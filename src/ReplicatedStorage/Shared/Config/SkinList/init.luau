--[[
	SkinList — 48 skins (Rare / Epic / Legendary) des 16 personnages.
	Format : voir CONTRACT_SKINS + options avancées décrites en tête de Modules/SkinBuilder
	(Anim, Text, Transform, Trail, Particles, Light, Reflect, Highlight, HitColor, FX.PowerAura / Spotlight / HandTrails).
	Thème : archétypes PARODIQUES de figures célèbres (streamers, PDG, chefs stars, présentateurs...) sans vrai nom,
	vraie marque, vrai logo ni ressemblance exacte (règles Roblox). Les Id <Perso>_Rare/_Epic/_Legendary ne changent jamais.
	Repères R6 : tête 2x1x1 (visuel ~1,25, dessus ~+0,6, visage en -Z), buste 2x2x1 (avant -Z), membres 1x2x1 (main à y -1).
]]
local C, V = Color3.fromRGB, Vector3.new
local rad = math.rad
local SP, NE, GL, ME, FF, FA, FO, WO = "SmoothPlastic", "Neon", "Glass", "Metal", "ForceField", "Fabric", "Foil", "Wood"
local H, T, LA, RA, LL, RL = "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"
local B, BA, CY, WE = "Block", "Ball", "Cylinder", "Wedge"

-- Une pièce soudée à un membre (rotations en degrés). opt = options avancées (Transparency, Anim, Text, Trail...)
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
-- pièce sur un anneau autour du membre (angle en degrés), pour les groupes en orbite (Anim.Circle)
local function ring(limb, shape, size, col, mat, r, y, ang, opt, face)
	local a = rad(ang)
	return P(limb, shape, size, col, mat, r * math.cos(a), y, -r * math.sin(a), 0, ang + (face or 90), 0, opt)
end

