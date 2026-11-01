--[[
	HUDController — interface de jeu (anglais, cartoon, lisible sur téléphone).
	PV, jauge OVERTIME, XP/grade, icônes d'attaques + recharges (PC), étage + minuteur de phase,
	kill feed (+ titre de carrière), bannières, toasts, compteur de combo, écran « YOU'RE FIRED! ».
	Panneaux (dans le dock unique MetaDockController, un seul ouvert à la fois via le registre UIKit) :
		"TasksPanel" (tâches du jour + contrats de la semaine, relance gratuite), "CombosPanel", "ShopPanel" (boutique honnête).
	Couleurs : jetons UITheme.HUD (local C) et UITheme.Colors ; pas de Color3 en dur hors cas particuliers.
	Niveau : pastille LV sur le portrait, jauge XP = progression vers le niveau suivant (attributs Level / LevelXP /
	LevelNeed), popup « LEVEL UP! » + son (remote LevelUp {level, from, cash, grade}).

	API pour les autres contrôleurs :
		HUD.bindCooldown(frame, key)  key = "1"|"2"|"3"|"Dash"|"DashStrike"|"Evasive" (lit CD<key> / CDMax<key> sur le perso)
		HUD.toast(text, color?, duration?)
		HUD.banner({text, sub, color, duration, style})
		HUD.addMenuButton(text, color, callback, order) -> bouton   (délégué à MetaDock.addButton)
		HUD.attackName(id) -> nom affiché
		HUD.currentKit() -> fiche du perso (Config/Characters), nom
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local UIKit = require(script.Parent.UIKit)
local C = UIKit.Theme.HUD -- jetons de couleur du HUD (UITheme.HUD)
local Config = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config")
local Characters = require(Config.Characters)
local Grades = require(Config.Grades)
local Shop = require(Config.Shop)
local CombatConfig = require(Config.Combat)
-- icônes d'attaque illustrées (une par attaque / ultime / action) ; repli = icônes génériques UIKit.icon
local AttackIcon
do
	local m = ReplicatedStorage.Shared.Modules:FindFirstChild("AttackIcon")
	local ok, mod = false, nil
	if m then
		ok, mod = pcall(require, m)
	end
	AttackIcon = ok and type(mod) == "table" and mod or nil
end

local HUD = {}
HUD.Priority = 40

local player = Players.LocalPlayer
local gui
local refs = {}
local cooldownBinds = {}
local bannerQueue, bannerBusy = {}, false
local likeShown, otTipShown = false, false
local lastKiller = nil

local function now()
	return workspace:GetServerTimeNow()
end

local function myChar()
	return player.Character
end

------------------------------------------------------------------------
-- Données
------------------------------------------------------------------------
local attacksCfg
local function getAttacks()
	if attacksCfg == nil then
		local m = Config:FindFirstChild("Attacks")
		if m then
			local ok, mod = pcall(require, m)
			attacksCfg = ok and mod or false
		end
	end
	return attacksCfg or nil
end

function HUD.attackName(id)
	local A = getAttacks()
	if A and type(A[id]) == "table" and A[id].Name then
		return A[id].Name
	end
	return UIKit.pretty(id)
end

function HUD.currentKit()
	local c = myChar()
	local name = c and c:GetAttribute("CharacterName") or nil
	return name and Characters[name] or nil, name
end

local function charColor(charName)
	local kit = charName and Characters[charName]
	return kit and kit.Color or C.Silver
end

------------------------------------------------------------------------
-- Petits outils visuels (dégradés, fondu, éclat « prêt », étincelles)
------------------------------------------------------------------------
local function grad(obj, c0, c1, rot)
	return UIKit.new("UIGradient", { Rotation = rot or 90, Color = ColorSequence.new(c0, c1), Parent = obj })
end

-- fondu de tout un groupe d'objets puis destruction
local function fadeOut(root, t)
	t = t or 0.3
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in ipairs(list) do
		if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
			UIKit.tween(d, t, { BackgroundTransparency = 1 })
		end
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			UIKit.tween(d, t, { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then
			UIKit.tween(d, t, { Transparency = 1 })
		end
	end
	task.delay(t, function()
		root:Destroy()
	end)
end

-- anneau qui s'élargit + petit rebond quand une attaque redevient prête
local function readyBurst(frame)
	local ring = UIKit.new("Frame", {
		Name = "ReadyRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = frame.ZIndex + 7,
		Parent = frame,
	})
	local fc = frame:FindFirstChildOfClass("UICorner")
	if fc then
		UIKit.corner(ring, fc.CornerRadius)
	end
	local s = UIKit.stroke(ring, 4, C.Glow, true)
	UIKit.tween(ring, 0.35, { Size = UDim2.new(1, 24, 1, 24) }, Enum.EasingStyle.Quad)
	UIKit.tween(s, 0.35, { Transparency = 1, Thickness = 1 })
	task.delay(0.36, function()
		ring:Destroy()
	end)
	local sc = frame:FindFirstChild("SlotScale")
	if sc then
		sc.Scale = 1.14
		UIKit.tween(sc, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end
end

-- étincelle carrée qui jaillit d'un conteneur (jauge pleine, ultime prête)
local function spark(container, color)
	if not container or not container.Parent then
		return
	end
	local s = UIKit.new("Frame", {
		BackgroundColor3 = color or UIKit.Colors.Yellow,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(math.random(), 0, 0.5, math.random(-8, 8)),
		Size = UDim2.fromOffset(6, 6),
		Rotation = 45,
		ZIndex = 9,
		Parent = container,
	})
	local dx, dy = math.random(-34, 34), math.random(-52, -20)
	UIKit.tween(s, 0.55, {
		Position = s.Position + UDim2.fromOffset(dx, dy),
		Size = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		Rotation = 45 + math.random(-120, 120),
	}, Enum.EasingStyle.Quad)
	task.delay(0.56, function()
		s:Destroy()
	end)
end

------------------------------------------------------------------------
-- Recharges (overlay qui se vide, forme conservée grâce à un UIGradient)
------------------------------------------------------------------------
function HUD.bindCooldown(frame: GuiObject, key: string)
	local fc = frame:FindFirstChildOfClass("UICorner")
	local round = fc ~= nil and fc.CornerRadius.Scale >= 0.5
	local z = frame.ZIndex + 4
	local holder = UIKit.new("Frame", {
		Name = "Cooldown",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
		Visible = false,
		Parent = frame,
	})
	-- balayage façon horloge : deux moitiés découpées ; dans chacune, un disque dont la moitié opaque tourne (UIGradient)
	local grads = {}
	for _, side in ipairs({ "R", "L" }) do
		local clip = UIKit.new("Frame", {
			Name = "Half" .. side,
			BackgroundTransparency = 1,
			ClipsDescendants = true,
			Position = UDim2.fromScale(side == "R" and 0.5 or 0, 0),
			Size = UDim2.fromScale(0.5, 1),
			ZIndex = z,
			Parent = holder,
		})
		local disk = UIKit.new("Frame", {
			Name = "Disk",
			BackgroundColor3 = UIKit.Colors.Shadow,
			BackgroundTransparency = 0.28,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(side == "R" and -1 or 0, 0),
			Size = UDim2.fromScale(2, 1),
			ZIndex = z,
			Parent = clip,
		})
		if round then
			UIKit.corner(disk, UDim.new(0.5, 0))
		elseif fc then
			UIKit.corner(disk, fc.CornerRadius)
		end
		grads[side] = UIKit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.499, 1),
				NumberSequenceKeypoint.new(0.5, 0),
				NumberSequenceKeypoint.new(1, 0),
			}),
			Parent = disk,
		})
	end
	local txt = UIKit.label({
		Name = "CDText",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromScale(0.62, 0.36),
		ZIndex = z + 1,
		Stroke = 3,
		TextColor3 = UIKit.Colors.Yellow,
	})
	txt.Parent = frame
	-- éclair blanc quand l'attaque redevient prête
	local flash = UIKit.new("Frame", {
		Name = "ReadyFlash",
		BackgroundColor3 = UIKit.White,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z + 2,
		Parent = frame,
	})
	if fc then
		UIKit.corner(flash, fc.CornerRadius)
	end
	table.insert(cooldownBinds, { overlay = holder, R = grads.R, L = grads.L, txt = txt, key = key, flash = flash, frame = frame, active = false })
end

local function updateCooldowns()
	local c = myChar()
	local t = now()
	for i = #cooldownBinds, 1, -1 do
		local b = cooldownBinds[i]
		if not b.overlay.Parent then
			table.remove(cooldownBinds, i)
			continue
		end
		local ready = c and c:GetAttribute("CD" .. b.key) or 0
		local max = c and c:GetAttribute("CDMax" .. b.key) or 1
		local rem = ready - t
		if rem <= 0 or max <= 0 then
			b.overlay.Visible = false
			b.txt.Text = ""
			if b.active then
				b.active = false
				b.flash.BackgroundTransparency = 0.15
				UIKit.tween(b.flash, 0.35, { BackgroundTransparency = 1 })
				readyBurst(b.frame)
			end
		else
			b.active = true
			local e = 1 - math.clamp(rem / max, 0, 1)
			local a = e * 360
			b.overlay.Visible = true
			b.R.Rotation = math.min(a, 180)
			b.L.Rotation = math.max(a, 180)
			b.txt.Text = rem >= 1 and tostring(math.ceil(rem)) or string.format("%.1f", rem)
		end
	end
end

------------------------------------------------------------------------
-- Toasts
------------------------------------------------------------------------
function HUD.toast(text: string, color: Color3?, duration: number?)
	if not refs.toasts then
		return
	end
	local list = refs.toasts:GetChildren()
	local count = 0
	for _, t in ipairs(list) do
		if t:IsA("Frame") then
			count += 1
		end
	end
	if count >= 4 then
		for _, t in ipairs(list) do
			if t:IsA("Frame") then
				t:Destroy()
				break
			end
		end
	end
	local accent = color or UIKit.Colors.Yellow
	local pill = UIKit.new("Frame", {
		BackgroundColor3 = UIKit.Colors.PanelDark,
		BackgroundTransparency = 0.04,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		LayoutOrder = math.floor(os.clock() * 100),
		Parent = refs.toasts,
	})
	UIKit.corner(pill, UDim.new(0, 6))
	UIKit.stroke(pill, 3, UIKit.Black, true)
	grad(pill, UIKit.White, C.Steel)
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 46), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10), Parent = pill })
	-- médaillon « ! » coloré à gauche
	local badge = UIKit.new("Frame", { Name = "Accent", AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = accent, Position = UDim2.new(0, -38, 0.5, 0), Size = UDim2.fromOffset(28, 28), Parent = pill })
	UIKit.corner(badge, UDim.new(0, 5))
	UIKit.stroke(badge, 2, UIKit.Black, true)
	UIKit.Theme.bevel(badge, 0.62, 0.72)
	local bl = UIKit.label({ Text = "!", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.52, 0.48), Size = UDim2.fromScale(0.6, 0.6), Stroke = 2 })
	bl.Parent = badge
	local l = UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = UIKit.Body,
		TextSize = 17,
		TextWrapped = true,
		Text = text,
		TextColor3 = UIKit.White,
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		Parent = pill,
	})
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(560, 200), Parent = l })
	UIKit.stroke(l, 2)
	-- liseré de couleur sous le texte
	UIKit.new("Frame", { Name = "Underline", AnchorPoint = Vector2.new(0, 1), BackgroundColor3 = accent, BorderSizePixel = 0, Position = UDim2.new(0, -46, 1, 10), Size = UDim2.new(1, 62, 0, 3), Parent = pill })
	UIKit.pop(pill, 1.14)
	UIKit.Theme.wobble(badge, 10, 0)
	task.delay(duration or 3.5, function()
		if pill.Parent then
			fadeOut(pill, 0.3)
		end
	end)
end

------------------------------------------------------------------------
-- Bannières
------------------------------------------------------------------------
local BANNER_COLORS = {
	Event = C.Gold,
	Floor = UIKit.Colors.Red,
	Overtime = UIKit.Colors.Orange,
	Big = UIKit.White,
}

