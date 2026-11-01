--[[
	SkinList.Pack4 — skins v3 (Rare / Epic / Legendary) de MaintenanceGuy, MarketingGuru, Lawyer, Mascot.
	Chaque entrée REMPLACE celle de même Id dans SkinList (voir CONTRACT_SKINS_V3).
	Champs avancés : Mesh (SpecialMesh), Asset (ReplicatedStorage.SkinAssets), Paint (SurfaceGui sur les membres),
	HideFace / HideHair. Repères R6 : tête (visuel ~1,25, dessus ~+0,62, visage en -Z), buste 2x2x1, membres 1x2x1.
	Offsets relatifs au centre du membre ; -Z = devant ; +X = côté droit du perso.
]]
local C, V = Color3.fromRGB, Vector3.new
local rad = math.rad
local SP, NE, GL, ME, FF, FA, FO, WO = "SmoothPlastic", "Neon", "Glass", "Metal", "ForceField", "Fabric", "Foil", "Wood"
local H, T, LA, RA, LL, RL = "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"
local B, BA, CY, WE = "Block", "Ball", "Cylinder", "Wedge"

-- Une pièce soudée à un membre (rotations en degrés). opt = options avancées (Anim, Text, Mesh, Transform...)
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
-- pièce arrondie (Block + SpecialMesh Sphere) : casques, cheveux, bouts de chaussures
local function R(limb, size, col, mat, x, y, z, rx, ry, rz, opt)
	local t = P(limb, B, size, col, mat, x, y, z, rx, ry, rz, opt)
	t.Mesh = { Type = "Sphere" }
	return t
