--[[
	ItemService — objets du décor : apparition, ramasser/lâcher, utiliser, lancer, casser, réapparaître.
	Tout est validé côté serveur : le client demande, le serveur choisit l'objet le plus proche.

	- Utiliser : swing avec finisher (« CHAIR COMBO! ») si on termine un combo, onde de choc des objets lourds,
	  spéciaux : Spray (extincteur), Splash (seau -> flaque), Eat (burger -> soin).
	- Lancer : TOUS les objets se cassent sur la victime, l'étourdissent et la soulèvent (on peut continuer le combo).
	  Spéciaux à l'impact : Smoke, Puddle, Dirt (étourdit autour), Blind (cône sur la tête), Roll (pneu qui roule).
	- Lot 2 : Use Squeak (canard : cri en cône qui étourdit), Use/Throw Sticky (peinture qui ralentit),
	  Throw Bounce (rebondit vers la cible suivante avant de casser), Burst (gerbe de dégâts autour),
	  Flash (aveugle tout le monde autour), Spin (lancer à plat qui tourne), ImpactWords (mots d'explosion).
	- Parade : désarme (CombatService.disarm).
	Passifs liés aux objets (lus via l'attribut CharacterName) : Intern (lancers +25 %, objets lourds sans ralentir,
	tasse de café = +30 % de vitesse 5 s), Lunch Lady (objets Kitchen +25 %, la nourriture soigne plus).

	Performances : pooling (ServerStorage.ItemPool), débris supprimés après 4 s, plafond MAX_ACTIVE,
	objets immobiles ancrés, propriété réseau serveur au sol.
]]
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ItemsConfig = require(Shared.Config.Items)
local CombatConfig = require(Shared.Config.Combat)
local Net = require(Shared.Modules.Net)
local Hitbox = require(Shared.Modules.Hitbox)
local M1Style = require(Shared.Modules.M1Style) -- mini-chaîne des Use d'objets (Config/M1Styles.ItemChains)
local CharacterState = require(script.Parent.CharacterState)
local CombatService = require(script.Parent.CombatService)
local ZoneService = require(script.Parent.ZoneService)
local Signals = require(script.Parent.Signals)
local World = require(script.Parent.World)

-- enchaînement d'objet : 3 coups consécutifs puis endlag (reset après 1,2 s sans frapper ou changement d'objet)
local ITEM_STRING_HITS = 3
local ITEM_STRING_ENDLAG = 0.7
local ITEM_STRING_RESET = 1.2

local ItemService = {}
ItemService.Priority = 20

local MAX_ACTIVE = 120 -- 2 étages chargés (~30 points chacun) + objets lâchés / en vol
local DEBRIS_LIFE = 4
local FX, Anim

local templates = ServerStorage:WaitForChild("Items")
local pool

local records = {} -- [model] = record
local activeCount = 0
local rng = Random.new()

local function charName(c)
	return c and c:GetAttribute("CharacterName")
end

local function parts(model)
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function setPhysical(model, held: boolean)
	for _, p in ipairs(parts(model)) do
		p.Anchored = false
		p.CanCollide = not held
		p.CanTouch = not held
		p.CanQuery = not held
		p.Massless = held
		p.CollisionGroup = held and "HeldItems" or "Items"
	end
end

local function setAnchored(model, anchored: boolean)
	for _, p in ipairs(parts(model)) do
		p.Anchored = anchored
	end
end

local function settleLater(rec, delay: number)
	task.delay(delay, function()
		local handle = rec.model.PrimaryPart
		if records[rec.model] == rec and rec.state == "Ground" and handle then
			if handle.AssemblyLinearVelocity.Magnitude < 1.5 then
				setAnchored(rec.model, true)
			else
				settleLater(rec, 1)
			end
		end
	end)
end

local function setServerOwned(model)
	local handle = model.PrimaryPart
	if handle and handle:IsDescendantOf(workspace) and not handle.Anchored then
		pcall(function()
			handle:SetNetworkOwner(nil)
		end)
	end
end

