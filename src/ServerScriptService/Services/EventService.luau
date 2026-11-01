--[[
	EventService — événements de bureau (master prompt §9). Valeurs : Config/Events.
	Génériques : FireAlarm, PizzaDelivery, SurpriseMeeting, PowerOutage, BossVisit, Friday5PM
	Spéciaux d'étage : PrinterRampage (OpenSpace), FoodFight (Cafeteria), Overheat (ServerRoom), CarAlarm (ParkingGarage),
	FitnessChallenge (CorporateGym), PackageAvalanche (Mailroom), ReplyAll (MeetingRooms), ShareholderMeeting (CEOOffice),
	RushHour (Lobby), HelicopterLanding (Rooftop), PaperStorm (Archives), PingPongBarrage (GameRoom), NapTime (Daycare),
	Keynote (Auditorium), ForkliftFrenzy (Warehouse), SteamBurst (Spa)
	Zones lentes : tout BasePart tagué SlowZone (attributs Mult, Radius) ralentit les personnages (boucle dans init)
	Chaque événement : bannière cartoon, son, tout son contenu dans workspace.Events.<Nom>, nettoyé à la fin.

	API : start(name), stop(name), stopAll(includePersistent?), list(), runForFloor(floorName, phaseDuration), isActive(name)
	Ajouter un événement = une fiche dans Config/Events + une fonction Impl.<Nom>(cfg, ctx) qui renvoie un nettoyage.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local EventsConfig = require(Shared.Config.Events)
local FloorConfig = require(Shared.Config.Floors)
local Hitbox = require(Shared.Modules.Hitbox)
local Net = require(Shared.Modules.Net)
local World = require(script.Parent.World)
local Signals = require(script.Parent.Signals)
local Announce = require(script.Parent.Announce)
local CombatService = require(script.Parent.CombatService)
local CharacterState = require(script.Parent.CharacterState)
local RigBuilder = require(script.Parent.RigBuilder)
local SoundLists = require(Shared.Config.Sounds)
-- sons partagés (Boing, Ding, Thud, GroundSlam, Pickup...) : chaque clé = liste d'IDs, on en tire un au hasard
local GameSounds = setmetatable({}, {
	__index = function(_, k)
		local v = SoundLists[k]
		if type(v) == "table" then
			return v[math.random(#v)]
		end
		return v
	end,
})

local EventService = {}
EventService.Priority = 40

local SND = EventsConfig.Sounds
local rng = Random.new()
local active = {}  -- [name] = { ctx, cleanup, persistent, token }
local eventsFolder = nil
local FloorFX = nil
local FX = nil -- remote "FX" (éclats de décor « Break »)

------------------------------------------------------------------------
-- Outils
------------------------------------------------------------------------
local function part(parent, size, cf, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.CanCollide = opts.collide == true
	p.CanQuery = opts.query == true
	p.CanTouch = opts.touch == true
	p.CastShadow = false
	p.Transparency = opts.transparency or 0
	if opts.shape then
		p.Shape = opts.shape
	end
	p.Name = opts.name or "Part"
	p.Parent = parent
	return p
end
local CYL = CFrame.Angles(0, 0, math.pi / 2)

local function floorY()
	return World.getFloorY()
end

local function points(name)
	local f = World.current()
	local ev = f and f:FindFirstChild("EventPoints")
	local list = {}
	if ev then
		for _, c in ipairs(ev:GetChildren()) do
			if c.Name == name then
				table.insert(list, c)
			end
		end
	end
	return list
end

local function pointPos(name)
	local p = points(name)[1]
	if not p then
		return nil
	end
	return p:IsA("Model") and p:GetPivot().Position or p.Position, p
end

local function globalSound(id, volume, looped, parent)
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.5
	s.Looped = looped == true
	s.Parent = parent or SoundService
	s:Play()
	if not looped then
		game:GetService("Debris"):AddItem(s, math.max(s.TimeLength, 8))
	end
	return s
end

local function soundAt(id, pos, volume, parent)
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume or 0.6
	s.RollOffMaxDistance = 160
	s.Parent = att
	s:Play()
	game:GetService("Debris"):AddItem(att, 6)
	return s
end

local function allCharacters()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		-- les joueurs en salle AFK (SafeZone) ne participent ni aux effondrements ni aux événements
		if h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") and c:GetAttribute("SafeZone") ~= true then
			table.insert(list, c)
		end
	end
	local d = workspace:FindFirstChild("Dummies")
	if d then
		for _, m in ipairs(d:GetChildren()) do
			local h = m:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 and m:FindFirstChild("HumanoidRootPart") then
				table.insert(list, m)
			end
		end
	end
	return list
end

-- point au sol aléatoire de l'étage (rayon vers le bas)
local function randomFloorPoint(margin)
	margin = margin or 12
	local y = floorY()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { eventsFolder, workspace:FindFirstChild("ActiveItems"), workspace:FindFirstChild("Dummies") }
	for _ = 1, 8 do
		local x = rng:NextNumber(-110 + margin, 110 - margin)
		local z = rng:NextNumber(-110 + margin, 110 - margin)
		local hit = workspace:Raycast(Vector3.new(x, y + 30, z), Vector3.new(0, -40, 0), params)
		if hit and math.abs(hit.Position.Y - y) < 0.6 then
			return Vector3.new(x, y, z)
		end
	end
	return Vector3.new(rng:NextNumber(-60, 60), y, rng:NextNumber(-60, 60))
end

local function eventHit(victim, damage, dir, kb, up, stun, category, power, words, weapon)
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	pcall(CharacterState.recordHit, victim, nil, weapon, "Event")
	CombatService.applyHit({
		attacker = nil,
		victim = victim,
		damage = damage,
		dir = CombatService.flatUnit(dir, Vector3.new(0, 0, -1)),
		knockback = kb,
		up = up,
		stun = stun,
		category = category,
		power = power,
		words = words,
		hitPos = root.Position,
		weapon = weapon,
		cause = "Event",
	})
end

local function billboardText(parent, text, color, size, offset)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(size or 260, 60)
	bb.StudsOffsetWorldSpace = offset or Vector3.new(0, 4, 0)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 400
	bb.Parent = parent
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.FontFace = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Bold) -- police pixel (UITheme.Display)
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Parent = l
	return bb
end

------------------------------------------------------------------------
-- Implémentations : function(cfg, ctx) -> cleanup
-- ctx.folder (dossier de l'événement), ctx.running (false quand on arrête)
------------------------------------------------------------------------
local Impl = {}

function Impl.FireAlarm(cfg, ctx)
	local alarm = globalSound(SND.Alarm, 0.55, true, ctx.folder)
	globalSound(SND.FireBell, 0.5, false, ctx.folder)
	-- fumée : atmosphère plus épaisse
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	local created = false
	if not atm then
		atm = Instance.new("Atmosphere")
		atm.Density = 0
		atm.Parent = Lighting
		created = true
	end
	local saved = { Density = atm.Density, Haze = atm.Haze, Color = atm.Color, Decay = atm.Decay }
	TweenService:Create(atm, TweenInfo.new(4), { Density = 0.62, Haze = 2.5, Color = Color3.fromRGB(190, 190, 195), Decay = Color3.fromRGB(150, 150, 155) }):Play()
	-- pluie des sprinklers
	local y = floorY()
	local rain = part(ctx.folder, Vector3.new(220, 1, 220), Vector3.new(0, y + 23, 0), Color3.new(1, 1, 1), { transparency = 1, name = "Sprinklers" })
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(Color3.fromRGB(150, 210, 255))
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.Speed = NumberRange.new(45, 60)
	pe.Lifetime = NumberRange.new(0.4, 0.5)
	pe.Rate = 220
	pe.Size = NumberSequence.new(0.25)
	pe.Transparency = NumberSequence.new(0.3)
	pe.Parent = rain
	-- flaques glissantes qui apparaissent
	task.spawn(function()
		for _ = 1, cfg.Puddles do
			if not ctx.running then
				return
			end
			local pos = randomFloorPoint(14)
			local d = rng:NextNumber(12, 20)
			local puddle = part(ctx.folder, Vector3.new(0.12, 1, 1), CFrame.new(pos + Vector3.new(0, 0.07, 0)) * CYL, Color3.fromRGB(110, 185, 255), {
				shape = Enum.PartType.Cylinder, transparency = 0.35, query = true, touch = true, name = "Puddle",
			})
			CollectionService:AddTag(puddle, "SlipZone")
			TweenService:Create(puddle, TweenInfo.new(0.8, Enum.EasingStyle.Back), { Size = Vector3.new(0.12, d, d) }):Play()
			task.wait(0.45)
		end
	end)
	return function()
		if alarm then
			alarm:Stop()
		end
		if created then
			atm:Destroy()
		else
			TweenService:Create(atm, TweenInfo.new(2), saved):Play()
		end
	end
end

function Impl.PizzaDelivery(cfg, ctx)
	local spot = pointPos("PizzaSpot") or Vector3.new(0, floorY(), 0)
	spot = Vector3.new(spot.X, floorY(), spot.Z)
	globalSound(SND.Doorbell, 0.7, false, ctx.folder)
	local beam = part(ctx.folder, Vector3.new(80, 7, 7), CFrame.new(spot + Vector3.new(0, 40, 0)) * CYL, Color3.fromRGB(255, 210, 60), {
		shape = Enum.PartType.Cylinder, transparency = 0.6, name = "PizzaBeam",
	})
	billboardText(beam, "FREE PIZZA!", Color3.fromRGB(255, 220, 70), 320, Vector3.new(0, -10, 0))
	for i = 1, cfg.Boxes do
		local a = (i / cfg.Boxes) * math.pi * 2
		local pos = spot + Vector3.new(math.cos(a) * 5, 0, math.sin(a) * 5)
		local m = Instance.new("Model")
		m.Name = "PizzaBox"
		local box = part(m, Vector3.new(3, 0.5, 3), CFrame.new(pos + Vector3.new(0, 30, 0)), Color3.fromRGB(245, 235, 215), { query = true, touch = true, collide = false })
		local pizza = part(m, Vector3.new(0.3, 2.6, 2.6), CFrame.new(pos + Vector3.new(0, 30.35, 0)) * CYL, Color3.fromRGB(255, 190, 60), { shape = Enum.PartType.Cylinder, query = true, touch = true })
		local pep = part(m, Vector3.new(0.32, 0.8, 0.8), CFrame.new(pos + Vector3.new(0.5, 30.4, 0.3)) * CYL, Color3.fromRGB(220, 50, 40), { shape = Enum.PartType.Cylinder })
		m.PrimaryPart = box
		m:SetAttribute("Heal", cfg.Heal)
		m.Parent = ctx.folder
		CollectionService:AddTag(m, "HealPickup")
		-- elle tombe du ciel
		local target = CFrame.new(pos + Vector3.new(0, 0.3, 0))
		task.delay(i * 0.25, function()
			if m.Parent then
				local start = m:GetPivot()
				local t0 = os.clock()
				while m.Parent and os.clock() - t0 < 0.7 do
					local a2 = (os.clock() - t0) / 0.7
					m:PivotTo(start:Lerp(target, a2 * a2))
					task.wait()
				end
				if m.Parent then
					m:PivotTo(target)
				end
			end
		end)
	end
	return function() end
end

function Impl.SurpriseMeeting(cfg, ctx)
	local f = World.current()
	local tableModel = f and f:FindFirstChild("MeetingTable", true)
	local center = pointPos("MeetingTable")
	if not center then
		return function() end
	end
	local cf, size
	if tableModel and tableModel:IsA("Model") then
		cf, size = tableModel:GetBoundingBox()
	else
		cf, size = CFrame.new(center), Vector3.new(20, 3, 8)
	end
	local flatCf = CFrame.new(cf.Position.X, floorY() + 3, cf.Position.Z) * (cf - cf.Position)
	local a = size.X / 2 + 3.5
	local b = size.Z / 2 + 3.5
	globalSound(SND.Doorbell, 0.6, false, ctx.folder)
	local chars = allCharacters()
	for i, c in ipairs(chars) do
		local ang = (i / math.max(#chars, 1)) * math.pi * 2
		local pos = (flatCf * CFrame.new(math.cos(ang) * a, 0, math.sin(ang) * b)).Position
		c:PivotTo(CFrame.lookAt(pos, Vector3.new(flatCf.Position.X, pos.Y, flatCf.Position.Z)))
		local root = c:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.zero
		end
		FloorFX:FireAllClients({ k = "Puff", p = pos })
	end
	return function()
		Announce.banner("MEETING ADJOURNED", "Back to work!", cfg.Color, 2, "Event")
	end
end

local LIGHT_PARTS = { Screen = true, BigScreen = true, RackLED = true, VendingGlass = true, CoffeeLight = true, Windshield = false }
function Impl.PowerOutage(cfg, ctx)
	globalSound(SND.PowerDown, 0.8, false, ctx.folder)
	local saved = {
		Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime, Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient, ExposureCompensation = Lighting.ExposureCompensation,
		EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale, EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
	}
	Lighting.ClockTime = 0
	Lighting.Brightness = 0
	Lighting.Ambient = Color3.new(0, 0, 0)
	Lighting.OutdoorAmbient = Color3.fromRGB(8, 8, 14)
	Lighting.ExposureCompensation = -0.6
	Lighting.EnvironmentDiffuseScale = 0
	Lighting.EnvironmentSpecularScale = 0
	-- seuls les écrans éclairent
	local glowing, count = {}, 0
	local f = World.current()
	if f then
		for _, p in ipairs(f:GetDescendants()) do
			if p:IsA("BasePart") and LIGHT_PARTS[p.Name] and count < 70 then
				count += 1
				table.insert(glowing, { p = p, m = p.Material })
				p.Material = Enum.Material.Neon
				local l = Instance.new("PointLight")
				l.Name = "OutageLight"
				l.Color = p.Color
				l.Brightness = 2
				l.Range = 12
				l.Parent = p
			end
		end
	end
	-- quelques lampes de secours rouges
	for _ = 1, 8 do
		local pos = randomFloorPoint(6)
		local lamp = part(ctx.folder, Vector3.new(1.2, 0.6, 1.2), pos + Vector3.new(0, 9, 0), Color3.fromRGB(255, 60, 40), { material = Enum.Material.Neon, name = "EmergencyLamp" })
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 70, 50)
		l.Brightness = 3
		l.Range = 26
		l.Parent = lamp
	end
	-- petite lueur sur chaque joueur (sinon on ne se voit plus du tout)
	local heads = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local head = p.Character and p.Character:FindFirstChild("Head")
		if head then
			local l = Instance.new("PointLight")
			l.Name = "OutageLight"
			l.Range = 7
			l.Brightness = 0.6
			l.Color = Color3.fromRGB(255, 230, 190)
			l.Parent = head
			table.insert(heads, l)
		end
	end
	return function()
		for k, v in pairs(saved) do
			Lighting[k] = v
		end
		for _, g in ipairs(glowing) do
			if g.p.Parent then
				g.p.Material = g.m
				local l = g.p:FindFirstChild("OutageLight")
				if l then
					l:Destroy()
				end
			end
		end
		for _, l in ipairs(heads) do
			l:Destroy()
		end
	end
end

function Impl.BossVisit(cfg, ctx)
	local startPos = pointPos("BossStart")
	local endPos = pointPos("BossEnd")
	if not startPos or not endPos then
		return function() end
	end
	local scale = cfg.Scale
	local y = floorY() + 3 * scale
	startPos = Vector3.new(startPos.X, y, startPos.Z)
	endPos = Vector3.new(endPos.X, y, endPos.Z)
	local boss = RigBuilder.r6("THE BOSS", {
		Shirt = Color3.fromRGB(55, 55, 68), Pants = Color3.fromRGB(35, 35, 45), Tie = Color3.fromRGB(220, 30, 30),
	})
	boss:PivotTo(CFrame.lookAt(startPos, endPos))
	boss:ScaleTo(scale)
	local root = boss.HumanoidRootPart
	for _, p in ipairs(boss:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.Anchored = false
		end
	end
	root.Anchored = true
	local hum = boss:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.MaxHealth = 1e9
	hum.Health = 1e9
	boss.Parent = ctx.folder
	billboardText(boss.Head, "THE BOSS", Color3.fromRGB(255, 70, 60), 300, Vector3.new(0, 3 * scale * 0.6, 0))
	local bubble = billboardText(boss.Head, "LOOK BUSY!!", Color3.fromRGB(255, 255, 255), 260, Vector3.new(0, 3 * scale, 0))
	local torso = boss.Torso
	local motors = {
		RH = torso:FindFirstChild("Right Hip"), LH = torso:FindFirstChild("Left Hip"),
		RS = torso:FindFirstChild("Right Shoulder"), LS = torso:FindFirstChild("Left Shoulder"),
	}
	local base = {}
	for k, m in pairs(motors) do
		if m then
			base[k] = m.C0
		end
	end
	local quotes = { "LOOK BUSY!!", "YOU'RE FIRED!", "WHERE'S MY REPORT?", "MEETING IN 5!", "SYNERGY!" }
	local lastHit = {}
	local walkTime = math.max(cfg.Duration - 2, 8)
	local t0 = os.clock()
	local lastStep = 0
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not ctx.running or not root.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		local alpha = math.clamp(t / walkTime, 0, 1)
		local pos = startPos:Lerp(endPos, alpha)
		local phase = t * 3.2
		local bob = math.abs(math.sin(phase)) * 0.35 * scale
		root.CFrame = CFrame.lookAt(pos + Vector3.new(0, bob, 0), endPos + Vector3.new(0, bob, 0))
		local swing = math.sin(phase) * 0.7
		if motors.RH then motors.RH.C0 = base.RH * CFrame.Angles(0, 0, swing) end
		if motors.LH then motors.LH.C0 = base.LH * CFrame.Angles(0, 0, swing) end
		if motors.RS then motors.RS.C0 = base.RS * CFrame.Angles(0, 0, -swing) end
		if motors.LS then motors.LS.C0 = base.LS * CFrame.Angles(0, 0, -swing) end
		-- pas lourds
		local step = math.floor(phase / math.pi)
		if step ~= lastStep then
			lastStep = step
			FloorFX:FireAllClients({ k = "Stomp", p = Vector3.new(pos.X, floorY(), pos.Z) })
			if step % 4 == 0 then
				bubble.TextLabel.Text = quotes[rng:NextInteger(1, #quotes)]
			end
		end
		-- éjecte ceux qu'il touche
		local hits = Hitbox.box(root.CFrame * CFrame.new(0, -1.2 * scale, -0.5 * scale), Vector3.new(4.5 * scale, 6 * scale, 3.5 * scale), nil, 10)
		for _, v in ipairs(hits) do
			if not lastHit[v] or os.clock() - lastHit[v] > 1.2 then
				lastHit[v] = os.clock()
				local vr = v:FindFirstChild("HumanoidRootPart")
				if vr then
					local dir = (vr.Position - root.Position)
					eventHit(v, cfg.Damage, dir.Magnitude > 0.1 and dir or root.CFrame.LookVector, cfg.Knockback, cfg.Up, 1.0, "Heavy", 1,
						{ "YOU'RE FIRED!", "BONK!", "WHAM!" }, "Boss")
				end
			end
		end
		if alpha >= 1 then
			conn:Disconnect()
			-- il s'en va en fumée
			FloorFX:FireAllClients({ k = "Puff", p = pos, big = true })
			boss:Destroy()
		end
	end)
	return function()
		if conn then
			conn:Disconnect()
		end
		if boss.Parent then
			boss:Destroy()
		end
	end
end

function Impl.Friday5PM(cfg, ctx)
	ReplicatedStorage:SetAttribute("XPMultiplier", 2)
	local music = globalSound(SND.Party, 0.45, true, ctx.folder)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Friday5PM"
	cc.Saturation = 0.25
	cc.Parent = Lighting
	local confetti = part(ctx.folder, Vector3.new(200, 1, 200), Vector3.new(0, floorY() + 24, 0), Color3.new(1, 1, 1), { transparency = 1, name = "Confetti" })
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 60)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 220, 120)), ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 90, 255)),
	})
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.Speed = NumberRange.new(6, 12)
	pe.Lifetime = NumberRange.new(3, 4)
	pe.Rate = 60
	pe.Size = NumberSequence.new(0.5)
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-200, 200)
	pe.Parent = confetti
	local tints = { Color3.fromRGB(255, 225, 240), Color3.fromRGB(225, 240, 255), Color3.fromRGB(255, 250, 220), Color3.fromRGB(230, 255, 230) }
	task.spawn(function()
		local i = 0
		while ctx.running do
			i += 1
			cc.TintColor = tints[(i % #tints) + 1]
			confetti.Position = Vector3.new(0, floorY() + 24, 0) -- suit les étages
			task.wait(0.5)
		end
	end)
	return function()
		ReplicatedStorage:SetAttribute("XPMultiplier", 1)
		if music then
			music:Stop()
		end
		cc:Destroy()
	end
end

-- projectile simple déplacé par le serveur (feuilles de papier...)
local function projectile(ctx, p, dir, speed, life, onHit)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.folder, workspace:FindFirstChild("ActiveItems"), workspace:FindFirstChild("FX") }
	local t0 = os.clock()
	local conn
	local sp = (p.Size.X + p.Size.Z) / 4
	conn = RunService.Heartbeat:Connect(function(dt)
		if not ctx.running or not p.Parent or os.clock() - t0 > life then
			conn:Disconnect()
			if p.Parent then
				p:Destroy()
			end
			return
		end
		local step = dir * speed * dt
		local hit = workspace:Spherecast(p.Position, math.min(sp, 1.2), step, params)
		if hit then
			conn:Disconnect()
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			while model and not model:FindFirstChildOfClass("Humanoid") do
				model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
			end
			if model then
				onHit(model)
			end
			p:Destroy()
			return
		end
		p.CFrame = (p.CFrame + step) * CFrame.Angles(0, dt * 14, 0)
	end)
end

function Impl.PrinterRampage(cfg, ctx)
	local printers = points("Printer")
	task.spawn(function()
		while ctx.running do
			for _, pr in ipairs(printers) do
				if not ctx.running then
					break
				end
				if pr.Parent and rng:NextNumber() < 0.8 then
					local pcf = pr:IsA("Model") and pr:GetPivot() or pr.CFrame
					-- tir à hauteur de poitrine (au-dessus des comptoirs), trajectoire horizontale
					local origin = (pcf * CFrame.new(0, 4.6, -3.2)).Position
					-- vise le joueur le plus proche devant l'imprimante
					local dir = (pcf.LookVector * Vector3.new(1, 0, 1)).Unit
					local best, bestD = nil, 85
					for _, c in ipairs(allCharacters()) do
						local r = c.HumanoidRootPart
						local to = (r.Position - origin) * Vector3.new(1, 0, 1)
						if to.Magnitude < bestD and to.Magnitude > 0.1 and to.Unit:Dot(dir) > 0.2 then
							best, bestD = to.Unit, to.Magnitude
						end
					end
					dir = best or (CFrame.Angles(0, math.rad(rng:NextNumber(-30, 30)), 0) * dir)
					local paper = part(ctx.folder, Vector3.new(2.4, 0.15, 3), CFrame.new(origin), Color3.fromRGB(255, 255, 255), { name = "Paper" })
					projectile(ctx, paper, dir, cfg.Speed, 1.8, function(v)
						eventHit(v, cfg.Damage, dir, 16, 5, 0.3, "Light", 0.3, { "PAPER CUT!", "THWACK!" }, "Printer")
					end)
					soundAt(SND.Printer, origin, 0.35)
				end
			end
			task.wait(cfg.Interval + rng:NextNumber(0, 0.3))
		end
	end)
	return function() end
end

local FOODS = {
	{ Color3.fromRGB(230, 50, 40), Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6) },   -- tomate
	{ Color3.fromRGB(190, 120, 50), Enum.PartType.Cylinder, Vector3.new(1, 2.2, 2.2) }, -- burger
	{ Color3.fromRGB(255, 230, 180), Enum.PartType.Cylinder, Vector3.new(0.8, 2.6, 2.6) }, -- tarte
	{ Color3.fromRGB(110, 210, 70), Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4) },   -- chou
}
function Impl.FoodFight(cfg, ctx)
	local markerPos, marker = pointPos("FoodDrop")
	local area = marker and marker:GetAttribute("Size") or Vector3.new(160, 1, 100)
	local top = markerPos and markerPos.Y or floorY() + 40
	local cx, cz = markerPos and markerPos.X or 0, markerPos and markerPos.Z or 0
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctx.folder }
	task.spawn(function()
		while ctx.running do
			local x = cx + rng:NextNumber(-area.X / 2, area.X / 2)
			local z = cz + rng:NextNumber(-area.Z / 2, area.Z / 2)
			local hit = workspace:Raycast(Vector3.new(x, top, z), Vector3.new(0, -60, 0), params)
			local ground = hit and hit.Position or Vector3.new(x, floorY(), z)
			local heal = rng:NextNumber() < cfg.HealChance
			local f = heal and { Color3.fromRGB(90, 220, 90), Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6) } or FOODS[rng:NextInteger(1, #FOODS)]
			local food = part(ctx.folder, f[3], Vector3.new(x, top, z), f[1], { shape = f[2], name = heal and "Apple" or "Food" })
			local fall = math.clamp((top - ground.Y) / 60, 0.4, 1.1)
			TweenService:Create(food, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = ground + Vector3.new(0, f[3].Y / 2, 0) }):Play()
			task.delay(fall, function()
				if not food.Parent then
					return
				end
				if heal then
					food.CanQuery = true
					food.CanTouch = true
					food:SetAttribute("Heal", cfg.Heal)
					CollectionService:AddTag(food, "HealPickup")
					return
				end
				food:Destroy()
				FloorFX:FireAllClients({ k = "Splat", p = ground, c = f[1] })
				for _, v in ipairs(Hitbox.box(CFrame.new(ground + Vector3.new(0, 2.5, 0)), Vector3.new(7, 6, 7), nil, 4)) do
					local vr = v:FindFirstChild("HumanoidRootPart")
					eventHit(v, cfg.Damage, vr and (vr.Position - ground) or Vector3.new(0, 0, 1), 6, 8, 0.35, "Splat", 0.3, { "SPLAT!" }, "Food")
				end
				local splat = part(ctx.folder, Vector3.new(0.1, 4, 4), CFrame.new(ground + Vector3.new(0, 0.06, 0)) * CYL, f[1], { shape = Enum.PartType.Cylinder, name = "Splat" })
				TweenService:Create(splat, TweenInfo.new(5), { Transparency = 1 }):Play()
				game:GetService("Debris"):AddItem(splat, 5)
			end)
			task.wait(cfg.Interval)
		end
	end)
	return function() end
