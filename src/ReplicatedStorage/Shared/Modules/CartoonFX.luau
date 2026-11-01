--[[
	CartoonFX — module central des effets cartoon (client).
	Appelé par tous les systèmes : coups, objets, futures attaques, étages, événements.

	CartoonFX.hit(data)        effet complet d'un coup (onomatopée, étoiles, chiffres, flash, son, shake, hit-stop)
	CartoonFX.word(pos, text, power, category)
	CartoonFX.impact(pos, power)
	CartoonFX.damageNumber(pos, amount, power)
	CartoonFX.sound(key, pos, volume)
	CartoonFX.shake(intensity)
	CartoonFX.twinkle(pos)     étoile qui scintille (« ding! ») quand quelqu'un est éjecté très loin
	CartoonFX.dizzy(character, duration)
	CartoonFX.alert(character) « ! » au-dessus de la tête (saisies)
	CartoonFX.puff(pos, size)  petit nuage de fumée
	CartoonFX.setSweat(character, on)

	Tous les éléments sont créés localement (jamais répliqués) et nettoyés automatiquement.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Words = require(Config.Words)
local Sounds = require(Config.Sounds)
local CombatConfig = require(Config.Combat)
local ProcAnim = require(ReplicatedStorage.Shared.Modules.ProcAnim)
local UITheme = require(ReplicatedStorage.Shared.Modules.UITheme)
local PIXEL = UITheme.Display

local CartoonFX = {}
local rng = Random.new()
local localPlayer = Players.LocalPlayer

local function tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- point d'ancrage invisible dans le monde (attachment dans Terrain)
local function anchorAt(pos: Vector3, life: number)
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = workspace.Terrain
	Debris:AddItem(att, life)
	return att
end

local function billboard(adornee, sizeStuds: number, life: number?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(sizeStuds, sizeStuds)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 160
	bb.ResetOnSpawn = false
	bb.Adornee = adornee
	bb.Parent = adornee
	if life then
		Debris:AddItem(bb, life)
	end
	return bb
end

local function colorForPower(power: number): Color3
	local c = Words.TextColors
	if power <= 0.5 then
		return c[1]:Lerp(c[2], power / 0.5)
	end
	return c[2]:Lerp(c[3], math.clamp((power - 0.5) / 0.5, 0, 1))
end

------------------------------------------------------------------------
-- Sons
------------------------------------------------------------------------
function CartoonFX.sound(key: string, pos: Vector3?, volume: number?)
	local list = Sounds[key]
	if type(list) ~= "table" or #list == 0 then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = list[rng:NextInteger(1, #list)]
	s.Volume = (volume or 0.7) * rng:NextNumber(0.85, 1.05)
	s.PlaybackSpeed = rng:NextNumber(0.9, 1.12)
	s.RollOffMaxDistance = 140
	s.RollOffMinDistance = 12
	if pos then
		s.Parent = anchorAt(pos, 4)
	else
		s.Parent = workspace.CurrentCamera
		Debris:AddItem(s, 4)
	end
	s:Play()
	return s
end

------------------------------------------------------------------------
-- Tremblement d'écran
------------------------------------------------------------------------
local shakeAmp = 0
function CartoonFX.shake(intensity: number)
	shakeAmp = math.max(shakeAmp, intensity)
end
RunService:BindToRenderStep("CartoonShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shakeAmp > 0.005 then
		local cam = workspace.CurrentCamera
		local a = shakeAmp
		cam.CFrame = cam.CFrame
			* CFrame.new(rng:NextNumber(-a, a) * 0.6, rng:NextNumber(-a, a) * 0.6, 0)
			* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-a, a) * 2))
		shakeAmp *= math.exp(-dt * 14)
	else
		shakeAmp = 0
	end
end)

------------------------------------------------------------------------
-- Onomatopée BD (mot + étoile d'explosion)
------------------------------------------------------------------------
local function makeBurst(parent, color: Color3, scale: number, z: number)
	local holder = Instance.new("Frame")
	holder.Name = "Burst"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(scale, scale)
	holder.BackgroundTransparency = 1
	holder.ZIndex = z
	holder.Parent = parent
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = holder
	-- 8 rectangles fins tournés (longueurs alternées) = étoile à 16 pointes + disque central
	for i = 0, 7 do
		local spike = Instance.new("Frame")
		spike.AnchorPoint = Vector2.new(0.5, 0.5)
		spike.Position = UDim2.fromScale(0.5, 0.5)
		spike.Size = UDim2.fromScale(i % 2 == 0 and 1 or 0.78, 0.13)
		spike.Rotation = i * 22.5 + rng:NextNumber(-4, 4)
		spike.BackgroundColor3 = color
		spike.BorderSizePixel = 0
		spike.ZIndex = z
		spike.Parent = holder
	end
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.5, 0.5)
	core.BackgroundColor3 = color
	core.BorderSizePixel = 0
	core.ZIndex = z
	core.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = core
	return holder
end