local function showBanner(data)
	bannerBusy = true
	local style = data.style or "Event"
	local big = style == "Big" or style == "Overtime"
	local root = refs.banner
	root:ClearAllChildren()
	local color = data.color or BANNER_COLORS[style] or BANNER_COLORS.Event
	local W, H = big and 760 or 640, big and 112 or 88
	local ribbon, face
	if style == "Big" then
		ribbon = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(W, H),
			BackgroundTransparency = 1,
			Rotation = -2,
			Parent = root,
		})
	else
		ribbon, face = UIKit.Theme.shadowed({
			Name = "Ribbon",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.fromOffset(W, H),
			Rotation = -2,
			Color = color,
			StrokeThickness = 4,
			Corner = 4,
			Parent = root,
		}, 7)
		UIKit.Theme.bevel(face, 0.8, 0.72)
		UIKit.Theme.shine(face)
		-- guirlande de petites lampes carrées (haut et bas) qui clignotent
		local lights = {}
		local n = math.floor(W / 26)
		for i = 0, n - 1 do
			for _, y in ipairs({ 6, H - 12 }) do
				local lamp = UIKit.new("Frame", {
					BackgroundColor3 = UIKit.White,
					BackgroundTransparency = 0.25,
					BorderSizePixel = 0,
					Position = UDim2.fromOffset(13 + i * 26 - 3, y),
					Size = UDim2.fromOffset(6, 6),
					ZIndex = 2,
					Parent = face,
				})
				table.insert(lights, { f = lamp, odd = (i % 2 == 1) })
			end
		end
		task.spawn(function()
			local k = 0
			while face.Parent do
				k += 1
				for _, L in ipairs(lights) do
					L.f.BackgroundTransparency = ((k % 2 == 0) == L.odd) and 0.1 or 0.75
				end
				task.wait(0.18)
			end
		end)
		-- chevrons pixel de chaque côté
		for _, sx in ipairs({ -1, 1 }) do
			local chev = UIKit.label({
				Text = sx < 0 and ">>" or "<<",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(sx < 0 and 0 or 1, sx * 46, 0.5, 0),
				Size = UDim2.fromOffset(64, math.floor(H * 0.42)),
				TextColor3 = color,
				Stroke = 3,
				ZIndex = 3,
			})
			chev.Parent = ribbon
			task.spawn(function()
				while chev.Parent do
					UIKit.tween(chev, 0.25, { Position = UDim2.new(sx < 0 and 0 or 1, sx * 38, 0.5, 0) })
					task.wait(0.25)
					UIKit.tween(chev, 0.25, { Position = UDim2.new(sx < 0 and 0 or 1, sx * 50, 0.5, 0) })
					task.wait(0.25)
				end
			end)
		end
	end
	local title = UIKit.label({
		Text = string.upper(data.text or ""),
		Size = UDim2.new(0.86, 0, data.sub and 0.42 or 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, data.sub and 0.17 or 0.24),
		TextColor3 = UIKit.White,
		Stroke = style == "Big" and 5 or 4,
		ZIndex = 4,
	})
	title.Parent = ribbon
	UIKit.new("UIGradient", {
		Rotation = 90,
		Color = style == "Big" and ColorSequence.new(UIKit.Theme.lighten(color, 0.55), color)
			or ColorSequence.new(UIKit.White, C.Cream),
		Parent = title,
	})
	if data.sub then
		local sub = UIKit.label({
			Text = data.sub,
			Font = UIKit.Body,
			Size = UDim2.fromScale(0.8, 0.22),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.63),
			Stroke = 2,
			ZIndex = 4,
		})
		sub.Parent = ribbon
	end
	-- entrée : glisse depuis la gauche + pop, petite secousse
	ribbon.Position = UDim2.new(0.5, -900, 0, 0)
	UIKit.tween(ribbon, 0.32, { Position = UDim2.fromScale(0.5, 0) }, Enum.EasingStyle.Back)
	local scale = UIKit.pop(ribbon, 1.18)
	task.delay(0.3, function()
		UIKit.Theme.wobble(ribbon, 3, -2)
	end)
	UIKit.Theme.click(0.35)
	task.wait(data.duration or 3)
	UIKit.tween(ribbon, 0.22, { Position = UDim2.new(0.5, 900, 0, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	UIKit.tween(scale, 0.22, { Scale = 0.6 * (scale:GetAttribute("Base") or 1) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.24)
	ribbon:Destroy()
	bannerBusy = false
	local nextData = table.remove(bannerQueue, 1)
	if nextData then
		task.spawn(showBanner, nextData)
	end
end

function HUD.banner(data)
	if type(data) ~= "table" or not refs.banner then
		return
	end
	if bannerBusy then
		if #bannerQueue < 3 then
			table.insert(bannerQueue, data)
		end
	else
		task.spawn(showBanner, data)
	end
end

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------
local function bar(parent, name, pos, size, color, label)
	local back = UIKit.new("Frame", {
		Name = name,
		Position = pos,
		Size = size,
		BackgroundColor3 = UIKit.Colors.Shadow,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = parent,
	})
	UIKit.corner(back, UDim.new(0, 4))
	UIKit.stroke(back, 3, UIKit.Black, true)
	-- segment « PV perdus » (clair) qui attend puis se vide
	local trail = UIKit.new("Frame", { Name = "Trail", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Peach, BorderSizePixel = 0, ZIndex = 2, Parent = back })
	UIKit.corner(trail, UDim.new(0, 4))
	local fill = UIKit.new("Frame", { Name = "Fill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 3, Parent = back })
	UIKit.corner(fill, UDim.new(0, 4))
	UIKit.Theme.bevel(fill, 0.6, 0.7)
	UIKit.new("Frame", { Name = "Shine", BackgroundColor3 = UIKit.White, BackgroundTransparency = 0.5, BorderSizePixel = 0, Position = UDim2.new(0, 3, 0, 3), Size = UDim2.new(1, -6, 0, 3), ZIndex = 3, Parent = fill })
	-- bord lumineux au bout de la jauge
	UIKit.new("Frame", { Name = "Edge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 3, 1, 0), BackgroundColor3 = UIKit.White, BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 3, Parent = fill })
	-- creux sombre en haut (profondeur)
	UIKit.new("Frame", { Name = "Well", BackgroundColor3 = UIKit.Colors.Black, BackgroundTransparency = 0.55, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 2), ZIndex = 4, Parent = back })
	local ticks = UIKit.new("Frame", { Name = "Ticks", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = back })
	for i = 1, 9 do
		UIKit.new("Frame", { BackgroundColor3 = UIKit.Colors.Shadow, BackgroundTransparency = 0.62, BorderSizePixel = 0, Position = UDim2.new(i / 10, -1, 0, 0), Size = UDim2.new(0, 2, 1, 0), ZIndex = 4, Parent = ticks })
	end
	local flash = UIKit.new("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = UIKit.White, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5, Parent = back })
	UIKit.corner(flash, UDim.new(0, 4))
	local text = UIKit.label({ Name = "Text", Text = label or "", Size = UDim2.new(1, -16, 0.6, 0), Position = UDim2.new(0, 8, 0.2, 0), ZIndex = 6, Stroke = 2, TextXAlignment = Enum.TextXAlignment.Left })
	text.Parent = back
	return back
end

-- portrait 3D du perso (copie figée dans un ViewportFrame)
local PORTRAIT_STRIP = {
	Script = true, LocalScript = true, ModuleScript = true, Sound = true, ParticleEmitter = true, Trail = true, Beam = true,
	PointLight = true, SpotLight = true, SurfaceLight = true, BillboardGui = true, Highlight = true, ForceField = true,
	Fire = true, Smoke = true, Sparkles = true, ProximityPrompt = true,
}
local function refreshPortrait()
	local c = myChar()
	local vp = refs.portrait
	if not vp or not c or not c.Parent then
		return
	end
	local head = c:FindFirstChild("Head")
	if not head then
		return
	end
	local was = c.Archivable
	c.Archivable = true
	local ok, clone = pcall(function()
		return c:Clone()
	end)
	c.Archivable = was
	if not ok or not clone then
		return
	end
	for _, d in ipairs(clone:GetDescendants()) do
		if PORTRAIT_STRIP[d.ClassName] then
			d:Destroy()
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	for _, ch in ipairs(vp:GetChildren()) do
		if not ch:IsA("Camera") then
			ch:Destroy()
		end
	end
	local h = clone:FindFirstChild("Head") or head
	local cf = h.CFrame
	refs.portraitCam.CFrame = CFrame.lookAt((cf * CFrame.new(0.9, 0.25, -3.7)).Position, cf.Position - Vector3.new(0, 0.25, 0))
	clone.Parent = vp
end

local function buildPortrait(parent)
	local box = UIKit.new("Frame", { Name = "PortraitBox", Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(86, 86), BackgroundColor3 = UIKit.Colors.PanelLight, ZIndex = 2, Parent = parent })
	UIKit.corner(box, UDim.new(0, 6))
	refs.portraitStroke = UIKit.stroke(box, 3, UIKit.Black, true)
	grad(box, UIKit.White, C.Dusk)
	-- rayons de fond (look « carte de joueur »)
	for i = 0, 3 do
		UIKit.new("Frame", { BackgroundColor3 = UIKit.White, BackgroundTransparency = 0.86, BorderSizePixel = 0, Position = UDim2.new(0, 6 + i * 22, 0, 0), Size = UDim2.new(0, 9, 1, 0), ZIndex = 2, Parent = box })
	end
	local vp = UIKit.new("ViewportFrame", {
		Name = "Portrait",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 3,
		Ambient = C.Silver,
		LightColor = UIKit.White,
		LightDirection = Vector3.new(-0.6, -1, -0.8),
		Parent = box,
	})
	local cam = Instance.new("Camera")
	cam.FieldOfView = 32
	cam.Parent = vp
	vp.CurrentCamera = cam
	refs.portrait, refs.portraitCam, refs.portraitBox = vp, cam, box
	UIKit.new("Frame", { Name = "Gloss", BackgroundColor3 = UIKit.White, BackgroundTransparency = 0.86, BorderSizePixel = 0, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0.28, 0), ZIndex = 4, Parent = box })
end

-- jauge OVERTIME : dégradé qui défile, lueur + étincelles quand elle est pleine, pastille « PRESS G »
local function buildOvertime(f)
	local glow = UIKit.new("Frame", { Name = "OTGlow", Position = UDim2.new(0, 6, 0, 100), Size = UDim2.new(1, -12, 0, 40), BackgroundColor3 = C.Gold, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1, Parent = f })
	UIKit.corner(glow, UDim.new(0, 9))
	refs.otGlow = glow
	local ot = bar(f, "OT", UDim2.new(0, 50, 0, 105), UDim2.new(1, -62, 0, 30), UIKit.White, "OVERTIME")
	refs.ot = ot
	refs.otStroke = ot:FindFirstChildOfClass("UIStroke")
	ot.Trail.Visible = false
	ot.Ticks.Visible = false
	local bev = ot.Fill:FindFirstChild("Bevel")
	if bev then
		bev:Destroy()
	end
	refs.otFlow = UIKit.new("UIGradient", { Name = "Flow", Rotation = 0, Parent = ot.Fill })
	-- bande sombre en bas de la jauge (relief)
	UIKit.new("Frame", { Name = "Lip", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0.3, 0), BackgroundColor3 = UIKit.Colors.Black, BackgroundTransparency = 0.72, BorderSizePixel = 0, ZIndex = 3, Parent = ot.Fill })
	-- segments (10 crans)
	local segs = UIKit.new("Frame", { Name = "Segments", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4, Parent = ot })
	for i = 1, 9 do
		UIKit.new("Frame", { BackgroundColor3 = UIKit.Colors.Ink, BackgroundTransparency = 0.35, BorderSizePixel = 0, Position = UDim2.new(i / 10, -2, 0, 0), Size = UDim2.new(0, 3, 1, 0), ZIndex = 4, Parent = segs })
	end
	ot.Text.TextXAlignment = Enum.TextXAlignment.Center
	-- médaillon éclair à gauche
	local badge = UIKit.new("Frame", { Name = "OTBadge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 30, 0, 120), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = UIKit.Colors.Orange, ZIndex = 5, Parent = f })
	UIKit.corner(badge, UDim.new(0, 7))
	UIKit.stroke(badge, 3, UIKit.Black, true)
	UIKit.Theme.bevel(badge, 0.62, 0.7)
	local ib = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.78, 0.78), BackgroundTransparency = 1, ZIndex = 6, Parent = badge })
	UIKit.icon("Bolt", ib, C.Glow, 6)
	refs.otBadge = badge
	refs.otSparks = UIKit.new("Frame", { Name = "OTSparks", BackgroundTransparency = 1, Position = UDim2.new(0, 50, 0, 105), Size = UDim2.new(1, -62, 0, 30), ZIndex = 9, Parent = f })
	-- pastille « PRESS G » qui dépasse à droite de la carte
	local prompt = UIKit.new("Frame", { Name = "OTPrompt", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 10, 0, 120), Size = UDim2.fromOffset(118, 38), BackgroundColor3 = C.Gold, Visible = false, ZIndex = 8, Parent = f })
	UIKit.corner(prompt, UDim.new(0, 6))
	UIKit.stroke(prompt, 3, UIKit.Black, true)
	UIKit.Theme.bevel(prompt, 0.7, 0.72)
	-- « PRESS [G] » (téléphone : « TAP [OT] »)
	local kw = UIKit.isTouch() and 36 or 28
	UIKit.Theme.keycap({ Text = UIKit.isTouch() and "OT" or "G", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(kw, 28), ZIndex = 9, Parent = prompt })
	local pl = UIKit.label({ Text = UIKit.isTouch() and "TAP" or "PRESS", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, 0), Size = UDim2.new(1, -(kw + 20), 0.44, 0), TextColor3 = UIKit.Colors.White, Stroke = 2.5, ZIndex = 9 })
	pl.Parent = prompt
	refs.otPrompt = prompt
	refs.otPromptScale = UIKit.new("UIScale", { Parent = prompt })
	-- ruban de l'ultime sous la carte : [G] NOM DE L'ULTIME !
	local tag = UIKit.new("Frame", { Name = "UltTag", Position = UDim2.new(0, 10, 1, 8), Size = UDim2.new(1, -20, 0, 32), BackgroundColor3 = C.Fire, Visible = false, ZIndex = 8, Parent = f })
	UIKit.corner(tag, UDim.new(0, 6))
	refs.ultTagStroke = UIKit.stroke(tag, 3, UIKit.Black, true)
	UIKit.Theme.bevel(tag, 0.68, 0.7)
	UIKit.Theme.keycap({ Text = UIKit.isTouch() and "ULT" or "G", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0), Size = UDim2.fromOffset(UIKit.isTouch() and 40 or 26, 24), Color = UIKit.Colors.Yellow, ZIndex = 9, Parent = tag })
	refs.ultTagLabel = UIKit.label({ Text = "ULTIMATE!", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, UIKit.isTouch() and 52 or 38, 0.5, 0), Size = UDim2.new(1, UIKit.isTouch() and -60 or -46, 0.5, 0), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2.5, ZIndex = 9 })
	refs.ultTagLabel.Parent = tag
	refs.ultTag = tag
end

local function buildStatus()
	local f = UIKit.panel({
		Name = "Status",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0, 14, 0, 62),
		Size = UDim2.fromOffset(384, 148),
		Accent = UIKit.Colors.Green,
		Parent = gui,
	})
	UIKit.autoScale(f)
	refs.status = f
	refs.statusStroke = f:FindFirstChildOfClass("UIStroke")
	buildPortrait(f)
	-- pastille de niveau sur le coin du portrait
	local lb = UIKit.new("Frame", { Name = "LevelBadge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(88, 88), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = C.Gold, ZIndex = 7, Parent = f })
	UIKit.corner(lb, UDim.new(0.5, 0))
	UIKit.stroke(lb, 3, UIKit.Black, true)
	grad(lb, UIKit.White, C.Amber)
	local lbt = UIKit.label({ Text = "LV", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.27), Size = UDim2.fromScale(0.5, 0.24), Stroke = 1.5, ZIndex = 8 })
	lbt.Parent = lb
	refs.levelNum = UIKit.label({ Name = "Num", Text = "1", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.63), Size = UDim2.fromScale(0.74, 0.42), Stroke = 2, ZIndex = 8 })
	refs.levelNum.Parent = lb
	refs.levelBadge = lb
	refs.charName = UIKit.label({ Text = "", Size = UDim2.new(1, -236, 0, 20), Position = UDim2.new(0, 110, 0, 13), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2.5, ZIndex = 3 })
	refs.charName.Parent = f
	local chip = UIKit.new("Frame", { Name = "GradeChip", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 11), Size = UDim2.fromOffset(112, 24), BackgroundColor3 = UIKit.Colors.PanelDark, ZIndex = 3, Parent = f })
	UIKit.corner(chip, UDim.new(0, 5))
	refs.gradeStroke = UIKit.stroke(chip, 2, UIKit.Black, true)
	refs.grade = UIKit.label({ Text = "TRAINEE", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -12, 0.58, 0), Stroke = 2, ZIndex = 4 })
	refs.grade.Parent = chip
	refs.hp = bar(f, "HP", UDim2.new(0, 110, 0, 40), UDim2.new(1, -122, 0, 34), C.HP, "100")
	refs.hp.Text.TextXAlignment = Enum.TextXAlignment.Right
	local tag = UIKit.label({ Name = "Tag", Text = "HP", Size = UDim2.new(0, 36, 0.5, 0), Position = UDim2.new(0, 8, 0.25, 0), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2, ZIndex = 6 })
	tag.Parent = refs.hp
	refs.xp = bar(f, "XP", UDim2.new(0, 110, 0, 81), UDim2.new(1, -122, 0, 15), C.XP, "")
	refs.xp.Trail.Visible = false
	refs.xp.Ticks.Visible = false
	refs.xp.Text.TextXAlignment = Enum.TextXAlignment.Right
	refs.xp.Text.Size = UDim2.new(1, -10, 0.72, 0)
	refs.xp.Text.Position = UDim2.new(0, 5, 0.14, 0)
	buildOvertime(f)
	refs.hpShown, refs.trailShown, refs.trailHold, refs.otShown = 1, 1, 0, 0