local L = {}
local function S(def)
	def.HideIdentity = def.HideIdentity ~= false
	L[#L + 1] = def
end

local WHT, BLK, DARK, GOLD = C(245, 245, 245), C(20, 20, 25), C(35, 35, 42), C(255, 200, 40)
local RED, GREEN, CYAN, PINK = C(230, 35, 45), C(80, 255, 120), C(40, 230, 255), C(255, 80, 200)

-- accessoires réutilisables
local function shades(frame, lens, mat, y)
	y = y or 0.12
	return {
		P(H, B, V(0.46, 0.27, 0.08), lens, mat or GL, -0.26, y, -0.62),
		P(H, B, V(0.46, 0.27, 0.08), lens, mat or GL, 0.26, y, -0.62),
		P(H, B, V(1.26, 0.07, 0.07), frame, SP, 0, y + 0.11, -0.63),
	}
end
local function sneakers(col, sole, trail)
	local o = trail and { Trail = { Color = trail, Width = 0.35 } } or nil
	local t = {
		P(LL, B, V(1.12, 0.42, 1.3), col, SP, 0, -0.8, -0.12),
		P(RL, B, V(1.12, 0.42, 1.3), col, SP, 0, -0.8, -0.12),
	}
	if sole then
		t[#t + 1] = P(LL, B, V(1.14, 0.1, 1.32), sole, NE, 0, -0.99, -0.12, o)
		t[#t + 1] = P(RL, B, V(1.14, 0.1, 1.32), sole, NE, 0, -0.99, -0.12, o)
	end
	return t
end
local function pair(limbL, limbR, shape, size, col, mat, x, y, z, opt)
	return {
		P(limbL, shape, size, col, mat, x, y, z, opt),
		P(limbR, shape, size, col, mat, x, y, z, opt),
	}
end
-- micro-casque (perche du côté droit vers la bouche)
local function headsetMic(col, tip)
	return {
		P(H, B, V(0.05, 0.05, 0.56), col, SP, 0.6, -0.14, -0.36, 0, 25, 0),
		P(H, BA, V(0.13, 0.13, 0.13), tip or col, tip and NE or SP, 0.46, -0.17, -0.63),
	}
end

-- ===================== INTERN =====================
S({ Id = "Intern_Rare", Character = "Intern", Rarity = "Rare", Name = "Hypebeast Intern",
	Desc = "Limited-drop hoodie. Unlimited confidence. Zero experience.",
	Outfit = { Shirt = C(255, 150, 40), Pants = C(45, 50, 65) },
	Parts = join({
		P(H, CY, V(0.5, 1.3, 1.3), C(40, 40, 48), FA, 0, 0.74, 0, 0, 0, 90),
		P(H, CY, V(0.12, 1.8, 1.8), C(40, 40, 48), FA, 0, 0.52, 0, 0, 0, 90),
		P(T, B, V(0.12, 0.85, 0.08), GOLD, FO, -0.26, 0.55, -0.54, 0, 0, 35),
		P(T, B, V(0.12, 0.85, 0.08), GOLD, FO, 0.26, 0.55, -0.54, 0, 0, -35),
		P(T, CY, V(0.1, 0.45, 0.45), GOLD, NE, 0, 0.12, -0.6, 0, 90, 0, { Anim = { Spin = 120 } }),
	}, shades(BLK, C(30, 30, 40)), sneakers(WHT)),
})
S({ Id = "Intern_Epic", Character = "Intern", Rarity = "Epic", Name = "Speedrun Intern",
	Desc = "Any% coffee run. On world record pace. Do not talk to him.",
	Outfit = { Shirt = C(40, 40, 52), Pants = C(35, 35, 45), ArmsSkin = true },
	Parts = join({
		P(H, CY, V(0.22, 1.32, 1.32), GREEN, NE, 0, 0.35, 0, 0, 0, 90),
		P(H, B, V(2.2, 0.62, 0.08), C(15, 30, 20), GL, 0, 1.55, 0, { Transparency = 0.25,
			Text = { Text = "00:59.99", Color = GREEN, Font = "Arcade", Face = "Both" }, Anim = { Bob = 0.12, Seed = 1 } }),
		P(H, B, V(2.32, 0.07, 0.1), GREEN, NE, 0, 1.9, 0, { Anim = { Bob = 0.12, Seed = 1 } }),
		P(H, B, V(2.32, 0.07, 0.1), GREEN, NE, 0, 1.2, 0, { Anim = { Bob = 0.12, Seed = 1 } }),
		P(H, B, V(1.3, 0.3, 0.05), GOLD, SP, 0, 2.15, 0, { Transparency = 1,
			Text = { Text = "WR PACE!", Color = GOLD, Font = "Black", Face = "Both", Blink = 2 }, Anim = { Bob = 0.12, Seed = 1 } }),
		P(T, CY, V(0.6, 0.32, 0.32), GREEN, ME, 0.85, -0.75, -0.25, 0, 0, 90),
		P(RA, CY, V(0.15, 0.5, 0.5), C(220, 220, 230), ME, 0, -1.1, -0.4, 0, 90, 0),
		P(RA, B, V(0.12, 0.15, 0.12), RED, NE, 0, -0.8, -0.4),
	}, pair(LA, RA, B, V(1.08, 0.3, 1.08), GREEN, NE, 0, -0.62, 0), sneakers(C(30, 30, 35), GREEN, GREEN)),
})
S({ Id = "Intern_Legendary", Character = "Intern", Rarity = "Legendary", Name = "Livestream Legend",
	Desc = "Smash that like button. Smash everything, actually. LIVE.",
	Outfit = { Shirt = C(255, 120, 40), Pants = C(35, 35, 45) },
	Parts = join({
		-- casque RGB + micro
		P(H, B, V(1.42, 0.14, 0.32), DARK, SP, 0, 0.7, 0),
		P(H, CY, V(0.28, 0.62, 0.62), DARK, SP, -0.71, 0.05, 0),
		P(H, CY, V(0.28, 0.62, 0.62), DARK, SP, 0.71, 0.05, 0),
		P(H, CY, V(0.3, 0.4, 0.4), PINK, NE, -0.72, 0.05, 0, { Anim = { Pulse = 0.5, PulseSpeed = 4 } }),
		P(H, CY, V(0.3, 0.4, 0.4), CYAN, NE, 0.72, 0.05, 0, { Anim = { Pulse = 0.5, PulseSpeed = 4, Seed = 0.8 } }),
		P(H, B, V(0.08, 0.08, 0.75), DARK, SP, -0.48, -0.2, -0.35, 0, -35, 0),
		P(H, BA, V(0.2, 0.2, 0.2), PINK, NE, -0.26, -0.22, -0.68),
		-- ring light derrière la tête
		P(H, CY, V(0.08, 2.6, 2.6), WHT, NE, 0, 0.3, 0.95, 0, 90, 0),
		P(H, CY, V(0.1, 1.95, 1.95), C(40, 40, 50), SP, 0, 0.3, 0.9, 0, 90, 0),
		P(H, CY, V(0.1, 1.95, 1.95), C(40, 40, 50), SP, 0, 0.3, 1.0, 0, 90, 0),
		-- drone caméra en orbite autour de la tête (4 pièces synchronisées)
		P(H, B, V(0.6, 0.25, 0.6), DARK, SP, 2.0, 0.9, 0, { Anim = { Circle = 1.1, Bob = 0.15, Seed = 2 } }),
		P(H, CY, V(0.15, 0.26, 0.26), RED, NE, 1.66, 0.88, 0, { Anim = { Circle = 1.1, Bob = 0.15, Seed = 2 } }),
		P(H, CY, V(0.05, 0.55, 0.55), WHT, GL, 2.0, 1.06, -0.42, 0, 0, 90, { Transparency = 0.3, Anim = { Circle = 1.1, Bob = 0.15, Seed = 2 } }),
		P(H, CY, V(0.05, 0.55, 0.55), WHT, GL, 2.0, 1.06, 0.42, 0, 0, 90, { Transparency = 0.3, Anim = { Circle = 1.1, Bob = 0.15, Seed = 2 } }),
		-- panneau LIVE flottant
		P(H, B, V(1.3, 0.5, 0.1), RED, NE, 0, 1.6, 0, { Text = { Text = "● LIVE", Font = "Black", Face = "Both", Blink = 1.5 },
			Anim = { Float = true, Seed = 3 } }),
		-- pancarte SUBSCRIBE
		P(RA, CY, V(2.6, 0.12, 0.12), C(150, 110, 70), WO, 0, 0.1, -0.6, 0, 0, 90),
		P(RA, B, V(1.9, 0.65, 0.12), RED, SP, 0.3, 1.55, -0.6, { Text = { Text = "SUBSCRIBE", Font = "Black", Face = "Front" } }),
		-- sweat
		P(T, B, V(1.7, 0.55, 0.55), C(230, 100, 35), FA, 0, 0.85, 0.5),
		P(T, B, V(0.8, 0.55, 0.06), RED, SP, 0, 0.2, -0.53, { Text = { Text = "▶", Color = WHT } }),
	}, sneakers(WHT, PINK)),
	FX = { PowerAura = C(255, 120, 40), Orbit = { Color = C(255, 60, 120), Count = 3, Shape = "Ball", Size = 0.35, Speed = 1.6 } },
	Highlight = { Outline = PINK },
	HitColor = C(255, 60, 120),
})

-- ===================== JANITOR =====================
S({ Id = "Janitor_Rare", Character = "Janitor", Rarity = "Rare", Name = "Disco Custodian",
	Desc = "Mops the floor. Then owns the dance floor.",
	Outfit = { Shirt = C(150, 60, 220), Pants = C(250, 250, 250) },
	Parts = join({
		P(H, BA, V(0.8, 0.8, 0.8), C(225, 225, 240), FO, 0, 1.6, 0, { Reflect = 0.6, Light = C(255, 120, 220),
			Anim = { Spin = 90, Bob = 0.15, Seed = 4 } }),
		P(H, B, V(0.05, 0.5, 0.05), C(200, 200, 210), ME, 0, 2.2, 0, { Anim = { Bob = 0.15, Seed = 4 } }),
		P(T, CY, V(0.1, 0.45, 0.45), GOLD, NE, 0, 0.35, -0.56, 0, 90, 0),
		P(T, B, V(0.5, 0.35, 0.1), GOLD, ME, 0, -0.85, -0.53),
	}, shades(GOLD, C(255, 90, 200)),
	pair(LL, RL, B, V(1.35, 0.6, 1.35), C(250, 250, 250), SP, 0, -0.72, 0)),
})
S({ Id = "Janitor_Epic", Character = "Janitor", Rarity = "Epic", Name = "Pressure Wash Pro",
	Desc = "10 million views of one very clean carpet. Satisfying.",
	Outfit = { Shirt = C(255, 205, 40), Pants = C(40, 60, 110) },
	Parts = join({
		P(H, CY, V(0.18, 1.3, 1.3), DARK, SP, 0, 0.15, 0, 0, 0, 90),
		P(H, B, V(1.1, 0.34, 0.15), C(120, 220, 255), GL, 0, 0.15, -0.62, { Transparency = 0.2 }),
		P(H, CY, V(0.5, 1.35, 1.35), C(255, 205, 40), SP, 0, 0.74, 0, 0, 0, 90),
		P(H, CY, V(0.1, 1.95, 1.95), C(255, 205, 40), SP, 0, 0.52, 0.12, 0, 0, 90),
		P(T, CY, V(1.7, 0.9, 0.9), C(230, 60, 50), ME, 0, 0, 0.95, 0, 0, 90),
		P(T, CY, V(0.2, 0.4, 0.4), DARK, SP, 0, 0.95, 0.95, 0, 0, 90),
		P(RA, B, V(0.25, 0.5, 0.25), C(255, 205, 40), SP, 0, -1.2, -0.45),
		P(RA, B, V(0.18, 0.18, 1.6), C(60, 60, 70), ME, 0, -1.05, -1.0),
		P(RA, CY, V(0.3, 0.25, 0.25), C(255, 205, 40), SP, 0, -1.05, -1.85, 0, 90, 0),
		P(RA, CY, V(1.4, 0.2, 0.2), C(130, 225, 255), NE, 0, -1.05, -2.7, 0, 90, 0, { Transparency = 0.3,
			Anim = { Pulse = 0.45, PulseSpeed = 10 },
			Particles = { Kind = "Smoke", Color = C(200, 240, 255), Rate = 12, Dir = "Right", Speed = 6, Size = 0.5, Life = 0.5, Spread = 20 } }),
	}, pair(LL, RL, B, V(1.12, 0.9, 1.15), C(255, 205, 40), SP, 0, -0.6, 0),
	pair(LA, RA, B, V(1.1, 0.45, 1.1), C(80, 200, 120), SP, 0, -0.8, 0)),
})
local BUB = C(150, 225, 255)
local crown = {}
for i, a in ipairs({ 0, 90, 180, 270 }) do
	local r = math.rad(a)
	crown[#crown + 1] = P(H, B, V(0.24, 0.42, 0.24), GOLD, ME, 0.52 * math.cos(r), 1.05, 0.52 * math.sin(r), 0, a + 45, 0,
		{ Anim = { Circle = 0.6, Seed = 5 } })
	crown[#crown + 1] = P(H, BA, V(0.26, 0.26, 0.26), CYAN, NE, 0.52 * math.cos(r), 1.32, 0.52 * math.sin(r),
		{ Anim = { Circle = 0.6, Seed = 5 } })
end
S({ Id = "Janitor_Legendary", Character = "Janitor", Rarity = "Legendary", Name = "Bubble Emperor",
	Desc = "Long live the spotless empire. Kneel before the mop.",
	Outfit = { Shirt = C(90, 170, 255), Pants = C(40, 70, 150) },
	Parts = join(crown, {
		P(H, CY, V(0.35, 1.36, 1.36), GOLD, ME, 0, 0.72, 0, 0, 0, 90, { Anim = { Circle = 0.6, Seed = 5 } }),
		P(T, B, V(2.0, 2.8, 0.1), C(120, 200, 255), SP, 0, -0.45, 0.62, 8, 0, 0, { Anim = { Swing = 4, SwingAxis = "X", SwingSpeed = 1.5 } }),
		P(T, B, V(2.3, 0.35, 0.55), WHT, FA, 0, 0.95, 0.15),
		P(LA, CY, V(3.0, 0.14, 0.14), GOLD, ME, 0, -0.6, -0.55, 0, 0, 90),
		P(LA, BA, V(0.7, 0.7, 0.7), BUB, GL, 0, 1.15, -0.55, { Transparency = 0.35, Light = C(120, 220, 255) }),
		P(LA, BA, V(0.35, 0.35, 0.35), CYAN, NE, 0, 1.15, -0.55, { Anim = { Pulse = 0.6 },
			Particles = { Kind = "Sparkle", Color = BUB, Rate = 6, Speed = 1.5, Size = 0.35, Life = 1 } }),
		P(LA, CY, V(0.5, 0.6, 0.6), WHT, FA, 0, -2.15, -0.55, 0, 0, 90),
		P(T, B, V(0.35, 2.5, 0.08), GOLD, FA, 0, 0, -0.53, 0, 0, 40),
		P(T, BA, V(0.4, 0.4, 0.2), CYAN, NE, 0, 0.4, -0.58),
	}, pair(LA, RA, BA, V(1.2, 1.0, 1.2), BUB, GL, 0, 0.85, 0, { Transparency = 0.35 }),
	pair(LA, RA, B, V(1.1, 0.5, 1.1), GOLD, ME, 0, -0.75, 0),
	pair(LL, RL, B, V(1.12, 0.45, 1.25), GOLD, ME, 0, -0.8, -0.1)),
	FX = { PowerAura = C(120, 220, 255), Orbit = { Color = BUB, Count = 4, Shape = "Ball", Size = 0.6, Material = "Glass", Speed = 1.2 } },
	Highlight = { Outline = BUB },
	HitColor = C(120, 220, 255),
})

-- ===================== LUNCH LADY =====================
local BOX, CHEESE, PEP = C(205, 165, 115), C(255, 200, 90), C(200, 50, 40)
S({ Id = "LunchLady_Rare", Character = "LunchLady", Rarity = "Rare", Name = "Pizza Party Queen",
	Desc = "Every Friday. Attendance is mandatory. So is fun.",
	Outfit = { Shirt = C(255, 215, 120), Pants = C(200, 50, 40) },
	Parts = {
		P(H, B, V(1.5, 0.2, 1.5), BOX, SP, 0, 0.72, 0),
		P(H, CY, V(0.06, 1.3, 1.3), CHEESE, SP, 0, 0.84, 0, 0, 0, 90),
		P(H, CY, V(0.05, 0.3, 0.3), PEP, SP, -0.3, 0.87, -0.2, 0, 0, 90),
		P(H, CY, V(0.05, 0.3, 0.3), PEP, SP, 0.3, 0.87, 0.1, 0, 0, 90),
		P(H, CY, V(0.05, 0.3, 0.3), PEP, SP, -0.05, 0.87, 0.38, 0, 0, 90),
		P(H, B, V(1.5, 1.5, 0.12), BOX, SP, 0, 1.53, 1.0, 20, 0, 0, { Text = { Text = "PIZZA PARTY", Color = PEP, Font = "Black", Face = "Both" } }),
		P(RA, WE, V(0.12, 0.8, 0.6), CHEESE, SP, 0, -1.25, -0.55, 0, 0, 180),
	},
})
S({ Id = "LunchLady_Epic", Character = "LunchLady", Rarity = "Epic", Name = "Cooking Show Diva",
	Desc = "Live from the break room: it's FABULOUS, darling.",
	Outfit = { Shirt = C(255, 110, 160), Pants = WHT },
	Parts = join({
		P(H, BA, V(1.7, 1.55, 1.5), C(245, 205, 95), SP, 0, 0.45, 0.35),
		P(H, BA, V(1.4, 0.9, 1.2), C(245, 205, 95), SP, 0, 0.85, 0.1),
		P(H, CY, V(0.05, 0.36, 0.36), GOLD, NE, -0.63, -0.25, 0),
		P(H, CY, V(0.05, 0.36, 0.36), GOLD, NE, 0.63, -0.25, 0),
		P(T, B, V(1.1, 0.12, 0.1), WHT, "Marble", 0, 0.85, -0.53),
		P(T, B, V(1.7, 2.3, 0.08), WHT, FA, 0, -0.5, -0.54, { Text = { Text = "CHEF ♥", Color = C(255, 80, 140), Font = "Cartoon" } }),
		P(RA, CY, V(0.9, 0.16, 0.16), C(255, 110, 160), SP, 0, -0.75, -0.7, 0, 0, 90),
		P(RA, BA, V(0.55, 1.1, 0.55), C(225, 225, 235), ME, 0, 0.05, -0.7, {
			Particles = { Kind = "Sparkle", Color = C(255, 150, 220), Rate = 5, Speed = 1.5, Size = 0.35, Life = 0.9 } }),
		P(LA, CY, V(0.3, 0.9, 0.9), C(210, 150, 80), SP, 0, -1.15, -0.5, 0, 0, 90),
		P(LA, BA, V(0.45, 0.4, 0.45), WHT, SP, 0, -0.92, -0.5),
		P(H, B, V(1.6, 0.5, 0.1), RED, NE, 0, 1.85, 0, { Text = { Text = "ON AIR", Font = "Black", Face = "Both" }, Anim = { Float = true } }),
	}, headsetMic(DARK)),
	FX = { Spotlight = C(255, 220, 240) },
})
S({ Id = "LunchLady_Legendary", Character = "LunchLady", Rarity = "Legendary", Name = "Celebrity Chef Inferno",
	Desc = "Five stars. Zero patience. The break room is HER kitchen now.",
	Outfit = { Shirt = WHT, Pants = C(40, 40, 48) },
	Parts = join({
		P(H, CY, V(0.35, 1.36, 1.36), WHT, SP, 0, 0.72, 0, 0, 0, 90),
		P(H, CY, V(1.2, 1.36, 1.36), WHT, FA, 0, 1.45, 0, 0, 0, 90),
		P(H, BA, V(1.95, 0.95, 1.95), WHT, FA, 0, 2.15, 0),
		P(H, CY, V(0.14, 1.38, 1.38), C(255, 120, 30), NE, 0, 0.88, 0, 0, 0, 90),
		P(H, B, V(0.4, 0.1, 0.05), DARK, SP, -0.22, 0.33, -0.62, 0, 0, -15),
		P(H, B, V(0.4, 0.1, 0.05), DARK, SP, 0.22, 0.33, -0.62, 0, 0, 15),
		P(H, B, V(1.6, 0.5, 0.06), GOLD, SP, 0, 2.95, 0, { Transparency = 1,
			Text = { Text = "★★★★★", Color = GOLD, Face = "Both" }, Anim = { Float = true, Seed = 6 } }),
		P(T, B, V(0.12, 1.4, 0.05), DARK, SP, -0.35, 0.1, -0.52),
		P(T, B, V(0.12, 1.4, 0.05), DARK, SP, 0.35, 0.1, -0.52),
		P(T, B, V(0.9, 0.3, 0.12), C(255, 120, 30), SP, 0, 0.85, -0.52),
		P(T, B, V(1.9, 1.2, 0.08), C(40, 40, 48), FA, 0, -0.95, -0.54),
		-- poêle enflammée
		P(RA, B, V(0.18, 0.15, 0.7), DARK, ME, 0, -1.05, -0.35),
		P(RA, CY, V(0.18, 1.3, 1.3), DARK, ME, 0, -1.15, -1.05, 0, 0, 90),
		P(RA, BA, V(0.9, 0.6, 0.9), C(255, 140, 30), NE, 0, -0.85, -1.05, { Anim = { Pulse = 0.4, PulseSpeed = 8, Bob = 0.08, BobSpeed = 9 },
			Particles = { Kind = "Fire", Color = C(255, 120, 30), Rate = 18, Speed = 3, Size = 0.7, Life = 0.6, React = true } }),
		P(RA, BA, V(0.5, 0.5, 0.5), C(255, 230, 80), NE, 0, -0.7, -1.05, { Anim = { Bob = 0.1, BobSpeed = 11 } }),
		-- moulin à poivre géant
		P(LA, CY, V(1.1, 0.36, 0.36), C(120, 70, 40), WO, 0, -1.1, -0.55, 0, 0, 90),
		P(LA, BA, V(0.36, 0.36, 0.36), C(120, 70, 40), WO, 0, -0.45, -0.55),
		-- assiettes en orbite
		ring(T, CY, V(0.08, 0.9, 0.9), WHT, SP, 2.3, 0.8, 0, { Anim = { Circle = 1.5, Seed = 7 } }, 0),
		ring(T, CY, V(0.08, 0.9, 0.9), WHT, SP, 2.3, 0.8, 120, { Anim = { Circle = 1.5, Seed = 7 } }, 0),
		ring(T, CY, V(0.08, 0.9, 0.9), WHT, SP, 2.3, 0.8, 240, { Anim = { Circle = 1.5, Seed = 7 } }, 0),
		-- épaules en feu pendant la transformation
		P(T, BA, V(1.0, 0.8, 1.0), C(255, 100, 20), NE, -1.4, 1.2, 0, { Transform = true, Anim = { Pulse = 0.4, PulseSpeed = 7 },
			Particles = { Kind = "Fire", Color = C(255, 100, 20), Rate = 14, Speed = 3, Size = 0.8, Life = 0.6, TransformOnly = true } }),
		P(T, BA, V(1.0, 0.8, 1.0), C(255, 100, 20), NE, 1.4, 1.2, 0, { Transform = true, Anim = { Pulse = 0.4, PulseSpeed = 7, Seed = 1 },
			Particles = { Kind = "Fire", Color = C(255, 100, 20), Rate = 14, Speed = 3, Size = 0.8, Life = 0.6, TransformOnly = true } }),
	}, pair(LL, RL, B, V(1.12, 0.4, 1.3), C(40, 40, 48), SP, 0, -0.82, -0.12)),
	FX = { PowerAura = C(255, 120, 30) },
	Highlight = { Outline = C(255, 120, 30) },
	HitColor = C(255, 120, 30),
})

-- ===================== SECURITY GUARD =====================
S({ Id = "SecurityGuard_Rare", Character = "SecurityGuard", Rarity = "Rare", Name = "Segway Patrol",
	Desc = "Top speed: 12 mph. Top attitude: maximum.",
	Outfit = { Shirt = C(70, 95, 160), Pants = C(30, 35, 50) },
	Parts = join({
		P(T, B, V(1.9, 0.25, 1.2), DARK, SP, 0, -2.85, -0.1),
		P(T, CY, V(0.35, 1.1, 1.1), BLK, SP, -1.15, -2.6, -0.1),
		P(T, CY, V(0.35, 1.1, 1.1), BLK, SP, 1.15, -2.6, -0.1),
		P(T, CY, V(2.2, 0.14, 0.14), C(170, 170, 180), ME, 0, -1.75, -0.85, 0, 0, 90),
		P(T, B, V(1.3, 0.14, 0.14), BLK, SP, 0, -0.65, -0.85),
		P(H, BA, V(1.4, 1.0, 1.45), WHT, SP, 0, 0.55, 0.05),
		P(T, B, V(0.4, 0.45, 0.08), GOLD, ME, -0.5, 0.45, -0.53),
	}, shades(BLK, C(40, 40, 50))),
})
S({ Id = "SecurityGuard_Epic", Character = "SecurityGuard", Rarity = "Epic", Name = "Action Hero Guard",
	Desc = "Wrong building. Wrong night. Wrong security guard.",
	Outfit = { Shirt = C(240, 240, 235), Pants = C(50, 60, 90), ArmsSkin = true },
	Parts = join({
		P(H, CY, V(0.25, 1.32, 1.32), C(200, 40, 40), FA, 0, 0.4, 0, 0, 0, 90),
		P(H, B, V(0.15, 0.5, 0.15), C(200, 40, 40), FA, 0.15, 0.2, 0.65, 0, 0, 20),
		P(H, B, V(0.3, 0.04, 0.04), C(230, 210, 160), WO, 0.18, -0.32, -0.62, 0, 0, -15),
		P(T, B, V(0.15, 2.2, 0.06), C(90, 60, 40), SP, 0, 0.05, -0.53, 0, 0, -28),
		P(T, B, V(0.15, 2.2, 0.06), C(90, 60, 40), SP, 0, 0.05, -0.54, 0, 0, 28),
		P(T, B, V(0.2, 0.3, 0.05), C(200, 200, 210), ME, 0, 0.35, -0.56),
		P(T, B, V(0.4, 0.45, 0.08), GOLD, ME, -0.55, -0.8, -0.53),
		P(LA, CY, V(0.3, 0.5, 0.5), RED, NE, 0, 1.15, 0, 0, 0, 90, { Anim = { Pulse = 0.7, PulseSpeed = 12, Seed = 0 }, Light = C(255, 40, 40) }),
		P(RA, CY, V(0.3, 0.5, 0.5), C(40, 90, 255), NE, 0, 1.15, 0, 0, 0, 90, { Anim = { Pulse = 0.7, PulseSpeed = 12, Seed = 0.26 }, Light = C(40, 90, 255) }),
		P(RA, CY, V(1.3, 0.35, 0.35), DARK, ME, 0, -1.1, -0.75, 0, 90, 0),
		P(RA, CY, V(0.08, 0.45, 0.45), C(255, 250, 200), NE, 0, -1.1, -1.42, 0, 90, 0),
		P(RA, CY, V(2.5, 0.6, 0.6), C(255, 250, 200), NE, 0, -1.1, -2.7, 0, 90, 0, { Transparency = 0.75 }),
	}, shades(GOLD, C(40, 40, 45)), pair(LL, RL, B, V(1.12, 0.7, 1.15), C(35, 30, 28), SP, 0, -0.7, -0.05)),
})
local STEEL, CY2 = C(190, 200, 220), C(40, 180, 255)
S({ Id = "SecurityGuard_Legendary", Character = "SecurityGuard", Rarity = "Legendary", Name = "Cyber Sentinel",
	Desc = "Scanning for overtime violations... Violation detected.",
	Outfit = { Shirt = C(40, 50, 80), Pants = C(30, 35, 55), Skin = C(180, 190, 210) },
	Parts = join({
		P(H, B, V(1.35, 1.15, 1.35), STEEL, ME, 0, 0.15, 0),
		P(H, B, V(1.25, 0.3, 0.1), CY2, NE, 0, 0.15, -0.68, { Text = { Text = "SCANNING... OVERTIME DETECTED... ", Font = "Code",
			Color = C(225, 250, 255), Scroll = 0.25, Width = 4 } }),
		P(H, B, V(0.2, 0.35, 1.4), CY2, NE, 0, 0.85, 0),
		P(H, CY, V(0.6, 0.08, 0.08), STEEL, ME, 0.55, 1.0, 0.3, 0, 0, 90),
		P(H, BA, V(0.15, 0.15, 0.15), RED, NE, 0.55, 1.32, 0.3, { Anim = { Pulse = 0.8, PulseSpeed = 6 } }),
		P(H, B, V(0.6, 0.7, 0.06), GOLD, NE, 0, 1.75, 0, { Transparency = 0.2, Anim = { Spin = 120, Bob = 0.15 } }),
		P(T, B, V(2.1, 1.3, 0.25), STEEL, ME, 0, 0.35, -0.5),
		P(T, CY, V(0.1, 0.6, 0.6), CY2, NE, 0, 0.35, -0.65, 0, 90, 0, { Anim = { Pulse = 0.4, React = true } }),
		P(T, B, V(1.4, 1.4, 0.5), C(150, 160, 180), ME, 0, 0.2, 0.75),
		P(T, B, V(1.0, 0.15, 0.1), CY2, NE, 0, 0.4, 1.02, { Anim = { Pulse = 0.5 } }),
		P(T, B, V(2.05, 0.3, 1.05), DARK, SP, 0, -0.85, 0),
		P(T, B, V(0.5, 0.3, 0.5), C(60, 70, 90), ME, 1.7, 1.7, 0.3, { Anim = { Bob = 0.15, Seed = 8 } }),
		P(T, BA, V(0.22, 0.22, 0.22), RED, NE, 1.7, 1.7, 0.03, { Anim = { Bob = 0.15, Seed = 8 } }),
	}, pair(LA, RA, B, V(1.25, 0.6, 1.25), STEEL, ME, 0, 0.9, 0),
	pair(LA, RA, B, V(1.27, 0.1, 1.27), CY2, NE, 0, 0.6, 0),
	pair(LA, RA, B, V(1.15, 0.8, 1.15), C(150, 160, 180), ME, 0, -0.55, 0),
	pair(LL, RL, B, V(1.15, 1.0, 1.15), STEEL, ME, 0, -0.45, 0),
	pair(LL, RL, B, V(1.17, 0.12, 1.2), CY2, NE, 0, -0.97, 0)),
	FX = { PowerAura = CY2, HandTrails = CY2 },
	Highlight = { Outline = CY2 },
	HitColor = CY2,
})

-- ===================== IT GUY =====================
local HOODIE = C(30, 32, 40)
S({ Id = "ITGuy_Rare", Character = "ITGuy", Rarity = "Rare", Name = "Hoodie Hacker",
	Desc = "\"I'm in.\" (He is not in. He forgot his password.)",
	Outfit = { Shirt = HOODIE, Pants = C(40, 42, 52) },
	Parts = {
		P(H, B, V(1.5, 1.35, 1.4), HOODIE, FA, 0, 0.2, 0.2),
		P(H, B, V(1.22, 0.3, 0.08), C(10, 20, 10), GL, 0, 0.12, -0.62, { Text = { Text = "01101 10010 0110 1011 ", Font = "Code",
			Color = GREEN, Scroll = 0.4, Width = 3 } }),
		P(T, B, V(0.06, 0.6, 0.06), WHT, SP, -0.2, 0.6, -0.53),
		P(T, B, V(0.06, 0.6, 0.06), WHT, SP, 0.2, 0.6, -0.53),
		P(T, B, V(1.0, 0.5, 0.05), HOODIE, SP, 0, 0.0, -0.52, { Text = { Text = "sudo", Font = "Code", Color = GREEN } }),
		P(RA, CY, V(0.6, 0.35, 0.35), GREEN, ME, 0, -1.15, -0.4, 0, 0, 90),
		P(LA, B, V(0.12, 1.0, 1.3), C(170, 175, 185), ME, -0.58, -0.4, 0),
	},
})
S({ Id = "ITGuy_Epic", Character = "ITGuy", Rarity = "Epic", Name = "Retro Pro Gamer",
	Desc = "Press START to take a break. There is no break.",
	Outfit = { Shirt = C(60, 190, 175), Pants = C(50, 40, 90) },
	Parts = join({
		P(H, B, V(1.42, 0.14, 0.3), DARK, SP, 0, 0.7, 0),
		P(H, B, V(0.12, 0.6, 0.2), DARK, SP, -0.7, 0.42, 0),
		P(H, B, V(0.12, 0.6, 0.2), DARK, SP, 0.7, 0.42, 0),
		P(H, CY, V(0.28, 0.62, 0.62), C(60, 190, 175), NE, -0.71, 0.05, 0),
		P(H, CY, V(0.28, 0.62, 0.62), C(60, 190, 175), NE, 0.71, 0.05, 0),
		P(H, B, V(1.26, 0.28, 0.08), BLK, SP, 0, 0.12, -0.62),
		P(H, CY, V(0.12, 0.7, 0.7), GOLD, NE, 0, 1.6, 0, 0, 90, 0, { Anim = { Spin = 180, Bob = 0.15 } }),
		P(H, B, V(1.6, 0.45, 0.06), RED, SP, 0, 2.15, 0, { Transparency = 1,
			Text = { Text = "♥♥♥", Color = C(255, 50, 70), Font = "Arcade", Face = "Both" }, Anim = { Bob = 0.15, Seed = 9 } }),
		P(T, B, V(1.6, 0.4, 0.05), DARK, SP, 0, 0.2, -0.53, { Text = { Text = "PRESS START", Font = "Arcade", Color = C(255, 230, 80), Blink = 1.2 } }),
		P(RA, B, V(1.0, 0.25, 0.5), C(80, 80, 90), SP, 0, -1.1, -0.5, { Text = { Text = "✚    ● ●", Color = RED, Face = "Top" } }),
		P(T, B, V(1.4, 1.6, 0.4), C(160, 160, 170), SP, 0, 0, 0.7),
		P(T, B, V(1.0, 0.8, 0.05), C(255, 80, 80), SP, 0, 0.3, 0.92, { Text = { Text = "GAME", Font = "Arcade", Face = "Back" } }),
	}, sneakers(WHT)),
})
local G2, BLKG = C(80, 255, 120), C(15, 20, 25)
local screens = {}
for i, a in ipairs({ 0, 90, 180, 270 }) do
	screens[#screens + 1] = ring(T, B, V(1.1, 0.75, 0.05), C(40, 255, 120), GL, 2.5, 0.6, a, { Transparency = 0.45,
		Text = { Text = ({ "01011\n11010", "ACCESS\nGRANTED", "rm -rf\nmonday", "ping\nboss" })[i], Font = "Code", Color = G2, Face = "Both" },
		Anim = { Circle = 0.7, Bob = 0.2, Seed = 10 } })
end
S({ Id = "ITGuy_Legendary", Character = "ITGuy", Rarity = "Legendary", Name = "Root Access",
	Desc = "Admin privileges: the entire building. Including you.",
	Outfit = { Shirt = BLKG, Pants = BLKG },
	Parts = join(screens, {
		P(H, B, V(1.5, 1.35, 1.4), BLKG, FA, 0, 0.2, 0.2),
		P(H, B, V(1.52, 0.1, 0.08), G2, NE, 0, 0.86, -0.5),
		P(H, B, V(0.1, 1.35, 0.08), G2, NE, -0.75, 0.2, -0.5),
		P(H, B, V(0.1, 1.35, 0.08), G2, NE, 0.75, 0.2, -0.5),
		P(H, B, V(1.22, 0.32, 0.08), C(10, 30, 15), GL, 0, 0.12, -0.62, { Text = { Text = "ACCESS GRANTED ✓ ", Font = "Code",
			Color = G2, Scroll = 0.3, Width = 3 } }),
		P(T, B, V(0.08, 1.6, 0.05), G2, NE, -0.5, -0.1, -0.52, { Anim = { Pulse = 0.5, Seed = 11 } }),
		P(T, B, V(0.7, 0.08, 0.05), G2, NE, -0.19, 0.66, -0.52, { Anim = { Pulse = 0.5, Seed = 11 } }),
		P(T, B, V(0.08, 0.7, 0.05), G2, NE, 0.12, 0.35, -0.52, { Anim = { Pulse = 0.5, Seed = 11 } }),
		P(T, B, V(1.6, 0.1, 0.6), DARK, SP, 0, -0.6, -1.3, { Anim = { Bob = 0.12, Seed = 12 } }),
		P(T, B, V(1.5, 0.04, 0.5), G2, NE, 0, -0.53, -1.3, { Transparency = 0.3, Anim = { Bob = 0.12, Seed = 12 } }),
		P(T, B, V(1.5, 1.7, 0.6), C(40, 45, 55), ME, 0, 0, 0.8),
		P(T, B, V(1.2, 1.2, 0.05), C(40, 45, 55), SP, 0, 0.1, 1.11, { Text = { Text = "■ ■ ■\n■ ■ ■", Color = G2, Font = "Code", Face = "Back", Blink = 3 } }),
	}, pair(LA, RA, B, V(1.1, 0.35, 1.1), G2, NE, 0, -0.85, 0), sneakers(C(25, 25, 30), G2)),
	FX = { PowerAura = G2, HandTrails = G2 },
	Highlight = { Outline = G2 },
	HitColor = G2,
})

-- ===================== ACCOUNTANT =====================
local TAN, HAT = C(170, 140, 100), C(60, 50, 45)
S({ Id = "Accountant_Rare", Character = "Accountant", Rarity = "Rare", Name = "Noir Auditor",
	Desc = "The numbers never lie. People do. Every receipt is a clue.",
	Outfit = { Shirt = TAN, Pants = C(70, 60, 50) },
	Parts = {
		P(H, CY, V(0.55, 1.25, 1.25), HAT, FA, 0, 0.78, 0, 0, 0, 90),
		P(H, CY, V(0.1, 1.9, 1.9), HAT, FA, 0, 0.55, 0, 0, 0, 90),
		P(H, CY, V(0.15, 1.27, 1.27), BLK, SP, 0, 0.6, 0, 0, 0, 90),
		P(T, B, V(1.6, 0.55, 0.2), C(160, 130, 90), FA, 0, 1.15, 0.45),
		P(T, B, V(0.2, 0.5, 0.9), C(160, 130, 90), FA, -0.78, 1.1, 0),
		P(T, B, V(0.2, 0.5, 0.9), C(160, 130, 90), FA, 0.78, 1.1, 0),
		P(T, B, V(2.05, 0.25, 1.05), C(120, 95, 65), FA, 0, -0.6, 0),
		P(T, B, V(2.0, 1.1, 0.1), TAN, FA, 0, -1.5, 0.53),
		P(RA, CY, V(0.7, 0.12, 0.12), C(60, 40, 30), WO, 0, -1.15, -0.45, 0, 0, 90),
		P(RA, CY, V(0.08, 0.6, 0.6), C(200, 230, 255), GL, 0, -0.6, -0.45, 0, 90, 0, { Transparency = 0.3 }),
	},
})
S({ Id = "Accountant_Epic", Character = "Accountant", Rarity = "Epic", Name = "Wall Street Wolf",
	Desc = "Buy low. Sell high. Yell constantly into a brick phone.",
	Outfit = { Shirt = C(245, 245, 250), Pants = C(30, 40, 70) },
	Parts = join({
		P(H, B, V(1.3, 0.35, 1.3), C(40, 30, 25), SP, 0, 0.6, 0.05, { Reflect = 0.3 }),
		P(H, B, V(1.3, 0.6, 0.3), C(40, 30, 25), SP, 0, 0.35, 0.55, { Reflect = 0.3 }),
		P(T, B, V(0.18, 2.05, 0.06), C(200, 30, 40), SP, -0.45, 0, -0.52),
		P(T, B, V(0.18, 2.05, 0.06), C(200, 30, 40), SP, 0.45, 0, -0.52),
		P(T, B, V(0.3, 1.3, 0.06), GOLD, SP, 0, 0.25, -0.54),
		P(T, B, V(0.35, 0.25, 0.08), GOLD, SP, 0, 0.9, -0.54),
		P(LA, B, V(0.35, 0.9, 0.25), DARK, SP, 0, -1.25, -0.35),
		P(LA, CY, V(0.5, 0.06, 0.06), DARK, SP, 0.1, -0.6, -0.35, 0, 0, 90),
		P(RA, B, V(0.5, 0.25, 0.8), C(110, 200, 100), SP, 0, -1.15, -0.4),
		P(RA, B, V(0.52, 0.27, 0.15), GOLD, SP, 0, -1.15, -0.4),
		P(H, B, V(2.6, 0.4, 0.06), C(15, 20, 15), SP, 0, 1.5, 0, { Text = { Text = "▲ STONKS +420%   ▲ COFFEE +12%   ▼ MONDAYS -99%   ",
			Font = "Code", Color = GREEN, Scroll = 0.22, Width = 5, Face = "Both" }, Anim = { Bob = 0.12, Seed = 13 } }),
		P(H, B, V(2.7, 0.06, 0.08), GREEN, NE, 0, 1.73, 0, { Anim = { Bob = 0.12, Seed = 13 } }),
	}, pair(LL, RL, B, V(1.1, 0.4, 1.25), C(25, 25, 28), SP, 0, -0.82, -0.1, { Reflect = 0.4 })),
	FX = { Orbit = { Color = C(110, 200, 100), Count = 3, Shape = "Block", Size = 0.4, Speed = 1.8 } },
})
S({ Id = "Accountant_Legendary", Character = "Accountant", Rarity = "Legendary", Name = "Bull Market Baron",
	Desc = "When he charges, the market goes up. And so does your blood pressure.",
	Outfit = { Shirt = C(30, 110, 60), Pants = C(25, 80, 45) },
	Parts = join({
		P(H, BA, V(1.45, 0.8, 1.45), GOLD, ME, 0, 0.62, 0.05),
		P(H, CY, V(0.8, 0.3, 0.3), GOLD, ME, -0.95, 0.65, 0, 0, 0, -20),
		P(H, CY, V(0.8, 0.3, 0.3), GOLD, ME, 0.95, 0.65, 0, 0, 0, 20),
		P(H, B, V(0.22, 0.6, 0.22), C(255, 240, 150), NE, -1.4, 1.05, 0, 0, 0, -25),
		P(H, B, V(0.22, 0.6, 0.22), C(255, 240, 150), NE, 1.4, 1.05, 0, 0, 0, 25),
		P(H, BA, V(0.18, 0.18, 0.18), GOLD, NE, 0, -0.15, -0.64, { Transform = true,
			Particles = { Kind = "Smoke", Color = WHT, Rate = 10, Dir = "Front", Speed = 3, Size = 0.5, Life = 0.6, TransformOnly = true } }),
		P(T, B, V(0.4, 1.1, 0.06), GOLD, FO, -0.42, 0.4, -0.53, 0, 0, 12),
		P(T, B, V(0.4, 1.1, 0.06), GOLD, FO, 0.42, 0.4, -0.53, 0, 0, -12),
		P(T, B, V(0.25, 1.1, 0.06), GREEN, NE, 0, 0.3, -0.55),
		P(T, B, V(2.3, 0.4, 0.05), C(10, 30, 15), SP, 0, -0.75, -0.62, { Text = { Text = "BULL RUN ▲▲▲ +1000% ▲▲▲ ", Font = "Code",
			Color = GREEN, Scroll = 0.3, Width = 4 } }),
		P(T, CY, V(0.2, 2.0, 2.0), GOLD, ME, 0, 0.6, 1.7, 0, 90, 0, { Anim = { Spin = 60, Bob = 0.15 } }),
		P(RA, CY, V(2.0, 0.14, 0.14), DARK, SP, 0, -2.0, -0.45, 0, 0, 90),
		P(RA, BA, V(0.4, 0.4, 0.4), GOLD, NE, 0, -0.95, -0.45),
	}, pair(LA, RA, B, V(1.2, 0.4, 1.2), GOLD, ME, 0, 0.85, 0),
	pair(LA, RA, B, V(1.08, 0.25, 1.08), GOLD, NE, 0, -0.75, 0),
	pair(LL, RL, B, V(1.12, 0.4, 1.3), GOLD, ME, 0, -0.82, -0.12)),
	FX = { PowerAura = GREEN, Orbit = { Color = GOLD, Count = 4, Shape = "Cylinder", Size = 0.5, Material = "Metal", Speed = 2 } },
	Highlight = { Outline = GOLD },
	HitColor = GOLD,
})

-- ===================== CEO =====================
local GREYH, JEANS = C(150, 150, 160), C(60, 80, 130)
S({ Id = "CEO_Rare", Character = "CEO", Rarity = "Rare", Name = "Hoodie Founder",
	Desc = "Move fast and break the printer. Worth 40 billion. Wears sandals.",
	Outfit = { Shirt = GREYH, Pants = JEANS },
	Parts = {
		P(T, B, V(1.6, 0.5, 0.6), C(140, 140, 150), FA, 0, 0.95, 0.45),
		P(T, B, V(0.06, 0.6, 0.06), WHT, SP, -0.2, 0.6, -0.53),
		P(T, B, V(0.06, 0.6, 0.06), WHT, SP, 0.2, 0.6, -0.53),
		P(T, B, V(1.3, 0.5, 0.06), C(140, 140, 150), FA, 0, -0.55, -0.53),
		P(T, B, V(0.55, 0.7, 0.06), WHT, SP, 0.45, 0.0, -0.56, { Text = { Text = "FOUNDER", Color = DARK, Font = "Black" } }),
		P(H, B, V(0.8, 0.8, 0.08), C(60, 120, 255), SP, 0, 1.6, 0, { Text = { Text = "LIKE", Font = "Black", Face = "Both" }, Anim = { Bob = 0.15, Seed = 14 } }),
		P(H, B, V(1.2, 0.3, 0.05), WHT, SP, 0, 2.15, 0, { Transparency = 1, Text = { Text = "+999K", Face = "Both" }, Anim = { Bob = 0.15, Seed = 14 } }),
		P(LL, B, V(1.1, 0.12, 1.3), DARK, SP, 0, -0.98, -0.12),
		P(RL, B, V(1.1, 0.12, 1.3), DARK, SP, 0, -0.98, -0.12),
	},
})
S({ Id = "CEO_Epic", Character = "CEO", Rarity = "Epic", Name = "Tech Visionary",
	Desc = "It's not a stapler. It's a revolution. Available in black.",
	Outfit = { Shirt = C(25, 25, 30), Pants = JEANS },
	Parts = join({
		P(T, CY, V(0.35, 1.15, 1.15), C(25, 25, 30), FA, 0, 1.1, 0, 0, 0, 90),
		P(H, CY, V(0.06, 0.4, 0.4), C(220, 230, 240), GL, -0.25, 0.12, -0.62, 0, 90, 0, { Transparency = 0.35 }),
		P(H, CY, V(0.06, 0.4, 0.4), C(220, 230, 240), GL, 0.25, 0.12, -0.62, 0, 90, 0, { Transparency = 0.35 }),
		P(H, B, V(0.2, 0.04, 0.04), C(180, 180, 190), ME, 0, 0.15, -0.63),
		P(RA, B, V(0.25, 0.15, 0.6), C(220, 220, 225), SP, 0, -1.1, -0.35),
		P(RA, BA, V(0.1, 0.1, 0.1), RED, NE, 0, -1.1, -0.67),
		P(T, B, V(2.0, 1.15, 0.08), C(15, 15, 20), SP, 2.2, 1.8, 0.3, 0, -25, 0, { Text = { Text = "THE FUTURE.", Font = "Black", Face = "Both" },
			Anim = { Bob = 0.15, Seed = 15 } }),
		P(T, B, V(2.15, 1.3, 0.05), WHT, NE, 2.2, 1.8, 0.3, 0, -25, 0, { Anim = { Bob = 0.15, Seed = 15 } }),
	}, headsetMic(C(230, 200, 170)), pair(LL, RL, B, V(1.12, 0.42, 1.3), C(240, 240, 245), SP, 0, -0.81, -0.12)),
	FX = { Spotlight = C(255, 255, 240) },
})
local SUIT = C(235, 235, 240)
S({ Id = "CEO_Legendary", Character = "CEO", Rarity = "Legendary", Name = "Rocket Mogul",
	Desc = "Moving the head office to orbit. Parking is still a nightmare.",
	Outfit = { Shirt = SUIT, Pants = SUIT },
	Parts = join({
		P(H, BA, V(1.9, 1.9, 1.9), C(200, 230, 255), GL, 0, 0.15, 0, { Transparency = 0.6, Reflect = 0.3 }),
		P(T, CY, V(0.3, 1.6, 1.6), C(200, 200, 210), ME, 0, 1.05, 0, 0, 0, 90),
		P(T, B, V(1.2, 0.8, 0.15), C(60, 60, 70), SP, 0, 0.3, -0.55),
		P(T, B, V(0.9, 0.15, 0.05), GOLD, NE, 0, 0.45, -0.64, { Anim = { Pulse = 0.5 } }),
		P(T, B, V(0.25, 0.15, 0.05), RED, NE, -0.3, 0.15, -0.64, { Anim = { Pulse = 0.6, PulseSpeed = 5 } }),
		P(LA, CY, V(0.05, 0.5, 0.5), GOLD, SP, -0.52, 0.45, 0),
		-- mini-fusée dorsale
		P(T, CY, V(2.0, 0.8, 0.8), WHT, SP, 0, 0.2, 0.95, 0, 0, 90),
		P(T, BA, V(0.8, 1.0, 0.8), RED, SP, 0, 1.3, 0.95),
		P(T, CY, V(0.2, 0.82, 0.82), RED, SP, 0, -0.2, 0.95, 0, 0, 90),
		P(T, B, V(0.5, 0.6, 0.1), RED, SP, -0.55, -0.6, 0.95, 0, 0, 20),
		P(T, B, V(0.5, 0.6, 0.1), RED, SP, 0.55, -0.6, 0.95, 0, 0, -20),
		P(T, CY, V(0.1, 0.35, 0.35), C(120, 200, 255), NE, 0, 0.6, 1.35, 0, 90, 0),
		P(T, BA, V(0.6, 0.9, 0.6), C(255, 160, 40), NE, 0, -1.2, 0.95, { Anim = { Pulse = 0.5, PulseSpeed = 12, Bob = 0.05, BobSpeed = 14 },
			Particles = { Kind = "Fire", Color = C(255, 140, 30), Rate = 20, Dir = "Bottom", Speed = 5, Size = 0.6, Life = 0.4, React = true } }),
		-- planète + anneau + lune en orbite
		P(T, BA, V(0.7, 0.7, 0.7), C(255, 120, 60), SP, 2.6, 1.4, 0, { Anim = { Circle = 0.8, Seed = 16 } }),
		P(T, CY, V(0.05, 1.25, 1.25), C(255, 220, 150), NE, 2.6, 1.4, 0, 0, 0, 70, { Transparency = 0.35, Anim = { Circle = 0.8, Seed = 16 } }),
		P(T, BA, V(0.45, 0.45, 0.45), C(220, 220, 230), SP, -2.6, 0.6, 0, { Anim = { Circle = 0.8, Seed = 16 } }),
		-- réacteurs aux bottes pendant la transformation
		P(LL, BA, V(0.6, 0.6, 0.6), C(120, 200, 255), NE, 0, -1.25, 0, { Transform = true, Anim = { Pulse = 0.5, PulseSpeed = 12 },
			Particles = { Kind = "Fire", Color = C(120, 200, 255), Dir = "Bottom", Rate = 15, Speed = 4, Size = 0.5, Life = 0.35, TransformOnly = true } }),
		P(RL, BA, V(0.6, 0.6, 0.6), C(120, 200, 255), NE, 0, -1.25, 0, { Transform = true, Anim = { Pulse = 0.5, PulseSpeed = 12, Seed = 1 },
			Particles = { Kind = "Fire", Color = C(120, 200, 255), Dir = "Bottom", Rate = 15, Speed = 4, Size = 0.5, Life = 0.35, TransformOnly = true } }),
	}, pair(LA, RA, B, V(1.1, 0.5, 1.1), C(60, 60, 70), SP, 0, -0.8, 0),
	pair(LL, RL, B, V(1.2, 0.8, 1.3), C(200, 200, 210), SP, 0, -0.65, -0.05)),
	FX = { PowerAura = GOLD },
	Highlight = { Outline = C(255, 210, 80) },
	HitColor = C(255, 160, 40),
})

-- ===================== HR MANAGER =====================
S({ Id = "HRManager_Rare", Character = "HRManager", Rarity = "Rare", Name = "Zen Wellness Coach",
	Desc = "Breathe in. Breathe out. You're fired. Namaste.",
	Outfit = { Shirt = C(200, 160, 240), Pants = C(110, 60, 150), ArmsSkin = true },
	Parts = {
		P(H, CY, V(0.15, 1.32, 1.32), C(80, 170, 90), SP, 0, 0.55, 0, 0, 0, 90),
		P(H, BA, V(0.32, 0.32, 0.32), C(255, 130, 190), SP, -0.42, 0.6, -0.42),
		P(H, BA, V(0.32, 0.32, 0.32), C(255, 230, 90), SP, 0, 0.62, -0.62),
		P(H, BA, V(0.32, 0.32, 0.32), WHT, SP, 0.42, 0.6, -0.42),
		P(H, BA, V(0.32, 0.32, 0.32), C(190, 110, 255), SP, 0.62, 0.6, 0),
		P(T, CY, V(2.4, 0.45, 0.45), C(150, 90, 220), SP, 0, 0.1, 0.75, 0, 0, 40),
		P(H, CY, V(0.15, 0.7, 0.7), C(255, 150, 210), NE, 0, 1.5, 0, 0, 0, 90, { Anim = { Bob = 0.15, Swing = 10, SwingSpeed = 1.2 } }),
		P(LA, CY, V(0.7, 0.3, 0.3), C(150, 220, 255), GL, 0, -1.25, -0.3, 0, 0, 90, { Transparency = 0.2 }),
	},
})
S({ Id = "HRManager_Epic", Character = "HRManager", Rarity = "Epic", Name = "Talk Show Host",
	Desc = "Tell me... how does that performance review make you feel?",
	Outfit = { Shirt = C(190, 90, 230), Pants = C(40, 30, 60) },
	Parts = {
		P(H, BA, V(1.6, 1.25, 1.5), C(70, 40, 30), SP, 0, 0.5, 0.3),
		P(LA, B, V(0.7, 0.95, 0.06), WHT, SP, 0, -1.0, -0.62, { Text = { Text = "SMILE!", Color = C(190, 90, 230), Font = "Black" } }),
		P(RA, CY, V(0.7, 0.18, 0.18), DARK, SP, 0, -1.0, -0.65, 0, 0, 90),
		P(RA, BA, V(0.3, 0.3, 0.3), C(180, 180, 190), ME, 0, -0.55, -0.65),
		P(H, B, V(2.0, 0.5, 0.12), C(255, 40, 60), NE, 0, 1.75, 0, { Text = { Text = "APPLAUSE", Font = "Black", Face = "Both", Blink = 2 },
			Anim = { Float = true }, Particles = { Kind = "Sparkle", Color = C(255, 210, 90), Rate = 6, Speed = 2, Size = 0.35, Life = 0.8 } }),
		P(T, B, V(0.4, 1.1, 0.06), C(255, 200, 240), FO, -0.45, 0.35, -0.53, 0, 0, 12),
		P(T, B, V(0.4, 1.1, 0.06), C(255, 200, 240), FO, 0.45, 0.35, -0.53, 0, 0, -12),
		P(H, CY, V(0.05, 0.36, 0.36), GOLD, NE, -0.63, -0.25, 0),
		P(H, CY, V(0.05, 0.36, 0.36), GOLD, NE, 0.63, -0.25, 0),
		P(LL, B, V(1.05, 0.35, 1.2), C(190, 90, 230), SP, 0, -0.85, -0.1),
		P(RL, B, V(1.05, 0.35, 1.2), C(190, 90, 230), SP, 0, -0.85, -0.1),
	},
	FX = { Spotlight = C(255, 220, 250) },
})
local SEQ, LIL = C(255, 210, 60), C(200, 90, 255)
local spokes = {}
for i, col in ipairs({ C(255, 80, 200), SEQ, CYAN, C(150, 255, 60) }) do
	spokes[#spokes + 1] = P(T, B, V(1.6, 0.16, 0.28), col, NE, -2.1, 1.9, 0.2, 0, 0, (i - 1) * 45, { Anim = { Spin = 90, Axis = "Z", React = true, Seed = 17 } })
end
S({ Id = "HRManager_Legendary", Character = "HRManager", Rarity = "Legendary", Name = "Prime Time Host",
	Desc = "Spin the wheel... of PERFORMANCE REVIEWS! Live, in front of everyone!",
	Outfit = { Shirt = C(140, 50, 200), Pants = C(60, 25, 90) },
	Parts = join(spokes, {
		P(T, CY, V(0.1, 1.75, 1.75), WHT, SP, -2.1, 1.9, 0.2, 0, 90, 0),
		P(T, CY, V(0.34, 0.36, 0.36), SEQ, ME, -2.1, 1.9, 0.2, 0, 90, 0),
		P(H, B, V(1.3, 0.35, 1.3), C(210, 210, 220), SP, 0, 0.6, 0.05, { Reflect = 0.3 }),
		P(H, BA, V(1.0, 0.5, 0.6), C(210, 210, 220), SP, 0, 0.75, -0.35, { Reflect = 0.3 }),
		P(T, B, V(0.45, 1.2, 0.06), SEQ, FO, -0.45, 0.35, -0.53, 0, 0, 12),
		P(T, B, V(0.45, 1.2, 0.06), SEQ, FO, 0.45, 0.35, -0.53, 0, 0, -12),
		P(T, B, V(0.7, 0.25, 0.1), SEQ, NE, 0, 0.85, -0.55),
		P(T, B, V(0.3, 0.2, 0.06), C(255, 120, 200), NE, -0.6, 0.5, -0.56),
		P(RA, CY, V(1.0, 0.2, 0.2), GOLD, ME, 0, -1.0, -0.65, 0, 0, 90),
		P(RA, BA, V(0.45, 0.45, 0.45), GOLD, FO, 0, -0.35, -0.65, { Reflect = 0.2 }),
		P(LA, B, V(0.6, 0.85, 0.06), SEQ, SP, 0, -1.05, -0.6),
		P(H, B, V(2.4, 0.6, 0.12), SEQ, NE, 0, 1.9, 0, { Transform = true, Text = { Text = "★ WINNER ★", Color = C(140, 50, 200),
			Font = "Black", Face = "Both", Blink = 3 }, Anim = { Float = true } }),
	}, pair(LL, RL, B, V(1.1, 0.4, 1.25), C(240, 240, 245), SP, 0, -0.82, -0.1, { Reflect = 0.3 })),
	FX = { Spotlight = C(255, 230, 180), PowerAura = LIL },
	Highlight = { Outline = SEQ },
	HitColor = LIL,
})

-- ===================== BARISTA =====================
local BREW, CREAM, BEAN = C(150, 95, 55), C(250, 240, 220), C(110, 65, 35)
S({ Id = "Barista_Rare", Character = "Barista", Rarity = "Rare", Name = "Latte Art Influencer",
	Desc = "Posts the foam. Never drinks it. 12K likes on a heart.",
	Outfit = { Shirt = C(240, 230, 215), Pants = C(70, 55, 45) },
	Parts = {
		P(H, CY, V(0.3, 1.45, 1.45), C(40, 35, 35), FA, 0, 0.66, 0.05, 0, 0, 82),
		P(H, BA, V(0.2, 0.2, 0.2), C(40, 35, 35), FA, 0.05, 0.85, 0),
		P(T, B, V(1.5, 0.35, 1.1), C(200, 120, 70), FA, 0, 0.95, 0),
		P(T, B, V(0.35, 0.9, 0.1), C(200, 120, 70), FA, 0.35, 0.4, -0.56),
		P(RA, CY, V(0.6, 0.55, 0.55), WHT, SP, 0, -1.2, -0.45, 0, 0, 90),
		P(RA, CY, V(0.05, 0.5, 0.5), C(220, 180, 130), SP, 0, -0.88, -0.45, 0, 0, 90, {
			Particles = { Kind = "Smoke", Color = WHT, Rate = 4, Speed = 1, Size = 0.3, Life = 1 } }),
		P(LA, B, V(0.5, 0.85, 0.08), DARK, SP, 0, -1.15, -0.5, { Text = { Text = "♥ 12K", Color = C(255, 90, 150), Font = "Black" } }),
	},
})
S({ Id = "Barista_Epic", Character = "Barista", Rarity = "Epic", Name = "ASMR Brewmaster",
	Desc = "*whispers* ...your espresso... is ready... *tap tap tap*",
	Outfit = { Shirt = C(60, 45, 40), Pants = C(45, 35, 30) },
	Parts = {
		P(H, B, V(1.42, 0.14, 0.3), CREAM, SP, 0, 0.7, 0),
		P(H, B, V(0.12, 0.6, 0.2), CREAM, SP, -0.7, 0.42, 0),
		P(H, B, V(0.12, 0.6, 0.2), CREAM, SP, 0.7, 0.42, 0),
		P(H, CY, V(0.28, 0.62, 0.62), BREW, SP, -0.71, 0.05, 0),
		P(H, CY, V(0.28, 0.62, 0.62), BREW, SP, 0.71, 0.05, 0),
		P(RA, CY, V(0.8, 0.12, 0.12), DARK, ME, 0, -1.15, -0.6, 0, 0, 90),
		P(RA, BA, V(0.75, 0.75, 0.75), C(230, 225, 215), FA, 0, -0.55, -0.65),
		P(T, B, V(1.7, 2.3, 0.08), BREW, FA, 0, -0.45, -0.53),
		P(T, B, V(1.0, 0.4, 0.05), BREW, FA, 0, -0.6, -0.58, { Text = { Text = "shhh...", Font = "Serif", Color = C(255, 240, 220) } }),
		P(LA, CY, V(0.4, 0.45, 0.45), WHT, SP, 0, -1.2, -0.4, 0, 0, 90, {
			Particles = { Kind = "Smoke", Color = WHT, Rate = 5, Speed = 1.2, Size = 0.35, Life = 1.2 } }),
		P(H, B, V(1.9, 0.45, 0.05), WHT, SP, 0, 1.6, 0, { Transparency = 1,
			Text = { Text = "~ tap tap tap ~", Font = "Serif", Color = C(255, 230, 200), Face = "Both" }, Anim = { Float = true } }),
	},
	FX = { Orbit = { Color = BEAN, Count = 4, Shape = "Ball", Size = 0.35, Material = "SmoothPlastic", Speed = 1.2 } },
})
local ROBE, GLOWB = C(90, 55, 35), C(255, 170, 80)
S({ Id = "Barista_Legendary", Character = "Barista", Rarity = "Legendary", Name = "Caffeine Archmage",
	Desc = "Brews forbidden potions. Mostly espresso. Foam beard of wisdom.",
	Outfit = { Shirt = ROBE, Pants = C(60, 40, 28) },
	Parts = join({
		P(H, CY, V(0.1, 2.0, 2.0), C(70, 40, 25), FA, 0, 0.55, 0, 0, 0, 90),
		P(H, CY, V(0.6, 1.25, 1.25), C(70, 40, 25), FA, 0, 0.85, 0, 0, 0, 90),
		P(H, CY, V(0.6, 0.9, 0.9), C(70, 40, 25), FA, 0, 1.4, 0.1, 0, 0, 90),
		P(H, CY, V(0.6, 0.55, 0.55), C(70, 40, 25), FA, 0, 1.9, 0.25, 0, 0, 90),
		P(H, BA, V(0.35, 0.35, 0.35), C(255, 200, 120), NE, 0, 2.3, 0.35, { Anim = { Pulse = 0.4 } }),
		P(H, CY, V(0.12, 1.27, 1.27), GLOWB, NE, 0, 0.66, 0, 0, 0, 90),
		P(H, B, V(0.9, 0.9, 0.35), CREAM, SP, 0, -0.6, -0.5),
		P(T, B, V(2.1, 1.0, 1.1), ROBE, FA, 0, -1.3, 0),
		P(T, B, V(2.12, 0.1, 1.12), GLOWB, NE, 0, -1.78, 0),
		P(T, B, V(2.3, 0.4, 1.2), C(70, 40, 25), FA, 0, 0.9, 0),
		P(T, B, V(2.05, 0.2, 1.05), GLOWB, NE, 0, -0.75, 0),
		P(LA, CY, V(3.4, 0.16, 0.16), C(110, 70, 40), WO, 0, -0.6, -0.55, 0, 0, 90),
		P(LA, CY, V(0.5, 0.5, 0.5), WHT, SP, 0, 1.45, -0.55, 0, 0, 90, { Anim = { Bob = 0.15, Seed = 18 } }),
		P(LA, BA, V(0.45, 0.45, 0.45), C(255, 180, 90), NE, 0, 1.8, -0.55, { Anim = { Bob = 0.15, Seed = 18 },
			Particles = { Kind = "Smoke", Color = C(255, 230, 200), Rate = 6, Speed = 1.5, Size = 0.4, Life = 1.2 } }),
		P(T, CY, V(0.05, 4.0, 4.0), GLOWB, NE, 0, -2.95, 0, 0, 0, 90, { Transparency = 0.6, Anim = { Pulse = 0.3, React = true } }),
		P(H, CY, V(0.08, 1.6, 1.6), C(255, 200, 120), NE, 0, 2.7, 0.35, 0, 0, 90, { Transform = true, Transparency = 0.3, Anim = { Bob = 0.1 },
			Particles = { Kind = "Smoke", Color = C(255, 230, 200), Rate = 10, Speed = 1, Size = 0.6, Life = 1.5, TransformOnly = true } }),
	}, pair(LA, RA, B, V(1.3, 0.6, 1.3), ROBE, FA, 0, -0.7, 0)),
	FX = { PowerAura = GLOWB, HandTrails = C(255, 180, 90), Orbit = { Color = BEAN, Count = 4, Shape = "Ball", Size = 0.4, Material = "SmoothPlastic", Speed = 1.5 } },
	Highlight = { Outline = GLOWB },
	HitColor = GLOWB,
})

-- ===================== DELIVERY GUY =====================
local COUR = C(40, 200, 120)
S({ Id = "DeliveryGuy_Rare", Character = "DeliveryGuy", Rarity = "Rare", Name = "Food Courier",
	Desc = "Your order is 2 minutes away. For the next 40 minutes.",
	Outfit = { Shirt = COUR, Pants = C(40, 40, 48) },
	Parts = join({
		P(T, B, V(1.7, 1.7, 1.3), COUR, SP, 0, 0.2, 1.15, { Text = { Text = "YUM!", Font = "Black", Face = "Back" } }),
		P(T, B, V(1.72, 0.2, 1.32), C(235, 235, 235), FO, 0, -0.35, 1.15),
		P(H, BA, V(1.4, 0.95, 1.5), COUR, SP, 0, 0.55, 0.05),
		P(LA, B, V(0.55, 0.8, 0.1), DARK, SP, 0, 0.2, -0.56, { Text = { Text = "ETA\n2 MIN", Font = "Code", Color = GREEN } }),
	}, sneakers(WHT, COUR)),
})
local RACE, STRIPE = C(215, 50, 45), C(255, 200, 40)
S({ Id = "DeliveryGuy_Epic", Character = "DeliveryGuy", Rarity = "Epic", Name = "Pit Stop Racer",
	Desc = "Delivered in 2.3 seconds. Changed the office chair tires too.",
	Outfit = { Shirt = RACE, Pants = RACE },
	Parts = join({
		P(H, BA, V(1.5, 1.4, 1.5), C(240, 240, 245), SP, 0, 0.15, 0.05),
		P(H, B, V(1.2, 0.35, 0.15), C(30, 30, 40), GL, 0, 0.15, -0.66, { Reflect = 0.5 }),
		P(T, B, V(0.25, 2.04, 1.04), STRIPE, SP, -0.55, 0, 0),
		P(T, B, V(0.25, 2.04, 1.04), STRIPE, SP, 0.55, 0, 0),
		P(T, B, V(0.7, 0.35, 0.05), WHT, SP, -0.15, 0.55, -0.53, { Text = { Text = "TURBO", Font = "Black", Color = RACE } }),
		P(T, B, V(0.7, 0.35, 0.05), WHT, SP, 0.1, -0.2, -0.53, { Text = { Text = "ZOOM", Font = "Black", Color = C(30, 30, 40) } }),
		P(T, B, V(0.9, 0.9, 0.05), WHT, SP, 0, 0.2, 0.53, { Text = { Text = "07", Font = "Black", Color = RACE, Face = "Back" } }),
		P(RA, CY, V(1.6, 0.1, 0.1), C(200, 200, 210), ME, 0, -0.5, -0.55, 0, 0, 90),
		P(RA, B, V(1.0, 0.7, 0.05), WHT, SP, 0.55, 0.0, -0.55, { Text = { Text = "■□■□\n□■□■", Color = BLK, Face = "Both" },
			Anim = { Swing = 15, SwingAxis = "Y", SwingSpeed = 6 } }),
		P(T, B, V(2.4, 0.12, 0.6), DARK, SP, 0, 1.1, 1.1),
		P(T, B, V(0.1, 0.5, 0.1), DARK, SP, -0.6, 0.85, 0.85),
		P(T, B, V(0.1, 0.5, 0.1), DARK, SP, 0.6, 0.85, 0.85),
	}, pair(LL, RL, B, V(1.12, 0.5, 1.3), DARK, SP, 0, -0.75, -0.1, { Trail = { Color = STRIPE, Width = 0.4 } }),
	pair(LA, RA, B, V(1.1, 0.45, 1.1), DARK, SP, 0, -0.8, 0)),
})
local CASH = C(110, 200, 100)
local bills = {}
for i, a in ipairs({ 0, 90, 180, 270 }) do
	bills[#bills + 1] = ring(T, B, V(0.9, 0.05, 0.45), CASH, SP, 2.4, i % 2 == 0 and 0.8 or 0.2, a, { Anim = { Circle = 1.6, Bob = 0.3, Seed = 19 } }, 0)
end
local giftCrown = {}
for _, a in ipairs({ 0, 90, 180, 270 }) do
	local r = math.rad(a)
	giftCrown[#giftCrown + 1] = P(H, B, V(0.25, 0.45, 0.25), GOLD, ME, 0.5 * math.cos(r), 1.05, 0.5 * math.sin(r), 0, 45, 0)
end
S({ Id = "DeliveryGuy_Legendary", Character = "DeliveryGuy", Rarity = "Legendary", Name = "Giveaway King",
	Desc = "EVERYONE GETS A PACKAGE!!! Smash subscribe for a chance to win a stapler!",
	Outfit = { Shirt = RACE, Pants = C(40, 40, 48) },
	Parts = join(bills, giftCrown, {
		P(H, CY, V(0.35, 1.36, 1.36), GOLD, ME, 0, 0.72, 0, 0, 0, 90),
		-- canon à billets sur l'épaule
		P(T, CY, V(1.8, 0.5, 0.5), DARK, ME, 1.3, 1.35, -0.2, 0, 90, 0),
		P(T, CY, V(0.2, 0.65, 0.65), GOLD, NE, 1.3, 1.35, -1.1, 0, 90, 0, {
			Particles = { Kind = "Spark", Color = CASH, Rate = 8, Dir = "Right", Speed = 8, Size = 0.4, Life = 0.8, Accel = -10, Spread = 15 } }),
		P(T, B, V(0.6, 0.4, 0.6), GOLD, ME, 1.3, 1.1, 0.1),
		P(T, B, V(0.12, 0.85, 0.08), GOLD, FO, -0.26, 0.55, -0.54, 0, 0, 35),
		P(T, B, V(0.12, 0.85, 0.08), GOLD, FO, 0.26, 0.55, -0.54, 0, 0, -35),
		P(T, B, V(0.55, 0.55, 0.08), GOLD, NE, 0, 0.1, -0.58, { Text = { Text = "$", Font = "Black", Color = C(60, 40, 0) } }),
		P(H, B, V(2.2, 0.6, 0.12), C(255, 230, 60), NE, 0, 1.9, 0, { Text = { Text = "FREE PACKAGES!", Font = "Black", Color = RACE,
			Face = "Both", Blink = 2 }, Anim = { Float = true } }),
		P(LA, B, V(0.9, 0.9, 0.9), C(200, 150, 90), SP, 0, -1.3, -0.6),
		P(LA, B, V(0.92, 0.92, 0.2), RED, SP, 0, -1.3, -0.6),
		P(LA, BA, V(0.45, 0.3, 0.45), RED, SP, 0, -0.8, -0.6),
		P(T, B, V(2.0, 2.4, 0.1), C(180, 30, 40), FA, 0, -0.3, 0.6, 6, 0, 0, { Anim = { Swing = 4, SwingAxis = "X", SwingSpeed = 1.6 } }),
		P(H, B, V(2.0, 0.1, 2.0), GOLD, SP, 0, 2.6, 0, { Transparency = 1,
			Particles = { Kind = "Spark", Color = CASH, Rate = 25, Dir = "Bottom", Speed = 2, Size = 0.5, Life = 1.5, Accel = -4, Spread = 40, TransformOnly = true } }),
	}, pair(LL, RL, B, V(1.15, 0.45, 1.35), GOLD, ME, 0, -0.8, -0.15)),
	FX = { PowerAura = GOLD },
	Highlight = { Outline = GOLD },
	HitColor = CASH,
})

-- ===================== RECEPTIONIST =====================
local FUCH, BUTTER = C(230, 85, 175), C(255, 240, 120)
S({ Id = "Receptionist_Rare", Character = "Receptionist", Rarity = "Rare", Name = "Retro Phone Diva",
	Desc = "Hold, please. Forever. Your call is very important to her nails.",
	Outfit = { Shirt = C(255, 120, 190), Pants = C(60, 50, 78) },
	Parts = join({
		P(H, BA, V(0.9, 0.9, 0.9), C(80, 40, 30), SP, 0, 0.8, 0.35),
		P(T, B, V(1.3, 0.3, 1.05), BUTTER, FA, 0, 0.9, 0),
		P(RA, B, V(0.3, 1.0, 0.3), BUTTER, SP, 0, -1.3, -0.45),
		P(RA, CY, V(1.2, 0.12, 0.12), BUTTER, FF, 0, -0.4, -0.4, 0, 0, 90),
	}, shades(WHT, C(255, 60, 160))),
})
S({ Id = "Receptionist_Epic", Character = "Receptionist", Rarity = "Epic", Name = "Breaking News Anchor",
	Desc = "Good evening. Tonight: the printer is on fire. More at eleven.",
	Outfit = { Shirt = C(30, 60, 140), Pants = C(30, 35, 55) },
	Parts = join({
		P(H, B, V(1.35, 0.4, 1.35), C(240, 200, 110), SP, 0, 0.58, 0.05),
		P(H, B, V(1.35, 0.8, 0.35), C(240, 200, 110), SP, 0, 0.15, 0.55),
		P(H, BA, V(0.15, 0.15, 0.15), DARK, SP, 0.63, 0, 0),
		P(T, BA, V(0.15, 0.15, 0.15), DARK, SP, -0.4, 0.6, -0.55),
		P(H, B, V(2.8, 0.42, 0.06), C(200, 20, 30), SP, 0, 1.55, 0, { Text = { Text = "BREAKING: PRINTER ON FIRE • COFFEE MACHINE MISSING • MEETING COULD HAVE BEEN AN EMAIL • ",
			Font = "Black", Scroll = 0.15, Width = 7, Face = "Both" }, Anim = { Bob = 0.12, Seed = 20 } }),
		P(H, B, V(0.65, 0.42, 0.08), C(255, 230, 60), SP, -1.72, 1.55, 0, { Text = { Text = "LIVE", Color = RED, Font = "Black", Face = "Both", Blink = 1 },
			Anim = { Bob = 0.12, Seed = 20 } }),
		P(LA, B, V(0.7, 0.95, 0.06), WHT, SP, 0, -1.0, -0.58, { Text = { Text = "NEWS", Color = DARK, Font = "Serif" } }),
		P(T, B, V(0.4, 1.1, 0.06), C(245, 245, 250), SP, -0.42, 0.4, -0.53, 0, 0, 12),
		P(T, B, V(0.4, 1.1, 0.06), C(245, 245, 250), SP, 0.42, 0.4, -0.53, 0, 0, -12),
		P(T, B, V(0.3, 0.9, 0.06), RED, SP, 0, 0.45, -0.55),
	}, pair(LL, RL, B, V(1.05, 0.35, 1.2), DARK, SP, 0, -0.85, -0.1)),
	FX = { Spotlight = WHT },
})
local PLAT, POP = C(255, 240, 180), C(255, 90, 200)
local sticks = {}
for i, col in ipairs({ PINK, CYAN, C(255, 230, 60), C(170, 90, 255) }) do
	sticks[#sticks + 1] = ring(T, CY, V(0.9, 0.16, 0.16), col, NE, 2.4, 0.6, (i - 1) * 90, { Anim = { Circle = 1.0, Bob = 0.25, Seed = 21 } }, 0)
	sticks[#sticks].Offset = sticks[#sticks].Offset * CFrame.Angles(0, 0, math.rad(90))
end
S({ Id = "Receptionist_Legendary", Character = "Receptionist", Rarity = "Legendary", Name = "Front Desk Pop Star",
	Desc = "Sold-out world tour. Still answers the phone between songs.",
	Outfit = { Shirt = POP, Pants = C(120, 40, 160) },
	Parts = join(sticks, {
		P(H, BA, V(1.45, 1.0, 1.45), PLAT, SP, 0, 0.55, 0.1),
		P(H, BA, V(0.7, 1.4, 0.7), PLAT, SP, 0, 0.9, 0.75, { Anim = { Swing = 10, SwingAxis = "X", SwingSpeed = 3 } }),
		P(T, B, V(2.05, 0.2, 1.05), PLAT, NE, 0, -0.8, 0),
		P(T, B, V(0.8, 0.8, 0.05), POP, SP, 0, 0.3, -0.53, { Text = { Text = "★", Color = PLAT } }),
		P(H, B, V(1.0, 0.1, 1.0), WHT, SP, 0, 1.3, 0, { Transparency = 1,
			Particles = { Kind = "Sparkle", Color = C(255, 150, 230), Rate = 8, Speed = 2, Size = 0.4, Life = 1 } }),
		P(T, B, V(1.6, 0.9, 0.1), C(255, 150, 230), NE, -1.4, 0.6, 0.75, 0, 20, 25, { Transform = true, Transparency = 0.2,
			Anim = { Swing = 8, SwingAxis = "Y", SwingSpeed = 4 } }),
		P(T, B, V(1.6, 0.9, 0.1), C(255, 150, 230), NE, 1.4, 0.6, 0.75, 0, -20, -25, { Transform = true, Transparency = 0.2,
			Anim = { Swing = 8, SwingAxis = "Y", SwingSpeed = 4, Seed = 0 } }),
	}, shades(WHT, POP, NE), headsetMic(PLAT, POP),
	pair(LA, RA, B, V(1.2, 0.4, 1.2), C(255, 210, 250), FO, 0, 0.85, 0),
	pair(LL, RL, B, V(1.15, 0.9, 1.3), C(255, 240, 250), SP, 0, -0.6, -0.1),
	pair(LL, RL, B, V(1.17, 0.2, 1.32), POP, NE, 0, -0.95, -0.1, { Trail = { Color = POP, Width = 0.3 } })),
	FX = { Spotlight = C(255, 150, 230), PowerAura = POP },
	Highlight = { Outline = C(255, 150, 230) },
	HitColor = POP,
})

-- ===================== FITNESS COACH =====================
local LIME = C(150, 230, 40)
S({ Id = "FitnessCoach_Rare", Character = "FitnessCoach", Rarity = "Rare", Name = "80s Aerobics Icon",
	Desc = "Feel the burn! And the deadline! Five, six, seven, eight!",
	Outfit = { Shirt = C(255, 80, 170), Pants = C(60, 200, 255), ArmsSkin = true },
	Parts = join({
		P(H, BA, V(1.6, 1.1, 1.5), C(120, 70, 40), SP, 0, 0.55, 0.3),
		P(H, CY, V(0.25, 1.34, 1.34), LIME, FA, 0, 0.35, 0, 0, 0, 90),
		P(T, B, V(2.05, 0.25, 1.05), LIME, FA, 0, -0.85, 0),
	}, pair(LA, RA, B, V(1.08, 0.3, 1.08), LIME, FA, 0, -0.6, 0),
	pair(LL, RL, B, V(1.15, 0.8, 1.15), C(255, 230, 60), FA, 0, -0.55, 0)),
})
S({ Id = "FitnessCoach_Epic", Character = "FitnessCoach", Rarity = "Epic", Name = "Gym Influencer",
	Desc = "Do you even lift... the office morale? #GAINS #BLESSED",
	Outfit = { Shirt = C(40, 40, 52), Pants = C(60, 60, 75), ArmsSkin = true },
	Parts = join({
		P(H, CY, V(0.4, 1.32, 1.32), LIME, SP, 0, 0.68, 0, 0, 0, 90),
		P(H, B, V(1.1, 0.1, 0.6), LIME, SP, 0, 0.55, 0.85),
		P(RA, B, V(0.08, 0.08, 2.0), DARK, ME, 0, -0.6, -1.0, 25, 0, 0),
		P(RA, B, V(0.5, 0.85, 0.08), DARK, SP, 0, -0.1, -1.95, { Text = { Text = "REC ●", Color = RED, Font = "Black", Face = "Back" } }),
		P(LA, CY, V(0.8, 0.4, 0.4), LIME, SP, 0, -1.25, -0.3, 0, 0, 90),
		P(LA, CY, V(0.2, 0.42, 0.42), DARK, SP, 0, -0.8, -0.3, 0, 0, 90),
		P(H, B, V(1.8, 0.5, 0.05), WHT, SP, 0, 1.6, 0, { Transparency = 1,
			Text = { Text = "#GAINS", Font = "Black", Color = LIME, Face = "Both" }, Anim = { Float = true } }),
		P(T, B, V(2.08, 0.45, 1.08), C(120, 70, 40), SP, 0, -0.75, 0),
		P(T, B, V(0.5, 0.4, 0.08), GOLD, ME, 0, -0.75, -0.55),
		P(LA, B, V(0.2, 0.2, 0.2), WHT, SP, -0.45, 0.4, 0, { Transparency = 1,
			Particles = { Kind = "Sparkle", Color = WHT, Rate = 5, Speed = 1, Size = 0.35, Life = 0.7 } }),
		P(RA, B, V(0.2, 0.2, 0.2), WHT, SP, 0.45, 0.4, 0, { Transparency = 1,
			Particles = { Kind = "Sparkle", Color = WHT, Rate = 5, Speed = 1, Size = 0.35, Life = 0.7 } }),
	}, pair(LL, RL, B, V(1.12, 0.42, 1.3), LIME, SP, 0, -0.81, -0.12)),
})
local GLOVE = C(220, 30, 40)
S({ Id = "FitnessCoach_Legendary", Character = "FitnessCoach", Rarity = "Legendary", Name = "Undisputed Champ",
	Desc = "Undefeated in 47 office fights. Trains on the stairs. All of them.",
	Outfit = { Shirt = C(30, 30, 36), Pants = LIME },
	Parts = join({
		P(T, B, V(1.7, 0.6, 0.6), C(30, 30, 36), FA, 0, 0.9, 0.5),
		P(T, B, V(0.25, 2.05, 0.06), LIME, NE, -0.4, 0, -0.53, 0, 0, 10),
		P(T, B, V(0.25, 2.05, 0.06), LIME, NE, 0.4, 0, -0.53, 0, 0, -10),
		P(T, B, V(1.6, 0.6, 0.05), C(30, 30, 36), SP, 0, 0.2, 0.53, { Text = { Text = "CHAMP", Font = "Bangers", Color = GOLD, Face = "Back" } }),
		P(T, B, V(2.1, 0.5, 1.1), C(140, 30, 30), FA, 0, -0.75, 0),
		P(T, B, V(1.0, 0.75, 0.12), GOLD, ME, 0, -0.75, -0.6, { Reflect = 0.3 }),
		P(T, BA, V(0.3, 0.3, 0.15), C(255, 50, 60), NE, 0, -0.75, -0.68),
		P(T, B, V(0.5, 0.12, 1.2), WHT, FA, -0.7, 1.05, 0),
		P(T, B, V(0.4, 0.8, 0.08), WHT, FA, -0.65, 0.6, -0.55),
		P(H, CY, V(0.12, 1.6, 1.6), GOLD, NE, 0, 1.55, 0, 0, 0, 90, { Transparency = 0.2, Anim = { Bob = 0.15 } }),
		P(H, B, V(1.5, 0.8, 0.08), WHT, SP, 0, 2.3, 0, { Transform = true, Text = { Text = "FINAL ROUND", Font = "Bangers", Color = RED, Face = "Both" },
			Anim = { Float = true } }),
	}, pair(LA, RA, BA, V(1.35, 1.2, 1.4), GLOVE, SP, 0, -1.15, 0, { Trail = { Color = C(255, 80, 60), Width = 0.8 } }),
	pair(LA, RA, CY, V(0.3, 1.1, 1.1), WHT, SP, 0, -0.55, 0),
	pair(LL, RL, B, V(1.12, 1.0, 1.15), C(240, 240, 245), SP, 0, -0.5, 0),
	pair(LL, RL, B, V(1.14, 0.12, 1.17), LIME, NE, 0, -0.3, 0)),
	FX = { Spotlight = C(255, 250, 220), PowerAura = LIME, Orbit = { Color = LIME, Count = 3, Shape = "Ball", Size = 0.35, Speed = 4 } },
	Highlight = { Outline = LIME },
	HitColor = C(255, 60, 60),
})

-- ===================== MAINTENANCE GUY =====================
local HIVIS, BELT, IRON = C(255, 210, 30), C(110, 75, 45), C(170, 170, 180)
S({ Id = "MaintenanceGuy_Rare", Character = "MaintenanceGuy", Rarity = "Rare", Name = "Hard Hat Hero",
	Desc = "Fixes everything with tape. Everything. Including the tape.",
	Outfit = { Shirt = C(255, 140, 30), Pants = C(50, 65, 90) },
	Parts = {
		P(H, BA, V(1.45, 0.9, 1.45), HIVIS, SP, 0, 0.6, 0),
		P(H, CY, V(0.1, 1.7, 1.7), HIVIS, SP, 0, 0.5, -0.05, 0, 0, 90),
		P(H, CY, V(0.15, 0.3, 0.3), WHT, NE, 0, 0.62, -0.72, 0, 90, 0, { Light = C(255, 250, 220) }),
		P(T, B, V(2.05, 0.18, 1.05), C(225, 225, 225), FO, 0, -0.2, 0),
		P(T, B, V(2.05, 0.18, 1.05), C(225, 225, 225), FO, 0, 0.3, 0),
		P(T, CY, V(0.25, 0.5, 0.5), IRON, SP, -0.85, -0.75, -0.2),
		P(T, B, V(2.08, 0.3, 1.08), BELT, SP, 0, -0.85, 0),
		P(RA, B, V(0.15, 1.0, 0.25), IRON, ME, 0, -1.3, -0.4),
	},
})
S({ Id = "MaintenanceGuy_Epic", Character = "MaintenanceGuy", Rarity = "Epic", Name = "Makeover Show Host",
	Desc = "MOVE! THAT! DESK! (He renovated your cubicle without asking.)",
	Outfit = { Shirt = C(180, 40, 40), Pants = C(60, 80, 130) },
	Parts = join({
		P(H, CY, V(0.4, 1.32, 1.32), C(240, 240, 240), SP, 0, 0.68, 0, 0, 0, 90),
		P(H, B, V(1.1, 0.1, 0.6), C(30, 60, 140), SP, 0, 0.55, -0.85),
		P(T, B, V(2.04, 0.18, 1.04), C(110, 20, 20), SP, 0, 0.3, 0),
		P(T, B, V(0.18, 2.04, 1.04), C(110, 20, 20), SP, 0.4, 0, 0),
		P(RA, CY, V(0.9, 0.5, 0.5), WHT, SP, 0, -1.1, -0.75, 0, 90, 0),
		P(RA, CY, V(0.25, 0.85, 0.85), HIVIS, SP, 0, -1.1, -1.25, 0, 90, 0),
		P(H, B, V(2.6, 0.55, 0.08), HIVIS, NE, 0, 1.6, 0, { Text = { Text = "MOVE THAT DESK!", Font = "Bangers", Color = DARK, Face = "Both", Blink = 1.5 },
			Anim = { Float = true } }),
		P(T, B, V(2.08, 0.3, 1.08), BELT, SP, 0, -0.85, 0),
		P(T, B, V(0.15, 0.9, 0.15), C(120, 80, 50), WO, 0.85, -1.2, -0.3),
		P(T, B, V(0.5, 0.2, 0.2), IRON, ME, 0.85, -0.75, -0.3),
		P(T, B, V(0.35, 0.6, 0.8), HIVIS, SP, -1.9, 1.3, 0, { Anim = { Bob = 0.15, Seed = 22 } }),
		P(T, B, V(0.1, 0.1, 0.6), IRON, ME, -1.9, 1.45, -0.65, { Anim = { Bob = 0.15, Seed = 22, Spin = 720, Axis = "Z" } }),
	}, pair(LL, RL, B, V(1.12, 0.6, 1.25), C(120, 80, 50), SP, 0, -0.72, -0.08)),
})
local MECH, MECHD, ORNG = C(255, 210, 30), C(70, 75, 90), C(255, 150, 30)
S({ Id = "MaintenanceGuy_Legendary", Character = "MaintenanceGuy", Rarity = "Legendary", Name = "Mega Mech Mechanic",
	Desc = "Brought a giant robot suit to a desk fight. Warranty void.",
	Outfit = { Shirt = C(70, 80, 100), Pants = C(50, 55, 70) },
	Parts = join({
		P(H, B, V(1.35, 1.3, 1.35), MECH, SP, 0, 0.12, 0),
		P(H, B, V(1.0, 0.35, 0.1), ORNG, NE, 0, 0.15, -0.7, { Anim = { Pulse = 0.3 } }),
		P(T, CY, V(0.5, 1.2, 1.2), C(60, 65, 80), ME, 0, 0.2, 0.75, 0, 90, 0),
		P(T, CY, V(0.55, 0.6, 0.6), ORNG, NE, 0, 0.2, 0.8, 0, 90, 0, { Anim = { Pulse = 0.4, React = true } }),
		P(T, B, V(1.6, 0.25, 0.15), IRON, ME, 0, 0.2, 1.08, { Anim = { Spin = 120, Axis = "Z", React = true, Seed = 23 } }),
		P(T, B, V(0.25, 1.6, 0.15), IRON, ME, 0, 0.2, 1.08, { Anim = { Spin = 120, Axis = "Z", React = true, Seed = 23 } }),
		P(LA, CY, V(0.6, 0.15, 0.15), IRON, ME, 0, -1.55, -0.45, 0, 90, 0),
		P(LA, BA, V(0.2, 0.2, 0.2), C(120, 200, 255), NE, 0, -1.55, -0.8, {
			Particles = { Kind = "Spark", Color = C(255, 200, 80), Rate = 20, Speed = 6, Size = 0.25, Life = 0.4, Spread = 60, Accel = -20, Dir = "Front" } }),
		P(T, CY, V(1.2, 0.3, 0.3), C(60, 65, 80), ME, -0.6, 1.1, 0.85, 0, 0, 90, {
			Particles = { Kind = "Smoke", Color = C(90, 90, 100), Rate = 4, Speed = 2, Size = 0.5, Life = 1, React = true } }),
		P(T, CY, V(1.2, 0.3, 0.3), C(60, 65, 80), ME, 0.6, 1.1, 0.85, 0, 0, 90),
		P(T, B, V(1.8, 1.0, 0.2), MECHD, ME, 0, 0.3, -0.55, { Text = { Text = "⚠ CAUTION ⚠", Font = "Black", Color = MECH } }),
	}, pair(LA, RA, B, V(1.5, 1.0, 1.5), MECH, ME, 0, 0.7, 0),
	pair(LA, RA, B, V(1.5, 1.1, 1.5), MECHD, ME, 0, -0.85, 0),
	pair(LA, RA, B, V(1.52, 0.15, 1.52), ORNG, NE, 0, -0.35, 0),
	pair(LL, RL, B, V(1.3, 1.4, 1.3), MECH, ME, 0, -0.3, 0),
	pair(LL, RL, B, V(1.35, 0.5, 1.5), MECHD, ME, 0, -0.8, -0.15)),
	FX = { PowerAura = ORNG },
	Highlight = { Outline = ORNG },
	HitColor = ORNG,
})

-- ===================== MARKETING GURU =====================
local MAG = C(205, 30, 175)
S({ Id = "MarketingGuru_Rare", Character = "MarketingGuru", Rarity = "Rare", Name = "Hashtag Hustler",
	Desc = "Personal brand: 100%. Actual work: to be determined.",
	Outfit = { Shirt = C(240, 240, 245), Pants = C(35, 35, 55), ArmsSkin = true },
	Parts = join({
		P(H, CY, V(0.4, 1.32, 1.32), MAG, SP, 0, 0.68, 0, 0, 0, 90),
		P(H, B, V(1.2, 0.08, 0.7), CYAN, SP, 0, 0.55, -0.85),
		P(H, B, V(0.6, 0.6, 0.1), CYAN, NE, 0, 1.55, 0, { Text = { Text = "#", Font = "Black", Face = "Both" }, Anim = { Spin = 60, Bob = 0.12 } }),
		P(RA, B, V(0.5, 0.85, 0.08), DARK, SP, 0, -1.15, -0.5, { Text = { Text = "♥ 1.2M", Color = C(255, 80, 150), Font = "Black" } }),
		P(T, B, V(1.3, 0.6, 0.05), C(240, 240, 245), SP, 0, 0.2, -0.52, { Text = { Text = "#HUSTLE", Font = "Black", Color = MAG } }),
	}, shades(WHT, CYAN, NE)),
})
S({ Id = "MarketingGuru_Epic", Character = "MarketingGuru", Rarity = "Epic", Name = "Hype Coach Live",
	Desc = "Let's GOOOO! (to the 3pm meeting about the 4pm meeting)",
	Outfit = { Shirt = MAG, Pants = C(30, 30, 45) },
	Parts = join({
		P(H, B, V(1.42, 0.12, 0.25), DARK, SP, 0, 0.68, 0),
		P(H, CY, V(0.2, 0.4, 0.4), DARK, SP, 0.66, 0.05, 0),
		P(T, B, V(0.15, 2.05, 0.06), CYAN, NE, -0.35, 0, -0.53),
		P(T, B, V(0.15, 2.05, 0.06), CYAN, NE, 0.35, 0, -0.53),
		P(H, B, V(2.4, 0.5, 0.06), C(20, 10, 30), GL, 0, 1.6, 0, { Transparency = 0.3, Text = { Text = "GRIND • HUSTLE • SYNERGY • DISRUPT • ",
			Font = "Black", Color = CYAN, Scroll = 0.22, Width = 5, Face = "Both" }, Anim = { Bob = 0.12, Seed = 24 } }),
		P(H, B, V(2.5, 0.06, 0.08), MAG, NE, 0, 1.87, 0, { Anim = { Bob = 0.12, Seed = 24 } }),
		P(LA, B, V(1.08, 0.25, 1.08), GOLD, ME, 0, -0.6, 0),
	}, headsetMic(DARK, CYAN), pair(LL, RL, B, V(1.12, 0.42, 1.3), WHT, SP, 0, -0.81, -0.12),
	pair(LL, RL, B, V(1.14, 0.12, 1.32), CYAN, NE, 0, -0.98, -0.12, { Anim = { Pulse = 0.5, PulseSpeed = 6 }, Trail = { Color = MAG, Width = 0.3 } })),
})
local boards = {}
for i, txt in ipairs({ "BUY NOW", "50% OFF", "LIKE & SHARE" }) do
	local a = (i - 1) * 120
	boards[#boards + 1] = ring(T, B, V(1.6, 0.9, 0.08), C(15, 10, 25), SP, 2.5, 0.8, a, { Text = { Text = txt, Font = "Black", Color = CYAN, Face = "Both" },
		Anim = { Circle = 0.6, Bob = 0.2, Seed = 25 } })
	boards[#boards + 1] = ring(T, B, V(1.75, 1.05, 0.05), MAG, NE, 2.5, 0.8, a, { Anim = { Circle = 0.6, Bob = 0.2, Seed = 25 } })
end
S({ Id = "MarketingGuru_Legendary", Character = "MarketingGuru", Rarity = "Legendary", Name = "Ad Overlord",
	Desc = "This skin is sponsored by... this skin. Skip ad in 5... 4...",
	Outfit = { Shirt = C(25, 20, 40), Pants = C(25, 20, 40) },
	Parts = join(boards, {
		P(H, B, V(1.35, 0.45, 0.5), C(30, 30, 40), SP, 0, 0.15, -0.45),
		P(H, B, V(1.2, 0.3, 0.06), CYAN, NE, 0, 0.15, -0.72, { Text = { Text = "BUY NOW • ", Font = "Code", Scroll = 0.4, Width = 3 } }),
		P(H, B, V(1.3, 0.3, 1.3), MAG, SP, 0, 0.62, 0.05),
		P(H, B, V(0.5, 0.22, 0.5), DARK, SP, 1.9, 0.9, 0, { Anim = { Circle = -1.2, Bob = 0.12, Seed = 26 } }),
		P(H, CY, V(0.12, 0.22, 0.22), RED, NE, 1.62, 0.88, 0, { Anim = { Circle = -1.2, Bob = 0.12, Seed = 26 } }),
		P(T, B, V(0.15, 2.05, 0.06), CYAN, NE, -0.4, 0, -0.53),
		P(T, B, V(0.15, 2.05, 0.06), CYAN, NE, 0.4, 0, -0.53),
		P(T, B, V(0.6, 0.6, 0.05), WHT, SP, 0, 0.3, -0.53, { Text = { Text = "SCAN\nME", Font = "Code", Color = DARK } }),
		P(H, B, V(2.4, 0.8, 0.12), C(255, 40, 90), NE, 0, 2.0, 0, { Transform = true, Text = { Text = "MEGA SALE!", Font = "Bangers", Face = "Both", Blink = 3 },
			Anim = { Bob = 0.15, Seed = 27 } }),
	}, sneakers(C(30, 30, 40), MAG)),
	FX = { PowerAura = MAG, HandTrails = CYAN },
	Highlight = { Outline = CYAN },
	HitColor = MAG,
})

-- ===================== LAWYER =====================
local WIG, BURG = C(240, 240, 235), C(125, 20, 45)
S({ Id = "Lawyer_Rare", Character = "Lawyer", Rarity = "Rare", Name = "Barrister Supreme",
	Desc = "Powdered wig. Unpowdered arguments. Bills by the second.",
	Outfit = { Shirt = C(25, 25, 30), Pants = C(40, 35, 40) },
	Parts = {
		P(H, B, V(1.4, 0.45, 1.4), WIG, SP, 0, 0.6, 0.05),
		P(H, CY, V(1.3, 0.35, 0.35), WIG, SP, -0.66, 0.25, 0.1, 0, 90, 0),
		P(H, CY, V(1.3, 0.35, 0.35), WIG, SP, 0.66, 0.25, 0.1, 0, 90, 0),
		P(H, CY, V(1.2, 0.35, 0.35), WIG, SP, -0.66, -0.1, 0.15, 0, 90, 0),
		P(H, CY, V(1.2, 0.35, 0.35), WIG, SP, 0.66, -0.1, 0.15, 0, 90, 0),
		P(T, B, V(0.35, 0.5, 0.06), WHT, SP, 0, 0.7, -0.53),
		P(LA, B, V(0.35, 0.9, 1.2), BURG, SP, 0, -1.4, -0.1),
	},
})
S({ Id = "Lawyer_Epic", Character = "Lawyer", Rarity = "Epic", Name = "TV Judge",
	Desc = "Order in the break room! Case dismissed. You're all guilty.",
	Outfit = { Shirt = C(20, 20, 25), Pants = C(20, 20, 25) },
	Parts = join({
		P(T, B, V(1.2, 0.4, 0.08), WHT, FA, 0, 0.82, -0.53),
		P(T, CY, V(0.22, 1.2, 1.2), WHT, FA, 0, 1.05, 0, 0, 0, 90),
		P(RA, CY, V(1.4, 0.15, 0.15), C(120, 70, 40), WO, 0, -1.05, -0.6, 0, 90, 0),
		P(RA, CY, V(0.9, 0.5, 0.5), C(120, 70, 40), WO, 0, -1.05, -1.3, 0, 0, 90, {
			Particles = { Kind = "Sparkle", Color = GOLD, Rate = 6, Speed = 1.5, Size = 0.35, Life = 0.8 } }),
		P(RA, CY, V(0.15, 0.55, 0.55), GOLD, ME, 0, -1.05, -1.3, 0, 0, 90),
		P(H, B, V(2.0, 0.6, 0.1), GOLD, NE, 0, 1.65, 0, { Text = { Text = "ORDER!", Font = "Serif", Color = C(60, 10, 20), Face = "Both", Blink = 1.5 },
			Anim = { Float = true } }),
		P(T, B, V(2.1, 1.2, 1.1), C(20, 20, 25), FA, 0, -1.4, 0),
		P(T, B, V(0.15, 2.0, 0.06), GOLD, SP, -0.3, 0, -0.54),
		P(T, B, V(0.15, 2.0, 0.06), GOLD, SP, 0.3, 0, -0.54),
	}, pair(LA, RA, B, V(1.3, 0.7, 1.3), C(20, 20, 25), FA, 0, -0.6, 0)),
})
local papers = {}
for i, a in ipairs({ 0, 120, 240 }) do
	papers[#papers + 1] = ring(T, B, V(0.6, 0.8, 0.03), WHT, SP, 2.2, 0.2 + i * 0.35, a, { Anim = { Circle = 1.3, Bob = 0.2, Seed = 28 } })
end
S({ Id = "Lawyer_Legendary", Character = "Lawyer", Rarity = "Legendary", Name = "Supreme Closer",
	Desc = "Case closed. Building closed. Everything closed. OBJECTION sustained.",
	Outfit = { Shirt = BURG, Pants = C(60, 15, 30) },
	Parts = join(papers, {
		P(H, B, V(1.3, 0.35, 1.3), C(30, 25, 25), SP, 0, 0.6, 0.05, { Reflect = 0.3 }),
		P(H, B, V(1.6, 0.6, 1.6), GOLD, FO, 0, 0.75, 0.05, { Transform = true }),
		P(T, B, V(0.4, 1.1, 0.06), GOLD, FO, -0.42, 0.4, -0.53, 0, 0, 12),
		P(T, B, V(0.4, 1.1, 0.06), GOLD, FO, 0.42, 0.4, -0.53, 0, 0, -12),
		P(T, B, V(0.3, 1.1, 0.06), GOLD, NE, 0, 0.3, -0.55),
		-- balance de la justice flottante
		P(T, CY, V(1.4, 0.12, 0.12), GOLD, ME, -1.9, 1.45, 0.3, 0, 0, 90, { Anim = { Bob = 0.15, Seed = 29 } }),
		P(T, B, V(1.5, 0.1, 0.1), GOLD, ME, -1.9, 2.15, 0.3, { Anim = { Bob = 0.15, Seed = 29 } }),
		P(T, CY, V(0.08, 0.6, 0.6), GOLD, NE, -2.5, 1.7, 0.3, 0, 0, 90, { Anim = { Bob = 0.15, Seed = 29 } }),
		P(T, CY, V(0.08, 0.6, 0.6), GOLD, NE, -1.3, 1.7, 0.3, 0, 0, 90, { Anim = { Bob = 0.15, Seed = 29 } }),
		P(T, BA, V(0.25, 0.25, 0.25), C(255, 240, 150), NE, -1.9, 2.28, 0.3, { Anim = { Bob = 0.15, Seed = 29 } }),
		-- OBJECTION!
		P(H, B, V(2.4, 0.7, 0.12), WHT, SP, 0, 1.75, 0, { Text = { Text = "OBJECTION!", Font = "Bangers", Color = C(200, 20, 40), Face = "Both" },
			Anim = { Float = true, React = true, Seed = 30 } }),
		P(H, B, V(2.6, 0.9, 0.08), GOLD, NE, 0, 1.75, 0, 0, 0, 6, { Anim = { Float = true, React = true, Seed = 30 } }),
		P(LA, B, V(0.35, 0.95, 1.25), GOLD, ME, 0, -1.4, -0.1, { Reflect = 0.3, Light = C(255, 210, 80) }),
	}, pair(LL, RL, B, V(1.1, 0.4, 1.25), C(25, 20, 22), SP, 0, -0.82, -0.1, { Reflect = 0.4 })),
	FX = { PowerAura = C(255, 200, 60) },
	Highlight = { Outline = GOLD },
	HitColor = GOLD,
})

-- ===================== MASCOT =====================
local BUN, SAUS, MUST, MRED = C(230, 170, 90), C(205, 75, 55), C(255, 220, 40), C(230, 45, 45)
S({ Id = "Mascot_Rare", Character = "Mascot", Rarity = "Rare", Name = "Hot Dog Hero",
	Desc = "Relish the moment. Ketchup is extra.",
	Outfit = { Shirt = C(255, 220, 40), Pants = C(190, 35, 35) },
	Parts = join({
		P(T, B, V(2.3, 4.0, 0.6), BUN, SP, 0, 0.9, 1.1),
		P(T, CY, V(4.2, 1.1, 1.1), SAUS, SP, 0, 1.0, 0.55, 0, 0, 90),
		P(T, B, V(0.15, 0.7, 0.12), MUST, SP, 0, 2.35, 0.0, 0, 0, 30),
		P(T, B, V(0.15, 0.7, 0.12), MUST, SP, 0, 2.85, 0.0, 0, 0, -30),
	}, sneakers(WHT)),
})
S({ Id = "Mascot_Epic", Character = "Mascot", Rarity = "Epic", Name = "Super Mascot",
	Desc = "Faster than a speeding T-shirt cannon. Weakness: stairs.",
	Outfit = { Shirt = C(40, 90, 220), Pants = MRED },
	Parts = join({
		P(T, B, V(2.0, 3.0, 0.1), MRED, FA, 0, -0.5, 0.62, 8, 0, 0, { Anim = { Swing = 6, SwingAxis = "X", SwingSpeed = 2 } }),
		P(T, B, V(2.2, 0.3, 0.4), MRED, FA, 0, 0.95, 0.35),
		P(H, B, V(1.3, 0.32, 0.1), BLK, SP, 0, 0.15, -0.62),
		P(H, B, V(0.3, 0.18, 0.05), WHT, NE, -0.25, 0.15, -0.68),
		P(H, B, V(0.3, 0.18, 0.05), WHT, NE, 0.25, 0.15, -0.68),
		P(T, B, V(1.0, 0.9, 0.08), MUST, SP, 0, 0.3, -0.53, { Text = { Text = "M", Font = "Bangers", Color = MRED } }),
		P(T, B, V(2.05, 0.25, 1.05), MUST, SP, 0, -0.85, 0),
		P(H, B, V(1.3, 0.3, 1.3), C(30, 25, 30), SP, 0, 0.6, 0.05),
		P(H, BA, V(0.25, 0.35, 0.25), C(30, 25, 30), SP, 0, 0.55, -0.62),
		P(H, B, V(1.6, 0.7, 0.1), MUST, NE, 0, 1.7, 0, { Text = { Text = "POW!", Font = "Bangers", Color = MRED, Face = "Both" }, Anim = { Float = true, React = true } }),
	}, pair(LL, RL, B, V(1.12, 1.0, 1.15), MRED, SP, 0, -0.5, 0),
	pair(LA, RA, B, V(1.1, 0.6, 1.1), MRED, SP, 0, -0.75, 0)),
	FX = { HandTrails = MUST },
})
S({ Id = "Mascot_Legendary", Character = "Mascot", Rarity = "Legendary", Name = "Halftime Legend",
	Desc = "The crowd goes WILD. The office goes WILDER. Jumbotron included.",
	Outfit = { Shirt = MRED, Pants = MUST },
	Parts = {
		P(H, BA, V(2.2, 2.0, 2.0), MRED, SP, 0, 0.55, 0),
		P(H, BA, V(0.6, 0.7, 0.3), WHT, SP, -0.38, 0.75, -0.88),
		P(H, BA, V(0.6, 0.7, 0.3), WHT, SP, 0.38, 0.75, -0.88),
		P(H, BA, V(0.28, 0.32, 0.2), BLK, SP, -0.38, 0.72, -1.0),
		P(H, BA, V(0.28, 0.32, 0.2), BLK, SP, 0.38, 0.72, -1.0),
		P(H, B, V(0.9, 0.2, 0.2), BLK, SP, 0, 0.15, -0.95),
		P(H, BA, V(0.7, 0.7, 0.3), MRED, SP, -0.85, 1.4, 0),
		P(H, BA, V(0.7, 0.7, 0.3), MRED, SP, 0.85, 1.4, 0),
		P(RA, B, V(1.0, 1.1, 0.8), MUST, SP, 0, -1.35, -0.6, { Text = { Text = "#1", Font = "Bangers", Color = MRED } }),
		P(RA, B, V(0.35, 1.2, 0.35), MUST, SP, 0, -0.3, -0.75),
		P(T, B, V(2.4, 1.4, 0.15), C(20, 20, 25), SP, -2.1, 1.7, 0.3, 0, 25, 0, { Text = { Text = "MAKE SOME NOISE!!!  ", Font = "Bangers", Color = MUST,
			Scroll = 0.3, Width = 3.5, Face = "Both" }, Anim = { Bob = 0.15, Seed = 31 } }),
		P(T, B, V(2.55, 1.55, 0.1), MRED, NE, -2.1, 1.7, 0.3, 0, 25, 0, { Anim = { Bob = 0.15, Seed = 31 } }),
		P(T, B, V(0.2, 0.2, 0.2), MUST, SP, 0, 2.9, 0, { Transparency = 1,
			Particles = { Kind = "Spark", Color = MUST, Rate = 10, Speed = 7, Size = 0.4, Life = 0.7, Spread = 180, Accel = -8, React = true } }),
		P(T, B, V(0.2, 0.2, 0.2), CYAN, SP, 0, 2.9, 0, { Transparency = 1,
			Particles = { Kind = "Spark", Color = CYAN, Rate = 8, Speed = 7, Size = 0.4, Life = 0.7, Spread = 180, Accel = -8, React = true } }),
		P(T, B, V(1.2, 1.2, 0.05), WHT, SP, 0, 0.1, 0.53, { Text = { Text = "00", Font = "Bangers", Color = MRED, Face = "Back" } }),
		P(T, BA, V(0.7, 0.7, 0.9), MRED, SP, 0, -0.8, 0.85, { Anim = { Swing = 20, SwingAxis = "Y", SwingSpeed = 4 } }),
		P(LL, B, V(1.3, 0.6, 1.8), MUST, SP, 0, -0.75, -0.35),
		P(RL, B, V(1.3, 0.6, 1.8), MUST, SP, 0, -0.75, -0.35),
		P(LA, BA, V(1.3, 1.1, 1.3), WHT, SP, 0, -1.05, 0),
		P(T, BA, V(1.5, 1.6, 0.3), MUST, SP, 0, -0.1, -0.45),
		P(T, CY, V(1.6, 0.45, 0.45), C(60, 60, 70), ME, 1.4, 1.3, -0.1, 0, 90, 0, { Transform = true,
			Particles = { Kind = "Spark", Color = WHT, Rate = 10, Dir = "Right", Speed = 9, Size = 0.5, Life = 0.6, Spread = 15, TransformOnly = true } }),
	},
	FX = { PowerAura = MUST, Orbit = { Color = MUST, Count = 4, Shape = "Block", Size = 0.3, Speed = 3 } },
	Highlight = { Outline = MUST },
	HitColor = MUST,
})

-- @@CHARS@@

-- Packs v3 (modules enfants SkinList.Pack1..Pack4) : chaque entrée REMPLACE celle de même Id
do
	local index = {}
	for i, d in ipairs(L) do
		index[d.Id] = i
	end
	local packs = {}
	for _, child in ipairs(script:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name:match("^Pack") then
			table.insert(packs, child)
		end
	end
	table.sort(packs, function(a, b) return a.Name < b.Name end)
	for _, child in ipairs(packs) do
		local ok, list = pcall(require, child)
		if ok and type(list) == "table" then
			for _, d in ipairs(list) do
				if type(d) == "table" and d.Id then
					if index[d.Id] then
						L[index[d.Id]] = d
					else
						table.insert(L, d)
						index[d.Id] = #L
					end
				end
			end
		else
			warn("[SkinList] pack invalide : " .. child.Name .. " " .. tostring(list))
		end
	end
end

return L
