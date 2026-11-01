--[[
	The Temp — personnage complet (format : voir Modules/ContentLoader).
	Intérimaire mystérieux, ninja de bureau : agrafeuses-shuriken, disparitions derrière la paperasse, clones en post-it.
	Passif « Nobody Knows My Name » : s'il ne subit aucun dégât pendant 4 s, il s'efface (semi-transparent) et son
	prochain coup est une attaque SURPRISE (+5 dégâts).
	Attaques : Staple Stars (3 shuriken-agrafes qui ralentissent), Clock Out (disparition + ruée invisible qui traverse),
	           Sticky-Note Clones (2 clones en post-it autonomes qui foncent et explosent : aveuglent).
	Transformation Off The Books : Thousand Paper Cuts (clignements autour de la cible, 4 entailles puis taille verticale
	           qui PLAQUE au sol), Paper Tornado (tornade de papier qui avance et aspire), Shredder Trap (piège-broyeuse posé
	           au sol : la 1re victime est broyée puis recrachée en l'air).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT
local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2)

local INDIGO = Color3.fromRGB(95, 85, 255) -- couleur du perso
local INDIGO2 = Color3.fromRGB(160, 150, 255)
local INK = Color3.fromRGB(30, 28, 45)
local NOTE = Color3.fromRGB(255, 230, 70)
local NOTE2 = Color3.fromRGB(255, 160, 200)
local PAPER = Color3.fromRGB(245, 242, 232)
local STEEL = Color3.fromRGB(200, 205, 215)
local DARKSTEEL = Color3.fromRGB(70, 72, 85)
local HAIR = Color3.fromRGB(40, 32, 30)

local M = { Id = "Temp", Order = 17 }

M.Character = {
	DisplayName = "The Temp",
	Role = "Elusive assassin",
	Color = INDIGO,
	Shirt = Color3.fromRGB(70, 72, 92), Pants = Color3.fromRGB(38, 38, 50), Tie = INDIGO,
	Passive = { Name = "Nobody Knows My Name", Desc = "After 4 s without taking damage he fades from notice: his next hit is a SURPRISE strike for +5 damage." },
	Attacks = { "StapleStars", "ClockOut", "StickyClones" },
	Transformation = { Name = "Off The Books", Desc = "Black ninja hood and mask, a TEMP headband, a sticky-note scarf and floating paper kunai.", Duration = 20, SpeedMultiplier = 1.25 },
	TransAttacks = { "ThousandCuts", "PaperTornado", "ShredderTrap" },
}

M.Attacks = {
	StapleStars = { Name = "Staple Stars", Kind = "TPShuriken", Desc = "Fling 3 spinning staple-shuriken in a tight fan. Each one staples the victim: slowed for 1.5 s.", Prop = "TPShuriken", Cooldown = 6, Anim = "TPShuriken", Sound = "Throw",
		Count = 3, Interval = 0.1, Spread = 7, Speed = 135, Range = 70, Damage = 4, Knockback = 6, Stun = 0.4, Category = "Projectile", Power = 0.35,
		Words = { "STAPLED!", "THUNK!", "SHING!" }, Effects = { Slow = { 0.6, 1.5 } } },
	ClockOut = { Name = "Clock Out", Kind = "TPVanishDash", Desc = "Vanish in a puff of paperwork and dash invisibly THROUGH everyone in a line, paper-cutting them all.", Cooldown = 8, Anim = "TPClockOut", Sound = "Dash",
		Windup = 0.14, Speed = 100, Time = 0.3, Width = 7, Damage = 8, Knockback = 24, KnockUp = 12, Stun = 0.8, Category = "Heavy", Power = 0.75, Words = { "CLOCKED OUT!", "SNIKT!" } },
	StickyClones = { Name = "Sticky-Note Clones", Kind = "TPClones", Desc = "Peel off 2 sticky-note clones that sprint at the closest coworkers and burst into a blizzard of notes: damage and Blind.", Prop = "TPNotePad", Cooldown = 11, Anim = "TPClones", Sound = "Whoosh",
		Count = 2, Range = 34, Speed = 46, Life = 1.4, Radius = 6, Damage = 5, Knockback = 14, KnockUp = 6, Stun = 0.6, Category = "Light", Power = 0.5,
		Words = { "POST-IT!", "STICKY!", "WHICH ONE?!" }, Effects = { Blind = 1.2 } },
	ThousandCuts = { Name = "Thousand Paper Cuts", Kind = "TPThousandCuts", Desc = "Blink onto the closest coworker in front, slice them from 4 angles in a blur of paper, then an overhead chop PINS them.", Prop = "TPLetterOpener", Cooldown = 12, Anim = "TPCuts", Sound = "Whoosh",
		Range = 26, Windup = 0.16, Slashes = 4, Interval = 0.11, Damage = 2, Knockback = 0, KnockUp = 0, Stun = 0.6, Category = "Light", Power = 0.3, Words = { "SNIP!", "SLICE!", "FWIP!", "CUT!" },
		Final = { Damage = 8, Stun = 1.3, Category = "Heavy", Power = 1.2, Pin = true, Words = { "PAPER CUT!", "FILED!" } } },
	PaperTornado = { Name = "Paper Tornado", Kind = "TPTornado", Desc = "Fan up a howling tornado of paper that crawls forward for 2 s, sucking coworkers in, then bursts and flings them.", Prop = "TPFan", Cooldown = 13, Anim = "TPTornado", Sound = "Whoosh",
		Windup = 0.32, Speed = 8, Life = 2.0, Radius = 6.5, Tick = 0.33, Pull = 30, Damage = 1.2, Knockback = 0, KnockUp = 0, Stun = 0.35, Category = "Light", Power = 0.2, Words = { "WHOOSH!", "PAPERWORK!" },
		Final = { Damage = 5, Knockback = 34, KnockUp = 34, Stun = 0.9, Category = "Heavy", Power = 0.9, Words = { "FILED AWAY!", "FWOOOSH!" } } },
	ShredderTrap = { Name = "Shredder Trap", Kind = "TPTrap", Desc = "Hide a paper shredder on the floor ahead (8 s). The first coworker to step on it gets sucked in, shredded and spat out sky-high.", Prop = "TPShredder", Cooldown = 12, Anim = "TPTrap", Sound = "Clang",
		Offset = 7, Arm = 0.45, Life = 8, Radius = 4, Ticks = 4, TickInterval = 0.2, TickDamage = 2, Damage = 6, Knockback = 0, Launch = Vector3.new(0, 62, 0), Stun = 1.0, Category = "Heavy", Power = 1.0,
		Words = { "SHREDDED!", "CONFIDENTIAL!" } },
}

------------------------------------------------------------------------
-- Animations (une unique par attaque)
------------------------------------------------------------------------
local function cutsAnim()
	local f = {
		{ t = 0 },
		{ t = 0.08, RS = { p = 1.7, y = 0.7 }, LS = { p = 1.7, y = -0.7 }, RJ = { ln = 0.45 }, RH = { p = 0.8 }, LH = { p = 0.8 } }, -- sceau
	}
	local t = 0.16
	for i = 1, 4 do
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = t, RS = { p = 1.2, y = -1.0 * s, r = 0.6 * s }, LS = { p = -0.5, r = -0.3 }, RJ = { ln = 0.35, tw = 0.7 * s }, RH = { p = -0.6 * s }, LH = { p = 0.6 * s } })
		table.insert(f, { t = t + 0.06, RS = { p = 1.5, y = 1.1 * s, r = -0.4 * s }, LS = { p = -0.7, r = -0.3 }, RJ = { ln = 0.5, tw = -0.8 * s, sd = 0.12 * s }, RH = { p = 0.7 * s }, LH = { p = -0.7 * s } })
		t += 0.11
	end
	table.insert(f, { t = t + 0.04, RS = { p = 3.2, r = -0.1 }, LS = { p = 3.0, r = 0.1 }, RJ = { ln = -0.5 }, RH = { p = 0.9 }, LH = { p = 0.3 } }) -- au-dessus
	table.insert(f, { t = t + 0.14, RS = { p = 0.4, y = 0.1 }, LS = { p = 0.5, y = -0.1 }, RJ = { ln = 1.0 }, RH = { p = 1.2 }, LH = { p = -0.5 } }) -- taille verticale
	table.insert(f, { t = t + 0.45, RS = { p = 0.45, y = 0.1 }, LS = { p = 0.5, y = -0.1 }, RJ = { ln = 0.9 }, RH = { p = 1.1 }, LH = { p = -0.45 } })
	table.insert(f, { t = t + 0.62 })
	return f