end

-- vignette rouge sur les bords de l'écran (PV bas / coup reçu)
local function buildVignette()
	local v = UIKit.new("Frame", { Name = "LowHP", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 0, Parent = gui })
	refs.vigEdges = {}
	for _, e in ipairs({ { 0, 0, 1, 0.2, 90 }, { 0, 0.8, 1, 0.2, -90 }, { 0, 0, 0.14, 1, 0 }, { 0.86, 0, 0.14, 1, 180 } }) do
		local f = UIKit.new("Frame", { BackgroundColor3 = C.Vignette, BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromScale(e[1], e[2]), Size = UDim2.fromScale(e[3], e[4]), ZIndex = 0, Parent = v })
		UIKit.new("UIGradient", { Rotation = e[5], Transparency = NumberSequence.new(0, 1), Parent = f })
		table.insert(refs.vigEdges, f)
	end
	refs.vignette = v
end
local function setVignette(a)
	if not refs.vignette then
		return
	end
	refs.vignette.Visible = a > 0.01
	for _, f in ipairs(refs.vigEdges) do
		f.BackgroundTransparency = 1 - a
	end
end

-- grosse invite centrale quand l'ultime est prête : [G] NOM DE L'ULTIME !
local function buildUltPrompt()
	local touch = UIKit.isTouch()
	local p = UIKit.new("Frame", { Name = "UltPrompt", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, touch and -118 or -160), Size = UDim2.fromOffset(540, 70), BackgroundTransparency = 1, Visible = false, ZIndex = 12, Parent = gui })
	UIKit.autoScale(p)
	local ribbon = UIKit.new("Frame", { Name = "Ribbon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = UIKit.Colors.Orange, Rotation = -2, ZIndex = 12, Parent = p })
	UIKit.corner(ribbon, UDim.new(0, 6))
	refs.ultRibbonStroke = UIKit.stroke(ribbon, 4, UIKit.Black, true)
	refs.ultRibbonGrad = UIKit.new("UIGradient", {
		Rotation = 0,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.Steel),
			ColorSequenceKeypoint.new(0.44, C.Silver),
			ColorSequenceKeypoint.new(0.5, UIKit.White),
			ColorSequenceKeypoint.new(0.56, C.Silver),
			ColorSequenceKeypoint.new(1, C.Steel),
		}),
		Parent = ribbon,
	})
	refs.ultPulse = UIKit.new("UIScale", { Name = "Pulse", Parent = ribbon })
	UIKit.new("Frame", { Name = "Shine", BackgroundColor3 = UIKit.White, BackgroundTransparency = 0.6, BorderSizePixel = 0, Position = UDim2.new(0, 6, 0, 5), Size = UDim2.new(1, -12, 0, 4), ZIndex = 13, Parent = ribbon })
	local kw = touch and 64 or 46
	UIKit.Theme.keycap({ Text = touch and "ULT" or "G", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(kw, 42), Color = UIKit.Colors.Yellow, ZIndex = 14, Parent = ribbon })
	refs.ultName = UIKit.label({ Text = "ULTIMATE!", AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, kw + 24, 0, 8), Size = UDim2.new(1, -(kw + 36), 0, 28), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3, ZIndex = 14 })
	grad(refs.ultName, UIKit.White, UIKit.Colors.Yellow)
	refs.ultName.Parent = ribbon
	local sub = UIKit.label({ Text = touch and "ULTIMATE READY - TAP ULT!" or "ULTIMATE READY - PRESS G!", Font = UIKit.Body, Position = UDim2.new(0, kw + 24, 0, 38), Size = UDim2.new(1, -(kw + 36), 0, 13), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Cream, Stroke = 2, ZIndex = 14 })
	sub.Parent = ribbon
	refs.ultRibbon = ribbon
	refs.ultSparks = UIKit.new("Frame", { Name = "Sparks", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 15, Parent = p })
	refs.ultPrompt = p
	-- icône illustrée de l'ultime, à gauche du ruban
	refs.ultIcon = UIKit.new("Frame", { Name = "UltIcon", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0, 4, 0.5, 0), Size = UDim2.fromOffset(80, 80), BackgroundTransparency = 1, ZIndex = 16, Parent = p })
end

local function buildFloor()
	local f = UIKit.panel({
		Name = "Floor",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(360, 92),
		Visible = false,
		Accent = UIKit.Colors.Yellow,
		Parent = gui,
	})
	UIKit.autoScale(f)
	refs.floor = f
	refs.floorStroke = f:FindFirstChildOfClass("UIStroke")
	refs.floorNum = UIKit.label({ Text = "FLOOR 30", Size = UDim2.new(1, -24, 0, 30), Position = UDim2.new(0, 12, 0, 10), TextColor3 = UIKit.Colors.Yellow, Stroke = 3, ZIndex = 2 })
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.Cream, C.Amber), Parent = refs.floorNum })
	refs.floorNum.Parent = f
	refs.floorName = UIKit.label({ Text = "", Font = UIKit.Body, Size = UDim2.new(1, -24, 0, 18), Position = UDim2.new(0, 12, 0, 43), TextColor3 = UIKit.Colors.Muted, Stroke = 2, ZIndex = 2 })
	refs.floorName.Parent = f
	refs.phase = UIKit.label({ Text = "", Font = UIKit.Body, Size = UDim2.new(1, -24, 0, 20), Position = UDim2.new(0, 12, 0, 63), TextColor3 = C.Sky, Stroke = 2, ZIndex = 2 })
	refs.phase.Parent = f
end

local function buildKillFeed()
	local f = UIKit.new("Frame", {
		Name = "KillFeed",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 62),
		Size = UDim2.fromOffset(400, 200),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UIKit.autoScale(f)
	UIKit.new("UIListLayout", {
		Padding = UDim.new(0, 5),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = f,
	})
	refs.feed = f
end

local function addFeed(entry)
	local function name(n, char, id)
		local c = charColor(char)
		if id == player.UserId then
			c = UIKit.Colors.Yellow
		end
		local out = '<font color="' .. UIKit.hex(c) .. '">' .. UIKit.escape(n or "?") .. "</font>"
		-- titre de carrière (attribut Player "Title", TaskService)
		local p = type(id) == "number" and id ~= 0 and Players:GetPlayerByUserId(id) or nil
		local title = p and p:GetAttribute("Title")
		if type(title) == "string" and title ~= "" then
			local tc = p:GetAttribute("TitleColor")
			out ..= ' <font size="12" color="' .. UIKit.hex(typeof(tc) == "Color3" and tc or UIKit.Colors.Muted) .. '">[' .. UIKit.escape(string.upper(title)) .. "]</font>"
		end
		return out
	end
	local left, right, chipText, chipColor, icon = "", "", "K.O.", UIKit.Colors.Red, "Skull"
	local bg = UIKit.Colors.PanelDark
	if entry.kind == "Fired" then
		left = name(entry.killer, entry.killerChar, entry.killerId)
		right = name(entry.victim, entry.victimChar, entry.victimId)
		chipText = entry.weapon and string.upper(tostring(entry.weapon)) or "FIRED"
	elseif entry.kind == "HR" then
		left = '<font color="#C79BFF">HR</font>'
		right = name(entry.victim, entry.victimChar, entry.victimId)
		chipText, chipColor = "LET GO", C.Violet
	elseif entry.kind == "Streak" then
		left = name(entry.killer, entry.killerChar, entry.killerId)
		right = '<font color="#FFE15A">EMPLOYEE OF THE MONTH!</font>'
		chipText, chipColor, icon = "STREAK", C.Gold, "Ult"
		bg = C.Bronze
	else
		right = name(entry.victim, entry.victimChar, entry.victimId)
		chipText, chipColor = "RESIGNED", C.SlotGrey
	end
	if entry.victimId == player.UserId and entry.victimId ~= 0 then
		bg = C.DeepRed
	elseif entry.killerId == player.UserId and entry.killerId ~= 0 and entry.kind == "Fired" then
		bg = C.DeepGreen
	end
	local row = UIKit.new("Frame", {
		BackgroundColor3 = bg,
		BackgroundTransparency = 0.1,
		Size = UDim2.fromOffset(0, 32),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = -math.floor(os.clock() * 1000),
		Parent = refs.feed,
	})
	UIKit.corner(row, UDim.new(0, 5))
	UIKit.stroke(row, 2.5, UIKit.Black, true)
	grad(row, UIKit.White, C.Steel)
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 10), Parent = row })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = row })
	local function txt(t, order)
		if t == "" then
			return
		end
		local l = UIKit.new("TextLabel", { BackgroundTransparency = 1, RichText = true, Font = UIKit.Body, TextSize = 16, TextColor3 = UIKit.White, Text = t, Size = UDim2.fromOffset(0, 24), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = order, Parent = row })
		UIKit.stroke(l, 1.5)
	end
	txt(left, 1)
	local chip = UIKit.new("Frame", { Name = "Chip", BackgroundColor3 = chipColor, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = row })
	UIKit.corner(chip, UDim.new(0, 4))
	UIKit.stroke(chip, 2, UIKit.Black, true)
	UIKit.Theme.bevel(chip, 0.66, 0.72)
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 3), PaddingRight = UDim.new(0, 6), Parent = chip })
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chip })
	local ib = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(18, 18), LayoutOrder = 1, Parent = chip })
	UIKit.icon(icon, ib, UIKit.White)
	local cl = UIKit.label({ Text = chipText, TextScaled = false, TextSize = 10, Size = UDim2.fromOffset(0, 14), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Stroke = 1.5 })
	cl.Parent = chip
	txt(right, 3)
	-- bande d'accent à gauche
	local strip = UIKit.new("Frame", { Name = "Strip", BackgroundColor3 = chipColor, BorderSizePixel = 0, Position = UDim2.new(0, -14, 0, 0), Size = UDim2.new(0, 6, 1, 0), Parent = row })
	strip.LayoutOrder = 0
	local sc = UIKit.pop(row, 1.15)
	local rows = {}
	for _, r in ipairs(refs.feed:GetChildren()) do
		if r:IsA("Frame") then
			table.insert(rows, r)
		end
	end
	table.sort(rows, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for i = 6, #rows do
		rows[i]:Destroy()
	end
	task.delay(7, function()
		if row.Parent then
			fadeOut(row, 0.4)
		end
	end)
end

local function buildCombo()
	local f = UIKit.new("Frame", {
		Name = "Combo",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -70, 0.42, 0),
		Size = UDim2.fromOffset(240, 130),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	UIKit.autoScale(f)
	refs.combo = f
	-- cadre intérieur centré : c'est lui qui grossit / tourne (un seul UIScale par objet)
	local inner = UIKit.new("Frame", { Name = "Inner", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = f })
	refs.comboInner = inner
	refs.comboScale = UIKit.new("UIScale", { Parent = inner })
	refs.comboNum = UIKit.label({ Text = "2", Size = UDim2.fromScale(0.55, 0.7), Stroke = 5, TextXAlignment = Enum.TextXAlignment.Right })
	refs.comboNum.Parent = inner
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(UIKit.White, C.Steel), Parent = refs.comboNum })
	refs.comboHits = UIKit.label({ Text = "HITS!", Size = UDim2.fromScale(0.43, 0.38), Position = UDim2.fromScale(0.57, 0.28), Stroke = 3, TextXAlignment = Enum.TextXAlignment.Left })
	refs.comboHits.Parent = inner
	UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(UIKit.White, C.Steel), Parent = refs.comboHits })
	refs.comboSub = UIKit.label({ Text = "", Size = UDim2.fromScale(1, 0.26), Position = UDim2.fromScale(0, 0.72), Stroke = 3, TextColor3 = UIKit.Colors.Pink })
	refs.comboSub.Parent = inner