end

function Impl.Overheat(cfg, ctx)
	local zones = points("SparkZone")
	local y = floorY()
	for i, z in ipairs(zones) do
		local size = z:GetAttribute("Size") or Vector3.new(12, 6, 10)
		local hz = part(ctx.folder, size, Vector3.new(z.Position.X, y + size.Y / 2, z.Position.Z), Color3.fromRGB(255, 220, 60), {
			transparency = 1, query = true, touch = true, name = "SparkZone",
		})
		hz:SetAttribute("Damage", cfg.Damage)
		hz:SetAttribute("Weapon", "Overheat")
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 230, 80), Color3.fromRGB(255, 120, 40))
		pe.LightEmission = 1
		pe.Speed = NumberRange.new(14, 26)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Lifetime = NumberRange.new(0.25, 0.45)
		pe.Size = NumberSequence.new(0.35, 0)
		pe.Rate = 70
		pe.Enabled = false
		pe.Parent = hz
		task.spawn(function()
			task.wait((i - 1) * 0.9)
			while ctx.running and hz.Parent do
				-- avertissement : clignote en jaune
				for _ = 1, 4 do
					if not ctx.running then return end
					hz.Transparency = 0.65
					task.wait(0.12)
					hz.Transparency = 1
					task.wait(0.12)
				end
				-- actif : zone de dégâts
				hz.Color = Color3.fromRGB(255, 90, 40)
				hz.Transparency = 0.55
				pe.Enabled = true
				CollectionService:AddTag(hz, "DamageZone")
				soundAt(SND.Spark, hz.Position, 0.6)
				local t0 = os.clock()
				while ctx.running and os.clock() - t0 < cfg.OnTime do
					task.wait(0.8)
					if ctx.running and hz.Parent then
						soundAt(SND.Spark, hz.Position, 0.4)
					end
				end
				if not hz.Parent then return end
				CollectionService:RemoveTag(hz, "DamageZone")
				pe.Enabled = false
				hz.Transparency = 1
				hz.Color = Color3.fromRGB(255, 220, 60)
				task.wait(cfg.OffTime)
			end
		end)
	end
	return function() end
end

