--[[
	The Barista — personnage complet (format : voir Modules/ContentLoader).
	Passif Extra Shot : chaque 4e coup qu'il porte fait +4 dégâts (« EXTRA SHOT! »).
	Attaques : Espresso Express (ruée vapeur qui traverse et brûle), Bean Barrage (éventail de grains qui rebondissent),
	           Latte Art (cœur de mousse géant au sol qui ralentit et pique).
	Transformation Triple Shot Venti : Portafilter Smash (bond + PLAQUE au sol), To-Go Order (saisie dans un gobelet géant
	           secoué puis lancé), Caffeine Overload (buff vitesse + coups brûlants, explosion de vapeur).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT
local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2)
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)

local BREW = Color3.fromRGB(140, 80, 42) -- couleur du perso (espresso)
local DARKC = Color3.fromRGB(62, 36, 20)
local CREAM = Color3.fromRGB(240, 222, 190)
local FOAM = Color3.fromRGB(255, 250, 240)
local CARAMEL = Color3.fromRGB(215, 145, 60)
local STEEL = Color3.fromRGB(200, 205, 215)
local WHITE = Color3.fromRGB(250, 250, 250)
local BURLAP = Color3.fromRGB(190, 160, 110)
local STEAM = Color3.fromRGB(235, 240, 245)

local M = { Id = "Barista", Order = 9 }

M.Character = {
	DisplayName = "The Barista",
	Role = "Caffeinated brawler",
	Color = BREW,
	Shirt = Color3.fromRGB(245, 238, 225), Pants = Color3.fromRGB(55, 42, 35), Tie = BREW,
	Passive = { Name = "Extra Shot", Desc = "Every 4th hit he lands is an EXTRA SHOT: +4 damage." },
	Attacks = { "EspressoExpress", "BeanBarrage", "LatteArt" },
	Transformation = { Name = "Triple Shot Venti", Desc = "Giant steaming cup hat and espresso tanks on his back.", Duration = 20, SpeedMultiplier = 1.2 },
	TransAttacks = { "PortafilterSmash", "ToGoOrder", "CaffeineOverload" },
}

M.Attacks = {
	EspressoExpress = { Name = "Espresso Express", Kind = "BarSteamDash", Desc = "Steam-rocket forward THROUGH everyone in your path and scald them.", Prop = "BarPitcher", Cooldown = 7, Anim = "BarExpress", Sound = "Dash",
		Windup = 0.25, Speed = 92, Time = 0.38, HitboxSize = Vector3.new(7, 6, 7), Damage = 8, Knockback = 30, KnockUp = 14, Stun = 0.8, Category = "Heavy", Power = 0.75,
		Words = { "ESPRESSO!", "PSSHHH!" }, Effects = { Burn = { Ticks = 2, Damage = 2, Interval = 0.5 } } },
	BeanBarrage = { Name = "Bean Barrage", Kind = "BarBeans", Desc = "Flick a fan of 5 roasted coffee beans that bounce off walls.", Prop = "BarBeanBag", Cooldown = 6, Anim = "BarBeans", Sound = "Throw",
		Count = 5, Spread = 34, Speed = 105, Range = 55, Damage = 3, Knockback = 6, Stun = 0.45, Category = "Projectile", Power = 0.3, Words = { "BEANED!", "CRUNCH!" } },
	LatteArt = { Name = "Latte Art", Kind = "BarLatte", Desc = "Pour a giant latte-art heart on the floor: it slows and stings everyone standing in it.", Prop = "BarJug", Cooldown = 11, Anim = "BarLatte", Sound = "Water",
		Offset = 10, Radius = 10, LatteTime = 5, Tick = 0.5, SlowMult = 0.5, Damage = 1.3, Knockback = 2, Stun = 0.15, Category = "Light", Power = 0.2, Words = { "FOAMED!", "FROTH!" } },
	PortafilterSmash = { Name = "Portafilter Smash", Kind = "BarLeap", Desc = "Leap up and TAMP the spot ahead with a giant portafilter: everyone under it is PINNED.", Prop = "BarPortafilter", Cooldown = 12, Anim = "BarSmash", Sound = "GroundSlam",
		Offset = 14, Radius = 10, Windup = 0.3, Up = 46, Rise = 0.3, Damage = 14, Knockback = 0, Stun = 1.4, Category = "Heavy", GuardBreak = true, Power = 1.2,
		Words = { "TAMPED!", "PORTAFILTER!" }, Effects = { Pin = true } },
	ToGoOrder = { Name = "To-Go Order", Kind = "BarToGo", Desc = "Stuff the closest coworker in a giant to-go cup, shake it up and hurl it.", Cooldown = 10, Anim = "BarToGo", Sound = "Whoosh",
		HitboxOffset = 3.5, HitboxSize = Vector3.new(6, 6, 7), HoldTime = 0.8, Windup = 0.25, Damage = 12, ThrowKnockback = 60, ThrowUp = 26, Stun = 1.0, Category = "Heavy", Power = 1.0,
		Words = { "ORDER UP!", "TO GO!" } },
	CaffeineOverload = { Name = "Caffeine Overload", Kind = "BarOverload", Desc = "Chug a venti: steam burst around you, then +35% speed for 6s and every hit scalds.", Prop = "BarVenti", Cooldown = 15, Anim = "BarChug", Sound = "PowerUp",
		BuffTime = 6, SpeedMultiplier = 1.35, Radius = 9, Damage = 5, Knockback = 26, KnockUp = 10, Stun = 0.6, Category = "Heavy", Power = 0.6, Words = { "JITTERS!", "OVERLOAD!" } },
}

