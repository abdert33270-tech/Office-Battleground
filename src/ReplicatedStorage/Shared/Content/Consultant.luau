--[[
	The Consultant — personnage complet (format : voir Modules/ContentLoader).
	Consultant en stratégie : diapos PowerPoint (parodie), graphiques, mots à la mode, pointeur laser, « let's circle back ».
	Passif « Move the Needle » : chaque coup porté ajoute +1 KPI (max 5) ; chaque KPI = +4 % de dégâts.
	Un coup lourd subi fait s'effondrer la courbe (KPI à 0). Graphique de KPI affiché au-dessus de lui.
	Attaques : Laser Pointer (visée puis rayon instantané : marque +5), Let's Circle Back (diapo-boomerang aller + retour
	           qui ramène vers lui), Buzzword Blast (cône de lettres géantes qui étourdit).
	Transformation Keynote Mode : Paradigm Shift (diapo géante qui balaie tout devant comme un mur), Exponential Growth
	           (barres d'histogramme qui jaillissent en ligne et envoient en l'air), Let's Take This Offline (bond + classeur
	           géant qui PLAQUE au sol).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT
local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2)

local ROYAL = Color3.fromRGB(40, 100, 240) -- couleur du perso
local ROYAL2 = Color3.fromRGB(120, 175, 255)
local NAVY = Color3.fromRGB(28, 36, 64)
local LASER = Color3.fromRGB(255, 40, 50)
local ORANGE = Color3.fromRGB(255, 150, 40)
local TEAL = Color3.fromRGB(40, 200, 170)
local YELLOW = Color3.fromRGB(255, 215, 50)
local WHITE = Color3.fromRGB(250, 250, 250)
local GREY = Color3.fromRGB(90, 95, 110)
local STEEL = Color3.fromRGB(200, 205, 215)
local GOLD = Color3.fromRGB(255, 200, 60)
local HAIR = Color3.fromRGB(110, 75, 45)
local CHART = { ORANGE, TEAL, YELLOW, ROYAL2, Color3.fromRGB(255, 90, 140) }

local M = { Id = "Consultant", Order = 18 }

M.Character = {
	DisplayName = "The Consultant",
	Role = "Ranged strategist",
	Color = ROYAL,
	Shirt = Color3.fromRGB(35, 45, 85), Pants = Color3.fromRGB(32, 34, 48), Tie = ORANGE,
	Passive = { Name = "Move the Needle", Desc = "Every hit he lands adds +1 KPI (max 5): each KPI = +4% damage. Taking a heavy hit crashes the chart back to 0." },
	Attacks = { "LaserPointer", "CircleBack", "Buzzword" },
	Transformation = { Name = "Keynote Mode", Desc = "Headset mic, a floating projector screen behind him and a holographic pie chart over his shoulder.", Duration = 20, SpeedMultiplier = 1.1 },
	TransAttacks = { "ParadigmShift", "GrowthChart", "TakeOffline" },
}

M.Attacks = {
	LaserPointer = { Name = "Laser Pointer", Kind = "CSLaser", Desc = "Aim a laser for a split second, then zap the first coworker in a long line: they get HIGHLIGHTED and your next hit on them deals +5.", Prop = "CSLaserPen", Cooldown = 7, Anim = "CSLaser", Sound = "Electric",
		Windup = 0.35, Range = 60, Width = 3.5, Damage = 6, Knockback = 10, KnockUp = 3, Stun = 0.5, Category = "Light", Power = 0.5, Words = { "KEY TAKEAWAY!", "HIGHLIGHTED!" }, Effects = { Mark = 5 } },
	CircleBack = { Name = "Let's Circle Back", Kind = "CSBoomerang", Desc = "Throw your laminated slide deck like a boomerang: it hits on the way out AND on the way back, dragging victims toward you.", Prop = "CSDeck", Cooldown = 8, Anim = "CSCircleBack", Sound = "Throw",
		Out = 26, Speed = 75, Width = 5, Damage = 4, Knockback = 10, KnockUp = 4, Stun = 0.45, Category = "Projectile", Power = 0.4, Words = { "PER MY LAST EMAIL!", "THWAP!" },
		Back = { Damage = 4, Knockback = 26, KnockUp = 6, Stun = 0.6, Category = "Light", Power = 0.5, Words = { "CIRCLING BACK!", "FOLLOW-UP!" } } },
	Buzzword = { Name = "Buzzword Blast", Kind = "CSBuzzword", Desc = "Shout a buzzword so hard its giant letters blast out in a cone: everyone hit is CONFUSED (stunned) for 1.2 s.", Prop = "CSClicker", Cooldown = 10, Anim = "CSBuzz", Sound = "Whoosh",
		Windup = 0.28, Range = 17, Angle = 70, Damage = 5, Knockback = 16, KnockUp = 4, Stun = 1.2, Category = "Light", Power = 0.55, Words = { "SYNERGY!", "LEVERAGE!", "PARADIGM!", "DISRUPT!", "PIVOT!" } },
	ParadigmShift = { Name = "Paradigm Shift", Kind = "CSSlideWall", Desc = "A giant presentation slide slams down and SWEEPS forward like a wall, bulldozing everyone in its path.", Cooldown = 12, Anim = "CSParadigm", Sound = "Whoosh",
		Windup = 0.34, Width = 14, Distance = 30, Time = 0.6, Damage = 9, Knockback = 52, KnockUp = 14, Stun = 0.9, Category = "Heavy", Power = 1.0, Words = { "PARADIGM SHIFT!", "NEXT SLIDE!" } },
	GrowthChart = { Name = "Exponential Growth", Kind = "CSGrowth", Desc = "The bars of a giant growth chart erupt one after another in a line, each taller than the last, launching coworkers sky-high.", Prop = "CSClicker", Cooldown = 13, Anim = "CSGrowth", Sound = "Rumble",
		Windup = 0.35, Bars = 5, Gap = 4.5, Interval = 0.12, Radius = 3.4, Damage = 8, Knockback = 6, Launch = Vector3.new(4, 50, 0), Stun = 1.0, Category = "Heavy", Power = 0.9, Words = { "STONKS!", "+400%!", "Q4 GROWTH!" } },
	TakeOffline = { Name = "Let's Take This Offline", Kind = "CSOffline", Desc = "Leap onto the closest coworker in front and slam a giant 3-ring binder down on them: PINS everyone under it.", Prop = "CSBinder", Cooldown = 11, Anim = "CSOffline", Sound = "Whoosh",
		Range = 26, Offset = 12, Radius = 8, Up = 42, Rise = 0.3, Damage = 13, Knockback = 0, Stun = 1.3, Category = "Heavy", Power = 1.2, Words = { "OFFLINE!", "MEETING ADJOURNED!" }, Effects = { Pin = true } },
}

