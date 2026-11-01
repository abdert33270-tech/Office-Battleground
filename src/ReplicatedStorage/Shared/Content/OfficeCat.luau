--[[
	The Office Cat — personnage PREMIUM (format : voir Modules/ContentLoader).
	Le chat du patron dans un costume de chat intégral (oreilles, queue, pattes, moustaches).
	Passif « Nine Lives » : chaque 12e coup subi est esquivé (jamais un coup imparable) (0 dégât, pas de recul, il retombe sur ses pattes).
	Attaques : Pounce (bond ciblé qui PLAQUE au sol), Hairball (boule de poils lobée + flaque gluante qui ralentit),
	           Claw Fury (6 coups de griffes en X, le dernier repousse).
	Transformation Midnight Zoomies : Laser Chase (ruée en zigzag derrière le point laser), Off The Desk (il fait tomber
	           les objets d'un bureau flottant : tasse, agrafeuse, plante, puis l'écran qui PLAQUE au sol),
	           Box Ambush (contre : caché dans un carton, il bondit sur celui qui le frappe).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT
local WEDGE = Enum.PartType.Wedge

local GINGER = Color3.fromRGB(255, 150, 50) -- couleur du perso (chat roux)
local STRIPE = Color3.fromRGB(205, 95, 25)
local CREAM = Color3.fromRGB(255, 238, 205)
local PINK = Color3.fromRGB(255, 140, 175)
local DARK = Color3.fromRGB(40, 30, 30)
local WHITE = Color3.fromRGB(250, 250, 250)
local GREEN = Color3.fromRGB(120, 255, 90)
local LASER = Color3.fromRGB(255, 35, 45)
local GOLD = Color3.fromRGB(255, 205, 50)
local YARN = Color3.fromRGB(235, 70, 120)
local YARN2 = Color3.fromRGB(190, 40, 90)
local HAIR = Color3.fromRGB(150, 160, 120)
local GOO = Color3.fromRGB(170, 190, 110)
local CARD = Color3.fromRGB(205, 155, 95)
local CARD2 = Color3.fromRGB(170, 120, 65)
local FUR = { GINGER, STRIPE, CREAM }

local SND = {
	Meow = "rbxassetid://134699420140804",
	Meow2 = "rbxassetid://136138461897866",
	Hiss = "rbxassetid://71522230632243",
}

local LIVES = 12 -- docs/Equilibrage.md (ex-9)

local M = { Id = "OfficeCat", Order = 19 }

M.Character = {
	DisplayName = "The Office Cat",
	Role = "Agile prankster",
	Color = GINGER,
	Shirt = GINGER, Pants = STRIPE, Tie = CREAM,
	Passive = { Name = "Nine Lives", Desc = "Every 12th hit he takes simply misses (never an unblockable one): no damage, no knockback. He always lands on his feet." },
	Attacks = { "CatPounce", "Hairball", "ClawFury" },
	Transformation = { Name = "Midnight Zoomies", Desc = "Glowing eyes, puffed-up fur, a tiny boss crown and a laser dot that never stops moving.", Duration = 20, SpeedMultiplier = 1.2 },
	TransAttacks = { "LaserChase", "OffTheDesk", "BoxAmbush" },
}

M.Attacks = {
	CatPounce = { Name = "Pounce", Kind = "CatPounce", Desc = "Wiggle your butt, then pounce on the first coworker ahead and PIN them to the floor.", Cooldown = 8, Anim = "CatPounce", Sound = "Whoosh",
		Windup = 0.42, Flight = 0.4, JumpUp = 40, Range = 22, Radius = 5.5, Damage = 11, Knockback = 0, Stun = 1.2, Category = "Heavy", GuardBreak = true, Power = 1.0,
		Words = { "POUNCE!", "GOTCHA!" }, Effects = { Pin = true } },
	Hairball = { Name = "Hairball", Kind = "CatHairball", Desc = "Hack up a gross hairball: it lobs, splats and leaves a sticky puddle that slows.", Cooldown = 7, Anim = "CatHairball", Sound = "Splat",
		Windup = 0.36, Speed = 72, Range = 60, Gravity = 0.55, Up = 15, GooRadius = 6, GooTime = 3.5, GooSlow = 0.55,
		Damage = 7, Knockback = 8, KnockUp = 4, Stun = 0.6, Category = "Projectile", Power = 0.5, Words = { "HAIRBALL!", "HACK!", "EWW!" }, Effects = { Slow = { 0.6, 2 } } },
	ClawFury = { Name = "Claw Fury", Kind = "Melee", Desc = "A frenzy of 5 crossing claw swipes, then a double swipe that sends them flying.", Prop = "CatClaws", Cooldown = 6, Anim = "CatClawFury", Sound = "Whoosh",
		Windup = 0.1, Hits = 6, Interval = 0.09, HitboxOffset = 3, HitboxSize = Vector3.new(6, 6, 6.5),
		Damage = 1.6, Knockback = 3, Stun = 0.45, Category = "Light", Power = 0.3, Words = { "SCRITCH!", "MREOW!", "SWIPE!" },
		Final = { Damage = 5, Knockback = 40, KnockUp = 12, Stun = 0.8, Category = "Heavy", Power = 0.9, Words = { "CLAW FURY!" } } },
	LaserChase = { Name = "Laser Chase", Kind = "CatLaser", Desc = "A laser dot appears... CHASE IT! Zigzag through everyone in 3 dashes.", Cooldown = 9, Anim = "CatLaserChase", Sound = "Dash",
		Windup = 0.12, Speed = 88, LegTime = 0.17, Zig = 32, MaxHitsPerTarget = 2, HitboxSize = Vector3.new(6, 6, 6),
		Damage = 4, Knockback = 14, KnockUp = 6, Stun = 0.5, Category = "Light", Power = 0.45, Words = { "ZOOM!", "MINE!", "RED DOT!" },
		Final = { Damage = 5, Knockback = 36, KnockUp = 12, Stun = 0.8, Category = "Heavy", Power = 0.8, Words = { "GOT IT!" } } },
	OffTheDesk = { Name = "Off The Desk", Kind = "CatDesk", Desc = "Summon a floating desk and knock everything off it, one item at a time. The monitor falls last and PINS.", Cooldown = 13, Anim = "CatDesk", Sound = "Pickup",
		Windup = 0.32, Offset = 13, Radius = 8, Gap = 0.18, Fall = 0.36, SmallRadius = 4, SmallDamage = 3, MaxSmallHits = 2, BigRadius = 6.5,
		Damage = 9, Knockback = 0, Stun = 1.2, Category = "Heavy", GuardBreak = true, Power = 1.1, Words = { "CRASH!", "OOPS!" }, Effects = { Pin = true } },
	BoxAmbush = { Name = "Box Ambush", Kind = "CatBox", Desc = "If I fits, I sits: hide in a box for 1.2s. If anyone hits you, you burst out and pounce on them.", Cooldown = 10, Anim = "CatBox", Sound = "Pickup",
		Windup = 0, Window = 1.2, Damage = 11, Knockback = 8, Launch = Vector3.new(6, 50, 0), Stun = 1.0, Category = "Heavy", Power = 1.0,
		Unblockable = true, Words = { "SURPRISE!", "MRRAOW!" } },
}

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local function pounceAnim()
	local f = {
		{ t = 0 },
		{ t = 0.08, RS = { p = 1.15 }, LS = { p = 1.15 }, RJ = { ln = 0.95 }, RH = { p = 1.0 }, LH = { p = 1.0 } },
	}
	for i = 1, 4 do -- le célèbre tortillement de fesses avant le bond
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = 0.08 + i * 0.075, RS = { p = 1.2 }, LS = { p = 1.2 }, RJ = { ln = 1.0, sd = 0.2 * s, tw = 0.16 * s }, RH = { p = 1.05 + 0.15 * s }, LH = { p = 1.05 - 0.15 * s } })
	end
	table.insert(f, { t = 0.44, RS = { p = 3.0, r = -0.25 }, LS = { p = 3.0, r = 0.25 }, RJ = { ln = 0.25 }, RH = { p = -0.8 }, LH = { p = -0.8 } })
	table.insert(f, { t = 0.66, RS = { p = 2.5, r = -0.5 }, LS = { p = 2.5, r = 0.5 }, RJ = { ln = 0.55 }, RH = { p = -0.6 }, LH = { p = -0.5 } })
	table.insert(f, { t = 0.82, RS = { p = 1.0, y = 0.2 }, LS = { p = 1.0, y = -0.2 }, RJ = { ln = 1.15 }, RH = { p = 1.25 }, LH = { p = 0.4 } })
	table.insert(f, { t = 1.08, RS = { p = 1.05, y = 0.2 }, LS = { p = 1.05, y = -0.2 }, RJ = { ln = 1.05 }, RH = { p = 1.15 }, LH = { p = 0.4 } })
	table.insert(f, { t = 1.3 })
	return f