------------------------------------------------------------------------
-- Apparition / pool
------------------------------------------------------------------------
local function takeFromPool(id: string)
	for _, m in ipairs(pool:GetChildren()) do
		if m:GetAttribute("ItemId") == id then
			return m
		end
	end
	local template = templates:FindFirstChild(id)
	if not template then
		warn("[ItemService] modèle manquant :", id)
		return nil
	end
	local m = template:Clone()
	m:SetAttribute("ItemId", id)
	return m
end

-- restPos (optionnel) : point où doit reposer le BAS de l'objet
function ItemService.spawn(id: string, cf: CFrame, spawnPoint: BasePart?, restPos: Vector3?)
	local cfg = ItemsConfig[id]
	if not cfg or activeCount >= MAX_ACTIVE then
		return nil
	end
	local model = takeFromPool(id)
	if not model then
		return nil
	end
	setPhysical(model, false)
	for _, p in ipairs(parts(model)) do
		p.AssemblyLinearVelocity = Vector3.zero
		p.AssemblyAngularVelocity = Vector3.zero
	end
	model:PivotTo(cf)
	if restPos then
		local bcf, bsize = model:GetBoundingBox()
		local bottom = bcf.Position.Y - bsize.Y / 2
		model:PivotTo(model:GetPivot() + Vector3.new(restPos.X - bcf.Position.X, restPos.Y - bottom, restPos.Z - bcf.Position.Z))
	end
	setAnchored(model, true)
	model.Parent = workspace.ActiveItems
	records[model] = {
		model = model, id = id, cfg = cfg, durability = cfg.Durability,
		spawnPoint = spawnPoint, state = "Ground", holder = nil,
	}
	model:SetAttribute("Durability", cfg.Durability)
	activeCount += 1
	return model
end

local function spawnAtPoint(point: BasePart)
	local id = point:GetAttribute("ItemId")
	if not (id and templates:FindFirstChild(id)) then
		return
	end
	local yaw = CFrame.Angles(0, math.rad(rng:NextNumber(-25, 25)), 0)
	local cf = CFrame.new(point.Position) * (point.CFrame - point.Position) * yaw
	ItemService.spawn(id, cf, point, point.Position - Vector3.new(0, 0.48, 0))
end

local function recycle(rec, noRespawn: boolean?)
	if records[rec.model] ~= rec then
		return
	end
	records[rec.model] = nil
	activeCount -= 1
	rec.model.Parent = pool
	local point = rec.spawnPoint
	if point and not noRespawn then
		task.delay(rec.cfg.RespawnTime or 8, function()
			if point:IsDescendantOf(workspace) then
				spawnAtPoint(point)
			end
		end)
	end
end

------------------------------------------------------------------------
-- Tenir / lâcher
------------------------------------------------------------------------
local function clearHolder(rec)
	local character = rec.holder
	rec.holder = nil
	local weld = rec.model.PrimaryPart and rec.model.PrimaryPart:FindFirstChild("HoldWeld")
	if weld then
		weld:Destroy()
	end
	if character then
		local s = CharacterState.get(character)
		if s.held == rec then
			s.held = nil
		end
		character:SetAttribute("HeldItem", nil)
		character:SetAttribute("HoldPose", nil)
		CharacterState.setSpeedMult(character, 1)
	end
end

