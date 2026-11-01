--[[
	SkinList.Pack5 — skins v3 (Rare / Epic / Legendary) de The Temp et The Consultant (agent newchars1).
	Chaque entrée REMPLACE / ajoute l'entrée de même Id dans SkinList (voir CONTRACT_SKINS_V3).
	Repères R6 : tête (visuel ~1,25, dessus ~+0,62, visage en -Z), buste 2x2x1, membres 1x2x1 (main à y -1).
	Offsets relatifs au centre du membre ; -Z = devant ; +X = côté droit du perso.
	Assets générés (ReplicatedStorage.SkinAssets) : Temp_Epic_Crane, Temp_Legendary_Shuriken, Consultant_Legendary_Briefcase.
]]
local C, V = Color3.fromRGB, Vector3.new
local rad = math.rad
local SP, NE, GL, ME, FA, FO = "SmoothPlastic", "Neon", "Glass", "Metal", "Fabric", "Foil"
local H, T, LA, RA, LL, RL = "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"
local B, BA, CY, WE = "Block", "Ball", "Cylinder", "Wedge"

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
local function R(limb, size, col, mat, x, y, z, rx, ry, rz, opt)
	local t = P(limb, B, size, col, mat, x, y, z, rx, ry, rz, opt)
	t.Mesh = { Type = "Sphere" }
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
local function face(limb, f, els, glow)
	return { Limb = limb, Face = f, Elements = els, Glow = glow }
end