end

local function hairballAnim()
	local f = { { t = 0 }, { t = 0.06, RS = { p = 0.7, y = 0.5 }, LS = { p = 0.7, y = -0.5 }, RJ = { ln = 0.5 }, RH = { p = 0.3 }, LH = { p = 0.3 } } }
	for i = 1, 4 do -- haut-le-cœur
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = 0.06 + i * 0.065, RS = { p = 0.7, y = 0.5 }, LS = { p = 0.7, y = -0.5 }, RJ = { ln = 0.55 + 0.25 * s }, RH = { p = 0.35 + 0.1 * s }, LH = { p = 0.35 - 0.1 * s } })
	end
	table.insert(f, { t = 0.38, RS = { p = -0.7, r = -0.3 }, LS = { p = -0.7, r = 0.3 }, RJ = { ln = 0.95 }, RH = { p = -0.45 }, LH = { p = 0.7 } })
	table.insert(f, { t = 0.6, RS = { p = -0.6, r = -0.3 }, LS = { p = -0.6, r = 0.3 }, RJ = { ln = 0.85 }, RH = { p = -0.4 }, LH = { p = 0.6 } })
	table.insert(f, { t = 0.8 })
	return f
end

local function clawAnim()
	local f = { { t = 0 }, { t = 0.08, RS = { p = 2.9, y = 0.4 }, LS = { p = 2.9, y = -0.4 }, RJ = { ln = -0.2, tw = 0 }, RH = { p = 0.2 }, LH = { p = -0.2 } } }
	local t = 0.08
	for i = 1, 5 do -- griffes en X qui alternent, buste qui suit
		t += 0.09
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = t, RS = { p = s > 0 and 0.9 or 2.9, y = s > 0 and -0.9 or 0.3 }, LS = { p = s > 0 and 2.9 or 0.9, y = s > 0 and -0.3 or 0.9 }, RJ = { ln = 0.35, tw = 0.45 * s }, RH = { p = 0.35 * s }, LH = { p = -0.35 * s } })
	end
	table.insert(f, { t = t + 0.06, RS = { p = 3.1, y = 0.6 }, LS = { p = 3.1, y = -0.6 }, RJ = { ln = -0.35 }, RH = { p = -0.3 }, LH = { p = 0.3 } })
	table.insert(f, { t = t + 0.15, RS = { p = 0.6, y = -0.9 }, LS = { p = 0.6, y = 0.9 }, RJ = { ln = 0.75 }, RH = { p = -0.6 }, LH = { p = 0.95 } })
	table.insert(f, { t = t + 0.38, RS = { p = 0.65, y = -0.85 }, LS = { p = 0.65, y = 0.85 }, RJ = { ln = 0.65 }, RH = { p = -0.5 }, LH = { p = 0.85 } })
	table.insert(f, { t = t + 0.55 })
	return f
end

local function gallopAnim()
	local f = { { t = 0 }, { t = 0.08, RS = { p = 1.0 }, LS = { p = 1.0 }, RJ = { ln = 1.0 }, RH = { p = 0.9 }, LH = { p = 0.9 } } }
	local t = 0.08
	for i = 1, 9 do -- galop à quatre pattes
		t += 0.065
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = t, RS = { p = 1.0 + 0.9 * s }, LS = { p = 1.0 + 0.9 * s }, RJ = { ln = 1.05 + 0.1 * s, sd = 0.08 * s }, RH = { p = 0.6 - 0.9 * s }, LH = { p = 0.6 - 0.9 * s } })
	end
	table.insert(f, { t = t + 0.12, RS = { p = 2.6, r = -0.4 }, LS = { p = 2.6, r = 0.4 }, RJ = { ln = 0.4 }, RH = { p = -0.5 }, LH = { p = 0.8 } })
	table.insert(f, { t = t + 0.32 })
	return f
end

local function deskAnim()
	local f = { { t = 0 }, { t = 0.12, RS = { p = 2.7, y = 0.2 }, LS = { p = 0.5, r = 0.4 }, RJ = { ln = -0.3 }, RH = { p = -0.15 }, LH = { p = 0.2 } } }
	for i = 0, 2 do -- petites tapes de patte, un objet à la fois (en regardant droit dans les yeux)
		local t = 0.3 + i * 0.18
		table.insert(f, { t = t - 0.06, RS = { p = 2.9, y = 0.45, r = -0.2 }, LS = { p = 0.5, r = 0.4 }, RJ = { ln = -0.3, tw = -0.15 } })
		table.insert(f, { t = t, RS = { p = 2.6, y = -0.5, r = 0.3 }, LS = { p = 0.5, r = 0.4 }, RJ = { ln = -0.25, tw = 0.2 } })
	end
	table.insert(f, { t = 0.78, RS = { p = 3.0, y = 0.6 }, LS = { p = 3.0, y = -0.6 }, RJ = { ln = -0.45, tw = -0.3 }, RH = { p = -0.3 }, LH = { p = 0.3 } })
	table.insert(f, { t = 0.88, RS = { p = 2.2, y = -0.8 }, LS = { p = 2.2, y = 0.2 }, RJ = { ln = 0.3, tw = 0.5 }, RH = { p = 0.4 }, LH = { p = -0.3 } })
	table.insert(f, { t = 1.15, RS = { p = 0.2, r = -0.3 }, LS = { p = 0.2, r = 0.3 }, RJ = { ln = -0.12, sd = 0.12 }, RH = { p = 0.1 }, LH = { p = -0.1 } })
	table.insert(f, { t = 1.45, RS = { p = 0.25, r = -0.3 }, LS = { p = 0.25, r = 0.3 }, RJ = { ln = -0.12, sd = 0.12 } })
	table.insert(f, { t = 1.6 })
	return f
end

local function boxAnim()
	local pose = { RS = { p = 1.7, y = 0.6 }, LS = { p = 1.7, y = -0.6 }, RJ = { ln = 0.95 }, RH = { p = 1.55 }, LH = { p = 1.55 } }
	local f = { { t = 0 } }
	for i = 1, 6 do -- recroquevillé dans le carton, petit frétillement
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = i * 0.2 - 0.12, RS = pose.RS, LS = pose.LS, RJ = { ln = 0.95, sd = 0.04 * s }, RH = pose.RH, LH = pose.LH })
	end
	table.insert(f, { t = 1.3 })
	return f
end