local function attach(character: Model, rec)
	local cfg = rec.cfg
	local handle = rec.model.PrimaryPart
	local part0, c0
	if cfg.Hold == "TwoHands" then
		part0 = character:FindFirstChild("Torso")
		c0 = cfg.HoldOffset or CFrame.new(0, 3.8, -0.4)
	else
		part0 = character:FindFirstChild("Right Arm")
		c0 = CFrame.new(0, -1, 0) * CFrame.Angles(-math.pi / 2, 0, 0) * (cfg.Grip or CFrame.new())
	end
	if not part0 or not handle then
		return false
	end
	setPhysical(rec.model, true)
	pcall(function()
		handle:SetNetworkOwnershipAuto()
	end)
	local weld = Instance.new("Weld")
	weld.Name = "HoldWeld"
	weld.Part0 = part0
	weld.Part1 = handle
	weld.C0 = c0
	weld.Parent = handle
	rec.state = "Held"
	rec.holder = character
	local s = CharacterState.get(character)
	s.held = rec
	character:SetAttribute("HeldItem", rec.id)
	character:SetAttribute("HoldPose", cfg.Hold)
	local slow = cfg.SpeedMultiplier or 1
	if charName(character) == "Intern" then
		slow = 1 -- passif : porte les objets lourds sans ralentir
		if rec.id == "CoffeeMug" then
			CharacterState.setSpeedMod(character, "Caffeine", 1.3, 5)
		end
	end
	CharacterState.setSpeedMult(character, slow)
	Signals.ItemPickedUp:Fire(character, rec.id)
	return true
end

local function release(rec, cf: CFrame?)
	clearHolder(rec)
	setPhysical(rec.model, false)
	if cf then
		rec.model:PivotTo(cf)
	end
	setServerOwned(rec.model)
	rec.state = "Ground"
	settleLater(rec, 2.5)
end

function ItemService.dropHeld(character: Model)
	local rec = CharacterState.get(character).held
	if not rec then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	release(rec, root and (root.CFrame * CFrame.new(0, 0, -3)) or nil)
end

-- parade : l'objet saute des mains
local function disarm(character: Model)
	local rec = CharacterState.get(character).held
	if not rec then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	release(rec, root and (root.CFrame * CFrame.new(0, 2, -2)) or nil)
	local h = rec.model.PrimaryPart
	if h and root then
		h.AssemblyLinearVelocity = -root.CFrame.LookVector * 20 + Vector3.new(0, 35, 0)
		h.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-15, 15), rng:NextNumber(-15, 15), rng:NextNumber(-15, 15))
	end
	FX:FireAllClients({ k = "Disarm", p = root and root.Position or h.Position, v = character })
end

local function onPickup(player: Player)
	if not Net.allow(player, "Pickup", CombatConfig.RemoteRate.Pickup) then
		return
	end
	local character = player.Character
	if not CharacterState.isAlive(character) then
		return
	end
	local s = CharacterState.get(character)
	if s.held then
		ItemService.dropHeld(character)
		return
	end
	if CharacterState.isStunned(character) then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local best, bestDist = nil, CombatConfig.PickupRange + 1.5
	for model, rec in pairs(records) do
		if rec.state ~= "Held" and model.PrimaryPart then
			local d = (model.PrimaryPart.Position - root.Position).Magnitude
			if d < bestDist then
				best, bestDist = rec, d
			end
		end
	end
	if best and attach(character, best) then
		FX:FireAllClients({ k = "Pickup", p = root.Position, a = character })
	end
end

------------------------------------------------------------------------
-- Casse
------------------------------------------------------------------------
function ItemService.breakItem(rec)
	if records[rec.model] ~= rec then
		return
	end
	local model = rec.model
	local who = rec.holder or rec.lastUser
	local center = model:GetPivot().Position
	FX:FireAllClients({ k = "Break", p = center, m = rec.cfg.Material })
	clearHolder(rec)
	-- débris : chaque part coupée en 2 morceaux qui partent dans tous les sens
	for _, p in ipairs(parts(model)) do
		if p.Transparency < 1 then
			for i = 1, (p.Size.Magnitude > 1.5 and 2 or 1) do
				local d = p:Clone()
				for _, c in ipairs(d:GetChildren()) do
					if not c:IsA("SpecialMesh") then
						c:Destroy()
					end
				end
				if i == 2 or p.Size.Magnitude > 1.5 then
					d.Size = d.Size * 0.55
				end
				d.Anchored = false
				d.CanCollide = true
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = false
				d.CollisionGroup = "Debris"
				d.Parent = workspace.FX
				local out = (d.Position - center)
				out = out.Magnitude > 0.1 and out.Unit or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit
				d.AssemblyLinearVelocity = (out + Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5))) * rng:NextNumber(16, 32)
					+ Vector3.new(0, rng:NextNumber(20, 38), 0)
				d.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(-20, 20), rng:NextNumber(-20, 20))
				Debris:AddItem(d, DEBRIS_LIFE)
			end
		end
	end
	Signals.ItemBroken:Fire(rec.id, who)
	recycle(rec)
