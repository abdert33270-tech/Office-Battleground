--[[
	CombatService — autorité serveur sur tous les coups. Système « ABA » (voir Config/Combat et docs/Combat-ABA.md).
	- Chaîne de 5 M1 (1-4 légers avec vrai hitstun, 5e = FINISHER lourd qui renverse), cadence lente et lisible.
	  Variantes du 5e coup : Espace maintenu = UPPERCUT (+ saut automatique, 3 M1 en l'air, le 3e = DOWNSLAM),
	  en l'air = DOWNSLAM. Dash avant + M1 = DASH STRIKE (lourd, recharge).
	- Dash directionnel (avant / arrière / côté), EVASIVE (Q pendant un hitstun, longue recharge).
	- Block avec jauge de garde, PERFECT BLOCK (parade), GUARD BREAK (coup lourd sur un block normal ou jauge vide).
	- Renversé (knockdown) après les gros coups : intouchable puis relevé invulnérable (pas de jongle infini).
	- applyHit() = point d'entrée UNIQUE de tous les dégâts du jeu (M1, objets, lancers, attaques, événements).
	  Ignore les coups quand la victime ou l'attaquant est en zone sûre (attribut SafeZone).
	- Hit-stop serveur (le recul part après le gel), éjection en tournoyant, wall splat, décor cassable.
]]
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.Combat)
local Net = require(Shared.Modules.Net)
local Hitbox = require(Shared.Modules.Hitbox)
local CharacterState = require(script.Parent.CharacterState)
local Signals = require(script.Parent.Signals)

local CombatService = {}
CombatService.Priority = 10
CombatService.itemUseHandler = nil -- branché par ItemService
CombatService.disarm = nil         -- branché par ItemService : function(character) (parade = désarme)
CombatService.damageMods = {}      -- passifs / statuts : function(p) qui modifie p.damage, p.knockback...

local FX, Anim
local M1 = CombatConfig.M1
local TOL = 0.1 -- tolérance (s) sur les délais serveur : gigue réseau entre deux clics

local function now()
	return workspace:GetServerTimeNow()
end