M.Anims = {
	CatPounce = pounceAnim(), -- accroupi, tortille des fesses, bond bras tendus, réception à quatre pattes
	CatHairball = hairballAnim(), -- haut-le-cœur puis crache la boule de poils
	CatClawFury = clawAnim(), -- griffes en X qui alternent puis double coup de griffes
	CatLaserChase = gallopAnim(), -- galop à quatre pattes, bond final sur le point rouge
	CatDesk = deskAnim(), -- tapote les objets un par un, pousse l'écran à deux pattes, pose fière
	CatBox = boxAnim(), -- recroquevillé dans le carton
	CatBoxStrike = { -- jaillit du carton griffes en avant
		{ t = 0 },
		{ t = 0.06, RS = { p = 3.1, r = -0.3 }, LS = { p = 3.1, r = 0.3 }, RJ = { ln = -0.4 }, RH = { p = -0.5 }, LH = { p = 0.6 } },
		{ t = 0.16, RS = { p = 1.6, y = -0.9 }, LS = { p = 1.6, y = 0.9 }, RJ = { ln = 0.6, tw = 0.3 }, RH = { p = -0.6 }, LH = { p = 0.9 } },
		{ t = 0.42, RS = { p = 1.5, y = -0.8 }, LS = { p = 1.5, y = 0.8 }, RJ = { ln = 0.5, tw = 0.25 } },
		{ t = 0.6 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main (repère bras droit : main en (0,-1,0), -Y = prolongement du bras)
------------------------------------------------------------------------
M.Props = {
	CatClaws = { -- griffes sorties (patte crème, 3 griffes blanches)
		{ Vector3.new(1.15, 0.6, 1.15), CFrame.new(0, -0.85, 0), CREAM },
		{ Vector3.new(0.12, 0.7, 0.12), CFrame.new(-0.32, -1.45, -0.2) * CFrame.Angles(0.35, 0, 0), WHITE },
		{ Vector3.new(0.12, 0.8, 0.12), CFrame.new(0, -1.5, -0.25) * CFrame.Angles(0.35, 0, 0), WHITE },
		{ Vector3.new(0.12, 0.7, 0.12), CFrame.new(0.32, -1.45, -0.2) * CFrame.Angles(0.35, 0, 0), WHITE },
		{ Vector3.one * 0.3, CFrame.new(0, -1.1, -0.45), PINK, BALL },
	},
}

------------------------------------------------------------------------
-- Costume de chat permanent (serveur)
------------------------------------------------------------------------
-- oreille triangulaire = deux demi-coins dos à dos (pointe au centre), intérieur rose
local function ear(f, head, prop, s, col, inner, scale)
	scale = scale or 1
	local base = CFrame.new(0.42 * s, 0.78 + 0.05 * (scale - 1), 0.05) * CFrame.Angles(0, 0, -0.28 * s)
	for _, h in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.16, 0.62, 0.27) * scale, base * CFrame.new(0.135 * h * scale, 0, 0) * CFrame.Angles(0, -h * math.pi / 2, 0), col, WEDGE)
		if inner then
			prop(f, head, Vector3.new(0.06, 0.4, 0.16) * scale, base * CFrame.new(0.08 * h * scale, -0.08 * scale, -0.09) * CFrame.Angles(0, -h * math.pi / 2, 0), inner, WEDGE)
		end
	end
end

function M.Identity(f, head, torso, c, prop)
	-- oreilles, museau, nez, moustaches
	for _, s in ipairs({ -1, 1 }) do
		ear(f, head, prop, s, GINGER, PINK)
		for k, y in ipairs({ -0.06, -0.18 }) do
			prop(f, head, Vector3.new(0.6, 0.04, 0.04), CFrame.new(0.52 * s, y, -0.6) * CFrame.Angles(0, 0, (k == 1 and 0.18 or -0.12) * s), DARK)
		end
	end
	prop(f, head, Vector3.new(0.2, 0.13, 0.12), CFrame.new(0, -0.02, -0.63), PINK) -- nez
	prop(f, head, Vector3.new(0.5, 0.06, 0.06), CFrame.new(0, 0.55, -0.45), STRIPE) -- rayures du front
	prop(f, head, Vector3.new(0.06, 0.25, 0.06), CFrame.new(0, 0.42, -0.6), STRIPE)
	-- ventre crème, collier rouge et grelot doré, rayures dans le dos
	prop(f, torso, Vector3.new(1.15, 1.35, 0.08), CFrame.new(0, -0.25, -0.52), CREAM)
	prop(f, torso, Vector3.new(0.22, 1.32, 1.32), CFrame.new(0, 1.02, 0) * UP, Color3.fromRGB(220, 40, 50), CYL)
	prop(f, torso, Vector3.one * 0.38, CFrame.new(0, 0.82, -0.66), GOLD, BALL)
	prop(f, torso, Vector3.new(0.3, 0.04, 0.1), CFrame.new(0, 0.78, -0.84), DARK)
	for _, y in ipairs({ 0.55, 0.05, -0.45 }) do
		prop(f, torso, Vector3.new(1.5, 0.18, 0.06), CFrame.new(0, y, 0.52), STRIPE)
	end
	-- pattes avant : moufles crème + coussinets roses
	for _, n in ipairs({ "Left Arm", "Right Arm" }) do
		local a = c:FindFirstChild(n)
		if a then
			prop(f, a, Vector3.new(1.12, 0.58, 1.12), CFrame.new(0, -0.76, 0), CREAM)
			prop(f, a, Vector3.new(1.06, 0.14, 1.06), CFrame.new(0, 0.3, 0), STRIPE)
			prop(f, a, Vector3.one * 0.42, CFrame.new(0, -1.02, 0.08), PINK, BALL)
			for _, x in ipairs({ -0.3, 0, 0.3 }) do
				prop(f, a, Vector3.one * 0.22, CFrame.new(x, -1.04, -0.32), PINK, BALL)
			end
		end
	end
	-- pattes arrière
	for _, n in ipairs({ "Left Leg", "Right Leg" }) do
		local leg = c:FindFirstChild(n)
		if leg then
			prop(f, leg, Vector3.new(1.1, 0.45, 1.36), CFrame.new(0, -0.79, -0.16), CREAM)
			for _, x in ipairs({ -0.3, 0, 0.3 }) do
				prop(f, leg, Vector3.one * 0.2, CFrame.new(x, -0.86, -0.84), PINK, BALL)
			end
		end
	end
	-- queue en S (boules qui rapetissent, rayée, bout crème)
	local pts = { { -0.75, 0.62, 0.52 }, { -0.88, 0.95, 0.48 }, { -0.72, 1.28, 0.45 }, { -0.35, 1.5, 0.42 }, { 0.1, 1.58, 0.4 }, { 0.55, 1.5, 0.38 }, { 0.92, 1.36, 0.42 } }
	for i, p in ipairs(pts) do
		local col = (i == #pts) and CREAM or ((i % 2 == 0) and STRIPE or GINGER)
		local part = prop(f, torso, Vector3.one * p[3], CFrame.new(0, p[1], p[2]), col, BALL)
		part.Name = "CatTail" .. i
	end
end

-- arme fétiche : pelote de laine à la main gauche
M.Signature = { Hand = "Left", Build = function(f, a, prop)
	prop(f, a, Vector3.one * 1.0, CFrame.new(0, -1.5, -0.15), YARN, BALL)
	prop(f, a, Vector3.new(1.03, 0.1, 0.35), CFrame.new(0, -1.5, -0.15) * CFrame.Angles(0, 0, 0.6), YARN2)
	prop(f, a, Vector3.new(1.03, 0.1, 0.35), CFrame.new(0, -1.5, -0.15) * CFrame.Angles(0, 0.9, -0.5), YARN2)
	prop(f, a, Vector3.new(0.35, 1.03, 0.1), CFrame.new(0, -1.5, -0.15) * CFrame.Angles(0.5, 0, 0), YARN2)
	prop(f, a, Vector3.new(0.07, 1.1, 0.07), CFrame.new(0.3, -2.3, -0.3) * CFrame.Angles(0, 0, 0.3), YARN)
end }

-- Transformation Midnight Zoomies : yeux verts, poils hérissés, petite couronne du patron, grosses oreilles, queue touffue
function M.Transform(f, head, torso, c, prop)
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.26, 0.2, 0.05), CFrame.new(0.22 * s, 0.14, -0.62), GREEN)
		prop(f, head, Vector3.new(0.06, 0.18, 0.06), CFrame.new(0.22 * s, 0.14, -0.645), DARK)
		ear(f, head, prop, s, STRIPE, PINK, 1.25)
	end
	-- couronne du patron
	prop(f, head, Vector3.new(0.28, 0.7, 0.7), CFrame.new(0, 0.8, 0) * UP, GOLD, CYL)
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		prop(f, head, Vector3.new(0.12, 0.28, 0.12), CFrame.new(math.cos(a) * 0.3, 1.05, math.sin(a) * 0.3), GOLD)
	end
	prop(f, head, Vector3.one * 0.18, CFrame.new(0, 0.82, -0.36), LASER, BALL)
	-- poils hérissés sur le dos
	for i, y in ipairs({ 0.85, 0.4, -0.05, -0.5 }) do
		prop(f, torso, Vector3.one * 0.4, CFrame.new(0, y, 0.55) * CFrame.Angles(math.rad(45), 0, 0), (i % 2 == 0) and STRIPE or GINGER)
	end
	for _, s in ipairs({ -1, 1 }) do
		prop(f, torso, Vector3.one * 0.32, CFrame.new(0.9 * s, 1.0, 0.1) * CFrame.Angles(math.rad(45), 0, math.rad(45)), GINGER)
	end
	-- queue touffue
	prop(f, torso, Vector3.one * 0.85, CFrame.new(0, 1.0, 1.42), CREAM, BALL)
	prop(f, torso, Vector3.one * 0.65, CFrame.new(0, 1.58, 0.95), GINGER, BALL)