end

local function wear(rec, amount: number)
	rec.durability -= amount
	rec.model:SetAttribute("Durability", rec.durability)
	if rec.durability <= 0 then
		ItemService.breakItem(rec)
	end
end

------------------------------------------------------------------------
-- Spéciaux du lot 2 (Squeak, Sticky, Bounce, Burst, Flash)
------------------------------------------------------------------------
local PAINT = Color3.fromRGB(255, 70, 170)

local function itemFX(pos: Vector3, word: string?, sound: string?, color: Color3?, ring: number?)
	FX:FireAllClients({ k = "ItemFX", p = pos, w = word, s = sound, c = color, r = ring })
end

-- peinture fraîche : disque au sol qui ralentit tout le monde sauf son propriétaire
local function paintZone(pos: Vector3, radius: number, duration: number, owner: Model?)
	local ground = ZoneService.groundBelow(pos)
	local p = Instance.new("Part")
	p.Name = "PaintZone"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.16, radius * 2, radius * 2)
	p.CFrame = CFrame.new(ground) * CFrame.Angles(0, 0, math.pi / 2)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = PAINT
	p.Transparency = 0.15
	p.Parent = workspace.FX
	Debris:AddItem(p, duration)
	task.spawn(function()
		local t0 = os.clock()
		while p.Parent and os.clock() - t0 < duration do
			for _, c in ipairs(Hitbox.characters()) do
				local r = c ~= owner and c:FindFirstChild("HumanoidRootPart")
				if r then
					local d = r.Position - ground
					if Vector3.new(d.X, 0, d.Z).Magnitude <= radius and d.Y > -1 and d.Y < 5 then
						CharacterState.setSpeedMod(c, "Paint", 0.5, 0.4)
					end
				end
			end
			task.wait(0.2)
		end
	end)
	return p
end

-- dégâts de zone autour d'un point (Burst)
local function aoeHit(rec, center: Vector3, radius: number, attacker: Model?, skip: Model?, p)
	local n = 0
	for _, c in ipairs(Hitbox.characters()) do
		local r = c ~= attacker and c ~= skip and c:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - center).Magnitude <= radius then
			n += 1
			CombatService.applyHit({
				attacker = attacker, victim = c, damage = p.damage,
				dir = CombatService.flatUnit(r.Position - center, Vector3.zAxis), knockback = p.knockback, up = p.up,
				stun = p.stun, category = p.category or "Heavy", power = p.power or 0.6, weapon = rec.cfg.DisplayName,
				words = p.words,
			})
		end
	end
	return n
end

