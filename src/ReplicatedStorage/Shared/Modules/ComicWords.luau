--[[
	ComicWords — onomatopées façon planche d'autocollants BD (client uniquement).

	ComicWords.create(pos: Vector3, text: string, power: number?, category: string?)
		pos      : point du monde où le mot apparaît
		text     : mot affiché tel quel (choisi par l'appelant)
		power    : 0..~1.5 (plus grand = plus gros coup = plus gros autocollant)
		category : "Light", "Heavy", "Break", "Projectile", "Splat", "Parry", "Land", "KO",
				   "Electric", "Air", "Funny"… — ne choisit que la forme et la palette

	Formes (construites uniquement avec des primitives GUI) :
		Star   étoile d'explosion (plusieurs ★ superposés, pointes inégales)
		Bang   explosion « BANG » à longues pointes irrégulières (triangles = Frames découpés par UIGradient)
		Cloud  nuage « POOF » (cercles qui se chevauchent)
		Speech bulle ronde avec petite queue
		Banner bandeau / parallélogramme penché
		Zigzag badge électrique à dents + éclairs
		Plain  mot seul, gros contour, petites étoiles autour
	Chaque forme = couche de contour sombre (décalée, effet autocollant) + couche colorée en 2 tons + reflets,
	trame de points (halftone) dans un coin, décorations (étoiles, traits de vitesse, bouffées).

	Aucun effet de bord au require : rien n'est créé tant que create() n'est pas appelé.
]]
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Words = require(ReplicatedStorage.Shared.Config.Words)
local UITheme = require(ReplicatedStorage.Shared.Modules.UITheme)

local ComicWords = {}
ComicWords.static = false -- tests : true = pas d'animation (pratique pour les captures)
ComicWords.forceShape = nil -- tests : force une forme ("Star", "Bang"…)

local rng = Random.new()
local TAU = math.pi * 2
local OUTLINE = Color3.fromRGB(26, 18, 40)
local WHITE = Color3.new(1, 1, 1)
local YELLOW = Color3.fromRGB(255, 232, 60)
local GLYPH_FONT = Enum.Font.GothamBlack

-- Z : trame derrière 1, déco derrière 2, contour 3, liseré KO 4, couleur 5, reflets/trame 6, texte 8, déco devant 9
local Z_DOTS_BACK, Z_DECO_BACK, Z_DARK, Z_RIM, Z_FILL, Z_HI, Z_TEXT, Z_DECO = 1, 2, 3, 4, 5, 6, 8, 9

------------------------------------------------------------------------
-- Valeurs par défaut (si Config/Words ne les fournit pas)
------------------------------------------------------------------------
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local DEFAULT_PALETTES = {
	{ Name = "Sunny", Bubble = { rgb(255, 238, 70), rgb(255, 170, 25) }, Text = { rgb(255, 95, 70), rgb(205, 20, 45) } },
	{ Name = "Sky", Bubble = { rgb(120, 228, 255), rgb(30, 135, 250) }, Text = { rgb(255, 250, 120), rgb(255, 165, 30) } },
	{ Name = "Cherry", Bubble = { rgb(255, 100, 85), rgb(210, 25, 50) }, Text = { rgb(255, 255, 160), rgb(255, 195, 40) } },
}
local DEFAULT_KO = { Name = "KO", Bubble = { rgb(255, 75, 60), rgb(195, 15, 40) }, Text = { rgb(255, 255, 255), rgb(255, 232, 90) }, Rim = rgb(255, 225, 50), Dots = rgb(255, 220, 60) }

local DEFAULT_SHAPES = {
	Light = { Star = 40, Speech = 30, Plain = 15, Banner = 15 },
	Heavy = { Bang = 55, Star = 35, Cloud = 10 },
	Electric = { Zigzag = 85, Bang = 15 },
	KO = { Bang = 100 },
	Default = { Star = 20, Bang = 15, Cloud = 15, Speech = 15, Banner = 15, Zigzag = 5, Plain = 15 },
}

------------------------------------------------------------------------
-- Petits utilitaires
------------------------------------------------------------------------
local function tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function pick(list)
	return list[rng:NextInteger(1, #list)]
end

local function weighted(weights)
	local total = 0
	for _, w in pairs(weights) do
		total += w
	end
	local r = rng:NextNumber() * total
	local last
	for k, w in pairs(weights) do
		last = k
		r -= w
		if r <= 0 then
			return k
		end
	end
	return last
end

local function rnd(a, b)
	return rng:NextNumber(a, b)
end

-- coordonnées en studs depuis le centre du billboard -> UDim2
local function frame(ctx, x, y, w, h, color, z, rot)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5 + x / ctx.W, 0.5 + y / ctx.H)
	f.Size = UDim2.fromScale(w / ctx.W, h / ctx.H)
	f.Rotation = rot or 0
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.ZIndex = z
	f.Parent = ctx.root
	ctx.count += 1
	return f
end

local function corner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(r or 0.5, 0)
	c.Parent = obj
	return obj
end

local function vgrad(obj, c1, c2, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rot or 90
	g.Parent = obj
	return g
end

local function glyph(ctx, ch, x, y, s, color, z, rot)
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5 + x / ctx.W, 0.5 + y / ctx.H)
	l.Size = UDim2.fromScale(s / ctx.W, s / ctx.H)
	l.BackgroundTransparency = 1
	l.Text = ch
	l.TextScaled = true
	l.Font = GLYPH_FONT
	l.TextColor3 = color
	l.Rotation = rot or 0
	l.ZIndex = z
	l.Parent = ctx.root
	ctx.count += 1
	return l
end

local function stroke(obj, px, color)
	local s = Instance.new("UIStroke")
	s.Thickness = px
	s.Color = color or OUTLINE
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = obj
	return s
end

-- Triangle rectangle = moitié d'un Frame L×w coupée en diagonale par un UIGradient à transition nette.
-- (bx, by) = milieu de la base, ang = direction de la pointe, flip = pointe côté « haut » ou « bas ».
-- Le dégradé de Roblox vit dans un carré de côté max(L, w) ancré en haut à gauche : on calcule le seuil t.
local function spike(ctx, bx, by, ang, L, w, color, z, flip, color2)
	local cx = bx + math.cos(ang) * L / 2
	local cy = by + math.sin(ang) * L / 2
	local f = frame(ctx, cx, cy, L, w, color2 and WHITE or color, z, math.deg(ang))
	local S = math.max(L, w)
	local n = math.sqrt(L * L + w * w)
	local theta, d
	if flip then
		theta = math.atan2(-L, w) -- garde le triangle bas-gauche (pointe en bas à droite)
		d = (S / 2) * (L - w) / n
	else
		theta = math.atan2(L, w) -- garde le triangle haut-gauche (pointe en haut à droite)
		d = (-S / 2) * w / n + (w - S / 2) * L / n
	end
	local k = S * (math.abs(math.cos(theta)) + math.abs(math.sin(theta)))
	local t = math.clamp(0.5 + d / k, 0.01, 0.985)
	local g = Instance.new("UIGradient")
	g.Rotation = math.deg(theta)
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(t, 0),
		NumberSequenceKeypoint.new(t + 0.005, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	if color2 then
		g.Color = ColorSequence.new(color, color2)
	end
	g.Parent = f
	return f
end

-- trame de points BD (une seule TextLabel multi-lignes = très peu coûteux)
local function halftone(ctx, x, y, s, color, z, right, transparency)
	local l = glyph(ctx, right and "        ● ●\n     ● ● ●\n  ● ● ● ●\n● ● ● ● ●" or "● ● ● ● ●\n● ● ● ●\n● ● ●\n● ●", x, y, s, color, z, 0)
	l.Size = UDim2.fromScale(s * 1.3 / ctx.W, s / ctx.H)
	l.TextXAlignment = right and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.LineHeight = 0.95
	l.TextTransparency = transparency or 0.3
	return l
end

------------------------------------------------------------------------
-- Formes de bulles
-- Chaque forme dessine : contour sombre (décalé vers le bas-droite = ombre d'autocollant),
-- couleur 2 tons, reflets. Elle renvoie la zone du texte {x, y, w, h} (studs depuis le centre).
------------------------------------------------------------------------
local Shapes = {}

-- (1) Étoile d'explosion : plusieurs ★ superposés de tailles/rotations différentes
function Shapes.Star(ctx, pal)
	local Bw, Bh, p = ctx.Bw, ctx.Bh, ctx.pad
	local stars = {
		{ x = 0, y = rnd(-0.04, 0.04) * Bh, s = Bh * rnd(2.0, 2.25), r = rnd(0, 72) },
		{ x = -Bw * rnd(0.24, 0.3), y = rnd(-0.08, 0.08) * Bh, s = Bh * rnd(1.5, 1.8), r = rnd(0, 72) },
		{ x = Bw * rnd(0.24, 0.3), y = rnd(-0.08, 0.08) * Bh, s = Bh * rnd(1.5, 1.8), r = rnd(0, 72) },
		{ x = rnd(-0.15, 0.15) * Bw, y = -Bh * rnd(0.08, 0.16), s = Bh * rnd(1.3, 1.55), r = rnd(0, 72) },
		{ x = rnd(-0.15, 0.15) * Bw, y = Bh * rnd(0.08, 0.16), s = Bh * rnd(1.3, 1.55), r = rnd(0, 72) },
	}
	local coreW, coreH = Bw * 0.6, Bh * 0.52
	for _, s in ipairs(stars) do
		glyph(ctx, "★", s.x + ctx.ox, s.y + ctx.oy, s.s + p * 3.2, OUTLINE, Z_DARK, s.r)
	end
	corner(frame(ctx, ctx.ox, ctx.oy, coreW + p * 2, coreH + p * 2, OUTLINE, Z_DARK))
	for _, s in ipairs(stars) do
		local g = glyph(ctx, "★", s.x, s.y, s.s, WHITE, Z_FILL, s.r)
		vgrad(g, pal.Bubble[1], pal.Bubble[2], 90 - s.r)
	end
	local core = corner(frame(ctx, 0, 0, coreW, coreH, WHITE, Z_FILL))
	vgrad(core, pal.Bubble[1], pal.Bubble[2])
	-- reflet
	local hi = corner(frame(ctx, -Bw * 0.2, -Bh * 0.2, Bw * 0.16, Bh * 0.1, WHITE, Z_HI, -25))
	hi.BackgroundTransparency = 0.35
	return { 0, 0, Bw * 0.95, Bh * 0.56 }
end

-- (2) Explosion « BANG » : longues pointes irrégulières autour d'un cœur ovale
function Shapes.Bang(ctx, pal, opts)
	opts = opts or {}
	local Bw, Bh, p = ctx.Bw, ctx.Bh, ctx.pad
	local n = opts.spikes or rng:NextInteger(10, 12)
	local rx, ry = Bw * 0.36, Bh * 0.34
	local perim = math.pi * (rx + ry)
	local spikes = {}
	local a0 = rnd(0, TAU)
	for i = 1, n do
		local a = a0 + (i / n) * TAU + rnd(-0.22, 0.22) * TAU / n
		local long = rng:NextNumber() < 0.35
		spikes[i] = {
			a = a,
			x = math.cos(a) * rx * 0.8,
			y = math.sin(a) * ry * 0.8,
			L = Bh * (long and rnd(0.6, 0.85) or rnd(0.34, 0.55)) * (opts.long or 1),
			w = perim / n * rnd(1.1, 1.45),
			flip = rng:NextNumber() < 0.5,
		}
	end
	local coreW, coreH = Bw * 0.84, Bh * 0.8
	local layers = { { pad = p * (opts.rim and 2.1 or 1), color = OUTLINE, z = Z_DARK, off = true } }
	if opts.rim then
		table.insert(layers, { pad = p * 1.0, color = opts.rim, z = Z_RIM })
	end
	for _, layer in ipairs(layers) do
		local q = layer.pad
		local ox, oy = layer.off and ctx.ox or 0, layer.off and ctx.oy or 0
		for _, s in ipairs(spikes) do
			local c, sn = math.cos(s.a), math.sin(s.a)
			spike(ctx, s.x - c * q + ox, s.y - sn * q + oy, s.a, s.L + q * 2.6, s.w + q * 2.2, layer.color, layer.z, s.flip)
		end
		corner(frame(ctx, ox, oy, coreW + q * 2, coreH + q * 2, layer.color, layer.z))
	end
	for _, s in ipairs(spikes) do
		local t = math.clamp(0.5 + s.y / Bh, 0, 1)
		spike(ctx, s.x, s.y, s.a, s.L, s.w, pal.Bubble[1]:Lerp(pal.Bubble[2], t * 0.6), Z_FILL, s.flip, pal.Bubble[1]:Lerp(pal.Bubble[2], 0.4 + t * 0.6))
	end
	local core = corner(frame(ctx, 0, 0, coreW, coreH, WHITE, Z_FILL))
	vgrad(core, pal.Bubble[1], pal.Bubble[2])
	local hi = corner(frame(ctx, -Bw * 0.24, -Bh * 0.22, Bw * 0.18, Bh * 0.1, WHITE, Z_HI, -20))
	hi.BackgroundTransparency = 0.35
	return { 0, 0, Bw * 0.9, Bh * 0.58 }
end

-- (3) Nuage « POOF » : cercles qui se chevauchent
function Shapes.Cloud(ctx, pal)
	local Bw, Bh, p = ctx.Bw, ctx.Bh, ctx.pad
	local n = rng:NextInteger(7, 9)
	local circles = {}
	local a0 = rnd(0, TAU)
	for i = 1, n do
		local a = a0 + (i / n) * TAU + rnd(-0.18, 0.18)
		circles[i] = { x = math.cos(a) * Bw * 0.4, y = math.sin(a) * Bh * 0.36, r = Bh * rnd(0.25, 0.37) }
	end
	local coreW, coreH = Bw * 0.88, Bh * 0.8
	for _, c in ipairs(circles) do
		local d = (c.r + p) * 2
		corner(frame(ctx, c.x + ctx.ox, c.y + ctx.oy, d, d, OUTLINE, Z_DARK))
	end
	corner(frame(ctx, ctx.ox, ctx.oy, coreW + p * 2, coreH + p * 2, OUTLINE, Z_DARK))
	for _, c in ipairs(circles) do
		local t = math.clamp(0.5 + c.y / Bh * 1.2, 0, 1)
		corner(frame(ctx, c.x, c.y, c.r * 2, c.r * 2, pal.Bubble[1]:Lerp(pal.Bubble[2], t), Z_FILL))
	end
	local core = corner(frame(ctx, 0, 0, coreW, coreH, WHITE, Z_FILL))
	vgrad(core, pal.Bubble[1], pal.Bubble[2])
	local hi1 = corner(frame(ctx, -Bw * 0.3, -Bh * 0.3, Bh * 0.2, Bh * 0.2, WHITE, Z_HI))
	hi1.BackgroundTransparency = 0.4
	local hi2 = corner(frame(ctx, -Bw * 0.19, -Bh * 0.38, Bh * 0.1, Bh * 0.1, WHITE, Z_HI))
	hi2.BackgroundTransparency = 0.4
	return { 0, 0, Bw * 0.88, Bh * 0.58 }
end

-- (4) Bulle ronde avec petite queue
function Shapes.Speech(ctx, pal)
	local Bw, Bh, p = ctx.Bw, ctx.Bh, ctx.pad
	local side = rng:NextNumber() < 0.5 and -1 or 1
	local tail = {
		x = side * Bw * rnd(0.16, 0.26),
		y = Bh * 0.3,
		a = math.rad(90 + side * rnd(20, 40)),
		L = Bh * rnd(0.45, 0.6),
		w = Bh * rnd(0.3, 0.38),
		flip = side > 0,
	}
	local ovals = { { w = Bw * 0.98, h = Bh * 0.74 }, { w = Bw * 0.74, h = Bh * 0.98 } }
	-- contour
	local c, s = math.cos(tail.a), math.sin(tail.a)
	spike(ctx, tail.x - c * p + ctx.ox, tail.y - s * p + ctx.oy, tail.a, tail.L + p * 2.6, tail.w + p * 2.2, OUTLINE, Z_DARK, tail.flip)
	for _, o in ipairs(ovals) do
		corner(frame(ctx, ctx.ox, ctx.oy, o.w + p * 2, o.h + p * 2, OUTLINE, Z_DARK))
	end
	-- couleur
	spike(ctx, tail.x, tail.y, tail.a, tail.L, tail.w, pal.Bubble[2], Z_FILL, tail.flip)
	for _, o in ipairs(ovals) do
		local f = corner(frame(ctx, 0, 0, o.w, o.h, WHITE, Z_FILL))
		vgrad(f, pal.Bubble[1], pal.Bubble[2])
	end
	local hi = corner(frame(ctx, -Bw * 0.26, -Bh * 0.28, Bw * 0.22, Bh * 0.11, WHITE, Z_HI, -18))
	hi.BackgroundTransparency = 0.25
	local dot = corner(frame(ctx, -Bw * 0.4, -Bh * 0.12, Bh * 0.08, Bh * 0.08, WHITE, Z_HI))
	dot.BackgroundTransparency = 0.25
	return { 0, -Bh * 0.02, Bw * 0.86, Bh * 0.56 }
end

-- (5) Bandeau penché : parallélogramme ou ruban à pans
function Shapes.Banner(ctx, pal)
	local Bw, Bh, p = ctx.Bw, ctx.Bh, ctx.pad
	local h = Bh * 0.66
	local para = rng:NextNumber() < 0.6
	ctx.root.Rotation = rnd(-12, 12)
	local function body(q, color, z, ox, oy, fill)
		if para then
			local rw, slant = Bw * 0.84, Bh * 0.34
			local f = frame(ctx, ox, oy, rw + q * 0.4, h + q * 2, fill and WHITE or color, z)
			if fill then
				vgrad(f, pal.Bubble[1], pal.Bubble[2])
			end
			-- pointes du parallélogramme (bas-gauche / haut-droite)
			spike(ctx, -rw / 2 + ox + q * 0.2, oy, math.pi, slant + q * 2.4, h + q * 2, fill and pal.Bubble[2] or color, z, false)
			spike(ctx, rw / 2 + ox - q * 0.2, oy, 0, slant + q * 2.4, h + q * 2, fill and pal.Bubble[1] or color, z, false)
		else
			local f = corner(frame(ctx, ox, oy, Bw + q * 2, h + q * 2, fill and WHITE or color, z), 0.18)
			if fill then
				vgrad(f, pal.Bubble[1], pal.Bubble[2])
			end
		end
	end
	if not para then
		-- pans du ruban (derrière)
		for _, sx in ipairs({ -1, 1 }) do
			local d = h * 0.75
			frame(ctx, sx * Bw * 0.5 + ctx.ox, h * 0.3 + ctx.oy, d + p * 2, d + p * 2, OUTLINE, Z_DECO_BACK, 45)
			frame(ctx, sx * Bw * 0.5, h * 0.3, d, d, pal.Bubble[2]:Lerp(OUTLINE, 0.25), Z_DECO_BACK, 45)
		end
	end
	body(p, OUTLINE, Z_DARK, ctx.ox * 1.5, ctx.oy * 1.5, false)
	body(0, nil, Z_FILL, 0, 0, true)
	local band = frame(ctx, 0, -h * 0.28, Bw * 0.78, h * 0.14, WHITE, Z_HI)
	band.BackgroundTransparency = 0.55
	return { 0, 0, Bw * 0.9, h * 0.8 }
end

-- (6) Badge électrique à dents en zigzag + éclairs
function Shapes.Zigzag(ctx, pal)
	local Bw, Bh, p = ctx.Bw, ctx.Bh, ctx.pad
	local bandW, bandH = Bw * 0.92, Bh * 0.56
	local n = 5
	local step = bandW / n
	local teeth = {}
	for i = 1, n do
		local d = step * rnd(0.62, 0.78)
		table.insert(teeth, { x = -bandW / 2 + step * (i - 0.5), y = -bandH / 2, d = d, top = true })
	end
	for i = 1, n - 1 do
		local d = step * rnd(0.62, 0.78)
		table.insert(teeth, { x = -bandW / 2 + step * i, y = bandH / 2, d = d, top = false })
	end
	ctx.root.Rotation = rnd(-10, 10)
	for _, t in ipairs(teeth) do
		frame(ctx, t.x + ctx.ox, t.y + ctx.oy, t.d + p * 2, t.d + p * 2, OUTLINE, Z_DARK, 45)
	end
	frame(ctx, ctx.ox, ctx.oy, bandW + p * 2, bandH + p * 2, OUTLINE, Z_DARK)
	for _, t in ipairs(teeth) do
		frame(ctx, t.x, t.y, t.d, t.d, t.top and pal.Bubble[1] or pal.Bubble[2], Z_FILL, 45)
	end
	local band = frame(ctx, 0, 0, bandW, bandH, WHITE, Z_FILL)
	vgrad(band, pal.Bubble[1], pal.Bubble[2])
	-- éclairs : deux triangles opposés de chaque côté
	for _, sx in ipairs({ -1, 1 }) do
		local bx, by = sx * Bw * 0.6, -Bh * 0.05
		local L, w = Bh * 0.55, Bh * 0.2
		local a1 = math.rad(sx > 0 and -60 or -120)
		local a2 = a1 + math.pi
		for _, layer in ipairs({ { q = p, c = OUTLINE, z = Z_DECO_BACK }, { q = 0, c = YELLOW, z = Z_DECO } }) do
			local q = layer.q
			spike(ctx, bx - math.cos(a1) * q - sx * w * 0.25, by - math.sin(a1) * q, a1, L + q * 2.6, w + q * 2.2, layer.c, layer.z, sx > 0)
			spike(ctx, bx - math.cos(a2) * q + sx * w * 0.25, by - math.sin(a2) * q, a2, L + q * 2.6, w + q * 2.2, layer.c, layer.z, sx > 0)
		end
	end
	return { 0, 0, bandW * 0.92, bandH * 0.86 }
end

-- (7) Mot seul : gros texte contouré + petites étoiles
function Shapes.Plain(ctx, pal)
	ctx.noBubble = true
	return { 0, 0, ctx.Bw * 1.2, ctx.Bh * 0.9 }
end

------------------------------------------------------------------------
-- Décorations
------------------------------------------------------------------------
local function addStars(ctx, n, pal)
	local list = {}
	for i = 1, n do
		local a = (i / n) * TAU + rnd(-0.5, 0.5)
		local s = ctx.Bh * rnd(0.2, 0.32)
		local l = glyph(ctx, "★", math.cos(a) * ctx.Bw * rnd(0.52, 0.62), math.sin(a) * ctx.Bh * rnd(0.55, 0.72), s, pick({ YELLOW, WHITE, pal.Text[1], pal.Bubble[1] }), Z_DECO, rnd(0, 72))
		stroke(l, math.clamp(s * ctx.ppS * 0.07, 1, 4))
		table.insert(list, l)
	end
	return list
end

local function addSpeedLines(ctx, n)
	local side = rng:NextNumber() < 0.5 and -1 or 1
	for i = 1, n do
		local y = (i - (n + 1) / 2) * ctx.Bh * 0.2 + rnd(-0.04, 0.04) * ctx.Bh
		local len = ctx.Bw * rnd(0.16, 0.3)
		local f = frame(ctx, side * (ctx.Bw * 0.6 + len / 2), y, len, ctx.Bh * 0.045, OUTLINE, Z_DECO_BACK, rnd(-6, 6))
		corner(f, 0.5)
	end
end

local function addPuffs(ctx, n)
	for i = 1, n do
		local sx = (i % 2 == 0) and 1 or -1
		local s = ctx.Bh * rnd(0.22, 0.34)
		local l = glyph(ctx, "●", sx * ctx.Bw * rnd(0.42, 0.55), ctx.Bh * rnd(0.28, 0.5), s, WHITE, Z_DECO, 0)
		stroke(l, math.clamp(s * ctx.ppS * 0.06, 1, 3))
	end
end

------------------------------------------------------------------------
-- Texte (bloc unique ou lettre par lettre pour les gros coups)
------------------------------------------------------------------------
local function textStyle(ctx, l, pal, th)
	l.BackgroundTransparency = 1
	l.TextScaled = true
	if ctx.fontFace then
		l.FontFace = ctx.fontFace
	else
		l.Font = ctx.font
	end
	l.TextColor3 = WHITE
	l.ZIndex = Z_TEXT
	vgrad(l, pal.Text[1], pal.Text[2])
	stroke(l, math.clamp(th * ctx.ppS * 0.085, 1.5, 7))
end

local function buildText(ctx, text, box, pal, perLetter)
	local x, y, w, h = box[1], box[2], box[3], box[4]
	local chars = {}
	for _, code in utf8.codes(text) do
		table.insert(chars, utf8.char(code))
	end
	if perLetter and #chars >= 2 and #chars <= 10 then
		local widths, total = {}, 0
		for i, ch in ipairs(chars) do
			local size = TextService:GetTextSize(ch, 100, ctx.font, Vector2.new(10000, 10000))
			widths[i] = h * size.X / math.max(size.Y, 1)
			total += widths[i] * 0.94
		end
		if total > w then
			local k = w / total
			h *= k
			total = w
			for i in ipairs(widths) do
				widths[i] *= k
			end
		end
		local cx = x - total / 2
		for i, ch in ipairs(chars) do
			local lw = widths[i] * 0.94
			if ch ~= " " then
				local s = rnd(0.9, 1.1)
				local l = Instance.new("TextLabel")
				l.AnchorPoint = Vector2.new(0.5, 0.5)
				l.Position = UDim2.fromScale(0.5 + (cx + lw / 2) / ctx.W, 0.5 + (y + rnd(-0.07, 0.07) * h) / ctx.H)
				l.Size = UDim2.fromScale(widths[i] * 1.35 * s / ctx.W, h * s / ctx.H)
				l.Rotation = rnd(-10, 10)
				l.Text = ch
				l.Parent = ctx.root
				ctx.count += 1
				textStyle(ctx, l, pal, h)
			end
			cx += lw
		end
		return
	end
	local l = Instance.new("TextLabel")
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = UDim2.fromScale(0.5 + x / ctx.W, 0.5 + y / ctx.H)
	l.Size = UDim2.fromScale(w / ctx.W, h / ctx.H)
	l.Rotation = rnd(-5, 5)
	l.Text = text
	l.Parent = ctx.root
	ctx.count += 1
	textStyle(ctx, l, pal, math.min(h, w / math.max(#chars * 0.55, 1)))
end

------------------------------------------------------------------------
-- Choix forme / palette
------------------------------------------------------------------------
local lastShape -- évite deux fois la même forme d'affilée

local function chooseShape(category, upper)
	local shapes = Words.CategoryShapes or DEFAULT_SHAPES
	local weights = shapes[category] or DEFAULT_SHAPES[category] or shapes.Default or DEFAULT_SHAPES.Default
	local shape = ComicWords.forceShape or weighted(weights)
	if not ComicWords.forceShape and shape == lastShape and category ~= "KO" and category ~= "Electric" then
		shape = weighted(weights)
	end
	if upper:find("POOF") or upper:find("PUFF") then
		shape = "Cloud"
	end
	if not Shapes[shape] then
		shape = "Star"
	end
	lastShape = shape
	return shape
end

local function choosePalette(category)
	if category == "KO" then
		return Words.KOPalette or DEFAULT_KO
	end
	local list = Words.Palettes or DEFAULT_PALETTES
	local prefs = Words.CategoryPalettes and Words.CategoryPalettes[category]
	if prefs and rng:NextNumber() < 0.7 then
		local name = pick(prefs)
		for _, pal in ipairs(list) do
			if pal.Name == name then
				return pal
			end
		end
	end
	return pick(list)
end

local function pixelsPerStud(worldPos)
	local cam = workspace.CurrentCamera
	if not cam then
		return 40
	end
	local d = math.max((cam.CFrame.Position - worldPos).Magnitude, 2)
	return cam.ViewportSize.Y / (2 * d * math.tan(math.rad(cam.FieldOfView) / 2))
end

------------------------------------------------------------------------
-- API
------------------------------------------------------------------------
function ComicWords.create(pos: Vector3, text: string, power: number?, category: string?)
	text = tostring(text or "POW!")
	local pw = math.clamp(tonumber(power) or 0.4, 0, 1.5)
	local upper = string.upper(text)
	local cat = category or "Light"
	if upper:find("ZAP") or upper:find("BZZ") or upper:find("ZZT") then
		cat = "Electric"
	end
	local isKO = cat == "KO"
	local heavy = isKO or pw >= 0.85

	-- taille : 3–6,5 studs de large pour un coup normal, ~8–9 pour un K.O.
	local len = utf8.len(text) or #text
	local lenK = math.clamp(1 + (len - 6) * 0.06, 1, 1.4)
	local Bw = (isKO and 6.2 or (2.3 + pw * 1.9)) * lenK
	local Bh = Bw * 0.6 / math.sqrt(lenK)
	local life = isKO and 1.2 or (0.6 + pw * 0.1)

	local worldPos = pos + Vector3.new(rnd(-0.8, 0.8), 1.2 + rnd(0, 0.8), rnd(-0.8, 0.8))
	local att = Instance.new("Attachment")
	att.Name = "ComicWord"
	att.WorldPosition = worldPos
	att.Parent = workspace.Terrain
	Debris:AddItem(att, life + 0.45)

	local W, H = Bw * 1.25, Bh * 1.4
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(W, H)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 160
	bb.ResetOnSpawn = false
	bb.ClipsDescendants = false
	bb.ZIndexBehavior = Enum.ZIndexBehavior.Global
	bb.Adornee = att

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Rotation = rnd(-14, 14)
	root.Parent = bb
	local scale = Instance.new("UIScale")
	scale.Scale = ComicWords.static and 1 or 0
	scale.Parent = root

	local fonts = Words.ComicFonts or { Enum.Font.Bangers, Enum.Font.LuckiestGuy }
	local ctx = {
		root = root,
		W = W,
		H = H,
		Bw = Bw,
		Bh = Bh,
		pad = Bh * 0.065,
		ox = Bh * 0.03,
		oy = Bh * 0.045,
		ppS = pixelsPerStud(worldPos),
		-- police pixel du thème (Press Start 2P) ; ComicWords.legacyFont = true pour revenir aux polices BD
		font = ComicWords.legacyFont and (isKO and Enum.Font.LuckiestGuy or pick(fonts)) or UITheme.DisplayEnum,
		fontFace = (not ComicWords.legacyFont) and UITheme.Display or nil,
		count = 0,
	}

	local pal = choosePalette(cat)
	local shape = chooseShape(cat, upper)
	local box
	if isKO then
		box = Shapes.Bang(ctx, pal, { spikes = 12, long = 1.05, rim = pal.Rim or YELLOW })
	else
		box = Shapes[shape](ctx, pal)
	end

	-- trame de points (halftone)
	local dots = pal.Dots or pal.Bubble[2]:Lerp(OUTLINE, 0.3)
	if isKO then
		halftone(ctx, Bw * 0.52, Bh * 0.42, Bh * 0.75, dots, Z_DOTS_BACK, true, 0.1)
		halftone(ctx, -Bw * 0.52, -Bh * 0.42, Bh * 0.75, dots, Z_DOTS_BACK, false, 0.1)
	elseif ctx.noBubble then
		halftone(ctx, Bw * rnd(0.15, 0.3), Bh * 0.18, Bh * 0.6, pal.Text[2], Z_DOTS_BACK, true, 0.35)
	elseif shape ~= "Zigzag" and shape ~= "Banner" or rng:NextNumber() < 0.5 then
		local right = rng:NextNumber() < 0.5
		halftone(ctx, (right and 1 or -1) * Bw * 0.22, (right and 1 or -1) * Bh * 0.16, Bh * 0.42, dots, Z_HI, right, 0.35)
	end

	-- décorations
	local stars
	if isKO then
		stars = addStars(ctx, 4, pal)
	elseif ctx.noBubble then
		stars = addStars(ctx, rng:NextInteger(3, 5), pal)
		if rng:NextNumber() < 0.6 then
			addSpeedLines(ctx, 3)
		end
	elseif shape == "Cloud" then
		addPuffs(ctx, rng:NextInteger(2, 3))
	elseif rng:NextNumber() < 0.55 then
		stars = addStars(ctx, rng:NextInteger(1, 3), pal)
	end
	if not isKO and not ctx.noBubble and shape ~= "Cloud" and (cat == "Light" or cat == "Projectile" or cat == "Air") and rng:NextNumber() < 0.5 then
		addSpeedLines(ctx, rng:NextInteger(3, 4))
	end

	-- texte : lettre par lettre (« wobble ») pour les gros coups si le budget d'objets le permet
	local perLetter = (heavy or ctx.noBubble) and ctx.count + len * 3 < 75
	if ctx.fontFace then
		-- la police pixel est très large : on laisse le mot déborder un peu de la bulle (façon BD)
		box = { box[1], box[2], box[3] * 1.14, box[4] * 1.06 }
	end
	buildText(ctx, text, box, pal, perLetter)

	bb.Parent = att

	if ComicWords.static then
		return bb
	end

	-- animation : pop 0 → 1.35 → 0.95 → 1, tremblement si gros coup, dérive, puis sortie vers le haut
	local rot0 = root.Rotation
	tween(scale, 0.1, { Scale = 1.35 }, Enum.EasingStyle.Back)
	task.delay(0.1, function()
		tween(scale, 0.07, { Scale = 0.95 }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
		task.delay(0.07, function()
			tween(scale, 0.09, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end)
	tween(root, life + 0.25, { Rotation = rot0 + rnd(-6, 6) }, Enum.EasingStyle.Linear)
	if stars then
		for _, s in ipairs(stars) do
			tween(s, life, { Rotation = s.Rotation + rnd(-120, 120) }, Enum.EasingStyle.Linear)
		end
	end
	if heavy then
		task.spawn(function()
			for i = 1, 7 do
				if not root.Parent then
					return
				end
				local a = (isKO and 0.05 or 0.035) * (1 - i / 8)
				root.Position = UDim2.fromScale(0.5 + rnd(-a, a), 0.5 + rnd(-a, a))
				task.wait(0.03)
			end
			root.Position = UDim2.fromScale(0.5, 0.5)
		end)
	end
	task.delay(life, function()
		if not bb.Parent then
			return
		end
		tween(scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(bb, 0.22, { StudsOffsetWorldSpace = Vector3.new(0, 1.1, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end)
	return bb
end

return ComicWords
