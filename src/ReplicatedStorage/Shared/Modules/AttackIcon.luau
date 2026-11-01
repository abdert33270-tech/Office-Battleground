--[[
	AttackIcon — icônes d'attaque illustrées (une par attaque, ultime et action de base).
	Chaque icône = cadre « carte » à la couleur du perso (dégradé + rayons + liseré selon le palier)
	+ sujet (emoji Twemoji rendu par Roblox, ou accessoire dessiné en Frames) + effet d'action
	(traits de vitesse, étoile d'impact, flèches, ondes, arcs de swing, éclairs…) + badge d'effet
	(PIN = punaise, contre/garde = bouclier, brûlure, ralenti, aveuglé, marque, étourdi…).
	Les données (couches de chaque icône) sont dans Config/AttackIcons.

	API :
		AttackIcon.build(key, parent, opts) -> Frame "AttackIcon" (carré, remplit le parent par défaut)
			key  : id d'attaque (Config/Attacks), "Ult:<CharId>" (ultime), ou action : "Dash" "Dropkick" "Block" "Transform" "Hit"
			opts : { Color = Color3 (fond ; défaut = couleur du perso), Tier = "Base"|"Trans"|"Ult"|"Slot",
			         Size = UDim2, ZIndex = number, NoBadge = bool, NoFrame = bool }
		AttackIcon.ultKey(charId) -> "Ult:<CharId>"
		AttackIcon.has(key) -> bool (icône dédiée existante)
		AttackIcon.ultInfo(charId) -> nom, description de l'ultime (partie lancée seulement)
	Lisible à 40 px (téléphone), détaillée à 64-80 px. Les contours suivent la taille réelle (AbsoluteSize).
	Ne fait AUCUN require de Config/Characters ou Config/Attacks hors partie lancée (Edit = blocage).
]]
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UITheme = require(script.Parent.UITheme)
local Icons = require(ReplicatedStorage.Shared.Config.AttackIcons)

local AttackIcon = {}

local INK = UITheme.Colors.Ink
local WHITE = Color3.new(1, 1, 1)
local YELLOW = Color3.fromRGB(255, 214, 50)
local RED = Color3.fromRGB(240, 62, 62)
local OL = 0.034 -- épaisseur de contour, en fraction de la taille de l'icône
local EMOJI_FONT = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

------------------------------------------------------------------------
-- Contexte de dessin : un conteneur carré, coordonnées 0..1 (y vers le bas)
------------------------------------------------------------------------
local Ctx = {}
Ctx.__index = Ctx

local function newCtx(parent, z, strokes, scale)
	return setmetatable({ parent = parent, z = z, strokes = strokes, scale = scale or 1 }, Ctx)
end

function Ctx:inst(class, props)
	local o = Instance.new(class)
	for k, v in pairs(props) do
		o[k] = v
	end
	if o:IsA("GuiObject") then
		o.ZIndex = self.z
		if o:IsA("Frame") then
			o.BorderSizePixel = 0
		end
	end
	o.Parent = self.parent
	return o
end

-- contour UIStroke dont l'épaisseur suit la taille de l'icône (mult x OL x taille)
function Ctx:stroke(obj, mult, color, transparency)
	local st = Instance.new("UIStroke")
	st.Color = color or INK
	st.Thickness = 2
	st.Transparency = transparency or 0
	st.LineJoinMode = Enum.LineJoinMode.Round
	st.ApplyStrokeMode = (obj:IsA("TextLabel") and Enum.ApplyStrokeMode.Contextual) or Enum.ApplyStrokeMode.Border
	st.Parent = obj
	table.insert(self.strokes, { st, mult or 1 })
	return st
end

-- sous-conteneur (pour dessiner un accessoire à une position / taille / rotation données)
function Ctx:sub(x, y, s, r)
	local f = self:inst("Frame", {
		Name = "G",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(s, s),
		Rotation = r or 0,
	})
	return newCtx(f, self.z, self.strokes, self.scale * s)
end

-- rectangle : round = rayon des coins (échelle 0..0.5), k = contour (false = aucun), tr = transparence
function Ctx:rect(x, y, w, h, r, color, round, k, tr)
	local f = self:inst("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h),
		Rotation = r or 0,
		BackgroundColor3 = color or WHITE,
		BackgroundTransparency = tr or 0,
	})
	if round and round > 0 then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(round, 0)
		c.Parent = f
	end
	if k ~= false then
		self:stroke(f, k or 1)
	end
	return f
end

function Ctx:circ(x, y, d, color, k, tr)
	return self:rect(x, y, d, d, 0, color, 0.5, k, tr)
end

-- anneau (cercle / ellipse vide) : épaisseur = mult x OL
function Ctx:ring(x, y, w, h, color, mult, tr)
	local f = self:inst("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w, h or w),
		BackgroundTransparency = 1,
	})
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	self:stroke(f, mult or 1, color or WHITE, tr)
	return f
end

-- anneau avec contour noir (couleur épaisse bordée d'encre)
function Ctx:inkRing(x, y, w, h, color, mult)
	self:ring(x, y, w, h, INK, (mult or 1.4) + 1.6)
	return self:ring(x, y, w, h, color, mult or 1.4)
end

-- segment arrondi de (x0,y0) à (x1,y1), épaisseur th (unités du conteneur)
function Ctx:seg(x0, y0, x1, y1, th, color, tr)
	local dx, dy = x1 - x0, y1 - y0
	local len = math.sqrt(dx * dx + dy * dy)
	local f = self:inst("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale((x0 + x1) / 2, (y0 + y1) / 2),
		Size = UDim2.fromScale(len + th, th),
		Rotation = math.deg(math.atan2(dy, dx)),
		BackgroundColor3 = color,
		BackgroundTransparency = tr or 0,
	})
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = f
	return f
end