local function fadeDescendants(root, time)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Frame") then
			tween(d, time, { BackgroundTransparency = 1 })
		elseif d:IsA("TextLabel") then
			tween(d, time, { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, time, { Transparency = 1 })
		end
	end
end

local ComicWords
function CartoonFX.word(pos: Vector3, text: string, power: number?, category: string?)
	if ComicWords == nil then
		local m = script.Parent:FindFirstChild("ComicWords")
		local ok, mod = false, nil
		if m then
			ok, mod = pcall(require, m)
		end
		ComicWords = (ok and type(mod) == "table" and mod.create) and mod or false
	end
	if ComicWords then
		local ok, err = pcall(ComicWords.create, pos, text, power, category)
		if ok then
			return
		end
		warn("[ComicWords]", err)
	end
	return CartoonFX.wordLegacy(pos, text, power, category)
end

function CartoonFX.wordLegacy(pos: Vector3, text: string, power: number?, category: string?)
	power = math.clamp(power or 0.4, 0, 1.5)
	local isKO = category == "KO"
	local size = 2.8 + power * 2.8 + (isKO and 3 or 0)
	local life = isKO and 1.2 or 0.65
	local offset = Vector3.new(rng:NextNumber(-0.8, 0.8), 1.2 + rng:NextNumber(0, 0.8), rng:NextNumber(-0.8, 0.8))
	local att = anchorAt(pos + offset, life + 0.1)
	local bb = billboard(att, size, life + 0.1)
	bb.Size = UDim2.fromScale(size * 1.5, size) -- plus large que haut : le mot déborde de l'étoile, façon BD

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Rotation = rng:NextNumber(-14, 14)
	root.Parent = bb
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0
	uiScale.Parent = root

	local burstColor = Words.CategoryBurst[category or ""] or Words.BurstColors[rng:NextInteger(1, #Words.BurstColors)]
	makeBurst(root, Color3.new(0, 0, 0), 1, 1) -- contour noir
	local burst = makeBurst(root, burstColor, 0.9, 2)
	burst.Rotation = rng:NextNumber(0, 30)

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.98, 0.5)
	label.BackgroundTransparency = 1
	label.FontFace = PIXEL
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = isKO and Color3.fromRGB(255, 255, 255) or colorForPower(power)
	label.ZIndex = 3
	label.Parent = root
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = isKO and 6 or 4
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label

	-- pop : 0 -> 1.3 -> 1, puis disparition qui monte un peu
	task.spawn(function()
		tween(uiScale, 0.08, { Scale = 1.3 }, Enum.EasingStyle.Back)
		task.wait(0.08)
		tween(uiScale, 0.08, { Scale = 1 })
		tween(burst, 0.5, { Rotation = burst.Rotation + rng:NextNumber(-25, 25) })
		task.wait(life - 0.36)
		if bb.Parent then
			tween(uiScale, 0.2, { Scale = 0.75 })
			tween(bb, 0.2, { StudsOffsetWorldSpace = Vector3.new(0, 0.8, 0) })
			fadeDescendants(root, 0.2)
		end
	end)
end

------------------------------------------------------------------------
-- Étoiles d'impact + lignes de vitesse
------------------------------------------------------------------------
function CartoonFX.impact(pos: Vector3, power: number?)
	power = math.clamp(power or 0.4, 0, 1.5)
	local size = 6 + power * 5
	local att = anchorAt(pos, 0.6)
	local bb = billboard(att, size, 0.6)
	bb.AlwaysOnTop = false
	local stars = 4 + math.floor(power * 4)
	for i = 1, stars do
		local a = (i / stars) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local star = Instance.new("TextLabel")
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(0.5, 0.5)
		star.Size = UDim2.fromScale(0.16, 0.16)
		star.BackgroundTransparency = 1
		star.Text = "★"
		star.TextScaled = true
		star.Font = Enum.Font.GothamBlack
		star.TextColor3 = (i % 2 == 0) and Color3.fromRGB(255, 235, 60) or Color3.fromRGB(255, 255, 255)
		star.Rotation = rng:NextNumber(0, 90)
		star.Parent = bb
		local st = Instance.new("UIStroke")
		st.Thickness = 2
		st.Parent = star
		local r = rng:NextNumber(0.32, 0.46)
		tween(star, 0.45, {
			Position = UDim2.fromScale(0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r),
			Rotation = star.Rotation + 180,
			TextTransparency = 1,
			Size = UDim2.fromScale(0.08, 0.08),
		})
		tween(st, 0.45, { Transparency = 1 })
	end
	-- lignes de vitesse
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.18, 0.5 + math.sin(a) * 0.18)
		line.Size = UDim2.fromScale(0.22, 0.025)
		line.Rotation = math.deg(a)
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BorderSizePixel = 0
		line.Parent = bb
		tween(line, 0.25, {
			Position = UDim2.fromScale(0.5 + math.cos(a) * 0.45, 0.5 + math.sin(a) * 0.45),
			Size = UDim2.fromScale(0.08, 0.012),
			BackgroundTransparency = 1,
		})
	end
end

------------------------------------------------------------------------
-- Chiffres de dégâts
------------------------------------------------------------------------
function CartoonFX.damageNumber(pos: Vector3, amount: number, power: number?)
	local pw = power or 0.4
	local big = pw >= 0.7
	local att = anchorAt(pos + Vector3.new(rng:NextNumber(-1.5, 1.5), 2.5, rng:NextNumber(-1.5, 1.5)), 0.95)
	local bb = billboard(att, 2.6 + pw * 2.2, 0.95)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.5)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.6)
	label.Rotation = rng:NextNumber(-10, 10)
	label.BackgroundTransparency = 1
	label.FontFace = PIXEL
	label.TextScaled = true
	label.Text = tostring(math.floor(amount + 0.5))
	-- dégradé 2 tons façon arcade (blanc -> jaune, ou jaune -> rouge pour les gros coups)
	label.TextColor3 = Color3.new(1, 1, 1)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = big and ColorSequence.new(Color3.fromRGB(255, 235, 80), Color3.fromRGB(255, 60, 50))
		or ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 215, 90))
	g.Parent = label
	label.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = big and 4 or 3
	st.Color = UITheme.Colors.Ink
	st.LineJoinMode = Enum.LineJoinMode.Miter
	st.Parent = label
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = label
	tween(sc, 0.1, { Scale = big and 1.6 or 1.25 }, Enum.EasingStyle.Back)
	task.delay(0.1, function()
		tween(sc, 0.12, { Scale = 1 })
	end)
	tween(label, 0.85, { Position = UDim2.fromScale(0.5 + rng:NextNumber(-0.15, 0.15), 0.05), Rotation = label.Rotation * 0.3 })
	task.delay(0.5, function()
		tween(label, 0.35, { TextTransparency = 1 })
		tween(st, 0.35, { Transparency = 1 })
	end)
end

------------------------------------------------------------------------
-- Flash blanc sur la victime
------------------------------------------------------------------------
function CartoonFX.flash(character: Model, duration: number?)
	if not character then
		return
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = Color3.new(1, 1, 1)
	hl.FillTransparency = 0.15
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = character
	hl.Parent = character
	Debris:AddItem(hl, duration or 0.08)
end

------------------------------------------------------------------------
-- Nuage de fumée cartoon
------------------------------------------------------------------------
function CartoonFX.puff(pos: Vector3, size: number?)
	size = size or 1
	for i = 1, 6 do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(245, 245, 245)
		local s = rng:NextNumber(1, 1.8) * size
		p.Size = Vector3.one * s
		local a = (i / 6) * math.pi * 2
		p.Position = pos + Vector3.new(math.cos(a), 0.2, math.sin(a)) * 0.6 * size
		p.Parent = workspace.FX
		tween(p, 0.45, {
			Position = pos + Vector3.new(math.cos(a) * 2.6, rng:NextNumber(0.4, 1.4), math.sin(a) * 2.6) * size,
			Size = Vector3.one * s * 1.8,
			Transparency = 1,
		})
		Debris:AddItem(p, 0.5)
	end