end

------------------------------------------------------------------------
-- Comportements serveur (Kinds)
------------------------------------------------------------------------
local function ready(api, c)
	return api.CharacterState.isAlive(c) and not api.CharacterState.isStunned(c)
end

local function kbAtt(root)
	local att = root:FindFirstChild("KBAtt")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "KBAtt"
		att.Parent = root
	end
	return att
end

local function velocity(root, v)
	local lv = Instance.new("LinearVelocity")
	lv.Name = "CatLeap"
	lv.Attachment0 = kbAtt(root)
	lv.MaxForce = 1e6
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = v
	lv.Parent = root
	return lv
end

local function decor(part, size, off, color, shape)
	local p = Kit.sPart({ Size = size, CFrame = part.CFrame * off, Color = color })
	if shape then
		p.Shape = shape
	end
	local w = Instance.new("WeldConstraint")
	w.Part0 = part
	w.Part1 = p
	w.Parent = p
	p.Anchored = false
	p.Massless = true
	p.Parent = part
end

local boxHits = {}

M.Kinds = {
	-- Pounce : tortillement, puis bond déterministe sur la 1re cible en ligne ; tout le monde sous la réception est PLAQUÉ
	CatPounce = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local target = Kit.firstInLine(attacker, root.Position, dir, cfg.Range, 7)
		local goal = target and Kit.root(target).Position or (root.Position + dir * cfg.Range * 0.7)
		local flatTo = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z)
		if flatTo.Magnitude > cfg.Range then
			flatTo = flatTo.Unit * cfg.Range
		elseif flatTo.Magnitude < 3 then
			flatTo = dir * 3
		end
		local landing = Kit.ground(Kit.safePoint(root.Position, root.Position + flatTo, 2))
		Kit.fx({ id = "Telegraph", p = landing, r = cfg.Radius, dur = cfg.Windup + cfg.Flight, a = attacker })
		Kit.fx({ id = "Cat_Wiggle", a = attacker, dur = cfg.Windup })
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local horiz = Vector3.new(landing.X - root.Position.X, 0, landing.Z - root.Position.Z)
		if horiz.Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + horiz)
		end
		Kit.fx({ id = "Cat_Leap", a = attacker, dur = cfg.Flight })
		local lv = velocity(root, horiz / cfg.Flight + Vector3.new(0, cfg.JumpUp, 0))
		task.wait(cfg.Flight / 2)
		lv.VectorVelocity = horiz / cfg.Flight + Vector3.new(0, -cfg.JumpUp, 0)
		task.wait(cfg.Flight / 2)
		lv:Destroy()
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		Kit.fx({ id = "Cat_PounceLand", p = landing, r = cfg.Radius, a = attacker, dir = horiz.Magnitude > 0.5 and horiz.Unit or dir })
		for _, v in ipairs(Kit.inCircle(attacker, landing + Vector3.new(0, 3, 0), cfg.Radius, 7)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - landing, dir))
		end
	end,

	-- Hairball : boule de poils lobée ; à l'impact (cible ou sol) elle laisse une flaque gluante qui ralentit
	CatHairball = function(attacker, cfg, aim, api)
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		Kit.fx({ id = "Cat_Hack", a = attacker })
		local landed = false
		local function goo(pos)
			if landed then
				return
			end
			landed = true
			local g = Kit.ground(pos + Vector3.new(0, 1, 0))
			Kit.fx({ id = "Cat_Goo", p = g, r = cfg.GooRadius, dur = cfg.GooTime, a = attacker })
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < cfg.GooTime do
					for _, v in ipairs(Kit.inCircle(attacker, g, cfg.GooRadius, 5)) do
						api.CharacterState.setSpeedMod(v, "CatGoo", cfg.GooSlow, 0.45)
					end
					task.wait(0.25)
				end
			end)
		end
		Kit.projectile(attacker, {
			origin = root.Position + Vector3.new(0, 1.2, 0) + dir * 2, dir = dir, speed = cfg.Speed, range = cfg.Range,
			size = Vector3.one * 1.3, color = HAIR, shape = BALL, gravity = cfg.Gravity, up = cfg.Up, spin = 12,
			decorate = function(part)
				decor(part, Vector3.new(0.08, 0.08, 1.7), CFrame.Angles(0.4, 0.3, 0), Color3.fromRGB(110, 115, 90))
				decor(part, Vector3.new(0.08, 1.6, 0.08), CFrame.Angles(0.2, 0, 0.6), Color3.fromRGB(110, 115, 90))
				decor(part, Vector3.new(1.5, 0.08, 0.08), CFrame.Angles(0, 0.7, 0.3), GINGER)
				decor(part, Vector3.one * 0.7, CFrame.new(0.35, 0.3, -0.2), GOO, BALL)
			end,
			onHit = function(v, pos, vel)
				api.hit(attacker, v, cfg, api.flat(vel, dir), { hitPos = pos })
				return false
			end,
			onEnd = function(pos)
				goo(pos)
			end,
		})
	end,

	-- Laser Chase : 3 ruées en zigzag derrière le point laser (chaque cible touchée au plus 2 fois)
	CatLaser = function(attacker, cfg, aim, api)
		local dir0 = Kit.aimDir(attacker, aim)
		Kit.fx({ id = "Cat_LaserStart", a = attacker })
		task.wait(cfg.Windup)
		local hits = {}
		local angles = { cfg.Zig, -cfg.Zig, 0 }
		for leg, ang in ipairs(angles) do
			if not ready(api, attacker) then
				return
			end
			local dir = CFrame.Angles(0, math.rad(ang), 0) * dir0
			Kit.fx({ id = "Cat_LaserLeg", a = attacker, dir = dir, len = cfg.Speed * cfg.LegTime, dur = cfg.LegTime, leg = leg, n = #angles })
			local legHit = {}
			Kit.dash(attacker, dir, cfg.Speed, cfg.LegTime, function(r)
				for _, v in ipairs(api.Hitbox.box(r.CFrame * CFrame.new(0, 0, -1.5), cfg.HitboxSize, attacker, 4)) do
					if not legHit[v] and (hits[v] or 0) < cfg.MaxHitsPerTarget then
						legHit[v] = true
						hits[v] = (hits[v] or 0) + 1
						local final = (leg == #angles or hits[v] == cfg.MaxHitsPerTarget) and cfg.Final or nil
						api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - r.Position, dir), final)
					end
				end
				return not api.CharacterState.isAlive(attacker)
			end)
		end
	end,

	-- Off The Desk : bureau flottant au-dessus de la zone ; 3 petits objets tombent puis l'écran (PLAQUE au sol)
	CatDesk = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local center = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 3))
		local right = dir:Cross(Vector3.yAxis)
		local items = {}
		for i, k in ipairs({ "Mug", "Stapler", "Plant" }) do
			local off = right * ((i - 2) * cfg.Radius * 0.6) + dir * Kit.rng:NextNumber(-2.5, 2.5)
			items[i] = { k = k, p = Kit.ground(center + off + Vector3.new(0, 2, 0)), t = cfg.Windup + (i - 1) * cfg.Gap }
		end
		items[4] = { k = "Monitor", p = center, t = cfg.Windup + 3 * cfg.Gap + 0.12 }
		Kit.fx({ id = "Telegraph", p = center, r = cfg.Radius, dur = items[4].t + cfg.Fall, a = attacker })
		Kit.fx({ id = "Cat_Desk", a = attacker, c = center, dir = dir, items = items, fall = cfg.Fall, r = cfg.Radius })
		local small = {}
		for i, it in ipairs(items) do
			task.delay(it.t + cfg.Fall, function()
				if not api.CharacterState.isAlive(attacker) then
					return
				end
				if i < 4 then
					for _, v in ipairs(Kit.inCircle(attacker, it.p + Vector3.new(0, 3, 0), cfg.SmallRadius, 7)) do
						if (small[v] or 0) < cfg.MaxSmallHits then
							small[v] = (small[v] or 0) + 1
							api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - it.p, dir), {
								Damage = cfg.SmallDamage, Pin = false, Knockback = 14, KnockUp = 8, Stun = 0.5, Category = "Light", Power = 0.4,
								Words = it.k == "Mug" and { "CLINK!", "MUG'D!" } or it.k == "Stapler" and { "CLACK!", "STAPLED!" } or { "THUD!", "PLANTED!" },
							})
						end
					end
				else
					for _, v in ipairs(Kit.inCircle(attacker, it.p + Vector3.new(0, 3, 0), cfg.BigRadius, 8)) do
						api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - it.p, dir))
					end
					api.ZoneService.shatterAround(it.p, cfg.BigRadius * 0.6, Vector3.new(0, 30, 0))
				end
			end)
		end
	end,

	-- Box Ambush : contre (carton) ; le premier qui le frappe se fait sauter dessus
	CatBox = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		boxHits[attacker] = nil
		attacker:SetAttribute("CatBoxUntil", Kit.now() + cfg.Window)
		api.CharacterState.setBlocking(attacker, true)
		api.CharacterState.setSpeedMod(attacker, "CatBox", 0.25, cfg.Window)
		Kit.fx({ id = "Cat_Box", a = attacker, dur = cfg.Window })
		local t0 = os.clock()
		while os.clock() - t0 < cfg.Window and api.CharacterState.isAlive(attacker) and not boxHits[attacker] do
			game:GetService("RunService").Heartbeat:Wait()
		end
		attacker:SetAttribute("CatBoxUntil", 0)
		api.CharacterState.setBlocking(attacker, false)
		api.CharacterState.setSpeedMod(attacker, "CatBox", nil)
		local foe = boxHits[attacker]
		boxHits[attacker] = nil
		local fr = foe and Kit.root(foe)
		if not fr or not root.Parent or not api.CharacterState.isAlive(attacker) or not api.CharacterState.isAlive(foe) or (fr.Position - root.Position).Magnitude > 30 then
			Kit.fx({ id = "Cat_BoxEnd", a = attacker })
			return
		end
		api.CharacterState.clearStun(attacker)
		local toMe = Kit.flat(root.Position - fr.Position, fr.CFrame.LookVector)
		local dest = Kit.safePoint(fr.Position, fr.Position + toMe * 3.2, 1.2)
		local from = root.Position
		root.CFrame = CFrame.lookAt(dest, Vector3.new(fr.Position.X, dest.Y, fr.Position.Z))
		Kit.fx({ id = "Cat_BoxPop", a = attacker, from = from, to = dest, v = foe })
		task.wait(0.12)
		if api.CharacterState.isAlive(attacker) and api.CharacterState.isAlive(foe) then
			api.hit(attacker, foe, cfg, api.flat(fr.Position - root.Position, root.CFrame.LookVector), { hitPos = fr.Position + Vector3.new(0, 1, 0) })
		end
	end,
}