local CAR_COLORS = { Color3.fromRGB(230, 60, 50), Color3.fromRGB(60, 120, 230), Color3.fromRGB(80, 200, 90), Color3.fromRGB(255, 170, 40), Color3.fromRGB(160, 80, 220) }
local function buildCar(parent, cf, color)
	local m = Instance.new("Model")
	m.Name = "RunawayCar"
	local body = part(m, Vector3.new(6, 2.2, 12), cf * CFrame.new(0, 1.9, 0), color)
	part(m, Vector3.new(5.4, 2.0, 6), cf * CFrame.new(0, 4.0, 0.6), color)
	part(m, Vector3.new(5.0, 1.6, 0.2), cf * CFrame.new(0, 4.0, -2.45), Color3.fromRGB(150, 210, 255), { transparency = 0.2 })
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part(m, Vector3.new(0.9, 2.2, 2.2), cf * CFrame.new(sx * 2.9, 1.1, sz * 3.8) * CYL, Color3.fromRGB(25, 25, 30), { shape = Enum.PartType.Cylinder })
		end
		part(m, Vector3.new(1.2, 0.6, 0.2), cf * CFrame.new(sx * 2, 2.2, -6.05), Color3.fromRGB(255, 250, 170), { material = Enum.Material.Neon })
		part(m, Vector3.new(1.2, 0.6, 0.2), cf * CFrame.new(sx * 2, 2.2, 6.05), Color3.fromRGB(255, 60, 40), { material = Enum.Material.Neon })
	end
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

function Impl.CarAlarm(cfg, ctx)
	local lanes = {}
	for _, s0 in ipairs(points("CarLaneStart")) do
		for _, e in ipairs(points("CarLaneEnd")) do
			if e:GetAttribute("Lane") == s0:GetAttribute("Lane") then
				table.insert(lanes, { s0.Position, e.Position })
			end
		end
	end
	if #lanes == 0 then
		return function() end
	end
	task.spawn(function()
		local k = 0
		while ctx.running do
			k += 1
			local lane = lanes[(k % #lanes) + 1]
			local y = floorY()
			local a = Vector3.new(lane[1].X, y, lane[1].Z)
			local b = Vector3.new(lane[2].X, y, lane[2].Z)
			local dir = (b - a).Unit
			-- avertissement : gyrophare + klaxon
			local flash = part(ctx.folder, Vector3.new(3, 3, 3), a + Vector3.new(0, 6, 0) + dir * 3, Color3.fromRGB(255, 200, 40), { material = Enum.Material.Neon, name = "Warning" })
			billboardText(flash, "CAR!", Color3.fromRGB(255, 220, 60), 140, Vector3.new(0, 3, 0))
			soundAt(SND.Horn, a, 0.9)
			for _ = 1, 4 do
				task.wait(0.15); flash.Transparency = 0.8
				task.wait(0.15); flash.Transparency = 0
			end
			flash:Destroy()
			if not ctx.running then
				break
			end
			local car = buildCar(ctx.folder, CFrame.lookAt(a, b), CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)])
			local alarm = Instance.new("Sound")
			alarm.SoundId = SND.CarAlarm
			alarm.Volume = 0.6
			alarm.Looped = true
			alarm.RollOffMaxDistance = 150
			alarm.Parent = car.PrimaryPart
			alarm:Play()
			local dist = (b - a).Magnitude
			local hitOnce = {}
			local t0 = os.clock()
			while ctx.running and car.Parent do
				local tr = math.min((os.clock() - t0) * cfg.Speed, dist)
				local pos = a + dir * tr
				car:PivotTo(CFrame.lookAt(pos, pos + dir))
				for _, v in ipairs(Hitbox.box(CFrame.lookAt(pos + Vector3.new(0, 3, 0), pos + Vector3.new(0, 3, 0) + dir), Vector3.new(7, 6, 13), nil, 6)) do
					if not hitOnce[v] then
						hitOnce[v] = true
						local vr = v:FindFirstChild("HumanoidRootPart")
						local side = vr and (vr.Position - pos) or dir
						eventHit(v, cfg.Damage, dir * 2 + side.Unit * 0.5, 85, 40, 0.9, "Heavy", 0.9, { "HONK!", "VROOM!", "BAM!" }, "Car")
					end
				end
				if tr >= dist then
					break
				end
				task.wait()
			end
			if car.Parent then
				car:Destroy()
			end
			task.wait(math.max(0.5, cfg.Interval - 1.2))
		end
	end)
	return function() end
end

------------------------------------------------------------------------
-- Spéciaux : CorporateGym, Mailroom, MeetingRooms, CEOOffice
------------------------------------------------------------------------
local SPHERE = Enum.PartType.Ball
local CYLINDER = Enum.PartType.Cylinder

