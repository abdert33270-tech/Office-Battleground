--[[
	CombatService — autorité serveur sur tous les coups.
	- M1 (combo 4 coups) + variantes : Uppercut (Espace + 4e coup), jongle aérien, Downslam (4e coup en l'air),
	  Dropkick (Shift+M1 ou M1 juste après un dash).
	- Dash (annule la fin d'un combo), Block / Parry / Guard Break, Combo Breaker.
	- applyHit() = point d'entrée UNIQUE de tous les dégâts du jeu (M1, objets, lancers, attaques, événements).
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
			if hum and hum.Health > 0 then
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
			if hum.Parent and hum.Health > 0 then
				hum.PlatformStand = false
			end
		end)
	end
	if velocity.Magnitude >= CombatConfig.WallSplat.MinSpeed then
		watchFlight(victim, attacker, 0.9)
	end
end
CombatService.knockback = knockback

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
				CharacterState.stun(victim, spec.Stun)
			elseif (spec.BounceUp or 0) > 0 then
				knockback(victim, Vector3.new(0, spec.BounceUp, 0), false, spec.Stun, attacker)
			end
			task.delay(math.max(0.6, spec.Stun), function()
				if hum.Parent and hum.Health > 0 then
					hum.PlatformStand = false
				end
			end)
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
-- applyHit : point d'entrée unique des dégâts
--[[
	p = {
		attacker: Model?, victim: Model, damage, dir: Vector3 (horizontal, de l'attaquant vers la victime),
		knockback, up, stun, category, power, words?, material?, hitPos?, weapon?, cause?, seq?,
		unblockable?, air? (suspension aérienne), launch? (Vector3 : vitesse imposée), slam? (spec Downslam),
		itemId?, kitchen?, finisher?, noFlinch?
	}
	Retourne "Hit" | "Blocked" | "Parried" | nil
]]
------------------------------------------------------------------------
function CombatService.applyHit(p)
	local victim = p.victim
	local hum = victim and victim:FindFirstChildOfClass("Humanoid")
	local root = victim and victim:FindFirstChild("HumanoidRootPart")
	if not hum or not root or hum.Health <= 0 then
		return nil
	end
	if CharacterState.isProtected(victim) then
		return nil
	end
	local attacker = p.attacker
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
	local vs = CharacterState.get(victim)
	local B = CombatConfig.Block

	-- garde : seulement contre un coup de face
	if vs.blocking and not p.unblockable then
		local frontal = root.CFrame.LookVector:Dot(-p.dir) > 0.1
		if frontal then
			releaseTether(victim)
			local t = os.clock()
			if t - vs.blockStart <= B.ParryWindow then
				-- PARADE : l'attaquant est repoussé, étourdi et désarmé
				vs.blockStart = -10
				FX:FireAllClients({ k = "Parry", p = root.Position + p.dir * -1.5 + Vector3.new(0, 1, 0), v = victim, a = attacker })
				if attacker then
					attacker:SetAttribute("ParriedAt", now())
				end
				if attacker and CharacterState.isAlive(attacker) then
					local aRoot = attacker:FindFirstChild("HumanoidRootPart")
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
			-- BLOCK : dégâts réduits, la garde s'use
			vs.guard = math.min(B.MaxGuard, vs.guard + (t - (vs.guardT or t)) * B.GuardRegen)
			vs.guardT = t
			vs.guard -= p.trayGuard and 0 or p.damage
			local chip = p.trayGuard and 0 or p.damage * (1 - B.Reduction)
			if vs.guard <= 0 then
				vs.guard = B.MaxGuard
				CharacterState.setBlocking(victim, false)
				CharacterState.stun(victim, B.GuardBreakStun)
				FX:FireAllClients({ k = "GuardBreak", p = root.Position + Vector3.new(0, 1.5, 0), v = victim, a = attacker })
			else
				FX:FireAllClients({ k = "Block", p = root.Position + p.dir * -1.2 + Vector3.new(0, 1, 0), v = victim, a = attacker, d = chip })
			end
			if chip > 0 then
				CharacterState.recordHit(victim, attacker, p.weapon, p.cause)
				hum:TakeDamage(chip)
			end
			knockback(victim, p.dir * 6, false, 0.1, attacker)
			return "Blocked"
		end
	end

	local damage = p.damage
	local ko = hum.Health - damage <= 0
	local category = p.category or "Light"
	local hitStop = ko and CombatConfig.HitStop.KO
		or (category == "Heavy" and CombatConfig.HitStop.Heavy)
		or CombatConfig.HitStop.Light

	CharacterState.recordHit(victim, attacker, p.weapon, p.cause)
	CharacterState.addStreak(victim)
	local combo = 0
	if attacker then
		combo = CharacterState.addCombo(attacker, victim)
		CombatService.addOvertime(attacker, damage * CombatConfig.Overtime.DealMult)
	end
	CombatService.addOvertime(victim, damage * CombatConfig.Overtime.TakeMult)

	local reaction = (p.slam or p.pin) and "Slam" or (p.launch and "Launch") or ((category == "Heavy" or p.knockback >= 30) and "Heavy" or "Light")
	FX:FireAllClients({
		k = "Hit", a = attacker, v = victim, p = p.hitPos or root.Position,
		c = category, pw = p.power or 0.4, d = damage, w = p.words, m = p.material,
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
		releaseTether(victim)
		victim:SetAttribute("KOLaunch", p.dir * CombatConfig.KOLaunch.Speed + Vector3.new(0, CombatConfig.KOLaunch.Up, 0))
		task.delay(hitStop, function()
			hum:TakeDamage(damage)
		end)
		return "Hit"
	end
	hum:TakeDamage(damage)
	CharacterState.stun(victim, p.stun or 0.3)
	if p.tether and attacker then
		setTether(victim, attacker, math.min(p.stun or 0.6, 0.8) + 0.12)
	end

	task.delay(hitStop, function()
		if not victim.Parent then
			return
		end
		if p.pin and not p.slam then
			p.slam = { SlamSpeed = 150, Stun = CombatConfig.PinStun, BounceUp = 0, Pin = true }
		end
		-- coup aérien pendant la montée du Rising Duo : on ne casse pas l'envol (ni recul ni suspension)
		local rising = attacker and not p.slam and not p.launch and os.clock() < (CharacterState.get(attacker).duoRiseUntil or 0)
		if rising then
			return
		end
		if p.slam then
			slam(victim, attacker, p.slam)
		elseif p.launch then
			knockback(victim, p.launch, false, p.stun or 1, attacker)
			hum.PlatformStand = true
			task.delay(math.max(0.6, p.stun or 1), function()
				if hum.Parent and hum.Health > 0 then
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
					for _, n in ipairs({ "AirStall", "Lift" }) do
						local c = aRoot:FindFirstChild(n)
						if c then
							c:Destroy()
						end
					end
				end
				attacker:SetAttribute("AirRelease", now()) -- le client de l'attaquant retire ses suspensions locales
			end
		elseif p.air then
			CombatService.airStall(victim, CombatConfig.Air.Stall)
			-- pendant un Rising Duo, le client du joueur gère lui-même sa montée et sa suspension :
			-- une suspension serveur freinerait la montée (l'attaquant resterait au sol)
			local selfLift = attacker and Players:GetPlayerFromCharacter(attacker) and os.clock() < (CharacterState.get(attacker).duoUntil or 0)
			if attacker and not selfLift then
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
			if not CharacterState.isProtected(victim) then
				CharacterState.recordHit(victim, attacker, "Burn", attacker and "Combat" or "Event")
				hum:TakeDamage(burn.Damage)
				FX:FireAllClients({ k = "Burn", v = victim, p = head.Position, d = burn.Damage })
			end
		end
	end)
end

-- Hitbox devant un personnage -> applique les coups. Utilisé par le M1, les objets et les attaques.
-- spec : HitboxOffset, HitboxSize, MaxTargets, Damage, Knockback, KnockUp, Stun, Category, Power, Words, Material,
--        Launch (Vector3 relatif : X = recul, Y = hauteur), Air, Slam, Unblockable, Weapon, ItemId, Kitchen, FinisherName
function CombatService.swing(attacker: Model, spec, seq)
	local cf = Hitbox.frontCFrame(attacker, spec.HitboxOffset)
	if not cf then
		return {}
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
	local landed = {}
	for _, victim in ipairs(hits) do
		local vRoot = victim:FindFirstChild("HumanoidRootPart")
		if vRoot and aRoot then
			local dir = flatUnit(vRoot.Position - aRoot.Position, aRoot.CFrame.LookVector)
			local p = {
				attacker = attacker, victim = victim, damage = spec.Damage, dir = dir,
				knockback = spec.Knockback, up = spec.KnockUp, stun = spec.Stun,
				category = spec.Category, power = spec.Power, words = spec.Words, material = spec.Material,
				seq = seq, unblockable = spec.Unblockable, weapon = spec.Weapon, itemId = spec.ItemId, kitchen = spec.Kitchen,
				tether = spec.Tether,
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
			if result == "Hit" or result == "Blocked" then
				table.insert(landed, victim)
			elseif result == "Parried" then
				break
			end
		end
	end
	return landed
end

------------------------------------------------------------------------
-- M1 et variantes
------------------------------------------------------------------------
local function slowAttacker(character: Model, duration: number)
	CharacterState.setSpeedMod(character, "Attack", CombatConfig.AttackSlow, duration)
end

local function doM1(player: Player, character: Model, seq: number, mods)
	local s = CharacterState.get(character)
	local t = os.clock()
	if t < s.nextAttack - 0.05 or s.blocking then
		return
	end
	-- après un Rising Duo, la montée est appliquée par le client avec un léger retard : on compte déjà les M1 comme aériens
	local airborne = CharacterState.isAirborne(character) or t < (s.duoUntil or 0)
	local wantsDropkick = (mods.shift or t - (s.lastDash or -10) < CombatConfig.Dash.AttackWindow)
	local spec, anim, windup, onLanded

	if wantsDropkick and not airborne and t >= s.nextDropkick then
		local D = CombatConfig.Dropkick
		s.nextDropkick = t + D.Cooldown
		character:SetAttribute("CDDropkick", now() + D.Cooldown)
		character:SetAttribute("CDMaxDropkick", D.Cooldown)
		s.nextAttack = t + 0.75
		s.combo, s.m1Landed = 0, 0
		anim, windup = D.Anim, D.Windup
		spec = {
			HitboxOffset = D.HitboxOffset, HitboxSize = D.HitboxSize, MaxTargets = 3, Damage = D.Damage,
			Knockback = D.Knockback, KnockUp = D.KnockUp, Stun = D.Stun, Category = "Heavy", Power = D.Power,
			Words = D.Words, Weapon = "Dropkick",
		}
	elseif airborne and mods.pin and (s.m1Landed or 0) == 3 and t - (s.lastM1Hit or -10) < CombatConfig.GroundPin.Window then
		-- 3 M1 + saut + M1 : GROUND PIN
		local G = CombatConfig.GroundPin
		s.combo, s.m1Landed = 0, 0
		character:SetAttribute("ComboStep", 0)
		s.nextAttack = t + 0.7
		anim, windup = "Downslam", 0.08
		FX:FireAllClients({ k = "ComboName", a = character, name = "GROUND PIN!" })
		spec = {
			HitboxOffset = 3, HitboxSize = Vector3.new(8, 15, 8), MaxTargets = 2, Damage = G.Damage,
			Knockback = 0, Stun = G.Stun, Category = "Heavy", Power = G.Power, Words = G.Words, Weapon = "Ground Pin",
			Slam = { SlamSpeed = G.SlamSpeed, Stun = G.Stun, BounceUp = 0, Pin = true },
		}
	elseif airborne then
		local C = CombatConfig.Combos
		local max = (t < (s.airMaxUntil or 0)) and s.airMax or C.AirMaxDefault
		if t - s.lastAir > 1.0 then
			s.airCombo = 0
		end
		s.airCombo += 1
		s.lastAir = t
		local i = s.airCombo
		if i >= max then
			local S = CombatConfig.Downslam
			s.airCombo = 0
			s.airMaxUntil = 0
			s.duoUntil, s.duoRiseUntil = 0, 0
			character:SetAttribute("AirMax", C.AirMaxDefault)
			s.nextAttack = t + 0.7
			anim, windup = S.Anim, 0.1
			spec = {
				HitboxOffset = 3, HitboxSize = Vector3.new(7, 11, 7.5), MaxTargets = 2, Damage = S.Damage,
				Knockback = 0, Stun = S.Stun, Category = "Heavy", Power = S.Power, Words = S.Words, Slam = S, Weapon = "Downslam",
			}
		else
			local A = CombatConfig.Air
			s.nextAttack = t + 0.3
			anim, windup = A.Anim[((i - 1) % #A.Anim) + 1], 0.05
			spec = {
				HitboxOffset = 3, HitboxSize = Vector3.new(7, 11, 7.5), MaxTargets = 2, Damage = A.Damage[((i - 1) % #A.Damage) + 1],
				Knockback = 4, KnockUp = 2, Stun = 0.8, Category = "Light", Power = 0.45, Air = true, Weapon = "Punch",
				Tether = true, -- la victime reste devant l'attaquant en l'air
			}
		end
	else
		if t - s.lastM1 > M1.ComboReset then
			s.combo, s.m1Landed = 0, 0
		end
		s.combo = s.combo % 4 + 1
		local i = s.combo
		s.lastM1 = t
		s.nextAttack = t + M1.Cooldown[i]
		slowAttacker(character, M1.Cooldown[i] + 0.05)
		if i == 4 then
			s.combo = 0
		end
		windup = M1.Windup
		anim = M1.Anim[i]
		spec = {
			HitboxOffset = M1.HitboxOffset, HitboxSize = M1.HitboxSize, MaxTargets = M1.MaxTargets,
			Damage = M1.Damage[i], Knockback = M1.Knockback[i], KnockUp = M1.KnockUp[i], Stun = M1.Stun[i],
			Category = M1.Category[i], Power = M1.Power[i], Weapon = "Punch",
			Tether = i < 4, -- coups 1-3 : la victime suit l'attaquant ; le finisher la relâche
		}
		if i == 4 then
			spec.Words = { "FINISHER!", "WHAM!", "KAPOW!" }
		end
		onLanded = function(landed)
			if #landed > 0 and i < 4 then
				s.m1Landed = (s.m1Landed or 0) + 1
				s.lastM1Victim = landed[1]
				s.lastM1Hit = os.clock()
				character:SetAttribute("ComboStep", s.m1Landed)
			else
				s.m1Landed = 0
				character:SetAttribute("ComboStep", 0)
			end
		end
	end
	Anim:FireAllClients(character, anim)
	task.delay(windup, function()
		if not CharacterState.isAlive(character) or CharacterState.isStunned(character) then
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
		local landed = CombatService.swing(character, spec, seq)
		if onLanded then
			onLanded(landed)
		end
	end)
end

------------------------------------------------------------------------
-- Lanceurs (Espace pendant la chaîne de M1) : Rising Duo (2 M1) et Uppercut (3 M1)
------------------------------------------------------------------------
local function liftAttacker(character: Model, up: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local att = root:FindFirstChild("KBAtt") or Instance.new("Attachment")
	att.Name = "KBAtt"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Lift"
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.VectorVelocity = Vector3.new(0, up, 0) + root.CFrame.LookVector * 4
	lv.Parent = root
	Debris:AddItem(lv, 0.14)
end

local function doLaunch(player: Player, character: Model, seq: number)
	local s = CharacterState.get(character)
	local C = CombatConfig.Combos
	local t = os.clock()
	local victim = s.lastM1Victim
	local step = s.m1Landed or 0
	if (step ~= 2 and step ~= 3) or t - (s.lastM1Hit or -10) > C.Window or not CharacterState.isAlive(victim) then
		return
	end
	local root, vRoot = character:FindFirstChild("HumanoidRootPart"), victim:FindFirstChild("HumanoidRootPart")
	if not root or not vRoot or (vRoot.Position - root.Position).Magnitude > 11 then
		return
	end
	s.combo, s.m1Landed = 0, 0
	character:SetAttribute("ComboStep", 0)
	s.nextAttack = t + 0.3
	local dir = flatUnit(vRoot.Position - root.Position, root.CFrame.LookVector)
	local duo = step == 2
	local L = duo and C.RisingDuo or C.Uppercut
	Anim:FireAllClients(character, duo and "RisingDuo" or "Uppercut")
	FX:FireAllClients({ k = "ComboName", a = character, name = duo and "RISING DUO!" or "UPPERCUT!" })
	task.delay(0.06, function()
		if not CharacterState.isAlive(character) or CharacterState.isStunned(character) then
			return
		end
		local result = CombatService.applyHit({
			attacker = character, victim = victim, damage = L.Damage, dir = dir, stun = 1.3,
			category = "Heavy", power = L.Power, words = L.Words, weapon = duo and "Rising Duo" or "Uppercut",
			launch = dir * 3 + Vector3.new(0, L.VictimUp, 0), seq = seq, unblockable = false,
			hitPos = vRoot.Position + Vector3.new(0, 0.5, 0),
		})
		if result ~= "Hit" then
			return
		end
		s.airMax = L.AirHits
		s.airMaxUntil = os.clock() + 3
		s.airCombo = 0
		character:SetAttribute("AirMax", L.AirHits)
		if duo then
			s.duoUntil = os.clock() + L.Stall + 0.8
			s.duoRiseUntil = os.clock() + 0.62
			-- les deux montent ensemble et restent suspendus en haut
			-- (l'attaquant est un joueur : c'est SON client qui applique la montée, sinon elle arrive trop tard)
			if Players:GetPlayerFromCharacter(character) then
				character:SetAttribute("LiftUp", L.AttackerUp)
				character:SetAttribute("LiftStall", L.Stall)
				character:SetAttribute("LiftAt", now())
			else
				liftAttacker(character, L.AttackerUp)
			end
			task.delay(0.62, function()
				-- (si le slam a déjà eu lieu, airMaxUntil vaut 0 : on ne re-suspend pas la victime)
				if victim.Parent and os.clock() < (s.airMaxUntil or 0) then
					CombatService.airStall(victim, L.Stall)
					if CharacterState.isAlive(victim) and CharacterState.isAlive(character) then
						setTether(victim, character, L.Stall + 0.2) -- en haut : la victime reste devant l'attaquant
					end
				end
			end)
		else
			character:SetAttribute("FollowUntil", now() + CombatConfig.Uppercut.FollowWindow)
		end
	end)
end
------------------------------------------------------------------------
-- Combo breaker : petite explosion qui libère
------------------------------------------------------------------------
local function comboBreaker(character: Model)
	local s = CharacterState.get(character)
	local C = CombatConfig.ComboBreaker
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	s.nextBreak = os.clock() + C.Cooldown
	s.hitStreak = 0
	character:SetAttribute("CanBreak", false)
	character:SetAttribute("CDBreak", now() + C.Cooldown)
	CharacterState.clearStun(character)
	CharacterState.protect(character, C.Protect)
	for _, other in ipairs(Hitbox.characters()) do
		local oRoot = other ~= character and other:FindFirstChild("HumanoidRootPart")
		if oRoot and (oRoot.Position - root.Position).Magnitude <= C.Radius then
			local dir = flatUnit(oRoot.Position - root.Position, root.CFrame.LookVector)
			CharacterState.stun(other, 0.6)
			knockback(other, dir * C.Knockback + Vector3.new(0, 18, 0), true, 0.6, character)
		end
	end
	FX:FireAllClients({ k = "Breaker", p = root.Position, a = character })
end

------------------------------------------------------------------------
function CombatService.init()
	FX = Net.get("FX")
	Anim = Net.get("Anim")
	RunService.Heartbeat:Connect(updateTethers)

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
		mods = { up = mods.up == true, shift = mods.shift == true, launch = mods.launch == true, pin = mods.pin == true }
		local character = player.Character
		if not CharacterState.isAlive(character) or CharacterState.isStunned(character) then
			return
		end
		local s = CharacterState.get(character)
		if mods.launch then
			doLaunch(player, character, seq)
		elseif s.held and CombatService.itemUseHandler then
			CombatService.itemUseHandler(player, character, seq)
		else
			doM1(player, character, seq, mods)
		end
	end)

	Net.get("Dash").OnServerEvent:Connect(function(player)
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
			if character:GetAttribute("CanBreak") and t >= s.nextBreak then
				comboBreaker(character)
			end
			return
		end
		if t < s.nextDash - 0.1 then
			return
		end
		local D = CombatConfig.Dash
		s.nextDash = t + D.Cooldown
		s.lastDash = t
		s.nextAttack = math.min(s.nextAttack, t) -- dash cancel
		CharacterState.setBlocking(character, false)
		character:SetAttribute("CDDash", now() + D.Cooldown)
		FX:FireAllClients({ k = "Dash", a = character })
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

	Net.get("Block").OnServerEvent:Connect(function(player, on)
		if type(on) ~= "boolean" or not Net.allow(player, "Block", R.Block) then
			return
		end
		local character = player.Character
		if not CharacterState.isAlive(character) then
			return
		end
		if on and (CharacterState.isStunned(character)) then
			return
		end
		CharacterState.setBlocking(character, on)
		if on then
			CharacterState.setRunning(character, false)
			Anim:FireAllClients(character, "BlockStart")
		end
	end)
end

return CombatService