------------------------------------------------------------------------
-- Animations (une unique par attaque)
------------------------------------------------------------------------
local function toGoAnim()
	local f = {
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.7, y = 0.6 }, LS = { p = 1.7, y = 0.6 }, RJ = { ln = 0.45 }, LH = { p = 0.6 }, RH = { p = -0.3 } },
		{ t = 0.26, RS = { p = 3.0, r = -0.2 }, LS = { p = 3.0, r = -0.2 }, RJ = { ln = -0.35 } },
	}
	for i = 1, 4 do -- secoue le gobelet de gauche à droite
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = 0.26 + i * 0.1, RS = { p = 3.0, r = 0.25 * s }, LS = { p = 3.0, r = -0.25 * s }, RJ = { ln = -0.35, sd = 0.28 * s, tw = 0.22 * s }, RH = { p = 0.15 * s }, LH = { p = -0.15 * s } })
	end
	table.insert(f, { t = 0.8, RS = { p = 3.25 }, LS = { p = 3.25 }, RJ = { ln = -0.6, tw = -0.45 }, RH = { p = -0.3 }, LH = { p = 0.4 } })
	table.insert(f, { t = 0.92, RS = { p = 1.25, y = 0.3 }, LS = { p = 1.25, y = 0.3 }, RJ = { ln = 0.75, tw = 0.45 }, LH = { p = 0.85 }, RH = { p = -0.55 } })
	table.insert(f, { t = 1.12, RS = { p = 1.2, y = 0.3 }, LS = { p = 1.2, y = 0.3 }, RJ = { ln = 0.65, tw = 0.4 }, LH = { p = 0.75 }, RH = { p = -0.45 } })
	table.insert(f, { t = 1.28 })
	return f
end

local function chugAnim()
	local f = {
		{ t = 0 },
		{ t = 0.12, RS = { p = 2.7, y = 0.9 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = -0.45 }, RH = { p = -0.1 }, LH = { p = 0.2 } },
		{ t = 0.42, RS = { p = 2.95, y = 0.9 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = -0.6 }, RH = { p = -0.1 }, LH = { p = 0.2 } },
	}
	for i = 1, 4 do -- les tremblements de la caféine
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = 0.42 + i * 0.04, RS = { p = 0.6, r = -0.6 + 0.2 * s }, LS = { p = 0.6, r = -0.6 - 0.2 * s }, RJ = { ln = 0.4, sd = 0.12 * s, tw = 0.15 * s }, RH = { p = 0.4 }, LH = { p = 0.4 } })
	end
	table.insert(f, { t = 0.66, RS = { p = 1.6, r = -1.35 }, LS = { p = 1.6, r = -1.35 }, RJ = { ln = -0.3 }, RH = { r = -0.45 }, LH = { r = -0.45 } })
	table.insert(f, { t = 0.92, RS = { p = 1.55, r = -1.3 }, LS = { p = 1.55, r = -1.3 }, RJ = { ln = -0.25 }, RH = { r = -0.4 }, LH = { r = -0.4 } })
	table.insert(f, { t = 1.06 })
	return f
end