end

------------------------------------------------------------------------
-- Étoile qui scintille (« ding! »)
------------------------------------------------------------------------
function CartoonFX.twinkle(pos: Vector3)
	local att = anchorAt(pos, 1)
	local bb = billboard(att, 6, 1)
	local star = Instance.new("TextLabel")
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Position = UDim2.fromScale(0.5, 0.5)
	star.Size = UDim2.fromScale(1, 1)
	star.BackgroundTransparency = 1
	star.Text = "✦"
	star.Font = Enum.Font.GothamBlack
	star.TextScaled = true
	star.TextColor3 = Color3.fromRGB(255, 250, 170)
	star.Parent = bb
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = star
	tween(sc, 0.18, { Scale = 1.4 }, Enum.EasingStyle.Back)
	tween(star, 0.9, { Rotation = 200 })
	task.delay(0.35, function()
		tween(sc, 0.4, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end)
	CartoonFX.sound("Ding", nil, 0.6)
end

------------------------------------------------------------------------
-- Vertige, sueur, alerte (attachés à la tête)
------------------------------------------------------------------------
local dizzyState = {} -- [character] = {bb, untilT}
function CartoonFX.dizzy(character: Model, duration: number)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local st = dizzyState[character]
	if st and st.bb.Parent then
		st.untilT = math.max(st.untilT, os.clock() + duration)
		return
	end
	local bb = billboard(head, 4)
	bb.StudsOffset = Vector3.new(0, 1.6, 0)
	bb.AlwaysOnTop = false
	local stars = {}
	for i = 1, 3 do
		local s = Instance.new("TextLabel")
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Size = UDim2.fromScale(0.28, 0.28)
		s.BackgroundTransparency = 1
		s.Text = "★"
		s.Font = Enum.Font.GothamBlack
		s.TextScaled = true
		s.TextColor3 = Color3.fromRGB(255, 225, 50)
		s.Parent = bb
		local k = Instance.new("UIStroke")
		k.Thickness = 2
		k.Parent = s
		stars[i] = s
	end
	st = { bb = bb, untilT = os.clock() + duration, stars = stars }
	dizzyState[character] = st
end

local sweatState = {}
function CartoonFX.setSweat(character: Model, on: boolean)
	local st = sweatState[character]
	if on and not st then
		local head = character:FindFirstChild("Head")
		if not head then
			return
		end
		local bb = billboard(head, 3)
		bb.StudsOffset = Vector3.new(0, 0.3, 0)
		bb.AlwaysOnTop = false
		local drops = {}
		for i = 1, 2 do
			local d = Instance.new("TextLabel")
			d.AnchorPoint = Vector2.new(0.5, 0.5)
			d.Size = UDim2.fromScale(0.3, 0.3)
			d.BackgroundTransparency = 1
			d.Text = "💧"
			d.TextScaled = true
			d.Parent = bb
			drops[i] = d
		end
		sweatState[character] = { bb = bb, drops = drops }
	elseif not on and st then
		st.bb:Destroy()
		sweatState[character] = nil
	end
end

function CartoonFX.alert(character: Model)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = billboard(head, 3, 0.8)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "!"
	l.FontFace = PIXEL
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 60, 60)
	l.Parent = bb
	local k = Instance.new("UIStroke")
	k.Thickness = 4
	k.Parent = l
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = l
	tween(sc, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
end

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for character, st in pairs(dizzyState) do
		if not st.bb.Parent or now > st.untilT then
			st.bb:Destroy()
			dizzyState[character] = nil
		else
			for i, s in ipairs(st.stars) do
				local a = now * 6 + i * (math.pi * 2 / 3)
				s.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.36, 0.5 + math.sin(a) * 0.12)
				s.ZIndex = math.sin(a) > 0 and 2 or 1
			end
		end
	end
	for character, st in pairs(sweatState) do
		if not st.bb.Parent then
			sweatState[character] = nil
		else
			for i, d in ipairs(st.drops) do
				local phase = (now * 1.6 + i * 0.5) % 1
				local side = i == 1 and 0.12 or 0.88
				d.Position = UDim2.fromScale(side, 0.2 + phase * 0.6)
				d.TextTransparency = phase
			end
		end
	end
end)

------------------------------------------------------------------------
-- « JUICE » : gel réel, zoom caméra, impact frames, ondes de choc, éclats, étincelles, lignes de vitesse
------------------------------------------------------------------------
local function involvesLocal(model)
	return model ~= nil and localPlayer and model == localPlayer.Character
end

-- gel réel du personnage local (hit-stop physique) : on ancre son HumanoidRootPart
local frozenUntil = 0
function CartoonFX.freezeLocal(duration: number)
	local c = localPlayer.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	frozenUntil = math.max(frozenUntil, os.clock() + duration)
	if root.Anchored then
		return
	end
	local vel = root.AssemblyLinearVelocity
	root.Anchored = true
	task.spawn(function()
		while os.clock() < frozenUntil do
			task.wait()
		end
		if root.Parent then
			root.Anchored = false
			root.AssemblyLinearVelocity = vel * 0.3
		end
	end)
end

-- coup de zoom (FOV)
local fovBase, fovKick = nil, 0
function CartoonFX.fovKick(amount: number)
	fovKick = math.max(fovKick, amount)
end
RunService:BindToRenderStep("CartoonFOV", Enum.RenderPriority.Camera.Value + 2, function(dt)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	if fovKick > 0.05 then
		fovBase = fovBase or cam.FieldOfView
		cam.FieldOfView = fovBase - fovKick
		fovKick *= math.exp(-dt * 10)
	elseif fovBase then
		cam.FieldOfView = fovBase
		fovBase = nil
		fovKick = 0
	end
end)

-- impact frame : 1–2 images très contrastées (façon anime)
local cc
function CartoonFX.impactFrame(strength: number?)
	strength = strength or 1
	if not cc or not cc.Parent then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "ImpactFrame"
		cc.Parent = game:GetService("Lighting")
	end
	cc.Enabled = true
	cc.Saturation = -1
	cc.Contrast = 0.9 * strength
	cc.Brightness = 0.15 * strength
	task.delay(0.045, function()
		cc.Saturation = 0.4
		cc.Contrast = 0.3
		cc.Brightness = 0
		task.delay(0.05, function()
			cc.Enabled = false
		end)
	end)
end