end

local QUIPS = { "OVERTIME COMBO!", "HR VIOLATION!", "PERFORMANCE REVIEW!", "UNPAID OVERTIME!", "CORPORATE SYNERGY!", "BOSS MODE!" }
local lastCombo, comboHide = 0, 0
local function onCombo(n)
	n = n or 0
	if n >= 2 then
		comboHide += 1
		refs.combo.Visible = true
		refs.comboNum.Text = tostring(n)
		local col = n >= 12 and UIKit.Colors.Pink or n >= 8 and C.HPLow or n >= 5 and UIKit.Colors.Orange or UIKit.Colors.Yellow
		refs.comboNum.TextColor3 = col
		refs.comboHits.TextColor3 = col
		local target = 1 + math.min(n, 25) * 0.035
		refs.comboScale.Scale = target * 1.35
		UIKit.tween(refs.comboScale, 0.15, { Scale = target }, Enum.EasingStyle.Back)
		refs.comboInner.Rotation = math.random(-8, 8)
		UIKit.tween(refs.comboInner, 0.15, { Rotation = 0 })
		if n >= 10 and (lastCombo < 10 or n % 5 == 0) then
			refs.comboSub.Text = QUIPS[math.random(#QUIPS)]
			UIKit.pop(refs.comboSub, 1.3)
		elseif n < 10 then
			refs.comboSub.Text = ""
		end
	elseif lastCombo >= 2 then
		local token = comboHide + 1
		comboHide = token
		task.delay(0.7, function()
			if comboHide == token then
				UIKit.tween(refs.comboScale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				task.wait(0.22)
				if comboHide == token then
					refs.combo.Visible = false
				end
			end
		end)
	end
	lastCombo = n
end

local function slot(parent, key, order, color)
	local f = UIKit.new("Frame", {
		Name = "Slot" .. key,
		Size = UDim2.fromOffset(82, 82),
		BackgroundColor3 = color or C.SlotBlue,
		LayoutOrder = order,
		Parent = parent,
	})
	UIKit.corner(f, UDim.new(0, 8))
	local st = UIKit.stroke(f, 3, UIKit.Black, true)
	UIKit.new("UIGradient", {
		Name = "Bevel",
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, UIKit.White),
			ColorSequenceKeypoint.new(0.62, C.Silver),
			ColorSequenceKeypoint.new(1, C.Steel),
		}),
		Parent = f,
	})
	-- creux sombre pour l'icône
	local well = UIKit.new("Frame", { Name = "Well", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(1, -12, 0, 54), BackgroundColor3 = UIKit.Colors.Black, BackgroundTransparency = 0.62, ZIndex = 2, Parent = f })
	UIKit.corner(well, UDim.new(0, 5))
	local holder = UIKit.new("Frame", { Name = "IconHolder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(54, 54), BackgroundTransparency = 1, ZIndex = 3, Parent = well })
	UIKit.Theme.shine(f, 2)
	UIKit.Theme.keycap({ Name = "Key", Text = key, Size = UDim2.fromOffset(#key > 2 and 48 or (#key == 2 and 34 or 26), 24), Position = UDim2.fromOffset(-8, -9), ZIndex = 8, Parent = f })
	local name = UIKit.label({
		Name = "Name",
		Text = "",
		Font = UIKit.Body,
		TextWrapped = true,
		Size = UDim2.new(1, -6, 0, 20),
		Position = UDim2.new(0, 3, 1, -23),
		ZIndex = 3,
		Stroke = 2,
		MaxText = 12,
	})
	name.Parent = f
	UIKit.new("UIScale", { Name = "SlotScale", Parent = f })
	return f, name, st, holder
end

local function setIcon(holder, kind, color)
	if not holder or holder:GetAttribute("Kind") == kind then
		return
	end
	holder:SetAttribute("Kind", kind)
	holder:ClearAllChildren()
	UIKit.icon(kind, holder, color)
end

-- icône illustrée d'une attaque / action (key = id d'attaque, "Ult:<CharId>", "Dash", "Dropkick", "Transform"…)
-- repli : icône générique du Kind si le module d'icônes manque
local function setAttackIcon(holder, key, color, fallbackKind)
	if not holder then
		return
	end
	local tag = tostring(key) .. "|" .. (color and color:ToHex() or "")
	if holder:GetAttribute("Kind") == tag then
		return
	end
	holder:SetAttribute("Kind", tag)
	holder:ClearAllChildren()
	if AttackIcon then
		local ok, err = pcall(AttackIcon.build, key, holder, { Color = color })
		if ok then
			return
		end
		warn("[HUD] attack icon " .. tostring(key) .. ": " .. tostring(err))
		holder:ClearAllChildren()
	end
	UIKit.icon(fallbackKind or "Melee", holder, UIKit.White)
end

local function attackKind(id)
	local A = getAttacks()
	local a = A and id and A[id]
	return type(a) == "table" and a.Kind or "Melee"
end

local function buildAbilities()
	local f = UIKit.new("Frame", {
		Name = "Abilities",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -54), -- au milieu, en bas (au-dessus du bandeau des commandes)
		Size = UDim2.fromOffset(7 * 92, 88),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UIKit.autoScale(f)
	UIKit.new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = f,
	})
	refs.abilities = f
	refs.slots = {}
	local dash, dashName, _, dashIcon = slot(f, "Q", 0, C.SlotBlue)
	dashName.Text = "DASH"
	setAttackIcon(dashIcon, "Dash", nil, "Dash")
	HUD.bindCooldown(dash, "Dash")
	for i = 1, 3 do
		local sf, nm, st, ic = slot(f, tostring(i), i)
		refs.slots[i] = { frame = sf, name = nm, stroke = st, icon = ic }
		HUD.bindCooldown(sf, tostring(i))
	end
	local g, gName, gStroke, gIcon = slot(f, "G", 4, C.Coffee)
	refs.gSlot, refs.gName, refs.gStroke, refs.gIcon = g, gName, gStroke, gIcon
	refs.gFill = UIKit.new("Frame", {
		Name = "GFill",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = UIKit.Colors.Orange,
		ZIndex = 1,
		Parent = g,
	})
	UIKit.corner(refs.gFill, UDim.new(0, 8))
	gName.Text = "OVERTIME"
	setAttackIcon(gIcon, "Transform", nil, "Bolt")
	-- système ABA : DASH STRIKE (dash avant + clic) et EVASIVE (Q pendant un combo), avec leurs recharges
	local dk, dkName, _, dkIcon = slot(f, "Q+M1", 5, C.Brick)
	dkName.Text = "DASH STRIKE"
	setAttackIcon(dkIcon, "Dropkick", nil, "Boot")
	HUD.bindCooldown(dk, "DashStrike")
	refs.dkSlot = dk
	local ev, evName, _, evIcon = slot(f, "Q", 6, C.Mustard)
	ev.Name = "SlotEvasive"
	evName.Text = "EVASIVE"
	if AttackIcon and AttackIcon.has and AttackIcon.has("Evasive") then
		setAttackIcon(evIcon, "Evasive", nil, "Bolt")
	else
		setIcon(evIcon, "Bolt", UIKit.White)
	end
	HUD.bindCooldown(ev, "Evasive")
	refs.evSlot = ev
	f.Visible = not UIKit.isTouch()

	-- info-bulle : description de l'attaque au survol (on comprend ce que fait chaque move)
	local tipBox = UIKit.new("Frame", {
		Name = "TipBox",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -18),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundColor3 = UIKit.Colors.PanelDark,
		BackgroundTransparency = 0.04,
		Visible = false,
		ZIndex = 12,
		Parent = f,
	})
	UIKit.corner(tipBox, UDim.new(0, 6))
	UIKit.stroke(tipBox, 3, UIKit.Black, true)
	grad(tipBox, UIKit.White, C.Steel)
	UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), Parent = tipBox })
	local tip = UIKit.new("TextLabel", {
		Name = "Tip",
		BackgroundTransparency = 1,
		Font = UIKit.Body,
		TextSize = 15,
		TextWrapped = true,
		RichText = true,
		TextColor3 = UIKit.White,
		Text = "",
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		ZIndex = 13,
		Parent = tipBox,
	})
	UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(520, 160), Parent = tip })
	UIKit.stroke(tip, 1.5)
	-- grande icône illustrée de l'attaque à gauche du texte
	UIKit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = tipBox })
	tip.LayoutOrder = 2
	local tipIcon = UIKit.new("Frame", { Name = "TipIcon", BackgroundTransparency = 1, Size = UDim2.fromOffset(64, 64), LayoutOrder = 1, ZIndex = 13, Parent = tipBox })
	local function iconKeyFor(key)
		local kit, cname = HUD.currentKit()
		local c = myChar()
		if key == "Q+M1" then
			return "Dropkick", nil, "Boot"
		elseif key == "EVA" then
			if AttackIcon and AttackIcon.has and AttackIcon.has("Evasive") then
				return "Evasive", nil, "Bolt"
			end
			return "Block", nil, "Bolt"
		elseif key == "Q" then
			return "Dash", nil, "Dash"
		elseif key == "G" then
			if c and c:GetAttribute("UltReady") and cname then
				return "Ult:" .. cname, kit and kit.Color, "Ult"
			end
			return "Transform", nil, "Bolt"
		end
		local list = kit and (c and c:GetAttribute("Transformed") and kit.TransAttacks or kit.Attacks) or {}
		local id = list[tonumber(key) or 0]
		return id or "Hit", kit and kit.Color, id and attackKind(id) or "Melee"
	end
	local Y = '<font color="#FFD632">'
	local function describe(key)
		local kit = HUD.currentKit()
		local c = myChar()
		if key == "Q+M1" then
			return Y .. "DASH STRIKE:</font> dash FORWARD then click right away: flying kick that breaks guards and knocks them down. " .. CombatConfig.DashStrike.Cooldown .. "s cooldown."
		elseif key == "EVA" then
			return Y .. "EVASIVE:</font> getting combo'd? Press Q to burst free and push them away (not while guard-broken). " .. CombatConfig.Evasive.Cooldown .. "s cooldown."
		elseif key == "Q" then
			return Y .. "DASH:</font> Q + direction (W/A/S/D): forward, back or SIDE dash. Cancels a combo you stopped. " .. CombatConfig.Dash.Cooldown .. "s cooldown."
		elseif key == "G" then
			if c and c:GetAttribute("UltReady") then
				return Y .. "ULTIMATE: " .. UIKit.escape(string.upper(tostring(c:GetAttribute("UltName") or "?"))) .. "</font> Press G again during OVERTIME to unleash it (once per transformation)."
			end
			return kit and (Y .. UIKit.escape(string.upper(kit.Transformation.Name)) .. ":</font> " .. UIKit.escape(kit.Transformation.Desc) .. " Fill OVERTIME by fighting, then press G. Press G AGAIN while transformed for your ULTIMATE!") or ""
		end
		local i = tonumber(key)
		local list = kit and (c and c:GetAttribute("Transformed") and kit.TransAttacks or kit.Attacks) or {}
		local A = getAttacks()
		local a = A and A[list[i] or ""]
		return a and (Y .. UIKit.escape(string.upper(a.Name)) .. ":</font> " .. UIKit.escape(a.Desc or "")) or ""
	end
	local function hook(frame, key)
		frame.Active = true
		frame.MouseEnter:Connect(function()
			tip.Text = describe(key)
			local ik, icol, ifb = iconKeyFor(key)
			setAttackIcon(tipIcon, ik, icol, ifb)
			tipBox.Visible = tip.Text ~= ""
			if tipBox.Visible then
				UIKit.pop(tipBox, 1.06)
			end
		end)
		frame.MouseLeave:Connect(function()
			tipBox.Visible = false
		end)
	end
	hook(dash, "Q")
	for i = 1, 3 do
		hook(refs.slots[i].frame, tostring(i))
	end
	hook(g, "G")
	hook(dk, "Q+M1")
	hook(ev, "EVA")
