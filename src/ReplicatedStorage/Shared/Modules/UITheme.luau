--[[
	UITheme — thème visuel commun (style « bureau cartoon arcade » : polices pixel, gros contours, couleurs vives).
	Utilisable côté client ET serveur (aucun effet de bord au require, sauf le son de clic créé à la demande).

	Polices (vérifiées en rendu dans Studio) :
		UITheme.Display  = Press Start 2P (Bold)  -> titres, chiffres, boutons, onomatopées
		UITheme.Body     = Silkscreen (Bold)      -> petits textes, descriptions (pixel mais très lisible)
		UITheme.DisplayEnum = Enum.Font.Arcade    -> même police que Display pour les API qui veulent un Enum.Font

	Aides :
		UITheme.label(props)    TextLabel (props.Body = police texte, props.Stroke = épaisseur/false, props.MaxText/MinText)
		UITheme.button(props)   bouton pixel 3D (props.Color, props.Text, props.TextColor3, props.Round, props.TextSize=UDim2)
		UITheme.panel(props)    panneau sombre à double bordure (props.Accent = couleur de la bordure intérieure)
		UITheme.shadowed(props) cadre + ombre portée décalée (renvoie holder, face)
		UITheme.pop(obj, peak)  apparition « pop » ; UITheme.tween(obj, t, props, style, dir)
		UITheme.applyFont(root) / UITheme.hookFonts(root) : remplace les anciennes polices (LuckiestGuy, Fredoka…)
		UITheme.click()         petit son de clic (Config/Sounds UIClick)
]]
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = {}

