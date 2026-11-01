--[[
	AFKService — « AFK BREAK ROOM » : salle de pause sûre, loin de l'arène, qui paie du Cash (Config/AFK).
	- Salle construite au démarrage en Parts simples (workspace.BreakRoom) : canapés (Seats), machine à café,
	  distributeur, plantes, baies vitrées sur une skyline, lumières douces, enseigne, tableau des gains, porte EXIT.
	- Entrée (remote "AFK" "Enter") validée serveur : données chargées, vivant, pas étourdi, pas touché depuis
	  CombatLockout s, pas pendant un effondrement, recharge ToggleCooldown. L'objet tenu est lâché avant.
	- Dedans : attribut perso SafeZone = true (CombatService ignore les coups), paie PayAmount / PayInterval s,
	  bonus BonusAmount toutes les BonusEvery s sans sortir, plafond DailyCap / jour UTC (data.AFK = {Day, Earned}).
	- Sortie : remote "AFK" "Exit", ProximityPrompt sur la porte, ou dalle verte devant la porte.
	- Mort / réapparition / départ => session finie (le nouveau perso n'a pas SafeZone).
	- Si un autre système déplace un joueur AFK hors de la salle (effondrement, réunion surprise...), il est remis dans la salle.
	Attributs Player (HUD client) : AFKActive, AFKSince, AFKNextPay, AFKNextBonus (temps serveur GetServerTimeNow),
	  AFKEarned (session), AFKCapLeft (Cash AFK encore possible aujourd'hui).
	Remote "AFK" : client -> serveur "Enter" | "Exit" | "Toggle".
	API : AFKService.isAFK(player) | enter(player) | exit(player) | forcePay(player) (admin /afkpay)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config.AFK)
local Net = require(Shared.Modules.Net)
local UITheme = require(Shared.Modules.UITheme)
local DataService = require(script.Parent.DataService)
local CharacterState = require(script.Parent.CharacterState)
local World = require(script.Parent.World)
local Signals = require(script.Parent.Signals)
local Announce = require(script.Parent.Announce)

local AFKService = {}
AFKService.Priority = 68

local ORIGIN = Config.Origin
local BASE = CFrame.new(ORIGIN)
local HALF = Vector3.new(44, 0, 34) -- demi-taille de la zone autorisée (X, Z)
local RED = Color3.fromRGB(255, 110, 90)

local room -- Model workspace.BreakRoom
local spawnSpots = {}
local sessions = {} -- [player] = { character, enteredAt, lastPay, bonuses, earned }
local lastToggle = {} -- [player] = os.clock()
local lastHurt = setmetatable({}, { __mode = "k" }) -- [character] = os.clock()
local busy = {} -- [player] = true pendant une téléportation

local function serverNow()
	return workspace:GetServerTimeNow()
end

------------------------------------------------------------------------
-- Construction de la salle
------------------------------------------------------------------------
local function part(parent, size, cf, color, material, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = BASE * cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanTouch = false
	if props then
		for k, v in pairs(props) do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function surfaceText(p, face, lines, opts)
	opts = opts or {}
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = opts.pps or 40
	sg.LightInfluence = 0
	sg.Brightness = opts.brightness or 1.4
	sg.Parent = p
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Size = UDim2.fromScale(1, 1)
	list.Parent = sg
	local layout = Instance.new("UIListLayout")
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.02, 0)
	layout.Parent = list
	for i, line in ipairs(lines) do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.LayoutOrder = i
		l.Size = UDim2.fromScale(0.94, line.h or (1 / #lines) * 0.8)
		l.FontFace = line.body and UITheme.Body or UITheme.Display
		l.Text = line.text
		l.TextScaled = true
		l.TextColor3 = line.color or Color3.new(1, 1, 1)
		l.Parent = list
		local st = Instance.new("UIStroke")
		st.Thickness = line.stroke or 3
		st.Color = UITheme.Colors.Ink
		st.Parent = l
	end
	return sg
end

-- canapé : cf = centre au sol, LookVector = côté assise
local function couch(parent, cf, width, color, seats)
	local dark = UITheme.darken(color, 0.25)
	part(parent, Vector3.new(width, 1.4, 3.4), cf * CFrame.new(0, 0.7, 0), dark, Enum.Material.Fabric)
	part(parent, Vector3.new(width, 3.4, 1), cf * CFrame.new(0, 2.6, 1.3), color, Enum.Material.Fabric)
	for _, sx in ipairs({ -1, 1 }) do
		part(parent, Vector3.new(1, 2.6, 3.4), cf * CFrame.new(sx * (width / 2 - 0.5), 1.9, 0), dark, Enum.Material.Fabric)
	end
	local n = seats or 2
	local w = (width - 2) / n
	for i = 1, n do
		local s = Instance.new("Seat")
		s.Anchored = true
		s.Size = Vector3.new(w - 0.15, 0.9, 2.5)
		s.CFrame = BASE * cf * CFrame.new(-width / 2 + 1 + w * (i - 0.5), 1.85, -0.35)
		s.Color = UITheme.lighten(color, 0.12)
		s.Material = Enum.Material.Fabric
		s.TopSurface = Enum.SurfaceType.Smooth
		s.Parent = parent
		-- coussin de dossier
		part(parent, Vector3.new(w - 0.3, 2, 0.6), cf * CFrame.new(-width / 2 + 1 + w * (i - 0.5), 3.1, 0.6), UITheme.lighten(color, 0.2), Enum.Material.Fabric)
	end
end

local function plant(parent, cf, scale)
	local s = scale or 1
	part(parent, Vector3.new(2.4, 2.4, 2.4) * s, cf * CFrame.new(0, 1.2 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(196, 110, 70), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	part(parent, Vector3.new(2.1, 0.2, 2.1) * s, cf * CFrame.new(0, 2.35 * s, 0), Color3.fromRGB(90, 60, 40), Enum.Material.Ground)
	local greens = { Color3.fromRGB(70, 170, 80), Color3.fromRGB(95, 195, 95), Color3.fromRGB(55, 140, 70) }
	local offs = { Vector3.new(0, 4.2, 0), Vector3.new(0.9, 3.4, 0.4), Vector3.new(-0.8, 3.6, -0.5), Vector3.new(0.2, 5.3, -0.2) }
	for i, o in ipairs(offs) do
		local d = (i == 1 and 2.6 or 1.9) * s
		part(parent, Vector3.new(d, d, d), cf * CFrame.new(o * s), greens[(i % #greens) + 1], Enum.Material.Grass, { Shape = Enum.PartType.Ball, CanCollide = false })
	end
end

local function buildSkyline(parent)
	local rng = Random.new(42)
	-- sol de la ville, loin en dessous (on est en haut d'une tour)
	part(parent, Vector3.new(900, 2, 500), CFrame.new(0, -90, -260), Color3.fromRGB(52, 58, 74), Enum.Material.Concrete, { CanCollide = false })
	local palette = {
		Color3.fromRGB(70, 86, 120), Color3.fromRGB(95, 105, 140), Color3.fromRGB(60, 70, 95),
		Color3.fromRGB(120, 130, 160), Color3.fromRGB(85, 115, 150), Color3.fromRGB(150, 140, 170),
	}
	local x = -230
	local row = 0
	while x < 230 do
		local w = rng:NextNumber(16, 30)
		local h = rng:NextNumber(70, 190)
		local z = -60 - rng:NextNumber(0, 50) - row * 40
		local cx = x + w / 2
		local col = palette[rng:NextInteger(1, #palette)]
		local b = part(parent, Vector3.new(w, h, rng:NextNumber(16, 28)), CFrame.new(cx, -90 + h / 2, z), col, Enum.Material.SmoothPlastic, { CanCollide = false, CastShadow = false })
		-- bandes de fenêtres allumées sur la face avant
		local strips = math.floor(h / 22)
		for i = 1, strips do
			if rng:NextNumber() < 0.75 then
				part(parent, Vector3.new(w - 3, 1.4, 0.3), CFrame.new(cx, -90 + i * 20, z + b.Size.Z / 2 + 0.1), Color3.fromRGB(255, 226, 140), Enum.Material.Neon, { CanCollide = false, CastShadow = false, Transparency = rng:NextNumber(0.1, 0.45) })
			end
		end
		-- antenne sur les plus hautes
		if h > 150 then
			part(parent, Vector3.new(0.6, 14, 0.6), CFrame.new(cx, -90 + h + 7, z), Color3.fromRGB(200, 200, 210), Enum.Material.Metal, { CanCollide = false })
			part(parent, Vector3.new(1.2, 1.2, 1.2), CFrame.new(cx, -90 + h + 14.5, z), Color3.fromRGB(255, 60, 60), Enum.Material.Neon, { CanCollide = false, Shape = Enum.PartType.Ball })
		end
		x += w + rng:NextNumber(2, 10)
		row = (row + 1) % 2
	end
end

local function buildRoom()
	local old = workspace:FindFirstChild("BreakRoom")
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "BreakRoom"
	pcall(function()
		m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	local C = UITheme.rgb
	local WALL = C(246, 232, 205)
	local TRIM = C(150, 105, 70)

	-- sol, tapis, plafond
	part(m, Vector3.new(86, 2, 66), CFrame.new(0, -1, 0), C(178, 128, 86), Enum.Material.WoodPlanks)
	part(m, Vector3.new(34, 0.2, 24), CFrame.new(0, 0.1, 2), C(70, 150, 150), Enum.Material.Fabric)
	part(m, Vector3.new(30, 0.22, 20), CFrame.new(0, 0.12, 2), C(95, 180, 175), Enum.Material.Fabric)
	part(m, Vector3.new(86, 1, 66), CFrame.new(0, 22.5, 0), C(250, 244, 230), Enum.Material.SmoothPlastic)

	-- mur vitré (fond, -Z) : allège, linteau, montants, vitre
	part(m, Vector3.new(86, 3, 1), CFrame.new(0, 1.5, -32.5), WALL)
	part(m, Vector3.new(86, 5, 1), CFrame.new(0, 19.5, -32.5), WALL)
	part(m, Vector3.new(86, 0.5, 1.6), CFrame.new(0, 3.1, -32.2), TRIM, Enum.Material.Wood)
	for i = -4, 4 do
		part(m, Vector3.new(1, 14, 1.2), CFrame.new(i * 10.5, 10, -32.5), C(235, 235, 240), Enum.Material.Metal)
	end
	part(m, Vector3.new(86, 14, 0.4), CFrame.new(0, 10, -32.6), C(190, 225, 255), Enum.Material.Glass, { Transparency = 0.7, CastShadow = false })
	-- murs latéraux
	part(m, Vector3.new(1, 24, 66), CFrame.new(-43, 11, 0), WALL)
	part(m, Vector3.new(1, 24, 66), CFrame.new(43, 11, 0), WALL)
	-- plinthes
	part(m, Vector3.new(0.4, 1, 64), CFrame.new(-42.4, 0.5, 0), TRIM, Enum.Material.Wood)
	part(m, Vector3.new(0.4, 1, 64), CFrame.new(42.4, 0.5, 0), TRIM, Enum.Material.Wood)
	-- mur avant (+Z) avec la porte
	part(m, Vector3.new(39, 24, 1), CFrame.new(-23.5, 11, 32.5), WALL)
	part(m, Vector3.new(39, 24, 1), CFrame.new(23.5, 11, 32.5), WALL)
	part(m, Vector3.new(8, 12, 1), CFrame.new(0, 17, 32.5), WALL)
	local door = part(m, Vector3.new(8, 11, 0.6), CFrame.new(0, 5.5, 32.7), C(120, 82, 55), Enum.Material.Wood, { Name = "ExitDoor" })
	part(m, Vector3.new(0.5, 0.5, 1), CFrame.new(2.8, 5.5, 32.2), C(235, 200, 90), Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	local exitSign = part(m, Vector3.new(6, 1.8, 0.4), CFrame.new(0, 12.6, 31.9), C(40, 200, 90), Enum.Material.Neon)
	surfaceText(exitSign, Enum.NormalId.Front, { { text = "EXIT", h = 0.8 } }, { pps = 60 })
	-- dalle de sortie
	local pad = part(m, Vector3.new(8, 0.3, 5), CFrame.new(0, 0.15, 28.5), C(60, 220, 110), Enum.Material.Neon, { Name = "ExitPad", CanCollide = false, CanTouch = true, Transparency = 0.15 })
	surfaceText(pad, Enum.NormalId.Top, { { text = "BACK TO WORK", h = 0.5 } }, { pps = 40 })

	-- éclairage doux : dalles lumineuses + lampadaires
	for _, x in ipairs({ -22, 0, 22 }) do
		for _, z in ipairs({ -14, 12 }) do
			local panel = part(m, Vector3.new(10, 0.3, 4), CFrame.new(x, 21.9, z), C(255, 244, 220), Enum.Material.Neon, { CastShadow = false })
			local l = Instance.new("SurfaceLight")
			l.Face = Enum.NormalId.Bottom
			l.Brightness = 1.1
			l.Range = 22
			l.Angle = 120
			l.Color = C(255, 226, 180)
			l.Parent = panel
		end
	end
	for _, pos in ipairs({ Vector3.new(-20, 0, 8), Vector3.new(20, 0, 8) }) do
		part(m, Vector3.new(2, 0.4, 2), CFrame.new(pos + Vector3.new(0, 0.2, 0)), C(60, 50, 45), Enum.Material.Metal)
		part(m, Vector3.new(0.35, 8, 0.35), CFrame.new(pos + Vector3.new(0, 4.2, 0)), C(60, 50, 45), Enum.Material.Metal)
		local shade = part(m, Vector3.new(2.6, 2, 2.6), CFrame.new(pos + Vector3.new(0, 8.6, 0)), C(255, 225, 160), Enum.Material.Neon, { Transparency = 0.2 })
		local l = Instance.new("PointLight")
		l.Range = 16
		l.Brightness = 0.9
		l.Color = C(255, 205, 140)
		l.Parent = shade
	end

	-- coin salon : canapés autour d'une table basse
	couch(m, CFrame.new(0, 0, 10) * CFrame.Angles(0, 0, 0), 14, C(230, 120, 90), 3)
	couch(m, CFrame.new(-13, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), 10, C(90, 140, 220), 2)
	couch(m, CFrame.new(13, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 10, C(240, 190, 70), 2)
	part(m, Vector3.new(9, 0.6, 5), CFrame.new(0, 1.9, 0), C(150, 100, 65), Enum.Material.Wood)
	for _, o in ipairs({ Vector3.new(-4, 0, -2), Vector3.new(4, 0, -2), Vector3.new(-4, 0, 2), Vector3.new(4, 0, 2) }) do
		part(m, Vector3.new(0.5, 1.6, 0.5), CFrame.new(o + Vector3.new(0, 0.8, 0)), C(110, 75, 50), Enum.Material.Wood)
	end
	part(m, Vector3.new(1, 1.2, 1), CFrame.new(-2, 2.8, 0) * CFrame.Angles(0, 0, math.rad(90)), C(255, 255, 255), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	part(m, Vector3.new(2.2, 0.4, 1.6), CFrame.new(2, 2.4, 0.4) * CFrame.Angles(0, 0.3, 0), C(240, 80, 80), Enum.Material.SmoothPlastic)
	-- poufs près des vitres
	for _, p in ipairs({ { Vector3.new(-26, 1.5, -24), C(255, 120, 180) }, { Vector3.new(-18, 1.5, -26), C(120, 210, 255) }, { Vector3.new(24, 1.5, -24), C(150, 230, 120) } }) do
		part(m, Vector3.new(4.5, 3.4, 4.5), CFrame.new(p[1]), p[2], Enum.Material.Fabric, { Shape = Enum.PartType.Ball })
	end

	-- comptoir café (mur gauche)
	part(m, Vector3.new(4, 3.6, 16), CFrame.new(-40.5, 1.8, -14), C(120, 82, 55), Enum.Material.Wood)
	part(m, Vector3.new(4.6, 0.4, 16.6), CFrame.new(-40.5, 3.8, -14), C(235, 235, 235), Enum.Material.Marble)
	local mach = part(m, Vector3.new(3, 4.4, 3.2), CFrame.new(-41, 6.2, -17), C(55, 55, 65), Enum.Material.Metal)
	part(m, Vector3.new(3.2, 0.5, 3.4), CFrame.new(-41, 8.6, -17), C(200, 200, 210), Enum.Material.Metal)
	part(m, Vector3.new(0.3, 0.8, 0.8), CFrame.new(-39.4, 6.6, -17), C(30, 30, 30), Enum.Material.Metal)
	part(m, Vector3.new(0.2, 0.4, 0.4), CFrame.new(-39.4, 7.6, -16.2), C(80, 255, 120), Enum.Material.Neon)
	part(m, Vector3.new(0.2, 0.4, 0.4), CFrame.new(-39.4, 7.6, -17.8), C(255, 80, 60), Enum.Material.Neon)
	part(m, Vector3.new(0.9, 0.8, 0.8), CFrame.new(-39.7, 4.4, -17) * CFrame.Angles(0, 0, math.rad(90)), C(255, 255, 255), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Rate = 3
	steam.Lifetime = NumberRange.new(1.5, 2.5)
	steam.Speed = NumberRange.new(1, 2)
	steam.Size = NumberSequence.new(0.4, 1.4)
	steam.Transparency = NumberSequence.new(0.6, 1)
	steam.EmissionDirection = Enum.NormalId.Top
	steam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	steam.Parent = mach
	local coffeeSign = part(m, Vector3.new(0.3, 2.4, 7), CFrame.new(-42.4, 11, -14), C(60, 40, 30), Enum.Material.Wood)
	surfaceText(coffeeSign, Enum.NormalId.Right, { { text = "COFFEE", color = C(255, 220, 160), h = 0.7 } }, { pps = 50 })
	for i = 0, 3 do
		part(m, Vector3.new(0.8, 0.9, 0.8), CFrame.new(-40, 4.45, -11 + i * 1.4) * CFrame.Angles(0, 0, math.rad(90)), ({ C(255, 90, 90), C(90, 160, 255), C(255, 210, 60), C(120, 220, 120) })[i + 1], Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	end

	-- distributeur (mur gauche)
	part(m, Vector3.new(4, 10, 6), CFrame.new(-40.5, 5, 6), C(215, 50, 60), Enum.Material.SmoothPlastic)
	part(m, Vector3.new(0.3, 6, 4), CFrame.new(-38.4, 6, 5.4), C(170, 220, 255), Enum.Material.Glass, { Transparency = 0.45 })
	local snacks = { C(255, 200, 40), C(90, 200, 255), C(255, 120, 200), C(120, 230, 110) }
	for r = 0, 2 do
		for c = 0, 3 do
			part(m, Vector3.new(0.6, 1, 0.7), CFrame.new(-38.9, 4.2 + r * 1.9, 3.9 + c * 1), snacks[((r + c) % #snacks) + 1], Enum.Material.SmoothPlastic, { CanCollide = false })
		end
	end
	part(m, Vector3.new(0.4, 1.2, 1.6), CFrame.new(-38.4, 6, 8.1), C(40, 40, 50), Enum.Material.Metal)
	part(m, Vector3.new(0.4, 1, 4), CFrame.new(-38.4, 1.6, 5.4), C(30, 30, 35), Enum.Material.Metal)
	local vendTop = part(m, Vector3.new(0.3, 1.4, 5), CFrame.new(-38.4, 9.3, 6), C(255, 240, 200), Enum.Material.Neon)
	surfaceText(vendTop, Enum.NormalId.Right, { { text = "SNACKS", color = C(200, 40, 50), h = 0.8, stroke = 0 } }, { pps = 50 })

	-- enseigne géante + tableau des gains (mur droit)
	local sign = part(m, Vector3.new(0.8, 8, 34), CFrame.new(42.2, 14.5, -8), C(36, 32, 62), Enum.Material.SmoothPlastic)
	surfaceText(sign, Enum.NormalId.Left, {
		{ text = "AFK BREAK ROOM", color = C(255, 214, 50), h = 0.55, stroke = 5 },
		{ text = "relax - you're on the clock", color = C(200, 230, 255), h = 0.22, body = true },
	}, { pps = 30 })
	for _, y in ipairs({ 10.3, 18.7 }) do
		part(m, Vector3.new(0.6, 0.4, 35), CFrame.new(41.8, y, -8), C(255, 140, 200), Enum.Material.Neon)
	end
	for _, z in ipairs({ -25.5, 9.5 }) do
		part(m, Vector3.new(0.6, 8.8, 0.4), CFrame.new(41.8, 14.5, z), C(255, 140, 200), Enum.Material.Neon)
	end
	local board = part(m, Vector3.new(0.6, 7, 14), CFrame.new(42.3, 6.5, 20), C(40, 80, 60), Enum.Material.SmoothPlastic)
	part(m, Vector3.new(0.5, 7.6, 14.6), CFrame.new(42.6, 6.5, 20), TRIM, Enum.Material.Wood)
	local capText = (Config.DailyCap or 0) > 0 and ("Daily AFK cap: " .. Config.DailyCap .. " Cash") or "No daily cap"
	surfaceText(board, Enum.NormalId.Left, {
		{ text = "PAYOUT BOARD", color = C(255, 214, 50), h = 0.18 },
		{ text = "+" .. Config.PayAmount .. " Cash every " .. math.floor(Config.PayInterval / 60 + 0.5) .. " min", h = 0.13, body = true },
		{ text = "+" .. Config.BonusAmount .. " bonus every " .. math.floor(Config.BonusEvery / 60 + 0.5) .. " min", h = 0.13, body = true, color = C(150, 255, 160) },
		{ text = capText, h = 0.11, body = true, color = C(200, 220, 210) },
		{ text = "Safe zone: no fighting", h = 0.11, body = true, color = C(255, 200, 200) },
	}, { pps = 40 })

	-- plantes
	for _, p in ipairs({ Vector3.new(-38, 0, -28), Vector3.new(38, 0, -28), Vector3.new(38, 0, 28), Vector3.new(-38, 0, 28), Vector3.new(-7, 0, 29), Vector3.new(7, 0, 29) }) do
		plant(m, CFrame.new(p), (math.abs(p.X) < 10) and 0.8 or 1.2)
	end

	-- horloge
	part(m, Vector3.new(0.4, 4, 4), CFrame.new(-24, 15, 32.1) * CFrame.Angles(0, math.rad(90), 0), C(255, 255, 255), Enum.Material.SmoothPlastic, { Shape = Enum.PartType.Cylinder })
	part(m, Vector3.new(0.2, 1.4, 0.2), CFrame.new(-24, 15.6, 31.8), C(30, 30, 30))
	part(m, Vector3.new(1, 0.2, 0.2), CFrame.new(-23.5, 15, 31.8), C(30, 30, 30))

	-- skyline derrière les vitres
	local city = Instance.new("Model")
	city.Name = "Skyline"
	city.Parent = m
	buildSkyline(city)

	-- points d'apparition (invisibles)
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = m
	spawnSpots = {}
	for _, x in ipairs({ -8, -3, 3, 8 }) do
		local s = part(spawns, Vector3.new(2, 1, 2), CFrame.new(x, 0.5, 19), Color3.new(1, 1, 1), nil, { Transparency = 1, CanCollide = false })
		table.insert(spawnSpots, s)
	end

	m.Parent = workspace
	room = m
	return m, door, pad
end

------------------------------------------------------------------------
-- Session
------------------------------------------------------------------------
local function today()
	return os.time() // 86400
end

local function afkData(player)
	local d = DataService.get(player)
	if not d then
		return nil
	end
	if type(d.AFK) ~= "table" then
		d.AFK = {}
	end
	if d.AFK.Day ~= today() then
		d.AFK.Day = today()
		d.AFK.Earned = 0
	end
	return d.AFK
end

local function capLeft(player)
	local a = afkData(player)
	if not a then
		return 0
	end
	if (Config.DailyCap or 0) <= 0 then
		return math.huge
	end
	return math.max(0, Config.DailyCap - (tonumber(a.Earned) or 0))
end

local function setAttrs(player, s)
	if s then
		local now = os.clock()
		local snow = serverNow()
		player:SetAttribute("AFKActive", true)
		player:SetAttribute("AFKSince", snow - (now - s.enteredAt))
		player:SetAttribute("AFKNextPay", snow + math.max(0, Config.PayInterval - (now - s.lastPay)))
		player:SetAttribute("AFKNextBonus", snow + math.max(0, (s.bonuses + 1) * Config.BonusEvery - (now - s.enteredAt)))
		player:SetAttribute("AFKEarned", s.earned)
		local left = capLeft(player)
		player:SetAttribute("AFKCapLeft", left == math.huge and -1 or left)
	else
		player:SetAttribute("AFKActive", false)
		player:SetAttribute("AFKNextPay", nil)
		player:SetAttribute("AFKNextBonus", nil)
	end
end

function AFKService.isAFK(player: Player): boolean
	return sessions[player] ~= nil
end

local function alive(character)
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil, hum
end

local function unseat(hum)
	if not hum then
		return
	end
	local seat = hum.SeatPart
	if seat then
		local w = seat:FindFirstChild("SeatWeld")
		if w then
			w:Destroy()
		end
	end
	hum.Sit = false
end

local function moveTo(player, character, cf)
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 5)
	end)
	if not character.Parent or player.Character ~= character then
		return false
	end
	local _, hum = alive(character)
	unseat(hum)
	character:PivotTo(cf)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	return true
end

local function roomSpawn()
	local spot = spawnSpots[math.random(1, math.max(1, #spawnSpots))]
	local pos = spot and spot.Position or (ORIGIN + Vector3.new(0, 0.5, 19))
	return CFrame.lookAt(pos + Vector3.new(0, 3, 0), pos + Vector3.new(0, 3, -10))
end

local function inside(pos: Vector3): boolean
	local d = pos - ORIGIN
	return math.abs(d.X) <= HALF.X and math.abs(d.Z) <= HALF.Z and d.Y > -8 and d.Y < 30
end

local function endSession(player)
	local s = sessions[player]
	sessions[player] = nil
	if s and s.character and s.character.Parent then
		s.character:SetAttribute("SafeZone", nil)
	end
	if player.Parent then
		setAttrs(player, nil)
	end
	return s
end

local function deny(player, text)
	Announce.toast(player, text, RED)
	return false
end

function AFKService.enter(player: Player)
	if sessions[player] or busy[player] then
		return false
	end
	if not DataService.get(player) then
		return deny(player, "Your data is still loading...")
	end
	local character = player.Character
	local ok, hum = alive(character)
	if not ok then
		return deny(player, "You can't take a break while knocked out!")
	end
	local now = os.clock()
	if now - (lastToggle[player] or -100) < Config.ToggleCooldown then
		return deny(player, "Wait a moment before switching again")
	end
	if World.collapsing then
		return deny(player, "The floor is collapsing! Hold on...")
	end
	local st = CharacterState.get(character)
	local hurt = math.max(lastHurt[character] or -100, st.lastHitTime or -100)
	if now - hurt < Config.CombatLockout or CharacterState.isStunned(character) then
		return deny(player, "You're in combat! Get away for " .. Config.CombatLockout .. "s first")
	end
	lastToggle[player] = now
	busy[player] = true
	-- lâche l'objet tenu (pas d'objets dans la salle de pause)
	pcall(function()
		require(script.Parent.ItemService).dropHeld(character)
	end)
	unseat(hum)
	character:SetAttribute("SafeZone", true)
	local moved = moveTo(player, character, roomSpawn())
	busy[player] = nil
	if not moved or not alive(character) then
		if character.Parent then
			character:SetAttribute("SafeZone", nil)
		end
		return false
	end
	local s = { character = character, enteredAt = os.clock(), lastPay = os.clock(), bonuses = 0, earned = 0 }
	sessions[player] = s
	setAttrs(player, s)
	Announce.toast(player, "Welcome to the Break Room! +" .. Config.PayAmount .. " Cash every minute.", Color3.fromRGB(120, 230, 255))
	return true
end

function AFKService.exit(player: Player, force: boolean?)
	local s = sessions[player]
	if not s or busy[player] then
		return false
	end
	local now = os.clock()
	if not force and now - (lastToggle[player] or -100) < Config.ToggleCooldown then
		return deny(player, "Wait a moment before switching again")
	end
	lastToggle[player] = now
	busy[player] = true
	sessions[player] = nil -- plus de rappel dans la salle pendant le trajet
	local character = s.character
	-- pas de retour pendant un effondrement : on attend que le nouvel étage soit posé
	local t0 = os.clock()
	while World.collapsing and os.clock() - t0 < 12 do
		task.wait(0.25)
	end
	if alive(character) and player.Character == character then
		moveTo(player, character, World.getPlayerSpawn())
		pcall(CharacterState.protect, character, 3)
	end
	busy[player] = nil
	if character and character.Parent then
		character:SetAttribute("SafeZone", nil)
	end
	if player.Parent then
		setAttrs(player, nil)
	end
	if player.Parent and s.earned > 0 then
		Announce.toast(player, "Break over! You earned " .. s.earned .. " Cash.", Color3.fromRGB(110, 235, 120))
	end
	return true
end

local function pay(player, s, amount, reason)
	local left = capLeft(player)
	amount = math.min(amount, left)
	if amount <= 0 then
		return 0
	end
	local a = afkData(player)
	a.Earned = (tonumber(a.Earned) or 0) + amount
	s.earned += amount
	local ok, SkinService = pcall(require, script.Parent.SkinService)
	if ok and SkinService and SkinService.addCash then
		SkinService.addCash(player, amount, reason)
	else
		local d = DataService.get(player)
		d.Cash = (d.Cash or 0) + amount
		player:SetAttribute("Cash", d.Cash)
	end
	return amount
end

-- admin / tests : paie tout de suite le prochain versement
function AFKService.forcePay(player: Player)
	local s = sessions[player]
	if not s then
		return false
	end
	s.lastPay = os.clock() - Config.PayInterval
	return true
end

local function tick()
	local now = os.clock()
	for player, s in pairs(sessions) do
		if busy[player] then
			continue
		end
		local character = s.character
		if not player.Parent or player.Character ~= character or not alive(character) then
			endSession(player)
			continue
		end
		character:SetAttribute("SafeZone", true)
		local root = character:FindFirstChild("HumanoidRootPart")
		-- déplacé hors de la salle (effondrement, événement, chute) : retour dans la salle
		if root and not inside(root.Position) then
			busy[player] = true
			task.spawn(function()
				moveTo(player, character, roomSpawn())
				busy[player] = nil
			end)
			continue
		end
		local changed = false
		if now - s.lastPay >= Config.PayInterval then
			s.lastPay += Config.PayInterval
			if now - s.lastPay >= Config.PayInterval then
				s.lastPay = now -- rattrapage (serveur figé) : un seul versement
			end
			pay(player, s, Config.PayAmount, "AFK")
			changed = true
		end
		local bonuses = math.floor((now - s.enteredAt) / Config.BonusEvery)
		if bonuses > s.bonuses then
			s.bonuses = bonuses
			local got = pay(player, s, Config.BonusAmount, "AFK BONUS")
			if got > 0 then
				Announce.toast(player, "Break bonus! +" .. got .. " Cash for " .. math.floor(bonuses * Config.BonusEvery / 60) .. " minutes of chill.", Color3.fromRGB(255, 214, 50))
			end
			changed = true
		end
		if changed then
			setAttrs(player, s)
			if capLeft(player) <= 0 and not s.cappedWarned then
				s.cappedWarned = true
				Announce.toast(player, "Daily AFK cap reached. Come back tomorrow!", Color3.fromRGB(255, 180, 80))
			end
		end
	end
end

function AFKService.init()
	local _, door, pad = buildRoom()

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Back to work"
	prompt.ObjectText = "Exit"
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = door
	prompt.Triggered:Connect(function(player)
		if sessions[player] then
			AFKService.exit(player)
		end
	end)
	pad.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if player and sessions[player] and sessions[player].character == character and not busy[player] then
			if os.clock() - (lastToggle[player] or -100) >= Config.ToggleCooldown then
				AFKService.exit(player)
			end
		end
	end)

	Net.get("AFK").OnServerEvent:Connect(function(player, op)
		if not Net.allow(player, "AFK", 3) then
			return
		end
		if op == "Enter" then
			AFKService.enter(player)
		elseif op == "Exit" then
			AFKService.exit(player)
		elseif op == "Toggle" then
			if sessions[player] then
				AFKService.exit(player)
			else
				AFKService.enter(player)
			end
		end
	end)

	Signals.Hit:Connect(function(_, victim)
		if typeof(victim) == "Instance" then
			lastHurt[victim] = os.clock()
		end
	end)

	local function onPlayer(player)
		player:SetAttribute("AFKActive", false)
		player.CharacterAdded:Connect(function()
			if sessions[player] then
				endSession(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		sessions[p] = nil
		lastToggle[p] = nil
		busy[p] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(tick)
			if not ok then
				warn("[AFKService]", err)
			end
		end
	end)
end

return AFKService
