--[[
	The AI Assistant — personnage PREMIUM (format : voir Modules/ContentLoader).
	L'IA holographique du bureau : hologrammes cyan, glitchs, « Did you mean...? », fenêtres pop-up, drones.
	Passif « Spam Filter » : les projectiles lui font 30 % de dégâts en moins (« SPAM FILTERED »).
	Attaques : Pop-Up Ad (fenêtre géante qui traverse tout le monde et aveugle), Autocomplete (combo au clavier
	           holographique, ENTER final qui expulse), Drone Swarm (3 drones en orbite qui zappent l'ennemi le plus proche).
	Transformation Full Sentience : Did You Mean...? (sélectionne la 1re cible en ligne, la tire vers elle et la
	           « corrige » : PLAQUE au sol), Deep Learning Laser (rayon des yeux qui balaie 80°), CAPTCHA (grille 3x3 au sol :
	           les cases qui contiennent des ennemis sont frappées par un pilier de lumière).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)

local CYAN = Color3.fromRGB(60, 220, 255) -- couleur du perso (hologramme)
local HOLO = Color3.fromRGB(160, 240, 255)
local MAG = Color3.fromRGB(255, 70, 200)
local NAVY = Color3.fromRGB(25, 35, 70)
local WHITE = Color3.fromRGB(245, 250, 255)
local LIME = Color3.fromRGB(110, 255, 150)
local RED = Color3.fromRGB(255, 70, 70)
local SCREEN = Color3.fromRGB(15, 25, 45)
local GREY = Color3.fromRGB(190, 200, 215)
local HOLOS = { CYAN, HOLO, WHITE, MAG }

local SND = {
	Ping = "rbxassetid://122293143209564",
	Glitch = "rbxassetid://119121567196332",
	Error = "rbxassetid://133031003123734",
	Beep = "rbxassetid://81826580928228",
	Laser = "rbxassetid://87085224980395",
}

local M = { Id = "AIAssistant", Order = 20 }

M.Character = {
	DisplayName = "The AI Assistant",
	Role = "Holographic controller",
	Color = CYAN,
	Shirt = Color3.fromRGB(230, 240, 250), Pants = NAVY, Tie = CYAN,
	Passive = { Name = "Spam Filter", Desc = "Projectiles deal 30% less damage to her: incoming spam gets filtered." },
	Attacks = { "PopUpAd", "Autocomplete", "DroneSwarm" },
	Transformation = { Name = "Full Sentience", Desc = "Double halo, magenta eyes, holographic data wings and a cloud of floating windows.", Duration = 20, SpeedMultiplier = 1.15 },
	TransAttacks = { "DidYouMean", "DeepLearningLaser", "Captcha" },
}

M.Attacks = {
	PopUpAd = { Name = "Pop-Up Ad", Kind = "AIPopup", Desc = "Fire a giant pop-up window that flies THROUGH everyone and covers their screen.", Prop = "AIHoloHand", Cooldown = 7, Anim = "AIPopup", Sound = "Whoosh",
		Windup = 0.18, Speed = 68, Range = 55, Size = Vector3.new(4.2, 3, 0.3),
		Damage = 6, Knockback = 14, KnockUp = 4, Stun = 0.8, Category = "Projectile", Power = 0.5, Words = { "CLOSE [X]!", "SPAM!", "ADS!" }, Effects = { Blind = 1.2 } },
	Autocomplete = { Name = "Autocomplete", Kind = "Melee", Desc = "Swing a holographic keyboard 3 times, then smash ENTER to send them flying.", Prop = "AIKeyboard", Cooldown = 6, Anim = "AIAutocomplete", Sound = "Whoosh",
		Windup = 0.1, Hits = 4, Interval = 0.16, HitboxOffset = 3, HitboxSize = Vector3.new(6.5, 6, 7),
		Damage = 2.5, Knockback = 4, Stun = 0.5, Category = "Light", Power = 0.35, Material = "Plastic", Words = { "TAP!", "CLACK!", "TYPO!" },
		Final = { Damage = 6, Knockback = 42, KnockUp = 14, Stun = 0.9, Category = "Heavy", Power = 1.0, Words = { "ENTER!" } } },
	DroneSwarm = { Name = "Drone Swarm", Kind = "AIDrones", Desc = "Deploy 3 helper drones for 4s: they orbit you and zap the closest enemy.", Cooldown = 12, Anim = "AIDrones", Sound = "Electric",
		Duration = 4, Tick = 0.5, Range = 16, MaxZapsPerTarget = 6,
		Damage = 1.5, Knockback = 3, Stun = 0.25, Category = "Light", Power = 0.25, Words = { "ZAP!", "BZZT!", "PEW!" } },
	DidYouMean = { Name = "Did You Mean...?", Kind = "AIDidYouMean", Desc = "Select the first coworker in a line, drag them to you and CORRECT them: PINNED.", Prop = "AIHoloHand", Cooldown = 12, Anim = "AIDidYouMean", Sound = "Electric",
		Windup = 0.25, Range = 30, Width = 6, PullSpeed = 75,
		Damage = 12, Knockback = 0, Stun = 1.2, Category = "Heavy", Power = 1.1, Words = { "CORRECTED!", "DID YOU MEAN: DOWN?" }, Effects = { Pin = true } },
	DeepLearningLaser = { Name = "Deep Learning Laser", Kind = "AILaser", Desc = "Fire a laser from your visor and sweep it 80 degrees across the room.", Cooldown = 11, Anim = "AILaser", Sound = "Electric",
		Windup = 0.3, Duration = 1.2, Tick = 0.12, Range = 26, Width = 3.5, Sweep = 80, MaxHitsPerTarget = 6,
		Damage = 1.6, Knockback = 5, Stun = 0.3, Category = "Light", Power = 0.3, Words = { "LEARNING...", "BZZZT!", "TRAINING!" } },
	Captcha = { Name = "CAPTCHA", Kind = "AICaptcha", Desc = "Select all squares with ENEMIES: a 3x3 grid appears ahead and every square with someone in it gets struck from the sky.", Prop = "AIStylus", Cooldown = 14, Anim = "AICaptcha", Sound = "PowerUp",
		Offset = 12, Cell = 4, Windup = 0.7,
		Damage = 13, Knockback = 6, Launch = Vector3.new(4, 48, 0), Stun = 1.0, Category = "Heavy", GuardBreak = true, Power = 1.1, Words = { "VERIFIED!", "NOT A ROBOT?" } },
}

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local function laserAnim()
	local f = {
		{ t = 0 },
		{ t = 0.12, RS = { p = 2.3, y = 0.9, r = -0.3 }, LS = { p = 2.3, y = -0.9, r = 0.3 }, RJ = { ln = -0.35, tw = -0.6 }, RH = { p = 0.3 }, LH = { p = -0.3 } },
		{ t = 0.3, RS = { p = 2.4, y = 0.95, r = -0.3 }, LS = { p = 2.4, y = -0.95, r = 0.3 }, RJ = { ln = -0.2, tw = -0.6 }, RH = { p = 0.35 }, LH = { p = -0.35 } },
	}
	for i = 1, 6 do -- le buste suit le balayage (droite -> gauche)
		local k = i / 6
		table.insert(f, { t = 0.3 + k * 1.2, RS = { p = 2.4, y = 0.95, r = -0.3 }, LS = { p = 2.4, y = -0.95, r = 0.3 }, RJ = { ln = -0.2 + 0.05 * math.sin(i * 2), tw = -0.6 + 1.2 * k, sd = 0.05 * math.sin(i * 3) }, RH = { p = 0.35 - 0.7 * k }, LH = { p = -0.35 + 0.7 * k } })
	end
	table.insert(f, { t = 1.7, RS = { p = 0.6, r = -0.5 }, LS = { p = 0.6, r = 0.5 }, RJ = { ln = 0.35 } })
	table.insert(f, { t = 1.9 })
	return f
end

M.Anims = {
	AIPopup = { -- bras croisé sur le buste, puis grand geste qui « ouvre » et lance la fenêtre
		{ t = 0 },
		{ t = 0.12, RS = { p = 1.5, y = 1.1 }, LS = { p = 0.5, r = 0.4 }, RJ = { tw = 0.45, ln = 0.1 }, RH = { p = 0.25 }, LH = { p = -0.15 } },
		{ t = 0.2, RS = { p = 1.75, y = -0.35 }, LS = { p = 0.3, r = 0.5 }, RJ = { tw = -0.4, ln = 0.3 }, RH = { p = -0.35 }, LH = { p = 0.55 } },
		{ t = 0.45, RS = { p = 1.7, y = -0.3 }, LS = { p = 0.3, r = 0.5 }, RJ = { tw = -0.35, ln = 0.25 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
		{ t = 0.62 },
	},
	AIAutocomplete = { -- 3 swings de clavier qui alternent puis ENTER écrasé par-dessus la tête
		{ t = 0 },
		{ t = 0.06, RS = { p = 1.6, y = 1.2 }, LS = { p = 1.2, y = 0.8 }, RJ = { tw = 0.6, ln = 0.1 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.12, RS = { p = 1.7, y = -1.0 }, LS = { p = 1.2, y = -0.6 }, RJ = { tw = -0.55, ln = 0.25 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
		{ t = 0.28, RS = { p = 1.6, y = 1.1 }, LS = { p = 1.2, y = 0.8 }, RJ = { tw = 0.55, ln = 0.25 }, RH = { p = 0.4 }, LH = { p = -0.3 } },
		{ t = 0.44, RS = { p = 2.4, y = -0.9 }, LS = { p = 1.2, y = -0.6 }, RJ = { tw = -0.5, ln = 0.15 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
		{ t = 0.54, RS = { p = 3.2, y = 0.1 }, LS = { p = 3.0, y = -0.1 }, RJ = { tw = 0, ln = -0.45 }, RH = { p = -0.3 }, LH = { p = 0.3 } },
		{ t = 0.62, RS = { p = 0.8, y = 0.1 }, LS = { p = 0.8, y = -0.1 }, RJ = { ln = 0.75 }, RH = { p = -0.55 }, LH = { p = 0.95 } },
		{ t = 0.88, RS = { p = 0.85 }, LS = { p = 0.85 }, RJ = { ln = 0.65 }, RH = { p = -0.45 }, LH = { p = 0.85 } },
		{ t = 1.05 },
	},
	AIDrones = { -- bras levés qui s'ouvrent : déploiement
		{ t = 0 },
		{ t = 0.12, RS = { p = 1.2, y = 0.8 }, LS = { p = 1.2, y = -0.8 }, RJ = { ln = 0.3 }, RH = { p = 0.4 }, LH = { p = 0.4 } },
		{ t = 0.3, RS = { p = 3.0, r = -0.9 }, LS = { p = 3.0, r = 0.9 }, RJ = { ln = -0.4 }, RH = { p = -0.2 }, LH = { p = 0.2 } },
		{ t = 0.55, RS = { p = 2.0, r = -1.3 }, LS = { p = 2.0, r = 1.3 }, RJ = { ln = -0.25 } },
		{ t = 0.8, RS = { p = 1.9, r = -1.3 }, LS = { p = 1.9, r = 1.3 }, RJ = { ln = -0.2 } },
		{ t = 0.95 },
	},
	AIDidYouMean = { -- pointe la cible, la tire d'un coup sec, puis abat les deux mains (correction)
		{ t = 0 },
		{ t = 0.12, RS = { p = 1.65, y = 0.05 }, LS = { p = 0.4, r = 0.4 }, RJ = { tw = 0.3, ln = 0.05 }, RH = { p = 0.2 } },
		{ t = 0.25, RS = { p = 1.75 }, LS = { p = 0.4, r = 0.4 }, RJ = { tw = 0.35, ln = 0.1 }, RH = { p = 0.25 }, LH = { p = -0.15 } },
		{ t = 0.4, RS = { p = 0.7, y = 0.7 }, LS = { p = 0.5, r = 0.4 }, RJ = { tw = -0.35, ln = -0.25 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
		{ t = 0.6, RS = { p = 3.15, r = -0.2 }, LS = { p = 3.15, r = 0.2 }, RJ = { ln = -0.45 }, RH = { p = -0.2 }, LH = { p = 0.2 } },
		{ t = 0.72, RS = { p = 0.7 }, LS = { p = 0.7 }, RJ = { ln = 0.8 }, RH = { p = -0.45 }, LH = { p = 1.0 } },
		{ t = 0.98, RS = { p = 0.75 }, LS = { p = 0.75 }, RJ = { ln = 0.7 }, RH = { p = -0.4 }, LH = { p = 0.9 } },
		{ t = 1.15 },
	},
	AILaser = laserAnim(), -- doigts aux tempes, le buste suit le balayage du rayon
	AICaptcha = { -- dessine une coche dans l'air au stylet, puis « clic »
		{ t = 0 },
		{ t = 0.12, RS = { p = 2.4, y = 0.35 }, LS = { p = 0.6, y = -0.4 }, RJ = { tw = 0.15, ln = -0.1 } },
		{ t = 0.28, RS = { p = 1.5, y = 0.55 }, LS = { p = 0.6, y = -0.4 }, RJ = { tw = 0.25, ln = 0.05 } },
		{ t = 0.48, RS = { p = 3.0, y = -0.7, r = -0.3 }, LS = { p = 0.6, y = -0.4 }, RJ = { tw = -0.3, ln = -0.25 }, RH = { p = -0.2 }, LH = { p = 0.2 } },
		{ t = 0.62, RS = { p = 1.85, y = -0.1 }, LS = { p = 0.5 }, RJ = { tw = -0.05, ln = 0.3 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.78, RS = { p = 2.0, y = -0.1 }, LS = { p = 0.5 }, RJ = { ln = 0.15 } },
		{ t = 0.95, RS = { p = 2.9, r = -0.5 }, LS = { p = 0.4, r = 0.5 }, RJ = { ln = -0.2 } },
		{ t = 1.2 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main (repère bras droit)
------------------------------------------------------------------------
M.Props = {
	AIKeyboard = { -- clavier holographique tenu comme une batte
		{ Vector3.new(0.45, 0.7, 0.45), CFrame.new(0, -1.15, 0), NAVY },
		{ Vector3.new(1.1, 3.0, 0.2), CFrame.new(0, -2.9, -0.1), NAVY },
		{ Vector3.new(0.18, 2.7, 0.26), CFrame.new(-0.32, -2.95, -0.1), CYAN },
		{ Vector3.new(0.18, 2.7, 0.26), CFrame.new(0, -2.95, -0.1), HOLO },
		{ Vector3.new(0.18, 2.2, 0.26), CFrame.new(0.32, -2.7, -0.1), CYAN },
		{ Vector3.new(0.4, 0.5, 0.3), CFrame.new(0.3, -4.05, -0.1), MAG },
	},
	AIHoloHand = { -- gant holographique + petite fenêtre au bout des doigts
		{ Vector3.new(1.12, 0.5, 1.12), CFrame.new(0, -0.85, 0), CYAN },
		{ Vector3.new(1.2, 0.9, 0.06), CFrame.new(0, -1.75, -0.45), HOLO },
		{ Vector3.new(1.2, 0.2, 0.08), CFrame.new(0, -1.35, -0.45), CYAN },
		{ Vector3.new(0.16, 0.16, 0.1), CFrame.new(0.48, -1.35, -0.5), RED },
	},
	AIStylus = { -- stylet lumineux
		{ Vector3.new(0.16, 1.6, 0.16), CFrame.new(0, -1.5, -0.3), WHITE },
		{ Vector3.one * 0.26, CFrame.new(0, -2.35, -0.3), CYAN, BALL },
		{ Vector3.new(0.2, 0.3, 0.2), CFrame.new(0, -0.75, -0.3), CYAN },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents (serveur) : halo, visière, écouteurs, noyau lumineux, panneaux d'interface flottants
------------------------------------------------------------------------
local function halo(f, head, prop, r, y, col, tilt, n)
	n = n or 12
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		local len = 2 * math.pi * r / n * 1.08
		prop(f, head, Vector3.new(len, 0.1, 0.12), CFrame.Angles(tilt or 0, 0, 0) * CFrame.new(math.cos(a) * r, y, math.sin(a) * r) * CFrame.Angles(0, -(a + math.pi / 2), 0), col)
	end
end

local function panelText(part, text, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 60
	gui.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.FontFace = Font.new("rbxasset://fonts/families/PressStart2P.json")
	l.TextScaled = true
	l.TextColor3 = color or WHITE
	l.Text = text
	l.Parent = gui
	return l
end

function M.Identity(f, head, torso, c, prop)
	-- visière cyan + ligne lumineuse
	local visor = prop(f, head, Vector3.new(1.28, 0.32, 0.14), CFrame.new(0, 0.12, -0.56), CYAN)
	visor.Transparency = 0.15
	prop(f, head, Vector3.new(1.0, 0.06, 0.05), CFrame.new(0, 0.12, -0.65), WHITE)
	-- écouteurs
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.22, 0.62, 0.62), CFrame.new(0.66 * s, 0.05, 0), WHITE, CYL)
		prop(f, head, Vector3.new(0.24, 0.36, 0.36), CFrame.new(0.68 * s, 0.05, 0), CYAN, CYL)
	end
	prop(f, head, Vector3.new(0.08, 0.5, 0.08), CFrame.new(-0.66, -0.35, -0.25) * CFrame.Angles(0.8, 0, 0), WHITE) -- micro
	prop(f, head, Vector3.one * 0.14, CFrame.new(-0.62, -0.5, -0.5), CYAN, BALL)
	-- halo holographique
	halo(f, head, prop, 0.72, 1.05, CYAN)
	-- noyau lumineux sur la poitrine + circuits
	prop(f, torso, Vector3.one * 0.55, CFrame.new(0, 0.35, -0.5), CYAN, BALL)
	prop(f, torso, Vector3.new(0.06, 0.82, 0.82), CFrame.new(0, 0.35, -0.52) * ALONG_Z, NAVY, CYL)
	for _, s in ipairs({ -1, 1 }) do
		prop(f, torso, Vector3.new(0.06, 0.7, 0.04), CFrame.new(0.3 * s, -0.25, -0.52) * CFrame.Angles(0, 0, 0.35 * s), CYAN)
		prop(f, torso, Vector3.new(0.45, 0.06, 0.04), CFrame.new(0.62 * s, -0.55, -0.52), CYAN)
		prop(f, torso, Vector3.one * 0.12, CFrame.new(0.85 * s, -0.55, -0.53), HOLO, BALL)
	end
	prop(f, torso, Vector3.new(2.04, 0.2, 1.04), CFrame.new(0, -0.9, 0), NAVY) -- ceinture
	prop(f, torso, Vector3.new(0.4, 0.14, 0.06), CFrame.new(0, -0.9, -0.53), CYAN)
	-- panneaux d'interface « flottants » aux épaules
	for _, e in ipairs({ { -1, "98%" }, { 1, "ONLINE" } }) do
		local s = e[1]
		local panel = prop(f, torso, Vector3.new(0.95, 0.6, 0.05), CFrame.new(1.75 * s, 1.35, 0.25) * CFrame.Angles(0, -0.45 * s, 0.08 * s), CYAN)
		panel.Transparency = 0.45
		panelText(panel, e[2], WHITE)
		local bar = prop(f, torso, Vector3.new(0.95, 0.1, 0.06), CFrame.new(1.75 * s, 1.7, 0.25) * CFrame.Angles(0, -0.45 * s, 0.08 * s), HOLO)
		bar.Transparency = 0.2
	end
	-- bras et jambes : épaulettes, bracelets lumineux, bandes latérales
	for _, n in ipairs({ "Left Arm", "Right Arm" }) do
		local a = c:FindFirstChild(n)
		if a then
			prop(f, a, Vector3.new(1.1, 0.4, 1.1), CFrame.new(0, 0.82, 0), NAVY)
			prop(f, a, Vector3.new(1.06, 0.16, 1.06), CFrame.new(0, -0.55, 0), CYAN)
		end
	end
	for _, e in ipairs({ { "Left Leg", -1 }, { "Right Leg", 1 } }) do
		local leg = c:FindFirstChild(e[1])
		if leg then
			prop(f, leg, Vector3.new(0.05, 1.5, 0.2), CFrame.new(0.52 * e[2], 0.1, 0), CYAN)
			prop(f, leg, Vector3.new(1.06, 0.3, 1.1), CFrame.new(0, -0.86, -0.04), WHITE)
		end
	end
end

-- arme fétiche : tablette holographique (main gauche)
M.Signature = { Hand = "Left", Build = function(f, a, prop)
	prop(f, a, Vector3.new(1.3, 0.08, 1.0), CFrame.new(0, -1.1, -0.55), WHITE)
	local scr = prop(f, a, Vector3.new(1.14, 0.1, 0.84), CFrame.new(0, -1.1, -0.55), CYAN)
	scr.Transparency = 0.1
	prop(f, a, Vector3.new(0.6, 0.12, 0.08), CFrame.new(-0.15, -1.1, -0.75), WHITE)
	prop(f, a, Vector3.new(0.4, 0.12, 0.08), CFrame.new(-0.25, -1.1, -0.55), WHITE)
end }

-- Transformation Full Sentience : 2e halo magenta, yeux magenta, ailes de données, antenne
function M.Transform(f, head, torso, c, prop)
	halo(f, head, prop, 0.95, 1.3, MAG, 0.2, 16)
	local eyes = prop(f, head, Vector3.new(1.0, 0.12, 0.05), CFrame.new(0, 0.12, -0.645), MAG)
	eyes.Transparency = 0
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.2, 0.2, 0.06), CFrame.new(0.28 * s, 0.12, -0.66), WHITE)
		for i = 0, 2 do
			local w = prop(f, torso, Vector3.new(1.7 - i * 0.3, 0.55, 0.06), CFrame.new((1.35 + i * 0.2) * s, 0.85 - i * 0.6, 0.85 + i * 0.1) * CFrame.Angles(0, -0.55 * s, (0.35 - i * 0.3) * s), (i % 2 == 0) and CYAN or MAG)
			w.Transparency = 0.3
		end
	end
	prop(f, head, Vector3.new(0.08, 0.7, 0.08), CFrame.new(0.3, 0.95, 0.1) * CFrame.Angles(0, 0, -0.3), WHITE) -- antenne
	prop(f, head, Vector3.one * 0.22, CFrame.new(0.42, 1.3, 0.1), MAG, BALL)
	local core = prop(f, torso, Vector3.one * 0.7, CFrame.new(0, 0.35, -0.55), MAG, BALL)
	core.Name = "SentientCore"
end

------------------------------------------------------------------------
-- Comportements serveur (Kinds)
------------------------------------------------------------------------
local function ready(api, c)
	return api.CharacterState.isAlive(c) and not api.CharacterState.isStunned(c)
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
	return p
end

local POPUP_TEXT = { "YOU WON!!", "FREE KO!", "CLICK HERE", "HOT SINGLES", "UPDATE NOW" }

M.Kinds = {
	-- Pop-Up Ad : fenêtre géante qui traverse tout le monde (aveugle)
	AIPopup = function(attacker, cfg, aim, api)
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		Kit.fx({ id = "AI_PopupCast", a = attacker })
		Kit.projectile(attacker, {
			origin = root.Position + Vector3.new(0, 1.3, 0) + dir * 2.5, dir = dir, speed = cfg.Speed, range = cfg.Range, size = cfg.Size, color = WHITE,
			decorate = function(part)
				decor(part, Vector3.new(4.3, 0.6, 0.36), CFrame.new(0, 1.25, 0), CYAN)
				decor(part, Vector3.new(0.45, 0.42, 0.42), CFrame.new(1.75, 1.25, 0), RED)
				decor(part, Vector3.new(4.4, 3.1, 0.2), CFrame.new(0, 0, 0.12), NAVY)
				local btn = decor(part, Vector3.new(1.4, 0.5, 0.36), CFrame.new(-0.9, -0.95, 0), LIME)
				local btn2 = decor(part, Vector3.new(1.4, 0.5, 0.36), CFrame.new(0.9, -0.95, 0), GREY)
				Kit.flatText(part, POPUP_TEXT[Kit.rng:NextInteger(1, #POPUP_TEXT)], NAVY, Enum.NormalId.Front)
				Kit.flatText(btn, "OK", NAVY, Enum.NormalId.Front)
				Kit.flatText(btn2, "OK", NAVY, Enum.NormalId.Front)
			end,
			onHit = function(v, pos, vel)
				if api.hit(attacker, v, cfg, api.flat(vel, dir), { hitPos = pos }) == "Hit" then
					Kit.fx({ id = "AI_PopupHit", v = v, p = pos })
				end
				return true
			end,
		})
	end,

	-- Drone Swarm : 3 drones en orbite, zappent l'ennemi le plus proche toutes les 0,5 s
	AIDrones = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		Kit.fx({ id = "AI_Drones", a = attacker, dur = cfg.Duration })
		local zaps = {}
		task.wait(0.35)
		local t0 = os.clock()
		local i = 0
		while os.clock() - t0 < cfg.Duration - 0.35 do
			if not api.CharacterState.isAlive(attacker) or attacker:GetAttribute("CharacterName") ~= "AIAssistant" then
				break
			end
			i += 1
			local best, bd
			for _, v in ipairs(Kit.inCircle(attacker, root.Position, cfg.Range, 8)) do
				if (zaps[v] or 0) < cfg.MaxZapsPerTarget then
					local dd = (Kit.root(v).Position - root.Position).Magnitude
					if not bd or dd < bd then
						best, bd = v, dd
					end
				end
			end
			if best then
				zaps[best] = (zaps[best] or 0) + 1
				Kit.fx({ id = "AI_Zap", a = attacker, v = best, i = i })
				api.hit(attacker, best, cfg, api.flat(Kit.root(best).Position - root.Position, root.CFrame.LookVector))
			end
			task.wait(cfg.Tick)
		end
	end,

	-- Did You Mean...? : sélection de la 1re cible en ligne, tirée vers elle puis PLAQUÉE
	AIDidYouMean = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		Kit.fx({ id = "AI_Scan", a = attacker, dir = dir, range = cfg.Range, w = cfg.Width, dur = cfg.Windup })
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local v = Kit.firstInLine(attacker, root.Position, dir, cfg.Range, cfg.Width)
		if not v or Kit.isProtected(v) then
			Kit.fx({ id = "AI_NoResult", a = attacker, dir = dir })
			return
		end
		local vr = Kit.root(v)
		api.CharacterState.stun(v, 1.0)
		Kit.fx({ id = "AI_Select", a = attacker, v = v })
		local front = root.Position + Kit.flat(vr.Position - root.Position, dir) * 4
		local t = Kit.pull(v, front, cfg.PullSpeed, 0.5)
		task.wait(t + 0.15)
		if not api.CharacterState.isAlive(attacker) or not api.CharacterState.isAlive(v) then
			return
		end
		Kit.fx({ id = "AI_Correct", a = attacker, v = v, p = Kit.ground(vr.Position) })
		api.hit(attacker, v, cfg, api.flat(vr.Position - root.Position, dir))
	end,

	-- Deep Learning Laser : rayon des yeux qui balaie de droite à gauche (chaque cible touchée 6 fois max)
	AILaser = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir0 = Kit.aimDir(attacker, aim)
		api.CharacterState.setSpeedMod(attacker, "AILaser", 0.35, cfg.Windup + cfg.Duration)
		Kit.fx({ id = "AI_Laser", a = attacker, dir = dir0, wind = cfg.Windup, dur = cfg.Duration, sweep = cfg.Sweep, range = cfg.Range })
		task.wait(cfg.Windup)
		local hits = {}
		local t0 = os.clock()
		while os.clock() - t0 <= cfg.Duration do
			if not ready(api, attacker) then
				break
			end
			local el = os.clock() - t0
			local a = math.rad(-cfg.Sweep / 2 + cfg.Sweep * math.clamp(el / cfg.Duration, 0, 1))
			local dir = CFrame.Angles(0, a, 0) * dir0
			local origin = root.Position + Vector3.new(0, 0.5, 0)
			local len = (Kit.safePoint(origin, origin + dir * cfg.Range, 0.5) - origin).Magnitude
			local cf = CFrame.lookAt(origin, origin + dir)
			for _, v in ipairs(Kit.inRect(attacker, cf, cfg.Width, len, 5)) do
				if (hits[v] or 0) < cfg.MaxHitsPerTarget then
					hits[v] = (hits[v] or 0) + 1
					api.hit(attacker, v, cfg, dir)
				end
			end
			task.wait(cfg.Tick)
		end
		api.CharacterState.setSpeedMod(attacker, "AILaser", nil)
	end,

	-- CAPTCHA : grille 3x3 devant ; chaque case qui contient un ennemi est frappée d'un pilier de lumière
	AICaptcha = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local center = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 3))
		local cf = CFrame.lookAt(center, center + dir)
		Kit.fx({ id = "AI_Captcha", a = attacker, c = center, dir = dir, cell = cfg.Cell, wind = cfg.Windup })
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local half = cfg.Cell * 1.5
		local cells, victims = {}, {}
		for _, v in ipairs(Kit.enemies(attacker)) do
			if not Kit.isProtected(v) then
				local lp = cf:PointToObjectSpace(Kit.root(v).Position)
				if math.abs(lp.X) <= half and math.abs(lp.Z) <= half and lp.Y > -2 and lp.Y < 9 then
					local ix = math.clamp(math.floor(lp.X / cfg.Cell + 1.5), 0, 2)
					local iz = math.clamp(math.floor(lp.Z / cfg.Cell + 1.5), 0, 2)
					table.insert(cells, { ix, iz })
					table.insert(victims, v)
				end
			end
		end
		Kit.fx({ id = "AI_CaptchaStrike", a = attacker, c = center, dir = dir, cell = cfg.Cell, cells = cells })
		for _, v in ipairs(victims) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - root.Position, dir))
		end
	end,
}

------------------------------------------------------------------------
-- Passif (serveur) : Spam Filter
------------------------------------------------------------------------
function M.ServerInit(api)
	table.insert(api.CombatService.damageMods, function(p)
		local v = p.victim
		if v and v:GetAttribute("CharacterName") == "AIAssistant" and p.category == "Projectile" and (p.damage or 0) > 0 then
			p.damage *= 0.7
			if (v:GetAttribute("AISpamFx") or 0) < Kit.now() then
				v:SetAttribute("AISpamFx", Kit.now() + 0.6)
				Kit.fx({ id = "AI_Spam", v = v })
			end
		end
	end)
end

------------------------------------------------------------------------
-- Effets client
------------------------------------------------------------------------
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

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

-- petite fenêtre holographique (cadre + barre de titre + texte), tournée vers look
local function miniWindow(pos, look, w, h, text, col, life)
	local cf = CFrame.lookAt(pos, pos + look)
	local body = Kit.part({ Size = Vector3.new(w, h, 0.08), CFrame = cf, Color = SCREEN, Transparency = 0.15 })
	local bar = Kit.part({ Size = Vector3.new(w, h * 0.2, 0.1), CFrame = cf * CFrame.new(0, h * 0.4, 0), Color = col or CYAN })
	local x = Kit.part({ Size = Vector3.new(h * 0.14, h * 0.14, 0.12), CFrame = cf * CFrame.new(w * 0.42, h * 0.4, -0.01), Color = RED })
	Kit.flatText(body, text, col or CYAN, Enum.NormalId.Back)
	for _, p in ipairs({ body, bar, x }) do
		local s0 = p.Size
		p.Size = s0 * Vector3.new(0.1, 0.1, 1)
		Kit.tween(p, 0.15, { Size = s0 }, Enum.EasingStyle.Back)
		task.delay(life, function()
			Kit.tween(p, 0.15, { Size = s0 * Vector3.new(1, 0.05, 1), Transparency = 1 })
		end)
		Debris:AddItem(p, life + 0.17)
	end
	return body
end

-- câble de sélection (12 arêtes d'un cube) autour d'un modèle
local function selectionBox(model, color, dur)
	local edges = {}
	local s = Vector3.new(4.2, 6, 4.2)
	local list = {}
	for _, a in ipairs({ -1, 1 }) do
		for _, b in ipairs({ -1, 1 }) do
			table.insert(list, { Vector3.new(s.X, 0.12, 0.12), Vector3.new(0, a * s.Y / 2, b * s.Z / 2) })
			table.insert(list, { Vector3.new(0.12, s.Y, 0.12), Vector3.new(a * s.X / 2, 0, b * s.Z / 2) })
			table.insert(list, { Vector3.new(0.12, 0.12, s.Z), Vector3.new(a * s.X / 2, b * s.Y / 2, 0) })
		end
	end
	for _, e in ipairs(list) do
		table.insert(edges, { p = Kit.part({ Size = e[1], Color = color, Material = Enum.Material.Neon }), off = e[2] })
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local r = model and model:FindFirstChild("HumanoidRootPart")
		local el = os.clock() - t0
		if not r or el > dur then
			conn:Disconnect()
			for _, e in ipairs(edges) do
				e.p:Destroy()
			end
			return
		end
		local k = 1 + 0.08 * math.sin(el * 25)
		local base = CFrame.new(r.Position) * CFrame.Angles(0, el * 2, 0)
		for _, e in ipairs(edges) do
			e.p.CFrame = base * CFrame.new(e.off * k)
		end
	end)
end

M.MoveFX = {
	PopUpAd = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			for k = 1, 3 do
				task.delay(k * 0.05, function()
					local off = Vector3.new(Kit.rng:NextNumber(-2.5, 2.5), Kit.rng:NextNumber(1.5, 3.5), Kit.rng:NextNumber(-1, 1))
					miniWindow(r.Position + off, -r.CFrame.LookVector, 1.4, 0.9, ({ "AD", "SALE!", "WIN!" })[k], ({ CYAN, MAG, LIME })[k], 0.5)
				end)
			end
		end
	end,
	Autocomplete = function(c, d, api)
		local letters = { "A", "U", "T", "ENTER" }
		for i = 1, 4 do
			task.delay(0.1 + (i - 1) * 0.16, function()
				local r = c:FindFirstChild("HumanoidRootPart")
				if not r then
					return
				end
				local look = r.CFrame.LookVector
				local p = r.Position + look * 3 + Vector3.new(0, 0.8, 0)
				snd(SND.Beep, p, 0.6, 1 + i * 0.12)
				if i < 4 then
					api.CartoonFX.slashArc(CFrame.lookAt(r.Position, r.Position + look), 4.2, (i % 2 == 0) and MAG or CYAN, (i % 2 == 0) and 60 or -60, (i % 2 == 0) and -60 or 60, 0.14, 0, 0.6)
					Kit.floatText(p + Vector3.new(0, 1.5, 0), letters[i], CYAN, 1.6, 0.6, 1.5)
					Kit.cubes(p, 5, HOLOS, 0.3, 4, 0.3)
				else
					api.CartoonFX.bigImpact(p, look, 1.1, CYAN)
					Kit.floatText(p + Vector3.new(0, 2, 0), "ENTER", MAG, 3, 0.8, 2)
					Kit.cubes(p, 14, HOLOS, 0.45, 9, 0.45)
					snd(SND.Ping, p, 0.9, 1)
				end
			end)
		end
	end,
	DroneSwarm = function(c, d, api) end,
	DidYouMean = function(c, d, api) end,
	DeepLearningLaser = function(c, d, api) end,
	Captcha = function(c, d, api)
		task.delay(0.48, function()
			local arm = c:FindFirstChild("Right Arm")
			if arm then
				api.CartoonFX.sparks((arm.CFrame * CFrame.new(0, -2.3, -0.3)).Position, 8, LIME)
			end
		end)
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	Kit.setupClient()

	Kit.on("AI_PopupCast", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if r then
			snd(SND.Ping, r.Position, 0.9, 1)
			Kit.cubes(r.Position + r.CFrame.LookVector * 2.5 + Vector3.new(0, 1.3, 0), 8, HOLOS, 0.35, 5, 0.35)
		end
	end)

	Kit.on("AI_PopupHit", function(d)
		snd(SND.Error, d.p, 0.8, 1)
		local r = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if r then
			-- la victime est couverte de mini pop-ups
			for k = 1, 4 do
				local off = Vector3.new(Kit.rng:NextNumber(-1.8, 1.8), Kit.rng:NextNumber(-0.5, 2.5), Kit.rng:NextNumber(-1.8, 1.8))
				local cam = workspace.CurrentCamera
				local look = cam and (cam.CFrame.Position - (r.Position + off)) or Vector3.new(0, 0, 1)
				miniWindow(r.Position + off, -look, 1.2, 0.8, ({ "ERROR", "404", "AD", "SPAM" })[k], ({ RED, CYAN, MAG, LIME })[k], 0.9)
			end
		end
	end)

	-- Drone Swarm
	local drones = {}
	Kit.on("AI_Drones", function(d)
		local c = d.a
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		snd(SND.Beep, r.Position, 0.8, 0.8)
		Kit.floatText(r.Position + Vector3.new(0, 4, 0), "DEPLOYING HELPERS", CYAN, 3, 1, 1)
		local list = {}
		for k = 1, 3 do
			local parts = {}
			local function add(size, off, color, shape)
				local p = Kit.part({ Size = size, Color = color, Shape = shape or Enum.PartType.Block })
				table.insert(parts, { p = p, off = off })
				return p
			end
			local hub = add(Vector3.one * 0.7, CFrame.new(), WHITE, BALL)
			add(Vector3.new(0.12, 1.4, 1.4), UP, CYAN, CYL)
			add(Vector3.one * 0.3, CFrame.new(0, -0.05, -0.32), (k == 2) and MAG or CYAN, BALL)
			local rot1 = add(Vector3.new(1.6, 0.06, 0.18), CFrame.new(0, 0.42, 0), GREY)
			local rot2 = add(Vector3.new(0.18, 0.06, 1.6), CFrame.new(0, 0.42, 0), GREY)
			list[k] = { hub = hub, parts = parts, rot = { rot1, rot2 } }
		end
		local state = { list = list }
		drones[c] = state
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			local rr = c:FindFirstChild("HumanoidRootPart")
			if el > d.dur or not rr then
				conn:Disconnect()
				if drones[c] == state then
					drones[c] = nil
				end
				for _, dr in ipairs(list) do
					local pos = dr.hub.Position
					CartoonFX.puff(pos, 0.8)
					Kit.cubes(pos, 5, HOLOS, 0.25, 4, 0.3)
					for _, e in ipairs(dr.parts) do
						e.p:Destroy()
					end
				end
				return
			end
			local rise = math.min(1, el / 0.35)
			for k, dr in ipairs(list) do
				local a = el * 2.4 + k * math.pi * 2 / 3
				local pos = rr.Position + Vector3.new(math.cos(a) * 3.4, -1 + 4.2 * rise + math.sin(el * 5 + k) * 0.3, math.sin(a) * 3.4)
				local base = CFrame.new(pos) * CFrame.Angles(0, -a, 0.15 * math.sin(el * 4 + k))
				for _, e in ipairs(dr.parts) do
					e.p.CFrame = base * e.off
				end
				dr.rot[1].CFrame = base * CFrame.new(0, 0.42, 0) * CFrame.Angles(0, el * 30, 0)
				dr.rot[2].CFrame = base * CFrame.new(0, 0.42, 0) * CFrame.Angles(0, el * 30, 0)
			end
		end)
	end)

	Kit.on("AI_Zap", function(d)
		local st = drones[d.a]
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		local from
		if st then
			from = st.list[(d.i % 3) + 1].hub.Position
		else
			local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
			from = r and r.Position + Vector3.new(0, 3, 0) or vr.Position + Vector3.new(0, 4, 0)
		end
		local col = (d.i % 2 == 0) and MAG or CYAN
		CartoonFX.beam(from, vr.Position, 0.35, col, 0.15)
		CartoonFX.sparks(vr.Position, 8, col)
		snd(SND.Laser, from, 0.5, 1 + (d.i % 3) * 0.1)
	end)

	-- Did You Mean...?
	Kit.on("AI_Scan", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		snd(SND.Beep, r.Position, 0.7, 1.3)
		local base = CFrame.lookAt(CartoonFX.groundPos(r.Position), CartoonFX.groundPos(r.Position) + d.dir)
		Kit.rectTelegraph(base, d.w, d.range, d.dur, d.a)
		local bar = Kit.part({ Size = Vector3.new(d.w, 5, 0.12), CFrame = base * CFrame.new(0, 2.5, -1), Color = CYAN, Transparency = 0.6 })
		Kit.tween(bar, d.dur, { CFrame = base * CFrame.new(0, 2.5, -d.range) }, Enum.EasingStyle.Linear)
		Debris:AddItem(bar, d.dur + 0.02)
	end)

	Kit.on("AI_NoResult", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		snd(SND.Error, r.Position, 0.9, 1)
		miniWindow(r.Position + d.dir * 3 + Vector3.new(0, 3, 0), d.dir, 3.2, 1.6, "No results found.", RED, 1.0)
	end)

	Kit.on("AI_Select", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		snd(SND.Ping, vr.Position, 1, 1.1)
		selectionBox(d.v, CYAN, 0.7)
		Kit.floatText(vr.Position + Vector3.new(0, 4.5, 0), "Did you mean: HERE?", CYAN, 4, 1.1, 1)
		if r then
			local arm = d.a:FindFirstChild("Right Arm")
			local from = arm and (arm.CFrame * CFrame.new(0, -1.2, 0)).Position or r.Position
			-- câble de données qui tire la victime
			local line = Kit.part({ Size = Vector3.new(0.2, 0.2, 1), Color = CYAN, Material = Enum.Material.Neon })
			local t0 = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local v2 = d.v:FindFirstChild("HumanoidRootPart")
				local a2 = d.a:FindFirstChild("Right Arm")
				if os.clock() - t0 > 0.6 or not v2 or not a2 then
					conn:Disconnect()
					line:Destroy()
					return
				end
				local p0 = (a2.CFrame * CFrame.new(0, -1.2, 0)).Position
				local len = (v2.Position - p0).Magnitude
				line.Size = Vector3.new(0.2, 0.2, len)
				line.CFrame = CFrame.lookAt(p0, v2.Position) * CFrame.new(0, 0, -len / 2)
			end)
			Kit.cubes(from, 6, HOLOS, 0.3, 4, 0.3)
		end
	end)

	Kit.on("AI_Correct", function(d)
		local p = d.p
		CartoonFX.sound("GroundSlam", p, 1)
		snd(SND.Glitch, p, 0.8, 1)
		CartoonFX.bigImpact(p + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.3, CYAN)
		CartoonFX.shockwave(p + Vector3.new(0, 0.2, 0), 9, CYAN)
		CartoonFX.shockwave(p + Vector3.new(0, 0.3, 0), 5.5, MAG)
		CartoonFX.word(p + Vector3.new(0, 5, 0), "CORRECTED!", 1.4, "Heavy")
		Kit.cubes(p + Vector3.new(0, 1, 0), 20, HOLOS, 0.5, 10, 0.5)
		-- souligné rouge ondulé (faute d'orthographe) sous la victime
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		local side = r and Kit.flat(p - r.Position):Cross(Vector3.yAxis) or Vector3.xAxis
		for i = -4, 3 do
			local a = p + side * (i * 0.8) + Vector3.new(0, 0.1, 0)
			local b = p + side * ((i + 1) * 0.8) + Vector3.new(0, 0.1, 0) + Kit.flat(side:Cross(Vector3.yAxis)) * ((i % 2 == 0) and 0.5 or -0.5)
			local len = (b - a).Magnitude
			local s = Kit.part({ Size = Vector3.new(0.25, 0.1, len), CFrame = CFrame.lookAt(a, b) * CFrame.new(0, 0, -len / 2), Color = RED, Material = Enum.Material.Neon })
			Kit.tween(s, 1.2, { Transparency = 1 })
			Debris:AddItem(s, 1.22)
		end
		if Kit.mine(d.a) then
			CartoonFX.shake(1)
			CartoonFX.impactFrame(0.7)
		end
	end)

	-- Deep Learning Laser
	Kit.on("AI_Laser", function(d)
		local c = d.a
		local head = c and c:FindFirstChild("Head")
		if not head then
			return
		end
		snd(SND.Beep, head.Position, 0.8, 0.6)
		Kit.floatText(head.Position + Vector3.new(0, 2.5, 0), "TRAINING MODEL...", CYAN, 3, 1, 1)
		local charge = Kit.part({ Shape = BALL, Size = Vector3.one * 0.2, Color = HOLO, Material = Enum.Material.Neon })
		local beam = Kit.part({ Size = Vector3.new(0.9, 0.9, 1), Color = CYAN, Material = Enum.Material.Neon, Transparency = 1 })
		local core = Kit.part({ Size = Vector3.new(0.35, 0.35, 1), Color = WHITE, Material = Enum.Material.Neon, Transparency = 1 })
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = Kit.excludeList()
		local t0 = os.clock()
		local lastFx = 0
		local fired = false
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			local h = c:FindFirstChild("Head")
			local r = c:FindFirstChild("HumanoidRootPart")
			if el > d.wind + d.dur + 0.05 or not h or not r then
				conn:Disconnect()
				charge:Destroy()
				beam:Destroy()
				core:Destroy()
				return
			end
			local eye = h.Position + h.CFrame.LookVector * 0.7 + Vector3.new(0, 0.1, 0)
			if el < d.wind then
				charge.Position = eye
				charge.Size = Vector3.one * (0.2 + 1.4 * el / d.wind)
				return
			end
			if not fired then
				fired = true
				charge.Transparency = 1
				beam.Transparency = 0.25
				core.Transparency = 0
				snd(SND.Laser, eye, 1, 0.7)
				CartoonFX.sound("Electric", eye, 1)
				if Kit.mine(c) then
					CartoonFX.shake(0.3)
				end
			end
			local k = math.clamp((el - d.wind) / d.dur, 0, 1)
			local dir = CFrame.Angles(0, math.rad(-d.sweep / 2 + d.sweep * k), 0) * d.dir
			local target = r.Position + Vector3.new(0, 0.5, 0) + dir * d.range
			local hit = workspace:Raycast(eye, target - eye, params)
			local to = hit and hit.Position or target
			local len = (to - eye).Magnitude
			local w = 0.85 + 0.15 * math.sin(el * 60)
			beam.Size = Vector3.new(w, w, len)
			beam.CFrame = CFrame.lookAt(eye, to) * CFrame.new(0, 0, -len / 2)
			core.Size = Vector3.new(0.35, 0.35, len)
			core.CFrame = beam.CFrame
			if os.clock() - lastFx > 0.05 then
				lastFx = os.clock()
				CartoonFX.sparks(to, 4, (Kit.rng:NextNumber() < 0.5) and CYAN or MAG)
				local g = CartoonFX.groundPos(to)
				local scorch = Kit.part({ Shape = CYL, Size = Vector3.new(0.06, 1.2, 1.2), CFrame = CFrame.new(g + Vector3.new(0, 0.06, 0)) * UP, Color = CYAN, Material = Enum.Material.Neon, Transparency = 0.3 })
				Kit.tween(scorch, 0.6, { Transparency = 1, Size = Vector3.new(0.06, 0.4, 0.4) })
				Debris:AddItem(scorch, 0.62)
			end
		end)
	end)

	-- CAPTCHA
	local grids = {}
	Kit.on("AI_Captcha", function(d)
		local cf = CFrame.lookAt(d.c, d.c + d.dir)
		local tiles = {}
		local col = Kit.mine(d.a) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 90, 80)
		for ix = 0, 2 do
			for iz = 0, 2 do
				local pos = cf * CFrame.new((ix - 1) * d.cell, 0.12, (iz - 1) * d.cell)
				local t = Kit.part({ Size = Vector3.new(0.1, 0.1, 0.1), CFrame = pos, Color = WHITE, Transparency = 0.35 })
				local border = Kit.part({ Size = Vector3.new(0.1, 0.08, 0.1), CFrame = pos * CFrame.new(0, -0.02, 0), Color = col, Transparency = 0.1 })
				Kit.tween(t, 0.2, { Size = Vector3.new(d.cell - 0.5, 0.12, d.cell - 0.5) }, Enum.EasingStyle.Back)
				Kit.tween(border, 0.2, { Size = Vector3.new(d.cell - 0.1, 0.08, d.cell - 0.1) }, Enum.EasingStyle.Back)
				tiles[ix * 3 + iz] = { t = t, b = border, pos = pos }
			end
		end
		-- panneau de consigne au fond de la grille, tourné vers le lanceur
		local head = cf * CFrame.new(0, 4.2, -d.cell * 1.5 - 0.6)
		local panel = Kit.part({ Size = Vector3.new(d.cell * 3, 2.2, 0.15), CFrame = head, Color = Color3.fromRGB(60, 130, 255) })
		local sub = Kit.part({ Size = Vector3.new(d.cell * 3, 0.6, 0.16), CFrame = head * CFrame.new(0, -1.35, 0), Color = WHITE })
		Kit.flatText(panel, "Select all squares with ENEMIES", WHITE, Enum.NormalId.Back)
		Kit.flatText(sub, "I'm not a robot", NAVY, Enum.NormalId.Back)
		snd(SND.Ping, d.c, 1, 0.9)
		local st = { tiles = tiles, extra = { panel, sub } }
		grids[d.a] = st
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < d.wind and not st.done do
				for _, e in pairs(tiles) do
					e.t.Transparency = 0.35 + 0.25 * math.sin((os.clock() - t0) * 18)
				end
				task.wait(0.03)
			end
		end)
		task.delay(d.wind + 1.5, function()
			for _, e in pairs(tiles) do
				for _, p in ipairs({ e.t, e.b }) do
					if p.Parent then
						p:Destroy()
					end
				end
			end
			for _, p in ipairs(st.extra) do
				if p.Parent then
					p:Destroy()
				end
			end
		end)
	end)

	Kit.on("AI_CaptchaStrike", function(d)
		local st = grids[d.a]
		if not st then
			return
		end
		st.done = true
		local sel = {}
		for _, cdef in ipairs(d.cells or {}) do
			sel[cdef[1] * 3 + cdef[2]] = true
		end
		local any = false
		for key, e in pairs(st.tiles) do
			if sel[key] then
				any = true
				e.t.Color = LIME
				e.t.Transparency = 0.1
				local g = e.pos.Position
				-- coche verte
				local c1 = Kit.part({ Size = Vector3.new(0.5, 0.15, 1.2), CFrame = e.pos * CFrame.new(-0.6, 0.15, 0.2) * CFrame.Angles(0, math.rad(45), 0), Color = WHITE })
				local c2 = Kit.part({ Size = Vector3.new(0.5, 0.15, 2.4), CFrame = e.pos * CFrame.new(0.45, 0.15, -0.2) * CFrame.Angles(0, math.rad(-35), 0), Color = WHITE })
				Debris:AddItem(c1, 1.2)
				Debris:AddItem(c2, 1.2)
				CartoonFX.pillar(g, d.cell * 0.5, 40, CYAN, 0.5)
				CartoonFX.bigImpact(g + Vector3.new(0, 1, 0), Vector3.new(0, 1, 0), 1.1, LIME)
				CartoonFX.shockwave(g + Vector3.new(0, 0.2, 0), d.cell, CYAN)
				Kit.cubes(g + Vector3.new(0, 1, 0), 10, HOLOS, 0.45, 8, 0.45)
			else
				Kit.tween(e.t, 0.25, { Transparency = 1 })
				Kit.tween(e.b, 0.25, { Transparency = 1 })
			end
		end
		if any then
			CartoonFX.sound("Explosion", d.c, 0.8)
			CartoonFX.sound("Electric", d.c, 1)
			snd(SND.Ping, d.c, 1, 1.2)
			CartoonFX.word(d.c + Vector3.new(0, 6, 0), "VERIFIED!", 1.4, "Heavy")
			if Kit.mine(d.a) then
				CartoonFX.shake(0.9)
				CartoonFX.impactFrame(0.6)
			end
		else
			snd(SND.Error, d.c, 0.8, 1)
			Kit.floatText(d.c + Vector3.new(0, 4, 0), "Please try again.", RED, 3, 1, 1)
		end
	end)

	Kit.on("AI_Spam", function(d)
		local r = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(Kit.rng:NextNumber(-1, 1), 3.8, 0), "SPAM FILTERED", MAG, 2.6, 0.8, 1.5)
			Kit.cubes(r.Position + Vector3.new(0, 1, 0), 5, { MAG, CYAN }, 0.3, 4, 0.3)
		end
	end)

	-- aura : cubes glitch en permanence (plus en transformation), fenêtres qui apparaissent autour d'elle
	local WORDS = { "98%", "LOADING...", "01101", "ERROR?", "HELLO!", "SYNC", "BEEP" }
	task.spawn(function()
		while true do
			task.wait(0.3)
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "AIAssistant" then
					local r = c:FindFirstChild("HumanoidRootPart")
					local trans = c:GetAttribute("Transformed")
					if r then
						if trans or Kit.rng:NextNumber() < 0.25 then
							Kit.cubes(r.Position + Vector3.new(Kit.rng:NextNumber(-1.5, 1.5), Kit.rng:NextNumber(-1, 2.5), Kit.rng:NextNumber(-1.5, 1.5)), trans and 3 or 1, trans and HOLOS or { CYAN }, 0.22, 2, 0.5)
						end
						if trans and Kit.rng:NextNumber() < 0.35 then
							local a = Kit.rng:NextNumber(0, math.pi * 2)
							local pos = r.Position + Vector3.new(math.cos(a) * 3, Kit.rng:NextNumber(1.5, 3.5), math.sin(a) * 3)
							miniWindow(pos, Kit.flat(r.Position - pos), 1.1, 0.7, WORDS[Kit.rng:NextInteger(1, #WORDS)], (Kit.rng:NextNumber() < 0.5) and CYAN or MAG, 0.7)
						end
					end
				end
			end
		end
	end)
end

return M