M.Anims = {
	BarExpress = { -- accroupi, pichet tendu en arrière comme un réacteur, puis fusée penchée et freinage
		{ t = 0 },
		{ t = 0.1, RS = { p = -1.3, r = -0.2 }, LS = { p = -1.3, r = -0.2 }, RJ = { ln = 0.75 }, RH = { p = 0.95 }, LH = { p = -0.5 } },
		{ t = 0.16, RS = { p = -1.65 }, LS = { p = 1.65, y = 0.3 }, RJ = { ln = 0.9, tw = 0.15 }, RH = { p = -0.85 }, LH = { p = 1.05 } },
		{ t = 0.32, RS = { p = -1.6 }, LS = { p = 1.6, y = 0.3 }, RJ = { ln = 0.85, tw = 0.12 }, RH = { p = 1.0 }, LH = { p = -0.8 } },
		{ t = 0.48, RS = { p = -1.55 }, LS = { p = 1.55, y = 0.3 }, RJ = { ln = 0.8, tw = 0.1 }, RH = { p = -0.8 }, LH = { p = 1.0 } },
		{ t = 0.6, RS = { p = 0.7 }, LS = { p = 0.5 }, RJ = { ln = -0.3 }, RH = { p = -0.35 }, LH = { p = 0.6 } },
		{ t = 0.78 },
	},
	BarBeans = { -- main dans le sac, armé en travers du buste, grand revers qui évente les grains
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.2, y = 1.3 }, RJ = { tw = 0.75, ln = 0.1 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.14, RS = { p = 1.3, y = 1.45, r = 0.2 }, RJ = { tw = 0.85, ln = 0.15 }, RH = { p = 0.35 }, LH = { p = -0.2 } },
		{ t = 0.22, RS = { p = 1.65, y = -1.25, r = -0.45 }, LS = { p = -0.45 }, RJ = { tw = -0.8, ln = 0.25 }, LH = { p = 0.65 }, RH = { p = -0.4 } },
		{ t = 0.42, RS = { p = 1.5, y = -1.1, r = -0.4 }, LS = { p = -0.4 }, RJ = { tw = -0.65, ln = 0.2 }, LH = { p = 0.5 }, RH = { p = -0.3 } },
		{ t = 0.56 },
	},
	BarLatte = { -- pot de lait levé, verse en dessinant un cœur, puis petite fierté bras en l'air
		{ t = 0 },
		{ t = 0.12, RS = { p = 2.6, y = 0.3 }, LS = { p = 1.0, y = 0.6 }, RJ = { ln = -0.25 } },
		{ t = 0.3, RS = { p = 1.9, y = 0.6, r = -0.3 }, LS = { p = 1.2, y = 0.6 }, RJ = { ln = 0.45 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
		{ t = 0.45, RS = { p = 1.7, y = -0.4, r = -0.1 }, LS = { p = 1.2, y = 0.6 }, RJ = { ln = 0.5, tw = -0.18 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
		{ t = 0.6, RS = { p = 1.9, y = 0.6, r = -0.3 }, LS = { p = 1.2, y = 0.6 }, RJ = { ln = 0.5, tw = 0.18 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
		{ t = 0.74, RS = { p = 1.45 }, LS = { p = 1.1, y = 0.6 }, RJ = { ln = 0.6 }, RH = { p = -0.35 }, LH = { p = 0.55 } },
		{ t = 0.84, RS = { p = 2.6 }, LS = { p = 0.3, r = -0.8 }, RJ = { ln = -0.25 } },
		{ t = 1.0 },
	},
	BarSmash = { -- accroupi, bond bras au-dessus de la tête, genoux rentrés, écrase le portafilter à deux mains
		{ t = 0 },
		{ t = 0.22, RS = { p = -0.8 }, LS = { p = -0.8 }, RJ = { ln = 0.65 }, RH = { p = 1.0 }, LH = { p = 1.0 } },
		{ t = 0.34, RS = { p = 3.3, y = 0.15 }, LS = { p = 3.2, y = 0.15 }, RJ = { ln = -0.5 }, RH = { p = 0.9 }, LH = { p = 0.3 } },
		{ t = 0.6, RS = { p = 3.4 }, LS = { p = 3.35 }, RJ = { ln = -0.65 }, RH = { p = 1.3 }, LH = { p = 1.1 } },
		{ t = 0.7, RS = { p = 0.7, y = 0.2 }, LS = { p = 0.7, y = 0.2 }, RJ = { ln = 1.0 }, RH = { p = 1.15 }, LH = { p = -0.45 } },
		{ t = 1.0, RS = { p = 0.75, y = 0.2 }, LS = { p = 0.75, y = 0.2 }, RJ = { ln = 0.9 }, RH = { p = 1.05 }, LH = { p = -0.4 } },
		{ t = 1.15 },
	},
	BarToGo = toGoAnim(), -- saisie à deux mains, gobelet soulevé et secoué, gros lancer
	BarChug = chugAnim(), -- boit le venti tête en arrière, tremble, explose bras écartés
}

------------------------------------------------------------------------
-- Accessoires de main (repère bras droit : main en (0,-1,0), -Y = prolongement du bras)
------------------------------------------------------------------------
M.Props = {
	BarPitcher = { -- pichet à lait en inox (réacteur de la ruée)
		{ Vector3.new(1.1, 0.95, 0.95), CFrame.new(0, -1.65, 0) * ALONG_Y, STEEL, CYL },
		{ Vector3.new(0.12, 1.0, 1.0), CFrame.new(0, -2.15, 0) * ALONG_Y, Color3.fromRGB(170, 175, 185), CYL },
		{ Vector3.new(0.35, 0.3, 0.55), CFrame.new(0, -2.15, -0.6), STEEL },
		{ Vector3.new(0.16, 0.75, 0.16), CFrame.new(0, -1.65, 0.6), DARKC },
	},
	BarBeanBag = { -- sac de toile plein de grains
		{ Vector3.new(1.15, 1.25, 1.15), CFrame.new(0, -1.75, 0), BURLAP },
		{ Vector3.new(0.7, 0.3, 0.7), CFrame.new(0, -1.05, 0), Color3.fromRGB(160, 130, 85) },
		{ Vector3.new(0.4, 0.3, 0.4), CFrame.new(-0.25, -2.45, -0.3), DARKC, BALL },
		{ Vector3.new(0.4, 0.3, 0.4), CFrame.new(0.2, -2.5, -0.15), DARKC, BALL },
		{ Vector3.new(0.5, 0.06, 0.5), CFrame.new(0, -1.75, -0.6) * CFrame.Angles(math.pi / 2, 0, 0), BREW },
	},
	BarJug = { -- gros pot à lait en céramique blanche, mousse au bord
		{ Vector3.new(1.5, 1.35, 1.35), CFrame.new(0, -1.85, 0) * ALONG_Y, WHITE, CYL },
		{ Vector3.new(0.12, 1.2, 1.2), CFrame.new(0, -2.62, 0) * ALONG_Y, FOAM, CYL },
		{ Vector3.new(0.4, 0.35, 0.7), CFrame.new(0, -2.5, -0.75), WHITE },
		{ Vector3.new(0.18, 0.9, 0.18), CFrame.new(0, -1.85, 0.75), CARAMEL },
	},
	BarPortafilter = { -- portafilter GÉANT : manche noir, panier inox, galète de café
		{ Vector3.new(1.8, 0.45, 0.45), CFrame.new(0, -1.9, 0) * ALONG_Y, DARKC, CYL },
		{ Vector3.new(0.5, 0.55, 0.55), CFrame.new(0, -1.05, 0) * ALONG_Y, STEEL, CYL },
		{ Vector3.new(0.9, 2.6, 2.6), CFrame.new(0, -3.4, 0) * ALONG_Y, STEEL, CYL },
		{ Vector3.new(0.12, 2.3, 2.3), CFrame.new(0, -3.88, 0) * ALONG_Y, DARKC, CYL },
		{ Vector3.new(0.3, 0.5, 0.5), CFrame.new(0, -3.9, 1.1) * ALONG_Y, STEEL, CYL },
	},
	BarVenti = { -- gobelet venti avec manchon, couvercle et paille
		{ Vector3.new(2.0, 1.05, 1.05), CFrame.new(0, -1.85, -0.1) * ALONG_Y, WHITE, CYL },
		{ Vector3.new(0.7, 1.1, 1.1), CFrame.new(0, -1.75, -0.1) * ALONG_Y, CARAMEL, CYL },
		{ Vector3.new(0.2, 1.12, 1.12), CFrame.new(0, -2.85, -0.1) * ALONG_Y, BREW, CYL },
		{ Vector3.new(0.12, 1.1, 0.12), CFrame.new(0.15, -3.4, -0.1), Color3.fromRGB(80, 200, 120) },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents : bonnet, moustache, tablier, badge, grain de café ; portafilter à la main droite
------------------------------------------------------------------------
function M.Identity(f, head, torso, c, prop)
	prop(f, head, Vector3.new(0.75, 1.3, 1.3), CFrame.new(0, 0.55, 0.02) * UP, BREW, CYL) -- bonnet
	prop(f, head, Vector3.new(0.25, 1.36, 1.36), CFrame.new(0, 0.3, 0.02) * UP, CREAM, CYL) -- rebord
	prop(f, head, Vector3.new(0.45, 0.45, 0.45), CFrame.new(0, 1.0, 0.02), CREAM, BALL) -- pompon
	prop(f, head, Vector3.new(0.75, 0.16, 0.1), CFrame.new(0, -0.17, -0.6), DARKC) -- moustache
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.18, 0.18, 0.1), CFrame.new(0.4 * s, -0.12, -0.6) * CFrame.Angles(0, 0, 0.5 * s), DARKC) -- pointes recourbées
		prop(f, torso, Vector3.new(0.14, 1.3, 0.06), CFrame.new(0.55 * s, 0.4, -0.54), DARKC) -- bretelles du tablier
	end
	prop(f, torso, Vector3.new(1.75, 1.35, 0.1), CFrame.new(0, -0.35, -0.56), Color3.fromRGB(75, 50, 35)) -- tablier
	prop(f, torso, Vector3.new(0.9, 0.45, 0.06), CFrame.new(0, -0.55, -0.62), Color3.fromRGB(95, 65, 45)) -- poche
	prop(f, torso, Vector3.new(0.55, 0.3, 0.06), CFrame.new(-0.45, 0.55, -0.56), WHITE) -- badge
	prop(f, torso, Vector3.new(0.3, 0.42, 0.1), CFrame.new(0.5, 0.0, -0.62) * CFrame.Angles(0, 0, 0.4), BREW, BALL) -- grain de café brodé
end

M.Signature = { Hand = "Right", Build = function(f, a, prop) -- portafilter à la main
	prop(f, a, Vector3.new(0.3, 0.3, 1.2), CFrame.new(0, -1.05, -0.6), DARKC)
	prop(f, a, Vector3.new(0.35, 1.0, 1.0), CFrame.new(0, -1.05, -1.55) * UP, STEEL, CYL)
	prop(f, a, Vector3.new(0.06, 0.82, 0.82), CFrame.new(0, -0.86, -1.55) * UP, DARKC, CYL)
end }

-- Transformation : gobelet géant fumant sur la tête, réservoirs d'espresso dans le dos, yeux écarquillés
function M.Transform(f, head, torso, c, prop)
	prop(f, head, Vector3.new(1.9, 1.2, 1.2), CFrame.new(0, 1.45, 0) * UP, WHITE, CYL)
	prop(f, head, Vector3.new(0.7, 1.25, 1.25), CFrame.new(0, 1.3, 0) * UP, CARAMEL, CYL)
	prop(f, head, Vector3.new(0.25, 1.3, 1.3), CFrame.new(0, 2.45, 0) * UP, BREW, CYL)
	prop(f, head, Vector3.new(1.0, 0.85, 0.85), CFrame.new(0, 2.85, 0), FOAM, BALL) -- chantilly
	prop(f, head, Vector3.new(0.12, 1.2, 0.12), CFrame.new(0.25, 3.2, 0) * CFrame.Angles(0, 0, -0.25), Color3.fromRGB(80, 200, 120)) -- paille
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.3, 0.3, 0.06), CFrame.new(0.22 * s, 0.15, -0.62), Color3.fromRGB(255, 255, 255)) -- yeux écarquillés
		prop(f, head, Vector3.new(0.12, 0.12, 0.07), CFrame.new(0.22 * s, 0.15, -0.64), DARKC)
		local tank = prop(f, torso, Vector3.new(1.8, 0.7, 0.7), CFrame.new(0.45 * s, 0.1, 0.85) * UP, STEEL, CYL) -- réservoirs
		tank.Material = Enum.Material.SmoothPlastic
		prop(f, torso, Vector3.new(0.3, 0.75, 0.75), CFrame.new(0.45 * s, 1.05, 0.85) * UP, BREW, CYL)
		prop(f, torso, Vector3.new(0.12, 0.9, 0.12), CFrame.new(0.45 * s, 1.5, 0.85), DARKC) -- cheminées
	end
end

------------------------------------------------------------------------
-- Serveur
------------------------------------------------------------------------
local function ready(attacker, api)
	return api.CharacterState.isAlive(attacker) and not api.CharacterState.isStunned(attacker)
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

M.Kinds = {
	-- Espresso Express : ruée vapeur qui traverse tout le monde
	BarSteamDash = function(attacker, cfg, aim, api)
		local dir = Kit.aimDir(attacker, aim)
		task.wait(cfg.Windup)
		if not ready(attacker, api) then
			return
		end
		Kit.fx({ id = "BarSteam", a = attacker, dur = cfg.Time })
		local hitSet = {}
		Kit.dash(attacker, dir, cfg.Speed, cfg.Time, function(root)
			for _, v in ipairs(api.Hitbox.box(root.CFrame * CFrame.new(0, 0, -2), cfg.HitboxSize, attacker, 4)) do
				if not hitSet[v] then
					hitSet[v] = true
					api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - root.Position, dir))
				end
			end
			return not api.CharacterState.isAlive(attacker)
		end)
	end,

	-- Bean Barrage : éventail de grains qui rebondissent une fois sur les murs
	BarBeans = function(attacker, cfg, aim, api)
		task.wait(0.18)
		if not ready(attacker, api) then
			return
		end
		local root = Kit.root(attacker)
		local base = Kit.aimDir(attacker, aim)
		for i = 1, cfg.Count do
			local a = math.rad(-cfg.Spread / 2 + cfg.Spread * (i - 1) / (cfg.Count - 1))
			local dir = CFrame.Angles(0, a, 0) * base
			Kit.projectile(attacker, {
				origin = root.Position + Vector3.new(0, 1, 0) + dir * 2, dir = dir, speed = cfg.Speed * Kit.rng:NextNumber(0.9, 1.1), range = cfg.Range,
				size = Vector3.new(0.75, 0.55, 1.05), color = BREW, shape = BALL, bounces = 1, spin = 25,
				decorate = function(part)
					decor(part, Vector3.new(0.12, 0.57, 0.85), CFrame.new(), DARKC) -- la fente du grain
				end,
				onHit = function(v, pos, vel)
					api.hit(attacker, v, cfg, api.flat(vel, base), { hitPos = pos })
				end,
			})
		end
	end,

	-- Latte Art : cœur de mousse au sol (ralentit + petits dégâts à chaque tick)
	BarLatte = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local center = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 2))
		Kit.fx({ id = "Telegraph", p = center, r = cfg.Radius, dur = 0.35, a = attacker })
		Kit.fx({ id = "BarLatte", p = center, r = cfg.Radius, dur = cfg.LatteTime, look = dir, a = attacker })
		task.wait(0.35)
		local t0 = os.clock()
		local first = {}
		while os.clock() - t0 < cfg.LatteTime do
			for _, v in ipairs(Kit.inCircle(attacker, center, cfg.Radius, 6)) do
				local over = first[v] and { Words = { "FROTH!", "FOAM!" }, Power = 0.12 } or nil
				first[v] = true
				if api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - center, dir), over) == "Hit" then
					api.CharacterState.setSpeedMod(v, "BarFoam", cfg.SlowMult, cfg.Tick + 0.35)
				end
			end
			task.wait(cfg.Tick)
		end
	end,

	-- Portafilter Smash : bond sur la zone visée, tout le monde dessous est PLAQUÉ
	BarLeap = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local dest = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 3))
		Kit.fx({ id = "Telegraph", p = dest, r = cfg.Radius, dur = cfg.Windup + cfg.Rise + 0.12, a = attacker })
		task.wait(cfg.Windup)
		if not ready(attacker, api) then
			return
		end
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
		Kit.fx({ id = "BarLeap", a = attacker, dur = cfg.Rise + 0.25 })
		Kit.leap(attacker, dest, cfg.Up, cfg.Rise)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local land = Kit.ground(root.Position)
		Kit.fx({ id = "BarTamp", p = land, r = cfg.Radius, a = attacker, look = dir })
		for _, v in ipairs(Kit.inCircle(attacker, land, cfg.Radius, 8)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - land, dir))
		end
		api.ZoneService.shatterAround(land, cfg.Radius * 0.6, Vector3.new(0, 30, 0))
	end,

	-- To-Go Order : saisie, la victime est enfermée dans un gobelet géant secoué, puis lancée
	BarToGo = function(attacker, cfg, aim, api)
		task.wait(0.12)
		if not ready(attacker, api) then
			return
		end
		local root = Kit.root(attacker)
		local victim = api.Hitbox.box(root.CFrame * CFrame.new(0, 0, -cfg.HitboxOffset), cfg.HitboxSize, attacker, 1)[1]
		if not victim or Kit.isProtected(victim) then
			return
		end
		local vh = victim:FindFirstChildOfClass("Humanoid")
		api.CharacterState.stun(victim, cfg.HoldTime + 0.5)
		local release = Kit.holdAt(victim, attacker, Vector3.new(0, 2.5, -3.2))
		Kit.fx({ id = "BarCup", a = attacker, v = victim, dur = cfg.HoldTime })
		task.wait(cfg.HoldTime)
		release(true)
		if api.CharacterState.isAlive(victim) and api.CharacterState.isAlive(attacker) then
			api.hit(attacker, victim, cfg, root.CFrame.LookVector, { Knockback = cfg.ThrowKnockback, KnockUp = cfg.ThrowUp })
		end
		task.delay(0.6, function()
			if vh and vh.Parent and vh.Health > 0 and not api.CharacterState.isStunned(victim) then
				vh.PlatformStand = false
			end
		end)
	end,

	-- Caffeine Overload : explosion de vapeur, puis buff (vitesse + coups brûlants, voir ServerInit)
	BarOverload = function(attacker, cfg, aim, api)
		task.wait(0.62)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local root = Kit.root(attacker)
		attacker:SetAttribute("BarOverloadUntil", api.now() + cfg.BuffTime)
		api.CharacterState.setSpeedMod(attacker, "BarOverload", cfg.SpeedMultiplier, cfg.BuffTime)
		Kit.fx({ id = "BarBurst", a = attacker, p = root.Position, r = cfg.Radius })
		for _, v in ipairs(Kit.inCircle(attacker, root.Position, cfg.Radius, 7)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - root.Position, root.CFrame.LookVector))
		end
	end,
}