------------------------------------------------------------------------
-- Polices
------------------------------------------------------------------------
UITheme.DisplayFamily = "rbxasset://fonts/families/PressStart2P.json"
UITheme.BodyAssetId = 12187371840 -- Silkscreen (bibliothèque de polices Roblox)
UITheme.Display = Font.new(UITheme.DisplayFamily, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
UITheme.DisplayRegular = Font.new(UITheme.DisplayFamily, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
UITheme.Body = Font.fromId(UITheme.BodyAssetId, Enum.FontWeight.Bold, Enum.FontStyle.Normal)
UITheme.BodyRegular = Font.fromId(UITheme.BodyAssetId, Enum.FontWeight.Regular, Enum.FontStyle.Normal)
UITheme.DisplayEnum = Enum.Font.Arcade

------------------------------------------------------------------------
-- Couleurs
------------------------------------------------------------------------
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
UITheme.rgb = rgb

UITheme.Colors = {
	Ink = rgb(18, 14, 30), -- contours
	Shadow = rgb(10, 8, 20),
	Panel = rgb(36, 32, 62),
	PanelDark = rgb(24, 21, 44),
	PanelLight = rgb(70, 62, 120),
	Slot = rgb(52, 48, 86),
	Paper = rgb(255, 248, 228),
	White = rgb(255, 255, 255),
	Muted = rgb(170, 165, 205),
	Yellow = rgb(255, 214, 50),
	Orange = rgb(255, 138, 30),
	Red = rgb(240, 62, 62),
	Green = rgb(90, 214, 96),
	Blue = rgb(60, 150, 255),
	Cyan = rgb(80, 215, 255),
	Pink = rgb(255, 95, 200),
	Purple = rgb(165, 95, 255),
	Gold = rgb(255, 196, 40),
	Cash = rgb(110, 235, 120),
}
UITheme.Rarity = {
	Base = rgb(165, 165, 178),
	Rare = rgb(60, 150, 255),
	Epic = rgb(170, 85, 255),
	Legendary = rgb(255, 192, 30),
}

function UITheme.darken(c: Color3, k: number?): Color3
	return c:Lerp(Color3.new(0, 0, 0), k or 0.35)
end
function UITheme.lighten(c: Color3, k: number?): Color3
	return c:Lerp(Color3.new(1, 1, 1), k or 0.35)
end

------------------------------------------------------------------------
-- Utilitaires
------------------------------------------------------------------------
function UITheme.new(class: string, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function UITheme.tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

-- vrai si le rayon est « rond » (cercle, pilule) : le contour doit alors suivre la courbe
local function isRoundRadius(r: UDim)
	return r.Scale > 0.05 or r.Offset >= 10
end

-- coins presque carrés = look pixel
function UITheme.corner(parent, px)
	local c = UITheme.new("UICorner", { CornerRadius = typeof(px) == "UDim" and px or UDim.new(0, px or 4), Parent = parent })
	-- un contour en onglet (Miter) sur un cercle dessine un carré plein : on passe en jointure ronde
	if parent and isRoundRadius(c.CornerRadius) then
		for _, s in ipairs(parent:GetChildren()) do
			if s:IsA("UIStroke") then
				s.LineJoinMode = Enum.LineJoinMode.Round
			end
		end
	end
	return c
end

-- contour : border = cadre, sinon texte. Jointures en onglet (angles nets).
function UITheme.stroke(parent, thickness, color, border)
	local uc = parent and parent:FindFirstChildOfClass("UICorner")
	return UITheme.new("UIStroke", {
		Thickness = thickness or 3,
		Color = color or UITheme.Colors.Ink,
		ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual,
		LineJoinMode = (border and uc and isRoundRadius(uc.CornerRadius)) and Enum.LineJoinMode.Round or Enum.LineJoinMode.Miter,
		Parent = parent,
	})
end

function UITheme.sizeLimit(label, maxSize, minSize)
	local c = label:FindFirstChildOfClass("UITextSizeConstraint") or UITheme.new("UITextSizeConstraint", { Parent = label })
	c.MaxTextSize = maxSize or 100
	c.MinTextSize = minSize or 1
	return c
end

-- dégradé « pixel » : bande claire en haut, bloc, bande sombre en bas (marches nettes)
function UITheme.bevel(obj, lipStart, dark)
	local s = lipStart or 0.74
	local d = dark or 0.7
	return UITheme.new("UIGradient", {
		Name = "Bevel",
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(s, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(math.min(s + 0.001, 0.999), Color3.new(d, d, d)),
			ColorSequenceKeypoint.new(1, Color3.new(d, d, d)),
		}),
		Parent = obj,
	})
end

-- reflet blanc en haut d'un bouton / d'une case
function UITheme.shine(obj, z)
	return UITheme.new("Frame", {
		Name = "Shine",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 4, 0, 3),
		Size = UDim2.new(1, -8, 0, 3),
		ZIndex = z or obj.ZIndex,
		Active = false,
		Parent = obj,
	})
end

------------------------------------------------------------------------
-- Son de clic
------------------------------------------------------------------------
local clickSounds
local lastClick = 0
function UITheme.click(volume)
	if not RunService:IsClient() then
		return
	end
	if os.clock() - lastClick < 0.05 then
		return
	end
	lastClick = os.clock()
	if clickSounds == nil then
		clickSounds = false
		local ok, Sounds = pcall(function()
			return require(ReplicatedStorage.Shared.Config.Sounds)
		end)
		if ok and type(Sounds) == "table" and type(Sounds.UIClick) == "table" then
			clickSounds = Sounds.UIClick
		end
	end
	if not clickSounds or #clickSounds == 0 then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = clickSounds[math.random(1, #clickSounds)]
	s.Volume = volume or 0.5
	s.PlaybackSpeed = 0.95 + math.random() * 0.15
	s.Parent = game:GetService("SoundService")
	s:Play()
	game:GetService("Debris"):AddItem(s, 2)
end

------------------------------------------------------------------------
-- Texte
------------------------------------------------------------------------
local LABEL_SKIP = { Stroke = true, Body = true, MaxText = true, MinText = true, StrokeColor = true }

function UITheme.label(props)
	props = props or {}
	local l = UITheme.new("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = props.Body and UITheme.Body or UITheme.Display,
		TextScaled = true,
		TextColor3 = UITheme.Colors.White,
		Text = "",
		Size = UDim2.fromScale(1, 1),
	})
	for k, v in pairs(props) do
		if not LABEL_SKIP[k] then
			l[k] = v
		end
	end
	if props.Stroke ~= false then
		UITheme.stroke(l, props.Stroke or 2.5, props.StrokeColor)
	end
	if props.MaxText or props.MinText then
		UITheme.sizeLimit(l, props.MaxText, props.MinText)
	end
	return l
end

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
function UITheme.pop(obj, peak)
	local s = obj:FindFirstChild("AutoScale") or obj:FindFirstChild("PopScale") or UITheme.new("UIScale", { Name = "PopScale", Parent = obj })
	local base = s:GetAttribute("Base") or 1
	s.Scale = 0.3 * base
	UITheme.tween(s, 0.14, { Scale = (peak or 1.15) * base }, Enum.EasingStyle.Back)
	task.delay(0.14, function()
		UITheme.tween(s, 0.12, { Scale = s:GetAttribute("Base") or 1 }, Enum.EasingStyle.Quad)
	end)
	return s
end

-- petite secousse en rotation (bannières, tampons)
function UITheme.wobble(obj, amp, base)
	task.spawn(function()
		local b = base or obj.Rotation
		for i = 1, 6 do
			if not obj.Parent then
				return
			end
			obj.Rotation = b + (i % 2 == 0 and 1 or -1) * (amp or 3) * (1 - i / 7)
			task.wait(0.04)
		end
		obj.Rotation = b
	end)
end

