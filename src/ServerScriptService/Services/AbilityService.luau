--[[
	AbilityService — attaques de personnages (touches 1, 2, 3), entièrement pilotées par Config/Attacks.
	Chaque fiche a un Kind ; chaque Kind est une fonction ici (Lunge, Projectile, Melee, AoE, Slam, Cone, Grab,
	Zone, Barrier, Buff, Guard). Tous les dégâts passent par CombatService.applyHit.
	Le kit (3 attaques de base ou 3 transformées) vient de CharacterService.getKit(character).
]]
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Attacks = require(Shared.Config.Attacks)
local CombatConfig = require(Shared.Config.Combat)
local Net = require(Shared.Modules.Net)
local Hitbox = require(Shared.Modules.Hitbox)
local CharacterState = require(script.Parent.CharacterState)
local CombatService = require(script.Parent.CombatService)
local ZoneService = require(script.Parent.ZoneService)

local AbilityService = {}
AbilityService.Priority = 26
AbilityService.getKit = nil -- branché par CharacterService

local FX, Anim
local rng = Random.new()
local Kinds = {}

local function now()
	return workspace:GetServerTimeNow()
end

local function fxFolder()
	return workspace:FindFirstChild("FX")
end

-- applique un coup + les effets de la fiche
local function hit(attacker, victim, cfg, dir, over)
	over = over or {}
	local vRoot = victim:FindFirstChild("HumanoidRootPart")
	if not vRoot then
		return nil
	end
	local p = {
		attacker = attacker, victim = victim, dir = dir,
		damage = over.Damage or cfg.Damage or 0, knockback = over.Knockback or cfg.Knockback or 5,
		up = over.KnockUp or cfg.KnockUp or 0, stun = over.Stun or cfg.Stun or 0.4,
		category = over.Category or cfg.Category or "Light", power = over.Power or cfg.Power or 0.4,
		words = over.Words or cfg.Words, material = cfg.Material, weapon = cfg.Name, kitchen = cfg.Kitchen,
		unblockable = cfg.Unblockable, hitPos = over.hitPos or vRoot.Position + Vector3.new(0, 0.5, 0),
	}
	if (over.Pin ~= nil and over.Pin) or (over.Pin == nil and cfg.Effects and cfg.Effects.Pin) then
		p.pin = true -- plaque au sol avec une onde de choc au lieu d'expulser
		p.knockback = 0
	end
	local launch = over.Launch or cfg.Launch
	if launch then
		p.launch = dir * launch.X + Vector3.new(0, launch.Y, 0)
	end
	local result = CombatService.applyHit(p)
	if result == "Hit" and cfg.Effects then
		local e = cfg.Effects
		if e.Blind then
			CharacterState.blind(victim, e.Blind)
			if cfg.Prop == "Bucket" then
				victim:SetAttribute("HeadProp", "Bucket")
				victim:SetAttribute("HeadPropUntil", now() + e.Blind)
			end
		end
		if e.Slow then
			CharacterState.setSpeedMod(victim, "Slow", e.Slow[1], e.Slow[2])
		end
		if e.Burn then
			CombatService.burn(victim, attacker, e.Burn)
		end
		if e.Mark then
			victim:SetAttribute("MarkedBy", attacker.Name)
			victim:SetAttribute("MarkUntil", now() + 6)
			victim:SetAttribute("MarkBonus", e.Mark)
		end
		if e.Trip then
			local hum = victim:FindFirstChildOfClass("Humanoid")
			task.delay(CombatConfig.HitStop.Heavy + 0.02, function()
				if hum and hum.Health > 0 then
					hum.PlatformStand = true
					task.delay(math.max(0.6, p.stun), function()
						if hum.Parent and hum.Health > 0 then
							hum.PlatformStand = false
						end
					end)
				end
			end)
		end
	end
	return result
end

local function others(attacker)
	local list = {}
	for _, c in ipairs(Hitbox.characters()) do
		if c ~= attacker then
			table.insert(list, c)
		end
	end
	return list
end