end

-- Boutons de menu : délégués au dock unique (MetaDockController) ; un seul panneau ouvert (registre UIKit)
local MENU_ICONS = { CHARACTER = "Person", TASKS = "Tasks", COMBOS = "List", SHOP = "Shop", ADMIN = "Admin", CRATES = "Crate", CRATE = "Crate" }
local MENU_ORDER = { CHARACTER = 2, TASKS = 4, COMBOS = 5, SHOP = 6, ADMIN = 95 }
local dockMod
local function getDock()
	if dockMod == nil then
		local m = script.Parent:FindFirstChild("MetaDockController")
		local ok, mod = false, nil
		if m then
			ok, mod = pcall(require, m)
		end
		dockMod = ok and type(mod) == "table" and mod or false
	end
	return dockMod or nil
end

function HUD.addMenuButton(text: string, color: Color3, callback, order: number?)
	local dock = getDock()
	if not dock then
		warn("[HUD] MetaDockController manquant : bouton " .. tostring(text) .. " ignoré")
		return nil
	end
	local first = string.upper(string.match(text, "^(%a+)") or "MENU")
	local id = string.sub(first, 1, 1) .. string.lower(string.sub(first, 2))
	local o = MENU_ORDER[first] or math.clamp(math.floor((order or 50) / 10), 1, 9)
	return dock.addButton(id, text, color, MENU_ICONS[first] or "Ult", callback, o)
end

local function remoteNamed(name)
	local rem = ReplicatedStorage:FindFirstChild("Remotes")
	return rem and rem:FindFirstChild(name)
end

local function decode(raw)
	local ok, list = pcall(function()
		return raw and HttpService:JSONDecode(raw) or {}
	end)
	return ok and type(list) == "table" and list or {}
end

-- Tâches du jour + contrats de la semaine (TaskService) : 2 sections, comptes à rebours, relance gratuite
local function taskRow(parent, y, weekly, index)
	local row = UIKit.new("Frame", {
		Name = (weekly and "Weekly" or "Daily") .. index,
		Position = UDim2.fromOffset(0, y),
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = UIKit.Colors.PanelDark,
		BackgroundTransparency = 0.15,
		ZIndex = 21,
		Parent = parent,
	})
	UIKit.corner(row, UDim.new(0, 5))
	UIKit.stroke(row, 2, UIKit.Black, true)
	local check = UIKit.new("Frame", { Name = "Check", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(24, 24), BackgroundColor3 = UIKit.Colors.Slot, ZIndex = 22, Parent = row })
	UIKit.corner(check, UDim.new(0, 4))
	UIKit.stroke(check, 2, UIKit.Black, true)
	local mark = UIKit.icon("Check", check, C.Mint, 23)
	mark.Visible = false
	local t = UIKit.label({ Text = "", Font = UIKit.Body, Size = UDim2.new(1, -200, 0, 18), Position = UDim2.new(0, 40, 0, 7), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 1.5, ZIndex = 22 })
	t.Parent = row
	local reward = UIKit.label({ Text = "", Font = UIKit.Body, Size = UDim2.new(0, 150, 0, 16), Position = UDim2.new(1, -158, 0, 8), TextColor3 = weekly and C.Gold or C.Lilac, TextXAlignment = Enum.TextXAlignment.Right, Stroke = 1.5, ZIndex = 22 })
	reward.Parent = row
	local b = bar(row, "Bar", UDim2.new(0, 40, 0, 31), UDim2.new(1, weekly and -48 or -132, 0, 14), weekly and C.Gold or C.HP, "")
	b.Trail.Visible = false
	b.Ticks.Visible = false
	b.Text.TextXAlignment = Enum.TextXAlignment.Center
	b.Text.Size = UDim2.new(1, -8, 0.8, 0)
	b.Text.Position = UDim2.new(0, 4, 0.1, 0)
	local rr
	if not weekly then
		rr = UIKit.button({ Name = "Reroll", Text = "REROLL", Color = UIKit.Colors.Blue, Position = UDim2.new(1, -84, 0, 25), Size = UDim2.fromOffset(78, 24), Visible = false, ZIndex = 23, Parent = row })
		rr.Activated:Connect(function()
			local r = remoteNamed("TaskRequest")
			if r then
				r:FireServer("Reroll", index)
				rr.Visible = false
			end
		end)
	end
	return { row = row, text = t, reward = reward, bar = b, mark = mark, check = check, reroll = rr }
end

local function buildTasks()
	local dock = getDock()
	if not dock then
		return
	end
	local f, body = dock.panel("TasksPanel", "TASKS & CONTRACTS", UIKit.Colors.Green, Vector2.new(560, 510), "Tasks")
	refs.tasks = f
	local function head(y, text, color)
		local l = UIKit.label({ Text = text, Position = UDim2.fromOffset(0, y), Size = UDim2.new(0.55, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = color, Stroke = 2.5, ZIndex = 22 })
		l.Parent = body
		local cd = UIKit.label({ Text = "", Font = UIKit.Body, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, y + 2), Size = UDim2.new(0.45, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = UIKit.Colors.Muted, Stroke = 1.5, ZIndex = 22 })
		cd.Parent = body
		return cd
	end
	refs.dailyClock = head(0, "DAILY TASKS", UIKit.Colors.Green)
	refs.weeklyClock = head(212, "WEEKLY CONTRACTS", C.Gold)
	refs.taskRows, refs.weekRows = {}, {}
	for i = 1, 3 do
		refs.taskRows[i] = taskRow(body, 26 + (i - 1) * 58, false, i)
		refs.weekRows[i] = taskRow(body, 238 + (i - 1) * 58, true, i)
	end
	local note = UIKit.label({ Text = "1 free reroll a day  -  contracts pay Cash + Briefcases", Font = UIKit.Body, Position = UDim2.fromOffset(0, 414), Size = UDim2.new(1, 0, 0, 16), TextColor3 = UIKit.Colors.Muted, Stroke = 1.5, ZIndex = 22 })
	note.Parent = body
	refs.rerollNote = note
end

local function tickTaskClocks()
	if not refs.tasks or not refs.tasks.Visible then
		return
	end
	local t = now()
	local d = tonumber(player:GetAttribute("TasksReset"))
	local w = tonumber(player:GetAttribute("TasksWeeklyReset"))
	refs.dailyClock.Text = d and ("NEW TASKS IN " .. UIKit.fmtLong(d - t)) or ""
	refs.weeklyClock.Text = w and ("RESETS IN " .. UIKit.fmtLong(w - t)) or ""
end

local function fillRows(rows, list, weekly, rerolls)
	local done = 0
	for i, r in ipairs(rows) do
		local e = list[i]
		r.row.Visible = e ~= nil
		if e then
			if e.d then
				done += 1
			end
			r.text.Text = tostring(e.t or "")
			r.text.TextColor3 = e.d and C.Mint or UIKit.White
			if weekly then
				r.reward.Text = "+" .. HUD.fmtMoney(e.c or 0) .. ((e.b or 0) > 0 and (" +" .. e.b .. " CASE") or "")
			else
				r.reward.Text = "+" .. tostring(e.x or 0) .. " XP"
			end
			r.mark.Visible = e.d == true
			r.check.BackgroundColor3 = e.d and C.DeepGreen or UIKit.Colors.Slot
			local pct = math.clamp((tonumber(e.p) or 0) / math.max(tonumber(e.g) or 1, 1), 0, 1)
			UIKit.tween(r.bar.Fill, 0.4, { Size = UDim2.fromScale(math.max(pct, 0.001), 1) }, Enum.EasingStyle.Quad)
			r.bar.Text.Text = tostring(e.p or 0) .. " / " .. tostring(e.g or 0)
			if r.reroll then
				r.reroll.Visible = (rerolls or 0) > 0 and not e.d
			end
		end
	end
	return done
end

local function refreshTasks()
	if not refs.taskRows then
		return
	end
	local list = decode(player:GetAttribute("Tasks"))
	local weekly = decode(player:GetAttribute("TasksWeekly"))
	local rerolls = tonumber(player:GetAttribute("TaskRerolls")) or 0
	local done = fillRows(refs.taskRows, list, false, rerolls)
	local wdone = fillRows(refs.weekRows, weekly, true, 0)
	refs.rerollNote.Text = (rerolls > 0 and (rerolls .. " free reroll left today") or "Reroll used - back tomorrow") .. "  -  contracts pay Cash + Briefcases"
	local dock = getDock()
	if dock then
		dock.setText("Tasks", "TASKS " .. done .. "/" .. #list)
		dock.setBadge("Tasks", done < #list or wdone < #weekly, tostring((#list - done) + (#weekly - wdone)))
	end
	tickTaskClocks()
end

-- Liste des combos (pour apprendre)
local COMBO_LIST = {
	{ "CLICK x5", "M1 STRING", "Hits 1-4 stun, the 5th KNOCKS DOWN. Long recovery after it: don't whiff!" },
	{ "HOLD SPACE + 5th CLICK", "UPPERCUT", "Launches them, you jump after them: CLICK x3 in the air, the 3rd slams them down." },
	{ "5th CLICK IN THE AIR", "DOWNSLAM", "Jump during your string: the 5th hit smashes them into the floor." },
	{ "HOLD F", "BLOCK", "Blocks hits from the front. The guard bar drains: empty = GUARD BREAK!" },
	{ "F (just before a hit)", "PERFECT BLOCK", "Tap F right as they swing: THEY are stunned and disarmed. Even stops heavy hits." },
	{ "HEAVY HITS", "GUARD BREAK", "5th hit, uppercut, slam, dash strike and heavy moves break a normal block." },
	{ "Q + W/A/S/D", "DASH", "Dash forward, back or SIDEWAYS (" .. CombatConfig.Dash.Cooldown .. "s cooldown). Cancels a combo you stopped." },
	{ "Q (forward) + CLICK", "DASH STRIKE", "Dash forward then click: flying kick, knocks down (" .. CombatConfig.DashStrike.Cooldown .. "s cooldown)." },
	{ "Q while combo'd", "EVASIVE", "Burst free and push them away (" .. CombatConfig.Evasive.Cooldown .. "s cooldown). Not while guard-broken." },
	{ "COMBO + ITEM", "ITEM FINISHER", "Punch twice then hit with an item: huge damage (\"CHAIR COMBO!\")." },
}
local function buildCombos()
	local dock = getDock()
	if not dock then
		return
	end
	local f, body = dock.panel("CombosPanel", "COMBOS", UIKit.Colors.Blue, Vector2.new(640, 582), "List")
	refs.combos = f
	for i, c in ipairs(COMBO_LIST) do
		local y = (i - 1) * 50
		local rowBg = UIKit.new("Frame", {
			BackgroundColor3 = i % 2 == 0 and UIKit.Colors.PanelDark or UIKit.Colors.Slot,
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 0, 0, y),
			Size = UDim2.new(1, 0, 0, 47),
			ZIndex = 21,
			Parent = body,
		})
		UIKit.corner(rowBg, UDim.new(0, 3))
		local chip = UIKit.new("Frame", {
			BackgroundColor3 = UIKit.Colors.Cyan,
			Position = UDim2.new(0, 6, 0, y + 4),
			Size = UDim2.fromOffset(0, 20),
			AutomaticSize = Enum.AutomaticSize.X,
			ZIndex = 22,
			Parent = body,
		})
		UIKit.corner(chip, UDim.new(0, 3))
		UIKit.stroke(chip, 2, UIKit.Black, true)
		UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6), Parent = chip })
		local keys = UIKit.label({ Text = c[1], Font = UIKit.Body, TextScaled = false, TextSize = 14, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = UIKit.Colors.Ink, Stroke = false, ZIndex = 23 })
		keys.Parent = chip
		local name = UIKit.label({ Text = c[2], Size = UDim2.new(0, 230, 0, 16), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, y + 6), TextColor3 = UIKit.Colors.Yellow, TextXAlignment = Enum.TextXAlignment.Right, Stroke = 2, ZIndex = 22 })
		name.Parent = body
		local desc = UIKit.label({ Text = c[3], Font = UIKit.Body, Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 0, y + 28), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.Silver, Stroke = 1.5, ZIndex = 22 })
		desc.Parent = body
	end
end

-- Compteur de Cash ("$1,250") en haut à droite + petits « +$30 K.O. » (remote CashPopup)
local function fmtMoney(n)
	n = math.floor(tonumber(n) or 0)
	local s = tostring(math.abs(n))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return (n < 0 and "-$" or "$") .. s .. out
end
HUD.fmtMoney = fmtMoney

local function buildCash()
	local f = UIKit.new("Frame", {
		Name = "Cash",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 12),
		Size = UDim2.fromOffset(186, 44),
		BackgroundColor3 = C.CashGreen,
		Parent = gui,
	})
	UIKit.autoScale(f)
	UIKit.corner(f, UDim.new(0, 8))
	UIKit.stroke(f, 3, UIKit.Black, true)
	UIKit.Theme.bevel(f, 0.72, 0.72)
	UIKit.Theme.shine(f)
	local coin = UIKit.new("Frame", { Name = "Bill", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -10, 0.5, 0), Size = UDim2.fromOffset(48, 48), BackgroundTransparency = 1, ZIndex = 3, Parent = f })
	UIKit.icon("Cash", coin, UIKit.Colors.Cash, 3)
	refs.cashBill = coin
	refs.cashText = UIKit.label({ Text = "$0", Position = UDim2.fromOffset(44, 7), Size = UDim2.new(1, -56, 1, -14), TextXAlignment = Enum.TextXAlignment.Right, Stroke = 2.5, ZIndex = 2 })
	grad(refs.cashText, UIKit.White, C.Mint)
	refs.cashText.Parent = f
	refs.cash = f
	refs.cashShown = tonumber(player:GetAttribute("Cash")) or 0
	refs.cashPop = UIKit.new("UIScale", { Name = "PopScale", Parent = refs.cashText })