------------------------------------------------------------------------
-- Utiliser (clic gauche avec un objet en main)
------------------------------------------------------------------------
local function specialUse(character, rec, use)
	local root = character:FindFirstChild("HumanoidRootPart")
	if use.Special == "Squeak" then
		-- cri en cône devant : petits dégâts, gros étourdissement, pas de recul
		local look = root.CFrame.LookVector
		local n = 0
		for _, c in ipairs(Hitbox.characters()) do
			local r = c ~= character and c:FindFirstChild("HumanoidRootPart")
			if r then
				local to = r.Position - root.Position
				if to.Magnitude <= (use.Radius or 9) and CombatService.flatUnit(to, look):Dot(look) > 0.2 then
					n += 1
					CombatService.applyHit({
						attacker = character, victim = c, damage = use.SqueakDamage or 2, dir = CombatService.flatUnit(to, look),
						knockback = 4, up = 0, stun = use.Stun or 0.9, category = "Light", power = 0.35,
						weapon = rec.cfg.DisplayName, words = { "SQUEAK!", "SQUEEE!" }, itemId = rec.id,
					})
				end
			end
		end
		itemFX(root.Position + look * 3 + Vector3.new(0, 1.5, 0), "SQUEAK!", "Squeak", Color3.fromRGB(255, 225, 60), use.Radius or 9)
		if n > 0 then
			wear(rec, 1)
		end
		return true
	elseif use.Special == "Sticky" then
		local pos = root.Position + root.CFrame.LookVector * 6
		paintZone(pos, use.Radius or 6, 6, character)
		itemFX(pos, "SPLAT!", "Splat", PAINT)
	elseif use.Special == "Eat" then
		local hum = character:FindFirstChildOfClass("Humanoid")
		local heal = (charName(character) == "LunchLady") and use.KitchenHeal or use.Heal
		hum.Health = math.min(hum.MaxHealth, hum.Health + heal)
		FX:FireAllClients({ k = "Heal", p = root.Position, v = character, d = heal, eat = true })
		clearHolder(rec)
		recycle(rec)
		return true
	elseif use.Special == "Splash" then
		ZoneService.puddle(root.Position + root.CFrame.LookVector * 6, 7, 10, character)
		FX:FireAllClients({ k = "Splash", p = root.Position + root.CFrame.LookVector * 5 })
	elseif use.Special == "Spray" then
		ZoneService.smoke(root.Position + root.CFrame.LookVector * 8 + Vector3.new(0, 1, 0), 5, 4)
		FX:FireAllClients({ k = "Spray", p = root.Position + root.CFrame.LookVector * 3, a = character })
	end
	return false
end

local function onUse(player: Player, character: Model, seq: number, mods)
	local s = CharacterState.get(character)
	local rec = s.held
	if not rec then
		return
	end
	local use = rec.cfg.Use
	local t = os.clock()
	if t < s.nextAttack - 0.05 or s.blocking then
		return
	end
	s.nextAttack = t + use.Cooldown
	s.combo = 0
	-- enchaînement d'objet (compteur serveur, indépendant de l'index client mods.ic) : le 3e coup consécutif
	-- ajoute ITEM_STRING_ENDLAG d'endlag (ni attaque, ni block, pose « essoufflé ») -> DPS soutenu borné (docs/Equilibrage.md)
	local str = s.itemString
	if not str or str.rec ~= rec or t - str.last > ITEM_STRING_RESET + use.Cooldown then
		str = { rec = rec, n = 0, last = t }
		s.itemString = str
	end
	str.n += 1
	str.last = t
	if str.n >= ITEM_STRING_HITS and use.Special ~= "Eat" then
		str.n = 0
		local recover = use.Cooldown + ITEM_STRING_ENDLAG
		s.nextAttack = t + recover
		s.busyUntil = math.max(s.busyUntil or 0, t + recover)
		character:SetAttribute("EndlagUntil", workspace:GetServerTimeNow() + recover)
	end
	-- mini-chaîne (Config/M1Styles.ItemChains) : index du client (mods.ic) accepté s'il est cohérent avec celui du serveur
	Anim:FireAllClients(character, (M1Style.itemAnim(character, use.Anim or "Jab", type(mods) == "table" and mods.ic or nil)))
	if rec.cfg.SlamPath then
		local weld = rec.model.PrimaryPart and rec.model.PrimaryPart:FindFirstChild("HoldWeld")
		if weld then
			task.spawn(function()
				for i, step in ipairs(rec.cfg.SlamPath) do
					if weld.Parent == nil then
						return
					end
					TweenService:Create(weld, TweenInfo.new(step.t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = step.cf }):Play()
					task.wait(step.t + (i == 2 and 0.15 or 0))
				end
			end)
		end
	end
	task.delay(use.Windup or 0.08, function()
		if s.held ~= rec or not CharacterState.isAlive(character) or CharacterState.isStunned(character) then
			return
		end
		if use.Special and specialUse(character, rec, use) then
			return
		end
		if not use.Damage then
			return
		end
		local landed = CombatService.swing(character, {
			HitboxOffset = use.HitboxOffset, HitboxSize = use.HitboxSize, MaxTargets = 3,
			Damage = use.Damage, Knockback = use.Knockback, KnockUp = use.KnockUp, Stun = use.Stun,
			Category = use.Category, Power = use.Power, Words = use.Words, Material = rec.cfg.Material,
			Weapon = rec.cfg.DisplayName, ItemId = rec.id, Kitchen = rec.cfg.Kitchen, FinisherName = rec.cfg.DisplayName,
		}, seq)
		if use.Shockwave then
			local root = character:FindFirstChild("HumanoidRootPart")
			local pos = root.Position + root.CFrame.LookVector * use.HitboxOffset - Vector3.new(0, 2.8, 0)
			FX:FireAllClients({ k = "Slam", p = pos, a = character, small = true })
			ZoneService.shatterAround(pos, use.Shockwave, root.CFrame.LookVector * 30)
		end
		if #landed > 0 then
			wear(rec, 1)
		end
	end)
