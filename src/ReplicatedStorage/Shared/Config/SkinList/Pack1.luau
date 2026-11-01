--[[
	SkinList.Pack1 (agent pack1) — skins v3 Rare / Epic / Legendary de Intern, Janitor, LunchLady, SecurityGuard.
	Chaque entrée REMPLACE l'entrée de même Id dans SkinList. Format : CONTRACT_SKINS + champs v3 de SkinBuilder
	(Mesh, Asset, Paint, HideFace, HideHair) + options avancées (Anim, Text, Transform, Trail, Particles, Light...).
	Principe : la couleur Outfit = le vêtement de base, Paint = les détails (coutures, poches, logos fictifs, rayures),
	les Parts fines = les couches 3D (manches, cols, chaussures, coiffes, accessoires héros).
	Repères R6 : tête 2x1x1 (visuel ~1,25, dessus ~+0,6, visage en -Z), buste 2x2x1 (avant -Z), membres 1x2x1 (main à y -1).
	Paint : Pos/Size en échelle 0..1 de la face (x de gauche à droite vu de face, y de haut en bas).
]]
local C, V = Color3.fromRGB, Vector3.new
local rad = math.rad
local SP, NE, GL, ME, FF, FA, FO, WO = "SmoothPlastic", "Neon", "Glass", "Metal", "ForceField", "Fabric", "Foil", "Wood"
local H, T, LA, RA, LL, RL = "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"
local B, BA, CY, WE = "Block", "Ball", "Cylinder", "Wedge"

-- fusionne des tables d'options
local function o(...)
	local t = {}
	for _, src in ipairs({ ... }) do
		for k, v in pairs(src) do
			t[k] = v
		end
	end
	return t
end
local SPH = { Mesh = { Type = "Sphere" } } -- ellipsoïde lisse (cheveux, casques, bouts de chaussures)

-- une pièce soudée à un membre (rotations en degrés)
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
-- paire symétrique : la 2e pièce (membre b) reçoit x, ry, rz inversés (côté extérieur = même signe visuel)
local function pair(a, b, shape, size, col, mat, x, y, z, rx, ry, rz, opt)
	if type(rx) == "table" then
		opt, rx = rx, nil
	end
	return {
		P(a, shape, size, col, mat, x, y, z, rx, ry, rz, opt),
		P(b, shape, size, col, mat, -(x or 0), y, z, rx, -(ry or 0), -(rz or 0), opt),
	}
end
-- miroir gauche/droite sur le même membre
local function mir(limb, shape, size, col, mat, x, y, z, rx, ry, rz, opt)
	return pair(limb, limb, shape, size, col, mat, x, y, z, rx, ry, rz, opt)
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

-- palette commune (déclarée avant faceKit qui utilise WHT)
local WHT, BLK, DARK, GOLD = C(245, 245, 245), C(20, 20, 25), C(35, 35, 42), C(255, 200, 40)
local RED, GREEN, CYAN, PINK = C(230, 35, 45), C(80, 255, 120), C(40, 230, 255), C(255, 80, 200)
local SIL = C(205, 210, 220)

-- Paint : éléments de SurfaceGui peints sur le corps
local function E(kind, x, y, w, h, col, opt)
	local e = { Type = kind, Pos = { x, y }, Size = { w, h }, Color = col }
	if opt then
		for k, v in pairs(opt) do
			e[k] = v
		end
	end
	return e
end
local function bx(x, y, w, h, col, opt)
	return E("Box", x, y, w, h, col, opt)
end
local function ci(x, y, w, h, col, opt)
	return E("Circle", x, y, w, h, col, opt)
end
local function tx(x, y, w, h, text, col, font, opt)
	local e = E("Text", x, y, w, h, col, opt)
	e.Text = text
	e.Font = font or "Black"
	return e
end
local function face(limb, f, els)
	return { Limb = limb, Face = f, Elements = els }
end
-- même dessin sur les deux faces extérieures des jambes (ou des bras)
local function outer(limbL, limbR, els)
	return face(limbL, "Left", els), face(limbR, "Right", els)
end

local function ln(x1, y1, x2, y2, w, col)
	return { Type = "Line", From = { x1, y1 }, To = { x2, y2 }, Width = w, Color = col }