------------------------------------------------------------------------
-- Boutons
------------------------------------------------------------------------
local BUTTON_SKIP = { Color = true, Text = true, TextColor3 = true, Round = true, TextSize = true, Body = true, NoSound = true }

-- bouton pixel 3D : biseau, reflet, contour net ; survol = voile clair + reflet qui balaie ; appui = s'enfonce
function UITheme.button(props)
	props = props or {}
	local color = props.Color or UITheme.Colors.Yellow
	local b = UITheme.new("TextButton", {
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		BackgroundColor3 = color,
		Size = UDim2.fromOffset(140, 44),
	})
	for k, v in pairs(props) do
		if not BUTTON_SKIP[k] then
			b[k] = v
		end
	end
	local radius = props.Round and UDim.new(0.5, 0) or UDim.new(0, 6)
	UITheme.corner(b, radius)
	local st = UITheme.stroke(b, 3, UITheme.Colors.Ink, true)
	if not props.Round then
		UITheme.bevel(b)
		UITheme.shine(b, b.ZIndex)
	else
		UITheme.new("UIGradient", {
			Name = "Bevel",
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(225, 225, 225)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)),
			}),
			Parent = b,
		})
		-- reflet en croissant en haut du bouton rond
		local gl = UITheme.new("Frame", {
			Name = "Shine",
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.08),
			Size = UDim2.fromScale(0.62, 0.22),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BackgroundTransparency = 0.7,
			BorderSizePixel = 0,
			ZIndex = b.ZIndex,
			Active = false,
			Parent = b,
		})
		UITheme.corner(gl, UDim.new(0.5, 0))
	end
	-- voile de survol (ne touche pas BackgroundColor3 : les autres scripts le changent librement)
	local hover = UITheme.new("Frame", {
		Name = "Hover",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = b.ZIndex,
		Active = false,
		Parent = b,
	})
	UITheme.corner(hover, radius)
	-- reflet qui balaie au survol
	local clip = UITheme.new("Frame", {
		Name = "GlintClip",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Size = UDim2.fromScale(1, 1),
		ZIndex = b.ZIndex,
		Active = false,
		Parent = b,
	})
	local glint = UITheme.new("Frame", {
		Name = "Glint",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(-0.3, 0.5),
		Size = UDim2.new(0, 14, 1, 0),
		Rotation = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		ZIndex = b.ZIndex,
		Active = false,
		Parent = clip,
	})
	local label = UITheme.label({
		Name = "Label",
		Text = props.Text or "",
		Body = props.Body,
		TextColor3 = props.TextColor3 or UITheme.Colors.White,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, props.Round and 0.5 or 0.45),
		Size = props.TextSize or UDim2.fromScale(0.84, 0.46),
		ZIndex = b.ZIndex + 1,
		Stroke = 2,
	})
	label.Parent = b
	local scale = UITheme.new("UIScale", { Name = "PressScale", Parent = b })
	local hovering, pressing, down = false, false, false
	local function refresh()
		UITheme.tween(scale, pressing and 0.05 or 0.14, { Scale = pressing and 0.92 or (hovering and 1.06 or 1) }, pressing and Enum.EasingStyle.Quad or Enum.EasingStyle.Back)
		UITheme.tween(hover, 0.1, { BackgroundTransparency = pressing and 0.7 or (hovering and 0.84 or 1) })
		-- le texte s'enfonce de 2 px (relatif : les scripts peuvent déplacer le texte après coup)
		if pressing ~= down then
			down = pressing
			label.Position = label.Position + UDim2.fromOffset(0, pressing and 2 or -2)
		end
		st.Color = hovering and UITheme.Colors.Shadow or UITheme.Colors.Ink
	end
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressing = true
			refresh()
			if not props.NoSound then
				UITheme.click()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			if not hovering then
				hovering = true
				glint.Position = UDim2.fromScale(-0.3, 0.5)
				UITheme.tween(glint, 0.35, { Position = UDim2.fromScale(1.3, 0.5) }, Enum.EasingStyle.Quad)
				UITheme.tween(label, 0.1, { Rotation = -3 })
			end
			refresh()
		end
	end)
	b.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			hovering = false
			UITheme.tween(label, 0.1, { Rotation = 0 })
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			pressing = false
		end
		refresh()
	end)
	b.MouseLeave:Connect(function()
		hovering, pressing = false, false
		label.Rotation = 0
		refresh()
	end)
	return b
end