-- lignes de vitesse plein écran (style manga)
local linesGui
function CartoonFX.speedLines(duration: number?, color: Color3?)
	if not linesGui or not linesGui.Parent then
		linesGui = Instance.new("ScreenGui")
		linesGui.Name = "SpeedLines"
		linesGui.IgnoreGuiInset = true
		linesGui.DisplayOrder = 5
		linesGui.Parent = localPlayer:WaitForChild("PlayerGui")
	end
	for i = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local l = Instance.new("Frame")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.55, 0.5 + math.sin(a) * 0.55)
		l.Size = UDim2.fromScale(rng:NextNumber(0.25, 0.45), 0.006)
		l.Rotation = math.deg(a)
		l.BackgroundColor3 = color or Color3.new(1, 1, 1)
		l.BackgroundTransparency = 0.1
		l.BorderSizePixel = 0
		l.Parent = linesGui
		tween(l, duration or 0.3, { Position = UDim2.fromScale(0.5 + math.cos(a) * 0.7, 0.5 + math.sin(a) * 0.7), BackgroundTransparency = 1 })
		Debris:AddItem(l, (duration or 0.3) + 0.05)
	end
end

-- onde de choc au sol (anneau qui s'élargit)
function CartoonFX.shockwave(pos: Vector3, radius: number?, color: Color3?)
	radius = radius or 8
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 1, 1)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = color or Color3.new(1, 1, 1)
	ring.Transparency = 0.2
	ring.Parent = workspace.FX
	tween(ring, 0.35, { Size = Vector3.new(0.15, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(ring, 0.4)
end

-- éclats colorés qui rebondissent (physique locale)
local SHARD_COLORS = { Color3.fromRGB(255, 230, 60), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 110, 70), Color3.fromRGB(110, 210, 255) }
function CartoonFX.shards(pos: Vector3, count: number, colors, speed: number?)
	colors = colors or SHARD_COLORS
	for i = 1, count do
		local p = Instance.new("Part")
		p.Size = Vector3.one * rng:NextNumber(0.25, 0.55)
		p.Position = pos + Vector3.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 0.5), rng:NextNumber(-0.5, 0.5))
		p.Color = colors[rng:NextInteger(1, #colors)]
		p.Material = Enum.Material.SmoothPlastic
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CollisionGroup = "Debris"
		p.Parent = workspace.FX
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.4, 1.2), rng:NextNumber(-1, 1)).Unit
		p.AssemblyLinearVelocity = dir * rng:NextNumber(18, 34) * (speed or 1)
		p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(-20, 20), rng:NextNumber(-20, 20))
		Debris:AddItem(p, rng:NextNumber(0.8, 1.3))
	end
end

-- étincelles (particules intégrées à Roblox)
function CartoonFX.sparks(pos: Vector3, count: number?, color: Color3?)
	local att = anchorAt(pos, 1)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color or Color3.fromRGB(255, 240, 120))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.2, 0.4)
	pe.Speed = NumberRange.new(25, 45)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Drag = 6
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(count or 14)
end

-- GROS IMPACT : flash, double onde de choc au sol, anneau d'air dans l'axe du coup, poussière, débris, fissures
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundAt(pos: Vector3): Vector3
	local ex = { workspace:FindFirstChild("FX"), workspace:FindFirstChild("Dummies"), workspace:FindFirstChild("ActiveItems"), workspace:FindFirstChild("Zones") }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	groundParams.FilterDescendantsInstances = ex
	local r = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), groundParams)
	return r and r.Position or (pos - Vector3.new(0, 3, 0)), r ~= nil
end

local function fxPart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = workspace.FX
	return p
end

function CartoonFX.bigImpact(pos: Vector3, dir: Vector3?, power: number?, color: Color3?)
	power = math.clamp(power or 1, 0.5, 1.6)
	color = color or Color3.new(1, 1, 1)
	-- flash sphérique
	local flash = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, Position = pos, Color = Color3.new(1, 1, 1), Transparency = 0.1 })
	tween(flash, 0.18, { Size = Vector3.one * 7 * power, Transparency = 1 })
	Debris:AddItem(flash, 0.2)
	-- anneau d'air perpendiculaire au coup
	if dir and dir.Magnitude > 0.1 then
		local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2, 2), CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi / 2, 0), Color = color, Transparency = 0.15 })
		tween(ring, 0.3, { Size = Vector3.new(0.1, 10 * power, 10 * power), Transparency = 1 })
		Debris:AddItem(ring, 0.32)
		-- traînée de choc qui part dans la direction du coup
		for i = 1, 3 do
			local l = fxPart({ Size = Vector3.new(0.25, 0.25, 3), CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), -1), Color = Color3.new(1, 1, 1), Transparency = 0.2 })
			tween(l, 0.22, { CFrame = l.CFrame * CFrame.new(0, 0, -6 * power), Transparency = 1, Size = Vector3.new(0.1, 0.1, 5) })
			Debris:AddItem(l, 0.25)
		end
	end
	-- au sol : double onde de choc + poussière + débris + fissures
	local ground, hit = groundAt(pos)
	if hit and (pos - ground).Magnitude < 8 then
		CartoonFX.shockwave(ground + Vector3.new(0, 0.15, 0), 9 * power, color)
		task.delay(0.07, function()
			CartoonFX.shockwave(ground + Vector3.new(0, 0.2, 0), 14 * power, Color3.fromRGB(230, 230, 235))
		end)
		for i = 1, 8 do
			local a = (i / 8) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local d = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(1.2, 2), Position = ground + out * 1.5 + Vector3.new(0, 0.6, 0), Color = Color3.fromRGB(225, 220, 210), Transparency = 0.2 })
			tween(d, 0.55, { Position = ground + out * 7 * power + Vector3.new(0, rng:NextNumber(0.6, 1.8), 0), Size = d.Size * 2.2, Transparency = 1 })
			Debris:AddItem(d, 0.6)
		end
		for i = 1, 5 do
			local a = rng:NextNumber(0, math.pi * 2)
			local crack = fxPart({ Size = Vector3.new(0.25, 0.06, rng:NextNumber(2, 4.5) * power), CFrame = CFrame.new(ground + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.6 * power), Color = Color3.fromRGB(40, 40, 45), Transparency = 0.15 })
			task.delay(1.2, function()
				tween(crack, 0.5, { Transparency = 1 })
			end)
			Debris:AddItem(crack, 1.8)
		end
		CartoonFX.shards(ground + Vector3.new(0, 0.5, 0), math.floor(6 * power), { Color3.fromRGB(170, 170, 180), Color3.fromRGB(120, 120, 130) }, 1.1)
	end