local function flatUnit(v: Vector3, fallback: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.05 then
		f = Vector3.new(fallback.X, 0, fallback.Z)
	end
	return f.Magnitude > 0 and f.Unit or Vector3.new(0, 0, -1)
end
CombatService.flatUnit = flatUnit

local function zones()
	local m = script.Parent:FindFirstChild("ZoneService")
	return m and require(m)
end

------------------------------------------------------------------------
-- Physique : recul, suspension aérienne, tournoiement
------------------------------------------------------------------------
local function rootAttachment(root)
	local att = root:FindFirstChild("KBAtt")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "KBAtt"
		att.Parent = root
	end
	return att
end

-- suspend la vitesse verticale (jongles aériens)
function CombatService.airStall(character: Model, duration: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local old = root:FindFirstChild("AirStall")
	if old then
		old:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "AirStall"
	lv.Attachment0 = rootAttachment(root)
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	lv.LineDirection = Vector3.yAxis
	lv.LineVelocity = 1.5
	lv.MaxForce = 1e6
	lv.Parent = root
	Debris:AddItem(lv, duration)
end

------------------------------------------------------------------------
-- LAISSE DE COMBO : pendant les M1 (coups 1-3) et les jongles, la victime reste collée devant l'attaquant
-- (AlignPosition horizontale créée par le serveur : elle se réplique et est simulée par le propriétaire réseau,
--  donc ça marche pour les joueurs comme pour le mannequin). Relâchée au finisher, au lanceur, au slam,
--  sur garde/parade, quand l'attaquant est étourdi, trop loin, ou à la fin de la fenêtre.
------------------------------------------------------------------------
local tethers = {} -- [victime] = { a = attaquant, untilT = os.clock(), align = AlignPosition }
local function releaseTether(victim)
	local d = victim and tethers[victim]
	if d then
		tethers[victim] = nil
		if d.align then
			d.align:Destroy()
		end
	end
end
CombatService.releaseTether = releaseTether

local function setTether(victim: Model, attacker: Model, duration: number)
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not root or not attacker or attacker == victim then
		return
	end
	local d = tethers[victim]
	if d and (d.a ~= attacker or not d.align or not d.align.Parent) then
		releaseTether(victim)
		d = nil
	end
	if not d then
		local ap = Instance.new("AlignPosition")
		ap.Name = "ComboTether"
		ap.Mode = Enum.PositionAlignmentMode.OneAttachment
		ap.Attachment0 = rootAttachment(root)
		ap.ApplyAtCenterOfMass = true
		ap.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		pcall(function()
			ap.ForceRelativeTo = Enum.ActuatorRelativeTo.World
		end)
		ap.MaxAxesForce = Vector3.new(4e5, 0, 4e5) -- horizontal seulement : la hauteur reste aux lanceurs / suspensions
		ap.MaxVelocity = 80
		ap.Responsiveness = 70
		ap.Position = root.Position
		ap.Parent = root
		d = { a = attacker, align = ap, untilT = 0 }
		tethers[victim] = d
	end
	d.untilT = math.max(d.untilT, os.clock() + duration)
end
CombatService.setTether = setTether

local TETHER_DIST, TETHER_BREAK = 3.2, 9
local function updateTethers()
	local t = os.clock()
	for victim, d in pairs(tethers) do
		local root = victim.Parent and victim:FindFirstChild("HumanoidRootPart")
		local aRoot = d.a and d.a.Parent and d.a:FindFirstChild("HumanoidRootPart")
		local ok = root and aRoot and d.align and d.align.Parent and t < d.untilT
			and CharacterState.isAlive(victim) and CharacterState.isAlive(d.a) and not CharacterState.isStunned(d.a)
		if ok then
			local flat = Vector3.new(root.Position.X - aRoot.Position.X, 0, root.Position.Z - aRoot.Position.Z)
			ok = flat.Magnitude <= TETHER_BREAK
		end
		if ok then
			local look = flatUnit(aRoot.CFrame.LookVector, root.Position - aRoot.Position)
			local target = aRoot.Position + look * TETHER_DIST
			d.align.Position = Vector3.new(target.X, root.Position.Y, target.Z)
		else
			releaseTether(victim)
		end
	end
end

local function spin(root: BasePart, power: number)
	local av = Instance.new("AngularVelocity")
	av.Name = "Spin"
	av.Attachment0 = rootAttachment(root)
	av.MaxTorque = 1e6
	av.AngularVelocity = Vector3.new(math.random(-10, 10), math.random(-6, 6), math.random(-10, 10)).Unit * (8 + power * 6)
	av.RelativeTo = Enum.ActuatorRelativeTo.World
	av.Parent = root
	Debris:AddItem(av, 0.35)
end

local splatParams = RaycastParams.new()
splatParams.FilterType = Enum.RaycastFilterType.Exclude

-- surveille une victime éjectée : wall splat + décor cassé sur son passage
local function watchFlight(victim: Model, attacker: Model?, duration: number)
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local t0 = os.clock()
	local splatted = false
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not root.Parent or os.clock() - t0 > duration or splatted then
			conn:Disconnect()
			return
		end
		local vel = root.AssemblyLinearVelocity
		local flat = Vector3.new(vel.X, 0, vel.Z)
		local speed = flat.Magnitude
		local Z = zones()
		if Z and vel.Magnitude > 22 then
			Z.shatterAround(root.Position, 3.5, vel)
		end
		if speed < CombatConfig.WallSplat.MinSpeed then
			return
		end
		local exclude = { workspace:FindFirstChild("ActiveItems"), workspace:FindFirstChild("FX"), workspace:FindFirstChild("Dummies") }
		for _, p in ipairs(Players:GetPlayers()) do
			if p.Character then
				table.insert(exclude, p.Character)
			end
		end
		splatParams.FilterDescendantsInstances = exclude
		local result = workspace:Raycast(root.Position, flat.Unit * math.max(3, speed * dt * 2.5), splatParams)
		if result and result.Instance.CanCollide and math.abs(result.Normal.Y) < 0.6 then
			if Z and Z.isBreakable(result.Instance) then
				Z.shatterModel(Z.isBreakable(result.Instance), vel)
				return
			end
			splatted = true
			conn:Disconnect()
			for _, n in ipairs({ "KB", "Spin" }) do
				local c = root:FindFirstChild(n)
				if c then
					c:Destroy()
				end
			end
			local bounce = result.Normal * 16 + Vector3.new(0, 12, 0)
			local lv = Instance.new("LinearVelocity")
			lv.Name = "KB"
			lv.Attachment0 = rootAttachment(root)
			lv.MaxForce = 1e6
			lv.VectorVelocity = bounce
			lv.Parent = root
			Debris:AddItem(lv, 0.1)
			local hum = victim:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and not CharacterState.isProtected(victim) and not CharacterState.inSafeZone(victim) then
				CharacterState.recordHit(victim, attacker, "Wall", attacker and "Combat" or "Event")
				hum:TakeDamage(CombatConfig.WallSplat.Damage)
				CharacterState.stun(victim, CombatConfig.WallSplat.Stun)
			end
			FX:FireAllClients({ k = "WallSplat", p = result.Position, n = result.Normal, v = victim, a = attacker, d = CombatConfig.WallSplat.Damage })
		end
	end)
end

local function knockback(victim: Model, velocity: Vector3, tumble: boolean, stun: number, attacker: Model?, power: number?)
	local root = victim:FindFirstChild("HumanoidRootPart")
	local hum = victim:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end
	local old = root:FindFirstChild("KB")
	if old then
		old:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "KB"
	lv.Attachment0 = rootAttachment(root)
	lv.MaxForce = 1e7
	lv.VectorVelocity = velocity
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	Debris:AddItem(lv, tumble and 0.2 or 0.12)
	if tumble then
		hum.PlatformStand = true
		spin(root, power or 0.5)
		task.delay(math.max(0.55, stun), function()
			if hum.Parent and hum.Health > 0 and not CharacterState.isKnockedDown(victim) then
				hum.PlatformStand = false
			end
		end)
	end
	if velocity.Magnitude >= CombatConfig.WallSplat.MinSpeed then
		watchFlight(victim, attacker, 0.9)
	end
end
CombatService.knockback = knockback

-- renversé : poussière + « thud » quand la victime touche le sol (FXController « Knockdown »).
-- Elle est éjectée d'abord : on attend la retombée (rayon vers le bas), au plus jusqu'à la fin du renversé.
local downParams = RaycastParams.new()
downParams.FilterType = Enum.RaycastFilterType.Exclude
local function knockdownFX(victim: Model, delay: number)
	task.delay(delay + 0.12, function()
		local root = victim.Parent and victim:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local excl = { workspace:FindFirstChild("FX"), workspace:FindFirstChild("ActiveItems") }
		for _, c in ipairs(Hitbox.characters()) do
			table.insert(excl, c)
		end
		downParams.FilterDescendantsInstances = excl
		local t0 = os.clock()
		while root.Parent and os.clock() - t0 < 1.2 and CharacterState.isKnockedDown(victim) do
			if root.AssemblyLinearVelocity.Y <= 2 and workspace:Raycast(root.Position, Vector3.new(0, -3.6, 0), downParams) then
				break
			end
			task.wait(0.03)
		end
		if root.Parent and CharacterState.isAlive(victim) and CharacterState.isKnockedDown(victim) then
			FX:FireAllClients({ type = "Knockdown", v = victim, p = root.Position })
		end
	end)
end

-- écrase la victime au sol (Downslam)
local function slam(victim: Model, attacker: Model?, spec)
	local root = victim:FindFirstChild("HumanoidRootPart")
	local hum = victim:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return
	end
	local st = root:FindFirstChild("AirStall")
	if st then
		st:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "KB"
	lv.Attachment0 = rootAttachment(root)
	lv.MaxForce = 1e7
	lv.VectorVelocity = Vector3.new(0, -spec.SlamSpeed, 0)
	lv.Parent = root
	hum.PlatformStand = true
	-- sol visé : raycast vers le bas (FloorMaterial n'est pas fiable en PlatformStand,
	-- et à 150 studs/s on traversait les dalles fines)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local excl = { victim }
	if attacker then
		table.insert(excl, attacker)
	end
	for _, folder in ipairs({ workspace:FindFirstChild("Dummies"), workspace:FindFirstChild("Items") }) do
		table.insert(excl, folder)
	end
	for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
		if pl.Character then
			table.insert(excl, pl.Character)
		end
	end
	rp.FilterDescendantsInstances = excl
	local hitRes = workspace:Raycast(root.Position, Vector3.new(0, -120, 0), rp)
	local groundY = hitRes and hitRes.Position.Y or nil
	local t0 = os.clock()
	local conn
	conn = RunService.Heartbeat:Connect(function()
		local near = groundY and root.Position.Y - groundY <= 3.4
		local landed = near or (not groundY and hum.FloorMaterial ~= Enum.Material.Air and os.clock() - t0 > 0.05)
		if landed or os.clock() - t0 > (groundY and 0.9 or 0.35) or not root.Parent then
			conn:Disconnect()
			lv:Destroy()
			if not root.Parent then
				return
			end
			if groundY then
				-- on pose la victime pile sur le sol (jamais en dessous)
				root.AssemblyLinearVelocity = Vector3.zero
				local p = root.Position
				root.CFrame = root.CFrame.Rotation + Vector3.new(p.X, groundY + 2.6, p.Z)
			end
			local ground = groundY and Vector3.new(root.Position.X, groundY, root.Position.Z) or (root.Position - Vector3.new(0, 2.8, 0))
			FX:FireAllClients({ k = "Slam", p = ground, v = victim, a = attacker })
			local Z = zones()
			if Z then
				Z.shatterAround(ground, 7, Vector3.new(0, 30, 0))
			end
			if spec.Pin then
				-- plaqué au sol : il reste allongé, étourdi
				FX:FireAllClients({ k = "Pinned", p = ground, v = victim, a = attacker })
			end
			if spec.Knockdown then
				CharacterState.knockdown(victim, CombatConfig.Knockdown.Duration)
				-- (pas de « Knockdown » ici : l'effet « Slam » fait déjà poussière + onde au même endroit)
			elseif spec.Pin then
				CharacterState.stun(victim, spec.Stun)
			elseif (spec.BounceUp or 0) > 0 then
				knockback(victim, Vector3.new(0, spec.BounceUp, 0), false, spec.Stun, attacker)
			end
			if not spec.Knockdown then
				task.delay(math.max(0.6, spec.Stun), function()
					if hum.Parent and hum.Health > 0 and not CharacterState.isKnockedDown(victim) then
						hum.PlatformStand = false
					end
				end)
			end
		end
	end)
end

------------------------------------------------------------------------
-- Overtime (jauge de transformation)
------------------------------------------------------------------------
function CombatService.addOvertime(character: Model, amount: number)
	if not character or character:GetAttribute("Transformed") then
		return
	end
	local v = math.clamp((character:GetAttribute("Overtime") or 0) + amount, 0, CombatConfig.Overtime.Max)
	character:SetAttribute("Overtime", v)
	-- la progression est gardée sur le joueur : on ne la perd pas en mourant
	local pl = Players:GetPlayerFromCharacter(character)
	if pl then
		pl:SetAttribute("OvertimeBank", v)
	end
end

------------------------------------------------------------------------
-- Guard break : le block est cassé (coup lourd sur un block normal, ou jauge de garde vide)
------------------------------------------------------------------------
local function guardBreak(victim: Model, attacker: Model?, p, root: BasePart, hum: Humanoid)
	releaseTether(victim)
	CharacterState.guardBreak(victim, CombatConfig.Block.GuardBreakStun)
	FX:FireAllClients({ k = "GuardBreak", p = root.Position + Vector3.new(0, 1.5, 0), v = victim, a = attacker })
	Anim:FireAllClients(victim, "GuardBroken")
	local chip = (p.damage or 0) * (1 - CombatConfig.Block.Reduction)
	if chip > 0 then
		CharacterState.recordHit(victim, attacker, p.weapon, p.cause)
		hum:TakeDamage(chip)
	end
	knockback(victim, (p.dir or Vector3.new(0, 0, -1)) * 9, false, 0.1, attacker)
	if attacker then
		CombatService.addOvertime(attacker, (p.damage or 0) * CombatConfig.Overtime.DealMult)
	end
	Signals.GuardBroken:Fire(victim, attacker)
end

------------------------------------------------------------------------
-- applyHit : point d'entrée unique des dégâts
--[[
	p = {
		attacker: Model?, victim: Model, damage, dir: Vector3 (horizontal, de l'attaquant vers la victime),
		knockback, up, stun, category, power, words?, material?, hitPos?, weapon?, cause?, seq?,
		unblockable?, air? (suspension aérienne), launch? (Vector3 : vitesse imposée), slam? (spec Downslam),
		itemId?, kitchen?, finisher?, noFlinch?, pin?,
		heavy? (casse le block ; sinon déduit de category == "Heavy"), knockdown? (renverse la victime)
	}
	Retourne "Hit" | "Blocked" | "Parried" | "GuardBreak" | nil
]]
------------------------------------------------------------------------
function CombatService.applyHit(p)
	local victim = p.victim
	local hum = victim and victim:FindFirstChildOfClass("Humanoid")
	local root = victim and victim:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return nil
	end
	local vs = CharacterState.get(victim)
	-- coup fatal déjà engagé (hit-stop K.O.) : plus rien ne s'empile, la mort est assurée
	if vs.pendingKO then
		return nil
	end
	if CharacterState.isProtected(victim) then
		return nil
	end
	local attacker = p.attacker
	-- zone sûre (zone AFK) : personne n'y frappe ni n'y est frappé
	if CharacterState.inSafeZone(victim) or CharacterState.inSafeZone(attacker) then
		return nil
	end
	-- renversé : intouchable (sauf coups imparables = ultimes) -> pas de jongle infini
	if not p.unblockable and CharacterState.isKnockedDown(victim) then
		return nil
	end
	-- laisse de combo : seul un coup « collant » du même attaquant la garde, tout autre coup la relâche
	if tethers[victim] and not (p.tether and attacker and tethers[victim].a == attacker) then
		releaseTether(victim)
	end
	p.dir = p.dir or Vector3.new(0, 0, -1)
	p.damage = math.max(0, p.damage or 0)
	p.knockback = p.knockback or 5
	for _, mod in ipairs(CombatService.damageMods) do
		mod(p)
	end
	local B = CombatConfig.Block
	local heavy = p.heavy == true or p.category == "Heavy"

	-- garde : seulement contre un coup de face
	if vs.blocking and not p.unblockable then
		local frontal = root.CFrame.LookVector:Dot(-p.dir) > 0.1
		if frontal then
			releaseTether(victim)
			local t = os.clock()
			if t - vs.blockStart <= (B.PerfectWindow or B.ParryWindow) then
				-- PERFECT BLOCK (parade) : marche aussi contre les coups lourds ; l'attaquant est repoussé, étourdi, désarmé
				vs.blockStart = -10
				vs.parryAttempt = nil -- tentative réussie : pas de verrou anti-spam
				-- un seul effet (FXController « PerfectBlock » : éclair, anneau, PERFECT!, sons) ; la réaction de
				-- l'attaquant (anim + vertige) vient de l'Anim « HitHeavy » et de son attribut DizzyUntil (stun)
				FX:FireAllClients({ type = "PerfectBlock", character = victim, a = attacker, p = root.Position + p.dir * -1.5 + Vector3.new(0, 1, 0) })
				Anim:FireAllClients(victim, "PerfectBlock")
				if attacker then
					attacker:SetAttribute("ParriedAt", now())
					Anim:FireAllClients(attacker, "HitHeavy")
				end
				if attacker and CharacterState.isAlive(attacker) then
					local aRoot = attacker:FindFirstChild("HumanoidRootPart")
					releaseTether(attacker)
					CharacterState.stun(attacker, B.ParryStun)
					if aRoot then
						knockback(attacker, -p.dir * B.ParryKnockback + Vector3.new(0, 10, 0), false, B.ParryStun, victim)
					end
					if CombatService.disarm then
						CombatService.disarm(attacker)
					end
					Signals.Parried:Fire(victim, attacker)
				end
				CombatService.addOvertime(victim, CombatConfig.Overtime.Parry or 5)
				return "Parried"
			end
			-- GUARD BREAK : un coup lourd casse un block normal (sauf garde spéciale type Tray Guard)
			if heavy and B.HeavyBreaks and not p.trayGuard then
				guardBreak(victim, attacker, p, root, hum)
				return "GuardBreak"
			end
			-- BLOCK : dégâts réduits, la jauge de garde s'use
			local left = p.trayGuard and CharacterState.guardNow(victim) or CharacterState.drainGuard(victim, p.damage)
			if left <= 0 then
				guardBreak(victim, attacker, p, root, hum)
				return "GuardBreak"
			end
			local chip = p.trayGuard and 0 or p.damage * (1 - B.Reduction)
			-- étincelles orientées vers l'attaquant (dir = normale de rebond, du bloqueur vers l'attaquant)
			FX:FireAllClients({ type = "BlockHit", p = root.Position + p.dir * -1.2 + Vector3.new(0, 1, 0), dir = -p.dir, v = victim, a = attacker, d = chip })
			if chip > 0 then
				CharacterState.recordHit(victim, attacker, p.weapon, p.cause)
				hum:TakeDamage(chip)
			end
			knockback(victim, p.dir * 6, false, 0.1, attacker)
			if Signals.Blocked then
				Signals.Blocked:Fire(attacker, victim)
			end
			return "Blocked"
		end
	end

	-- ANTI-INFINI (CombatConfig.ComboCap) : combo vrai trop long -> ce coup renverse de force
	local C = CombatConfig.ComboCap
	local tNow = now()
	if not (vs.chainStart and tNow < vs.stunUntil + C.Grace) then
		vs.chainStart, vs.chainLinks = tNow, 0 -- la victime avait récupéré : nouveau combo
	end
	if p.tether then
		vs.chainLinks += 1
	end
	if not p.unblockable and not p.knockdown and (vs.chainLinks >= C.MaxLinks or tNow - vs.chainStart >= C.MaxTime) then
		p.knockdown, p.tether, p.air, p.launch = true, nil, nil, nil
		if p.pin and not p.slam then
			p.slam = { SlamSpeed = 150, Stun = CombatConfig.PinStun, BounceUp = 0, Pin = true }
		end
		if p.slam then
			p.slam = table.clone(p.slam) -- (la spec peut être une table de Config partagée)
			p.slam.Knockdown = true
		else
			p.knockback = math.max(p.knockback or 0, C.Knockback)
			p.up = math.max(p.up or 0, C.Up)
		end
		p.words = C.Words
	end
	if p.knockdown then
		vs.chainStart, vs.chainLinks = nil, 0
	end

	local damage = p.damage
	local ko = hum.Health - damage <= 0
	local category = p.category or "Light"
	local hitStop = ko and CombatConfig.HitStop.KO
		or (heavy and CombatConfig.HitStop.Heavy)
		or CombatConfig.HitStop.Light

	CharacterState.recordHit(victim, attacker, p.weapon, p.cause)
	local combo = 0
	if attacker then
		combo = CharacterState.addCombo(attacker, victim)
		CombatService.addOvertime(attacker, damage * CombatConfig.Overtime.DealMult)
	end
	CombatService.addOvertime(victim, damage * CombatConfig.Overtime.TakeMult)

	local reaction = (p.slam or p.pin) and "Slam" or (p.launch and "Launch") or ((heavy or p.knockback >= 30) and "Heavy" or "Light")
	FX:FireAllClients({
		k = "Hit", a = attacker, v = victim, p = p.hitPos or root.Position,
		c = heavy and category ~= "Heavy" and "Heavy" or category, pw = p.power or 0.4, d = damage, w = p.words, m = p.material,
		ko = ko, seq = p.seq, r = reaction, combo = combo, fin = p.finisher,
	})
	Signals.Hit:Fire(attacker, victim, damage, { weapon = p.weapon, category = category, combo = combo, finisher = p.finisher })

	-- gel du mannequin pendant le hit-stop (les joueurs se gèlent eux-mêmes côté client)
	if victim:GetAttribute("IsDummy") then
		root.Anchored = true
		task.delay(hitStop, function()
			if root.Parent then
				root.Anchored = false
			end
		end)
	end

	if ko then
		-- coup fatal ENGAGÉ : la victime est figée (pas d'EVASIVE, pas d'autres coups empilés) et meurt à la fin du
		-- hit-stop même si une bulle (ForceField) apparaît entre-temps (Health posé directement, pas TakeDamage).
		-- (Plot Armor de Bacon agit avant, dans damageMods : un coup qu'elle sauve n'est jamais « ko » ici.)
		vs.pendingKO = true
		victim:SetAttribute("PendingKO", true)
		releaseTether(victim)
		CharacterState.stun(victim, hitStop + 0.2)
		victim:SetAttribute("KOLaunch", p.dir * CombatConfig.KOLaunch.Speed + Vector3.new(0, CombatConfig.KOLaunch.Up, 0))
		task.delay(hitStop, function()
			if hum.Parent and hum.Health > 0 then
				CharacterState.recordHit(victim, attacker, p.weapon, p.cause) -- le tueur reste celui du coup fatal
				hum.Health = 0
			end
			vs.pendingKO = false
			if victim.Parent then
				victim:SetAttribute("PendingKO", nil)
			end
		end)
		return "Hit"
	end
	hum:TakeDamage(damage)
	CharacterState.stun(victim, p.stun or 0.3)
	if p.knockdown then
		releaseTether(victim)
		if p.slam then
			-- intouchable pendant la chute ; le vrai renversé démarre à l'atterrissage (slam)
			victim:SetAttribute("KnockdownUntil", math.max(victim:GetAttribute("KnockdownUntil") or 0, now() + hitStop + 1))
		else
			CharacterState.knockdown(victim, hitStop + CombatConfig.Knockdown.Duration)
			knockdownFX(victim, hitStop)
		end
	elseif p.tether and attacker then
		setTether(victim, attacker, math.min(p.stun or 0.6, 0.8) + 0.12)
	end

	task.delay(hitStop, function()
		if not victim.Parent then
			return
		end
		if p.pin and not p.slam then
			p.slam = { SlamSpeed = 150, Stun = CombatConfig.PinStun, BounceUp = 0, Pin = true }
		end
		if p.slam then
			slam(victim, attacker, p.slam)
		elseif p.launch then
			knockback(victim, p.launch, false, p.stun or 1, attacker)
			hum.PlatformStand = true
			task.delay(math.max(0.6, p.stun or 1), function()
				if hum.Parent and hum.Health > 0 and not CharacterState.isKnockedDown(victim) then
					hum.PlatformStand = false
				end
			end)
		else
			local kb = p.knockback
			local vel = p.dir * kb + Vector3.new(0, p.up or 0, 0)
			knockback(victim, vel, kb >= 35, p.stun or 0.3, attacker, p.power)
		end
		if p.slam then
			-- fin de jongle : la victime est écrasée, l'attaquant est libéré de la suspension et retombe
			if attacker then
				local aRoot = attacker:FindFirstChild("HumanoidRootPart")
				if aRoot then
					local c = aRoot:FindFirstChild("AirStall")
					if c then
						c:Destroy()
					end
				end
				attacker:SetAttribute("AirRelease", now()) -- le client de l'attaquant retire ses suspensions locales
			end
		elseif p.air then
			CombatService.airStall(victim, CombatConfig.Air.Stall)
			if attacker then
				CombatService.airStall(attacker, CombatConfig.Air.Stall)
			end
		end
	end)
	return "Hit"
end

-- Dégâts sur la durée (brûlure du café...)
function CombatService.burn(victim: Model, attacker: Model?, burn)
	task.spawn(function()
		for _ = 1, burn.Ticks do
			task.wait(burn.Interval)
			local hum = victim:FindFirstChildOfClass("Humanoid")
			local head = victim:FindFirstChild("Head")
			if not hum or hum.Health <= 0 or not head then
				return
			end
			if not CharacterState.isProtected(victim) and not CharacterState.inSafeZone(victim) then
				CharacterState.recordHit(victim, attacker, "Burn", attacker and "Combat" or "Event")
				hum:TakeDamage(burn.Damage)
				FX:FireAllClients({ k = "Burn", v = victim, p = head.Position, d = burn.Damage })
			end
		end
	end)
end

-- Hitbox devant un personnage -> applique les coups. Utilisé par le M1, les objets et les attaques.
-- spec : HitboxOffset, HitboxSize, MaxTargets, Damage, Knockback, KnockUp, Stun, Category, Power, Words, Material,
--        Launch (Vector3 relatif : X = recul, Y = hauteur), Air, Slam, Unblockable, Weapon, ItemId, Kitchen, FinisherName,
--        Heavy, Knockdown, Tether, ComboTarget
-- Retourne : landed (touchés + bloqués + gardes cassées), hits (vraiment touchés)
function CombatService.swing(attacker: Model, spec, seq)
	local cf = Hitbox.frontCFrame(attacker, spec.HitboxOffset)
	if not cf then
		return {}, {}
	end
	local size = spec.HitboxSize + Vector3.one * CombatConfig.LatencyTolerance
	local hits = Hitbox.box(cf, size, attacker, spec.MaxTargets or 3)
	-- victime tenue en laisse par CE combo : le coup suivant la touche toujours si elle est à portée
	-- (l'attaquant peut tourner / marcher, la laisse a un léger retard réseau)
	if spec.ComboTarget and tethers[spec.ComboTarget] and tethers[spec.ComboTarget].a == attacker
		and not table.find(hits, spec.ComboTarget) then
		local ar, vr = attacker:FindFirstChild("HumanoidRootPart"), spec.ComboTarget:FindFirstChild("HumanoidRootPart")
		if ar and vr and (vr.Position - ar.Position).Magnitude <= 7 then
			table.insert(hits, spec.ComboTarget)
		end
	end
	local aRoot = attacker:FindFirstChild("HumanoidRootPart")
	local landed, really = {}, {}
	for _, victim in ipairs(hits) do
		local vRoot = victim:FindFirstChild("HumanoidRootPart")
		if vRoot and aRoot then
			local dir = flatUnit(vRoot.Position - aRoot.Position, aRoot.CFrame.LookVector)
			local p = {
				attacker = attacker, victim = victim, damage = spec.Damage, dir = dir,
				knockback = spec.Knockback, up = spec.KnockUp, stun = spec.Stun,
				category = spec.Category, power = spec.Power, words = spec.Words, material = spec.Material,
				seq = seq, unblockable = spec.Unblockable, weapon = spec.Weapon, itemId = spec.ItemId, kitchen = spec.Kitchen,
				tether = spec.Tether, heavy = spec.Heavy, knockdown = spec.Knockdown,
				hitPos = vRoot.Position:Lerp(aRoot.Position, 0.3) + Vector3.new(0, 0.6, 0),
			}
			if spec.Launch then
				p.launch = dir * spec.Launch.X + Vector3.new(0, spec.Launch.Y, 0)
			end
			if spec.Slam then
				p.slam = spec.Slam
			end
			-- jongle : si les deux sont en l'air, on suspend
			if spec.Air or (CharacterState.isAirborne(attacker) and CharacterState.isAirborne(victim)) then
				p.air = true
			end
			-- finisher d'objet : on termine un combo avec un objet
			if spec.FinisherName and CharacterState.inComboOn(attacker, victim) then
				local F = CombatConfig.ItemFinisher
				p.damage *= F.DamageMult
				p.knockback = (p.knockback or 0) * F.KnockbackMult
				p.power = (p.power or 0.5) + 0.4
				p.category = "Heavy"
				p.finisher = true
				p.words = { string.upper(spec.FinisherName) .. " COMBO!" }
			end
			local result = CombatService.applyHit(p)
			if result == "Hit" or result == "Blocked" or result == "GuardBreak" then
				table.insert(landed, victim)
				if result == "Hit" then
					table.insert(really, victim)
				end
			elseif result == "Parried" then
				break
			end
		end
	end
	return landed, really
end

------------------------------------------------------------------------
-- Peut-on commencer une attaque ? (M1, dash, attaques de perso : AbilityService peut l'appeler)
------------------------------------------------------------------------
function CombatService.canStartAttack(character: Model?): boolean
	if not character or not CharacterState.isAlive(character) or CharacterState.isStunned(character) then
		return false
	end
	if CharacterState.inSafeZone(character) then
		return false
	end
	local s = CharacterState.get(character)
	return os.clock() >= (s.busyUntil or 0) - TOL and not s.blocking
end

------------------------------------------------------------------------
-- M1 et variantes (chaîne de 5, uppercut, jongle, downslam, dash strike)
------------------------------------------------------------------------
local function slowAttacker(character: Model, duration: number)
	CharacterState.setSpeedMod(character, "Attack", CombatConfig.AttackSlow, duration)
end

-- récupération après un coup : cooldown = délai avant le prochain M1 ;
-- heavy = endlag (pas de dash ni de block pendant toute la durée), sinon le block revient après DropEndlag
local function setRecovery(character: Model, s, t: number, cooldown: number, heavy: boolean)
	s.nextAttack = t + cooldown
	s.busyUntil = t + cooldown + (heavy and 0 or M1.DropEndlag)
	s.endlagUntil = heavy and (t + cooldown) or 0
	-- endlag visible par tous (ProcAnim : pose « essoufflé » tant que EndlagUntil n'est pas passé)
	character:SetAttribute("EndlagUntil", heavy and (now() + cooldown) or 0)
	slowAttacker(character, cooldown + 0.05)
end

-- index du coup dans la chaîne. Le client envoie le sien (want) : accepté s'il continue la chaîne serveur
-- (ou repart de 1) ; sinon on suit la logique serveur. Impossible de sauter directement au 5e coup.
local function nextIndex(s, t: number, want): number
	local continuing = s.combo > 0 and s.combo < M1.Hits and t - s.lastM1 <= M1.ComboReset + 0.3
	local i
	if want == 1 then
		i = 1
	elseif continuing and want == s.combo + 1 then
		i = want
	elseif continuing and t - s.lastM1 <= M1.ComboReset then
		i = s.combo + 1
	else
		i = 1
	end
	s.lastM1 = t
	s.combo = (i >= M1.Hits) and 0 or i
	return i
end

local function downslamSpec()
	local S = CombatConfig.Downslam
	local A = CombatConfig.Air
	return {
		HitboxOffset = A.HitboxOffset, HitboxSize = A.HitboxSize, MaxTargets = 2, Damage = S.Damage,
		Knockback = 0, Stun = S.Stun, Category = "Heavy", Power = S.Power, Words = S.Words, Slam = S, Weapon = "Downslam",
		Knockdown = S.Knockdown, Heavy = true,
	}
end

local function airSpec(i: number)
	local A = CombatConfig.Air
	return {
		HitboxOffset = A.HitboxOffset, HitboxSize = A.HitboxSize, MaxTargets = 2, Damage = A.Damage[((i - 1) % #A.Damage) + 1],
		Knockback = 3, KnockUp = 2, Stun = A.Stun, Category = "Light", Power = 0.4, Air = true, Weapon = "Punch",
		Tether = true, -- la victime reste devant l'attaquant en l'air
	}
end

local function doM1(player: Player, character: Model, seq: number, mods)
	local s = CharacterState.get(character)
	local t = os.clock()
	if t < s.nextAttack - TOL or s.blocking or CharacterState.inSafeZone(character) then
		return
	end
	-- en l'air : vu par le serveur, ou annoncé par le client et plausible (jongle d'uppercut en cours, ou vitesse
	-- verticale répliquée non nulle : la physique du joueur arrive au serveur avec un peu de retard)
	local cRoot = character:FindFirstChild("HumanoidRootPart")
	local airborne = CharacterState.isAirborne(character)
		or (mods.air and (t < s.airChainUntil or (cRoot ~= nil and math.abs(cRoot.AssemblyLinearVelocity.Y) > 3)))
	local DS = CombatConfig.DashStrike
	local U = CombatConfig.Uppercut
	local spec, anim, windup, onLanded

	if not airborne and s.lastDashKind == "F" and t - s.lastDash <= DS.Window + TOL and t >= s.nextDashStrike - TOL then
		-- DASH STRIKE : dash avant + M1
		s.nextDashStrike = t + DS.Cooldown
		character:SetAttribute("CDDashStrike", now() + DS.Cooldown)
		s.lastDash = -10
		s.combo = 0
		setRecovery(character, s, t, DS.Endlag, true)
		anim, windup = DS.Anim, DS.Windup
		spec = {
			HitboxOffset = DS.HitboxOffset, HitboxSize = DS.HitboxSize, MaxTargets = 3, Damage = DS.Damage,
			Knockback = DS.Knockback, KnockUp = DS.KnockUp, Stun = DS.Stun, Category = "Heavy", Power = DS.Power,
			Words = DS.Words, Weapon = "Dash Strike", Heavy = true, Knockdown = true,
		}
	elseif airborne and t < s.airChainUntil then
		-- jongle après un uppercut : AirHits coups, le dernier = DOWNSLAM
		s.airCombo += 1
		if s.airCombo >= U.AirHits then
			s.airCombo, s.airChainUntil = 0, 0
			setRecovery(character, s, t, CombatConfig.Downslam.Endlag, true)
			anim, windup = CombatConfig.Downslam.Anim, CombatConfig.Downslam.Windup
			spec = downslamSpec()
		else
			setRecovery(character, s, t, CombatConfig.Air.Cooldown, false)
			anim, windup = CombatConfig.Air.Anim[((s.airCombo - 1) % #CombatConfig.Air.Anim) + 1], CombatConfig.Air.Windup
			spec = airSpec(s.airCombo)
		end
	elseif airborne then
		-- chaîne de M1 en l'air : le 5e coup devient un DOWNSLAM
		local i = nextIndex(s, t, mods.i)
		if i >= M1.Hits then
			setRecovery(character, s, t, CombatConfig.Downslam.Endlag, true)
			anim, windup = CombatConfig.Downslam.Anim, CombatConfig.Downslam.Windup
			spec = downslamSpec()
		else
			setRecovery(character, s, t, M1.Cooldown[i], false)
			anim, windup = CombatConfig.Air.Anim[((i - 1) % #CombatConfig.Air.Anim) + 1], CombatConfig.Air.Windup
			spec = airSpec(i)
		end
	else
		local i = nextIndex(s, t, mods.i)
		if i >= M1.Hits and mods.up then
			-- UPPERCUT (Espace maintenu sur le 5e coup) : endlag complet s'il rate, raccourci s'il touche
			setRecovery(character, s, t, M1.Cooldown[M1.Hits], true)
			anim, windup = U.Anim, U.Windup
			spec = {
				HitboxOffset = M1.HitboxOffset, HitboxSize = M1.HitboxSize, MaxTargets = 2, Damage = U.Damage,
				Knockback = 0, Stun = U.Stun, Category = "Heavy", Power = U.Power, Words = U.Words, Weapon = "Uppercut",
				Launch = Vector3.new(U.LaunchForward, U.LaunchUp, 0), Heavy = true,
			}
			onLanded = function(_, hits)
				if #hits == 0 then
					return
				end
				local t2 = os.clock()
				s.nextAttack = t2 + 0.2
				s.busyUntil = t2 + 0.2
				s.endlagUntil = 0
				character:SetAttribute("EndlagUntil", 0)
				s.airCombo = 0
				s.airChainUntil = t2 + U.AirWindow
				s.lastM1Victim, s.lastM1Hit = hits[1], t2
				FX:FireAllClients({ k = "ComboName", a = character, name = "UPPERCUT!" })
				-- le client de l'attaquant saute tout seul derrière la victime (sa physique lui appartient)
				character:SetAttribute("AutoFollow", now())
			end
		else
			setRecovery(character, s, t, M1.Cooldown[i], i >= M1.Hits)
			windup = M1.Windup[i]
			anim = M1.Anim[i]
			spec = {
				HitboxOffset = M1.HitboxOffset, HitboxSize = M1.HitboxSize, MaxTargets = M1.MaxTargets,
				Damage = M1.Damage[i], Knockback = M1.Knockback[i], KnockUp = M1.KnockUp[i], Stun = M1.Stun[i],
				Category = M1.Category[i], Power = M1.Power[i], Weapon = "Punch",
				Tether = i < M1.Hits, -- coups 1-4 : la victime suit l'attaquant ; le finisher la relâche
			}
			if i >= M1.Hits then
				spec.Words = M1.FinisherWords
				spec.Heavy = true
				spec.Knockdown = true
			end
			onLanded = function(_, hits)
				if #hits > 0 and i < M1.Hits then
					s.lastM1Victim = hits[1]
					s.lastM1Hit = os.clock()
				end
			end
		end
	end
	Anim:FireAllClients(character, anim)
	task.delay(windup, function()
		if not CharacterState.isAlive(character) or CharacterState.isStunned(character) or CharacterState.inSafeZone(character) then
			return
		end
		-- tolérance de portée pour la fluidité : la hitbox suit la dernière victime si elle est juste devant
		local v = s.lastM1Victim
		local root = character:FindFirstChild("HumanoidRootPart")
		local vr = v and v.Parent and v:FindFirstChild("HumanoidRootPart")
		if root and vr and os.clock() - (s.lastM1Hit or -10) < 1.2 then
			local to = vr.Position - root.Position
			if to.Magnitude < 9 and flatUnit(to, root.CFrame.LookVector):Dot(root.CFrame.LookVector) > 0.3 then
				spec.HitboxOffset = math.max(spec.HitboxOffset, math.min(to.Magnitude - 0.5, 6))
			end
		end
		spec.ComboTarget = vr and v or nil
		local landed, hits = CombatService.swing(character, spec, seq)
		if onLanded then
			onLanded(landed, hits)
		end
	end)
end

------------------------------------------------------------------------
-- EVASIVE (combo breaker) : Q pendant un hitstun
------------------------------------------------------------------------
local function evasive(character: Model): boolean
	local s = CharacterState.get(character)
	local E = CombatConfig.Evasive
	local t = os.clock()
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or t < s.nextBreak then
		return false
	end
	-- interdit : guard break (punition du block), renversé (déjà intouchable), tenu par une ulti
	if CharacterState.isGuardBroken(character) or CharacterState.isKnockedDown(character) or s.pendingKO
		or character:GetAttribute("UltHeld") ~= nil or character:GetAttribute("UltAnchor") then
		return false
	end
	s.nextBreak = t + E.Cooldown
	character:SetAttribute("CDEvasive", now() + E.Cooldown)
	character:SetAttribute("CDMaxEvasive", E.Cooldown)
	for _, n in ipairs({ "KB", "AirStall", "Spin" }) do
		local c = root:FindFirstChild(n)
		if c then
			c:Destroy()
		end
	end
	CharacterState.clearStun(character) -- remet aussi PlatformStand à false
	CharacterState.protect(character, E.IFrames, false)
	character:SetAttribute("EvasiveAt", now()) -- le client fait un petit bond en arrière
	-- seuls les attaquants RÉCENTS de l'évadé sont repoussés (pas les passants dans le rayon)
	local tether = tethers[character]
	local attackers = CharacterState.recentAttackers(character, E.AttackerMemory or 2)
	if tether and tether.a and not table.find(attackers, tether.a) then
		table.insert(attackers, tether.a)
	end
	releaseTether(character)
	for _, other in ipairs(attackers) do
		local oRoot = other ~= character and other:FindFirstChild("HumanoidRootPart")
		if oRoot and (oRoot.Position - root.Position).Magnitude <= E.Radius and not CharacterState.inSafeZone(other)
			and not CharacterState.isProtected(other) and CharacterState.isAlive(other) then
			local dir = flatUnit(oRoot.Position - root.Position, root.CFrame.LookVector)
			releaseTether(other)
			CharacterState.stun(other, E.AttackerStun)
			knockback(other, dir * E.Knockback + Vector3.new(0, 16, 0), false, E.AttackerStun, character)
		end
	end
	FX:FireAllClients({ k = "Breaker", p = root.Position, a = character })
	Anim:FireAllClients(character, "Evasive")
	return true
end

local DASH_ANIMS = { F = "Dash", B = "DashBack", L = "SideDashL", R = "SideDashR" }

------------------------------------------------------------------------
function CombatService.init()
	FX = Net.get("FX")
	Anim = Net.get("Anim")
	RunService.Heartbeat:Connect(updateTethers)
	-- jauge de garde qui remonte : attribut Guard mis à jour 5 fois par seconde (HUD)
	task.spawn(function()
		while true do
			task.wait(0.2)
			CharacterState.tickGuards()
		end
	end)

	-- Overtime : rendu au respawn, remis à zéro quand on se transforme (la jauge est consommée)
	Signals.CharacterSpawned:Connect(function(character, player)
		player = player or Players:GetPlayerFromCharacter(character)
		if player and character then
			character:SetAttribute("Overtime", player:GetAttribute("OvertimeBank") or 0)
			-- toute modification de la jauge (gain, vol de l'Accountant, admin) est recopiée sur le joueur
			character:GetAttributeChangedSignal("Overtime"):Connect(function()
				if not character:GetAttribute("Transformed") and character.Parent then
					local hum = character:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						player:SetAttribute("OvertimeBank", character:GetAttribute("Overtime") or 0)
					end
				end
			end)
		end
	end)
	Signals.Transformed:Connect(function(character)
		local pl = Players:GetPlayerFromCharacter(character)
		if pl then
			pl:SetAttribute("OvertimeBank", 0)
		end
	end)
	local R = CombatConfig.RemoteRate

	Net.get("Attack").OnServerEvent:Connect(function(player, seq, mods)
		if type(seq) ~= "number" or not Net.allow(player, "Attack", R.Attack) then
			return
		end
		mods = type(mods) == "table" and mods or {}
		local wantI = tonumber(mods.i)
		mods = {
			up = mods.up == true,
			air = mods.air == true,
			i = (wantI and wantI == math.floor(wantI) and wantI >= 1 and wantI <= M1.Hits) and wantI or nil,
		}
		local character = player.Character
		if not CharacterState.isAlive(character) or CharacterState.isStunned(character) or CharacterState.inSafeZone(character) then
			return
		end
		local s = CharacterState.get(character)
		if s.held and CombatService.itemUseHandler then
			CombatService.itemUseHandler(player, character, seq)
		else
			doM1(player, character, seq, mods)
		end
	end)

	-- Q : dash directionnel (kind = "F" | "B" | "L" | "R") ; pendant un hitstun = EVASIVE
	Net.get("Dash").OnServerEvent:Connect(function(player, kind, wantDir)
		if not Net.allow(player, "Dash", R.Dash) then
			return
		end
		local character = player.Character
		if not CharacterState.isAlive(character) then
			return
		end
		local s = CharacterState.get(character)
		local t = os.clock()
		if CharacterState.isStunned(character) then
			evasive(character)
			return
		end
		if CharacterState.inSafeZone(character) or t < s.nextDash - 0.15 or t < s.endlagUntil - TOL then
			return
		end
		if kind ~= "F" and kind ~= "B" and kind ~= "L" and kind ~= "R" then
			kind = "F"
		end
		local D = CombatConfig.Dash
		s.nextDash = t + D.Cooldown
		s.lastDash = t
		s.lastDashKind = kind
		-- dash cancel au milieu de la chaîne (jamais pendant l'endlag d'un coup lourd, voir plus haut) :
		-- la chaîne CONTINUE (s.combo gardé) : dash après le 4e coup = le prochain M1 est le FINISHER, jamais un
		-- retour au 1er coup (sinon combo infini). La laisse est relâchée : le dash ne traîne pas la victime.
		if t < s.nextAttack then
			s.nextAttack = t
		end
		s.busyUntil = math.min(s.busyUntil, t)
		for victim, d in pairs(tethers) do
			if d.a == character then
				releaseTether(victim)
			end
		end
		s.wantBlock = false
		CharacterState.setBlocking(character, false)
		character:SetAttribute("CDDash", now() + D.Cooldown)
		character:SetAttribute("CDMaxDash", D.Cooldown)
		-- direction : celle du client si plausible (horizontale), sinon déduite du type et de l'orientation
		local root = character:FindFirstChild("HumanoidRootPart")
		local dir
		if typeof(wantDir) == "Vector3" and wantDir.Magnitude == wantDir.Magnitude and wantDir.Magnitude < 1e3 then
			local f = Vector3.new(wantDir.X, 0, wantDir.Z)
			dir = f.Magnitude > 0.05 and f.Unit or nil
		end
		if not dir and root then
			local cf = root.CFrame
			dir = (kind == "B" and -cf.LookVector) or (kind == "L" and -cf.RightVector) or (kind == "R" and cf.RightVector) or cf.LookVector
		end
		-- skipSelf : le dasheur a déjà joué son effet en local (CombatController)
		FX:FireAllClients({ type = "DashFX", character = character, dir = dir, skipSelf = true })
		Anim:FireAllClients(character, DASH_ANIMS[kind])
	end)

	Net.get("Run").OnServerEvent:Connect(function(player, on)
		if type(on) ~= "boolean" or not Net.allow(player, "Run", R.Run) then
			return
		end
		local character = player.Character
		if not CharacterState.isAlive(character) then
			return
		end
		local s = CharacterState.get(character)
		if on and (CharacterState.isStunned(character) or s.blocking or (s.held and s.held.cfg.Hold == "TwoHands" and character:GetAttribute("CharacterName") ~= "Intern")) then
			return
		end
		CharacterState.setRunning(character, on)
	end)

	-- F : block (maintenu). auto = true : réactivation automatique (F maintenu) -> pas de PERFECT BLOCK
	local function startBlock(character: Model, auto: boolean)
		CharacterState.setBlocking(character, true, auto)
		CharacterState.setRunning(character, false)
		Anim:FireAllClients(character, "BlockStart")
	end
	Net.get("Block").OnServerEvent:Connect(function(player, on, auto)
		if type(on) ~= "boolean" or not Net.allow(player, "Block", R.Block) then
			return
		end
		local character = player.Character
		if not CharacterState.isAlive(character) then
			return
		end
		local s = CharacterState.get(character)
		s.wantBlock = on
		if not on then
			s.blockReq = nil
			CharacterState.setBlocking(character, false)
			return
		end
		if CharacterState.isStunned(character) or CharacterState.isGuardBroken(character) then
			return
		end
		auto = auto == true
		local t = os.clock()
		if t < s.busyUntil then
			-- encore en récupération d'attaque (le client est un peu en avance) : on bloque dès qu'elle finit
			local req = {}
			s.blockReq = req
			task.delay(s.busyUntil - t + 0.01, function()
				if s.blockReq == req and s.wantBlock and CharacterState.isAlive(character) and not CharacterState.isStunned(character)
					and os.clock() >= s.busyUntil - 0.02 then
					startBlock(character, auto)
				end
			end)
			return
		end
		startBlock(character, auto)
	end)
end

return CombatService