end

local function cashPopup(d)
	if type(d) ~= "table" or not refs.cash then
		return
	end
	local amt = tonumber(d.amount) or 0
	if amt == 0 then
		return
	end
	local txt = (amt > 0 and "+" or "-") .. fmtMoney(math.abs(amt)) .. (d.reason and ("  " .. string.upper(tostring(d.reason))) or "")
	local n = 0
	for _, c in ipairs(refs.cash:GetChildren()) do
		if c.Name == "CashPop" then
			n += 1
		end
	end
	local y = 0.5 + math.min(n, 3) * 0.7
	local l = UIKit.label({
		Name = "CashPop",
		Text = txt,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(0, -12, y, 0),
		Size = UDim2.fromOffset(260, 26),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = amt > 0 and C.Mint or C.HPLow,
		Stroke = 2.5,
		ZIndex = 4,
	})
	l.Parent = refs.cash
	UIKit.pop(l, 1.4)
	UIKit.tween(l, 1.6, { Position = UDim2.new(0, -12, y, 16) })
	refs.cashPop.Scale = 1.3
	UIKit.tween(refs.cashPop, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	if refs.cashBill then
		UIKit.Theme.wobble(refs.cashBill, 14, 0)
	end
	task.delay(1.1, function()
		UIKit.tween(l, 0.5, { TextTransparency = 1 })
		local st = l:FindFirstChildOfClass("UIStroke")
		if st then
			UIKit.tween(st, 0.5, { Transparency = 1 })
		end
		task.wait(0.5)
		l:Destroy()
	end)
end

-- Popup « LEVEL UP! » (remote LevelUp) : rayons, onde, gros numéro qui défile, récompense en Cash, son
local levelSounds
local function playLevelSound()
	if levelSounds == nil then
		local ok, S = pcall(function()
			return require(Config.Sounds)
		end)
		levelSounds = ok and type(S) == "table" and S.LevelUp or false
	end
	if not levelSounds or #levelSounds == 0 then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = levelSounds[1]
	s.Volume = 0.8
	s.Parent = game:GetService("SoundService")
	s:Play()
	game:GetService("Debris"):AddItem(s, 6)
end

local function levelUpPopup(d)
	if type(d) ~= "table" or not gui then
		return
	end
	local level = tonumber(d.level) or (player:GetAttribute("Level") or 1)
	local from = math.clamp(tonumber(d.from) or (level - 1), 1, level)
	local cash = tonumber(d.cash) or 0
	local old = gui:FindFirstChild("LevelUp")
	if old then
		old:Destroy()
	end
	local GOLD = C.Gold
	local holder = UIKit.new("Frame", { Name = "LevelUp", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(460, 250), BackgroundTransparency = 1, ZIndex = 40, Parent = gui })
	UIKit.autoScale(holder)
	-- rayons qui tournent
	local rays = UIKit.new("Frame", { Name = "Rays", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 40, Parent = holder })
	for i = 1, 8 do
		local r = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 26), Rotation = i * 22.5, BackgroundColor3 = GOLD, BackgroundTransparency = 0.72, BorderSizePixel = 0, ZIndex = 40, Parent = rays })
		UIKit.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) }), Parent = r })
	end
	-- onde de choc
	local ring = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, ZIndex = 41, Parent = holder })
	UIKit.corner(ring, UDim.new(0.5, 0))
	local ringStroke = UIKit.stroke(ring, 8, C.Cream, true)
	UIKit.tween(ring, 0.55, { Size = UDim2.fromOffset(520, 520) })
	UIKit.tween(ringStroke, 0.55, { Transparency = 1, Thickness = 1 })
	-- carte centrale
	local card = UIKit.new("Frame", { Name = "Card", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(330, 190), BackgroundColor3 = C.DeepPurple, ZIndex = 42, Parent = holder })
	UIKit.corner(card, UDim.new(0, 10))
	UIKit.stroke(card, 4, UIKit.Black, true)
	grad(card, UIKit.Colors.Purple, C.DeepPurple)
	UIKit.Theme.shine(card, 43)
	local title = UIKit.label({ Text = "LEVEL UP!", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(400, 58), TextColor3 = GOLD, Stroke = 5, ZIndex = 45 })
	grad(title, C.Cream, C.Amber)
	title.Parent = card
	local lvTag = UIKit.label({ Text = "LV", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(0.5, -58, 0.47, 6), Size = UDim2.fromOffset(60, 30), TextColor3 = C.Lilac, Stroke = 3, ZIndex = 44 })
	lvTag.Parent = card
	local num = UIKit.label({ Name = "Num", Text = tostring(from), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.fromOffset(120, 74), TextColor3 = UIKit.White, Stroke = 5, ZIndex = 44 })
	num.Parent = card
	local pill = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(230, 40), BackgroundColor3 = C.CashGreen, ZIndex = 44, Parent = card })
	UIKit.corner(pill, UDim.new(0, 8))
	UIKit.stroke(pill, 3, UIKit.Black, true)
	UIKit.Theme.bevel(pill, 0.7, 0.72)
	local reward = UIKit.label({ Text = "+" .. fmtMoney(cash) .. " CASH", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -20, 0.6, 0), TextColor3 = C.Mint, Stroke = 2.5, ZIndex = 45 })
	reward.Parent = pill
	local pscale = UIKit.new("UIScale", { Scale = 0, Parent = pill })
	UIKit.pop(holder, 1.18)
	UIKit.Theme.wobble(title, 6, 0)
	playLevelSound()
	UIKit.Theme.countUp(num, from, level, math.min(0.25 + 0.08 * (level - from), 0.9))
	task.delay(0.45, function()
		if pill.Parent then
			UIKit.tween(pscale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
			UIKit.Theme.wobble(pill, 5, 0)
		end
	end)
	-- rotation des rayons + pulsation du numéro
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not holder.Parent then
			conn:Disconnect()
			return
		end
		local t = os.clock() - t0
		rays.Rotation = t * 35
		num.Rotation = math.sin(t * 7) * 3
	end)
	task.delay(3.4, function()
		if holder.Parent then
			fadeOut(holder, 0.45)
		end
	end)
end
HUD.levelUpPopup = levelUpPopup

local function skinRequest(...)
	local rf = remoteNamed("SkinRequest")
	if not rf then
		HUD.toast("The shop is still loading, try again!", C.HPLow)
		return
	end
	local args = table.pack(...)
	task.spawn(function()
		pcall(function()
			return rf:InvokeServer(table.unpack(args, 1, args.n))
		end)
	end)
end

-- Boutique HONNÊTE : seulement ce qui s'achète vraiment. Jamais vide :
--   portefeuille (Cash, mallettes, persos) + JOBS (écran de sélection) + caisses de skins en Cash,
--   puis offres Robux / cosmétiques seulement si ProductId ~= 0 (Config/Skins.Products, Config/Shop). Aucune section « SOON ».
local Skins, Unlocks
local function shopConfigs()
	if Skins == nil then
		local sm = Config:FindFirstChild("Skins")
		local ok, mod = false, nil
		if sm then
			ok, mod = pcall(require, sm)
		end
		Skins = ok and type(mod) == "table" and mod or false
	end
	if Unlocks == nil then
		local um = Config:FindFirstChild("Unlocks")
		local ok, mod = false, nil
		if um then
			ok, mod = pcall(require, um)
		end
		Unlocks = ok and type(mod) == "table" and mod or false
	end
	return Skins or nil, Unlocks or nil
end

local ownedJobs = nil -- {[charId]=true} (UnlockState / UnlockRequest "State")
local ctxRef
local fillShop

local function openJobs()
	local cs = ctxRef and ctxRef.CharacterSelectController
	if cs and cs.open then
		UIKit.closeAllPanels()
		cs.open(false)
	else
		HUD.toast("Job select is still loading, try again!", C.HPLow)
	end
end

local function openCrates(crateId)
	local cs = ctxRef and ctxRef.CharacterSelectController
	if cs and cs.openBriefcase then
		UIKit.closeAllPanels()
		cs.openBriefcase(crateId)
	end
end

local function buildShop()
	local dock = getDock()
	if not dock then
		return
	end
	local f, body = dock.panel("ShopPanel", "SHOP", C.Amber, Vector2.new(660, 490), "Shop")
	refs.shop = f
	local sub = UIKit.label({ Text = "Cosmetics only - never pay-to-win!", Font = UIKit.Body, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = UIKit.Colors.Muted, Stroke = 1.5, ZIndex = 21 })
	sub.Parent = body
	local list = UIKit.new("ScrollingFrame", {
		Name = "List",
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 1, -24),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 21,
		Parent = body,
	})
	refs.shopList = list
	f:GetPropertyChangedSignal("Visible"):Connect(function()
		if not f.Visible then
			return
		end
		fillShop()
		task.spawn(function()
			local rf = remoteNamed("UnlockRequest")
			if not rf then
				return
			end
			local ok, st = pcall(function()
				return rf:InvokeServer("State")
			end)
			if ok and type(st) == "table" and type(st.Owned) == "table" then
				ownedJobs = st.Owned
				if f.Visible then
					fillShop()
				end
			end
		end)
	end)
end