local function flat(v, fallback)
	return CombatService.flatUnit(v, fallback or Vector3.new(0, 0, -1))
end

------------------------------------------------------------------------
-- Kinds
------------------------------------------------------------------------
function Kinds.Lunge(attacker, cfg)
	local root = attacker:FindFirstChild("HumanoidRootPart")
	local look = root.CFrame.LookVector
	local att = root:FindFirstChild("KBAtt") or Instance.new("Attachment")
	att.Name = "KBAtt"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Lunge"
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(look.X * cfg.Speed, look.Z * cfg.Speed)
	lv.Parent = root
	Debris:AddItem(lv, cfg.Time)
	local hitSet = {}
	local t0 = os.clock()
	local lastTrail = 0
	local wallParams = RaycastParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { fxFolder(), workspace:FindFirstChild("Zones"), workspace:FindFirstChild("ActiveItems"), workspace:FindFirstChild("Dummies") }
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(ex, pl.Character)
		end
	end
	wallParams.FilterDescendantsInstances = ex
	while os.clock() - t0 < cfg.Time and root.Parent and lv.Parent do
		-- on s'arrête devant un mur (jamais traverser les murs de l'étage)
		local wall = workspace:Raycast(root.Position, look * 4, wallParams)
		if wall and wall.Instance.CanCollide then
			lv:Destroy()
			break
		end
		if cfg.Trail and os.clock() - lastTrail > 0.09 then
			lastTrail = os.clock()
			ZoneService.puddle(root.Position, 3.5, 6, attacker)
		end
		local cf = root.CFrame * CFrame.new(0, 0, -2)
		for _, v in ipairs(Hitbox.box(cf, cfg.HitboxSize + Vector3.one * CombatConfig.LatencyTolerance, attacker, 4)) do
			if not hitSet[v] then
				hitSet[v] = true
				local vr = v:FindFirstChild("HumanoidRootPart")
				hit(attacker, v, cfg, flat(vr.Position - root.Position, look))
				if not cfg.Pierce then
					lv:Destroy()
					break
				end
			end
		end
		RunService.Heartbeat:Wait()
	end
end

local projParams = RaycastParams.new()
projParams.FilterType = Enum.RaycastFilterType.Exclude

local function projectile(attacker, cfg, dir, color)
	local root = attacker:FindFirstChild("HumanoidRootPart")
	local part = Instance.new("Part")
	part.Name = "Projectile"
	part.Size = cfg.Size or Vector3.new(1, 1, 1)
	if cfg.Shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif cfg.Shape == "Bucket" then
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(1.5, 1.5, 1.5)
		local water = Instance.new("Part")
		water.Shape = Enum.PartType.Cylinder
		water.Size = Vector3.new(0.1, 1.3, 1.3)
		water.Color = Color3.fromRGB(90, 180, 255)
		water.Material = Enum.Material.SmoothPlastic
		water.Anchored = true
		water.CanCollide = false
		water.CanQuery = false
		water.CFrame = CFrame.new(0, 0, 0)
		water.Parent = part
		local w = Instance.new("WeldConstraint")
		w.Part0 = part
		w.Part1 = water
		w.Parent = water
	end
	part.Color = color or cfg.Color or Color3.new(1, 1, 1)
	part.Material = Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	local pos = root.Position + Vector3.new(0, 1, 0) + dir * 2.5
	part.CFrame = CFrame.lookAt(pos, pos + dir)
	-- traînée (rendue par les clients)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, part.Size.Y * 0.4, 0)
	a1.Position = Vector3.new(0, -part.Size.Y * 0.4, 0)
	a0.Parent, a1.Parent = part, part
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.25
	tr.Color = ColorSequence.new(part.Color)
	tr.Transparency = NumberSequence.new(0.2, 1)
	tr.WidthScale = NumberSequence.new(1, 0)
	tr.LightEmission = 0.4
	tr.Parent = part
	part.Parent = fxFolder()
	local vel = dir * cfg.Speed + Vector3.new(0, cfg.Up or 0, 0)
	local traveled, owner = 0, attacker
	local spin = rng:NextNumber(8, 16)
	local exclude = { fxFolder(), workspace:FindFirstChild("Zones"), workspace:FindFirstChild("ActiveItems"), workspace:FindFirstChild("Dummies") }
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(exclude, pl.Character)
		end
	end
	projParams.FilterDescendantsInstances = exclude
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not part.Parent then
			conn:Disconnect()
			return
		end
		vel -= Vector3.new(0, workspace.Gravity * (cfg.Gravity or 0) * dt, 0)
		local step = vel * dt
		local wall = workspace:Raycast(part.Position, step, projParams)
		local newPos = part.Position + step
		traveled += step.Magnitude
		part.CFrame = CFrame.new(newPos) * (part.CFrame - part.Position) * CFrame.Angles(spin * dt, spin * dt * 0.5, 0)
		for _, v in ipairs(Hitbox.box(CFrame.new(newPos), part.Size + Vector3.one * 2.5, owner, 1)) do
			-- renvoi par la Tray Guard
			if (v:GetAttribute("TrayGuardUntil") or 0) > now() then
				vel = -vel
				owner = v
				FX:FireAllClients({ k = "Block", p = newPos, v = v })
				return
			end
			local vr = v:FindFirstChild("HumanoidRootPart")
			hit(owner, v, cfg, flat(vel, vr.CFrame.LookVector), { hitPos = newPos })
			conn:Disconnect()
			part:Destroy()
			return
		end
		if wall or traveled > (cfg.Range or 60) then
			conn:Disconnect()
			FX:FireAllClients({ k = "ProjPop", p = newPos, c = part.Color })
			part:Destroy()
		end
	end)