end

------------------------------------------------------------------------
-- Lancer (touche R)
------------------------------------------------------------------------
local function throwImpact(rec, pos: Vector3, thrower: Model?, victimHit: Model?)
	local throw = rec.cfg.Throw
	local sp = throw.Special
	if sp == "Smoke" then
		ZoneService.smoke(pos, 7, 6)
	elseif sp == "Puddle" then
		ZoneService.puddle(pos, throw.Radius or 9, 12, thrower)
		FX:FireAllClients({ k = "Splash", p = pos })
	elseif sp == "Sticky" then
		paintZone(pos, throw.Radius or 8, 7, thrower)
		itemFX(pos, "FRESH PAINT!", "Splat", PAINT)
		if victimHit then
			CharacterState.setSpeedMod(victimHit, "Paint", 0.5, 2.5)
		end
	elseif sp == "Flash" then
		local rad = throw.Radius or 10
		for _, c in ipairs(Hitbox.characters()) do
			local r = c ~= thrower and c:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - pos).Magnitude <= rad then
				CharacterState.blind(c, throw.BlindTime or 1.2)
			end
		end
		itemFX(pos, "FLASH!", "Electric", Color3.fromRGB(255, 250, 190), rad)
	elseif sp == "Burst" then
		local rad = throw.Radius or 9
		aoeHit(rec, pos, rad, thrower, victimHit, {
			damage = math.max(3, math.floor(throw.Damage * 0.5)), knockback = 32, up = 20, stun = 0.6,
			words = throw.ImpactWords or { "PAPERCUT!", "FLAP!" },
		})
		itemFX(pos, "BURST!", "WoodBreak", Color3.fromRGB(255, 255, 255), rad)
	end
	if sp == "Smoke" or sp == "Dirt" then
		-- explosion autour du point d'impact
		for _, c in ipairs(Hitbox.characters()) do
			local r = c ~= thrower and c ~= victimHit and c:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - pos).Magnitude <= (throw.Radius or 8) then
				CombatService.applyHit({
					attacker = thrower, victim = c, damage = math.floor(throw.Damage * 0.6),
					dir = CombatService.flatUnit(r.Position - pos, Vector3.zAxis), knockback = 18, up = 14,
					stun = throw.Stun, category = "Heavy", power = 0.6, weapon = rec.cfg.DisplayName,
					words = throw.ImpactWords or (sp == "Dirt" and { "DIRT!", "BONK!" } or { "POOF!", "COUGH!" }),
				})
			end
		end
	end
end