------------------------------------------------------------------------
-- Panneaux
------------------------------------------------------------------------
-- panneau sombre en relief : double cadre, dégradé, lueur en haut, ombre interne en bas, coins d'accent pixel
function UITheme.panel(props)
	props = props or {}
	local accent = props.Accent
	local f = UITheme.new("Frame", {
		BackgroundColor3 = UITheme.Colors.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
	})
	for k, v in pairs(props) do
		if k ~= "Accent" then
			f[k] = v
		end
	end
	UITheme.corner(f, 6)
	UITheme.stroke(f, 3, UITheme.Colors.Ink, true)
	UITheme.new("UIGradient", {
		Name = "Shade",
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(215, 215, 225)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 165)),
		}),
		Parent = f,
	})
	-- lueur douce en haut (profondeur)
	local glow = UITheme.new("Frame", {
		Name = "TopGlow",
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 0.32, 0),
		ZIndex = f.ZIndex,
		Active = false,
		Parent = f,
	})
	UITheme.corner(glow, 4)
	UITheme.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.9, 1), Parent = glow })
	-- ombre interne en bas
	local inner = UITheme.new("Frame", {
		Name = "InnerShadow",
		AnchorPoint = Vector2.new(0, 1),
		BackgroundColor3 = UITheme.Colors.Shadow,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 3, 1, -3),
		Size = UDim2.new(1, -6, 0, 18),
		ZIndex = f.ZIndex,
		Active = false,
		Parent = f,
	})
	UITheme.corner(inner, 4)
	UITheme.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0.55), Parent = inner })
	-- bordure intérieure claire (double cadre façon jeu rétro)
	local inset = UITheme.new("Frame", {
		Name = "Inset",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 1, -8),
		ZIndex = f.ZIndex,
		Active = false,
		Parent = f,
	})
	UITheme.corner(inset, 3)
	local st = UITheme.stroke(inset, 2, accent or UITheme.Colors.PanelLight, true)
	st.Transparency = 0.15
	-- coins d'accent (petits « L » pixel)
	local cc = accent and UITheme.lighten(accent, 0.25) or UITheme.Colors.Muted
	for _, c in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local holder = UITheme.new("Frame", {
			Name = "Corner",
			AnchorPoint = Vector2.new(c[1], c[2]),
			Position = UDim2.new(c[1], c[1] == 0 and 7 or -7, c[2], c[2] == 0 and 7 or -7),
			Size = UDim2.fromOffset(10, 10),
			BackgroundTransparency = 1,
			ZIndex = f.ZIndex,
			Active = false,
			Parent = f,
		})
		UITheme.new("Frame", { BackgroundColor3 = cc, BorderSizePixel = 0, Position = UDim2.fromScale(0, c[2]), AnchorPoint = Vector2.new(0, c[2]), Size = UDim2.new(1, 0, 0, 3), ZIndex = f.ZIndex, Active = false, Parent = holder })
		UITheme.new("Frame", { BackgroundColor3 = cc, BorderSizePixel = 0, Position = UDim2.fromScale(c[1], 0), AnchorPoint = Vector2.new(c[1], 0), Size = UDim2.new(0, 3, 1, 0), ZIndex = f.ZIndex, Active = false, Parent = holder })
	end
	return f
end

-- cadre + ombre portée pixel (pour les éléments dont on contrôle la hiérarchie)
-- renvoie holder (transparent, à positionner) et face (le cadre visible)
function UITheme.shadowed(props, offset)
	props = props or {}
	local off = offset or 5
	local holder = UITheme.new("Frame", {
		Name = props.Name or "Shadowed",
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		AutomaticSize = props.AutomaticSize,
		LayoutOrder = props.LayoutOrder,
		Rotation = props.Rotation,
		ZIndex = props.ZIndex,
		Visible = props.Visible ~= false,
	})
	local shadow = UITheme.new("Frame", {
		Name = "Shadow",
		BackgroundColor3 = UITheme.Colors.Shadow,
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(off, off),
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex,
		Parent = holder,
	})
	local face = UITheme.new("Frame", {
		Name = "Face",
		BackgroundColor3 = props.Color or UITheme.Colors.Panel,
		BackgroundTransparency = props.Transparency or 0,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = props.ZIndex,
		Parent = holder,
	})
	local r = props.Corner or 6
	UITheme.corner(shadow, r)
	UITheme.corner(face, r)
	UITheme.stroke(face, props.StrokeThickness or 3, props.StrokeColor or UITheme.Colors.Ink, true)
	if props.Parent then
		holder.Parent = props.Parent
	end
	return holder, face, shadow
end

------------------------------------------------------------------------
-- Transitions d'ouverture / fermeture (panneaux, menus)
------------------------------------------------------------------------
local function scaleOf(obj)
	return obj:FindFirstChild("AutoScale") or obj:FindFirstChild("PopScale") or UITheme.new("UIScale", { Name = "PopScale", Parent = obj })
end