end

local function tornadoAnim()
	local f = {
		{ t = 0 },
		{ t = 0.1, RS = { p = 3.0, r = -0.4 }, LS = { p = 0.6, r = 0.5 }, RJ = { ln = -0.3, tw = 0.6 }, RH = { p = 0.4 }, LH = { p = -0.2 } }, -- éventail levé
	}
	local t = 0.1
	for i = 1, 8 do
		t += 0.04
		table.insert(f, { t = t, RS = { p = 2.2, r = -1.2 }, LS = { p = 1.2, r = 1.0 }, RJ = { tw = 0.6 - i * (2 * math.pi + 0.6) / 8, ln = 0.1 }, RH = { p = (i % 2 == 0) and 0.5 or -0.2 }, LH = { p = (i % 2 == 0) and -0.2 or 0.5 } })
	end
	table.insert(f, { t = t + 0.001, RS = { p = 2.2, r = -1.2 }, LS = { p = 1.2, r = 1.0 }, RJ = { tw = 0, ln = 0.1 } })
	table.insert(f, { t = t + 0.1, RS = { p = 1.6, y = 0.8 }, LS = { p = -0.4, r = -0.4 }, RJ = { ln = 0.55, tw = -0.5 }, RH = { p = -0.7 }, LH = { p = 0.9 } }) -- coup d'éventail
	table.insert(f, { t = t + 0.5, RS = { p = 1.55, y = 0.8 }, LS = { p = -0.4, r = -0.4 }, RJ = { ln = 0.5, tw = -0.45 }, RH = { p = -0.6 }, LH = { p = 0.8 } })
	table.insert(f, { t = t + 0.7 })
	return f
end