end

function Kinds.Projectile(attacker, cfg, aim)
	local root = attacker:FindFirstChild("HumanoidRootPart")
	local base = (typeof(aim) == "Vector3" and aim.Magnitude > 0.5 and aim.Magnitude < 2) and aim.Unit or root.CFrame.LookVector
	base = flat(base, root.CFrame.LookVector)
	local count = cfg.Count or 1
	local spread = math.rad(cfg.Spread or 0)
	for i = 1, count do
		local angle = 0
		if count > 1 then
			if (cfg.Spread or 0) >= 360 then
				angle = (i / count) * math.pi * 2
			else
				angle = -spread / 2 + spread * (i - 1) / (count - 1)
			end
		end
		local dir = (CFrame.Angles(0, angle, 0) * base)
		local color = cfg.Colors and cfg.Colors[rng:NextInteger(1, #cfg.Colors)] or nil
		projectile(attacker, cfg, dir, color)
	end
end

function Kinds.Melee(attacker, cfg)
	if (cfg.Windup or 0) >= 0.15 then
		FX:FireAllClients({ k = "Telegraph", shape = "Box", a = attacker, size = cfg.HitboxSize, offset = cfg.HitboxOffset or 3, dur = cfg.Windup })
	end
	task.wait(cfg.Windup or 0.08)
	local hits = cfg.Hits or 1
	for i = 1, hits do
		if not CharacterState.isAlive(attacker) or CharacterState.isStunned(attacker) then
			return
		end
		local c = (i == hits and cfg.Final) or cfg
		local root = attacker:FindFirstChild("HumanoidRootPart")
		local cf = root.CFrame * CFrame.new(0, 0, -(cfg.HitboxOffset or 3))
		for _, v in ipairs(Hitbox.box(cf, cfg.HitboxSize + Vector3.one * CombatConfig.LatencyTolerance, attacker, 3)) do
			local vr = v:FindFirstChild("HumanoidRootPart")
			hit(attacker, v, cfg, flat(vr.Position - root.Position, root.CFrame.LookVector), c ~= cfg and c or nil)
		end
		if i < hits then
			task.wait(cfg.Interval or 0.1)
		end
	end
end

local function aoe(attacker, cfg, center)
	for _, v in ipairs(others(attacker)) do
		local vr = v:FindFirstChild("HumanoidRootPart")
		if vr and (vr.Position - center).Magnitude <= cfg.Radius then
			hit(attacker, v, cfg, flat(vr.Position - center, Vector3.zAxis))
		end
	end
	if cfg.Shockwave then
		local ground = center - Vector3.new(0, 2.8, 0)
		FX:FireAllClients({ k = "Slam", p = ground, a = attacker })
		ZoneService.shatterAround(ground, cfg.Radius * 0.7, Vector3.new(0, 30, 0))
	end
end

function Kinds.AoE(attacker, cfg)
	FX:FireAllClients({ k = "Telegraph", shape = "Circle", a = attacker, r = cfg.Radius, dur = cfg.Windup or 0.1 })
	task.wait(cfg.Windup or 0.1)
	local root = attacker:FindFirstChild("HumanoidRootPart")
	if root and CharacterState.isAlive(attacker) then
		aoe(attacker, cfg, root.Position)
	end
end

function Kinds.Slam(attacker, cfg)
	local root = attacker:FindFirstChild("HumanoidRootPart")
	local hum = attacker:FindFirstChildOfClass("Humanoid")
	local att = root:FindFirstChild("KBAtt") or Instance.new("Attachment")
	att.Name = "KBAtt"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.MaxForce = 1e6
	lv.VectorVelocity = root.CFrame.LookVector * cfg.Forward + Vector3.new(0, cfg.JumpUp, 0)
	lv.Parent = root
	Debris:AddItem(lv, 0.18)
	task.wait(0.3)
	-- redescend vite
	local down = Instance.new("LinearVelocity")
	down.Attachment0 = att
	down.MaxForce = 1e6
	down.VectorVelocity = root.CFrame.LookVector * 10 + Vector3.new(0, -110, 0)
	down.Parent = root
	local t0 = os.clock()
	while os.clock() - t0 < 1.2 and hum.FloorMaterial == Enum.Material.Air and root.Parent do
		RunService.Heartbeat:Wait()
	end
	down:Destroy()
	if CharacterState.isAlive(attacker) then
		aoe(attacker, cfg, root.Position)
	end
end

function Kinds.Cone(attacker, cfg)
	local root = attacker:FindFirstChild("HumanoidRootPart")
	FX:FireAllClients({ k = "Telegraph", shape = "Cone", a = attacker, r = cfg.Range, angle = cfg.Angle, dur = cfg.Windup or 0.1 })
	task.wait(cfg.Windup or 0.1)
	FX:FireAllClients({ k = "Cone", id = cfg.Name, a = attacker, range = cfg.Range, angle = cfg.Angle, dur = cfg.Duration, c = cfg.Color })
	local cosA = math.cos(math.rad(cfg.Angle))
	local t0 = os.clock()
	repeat
		if not root.Parent or CharacterState.isStunned(attacker) then
			return
		end
		local look = root.CFrame.LookVector
		for _, v in ipairs(others(attacker)) do
			local vr = v:FindFirstChild("HumanoidRootPart")
			if vr then
				local to = vr.Position - root.Position
				if to.Magnitude <= cfg.Range and to.Magnitude > 0 and flat(to):Dot(flat(look)) >= cosA then
					hit(attacker, v, cfg, flat(to, look))
				end
			end
		end
		task.wait(cfg.Tick)
	until os.clock() - t0 >= cfg.Duration
end

function Kinds.Grab(attacker, cfg)
	task.wait(0.08)
	local root = attacker:FindFirstChild("HumanoidRootPart")
	local cf = root.CFrame * CFrame.new(0, 0, -cfg.HitboxOffset)
	local victim = Hitbox.box(cf, cfg.HitboxSize + Vector3.one * CombatConfig.LatencyTolerance, attacker, 1)[1]
	if not victim or CharacterState.isProtected(victim) then
		return
	end
	local vr = victim:FindFirstChild("HumanoidRootPart")
	local vh = victim:FindFirstChildOfClass("Humanoid")
	FX:FireAllClients({ k = "Grab", v = victim, a = attacker, p = vr.Position })
	CharacterState.stun(victim, cfg.HoldTime + 0.4)
	vh.PlatformStand = true
	local a0 = Instance.new("Attachment")
	a0.Parent = vr
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 2.5, -3)
	a1.Parent = root
	local ap = Instance.new("AlignPosition")
	ap.Attachment0 = a0
	ap.Attachment1 = a1
	ap.RigidityEnabled = true
	ap.Parent = vr
	task.wait(cfg.HoldTime)
	ap:Destroy()
	a0:Destroy()
	a1:Destroy()
	if CharacterState.isAlive(victim) and CharacterState.isAlive(attacker) then
		hit(attacker, victim, cfg, root.CFrame.LookVector, { Knockback = cfg.ThrowKnockback, KnockUp = cfg.ThrowUp })
	end
	task.delay(0.6, function()
		if vh.Parent and vh.Health > 0 and not CharacterState.isStunned(victim) then
			vh.PlatformStand = false
		end
	end)
end

local function wetFloorSign(pos: Vector3)
	local m = Instance.new("Model")
	m.Name = "WetFloorSign"
	local function wedge(cf)
		local w = Instance.new("WedgePart")
		w.Size = Vector3.new(1.6, 2.6, 0.9)
		w.CFrame = cf
		w.Color = Color3.fromRGB(255, 215, 0)
		w.Material = Enum.Material.SmoothPlastic
		w.Anchored = true
		w.CanCollide = false
		w.CanQuery = false
		w.Parent = m
		return w
	end
	local base = CFrame.new(ZoneService.groundBelow(pos) + Vector3.new(0, 1.3, 0))
	local front = wedge(base * CFrame.new(0, 0, -0.45))
	wedge(base * CFrame.new(0, 0, 0.45) * CFrame.Angles(0, math.pi, 0))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Adornee = front
	gui.Parent = front
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "WET\nFLOOR"
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = Color3.new(0, 0, 0)
	l.Parent = gui
	m.Parent = workspace:FindFirstChild("Zones") or fxFolder()
	return m
end

function Kinds.Zone(attacker, cfg)
	local root = attacker:FindFirstChild("HumanoidRootPart")
	local pos = root.Position + root.CFrame.LookVector * (cfg.Offset or 0)
	if cfg.Zone == "Puddle" then
		ZoneService.puddle(pos, cfg.Radius, cfg.Duration, attacker)
		Debris:AddItem(wetFloorSign(pos), cfg.Duration)
		FX:FireAllClients({ k = "Splash", p = pos })
	elseif cfg.Zone == "Flood" then
		ZoneService.puddle(pos, cfg.Radius, cfg.Duration, attacker)
		ZoneService.damageZone(pos, cfg.Radius, cfg.Duration, cfg.TickDamage or 2, cfg.Name, attacker, Color3.fromRGB(160, 220, 255))
		FX:FireAllClients({ k = "Flood", p = pos, r = cfg.Radius, dur = cfg.Duration })
	end
end

function Kinds.Barrier(attacker, cfg)
	-- anneau de barrières TRÈS haut, sans trou, et surveillé : personne n'entre ni ne sort pendant la durée
	local root = attacker:FindFirstChild("HumanoidRootPart")
	local center = ZoneService.groundBelow(root.Position)
	local R = cfg.Radius
	local H = math.max(cfg.Height or 40, 40)
	local m = Instance.new("Model")
	m.Name = "Lockdown"
	local n = 40
	for i = 1, n do
		local a = (i / n) * math.pi * 2
		local p = Instance.new("Part")
		p.Size = Vector3.new(R * 2 * math.pi / n + 1.2, H, 1.6)
		p.CFrame = CFrame.new(center + Vector3.new(math.cos(a) * R, H / 2, math.sin(a) * R)) * CFrame.Angles(0, -a + math.pi / 2, 0)
		p.Color = (i % 2 == 0) and Color3.fromRGB(255, 210, 0) or Color3.fromRGB(30, 30, 30)
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = 0.2
		p.Anchored = true
		p.CanCollide = true
		p.Parent = m
	end
	-- couvercle invisible : impossible de sauter par-dessus
	local lid = Instance.new("Part")
	lid.Shape = Enum.PartType.Cylinder
	lid.Size = Vector3.new(1, R * 2 + 3, R * 2 + 3)
	lid.CFrame = CFrame.new(center + Vector3.new(0, H, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	lid.Transparency = 1
	lid.Anchored = true
	lid.CanCollide = true
	lid.Parent = m
	m.Parent = workspace:FindFirstChild("Zones") or fxFolder()
	Debris:AddItem(m, cfg.Duration)
	FX:FireAllClients({ k = "Lockdown", p = center, r = R, a = attacker })
	-- qui est dedans au moment du lancement ?
	local inside = {}
	for _, c in ipairs(Hitbox.characters()) do
		local r = c:FindFirstChild("HumanoidRootPart")
		if r and (Vector3.new(r.Position.X, 0, r.Position.Z) - Vector3.new(center.X, 0, center.Z)).Magnitude <= R then
			inside[c] = true
		end
	end
	local t0 = os.clock()
	while os.clock() - t0 < cfg.Duration and m.Parent do
		for _, c in ipairs(Hitbox.characters()) do
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				local flatPos = Vector3.new(r.Position.X, 0, r.Position.Z)
				local flatC = Vector3.new(center.X, 0, center.Z)
				local d = (flatPos - flatC).Magnitude
				local dir = d > 0.01 and (flatPos - flatC).Unit or Vector3.xAxis
				if inside[c] and d > R - 2 then
					r.CFrame = CFrame.new(flatC + dir * (R - 3.5) + Vector3.new(0, r.Position.Y, 0)) * (r.CFrame - r.Position)
					r.AssemblyLinearVelocity = Vector3.zero
				elseif not inside[c] and d < R + 2 then
					r.CFrame = CFrame.new(flatC + dir * (R + 3.5) + Vector3.new(0, r.Position.Y, 0)) * (r.CFrame - r.Position)
					r.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
		RunService.Heartbeat:Wait()
	end
end

function Kinds.Buff(attacker, cfg)
	CharacterState.setSpeedMod(attacker, "Buff", cfg.SpeedMultiplier, cfg.Duration)
	local player = Players:GetPlayerFromCharacter(attacker)
	if player and cfg.RevealRadius then
		FX:FireClient(player, { k = "Reveal", r = cfg.RevealRadius, dur = cfg.Duration })
	end
end

function Kinds.Guard(attacker, cfg)
	attacker:SetAttribute("TrayGuardUntil", now() + cfg.Duration)
	CharacterState.setBlocking(attacker, true)
	task.wait(cfg.Duration)
	attacker:SetAttribute("TrayGuardUntil", 0)
	CharacterState.setBlocking(attacker, false)
end

------------------------------------------------------------------------
-- comportements ajoutés par les modules de Content (api exposée)
AbilityService.api = {
	hit = function(...) return hit(...) end, others = others, flat = flat, projectile = function(...) return projectile(...) end,
	aoe = function(...) return aoe(...) end, Kinds = Kinds, CharacterState = CharacterState, CombatService = CombatService,
	ZoneService = ZoneService, Hitbox = Hitbox, getFX = function() return FX end, now = now,
}
for _, def in ipairs(require(Shared.Modules.ContentLoader).all()) do
	if type(def.Kinds) == "table" then
		for name, fn in pairs(def.Kinds) do
			Kinds[name] = function(attacker, cfg, aim)
				return fn(attacker, cfg, aim, AbilityService.api)
			end
		end
	end
end

local function onAbility(player: Player, slot, aim)
	if type(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > 3 then
		return
	end
	if not Net.allow(player, "Ability", CombatConfig.RemoteRate.Ability) then
		return
	end
	local character = player.Character
	if not CharacterState.isAlive(character) or CharacterState.isStunned(character) then
		return
	end
	if CharacterState.inSafeZone and CharacterState.inSafeZone(character) then
		return -- salle AFK : aucune attaque
	end
	local s = CharacterState.get(character)
	if s.blocking or s.held and s.held.cfg.Hold == "TwoHands" then
		return
	end
	local kit = AbilityService.getKit and AbilityService.getKit(character)
	local id = kit and kit[slot]
	local cfg = id and Attacks[id]
	if not cfg then
		return
	end
	local t = os.clock()
	if t < (s.gcdUntil or 0) or t < s.nextAttack - 0.05 then
		return -- anti-spam : délai global entre attaques, et pas pendant la récupération d'un combo
	end
	s.cd = s.cd or {}
	s.charges = s.charges or {}
	local cd = s.cd[id] or 0
	local ch = s.charges[id]
	if cfg.Charges then
		if ch and ch.left > 0 and t - ch.start < cfg.ChargeWindow then
			ch.left -= 1
		elseif t >= cd then
			ch = { left = cfg.Charges - 1, start = t }
			s.charges[id] = ch
		else
			return
		end
		if ch.left <= 0 then
			s.cd[id] = t + cfg.Cooldown
			character:SetAttribute("CD" .. slot, now() + cfg.Cooldown)
		end
	else
		if t < cd or t < s.nextAttack - 0.05 then
			return
		end
		s.cd[id] = t + cfg.Cooldown
		character:SetAttribute("CD" .. slot, now() + cfg.Cooldown)
	end
	character:SetAttribute("CDMax" .. slot, cfg.Cooldown)
	s.nextAttack = math.max(s.nextAttack, t + 0.35)
	s.gcdUntil = t + CombatConfig.AbilityGCD
	CharacterState.setSpeedMod(character, "Attack", 0.55, 0.35)
	if cfg.Anim then
		Anim:FireAllClients(character, cfg.Anim)
	end
	local propTime = (cfg.Duration and cfg.Kind ~= "Zone" and cfg.Kind ~= "Barrier" and cfg.Kind ~= "Buff" and cfg.Duration + 0.15)
		or (cfg.Time and cfg.Time + 0.25) or 0.75
	FX:FireAllClients({ k = "Ability", a = character, id = id, name = cfg.Name, snd = cfg.Sound, kind = cfg.Kind, prop = cfg.Prop, dur = propTime })
	local fn = Kinds[cfg.Kind]
	if fn then
		task.spawn(function()
			local ok, err = pcall(fn, character, cfg, aim)
			if not ok then
				warn("[AbilityService]", id, err)
			end
		end)
	end
end

-- remet les recharges à zéro (changement de perso / transformation)
function AbilityService.resetCooldowns(character: Model)
	local s = CharacterState.get(character)
	s.cd, s.charges = {}, {}
	local kit = AbilityService.getKit and AbilityService.getKit(character)
	for i = 1, 3 do
		character:SetAttribute("CD" .. i, 0)
		local cfg = kit and Attacks[kit[i]]
		character:SetAttribute("CDMax" .. i, cfg and cfg.Cooldown or 1)
	end
end

function AbilityService.init()
	FX = Net.get("FX")
	Anim = Net.get("Anim")
	Net.get("Ability").OnServerEvent:Connect(onAbility)
	-- Sticky Note : le prochain coup de celui qui a collé le post-it fait des dégâts bonus
	table.insert(CombatService.damageMods, function(p)
		local v, a = p.victim, p.attacker
		if a and v:GetAttribute("MarkedBy") == a.Name and (v:GetAttribute("MarkUntil") or 0) > now() and p.weapon ~= "Sticky Note" then
			p.damage += v:GetAttribute("MarkBonus") or 8
			p.words = { "STICKY!", "NOTED!" }
			p.power = (p.power or 0.5) + 0.3
			v:SetAttribute("MarkedBy", nil)
		end
	end)
	-- Tray Guard : bloque tout de face sans user la garde
	table.insert(CombatService.damageMods, function(p)
		if (p.victim:GetAttribute("TrayGuardUntil") or 0) > now() then
			p.unblockable = false
			p.trayGuard = true
		end
	end)
end

return AbilityService