------------------------------------------------------------------------
-- Passif (serveur) : Nine Lives ; + détection du contre Box Ambush
------------------------------------------------------------------------
function M.ServerInit(api)
	local CS = api.CombatService
	-- Box Ambush : le coup reçu dans le carton devient un blocage sans dégâts, on retient l'agresseur
	table.insert(CS.damageMods, function(p)
		local v, a = p.victim, p.attacker
		if a and a ~= v and v and (v:GetAttribute("CatBoxUntil") or 0) > Kit.now() then
			local vr = Kit.root(v)
			if vr then
				p.dir = -Kit.flat(vr.CFrame.LookVector)
			end
			p.unblockable = false
			p.trayGuard = true
			if not boxHits[v] then
				boxHits[v] = a
			end
		end
	end)
	-- Nine Lives : ajouté en DERNIER (après les bonus des autres passifs) pour annuler vraiment le coup
	task.delay(1, function()
		table.insert(CS.damageMods, function(p)
			local v = p.victim
			if not v or v:GetAttribute("CharacterName") ~= "OfficeCat" or (p.damage or 0) <= 0 or p.trayGuard or p.category == "Ultimate" or p.unblockable then
				return
			end
			local n = (v:GetAttribute("CatHits") or 0) + 1
			if n >= LIVES then
				n = 0
				p.damage = 0
				p.knockback = 0
				p.up = 0
				p.stun = 0.05
				p.launch = nil
				p.pin = nil
				p.slam = nil
				p.air = nil
				p.category = "Light"
				p.power = 0.15
				p.words = { "MISSED ME!", "NINE LIVES!" }
				Kit.fx({ id = "Cat_Life", v = v })
			end
			v:SetAttribute("CatHits", n)
		end)
	end)
end

------------------------------------------------------------------------
-- Effets client
------------------------------------------------------------------------
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local ProcAnim -- branché dans ClientInit

local function snd(id, pos, vol, pitch)
	local holder = Kit.part({ Size = Vector3.one * 0.2, Transparency = 1, Position = pos })
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 1
	s.PlaybackSpeed = pitch or 1
	s.RollOffMaxDistance = 120
	s.Parent = holder
	s:Play()
	Debris:AddItem(holder, 4)
end

-- 3 griffures parallèles dans le plan face à dir
local function claws(pos, look, angle, len, color, life)
	local base = CFrame.lookAt(pos, pos + look) * CFrame.Angles(0, 0, angle)
	for i = -1, 1 do
		local cf = base * CFrame.new(i * 0.55, 0, 0)
		local s = Kit.part({ Size = Vector3.new(0.18, 0.3, 0.18), CFrame = cf * CFrame.new(0, len / 2, 0), Color = color })
		local core = Kit.part({ Size = Vector3.new(0.08, 0.3, 0.2), CFrame = cf * CFrame.new(0, len / 2, -0.02), Color = WHITE })
		Kit.tween(s, 0.06, { Size = Vector3.new(0.22, len, 0.18), CFrame = cf })
		Kit.tween(core, 0.06, { Size = Vector3.new(0.09, len * 0.9, 0.2), CFrame = cf * CFrame.new(0, 0, -0.02) })
		task.delay(0.08, function()
			Kit.tween(s, life, { Transparency = 1, Size = Vector3.new(0.05, len * 1.1, 0.05) })
			Kit.tween(core, life, { Transparency = 1 })
		end)
		Debris:AddItem(s, life + 0.12)
		Debris:AddItem(core, life + 0.12)
	end
end

-- empreinte de patte au sol
local function pawPrint(pos, look, scale, color, life)
	local base = CFrame.lookAt(pos, pos + Kit.flat(look))
	local parts = {}
	local function disc(off, d)
		local p = Kit.part({ Shape = CYL, Size = Vector3.new(0.08, d * scale, d * scale), CFrame = base * CFrame.new(off.X * scale, 0.08, off.Z * scale) * UP, Color = color })
		table.insert(parts, p)
	end
	disc(Vector3.new(0, 0, 0.3), 2.2)
	for _, o in ipairs({ { -1.05, -0.75 }, { -0.38, -1.35 }, { 0.38, -1.35 }, { 1.05, -0.75 } }) do
		disc(Vector3.new(o[1], 0, o[2]), 0.85)
	end
	task.delay(life, function()
		for _, p in ipairs(parts) do
			Kit.tween(p, 0.4, { Transparency = 1 })
			Debris:AddItem(p, 0.42)
		end
	end)
end

