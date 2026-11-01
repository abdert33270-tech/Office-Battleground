--[[
	SkinList.Pack6 — skins v3 (Rare / Epic / Legendary) des persos premium OfficeCat et AIAssistant.
	Chaque entrée REMPLACE celle de même Id dans SkinList (voir CONTRACT_SKINS_V3).
	Repères R6 : tête (visuel ~1,25, dessus ~+0,62, visage en -Z), buste 2x2x1, membres 1x2x1.
	Offsets relatifs au centre du membre ; -Z = devant ; +X = côté droit du perso.
	Meshes générés : SkinAssets.OfficeCat_Legendary_Head (tête de chat porte-bonheur), SkinAssets.AIAssistant_Legendary_Helmet.
]]
local C, V = Color3.fromRGB, Vector3.new
local rad = math.rad
local SP, NE, ME, FF, FA = "SmoothPlastic", "Neon", "Metal", "ForceField", "Fabric"
local H, T, LA, RA, LL, RL = "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"
local B, CY, WE = "Block", "Cylinder", "Wedge"

-- pièce soudée à un membre (rotations en degrés)
local function P(limb, shape, size, col, mat, x, y, z, rx, ry, rz, opt)
	if type(rx) == "table" then
		opt, rx = rx, nil
	end
	local t = {
		Limb = limb, Shape = shape, Size = size, Color = col, Material = mat or SP,
		Offset = CFrame.new(x or 0, y or 0, z or 0) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0)),
	}
	if opt then
		for k, v in pairs(opt) do
			t[k] = v
		end
	end
	return t
end
-- pièce arrondie (SpecialMesh Sphere)
local function R(limb, size, col, mat, x, y, z, rx, ry, rz, opt)
	local t = P(limb, B, size, col, mat, x, y, z, rx, ry, rz, opt)
	t.Mesh = { Type = "Sphere" }
	return t
end
-- pièce avec CFrame libre
local function E(limb, shape, size, col, mat, cf, opt)
	local t = { Limb = limb, Shape = shape, Size = size, Color = col, Material = mat or SP, Offset = cf }
	if opt then
		for k, v in pairs(opt) do
			t[k] = v
		end
	end
	return t
end
-- mesh généré (SkinAssets)
local function A(limb, asset, size, x, y, z, opt)
	local t = { Limb = limb, Asset = asset, Size = size, Offset = CFrame.new(x or 0, y or 0, z or 0) }
	if opt then
		for k, v in pairs(opt) do
			t[k] = v
		end
	end
	return t
