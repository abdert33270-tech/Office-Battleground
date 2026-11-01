--[[
	The Mascot — personnage complet (format : voir Modules/ContentLoader).
	Passif « Foam Padding » : -30 % de recul subi et -15 % de dégâts des coups lourds (BOING!).
	Attaques : We're #1! (uppercut au doigt en mousse qui envoie en l'air), T-Shirt Cannon (3 t-shirts tirés à la suite), Cheer Spin (toupie de pom-poms en mouvement).
	Transformation Halftime Show : Dance-Off (piste de disco : tout le monde danse, étourdi), Big Head Bounce (saut périlleux, la grosse tête plaque au sol), Grand Finale (pluie de feux d'artifice).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT

local RED = Color3.fromRGB(230, 45, 45)
local YELLOW = Color3.fromRGB(255, 215, 40)
local WHITE = Color3.fromRGB(250, 250, 250)
local DARK = Color3.fromRGB(25, 25, 30)
local BLUE = Color3.fromRGB(50, 120, 255)
local PARTY = { RED, YELLOW, WHITE, BLUE, Color3.fromRGB(255, 90, 200), Color3.fromRGB(80, 230, 120) }

local M = { Id = "Mascot", Order = 16 }

M.Character = {
	DisplayName = "The Mascot",
	Role = "Bouncy crowd-pleaser",
	Color = RED,
	Shirt = Color3.fromRGB(230, 45, 45), Pants = Color3.fromRGB(190, 35, 35), Tie = YELLOW,
	Passive = { Name = "Foam Padding", Desc = "The foam costume absorbs blows: 30% less knockback taken and 15% less damage from heavy hits." },
	Attacks = { "FoamFinger", "TShirtCannon", "CheerSpin" },
	Transformation = { Name = "Halftime Show", Desc = "Party hat, star shades and a spotlight that follows the star of the show.", Duration = 20, SpeedMultiplier = 1.15 },
	TransAttacks = { "DanceOff", "HeadBounce", "GrandFinale" },
}

M.Attacks = {
	FoamFinger = { Name = "We're #1!", Kind = "Melee", Desc = "Crouch and uppercut with your giant foam finger, launching the coworker in front sky-high.", Prop = "MSFoamFinger", Cooldown = 6, Anim = "MSFoamFinger", Sound = "Uppercut",
		Windup = 0.22, HitboxOffset = 3, HitboxSize = Vector3.new(5.5, 7, 6), Material = "Plastic",
		Damage = 9, Knockback = 6, Launch = Vector3.new(4, 55, 0), Stun = 1.0, Category = "Heavy", Power = 0.85, Words = { "WE'RE #1!", "BOOP!" } },
	TShirtCannon = { Name = "T-Shirt Cannon", Kind = "MSTShirt", Desc = "Fire 3 rolled-up T-shirts into the crowd, one after another.", Prop = "MSCannon", Cooldown = 7, Anim = "MSTShirt", Sound = "Throw",
		Count = 3, Interval = 0.15, Spread = 3, Speed = 120, Range = 75, Size = Vector3.new(1.0, 1.0, 1.8), Colors = { RED, WHITE, YELLOW },
		Damage = 4, Knockback = 18, KnockUp = 5, Stun = 0.45, Category = "Projectile", Power = 0.45, Words = { "FREE SHIRT!", "THWUMP!" } },
	CheerSpin = { Name = "Cheer Spin", Kind = "MSCheerSpin", Desc = "Spin like a pom-pom tornado for 1 s while moving faster, hitting everyone around you again and again.", Prop = "MSPomPom", Cooldown = 9, Anim = "MSCheerSpin", Sound = "Whoosh",
		Duration = 1.0, Ticks = 5, Radius = 6, SpeedBuff = 1.35, Damage = 2, Knockback = 6, KnockUp = 6, Stun = 0.4, Category = "Light", Power = 0.3, Words = { "GO!", "TEAM!", "FIGHT!" },
		Final = { Damage = 5, Knockback = 34, KnockUp = 14, Stun = 0.8, Category = "Heavy", Power = 0.8, Words = { "GOOO TEAM!" } } },
	DanceOff = { Name = "Dance-Off", Kind = "MSDanceOff", Desc = "Drop a disco floor around you: everyone on it is forced to dance (stunned) for 2 s.", Cooldown = 13, Anim = "MSDanceOff", Sound = "PowerUp",
		Windup = 0.4, Radius = 12, DanceTime = 2.0, Damage = 5, Knockback = 0, Stun = 2.0, Category = "Light", Power = 0.5, Words = { "DANCE-OFF!", "BOOGIE!" } },
	HeadBounce = { Name = "Big Head Bounce", Kind = "MSHeadBounce", Desc = "Front-flip high into the air and land head-first: your giant foam head pins everyone around.", Cooldown = 11, Anim = "MSHeadBounce", Sound = "Boing",
		Windup = 0.55, Forward = 10, JumpUp = 45, Radius = 9, Damage = 13, Knockback = 0, Stun = 1.2, Category = "Heavy", Power = 1.1, Words = { "BOING!", "HEADS UP!" }, Effects = { Pin = true } },
	GrandFinale = { Name = "Grand Finale", Kind = "MSFireworks", Desc = "Light the fuse: 8 fireworks shoot up and rain down on the area in front of you.", Cooldown = 14, Anim = "MSFireworks", Sound = "Explosion",
		Windup = 0.35, Offset = 14, Radius = 9, Rockets = 8, Gap = 0.12, Fall = 0.35, Blast = 5, MaxHitsPerTarget = 3,
		Damage = 4, Knockback = 16, KnockUp = 10, Stun = 0.5, Category = "Light", Power = 0.5, Words = { "BOOM!", "TA-DA!", "OOOH!" }, Effects = { Burn = { Ticks = 2, Damage = 1, Interval = 0.5 } } },
}

------------------------------------------------------------------------
-- Animations (une par attaque)
------------------------------------------------------------------------
local function cheerAnim()
	local f = { { t = 0 }, { t = 0.06, RS = { p = 2.8, r = -0.6 }, LS = { p = 2.8, r = -0.6 }, RJ = { tw = -0.4 } } }
	local t = 0.06
	for i = 1, 16 do
		t += 0.058
		local even = i % 2 == 0
		table.insert(f, { t = t, RS = { p = even and 2.9 or 1.6, r = -1.0 }, LS = { p = even and 1.6 or 2.9, r = -1.0 }, RJ = { tw = -0.4 + i * (4 * math.pi + 0.4) / 16, sd = even and 0.1 or -0.1 }, RH = { p = even and 0.5 or -0.2, r = -0.2 }, LH = { p = even and -0.2 or 0.5, r = -0.2 } })
	end
	table.insert(f, { t = t + 0.001, RS = { p = 1.6, r = -1.0 }, LS = { p = 2.9, r = -1.0 }, RJ = { tw = 0 } })
	table.insert(f, { t = t + 0.1, RS = { p = 2.9, r = -0.6 }, LS = { p = 2.9, r = -0.6 }, RJ = { ln = -0.2 }, RH = { p = 1.3 }, LH = { p = -0.2 } })
	table.insert(f, { t = t + 0.3, RS = { p = 2.8, r = -0.6 }, LS = { p = 2.8, r = -0.6 }, RJ = { ln = -0.15 }, RH = { p = 1.1 } })
	table.insert(f, { t = t + 0.45 })
	return f
end

local function discoAnim()
	local f = { { t = 0 } }
	local t = 0
	for i = 1, 6 do
		t += 0.18
		local up = i % 2 == 1
		table.insert(f, { t = t, RS = { p = up and 3.0 or 0.4, r = up and -0.5 or 0.4, y = up and 0.3 or -0.6 }, LS = { p = 0.3, r = 0.4 }, RJ = { sd = up and 0.2 or -0.12, tw = up and 0.3 or -0.2 }, RH = { r = up and -0.35 or 0 }, LH = { p = up and 0 or 0.4 } })
	end
	table.insert(f, { t = t + 0.2 })
	return f
end

local function victimDance()
	local f = { { t = 0 } }
	local t = 0
	for i = 1, 10 do
		t += 0.18
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = t, RS = { p = 1.2 + 0.9 * s, r = -0.8 }, LS = { p = 1.2 - 0.9 * s, r = -0.8 }, RJ = { sd = 0.18 * s, tw = 0.25 * s }, RH = { p = s > 0 and 0.6 or 0 }, LH = { p = s < 0 and 0.6 or 0 } })
	end
	table.insert(f, { t = t + 0.15 })
	return f