------------------------------------------------------------------------
-- Passif (serveur) : Extra Shot (chaque 4e coup +4) ; Caffeine Overload (coups brûlants)
------------------------------------------------------------------------
function M.ServerInit(api)
	table.insert(api.CombatService.damageMods, function(p)
		local a = p.attacker
		if not a or a:GetAttribute("CharacterName") ~= "Barista" or (p.damage or 0) <= 0 then
			return
		end
		if p.weapon == "Latte Art" then -- les ticks de la zone ne comptent pas pour l'Extra Shot
			return
		end
		local n = (a:GetAttribute("BarShots") or 0) + 1
		if n >= 4 then
			n = 0
			p.damage += 4
			p.power = (p.power or 0.5) + 0.25
			p.words = { "EXTRA SHOT!" }
			local vr = Kit.root(p.victim)
			if vr then
				Kit.fx({ id = "BarExtra", p = vr.Position })
			end
		end
		a:SetAttribute("BarShots", n)
		-- Caffeine Overload : chaque coup brûle (sauf l'explosion elle-même)
		if (a:GetAttribute("BarOverloadUntil") or 0) > workspace:GetServerTimeNow() and p.weapon ~= "Caffeine Overload" then
			local v = p.victim
			if (v:GetAttribute("BarScaldUntil") or 0) < workspace:GetServerTimeNow() then
				v:SetAttribute("BarScaldUntil", workspace:GetServerTimeNow() + 1)
				api.CombatService.burn(v, a, { Ticks = 2, Damage = 2, Interval = 0.4 })
			end
		end
	end)
end

------------------------------------------------------------------------
-- Effets client
------------------------------------------------------------------------
local function puff(pos, size, life, rise, color)
	local b = Kit.part({ Shape = BALL, Size = Vector3.one * size, Position = pos, Color = color or STEAM, Transparency = 0.25 })
	Kit.tween(b, life, { Position = pos + Vector3.new(0, rise, 0), Size = Vector3.one * size * 2.2, Transparency = 1 })
	game:GetService("Debris"):AddItem(b, life + 0.05)
	return b
end

M.MoveFX = {
	EspressoExpress = function(c, d, api)
		task.delay(0.12, function()
			api.afterimages(c, 0.38, BREW)
			if Kit.mine(c) then
				api.CartoonFX.speedLines(0.4, CREAM)
			end
		end)
	end,
	BeanBarrage = function(c, d, api)
		task.delay(0.18, function()
			local arm = c:FindFirstChild("Right Arm")
			if arm then
				local pos = arm.Position - arm.CFrame.UpVector * 1.4
				api.CartoonFX.shards(pos, 10, { BREW, DARKC, CARAMEL }, 0.9)
				Kit.floatText(pos + Vector3.new(0, 1.5, 0), "FRESH ROAST!", CARAMEL, 2.4, 0.6, 1.5)
			end
		end)
	end,
	LatteArt = function(c, d, api)
		-- filet de lait versé depuis le pot
		task.spawn(function()
			for _ = 1, 14 do
				local arm = c:FindFirstChild("Right Arm")
				if not arm then
					return
				end
				local pos = (arm.CFrame * CFrame.new(0, -2.6, -0.8)).Position
				local drop = Kit.part({ Shape = BALL, Size = Vector3.one * 0.45, Position = pos, Color = FOAM })
				Kit.tween(drop, 0.3, { Position = pos + Vector3.new(0, -3, 0) + (c.HumanoidRootPart.CFrame.LookVector * 2), Size = Vector3.one * 0.7, Transparency = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				api.Debris:AddItem(drop, 0.32)
				task.wait(0.05)
			end
		end)
	end,
	PortafilterSmash = function(c, d, api)
		task.delay(0.25, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.puff(r.Position - Vector3.new(0, 2.6, 0), 1.2)
				api.rings(c, 1, 6, CREAM, -2.6)
			end
		end)
	end,
	ToGoOrder = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 4.5, 0), "ONE TO GO!", CARAMEL, 2.6, 0.8, 1)
		end
	end,
	CaffeineOverload = function(c, d, api)
		task.delay(0.42, function()
			api.afterimages(c, 0.25, CARAMEL)
		end)
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	local RunService = game:GetService("RunService")
	local Debris = game:GetService("Debris")
	Kit.setupClient()

	-- nuages de vapeur tout au long de la ruée
	Kit.on("BarSteam", function(d)
		local c = d.a
		local r0 = c and c:FindFirstChild("HumanoidRootPart")
		if r0 then
			CartoonFX.sound("Spray", r0.Position, 1)
			CartoonFX.shockwave(r0.Position - Vector3.new(0, 2.7, 0), 7, CREAM)
		end
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < d.dur + 0.1 do
				local r = c and c:FindFirstChild("HumanoidRootPart")
				if not r then
					return
				end
				local back = r.Position - r.CFrame.LookVector * 2 + Vector3.new(Kit.rng:NextNumber(-0.8, 0.8), Kit.rng:NextNumber(-1.5, 0.8), 0)
				puff(back, Kit.rng:NextNumber(1.2, 2), 0.7, 2.5)
				if Kit.rng:NextNumber() < 0.5 then
					puff(back, 0.6, 0.5, 1, BREW)
				end
				task.wait(0.03)
			end
		end)
	end)

	-- cœur de latte art géant
	Kit.on("BarLatte", function(d)
		local look = d.look or Vector3.new(0, 0, -1)
		local base = CFrame.lookAt(d.p, d.p + look)
		local parts = {}
		local function add(p)
			table.insert(parts, p)
			return p
		end
		local r = d.r
		local disc = add(Kit.part({ Shape = CYL, Size = Vector3.new(0.1, 0.5, 0.5), CFrame = CFrame.new(d.p + Vector3.new(0, 0.08, 0)) * UP, Color = CARAMEL }))
		local rim = add(Kit.part({ Shape = CYL, Size = Vector3.new(0.09, 0.6, 0.6), CFrame = CFrame.new(d.p + Vector3.new(0, 0.06, 0)) * UP, Color = BREW }))
		Kit.tween(disc, 0.35, { Size = Vector3.new(0.1, r * 2, r * 2) }, Enum.EasingStyle.Back)
		Kit.tween(rim, 0.35, { Size = Vector3.new(0.09, r * 2 + 1.2, r * 2 + 1.2) }, Enum.EasingStyle.Back)
		task.delay(0.25, function()
			-- le cœur : deux lobes + une pointe (carré tourné à 45°)
			local s = r * 0.5
			for _, x in ipairs({ -1, 1 }) do
				local lobe = add(Kit.part({ Shape = CYL, Size = Vector3.new(0.1, 0.2, 0.2), CFrame = base * CFrame.new(x * s * 0.42, 0.13, -s * 0.25) * UP, Color = FOAM }))
				Kit.tween(lobe, 0.3, { Size = Vector3.new(0.1, s, s) }, Enum.EasingStyle.Back)
			end
			local tip = add(Kit.part({ Size = Vector3.new(0.2, 0.1, 0.2), CFrame = base * CFrame.new(0, 0.12, s * 0.22) * CFrame.Angles(0, math.rad(45), 0), Color = FOAM }))
			Kit.tween(tip, 0.3, { Size = Vector3.new(s * 0.72, 0.1, s * 0.72) }, Enum.EasingStyle.Back)
			CartoonFX.sound("Splat", d.p, 0.8)
			CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), r, FOAM)
		end)
		Kit.floatText(d.p + Vector3.new(0, 4, 0), "LATTE ART!", CREAM, 3.2, 1, 1.5)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < d.dur do
				local a, rr = Kit.rng:NextNumber(0, math.pi * 2), Kit.rng:NextNumber(0, r)
				puff(d.p + Vector3.new(math.cos(a) * rr, 0.4, math.sin(a) * rr), Kit.rng:NextNumber(0.4, 0.9), 0.9, 1.6, Kit.rng:NextNumber() < 0.7 and FOAM or CREAM)
				task.wait(0.05)
			end
			for _, p in ipairs(parts) do
				Kit.tween(p, 0.35, { Transparency = 1 })
			end
		end)
		for _, p in ipairs(parts) do
			Debris:AddItem(p, d.dur + 0.45)
		end
		task.delay(0.6, function()
			for _, p in ipairs(parts) do
				Debris:AddItem(p, d.dur)
			end
		end)
	end)

	-- traînée pendant le bond
	Kit.on("BarLeap", function(d)
		local c = d.a
		if not c then
			return
		end
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			CartoonFX.sound("Whoosh", r.Position, 1)
		end
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < d.dur do
				local rr = c:FindFirstChild("HumanoidRootPart")
				if not rr then
					return
				end
				puff(rr.Position - Vector3.new(0, 1, 0), 1.1, 0.5, 1)
				task.wait(0.03)
			end
		end)
	end)

	-- impact du portafilter : onde de choc, marc de café, empreinte de la galète
	Kit.on("BarTamp", function(d)
		CartoonFX.sound("GroundSlam", d.p, 1.3)
		CartoonFX.sound("BigImpact", d.p, 1)
		CartoonFX.bigImpact(d.p + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.3, BREW)
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r * 1.2, BREW)
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.3, 0), d.r * 0.7, CREAM)
		Kit.cubes(d.p + Vector3.new(0, 0.8, 0), 26, { DARKC, BREW, CARAMEL }, 0.6, 12, 0.6)
		local print_ = Kit.part({ Shape = CYL, Size = Vector3.new(0.1, d.r * 1.3, d.r * 1.3), CFrame = CFrame.new(d.p + Vector3.new(0, 0.07, 0)) * UP, Color = DARKC, Transparency = 0.1 })
		local ring = Kit.part({ Shape = CYL, Size = Vector3.new(0.08, d.r * 1.5, d.r * 1.5), CFrame = CFrame.new(d.p + Vector3.new(0, 0.05, 0)) * UP, Color = STEEL, Transparency = 0.1 })
		task.delay(0.9, function()
			Kit.tween(print_, 0.5, { Transparency = 1 })
			Kit.tween(ring, 0.5, { Transparency = 1 })
		end)
		Debris:AddItem(print_, 1.45)
		Debris:AddItem(ring, 1.45)
		Kit.floatText(d.p + Vector3.new(0, 4, 0), "TAMPED!", CARAMEL, 4, 1, 2)
		if Kit.mine(d.a) then
			CartoonFX.shake(1)
			CartoonFX.impactFrame(0.8)
		end
	end)

	-- gobelet géant autour de la victime (couvercle, chantilly, paille) qui tremble, puis éclate
	Kit.on("BarCup", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		CartoonFX.sound("Pickup", vr.Position, 1)
		local cup = Kit.part({ Shape = CYL, Size = Vector3.new(6.2, 4.6, 4.6), Color = WHITE, Transparency = 0.25 })
		local sleeve = Kit.part({ Shape = CYL, Size = Vector3.new(2.2, 4.75, 4.75), Color = CARAMEL })
		local lid = Kit.part({ Shape = CYL, Size = Vector3.new(0.6, 4.9, 4.9), Color = BREW })
		local cream = Kit.part({ Shape = BALL, Size = Vector3.new(3.2, 3.2, 3.2), Color = FOAM })
		local straw = Kit.part({ Size = Vector3.new(0.35, 3.4, 0.35), Color = Color3.fromRGB(80, 200, 120) })
		local label = Kit.part({ Size = Vector3.new(2.6, 1.1, 0.1), Color = WHITE })
		Kit.flatText(label, "TO GO", BREW, Enum.NormalId.Front)
		local parts = { cup, sleeve, lid, cream, straw, label }
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			if el > d.dur or not vr.Parent then
				conn:Disconnect()
				for _, p in ipairs(parts) do
					p:Destroy()
				end
				if vr.Parent then
					Kit.cubes(vr.Position, 22, { WHITE, CARAMEL, BREW, FOAM }, 0.8, 10, 0.5)
					CartoonFX.sound("Splat", vr.Position, 1)
					Kit.floatText(vr.Position + Vector3.new(0, 3, 0), "ORDER UP!", CARAMEL, 3, 0.8, 2)
				end
				return
			end
			local shake = math.sin(el * 40) * 0.25
			local base = CFrame.new(vr.Position) * CFrame.Angles(0, 0, shake)
			cup.CFrame = base * CFrame.new(0, -0.3, 0) * UP
			sleeve.CFrame = base * CFrame.new(0, -0.6, 0) * UP
			lid.CFrame = base * CFrame.new(0, 2.9, 0) * UP
			cream.CFrame = base * CFrame.new(0, 3.5, 0)
			straw.CFrame = base * CFrame.new(0.8, 4.8, 0) * CFrame.Angles(0, 0, -0.3)
			label.CFrame = base * CFrame.new(0, -0.6, -2.42)
		end)
	end)

	-- explosion de vapeur du Caffeine Overload
	Kit.on("BarBurst", function(d)
		CartoonFX.sound("Spray", d.p, 1.2)
		CartoonFX.shockwave(d.p - Vector3.new(0, 2.7, 0), d.r, CARAMEL)
		CartoonFX.shockwave(d.p - Vector3.new(0, 2.5, 0), d.r * 0.6, STEAM)
		for i = 1, 12 do
			local a = i / 12 * math.pi * 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local b = Kit.part({ Shape = BALL, Size = Vector3.one * 1.6, Position = d.p + dir * 1.5, Color = STEAM, Transparency = 0.2 })
			Kit.tween(b, 0.45, { Position = d.p + dir * d.r + Vector3.new(0, 1, 0), Size = Vector3.one * 3.5, Transparency = 1 })
			Debris:AddItem(b, 0.47)
		end
		Kit.floatText(d.p + Vector3.new(0, 4, 0), "OVERLOAD!", CARAMEL, 3.4, 0.9, 2)
		if Kit.mine(d.a) then
			CartoonFX.shake(0.5)
			CartoonFX.fovKick(8)
		end
	end)

	Kit.on("BarExtra", function(d)
		Kit.floatText(d.p + Vector3.new(0, 2.5, 0), "EXTRA SHOT!", CARAMEL, 2.8, 0.8, 2)
		CartoonFX.sparks(d.p, 12, BREW)
		puff(d.p + Vector3.new(0, 1, 0), 1.4, 0.6, 2)
	end)

	-- auras : vapeur qui monte du gobelet (transformation), tremblote de caféine (Overload)
	task.spawn(function()
		while true do
			task.wait(0.18)
			local now = workspace:GetServerTimeNow()
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "Barista" then
					local r = c:FindFirstChild("HumanoidRootPart")
					local head = c:FindFirstChild("Head")
					if r and head and c:GetAttribute("Transformed") and Kit.rng:NextNumber() < 0.6 then
						puff(head.Position + Vector3.new(Kit.rng:NextNumber(-0.4, 0.4), 3.4, Kit.rng:NextNumber(-0.4, 0.4)), 0.7, 0.9, 2.5)
					end
					if r and (c:GetAttribute("BarOverloadUntil") or 0) > now then
						local off = Vector3.new(Kit.rng:NextNumber(-1.5, 1.5), Kit.rng:NextNumber(-2, 1.5), Kit.rng:NextNumber(-1.5, 1.5))
						puff(r.Position + off, 0.5, 0.4, 1, Kit.rng:NextNumber() < 0.5 and CARAMEL or BREW)
					end
				end
			end
		end
	end)
end

return M