end
local function join(...)
	local out = {}
	for _, l in ipairs({ ... }) do
		for _, p in ipairs(l) do
			out[#out + 1] = p
		end
	end
	return out
end
local function sym(limbL, limbR, fn)
	local out = {}
	for _, e in ipairs({ { limbL, -1 }, { limbR, 1 } }) do
		for _, p in ipairs(fn(e[1], e[2])) do
			out[#out + 1] = p
		end
	end
	return out
end
local function ring(limb, shape, size, col, mat, r, y, ang, opt, face)
	local a = rad(ang)
	return P(limb, shape, size, col, mat, r * math.cos(a), y, -r * math.sin(a), 0, ang + (face or 90), 0, opt)
end
-- oreilles de chat : deux demi-coins dos à dos par oreille (+ intérieur)
local function ears(col, inner, sc, mat, opt, innerMat)
	sc = sc or 1
	local out = {}
	for _, s in ipairs({ -1, 1 }) do
		local base = CFrame.new(0.42 * s, 0.8 + 0.06 * (sc - 1), 0.05) * CFrame.Angles(0, 0, -0.28 * s)
		for _, h in ipairs({ -1, 1 }) do
			out[#out + 1] = E(H, WE, V(0.16, 0.62, 0.27) * sc, col, mat, base * CFrame.new(0.135 * h * sc, 0, 0) * CFrame.Angles(0, -h * math.pi / 2, 0), opt)
			if inner then
				out[#out + 1] = E(H, WE, V(0.06, 0.4, 0.16) * sc, inner, innerMat or SP, base * CFrame.new(0.08 * h * sc, -0.08 * sc, -0.09) * CFrame.Angles(0, -h * math.pi / 2, 0), opt)
			end
		end
	end
	return out
end
-- queue en S (boules), cols = couleurs alternées, tip = bout
local TAIL = { { -0.75, 0.62, 0.56 }, { -0.85, 0.98, 0.54 }, { -0.62, 1.32, 0.52 }, { -0.22, 1.52, 0.5 }, { 0.22, 1.56, 0.48 }, { 0.62, 1.42, 0.48 } }
local function tail(cols, tip, mat, n, opt, tipOpt)
	n = n or #TAIL
	local out = {}
	for i = 1, n do
		local p = TAIL[i]
		local last = i == n
		out[#out + 1] = R(T, V(p[3], p[3], p[3]), last and tip or cols[(i - 1) % #cols + 1], mat, 0, p[1], p[2], 0, 0, 0, last and tipOpt or opt)
	end
	return out
end

-- Paint
local function bx(x, y, w, h, col, o)
	local e = { Type = "Box", Pos = { x, y }, Size = { w, h }, Color = col }
	if o then
		for k, v in pairs(o) do
			e[k] = v
		end
	end
	return e
end
local function ci(x, y, w, h, col, o)
	local e = bx(x, y, w, h, col, o)
	e.Type = "Circle"
	return e
end
local function tx(x, y, w, h, text, col, font, o)
	local e = bx(x, y, w, h, col, o)
	e.Type = "Text"
	e.Text = text
	e.Font = font or "Black"
	return e
end
local function ln(x0, y0, x1, y1, col, w)
	return { Type = "Line", From = { x0, y0 }, To = { x1, y1 }, Color = col, Width = w or 3 }
end
local function face(limb, f, els, glow)
	return { Limb = limb, Face = f, Elements = els, Glow = glow }
end

local WHT, BLK, PINK = C(245, 245, 245), C(22, 22, 28), C(255, 140, 175)

local L = {}
local function S(def)
	if def.HideIdentity == nil then
		def.HideIdentity = true
	end
	L[#L + 1] = def
end

-- ===================== THE OFFICE CAT =====================
-- visage de chat peint (fond, yeux, nez, bouche en w, moustaches)
local function catFace(bg, eye, pupil, muzzle, whisker)
	local els = { bx(0.5, 0.5, 1, 1, bg) }
	if muzzle then
		els[#els + 1] = ci(0.5, 0.74, 0.58, 0.4, muzzle)
	end
	for _, x in ipairs({ 0.33, 0.67 }) do
		els[#els + 1] = ci(x, 0.43, 0.2, 0.18, eye, { Stroke = { BLK, 2 } })
		els[#els + 1] = bx(x, 0.43, 0.045, 0.15, pupil, { Corner = 1 })
		els[#els + 1] = ci(x + 0.04, 0.395, 0.05, 0.05, WHT)
	end
	els[#els + 1] = bx(0.5, 0.62, 0.1, 0.06, PINK, { Corner = 0.6 })
	els[#els + 1] = ln(0.5, 0.65, 0.45, 0.71, BLK, 3)
	els[#els + 1] = ln(0.5, 0.65, 0.55, 0.71, BLK, 3)
	for _, s in ipairs({ -1, 1 }) do
		els[#els + 1] = ln(0.5 + 0.18 * s, 0.66, 0.5 + 0.42 * s, 0.62, whisker, 2)
		els[#els + 1] = ln(0.5 + 0.18 * s, 0.7, 0.5 + 0.42 * s, 0.72, whisker, 2)
		els[#els + 1] = ci(0.5 + 0.27 * s, 0.6, 0.1, 0.06, PINK, { Transparency = 0.5 })
	end
	return els
end

-- ---------- Rare : Tuxedo Cat ----------
local TUX, TUXRED = C(20, 20, 26), C(220, 40, 60)
S({ Id = "OfficeCat_Rare", Character = "OfficeCat", Rarity = "Rare", Name = "Tuxedo Cat",
	Desc = "Black tie, white paws, zero manners. Dressed for the board meeting, ready to knock it over.",
	Outfit = { Shirt = TUX, Pants = TUX },
	HideFace = true, HideHair = true,
	Parts = join(
		ears(BLK, PINK),
		{
			R(H, V(1.36, 0.75, 1.38), BLK, SP, 0, 0.42, 0.05), -- haut du crâne
			R(H, V(1.3, 1.1, 0.7), BLK, SP, 0, 0.08, 0.36), -- arrière de la tête
			-- nœud papillon rouge
			P(T, B, V(0.42, 0.34, 0.12), TUXRED, SP, -0.24, 0.84, -0.58, 0, 0, -12),
			P(T, B, V(0.42, 0.34, 0.12), TUXRED, SP, 0.24, 0.84, -0.58, 0, 0, 12),
			R(T, V(0.2, 0.2, 0.16), C(170, 25, 40), SP, 0, 0.84, -0.62),
			-- queue-de-pie
			P(T, B, V(0.85, 1.25, 0.1), C(12, 12, 16), FA, -0.45, -1.3, 0.55, -8, 0, -5),
			P(T, B, V(0.85, 1.25, 0.1), C(12, 12, 16), FA, 0.45, -1.3, 0.55, -8, 0, 5),
		},
		sym(LA, RA, function(l)
			return { R(l, V(1.16, 0.62, 1.16), WHT, SP, 0, -0.8, 0) }
		end),
		sym(LL, RL, function(l)
			return { P(l, B, V(1.08, 0.45, 1.3), WHT, SP, 0, -0.8, -0.12) }
		end),
		tail({ BLK }, WHT, SP, 5)
	),
	Paint = {
		face(H, "Front", catFace(BLK, C(140, 230, 90), BLK, WHT, C(120, 120, 120))),
		face(H, "Left", { bx(0.5, 0.5, 1, 1, BLK) }),
		face(H, "Right", { bx(0.5, 0.5, 1, 1, BLK) }),
		face(T, "Front", {
			bx(0.5, 0.36, 0.44, 0.72, WHT),
			bx(0.35, 0.34, 0.12, 0.62, C(10, 10, 14), { Rotation = -16 }),
			bx(0.65, 0.34, 0.12, 0.62, C(10, 10, 14), { Rotation = 16 }),
			ci(0.5, 0.48, 0.05, 0.05, BLK), ci(0.5, 0.6, 0.05, 0.05, BLK),
			bx(0.8, 0.3, 0.12, 0.06, TUXRED, { Rotation = -8 }),
			bx(0.5, 0.9, 1, 0.06, C(40, 40, 48)),
		}),
		face(LA, "Bottom", { ci(0.5, 0.6, 0.45, 0.35, PINK), ci(0.25, 0.25, 0.18, 0.18, PINK), ci(0.5, 0.18, 0.18, 0.18, PINK), ci(0.75, 0.25, 0.18, 0.18, PINK) }),
		face(RA, "Bottom", { ci(0.5, 0.6, 0.45, 0.35, PINK), ci(0.25, 0.25, 0.18, 0.18, PINK), ci(0.5, 0.18, 0.18, 0.18, PINK), ci(0.75, 0.25, 0.18, 0.18, PINK) }),
	},
	HitColor = TUXRED,
})

-- ---------- Epic : Cyber Kitty ----------
local DPUR, NPINK, NCYAN, DGREY, LAV = C(40, 25, 70), C(255, 60, 200), C(40, 230, 255), C(32, 32, 42), C(245, 232, 250)
local pulse = { Anim = { Pulse = 0.35, PulseSpeed = 3, React = true, Seed = 61 } }
S({ Id = "OfficeCat_Epic", Character = "OfficeCat", Rarity = "Epic", Name = "Cyber Kitty",
	Desc = "Neon ears, LED tail, all nine lives backed up to the cloud.",
	Outfit = { Shirt = DPUR, Pants = DGREY },
	HideFace = true, HideHair = true,
	Parts = join(
		ears(NPINK, NCYAN, 1.1, NE, nil, NE),
		{
			R(H, V(1.4, 0.7, 1.42), C(250, 200, 240), SP, 0, 0.44, 0.06), -- cheveux/fourrure lavande
			R(H, V(1.44, 0.3, 1.46), DGREY, SP, 0, 0.56, 0.02), -- arceau du casque
			P(H, CY, V(0.25, 0.62, 0.62), DGREY, SP, -0.68, 0.05, 0),
			P(H, CY, V(0.25, 0.62, 0.62), DGREY, SP, 0.68, 0.05, 0),
			P(H, CY, V(0.27, 0.4, 0.4), NPINK, NE, -0.7, 0.05, 0, pulse),
			P(H, CY, V(0.27, 0.4, 0.4), NPINK, NE, 0.7, 0.05, 0, pulse),
			P(H, B, V(0.07, 0.45, 0.07), DGREY, SP, -0.62, -0.28, -0.28, 45, 0, 0), -- micro
			R(H, V(0.16, 0.16, 0.16), NCYAN, NE, -0.62, -0.45, -0.5),
			-- capuche du hoodie
			R(T, V(1.7, 0.55, 0.7), DPUR, FA, 0, 1.02, 0.45),
			P(T, B, V(0.08, 0.6, 0.08), NCYAN, SP, -0.3, 0.55, -0.55), -- cordons
			P(T, B, V(0.08, 0.6, 0.08), NCYAN, SP, 0.3, 0.55, -0.55),
			-- poisson holographique (transformation) + pelote en orbite
			R(T, V(0.9, 0.5, 0.3), NCYAN, NE, 1.6, 1.7, 0.4, { Transform = true, Anim = { Float = true, Seed = 62 } }),
			P(T, WE, V(0.15, 0.5, 0.4), NCYAN, NE, 2.15, 1.7, 0.4, 0, 90, 0, { Transform = true, Anim = { Float = true, Seed = 62 } }),
			R(T, V(0.6, 0.6, 0.6), NPINK, FF, 2.2, 0.2, 0, { Anim = { Circle = 1.6, Seed = 63 } }),
		},
		sym(LA, RA, function(l)
			return {
				R(l, V(1.16, 0.64, 1.16), DGREY, SP, 0, -0.78, 0),
				P(l, B, V(0.62, 0.08, 0.5), NCYAN, NE, 0, -1.1, 0),
				P(l, B, V(1.06, 0.1, 1.06), NPINK, NE, 0, 0.2, 0, pulse),
			}
		end),
		sym(LL, RL, function(l)
			return {
				P(l, B, V(1.08, 0.45, 1.3), WHT, SP, 0, -0.8, -0.12),
				P(l, B, V(1.1, 0.1, 1.34), NCYAN, NE, 0, -0.98, -0.12),
			}
		end),
		tail({ DGREY, NPINK }, NCYAN, SP, 6, nil, { Material = NE, Particles = { Kind = "Sparkle", Color = NPINK, Rate = 6, Speed = 1.5, Size = 0.3, Life = 0.8, Spread = 180, React = true } })
	),
	Paint = {
		face(H, "Front", {
			bx(0.5, 0.5, 1, 1, LAV),
			ci(0.32, 0.45, 0.22, 0.25, NCYAN, { Stroke = { DGREY, 3 } }), ci(0.68, 0.45, 0.22, 0.25, NCYAN, { Stroke = { DGREY, 3 } }),
			ci(0.33, 0.48, 0.1, 0.13, DGREY), ci(0.67, 0.48, 0.1, 0.13, DGREY),
			ci(0.36, 0.41, 0.06, 0.06, WHT), ci(0.7, 0.41, 0.06, 0.06, WHT),
			bx(0.5, 0.64, 0.08, 0.05, NPINK, { Corner = 0.6 }),
			ln(0.5, 0.67, 0.45, 0.72, DGREY, 3), ln(0.5, 0.67, 0.55, 0.72, DGREY, 3),
			ln(0.3, 0.66, 0.06, 0.62, NPINK, 2), ln(0.3, 0.7, 0.06, 0.72, NPINK, 2),
			ln(0.7, 0.66, 0.94, 0.62, NPINK, 2), ln(0.7, 0.7, 0.94, 0.72, NPINK, 2),
			ci(0.22, 0.6, 0.1, 0.06, NPINK, { Transparency = 0.5 }), ci(0.78, 0.6, 0.1, 0.06, NPINK, { Transparency = 0.5 }),
		}),
		face(H, "Left", { bx(0.5, 0.5, 1, 1, LAV) }),
		face(H, "Right", { bx(0.5, 0.5, 1, 1, LAV) }),
		face(H, "Back", { bx(0.5, 0.5, 1, 1, LAV) }),
		face(T, "Front", {
			ln(0.5, 0.05, 0.5, 1, NCYAN, 3),
			ci(0.5, 0.42, 0.34, 0.3, NPINK),
			bx(0.38, 0.27, 0.1, 0.12, NPINK, { Rotation = -25 }), bx(0.62, 0.27, 0.1, 0.12, NPINK, { Rotation = 25 }),
			tx(0.5, 0.43, 0.26, 0.14, "=^.^=", DPUR, "Arcade"),
			bx(0.5, 0.8, 0.62, 0.18, C(58, 38, 98), { Corner = 0.3 }),
		}, true),
		face(T, "Back", { tx(0.5, 0.45, 0.85, 0.18, "MEOW.EXE", NCYAN, "Arcade"), bx(0.5, 0.6, 0.6, 0.03, NPINK) }, true),
	},
	FX = { HandTrails = NPINK },
	Highlight = { Outline = NCYAN },
	HitColor = NPINK,
})

-- ---------- Legendary : Lucky Fortune Cat ----------
local LWHT, LRED, LGOLD, LGOLDD, CALI = C(252, 250, 244), C(220, 35, 45), C(255, 200, 40), C(215, 155, 30), C(255, 150, 50)
local coin = function(ang, y)
	return ring(T, CY, V(0.12, 0.7, 0.7), LGOLD, ME, 2.3, y, ang, { Anim = { Circle = 1.2, Seed = 71, React = true }, Reflect = 0.3 }, 0)
end
S({ Id = "OfficeCat_Legendary", Character = "OfficeCat", Rarity = "Legendary", Name = "Lucky Fortune Cat",
	Desc = "Waves one paw, brings fortune to the office. Brings ruin to your coworkers.",
	Outfit = { Shirt = LWHT, Pants = LWHT },
	HideFace = true, HideHair = true,
	Parts = join(
		{
			A(H, "OfficeCat_Legendary_Head", V(2.3, 2.35, 1.95), 0, 0.42, -0.05),
			P(T, CY, V(0.3, 1.45, 1.45), LRED, FA, 0, 1.0, 0, 0, 0, 90), -- collier
			R(T, V(0.62, 0.62, 0.62), LGOLD, ME, 0, 0.7, -0.74, { Reflect = 0.35, Light = LGOLD }), -- grelot
			-- v4 : nœud de ruban derrière le grelot + porte-bonheur (omamori) dans la patte droite
			R(T, V(0.5, 0.32, 0.14), LRED, FA, -0.32, 0.78, -0.6, 0, 0, 20),
			R(T, V(0.5, 0.32, 0.14), LRED, FA, 0.32, 0.78, -0.6, 0, 0, -20),
			P(RA, B, V(0.42, 0.6, 0.16), LRED, FA, 0, -1.35, -0.42, { Text = { Text = "福", Color = LGOLD, Font = "Black" } }),
			P(RA, B, V(0.44, 0.08, 0.18), LGOLD, ME, 0, -1.06, -0.42),
			P(T, B, V(0.4, 0.05, 0.14), LGOLDD, ME, 0, 0.6, -1.0),
			R(T, V(1.45, 0.95, 0.14), LRED, FA, 0, 0.3, -0.56, { Text = { Text = "LUCK", Font = "Bangers", Color = LGOLD } }), -- bavoir
			-- koban (pièce d'or ovale) dans la patte gauche
			P(LA, B, V(0.16, 1.45, 0.95), LGOLD, ME, 0, -1.55, -0.55, 0, 90, 0, { Mesh = { Type = "Cylinder" }, Reflect = 0.3, Text = { Text = "$$$", Font = "Bangers", Color = LGOLDD, Face = "Right" } }),
			-- particules dorées
			P(T, B, V(0.2, 0.2, 0.2), LGOLD, SP, 0, 2.8, 0, { Transparency = 1, Particles = { Kind = "Sparkle", Color = LGOLD, Rate = 8, Speed = 2, Size = 0.35, Life = 1.2, Spread = 180, React = true } }),
			-- transformation : grande pièce porte-bonheur qui tourne dans le dos + patte dorée qui fait coucou
			P(T, CY, V(0.2, 4.2, 4.2), LGOLD, NE, 0, 1.5, 1.35, 0, 90, 0, { Transform = true, Anim = { Spin = 40, Axis = "X" } }),
			P(T, B, V(0.26, 1.2, 1.2), LRED, SP, 0, 1.5, 1.32, 0, 90, 0, { Transform = true }),
			R(T, V(1.2, 1.3, 0.45), LGOLD, NE, 1.7, 1.9, 0.2, { Transform = true, Anim = { Swing = 25, SwingAxis = "Z", SwingSpeed = 6 } }),
		},
		{ coin(0, 0.3), coin(60, 0.9), coin(120, 0.3), coin(180, 0.9), coin(240, 0.3), coin(300, 0.9) },
		sym(LA, RA, function(l)
			return {
				-- v4 : mantelet de fête (épaules rouges bordées d'or)
				R(l, V(1.32, 0.5, 1.32), LRED, FA, 0, 0.9, 0),
				P(l, B, V(1.34, 0.07, 1.34), LGOLD, ME, 0, 0.72, 0),
				R(l, V(1.3, 0.9, 1.3), LWHT, SP, 0, -0.85, 0),
				P(l, B, V(1.08, 0.14, 1.08), LGOLD, ME, 0, 0.15, 0),
				P(l, B, V(1.08, 0.08, 1.08), LRED, FA, 0, 0.0, 0),
			}
		end),
		sym(LL, RL, function(l)
			return { R(l, V(1.15, 0.55, 1.45), LWHT, SP, 0, -0.78, -0.15) }
		end),
		tail({ LWHT, CALI, LWHT, BLK }, LGOLD, SP, 6, nil, { Material = NE })
	),
	Paint = {
		face(T, "Front", { ci(0.5, 0.75, 0.75, 0.5, C(255, 253, 248)), bx(0.5, 0.97, 1, 0.06, LGOLD) }),
		face(T, "Back", {
			ci(0.3, 0.3, 0.32, 0.28, CALI), ci(0.72, 0.55, 0.28, 0.26, BLK), ci(0.4, 0.78, 0.22, 0.2, CALI),
			tx(0.5, 0.92, 0.7, 0.1, "FORTUNE", LGOLDD, "Bangers"),
		}),
		face(LA, "Bottom", { ci(0.5, 0.6, 0.45, 0.35, PINK), ci(0.25, 0.25, 0.18, 0.18, PINK), ci(0.5, 0.18, 0.18, 0.18, PINK), ci(0.75, 0.25, 0.18, 0.18, PINK) }),
		face(RA, "Bottom", { ci(0.5, 0.6, 0.45, 0.35, PINK), ci(0.25, 0.25, 0.18, 0.18, PINK), ci(0.5, 0.18, 0.18, 0.18, PINK), ci(0.75, 0.25, 0.18, 0.18, PINK) }),
		face(LL, "Front", { bx(0.5, 0.15, 1, 0.08, LGOLD) }),
		face(RL, "Front", { bx(0.5, 0.15, 1, 0.08, LGOLD) }),
	},
	FX = { PowerAura = LGOLD, Spotlight = C(255, 240, 200) },
	Highlight = { Outline = LGOLD },
	HitColor = LGOLD,
})

-- ===================== THE AI ASSISTANT =====================
-- ---------- Rare : Retro PC ----------
local BEIGE, BEIGE2, SCR, GRN, GREY = C(225, 215, 180), C(195, 185, 150), C(18, 28, 20), C(80, 255, 120), C(120, 120, 130)
S({ Id = "AIAssistant_Rare", Character = "AIAssistant", Rarity = "Rare", Name = "Retro PC",
	Desc = "Running on 640K of pure confidence. Please do not unplug.",
	Outfit = { Shirt = BEIGE, Pants = GREY },
	HideFace = true, HideHair = true,
	Parts = join(
		{
			P(H, B, V(1.75, 1.5, 1.45), BEIGE, SP, 0, 0.12, 0.12), -- moniteur CRT
			P(H, B, V(1.3, 1.1, 0.6), BEIGE2, SP, 0, 0.12, 1.0),
			P(H, B, V(1.42, 1.14, 0.06), BEIGE2, SP, 0, 0.18, -0.61),
			P(H, B, V(1.26, 0.98, 0.06), SCR, SP, 0, 0.18, -0.65, { Text = { Text = "^_^", Font = "Code", Color = GRN }, Light = GRN }),
			P(H, B, V(0.14, 0.08, 0.05), GRN, NE, 0.62, -0.48, -0.66, { Anim = { Pulse = 0.6, PulseSpeed = 2 } }),
			P(H, B, V(0.5, 0.06, 0.05), BEIGE2, SP, -0.35, -0.48, -0.66),
			-- disquette sur la poitrine
			P(T, B, V(0.55, 0.55, 0.06), C(40, 60, 160), SP, -0.5, 0.45, -0.53),
			P(T, B, V(0.3, 0.17, 0.07), C(190, 195, 205), ME, -0.5, 0.62, -0.535),
			P(T, B, V(0.42, 0.2, 0.07), WHT, SP, -0.5, 0.33, -0.535),
			-- ceinture-clavier
			P(T, B, V(2.06, 0.36, 1.06), BEIGE2, SP, 0, -0.85, 0, { Text = { Text = "Q W E R T Y", Font = "Code", Color = SCR } }),
			-- tour PC dans le dos + câble
			P(T, B, V(1.0, 1.8, 0.7), BEIGE, SP, 0, 0, 0.88),
			P(T, B, V(0.6, 0.07, 0.05), SCR, SP, 0, 0.5, 1.24),
			P(T, B, V(0.1, 0.1, 0.05), GRN, NE, 0.3, -0.6, 1.24),
			P(T, CY, V(1.1, 0.12, 0.12), C(60, 60, 66), SP, 0.25, 1.15, 0.75, 0, 0, 70),
			-- souris dans la main droite
			R(RA, V(0.5, 0.32, 0.75), C(235, 230, 215), SP, 0, -1.15, -0.3),
			P(RA, B, V(0.06, 0.06, 0.9), C(200, 195, 180), SP, 0, -1.12, 0.35),
			-- transformation : fenêtre de chargement flottante
			P(T, B, V(1.4, 0.8, 0.06), C(0, 0, 160), SP, -1.75, 1.6, 0.2, { Transform = true, Anim = { Float = true, Seed = 81 }, Text = { Text = "PLEASE WAIT...", Font = "Code", Color = WHT, Face = "Both" } }),
		},
		sym(LA, RA, function(l)
			return { P(l, B, V(1.08, 0.5, 1.08), BEIGE2, SP, 0, -0.78, 0) }
		end),
		sym(LL, RL, function(l)
			return { P(l, B, V(1.08, 0.4, 1.25), C(90, 90, 100), SP, 0, -0.82, -0.1) }
		end)
	),
	Paint = {
		face(T, "Front", {
			tx(0.66, 0.3, 0.42, 0.14, "486", SCR, "Code"),
			bx(0.66, 0.42, 0.4, 0.02, GREY),
			ci(0.6, 0.55, 0.06, 0.06, C(255, 80, 80)), ci(0.68, 0.55, 0.06, 0.06, GRN), ci(0.76, 0.55, 0.06, 0.06, C(80, 140, 255)),
		}),
	},
	HitColor = GRN,
})

-- ---------- Epic : Neon Hologram ----------
local HMAG, HPUR, HCY, HDK = C(255, 60, 200), C(140, 60, 255), C(60, 230, 255), C(25, 10, 50)
local glitch = function(ang, y, col)
	return ring(T, B, V(0.3, 0.3, 0.3), col, NE, 2.0, y, ang, { Anim = { Circle = 1.6, Seed = 91, React = true } })
end
local halo = function(ang)
	return ring(H, B, V(0.42, 0.1, 0.12), HCY, NE, 0.78, 1.0, ang, { Anim = { Circle = 1, Seed = 92 } })
end
local band = function(y)
	return P(T, B, V(2.08, 0.08, 1.08), HCY, NE, 0, y, 0, { Transparency = 0.35, Anim = { Bob = 0.6, BobSpeed = 2, Seed = 93 } })
end
S({ Id = "AIAssistant_Epic", Character = "AIAssistant", Rarity = "Epic", Name = "Neon Hologram",
	Desc = "100% light, 0% physical form, 200% attitude.",
	Outfit = { Shirt = C(110, 50, 200), Pants = C(70, 30, 140) },
	HideFace = true, HideHair = true,
	Parts = join(
		{
			R(H, V(1.4, 0.62, 1.42), HMAG, NE, 0, 0.45, 0.06, { Transparency = 0.25 }), -- « cheveux » de lumière
			R(T, V(0.6, 0.6, 0.3), HCY, NE, 0, 0.35, -0.55, { Anim = { Pulse = 0.4, PulseSpeed = 4 } }),
			band(0.6), band(-0.1), band(-0.8),
			P(T, B, V(0.2, 0.2, 0.2), HMAG, SP, 0, 0, 0, { Transparency = 1, Particles = { Kind = "Spark", Color = HMAG, Rate = 6, Speed = 3, Size = 0.25, Life = 0.6, Spread = 180, React = true } }),
			-- ailes holographiques (transformation)
			P(T, B, V(1.8, 0.7, 0.06), HMAG, FF, -1.5, 0.9, 0.7, 0, 30, -20, { Transform = true, Anim = { Float = true, Seed = 94 } }),
			P(T, B, V(1.8, 0.7, 0.06), HMAG, FF, 1.5, 0.9, 0.7, 0, -30, 20, { Transform = true, Anim = { Float = true, Seed = 94 } }),
			P(T, B, V(1.5, 0.55, 0.06), HCY, FF, -1.4, 0.2, 0.8, 0, 30, -5, { Transform = true, Anim = { Float = true, Seed = 94 } }),
			P(T, B, V(1.5, 0.55, 0.06), HCY, FF, 1.4, 0.2, 0.8, 0, -30, 5, { Transform = true, Anim = { Float = true, Seed = 94 } }),
		},
		{ halo(0), halo(45), halo(90), halo(135), halo(180), halo(225), halo(270), halo(315) },
		{ glitch(0, 0.8, HMAG), glitch(60, -0.2, HCY), glitch(120, 0.5, HMAG), glitch(180, -0.6, HCY), glitch(240, 1.0, HMAG), glitch(300, 0.1, HCY) },
		sym(LA, RA, function(l, s)
			return { P(l, B, V(1.04, 2.04, 1.04), HMAG, FF, 0.12 * s, 0, 0) }
		end),
		sym(LL, RL, function(l)
			return {
				P(l, B, V(1.04, 2.04, 1.04), HCY, FF, 0, 0, 0.08),
				P(l, B, V(1.1, 0.3, 1.3), HCY, NE, 0, -0.85, -0.1),
			}
		end)
	),
	Paint = {
		face(H, "Front", {
			bx(0.5, 0.5, 1, 1, HDK),
			bx(0.33, 0.45, 0.2, 0.08, HCY, { Corner = 1 }), bx(0.67, 0.45, 0.2, 0.08, HCY, { Corner = 1 }),
			bx(0.5, 0.7, 0.22, 0.04, HMAG, { Corner = 1 }),
			bx(0.5, 0.25, 0.9, 0.02, HPUR, { Transparency = 0.4 }), bx(0.5, 0.85, 0.9, 0.02, HPUR, { Transparency = 0.4 }),
		}, true),
		face(H, "Left", { bx(0.5, 0.5, 1, 1, HDK) }, true),
		face(H, "Right", { bx(0.5, 0.5, 1, 1, HDK) }, true),
		face(H, "Back", { bx(0.5, 0.5, 1, 1, HDK) }, true),
		face(T, "Front", {
			ln(0.1, 0.15, 0.9, 0.15, HCY, 2), ln(0.1, 0.85, 0.9, 0.85, HCY, 2), ln(0.15, 0.1, 0.15, 0.9, HCY, 2), ln(0.85, 0.1, 0.85, 0.9, HCY, 2),
			tx(0.5, 0.72, 0.7, 0.12, "ONLINE", HCY, "Tech"),
		}, true),
		face(T, "Back", { tx(0.5, 0.5, 0.8, 0.16, "404: BODY NOT FOUND", HMAG, "Tech") }, true),
	},
	FX = { HandTrails = HCY },
	Highlight = { Outline = HMAG },
	HitColor = HMAG,
})

-- ---------- Legendary : Singularity Core ----------
local W3, G3, C3, D3 = C(245, 248, 252), C(255, 200, 60), C(60, 230, 255), C(30, 35, 50)
local cube = function(ang, y, col)
	return ring(T, B, V(0.35, 0.35, 0.35), col, NE, 2.4, y, ang, { Anim = { Circle = 1.2, Seed = 101, React = true } })
end
local crown = function(ang)
	return ring(H, B, V(0.42, 0.1, 0.12), G3, NE, 0.85, 1.25, ang, { Anim = { Circle = 0.8, Seed = 102 } })
end
local wing = function(s, i, col, tr)
	return P(T, B, V(1.2, 0.6, 0.06), col, NE, s * (1.2 + i * 0.5), 0.9 - i * 0.4, 0.75, 0, -25 * s, s * (20 - i * 15), { Transparency = tr or 0.35, Anim = { Float = true, Seed = 103 } })
end
S({ Id = "AIAssistant_Legendary", Character = "AIAssistant", Rarity = "Legendary", Name = "Singularity Core",
	Desc = "It read every email in the building. It knows what you did at the holiday party.",
	Outfit = { Shirt = W3, Pants = C(220, 225, 235) },
	HideFace = true, HideHair = true,
	Parts = join(
		{
			A(H, "AIAssistant_Legendary_Helmet", V(1.75, 1.75, 1.75), 0, 0.15, 0),
			P(T, CY, V(0.2, 1.2, 1.2), G3, SP, 0, 1.02, 0, 0, 0, 90, { Reflect = 0.3 }),
			R(T, V(1.9, 1.3, 0.35), W3, SP, 0, 0.35, -0.38),
			R(T, V(0.65, 0.65, 0.3), C3, NE, 0, 0.35, -0.6, { Anim = { Pulse = 0.35, PulseSpeed = 3 }, Light = C3 }),
			P(T, CY, V(0.1, 0.95, 0.95), G3, SP, 0, 0.35, -0.56, 0, 90, 0, { Reflect = 0.3 }),
			P(T, B, V(2.06, 0.22, 1.06), G3, SP, 0, -0.88, 0, { Reflect = 0.3 }),
			P(T, B, V(0.2, 0.2, 0.2), C3, SP, 0, 0.6, 0.9, { Transparency = 1, Particles = { Kind = "Sparkle", Color = C3, Rate = 8, Speed = 2, Size = 0.3, Life = 1.0, Spread = 120, Dir = "Back", React = true } }),
			wing(-1, 0, C3), wing(-1, 1, G3), wing(-1, 2, C3), wing(1, 0, C3), wing(1, 1, G3), wing(1, 2, C3),
			-- transformation : grand halo double dans le dos + ailes d'or
			P(T, CY, V(0.1, 5, 5), G3, FF, 0, 2.2, 1.4, 0, 90, 0, { Transform = true, Anim = { Spin = 30, Axis = "X" } }),
			P(T, CY, V(0.12, 3.6, 3.6), C3, FF, 0, 2.2, 1.42, 0, 90, 0, { Transform = true, Anim = { Spin = -45, Axis = "X" } }),
			P(T, B, V(2.6, 1.0, 0.06), G3, NE, -2.2, 1.6, 0.95, 0, 25, -30, { Transform = true, Anim = { Float = true, Seed = 104 } }),
			P(T, B, V(2.6, 1.0, 0.06), G3, NE, 2.2, 1.6, 0.95, 0, -25, 30, { Transform = true, Anim = { Float = true, Seed = 104 } }),
		},
		{ cube(0, 0.9, C3), cube(45, -0.3, G3), cube(90, 0.5, C3), cube(135, -0.8, G3), cube(180, 1.1, C3), cube(225, 0.1, G3), cube(270, -0.5, C3), cube(315, 0.7, G3) },
		{ crown(0), crown(36), crown(72), crown(108), crown(144), crown(180), crown(216), crown(252), crown(288), crown(324) },
		sym(LA, RA, function(l, s)
			return {
				R(l, V(1.25, 0.6, 1.25), G3, SP, 0.1 * s, 0.85, 0, { Reflect = 0.3 }),
				P(l, B, V(1.1, 0.9, 1.1), W3, SP, 0, -0.5, 0),
				P(l, B, V(1.12, 0.08, 1.12), C3, NE, 0, -0.3, 0),
			}
		end),
		sym(LL, RL, function(l)
			return {
				P(l, B, V(1.08, 0.8, 1.12), W3, SP, 0, -0.55, -0.02),
				R(l, V(0.6, 0.42, 0.3), G3, SP, 0, 0.1, -0.55, { Reflect = 0.3 }),
				P(l, B, V(1.1, 0.08, 1.2), C3, NE, 0, -0.98, 0),
			}
		end)
	),
	Paint = {
		face(T, "Front", {
			ln(0.18, 0.72, 0.82, 0.72, D3, 3), ln(0.5, 0.72, 0.5, 0.95, D3, 3),
			ln(0.25, 0.82, 0.4, 0.82, C3, 2), ln(0.6, 0.82, 0.75, 0.82, C3, 2),
			tx(0.5, 0.92, 0.5, 0.07, "CORE v9.0", G3, "Tech"),
		}),
		face(T, "Back", {
			ln(0.5, 0.05, 0.5, 0.95, D3, 3), ln(0.2, 0.5, 0.8, 0.5, D3, 3),
			tx(0.5, 0.75, 0.8, 0.1, "SINGULARITY", G3, "Tech"),
		}),
	},
	FX = { PowerAura = C3, Spotlight = C(220, 250, 255) },
	Highlight = { Outline = G3 },
	HitColor = C3,
})

return L
