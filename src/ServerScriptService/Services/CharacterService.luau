--[[
	CharacterService — choix du personnage, kit d'attaques, transformation (jauge Overtime).
	- Remote "SelectCharacter"(name) : name dans Config/Characters.Order. 1 requête / s (Net.allow), re-choisir le
	  perso actuel = rien. Prend effet tout de suite, SAUF en combat (coup donné / reçu, bloqué, garde cassée, paré
	  depuis COMBAT_LOCK s) : changement mis en file pour la prochaine apparition (toast, attribut Player
	  PendingCharacter). Un changement en direct ne remet JAMAIS les recharges à zéro : chaque emplacement garde le
	  temps restant de l'ancien kit (carryCooldowns). Remise à zéro seulement à l'apparition (perso neuf) et par la
	  transformation (voulu). Voir docs/Serveur-securite.md.
	- CharacterService.setCharacter(player, name, force?) : refuse un perso non possédé (CharacterService.canUse,
	  branché par UnlockService) sauf force = true (admin /char). Perso actuel non possédé => retour à l'Intern.
	- Remote "Transform" : jauge Overtime pleine -> transformation (durée de la fiche), annonce serveur
	  « [NAME] IS WORKING OVERTIME! », accessoires + aura, attaques transformées.
	- Accessoires d'identité en parts simples (badge, casquette…) pour reconnaître le métier d'un coup d'œil.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Config.Characters)
local Sounds = require(Shared.Config.Sounds)
local CombatConfig = require(Shared.Config.Combat)
local Attacks = require(Shared.Config.Attacks)
local Net = require(Shared.Modules.Net)
local CharacterState = require(script.Parent.CharacterState)
local AbilityService = require(script.Parent.AbilityService)
local PlayerService = require(script.Parent.PlayerService)
local Announce = require(script.Parent.Announce)
local Signals = require(script.Parent.Signals)

local CharacterService = {}
CharacterService.Priority = 25

local DEFAULT = "Intern"
local COMBAT_LOCK = 8 -- s sans échange de coups avant de pouvoir changer de perso en direct
local FX
local lastCombat = setmetatable({}, { __mode = "k" }) -- [character] = os.clock() du dernier échange
local pending = setmetatable({}, { __mode = "k" }) -- [player] = perso choisi pour la prochaine apparition

local function now()
	return workspace:GetServerTimeNow()
end

function CharacterService.getKit(character: Model)
	local def = Characters[character:GetAttribute("CharacterName") or ""]
	if not def then
		return nil
	end
	return character:GetAttribute("Transformed") and def.TransAttacks or def.Attacks
end

------------------------------------------------------------------------
-- Accessoires en parts simples
------------------------------------------------------------------------
local function prop(parent: Instance, attachTo: BasePart, size: Vector3, offset: CFrame, color: Color3, shape)
	local p = Instance.new("Part")
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	if shape then
		p.Shape = shape
	end
	p.CFrame = attachTo.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = attachTo
	w.Part1 = p
	w.Parent = p
	p.Parent = parent
	return p
end

local CYL = Enum.PartType.Cylinder
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2)

-- Accessoires de métier (IdentityProps) : construits par SkinBuilder.identity (via SkinService.applyTo)

-- Armes fétiches : dans le dossier "Signature", attribut Hand = "Left"/"Right" (le client les cache quand la main est occupée)
local function arm(c, side)
	return c:FindFirstChild(side == "Left" and "Left Arm" or "Right Arm")
end
local SIGNATURE = {
	Intern = { Hand = "Left", Build = function(f, a)
		prop(f, a, Vector3.new(1.1, 0.8, 0.8), CFrame.new(0, -1.25, -0.35) * UPRIGHT, Color3.fromRGB(255, 255, 255), CYL) -- gobelet
		prop(f, a, Vector3.new(0.35, 0.86, 0.86), CFrame.new(0, -1.15, -0.35) * UPRIGHT, Color3.fromRGB(150, 95, 50), CYL) -- manchon
		prop(f, a, Vector3.new(0.15, 0.82, 0.82), CFrame.new(0, -0.78, -0.35) * UPRIGHT, Color3.fromRGB(60, 40, 30), CYL) -- couvercle
	end },
	Janitor = { Hand = "Left", Build = function(f, a)
		prop(f, a, Vector3.new(1.3, 1.4, 1.4), CFrame.new(0, -2.0, 0) * UPRIGHT, Color3.fromRGB(150, 160, 175), CYL) -- seau
		prop(f, a, Vector3.new(0.1, 1.2, 1.2), CFrame.new(0, -1.36, 0) * UPRIGHT, Color3.fromRGB(90, 180, 255), CYL) -- eau
		prop(f, a, Vector3.new(0.1, 0.9, 0.1), CFrame.new(0.65, -1.05, 0) * CFrame.Angles(0, 0, 0.5), Color3.fromRGB(70, 70, 80)) -- anse
		prop(f, a, Vector3.new(0.1, 0.9, 0.1), CFrame.new(-0.65, -1.05, 0) * CFrame.Angles(0, 0, -0.5), Color3.fromRGB(70, 70, 80))
	end },
	LunchLady = { Hand = "Right", Build = function(f, a)
		prop(f, a, Vector3.new(0.25, 0.25, 1.9), CFrame.new(0, -1, -0.9), Color3.fromRGB(120, 70, 40)) -- manche
		prop(f, a, Vector3.new(0.9, 0.08, 1.0), CFrame.new(0, -1, -2.3), Color3.fromRGB(205, 210, 220)) -- lame de spatule
		prop(f, a, Vector3.new(0.6, 0.1, 0.12), CFrame.new(0, -1, -2.15), Color3.fromRGB(60, 60, 70))
	end },
	SecurityGuard = { Hand = "Right", Build = function(f, a)
		prop(f, a, Vector3.new(2.4, 0.28, 0.28), CFrame.new(0, -1, -1.1) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(25, 25, 30), CYL) -- matraque
		prop(f, a, Vector3.new(0.5, 0.4, 0.4), CFrame.new(0.35, -1, -0.5) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(25, 25, 30), CYL) -- poignée latérale
	end },
}

local TRANSFORM = {
	Intern = function(f, head, torso)
		prop(f, head, Vector3.new(0.25, 0.18, 0.05), CFrame.new(-0.2, 0.15, -0.6), Color3.fromRGB(255, 30, 30))
		prop(f, head, Vector3.new(0.25, 0.18, 0.05), CFrame.new(0.2, 0.15, -0.6), Color3.fromRGB(255, 30, 30))
		prop(f, torso, Vector3.new(0.5, 1.3, 0.5), CFrame.new(0.6, 0.2, 0.75) * UPRIGHT, Color3.fromRGB(110, 60, 30), CYL) -- gobelet géant dans le dos
	end,
	Janitor = function(f, head, torso, c)
		for _, arm in ipairs({ "Left Arm", "Right Arm" }) do
			local a = c:FindFirstChild(arm)
			if a then
				prop(f, a, Vector3.new(1.08, 0.9, 1.08), CFrame.new(0, -0.6, 0), Color3.fromRGB(255, 220, 30)) -- gants
			end
		end
	end,
	LunchLady = function(f, head, torso)
		prop(f, head, Vector3.new(1.6, 1.3, 1.3), CFrame.new(0, 1.0, 0) * UPRIGHT, Color3.fromRGB(255, 255, 255), CYL) -- toque
		prop(f, head, Vector3.new(2, 2, 2), CFrame.new(0, 1.9, 0), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
		prop(f, torso, Vector3.new(1.7, 1.7, 0.1), CFrame.new(0, -0.15, -0.56), Color3.fromRGB(255, 255, 255)) -- tablier
	end,
	SecurityGuard = function(f, head, torso)
		local light = prop(f, torso, Vector3.new(0.5, 0.6, 0.6), CFrame.new(0.9, 1.25, 0) * UPRIGHT, Color3.fromRGB(255, 40, 40), CYL)
		light.Name = "Siren"
		local pl = Instance.new("PointLight")
		pl.Range = 14
		pl.Brightness = 3
		pl.Color = light.Color
		pl.Parent = light
	end,
}

-- contenu ajouté par les modules de Content
for _, def in ipairs(require(Shared.Modules.ContentLoader).all()) do
	if def.Transform then
		TRANSFORM[def.Id] = function(f, head, torso, c) def.Transform(f, head, torso, c, prop) end
	end
	if def.Signature then
		SIGNATURE[def.Id] = { Hand = def.Signature.Hand or "Right", Build = function(f, a) def.Signature.Build(f, a, prop) end }
	end
end

local function clearFolder(character, name)
	local f = character:FindFirstChild(name)
	if f then
		f:Destroy()
	end
end

local function buildFolder(character, name, builder)
	clearFolder(character, name)
	local head, torso = character:FindFirstChild("Head"), character:FindFirstChild("Torso")
	if not builder or not head or not torso then
		return nil
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = character
	builder(f, head, torso, character)
	return f
end

------------------------------------------------------------------------
-- Choix du personnage
------------------------------------------------------------------------
local function endTransform(character: Model, keepCooldowns: boolean?)
	if not character:GetAttribute("Transformed") then
		return
	end
	character:SetAttribute("Transformed", false)
	character:SetAttribute("TransformUntil", 0)
	clearFolder(character, "TransformFX")
	local hl = character:FindFirstChild("OvertimeAura")
	if hl then
		hl:Destroy()
	end
	if character:GetAttribute("Scaled") then
		character:SetAttribute("Scaled", nil)
		pcall(function()
			character:ScaleTo(1)
		end)
	end
	CharacterState.setSpeedMod(character, "Transform", nil)
	if not keepCooldowns then
		AbilityService.resetCooldowns(character)
	end
end

-- apparence (avatar du joueur / uniforme / skin) : SkinService.applyTo (require paresseux, pas de cycle)
local function applyLook(character: Model, name: string)
	local ok, err = pcall(function()
		require(script.Parent.SkinService).applyTo(character, Players:GetPlayerFromCharacter(character), name)
	end)
	if not ok then
		warn("[CharacterService] SkinService.applyTo :", err)
	end
end

-- changement en direct : chaque emplacement (1..3) du nouveau kit hérite du temps de recharge restant de l'ancien
-- emplacement (attributs CD1..3 = heure serveur de fin) ; s.cd (os.clock, par attaque) n'est jamais vidé.
local function snapshotCooldowns(character: Model)
	local left = {}
	local t = now()
	for i = 1, 3 do
		left[i] = math.max(0, (tonumber(character:GetAttribute("CD" .. i)) or 0) - t)
	end
	return left
end

local function carryCooldowns(character: Model, left)
	local s = CharacterState.get(character)
	s.cd = s.cd or {}
	local kit = CharacterService.getKit(character)
	local clock, t = os.clock(), now()
	for i = 1, 3 do
		local id = kit and kit[i]
		if id then
			-- le plus long des deux : reste de l'ancien emplacement / recharge propre de cette attaque (aller-retour A->B->A)
			local remain = math.max(left[i] or 0, (s.cd[id] or 0) - clock)
			s.cd[id] = clock + remain
			character:SetAttribute("CD" .. i, remain > 0 and t + remain or 0)
			local cfg = Attacks[id]
			character:SetAttribute("CDMax" .. i, math.max(cfg and cfg.Cooldown or 1, remain))
		end
	end
end

-- swap = true : changement de perso en direct (garde les recharges) ; sinon apparition (perso neuf, remise à zéro)
function CharacterService.apply(character: Model, name: string, swap: boolean?)
	if not Characters[name] then
		name = DEFAULT
	end
	local left = swap and snapshotCooldowns(character) or nil
	endTransform(character, swap)
	character:SetAttribute("CharacterName", name)
	applyLook(character, name)
	clearFolder(character, "Signature")
	local sig = SIGNATURE[name]
	local a = sig and arm(character, sig.Hand)
	if a then
		local f = Instance.new("Folder")
		f.Name = "Signature"
		f:SetAttribute("Hand", sig.Hand)
		f.Parent = character
		sig.Build(f, a)
	end
	if left then
		carryCooldowns(character, left)
	else
		AbilityService.resetCooldowns(character)
	end
end

-- possession d'un perso (remplacé par UnlockService.owns) ; vrai par défaut
CharacterService.canUse = function(player, name)
	return true
end

local function usable(player, name)
	if player:GetAttribute("AdminChar") == name then
		return true -- choisi par un admin (/char) : test sans déblocage
	end
	local ok, res = pcall(CharacterService.canUse, player, name)
	if not ok then
		warn("[CharacterService] canUse a planté (refusé) :", res)
		return false
	end
	return res == true
end
CharacterService.usable = usable

function CharacterService.setCharacter(player: Player, name: string, force: boolean?)
	if not Characters[name] then
		return false
	end
	if force then
		player:SetAttribute("AdminChar", name)
	elseif not usable(player, name) then
		-- refusé : on garde le perso actuel s'il est possédé, sinon l'Intern
		local cur = player:GetAttribute("CharacterName")
		if cur and not usable(player, cur) then
			CharacterService.setCharacter(player, DEFAULT, true)
		end
		return false
	else
		player:SetAttribute("AdminChar", nil)
	end
	pending[player] = nil
	player:SetAttribute("PendingCharacter", nil)
	player:SetAttribute("CharacterName", name)
	local c = player.Character
	if c and CharacterState.isAlive(c) and c:GetAttribute("CharacterName") ~= name then
		CharacterService.apply(c, name, true)
	end
	return true
end

-- combat récent (coup donné / reçu, bloqué, garde cassée, paré) : pas de changement de perso en direct
function CharacterService.inCombat(character: Model?): boolean
	if not character then
		return false
	end
	local t = lastCombat[character]
	return t ~= nil and os.clock() - t < COMBAT_LOCK
end

-- requête du client (remote SelectCharacter) : limitée, ignorée si rien ne change, différée en combat
local function onSelect(player: Player, name)
	if type(name) ~= "string" or not Net.allow(player, "SelectCharacter", 1) then
		return
	end
	local def = Characters[name]
	if not def then
		return
	end
	if not usable(player, name) then
		Announce.toast(player, "LOCKED! Unlock " .. (def.DisplayName or name) .. " first.", Color3.fromRGB(255, 110, 90))
		return
	end
	local c = player.Character
	local live = c and CharacterState.isAlive(c) and c:GetAttribute("CharacterName") or nil
	if player:GetAttribute("CharacterName") == name and (live == nil or live == name) then
		if pending[player] then
			pending[player] = nil -- re-choisir le perso actuel annule un changement en file
			player:SetAttribute("PendingCharacter", nil)
		end
		return
	end
	if live and CharacterService.inCombat(c) then
		pending[player] = name
		player:SetAttribute("PendingCharacter", name)
		Announce.toast(player, "In combat! You'll be " .. (def.DisplayName or name) .. " next respawn.", Color3.fromRGB(255, 200, 90))
		return
	end
	CharacterService.setCharacter(player, name)
end
CharacterService.onSelect = onSelect

------------------------------------------------------------------------
-- Transformation
------------------------------------------------------------------------
-- animation de transformation (Overtime) : le perso est soulevé, figé et protégé ~1,3 s
-- (le client joue la charge puis l'explosion d'aura : AbilityFXController handlers.Transform)
local LIFT_TIME = 1.3
local function transformLift(c: Model)
	local root = c:FindFirstChild("HumanoidRootPart")
	if not root or c:GetAttribute("UltAnchor") then
		return
	end
	local st = CharacterState.get(c)
	st.nextAttack = math.max(st.nextAttack, os.clock() + LIFT_TIME)
	st.gcdUntil = math.max(st.gcdUntil or 0, os.clock() + LIFT_TIME)
	for _, o in ipairs(root:GetChildren()) do
		if o:IsA("LinearVelocity") or o:IsA("AngularVelocity") then
			o:Destroy()
		end
	end
	local base = root.CFrame
	c:SetAttribute("UltAnchor", true) -- le client garde le perso ancré et bloque ses actions
	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < LIFT_TIME and c.Parent and root.Parent and CharacterState.isAlive(c) do
			local t = os.clock() - t0
			local h
			if t < 0.55 then
				h = 0.8 * (t / 0.55) -- se ramasse en montant doucement
			elseif t < 1.05 then
				h = 0.8 + 1.4 * math.min(1, (t - 0.55) / 0.1) -- explosion : bond vers le haut
			else
				h = 2.2 * (1 - (t - 1.05) / (LIFT_TIME - 1.05)) -- redescend
			end
			root.Anchored = true
			root.CFrame = base + Vector3.new(0, math.max(h, 0), 0)
			task.wait()
		end
		if c.Parent then
			c:SetAttribute("UltAnchor", nil)
		end
		if root.Parent then
			root.CFrame = base
			root.Anchored = false
		end
	end)
end

local function transform(player: Player)
	if not Net.allow(player, "Transform", CombatConfig.RemoteRate.Transform) then
		return
	end
	local c = player.Character
	if not CharacterState.isAlive(c) or c:GetAttribute("Transformed") then
		return
	end
	if (c:GetAttribute("Overtime") or 0) < CombatConfig.Overtime.Max then
		return
	end
	-- pas de transformation « brise-combo » : refusée si étourdi, garde brisée, au sol, K.O. en cours ou tenu par un ulti
	local st = CharacterState.get(c)
	if CharacterState.isStunned(c) or CharacterState.isGuardBroken(c) or CharacterState.isKnockedDown(c)
		or (st and st.pendingKO) or c:GetAttribute("PendingKO") or c:GetAttribute("UltHeld") then
		return
	end
	-- zone AFK : pas de transformation (ni coups, ni ulti là-bas)
	if CharacterState.inSafeZone(c) then
		Announce.toast(player, "No Overtime in the AFK zone!", Color3.fromRGB(255, 200, 90))
		return
	end
	local name = c:GetAttribute("CharacterName") or DEFAULT
	local def = Characters[name]
	-- durée allongée (multiplicateur global) + soin complet à l'activation
	local duration = (def.Transformation.Duration or 20) * (CombatConfig.Overtime.DurationMult or 1)
	c:SetAttribute("Transformed", true)
	c:SetAttribute("TransformUntil", now() + duration)
	CharacterState.clearStun(c)
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = hum.MaxHealth
		FX:FireAllClients({ k = "Heal", p = c.HumanoidRootPart.Position, v = c, d = math.floor(hum.MaxHealth) })
	end
	-- protégé pendant l'animation de transformation (bouclier invisible)
	local guard = Instance.new("ForceField")
	guard.Name = "TransformGuard"
	guard.Visible = false
	guard.Parent = c
	game:GetService("Debris"):AddItem(guard, 1.5)
	buildFolder(c, "TransformFX", TRANSFORM[name])
	if name == "LunchLady" then
		c:SetAttribute("Scaled", true)
		pcall(function()
			c:ScaleTo(1.15)
		end)
	end
	transformLift(c)
	local hl = Instance.new("Highlight")
	hl.Name = "OvertimeAura"
	hl.FillTransparency = 0.85
	hl.FillColor = def.Color
	hl.OutlineColor = def.Color
	hl.OutlineTransparency = 0
	hl.Parent = c
	CharacterState.setSpeedMod(c, "Transform", def.Transformation.SpeedMultiplier or 1)
	AbilityService.resetCooldowns(c)
	FX:FireAllClients({ k = "Transform", a = c, name = name, color = def.Color })
	Announce.banner(string.upper(player.DisplayName) .. " IS WORKING OVERTIME!", def.Transformation.Name .. "!", def.Color, 3, "Overtime")
	Signals.Transformed:Fire(c, name)

	-- la jauge se vide pendant la transformation ; gyrophare qui clignote pour le Security Guard
	task.spawn(function()
		local t0 = os.clock()
		local siren
		if name == "SecurityGuard" then
			siren = Instance.new("Sound")
			siren.SoundId = Sounds.Siren and Sounds.Siren[1] or ""
			siren.Looped = true
			siren.Volume = 0.5
			siren.RollOffMaxDistance = 90
			siren.Parent = c:FindFirstChild("Torso")
			siren:Play()
		end
		while c.Parent and c:GetAttribute("Transformed") do
			local elapsed = os.clock() - t0
			if elapsed >= duration then
				break
			end
			c:SetAttribute("Overtime", math.max(0, CombatConfig.Overtime.Max * (1 - elapsed / duration)))
			local fx = c:FindFirstChild("TransformFX")
			local light = fx and fx:FindFirstChild("Siren")
			if light then
				local red = math.floor(elapsed * 4) % 2 == 0
				light.Color = red and Color3.fromRGB(255, 40, 40) or Color3.fromRGB(40, 90, 255)
				light.PointLight.Color = light.Color
			end
			task.wait(0.25)
		end
		if siren then
			siren:Destroy()
		end
		if c.Parent then
			c:SetAttribute("Overtime", 0)
			endTransform(c)
		end
	end)
end

function CharacterService.init()
	for _, def in ipairs(require(Shared.Modules.ContentLoader).all()) do
		if def.ServerInit then
			task.spawn(def.ServerInit, {
				CombatService = require(script.Parent.CombatService), CharacterState = CharacterState, Signals = Signals,
				ZoneService = require(script.Parent.ZoneService), Net = Net, Announce = Announce,
				getItemService = function() return require(script.Parent.ItemService) end,
			})
		end
	end
	FX = Net.get("FX")
	AbilityService.getKit = CharacterService.getKit
	Net.get("SelectCharacter").OnServerEvent:Connect(onSelect)
	-- verrou de combat : les deux camps de chaque échange (comme AFKService)
	local function stamp(a, b)
		local t = os.clock()
		if typeof(a) == "Instance" then
			lastCombat[a] = t
		end
		if typeof(b) == "Instance" then
			lastCombat[b] = t
		end
	end
	Signals.Hit:Connect(stamp) -- (attacker, victim, damage, info)
	Signals.Blocked:Connect(stamp) -- (attacker, victim)
	Signals.GuardBroken:Connect(stamp) -- (victim, attacker)
	Signals.Parried:Connect(stamp) -- (defender, attacker)
	Net.get("Transform").OnServerEvent:Connect(transform)
	table.insert(PlayerService.afterSpawn, function(player, character)
		-- changement demandé en combat : appliqué maintenant (perso neuf)
		local queued = pending[player]
		pending[player] = nil
		player:SetAttribute("PendingCharacter", nil)
		if queued and usable(player, queued) then
			player:SetAttribute("AdminChar", nil)
			player:SetAttribute("CharacterName", queued)
		end
		local name = player:GetAttribute("CharacterName") or DEFAULT
		if not usable(player, name) then
			name = DEFAULT
			player:SetAttribute("CharacterName", name)
		end
		CharacterService.apply(character, name)
		-- la jauge d'Overtime n'est pas perdue à la mort (sauvegardée sur le joueur)
		character:SetAttribute("Overtime", player:GetAttribute("OvertimeBank") or 0)
	end)
	Signals.Died:Connect(function(character)
		if character:GetAttribute("Transformed") then
			character:SetAttribute("Transformed", false)
		end
	end)
end

return CharacterService