-- polylignes bordées d'encre : passe noire plus épaisse puis passe couleur (jointures propres)
function Ctx:lines(groups, th, color)
	local e = 2 * OL / self.scale
	for pass = 1, 2 do
		for _, pts in ipairs(groups) do
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				if pass == 1 then
					self:seg(a[1], a[2], b[1], b[2], th + e, INK)
				else
					self:seg(a[1], a[2], b[1], b[2], th, color or WHITE)
				end
			end
		end
	end
end

function Ctx:emoji(e, x, y, s, r, tr, k)
	local l = self:inst("TextLabel", {
		Name = "Emoji",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x or 0.5, y or 0.5),
		Size = UDim2.fromScale((s or 0.62) * 1.16, (s or 0.62) * 1.16), -- le glyphe emoji est plus petit que sa boîte
		Rotation = r or 0,
		Text = e,
		TextScaled = true,
		FontFace = EMOJI_FONT,
		TextColor3 = WHITE,
		TextTransparency = tr or 0,
	})
	if k ~= false and not tr then
		self:stroke(l, k or 0.9)
	end
	return l
end

function Ctx:text(t, x, y, h, r, color, w, font)
	local l = self:inst("TextLabel", {
		Name = "Text",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(x, y),
		Size = UDim2.fromScale(w or 0.9, h),
		Rotation = r or 0,
		Text = t,
		TextScaled = true,
		FontFace = font or UITheme.Display,
		TextColor3 = color or WHITE,
	})
	self:stroke(l, 0.9)
	return l
end

------------------------------------------------------------------------
-- Effets d'action (fx)
------------------------------------------------------------------------
local FX = {}

-- traits de vitesse derrière un objet qui va dans la direction dir (degrés, 0 = droite)
function FX.speed(c, x, y, s, dir, color)
	local g = c:sub(x, y, s or 0.6, dir or 0)
	g:lines({
		{ { 0.06, 0.28 }, { 0.42, 0.28 } },
		{ { 0.0, 0.5 }, { 0.5, 0.5 } },
		{ { 0.12, 0.72 }, { 0.4, 0.72 } },
	}, 0.09, color or WHITE)
end

-- étoile d'impact (comic)
function FX.burst(c, x, y, s, color, inner)
	local g = c:sub(x, y, s or 0.5, 0)
	local e = 2.2 * OL / g.scale
	local col = color or YELLOW
	for _, r in ipairs({ 0, 45 }) do
		g:rect(0.5, 0.5, 0.7 + e, 0.7 + e, r, INK, nil, false)
	end
	for _, r in ipairs({ 0, 45 }) do
		g:rect(0.5, 0.5, 0.7, 0.7, r, col, nil, false)
	end
	for _, r in ipairs({ 22.5, 67.5 }) do
		g:rect(0.5, 0.5, 0.38, 0.38, r, inner or WHITE, nil, false)
	end
end

-- onde de choc au sol : ellipse + éclats qui volent
function FX.shock(c, x, y, s, color)
	s = s or 0.86
	local col = color or WHITE
	c:inkRing(x, y, s, s * 0.3, col, 1.3)
	c:inkRing(x, y, s * 0.55, s * 0.17, col, 1.1)
	local g = c:sub(x, y - s * 0.12, s, 0)
	g:lines({
		{ { 0.08, 0.3 }, { 0.0, 0.12 } },
		{ { 0.92, 0.3 }, { 1.0, 0.12 } },
		{ { 0.2, 0.18 }, { 0.16, 0.02 } },
		{ { 0.8, 0.18 }, { 0.84, 0.02 } },
	}, 0.05, col)
end

-- anneaux concentriques (son, onde autour de soi)
function FX.rings(c, x, y, s, n, color)
	n = n or 3
	for i = 1, n do
		local d = s * (0.45 + 0.55 * (i / n))
		c:ring(x, y, d, d, color or WHITE, 1.1, (i - 1) * 0.25)
	end
end

-- flèche épaisse (dir en degrés : 0 droite, 90 bas, -90 haut)
function FX.arrow(c, x, y, s, dir, color)
	s = s or 0.4
	local a = math.rad(dir or 90)
	local ux, uy = math.cos(a), math.sin(a)
	local tx, ty = x - ux * s * 0.5, y - uy * s * 0.5
	local hx, hy = x + ux * s * 0.5, y + uy * s * 0.5
	local function back(deg)
		local b = a + math.rad(deg)
		return { hx + math.cos(b) * s * 0.42, hy + math.sin(b) * s * 0.42 }
	end
	c:lines({ { { tx, ty }, { hx, hy } }, { back(145), { hx, hy }, back(-145) } }, s * 0.2, color or RED)
end

-- arc de mouvement (swing, rotation) : centre, rayon, angles de début / fin (degrés, y vers le bas)
function FX.arc(c, x, y, r, a0, a1, th, color, head)
	local n = math.max(2, math.ceil(math.abs(a1 - a0) / 22))
	local pts = {}
	for i = 0, n do
		local a = math.rad(a0 + (a1 - a0) * i / n)
		table.insert(pts, { x + math.cos(a) * r, y + math.sin(a) * r })
	end
	local groups = { pts }
	if head then
		local a = math.rad(a1)
		local hx, hy = x + math.cos(a) * r, y + math.sin(a) * r
		local tang = a + (a1 > a0 and math.pi / 2 or -math.pi / 2)
		local hs = (th or 0.08) * 2.4
		local function back(deg)
			local b = tang + math.rad(deg)
			return { hx + math.cos(b) * hs, hy + math.sin(b) * hs }
		end
		table.insert(groups, { back(145), { hx, hy }, back(-145) })
	end
	c:lines(groups, th or 0.08, color or WHITE)
end