end

local function flipAnim()
	local tuck = { RS = { p = 1.7 }, LS = { p = 1.7 }, RH = { p = 1.5 }, LH = { p = 1.5 } }
	local function pose(ln)
		return { RS = tuck.RS, LS = tuck.LS, RH = tuck.RH, LH = tuck.LH, RJ = { ln = ln } }
	end
	local f = {
		{ t = 0 },
		{ t = 0.1, RS = { p = -0.6 }, LS = { p = -0.6 }, RJ = { ln = 0.45 }, RH = { p = 0.9 }, LH = { p = 0.9 } },
		{ t = 0.18, RS = { p = 3.1, r = -0.3 }, LS = { p = 3.1, r = -0.3 }, RJ = { ln = -0.3 }, RH = { p = -0.1 }, LH = { p = -0.1 } },
	}
	for i, ln in ipairs({ 1.57, 3.14, 4.71, 6.28 }) do
		local p = pose(ln)
		p.t = 0.18 + i * 0.08
		table.insert(f, p)
	end
	local p0 = pose(0)
	p0.t = 0.18 + 4 * 0.08 + 0.001
	table.insert(f, p0)
	table.insert(f, { t = 0.58, RS = { p = -0.9, r = -0.4 }, LS = { p = -0.9, r = -0.4 }, RJ = { ln = 1.15 }, RH = { p = 1.2 }, LH = { p = 0.6 } })
	table.insert(f, { t = 0.85, RS = { p = -0.85, r = -0.4 }, LS = { p = -0.85, r = -0.4 }, RJ = { ln = 1.05 }, RH = { p = 1.1 }, LH = { p = 0.55 } })
	table.insert(f, { t = 1.05 })
	return f