M.Anims = {
	TPShuriken = { -- trois lancers latéraux, buste qui vrille, puis lancer double
		{ t = 0 },
		{ t = 0.06, RS = { p = 0.5, y = -1.0, r = -0.7 }, LS = { p = 1.2, y = 0.5 }, RJ = { tw = 0.7, ln = 0.3 }, RH = { p = 0.6 }, LH = { p = -0.3 } },
		{ t = 0.12, RS = { p = 1.7, y = 1.0, r = 0.3 }, LS = { p = 0.3 }, RJ = { tw = -0.7, ln = 0.15 }, RH = { p = -0.4 }, LH = { p = 0.6 } },
		{ t = 0.18, LS = { p = 0.5, y = 1.0, r = 0.7 }, RS = { p = 1.2, y = -0.5 }, RJ = { tw = -0.7, ln = 0.3 }, LH = { p = 0.6 }, RH = { p = -0.3 } },
		{ t = 0.24, LS = { p = 1.7, y = -1.0, r = -0.3 }, RS = { p = 0.3 }, RJ = { tw = 0.7, ln = 0.15 }, LH = { p = -0.4 }, RH = { p = 0.6 } },
		{ t = 0.3, RS = { p = 0.6, y = -1.1, r = -0.8 }, LS = { p = 1.0, y = 0.4 }, RJ = { tw = 0.9, ln = 0.35, sd = -0.1 }, RH = { p = 0.7 }, LH = { p = -0.3 } },
		{ t = 0.36, RS = { p = 1.8, y = 1.1, r = 0.4 }, LS = { p = -0.5 }, RJ = { tw = -0.9, ln = 0.2, sd = 0.1 }, RH = { p = -0.5 }, LH = { p = 0.7 } },
		{ t = 0.6, RS = { p = 1.75, y = 1.05, r = 0.4 }, LS = { p = -0.5 }, RJ = { tw = -0.8, ln = 0.15 }, RH = { p = -0.4 }, LH = { p = 0.6 } },
		{ t = 0.75 },
	},
	TPClockOut = { -- sceau accroupi, course ninja bras en arrière, se retourne en garde
		{ t = 0 },
		{ t = 0.07, RS = { p = 1.8, y = 0.6 }, LS = { p = 1.8, y = -0.6 }, RJ = { ln = 0.5 }, RH = { p = 0.9 }, LH = { p = 0.9 } },
		{ t = 0.14, RS = { p = -1.3, r = -0.3 }, LS = { p = -1.3, r = 0.3 }, RJ = { ln = 0.9, tw = 0.1 }, RH = { p = -0.9 }, LH = { p = 1.2 } },
		{ t = 0.42, RS = { p = -1.35, r = -0.35 }, LS = { p = -1.35, r = 0.35 }, RJ = { ln = 0.85 }, RH = { p = -0.8 }, LH = { p = 1.1 } },
		{ t = 0.5, RS = { p = 1.0, y = 0.9, r = 0.4 }, LS = { p = -0.4 }, RJ = { ln = 0.25, tw = -0.8 }, RH = { p = 0.7 }, LH = { p = -0.4 } },
		{ t = 0.75, RS = { p = 1.0, y = 0.9, r = 0.4 }, LS = { p = -0.4 }, RJ = { ln = 0.2, tw = -0.7 }, RH = { p = 0.6 }, LH = { p = -0.4 } },
		{ t = 0.9 },
	},
	TPClones = { -- sceau des mains qui tremble, puis bras projetés vers l'extérieur
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.6, y = 0.75 }, LS = { p = 1.6, y = -0.75 }, RJ = { ln = 0.25 }, RH = { p = 0.4 }, LH = { p = 0.4 } },
		{ t = 0.2, RS = { p = 1.7, y = 0.8, r = 0.1 }, LS = { p = 1.7, y = -0.8, r = -0.1 }, RJ = { ln = 0.3, sd = 0.06 }, RH = { p = 0.45 }, LH = { p = 0.45 } },
		{ t = 0.3, RS = { p = 1.65, y = 0.75, r = -0.1 }, LS = { p = 1.65, y = -0.75, r = 0.1 }, RJ = { ln = 0.3, sd = -0.06 }, RH = { p = 0.45 }, LH = { p = 0.45 } },
		{ t = 0.38, RS = { p = 1.5, r = 1.5 }, LS = { p = 1.5, r = -1.5 }, RJ = { ln = -0.35 }, RH = { p = -0.3, r = 0.25 }, LH = { p = -0.3, r = -0.25 } },
		{ t = 0.65, RS = { p = 1.4, r = 1.4 }, LS = { p = 1.4, r = -1.4 }, RJ = { ln = -0.3 }, RH = { p = -0.25, r = 0.2 }, LH = { p = -0.25, r = -0.2 } },
		{ t = 0.85 },
	},
	TPCuts = cutsAnim(),
	TPTornado = tornadoAnim(),
	TPTrap = { -- bond accroupi, plaque la broyeuse au sol à deux mains, se relève d'un saut arrière
		{ t = 0 },
		{ t = 0.1, RS = { p = 2.6, r = -0.2 }, LS = { p = 2.6, r = 0.2 }, RJ = { ln = -0.3 }, RH = { p = 0.3 }, LH = { p = 0.3 } },
		{ t = 0.28, RS = { p = 1.0 }, LS = { p = 1.0 }, RJ = { ln = 1.05 }, RH = { p = 1.3 }, LH = { p = 0.2 } },
		{ t = 0.5, RS = { p = 0.9 }, LS = { p = 0.9 }, RJ = { ln = 1.0 }, RH = { p = 1.25 }, LH = { p = 0.15 } },
		{ t = 0.62, RS = { p = -0.6, r = -0.4 }, LS = { p = -0.6, r = 0.4 }, RJ = { ln = -0.25 }, RH = { p = -0.5 }, LH = { p = 0.6 } },
		{ t = 0.85 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main (repère bras droit)
------------------------------------------------------------------------
local function fanProp()
	local t = {}
	for i = -3, 3 do
		local a = i * 0.32
		table.insert(t, { Vector3.new(0.06, 1.7, 0.42), CFrame.new(0, -1.1, -0.2) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -0.15, -0.85) * CFrame.Angles(math.pi / 2, 0, 0), (i % 2 == 0) and PAPER or INDIGO })
	end
	table.insert(t, { Vector3.new(0.16, 0.3, 0.3), CFrame.new(0, -1.1, -0.2) * ALONG_Y, INK, CYL })
	return t
end

M.Props = {
	TPShuriken = {
		{ Vector3.new(0.12, 0.45, 0.45), CFrame.new(0, -1.2, -0.45), INDIGO, CYL },
		{ Vector3.new(0.08, 1.2, 0.24), CFrame.new(0, -1.2, -0.45), STEEL },
		{ Vector3.new(0.08, 1.2, 0.24), CFrame.new(0, -1.2, -0.45) * CFrame.Angles(math.pi / 2, 0, 0), STEEL },
		{ Vector3.new(0.09, 0.8, 0.18), CFrame.new(0, -1.2, -0.45) * CFrame.Angles(math.pi / 4, 0, 0), DARKSTEEL },
		{ Vector3.new(0.09, 0.8, 0.18), CFrame.new(0, -1.2, -0.45) * CFrame.Angles(-math.pi / 4, 0, 0), DARKSTEEL },
	},
	TPNotePad = {
		{ Vector3.new(0.85, 0.35, 0.85), CFrame.new(0, -1.25, -0.3), NOTE },
		{ Vector3.new(0.85, 0.04, 0.85), CFrame.new(0.05, -1.05, -0.35) * CFrame.Angles(0.2, 0.3, 0), NOTE2 },
	},
	TPLetterOpener = {
		{ Vector3.new(0.2, 0.2, 0.55), CFrame.new(0, -1.15, -0.2), INK },
		{ Vector3.new(0.35, 0.08, 0.1), CFrame.new(0, -1.15, -0.5), INDIGO },
		{ Vector3.new(0.12, 0.05, 1.6), CFrame.new(0, -1.15, -1.3), STEEL },
		{ Vector3.new(0.13, 0.06, 1.6), CFrame.new(0, -1.15, -1.3), INDIGO2 },
	},
	TPFan = fanProp(),
	TPShredder = {
		{ Vector3.new(1.3, 0.85, 0.9), CFrame.new(0, -1.5, -0.35), DARKSTEEL },
		{ Vector3.new(1.0, 0.06, 0.12), CFrame.new(0, -1.06, -0.35), INK },
		{ Vector3.new(1.32, 0.15, 0.92), CFrame.new(0, -1.85, -0.35), INDIGO },
		{ Vector3.new(0.18, 0.35, 0.02), CFrame.new(0.3, -0.85, -0.35), PAPER },
		{ Vector3.new(0.18, 0.28, 0.02), CFrame.new(-0.1, -0.88, -0.35), PAPER },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents (serveur) : cordon + badge TEMP, cheveux en bataille, crayon, bloc de post-it au poignet
------------------------------------------------------------------------
local function label(part, text, color, face, bg)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face or Enum.NormalId.Front
	sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 60
	sg.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = bg and 0 or 1
	l.BackgroundColor3 = bg or Color3.new(1, 1, 1)
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.GothamBlack
	l.TextColor3 = color
	l.Parent = sg
	return l
end

function M.Identity(f, head, torso, c, prop)
	-- cordon (deux brins) + badge
	prop(f, torso, Vector3.new(0.08, 0.95, 0.05), CFrame.new(-0.28, 0.5, -0.53) * CFrame.Angles(0, 0, -0.45), INDIGO)
	prop(f, torso, Vector3.new(0.08, 0.95, 0.05), CFrame.new(0.28, 0.5, -0.53) * CFrame.Angles(0, 0, 0.45), INDIGO)
	local badge = prop(f, torso, Vector3.new(0.55, 0.65, 0.05), CFrame.new(0, -0.05, -0.55), PAPER)
	label(badge, "TEMP", INDIGO, Enum.NormalId.Front)
	prop(f, torso, Vector3.new(0.56, 0.14, 0.06), CFrame.new(0, 0.23, -0.555), INDIGO)
	prop(f, torso, Vector3.new(0.12, 0.1, 0.07), CFrame.new(0, 0.33, -0.555), STEEL)
	-- cheveux en bataille + mèches
	prop(f, head, Vector3.new(1.28, 0.32, 1.22), CFrame.new(0, 0.6, 0.05), HAIR)
	prop(f, head, Vector3.new(1.28, 0.55, 0.28), CFrame.new(0, 0.32, 0.55), HAIR)
	for i, a in ipairs({ -0.5, 0.1, 0.6 }) do
		prop(f, head, Vector3.new(0.35, 0.3, 0.5), CFrame.new(-0.4 + i * 0.25, 0.72, -0.3) * CFrame.Angles(0.4, 0, a), HAIR)
	end
	-- crayon derrière l'oreille droite
	prop(f, head, Vector3.new(0.1, 0.1, 0.85), CFrame.new(0.66, 0.2, 0.05) * CFrame.Angles(0.3, 0, 0), NOTE)
	prop(f, head, Vector3.new(0.11, 0.11, 0.12), CFrame.new(0.66, 0.08, -0.36) * CFrame.Angles(0.3, 0, 0), Color3.fromRGB(255, 150, 160))
	-- bloc de post-it au poignet gauche
	local la = c:FindFirstChild("Left Arm")
	if la then
		prop(f, la, Vector3.new(1.06, 0.32, 1.06), CFrame.new(0, -0.5, 0), NOTE)
		prop(f, la, Vector3.new(0.6, 0.05, 0.6), CFrame.new(0, -0.5, -0.56) * CFrame.Angles(math.pi / 2, 0, 0.2), NOTE2)
	end
end

-- arme fétiche : agrafeuse à la main droite
M.Signature = { Hand = "Right", Build = function(f, a, prop)
	prop(f, a, Vector3.new(0.4, 0.18, 1.3), CFrame.new(0, -1.2, -0.45), DARKSTEEL)
	prop(f, a, Vector3.new(0.34, 0.2, 1.25), CFrame.new(0, -1.02, -0.42) * CFrame.Angles(-0.08, 0, 0), INDIGO)
	prop(f, a, Vector3.new(0.3, 0.06, 0.25), CFrame.new(0, -0.92, -0.95), STEEL)
	prop(f, a, Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, -1.1, 0.15), STEEL, BALL)
end }

-- Transformation : capuche + masque de ninja, bandeau TEMP, écharpe de post-it, kunai de papier flottants
function M.Transform(f, head, torso, c, prop)
	prop(f, head, Vector3.new(1.34, 0.5, 1.34), CFrame.new(0, 0.45, 0.02), INK) -- capuche
	prop(f, head, Vector3.new(1.34, 1.2, 0.35), CFrame.new(0, 0.05, 0.5), INK)
	prop(f, head, Vector3.new(0.18, 1.15, 1.25), CFrame.new(0.62, 0.05, 0.02), INK)
	prop(f, head, Vector3.new(0.18, 1.15, 1.25), CFrame.new(-0.62, 0.05, 0.02), INK)
	prop(f, head, Vector3.new(1.28, 0.46, 1.26), CFrame.new(0, -0.3, 0), INK) -- masque
	local band = prop(f, head, Vector3.new(1.38, 0.2, 1.38), CFrame.new(0, 0.28, 0.02), INDIGO) -- bandeau
	band.Material = Enum.Material.Neon
	local plate = prop(f, head, Vector3.new(0.62, 0.26, 0.06), CFrame.new(0, 0.28, -0.71), STEEL)
	label(plate, "TEMP", INK, Enum.NormalId.Front)
	prop(f, head, Vector3.new(0.14, 0.75, 0.06), CFrame.new(0.15, -0.05, 0.75) * CFrame.Angles(0.3, 0, 0.35), INDIGO)
	prop(f, head, Vector3.new(0.14, 0.65, 0.06), CFrame.new(-0.12, -0.05, 0.75) * CFrame.Angles(0.3, 0, -0.3), INDIGO)
	-- écharpe de post-it : col + traîne dans le dos
	prop(f, torso, Vector3.new(1.5, 0.35, 1.15), CFrame.new(0, 0.95, 0), NOTE)
	for i = 1, 5 do
		local n = prop(f, torso, Vector3.new(0.5, 0.5, 0.05), CFrame.new(0.55 - i * 0.08, 0.75 - i * 0.42, 0.6 + i * 0.12) * CFrame.Angles(-0.25 - i * 0.05, 0, (i % 2 == 0) and 0.25 or -0.2), (i % 2 == 0) and NOTE2 or NOTE)
		n.Name = "Scarf" .. i
	end
	-- kunai de papier en éventail dans le dos
	for i = -1, 1 do
		local base = CFrame.new(i * 0.55, 1.35, 0.85) * CFrame.Angles(0.2, 0, -i * 0.45)
		prop(f, torso, Vector3.new(0.1, 1.0, 0.32), base * CFrame.new(0, 0.55, 0), PAPER)
		prop(f, torso, Vector3.new(0.12, 0.45, 0.14), base * CFrame.new(0, -0.15, 0), INK)
		local ring = prop(f, torso, Vector3.new(0.06, 0.24, 0.24), base * CFrame.new(0, -0.45, 0), INDIGO, CYL)
		ring.Material = Enum.Material.Neon
	end
	local pl = Instance.new("PointLight")
	pl.Color = INDIGO
	pl.Range = 9
	pl.Brightness = 1.6
	pl.Parent = band
end

------------------------------------------------------------------------
-- Comportements serveur (Kinds)
------------------------------------------------------------------------
local function ready(api, c)
	return api.CharacterState.isAlive(c) and not api.CharacterState.isStunned(c)
end

local function frontTarget(attacker, dir, range)
	local root = Kit.root(attacker)
	local best, bestD = nil, math.huge
	for _, v in ipairs(Kit.enemies(attacker)) do
		local to = Kit.root(v).Position - root.Position
		local d = to.Magnitude
		if d <= range and not Kit.isProtected(v) then
			if (Kit.flat(to):Dot(dir) >= 0.4 or d < 8) and d < bestD then
				best, bestD = v, d
			end
		end
	end
	return best
end

local function unhold(c)
	local r = Kit.root(c)
	local h = r and r:FindFirstChild("ContentHold")
	if h then
		h:Destroy()
	end
end

local function decorateStar(part)
	part.Transparency = 1
	local function add(size, cf, color, shape, mat)
		local p = Instance.new("Part")
		p.Size = size
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
		p.Anchored = false
		p.CFrame = part.CFrame * cf
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = part, p
		w.Parent = p
		p.Parent = part
		return p
	end
	add(Vector3.new(0.16, 0.55, 0.55), UP, INDIGO, CYL, Enum.Material.Neon)
	for k = 0, 3 do
		add(Vector3.new(0.3, 0.08, 1.5), CFrame.Angles(0, k * math.pi / 4, 0), (k % 2 == 0) and STEEL or DARKSTEEL, nil, Enum.Material.Metal)
	end
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0.45, 0, 0), Vector3.new(-0.45, 0, 0)
	a0.Parent, a1.Parent = part, part
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.18
	tr.Color = ColorSequence.new(INDIGO2, INDIGO)
	tr.Transparency = NumberSequence.new(0.2, 1)
	tr.LightEmission = 0.8
	tr.Parent = part
end

M.Kinds = {
	-- Staple Stars : 3 shuriken-agrafes en éventail serré, chacun ralentit
	TPShuriken = function(attacker, cfg, aim, api)
		task.wait(0.08)
		for i = 1, cfg.Count do
			if not ready(api, attacker) then
				return
			end
			local root = Kit.root(attacker)
			local base = Kit.aimDir(attacker, aim)
			local dir = CFrame.Angles(0, math.rad((i - (cfg.Count + 1) / 2) * cfg.Spread), 0) * base
			local origin = root.Position + Vector3.new(0, 0.8, 0) + dir * 2.2
			Kit.projectile(attacker, {
				origin = origin, dir = dir, speed = cfg.Speed, range = cfg.Range, size = Vector3.new(1.3, 0.12, 1.3), color = STEEL, spin = 40,
				decorate = decorateStar,
				onHit = function(v, pos, vel)
					if api.hit(attacker, v, cfg, Kit.flat(vel, dir)) == "Hit" then
						Kit.fx({ id = "TP_Stapled", v = v, p = pos })
					end
					return false
				end,
			})
			if i < cfg.Count then
				task.wait(cfg.Interval)
			end
		end
	end,

	-- Clock Out : disparition, ruée invisible qui traverse et entaille tout le monde sur la ligne
	TPVanishDash = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local start = root.Position
		local g = Kit.ground(start)
		Kit.fx({ id = "TP_DashTele", cf = CFrame.lookAt(g, g + dir), w = cfg.Width, len = cfg.Speed * cfg.Time, dur = cfg.Windup, a = attacker })
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		attacker:SetAttribute("TPVanish", true)
		Kit.fx({ id = "TP_Vanish", p = root.Position, a = attacker, look = dir })
		local hitSet = {}
		Kit.dash(attacker, dir, cfg.Speed, cfg.Time, function(r)
			for _, v in ipairs(Kit.inCircle(attacker, r.Position, cfg.Width / 2, 5)) do
				if not hitSet[v] then
					hitSet[v] = true
					Kit.fx({ id = "TP_Cut", p = Kit.root(v).Position, look = dir })
					api.hit(attacker, v, cfg, dir)
				end
			end
		end)
		-- bloqué par un corps (collision entre persos) : il « passe à travers » et réapparaît au bout de la ligne
		local len = cfg.Speed * cfg.Time
		if root.Parent and api.CharacterState.isAlive(attacker) and (Kit.flat(root.Position - start) * (root.Position - start).Magnitude):Dot(dir) < len * 0.75 then
			local fin = Kit.safePoint(start, start + dir * len, 2.5)
			for _, v in ipairs(Kit.inRect(attacker, CFrame.lookAt(start, start + dir), cfg.Width, (fin - start).Magnitude, 5)) do
				if not hitSet[v] then
					hitSet[v] = true
					Kit.fx({ id = "TP_Cut", p = Kit.root(v).Position, look = dir })
					api.hit(attacker, v, cfg, dir)
				end
			end
			root.CFrame = CFrame.lookAt(fin, fin + dir)
		end
		attacker:SetAttribute("TPVanish", false)
		if root.Parent then
			Kit.fx({ id = "TP_Appear", p = root.Position, a = attacker, look = dir })
		end
	end,

	-- Sticky-Note Clones : 2 clones autonomes qui foncent sur les ennemis devant puis explosent
	TPClones = function(attacker, cfg, aim, api)
		task.wait(0.36)
		if not ready(api, attacker) then
			return
		end
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local cands = {}
		for _, v in ipairs(Kit.enemies(attacker)) do
			local to = Kit.root(v).Position - root.Position
			if to.Magnitude <= cfg.Range and (Kit.flat(to):Dot(dir) > 0.2 or to.Magnitude < 8) and not Kit.isProtected(v) then
				table.insert(cands, { v = v, d = to.Magnitude })
			end
		end
		table.sort(cands, function(a, b)
			return a.d < b.d
		end)
		local token = (attacker:GetAttribute("TPCloneSeq") or 0) + 1
		attacker:SetAttribute("TPCloneSeq", token)
		local right = dir:Cross(Vector3.yAxis)
		for i = 1, cfg.Count do
			local side = (i == 1) and -1 or 1
			local pick = cands[i] or cands[1]
			local target = pick and pick.v or nil
			local pos = Kit.safePoint(root.Position, root.Position + right * side * 2.4, 1)
			local goal = Kit.safePoint(pos, pos + (CFrame.Angles(0, math.rad(-side * 14), 0) * dir) * cfg.Range * 0.7, 2)
			local cid = attacker.Name .. "_" .. token .. "_" .. i
			Kit.fx({ id = "TP_Clone", cid = cid, p = pos, look = dir, v = target, goal = goal, speed = cfg.Speed, life = cfg.Life, a = attacker })
			task.spawn(function()
				local t0 = os.clock()
				while os.clock() - t0 < cfg.Life do
					local dt = task.wait()
					local to = goal
					if target and target.Parent and Kit.root(target) and api.CharacterState.isAlive(target) then
						to = Kit.root(target).Position
					end
					local d = Vector3.new(to.X - pos.X, 0, to.Z - pos.Z)
					if d.Magnitude < 2.6 then
						break
					end
					pos += d.Unit * math.min(d.Magnitude, cfg.Speed * dt)
					if #Kit.inCircle(attacker, pos, 2.6, 5) > 0 then
						break
					end
				end
				Kit.fx({ id = "TP_CloneBurst", cid = cid, p = pos, r = cfg.Radius, a = attacker })
				for _, v in ipairs(Kit.inCircle(attacker, pos, cfg.Radius, 6)) do
					api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - pos, dir))
				end
			end)
			task.wait(0.07)
		end
	end,

	-- Thousand Paper Cuts : clignements autour de la cible, 4 entailles, puis taille verticale qui plaque au sol
	TPThousandCuts = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local victim = frontTarget(attacker, dir, cfg.Range)
		if not victim then
			local dest = Kit.safePoint(root.Position, root.Position + dir * 10, 2)
			Kit.fx({ id = "TP_Blink", p = root.Position, to = dest, a = attacker })
			root.CFrame = CFrame.lookAt(dest, dest + dir)
			Kit.fx({ id = "TP_CutsWhiff", a = attacker, p = dest })
			return
		end
		local vr = Kit.root(victim)
		Kit.fx({ id = "Telegraph", p = Kit.ground(vr.Position), r = 4, dur = cfg.Windup, a = attacker })
		task.wait(cfg.Windup)
		if not ready(api, attacker) or not api.CharacterState.isAlive(victim) or not vr.Parent then
			return
		end
		local total = cfg.Slashes * cfg.Interval + 0.55
		api.CharacterState.stun(victim, total)
		Kit.hold(victim, total)
		Kit.hold(attacker, total)
		local from = root.Position
		local broke = false
		for i = 1, cfg.Slashes do
			if not api.CharacterState.isAlive(attacker) or not api.CharacterState.isAlive(victim) or api.CharacterState.isStunned(attacker) then
				broke = true
				break
			end
			local c = vr.Position
			local a = math.rad(i * 137 + 25)
			local pos = Kit.safePoint(c, c + Vector3.new(math.cos(a), 0, math.sin(a)) * 4.2, 1.5)
			root.CFrame = CFrame.lookAt(pos, Vector3.new(c.X, pos.Y, c.Z))
			Kit.fx({ id = "TP_Slash", from = from, p = pos, c = c, i = i, a = attacker })
			api.hit(attacker, victim, cfg, Kit.flat(c - pos, dir))
			from = pos
			task.wait(cfg.Interval)
		end
		if not broke and api.CharacterState.isAlive(attacker) and api.CharacterState.isAlive(victim) and not api.CharacterState.isStunned(attacker) then
			local c = vr.Position
			local above = Kit.safePoint(c - dir * 2.5, c - dir * 2.5 + Vector3.new(0, 6, 0), 1.5)
			root.CFrame = CFrame.lookAt(above, above + dir)
			Kit.fx({ id = "TP_Chop", p = c, from = above, a = attacker, look = dir })
			task.wait(0.13)
			local land = Kit.safePoint(c, c - dir * 2.6, 1)
			root.CFrame = CFrame.lookAt(land, Vector3.new(c.X, land.Y, c.Z))
			unhold(victim)
			api.hit(attacker, victim, cfg, dir, cfg.Final)
		end
		unhold(attacker)
	end,

	-- Paper Tornado : tornade qui avance, aspire et entaille, puis explose
	TPTornado = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local p0 = Kit.ground(root.Position + dir * 3)
		local p1 = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * (3 + cfg.Speed * cfg.Life), 3))
		Kit.fx({ id = "TP_TornadoTele", cf = CFrame.lookAt(p0 - dir * cfg.Radius * 0.5, p0 + dir), w = cfg.Radius * 2, len = (p1 - p0).Magnitude + cfg.Radius, dur = cfg.Windup, a = attacker })
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		Kit.fx({ id = "TP_Tornado", p0 = p0, p1 = p1, life = cfg.Life, r = cfg.Radius, a = attacker })
		local t0 = os.clock()
		local nextTick = 0
		while os.clock() - t0 < cfg.Life do
			local el = os.clock() - t0
			if el >= nextTick then
				nextTick += cfg.Tick
				local c = p0:Lerp(p1, el / cfg.Life) + Vector3.new(0, 3, 0)
				for _, v in ipairs(Kit.inCircle(attacker, c, cfg.Radius, 8)) do
					api.hit(attacker, v, cfg, api.flat(c - Kit.root(v).Position, dir))
					Kit.pull(v, c, cfg.Pull, 0.6)
				end
			end
			task.wait()
		end
		local c = p1 + Vector3.new(0, 3, 0)
		Kit.fx({ id = "TP_TornadoBurst", p = p1, r = cfg.Radius, a = attacker })
		for _, v in ipairs(Kit.inCircle(attacker, c, cfg.Radius + 1.5, 9)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - c, dir), cfg.Final)
		end
	end,

	-- Shredder Trap : broyeuse posée au sol, la 1re victime est broyée puis recrachée en l'air
	TPTrap = function(attacker, cfg, aim, api)
		task.wait(0.3)
		local root = Kit.root(attacker)
		if not root then
			return
		end
		local dir = Kit.aimDir(attacker, aim)
		local pos = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 2))
		local token = (attacker:GetAttribute("TPTrapSeq") or 0) + 1
		attacker:SetAttribute("TPTrapSeq", token)
		local tid = attacker.Name .. "_trap" .. token
		Kit.fx({ id = "TP_TrapSet", tid = tid, p = pos, look = dir, life = cfg.Life, r = cfg.Radius, a = attacker })
		task.wait(cfg.Arm)
		local t0 = os.clock()
		local victim
		while os.clock() - t0 < cfg.Life do
			if attacker:GetAttribute("TPTrapSeq") ~= token or not attacker.Parent then
				break
			end
			local list = Kit.inCircle(attacker, pos + Vector3.new(0, 3, 0), cfg.Radius, 5)
			if #list > 0 then
				victim = list[1]
				break
			end
			task.wait(0.1)
		end
		if not victim then
			Kit.fx({ id = "TP_TrapGone", tid = tid, p = pos })
			return
		end
		local vr = Kit.root(victim)
		local total = cfg.Ticks * cfg.TickInterval + 0.45
		Kit.fx({ id = "TP_TrapSnap", tid = tid, p = pos, v = victim, dur = total })
		api.CharacterState.stun(victim, total)
		Kit.pull(victim, pos + Vector3.new(0, 3, 0), 70, 0.1)
		task.wait(0.15)
		Kit.hold(victim, total)
		for _ = 1, cfg.Ticks do
			if not api.CharacterState.isAlive(victim) or not vr.Parent then
				break
			end
			api.hit(attacker, victim, cfg, dir, { Damage = cfg.TickDamage, Knockback = 0, KnockUp = 0, Stun = 0.5, Category = "Light", Power = 0.3, Words = { "SHRED!", "BRRRT!", "ZZZT!" } })
			Kit.fx({ id = "TP_Shred", p = vr.Position })
			task.wait(cfg.TickInterval)
		end
		if api.CharacterState.isAlive(victim) and vr.Parent then
			unhold(victim)
			Kit.fx({ id = "TP_TrapSpit", tid = tid, p = pos })
			api.hit(attacker, victim, cfg, dir)
		else
			Kit.fx({ id = "TP_TrapGone", tid = tid, p = pos })
		end
	end,
}