end
-- concatène des listes de pièces
local function join(...)
	local out = {}
	for _, l in ipairs({ ... }) do
		for _, p in ipairs(l) do
			out[#out + 1] = p
		end
	end
	return out
end
-- symétrie gauche/droite : fn(limb, s) avec s = -1 (gauche) / +1 (droite) ; x*s = vers l'extérieur
local function sym(limbL, limbR, fn)
	local out = {}
	for _, e in ipairs({ { limbL, -1 }, { limbR, 1 } }) do
		for _, p in ipairs(fn(e[1], e[2])) do
			out[#out + 1] = p
		end
	end
	return out
end
-- pièce sur un anneau autour du membre (angle en degrés), pour les groupes en orbite (Anim.Circle)
local function ring(limb, shape, size, col, mat, r, y, ang, opt, face)
	local a = rad(ang)
	return P(limb, shape, size, col, mat, r * math.cos(a), y, -r * math.sin(a), 0, ang + (face or 90), 0, opt)
end
local function with(t, extra)
	local o = {}
	for k, v in pairs(t) do
		o[k] = v
	end
	for k, v in pairs(extra) do
		o[k] = v
	end
	return o
end

-- Paint : éléments de SurfaceGui (Pos / Size en 0..1, centre ; y = 0 en haut)
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
local function face(limb, f, els)
	return { Limb = limb, Face = f, Elements = els }
end
-- motif écossais (flanelle) : lignes verticales + horizontales
local function plaid(dark, light, n, w)
	local els = {}
	for i = 1, n do
		local p = (i - 0.5) / n
		els[#els + 1] = bx(p, 0.5, w, 1, dark, { Transparency = 0.35 })
		els[#els + 1] = bx(0.5, p, 1, w, dark, { Transparency = 0.35 })
		els[#els + 1] = bx(p + 0.5 / n, 0.5, w * 0.3, 1, light, { Transparency = 0.55 })
	end
	return els
end

local WHT, BLK, DARK, GOLD = C(245, 245, 245), C(20, 20, 25), C(35, 35, 42), C(255, 200, 40)
local RED, CYAN, MAG = C(230, 35, 45), C(40, 230, 255), C(225, 40, 170)
local STEEL, CHROME = C(165, 170, 180), C(200, 205, 215)

local L = {}
local function S(def)
	if def.HideIdentity == nil then
		def.HideIdentity = true
	end
	L[#L + 1] = def
end

-- ===================== MAINTENANCE GUY =====================
local HIVIS, NAVY, CHAR = C(255, 125, 25), C(38, 52, 84), C(58, 62, 72)
local HAT, TAN, BOOT, LEATH = C(255, 205, 35), C(205, 160, 95), C(130, 85, 45), C(105, 68, 40)
local REFL = C(235, 238, 242)

-- bottes de chantier (tige + coque arrondie + semelle)
local function workBoots(col, sole, toe)
	return sym(LL, RL, function(l)
		return {
			P(l, B, V(1.06, 0.6, 1.08), col, SP, 0, -0.72, 0),
			R(l, V(1.02, 0.42, 0.5), toe or col, SP, 0, -0.82, -0.5),
			P(l, B, V(1.1, 0.12, 1.32), sole, SP, 0, -0.96, -0.12),
		}
	end)
end

S({ Id = "MaintenanceGuy_Rare", Character = "MaintenanceGuy", Rarity = "Rare", Name = "Hard Hat Hero",
	Desc = "Fixes everything with tape. Everything. Including the tape.",
	Outfit = { Shirt = HIVIS, Pants = CHAR, ArmsSkin = true },
	HideHair = true,
	Parts = join({
		-- casque de chantier + lampe frontale
		R(H, V(1.38, 0.82, 1.44), HAT, SP, 0, 0.66, 0.02),
		P(H, CY, V(0.07, 1.66, 1.66), HAT, SP, 0, 0.36, 0.02, 0, 0, 90),
		R(H, V(1.0, 0.07, 0.46), HAT, SP, 0, 0.38, -0.82),
		P(H, CY, V(0.18, 0.34, 0.34), DARK, SP, 0, 0.62, -0.74, 0, 90, 0),
		P(H, CY, V(0.04, 0.26, 0.26), C(255, 250, 215), NE, 0, 0.62, -0.84, 0, 90, 0, { Light = C(255, 245, 210) }),
		-- gilet : bandes réfléchissantes, col de chemise
		P(T, B, V(2.04, 0.16, 1.04), REFL, FO, 0, -0.45, 0),
		P(T, B, V(2.04, 0.16, 1.04), REFL, FO, 0, -0.05, 0),
		P(T, B, V(1.05, 0.12, 0.75), NAVY, SP, 0, 1.04, 0),
		-- ceinture porte-outils, rouleau de ruban adhésif, pochette
		P(T, B, V(2.08, 0.24, 1.08), LEATH, SP, 0, -0.88, 0),
		P(T, B, V(0.32, 0.2, 0.04), STEEL, ME, 0, -0.88, -0.55),
		P(T, CY, V(0.24, 0.62, 0.62), C(205, 205, 210), FO, 0.55, -0.86, 0.64, 0, 90, 0),
		P(T, CY, V(0.26, 0.3, 0.3), DARK, SP, 0.55, -0.86, 0.64, 0, 90, 0),
		P(T, B, V(0.45, 0.45, 0.26), LEATH, SP, -0.6, -1.0, -0.64),
	},
	-- manches retroussées + gants de travail
	sym(LA, RA, function(l)
		return {
			P(l, B, V(1.05, 0.8, 1.05), NAVY, SP, 0, 0.6, 0),
			P(l, B, V(1.09, 0.2, 1.09), C(55, 72, 110), SP, 0, 0.2, 0),
			P(l, B, V(1.05, 0.5, 1.05), TAN, SP, 0, -0.76, 0),
		}
	end),
	-- genouillères
	sym(LL, RL, function(l)
		return { P(l, B, V(0.8, 0.45, 0.12), DARK, SP, 0, 0.0, -0.53) }
	end),
	{
		P(LL, B, V(1.06, 0.6, 1.08), BOOT, SP, 0, -0.72, 0),
		P(RL, B, V(1.06, 0.6, 1.08), BOOT, SP, 0, -0.72, 0),
		P(LL, B, V(1.1, 0.12, 1.32), C(40, 35, 30), SP, 0, -0.96, -0.12),
		P(RL, B, V(1.1, 0.12, 1.32), C(40, 35, 30), SP, 0, -0.96, -0.12),
	}),
	Paint = {
		face(T, "Front", {
			bx(0.5, 0.0, 0.34, 0.34, NAVY, { Rotation = 45 }),
			bx(0.5, 0.6, 0.025, 0.8, C(70, 70, 75)),
			bx(0.27, 0.26, 0.08, 0.52, REFL), bx(0.73, 0.26, 0.08, 0.52, REFL),
			bx(0.73, 0.38, 0.2, 0.16, C(230, 105, 15), { Stroke = { C(170, 75, 10), 2 } }),
			bx(0.69, 0.29, 0.03, 0.12, C(40, 90, 220)),
			bx(0.27, 0.4, 0.24, 0.11, WHT, { Corner = 0.25 }),
			tx(0.27, 0.4, 0.22, 0.08, "FIX-IT", NAVY, "Black"),
		}),
		face(T, "Back", {
			bx(0.27, 0.26, 0.08, 0.52, REFL), bx(0.73, 0.26, 0.08, 0.52, REFL),
			bx(0.5, 0.3, 0.84, 0.18, NAVY, { Corner = 0.2 }),
			tx(0.5, 0.3, 0.8, 0.14, "FIX-IT CREW", HIVIS, "Black"),
		}),
		face(T, "Top", { bx(0.27, 0.5, 0.08, 1, REFL), bx(0.73, 0.5, 0.08, 1, REFL) }),
		face(LL, "Left", { bx(0.5, 0.42, 0.62, 0.22, C(48, 52, 60), { Stroke = { C(35, 38, 45), 2 } }) }),
		face(RL, "Right", { bx(0.5, 0.42, 0.62, 0.22, C(48, 52, 60), { Stroke = { C(35, 38, 45), 2 } }) }),
		face(LL, "Front", { bx(0.85, 0.5, 0.03, 1, C(48, 52, 60)) }),
		face(RL, "Front", { bx(0.15, 0.5, 0.03, 1, C(48, 52, 60)) }),
	},
})

-- Visage de l'animateur déco (grand sourire, moustache, barbe de 3 jours)
local HOSTHAIR = C(95, 60, 35)
local hostFace = face(H, "Front", {
	bx(0.5, 0.74, 0.62, 0.34, HOSTHAIR, { Transparency = 0.72, Corner = 0.45 }),
	ci(0.36, 0.42, 0.11, 0.15, C(30, 25, 25)), ci(0.64, 0.42, 0.11, 0.15, C(30, 25, 25)),
	ci(0.38, 0.39, 0.04, 0.05, WHT), ci(0.66, 0.39, 0.04, 0.05, WHT),
	bx(0.36, 0.28, 0.17, 0.045, HOSTHAIR, { Rotation = -10, Corner = 1 }),
	bx(0.64, 0.28, 0.17, 0.045, HOSTHAIR, { Rotation = 10, Corner = 1 }),
	bx(0.5, 0.67, 0.36, 0.14, C(70, 20, 20), { Corner = 0.6 }),
	bx(0.5, 0.635, 0.3, 0.05, WHT, { Corner = 0.3 }),
	bx(0.5, 0.575, 0.32, 0.07, HOSTHAIR, { Corner = 1 }),
})
local FLANNEL, FLANNELD, JEAN = C(200, 38, 38), C(60, 12, 16), C(55, 85, 140)
local DRILL = C(255, 185, 25)
local function drillPart(shape, size, col, mat, x, y, z, rx, ry, rz, opt)
	if type(rx) == "table" then
		opt, rx = rx, nil
	end
	local o = { Anim = { Bob = 0.16, BobSpeed = 1.6, Seed = 44 } }
	if opt then
		o = with(o, opt)
		o.Anim = with({ Bob = 0.16, BobSpeed = 1.6, Seed = 44 }, opt.Anim or {})
	end
	return P(T, shape, size, col, mat, x, y, z, rx, ry, rz, o)
end
S({ Id = "MaintenanceGuy_Epic", Character = "MaintenanceGuy", Rarity = "Epic", Name = "Makeover Show Host",
	Desc = "MOVE! THAT! DESK! (He renovated your cubicle without asking.)",
	Outfit = { Shirt = FLANNEL, Pants = JEAN },
	HideFace = true, HideHair = true,
	Parts = join({
		-- casquette de l'émission + cheveux + crayon sur l'oreille
		R(H, V(1.42, 0.66, 1.44), C(30, 45, 95), SP, 0, 0.62, 0.04),
		P(H, B, V(0.66, 0.28, 0.05), WHT, SP, 0, 0.68, -0.66, -20, 0, 0, { Text = { Text = "MAKEOVER", Font = "Black", Color = FLANNEL } }),
		P(H, B, V(1.02, 0.06, 0.6), C(30, 45, 95), SP, 0, 0.4, -0.86),
		R(H, V(1.36, 0.5, 0.7), HOSTHAIR, SP, 0, 0.18, 0.36),
		P(H, B, V(0.07, 0.07, 0.55), DRILL, SP, 0.66, 0.22, 0.02),
		-- col de la flanelle
		P(T, B, V(1.1, 0.14, 0.8), FLANNELD, SP, 0, 1.04, 0.05),
		-- ceinture à outils chargée
		P(T, B, V(2.08, 0.22, 1.08), LEATH, SP, 0, -0.88, 0),
		P(T, B, V(0.34, 0.2, 0.04), C(210, 180, 90), ME, 0, -0.88, -0.55),
		P(T, B, V(0.55, 0.55, 0.3), C(150, 100, 55), SP, -0.62, -1.05, -0.62),
		P(T, B, V(0.55, 0.55, 0.3), C(150, 100, 55), SP, 0.62, -1.05, -0.62),
		P(T, B, V(0.12, 0.62, 0.12), C(160, 110, 60), WO, -0.75, -0.72, -0.66),
		P(T, B, V(0.42, 0.14, 0.16), STEEL, ME, -0.75, -0.42, -0.66),
		P(T, B, V(0.13, 0.32, 0.13), DRILL, SP, 0.55, -0.68, -0.66),
		P(T, B, V(0.45, 0.42, 0.26), DRILL, SP, 0.6, -0.86, 0.62),
		-- mégaphone (main gauche)
		P(LA, B, V(0.2, 0.42, 0.22), DARK, SP, 0, -1.12, -0.25),
		P(LA, CY, V(0.8, 0.42, 0.42), WHT, SP, 0, -0.98, -0.62, 0, 90, 0),
		P(LA, CY, V(0.26, 0.72, 0.72), WHT, SP, 0, -0.98, -1.12, 0, 90, 0),
		P(LA, CY, V(0.12, 0.92, 0.92), FLANNEL, SP, 0, -0.98, -1.3, 0, 90, 0),
		-- perceuse volante (mèche qui tourne)
		{ Limb = T, Asset = "MaintenanceGuy_Epic_Drill", Size = V(1.8, 1.8, 1.8), Offset = CFrame.new(2.15, 1.45, 0) * CFrame.Angles(0, rad(90), 0),
			Anim = { Bob = 0.16, BobSpeed = 1.6, Seed = 44 } },
		-- bandeau d'émission (transformation)
		P(H, B, V(2.9, 0.62, 0.1), DRILL, SP, 0, 1.9, 0, { Transform = true, Text = { Text = "MOVE THAT DESK!", Font = "Bangers", Color = DARK, Face = "Both", Blink = 1.4 },
			Anim = { Float = true, Seed = 45, React = true } }),
		P(H, B, V(3.05, 0.77, 0.06), FLANNEL, NE, 0, 1.9, 0, { Transform = true, Anim = { Float = true, Seed = 45, React = true } }),
	},
	-- manches retroussées + gants en cuir
	sym(LA, RA, function(l)
		return {
			P(l, B, V(1.1, 0.24, 1.1), FLANNELD, SP, 0, -0.42, 0),
			P(l, B, V(1.05, 0.48, 1.05), C(120, 80, 45), SP, 0, -0.78, 0),
		}
	end),
	-- jean à revers + bottes
	sym(LL, RL, function(l)
		return { P(l, B, V(1.08, 0.16, 1.08), C(95, 130, 185), SP, 0, -0.36, 0) }
	end),
	workBoots(C(180, 125, 65), C(60, 45, 35))),
	Paint = {
		hostFace,
		face(T, "Front", join(plaid(FLANNELD, C(255, 120, 120), 5, 0.05), {
			bx(0.5, 0.55, 0.36, 1.1, WHT),
			bx(0.5, 0.0, 0.38, 0.2, WHT, { Rotation = 45 }),
			tx(0.5, 0.45, 0.32, 0.12, "HQ", FLANNEL, "Black"),
			bx(0.31, 0.25, 0.02, 0.6, FLANNELD), bx(0.69, 0.25, 0.02, 0.6, FLANNELD),
			ci(0.28, 0.35, 0.035, 0.035, C(240, 230, 210)), ci(0.28, 0.55, 0.035, 0.035, C(240, 230, 210)),
			bx(0.18, 0.33, 0.2, 0.16, FLANNEL, { Stroke = { FLANNELD, 2 } }),
			bx(0.82, 0.33, 0.2, 0.16, FLANNEL, { Stroke = { FLANNELD, 2 } }),
		})),
		face(T, "Back", join(plaid(FLANNELD, C(255, 120, 120), 5, 0.05), {
			bx(0.5, 0.28, 0.8, 0.22, WHT, { Corner = 0.3 }),
			tx(0.5, 0.28, 0.76, 0.18, "MAKEOVER HQ", FLANNEL, "Black"),
		})),
		face(LA, "Front", plaid(FLANNELD, C(255, 120, 120), 2, 0.09)),
		face(RA, "Front", plaid(FLANNELD, C(255, 120, 120), 2, 0.09)),
		face(LA, "Left", plaid(FLANNELD, C(255, 120, 120), 2, 0.09)),
		face(RA, "Right", plaid(FLANNELD, C(255, 120, 120), 2, 0.09)),
		face(LA, "Back", plaid(FLANNELD, C(255, 120, 120), 2, 0.09)),
		face(RA, "Back", plaid(FLANNELD, C(255, 120, 120), 2, 0.09)),
		face(LL, "Front", { bx(0.5, 0.45, 0.5, 0.25, C(80, 112, 165), { Corner = 1 }), bx(0.85, 0.5, 0.03, 1, C(200, 160, 60)) }),
		face(RL, "Front", { bx(0.5, 0.45, 0.5, 0.25, C(80, 112, 165), { Corner = 1 }), bx(0.15, 0.5, 0.03, 1, C(200, 160, 60)) }),
		face(LL, "Back", { bx(0.5, 0.15, 0.55, 0.2, C(45, 72, 120), { Stroke = { C(200, 160, 60), 1 } }) }),
		face(RL, "Back", { bx(0.5, 0.15, 0.55, 0.2, C(45, 72, 120), { Stroke = { C(200, 160, 60), 1 } }) }),
	},
	Highlight = { Outline = DRILL },
	HitColor = DRILL,
})

-- Méga exosquelette jaune
local MECH, MECHD, MDARK, ORNG, CORE = C(255, 196, 28), C(62, 66, 80), C(34, 37, 46), C(255, 135, 25), C(70, 225, 255)
local function gear(x, y, z, d, speed, seed)
	local o = { Anim = { Spin = speed, Axis = "Z", Seed = seed, React = true } }
	return {
		P(T, CY, V(0.12, d, d), STEEL, ME, x, y, z, 0, 90, 0, { Anim = { Spin = speed, Axis = "X", Seed = seed, React = true } }),
		P(T, B, V(d * 1.18, 0.2, 0.1), STEEL, ME, x, y, z, 0, 0, 0, o),
		P(T, B, V(d * 1.18, 0.2, 0.1), STEEL, ME, x, y, z, 0, 0, 60, o),
		P(T, B, V(d * 1.18, 0.2, 0.1), STEEL, ME, x, y, z, 0, 0, 120, o),
		P(T, CY, V(0.16, d * 0.3, d * 0.3), ORNG, NE, x, y, z + 0.04, 0, 90, 0),
	}
end
S({ Id = "MaintenanceGuy_Legendary", Character = "MaintenanceGuy", Rarity = "Legendary", Name = "Mega Mech Mechanic",
	Desc = "Brought a giant robot suit to a desk fight. Warranty void.",
	Outfit = { Shirt = MDARK, Pants = MDARK },
	HideFace = true, HideHair = true,
	Parts = join({
		-- casque de soudeur
		{ Limb = H, Asset = "MaintenanceGuy_Legendary_Helmet2", Size = V(1.8, 1.8, 1.8), Offset = CFrame.new(0, 0.16, 0.04), Color = MECH, Material = SP },
		R(H, V(1.2, 0.62, 0.42), MDARK, GL, 0, 0.1, -0.6, { Reflect = 0.3 }),
		P(H, B, V(0.9, 0.1, 0.05), ORNG, NE, 0, 0.14, -0.8, { Anim = { Pulse = 0.3, PulseSpeed = 4 } }),
		P(H, CY, V(0.14, 0.26, 0.26), STEEL, ME, -0.73, 0.22, -0.2),
		P(H, CY, V(0.14, 0.26, 0.26), STEEL, ME, 0.73, 0.22, -0.2),
		R(H, V(0.26, 0.22, 1.3), MECHD, ME, 0, 0.9, 0.08),
		P(H, B, V(1.1, 0.3, 0.4), MECHD, ME, 0, -0.5, -0.5),
		P(H, B, V(0.06, 0.8, 0.06), STEEL, ME, 0.5, 1.15, 0.35, 0, 0, -10),
		P(H, BA, V(0.18, 0.18, 0.18), C(255, 60, 40), NE, 0.57, 1.56, 0.35, { Anim = { Pulse = 0.6, PulseSpeed = 5 } }),
		-- plastron + réacteur
		P(T, B, V(2.2, 1.4, 0.3), MECH, SP, 0, 0.35, -0.62),
		P(T, B, V(1.6, 0.3, 0.22), MECHD, ME, 0, -0.5, -0.59),
		P(T, B, V(1.4, 0.24, 0.2), MECHD, ME, 0, -0.82, -0.58),
		P(T, CY, V(0.18, 0.82, 0.82), MECHD, ME, 0, 0.42, -0.82, 0, 90, 0),
		P(T, CY, V(0.1, 0.58, 0.58), CORE, NE, 0, 0.42, -0.9, 0, 90, 0, { Light = CORE, Anim = { Pulse = 0.35, PulseSpeed = 3, React = true } }),
		P(T, B, V(0.62, 0.08, 0.04), MDARK, ME, 0, 0.42, -0.96, { Anim = { Spin = 200, Axis = "Z", Seed = 51, React = true } }),
		P(T, B, V(0.08, 0.62, 0.04), MDARK, ME, 0, 0.42, -0.96, { Anim = { Spin = 200, Axis = "Z", Seed = 51, React = true } }),
		-- bande « danger » noire et jaune
		P(T, B, V(2.22, 0.2, 0.32), MDARK, SP, 0, 0.94, -0.62),
		P(T, B, V(0.12, 0.3, 0.04), MECH, SP, -0.7, 0.94, -0.79, 0, 0, 35),
		P(T, B, V(0.12, 0.3, 0.04), MECH, SP, -0.24, 0.94, -0.79, 0, 0, 35),
		P(T, B, V(0.12, 0.3, 0.04), MECH, SP, 0.24, 0.94, -0.79, 0, 0, 35),
		P(T, B, V(0.12, 0.3, 0.04), MECH, SP, 0.7, 0.94, -0.79, 0, 0, 35),
		-- châssis dorsal, cheminées, panneau CAUTION
		P(T, B, V(1.8, 1.9, 0.5), MECHD, ME, 0, 0.1, 0.78),
		P(T, CY, V(1.0, 0.32, 0.32), STEEL, ME, -0.62, 1.25, 0.9, 0, 0, 90, {
			Particles = { Kind = "Smoke", Color = C(90, 90, 100), Rate = 3, Speed = 2.5, Size = 0.5, Life = 1.2, Dir = "Top", React = true } }),
		P(T, CY, V(1.0, 0.32, 0.32), STEEL, ME, 0.62, 1.25, 0.9, 0, 0, 90, {
			Particles = { Kind = "Fire", Color = ORNG, Rate = 12, Speed = 3, Size = 0.6, Life = 0.5, Dir = "Top", TransformOnly = true } }),
		P(T, B, V(1.45, 0.36, 0.05), MDARK, SP, 0, -0.62, 1.05, { Text = { Text = "⚠ CAUTION ⚠", Font = "Black", Color = MECH, Face = "Back" } }),
		-- torche de soudure (main gauche) : étincelles
		P(LA, CY, V(0.55, 0.15, 0.15), STEEL, ME, 0, -1.22, -0.72, 0, 90, 0),
		P(LA, BA, V(0.2, 0.2, 0.2), CORE, NE, 0, -1.22, -1.02, {
			Particles = { Kind = "Spark", Color = C(255, 190, 70), Rate = 22, Speed = 7, Size = 0.22, Life = 0.4, Spread = 60, Accel = -25, Dir = "Front", React = true } }),
	},
	gear(0.36, 0.25, 1.08, 1.25, 90, 52),
	gear(-0.5, -0.38, 1.1, 0.82, -140, 53),
	-- bras blindés : épaulières, vérins, gantelets à liseré néon
	sym(LA, RA, function(l, s)
		return {
			R(l, V(1.6, 1.15, 1.55), MECH, SP, 0.15 * s, 0.85, 0),
			P(l, B, V(1.2, 0.7, 1.2), MECHD, ME, 0, 0.12, 0),
			P(l, CY, V(0.9, 0.14, 0.14), STEEL, ME, 0.64 * s, 0.05, 0, 0, 0, 90),
			P(l, B, V(1.4, 1.05, 1.4), MECH, SP, 0, -0.6, 0),
			P(l, B, V(1.42, 0.1, 1.42), ORNG, NE, 0, -0.26, 0, { Anim = { Pulse = 0.4, PulseSpeed = 3, React = true } }),
			P(l, B, V(1.15, 0.45, 1.15), MECHD, ME, 0, -1.22, 0),
		}
	end),
	-- jambes blindées
	sym(LL, RL, function(l)
		return {
			P(l, B, V(1.2, 0.8, 1.2), MECHD, ME, 0, 0.45, 0),
			P(l, B, V(1.3, 1.0, 1.3), MECH, SP, 0, -0.32, 0),
			P(l, B, V(0.95, 0.28, 0.2), ORNG, NE, 0, 0.1, -0.62),
			P(l, B, V(1.4, 0.45, 1.7), MDARK, ME, 0, -0.8, -0.15),
			P(l, B, V(1.32, 0.08, 1.32), ORNG, NE, 0, -0.54, 0),
		}
	end)),
	FX = { PowerAura = ORNG, Light = CORE },
	Highlight = { Outline = ORNG },
	HitColor = ORNG,
})

-- ===================== MARKETING GURU =====================
-- pièce 3D générée (ReplicatedStorage.SkinAssets), texture d'origine conservée sauf opt.Color
local function A(limb, asset, size, x, y, z, rx, ry, rz, opt)
	local t = { Limb = limb, Asset = asset, Size = size,
		Offset = CFrame.new(x or 0, y or 0, z or 0) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0)) }
	if opt then
		for k, v in pairs(opt) do
			t[k] = v
		end
	end
	return t
end
local BOMBER, JOG = C(30, 30, 40), C(95, 95, 108)

S({ Id = "MarketingGuru_Rare", Character = "MarketingGuru", Rarity = "Rare", Name = "Hashtag Hustler",
	Desc = "Personal brand: 100%. Actual work: to be determined.",
	Outfit = { Shirt = BOMBER, Pants = JOG },
	HideHair = true,
	Parts = join({
		-- casquette snapback + lunettes néon + cheveux
		R(H, V(1.36, 0.58, 1.4), MAG, SP, 0, 0.64, 0.04),
		P(H, B, V(1.04, 0.06, 0.62), BLK, SP, 0, 0.42, -0.86),
		R(H, V(0.16, 0.1, 0.16), BLK, SP, 0, 0.94, 0.04),
		P(H, B, V(0.42, 0.32, 0.05), CYAN, NE, 0, 0.66, -0.68, -15, 0, 0, { Text = { Text = "#", Font = "Black", Color = DARK } }),
		P(H, B, V(1.26, 0.26, 0.08), CYAN, NE, 0, 0.12, -0.64, { Transparency = 0.15 }),
		P(H, B, V(1.32, 0.06, 0.09), WHT, SP, 0, 0.27, -0.64),
		R(H, V(1.3, 0.42, 0.9), C(40, 30, 25), SP, 0, 0.42, 0.25),
		-- « # » néon qui tourne au-dessus de la tête
		P(H, B, V(0.1, 0.62, 0.1), MAG, NE, -0.13, 1.75, 0, 0, 0, -10, { Anim = { Circle = 2, Bob = 0.12, Seed = 61 } }),
		P(H, B, V(0.1, 0.62, 0.1), MAG, NE, 0.13, 1.75, 0, 0, 0, -10, { Anim = { Circle = 2, Bob = 0.12, Seed = 61 } }),
		P(H, B, V(0.62, 0.1, 0.1), MAG, NE, 0.03, 1.88, 0, { Anim = { Circle = 2, Bob = 0.12, Seed = 61 } }),
		P(H, B, V(0.62, 0.1, 0.1), MAG, NE, -0.03, 1.62, 0, { Anim = { Circle = 2, Bob = 0.12, Seed = 61 } }),
		-- col côtelé du bomber, téléphone (main droite)
		P(T, B, V(1.1, 0.14, 0.8), MAG, SP, 0, 1.04, 0.05),
		P(RA, B, V(0.5, 0.85, 0.08), DARK, SP, 0, -1.15, -0.55, -20, 0, 0),
		P(RA, B, V(0.44, 0.76, 0.03), C(255, 60, 140), NE, 0, -1.15, -0.6, -20, 0, 0, { Text = { Text = "♥ 1.2M", Font = "Black", Color = WHT } }),
	},
	sym(LA, RA, function(l)
		return { P(l, B, V(1.07, 0.18, 1.07), MAG, SP, 0, -0.68, 0) }
	end),
	-- jogging + baskets montantes
	sym(LL, RL, function(l)
		return {
			P(l, B, V(1.05, 0.2, 1.05), C(60, 60, 70), SP, 0, -0.55, 0),
			P(l, B, V(1.06, 0.38, 1.1), WHT, SP, 0, -0.8, -0.05),
			R(l, V(1.04, 0.38, 0.55), WHT, SP, 0, -0.82, -0.55),
			P(l, B, V(1.1, 0.12, 1.34), DARK, SP, 0, -0.96, -0.12),
		}
	end)),
	Paint = {
		face(T, "Front", {
			bx(0.5, 0.55, 0.4, 1.1, WHT),
			tx(0.5, 0.45, 0.36, 0.12, "#HUSTLE", MAG, "Black"),
			tx(0.5, 0.57, 0.16, 0.1, "♥", MAG, "Black"),
			bx(0.42, 0.18, 0.02, 0.24, GOLD, { Rotation = -30 }), bx(0.58, 0.18, 0.02, 0.24, GOLD, { Rotation = 30 }),
			ci(0.5, 0.31, 0.07, 0.07, GOLD),
			bx(0.29, 0.5, 0.025, 1, CHROME), bx(0.71, 0.5, 0.025, 1, CHROME),
			ci(0.16, 0.3, 0.15, 0.15, MAG), tx(0.16, 0.3, 0.12, 0.12, "#", WHT, "Black"),
			bx(0.5, 0.95, 1, 0.1, MAG),
		}),
		face(T, "Back", {
			tx(0.5, 0.36, 0.55, 0.5, "#", MAG, "Black"),
			tx(0.5, 0.7, 0.8, 0.14, "HUSTLE", WHT, "Black"),
			bx(0.5, 0.95, 1, 0.1, MAG),
		}),
		face(LA, "Left", { bx(0.5, 0.5, 0.14, 1, MAG), bx(0.68, 0.5, 0.04, 1, WHT) }),
		face(RA, "Right", { bx(0.5, 0.5, 0.14, 1, MAG), bx(0.32, 0.5, 0.04, 1, WHT) }),
		face(LL, "Left", { bx(0.5, 0.5, 0.1, 1, WHT) }),
		face(RL, "Right", { bx(0.5, 0.5, 0.1, 1, WHT) }),
	},
})

local BLAZER, BLAZERD = C(210, 30, 160), C(150, 15, 115)
local tick = {}
for i, w in ipairs({ "GRIND", "HUSTLE", "SYNERGY", "GRIND", "HUSTLE", "SYNERGY" }) do
	local a = (i - 1) * 60
	local an = { Circle = 0.9, Bob = 0.08, Seed = 62 }
	tick[#tick + 1] = ring(H, B, V(0.95, 0.34, 0.06), C(18, 14, 26), SP, 1.36, 1.3, a, { Text = { Text = w, Font = "Black", Color = CYAN }, Anim = an }, -90)
	tick[#tick + 1] = ring(H, B, V(1.02, 0.42, 0.04), MAG, NE, 1.31, 1.3, a, { Anim = an }, -90)
end
S({ Id = "MarketingGuru_Epic", Character = "MarketingGuru", Rarity = "Epic", Name = "Hype Coach Live",
	Desc = "Let's GOOOO! (to the 3pm meeting about the 4pm meeting)",
	Outfit = { Shirt = BLAZER, Pants = C(25, 25, 32), ArmsSkin = true },
	HideHair = true,
	Parts = join(tick, {
		-- banane + micro-casque
		R(H, V(1.3, 0.5, 1.25), C(35, 25, 20), SP, 0, 0.6, 0.1),
		R(H, V(1.1, 0.45, 0.6), C(35, 25, 20), SP, 0, 0.8, -0.32, -20, 0, 0),
		P(H, CY, V(0.14, 0.38, 0.38), DARK, SP, 0.68, 0.05, 0),
		P(H, B, V(0.06, 0.55, 0.08), DARK, SP, 0.67, 0.38, 0),
		P(H, B, V(0.05, 0.05, 0.62), DARK, SP, 0.56, -0.12, -0.36, 0, -28, 0),
		R(H, V(0.15, 0.15, 0.15), CYAN, NE, 0.4, -0.2, -0.64),
		-- lunettes néon sur la banane + bandeau LIVE (transformation)
		P(H, B, V(1.1, 0.16, 0.06), CYAN, NE, 0, 0.92, -0.5, -25, 0, 0, { Transparency = 0.1 }),
		P(H, B, V(1.16, 0.04, 0.07), WHT, SP, 0, 1.0, -0.47, -25, 0, 0),
		P(H, B, V(2.6, 0.6, 0.1), C(255, 40, 90), NE, 0, 2.15, 0, { Transform = true,
			Text = { Text = "LET'S GOOO!", Font = "Bangers", Color = WHT, Face = "Both", Blink = 2 }, Anim = { Float = true, Seed = 66, React = true } }),
		-- col du tee, revers du blazer
		P(T, B, V(1.05, 0.12, 0.75), BLK, SP, 0, 1.04, 0),
		P(T, B, V(0.34, 1.0, 0.05), BLAZERD, SP, -0.3, 0.5, -0.53, 0, 0, 15),
		P(T, B, V(0.34, 1.0, 0.05), BLAZERD, SP, 0.3, 0.5, -0.53, 0, 0, -15),
		-- montre en or (poignet gauche)
		P(LA, B, V(1.07, 0.14, 1.07), GOLD, ME, 0, -0.62, 0),
		P(LA, B, V(0.32, 0.22, 0.05), CYAN, NE, 0, -0.62, -0.56),
		-- mégaphone (main droite, v4 : objet tenu)
		P(RA, CY, V(0.8, 0.36, 0.36), WHT, SP, 0, -1.05, -0.72, 0, 90, 0),
		P(RA, CY, V(0.14, 0.78, 0.78), MAG, SP, 0, -1.05, -1.16, 0, 90, 0),
	},
	-- manches remontées
	sym(LA, RA, function(l)
		return {
			P(l, B, V(1.06, 1.2, 1.06), BLAZER, SP, 0, 0.4, 0),
			P(l, B, V(1.1, 0.26, 1.1), BLAZERD, SP, 0, -0.17, 0),
		}
	end),
	-- baskets LED
	sym(LL, RL, function(l)
		return {
			P(l, B, V(1.06, 0.38, 1.1), WHT, SP, 0, -0.8, -0.05),
			R(l, V(1.04, 0.38, 0.55), WHT, SP, 0, -0.82, -0.55),
			P(l, B, V(1.1, 0.12, 1.34), CYAN, NE, 0, -0.96, -0.12, { Anim = { Pulse = 0.45, PulseSpeed = 5 }, Trail = { Color = MAG, Width = 0.3 } }),
			P(l, B, V(1.08, 0.07, 0.9), MAG, NE, 0, -0.72, -0.1),
		}
	end)),
	Paint = {
		face(T, "Front", {
			bx(0.5, 0.35, 0.36, 0.7, BLK), bx(0.5, 0.0, 0.36, 0.36, BLK, { Rotation = 45 }),
			bx(0.43, 0.3, 0.02, 0.42, CYAN, { Rotation = -12 }), bx(0.57, 0.3, 0.02, 0.42, CYAN, { Rotation = 12 }),
			bx(0.5, 0.56, 0.22, 0.14, WHT, { Corner = 0.25 }),
			tx(0.5, 0.56, 0.19, 0.08, "SPEAKER", MAG, "Black"),
			ci(0.5, 0.8, 0.06, 0.06, GOLD),
			bx(0.8, 0.3, 0.16, 0.07, CYAN),
			bx(0.2, 0.75, 0.22, 0.03, BLAZERD), bx(0.8, 0.75, 0.22, 0.03, BLAZERD),
		}),
		face(T, "Back", {
			bx(0.5, 0.3, 0.9, 0.2, BLK, { Corner = 0.3 }),
			tx(0.5, 0.3, 0.85, 0.16, "LET'S GOOO!", CYAN, "Black"),
		}),
		face(LL, "Left", { bx(0.5, 0.5, 0.08, 1, CYAN) }),
		face(RL, "Right", { bx(0.5, 0.5, 0.08, 1, CYAN) }),
	},
	FX = { HandTrails = CYAN },
	Highlight = { Outline = MAG },
	HitColor = MAG,
})

local COAT = C(22, 20, 32)
local boards = {}
for i, b in ipairs({ { "BUY NOW", CYAN }, { "50% OFF", GOLD }, { "LIKE & SHARE", MAG } }) do
	local a = (i - 1) * 120
	local an = { Circle = 0.55, Bob = 0.18, Seed = 63 }
	boards[#boards + 1] = ring(T, B, V(1.5, 0.85, 0.06), C(15, 10, 25), SP, 2.6, 0.9, a, { Text = { Text = b[1], Font = "Black", Color = b[2] }, Anim = an }, -90)
	boards[#boards + 1] = ring(T, B, V(1.64, 0.99, 0.04), b[2], NE, 2.56, 0.9, a, { Anim = an }, -90)
	boards[#boards + 1] = ring(T, B, V(0.08, 0.7, 0.08), CHROME, ME, 2.58, 0.15, a, { Anim = an }, -90)
end
local qr = { bx(0.5, 0.45, 0.38, 0.38, WHT) }
for _, q in ipairs({ { 0.36, 0.31 }, { 0.64, 0.31 }, { 0.36, 0.59 } }) do
	qr[#qr + 1] = bx(q[1], q[2], 0.08, 0.08, BLK, { Stroke = { BLK, 2 } })
	qr[#qr + 1] = bx(q[1], q[2], 0.035, 0.035, WHT)
end
for _, q in ipairs({ { 0.47, 0.33 }, { 0.53, 0.38 }, { 0.45, 0.45 }, { 0.58, 0.47 }, { 0.5, 0.52 }, { 0.62, 0.58 }, { 0.55, 0.6 }, { 0.47, 0.6 }, { 0.65, 0.42 } }) do
	qr[#qr + 1] = bx(q[1], q[2], 0.04, 0.04, BLK)
end
for _, e in ipairs({
	tx(0.5, 0.71, 0.4, 0.09, "SCAN ME", CYAN, "Black"),
	bx(0.13, 0.5, 0.02, 0.8, MAG), bx(0.87, 0.5, 0.02, 0.8, CYAN),
	bx(0.19, 0.3, 0.12, 0.02, MAG), bx(0.81, 0.62, 0.12, 0.02, CYAN),
	ci(0.25, 0.3, 0.035, 0.035, MAG), ci(0.75, 0.62, 0.035, 0.035, CYAN),
	bx(0.5, 0.88, 0.02, 0.24, CHROME),
}) do
	qr[#qr + 1] = e
end
S({ Id = "MarketingGuru_Legendary", Character = "MarketingGuru", Rarity = "Legendary", Name = "Ad Overlord",
	Desc = "This skin is sponsored by... this skin. Skip ad in 5... 4...",
	Outfit = { Shirt = COAT, Pants = COAT },
	HideFace = true, HideHair = true,
	Parts = join(boards, {
		-- cheveux platine plaqués + visière AR
		R(H, V(1.34, 0.44, 1.38), C(230, 232, 240), SP, 0, 0.62, 0.08),
		R(H, V(1.12, 0.32, 0.55), C(230, 232, 240), SP, 0, 0.74, -0.36, -18, 0, 0),
		P(H, B, V(1.3, 0.3, 0.08), CYAN, NE, 0, 0.12, -0.66, { Transparency = 0.12,
			Text = { Text = "BUY NOW • ", Font = "Code", Color = DARK, Scroll = 0.4, Width = 3 } }),
		P(H, B, V(0.08, 0.26, 0.62), CYAN, NE, -0.68, 0.12, -0.34, { Transparency = 0.12 }),
		P(H, B, V(0.08, 0.26, 0.62), CYAN, NE, 0.68, 0.12, -0.34, { Transparency = 0.12 }),
		P(H, B, V(1.38, 0.06, 0.1), DARK, ME, 0, 0.29, -0.66),
		P(H, CY, V(0.12, 0.3, 0.3), DARK, ME, -0.7, 0.12, 0),
		P(H, CY, V(0.12, 0.3, 0.3), DARK, ME, 0.7, 0.12, 0),
		-- col montant, pans du manteau
		P(T, B, V(1.6, 0.6, 0.14), COAT, SP, 0, 1.22, 0.48, -12, 0, 0),
		P(T, B, V(0.14, 0.5, 0.8), COAT, SP, -0.78, 1.18, 0.12),
		P(T, B, V(0.14, 0.5, 0.8), COAT, SP, 0.78, 1.18, 0.12),
		P(T, B, V(1.62, 0.06, 0.18), MAG, NE, 0, 1.52, 0.55, -12, 0, 0),
		P(T, B, V(2.06, 1.7, 0.08), COAT, SP, 0, -1.8, 0.54),
		P(T, B, V(2.08, 0.08, 0.1), CYAN, NE, 0, -2.62, 0.55),
		P(T, B, V(0.08, 1.6, 0.95), COAT, SP, -1.02, -1.78, 0.05),
		P(T, B, V(0.08, 1.6, 0.95), COAT, SP, 1.02, -1.78, 0.05),
		P(T, B, V(2.06, 0.16, 1.06), CHROME, ME, 0, -0.9, 0),
		P(T, B, V(0.36, 0.2, 0.05), CYAN, NE, 0, -0.9, -0.55),
		-- tablette holographique (main droite)
		P(RA, B, V(0.75, 0.5, 0.03), CYAN, NE, 0, -1.2, -0.75, -60, 0, 0, { Transparency = 0.35, Text = { Text = "SALE", Font = "Black", Color = WHT } }),
		-- drone caméra en orbite autour de la tête
		A(H, "MarketingGuru_Legendary_Drone", V(1.0, 0.4, 1.0), 1.9, 0.9, 0, 0, 90, 0, { Anim = { Circle = -1.1, Bob = 0.12, Seed = 64 } }),
		P(H, BA, V(0.14, 0.14, 0.14), RED, NE, 1.9, 1.14, 0, { Anim = { Circle = -1.1, Bob = 0.12, Seed = 64 } }),
		-- MEGA SALE (transformation)
		P(H, B, V(2.5, 0.8, 0.12), C(255, 40, 90), NE, 0, 2.2, 0, { Transform = true,
			Text = { Text = "MEGA SALE!", Font = "Bangers", Color = WHT, Face = "Both", Blink = 3 }, Anim = { Float = true, Seed = 65, React = true } }),
		P(H, B, V(1.5, 1.5, 0.06), GOLD, NE, 0, 2.2, 0.08, 0, 0, 45, { Transform = true, Anim = { Float = true, Seed = 65, React = true } }),
		P(H, B, V(1.5, 1.5, 0.06), C(255, 150, 30), NE, 0, 2.2, 0.1, { Transform = true, Anim = { Float = true, Seed = 65, React = true } }),
	},
	sym(LA, RA, function(l)
		return {
			P(l, B, V(1.15, 0.26, 1.15), CHROME, ME, 0, 0.94, 0),
			P(l, B, V(1.17, 0.06, 1.17), MAG, NE, 0, 0.8, 0),
			P(l, B, V(1.08, 0.1, 1.08), CYAN, NE, 0, -0.62, 0),
			P(l, B, V(1.05, 0.42, 1.05), BLK, SP, 0, -0.8, 0),
		}
	end),
	sym(LL, RL, function(l)
		return {
			P(l, B, V(1.06, 0.7, 1.08), C(15, 15, 22), SP, 0, -0.66, 0, { Reflect = 0.3 }),
			R(l, V(1.02, 0.4, 0.5), C(15, 15, 22), SP, 0, -0.82, -0.5),
			P(l, B, V(1.1, 0.1, 1.3), MAG, NE, 0, -0.96, -0.1, { Anim = { Pulse = 0.4, PulseSpeed = 4 } }),
		}
	end)),
	Paint = {
		face(H, "Front", { bx(0.58, 0.74, 0.22, 0.045, C(60, 20, 30), { Rotation = -10, Corner = 1 }) }),
		face(T, "Front", qr),
		face(T, "Back", {
			bx(0.13, 0.5, 0.02, 0.8, MAG), bx(0.87, 0.5, 0.02, 0.8, CYAN),
			bx(0.5, 0.3, 0.8, 0.18, C(10, 8, 18), { Stroke = { CYAN, 2 }, Corner = 0.2 }),
			tx(0.5, 0.3, 0.74, 0.13, "SKIP AD ▶", CYAN, "Black"),
		}),
		face(LA, "Left", { bx(0.5, 0.5, 0.06, 1, MAG) }),
		face(RA, "Right", { bx(0.5, 0.5, 0.06, 1, CYAN) }),
		face(LL, "Front", { bx(0.3, 0.4, 0.04, 0.8, MAG), bx(0.45, 0.8, 0.3, 0.04, MAG) }),
		face(RL, "Front", { bx(0.7, 0.4, 0.04, 0.8, CYAN), bx(0.55, 0.8, 0.3, 0.04, CYAN) }),
	},
	FX = { PowerAura = MAG, HandTrails = CYAN, Orbit = { Color = GOLD, Count = 5, Shape = "Block", Size = 0.25 } },
	Highlight = { Outline = CYAN },
	HitColor = MAG,
})

-- ===================== LAWYER =====================
local WIG, GOWN, PIN, BURG = C(242, 240, 232), C(22, 22, 28), C(55, 55, 62), C(125, 20, 45)
local function pinstripes(x0, x1, n, y, h, col)
	local els = {}
	for i = 0, n - 1 do
		els[#els + 1] = bx(x0 + (x1 - x0) * i / math.max(1, n - 1), y, 0.008, h, col)
	end
	return els
end
S({ Id = "Lawyer_Rare", Character = "Lawyer", Rarity = "Rare", Name = "Barrister Supreme",
	Desc = "Powdered wig. Unpowdered arguments. Bills by the second.",
	Outfit = { Shirt = GOWN, Pants = PIN },
	HideHair = true,
	Parts = join({
		-- perruque poudrée : rouleaux sur les côtés et derrière, queue + nœud noir
		R(H, V(1.44, 0.56, 1.46), WIG, SP, 0, 0.6, 0.06),
		P(H, CY, V(0.95, 0.3, 0.3), WIG, SP, -0.7, 0.3, 0.12, 0, 90, 0),
		P(H, CY, V(0.95, 0.3, 0.3), WIG, SP, 0.7, 0.3, 0.12, 0, 90, 0),
		P(H, CY, V(0.9, 0.3, 0.3), WIG, SP, -0.7, 0.0, 0.15, 0, 90, 0),
		P(H, CY, V(0.9, 0.3, 0.3), WIG, SP, 0.7, 0.0, 0.15, 0, 90, 0),
		P(H, CY, V(1.3, 0.3, 0.3), WIG, SP, 0, 0.3, 0.64),
		P(H, CY, V(1.3, 0.3, 0.3), WIG, SP, 0, 0.0, 0.64),
		P(H, B, V(0.18, 0.55, 0.18), WIG, SP, 0, -0.35, 0.72),
		P(H, B, V(0.5, 0.2, 0.07), BLK, SP, 0, -0.14, 0.8),
		-- rabats blancs + col cassé
		P(T, B, V(0.15, 0.45, 0.04), WHT, SP, -0.09, 0.72, -0.53),
		P(T, B, V(0.15, 0.45, 0.04), WHT, SP, 0.09, 0.72, -0.53),
		P(T, B, V(0.8, 0.14, 0.12), WHT, SP, 0, 0.98, -0.46),
		-- bas de la robe
		P(T, B, V(2.12, 0.8, 1.12), GOWN, FA, 0, -1.4, 0),
		-- mallette bordeaux (main gauche)
		P(LA, B, V(0.3, 0.85, 1.15), BURG, SP, 0, -1.55, -0.05),
		P(LA, B, V(0.1, 0.12, 0.42), DARK, SP, 0, -1.04, -0.05),
		P(LA, B, V(0.06, 0.12, 0.12), GOLD, ME, -0.17, -1.25, -0.3),
		P(LA, B, V(0.06, 0.12, 0.12), GOLD, ME, -0.17, -1.25, 0.2),
		-- v5 : maillet (main droite, manche dans le poing, tête cerclée d'or)
		P(RA, CY, V(1.0, 0.14, 0.14), C(120, 72, 40), WO, 0, -1.02, -0.45, 0, 90, 0),
		P(RA, CY, V(0.7, 0.3, 0.3), C(95, 55, 30), WO, 0, -1.02, -1.0),
		P(RA, CY, V(0.08, 0.32, 0.32), GOLD, ME, 0, -1.02, -1.0),
		-- v5 : broche balance de la justice (pan gauche de la robe)
		P(T, B, V(0.05, 0.34, 0.05), GOLD, ME, -0.6, 0.38, -0.53),
		P(T, B, V(0.38, 0.04, 0.05), GOLD, ME, -0.6, 0.54, -0.535),
		P(T, BA, V(0.12, 0.12, 0.12), GOLD, NE, -0.77, 0.46, -0.54),
		P(T, BA, V(0.12, 0.12, 0.12), GOLD, NE, -0.43, 0.46, -0.54),
	},
	sym(LA, RA, function(l)
		return { P(l, B, V(1.24, 1.0, 1.28), GOWN, FA, 0, -0.35, 0) }
	end),
	sym(LL, RL, function(l)
		return {
			P(l, B, V(1.04, 0.34, 1.1), BLK, SP, 0, -0.84, -0.05, { Reflect = 0.35 }),
			R(l, V(1.0, 0.34, 0.5), BLK, SP, 0, -0.85, -0.55, { Reflect = 0.35 }),
		}
	end)),
	Paint = {
		face(T, "Front", join({
			bx(0.5, 0.6, 0.42, 0.8, C(70, 70, 80)),
		}, pinstripes(0.33, 0.67, 6, 0.6, 0.8, C(125, 125, 135)), {
			bx(0.5, 0.08, 0.3, 0.3, WHT, { Rotation = 45 }),
			ci(0.5, 0.5, 0.04, 0.04, GOLD), ci(0.5, 0.64, 0.04, 0.04, GOLD), ci(0.5, 0.78, 0.04, 0.04, GOLD),
			bx(0.41, 0.66, 0.14, 0.015, GOLD, { Rotation = 15 }),
			bx(0.22, 0.5, 0.14, 1, C(10, 10, 14)), bx(0.78, 0.5, 0.14, 1, C(10, 10, 14)),
		})),
		face(T, "Back", pinstripes(0.2, 0.8, 5, 0.6, 0.8, C(10, 10, 14))),
		face(LL, "Front", pinstripes(0.2, 0.8, 4, 0.5, 1, C(85, 85, 95))),
		face(RL, "Front", pinstripes(0.2, 0.8, 4, 0.5, 1, C(85, 85, 95))),
	},
})

local ROBE, HAIRS = C(18, 18, 24), C(205, 200, 195)
S({ Id = "Lawyer_Epic", Character = "Lawyer", Rarity = "Epic", Name = "TV Judge",
	Desc = "Order in the break room! Case dismissed. You're all guilty.",
	Outfit = { Shirt = ROBE, Pants = ROBE },
	HideHair = true,
	Parts = join({
		-- grosses boucles argentées + demi-lunes dorées
		R(H, V(1.5, 0.7, 1.5), HAIRS, SP, 0, 0.66, 0.08),
		R(H, V(0.5, 0.5, 0.5), HAIRS, SP, -0.62, 0.28, 0.18),
		R(H, V(0.5, 0.5, 0.5), HAIRS, SP, 0.62, 0.28, 0.18),
		R(H, V(0.5, 0.5, 0.5), HAIRS, SP, -0.55, -0.05, 0.42),
		R(H, V(0.5, 0.5, 0.5), HAIRS, SP, 0.55, -0.05, 0.42),
		R(H, V(0.55, 0.55, 0.55), HAIRS, SP, 0, 0.25, 0.65),
		R(H, V(0.55, 0.5, 0.5), HAIRS, SP, 0, -0.08, 0.6),
		P(H, B, V(0.34, 0.15, 0.04), C(200, 230, 255), GL, -0.24, 0.0, -0.64, { Transparency = 0.4 }),
		P(H, B, V(0.34, 0.15, 0.04), C(200, 230, 255), GL, 0.24, 0.0, -0.64, { Transparency = 0.4 }),
		P(H, B, V(0.85, 0.04, 0.04), GOLD, ME, 0, 0.08, -0.65),
		-- jabot de dentelle + col
		R(T, V(0.62, 0.26, 0.16), WHT, SP, 0, 0.84, -0.55),
		R(T, V(0.52, 0.26, 0.18), WHT, SP, 0, 0.64, -0.56),
		R(T, V(0.4, 0.24, 0.18), WHT, SP, 0, 0.45, -0.57),
		P(T, B, V(1.1, 0.12, 0.8), WHT, SP, 0, 1.04, 0.04),
		P(T, B, V(2.14, 0.6, 1.14), ROBE, FA, 0, -1.28, 0),
		-- maillet géant dans le dos (scintille)
		{ Limb = T, Asset = "Lawyer_Epic_Gavel2", Size = V(1.2, 1.45, 2.7),
			Offset = CFrame.new(0, 0.15, 0.95) * CFrame.Angles(0, 0, rad(40)) * CFrame.Angles(0, rad(90), 0),
			Particles = { Kind = "Sparkle", Color = GOLD, Rate = 5, Speed = 1, Size = 0.3, Life = 0.9 } },
		-- ORDER! (transformation)
		P(H, B, V(2.2, 0.65, 0.1), GOLD, NE, 0, 1.95, 0, { Transform = true,
			Text = { Text = "ORDER!", Font = "Serif", Color = C(60, 10, 20), Face = "Both", Blink = 1.5 }, Anim = { Float = true, Seed = 71, React = true } }),
		P(H, B, V(2.35, 0.8, 0.06), C(90, 50, 25), WO, 0, 1.95, 0, { Transform = true, Anim = { Float = true, Seed = 71, React = true } }),
	},
	-- manches évasées à chevrons dorés
	sym(LA, RA, function(l)
		return {
			P(l, B, V(1.3, 1.0, 1.3), ROBE, FA, 0, -0.45, 0),
			P(l, B, V(1.32, 0.07, 1.32), GOLD, ME, 0, -0.2, 0),
			P(l, B, V(1.32, 0.07, 1.32), GOLD, ME, 0, -0.38, 0),
		}
	end),
	-- robe longue jusqu'aux chevilles
	sym(LL, RL, function(l)
		return {
			P(l, B, V(1.2, 0.4, 1.28), ROBE, FA, 0, -0.78, 0),
			P(l, B, V(1.22, 0.06, 1.3), GOLD, ME, 0, -0.6, 0),
			R(l, V(0.9, 0.28, 0.4), BLK, SP, 0, -0.88, -0.62),
		}
	end)),
	Paint = {
		face(H, "Front", {
			bx(0.36, 0.3, 0.17, 0.045, C(120, 115, 110), { Rotation = 12, Corner = 1 }),
			bx(0.64, 0.3, 0.17, 0.045, C(120, 115, 110), { Rotation = -12, Corner = 1 }),
		}),
		face(T, "Front", {
			bx(0.2, 0.6, 0.012, 0.8, C(45, 45, 55)), bx(0.33, 0.6, 0.012, 0.8, C(45, 45, 55)),
			bx(0.67, 0.6, 0.012, 0.8, C(45, 45, 55)), bx(0.8, 0.6, 0.012, 0.8, C(45, 45, 55)),
			bx(0.5, 0.6, 0.02, 0.8, GOLD),
		}),
		face(T, "Back", {
			bx(0.25, 0.6, 0.012, 0.8, C(45, 45, 55)), bx(0.5, 0.6, 0.012, 0.8, C(45, 45, 55)), bx(0.75, 0.6, 0.012, 0.8, C(45, 45, 55)),
			tx(0.5, 0.2, 0.7, 0.12, "HONORABLE", GOLD, "Serif"),
		}),
	},
	FX = { Spotlight = C(255, 235, 190) },
	Highlight = { Outline = GOLD },
	HitColor = GOLD,
})

local IVORY, CAPE = C(242, 236, 222), C(30, 26, 30)
local papers = {}
for i = 0, 7 do
	local a = i * 45
	local y = (i % 2 == 0) and 0.1 or 0.7
	local an = { Circle = 1.1, Bob = 0.2, Seed = 73 }
	papers[#papers + 1] = ring(T, B, V(0.55, 0.75, 0.03), C(250, 248, 240), SP, 2.3, y, a, { Anim = an }, -90)
	if i % 2 == 0 then
		papers[#papers + 1] = ring(T, CY, V(0.03, 0.16, 0.16), RED, SP, 2.33, y - 0.2, a, { Anim = an }, 0)
	end
end
S({ Id = "Lawyer_Legendary", Character = "Lawyer", Rarity = "Legendary", Name = "Supreme Closer",
	Desc = "Case closed. Building closed. Everything closed. OBJECTION sustained.",
	Outfit = { Shirt = IVORY, Pants = IVORY },
	HideFace = true, HideHair = true,
	Parts = join(papers, {
		-- cheveux plaqués + aviateurs dorées
		R(H, V(1.34, 0.42, 1.4), C(25, 22, 22), SP, 0, 0.62, 0.1, { Reflect = 0.2 }),
		R(H, V(1.15, 0.34, 0.55), C(25, 22, 22), SP, 0, 0.75, -0.34, -15, 0, 0, { Reflect = 0.2 }),
		P(H, B, V(0.44, 0.26, 0.05), C(210, 160, 40), GL, -0.25, 0.12, -0.64, { Reflect = 0.5, Transparency = 0.15 }),
		P(H, B, V(0.44, 0.26, 0.05), C(210, 160, 40), GL, 0.25, 0.12, -0.64, { Reflect = 0.5, Transparency = 0.15 }),
		P(H, B, V(0.92, 0.05, 0.06), GOLD, ME, 0, 0.22, -0.65),
		-- costume ivoire : revers et cravate dorés
		P(T, B, V(1.05, 0.12, 0.75), BLK, SP, 0, 1.04, 0),
		P(T, B, V(0.24, 0.95, 0.05), GOLD, SP, 0, 0.45, -0.535),
		P(T, B, V(0.3, 0.18, 0.07), GOLD, SP, 0, 0.9, -0.54),
		P(T, B, V(0.36, 1.1, 0.06), GOLD, ME, -0.44, 0.4, -0.53, 0, 0, 12, { Reflect = 0.3 }),
		P(T, B, V(0.36, 1.1, 0.06), GOLD, ME, 0.44, 0.4, -0.53, 0, 0, -12, { Reflect = 0.3 }),
		-- manteau porté sur les épaules
		P(T, B, V(2.5, 2.7, 0.08), CAPE, FA, 0, -0.45, 0.62),
		P(T, B, V(2.52, 0.08, 0.1), GOLD, NE, 0, -1.78, 0.63),
		-- mallette en or (main gauche)
		P(LA, B, V(0.32, 0.85, 1.2), GOLD, FO, 0, -1.55, -0.05, { Reflect = 0.4, Light = C(255, 210, 80),
			Particles = { Kind = "Sparkle", Color = C(255, 230, 140), Rate = 4, Speed = 1, Size = 0.25, Life = 1 } }),
		P(LA, B, V(0.1, 0.12, 0.45), DARK, SP, 0, -1.04, -0.05),
		P(LA, B, V(0.06, 0.12, 0.14), C(255, 240, 170), NE, -0.18, -1.25, -0.32),
		P(LA, B, V(0.06, 0.12, 0.14), C(255, 240, 170), NE, -0.18, -1.25, 0.22),
		-- balance de la justice flottante
		A(T, "Lawyer_Legendary_Scales", V(1.6, 1.6, 0.8), -1.95, 1.85, 0.3, 0, 0, 0, { Color = GOLD, Material = FO,
			Light = C(255, 210, 90), Anim = { Bob = 0.15, Seed = 72 } }),
		P(T, CY, V(0.06, 1.0, 1.0), C(255, 220, 120), NE, -1.95, 0.95, 0.3, 0, 0, 90, { Transparency = 0.3, Anim = { Bob = 0.15, Seed = 72 } }),
		-- OBJECTION! (transformation)
		P(H, B, V(2.5, 0.75, 0.12), WHT, SP, 0, 2.05, 0, { Transform = true,
			Text = { Text = "OBJECTION!", Font = "Bangers", Color = C(200, 20, 40), Face = "Both" }, Anim = { Float = true, React = true, Seed = 74 } }),
		P(H, B, V(1.7, 1.7, 0.06), GOLD, NE, 0, 2.05, 0.08, 0, 0, 45, { Transform = true, Anim = { Float = true, React = true, Seed = 74 } }),
		P(H, B, V(1.7, 1.7, 0.06), C(255, 90, 60), NE, 0, 2.05, 0.1, { Transform = true, Anim = { Float = true, React = true, Seed = 74 } }),
	},
	sym(LA, RA, function(l)
		return {
			P(l, B, V(1.2, 0.28, 1.25), CAPE, FA, 0, 0.92, 0),
			P(l, B, V(1.07, 0.16, 1.07), BLK, SP, 0, -0.7, 0),
			P(l, B, V(0.15, 0.15, 0.04), GOLD, NE, 0, -0.7, -0.55),
		}
	end),
	sym(LL, RL, function(l)
		return {
			P(l, B, V(1.04, 0.36, 1.1), C(250, 250, 250), SP, 0, -0.83, -0.05),
			R(l, V(1.02, 0.36, 0.5), BLK, SP, 0, -0.84, -0.55, { Reflect = 0.4 }),
			P(l, B, V(1.05, 0.3, 0.3), BLK, SP, 0, -0.85, 0.4),
		}
	end)),
	Paint = {
		face(H, "Front", {
			bx(0.36, 0.27, 0.18, 0.04, C(30, 25, 25), { Rotation = -4, Corner = 1 }),
			bx(0.64, 0.23, 0.18, 0.04, C(30, 25, 25), { Rotation = 14, Corner = 1 }),
			bx(0.53, 0.68, 0.3, 0.06, C(90, 30, 30), { Rotation = -6, Corner = 1 }),
			ci(0.64, 0.66, 0.05, 0.05, WHT),
		}),
		face(T, "Front", {
			bx(0.5, 0.28, 0.3, 0.56, BLK), bx(0.5, 0.0, 0.3, 0.3, BLK, { Rotation = 45 }),
			ci(0.5, 0.64, 0.045, 0.045, GOLD), ci(0.5, 0.8, 0.045, 0.045, GOLD),
			bx(0.8, 0.32, 0.16, 0.08, GOLD),
			bx(0.2, 0.78, 0.22, 0.03, C(200, 190, 170)), bx(0.8, 0.78, 0.22, 0.03, C(200, 190, 170)),
		}),
		face(LL, "Front", { bx(0.5, 0.45, 0.012, 0.9, C(215, 208, 190)) }),
		face(RL, "Front", { bx(0.5, 0.45, 0.012, 0.9, C(215, 208, 190)) }),
	},
	FX = { PowerAura = GOLD, Sparkles = C(255, 230, 140) },
	Highlight = { Outline = GOLD },
	HitColor = GOLD,
})

-- ===================== MASCOT =====================
local SAUS, BUN, CRUMB, MUST, KET = C(205, 85, 60), C(230, 170, 90), C(250, 220, 160), C(255, 215, 40), C(220, 35, 35)
local MRED, MBLUE = C(230, 45, 45), C(40, 90, 220)
local function mustard(x, rz)
	return P(H, B, V(0.1, 0.38, 0.06), MUST, SP, x, 1.35, -0.6, 0, 0, rz)
end
S({ Id = "Mascot_Rare", Character = "Mascot", Rarity = "Rare", Name = "Hot Dog Hero",
	Desc = "Relish the moment. Ketchup is extra.",
	Outfit = { Shirt = SAUS, Pants = SAUS },
	HideFace = true, HideHair = true,
	Parts = join({
		-- pain dans le dos (dépasse de chaque côté et au-dessus de la tête)
		R(T, V(4.6, 5.2, 1.1), BUN, SP, 0, 0.9, 0.8),
		R(T, V(4.3, 4.9, 0.4), CRUMB, SP, 0, 0.9, 0.36),
		-- capuche saucisse + moutarde
		R(H, V(1.48, 1.0, 1.48), SAUS, SP, 0, 0.68, 0.05),
		R(H, V(1.3, 1.6, 1.3), SAUS, SP, 0, 1.3, 0.1),
		mustard(-0.3, 50), mustard(-0.1, -50), mustard(0.1, 50), mustard(0.3, -50),
		-- bouteille de ketchup (main droite)
		P(RA, CY, V(0.75, 0.4, 0.4), KET, SP, 0, -1.3, -0.25, 0, 0, 90),
		P(RA, CY, V(0.25, 0.2, 0.2), WHT, SP, 0, -0.85, -0.25, 0, 0, 90),
		-- v5 : moutarde (main gauche) = duo de sauces
		P(LA, CY, V(0.75, 0.4, 0.4), MUST, SP, 0, -1.3, -0.25, 0, 0, 90),
		P(LA, CY, V(0.25, 0.2, 0.2), KET, SP, 0, -0.85, -0.25, 0, 0, 90),
		-- v5 : relish (trois dés verts entre les zigzags de moutarde)
		P(H, B, V(0.14, 0.14, 0.14), C(90, 175, 60), SP, -0.2, 1.62, -0.5, 20, 30, 0),
		P(H, B, V(0.14, 0.14, 0.14), C(90, 175, 60), SP, 0, 1.64, -0.52, 0, 45, 10),
		P(H, B, V(0.14, 0.14, 0.14), C(90, 175, 60), SP, 0.2, 1.62, -0.5, -15, 20, 0),
		-- v5 : calot de vendeur de hot-dogs (papier blanc, liseré rouge) posé sur la saucisse
		P(H, B, V(0.7, 0.3, 0.55), WHT, SP, 0, 2.08, 0.1),
		P(H, B, V(0.72, 0.07, 0.57), KET, SP, 0, 2.0, 0.1),
	},
	-- gants de mascotte
	sym(LA, RA, function(l)
		return { R(l, V(1.2, 0.6, 1.2), WHT, SP, 0, -0.8, 0) }
	end),
	sym(LL, RL, function(l)
		return {
			P(l, B, V(1.06, 0.38, 1.1), WHT, SP, 0, -0.8, -0.05),
			R(l, V(1.04, 0.38, 0.55), WHT, SP, 0, -0.82, -0.55),
			P(l, B, V(1.1, 0.12, 1.34), KET, SP, 0, -0.96, -0.12),
		}
	end)),
	Paint = {
		face(H, "Front", {
			bx(0.5, 0.42, 0.9, 0.2, KET, { Corner = 0.5 }),
			ci(0.36, 0.42, 0.13, 0.11, WHT), ci(0.64, 0.42, 0.13, 0.11, WHT),
			ci(0.38, 0.43, 0.05, 0.06, BLK), ci(0.62, 0.43, 0.05, 0.06, BLK),
			bx(0.5, 0.7, 0.3, 0.08, C(80, 20, 20), { Corner = 1 }),
			ci(0.25, 0.62, 0.1, 0.07, C(255, 140, 140), { Transparency = 0.4 }), ci(0.75, 0.62, 0.1, 0.07, C(255, 140, 140), { Transparency = 0.4 }),
		}),
		face(T, "Front", {
			ci(0.5, 0.4, 0.42, 0.42, MUST, { Stroke = { KET, 4 } }),
			tx(0.5, 0.4, 0.3, 0.25, "HD", KET, "Bangers"),
			bx(0.2, 0.8, 0.24, 0.05, MUST, { Rotation = 30, Corner = 1 }), bx(0.4, 0.8, 0.24, 0.05, MUST, { Rotation = -30, Corner = 1 }),
			bx(0.6, 0.8, 0.24, 0.05, MUST, { Rotation = 30, Corner = 1 }), bx(0.8, 0.8, 0.24, 0.05, MUST, { Rotation = -30, Corner = 1 }),
		}),
	},
})

local HAIRB = C(25, 25, 40)
local function pow(size, col, z, rz, extra)
	local o = { Transform = true, Anim = { Float = true, Seed = 81, React = true } }
	if extra then
		o = with(o, extra)
	end
	return P(H, B, size, col, NE, 0, 1.95, z, 0, 0, rz, o)
end
S({ Id = "Mascot_Epic", Character = "Mascot", Rarity = "Epic", Name = "Super Mascot",
	Desc = "Faster than a speeding T-shirt cannon. Weakness: stairs.",
	Outfit = { Shirt = MBLUE, Pants = MBLUE },
	HideFace = true, HideHair = true,
	Parts = join({
		-- coiffure de héros + mèche
		R(H, V(1.38, 0.48, 1.42), HAIRB, SP, 0, 0.62, 0.06),
		R(H, V(0.22, 0.34, 0.12), HAIRB, SP, 0.12, 0.5, -0.64, 0, 0, 30),
		-- cape + col + fermoirs + emblème
		P(T, B, V(1.9, 0.4, 0.15), MRED, FA, 0, 1.15, 0.45, -15, 0, 0),
		P(T, B, V(2.3, 3.3, 0.08), MRED, FA, 0, -0.6, 0.68, -6, 0, 0),
		P(T, B, V(0.95, 0.95, 0.05), MUST, SP, 0, 0.25, 0.665, -6, 0, 0, { Text = { Text = "M", Font = "Bangers", Color = MRED, Face = "Back" } }),
		R(T, V(0.28, 0.28, 0.12), MUST, ME, -0.72, 0.82, -0.52),
		R(T, V(0.28, 0.28, 0.12), MUST, ME, 0.72, 0.82, -0.52),
		-- ceinture
		P(T, B, V(2.06, 0.22, 1.06), MUST, SP, 0, -0.86, 0),
		P(T, B, V(0.45, 0.32, 0.06), MRED, SP, 0, -0.86, -0.55, { Text = { Text = "M", Font = "Bangers", Color = MUST } }),
		-- POW! (transformation)
		pow(V(1.9, 0.75, 0.1), MUST, 0, 0, { Text = { Text = "POW!", Font = "Bangers", Color = MRED, Face = "Both" } }),
		pow(V(1.5, 1.5, 0.06), MRED, 0.08, 45),
		pow(V(1.5, 1.5, 0.06), C(255, 140, 30), 0.1, 0),
	},
	-- gants cartoon + brassards
	sym(LA, RA, function(l)
		return {
			R(l, V(1.28, 0.8, 1.28), MRED, SP, 0, -0.72, 0),
			P(l, B, V(1.2, 0.22, 1.2), MUST, SP, 0, -0.3, 0),
			P(l, B, V(1.08, 0.12, 1.08), MUST, SP, 0, 0.55, 0),
		}
	end),
	-- slip rouge + bottes
	sym(LL, RL, function(l)
		return {
			P(l, B, V(1.06, 0.6, 1.06), MRED, SP, 0, 0.7, 0),
			P(l, B, V(1.08, 0.95, 1.1), MRED, SP, 0, -0.52, 0),
			P(l, B, V(1.14, 0.14, 1.16), MUST, SP, 0, -0.02, 0),
			R(l, V(1.04, 0.42, 0.52), MRED, SP, 0, -0.82, -0.52),
			P(l, B, V(1.1, 0.1, 1.32), C(60, 15, 15), SP, 0, -0.96, -0.12),
		}
	end)),
	Paint = {
		face(H, "Front", {
			bx(0.5, 0.42, 0.86, 0.2, BLK, { Corner = 0.6 }),
			ci(0.36, 0.42, 0.14, 0.1, WHT), ci(0.64, 0.42, 0.14, 0.1, WHT),
			bx(0.36, 0.28, 0.16, 0.04, HAIRB, { Rotation = -12, Corner = 1 }),
			bx(0.64, 0.28, 0.16, 0.04, HAIRB, { Rotation = 12, Corner = 1 }),
			bx(0.5, 0.69, 0.32, 0.1, C(90, 20, 20), { Corner = 0.6 }),
			bx(0.5, 0.665, 0.26, 0.04, WHT, { Corner = 0.3 }),
		}),
		face(T, "Front", {
			bx(0.5, 0.42, 0.5, 0.42, MUST, { Corner = 0.3, Stroke = { MRED, 4 } }),
			tx(0.5, 0.42, 0.36, 0.34, "M", MRED, "Bangers"),
			bx(0.3, 0.74, 0.2, 0.02, C(30, 70, 190)), bx(0.7, 0.74, 0.2, 0.02, C(30, 70, 190)),
		}),
	},
	FX = { HandTrails = MUST },
	Highlight = { Outline = MUST },
	HitColor = MUST,
})

local JERSEY, FUR = C(30, 40, 95), C(220, 40, 40)
local function jumbo(shape, size, col, mat, x, y, z, opt)
	local o = { Anim = { Bob = 0.15, Seed = 91 } }
	if opt then
		o = with(o, opt)
		o.Anim = with({ Bob = 0.15, Seed = 91 }, opt.Anim or {})
	end
	return P(T, shape, size, col, mat, x, y, z, 0, 25, 0, o)
end
local function cannon(shape, size, col, mat, x, y, z, opt)
	return P(T, shape, size, col, mat, x, y, z, 0, 90, 0, with({ Transform = true }, opt or {}))
end
S({ Id = "Mascot_Legendary", Character = "Mascot", Rarity = "Legendary", Name = "Halftime Legend",
	Desc = "The crowd goes WILD. The office goes WILDER. Jumbotron included.",
	Outfit = { Shirt = JERSEY, Pants = FUR },
	HideFace = true, HideHair = true,
	Parts = join({
		-- tête de bouledogue géante (mesh généré)
		A(H, "Mascot_Legendary_Head", V(2.4, 2.25, 2.2), 0, 0.55, -0.05),
		P(T, B, V(1.1, 0.14, 0.8), MUST, SP, 0, 1.04, 0.04),
		-- doigt en mousse « #1 » (main droite)
		P(RA, B, V(0.95, 0.9, 0.6), MRED, SP, 0, -1.25, -0.55, { Text = { Text = "#1", Font = "Bangers", Color = MUST } }),
		P(RA, B, V(0.32, 1.0, 0.32), MRED, SP, 0.15, -0.35, -0.6),
		-- queue
		R(T, V(0.45, 0.45, 0.8), FUR, FA, 0, -0.95, 0.7, { Anim = { Swing = 20, SwingAxis = "Y", SwingSpeed = 5 } }),
		-- écran géant flottant
		jumbo(B, V(2.6, 1.45, 0.14), C(15, 15, 22), SP, -2.7, 2.3, 0.9, { Text = { Text = "MAKE SOME NOISE!!!  ", Font = "Bangers", Color = MUST,
			Scroll = 0.3, Width = 3.5, Face = "Both" } }),
		jumbo(B, V(2.8, 1.65, 0.1), MRED, NE, -2.7, 2.3, 0.94),
		jumbo(B, V(2.8, 0.14, 0.2), C(40, 40, 50), ME, -2.7, 3.18, 0.92),
		jumbo(BA, V(0.22, 0.22, 0.22), MUST, NE, -3.61, 3.32, 1.34, { Anim = { Pulse = 0.6, PulseSpeed = 6 } }),
		jumbo(BA, V(0.22, 0.22, 0.22), C(80, 230, 255), NE, -2.7, 3.32, 0.92, { Anim = { Pulse = 0.6, PulseSpeed = 7 } }),
		jumbo(BA, V(0.22, 0.22, 0.22), MUST, NE, -1.79, 3.32, 0.5, { Anim = { Pulse = 0.6, PulseSpeed = 5 } }),
		-- feux d'artifice + confettis
		P(T, B, V(0.2, 0.2, 0.2), MUST, SP, 0, 3.4, 0, { Transparency = 1,
			Particles = { Kind = "Spark", Color = MUST, Rate = 10, Speed = 7, Size = 0.4, Life = 0.7, Spread = 180, Accel = -8, React = true } }),
		P(T, B, V(0.2, 0.2, 0.2), CYAN, SP, 0, 3.4, 0, { Transparency = 1,
			Particles = { Kind = "Spark", Color = CYAN, Rate = 8, Speed = 7, Size = 0.4, Life = 0.7, Spread = 180, Accel = -8, React = true } }),
		P(T, B, V(0.2, 0.2, 0.2), MAG, SP, 0, 3.4, 0, { Transparency = 1,
			Particles = { Kind = "Sparkle", Color = MAG, Rate = 8, Speed = 4, Size = 0.3, Life = 1.2, Spread = 180, Accel = -4, React = true } }),
		-- canon à t-shirts sur l'épaule (transformation)
		cannon(CY, V(1.7, 0.5, 0.5), C(70, 70, 80), ME, 1.35, 1.26, -0.1),
		cannon(CY, V(0.9, 0.38, 0.38), MRED, SP, 1.35, 1.05, 0.45),
		cannon(CY, V(0.1, 0.6, 0.6), MUST, NE, 1.35, 1.26, -0.95, {
			Particles = { Kind = "Spark", Color = WHT, Rate = 10, Dir = "Front", Speed = 9, Size = 0.5, Life = 0.6, Spread = 15, TransformOnly = true } }),
	},
	-- épaulettes de football, manchettes en fourrure, gros gants
	sym(LA, RA, function(l, s)
		return {
			R(l, V(1.4, 0.7, 1.4), JERSEY, SP, 0.1 * s, 0.85, 0),
			P(l, B, V(1.08, 0.14, 1.08), MUST, SP, 0, 0.35, 0),
			P(l, B, V(1.2, 0.3, 1.2), FUR, FA, 0, -0.38, 0),
			R(l, V(1.35, 0.95, 1.35), WHT, SP, 0, -0.88, 0),
		}
	end),
	-- short, chaussettes, grands pieds poilus
	sym(LL, RL, function(l)
		return {
			P(l, B, V(1.08, 0.75, 1.08), MUST, SP, 0, 0.6, 0),
			P(l, B, V(1.1, 0.1, 1.1), JERSEY, SP, 0, 0.28, 0),
			P(l, B, V(1.06, 0.3, 1.06), WHT, SP, 0, -0.32, 0),
			P(l, B, V(1.08, 0.07, 1.08), JERSEY, SP, 0, -0.3, 0),
			R(l, V(1.4, 0.65, 2.0), FUR, FA, 0, -0.72, -0.35),
			P(l, B, V(1.3, 0.14, 1.8), WHT, SP, 0, -0.97, -0.3),
		}
	end)),
	Paint = {
		face(T, "Front", {
			bx(0.5, 0.02, 0.32, 0.32, MUST, { Rotation = 45 }),
			bx(0.5, 0.0, 0.22, 0.22, FUR, { Rotation = 45 }),
			tx(0.5, 0.3, 0.8, 0.16, "OFFICE", MUST, "Bangers"),
			tx(0.5, 0.64, 0.5, 0.44, "00", WHT, "Bangers"),
			bx(0.06, 0.5, 0.06, 1, MUST), bx(0.94, 0.5, 0.06, 1, MUST),
		}),
		face(T, "Back", {
			tx(0.5, 0.2, 0.8, 0.15, "LEGEND", MUST, "Bangers"),
			tx(0.5, 0.6, 0.7, 0.55, "00", WHT, "Bangers"),
			bx(0.06, 0.5, 0.06, 1, MUST), bx(0.94, 0.5, 0.06, 1, MUST),
		}),
	},
	FX = { PowerAura = MUST, Spotlight = C(255, 240, 200) },
	Highlight = { Outline = MUST },
	HitColor = MUST,
})

return L