end

M.Anims = {
	MSFoamFinger = { -- s'accroupit doigt en bas, puis uppercut sauté de tout le corps
		{ t = 0 },
		{ t = 0.12, RS = { p = -0.5, r = -0.2 }, LS = { p = 0.8, y = 0.6 }, RJ = { ln = 0.5, tw = -0.35 }, RH = { p = 0.7 }, LH = { p = 0.7 } },
		{ t = 0.21, RS = { p = -0.6, r = -0.2 }, LS = { p = 0.9, y = 0.6 }, RJ = { ln = 0.55, tw = -0.4 }, RH = { p = 0.8 }, LH = { p = 0.8 } },
		{ t = 0.28, RS = { p = 3.15, y = 0.1 }, LS = { p = -0.5, r = -0.4 }, RJ = { ln = -0.5, tw = 0.35 }, RH = { p = -0.35 }, LH = { p = 0.55 } },
		{ t = 0.55, RS = { p = 3.05, y = 0.1 }, LS = { p = -0.45, r = -0.4 }, RJ = { ln = -0.4, tw = 0.3 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
		{ t = 0.8 },
	},
	MSTShirt = { -- canon calé à deux mains, trois reculs
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.55 }, LS = { p = 1.45, y = 0.5 }, RJ = { tw = 0.2, ln = 0.15 }, RH = { p = 0.35 }, LH = { p = -0.25 } },
		{ t = 0.15, RS = { p = 1.95 }, LS = { p = 1.85, y = 0.5 }, RJ = { tw = 0.1, ln = -0.25 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
		{ t = 0.26, RS = { p = 1.55 }, LS = { p = 1.45, y = 0.5 }, RJ = { tw = 0.2, ln = 0.15 } },
		{ t = 0.3, RS = { p = 1.95 }, LS = { p = 1.85, y = 0.5 }, RJ = { tw = 0.1, ln = -0.25 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
		{ t = 0.41, RS = { p = 1.55 }, LS = { p = 1.45, y = 0.5 }, RJ = { tw = 0.2, ln = 0.15 } },
		{ t = 0.45, RS = { p = 2.1 }, LS = { p = 2.0, y = 0.5 }, RJ = { tw = 0.05, ln = -0.4 }, RH = { p = -0.35 }, LH = { p = 0.45 } },
		{ t = 0.75 },
	},
	MSCheerSpin = cheerAnim(), -- 2 tours de toupie bras en V qui alternent, puis pose de pom-pom girl
	MSDanceOff = discoAnim(), -- pas de disco (doigt vers le ciel / vers le sol)
	MSVictimDance = victimDance(), -- victimes forcées de danser (bras qui battent, hanches)
	MSHeadBounce = flipAnim(), -- saut périlleux avant groupé, réception tête la première
	MSFireworks = { -- allume la mèche accroupi, puis acclame la foule bras levés
		{ t = 0 },
		{ t = 0.12, RS = { p = 1.0, y = 0.6 }, LS = { p = 0.7, y = 0.4 }, RJ = { ln = 0.45 }, RH = { p = 0.6 }, LH = { p = -0.1 } },
		{ t = 0.3, RS = { p = 1.1, y = 0.6 }, LS = { p = 0.75, y = 0.4 }, RJ = { ln = 0.5 }, RH = { p = 0.65 } },
		{ t = 0.4, RS = { p = 3.0, r = -0.5 }, LS = { p = 3.0, r = -0.5 }, RJ = { ln = -0.35 }, RH = { p = -0.1 }, LH = { p = 0.2 } },
		{ t = 0.6, RS = { p = 2.6, r = -0.7 }, LS = { p = 3.1, r = -0.4 }, RJ = { ln = -0.25, sd = 0.1 }, LH = { p = 0.5 } },
		{ t = 0.8, RS = { p = 3.1, r = -0.4 }, LS = { p = 2.6, r = -0.7 }, RJ = { ln = -0.25, sd = -0.1 }, RH = { p = 0.5 } },
		{ t = 1.0, RS = { p = 2.6, r = -0.7 }, LS = { p = 3.1, r = -0.4 }, RJ = { ln = -0.25, sd = 0.1 }, LH = { p = 0.5 } },
		{ t = 1.2 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main (repère bras droit)
------------------------------------------------------------------------
M.Props = {
	MSFoamFinger = {
		{ Vector3.new(1.3, 0.4, 0.9), CFrame.new(0, -1.05, 0), RED }, -- manchette
		{ Vector3.new(1.3, 1.4, 0.8), CFrame.new(0, -1.85, 0), YELLOW }, -- main en mousse
		{ Vector3.new(0.5, 1.9, 0.5), CFrame.new(0.25, -3.4, 0), YELLOW }, -- index levé
		{ Vector3.new(0.45, 0.8, 0.45), CFrame.new(-0.75, -1.9, -0.2) * CFrame.Angles(0, 0, 0.5), YELLOW }, -- pouce
		{ Vector3.new(0.06, 0.9, 0.6), CFrame.new(0.66, -1.85, 0), RED }, -- « #1 » côté
	},
	MSCannon = {
		{ Vector3.new(3.0, 0.85, 0.85), CFrame.new(0, -2.0, 0) * UP, Color3.fromRGB(150, 155, 165), CYL }, -- canon
		{ Vector3.new(0.3, 1.05, 1.05), CFrame.new(0, -3.45, 0) * UP, RED, CYL }, -- bouche
		{ Vector3.new(1.4, 0.6, 0.6), CFrame.new(0, -1.7, 0.6) * UP, RED, CYL }, -- réservoir d'air
		{ Vector3.new(0.3, 0.6, 0.3), CFrame.new(0, -1.2, -0.45), DARK }, -- poignée
		{ Vector3.new(0.75, 0.75, 0.75), CFrame.new(0, -3.3, 0), WHITE, BALL }, -- t-shirt qui dépasse
	},
	MSPomPom = {
		{ Vector3.one * 0.9, CFrame.new(0, -1.5, 0), RED, BALL },
		{ Vector3.one * 0.8, CFrame.new(0.4, -1.8, 0.2), YELLOW, BALL },
		{ Vector3.one * 0.8, CFrame.new(-0.4, -1.8, -0.2), WHITE, BALL },
		{ Vector3.one * 0.7, CFrame.new(0, -2.1, 0), RED, BALL },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents (serveur) : costume en mousse avec grosse tête ronde
------------------------------------------------------------------------
function M.Identity(f, head, torso, c, prop)
	-- grosse tête ronde en mousse (cache la vraie tête)
	prop(f, head, Vector3.one * 2.5, CFrame.new(0, 0.45, 0), YELLOW, BALL)
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.one * 0.8, CFrame.new(0.42 * s, 0.75, -1.0), WHITE, BALL) -- yeux
		prop(f, head, Vector3.one * 0.38, CFrame.new(0.42 * s, 0.72, -1.36), DARK, BALL) -- pupilles
		prop(f, head, Vector3.one * 0.95, CFrame.new(1.05 * s, 1.55, 0), RED, BALL) -- oreilles
		prop(f, head, Vector3.new(0.35, 0.14, 0.1), CFrame.new(0.42 * s, 1.22, -1.0) * CFrame.Angles(0, 0, -0.25 * s), DARK) -- sourcils
		prop(f, head, Vector3.new(0.4, 0.15, 0.2), CFrame.new(0.42 * s, -0.02, -1.08) * CFrame.Angles(0, 0, 0.45 * s), DARK) -- coins du sourire
	end
	prop(f, head, Vector3.new(0.55, 0.16, 0.2), CFrame.new(0, -0.15, -1.15), DARK) -- sourire
	prop(f, head, Vector3.one * 0.45, CFrame.new(0, 0.4, -1.22), RED, BALL) -- nez
	-- corps rembourré + numéro dans le dos
	prop(f, torso, Vector3.new(2.25, 2.1, 1.35), CFrame.new(0, -0.05, 0), RED)
	prop(f, torso, Vector3.new(1.4, 1.3, 0.1), CFrame.new(0, -0.2, -0.7), WHITE) -- ventre
	local back = prop(f, torso, Vector3.new(1.4, 1.5, 0.1), CFrame.new(0, 0, 0.7), YELLOW)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = back
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = RED
	l.Text = "1"
	l.Parent = gui
	-- gants et grosses chaussures
	for _, n in ipairs({ "Left Arm", "Right Arm" }) do
		local a = c:FindFirstChild(n)
		if a then
			prop(f, a, Vector3.new(1.15, 0.5, 1.15), CFrame.new(0, -0.8, 0), WHITE)
		end
	end
	for _, n in ipairs({ "Left Leg", "Right Leg" }) do
		local leg = c:FindFirstChild(n)
		if leg then
			prop(f, leg, Vector3.new(1.3, 0.6, 1.8), CFrame.new(0, -0.75, -0.3), YELLOW)
		end
	end
end

-- arme fétiche : doigt en mousse à la main gauche
M.Signature = { Hand = "Left", Build = function(f, a, prop)
	prop(f, a, Vector3.new(1.1, 1.2, 0.7), CFrame.new(0, -1.55, -0.1), YELLOW)
	prop(f, a, Vector3.new(0.42, 0.42, 1.5), CFrame.new(0, -1.25, -1.1), YELLOW)
	prop(f, a, Vector3.new(0.05, 0.8, 0.5), CFrame.new(-0.57, -1.55, -0.1), RED)
end }

-- Transformation : chapeau de fête, lunettes étoiles, projecteur au-dessus
function M.Transform(f, head, torso, c, prop)
	for i = 0, 4 do
		prop(f, head, Vector3.new(0.4, 1.0 - i * 0.2, 1.0 - i * 0.2), CFrame.new(0, 1.85 + i * 0.35, 0) * UP, PARTY[(i % #PARTY) + 1], CYL)
	end
	prop(f, head, Vector3.one * 0.45, CFrame.new(0, 3.65, 0), YELLOW, BALL)
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.8, 0.8, 0.1), CFrame.new(0.45 * s, 0.75, -1.42), Color3.fromRGB(255, 90, 200))
		prop(f, head, Vector3.new(0.8, 0.8, 0.1), CFrame.new(0.45 * s, 0.75, -1.43) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(255, 90, 200))
		prop(f, torso, Vector3.one * 1.0, CFrame.new(1.2 * s, 1.0, 0), PARTY[s > 0 and 2 or 4], BALL) -- épaulettes pom-pom
	end
	-- projecteur de stade qui flotte au-dessus de lui et l'éclaire
	local spot = prop(f, torso, Vector3.new(0.9, 1.5, 1.5), CFrame.new(0, 7.5, 0) * UP, DARK, CYL)
	spot.Name = "Spotlight"
	prop(f, torso, Vector3.new(0.1, 1.25, 1.25), CFrame.new(0, 7.02, 0) * UP, Color3.fromRGB(255, 245, 180), CYL)
	prop(f, torso, Vector3.new(0.15, 2.2, 0.15), CFrame.new(0, 8.3, 0), DARK)
	local sl = Instance.new("SpotLight")
	sl.Face = Enum.NormalId.Left
	sl.Angle = 70
	sl.Range = 18
	sl.Brightness = 3
	sl.Color = Color3.fromRGB(255, 240, 180)
	sl.Parent = spot
end

------------------------------------------------------------------------
-- Comportements serveur (Kinds)
------------------------------------------------------------------------
local function ready(api, c)
	return api.CharacterState.isAlive(c) and not api.CharacterState.isStunned(c)
end

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
	lv.Name = "MSBounce"
	lv.Attachment0 = kbAtt(root)
	lv.MaxForce = 1e6
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = v
	lv.Parent = root
	return lv
end

M.Kinds = {
	-- T-Shirt Cannon : 3 t-shirts roulés tirés à la suite
	MSTShirt = function(attacker, cfg, aim, api)
		task.wait(0.12)
		for i = 1, cfg.Count do
			if not ready(api, attacker) then
				return
			end
			local dir = CFrame.Angles(0, math.rad(Kit.rng:NextNumber(-cfg.Spread, cfg.Spread)), 0) * Kit.aimDir(attacker, aim)
			api.projectile(attacker, cfg, dir, cfg.Colors[(i - 1) % #cfg.Colors + 1])
			Kit.fx({ id = "MS_Muzzle", a = attacker })
			if i < cfg.Count then
				task.wait(cfg.Interval)
			end
		end
	end,

	-- Cheer Spin : toupie en mouvement (plus rapide), touche tout autour plusieurs fois
	MSCheerSpin = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		api.CharacterState.setSpeedMod(attacker, "MSSpin", cfg.SpeedBuff, cfg.Duration)
		Kit.fx({ id = "MS_Spin", a = attacker, dur = cfg.Duration, r = cfg.Radius })
		for i = 1, cfg.Ticks do
			task.wait(cfg.Duration / cfg.Ticks)
			if not ready(api, attacker) then
				api.CharacterState.setSpeedMod(attacker, "MSSpin", nil)
				return
			end
			local c = root.Position
			for _, v in ipairs(inDisc(attacker, c, cfg.Radius, 7)) do
				api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - c, root.CFrame.LookVector), i == cfg.Ticks and cfg.Final or nil)
			end
		end
	end,

	-- Dance-Off : piste de disco, tout le monde dessus danse (étourdi, figé)
	MSDanceOff = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local center = Kit.ground(root.Position)
		Kit.fx({ id = "Telegraph", p = center, r = cfg.Radius, dur = cfg.Windup, a = attacker })
		Kit.fx({ id = "MS_Disco", p = center, r = cfg.Radius, wind = cfg.Windup, dur = cfg.Windup + cfg.DanceTime, a = attacker })
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		for _, v in ipairs(inDisc(attacker, center, cfg.Radius, 8)) do
			if api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - center, root.CFrame.LookVector)) == "Hit" then
				Kit.hold(v, cfg.DanceTime)
				Kit.fx({ id = "MS_Dancing", v = v, dur = cfg.DanceTime })
			end
		end
	end,

	-- Big Head Bounce : saut périlleux et réception tête la première (plaque au sol)
	MSHeadBounce = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local landing = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * cfg.Forward, 2.5))
		Kit.fx({ id = "Telegraph", p = landing, r = cfg.Radius, dur = cfg.Windup + 0.1, a = attacker })
		local horiz = Vector3.new(landing.X - root.Position.X, 0, landing.Z - root.Position.Z)
		task.wait(0.1) -- accroupi
		-- arc déterministe (montée puis descente symétriques) : l'impact se fait au point annoncé,
		-- la position répliquée du joueur étant en retard côté serveur
		local lv = velocity(root, horiz / cfg.Windup + Vector3.new(0, cfg.JumpUp, 0))
		task.wait(cfg.Windup / 2)
		lv.VectorVelocity = horiz / cfg.Windup + Vector3.new(0, -cfg.JumpUp, 0)
		task.wait(cfg.Windup / 2)
		lv:Destroy()
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local c = landing + Vector3.new(0, 3, 0)
		Kit.fx({ id = "MS_Bounce", p = landing, r = cfg.Radius, a = attacker })
		for _, v in ipairs(inDisc(attacker, c, cfg.Radius, 7)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - c, dir))
		end
		-- petit rebond du mascotte
		local hop = velocity(root, Vector3.new(0, 28, 0))
		task.delay(0.12, function()
			hop:Destroy()
		end)
	end,

	-- Grand Finale : fusées qui montent puis retombent en pluie sur la zone devant
	MSFireworks = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local center = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 3))
		Kit.fx({ id = "Telegraph", p = center, r = cfg.Radius + 2, dur = cfg.Windup + 0.35, a = attacker })
		Kit.fx({ id = "MS_Launch", a = attacker, n = cfg.Rockets })
		task.wait(cfg.Windup)
		local hits = {}
		for i = 1, cfg.Rockets do
			if not api.CharacterState.isAlive(attacker) then
				return
			end
			local a = Kit.rng:NextNumber(0, math.pi * 2)
			local r = math.sqrt(Kit.rng:NextNumber()) * cfg.Radius
			local spot = Kit.ground(center + Vector3.new(math.cos(a) * r, 2, math.sin(a) * r))
			Kit.fx({ id = "MS_Rocket", p = spot, fall = cfg.Fall, r = cfg.Blast, a = attacker, i = i })
			task.delay(cfg.Fall, function()
				if not api.CharacterState.isAlive(attacker) then
					return
				end
				for _, v in ipairs(inDisc(attacker, spot, cfg.Blast, 7)) do
					if (hits[v] or 0) < cfg.MaxHitsPerTarget then
						hits[v] = (hits[v] or 0) + 1
						api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - spot, dir))
					end
				end
			end)
			task.wait(cfg.Gap)
		end
	end,
}