end

local function onScreen(pos)
	local cam = workspace.CurrentCamera
	return cam and (cam.CFrame.Position - pos).Magnitude < 70
end

------------------------------------------------------------------------
-- Effet complet d'un coup
-- data = { a = attaquant, v = victime, p = position, c = catégorie, pw = puissance, d = dégâts,
--          w = liste de mots, m = matière, ko = bool, r = réaction ("Light"|"Heavy"|"Launch"|"Slam"), fin = finisher }
------------------------------------------------------------------------
function CartoonFX.hit(data)
	local pos = data.p
	local category = data.c or "Light"
	local power = data.pw or 0.4
	local heavy = category == "Heavy" or data.ko or data.fin
	local list = data.w or Words[category] or Words.Light
	local text = list[rng:NextInteger(1, #list)]
	local mine = involvesLocal(data.a) or involvesLocal(data.v)

	CartoonFX.word(pos, text, power + (data.fin and 0.4 or 0), category)
	CartoonFX.impact(pos, power)
	if data.d and data.d > 0 then
		CartoonFX.damageNumber(pos, data.d, power)
	end
	CartoonFX.flash(data.v, heavy and 0.12 or 0.07)
	CartoonFX.sparks(pos, heavy and 22 or 10)
	CartoonFX.shards(pos, heavy and 10 or 4, nil, heavy and 1.2 or 0.8)
	if heavy then
		local dir
		if data.a and data.v and data.a:FindFirstChild("HumanoidRootPart") and data.v:FindFirstChild("HumanoidRootPart") then
			dir = data.v.HumanoidRootPart.Position - data.a.HumanoidRootPart.Position
		end
		CartoonFX.bigImpact(pos, dir, power + (data.fin and 0.3 or 0) + (data.ko and 0.4 or 0))
	end

	-- réaction de la victime
	if data.v then
		local r = data.r or "Light"
		if r == "Launch" then
			ProcAnim.play(data.v, "Launch")
		elseif r == "Heavy" or r == "Slam" then
			ProcAnim.play(data.v, "HitHeavy")
		else
			ProcAnim.play(data.v, rng:NextNumber() < 0.5 and "HitLight" or "HitLight2")
		end
	end

	-- sons superposés : coup + gros impact + matière + « oof »
	CartoonFX.sound(Sounds.Category[category] or "Punch", pos, 0.9 + power * 0.5)
	if heavy then
		CartoonFX.sound("BigImpact", pos, 1.1)
		CartoonFX.sound("AnimeHit", pos, 0.7)
	end
	if data.m and Sounds.MaterialHit[data.m] then
		CartoonFX.sound(Sounds.MaterialHit[data.m], pos, 1.0)
	end
	if data.r == "Launch" then
		CartoonFX.sound("Uppercut", pos, 1)
		CartoonFX.sound("Boing", pos, 0.6)
	end
	if rng:NextNumber() < (heavy and 0.6 or 0.2) then
		CartoonFX.sound("Oof", pos, 0.8)
	end

	-- hit-stop : animations gelées pour tout le monde, physique gelée pour le joueur concerné
	local hs = data.ko and CombatConfig.HitStop.KO
		or (heavy and CombatConfig.HitStop.Heavy)
		or CombatConfig.HitStop.Light
	if data.a then
		ProcAnim.freeze(data.a, hs)
	end
	if data.v then
		ProcAnim.freeze(data.v, hs)
	end
	if mine then
		CartoonFX.freezeLocal(hs)
	end

	-- caméra
	local shake = data.ko and CombatConfig.Shake.KO or (heavy and CombatConfig.Shake.Heavy) or CombatConfig.Shake.Light
	local fov = data.ko and CombatConfig.FOVKick.KO or (heavy and CombatConfig.FOVKick.Heavy) or CombatConfig.FOVKick.Light
	if mine then
		CartoonFX.shake(shake)
		CartoonFX.fovKick(fov)
		if heavy then
			CartoonFX.impactFrame(data.ko and 1.3 or 1)
			CartoonFX.speedLines(0.3)
		end
	elseif onScreen(pos) then
		CartoonFX.shake(shake * 0.3)
	end

	if data.ko then
		CartoonFX.ko(data.v, pos, mine)
	end
end

-- K.O. : gel, gros mot, cloche, sifflet de glissade, puis étoile qui scintille là où il a atterri
function CartoonFX.ko(victim: Model?, pos: Vector3, mine: boolean?)
	task.delay(0.05, function()
		CartoonFX.word(pos + Vector3.new(0, 1.5, 0), "K.O.!", 1.3, "KO")
	end)
	CartoonFX.sound("KO", pos, 1)
	CartoonFX.sound("BigImpact", pos, 1.2)
	task.delay(CombatConfig.HitStop.KO, function()
		CartoonFX.sound("SlideWhistle", pos, 1)
	end)
	CartoonFX.shards(pos, 18, nil, 1.4)
	CartoonFX.shockwave(pos, 14, Color3.fromRGB(255, 80, 80))
	if mine then
		CartoonFX.speedLines(0.6, Color3.fromRGB(255, 255, 255))
	end
	if victim then
		task.delay(1.1, function()
			local torso = victim:FindFirstChild("Torso") or victim:FindFirstChild("HumanoidRootPart")
			if torso and torso.Parent then
				CartoonFX.twinkle(torso.Position)
			end
		end)
	end
end

-- Objet (ou décor) qui casse
function CartoonFX.breakItem(pos: Vector3, material: string?)
	local list = Words.Break
	CartoonFX.word(pos, list[rng:NextInteger(1, #list)], 0.75, "Break")
	CartoonFX.sound(Sounds.MaterialBreak[material or ""] or "Crash", pos, 1.1)
	if material == "Glass" then
		CartoonFX.sound("GlassBreak", pos, 1)
	end
	CartoonFX.puff(pos, 0.9)
	CartoonFX.shards(pos, 12)
	CartoonFX.sparks(pos, 10, Color3.new(1, 1, 1))
end

------------------------------------------------------------------------
-- Mécaniques de combat
------------------------------------------------------------------------
function CartoonFX.parry(data)
	CartoonFX.word(data.p, "PARRY!", 1.25, "Parry")
	if data.a and data.a:FindFirstChild("Head") then
		CartoonFX.word(data.a.Head.Position + Vector3.new(0, 2, 0), "STUNNED!", 0.9, "Funny")
	end
	CartoonFX.sound("Parry", data.p, 1.2)
	CartoonFX.sound("Clang", data.p, 1)
	CartoonFX.sparks(data.p, 30, Color3.fromRGB(150, 220, 255))
	CartoonFX.shockwave(data.p, 9, Color3.fromRGB(150, 220, 255))
	CartoonFX.flash(data.v, 0.15)
	if data.a then
		ProcAnim.play(data.a, "HitHeavy")
		CartoonFX.dizzy(data.a, 1.1)
	end
	if involvesLocal(data.a) or involvesLocal(data.v) then
		CartoonFX.freezeLocal(0.12)
		CartoonFX.impactFrame(1)
		CartoonFX.fovKick(7)
		CartoonFX.shake(0.6)
		CartoonFX.speedLines(0.35, Color3.fromRGB(170, 230, 255))
	end
end

function CartoonFX.pinned(data)
	CartoonFX.bigImpact(data.p + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.35, Color3.fromRGB(255, 220, 80))
	CartoonFX.word(data.p + Vector3.new(0, 3, 0), "PINNED!", 1.2, "Heavy")
	CartoonFX.sound("GroundSlam", data.p, 1.3)
	CartoonFX.sound("BigImpact", data.p, 1.2)
	if data.v then
		CartoonFX.dizzy(data.v, 1.4)
	end
	if involvesLocal(data.a) or involvesLocal(data.v) then
		CartoonFX.freezeLocal(0.12)
		CartoonFX.impactFrame(1.2)
		CartoonFX.shake(1.3)
		CartoonFX.fovKick(10)
		CartoonFX.speedLines(0.4)
	end
end

function CartoonFX.block(data)
	CartoonFX.word(data.p, "BLOCK!", 0.25, "Parry")
	CartoonFX.sound("Block", data.p, 1)
	CartoonFX.sparks(data.p, 8, Color3.fromRGB(200, 220, 255))
	if involvesLocal(data.v) then
		CartoonFX.shake(0.2)
	end
end

function CartoonFX.guardBreak(data)
	CartoonFX.word(data.p, "GUARD BREAK!", 1.1, "KO")
	CartoonFX.sound("GlassBreak", data.p, 1.1)
	CartoonFX.shards(data.p, 14, { Color3.fromRGB(150, 220, 255), Color3.new(1, 1, 1) })
	if data.v then
		CartoonFX.dizzy(data.v, 1.5)
	end
	if involvesLocal(data.a) or involvesLocal(data.v) then
		CartoonFX.impactFrame(1)
		CartoonFX.shake(0.7)
	end
end

function CartoonFX.wallSplat(data)
	CartoonFX.bigImpact(data.p, data.n and -data.n or nil, 1.1)
	CartoonFX.word(data.p, rng:NextNumber() < 0.5 and "SPLAT!" or "CRASH!", 1.1, "Heavy")
	CartoonFX.sound("WallSplat", data.p, 1.2)
	CartoonFX.sound("BigImpact", data.p, 1)
	CartoonFX.shockwave(data.p, 7)
	CartoonFX.shards(data.p, 16, { Color3.fromRGB(200, 200, 210), Color3.fromRGB(255, 255, 255) }, 1.2)
	CartoonFX.puff(data.p, 1.2)
	if data.d then
		CartoonFX.damageNumber(data.p, data.d, 0.8)
	end
	if data.v then
		CartoonFX.dizzy(data.v, 1)
	end
	if involvesLocal(data.a) or involvesLocal(data.v) then
		CartoonFX.shake(0.9)
		CartoonFX.impactFrame(0.8)
	end
end

function CartoonFX.slam(data)
	local big = not data.small
	CartoonFX.bigImpact(data.p + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), big and 1.4 or 0.9)
	CartoonFX.word(data.p + Vector3.new(0, 1, 0), big and "KABOOM!" or "THOOM!", big and 1.2 or 0.8, "Heavy")
	CartoonFX.sound("GroundSlam", data.p, 1.2)
	CartoonFX.shockwave(data.p + Vector3.new(0, 0.3, 0), big and 14 or 9)
	CartoonFX.shockwave(data.p + Vector3.new(0, 0.3, 0), big and 9 or 6, Color3.fromRGB(255, 230, 120))
	CartoonFX.puff(data.p, big and 1.8 or 1.2)
	CartoonFX.shards(data.p, big and 20 or 10, { Color3.fromRGB(180, 180, 190), Color3.fromRGB(240, 240, 240) }, 1.3)
	local cam = workspace.CurrentCamera
	if involvesLocal(data.a) or involvesLocal(data.v) then
		CartoonFX.shake(1.1)
		CartoonFX.impactFrame(1)
		CartoonFX.fovKick(8)
	elseif cam and (cam.CFrame.Position - data.p).Magnitude < 50 then
		CartoonFX.shake(0.5)
	end
end

function CartoonFX.breaker(data)
	CartoonFX.word(data.p + Vector3.new(0, 2, 0), "BREAK FREE!", 1.2, "Break")
	CartoonFX.sound("Explosion", data.p, 1.2)
	CartoonFX.shockwave(data.p, 13, Color3.fromRGB(255, 220, 80))
	CartoonFX.puff(data.p, 2)
	CartoonFX.sparks(data.p, 30)
	if involvesLocal(data.a) then
		CartoonFX.shake(0.8)
		CartoonFX.impactFrame(0.8)
	end
end

function CartoonFX.slip(data)
	CartoonFX.word(data.p, "SLIP!", 0.6, "Splat")
	CartoonFX.sound("Slip", data.p, 1)
	CartoonFX.sound("Water", data.p, 0.6)
	if data.v then
		CartoonFX.dizzy(data.v, 1)
	end
end

function CartoonFX.heal(data)
	CartoonFX.word(data.p, data.eat and "NOM!" or "YUM!", 0.4, "Splat")
	CartoonFX.sound(data.eat and "Eat" or "Combo", data.p, 1)
	local att = anchorAt(data.p + Vector3.new(0, 3, 0), 1)
	local bb = billboard(att, 3, 1)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 0.6)
	l.BackgroundTransparency = 1
	l.FontFace = PIXEL
	l.TextScaled = true
	l.Text = "+" .. tostring(math.floor(data.d or 0))
	l.TextColor3 = Color3.fromRGB(90, 255, 120)
	l.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Parent = l
	tween(l, 0.9, { Position = UDim2.fromScale(0, -0.6), TextTransparency = 1 })
end

function CartoonFX.dash(character: Model)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	CartoonFX.puff(root.Position - Vector3.new(0, 2.5, 0), 0.8)
	CartoonFX.sound("Dash", root.Position, 0.9)
	ProcAnim.play(character, "Dash")
end

------------------------------------------------------------------------
-- AIDES VFX DES KITS (ajoutées pour les attaques de personnages ; n'altèrent rien d'autre)
-- slashArc, cracks, debris, light, pillar, trailOn, swirl, implode, airRing, bigTelegraph, casterShake, dust, quake, beam
------------------------------------------------------------------------
function CartoonFX.groundPos(pos: Vector3): Vector3
	local g = groundAt(pos)
	return g
end

-- arc de taillade : cf = repère (le personnage), a0 -> a1 en degrés (0 = devant, + = vers la droite), tilt en degrés (90 = vertical)
function CartoonFX.slashArc(cf: CFrame, radius: number?, color: Color3?, a0: number?, a1: number?, dur: number?, tilt: number?, width: number?)
	radius = radius or 5
	dur = dur or 0.12
	width = width or 0.45
	a0, a1 = a0 or -80, a1 or 80
	local base = cf * CFrame.Angles(0, 0, math.rad(tilt or 0))
	local n = 10
	for i = 0, n do
		local a = math.rad(a0 + (a1 - a0) * i / n)
		task.delay(dur * i / n, function()
			local seg = fxPart({ Size = Vector3.new(radius * 0.4, width, 0.3), CFrame = base * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, -radius), Color = color or Color3.new(1, 1, 1), Transparency = 0.05 })
			local core = fxPart({ Size = Vector3.new(radius * 0.36, width * 0.45, 0.32), CFrame = seg.CFrame, Color = Color3.new(1, 1, 1), Transparency = 0.1 })
			tween(seg, 0.22, { Size = Vector3.new(radius * 0.5, 0.05, 0.08), Transparency = 1 })
			tween(core, 0.14, { Size = Vector3.new(radius * 0.4, 0.04, 0.05), Transparency = 1 })
			Debris:AddItem(seg, 0.24)
			Debris:AddItem(core, 0.16)
		end)
	end
end

-- fissures au sol en étoile (avec branches)
function CartoonFX.cracks(pos: Vector3, count: number?, length: number?, life: number?)
	local g = groundAt(pos)
	count = count or 6
	life = life or 1.4
	local dark = Color3.fromRGB(35, 35, 40)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local len = (length or 5) * rng:NextNumber(0.6, 1.2)
		local c = fxPart({ Size = Vector3.new(rng:NextNumber(0.22, 0.4), 0.07, len), CFrame = CFrame.new(g + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -len / 2 - 0.5), Color = dark })
		local b = fxPart({ Size = Vector3.new(0.16, 0.07, len * 0.5), CFrame = c.CFrame * CFrame.new(0, 0, -len * 0.2) * CFrame.Angles(0, rng:NextNumber(-0.9, 0.9), 0) * CFrame.new(0, 0, -len * 0.25), Color = dark })
		for _, p in ipairs({ c, b }) do
			task.delay(life, function()
				tween(p, 0.5, { Transparency = 1 })
			end)
			Debris:AddItem(p, life + 0.55)
		end
	end
end

-- gros blocs de sol projetés (physique locale)
function CartoonFX.debris(pos: Vector3, count: number?, colors, speed: number?, size: number?)
	colors = colors or { Color3.fromRGB(170, 170, 180), Color3.fromRGB(120, 120, 130) }
	for _ = 1, count or 6 do
		local p = Instance.new("Part")
		p.Size = Vector3.new(rng:NextNumber(0.6, 1.3), rng:NextNumber(0.4, 0.9), rng:NextNumber(0.6, 1.3)) * (size or 1)
		p.CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1), 0.7, rng:NextNumber(-1, 1))) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		p.Color = colors[rng:NextInteger(1, #colors)]
		p.Material = Enum.Material.SmoothPlastic
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CollisionGroup = "Debris"
		p.Parent = workspace.FX
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(1.2, 2.2), rng:NextNumber(-1, 1)).Unit
		p.AssemblyLinearVelocity = dir * rng:NextNumber(20, 36) * (speed or 1)
		p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-15, 15), rng:NextNumber(-15, 15), rng:NextNumber(-15, 15))
		task.delay(1.1, function()
			if p.Parent then
				tween(p, 0.35, { Transparency = 1 })
			end
		end)
		Debris:AddItem(p, 1.5)
	end