------------------------------------------------------------------------
-- Passif (serveur) : Nobody Knows My Name
------------------------------------------------------------------------
local HIDE_AFTER, BONUS = 4, 5
function M.ServerInit(api)
	local CombatService = api.CombatService
	local Players = game:GetService("Players")
	local quiet = setmetatable({}, { __mode = "k" }) -- dernier instant « remarqué » (touché ou coup surprise)
	table.insert(CombatService.damageMods, function(p)
		local v, a = p.victim, p.attacker
		if (p.damage or 0) <= 0 then
			return
		end
		if a and a ~= v and p.category ~= "Ultimate" and a:GetAttribute("CharacterName") == "Temp" and a:GetAttribute("TPHidden") then
			a:SetAttribute("TPHidden", false)
			quiet[a] = os.clock()
			p.damage += BONUS
			p.words = { "SURPRISE!", "WHO ARE YOU?!", "NEW GUY?!" }
			p.power = (p.power or 0.5) + 0.25
			local vr = Kit.root(v)
			if vr then
				Kit.fx({ id = "TP_Surprise", p = vr.Position, a = a })
			end
		end
		if v and v ~= a and v:GetAttribute("CharacterName") == "Temp" then
			quiet[v] = os.clock()
			if v:GetAttribute("TPHidden") then
				v:SetAttribute("TPHidden", false)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, pl in ipairs(Players:GetPlayers()) do
				local c = pl.Character
				if c and c:GetAttribute("CharacterName") == "Temp" and api.CharacterState.isAlive(c) then
					if not quiet[c] then
						quiet[c] = os.clock()
					end
					local hidden = os.clock() - quiet[c] >= HIDE_AFTER
					if (c:GetAttribute("TPHidden") or false) ~= hidden then
						c:SetAttribute("TPHidden", hidden)
					end
				end
			end
		end
	end)
