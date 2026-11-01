--[[
	SkinList.Pack2 — skins v3 (Rare / Epic / Legendary) de ITGuy, Accountant, CEO, HRManager (agent "pack2").
	Chaque entrée REMPLACE l'entrée de même Id dans SkinList. Format : CONTRACT_SKINS + champs v3
	(Mesh, Asset, Paint, HideFace, HideHair) + options avancées documentées en tête de Modules/SkinBuilder.
	Repères R6 : tête 2x1x1 (visuel ~1,25, dessus ~+0,62, visage en -Z), buste 2x2x1 (avant -Z), membres 1x2x1 (main à y -1).
	Paint : Pos/Size en échelle 0..1 de la face (centre), vue de face.
]]
local C, V = Color3.fromRGB, Vector3.new
local rad = math.rad
local SP, NE, GL, ME, FA, FO, WO, FF = "SmoothPlastic", "Neon", "Glass", "Metal", "Fabric", "Foil", "Wood", "ForceField"
local H, T, LA, RA, LL, RL = "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"
local B, BA, CY = "Block", "Ball", "Cylinder"

local WHT, BLK, DARK, GOLD = C(245, 245, 245), C(18, 18, 22), C(35, 35, 42), C(255, 200, 40)

-- pièce soudée à un membre (rotations en degrés) ; opt = champs en plus (Mesh, Transparency, Anim, Text...)
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
-- forme lisse (SpecialMesh) : "Sphere" | "Cylinder" | "Wedge" | "Brick" | "Head"
local function M(part, mesh, scale)
	part.Mesh = { Type = mesh, Scale = scale }
	return part
end
-- ellipsoïde (bloc + mesh sphère)
local function E(limb, size, col, mat, x, y, z, rx, ry, rz, opt)
	return M(P(limb, B, size, col, mat, x, y, z, rx, ry, rz, opt), "Sphere")
end
-- pièce générée (ReplicatedStorage.SkinAssets) : garde sa texture (pas de Color / Material)
local function A(limb, asset, size, x, y, z, rx, ry, rz, opt)
	if type(rx) == "table" then
		opt, rx = rx, nil
	end
	local t = P(limb, B, size, nil, nil, x, y, z, rx, ry, rz)
	t.Color, t.Material, t.Asset = nil, nil, asset
	for k, v in pairs(opt or {}) do
		t[k] = v
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
-- même pièce sur les deux bras / les deux jambes ; x miroir (x positif = côté extérieur)
local function pairA(shape, size, col, mat, x, y, z, opt, mesh)
	local a = P(LA, shape, size, col, mat, -x, y, z, opt)
	local b = P(RA, shape, size, col, mat, x, y, z, opt)
	if mesh then
		M(a, mesh)
		M(b, mesh)
	end
	return { a, b }
end
local function pairL(shape, size, col, mat, x, y, z, opt, mesh)
	local a = P(LL, shape, size, col, mat, -x, y, z, opt)
	local b = P(RL, shape, size, col, mat, x, y, z, opt)
	if mesh then
		M(a, mesh)
		M(b, mesh)
	end
	return { a, b }
end
-- pièce sur un anneau autour du buste (orbites Anim.Circle)
local function ring(limb, shape, size, col, mat, r, y, ang, opt)
	local a = rad(ang)
	return P(limb, shape, size, col, mat, r * math.cos(a), y, -r * math.sin(a), 0, ang + 90, 0, opt)
end

-- éléments de peinture (SurfaceGui)
local function bx(x, y, w, h, col, opt)
	local e = { Type = "Box", Pos = { x, y }, Size = { w, h }, Color = col }
	if opt then
		for k, v in pairs(opt) do
			e[k] = v
		end
	end
	return e
end
local function ci(x, y, w, h, col, opt)
	local e = bx(x, y, w, h, col, opt)
	e.Type = "Circle"
	return e
end
local function tx(x, y, w, h, text, col, font, opt)
	local e = bx(x, y, w, h, col, opt)
	e.Type = "Text"
	e.Text = text
	e.Font = font or "Black"
	return e
end
local function ln(x, y, w, h, col, rot, opt)
	local e = bx(x, y, w, h, col, opt)
	e.Type = "Line"
	e.Rotation = rot
	return e
end
local function face(limb, side, elements)
	return { Limb = limb, Face = side, Elements = elements }
