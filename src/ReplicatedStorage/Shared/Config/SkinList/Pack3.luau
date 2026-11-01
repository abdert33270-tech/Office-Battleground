--[[
	SkinList.Pack3 — skins v3 de Barista, DeliveryGuy, Receptionist, FitnessCoach (Rare / Epic / Legendary).
	Chaque entrée REMPLACE celle de même Id dans SkinList (agrégateur). Format : CONTRACT_SKINS + options
	avancées de Modules/SkinBuilder (Anim, Text, Transform, Particles, Mesh, Asset, Paint, HideFace, HideHair...).
	Repères R6 : tête 2x1x1 (visuel ~1,25, dessus ~+0,62, visage en -Z), buste 2x2x1 (avant -Z),
	membres 1x2x1 (main à y -1). Droite du perso = +X. Paint : Pos/Size en 0..1 (x vers la droite de
	l'observateur, y vers le bas), donc sur la face Front, x = 0 correspond au côté +X du perso.
]]
local C, V = Color3.fromRGB, Vector3.new
local rad = math.rad
local SP, NE, GL, ME, FA, FO, WO, FF = "SmoothPlastic", "Neon", "Glass", "Metal", "Fabric", "Foil", "Wood", "ForceField"
local H, T, LA, RA, LL, RL = "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"
local B, BA, CY, WE = "Block", "Ball", "Cylinder", "Wedge"

local function merge(t, o)
	if o then
		for k, v in pairs(o) do
			t[k] = v
		end
	end
	return t
end
-- une pièce soudée à un membre (rotations en degrés) ; opt = options avancées
local function P(limb, shape, size, col, mat, x, y, z, rx, ry, rz, opt)
	if type(rx) == "table" then
		opt, rx = rx, nil
	end
	return merge({
		Limb = limb, Shape = shape, Size = size, Color = col, Material = mat or SP,
		Offset = CFrame.new(x or 0, y or 0, z or 0) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0)),
	}, opt)
end
-- ellipsoïde lisse (Block + SpecialMesh Sphere) : cheveux, casques, gants, chaussures arrondies
local function E(limb, size, col, mat, x, y, z, rx, ry, rz, opt)
	if type(rx) == "table" then
		opt, rx = rx, nil
	end
	local p = P(limb, B, size, col, mat, x, y, z, rx, ry, rz, opt)
	p.Mesh = p.Mesh or { Type = "Sphere" }
	return p
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
-- la même pièce sur les deux membres (s = +1 côté droit, -1 côté gauche, pour les décalages en X)
local function both(limbR, limbL, fn)
	return { fn(limbR, 1), fn(limbL, -1) }
end
-- pièce placée sur un anneau autour du membre (orbites, Anim.Circle)
local function ring(limb, shape, size, col, mat, r, y, ang, opt, face)
	local a = rad(ang)
	return P(limb, shape, size, col, mat, r * math.cos(a), y, -r * math.sin(a), 0, ang + (face or 90), 0, opt)
end

-- Paint (dessins sur les faces des membres)
local function Bx(x, y, w, h, col, o)
	return merge({ Type = "Box", Pos = { x, y }, Size = { w, h }, Color = col }, o)
end
local function Ci(x, y, w, h, col, o)
	return merge({ Type = "Circle", Pos = { x, y }, Size = { w, h }, Color = col }, o)
end
local function Tx(x, y, w, h, text, col, font, o)
	return merge({ Type = "Text", Pos = { x, y }, Size = { w, h }, Text = text, Color = col, Font = font or "Black" }, o)
end
local function Ln(x, y, w, h, col, rot, o)
	return merge({ Type = "Line", Pos = { x, y }, Size = { w, h }, Color = col, Rotation = rot or 0 }, o)
end
local function PT(limb, face, els)
	return { Limb = limb, Face = face, Elements = els }
end
-- même dessin sur les 4 côtés d'un membre (manchettes, bandes, chaussettes)
local function ring4(limb, els)
	return { PT(limb, "Front", els), PT(limb, "Back", els), PT(limb, "Left", els), PT(limb, "Right", els) }
end
local function ring4x2(els)
	return join(ring4(LA, els), ring4(RA, els))
end
local function legs4(els)
	return join(ring4(LL, els), ring4(RL, els))
end