local WHT, BLK, DARK = C(245, 245, 245), C(20, 20, 25), C(35, 35, 42)
local L = {}
local function S(def)
	if def.HideIdentity == nil then
		def.HideIdentity = true
	end
	L[#L + 1] = def
end

-- ===================== THE TEMP =====================
local INDIGO, INDIGO2, INDIGOD = C(95, 85, 255), C(160, 150, 255), C(55, 50, 130)
local INK, INK2 = C(28, 26, 40), C(20, 18, 30)
local NOTE, PAPER = C(255, 230, 70), C(242, 238, 228)
local STEEL, DSTEEL = C(200, 205, 215), C(62, 64, 78)

-- baskets : tige + bout arrondi + semelle
local function sneakers(col, toe, sole)
	return sym(LL, RL, function(l)
		return {
			P(l, B, V(1.06, 0.42, 1.08), col, SP, 0, -0.78, 0),
			R(l, V(1.02, 0.4, 0.5), toe or col, SP, 0, -0.84, -0.5),
			P(l, B, V(1.1, 0.12, 1.34), sole, SP, 0, -0.96, -0.12),
		}
	end)
end

local HOOD = C(62, 64, 88)
S({ Id = "Temp_Rare", Character = "Temp", Rarity = "Rare", Name = "Night Shift Temp",
	Desc = "Works 11 PM to 7 AM. Nobody has ever seen him arrive. Or leave.",
	Outfit = { Shirt = HOOD, Pants = C(40, 42, 56) },
	HideHair = true,
	Parts = join({
		-- bonnet + revers + pompon post-it
		R(H, V(1.38, 0.78, 1.4), INDIGOD, FA, 0, 0.55, 0.03),
		P(H, CY, V(0.3, 1.44, 1.44), C(75, 68, 170), FA, 0, 0.3, 0.03, 0, 0, 90),
		P(H, BA, V(0.42, 0.42, 0.42), NOTE, SP, 0, 0.98, 0.06),
		-- capuche baissée + casque autour du cou
		R(T, V(1.75, 0.62, 0.8), HOOD, FA, 0, 1.0, 0.42),
		P(T, B, V(1.55, 0.1, 0.14), DARK, SP, 0, 1.1, 0.42),
		P(T, CY, V(0.22, 0.55, 0.55), DARK, SP, -0.72, 1.02, -0.05),
		P(T, CY, V(0.22, 0.55, 0.55), DARK, SP, 0.72, 1.02, -0.05),
		P(T, CY, V(0.06, 0.4, 0.4), INDIGO, NE, -0.84, 1.02, -0.05),
		P(T, CY, V(0.06, 0.4, 0.4), INDIGO, NE, 0.84, 1.02, -0.05),
		-- cordons de capuche
		P(T, B, V(0.06, 0.55, 0.06), WHT, SP, -0.22, 0.62, -0.53),
		P(T, B, V(0.06, 0.65, 0.06), WHT, SP, 0.22, 0.58, -0.53),
		-- thermos de café (main gauche)
		P(LA, CY, V(0.95, 0.5, 0.5), STEEL, ME, 0, -1.25, -0.15, 0, 0, 90),
		P(LA, CY, V(0.16, 0.52, 0.52), INDIGO, SP, 0, -0.85, -0.15, 0, 0, 90),
	},
	sym(LA, RA, function(l)
		return { P(l, B, V(1.07, 0.26, 1.07), C(48, 50, 70), FA, 0, -0.8, 0) }
	end),
	sneakers(WHT, WHT, INDIGO)),
	Paint = {
		face(T, "Front", {
			bx(0.5, 0.78, 0.6, 0.26, C(50, 52, 72), { Corner = 0.3 }), -- poche kangourou
			bx(0.5, 0.67, 0.6, 0.02, C(40, 42, 60)),
			bx(0.3, 0.36, 0.3, 0.2, WHT, { Corner = 0.15 }), -- étiquette HELLO
			bx(0.3, 0.29, 0.3, 0.07, C(220, 50, 50), { Corner = 0.15 }),
			tx(0.3, 0.29, 0.26, 0.05, "HELLO MY NAME IS", WHT, "Black"),
			tx(0.3, 0.39, 0.24, 0.1, "???", INDIGOD, "Marker"),
		}),
		face(T, "Back", { tx(0.5, 0.45, 0.8, 0.22, "NIGHT SHIFT", INDIGO2, "Arcade"), bx(0.5, 0.58, 0.7, 0.02, INDIGO2) }),
		face(LL, "Front", { bx(0.15, 0.5, 0.03, 1, C(32, 34, 46)) }),
		face(RL, "Front", { bx(0.85, 0.5, 0.03, 1, C(32, 34, 46)) }),
	},
})

S({ Id = "Temp_Epic", Character = "Temp", Rarity = "Epic", Name = "Origami Shinobi",
	Desc = "Folded himself out of a single A4 sheet. Recyclable. Lethal.",
	Outfit = { Shirt = PAPER, Pants = C(45, 40, 95) },
	HideFace = true, HideHair = true,
	HitColor = INDIGO2,
	FX = { HandTrails = INDIGO2 },
	Parts = join({
		-- capuche de papier plié + coins pliés + masque + bandeau
		R(H, V(1.4, 0.7, 1.42), PAPER, SP, 0, 0.48, 0.04),
		P(H, WE, V(0.12, 0.5, 0.55), PAPER, SP, -0.5, 0.95, 0.15, 0, 90, 15),
		P(H, WE, V(0.12, 0.5, 0.55), PAPER, SP, 0.5, 0.95, 0.15, 0, -90, -15),
		P(H, B, V(1.3, 0.46, 1.3), INDIGOD, SP, 0, -0.3, 0),
		P(H, B, V(1.42, 0.18, 1.42), INDIGO, NE, 0, 0.24, 0.02),
		P(H, B, V(0.16, 0.8, 0.05), INDIGO, NE, 0.18, -0.05, 0.76, 20, 0, 18, { Anim = { Swing = 12, SwingSpeed = 2.5, SwingAxis = "X" } }),
		P(H, B, V(0.16, 0.7, 0.05), INDIGO, NE, -0.14, -0.05, 0.76, 20, 0, -15, { Anim = { Swing = 12, SwingSpeed = 2.8, SwingAxis = "X" } }),
		-- plis croisés sur le torse + ceinture-sash + noeud
		P(T, B, V(0.26, 2.3, 0.06), INDIGO, SP, 0, 0.05, -0.53, 0, 0, 38),
		P(T, B, V(0.26, 2.3, 0.06), INDIGOD, SP, 0, 0.05, -0.535, 0, 0, -38),
		P(T, B, V(2.08, 0.32, 1.08), INDIGO, SP, 0, -0.74, 0),
		P(T, WE, V(0.1, 0.5, 0.35), INDIGO, SP, 0.6, -1.0, -0.56, 0, 90, 0),
		P(T, WE, V(0.1, 0.4, 0.35), INDIGOD, SP, 0.78, -1.0, -0.56, 0, 90, 0),
		-- kunai de papier à la ceinture
		P(T, B, V(0.08, 0.7, 0.24), PAPER, SP, -0.7, -0.95, 0.56, 0, 0, 15),
		P(T, B, V(0.1, 0.3, 0.1), INK, SP, -0.62, -0.62, 0.56, 0, 0, 15),
		-- grue en origami sur l'épaule gauche (mesh généré)
		{ Limb = T, Asset = "Temp_Epic_Crane", Size = V(1.25, 0.8, 1.1), Offset = CFrame.new(-0.72, 1.42, 0.1) * CFrame.Angles(0, rad(90), 0), Anim = { Bob = 0.08, BobSpeed = 2.2 } },
	},
	-- épaulières pliées (deux couches) + bandes d'avant-bras
	sym(LA, RA, function(l, s)
		return {
			P(l, B, V(1.3, 0.2, 1.24), PAPER, SP, 0.12 * s, 1.02, 0, 0, 0, -22 * s),
			P(l, B, V(1.32, 0.07, 1.26), INDIGO, SP, 0.12 * s, 0.9, 0, 0, 0, -22 * s),
			P(l, B, V(1.2, 0.18, 1.18), PAPER, SP, 0.2 * s, 0.74, 0, 0, 0, -30 * s),
			P(l, B, V(1.06, 0.6, 1.06), INDIGOD, FA, 0, -0.55, 0),
		}
	end),
	-- jambières de papier + tabi
	sym(LL, RL, function(l)
		return {
			P(l, B, V(1.06, 0.7, 1.06), PAPER, SP, 0, -0.35, 0),
			P(l, B, V(1.08, 0.06, 1.08), INDIGO, SP, 0, -0.02, 0),
			P(l, B, V(1.07, 0.32, 1.12), INK, SP, 0, -0.84, -0.04),
		}
	end)),
	Paint = {
		face(H, "Front", {
			ci(0.36, 0.42, 0.13, 0.11, WHT), ci(0.64, 0.42, 0.13, 0.11, WHT),
			ci(0.37, 0.43, 0.06, 0.08, INK), ci(0.63, 0.43, 0.06, 0.08, INK),
			bx(0.35, 0.33, 0.18, 0.04, INK, { Rotation = 14, Corner = 1 }),
			bx(0.65, 0.33, 0.18, 0.04, INK, { Rotation = -14, Corner = 1 }),
		}),
		face(T, "Front", {
			bx(0.25, 0.25, 0.01, 0.5, C(205, 200, 190)), bx(0.75, 0.25, 0.01, 0.5, C(205, 200, 190)),
			bx(0.5, 0.55, 1, 0.01, C(205, 200, 190)),
		}),
		face(T, "Back", {
			ci(0.5, 0.4, 0.55, 0.55, INDIGO, { Transparency = 0.1 }),
			tx(0.5, 0.4, 0.42, 0.18, "TEMP", PAPER, "Black"),
			bx(0.5, 0.55, 1, 0.01, C(205, 200, 190)),
		}),
	},
})

-- pièce en orbite autour du buste (kunai de papier)
local function orbit(i, n, r, y, col, mat, seed)
	local a = rad(i / n * 360)
	return P(T, B, V(0.42, 0.42, 0.08), col, mat, r * math.cos(a), y, -r * math.sin(a), 0, i / n * 360 + 90, 45, { Anim = { Circle = 1.8, Seed = seed, Bob = 0.15, BobSpeed = 1.5, React = true } })
end
S({ Id = "Temp_Legendary", Character = "Temp", Rarity = "Legendary", Name = "Shadow Contractor",
	Desc = "Hired off the books. Paid in shadows. Leaves no paper trail. Ever.",
	Outfit = { Shirt = INK, Pants = INK2 },
	HideFace = true, HideHair = true,
	HitColor = INDIGO,
	Highlight = { Outline = INDIGO2 },
	FX = { PowerAura = INDIGO, HandTrails = INDIGO2 },
	Parts = join({
		-- capuche + masque + bandeau néon
		R(H, V(1.46, 0.72, 1.46), INK, FA, 0, 0.5, 0.08),
		P(H, B, V(0.16, 1.1, 1.25), INK, FA, 0.68, 0.05, 0.08),
		P(H, B, V(0.16, 1.1, 1.25), INK, FA, -0.68, 0.05, 0.08),
		P(H, B, V(1.24, 1.1, 0.36), INK, FA, 0, -0.1, 0.55),
		P(H, B, V(1.32, 0.5, 1.32), INK2, SP, 0, -0.3, 0),
		P(H, B, V(1.48, 0.15, 1.48), INDIGO, NE, 0, 0.42, 0.02),
		P(H, B, V(0.16, 1.2, 0.05), INDIGO, NE, 0.16, -0.15, 0.8, 22, 0, 16, { Anim = { Swing = 16, SwingSpeed = 3, SwingAxis = "X", React = true } }),
		P(H, B, V(0.16, 1.0, 0.05), INDIGO, NE, -0.14, -0.1, 0.8, 22, 0, -14, { Anim = { Swing = 16, SwingSpeed = 3.4, SwingAxis = "X", React = true } }),
		-- écharpe + traîne qui flotte
		R(T, V(1.75, 0.48, 1.28), INDIGOD, FA, 0, 1.0, 0),
		P(T, B, V(0.55, 1.0, 0.08), INDIGOD, FA, 0.45, 0.35, 0.62, -12, 0, -8, { Anim = { Swing = 10, SwingSpeed = 2.2, SwingAxis = "X" } }),
		P(T, B, V(0.5, 0.9, 0.08), INDIGO, NE, 0.5, -0.45, 0.78, -22, 0, -12, { Anim = { Swing = 14, SwingSpeed = 2.2, SwingAxis = "X" } }),
		-- plastron + liserés néon + ceinture + boucle shuriken
		P(T, B, V(1.6, 1.0, 0.12), DSTEEL, ME, 0, 0.35, -0.55),
		P(T, B, V(1.62, 0.05, 0.14), INDIGO, NE, 0, -0.16, -0.55),
		P(T, B, V(0.05, 1.0, 0.14), INDIGO, NE, 0, 0.35, -0.56),
		P(T, B, V(2.1, 0.28, 1.1), DSTEEL, ME, 0, -0.8, 0),
		P(T, B, V(0.38, 0.38, 0.06), INDIGO2, NE, 0, -0.8, -0.58, 0, 0, 45),
		P(T, B, V(0.38, 0.38, 0.06), INDIGO, NE, 0, -0.8, -0.585),
		-- shuriken géant dans le dos (mesh généré) qui tourne
		{ Limb = T, Asset = "Temp_Legendary_Shuriken", Size = V(2.5, 2.5, 1), Offset = CFrame.new(0, 0.3, 0.9), Anim = { Spin = 90, Axis = "Z", React = true }, Light = INDIGO },
		-- kunai de papier en orbite
		orbit(0, 4, 2.3, 0.4, INDIGO2, NE, 31), orbit(1, 4, 2.3, 0.4, INDIGO, NE, 31),
		orbit(2, 4, 2.3, 0.4, INDIGO2, NE, 31), orbit(3, 4, 2.3, 0.4, INDIGO, NE, 31),
	},
	-- épaulières, brassards néon
	sym(LA, RA, function(l, s)
		return {
			R(l, V(1.3, 0.62, 1.3), DSTEEL, ME, 0.08 * s, 0.92, 0),
			P(l, CY, V(0.06, 1.3, 1.3), INDIGO, NE, 0.08 * s, 0.7, 0, 0, 0, 90),
			P(l, B, V(1.1, 0.72, 1.1), DSTEEL, ME, 0, -0.55, 0),
			P(l, B, V(1.12, 0.07, 1.12), INDIGO, NE, 0, -0.4, 0),
			P(l, B, V(0.08, 0.5, 0.3), INDIGO2, NE, 0.56 * s, -0.55, 0),
		}
	end),
	-- jambières + bottes tabi
	sym(LL, RL, function(l)
		return {
			P(l, B, V(1.08, 0.7, 1.08), DSTEEL, ME, 0, -0.45, 0),
			P(l, B, V(0.5, 0.6, 0.06), INDIGO, NE, 0, -0.45, -0.56),
			R(l, V(1.04, 0.4, 0.55), INK2, SP, 0, -0.84, -0.48),
		}
	end)),
	Paint = {
		face(H, "Front", {
			bx(0.36, 0.42, 0.2, 0.06, INDIGO2, { Rotation = 12, Corner = 1 }),
			bx(0.64, 0.42, 0.2, 0.06, INDIGO2, { Rotation = -12, Corner = 1 }),
			ci(0.37, 0.42, 0.07, 0.07, WHT), ci(0.63, 0.42, 0.07, 0.07, WHT),
		}, true),
		face(T, "Back", {
			ci(0.5, 0.75, 0.3, 0.2, INDIGO, { Transparency = 0.2 }),
			tx(0.5, 0.75, 0.28, 0.1, "NO TRACE", INDIGO2, "Arcade"),
		}, true),
		face(LA, "Front", { bx(0.5, 0.2, 0.05, 0.35, INDIGO) }, true),
		face(RA, "Front", { bx(0.5, 0.2, 0.05, 0.35, INDIGO) }, true),
	},
})

-- ===================== THE CONSULTANT =====================
local ROYAL, ROYAL2, NAVY = C(40, 100, 240), C(120, 175, 255), C(28, 36, 64)
local ORANGE, TEAL, YELLOW, PINK = C(255, 150, 40), C(40, 200, 170), C(255, 215, 50), C(255, 90, 140)
local GOLD, GOLD2, GOLDD = C(255, 200, 60), C(255, 225, 120), C(190, 140, 40)
local LASER = C(255, 40, 50)
local HAIRB, GREYH = C(120, 80, 45), C(160, 160, 165)

local VEST = C(52, 62, 84)
S({ Id = "Consultant_Rare", Character = "Consultant", Rarity = "Rare", Name = "Casual Friday",
	Desc = "Fleece vest. Cold brew. Has never once said a sentence without 'circle back'.",
	Outfit = { Shirt = C(150, 190, 240), Pants = C(190, 165, 120) },
	HideHair = true,
	Parts = join({
		-- cheveux coiffés avec mèche + lunettes de soleil remontées
		R(H, V(1.36, 0.52, 1.34), HAIRB, SP, 0, 0.56, 0.05),
		R(H, V(0.8, 0.38, 0.7), HAIRB, SP, 0.18, 0.72, -0.38, -15, 0, -12),
		P(H, B, V(1.22, 0.08, 0.08), DARK, SP, 0, 0.16, -0.62),
		P(H, B, V(0.44, 0.24, 0.06), C(30, 45, 75), GL, -0.25, 0.1, -0.64),
		P(H, B, V(0.44, 0.24, 0.06), C(30, 45, 75), GL, 0.25, 0.1, -0.64),
		R(H, V(1.34, 0.85, 0.55), HAIRB, SP, 0, 0.22, 0.42),
		-- écouteurs blancs
		P(H, BA, V(0.2, 0.2, 0.2), WHT, SP, -0.66, 0.05, -0.05),
		P(H, BA, V(0.2, 0.2, 0.2), WHT, SP, 0.66, 0.05, -0.05),
		-- doudoune sans manches (corps + col + bas)
		P(T, B, V(2.1, 2.02, 1.1), VEST, FA, 0, 0, 0),
		P(T, B, V(1.35, 0.3, 1.12), VEST, FA, 0, 1.02, 0),
		P(T, B, V(2.12, 0.12, 1.12), C(40, 48, 66), FA, 0, -0.92, 0),
		-- cordon + badge
		P(T, B, V(0.08, 0.7, 0.05), ROYAL, SP, -0.18, 0.55, -0.58, 0, 0, -18),
		P(T, B, V(0.08, 0.7, 0.05), ROYAL, SP, 0.18, 0.55, -0.58, 0, 0, 18),
		P(T, B, V(0.4, 0.5, 0.05), WHT, SP, 0, 0.12, -0.6),
		-- montre connectée + cold brew
		P(LA, B, V(1.06, 0.18, 1.06), DARK, SP, 0, -0.55, 0),
		P(LA, B, V(0.32, 0.32, 0.06), ROYAL2, NE, 0, -0.55, -0.56),
		P(RA, CY, V(0.95, 0.48, 0.48), C(240, 240, 240), GL, 0, -1.25, -0.2, 0, 0, 90),
		P(RA, CY, V(0.6, 0.44, 0.44), C(90, 55, 30), SP, 0, -1.35, -0.2, 0, 0, 90),
		P(RA, B, V(0.06, 0.06, 0.9), C(40, 160, 90), SP, 0, -0.75, -0.2, 90, 0, 0),
	},
	sneakers(WHT, WHT, C(220, 220, 225))),
	Paint = {
		face(T, "Front", {
			bx(0.5, 0.55, 0.025, 0.9, C(200, 205, 215)),
			bx(0.5, 0.11, 0.02, 0.1, C(200, 205, 215)),
			tx(0.27, 0.3, 0.2, 0.06, "SYNRG", ROYAL2, "Black"),
			tx(0.5, 0.16, 0.3, 0.06, "J. DOE", DARK, "Bold"),
		}),
		face(T, "Back", { tx(0.5, 0.3, 0.5, 0.08, "SYNRG", ROYAL2, "Black") }),
		face(LL, "Front", { bx(0.5, 0.5, 0.02, 1, C(170, 145, 100)), bx(0.5, 0.92, 1, 0.08, C(170, 145, 100)) }),
		face(RL, "Front", { bx(0.5, 0.5, 0.02, 1, C(170, 145, 100)), bx(0.5, 0.92, 1, 0.08, C(170, 145, 100)) }),
		face(LL, "Left", { bx(0.5, 0.92, 0.8, 0.07, ROYAL, { Corner = 1 }) }),
		face(RL, "Right", { bx(0.5, 0.92, 0.8, 0.07, ROYAL, { Corner = 1 }) }),
	},
})

local TURTLE, JEANS = C(25, 25, 28), C(60, 85, 130)
S({ Id = "Consultant_Epic", Character = "Consultant", Rarity = "Epic", Name = "Keynote Visionary",
	Desc = "Walks on stage, pauses for 9 seconds, says 'reimagined'. Standing ovation.",
	Outfit = { Shirt = TURTLE, Pants = JEANS },
	HideFace = true, HideHair = true,
	HitColor = ROYAL2,
	FX = { Spotlight = C(255, 250, 230) },
	Parts = join({
		-- cheveux courts grisonnants + lunettes rondes
		R(H, V(1.32, 0.42, 1.3), GREYH, SP, 0, 0.6, 0.06),
		R(H, V(1.32, 0.8, 0.55), GREYH, SP, 0, 0.22, 0.42),
		P(H, CY, V(0.05, 0.4, 0.4), DARK, ME, -0.24, 0.1, -0.64, 0, 90, 0),
		P(H, CY, V(0.05, 0.4, 0.4), DARK, ME, 0.24, 0.1, -0.64, 0, 90, 0),
		P(H, CY, V(0.03, 0.32, 0.32), C(215, 232, 250), SP, -0.24, 0.1, -0.665, 0, 90, 0),
		P(H, CY, V(0.03, 0.32, 0.32), C(215, 232, 250), SP, 0.24, 0.1, -0.665, 0, 90, 0),
		P(H, BA, V(0.1, 0.13, 0.04), DARK, SP, -0.24, 0.09, -0.69),
		P(H, BA, V(0.1, 0.13, 0.04), DARK, SP, 0.24, 0.09, -0.69),
		P(H, B, V(0.12, 0.04, 0.04), DARK, ME, 0, 0.12, -0.65),
		-- micro-casque
		P(H, B, V(0.06, 0.06, 0.6), C(230, 220, 200), SP, 0.52, -0.15, -0.38, 0, 35, 0),
		P(H, BA, V(0.12, 0.12, 0.12), C(230, 220, 200), SP, 0.36, -0.2, -0.64),
		P(H, BA, V(0.18, 0.18, 0.18), C(230, 220, 200), SP, 0.64, 0.02, 0),
		-- col roulé
		R(T, V(1.2, 0.36, 1.05), TURTLE, FA, 0, 1.05, 0),
		-- télécommande de présentation (main droite) + écran holographique (transformation)
		P(RA, B, V(0.26, 0.16, 0.6), C(200, 200, 205), ME, 0, -1.12, -0.3),
		P(RA, B, V(0.12, 0.06, 0.12), LASER, NE, 0, -1.03, -0.45),
		P(T, B, V(3.4, 2.0, 0.08), ROYAL2, NE, 0, 2.6, 1.6, 10, 0, 0, { Transparency = 0.55, Transform = true, Anim = { Float = true }, Text = { Text = "REIMAGINED.", Color = WHT, Font = "SciFi", Face = "Back" } }),
		P(T, B, V(0.5, 0.9, 0.1), ORANGE, NE, -1.0, 2.2, 1.66, 10, 0, 0, { Transform = true, Anim = { Float = true } }),
		P(T, B, V(0.5, 1.3, 0.1), TEAL, NE, -0.4, 2.35, 1.66, 10, 0, 0, { Transform = true, Anim = { Float = true } }),
		P(T, B, V(0.5, 1.7, 0.1), YELLOW, NE, 0.2, 2.5, 1.66, 10, 0, 0, { Transform = true, Anim = { Float = true } }),
	},
	sneakers(C(240, 240, 240), C(240, 240, 240), C(200, 200, 205)),
	sym(LA, RA, function(l)
		return { P(l, B, V(1.06, 0.3, 1.06), TURTLE, FA, 0, -0.72, 0) } -- manches remontées
	end)),
	Paint = {
		face(H, "Front", {
			bx(0.5, 0.72, 0.6, 0.32, C(120, 115, 110), { Transparency = 0.7, Corner = 0.45 }),
			ci(0.37, 0.43, 0.07, 0.09, C(30, 25, 25)), ci(0.63, 0.43, 0.07, 0.09, C(30, 25, 25)),
			bx(0.36, 0.32, 0.15, 0.035, GREYH, { Corner = 1, Rotation = -5 }),
			bx(0.64, 0.32, 0.15, 0.035, GREYH, { Corner = 1, Rotation = 5 }),
			bx(0.5, 0.67, 0.22, 0.035, C(90, 40, 40), { Corner = 1, Rotation = -4 }),
		}),
		face(T, "Front", {
			bx(0.5, 0.06, 0.6, 0.02, C(45, 45, 50)),
			tx(0.5, 0.92, 0.5, 0.06, "THINK BIGGER", C(55, 55, 62), "Condensed"),
		}),
		face(LL, "Front", { bx(0.5, 0.42, 0.5, 0.08, C(80, 110, 160), { Corner = 1, Transparency = 0.4 }) }),
		face(RL, "Front", { bx(0.5, 0.42, 0.5, 0.08, C(80, 110, 160), { Corner = 1, Transparency = 0.4 }) }),
	},
})

local function holo(i, n, r, y, col, size, seed)
	local a = rad(i / n * 360)
	return P(T, B, size, col, NE, r * math.cos(a), y, -r * math.sin(a), 0, i / n * 360 + 90, 0, { Transparency = 0.25, Anim = { Circle = 1.2, Seed = seed, React = true } })
end
S({ Id = "Consultant_Legendary", Character = "Consultant", Rarity = "Legendary", Name = "Synergy Overlord",
	Desc = "Billed 3,000 hours this week. There are only 168. Nobody dares to ask.",
	Outfit = { Shirt = GOLD, Pants = GOLDD },
	HideFace = true, HideHair = true,
	HitColor = GOLD,
	Highlight = { Outline = GOLD2 },
	FX = { PowerAura = GOLD, HandTrails = ROYAL2 },
	Parts = join({
		-- cheveux gominés dorés + monocle laser
		R(H, V(1.36, 0.5, 1.36), C(240, 200, 90), FO, 0, 0.58, 0.06),
		R(H, V(1.0, 0.36, 0.7), C(240, 200, 90), FO, -0.1, 0.72, -0.36, -12, 0, 10),
		R(H, V(1.34, 0.85, 0.55), C(240, 200, 90), FO, 0, 0.22, 0.42),
		P(H, CY, V(0.06, 0.44, 0.44), GOLD, ME, 0.24, 0.1, -0.64, 0, 90, 0),
		P(H, CY, V(0.04, 0.36, 0.36), LASER, NE, 0.24, 0.1, -0.66, 0, 90, 0, { Transparency = 0.25, Light = LASER }),
		P(H, B, V(0.03, 0.6, 0.03), GOLD, ME, 0.42, -0.2, -0.6, 0, 0, 20),
		-- revers noirs, cravate néon, pochette, bouton
		P(T, B, V(0.32, 1.15, 0.06), BLK, SP, -0.42, 0.42, -0.54, 0, 0, -28),
		P(T, B, V(0.32, 1.15, 0.06), BLK, SP, 0.42, 0.42, -0.54, 0, 0, 28),
		P(T, B, V(0.3, 1.1, 0.05), ROYAL, NE, 0, 0.35, -0.55),
		P(T, B, V(0.34, 0.2, 0.06), ROYAL2, NE, -0.62, 0.45, -0.55, 0, 0, 20),
		P(T, BA, V(0.14, 0.14, 0.08), BLK, SP, 0, -0.45, -0.53),
		-- mallette dorée (mesh généré) main gauche
		{ Limb = LA, Asset = "Consultant_Legendary_Briefcase", Size = V(1.7, 1.85, 1.0), Offset = CFrame.new(0, -1.9, 0) * CFrame.Angles(0, rad(90), 0), Color = GOLD, Material = "Foil", Light = GOLD },
		-- flèche de croissance holographique au-dessus de l'épaule droite
		P(T, B, V(0.25, 1.0, 0.1), ROYAL2, NE, 1.65, 1.75, 0, 0, 0, -30, { Anim = { Bob = 0.2, BobSpeed = 1.6, Seed = 41 } }),
		P(T, WE, V(0.1, 0.5, 0.6), ROYAL2, NE, 1.95, 2.25, 0, 0, 90, -30, { Anim = { Bob = 0.2, BobSpeed = 1.6, Seed = 41 } }),
		-- graphiques holographiques en orbite (v4 : bleu roi / or, plus d'arc-en-ciel)
		holo(0, 5, 2.4, 0.6, ROYAL2, V(0.35, 0.8, 0.08), 52), holo(1, 5, 2.4, 0.6, GOLD2, V(0.35, 1.1, 0.08), 52),
		holo(2, 5, 2.4, 0.6, ROYAL2, V(0.35, 0.6, 0.08), 52), holo(3, 5, 2.4, 0.6, GOLD2, V(0.35, 1.3, 0.08), 52),
		holo(4, 5, 2.4, 0.6, ROYAL, V(0.7, 0.7, 0.08), 52),
		-- v4 : col relevé doré + cape marine bordée d'or (rx négatif = le bas s'écarte du dos)
		P(T, B, V(2.0, 0.5, 0.1), GOLD, FO, 0, 1.12, 0.52, 15, 0, 0),
		P(T, B, V(2.1, 2.4, 0.08), NAVY, FA, 0, -0.45, 0.6, -6, 0, 0),
		P(T, B, V(2.12, 0.08, 0.1), GOLD2, NE, 0, -1.64, 0.735, -6, 0, 0),
	},
	-- épaulettes « power suit » + manchettes + chaussures vernies
	sym(LA, RA, function(l, s)
		return {
			R(l, V(1.3, 0.5, 1.3), GOLD, FO, 0.06 * s, 0.9, 0),
			P(l, B, V(1.32, 0.06, 1.32), ROYAL2, NE, 0.06 * s, 0.72, 0),
			P(l, B, V(1.07, 0.2, 1.07), WHT, SP, 0, -0.75, 0),
			P(l, BA, V(0.16, 0.16, 0.16), ROYAL2, NE, 0.5 * s, -0.75, 0),
		}
	end),
	sym(LL, RL, function(l)
		return {
			P(l, B, V(1.06, 0.35, 1.1), BLK, FO, 0, -0.82, -0.04),
			R(l, V(1.0, 0.34, 0.5), BLK, FO, 0, -0.86, -0.5),
		}
	end)),
	Paint = {
		face(H, "Front", {
			ci(0.37, 0.43, 0.07, 0.09, C(30, 25, 25)),
			bx(0.36, 0.31, 0.16, 0.04, C(200, 160, 60), { Corner = 1, Rotation = -16 }),
			bx(0.64, 0.33, 0.16, 0.04, C(200, 160, 60), { Corner = 1, Rotation = 6 }),
			bx(0.55, 0.68, 0.26, 0.05, C(90, 30, 30), { Corner = 1, Rotation = -10 }),
			bx(0.6, 0.665, 0.08, 0.035, WHT, { Corner = 0.4, Rotation = -10 }),
		}),
		face(T, "Front", {
			bx(0.1, 0.5, 0.012, 1, GOLDD), bx(0.22, 0.5, 0.012, 1, GOLDD), bx(0.78, 0.5, 0.012, 1, GOLDD), bx(0.9, 0.5, 0.012, 1, GOLDD),
		}),
		face(T, "Back", {
			ci(0.5, 0.35, 0.5, 0.42, GOLD, { Stroke = { GOLDD, 3 } }),
			tx(0.5, 0.35, 0.3, 0.3, "$", NAVY, "Black"),
			tx(0.5, 0.65, 0.8, 0.08, "SYNERGY CORP", GOLD2, "Black"),
		}),
		face(LL, "Front", { bx(0.3, 0.5, 0.012, 1, C(170, 120, 30)), bx(0.7, 0.5, 0.012, 1, C(170, 120, 30)) }),
		face(RL, "Front", { bx(0.3, 0.5, 0.012, 1, C(170, 120, 30)), bx(0.7, 0.5, 0.012, 1, C(170, 120, 30)) }),
	},
})

return L
