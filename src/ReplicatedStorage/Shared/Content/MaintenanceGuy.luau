--[[
	The Maintenance Guy — personnage complet (format : voir Modules/ContentLoader).
	Passif « Duct Tape Fix » : sous 35 % de vie, il se rafistole au scotch (+20 PV), une fois toutes les 40 s.
	Attaques : Monkey Wrench (clé géante qui plaque au sol), Fuse Box (boîte à fusibles qui électrocute), Duct Tape (rouleau qui rebondit et ralentit).
	Transformation Building Super : Ladder Spin (toupie à l'échelle), Short Circuit (onde électrique au sol), Toolbox Drop (caisse à outils géante qui plaque au sol).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT

local HIVIS = Color3.fromRGB(210, 245, 25)
local STEEL = Color3.fromRGB(175, 180, 190)
local DARK = Color3.fromRGB(35, 38, 45)
local ORANGE = Color3.fromRGB(255, 130, 20)
local RED = Color3.fromRGB(215, 40, 35)
local BROWN = Color3.fromRGB(115, 75, 40)
local SPARK = Color3.fromRGB(120, 220, 255)
local SPARKS = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 240, 90) }
local TAPE = Color3.fromRGB(165, 170, 178)
local TOOLS = { STEEL, RED, HIVIS, DARK, Color3.fromRGB(255, 200, 40) }

local M = { Id = "MaintenanceGuy", Order = 13 }

M.Character = {
	DisplayName = "The Maintenance Guy",
	Role = "Handy bruiser",
	Color = HIVIS,
	Shirt = Color3.fromRGB(70, 95, 130), Pants = Color3.fromRGB(50, 65, 90), Tie = HIVIS,
	Passive = { Name = "Duct Tape Fix", Desc = "Below 35% health he tapes himself back together and heals 20 HP (once every 40 s)." },
	Attacks = { "MonkeyWrench", "FuseBox", "DuctTape" },
	Transformation = { Name = "Building Super", Desc = "Hard hat with a flashing beacon, glowing hi-vis vest and caution tape.", Duration = 20, SpeedMultiplier = 1.15 },
	TransAttacks = { "LadderSpin", "ShortCircuit", "ToolboxDrop" },
}

M.Attacks = {
	MonkeyWrench = { Name = "Monkey Wrench", Kind = "Melee", Desc = "Wind up your giant wrench and bring it down two-handed: pins the coworker in front to the floor.", Prop = "MGWrench", Cooldown = 7, Anim = "MGWrench", Sound = "Clang",
		Windup = 0.32, HitboxOffset = 3.5, HitboxSize = Vector3.new(6, 7, 7.5), Material = "Metal",
		Damage = 12, Knockback = 0, KnockUp = 0, Stun = 1.2, Category = "Heavy", Power = 1.0, Words = { "BONK!", "TIGHTENED!", "CLANG!" }, Effects = { Pin = true } },
	FuseBox = { Name = "Fuse Box", Kind = "MGFuseBox", Desc = "Plant a live fuse box: for 5 s it zaps the closest coworker nearby with lightning.", Cooldown = 14, Anim = "MGFuseBox", Sound = "Electric",
		Windup = 0.3, Offset = 4, Life = 5, Interval = 0.75, Range = 17, Damage = 2.5, Knockback = 6, KnockUp = 4, Stun = 0.45, Category = "Light", Power = 0.35, Words = { "ZAP!", "BZZT!" } },
	DuctTape = { Name = "Duct Tape", Kind = "MGDuctTape", Desc = "Hurl a roll of duct tape that bounces off walls and tapes up the first coworker it hits (big slow).", Prop = "MGTapeRoll", Cooldown = 8, Anim = "MGDuctTape", Sound = "Throw",
		Windup = 0.3, Speed = 85, Range = 70, Bounces = 2, SlowMult = 0.4, SlowTime = 2.5, Damage = 6, Knockback = 8, KnockUp = 4, Stun = 0.8, Category = "Projectile", Power = 0.5, Words = { "TAPED!", "RRRIP!" } },
	LadderSpin = { Name = "Ladder Spin", Kind = "MGLadderSpin", Desc = "Swing a huge ladder around you twice: the second spin sends everyone flying.", Prop = "MGLadder", Cooldown = 9, Anim = "MGLadderSpin", Sound = "Whoosh",
		Windup = 0.3, Radius = 11, Damage = 6, Knockback = 14, KnockUp = 6, Stun = 0.6, Category = "Light", Power = 0.5, Words = { "WHACK!", "LADDER!" },
		Final = { Damage = 8, Knockback = 52, KnockUp = 20, Stun = 0.9, Category = "Heavy", Power = 1.0, Words = { "TIMBER!", "SPIN CYCLE!" } } },
	ShortCircuit = { Name = "Short Circuit", Kind = "MGShortCircuit", Desc = "Punch the floor and send a surge of electricity racing forward that launches everyone in its path.", Cooldown = 10, Anim = "MGShortCircuit", Sound = "Electric",
		Windup = 0.36, Length = 32, Width = 6, Damage = 9, Knockback = 6, Launch = Vector3.new(6, 46, 0), Stun = 1.0, Category = "Heavy", Power = 0.85, Words = { "SHORT CIRCUIT!", "KZZZT!" } },
	ToolboxDrop = { Name = "Toolbox Drop", Kind = "MGToolbox", Desc = "Call in a giant toolbox from the ceiling: it crushes and pins everyone under it.", Cooldown = 14, Anim = "MGToolbox", Sound = "Crash",
		Windup = 0.55, Offset = 13, Radius = 10, Damage = 14, Knockback = 0, Stun = 1.3, Category = "Heavy", Power = 1.2, Words = { "TOOLBOX!", "CRUNCH!" }, Effects = { Pin = true } },
}

------------------------------------------------------------------------
-- Animations (une par attaque)
------------------------------------------------------------------------
local function spinAnim()
	local f = {
		{ t = 0 },
		{ t = 0.22, RS = { p = 0.55, r = -0.4 }, LS = { p = 0.7, r = -0.2 }, RJ = { tw = -1.3, ln = 0.25 }, RH = { p = 0.45 }, LH = { p = -0.35 } },
	}
	local t = 0.22
	for i = 1, 8 do
		t += 0.07
		local even = i % 2 == 0
		table.insert(f, { t = t, RS = { p = 0.35, r = -1.0 }, LS = { p = 0.55, r = -0.7 }, RJ = { tw = -1.3 + i * (2 * math.pi + 1.3) / 8, ln = 0.12 }, RH = { p = even and 0.45 or -0.25 }, LH = { p = even and -0.25 or 0.45 } })
	end
	-- 4π = même orientation que 0 : on revient à 0 instantanément (pas de dé-rotation visible)
	table.insert(f, { t = t + 0.001, RS = { p = 0.35, r = -1.0 }, LS = { p = 0.55, r = -0.7 }, RJ = { tw = 0, ln = 0.12 } })
	table.insert(f, { t = t + 0.12, RS = { p = 0.6, r = -0.8 }, LS = { p = 0.3, r = -0.5 }, RJ = { tw = 0.15, ln = 0.05 } })
	table.insert(f, { t = t + 0.3 })
	return f
end

M.Anims = {
	MGWrench = { -- clé levée à deux mains loin derrière la tête, puis écrasement de tout le corps
		{ t = 0 },
		{ t = 0.12, RS = { p = 2.6, r = -0.2 }, LS = { p = 2.6, r = -0.2 }, RJ = { ln = -0.3 }, RH = { p = 0.15 }, LH = { p = -0.1 } },
		{ t = 0.3, RS = { p = 3.25, r = -0.1 }, LS = { p = 3.25, r = -0.1 }, RJ = { ln = -0.55, sd = 0.06 }, RH = { p = 0.3 }, LH = { p = -0.25 } },
		{ t = 0.37, RS = { p = 0.75, y = 0.2 }, LS = { p = 0.75, y = 0.2 }, RJ = { ln = 0.95 }, RH = { p = 1.05 }, LH = { p = -0.45 } },
		{ t = 0.62, RS = { p = 0.8, y = 0.2 }, LS = { p = 0.8, y = 0.2 }, RJ = { ln = 0.85 }, RH = { p = 0.95 }, LH = { p = -0.4 } },
		{ t = 0.85 },
	},
	MGFuseBox = { -- pose la boîte en s'accroupissant, puis pouce levé
		{ t = 0 },
		{ t = 0.12, RS = { p = 1.3, y = 0.3 }, LS = { p = 1.3, y = 0.3 }, RJ = { ln = 0.35 }, RH = { p = 0.4 } },
		{ t = 0.3, RS = { p = 0.7 }, LS = { p = 0.7 }, RJ = { ln = 0.95 }, RH = { p = 1.2 }, LH = { p = -0.3 } },
		{ t = 0.45, RS = { p = 0.75 }, LS = { p = 0.75 }, RJ = { ln = 0.9 }, RH = { p = 1.15 }, LH = { p = -0.3 } },
		{ t = 0.6, RS = { p = 2.7, r = -0.25 }, LS = { p = 0.3, r = -0.2 }, RJ = { ln = -0.15, tw = 0.2 } },
		{ t = 0.85, RS = { p = 2.6, r = -0.25 }, RJ = { ln = -0.1, tw = 0.2 } },
		{ t = 1.0 },
	},
	MGDuctTape = { -- déchire un bout de scotch, arme le bras derrière, lancer de frisbee appuyé
		{ t = 0 },
		{ t = 0.08, RS = { p = 1.4, r = -0.7 }, LS = { p = 1.4, r = -0.7 }, RJ = { ln = 0.1 } },
		{ t = 0.15, RS = { p = 1.3, r = 0.1 }, LS = { p = 1.3, r = 0.1 } },
		{ t = 0.26, RS = { p = 1.3, y = -1.4, r = -0.5 }, LS = { p = 0.6, y = 0.6 }, RJ = { tw = -1.0, ln = 0.05 }, RH = { p = -0.2 }, LH = { p = 0.35 } },
		{ t = 0.34, RS = { p = 1.55, y = 1.2 }, LS = { p = -0.4 }, RJ = { tw = 1.0, ln = 0.3 }, RH = { p = 0.55 }, LH = { p = -0.4 } },
		{ t = 0.55, RS = { p = 1.5, y = 1.1 }, LS = { p = -0.35 }, RJ = { tw = 0.85, ln = 0.25 }, RH = { p = 0.5 }, LH = { p = -0.35 } },
		{ t = 0.75 },
	},
	MGLadderSpin = spinAnim(), -- deux tours complets, échelle tendue
	MGShortCircuit = { -- poing levé chargé d'électricité, puis coup de poing dans le sol, un genou à terre
		{ t = 0 },
		{ t = 0.14, RS = { p = 3.0, r = -0.45 }, LS = { p = 0.5, r = -0.4 }, RJ = { ln = -0.35, sd = -0.1 }, RH = { p = 0.2 }, LH = { p = -0.1 } },
		{ t = 0.3, RS = { p = 3.2, r = -0.3 }, LS = { p = 0.6, r = -0.5 }, RJ = { ln = -0.45, sd = -0.12 }, RH = { p = 0.3 } },
		{ t = 0.38, RS = { p = 0.55, y = 0.1 }, LS = { p = -0.5, r = -0.3 }, RJ = { ln = 1.05, sd = 0.1 }, RH = { p = 1.3 }, LH = { p = -0.5 } },
		{ t = 0.75, RS = { p = 0.6, y = 0.1 }, LS = { p = -0.45, r = -0.3 }, RJ = { ln = 1.0, sd = 0.08 }, RH = { p = 1.25 }, LH = { p = -0.45 } },
		{ t = 0.95 },
	},
	MGToolbox = { -- pointe le plafond, puis se protège la tête (« attention en dessous ! »)
		{ t = 0 },
		{ t = 0.15, RS = { p = 3.1, r = -0.15 }, LS = { p = 0.3, r = -0.3 }, RJ = { ln = -0.35, sd = 0.12 }, RH = { p = -0.15 }, LH = { p = 0.15 } },
		{ t = 0.45, RS = { p = 3.15, r = -0.1 }, LS = { p = 0.35, r = -0.3 }, RJ = { ln = -0.4, sd = 0.15 } },
		{ t = 0.55, RS = { p = 2.5, y = -0.9, r = 0.3 }, LS = { p = 2.5, y = -0.9, r = 0.3 }, RJ = { ln = 0.45 }, RH = { p = 0.6 }, LH = { p = 0.2 } },
		{ t = 0.85, RS = { p = 2.4, y = -0.9, r = 0.3 }, LS = { p = 2.4, y = -0.9, r = 0.3 }, RJ = { ln = 0.4 }, RH = { p = 0.55 }, LH = { p = 0.2 } },
		{ t = 1.05 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main (repère bras droit)
------------------------------------------------------------------------
local function ladderProp()
	local list = {
		{ Vector3.new(0.22, 0.22, 8.4), CFrame.new(0.65, -1.1, -4.0), Color3.fromRGB(205, 210, 220) },
		{ Vector3.new(0.22, 0.22, 8.4), CFrame.new(-0.65, -1.1, -4.0), Color3.fromRGB(205, 210, 220) },
		{ Vector3.new(1.6, 0.3, 0.4), CFrame.new(0, -1.1, -8.25), HIVIS },
	}
	for z = -1.4, -7.6, -1.25 do
		table.insert(list, { Vector3.new(1.3, 0.16, 0.16), CFrame.new(0, -1.1, z), Color3.fromRGB(185, 190, 200) })
	end
	return list
end

M.Props = {
	MGWrench = {
		{ Vector3.new(0.46, 0.46, 1.1), CFrame.new(0, -1.1, -0.45), HIVIS }, -- poignée
		{ Vector3.new(0.4, 0.4, 3.6), CFrame.new(0, -1.1, -1.9), STEEL }, -- manche
		{ Vector3.new(0.62, 1.8, 1.1), CFrame.new(0, -1.1, -3.9), STEEL }, -- tête
		{ Vector3.new(0.62, 0.55, 0.9), CFrame.new(0, -0.48, -4.8), STEEL }, -- mâchoires
		{ Vector3.new(0.62, 0.55, 0.9), CFrame.new(0, -1.72, -4.8), STEEL },
		{ Vector3.new(0.7, 0.45, 0.45), CFrame.new(0, -1.1, -3.3) * UP, DARK, CYL }, -- molette
	},
	MGTapeRoll = {
		{ Vector3.new(0.5, 1.25, 1.25), CFrame.new(0, -1.3, -0.35), TAPE, CYL },
		{ Vector3.new(0.52, 0.6, 0.6), CFrame.new(0, -1.3, -0.35), Color3.fromRGB(150, 110, 70), CYL },
		{ Vector3.new(0.42, 0.9, 0.04), CFrame.new(0, -1.85, -0.98) * CFrame.Angles(0.3, 0, 0), TAPE },
	},
	MGLadder = ladderProp(),
}

------------------------------------------------------------------------
-- Accessoires permanents (serveur) : bandes réfléchissantes, ceinture à outils, moustache, crayon
------------------------------------------------------------------------
function M.Identity(f, head, torso, c, prop)
	for _, s in ipairs({ -1, 1 }) do
		prop(f, torso, Vector3.new(0.3, 2.02, 0.06), CFrame.new(0.55 * s, 0, -0.52), HIVIS) -- bandes devant
		prop(f, torso, Vector3.new(0.3, 2.02, 0.06), CFrame.new(0.55 * s, 0, 0.52), HIVIS) -- bandes dos
		prop(f, torso, Vector3.new(0.5, 0.5, 0.36), CFrame.new(0.68 * s, -1.0, -0.58), Color3.fromRGB(90, 58, 30)) -- poches
	end
	prop(f, torso, Vector3.new(2.06, 0.22, 1.06), CFrame.new(0, -0.3, 0), HIVIS) -- bande horizontale
	prop(f, torso, Vector3.new(2.08, 0.32, 1.08), CFrame.new(0, -0.86, 0), BROWN) -- ceinture
	prop(f, torso, Vector3.new(0.34, 0.26, 0.1), CFrame.new(0, -0.86, -0.56), Color3.fromRGB(230, 200, 60)) -- boucle
	prop(f, torso, Vector3.new(0.16, 0.95, 0.16), CFrame.new(1.1, -1.2, -0.1), Color3.fromRGB(160, 110, 60)) -- marteau
	prop(f, torso, Vector3.new(0.5, 0.2, 0.2), CFrame.new(1.1, -0.78, -0.1), DARK)
	prop(f, torso, Vector3.new(0.1, 0.4, 0.4), CFrame.new(-1.08, -1.05, 0.15) * UP, Color3.fromRGB(230, 200, 60), CYL) -- trousseau
	prop(f, head, Vector3.new(0.75, 0.16, 0.08), CFrame.new(0, -0.17, -0.6), Color3.fromRGB(70, 45, 25)) -- moustache
	prop(f, head, Vector3.new(0.12, 0.12, 0.85), CFrame.new(0.63, 0.15, 0.05), Color3.fromRGB(255, 205, 40)) -- crayon sur l'oreille
	prop(f, head, Vector3.new(0.13, 0.13, 0.12), CFrame.new(0.63, 0.15, -0.42), Color3.fromRGB(255, 150, 160))
end

-- arme fétiche : grosse clé à molette tenue pointe vers le bas
M.Signature = { Hand = "Right", Build = function(f, a, prop)
	local base = CFrame.new(0, -1.05, 0) * CFrame.Angles(math.rad(-35), 0, 0)
	prop(f, a, Vector3.new(0.34, 0.34, 0.8), base * CFrame.new(0, 0, -0.3), HIVIS)
	prop(f, a, Vector3.new(0.3, 0.3, 2.4), base * CFrame.new(0, 0, -1.3), STEEL)
	prop(f, a, Vector3.new(0.45, 1.25, 0.8), base * CFrame.new(0, 0, -2.75), STEEL)
	prop(f, a, Vector3.new(0.45, 0.4, 0.6), base * CFrame.new(0, 0.45, -3.3), STEEL)
	prop(f, a, Vector3.new(0.45, 0.4, 0.6), base * CFrame.new(0, -0.45, -3.3), STEEL)
end }

-- Transformation : casque de chantier avec gyrophare, gilet qui brille, ruban « caution » en bandoulière
function M.Transform(f, head, torso, c, prop)
	prop(f, head, Vector3.new(0.7, 1.4, 1.4), CFrame.new(0, 0.72, 0) * UP, HIVIS, CYL) -- casque
	prop(f, head, Vector3.new(0.12, 1.85, 1.85), CFrame.new(0, 0.42, -0.05) * UP, HIVIS, CYL) -- bord
	prop(f, head, Vector3.new(0.22, 0.2, 1.45), CFrame.new(0, 1.08, 0), Color3.fromRGB(180, 210, 20)) -- arête
	local beacon = prop(f, head, Vector3.new(0.45, 0.5, 0.5), CFrame.new(0, 1.35, 0) * UP, ORANGE, CYL)
	beacon.Name = "Beacon"
	local pl = Instance.new("PointLight")
	pl.Color = ORANGE
	pl.Range = 14
	pl.Brightness = 3
	pl.Parent = beacon
	local vest = Instance.new("PointLight")
	vest.Color = HIVIS
	vest.Range = 8
	vest.Brightness = 1.5
	local core = prop(f, torso, Vector3.new(0.1, 0.1, 0.1), CFrame.new(0, 0, -0.45), HIVIS)
	core.Transparency = 1
	vest.Parent = core -- dans le dossier TransformFX : retirée à la fin de la transformation
	-- ruban « caution » en diagonale (bandes jaunes / noires)
	for i = -3, 3 do
		prop(f, torso, Vector3.new(0.4, 0.36, 0.07), CFrame.new(0, 0, -0.57) * CFrame.Angles(0, 0, 0.75) * CFrame.new(0, i * 0.38, 0), (i % 2 == 0) and Color3.fromRGB(255, 220, 30) or DARK)
	end
	-- perceuse à la hanche + mètre ruban
	prop(f, torso, Vector3.new(0.4, 0.5, 0.9), CFrame.new(-1.15, -0.85, -0.2), RED)
	prop(f, torso, Vector3.new(0.3, 0.3, 0.6), CFrame.new(-1.15, -0.75, -0.85) * CFrame.Angles(0, math.pi / 2, 0) * UP, STEEL, CYL)
	prop(f, torso, Vector3.new(0.3, 0.55, 0.55), CFrame.new(1.12, -0.5, 0.2), Color3.fromRGB(255, 205, 30), CYL)
end

------------------------------------------------------------------------
-- Comportements serveur (Kinds)
------------------------------------------------------------------------
local function ready(api, c)
	return api.CharacterState.isAlive(c) and not api.CharacterState.isStunned(c)
end

-- ennemis dans un disque (distance à plat + écart vertical)
local function inDisc(attacker, center, radius, height)
	local list = {}
	for _, v in ipairs(Kit.enemies(attacker)) do
		local vp = Kit.root(v).Position
		if Vector3.new(vp.X - center.X, 0, vp.Z - center.Z).Magnitude <= radius and math.abs(vp.Y - center.Y) < (height or 9) then
			table.insert(list, v)
		end
	end
	return list
end

M.Kinds = {
	-- Fuse Box : boîte à fusibles posée au sol qui électrocute l'ennemi le plus proche
	MGFuseBox = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local look = Kit.flat(root.CFrame.LookVector)
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local spot = Kit.safePoint(root.Position, root.Position + look * cfg.Offset, 2)
		local g = Kit.ground(spot)
		local base = CFrame.lookAt(g, g - look)
		local model = Instance.new("Model")
		model.Name = "FuseBox"
		Kit.sPart({ Size = Vector3.new(2.6, 3.2, 1.4), CFrame = base * CFrame.new(0, 1.6, 0), Color = Color3.fromRGB(120, 125, 135) }, model)
		Kit.sPart({ Size = Vector3.new(2.2, 2.8, 0.1), CFrame = base * CFrame.new(0, 1.6, -0.72), Color = Color3.fromRGB(150, 155, 165) }, model)
		Kit.sPart({ Size = Vector3.new(1.1, 1.1, 0.1), CFrame = base * CFrame.new(0, 2.1, -0.79) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(255, 220, 30) }, model)
		Kit.sPart({ Size = Vector3.new(0.18, 0.8, 0.05), CFrame = base * CFrame.new(0, 2.1, -0.85) * CFrame.Angles(0, 0, 0.4), Color = DARK }, model)
		Kit.sPart({ Size = Vector3.new(0.5, 0.25, 0.1), CFrame = base * CFrame.new(0.6, 0.9, -0.8), Color = RED }, model)
		local lamp = Kit.sPart({ Name = "Lamp", Shape = BALL, Size = Vector3.one * 0.6, CFrame = base * CFrame.new(0, 3.45, 0), Color = SPARK }, model)
		for _, x in ipairs({ -0.85, 0.85 }) do
			Kit.sPart({ Shape = CYL, Size = Vector3.new(0.7, 0.35, 0.35), CFrame = base * CFrame.new(x, 3.5, 0) * UP, Color = DARK }, model)
		end
		local pl = Instance.new("PointLight")
		pl.Color = SPARK
		pl.Range = 12
		pl.Brightness = 2
		pl.Parent = lamp
		model.Parent = workspace:FindFirstChild("FX") or workspace
		local top = (base * CFrame.new(0, 3.6, 0)).Position
		Kit.fx({ id = "MG_Fuse", p = g, top = top, dur = cfg.Life, a = attacker })
		local t0 = os.clock()
		while os.clock() - t0 < cfg.Life and model.Parent and api.CharacterState.isAlive(attacker) do
			local best, bestD = nil, cfg.Range
			for _, v in ipairs(Kit.enemies(attacker)) do
				local d = (Kit.root(v).Position - top).Magnitude
				if d < bestD and not Kit.isProtected(v) then
					best, bestD = v, d
				end
			end
			if best then
				local vr = Kit.root(best)
				Kit.fx({ id = "MG_Zap", from = top, to = vr.Position })
				api.hit(attacker, best, cfg, api.flat(vr.Position - g, look))
			end
			task.wait(cfg.Interval)
		end
		Kit.fx({ id = "MG_FuseEnd", p = top })
		model:Destroy()
	end,

	-- Duct Tape : rouleau qui rebondit sur les murs, la cible est scotchée (très ralentie)
	MGDuctTape = function(attacker, cfg, aim, api)
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		Kit.projectile(attacker, {
			origin = root.Position + Vector3.new(0, 1, 0) + dir * 2.5, dir = dir, speed = cfg.Speed, range = cfg.Range,
			size = Vector3.new(0.7, 1.5, 1.5), color = TAPE, shape = CYL, bounces = cfg.Bounces, spin = 14,
			decorate = function(part)
				local core = Instance.new("Part")
				core.Shape = CYL
				core.Size = Vector3.new(0.75, 0.7, 0.7)
				core.Color = Color3.fromRGB(150, 110, 70)
				core.Material = Enum.Material.SmoothPlastic
				core.CanCollide, core.CanQuery, core.CanTouch, core.Massless = false, false, false, true
				core.CFrame = part.CFrame
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = part, core
				w.Parent = core
				core.Parent = part
			end,
			onHit = function(v, pos, vel)
				if api.hit(attacker, v, cfg, api.flat(vel, dir), { hitPos = pos }) == "Hit" then
					api.CharacterState.setSpeedMod(v, "MGTaped", cfg.SlowMult, cfg.SlowTime)
					Kit.fx({ id = "MG_Taped", v = v, dur = cfg.SlowTime })
				end
			end,
		})
	end,

	-- Ladder Spin : deux tours d'échelle autour de soi, le second expulse
	MGLadderSpin = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		Kit.fx({ id = "Telegraph", p = Kit.ground(root.Position), r = cfg.Radius, dur = cfg.Windup, a = attacker })
		task.wait(cfg.Windup)
		for i = 1, 2 do
			if not ready(api, attacker) then
				return
			end
			local c = root.Position
			Kit.fx({ id = "MG_Spin", a = attacker, r = cfg.Radius, final = i == 2 })
			for _, v in ipairs(inDisc(attacker, c, cfg.Radius, 7)) do
				local vr = Kit.root(v)
				api.hit(attacker, v, cfg, api.flat(vr.Position - c, root.CFrame.LookVector), i == 2 and cfg.Final or nil)
			end
			if i == 1 then
				task.wait(0.3)
			end
		end
	end,

	-- Short Circuit : onde électrique qui court au sol en ligne droite et soulève tout le monde
	MGShortCircuit = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local origin = Kit.ground(root.Position)
		local far = Kit.safePoint(root.Position, root.Position + dir * cfg.Length, 1)
		local len = math.max(6, (Vector3.new(far.X, 0, far.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude)
		local step = 0.035
		Kit.fx({ id = "MG_Wave", p = origin, dir = dir, len = len, w = cfg.Width, wind = cfg.Windup, step = step, a = attacker })
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local hitSet = {}
		for i = 1, math.ceil(len / 3) do
			local pt = origin + dir * (i * 3)
			for _, v in ipairs(inDisc(attacker, pt, cfg.Width / 2 + 0.5, 8)) do
				if not hitSet[v] then
					hitSet[v] = true
					api.hit(attacker, v, cfg, dir)
				end
			end
			task.wait(step)
		end
	end,

	-- Toolbox Drop : caisse à outils géante qui tombe du plafond et plaque au sol
	MGToolbox = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local spot = Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 3)
		local center = Kit.ground(spot)
		Kit.fx({ id = "Telegraph", p = center, r = cfg.Radius, dur = cfg.Windup, a = attacker })
		Kit.fx({ id = "MG_Toolbox", p = center, look = dir, fall = cfg.Windup, r = cfg.Radius, a = attacker })
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		for _, v in ipairs(inDisc(attacker, center, cfg.Radius, 9)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - center, dir))
		end
		if api.ZoneService and api.ZoneService.shatterAround then
			pcall(api.ZoneService.shatterAround, center, cfg.Radius * 0.7, Vector3.new(0, 30, 0))
		end
	end,
}

------------------------------------------------------------------------
-- Passif (serveur) : Duct Tape Fix
------------------------------------------------------------------------
function M.ServerInit(api)
	local last = setmetatable({}, { __mode = "k" })
	local function watch(c)
		local hum = c:WaitForChild("Humanoid", 5)
		if not hum then
			return
		end
		hum.HealthChanged:Connect(function(h)
			if c:GetAttribute("CharacterName") ~= "MaintenanceGuy" or h <= 0 or h >= hum.MaxHealth * 0.35 then
				return
			end
			if os.clock() - (last[c] or -100) < 40 then
				return
			end
			last[c] = os.clock()
			task.delay(0.15, function()
				if hum.Parent and hum.Health > 0 then
					hum.Health = math.min(hum.MaxHealth, hum.Health + 20)
					Kit.fx({ id = "MG_Patch", v = c })
				end
			end)
		end)
	end
	api.Signals.CharacterSpawned:Connect(function(c)
		task.spawn(watch, c)
	end)
	for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
		if pl.Character then
			task.spawn(watch, pl.Character)
		end
	end
end

------------------------------------------------------------------------
-- Effets client
------------------------------------------------------------------------
local Debris = game:GetService("Debris")

-- éclair en zigzag entre deux points
local function bolt(a, b, color, width, life)
	local pts = { a }
	local n = 6
	for i = 1, n - 1 do
		table.insert(pts, a:Lerp(b, i / n) + Vector3.new(Kit.rng:NextNumber(-1, 1), Kit.rng:NextNumber(-1, 1), Kit.rng:NextNumber(-1, 1)) * 0.9)
	end
	table.insert(pts, b)
	for i = 1, #pts - 1 do
		local p0, p1 = pts[i], pts[i + 1]
		local len = math.max((p1 - p0).Magnitude, 0.05)
		local seg = Kit.part({ Size = Vector3.new(width, width, len), CFrame = CFrame.lookAt(p0, p1) * CFrame.new(0, 0, -len / 2), Color = color })
		Kit.tween(seg, life, { Transparency = 1, Size = Vector3.new(width * 0.2, width * 0.2, len) })
		Debris:AddItem(seg, life + 0.03)
	end
end

-- bande d'alerte au sol (ligne)
local function teleLine(origin, dir, len, w, dur, attacker)
	local col = Kit.mine(attacker) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 70, 60)
	local base = CFrame.lookAt(origin, origin + dir)
	local p = Kit.part({ Size = Vector3.new(w, 0.12, len), CFrame = base * CFrame.new(0, 0.1, -len / 2), Color = col, Transparency = 0.6 })
	local fill = Kit.part({ Size = Vector3.new(w, 0.14, 0.2), CFrame = base * CFrame.new(0, 0.12, -0.1), Color = col, Transparency = 0.3 })
	Kit.tween(fill, dur, { Size = Vector3.new(w, 0.14, len), CFrame = base * CFrame.new(0, 0.12, -len / 2) }, Enum.EasingStyle.Linear)
	task.delay(dur, function()
		Kit.tween(p, 0.2, { Transparency = 1 })
		fill:Destroy()
	end)
	Debris:AddItem(p, dur + 0.25)
	Debris:AddItem(fill, dur + 0.05)
end

local function follow(part, target, offset, dur)
	local RunService = game:GetService("RunService")
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not part.Parent or not target.Parent then
			conn:Disconnect()
			return
		end
		part.CFrame = target.CFrame * offset
	end)
	Debris:AddItem(part, dur)
end

M.MoveFX = {
	MonkeyWrench = function(c, d, api)
		task.delay(0.33, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if not r then
				return
			end
			local look = r.CFrame.LookVector
			local pos = r.Position + look * 3.8 - Vector3.new(0, 2.6, 0)
			api.CartoonFX.bigImpact(pos + Vector3.new(0, 1, 0), look, 1.1, HIVIS)
			api.CartoonFX.shockwave(pos + Vector3.new(0, 0.2, 0), 9, HIVIS)
			api.CartoonFX.sparks(pos + Vector3.new(0, 0.5, 0), 16, SPARK)
			Kit.cubes(pos + Vector3.new(0, 0.4, 0), 12, { Color3.fromRGB(120, 120, 130), STEEL, HIVIS }, 0.6, 9, 0.5)
			api.CartoonFX.sound("GroundSlam", pos, 0.8)
			if Kit.mine(c) then
				api.CartoonFX.shake(0.7)
			end
		end)
	end,
	FuseBox = function(c, d, api)
		local arm = c:FindFirstChild("Right Arm")
		if arm then
			api.CartoonFX.sparks((arm.CFrame * CFrame.new(0, -1.1, 0)).Position, 10, SPARK)
		end
	end,
	DuctTape = function(c, d, api)
		task.delay(0.1, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				Kit.floatText(r.Position + r.CFrame.LookVector * 1.5 + Vector3.new(0, 1.5, 0), "RRRIP!", TAPE, 2, 0.5, 1.5)
			end
		end)
	end,
	LadderSpin = function(c, d, api)
		api.trail(c, 0.8, { HIVIS, Color3.fromRGB(205, 210, 220) }, 0.5, 1)
	end,
	ShortCircuit = function(c, d, api)
		task.spawn(function()
			for _ = 1, 5 do
				local arm = c:FindFirstChild("Right Arm")
				if not arm then
					return
				end
				local hand = (arm.CFrame * CFrame.new(0, -1.1, 0)).Position
				bolt(hand, hand + Vector3.new(api.rng:NextNumber(-2, 2), api.rng:NextNumber(-1, 2), api.rng:NextNumber(-2, 2)), SPARK, 0.18, 0.12)
				task.wait(0.07)
			end
		end)
	end,
	ToolboxDrop = function(c, d, api)
		local arm = c:FindFirstChild("Right Arm")
		if arm then
			api.CartoonFX.twinkle((arm.CFrame * CFrame.new(0, -1.2, 0)).Position)
		end
		api.CartoonFX.sound("Whistle", nil, 0.6)
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	local RunService = game:GetService("RunService")
	Kit.setupClient()

	Kit.on("MG_Zap", function(d)
		bolt(d.from, d.to, SPARK, 0.35, 0.18)
		bolt(d.from, d.to, Color3.new(1, 1, 1), 0.15, 0.12)
		CartoonFX.sparks(d.to, 8, SPARK)
		CartoonFX.sound("Electric", d.to, 0.6)
	end)

	Kit.on("MG_Fuse", function(d)
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), 7, SPARK)
		CartoonFX.puff(d.p + Vector3.new(0, 1, 0), 2)
		Kit.floatText(d.top + Vector3.new(0, 1.5, 0), "DANGER!", Color3.fromRGB(255, 220, 30), 2.5, 0.9, 1.5)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < d.dur do
				bolt(d.top, d.top + Vector3.new(Kit.rng:NextNumber(-2.5, 2.5), Kit.rng:NextNumber(0.5, 2.5), Kit.rng:NextNumber(-2.5, 2.5)), SPARK, 0.14, 0.1)
				task.wait(0.12)
			end
		end)
	end)

	Kit.on("MG_FuseEnd", function(d)
		CartoonFX.puff(d.p, 2.5)
		Kit.cubes(d.p, 10, { STEEL, DARK, Color3.fromRGB(255, 220, 30) }, 0.5, 6, 0.4)
	end)

	Kit.on("MG_Taped", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		CartoonFX.sound("Squeak", vr.Position, 0.7)
		Kit.floatText(vr.Position + Vector3.new(0, 3, 0), "TAPED!", TAPE, 2.4, 0.8, 1.5)
		for i, y in ipairs({ 0.6, -0.2, -1.4 }) do
			local band = Kit.part({ Size = Vector3.new(2.25, 0.38, 1.25), Color = TAPE, CFrame = vr.CFrame * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, (i - 2) * 0.18) })
			follow(band, vr, CFrame.new(0, y, 0) * CFrame.Angles(0, 0, (i - 2) * 0.18), d.dur)
		end
	end)

	Kit.on("MG_Spin", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		local g = r.Position - Vector3.new(0, 2.6, 0)
		CartoonFX.shockwave(g, d.r, d.final and HIVIS or Color3.new(1, 1, 1))
		local disc = Kit.part({ Shape = CYL, Size = Vector3.new(0.15, 4, 4), CFrame = CFrame.new(r.Position - Vector3.new(0, 0.6, 0)) * UP, Color = d.final and HIVIS or Color3.new(1, 1, 1), Transparency = 0.35 })
		Kit.tween(disc, 0.25, { Size = Vector3.new(0.05, d.r * 2, d.r * 2), Transparency = 1 })
		Debris:AddItem(disc, 0.27)
		CartoonFX.sound("Whoosh", r.Position, d.final and 1.1 or 0.8)
		if d.final then
			CartoonFX.sparks(r.Position, 14, HIVIS)
			if Kit.mine(d.a) then
				CartoonFX.shake(0.5)
			end
		end
	end)

	Kit.on("MG_Wave", function(d)
		teleLine(d.p, d.dir, d.len, d.w, d.wind, d.a)
		task.delay(d.wind, function()
			CartoonFX.sound("Electric", d.p, 1.2)
			if Kit.mine(d.a) then
				CartoonFX.shake(0.5)
			end
			local n = math.ceil(d.len / 3)
			for i = 1, n do
				local pt = d.p + d.dir * (i * 3)
				bolt(pt, pt + Vector3.new(Kit.rng:NextNumber(-0.8, 0.8), 6 + Kit.rng:NextNumber(0, 3), Kit.rng:NextNumber(-0.8, 0.8)), SPARK, 0.4, 0.22)
				bolt(pt, pt + Vector3.new(Kit.rng:NextNumber(-0.8, 0.8), 4, Kit.rng:NextNumber(-0.8, 0.8)), Color3.new(1, 1, 1), 0.18, 0.15)
				local crack = Kit.part({ Size = Vector3.new(d.w * 0.7, 0.1, 3.1), CFrame = CFrame.lookAt(pt, pt + d.dir) * CFrame.new(0, 0.08, 1.5), Color = DARK, Transparency = 0.2 })
				Kit.tween(crack, 0.9, { Transparency = 1 })
				Debris:AddItem(crack, 0.92)
				if i % 2 == 0 then
					Kit.cubes(pt + Vector3.new(0, 0.3, 0), 4, SPARKS, 0.35, 5, 0.35)
				end
				task.wait(d.step)
			end
			CartoonFX.shockwave(d.p + d.dir * d.len + Vector3.new(0, 0.2, 0), 5, SPARK)
		end)
	end)

	Kit.on("MG_Toolbox", function(d)
		local look = d.look
		local final = CFrame.lookAt(d.p + Vector3.new(0, 2.6, 0), d.p + Vector3.new(0, 2.6, 0) + look)
		local parts = {}
		local function add(size, off, color, shape)
			local p = Kit.part({ Size = size, CFrame = final * off + Vector3.new(0, 45, 0), Color = color })
			if shape then
				p.Shape = shape
			end
			table.insert(parts, { p, off })
		end
		add(Vector3.new(10, 5, 5.5), CFrame.new(0, 0, 0), RED) -- caisse
		add(Vector3.new(10.2, 1.1, 5.7), CFrame.new(0, 2.2, 0), Color3.fromRGB(170, 25, 25)) -- couvercle
		add(Vector3.new(4, 0.5, 0.6), CFrame.new(0, 3.6, 0), DARK) -- poignée
		add(Vector3.new(0.5, 1.1, 0.6), CFrame.new(-1.8, 3.0, 0), DARK)
		add(Vector3.new(0.5, 1.1, 0.6), CFrame.new(1.8, 3.0, 0), DARK)
		add(Vector3.new(1.2, 0.8, 0.2), CFrame.new(0, 1.2, -2.85), STEEL) -- loquet
		for _, e in ipairs(parts) do
			Kit.tween(e[1], d.fall, { CFrame = final * e[2] }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		task.delay(d.fall, function()
			CartoonFX.sound("Crash", d.p, 1.2)
			CartoonFX.sound("GroundSlam", d.p, 1)
			CartoonFX.bigImpact(d.p + Vector3.new(0, 1.5, 0), Vector3.new(0, -1, 0), 1.5, HIVIS)
			CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r * 1.15, RED)
			CartoonFX.shockwave(d.p + Vector3.new(0, 0.3, 0), d.r * 0.7, HIVIS)
			Kit.cubes(d.p + Vector3.new(0, 1, 0), 26, TOOLS, 0.8, 16, 0.7)
			-- outils qui s'échappent (clés, tournevis)
			for i = 1, 8 do
				local a = i / 8 * math.pi * 2
				local dirv = Vector3.new(math.cos(a), 0, math.sin(a))
				local tool = Kit.part({ Size = Vector3.new(0.3, 0.3, 1.8), CFrame = CFrame.lookAt(d.p + Vector3.new(0, 2, 0), d.p + Vector3.new(0, 2, 0) + dirv), Color = TOOLS[(i % #TOOLS) + 1] })
				Kit.tween(tool, 0.6, { CFrame = CFrame.new(d.p + dirv * (d.r + 3) + Vector3.new(0, 0.5, 0)) * CFrame.Angles(3, a, 2), Transparency = 1 })
				Debris:AddItem(tool, 0.62)
			end
			if Kit.mine(d.a) then
				CartoonFX.shake(1)
			end
		end)
		task.delay(d.fall + 0.9, function()
			for _, e in ipairs(parts) do
				Kit.tween(e[1], 0.35, { Transparency = 1 })
			end
		end)
		for _, e in ipairs(parts) do
			Debris:AddItem(e[1], d.fall + 1.3)
		end
	end)

	Kit.on("MG_Patch", function(d)
		local torso = d.v and d.v:FindFirstChild("Torso")
		if not torso then
			return
		end
		CartoonFX.sound("PowerUp", torso.Position, 0.8)
		CartoonFX.twinkle(torso.Position + Vector3.new(0, 1, 0))
		Kit.floatText(torso.Position + Vector3.new(0, 3.5, 0), "DUCT TAPED! +20", HIVIS, 3, 1.1, 2)
		for _, a in ipairs({ 0.7, -0.7 }) do
			local strip = Kit.part({ Size = Vector3.new(0.45, 2.3, 0.08), Color = TAPE })
			follow(strip, torso, CFrame.new(0, 0, -0.56) * CFrame.Angles(0, 0, a), 3)
		end
	end)

	-- gyrophare qui clignote + étincelles pendant la transformation
	task.spawn(function()
		while true do
			task.wait(0.2)
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "MaintenanceGuy" and c:GetAttribute("Transformed") then
					local fx = c:FindFirstChild("TransformFX")
					local beacon = fx and fx:FindFirstChild("Beacon")
					if beacon then
						local on = math.floor(os.clock() * 5) % 2 == 0
						beacon.Color = on and ORANGE or Color3.fromRGB(255, 220, 40)
						local l = beacon:FindFirstChildOfClass("PointLight")
						if l then
							l.Enabled = on
						end
					end
					local r = c:FindFirstChild("HumanoidRootPart")
					if r and Kit.rng:NextNumber() < 0.5 then
						local p = r.Position + Vector3.new(Kit.rng:NextNumber(-1.5, 1.5), Kit.rng:NextNumber(-2, 1.5), Kit.rng:NextNumber(-1.5, 1.5))
						bolt(p, p + Vector3.new(Kit.rng:NextNumber(-1, 1), Kit.rng:NextNumber(0.5, 1.5), Kit.rng:NextNumber(-1, 1)), SPARK, 0.12, 0.12)
					end
				end
			end
		end
	end)
end

return M