fillShop = function()
	local list = refs.shopList
	if not list then
		return
	end
	list:ClearAllChildren()
	UIKit.new("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })
	local S, U = shopConfigs()
	local function section(order, text)
		if Shop.isHiddenSection(text) then
			return nil
		end
		local head = UIKit.label({ Text = text, Size = UDim2.new(1, -10, 0, 26), TextColor3 = UIKit.Colors.Yellow, TextXAlignment = Enum.TextXAlignment.Left, Stroke = 3, LayoutOrder = order, ZIndex = 22 })
		head.Parent = list
		local box = UIKit.new("Frame", { Size = UDim2.new(1, -10, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = order + 1, ZIndex = 21, Parent = list })
		UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(190, 150), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, Parent = box })
		return box
	end
	local function card(box, order, color, icon, swatchText, name, subText, btnText, btnColor, onClick)
		local c = UIKit.new("Frame", { BackgroundColor3 = UIKit.Colors.Slot, LayoutOrder = order, ZIndex = 22, Parent = box })
		UIKit.corner(c, UDim.new(0, 8))
		UIKit.stroke(c, 3, UIKit.Black, true)
		grad(c, UIKit.White, C.Steel)
		local sw = UIKit.new("Frame", { Position = UDim2.new(0, 8, 0, 8), Size = UDim2.new(1, -16, 0, 50), BackgroundColor3 = color, ZIndex = 23, Parent = c })
		UIKit.corner(sw, UDim.new(0, 6))
		UIKit.Theme.bevel(sw, 0.72, 0.72)
		UIKit.stroke(sw, 2, UIKit.Black, true)
		UIKit.Theme.shine(sw, 23)
		local ib = UIKit.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(36, 36), BackgroundTransparency = 1, ZIndex = 24, Parent = sw })
		UIKit.icon(icon, ib, UIKit.White, 24)
		local st = UIKit.label({ Text = swatchText, Size = UDim2.new(1, -56, 0.56, 0), Position = UDim2.new(0, 48, 0.22, 0), ZIndex = 24 })
		st.Parent = sw
		local nm = UIKit.label({ Text = name, Font = UIKit.Body, Size = UDim2.new(1, -16, 0, 19), Position = UDim2.new(0, 8, 0, 63), ZIndex = 23 })
		nm.Parent = c
		local sl = UIKit.label({ Text = subText, Font = UIKit.Body, Size = UDim2.new(1, -16, 0, 14), Position = UDim2.new(0, 8, 0, 85), TextColor3 = C.Mint, ZIndex = 23 })
		sl.Parent = c
		local b = UIKit.button({ Text = btnText, Color = btnColor, Position = UDim2.new(0, 8, 1, -46), Size = UDim2.new(1, -16, 0, 38), ZIndex = 23, Parent = c })
		if onClick then
			b.Activated:Connect(onClick)
		else
			b.Active = false
			b.Label.TextColor3 = C.Silver
		end
		local cs = UIKit.new("UIScale", { Parent = c })
		c.MouseEnter:Connect(function()
			UIKit.tween(cs, 0.12, { Scale = 1.04 }, Enum.EasingStyle.Back)
		end)
		c.MouseLeave:Connect(function()
			UIKit.tween(cs, 0.12, { Scale = 1 })
		end)
		return c
	end

	-- 1) Portefeuille (toujours là)
	local cash = tonumber(player:GetAttribute("Cash")) or 0
	local crates = tonumber(player:GetAttribute("Crates")) or 0
	local total, owned = 0, 0
	for _, id in ipairs(Characters.Order or {}) do
		total += 1
		if (ownedJobs and ownedJobs[id]) or (not ownedJobs and U and U.isFree(id)) then
			owned += 1
		end
	end
	local wallet = section(1, "YOUR STUFF")
	card(wallet, 1, C.CashGreen, "Cash", HUD.fmtMoney(cash), "Your Cash", "Earn it fighting & tasks", "EARN MORE", UIKit.Colors.Green, function()
		if refs.tasks then
			UIKit.openPanel(refs.tasks)
		end
	end)
	card(wallet, 2, UIKit.Colors.Blue, "Crate", "x" .. crates, "Free Briefcases", "From dailies & contracts", crates > 0 and "OPEN ONE" or "GET SOME", crates > 0 and C.Gold or UIKit.Colors.Blue, function()
		if crates > 0 then
			openCrates("Briefcase")
		elseif refs.tasks then
			UIKit.openPanel(refs.tasks)
		end
	end)
	card(wallet, 3, UIKit.Colors.Purple, "Person", owned .. "/" .. total, "Jobs Unlocked", ownedJobs and "Unlock more with Cash" or "Checking...", "BROWSE JOBS", UIKit.Colors.Purple, openJobs)

	-- 2) JOBS : persos à débloquer (Cash ; Robux seulement si le Game Pass existe) -> écran de sélection
	local jobs = section(10, "JOBS")
	local n = 0
	if U then
		for _, id in ipairs(Characters.Order or {}) do
			local e = U.get(id)
			local kit = Characters[id]
			local buyable = e.Tier == "Cash" or (e.Tier == "Robux" and (tonumber(e.GamePassId) or 0) ~= 0)
			if kit and buyable and not (ownedJobs and ownedJobs[id]) and n < 6 then
				n += 1
				local can = e.Tier ~= "Cash" or cash >= (e.Price or 0)
				card(jobs, n, kit.Color or UIKit.Colors.Slot, "Person", U.priceText(id), kit.DisplayName or id, e.Tier == "Cash" and (can and "You can afford it!" or "Keep earning Cash") or "Game Pass", "VIEW JOB", can and UIKit.Colors.Green or UIKit.Colors.Blue, openJobs)
			end
		end
	end
	if n == 0 then
		card(jobs, 1, UIKit.Colors.Purple, "Person", "ALL", ownedJobs and "Every job unlocked!" or "Your jobs", "Pick who you play", "OPEN JOBS", UIKit.Colors.Purple, openJobs)
	end

	-- 3) Caisses de skins (Cash) : ouvre la CRATE SHOP sur la caisse choisie
	local crateBox = section(20, "SKIN CRATES")
	local crateList = S and type(S.Crates) == "table" and S.Crates or {}
	for i, cd in ipairs(crateList) do
		local o = cd.Odds or {}
		local swatch = (o.Rare or 0) == 0 and "EPIC+" or (cd.Pool and (#cd.Pool .. " JOBS") or "ALL JOBS")
		local odds = string.format("Epic %d%%  -  Legendary %d%%", o.Epic or 0, o.Legendary or 0)
		card(crateBox, i, cd.Color or C.Amber, "Crate", swatch, cd.Name or cd.Id, odds, "OPEN - " .. HUD.fmtMoney(cd.Price or 0), C.Amber, function()
			openCrates(cd.Id)
		end)
	end

	-- 4) Offres Robux : seulement les produits créés sur le site (ProductId ~= 0)
	local live = {}
	for _, p in ipairs(S and S.Products or {}) do
		if (tonumber(p.ProductId) or 0) ~= 0 then
			table.insert(live, p)
		end
	end
	if #live > 0 then
		local box = section(30, "CASH & BRIEFCASES")
		for i, p in ipairs(live) do
			local isCash = (tonumber(p.Cash) or 0) > 0
			local swatch = isCash and ("+" .. HUD.fmtMoney(p.Cash)) or ("x" .. tostring(p.Crates or 1))
			local subText = isCash and (HUD.fmtMoney(p.Cash) .. " cash") or (tostring(p.Crates or 1) .. " free briefcase" .. ((p.Crates or 1) > 1 and "s" or ""))
			card(box, i, isCash and C.CashGreen or C.Amber, isCash and "Cash" or "Crate", swatch, p.Name or p.Id, subText, "R$ " .. tostring(p.Robux or "?"), UIKit.Colors.Green, function()
				skinRequest("Buy", p.Id)
			end)
		end
	end

	-- 5) Cosmétiques : seulement les fiches en vente (Config/Shop, ProductId ~= 0)
	local items = Shop.liveItems()
	if #items > 0 then
		local box = section(40, "COSMETICS")
		for i, item in ipairs(items) do
			card(box, i, item.Color or UIKit.Colors.Slot, "Shop", string.upper(item.Category or ""), item.Name, item.Desc or "Cosmetic", "R$ " .. tostring(item.Price), UIKit.Colors.Green, function()
				local mps = game:GetService("MarketplaceService")
				pcall(function()
					mps:PromptProductPurchase(player, item.ProductId)
				end)
			end)
		end
	end
end

-- Écran K.O.
local function showFired()
	local f = UIKit.new("Frame", {
		Name = "Fired",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Blood,
		BackgroundTransparency = 1,
		ZIndex = 30,
		Parent = gui,
	})
	refs.fired = f
	UIKit.tween(f, 0.3, { BackgroundTransparency = 0.55 })
	local holder = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(620, 150),
		BackgroundTransparency = 1,
		ZIndex = 31,
		Parent = f,
	})
	UIKit.autoScale(holder)
	local stamp = UIKit.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Rotation = -9,
		ZIndex = 31,
		Parent = holder,
	})
	local border = UIKit.stroke(stamp, 10, UIKit.Colors.Red, true)
	UIKit.corner(stamp, UDim.new(0, 4))
	local text = UIKit.label({ Text = "YOU'RE FIRED!", Size = UDim2.fromScale(0.92, 0.8), Position = UDim2.fromScale(0.04, 0.1), TextColor3 = UIKit.Colors.Red, Stroke = 3, ZIndex = 32 })
	text.Parent = stamp
	local sc = UIKit.new("UIScale", { Scale = 3, Parent = text })
	local sc2 = UIKit.new("UIScale", { Scale = 1, Parent = stamp })
	border.Transparency = 1
	UIKit.tween(sc, 0.18, { Scale = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.18, function()
		border.Transparency = 0
		sc2.Scale = 1.08
		UIKit.tween(sc2, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	local by = UIKit.label({ Text = "", Font = UIKit.Body, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.4, 100), Size = UDim2.fromOffset(600, 34), ZIndex = 31 })
	by.Parent = f
	UIKit.autoScale(by)
	local count = UIKit.label({ Text = "", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.4, 140), Size = UDim2.fromOffset(400, 30), ZIndex = 31, TextColor3 = UIKit.Colors.Yellow })
	count.Parent = f
	UIKit.autoScale(count)
	task.spawn(function()
		local t0 = os.clock()
		local respawn = Players.RespawnTime > 0 and Players.RespawnTime or 4
		while f.Parent do
			if lastKiller and os.clock() - lastKiller.t < 3 then
				by.Text = lastKiller.text
			end
			local left = math.max(0, math.ceil(respawn - (os.clock() - t0)))
			count.Text = left > 0 and ("BACK TO WORK IN " .. left .. "...") or "BACK TO WORK!"
			task.wait(0.1)
		end
	end)
end

------------------------------------------------------------------------
-- Boucle de mise à jour
------------------------------------------------------------------------
local function hpColor(r)
	if r > 0.6 then
		return C.HP
	elseif r > 0.3 then
		return C.Gold
	end
	return C.HPLow
end

local PHASE_TEXT = {
	Business = "BUSINESS AS USUAL",
	Events = "SOMETHING'S HAPPENING!",
	Warning = "FLOOR IS COLLAPSING!",
	Collapse = "TIMBEEER!",
}

local function update(dt)
	local c = myChar()
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local t = now()
	local clock = os.clock()
	local kit, charName = HUD.currentKit()
	local pulse = 0.5 + 0.5 * math.sin(clock * 8)
	local touch = UIKit.isTouch()

	-- PV : la barre suit, le segment « perdu » attend puis se vide, flash + secousse au coup, alerte PV bas
	if hum then
		local r = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
		if refs.lastHP and hum.Health < refs.lastHP - 0.5 then
			local dmg = refs.lastHP - hum.Health
			refs.trailHold = clock + 0.45
			refs.hp.Flash.BackgroundTransparency = 0.05
			UIKit.tween(refs.hp.Flash, 0.3, { BackgroundTransparency = 1 })
			refs.shakeT = clock
			refs.shakeAmp = math.clamp(dmg / 3, 2, 7)
			refs.vigFlash = math.clamp(dmg / 25, 0.25, 0.75)
		elseif refs.lastHP and hum.Health > refs.lastHP + 0.5 then
			refs.hp.Flash.BackgroundColor3 = C.Heal
			refs.hp.Flash.BackgroundTransparency = 0.4
			UIKit.tween(refs.hp.Flash, 0.4, { BackgroundTransparency = 1 })
			task.delay(0.4, function()
				refs.hp.Flash.BackgroundColor3 = UIKit.White
			end)
		end
		refs.lastHP = hum.Health
		refs.hpShown += (r - refs.hpShown) * math.min(1, dt * 16)
		if r > refs.trailShown then
			refs.trailShown = r
		elseif clock > (refs.trailHold or 0) then
			refs.trailShown += (r - refs.trailShown) * math.min(1, dt * 4)
		end
		refs.hp.Fill.Size = UDim2.fromScale(math.max(refs.hpShown, 0.001), 1)
		refs.hp.Trail.Size = UDim2.fromScale(math.max(refs.trailShown, 0.001), 1)
		local low = r <= 0.3 and hum.Health > 0
		refs.hp.Fill.BackgroundColor3 = low and C.HPLow:Lerp(C.Peach, pulse) or hpColor(r)
		local shownHP = math.abs(refs.hpShown - r) < 0.004 and math.ceil(hum.Health) or math.ceil(refs.hpShown * hum.MaxHealth)
		refs.hp.Text.Text = math.max(shownHP, 0) .. " / " .. math.floor(hum.MaxHealth)
		refs.statusStroke.Color = low and C.Blood:Lerp(C.HPLow, pulse) or UIKit.Black
		refs.vigFlash = math.max(0, (refs.vigFlash or 0) - dt * 2.4)
		setVignette(math.max(low and (0.2 + 0.22 * pulse) or 0, refs.vigFlash))
	else
		setVignette(0)
	end
	-- secousse de la carte quand on prend un coup
	local sk = clock - (refs.shakeT or -10)
	if sk < 0.25 then
		local a = (1 - sk / 0.25) * (refs.shakeAmp or 4)
		refs.status.Position = UDim2.new(0, 14 + (math.random() * 2 - 1) * a, 0, 62 + (math.random() * 2 - 1) * a)
	elseif refs.status.Position.X.Offset ~= 14 or refs.status.Position.Y.Offset ~= 62 then
		refs.status.Position = UDim2.new(0, 14, 0, 62)
	end
	refs.charName.Text = kit and string.upper(kit.DisplayName) or string.upper(player.DisplayName)
	refs.charName.TextColor3 = kit and kit.Color or UIKit.White
	refs.portraitBox.BackgroundColor3 = kit and kit.Color or UIKit.Colors.PanelLight

	-- Overtime / ultime
	local transformed = c and c:GetAttribute("Transformed") == true
	local ot = c and c:GetAttribute("Overtime") or 0
	local ultReady = transformed and c:GetAttribute("UltReady") == true
	local ultName = c and c:GetAttribute("UltName")
	local ready = (not transformed) and ot >= 100
	local fillR, c0, c1, label
	if transformed then
		local dur = kit and kit.Transformation and kit.Transformation.Duration or 20
		local left = math.max(0, (c:GetAttribute("TransformUntil") or t) - t)
		fillR = left / dur
		c0, c1 = C.Fire, C.Gold
		label = (ultReady and "ULT READY!  " or "OVERTIME!  ") .. math.ceil(left) .. "s"
	elseif ready then
		fillR = 1
		c0, c1 = UIKit.Colors.Orange, C.Glow
		label = "OVERTIME READY!"
		if not otTipShown then
			otTipShown = true
			HUD.toast(touch and "Your OVERTIME meter is full! Tap OT to transform!" or "Your OVERTIME meter is full! Press G to transform!", C.Amber, 5)
		end
	else
		fillR = ot / 100
		c0, c1 = UIKit.Colors.Orange, C.Amber
		label = "OVERTIME " .. math.floor(ot) .. "%"
	end
	refs.otShown += (math.clamp(fillR, 0, 1) - refs.otShown) * math.min(1, dt * 10)
	refs.ot.Fill.Size = UDim2.fromScale(math.max(refs.otShown, 0.001), 1)
	local hot = ready or transformed
	local band = hot and 0 or 0.45
	refs.otFlow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, c0),
		ColorSequenceKeypoint.new(0.4, c0:Lerp(c1, 0.6)),
		ColorSequenceKeypoint.new(0.5, UIKit.White:Lerp(c1, band)),
		ColorSequenceKeypoint.new(0.6, c0:Lerp(c1, 0.6)),
		ColorSequenceKeypoint.new(1, c0),
	})
	refs.otFlow.Offset = Vector2.new((clock * (hot and 1.3 or 0.45)) % 2 - 1, 0)
	local glowOn = ready or ultReady
	refs.otGlow.BackgroundTransparency = glowOn and (0.2 + 0.5 * (1 - pulse)) or (transformed and 0.75 or 1)
	refs.otGlow.BackgroundColor3 = ultReady and C.Fire or C.Gold
	refs.otStroke.Color = glowOn and UIKit.White:Lerp(UIKit.Colors.Yellow, pulse) or (transformed and UIKit.Colors.Orange or UIKit.Black)
	refs.ot.Text.Text = label
	refs.otBadge.Rotation = glowOn and math.sin(clock * 12) * 9 or 0
	refs.otBadge.BackgroundColor3 = ultReady and C.Fire or UIKit.Colors.Orange
	if glowOn and clock - (refs.sparkT or 0) > 0.05 then
		refs.sparkT = clock
		spark(refs.otSparks, ultReady and C.Fire or UIKit.Colors.Yellow)
	end
	refs.otPrompt.Visible = ready
	if ready then
		refs.otPromptScale.Scale = 1 + 0.08 * pulse
	end
	refs.ultTag.Visible = ultReady
	if ultReady then
		refs.ultTagLabel.Text = string.upper(tostring(ultName or "ULTIMATE")) .. "!"
		refs.ultTag.BackgroundColor3 = (kit and kit.Color or C.Fire):Lerp(C.Fire, 0.35)
		refs.ultTagStroke.Color = UIKit.White:Lerp(UIKit.Colors.Yellow, pulse)
	end
	-- invite centrale de l'ultime (apparaît avec un « pop », pulse tant qu'elle est prête)
	if ultReady ~= refs.ultShown then
		refs.ultShown = ultReady
		refs.ultPrompt.Visible = ultReady
		if ultReady then
			UIKit.pop(refs.ultPrompt, 1.35)
			UIKit.Theme.click(0.6)
		end
		-- les toasts remontent pour laisser la place à l'invite de l'ultime
		UIKit.tween(refs.toasts, 0.25, { Position = UDim2.new(0.5, 0, 1, ultReady and (touch and -200 or -240) or -150) }, Enum.EasingStyle.Back)
	end
	if ultReady then
		refs.ultName.Text = string.upper(tostring(ultName or "ULTIMATE")) .. "!"
		if refs.ultIcon then
			setAttackIcon(refs.ultIcon, charName and ("Ult:" .. charName) or "Transform", kit and kit.Color, "Ult")
			refs.ultIcon.Rotation = math.sin(clock * 3) * 5
		end
		refs.ultPulse.Scale = 1 + 0.05 * pulse
		refs.ultRibbon.BackgroundColor3 = kit and kit.Color or UIKit.Colors.Orange
		refs.ultRibbon.Rotation = -2 + math.sin(clock * 3) * 1.2
		refs.ultRibbonGrad.Offset = Vector2.new((clock * 0.9) % 2 - 1, 0)
		refs.ultRibbonStroke.Color = UIKit.White:Lerp(UIKit.Colors.Yellow, pulse)
		if clock - (refs.ultSparkT or 0) > 0.04 then
			refs.ultSparkT = clock
			spark(refs.ultSparks, math.random() < 0.5 and C.Glow or (kit and kit.Color or UIKit.White))
		end
	end

	-- XP / grade
	local xp = player:GetAttribute("XP") or 0
	local gi = 1
	for i, g in ipairs(Grades.List) do
		if xp >= g.XP then
			gi = i
		end
	end
	local g, nextG = Grades.List[gi], Grades.List[gi + 1]
	refs.grade.Text = string.upper(g.Name)
	refs.grade.TextColor3 = g.Color
	refs.gradeStroke.Color = g.Color:Lerp(UIKit.Colors.Black, 0.55)
	-- jauge = progression vers le niveau suivant (grade affiché dans la pastille)
	local lvl = player:GetAttribute("Level") or 1
	local into = player:GetAttribute("LevelXP") or 0
	local need = player:GetAttribute("LevelNeed") or 0
	if refs.levelNum and refs.levelNum.Text ~= tostring(lvl) then
		refs.levelNum.Text = tostring(lvl)
	end
	if need > 0 then
		refs.xp.Fill.Size = UDim2.fromScale(math.clamp(into / need, 0.001, 1), 1)
		refs.xp.Text.Text = "LV " .. lvl .. "   " .. into .. " / " .. need .. " XP"
	elseif player:GetAttribute("Level") then
		refs.xp.Fill.Size = UDim2.fromScale(1, 1)
		refs.xp.Text.Text = "LV " .. lvl .. " - MAX LEVEL"
	elseif nextG then
		local pct = (xp - g.XP) / (nextG.XP - g.XP)
		refs.xp.Fill.Size = UDim2.fromScale(math.clamp(pct, 0.001, 1), 1)
		refs.xp.Text.Text = xp .. " / " .. nextG.XP .. " XP"
	else
		refs.xp.Fill.Size = UDim2.fromScale(1, 1)
		refs.xp.Text.Text = xp .. " XP - TOP OF THE LADDER"
	end
	if (ReplicatedStorage:GetAttribute("XPMultiplier") or 1) > 1 then
		refs.xp.Text.Text ..= "  x" .. ReplicatedStorage:GetAttribute("XPMultiplier")
	end

	-- Attaques (PC)
	if refs.abilities.Visible then
		local list = kit and (transformed and kit.TransAttacks or kit.Attacks) or {}
		local base = kit and kit.Color or C.SlotBlue
		for i, s in ipairs(refs.slots) do
			local id = list[i]
			s.name.Text = id and string.upper(HUD.attackName(id)) or "-"
			setAttackIcon(s.icon, id or "Hit", kit and kit.Color, id and attackKind(id) or "Melee")
			s.frame.BackgroundColor3 = transformed and C.Fire:Lerp(UIKit.Colors.Orange, pulse) or base:Lerp(UIKit.Colors.Black, 0.2)
			s.stroke.Color = transformed and UIKit.Colors.Yellow or UIKit.Black
		end
		refs.gFill.Size = UDim2.fromScale(1, transformed and 1 or math.clamp(ot / 100, 0, 1))
		refs.gFill.BackgroundColor3 = ultReady and C.Fire:Lerp(C.Gold, pulse)
			or (ready or transformed) and UIKit.Colors.Orange:Lerp(C.Glow, pulse)
			or C.Amber
		refs.gStroke.Color = glowOn and UIKit.White:Lerp(UIKit.Colors.Yellow, pulse) or UIKit.Black
		refs.gName.Text = ultReady and "ULT!" or transformed and "ACTIVE!" or ready and "READY!" or "OVERTIME"
		setAttackIcon(refs.gIcon, (ultReady and charName) and ("Ult:" .. charName) or "Transform", ultReady and kit and kit.Color or nil, ultReady and "Ult" or "Bolt")
		local gs = refs.gSlot:FindFirstChild("SlotScale")
		if gs and glowOn then
			gs.Scale = 1 + 0.06 * pulse
			refs.gGlowing = true
		elseif gs and refs.gGlowing then
			refs.gGlowing = false
			gs.Scale = 1
		end
	end
	updateCooldowns()

	-- Cash (compte progressivement vers la valeur réelle)
	if refs.cashText then
		local target = tonumber(player:GetAttribute("Cash")) or 0
		refs.cashShown += (target - refs.cashShown) * math.min(1, dt * 8)
		if math.abs(target - refs.cashShown) < 1 then
			refs.cashShown = target
		end
		refs.cashText.Text = fmtMoney(math.floor(refs.cashShown + 0.5))
	end

	-- Étage
	local fn = ReplicatedStorage:GetAttribute("FloorNumber")
	refs.floor.Visible = fn ~= nil
	if fn then
		refs.floorNum.Text = "FLOOR " .. fn
		refs.floorName.Text = string.upper(ReplicatedStorage:GetAttribute("FloorDisplay") or UIKit.pretty(ReplicatedStorage:GetAttribute("FloorName")) or "")
		local phase = ReplicatedStorage:GetAttribute("Phase")
		local ends = ReplicatedStorage:GetAttribute("PhaseEndsAt")
		local txt = PHASE_TEXT[phase or ""] or ""
		if ends and phase ~= "Collapse" then
			txt ..= "  " .. UIKit.fmtTime(ends - t)
		end
		refs.phase.Text = txt
		local danger = phase == "Warning" or phase == "Collapse"
		refs.phase.TextColor3 = danger and C.HPLow:Lerp(UIKit.Colors.Yellow, pulse) or C.Sky
		if refs.floorStroke then
			refs.floorStroke.Color = danger and C.Blood:Lerp(C.HPLow, pulse) or UIKit.Black
		end
	end