local function onThrow(player: Player, aim)
	if not Net.allow(player, "Throw", CombatConfig.RemoteRate.Throw) then
		return
	end
	local character = player.Character
	if not CharacterState.isAlive(character) or CharacterState.isStunned(character) then
		return
	end
	local s = CharacterState.get(character)
	local rec = s.held
	local root = character:FindFirstChild("HumanoidRootPart")
	if not rec or not root then
		return
	end
	local t = os.clock()
	if t < s.nextThrow then
		return
	end
	s.nextThrow = t + 0.45
	s.nextAttack = math.max(s.nextAttack, t + 0.3)

	local dir = root.CFrame.LookVector
	if typeof(aim) == "Vector3" and aim.Magnitude > 0.1 and aim.Magnitude < 2 and aim == aim then
		dir = aim.Unit
	end
	local y = math.clamp(dir.Y, -0.35, 0.6)
	local flat = CombatService.flatUnit(dir, root.CFrame.LookVector)
	dir = (flat * math.sqrt(1 - y * y) + Vector3.new(0, y, 0)).Unit

	local throw = rec.cfg.Throw
	local heavy = rec.cfg.Hold == "TwoHands"
	local speedMult = charName(character) == "Intern" and 1.25 or 1 -- passif Intern
	Anim:FireAllClients(character, heavy and "HeavyThrow" or "Throw")
	FX:FireAllClients({ k = "Throw", p = root.Position, a = character })

	task.delay(heavy and 0.22 or 0.12, function()
		if s.held ~= rec or not root.Parent then
			return
		end
		local origin = root.Position + Vector3.new(0, 1.5, 0) + flat * 3.5
		release(rec, CFrame.lookAt(origin, origin + dir))
		local handle = rec.model.PrimaryPart
		handle.AssemblyLinearVelocity = dir * throw.Speed * speedMult + Vector3.new(0, throw.Up or 0, 0)
		if throw.Special == "Roll" then
			handle.AssemblyAngularVelocity = root.CFrame.RightVector * -20
		elseif throw.Spin then
			handle.AssemblyAngularVelocity = Vector3.new(0, 45, 0) -- lancer à plat qui tourne
		else
			handle.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-8, 8), rng:NextNumber(-12, 12))
		end
		rec.state = "Flight"
		rec.thrower = character
		rec.lastUser = character
		rec.flightStart = os.clock()
		rec.bounced = false
		rec.bounces = 0
		rec.skipVictim = nil
	end)
end