end
-- visage cartoon peint sur Head Front (avec HideFace = true)
-- f = { Iris, Ink, Brow = "normal"|"angry"|"raised"|"happy"|"focus", BrowCol, BrowW, Mouth = "smile"|"grin"|"smirk"|"open"|"grit"|"flat"|"none",
--       NoEyes (lunettes en Parts), Lashes, Lips, Blush, Stubble, Mustache }
local function faceKit(f)
	f = f or {}
	local ink = f.Ink or C(30, 25, 30)
	local iris = f.Iris or C(70, 45, 30)
	local els = {}
	local function add(e)
		els[#els + 1] = e
	end
	if f.Stubble then
		add(ci(0.5, 0.76, 0.66, 0.34, f.Stubble, { Transparency = 0.6 }))
	end
	if f.Blush then
		add(ci(0.24, 0.62, 0.13, 0.07, f.Blush, { Transparency = 0.45 }))
		add(ci(0.76, 0.62, 0.13, 0.07, f.Blush, { Transparency = 0.45 }))
	end
	if not f.NoEyes then
		for _, x in ipairs({ 0.36, 0.64 }) do
			add(ci(x, 0.45, 0.15, 0.2, WHT, { Stroke = { ink, 2 } }))
			add(ci(x + 0.01, 0.47, 0.08, 0.12, iris))
			add(ci(x + 0.025, 0.44, 0.03, 0.04, WHT))
		end
		if f.Lashes then
			add(ln(0.27, 0.38, 0.23, 0.34, 3, ink))
			add(ln(0.73, 0.38, 0.77, 0.34, 3, ink))
		end
	end
	local bc, bw, brow = f.BrowCol or ink, f.BrowW or 5, f.Brow or "normal"
	if brow == "angry" then
		add(ln(0.25, 0.26, 0.45, 0.34, bw + 2, bc))
		add(ln(0.55, 0.34, 0.75, 0.26, bw + 2, bc))
	elseif brow == "focus" then
		add(ln(0.27, 0.29, 0.44, 0.32, bw, bc))
		add(ln(0.56, 0.32, 0.73, 0.29, bw, bc))
	elseif brow == "raised" then
		add(ln(0.27, 0.3, 0.44, 0.3, bw, bc))
		add(ln(0.56, 0.26, 0.73, 0.22, bw, bc))
	elseif brow == "happy" then
		add(ln(0.27, 0.27, 0.36, 0.23, bw, bc))
		add(ln(0.36, 0.23, 0.44, 0.27, bw, bc))
		add(ln(0.56, 0.27, 0.64, 0.23, bw, bc))
		add(ln(0.64, 0.23, 0.73, 0.27, bw, bc))
	else
		add(ln(0.27, 0.3, 0.43, 0.27, bw, bc))
		add(ln(0.57, 0.27, 0.73, 0.3, bw, bc))
	end
	if f.Mustache then
		add(bx(0.42, 0.63, 0.2, 0.08, f.Mustache, { Corner = 1, Rotation = 8 }))
		add(bx(0.58, 0.63, 0.2, 0.08, f.Mustache, { Corner = 1, Rotation = -8 }))
	end
	local m, lip = f.Mouth or "smile", f.Lips
	if m == "grin" then
		add(bx(0.5, 0.72, 0.3, 0.1, WHT, { Corner = 1, Stroke = { lip or ink, 3 } }))
	elseif m == "grit" then
		add(bx(0.5, 0.72, 0.32, 0.11, WHT, { Corner = 0.3, Stroke = { ink, 3 } }))
		add(bx(0.5, 0.72, 0.3, 0.012, ink))
		add(bx(0.43, 0.72, 0.012, 0.1, ink))
		add(bx(0.57, 0.72, 0.012, 0.1, ink))
	elseif m == "smirk" then
		add(ln(0.42, 0.73, 0.6, 0.69, 5, lip or ink))
	elseif m == "open" then
		add(ci(0.5, 0.72, 0.18, 0.15, C(110, 25, 35), { Stroke = { lip or ink, 3 } }))
		add(ci(0.5, 0.76, 0.1, 0.05, C(255, 120, 130)))
	elseif m == "flat" then
		add(bx(0.5, 0.72, 0.2, 0.05, lip or ink, { Corner = 1 }))
	elseif m ~= "none" then
		add(ln(0.4, 0.69, 0.5, 0.73, 5, lip or ink))
		add(ln(0.5, 0.73, 0.6, 0.69, 5, lip or ink))
	end
	return face(H, "Front", els)
end

local L = {}
local function S(def)
	def.HideIdentity = def.HideIdentity ~= false
	L[#L + 1] = def
end


-- ===================== INTERN =====================
do
	local OR, OR2, CREAM, INK = C(255, 145, 40), C(220, 105, 25), C(240, 232, 210), C(30, 30, 38)
	local CARGO = C(52, 56, 68)
	S({ Id = "Intern_Rare", Character = "Intern", Rarity = "Rare", Name = "Hypebeast Intern",
		Desc = "Limited-drop hoodie. Unlimited confidence. Zero experience.",
		Outfit = { Shirt = OR, Pants = CARGO, ArmsSkin = true },
		HideHair = true, HideFace = true,
		Parts = join({
			-- bob crème à bandeau noir
			P(H, CY, V(0.5, 1.34, 1.34), CREAM, FA, 0, 0.57, 0, 0, 0, 90),
			P(H, CY, V(0.13, 1.37, 1.37), INK, FA, 0, 0.39, 0, 0, 0, 90),
			P(H, B, V(1.95, 0.07, 1.95), CREAM, FA, 0, 0.33, 0, o(SPH)),
			-- lunettes miroir
			P(H, B, V(1.22, 0.24, 0.1), C(18, 18, 26), SP, 0, 0.1, -0.6, o(SPH, { Reflect = 0.08 })),
			P(H, B, V(1.28, 0.05, 0.12), GOLD, ME, 0, 0.23, -0.6),
			-- chaîne en or + pièce qui tourne
			P(T, CY, V(0.08, 0.36, 0.36), GOLD, FO, 0, 0.38, -0.6, 0, 90, 0, { Anim = { Spin = 140 } }),
			-- capuche baissée
			P(T, B, V(1.5, 0.55, 0.75), OR2, FA, 0, 1.0, 0.36, o(SPH)),
		}, mir(T, B, V(0.08, 0.62, 0.06), GOLD, FO, -0.18, 0.68, -0.53, 0, 0, 30),
		mir(T, B, V(0.06, 0.55, 0.06), WHT, SP, -0.17, 0.66, -0.535),
		-- manches de sweat oversize + poignets côtelés
		pair(LA, RA, B, V(1.07, 1.5, 1.07), OR, FA, 0, 0.25, 0),
		pair(LA, RA, B, V(1.11, 0.2, 1.11), OR2, FA, 0, -0.55, 0),
		-- chaussettes + baskets épaisses
		pair(LL, RL, B, V(1.04, 0.22, 1.04), WHT, FA, 0, -0.48, 0),
		pair(LL, RL, B, V(1.1, 0.42, 1.25), WHT, SP, 0, -0.79, -0.1),
		pair(LL, RL, B, V(1.15, 0.16, 1.36), OR, SP, 0, -0.95, -0.14),
		pair(LL, RL, B, V(1.08, 0.38, 0.5), WHT, SP, 0, -0.81, -0.68, o(SPH)),
		pair(LL, RL, B, V(0.04, 0.14, 0.75), INK, SP, -0.56, -0.76, -0.15)),
		Paint = {
			faceKit({ NoEyes = true, Brow = "raised", Mouth = "smirk" }),
			face(T, "Front", {
				bx(0.5, 0.83, 0.64, 0.22, OR2, { Corner = 0.3 }), -- poche kangourou
				bx(0.5, 0.83, 0.6, 0.02, C(190, 90, 20)),
				bx(0.5, 0.56, 0.56, 0.2, INK, { Corner = 0.25 }), -- logo fictif
				tx(0.5, 0.56, 0.5, 0.15, "HYPE", OR, "Black"),
				bx(0.5, 0.97, 1, 0.06, OR2), -- bas côtelé
			}),
			face(T, "Back", {
				bx(0.5, 0.42, 0.72, 0.3, CREAM, { Corner = 0.15 }),
				tx(0.5, 0.42, 0.66, 0.24, "HYPE", INK, "Black"),
				tx(0.5, 0.72, 0.8, 0.09, "LIMITED DROP", INK, "Black"),
				bx(0.5, 0.97, 1, 0.06, OR2),
			}),
			outer(LL, RL, {
				bx(0.5, 0.36, 0.7, 0.22, C(42, 46, 56), { Corner = 0.15 }), -- poche cargo
				bx(0.5, 0.27, 0.72, 0.05, C(35, 38, 48)),
				bx(0.5, 0.5, 0.08, 1, OR), -- passepoil
			}),
		},
	})

	local K, G, G2 = C(28, 30, 36), GREEN, C(40, 200, 95)
	local HOLO = C(15, 40, 25)
	local sync = { Bob = 0.12, Seed = 1 }
	S({ Id = "Intern_Epic", Character = "Intern", Rarity = "Epic", Name = "Speedrun Intern",
		Desc = "Any% coffee run. On world record pace. Do not talk to him.",
		Outfit = { Shirt = K, Pants = C(45, 48, 58), ArmsSkin = true },
		HideFace = true,
		Parts = join({
			-- bandeau éponge
			P(H, CY, V(0.22, 1.32, 1.32), G2, FA, 0, 0.3, 0, 0, 0, 90),
			P(H, CY, V(0.06, 1.34, 1.34), G, NE, 0, 0.3, 0, 0, 0, 90),
			-- col montant + liseré néon + tirette
			P(T, B, V(1.3, 0.24, 1.04), K, SP, 0, 1.1, 0),
			P(T, B, V(1.32, 0.04, 1.06), G, NE, 0, 1.22, 0),
			P(T, B, V(0.1, 0.2, 0.05), SIL, ME, 0, 0.75, -0.54),
			-- chrono hologramme flottant
			P(H, B, V(2.2, 0.62, 0.06), HOLO, GL, 0, 1.6, 0, { Transparency = 0.35,
				Text = { Text = "00:59.99", Color = G, Font = "Arcade", Face = "Both" }, Anim = sync }),
			P(H, B, V(2.32, 0.06, 0.1), G, NE, 0, 1.94, 0, { Anim = sync }),
			P(H, B, V(2.32, 0.06, 0.1), G, NE, 0, 1.26, 0, { Anim = sync }),
			P(H, B, V(1.4, 0.32, 0.05), GOLD, SP, 0, 2.2, 0, { Transparency = 1,
				Text = { Text = "WR PACE!", Color = GOLD, Font = "Black", Face = "Both", Blink = 2 }, Anim = sync }),
			P(H, B, V(1.0, 0.3, 0.05), HOLO, GL, 1.55, 1.05, 0, 0, -20, 0, { Transparency = 0.35,
				Text = { Text = "-0.42", Color = G, Font = "Arcade", Face = "Both" }, Anim = sync }),
			-- chronomètre en main
			P(RA, CY, V(0.14, 0.5, 0.5), SIL, ME, 0, -1.1, -0.45, 0, 90, 0),
			P(RA, CY, V(0.03, 0.4, 0.4), WHT, SP, 0, -1.1, -0.53, 0, 90, 0),
			P(RA, B, V(0.1, 0.12, 0.1), RED, NE, 0, -0.8, -0.45),
			-- sac d'hydratation de coureur (dos) + tuyau par-dessus l'épaule droite (v4 : silhouette de dos)
			P(T, B, V(1.15, 1.25, 0.42), K, SP, 0, 0.2, 0.7, o(SPH)),
			P(T, B, V(0.08, 0.95, 0.06), G, NE, 0, 0.2, 0.92),
			P(T, CY, V(1.1, 0.08, 0.08), G2, SP, 0.55, 1.04, 0.1, 0, 90, 0),
			-- transformation : panneau GOLD SPLIT
			P(H, B, V(1.8, 0.4, 0.05), GOLD, SP, 0, 2.6, 0, { Transform = true, Transparency = 1,
				Text = { Text = "GOLD SPLIT!", Color = GOLD, Font = "Arcade", Face = "Both", Blink = 4 }, Anim = sync }),
		},
		-- veste de survet' : manches + bandes néon + poignets lumineux
		pair(LA, RA, B, V(1.06, 1.45, 1.06), K, SP, 0, 0.275, 0),
		pair(LA, RA, B, V(0.04, 1.45, 0.16), G, NE, -0.54, 0.275, 0),
		pair(LA, RA, B, V(1.1, 0.26, 1.1), G, NE, 0, -0.6, 0),
		-- short de course sur legging
		pair(LL, RL, B, V(1.06, 0.85, 1.06), K, SP, 0, 0.575, 0),
		pair(LL, RL, B, V(0.04, 0.85, 0.18), G, NE, -0.55, 0.575, 0),
		-- runners blancs semelle néon (traînées)
		pair(LL, RL, B, V(1.1, 0.42, 1.25), C(240, 240, 245), SP, 0, -0.79, -0.1),
		pair(LL, RL, B, V(1.15, 0.13, 1.36), G, NE, 0, -0.96, -0.14, { Trail = { Color = G, Width = 0.35 } }),
		pair(LL, RL, B, V(1.08, 0.38, 0.5), C(240, 240, 245), SP, 0, -0.81, -0.68, o(SPH)),
		pair(LL, RL, B, V(0.5, 0.05, 0.42), K, SP, 0, -0.57, -0.4)),
		Paint = {
			faceKit({ Brow = "focus", Mouth = "smirk", Iris = C(30, 140, 70) }),
			face(T, "Front", {
				bx(0.3, 0.3, 0.09, 0.5, G, { Rotation = -40 }), bx(0.7, 0.3, 0.09, 0.5, G, { Rotation = 40 }), -- chevron de course
				bx(0.5, 0.42, 0.025, 0.84, C(170, 170, 180)), -- zip
				tx(0.25, 0.12, 0.3, 0.09, "ANY%", G, "Black"),
				bx(0.5, 0.74, 0.5, 0.26, WHT, { Corner = 0.1 }), -- dossard
				tx(0.5, 0.71, 0.42, 0.16, "WR", K, "Black"),
				tx(0.5, 0.83, 0.42, 0.05, "COFFEE RUN", K, "Black"),
				bx(0.03, 0.5, 0.06, 1, G2), bx(0.97, 0.5, 0.06, 1, G2),
			}),
			face(T, "Back", {
				tx(0.5, 0.3, 0.9, 0.18, "SPEED//RUN", G, "Black"),
				tx(0.5, 0.5, 0.7, 0.08, "ANY% NO COFFEE", WHT, "Black"),
				bx(0.5, 0.65, 0.8, 0.03, G),
			}),
			face(T, "Left", { bx(0.5, 0.5, 0.3, 1, G) }),
			face(T, "Right", { bx(0.5, 0.5, 0.3, 1, G) }),
			outer(LL, RL, { bx(0.5, 0.5, 0.14, 1, G2) }),
		},
		FX = { HandTrails = G },
		HitColor = G,
	})

	local JK, PK, CYN = C(24, 24, 32), C(255, 70, 190), C(40, 230, 255)
	local drone = { Circle = 1.1, Bob = 0.15, Seed = 2 }
	S({ Id = "Intern_Legendary", Character = "Intern", Rarity = "Legendary", Name = "Livestream Legend",
		Desc = "Smash that like button. Smash everything, actually. LIVE.",
		Outfit = { Shirt = JK, Pants = C(42, 42, 55) },
		HideFace = true,
		Parts = join({
			-- casque RGB à oreilles de chat
			P(H, B, V(1.42, 0.13, 0.34), DARK, SP, 0, 0.68, 0),
			P(H, CY, V(0.3, 0.66, 0.66), DARK, SP, -0.68, 0.05, 0),
			P(H, CY, V(0.3, 0.66, 0.66), DARK, SP, 0.68, 0.05, 0),
			P(H, CY, V(0.32, 0.46, 0.46), PK, NE, -0.7, 0.05, 0, { Anim = { Pulse = 0.5, PulseSpeed = 4 } }),
			P(H, CY, V(0.32, 0.46, 0.46), CYN, NE, 0.7, 0.05, 0, { Anim = { Pulse = 0.5, PulseSpeed = 4, Seed = 0.8 } }),
			P(H, WE, V(0.1, 0.42, 0.36), PK, NE, -0.42, 0.88, 0, 0, -90, 0),
			P(H, WE, V(0.1, 0.42, 0.36), CYN, NE, 0.42, 0.88, 0, 0, 90, 0),
			P(H, B, V(0.06, 0.06, 0.6), DARK, SP, -0.5, -0.2, -0.38, 0, -35, 0),
			P(H, BA, V(0.18, 0.18, 0.18), PK, NE, -0.3, -0.22, -0.66),
			-- ring light derrière la tête
			P(H, CY, V(0.08, 2.7, 2.7), WHT, NE, 0, 0.3, 0.95, 0, 90, 0),
			P(H, CY, V(0.1, 2.15, 2.15), C(40, 40, 50), SP, 0, 0.3, 0.9, 0, 90, 0),
			P(H, CY, V(0.1, 2.15, 2.15), C(40, 40, 50), SP, 0, 0.3, 1.0, 0, 90, 0),
			P(T, B, V(0.16, 0.55, 0.48), C(40, 40, 50), ME, 0, 0.72, 0.73),
			-- drone caméra en orbite
			{ Limb = H, Asset = "Intern_Legendary_Drone", Size = V(1.1, 0.6, 0.8), Offset = CFrame.new(2.0, 0.95, 0) * CFrame.Angles(0, rad(-90), 0), Anim = drone },
			P(H, BA, V(0.14, 0.14, 0.14), RED, NE, 2.0, 1.28, 0, { Anim = o(drone, { Pulse = 0.8, PulseSpeed = 5 }) }),
			-- LIVE + compteur de viewers
			P(H, B, V(1.3, 0.46, 0.1), RED, NE, 0, 2.0, 0.2, { Text = { Text = "● LIVE", Font = "Black", Face = "Both", Blink = 1.5 },
				Anim = { Float = true, Seed = 3 } }),
			P(H, B, V(1.1, 0.3, 0.05), WHT, SP, -1.45, 1.75, 0.2, 0, 15, 0, { Transparency = 1,
				Text = { Text = "99.9K watching", Color = WHT, Font = "Black", Face = "Both" }, Anim = { Float = true, Seed = 3 } }),
			-- veste gamer : passepoils RGB + capuche
			P(T, B, V(0.06, 2.0, 0.06), PK, NE, -0.4, 0, -0.53),
			P(T, B, V(0.06, 2.0, 0.06), CYN, NE, 0.4, 0, -0.53),
			P(T, B, V(1.5, 0.55, 0.75), JK, FA, 0, 1.0, 0.38, o(SPH)),
			-- poignets néon + jointures des gants gamer
			P(LA, B, V(1.1, 0.12, 1.1), PK, NE, 0, -0.45, 0),
			P(RA, B, V(1.1, 0.12, 1.1), CYN, NE, 0, -0.45, 0),
			P(LA, B, V(1.06, 0.08, 0.3), PK, NE, 0, -0.82, -0.4),
			P(RA, B, V(1.06, 0.08, 0.3), CYN, NE, 0, -0.82, -0.4),
			-- baskets LED
			P(LL, B, V(1.15, 0.14, 1.36), PK, NE, 0, -0.96, -0.14, { Trail = { Color = PK, Width = 0.35 } }),
			P(RL, B, V(1.15, 0.14, 1.36), CYN, NE, 0, -0.96, -0.14, { Trail = { Color = CYN, Width = 0.35 } }),
			-- pancarte SUBSCRIBE + cloche
			P(RA, CY, V(2.4, 0.1, 0.1), C(150, 110, 70), WO, 0, 0.2, -0.6, 0, 0, 90),
			P(RA, B, V(1.9, 0.65, 0.1), RED, SP, 0.3, 1.55, -0.6, { Text = { Text = "SUBSCRIBE", Font = "Black", Face = "Both" } }),
			P(RA, BA, V(0.32, 0.32, 0.32), GOLD, NE, 1.48, 1.55, -0.6, { Anim = { Swing = 25, SwingSpeed = 6, SwingAxis = "Z" } }),
			-- cœurs flottants
			P(H, B, V(0.5, 0.5, 0.05), PK, SP, -1.4, 0.7, -0.3, { Transparency = 1, Text = { Text = "♥", Color = PK, Face = "Both" }, Anim = { Float = true, Seed = 4 } }),
			P(H, B, V(0.4, 0.4, 0.05), PK, SP, 1.35, 1.35, -0.2, { Transparency = 1, Text = { Text = "♥", Color = PK, Face = "Both" }, Anim = { Float = true, Seed = 5 } }),
			P(H, B, V(0.35, 0.35, 0.05), CYN, SP, -0.9, 2.2, 0.1, { Transparency = 1, Text = { Text = "♥", Color = CYN, Face = "Both" }, Anim = { Float = true, Seed = 6 } }),
			-- transformation : le chat explose
			P(H, B, V(1.1, 0.5, 0.05), WHT, SP, -1.9, 1.3, 0.3, 0, 25, 0, { Transform = true,
				Text = { Text = "POG!!", Color = PK, Font = "Black", Face = "Both", Bg = WHT }, Anim = { Bob = 0.15, Seed = 7 } }),
			P(H, B, V(1.1, 0.5, 0.05), WHT, SP, 1.9, 0.6, 0.3, 0, -25, 0, { Transform = true,
				Text = { Text = "GG EZ", Color = CYN, Font = "Black", Face = "Both", Bg = WHT }, Anim = { Bob = 0.15, Seed = 8 } }),
		},
		pair(LL, RL, B, V(1.06, 0.2, 1.06), JK, FA, 0, -0.48, 0),
		pair(LL, RL, B, V(1.1, 0.42, 1.25), WHT, SP, 0, -0.79, -0.1),
		pair(LL, RL, B, V(1.08, 0.38, 0.5), WHT, SP, 0, -0.81, -0.68, o(SPH))),
		Paint = {
			faceKit({ Brow = "happy", Mouth = "open", Blush = PK, Iris = C(90, 50, 160) }),
			face(T, "Front", {
				bx(0.5, 0.5, 0.38, 1, WHT), -- t-shirt sous la veste ouverte
				bx(0.5, 0.3, 0.28, 0.18, RED, { Corner = 0.35 }),
				tx(0.5, 0.3, 0.14, 0.12, "▶", WHT, "Black"),
				tx(0.5, 0.48, 0.34, 0.07, "STREAM", JK, "Black"),
				tx(0.5, 0.55, 0.34, 0.05, "TEAM", RED, "Black"),
				bx(0.16, 0.72, 0.2, 0.03, C(60, 60, 75)), bx(0.84, 0.72, 0.2, 0.03, C(60, 60, 75)),
				ci(0.15, 0.25, 0.1, 0.1, CYN), ci(0.85, 0.25, 0.1, 0.1, PK),
			}),
			face(T, "Back", {
				tx(0.5, 0.42, 0.9, 0.26, "LIVE", PK, "Black"),
				tx(0.5, 0.62, 0.9, 0.08, "SMASH THAT LIKE", CYN, "Black"),
				bx(0.5, 0.2, 0.9, 0.025, PK), bx(0.5, 0.75, 0.9, 0.025, CYN),
			}),
			face(LL, "Left", { bx(0.5, 0.45, 0.12, 0.9, PK) }),
			face(RL, "Right", { bx(0.5, 0.45, 0.12, 0.9, CYN) }),
			face(LA, "Left", { tx(0.5, 0.3, 0.9, 0.12, "LIVE", PK, "Black", { Rotation = 90 }) }),
		},
		FX = { PowerAura = PK, Orbit = { Color = CYN, Count = 3, Shape = "Ball", Size = 0.3, Speed = 1.6 } },
		Highlight = { Outline = PK },
		HitColor = PK,
	})
end

-- ===================== JANITOR =====================
do
	local PUR, PUR2, AFRO, PNKL = C(150, 60, 220), C(195, 120, 255), C(45, 30, 22), C(255, 90, 200)
	S({ Id = "Janitor_Rare", Character = "Janitor", Rarity = "Rare", Name = "Disco Custodian",
		Desc = "Mops the floor. Then owns the dance floor.",
		Outfit = { Shirt = PUR, Pants = WHT, ArmsSkin = true },
		HideHair = true, HideFace = true,
		Parts = join({
			-- afro + pattes
			P(H, B, V(1.85, 1.35, 1.75), AFRO, FA, 0, 0.6, 0.12, o(SPH)),
			-- boule à facettes qui tourne au-dessus de la tête
			P(H, BA, V(0.85, 0.85, 0.85), C(225, 225, 240), FO, 0, 2.05, 0, { Reflect = 0.6, Light = C(255, 120, 220),
				Anim = { Spin = 90, Bob = 0.15, Seed = 4 } }),
			P(H, B, V(0.04, 0.6, 0.04), SIL, ME, 0, 2.75, 0, { Anim = { Bob = 0.15, Seed = 4 } }),
			-- lunettes rondes roses
			P(H, B, V(1.22, 0.05, 0.06), GOLD, ME, 0, 0.21, -0.63),
			-- ceinture blanche, grosse boucle dorée
			P(T, B, V(2.04, 0.18, 1.04), WHT, SP, 0, -0.9, 0),
			P(T, B, V(0.5, 0.3, 0.06), GOLD, FO, 0, -0.9, -0.53),
			-- médaillon
			P(T, CY, V(0.08, 0.42, 0.42), GOLD, FO, 0, 0.12, -0.6, 0, 90, 0, { Anim = { Spin = 100 } }),
		}, mir(H, B, V(0.12, 0.42, 0.28), AFRO, FA, -0.6, -0.05, -0.08),
		mir(H, CY, V(0.06, 0.38, 0.38), PNKL, GL, -0.25, 0.1, -0.62, 0, 90, 0),
		-- grand col pointu 70s
		mir(T, B, V(0.26, 0.72, 0.05), PUR2, SP, -0.36, 0.72, -0.535, 0, 0, 52),
		mir(T, B, V(0.07, 0.75, 0.06), GOLD, FO, -0.2, 0.55, -0.54, 0, 0, 25),
		-- manches satinées + poignets évasés
		pair(LA, RA, B, V(1.06, 1.5, 1.06), PUR, SP, 0, 0.25, 0),
		pair(LA, RA, B, V(1.18, 0.26, 1.18), WHT, SP, 0, -0.55, 0),
		-- pattes d'éph + semelles compensées
		pair(LL, RL, CY, V(0.5, 1.2, 1.2), WHT, SP, 0, -0.3, 0, 0, 0, 90),
		pair(LL, RL, CY, V(0.5, 1.5, 1.5), WHT, SP, 0, -0.75, 0, 0, 0, 90),
		pair(LL, RL, B, V(1.0, 0.28, 0.4), GOLD, ME, 0, -0.88, -0.66)),
		Paint = {
			face(T, "Front", {
				bx(0.5, 0.3, 0.3, 0.45, C(120, 40, 190), { Rotation = 0 }), -- décolleté ombré
				ci(0.5, 0.6, 0.05, 0.05, GOLD), ci(0.5, 0.7, 0.05, 0.05, GOLD), ci(0.5, 0.8, 0.05, 0.05, GOLD),
				bx(0.2, 0.62, 0.07, 0.07, GOLD, { Rotation = 45 }), bx(0.82, 0.75, 0.06, 0.06, PNKL, { Rotation = 45 }),
				bx(0.78, 0.45, 0.05, 0.05, WHT, { Rotation = 45 }), bx(0.15, 0.85, 0.05, 0.05, PNKL, { Rotation = 45 }),
			}),
			faceKit({ NoEyes = true, Brow = "raised", BrowCol = AFRO, Mustache = AFRO, Mouth = "grin" }),
			face(T, "Back", {
				tx(0.5, 0.38, 0.9, 0.25, "DISCO", GOLD, "Display"),
				tx(0.5, 0.6, 0.8, 0.08, "CUSTODIAN", WHT, "Black"),
				bx(0.2, 0.15, 0.08, 0.08, PNKL, { Rotation = 45 }), bx(0.8, 0.8, 0.08, 0.08, PNKL, { Rotation = 45 }),
			}),
			outer(LL, RL, { bx(0.5, 0.5, 0.08, 1, GOLD) }),
			face(LL, "Front", { bx(0.5, 0.5, 0.04, 1, C(225, 225, 232)) }),
			face(RL, "Front", { bx(0.5, 0.5, 0.04, 1, C(225, 225, 232)) }),
		},
	})

	local YEL, NAVY, RUB, BOOT = C(255, 205, 40), C(40, 60, 110), C(60, 120, 230), C(45, 95, 65)
	local TANK, WATER = C(225, 50, 45), C(130, 225, 255)
	S({ Id = "Janitor_Epic", Character = "Janitor", Rarity = "Epic", Name = "Pressure Wash Pro",
		Desc = "10 million views of one very clean carpet. Satisfying.",
		Outfit = { Shirt = YEL, Pants = NAVY },
		HideHair = true, HideFace = true,
		Parts = join({
			-- chapeau de pluie (suroît)
			P(H, B, V(1.38, 0.72, 1.42), YEL, SP, 0, 0.5, 0.03, o(SPH)),
			P(H, B, V(2.0, 0.08, 2.25), YEL, SP, 0, 0.3, 0.16, o(SPH)),
			-- lunettes de protection
			P(H, CY, V(0.16, 1.3, 1.3), DARK, SP, 0, 0.12, 0, 0, 0, 90),
			P(H, B, V(1.15, 0.44, 0.14), DARK, SP, 0, 0.12, -0.58, o(SPH)),
			P(H, B, V(1.04, 0.34, 0.16), C(140, 225, 255), GL, 0, 0.12, -0.6, o(SPH, { Transparency = 0.15, Reflect = 0.3 })),
			-- salopette : bavette + bretelles + boutons
			P(T, B, V(1.2, 0.95, 0.05), NAVY, FA, 0, -0.5, -0.53, { Text = { Text = "PRESSURE PRO", Color = YEL, Font = "Black", Face = "Front" } }),
			-- réservoir rouge dans le dos
			P(T, CY, V(1.6, 0.95, 0.95), TANK, ME, 0, -0.1, 0.98, 0, 0, 90),
			P(T, B, V(0.95, 0.5, 0.95), TANK, ME, 0, 0.7, 0.98, o(SPH)),
			P(T, CY, V(0.05, 0.36, 0.36), WHT, SP, 0, 0.15, 1.47, 0, 90, 0),
			P(T, B, V(0.03, 0.15, 0.02), RED, SP, 0.03, 0.19, 1.5, 0, 0, -35),
			-- tuyau + lance
			P(RA, CY, V(1.8, 0.12, 0.12), BLK, SP, 0, -0.2, 0.56, 0, 0, 90),
			P(RA, B, V(0.24, 0.5, 0.24), YEL, SP, 0, -1.15, -0.4),
			P(RA, CY, V(1.6, 0.12, 0.12), C(70, 70, 80), ME, 0, -1.05, -1.1, 0, 90, 0),
			P(RA, CY, V(0.3, 0.24, 0.24), YEL, SP, 0, -1.05, -1.95, 0, 90, 0),
			P(RA, CY, V(1.6, 0.22, 0.22), WATER, NE, 0, -1.05, -2.9, 0, 90, 0, { Transparency = 0.3,
				Anim = { Pulse = 0.45, PulseSpeed = 10 },
				Particles = { Kind = "Smoke", Color = C(200, 240, 255), Rate = 12, Dir = "Right", Speed = 6, Size = 0.5, Life = 0.5, Spread = 20 } }),
			-- transformation : jet XXL
			P(RA, CY, V(3.2, 0.45, 0.45), C(170, 240, 255), NE, 0, -1.05, -3.7, 0, 90, 0, { Transform = true, Transparency = 0.45,
				Anim = { Pulse = 0.3, PulseSpeed = 14 } }),
			P(H, B, V(1.6, 0.4, 0.05), WHT, SP, 0, 1.55, 0, { Transparency = 1,
				Text = { Text = "▶ 10M VIEWS", Color = WHT, Font = "Black", Face = "Both" }, Anim = { Float = true } }),
		}, mir(T, B, V(0.16, 1.1, 0.05), NAVY, FA, -0.45, 0.45, -0.53),
		mir(T, CY, V(0.05, 0.14, 0.14), GOLD, ME, -0.45, 0.02, -0.56, 0, 90, 0),
		-- gants caoutchouc + bandes réfléchissantes
		pair(LA, RA, B, V(1.08, 0.5, 1.08), RUB, SP, 0, -0.76, 0),
		pair(LA, RA, B, V(1.14, 0.14, 1.14), RUB, SP, 0, -0.48, 0),
		pair(LA, RA, B, V(1.05, 0.14, 1.05), SIL, FO, 0, 0.2, 0, { Reflect = 0.4 }),
		-- bottes en caoutchouc
		pair(LL, RL, B, V(1.1, 0.95, 1.16), BOOT, SP, 0, -0.55, -0.04),
		pair(LL, RL, B, V(1.08, 0.45, 0.5), BOOT, SP, 0, -0.8, -0.62, o(SPH)),
		pair(LL, RL, B, V(1.15, 0.12, 1.36), BLK, SP, 0, -0.96, -0.14),
		pair(LL, RL, B, V(1.13, 0.1, 1.18), YEL, SP, 0, -0.1, -0.04)),
		Paint = {
			face(T, "Front", {
				bx(0.5, 0.22, 1, 0.07, SIL), -- bande réfléchissante
				bx(0.5, 0.04, 0.5, 0.08, C(235, 185, 30)), -- col
				bx(0.5, 0.1, 0.03, 0.2, C(200, 160, 20)),
				bx(0.18, 0.4, 0.22, 0.1, C(235, 185, 30), { Corner = 0.2 }), bx(0.82, 0.4, 0.22, 0.1, C(235, 185, 30), { Corner = 0.2 }),
			}),
			face(T, "Back", { bx(0.5, 0.22, 1, 0.07, SIL), bx(0.5, 0.85, 1, 0.07, SIL) }),
			faceKit({ NoEyes = true, Brow = "happy", Mouth = "grin" }),
			face(T, "Left", { bx(0.5, 0.22, 1, 0.07, SIL) }),
			face(T, "Right", { bx(0.5, 0.22, 1, 0.07, SIL) }),
			face(LL, "Front", { bx(0.5, 0.2, 0.5, 0.16, C(30, 45, 85), { Corner = 0.2 }) }),
			face(RL, "Front", { bx(0.5, 0.2, 0.5, 0.16, C(30, 45, 85), { Corner = 0.2 }) }),
		},
		FX = { Aura = C(170, 235, 255) },
		HitColor = WATER,
	})

	local SKY, SKY2, NAVY2, BUB, VEL = C(90, 170, 255), C(160, 210, 255), C(35, 60, 140), C(150, 225, 255), C(150, 30, 70)
	-- couronne : mesh généré (SkinAssets.Janitor_Legendary_Crown) qui tourne lentement
	local crown, halo = {
		{ Limb = H, Asset = "Janitor_Legendary_Crown", Size = V(1.55, 0.9, 1.55), Offset = CFrame.new(0, 0.98, 0), Anim = { Spin = 35 },
			Light = C(150, 220, 255) },
	}, {}
	for i = 0, 4 do
		local a = math.rad(i * 72)
		halo[#halo + 1] = P(T, BA, V(0.55, 0.55, 0.55), BUB, GL, 2.6 * math.cos(a), 0.5, 2.6 * math.sin(a),
			{ Transform = true, Transparency = 0.3, Anim = { Circle = 0.9, Seed = 11 } })
	end
	local cape = { Swing = 4, SwingAxis = "X", SwingSpeed = 1.5, Seed = 9 }
	S({ Id = "Janitor_Legendary", Character = "Janitor", Rarity = "Legendary", Name = "Bubble Emperor",
		Desc = "Long live the spotless empire. Kneel before the mop.",
		Outfit = { Shirt = SKY, Pants = NAVY2 },
		HideHair = true, HideFace = true,
		Parts = join(crown, halo, {
			-- couronne : anneau tournant + bonnet de velours + orbe
			P(H, B, V(1.2, 0.62, 1.2), VEL, FA, 0, 0.9, 0, o(SPH)),
			P(H, BA, V(0.3, 0.3, 0.3), CYAN, NE, 0, 1.55, 0, { Anim = { Bob = 0.08, Pulse = 0.4 } }),
			-- col d'hermine
			P(T, B, V(2.3, 0.5, 1.35), WHT, FA, 0, 0.98, 0, o(SPH)),
			P(T, B, V(0.08, 0.14, 0.04), BLK, SP, 0, 0.95, -0.68),
			P(T, B, V(0.08, 0.14, 0.04), BLK, SP, -0.62, 0.95, -0.57),
			P(T, B, V(0.08, 0.14, 0.04), BLK, SP, 0.62, 0.95, -0.57),
			-- écharpe dorée + médaille, ceinture
			P(T, B, V(0.3, 2.6, 0.05), GOLD, FA, 0, -0.05, -0.54, 0, 0, 38),
			P(T, CY, V(0.06, 0.4, 0.4), CYAN, NE, -0.22, 0.25, -0.58, 0, 90, 0),
			P(T, B, V(2.04, 0.22, 1.04), GOLD, ME, 0, -0.9, 0),
			P(T, BA, V(0.3, 0.3, 0.3), CYAN, NE, 0, -0.9, -0.55),
			-- cape-bulle irisée
			P(T, B, V(2.6, 3.4, 0.1), C(45, 90, 200), FA, 0, -0.7, 0.75, -8, 0, 0, { Anim = cape,
				Text = { Text = "♛", Color = GOLD, Face = "Back" },
				Particles = { Kind = "Sparkle", Color = BUB, Rate = 5, Dir = "Back", Speed = 1, Size = 0.4, Life = 1.2 } }),
			P(T, B, V(2.65, 0.14, 0.16), GOLD, ME, 0, 0.95, 0.55),
			P(T, B, V(2.75, 0.32, 0.32), WHT, FA, 0, -2.4, 0.99, -8, 0, 0, o(SPH, { Anim = cape })),
			-- grand col médicis derrière la tête
			P(T, B, V(2.3, 1.1, 0.08), WHT, FA, 0, 1.45, 0.62, 18, 0, 0),
			P(T, B, V(2.35, 0.1, 0.12), GOLD, ME, 0, 1.97, 0.79, 18, 0, 0),
			-- transformation : bouclier-bulle géant
			P(T, BA, V(6, 6, 6), BUB, FF, 0, -0.4, 0, { Transform = true, Transparency = 0.1 }),
			P(T, BA, V(0.5, 0.5, 0.5), BUB, GL, 0.55, -0.4, 0.9, { Transparency = 0.3, Anim = cape }),
			P(T, BA, V(0.35, 0.35, 0.35), BUB, GL, -0.6, -1.3, 0.97, { Transparency = 0.3, Anim = cape }),
			P(T, BA, V(0.42, 0.42, 0.42), BUB, GL, 0.3, -2.0, 1.05, { Transparency = 0.3, Anim = cape }),
			-- sceptre-serpillière : orbe lumineuse dans une bulle
			P(LA, CY, V(3.2, 0.14, 0.14), GOLD, ME, 0, -0.7, -0.55, 0, 0, 90),
			P(LA, CY, V(0.2, 0.38, 0.38), GOLD, ME, 0, 0.95, -0.55, 0, 0, 90),
			P(LA, B, V(0.07, 0.6, 0.07), GOLD, ME, 0.25, 1.25, -0.55, 0, 0, -25),
			P(LA, B, V(0.07, 0.6, 0.07), GOLD, ME, -0.25, 1.25, -0.55, 0, 0, 25),
			P(LA, B, V(0.07, 0.6, 0.07), GOLD, ME, 0, 1.25, -0.3, 25, 0, 0),
			P(LA, BA, V(0.8, 0.8, 0.8), BUB, GL, 0, 1.5, -0.55, { Transparency = 0.35, Light = C(120, 220, 255) }),
			P(LA, BA, V(0.38, 0.38, 0.38), CYAN, NE, 0, 1.5, -0.55, { Anim = { Pulse = 0.6 },
				Particles = { Kind = "Sparkle", Color = BUB, Rate = 6, Speed = 1.5, Size = 0.35, Life = 1 } }),
			P(LA, B, V(0.8, 0.6, 0.8), WHT, FA, 0, -2.45, -0.55, o(SPH)),
			P(LA, CY, V(0.16, 0.42, 0.42), GOLD, ME, 0, -2.12, -0.55, 0, 0, 90),
		},
		-- moustache impériale
		mir(H, B, V(0.4, 0.12, 0.13), C(240, 240, 245), SP, -0.19, -0.16, -0.62, 0, 0, -15, o(SPH)),
		-- manches bouffantes + épaulettes + manchettes + gants blancs
		pair(LA, RA, B, V(1.32, 1.0, 1.32), SKY2, SP, 0, 0.55, 0, o(SPH)),
		pair(LA, RA, CY, V(0.14, 1.1, 1.1), GOLD, ME, 0, 1.06, 0, 0, 0, 90),
		pair(LA, RA, B, V(1.12, 0.18, 1.12), GOLD, ME, 0, -0.5, 0),
		pair(LA, RA, B, V(1.06, 0.42, 1.06), WHT, SP, 0, -0.79, 0),
		-- bottes royales
		pair(LL, RL, B, V(1.08, 0.75, 1.18), WHT, SP, 0, -0.62, -0.06),
		pair(LL, RL, B, V(1.12, 0.12, 1.2), GOLD, ME, 0, -0.27, -0.06)),
		Paint = {
			face(T, "Front", {
				bx(0.5, 0.6, 0.34, 0.8, WHT), -- tunique
				bx(0.32, 0.6, 0.03, 0.8, GOLD), bx(0.68, 0.6, 0.03, 0.8, GOLD),
				ci(0.5, 0.55, 0.05, 0.05, GOLD), ci(0.5, 0.68, 0.05, 0.05, GOLD), ci(0.5, 0.81, 0.05, 0.05, GOLD),
			}),
			face(T, "Back", {
				ci(0.5, 0.42, 0.5, 0.5, GOLD), ci(0.5, 0.42, 0.42, 0.42, SKY),
				tx(0.5, 0.42, 0.3, 0.3, "B", GOLD, "Display"),
				ci(0.2, 0.8, 0.12, 0.12, WHT, { Transparency = 0.4 }), ci(0.8, 0.75, 0.08, 0.08, WHT, { Transparency = 0.4 }),
			}),
			outer(LL, RL, { bx(0.5, 0.5, 0.1, 1, GOLD) }),
			faceKit({ Brow = "raised", BrowCol = C(225, 225, 230), BrowW = 6, Mouth = "smirk", Iris = C(40, 90, 200) }),
		},
		FX = { PowerAura = BUB, Orbit = { Color = BUB, Count = 4, Shape = "Ball", Size = 0.55, Material = "Glass", Speed = 1.2 } },
		Highlight = { Outline = BUB },
		HitColor = C(120, 220, 255),
	})
end

-- ===================== LUNCH LADY =====================
do
	local TOM, CHEESE, BOX, PEP, CRUST, HAIR = C(220, 50, 45), C(255, 200, 90), C(205, 165, 115), C(170, 35, 30), C(215, 150, 70), C(120, 70, 40)
	local MITT = C(240, 95, 95)
	local checks = { bx(0.5, 0.56, 0.42, 0.44, WHT, { Corner = 0.1 }) } -- bavette à carreaux (nappe de pizzeria)
	for r = 0, 3 do
		for c = 0, 3 do
			if (r + c) % 2 == 0 then
				checks[#checks + 1] = bx(0.34 + c * 0.105, 0.39 + r * 0.11, 0.1, 0.1, TOM)
			end
		end
	end
	checks[#checks + 1] = bx(0.5, 0.04, 0.42, 0.06, WHT) -- bretelles du tablier
	checks[#checks + 1] = bx(0.32, 0.18, 0.05, 0.3, WHT)
	checks[#checks + 1] = bx(0.68, 0.18, 0.05, 0.3, WHT)
	checks[#checks + 1] = bx(0.5, 0.93, 1, 0.06, WHT)
	local stock = {}
	for i = 0, 3 do
		stock[#stock + 1] = bx(0.5, 0.42 + i * 0.12, 1, 0.05, TOM)
	end
	S({ Id = "LunchLady_Rare", Character = "LunchLady", Rarity = "Rare", Name = "Pizza Party Queen",
		Desc = "Every Friday. Attendance is mandatory. So is fun.",
		Outfit = { Shirt = TOM, Pants = C(250, 240, 225), ArmsSkin = true },
		HideHair = true, HideFace = true,
		Parts = join({
			-- couronne boîte à pizza ouverte
			P(H, B, V(1.5, 0.2, 1.5), BOX, SP, 0, 0.64, 0),
			P(H, CY, V(0.06, 1.32, 1.32), CHEESE, SP, 0, 0.76, 0, 0, 0, 90),
			P(H, CY, V(0.05, 0.3, 0.3), PEP, SP, -0.3, 0.79, -0.2, 0, 0, 90),
			P(H, CY, V(0.05, 0.3, 0.3), PEP, SP, 0.3, 0.79, 0.1, 0, 0, 90),
			P(H, CY, V(0.05, 0.3, 0.3), PEP, SP, -0.05, 0.79, 0.38, 0, 0, 90),
			P(H, B, V(1.5, 1.5, 0.1), BOX, SP, 0, 1.45, 1.0, 20, 0, 0, { Text = { Text = "PIZZA PARTY", Color = PEP, Font = "Black", Face = "Front" } }),
			-- carré plongeant
			P(H, B, V(1.42, 1.0, 0.8), HAIR, SP, 0, 0.05, 0.3, o(SPH)),
			-- col claudine
			P(T, B, V(1.3, 0.18, 1.1), WHT, SP, 0, 1.02, -0.05, o(SPH)),
			-- jupe + volant
			P(T, B, V(2.12, 0.9, 1.14), TOM, SP, 0, -1.4, 0),
			P(T, B, V(2.18, 0.14, 1.2), WHT, SP, 0, -1.84, 0),
			P(T, B, V(1.3, 1.05, 0.05), WHT, SP, 0, -1.25, -0.6, { Text = { Text = "PIZZA QUEEN", Color = TOM, Font = "Cartoon", Face = "Front" } }),
			-- part de pizza (main droite)
			P(RA, WE, V(0.1, 0.9, 0.65), CHEESE, SP, 0, -1.4, -0.5, 0, 0, 180),
			P(RA, B, V(0.16, 0.16, 0.7), CRUST, SP, 0, -0.95, -0.5),
			P(RA, CY, V(0.12, 0.2, 0.2), PEP, SP, 0, -1.25, -0.6),
			P(RA, CY, V(0.12, 0.16, 0.16), PEP, SP, 0, -1.55, -0.45),
			-- gant de cuisine (main gauche)
			P(LA, B, V(1.15, 0.62, 1.15), MITT, FA, 0, -0.72, 0),
			P(LA, B, V(0.36, 0.36, 0.4), MITT, FA, 0.35, -0.72, -0.5, o(SPH)),
		}, mir(H, B, V(0.42, 0.58, 0.5), HAIR, SP, -0.6, -0.1, 0.05, o(SPH)),
		mir(H, CY, V(0.04, 0.32, 0.32), GOLD, ME, -0.66, -0.38, -0.05),
		pair(LA, RA, B, V(1.3, 1.05, 1.3), TOM, SP, 0, 0.5, 0, o(SPH)),
		pair(LL, RL, B, V(1.08, 0.35, 1.25), TOM, SP, 0, -0.83, -0.1)),
		Paint = {
			faceKit({ Lashes = true, Lips = C(200, 30, 50), Mouth = "smile", Blush = C(255, 110, 120), Brow = "happy", BrowCol = HAIR }),
			face(T, "Front", checks),
			face(T, "Back", {
				bx(0.5, 0.45, 0.08, 1.1, WHT, { Rotation = 30 }), bx(0.5, 0.45, 0.08, 1.1, WHT, { Rotation = -30 }),
				ci(0.4, 0.9, 0.2, 0.12, WHT), ci(0.6, 0.9, 0.2, 0.12, WHT), ci(0.5, 0.9, 0.08, 0.08, TOM),
			}),
			face(LL, "Front", stock), face(RL, "Front", stock),
			face(LL, "Left", stock), face(RL, "Right", stock),
			face(LL, "Back", stock), face(RL, "Back", stock),
		},
	})

	local PNK, PNK2, PNKD, BLOND, BLONDD = C(255, 110, 160), C(255, 175, 205), C(225, 75, 135), C(250, 215, 110), C(225, 180, 75)
	S({ Id = "LunchLady_Epic", Character = "LunchLady", Rarity = "Epic", Name = "Cooking Show Diva",
		Desc = "Live from the break room: it's FABULOUS, darling.",
		Outfit = { Shirt = PNK, Pants = C(45, 32, 48), ArmsSkin = true },
		HideHair = true, HideFace = true,
		Parts = join({
			-- brushing blond XXL
			P(H, B, V(1.75, 1.3, 1.6), BLOND, SP, 0, 0.5, 0.22, o(SPH)),
			P(H, B, V(1.3, 0.85, 1.2), BLOND, SP, 0, 1.08, 0.15, o(SPH)),
			P(H, B, V(1.55, 1.2, 0.9), BLONDD, SP, 0, 0.05, 0.5, o(SPH)),
			P(H, B, V(1.8, 0.14, 1.66), PNK, SP, 0, 0.62, 0.2, o(SPH)),
			-- micro-casque
			P(H, B, V(0.05, 0.05, 0.56), DARK, SP, 0.6, -0.14, -0.36, 0, 25, 0),
			P(H, BA, V(0.13, 0.13, 0.13), DARK, SP, 0.46, -0.17, -0.63),
			-- foulard + revers blancs
			P(T, B, V(0.45, 0.45, 0.05), WHT, SP, 0, 0.72, -0.53, 0, 0, 45),
			P(T, B, V(0.26, 0.2, 0.12), WHT, SP, 0, 0.93, -0.55, o(SPH)),
			-- jupe crayon + demi-tablier à volant
			P(T, B, V(2.06, 1.25, 1.08), PNKD, SP, 0, -1.6, 0),
			P(T, B, V(1.3, 1.05, 0.05), WHT, SP, 0, -1.45, -0.57, { Text = { Text = "♥ DIVA ♥", Color = PNK, Font = "Cartoon", Face = "Front" } }),
			P(T, B, V(1.38, 0.14, 0.08), PNK2, SP, 0, -2.0, -0.58),
			-- fouet géant scintillant
			{ Limb = RA, Asset = "LunchLady_Epic_Whisk", Size = V(1.0, 1.6, 1.0), Offset = CFrame.new(0, -0.45, -0.7) * CFrame.Angles(rad(-20), 0, 0),
				Particles = { Kind = "Sparkle", Color = C(255, 150, 220), Rate = 5, Speed = 1.5, Size = 0.35, Life = 0.9 } },
			-- tarte à la cerise (main gauche)
			P(LA, CY, V(0.2, 1.0, 1.0), C(205, 145, 75), SP, 0, -1.05, -0.7, 0, 0, 90),
			P(LA, CY, V(0.08, 0.84, 0.84), C(200, 40, 70), SP, 0, -0.94, -0.7, 0, 0, 90),
			P(LA, B, V(0.26, 0.2, 0.26), WHT, SP, -0.22, -0.85, -0.55, o(SPH)),
			P(LA, B, V(0.26, 0.2, 0.26), WHT, SP, 0.22, -0.85, -0.8, o(SPH)),
			P(LA, B, V(0.3, 0.24, 0.3), WHT, SP, 0, -0.84, -0.7, o(SPH)),
			P(LA, BA, V(0.18, 0.18, 0.18), RED, SP, 0, -0.68, -0.7),
			-- panneau ON AIR
			P(H, B, V(1.6, 0.5, 0.1), RED, NE, 0, 2.0, 0.2, { Text = { Text = "ON AIR", Font = "Black", Face = "Both", Blink = 1 }, Anim = { Float = true } }),
		}, mir(H, B, V(0.5, 0.3, 0.6), BLOND, SP, -0.8, -0.35, 0.15, 0, 0, 25, o(SPH)),
		mir(H, CY, V(0.05, 0.36, 0.36), GOLD, NE, -0.64, -0.3, 0),
		mir(T, BA, V(0.16, 0.16, 0.16), WHT, SP, -0.26, 0.9, -0.53),
		mir(T, B, V(0.2, 0.75, 0.05), WHT, SP, -0.34, 0.62, -0.535, 0, 0, 22),
		pair(LA, RA, B, V(1.06, 1.3, 1.06), PNK, SP, 0, 0.35, 0),
		pair(LA, RA, B, V(1.12, 0.2, 1.12), WHT, SP, 0, -0.3, 0),
		pair(LL, RL, B, V(1.04, 0.3, 1.2), PNK, SP, 0, -0.86, -0.1),
		pair(LL, RL, B, V(0.42, 0.18, 0.12), WHT, SP, 0, -0.7, -0.72)),
		Paint = {
			faceKit({ Lashes = true, Iris = C(60, 130, 220), Lips = C(230, 40, 120), Mouth = "smile", Blush = C(255, 120, 170), Brow = "raised", BrowCol = BLONDD }),
			face(H, "Front", { ci(0.36, 0.36, 0.17, 0.08, C(120, 170, 255), { Transparency = 0.35 }), ci(0.64, 0.36, 0.17, 0.08, C(120, 170, 255), { Transparency = 0.35 }),
				ci(0.58, 0.6, 0.03, 0.04, C(60, 40, 40)) }), -- fard + grain de beauté
			face(T, "Front", {
				ci(0.38, 0.45, 0.06, 0.06, GOLD), ci(0.62, 0.45, 0.06, 0.06, GOLD),
				ci(0.38, 0.58, 0.06, 0.06, GOLD), ci(0.62, 0.58, 0.06, 0.06, GOLD),
				bx(0.82, 0.35, 0.16, 0.1, PNK2, { Corner = 0.3 }), tx(0.5, 0.3, 0.2, 0.08, "DIVA", WHT, "Hand"),
				bx(0.5, 0.97, 1, 0.06, PNKD),
			}),
			face(T, "Back", {
				tx(0.5, 0.3, 0.9, 0.12, "LIVE FROM", WHT, "Black"),
				tx(0.5, 0.45, 0.9, 0.12, "THE BREAK ROOM", PNK2, "Black"),
				tx(0.5, 0.68, 0.3, 0.2, "★", GOLD, "Black"),
			}),
		},
		FX = { Spotlight = C(255, 220, 240) },
		HitColor = PNK,
	})

	local BLK2, FLAME, FLAME2, BURG, RUST = C(26, 26, 30), C(255, 120, 30), C(255, 215, 60), C(140, 25, 30), C(220, 40, 30)
	local pleats = {}
	for _, a in ipairs({ -60, -20, 20, 60 }) do
		local r = math.rad(a)
		pleats[#pleats + 1] = P(H, B, V(0.05, 1.0, 0.05), C(225, 225, 230), SP, 0.69 * math.sin(r), 1.38, -0.69 * math.cos(r), 0, -a, 0)
	end
	local plates = {}
	for i = 0, 2 do
		local a = math.rad(i * 120)
		local x, z = 2.4 * math.cos(a), 2.4 * math.sin(a)
		plates[#plates + 1] = P(T, CY, V(0.08, 0.9, 0.9), WHT, SP, x, 0.8, z, 0, 0, 90, { Anim = { Circle = 1.5, Seed = 7 } })
		plates[#plates + 1] = P(T, B, V(0.66, 0.36, 0.66), SIL, ME, x, 1.0, z, o(SPH, { Reflect = 0.35, Anim = { Circle = 1.5, Seed = 7 } }))
	end
	local checker = {}
	for r = 0, 7 do
		for c = 0, 3 do
			if (r + c) % 2 == 0 then
				checker[#checker + 1] = bx(0.125 + c * 0.25, 0.0625 + r * 0.125, 0.25, 0.125, BLK2)
			end
		end
	end
	local fire = { Kind = "Fire", Color = C(255, 100, 20), Rate = 14, Speed = 3, Size = 0.8, Life = 0.6, TransformOnly = true }
	S({ Id = "LunchLady_Legendary", Character = "LunchLady", Rarity = "Legendary", Name = "Celebrity Chef Inferno",
		Desc = "Five stars. Zero patience. The break room is HER kitchen now.",
		Outfit = { Shirt = BLK2, Pants = WHT, ArmsSkin = true },
		HideHair = true, HideFace = true,
		Parts = join(pleats, plates, {
			-- toque géante
			P(H, CY, V(0.32, 1.36, 1.36), WHT, SP, 0, 0.68, 0, 0, 0, 90),
			P(H, CY, V(1.1, 1.34, 1.34), WHT, FA, 0, 1.38, 0, 0, 0, 90),
			P(H, B, V(2.0, 0.95, 2.0), WHT, FA, 0, 2.1, 0, o(SPH)),
			P(H, CY, V(0.12, 1.38, 1.38), FLAME, NE, 0, 0.86, 0, 0, 0, 90),
			P(H, B, V(1.35, 0.9, 0.7), C(70, 50, 45), SP, 0, 0.0, 0.32, o(SPH)),
			-- foulard rouge + col officier
			P(T, B, V(0.36, 0.22, 0.12), RUST, SP, 0, 0.92, -0.55, o(SPH)),
			P(T, B, V(0.3, 0.4, 0.05), RUST, SP, 0.05, 0.68, -0.55, 0, 0, 45),
			P(T, B, V(1.3, 0.22, 1.06), BLK2, SP, 0, 1.1, 0),
			P(T, B, V(1.32, 0.05, 1.08), FLAME, NE, 0, 1.22, 0),
			-- médaille 5 étoiles
			P(T, CY, V(0.06, 0.42, 0.42), GOLD, FO, -0.55, 0.3, -0.56, 0, 90, 0),
			P(T, B, V(0.18, 0.35, 0.04), RUST, SP, -0.55, 0.58, -0.54),
			-- tablier bordeaux + torchon
			P(T, B, V(1.9, 2.0, 0.05), BURG, FA, 0, -1.45, -0.55, { Text = { Text = "INFERNO", Color = FLAME, Font = "Bangers", Face = "Front" } }),
			P(T, B, V(2.04, 0.1, 1.04), WHT, SP, 0, -0.45, 0),
			P(T, B, V(0.45, 0.85, 0.06), WHT, FA, 0.62, -0.85, -0.6),
			P(T, B, V(0.46, 0.08, 0.07), RUST, SP, 0.62, -1.05, -0.6),
			-- poêle enflammée
			{ Limb = RA, Asset = "LunchLady_Legendary_Pan", Size = V(2.5, 1.1, 1.1), Offset = CFrame.new(0, -1.05, -0.6) * CFrame.Angles(0, rad(90), 0) },
			P(RA, B, V(1.0, 0.75, 1.0), FLAME, NE, 0, -0.78, -1.3, o(SPH, { Anim = { Pulse = 0.4, PulseSpeed = 8, Bob = 0.08, BobSpeed = 9 },
				Particles = { Kind = "Fire", Color = FLAME, Rate = 18, Speed = 3, Size = 0.7, Life = 0.6, React = true } })),
			P(RA, B, V(0.55, 0.6, 0.55), FLAME2, NE, 0, -0.7, -1.3, o(SPH, { Anim = { Bob = 0.1, BobSpeed = 11 } })),
			-- moulin à poivre géant
			P(LA, CY, V(1.2, 0.38, 0.38), C(110, 65, 35), WO, 0, -1.15, -0.5, 0, 0, 90),
			P(LA, CY, V(0.1, 0.42, 0.42), SIL, ME, 0, -0.85, -0.5, 0, 0, 90),
			P(LA, BA, V(0.3, 0.3, 0.3), SIL, ME, 0, -0.45, -0.5),
			-- 5 étoiles flottantes
			P(H, B, V(1.8, 0.45, 0.05), GOLD, SP, 0, 3.0, 0, { Transparency = 1,
				Text = { Text = "★★★★★", Color = GOLD, Face = "Both" }, Anim = { Float = true, Seed = 6 } }),
			-- transformation : épaules + toque en feu
			P(T, B, V(1.0, 0.8, 1.0), C(255, 100, 20), NE, -1.4, 1.2, 0, o(SPH, { Transform = true, Transparency = 0.35, Anim = { Pulse = 0.4, PulseSpeed = 7 }, Particles = fire })),
			P(T, B, V(1.0, 0.8, 1.0), C(255, 100, 20), NE, 1.4, 1.2, 0, o(SPH, { Transform = true, Transparency = 0.35, Anim = { Pulse = 0.4, PulseSpeed = 7, Seed = 1 }, Particles = fire })),
			P(H, B, V(1.2, 0.9, 1.2), FLAME, NE, 0, 2.7, 0, o(SPH, { Transform = true, Transparency = 0.3, Anim = { Pulse = 0.4, PulseSpeed = 9 }, Particles = fire })),
		},
		-- manches retroussées
		pair(LA, RA, B, V(1.06, 1.05, 1.06), BLK2, SP, 0, 0.475, 0),
		pair(LA, RA, B, V(1.12, 0.24, 1.12), C(48, 48, 56), SP, 0, -0.08, 0),
		-- sabots rouges
		pair(LL, RL, B, V(1.1, 0.42, 1.25), RUST, SP, 0, -0.8, -0.1),
		pair(LL, RL, B, V(1.08, 0.4, 0.55), RUST, SP, 0, -0.8, -0.68, o(SPH))),
		Paint = {
			faceKit({ Brow = "angry", BrowW = 7, Mouth = "grit", Iris = C(200, 60, 20), Ink = C(25, 15, 15) }),
			face(T, "Front", {
				ci(0.38, 0.22, 0.07, 0.07, SIL), ci(0.62, 0.22, 0.07, 0.07, SIL),
				ci(0.38, 0.38, 0.07, 0.07, SIL), ci(0.62, 0.38, 0.07, 0.07, SIL),
				ci(0.38, 0.54, 0.07, 0.07, SIL), ci(0.62, 0.54, 0.07, 0.07, SIL),
				bx(0.12, 0.45, 0.03, 0.9, FLAME), bx(0.88, 0.45, 0.03, 0.9, FLAME),
				tx(0.2, 0.15, 0.24, 0.07, "CHEF", FLAME, "Bangers"),
			}),
			face(T, "Back", {
				bx(0.2, 0.85, 0.16, 0.4, FLAME, { Corner = 1, Rotation = -10 }), bx(0.5, 0.8, 0.2, 0.5, FLAME, { Corner = 1 }),
				bx(0.8, 0.85, 0.16, 0.4, FLAME, { Corner = 1, Rotation = 10 }), bx(0.5, 0.86, 0.12, 0.3, FLAME2, { Corner = 1 }),
				tx(0.5, 0.3, 0.9, 0.16, "INFERNO", FLAME, "Bangers"),
				tx(0.5, 0.45, 0.8, 0.08, "KITCHEN", WHT, "Black"),
			}),
			face(LA, "Front", { tx(0.5, 0.78, 0.8, 0.1, "SALT", C(40, 60, 120), "Marker") }),
			face(RA, "Front", { tx(0.5, 0.78, 0.8, 0.1, "FIRE", C(180, 30, 20), "Marker") }),
			face(LL, "Front", checker), face(RL, "Front", checker),
			face(LL, "Left", checker), face(RL, "Right", checker),
			face(LL, "Back", checker), face(RL, "Back", checker),
		},
		FX = { PowerAura = FLAME, HandTrails = FLAME },
		Highlight = { Outline = FLAME },
		HitColor = FLAME,
	})
end

-- ===================== SECURITY GUARD =====================
do
	local LB, NV, PANTS, STEELG = C(150, 190, 235), C(30, 40, 75), C(35, 42, 62), C(170, 175, 185)
	S({ Id = "SecurityGuard_Rare", Character = "SecurityGuard", Rarity = "Rare", Name = "Segway Patrol",
		Desc = "Top speed: 12 mph. Top attitude: maximum.",
		Outfit = { Shirt = LB, Pants = PANTS, ArmsSkin = true },
		HideHair = true, HideFace = true,
		Parts = join({
			-- gyropode
			P(T, B, V(2.2, 0.22, 1.3), DARK, SP, 0, -3.12, -0.05),
			P(T, B, V(0.18, 2.1, 0.18), STEELG, ME, 0, -2.05, -0.85),
			P(T, CY, V(1.5, 0.14, 0.14), STEELG, ME, 0, -0.98, -0.85),
			P(T, B, V(0.4, 0.16, 0.06), C(255, 250, 200), NE, 0, -2.4, -0.96),
			-- casque vélo blanc à bande bleue + visière
			P(H, B, V(1.42, 0.95, 1.5), WHT, SP, 0, 0.45, 0.05, o(SPH)),
			P(H, B, V(0.26, 0.97, 1.52), C(40, 110, 230), SP, 0, 0.46, 0.05, o(SPH)),
			P(H, B, V(1.2, 0.08, 0.4), DARK, SP, 0, 0.36, -0.7),
			-- aviateurs miroir
			P(H, B, V(1.24, 0.05, 0.06), GOLD, ME, 0, 0.21, -0.63),
			-- radio d'épaule + insigne
			P(T, B, V(0.3, 0.45, 0.15), BLK, SP, 0.62, 0.62, -0.58),
			P(T, B, V(0.05, 0.4, 0.05), BLK, SP, 0.7, 1.02, -0.58),
			P(T, B, V(0.34, 0.34, 0.06), GOLD, ME, -0.48, 0.35, -0.54, 0, 0, 45),
			-- ceinture de service
			P(T, B, V(2.04, 0.2, 1.04), BLK, SP, 0, -0.9, 0),
			P(T, B, V(0.35, 0.3, 0.2), BLK, SP, 0.75, -0.95, -0.55),
		}, mir(T, CY, V(0.32, 1.15, 1.15), BLK, SP, -1.3, -2.75, -0.05),
		mir(T, CY, V(0.3, 0.18, 0.18), BLK, SP, -0.68, -0.98, -0.85),
		mir(H, B, V(0.44, 0.27, 0.06), C(255, 185, 60), SP, -0.26, 0.1, -0.63, o(SPH, { Reflect = 0.5 })),
		mir(T, B, V(0.5, 0.08, 0.9), NV, SP, -0.72, 1.02, 0),
		pair(LA, RA, B, V(1.06, 0.85, 1.06), LB, SP, 0, 0.575, 0),
		pair(LL, RL, B, V(1.08, 0.5, 1.25), BLK, SP, 0, -0.76, -0.1)),
		Paint = {
			faceKit({ NoEyes = true, Brow = "raised", Mustache = C(90, 60, 40), Mouth = "smirk" }),
			face(T, "Front", {
				bx(0.27, 0.3, 0.26, 0.18, C(130, 170, 220), { Corner = 0.15 }), bx(0.73, 0.3, 0.26, 0.18, C(130, 170, 220), { Corner = 0.15 }),
				bx(0.27, 0.23, 0.27, 0.05, C(110, 150, 205)), bx(0.73, 0.23, 0.27, 0.05, C(110, 150, 205)),
				bx(0.5, 0.36, 0.09, 0.5, NV), bx(0.5, 0.1, 0.13, 0.07, NV), -- cravate
				bx(0.27, 0.48, 0.24, 0.07, NV, { Corner = 0.3 }), tx(0.27, 0.48, 0.22, 0.05, "PATROL", WHT, "Black"),
			}),
			face(T, "Back", {
				tx(0.5, 0.35, 0.9, 0.18, "SECURITY", NV, "Black"),
				tx(0.5, 0.52, 0.7, 0.08, "MALL PATROL", NV, "Black"),
			}),
			outer(LL, RL, {
				bx(0.5, 0.36, 0.7, 0.2, C(28, 34, 52), { Corner = 0.15 }),
				bx(0.5, 0.5, 0.06, 1, C(150, 190, 235)),
			}),
		},
	})

	local TANKC, LEATHER, BAND, BOOTC = C(235, 232, 220), C(95, 62, 40), C(200, 35, 35), C(38, 32, 28)
	local CAMO1, CAMO2, CAMO3 = C(85, 95, 60), C(125, 105, 70), C(48, 54, 38)
	local camo = {
		ci(0.3, 0.12, 0.5, 0.14, CAMO2), ci(0.75, 0.3, 0.45, 0.12, CAMO3), ci(0.25, 0.45, 0.4, 0.15, CAMO3),
		ci(0.7, 0.58, 0.5, 0.13, CAMO2), ci(0.3, 0.75, 0.45, 0.12, CAMO2), ci(0.75, 0.88, 0.4, 0.12, CAMO3),
		ci(0.55, 0.2, 0.25, 0.08, CAMO3), ci(0.45, 0.65, 0.25, 0.08, CAMO3),
	}
	local batt = {}
	for _, t in ipairs({ -0.6, -0.2, 0.2, 0.6 }) do
		batt[#batt + 1] = P(T, CY, V(0.3, 0.16, 0.16), C(255, 200, 40), SP, 0.62 * t, 0.79 * t, -0.6, 0, 0, 90)
	end
	S({ Id = "SecurityGuard_Epic", Character = "SecurityGuard", Rarity = "Epic", Name = "Action Hero Guard",
		Desc = "Wrong building. Wrong night. Wrong security guard.",
		Outfit = { Shirt = TANKC, Pants = CAMO1, ArmsSkin = true },
		HideFace = true,
		Parts = join(batt, {
			-- bandana rouge
			P(H, CY, V(0.26, 1.33, 1.33), BAND, FA, 0, 0.4, 0, 0, 0, 90),
			P(H, B, V(0.3, 0.25, 0.2), BAND, FA, 0, 0.38, 0.68, o(SPH)),
			-- aviateurs + cure-dent
			P(H, B, V(1.24, 0.05, 0.06), GOLD, ME, 0, 0.21, -0.63),
			P(H, B, V(0.32, 0.04, 0.04), C(230, 210, 160), WO, 0.2, -0.3, -0.64, 0, 20, -15),
			-- bandoulière de piles (devant + dos)
			P(T, B, V(0.28, 2.7, 0.06), LEATHER, SP, 0, 0, -0.54, 0, 0, -38),
			P(T, B, V(0.28, 2.7, 0.06), LEATHER, SP, 0, 0, 0.54, 0, 0, 38),
			-- plaques militaires
			P(T, B, V(0.2, 0.3, 0.04), SIL, ME, -0.05, 0.45, -0.56),
			-- lampe torche géante + faisceau
			{ Limb = RA, Asset = "SecurityGuard_Epic_Flashlight", Size = V(0.75, 1.35, 1.42), Offset = CFrame.new(0, -0.95, -0.55), Light = C(255, 245, 200) },
			P(RA, CY, V(3.0, 0.6, 0.6), C(255, 250, 200), NE, 0, -0.75, -2.75, 0, 90, 0, { Transparency = 0.8 }),
			P(RA, CY, V(2.0, 1.1, 1.1), C(255, 250, 200), NE, 0, -0.75, -5.1, 0, 90, 0, { Transparency = 0.88 }),
			-- sirènes d'épaule
			P(LA, B, V(0.42, 0.36, 0.42), RED, NE, 0, 1.22, 0, o(SPH, { Anim = { Pulse = 0.7, PulseSpeed = 12, Seed = 0 }, Light = C(255, 40, 40) })),
			P(RA, B, V(0.42, 0.36, 0.42), C(40, 90, 255), NE, 0, 1.22, 0, o(SPH, { Anim = { Pulse = 0.7, PulseSpeed = 12, Seed = 0.26 }, Light = C(40, 90, 255) })),
			-- ceinturon
			P(T, B, V(2.04, 0.22, 1.04), BLK, SP, 0, -0.9, 0),
			P(T, B, V(0.4, 0.26, 0.06), SIL, ME, 0, -0.9, -0.53),
		}, mir(H, B, V(0.14, 0.55, 0.06), BAND, FA, -0.12, 0.12, 0.72, 0, 0, 15),
		mir(H, B, V(0.44, 0.27, 0.06), C(25, 25, 30), SP, -0.26, 0.1, -0.63, o(SPH, { Reflect = 0.08 })),
		mir(T, B, V(0.04, 0.55, 0.04), SIL, ME, -0.15, 0.75, -0.53, 0, 0, 25),
		pair(LA, RA, B, V(1.1, 0.22, 1.1), C(35, 35, 35), SP, 0, 0.95, 0),
		pair(LA, RA, B, V(1.08, 0.45, 1.08), C(40, 35, 30), SP, 0, -0.75, 0),
		pair(LL, RL, B, V(1.1, 0.8, 1.18), BOOTC, SP, 0, -0.62, -0.05),
		pair(LL, RL, B, V(1.14, 0.14, 1.3), BLK, SP, 0, -0.96, -0.1),
		pair(LL, RL, B, V(1.08, 0.4, 0.25), BLK, SP, 0, 0.05, -0.52, o(SPH))),
		Paint = {
			faceKit({ NoEyes = true, Brow = "angry", Mouth = "smirk", Stubble = C(60, 45, 40) }),
			face(H, "Front", { ln(0.62, 0.55, 0.72, 0.62, 3, C(150, 60, 50)) }), -- cicatrice
			face(T, "Front", {
				ci(0.25, 0.72, 0.18, 0.1, C(150, 130, 100), { Transparency = 0.55 }), ci(0.72, 0.85, 0.14, 0.08, C(150, 130, 100), { Transparency = 0.55 }),
				ci(0.8, 0.2, 0.1, 0.06, C(150, 130, 100), { Transparency = 0.6 }),
				bx(0.3, 0.6, 0.02, 0.1, C(170, 160, 140), { Rotation = 20 }),
			}),
			face(T, "Back", {
				tx(0.5, 0.25, 0.9, 0.12, "NIGHT SHIFT", C(60, 60, 60), "Black"),
				tx(0.5, 0.75, 0.9, 0.09, "NOT ON MY WATCH", C(120, 30, 30), "Black"),
			}),
			face(LL, "Front", camo), face(RL, "Front", camo),
			face(LL, "Left", camo), face(RL, "Right", camo),
			face(LL, "Back", camo), face(RL, "Back", camo),
			face(LL, "Right", camo), face(RL, "Left", camo),
		},
		HitColor = C(255, 245, 200),
	})

	local STEEL, DSTEEL, CHR, CY2, BODY = C(190, 200, 220), C(70, 80, 100), C(225, 232, 242), C(40, 200, 255), C(35, 42, 62)
	local circuit = {
		bx(0.5, 0.5, 0.06, 1, CY2), bx(0.5, 0.3, 0.5, 0.03, CY2), ci(0.25, 0.3, 0.12, 0.06, CY2),
	}
	S({ Id = "SecurityGuard_Legendary", Character = "SecurityGuard", Rarity = "Legendary", Name = "Cyber Sentinel",
		Desc = "Scanning for overtime violations... Violation detected.",
		Outfit = { Shirt = BODY, Pants = BODY, Skin = C(170, 180, 200) },
		HideFace = true, HideHair = true,
		Parts = join({
			-- casque chromé + visière défilante
			P(H, B, V(1.4, 1.34, 1.42), CHR, ME, 0, 0.08, 0, o(SPH, { Reflect = 0.25 })),
			P(H, B, V(1.3, 0.36, 0.34), C(10, 20, 30), GL, 0, 0.12, -0.55, o(SPH)),
			P(H, B, V(1.0, 0.2, 0.04), CY2, NE, 0, 0.12, -0.72, { Text = { Text = "SCANNING... OVERTIME DETECTED... ", Font = "Code",
				Color = WHT, Scroll = 0.25, Width = 4 } }),
			P(H, B, V(0.16, 0.32, 1.3), CY2, NE, 0, 0.72, 0.05, o(SPH)),
			P(H, CY, V(0.7, 0.06, 0.06), STEEL, ME, 0.72, 0.6, 0.15, 0, 0, 90),
			P(H, BA, V(0.14, 0.14, 0.14), RED, NE, 0.72, 0.98, 0.15, { Anim = { Pulse = 0.8, PulseSpeed = 6 } }),
			P(H, B, V(1.0, 0.3, 0.35), DSTEEL, ME, 0, -0.45, -0.5),
			-- badge holographique
			P(H, B, V(0.55, 0.65, 0.05), GOLD, NE, 0, 1.75, 0, { Transparency = 0.25, Anim = { Spin = 120, Bob = 0.15, Seed = 12 },
				Text = { Text = "★", Color = WHT, Face = "Both" } }),
			-- plastron + cœur réacteur
			P(T, B, V(2.1, 1.3, 0.2), STEEL, ME, 0, 0.35, -0.55, { Reflect = 0.15 }),
			P(T, CY, V(0.08, 0.78, 0.78), DSTEEL, ME, 0, 0.35, -0.66, 0, 90, 0),
			P(T, CY, V(0.1, 0.6, 0.6), CY2, NE, 0, 0.35, -0.69, 0, 90, 0, { Anim = { Pulse = 0.4, React = true }, Light = CY2 }),
			P(T, B, V(1.2, 0.28, 0.12), DSTEEL, ME, 0, -0.45, -0.53),
			P(T, B, V(1.2, 0.28, 0.12), DSTEEL, ME, 0, -0.78, -0.53),
			P(T, B, V(1.5, 0.3, 1.15), DSTEEL, ME, 0, 1.05, 0),
			-- sac réacteur dorsal
			P(T, B, V(1.5, 1.5, 0.5), DSTEEL, ME, 0, 0.25, 0.75),
			-- drone d'épaule
			P(T, B, V(0.55, 0.3, 0.55), DSTEEL, ME, 1.7, 1.8, 0.3, o(SPH, { Anim = { Bob = 0.15, Seed = 8 } })),
			P(T, BA, V(0.2, 0.2, 0.2), RED, NE, 1.7, 1.78, 0.03, { Anim = { Bob = 0.15, Seed = 8 } }),
			P(T, CY, V(0.04, 0.75, 0.75), CY2, GL, 1.7, 1.98, 0.3, 0, 0, 90, { Transparency = 0.4, Anim = { Bob = 0.15, Seed = 8 } }),
			-- ceinture
			P(T, B, V(2.06, 0.3, 1.06), DSTEEL, ME, 0, -0.88, 0),
			P(T, B, V(0.4, 0.2, 0.06), CY2, NE, 0, -0.88, -0.55),
			-- matraque à impulsion (main droite, v4 : objet tenu)
			P(RA, CY, V(1.5, 0.17, 0.17), DSTEEL, ME, 0, -1.05, -0.6, 0, 90, 0),
			P(RA, CY, V(0.07, 0.38, 0.38), CHR, ME, 0, -1.05, -0.88, 0, 90, 0),
			P(RA, CY, V(0.6, 0.2, 0.2), CY2, NE, 0, -1.05, -1.62, 0, 90, 0, { Anim = { Pulse = 0.4, PulseSpeed = 7, React = true } }),
			-- transformation : laser de scan + ailerons
			P(H, B, V(2.6, 0.04, 3.0), RED, NE, 0, 0.12, -2.2, { Transform = true, Transparency = 0.5, Anim = { Swing = 25, SwingAxis = "X", SwingSpeed = 2 } }),
			P(T, WE, V(0.1, 1.4, 0.9), CY2, NE, -0.6, 0.9, 1.25, 0, 0, 0, { Transform = true }),
			P(T, WE, V(0.1, 1.4, 0.9), CY2, NE, 0.6, 0.9, 1.25, 0, 0, 0, { Transform = true }),
		}, mir(H, CY, V(0.25, 0.6, 0.6), DSTEEL, ME, -0.7, 0.05, 0),
		mir(H, CY, V(0.27, 0.36, 0.36), CY2, NE, -0.71, 0.05, 0),
		mir(T, B, V(0.2, 0.9, 0.06), CY2, NE, -0.4, 0.25, 1.02),
		pair(LA, RA, B, V(1.35, 0.75, 1.35), CHR, ME, 0, 0.85, 0, o(SPH, { Reflect = 0.2 })),
		pair(LA, RA, B, V(1.42, 0.08, 1.42), CY2, NE, 0, 0.82, 0, o(SPH)),
		pair(LA, RA, B, V(1.12, 0.85, 1.12), STEEL, ME, 0, -0.45, 0),
		pair(LA, RA, B, V(1.14, 0.06, 1.14), CY2, NE, 0, -0.2, 0),
		pair(LL, RL, B, V(1.08, 0.7, 0.2), STEEL, ME, 0, 0.5, -0.52),
		pair(LL, RL, B, V(0.7, 0.45, 0.35), CHR, ME, 0, 0, -0.55, o(SPH)),
		pair(LL, RL, B, V(1.12, 0.95, 1.15), STEEL, ME, 0, -0.5, -0.02),
		pair(LL, RL, B, V(0.12, 0.75, 0.04), CY2, NE, 0, -0.45, -0.6),
		pair(LL, RL, B, V(1.16, 0.12, 1.22), CY2, NE, 0, -0.97, -0.02)),
		Paint = {
			{ Limb = T, Face = "Left", Glow = true, Elements = circuit },
			{ Limb = T, Face = "Right", Glow = true, Elements = circuit },
			{ Limb = LA, Face = "Front", Glow = true, Elements = { bx(0.5, 0.18, 0.08, 0.2, CY2) } },
			{ Limb = RA, Face = "Front", Glow = true, Elements = { bx(0.5, 0.18, 0.08, 0.2, CY2) } },
			{ Limb = LL, Face = "Back", Glow = true, Elements = { bx(0.5, 0.5, 0.08, 1, CY2) } },
			{ Limb = RL, Face = "Back", Glow = true, Elements = { bx(0.5, 0.5, 0.08, 1, CY2) } },
		},
		FX = { PowerAura = CY2, HandTrails = CY2 },
		Highlight = { Outline = CY2 },
		HitColor = CY2,
	})
end

return L