end

-- éclair de lumière bref
function CartoonFX.light(pos: Vector3, color: Color3?, range: number?, brightness: number?, dur: number?)
	dur = dur or 0.25
	local att = anchorAt(pos, dur + 0.05)
	local l = Instance.new("PointLight")
	l.Color = color or Color3.new(1, 1, 1)
	l.Range = range or 16
	l.Brightness = brightness or 4
	l.Shadows = false
	l.Parent = att
	tween(l, dur, { Brightness = 0 })
end

-- colonne d'énergie verticale qui se resserre
function CartoonFX.pillar(pos: Vector3, radius: number?, height: number?, color: Color3?, dur: number?)
	radius, height, dur = radius or 2, height or 12, dur or 0.35
	local g = groundAt(pos)
	local p = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 2, radius * 2), CFrame = CFrame.new(g + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = color or Color3.new(1, 1, 1), Transparency = 0.25 })
	tween(p, dur, { Size = Vector3.new(height * 1.25, 0.2, 0.2), Transparency = 1 })
	Debris:AddItem(p, dur + 0.05)
end

-- traînée attachée à une part (bras, accessoire) pendant dur secondes
function CartoonFX.trailOn(part: BasePart?, color: Color3?, dur: number?, offset: number?, width: number?)
	if not part then
		return
	end
	dur = dur or 0.5
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, -(offset or 0.6), 0)
	a1.Position = Vector3.new(0, -(offset or 0.6) - (width or 1.1), 0)
	a0.Parent, a1.Parent = part, part
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.2
	tr.Color = ColorSequence.new(color or Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	tr.Transparency = NumberSequence.new(0.1, 1)
	tr.WidthScale = NumberSequence.new(1, 0.15)
	tr.LightEmission = 0.5
	tr.Parent = part
	Debris:AddItem(tr, dur)
	Debris:AddItem(a0, dur + 0.25)
	Debris:AddItem(a1, dur + 0.25)
end

-- tourbillon de petites parts qui montent en spirale
function CartoonFX.swirl(pos: Vector3, radius: number?, height: number?, colors, count: number?, dur: number?)
	radius, count, dur = radius or 3, count or 12, dur or 0.5
	colors = colors or { Color3.new(1, 1, 1) }
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		local p = fxPart({ Size = Vector3.one * rng:NextNumber(0.35, 0.7), CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)), Color = colors[rng:NextInteger(1, #colors)] })
		local a2 = a + 2.4
		tween(p, dur, { CFrame = CFrame.new(pos + Vector3.new(math.cos(a2) * radius * 0.3, height or 5, math.sin(a2) * radius * 0.3)) * CFrame.Angles(2, 2, 0), Transparency = 1, Size = Vector3.one * 0.15 })
		Debris:AddItem(p, dur + 0.05)
	end
end

-- implosion : traits aspirés vers un point (charge d'énergie)
function CartoonFX.implode(pos: Vector3, radius: number?, colors, count: number?, dur: number?)
	radius, count, dur = radius or 6, count or 10, dur or 0.25
	colors = colors or { Color3.new(1, 1, 1) }
	for _ = 1, count do
		local off = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 1), rng:NextNumber(-1, 1)).Unit * radius
		local p = fxPart({ Size = Vector3.new(0.18, 0.18, rng:NextNumber(1, 2.2)), CFrame = CFrame.lookAt(pos + off, pos), Color = colors[rng:NextInteger(1, #colors)], Transparency = 0.1 })
		tween(p, dur, { CFrame = CFrame.lookAt(pos + off * 0.1, pos), Size = Vector3.new(0.08, 0.08, 0.4), Transparency = 0.7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(p, dur + 0.02)
	end
end

-- anneau d'air orienté (coup qui part dans une direction)
function CartoonFX.airRing(pos: Vector3, dir: Vector3, size: number?, color: Color3?, dur: number?)
	if not dir or dir.Magnitude < 0.05 then
		return
	end
	dir = dir.Unit
	dur = dur or 0.25
	local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 1.5, 1.5), CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi / 2, 0), Color = color or Color3.new(1, 1, 1), Transparency = 0.15 })
	tween(ring, dur, { Size = Vector3.new(0.08, size or 8, size or 8), Transparency = 1, CFrame = ring.CFrame + dir * 2.5 })
	Debris:AddItem(ring, dur + 0.03)
end

-- grande alerte au sol : disque, bord, anneau blanc qui se resserre jusqu'à l'impact
function CartoonFX.bigTelegraph(pos: Vector3, radius: number, dur: number, color: Color3?)
	color = color or Color3.fromRGB(255, 70, 60)
	local UP = CFrame.Angles(0, 0, math.pi / 2)
	local disc = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, radius * 2, radius * 2), CFrame = CFrame.new(pos + Vector3.new(0, 0.09, 0)) * UP, Color = color, Transparency = 0.75 })
	local edge = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, radius * 2 + 0.7, radius * 2 + 0.7), CFrame = CFrame.new(pos + Vector3.new(0, 0.06, 0)) * UP, Color = color, Transparency = 0.3 })
	local inner = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, radius * 2.4, radius * 2.4), CFrame = CFrame.new(pos + Vector3.new(0, 0.11, 0)) * UP, Color = Color3.new(1, 1, 1), Transparency = 0.65 })
	tween(disc, dur, { Transparency = 0.4 })
	tween(inner, dur, { Size = Vector3.new(0.12, 0.3, 0.3), Transparency = 0.25 }, Enum.EasingStyle.Linear)
	task.delay(dur, function()
		tween(disc, 0.2, { Transparency = 1 })
		tween(edge, 0.2, { Transparency = 1 })
		inner:Destroy()
	end)
	Debris:AddItem(disc, dur + 0.25)
	Debris:AddItem(edge, dur + 0.25)
	Debris:AddItem(inner, dur + 0.05)