-- Suivi des objets en vol : le serveur détecte lui-même les impacts
local function updateFlights()
	local t = os.clock()
	for model, rec in pairs(records) do
		local handle = model.PrimaryPart
		if not handle then
			continue
		end
		if handle.Position.Y < World.getFloorY() - 80 then
			if rec.holder then
				clearHolder(rec)
			end
			recycle(rec)
			continue
		end
		if rec.state ~= "Flight" then
			continue
		end
		local elapsed = t - rec.flightStart
		local vel = handle.AssemblyLinearVelocity
		local throw = rec.cfg.Throw
		local maxTime = throw.Special == "Roll" and 3.5 or 2.5
		if elapsed > maxTime or (elapsed > 0.25 and vel.Magnitude < 10) then
			local thrower = rec.thrower
			rec.state = "Ground"
			rec.thrower = nil
			if throw.Special and throw.Special ~= "Roll" and throw.Special ~= "Blind" then
				-- le lanceur garde le crédit (et n'est pas touché par sa propre zone)
				throwImpact(rec, handle.Position, thrower, nil)
				ItemService.breakItem(rec)
			else
				settleLater(rec, 2)
			end
			continue
		end
		if vel.Magnitude > 25 then
			ZoneService.shatterAround(handle.Position, 2.5, vel)
		end
		local cf, size = model:GetBoundingBox()
		local hits = Hitbox.box(cf, size + Vector3.one * 2, rec.thrower, rec.skipVictim and 3 or 1)
		local victim = hits[1]
		if victim and victim == rec.skipVictim then
			victim = hits[2] -- Bounce : on ne retouche pas la cible précédente
		end
		if victim and (victim:GetAttribute("TrayGuardUntil") or 0) > workspace:GetServerTimeNow() then
			-- renvoyé par la Tray Guard de la Lunch Lady
			handle.AssemblyLinearVelocity = -vel
			rec.thrower = victim
			FX:FireAllClients({ k = "Block", p = handle.Position, v = victim })
		elseif victim then
			local thrower = rec.thrower
			local result = CombatService.applyHit({
				attacker = thrower, victim = victim,
				damage = (rec.bounces or 0) > 0 and math.max(3, math.floor(throw.Damage * 0.75)) or throw.Damage,
				dir = CombatService.flatUnit(vel, Vector3.new(0, 0, -1)),
				knockback = throw.Knockback, up = 18, stun = throw.Stun,
				category = throw.Category or "Projectile", power = math.clamp(throw.Damage / 20, 0.4, 1.1),
				material = rec.cfg.Material, hitPos = handle.Position, weapon = rec.cfg.DisplayName,
				itemId = rec.id, kitchen = rec.cfg.Kitchen,
			})
			if result == "Hit" then
				if throw.Burn then
					CombatService.burn(victim, thrower, throw.Burn)
				end
				if throw.Special == "Blind" then
					CharacterState.blind(victim, throw.BlindTime or 1.5)
					victim:SetAttribute("HeadProp", "Cone")
					victim:SetAttribute("HeadPropUntil", workspace:GetServerTimeNow() + (throw.BlindTime or 1.5))
				end
				if throw.Special == "Bounce" and (rec.bounces or 0) < (throw.Bounces or 2) then
					-- rebond vers la cible la plus proche (sinon on casse normalement)
					local nextRoot, best = nil, 22
					for _, c in ipairs(Hitbox.characters()) do
						local r = c ~= thrower and c ~= victim and CharacterState.isAlive(c) and c:FindFirstChild("HumanoidRootPart")
						if r then
							local d = (r.Position - handle.Position).Magnitude
							if d < best then
								nextRoot, best = r, d
							end
						end
					end
					if nextRoot then
						rec.bounces = (rec.bounces or 0) + 1
						rec.skipVictim = victim
						rec.flightStart = os.clock()
						local to = nextRoot.Position - handle.Position
						handle.AssemblyLinearVelocity = CombatService.flatUnit(to, Vector3.zAxis) * math.max(throw.Speed * 0.75, 60)
							+ Vector3.new(0, 10 + best * 0.5, 0)
						itemFX(handle.Position, "BOING!", "Boing", Color3.fromRGB(255, 225, 60))
						continue
					end
				end
			end
			rec.state = "Ground"
			rec.thrower = nil
			throwImpact(rec, handle.Position, thrower, victim)
			ItemService.breakItem(rec) -- tous les lancers se cassent sur la cible
		end
	end
end

function ItemService.init()
	FX = Net.get("FX")
	Anim = Net.get("Anim")
	pool = ServerStorage:FindFirstChild("ItemPool") or Instance.new("Folder")
	pool.Name = "ItemPool"
	pool.Parent = ServerStorage
	Net.get("Pickup").OnServerEvent:Connect(onPickup)
	Net.get("Throw").OnServerEvent:Connect(onThrow)
	CombatService.itemUseHandler = onUse
	CombatService.disarm = disarm
	-- passif Lunch Lady : objets de cuisine +25 %
	table.insert(CombatService.damageMods, function(p)
		if p.kitchen and p.attacker and charName(p.attacker) == "LunchLady" then
			p.damage *= 1.25
		end
	end)
	RunService.Heartbeat:Connect(updateFlights)
	Signals.Died:Connect(function(character)
		ItemService.dropHeld(character)
	end)
	task.defer(function()
		if not World.managed and workspace:FindFirstChild("Arena") then
			ItemService.spawnFloorItems(workspace.Arena)
		end
	end)
end

function ItemService.spawnFloorItems(container: Instance)
	local folder = container:FindFirstChild("ItemSpawns", true)
	if not folder then
		return
	end
	for _, point in ipairs(folder:GetChildren()) do
		if point:IsA("BasePart") then
			spawnAtPoint(point)
			task.wait()
		end
	end
end

function ItemService.clearGroundItems(minY: number, maxY: number)
	for model, rec in pairs(records) do
		if rec.state ~= "Held" and model.PrimaryPart then
			local y = model.PrimaryPart.Position.Y
			if y >= minY and y <= maxY then
				recycle(rec, true)
			end
		end
	end
end

function ItemService.getHeld(character: Model)
	local rec = CharacterState.get(character).held
	return rec and rec.id or nil
end

return ItemService