end

------------------------------------------------------------------------
-- Effets client
------------------------------------------------------------------------
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local function follow(part, target, offset, dur)
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

-- post-it qui volent dans tous les sens
local function notes(pos, n, dist, life, colors)
	colors = colors or { NOTE, NOTE, NOTE2, PAPER }
	for _ = 1, n do
		local dirv = Vector3.new(Kit.rng:NextNumber(-1, 1), Kit.rng:NextNumber(-0.2, 1), Kit.rng:NextNumber(-1, 1))
		if dirv.Magnitude < 0.1 then
			dirv = Vector3.yAxis
		end
		local p = Kit.part({ Size = Vector3.new(0.6, 0.04, 0.6), CFrame = CFrame.new(pos) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Color = colors[Kit.rng:NextInteger(1, #colors)] })
		Kit.tween(p, life, { CFrame = CFrame.new(pos + dirv.Unit * dist * Kit.rng:NextNumber(0.5, 1) - Vector3.new(0, 1, 0)) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6)), Transparency = 1 }, Enum.EasingStyle.Quad)
		Debris:AddItem(p, life + 0.05)
	end
end

-- fumée indigo (boules qui gonflent)
local function smoke(pos, n, r, life)
	for _ = 1, n do
		local off = Vector3.new(Kit.rng:NextNumber(-r, r), Kit.rng:NextNumber(-r * 0.5, r), Kit.rng:NextNumber(-r, r))
		local s = Kit.rng:NextNumber(1.2, 2.4)
		local b = Kit.part({ Shape = BALL, Size = Vector3.one * s, CFrame = CFrame.new(pos + off * 0.3), Color = (Kit.rng:NextNumber() < 0.5) and INDIGO or INK, Transparency = 0.25 })
		Kit.tween(b, life, { Size = Vector3.one * s * 2.2, CFrame = CFrame.new(pos + off + Vector3.new(0, 1.2, 0)), Transparency = 1 }, Enum.EasingStyle.Quad)
		Debris:AddItem(b, life + 0.05)
	end
end

-- silhouette en post-it (clone)
local DOLL = {
	{ "T", Vector3.new(2, 2, 0.35) }, { "H", Vector3.new(1.2, 1.2, 0.35) },
	{ "LA", Vector3.new(0.9, 2, 0.3) }, { "RA", Vector3.new(0.9, 2, 0.3) },
	{ "LL", Vector3.new(0.9, 2, 0.3) }, { "RL", Vector3.new(0.9, 2, 0.3) },
}
local function makeDoll(cf)
	local parts = {}
	for i, d in ipairs(DOLL) do
		parts[d[1]] = Kit.part({ Size = d[2], CFrame = cf, Color = (i == 2) and NOTE2 or NOTE, Transparency = 0.08 })
	end
	local e1 = Kit.part({ Size = Vector3.new(0.2, 0.35, 0.05), Color = INK })
	local e2 = Kit.part({ Size = Vector3.new(0.2, 0.35, 0.05), Color = INK })
	local band = Kit.part({ Size = Vector3.new(1.25, 0.22, 0.4), Color = INDIGO, Material = Enum.Material.Neon })
	local doll = { parts = parts, extra = { e1, e2, band } }
	function doll.place(c, phase)
		local sw = math.sin(phase) * 0.9
		parts.T.CFrame = c
		parts.H.CFrame = c * CFrame.new(0, 1.6, 0)
		parts.LA.CFrame = c * CFrame.new(-1.5, 0.9, 0) * CFrame.Angles(-sw - 0.6, 0, 0) * CFrame.new(0, -0.9, 0)
		parts.RA.CFrame = c * CFrame.new(1.5, 0.9, 0) * CFrame.Angles(sw - 0.6, 0, 0) * CFrame.new(0, -0.9, 0)
		parts.LL.CFrame = c * CFrame.new(-0.5, -1, 0) * CFrame.Angles(sw, 0, 0) * CFrame.new(0, -1, 0)
		parts.RL.CFrame = c * CFrame.new(0.5, -1, 0) * CFrame.Angles(-sw, 0, 0) * CFrame.new(0, -1, 0)
		e1.CFrame = c * CFrame.new(-0.25, 1.65, -0.2)
		e2.CFrame = c * CFrame.new(0.25, 1.65, -0.2)
		band.CFrame = c * CFrame.new(0, 1.95, 0)
	end
	function doll.destroy()
		for _, p in pairs(parts) do
			p:Destroy()
		end
		for _, p in ipairs(doll.extra) do
			p:Destroy()
		end
	end
	doll.place(cf, 0)
	return doll
end

local clones = {}
local traps = {}

M.MoveFX = {
	StapleStars = function(c, d, api)
		local arm = c:FindFirstChild("Right Arm")
		if arm then
			api.CartoonFX.twinkle((arm.CFrame * CFrame.new(0, -1.2, 0)).Position)
		end
	end,
	ClockOut = function(c, d, api) end,
	StickyClones = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 3.5, 0), "COPY THAT!", NOTE, 2.2, 0.8, 1)
			notes(r.Position, 10, 4, 0.6)
		end
	end,
	ThousandCuts = function(c, d, api)
		api.afterimages(c, 0.7, INDIGO)
	end,
	PaperTornado = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			api.CartoonFX.swirl(r.Position - Vector3.new(0, 2, 0), 3, 5, { PAPER, INDIGO }, 10, 0.5)
		end
	end,
	ShredderTrap = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r and Kit.mine(c) then
			Kit.floatText(r.Position + Vector3.new(0, 3.5, 0), "SHHH...", INDIGO2, 2, 0.8, 1)
		end
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	Kit.setupClient()

	Kit.on("TP_Stapled", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		CartoonFX.sound("MetalHit", d.p, 0.9)
		CartoonFX.sparks(d.p, 8, INDIGO2)
		if vr then
			Kit.floatText(vr.Position + Vector3.new(0, 3, 0), "STAPLED!", INDIGO2, 2, 0.8, 1.2)
			for i = 1, 2 do
				local s = Kit.part({ Size = Vector3.new(0.7, 0.12, 0.12), Color = STEEL, Material = Enum.Material.Metal })
				follow(s, vr, CFrame.new((i - 1.5) * 0.6, 0.3 + i * 0.25, -0.62) * CFrame.Angles(0, 0, (i - 1.5) * 0.6), 1.5)
			end
		end
	end)

	Kit.on("TP_DashTele", function(d)
		Kit.rectTelegraph(d.cf, d.w, d.len, d.dur, d.a)
	end)

	Kit.on("TP_Vanish", function(d)
		CartoonFX.sound("Whoosh", d.p, 1.1)
		smoke(d.p, 8, 2, 0.6)
		notes(d.p, 18, 6, 0.7, { PAPER, PAPER, NOTE })
		CartoonFX.shockwave(d.p - Vector3.new(0, 2.8, 0), 6, INDIGO)
		Kit.floatText(d.p + Vector3.new(0, 3.5, 0), "*POOF*", PAPER, 2, 0.6, 1)
		if Kit.mine(d.a) then
			CartoonFX.speedLines(0.35, INDIGO2)
		end
	end)

	Kit.on("TP_Cut", function(d)
		CartoonFX.sound("Punch", d.p, 1)
		local cf = CFrame.lookAt(d.p, d.p + d.look)
		CartoonFX.slashArc(cf, 4, INDIGO2)
		CartoonFX.shards(d.p, 8, { PAPER, INDIGO }, 1)
		local line = Kit.part({ Size = Vector3.new(0.15, 0.15, 7), CFrame = cf * CFrame.Angles(0, 0, 0.6), Color = INDIGO2, Material = Enum.Material.Neon })
		Kit.tween(line, 0.25, { Size = Vector3.new(0.02, 0.02, 9), Transparency = 1 })
		Debris:AddItem(line, 0.3)
	end)

	Kit.on("TP_Appear", function(d)
		CartoonFX.sound("Whoosh", d.p, 0.8)
		smoke(d.p, 6, 1.6, 0.5)
		notes(d.p, 10, 4, 0.6, { PAPER, NOTE })
		if Kit.mine(d.a) then
			CartoonFX.shake(0.3)
		end
	end)

	Kit.on("TP_Clone", function(d)
		local look = d.look
		local doll = makeDoll(CFrame.lookAt(d.p, d.p + look))
		clones[d.cid] = doll
		notes(d.p, 8, 3, 0.5)
		CartoonFX.sound("Whoosh", d.p, 0.8)
		local pos = d.p
		local phase = 0
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function(dt)
			if clones[d.cid] ~= doll or os.clock() - t0 > d.life + 0.6 then
				conn:Disconnect()
				if clones[d.cid] == doll then
					clones[d.cid] = nil
					doll.destroy()
				end
				return
			end
			local to = d.goal
			local vr = d.v and d.v.Parent and d.v:FindFirstChild("HumanoidRootPart")
			if vr then
				to = vr.Position
			end
			local dv = Vector3.new(to.X - pos.X, 0, to.Z - pos.Z)
			if dv.Magnitude > 2.6 then
				look = dv.Unit
				pos += look * math.min(dv.Magnitude, d.speed * dt)
			end
			phase += dt * 22
			doll.place(CFrame.lookAt(pos, pos + look) * CFrame.Angles(-0.35, 0, 0), phase)
		end)
	end)

	Kit.on("TP_CloneBurst", function(d)
		local doll = clones[d.cid]
		clones[d.cid] = nil
		if doll then
			doll.destroy()
		end
		CartoonFX.sound("Splat", d.p, 1)
		CartoonFX.sound("Whoosh", d.p, 0.8)
		notes(d.p, 34, d.r * 1.2, 0.8)
		notes(d.p + Vector3.new(0, 2, 0), 14, d.r * 0.8, 1.1, { NOTE2, NOTE })
		CartoonFX.shockwave(d.p - Vector3.new(0, 2.6, 0), d.r, NOTE)
		CartoonFX.bigImpact(d.p, Vector3.yAxis, 0.7, NOTE)
		CartoonFX.word(d.p + Vector3.new(0, 4, 0), "STICKY!", 0.9, "Light")
		if Kit.mine(d.a) then
			CartoonFX.shake(0.35)
		end
	end)

	Kit.on("TP_Blink", function(d)
		smoke(d.p, 5, 1.4, 0.45)
		smoke(d.to, 5, 1.4, 0.45)
		CartoonFX.sound("Whoosh", d.p, 0.9)
	end)

	Kit.on("TP_CutsWhiff", function(d)
		Kit.floatText(d.p + Vector3.new(0, 3.5, 0), "WRONG DESK...", PAPER, 2.4, 0.8, 1)
	end)

	Kit.on("TP_Slash", function(d)
		smoke(d.from, 3, 1, 0.35)
		smoke(d.p, 3, 1, 0.35)
		local mid = (d.from + d.p) / 2
		local len = (d.p - d.from).Magnitude
		if len > 0.5 then
			local st = Kit.part({ Size = Vector3.new(0.35, 0.35, len), CFrame = CFrame.lookAt(mid, d.p), Color = INDIGO2, Material = Enum.Material.Neon, Transparency = 0.2 })
			Kit.tween(st, 0.22, { Size = Vector3.new(0.05, 0.05, len), Transparency = 1 })
			Debris:AddItem(st, 0.25)
		end
		local back = d.c - d.p
		if back.Magnitude < 0.1 then
			back = Vector3.new(0, 0, -1)
		end
		local cf = CFrame.lookAt(d.c, d.c + back) * CFrame.Angles(0, 0, (d.i % 2 == 0) and 0.9 or -0.9)
		CartoonFX.slashArc(cf, 3.6, (d.i % 2 == 0) and INDIGO or PAPER)
		CartoonFX.shards(d.c, 6, { PAPER, INDIGO2 }, 1)
		CartoonFX.sound("Punch", d.c, 0.9)
		if Kit.mine(d.a) then
			CartoonFX.shake(0.25)
		end
	end)

	Kit.on("TP_Chop", function(d)
		CartoonFX.sound("Whoosh", d.p, 1.2)
		local g = CartoonFX.groundPos(d.p)
		local blade = Kit.part({ Size = Vector3.new(0.3, 9, 0.3), CFrame = CFrame.new(d.p + Vector3.new(0, 6, 0)), Color = INDIGO2, Material = Enum.Material.Neon })
		Kit.tween(blade, 0.13, { CFrame = CFrame.new(d.p + Vector3.new(0, 1, 0)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.13, function()
			Kit.tween(blade, 0.25, { Size = Vector3.new(0.05, 12, 0.05), Transparency = 1 })
			CartoonFX.sound("GroundSlam", g, 1)
			CartoonFX.sound("PunchHeavy", d.p, 1)
			CartoonFX.bigImpact(g + Vector3.new(0, 0.5, 0), Vector3.new(0, -1, 0), 1.3, INDIGO)
			CartoonFX.shockwave(g + Vector3.new(0, 0.2, 0), 9, INDIGO)
			CartoonFX.shockwave(g + Vector3.new(0, 0.3, 0), 5, PAPER)
			CartoonFX.cracks(g, 6, 4, 1.2)
			notes(d.p, 26, 7, 0.8, { PAPER, PAPER, NOTE, INDIGO2 })
			CartoonFX.word(d.p + Vector3.new(0, 4.5, 0), "PAPER CUT!", 1.3, "Heavy")
			if Kit.mine(d.a) then
				CartoonFX.shake(0.9)
				CartoonFX.impactFrame(0.6)
			end
		end)
		Debris:AddItem(blade, 0.45)
	end)

	Kit.on("TP_TornadoTele", function(d)
		Kit.rectTelegraph(d.cf, d.w, d.len, d.dur, d.a)
	end)

	Kit.on("TP_Tornado", function(d)
		CartoonFX.sound("Whoosh", d.p0, 1.2)
		CartoonFX.sound("Rumble", d.p0, 0.6)
		local sheets = {}
		local cols = { PAPER, PAPER, NOTE, INDIGO2, PAPER }
		for i = 1, 34 do
			local s = Kit.part({ Size = Vector3.new(0.9, 0.05, 1.15), Color = cols[i % #cols + 1] })
			sheets[i] = { p = s, h = (i / 34) * 8, a = i * 0.9, sp = Kit.rng:NextNumber(5, 8) }
		end
		local core = Kit.part({ Shape = CYL, Size = Vector3.new(8, 3, 3), Color = INDIGO, Transparency = 0.75 })
		local core2 = Kit.part({ Shape = CYL, Size = Vector3.new(0.3, d.r * 2, d.r * 2), Color = INDIGO, Transparency = 0.7 })
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			if el > d.life then
				conn:Disconnect()
				for _, s in ipairs(sheets) do
					s.p:Destroy()
				end
				core:Destroy()
				core2:Destroy()
				return
			end
			local c = d.p0:Lerp(d.p1, el / d.life)
			local grow = math.min(1, el * 5)
			for _, s in ipairs(sheets) do
				local a = s.a + el * s.sp
				local rr = (1 + s.h * 0.55) * grow
				local pos = c + Vector3.new(math.cos(a) * rr, s.h + math.sin(el * 3 + s.a) * 0.3, math.sin(a) * rr)
				s.p.CFrame = CFrame.new(pos) * CFrame.Angles(0, -a, 0.6) * CFrame.Angles(el * 4, 0, 0)
			end
			core.CFrame = CFrame.new(c + Vector3.new(0, 4, 0)) * UP * CFrame.Angles(el * 6, 0, 0)
			core2.CFrame = CFrame.new(c + Vector3.new(0, 0.15, 0)) * UP
		end)
		if Kit.mine(d.a) then
			CartoonFX.shake(0.3)
		end
	end)

	Kit.on("TP_TornadoBurst", function(d)
		CartoonFX.sound("Explosion", d.p, 0.8)
		CartoonFX.sound("Whoosh", d.p, 1.2)
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r * 1.5, INDIGO)
		CartoonFX.bigImpact(d.p + Vector3.new(0, 2, 0), Vector3.yAxis, 1.1, INDIGO2)
		notes(d.p + Vector3.new(0, 2, 0), 40, d.r * 1.6, 1.0, { PAPER, PAPER, NOTE, INDIGO2 })
		CartoonFX.word(d.p + Vector3.new(0, 5, 0), "FILED AWAY!", 1.1, "Heavy")
		if Kit.mine(d.a) then
			CartoonFX.shake(0.6)
		end
	end)

	Kit.on("TP_TrapSet", function(d)
		local mine = Kit.mine(d.a)
		local base = CFrame.lookAt(d.p, d.p + d.look) * CFrame.new(0, 0.5, 0)
		local alpha = mine and 0 or 0.72
		local model = {}
		local function add(size, off, color, mat)
			local p = Kit.part({ Size = size, CFrame = base * off, Color = color, Material = mat or Enum.Material.SmoothPlastic, Transparency = alpha })
			table.insert(model, p)
			return p
		end
		local body = add(Vector3.new(2.6, 1.0, 1.8), CFrame.new(0, 0, 0), DARKSTEEL)
		add(Vector3.new(2.0, 0.08, 0.25), CFrame.new(0, 0.52, 0), INK)
		add(Vector3.new(2.64, 0.2, 1.84), CFrame.new(0, -0.35, 0), INDIGO)
		local led = add(Vector3.new(0.2, 0.2, 0.2), CFrame.new(0.95, 0.52, -0.6), Color3.fromRGB(255, 60, 60), Enum.Material.Neon)
		local lbl = Kit.flatText(body, "SHRED", NOTE, Enum.NormalId.Front)
		lbl.TextTransparency = alpha
		if mine then
			table.insert(model, Kit.part({ Shape = CYL, Size = Vector3.new(0.1, d.r * 2, d.r * 2), CFrame = CFrame.new(d.p + Vector3.new(0, 0.08, 0)) * UP, Color = INDIGO, Transparency = 0.75 }))
		end
		traps[d.tid] = { parts = model, body = body }
		CartoonFX.sound("Clang", d.p, 0.8)
		CartoonFX.puff(d.p + Vector3.new(0, 0.5, 0), 2)
		task.spawn(function()
			local t0 = os.clock()
			while traps[d.tid] and os.clock() - t0 < d.life + 1 do
				led.Transparency = (led.Transparency < 0.5) and 0.9 or alpha
				task.wait(0.35)
			end
		end)
		task.delay(d.life + 2.5, function()
			local tr = traps[d.tid]
			if tr then
				traps[d.tid] = nil
				for _, p in ipairs(tr.parts) do
					p:Destroy()
				end
			end
		end)
	end)

	local function killTrap(tid, pos, burst)
		local tr = traps[tid]
		traps[tid] = nil
		if tr then
			for _, p in ipairs(tr.parts) do
				Kit.tween(p, 0.25, { Transparency = 1 })
				Debris:AddItem(p, 0.3)
			end
		end
		if burst then
			CartoonFX.puff(pos + Vector3.new(0, 0.5, 0), 2.5)
		end
	end

	Kit.on("TP_TrapGone", function(d)
		killTrap(d.tid, d.p, true)
	end)

	Kit.on("TP_TrapSnap", function(d)
		local tr = traps[d.tid]
		if tr then
			for _, p in ipairs(tr.parts) do
				p.Transparency = (p.Shape == CYL) and 0.75 or 0
			end
			for _, l in ipairs(tr.body:GetDescendants()) do
				if l:IsA("TextLabel") then
					l.TextTransparency = 0
				end
			end
		end
		CartoonFX.sound("Clang", d.p, 1.2)
		CartoonFX.sound("Electric", d.p, 1)
		CartoonFX.word(d.p + Vector3.new(0, 5, 0), "GOTCHA!", 1.1, "Heavy")
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), 6, INDIGO)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if vr then
			Kit.floatText(vr.Position + Vector3.new(0, 3.5, 0), "CONFIDENTIAL!", Color3.fromRGB(255, 80, 80), 2.6, 0.9, 1)
		end
	end)

	Kit.on("TP_Shred", function(d)
		CartoonFX.sound("Crumble", d.p, 0.8)
		for _ = 1, 10 do
			local s = Kit.part({ Size = Vector3.new(0.12, 0.03, 1.1), CFrame = CFrame.new(d.p - Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, Kit.rng:NextNumber(0, 6), 0), Color = (Kit.rng:NextNumber() < 0.75) and PAPER or NOTE })
			local out = Vector3.new(Kit.rng:NextNumber(-3, 3), Kit.rng:NextNumber(2, 5), Kit.rng:NextNumber(-3, 3))
			Kit.tween(s, 0.6, { CFrame = CFrame.new(d.p + out) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Transparency = 1 })
			Debris:AddItem(s, 0.65)
		end
		CartoonFX.sparks(d.p - Vector3.new(0, 1.5, 0), 6, INDIGO2)
	end)

	Kit.on("TP_TrapSpit", function(d)
		CartoonFX.sound("Explosion", d.p, 0.7)
		CartoonFX.sound("BigImpact", d.p, 1)
		CartoonFX.bigImpact(d.p + Vector3.new(0, 1, 0), Vector3.yAxis, 1.2, INDIGO)
		CartoonFX.pillar(d.p, 2.5, 12, INDIGO2, 0.4)
		notes(d.p + Vector3.new(0, 1, 0), 30, 8, 1.0, { PAPER, PAPER, PAPER, NOTE })
		CartoonFX.word(d.p + Vector3.new(0, 5, 0), "SHREDDED!", 1.3, "Heavy")
		killTrap(d.tid, d.p, false)
	end)

	Kit.on("TP_Surprise", function(d)
		CartoonFX.sound("Ding", d.p, 1)
		CartoonFX.word(d.p + Vector3.new(0, 4.5, 0), "SURPRISE!", 1.2, "Heavy")
		Kit.floatText(d.p + Vector3.new(0, 3, 0), "WHO ARE YOU?!", INDIGO2, 2.6, 1, 2)
		smoke(d.p, 5, 1.5, 0.5)
		CartoonFX.shockwave(d.p - Vector3.new(0, 2.6, 0), 5, INDIGO)
	end)

	-- passif + disparition : transparence locale des Temp (TPVanish > TPHidden)
	local lastAlpha = setmetatable({}, { __mode = "k" })
	local function setAlpha(c, a)
		if lastAlpha[c] == a then
			return
		end
		lastAlpha[c] = a
		for _, p in ipairs(c:GetDescendants()) do
			if (p:IsA("BasePart") and p.Name ~= "HumanoidRootPart") or p:IsA("Decal") then
				p.LocalTransparencyModifier = a
			end
		end
	end
	task.spawn(function()
		local n = 0
		while true do
			task.wait(0.1)
			n += 1
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "Temp" then
					local mine = Kit.mine(c)
					local a = 0
					if c:GetAttribute("TPVanish") then
						a = mine and 0.6 or 0.92
					elseif c:GetAttribute("TPHidden") then
						a = mine and 0.3 or 0.45
					end
					setAlpha(c, a)
					local r = c:FindFirstChild("HumanoidRootPart")
					if r and c:GetAttribute("TPHidden") and n % 12 == 0 then
						Kit.floatText(r.Position + Vector3.new(Kit.rng:NextNumber(-1, 1), 3.2, 0), "?", INDIGO2, 1.4, 1, 1.5)
					end
					if r and c:GetAttribute("Transformed") and n % 3 == 0 then
						smoke(r.Position - Vector3.new(0, 2.2, 0), 1, 1.2, 0.7)
						if n % 6 == 0 then
							notes(r.Position + Vector3.new(0, 2.5, 0), 1, 3, 1.2)
						end
					end
				elseif lastAlpha[c] and lastAlpha[c] ~= 0 then
					setAlpha(c, 0)
				end
			end
		end
	end)
end

return M