-- jet en cône depuis (x,y) vers dir
function FX.cone(c, x, y, len, dir, spread, color, n)
	n = n or 3
	local groups = {}
	for i = 0, n - 1 do
		local a = math.rad(dir + (n == 1 and 0 or (-spread / 2 + spread * i / (n - 1))))
		local l = len * (i % 2 == 0 and 1 or 0.82)
		table.insert(groups, { { x + math.cos(a) * len * 0.12, y + math.sin(a) * len * 0.12 }, { x + math.cos(a) * l, y + math.sin(a) * l } })
	end
	c:lines(groups, 0.075, color or WHITE)
end

-- éclair en zigzag
function FX.zig(c, x0, y0, x1, y1, color, th)
	local dx, dy = x1 - x0, y1 - y0
	local px, py = -dy * 0.28, dx * 0.28
	c:lines({ {
		{ x0, y0 },
		{ x0 + dx * 0.45 + px, y0 + dy * 0.45 + py },
		{ x0 + dx * 0.55 - px, y0 + dy * 0.55 - py },
		{ x1, y1 },
	} }, th or 0.065, color or rgb(255, 232, 70))
end

-- étincelle à 4 branches
function FX.spark(c, x, y, s, color)
	local g = c:sub(x, y, s or 0.2, 0)
	g:lines({ { { 0.5, 0.0 }, { 0.5, 1.0 } }, { { 0.12, 0.5 }, { 0.88, 0.5 } } }, 0.2, color or WHITE)
end

-- flèches qui convergent vers le centre (attirer)
function FX.conv(c, y, color)
	FX.arrow(c, 0.17, y or 0.5, 0.26, 0, color or WHITE)
	FX.arrow(c, 0.83, y or 0.5, 0.26, 180, color or WHITE)
end