------------------------------------------------------------------------
-- Animations (une unique par attaque)
------------------------------------------------------------------------
M.Anims = {
	CSLaser = { -- bras tendu de présentateur, l'autre main dans le dos, recul au tir
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.65, y = 0.1 }, LS = { p = -0.3, r = 0.5, y = 0.6 }, RJ = { tw = 0.35, ln = 0.1 }, RH = { p = 0.3 }, LH = { p = -0.25 } },
		{ t = 0.35, RS = { p = 1.62 }, LS = { p = -0.3, r = 0.5, y = 0.6 }, RJ = { tw = 0.4, ln = 0.18 }, RH = { p = 0.35 }, LH = { p = -0.3 } },
		{ t = 0.4, RS = { p = 2.0, r = -0.1 }, LS = { p = -0.3, r = 0.5, y = 0.6 }, RJ = { tw = 0.45, ln = -0.2 }, RH = { p = 0.15 }, LH = { p = -0.15 } },
		{ t = 0.65, RS = { p = 1.9, r = -0.1 }, LS = { p = -0.3, r = 0.5, y = 0.6 }, RJ = { tw = 0.4, ln = -0.1 }, RH = { p = 0.2 }, LH = { p = -0.2 } },
		{ t = 0.8 },
	},
	CSCircleBack = { -- grand armé derrière l'épaule, lancer fouetté en travers, suivi du buste
		{ t = 0 },
		{ t = 0.12, RS = { p = 0.8, y = -1.3, r = -0.9 }, LS = { p = 1.0, y = 0.6 }, RJ = { tw = 0.9, ln = -0.1 }, RH = { p = 0.5 }, LH = { p = -0.4 } },
		{ t = 0.19, RS = { p = 1.6, y = 1.3, r = 0.3 }, LS = { p = -0.3 }, RJ = { tw = -0.9, ln = 0.35 }, RH = { p = -0.6 }, LH = { p = 0.8 } },
		{ t = 0.45, RS = { p = 1.3, y = 1.4, r = 0.4 }, LS = { p = -0.3 }, RJ = { tw = -0.8, ln = 0.3 }, RH = { p = -0.5 }, LH = { p = 0.7 } },
		{ t = 0.6, RS = { p = 1.2, y = 0.3 }, LS = { p = 0.2, r = 0.6 }, RJ = { tw = 0, ln = 0 } }, -- attend le retour
		{ t = 0.85 },
	},
	CSBuzz = { -- inspire cambré bras ouverts, puis crie penché, mains en porte-voix
		{ t = 0 },
		{ t = 0.22, RS = { p = 1.2, r = 0.9 }, LS = { p = 1.2, r = -0.9 }, RJ = { ln = -0.45 }, RH = { p = 0.2 }, LH = { p = -0.1 } },
		{ t = 0.3, RS = { p = 2.1, y = 0.6 }, LS = { p = 2.1, y = -0.6 }, RJ = { ln = 0.55 }, RH = { p = -0.6 }, LH = { p = 0.8 } },
		{ t = 0.7, RS = { p = 2.0, y = 0.6 }, LS = { p = 2.0, y = -0.6 }, RJ = { ln = 0.5, sd = 0.05 }, RH = { p = -0.55 }, LH = { p = 0.75 } },
		{ t = 0.9 },
	},
	CSParadigm = { -- appelle la diapo bras au ciel, puis grande poussée à deux mains en fente
		{ t = 0 },
		{ t = 0.18, RS = { p = 3.1, r = -0.3 }, LS = { p = 3.1, r = 0.3 }, RJ = { ln = -0.4 }, RH = { p = 0.2 }, LH = { p = 0.2 } },
		{ t = 0.34, RS = { p = 3.2, r = -0.25 }, LS = { p = 3.2, r = 0.25 }, RJ = { ln = -0.5 }, RH = { p = 0.25 }, LH = { p = 0.25 } },
		{ t = 0.42, RS = { p = 1.6, y = 0.3 }, LS = { p = 1.6, y = -0.3 }, RJ = { ln = 0.7 }, RH = { p = -0.9 }, LH = { p = 1.2 } },
		{ t = 0.9, RS = { p = 1.55, y = 0.3 }, LS = { p = 1.55, y = -0.3 }, RJ = { ln = 0.65 }, RH = { p = -0.85 }, LH = { p = 1.1 } },
		{ t = 1.05 },
	},
	CSGrowth = { -- accroupi mains basses, puis les bras montent par paliers (courbe qui grimpe), pose en V
		{ t = 0 },
		{ t = 0.12, RS = { p = 0.4, r = 0.3 }, LS = { p = 0.4, r = -0.3 }, RJ = { ln = 0.6 }, RH = { p = 1.0 }, LH = { p = 1.0 } },
		{ t = 0.35, RS = { p = 0.5, r = 0.3 }, LS = { p = 0.5, r = -0.3 }, RJ = { ln = 0.65 }, RH = { p = 1.05 }, LH = { p = 1.05 } },
		{ t = 0.45, RS = { p = 1.2, r = 0.4 }, LS = { p = 1.2, r = -0.4 }, RJ = { ln = 0.3 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
		{ t = 0.57, RS = { p = 1.9, r = 0.5 }, LS = { p = 1.9, r = -0.5 }, RJ = { ln = 0.0 }, RH = { p = 0.3 }, LH = { p = 0.3 } },
		{ t = 0.69, RS = { p = 2.6, r = 0.6 }, LS = { p = 2.6, r = -0.6 }, RJ = { ln = -0.3 }, RH = { p = 0.1 }, LH = { p = 0.1 } },
		{ t = 0.85, RS = { p = 3.0, r = 0.75 }, LS = { p = 3.0, r = -0.75 }, RJ = { ln = -0.5 }, RH = { p = -0.1, r = 0.15 }, LH = { p = -0.1, r = -0.15 } },
		{ t = 1.2, RS = { p = 2.95, r = 0.75 }, LS = { p = 2.95, r = -0.75 }, RJ = { ln = -0.45 } },
		{ t = 1.35 },
	},
	CSOffline = { -- s'accroupit, classeur levé à deux mains en l'air, l'abat genoux pliés
		{ t = 0 },
		{ t = 0.1, RS = { p = 2.0 }, LS = { p = 2.0 }, RJ = { ln = 0.4 }, RH = { p = 0.8 }, LH = { p = 0.8 } },
		{ t = 0.25, RS = { p = 3.2, r = -0.1 }, LS = { p = 3.2, r = 0.1 }, RJ = { ln = -0.55 }, RH = { p = 1.0 }, LH = { p = 0.3 } },
		{ t = 0.45, RS = { p = 3.25, r = -0.1 }, LS = { p = 3.25, r = 0.1 }, RJ = { ln = -0.6 }, RH = { p = 1.0 }, LH = { p = 0.35 } },
		{ t = 0.52, RS = { p = 0.5, y = 0.2 }, LS = { p = 0.5, y = -0.2 }, RJ = { ln = 1.1 }, RH = { p = 1.2 }, LH = { p = -0.4 } },
		{ t = 0.85, RS = { p = 0.55, y = 0.2 }, LS = { p = 0.55, y = -0.2 }, RJ = { ln = 1.0 }, RH = { p = 1.1 }, LH = { p = -0.4 } },
		{ t = 1.05 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main (repère bras droit)
------------------------------------------------------------------------
M.Props = {
	CSLaserPen = {
		{ Vector3.new(0.14, 0.14, 1.0), CFrame.new(0, -1.1, -0.4), STEEL },
		{ Vector3.new(0.16, 0.16, 0.3), CFrame.new(0, -1.1, -0.05), NAVY },
		{ Vector3.new(0.15, 0.15, 0.15), CFrame.new(0, -1.1, -0.93), LASER, BALL },
	},
	CSDeck = {
		{ Vector3.new(1.8, 0.12, 1.3), CFrame.new(0, -1.15, -0.6), WHITE },
		{ Vector3.new(1.82, 0.13, 0.28), CFrame.new(0, -1.15, -1.12), ROYAL },
		{ Vector3.new(0.25, 0.05, 0.4), CFrame.new(-0.45, -1.08, -0.4), ORANGE },
		{ Vector3.new(0.25, 0.05, 0.6), CFrame.new(0, -1.08, -0.5), TEAL },
		{ Vector3.new(0.25, 0.05, 0.8), CFrame.new(0.45, -1.08, -0.6), YELLOW },
	},
	CSClicker = {
		{ Vector3.new(0.28, 0.16, 0.65), CFrame.new(0, -1.1, -0.3), GREY },
		{ Vector3.new(0.14, 0.06, 0.14), CFrame.new(0, -1.01, -0.45), LASER },
		{ Vector3.new(0.12, 0.05, 0.12), CFrame.new(0, -1.01, -0.2), ROYAL2 },
	},
	CSBinder = {
		{ Vector3.new(2.5, 0.7, 2.0), CFrame.new(0, -1.3, -1.1), ROYAL },
		{ Vector3.new(2.3, 0.5, 1.9), CFrame.new(0.1, -1.3, -1.1), WHITE },
		{ Vector3.new(0.22, 0.74, 2.04), CFrame.new(-1.2, -1.3, -1.1), NAVY },
		{ Vector3.new(0.4, 0.5, 0.5), CFrame.new(-1.0, -1.3, -0.5), STEEL, CYL },
		{ Vector3.new(0.4, 0.5, 0.5), CFrame.new(-1.0, -1.3, -1.1), STEEL, CYL },
		{ Vector3.new(0.4, 0.5, 0.5), CFrame.new(-1.0, -1.3, -1.7), STEEL, CYL },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents (serveur) : revers de veste, pochette, oreillette, montre dorée, raie sur le côté
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
	prop(f, torso, Vector3.new(0.3, 1.1, 0.06), CFrame.new(-0.42, 0.45, -0.53) * CFrame.Angles(0, 0, -0.3), NAVY) -- revers
	prop(f, torso, Vector3.new(0.3, 1.1, 0.06), CFrame.new(0.42, 0.45, -0.53) * CFrame.Angles(0, 0, 0.3), NAVY)
	prop(f, torso, Vector3.new(0.34, 0.18, 0.07), CFrame.new(-0.6, 0.45, -0.55) * CFrame.Angles(0, 0, 0.25), ORANGE) -- pochette
	prop(f, torso, Vector3.new(0.12, 0.12, 0.08), CFrame.new(0.62, 0.55, -0.56), GOLD) -- pin
	prop(f, head, Vector3.new(1.28, 0.3, 1.22), CFrame.new(0, 0.6, 0.05), HAIR) -- raie sur le côté
	prop(f, head, Vector3.new(0.9, 0.28, 1.0), CFrame.new(0.2, 0.72, -0.05) * CFrame.Angles(0, 0, -0.18), HAIR)
	prop(f, head, Vector3.new(1.28, 0.5, 0.28), CFrame.new(0, 0.35, 0.55), HAIR)
	prop(f, head, Vector3.new(0.18, 0.3, 0.22), CFrame.new(0.66, 0.05, 0), GREY) -- oreillette
	local dot = prop(f, head, Vector3.new(0.06, 0.08, 0.08), CFrame.new(0.76, 0.1, 0), ROYAL2)
	dot.Material = Enum.Material.Neon
	local la = c:FindFirstChild("Left Arm")
	if la then
		prop(f, la, Vector3.new(1.06, 0.22, 1.06), CFrame.new(0, -0.55, 0), GOLD) -- montre
		prop(f, la, Vector3.new(0.3, 0.3, 0.06), CFrame.new(0, -0.55, -0.55), WHITE)
	end
end

-- arme fétiche : tablette avec graphique à la main gauche
M.Signature = { Hand = "Left", Build = function(f, a, prop)
	prop(f, a, Vector3.new(0.12, 1.2, 0.9), CFrame.new(0.05, -1.2, -0.35), NAVY)
	local scr = prop(f, a, Vector3.new(0.13, 1.05, 0.78), CFrame.new(0.06, -1.2, -0.35), ROYAL)
	scr.Material = Enum.Material.Neon
	prop(f, a, Vector3.new(0.14, 0.25, 0.12), CFrame.new(0.07, -1.5, -0.6), ORANGE)
	prop(f, a, Vector3.new(0.14, 0.42, 0.12), CFrame.new(0.07, -1.42, -0.42), TEAL)
	prop(f, a, Vector3.new(0.14, 0.6, 0.12), CFrame.new(0.07, -1.33, -0.24), YELLOW)
end }

-- Transformation : micro-casque, écran de projection flottant dans le dos, camembert holographique
function M.Transform(f, head, torso, c, prop)
	prop(f, head, Vector3.new(1.36, 0.12, 0.14), CFrame.new(0, 0.55, 0), NAVY) -- arceau
	prop(f, head, Vector3.new(0.14, 0.45, 0.14), CFrame.new(0.66, 0.3, 0), NAVY)
	prop(f, head, Vector3.new(0.16, 0.3, 0.3), CFrame.new(0.68, 0.05, 0), NAVY, CYL)
	prop(f, head, Vector3.new(0.06, 0.06, 0.7), CFrame.new(0.58, -0.15, -0.35) * CFrame.Angles(0, 0.5, 0), GREY)
	local mic = prop(f, head, Vector3.new(0.14, 0.14, 0.14), CFrame.new(0.38, -0.25, -0.62), ROYAL2, BALL)
	mic.Material = Enum.Material.Neon
	-- écran de projection
	local base = CFrame.new(0, 2.4, 1.5) * CFrame.Angles(0.12, 0, 0)
	prop(f, torso, Vector3.new(3.6, 2.2, 0.12), base, NAVY)
	local screen = prop(f, torso, Vector3.new(3.3, 1.9, 0.14), base, WHITE)
	screen.Name = "Screen"
	label(screen, "Q4 STRATEGY", ROYAL, Enum.NormalId.Back)
	for i = 1, 4 do
		local h = 0.25 + i * 0.25
		local b = prop(f, torso, Vector3.new(0.4, h, 0.06), base * CFrame.new(-1.1 + i * 0.45, -0.85 + h / 2, 0.1), CHART[i])
		b.Material = Enum.Material.Neon
	end
	-- camembert holographique au-dessus de l'épaule gauche
	local pie = prop(f, torso, Vector3.new(0.12, 1.3, 1.3), CFrame.new(-1.9, 1.9, 0) * CFrame.Angles(0, math.pi / 2, 0.3), ROYAL2, CYL)
	pie.Material = Enum.Material.Neon
	pie.Transparency = 0.35
	local slice = prop(f, torso, Vector3.new(0.6, 0.6, 0.14), CFrame.new(-1.9, 1.9, 0) * CFrame.Angles(0, 0, 0.3) * CFrame.new(0.32, 0.32, 0), ORANGE)
	slice.Material = Enum.Material.Neon
	local pl = Instance.new("PointLight")
	pl.Color = ROYAL2
	pl.Range = 10
	pl.Brightness = 1.6
	pl.Parent = screen
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

local function decorateDeck(part)
	local function add(size, cf, color, mat)
		local p = Instance.new("Part")
		p.Size = size
		p.Color = color
		p.Material = mat or Enum.Material.SmoothPlastic
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless, p.CastShadow = false, false, false, true, false
		p.Anchored = false
		p.CFrame = part.CFrame * cf
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = part, p
		w.Parent = p
		p.Parent = part
		return p
	end
	add(Vector3.new(2.45, 0.16, 0.35), CFrame.new(0, 0, -0.75), ROYAL)
	add(Vector3.new(0.35, 0.18, 0.5), CFrame.new(-0.6, 0.02, 0.4), ORANGE)
	add(Vector3.new(0.35, 0.18, 0.8), CFrame.new(0, 0.02, 0.25), TEAL)
	add(Vector3.new(0.35, 0.18, 1.1), CFrame.new(0.6, 0.02, 0.1), YELLOW)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(1.1, 0, 0), Vector3.new(-1.1, 0, 0)
	a0.Parent, a1.Parent = part, part
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.2
	tr.Color = ColorSequence.new(ROYAL2, ROYAL)
	tr.Transparency = NumberSequence.new(0.3, 1)
	tr.LightEmission = 0.6
	tr.Parent = part
end

M.Kinds = {
	-- Laser Pointer : visée (ligne rouge), puis rayon instantané sur la 1re cible en ligne (marque +5)
	CSLaser = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		Kit.fx({ id = "CS_Aim", a = attacker, dir = dir, range = cfg.Range, dur = cfg.Windup })
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local origin = root.Position + Vector3.new(0, 0.8, 0)
		local victim = Kit.firstInLine(attacker, root.Position, dir, cfg.Range, cfg.Width)
		if victim and Kit.isProtected(victim) then
			victim = nil
		end
		local to = victim and Kit.root(victim).Position or Kit.safePoint(origin, origin + dir * cfg.Range, 0.5)
		Kit.fx({ id = "CS_Zap", a = attacker, from = origin + dir * 1.5, to = to, hit = victim ~= nil })
		if victim then
			api.hit(attacker, victim, cfg, dir)
		end
	end,

	-- Let's Circle Back : diapo-boomerang (aller puis retour vers le lanceur, deux séries de coups)
	CSBoomerang = function(attacker, cfg, aim, api)
		task.wait(0.17)
		if not ready(api, attacker) then
			return
		end
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local start = root.Position + Vector3.new(0, 0.6, 0) + dir * 2
		local stop = Kit.safePoint(start, start + dir * cfg.Out, 1.5)
		local part = Kit.sPart({ Name = "Projectile", Size = Vector3.new(2.4, 0.15, 1.8), Color = WHITE })
		part.CFrame = CFrame.new(start)
		decorateDeck(part)
		local outSet, backSet = {}, {}
		local pos, phase, spin, t0 = start, "out", 0, os.clock()
		while part.Parent and os.clock() - t0 < 3 do
			local dt = task.wait()
			spin += dt * 16
			if phase == "out" then
				local d = stop - pos
				local stepLen = cfg.Speed * dt
				if d.Magnitude <= stepLen then
					pos = stop
					phase = "back"
				else
					pos += d.Unit * stepLen
				end
			else
				if not root.Parent then
					break
				end
				local d = root.Position + Vector3.new(0, 0.6, 0) - pos
				local stepLen = cfg.Speed * 1.15 * dt
				if d.Magnitude <= math.max(stepLen, 2.2) then
					break
				end
				pos += d.Unit * stepLen
			end
			part.CFrame = CFrame.new(pos) * CFrame.Angles(0, spin, 0)
			for _, v in ipairs(Kit.inCircle(attacker, pos, cfg.Width / 2 + 1, 5)) do
				if phase == "out" and not outSet[v] then
					outSet[v] = true
					Kit.fx({ id = "CS_Thwap", p = Kit.root(v).Position, back = false })
					api.hit(attacker, v, cfg, dir)
				elseif phase == "back" and not backSet[v] then
					backSet[v] = true
					local toMe = api.flat(root.Position - Kit.root(v).Position, -dir)
					Kit.fx({ id = "CS_Thwap", p = Kit.root(v).Position, back = true })
					api.hit(attacker, v, cfg, toMe, cfg.Back)
				end
			end
		end
		Kit.fx({ id = "CS_Catch", p = pos, a = attacker })
		part:Destroy()
	end,

	-- Buzzword Blast : cône de lettres géantes, étourdit
	CSBuzzword = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		Kit.fx({ id = "CS_ConeTele", p = Kit.ground(root.Position), dir = dir, range = cfg.Range, angle = cfg.Angle, dur = cfg.Windup, a = attacker })
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local word = cfg.Words[Kit.rng:NextInteger(1, #cfg.Words)]
		local c = root.Position
		Kit.fx({ id = "CS_Buzz", p = c, dir = dir, range = cfg.Range, angle = cfg.Angle, word = word, a = attacker })
		local cosA = math.cos(math.rad(cfg.Angle / 2))
		for _, v in ipairs(Kit.enemies(attacker)) do
			local to = Kit.root(v).Position - c
			if not Kit.isProtected(v) and to.Magnitude <= cfg.Range and math.abs(to.Y) < 8 and (Kit.flat(to):Dot(dir) >= cosA or to.Magnitude < 3) then
				if api.hit(attacker, v, cfg, Kit.flat(to, dir), { Words = { word } }) == "Hit" then
					Kit.fx({ id = "CS_Confused", v = v, dur = cfg.Stun })
				end
			end
		end
	end,

	-- Paradigm Shift : diapo géante qui tombe puis balaie tout devant comme un mur
	CSSlideWall = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local g = Kit.ground(root.Position)
		local dist = (Kit.safePoint(root.Position, root.Position + dir * cfg.Distance, 2) - root.Position).Magnitude
		local cf = CFrame.lookAt(g, g + dir)
		Kit.fx({ id = "CS_WallTele", cf = cf, w = cfg.Width, len = dist, dur = cfg.Windup, a = attacker })
		Kit.fx({ id = "CS_Wall", cf = cf, w = cfg.Width, dist = dist, time = cfg.Time, windup = cfg.Windup, a = attacker })
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local hitSet = {}
		local t0 = os.clock()
		local rcf = cf * CFrame.new(0, 3, 0)
		while os.clock() - t0 < cfg.Time + 0.05 do
			local a = math.min(1, (os.clock() - t0) / cfg.Time)
			local front = 2 + (dist - 2) * a
			for _, v in ipairs(Kit.inRect(attacker, rcf, cfg.Width, front + 1.5, 6)) do
				if not hitSet[v] then
					hitSet[v] = true
					Kit.fx({ id = "CS_WallHit", p = Kit.root(v).Position, look = dir })
					api.hit(attacker, v, cfg, dir)
				end
			end
			task.wait()
		end
	end,

	-- Exponential Growth : barres qui jaillissent l'une après l'autre en ligne, de plus en plus hautes
	CSGrowth = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local g = Kit.ground(root.Position)
		local maxLen = (Kit.safePoint(root.Position, root.Position + dir * (cfg.Bars * cfg.Gap + 2), 2) - root.Position).Magnitude
		local n = math.clamp(math.floor((maxLen - 1) / cfg.Gap), 1, cfg.Bars)
		Kit.fx({ id = "CS_GrowthTele", cf = CFrame.lookAt(g + dir * 1.5, g + dir * 2.5), w = cfg.Radius * 2, len = n * cfg.Gap + 1.5, dur = cfg.Windup, a = attacker })
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local hitSet = {}
		for i = 1, n do
			local p = Kit.ground(g + dir * (i * cfg.Gap) + Vector3.new(0, 3, 0))
			Kit.fx({ id = "CS_Bar", p = p, i = i, n = n, look = dir, a = attacker })
			for _, v in ipairs(Kit.inCircle(attacker, p + Vector3.new(0, 3, 0), cfg.Radius, 6)) do
				if not hitSet[v] then
					hitSet[v] = true
					api.hit(attacker, v, cfg, dir, { Launch = Vector3.new(4, 38 + i * 6, 0) })
				end
			end
			task.wait(cfg.Interval)
		end
	end,

	-- Let's Take This Offline : bond sur la cible devant, classeur géant qui plaque au sol
	CSOffline = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local target = frontTarget(attacker, dir, cfg.Range)
		local dest = target and Kit.root(target).Position or (root.Position + dir * cfg.Offset)
		dest = Kit.safePoint(root.Position, dest, 2.5)
		local land = Kit.ground(dest)
		Kit.fx({ id = "Telegraph", p = land, r = cfg.Radius, dur = cfg.Rise + 0.2, a = attacker })
		Kit.fx({ id = "CS_Leap", a = attacker, p = land })
		Kit.leap(attacker, dest, cfg.Up, cfg.Rise)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local c = Kit.ground(root.Position)
		Kit.fx({ id = "CS_Binder", p = c, r = cfg.Radius, a = attacker, look = dir })
		for _, v in ipairs(Kit.inCircle(attacker, c + Vector3.new(0, 3, 0), cfg.Radius, 7)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - c, dir))
		end
	end,
}

------------------------------------------------------------------------
-- Passif (serveur) : Move the Needle (KPI)
------------------------------------------------------------------------
local KPI_MAX, KPI_BONUS = 5, 0.04
function M.ServerInit(api)
	local CombatService = api.CombatService
	table.insert(CombatService.damageMods, function(p)
		local v, a = p.victim, p.attacker
		if (p.damage or 0) <= 0 then
			return
		end
		if a and a ~= v and p.category ~= "Ultimate" and a:GetAttribute("CharacterName") == "Consultant" then
			local k = a:GetAttribute("CSKPI") or 0
			if k > 0 then
				p.damage = math.floor(p.damage * (1 + KPI_BONUS * k) * 10 + 0.5) / 10
			end
			if k < KPI_MAX then
				a:SetAttribute("CSKPI", k + 1)
			end
		end
		if v and v ~= a and v:GetAttribute("CharacterName") == "Consultant" and (p.category == "Heavy" or p.category == "Ultimate") then
			if (v:GetAttribute("CSKPI") or 0) > 0 then
				v:SetAttribute("CSKPI", 0)
				local vr = Kit.root(v)
				if vr then
					Kit.fx({ id = "CS_Crash", p = vr.Position })
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

local function papers(pos, n, dist, life, colors)
	colors = colors or { WHITE, WHITE, ROYAL2 }
	for _ = 1, n do
		local dirv = Vector3.new(Kit.rng:NextNumber(-1, 1), Kit.rng:NextNumber(0, 1), Kit.rng:NextNumber(-1, 1))
		if dirv.Magnitude < 0.1 then
			dirv = Vector3.yAxis
		end
		local p = Kit.part({ Size = Vector3.new(0.8, 0.05, 1.05), CFrame = CFrame.new(pos) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Color = colors[Kit.rng:NextInteger(1, #colors)] })
		Kit.tween(p, life, { CFrame = CFrame.new(pos + dirv.Unit * dist * Kit.rng:NextNumber(0.5, 1)) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Transparency = 1 }, Enum.EasingStyle.Quad)
		Debris:AddItem(p, life + 0.05)
	end
end

local function handPos(c)
	local arm = c and c:FindFirstChild("Right Arm")
	return arm and (arm.CFrame * CFrame.new(0, -1.1, -0.9)).Position
end

local function letterPart(ch, cf, color)
	local p = Kit.part({ Size = Vector3.new(2.2, 2.6, 0.5), CFrame = cf, Color = color })
	local l1 = Kit.flatText(p, ch, WHITE, Enum.NormalId.Front)
	local l2 = Kit.flatText(p, ch, WHITE, Enum.NormalId.Back)
	return p, l1, l2
end

M.MoveFX = {
	LaserPointer = function(c, d, api) end,
	CircleBack = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 3.5, 0), "PER MY LAST EMAIL...", ROYAL2, 2.6, 0.8, 1)
		end
	end,
	Buzzword = function(c, d, api) end,
	ParadigmShift = function(c, d, api)
		api.afterimages(c, 0.4, ROYAL)
	end,
	GrowthChart = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			api.CartoonFX.implode(r.Position, 4, { ROYAL2, WHITE }, 8, 0.3)
		end
	end,
	TakeOffline = function(c, d, api)
		api.afterimages(c, 0.5, ROYAL)
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	Kit.setupClient()

	-- visée du pointeur laser : fine ligne rouge qui suit la main
	Kit.on("CS_Aim", function(d)
		local c = d.a
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		local beam = Kit.part({ Size = Vector3.new(0.08, 0.08, 1), Color = LASER, Material = Enum.Material.Neon, Transparency = 0.2 })
		local dot = Kit.part({ Shape = BALL, Size = Vector3.one * 0.5, Color = LASER, Material = Enum.Material.Neon })
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { c, workspace:FindFirstChild("FX") }
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			if el > d.dur or not r.Parent then
				conn:Disconnect()
				beam:Destroy()
				dot:Destroy()
				return
			end
			local from = handPos(c) or r.Position
			local hit = workspace:Raycast(from, d.dir * d.range, params)
			local to = hit and hit.Position or (from + d.dir * d.range)
			local len = (to - from).Magnitude
			beam.Size = Vector3.new(0.08, 0.08, len)
			beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
			beam.Transparency = (math.floor(el * 30) % 2 == 0) and 0.1 or 0.5
			dot.CFrame = CFrame.new(to)
		end)
		CartoonFX.sound("Electric", r.Position, 0.5)
	end)

	Kit.on("CS_Zap", function(d)
		local len = (d.to - d.from).Magnitude
		local core = Kit.part({ Size = Vector3.new(0.5, 0.5, len), CFrame = CFrame.lookAt(d.from, d.to) * CFrame.new(0, 0, -len / 2), Color = LASER, Material = Enum.Material.Neon })
		local glow = Kit.part({ Size = Vector3.new(1.3, 1.3, len), CFrame = core.CFrame, Color = Color3.fromRGB(255, 140, 140), Material = Enum.Material.Neon, Transparency = 0.6 })
		Kit.tween(core, 0.3, { Size = Vector3.new(0.05, 0.05, len), Transparency = 1 })
		Kit.tween(glow, 0.3, { Size = Vector3.new(0.1, 0.1, len), Transparency = 1 })
		Debris:AddItem(core, 0.35)
		Debris:AddItem(glow, 0.35)
		CartoonFX.sound("Electric", d.from, 1)
		CartoonFX.light(d.to, LASER, 14, 4, 0.3)
		CartoonFX.sparks(d.to, 12, LASER)
		if d.hit then
			CartoonFX.bigImpact(d.to, (d.to - d.from).Unit, 0.7, LASER)
			Kit.floatText(d.to + Vector3.new(0, 3.2, 0), "HIGHLIGHTED!", LASER, 2.4, 0.9, 1.2)
			local ring = Kit.part({ Shape = CYL, Size = Vector3.new(0.1, 6, 6), CFrame = CFrame.new(CartoonFX.groundPos(d.to) + Vector3.new(0, 0.12, 0)) * UP, Color = LASER, Material = Enum.Material.Neon, Transparency = 0.3 })
			Kit.tween(ring, 0.5, { Size = Vector3.new(0.1, 2, 2), Transparency = 1 })
			Debris:AddItem(ring, 0.55)
		end
		if Kit.mine(d.a) then
			CartoonFX.shake(0.25)
		end
	end)

	Kit.on("CS_Thwap", function(d)
		CartoonFX.sound(d.back and "Bonk" or "PlasticHit", d.p, 1)
		CartoonFX.sparks(d.p, 8, ROYAL2)
		CartoonFX.word(d.p + Vector3.new(0, 3.5, 0), d.back and "CIRCLE BACK!" or "THWAP!", 0.8, "Light")
		papers(d.p, 5, 3, 0.5)
	end)

	Kit.on("CS_Catch", function(d)
		CartoonFX.puff(d.p, 1.2)
		if Kit.mine(d.a) then
			Kit.floatText(d.p + Vector3.new(0, 2.5, 0), "CIRCLED BACK", ROYAL2, 2, 0.6, 1)
		end
	end)

	-- cône d'alerte : rayons au sol
	Kit.on("CS_ConeTele", function(d)
		local col = Kit.mine(d.a) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 70, 60)
		local n = 7
		for i = 0, n - 1 do
			local ang = math.rad(-d.angle / 2 + d.angle * i / (n - 1))
			local dv = CFrame.Angles(0, ang, 0) * d.dir
			local cf = CFrame.lookAt(d.p + Vector3.new(0, 0.1, 0), d.p + Vector3.new(0, 0.1, 0) + dv)
			local s = Kit.part({ Size = Vector3.new(0.5, 0.1, 0.5), CFrame = cf, Color = col, Transparency = 0.4 })
			Kit.tween(s, d.dur, { Size = Vector3.new(0.5, 0.1, d.range), CFrame = cf * CFrame.new(0, 0, -d.range / 2) }, Enum.EasingStyle.Linear)
			task.delay(d.dur, function()
				Kit.tween(s, 0.15, { Transparency = 1 })
			end)
			Debris:AddItem(s, d.dur + 0.2)
		end
	end)

	-- lettres géantes du mot à la mode qui jaillissent en éventail
	Kit.on("CS_Buzz", function(d)
		CartoonFX.sound("Whoosh", d.p, 1.3)
		CartoonFX.sound("BigImpact", d.p, 0.7)
		CartoonFX.airRing(d.p + d.dir * 2, d.dir, 6, ROYAL2, 0.35)
		CartoonFX.airRing(d.p + d.dir * 5, d.dir, 9, WHITE, 0.4)
		CartoonFX.word(d.p + Vector3.new(0, 4.5, 0) + d.dir * 2, d.word, 1.3, "Heavy")
		local letters = string.gsub(d.word, "[^%a]", "")
		local n = #letters
		for i = 1, n do
			local ch = string.sub(letters, i, i)
			local ang = math.rad(-d.angle / 2 + d.angle * (i - 0.5) / n)
			local dv = CFrame.Angles(0, ang, 0) * d.dir
			local from = d.p + dv * 1.5 + Vector3.new(0, 0.5, 0)
			local to = d.p + dv * d.range + Vector3.new(0, Kit.rng:NextNumber(-0.5, 2), 0)
			local p, l1, l2 = letterPart(ch, CFrame.lookAt(from, from - dv), CHART[(i - 1) % #CHART + 1])
			p.Size = Vector3.new(0.6, 0.7, 0.2)
			Kit.tween(p, 0.12, { Size = Vector3.new(2.2, 2.6, 0.5) }, Enum.EasingStyle.Back)
			Kit.tween(p, 0.55, { CFrame = CFrame.lookAt(to, to - dv) * CFrame.Angles(0, 0, Kit.rng:NextNumber(-0.6, 0.6)) }, Enum.EasingStyle.Quad)
			task.delay(0.4, function()
				Kit.tween(p, 0.2, { Transparency = 1 })
				Kit.tween(l1, 0.2, { TextTransparency = 1 })
				Kit.tween(l2, 0.2, { TextTransparency = 1 })
			end)
			Debris:AddItem(p, 0.65)
		end
		if Kit.mine(d.a) then
			CartoonFX.shake(0.4)
		end
	end)

	Kit.on("CS_Confused", function(d)
		local v = d.v
		local vr = v and v:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		pcall(CartoonFX.dizzy, v, d.dur)
		Kit.floatText(vr.Position + Vector3.new(0, 3.5, 0), "???", YELLOW, 2, d.dur, 0.8)
		-- points d'interrogation qui tournent
		local qs = {}
		for i = 1, 3 do
			local q = Kit.part({ Size = Vector3.new(0.6, 0.8, 0.1), Color = YELLOW, Transparency = 1 })
			Kit.flatText(q, "?", YELLOW, Enum.NormalId.Front)
			Kit.flatText(q, "?", YELLOW, Enum.NormalId.Back)
			qs[i] = q
			Debris:AddItem(q, d.dur)
		end
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			if el > d.dur or not vr.Parent then
				conn:Disconnect()
				return
			end
			for i, q in ipairs(qs) do
				if q.Parent then
					local a = el * 5 + i * 2.1
					q.CFrame = CFrame.new(vr.Position + Vector3.new(math.cos(a) * 1.4, 2.6, math.sin(a) * 1.4)) * CFrame.Angles(0, -a, 0)
				end
			end
		end)
	end)

	Kit.on("CS_WallTele", function(d)
		Kit.rectTelegraph(d.cf, d.w, d.len, d.dur, d.a)
	end)

	-- diapo géante : tombe du ciel devant le lanceur, puis balaie vers l'avant
	Kit.on("CS_Wall", function(d)
		local H = 8
		local stand = d.cf * CFrame.new(0, H / 2, -2)
		local parts = {}
		local function add(size, off, color, mat)
			local p = Kit.part({ Size = size, CFrame = stand * off * CFrame.new(0, 16, 0), Color = color, Material = mat or Enum.Material.SmoothPlastic })
			table.insert(parts, { p = p, off = off })
			return p
		end
		add(Vector3.new(d.w + 0.6, H + 0.6, 0.5), CFrame.new(0, 0, 0.1), NAVY)
		local face = add(Vector3.new(d.w, H, 0.55), CFrame.new(0, 0, 0), WHITE)
		add(Vector3.new(d.w, 1.4, 0.6), CFrame.new(0, H / 2 - 0.7, 0), ROYAL)
		for i = 1, 5 do
			local h = 0.8 + i * 0.85
			add(Vector3.new(1.4, h, 0.62), CFrame.new(-d.w / 2 + 1.6 + (i - 1) * 2.4, -H / 2 + 0.4 + h / 2, 0), CHART[i], Enum.Material.Neon)
		end
		local title = Kit.flatText(face, "PARADIGM SHIFT", ROYAL, Enum.NormalId.Back)
		title.Size = UDim2.fromScale(1, 0.25)
		local t1 = Kit.flatText(face, "PARADIGM SHIFT", ROYAL, Enum.NormalId.Front)
		t1.Size = UDim2.fromScale(1, 0.25)
		local function place(cf)
			for _, e in ipairs(parts) do
				e.p.CFrame = cf * e.off
			end
		end
		-- chute (pendant l'anticipation)
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			if el < d.windup then
				local a = el / d.windup
				place(stand * CFrame.new(0, 16 * (1 - a * a), 0))
			elseif el < d.windup + d.time then
				local a = (el - d.windup) / d.time
				place(stand * CFrame.new(0, 0, -(d.dist - 2) * a))
			else
				conn:Disconnect()
				local final = stand * CFrame.new(0, 0, -(d.dist - 2))
				place(final)
				for _, e in ipairs(parts) do
					Kit.tween(e.p, 0.35, { CFrame = final * CFrame.new(0, -H / 2, 0) * CFrame.Angles(-1.4, 0, 0) * CFrame.new(0, H / 2, 0) * e.off, Transparency = 1 })
					Debris:AddItem(e.p, 0.4)
				end
				for _, l in ipairs({ title, t1 }) do
					Kit.tween(l, 0.3, { TextTransparency = 1 })
				end
				CartoonFX.dust(final.Position - Vector3.new(0, H / 2, 0), 5)
			end
		end)
		task.delay(d.windup, function()
			local g = (stand * CFrame.new(0, -H / 2, 0)).Position
			CartoonFX.sound("GroundSlam", g, 1)
			CartoonFX.sound("Whoosh", g, 1.2)
			CartoonFX.shockwave(g + Vector3.new(0, 0.2, 0), d.w * 0.6, ROYAL)
			CartoonFX.dust(g, d.w * 0.5)
			CartoonFX.word(g + Vector3.new(0, H + 1.5, 0), "NEXT SLIDE!", 1.1, "Heavy")
			if Kit.mine(d.a) then
				CartoonFX.shake(0.6)
				CartoonFX.speedLines(0.4, ROYAL2)
			end
			-- traînée de feuilles au sol pendant le balayage
			for k = 1, 6 do
				task.delay(k * d.time / 6, function()
					local pp = (d.cf * CFrame.new(0, 0.5, -2 - (d.dist - 2) * k / 6)).Position
					papers(pp, 4, 3, 0.5)
				end)
			end
		end)
	end)

	Kit.on("CS_WallHit", function(d)
		CartoonFX.sound("PunchHeavy", d.p, 1)
		CartoonFX.bigImpact(d.p, d.look, 1.0, ROYAL)
		papers(d.p, 8, 4, 0.6)
	end)

	Kit.on("CS_GrowthTele", function(d)
		Kit.rectTelegraph(d.cf, d.w, d.len, d.dur, d.a)
	end)

	-- barre d'histogramme qui jaillit du sol
	Kit.on("CS_Bar", function(d)
		local h = 3 + d.i * 2.2
		local col = CHART[(d.i - 1) % #CHART + 1]
		local base = CFrame.lookAt(d.p, d.p + d.look)
		local bar = Kit.part({ Size = Vector3.new(3.6, 0.2, 3.6), CFrame = base * CFrame.new(0, 0.1, 0), Color = col })
		local cap = Kit.part({ Size = Vector3.new(3.8, 0.4, 3.8), CFrame = base * CFrame.new(0, 0.3, 0), Color = WHITE, Material = Enum.Material.Neon })
		Kit.tween(bar, 0.12, { Size = Vector3.new(3.6, h, 3.6), CFrame = base * CFrame.new(0, h / 2, 0) }, Enum.EasingStyle.Back)
		Kit.tween(cap, 0.12, { CFrame = base * CFrame.new(0, h + 0.2, 0) }, Enum.EasingStyle.Back)
		local lbl = Kit.flatText(bar, "+" .. tostring(d.i * 80) .. "%", WHITE, Enum.NormalId.Front)
		lbl.Rotation = 0
		local arrow
		if d.i == d.n then
			arrow = Kit.part({ Size = Vector3.new(1.2, 3, 1.2), CFrame = base * CFrame.new(0, h + 1.8, 0), Color = GOLD, Material = Enum.Material.Neon })
			local tip = Kit.part({ Shape = BALL, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = base * CFrame.new(0, h + 3.6, 0), Color = GOLD, Material = Enum.Material.Neon })
			Kit.tween(tip, 0.7, { Transparency = 1, Size = Vector3.one * 4 })
			Debris:AddItem(tip, 0.75)
			CartoonFX.word(d.p + Vector3.new(0, h + 3, 0), "STONKS!", 1.4, "Heavy")
			CartoonFX.sound("PowerUp", d.p, 1)
		end
		CartoonFX.sound("GroundSlam", d.p, 0.7 + d.i * 0.08)
		CartoonFX.sound("Uppercut", d.p, 0.9)
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), 4 + d.i * 0.6, col)
		CartoonFX.bigImpact(d.p + Vector3.new(0, 1, 0), Vector3.yAxis, 0.6 + d.i * 0.1, col)
		CartoonFX.debris(d.p, 5, { GREY, col }, 1, 0.6)
		Kit.floatText(d.p + Vector3.new(0, h + 1.5, 0), "+" .. tostring(d.i * 80) .. "%", col, 2, 0.8, 1.5)
		task.delay(0.65, function()
			Kit.tween(bar, 0.3, { Size = Vector3.new(3.6, 0.2, 3.6), CFrame = base * CFrame.new(0, 0.1, 0), Transparency = 1 })
			Kit.tween(cap, 0.3, { CFrame = base * CFrame.new(0, 0.3, 0), Transparency = 1 })
			Kit.tween(lbl, 0.3, { TextTransparency = 1 })
			if arrow then
				Kit.tween(arrow, 0.3, { Transparency = 1 })
			end
		end)
		Debris:AddItem(bar, 1)
		Debris:AddItem(cap, 1)
		if arrow then
			Debris:AddItem(arrow, 1)
		end
		if Kit.mine(d.a) then
			CartoonFX.shake(0.2 + d.i * 0.08)
		end
	end)

	Kit.on("CS_Leap", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 3.5, 0), "LET'S TAKE THIS OFFLINE.", ROYAL2, 3, 0.9, 1.5)
			CartoonFX.dust(r.Position - Vector3.new(0, 2.8, 0), 3)
		end
	end)

	-- classeur géant qui s'abat
	Kit.on("CS_Binder", function(d)
		local base = CFrame.lookAt(d.p, d.p + d.look)
		local cover = Kit.part({ Size = Vector3.new(7, 1.4, 5.4), CFrame = base * CFrame.new(0, 9, 0), Color = ROYAL })
		local pages = Kit.part({ Size = Vector3.new(6.6, 1.0, 5.2), CFrame = base * CFrame.new(0.2, 9, 0), Color = WHITE })
		local spine = Kit.part({ Size = Vector3.new(0.5, 1.5, 5.5), CFrame = base * CFrame.new(-3.5, 9, 0), Color = NAVY })
		local lbl = Kit.flatText(cover, "Q4 REVIEW", WHITE, Enum.NormalId.Top)
		local list = { cover, pages, spine }
		for _, p in ipairs(list) do
			local off = base:ToObjectSpace(p.CFrame) - Vector3.new(0, 9, 0)
			Kit.tween(p, 0.1, { CFrame = base * off * CFrame.new(0, 0.8, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		CartoonFX.sound("GroundSlam", d.p, 1.2)
		CartoonFX.sound("BigImpact", d.p, 1)
		task.delay(0.1, function()
			CartoonFX.bigImpact(d.p + Vector3.new(0, 0.5, 0), Vector3.new(0, -1, 0), 1.4, ROYAL)
			CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r * 1.2, ROYAL)
			CartoonFX.shockwave(d.p + Vector3.new(0, 0.3, 0), d.r * 0.7, WHITE)
			CartoonFX.cracks(d.p, 7, 5, 1.2)
			CartoonFX.debris(d.p, 8, { GREY, ROYAL, WHITE }, 1.2, 0.8)
			papers(d.p + Vector3.new(0, 1.5, 0), 26, d.r, 0.9)
			CartoonFX.word(d.p + Vector3.new(0, 5, 0), "OFFLINE!", 1.4, "Heavy")
			if Kit.mine(d.a) then
				CartoonFX.shake(1.0)
				CartoonFX.impactFrame(0.6)
			end
		end)
		task.delay(0.6, function()
			for _, p in ipairs(list) do
				Kit.tween(p, 0.3, { Transparency = 1 })
			end
			Kit.tween(lbl, 0.3, { TextTransparency = 1 })
		end)
		for _, p in ipairs(list) do
			Debris:AddItem(p, 1)
		end
	end)

	Kit.on("CS_Crash", function(d)
		CartoonFX.sound("SlideWhistle", d.p, 0.9)
		Kit.floatText(d.p + Vector3.new(0, 3.5, 0), "Q4 LOSSES!", LASER, 2.4, 1, 1.5)
		local arrow = Kit.part({ Size = Vector3.new(0.6, 2.4, 0.2), CFrame = CFrame.new(d.p + Vector3.new(1.5, 4, 0)) * CFrame.Angles(0, 0, 0.5), Color = LASER, Material = Enum.Material.Neon })
		Kit.tween(arrow, 0.6, { CFrame = CFrame.new(d.p + Vector3.new(2.5, 1, 0)) * CFrame.Angles(0, 0, 0.5), Transparency = 1 })
		Debris:AddItem(arrow, 0.65)
	end)

	-- passif : graphique de KPI au-dessus de chaque Consultant + aura holographique en transformation
	local charts = setmetatable({}, { __mode = "k" })
	local function chartFor(c)
		local head = c:FindFirstChild("Head")
		if not head then
			return nil
		end
		local bb = charts[c]
		if bb and bb.Parent == head then
			return bb
		end
		bb = Instance.new("BillboardGui")
		bb.Name = "CSKPIChart"
		bb.Size = UDim2.fromScale(1.6, 1.2)
		bb.StudsOffset = Vector3.new(2.1, 1.2, 0)
		bb.LightInfluence = 0
		bb.MaxDistance = 70
		bb.Parent = head
		local bg = Instance.new("Frame")
		bg.Size = UDim2.fromScale(1, 1)
		bg.BackgroundColor3 = NAVY
		bg.BackgroundTransparency = 0.25
		bg.Parent = bb
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.12, 0)
		cr.Parent = bg
		local st = Instance.new("UIStroke")
		st.Color = ROYAL2
		st.Thickness = 1.5
		st.Parent = bg
		for i = 1, KPI_MAX do
			local b = Instance.new("Frame")
			b.Name = "B" .. i
			b.AnchorPoint = Vector2.new(0, 1)
			b.Position = UDim2.fromScale(0.08 + (i - 1) * 0.175, 0.9)
			b.Size = UDim2.fromScale(0.13, 0.15 + i * 0.13)
			b.BorderSizePixel = 0
			b.Parent = bg
		end
		charts[c] = bb
		return bb
	end
	task.spawn(function()
		local n = 0
		while true do
			task.wait(0.2)
			n += 1
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "Consultant" and c:FindFirstChildOfClass("Humanoid") and c:FindFirstChildOfClass("Humanoid").Health > 0 then
					local bb = chartFor(c)
					if bb then
						local k = c:GetAttribute("CSKPI") or 0
						for i = 1, KPI_MAX do
							local b = bb.Frame:FindFirstChild("B" .. i)
							if b then
								b.BackgroundColor3 = (i <= k) and ((k >= KPI_MAX) and GOLD or Color3.fromRGB(90, 220, 110)) or GREY
								b.BackgroundTransparency = (i <= k) and 0 or 0.6
							end
						end
					end
					local r = c:FindFirstChild("HumanoidRootPart")
					if r and c:GetAttribute("Transformed") and n % 2 == 0 then
						local p = Kit.part({ Size = Vector3.new(0.5, Kit.rng:NextNumber(0.4, 1.2), 0.1), CFrame = CFrame.new(r.Position + Vector3.new(Kit.rng:NextNumber(-2, 2), -1.5, Kit.rng:NextNumber(-2, 2))), Color = CHART[Kit.rng:NextInteger(1, #CHART)], Material = Enum.Material.Neon, Transparency = 0.3 })
						Kit.tween(p, 1, { CFrame = p.CFrame + Vector3.new(0, 3, 0), Transparency = 1 })
						Debris:AddItem(p, 1.05)
					end
				else
					local bb = charts[c]
					if bb then
						bb:Destroy()
						charts[c] = nil
					end
				end
			end
		end
	end)
end

return M