-- ouvre : glisse de 26 px vers le haut + grossit (rebond) ; renvoie true
function UITheme.open(obj)
	local s = scaleOf(obj)
	local base = s:GetAttribute("Base") or 1
	local home = obj:GetAttribute("HomePos")
	if not home then
		home = obj.Position
		obj:SetAttribute("HomePos", home)
	end
	local token = (obj:GetAttribute("AnimToken") or 0) + 1
	obj:SetAttribute("AnimToken", token)
	obj.Visible = true
	obj.Position = home + UDim2.fromOffset(0, 26)
	s.Scale = base * 0.82
	UITheme.tween(obj, 0.22, { Position = home }, Enum.EasingStyle.Back)
	UITheme.tween(s, 0.22, { Scale = base }, Enum.EasingStyle.Back)
	return true
end

-- ferme : rétrécit vite puis cache ; renvoie false
function UITheme.close(obj)
	if not obj.Visible then
		return false
	end
	local s = scaleOf(obj)
	local base = s:GetAttribute("Base") or 1
	local home = obj:GetAttribute("HomePos") or obj.Position
	local token = (obj:GetAttribute("AnimToken") or 0) + 1
	obj:SetAttribute("AnimToken", token)
	UITheme.tween(s, 0.12, { Scale = base * 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	UITheme.tween(obj, 0.12, { Position = home + UDim2.fromOffset(0, 16) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.12, function()
		if obj:GetAttribute("AnimToken") == token then
			obj.Visible = false
			obj.Position = home
			s.Scale = s:GetAttribute("Base") or 1
		end
	end)
	return false
end

function UITheme.toggle(obj)
	if obj.Visible then
		return UITheme.close(obj)
	end
	return UITheme.open(obj)
end

------------------------------------------------------------------------
-- Pastille de touche (clavier) : [G]
------------------------------------------------------------------------
function UITheme.keycap(props)
	props = props or {}
	local k = UITheme.new("Frame", {
		Name = props.Name or "Keycap",
		BackgroundColor3 = props.Color or UITheme.Colors.Paper,
		AnchorPoint = props.AnchorPoint or Vector2.new(0, 0),
		Position = props.Position or UDim2.new(),
		Size = props.Size or UDim2.fromOffset(26, 24),
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	UITheme.corner(k, 4)
	UITheme.stroke(k, 2, UITheme.Colors.Ink, true)
	UITheme.bevel(k, 0.7, 0.72)
	local l = UITheme.label({ Name = "Label", Text = props.Text or "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.78, 0.55), TextColor3 = props.TextColor3 or UITheme.Colors.Ink, Stroke = false, ZIndex = (props.ZIndex or 1) + 1 })
	l.Parent = k
	return k, l
end

------------------------------------------------------------------------
-- Icônes dessinées (Frames uniquement, pas d'images externes)
-- UITheme.icon(kind, parent, color?, z?) -> Frame "Icon" (taille 1x1 du parent par défaut)
-- kinds : Dash Lunge Projectile Melee AoE Slam Cone Grab Zone Barrier Buff Guard Counter Bolt Boot Ult
--         Person Tasks List Shop Admin Crate Cash Skull Check Coin
------------------------------------------------------------------------
local ICON_ALIAS = {
	SkyDrop = "Slam", ElbowDrop = "Slam", CartRush = "Lunge", BubblePrison = "Zone", Charge = "Lunge", Teleport = "Dash",
	Character = "Person", Combos = "List", Book = "List",
}
function UITheme.icon(kind, parent, color, z)
	kind = ICON_ALIAS[kind] or kind
	if type(kind) == "string" and not UITheme._iconKnown(kind) then
		local k = kind
		kind = string.find(k, "Drop") and "Slam" or string.find(k, "Rush") and "Lunge" or string.find(k, "Throw") and "Projectile"
			or string.find(k, "Shield") and "Guard" or string.find(k, "Trap") and "Zone" or "Melee"
	end
	local col = color or UITheme.Colors.White
	local zi = z or ((parent and parent:IsA("GuiObject")) and parent.ZIndex + 1 or 1)
	local root = UITheme.new("Frame", {
		Name = "Icon",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = zi,
	})
	UITheme.new("UIAspectRatioConstraint", { Parent = root })
	local function rect(x, y, w, h, rot, c, round, ax, ay)
		local f = UITheme.new("Frame", {
			BackgroundColor3 = c or col,
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(ax or 0.5, ay or 0.5),
			Position = UDim2.fromScale(x, y),
			Size = UDim2.fromScale(w, h),
			Rotation = rot or 0,
			ZIndex = zi,
			Parent = root,
		})
		if round then
			UITheme.corner(f, UDim.new(round, 0))
		end
		local s = UITheme.stroke(f, 2, UITheme.Colors.Ink, true)
		s.LineJoinMode = round and Enum.LineJoinMode.Round or Enum.LineJoinMode.Miter
		return f
	end
	local function ring(x, y, d, th, c)
		local f = UITheme.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(d, d), ZIndex = zi, Parent = root })
		UITheme.corner(f, UDim.new(0.5, 0))
		UITheme.stroke(f, th or 3, c or col, true)
		return f
	end
	local function chevron(x, y, s, dir)
		local d = dir or 1
		rect(x, y - s * 0.17, s * 0.62, s * 0.2, 45 * d)
		rect(x, y + s * 0.17, s * 0.62, s * 0.2, -45 * d)
	end
	local function arrowDown(x, y, s)
		rect(x, y - s * 0.12, s * 0.22, s * 0.5)
		rect(x - s * 0.13, y + s * 0.16, s * 0.42, s * 0.18, 45)
		rect(x + s * 0.13, y + s * 0.16, s * 0.42, s * 0.18, -45)
	end
	if kind == "Dash" or kind == "Lunge" then
		chevron(0.36, 0.5, 0.8)
		chevron(0.64, 0.5, 0.8)
		if kind == "Lunge" then
			rect(0.16, 0.5, 0.18, 0.1)
		end
	elseif kind == "Projectile" then
		rect(0.22, 0.34, 0.26, 0.08, 0, nil, 0.5)
		rect(0.18, 0.5, 0.34, 0.08, 0, nil, 0.5)
		rect(0.22, 0.66, 0.26, 0.08, 0, nil, 0.5)
		rect(0.66, 0.5, 0.42, 0.42, 0, nil, 0.5)
		rect(0.6, 0.42, 0.12, 0.12, 0, Color3.new(1, 1, 1), 0.5)
	elseif kind == "AoE" then
		ring(0.5, 0.5, 0.9, 3)
		ring(0.5, 0.5, 0.56, 3)
		rect(0.5, 0.5, 0.22, 0.22, 0, nil, 0.5)
	elseif kind == "Slam" then
		arrowDown(0.5, 0.42, 0.85)
		rect(0.5, 0.86, 0.86, 0.1)
		rect(0.14, 0.72, 0.1, 0.14, -30)
		rect(0.86, 0.72, 0.1, 0.14, 30)
	elseif kind == "Cone" then
		rect(0.14, 0.5, 0.74, 0.09, -24, nil, nil, 0, 0.5)
		rect(0.14, 0.5, 0.8, 0.09, 0, nil, nil, 0, 0.5)
		rect(0.14, 0.5, 0.74, 0.09, 24, nil, nil, 0, 0.5)
		rect(0.14, 0.5, 0.18, 0.18, 45)
	elseif kind == "Grab" then
		rect(0.5, 0.66, 0.5, 0.4, 0, nil, 0.2)
		for i = 0, 2 do
			rect(0.34 + i * 0.16, 0.34, 0.12, 0.32, 0, nil, 0.4)
		end
		rect(0.2, 0.58, 0.12, 0.28, -35, nil, 0.4)
	elseif kind == "Zone" then
		rect(0.5, 0.74, 0.86, 0.3, 0, nil, 0.5)
		rect(0.5, 0.36, 0.26, 0.3, 0, nil, 0.5)
		rect(0.5, 0.22, 0.14, 0.14, 45)
	elseif kind == "Barrier" then
		for i = 0, 2 do
			rect(0.22 + i * 0.28, 0.58, 0.16, 0.62)
		end
		rect(0.5, 0.24, 0.9, 0.12)
	elseif kind == "Buff" then
		rect(0.5, 0.62, 0.22, 0.5)
		rect(0.37, 0.34, 0.42, 0.18, -45)
		rect(0.63, 0.34, 0.42, 0.18, 45)
	elseif kind == "Guard" then
		rect(0.5, 0.38, 0.66, 0.44, 0, nil, 0.15)
		rect(0.5, 0.6, 0.48, 0.48, 45, nil, 0.1)
		rect(0.5, 0.46, 0.12, 0.4, 0, Color3.new(1, 1, 1))
	elseif kind == "Counter" then
		rect(0.46, 0.34, 0.6, 0.12)
		rect(0.74, 0.34, 0.24, 0.24, 45)
		rect(0.54, 0.66, 0.6, 0.12)
		rect(0.26, 0.66, 0.24, 0.24, 45)
	elseif kind == "Bolt" then
		rect(0.6, 0.27, 0.21, 0.46, 22)
		rect(0.5, 0.5, 0.52, 0.18, -18)
		rect(0.4, 0.73, 0.21, 0.46, 22)
	elseif kind == "Boot" then
		rect(0.4, 0.36, 0.26, 0.52)
		rect(0.56, 0.7, 0.58, 0.26, 0, nil, 0.3)
		rect(0.56, 0.86, 0.62, 0.08, 0, UITheme.Colors.Ink)
	elseif kind == "Ult" then
		for i = 0, 2 do
			rect(0.5, 0.5, 0.58, 0.58, i * 30)
		end
		rect(0.5, 0.5, 0.3, 0.3, 0, Color3.new(1, 1, 1), 0.5)
	elseif kind == "Person" then
		rect(0.5, 0.3, 0.36, 0.36, 0, nil, 0.5)
		rect(0.5, 0.76, 0.66, 0.4, 0, nil, 0.35)
	elseif kind == "Tasks" then
		rect(0.5, 0.54, 0.66, 0.8, 0, nil, 0.1)
		rect(0.5, 0.16, 0.34, 0.14, 0, UITheme.Colors.Muted)
		for i = 0, 2 do
			rect(0.56, 0.38 + i * 0.18, 0.34, 0.07, 0, UITheme.Colors.Ink)
			rect(0.3, 0.38 + i * 0.18, 0.09, 0.09, 0, i == 0 and UITheme.Colors.Green or UITheme.Colors.Muted)
		end
	elseif kind == "List" then
		rect(0.32, 0.5, 0.42, 0.74, -4, nil, 0.1)
		rect(0.68, 0.5, 0.42, 0.74, 4, nil, 0.1)
		rect(0.5, 0.5, 0.06, 0.74, 0, UITheme.Colors.Ink)
	elseif kind == "Shop" then
		ring(0.5, 0.32, 0.4, 3)
		rect(0.5, 0.64, 0.76, 0.56, 0, nil, 0.12)
		rect(0.5, 0.62, 0.2, 0.2, 0, Color3.new(1, 1, 1), 0.5)
	elseif kind == "Admin" then
		for i = 0, 3 do
			rect(0.5, 0.5, 0.24, 0.94, i * 45)
		end
		rect(0.5, 0.5, 0.66, 0.66, 0, nil, 0.5)
		rect(0.5, 0.5, 0.26, 0.26, 0, UITheme.Colors.Ink, 0.5)
	elseif kind == "Crate" then
		rect(0.5, 0.58, 0.8, 0.62, 0, nil, 0.1)
		rect(0.5, 0.32, 0.86, 0.18, 0, nil, 0.1)
		rect(0.5, 0.58, 0.14, 0.62, 0, UITheme.Colors.Yellow)
	elseif kind == "Cash" then
		rect(0.5, 0.5, 0.86, 0.56, -8, nil, 0.12)
		rect(0.5, 0.5, 0.28, 0.28, -8, Color3.new(1, 1, 1), 0.5)
	elseif kind == "Coin" then
		rect(0.5, 0.5, 0.8, 0.8, 0, nil, 0.5)
		ring(0.5, 0.5, 0.52, 2, UITheme.darken(col, 0.3))
	elseif kind == "Skull" then
		rect(0.5, 0.42, 0.7, 0.6, 0, nil, 0.45)
		rect(0.5, 0.74, 0.44, 0.24, 0, nil, 0.15)
		rect(0.36, 0.44, 0.16, 0.18, 0, UITheme.Colors.Ink, 0.5)
		rect(0.64, 0.44, 0.16, 0.18, 0, UITheme.Colors.Ink, 0.5)
	elseif kind == "Check" then
		rect(0.36, 0.6, 0.38, 0.16, 45)
		rect(0.6, 0.48, 0.62, 0.16, -50)
	else -- Melee : étoile d'impact
		rect(0.5, 0.5, 0.6, 0.6, 0)
		rect(0.5, 0.5, 0.6, 0.6, 45)
		rect(0.5, 0.5, 0.26, 0.26, 0, Color3.new(1, 1, 1), 0.5)
	end
	if parent then
		root.Parent = parent
		-- petites icônes (< 26 px) : contours fins pour rester lisibles
		local ok, sz = pcall(function()
			return root.AbsoluteSize.X
		end)
		if ok and sz > 0 and sz < 26 then
			for _, d in ipairs(root:GetDescendants()) do
				if d:IsA("UIStroke") then
					d.Thickness = math.min(d.Thickness, 1)
				end
			end
		end
	end
	return root
end
local KNOWN = {}
for _, k in ipairs({ "Dash", "Lunge", "Projectile", "Melee", "AoE", "Slam", "Cone", "Grab", "Zone", "Barrier", "Buff", "Guard", "Counter", "Bolt", "Boot", "Ult", "Person", "Tasks", "List", "Shop", "Admin", "Crate", "Cash", "Coin", "Skull", "Check" }) do
	KNOWN[k] = true
end
function UITheme._iconKnown(k)
	return KNOWN[k] == true
end

------------------------------------------------------------------------
-- Icônes d'attaque illustrées (Modules/AttackIcon + données Config/AttackIcons)
-- UITheme.attackIcon(key, parent, size?, opts?) -> Frame "AttackIcon" (nil si le module manque)
--   key = id d'attaque, "Ult:<CharId>", ou action "Dash" "Dropkick" "Block" "Transform" "Hit"
--   size = nombre (px) ou UDim2 (défaut : remplit le parent) ; opts = { Color, Tier, ZIndex, NoBadge }
-- UITheme.ultInfo(charId) -> nom, description de l'ultime du perso
------------------------------------------------------------------------
local attackIconMod
local function getAttackIcon()
	if attackIconMod == nil then
		attackIconMod = false
		local m = script.Parent:FindFirstChild("AttackIcon")
		if m then
			local ok, mod = pcall(require, m)
			attackIconMod = ok and type(mod) == "table" and mod or false
		end
	end
	return attackIconMod or nil
end
function UITheme.attackIcon(key, parent, size, opts)
	local AI = getAttackIcon()
	if not AI then
		return nil
	end
	local o = {}
	for k, v in pairs(opts or {}) do
		o[k] = v
	end
	if typeof(size) == "number" then
		o.Size = UDim2.fromOffset(size, size)
	elseif typeof(size) == "UDim2" then
		o.Size = size
	end
	return AI.build(key, parent, o)
end
function UITheme.ultInfo(charId)
	local AI = getAttackIcon()
	if AI and AI.ultInfo then
		return AI.ultInfo(charId)
	end
	return nil, nil
end

------------------------------------------------------------------------
-- Nombre qui défile (compteur) : UITheme.countUp(label, from, to, time, fmt)
------------------------------------------------------------------------
function UITheme.countUp(label, from, to, time, fmt)
	local f = fmt or function(n)
		return tostring(math.floor(n + 0.5))
	end
	local token = (label:GetAttribute("CountToken") or 0) + 1
	label:SetAttribute("CountToken", token)
	task.spawn(function()
		local t0, d = os.clock(), math.max(time or 0.6, 0.01)
		while label.Parent and label:GetAttribute("CountToken") == token do
			local a = math.clamp((os.clock() - t0) / d, 0, 1)
			local e = 1 - (1 - a) ^ 3
			label.Text = f(from + (to - from) * e)
			if a >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
	end)
end

------------------------------------------------------------------------
-- Remplacement des anciennes polices
------------------------------------------------------------------------
-- familles -> rôle ("D" = Display, "B" = Body)
local FAMILY_ROLE = {
	luckiestguy = "D",
	bangers = "D",
	denkone = "D",
	pressstart2p = "D",
	fredokaone = "B",
	nunito = "B",
	sourcesanspro = "B",
	gothambold = "B",
	gothamssm = "B",
}

local function roleOf(face: Font)
	local fam = string.lower(face.Family)
	if string.find(fam, tostring(UITheme.BodyAssetId), 1, true) then
		return nil -- déjà Silkscreen
	end
	local name = string.match(fam, "families/([%w_]+)%.json")
	if not name then
		return nil
	end
	local role = FAMILY_ROLE[name]
	if role == "D" and name == "pressstart2p" and face.Weight == Enum.FontWeight.Bold then
		return nil -- déjà au bon format
	end
	return role
end

function UITheme.fixFont(obj)
	if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
		return
	end
	if obj:GetAttribute("KeepFont") then
		return
	end
	local role = roleOf(obj.FontFace)
	if role == "D" then
		obj.FontFace = UITheme.Display
	elseif role == "B" then
		obj.FontFace = UITheme.Body
	end
end

function UITheme.applyFont(root)
	if not root then
		return
	end
	UITheme.fixFont(root)
	for _, d in ipairs(root:GetDescendants()) do
		UITheme.fixFont(d)
	end
end

-- applique maintenant + sur tout ce qui sera ajouté plus tard (et si la police change après coup)
function UITheme.hookFonts(root)
	if not root or root:GetAttribute("FontHooked") then
		return
	end
	root:SetAttribute("FontHooked", true)
	local function watch(d)
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			UITheme.fixFont(d)
			d:GetPropertyChangedSignal("FontFace"):Connect(function()
				UITheme.fixFont(d)
			end)
		end
	end
	for _, d in ipairs(root:GetDescendants()) do
		watch(d)
	end
	root.DescendantAdded:Connect(watch)
end

------------------------------------------------------------------------
-- Écran
------------------------------------------------------------------------
-- vrai si l'écran est petit (téléphone en paysage : hauteur < 500 px)
function UITheme.isSmallScreen(): boolean
	local cam = workspace.CurrentCamera
	return cam ~= nil and math.min(cam.ViewportSize.X, cam.ViewportSize.Y) < 500
end

return UITheme