-- visages peints (Head / Front, 0..1 sur la zone visible du visage)
local INK, WH = C(40, 28, 28), C(255, 255, 255)
local function eyes(y, col, o)
	o = o or {}
	local gap, w, h = o.gap or 0.17, o.w or 0.1, o.h or 0.15
	local t = {}
	for _, s in ipairs({ -1, 1 }) do
		local x = 0.5 + s * gap
		if o.white then
			t[#t + 1] = Ci(x, y, w * 1.6, h * 1.25, WH)
		end
		t[#t + 1] = Ci(x, y, w, h, col or INK)
		if o.pupil then
			t[#t + 1] = Ci(x, y, w * 0.5, h * 0.5, o.pupil)
		end
		t[#t + 1] = Ci(x + w * 0.2, y - h * 0.22, w * 0.38, h * 0.3, WH)
		if o.lash then
			t[#t + 1] = Ln(x + s * w * 0.55, y - h * 0.5, w * 0.55, 0.022, o.lash, s * -30)
		end
	end
	return t
end
local function brows(y, col, tilt, o)
	o = o or {}
	local gap, w, th = o.gap or 0.17, o.w or 0.16, o.th or 0.035
	return { Ln(0.5 - gap, y, w, th, col, tilt or 0), Ln(0.5 + gap, y, w, th, col, -(tilt or 0)) }
end
-- sourire en 3 segments
local function smile(y, w, col, th)
	w, th = w or 0.2, th or 0.032
	return {
		Ln(0.5, y, w * 0.42, th, col),
		Ln(0.5 - w * 0.38, y - w * 0.09, w * 0.38, th, col, 28),
		Ln(0.5 + w * 0.38, y - w * 0.09, w * 0.38, th, col, -28),
	}
end
-- grand sourire avec dents
local function grin(y, w, h, o)
	o = o or {}
	return {
		Bx(0.5, y, w, h, o.mouth or C(120, 30, 40), { Corner = 0.5, Stroke = { o.line or INK, 2 } }),
		Bx(0.5, y - h * 0.1, w * 0.88, h * 0.58, WH, { Corner = 0.4 }),
	}
end
local function blush(y, col, gap)
	gap = gap or 0.27
	return { Ci(0.5 - gap, y, 0.13, 0.07, col, { Transparency = 0.45 }), Ci(0.5 + gap, y, 0.13, 0.07, col, { Transparency = 0.45 }) }
end
local function faceP(els)
	return PT(H, "Front", els)
end

-- chaussures arrondies : tige + bout arrondi + semelle (6 pièces)
local function shoes(col, sole, toe, opt, soleMat)
	local t = {}
	for _, l in ipairs({ RL, LL }) do
		t[#t + 1] = P(l, B, V(1.06, 0.36, 1.06), col, SP, 0, -0.83, 0.02)
		t[#t + 1] = E(l, V(1.04, 0.38, 0.62), toe or col, SP, 0, -0.84, -0.46)
		t[#t + 1] = P(l, B, V(1.1, 0.12, 1.32), sole, soleMat or SP, 0, -0.98, -0.12, opt)
	end
	return t
end

local L = {}
local function S(def)
	def.HideIdentity = def.HideIdentity ~= false
	L[#L + 1] = def
end

-- ===================== BARISTA =====================
local CREAM, KNIT, MOCHA, CARAMEL = C(240, 230, 212), C(222, 207, 182), C(92, 66, 50), C(196, 134, 72)
local FOAM, BEAN, ESP, AMBER = C(250, 244, 232), C(105, 62, 34), C(58, 38, 28), C(255, 165, 60)
local CHEST, MUST, MUST2 = C(112, 62, 38), C(214, 158, 58), C(170, 70, 50)

S({ Id = "Barista_Rare", Character = "Barista", Rarity = "Rare", Name = "Latte Art Influencer",
	Desc = "Posts the foam. Never drinks it. 12K likes on a heart.",
	Outfit = { Shirt = CREAM, Pants = MOCHA },
	HideHair = true, HideFace = true,
	Parts = join({
		-- béret incliné + cheveux longs ondulés
		E(H, V(1.56, 0.36, 1.5), C(32, 28, 32), FA, 0.1, 0.68, 0.04, 0, 0, -9),
		P(H, BA, V(0.15, 0.15, 0.15), C(32, 28, 32), FA, 0.16, 0.86, 0.04),
		E(H, V(1.38, 0.74, 1.38), CHEST, SP, 0, 0.36, 0.06),
		E(H, V(1.34, 1.5, 0.5), CHEST, SP, 0, -0.18, 0.42),
		E(H, V(0.34, 1.05, 0.5), CHEST, SP, 0.6, -0.16, -0.02, 0, 0, 6),
		E(H, V(0.34, 1.05, 0.5), CHEST, SP, -0.6, -0.16, -0.02, 0, 0, -6),
		E(H, V(1.0, 0.26, 0.34), CHEST, SP, -0.14, 0.43, -0.5, 0, 0, -12),
		-- écharpe moutarde à carreaux
		E(T, V(1.56, 0.42, 1.18), MUST, FA, 0, 1.02, 0),
		P(T, B, V(0.44, 1.05, 0.12), MUST, FA, 0.42, 0.36, -0.57, 0, 0, -5),
		P(T, B, V(0.46, 0.06, 0.13), MUST2, FA, 0.43, 0.62, -0.575, 0, 0, -5),
		P(T, B, V(0.46, 0.06, 0.13), MUST2, FA, 0.4, 0.3, -0.575, 0, 0, -5),
		P(T, B, V(0.48, 0.12, 0.14), C(235, 190, 90), FA, 0.37, -0.2, -0.58, 0, 0, -5),
		-- pantalon large (bas évasé)
		P(LL, B, V(1.14, 0.72, 1.14), MOCHA, SP, 0, -0.38, 0),
		P(RL, B, V(1.14, 0.72, 1.14), MOCHA, SP, 0, -0.38, 0),
		-- latte (main droite) : tasse, manchon, mousse + coeur
		P(RA, CY, V(0.5, 0.5, 0.5), WH, SP, 0, -1.12, -0.5, 0, 0, 90),
		P(RA, CY, V(0.22, 0.53, 0.53), CARAMEL, SP, 0, -1.14, -0.5, 0, 0, 90),
		P(RA, CY, V(0.04, 0.44, 0.44), C(205, 150, 95), SP, 0, -0.86, -0.5, 0, 0, 90, {
			Particles = { Kind = "Smoke", Color = WH, Rate = 4, Speed = 1, Size = 0.3, Life = 1.1 } }),
		P(RA, BA, V(0.13, 0.13, 0.13), FOAM, SP, -0.05, -0.845, -0.53),
		P(RA, BA, V(0.13, 0.13, 0.13), FOAM, SP, 0.05, -0.845, -0.53),
		-- téléphone (main gauche) : 12K likes
		P(LA, B, V(0.44, 0.78, 0.08), C(25, 25, 30), SP, 0, -1.18, -0.57, { Text = { Text = "♥\n12K", Color = C(255, 90, 150), Font = "Black" } }),
	}, shoes(WH, CARAMEL, WH)),
	Paint = join({
		PT(T, "Front", {
			Ln(0.12, 0.55, 0.012, 0.75, KNIT), Ln(0.24, 0.55, 0.012, 0.75, KNIT), Ln(0.6, 0.55, 0.012, 0.75, KNIT),
			Ln(0.72, 0.55, 0.012, 0.75, KNIT), Ln(0.84, 0.55, 0.012, 0.75, KNIT),
			Bx(0.5, 0.94, 1, 0.12, KNIT), Bx(0.5, 0.05, 0.5, 0.1, KNIT),
			Tx(0.72, 0.3, 0.14, 0.14, "♥", CARAMEL, "Black", { Stroke = false }),
		}),
		PT(T, "Back", {
			Ln(0.2, 0.55, 0.012, 0.75, KNIT), Ln(0.4, 0.55, 0.012, 0.75, KNIT), Ln(0.6, 0.55, 0.012, 0.75, KNIT),
			Ln(0.8, 0.55, 0.012, 0.75, KNIT), Bx(0.5, 0.94, 1, 0.12, KNIT),
		}),
		faceP(join(eyes(0.44, INK, { lash = INK, h = 0.14 }), brows(0.27, C(90, 50, 30), -6, { th = 0.025 }),
			smile(0.7, 0.16, C(170, 60, 70)), blush(0.6, C(255, 120, 130)), { Ci(0.66, 0.58, 0.025, 0.025, C(120, 70, 50)) })),
	}, ring4x2({ Bx(0.5, 0.93, 1, 0.14, KNIT), Ln(0.5, 0.93, 1, 0.01, CREAM) }),
	legs4({ Bx(0.5, 0.03, 1, 0.06, C(70, 50, 38)) }),
	{ PT(LL, "Front", { Ln(0.5, 0.3, 0.015, 0.5, C(70, 50, 38)) }), PT(RL, "Front", { Ln(0.5, 0.3, 0.015, 0.5, C(70, 50, 38)) }) }),
})

S({ Id = "Barista_Epic", Character = "Barista", Rarity = "Epic", Name = "ASMR Brewmaster",
	Desc = "*whispers* ...your espresso... is ready... *tap tap tap*",
	Outfit = { Shirt = C(214, 196, 170), Pants = C(52, 58, 76), ArmsSkin = true },
	HideHair = true, HideFace = true,
	Parts = join({
		-- cheveux + chignon, barbe, moustache
		E(H, V(1.36, 0.72, 1.36), C(60, 38, 26), SP, 0, 0.38, 0.06),
		E(H, V(0.5, 0.44, 0.5), C(60, 38, 26), SP, 0, 0.8, 0.34),
		E(H, V(1.3, 0.75, 0.5), C(60, 38, 26), SP, 0, 0.08, 0.36),
		E(H, V(1.12, 0.5, 0.42), C(60, 38, 26), SP, 0, -0.44, -0.4),
		E(H, V(0.5, 0.13, 0.14), C(60, 38, 26), SP, 0, -0.14, -0.62),
		-- casque studio
		P(H, B, V(0.84, 0.13, 0.28), FOAM, SP, 0, 0.8, 0.05),
		P(H, B, V(0.62, 0.13, 0.28), FOAM, SP, 0.58, 0.54, 0.05, 0, 0, -55),
		P(H, B, V(0.62, 0.13, 0.28), FOAM, SP, -0.58, 0.54, 0.05, 0, 0, 55),
		P(H, CY, V(0.28, 0.68, 0.68), MOCHA, SP, 0.76, 0.04, 0.05),
		P(H, CY, V(0.28, 0.68, 0.68), MOCHA, SP, -0.76, 0.04, 0.05),
		P(H, CY, V(0.05, 0.5, 0.5), AMBER, NE, 0.91, 0.04, 0.05, { Anim = { Pulse = 0.5, PulseSpeed = 1.5, Seed = 3 } }),
		P(H, CY, V(0.05, 0.5, 0.5), AMBER, NE, -0.91, 0.04, 0.05, { Anim = { Pulse = 0.5, PulseSpeed = 1.5, Seed = 3 } }),
		-- manches retroussées
		P(RA, B, V(1.06, 0.6, 1.06), C(214, 196, 170), SP, 0, 0.71, 0),
		P(LA, B, V(1.06, 0.6, 1.06), C(214, 196, 170), SP, 0, 0.71, 0),
		P(RA, B, V(1.1, 0.16, 1.1), C(190, 170, 142), SP, 0, 0.42, 0),
		P(LA, B, V(1.1, 0.16, 1.1), C(190, 170, 142), SP, 0, 0.42, 0),
		-- tablier en cuir chocolat
		P(T, B, V(1.5, 1.55, 0.06), ESP, SP, 0, -0.2, -0.535),
		P(T, B, V(1.94, 1.3, 0.06), ESP, SP, 0, -1.62, -0.545),
		P(T, B, V(0.12, 0.5, 0.06), ESP, SP, 0.56, 0.8, -0.53),
		P(T, B, V(0.12, 0.5, 0.06), ESP, SP, -0.56, 0.8, -0.53),
		P(T, B, V(1.52, 0.06, 0.07), CARAMEL, SP, 0, 0.56, -0.54),
		P(T, B, V(1.96, 0.06, 0.07), CARAMEL, SP, 0, -2.25, -0.55),
		P(T, B, V(0.85, 0.42, 0.03), C(84, 56, 40), SP, 0, -0.5, -0.575, { Text = { Text = "shhh...", Font = "Serif", Color = C(255, 236, 210) } }),
		-- espresso + soucoupe (main droite)
		P(RA, CY, V(0.05, 0.64, 0.64), WH, SP, 0, -1.2, -0.5, 0, 0, 90),
		P(RA, CY, V(0.32, 0.36, 0.36), WH, SP, 0, -1.02, -0.5, 0, 0, 90),
		P(RA, CY, V(0.03, 0.3, 0.3), CARAMEL, SP, 0, -0.86, -0.5, 0, 0, 90, {
			Particles = { Kind = "Smoke", Color = WH, Rate = 5, Speed = 1.1, Size = 0.32, Life = 1.2 } }),
		-- micro binaural duveteux (main gauche)
		P(LA, CY, V(0.55, 0.13, 0.13), C(40, 40, 46), ME, 0, -1.22, -0.45, 0, 0, 90),
		E(LA, V(0.6, 0.82, 0.6), C(196, 190, 180), FA, 0, -0.78, -0.55),
		-- ondes sonores ambrées qui dansent + texte flottant
		P(H, B, V(0.09, 0.22, 0.09), AMBER, NE, -0.36, 1.45, 0, { Anim = { Bob = 0.1, BobSpeed = 5, Seed = 1 } }),
		P(H, B, V(0.09, 0.45, 0.09), AMBER, NE, -0.12, 1.45, 0, { Anim = { Bob = 0.12, BobSpeed = 6, Seed = 2 } }),
		P(H, B, V(0.09, 0.45, 0.09), AMBER, NE, 0.12, 1.45, 0, { Anim = { Bob = 0.12, BobSpeed = 6.5, Seed = 4 } }),
		P(H, B, V(0.09, 0.22, 0.09), AMBER, NE, 0.36, 1.45, 0, { Anim = { Bob = 0.1, BobSpeed = 5.5, Seed = 5 } }),
		P(H, B, V(2.2, 0.42, 0.05), WH, SP, 0, 1.95, 0, { Transparency = 1,
			Text = { Text = "~ tap tap tap ~", Font = "Serif", Color = C(255, 228, 196), Face = "Both" }, Anim = { Float = true } }),
		-- transformation : anneau sonore autour de la tête
		P(T, CY, V(0.05, 3.6, 3.6), AMBER, NE, 0, 0.3, 0, 0, 0, 90, { Transform = true, Transparency = 0.55,
			Anim = { Pulse = 0.35, PulseSpeed = 3, Spin = 40, Axis = "X" } }),
	}, {
		P(RL, B, V(1.08, 0.55, 1.08), C(92, 58, 38), SP, 0, -0.72, 0), P(LL, B, V(1.08, 0.55, 1.08), C(92, 58, 38), SP, 0, -0.72, 0),
		E(RL, V(1.04, 0.4, 0.62), C(92, 58, 38), SP, 0, -0.84, -0.46), E(LL, V(1.04, 0.4, 0.62), C(92, 58, 38), SP, 0, -0.84, -0.46),
	}),
	Paint = join({
		PT(T, "Front", { Bx(0.5, 0.025, 0.42, 0.05, C(190, 170, 142)), Ci(0.5, 0.08, 0.04, 0.04, C(120, 90, 60)), Ci(0.5, 0.16, 0.04, 0.04, C(120, 90, 60)) }),
		PT(T, "Back", { Ln(0.22, 0.5, 0.06, 1, ESP, 12), Ln(0.78, 0.5, 0.06, 1, ESP, -12), Bx(0.5, 0.62, 1, 0.06, ESP) }),
		faceP(join(brows(0.3, C(60, 38, 26), 4, { th = 0.04 }),
			{ Ln(0.31, 0.45, 0.12, 0.03, INK, 15), Ln(0.37, 0.45, 0.06, 0.03, INK, -10), Ln(0.69, 0.45, 0.12, 0.03, INK, -15), Ln(0.63, 0.45, 0.06, 0.03, INK, 10) },
			blush(0.58, C(255, 140, 120)))),
		PT(LA, "Front", { Bx(0.5, 0.86, 1, 0.08, C(40, 40, 46)), Ci(0.5, 0.86, 0.24, 0.1, C(220, 200, 150), { Stroke = { C(40, 40, 46), 2 } }) }),
		PT(RA, "Right", { Tx(0.5, 0.6, 0.6, 0.2, "☕", C(70, 50, 40), "Black", { Stroke = false }) }),
	}, legs4({ Bx(0.5, 0.6, 1, 0.07, C(80, 96, 130)) }),
	{ PT(LL, "Front", { Ln(0.5, 0.3, 0.012, 0.6, C(80, 96, 130)) }), PT(RL, "Front", { Ln(0.5, 0.3, 0.012, 0.6, C(80, 96, 130)) }) }),
	FX = { Orbit = { Color = BEAN, Count = 5, Shape = "Ball", Size = 0.32, Material = "SmoothPlastic", Speed = 1.2 } },
})

local ROBE, ROBE2, HAT, GOLDT = C(64, 36, 26), C(104, 60, 38), C(48, 28, 20), C(232, 172, 70)
local runes = {}
for i, a in ipairs({ 0, 90, 180, 270 }) do
	runes[#runes + 1] = ring(T, B, V(0.32, 0.06, 0.32), AMBER, NE, 1.8, -2.92, a + 45, { Anim = { Circle = -0.8, Seed = 40 } }, 0)
end
S({ Id = "Barista_Legendary", Character = "Barista", Rarity = "Legendary", Name = "Caffeine Archmage",
	Desc = "Brews forbidden potions. Mostly espresso. Foam beard of wisdom.",
	Outfit = { Shirt = ROBE, Pants = ROBE },
	HideHair = true, HideFace = true,
	Parts = join(runes, {
		-- chapeau de mage tordu
		{ Limb = H, Asset = "Barista_Legendary_Hat", Size = V(2.4, 2.4, 2.4), Offset = CFrame.new(0, 1.58, 0.05) * CFrame.Angles(rad(8), 0, rad(6)) },
		P(H, BA, V(0.28, 0.28, 0.28), C(255, 210, 130), NE, -0.12, 2.74, 0.22, { Anim = { Pulse = 0.4 }, Light = AMBER }),
		E(H, V(1.25, 1.2, 0.45), FOAM, SP, 0, -0.2, 0.42),
		-- barbe de mousse, moustache, sourcils broussailleux, mèches
		E(H, V(1.18, 0.86, 0.5), FOAM, SP, 0, -0.52, -0.42),
		E(H, V(0.86, 0.8, 0.42), FOAM, SP, 0, -1.0, -0.46),
		E(H, V(0.42, 0.55, 0.32), FOAM, SP, 0, -1.4, -0.48, 10, 0, 0),
		E(H, V(0.46, 0.2, 0.2), FOAM, SP, 0.21, -0.16, -0.64, 0, 0, 14),
		E(H, V(0.46, 0.2, 0.2), FOAM, SP, -0.21, -0.16, -0.64, 0, 0, -14),
		E(H, V(0.36, 0.13, 0.14), FOAM, SP, 0.26, 0.3, -0.61, 0, 0, -12),
		E(H, V(0.36, 0.13, 0.14), FOAM, SP, -0.26, 0.3, -0.61, 0, 0, 12),
		E(H, V(0.32, 1.1, 0.55), FOAM, SP, 0.62, -0.2, 0.12),
		E(H, V(0.32, 1.1, 0.55), FOAM, SP, -0.62, -0.2, 0.12),
		-- robe : col haut, mantelet, liserés dorés, ceinture et potions
		P(T, B, V(2.1, 0.8, 0.12), ROBE2, FA, 0, 1.25, 0.46, 14, 0, 0),
		E(T, V(2.7, 0.62, 1.45), ROBE2, FA, 0, 0.86, 0),
		E(T, V(0.32, 0.32, 0.12), AMBER, NE, 0, 0.72, -0.72),
		P(T, B, V(0.16, 1.6, 0.04), GOLDT, FO, 0.3, -0.15, -0.53),
		P(T, B, V(0.16, 1.6, 0.04), GOLDT, FO, -0.3, -0.15, -0.53),
		P(T, B, V(2.1, 0.22, 1.1), ROBE2, SP, 0, -0.78, 0),
		P(T, B, V(0.36, 0.32, 0.06), GOLDT, ME, 0, -0.78, -0.57),
		P(T, CY, V(0.36, 0.22, 0.22), C(200, 230, 255), GL, 0.62, -1.06, -0.55, 0, 0, 90, { Transparency = 0.35 }),
		P(T, CY, V(0.26, 0.16, 0.16), C(255, 120, 40), NE, 0.62, -1.09, -0.55, 0, 0, 90),
		P(T, CY, V(0.36, 0.22, 0.22), C(200, 230, 255), GL, -0.62, -1.06, -0.55, 0, 0, 90, { Transparency = 0.35 }),
		P(T, CY, V(0.26, 0.16, 0.16), C(120, 255, 200), NE, -0.62, -1.09, -0.55, 0, 0, 90),
		-- jupe de robe évasée + ourlet lumineux
		P(T, B, V(2.1, 1.2, 1.1), ROBE, FA, 0, -1.55, 0),
		P(T, B, V(2.26, 1.05, 1.26), ROBE, FA, 0, -2.45, 0),
		P(T, B, V(0.22, 1.2, 0.04), GOLDT, FO, 0, -1.55, -0.565),
		P(T, B, V(0.22, 1.05, 0.04), GOLDT, FO, 0, -2.45, -0.645),
		P(T, B, V(2.28, 0.1, 1.28), AMBER, NE, 0, -2.93, 0),
		-- manches évasées
		P(RA, B, V(1.08, 1.0, 1.08), ROBE, FA, 0, 0.5, 0),
		P(LA, B, V(1.08, 1.0, 1.08), ROBE, FA, 0, 0.5, 0),
		P(RA, B, V(1.34, 1.0, 1.34), ROBE2, FA, 0, -0.5, 0),
		P(LA, B, V(1.34, 1.0, 1.34), ROBE2, FA, 0, -0.5, 0),
		P(RA, B, V(1.36, 0.1, 1.36), AMBER, NE, 0, -1.0, 0),
		P(LA, B, V(1.36, 0.1, 1.36), AMBER, NE, 0, -1.0, 0),
		-- bâton : griffe dorée, tasse flottante et orbe
		P(RA, CY, V(4.2, 0.17, 0.17), C(100, 64, 36), WO, 0, -0.55, -0.6, 0, 0, 90),
		P(RA, CY, V(0.14, 0.26, 0.26), GOLDT, ME, 0, 1.3, -0.6, 0, 0, 90),
		P(RA, B, V(0.08, 0.55, 0.08), GOLDT, ME, 0.17, 1.62, -0.6, 0, 0, -22),
		P(RA, B, V(0.08, 0.55, 0.08), GOLDT, ME, -0.17, 1.62, -0.6, 0, 0, 22),
		P(RA, B, V(0.08, 0.55, 0.08), GOLDT, ME, 0, 1.62, -0.43, -22, 0, 0),
		P(RA, CY, V(0.46, 0.5, 0.5), FOAM, SP, 0, 2.08, -0.6, 0, 0, 90, { Anim = { Bob = 0.14, BobSpeed = 1.6, Seed = 18 } }),
		P(RA, CY, V(0.03, 0.42, 0.42), BEAN, SP, 0, 2.32, -0.6, 0, 0, 90, { Anim = { Bob = 0.14, BobSpeed = 1.6, Seed = 18 } }),
		P(RA, BA, V(0.46, 0.46, 0.46), C(255, 190, 100), NE, 0, 2.72, -0.6, { Anim = { Bob = 0.14, BobSpeed = 1.6, Seed = 18 }, Light = AMBER,
			Particles = { Kind = "Smoke", Color = C(255, 232, 200), Rate = 6, Speed = 1.4, Size = 0.42, Life = 1.2, React = true } }),
		-- cercle de runes au sol
		P(T, CY, V(0.05, 4.4, 4.4), AMBER, NE, 0, -2.97, 0, 0, 0, 90, { Transparency = 0.72, Anim = { Pulse = 0.25, React = true } }),
		P(T, CY, V(0.06, 3.0, 3.0), C(255, 210, 140), NE, 0, -2.96, 0, 0, 0, 90, { Transparency = 0.86 }),
		-- transformation : yeux brûlants + halo de runes au-dessus du chapeau
		E(H, V(0.16, 0.1, 0.06), C(255, 200, 90), NE, 0.17, 0.12, -0.63, { Transform = true }),
		E(H, V(0.16, 0.1, 0.06), C(255, 200, 90), NE, -0.17, 0.12, -0.63, { Transform = true }),
		P(H, CY, V(0.06, 1.7, 1.7), AMBER, NE, -0.12, 3.05, 0.22, 0, 0, 90, { Transform = true, Transparency = 0.35,
			Anim = { Spin = 60, Axis = "X", Bob = 0.1 },
			Particles = { Kind = "Sparkle", Color = AMBER, Rate = 12, Speed = 1, Size = 0.4, Life = 1, TransformOnly = true } }),
	}),
	Paint = {
		PT(T, "Front", { Bx(0.5, 0.55, 0.26, 0.9, ROBE2), Ci(0.5, 0.45, 0.06, 0.06, GOLDT), Ci(0.5, 0.58, 0.06, 0.06, GOLDT) }),
		faceP({ Ci(0.33, 0.45, 0.17, 0.12, WH), Ci(0.67, 0.45, 0.17, 0.12, WH), Ci(0.33, 0.45, 0.09, 0.11, C(255, 150, 40)),
			Ci(0.67, 0.45, 0.09, 0.11, C(255, 150, 40)), Ci(0.33, 0.45, 0.04, 0.06, INK), Ci(0.67, 0.45, 0.04, 0.06, INK),
			Ln(0.33, 0.37, 0.18, 0.025, C(120, 80, 60)), Ln(0.67, 0.37, 0.18, 0.025, C(120, 80, 60)) }),
	},
	FX = { PowerAura = AMBER, HandTrails = C(255, 180, 90),
		Orbit = { Color = BEAN, Count = 6, Shape = "Ball", Size = 0.36, Material = "SmoothPlastic", Speed = 1.5 } },
	Highlight = { Outline = AMBER },
	HitColor = AMBER,
})

-- ===================== DELIVERY GUY =====================
local COUR, COUR2, JOG, SILV, ORNG = C(40, 190, 110), C(24, 128, 74), C(38, 40, 48), C(225, 232, 238), C(255, 140, 40)

S({ Id = "DeliveryGuy_Rare", Character = "DeliveryGuy", Rarity = "Rare", Name = "Food Courier",
	Desc = "Your order is 2 minutes away. For the next 40 minutes.",
	Outfit = { Shirt = COUR, Pants = JOG },
	HideHair = true,
	Parts = join({
		-- casque de vélo aéré
		E(H, V(1.46, 0.86, 1.56), COUR, SP, 0, 0.42, 0.06),
		P(H, B, V(0.1, 0.08, 0.8), JOG, SP, 0.3, 0.77, 0.06),
		P(H, B, V(0.1, 0.08, 0.95), JOG, SP, 0, 0.81, 0.06),
		P(H, B, V(0.1, 0.08, 0.8), JOG, SP, -0.3, 0.77, 0.06),
		P(H, B, V(0.9, 0.05, 0.26), COUR2, SP, 0, 0.5, -0.74, -10, 0, 0),
		P(H, B, V(0.06, 0.62, 0.06), JOG, SP, 0.63, -0.08, -0.12, 0, 0, 0),
		P(H, B, V(0.06, 0.62, 0.06), JOG, SP, -0.63, -0.08, -0.12, 0, 0, 0),
		-- sac isotherme cubique
		P(T, B, V(1.75, 1.75, 1.25), COUR, SP, 0, 0.18, 1.15, { Text = { Text = "YUM!", Font = "Black", Face = "Back", Color = WH } }),
		P(T, B, V(1.79, 0.2, 1.29), C(30, 32, 38), SP, 0, 1.0, 1.15),
		P(T, B, V(1.79, 0.12, 1.29), SILV, FO, 0, -0.45, 1.15),
		P(T, B, V(0.2, 2.0, 0.06), C(30, 32, 38), SP, 0.55, 0, -0.53),
		P(T, B, V(0.2, 2.0, 0.06), C(30, 32, 38), SP, -0.55, 0, -0.53),
		P(T, B, V(1.2, 0.1, 0.07), C(30, 32, 38), SP, 0, 0.25, -0.545),
		P(T, B, V(0.22, 0.18, 0.09), ORNG, SP, 0, 0.25, -0.56),
		-- téléphone au poignet
		P(LA, B, V(0.52, 0.75, 0.08), C(25, 25, 30), SP, 0, -0.5, -0.56, { Text = { Text = "ETA\n2 MIN", Font = "Code", Color = C(80, 255, 140) } }),
		-- mitaines
		P(RA, B, V(1.06, 0.34, 1.06), C(30, 32, 38), SP, 0, -0.84, 0),
		P(LA, B, V(1.06, 0.34, 1.06), C(30, 32, 38), SP, 0, -0.84, 0),
	}, shoes(WH, COUR, WH)),
	Paint = join({
		PT(T, "Front", { Ln(0.5, 0.5, 0.025, 1, C(20, 90, 50)), Bx(0.5, 0.03, 0.55, 0.06, COUR2), Bx(0.5, 0.72, 1, 0.07, SILV),
			Bx(0.5, 0.72, 1, 0.015, ORNG), Bx(0.2, 0.86, 0.26, 0.04, COUR2), Bx(0.8, 0.86, 0.26, 0.04, COUR2) }),
		PT(T, "Back", { Bx(0.5, 0.94, 1, 0.07, SILV) }),
	}, ring4x2({ Bx(0.5, 0.42, 1, 0.07, SILV), Bx(0.5, 0.42, 1, 0.015, ORNG), Bx(0.5, 0.74, 1, 0.05, COUR2) }),
	{ PT(RL, "Right", { Bx(0.5, 0.4, 0.14, 0.8, COUR) }), PT(LL, "Left", { Bx(0.5, 0.4, 0.14, 0.8, COUR) }),
		PT(RL, "Front", { Bx(0.32, 0.3, 0.28, 0.2, C(48, 50, 60), { Corner = 0.2 }) }), PT(LL, "Front", { Bx(0.68, 0.3, 0.28, 0.2, C(48, 50, 60), { Corner = 0.2 }) }) },
	legs4({ Bx(0.5, 0.78, 1, 0.07, C(28, 30, 36)) })),
})

local RACE, STRIPE, CARB = C(215, 38, 40), C(255, 205, 40), C(30, 30, 36)
S({ Id = "DeliveryGuy_Epic", Character = "DeliveryGuy", Rarity = "Epic", Name = "Pit Stop Racer",
	Desc = "Delivered in 2.3 seconds. Changed the office chair tires too.",
	Outfit = { Shirt = RACE, Pants = RACE },
	HideHair = true, HideFace = true,
	Parts = join({
		-- casque intégral
		E(H, V(1.56, 1.46, 1.62), WH, SP, 0, 0.12, 0.05),
		E(H, V(0.34, 1.48, 1.64), RACE, SP, 0, 0.13, 0.05),
		E(H, V(1.38, 0.46, 0.4), C(20, 22, 30), GL, 0, 0.14, -0.58, { Reflect = 0.5 }),
		P(H, B, V(1.1, 0.04, 0.05), STRIPE, NE, 0, 0.38, -0.72),
		E(H, V(1.3, 0.52, 0.56), WH, SP, 0, -0.3, -0.42),
		P(H, B, V(0.9, 0.06, 0.32), CARB, SP, 0, 0.74, 0.52),
		-- collerette HANS
		P(T, B, V(1.8, 0.26, 1.2), CARB, SP, 0, 1.06, 0.05),
		-- gants + manchettes
		P(RA, B, V(1.08, 0.42, 1.08), CARB, SP, 0, -0.82, 0), P(LA, B, V(1.08, 0.42, 1.08), CARB, SP, 0, -0.82, 0),
		P(RA, B, V(1.1, 0.1, 1.1), STRIPE, SP, 0, -0.6, 0), P(LA, B, V(1.1, 0.1, 1.1), STRIPE, SP, 0, -0.6, 0),
		-- drapeau à damier (main droite)
		P(RA, CY, V(1.9, 0.08, 0.08), C(200, 200, 210), ME, 0, -0.45, -0.55, 0, 0, 90),
		P(RA, B, V(1.05, 0.72, 0.05), WH, SP, 0.56, 0.1, -0.55, { Text = { Text = "■□■□■\n□■□■□\n■□■□■", Color = C(15, 15, 20), Face = "Both", Font = "Code", Stroke = false },
			Anim = { Swing = 14, SwingAxis = "Y", SwingSpeed = 6 } }),
		-- clé à chocs (main gauche)
		P(LA, CY, V(0.62, 0.34, 0.34), STRIPE, SP, 0, -1.12, -0.5, 0, 90, 0),
		P(LA, B, V(0.2, 0.42, 0.26), CARB, SP, 0, -1.3, -0.3),
		P(LA, CY, V(0.22, 0.18, 0.18), C(190, 190, 200), ME, 0, -1.12, -0.88, 0, 90, 0),
		-- aileron arrière
		P(T, B, V(2.4, 0.1, 0.56), CARB, SP, 0, 1.18, 1.05),
		P(T, B, V(2.42, 0.04, 0.06), STRIPE, NE, 0, 1.24, 0.79),
		P(T, B, V(0.06, 0.46, 0.62), RACE, SP, 1.21, 1.1, 1.05),
		P(T, B, V(0.06, 0.46, 0.62), RACE, SP, -1.21, 1.1, 1.05),
		P(T, B, V(0.1, 0.55, 0.1), CARB, SP, 0.5, 0.86, 0.82),
		P(T, B, V(0.1, 0.55, 0.1), CARB, SP, -0.5, 0.86, 0.82),
		-- transformation : réacteurs sous l'aileron
		P(T, CY, V(0.5, 0.3, 0.3), C(255, 120, 40), NE, 0.35, 0.55, 0.8, 0, 90, 0, { Transform = true,
			Particles = { Kind = "Fire", Color = C(255, 150, 50), Rate = 25, Dir = "Back", Speed = 4, Size = 0.5, Life = 0.4, TransformOnly = true } }),
		P(T, CY, V(0.5, 0.3, 0.3), C(255, 120, 40), NE, -0.35, 0.55, 0.8, 0, 90, 0, { Transform = true,
			Particles = { Kind = "Fire", Color = C(255, 150, 50), Rate = 25, Dir = "Back", Speed = 4, Size = 0.5, Life = 0.4, TransformOnly = true } }),
		-- bottines de course
		P(RL, B, V(1.08, 0.55, 1.08), CARB, SP, 0, -0.72, 0), P(LL, B, V(1.08, 0.55, 1.08), CARB, SP, 0, -0.72, 0),
		E(RL, V(1.04, 0.4, 0.62), CARB, SP, 0, -0.84, -0.46), E(LL, V(1.04, 0.4, 0.62), CARB, SP, 0, -0.84, -0.46),
		P(RL, B, V(1.1, 0.1, 1.32), STRIPE, NE, 0, -0.98, -0.12, { Trail = { Color = STRIPE, Width = 0.35 } }),
		P(LL, B, V(1.1, 0.1, 1.32), STRIPE, NE, 0, -0.98, -0.12, { Trail = { Color = STRIPE, Width = 0.35 } }),
	}),
	Paint = join({
		PT(T, "Front", { Bx(0.08, 0.5, 0.16, 1, WH), Bx(0.92, 0.5, 0.16, 1, WH), Bx(0.18, 0.5, 0.03, 1, STRIPE), Bx(0.82, 0.5, 0.03, 1, STRIPE),
			Ln(0.5, 0.5, 0.02, 0.9, C(150, 20, 25)),
			Bx(0.32, 0.26, 0.34, 0.13, WH, { Corner = 0.3 }), Tx(0.32, 0.26, 0.3, 0.11, "TURBO", RACE, "Black"),
			Bx(0.68, 0.26, 0.3, 0.13, CARB, { Corner = 0.3 }), Tx(0.68, 0.26, 0.26, 0.11, "NITRO", STRIPE, "Black"),
			Bx(0.5, 0.56, 0.44, 0.12, STRIPE, { Corner = 0.3 }), Tx(0.5, 0.56, 0.4, 0.1, "ZOOM CO.", CARB, "Black"),
			Bx(0.5, 0.92, 1, 0.08, CARB) }),
		PT(T, "Back", { Ci(0.5, 0.52, 0.5, 0.5, WH, { Stroke = { STRIPE, 6 } }), Tx(0.5, 0.52, 0.4, 0.32, "07", RACE, "Black"),
			Tx(0.5, 0.86, 0.6, 0.1, "PIT CREW", WH, "Black"), Bx(0.5, 0.95, 1, 0.06, CARB) }),
		PT(RA, "Right", { Bx(0.5, 0.45, 0.32, 0.9, WH), Bx(0.5, 0.45, 0.08, 0.9, STRIPE) }),
		PT(LA, "Left", { Bx(0.5, 0.45, 0.32, 0.9, WH), Bx(0.5, 0.45, 0.08, 0.9, STRIPE) }),
		PT(RA, "Front", { Bx(0.5, 0.18, 0.6, 0.12, WH, { Corner = 0.3 }), Tx(0.5, 0.18, 0.5, 0.1, "07", RACE, "Black") }),
		PT(LA, "Front", { Bx(0.5, 0.18, 0.6, 0.12, STRIPE, { Corner = 0.3 }), Tx(0.5, 0.18, 0.5, 0.08, "GO!", CARB, "Black") }),
		PT(RL, "Right", { Bx(0.5, 0.4, 0.3, 0.8, WH), Bx(0.5, 0.4, 0.07, 0.8, STRIPE) }),
		PT(LL, "Left", { Bx(0.5, 0.4, 0.3, 0.8, WH), Bx(0.5, 0.4, 0.07, 0.8, STRIPE) }),
		PT(RL, "Front", { Bx(0.5, 0.42, 0.8, 0.16, WH, { Corner = 0.4 }) }),
		PT(LL, "Front", { Bx(0.5, 0.42, 0.8, 0.16, WH, { Corner = 0.4 }) }),
	}),
	FX = { HandTrails = STRIPE },
})

local CRIM, GOLD, CASH, VELV = C(185, 20, 45), C(255, 200, 40), C(110, 200, 100), C(120, 20, 40)
local bills = {}
for i, a in ipairs({ 0, 90, 180, 270 }) do
	bills[#bills + 1] = ring(T, B, V(0.9, 0.05, 0.45), CASH, SP, 2.4, i % 2 == 0 and 0.8 or 0.2, a,
		{ Anim = { Circle = 1.6, Bob = 0.3, Seed = 19 }, Text = { Text = "$", Face = "Top", Color = C(30, 90, 40), Stroke = false } }, 0)
end
local crown = {}
for i = 0, 5 do
	local a = rad(i * 60)
	crown[#crown + 1] = P(H, B, V(0.22, 0.42, 0.22), GOLD, ME, 0.6 * math.sin(a), 1.08, -0.6 * math.cos(a), 0, i * 60 + 45, 0)
	crown[#crown + 1] = P(H, BA, V(0.17, 0.17, 0.17), i % 2 == 0 and C(255, 60, 80) or C(80, 160, 255), NE, 0.6 * math.sin(a), 1.33, -0.6 * math.cos(a))
end
S({ Id = "DeliveryGuy_Legendary", Character = "DeliveryGuy", Rarity = "Legendary", Name = "Giveaway King",
	Desc = "EVERYONE GETS A PACKAGE!!! Smash subscribe for a chance to win a stapler!",
	Outfit = { Shirt = CRIM, Pants = C(28, 26, 32) },
	HideHair = true, HideFace = true,
	Parts = join(bills, crown, {
		-- couronne : bandeau, coiffe de velours, gemme
		P(H, CY, V(0.4, 1.36, 1.36), GOLD, ME, 0, 0.82, 0, 0, 0, 90),
		E(H, V(1.18, 0.62, 1.18), VELV, FA, 0, 1.0, 0),
		E(H, V(0.3, 0.3, 0.12), CASH, NE, 0, 0.82, -0.7, { Anim = { Pulse = 0.3 } }),
		E(H, V(1.38, 0.66, 1.38), C(40, 28, 22), SP, 0, 0.34, 0.08),
		-- lunettes dorées
		E(H, V(0.46, 0.3, 0.08), C(25, 25, 35), GL, 0.26, 0.12, -0.62, { Reflect = 0.4 }),
		E(H, V(0.46, 0.3, 0.08), C(25, 25, 35), GL, -0.26, 0.12, -0.62, { Reflect = 0.4 }),
		P(H, B, V(1.28, 0.06, 0.06), GOLD, ME, 0, 0.26, -0.63),
		-- veste ouverte : liserés, col relevé, épaulettes
		P(T, B, V(0.1, 2.0, 0.04), GOLD, FO, 0.42, 0, -0.52),
		P(T, B, V(0.1, 2.0, 0.04), GOLD, FO, -0.42, 0, -0.52),
		P(T, B, V(1.8, 0.45, 0.12), CRIM, FA, 0, 1.15, 0.42, 15, 0, 0),
		P(T, B, V(1.82, 0.06, 0.13), GOLD, ME, 0, 1.37, 0.47, 15, 0, 0),
		E(RA, V(1.2, 0.34, 1.2), GOLD, ME, 0, 1.0, 0),
		E(LA, V(1.2, 0.34, 1.2), GOLD, ME, 0, 1.0, 0),
		-- cape royale + hermine
		P(T, B, V(2.2, 2.8, 0.1), CRIM, FA, 0, -0.5, 0.62, -6, 0, 0),
		E(T, V(2.4, 0.36, 0.55), WH, FA, 0, 0.95, 0.55),
		P(T, B, V(2.22, 0.12, 0.14), GOLD, NE, 0, -1.88, 0.77, -6, 0, 0),
		P(T, BA, V(0.1, 0.1, 0.1), C(20, 20, 25), SP, -0.6, 1.0, 0.83),
		P(T, BA, V(0.1, 0.1, 0.1), C(20, 20, 25), SP, 0, 1.08, 0.84),
		P(T, BA, V(0.1, 0.1, 0.1), C(20, 20, 25), SP, 0.6, 1.0, 0.83),
		-- chaîne « $ »
		P(T, B, V(0.1, 0.85, 0.06), GOLD, FO, -0.25, 0.55, -0.54, 0, 0, 35),
		P(T, B, V(0.1, 0.85, 0.06), GOLD, FO, 0.25, 0.55, -0.54, 0, 0, -35),
		P(T, B, V(0.5, 0.5, 0.08), GOLD, NE, 0, 0.08, -0.58, { Text = { Text = "$", Font = "Black", Color = C(90, 60, 0), Stroke = false } }),
		-- canon à billets sur l'épaule
		P(T, CY, V(1.8, 0.5, 0.5), C(30, 30, 36), ME, 1.3, 1.4, -0.2, 0, 90, 0),
		P(T, CY, V(0.14, 0.54, 0.54), GOLD, ME, 1.3, 1.4, 0.3, 0, 90, 0),
		P(T, CY, V(0.2, 0.62, 0.62), GOLD, NE, 1.3, 1.4, -1.1, 0, 90, 0, {
			Particles = { Kind = "Spark", Color = CASH, Rate = 8, Dir = "Right", Speed = 8, Size = 0.4, Life = 0.8, Accel = -10, Spread = 15, React = true } }),
		P(T, B, V(0.6, 0.4, 0.6), GOLD, ME, 1.3, 1.12, 0.1),
		-- colis cadeau (main gauche)
		P(LA, B, V(0.9, 0.9, 0.9), C(140, 60, 220), SP, 0, -1.35, -0.6),
		P(LA, B, V(0.92, 0.92, 0.2), GOLD, SP, 0, -1.35, -0.6),
		P(LA, B, V(0.2, 0.92, 0.92), GOLD, SP, 0, -1.35, -0.6),
		E(LA, V(0.38, 0.26, 0.2), GOLD, SP, 0.16, -0.82, -0.6, 0, 0, -30),
		E(LA, V(0.38, 0.26, 0.2), GOLD, SP, -0.16, -0.82, -0.6, 0, 0, 30),
		-- pancarte
		P(H, B, V(2.6, 0.62, 0.12), C(255, 228, 60), NE, 0, 2.15, 0, { Text = { Text = "FREE PACKAGES!", Font = "Black", Color = CRIM,
			Face = "Both", Blink = 2, Stroke = false }, Anim = { Float = true } }),
		-- transformation : pluie de billets
		P(H, B, V(2.4, 0.1, 2.4), GOLD, SP, 0, 2.9, 0, { Transparency = 1,
			Particles = { Kind = "Spark", Color = CASH, Rate = 28, Dir = "Bottom", Speed = 2, Size = 0.55, Life = 1.6, Accel = -4, Spread = 40, TransformOnly = true } }),
	}, shoes(GOLD, WH, GOLD, nil)),
	Paint = join({
		PT(T, "Front", { Bx(0.5, 0.5, 0.34, 1, WH), Bx(0.5, 0.95, 1, 0.07, VELV), Bx(0.15, 0.76, 0.18, 0.035, GOLD), Bx(0.85, 0.76, 0.18, 0.035, GOLD),
			Ci(0.24, 0.42, 0.04, 0.04, GOLD), Ci(0.24, 0.58, 0.04, 0.04, GOLD), Ci(0.76, 0.42, 0.04, 0.04, GOLD), Ci(0.76, 0.58, 0.04, 0.04, GOLD),
			Tx(0.5, 0.82, 0.3, 0.1, "GG", CRIM, "Black") }),
		faceP(join(brows(0.25, INK, -10, { th = 0.04 }), grin(0.68, 0.3, 0.08))),
	}, ring4x2({ Bx(0.5, 0.88, 1, 0.06, GOLD), Bx(0.5, 0.82, 1, 0.025, GOLD) }),
	{ PT(RL, "Right", { Bx(0.42, 0.4, 0.06, 0.8, GOLD), Bx(0.58, 0.4, 0.06, 0.8, GOLD) }), PT(LL, "Left", { Bx(0.42, 0.4, 0.06, 0.8, GOLD), Bx(0.58, 0.4, 0.06, 0.8, GOLD) }) }),
	FX = { PowerAura = GOLD, Sparkles = GOLD },
	Highlight = { Outline = GOLD },
	HitColor = CASH,
})

-- ===================== RECEPTIONIST =====================
local BLUSH_P, PLUM, MINT, AUB, TIGHT = C(255, 150, 200), C(96, 40, 92), C(120, 222, 192), C(150, 52, 38), C(48, 40, 52)
local coil = {}
for i = 0, 2 do
	coil[#coil + 1] = P(LA, CY, V(0.06, 0.22, 0.22), MINT, SP, -0.58, -0.45 + i * 0.32, -0.22 + i * 0.08, 0, 0, 90)
end
S({ Id = "Receptionist_Rare", Character = "Receptionist", Rarity = "Rare", Name = "Retro Phone Diva",
	Desc = "Hold, please. Forever. Your call is very important to her nails.",
	Outfit = { Shirt = BLUSH_P, Pants = TIGHT },
	HideHair = true, HideFace = true,
	Parts = join(coil, {
		-- choucroute rétro + bandeau menthe à noeud
		E(H, V(1.42, 0.82, 1.44), AUB, SP, 0, 0.36, 0.05),
		E(H, V(1.22, 1.15, 1.2), AUB, SP, 0, 0.94, 0.12),
		E(H, V(1.32, 0.8, 0.5), AUB, SP, 0, 0.05, 0.4),
		E(H, V(0.52, 0.36, 0.62), AUB, SP, 0.64, -0.26, 0.16, 0, 0, -28),
		E(H, V(0.52, 0.36, 0.62), AUB, SP, -0.64, -0.26, 0.16, 0, 0, 28),
		E(H, V(1.46, 0.14, 1.48), MINT, SP, 0, 0.56, 0.05),
		E(H, V(0.42, 0.26, 0.16), MINT, SP, 0.46, 0.66, -0.46, 0, 0, -20),
		-- lunettes oeil-de-chat roses
		E(H, V(0.48, 0.3, 0.08), C(255, 110, 180), GL, 0.26, 0.12, -0.62, { Transparency = 0.15 }),
		E(H, V(0.48, 0.3, 0.08), C(255, 110, 180), GL, -0.26, 0.12, -0.62, { Transparency = 0.15 }),
		P(H, B, V(1.34, 0.07, 0.07), WH, SP, 0, 0.27, -0.63),
		-- col Claudine
		E(T, V(0.75, 0.13, 0.52), WH, SP, 0.36, 0.97, -0.28, 0, 0, -8),
		E(T, V(0.75, 0.13, 0.52), WH, SP, -0.36, 0.97, -0.28, 0, 0, 8),
		-- jupe crayon prune + ceinture dorée
		P(T, B, V(2.06, 1.3, 1.08), PLUM, FA, 0, -1.6, 0),
		P(T, B, V(2.08, 0.13, 1.1), C(240, 190, 80), ME, 0, -0.98, 0),
		-- combiné rétro à l'oreille + téléphone à cadran dans la main
		P(H, B, V(0.18, 0.92, 0.22), MINT, SP, -0.74, -0.08, -0.14, 18, 0, 0),
		E(H, V(0.3, 0.3, 0.34), MINT, SP, -0.74, 0.32, -0.02),
		E(H, V(0.3, 0.3, 0.34), MINT, SP, -0.72, -0.46, -0.3),
		{ Limb = LA, Asset = "Receptionist_Rare_Phone", Size = V(0.95, 0.8, 0.8), Offset = CFrame.new(0, -1.35, -0.55) },
		-- escarpins
		P(RL, B, V(1.02, 0.28, 1.0), BLUSH_P, SP, 0, -0.87, -0.06), P(LL, B, V(1.02, 0.28, 1.0), BLUSH_P, SP, 0, -0.87, -0.06),
		P(RL, B, V(0.22, 0.32, 0.22), BLUSH_P, SP, 0, -0.9, 0.36), P(LL, B, V(0.22, 0.32, 0.22), BLUSH_P, SP, 0, -0.9, 0.36),
	}),
	Paint = join({
		PT(T, "Front", { Ci(0.5, 0.2, 0.045, 0.045, WH), Ci(0.5, 0.35, 0.045, 0.045, WH), Ci(0.5, 0.5, 0.045, 0.045, WH), Ci(0.5, 0.65, 0.045, 0.045, WH),
			Ci(0.32, 0.11, 0.06, 0.06, C(250, 245, 235)), Ci(0.38, 0.15, 0.06, 0.06, C(250, 245, 235)), Ci(0.44, 0.17, 0.06, 0.06, C(250, 245, 235)),
			Ci(0.56, 0.17, 0.06, 0.06, C(250, 245, 235)), Ci(0.62, 0.15, 0.06, 0.06, C(250, 245, 235)), Ci(0.68, 0.11, 0.06, 0.06, C(250, 245, 235)) }),
		faceP(join(brows(0.25, AUB, -8, { th = 0.03 }), { Ci(0.5, 0.69, 0.15, 0.08, C(210, 30, 60)), Ci(0.5, 0.68, 0.07, 0.025, C(255, 120, 140)),
			Ci(0.67, 0.6, 0.025, 0.025, C(70, 40, 40)) }, blush(0.56, C(255, 110, 140)))),
		PT(RL, "Back", { Ln(0.5, 0.6, 0.02, 0.8, C(20, 15, 20)) }), PT(LL, "Back", { Ln(0.5, 0.6, 0.02, 0.8, C(20, 15, 20)) }),
	}, ring4x2({ Bx(0.5, 0.88, 1, 0.24, WH), Bx(0.5, 0.75, 1, 0.03, C(230, 230, 235)) }),
	{ PT(RA, "Front", { Bx(0.2, 0.985, 0.12, 0.03, C(220, 30, 70)), Bx(0.4, 0.985, 0.12, 0.03, C(220, 30, 70)), Bx(0.6, 0.985, 0.12, 0.03, C(220, 30, 70)), Bx(0.8, 0.985, 0.12, 0.03, C(220, 30, 70)) }) }),
})

local NAVY, NAVY2, BLOND, NRED = C(28, 48, 110), C(18, 32, 80), C(236, 200, 120), C(205, 30, 40)
S({ Id = "Receptionist_Epic", Character = "Receptionist", Rarity = "Epic", Name = "Breaking News Anchor",
	Desc = "Good evening. Tonight: the printer is on fire. More at eleven.",
	Outfit = { Shirt = NAVY, Pants = C(30, 34, 52), ArmsSkin = true },
	HideHair = true, HideFace = true,
	Parts = {
		-- coiffure « casque » laquée
		E(H, V(1.42, 0.86, 1.46), BLOND, SP, 0, 0.38, 0.05),
		E(H, V(0.95, 0.36, 0.55), BLOND, SP, 0.14, 0.6, -0.38, 0, 0, -10),
		E(H, V(1.34, 0.8, 0.5), BLOND, SP, 0, 0.08, 0.4),
		E(H, V(0.3, 0.62, 0.72), BLOND, SP, 0.63, 0.04, 0.1),
		E(H, V(0.3, 0.62, 0.72), BLOND, SP, -0.63, 0.04, 0.1),
		-- oreillette + fil
		P(H, BA, V(0.16, 0.16, 0.16), C(225, 215, 200), SP, -0.66, 0, -0.02),
		P(H, B, V(0.04, 0.6, 0.04), C(225, 215, 200), SP, -0.6, -0.36, 0.1, 0, 0, 8),
		-- veste : manches longues (mains libres), épaulettes, basque, pochette
		P(RA, B, V(1.05, 1.66, 1.05), NAVY, SP, 0, 0.17, 0), P(LA, B, V(1.05, 1.66, 1.05), NAVY, SP, 0, 0.17, 0),
		P(RA, B, V(1.07, 0.08, 1.07), WH, SP, 0, -0.62, 0), P(LA, B, V(1.07, 0.08, 1.07), WH, SP, 0, -0.62, 0),
		P(RA, B, V(1.12, 0.2, 1.12), NAVY, SP, 0, 0.94, 0), P(LA, B, V(1.12, 0.2, 1.12), NAVY, SP, 0, 0.94, 0),
		P(T, B, V(2.08, 0.34, 1.1), NAVY, SP, 0, -0.9, 0),
		P(T, B, V(0.26, 0.12, 0.04), WH, SP, -0.55, 0.42, -0.53),
		-- micro « NEWS 7 » (main droite)
		P(RA, CY, V(0.7, 0.14, 0.14), C(25, 25, 30), SP, 0, -1.15, -0.5, 0, 0, 90),
		P(RA, B, V(0.36, 0.3, 0.36), NRED, SP, 0, -0.92, -0.5, { Text = { Text = "7", Font = "Black", Color = WH, Stroke = false } }),
		E(RA, V(0.3, 0.3, 0.3), C(70, 70, 80), ME, 0, -0.7, -0.5),
		-- feuilles du script (main gauche)
		P(LA, B, V(0.08, 0.8, 0.62), WH, SP, 0, -1.2, -0.4, { Text = { Text = "NEWS\n—\n—", Font = "Black", Color = C(40, 40, 50), Face = "Left", Stroke = false } }),
		-- bloc LIVE + bandeau défilant
		P(H, B, V(0.95, 0.42, 0.1), NRED, NE, -1.35, 1.35, 0, { Text = { Text = "● LIVE", Face = "Both", Blink = 1.2, Font = "Black", Stroke = false }, Anim = { Float = true } }),
		P(H, B, V(1.1, 0.4, 0.09), NRED, SP, -1.25, 2.1, 0.3, { Text = { Text = "BREAKING", Face = "Both", Font = "Black", Stroke = false } }),
		P(H, B, V(2.6, 0.36, 0.08), WH, SP, 0.6, 2.1, 0.3, { Text = { Text = "PRINTER ON FIRE... COFFEE MACHINE MISSING... MORE AT 11...",
			Face = "Both", Scroll = 0.25, Width = 4, Color = NAVY2, Font = "Black", Stroke = false } }),
		P(H, B, V(3.72, 0.05, 0.09), C(255, 200, 40), NE, 0.05, 1.89, 0.3),
		-- souliers vernis
		P(RL, B, V(1.06, 0.34, 1.06), C(20, 20, 24), SP, 0, -0.84, 0.02, { Reflect = 0.2 }), P(LL, B, V(1.06, 0.34, 1.06), C(20, 20, 24), SP, 0, -0.84, 0.02, { Reflect = 0.2 }),
		E(RL, V(1.04, 0.36, 0.6), C(20, 20, 24), SP, 0, -0.85, -0.46, { Reflect = 0.2 }), E(LL, V(1.04, 0.36, 0.6), C(20, 20, 24), SP, 0, -0.85, -0.46, { Reflect = 0.2 }),
		-- transformation : drone caméra en orbite + bannière
		P(T, B, V(0.6, 0.45, 0.7), C(40, 40, 48), ME, 2.4, 1.6, 0, { Transform = true, Anim = { Circle = 1.1, Bob = 0.2, Seed = 77 } }),
		P(T, CY, V(0.3, 0.3, 0.3), C(20, 20, 25), GL, 2.4, 1.6, -0.45, 0, 90, 0, { Transform = true, Anim = { Circle = 1.1, Bob = 0.2, Seed = 77 } }),
		P(T, BA, V(0.14, 0.14, 0.14), NRED, NE, 2.4, 1.88, 0, { Transform = true, Anim = { Circle = 1.1, Bob = 0.2, Seed = 77, Pulse = 0.6 } }),
		P(H, B, V(3.2, 0.7, 0.1), NRED, NE, 0, 2.85, 0.3, { Transform = true, Text = { Text = "BREAKING NEWS", Face = "Both", Font = "Black", Blink = 2, Stroke = false } }),
	},
	Paint = join({
		PT(T, "Front", { Bx(0.5, 0.22, 0.32, 0.44, WH), Bx(0.36, 0.3, 0.12, 0.6, NAVY2, { Rotation = -18 }), Bx(0.64, 0.3, 0.12, 0.6, NAVY2, { Rotation = 18 }),
			Bx(0.5, 0.06, 0.1, 0.07, C(150, 20, 28)), Bx(0.5, 0.27, 0.07, 0.36, NRED), Ci(0.5, 0.64, 0.045, 0.045, C(240, 200, 90)),
			Ci(0.5, 0.78, 0.045, 0.045, C(240, 200, 90)), Bx(0.24, 0.8, 0.24, 0.035, NAVY2), Bx(0.76, 0.8, 0.24, 0.035, NAVY2),
			Ci(0.75, 0.3, 0.09, 0.09, C(240, 200, 90), { Stroke = { NAVY2, 2 } }), Tx(0.75, 0.3, 0.06, 0.07, "7", NAVY2, "Black", { Stroke = false }) }),
		PT(T, "Back", { Ln(0.5, 0.6, 0.015, 0.8, NAVY2) }),
		faceP(join(eyes(0.43, INK, { h = 0.13, w = 0.09 }), brows(0.29, C(150, 110, 60), -10, { th = 0.035 }), grin(0.69, 0.26, 0.075))),
	}, { PT(RL, "Front", { Ln(0.5, 0.45, 0.012, 0.85, C(22, 26, 40)) }), PT(LL, "Front", { Ln(0.5, 0.45, 0.012, 0.85, C(22, 26, 40)) }) }),
	FX = { Spotlight = WH },
})

local PLAT, POP, CYAN, SILVR, PURP = C(250, 240, 205), C(255, 70, 190), C(40, 230, 255), C(222, 222, 238), C(120, 40, 170)
local sticks = {}
for i, a in ipairs({ 0, 90, 180, 270 }) do
	local col = i % 2 == 0 and CYAN or POP
	sticks[#sticks + 1] = ring(T, CY, V(0.75, 0.13, 0.13), col, NE, 2.3, i % 2 == 0 and 0.9 or 0.3, a,
		{ Anim = { Circle = 1.4, Bob = 0.25, Seed = 60 } }, 0)
	sticks[#sticks].Offset = sticks[#sticks].Offset * CFrame.Angles(0, 0, rad(90))
end
local function wing(s, i)
	local col = i == 1 and POP or (i == 2 and C(200, 120, 255) or CYAN)
	return P(T, B, V(1.5 - i * 0.25, 0.32, 0.06), col, NE, s * (0.9 + i * 0.35), 0.9 - i * 0.35, 0.65, 0, s * -15, s * (30 - i * 18),
		{ Transform = true, Transparency = 0.2, Anim = { Swing = 8, SwingAxis = "Y", SwingSpeed = 3, Seed = 50 + i } })
end
S({ Id = "Receptionist_Legendary", Character = "Receptionist", Rarity = "Legendary", Name = "Front Desk Pop Star",
	Desc = "Sold-out world tour. Still answers the phone between songs.",
	Outfit = { Shirt = POP, Pants = C(40, 30, 55) },
	HideHair = true, HideFace = true,
	Parts = join(sticks, { wing(1, 1), wing(1, 2), wing(1, 3), wing(-1, 1), wing(-1, 2), wing(-1, 3) }, {
		-- queue de cheval platine haute
		E(H, V(1.42, 0.8, 1.44), PLAT, SP, 0, 0.38, 0.06),
		E(H, V(1.2, 0.32, 0.42), PLAT, SP, -0.05, 0.5, -0.48, 0, 0, 8),
		E(H, V(0.3, 0.7, 0.6), PLAT, SP, 0.62, 0.0, 0.05),
		E(H, V(0.3, 0.7, 0.6), PLAT, SP, -0.62, 0.0, 0.05),
		E(H, V(0.38, 0.28, 0.38), POP, NE, 0, 0.84, 0.38),
		E(H, V(0.62, 0.62, 0.62), PLAT, SP, 0, 1.05, 0.48),
		E(H, V(0.56, 1.75, 0.56), PLAT, SP, 0, 0.32, 0.92, 14, 0, 0),
		E(H, V(1.3, 0.75, 0.48), PLAT, SP, 0, 0.1, 0.4),
		-- lunettes néon + micro-casque
		P(H, B, V(1.32, 0.26, 0.1), CYAN, NE, 0, 0.12, -0.62, { Transparency = 0.1 }),
		P(H, B, V(1.36, 0.05, 0.11), C(25, 25, 35), SP, 0, 0.26, -0.62),
		P(H, CY, V(0.12, 0.42, 0.42), C(30, 30, 40), SP, 0.66, 0, 0),
		P(H, B, V(0.05, 0.05, 0.58), C(30, 30, 40), SP, 0.6, -0.16, -0.36, 0, 25, 0),
		P(H, BA, V(0.14, 0.14, 0.14), POP, NE, 0.46, -0.19, -0.64),
		-- veste courte à sequins : épaules XXL, panneaux, col, liserés néon
		E(RA, V(1.26, 0.46, 1.22), SILVR, ME, 0, 0.98, 0), E(LA, V(1.26, 0.46, 1.22), SILVR, ME, 0, 0.98, 0),
		P(RA, B, V(1.06, 0.9, 1.06), SILVR, ME, 0, 0.5, 0), P(LA, B, V(1.06, 0.9, 1.06), SILVR, ME, 0, 0.5, 0),
		P(T, B, V(2.06, 1.1, 0.06), SILVR, ME, 0, 0.45, 0.53, { Text = { Text = "WORLD\nTOUR", Face = "Back", Font = "Bangers", Color = POP } }),
		P(T, B, V(0.55, 1.1, 0.06), SILVR, ME, 0.75, 0.45, -0.53), P(T, B, V(0.55, 1.1, 0.06), SILVR, ME, -0.75, 0.45, -0.53),
		P(T, B, V(0.57, 0.06, 0.08), CYAN, NE, 0.75, -0.1, -0.54), P(T, B, V(0.57, 0.06, 0.08), CYAN, NE, -0.75, -0.1, -0.54),
		P(T, B, V(2.08, 0.06, 0.08), CYAN, NE, 0, -0.1, 0.54),
		P(T, B, V(1.9, 0.4, 0.1), SILVR, ME, 0, 1.15, 0.45, 15, 0, 0),
		-- mini-jupe pailletée + tutu + ceinture néon
		P(T, B, V(2.14, 0.8, 1.14), PURP, FO, 0, -1.25, 0),
		E(T, V(2.7, 0.36, 1.6), POP, SP, 0, -1.62, 0, { Transparency = 0.15 }),
		P(T, B, V(2.18, 0.12, 1.18), CYAN, NE, 0, -0.9, 0),
		-- bottes plateformes
		P(RL, B, V(1.06, 1.0, 1.06), C(245, 245, 255), SP, 0, -0.5, 0), P(LL, B, V(1.06, 1.0, 1.06), C(245, 245, 255), SP, 0, -0.5, 0),
		E(RL, V(1.04, 0.4, 0.6), C(245, 245, 255), SP, 0, -0.84, -0.46), E(LL, V(1.04, 0.4, 0.6), C(245, 245, 255), SP, 0, -0.84, -0.46),
		P(RL, B, V(1.14, 0.22, 1.34), CYAN, NE, 0, -1.0, -0.12), P(LL, B, V(1.14, 0.22, 1.34), CYAN, NE, 0, -1.0, -0.12),
		P(RL, B, V(1.09, 0.08, 1.09), POP, NE, 0, 0.0, 0), P(LL, B, V(1.09, 0.08, 1.09), POP, NE, 0, 0.0, 0),
		-- micro doré (main droite)
		P(RA, CY, V(0.6, 0.13, 0.13), C(255, 200, 60), ME, 0, -1.15, -0.5, 0, 0, 90),
		E(RA, V(0.3, 0.3, 0.3), C(255, 230, 140), FO, 0, -0.78, -0.5, { Particles = { Kind = "Sparkle", Color = C(255, 230, 140), Rate = 4, Speed = 1, Size = 0.25, Life = 0.8 } }),
		-- notes flottantes
		P(H, B, V(0.5, 0.5, 0.05), WH, SP, -1.1, 1.3, 0, { Transparency = 1, Text = { Text = "♪", Face = "Both", Color = CYAN, Font = "Black" }, Anim = { Float = true, Seed = 1 } }),
		P(H, B, V(0.5, 0.5, 0.05), WH, SP, 1.15, 1.55, 0, { Transparency = 1, Text = { Text = "♫", Face = "Both", Color = POP, Font = "Black" }, Anim = { Float = true, Seed = 2 } }),
	}),
	Paint = join({
		PT(T, "Front", { Tx(0.5, 0.36, 0.3, 0.3, "★", WH, "Black", { Stroke = false }), Ci(0.4, 0.62, 0.03, 0.03, CYAN), Ci(0.5, 0.66, 0.03, 0.03, CYAN), Ci(0.6, 0.62, 0.03, 0.03, CYAN) }),
		faceP(join({ Ci(0.5, 0.69, 0.14, 0.08, C(255, 60, 150)), Ci(0.48, 0.67, 0.05, 0.02, WH) }, blush(0.56, C(255, 100, 180)),
			{ Tx(0.74, 0.58, 0.1, 0.1, "★", CYAN, "Black", { Stroke = false }) })),
	}),
	FX = { Spotlight = C(255, 150, 230), PowerAura = POP },
	Highlight = { Outline = POP },
	HitColor = POP,
})

-- ===================== FITNESS COACH =====================
local HOTP, TEAL, YELW, VIOL, PERM = C(255, 60, 170), C(30, 215, 210), C(255, 228, 50), C(130, 60, 220), C(250, 212, 120)
S({ Id = "FitnessCoach_Rare", Character = "FitnessCoach", Rarity = "Rare", Name = "80s Aerobics Icon",
	Desc = "Feel the burn! And the deadline! Five, six, seven, eight!",
	Outfit = { Shirt = HOTP, Pants = TEAL, ArmsSkin = true },
	HideHair = true, HideFace = true,
	Parts = join({
		-- permanente XXL
		E(H, V(1.52, 0.92, 1.52), PERM, SP, 0, 0.42, 0.08),
		E(H, V(0.62, 0.86, 0.86), PERM, SP, 0.66, 0.08, 0.16),
		E(H, V(0.62, 0.86, 0.86), PERM, SP, -0.66, 0.08, 0.16),
		E(H, V(1.46, 1.05, 0.66), PERM, SP, 0, -0.02, 0.52),
		E(H, V(0.95, 0.62, 0.95), PERM, SP, 0.1, 0.84, 0.06),
		-- bandeau éponge rayé
		P(H, CY, V(0.24, 1.36, 1.36), VIOL, FA, 0, 0.36, 0, 0, 0, 90),
		P(H, CY, V(0.07, 1.38, 1.38), TEAL, SP, 0, 0.36, 0, 0, 0, 90),
		-- poignets éponge
		P(RA, B, V(1.1, 0.3, 1.1), YELW, FA, 0, -0.62, 0), P(LA, B, V(1.1, 0.3, 1.1), YELW, FA, 0, -0.62, 0),
		-- ceinture brillante + walkman
		P(T, B, V(2.08, 0.14, 1.08), VIOL, FO, 0, -0.86, 0),
		P(T, B, V(0.4, 0.5, 0.16), C(60, 60, 72), SP, 0.62, -0.78, -0.6),
		P(T, B, V(0.3, 0.12, 0.05), C(255, 140, 40), SP, 0.62, -0.64, -0.69),
		E(T, V(0.32, 0.32, 0.16), C(255, 140, 40), FA, 0.48, 0.95, -0.42),
		E(T, V(0.32, 0.32, 0.16), C(255, 140, 40), FA, -0.48, 0.95, -0.42),
		-- jambières molles
		P(RL, B, V(1.16, 0.72, 1.16), YELW, FA, 0, -0.5, 0), P(LL, B, V(1.16, 0.72, 1.16), YELW, FA, 0, -0.5, 0),
		E(RL, V(1.22, 0.26, 1.22), YELW, FA, 0, -0.12, 0), E(LL, V(1.22, 0.26, 1.22), YELW, FA, 0, -0.12, 0),
	}, shoes(WH, HOTP, WH)),
	Paint = join({
		PT(T, "Front", { Bx(0.5, 0.46, 1, 0.12, TEAL), Bx(0.5, 0.58, 1, 0.05, YELW), Bx(0.5, 0.66, 1, 0.05, VIOL),
			Tx(0.5, 0.22, 0.6, 0.14, "FEEL IT!", WH, "Bangers"), Bx(0.5, 0.03, 0.5, 0.06, C(220, 40, 140)) }),
		PT(T, "Back", { Bx(0.5, 0.46, 1, 0.12, TEAL), Bx(0.5, 0.58, 1, 0.05, YELW), Bx(0.5, 0.66, 1, 0.05, VIOL) }),
		faceP(join(eyes(0.44, INK, { lash = INK, h = 0.14 }), { Ci(0.33, 0.36, 0.17, 0.07, C(60, 160, 255), { Transparency = 0.25 }),
			Ci(0.67, 0.36, 0.17, 0.07, C(60, 160, 255), { Transparency = 0.25 }) }, brows(0.27, C(170, 120, 50), -6, { th = 0.025 }),
			grin(0.69, 0.22, 0.07, { mouth = C(200, 40, 90) }), blush(0.58, HOTP))),
	}, legs4({ Bx(0.5, 0.06, 1, 0.12, HOTP) }),
	{ PT(RL, "Front", { Ln(0.5, 0.5, 0.012, 0.9, C(20, 170, 165)) }), PT(LL, "Front", { Ln(0.5, 0.5, 0.012, 0.9, C(20, 170, 165)) }) }),
})

local TANK, NEONG, GREYJ = C(30, 30, 36), C(130, 255, 60), C(72, 74, 88)
S({ Id = "FitnessCoach_Epic", Character = "FitnessCoach", Rarity = "Epic", Name = "Gym Influencer",
	Desc = "Do you even lift... the office morale? #GAINS #BLESSED",
	Outfit = { Shirt = TANK, Pants = GREYJ, ArmsSkin = true },
	HideHair = true, HideFace = true,
	Parts = join({
		-- casquette à l'envers
		E(H, V(1.38, 0.62, 1.38), TANK, SP, 0, 0.5, 0.03),
		P(H, B, V(0.95, 0.07, 0.6), NEONG, SP, 0, 0.47, 0.84, 6, 0, 0),
		P(H, BA, V(0.15, 0.15, 0.15), NEONG, SP, 0, 0.82, 0.03),
		P(H, B, V(0.4, 0.14, 0.04), NEONG, NE, 0, 0.46, -0.68),
		-- écouteurs sans fil
		P(H, BA, V(0.2, 0.2, 0.2), WH, SP, 0.65, 0.0, 0), P(H, BA, V(0.2, 0.2, 0.2), WH, SP, -0.65, 0.0, 0),
		E(H, V(1.28, 0.55, 0.5), C(40, 30, 25), SP, 0, 0.2, 0.38),
		-- bandes de poignets + gants de muscu
		P(RA, B, V(1.08, 0.34, 1.08), NEONG, FA, 0, -0.58, 0), P(LA, B, V(1.08, 0.34, 1.08), NEONG, FA, 0, -0.58, 0),
		P(RA, B, V(1.08, 0.28, 1.08), C(20, 20, 24), SP, 0, -0.87, 0), P(LA, B, V(1.08, 0.28, 1.08), C(20, 20, 24), SP, 0, -0.87, 0),
		-- ceinture de force
		P(T, B, V(2.1, 0.46, 1.1), C(110, 70, 40), SP, 0, -0.78, 0),
		P(T, B, V(0.46, 0.38, 0.08), C(200, 200, 210), ME, 0, -0.78, -0.58),
		-- jogger : chevilles serrées
		P(RL, B, V(1.08, 0.2, 1.08), C(40, 42, 52), SP, 0, -0.56, 0), P(LL, B, V(1.08, 0.2, 1.08), C(40, 42, 52), SP, 0, -0.56, 0),
		-- perche à selfie + téléphone REC + anneau lumineux (main droite)
		P(RA, CY, V(2.1, 0.08, 0.08), C(190, 190, 200), ME, 0, -0.25, -0.8, -35, 0, 90),
		P(RA, B, V(0.5, 0.85, 0.07), C(20, 20, 26), SP, 0, 0.72, -1.48, -15, 0, 0, { Text = { Text = "● REC", Color = C(255, 60, 60), Blink = 1.5, Font = "Black", Stroke = false } }),
		P(RA, CY, V(0.04, 1.0, 1.0), WH, NE, 0, 0.72, -1.44, -15, 90, 0, { Transparency = 0.3 }),
		-- shaker protéiné (main gauche)
		P(LA, CY, V(0.75, 0.42, 0.42), C(240, 240, 245), SP, 0, -1.2, -0.45, 0, 0, 90),
		P(LA, CY, V(0.2, 0.44, 0.44), NEONG, SP, 0, -0.78, -0.45, 0, 0, 90),
		P(LA, CY, V(0.14, 0.14, 0.14), TANK, SP, 0, -0.62, -0.45, 0, 0, 90),
		-- hologrammes
		P(H, B, V(1.9, 0.5, 0.06), WH, SP, 0, 1.75, 0, { Transparency = 1, Text = { Text = "#GAINS", Font = "Black", Color = NEONG, Face = "Both" }, Anim = { Float = true } }),
		P(H, B, V(1.0, 0.4, 0.06), WH, SP, -1.3, 1.25, 0, { Transparency = 1, Text = { Text = "♥ 50K", Font = "Black", Color = C(255, 80, 120), Face = "Both" }, Anim = { Float = true, Seed = 3 } }),
		-- transformation : haltère géant qui tourne + « PR! »
		P(H, CY, V(1.8, 0.14, 0.14), C(190, 190, 200), ME, 0, 2.55, 0, { Transform = true, Anim = { Spin = 90, Axis = "Y", Seed = 9 } }),
		P(H, CY, V(0.25, 0.8, 0.8), TANK, SP, 0.8, 2.55, 0, { Transform = true, Anim = { Spin = 90, Axis = "Y", Seed = 9 } }),
		P(H, CY, V(0.25, 0.8, 0.8), TANK, SP, -0.8, 2.55, 0, { Transform = true, Anim = { Spin = 90, Axis = "Y", Seed = 9 } }),
		P(H, B, V(1.2, 0.6, 0.06), WH, SP, 1.4, 1.9, 0, { Transform = true, Transparency = 1, Text = { Text = "PR!", Font = "Bangers", Color = NEONG, Face = "Both", Blink = 3 } }),
	}, shoes(C(245, 245, 250), NEONG, C(245, 245, 250), nil, NE)),
	Paint = join({
		PT(T, "Front", { Tx(0.5, 0.32, 0.7, 0.18, "SWOLE", NEONG, "Black"), Bx(0.5, 0.48, 0.3, 0.04, NEONG), Bx(0.32, 0.48, 0.05, 0.1, NEONG), Bx(0.68, 0.48, 0.05, 0.1, NEONG),
			Ln(0.38, 0.05, 0.22, 0.04, C(255, 200, 60), 25), Ln(0.62, 0.05, 0.22, 0.04, C(255, 200, 60), -25), Ci(0.5, 0.12, 0.06, 0.06, C(255, 200, 60)) }),
		PT(T, "Back", { Tx(0.5, 0.35, 0.8, 0.2, "#GAINS", NEONG, "Black"), Tx(0.5, 0.55, 0.6, 0.1, "COACH", WH, "Black") }),
		PT(RA, "Right", { Ln(0.5, 0.2, 0.7, 0.06, TANK, 30), Ln(0.5, 0.3, 0.7, 0.06, TANK, -30), Ln(0.5, 0.4, 0.6, 0.05, TANK, 30), Ci(0.5, 0.3, 0.2, 0.1, TANK, { Transparency = 0.2 }) }),
		faceP(join({ Ln(0.33, 0.29, 0.17, 0.04, INK, -8), Ln(0.67, 0.27, 0.17, 0.04, INK, -18) }, eyes(0.43, INK, { h = 0.12, w = 0.09 }),
			grin(0.69, 0.24, 0.075))),
	}, { PT(RL, "Right", { Bx(0.5, 0.4, 0.1, 0.8, WH) }), PT(LL, "Left", { Bx(0.5, 0.4, 0.1, 0.8, WH) }),
		PT(RL, "Front", { Ln(0.25, 0.12, 0.3, 0.02, C(50, 52, 64), -60) }), PT(LL, "Front", { Ln(0.75, 0.12, 0.3, 0.02, C(50, 52, 64), 60) }) }),
	FX = { HandTrails = NEONG },
})

local CHB, CGOLD, CRED = C(25, 25, 30), C(255, 196, 40), C(215, 28, 40)
local halo = {}
for i = 0, 7 do
	halo[#halo + 1] = ring(H, BA, V(0.2, 0.2, 0.2), C(255, 220, 90), NE, 0.72, 1.12, i * 45, { Anim = { Circle = 1.2, Seed = 70 } })
end
local function glove(limb, s)
	return {
		E(limb, V(1.5, 1.32, 1.6), CRED, SP, 0, -1.25, -0.1, { Particles = { Kind = "Fire", Color = C(255, 140, 40), Rate = 18, Speed = 2, Size = 0.8, Life = 0.5, TransformOnly = true } }),
		E(limb, V(0.5, 0.62, 0.5), CRED, SP, -s * 0.55, -1.0, -0.45),
		P(limb, B, V(1.2, 0.45, 1.2), WH, SP, 0, -0.6, 0),
		P(limb, B, V(0.08, 0.46, 1.22), CGOLD, SP, 0, -0.6, 0),
	}
end
S({ Id = "FitnessCoach_Legendary", Character = "FitnessCoach", Rarity = "Legendary", Name = "Undisputed Champ",
	Desc = "Undefeated in 47 office fights. Trains on the stairs. All of them.",
	Outfit = { Shirt = CHB, Pants = CHB, ArmsSkin = true },
	HideHair = true, HideFace = true,
	Parts = join(halo, glove(RA, 1), glove(LA, -1), {
		-- cheveux ras
		E(H, V(1.3, 0.5, 1.3), C(30, 22, 18), SP, 0, 0.44, 0.05),
		E(H, V(1.28, 0.6, 0.5), C(30, 22, 18), SP, 0, 0.16, 0.38),
		-- peignoir : capuche baissée, liserés, manches courtes, pans ouverts sur le short rouge
		E(T, V(1.6, 0.72, 0.62), CHB, FA, 0, 0.95, 0.62),
		P(T, B, V(0.16, 1.9, 0.04), CGOLD, FO, 0.36, 0.05, -0.53, 0, 0, 12),
		P(T, B, V(0.16, 1.9, 0.04), CGOLD, FO, -0.36, 0.05, -0.53, 0, 0, -12),
		P(RA, B, V(1.12, 1.0, 1.12), CHB, FA, 0, 0.5, 0), P(LA, B, V(1.12, 1.0, 1.12), CHB, FA, 0, 0.5, 0),
		P(RA, B, V(1.14, 0.1, 1.14), CGOLD, SP, 0, 0.02, 0), P(LA, B, V(1.14, 0.1, 1.14), CGOLD, SP, 0, 0.02, 0),
		P(T, B, V(2.06, 0.9, 1.06), CRED, SP, 0, -1.45, 0),
		P(T, B, V(0.95, 1.4, 1.12), CHB, FA, 0.58, -1.68, 0.02, 0, -8, 0),
		P(T, B, V(0.95, 1.4, 1.12), CHB, FA, -0.58, -1.68, 0.02, 0, 8, 0),
		P(T, B, V(0.97, 0.1, 1.14), CGOLD, SP, 0.58, -2.35, 0.02, 0, -8, 0),
		P(T, B, V(0.97, 0.1, 1.14), CGOLD, SP, -0.58, -2.35, 0.02, 0, 8, 0),
		-- ceinture de champion
		P(T, B, V(2.12, 0.36, 1.12), C(30, 20, 20), SP, 0, -0.86, 0),
		{ Limb = T, Asset = "FitnessCoach_Legendary_Belt", Size = V(2.8, 1.7, 2.1), Offset = CFrame.new(0, -0.86, -0.12) },
		E(T, V(0.3, 0.3, 0.1), CRED, NE, 0, -0.84, -0.98, { Anim = { Pulse = 0.35 }, Transparency = 0.2 }),
		-- bottes de boxe montantes
		P(RL, B, V(1.06, 1.0, 1.06), WH, SP, 0, -0.5, 0), P(LL, B, V(1.06, 1.0, 1.06), WH, SP, 0, -0.5, 0),
		E(RL, V(1.04, 0.38, 0.6), WH, SP, 0, -0.85, -0.46), E(LL, V(1.04, 0.38, 0.6), WH, SP, 0, -0.85, -0.46),
		P(RL, B, V(1.1, 0.1, 1.3), CHB, SP, 0, -0.98, -0.12), P(LL, B, V(1.1, 0.1, 1.3), CHB, SP, 0, -0.98, -0.12),
		P(RL, B, V(1.09, 0.1, 1.09), CGOLD, SP, 0, 0.0, 0), P(LL, B, V(1.09, 0.1, 1.09), CGOLD, SP, 0, 0.0, 0),
		-- pancarte FINAL ROUND
		P(H, B, V(1.7, 1.1, 0.06), CGOLD, NE, -2.0, 1.2, 0.04, { Anim = { Float = true, Seed = 33 } }),
		P(H, B, V(1.6, 1.0, 0.08), WH, SP, -2.0, 1.2, 0, { Text = { Text = "FINAL\nROUND", Font = "Bangers", Color = CRED, Face = "Both", Stroke = false }, Anim = { Float = true, Seed = 33 } }),
		-- transformation : K.O.!
		P(H, B, V(1.6, 0.8, 0.06), WH, SP, 1.6, 1.9, 0, { Transform = true, Transparency = 1, Text = { Text = "K.O.!", Font = "Bangers", Color = CGOLD, Face = "Both", Blink = 3 } }),
	}),
	Paint = join({
		PT(T, "Front", { Bx(0.5, 0.45, 0.34, 0.9, C(45, 45, 52)), Tx(0.5, 0.3, 0.2, 0.14, "★", CGOLD, "Black", { Stroke = false }) }),
		PT(T, "Back", { Tx(0.5, 0.5, 0.85, 0.22, "CHAMP", CGOLD, "Black", { Stroke = { C(80, 50, 0), 3 } }), Tx(0.5, 0.72, 0.5, 0.1, "47 - 0", WH, "Black") }),
		faceP(join(brows(0.3, INK, -14, { th = 0.045 }), eyes(0.43, INK, { h = 0.11, w = 0.09 }), grin(0.69, 0.24, 0.075, { mouth = CGOLD }),
			{ Bx(0.72, 0.56, 0.14, 0.06, C(250, 240, 220), { Rotation = 20 }), Ln(0.72, 0.56, 0.01, 0.06, C(200, 180, 160), 20) })),
	}, legs4({ Bx(0.5, 0.42, 1, 0.04, CGOLD) })),
	FX = { Spotlight = C(255, 250, 220), PowerAura = CGOLD, Orbit = { Color = CGOLD, Count = 3, Shape = "Ball", Size = 0.32, Speed = 3 } },
	Highlight = { Outline = CGOLD },
	HitColor = CGOLD,
})





return L