end
-- chaussures peintes sur le bas des jambes (4 faces) + lacets + semelle et bout arrondi en pièces
local function shoes(col, sole, lace, opt)
	opt = opt or {}
	local h = opt.h or 0.16
	local y = 1 - h / 2
	local paint, parts = {}, {}
	for _, leg in ipairs({ LL, RL }) do
		local front = { bx(0.5, y, 1.02, h + 0.01, col) }
		if lace then
			for i = 0, 2 do
				front[#front + 1] = ln(0.5, 1 - h + 0.03 + i * (h - 0.06) / 2.5, 0.42, 0.018, lace, 0)
			end
			front[#front + 1] = bx(0.5, 1 - h + 0.02, 0.5, 0.025, opt.tongue or col)
		end
		if opt.stripe then
			front[#front + 1] = bx(0.5, 1 - 0.015, 1.02, 0.03, opt.stripe)
		end
		paint[#paint + 1] = face(leg, "Front", front)
		local side = { bx(0.5, y, 1.02, h + 0.01, col) }
		if opt.swoosh then
			side[#side + 1] = ln(0.5, y + 0.01, 0.7, 0.025, opt.swoosh, -12)
		end
		paint[#paint + 1] = face(leg, "Left", side)
		paint[#paint + 1] = face(leg, "Right", side)
		paint[#paint + 1] = face(leg, "Back", { bx(0.5, y, 1.02, h + 0.01, col), bx(0.5, 1 - h + 0.02, 0.3, 0.04, opt.heel or sole) })
		if opt.toe ~= false then
			parts[#parts + 1] = E(leg, V(0.98, 0.3, 0.36), col, opt.mat or SP, 0, -0.86, -0.5)
		end
		if sole then
			parts[#parts + 1] = P(leg, B, V(1.06, 0.1, 1.26), sole, opt.soleMat or SP, 0, -0.96, -0.12, opt.soleOpt)
		end
	end
	return paint, parts
end

local L = {}
local function S(def)
	def.HideIdentity = def.HideIdentity ~= false
	L[#L + 1] = def
end

-- ===================== IT GUY =====================
do
	-- ---------- Rare : Hoodie Hacker ----------
	local HOOD, HOOD2, JEAN, G = C(38, 40, 52), C(26, 28, 36), C(48, 62, 98), C(70, 255, 120)
	local shoeP, shoeX = shoes(C(30, 30, 34), G, WHT, { h = 0.15, soleMat = NE, heel = G })
	S({ Id = "ITGuy_Rare", Character = "ITGuy", Rarity = "Rare", Name = "Hoodie Hacker",
		Desc = "\"I'm in.\" (He is not in. He forgot his password.)",
		Outfit = { Shirt = HOOD, Pants = JEAN },
		HideHair = true,
		Parts = join({
			-- capuche relevée
			E(H, V(1.52, 1.5, 1.4), HOOD, FA, 0, 0.08, 0.18),
			E(H, V(1.42, 1.42, 0.24), HOOD2, FA, 0, 0.08, -0.4),
			E(T, V(1.7, 0.36, 1.15), HOOD, FA, 0, 1.02, 0.08),
			E(T, V(1.3, 0.6, 0.5), HOOD, FA, 0, 0.95, 0.42),
			-- visière à code défilant
			P(H, B, V(1.3, 0.28, 0.1), C(6, 18, 10), GL, 0, 0.12, -0.63, { Text = { Text = "01101 sudo 10010 ssh 0110 ", Font = "Code",
				Color = G, Scroll = 0.4, Width = 3 } }),
			P(H, B, V(1.3, 0.03, 0.11), G, NE, 0, 0.27, -0.63),
			P(H, B, V(0.08, 0.26, 0.3), G, NE, -0.66, 0.12, -0.5),
			P(H, B, V(0.08, 0.26, 0.3), G, NE, 0.66, 0.12, -0.5),
			-- cordons de capuche
			P(T, B, V(0.05, 0.7, 0.05), WHT, SP, -0.24, 0.55, -0.53),
			P(T, B, V(0.05, 0.7, 0.05), WHT, SP, 0.24, 0.55, -0.53),
			P(T, B, V(0.09, 0.13, 0.09), G, NE, -0.24, 0.16, -0.53),
			P(T, B, V(0.09, 0.13, 0.09), G, NE, 0.24, 0.16, -0.53),
			-- bord-côtes (poignets, taille)
			P(T, B, V(2.04, 0.22, 1.04), HOOD2, FA, 0, -0.89, 0),
		}, pairA(B, V(1.05, 0.2, 1.05), HOOD2, FA, 0, -0.72, 0), {
			-- canette d'energy drink
			P(RA, CY, V(0.6, 0.34, 0.34), C(22, 22, 28), ME, 0, -1.18, -0.38, 0, 0, 90),
			P(RA, CY, V(0.2, 0.36, 0.36), G, NE, 0, -1.2, -0.38, 0, 0, 90),
			-- portable sous le bras
			P(LA, B, V(0.1, 0.95, 1.35), C(175, 180, 190), ME, -0.57, -0.35, 0.05),
			P(LA, B, V(0.02, 0.28, 0.28), G, NE, -0.63, -0.35, 0.05),
		}, shoeX),
		Paint = join({
			face(H, "Front", {
				ln(0.6, 0.74, 0.22, 0.04, C(60, 35, 30), -12),
				bx(0.5, 0.8, 0.5, 0.16, C(40, 40, 45), { Transparency = 0.82, Corner = 0.5 }),
			}),
			face(T, "Front", {
				tx(0.5, 0.36, 0.62, 0.2, "sudo", G, "Code"),
				tx(0.5, 0.5, 0.8, 0.07, "make me a sandwich", C(150, 160, 170), "Code"),
				bx(0.5, 0.76, 0.66, 0.26, HOOD2, { Corner = 0.25, Stroke = { C(62, 66, 82), 2 } }),
				ln(0.5, 0.65, 0.66, 0.012, C(62, 66, 82), 0),
			}),
			face(T, "Back", {
				tx(0.5, 0.3, 0.7, 0.26, "404", G, "Code"),
				tx(0.5, 0.52, 0.86, 0.1, "SLEEP NOT FOUND", WHT, "Code"),
				bx(0.5, 0.05, 0.8, 0.1, HOOD2, { Corner = 0.5 }),
			}),
			face(LA, "Left", { bx(0.5, 0.4, 0.08, 0.7, G) }),
			face(RA, "Right", { bx(0.5, 0.4, 0.08, 0.7, G) }),
			face(LL, "Front", { ln(0.3, 0.12, 0.3, 0.015, C(80, 95, 140), 30), bx(0.45, 0.5, 0.3, 0.06, C(200, 210, 230), { Transparency = 0.3 }) }),
			face(RL, "Front", { ln(0.7, 0.12, 0.3, 0.015, C(80, 95, 140), -30) }),
			face(LL, "Left", { ln(0.5, 0.45, 0.012, 0.8, C(200, 170, 80), 0) }),
			face(RL, "Right", { ln(0.5, 0.45, 0.012, 0.8, C(200, 170, 80), 0) }),
		}, shoeP),
		HideFace = true,
	})

	-- ---------- Epic : Retro Pro Gamer ----------
	local PURP, TEAL, PINK, YEL, NAVY = C(95, 55, 175), C(40, 205, 190), C(255, 70, 160), C(255, 215, 60), C(30, 28, 58)
	local eShoeP, eShoeX = shoes(WHT, PINK, PINK, { h = 0.3, stripe = TEAL, swoosh = TEAL, heel = TEAL })
	local function sleeves(limb)
		local t = {}
		for _, f in ipairs({ "Front", "Back", "Left", "Right" }) do
			t[#t + 1] = face(limb, f, { bx(0.5, 0.18, 1.02, 0.36, TEAL), bx(0.5, 0.37, 1.02, 0.04, PINK) })
		end
		return t
	end
	S({ Id = "ITGuy_Epic", Character = "ITGuy", Rarity = "Epic", Name = "Retro Pro Gamer",
		Desc = "Press START to take a break. There is no break.",
		Outfit = { Shirt = PURP, Pants = NAVY },
		HideHair = true,
		Parts = join({
			-- cheveux
			E(H, V(1.34, 0.46, 1.34), C(55, 35, 28), SP, 0, 0.5, 0.04),
			E(H, V(1.0, 0.26, 0.34), C(55, 35, 28), SP, 0.1, 0.46, -0.5, 0, 0, -10),
			E(H, V(1.3, 0.85, 0.5), C(55, 35, 28), SP, 0, 0.18, 0.4),
			-- casque audio
			E(H, V(1.0, 0.14, 0.34), DARK, SP, 0, 0.74, 0),
			P(H, B, V(0.13, 0.5, 0.3), DARK, SP, -0.66, 0.48, 0, 0, 0, -14),
			P(H, B, V(0.13, 0.5, 0.3), DARK, SP, 0.66, 0.48, 0, 0, 0, 14),
			P(H, CY, V(0.3, 0.72, 0.72), PINK, SP, -0.74, 0.08, 0),
			P(H, CY, V(0.3, 0.72, 0.72), PINK, SP, 0.74, 0.08, 0),
			P(H, CY, V(0.06, 0.5, 0.5), TEAL, NE, -0.91, 0.08, 0),
			P(H, CY, V(0.06, 0.5, 0.5), TEAL, NE, 0.91, 0.08, 0),
			P(H, B, V(0.05, 0.05, 0.5), DARK, SP, 0.72, -0.16, -0.32, 0, 22, 0),
			P(H, BA, V(0.14, 0.14, 0.14), PINK, NE, 0.6, -0.2, -0.58),
			-- lunettes pixel
			P(H, B, V(1.24, 0.09, 0.06), BLK, SP, 0, 0.23, -0.64),
			P(H, B, V(0.46, 0.16, 0.06), BLK, SP, -0.28, 0.12, -0.64),
			P(H, B, V(0.46, 0.16, 0.06), BLK, SP, 0.28, 0.12, -0.64),
			P(H, B, V(0.3, 0.08, 0.06), BLK, SP, -0.32, 0.0, -0.64),
			P(H, B, V(0.3, 0.08, 0.06), BLK, SP, 0.32, 0.0, -0.64),
			P(H, B, V(0.08, 0.08, 0.02), WHT, NE, -0.4, 0.16, -0.675),
			P(H, B, V(0.08, 0.08, 0.02), WHT, NE, 0.16, 0.16, -0.675),
			-- pièce d'or qui tourne + cœurs
			P(H, CY, V(0.12, 0.72, 0.72), GOLD, NE, 0, 1.55, 0, 0, 90, 0, { Anim = { Spin = 180, Bob = 0.15, Seed = 30 } }),
			P(H, CY, V(0.16, 0.42, 0.42), C(255, 170, 0), ME, 0, 1.55, 0, 0, 90, 0, { Anim = { Spin = 180, Bob = 0.15, Seed = 30 } }),
			P(H, B, V(1.6, 0.45, 0.06), PINK, SP, 0, 2.15, 0, { Transparency = 1,
				Text = { Text = "♥ ♥ ♥", Color = C(255, 50, 90), Font = "Black", Face = "Both" }, Anim = { Bob = 0.15, Seed = 30 } }),
			-- "PRESS START" clignotant sur le maillot
			P(T, B, V(1.7, 0.3, 0.02), PURP, SP, 0, -0.62, -0.52, { Transparency = 1,
				Text = { Text = "PRESS START", Font = "Arcade", Color = YEL, Blink = 1.2 } }),
			-- manette (pièce générée)
			A(RA, "ITGuy_Epic_Controller", V(1.1, 0.8, 0.5), -0.3, -1.25, -0.6, -25, 0, 0),
			-- sac à dos cartouche
			P(T, B, V(1.5, 1.6, 0.32), C(150, 152, 165), SP, 0, 0.0, 0.68),
			P(T, B, V(1.5, 0.14, 0.36), C(118, 120, 132), SP, 0, 0.74, 0.68),
			P(T, B, V(1.2, 0.86, 0.02), YEL, SP, 0, 0.12, 0.85, { Text = { Text = "MEGA\nDESK 64", Font = "Arcade", Color = PURP, Face = "Back" } }),
			P(T, B, V(1.0, 0.16, 0.2), GOLD, ME, 0, -0.84, 0.66),
			P(T, B, V(0.2, 0.95, 0.06), NAVY, SP, -0.55, 0.52, -0.53),
			P(T, B, V(0.2, 0.95, 0.06), NAVY, SP, 0.55, 0.52, -0.53),
		}, pairA(B, V(1.08, 0.22, 1.08), TEAL, NE, 0, -0.62, 0), eShoeX),
		Paint = join({
			face(H, "Front", {
				bx(0.5, 0.68, 0.3, 0.11, C(90, 30, 40), { Corner = 0.6 }),
				bx(0.5, 0.645, 0.26, 0.035, WHT),
				ci(0.5, 0.715, 0.12, 0.045, C(255, 110, 130)),
			}),
			face(T, "Front", {
				ln(0.38, 0.08, 0.3, 0.05, TEAL, 40), ln(0.62, 0.08, 0.3, 0.05, TEAL, -40),
				bx(0.04, 0.5, 0.08, 1.02, PINK), bx(0.96, 0.5, 0.08, 1.02, PINK),
				tx(0.5, 0.4, 0.6, 0.3, "1UP", YEL, "Arcade"),
				ci(0.22, 0.22, 0.1, 0.1, PINK), ci(0.78, 0.22, 0.1, 0.1, TEAL),
			}),
			face(T, "Back", { tx(0.5, 0.1, 0.8, 0.12, "PLAYER", TEAL, "Arcade"), bx(0.04, 0.5, 0.08, 1.02, PINK), bx(0.96, 0.5, 0.08, 1.02, PINK) }),
			face(LL, "Left", { bx(0.5, 0.42, 0.14, 0.84, PINK), bx(0.5, 0.42, 0.04, 0.84, WHT) }),
			face(RL, "Right", { bx(0.5, 0.42, 0.14, 0.84, PINK), bx(0.5, 0.42, 0.04, 0.84, WHT) }),
			face(LL, "Front", { bx(0.5, 0.48, 0.5, 0.12, TEAL, { Corner = 0.3 }) }),
			face(RL, "Front", { bx(0.5, 0.48, 0.5, 0.12, TEAL, { Corner = 0.3 }) }),
		}, sleeves(LA), sleeves(RA), eShoeP),
		HideFace = true,
		FX = { Orbit = { Color = PINK, Count = 4, Shape = "Block", Size = 0.25, Speed = 2 } },
		HitColor = PINK,
	})

	-- ---------- Legendary : Root Access ----------
	local VOID, GN, GD, CHROME = C(10, 12, 16), C(60, 255, 120), C(20, 110, 55), C(92, 100, 115)
	local lShoeP, lShoeX = shoes(VOID, GN, GN, { h = 0.3, soleMat = NE, heel = GN, stripe = GN })
	local screens = {}
	for i, a in ipairs({ 0, 90, 180, 270 }) do
		screens[#screens + 1] = ring(T, B, V(1.15, 0.78, 0.04), C(30, 200, 100), GL, 2.6, 0.7, a, { Transparency = 0.4,
			Text = { Text = ({ "01011\n11010", "ACCESS\nGRANTED", "rm -rf\nmonday", "ping\nboss" })[i], Font = "Code", Color = GN, Face = "Both" },
			Anim = { Circle = 0.7, Bob = 0.2, Seed = 40 } })
	end
	local leds = {}
	for i = 1, 5 do
		leds[#leds + 1] = P(T, B, V(0.9, 0.08, 0.03), GN, NE, 0, 0.75 - i * 0.28, 1.09, { Anim = { Pulse = 0.7, PulseSpeed = 3 + i, Seed = 40 + i } })
	end
	-- auréole de données : anneau de 8 segments néon derrière la tête
	for i = 0, 7 do
		local a = i * 45
		leds[#leds + 1] = P(H, B, V(0.8, 0.08, 0.05), GN, NE, 1.05 * math.cos(rad(a)), 0.45 + 1.05 * math.sin(rad(a)), 0.85, 0, 0, a + 90,
			{ Anim = { Pulse = 0.5, PulseSpeed = 2, Seed = 49 } })
	end
	S({ Id = "ITGuy_Legendary", Character = "ITGuy", Rarity = "Legendary", Name = "Root Access",
		Desc = "Admin privileges: the entire building. Including you.",
		Outfit = { Shirt = VOID, Pants = VOID, Skin = C(14, 16, 20) },
		HideHair = true,
		HideFace = true,
		Parts = join(screens, leds, {
			-- capuche à liseré néon
			E(H, V(1.62, 1.56, 1.46), VOID, FA, 0, 0.12, 0.2),
			E(H, V(0.55, 0.7, 0.55), VOID, FA, 0, 0.72, 0.62, -35, 0, 0),
			E(H, V(1.5, 1.5, 0.2), GN, NE, 0, 0.1, -0.38),
			E(H, V(1.36, 1.36, 0.22), VOID, FA, 0, 0.1, -0.41),
			-- col / mantelet
			E(T, V(2.25, 0.5, 1.32), VOID, FA, 0, 1.0, 0.05),
			-- pans du manteau
			P(T, B, V(1.9, 1.6, 0.08), VOID, FA, 0, -1.6, 0.52, -8, 0, 0),
			P(T, B, V(1.9, 0.07, 0.1), GN, NE, 0, -2.39, 0.63, -8, 0, 0),
			P(T, B, V(0.66, 1.5, 0.08), VOID, FA, -0.66, -1.55, -0.52, 8, 0, 0),
			P(T, B, V(0.66, 1.5, 0.08), VOID, FA, 0.66, -1.55, -0.52, 8, 0, 0),
			-- circuits lumineux sur le buste
			P(T, B, V(0.05, 1.5, 0.04), GN, NE, -0.55, -0.1, -0.52, { Anim = { Pulse = 0.5, Seed = 46 } }),
			P(T, B, V(0.6, 0.05, 0.04), GN, NE, -0.27, 0.63, -0.52, { Anim = { Pulse = 0.5, Seed = 46 } }),
			P(T, B, V(0.05, 0.7, 0.04), GN, NE, 0.55, 0.3, -0.52, { Anim = { Pulse = 0.5, Seed = 47 } }),
			-- clavier flottant (pièce générée)
			A(T, "ITGuy_Legendary_Keyboard", V(1.8, 0.3, 0.8), 0, -0.55, -1.45, 18, 0, 0, { Anim = { Bob = 0.12, Seed = 48 } }),
			P(T, B, V(1.7, 0.03, 0.6), GN, NE, 0, -0.72, -1.45, 18, 0, 0, { Transparency = 0.55, Anim = { Bob = 0.12, Seed = 48 } }),
			-- baie serveur dorsale
			P(T, B, V(1.4, 1.9, 0.55), CHROME, ME, 0, 0, 0.8),
			P(T, CY, V(0.9, 0.06, 0.06), CHROME, ME, 0.5, 1.35, 0.8, 0, 0, 90),
			P(T, BA, V(0.16, 0.16, 0.16), GN, NE, 0.5, 1.82, 0.8, { Anim = { Pulse = 0.8, PulseSpeed = 6 },
				Particles = { Kind = "Spark", Color = GN, Rate = 6, Speed = 3, Size = 0.25, Life = 0.7, React = true } }),
			-- épaulières, avant-bras, gants néon
		}, pairA(B, V(1.3, 0.5, 1.3), CHROME, ME, 0, 0.95, 0, nil, "Sphere"),
		pairA(B, V(1.32, 0.05, 1.32), GN, NE, 0, 0.78, 0),
		pairA(B, V(1.1, 0.55, 1.1), CHROME, ME, 0, -0.42, 0),
		pairA(B, V(1.12, 0.05, 1.12), GN, NE, 0, -0.2, 0),
		pairA(B, V(1.06, 0.3, 1.06), GN, NE, 0, -0.86, 0), {
			-- transformation : ailes de code + couronne "{ root }"
			P(T, B, V(2.6, 3.2, 0.05), C(30, 160, 80), GL, -1.9, 0.6, 0.95, 0, 25, 15, { Transform = true, Transparency = 0.45,
				Text = { Text = "01101 0110 1011 0101 1110 0010 1101 ", Font = "Code", Color = GN, Scroll = 0.3, Width = 3, Face = "Both" },
				Anim = { Swing = 6, SwingSpeed = 1.5, SwingAxis = "Y" } }),
			P(T, B, V(2.6, 3.2, 0.05), C(30, 160, 80), GL, 1.9, 0.6, 0.95, 0, -25, -15, { Transform = true, Transparency = 0.45,
				Text = { Text = "10010 1001 0100 1010 0001 1101 0010 ", Font = "Code", Color = GN, Scroll = 0.3, Width = 3, Face = "Both" },
				Anim = { Swing = 6, SwingSpeed = 1.5, SwingAxis = "Y", Seed = 2 } }),
			P(H, B, V(2.2, 0.5, 0.05), GN, SP, 0, 1.55, 0, { Transform = true, Transparency = 1,
				Text = { Text = "{ root }", Font = "Code", Color = GN, Face = "Both" }, Anim = { Float = true } }),
		}, lShoeX),
		Paint = join({
			face(H, "Front", {
				bx(0.34, 0.45, 0.2, 0.09, GN, { Rotation = 8, Corner = 0.4 }),
				bx(0.66, 0.45, 0.2, 0.09, GN, { Rotation = -8, Corner = 0.4 }),
				bx(0.5, 0.62, 0.44, 0.02, GD), bx(0.5, 0.7, 0.34, 0.02, GD), bx(0.5, 0.78, 0.22, 0.02, GD),
			}),
			face(T, "Front", {
				ln(0.2, 0.3, 0.01, 0.5, GD, 0), ln(0.3, 0.55, 0.2, 0.01, GD, 0), ci(0.4, 0.55, 0.05, 0.05, GN),
				ln(0.8, 0.6, 0.01, 0.5, GD, 0), ln(0.7, 0.35, 0.2, 0.01, GD, 0), ci(0.6, 0.35, 0.05, 0.05, GN),
				tx(0.5, 0.82, 0.6, 0.08, "uid=0(root)", GN, "Code"),
			}),
			face(T, "Back", { tx(0.5, 0.92, 0.8, 0.08, "sudo su", GN, "Code") }),
			face(LL, "Front", { ln(0.3, 0.4, 0.01, 0.6, GD, 0), ci(0.3, 0.1, 0.06, 0.03, GN) }),
			face(RL, "Front", { ln(0.7, 0.4, 0.01, 0.6, GD, 0), ci(0.7, 0.1, 0.06, 0.03, GN) }),
			face(LL, "Left", { bx(0.5, 0.42, 0.06, 0.84, GN) }),
			face(RL, "Right", { bx(0.5, 0.42, 0.06, 0.84, GN) }),
		}, lShoeP),
		FX = { PowerAura = GN, HandTrails = GN },
		Highlight = { Outline = GN },
		HitColor = GN,
	})
end

-- ===================== ACCOUNTANT =====================
do
	-- ---------- Rare : Noir Auditor ----------
	local TRENCH, TRENCH2, FED, BAND, GREY, SHOE = C(184, 150, 100), C(150, 118, 76), C(50, 44, 42), C(20, 18, 18), C(58, 58, 66), C(92, 54, 32)
	local rShoeP, rShoeX = shoes(SHOE, C(40, 25, 15), nil, { h = 0.13, heel = C(40, 25, 15) })
	S({ Id = "Accountant_Rare", Character = "Accountant", Rarity = "Rare", Name = "Noir Auditor",
		Desc = "The numbers never lie. People do. Every receipt is a clue.",
		Outfit = { Shirt = TRENCH, Pants = GREY },
		HideHair = true,
		HideFace = true,
		Parts = join({
			-- fedora
			P(H, CY, V(0.5, 1.2, 1.2), FED, FA, 0, 0.86, 0, 0, 0, 90),
			E(H, V(1.16, 0.28, 1.1), FED, FA, 0, 1.1, 0.02),
			P(H, CY, V(0.15, 1.23, 1.23), BAND, SP, 0, 0.68, 0, 0, 0, 90),
			P(H, CY, V(0.07, 2.05, 2.05), FED, FA, 0, 0.6, 0, -6, 0, 90),
			P(H, B, V(0.26, 0.34, 0.03), C(250, 248, 235), SP, 0.42, 0.84, -0.44, 0, -32, 6, { Text = { Text = "AUDIT", Color = C(170, 30, 30), Font = "Black" } }),
			-- col relevé + épaulettes
			P(T, B, V(1.7, 0.5, 0.12), TRENCH2, FA, 0, 1.18, 0.4, 12, 0, 0),
			P(T, B, V(0.12, 0.5, 0.75), TRENCH2, FA, -0.62, 1.16, 0.0, 0, 0, -10),
			P(T, B, V(0.12, 0.5, 0.75), TRENCH2, FA, 0.62, 1.16, 0.0, 0, 0, 10),
			P(T, B, V(0.55, 0.08, 0.32), TRENCH2, FA, -0.72, 1.02, 0),
			P(T, B, V(0.55, 0.08, 0.32), TRENCH2, FA, 0.72, 1.02, 0),
			-- ceinture à boucle
			P(T, B, V(2.06, 0.2, 1.06), TRENCH2, FA, 0, -0.38, 0),
			P(T, B, V(0.3, 0.26, 0.06), C(205, 175, 95), ME, 0, -0.38, -0.55),
			-- pans du trench (jusqu'aux genoux)
			P(T, B, V(0.98, 1.1, 0.08), TRENCH, FA, -0.52, -1.5, -0.55, 5, 0, 0),
			P(T, B, V(0.98, 1.1, 0.08), TRENCH, FA, 0.52, -1.5, -0.55, 5, 0, 0),
			P(T, B, V(2.04, 1.1, 0.08), TRENCH, FA, 0, -1.5, 0.55, -5, 0, 0),
		}, pairA(B, V(1.06, 0.14, 1.06), TRENCH2, FA, 0, -0.62, 0), {
			-- loupe + registre
			P(RA, CY, V(0.55, 0.12, 0.12), C(70, 40, 25), WO, 0, -1.2, -0.42, 0, 0, 90),
			P(RA, CY, V(0.08, 0.62, 0.62), GOLD, ME, 0, -0.66, -0.46, 0, 90, 0),
			P(RA, CY, V(0.05, 0.5, 0.5), C(200, 230, 255), GL, 0, -0.66, -0.47, 0, 90, 0, { Transparency = 0.45 }),
			P(LA, B, V(0.26, 0.82, 0.62), C(120, 28, 34), SP, 0, -1.05, -0.2, { Text = { Text = "LEDGER", Color = GOLD, Font = "Serif", Face = "Left" } }),
		}, rShoeX),
		Paint = join({
			face(H, "Front", {
				ln(0.37, 0.36, 0.2, 0.045, C(40, 30, 25), 10), ln(0.63, 0.36, 0.2, 0.045, C(40, 30, 25), -10),
				ci(0.38, 0.45, 0.09, 0.07, BLK), ci(0.62, 0.45, 0.09, 0.07, BLK),
				ln(0.48, 0.71, 0.2, 0.03, C(70, 40, 35), 0),
				ln(0.63, 0.73, 0.2, 0.02, C(225, 200, 150), -14),
				bx(0.5, 0.78, 0.55, 0.2, C(60, 50, 45), { Transparency = 0.85, Corner = 0.5 }),
			}),
			face(T, "Front", {
				bx(0.5, 0.06, 0.24, 0.13, WHT), bx(0.5, 0.12, 0.07, 0.2, C(120, 25, 30)),
				ln(0.36, 0.2, 0.36, 0.025, TRENCH2, 62), ln(0.64, 0.2, 0.36, 0.025, TRENCH2, -62),
				ln(0.56, 0.5, 0.01, 0.92, TRENCH2, 0),
				ci(0.34, 0.34, 0.06, 0.06, C(70, 50, 30)), ci(0.66, 0.34, 0.06, 0.06, C(70, 50, 30)),
				ci(0.34, 0.52, 0.06, 0.06, C(70, 50, 30)), ci(0.66, 0.52, 0.06, 0.06, C(70, 50, 30)),
				ci(0.34, 0.8, 0.06, 0.06, C(70, 50, 30)), ci(0.66, 0.8, 0.06, 0.06, C(70, 50, 30)),
				bx(0.2, 0.86, 0.26, 0.04, TRENCH2), bx(0.8, 0.86, 0.26, 0.04, TRENCH2),
			}),
			face(T, "Back", { bx(0.5, 0.16, 1.02, 0.32, TRENCH2), ln(0.5, 0.75, 0.01, 0.5, TRENCH2, 0) }),
			face(LL, "Front", { ln(0.5, 0.45, 0.01, 0.8, C(45, 45, 52), 0) }),
			face(RL, "Front", { ln(0.5, 0.45, 0.01, 0.8, C(45, 45, 52), 0) }),
		}, rShoeP),
	})

	-- ---------- Epic : Wall Street Wolf ----------
	local SHIRT, SUSP, TIE, NAVY, HAIR = C(240, 242, 250), C(205, 30, 42), C(255, 205, 40), C(26, 34, 64), C(48, 32, 24)
	local eShoeP, eShoeX = shoes(C(18, 18, 22), C(70, 45, 30), nil, { h = 0.14, heel = C(70, 45, 30) })
	local function stripes()
		local t = {}
		for i = 1, 9 do
			t[#t + 1] = bx(i / 10, 0.5, 0.008, 1.02, C(160, 185, 230))
		end
		return t
	end
	local pin = {}
	for i = 1, 4 do
		pin[#pin + 1] = bx(i / 5, 0.45, 0.012, 0.9, C(70, 80, 115))
	end
	local front = stripes()
	for _, e in ipairs({
		-- bretelles rouges + cravate jaune
		bx(0.27, 0.5, 0.1, 1.02, SUSP), bx(0.73, 0.5, 0.1, 1.02, SUSP),
		bx(0.5, 0.13, 0.13, 0.1, TIE, { Corner = 0.3 }),
		bx(0.5, 0.45, 0.16, 0.58, TIE, { Corner = 0.2 }),
		bx(0.5, 0.75, 0.115, 0.115, TIE, { Rotation = 45 }),
		ci(0.47, 0.3, 0.04, 0.04, SUSP), ci(0.53, 0.42, 0.04, 0.04, SUSP), ci(0.47, 0.54, 0.04, 0.04, SUSP), ci(0.53, 0.66, 0.04, 0.04, SUSP),
		bx(0.62, 0.3, 0.16, 0.13, WHT, { Stroke = { C(160, 185, 230), 1 } }),
		tx(0.62, 0.3, 0.14, 0.06, "$$", C(60, 140, 60), "Black"),
	}) do
		front[#front + 1] = e
	end
	local back = stripes()
	back[#back + 1] = ln(0.4, 0.5, 0.1, 1.1, SUSP, 12)
	back[#back + 1] = ln(0.6, 0.5, 0.1, 1.1, SUSP, -12)
	S({ Id = "Accountant_Epic", Character = "Accountant", Rarity = "Epic", Name = "Wall Street Wolf",
		Desc = "Buy low. Sell high. Yell constantly into a brick phone.",
		Outfit = { Shirt = SHIRT, Pants = NAVY, ArmsSkin = true },
		HideHair = true,
		HideFace = true,
		Parts = join({
			-- cheveux plaqués en arrière (brillants)
			E(H, V(1.34, 0.5, 1.36), HAIR, SP, 0, 0.46, 0.08, { Reflect = 0.06 }),
			E(H, V(1.3, 0.85, 0.55), HAIR, SP, 0, 0.18, 0.42, { Reflect = 0.06 }),
			E(H, V(1.12, 0.32, 0.55), HAIR, SP, 0, 0.62, -0.25, -14, 0, 0, { Reflect = 0.06 }),
			-- col de chemise + nœud de cravate
			E(T, V(1.15, 0.2, 0.95), SHIRT, SP, 0, 1.02, 0),
			P(T, B, V(0.34, 0.05, 0.3), SHIRT, SP, -0.2, 0.93, -0.5, -55, 0, -22),
			P(T, B, V(0.34, 0.05, 0.3), SHIRT, SP, 0.2, 0.93, -0.5, -55, 0, 22),
			P(T, B, V(0.24, 0.2, 0.08), TIE, SP, 0, 0.86, -0.53),
			-- pinces de bretelles
			P(T, B, V(0.18, 0.12, 0.06), GOLD, ME, -0.46, -0.86, -0.53),
			P(T, B, V(0.18, 0.12, 0.06), GOLD, ME, 0.46, -0.86, -0.53),
			-- veste jetée sur l'épaule
			P(T, B, V(0.95, 1.55, 0.1), NAVY, SP, 0.5, 0.12, 0.58, 0, 0, -8),
			P(T, B, V(0.95, 0.12, 0.5), NAVY, SP, 0.55, 1.02, 0.3, 0, 0, -8),
		}, pairA(B, V(1.06, 1.02, 1.06), SHIRT, SP, 0, 0.5, 0), pairA(B, V(1.16, 0.22, 1.16), SHIRT, SP, 0, -0.02, 0, nil, "Sphere"), {
			-- montre en or
			P(LA, B, V(1.08, 0.14, 1.08), GOLD, ME, 0, -0.7, 0),
			P(LA, CY, V(0.06, 0.3, 0.3), C(25, 25, 35), SP, -0.55, -0.7, 0),
			-- téléphone brique
			P(LA, B, V(0.32, 0.78, 0.26), C(40, 40, 46), SP, 0, -1.25, -0.32),
			P(LA, CY, V(0.42, 0.07, 0.07), C(25, 25, 28), SP, 0.08, -0.7, -0.32, 0, 0, 90),
			P(LA, B, V(0.22, 0.12, 0.02), C(150, 235, 150), NE, 0, -1.04, -0.46),
			-- liasse de billets
			P(RA, B, V(0.5, 0.22, 0.82), C(110, 195, 100), SP, 0, -1.15, -0.42),
			P(RA, B, V(0.46, 0.03, 0.82), C(135, 215, 125), SP, 0, -1.03, -0.48, 0, 22, 0),
			P(RA, B, V(0.52, 0.24, 0.14), GOLD, ME, 0, -1.15, -0.42),
			-- bandeau boursier flottant
			P(H, B, V(2.8, 0.42, 0.06), C(12, 18, 14), SP, 0, 1.6, 0, { Text = { Text = "▲ STONKS +420%   ▲ COFFEE +12%   ▼ MONDAYS -99%   ",
				Font = "Code", Color = C(80, 255, 120), Scroll = 0.22, Width = 5, Face = "Both" }, Anim = { Bob = 0.12, Seed = 50 } }),
			P(H, B, V(2.9, 0.05, 0.08), C(80, 255, 120), NE, 0, 1.84, 0, { Anim = { Bob = 0.12, Seed = 50 } }),
			P(H, B, V(2.9, 0.05, 0.08), C(80, 255, 120), NE, 0, 1.36, 0, { Anim = { Bob = 0.12, Seed = 50 } }),
		}, eShoeX),
		Paint = join({
			face(H, "Front", {
				ln(0.37, 0.34, 0.2, 0.045, HAIR, 14), ln(0.63, 0.32, 0.2, 0.045, HAIR, -4),
				ci(0.38, 0.45, 0.08, 0.09, BLK), ci(0.62, 0.45, 0.08, 0.09, BLK),
				bx(0.5, 0.7, 0.36, 0.1, WHT, { Corner = 0.5, Stroke = { C(80, 30, 30), 2 } }),
				ln(0.5, 0.7, 0.34, 0.012, C(200, 200, 200), 0),
			}),
			face(T, "Front", front),
			face(T, "Back", back),
			face(LL, "Front", pin), face(RL, "Front", pin),
			face(LL, "Left", pin), face(RL, "Right", pin),
		}, eShoeP),
		FX = { Orbit = { Color = C(110, 200, 100), Count = 4, Shape = "Block", Size = 0.4, Speed = 1.8 } },
		HitColor = C(110, 200, 100),
	})

	-- ---------- Legendary : Bull Market Baron ----------
	local EMER, EMER2, GOLD2, GN = C(18, 112, 66), C(12, 78, 46), C(205, 150, 30), C(80, 255, 120)
	local lShoeP, lShoeX = shoes(GOLD, GOLD2, nil, { h = 0.14, mat = ME, soleMat = ME, heel = GOLD2 })
	local gpin = {}
	for i = 1, 4 do
		gpin[#gpin + 1] = bx(i / 5, 0.45, 0.012, 0.9, C(200, 170, 60))
	end
	S({ Id = "Accountant_Legendary", Character = "Accountant", Rarity = "Legendary", Name = "Bull Market Baron",
		Desc = "When he charges, the market goes up. And so does your blood pressure.",
		Outfit = { Shirt = EMER, Pants = EMER2 },
		HideHair = true,
		HideFace = true,
		Parts = join({
			-- casque de taureau doré (pièce générée)
			A(H, "Accountant_Legendary_Horns", V(2.7, 2.6, 2.2), 0, 0.52, 0.05, 0, 0, 0, { Color = GOLD, Material = ME, Reflect = 0.15 }),
			-- naseaux fumants (transformation)
			P(H, BA, V(0.12, 0.12, 0.12), GOLD, NE, 0, -0.15, -0.64, { Transform = true,
				Particles = { Kind = "Smoke", Color = WHT, Rate = 12, Dir = "Front", Speed = 3, Size = 0.55, Life = 0.6, TransformOnly = true } }),
			-- monocle
			P(H, CY, V(0.03, 0.28, 0.28), C(255, 225, 130), GL, 0.2, 0.09, -0.645, 0, 90, 0, { Transparency = 0.55 }),
			-- revers dorés + pochette
			P(T, B, V(0.36, 1.05, 0.05), GOLD, FO, -0.4, 0.45, -0.53, 0, 0, 14),
			P(T, B, V(0.36, 1.05, 0.05), GOLD, FO, 0.4, 0.45, -0.53, 0, 0, -14),
			P(T, B, V(0.3, 0.16, 0.06), GN, NE, -0.6, 0.52, -0.53),
			-- chaîne de montre
			P(T, CY, V(0.7, 0.05, 0.05), GOLD, ME, 0.25, -0.38, -0.53, 0, 0, -12),
			-- cape émeraude bordée d'or
			P(T, B, V(2.1, 2.6, 0.08), EMER2, FA, 0, -0.35, 0.62, -6, 0, 0),
			P(T, B, V(2.12, 0.08, 0.1), GOLD, NE, 0, -1.645, 0.756, -6, 0, 0),
			P(T, B, V(2.2, 0.5, 0.1), GOLD, FO, 0, 1.12, 0.56, 18, 0, 0),
			-- pièce d'or géante (auréole)
			P(H, CY, V(0.14, 2.0, 2.0), GOLD, ME, 0, 0.55, 1.05, 0, 90, 0, { Reflect = 0.3, Anim = { Bob = 0.1, Seed = 52 } }),
			P(H, CY, V(0.17, 1.6, 1.6), GOLD2, ME, 0, 0.55, 1.05, 0, 90, 0, { Anim = { Bob = 0.1, Seed = 52 } }),
			P(H, B, V(1.2, 1.2, 0.2), GOLD, SP, 0, 0.55, 1.05, { Transparency = 1, Text = { Text = "$", Color = C(255, 240, 150), Font = "Black", Face = "Both" },
				Anim = { Bob = 0.1, Seed = 52 } }),
			-- canne à pommeau doré
			P(RA, CY, V(2.0, 0.12, 0.12), BLK, ME, 0, -2.0, -0.42, 0, 0, 90),
			P(RA, BA, V(0.4, 0.4, 0.4), GOLD, ME, 0, -0.95, -0.42, { Reflect = 0.3 }),
			P(RA, CY, V(0.3, 0.08, 0.08), GOLD, ME, -0.2, -0.78, -0.42, 0, 0, -40),
			P(RA, CY, V(0.3, 0.08, 0.08), GOLD, ME, 0.2, -0.78, -0.42, 0, 0, 40),
			-- bandeau "BULL RUN"
			P(H, B, V(3.0, 0.42, 0.06), C(8, 26, 14), SP, 0, 2.45, 0, { Text = { Text = "BULL RUN ▲▲▲ +1000% ▲▲▲ ", Font = "Code",
				Color = GN, Scroll = 0.3, Width = 4, Face = "Both" }, Anim = { Bob = 0.12, Seed = 53 } }),
			P(H, B, V(3.1, 0.06, 0.08), GOLD, NE, 0, 2.69, 0, { Anim = { Bob = 0.12, Seed = 53 } }),
			P(H, B, V(3.1, 0.06, 0.08), GOLD, NE, 0, 2.21, 0, { Anim = { Bob = 0.12, Seed = 53 } }),
		}, pairA(B, V(1.26, 0.22, 1.26), GOLD, ME, 0, 0.95, 0), pairA(B, V(1.28, 0.24, 1.28), GOLD2, FO, 0, 0.74, 0),
		pairA(B, V(1.08, 0.13, 1.08), GOLD, ME, 0, -0.72, 0), lShoeX),
		Paint = join({
			face(H, "Front", {
				ln(0.37, 0.35, 0.22, 0.05, C(40, 30, 20), 16), ln(0.63, 0.35, 0.22, 0.05, C(40, 30, 20), -16),
				ci(0.38, 0.45, 0.09, 0.08, BLK), ci(0.62, 0.45, 0.09, 0.08, BLK),
				bx(0.5, 0.68, 0.3, 0.07, WHT, { Corner = 0.5, Rotation = -4, Stroke = { C(80, 30, 30), 2 } }),
				bx(0.5, 0.6, 0.36, 0.05, C(120, 80, 50), { Corner = 0.5 }),
			}),
			{ Limb = H, Face = "Front", Glow = true, Elements = { ci(0.385, 0.445, 0.035, 0.035, C(255, 220, 80)), ci(0.625, 0.445, 0.035, 0.035, C(255, 220, 80)) } },
			face(T, "Front", join(gpin, {
				bx(0.5, 0.2, 0.3, 0.4, C(20, 20, 24)),
				bx(0.5, 0.3, 0.1, 0.42, GOLD, { Corner = 0.2 }),
				bx(0.5, 0.1, 0.12, 0.08, GOLD, { Corner = 0.3 }),
				ci(0.5, 0.58, 0.05, 0.05, GOLD), ci(0.5, 0.7, 0.05, 0.05, GOLD), ci(0.5, 0.82, 0.05, 0.05, GOLD),
				bx(0.5, 0.94, 1.02, 0.08, C(20, 20, 24)), bx(0.5, 0.94, 0.12, 0.06, GOLD),
			})),
			face(T, "Back", gpin),
			face(LL, "Front", gpin), face(RL, "Front", gpin),
			face(LL, "Left", { bx(0.5, 0.42, 0.06, 0.84, GOLD) }), face(RL, "Right", { bx(0.5, 0.42, 0.06, 0.84, GOLD) }),
		}, lShoeP),
		FX = { PowerAura = GN, Sparkles = GOLD, Orbit = { Color = GOLD, Count = 4, Shape = "Cylinder", Size = 0.5, Material = "Metal", Speed = 2 } },
		Highlight = { Outline = GOLD },
		HitColor = GOLD,
	})
end

-- ===================== CEO =====================
do
	-- ---------- Rare : Hoodie Founder ----------
	local HEATH, HEATH2, TEE, JEANS, HAIR = C(162, 164, 172), C(128, 130, 140), C(28, 38, 70), C(70, 96, 148), C(110, 70, 40)
	local BLKS = C(40, 40, 46)
	local rShoeP, rShoeX = shoes(WHT, BLKS, nil, { h = 0.3, toe = false, heel = BLKS })
	S({ Id = "CEO_Rare", Character = "CEO", Rarity = "Rare", Name = "Hoodie Founder",
		Desc = "Move fast and break the printer. Worth 40 billion. Wears sandals.",
		Outfit = { Shirt = HEATH, Pants = JEANS },
		HideHair = true,
		HideFace = true,
		Parts = join({
			-- cheveux bouclés en bataille
			E(H, V(1.32, 0.5, 1.32), HAIR, SP, 0, 0.48, 0.05),
			E(H, V(1.25, 0.72, 0.45), HAIR, SP, 0, 0.24, 0.42),
			E(H, V(0.42, 0.34, 0.42), HAIR, SP, -0.36, 0.66, -0.28),
			E(H, V(0.42, 0.34, 0.42), HAIR, SP, 0.04, 0.72, -0.36),
			E(H, V(0.42, 0.34, 0.42), HAIR, SP, 0.38, 0.64, -0.24),
			-- écouteurs sans fil
			P(H, BA, V(0.15, 0.15, 0.15), WHT, SP, -0.64, -0.02, -0.05),
			P(H, BA, V(0.15, 0.15, 0.15), WHT, SP, 0.64, -0.02, -0.05),
			P(H, B, V(0.05, 0.2, 0.05), WHT, SP, -0.64, -0.15, -0.08),
			P(H, B, V(0.05, 0.2, 0.05), WHT, SP, 0.64, -0.15, -0.08),
			-- capuche baissée + col
			E(T, V(1.6, 0.62, 0.72), HEATH2, FA, 0, 1.0, 0.44),
			E(T, V(1.45, 0.34, 1.06), HEATH, FA, 0, 1.02, 0.05),
			-- cordons
			P(T, B, V(0.05, 0.62, 0.05), WHT, SP, -0.28, 0.6, -0.53),
			P(T, B, V(0.05, 0.62, 0.05), WHT, SP, 0.28, 0.6, -0.53),
			P(T, B, V(0.08, 0.12, 0.08), C(200, 200, 205), ME, -0.28, 0.24, -0.53),
			P(T, B, V(0.08, 0.12, 0.08), C(200, 200, 205), ME, 0.28, 0.24, -0.53),
			-- bord-côtes
			P(T, B, V(2.04, 0.2, 1.04), HEATH2, FA, 0, -0.9, 0),
		}, pairA(B, V(1.05, 0.18, 1.05), HEATH2, FA, 0, -0.73, 0), {
			-- badge FOUNDER
			P(T, B, V(0.46, 0.6, 0.04), WHT, SP, -0.62, -0.05, -0.54, 0, 0, 4, { Text = { Text = "FOUNDER", Color = DARK, Font = "Black" } }),
			-- bulle LIKE flottante
			M(P(H, B, V(0.85, 0.85, 0.14), C(60, 120, 255), SP, 0, 1.75, 0, { Text = { Text = "LIKE", Font = "Black", Face = "Both" }, Anim = { Bob = 0.15, Seed = 70 } }), "Brick"),
			P(H, B, V(1.3, 0.34, 0.05), WHT, SP, 0, 2.38, 0, { Transparency = 1, Text = { Text = "+999K", Face = "Both", Font = "Black", Color = WHT }, Anim = { Bob = 0.15, Seed = 70 } }),
			-- smoothie vert
			P(LA, CY, V(0.58, 0.36, 0.36), C(140, 220, 120), SP, 0, -1.2, -0.38, 0, 0, 90),
			P(LA, CY, V(0.08, 0.4, 0.4), WHT, SP, 0, -0.9, -0.38, 0, 0, 90),
			P(LA, CY, V(0.4, 0.05, 0.05), C(255, 120, 160), SP, 0.05, -0.7, -0.38, 0, 0, 80),
			-- sandales (sur chaussettes blanches peintes)
			P(LL, B, V(1.06, 0.07, 0.3), BLKS, SP, 0, -0.86, -0.4),
			P(RL, B, V(1.06, 0.07, 0.3), BLKS, SP, 0, -0.86, -0.4),
		}, rShoeX),
		Paint = join({
			face(H, "Front", {
				ln(0.37, 0.33, 0.14, 0.035, HAIR, -8), ln(0.63, 0.33, 0.14, 0.035, HAIR, 8),
				ci(0.37, 0.43, 0.08, 0.09, BLK), ci(0.63, 0.43, 0.08, 0.09, BLK),
				ci(0.385, 0.415, 0.025, 0.025, WHT), ci(0.645, 0.415, 0.025, 0.025, WHT),
				bx(0.5, 0.67, 0.26, 0.05, C(80, 35, 35), { Corner = 1 }),
				ci(0.35, 0.6, 0.08, 0.05, C(255, 160, 150), { Transparency = 0.5 }), ci(0.65, 0.6, 0.08, 0.05, C(255, 160, 150), { Transparency = 0.5 }),
			}),
			face(T, "Front", {
				bx(0.5, 0.5, 0.24, 1.02, TEE),
				tx(0.5, 0.34, 0.2, 0.08, "MVP", WHT, "Black"),
				ln(0.375, 0.5, 0.014, 1.02, C(90, 92, 100), 0), ln(0.625, 0.5, 0.014, 1.02, C(90, 92, 100), 0),
				bx(0.39, 0.14, 0.03, 0.08, C(200, 200, 205)),
				ln(0.2, 0.74, 0.22, 0.016, HEATH2, 70), ln(0.8, 0.74, 0.22, 0.016, HEATH2, -70),
				ln(0.25, 0.25, 0.4, 0.012, C(60, 120, 255), 60),
			}),
			face(T, "Back", { tx(0.5, 0.55, 0.7, 0.1, "BUILD FAST", C(60, 120, 255), "Black") }),
			face(LL, "Front", { ln(0.3, 0.1, 0.3, 0.015, C(50, 70, 115), 30), bx(0.5, 0.66, 1.02, 0.05, C(110, 135, 185)) }),
			face(RL, "Front", { ln(0.7, 0.1, 0.3, 0.015, C(50, 70, 115), -30), bx(0.5, 0.66, 1.02, 0.05, C(110, 135, 185)) }),
			face(LL, "Left", { ln(0.5, 0.4, 0.012, 0.7, C(200, 170, 80), 0) }),
			face(RL, "Right", { ln(0.5, 0.4, 0.012, 0.7, C(200, 170, 80), 0) }),
		}, rShoeP),
	})

	-- ---------- Epic : Tech Visionary ----------
	local TURT, JEAN2, SNEAK, GREYH, SKINT = C(20, 20, 24), C(84, 110, 156), C(226, 227, 232), C(158, 158, 164), C(230, 195, 165)
	local eShoeP, eShoeX = shoes(SNEAK, WHT, C(190, 190, 196), { h = 0.2, swoosh = C(150, 150, 160), heel = C(150, 150, 160) })
	local ribs = {}
	for i = 1, 9 do
		ribs[#ribs + 1] = bx(i / 10, 0.5, 0.01, 1.02, C(34, 34, 40))
	end
	S({ Id = "CEO_Epic", Character = "CEO", Rarity = "Epic", Name = "Tech Visionary",
		Desc = "It's not a stapler. It's a revolution. Available in black.",
		Outfit = { Shirt = TURT, Pants = JEAN2 },
		HideHair = true,
		HideFace = true,
		Parts = join({
			-- cheveux courts gris (front dégarni)
			E(H, V(1.3, 0.36, 1.26), GREYH, SP, 0, 0.5, 0.14),
			E(H, V(1.26, 0.62, 0.42), GREYH, SP, 0, 0.22, 0.43),
			-- lunettes rondes
			P(H, CY, V(0.03, 0.34, 0.34), C(40, 40, 46), GL, -0.22, 0.12, -0.64, 0, 90, 0, { Transparency = 0.45, Reflect = 0.2 }),
			P(H, CY, V(0.03, 0.34, 0.34), C(40, 40, 46), GL, 0.22, 0.12, -0.64, 0, 90, 0, { Transparency = 0.45, Reflect = 0.2 }),
			P(H, B, V(0.12, 0.03, 0.03), C(170, 170, 180), ME, 0, 0.16, -0.65),
			P(H, B, V(0.03, 0.03, 0.6), C(170, 170, 180), ME, -0.62, 0.14, -0.33),
			P(H, B, V(0.03, 0.03, 0.6), C(170, 170, 180), ME, 0.62, 0.14, -0.33),
			-- col roulé
			P(T, CY, V(0.34, 1.16, 1.16), TURT, FA, 0, 1.1, 0, 0, 0, 90),
			E(T, V(1.3, 0.2, 1.1), C(30, 30, 36), FA, 0, 0.98, 0),
			-- micro-casque
			P(H, B, V(0.04, 0.04, 0.55), SKINT, SP, 0.6, -0.16, -0.36, 0, 24, 0),
			P(H, BA, V(0.1, 0.1, 0.1), SKINT, SP, 0.48, -0.2, -0.62),
			-- télécommande + laser (transformation)
			P(RA, B, V(0.2, 0.14, 0.55), C(230, 230, 236), SP, 0, -1.12, -0.38),
			P(RA, BA, V(0.1, 0.1, 0.1), C(255, 40, 40), NE, 0, -1.12, -0.68),
			P(RA, B, V(0.04, 0.04, 3.0), C(255, 40, 40), NE, 0, -1.12, -2.2, { Transform = true, Transparency = 0.25 }),
			-- montre connectée
			P(LA, B, V(1.06, 0.12, 1.06), BLK, SP, 0, -0.7, 0),
			P(LA, B, V(0.04, 0.22, 0.22), C(60, 160, 255), NE, -0.55, -0.7, 0),
			-- écran de keynote flottant
			P(T, B, V(2.4, 1.4, 0.08), C(10, 10, 14), SP, 2.4, 1.9, 0.4, 0, -25, 0, { Text = { Text = "THE FUTURE.", Font = "Black", Face = "Front", Color = WHT },
				Anim = { Bob = 0.15, Seed = 71 } }),
			P(T, B, V(2.55, 1.55, 0.04), C(150, 190, 255), NE, 2.383, 1.9, 0.436, 0, -25, 0, { Anim = { Bob = 0.15, Seed = 71 } }),
			P(T, B, V(2.4, 1.4, 0.04), C(10, 10, 14), SP, 2.366, 1.9, 0.472, 0, -25, 0, { Text = { Text = "THE FUTURE.", Font = "Black", Face = "Back", Color = WHT },
				Anim = { Bob = 0.15, Seed = 71 } }),
			P(T, B, V(0.08, 0.9, 0.08), C(60, 60, 66), ME, 2.43, 0.75, 0.45, 0, -25, 0, { Anim = { Bob = 0.15, Seed = 71 } }),
			P(T, B, V(2.1, 1.2, 0.08), C(10, 10, 14), SP, -2.4, 1.9, 0.4, 0, 25, 0, { Transform = true, Text = { Text = "ONE MORE\nTHING...", Font = "Black", Face = "Front", Color = WHT },
				Anim = { Bob = 0.15, Seed = 72 } }),
			P(T, B, V(2.25, 1.35, 0.04), C(255, 200, 120), NE, -2.383, 1.9, 0.436, 0, 25, 0, { Transform = true, Anim = { Bob = 0.15, Seed = 72 } }),
			P(T, B, V(2.1, 1.2, 0.04), C(10, 10, 14), SP, -2.366, 1.9, 0.472, 0, 25, 0, { Transform = true, Text = { Text = "ONE MORE\nTHING...", Font = "Black", Face = "Back", Color = WHT },
				Anim = { Bob = 0.15, Seed = 72 } }),
		}, eShoeX),
		Paint = join({
			face(H, "Front", {
				ln(0.37, 0.32, 0.14, 0.03, C(120, 120, 126), 0), ln(0.63, 0.32, 0.14, 0.03, C(120, 120, 126), 0),
				ci(0.37, 0.43, 0.07, 0.08, BLK), ci(0.63, 0.43, 0.07, 0.08, BLK),
				ln(0.5, 0.67, 0.18, 0.03, C(90, 45, 40), -4),
				bx(0.5, 0.74, 0.44, 0.22, C(80, 80, 85), { Transparency = 0.85, Corner = 0.6 }),
			}),
			face(T, "Front", ribs), face(T, "Back", ribs),
			face(LL, "Front", { bx(0.5, 0.38, 0.62, 0.55, C(125, 150, 195), { Transparency = 0.55 }), ln(0.5, 0.45, 0.01, 0.8, C(60, 80, 120), 0) }),
			face(RL, "Front", { bx(0.5, 0.38, 0.62, 0.55, C(125, 150, 195), { Transparency = 0.55 }), ln(0.5, 0.45, 0.01, 0.8, C(60, 80, 120), 0) }),
			face(LL, "Left", { ln(0.5, 0.42, 0.012, 0.84, C(200, 170, 80), 0) }),
			face(RL, "Right", { ln(0.5, 0.42, 0.012, 0.84, C(200, 170, 80), 0) }),
		}, eShoeP),
		FX = { Spotlight = C(255, 255, 240) },
		HitColor = C(150, 190, 255),
	})

	-- ---------- Legendary : Rocket Mogul ----------
	local SUIT, SUIT2, ORNG, PANEL, BLUE = C(238, 238, 242), C(205, 205, 212), C(255, 130, 30), C(58, 60, 72), C(120, 200, 255)
	local function patch(limb, side)
		return face(limb, side, {
			ci(0.5, 0.2, 0.7, 0.32, C(30, 50, 120), { Stroke = { GOLD, 2 } }),
			ci(0.42, 0.18, 0.18, 0.09, ORNG), ci(0.6, 0.22, 0.08, 0.04, WHT),
			bx(0.5, 0.5, 1.02, 0.06, ORNG), bx(0.5, 0.56, 1.02, 0.02, GOLD),
		})
	end
	S({ Id = "CEO_Legendary", Character = "CEO", Rarity = "Legendary", Name = "Rocket Mogul",
		Desc = "Moving the head office to orbit. Parking is still a nightmare.",
		Outfit = { Shirt = SUIT, Pants = SUIT },
		HideHair = true,
		HideFace = true,
		Parts = join({
			-- casque bulle + col métal
			P(H, BA, V(1.95, 1.95, 1.95), C(200, 230, 255), GL, 0, 0.15, 0, { Transparency = 0.68, Reflect = 0.3 }),
			P(H, B, V(0.45, 0.07, 0.02), WHT, NE, -0.42, 0.78, -0.72, 0, -25, 35, { Transparency = 0.35 }),
			E(H, V(1.3, 0.4, 1.3), C(62, 46, 36), SP, 0, 0.48, 0.08),
			P(T, CY, V(0.32, 1.72, 1.72), C(200, 202, 212), ME, 0, 1.08, 0, 0, 0, 90),
			P(T, CY, V(0.06, 1.76, 1.76), GOLD, ME, 0, 1.25, 0, 0, 0, 90),
			P(H, CY, V(0.6, 0.05, 0.05), C(180, 180, 190), ME, 0.6, 1.2, 0.25, 0, 0, 90),
			P(H, BA, V(0.13, 0.13, 0.13), C(255, 50, 50), NE, 0.6, 1.52, 0.25, { Anim = { Pulse = 0.8, PulseSpeed = 4 } }),
			-- panneau de contrôle
			P(T, B, V(1.1, 0.7, 0.14), PANEL, SP, 0, 0.32, -0.55),
			P(T, B, V(0.16, 0.12, 0.05), C(255, 60, 60), NE, -0.3, 0.45, -0.63, { Anim = { Pulse = 0.6, PulseSpeed = 5, Seed = 73 } }),
			P(T, B, V(0.16, 0.12, 0.05), C(80, 255, 120), NE, 0, 0.45, -0.63, { Anim = { Pulse = 0.6, PulseSpeed = 3, Seed = 74 } }),
			P(T, B, V(0.16, 0.12, 0.05), BLUE, NE, 0.3, 0.45, -0.63, { Anim = { Pulse = 0.6, PulseSpeed = 4, Seed = 75 } }),
			P(T, B, V(0.8, 0.1, 0.05), GOLD, NE, 0, 0.18, -0.63, { Anim = { Pulse = 0.5 } }),
			-- ceinture utilitaire
			P(T, B, V(2.06, 0.2, 1.06), PANEL, SP, 0, -0.85, 0),
			P(T, B, V(0.34, 0.26, 0.08), GOLD, ME, 0, -0.85, -0.56),
			P(T, B, V(0.3, 0.3, 0.2), SUIT2, SP, -0.7, -0.85, -0.55),
			-- bretelles du réacteur
			P(T, B, V(0.2, 0.95, 0.06), PANEL, SP, -0.78, 0.5, -0.53),
			P(T, B, V(0.2, 0.95, 0.06), PANEL, SP, 0.78, 0.5, -0.53),
			-- fusée dorsale (pièce générée) + flamme
			A(T, "CEO_Legendary_Rocket", V(1.6, 2.6, 1.6), 0, 0.15, 1.2, 0, 180, 0),
			P(T, BA, V(0.5, 0.75, 0.5), C(255, 160, 40), NE, 0, -1.15, 1.2, { Anim = { Pulse = 0.5, PulseSpeed = 12, Bob = 0.05, BobSpeed = 14 },
				Particles = { Kind = "Fire", Color = C(255, 140, 30), Rate = 20, Dir = "Bottom", Speed = 5, Size = 0.6, Life = 0.4, React = true } }),
			-- planète + anneau + lune en orbite
			P(T, BA, V(0.75, 0.75, 0.75), C(255, 120, 60), SP, 2.7, 1.4, 0, { Anim = { Circle = 0.8, Seed = 76 } }),
			P(T, CY, V(0.05, 1.3, 1.3), C(255, 220, 150), NE, 2.7, 1.4, 0, 0, 0, 70, { Transparency = 0.35, Anim = { Circle = 0.8, Seed = 76 } }),
			P(T, BA, V(0.45, 0.45, 0.45), C(220, 220, 230), SP, -2.7, 0.6, 0, { Anim = { Circle = 0.8, Seed = 76 } }),
			-- réacteurs aux bottes (transformation)
			P(LL, BA, V(0.6, 0.6, 0.6), BLUE, NE, 0, -1.25, 0, { Transform = true, Anim = { Pulse = 0.5, PulseSpeed = 12 },
				Particles = { Kind = "Fire", Color = BLUE, Dir = "Bottom", Rate = 15, Speed = 4, Size = 0.5, Life = 0.35, TransformOnly = true } }),
			P(RL, BA, V(0.6, 0.6, 0.6), BLUE, NE, 0, -1.25, 0, { Transform = true, Anim = { Pulse = 0.5, PulseSpeed = 12, Seed = 1 },
				Particles = { Kind = "Fire", Color = BLUE, Dir = "Bottom", Rate = 15, Speed = 4, Size = 0.5, Life = 0.35, TransformOnly = true } }),
		}, pairA(B, V(1.12, 0.2, 1.12), ORNG, SP, 0, -0.1, 0, nil, "Sphere"),
		pairL(B, V(1.12, 0.2, 1.12), ORNG, SP, 0, 0.05, 0, nil, "Sphere"),
		pairA(B, V(1.1, 0.42, 1.1), SUIT2, SP, 0, -0.82, 0),
		pairA(B, V(1.15, 0.12, 1.15), ORNG, SP, 0, -0.6, 0),
		pairL(B, V(1.12, 0.55, 1.3), C(228, 228, 234), SP, 0, -0.74, -0.1),
		pairL(B, V(1.14, 0.12, 1.32), GOLD, ME, 0, -0.97, -0.1),
		pairL(B, V(1.15, 0.1, 1.15), ORNG, SP, 0, -0.46, 0)),
		Paint = {
			face(H, "Front", {
				ln(0.37, 0.32, 0.15, 0.035, C(62, 46, 36), -6), ln(0.63, 0.32, 0.15, 0.035, C(62, 46, 36), 6),
				ci(0.37, 0.43, 0.08, 0.09, BLK), ci(0.63, 0.43, 0.08, 0.09, BLK),
				ci(0.385, 0.415, 0.025, 0.025, WHT), ci(0.645, 0.415, 0.025, 0.025, WHT),
				bx(0.53, 0.67, 0.24, 0.05, C(90, 40, 40), { Corner = 1, Rotation = -6 }),
			}),
			face(T, "Front", {
				bx(0.12, 0.5, 0.1, 1.02, ORNG), bx(0.88, 0.5, 0.1, 1.02, ORNG),
				tx(0.5, 0.66, 0.6, 0.08, "MOGUL SPACE", C(30, 50, 120), "Black"),
				ci(0.78, 0.18, 0.14, 0.14, C(30, 50, 120), { Stroke = { GOLD, 2 } }),
			}),
			face(T, "Back", { bx(0.12, 0.5, 0.1, 1.02, ORNG), bx(0.88, 0.5, 0.1, 1.02, ORNG) }),
			patch(LA, "Left"), patch(RA, "Right"),
			face(LL, "Left", { bx(0.5, 0.3, 0.12, 0.5, ORNG) }), face(RL, "Right", { bx(0.5, 0.3, 0.12, 0.5, ORNG) }),
			face(LL, "Front", { bx(0.5, 0.25, 0.5, 0.2, SUIT2, { Corner = 0.4 }) }), face(RL, "Front", { bx(0.5, 0.25, 0.5, 0.2, SUIT2, { Corner = 0.4 }) }),
		},
		FX = { PowerAura = GOLD, Sparkles = WHT },
		Highlight = { Outline = C(255, 210, 80) },
		HitColor = C(255, 160, 40),
	})
end

-- ===================== HR MANAGER =====================
do
	-- ---------- Rare : Zen Wellness Coach ----------
	local LAV, LAV2, MINT, PEACH, HAIRC, LEG = C(205, 178, 245), C(150, 105, 215), C(150, 232, 200), C(255, 190, 170), C(125, 72, 46), C(112, 72, 165)
	local rShoeP, rShoeX = shoes(WHT, MINT, LAV2, { h = 0.17, heel = MINT })
	local lotus = {}
	for i = 0, 4 do
		local p = E(H, V(0.2, 0.07, 0.42), C(255, 150, 210), SP, 0, 0, 0, { Anim = { Bob = 0.15, Seed = 80 } })
		p.Offset = CFrame.new(0, 1.55, 0) * CFrame.Angles(0, rad(i * 72), 0) * CFrame.new(0, 0, -0.18) * CFrame.Angles(rad(32), 0, 0)
		lotus[#lotus + 1] = p
	end
	lotus[#lotus + 1] = P(H, BA, V(0.18, 0.18, 0.18), C(255, 230, 110), NE, 0, 1.58, 0, { Anim = { Bob = 0.15, Seed = 80 },
		Particles = { Kind = "Sparkle", Color = C(255, 200, 240), Rate = 4, Speed = 1, Size = 0.25, Life = 1 } })
	local flowers = {}
	for i, col in ipairs({ C(255, 130, 190), WHT, C(255, 225, 90), C(190, 120, 255), PEACH }) do
		local a = rad(-60 + (i - 1) * 30)
		flowers[#flowers + 1] = P(H, BA, V(0.3, 0.3, 0.3), col, SP, 0.68 * math.sin(a), 0.6, -0.68 * math.cos(a))
	end
	S({ Id = "HRManager_Rare", Character = "HRManager", Rarity = "Rare", Name = "Zen Wellness Coach",
		Desc = "Breathe in. Breathe out. You're fired. Namaste.",
		Outfit = { Shirt = LAV, Pants = LEG },
		HideHair = true,
		HideFace = true,
		Parts = join(lotus, flowers, {
			-- cheveux longs + chignon
			E(H, V(1.34, 0.52, 1.34), HAIRC, SP, 0, 0.47, 0.05),
			E(H, V(1.3, 1.35, 0.45), HAIRC, SP, 0, -0.08, 0.43),
			P(H, BA, V(0.6, 0.6, 0.6), HAIRC, SP, 0, 0.86, 0.22),
			E(H, V(0.5, 0.3, 0.3), HAIRC, SP, -0.35, 0.42, -0.48, 0, 0, 20),
			-- couronne de feuilles
			P(H, CY, V(0.12, 1.4, 1.4), C(80, 170, 90), SP, 0, 0.6, 0, 0, 0, 90),
			P(H, BA, V(0.12, 0.12, 0.12), C(255, 220, 60), NE, 0, 0.62, -0.83),
			-- tapis de yoga roulé dans le dos
			P(T, CY, V(2.3, 0.46, 0.46), MINT, SP, 0, 0.05, 0.76, 0, 0, 35),
			P(T, CY, V(0.09, 0.48, 0.48), LAV2, SP, -0.57, -0.35, 0.76, 0, 0, 35),
			P(T, CY, V(0.09, 0.48, 0.48), LAV2, SP, 0.57, 0.45, 0.76, 0, 0, 35),
			-- bracelet mala + gourde
			P(LA, B, V(1.08, 0.12, 1.08), C(150, 95, 60), WO, 0, -0.72, 0),
			P(RA, CY, V(0.62, 0.3, 0.3), MINT, GL, 0, -1.2, -0.36, 0, 0, 90, { Transparency = 0.15 }),
			P(RA, CY, V(0.12, 0.32, 0.32), WHT, SP, 0, -0.86, -0.36, 0, 0, 90),
		}, rShoeX),
		Paint = join({
			face(H, "Front", {
				ln(0.33, 0.44, 0.07, 0.025, C(70, 40, 30), 22), ln(0.39, 0.44, 0.07, 0.025, C(70, 40, 30), -22),
				ln(0.61, 0.44, 0.07, 0.025, C(70, 40, 30), 22), ln(0.67, 0.44, 0.07, 0.025, C(70, 40, 30), -22),
				ci(0.31, 0.56, 0.1, 0.06, C(255, 150, 160), { Transparency = 0.4 }), ci(0.69, 0.56, 0.1, 0.06, C(255, 150, 160), { Transparency = 0.4 }),
				ln(0.46, 0.67, 0.1, 0.03, C(200, 80, 110), 18), ln(0.54, 0.67, 0.1, 0.03, C(200, 80, 110), -18),
				ci(0.5, 0.24, 0.05, 0.05, C(190, 120, 255)),
			}),
			face(T, "Front", {
				ln(0.5, 0.5, 0.014, 1.02, WHT, 0), bx(0.53, 0.1, 0.04, 0.08, WHT),
				bx(0.06, 0.5, 0.06, 1.02, WHT), bx(0.94, 0.5, 0.06, 1.02, WHT),
				ln(0.3, 0.55, 0.9, 0.04, LAV2, 50),
				tx(0.27, 0.3, 0.3, 0.07, "breathe", LAV2, "Hand"),
			}),
			face(T, "Back", { bx(0.06, 0.5, 0.06, 1.02, WHT), bx(0.94, 0.5, 0.06, 1.02, WHT), ci(0.5, 0.82, 0.18, 0.12, PEACH) }),
			face(LA, "Left", { bx(0.5, 0.42, 0.12, 0.84, WHT) }), face(RA, "Right", { bx(0.5, 0.42, 0.12, 0.84, WHT) }),
			face(LL, "Left", { bx(0.5, 0.42, 0.3, 0.84, LAV2) }), face(RL, "Right", { bx(0.5, 0.42, 0.3, 0.84, LAV2) }),
			face(LL, "Front", { ci(0.4, 0.3, 0.16, 0.08, PEACH, { Transparency = 0.3 }), ci(0.6, 0.55, 0.12, 0.06, MINT, { Transparency = 0.3 }) }),
			face(RL, "Front", { ci(0.6, 0.35, 0.16, 0.08, MINT, { Transparency = 0.3 }), ci(0.4, 0.6, 0.12, 0.06, PEACH, { Transparency = 0.3 }) }),
		}, rShoeP),
	})

	-- ---------- Epic : Talk Show Host ----------
	local MAG, MAG2, BLOUSE, TIGHT, HAIRA = C(215, 40, 145), C(170, 25, 110), C(255, 240, 246), C(48, 36, 58), C(140, 60, 38)
	local heelP, heelX = shoes(MAG, MAG2, nil, { h = 0.13, heel = MAG2 })
	local pearls = {}
	for i = 0, 6 do
		local t = (i - 3) / 3
		pearls[#pearls + 1] = ci(0.5 + t * 0.2, 0.1 + (1 - t * t) * 0.1, 0.05, 0.05, WHT)
	end
	S({ Id = "HRManager_Epic", Character = "HRManager", Rarity = "Epic", Name = "Talk Show Host",
		Desc = "Tell me... how does that performance review make you feel?",
		Outfit = { Shirt = MAG, Pants = TIGHT },
		HideHair = true,
		HideFace = true,
		Parts = join({
			-- grosse mise en plis
			E(H, V(1.78, 1.0, 1.62), HAIRA, SP, 0, 0.46, 0.1),
			E(H, V(0.55, 1.15, 0.95), HAIRA, SP, -0.72, -0.05, 0.12),
			E(H, V(0.55, 1.15, 0.95), HAIRA, SP, 0.72, -0.05, 0.12),
			E(H, V(1.62, 1.3, 0.72), HAIRA, SP, 0, 0.04, 0.46),
			E(H, V(1.0, 0.34, 0.5), HAIRA, SP, -0.2, 0.62, -0.38, 0, 0, 12),
			-- boucles d'oreilles
			P(H, CY, V(0.03, 0.3, 0.3), GOLD, ME, -0.66, -0.32, -0.05),
			P(H, CY, V(0.03, 0.3, 0.3), GOLD, ME, 0.66, -0.32, -0.05),
			-- blazer : épaulettes rembourrées + revers satin
			P(T, B, V(0.34, 1.0, 0.05), BLK, SP, -0.42, 0.45, -0.53, 0, 0, 14),
			P(T, B, V(0.34, 1.0, 0.05), BLK, SP, 0.42, 0.45, -0.53, 0, 0, -14),
			P(T, B, V(2.06, 0.16, 1.06), BLK, SP, 0, -0.86, 0),
			P(T, B, V(0.26, 0.2, 0.06), GOLD, ME, 0, -0.86, -0.55),
			-- jupe crayon
			P(T, B, V(2.08, 0.95, 1.08), BLK, SP, 0, -1.45, 0),
			-- talons
			P(LL, B, V(0.14, 0.3, 0.14), MAG2, SP, 0, -0.96, 0.42),
			P(RL, B, V(0.14, 0.3, 0.14), MAG2, SP, 0, -0.96, 0.42),
			-- fiches "SMILE!"
			P(LA, B, V(0.7, 0.95, 0.05), WHT, SP, 0, -1.05, -0.62, { Text = { Text = "SMILE!", Color = MAG, Font = "Black" } }),
			P(LA, B, V(0.7, 0.95, 0.05), C(255, 200, 225), SP, 0.06, -1.0, -0.58, 0, 0, 8),
			-- micro à main
			P(RA, CY, V(0.6, 0.15, 0.15), DARK, SP, 0, -1.05, -0.62, 0, 0, 90),
			P(RA, BA, V(0.32, 0.32, 0.32), C(195, 195, 205), ME, 0, -0.62, -0.62),
			P(RA, CY, V(0.06, 0.2, 0.2), GOLD, ME, 0, -0.78, -0.62, 0, 0, 90),
			-- panneau APPLAUSE
			P(H, B, V(2.1, 0.5, 0.12), C(255, 40, 60), NE, 0, 1.85, 0, { Text = { Text = "APPLAUSE", Font = "Black", Face = "Both", Blink = 2 },
				Anim = { Float = true }, Particles = { Kind = "Sparkle", Color = C(255, 210, 90), Rate = 6, Speed = 2, Size = 0.35, Life = 0.8 } }),
		}, pairA(B, V(1.22, 0.3, 1.16), MAG, SP, 0, 0.9, 0, nil, "Sphere"),
		pairA(B, V(1.06, 0.14, 1.06), BLOUSE, SP, 0, -0.66, 0), heelX),
		Paint = join({
			face(H, "Front", {
				ln(0.36, 0.31, 0.15, 0.03, HAIRA, -10), ln(0.64, 0.31, 0.15, 0.03, HAIRA, 10),
				ci(0.37, 0.43, 0.08, 0.1, BLK), ci(0.63, 0.43, 0.08, 0.1, BLK),
				ci(0.385, 0.41, 0.025, 0.03, WHT), ci(0.645, 0.41, 0.025, 0.03, WHT),
				ln(0.31, 0.39, 0.06, 0.02, BLK, -35), ln(0.69, 0.39, 0.06, 0.02, BLK, 35),
				bx(0.5, 0.67, 0.24, 0.07, C(220, 30, 90), { Corner = 1 }),
				bx(0.5, 0.66, 0.18, 0.02, WHT),
				ci(0.31, 0.57, 0.1, 0.06, C(255, 120, 150), { Transparency = 0.45 }), ci(0.69, 0.57, 0.1, 0.06, C(255, 120, 150), { Transparency = 0.45 }),
			}),
			face(T, "Front", join({
				bx(0.5, 0.18, 0.3, 0.38, BLOUSE),
				ci(0.5, 0.62, 0.06, 0.06, GOLD), ci(0.5, 0.76, 0.06, 0.06, GOLD),
				bx(0.78, 0.4, 0.16, 0.06, C(255, 210, 90)),
				bx(0.22, 0.32, 0.08, 0.08, GOLD, { Rotation = 45 }),
			}, pearls)),
			face(T, "Back", { ln(0.5, 0.5, 0.012, 1.02, MAG2, 0) }),
			face(LL, "Front", { bx(0.5, 0.5, 0.18, 0.8, C(80, 64, 96), { Transparency = 0.5 }) }),
			face(RL, "Front", { bx(0.5, 0.5, 0.18, 0.8, C(80, 64, 96), { Transparency = 0.5 }) }),
		}, heelP),
		FX = { Spotlight = C(255, 220, 250) },
		HitColor = MAG,
	})

	-- ---------- Legendary : Prime Time Host ----------
	local SEQ, PURP, SILV, LIL = C(255, 205, 60), C(110, 35, 180), C(215, 220, 232), C(200, 90, 255)
	local lShoeP, lShoeX = shoes(C(15, 15, 18), C(40, 40, 44), nil, { h = 0.14, heel = GOLD })
	local bulbs = {}
	for i = 0, 9 do
		local x = -1.1 + (i % 5) * 0.55
		local y = i < 5 and 0.38 or -0.38
		bulbs[#bulbs + 1] = P(H, BA, V(0.14, 0.14, 0.14), C(255, 245, 200), NE, x, 2.0 + y, -0.08, { Transform = true,
			Anim = { Pulse = 0.9, PulseSpeed = 6, Seed = 90 + (i % 2) } })
	end
	S({ Id = "HRManager_Legendary", Character = "HRManager", Rarity = "Legendary", Name = "Prime Time Host",
		Desc = "Spin the wheel... of PERFORMANCE REVIEWS! Live, in front of everyone!",
		Outfit = { Shirt = SEQ, Pants = PURP, ArmsSkin = true },
		HideHair = true,
		HideFace = true,
		Parts = join(bulbs, {
			-- banane argentée
			E(H, V(1.34, 0.45, 1.36), SILV, SP, 0, 0.48, 0.08, { Reflect = 0.1 }),
			E(H, V(0.95, 0.6, 0.75), SILV, SP, 0, 0.72, -0.24, -28, 0, 0, { Reflect = 0.1 }),
			E(H, V(1.26, 0.72, 0.45), SILV, SP, 0, 0.2, 0.42, { Reflect = 0.1 }),
			-- veste à sequins (Foil) : buste + manches
			P(T, B, V(2.03, 2.03, 1.03), SEQ, FO, 0, 0, 0),
			P(T, B, V(0.5, 0.9, 0.03), WHT, SP, 0, 0.53, -0.525),
			P(T, B, V(0.42, 1.12, 0.05), BLK, SP, -0.42, 0.4, -0.54, 0, 0, 14),
			P(T, B, V(0.42, 1.12, 0.05), BLK, SP, 0.42, 0.4, -0.54, 0, 0, -14),
			P(T, BA, V(0.08, 0.08, 0.08), BLK, SP, 0, 0.5, -0.545),
			P(T, BA, V(0.08, 0.08, 0.08), BLK, SP, 0, 0.3, -0.545),
			P(T, B, V(0.3, 0.16, 0.06), LIL, NE, -0.62, 0.5, -0.56),
			-- nœud papillon
			E(T, V(0.32, 0.22, 0.08), PURP, SP, -0.15, 0.86, -0.56),
			E(T, V(0.32, 0.22, 0.08), PURP, SP, 0.15, 0.86, -0.56),
			P(T, B, V(0.1, 0.12, 0.09), PURP, SP, 0, 0.86, -0.565),
			-- micro doré
			P(RA, CY, V(0.65, 0.16, 0.16), GOLD, ME, 0, -1.05, -0.6, 0, 0, 90, { Reflect = 0.2 }),
			P(RA, BA, V(0.36, 0.36, 0.36), GOLD, FO, 0, -0.62, -0.6),
			P(RA, CY, V(0.06, 0.2, 0.2), LIL, NE, 0, -0.8, -0.6, 0, 0, 90),
			-- roue des prix (pièce générée) flottant à côté
			A(T, "HRManager_Legendary_Wheel", V(3.0, 3.6, 1.5), -2.6, 1.5, 0.3, 0, 20, 0, { Anim = { Bob = 0.15, Swing = 6, SwingSpeed = 1, Seed = 92 } }),
			-- panneau WINNER (transformation)
			P(H, B, V(2.6, 0.62, 0.12), PURP, SP, 0, 2.0, 0, { Transform = true, Text = { Text = "★ WINNER ★", Color = SEQ, Font = "Black", Face = "Both", Blink = 3 },
				Particles = { Kind = "Sparkle", Color = SEQ, Rate = 14, Speed = 4, Size = 0.4, Life = 1, Spread = 60, TransformOnly = true } }),
		}, pairA(B, V(1.04, 1.62, 1.04), SEQ, FO, 0, 0.19, 0), pairA(B, V(1.06, 0.1, 1.06), WHT, SP, 0, -0.64, 0), lShoeX),
		Paint = join({
			face(H, "Front", {
				ln(0.36, 0.3, 0.15, 0.035, C(150, 150, 160), -12), ln(0.64, 0.29, 0.15, 0.035, C(150, 150, 160), 14),
				ln(0.37, 0.43, 0.1, 0.03, BLK, -8),
				ci(0.63, 0.42, 0.08, 0.1, BLK), ci(0.645, 0.4, 0.025, 0.03, WHT),
				bx(0.5, 0.685, 0.3, 0.09, WHT, { Corner = 1, Stroke = { C(80, 30, 40), 2 } }),
				ln(0.335, 0.645, 0.07, 0.022, C(80, 30, 40), 40), ln(0.665, 0.645, 0.07, 0.022, C(80, 30, 40), -40),
			}),
			{ Limb = H, Face = "Front", Glow = true, Elements = { tx(0.72, 0.6, 0.12, 0.12, "✦", WHT, "Black") } },
			face(LL, "Left", { bx(0.5, 0.42, 0.1, 0.84, GOLD) }), face(RL, "Right", { bx(0.5, 0.42, 0.1, 0.84, GOLD) }),
			face(LL, "Front", { ln(0.5, 0.42, 0.01, 0.84, C(140, 60, 210), 0) }), face(RL, "Front", { ln(0.5, 0.42, 0.01, 0.84, C(140, 60, 210), 0) }),
		}, lShoeP),
		FX = { Spotlight = C(255, 230, 180), PowerAura = LIL, Orbit = { Color = SEQ, Count = 5, Shape = "Ball", Size = 0.25, Material = "Neon", Speed = 2 } },
		Highlight = { Outline = SEQ },
		HitColor = LIL,
	})
end

return L