-- FITNESS CHALLENGE : tapis de course + pistes => convoyeurs, ballons lestés qui rebondissent
function Impl.FitnessChallenge(cfg, ctx)
	local f = World.current()
	local belts, arrows = {}, {}
	if f then
		for _, p in ipairs(f:GetDescendants()) do
			if p:IsA("BasePart") and (p.Name == "TreadBelt" or p.Name == "TrackLane") then
				local dir = p:GetAttribute("ConveyorDir") or Vector3.new(1, 0, 0)
				local speed = (p.Name == "TreadBelt") and cfg.BeltSpeed or cfg.LaneSpeed
				table.insert(belts, { p = p, color = p.Color, mat = p.Material })
				-- partie ancrée + vitesse = convoyeur (les personnages posés dessus sont entraînés)
				p.AssemblyLinearVelocity = dir * speed
				if p.Name == "TreadBelt" or p.Size.Z > 4 then
					p.Color = Color3.fromRGB(255, 210, 60)
					p.Material = Enum.Material.Neon
					if p.Name == "TrackLane" then
						for i = 1, 6 do
							local a = part(ctx.folder, Vector3.new(5, 0.12, 1.4), p.CFrame, Color3.fromRGB(255, 255, 255), { material = Enum.Material.Neon, name = "ConveyorArrow" })
							table.insert(arrows, { a = a, lane = p, dir = dir, off = (i - 1) / 6 })
						end
					end
				end
			end
		end
	end
	globalSound(GameSounds.Whistle, 0.7, false, ctx.folder)
	-- ballons lestés
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { f }
	local spawns = points("BallSpawn")
	local balls = {}
	local r = 1.7
	for i = 1, cfg.Balls do
		local sp = spawns[(i - 1) % math.max(#spawns, 1) + 1]
		local pos = sp and sp.Position or Vector3.new(rng:NextNumber(-40, 40), floorY() + 14, rng:NextNumber(-40, 40))
		local ang = rng:NextNumber(0, math.pi * 2)
		local col = (i % 2 == 0) and Color3.fromRGB(150, 80, 45) or Color3.fromRGB(220, 50, 50)
		local b = part(ctx.folder, Vector3.new(r * 2, r * 2, r * 2), pos, col, { shape = SPHERE, name = "MedicineBall" })
		table.insert(balls, { p = b, v = Vector3.new(math.cos(ang), 0, math.sin(ang)) * cfg.BallSpeed, hit = {}, snd = 0 })
		FloorFX:FireAllClients({ k = "Puff", p = pos })
	end
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not ctx.running then
			conn:Disconnect()
			return
		end
		dt = math.min(dt, 1 / 20)
		local now = os.clock()
		-- flèches qui défilent sur les pistes
		for _, ar in ipairs(arrows) do
			if ar.a.Parent and ar.lane.Parent then
				local len = ar.lane.Size.X
				local t = ((now * cfg.LaneSpeed / len) + ar.off) % 1
				local pos = ar.lane.Position + ar.dir * (t - 0.5) * (len - 2) + Vector3.new(0, 0.17, 0)
				ar.a.CFrame = CFrame.lookAt(pos, pos + ar.dir)
			end
		end
		local fy = floorY()
		for _, b in ipairs(balls) do
			if b.p.Parent then
				b.v += Vector3.new(0, -cfg.Gravity * dt, 0)
				local pos = b.p.Position
				local step = b.v * dt
				local hit = f and f.Parent and workspace:Spherecast(pos, r, step, params)
				if hit then
					local n = hit.Normal
					b.v = b.v - 2 * b.v:Dot(n) * n
					if n.Y > 0.6 then
						b.v = Vector3.new(b.v.X, math.max(b.v.Y, cfg.Bounce), b.v.Z)
						if now - b.snd > 0.3 then
							b.snd = now
							soundAt(GameSounds.Boing, hit.Position, 0.35)
						end
					end
					pos = pos + step * 0.5 + n * 0.05
				else
					pos += step
				end
				-- garde-fous : rester dans l'étage
				if pos.Y < fy + r then
					pos = Vector3.new(pos.X, fy + r, pos.Z)
					b.v = Vector3.new(b.v.X, cfg.Bounce, b.v.Z)
				end
				if math.abs(pos.X) > 106 then
					b.v = Vector3.new(-math.sign(pos.X) * math.abs(b.v.X), b.v.Y, b.v.Z)
					pos = Vector3.new(math.clamp(pos.X, -106, 106), pos.Y, pos.Z)
				end
				if math.abs(pos.Z) > 106 then
					b.v = Vector3.new(b.v.X, b.v.Y, -math.sign(pos.Z) * math.abs(b.v.Z))
					pos = Vector3.new(pos.X, pos.Y, math.clamp(pos.Z, -106, 106))
				end
				-- vitesse horizontale constante (ils ne s'arrêtent jamais)
				local hv = Vector3.new(b.v.X, 0, b.v.Z)
				if hv.Magnitude < 1 then
					local a = rng:NextNumber(0, math.pi * 2)
					hv = Vector3.new(math.cos(a), 0, math.sin(a))
				end
				hv = hv.Unit * cfg.BallSpeed
				b.v = Vector3.new(hv.X, b.v.Y, hv.Z)
				b.p.CFrame = CFrame.new(pos) * (b.p.CFrame - b.p.Position) * CFrame.Angles(dt * 5, 0, dt * 3)
				for _, v in ipairs(Hitbox.box(CFrame.new(pos), Vector3.new(5, 5, 5), nil, 4)) do
					if not b.hit[v] or now - b.hit[v] > 1 then
						b.hit[v] = now
						eventHit(v, cfg.Damage, hv, cfg.Knockback, cfg.Up, 0.4, "Light", 0.45, { "BONK!", "CARDIO!", "OOF!" }, "MedicineBall")
					end
				end
			end
		end
	end)
	return function()
		if conn then
			conn:Disconnect()
		end
		for _, b in ipairs(belts) do
			if b.p.Parent then
				b.p.AssemblyLinearVelocity = Vector3.zero
				b.p.Color = b.color
				b.p.Material = b.mat
			end
		end
	end
end

-- PACKAGE AVALANCHE : des cartons tombent du plafond (ombre d'avertissement, puis impact + débris)
local BOX_COLORS = { Color3.fromRGB(196, 150, 95), Color3.fromRGB(180, 132, 80), Color3.fromRGB(210, 168, 110) }
function Impl.PackageAvalanche(cfg, ctx)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local function dropOne()
		local chars = allCharacters()
		local pos
		if #chars > 0 and rng:NextNumber() < cfg.TargetChance then
			local rp = chars[rng:NextInteger(1, #chars)].HumanoidRootPart.Position
			pos = Vector3.new(rp.X + rng:NextNumber(-6, 6), floorY(), rp.Z + rng:NextNumber(-6, 6))
		else
			pos = randomFloorPoint(10)
		end
		local ignore = { ctx.folder, workspace:FindFirstChild("ActiveItems"), workspace:FindFirstChild("FX"), workspace:FindFirstChild("Dummies") }
		for _, c in ipairs(chars) do
			table.insert(ignore, c)
		end
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(Vector3.new(pos.X, floorY() + 45, pos.Z), Vector3.new(0, -60, 0), params)
		local ground = hit and hit.Position or Vector3.new(pos.X, floorY(), pos.Z)
		local s = rng:NextNumber(3.6, 5)
		local col = BOX_COLORS[rng:NextInteger(1, #BOX_COLORS)]
		local shadow = part(ctx.folder, Vector3.new(0.1, 1, 1), CFrame.new(ground + Vector3.new(0, 0.08, 0)) * CYL, Color3.fromRGB(25, 18, 10), {
			shape = CYLINDER, transparency = 0.55, name = "Shadow",
		})
		TweenService:Create(shadow, TweenInfo.new(cfg.Telegraph), { Size = Vector3.new(0.1, cfg.Radius * 2, cfg.Radius * 2), Transparency = 0.25 }):Play()
		local rot = CFrame.Angles(0, rng:NextNumber(0, 3), 0)
		local box = part(ctx.folder, Vector3.new(s, s * 0.8, s), CFrame.new(ground + Vector3.new(0, 48, 0)) * rot, col, { name = "Package" })
		local tape = part(ctx.folder, Vector3.new(s + 0.05, 0.1, s * 0.28), box.CFrame * CFrame.new(0, s * 0.4 + 0.04, 0), Color3.fromRGB(240, 200, 80), { name = "Tape" })
		local fall = 0.5
		task.delay(cfg.Telegraph - fall, function()
			if not ctx.running or not box.Parent then
				return
			end
			local target = CFrame.new(ground + Vector3.new(0, s * 0.4, 0)) * rot
			local ti = TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(box, ti, { CFrame = target }):Play()
			TweenService:Create(tape, ti, { CFrame = target * CFrame.new(0, s * 0.4 + 0.04, 0) }):Play()
		end)
		task.delay(cfg.Telegraph, function()
			if not ctx.running or not box.Parent then
				return
			end
			shadow:Destroy()
			box:Destroy()
			tape:Destroy()
			FX:FireAllClients({ k = "Break", p = ground + Vector3.new(0, 1.5, 0), m = "Wood" })
			soundAt(GameSounds.Thud, ground, 0.8)
			-- le carton éclate en morceaux
			for _ = 1, 5 do
				local d = part(ctx.folder, Vector3.new(rng:NextNumber(1, 1.8), 0.2, rng:NextNumber(1, 1.8)),
					CFrame.new(ground + Vector3.new(rng:NextNumber(-1.5, 1.5), 1.5, rng:NextNumber(-1.5, 1.5))), col, { collide = true, name = "BoxDebris" })
				d.Anchored = false
				d.CollisionGroup = "Debris"
				d.AssemblyLinearVelocity = Vector3.new(rng:NextNumber(-18, 18), rng:NextNumber(14, 26), rng:NextNumber(-18, 18))
				d.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-10, 10), rng:NextNumber(-10, 10))
				game:GetService("Debris"):AddItem(d, 2.5)
			end
			for _, v in ipairs(Hitbox.box(CFrame.new(ground + Vector3.new(0, 3, 0)), Vector3.new(cfg.Radius * 2, 7, cfg.Radius * 2), nil, 8)) do
				local vr = v:FindFirstChild("HumanoidRootPart")
				local d = vr and (vr.Position - ground) or Vector3.new(0, 0, 1)
				eventHit(v, cfg.Damage, d, cfg.Knockback, cfg.Up, 0.6, "Heavy", 0.6, { "PACKAGE!", "DELIVERED!", "THUD!" }, "Package")
			end
		end)
	end
	task.spawn(function()
		while ctx.running do
			for _ = 1, cfg.PerWave do
				dropOne()
			end
			task.wait(cfg.Interval)
		end
	end)
	return function() end
end

-- REPLY ALL : les écrans de projection tirent des vagues d'enveloppes (projectiles légers)
function Impl.ReplyAll(cfg, ctx)
	local projs = points("Projector")
	if #projs == 0 then
		return function() end
	end
	local f = World.current()
	local screens = {}
	if f then
		for _, p in ipairs(f:GetDescendants()) do
			if p:IsA("BasePart") and p.Name == "ProjectorScreen" then
				table.insert(screens, { p = p, c = p.Color, m = p.Material })
				p.Color = Color3.fromRGB(70, 150, 255)
				p.Material = Enum.Material.Neon
			end
		end
	end
	for _, pr in ipairs(projs) do
		local anchor = part(ctx.folder, Vector3.new(1, 1, 1), pr.Position + Vector3.new(0, 5, 0), Color3.new(1, 1, 1), { transparency = 1, name = "MailBadge" })
		billboardText(anchor, "99+ NEW EMAILS", Color3.fromRGB(255, 90, 90), 200, Vector3.new(0, 0, 0))
	end
	globalSound(GameSounds.Ding, 0.6, false, ctx.folder)
	local ENV_COLORS = { Color3.fromRGB(255, 252, 240), Color3.fromRGB(255, 240, 190), Color3.fromRGB(220, 240, 255) }
	task.spawn(function()
		while ctx.running do
			local order = table.clone(projs)
			for i = #order, 2, -1 do
				local j = rng:NextInteger(1, i)
				order[i], order[j] = order[j], order[i]
			end
			for k = 1, math.min(cfg.PerWave, #order) do
				local pr = order[k]
				if pr.Parent and ctx.running then
					local cf = pr.CFrame
					soundAt(GameSounds.Ding, cf.Position, 0.7)
					for j = 1, cfg.Fan do
						local a = math.rad((j - (cfg.Fan + 1) / 2) * (60 / math.max(cfg.Fan - 1, 1)))
						local look = (cf * CFrame.Angles(0, a, 0)).LookVector
						local dir = Vector3.new(look.X, 0, look.Z).Unit
						local env = part(ctx.folder, Vector3.new(2.4, 0.25, 1.7), CFrame.lookAt(cf.Position, cf.Position + dir),
							ENV_COLORS[rng:NextInteger(1, #ENV_COLORS)], { name = "Email" })
						projectile(ctx, env, dir, cfg.Speed, 2.6, function(v)
							eventHit(v, cfg.Damage, dir, 14, 6, 0.3, "Light", 0.3, { "REPLY ALL!", "SPAM!", "FWD: FWD:", "CC'D!" }, "Email")
						end)
					end
				end
			end
			task.wait(cfg.Interval)
		end
	end)
	return function()
		for _, s in ipairs(screens) do
			if s.p.Parent then
				s.p.Color = s.c
				s.p.Material = s.m
			end
		end
	end
end

-- SHAREHOLDER MEETING : pluie de pièces d'or (soin / Overtime) + statue géante du PDG qui piétine
function Impl.ShareholderMeeting(cfg, ctx)
	local GOLD = Color3.fromRGB(255, 200, 50)
	local path = points("StatuePath")
	table.sort(path, function(a, b)
		return (a:GetAttribute("Order") or 0) < (b:GetAttribute("Order") or 0)
	end)
	if #path == 0 then
		path = { { Position = Vector3.new(0, 0, 0) } }
	end
	local scale = cfg.Scale
	local pos = Vector3.new(path[1].Position.X, floorY() + 3 * scale, path[1].Position.Z)
	local statue = RigBuilder.r6("GOLDEN CEO", { Skin = GOLD, Shirt = GOLD, Pants = Color3.fromRGB(225, 165, 30), Tie = Color3.fromRGB(200, 30, 40) })
	for _, d in ipairs(statue:GetDescendants()) do
		if d:IsA("Decal") then
			d:Destroy()
		end
	end
	statue:PivotTo(CFrame.new(pos))
	statue:ScaleTo(scale)
	for _, p in ipairs(statue:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.Anchored = false
		end
	end
	local root = statue.HumanoidRootPart
	root.Anchored = true
	local hum = statue:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.MaxHealth = 1e9
	hum.Health = 1e9
	statue.Parent = ctx.folder
	billboardText(statue.Head, "GOLDEN CEO", GOLD, 300, Vector3.new(0, 3 * scale * 0.6, 0))
	local bubble = billboardText(statue.Head, "PROFIT!", Color3.fromRGB(255, 255, 255), 260, Vector3.new(0, 3 * scale, 0))
	FloorFX:FireAllClients({ k = "Puff", p = Vector3.new(pos.X, floorY(), pos.Z), big = true })
	globalSound(GameSounds.PowerUp, 0.6, false, ctx.folder)
	local torso = statue.Torso
	local motors = { RH = torso:FindFirstChild("Right Hip"), LH = torso:FindFirstChild("Left Hip"), RS = torso:FindFirstChild("Right Shoulder"), LS = torso:FindFirstChild("Left Shoulder") }
	local base = {}
	for k, m in pairs(motors) do
		base[k] = m.C0
	end
	local quotes = { "PROFIT!", "SYNERGY!", "DIVIDENDS!", "STOCKS UP!", "YOU'RE ALL FIRED!" }
	local target = math.min(2, #path)
	local stomping = false
	local nextStomp = os.clock() + 2
	local phase, lastStep = 0, 0
	local function doStomp()
		local center = Vector3.new(pos.X, floorY(), pos.Z)
		local ring = part(ctx.folder, Vector3.new(0.12, 2, 2), CFrame.new(center + Vector3.new(0, 0.12, 0)) * CYL, Color3.fromRGB(255, 60, 40), {
			shape = CYLINDER, transparency = 0.5, name = "StompWarning",
		})
		TweenService:Create(ring, TweenInfo.new(cfg.Telegraph), { Size = Vector3.new(0.12, cfg.Radius * 2, cfg.Radius * 2) }):Play()
		bubble.TextLabel.Text = quotes[rng:NextInteger(1, #quotes)]
		local t = 0
		local rot = root.CFrame.Rotation
		while t < cfg.Telegraph and ctx.running and root.Parent do
			t += task.wait()
			local a = math.clamp(t / cfg.Telegraph, 0, 1)
			root.CFrame = CFrame.new(pos + Vector3.new(0, a * 1.2 * scale, 0)) * rot
			if motors.RH then motors.RH.C0 = base.RH * CFrame.Angles(0, 0, a * 1.3) end
			if motors.RS then motors.RS.C0 = base.RS * CFrame.Angles(0, 0, a * 2.6) end
			if motors.LS then motors.LS.C0 = base.LS * CFrame.Angles(0, 0, -a * 2.6) end
		end
		if ring.Parent then
			ring:Destroy()
		end
		if not ctx.running or not root.Parent then
			return
		end
		root.CFrame = CFrame.new(pos) * rot
		for k, m in pairs(motors) do
			m.C0 = base[k]
		end
		-- onde de choc
		FloorFX:FireAllClients({ k = "Stomp", p = center })
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			FloorFX:FireAllClients({ k = "Puff", p = center + Vector3.new(math.cos(a), 0, math.sin(a)) * cfg.Radius * 0.6 })
		end
		soundAt(GameSounds.GroundSlam, center, 1)
		local wave = part(ctx.folder, Vector3.new(1.5, 2, 2), CFrame.new(center + Vector3.new(0, 0.6, 0)) * CYL, GOLD, { shape = CYLINDER, transparency = 0.3, name = "Shockwave" })
		TweenService:Create(wave, TweenInfo.new(0.35), { Size = Vector3.new(0.4, cfg.Radius * 2.2, cfg.Radius * 2.2), Transparency = 1 }):Play()
		game:GetService("Debris"):AddItem(wave, 0.4)
		for _, v in ipairs(Hitbox.box(CFrame.new(center + Vector3.new(0, 4, 0)), Vector3.new(cfg.Radius * 2, 8, cfg.Radius * 2), nil, 12)) do
			local vr = v:FindFirstChild("HumanoidRootPart")
			if vr then
				local d = (vr.Position - center) * Vector3.new(1, 0, 1)
				if d.Magnitude <= cfg.Radius then
					eventHit(v, cfg.Damage, d.Magnitude > 0.1 and d or Vector3.new(0, 0, 1), cfg.Knockback, cfg.Up, 0.8, "Heavy", 0.9,
						{ "STOMP!", "QUARTERLY LOSS!", "DOWNSIZED!" }, "Statue")
				end
			end
		end
		task.wait(0.4)
		nextStomp = os.clock() + cfg.StompEvery
		stomping = false
	end
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not ctx.running or not root.Parent then
			conn:Disconnect()
			return
		end
		if stomping then
			return
		end
		local y = floorY() + 3 * scale
		local tp = path[target].Position
		local flat = Vector3.new(tp.X, y, tp.Z) - Vector3.new(pos.X, y, pos.Z)
		if flat.Magnitude < 1 then
			target = target % #path + 1
		else
			pos = Vector3.new(pos.X, y, pos.Z) + flat.Unit * math.min(flat.Magnitude, cfg.WalkSpeed * dt)
		end
		local face = flat.Magnitude > 0.1 and flat.Unit or root.CFrame.LookVector
		phase += dt * 3
		local bob = math.abs(math.sin(phase)) * 0.3 * scale
		root.CFrame = CFrame.lookAt(pos + Vector3.new(0, bob, 0), pos + Vector3.new(0, bob, 0) + face)
		local swing = math.sin(phase) * 0.6
		if motors.RH then motors.RH.C0 = base.RH * CFrame.Angles(0, 0, swing) end
		if motors.LH then motors.LH.C0 = base.LH * CFrame.Angles(0, 0, swing) end
		if motors.RS then motors.RS.C0 = base.RS * CFrame.Angles(0, 0, -swing) end
		if motors.LS then motors.LS.C0 = base.LS * CFrame.Angles(0, 0, -swing) end
		local step = math.floor(phase / math.pi)
		if step ~= lastStep then
			lastStep = step
			FloorFX:FireAllClients({ k = "Puff", p = Vector3.new(pos.X, floorY(), pos.Z) })
		end
		if os.clock() >= nextStomp then
			stomping = true
			task.spawn(doStomp)
		end
	end)
	-- pluie de pièces : "+HP" (HealPickup) ou "+OT" (jauge Overtime)
	local otCoins = {}
	local live = 0
	local function spawnCoin()
		local ground = randomFloorPoint(8)
		local heal = rng:NextNumber() < cfg.HealChance
		local coin = part(ctx.folder, Vector3.new(0.5, 2.6, 2.6), CFrame.new(ground + Vector3.new(0, 30, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), GOLD, {
			shape = CYLINDER, name = heal and "HealCoin" or "OvertimeCoin",
		})
		local bb = billboardText(coin, heal and "+HP" or "+OT", heal and Color3.fromRGB(90, 255, 110) or Color3.fromRGB(255, 120, 60), 70, Vector3.new(0, 2.2, 0))
		bb.Size = UDim2.fromOffset(70, 34)
		bb.AlwaysOnTop = false
		bb.MaxDistance = 90
		live += 1
		coin.Destroying:Connect(function()
			live -= 1
		end)
		local target = ground + Vector3.new(0, 1.4, 0)
		TweenService:Create(coin, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = target }):Play()
		task.delay(0.7, function()
			if not coin.Parent or not ctx.running then
				return
			end
			if heal then
				coin.CanQuery = true
				coin.CanTouch = true
				coin:SetAttribute("Heal", cfg.Heal)
				CollectionService:AddTag(coin, "HealPickup")
			else
				otCoins[coin] = true
			end
			game:GetService("Debris"):AddItem(coin, cfg.CoinLife)
		end)
	end
	task.spawn(function()
		while ctx.running do
			if live < cfg.MaxCoins then
				spawnCoin()
			end
			task.wait(cfg.CoinInterval)
		end
	end)
	-- ramassage des pièces Overtime (+10, plafonné par CombatService.addOvertime)
	task.spawn(function()
		while ctx.running do
			for coin in pairs(otCoins) do
				if not coin.Parent then
					otCoins[coin] = nil
				else
					for _, c in ipairs(allCharacters()) do
						local d = c.HumanoidRootPart.Position - coin.Position
						if Vector3.new(d.X, 0, d.Z).Magnitude < 3.2 and math.abs(d.Y) < 5 then
							otCoins[coin] = nil
							pcall(CombatService.addOvertime, c, cfg.Overtime)
							local plr = Players:GetPlayerFromCharacter(c)
							if plr then
								pcall(Announce.toast, plr, "+" .. cfg.Overtime .. " OVERTIME!", GOLD)
							end
							soundAt(GameSounds.Pickup, coin.Position, 0.6)
							FloorFX:FireAllClients({ k = "Puff", p = coin.Position })
							coin:Destroy()
							break
						end
					end
				end
			end
			task.wait(0.1)
		end
	end)
	return function()
		if conn then
			conn:Disconnect()
		end
	end
end

------------------------------------------------------------------------
-- Spéciaux : Lobby, Rooftop, Archives, GameRoom, Daycare, Auditorium, Warehouse, Spa
------------------------------------------------------------------------
-- coup d'événement avec options avancées (launch = vitesse imposée)
local function eventHitEx(victim, p)
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	pcall(CharacterState.recordHit, victim, nil, p.weapon, "Event")
	p.attacker = nil
	p.victim = victim
	p.cause = "Event"
	p.hitPos = p.hitPos or root.Position
	p.dir = CombatService.flatUnit(p.dir or Vector3.new(0, 0, -1), Vector3.new(0, 0, -1))
	CombatService.applyHit(p)
end

-- couloirs <prefix>Start / <prefix>End appariés par l'attribut Lane
local function lanePairs(prefix)
	local list = {}
	for _, a in ipairs(points(prefix .. "Start")) do
		for _, b in ipairs(points(prefix .. "End")) do
			if b:GetAttribute("Lane") == a:GetAttribute("Lane") then
				table.insert(list, { a = a.Position, b = b.Position, lane = a:GetAttribute("Lane") or 0 })
			end
		end
	end
	table.sort(list, function(x, y)
		return x.lane < y.lane
	end)
	return list
end

-- bande clignotante + flèches le long d'un couloir (avertissement) ; bloque pendant dur secondes
local function laneWarning(ctx, a, b, width, color, dur, text)
	local y = floorY()
	a = Vector3.new(a.X, y, a.Z)
	b = Vector3.new(b.X, y, b.Z)
	local dir = (b - a).Unit
	local len = (b - a).Magnitude
	local mid = (a + b) / 2 + Vector3.new(0, 0.12, 0)
	local strip = part(ctx.folder, Vector3.new(width, 0.1, len), CFrame.lookAt(mid, mid + dir), color, {
		material = Enum.Material.Neon, transparency = 0.5, name = "LaneWarning",
	})
	local extra = {}
	for d = 10, len - 6, 16 do
		local p = a + dir * d + Vector3.new(0, 0.2, 0)
		table.insert(extra, part(ctx.folder, Vector3.new(width * 0.4, 0.1, 3), CFrame.lookAt(p, p + dir), Color3.new(1, 1, 1), {
			material = Enum.Material.Neon, name = "LaneArrow",
		}))
	end
	if text then
		local anchor = part(ctx.folder, Vector3.new(1, 1, 1), a + dir * 8 + Vector3.new(0, 7, 0), Color3.new(1, 1, 1), { transparency = 1, name = "LaneText" })
		billboardText(anchor, text, color, 220, Vector3.new(0, 0, 0))
		table.insert(extra, anchor)
	end
	local t0 = os.clock()
	local on = true
	while ctx.running and os.clock() - t0 < dur do
		on = not on
		strip.Transparency = on and 0.3 or 0.75
		for _, e in ipairs(extra) do
			if e.Name == "LaneArrow" then
				e.Transparency = on and 0 or 0.6
			end
		end
		task.wait(0.14)
	end
	strip:Destroy()
	for _, e in ipairs(extra) do
		e:Destroy()
	end
end

-- dessus réel du décor (scène, gradins, héliport...) sous une position XZ
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
local function groundAt(x, z)
	local f = World.current()
	local y = floorY()
	if f then
		groundParams.FilterDescendantsInstances = { f }
		local hit = workspace:Raycast(Vector3.new(x, y + 19, z), Vector3.new(0, -29, 0), groundParams) -- sous les rampes de projecteurs
		if hit then
			return hit.Position
		end
	end
	return Vector3.new(x, y, z)
end

local function randomChar()
	local chars = allCharacters()
	if #chars == 0 then
		return nil
	end
	return chars[rng:NextInteger(1, #chars)]
end

-- RUSH HOUR (Lobby) : des foules de banlieusards traversent le hall par couloirs et bousculent
local SUITS = { Color3.fromRGB(45, 55, 80), Color3.fromRGB(70, 70, 80), Color3.fromRGB(110, 60, 50), Color3.fromRGB(40, 90, 150), Color3.fromRGB(150, 150, 160) }
local SKINS = { Color3.fromRGB(255, 220, 180), Color3.fromRGB(210, 160, 120), Color3.fromRGB(140, 95, 65), Color3.fromRGB(240, 200, 160) }
local function buildCommuter(parent)
	local m = Instance.new("Model")
	m.Name = "Commuter"
	local torso = part(m, Vector3.new(2, 2, 1), CFrame.new(0, 3, 0), SUITS[rng:NextInteger(1, #SUITS)], { name = "Torso" })
	part(m, Vector3.new(2, 2, 1), CFrame.new(0, 1, 0), Color3.fromRGB(40, 40, 50), { name = "Legs" })
	part(m, Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 4.6, 0), SKINS[rng:NextInteger(1, #SKINS)], { name = "Head" })
	part(m, Vector3.new(0.4, 1.1, 0.2), CFrame.new(0, 3.3, -0.55), Color3.fromRGB(200, 40, 40), { name = "Tie" })
	part(m, Vector3.new(1.4, 1, 0.4), CFrame.new(1.4, 1.6, 0), Color3.fromRGB(110, 70, 40), { name = "Briefcase" })
	m.PrimaryPart = torso
	m.Parent = parent
	return m
end

function Impl.RushHour(cfg, ctx)
	local lanes = lanePairs("CommuterLane")
	if #lanes == 0 then
		return function() end
	end
	local crowdSnd = globalSound(SND.Crowd, 0.35, true, ctx.folder)
	local function wave(lane)
		laneWarning(ctx, lane.a, lane.b, 11, Color3.fromRGB(255, 210, 60), cfg.Telegraph, "RUSH HOUR!")
		if not ctx.running then
			return
		end
		local y = floorY()
		local a = Vector3.new(lane.a.X, y, lane.a.Z)
		local b = Vector3.new(lane.b.X, y, lane.b.Z)
		local dir = (b - a).Unit
		local side = Vector3.new(-dir.Z, 0, dir.X)
		local people = {}
		for _ = 1, cfg.Crowd do
			table.insert(people, { m = buildCommuter(ctx.folder), off = side * rng:NextNumber(-4, 4) - dir * rng:NextNumber(0, 12), ph = rng:NextNumber(0, 6) })
		end
		soundAt(GameSounds.Whistle, a, 0.7)
		local dist = (b - a).Magnitude + 12
		local hitAt = {}
		local t0 = os.clock()
		while ctx.running do
			local t = os.clock() - t0
			local tr = t * cfg.Speed
			if tr > dist then
				break
			end
			local yy = floorY()
			local head = Vector3.new(a.X, yy, a.Z) + dir * tr
			for _, p in ipairs(people) do
				if p.m.Parent then
					local pos = head + p.off + Vector3.new(0, 3 + math.abs(math.sin(t * 9 + p.ph)) * 0.5, 0)
					p.m:PivotTo(CFrame.lookAt(pos, pos + dir))
				end
			end
			-- une seule boîte pour toute la foule
			local center = head - dir * 6 + Vector3.new(0, 3, 0)
			for _, v in ipairs(Hitbox.box(CFrame.lookAt(center, center + dir), Vector3.new(11, 6, 16), nil, 8)) do
				if not hitAt[v] or os.clock() - hitAt[v] > 0.8 then
					hitAt[v] = os.clock()
					local vr = v:FindFirstChild("HumanoidRootPart")
					local s = vr and (vr.Position - center):Dot(side) or 1
					eventHit(v, cfg.Damage, dir * 2 + side * (s >= 0 and 0.6 or -0.6), cfg.Knockback, cfg.Up, 0.5, "Heavy", 0.6,
						{ "EXCUSE ME!", "I'M LATE!", "MOVE!", "COMING THROUGH!" }, "Commuters")
				end
			end
			task.wait()
		end
		for _, p in ipairs(people) do
			if p.m.Parent then
				p.m:Destroy()
			end
		end
	end
	task.spawn(function()
		local k = 0
		while ctx.running do
			k += 1
			task.spawn(wave, lanes[(k - 1) % #lanes + 1])
			-- de temps en temps, deux couloirs à la fois
			if #lanes > 1 and k % 3 == 0 then
				task.wait(0.6)
				task.spawn(wave, lanes[k % #lanes + 1])
			end
			task.wait(cfg.Interval)
		end
	end)
	return function()
		if crowdSnd then
			crowdSnd:Stop()
		end
	end
end

-- HELICOPTER LANDING (Rooftop) : hélico en vol stationnaire, souffle du rotor, caisses de ravitaillement
local function buildHeli(parent)
	local m = Instance.new("Model")
	m.Name = "Helicopter"
	local RED, WHITE, DARK = Color3.fromRGB(230, 70, 40), Color3.fromRGB(245, 245, 245), Color3.fromRGB(45, 45, 50)
	local body = part(m, Vector3.new(8, 7, 14), CFrame.new(0, 0, 0), RED, { name = "Body" })
	part(m, Vector3.new(8.2, 1.2, 14.2), CFrame.new(0, -0.6, 0), WHITE, { name = "Stripe" })
	part(m, Vector3.new(7, 5, 4), CFrame.new(0, 0.6, -8.5), Color3.fromRGB(140, 210, 255), { transparency = 0.25, name = "Cockpit" })
	part(m, Vector3.new(1.8, 1.8, 16), CFrame.new(0, 1.6, 15), RED, { name = "TailBoom" })
	part(m, Vector3.new(0.6, 5, 3), CFrame.new(0, 3.8, 22), RED, { name = "TailFin" })
	part(m, Vector3.new(1, 1.4, 1), CFrame.new(0, 4.2, 0), DARK, { name = "Mast" })
	local r1 = part(m, Vector3.new(36, 0.3, 1.6), CFrame.new(0, 5, 0), DARK, { name = "Rotor" })
	local r2 = part(m, Vector3.new(1.6, 0.3, 36), CFrame.new(0, 5, 0), DARK, { name = "Rotor" })
	local tr = part(m, Vector3.new(0.3, 5, 0.8), CFrame.new(0.7, 3.8, 22), DARK, { name = "TailRotor" })
	for _, sx in ipairs({ -1, 1 }) do
		part(m, Vector3.new(0.6, 0.6, 14), CFrame.new(sx * 3.6, -5, 0), DARK, { name = "Skid" })
		part(m, Vector3.new(0.4, 2.2, 0.4), CFrame.new(sx * 3.4, -3.9, -4), DARK)
		part(m, Vector3.new(0.4, 2.2, 0.4), CFrame.new(sx * 3.4, -3.9, 4), DARK)
	end
	part(m, Vector3.new(1, 1, 1), CFrame.new(0, -3.6, -6.5), Color3.fromRGB(255, 255, 200), { material = Enum.Material.Neon, name = "Searchlight" })
	m.PrimaryPart = body
	m.Parent = parent
	return m, r1, r2, tr
end

function Impl.HelicopterLanding(cfg, ctx)
	local padPos = pointPos("HeliPad") or Vector3.new(0, floorY(), 0)
	local heli, r1, r2, tr = buildHeli(ctx.folder)
	local hover = Vector3.new(padPos.X, floorY() + cfg.HoverHeight, padPos.Z)
	local startP = hover + Vector3.new(-170, 70, -60)
	local exitP = hover + Vector3.new(170, 80, 60)
	heli:PivotTo(CFrame.new(startP))
	local snd = Instance.new("Sound")
	snd.SoundId = SND.Helicopter
	snd.Looped = true
	snd.Volume = 0.8
	snd.RollOffMinDistance = 40
	snd.RollOffMaxDistance = 400
	snd.Parent = heli.PrimaryPart
	snd:Play()
	local ring = part(ctx.folder, Vector3.new(0.15, cfg.WindRadius * 2, cfg.WindRadius * 2), CFrame.new(padPos.X, floorY() + 0.2, padPos.Z) * CYL,
		Color3.fromRGB(255, 220, 60), { shape = CYLINDER, transparency = 0.85, name = "WindZone" })
	local anchor = part(ctx.folder, Vector3.new(1, 1, 1), startP, Color3.new(1, 1, 1), { transparency = 1, name = "HeliText" })
	billboardText(anchor, "ROTOR WASH!", Color3.fromRGB(255, 220, 60), 260, Vector3.new(0, 0, 0))

	local function dropCrate(fromPos)
		local c = randomChar()
		local target
		if c and rng:NextNumber() < 0.6 then
			local rp = c.HumanoidRootPart.Position
			target = Vector3.new(rp.X + rng:NextNumber(-5, 5), 0, rp.Z + rng:NextNumber(-5, 5))
		else
			local ang, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(14, 40)
			target = Vector3.new(padPos.X + math.cos(ang) * r, 0, padPos.Z + math.sin(ang) * r)
		end
		local ground = groundAt(math.clamp(target.X, -100, 100), math.clamp(target.Z, -100, 100))
		local shadow = part(ctx.folder, Vector3.new(0.12, 1, 1), CFrame.new(ground + Vector3.new(0, 0.1, 0)) * CYL, Color3.fromRGB(255, 60, 40), {
			shape = CYLINDER, transparency = 0.5, name = "CrateShadow",
		})
		TweenService:Create(shadow, TweenInfo.new(cfg.Telegraph), { Size = Vector3.new(0.12, cfg.CrateRadius * 2, cfg.CrateRadius * 2), Transparency = 0.25 }):Play()
		local m = Instance.new("Model")
		m.Name = "SupplyCrate"
		local box = part(m, Vector3.new(4, 4, 4), CFrame.new(fromPos), Color3.fromRGB(170, 120, 70), { name = "Crate" })
		local c1 = part(m, Vector3.new(3, 0.2, 0.9), CFrame.new(fromPos + Vector3.new(0, 2.05, 0)), Color3.fromRGB(230, 40, 40), { name = "Cross" })
		local c2 = part(m, Vector3.new(0.9, 0.2, 3), CFrame.new(fromPos + Vector3.new(0, 2.06, 0)), Color3.fromRGB(230, 40, 40), { name = "Cross" })
		m.PrimaryPart = box
		m.Parent = ctx.folder
		local fall = 0.7
		task.delay(math.max(0, cfg.Telegraph - fall), function()
			if not ctx.running or not m.Parent then
				return
			end
			local target2 = CFrame.new(ground + Vector3.new(0, 2, 0))
			local ti = TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			TweenService:Create(box, ti, { CFrame = target2 }):Play()
			TweenService:Create(c1, ti, { CFrame = target2 * CFrame.new(0, 2.05, 0) }):Play()
			TweenService:Create(c2, ti, { CFrame = target2 * CFrame.new(0, 2.06, 0) }):Play()
		end)
		task.delay(cfg.Telegraph, function()
			if shadow.Parent then
				shadow:Destroy()
			end
			if not ctx.running or not m.Parent then
				return
			end
			soundAt(GameSounds.Thud, ground, 0.8)
			FX:FireAllClients({ k = "Break", p = ground + Vector3.new(0, 1.5, 0), m = "Wood" })
			for _, v in ipairs(Hitbox.box(CFrame.new(ground + Vector3.new(0, 3, 0)), Vector3.new(cfg.CrateRadius * 2, 7, cfg.CrateRadius * 2), nil, 8)) do
				local vr = v:FindFirstChild("HumanoidRootPart")
				local d = vr and (vr.Position - ground) or Vector3.new(0, 0, 1)
				eventHit(v, cfg.CrateDamage, d, 50, 30, 0.6, "Heavy", 0.6, { "SUPPLY DROP!", "THUD!", "SPECIAL DELIVERY!" }, "SupplyCrate")
			end
			-- la caisse reste : soin au contact
			for _, p in ipairs(m:GetChildren()) do
				p.CanQuery = true
				p.CanTouch = true
			end
			m:SetAttribute("Heal", cfg.Heal)
			CollectionService:AddTag(m, "HealPickup")
			local bb = billboardText(box, "+HP", Color3.fromRGB(90, 255, 110), 80, Vector3.new(0, 3.5, 0))
			bb.AlwaysOnTop = false
			bb.MaxDistance = 120
		end)
	end

	local t0 = os.clock()
	local arriveT, leaveT = 4, cfg.Duration - 3.5
	local spin, lastWind = 0, 0
	local cratesLeft = cfg.Crates
	local nextCrate = arriveT + 1
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not ctx.running or not heli.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		local y = floorY()
		hover = Vector3.new(padPos.X, y + cfg.HoverHeight, padPos.Z)
		local pos, look
		if t < arriveT then
			local e = 1 - (1 - t / arriveT) ^ 3
			pos = startP:Lerp(hover, e)
			look = (hover - startP) * Vector3.new(1, 0, 1)
		elseif t < leaveT then
			pos = hover + Vector3.new(math.sin(t * 0.9) * 2.5, math.sin(t * 1.7) * 1.2, math.cos(t * 0.7) * 2.5)
			look = Vector3.new(math.sin(t * 0.25), 0, -math.cos(t * 0.25))
		else
			local a = math.clamp((t - leaveT) / 3.5, 0, 1)
			pos = hover:Lerp(exitP, a * a)
			look = (exitP - hover) * Vector3.new(1, 0, 1)
		end
		local tilt = (t < arriveT or t >= leaveT) and CFrame.Angles(math.rad(-10), 0, 0) or CFrame.new()
		local cf = CFrame.lookAt(pos, pos + look.Unit) * tilt
		heli:PivotTo(cf)
		spin += dt * 25
		r1.CFrame = cf * CFrame.new(0, 5, 0) * CFrame.Angles(0, spin, 0)
		r2.CFrame = cf * CFrame.new(0, 5, 0) * CFrame.Angles(0, spin, 0)
		tr.CFrame = cf * CFrame.new(0.7, 3.8, 22) * CFrame.Angles(spin * 1.6, 0, 0)
		anchor.Position = pos + Vector3.new(0, -9, 0)
		local active = t >= arriveT and t < leaveT
		ring.Transparency = active and (0.55 + math.sin(t * 8) * 0.15) or 0.85
		-- souffle du rotor : repousse tout le monde vers l'extérieur
		if active and t - lastWind >= cfg.WindEvery then
			lastWind = t
			local center = Vector3.new(pos.X, y, pos.Z)
			local gust = part(ctx.folder, Vector3.new(0.3, 6, 6), CFrame.new(center + Vector3.new(0, 1.8, 0)) * CYL, Color3.fromRGB(230, 240, 255), {
				shape = CYLINDER, transparency = 0.4, name = "Gust",
			})
			TweenService:Create(gust, TweenInfo.new(0.6), { Size = Vector3.new(0.3, cfg.WindRadius * 2, cfg.WindRadius * 2), Transparency = 1 }):Play()
			game:GetService("Debris"):AddItem(gust, 0.7)
			for _, c in ipairs(allCharacters()) do
				local r = c.HumanoidRootPart
				local d = (r.Position - center) * Vector3.new(1, 0, 1)
				if d.Magnitude < cfg.WindRadius and r.Position.Y < y + cfg.HoverHeight then
					local k = 1 - (d.Magnitude / cfg.WindRadius) * 0.5
					eventHit(c, cfg.WindDamage, d.Magnitude > 0.5 and d or Vector3.new(1, 0, 0), cfg.WindPush * k, cfg.WindUp, 0.2, "Light", 0.3,
						{ "WHOOSH!", "ROTOR WASH!" }, "Helicopter")
				end
			end
		end
		if active and t >= nextCrate and cratesLeft > 0 and t < leaveT - 1.5 then
			cratesLeft -= 1
			nextCrate = t + cfg.CrateEvery
			task.spawn(dropCrate, pos + Vector3.new(0, -6, 0))
		end
	end)
	return function()
		if conn then
			conn:Disconnect()
		end
		snd:Stop()
	end
end

-- PAPER STORM (Archives) : tornades de papier qui errent et projettent en l'air
local function buildTornado(parent)
	local m = Instance.new("Model")
	m.Name = "PaperTornado"
	local core = part(m, Vector3.new(1, 1, 1), CFrame.new(), Color3.new(1, 1, 1), { transparency = 1, name = "Core" })
	local rings = {}
	for i, d in ipairs({ 4, 6.5, 9, 12, 15 }) do
		local r = part(m, Vector3.new(3.4, d, d), CFrame.new(), Color3.fromRGB(235, 225, 200), { shape = CYLINDER, transparency = 0.6, name = "Swirl" })
		table.insert(rings, { p = r, y = (i - 1) * 3.2 + 1.7, d = d })
	end
	local sheets = {}
	for i = 1, 12 do
		local s = part(m, Vector3.new(2, 0.12, 2.6), CFrame.new(), (i % 3 == 0) and Color3.fromRGB(250, 240, 200) or Color3.new(1, 1, 1), { name = "Sheet" })
		table.insert(sheets, { p = s, a = rng:NextNumber(0, math.pi * 2), y = rng:NextNumber(1, 16), r = rng:NextNumber(2.5, 7.5), sp = rng:NextNumber(3, 6) })
	end
	m.PrimaryPart = core
	m.Parent = parent
	return m, core, rings, sheets
end

function Impl.PaperStorm(cfg, ctx)
	local spawns = points("TornadoSpawn")
	local storms = {}
	globalSound(GameSounds.Whoosh, 0.7, false, ctx.folder)
	for i = 1, cfg.Tornadoes do
		local sp = spawns[(i - 1) % math.max(#spawns, 1) + 1]
		local pos = sp and Vector3.new(sp.Position.X, floorY(), sp.Position.Z) or randomFloorPoint(20)
		local m, core, rings, sheets = buildTornado(ctx.folder)
		local s = Instance.new("Sound")
		s.SoundId = SND.Wind
		s.Looped = true
		s.Volume = 0.45
		s.RollOffMaxDistance = 120
		s.Parent = core
		s:Play()
		local born = os.clock() + (i - 1) * 0.6
		local warnRing = part(ctx.folder, Vector3.new(0.15, 2, 2), CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CYL, Color3.fromRGB(255, 200, 80), {
			shape = CYLINDER, transparency = 0.4, name = "StormWarning",
		})
		TweenService:Create(warnRing, TweenInfo.new(cfg.Telegraph + (i - 1) * 0.6), { Size = Vector3.new(0.15, cfg.Radius * 2, cfg.Radius * 2) }):Play()
		game:GetService("Debris"):AddItem(warnRing, cfg.Telegraph + (i - 1) * 0.6 + 0.1)
		table.insert(storms, { m = m, core = core, rings = rings, sheets = sheets, pos = pos, target = pos, born = born, retarget = 0, hit = {}, grown = false })
	end
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not ctx.running then
			conn:Disconnect()
			return
		end
		local now = os.clock()
		local y = floorY()
		for _, st in ipairs(storms) do
			if st.m.Parent then
				local age = now - st.born
				local grow = math.clamp(age / cfg.Telegraph, 0.05, 1)
				local live = age > cfg.Telegraph
				if live and (now > st.retarget or (st.target - st.pos).Magnitude < 3) then
					st.retarget = now + rng:NextNumber(2.5, 4)
					local c = randomChar()
					if c and rng:NextNumber() < 0.6 then
						local rp = c.HumanoidRootPart.Position
						st.target = Vector3.new(rp.X, y, rp.Z)
					else
						st.target = randomFloorPoint(14)
					end
				end
				if live then
					local to = (st.target - st.pos) * Vector3.new(1, 0, 1)
					if to.Magnitude > 0.5 then
						st.pos += to.Unit * math.min(to.Magnitude, cfg.Speed * dt)
					end
				end
				st.pos = Vector3.new(math.clamp(st.pos.X, -100, 100), y, math.clamp(st.pos.Z, -100, 100))
				local base = CFrame.new(st.pos)
				st.core.CFrame = base
				for k, r in ipairs(st.rings) do
					if not st.grown then
						r.p.Size = Vector3.new(3.4, r.d * grow, r.d * grow)
					end
					local wob = 0.18 * k
					r.p.CFrame = base * CFrame.new(math.sin(now * 3 + k) * wob, r.y * grow, math.cos(now * 3 + k) * wob) * CFrame.Angles(0, now * 6 + k, 0) * CYL
				end
				if grow >= 1 then
					st.grown = true
				end
				for _, s in ipairs(st.sheets) do
					s.a += dt * s.sp
					local rr = s.r * (0.4 + s.y / 18) * grow
					s.p.CFrame = base * CFrame.new(math.cos(s.a) * rr, s.y * grow, math.sin(s.a) * rr) * CFrame.Angles(s.a, s.a * 2, 0)
				end
				if live then
					for _, c in ipairs(allCharacters()) do
						local r = c.HumanoidRootPart
						local d = r.Position - st.pos
						local flat = Vector3.new(d.X, 0, d.Z)
						if flat.Magnitude < cfg.Radius and d.Y < 18 and d.Y > -4 and (not st.hit[c] or now - st.hit[c] > 1.6) then
							st.hit[c] = now
							local out = flat.Magnitude > 0.3 and flat.Unit or Vector3.new(1, 0, 0)
							local tan = Vector3.new(-out.Z, 0, out.X)
							eventHitEx(c, {
								damage = cfg.Damage, dir = out, knockback = 30, up = cfg.Launch, stun = 0.8, category = "Heavy", power = 0.7,
								launch = tan * cfg.Spin + out * 18 + Vector3.new(0, cfg.Launch, 0),
								words = { "PAPERWORK!", "FILED!", "WHOOSH!" }, weapon = "PaperStorm",
							})
						end
					end
				end
			end
		end
	end)
	return function()
		if conn then
			conn:Disconnect()
		end
	end
end

-- PING PONG BARRAGE (GameRoom) : les lanceurs tirent des balles rebondissantes (coups légers)
function Impl.PingPongBarrage(cfg, ctx)
	local cannons = points("BallCannon")
	if #cannons == 0 then
		return function() end
	end
	local f = World.current()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { f }
	local balls = {}
	local COLORS = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 150, 40) }
	local function fire(cn, dir, big)
		local r = big and 1.4 or 1
		local pos = cn.CFrame.Position
		local b = part(ctx.folder, Vector3.new(r * 2, r * 2, r * 2), pos, COLORS[rng:NextInteger(1, 2)], {
			shape = SPHERE, name = "PingPongBall", material = big and Enum.Material.Neon or nil,
		})
		table.insert(balls, { p = b, v = dir * cfg.Speed + Vector3.new(0, rng:NextNumber(6, 14), 0), born = os.clock(), r = r, hit = {}, snd = 0 })
		soundAt(SND.PingPong, pos, 0.6)
	end
	local function aimFrom(cn)
		local cf = cn.CFrame
		local look = (cf.LookVector * Vector3.new(1, 0, 1)).Unit
		local best, bd = nil, 140
		for _, c in ipairs(allCharacters()) do
			local to = (c.HumanoidRootPart.Position - cf.Position) * Vector3.new(1, 0, 1)
			if to.Magnitude > 0.1 and to.Magnitude < bd and to.Unit:Dot(look) > 0.35 then
				best, bd = to.Unit, to.Magnitude
			end
		end
		return best or (CFrame.Angles(0, math.rad(rng:NextNumber(-35, 35)), 0) * look)
	end
	local function flash(cn, t, text)
		local m = part(ctx.folder, Vector3.new(2.6, 2.6, 2.6), cn.CFrame.Position, Color3.fromRGB(255, 120, 40), {
			shape = SPHERE, material = Enum.Material.Neon, transparency = 0.3, name = "MuzzleFlash",
		})
		if text then
			billboardText(m, text, Color3.fromRGB(255, 160, 60), 180, Vector3.new(0, 3, 0))
		end
		TweenService:Create(m, TweenInfo.new(t), { Size = Vector3.new(0.6, 0.6, 0.6), Transparency = 0.8 }):Play()
		game:GetService("Debris"):AddItem(m, t)
	end
	task.spawn(function()
		local lastVolley = os.clock()
		while ctx.running do
			local cn = cannons[rng:NextInteger(1, #cannons)]
			if os.clock() - lastVolley > cfg.VolleyEvery then
				lastVolley = os.clock()
				flash(cn, 0.8, "SMASH!")
				task.wait(0.8)
				if not ctx.running then
					break
				end
				local base = aimFrom(cn)
				for i = 1, cfg.Volley do
					fire(cn, CFrame.Angles(0, math.rad((i - (cfg.Volley + 1) / 2) * 12), 0) * base, true)
				end
			else
				flash(cn, 0.35)
				task.wait(0.35)
				if not ctx.running then
					break
				end
				fire(cn, aimFrom(cn), false)
			end
			task.wait(cfg.Interval)
		end
	end)
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not ctx.running then
			conn:Disconnect()
			return
		end
		dt = math.min(dt, 1 / 20)
		local now = os.clock()
		local fy = floorY()
		for i = #balls, 1, -1 do
			local b = balls[i]
			if not b.p.Parent or now - b.born > cfg.Life then
				if b.p.Parent then
					b.p:Destroy()
				end
				table.remove(balls, i)
			else
				b.v += Vector3.new(0, -cfg.Gravity * dt, 0)
				local pos = b.p.Position
				local step = b.v * dt
				local hit = f and f.Parent and workspace:Spherecast(pos, b.r, step, params)
				if hit then
					local n = hit.Normal
					b.v = (b.v - 2 * b.v:Dot(n) * n) * 0.9
					if n.Y > 0.6 then
						b.v = Vector3.new(b.v.X, math.max(b.v.Y, cfg.Bounce), b.v.Z)
					end
					pos += n * 0.05
					if now - b.snd > 0.25 then
						b.snd = now
						soundAt(SND.PingPong, hit.Position, 0.35)
					end
				else
					pos += step
				end
				if pos.Y < fy + b.r then
					pos = Vector3.new(pos.X, fy + b.r, pos.Z)
					b.v = Vector3.new(b.v.X, cfg.Bounce, b.v.Z)
				end
				b.p.CFrame = CFrame.new(pos)
				for _, v in ipairs(Hitbox.box(CFrame.new(pos), Vector3.one * (b.r * 2 + 2), nil, 3)) do
					if not b.hit[v] then
						b.hit[v] = true
						local hv = Vector3.new(b.v.X, 0, b.v.Z)
						eventHit(v, cfg.Damage, hv.Magnitude > 0.1 and hv or Vector3.new(1, 0, 0), cfg.Knockback, cfg.Up, 0.25, "Light", 0.3,
							{ "PING!", "PONG!", "SMASH!" }, "PingPong")
						b.v = Vector3.new(-b.v.X * 0.5, math.abs(b.v.Y) + 10, -b.v.Z * 0.5)
					end
				end
			end
		end
	end)
	return function()
		if conn then
			conn:Disconnect()
		end
	end
end

-- NAP TIME (Daycare) : lumière tamisée, berceuse, nuages qui ralentissent, nounours géants qui roulent
local function buildBigTeddy(parent, color)
	local m = Instance.new("Model")
	m.Name = "GiantTeddy"
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.25)
	local body = part(m, Vector3.new(10, 10, 10), CFrame.new(0, 0, 0), color, { shape = SPHERE, name = "Body" })
	part(m, Vector3.new(6, 6, 6), CFrame.new(0, 3, -2.6), color, { shape = SPHERE, name = "Head" })
	part(m, Vector3.new(2.4, 2.4, 2.4), CFrame.new(-2.4, 5.6, -2.2), dark, { shape = SPHERE })
	part(m, Vector3.new(2.4, 2.4, 2.4), CFrame.new(2.4, 5.6, -2.2), dark, { shape = SPHERE })
	part(m, Vector3.new(2.4, 2.4, 2.4), CFrame.new(0, 2.4, -5.3), Color3.fromRGB(245, 225, 195), { shape = SPHERE })
	part(m, Vector3.new(0.9, 0.9, 0.9), CFrame.new(-1.1, 4, -5.2), Color3.fromRGB(25, 25, 30), { shape = SPHERE })
	part(m, Vector3.new(0.9, 0.9, 0.9), CFrame.new(1.1, 4, -5.2), Color3.fromRGB(25, 25, 30), { shape = SPHERE })
	part(m, Vector3.new(2.4, 1.2, 1), CFrame.new(0, 0, -5), Color3.fromRGB(230, 50, 80), { name = "Bow" })
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

function Impl.NapTime(cfg, ctx)
	local lull = globalSound(SND.Lullaby, 0.55, true, ctx.folder)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "NapTime"
	cc.Parent = Lighting
	TweenService:Create(cc, TweenInfo.new(2), { Brightness = -0.2, Saturation = -0.25, Contrast = 0.05, TintColor = Color3.fromRGB(185, 175, 255) }):Play()
	-- nuages de sieste : disques lents (SlowZone) qui dérivent
	local clouds = {}
	for _ = 1, cfg.Clouds do
		local pos = randomFloorPoint(20)
		local disk = part(ctx.folder, Vector3.new(0.2, 1, 1), CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CYL, Color3.fromRGB(190, 170, 255), {
			shape = CYLINDER, transparency = 0.45, name = "SleepyZone",
		})
		disk:SetAttribute("Mult", cfg.SlowMult)
		disk:SetAttribute("Radius", cfg.CloudRadius)
		CollectionService:AddTag(disk, "SlowZone")
		TweenService:Create(disk, TweenInfo.new(1.2, Enum.EasingStyle.Back), { Size = Vector3.new(0.2, cfg.CloudRadius * 2, cfg.CloudRadius * 2) }):Play()
		local puffs = {}
		for k = 1, 3 do
			local off = Vector3.new((k - 2) * 3.5, 9 + (k % 2), 0)
			table.insert(puffs, { p = part(ctx.folder, Vector3.new(4 + k, 4 + k, 4 + k), pos + off, Color3.fromRGB(235, 230, 255), { shape = SPHERE, transparency = 0.25, name = "Cloud" }), off = off })
		end
		local bb = billboardText(puffs[2].p, "Zzz...", Color3.fromRGB(200, 190, 255), 100, Vector3.new(0, 4, 0))
		bb.AlwaysOnTop = false
		bb.Size = UDim2.fromOffset(100, 40)
		table.insert(clouds, { disk = disk, puffs = puffs, pos = pos, target = randomFloorPoint(20) })
	end
	local TEDDY = { Color3.fromRGB(190, 130, 80), Color3.fromRGB(255, 180, 210), Color3.fromRGB(170, 210, 255), Color3.fromRGB(230, 200, 140) }
	local spawns = points("TeddySpawn")
	local function teddyRun()
		local sp = spawns[rng:NextInteger(1, math.max(#spawns, 1))]
		local y = floorY()
		local a = sp and Vector3.new(sp.Position.X, y, sp.Position.Z) or randomFloorPoint(10)
		local c = randomChar()
		local aim = c and Vector3.new(c.HumanoidRootPart.Position.X, y, c.HumanoidRootPart.Position.Z) or Vector3.new(0, y, 0)
		local dir = (aim - a) * Vector3.new(1, 0, 1)
		dir = dir.Magnitude > 1 and dir.Unit or Vector3.new(1, 0, 0)
		-- distance jusqu'au bord de l'étage
		local L = 210
		for _, axis in ipairs({ "X", "Z" }) do
			local dv = dir[axis]
			if math.abs(dv) > 0.01 then
				local lim = ((dv > 0) and 102 or -102)
				L = math.min(L, (lim - a[axis]) / dv)
			end
		end
		L = math.max(L, 20)
		-- avertissement : pointillés + nounours qui grossit
		local dots = {}
		for d = 6, L, 8 do
			table.insert(dots, part(ctx.folder, Vector3.new(1.4, 1.4, 1.4), a + dir * d + Vector3.new(0, 0.6, 0), Color3.fromRGB(200, 170, 255), {
				shape = SPHERE, material = Enum.Material.Neon, transparency = 0.2, name = "TeddyPath",
			}))
		end
		local m = buildBigTeddy(ctx.folder, TEDDY[rng:NextInteger(1, #TEDDY)])
		local look = CFrame.lookAt(Vector3.zero, dir)
		m:PivotTo(CFrame.new(a + Vector3.new(0, 5.8, 0)) * look)
		local tag = billboardText(m.PrimaryPart, "HUG TIME!", Color3.fromRGB(255, 170, 220), 220, Vector3.new(0, 9, 0))
		local t0 = os.clock()
		while ctx.running and os.clock() - t0 < cfg.Telegraph do
			local on = math.floor((os.clock() - t0) * 8) % 2 == 0
			for _, d in ipairs(dots) do
				d.Transparency = on and 0.1 or 0.7
			end
			task.wait(0.05)
		end
		for _, d in ipairs(dots) do
			d:Destroy()
		end
		if not ctx.running or not m.Parent then
			return
		end
		tag:Destroy()
		soundAt(GameSounds.Boing, a, 0.7)
		local axis = Vector3.new(0, 1, 0):Cross(dir)
		local hitAt = {}
		t0 = os.clock()
		while ctx.running and m.Parent do
			local tr = (os.clock() - t0) * cfg.TeddySpeed
			if tr > L then
				break
			end
			local yy = floorY()
			local pos = Vector3.new(a.X, yy, a.Z) + dir * tr
			m:PivotTo(CFrame.new(pos + Vector3.new(0, 5.8, 0)) * CFrame.fromAxisAngle(axis, tr / 5.5) * look)
			for _, ch in ipairs(allCharacters()) do
				local r = ch.HumanoidRootPart
				local d = r.Position - pos
				local flat = Vector3.new(d.X, 0, d.Z)
				if flat.Magnitude < 7 and d.Y < 11 and (not hitAt[ch] or os.clock() - hitAt[ch] > 1) then
					hitAt[ch] = os.clock()
					local side = Vector3.new(-dir.Z, 0, dir.X)
					local s = flat:Dot(side) >= 0 and 0.5 or -0.5
					eventHit(ch, cfg.TeddyDamage, dir + side * s, cfg.Knockback, cfg.Up, 0.7, "Heavy", 0.8, { "BEAR HUG!", "NIGHT NIGHT!", "SNUGGLE!" }, "Teddy")
				end
			end
			task.wait()
		end
		if m.Parent then
			FloorFX:FireAllClients({ k = "Puff", p = m:GetPivot().Position - Vector3.new(0, 5, 0), big = true })
			m:Destroy()
		end
	end
	task.spawn(function()
		task.wait(1.5)
		while ctx.running do
			task.spawn(teddyRun)
			task.wait(cfg.TeddyEvery)
		end
	end)
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not ctx.running then
			conn:Disconnect()
			return
		end
		local y = floorY()
		for _, cl in ipairs(clouds) do
			if cl.disk.Parent then
				local to = (cl.target - cl.pos) * Vector3.new(1, 0, 1)
				if to.Magnitude < 3 then
					cl.target = randomFloorPoint(20)
				else
					cl.pos += to.Unit * math.min(to.Magnitude, cfg.CloudSpeed * dt)
				end
				cl.pos = Vector3.new(cl.pos.X, y, cl.pos.Z)
				cl.disk.CFrame = CFrame.new(cl.pos + Vector3.new(0, 0.15, 0)) * CYL
				for _, pf in ipairs(cl.puffs) do
					pf.p.CFrame = CFrame.new(cl.pos + pf.off + Vector3.new(0, math.sin(os.clock() * 2 + pf.off.X) * 0.4, 0))
				end
			end
		end
	end)
	return function()
		if conn then
			conn:Disconnect()
		end
		if lull then
			lull:Stop()
		end
		TweenService:Create(cc, TweenInfo.new(1), { Brightness = 0, Saturation = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) }):Play()
		game:GetService("Debris"):AddItem(cc, 1.1)
	end
end

-- KEYNOTE (Auditorium) : des projecteurs traquent les joueurs (trop longtemps dedans = dégâts), l'écran fait le compte à rebours
function Impl.Keynote(cfg, ctx)
	local f = World.current()
	local screen = f and f:FindFirstChild("BigScreen", true)
	local gui, label, saved
	if screen and screen:IsA("BasePart") then
		saved = { c = screen.Color, m = screen.Material }
		screen.Color = Color3.fromRGB(20, 30, 90)
		screen.Material = Enum.Material.Neon
		gui = Instance.new("SurfaceGui")
		gui.Name = "KeynoteGui"
		gui.Face = Enum.NormalId[screen:GetAttribute("Face") or "Back"]
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.LightInfluence = 0
		gui.Parent = screen
		label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Bold)
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Text = "KEYNOTE"
		label.Parent = gui
		local st = Instance.new("UIStroke")
		st.Thickness = 4
		st.Parent = label
	end
	globalSound(SND.Applause, 0.6, false, ctx.folder)
	local starts = points("SpotlightStart")
	local spots = {}
	for i = 1, cfg.Spots do
		local sp = starts[(i - 1) % math.max(#starts, 1) + 1]
		local p0 = sp and sp.Position or randomFloorPoint(20)
		local disk = part(ctx.folder, Vector3.new(0.2, cfg.Radius * 2, cfg.Radius * 2), CFrame.new(p0) * CYL, Color3.fromRGB(255, 250, 210), {
			shape = CYLINDER, material = Enum.Material.Neon, transparency = 0.35, name = "Spotlight",
		})
		local beam = part(ctx.folder, Vector3.new(26, cfg.Radius * 1.7, cfg.Radius * 1.7), CFrame.new(p0 + Vector3.new(0, 13, 0)) * CYL, Color3.fromRGB(255, 250, 220), {
			shape = CYLINDER, transparency = 0.86, name = "SpotBeam",
		})
		local lamp = part(ctx.folder, Vector3.new(1, 1, 1), p0 + Vector3.new(0, 24, 0), Color3.new(1, 1, 1), { transparency = 1, name = "SpotLamp" })
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Bottom
		light.Angle = 30
		light.Range = 40
		light.Brightness = 4
		light.Color = Color3.fromRGB(255, 245, 210)
		light.Parent = lamp
		table.insert(spots, { disk = disk, beam = beam, lamp = lamp, light = light, pos = Vector3.new(p0.X, 0, p0.Z), target = nil })
	end
	local heat = {}
	local t0 = os.clock()
	local lastAssign = 0
	local lastDing = -1
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not ctx.running then
			conn:Disconnect()
			return
		end
		local now = os.clock()
		local chars = allCharacters()
		-- répartition des cibles toutes les 2 s
		if now - lastAssign > 2 then
			lastAssign = now
			for i = #chars, 2, -1 do
				local j = rng:NextInteger(1, i)
				chars[i], chars[j] = chars[j], chars[i]
			end
			for i, s in ipairs(spots) do
				s.target = (#chars > 0) and chars[(i - 1) % #chars + 1] or nil
			end
		end
		local inside = {}
		for _, s in ipairs(spots) do
			local tgt = s.target
			if tgt and tgt.Parent and tgt:FindFirstChild("HumanoidRootPart") then
				local tp = tgt.HumanoidRootPart.Position
				local to = Vector3.new(tp.X - s.pos.X, 0, tp.Z - s.pos.Z)
				if to.Magnitude > 0.3 then
					s.pos += to.Unit * math.min(to.Magnitude, cfg.Speed * dt)
				end
			end
			local g = groundAt(s.pos.X, s.pos.Z)
			s.disk.CFrame = CFrame.new(g + Vector3.new(0, 0.12, 0)) * CYL
			s.beam.CFrame = CFrame.new(g + Vector3.new(0, 13.2, 0)) * CYL
			s.lamp.Position = g + Vector3.new(0, 24, 0)
			local hot = 0
			for _, c in ipairs(chars) do
				local r = c.HumanoidRootPart
				local d = Vector3.new(r.Position.X - g.X, 0, r.Position.Z - g.Z)
				if d.Magnitude < cfg.Radius and math.abs(r.Position.Y - g.Y) < 8 then
					inside[c] = s
					hot = math.max(hot, (heat[c] or 0) / cfg.Heat)
				end
			end
			local col = Color3.fromRGB(255, 250, 210):Lerp(Color3.fromRGB(255, 140, 40), math.clamp(hot * 1.6, 0, 1)):Lerp(Color3.fromRGB(255, 40, 30), math.clamp(hot * 2 - 1, 0, 1))
			s.disk.Color = col
			s.beam.Color = col
			s.light.Color = col
		end
		for _, c in ipairs(chars) do
			local s = inside[c]
			if s then
				heat[c] = (heat[c] or 0) + dt
				if heat[c] >= cfg.Heat then
					heat[c] = 0
					local r = c.HumanoidRootPart
					local g = s.disk.Position
					local d = Vector3.new(r.Position.X - g.X, 0, r.Position.Z - g.Z)
					FloorFX:FireAllClients({ k = "Puff", p = r.Position - Vector3.new(0, 2.5, 0) })
					eventHit(c, cfg.Damage, d.Magnitude > 0.3 and d or Vector3.new(0, 0, 1), cfg.Knockback, cfg.Up, 0.5, "Heavy", 0.6,
						{ "STAGE FRIGHT!", "TOO HOT!", "SPOTLIGHT HOG!" }, "Spotlight")
				end
			else
				heat[c] = math.max(0, (heat[c] or 0) - dt * 1.5)
			end
		end
		-- compte à rebours sur l'écran géant
		local left = math.max(0, math.ceil(cfg.Duration - (now - t0)))
		if label then
			label.Text = left > 1 and string.format("KEYNOTE\n0:%02d", left) or "THANK YOU!"
			label.TextColor3 = left <= 5 and Color3.fromRGB(255, 90, 80) or Color3.new(1, 1, 1)
		end
		if left <= 5 and left ~= lastDing and left > 0 then
			lastDing = left
			globalSound(GameSounds.Ding, 0.5, false, ctx.folder)
		end
	end)
	return function()
		if conn then
			conn:Disconnect()
		end
		if gui then
			gui:Destroy()
		end
		if screen and saved and screen.Parent then
			screen.Color = saved.c
			screen.Material = saved.m
		end
	end
end

-- FORKLIFT FRENZY (Warehouse) : des chariots élévateurs font des allers-retours sur les couloirs jaunes
local function buildForklift(parent)
	local m = Instance.new("Model")
	m.Name = "Forklift"
	local BODY, DARK, STEEL = Color3.fromRGB(250, 190, 30), Color3.fromRGB(40, 40, 45), Color3.fromRGB(70, 70, 78)
	local chassis = part(m, Vector3.new(5, 3, 7), CFrame.new(0, 2.2, 0.5), BODY, { name = "Chassis" })
	part(m, Vector3.new(4.6, 2.4, 2.2), CFrame.new(0, 2.8, 3.6), Color3.fromRGB(60, 60, 70))
	part(m, Vector3.new(2.6, 0.7, 2.4), CFrame.new(0, 4.05, 1.2), DARK)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			part(m, Vector3.new(0.35, 4.6, 0.35), CFrame.new(sx * 2.2, 6, 1 + sz * 1.9), DARK)
		end
		part(m, Vector3.new(0.5, 9, 0.5), CFrame.new(sx * 1.4, 4.8, -3.2), STEEL)
		part(m, Vector3.new(0.5, 0.3, 4), CFrame.new(sx * 1, 0.5, -5.1), STEEL)
		part(m, Vector3.new(0.9, 2.2, 2.2), CFrame.new(sx * 2.6, 1.1, -1.8) * CYL, Color3.fromRGB(25, 25, 30), { shape = CYLINDER })
		part(m, Vector3.new(0.9, 1.8, 1.8), CFrame.new(sx * 2.5, 0.9, 3.4) * CYL, Color3.fromRGB(25, 25, 30), { shape = CYLINDER })
	end
	part(m, Vector3.new(4.8, 0.3, 4.4), CFrame.new(0, 8.4, 1), BODY)
	part(m, Vector3.new(3.4, 2.2, 0.4), CFrame.new(0, 1.6, -3.5), STEEL)
	part(m, Vector3.new(3.6, 2.4, 3.6), CFrame.new(0, 1.9, -5.1), Color3.fromRGB(196, 150, 95), { name = "Load" })
	local beacon = part(m, Vector3.new(0.9, 0.7, 0.9), CFrame.new(0, 8.9, 1), Color3.fromRGB(255, 150, 30), { material = Enum.Material.Neon, name = "Beacon" })
	m.WorldPivot = CFrame.new()
	m.Parent = parent
	return m, beacon, chassis
end

function Impl.ForkliftFrenzy(cfg, ctx)
	local lanes = lanePairs("ForkLane")
	if #lanes == 0 then
		return function() end
	end
	local function drive(lane, idx)
		task.wait((idx - 1) * 1.3)
		local fwd = true
		local fl, beacon, chassis
		while ctx.running do
			local y = floorY()
			local a = Vector3.new(lane.a.X, y, lane.a.Z)
			local b = Vector3.new(lane.b.X, y, lane.b.Z)
			local from, to = (fwd and a or b), (fwd and b or a)
			local travel = (to - from).Unit
			local face = fwd and travel or -travel -- fourches devant à l'aller, marche arrière au retour
			if not fl then
				fl, beacon, chassis = buildForklift(ctx.folder)
				fl:PivotTo(CFrame.lookAt(from, from + face))
				FloorFX:FireAllClients({ k = "Puff", p = from, big = true })
			end
			local beep = Instance.new("Sound")
			beep.SoundId = SND.ForkliftBeep
			beep.Looped = true
			beep.Volume = 0.6
			beep.RollOffMaxDistance = 160
			beep.Parent = chassis
			beep:Play()
			laneWarning(ctx, from, to, 12, Color3.fromRGB(255, 170, 30), cfg.Telegraph, fwd and "FORKLIFT!" or "BEEP BEEP!")
			if not ctx.running or not fl.Parent then
				break
			end
			local dist = (to - from).Magnitude
			local hitAt = {}
			local t0 = os.clock()
			while ctx.running and fl.Parent do
				local tr = math.min((os.clock() - t0) * cfg.Speed, dist)
				local pos = Vector3.new(from.X, floorY(), from.Z) + travel * tr
				fl:PivotTo(CFrame.lookAt(pos, pos + face))
				beacon.Transparency = (math.floor(os.clock() * 6) % 2 == 0) and 0 or 0.7
				local boxCf = CFrame.lookAt(pos + Vector3.new(0, 3.5, 0), pos + Vector3.new(0, 3.5, 0) + travel)
				for _, v in ipairs(Hitbox.box(boxCf, Vector3.new(7, 7, 14), nil, 6)) do
					if not hitAt[v] or os.clock() - hitAt[v] > 1 then
						hitAt[v] = os.clock()
						local vr = v:FindFirstChild("HumanoidRootPart")
						local side = vr and (vr.Position - pos) * Vector3.new(1, 0, 1) or travel
						eventHit(v, cfg.Damage, travel * 2 + (side.Magnitude > 0.1 and side.Unit or travel) * 0.6, cfg.Knockback, cfg.Up, 0.9, "Heavy", 0.9,
							{ "BEEP BEEP!", "FORKED!", "WATCH IT!", "SHIPPED!" }, "Forklift")
					end
				end
				if tr >= dist then
					break
				end
				task.wait()
			end
			beep:Destroy()
			fwd = not fwd
			task.wait(cfg.Pause)
		end
	end
	for i, lane in ipairs(lanes) do
		task.spawn(drive, lane, i)
	end
	return function() end
end

-- STEAM BURST (Spa) : les grilles rougeoient puis crachent un jet de vapeur qui envoie en l'air
function Impl.SteamBurst(cfg, ctx)
	local vents = points("SteamVent")
	if #vents == 0 then
		return function() end
	end
	local function steamEmitter(parent, rate, speed)
		local pe = Instance.new("ParticleEmitter")
		pe.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		pe.Size = NumberSequence.new(1.5, 5)
		pe.Speed = NumberRange.new(speed * 0.7, speed)
		pe.Lifetime = NumberRange.new(0.6, 1.1)
		pe.SpreadAngle = Vector2.new(12, 12)
		pe.EmissionDirection = Enum.NormalId.Right
		pe.Rate = rate
		pe.Parent = parent
		return pe
	end
	local function burst(v)
		local y = floorY()
		local pos = Vector3.new(v.Position.X, y, v.Position.Z)
		local ring = part(ctx.folder, Vector3.new(0.15, cfg.Radius * 2, cfg.Radius * 2), CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CYL, Color3.fromRGB(255, 140, 40), {
			shape = CYLINDER, material = Enum.Material.Neon, transparency = 0.5, name = "VentWarning",
		})
		steamEmitter(ring, 12, 6)
		soundAt(SND.Steam, pos, 0.3)
		local t0 = os.clock()
		while ctx.running and os.clock() - t0 < cfg.Telegraph do
			ring.Transparency = (math.floor((os.clock() - t0) * 10) % 2 == 0) and 0.2 or 0.65
			task.wait(0.05)
		end
		ring:Destroy()
		if not ctx.running then
			return
		end
		local col = part(ctx.folder, Vector3.new(4, cfg.Radius * 1.6, cfg.Radius * 1.6), CFrame.new(pos + Vector3.new(0, 2, 0)) * CYL, Color3.fromRGB(215, 240, 255), {
			shape = CYLINDER, transparency = 0.1, name = "SteamColumn",
		})
		TweenService:Create(col, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(30, cfg.Radius * 2.4, cfg.Radius * 2.4), CFrame = CFrame.new(pos + Vector3.new(0, 15, 0)) * CYL, Transparency = 1,
		}):Play()
		local pe = steamEmitter(col, 0, 45)
		pe:Emit(35)
		game:GetService("Debris"):AddItem(col, 1.4)
		soundAt(SND.Steam, pos, 0.9)
		FloorFX:FireAllClients({ k = "Puff", p = pos, big = true })
		for _, c in ipairs(allCharacters()) do
			local r = c.HumanoidRootPart
			local d = r.Position - pos
			local h = Vector3.new(d.X, 0, d.Z)
			if h.Magnitude < cfg.Radius and d.Y < 12 and d.Y > -3 then
				local out = h.Magnitude > 0.3 and h.Unit or Vector3.new(1, 0, 0)
				eventHitEx(c, {
					damage = cfg.Damage, dir = out, knockback = 10, up = cfg.Launch, stun = 0.6, category = "Heavy", power = 0.6,
					launch = out * 12 + Vector3.new(0, cfg.Launch, 0), words = { "HOT!", "STEAMED!", "PSSHHH!" }, weapon = "Steam",
				})
			end
		end
	end
	task.spawn(function()
		while ctx.running do
			local chosen = {}
			local chars = allCharacters()
			for _ = 1, cfg.PerWave do
				local v
				if #chars > 0 and rng:NextNumber() < cfg.TargetChance then
					local rp = chars[rng:NextInteger(1, #chars)].HumanoidRootPart.Position
					local bd = math.huge
					for _, vv in ipairs(vents) do
						local d = ((vv.Position - rp) * Vector3.new(1, 0, 1)).Magnitude
						if d < bd and not chosen[vv] then
							bd, v = d, vv
						end
					end
				end
				v = v or vents[rng:NextInteger(1, #vents)]
				if not chosen[v] then
					chosen[v] = true
					task.spawn(burst, v)
				end
			end
			task.wait(cfg.Interval)
		end
	end)
	return function() end
end

------------------------------------------------------------------------
-- Gestion
------------------------------------------------------------------------
function EventService.isActive(name: string): boolean
	return active[name] ~= nil
end

function EventService.stop(name: string)
	local e = active[name]
	if not e then
		return
	end
	active[name] = nil
	e.ctx.running = false
	local ok, err = pcall(e.cleanup)
	if not ok then
		warn("[EventService] nettoyage", name, err)
	end
	task.delay(0.1, function()
		if e.ctx.folder then
			e.ctx.folder:Destroy()
		end
	end)
	Signals.EventEnded:Fire(name)
end

function EventService.start(name: string): boolean
	local cfg = EventsConfig[name]
	local impl = Impl[name]
	if not cfg or not impl or active[name] then
		return false
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = eventsFolder
	local ctx = { folder = folder, running = true }
	local token = {}
	Announce.banner(cfg.Title, cfg.Sub, cfg.Color, 3, "Event")
	local ok, cleanup = pcall(impl, cfg, ctx)
	if not ok then
		warn("[EventService] erreur au démarrage de", name, cleanup)
		folder:Destroy()
		return false
	end
	active[name] = { ctx = ctx, cleanup = cleanup or function() end, persistent = cfg.Persistent == true, token = token }
	Signals.EventStarted:Fire(name)
	task.delay(cfg.Duration, function()
		local e = active[name]
		if e and e.token == token then
			EventService.stop(name)
		end
	end)
	return true
end

function EventService.stopAll(includePersistent: boolean?)
	for name, e in pairs(active) do
		if includePersistent or not e.persistent then
			EventService.stop(name)
		end
	end
end

function EventService.list()
	local l = table.clone(EventsConfig.Generic)
	for _, name in pairs(FloorConfig.Special) do
		table.insert(l, name)
	end
	return l
end

local function pickGeneric(exclude)
	local total, pool = 0, {}
	for _, name in ipairs(EventsConfig.Generic) do
		if not exclude[name] and not active[name] then
			local w = EventsConfig[name].Weight or 1
			total += w
			table.insert(pool, { name, w })
		end
	end
	local r = rng:NextNumber() * total
	for _, e in ipairs(pool) do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return pool[1] and pool[1][1]
end

-- appelé par FloorService au début de la phase Events
function EventService.runForFloor(floorName: string, phaseDuration: number)
	local count = rng:NextInteger(FloorConfig.EventsPerFloor[1], FloorConfig.EventsPerFloor[2])
	local chosen, used = {}, {}
	local special = FloorConfig.Special[floorName]
	if special and rng:NextNumber() < FloorConfig.SpecialChance then
		table.insert(chosen, special)
		used[special] = true
	end
	while #chosen < count do
		local g = pickGeneric(used)
		if not g then
			break
		end
		used[g] = true
		table.insert(chosen, g)
	end
	local floorAtStart = World.floorNumber
	for i, name in ipairs(chosen) do
		if i > 1 then
			task.wait(phaseDuration * 0.45)
			if World.floorNumber ~= floorAtStart or ReplicatedStorage:GetAttribute("Phase") ~= "Events" then
				return
			end
		end
		EventService.start(name)
	end
end

function EventService.init()
	eventsFolder = workspace:FindFirstChild("Events") or Instance.new("Folder")
	eventsFolder.Name = "Events"
	eventsFolder.Parent = workspace
	FloorFX = Net.get("FloorFX")
	FX = Net.get("FX")
	if ReplicatedStorage:GetAttribute("XPMultiplier") == nil then
		ReplicatedStorage:SetAttribute("XPMultiplier", 1)
	end
	-- Zones lentes (tag SlowZone : piscine à balles, eau, nuages de sieste...) : attribut Mult (0,5 par défaut),
	-- Radius optionnel (disque horizontal autour du centre), sinon boîte de la part
	task.spawn(function()
		while true do
			task.wait(0.2)
			local zones = CollectionService:GetTagged("SlowZone")
			if #zones > 0 then
				for _, c in ipairs(allCharacters()) do
					local pos = c.HumanoidRootPart.Position
					local best = nil
					for _, z in ipairs(zones) do
						if z:IsA("BasePart") and z:IsDescendantOf(workspace) then
							local r = z:GetAttribute("Radius")
							local inside
							if r then
								local d = pos - z.Position
								inside = Vector3.new(d.X, 0, d.Z).Magnitude <= r and d.Y > -3 and d.Y < 7
							else
								local lp = z.CFrame:PointToObjectSpace(pos)
								local h = z.Size / 2
								inside = math.abs(lp.X) <= h.X and math.abs(lp.Z) <= h.Z and lp.Y > -h.Y - 1 and lp.Y < h.Y + 5
							end
							if inside then
								local m = z:GetAttribute("Mult") or 0.5
								best = best and math.min(best, m) or m
							end
						end
					end
					if best then
						pcall(CharacterState.setSpeedMod, c, "SlowZone", best, 0.35)
					end
				end
			end
		end
	end)
	-- Studio uniquement : ReplicatedStorage attribut "_StartEvent" = nom => lance l'événement (tests MCP).
	-- (un require depuis la barre de commande donne une AUTRE instance du module : passer par l'attribut)
	if RunService:IsStudio() then
		ReplicatedStorage:GetAttributeChangedSignal("_StartEvent"):Connect(function()
			local v = ReplicatedStorage:GetAttribute("_StartEvent")
			if type(v) == "string" and v ~= "" then
				ReplicatedStorage:SetAttribute("_StartEvent", nil)
				if v == "STOP" then
					EventService.stopAll(true)
				else
					EventService.start(v)
				end
			end
		end)
	end
end

return EventService