end

------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------
local function hookCharacter(c)
	if refs.fired then
		refs.fired:Destroy()
		refs.fired = nil
	end
	refs.hpShown, refs.trailShown, refs.lastHP = 1, 1, nil
	onCombo(0)
	task.delay(1.2, refreshPortrait)
	c:GetAttributeChangedSignal("CharacterName"):Connect(function()
		task.delay(1, refreshPortrait)
	end)
	c:GetAttributeChangedSignal("Transformed"):Connect(function()
		task.delay(1.5, refreshPortrait)
	end)
	c:GetAttributeChangedSignal("ComboCount"):Connect(function()
		onCombo(c:GetAttribute("ComboCount"))
	end)
	local hum = c:WaitForChild("Humanoid", 10)
	if hum then
		hum.Died:Connect(function()
			if player.Character == c then
				showFired()
			end
		end)
	end
end

function HUD.init(ctx)
	for _, t in ipairs({ Enum.CoreGuiType.Health, Enum.CoreGuiType.Backpack, Enum.CoreGuiType.PlayerList }) do
		pcall(function()
			StarterGui:SetCoreGuiEnabled(t, false)
		end)
	end

	ctxRef = ctx
	gui = UIKit.screen("HUD", 5)
	HUD.gui = gui
	buildVignette()
	buildStatus()
	buildFloor()
	buildKillFeed()
	refs.banner = UIKit.new("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 104),
		Size = UDim2.fromOffset(760, 120),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = gui,
	})
	UIKit.autoScale(refs.banner)
	refs.toasts = UIKit.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(700, 170),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	UIKit.autoScale(refs.toasts)
	UIKit.new("UIListLayout", {
		Padding = UDim.new(0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = refs.toasts,
	})
	buildCombo()
	buildAbilities()
	buildUltPrompt()
	buildTasks()
	buildCash()
	buildShop()
	buildCombos()

	-- un seul dock (MetaDockController) ; ouvrir un panneau ferme les autres (registre UIKit)
	HUD.addMenuButton("TASKS 0/3", UIKit.Colors.Green, function()
		if refs.tasks then
			UIKit.togglePanel(refs.tasks)
		end
	end, 20)
	HUD.addMenuButton("COMBOS", UIKit.Colors.Cyan, function()
		if refs.combos then
			UIKit.togglePanel(refs.combos)
		end
	end, 25)
	HUD.addMenuButton("SHOP", C.Gold, function()
		if refs.shop then
			UIKit.togglePanel(refs.shop)
		end
	end, 30)
	for _, attr in ipairs({ "Tasks", "TasksWeekly", "TaskRerolls" }) do
		player:GetAttributeChangedSignal(attr):Connect(refreshTasks)
	end
	refreshTasks()
	task.spawn(function()
		while true do
			task.wait(0.5)
			pcall(tickTaskClocks)
		end
	end)
	-- boutique ouverte : suit le Cash, les mallettes et les déblocages
	local function shopDirty()
		if refs.shop and refs.shop.Visible then
			fillShop()
		end
	end
	player:GetAttributeChangedSignal("Cash"):Connect(shopDirty)
	player:GetAttributeChangedSignal("Crates"):Connect(shopDirty)
	task.spawn(function()
		local rem = ReplicatedStorage:WaitForChild("Remotes", 30)
		local ev = rem and rem:WaitForChild("UnlockState", 60)
		if ev then
			ev.OnClientEvent:Connect(function(st)
				if type(st) == "table" and type(st.Owned) == "table" then
					ownedJobs = st.Owned
					shopDirty()
				end
			end)
		end
	end)

	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end
	player.CharacterAdded:Connect(hookCharacter)

	RunService.RenderStepped:Connect(function(dt)
		local ok, err = pcall(update, dt)
		if not ok and not refs.warned then
			refs.warned = true
			warn("[HUD] " .. tostring(err))
		end
	end)

	-- remotes (attendues dans des threads séparés : ne bloque pas les autres contrôleurs)
	local Net = require(ReplicatedStorage.Shared.Modules.Net)
	task.spawn(function()
		local rem = ReplicatedStorage:WaitForChild("Remotes", 30)
		local ev = rem and rem:WaitForChild("CashPopup", 60)
		if ev then
			ev.OnClientEvent:Connect(cashPopup)
		end
	end)
	task.spawn(function()
		Net.get("Banner").OnClientEvent:Connect(HUD.banner)
	end)
	task.spawn(function()
		Net.get("LevelUp").OnClientEvent:Connect(levelUpPopup)
	end)
	task.spawn(function()
		Net.get("Toast").OnClientEvent:Connect(function(d)
			if type(d) == "table" then
				HUD.toast(d.text, d.color)
			end
		end)
	end)
	task.spawn(function()
		Net.get("KillFeed").OnClientEvent:Connect(function(entry)
			if type(entry) ~= "table" then
				return
			end
			addFeed(entry)
			if entry.victimId == player.UserId and entry.victimId ~= 0 then
				local txt = entry.kind == "Fired" and ("by " .. tostring(entry.killer) .. (entry.weapon and (" (" .. entry.weapon .. ")") or ""))
					or entry.kind == "HR" and "HR let you go."
					or "You resigned."
				lastKiller = { text = txt, t = os.clock() }
			end
			if entry.kind == "Fired" and entry.killerId == player.UserId and not likeShown then
				likeShown = true
				task.delay(2.5, function()
					HUD.toast("Having fun? Leave a LIKE on the game page!", C.Sky, 6)
				end)
			end
		end)
	end)
end

return HUD