------------------------------------------------------------------------
-- Passif (serveur) : Foam Padding
------------------------------------------------------------------------
function M.ServerInit(api)
	table.insert(api.CombatService.damageMods, function(p)
		local v = p.victim
		if v and v:GetAttribute("CharacterName") == "Mascot" then
			p.knockback = (p.knockback or 5) * 0.7
			if p.up then
				p.up *= 0.8
			end
			if p.category == "Heavy" and (p.damage or 0) > 0 then
				p.damage *= 0.85
				local r = Kit.root(v)
				if r then
					Kit.fx({ id = "MS_Boing", p = r.Position })
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
local ProcAnim -- branché dans ClientInit

local function follow(part, target, offsetFn, dur)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not part.Parent or not target.Parent then
			conn:Disconnect()
			return
		end
		part.CFrame = target.CFrame * offsetFn(os.clock() - t0)
	end)
	Debris:AddItem(part, dur)
end

local function burst(pos, colors, n, dist, life)
	for i = 1, n do
		local d = Vector3.new(Kit.rng:NextNumber(-1, 1), Kit.rng:NextNumber(-0.4, 1), Kit.rng:NextNumber(-1, 1)).Unit
		local s = Kit.part({ Size = Vector3.new(0.25, 0.25, 1.4), CFrame = CFrame.lookAt(pos, pos + d), Color = colors[(i % #colors) + 1] })
		Kit.tween(s, life, { CFrame = CFrame.lookAt(pos + d * dist, pos + d * (dist + 1)), Size = Vector3.new(0.1, 0.1, 0.4), Transparency = 1 })
		Debris:AddItem(s, life + 0.03)
	end
end

M.MoveFX = {
	FoamFinger = function(c, d, api)
		task.delay(0.24, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if not r then
				return
			end
			local look = r.CFrame.LookVector
			local p = r.Position + look * 3 + Vector3.new(0, 1, 0)
			api.CartoonFX.bigImpact(p, Vector3.new(0, 1, 0), 1, YELLOW)
			local beam = Kit.part({ Shape = CYL, Size = Vector3.new(1, 3, 3), CFrame = CFrame.new(p) * UP, Color = YELLOW, Transparency = 0.3 })
			Kit.tween(beam, 0.3, { Size = Vector3.new(14, 0.4, 0.4), CFrame = CFrame.new(p + Vector3.new(0, 7, 0)) * UP, Transparency = 1 })
			Debris:AddItem(beam, 0.32)
			Kit.floatText(p + Vector3.new(0, 3, 0), "#1", RED, 3, 0.8, 4)
			burst(p, PARTY, 10, 5, 0.35)
		end)
	end,
	TShirtCannon = function(c, d, api) end,
	CheerSpin = function(c, d, api)
		api.trail(c, 1.0, PARTY, 0.5, 1)
	end,
	DanceOff = function(c, d, api) end,
	HeadBounce = function(c, d, api)
		task.delay(0.1, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.puff(r.Position - Vector3.new(0, 2.5, 0), 2.5)
				api.CartoonFX.sound("Boing", r.Position, 0.8)
			end
		end)
		api.afterimages(c, 0.55, YELLOW)
	end,
	GrandFinale = function(c, d, api)
		local arm = c:FindFirstChild("Right Arm")
		if arm then
			api.CartoonFX.sparks((arm.CFrame * CFrame.new(0, -1.2, 0)).Position, 10, Color3.fromRGB(255, 170, 40))
		end
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	ProcAnim = api.ProcAnim
	Kit.setupClient()

	Kit.on("MS_Muzzle", function(d)
		local arm = d.a and d.a:FindFirstChild("Right Arm")
		if not arm then
			return
		end
		local tip = (arm.CFrame * CFrame.new(0, -3.6, 0)).Position
		CartoonFX.puff(tip, 1.4)
		CartoonFX.sound("Throw", tip, 0.8)
		Kit.cubes(tip, 5, PARTY, 0.3, 3, 0.3)
	end)

	Kit.on("MS_Spin", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		Kit.floatText(r.Position + Vector3.new(0, 3.5, 0), "GO TEAM!", YELLOW, 2.4, 0.8, 1.5)
		for i, y in ipairs({ -2.2, -0.6, 1.0 }) do
			local n = 8
			for k = 1, n do
				local col = PARTY[((k + i) % #PARTY) + 1]
				local seg = Kit.part({ Size = Vector3.new(0.35, 0.35, 1.6), Color = col, Transparency = 0.25 })
				local rad = d.r * (0.45 + i * 0.15)
				follow(seg, r, function(t)
					local a = k / n * math.pi * 2 + t * 18 * (i % 2 == 0 and -1 or 1)
					return CFrame.new(0, y, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -rad)
				end, d.dur)
			end
		end
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < d.dur and r.Parent do
				Kit.cubes(r.Position, 3, PARTY, 0.35, d.r, 0.35)
				task.wait(0.1)
			end
			CartoonFX.shockwave(r.Position - Vector3.new(0, 2.7, 0), d.r + 2, RED)
		end)
	end)

	Kit.on("MS_Disco", function(d)
		CartoonFX.sound("PowerUp", d.p, 1)
		Kit.floatText(d.p + Vector3.new(0, 7, 0), "DANCE-OFF!", Color3.fromRGB(255, 90, 200), 4, 1.2, 1)
		-- dalles qui clignotent (disque découpé en grille)
		local tiles = {}
		local step = 3
		for x = -d.r, d.r, step do
			for z = -d.r, d.r, step do
				if x * x + z * z <= d.r * d.r then
					local t = Kit.part({ Size = Vector3.new(step - 0.2, 0.15, step - 0.2), CFrame = CFrame.new(d.p + Vector3.new(x, 0.12, z)), Color = PARTY[Kit.rng:NextInteger(1, #PARTY)], Transparency = 0.3 })
					table.insert(tiles, t)
				end
			end
		end
		local ball = Kit.part({ Shape = BALL, Size = Vector3.one * 2.4, CFrame = CFrame.new(d.p + Vector3.new(0, 11, 0)), Color = Color3.fromRGB(210, 215, 230) })
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < d.dur do
				for _, t in ipairs(tiles) do
					t.Color = PARTY[Kit.rng:NextInteger(1, #PARTY)]
				end
				ball.CFrame = ball.CFrame * CFrame.Angles(0, 0.6, 0)
				if os.clock() - t0 > d.wind then
					local p = d.p + Vector3.new(Kit.rng:NextNumber(-d.r, d.r) * 0.7, 0.3, Kit.rng:NextNumber(-d.r, d.r) * 0.7)
					local len = (ball.Position - p).Magnitude
					local beam = Kit.part({ Size = Vector3.new(0.3, 0.3, len), CFrame = CFrame.lookAt(ball.Position, p) * CFrame.new(0, 0, -len / 2), Color = PARTY[Kit.rng:NextInteger(1, #PARTY)], Transparency = 0.4 })
					Kit.tween(beam, 0.25, { Transparency = 1 })
					Debris:AddItem(beam, 0.27)
				end
				task.wait(0.15)
			end
			for _, t in ipairs(tiles) do
				Kit.tween(t, 0.3, { Transparency = 1 })
				Debris:AddItem(t, 0.32)
			end
			Kit.tween(ball, 0.3, { Transparency = 1 })
			Debris:AddItem(ball, 0.32)
		end)
		task.delay(d.wind, function()
			CartoonFX.shockwave(d.p + Vector3.new(0, 0.3, 0), d.r, Color3.fromRGB(255, 90, 200))
			if Kit.mine(d.a) then
				CartoonFX.shake(0.4)
			end
		end)
	end)

	Kit.on("MS_Dancing", function(d)
		local v = d.v
		if not v then
			return
		end
		if ProcAnim then
			ProcAnim.play(v, "MSVictimDance")
		end
		task.spawn(function()
			local t0 = os.clock()
			local words = { "DANCE!", "LA LA!", "BOOGIE!", "GROOVY!" }
			while os.clock() - t0 < d.dur and v.Parent do
				local r = v:FindFirstChild("HumanoidRootPart")
				if r then
					Kit.floatText(r.Position + Vector3.new(Kit.rng:NextNumber(-1.5, 1.5), 3, Kit.rng:NextNumber(-1.5, 1.5)), words[Kit.rng:NextInteger(1, #words)], PARTY[Kit.rng:NextInteger(1, #PARTY)], 1.6, 0.7, 1.5)
				end
				task.wait(0.35)
			end
		end)
	end)

	Kit.on("MS_Bounce", function(d)
		CartoonFX.sound("Boing", d.p, 1.3)
		CartoonFX.sound("GroundSlam", d.p, 0.9)
		CartoonFX.word(d.p + Vector3.new(0, 5, 0), "BOING!", 1.4, "Heavy")
		CartoonFX.bigImpact(d.p + Vector3.new(0, 1.5, 0), Vector3.new(0, -1, 0), 1.4, YELLOW)
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r * 1.15, RED)
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.3, 0), d.r * 0.7, YELLOW)
		Kit.cubes(d.p + Vector3.new(0, 0.6, 0), 18, PARTY, 0.6, 12, 0.5)
		if Kit.mine(d.a) then
			CartoonFX.shake(1)
		end
	end)

	Kit.on("MS_Launch", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		task.delay(0.3, function()
			for i = 1, d.n do
				task.delay(i * 0.04, function()
					local from = r.Position + Vector3.new(Kit.rng:NextNumber(-1, 1), 1, Kit.rng:NextNumber(-1, 1))
					local to = from + Vector3.new(Kit.rng:NextNumber(-6, 6), 40, Kit.rng:NextNumber(-6, 6))
					local rk = Kit.part({ Size = Vector3.new(0.4, 0.4, 1.4), CFrame = CFrame.lookAt(from, to), Color = PARTY[(i % #PARTY) + 1] })
					Kit.tween(rk, 0.45, { CFrame = CFrame.lookAt(to, to + (to - from)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
					Debris:AddItem(rk, 0.46)
					CartoonFX.sparks(from, 4, Color3.fromRGB(255, 170, 40))
				end)
			end
			CartoonFX.sound("Whistle", r.Position, 0.8)
		end)
	end)

	Kit.on("MS_Rocket", function(d)
		Kit.telegraph(d.p, d.r, d.fall, d.a)
		local col = PARTY[(d.i % #PARTY) + 1]
		local from = d.p + Vector3.new(Kit.rng:NextNumber(-4, 4), 40, Kit.rng:NextNumber(-4, 4))
		local rk = Kit.part({ Size = Vector3.new(0.5, 0.5, 1.8), CFrame = CFrame.lookAt(from, d.p), Color = col })
		Kit.tween(rk, d.fall, { CFrame = CFrame.lookAt(d.p + Vector3.new(0, 0.5, 0), d.p + (d.p - from)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(rk, d.fall)
		task.delay(d.fall, function()
			CartoonFX.sound("Explosion", d.p, 0.45)
			local flash = Kit.part({ Shape = BALL, Size = Vector3.one, Position = d.p + Vector3.new(0, 1.5, 0), Color = col, Transparency = 0.1 })
			Kit.tween(flash, 0.25, { Size = Vector3.one * d.r * 2, Transparency = 1 })
			Debris:AddItem(flash, 0.27)
			burst(d.p + Vector3.new(0, 1.5, 0), { col, WHITE, YELLOW }, 14, d.r + 1, 0.4)
			CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r, col)
			if Kit.mine(d.a) then
				CartoonFX.shake(0.25)
			end
		end)
	end)

	Kit.on("MS_Boing", function(d)
		Kit.floatText(d.p + Vector3.new(0, 3.5, 0), "BOING!", YELLOW, 1.8, 0.6, 1.5)
	end)

	-- aura de transformation : confettis et projecteur qui pulse
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "Mascot" and c:GetAttribute("Transformed") then
					local r = c:FindFirstChild("HumanoidRootPart")
					if r then
						Kit.cubes(r.Position + Vector3.new(0, 4, 0), 2, PARTY, 0.3, 4, 0.8)
					end
					local fx = c:FindFirstChild("TransformFX")
					local spot = fx and fx:FindFirstChild("Spotlight")
					local sl = spot and spot:FindFirstChildOfClass("SpotLight")
					if sl then
						sl.Brightness = 3 + math.sin(os.clock() * 6)
					end
				end
			end
		end
	end)
end

return M