-- objets du bureau (repère local, origine = base de l'objet)
local function buildItem(kind, cf)
	local list = {}
	local function add(size, off, color, shape)
		local p = Kit.part({ Size = size, CFrame = cf * off, Color = color })
		if shape then
			p.Shape = shape
		end
		table.insert(list, { p = p, off = off })
		return p
	end
	if kind == "Mug" then
		add(Vector3.new(1.4, 1.2, 1.2), CFrame.new(0, 0.7, 0) * UP, WHITE, CYL)
		add(Vector3.new(0.1, 1.0, 1.0), CFrame.new(0, 1.31, 0) * UP, Color3.fromRGB(110, 60, 30), CYL)
		add(Vector3.new(0.25, 0.8, 0.5), CFrame.new(0.75, 0.7, 0), WHITE)
		add(Vector3.new(0.05, 0.5, 0.5), CFrame.new(0, 0.7, -0.62), GINGER)
	elseif kind == "Stapler" then
		add(Vector3.new(0.7, 0.3, 2.0), CFrame.new(0, 0.15, 0), DARK)
		add(Vector3.new(0.75, 0.45, 1.9), CFrame.new(0, 0.55, 0.05) * CFrame.Angles(math.rad(-6), 0, 0), Color3.fromRGB(220, 40, 45))
		add(Vector3.new(0.6, 0.1, 0.4), CFrame.new(0, 0.82, -0.7), Color3.fromRGB(200, 205, 215))
	elseif kind == "Plant" then
		add(Vector3.new(1.2, 1.2, 1.2), CFrame.new(0, 0.6, 0) * UP, Color3.fromRGB(200, 100, 60), CYL)
		add(Vector3.new(0.2, 1.35, 1.35), CFrame.new(0, 1.2, 0) * UP, Color3.fromRGB(175, 85, 50), CYL)
		add(Vector3.one * 1.1, CFrame.new(0, 1.9, 0), Color3.fromRGB(70, 190, 80), BALL)
		add(Vector3.one * 0.8, CFrame.new(0.4, 2.3, 0.2), Color3.fromRGB(90, 215, 95), BALL)
		add(Vector3.one * 0.7, CFrame.new(-0.4, 2.4, -0.1), Color3.fromRGB(60, 170, 70), BALL)
	else -- Monitor
		add(Vector3.new(5.2, 3.4, 0.5), CFrame.new(0, 2.6, 0), Color3.fromRGB(45, 45, 55))
		local screen = add(Vector3.new(4.7, 2.9, 0.1), CFrame.new(0, 2.6, -0.28), Color3.fromRGB(80, 200, 255))
		Kit.flatText(screen, "=^.^=", WHITE, Enum.NormalId.Front)
		add(Vector3.new(0.6, 1.0, 0.4), CFrame.new(0, 0.6, 0.1), Color3.fromRGB(60, 60, 70))
		add(Vector3.new(2.4, 0.2, 1.4), CFrame.new(0, 0.1, 0), Color3.fromRGB(60, 60, 70))
	end
	return list
end

local function moveItem(list, cf)
	for _, e in ipairs(list) do
		e.p.CFrame = cf * e.off
	end
end

M.MoveFX = {
	CatPounce = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 3.5, 0), "!", GINGER, 2.4, 0.5, 1)
		end
	end,
	Hairball = function(c, d, api) end,
	ClawFury = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			snd(SND.Hiss, r.Position, 0.6, 1.1)
		end
		for i = 1, 6 do
			task.delay(0.1 + (i - 1) * 0.09, function()
				local rr = c:FindFirstChild("HumanoidRootPart")
				if not rr then
					return
				end
				local look = rr.CFrame.LookVector
				local p = rr.Position + look * 3 + Vector3.new(0, 0.6, 0)
				if i < 6 then
					claws(p, -look, (i % 2 == 0) and 0.7 or -0.7, 3.2, (i % 2 == 0) and GINGER or STRIPE, 0.22)
					api.CartoonFX.sparks(p, 4, WHITE)
				else
					claws(p, -look, 0.75, 4.6, GINGER, 0.35)
					claws(p, -look, -0.75, 4.6, STRIPE, 0.35)
					api.CartoonFX.bigImpact(p, look, 0.9, GINGER)
					snd(SND.Meow, p, 0.8, 1.15)
				end
			end)
		end
	end,
	LaserChase = function(c, d, api)
		api.afterimages(c, 0.62, GINGER)
		if Kit.mine(c) then
			task.delay(0.1, function()
				api.CartoonFX.speedLines(0.5, LASER)
			end)
		end
	end,
	OffTheDesk = function(c, d, api) end,
	BoxAmbush = function(c, d, api) end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	ProcAnim = api.ProcAnim
	Kit.setupClient()

	-- tortillement : petits poils qui volent
	Kit.on("Cat_Wiggle", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		snd(SND.Meow2, r.Position, 0.7, 1.3)
		for i = 0, 2 do
			task.delay(i * 0.12, function()
				if r.Parent then
					Kit.cubes(r.Position - r.CFrame.LookVector * 1.2 - Vector3.new(0, 1, 0), 3, FUR, 0.25, 3, 0.3)
				end
			end)
		end
	end)

	Kit.on("Cat_Leap", function(d)
		local c = d.a
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		CartoonFX.sound("Whoosh", r.Position, 1)
		CartoonFX.dust(CartoonFX.groundPos(r.Position), 3, nil, 6)
		local tr = c:FindFirstChild("Torso")
		if tr then
			CartoonFX.trailOn(tr, GINGER, d.dur + 0.1, 0, 1.6)
		end
	end)

	Kit.on("Cat_PounceLand", function(d)
		CartoonFX.sound("GroundSlam", d.p, 1)
		CartoonFX.sound("PunchHeavy", d.p, 1)
		snd(SND.Meow, d.p, 1, 0.9)
		CartoonFX.bigImpact(d.p + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.2, GINGER)
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r * 1.25, GINGER)
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.3, 0), d.r * 0.7, CREAM)
		CartoonFX.word(d.p + Vector3.new(0, 5, 0), "POUNCE!", 1.3, "Heavy")
		pawPrint(d.p, d.dir or Vector3.new(0, 0, -1), 1.3, PINK, 1.2)
		Kit.cubes(d.p + Vector3.new(0, 0.6, 0), 14, FUR, 0.5, 10, 0.5)
		claws(d.p + Vector3.new(0, 2, 0) + (d.dir or Vector3.zero) * 1.5, -(d.dir or Vector3.new(0, 0, -1)), 0.6, 4, GINGER, 0.3)
		if Kit.mine(d.a) then
			CartoonFX.shake(0.9)
			CartoonFX.impactFrame(0.6)
		end
	end)

	Kit.on("Cat_Hack", function(d)
		local c = d.a
		local head = c and c:FindFirstChild("Head")
		if not head then
			return
		end
		local p = head.Position + head.CFrame.LookVector * 0.9
		CartoonFX.sound("Splat", p, 0.9)
		snd(SND.Hiss, p, 0.4, 1.6)
		Kit.floatText(p + Vector3.new(0, 1.5, 0), "*HACK*", GOO, 2.2, 0.7, 1.5)
		Kit.cubes(p, 8, { GOO, HAIR, GINGER }, 0.35, 4, 0.4)
		CartoonFX.puff(p, 1)
	end)

	Kit.on("Cat_Goo", function(d)
		CartoonFX.sound("Splat", d.p, 1.2)
		CartoonFX.word(d.p + Vector3.new(0, 3, 0), "SPLAT!", 1, "Light")
		local pool = Kit.part({ Shape = CYL, Size = Vector3.new(0.12, 1, 1), CFrame = CFrame.new(d.p + Vector3.new(0, 0.08, 0)) * UP, Color = GOO, Transparency = 0.15 })
		local rim = Kit.part({ Shape = CYL, Size = Vector3.new(0.1, 1.2, 1.2), CFrame = CFrame.new(d.p + Vector3.new(0, 0.06, 0)) * UP, Color = Color3.fromRGB(120, 140, 70), Transparency = 0.2 })
		Kit.tween(pool, 0.25, { Size = Vector3.new(0.12, d.r * 2, d.r * 2) }, Enum.EasingStyle.Back)
		Kit.tween(rim, 0.25, { Size = Vector3.new(0.1, d.r * 2 + 0.8, d.r * 2 + 0.8) }, Enum.EasingStyle.Back)
		local fade = { pool, rim }
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local b = Kit.part({ Shape = BALL, Size = Vector3.one * Kit.rng:NextNumber(0.6, 1.1), Position = d.p + Vector3.new(math.cos(a) * d.r * 0.55, 0.15, math.sin(a) * d.r * 0.55), Color = (i % 2 == 0) and HAIR or GOO })
			table.insert(fade, b)
		end
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r, GOO)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < d.dur do
				local a, rr = Kit.rng:NextNumber(0, math.pi * 2), Kit.rng:NextNumber(0, d.r * 0.9)
				local pos = d.p + Vector3.new(math.cos(a) * rr, 0.2, math.sin(a) * rr)
				local bub = Kit.part({ Shape = BALL, Size = Vector3.one * 0.35, Position = pos, Color = GOO, Transparency = 0.2 })
				Kit.tween(bub, 0.5, { Size = Vector3.one * 0.8, Position = pos + Vector3.new(0, 0.6, 0), Transparency = 1 })
				Debris:AddItem(bub, 0.52)
				task.wait(0.12)
			end
			for _, p in ipairs(fade) do
				Kit.tween(p, 0.4, { Transparency = 1 })
				Debris:AddItem(p, 0.42)
			end
		end)
	end)

	-- Laser Chase : point rouge qui file devant, rayon depuis le ciel, traînée
	Kit.on("Cat_LaserStart", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if r then
			snd(SND.Meow2, r.Position, 0.8, 1.5)
			Kit.floatText(r.Position + Vector3.new(0, 4, 0), "RED DOT!!", LASER, 2.6, 0.8, 1.5)
		end
	end)
	Kit.on("Cat_LaserLeg", function(d)
		local c = d.a
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		local from = CartoonFX.groundPos(r.Position)
		local to = CartoonFX.groundPos(r.Position + d.dir * (d.len + 3))
		local dot = Kit.part({ Shape = CYL, Size = Vector3.new(0.1, 1.1, 1.1), CFrame = CFrame.new(from + Vector3.new(0, 0.1, 0)) * UP, Color = LASER, Material = Enum.Material.Neon })
		local glow = Kit.part({ Shape = BALL, Size = Vector3.one * 0.6, Position = from + Vector3.new(0, 0.2, 0), Color = Color3.fromRGB(255, 160, 160), Material = Enum.Material.Neon })
		local sky = from + Vector3.new(-8, 40, 6)
		local beam = Kit.part({ Size = Vector3.new(0.12, 0.12, 1), Color = LASER, Material = Enum.Material.Neon, Transparency = 0.4 })
		CartoonFX.sound("Dash", r.Position, 0.8)
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = math.clamp((os.clock() - t0) / (d.dur * 0.8), 0, 1)
			local p = from:Lerp(to, a) + Vector3.new(0, 0.1, 0)
			dot.CFrame = CFrame.new(p) * UP
			glow.Position = p + Vector3.new(0, 0.15, 0)
			local len = (p - sky).Magnitude
			beam.Size = Vector3.new(0.12, 0.12, len)
			beam.CFrame = CFrame.lookAt(sky, p) * CFrame.new(0, 0, -len / 2)
			if os.clock() - t0 > d.dur + 0.15 then
				conn:Disconnect()
				dot:Destroy()
				glow:Destroy()
				beam:Destroy()
			end
		end)
		CartoonFX.dust(from, 2.5, nil, 5)
		if d.leg == d.n then
			task.delay(d.dur, function()
				local rr = c:FindFirstChild("HumanoidRootPart")
				if rr then
					CartoonFX.shockwave(CartoonFX.groundPos(rr.Position) + Vector3.new(0, 0.2, 0), 7, LASER)
					pawPrint(CartoonFX.groundPos(rr.Position), d.dir, 0.8, LASER, 0.6)
				end
			end)
		end
	end)

	-- Off The Desk : bureau flottant, objets poussés un à un
	Kit.on("Cat_Desk", function(d)
		local look = d.dir or Vector3.new(0, 0, -1)
		local deskCF = CFrame.lookAt(d.c + Vector3.new(0, 13, 0), d.c + Vector3.new(0, 13, 0) + look)
		local desk = {}
		local function dpart(size, off, color)
			local p = Kit.part({ Size = size, CFrame = deskCF * off * CFrame.new(0, 6, 0), Color = color, Transparency = 1 })
			Kit.tween(p, 0.25, { CFrame = deskCF * off, Transparency = 0 }, Enum.EasingStyle.Back)
			table.insert(desk, p)
			return p
		end
		dpart(Vector3.new(d.r * 2 + 4, 0.5, 5), CFrame.new(0, 0, 0), Color3.fromRGB(150, 100, 60))
		dpart(Vector3.new(d.r * 2 + 4, 1.2, 0.3), CFrame.new(0, -0.7, 2.4), Color3.fromRGB(120, 80, 45))
		for _, s in ipairs({ -1, 1 }) do
			dpart(Vector3.new(0.5, 3, 0.5), CFrame.new(s * (d.r + 1.5), -1.7, 2), Color3.fromRGB(120, 80, 45))
		end
		CartoonFX.sound("Pickup", d.c, 1)
		Kit.floatText(d.c + Vector3.new(0, 16, 0), "...don't you dare.", WHITE, 3, 1, 1)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if r then
			snd(SND.Meow2, r.Position, 0.7, 1)
		end
		for _, it in ipairs(d.items or {}) do
			-- l'objet est posé sur le bureau, au-dessus de son point de chute
			local top = Vector3.new(it.p.X, d.c.Y + 13.25, it.p.Z)
			local startCF = CFrame.lookAt(top, top + look)
			local list = buildItem(it.k, startCF * CFrame.new(0, 6, 0))
			for _, e in ipairs(list) do
				Kit.tween(e.p, 0.25, { CFrame = startCF * e.off }, Enum.EasingStyle.Back)
			end
			task.delay(it.t - 0.12, function()
				-- petite tape : l'objet glisse vers le bord
				local edge = startCF * CFrame.new(0, 0, -2.6)
				for _, e in ipairs(list) do
					Kit.tween(e.p, 0.12, { CFrame = edge * CFrame.Angles(math.rad(-25), 0, 0) * e.off })
				end
				Kit.floatText(top + Vector3.new(0, 2, 0), "*tap*", GINGER, 1.6, 0.5, 1)
			end)
			task.delay(it.t, function()
				local t0 = os.clock()
				local fromCF = startCF * CFrame.new(0, 0, -2.6)
				local spin = Kit.rng:NextNumber(-1, 1)
				Kit.telegraph(it.p, it.k == "Monitor" and 6.5 or 4, d.fall, d.a)
				local conn
				conn = RunService.RenderStepped:Connect(function()
					local a = math.clamp((os.clock() - t0) / d.fall, 0, 1)
					local pos = fromCF.Position:Lerp(it.p, a)
					pos = Vector3.new(pos.X, fromCF.Position.Y + (it.p.Y - fromCF.Position.Y) * a * a, pos.Z)
					moveItem(list, CFrame.new(pos) * (fromCF - fromCF.Position) * CFrame.Angles(a * 2.2 * spin, 0, a * 1.4 * spin))
					if a >= 1 then
						conn:Disconnect()
						for _, e in ipairs(list) do
							e.p:Destroy()
						end
						if it.k == "Monitor" then
							CartoonFX.sound("GlassBreak", it.p, 1.2)
							CartoonFX.sound("BigImpact", it.p, 1)
							CartoonFX.bigImpact(it.p + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.4, Color3.fromRGB(80, 200, 255))
							CartoonFX.shockwave(it.p + Vector3.new(0, 0.2, 0), 8, GINGER)
							CartoonFX.shards(it.p + Vector3.new(0, 1, 0), 18, { Color3.fromRGB(80, 200, 255), Color3.fromRGB(45, 45, 55), WHITE }, 1.4)
							CartoonFX.word(it.p + Vector3.new(0, 5, 0), "CRASH!!", 1.5, "Heavy")
							if Kit.mine(d.a) then
								CartoonFX.shake(1)
								CartoonFX.impactFrame(0.7)
							end
							-- le chat est très fier de lui
							local rr = d.a and d.a:FindFirstChild("HumanoidRootPart")
							if rr then
								snd(SND.Meow, rr.Position, 0.9, 1.05)
								Kit.floatText(rr.Position + Vector3.new(0, 4, 0), "=^.^=", GINGER, 2.4, 1, 1.5)
							end
							for _, p in ipairs(desk) do
								Kit.tween(p, 0.3, { Transparency = 1, CFrame = p.CFrame * CFrame.new(0, 4, 0) })
								Debris:AddItem(p, 0.32)
							end
						elseif it.k == "Mug" then
							CartoonFX.sound("GlassBreak", it.p, 0.8)
							Kit.cubes(it.p + Vector3.new(0, 0.5, 0), 10, { WHITE, Color3.fromRGB(110, 60, 30) }, 0.4, 6, 0.4)
							CartoonFX.shockwave(it.p + Vector3.new(0, 0.2, 0), 4, Color3.fromRGB(110, 60, 30))
						elseif it.k == "Stapler" then
							CartoonFX.sound("MetalHit", it.p, 0.9)
							CartoonFX.sparks(it.p + Vector3.new(0, 0.5, 0), 10, WHITE)
							CartoonFX.shockwave(it.p + Vector3.new(0, 0.2, 0), 4, Color3.fromRGB(220, 40, 45))
						else
							CartoonFX.sound("Crash", it.p, 0.8)
							Kit.cubes(it.p + Vector3.new(0, 0.5, 0), 12, { Color3.fromRGB(200, 100, 60), Color3.fromRGB(90, 60, 40), Color3.fromRGB(70, 190, 80) }, 0.45, 6, 0.45)
							CartoonFX.shockwave(it.p + Vector3.new(0, 0.2, 0), 4, Color3.fromRGB(70, 190, 80))
						end
						if Kit.mine(d.a) and it.k ~= "Monitor" then
							CartoonFX.shake(0.25)
						end
					end
				end)
			end)
		end
		-- sécurité : le bureau disparaît même si l'écran n'est jamais tombé
		task.delay(3, function()
			for _, p in ipairs(desk) do
				if p.Parent then
					p:Destroy()
				end
			end
		end)
	end)

	-- Box Ambush : carton qui suit le chat
	local boxes = {}
	Kit.on("Cat_Box", function(d)
		local c = d.a
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		CartoonFX.sound("Pickup", r.Position, 1)
		Kit.floatText(r.Position + Vector3.new(0, 4, 0), "IF I FITS, I SITS", CARD, 3, 1.1, 1)
		local parts = {}
		local function add(size, off, color)
			local p = Kit.part({ Size = size, Color = color })
			table.insert(parts, { p = p, off = off })
			return p
		end
		add(Vector3.new(3.6, 2.6, 0.2), CFrame.new(0, -1.7, -1.8), CARD)
		add(Vector3.new(3.6, 2.6, 0.2), CFrame.new(0, -1.7, 1.8), CARD)
		add(Vector3.new(0.2, 2.6, 3.6), CFrame.new(-1.8, -1.7, 0), CARD2)
		add(Vector3.new(0.2, 2.6, 3.6), CFrame.new(1.8, -1.7, 0), CARD2)
		add(Vector3.new(3.4, 0.2, 3.4), CFrame.new(0, -2.95, 0), CARD2)
		add(Vector3.new(3.8, 0.18, 0.5), CFrame.new(0, -1.1, -1.8), Color3.fromRGB(230, 200, 140)) -- scotch
		add(Vector3.new(3.6, 0.15, 1.6), CFrame.new(0, -0.4, -2.6) * CFrame.Angles(math.rad(-50), 0, 0), CARD)
		add(Vector3.new(3.6, 0.15, 1.6), CFrame.new(0, -0.4, 2.6) * CFrame.Angles(math.rad(50), 0, 0), CARD)
		local label = add(Vector3.new(2.2, 1, 0.1), CFrame.new(0, -1.7, -1.92), CARD)
		Kit.flatText(label, "FRAGILE", Color3.fromRGB(200, 40, 40), Enum.NormalId.Front)
		local t0 = os.clock()
		local state = { parts = parts }
		boxes[c] = state
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			if el > d.dur + 0.2 or state.dead or not r.Parent then
				conn:Disconnect()
				if not state.dead then
					for _, e in ipairs(parts) do
						e.p:Destroy()
					end
				end
				if boxes[c] == state then
					boxes[c] = nil
				end
				return
			end
			local wob = math.sin(el * 18) * 0.04
			local base = CFrame.new(r.Position) * (r.CFrame - r.Position) * CFrame.Angles(0, 0, wob)
			for _, e in ipairs(parts) do
				e.p.CFrame = base * e.off
			end
		end)
		task.delay(0.35, function()
			if r.Parent and not state.dead then
				Kit.floatText(r.Position + Vector3.new(0, 0.6, 0) + r.CFrame.LookVector * 1.2, "o_o", GREEN, 1.6, 0.8, 0.3)
			end
		end)
	end)

	Kit.on("Cat_BoxPop", function(d)
		local st = boxes[d.a]
		if st then
			st.dead = true
			for _, e in ipairs(st.parts) do
				local p = e.p
				local dir = (p.Position - d.from).Unit + Vector3.new(0, 1, 0)
				Kit.tween(p, 0.45, { CFrame = p.CFrame * CFrame.Angles(Kit.rng:NextNumber(-2, 2), 0, Kit.rng:NextNumber(-2, 2)) + dir * 6, Transparency = 1 })
				Debris:AddItem(p, 0.47)
			end
		end
		CartoonFX.sound("WoodBreak", d.from, 1)
		snd(SND.Hiss, d.to, 1, 1)
		CartoonFX.word(d.to + Vector3.new(0, 4, 0), "SURPRISE!", 1.3, "Heavy")
		Kit.cubes(d.from, 12, { CARD, CARD2 }, 0.5, 8, 0.5)
		CartoonFX.beam(d.from, d.to, 1.2, GINGER, 0.2)
		if ProcAnim and d.a then
			pcall(ProcAnim.play, d.a, "CatBoxStrike")
		end
		task.delay(0.12, function()
			local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
			local p = vr and vr.Position or d.to
			claws(p + Vector3.new(0, 0.5, 0), (d.to - p).Magnitude > 0.1 and (d.to - p).Unit or Vector3.new(0, 0, 1), 0.7, 4.5, GINGER, 0.35)
			CartoonFX.bigImpact(p, Vector3.new(0, 1, 0), 1.1, GINGER)
			if Kit.mine(d.a) then
				CartoonFX.shake(0.8)
			end
		end)
	end)

	Kit.on("Cat_BoxEnd", function(d)
		local st = boxes[d.a]
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if st then
			st.dead = true
			for _, e in ipairs(st.parts) do
				Kit.tween(e.p, 0.3, { Size = e.p.Size * 0.2, Transparency = 1 })
				Debris:AddItem(e.p, 0.32)
			end
		end
		if r then
			CartoonFX.puff(r.Position - Vector3.new(0, 2, 0), 1.6)
			Kit.floatText(r.Position + Vector3.new(0, 3.5, 0), "...meow?", CREAM, 2, 0.9, 1)
		end
	end)

	-- Nine Lives : esquive (silhouette fantôme dorée, « NINE LIVES! »)
	Kit.on("Cat_Life", function(d)
		local v = d.v
		local r = v and v:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		snd(SND.Meow2, r.Position, 0.8, 1.2)
		Kit.floatText(r.Position + Vector3.new(0, 4.2, 0), "NINE LIVES!", GOLD, 3, 1, 2)
		CartoonFX.sparks(r.Position + Vector3.new(0, 1, 0), 10, GOLD)
		for _, n in ipairs({ "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
			local src = v:FindFirstChild(n)
			if src then
				local g = Kit.part({ Size = src.Size, CFrame = src.CFrame, Color = GOLD, Transparency = 0.4, Material = Enum.Material.Neon })
				Kit.tween(g, 0.5, { CFrame = src.CFrame + Vector3.new(0, 2.5, 0) - r.CFrame.LookVector * 1.5, Transparency = 1 })
				Debris:AddItem(g, 0.52)
			end
		end
	end)

	-- aura de transformation : point laser qui se balade devant le chat, étincelles vertes dans les yeux
	local dots = {}
	task.spawn(function()
		while true do
			task.wait(0.05)
			local seen = {}
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "OfficeCat" and c:GetAttribute("Transformed") then
					local r = c:FindFirstChild("HumanoidRootPart")
					if r then
						seen[c] = true
						local st = dots[c]
						if not st then
							st = { p = Kit.part({ Shape = CYL, Size = Vector3.new(0.08, 0.7, 0.7), Color = LASER, Material = Enum.Material.Neon }), t = Kit.rng:NextNumber(0, 10) }
							dots[c] = st
						end
						st.t += 0.05
						local off = Vector3.new(math.sin(st.t * 1.7) * 3 + math.sin(st.t * 4.1), 0, -4 - math.cos(st.t * 2.3) * 2)
						local target = CartoonFX.groundPos((r.CFrame * CFrame.new(off)).Position)
						st.p.CFrame = CFrame.new(st.p.Position:Lerp(target + Vector3.new(0, 0.08, 0), 0.5)) * UP
						if Kit.rng:NextNumber() < 0.08 then
							local head = c:FindFirstChild("Head")
							if head then
								Kit.cubes(head.Position + head.CFrame.LookVector * 0.65, 1, { GREEN }, 0.15, 1.5, 0.3)
							end
						end
					end
				end
			end
			for c, st in pairs(dots) do
				if not seen[c] then
					st.p:Destroy()
					dots[c] = nil
				end
			end
		end
	end)
end

return M