-- confettis / pixels éparpillés (graine fixe : même dessin à chaque fois)
local BIT_COLORS = { rgb(255, 80, 120), rgb(80, 210, 255), rgb(255, 220, 60), rgb(120, 230, 110), rgb(190, 110, 255) }
function FX.bits(c, x, y, s, n, colors, size)
	local rnd = Random.new(7)
	colors = colors or BIT_COLORS
	for i = 1, n or 9 do
		local px = x + (rnd:NextNumber() - 0.5) * s
		local py = y + (rnd:NextNumber() - 0.5) * s
		c:rect(px, py, size or 0.09, size or 0.09, rnd:NextInteger(0, 60), colors[(i - 1) % #colors + 1], nil, 0.7)
	end
end

-- ombre au sol (objet qui tombe)
function FX.shadow(c, x, y, w)
	c:rect(x, y, w, w * 0.22, 0, INK, 0.5, false, 0.55)
end

-- tremblement (petits traits de part et d'autre)
function FX.shake(c, x, y, s)
	local g = c:sub(x, y, s or 0.8, 0)
	g:lines({
		{ { 0.04, 0.3 }, { 0.12, 0.4 }, { 0.04, 0.5 } },
		{ { 0.96, 0.3 }, { 0.88, 0.4 }, { 0.96, 0.5 } },
	}, 0.06, WHITE)
end

------------------------------------------------------------------------
-- Accessoires dessinés (props) : dessinés dans un sous-conteneur (x, y, s, r)
------------------------------------------------------------------------
local PROPS = {}

-- silhouette R6 (la victime) ; col = couleur
function PROPS.sil(g, col)
	col = col or rgb(245, 245, 252)
	g:rect(0.24, 0.48, 0.15, 0.34, 0, col, 0.2)
	g:rect(0.76, 0.48, 0.15, 0.34, 0, col, 0.2)
	g:rect(0.41, 0.8, 0.17, 0.32, 0, col, 0.2)
	g:rect(0.59, 0.8, 0.17, 0.32, 0, col, 0.2)
	g:rect(0.5, 0.48, 0.36, 0.36, 0, col, 0.12)
	g:rect(0.5, 0.17, 0.3, 0.28, 0, col, 0.3)
end

function PROPS.note(g, col)
	g:rect(0.5, 0.5, 0.82, 0.82, 0, col or rgb(255, 232, 80), 0.06)
	g:rect(0.5, 0.18, 0.82, 0.18, 0, rgb(240, 200, 40), 0.06, false)
	g:rect(0.48, 0.48, 0.5, 0.07, 0, INK, 0.5, false, 0.3)
	g:rect(0.42, 0.66, 0.38, 0.07, 0, INK, 0.5, false, 0.3)
end

function PROPS.bucket(g)
	g:ring(0.5, 0.3, 0.58, 0.52, INK, 1.6)
	local b = g:rect(0.5, 0.58, 0.62, 0.6, 0, rgb(160, 172, 188), 0.12)
	local gr = Instance.new("UIGradient")
	gr.Color = ColorSequence.new(rgb(235, 235, 240), rgb(130, 130, 140))
	gr.Parent = b
	g:rect(0.5, 0.3, 0.76, 0.14, 0, rgb(110, 120, 138), 0.3)
	g:rect(0.5, 0.62, 0.62, 0.08, 0, rgb(80, 150, 255), nil, false)
end

function PROPS.tray(g)
	g:rect(0.5, 0.5, 0.96, 0.66, 0, rgb(200, 206, 218), 0.22)
	g:rect(0.5, 0.5, 0.74, 0.44, 0, rgb(236, 240, 248), 0.22, 0.6)
	g:rect(0.36, 0.36, 0.3, 0.06, -8, WHITE, 0.5, false)
end

function PROPS.cuffs(g)
	g:seg(0.36, 0.56, 0.64, 0.44, 0.08, rgb(90, 95, 110))
	g:inkRing(0.27, 0.62, 0.42, 0.42, rgb(205, 210, 222), 1.6)
	g:inkRing(0.73, 0.38, 0.42, 0.42, rgb(205, 210, 222), 1.6)
end

function PROPS.whistle(g)
	g:rect(0.74, 0.42, 0.46, 0.22, -18, rgb(200, 205, 218), 0.15)
	g:circ(0.4, 0.58, 0.6, rgb(220, 225, 235))
	g:circ(0.42, 0.5, 0.16, INK, false)
	g:inkRing(0.16, 0.34, 0.2, 0.2, rgb(255, 214, 50), 0.8)
end

function PROPS.walkie(g)
	g:rect(0.34, 0.2, 0.1, 0.38, 0, rgb(40, 40, 50), 0.4)
	g:rect(0.52, 0.6, 0.5, 0.7, 0, rgb(55, 58, 70), 0.12)
	g:rect(0.52, 0.44, 0.34, 0.16, 0, rgb(150, 235, 150), 0.1, 0.6)
	for i = 0, 2 do
		g:rect(0.52, 0.62 + i * 0.08, 0.32, 0.04, 0, rgb(25, 25, 32), 0.5, false)
	end
	g:rect(0.82, 0.5, 0.08, 0.16, 0, rgb(255, 140, 30), 0.3, 0.6)
end

function PROPS.ladder(g)
	for i = 0, 4 do
		g:rect(0.5, 0.12 + i * 0.19, 0.44, 0.07, 0, rgb(225, 185, 90), nil, 0.7)
	end
	g:rect(0.28, 0.5, 0.1, 0.98, 0, rgb(200, 205, 215), 0.3)
	g:rect(0.72, 0.5, 0.1, 0.98, 0, rgb(200, 205, 215), 0.3)
end

function PROPS.kettle(g)
	g:inkRing(0.5, 0.3, 0.48, 0.44, rgb(70, 72, 84), 2.2)
	g:circ(0.5, 0.62, 0.7, rgb(70, 72, 84))
	g:rect(0.36, 0.5, 0.16, 0.1, -35, WHITE, 0.5, false, 0.5)
	g:text("24", 0.5, 0.66, 0.24, 0, rgb(255, 214, 50), 0.4)
end

function PROPS.medball(g)
	g:circ(0.5, 0.5, 0.86, rgb(170, 45, 55))
	g:rect(0.5, 0.5, 0.86, 0.06, 0, rgb(70, 15, 20), nil, false)
	g:rect(0.5, 0.5, 0.06, 0.86, 0, rgb(70, 15, 20), nil, false)
	g:rect(0.32, 0.3, 0.2, 0.1, -35, WHITE, 0.5, false, 0.45)
end

function PROPS.tape(g, col)
	col = col or rgb(195, 200, 212)
	g:rect(0.78, 0.84, 0.5, 0.16, 8, col, 0.1)
	g:circ(0.5, 0.48, 0.82, col)
	g:circ(0.5, 0.48, 0.36, rgb(60, 55, 70))
	g:ring(0.5, 0.48, 0.6, 0.6, rgb(255, 255, 255), 0.5, 0.6)
end

function PROPS.dolly(g)
	g:seg(0.28, 0.1, 0.16, 0.02, 0.09, rgb(220, 60, 60))
	g:rect(0.3, 0.5, 0.09, 0.84, 0, rgb(220, 60, 60), 0.3)
	g:rect(0.56, 0.9, 0.56, 0.08, 0, rgb(170, 175, 185), 0.3)
	g:emoji("📦", 0.6, 0.6, 0.52, 0)
	g:circ(0.3, 0.88, 0.24, rgb(40, 40, 48))
	g:circ(0.3, 0.88, 0.08, rgb(170, 175, 185), false)
end

function PROPS.idcard(g)
	g:seg(0.22, 0.0, 0.46, 0.22, 0.07, rgb(60, 140, 255))
	g:seg(0.78, 0.0, 0.54, 0.22, 0.07, rgb(60, 140, 255))
	g:rect(0.5, 0.62, 0.66, 0.74, 0, WHITE, 0.1)
	g:rect(0.5, 0.36, 0.66, 0.16, 0, rgb(60, 140, 255), 0.1, false)
	g:rect(0.5, 0.58, 0.26, 0.26, 0, rgb(170, 215, 255), 0.1, 0.5)
	g:rect(0.5, 0.82, 0.4, 0.06, 0, INK, 0.5, false, 0.4)
	g:rect(0.5, 0.25, 0.14, 0.08, 0, rgb(200, 205, 215), 0.2, 0.5)
end

function PROPS.portafilter(g)
	g:seg(0.36, 0.42, 0.04, 0.3, 0.14, INK)
	g:seg(0.33, 0.41, 0.07, 0.31, 0.08, rgb(60, 50, 45))
	g:rect(0.62, 0.48, 0.5, 0.3, 0, rgb(205, 210, 222), 0.25)
	g:rect(0.62, 0.36, 0.56, 0.08, 0, rgb(160, 165, 178), 0.3, 0.7)
	g:rect(0.62, 0.68, 0.14, 0.12, 0, rgb(160, 165, 178), 0.2, 0.7)
	g:rect(0.62, 0.84, 0.62, 0.12, 0, rgb(120, 70, 35), 0.3)
end

function PROPS.bean(g)
	g:rect(0.5, 0.5, 0.9, 0.64, 0, rgb(120, 66, 34), 0.5)
	g:rect(0.5, 0.5, 0.62, 0.08, 6, rgb(55, 28, 12), 0.5, false)
	g:rect(0.32, 0.34, 0.22, 0.08, -12, WHITE, 0.5, false, 0.6)
end

function PROPS.latte(g)
	g:circ(0.5, 0.5, 0.98, rgb(250, 248, 242))
	g:circ(0.5, 0.5, 0.78, rgb(160, 96, 52), 0.6)
	local cream = rgb(250, 236, 205)
	g:circ(0.4, 0.44, 0.26, cream, false)
	g:circ(0.6, 0.44, 0.26, cream, false)
	g:rect(0.5, 0.55, 0.27, 0.27, 45, cream, nil, false)
end

function PROPS.bsod(g)
	g:rect(0.5, 0.88, 0.5, 0.08, 0, rgb(70, 72, 84), 0.3)
	g:rect(0.5, 0.78, 0.14, 0.16, 0, rgb(70, 72, 84), nil, 0.7)
	g:rect(0.5, 0.4, 0.98, 0.72, 0, rgb(60, 62, 74), 0.08)
	g:rect(0.5, 0.4, 0.86, 0.58, 0, rgb(30, 100, 230), 0.04, false)
	g:text(":(", 0.36, 0.36, 0.32, 0, WHITE, 0.4)
	g:rect(0.6, 0.6, 0.5, 0.05, 0, WHITE, nil, false, 0.3)
end

function PROPS.keycap(g, txt)
	g:rect(0.5, 0.56, 0.94, 0.82, 0, rgb(140, 140, 158), 0.14)
	g:rect(0.5, 0.46, 0.76, 0.6, 0, rgb(238, 238, 248), 0.12, 0.6)
	g:text(txt or "DEL", 0.5, 0.46, 0.36, 0, RED, 0.72)
end

function PROPS.stamp(g, txt, col)
	col = col or RED
	local f = g:rect(0.5, 0.5, 0.98, 0.42, 0, rgb(255, 244, 240), 0.1, false, 0.05)
	g:stroke(f, 1.6, col)
	g:text(txt or "OK", 0.5, 0.5, 0.26, 0, col, 0.86)
end

function PROPS.slip(g, txt)
	g:rect(0.5, 0.5, 0.96, 0.64, 0, rgb(255, 160, 200), 0.06)
	g:text(txt or "FIRED", 0.5, 0.44, 0.24, 0, WHITE, 0.82)
	g:rect(0.5, 0.68, 0.6, 0.05, 0, INK, 0.5, false, 0.4)
end

function PROPS.sheet(g)
	g:rect(0.5, 0.5, 0.98, 0.72, 0, WHITE, 0.04)
	g:rect(0.5, 0.2, 0.98, 0.14, 0, rgb(40, 170, 90), 0.04, false)
	for i = 1, 3 do
		g:rect(i * 0.245, 0.55, 0.025, 0.6, 0, rgb(150, 200, 165), nil, false)
	end
	for i = 1, 3 do
		g:rect(0.5, 0.27 + i * 0.14, 0.96, 0.025, 0, rgb(150, 200, 165), nil, false)
	end
	g:rect(0.62, 0.48, 0.2, 0.11, 0, rgb(255, 214, 50), nil, false)
end

function PROPS.fusebox(g)
	g:rect(0.5, 0.5, 0.8, 0.92, 0, rgb(150, 156, 170), 0.08)
	g:rect(0.5, 0.46, 0.62, 0.66, 0, rgb(120, 126, 140), 0.06, 0.6)
	g:emoji("⚡", 0.5, 0.46, 0.56, 0)
	g:rect(0.5, 0.88, 0.8, 0.1, 0, rgb(255, 214, 50), nil, 0.6)
end

function PROPS.wrap(g)
	g:rect(0.5, 0.5, 0.98, 0.7, 0, rgb(225, 245, 255), 0.08, 1, 0.25)
	for i = 0, 3 do
		for j = 0, 2 do
			g:circ(0.17 + i * 0.22, 0.29 + j * 0.21, 0.17, WHITE, 0.5, 0.15)
		end
	end
end

function PROPS.disco(g)
	local cols = { rgb(255, 80, 180), rgb(80, 220, 255), rgb(255, 220, 60), rgb(160, 100, 255) }
	for i = 0, 3 do
		for j = 0, 1 do
			g:rect(0.13 + i * 0.25, 0.7 + j * 0.2, 0.24, 0.19, 0, cols[(i + j) % 4 + 1], nil, 0.6)
		end
	end
end

function PROPS.mhead(g, col)
	col = col or rgb(255, 170, 60)
	g:circ(0.2, 0.2, 0.3, col)
	g:circ(0.8, 0.2, 0.3, col)
	g:circ(0.5, 0.54, 0.86, col)
	g:circ(0.36, 0.46, 0.22, WHITE, 0.6)
	g:circ(0.64, 0.46, 0.22, WHITE, 0.6)
	g:circ(0.38, 0.48, 0.1, INK, false)
	g:circ(0.62, 0.48, 0.1, INK, false)
	g:rect(0.5, 0.72, 0.36, 0.1, 0, INK, 0.5, false)
end

function PROPS.hoop(g)
	g:rect(0.5, 0.34, 0.9, 0.6, 0, WHITE, 0.06)
	local sq = g:rect(0.5, 0.42, 0.36, 0.28, 0, WHITE, nil, false)
	g:stroke(sq, 1, RED)
	g:seg(0.3, 0.72, 0.38, 0.98, 0.04, WHITE)
	g:seg(0.5, 0.72, 0.5, 0.98, 0.04, WHITE)
	g:seg(0.7, 0.72, 0.62, 0.98, 0.04, WHITE)
	g:inkRing(0.5, 0.72, 0.5, 0.12, rgb(255, 120, 30), 1.4)
end

function PROPS.wball(g)
	g:seg(0.5, -0.1, 0.5, 0.4, 0.08, INK)
	g:seg(0.5, -0.1, 0.5, 0.4, 0.04, rgb(150, 150, 160))
	g:circ(0.5, 0.66, 0.62, rgb(55, 55, 66))
	g:rect(0.38, 0.54, 0.16, 0.08, -35, WHITE, 0.5, false, 0.5)
end

function PROPS.bars(g)
	for i = 0, 4 do
		g:rect(0.1 + i * 0.2, 0.5, 0.08, 0.84, 0, rgb(175, 180, 195), 0.3)
	end
	g:rect(0.5, 0.1, 0.98, 0.1, 0, rgb(130, 135, 150), 0.2)
	g:rect(0.5, 0.9, 0.98, 0.1, 0, rgb(130, 135, 150), 0.2)
end

function PROPS.calc(g)
	g:rect(0.5, 0.5, 0.72, 0.94, 0, rgb(70, 76, 94), 0.1)
	g:rect(0.5, 0.22, 0.56, 0.2, 0, rgb(160, 235, 160), 0.08, 0.6)
	for i = 0, 2 do
		for j = 0, 2 do
			g:rect(0.32 + i * 0.18, 0.46 + j * 0.15, 0.13, 0.1, 0, (i == 2 and j == 2) and rgb(255, 140, 30) or rgb(225, 228, 238), 0.15, false)
		end
	end
end

function PROPS.safe(g)
	g:rect(0.5, 0.5, 0.9, 0.86, 0, rgb(125, 130, 148), 0.08)
	g:rect(0.5, 0.5, 0.72, 0.68, 0, rgb(150, 156, 175), 0.06, 0.6)
	g:circ(0.46, 0.5, 0.32, rgb(60, 62, 74))
	g:circ(0.46, 0.5, 0.12, rgb(200, 205, 215), false)
	g:rect(0.76, 0.5, 0.07, 0.24, 0, rgb(255, 214, 50), 0.3, 0.6)
	g:rect(0.24, 0.96, 0.14, 0.08, 0, INK, nil, false)
	g:rect(0.76, 0.96, 0.14, 0.08, 0, INK, nil, false)
end

function PROPS.billboard(g)
	g:rect(0.3, 0.82, 0.08, 0.36, 0, rgb(120, 120, 135), nil, 0.7)
	g:rect(0.7, 0.82, 0.08, 0.36, 0, rgb(120, 120, 135), nil, 0.7)
	g:rect(0.5, 0.38, 0.98, 0.6, 0, rgb(255, 214, 50), 0.06)
	g:rect(0.5, 0.38, 0.84, 0.46, 0, rgb(255, 90, 170), 0.04, false)
	g:text("AD!", 0.5, 0.38, 0.32, -4, WHITE, 0.7)
end

function PROPS.bubble(g)
	g:circ(0.5, 0.5, 0.96, rgb(170, 225, 255), 1, 0.62)
	g:ring(0.5, 0.5, 0.86, 0.86, WHITE, 1.2, 0.25)
	g:rect(0.3, 0.27, 0.26, 0.12, -40, WHITE, 0.5, false, 0.1)
	g:circ(0.72, 0.74, 0.08, WHITE, false, 0.3)
end

function PROPS.cord(g)
	for i = 0, 5 do
		local t = i / 5
		g:ring(0.16 + t * 0.66, 0.66 - t * 0.36, 0.15, 0.15, INK, 1.4)
	end
end

function PROPS.swap(g)
	FX.arrow(g, 0.5, 0.32, 0.8, 0, rgb(255, 214, 50))
	FX.arrow(g, 0.5, 0.68, 0.8, 180, rgb(80, 210, 255))
end

function PROPS.speech(g, txt)
	g:rect(0.32, 0.8, 0.2, 0.2, 45, WHITE)
	g:rect(0.5, 0.42, 0.94, 0.66, 0, WHITE, 0.25)
	g:rect(0.32, 0.72, 0.14, 0.1, 45, WHITE, nil, false)
	g:text(txt or "!", 0.5, 0.42, 0.5, 0, RED, 0.8)
end

function PROPS.splat(g, col)
	col = col or rgb(150, 90, 60)
	g:circ(0.1, 0.42, 0.14, col, 0.6)
	g:circ(0.9, 0.44, 0.12, col, 0.6)
	g:circ(0.52, 0.2, 0.12, col, 0.6)
	g:rect(0.5, 0.66, 0.86, 0.4, 0, col, 0.5)
	g:rect(0.38, 0.6, 0.2, 0.08, 0, WHITE, 0.5, false, 0.55)
end

function PROPS.peanuts(g)
	local rnd = Random.new(3)
	for _ = 1, 6 do
		g:rect(rnd:NextNumber(0.1, 0.9), rnd:NextNumber(0.1, 0.9), 0.2, 0.12, rnd:NextInteger(0, 180), rgb(250, 240, 210), 0.5, 0.6)
	end
end

function PROPS.puddle(g)
	g:rect(0.5, 0.5, 0.98, 0.32, 0, rgb(100, 195, 255), 0.5, 1, 0.1)
	g:rect(0.32, 0.44, 0.24, 0.07, 0, WHITE, 0.5, false, 0.3)
end

function PROPS.jumprope(g)
	g:inkRing(0.5, 0.5, 0.86, 0.6, rgb(240, 200, 120), 1.4)
	g:rect(0.08, 0.6, 0.11, 0.3, -20, rgb(240, 70, 70), 0.3)
	g:rect(0.92, 0.6, 0.11, 0.3, 20, rgb(240, 70, 70), 0.3)
end

function PROPS.stockarrow(g)
	local pts = { { 0.06, 0.12 }, { 0.36, 0.42 }, { 0.52, 0.28 }, { 0.8, 0.7 } }
	local a = math.atan2(0.7 - 0.28, 0.8 - 0.52)
	local hx, hy = 0.84, 0.76
	local function back(deg)
		local b = a + math.rad(deg)
		return { hx + math.cos(b) * 0.3, hy + math.sin(b) * 0.3 }
	end
	g:lines({ pts, { back(150), { hx, hy }, back(-150) } }, 0.14, rgb(240, 50, 50))
end

function PROPS.uturn(g)
	FX.arc(g, 0.5, 0.62, 0.32, 0, -180, 0.11, rgb(255, 214, 50), true)
end

function PROPS.bricks(g)
	local c = rgb(200, 90, 60)
	for i = 0, 2 do
		g:rect(0.18 + i * 0.32, 0.58, 0.3, 0.2, 0, c, 0.1, 0.7)
	end
	for i = 0, 3 do
		g:rect(0.02 + i * 0.32, 0.8, 0.3, 0.2, 0, c, 0.1, 0.7)
	end
end

------------------------------------------------------------------------
-- Badges d'effet (coin bas-droit)
------------------------------------------------------------------------
local BADGES = {
	pin = { "📌", rgb(255, 70, 70) },
	counter = { "🛡️", rgb(80, 160, 255) },
	burn = { "🔥", rgb(255, 140, 40) },
	slow = { "🐌", rgb(110, 220, 110) },
	blind = { "😵", rgb(190, 120, 255) },
	mark = { "🎯", rgb(255, 90, 90) },
	stun = { "💫", rgb(255, 214, 50) },
	trip = { "🍌", rgb(255, 225, 80) },
	buff = { "⚡", rgb(255, 214, 50) },
	heal = { "❤️", rgb(110, 220, 110) },
	freeze = { "🧊", rgb(130, 210, 255) },
	drain = { "💸", rgb(110, 220, 110) },
	grab = { "👊", rgb(255, 170, 80) },
}
AttackIcon.Badges = BADGES

------------------------------------------------------------------------
-- Données du jeu (seulement en partie lancée : jamais de require de ces modules en Edit)
------------------------------------------------------------------------
local owners -- attackId -> { color, tier, char }
local attacksCfg
local function running()
	return RunService:IsRunning()
end

local function ownerOf(id)
	if owners == nil then
		owners = false
		if running() then
			local ok, Characters = pcall(require, ReplicatedStorage.Shared.Config.Characters)
			if ok and type(Characters) == "table" then
				owners = {}
				for charId, def in pairs(Characters) do
					if type(def) == "table" and def.Color then
						for _, a in ipairs(def.Attacks or {}) do
							owners[a] = { color = def.Color, tier = "Base", char = charId }
						end
						for _, a in ipairs(def.TransAttacks or {}) do
							owners[a] = { color = def.Color, tier = "Trans", char = charId }
						end
						owners["Ult:" .. charId] = { color = def.Color, tier = "Ult", char = charId }
					end
				end
			end
		end
	end
	return owners and owners[id] or nil
end

local function attackDef(id)
	if attacksCfg == nil then
		attacksCfg = false
		if running() then
			local ok, A = pcall(require, ReplicatedStorage.Shared.Config.Attacks)
			attacksCfg = ok and A or false
		end
	end
	return attacksCfg and type(attacksCfg[id]) == "table" and attacksCfg[id] or nil
end

-- badge déduit des effets de l'attaque (si la fiche d'icône n'en impose pas)
local function autoBadge(id)
	local a = attackDef(id)
	if not a then
		return nil
	end
	local fx = type(a.Effects) == "table" and a.Effects or {}
	if fx.Pin then
		return "pin"
	elseif a.Kind == "Counter" or a.Kind == "Guard" then
		return "counter"
	elseif fx.Burn then
		return "burn"
	elseif fx.Blind then
		return "blind"
	elseif fx.Slow then
		return "slow"
	elseif fx.Mark then
		return "mark"
	elseif fx.Trip then
		return "trip"
	end
	return nil
end

-- icône de secours (attaque sans fiche) : sujet selon le Kind
local KIND_EMOJI = {
	Lunge = "💨", Projectile = "☄️", Melee = "👊", AoE = "💥", Slam = "⏬", Cone = "📢", Grab = "👊",
	Zone = "⚠️", Barrier = "🚧", Buff = "⚡", Guard = "🛡️", Counter = "🛡️",
}

------------------------------------------------------------------------
-- Construction
------------------------------------------------------------------------
function AttackIcon.ultKey(charId)
	return "Ult:" .. tostring(charId)
end

local function specOf(key)
	if type(key) ~= "string" then
		return nil
	end
	local charId = string.match(key, "^Ult:(.+)$")
	if charId then
		return Icons.Ults[charId], "Ult"
	end
	if Icons.Slots[key] then
		return Icons.Slots[key], "Slot"
	end
	return Icons.Attacks[key], nil
end

function AttackIcon.has(key)
	return specOf(key) ~= nil
end

-- nom + description de l'ultime d'un perso (module Shared.Ultimates.<CharId>, en partie lancée seulement)
local ultCache = {}
function AttackIcon.ultInfo(charId)
	if ultCache[charId] == nil then
		ultCache[charId] = false
		local f = running() and ReplicatedStorage.Shared:FindFirstChild("Ultimates")
		local m = f and f:FindFirstChild(tostring(charId))
		if m and m:IsA("ModuleScript") then
			local ok, def = pcall(require, m)
			if ok and type(def) == "table" and def.Name then
				ultCache[charId] = def
			end
		end
	end
	local u = ultCache[charId]
	return u and u.Name or nil, u and u.Desc or nil
end

local function drawLayer(c, L)
	local t = L[1]
	if t == "e" then
		c:emoji(L[2], L[3], L[4], L[5], L[6], L.a, L.k)
	elseif t == "t" then
		c:text(L[2], L[3], L[4], L[5], L[6], L.c, L.w)
	elseif t == "d" then
		local fn = PROPS[L[2]]
		if fn then
			fn(c:sub(L[3], L[4], L[5], L[6]), L[7], L[8])
		end
	elseif FX[t] then
		FX[t](c, table.unpack(L, 2))
	end
end

function AttackIcon.build(key, parent, opts)
	opts = opts or {}
	local spec, kindTier = specOf(key)
	local own = ownerOf(key)
	local tier = opts.Tier or (spec and spec.tier) or kindTier or (own and own.tier) or "Base"
	local base = opts.Color or (spec and spec.bg) or (own and own.color) or rgb(90, 110, 170)
	if spec and spec.bg and kindTier == "Slot" and not opts.KeepColor then
		base = spec.bg
	end
	local z = opts.ZIndex or ((parent and parent:IsA("GuiObject")) and parent.ZIndex + 1) or 2

	local root = Instance.new("Frame")
	root.Name = "AttackIcon"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = opts.Size or UDim2.fromScale(1, 1)
	root.BorderSizePixel = 0
	root.ZIndex = z
	root:SetAttribute("IconKey", tostring(key))
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.Parent = root
	local strokes = {}
	local top = newCtx(root, z, strokes, 1)

	-- fond : couleur du perso (ultime : plus sombre, transformé : plus chaud), dégradé, rayons, liseré du palier
	local bg = base
	if tier == "Ult" then
		bg = base:Lerp(rgb(30, 20, 50), 0.35)
	elseif tier == "Trans" then
		bg = base:Lerp(rgb(255, 90, 30), 0.1)
	end
	local lum = 0.299 * bg.R + 0.587 * bg.G + 0.114 * bg.B
	if lum > 0.72 then
		bg = bg:Lerp(Color3.new(0, 0, 0), 0.22) -- fond trop clair : on assombrit pour que le sujet ressorte
	elseif lum < 0.2 then
		bg = bg:Lerp(Color3.new(1, 1, 1), 0.18)
	end
	if opts.NoFrame then
		root.BackgroundTransparency = 1
	else
		root.BackgroundColor3 = bg
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.18, 0)
		corner.Parent = root
		top:stroke(root, 1.15, INK)
		local gr = Instance.new("UIGradient")
		gr.Rotation = 90
		gr.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, rgb(255, 255, 255)),
			ColorSequenceKeypoint.new(0.55, rgb(222, 222, 228)),
			ColorSequenceKeypoint.new(1, rgb(140, 140, 155)),
		})
		gr.Parent = root
		local rayCol = (tier == "Ult" and rgb(255, 210, 80)) or (tier == "Trans" and rgb(255, 230, 140)) or UITheme.lighten(bg, 0.6)
		local rayTr = tier == "Ult" and 0.6 or 0.8
		for i = 0, 5 do
			top:rect(0.5, 0.5, 0.94, i % 2 == 0 and 0.13 or 0.08, i * 30 + 15, rayCol, nil, false, rayTr)
		end
		top:circ(0.5, 0.5, 0.42, rayCol, false, tier == "Ult" and 0.7 or 0.86)
		local inset = top:inst("Frame", {
			Name = "Inset",
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.86, 0.86),
		})
		local ic = Instance.new("UICorner")
		ic.CornerRadius = UDim.new(0.14, 0)
		ic.Parent = inset
		local insetCol = (tier == "Trans" and rgb(255, 200, 50)) or (tier == "Ult" and WHITE) or UITheme.lighten(bg, 0.5)
		local ist = top:stroke(inset, tier == "Base" and 0.7 or 1.0, insetCol, tier == "Base" and 0.35 or 0)
		if tier == "Ult" then
			local rg = Instance.new("UIGradient")
			rg.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, rgb(255, 214, 50)),
				ColorSequenceKeypoint.new(0.35, rgb(255, 90, 200)),
				ColorSequenceKeypoint.new(0.7, rgb(80, 210, 255)),
				ColorSequenceKeypoint.new(1, rgb(255, 214, 50)),
			})
			rg.Rotation = 45
			rg.Parent = ist
		end
	end

	-- dessin
	local art = top:sub(0.5, 0.5, opts.NoFrame and 1 or 0.92, 0)
	art.parent.Name = "Art"
	if spec then
		for _, L in ipairs(spec) do
			local ok, err = pcall(drawLayer, art, L)
			if not ok then
				warn("[AttackIcon] " .. tostring(key) .. ": " .. tostring(err))
			end
		end
	else
		local a = attackDef(key)
		FX.burst(art, 0.5, 0.52, 0.7, UITheme.lighten(bg, 0.3))
		art:emoji((tier == "Ult" and "⭐") or KIND_EMOJI[a and a.Kind or ""] or "💥", 0.5, 0.52, 0.62, 0)
	end

	if not opts.NoFrame and tier == "Ult" then
		top:emoji("✨", 0.13, 0.13, 0.3, 0, nil, false)
	end

	-- badge d'effet
	local badge = spec and spec.b
	if badge == nil and kindTier == nil then
		badge = autoBadge(key)
	end
	if badge and not opts.NoBadge and BADGES[badge] then
		local def = BADGES[badge]
		local bz = newCtx(root, z + 1, strokes, 1)
		local holder = bz:inst("Frame", {
			Name = "Badge",
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1.07, 1.07),
			Size = UDim2.fromScale(0.42, 0.42),
			BackgroundColor3 = rgb(30, 26, 48),
		})
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0.5, 0)
		bc.Parent = holder
		bz:stroke(holder, 0.95, def[2])
		local bctx = newCtx(holder, z + 1, strokes, 0.42)
		bctx:emoji(def[1], 0.5, 0.52, 0.78, 0, nil, false)
		root:SetAttribute("Badge", badge)
	end

	-- épaisseur des contours proportionnelle à la taille affichée
	local function restroke()
		local px = root.AbsoluteSize.X
		if px <= 0 then
			return
		end
		for _, s in ipairs(strokes) do
			s[1].Thickness = math.max(0.8, OL * s[2] * px)
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(restroke)
	if parent then
		root.Parent = parent
	end
	restroke()
	return root
end

return AttackIcon