end

-- secousse : forte si c'est le joueur local, légère s'il est proche
function CartoonFX.casterShake(character: Model?, amount: number)
	if involvesLocal(character) then
		CartoonFX.shake(amount)
		CartoonFX.fovKick(amount * 6)
	else
		local r = character and character:FindFirstChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera
		if r and cam and (cam.CFrame.Position - r.Position).Magnitude < 45 then
			CartoonFX.shake(amount * 0.35)
		end
	end
end

-- poussière au sol qui part en anneau
function CartoonFX.dust(pos: Vector3, radius: number?, color: Color3?, count: number?)
	local g = groundAt(pos)
	count = count or 10
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local d = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(1, 1.8), Position = g + out + Vector3.new(0, 0.5, 0), Color = color or Color3.fromRGB(225, 220, 210), Transparency = 0.25 })
		tween(d, 0.5, { Position = g + out * (radius or 6) + Vector3.new(0, rng:NextNumber(0.4, 1.4), 0), Size = d.Size * 2, Transparency = 1 })
		Debris:AddItem(d, 0.55)
	end
end

-- TREMBLEMENT DE TERRE : gros impact au sol complet (onde de choc, fissures, débris, poussière, lumière)
function CartoonFX.quake(pos: Vector3, radius: number?, color: Color3?, power: number?)
	radius, power = radius or 10, power or 1
	color = color or Color3.new(1, 1, 1)
	local g = groundAt(pos)
	CartoonFX.bigImpact(g + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.2 * power, color)
	CartoonFX.shockwave(g + Vector3.new(0, 0.25, 0), radius, color)
	task.delay(0.08, function()
		CartoonFX.shockwave(g + Vector3.new(0, 0.3, 0), radius * 1.35, Color3.new(1, 1, 1))
	end)
	CartoonFX.cracks(g, 8, radius * 0.45)
	CartoonFX.debris(g, math.floor(5 * power + 1), nil, power)
	CartoonFX.dust(g, radius * 0.8, nil, 12)
	CartoonFX.light(g + Vector3.new(0, 2, 0), color, radius * 2.2, 5, 0.3)
end

-- rayon entre deux points (laser, jet d'eau, câble…)
function CartoonFX.beam(from: Vector3, to: Vector3, width: number?, color: Color3?, dur: number?)
	local len = (to - from).Magnitude
	if len < 0.1 then
		return nil
	end
	local p = fxPart({ Size = Vector3.new(width or 0.6, width or 0.6, len), CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2), Color = color or Color3.new(1, 1, 1), Transparency = 0.1 })
	tween(p, dur or 0.2, { Size = Vector3.new(0.05, 0.05, len), Transparency = 1 })
	Debris:AddItem(p, (dur or 0.2) + 0.03)
	return p
end

return CartoonFX
