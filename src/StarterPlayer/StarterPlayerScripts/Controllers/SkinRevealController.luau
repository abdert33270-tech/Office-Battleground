--[[
	SkinRevealController — cinématiques de révélation de skin (client uniquement). v2 = MOTEUR DE CHORÉGRAPHIE.

	API publique (via ctx.SkinRevealController) — inchangée :
		SkinRevealController.play(skinId, opts)   -- retourne tout de suite ; file d'attente si une révélation est déjà en cours
			opts = { isNew: bool?, refund: number?, crateId: string?, replay: bool?, onDone: function(skinId)?,
			         scene: string? (force un modèle de scène, flux générique), showcase: string? (force une attaque),
			         demo: string? (joue une démo du moteur : "RocketMogul" | "LivestreamLegend") }
		SkinRevealController.isPlaying() -> bool   -- vrai pendant une révélation (ou s'il en reste dans la file)
		SkinRevealController.skip()                -- comme un clic
		SkinRevealController.Scenes / .Stages / .Props / .Moves / .Poses / .DemoReveals -- listes (outils)
	Debug (execute_luau sur le Client) : ReplicatedStorage.SkinRevealDebug:Fire("play", id, opts) | ("skip")
		| ("pause", bool) | ("demo", "RocketMogul") ; attributs SkinRevealPlaying / Phase ; _G.SkinReveal.

	DEUX FLUX
	1) Chorégraphie scriptée (v2) : l'entrée Config/SkinReveals[skinId] (ou ses enfants Pack1..Pack5) contient
	   Reveal = function(R, ctx) ... end   (ou une liste de fonctions = temps forts joués dans l'ordre).
	   Le script construit SA scène, SES accessoires, SES animations, SES plans de caméra et SA fin, puis R.title().
	   Aucun passage par l'ancien schéma « chute + coup sur BOB + pose ».
	2) Flux générique (skins Base, skins sans script) : modèle de scène (Scene) -> démonstration d'attaque (Epic+)
	   -> pose héroïque -> carte titre. (inchangé)
	Documentation complète de l'API R : scratchpad/REVEAL_API.md (résumé ci-dessous) ; exemples complets :
	table DemoReveals (chercher « DEMO REVEALS » dans ce fichier).

	RÉSUMÉ DE L'API R (coordonnées LOCALES de la scène : sol y = 0, marque du héros CF(0, 3, 0), le héros regarde
	vers -Z, caméra côté -Z, +X = droite du héros ; tout argument « pos » accepte Vector3 / CFrame / Instance) :
		temps   : R.wait(t) (temps du récit, lève SKIP : jamais dans un pcall), R.spawn(fn), R.delay(t, fn),
		          R.every(dt, fn), R.over(t, fn(a, e)), R.slowmo(scale, t?), R.freeze(dur), R.title(opts?),
		          R.onSkip(fn), R.mark(cf)
		scène   : R.stage(nom | fn, opts), R.box, R.cyl, R.ball, R.floor, R.text, R.billboard, R.light, R.spot,
		          R.model, R.prop(nom | spec, cf, opts) -> (objet, label?), R.mesh, R.attach, R.detach, R.hold,
		          R.drop, R.show, R.destroy, R.at / R.wp / R.loc / R.pos
		perso   : R.rig, R.root, R.place, R.face, R.alpha, R.transform, R.anim, R.pose, R.attackAnim
		mouvements : R.moveTo, R.walk, R.jump, R.fly, R.spin, R.teleport, R.tween, R.scale
		caméra  : R.cam.cut / move / dolly / pushIn / pullOut / orbit / crane / whip / lowAngle / topDown / dutch /
		          follow / track / hero / shake / punch / fov / roll (+ R.cam.slowmo, R.cam.freeze)
		effets  : R.fx.smoke / sparks / confetti / money / coins / hearts / bubbles / fire / explosion / lightning /
		          beam / shockwave / ring / bigImpact / flash / impact / word / banner / rain / rays / glitch /
		          speedLines / dust / puff / implode / swirl / pillar / quake / shards / debris / light / trail /
		          fireworks / twinkle / tint / dark / saturation / contrast
		son / bandeaux : R.sound(clé | id, pos?, vol?, pitch?), R.caption(text), R.location(text)
		infos   : ctx = { skinId, def, charId, charDef, rarity, tier, color, rarityColor, caption, entry, isNew,
		          replay, opts, attacks, rng } ; R.color, R.rc, R.tier, R.rand, R.randi, R.choose, R.S (session brute)
	Sécurité : chaque script tourne dans un pcall ; en cas d'erreur -> warn + scène vide + révélation générique.
	Nettoyage garanti (fin, passer, erreur) : caméra, Lighting (CC / flou / bloom / DOF), bandes noires,
	capture des touches, GUI masquées, bac à sable (Y = 10000), sons.
	Durées : Rare ~3,5 s, Epic ~5,5 s, Legendary ~8-9 s avant la carte. Garde-fou : scène forcée à la fin après 20 s.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Modules = Shared:WaitForChild("Modules")
local Config = Shared:WaitForChild("Config")
local ProcAnim = require(Modules.ProcAnim)
local CartoonFX = require(Modules.CartoonFX)
local SkinBuilder = require(Modules.SkinBuilder)
local UITheme = require(Modules.UITheme)

local SkinRevealController = {}
SkinRevealController.Priority = 70
local DemoReveals = {} -- rempli plus bas (DEMO REVEALS)
SkinRevealController.Version = 2

local player = Players.LocalPlayer
local rng = Random.new()
local V3, V2, C3, CFn, ANG = Vector3.new, Vector2.new, Color3.fromRGB, CFrame.new, CFrame.Angles
local PI = math.pi
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local INK = UITheme.Colors.Ink
local ES, ED = Enum.EasingStyle, Enum.EasingDirection

local ORIGIN = V3(6000, 10000, 6000)
local SKIP = setmetatable({}, { __tostring = function()
	return "SKIP"
end })
local TIER = { Base = 1, Rare = 1, Epic = 2, Legendary = 3 }
local CARD_TIME = { 1.6, 2.0, 2.6 }
local RARITY_FALLBACK = { Base = C3(165, 165, 178), Rare = C3(60, 150, 255), Epic = C3(170, 85, 255), Legendary = C3(255, 192, 30) }
local DEFAULT_REFUND = { Base = 0, Rare = 60, Epic = 150, Legendary = 400 }
local MATS = {
	SmoothPlastic = Enum.Material.SmoothPlastic, Plastic = Enum.Material.Plastic, Neon = Enum.Material.Neon,
	Glass = Enum.Material.Glass, Metal = Enum.Material.Metal, Wood = Enum.Material.Wood, Fabric = Enum.Material.Fabric,
	Marble = Enum.Material.Marble, Concrete = Enum.Material.Concrete, Foil = Enum.Material.Foil,
	ForceField = Enum.Material.ForceField, DiamondPlate = Enum.Material.DiamondPlate,
}
local SINK_KEYS = {
	Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down, Enum.KeyCode.Left, Enum.KeyCode.Right,
	Enum.KeyCode.Space, Enum.KeyCode.Return, Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five,
	Enum.KeyCode.Q, Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.F, Enum.KeyCode.G, Enum.KeyCode.T, Enum.KeyCode.LeftShift, Enum.KeyCode.Tab,
	Enum.KeyCode.ButtonA, Enum.KeyCode.ButtonB, Enum.KeyCode.ButtonX, Enum.KeyCode.ButtonY, Enum.KeyCode.ButtonR1, Enum.KeyCode.ButtonR2,
	Enum.KeyCode.ButtonL1, Enum.KeyCode.ButtonL2, Enum.KeyCode.Thumbstick1,
}
local SKIP_KEYS = { [Enum.KeyCode.Space] = true, [Enum.KeyCode.Return] = true, [Enum.KeyCode.ButtonA] = true }

------------------------------------------------------------------------
-- Accessoires de main des 4 persos d'origine (copie du format d'AbilityFXController ; les persos de Content
-- sont ajoutés via ContentLoader.merge("Props")) : { taille, décalage (repère bras droit), couleur, forme? }
------------------------------------------------------------------------
local CYL, BALL = Enum.PartType.Cylinder, Enum.PartType.Ball
local ALONG_Y = ANG(0, 0, PI / 2)
local ALONG_Z = ANG(0, PI / 2, 0)
local PC = {
	white = C3(250, 250, 250), brown = C3(120, 70, 40), dark = C3(30, 30, 35), steel = C3(200, 205, 215), yellow = C3(255, 215, 0),
	blue = C3(90, 180, 255), grey = C3(150, 160, 175), orange = C3(255, 150, 40), red = C3(220, 50, 50),
}
local BASE_PROPS = {
	BigCup = { { V3(1.5, 1.1, 1.1), CFn(0, -1.5, 0) * ALONG_Y, PC.white, CYL }, { V3(0.5, 1.15, 1.15), CFn(0, -1.4, 0) * ALONG_Y, C3(150, 95, 50), CYL } },
	PaperStack = { { V3(1.6, 0.5, 1.3), CFn(-0.75, -1.4, 0), PC.white } },
	StickyPad = { { V3(1.25, 0.3, 1.25), CFn(0, -1.25, -0.1), C3(255, 235, 60) } },
	BubbleWand = { { V3(2.2, 0.18, 0.18), CFn(0, -2.0, 0) * ALONG_Y, PC.yellow, CYL }, { V3(0.14, 1.5, 1.5), CFn(0, -3.7, 0) * ALONG_Z, C3(255, 120, 200), CYL } },
	EspressoCup = { { V3(0.5, 0.5, 0.5), CFn(0, -1.25, 0) * ALONG_Y, PC.white, CYL } },
	Mop = { { V3(4.6, 0.25, 0.25), CFn(-0.5, -2.8, 0) * ALONG_Y, PC.brown, CYL }, { V3(1.8, 0.6, 1.0), CFn(-0.5, -5.2, 0), PC.grey }, { V3(1.6, 0.4, 0.8), CFn(-0.5, -5.6, 0), C3(230, 230, 235) } },
	WetSign = { { V3(1.8, 2.4, 0.2), CFn(-0.75, -2.4, 0.4) * ANG(0.35, 0, 0), PC.yellow }, { V3(1.8, 2.4, 0.2), CFn(-0.75, -2.4, -0.4) * ANG(-0.35, 0, 0), PC.yellow } },
	Bucket = { { V3(1.4, 1.4, 1.4), CFn(0, -1.9, 0) * ALONG_Y, PC.grey, CYL }, { V3(0.1, 1.2, 1.2), CFn(0, -1.25, 0) * ALONG_Y, PC.blue, CYL } },
	PowerWasher = { { V3(0.7, 1.0, 0.7), CFn(-0.3, -1.4, 0), PC.yellow }, { V3(2.8, 0.2, 0.2), CFn(-0.3, -3.2, 0) * ALONG_Y, C3(80, 80, 90), CYL } },
	TrayShield = { { V3(2.8, 0.2, 2.0), CFn(-0.75, -1.6, 0), PC.orange }, { V3(2.5, 0.22, 1.7), CFn(-0.75, -1.55, 0), C3(255, 190, 90) } },
	Ladle = { { V3(2.6, 0.25, 0.25), CFn(0, -2.3, 0) * ALONG_Y, PC.steel, CYL }, { V3(1.2, 1.2, 1.2), CFn(0, -3.8, -0.3), PC.steel, BALL } },
	Meat = { { V3(1.3, 1.3, 1.3), CFn(0, -1.5, 0), C3(140, 90, 60), BALL } },
	GiantPan = { { V3(0.35, 2.0, 0.35), CFn(-0.6, -2.1, 0), PC.dark }, { V3(0.35, 3.6, 3.6), CFn(-0.6, -4.6, 0) * ALONG_Z, PC.dark, CYL }, { V3(0.6, 0.6, 0.6), CFn(-0.6, -4.6, -0.3), PC.yellow, BALL } },
	SoupPot = { { V3(1.4, 1.6, 1.6), CFn(-0.75, -1.6, 0) * ALONG_Y, PC.steel, CYL }, { V3(0.1, 1.4, 1.4), CFn(-0.75, -2.32, 0) * ALONG_Y, PC.orange, CYL } },
	Handcuffs = { { V3(0.6, 0.6, 0.15), CFn(-0.2, -1.2, -0.3), PC.steel }, { V3(0.6, 0.6, 0.15), CFn(0.3, -1.2, -0.3), PC.steel } },
	FlashlightProp = { { V3(1.6, 0.4, 0.4), CFn(0, -1.7, 0) * ALONG_Y, PC.dark, CYL }, { V3(0.1, 0.5, 0.5), CFn(0, -2.52, 0) * ALONG_Y, C3(255, 250, 170), CYL } },
	Walkie = { { V3(0.45, 1.0, 0.3), CFn(0, -1.3, -0.2), PC.dark } },
	WhistleProp = { { V3(0.5, 0.3, 0.3), CFn(0, -1.15, -0.25), PC.steel } },
	Baton = { { V3(2.6, 0.3, 0.3), CFn(0, -2.3, 0) * ALONG_Y, PC.dark, CYL } },
}

------------------------------------------------------------------------
-- Poses et animations propres aux révélations (ajoutées dans ProcAnim.Anims au chargement, côté client)
------------------------------------------------------------------------
-- NB : dans ProcAnim, r > 0 écarte le membre vers l'EXTÉRIEUR (vérifié en jeu), r < 0 le ramène devant le corps
local POSES = {
	Hero = { RS = { p = 3.05, r = 0.15 }, LS = { p = 0.25, r = 0.35 }, RJ = { ln = -0.12, sd = 0.05 }, RH = { p = -0.15, r = 0.2 }, LH = { p = 0.2, r = 0.2 } },
	Point = { RS = { p = 1.6, y = 0.1 }, LS = { p = 0.3, r = 0.4 }, RJ = { tw = 0.35, ln = 0.05 }, RH = { p = -0.3, r = 0.1 }, LH = { p = 0.35, r = 0.1 } },
	Victory = { RS = { p = 0.25, r = 2.3 }, LS = { p = 0.25, r = 2.3 }, RJ = { ln = -0.18 }, RH = { r = 0.25 }, LH = { r = 0.25 } },
	Boss = { RS = { p = 1.25, r = -0.62 }, LS = { p = 1.1, r = -0.68 }, RJ = { ln = -0.1 }, RH = { r = 0.15 }, LH = { r = 0.15 } },
	Power = { RS = { p = 0.5, r = 1.1 }, LS = { p = 0.5, r = 1.1 }, RJ = { ln = 0.12 }, RH = { p = 0.35, r = 0.35 }, LH = { p = -0.1, r = 0.35 } },
	Salute = { RS = { p = 2.7, y = 1.2, r = -0.55 }, LS = { p = 0.05 }, RJ = { ln = -0.06 }, RH = { r = 0.08 }, LH = { r = 0.08 } },
	Thinker = { RS = { p = 2.2, y = 1.3, r = -0.3 }, LS = { p = 1.2, y = 1.1, r = -0.2 }, RJ = { ln = 0.1, tw = 0.2 }, RH = { p = 0.15 }, LH = { p = -0.1 } },
	Lean = { RS = { p = 0.2, r = 0.25 }, LS = { p = 3.0, r = 0.2 }, RJ = { sd = 0.18, ln = -0.05 }, RH = { r = 0.2 }, LH = { p = 0.3, r = -0.1 } },
	Flex = { RS = { p = 0.15, r = 1.55 }, LS = { p = 0.15, r = 1.55 }, RJ = { ln = 0.08 }, RH = { r = 0.3 }, LH = { r = 0.3 } },
	Sit = { RS = { p = 0.5, r = 0.15 }, LS = { p = 0.5, r = 0.15 }, RJ = { ln = -0.08 }, RH = { p = 1.57 }, LH = { p = 1.57 } },
	Fall = { RS = { p = 2.9, r = 0.6 }, LS = { p = 2.9, r = 0.6 }, RJ = { ln = -0.25 }, RH = { p = 0.6 }, LH = { p = -0.45 } },
	Crouch = { RS = { p = -0.4, r = 0.9 }, LS = { p = 1.0, r = 0.25 }, RJ = { ln = 0.75 }, RH = { p = 1.3, r = 0.2 }, LH = { p = -0.5, r = 0.2 } },
	-- v2 : poses supplémentaires pour les chorégraphies
	Kneel = { RS = { p = 0.4, r = 0.2 }, LS = { p = 1.2, r = -0.1 }, RJ = { ln = 0.15 }, RH = { p = 1.45 }, LH = { p = -0.7 } },
	Cheer = { RS = { p = 3.0, r = 0.5 }, LS = { p = 3.0, r = 0.5 }, RJ = { ln = -0.18 }, RH = { r = 0.15 }, LH = { r = 0.15 } },
	Shrug = { RS = { p = 0.7, y = -0.6, r = 1.0 }, LS = { p = 0.7, y = -0.6, r = 1.0 }, RJ = { sd = 0.06, ln = -0.05 } },
	Bow = { RS = { p = 0.25, r = 0.1 }, LS = { p = 1.3, y = 1.0, r = -0.4 }, RJ = { ln = 0.8 }, RH = { p = -0.1 }, LH = { p = 0.1 } },
	ArmsCrossed = { RS = { p = 1.45, y = 0.2, r = -0.95 }, LS = { p = 1.3, y = 0.2, r = -0.9 }, RJ = { ln = -0.06 }, RH = { r = 0.12 }, LH = { r = 0.12 } },
	HandsHips = { RS = { p = 0.3, y = 1.2, r = 0.75 }, LS = { p = 0.3, y = 1.2, r = 0.75 }, RJ = { ln = -0.1 }, RH = { r = 0.18 }, LH = { r = 0.18 } },
	Present = { RS = { p = 1.2, r = 1.0 }, LS = { p = 1.2, r = 1.0 }, RJ = { ln = -0.08 }, RH = { r = 0.1 }, LH = { r = 0.1 } },
	Float = { RS = { p = 0.35, r = 1.35 }, LS = { p = 0.35, r = 1.35 }, RJ = { ln = -0.05 }, RH = { p = 0.35 }, LH = { p = -0.2 } },
	Guard = { RS = { p = 1.9, y = 0.3, r = -0.45 }, LS = { p = 2.0, y = 0.3, r = -0.35 }, RJ = { ln = 0.12, tw = -0.15 }, RH = { p = -0.25, r = 0.1 }, LH = { p = 0.3, r = 0.1 } },
	Selfie = { RS = { p = 2.3, y = 0.3, r = 0.4 }, LS = { p = 0.35, r = 0.35 }, RJ = { sd = -0.08, ln = -0.05 }, RH = { r = 0.1 }, LH = { r = 0.1 } },
	HoldUp = { RS = { p = 3.05, r = 0.15 }, LS = { p = 3.05, r = 0.15 }, RJ = { ln = -0.12 }, RH = { r = 0.15 }, LH = { r = 0.15 } },
	HoldOut = { RS = { p = 1.57, r = 0.05 }, LS = { p = 0.15, r = 0.15 }, RJ = { tw = 0.15 }, RH = { r = 0.08 }, LH = { r = 0.08 } },
	Facepalm = { RS = { p = 2.4, y = 1.4, r = -0.5 }, LS = { p = 0.2 }, RJ = { ln = 0.18 }, RH = { r = 0.06 }, LH = { r = 0.06 } },
	Drink = { RS = { p = 2.3, y = 1.1, r = -0.3 }, LS = { p = 0.3, r = 0.3 }, RJ = { ln = -0.15 }, RH = { r = 0.08 }, LH = { r = 0.08 } },
	Typing = { RS = { p = 1.35, r = -0.15 }, LS = { p = 1.35, r = -0.15 }, RJ = { ln = 0.1 } },
	Shades = { RS = { p = 2.6, y = 1.2, r = -0.45 }, LS = { p = 0.2, r = 0.25 }, RJ = { ln = -0.08, tw = 0.1 }, RH = { r = 0.12 }, LH = { r = 0.12 } },
}
SkinRevealController.Poses = {}
local function holdAnim(pose)
	local over = {}
	for j, v in pairs(pose) do
		local c = {}
		for k, x in pairs(v) do
			c[k] = x * 1.15
		end
		over[j] = c
	end
	local k1 = table.clone(over)
	k1.t = 0.13
	local k2 = table.clone(pose)
	k2.t = 0.27
	local k3 = table.clone(pose)
	k3.t = 90
	return { { t = 0 }, k1, k2, k3 }
end
for name, pose in pairs(POSES) do
	ProcAnim.Anims["Reveal_" .. name] = holdAnim(pose)
	table.insert(SkinRevealController.Poses, name)
end
ProcAnim.Anims.Reveal_Stop = { { t = 0 }, { t = 0.18 } }
local function walkAnim(step, amp, lean)
	local f = { { t = 0 } }
	local t, s = 0, 1
	while t < 8 do
		t += step
		s = -s
		table.insert(f, { t = t, RS = { p = amp * s }, LS = { p = -amp * s }, RH = { p = -amp * 1.1 * s }, LH = { p = amp * 1.1 * s }, RJ = { tw = 0.06 * s, ln = lean } })
	end
	return f
end
ProcAnim.Anims.Reveal_Walk = walkAnim(0.28, 0.6, 0.04)
ProcAnim.Anims.Reveal_Run = walkAnim(0.15, 1.05, 0.3)

-- v2 : mouvements d'acteur pour les chorégraphies (R.anim("Wave") -> ProcAnim "Reveal_Wave")
local MOVES = {}
local function seq(base, n, step, a, b)
	-- alterne les clés a / b n fois (b et a sont fusionnées avec base)
	local f = { { t = 0 } }
	local t = 0
	for i = 1, n do
		t += step
		local k = table.clone(base)
		for j, v in pairs((i % 2 == 1) and a or b) do
			k[j] = v
		end
		k.t = t
		table.insert(f, k)
	end
	return f, t
end
do
	local f, t = seq({ LS = { p = 0.2, r = 0.2 }, RJ = { ln = -0.05, sd = -0.05 } }, 6, 0.15, { RS = { p = 2.75, r = 0.25 } }, { RS = { p = 2.75, r = 0.85 } })
	table.insert(f, { t = t + 0.25 })
	MOVES.Wave = f
	f, t = seq({ RJ = { ln = 0.05 } }, 8, 0.11, { RS = { p = 1.45, r = 0.55 }, LS = { p = 1.45, r = 0.55 } }, { RS = { p = 1.45, r = -0.3 }, LS = { p = 1.45, r = -0.3 } })
	table.insert(f, { t = t + 0.2 })
	MOVES.Clap = f
	f, t = seq({ RS = { p = 2.75, r = 0.4 }, LS = { p = 2.75, r = 0.4 } }, 10, 0.16, { RJ = { ln = -0.2, sd = 0.06 } }, { RJ = { ln = -0.05, sd = -0.06 } })
	table.insert(f, { t = t + 0.2 })
	MOVES.Cheer = f
	f, t = seq({ RJ = { ln = 0.1 } }, 28, 0.085, { RS = { p = 1.25, r = -0.15 }, LS = { p = 1.45, r = -0.15 } }, { RS = { p = 1.45, r = -0.15 }, LS = { p = 1.25, r = -0.15 } })
	MOVES.Typing = f
	-- danse disco (boucle ~4 s)
	f = { { t = 0 } }
	t = 0
	for i = 1, 16 do
		t += 0.25
		local s = (i % 2 == 1) and 1 or -1
		table.insert(f, { t = t, RS = { p = s > 0 and 2.9 or 0.4, r = s > 0 and 0.45 or 0.2 }, LS = { p = s > 0 and 0.4 or 2.9, r = s > 0 and 0.2 or 0.45 }, RJ = { sd = 0.16 * s, tw = 0.12 * s }, RH = { r = s > 0 and 0.3 or 0.05 }, LH = { r = s > 0 and 0.05 or 0.3 } })
	end
	MOVES.Dance = f
	-- nage / flottement (boucle ~3 s)
	f = { { t = 0 } }
	t = 0
	for i = 1, 10 do
		t += 0.3
		local s = (i % 2 == 1) and 1 or -1
		table.insert(f, { t = t, RS = { p = 0.4 + 0.25 * s, r = 1.3 }, LS = { p = 0.4 - 0.25 * s, r = 1.3 }, RJ = { ln = -0.05 }, RH = { p = 0.3 * s }, LH = { p = -0.3 * s } })
	end
	MOVES.Swim = f
end
MOVES.ChefKiss = {
	{ t = 0 },
	{ t = 0.22, RS = { p = 2.25, y = 1.3, r = -0.4 }, LS = { p = 0.3, r = 0.3 }, RJ = { ln = 0.08 } },
	{ t = 0.5, RS = { p = 2.25, y = 1.3, r = -0.4 }, LS = { p = 0.3, r = 0.3 }, RJ = { ln = 0.1 } },
	{ t = 0.62, RS = { p = 2.1, y = 0.2, r = 1.0 }, LS = { p = 0.3, r = 0.4 }, RJ = { ln = -0.12, tw = 0.2 } },
	{ t = 1.1, RS = { p = 2.1, y = 0.2, r = 1.05 }, LS = { p = 0.3, r = 0.4 }, RJ = { ln = -0.12, tw = 0.2 } },
	{ t = 1.35 },
}
MOVES.Bite = {
	{ t = 0 },
	{ t = 0.2, RS = { p = 2.3, y = 1.2, r = -0.45 }, LS = { p = 2.2, y = 1.2, r = -0.45 }, RJ = { ln = 0.12 } },
	{ t = 0.32, RS = { p = 2.3, y = 1.2, r = -0.45 }, LS = { p = 2.2, y = 1.2, r = -0.45 }, RJ = { ln = 0.2 } },
	{ t = 0.44, RS = { p = 2.3, y = 1.2, r = -0.45 }, LS = { p = 2.2, y = 1.2, r = -0.45 }, RJ = { ln = 0.06 } },
	{ t = 0.56, RS = { p = 2.3, y = 1.2, r = -0.45 }, LS = { p = 2.2, y = 1.2, r = -0.45 }, RJ = { ln = 0.2 } },
	{ t = 0.9, RS = { p = 2.3, y = 1.2, r = -0.45 }, LS = { p = 2.2, y = 1.2, r = -0.45 }, RJ = { ln = 0.1 } },
	{ t = 1.1 },
}
MOVES.FlagPlant = {
	{ t = 0 },
	{ t = 0.3, RS = { p = 3.0, r = -0.1 }, LS = { p = 3.0, r = -0.1 }, RJ = { ln = -0.2 }, RH = { p = -0.2 }, LH = { p = 0.2 } },
	{ t = 0.46, RS = { p = 1.15, r = -0.25 }, LS = { p = 1.15, r = -0.25 }, RJ = { ln = 0.5 }, RH = { p = -0.45 }, LH = { p = 0.65 } },
	{ t = 0.95, RS = { p = 1.2, r = -0.25 }, LS = { p = 1.2, r = -0.25 }, RJ = { ln = 0.45 }, RH = { p = -0.45 }, LH = { p = 0.65 } },
	{ t = 1.2 },
}
MOVES.Throw = {
	{ t = 0 },
	{ t = 0.25, RS = { p = -0.9, r = 0.3 }, LS = { p = 1.3 }, RJ = { tw = -0.55, ln = -0.1 }, RH = { p = 0.35 }, LH = { p = -0.3 } },
	{ t = 0.38, RS = { p = 2.5 }, LS = { p = 0.2 }, RJ = { tw = 0.5, ln = 0.3 }, RH = { p = -0.35 }, LH = { p = 0.45 } },
	{ t = 0.62, RS = { p = 1.3 }, LS = { p = 0.1 }, RJ = { tw = 0.3, ln = 0.2 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
	{ t = 0.9 },
}
MOVES.Catch = {
	{ t = 0 },
	{ t = 0.15, RS = { p = 2.1, r = 0.2 }, LS = { p = 2.1, r = 0.2 }, RJ = { ln = -0.08 } },
	{ t = 0.4, RS = { p = 1.3, r = -0.1 }, LS = { p = 1.3, r = -0.1 }, RJ = { ln = -0.2 }, RH = { p = -0.2 }, LH = { p = 0.25 } },
	{ t = 0.75, RS = { p = 1.3, r = -0.1 }, LS = { p = 1.3, r = -0.1 }, RJ = { ln = -0.1 } },
	{ t = 0.95 },
}
MOVES.Taunt = {
	{ t = 0 },
	{ t = 0.15, RS = { p = 1.6, y = -0.4 }, LS = { p = 0.3, y = 1.2, r = 0.75 }, RJ = { ln = -0.1, tw = 0.15 } },
	{ t = 0.3, RS = { p = 1.95, y = -0.4 }, LS = { p = 0.3, y = 1.2, r = 0.75 }, RJ = { ln = -0.12, tw = 0.15 } },
	{ t = 0.45, RS = { p = 1.5, y = -0.4 }, LS = { p = 0.3, y = 1.2, r = 0.75 }, RJ = { ln = -0.1, tw = 0.15 } },
	{ t = 0.6, RS = { p = 1.95, y = -0.4 }, LS = { p = 0.3, y = 1.2, r = 0.75 }, RJ = { ln = -0.12, tw = 0.15 } },
	{ t = 1.0, RS = { p = 1.6, y = -0.4 }, LS = { p = 0.3, y = 1.2, r = 0.75 }, RJ = { ln = -0.1, tw = 0.15 } },
	{ t = 1.2 },
}
MOVES.LookAround = {
	{ t = 0 },
	{ t = 0.3, RS = { p = 0.3, r = 0.2 }, LS = { p = 0.3, r = 0.2 }, RJ = { tw = 0.55 } },
	{ t = 0.7, RS = { p = 0.3, r = 0.2 }, LS = { p = 0.3, r = 0.2 }, RJ = { tw = 0.55 } },
	{ t = 1.0, RS = { p = 0.3, r = 0.2 }, LS = { p = 0.3, r = 0.2 }, RJ = { tw = -0.55 } },
	{ t = 1.4, RS = { p = 0.3, r = 0.2 }, LS = { p = 0.3, r = 0.2 }, RJ = { tw = -0.55 } },
	{ t = 1.65 },
}
MOVES.Jump = {
	{ t = 0 },
	{ t = 0.14, RS = { p = -0.5, r = 0.3 }, LS = { p = -0.5, r = 0.3 }, RJ = { ln = 0.35 }, RH = { p = 0.9 }, LH = { p = 0.9 } },
	{ t = 0.3, RS = { p = 3.0, r = 0.3 }, LS = { p = 3.0, r = 0.3 }, RJ = { ln = -0.12 }, RH = { p = -0.2 }, LH = { p = 0.35 } },
	{ t = 0.7, RS = { p = 2.6, r = 0.5 }, LS = { p = 2.6, r = 0.5 }, RJ = { ln = -0.05 }, RH = { p = 0.5 }, LH = { p = -0.2 } },
	{ t = 1.2, RS = { p = 2.4, r = 0.6 }, LS = { p = 2.4, r = 0.6 }, RH = { p = 0.4 }, LH = { p = -0.1 } },
}
MOVES.Land = {
	{ t = 0, RS = { p = 1.0, r = 0.8 }, LS = { p = 1.0, r = 0.8 }, RJ = { ln = 0.2 } },
	{ t = 0.07, RS = { p = 0.5, r = 1.0 }, LS = { p = 0.5, r = 1.0 }, RJ = { ln = 0.6 }, RH = { p = 1.2, r = 0.2 }, LH = { p = 1.2, r = 0.2 } },
	{ t = 0.3, RS = { p = 0.5, r = 1.0 }, LS = { p = 0.5, r = 1.0 }, RJ = { ln = 0.55 }, RH = { p = 1.1, r = 0.2 }, LH = { p = 1.1, r = 0.2 } },
	{ t = 0.6 },
}
MOVES.Stumble = {
	{ t = 0 },
	{ t = 0.15, RS = { p = 2.6, r = 1.0 }, LS = { p = 1.0, r = 1.2 }, RJ = { ln = -0.35, sd = 0.1 }, RH = { p = -0.4 }, LH = { p = 0.5 } },
	{ t = 0.3, RS = { p = 1.0, r = 1.2 }, LS = { p = 2.6, r = 1.0 }, RJ = { ln = -0.3, sd = -0.1 }, RH = { p = 0.4 }, LH = { p = -0.3 } },
	{ t = 0.45, RS = { p = 2.6, r = 1.0 }, LS = { p = 1.0, r = 1.2 }, RJ = { ln = -0.25, sd = 0.08 } },
	{ t = 0.8 },
}
MOVES.Jab = {
	{ t = 0, RS = { p = 1.9, y = 0.3, r = -0.45 }, LS = { p = 2.0, y = 0.3, r = -0.35 }, RJ = { ln = 0.12 } },
	{ t = 0.1, RS = { p = 1.65, r = -0.1 }, LS = { p = 2.0, y = 0.3, r = -0.35 }, RJ = { ln = 0.18, tw = 0.35 }, RH = { p = -0.3 }, LH = { p = 0.35 } },
	{ t = 0.22, RS = { p = 1.9, y = 0.3, r = -0.45 }, LS = { p = 2.0, y = 0.3, r = -0.35 }, RJ = { ln = 0.12 } },
	{ t = 0.32, RS = { p = 1.9, y = 0.3, r = -0.45 }, LS = { p = 1.65, r = -0.1 }, RJ = { ln = 0.18, tw = -0.35 }, RH = { p = 0.35 }, LH = { p = -0.3 } },
	{ t = 0.46, RS = { p = 1.9, y = 0.3, r = -0.45 }, LS = { p = 2.0, y = 0.3, r = -0.35 }, RJ = { ln = 0.12 } },
	{ t = 0.6 },
}
MOVES.Uppercut = {
	{ t = 0 },
	{ t = 0.2, RS = { p = 0.2, r = 0.2 }, LS = { p = 1.8, r = -0.3 }, RJ = { ln = 0.45, tw = -0.3 }, RH = { p = 0.9 }, LH = { p = 0.6 } },
	{ t = 0.34, RS = { p = 3.05, r = -0.1 }, LS = { p = 0.5 }, RJ = { ln = -0.25, tw = 0.35 }, RH = { p = -0.3 }, LH = { p = 0.3 } },
	{ t = 0.8, RS = { p = 3.0, r = -0.1 }, LS = { p = 0.5 }, RJ = { ln = -0.2, tw = 0.3 }, RH = { p = -0.3 }, LH = { p = 0.3 } },
	{ t = 1.0 },
}
MOVES.Stomp = {
	{ t = 0 },
	{ t = 0.25, RS = { p = 0.4, r = 0.9 }, LS = { p = 0.4, r = 0.9 }, RJ = { ln = -0.1 }, RH = { p = 1.5 } },
	{ t = 0.35, RS = { p = 0.6, r = 1.1 }, LS = { p = 0.6, r = 1.1 }, RJ = { ln = 0.25 }, RH = { p = -0.1 }, LH = { p = 0.2 } },
	{ t = 0.75, RS = { p = 0.6, r = 1.1 }, LS = { p = 0.6, r = 1.1 }, RJ = { ln = 0.2 }, RH = { p = -0.1 }, LH = { p = 0.2 } },
	{ t = 0.95 },
}
MOVES.Slam = {
	{ t = 0 },
	{ t = 0.3, RS = { p = 3.05, r = -0.1 }, LS = { p = 3.05, r = -0.1 }, RJ = { ln = -0.25 }, RH = { p = -0.2 }, LH = { p = 0.2 } },
	{ t = 0.42, RS = { p = 0.95, r = -0.2 }, LS = { p = 0.95, r = -0.2 }, RJ = { ln = 0.65 }, RH = { p = -0.5 }, LH = { p = 0.7 } },
	{ t = 0.85, RS = { p = 1.0, r = -0.2 }, LS = { p = 1.0, r = -0.2 }, RJ = { ln = 0.6 }, RH = { p = -0.5 }, LH = { p = 0.7 } },
	{ t = 1.1 },
}
MOVES.Spin = { { t = 0 }, { t = 0.15, RS = { p = 0.15, r = 1.5 }, LS = { p = 0.15, r = 1.5 }, RJ = { ln = -0.05 }, RH = { r = 0.25 }, LH = { r = 0.25 } }, { t = 3, RS = { p = 0.15, r = 1.5 }, LS = { p = 0.15, r = 1.5 }, RJ = { ln = -0.05 }, RH = { r = 0.25 }, LH = { r = 0.25 } } }
MOVES.Strut = walkAnim(0.32, 0.45, -0.08)
MOVES.Sneak = walkAnim(0.42, 0.3, 0.38)
for name, frames in pairs(MOVES) do
	ProcAnim.Anims["RevealM_" .. name] = frames
end
local POSE_HOLD = {}
for name in pairs(POSES) do
	POSE_HOLD[name] = ProcAnim.Anims["Reveal_" .. name]
end
MOVES.Walk = ProcAnim.Anims.Reveal_Walk
MOVES.Run = ProcAnim.Anims.Reveal_Run
MOVES.Stop = ProcAnim.Anims.Reveal_Stop
SkinRevealController.Moves = {}
for name in pairs(MOVES) do
	table.insert(SkinRevealController.Moves, name)
end
table.sort(SkinRevealController.Moves)

------------------------------------------------------------------------
-- Données (chargées à la première révélation)
------------------------------------------------------------------------
local data
local function loadData()
	if data then
		return data
	end
	local d = {}
	local function try(m)
		if not m then
			return {}
		end
		local ok, r = pcall(require, m)
		if ok and type(r) == "table" then
			return r
		end
		warn("[SkinReveal] impossible de charger", m:GetFullName(), r)
		return {}
	end
	d.Skins = try(Config:FindFirstChild("Skins"))
	d.Characters = try(Config:FindFirstChild("Characters"))
	d.Attacks = try(Config:FindFirstChild("Attacks"))
	d.Reveals = try(Config:FindFirstChild("SkinReveals"))
	d.Props = table.clone(BASE_PROPS)
	d.Content = {}
	pcall(function()
		local CL = require(Modules.ContentLoader)
		CL.merge(d.Props, "Props")
		for _, def in ipairs(CL.all()) do
			d.Content[def.Id] = def
		end
	end)
	data = d
	return d
end

local function lum(c)
	return c.R * 0.3 + c.G * 0.59 + c.B * 0.11
end

-- couleur principale des effets : Color de l'entrée > FX du skin > part Neon > chemise > couleur du perso
local function skinColor(def, charDef, entry)
	if typeof(entry.Color) == "Color3" then
		return entry.Color
	end
	local fx = def.FX
	if type(fx) == "table" then
		for _, k in ipairs({ "Aura", "Light", "Sparkles", "Fire", "Trail" }) do
			if typeof(fx[k]) == "Color3" then
				return fx[k]
			end
		end
		if type(fx.Orbit) == "table" and typeof(fx.Orbit.Color) == "Color3" then
			return fx.Orbit.Color
		end
	end
	for _, pd in ipairs(type(def.Parts) == "table" and def.Parts or {}) do
		if type(pd) == "table" and pd.Material == "Neon" and typeof(pd.Color) == "Color3" then
			return pd.Color
		end
	end
	local o = type(def.Outfit) == "table" and def.Outfit or {}
	if typeof(o.Shirt) == "Color3" and lum(o.Shirt) > 0.25 and lum(o.Shirt) < 0.92 then
		return o.Shirt
	end
	return typeof(charDef.Color) == "Color3" and charDef.Color or WHITE
end

local function runSafe(fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and err ~= SKIP then
		warn("[SkinReveal]", err)
	end
end

------------------------------------------------------------------------
-- Session (une révélation)
------------------------------------------------------------------------
local Session = {}
Session.__index = Session

function Session:check()
	if not self.alive or self.endNow or (self.skipped and self.phase == "scene") then
		error(SKIP, 0)
	end
	-- chorégraphie : la suite jouée derrière la carte titre est plafonnée à 7 s
	if self.R and self.phase == "card" and self.cardAt and os.clock() - self.cardAt > 7 then
		self.endNow = true
		error(SKIP, 0)
	end
end

local debugPause = false -- tests : fige la révélation (captures d'écran)
function Session:wait(t)
	local e = 0
	t = t or 0
	repeat
		local dt = task.wait()
		if not debugPause then
			e += self:sdt(dt) -- temps du récit (ralenti / arrêt sur image)
		elseif self.rig then
			ProcAnim.freeze(self.rig, 0.1)
		end
		self:check()
	until e >= t
end

-- délai annulé si la phase change (skip)
function Session:delay(t, fn)
	local tok = self.token
	task.delay(t, function()
		if self.alive and self.token == tok then
			runSafe(fn)
		end
	end)
end

function Session:spawn(fn)
	local tok = self.token
	task.spawn(function()
		if self.alive and self.token == tok then
			runSafe(fn)
		end
	end)
end

-- boucle de décor (tourne jusqu'à la fin de la révélation)
function Session:loop(interval, fn)
	task.spawn(function()
		while self.alive do
			runSafe(fn)
			task.wait(interval)
		end
	end)
end

function Session:pick(a, b, c)
	if self.tier >= 3 then
		return c
	elseif self.tier == 2 then
		return b
	end
	return a
end

-- repères : wp/at/look = coordonnées locales du décor ; hl = repère du héros (il regarde vers -Z)
function Session:wp(x, y, z)
	return self.O * V3(x, y, z)
end
function Session:at(x, y, z)
	return self.O * CFn(x, y, z)
end
function Session:look(from, to)
	return CFrame.lookAt(self.O * from, self.O * to)
end
function Session:hl(x, y, z)
	return self.heroCF * V3(x, y, z)
end

function Session:part(props, parent)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		if k ~= "ClassName" then
			p[k] = v
		end
	end
	if p.Material == Enum.Material.Neon then
		p.CastShadow = false
	end
	p.Parent = parent or self.set
	return p
end

function Session:box(size, lcf, color, mat, tr, shape)
	local p = self:part({
		ClassName = shape == "Wedge" and "WedgePart" or "Part",
		Size = size,
		CFrame = self.O * lcf,
		Color = color or C3(200, 200, 200),
		Material = (type(mat) == "string" and MATS[mat]) or (typeof(mat) == "EnumItem" and mat) or Enum.Material.SmoothPlastic,
		Transparency = tr or 0,
	})
	if shape == "Ball" or shape == "Cyl" then
		p.Shape = shape == "Ball" and Enum.PartType.Ball or Enum.PartType.Cylinder
		p.Size = size
		p.CFrame = self.O * lcf
	end
	if p.Material == Enum.Material.Neon then
		p.CastShadow = false
	end
	return p
end

-- cylindre vertical (h = hauteur, d = diamètre)
function Session:cyl(h, d, lpos, color, mat, tr)
	return self:box(V3(h, d, d), CFn(lpos) * ANG(0, 0, PI / 2), color, mat, tr, "Cyl")
end

function Session:floor(size, lcf, color, mat)
	local p = self:box(size, lcf, color, mat)
	p.CanCollide = true
	return p
end

function Session:sign(part, text, o)
	o = o or {}
	local g = Instance.new("SurfaceGui")
	g.Face = o.Face or Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = o.PPS or 50
	g.LightInfluence = o.Lit and 1 or 0
	g.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = o.Bg and 0 or 1
	l.BackgroundColor3 = o.Bg or BLACK
	l.BorderSizePixel = 0
	l.FontFace = o.Body and UITheme.Body or UITheme.Display
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = o.Color or WHITE
	l.Parent = g
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.06, 0)
	pad.PaddingRight = UDim.new(0.06, 0)
	pad.PaddingTop = UDim.new(0.12, 0)
	pad.PaddingBottom = UDim.new(0.12, 0)
	pad.Parent = l
	if o.Stroke ~= false then
		local s = Instance.new("UIStroke")
		s.Thickness = o.Stroke or 3
		s.Color = o.StrokeColor or INK
		s.Parent = l
	end
	return l
end

function Session:light(part, color, range, bright, face, angle)
	local l = Instance.new(face and "SpotLight" or "PointLight")
	l.Color = color or WHITE
	l.Range = range or 16
	l.Brightness = bright or 2
	l.Shadows = false
	if face then
		l.Face = face
		l.Angle = angle or 45
	end
	l.Parent = part
	return l
end

function Session:lamp(lpos, color, range, bright)
	local p = self:box(V3(0.2, 0.2, 0.2), CFn(lpos), WHITE, nil, 1)
	p.CanQuery = false
	return self:light(p, color, range, bright)
end

function Session:tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(math.max(t, 0.001), style or ES.Quad, dir or ED.Out), props)
	tw:Play()
	return tw
end

function Session:sound(key, pos, vol)
	pcall(CartoonFX.sound, key, pos or (self.heroCF and self.heroCF.Position), vol or 0.8)
end

function Session:word(text, pos, power, cat)
	if type(text) == "string" and text ~= "" then
		pcall(CartoonFX.word, pos or (self.root.Position + V3(0, 3, 0)), text, power or 1, cat or "Heavy")
	end
end

-- perso
function Session:pose(name)
	if ProcAnim.Anims["Reveal_" .. tostring(name)] then
		ProcAnim.play(self.rig, "Reveal_" .. name)
	else
		ProcAnim.play(self.rig, "Reveal_Hero")
	end
end
function Session:anim(name, speed)
	if name and ProcAnim.Anims[name] then
		ProcAnim.play(self.rig, name, speed)
	end
end
function Session:place(cf)
	self.root.CFrame = cf
end
function Session:move(cf, t, style, dir)
	return self:tween(self.root, t, { CFrame = cf }, style or ES.Quad, dir or ED.InOut)
end
-- saut en cloche vers cf
function Session:arc(cf, t, height)
	local from = self.root.CFrame
	local e = 0
	while e < t do
		e += task.wait()
		self:check()
		local a = math.min(e / t, 1)
		self.root.CFrame = from:Lerp(cf, a) + V3(0, math.sin(a * PI) * height, 0)
	end
	self.root.CFrame = cf
end
-- visibilité du perso (0 = invisible, 1 = normal)
function Session:alpha(a)
	for p, base in pairs(self.vis) do
		if p.Parent then
			p.Transparency = base + (1 - base) * (1 - a)
		end
	end
	for dcl, base in pairs(self.visDecals) do
		if dcl.Parent then
			dcl.Transparency = base + (1 - base) * (1 - a)
		end
	end
	for _, e in ipairs(self.fxObjs) do
		if e.Parent then
			pcall(function()
				e.Enabled = a > 0.5
			end)
		end
	end
	-- peintures du skin (SurfaceGui / BillboardGui) : invisibles avec le perso
	if self.rig then
		self.guiOn = self.guiOn or {}
		for _, g in ipairs(self.rig:GetDescendants()) do
			if g:IsA("SurfaceGui") or g:IsA("BillboardGui") then
				if self.guiOn[g] == nil then
					self.guiOn[g] = g.Enabled
				end
				if self.guiOn[g] then
					g.Enabled = a > 0.5
				end
			end
		end
	end
end

-- caméra
function Session:cam(cf, fov)
	self.camJob = nil
	self.camCF = cf
	if fov then
		self.camFov = fov
	end
end
function Session:shot(cf, dur, fov, style, dir)
	self.camJob = { t = 0, dur = math.max(dur or 1, 0.001), from = self.camCF, to = cf, fov0 = self.camFov, fov1 = fov or self.camFov, style = style or ES.Quad, dir = dir or ED.InOut }
end
function Session:camFn(dur, fn)
	self.camJob = { t = 0, dur = math.max(dur, 0.001), fn = fn }
end
function Session:orbit(center, radius, height, a0, a1, dur, fov0, fov1)
	self:camFn(dur, function(a)
		local e = TweenService:GetValue(a, ES.Sine, ED.InOut)
		local ang = a0 + (a1 - a0) * e
		local pos = center + V3(math.sin(ang) * radius, height, -math.cos(ang) * radius)
		return CFrame.lookAt(pos, center), fov0 + (fov1 - fov0) * e
	end)
end
function Session:punch(a)
	self.punchV = math.max(self.punchV, a)
end

-- GUI
function Session:flash(color, inT, hold, outT, minT)
	local f = self.flashF
	if not f then
		return
	end
	f.BackgroundColor3 = color or WHITE
	self:tween(f, inT or 0.04, { BackgroundTransparency = minT or 0 })
	task.delay((inT or 0.04) + (hold or 0.03), function()
		if f.Parent then
			self:tween(f, outT or 0.3, { BackgroundTransparency = 1 })
		end
	end)
end
function Session:setLocation(text)
	local lbl = self.locLbl
	if not lbl then
		return
	end
	text = string.upper(text or "")
	task.spawn(function()
		for i = 1, #text do
			if not self.alive or not lbl.Parent then
				return
			end
			lbl.Text = string.sub(text, 1, i)
			task.wait(0.02)
		end
	end)
end
function Session:setLower(text)
	if self.lowLbl then
		self.lowLbl.Text = text or ""
	end
end
function Session:glitchBars()
	if not self.gui then
		return
	end
	for _ = 1, 4 do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.ZIndex = 30
		f.BackgroundColor3 = ({ C3(0, 255, 220), C3(255, 0, 200), WHITE, C3(255, 240, 0) })[rng:NextInteger(1, 4)]
		f.BackgroundTransparency = 0.35
		f.Position = UDim2.fromScale(rng:NextNumber(-0.2, 0.4), rng:NextNumber(0.12, 0.86))
		f.Size = UDim2.fromScale(rng:NextNumber(0.3, 0.9), rng:NextNumber(0.005, 0.03))
		f.Parent = self.gui
		Debris:AddItem(f, 0.07)
	end
end

-- petits effets de décor
function Session:cubes(center, n, colors, radius)
	for _ = 1, n do
		local off = V3(rng:NextNumber(-1, 1), rng:NextNumber(-1.2, 1.6), rng:NextNumber(-1, 1)) * (radius or 2)
		local p = self:part({ Size = Vector3.one * rng:NextNumber(0.3, 0.8), CFrame = CFn(center + off), Color = colors[rng:NextInteger(1, #colors)], Material = Enum.Material.Neon, CanQuery = false })
		self:tween(p, 0.35, { Transparency = 1, Size = Vector3.one * 0.05, CFrame = p.CFrame + V3(0, rng:NextNumber(0.5, 1.5), 0) })
		Debris:AddItem(p, 0.4)
	end
end

function Session:confetti(pos, n, colors, spread, up)
	local floorY = self.heroCF.Position.Y - 3
	for _ = 1, n do
		local p = self:part({ Size = V3(0.4, 0.05, 0.28), CFrame = CFn(pos), Color = colors[rng:NextInteger(1, #colors)], CanQuery = false, CastShadow = false })
		local peak = pos + V3(rng:NextNumber(-1, 1) * spread, rng:NextNumber(0.6, 1.2) * up, rng:NextNumber(-1, 1) * spread)
		local t1 = rng:NextNumber(0.3, 0.45)
		local t2 = rng:NextNumber(1.4, 2.2)
		self:tween(p, t1, { CFrame = CFn(peak) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0) }, ES.Quad, ED.Out)
		task.delay(t1, function()
			if p.Parent then
				self:tween(p, t2, { CFrame = CFn(peak.X + rng:NextNumber(-2, 2), floorY + 0.05, peak.Z + rng:NextNumber(-2, 2)) * ANG(0, rng:NextNumber(0, 6), 0) }, ES.Sine, ED.In)
			end
		end)
		Debris:AddItem(p, t1 + t2 + 1.5)
	end
end

-- pluie d'objets (Rain d'une entrée) : { Color|Colors, Size, Shape, Material, Count, Area, Slow }
function Session:rain(spec, dur)
	spec = type(spec) == "table" and spec or {}
	local count = math.clamp(tonumber(spec.Count) or 30, 1, 80)
	local colors = (type(spec.Colors) == "table" and #spec.Colors > 0) and spec.Colors or { typeof(spec.Color) == "Color3" and spec.Color or WHITE }
	local size = typeof(spec.Size) == "Vector3" and spec.Size or V3(0.8, 0.8, 0.8)
	local area = tonumber(spec.Area) or 14
	local floorY = self.heroCF.Position.Y - 3
	for i = 1, count do
		task.delay((i / count) * (dur or 2), function()
			if not self.alive then
				return
			end
			local start = self.heroCF * CFn(rng:NextNumber(-area, area), 22, rng:NextNumber(-area * 0.6, area * 0.5)) * ANG(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
			local p = self:part({ Size = size, CFrame = start, Color = colors[rng:NextInteger(1, #colors)], Material = MATS[spec.Material or ""] or Enum.Material.SmoothPlastic, CanQuery = false, CastShadow = false })
			if spec.Shape == "Ball" or spec.Shape == "Cyl" then
				p.Shape = spec.Shape == "Ball" and Enum.PartType.Ball or Enum.PartType.Cylinder
				p.Size = size
				p.CFrame = start
			end
			local slow = (type(spec.Slow) == "number" and spec.Slow) or (spec.Slow == true and 1.8) or 1
			local fallT = rng:NextNumber(1.2, 1.9) * slow
			self:tween(p, fallT, { CFrame = CFn(start.X, floorY + math.min(size.X, size.Y, size.Z) / 2 + 0.03, start.Z) * ANG(0, rng:NextNumber(0, 6), 0) }, ES.Sine, ED.In)
			Debris:AddItem(p, fallT + 2.5)
		end)
	end
end

-- rayons de lumière derrière le héros (Legendary)
function Session:rays(color)
	local folder = Instance.new("Folder")
	folder.Name = "Rays"
	folder.Parent = self.set
	local n = 12
	local parts = {}
	for i = 1, n do
		local p = self:part({ Size = V3((i % 2 == 0) and 0.7 or 0.4, 26, 0.05), Color = color, Material = Enum.Material.Neon, Transparency = 1, CanQuery = false }, folder)
		parts[i] = p
		self:tween(p, 0.6, { Transparency = (i % 2 == 0) and 0.72 or 0.82 })
	end
	local center = (self.heroCF * CFn(0, 1.2, 3.5)).Position
	local spin = 0
	table.insert(self.conns, RunService.RenderStepped:Connect(function(dt)
		spin += dt * 0.35
		local c = CFrame.lookAt(center, workspace.CurrentCamera.CFrame.Position)
		for i, p in ipairs(parts) do
			p.CFrame = c * ANG(0, 0, spin + i * 2 * PI / n) * CFn(0, 13.5, 0)
		end
	end))
end

-- accessoire de main pendant la démonstration
function Session:attachProp(name)
	self:detachProp()
	local def = name and self.data.Props[name]
	local arm = self.rig:FindFirstChild("Right Arm")
	if type(def) ~= "table" or not arm then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "ShowcaseProp"
	f.Parent = self.rig
	for _, d in ipairs(def) do
		if type(d) == "table" and typeof(d[1]) == "Vector3" then
			pcall(function()
				local p = Instance.new("Part")
				if typeof(d[4]) == "EnumItem" then
					p.Shape = d[4]
				end
				p.Size = d[1]
				p.Color = typeof(d[3]) == "Color3" and d[3] or WHITE
				p.Material = Enum.Material.SmoothPlastic
				p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
				p.CFrame = arm.CFrame * (typeof(d[2]) == "CFrame" and d[2] or CFn())
				local w = Instance.new("WeldConstraint")
				w.Part0 = arm
				w.Part1 = p
				w.Parent = p
				p.Parent = f
			end)
		end
	end
	self.propFolder = f
	if self.signature and self.signatureHand == "Right" then
		for _, p in ipairs(self.signature:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Transparency = 1
			end
		end
	end
end
function Session:detachProp()
	if self.propFolder then
		self.propFolder:Destroy()
		self.propFolder = nil
		if self.signature then
			for _, p in ipairs(self.signature:GetDescendants()) do
				if p:IsA("BasePart") and self.vis[p] then
					p.Transparency = self.vis[p]
				end
			end
		end
	end
end
function Session:hand()
	local arm = self.rig:FindFirstChild("Right Arm")
	return arm and (arm.CFrame * CFn(0, -1.2, 0)).Position or self.root.Position
end

-- mannequin en carton « BOB » (cible de la démonstration)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
function Session:groundY(pos)
	groundParams.FilterDescendantsInstances = { self.set }
	local r = workspace:Raycast(pos + V3(0, 3, 0), V3(0, -12, 0), groundParams)
	return r and r.Position.Y or (self.heroCF.Position.Y - 3)
end
function Session:buildTarget(pos)
	local gy = self:groundY(pos)
	self.targetFloorY = gy
	pos = V3(pos.X, gy + 3, pos.Z)
	local face = self.root.Position
	local cf = CFrame.lookAt(pos, V3(face.X, pos.Y, face.Z))
	local model = Instance.new("Model")
	model.Name = "Target"
	model.Parent = self.set
	local root = self:part({ Size = V3(2, 2.4, 0.3), CFrame = cf * CFn(0, -0.4, 0), Color = C3(205, 170, 120), CanQuery = false }, model)
	local function add(size, off, color)
		local p = self:part({ Size = size, CFrame = root.CFrame * off, Color = color, CanQuery = false, Anchored = false, Massless = true }, model)
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
		return p
	end
	local head = add(V3(1.3, 1.3, 0.3), CFn(0, 1.95, 0), C3(255, 205, 150))
	self:sign(head, "o_o", { Color = INK, Stroke = false })
	add(V3(0.35, 1.3, 0.32), CFn(0, 0.45, -0.02), C3(220, 50, 50))
	add(V3(0.5, 1.6, 0.28), CFn(-0.55, -1.8, 0), C3(60, 70, 100))
	add(V3(0.5, 1.6, 0.28), CFn(0.55, -1.8, 0), C3(60, 70, 100))
	add(V3(0.45, 2.0, 0.28), CFn(-1.25, 0.1, 0) * ANG(0, 0, 0.25), C3(205, 170, 120))
	add(V3(0.45, 2.0, 0.28), CFn(1.25, 0.1, 0) * ANG(0, 0, -0.25), C3(205, 170, 120))
	local tag = add(V3(1.2, 0.5, 0.32), CFn(0, -0.6, 0), WHITE)
	self:sign(tag, "BOB", { Color = INK, Stroke = false })
	pcall(CartoonFX.puff, pos, 2)
	self.target = root
	return root
end
function Session:knock(target, dir, pin, power)
	if not target or not target.Parent then
		return
	end
	local floorY = self.targetFloorY or (self.heroCF.Position.Y - 3)
	local p = target.Position
	if pin then
		self:tween(target, 0.14, { CFrame = CFn(p.X, floorY + 0.3, p.Z) * CFrame.lookAt(Vector3.zero, dir) * ANG(-PI / 2, 0, 0) }, ES.Quad, ED.In)
		pcall(CartoonFX.dust, V3(p.X, floorY, p.Z), 6)
	else
		local to = p + dir * (12 * (power or 1)) + V3(0, 5, 0)
		self:tween(target, 0.45, { CFrame = CFn(to) * ANG(rng:NextNumber(-3, 3), rng:NextNumber(-3, 3), rng:NextNumber(-3, 3)) }, ES.Quad, ED.Out)
		task.delay(0.45, function()
			if target.Parent then
				self:tween(target, 0.3, { CFrame = CFn(to.X + dir.X * 3, floorY + 0.4, to.Z + dir.Z * 3) * ANG(PI / 2, rng:NextNumber(0, 6), 0) }, ES.Quad, ED.In)
			end
		end)
	end
end
function Session:impact(target, dir, atk, power)
	local tpos = (target and target.Parent and target.Position) or self:hl(-8, 0, -2.5)
	local col = self.col
	pcall(CartoonFX.bigImpact, tpos, dir, power or 1.2, col)
	pcall(CartoonFX.sparks, tpos, 20, col)
	pcall(CartoonFX.impactFrame, 0.7)
	CartoonFX.shake(0.7)
	self:punch(6)
	self:sound((atk and atk.Category == "Splat") and "Splat" or "PunchHeavy", tpos, 0.9)
	self:sound("BigImpact", tpos, 0.6)
	local w = atk and atk.Words
	self:word(type(w) == "table" and w[#w] or "POW!", tpos + V3(0, 1.5, 0), 1.2, (atk and atk.Category) or "Heavy")
	self:knock(target, dir, atk and type(atk.Effects) == "table" and atk.Effects.Pin, power)
end

function Session:skip()
	if os.clock() - self.started < 0.35 then
		return
	end
	if self.phase == "scene" or self.phase == "setup" then
		self.skipped = true
	elseif self.phase == "card" and self.cardAt and os.clock() - self.cardAt > 0.3 then
		self.endNow = true
	end
end

------------------------------------------------------------------------
-- Aides de décor
------------------------------------------------------------------------
local function enclose(S, color, halfW, zBack, zFront, h)
	local depth = zBack - zFront
	local zc = (zBack + zFront) / 2
	S:box(V3(halfW * 2, h, 1), CFn(0, h / 2, zBack), color)
	S:box(V3(halfW * 2, h, 1), CFn(0, h / 2, zFront), color)
	S:box(V3(1, h, depth), CFn(-halfW, h / 2, zc), color)
	S:box(V3(1, h, depth), CFn(halfW, h / 2, zc), color)
	S:box(V3(halfW * 2, 1, depth), CFn(0, h, zc), color)
end
local function plant(S, x, z)
	S:cyl(1.6, 1.8, V3(x, 0.8, z), C3(150, 90, 55))
	S:box(V3(2.6, 2.6, 2.6), CFn(x, 2.6, z), C3(70, 170, 80), nil, nil, "Ball")
	S:box(V3(1.9, 1.9, 1.9), CFn(x + 0.5, 3.8, z - 0.2), C3(95, 195, 95), nil, nil, "Ball")
end
local function desk(S, x, z, rot)
	local o = CFn(x, 0, z) * ANG(0, rot or 0, 0)
	S:box(V3(5, 0.3, 2.6), o * CFn(0, 2.6, 0), C3(225, 220, 210))
	S:box(V3(0.3, 2.5, 2.4), o * CFn(-2.3, 1.25, 0), C3(120, 120, 130))
	S:box(V3(0.3, 2.5, 2.4), o * CFn(2.3, 1.25, 0), C3(120, 120, 130))
	S:box(V3(2.2, 1.4, 0.2), o * CFn(0, 3.65, 0.7), C3(30, 30, 35))
	S:box(V3(2.0, 1.2, 0.05), o * CFn(0, 3.65, 0.58), C3(90, 170, 255), "Neon")
	S:box(V3(0.3, 0.6, 0.3), o * CFn(0, 2.95, 0.8), C3(30, 30, 35))
	S:box(V3(1.8, 0.1, 0.6), o * CFn(0, 2.8, -0.3), C3(40, 40, 45))
	S:box(V3(1.8, 0.35, 1.8), o * CFn(0, 1.7, -1.9), C3(40, 40, 50))
	S:box(V3(1.8, 2, 0.3), o * CFn(0, 2.8, -2.75), C3(40, 40, 50))
	S:cyl(1.5, 0.3, (o * CFn(0, 0.8, -1.9)).Position, C3(80, 80, 90))
end

------------------------------------------------------------------------
-- MODÈLES DE SCÈNE
-- build(S) : construit le décor (repère local : sol à y = 0, le héros regarde vers -Z, la caméra est côté -Z)
--            peut définir S.heroCF (pose finale) et S.startCF (position au début du scénario)
-- intro(S) : le scénario ; doit finir avec le perso sur S.heroCF
-- finish(S) : (optionnel) remet le décor dans son état final si le joueur passe la scène
-- Zone à garder libre pour la démonstration : x de -11 à +2, z de -6 à +1 autour du héros.
------------------------------------------------------------------------
local SCENES = {}

SCENES.Elevator = {
	Location = "Lobby - Elevator 3",
	build = function(S)
		local wall, metal = C3(214, 200, 182), C3(186, 192, 204)
		S:floor(V3(70, 1, 60), CFn(0, -0.5, -10), C3(214, 205, 190), "Marble")
		S:box(V3(7, 0.06, 30), CFn(0, 0.03, -9), C3(150, 30, 45), "Fabric")
		S:box(V3(27, 18, 1), CFn(-16.5, 9, 5.5), wall)
		S:box(V3(27, 18, 1), CFn(16.5, 9, 5.5), wall)
		S:box(V3(6, 10, 1), CFn(0, 13, 5.5), wall)
		S:box(V3(0.5, 8.5, 1.4), CFn(-3.2, 4.25, 5.4), metal, "Metal")
		S:box(V3(0.5, 8.5, 1.4), CFn(3.2, 4.25, 5.4), metal, "Metal")
		S:box(V3(6.9, 0.5, 1.4), CFn(0, 8.5, 5.4), metal, "Metal")
		local woodC = C3(196, 160, 110)
		S:box(V3(6, 8, 0.5), CFn(0, 4, 12.2), woodC, "Wood")
		S:box(V3(0.5, 8, 6.4), CFn(-3.1, 4, 9), woodC, "Wood")
		S:box(V3(0.5, 8, 6.4), CFn(3.1, 4, 9), woodC, "Wood")
		S:box(V3(6.4, 0.2, 6.4), CFn(0, 0.1, 9), C3(60, 60, 70))
		S:box(V3(6.4, 0.4, 6.6), CFn(0, 8.2, 9), C3(235, 235, 235))
		local lampP = S:box(V3(4, 0.1, 4), CFn(0, 7.95, 9), C3(255, 246, 220), "Neon")
		S.elLight = S:light(lampP, C3(255, 238, 205), 16, 0, Enum.NormalId.Bottom, 100)
		S:box(V3(5, 0.2, 0.2), CFn(0, 3, 11.85), C3(225, 195, 110), "Metal")
		S:box(V3(4.6, 5, 0.1), CFn(0, 4.6, 11.9), C3(200, 225, 240), "Glass", 0.3)
		S.doorL = S:box(V3(3, 8, 0.3), CFn(-1.5, 4, 5.5), metal, "Metal")
		S.doorR = S:box(V3(3, 8, 0.3), CFn(1.5, 4, 5.5), metal, "Metal")
		local ind = S:box(V3(3, 1.1, 0.2), CFn(0, 9.6, 4.85), C3(20, 20, 26))
		S.indLbl = S:sign(ind, "1", { Color = C3(255, 160, 40), Stroke = false })
		S:box(V3(0.7, 1.2, 0.15), CFn(4.3, 4, 4.95), C3(40, 40, 46))
		S.callBtn = S:box(V3(0.35, 0.35, 0.1), CFn(4.3, 4.2, 4.85), C3(255, 200, 60), "Neon")
		plant(S, -7, 3.2)
		plant(S, 7, 3.2)
		local sg = S:box(V3(8, 1.4, 0.2), CFn(-12, 10, 4.9), C3(40, 50, 80))
		S:sign(sg, "WELCOME", { Color = C3(255, 220, 80) })
		S:lamp(V3(0, 14, -6), C3(255, 240, 220), 40, 1)
		S.startCF = S:at(0, 3, 9)
	end,
	intro = function(S)
		S:place(S.startCF)
		S:pose("Boss")
		S:cam(S:look(V3(0, 5.2, -17), V3(0, 4.6, 5)), 46)
		S:shot(S:look(V3(0, 4.4, -9.5), V3(0, 4, 5)), S:pick(1.8, 2.4, 3.2), 40, ES.Sine, ED.InOut)
		local stops = S:pick({ "2", "3" }, { "4", "8", "12" }, { "10", "20", "30", "40", "PH" })
		for _, n in ipairs(stops) do
			S.indLbl.Text = n
			S:sound("UIClick", nil, 0.35)
			S:wait(0.14)
		end
		S:sound("Ding", S:wp(0, 6, 5), 1)
		S.callBtn.Color = C3(90, 255, 120)
		S:tween(S.elLight, 0.25, { Brightness = 6 })
		S:tween(S.doorL, 0.6, { CFrame = S:at(-4.5, 4, 5.5) }, ES.Quad, ED.InOut)
		S:tween(S.doorR, 0.6, { CFrame = S:at(4.5, 4, 5.5) }, ES.Quad, ED.InOut)
		S:sound("Whoosh", nil, 0.6)
		S:wait(S:pick(0.45, 0.7, 0.9))
		local walk = S:pick(0.7, 1.0, 1.2)
		S:anim("Reveal_Walk")
		S:move(S.heroCF, walk, ES.Linear)
		S:wait(walk)
		S:anim("Reveal_Stop")
	end,
	finish = function(S)
		S.doorL.CFrame = S:at(-4.5, 4, 5.5)
		S.doorR.CFrame = S:at(4.5, 4, 5.5)
		S.elLight.Brightness = 6
	end,
}

SCENES.Spotlight = {
	Location = "Main Stage - All Hands Meeting",
	build = function(S)
		local dark = C3(18, 16, 26)
		S.heroCF = S:at(0, 4, 0)
		S:floor(V3(80, 1, 80), CFn(0, -0.5, -10), dark)
		S:floor(V3(34, 1, 18), CFn(0, 0.5, 1), C3(115, 75, 48), "Wood")
		S:box(V3(34, 0.25, 0.3), CFn(0, 1.02, -7.9), C3(255, 205, 70), "Neon")
		enclose(S, dark, 26, 12, -36, 30)
		for i = -7, 7 do
			S:cyl(22, 2.6, V3(i * 2.3, 11, 10), C3(165, 22, 40), "Fabric")
		end
		S:box(V3(36, 3, 1), CFn(0, 21, 9), C3(130, 15, 30), "Fabric")
		local b = S:box(V3(16, 2.4, 0.3), CFn(0, 16, 8.4), C3(30, 28, 44))
		S:sign(b, "ALL HANDS MEETING", { Color = C3(255, 215, 60) })
		S.spots = {}
		for i, x in ipairs({ 0, -9, 9 }) do
			local from, to = V3(x, 22, -11), V3(x * 0.12, 1, 0.3)
			local lampP = S:box(V3(1.6, 1.6, 2.4), CFrame.lookAt(from, to), C3(45, 45, 52), "Metal")
			local len = (to - from).Magnitude
			local beam = S:box(V3(len, 3.6, 3.6), CFrame.lookAt(from:Lerp(to, 0.5), to) * ANG(0, PI / 2, 0), C3(255, 248, 215), "Neon", 1, "Cyl")
			beam.CanQuery = false
			local pool = S:box(V3(0.05, 6.5, 6.5), CFn(to + V3(0, 0.03, 0)) * ANG(0, 0, PI / 2), C3(255, 248, 215), "Neon", 1, "Cyl")
			pool.CanQuery = false
			local spot = S:light(lampP, C3(255, 245, 220), 45, 0, Enum.NormalId.Front, 22)
			S.spots[i] = { beam = beam, pool = pool, spot = spot }
		end
		S.smoke = {}
		for i = 1, 12 do
			local x = rng:NextNumber(3.5, 13) * (i % 2 == 0 and 1 or -1)
			local p = S:box(Vector3.one * rng:NextNumber(2, 3.4), CFn(x, 1.4, rng:NextNumber(1, 8)), C3(190, 190, 205), nil, 1, "Ball")
			p.CanQuery = false
			p.CastShadow = false
			S.smoke[i] = p
		end
	end,
	intro = function(S)
		S:place(S.heroCF)
		S:pose("Boss")
		S:cam(S:look(V3(0, 7, -24), V3(0, 4.5, 2)), 44)
		S:shot(S:look(V3(0, 5.2, -12.5), V3(0, 4.8, 1)), S:pick(1.7, 2.3, 3.0), 38, ES.Sine, ED.InOut)
		S:sound("Rumble", nil, 0.5)
		for _, p in ipairs(S.smoke) do
			S:tween(p, 1.6, { Transparency = 0.72, Size = p.Size * 1.3, CFrame = p.CFrame + V3(rng:NextNumber(-1, 1), 0.6, rng:NextNumber(0, 1)) }, ES.Sine)
		end
		S:wait(S:pick(0.45, 0.55, 0.6))
		for _, i in ipairs(S:pick({ 1 }, { 2, 3, 1 }, { 2, 3, 1 })) do
			local sp = S.spots[i]
			sp.beam.Transparency = 0.9
			sp.pool.Transparency = 0.6
			sp.spot.Brightness = (i == 1) and 12 or 6
			S:sound("Thud", nil, 0.9)
			S:sound("Clang", nil, 0.4)
			CartoonFX.shake(0.15)
			S:wait(S:pick(0.5, 0.35, 0.45))
		end
		S:wait(0.2)
	end,
	finish = function(S)
		for _, sp in ipairs(S.spots) do
			sp.beam.Transparency = 0.9
			sp.pool.Transparency = 0.6
			sp.spot.Brightness = 8
		end
	end,
}

SCENES.SkyDrop = {
	Location = "Open Space - Floor 7",
	build = function(S)
		local ceilC = C3(236, 236, 230)
		S:floor(V3(70, 1, 60), CFn(0, -0.5, -10), C3(92, 108, 140), "Fabric")
		S:box(V3(29, 1, 60), CFn(-20.5, 14.5, -10), ceilC)
		S:box(V3(29, 1, 60), CFn(20.5, 14.5, -10), ceilC)
		S:box(V3(12, 1, 34), CFn(0, 14.5, -23), ceilC)
		S:box(V3(12, 1, 14), CFn(0, 14.5, 13), ceilC)
		S.tiles = {}
		for ix = -1, 1 do
			for iz = -1, 1 do
				table.insert(S.tiles, S:box(V3(3.95, 0.6, 3.95), CFn(ix * 4, 14.5, iz * 4), ceilC))
			end
		end
		for _, x in ipairs({ -12, 12 }) do
			for _, z in ipairs({ -14, -2, 10 }) do
				S:box(V3(4, 0.1, 1.6), CFn(x, 13.95, z), C3(255, 252, 235), "Neon")
			end
		end
		S:box(V3(70, 16, 1), CFn(0, 8, 20), C3(225, 230, 238))
		for i = -3, 3 do
			S:box(V3(6, 7, 0.2), CFn(i * 8, 8, 19.4), C3(160, 210, 245), "Glass", 0.3)
		end
		S:box(V3(1, 16, 60), CFn(-30, 8, -10), C3(225, 230, 238))
		S:box(V3(1, 16, 60), CFn(30, 8, -10), C3(225, 230, 238))
		desk(S, -10, 5, 0)
		desk(S, 10, 5, 0)
		desk(S, 11, -8, PI / 2)
		desk(S, -16, -8, -PI / 2)
		plant(S, 5.5, 9)
		S:lamp(V3(0, 12, -8), C3(255, 245, 230), 40, 1.2)
		S.skyBeam = S:box(V3(15, 4.5, 4.5), CFn(0, 7.2, 0) * ANG(0, 0, PI / 2), C3(255, 250, 230), "Neon", 1, "Cyl")
		S.skyBeam.CanQuery = false
		S.startCF = S:at(0, 26, 0)
	end,
	intro = function(S)
		S:place(S.startCF)
		S:pose("Fall")
		S:cam(S:look(V3(3, 2.6, -13), V3(0, 9, 0)), 56)
		S:shot(S:look(V3(2.5, 2.4, -11.5), V3(0, 8, 0)), 1.0, 54)
		S:sound("Rumble", nil, 0.8)
		for i = 1, S:pick(4, 6, 9) do
			CartoonFX.shake(0.08 + i * 0.03)
			local t = S.tiles[rng:NextInteger(1, #S.tiles)]
			S:tween(t, 0.05, { CFrame = t.CFrame * ANG(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)) })
			local d = S:part({ Size = Vector3.one * 0.35, CFrame = t.CFrame * CFn(rng:NextNumber(-1.5, 1.5), -0.4, rng:NextNumber(-1.5, 1.5)), Color = C3(200, 200, 195), CanQuery = false })
			S:tween(d, 0.6, { CFrame = d.CFrame - V3(0, 13, 0) }, ES.Quad, ED.In)
			Debris:AddItem(d, 0.65)
			S:wait(0.1)
		end
		S:sound("Crash", S:wp(0, 14, 0), 1)
		S:sound("Explosion", nil, 0.6)
		for _, t in ipairs(S.tiles) do
			local to = CFn(t.Position.X + rng:NextNumber(-3, 3), S.O.Y + 0.4, t.Position.Z + rng:NextNumber(-3, 3)) * ANG(rng:NextNumber(-1, 1), rng:NextNumber(0, 6), rng:NextNumber(-1, 1))
			S:tween(t, rng:NextNumber(0.4, 0.55), { CFrame = to }, ES.Quad, ED.In)
		end
		pcall(CartoonFX.debris, S:wp(0, 14, 0), 8, { C3(236, 236, 230), C3(200, 200, 195) }, 0.6)
		S.skyBeam.Transparency = 0.9
		S:move(S.heroCF * CFn(0, -0.6, 0), 0.34, ES.Quad, ED.In)
		S:wait(0.34)
		S:pose("Crouch")
		pcall(CartoonFX.quake, S.heroCF.Position - V3(0, 3, 0), 12, S.rc, 1.2)
		CartoonFX.shake(1.1)
		S:punch(10)
		S:sound("GroundSlam", nil, 1)
		S:word("CRASH!", S:hl(0, 1, 0), 1.3, "Heavy")
		for _, t in ipairs(S.tiles) do
			S:delay(0.6, function()
				S:tween(t, 0.4, { Transparency = 1 })
			end)
		end
		S:shot(S:look(V3(1.6, 3, -9), V3(0, 3, 0)), 0.5, 50, ES.Quad, ED.Out)
		S:wait(S:pick(0.5, 0.7, 0.9))
		S:anim("Reveal_Stop")
		S:move(S.heroCF, 0.25)
		S:wait(0.25)
	end,
	finish = function(S)
		for _, t in ipairs(S.tiles) do
			t.Transparency = 1
		end
		S.skyBeam.Transparency = 0.9
	end,
}

SCENES.ChairSpin = {
	Location = "Corner Office - After Hours",
	build = function(S)
		S:floor(V3(60, 1, 50), CFn(0, -0.5, -8), C3(72, 52, 46), "Fabric")
		S:box(V3(11, 0.06, 8), CFn(0, 0.03, 0), C3(140, 40, 45), "Fabric")
		local frame = C3(40, 40, 48)
		S:box(V3(60, 2, 1), CFn(0, 1, 9), frame)
		S:box(V3(60, 2, 1), CFn(0, 17, 9), frame)
		for i = -4, 4 do
			S:box(V3(0.5, 14, 0.8), CFn(i * 6, 9, 9), frame, "Metal")
		end
		S:box(V3(60, 14, 0.2), CFn(0, 9, 9), C3(150, 180, 230), "Glass", 0.65)
		for i = 1, 16 do
			local w, h = rng:NextNumber(5, 9), rng:NextNumber(14, 36)
			local x, z = -42 + i * 5 + rng:NextNumber(-1, 1), rng:NextNumber(30, 50)
			S:box(V3(w, h, w), CFn(x, h / 2 - 8, z), C3(28, 34, 60))
			for _ = 1, 4 do
				S:box(V3(0.8, 0.6, 0.1), CFn(x + rng:NextNumber(-w / 2 + 0.6, w / 2 - 0.6), rng:NextNumber(0, h - 9), z - w / 2 - 0.06), C3(255, 220, 120), "Neon")
			end
		end
		S:box(V3(220, 90, 1), CFn(0, 20, 72), C3(255, 150, 100))
		local wood = C3(60, 38, 28)
		S:box(V3(3, 0.4, 6), CFn(7.5, 2.8, -0.5), wood, "Wood")
		S:box(V3(2.8, 2.6, 0.3), CFn(7.5, 1.3, -3.2), wood, "Wood")
		S:box(V3(2.8, 2.6, 0.3), CFn(7.5, 1.3, 2.2), wood, "Wood")
		local plate = S:box(V3(2.6, 0.5, 0.2), CFn(7.5, 3.25, -3.3), C3(220, 180, 60), "Metal")
		S:sign(plate, string.upper(S.charDef.DisplayName or "THE BOSS"), { Color = INK, Stroke = false })
		S:box(V3(1.5, 8, 5), CFn(-10, 4, 3), C3(90, 60, 40), "Wood")
		for k = 0, 2 do
			for j = -2, 2 do
				S:box(V3(0.6, 1.4, 0.7), CFn(-9.6, 1.5 + k * 2.4, 3 + j * 0.85), Color3.fromHSV(rng:NextNumber(), 0.6, 0.8))
			end
		end
		plant(S, -8, -5)
		local pivot = S:box(V3(0.4, 0.4, 0.4), CFn(0, 0, 1.5) * ANG(0, PI, 0), WHITE, nil, 1)
		pivot.CanQuery = false
		S.chairPivot = pivot
		local function cp(size, off, color)
			local p = S:part({ Size = size, CFrame = pivot.CFrame * off, Color = color, Anchored = false, Massless = true })
			local w = Instance.new("WeldConstraint")
			w.Part0 = pivot
			w.Part1 = p
			w.Parent = p
			return p
		end
		local leather = C3(35, 30, 32)
		cp(V3(0.5, 2, 0.5), CFn(0, 1, 0), C3(80, 80, 90))
		cp(V3(2.8, 0.3, 2.8), CFn(0, 0.15, 0), C3(60, 60, 70))
		cp(V3(2.6, 0.5, 2.6), CFn(0, 2.05, 0), leather)
		cp(V3(2.8, 4.4, 0.6), CFn(0, 4.3, 1.3), leather)
		cp(V3(2.2, 1, 0.6), CFn(0, 6.9, 1.3), leather)
		cp(V3(0.4, 0.4, 2.2), CFn(-1.5, 3, 0), leather)
		cp(V3(0.4, 0.4, 2.2), CFn(1.5, 3, 0), leather)
		S:lamp(V3(0, 10, -6), C3(255, 210, 170), 30, 1)
		S.heroCF = S:at(0, 3, -2.6)
		S.cc.TintColor = C3(255, 232, 210)
	end,
	intro = function(S)
		S:pose("Sit")
		local function setRot(a)
			S.chairPivot.CFrame = S:at(0, 0, 1.5) * ANG(0, a, 0)
			S:place(S.chairPivot.CFrame * CFn(0, 3.25, -0.1))
		end
		setRot(PI)
		S:cam(S:look(V3(1, 4.8, -9.5), V3(0, 3.6, 1.5)), 50)
		S:shot(S:look(V3(0.5, 4.2, -7.2), V3(0, 3.6, 1.5)), S:pick(1.4, 2.0, 2.6), 44, ES.Sine, ED.InOut)
		S:wait(S:pick(0.3, 0.5, 0.8))
		S:sound("Squeak", nil, 0.9)
		local dur = S:pick(0.55, 0.85, 1.2)
		local e = 0
		while e < dur do
			e += task.wait()
			S:check()
			setRot(PI * (1 - TweenService:GetValue(math.min(e / dur, 1), ES.Back, ED.Out)))
		end
		setRot(0)
		if S.tier >= 3 then
			S:flash(C3(220, 235, 255), 0.02, 0.05, 0.3, 0.3)
			S:sound("Rumble")
		end
		S:wait(S:pick(0.25, 0.45, 0.6))
		S:anim("Reveal_Stop")
		S:arc(S.heroCF, 0.4, 1.2)
	end,
	finish = function(S)
		S.chairPivot.CFrame = S:at(0, 0, 1.5)
	end,
}

SCENES.Delivery = {
	Location = "Loading Dock B - Express Delivery",
	build = function(S)
		S:floor(V3(70, 1, 60), CFn(0, -0.5, -10), C3(150, 150, 156), "Concrete")
		for i = -10, 10 do
			S:box(V3(1.5, 0.05, 0.8), CFn(i * 1.6, 0.03, 7.5), (i % 2 == 0) and C3(255, 205, 40) or C3(30, 30, 30))
		end
		S:box(V3(70, 20, 1), CFn(0, 10, 10), C3(120, 125, 135))
		for k = 0, 11 do
			S:box(V3(14, 0.6, 0.3), CFn(0, 0.6 + k * 0.75, 9.3), (k % 2 == 0) and C3(175, 180, 188) or C3(150, 155, 165), "Metal")
		end
		S:box(V3(0.6, 10, 0.6), CFn(-7.3, 5, 9.3), C3(255, 205, 40))
		S:box(V3(0.6, 10, 0.6), CFn(7.3, 5, 9.3), C3(255, 205, 40))
		local sg = S:box(V3(10, 1.6, 0.2), CFn(0, 11.5, 9.4), C3(30, 40, 70))
		S:sign(sg, "LOADING DOCK B", { Color = C3(255, 215, 60) })
		for _, x in ipairs({ 13, -14 }) do
			S:box(V3(4, 0.3, 12), CFn(x, 3, 3), C3(60, 90, 160))
			S:box(V3(4, 0.3, 12), CFn(x, 6.5, 3), C3(60, 90, 160))
			for _, dz in ipairs({ -5.8, 5.8 }) do
				S:box(V3(0.3, 9, 0.3), CFn(x - 1.8, 4.5, 3 + dz), C3(255, 140, 40))
				S:box(V3(0.3, 9, 0.3), CFn(x + 1.8, 4.5, 3 + dz), C3(255, 140, 40))
			end
			for k = 1, 5 do
				S:box(V3(2.4, 2, 2.4), CFn(x + rng:NextNumber(-0.3, 0.3), 4.15, -1.8 + k * 2.2), C3(200, 160, 105))
			end
		end
		local cardboard = C3(200, 160, 105)
		S.box5 = {}
		local function face(size, lcf, kind)
			local p = S:box(size, lcf, cardboard)
			table.insert(S.box5, { p = p, base = p.CFrame, kind = kind })
			return p
		end
		local front = face(V3(4.8, 6, 0.2), CFn(0, 3, -2.4), "F")
		S:sign(front, "FRAGILE", { Color = C3(220, 40, 40), Stroke = false })
		face(V3(4.8, 6, 0.2), CFn(0, 3, 2.4), "B")
		face(V3(0.2, 6, 4.8), CFn(-2.4, 3, 0), "L")
		face(V3(0.2, 6, 4.8), CFn(2.4, 3, 0), "R")
		local top = face(V3(5, 0.2, 5), CFn(0, 6.1, 0), "T")
		local tape = S:part({ Size = V3(0.9, 0.05, 5.05), CFrame = top.CFrame * CFn(0, 0.12, 0), Color = C3(225, 200, 150), Anchored = false, Massless = true })
		local w = Instance.new("WeldConstraint")
		w.Part0 = top
		w.Part1 = tape
		w.Parent = tape
		S.boxTape = tape
		S:lamp(V3(0, 13, -6), C3(255, 245, 230), 40, 1)
	end,
	intro = function(S)
		S:place(S.heroCF * CFn(0, -1.4, 0))
		S:pose("Crouch")
		S:alpha(0)
		for _, f in ipairs(S.box5) do
			f.p.CFrame = f.base + V3(0, 30, 0)
		end
		S:cam(S:look(V3(-4, 4.2, -15), V3(0, 5, 0)), 50)
		S:shot(S:look(V3(-2.5, 3.8, -11), V3(0, 3.6, 0)), S:pick(1.6, 2.4, 3.0), 44, ES.Sine, ED.InOut)
		S:sound("Whoosh", nil, 0.9)
		for _, f in ipairs(S.box5) do
			S:tween(f.p, 0.45, { CFrame = f.base }, ES.Quad, ED.In)
		end
		S:wait(0.45)
		S:alpha(1)
		S:sound("Thud", nil, 1)
		S:sound("Crash", nil, 0.5)
		CartoonFX.shake(0.6)
		pcall(CartoonFX.dust, S:hl(0, -3, 0), 8)
		S:wait(0.25)
		for _ = 1, S:pick(1, 2, 3) do
			for _, f in ipairs(S.box5) do
				S:tween(f.p, 0.06, { CFrame = f.base * ANG(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)) + V3(0, 0.3, 0) })
			end
			S:sound("Bonk", nil, 0.7)
			S:wait(0.1)
			for _, f in ipairs(S.box5) do
				S:tween(f.p, 0.08, { CFrame = f.base })
			end
			S:wait(0.22)
		end
		S:sound("WoodBreak", nil, 0.8)
		S:sound("Boing", nil, 0.8)
		local floorY = S.O.Y
		for _, f in ipairs(S.box5) do
			local pos = f.base.Position
			local to
			if f.kind == "T" then
				to = CFn(pos + V3(rng:NextNumber(-3, 3), 9, 3)) * ANG(1.2, 0.6, 0.4)
			else
				local out = ((pos - S.heroCF.Position) * V3(1, 0, 1)).Unit
				local lay = CFn(V3(pos.X, floorY + 0.1, pos.Z) + out * 3)
				to = (f.kind == "F" or f.kind == "B") and lay * ANG(PI / 2, 0, 0) or lay * ANG(0, 0, PI / 2)
			end
			S:tween(f.p, 0.32, { CFrame = to }, ES.Quad, ED.In)
		end
		S:delay(0.5, function()
			for _, f in ipairs(S.box5) do
				if f.kind == "T" then
					S:tween(f.p, 0.3, { Transparency = 1 })
					S:tween(S.boxTape, 0.3, { Transparency = 1 })
				end
			end
		end)
		S:confetti(S:hl(0, 0, 0), S:pick(16, 26, 40), { C3(255, 250, 235), C3(240, 230, 200), S.rc }, 6, 9)
		S:pose("Victory")
		S:arc(S.heroCF, 0.45, 3.2)
		pcall(CartoonFX.dust, S:hl(0, -3, 0), 6)
		S:wait(S:pick(0.2, 0.35, 0.5))
	end,
	finish = function(S)
		for _, f in ipairs(S.box5) do
			f.p.Transparency = 1
			for _, d in ipairs(f.p:GetChildren()) do
				if d:IsA("SurfaceGui") then
					d.Enabled = false
				end
			end
		end
		S.boxTape.Transparency = 1
	end,
}

SCENES.Hologram = {
	Location = "R&D Lab - Prototype Bay",
	build = function(S)
		local dark = C3(24, 28, 42)
		local cyan = C3(60, 230, 255)
		S:floor(V3(70, 1, 60), CFn(0, -0.5, -10), dark)
		for i = -6, 6 do
			S:box(V3(0.12, 0.04, 48), CFn(i * 4, 0.02, -12), cyan, "Neon", 0.75)
		end
		for k = -8, 2 do
			S:box(V3(48, 0.04, 0.12), CFn(0, 0.02, k * 4), cyan, "Neon", 0.75)
		end
		enclose(S, dark, 25, 12, -36, 22)
		S:cyl(0.3, 9, V3(0, 0.15, 0), C3(70, 78, 98), "Metal")
		S:cyl(0.22, 9.8, V3(0, 0.11, 0), cyan, "Neon")
		S:cyl(0.32, 5, V3(0, 0.16, 0), C3(90, 100, 125), "Metal")
		for _, a in ipairs({ math.rad(75), math.rad(-75), PI }) do
			local x, z = math.sin(a) * 5.6, -math.cos(a) * 5.6
			S:cyl(7, 0.8, V3(x, 3.5, z), C3(60, 68, 88), "Metal")
			S:box(Vector3.one * 0.9, CFn(x, 7.3, z), cyan, "Neon", nil, "Ball")
		end
		local texts = { "PROTOTYPE", "DNA: 100%", "SCANNING...", "UPLOAD OK", "DO NOT TOUCH" }
		for i = -2, 2 do
			local scr = S:box(V3(5, 3, 0.2), CFn(i * 6, 6, 11.4), C3(20, 60, 90), "Neon")
			S:sign(scr, texts[i + 3], { Color = cyan, Stroke = false })
		end
		S.rings = {}
		for i = 1, 3 do
			local r = S:cyl(0.15, 5.6, V3(0, 0.7, 0), cyan, "Neon", 1)
			r.CanQuery = false
			S.rings[i] = r
		end
		S:lamp(V3(0, 9, 0), cyan, 26, 1.5)
		S:lamp(V3(0, 9, -10), C3(150, 170, 255), 30, 0.8)
		S.heroCF = S:at(0, 3.3, 0)
	end,
	intro = function(S)
		S:place(S.heroCF)
		S:pose("Boss")
		S:alpha(0)
		local c = S.heroCF.Position
		S:orbit(c + V3(0, 0.6, 0), 11, 1.6, -0.7, 0.12, S:pick(1.6, 2.2, 2.9), 50, 42)
		S:sound("Electric", nil, 0.7)
		local dur = S:pick(1.0, 1.4, 1.9)
		local e, nxt = 0, 0
		while e < dur do
			e += task.wait()
			S:check()
			local a = math.min(e / dur, 1)
			for k, r in ipairs(S.rings) do
				r.Transparency = 0.15
				r.CFrame = S:at(0, 0.5 + ((a * 2.5 + k / 3) % 1) * 6.2, 0) * ANG(0, 0, PI / 2)
			end
			if e >= nxt then
				nxt = e + 0.08
				S:alpha(rng:NextNumber() < 0.35 and a * 0.3 or a)
				if rng:NextNumber() < 0.6 then
					S:cubes(c, 3, { C3(60, 230, 255), C3(170, 120, 255) }, 1.6)
				end
			end
		end
		for _, r in ipairs(S.rings) do
			S:tween(r, 0.3, { Transparency = 1 })
		end
		S:alpha(1)
		pcall(CartoonFX.shockwave, c - V3(0, 2.9, 0), 10, C3(60, 230, 255))
		pcall(CartoonFX.sparks, c, 16, C3(60, 230, 255))
		S:sound("Ding", nil, 0.9)
		S:wait(S:pick(0.25, 0.4, 0.6))
	end,
	finish = function(S)
		for _, r in ipairs(S.rings) do
			r.Transparency = 1
		end
	end,
}

SCENES.Kitchen = {
	Location = "Break Room - Label Your Food",
	build = function(S)
		S:floor(V3(60, 1, 50), CFn(0, -0.5, -8), C3(245, 245, 240))
		for ix = -6, 5 do
			for iz = -6, 1 do
				if (ix + iz) % 2 == 0 then
					S:box(V3(5, 0.04, 5), CFn(ix * 5 + 2.5, 0.02, iz * 5 + 2.5), C3(220, 70, 70))
				end
			end
		end
		S:box(V3(60, 18, 1), CFn(0, 9, 10.5), C3(255, 236, 200))
		S:box(V3(26, 3, 3), CFn(0, 1.5, 8.5), C3(110, 170, 200))
		S:box(V3(26.4, 0.3, 3.4), CFn(0, 3.15, 8.5), C3(240, 240, 235), "Marble")
		S:box(V3(26, 3, 1.6), CFn(0, 8.5, 9.6), C3(110, 170, 200))
		S:box(V3(4, 0.15, 2.4), CFn(-6, 3.37, 8.4), C3(30, 30, 35))
		S.burners = {}
		for _, dx in ipairs({ -0.9, 0.9 }) do
			table.insert(S.burners, S:cyl(0.06, 1.2, V3(-6 + dx, 3.46, 8.4), C3(80, 30, 30), "Neon"))
		end
		S:box(V3(3.2, 1.9, 2.2), CFn(4, 4.3, 8.6), C3(235, 235, 240))
		local win = S:box(V3(2, 1.3, 0.05), CFn(3.6, 4.3, 7.48), C3(40, 40, 50), "Glass")
		local disp = S:box(V3(0.7, 0.45, 0.05), CFn(5.1, 4.65, 7.48), C3(15, 20, 15))
		S.mwLbl = S:sign(disp, "0:03", { Color = C3(80, 255, 120), Stroke = false })
		S.mwLight = S:light(win, C3(255, 220, 120), 6, 0)
		S:box(V3(1.6, 2.4, 1.8), CFn(9, 4.5, 8.6), C3(40, 40, 45))
		S:cyl(0.6, 0.6, V3(9, 3.6, 7.8), WHITE)
		S:box(V3(4, 9, 3.4), CFn(-12, 4.5, 8.4), C3(240, 240, 245), "Metal")
		S:box(V3(0.2, 3, 0.3), CFn(-10.4, 5.5, 6.6), C3(150, 150, 160), "Metal")
		S:cyl(2.2, 0.8, V3(12, 1.1, 7), C3(220, 30, 30))
		local sg = S:box(V3(14, 1.4, 0.2), CFn(0, 12.2, 9.9), C3(220, 60, 60))
		S:sign(sg, "NO FISH IN THE MICROWAVE", { Color = WHITE })
		S:lamp(V3(0, 12, -4), C3(255, 240, 220), 40, 1)
	end,
	intro = function(S)
		S:place(S.heroCF)
		S:pose("Power")
		S:alpha(0)
		S:cam(S:look(V3(-3, 4.2, -10), V3(3, 4.2, 8)), 48)
		S:shot(S:look(V3(-1.5, 4.4, -8), V3(4, 4.4, 8)), 1.4, 42, ES.Sine, ED.InOut)
		S.mwLight.Brightness = 2
		for _, n in ipairs(S:pick({ "0:01" }, { "0:02", "0:01" }, { "0:03", "0:02", "0:01" })) do
			S.mwLbl.Text = n
			S:sound("UIClick", nil, 0.4)
			S:wait(0.3)
		end
		S.mwLbl.Text = "DING"
		S:sound("Ding", S:wp(4, 4, 8), 1)
		for _, b in ipairs(S.burners) do
			b.Color = C3(255, 90, 30)
		end
		S:wait(0.2)
		local c = S.heroCF.Position
		S:cam(S:look(V3(1.5, 3.4, -11), V3(0, 3.6, 0)), 50)
		S:shot(S:look(V3(1, 3.2, -8.5), V3(0, 3.4, 0)), 1, 46, ES.Quad, ED.Out)
		local outer = S:box(Vector3.one, CFn(0, 3, 0), C3(255, 120, 30), "Neon", 0.1, "Ball")
		local inner = S:box(Vector3.one, CFn(0, 3, 0), C3(255, 230, 90), "Neon", 0.05, "Ball")
		outer.CanQuery = false
		inner.CanQuery = false
		S:tween(outer, 0.18, { Size = Vector3.one * 10 })
		S:tween(inner, 0.18, { Size = Vector3.one * 7 })
		S:sound("Explosion", c, 1)
		S:flash(C3(255, 170, 60), 0.03, 0.05, 0.3, 0.2)
		CartoonFX.shake(1)
		pcall(CartoonFX.impactFrame, 0.7)
		S:wait(0.2)
		S:alpha(1)
		S:word("KABOOM!", c + V3(0, 3, 0), 1.3, "Heavy")
		S:tween(outer, 0.7, { Size = Vector3.one * 13, Transparency = 1 })
		S:tween(inner, 0.5, { Size = Vector3.one * 2, Transparency = 1 })
		for i = 1, 6 do
			local a = i / 6 * 2 * PI
			local fp = S:box(Vector3.one * 0.5, CFn(math.cos(a) * 2.6, 0.5, math.sin(a) * 2.6), WHITE, nil, 1)
			fp.CanQuery = false
			local f = Instance.new("Fire")
			f.Size = 4
			f.Heat = 8
			f.Color = C3(255, 120, 30)
			f.SecondaryColor = C3(255, 210, 80)
			f.Parent = fp
		end
		S:spawn(function()
			for _ = 1, 24 do
				local p = S:part({ Size = Vector3.one * rng:NextNumber(0.15, 0.35), CFrame = CFn(c + V3(rng:NextNumber(-2.5, 2.5), -2.5, rng:NextNumber(-2.5, 2.5))), Color = C3(255, rng:NextInteger(120, 210), 40), Material = Enum.Material.Neon, CanQuery = false })
				S:tween(p, 1.1, { CFrame = p.CFrame + V3(rng:NextNumber(-1, 1), rng:NextNumber(5, 8), rng:NextNumber(-1, 1)), Transparency = 1 }, ES.Sine)
				Debris:AddItem(p, 1.2)
				task.wait(0.05)
			end
		end)
		S:wait(S:pick(0.6, 0.8, 1.1))
	end,
	finish = function(S)
		S.mwLbl.Text = "DING"
	end,
}

SCENES.ServerRoom = {
	Location = "Server Room B2 - Do Not Unplug",
	build = function(S)
		local dark = C3(22, 24, 30)
		S:floor(V3(60, 1, 70), CFn(0, -0.5, -4), C3(60, 64, 74))
		for k = -10, 9 do
			S:box(V3(44, 0.04, 0.1), CFn(0, 0.02, k * 3), C3(35, 38, 45))
		end
		for i = -7, 7 do
			S:box(V3(0.1, 0.04, 60), CFn(i * 3, 0.02, -2), C3(35, 38, 45))
		end
		enclose(S, dark, 22, 31, -34, 13)
		S.leds = {}
		local ledC = { C3(60, 255, 120), C3(60, 170, 255), C3(255, 170, 40) }
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 5 do
				local z = 4 + i * 4.2
				S:box(V3(3, 9, 3.8), CFn(side * 6, 4.5, z), C3(28, 30, 36), "Metal")
				for _ = 1, 7 do
					local led = S:box(V3(0.1, 0.18, 0.3), CFn(side * 6 - side * 1.52, rng:NextNumber(1, 8.5), z + rng:NextNumber(-1.5, 1.5)), ledC[rng:NextInteger(1, 3)], "Neon")
					led.CanQuery = false
					table.insert(S.leds, led)
				end
			end
			S:box(V3(1.2, 0.3, 28), CFn(side * 5, 10.5, 16), C3(255, 200, 40))
		end
		local scr = S:box(V3(9, 2.6, 0.2), CFn(0, 8, 30.4), C3(15, 15, 20))
		S.accessLbl = S:sign(scr, "ACCESS DENIED", { Color = C3(255, 70, 70) })
		for _, z in ipairs({ 6, 14, 22 }) do
			S:lamp(V3(0, 9, z), C3(90, 160, 255), 20, 1.2)
		end
		S:lamp(V3(0, 9, -6), C3(120, 170, 255), 26, 1)
	end,
	intro = function(S)
		S:place(S.heroCF)
		S:pose("Boss")
		S:alpha(0)
		S:loop(0.12, function()
			for _, l in ipairs(S.leds) do
				if rng:NextNumber() < 0.25 then
					l.Transparency = (l.Transparency > 0.5) and 0 or 0.85
				end
			end
		end)
		S:cam(S:look(V3(0, 4.5, -20), V3(0, 3.6, 4)), 52)
		S:shot(S:look(V3(0.8, 3.9, -9), V3(0, 3.5, 2)), S:pick(1.5, 2.1, 2.8), 44, ES.Sine, ED.InOut)
		S:wait(S:pick(0.3, 0.5, 0.7))
		S:sound("Electric", nil, 0.8)
		local dur = S:pick(0.6, 0.9, 1.3)
		local e, nxt = 0, 0
		while e < dur do
			e += task.wait()
			S:check()
			if e >= nxt then
				nxt = e + 0.07
				local a = math.min(e / dur, 1)
				S:alpha(rng:NextNumber() < 0.5 and a or 0)
				S:place(S.heroCF * CFn(rng:NextNumber(-0.8, 0.8) * (1 - a), 0, 0))
				S:cubes(S.heroCF.Position, 3, { C3(0, 255, 220), C3(255, 0, 200) }, 1.8)
				S:glitchBars()
			end
		end
		S:alpha(1)
		S:place(S.heroCF)
		S.accessLbl.Text = "ACCESS GRANTED"
		S.accessLbl.TextColor3 = C3(80, 255, 120)
		pcall(CartoonFX.shockwave, S.heroCF.Position - V3(0, 2.9, 0), 11, C3(0, 255, 220))
		S:sound("Ding", nil, 0.8)
		S:wait(S:pick(0.25, 0.4, 0.55))
	end,
	finish = function(S)
		S.accessLbl.Text = "ACCESS GRANTED"
		S.accessLbl.TextColor3 = C3(80, 255, 120)
	end,
}

SCENES.Boardroom = {
	Location = "Boardroom - Q4 Review",
	build = function(S)
		local wood = C3(92, 58, 38)
		S:floor(V3(60, 1, 60), CFn(0, -0.5, -8), C3(42, 52, 84), "Fabric")
		S:box(V3(5.4, 0.45, 12.5), CFn(0, 3.0, 9), wood, "Wood")
		S:box(V3(2, 2.8, 9), CFn(0, 1.4, 9), C3(60, 38, 26), "Wood")
		for _, sx in ipairs({ -1, 1 }) do
			for _, z in ipairs({ 5, 8.5, 12 }) do
				S:box(V3(1.9, 0.4, 1.9), CFn(sx * 3.7, 1.9, z), C3(30, 30, 36))
				S:box(V3(0.4, 2.6, 1.9), CFn(sx * 4.7, 3.2, z), C3(30, 30, 36))
				S:cyl(1.7, 0.3, V3(sx * 3.7, 0.85, z), C3(90, 90, 100), "Metal")
			end
		end
		S.tableStuff = {}
		local function stuff(size, lcf, color, shape)
			local p = S:box(size, lcf, color, nil, nil, shape)
			table.insert(S.tableStuff, { p = p, base = p.CFrame })
		end
		for _, z in ipairs({ 5, 8.5, 12 }) do
			stuff(V3(1.1, 0.04, 1.4), CFn(-1.4, 3.25, z) * ANG(0, rng:NextNumber(-0.4, 0.4), 0), WHITE)
			stuff(V3(1.1, 0.04, 1.4), CFn(1.4, 3.25, z + 0.6) * ANG(0, rng:NextNumber(-0.4, 0.4), 0), WHITE)
			stuff(V3(0.6, 0.5, 0.5), CFn(1.8, 3.5, z - 0.8) * ANG(0, 0, PI / 2), WHITE, "Cyl")
		end
		S:box(V3(60, 18, 1), CFn(0, 9, 19), C3(205, 210, 220))
		S:box(V3(12, 6.5, 0.3), CFn(0, 8.5, 18.4), C3(20, 30, 60))
		local title = S:box(V3(11, 1.2, 0.05), CFn(0, 11, 18.22), C3(20, 30, 60))
		S:sign(title, "Q4 RESULTS", { Color = WHITE, Stroke = false })
		for i, h in ipairs({ 1, 1.6, 2.4, 3.6 }) do
			S:box(V3(1.4, h, 0.2), CFn(-4 + i * 1.7, 5.8 + h / 2, 18.2), C3(80, 220, 110), "Neon")
		end
		S:box(V3(3, 7.5, 0.8), CFn(0, 3.75, 16.6), C3(30, 30, 36))
		for _, sx in ipairs({ -1, 1 }) do
			S:box(V3(1, 18, 60), CFn(sx * 18, 9, -8), C3(205, 210, 220))
			for k = 0, 3 do
				S:box(V3(0.2, 7, 5), CFn(sx * 17.4, 8, 14 - k * 7), C3(150, 200, 240), "Glass", 0.3)
			end
		end
		S:lamp(V3(0, 11, 9), C3(255, 245, 230), 30, 1.3)
		S:lamp(V3(0, 10, -6), C3(255, 245, 230), 30, 0.8)
		S.startCF = S:at(0, 3, 15.5)
	end,
	intro = function(S)
		S:place(S.startCF)
		S:pose("Boss")
		S:cam(S:look(V3(1.2, 4.1, -2.5), V3(0, 4, 15.5)), 34)
		S:shot(S:look(V3(0.8, 4, 0.5), V3(0, 4.2, 15.5)), 0.9, 30, ES.Sine, ED.Out)
		S:wait(S:pick(0.2, 0.35, 0.5))
		S:anim("Slam")
		S:wait(0.37)
		CartoonFX.shake(0.9)
		S:punch(8)
		S:sound("Clang", nil, 1)
		S:sound("GroundSlam", nil, 0.7)
		pcall(CartoonFX.shockwave, S:wp(0, 3.3, 14), 6, S.rc)
		S:word(S.tier >= 3 and "ADJOURNED!" or "SLAM!", S:wp(0, 6, 14.5), 1.2, "Heavy")
		for _, s in ipairs(S.tableStuff) do
			local up = s.base + V3(rng:NextNumber(-0.3, 0.3), rng:NextNumber(1.2, 2.4), 0)
			S:tween(s.p, 0.18, { CFrame = up * ANG(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), 0) }, ES.Quad, ED.Out)
			S:delay(0.18, function()
				S:tween(s.p, 0.22, { CFrame = s.base * ANG(0, rng:NextNumber(-0.5, 0.5), 0) }, ES.Quad, ED.In)
			end)
		end
		S:wait(0.45)
		if S.tier >= 2 then
			S:shot(S:look(V3(3, 5.5, -9), V3(0, 4.5, 6)), 1.2, 46, ES.Sine, ED.InOut)
			S:anim("Reveal_Stop")
			S:arc(S:at(0, 6.25, 12.5), 0.35, 2)
			S:anim("Reveal_Run", 1.2)
			S:move(S:at(0, 6.25, 4), 0.55, ES.Linear)
			S:wait(0.55)
			S:anim("Reveal_Stop")
			S:arc(S.heroCF, 0.4, 2.2)
			pcall(CartoonFX.dust, S:hl(0, -3, 0), 7)
			S:sound("Thud", nil, 0.9)
		else
			S:flash(WHITE, 0.03, 0.03, 0.25, 0.2)
			S:place(S.heroCF)
			S:anim("Reveal_Stop")
		end
	end,
	finish = function(S)
		for _, s in ipairs(S.tableStuff) do
			s.p.CFrame = s.base
		end
	end,
}

SCENES.RedCarpet = {
	Location = "Lobby - Employee Of The Month Gala",
	build = function(S)
		S:floor(V3(70, 1, 70), CFn(0, -0.5, -8), C3(38, 36, 46))
		S:box(V3(7, 0.1, 36), CFn(0, 0.05, 6), C3(185, 18, 35), "Fabric")
		local gold = C3(235, 190, 60)
		for z = 2, 18, 4 do
			for _, sx in ipairs({ -1, 1 }) do
				S:cyl(2.6, 0.35, V3(sx * 4.6, 1.3, z), gold, "Metal")
				S:box(Vector3.one * 0.6, CFn(sx * 4.6, 2.75, z), gold, "Metal", nil, "Ball")
				if z < 18 then
					S:box(V3(4, 0.25, 0.25), CFn(sx * 4.6, 2.2, z + 2) * ANG(0, PI / 2, 0), C3(150, 20, 40), "Fabric", nil, "Cyl")
				end
			end
		end
		S:box(V3(30, 13, 1), CFn(0, 6.5, 24), WHITE)
		for ix = -2, 2 do
			for iy = 0, 2 do
				local p = S:box(V3(5, 3, 0.1), CFn(ix * 5.6, 2.5 + iy * 4, 23.45), WHITE)
				local even = (ix + iy) % 2 == 0
				S:sign(p, even and "OFFICE AWARDS" or "EMPLOYEE OF THE MONTH", { Color = even and C3(150, 60, 220) or C3(220, 160, 30), Stroke = false })
			end
		end
		S.flashes = {}
		for _, sx in ipairs({ -1, 1 }) do
			for k = 0, 3 do
				local x, z = sx * (7.5 + (k % 2) * 1.6), 3 + k * 4.5
				S:box(V3(1.8, 3, 1), CFn(x, 2.5, z), C3(50 + k * 8, 50, 62))
				S:box(V3(1.6, 1, 0.9), CFn(x, 0.5, z), C3(30, 30, 36))
				S:box(Vector3.one * 1.3, CFn(x, 4.7, z), C3(225, 190, 160), nil, nil, "Ball")
				local camCF = CFrame.lookAt(V3(x - sx * 0.9, 4.5, z), V3(0, 4, z - 2))
				S:box(V3(0.9, 0.7, 0.8), camCF, C3(20, 20, 24))
				local fl = S:box(V3(0.5, 0.3, 0.1), camCF * CFn(0, 0.55, -0.4), WHITE, "Neon", 0.9)
				fl.CanQuery = false
				table.insert(S.flashes, { p = fl, l = S:light(fl, WHITE, 18, 0) })
			end
		end
		S:lamp(V3(0, 12, 4), C3(255, 235, 210), 36, 1.1)
		S.startCF = S:at(0, 3, ({ 7, 11, 16 })[S.tier] or 7)
	end,
	intro = function(S)
		S:place(S.startCF)
		S:anim("Reveal_Walk", 0.9)
		local dur = S:pick(1.3, 1.8, 2.5)
		S:move(S.heroCF, dur, ES.Linear)
		S:camFn(dur + 0.2, function(a)
			local p = S.root.Position
			return CFrame.lookAt(p + V3(1.8, 1.5, -11 - 1.5 * (1 - a)), p + V3(0, 0.5, 0)), 44 - a * 2
		end)
		S:loop(0.05, function()
			if rng:NextNumber() < 0.5 then
				local f = S.flashes[rng:NextInteger(1, #S.flashes)]
				f.p.Transparency = 0
				f.l.Brightness = 8
				S:sound("UIClick", f.p.Position, 0.3)
				task.delay(0.06, function()
					if f.p.Parent then
						f.p.Transparency = 0.9
						f.l.Brightness = 0
					end
				end)
			end
		end)
		S:wait(dur)
		S:anim("Reveal_Stop")
		for _, f in ipairs(S.flashes) do
			f.p.Transparency = 0
			f.l.Brightness = 10
		end
		S:flash(WHITE, 0.02, 0.03, 0.2, 0.4)
		S:sound("Ding", nil, 0.6)
		S:wait(0.1)
		for _, f in ipairs(S.flashes) do
			f.p.Transparency = 0.9
			f.l.Brightness = 0
		end
		S:wait(0.2)
	end,
}

SCENES.GymPodium = {
	Location = "Company Gym - Annual Awards",
	build = function(S)
		S:floor(V3(60, 1, 60), CFn(0, -0.5, -8), C3(210, 165, 110), "Wood")
		S:box(V3(40, 0.03, 0.3), CFn(0, 0.02, -7), WHITE)
		S:box(V3(0.3, 0.03, 20), CFn(-14, 0.02, 0), WHITE)
		S:box(V3(60, 18, 1), CFn(0, 9, 12), C3(60, 92, 165))
		local ban = S:box(V3(16, 2.6, 0.2), CFn(0, 11, 11.4), C3(255, 210, 50))
		S:sign(ban, "EMPLOYEE OF THE YEAR", { Color = INK, Stroke = false })
		local function pod(x, h, label, color)
			S:box(V3(4, h, 4), CFn(x, h / 2, 5), WHITE)
			S:box(V3(4.05, 0.3, 4.05), CFn(x, h - 0.15, 5), color)
			local f = S:box(V3(1.4, 1.4, 0.05), CFn(x, h / 2, 2.98), color)
			S:sign(f, label, { Color = WHITE })
		end
		pod(0, 3, "1", C3(255, 200, 40))
		pod(-4.2, 2, "2", C3(190, 195, 210))
		pod(4.2, 1.3, "3", C3(205, 125, 60))
		local dark = C3(45, 45, 52)
		for i = 0, 3 do
			local x, z = -13 - (i % 2) * 2.5, 2 + i * 2
			S:box(V3(2.2, 0.25, 0.25), CFn(x, 0.5, z) * ANG(0, 0, 0), C3(160, 160, 170), "Metal", nil, "Cyl")
			S:box(V3(0.35, 1, 1), CFn(x - 1.1, 0.5, z), dark, nil, nil, "Cyl")
			S:box(V3(0.35, 1, 1), CFn(x + 1.1, 0.5, z), dark, nil, nil, "Cyl")
		end
		for i = 0, 2 do
			local x = 11 + i * 1.8
			S:box(Vector3.one * 1.3, CFn(x, 0.65, 4), dark, nil, nil, "Ball")
			S:box(V3(0.9, 0.25, 0.25), CFn(x, 1.5, 4), dark)
		end
		S:box(V3(4, 0.3, 2), CFn(10, 2.8, 8), C3(120, 80, 50), "Wood")
		for i = -1, 1 do
			S:cyl(1, 0.8, V3(10 + i * 1.2, 3.45, 8), C3(255, 200, 40), "Metal")
			S:box(Vector3.one * 0.6, CFn(10 + i * 1.2, 4.1, 8), C3(255, 200, 40), "Metal", nil, "Ball")
		end
		S:lamp(V3(0, 13, 0), C3(255, 245, 225), 40, 1.2)
		S.startCF = S:at(0, 6, 5)
		S.heroCF = S:at(0, 3, -1.2)
	end,
	intro = function(S)
		S:place(S.startCF)
		S:pose("Victory")
		S:cam(S:look(V3(-2.5, 2.4, -8), V3(0, 6, 5)), 50)
		S:shot(S:look(V3(-1.5, 2.2, -6.5), V3(0, 6, 5)), 1.2, 46, ES.Sine, ED.InOut)
		S:sound("Combo", nil, 0.7)
		local colors = { C3(255, 80, 80), C3(255, 220, 60), C3(80, 200, 255), C3(120, 255, 120), C3(255, 120, 220) }
		for _ = 1, S:pick(1, 2, 3) do
			S:confetti(S:wp(-5, 1, 3), 14, colors, 4, 10)
			S:confetti(S:wp(5, 1, 3), 14, colors, 4, 10)
			S:sound("Pickup", nil, 0.6)
			pcall(CartoonFX.sparks, S:wp(0, 7, 5), 10, C3(255, 220, 60))
			S:wait(0.35)
		end
		if S.tier >= 2 then
			S:pose("Flex")
			S:wait(0.35)
		end
		S:anim("Reveal_Stop")
		S:arc(S.heroCF, 0.45, 2.5)
		pcall(CartoonFX.dust, S:hl(0, -3, 0), 7)
		S:sound("Thud", nil, 0.8)
		S:shot(S:look(V3(1.5, 3.4, -9), V3(0, 3.4, -1)), 0.4, 48)
		S:wait(0.2)
	end,
}

SCENES.PaperPortal = {
	Location = "Copy Room - Paper Jam Dimension",
	build = function(S)
		S:floor(V3(60, 1, 60), CFn(0, -0.5, -8), C3(165, 170, 182))
		S:box(V3(60, 16, 1), CFn(0, 8, 13), C3(215, 220, 230))
		S:box(V3(8, 5, 4), CFn(0, 2.5, 10), C3(225, 215, 190))
		S:box(V3(6, 0.3, 2.5), CFn(0, 5.15, 10), C3(60, 60, 66))
		S:box(V3(5, 0.2, 2), CFn(0, 3.2, 7.7) * ANG(0.2, 0, 0), WHITE)
		local st = S:box(V3(2.4, 0.8, 0.05), CFn(2.6, 4.3, 7.98), C3(20, 20, 20))
		S.jamLbl = S:sign(st, "PAPER JAM", { Color = C3(255, 70, 70), Stroke = false })
		for _, p in ipairs({ V3(-10, 0, 4), V3(-12, 0, 7), V3(11, 0, 5), V3(13, 0, 8), V3(-14, 0, 1), V3(9, 0, 9) }) do
			local h = rng:NextNumber(1, 4)
			S:box(V3(1.7, h, 1.2), CFn(p + V3(0, h / 2, 0)) * ANG(0, rng:NextNumber(-0.3, 0.3), 0), WHITE)
		end
		local pc = CFn(0, 4.2, 2.5)
		S.portalCF = pc
		S.portal = S:box(V3(0.1, 0.5, 0.5), pc * ANG(0, PI / 2, 0), C3(150, 70, 255), "Neon", 0.25, "Cyl")
		S.portal2 = S:box(V3(0.12, 0.3, 0.3), pc * CFn(0, 0, -0.03) * ANG(0, PI / 2, 0), C3(255, 140, 240), "Neon", 0.35, "Cyl")
		S.portal.CanQuery = false
		S.portal2.CanQuery = false
		S.sheets = {}
		for i = 1, 16 do
			local p = S:box(V3(1.1, 1.5, 0.05), pc, WHITE)
			p.CanQuery = false
			S.sheets[i] = p
		end
		S.portalR = 0
		S:lamp(V3(0, 4.2, 1), C3(170, 100, 255), 20, 2)
		S:lamp(V3(0, 12, -6), C3(255, 245, 230), 36, 1)
		S.startCF = S:at(0, 3, 3.6)
	end,
	intro = function(S)
		S:place(S.startCF)
		S:alpha(0)
		S:pose("Boss")
		local pcW = S.O * S.portalCF
		local t0 = os.clock()
		table.insert(S.conns, RunService.RenderStepped:Connect(function()
			if S.sheetsFree then
				return
			end
			local t = os.clock() - t0
			for i, p in ipairs(S.sheets) do
				local a = t * 2.2 + i * 2 * PI / #S.sheets
				p.CFrame = pcW * ANG(0, 0, a) * CFn(0, S.portalR, 0) * ANG(0.4 * math.sin(t * 5 + i), 0.5, 0)
			end
		end))
		S:cam(S:look(V3(-3.5, 4.4, -13), V3(0, 4.2, 2.5)), 50)
		S:shot(S:look(V3(-2, 4, -10), V3(0, 4, 2)), S:pick(1.6, 2.2, 2.9), 44, ES.Sine, ED.InOut)
		S:sound("Electric", nil, 0.7)
		S:sound("Whoosh", nil, 0.8)
		S:tween(S.portal, 0.5, { Size = V3(0.1, 7.5, 7.5) }, ES.Back, ED.Out)
		S:tween(S.portal2, 0.6, { Size = V3(0.12, 5.2, 5.2) }, ES.Back, ED.Out)
		local rv = Instance.new("NumberValue")
		rv.Parent = S.set
		rv.Changed:Connect(function(v)
			S.portalR = v
		end)
		S:tween(rv, 0.6, { Value = 4.6 }, ES.Back, ED.Out)
		S:wait(S:pick(0.5, 0.7, 0.9))
		S:alpha(1)
		local walk = S:pick(0.6, 0.8, 1.0)
		S:anim("Reveal_Walk")
		S:move(S.heroCF, walk, ES.Linear)
		pcall(CartoonFX.sparks, pcW.Position, 20, C3(200, 120, 255))
		S:wait(walk)
		S:anim("Reveal_Stop")
		S.sheetsFree = true
		for _, p in ipairs(S.sheets) do
			local dir = p.Position - pcW.Position
			dir = dir.Magnitude > 0.1 and dir.Unit or V3(0, 1, 0)
			S:tween(p, 0.8, { CFrame = p.CFrame + dir * 9 + V3(0, rng:NextNumber(-2, 3), -3), Transparency = 1 }, ES.Quad, ED.Out)
		end
		S:tween(S.portal, 0.3, { Size = V3(0.1, 0.1, 0.1) }, ES.Back, ED.In)
		S:tween(S.portal2, 0.3, { Size = V3(0.12, 0.1, 0.1) }, ES.Back, ED.In)
		S:word("PAPER JAM!", pcW.Position + V3(0, 3, 0), 1.1, "Heavy")
		S:sound("Boing", nil, 0.6)
		S:wait(0.3)
	end,
	finish = function(S)
		S.sheetsFree = true
		for _, p in ipairs(S.sheets) do
			p.Transparency = 1
		end
		S.portal.Transparency = 1
		S.portal2.Transparency = 1
	end,
}

SCENES.Cubicle = {
	Location = "Open Space - Cubicle 42",
	build = function(S)
		local fab = C3(150, 158, 175)
		S:floor(V3(60, 1, 60), CFn(0, -0.5, -8), C3(95, 105, 130), "Fabric")
		local function cubicle(x, z)
			S:box(V3(9, 5, 0.4), CFn(x, 2.5, z + 4.2), fab, "Fabric")
			S:box(V3(0.4, 5, 4.2), CFn(x - 4.3, 2.5, z + 2.1), fab, "Fabric")
			S:box(V3(0.4, 5, 4.2), CFn(x + 4.3, 2.5, z + 2.1), fab, "Fabric")
			S:box(V3(9.2, 0.25, 0.5), CFn(x, 5.1, z + 4.2), C3(90, 95, 110))
			S:box(V3(8, 0.3, 2.2), CFn(x, 2.6, z + 2.9), C3(225, 218, 205))
			S:box(V3(0.3, 2.45, 2), CFn(x - 3.7, 1.25, z + 2.9), C3(120, 120, 130))
			S:box(V3(0.3, 2.45, 2), CFn(x + 3.7, 1.25, z + 2.9), C3(120, 120, 130))
			S:box(V3(2.4, 1.5, 0.2), CFn(x + 1.5, 3.75, z + 3.5), C3(30, 30, 35))
			S:box(V3(2.2, 1.3, 0.05), CFn(x + 1.5, 3.75, z + 3.38), C3(90, 170, 255), "Neon")
			S:cyl(0.6, 0.55, V3(x - 2, 3.05, z + 2.6), C3(220, 60, 60))
			for _ = 1, 5 do
				S:box(V3(0.5, 0.5, 0.05), CFn(x + rng:NextNumber(-3.5, 3.5), rng:NextNumber(3.2, 4.6), z + 3.98), ({ C3(255, 235, 80), C3(255, 150, 200), C3(140, 230, 140) })[rng:NextInteger(1, 3)])
			end
		end
		cubicle(0, 0)
		cubicle(-11, 2)
		cubicle(11, 2)
		S:box(V3(60, 16, 1), CFn(0, 8, 14), C3(225, 228, 235))
		for i = -3, 3 do
			S:box(V3(6, 6, 0.2), CFn(i * 8, 8, 13.4), C3(160, 210, 245), "Glass", 0.3)
		end
		S.lights = {}
		for _, z in ipairs({ -5, 1, 7 }) do
			local p = S:box(V3(5, 0.2, 1.4), CFn(0, 10, z), C3(120, 120, 125))
			table.insert(S.lights, { p = p, l = S:light(p, C3(255, 252, 235), 22, 0) })
		end
		S.heroCF = S:at(0, 3, -0.6)
	end,
	intro = function(S)
		S:place(S.heroCF)
		S:pose("Boss")
		S.cc.Brightness = -0.35
		S:cam(S:look(V3(0.8, 4.4, -13), V3(0, 3.6, 0)), 48)
		S:shot(S:look(V3(0.5, 4, -9), V3(0, 3.6, 0)), S:pick(1.5, 2.0, 2.6), 44, ES.Sine, ED.InOut)
		S:wait(0.3)
		local function set(l, on)
			l.p.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
			l.p.Color = on and C3(250, 250, 240) or C3(120, 120, 125)
			l.l.Brightness = on and 2 or 0
		end
		for i, l in ipairs(S.lights) do
			for _ = 1, S:pick(1, 2, 3) do
				set(l, true)
				S:wait(0.05)
				set(l, false)
				S:wait(0.05)
			end
			set(l, true)
			S:sound("Electric", nil, 0.4)
			S:tween(S.cc, 0.25, { Brightness = -0.35 + i * 0.35 / #S.lights })
			S:wait(0.15)
		end
		S:sound("Ding", nil, 0.7)
		S:wait(0.2)
	end,
	finish = function(S)
		S.cc.Brightness = 0
		for _, l in ipairs(S.lights) do
			l.p.Material = Enum.Material.Neon
			l.p.Color = C3(250, 250, 240)
			l.l.Brightness = 2
		end
	end,
}

SkinRevealController.Scenes = {}
for name in pairs(SCENES) do
	table.insert(SkinRevealController.Scenes, name)
end
table.sort(SkinRevealController.Scenes)

------------------------------------------------------------------------
-- Temps forts bonus (Beat d'une entrée, joués pendant la pose héroïque)
------------------------------------------------------------------------
local BEATS = {}
BEATS.Thunder = function(S)
	local target = S.heroCF.Position + V3(0, 2, 0)
	local p0 = S:hl(rng:NextNumber(-3, 3), 40, 3)
	for i = 1, 6 do
		local p1 = p0:Lerp(target, 1 / (7 - i)) + V3(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
		pcall(CartoonFX.beam, p0, p1, 0.8, C3(200, 230, 255), 0.35)
		p0 = p1
	end
	S:flash(C3(220, 235, 255), 0.02, 0.05, 0.25)
	S:sound("Electric")
	S:sound("Rumble")
	CartoonFX.shake(0.8)
end
BEATS.Fireworks = function(S)
	for i = 1, 5 do
		S:delay(i * 0.14, function()
			local pos = S:hl(rng:NextNumber(-10, 10), rng:NextNumber(9, 15), rng:NextNumber(4, 10))
			local col = Color3.fromHSV(rng:NextNumber(), 0.7, 1)
			pcall(CartoonFX.sparks, pos, 30, col)
			pcall(CartoonFX.light, pos, col, 30, 4, 0.4)
			S:sound("Explosion", pos, 0.4)
			S:confetti(pos, 10, { col, WHITE }, 8, 3)
		end)
	end
end
BEATS.Glitch = function(S)
	for i = 1, 6 do
		S:delay(i * 0.06, function()
			S:glitchBars()
		end)
	end
	S:cubes(S.heroCF.Position, 14, { C3(0, 255, 200), C3(255, 0, 200) }, 2.2)
	S:sound("Electric")
end
BEATS.Rain = function(S)
	S:rain(S.entry.Rain or { Colors = { S.rc, S.col }, Size = V3(0.8, 0.8, 0.8) }, 1.4)
end
BEATS.Quake = function(S)
	pcall(CartoonFX.quake, S.heroCF.Position - V3(0, 3, 0), 16, S.rc, 1.4)
	CartoonFX.shake(1.2)
end
BEATS.Confetti = function(S)
	S:confetti(S:hl(-6, 0, 2), 20, { C3(255, 80, 80), C3(255, 220, 60), C3(80, 200, 255), C3(120, 255, 120) }, 4, 11)
	S:confetti(S:hl(6, 0, 2), 20, { C3(255, 80, 80), C3(255, 220, 60), C3(80, 200, 255), C3(120, 255, 120) }, 4, 11)
	S:sound("Pickup")
end
SkinRevealController.Beats = {}
for name in pairs(BEATS) do
	table.insert(SkinRevealController.Beats, name)
end

------------------------------------------------------------------------
-- Démonstration de pouvoir
------------------------------------------------------------------------
local HEAVY = { Slam = true, AoE = true, SkyDrop = true, ElbowDrop = true, BubblePrison = true, CartRush = true, Zone = true, Barrier = true }

-- instant du coup dans une anim ProcAnim : image clé où les membres bougent le plus vite
local function strikeTime(frames)
	if type(frames) ~= "table" or #frames < 2 then
		return 0.2, 0.5
	end
	local function mag(k, j)
		local v = k[j]
		if type(v) ~= "table" then
			return 0
		end
		return math.abs(v.p or 0) + math.abs(v.y or 0) * 0.5 + math.abs(v.r or 0) + math.abs(v.tw or 0) + math.abs(v.ln or 0)
	end
	local best, bestT = -1, frames[2].t
	for i = 2, math.max(2, #frames - 1) do
		local a, b = frames[i - 1], frames[i]
		local dsum = 0
		for _, j in ipairs({ "RS", "LS", "RH", "LH", "RJ" }) do
			dsum += math.abs(mag(b, j) - mag(a, j))
		end
		dsum = dsum / math.max(b.t - a.t, 0.04)
		if dsum > best then
			best, bestT = dsum, b.t
		end
	end
	return bestT, frames[#frames].t
end

-- les Kinds spécifiques des persos de Content (RecBell, MKViral...) sont classés par mots-clés
local KNOWN_KINDS = { Projectile = true, Lunge = true, CartRush = true, Grab = true, Counter = true, Cone = true, Slam = true, ElbowDrop = true, SkyDrop = true, BubblePrison = true, AoE = true, Zone = true, Barrier = true, Buff = true, Guard = true, Melee = true }
local KIND_WORDS = {
	{ "SkyDrop", { "drop", "rain", "billboard", "toolbox", "crate", "firework", "finale", "star", "deadline", "calendar", "crash" } },
	{ "Projectile", { "throw", "calc", "ball", "bean", "parcel", "book", "shirt", "cannon", "confetti", "togo", "to-go", "barrage", "meat", "ddos", "slip", "letter" } },
	{ "Lunge", { "dash", "rush", "dolly", "train", "express", "teleport", "steam", "layoff", "cut" } },
	{ "Slam", { "shockwave", "pushup", "push-up", "smash", "leap", "bounce", "gavel", "slam" } },
	{ "Grab", { "lasso", "grab", "cord", "line", "stamp", "audit", "takeover", "spot", "cross", "hang", "buyout" } },
	{ "Cone", { "cone", "spray", "memo", "megaphone", "music", "flash", "wash", "latte", "policy" } },
	{ "AoE", { "viral", "synergy", "whirl", "spin", "overload", "firewall", "circuit", "screen", "virus", "shake", "team", "bell", "badge", "transfer", "lockdown", "bubble", "fuse", "tape", "wrap", "review", "objection", "contract", "lawsuit", "dance", "bankrupt", "whistle", "sign", "fired" } },
}
local function classify(atk, entry)
	if type(entry.ShowcaseKind) == "string" then
		return entry.ShowcaseKind
	end
	local kind = atk.Kind or "Melee"
	if KNOWN_KINDS[kind] then
		return kind
	end
	local key = string.lower(kind .. " " .. tostring(atk.Name or "") .. " " .. tostring(atk.Anim or ""))
	for _, row in ipairs(KIND_WORDS) do
		for _, w in ipairs(row[2]) do
			if string.find(key, w, 1, true) then
				return row[1]
			end
		end
	end
	return "Melee"
end

local function kindFX(S, atk, target)
	local kind = classify(atk, S.entry)
	local rootPos = S.root.Position
	local tpos = target.Position
	local flat = (tpos - rootPos) * V3(1, 0, 1)
	local dir = flat.Magnitude > 0.1 and flat.Unit or V3(-1, 0, 0)
	local col = S.col
	local pCol = typeof(atk.Color) == "Color3" and atk.Color or col
	if kind == "Projectile" then
		local count = math.clamp(atk.Count or 1, 1, 5)
		local size = typeof(atk.Size) == "Vector3" and atk.Size or V3(1.2, 1.2, 1.2)
		size = V3(math.clamp(size.X, 0.4, 3), math.clamp(size.Y, 0.2, 3), math.clamp(size.Z, 0.4, 3))
		local from = S:hand()
		for i = 1, count do
			local off = (i - (count + 1) / 2) * 1.4
			local to = tpos + V3(0, 0.4, 0) + dir:Cross(V3(0, 1, 0)) * off
			local p = S:part({ Size = size, CFrame = CFrame.lookAt(from, to), Color = pCol, CanQuery = false })
			if atk.Shape == "Ball" then
				p.Shape = Enum.PartType.Ball
			end
			pcall(CartoonFX.trailOn, p, col, 0.4, 0, 0.6)
			S:tween(p, 0.22, { CFrame = CFrame.lookAt(to, to + dir) * ANG(0, 0, rng:NextNumber(3, 6)) }, ES.Linear)
			Debris:AddItem(p, 0.3)
		end
		S:sound("Throw", from, 0.8)
		S:wait(0.22)
		S:impact(target, dir, atk, 1.1)
	elseif kind == "Lunge" or kind == "CartRush" or kind == "Grab" or kind == "Counter" then
		local stop = tpos - dir * 2.6
		pcall(CartoonFX.airRing, rootPos, dir, 6, col)
		pcall(CartoonFX.trailOn, S.rig:FindFirstChild("Torso"), col, 0.4, 0, 2)
		S:sound("Dash", rootPos, 0.9)
		S:move(CFrame.lookAt(V3(stop.X, rootPos.Y, stop.Z), V3(tpos.X, rootPos.Y, tpos.Z)), 0.16, ES.Quad, ED.Out)
		S:wait(0.16)
		S:impact(target, dir, atk, 1.25)
	elseif kind == "Cone" then
		local from = S:hand()
		for k = 1, 4 do
			for _ = 1, 3 do
				pcall(CartoonFX.beam, from, tpos + V3(rng:NextNumber(-1.5, 1.5), rng:NextNumber(-1, 1.5), rng:NextNumber(-1.5, 1.5)), 0.45, pCol, 0.25)
			end
			pcall(CartoonFX.sparks, tpos, 8, pCol)
			if k < 4 then
				S:wait(0.06)
			end
		end
		S:impact(target, dir, atk, 1)
	elseif kind == "Slam" or kind == "ElbowDrop" then
		local land = tpos - dir * 2.2
		S:arc(CFrame.lookAt(V3(land.X, rootPos.Y, land.Z), V3(tpos.X, rootPos.Y, tpos.Z)), 0.32, 4)
		pcall(CartoonFX.quake, V3(land.X, S.targetFloorY or (rootPos.Y - 3), land.Z), 10, col, 1.1)
		S:sound("GroundSlam", land, 1)
		S:impact(target, dir, atk, 1.2)
	elseif kind == "SkyDrop" or kind == "BubblePrison" then
		local slab = S:part({ Size = V3(5, 1.2, 5), CFrame = CFn(tpos + V3(0, 22, 0)), Color = pCol, CanQuery = false })
		local txt = type(atk.Words) == "table" and atk.Words[#atk.Words] or string.upper(atk.Name or "")
		S:sign(slab, txt, { Face = Enum.NormalId.Front, Color = WHITE })
		S:tween(slab, 0.28, { CFrame = CFn(tpos + V3(0, -1.5, 0)) }, ES.Quad, ED.In)
		S:wait(0.28)
		pcall(CartoonFX.quake, V3(tpos.X, S.targetFloorY or (tpos.Y - 3), tpos.Z), 11, col, 1.2)
		S:impact(target, dir, atk, 1.2)
		S:delay(0.5, function()
			S:tween(slab, 0.3, { Transparency = 1 })
		end)
	elseif kind == "AoE" or kind == "Zone" or kind == "Barrier" or kind == "Buff" or kind == "Guard" then
		local feet = V3(rootPos.X, rootPos.Y - 3, rootPos.Z)
		pcall(CartoonFX.quake, feet, 12, col, 1.1)
		pcall(CartoonFX.pillar, feet, 3, 14, col, 0.45)
		pcall(CartoonFX.swirl, feet, 4, 7, { col, WHITE }, 14, 0.6)
		S:sound("GroundSlam", feet, 0.9)
		S:impact(target, dir, atk, 1.1)
	else
		pcall(CartoonFX.slashArc, S.root.CFrame, 5, col, -70, 70, 0.12, 0, 0.5)
		S:sound("Whoosh", rootPos, 0.8)
		S:wait(0.06)
		S:impact(target, dir, atk, 1.2)
	end
end

local function showcase(S)
	local atk = S.data.Attacks[S.showcaseId or ""]
	if type(atk) ~= "table" then
		atk = nil
	end
	local h = S.heroCF
	local slow = S.tier >= 3
	-- pièces « Transform » du skin + aura renforcée (SkinBuilder réagit à l'attribut)
	S.rig:SetAttribute("Transformed", true)
	S:setLower(atk and ("SIGNATURE MOVE: " .. string.upper(atk.Name or S.showcaseId)) or "POWER CHECK")
	S:flash(WHITE, 0.03, 0.02, 0.2, 0.35)
	local tpos = S:hl(-8, 0, -2.5)
	S:buildTarget(tpos)
	tpos = S.target.Position
	local face = CFrame.lookAt(h.Position, V3(tpos.X, h.Position.Y, tpos.Z))
	S:move(face, 0.15)
	S:anim("Reveal_Stop")
	S:cam(CFrame.lookAt(S:hl(-2.6, 2.4, -15.5), S:hl(-4, 0.5, -1.2)), 52)
	S:shot(CFrame.lookAt(S:hl(-3.4, 1.9, -12.8), S:hl(-4.2, 0.5, -1.2)), 2.4, 48, ES.Sine, ED.Out)
	S:wait(0.2)
	if not atk then
		-- pas d'attaque connue : montée en puissance
		S:pose("Power")
		local feet = S.root.Position - V3(0, 3, 0)
		pcall(CartoonFX.implode, S.root.Position, 7, { S.col, WHITE }, 14, 0.35)
		S:wait(0.35)
		pcall(CartoonFX.pillar, feet, 3, 14, S.col, 0.5)
		pcall(CartoonFX.quake, feet, 12, S.col, 1)
		S:impact(S.target, face.LookVector, nil, 1)
		S:wait(0.6)
		return
	end
	S:attachProp(atk.Prop)
	local animName = (atk.Anim and ProcAnim.Anims[atk.Anim]) and atk.Anim or "Punch4"
	local strikeT, len = strikeTime(ProcAnim.Anims[animName])
	strikeT = math.clamp(strikeT, 0.08, 1.1)
	local speed = slow and 0.5 or 1
	if HEAVY[classify(atk, S.entry)] then
		pcall(CartoonFX.bigTelegraph, V3(tpos.X, S.targetFloorY or (tpos.Y - 3), tpos.Z), 5, strikeT / speed, C3(255, 70, 60))
	end
	S:word(type(atk.Words) == "table" and atk.Words[1] or string.upper(atk.Name or ""), S.root.Position + V3(0, 3.4, 0), 0.9, "Heavy")
	S:sound(atk.Sound or "Whoosh", nil, 0.8)
	S:anim(animName, speed)
	if slow then
		-- ralenti : la caméra se rapproche du perso pendant l'élan
		S:shot(CFrame.lookAt(S:hl(-1.4, 1.3, -7), S:hl(-2.4, 0.9, 0)), strikeT / speed, 40, ES.Sine, ED.InOut)
		pcall(CartoonFX.speedLines, 0.5, S.rc)
	end
	S:wait(strikeT / speed)
	if slow then
		S:cam(CFrame.lookAt(S:hl(-3.2, 2.2, -13.5), S:hl(-5, 0.5, -1.5)), 50)
		S:shot(CFrame.lookAt(S:hl(-3.6, 2, -12.4), S:hl(-5.2, 0.5, -1.5)), 1.2, 47, ES.Quad, ED.Out)
		S:punch(10)
		S:flash(WHITE, 0.02, 0.02, 0.2, 0.4)
	end
	kindFX(S, atk, S.target)
	S:wait(math.clamp((len - strikeT) / speed * 0.6, 0.45, 1.0))
	S:detachProp()
	S:anim("Reveal_Stop")
	S:move(h, 0.2)
	S:wait(0.15)
end

------------------------------------------------------------------------
-- Carte titre
------------------------------------------------------------------------
local function showCard(S)
	S.phase = "card"
	S.cardAt = os.clock()
	local root = S.cardRoot
	local rc = S.rc
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	S.hintLbl.Text = touchOnly and "TAP TO CONTINUE" or "CLICK TO CONTINUE"
	-- bandeau de rareté
	local banner = UITheme.new("Frame", {
		Name = "Banner", AnchorPoint = V2(0, 0.5), Position = UDim2.new(-0.6, 0, 0.555, 0), Size = UDim2.new(0.4, 0, 0.068, 0),
		BackgroundColor3 = rc, BorderSizePixel = 0, Rotation = -3, ZIndex = 22, Parent = root,
	})
	UITheme.stroke(banner, 4, INK, true)
	UITheme.bevel(banner, 0.7, 0.75)
	local bl = UITheme.label({ Text = S.label .. " SKIN", TextColor3 = WHITE, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.92, 0.62), ZIndex = 23, Stroke = 3 })
	bl.Parent = banner
	S:tween(banner, 0.35, { Position = UDim2.new(0.04, 0, 0.555, 0) }, ES.Back, ED.Out)
	-- nom du skin
	local name = UITheme.label({
		Name = "SkinName", Text = string.upper(S.def.Name or S.id), TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0.045, 0, 0.6, 0), Size = UDim2.new(0.56, 0, 0.1, 0), ZIndex = 22, Stroke = 5,
	})
	name.Parent = root
	local ns = Instance.new("UIScale")
	ns.Scale = 0
	ns.Parent = name
	-- perso + légende
	local charName = string.upper(S.charDef.DisplayName or S.charId or "")
	local cl = UITheme.label({
		Name = "Character", Body = true, Text = charName, TextColor3 = UITheme.lighten(rc, 0.35), TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(0.047, 0, 0.705, 0), Size = UDim2.new(0.42, 0, 0.045, 0), ZIndex = 22, Stroke = 2, TextTransparency = 1,
	})
	cl.Parent = root
	local cap = UITheme.label({
		Name = "Caption", Body = true, Text = S.caption ~= "" and ('"' .. S.caption .. '"') or "", TextColor3 = UITheme.Colors.Paper,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true,
		Position = UDim2.new(0.047, 0, 0.756, 0), Size = UDim2.new(0.5, 0, 0.08, 0), ZIndex = 22, Stroke = 2, TextTransparency = 1, MaxText = 28,
	})
	cap.Parent = root
	-- badge NEW! / DUPLICATE
	local replay = S.opts.replay == true -- rejouée depuis le bouton SHOWCASE du menu
	local dup = not replay and (S.opts.isNew == false or (type(S.opts.refund) == "number" and S.opts.refund > 0))
	local refund = S.opts.refund or DEFAULT_REFUND[S.rarity] or 0
	local badge = UITheme.new("Frame", {
		Name = "Badge", AnchorPoint = V2(0, 0.5), Position = UDim2.new(0.047, 0, 0.485, 0), Size = UDim2.new((dup or replay) and 0.25 or 0.11, 0, 0.055, 0),
		BackgroundColor3 = dup and UITheme.Colors.Cash or UITheme.Colors.Yellow, BorderSizePixel = 0, Rotation = -5, ZIndex = 24, Parent = root,
	})
	UITheme.corner(badge, 6)
	UITheme.stroke(badge, 3, INK, true)
	local bdl = UITheme.label({ Text = replay and "SHOWCASE" or (dup and ("DUPLICATE +$" .. tostring(refund)) or "NEW!"), TextColor3 = INK, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.88, 0.58), ZIndex = 25, Stroke = false })
	bdl.Parent = badge
	local bs = Instance.new("UIScale")
	bs.Scale = 0
	bs.Parent = badge
	S:sound("Whoosh", nil, 0.6)
	task.delay(0.12, function()
		if not name.Parent then
			return
		end
		S:tween(ns, 0.16, { Scale = 1.12 }, ES.Back, ED.Out)
		task.delay(0.16, function()
			if ns.Parent then
				S:tween(ns, 0.1, { Scale = 1 })
			end
		end)
	end)
	task.delay(0.25, function()
		if cl.Parent then
			S:tween(cl, 0.25, { TextTransparency = 0 })
			S:tween(cap, 0.35, { TextTransparency = 0 })
		end
	end)
	task.delay(0.42, function()
		if not badge.Parent then
			return
		end
		S:tween(bs, 0.16, { Scale = 1.15 }, ES.Back, ED.Out)
		task.delay(0.16, function()
			if bs.Parent then
				S:tween(bs, 0.1, { Scale = 1 })
				UITheme.wobble(badge, 4, -5)
			end
		end)
		S:sound(dup and "Pickup" or "LevelUp", nil, 0.7)
	end)
	-- caméra : lente poussée
	S:shot(S.camCF * CFn(0, 0, -0.9), (CARD_TIME[S.tier] or 2) + 0.6, S.camFov - 2, ES.Sine, ED.Out)
end

------------------------------------------------------------------------
-- Pose héroïque
------------------------------------------------------------------------
local function hero(S, quick)
	S.phase = "hero"
	S.token += 1
	local h = S.heroCF
	if quick then
		S:flash(WHITE, 0.02, 0.04, 0.35)
		if S.scene.finish then
			runSafe(S.scene.finish, S)
		end
		if S.cc then
			S.cc.Brightness = 0
		end
	end
	S:detachProp()
	if S.target and S.target.Parent then
		S.target.Parent:Destroy()
		S.target = nil
	end
	S.rig:SetAttribute("Transformed", false)
	S:alpha(1)
	S:place(h)
	S:setLower("")
	local tier = S.tier
	S:cam(CFrame.lookAt(S:hl(0, -1.1, -22), S:hl(5, 0, 0)), 44)
	S:shot(CFrame.lookAt(S:hl(-0.8, -0.6, -17.5), S:hl(4.6, -0.1, 0)), tier >= 3 and 1.4 or 0.7, 37, ES.Quart, ED.Out)
	S:pose(S.entry.Pose or (S.rarity == "Base" and "Boss") or ({ "Point", "Power", "Hero" })[tier])
	local feet = h.Position - V3(0, 2.9, 0)
	pcall(CartoonFX.shockwave, feet, 9 + tier * 3, S.rc)
	pcall(CartoonFX.sparks, h.Position, 12 + tier * 8, S.rc)
	S:punch(5 + tier * 2)
	if tier == 1 then
		S:sound("Ding")
		pcall(CartoonFX.puff, feet + V3(0, 0.5, 0), 3)
	elseif tier == 2 then
		S:sound("PowerUp")
		S:sound("BigImpact", nil, 0.5)
		pcall(CartoonFX.speedLines, 0.45, S.rc)
		pcall(CartoonFX.impactFrame, 0.6)
		S:word(S.entry.Word or "EPIC!", h.Position + V3(0, 4, 0), 1.2, "Heavy")
		S:confetti(h.Position + V3(0, 1, 0), 18, { S.rc, S.col, WHITE }, 7, 6)
	else
		S:sound("PowerUp")
		S:sound("Explosion", nil, 0.7)
		S:rays(typeof(S.entry.Rays) == "Color3" and S.entry.Rays or S.rc)
		S:flash(C3(255, 236, 160), 0.03, 0.06, 0.45, 0.3)
		pcall(CartoonFX.shards, h.Position, 16, { S.rc, WHITE, C3(255, 240, 170) }, 1.3)
		pcall(CartoonFX.light, h.Position + V3(0, 2, 0), S.rc, 30, 6, 0.8)
		S:delay(0.1, function()
			pcall(CartoonFX.shockwave, feet + V3(0, 0.1, 0), 22, WHITE)
		end)
		S:confetti(h.Position + V3(0, 1, 0), 34, { S.rc, C3(255, 240, 170), WHITE, S.col }, 9, 8)
		CartoonFX.shake(0.9)
		S:word(S.entry.Word or "LEGENDARY!", h.Position + V3(0, 4.2, 0), 1.4, "KO")
	end
	local beat = S.entry.Beat
	if type(beat) == "string" and BEATS[beat] then
		runSafe(BEATS[beat], S)
	end
	S:wait(tier >= 3 and 0.55 or 0.3)
	showCard(S)
end

------------------------------------------------------------------------
-- MOTEUR DE CHORÉGRAPHIE (v2) — voir l'en-tête et scratchpad/REVEAL_API.md
------------------------------------------------------------------------
local Engine = {}

-- conversions (le repère de scène S.O est une simple translation)
local function W(S, v) -- -> Vector3 monde
	local t = typeof(v)
	if t == "Vector3" then
		return S.O * v
	elseif t == "CFrame" then
		return (S.O * v).Position
	elseif t == "Instance" then
		if v == S.rig then
			return S.root.Position
		elseif v:IsA("Model") then
			return v:GetPivot().Position
		elseif v:IsA("BasePart") then
			return v.Position
		elseif v:IsA("Attachment") then
			return v.WorldPosition
		end
	end
	return S.heroCF.Position
end
local function WCF(S, v) -- -> CFrame monde
	local t = typeof(v)
	if t == "CFrame" then
		return S.O * v
	elseif t == "Vector3" then
		return S.O * CFn(v)
	elseif t == "Instance" then
		if v == S.rig then
			return S.root.CFrame
		elseif v:IsA("Model") then
			return v:GetPivot()
		elseif v:IsA("BasePart") then
			return v.CFrame
		end
	end
	return S.heroCF
end
local function getCF(S, obj)
	if obj == S.rig or obj == "rig" then
		return S.root.CFrame
	elseif typeof(obj) == "Instance" then
		if obj:IsA("Model") then
			return obj:GetPivot()
		elseif obj:IsA("BasePart") then
			return obj.CFrame
		end
	end
	return nil
end
local function setCF(S, obj, cf)
	if obj == S.rig or obj == "rig" then
		S.root.CFrame = cf
	elseif typeof(obj) == "Instance" and obj.Parent then
		if obj:IsA("Model") then
			obj:PivotTo(cf)
		elseif obj:IsA("BasePart") then
			obj.CFrame = cf
		end
	end
end
local function ease(a, style, dir)
	return TweenService:GetValue(math.clamp(a, 0, 1), style or ES.Quad, dir or ED.InOut)
end
local function lerpAny(a, b, e)
	local t = typeof(a)
	if t == "number" then
		return a + (b - a) * e
	elseif t == "boolean" or t == "string" or t == "EnumItem" then
		return e >= 1 and b or a
	end
	return a:Lerp(b, e)
end

-- temps du récit : ralenti (timeScale) et arrêt sur image (frozenUntil)
function Session:sdt(dt)
	if debugPause or os.clock() < (self.frozenUntil or 0) then
		return 0
	end
	return dt * (self.timeScale or 1)
end

-- animateurs (avancés à chaque image dans le temps du récit) ; key = remplace l'animateur précédent de même clé
function Session:mover(dur, fn, key, onDone)
	local m = { t = 0, dur = math.max(dur or 0, 0.001), fn = fn, key = key, onDone = onDone }
	if key then
		for i = #self.movers, 1, -1 do
			if self.movers[i].key == key then
				table.remove(self.movers, i)
			end
		end
	end
	table.insert(self.movers, m)
	return m.dur
end
function Session:stepMovers(dt)
	local sdt = self:sdt(dt)
	local list = self.movers
	local i = 1
	while i <= #list do
		local m = list[i]
		m.t += sdt
		local a = math.clamp(m.t / m.dur, 0, 1)
		local ok, err = pcall(m.fn, a, m.t)
		if not ok then
			warn("[SkinReveal] animateur :", err)
			a = 1
		end
		if a >= 1 or m.dead then
			table.remove(list, i)
			if m.onDone and not m.dead then
				task.spawn(runSafe, m.onDone)
			end
		else
			i += 1
		end
	end
	local tr = self.animTrack
	if tr then
		tr.t += sdt * tr.speed
		if tr.t >= tr.len then
			self.animTrack = nil
		end
	end
end

-- découpe une piste ProcAnim à l'instant t (pour changer la vitesse d'une anim en cours : ralenti)
local LIMB_KEYS = { RS = { "p", "y", "r" }, LS = { "p", "y", "r" }, RH = { "p", "y", "r" }, LH = { "p", "y", "r" }, RJ = { "tw", "ln", "sd" } }
local function sliceFrames(frames, t)
	for i = 1, #frames - 1 do
		local a, b = frames[i], frames[i + 1]
		if t <= b.t then
			local x = math.clamp((t - a.t) / math.max(b.t - a.t, 1e-3), 0, 1)
			local al = 1 - (1 - x) * (1 - x)
			local f0 = { t = 0 }
			for j, keys in pairs(LIMB_KEYS) do
				if a[j] or b[j] then
					local o = {}
					for _, k in ipairs(keys) do
						local va, vb = (a[j] and a[j][k]) or 0, (b[j] and b[j][k]) or 0
						o[k] = va + (vb - va) * al
					end
					f0[j] = o
				end
			end
			local out = { f0 }
			for k = i + 1, #frames do
				local f = table.clone(frames[k])
				f.t = frames[k].t - t
				table.insert(out, f)
			end
			return out
		end
	end
	return nil
end
function Session:playTrack(frames, speed)
	speed = speed or 1
	if type(frames) ~= "table" or #frames < 2 then
		return 0
	end
	self.animTrack = { frames = frames, speed = speed, t = 0, len = frames[#frames].t }
	ProcAnim.playFrames(self.rig, frames, speed * math.max(self.timeScale or 1, 0.01))
	local len = frames[#frames].t
	if len > 20 then -- pose tenue : durée de mise en place
		return 0.27 / speed
	end
	return len / speed
end
function Session:setTimeScale(scale)
	scale = math.clamp(scale or 1, 0.02, 4)
	self.timeScale = scale
	local tr = self.animTrack
	if tr and self.rig then
		local sl = sliceFrames(tr.frames, tr.t)
		if sl and #sl >= 2 then
			self.animTrack = { frames = sl, speed = tr.speed, t = 0, len = sl[#sl].t }
			ProcAnim.playFrames(self.rig, sl, tr.speed * scale)
		end
	end
end

------------------------------------------------------------------------
-- Bibliothèque d'accessoires (R.prop) : chaque entrée construit un Model (pivot = sol sous l'objet, face vers -Z)
------------------------------------------------------------------------
local PROPS = {}
local GOLD_C, RED_C, DARK_C, STEEL_C = C3(255, 196, 40), C3(220, 45, 50), C3(32, 32, 38), C3(195, 200, 212)
local VCYL = ANG(0, 0, PI / 2) -- cylindre (axe X) -> vertical
local ZCYL = ANG(0, PI / 2, 0) -- cylindre -> axe Z (face caméra)

-- specs = { { Name?, Size, CFrame (relatif), Color, Material?, Shape?, Transparency?, Text?, TextColor?, Light? } }
function Session:buildModel(specs, cf, name)
	local m = Instance.new("Model")
	m.Name = name or "Prop"
	local first
	local label
	for _, sp in ipairs(specs) do
		local shape = sp.Shape or sp[6]
		local p = self:part({
			ClassName = (shape == "Wedge" and "WedgePart") or (shape == "CornerWedge" and "CornerWedgePart") or "Part",
			Name = sp.Name or "Part",
			Size = sp.Size,
			CFrame = cf * (sp.CFrame or CFn()),
			Color = sp.Color or WHITE,
			Material = (type(sp.Material) == "string" and MATS[sp.Material]) or (typeof(sp.Material) == "EnumItem" and sp.Material) or Enum.Material.SmoothPlastic,
			Transparency = sp.Transparency or 0,
			CanQuery = false,
		}, m)
		if shape == "Ball" or shape == "Cyl" then
			p.Shape = shape == "Ball" and Enum.PartType.Ball or Enum.PartType.Cylinder
			p.Size = sp.Size
			p.CFrame = cf * (sp.CFrame or CFn())
		end
		if p.Material == Enum.Material.Neon then
			p.CastShadow = false
		end
		if type(sp.Text) == "string" then
			label = self:sign(p, sp.Text, { Color = sp.TextColor, Face = sp.Face, Bg = sp.TextBg, Stroke = sp.Stroke })
		end
		if typeof(sp.Light) == "Color3" then
			self:light(p, sp.Light, sp.LightRange or 14, sp.LightBright or 2)
		end
		first = first or p
	end
	-- pivot du modèle = cf (sol sous l'objet, orientation de cf) quelle que soit l'orientation de la 1re pièce
	if first then
		first.PivotOffset = first.CFrame:ToObjectSpace(cf)
	end
	m.PrimaryPart = first
	m.Parent = self.set
	return m, label
end
local function S_(name, size, cf, color, mat, shape, tr)
	return { Name = name, Size = size, CFrame = cf, Color = color, Material = mat, Shape = shape, Transparency = tr }
end

PROPS.Rocket = function(S, cf, o)
	local body = o.color or C3(240, 240, 245)
	local acc = o.accent or RED_C
	local sp = {
		S_("Body", V3(11, 4.6, 4.6), CFn(0, 7.5, 0) * VCYL, body),
		S_("Band", V3(0.7, 4.75, 4.75), CFn(0, 11.2, 0) * VCYL, acc),
		S_("Nose", V3(1.8, 4.0, 4.0), CFn(0, 13.9, 0) * VCYL, acc),
		S_("Nose2", V3(1.5, 2.8, 2.8), CFn(0, 15.5, 0) * VCYL, acc),
		S_("Tip", V3(1.7, 1.7, 1.7), CFn(0, 16.7, 0), acc, nil, "Ball"),
		S_("Window", V3(0.3, 1.9, 1.9), CFn(0, 10, -2.3) * ZCYL, C3(120, 200, 255), "Glass"),
		S_("WindowRim", V3(0.25, 2.3, 2.3), CFn(0, 10, -2.25) * ZCYL, STEEL_C, "Metal"),
		S_("Nozzle", V3(1.4, 3, 3), CFn(0, 1.6, 0) * VCYL, DARK_C, "Metal"),
		S_("Hatch", V3(2.8, 5.6, 0.3), CFn(0, 4.0, -2.45), STEEL_C, "Metal"),
		S_("Door", V3(2.6, 5.4, 0.1), CFn(0, 4.0, -2.32), C3(255, 236, 170), "Neon", nil, 1),
		S_("Flame", V3(4, 2.6, 2.6), CFn(0, -1.2, 0) * VCYL, C3(255, 140, 30), "Neon", "Cyl", 1),
		S_("FlameCore", V3(5, 1.4, 1.4), CFn(0, -1.6, 0) * VCYL, C3(255, 240, 150), "Neon", "Cyl", 1),
	}
	for i = 0, 2 do
		local a = i * 2 * PI / 3 + PI / 3
		table.insert(sp, S_("Fin" .. (i + 1), V3(0.5, 4.2, 3), CFn(0, 3.4, 0) * ANG(0, a, 0) * CFn(0, 0, 3.2) * ANG(0, PI, 0), acc, nil, "Wedge"))
	end
	sp[1].Shape, sp[2].Shape, sp[3].Shape, sp[4].Shape, sp[6].Shape, sp[7].Shape, sp[8].Shape = "Cyl", "Cyl", "Cyl", "Cyl", "Cyl", "Cyl", "Cyl"
	return S:buildModel(sp, cf, "Rocket")
end
PROPS.Flag = function(S, cf, o)
	return S:buildModel({
		S_("Pole", V3(7.5, 0.25, 0.25), CFn(0, 3.75, 0) * VCYL, STEEL_C, "Metal", "Cyl"),
		S_("Ball", V3(0.5, 0.5, 0.5), CFn(0, 7.6, 0), GOLD_C, "Metal", "Ball"),
		{ Name = "Cloth", Size = V3(3.2, 2.1, 0.08), CFrame = CFn(1.7, 6.3, 0), Color = o.color or RED_C, Material = "Fabric", Text = o.text, TextColor = WHITE },
	}, cf, "Flag")
end
PROPS.Monitor = function(S, cf, o)
	return S:buildModel({
		S_("Base", V3(1.4, 0.15, 0.8), CFn(0, 0.075, 0), DARK_C),
		S_("Neck", V3(0.3, 1.0, 0.3), CFn(0, 0.6, 0.1), DARK_C),
		S_("Frame", V3(4, 2.4, 0.25), CFn(0, 2.2, 0), DARK_C),
		{ Name = "Screen", Size = V3(3.7, 2.1, 0.05), CFrame = CFn(0, 2.2, -0.14), Color = o.color or C3(20, 24, 40), Material = "Neon", Text = o.text or "", TextColor = WHITE, Stroke = 2 },
	}, cf, "Monitor")
end
PROPS.Desk = function(S, cf, o)
	local c = o.color or C3(225, 220, 210)
	return S:buildModel({
		S_("Top", V3(6, 0.3, 3), CFn(0, 2.6, 0), c),
		S_("LegL", V3(0.3, 2.45, 2.8), CFn(-2.75, 1.25, 0), C3(110, 110, 120)),
		S_("LegR", V3(0.3, 2.45, 2.8), CFn(2.75, 1.25, 0), C3(110, 110, 120)),
		S_("Back", V3(5.2, 1.4, 0.15), CFn(0, 1.6, 1.3), C3(110, 110, 120)),
	}, cf, "Desk")
end
local function chair(S, cf, o, gaming)
	local c = o.color or (gaming and C3(30, 30, 36) or C3(60, 60, 70))
	local acc = o.accent or C3(255, 40, 90)
	local sp = {
		S_("Seat", V3(2.4, 0.5, 2.4), CFn(0, 2.2, 0), c),
		S_("BackRest", V3(2.4, gaming and 3.8 or 2.6, 0.45), CFn(0, gaming and 4.5 or 3.8, 1.1), c),
		S_("Post", V3(1.6, 0.35, 0.35), CFn(0, 1.2, 0) * VCYL, STEEL_C, "Metal", "Cyl"),
		S_("Star", V3(0.2, 2.4, 2.4), CFn(0, 0.35, 0) * VCYL, DARK_C, nil, "Cyl"),
		S_("ArmL", V3(0.3, 0.25, 1.8), CFn(-1.3, 3.0, 0.1), c),
		S_("ArmR", V3(0.3, 0.25, 1.8), CFn(1.3, 3.0, 0.1), c),
	}
	if gaming then
		table.insert(sp, S_("Stripe1", V3(0.35, 3.6, 0.1), CFn(-0.6, 4.5, 0.86), acc, "Neon"))
		table.insert(sp, S_("Stripe2", V3(0.35, 3.6, 0.1), CFn(0.6, 4.5, 0.86), acc, "Neon"))
		table.insert(sp, S_("Headrest", V3(1.6, 0.6, 0.5), CFn(0, 6.2, 1.1), acc))
	end
	return S:buildModel(sp, cf, gaming and "GamingChair" or "OfficeChair")
end
PROPS.GamingChair = function(S, cf, o)
	return chair(S, cf, o, true)
end
PROPS.OfficeChair = function(S, cf, o)
	return chair(S, cf, o, false)
end
PROPS.Curtains = function(S, cf, o)
	local c = o.color or C3(165, 22, 40)
	local w, h = o.w or 12, o.h or 22
	return S:buildModel({
		S_("Left", V3(w, h, 0.6), CFn(-w / 2, h / 2, 0), c, "Fabric"),
		S_("Right", V3(w, h, 0.6), CFn(w / 2, h / 2, 0), c, "Fabric"),
		S_("Valance", V3(w * 2 + 2, 3, 1), CFn(0, h + 0.5, -0.2), C3(130, 15, 30), "Fabric"),
		S_("Trim", V3(w * 2 + 2, 0.4, 1.1), CFn(0, h - 1.1, -0.2), GOLD_C, "Metal"),
	}, cf, "Curtains")
end
PROPS.Cannon = function(S, cf, o)
	local c = o.color or C3(50, 55, 70)
	return S:buildModel({
		S_("Base", V3(3, 1, 3.2), CFn(0, 0.9, 0.6), C3(120, 80, 50), "Wood"),
		S_("Barrel", V3(5, 1.7, 1.7), CFn(0, 2.2, 0) * ANG(0.35, 0, 0) * ZCYL, c, "Metal", "Cyl"),
		S_("Muzzle", V3(0.5, 2.2, 2.2), CFn(0, 2.2, 0) * ANG(0.35, 0, 0) * CFn(0, 0, -2.4) * ZCYL, o.accent or GOLD_C, "Metal", "Cyl"),
		S_("WheelL", V3(0.4, 2.2, 2.2), CFn(-1.7, 1.1, 0.5), C3(90, 60, 40), "Wood", "Cyl"),
		S_("WheelR", V3(0.4, 2.2, 2.2), CFn(1.7, 1.1, 0.5), C3(90, 60, 40), "Wood", "Cyl"),
	}, cf, "Cannon")
end
PROPS.Bubble = function(S, cf, o)
	local d = o.size or 6
	return S:buildModel({
		S_("Sphere", V3(d, d, d), CFn(0, d / 2, 0), o.color or C3(190, 235, 255), "Glass", "Ball", 0.55),
		S_("Shine", V3(d * 0.18, d * 0.18, d * 0.18), CFn(-d * 0.22, d * 0.75, -d * 0.3), WHITE, "Neon", "Ball", 0.35),
	}, cf, "Bubble")
end
PROPS.Crown = function(S, cf, o)
	local c = o.color or GOLD_C
	local sp = { S_("Band", V3(0.7, 2.2, 2.2), CFn(0, 0.35, 0) * VCYL, c, "Metal", "Cyl") }
	for i = 0, 4 do
		local a = i * 2 * PI / 5
		table.insert(sp, S_("Spike" .. i, V3(0.35, 0.35, 0.35), CFn(math.sin(a) * 0.95, 1.05, math.cos(a) * 0.95), c, "Metal", "Ball"))
		table.insert(sp, S_("Gem" .. i, V3(0.3, 0.3, 0.12), CFn(math.sin(a) * 1.08, 0.38, math.cos(a) * 1.08) * ANG(0, a, 0), i % 2 == 0 and RED_C or C3(60, 140, 255), "Neon"))
	end
	return S:buildModel(sp, cf, "Crown")
end
PROPS.Gavel = function(S, cf, o)
	return S:buildModel({
		S_("Handle", V3(2.4, 0.3, 0.3), CFn(0, 1.2, 0) * VCYL, C3(120, 75, 40), "Wood", "Cyl"),
		S_("Head", V3(1.8, 0.9, 0.9), CFn(0, 2.5, 0), o.color or C3(95, 55, 30), "Wood", "Cyl"),
		S_("BandL", V3(0.15, 0.95, 0.95), CFn(-0.6, 2.5, 0), GOLD_C, "Metal", "Cyl"),
		S_("BandR", V3(0.15, 0.95, 0.95), CFn(0.6, 2.5, 0), GOLD_C, "Metal", "Cyl"),
	}, cf, "Gavel")
end
PROPS.Coin = function(S, cf, o)
	local d = o.size or 1.6
	return S:buildModel({
		S_("Coin", V3(d * 0.15, d, d), CFn(0, d / 2, 0) * ZCYL, o.color or GOLD_C, "Metal", "Cyl"),
		{ Name = "Mark", Size = V3(d * 0.5, d * 0.5, d * 0.17), CFrame = CFn(0, d / 2, 0), Color = C3(255, 230, 120), Material = "Neon", Text = "$", TextColor = C3(150, 100, 0), Stroke = false },
	}, cf, "Coin")
end
PROPS.Bill = function(S, cf, o)
	return S:buildModel({
		S_("Bill", V3(1.6, 0.04, 0.8), CFn(0, 0.02, 0), o.color or C3(110, 200, 90)),
		S_("Seal", V3(0.45, 0.05, 0.45), CFn(0, 0.02, 0), C3(60, 140, 60), nil, "Cyl"),
	}, cf, "Bill")
end
PROPS.Heart = function(S, cf, o)
	local c = o.color or C3(255, 70, 120)
	local k = o.size or 1
	return S:buildModel({
		S_("Core", V3(0.95, 0.95, 0.5) * k, CFn(0, 0.55 * k, 0) * ANG(0, 0, PI / 4), c, "Neon"),
		S_("L", V3(0.72, 0.72, 0.72) * k, CFn(-0.3 * k, 0.85 * k, 0), c, "Neon", "Ball"),
		S_("R", V3(0.72, 0.72, 0.72) * k, CFn(0.3 * k, 0.85 * k, 0), c, "Neon", "Ball"),
	}, cf, "Heart")
end
PROPS.Plate = function(S, cf, o)
	return S:buildModel({
		S_("Plate", V3(0.15, 2, 2), CFn(0, 0.075, 0) * VCYL, o.color or WHITE, nil, "Cyl"),
		S_("Rim", V3(0.17, 1.3, 1.3), CFn(0, 0.08, 0) * VCYL, C3(225, 230, 240), nil, "Cyl"),
	}, cf, "Plate")
end
PROPS.Pan = function(S, cf, o)
	return S:buildModel({
		S_("Pan", V3(0.3, 2.4, 2.4), CFn(0, 0.15, 0) * VCYL, o.color or DARK_C, "Metal", "Cyl"),
		S_("Handle", V3(2, 0.2, 0.3), CFn(2.1, 0.2, 0), C3(60, 40, 30), "Wood"),
	}, cf, "Pan")
end
PROPS.Bun = function(S, cf, o)
	local L = o.length or 8
	return S:buildModel({
		S_("Bottom", V3(L, 2.6, 3.2), CFn(0, 1.2, 0), C3(230, 170, 90), nil, "Cyl"),
		S_("Sausage", V3(L + 1.4, 1.7, 1.7), CFn(0, 2.3, 0), C3(190, 70, 50), nil, "Cyl"),
		S_("Mustard", V3(L * 0.8, 0.2, 0.3), CFn(0, 3.2, 0), C3(255, 215, 0), "Neon"),
		S_("Top", V3(L, 2.4, 3.0), CFn(0, 3.4, 0.9), C3(240, 180, 100), nil, "Cyl"),
	}, cf, "Bun")
end
PROPS.Belt = function(S, cf, o)
	return S:buildModel({
		S_("Strap", V3(5, 0.6, 0.1), CFn(0, 0.3, 0.02), C3(25, 25, 25), "Fabric"),
		{ Name = "Plate", Size = V3(2.2, 1.4, 0.18), CFrame = CFn(0, 0.3, -0.05), Color = o.color or GOLD_C, Material = "Metal", Text = o.text or "CHAMP", TextColor = C3(120, 70, 0), Stroke = false },
		S_("GemL", V3(0.35, 0.35, 0.2), CFn(-1.5, 0.3, -0.05), RED_C, "Neon"),
		S_("GemR", V3(0.35, 0.35, 0.2), CFn(1.5, 0.3, -0.05), RED_C, "Neon"),
	}, cf, "Belt")
end
PROPS.BoxingRing = function(S, cf, o)
	local sp = {
		S_("Platform", V3(18, 1.5, 18), CFn(0, 0.75, 0), C3(40, 40, 50)),
		S_("Mat", V3(17, 0.1, 17), CFn(0, 1.55, 0), o.color or C3(40, 110, 220), "Fabric"),
	}
	local cols = { RED_C, WHITE, C3(40, 110, 220) }
	for _, cx in ipairs({ -8.2, 8.2 }) do
		for _, cz in ipairs({ -8.2, 8.2 }) do
			table.insert(sp, S_("Post", V3(5, 0.6, 0.6), CFn(cx, 4, cz) * VCYL, STEEL_C, "Metal", "Cyl"))
		end
	end
	for i, y in ipairs({ 3, 4.2, 5.4 }) do
		table.insert(sp, S_("RopeB" .. i, V3(16.4, 0.18, 0.18), CFn(0, y, 8.2), cols[i], "Neon"))
		table.insert(sp, S_("RopeL" .. i, V3(0.18, 0.18, 16.4), CFn(-8.2, y, 0), cols[i], "Neon"))
		table.insert(sp, S_("RopeR" .. i, V3(0.18, 0.18, 16.4), CFn(8.2, y, 0), cols[i], "Neon"))
		table.insert(sp, S_("RopeF" .. i, V3(16.4, 0.18, 0.18), CFn(0, y, -8.2), cols[i], "Neon"))
	end
	return S:buildModel(sp, cf, "BoxingRing")
end
PROPS.Podium = function(S, cf, o)
	return S:buildModel({
		{ Name = "Body", Size = V3(4, 3.5, 2.5), CFrame = CFn(0, 1.75, 0), Color = o.color or C3(60, 60, 80), Text = o.text, TextColor = GOLD_C },
		S_("Top", V3(4.4, 0.3, 2.8), CFn(0, 3.6, 0), GOLD_C, "Metal"),
	}, cf, "Podium")
end
PROPS.Jumbotron = function(S, cf, o)
	return S:buildModel({
		S_("Frame", V3(16, 9, 0.8), CFn(0, 12, 0), DARK_C),
		{ Name = "Screen", Size = V3(15, 8, 0.1), CFrame = CFn(0, 12, -0.45), Color = o.color or C3(20, 30, 60), Material = "Neon", Text = o.text or "", TextColor = GOLD_C },
		S_("LegL", V3(0.8, 7.5, 0.8), CFn(-5, 3.75, 0.3), STEEL_C, "Metal"),
		S_("LegR", V3(0.8, 7.5, 0.8), CFn(5, 3.75, 0.3), STEEL_C, "Metal"),
	}, cf, "Jumbotron")
end
PROPS.Ramp = function(S, cf, o)
	return S:buildModel({ S_("Ramp", V3(o.w or 4, o.h or 2, o.l or 6), CFn(0, (o.h or 2) / 2, 0), o.color or STEEL_C, "DiamondPlate", "Wedge") }, cf, "Ramp")
end
PROPS.Crate = function(S, cf, o)
	local s = o.size or 3
	return S:buildModel({
		{ Name = "Box", Size = V3(s, s, s), CFrame = CFn(0, s / 2, 0), Color = o.color or C3(190, 140, 80), Material = "Wood", Text = o.text, TextColor = C3(80, 50, 20), Stroke = false },
		S_("Band1", V3(s + 0.1, 0.3, s + 0.1), CFn(0, s * 0.2, 0), C3(120, 85, 50), "Wood"),
		S_("Band2", V3(s + 0.1, 0.3, s + 0.1), CFn(0, s * 0.8, 0), C3(120, 85, 50), "Wood"),
	}, cf, "Crate")
end
PROPS.Plant = function(S, cf, o)
	return S:buildModel({
		S_("Pot", V3(1.6, 1.8, 1.8), CFn(0, 0.8, 0) * VCYL, C3(150, 90, 55), nil, "Cyl"),
		S_("Leaves", V3(2.6, 2.6, 2.6), CFn(0, 2.6, 0), C3(70, 170, 80), nil, "Ball"),
		S_("Leaves2", V3(1.9, 1.9, 1.9), CFn(0.5, 3.8, -0.2), C3(95, 195, 95), nil, "Ball"),
	}, cf, "Plant")
end
PROPS.Door = function(S, cf, o)
	return S:buildModel({
		S_("Frame", V3(5, 8.4, 0.5), CFn(0, 4.2, 0.1), C3(90, 90, 100)),
		S_("Panel", V3(4, 7.6, 0.3), CFn(0, 3.8, -0.15), o.color or C3(170, 120, 70), "Wood"),
		S_("Knob", V3(0.35, 0.35, 0.35), CFn(1.5, 3.6, -0.4), GOLD_C, "Metal", "Ball"),
	}, cf, "Door")
end
PROPS.MicStand = function(S, cf, o)
	return S:buildModel({
		S_("Base", V3(0.2, 1.6, 1.6), CFn(0, 0.1, 0) * VCYL, DARK_C, nil, "Cyl"),
		S_("Pole", V3(4.6, 0.18, 0.18), CFn(0, 2.4, 0) * VCYL, STEEL_C, "Metal", "Cyl"),
		S_("Mic", V3(0.55, 0.55, 0.55), CFn(0, 4.9, -0.2), o.color or C3(60, 60, 66), "Metal", "Ball"),
	}, cf, "MicStand")
end
PROPS.Trophy = function(S, cf, o)
	local c = o.color or GOLD_C
	return S:buildModel({
		S_("Base", V3(1.6, 0.6, 1.6), CFn(0, 0.3, 0), C3(60, 40, 30), "Wood"),
		S_("Stem", V3(1.2, 0.35, 0.35), CFn(0, 1.2, 0) * VCYL, c, "Metal", "Cyl"),
		S_("Cup", V3(1.5, 1.6, 1.6), CFn(0, 2.4, 0) * VCYL, c, "Metal", "Cyl"),
		S_("HandleL", V3(0.25, 0.9, 0.5), CFn(-1, 2.5, 0), c, "Metal"),
		S_("HandleR", V3(0.25, 0.9, 0.5), CFn(1, 2.5, 0), c, "Metal"),
	}, cf, "Trophy")
end
PROPS.Drone = function(S, cf, o)
	local sp = {
		S_("Body", V3(1.2, 0.4, 1.2), CFn(0, 0, 0), o.color or C3(40, 40, 46)),
		S_("Lens", V3(0.2, 0.5, 0.5), CFn(0, -0.1, -0.65) * ZCYL, C3(20, 20, 30), "Glass", "Cyl"),
		S_("Rec", V3(0.2, 0.2, 0.2), CFn(0.35, 0.25, -0.5), C3(255, 40, 40), "Neon", "Ball"),
	}
	for i, d in ipairs({ V3(1, 0, 1), V3(-1, 0, 1), V3(1, 0, -1), V3(-1, 0, -1) }) do
		table.insert(sp, S_("Arm" .. i, V3(0.15, 0.12, 1.1), CFn(d * 0.45) * CFrame.lookAt(Vector3.zero, d), C3(60, 60, 66)))
		table.insert(sp, S_("Rotor" .. i, V3(0.05, 0.9, 0.9), CFn(d * 0.85 + V3(0, 0.25, 0)) * VCYL, C3(200, 200, 210), nil, "Cyl", 0.4))
	end
	local m = S:buildModel(sp, cf, "Drone")
	return m
end
PROPS.RingLight = function(S, cf, o)
	local sp = {
		S_("Pole", V3(5, 0.2, 0.2), CFn(0, 2.5, 0) * VCYL, DARK_C, "Metal", "Cyl"),
		S_("Base", V3(0.2, 1.6, 1.6), CFn(0, 0.1, 0) * VCYL, DARK_C, nil, "Cyl"),
	}
	for i = 0, 15 do
		local a = i * 2 * PI / 16
		table.insert(sp, S_("Led" .. i, V3(0.62, 0.25, 0.25), CFn(0, 6.5, 0) * ANG(0, 0, a) * CFn(0, 1.5, 0), o.color or C3(255, 250, 235), "Neon"))
	end
	return S:buildModel(sp, cf, "RingLight")
end
PROPS.Camera = function(S, cf, o)
	local sp = {
		S_("Body", V3(1.4, 1.3, 2.4), CFn(0, 5, 0), o.color or DARK_C),
		S_("Lens", V3(1.0, 0.9, 0.9), CFn(0, 5, -1.6) * ZCYL, C3(20, 20, 26), "Glass", "Cyl"),
		S_("Rec", V3(0.25, 0.25, 0.25), CFn(0.5, 5.75, -0.9), C3(255, 40, 40), "Neon", "Ball"),
	}
	for i = 0, 2 do
		local a = i * 2 * PI / 3
		table.insert(sp, S_("Leg" .. i, V3(0.15, 4.8, 0.15), CFn(math.sin(a) * 0.9, 2.3, math.cos(a) * 0.9) * ANG(math.cos(a) * 0.2, 0, -math.sin(a) * 0.2), STEEL_C, "Metal"))
	end
	return S:buildModel(sp, cf, "Camera")
end
PROPS.Sign = function(S, cf, o)
	local w, h = o.w or 6, o.h or 2
	return S:buildModel({
		{ Name = "Board", Size = V3(w, h, 0.25), CFrame = CFn(0, (o.y or 4) + h / 2, 0), Color = o.color or C3(30, 30, 40), Text = o.text or "", TextColor = o.textColor or GOLD_C },
		S_("Post", V3(o.y or 4, 0.3, 0.3), CFn(0, (o.y or 4) / 2, 0.1) * VCYL, STEEL_C, "Metal", "Cyl"),
	}, cf, "Sign")
end
PROPS.Spotlamp = function(S, cf, o)
	return S:buildModel({
		S_("Stand", V3(4, 0.3, 0.3), CFn(0, 2, 0) * VCYL, DARK_C, "Metal", "Cyl"),
		S_("Housing", V3(1.8, 1.6, 1.6), CFn(0, 4.3, 0) * ZCYL, DARK_C, "Metal", "Cyl"),
		S_("Lens", V3(0.1, 1.4, 1.4), CFn(0, 4.3, -0.95) * ZCYL, o.color or C3(255, 248, 215), "Neon", "Cyl"),
	}, cf, "Spotlamp")
end
PROPS.Stairs = function(S, cf, o)
	local sp = {}
	local n = o.steps or 5
	for i = 1, n do
		table.insert(sp, S_("Step" .. i, V3(o.w or 6, 0.6 * i, 1.2), CFn(0, 0.3 * i, (n - i) * 1.2), o.color or C3(200, 200, 210)))
	end
	return S:buildModel(sp, cf, "Stairs")
end
PROPS.Server = function(S, cf, o)
	local sp = { S_("Rack", V3(3, 7, 2), CFn(0, 3.5, 0), o.color or C3(28, 30, 36), "Metal") }
	for i = 1, 10 do
		table.insert(sp, S_("Led" .. i, V3(0.25, 0.15, 0.1), CFn(((i % 3) - 1) * 0.8, 0.8 + i * 0.55, -1.02), (i % 2 == 0) and C3(60, 255, 120) or C3(60, 180, 255), "Neon"))
	end
	return S:buildModel(sp, cf, "Server")
end
PROPS.Mech = function(S, cf, o)
	local c = o.color or C3(255, 200, 30)
	return S:buildModel({
		S_("Leg1", V3(1.6, 5, 1.8), CFn(-1.5, 2.5, 0), c),
		S_("Leg2", V3(1.6, 5, 1.8), CFn(1.5, 2.5, 0), c),
		S_("Torso", V3(5, 4, 3), CFn(0, 7, 0.2), c),
		S_("Hazard", V3(5.1, 0.6, 3.1), CFn(0, 5.4, 0.2), C3(30, 30, 30)),
		S_("Arm1", V3(1.5, 4.5, 1.5), CFn(-3.5, 6.5, 0), c),
		S_("Arm2", V3(1.5, 4.5, 1.5), CFn(3.5, 6.5, 0), c),
		S_("Head", V3(2.5, 1.8, 2), CFn(0, 9.9, 0), c),
		S_("Visor", V3(2.1, 0.5, 0.1), CFn(0, 10, -1.02), C3(80, 220, 255), "Neon"),
		S_("Reactor", V3(1.2, 1.2, 0.2), CFn(0, 7.2, -1.32), C3(80, 220, 255), "Neon", "Cyl"),
	}, cf, "Mech")
end
SkinRevealController.Props = {}
for name in pairs(PROPS) do
	table.insert(SkinRevealController.Props, name)
end
table.sort(SkinRevealController.Props)

------------------------------------------------------------------------
-- Scènes vierges (R.stage) : build(S, opts), Location
------------------------------------------------------------------------
local STAGES = {}
STAGES.Studio = {
	Location = "",
	build = function(S, o)
		local c = o.color or C3(236, 232, 226)
		S:floor(V3(240, 1, 240), CFn(0, -0.5, 0), o.floor or c)
		S:box(V3(240, 90, 1), CFn(0, 45, 60), c)
		S:box(V3(240, 8, 8), CFn(0, 1, 56) * ANG(PI / 4, 0, 0), c)
		S:lamp(V3(0, 16, -10), C3(255, 245, 230), 50, 1.2)
	end,
}
STAGES.Void = {
	Location = "",
	build = function(S, o)
		local c = o.color or C3(8, 8, 12)
		S:floor(V3(400, 1, 400), CFn(0, -0.5, 0), c)
		enclose(S, c, 160, 160, -160, 120)
		S.cc.Brightness = -0.04
		S:lamp(V3(0, 12, -6), C3(255, 250, 240), 30, 1)
	end,
}
STAGES.Night = {
	Location = "",
	build = function(S, o)
		local sky = o.sky or C3(12, 16, 40)
		S:floor(V3(400, 1, 400), CFn(0, -0.5, 0), o.floor or C3(40, 44, 60), "Concrete")
		enclose(S, sky, 170, 170, -170, 160)
		for _ = 1, 90 do
			local a = rng:NextNumber(-1.3, 1.3)
			local el = rng:NextNumber(0.08, 1.2)
			local r = 150
			local p = V3(math.sin(a) * math.cos(el) * r, 8 + math.sin(el) * r * 0.9, math.cos(a) * math.cos(el) * r)
			local st = S:box(Vector3.one * rng:NextNumber(0.5, 1.4), CFn(p), C3(255, 250, 225), "Neon", 0, "Ball")
			st.CanQuery = false
		end
		local moon = S:box(V3(20, 20, 20), CFn(-55, 70, 140), C3(250, 245, 215), "Neon", 0, "Ball")
		moon.CanQuery = false
		S.cc.Brightness = -0.06
		S.cc.TintColor = C3(205, 215, 255)
		S:lamp(V3(0, 18, -8), C3(190, 205, 255), 60, 1.2)
	end,
}
STAGES.Sky = {
	Location = "",
	build = function(S, o)
		for _ = 1, 26 do
			local p = V3(rng:NextNumber(-90, 90), rng:NextNumber(-60, -35), rng:NextNumber(-60, 120))
			local s = rng:NextNumber(14, 30)
			local c = S:box(V3(s, s * 0.55, s), CFn(p), WHITE, nil, 0.05, "Ball")
			c.CanQuery = false
		end
		for _ = 1, 10 do
			local p = V3(rng:NextNumber(-60, 60), rng:NextNumber(-10, 30), rng:NextNumber(30, 120))
			local s = rng:NextNumber(8, 16)
			local c = S:box(V3(s, s * 0.5, s), CFn(p), WHITE, nil, 0.15, "Ball")
			c.CanQuery = false
		end
		S.cc.TintColor = o.tint or C3(235, 245, 255)
		S:lamp(V3(0, 12, -8), C3(255, 250, 235), 40, 1)
	end,
}
STAGES.Room = {
	Location = "",
	build = function(S, o)
		local w, d, h = o.w or 40, o.d or 40, o.h or 14
		local c = o.color or C3(214, 208, 196)
		S:floor(V3(w, 1, d), CFn(0, -0.5, 0), o.floor or C3(92, 108, 140), "Fabric")
		enclose(S, c, w / 2, d / 2, -d / 2, h)
		if o.dark then
			S.cc.Brightness = -0.3
			S.cc.Contrast = 0.2
		else
			for _, x in ipairs({ -8, 8 }) do
				S:box(V3(4, 0.1, 1.6), CFn(x, h - 0.55, 0), C3(255, 252, 235), "Neon")
			end
			S:lamp(V3(0, h - 2, -4), C3(255, 245, 225), 40, 1.2)
		end
	end,
}
STAGES.Stage = {
	Location = "Main Stage",
	build = function(S, o)
		local dark = C3(18, 16, 26)
		S:floor(V3(80, 1, 80), CFn(0, -0.5, -10), dark)
		S:floor(V3(34, 0.2, 18), CFn(0, 0.1, 1), C3(115, 75, 48), "Wood")
		S:box(V3(34, 0.25, 0.3), CFn(0, 0.22, -7.9), C3(255, 205, 70), "Neon")
		enclose(S, dark, 26, 12, -36, 30)
		for i = -7, 7 do
			S:cyl(22, 2.6, V3(i * 2.3, 11, 10), o.back or C3(165, 22, 40), "Fabric")
		end
		local cur = PROPS.Curtains(S, S.O * CFn(0, 0, -5), { color = o.color })
		S.curtainL, S.curtainR = cur:FindFirstChild("Left"), cur:FindFirstChild("Right")
		local l0, r0 = S.curtainL.CFrame, S.curtainR.CFrame
		S.curtainOpen = function(t)
			S:mover(t or 1.2, function(a)
				local e = ease(a, ES.Quad, ED.InOut)
				S.curtainL.CFrame = l0 + V3(-12 * e, 0, 0)
				S.curtainR.CFrame = r0 + V3(12 * e, 0, 0)
			end, "curtains")
			return t or 1.2
		end
		S:lamp(V3(0, 14, -6), C3(255, 235, 200), 40, 1)
	end,
}
SkinRevealController.Stages = {}
for name in pairs(STAGES) do
	table.insert(SkinRevealController.Stages, name)
end
table.sort(SkinRevealController.Stages)

------------------------------------------------------------------------
-- Construction de l'objet R (API des scripts)
------------------------------------------------------------------------
function Engine.makeR(S)
	local R = {}
	local cam, fx = {}, {}
	R.cam, R.fx, R.S = cam, fx, S
	R.color, R.rc, R.tier, R.rarity = S.col, S.rc, S.tier, S.rarity
	local function ensureStage()
		if not S.staged then
			R.stage("Studio")
		end
	end

	-- infos
	local attacks = {}
	pcall(function()
		local ids = {}
		for _, k in ipairs({ "Attacks", "TransformAttacks", "Transformed" }) do
			if type(S.charDef[k]) == "table" then
				for _, id in pairs(S.charDef[k]) do
					if type(id) == "string" then
						table.insert(ids, id)
					end
				end
			end
		end
		for _, id in ipairs(ids) do
			if type(S.data.Attacks[id]) == "table" then
				attacks[id] = S.data.Attacks[id]
			end
		end
		local content = S.data.Content[S.charId]
		if content and type(content.Attacks) == "table" then
			for id, a in pairs(content.Attacks) do
				if type(id) == "string" and type(a) == "table" then
					attacks[id] = attacks[id] or a
				end
			end
		end
	end)
	local ctx = {
		skinId = S.id, def = S.def, charId = S.charId, charDef = S.charDef, rarity = S.rarity, tier = S.tier,
		color = S.col, rarityColor = S.rc, caption = S.caption, entry = S.entry, isNew = S.opts.isNew ~= false,
		replay = S.opts.replay == true, opts = S.opts, attacks = attacks, rng = rng,
	}
	function R.rand(a, b)
		return rng:NextNumber(a or 0, b or 1)
	end
	function R.randi(a, b)
		return rng:NextInteger(a, b)
	end
	function R.choose(list)
		return list[rng:NextInteger(1, #list)]
	end

	-- repères
	function R.at(x, y, z)
		return S.O * CFn(x, y, z)
	end
	function R.wp(x, y, z)
		return S.O * V3(x, y, z)
	end
	function R.loc(v)
		return v - S.O.Position
	end
	function R.pos(obj)
		return W(S, obj) - S.O.Position
	end

	-- temps
	function R.wait(t)
		if S.phase == "scene" then
			ensureStage()
		end
		local g = S.threadGen[coroutine.running()]
		if g and g ~= S.gen then
			error(SKIP, 0)
		end
		S:wait(t or 0)
		g = S.threadGen[coroutine.running()]
		if g and g ~= S.gen then
			error(SKIP, 0)
		end
	end
	function R.spawn(fn, ...)
		local args = table.pack(...)
		local gen = S.gen
		task.spawn(function()
			if S.alive and S.gen == gen then
				S.threadGen[coroutine.running()] = gen
				runSafe(fn, table.unpack(args, 1, args.n))
			end
		end)
	end
	function R.delay(t, fn)
		R.spawn(function()
			R.wait(t)
			fn()
		end)
		return t
	end
	function R.every(interval, fn)
		R.spawn(function()
			local i = 0
			while S.alive do
				i += 1
				fn(i)
				R.wait(interval)
			end
		end)
	end
	function R.over(t, fn, style, dir)
		return S:mover(t, function(a, e)
			fn(a, ease(a, style or ES.Linear, dir or ED.InOut), e)
		end)
	end
	function R.slowmo(scale, t)
		S.slowTok = (S.slowTok or 0) + 1
		local tok = S.slowTok
		S:setTimeScale(scale or 1)
		if t then
			task.delay(t, function()
				if S.alive and S.slowTok == tok then
					S:setTimeScale(1)
				end
			end)
		end
		return t or 0
	end
	function R.freeze(dur)
		dur = dur or 0.15
		S.frozenUntil = os.clock() + dur
		if S.rig then
			ProcAnim.freeze(S.rig, dur)
		end
		pcall(CartoonFX.impactFrame, 0.8)
		S:flash(WHITE, 0.01, 0.02, 0.12, 0.6)
		local c0, s0 = S.cc.Contrast, S.cc.Saturation
		S.cc.Contrast, S.cc.Saturation = c0 + 0.5, s0 - 0.4
		task.delay(dur, function()
			if S.cc and S.cc.Parent then
				S.cc.Contrast, S.cc.Saturation = c0, s0
			end
		end)
		return dur
	end
	function R.mark(cf)
		S.heroCF = WCF(S, cf or CFn(0, 3, 0))
	end
	function R.onSkip(fn)
		S.onSkip = fn
	end
	function R.title(o)
		o = o or {}
		if S.cardShown then
			return
		end
		ensureStage()
		S.cardShown = true
		if o.shot then
			cam.hero(0)
		end
		local keepJob = S.camJob
		showCard(S)
		if o.push == false or keepJob then
			S.camJob = keepJob
		end
	end

	-- scène
	function R.stage(nameOrFn, o)
		o = o or {}
		-- remplace le décor précédent (le perso est conservé)
		for _, ch in ipairs(S.set:GetChildren()) do
			if ch ~= S.rig then
				ch:Destroy()
			end
		end
		S.movers = {}
		S.cc.Brightness, S.cc.Contrast, S.cc.Saturation, S.cc.TintColor = 0, 0.08, 0.12, WHITE
		S.staged = true
		local loc
		if type(nameOrFn) == "function" then
			nameOrFn(R)
		elseif type(nameOrFn) == "string" and STAGES[nameOrFn] then
			STAGES[nameOrFn].build(S, o)
			loc = STAGES[nameOrFn].Location
		elseif type(nameOrFn) == "string" and SCENES[nameOrFn] then
			local before = S.heroCF
			SCENES[nameOrFn].build(S)
			loc = SCENES[nameOrFn].Location
			if S.heroCF ~= before and S.root then
				S.root.CFrame = S.heroCF
			end
		else
			warn("[SkinReveal] scène inconnue", nameOrFn)
			STAGES.Studio.build(S, o)
		end
		if not S.entry.Location and loc and loc ~= "" then
			S:setLocation(loc)
		end
	end
	function R.box(size, cf, color, mat, tr, shape)
		return S:box(size, typeof(cf) == "Vector3" and CFn(cf) or (cf or CFn()), color, mat, tr, shape)
	end
	function R.cyl(h, d, pos, color, mat)
		return S:cyl(h, d, typeof(pos) == "CFrame" and pos.Position or pos, color, mat)
	end
	function R.ball(d, pos, color, mat, tr)
		return S:box(V3(d, d, d), typeof(pos) == "Vector3" and CFn(pos) or pos, color, mat, tr, "Ball")
	end
	function R.floor(size, cf, color, mat)
		return S:floor(size, typeof(cf) == "Vector3" and CFn(cf) or cf, color, mat)
	end
	function R.text(part, text, o)
		return S:sign(part, text, o)
	end
	function R.billboard(text, pos, o)
		o = o or {}
		local anchor = S:part({ Size = V3(0.2, 0.2, 0.2), CFrame = CFn(W(S, pos)), Transparency = 1, CanQuery = false })
		local size = o.size or 4
		local g = Instance.new("BillboardGui")
		g.Size = UDim2.fromScale(o.w or size * 3, size)
		g.AlwaysOnTop = false
		g.LightInfluence = 0
		g.MaxDistance = 300
		g.Adornee = anchor
		g.Parent = anchor
		local l = UITheme.label({ Name = "Label", Text = text, TextColor3 = o.Color or WHITE, Size = UDim2.fromScale(1, 1), Stroke = 3 })
		if o.Bg then
			l.BackgroundTransparency = 0
			l.BackgroundColor3 = o.Bg
		end
		l.Parent = g
		local st = l:FindFirstChildOfClass("UIStroke")
		if st and o.StrokeColor then
			st.Color = o.StrokeColor
		end
		return g, anchor
	end
	function R.light(pos, color, range, bright)
		if typeof(pos) == "Instance" and pos:IsA("BasePart") then
			return S:light(pos, color, range, bright)
		end
		local p = S:part({ Size = V3(0.2, 0.2, 0.2), CFrame = CFn(W(S, pos)), Transparency = 1, CanQuery = false })
		return S:light(p, color, range, bright)
	end
	function R.spot(from, to, o)
		o = o or {}
		local col = o.color or C3(255, 248, 215)
		local f, t = W(S, from), W(S, to)
		local lampP = S:part({ Size = V3(1.6, 1.6, 2.4), CFrame = CFrame.lookAt(f, t), Color = C3(45, 45, 52), Material = Enum.Material.Metal })
		local w = o.width or 3.6
		local beam = S:part({ Shape = Enum.PartType.Cylinder, Size = V3(1, w, w), Color = col, Material = Enum.Material.Neon, Transparency = 1, CanQuery = false, CastShadow = false })
		local pool = S:part({ Shape = Enum.PartType.Cylinder, Size = V3(0.05, w * 1.8, w * 1.8), Color = col, Material = Enum.Material.Neon, Transparency = 1, CanQuery = false, CastShadow = false })
		local light = S:light(lampP, col, o.range or 45, 0, Enum.NormalId.Front, o.angle or 22)
		local spot = { lamp = lampP, beam = beam, pool = pool, light = light, target = t }
		local function place()
			local len = (spot.target - f).Magnitude
			beam.Size = V3(len, w, w)
			beam.CFrame = CFrame.lookAt(f:Lerp(spot.target, 0.5), spot.target) * ANG(0, PI / 2, 0)
			pool.CFrame = CFn(spot.target.X, spot.target.Y + 0.03, spot.target.Z) * ANG(0, 0, PI / 2)
			lampP.CFrame = CFrame.lookAt(f, spot.target)
		end
		place()
		function spot.on(tt)
			S:mover(tt or 0.05, function(a)
				beam.Transparency = 1 - 0.12 * a
				pool.Transparency = 1 - 0.4 * a
				light.Brightness = (o.brightness or 8) * a
			end)
		end
		function spot.off(tt)
			S:mover(tt or 0.05, function(a)
				beam.Transparency = 0.88 + 0.12 * a
				pool.Transparency = 0.6 + 0.4 * a
				light.Brightness = (o.brightness or 8) * (1 - a)
			end)
		end
		function spot.aim(pos, tt)
			local from0, to0 = spot.target, W(S, pos)
			return S:mover(tt or 0.3, function(a)
				spot.target = from0:Lerp(to0, ease(a))
				place()
			end, beam)
		end
		function spot.color(c)
			beam.Color, pool.Color, light.Color = c, c, c
		end
		if o.on then
			spot.on(0)
		end
		return spot
	end
	function R.model(specs, cf)
		return S:buildModel(specs, WCF(S, cf or CFn()), "Model")
	end
	function R.prop(name, cf, o)
		o = o or {}
		local wcf = WCF(S, cf or CFn())
		if type(name) == "table" then
			local sp = name
			if sp[1] then
				return S:buildModel(sp, wcf, "Model")
			end
			sp = table.clone(sp)
			sp.CFrame = CFn()
			local m, l = S:buildModel({ sp }, wcf, sp.Name or "Prop")
			return m.PrimaryPart, l
		end
		local b = PROPS[name]
		if not b then
			warn("[SkinReveal] accessoire inconnu", name)
			return S:buildModel({ { Name = "Box", Size = V3(2, 2, 2), CFrame = CFn(0, 1, 0), Color = C3(200, 200, 200), Text = tostring(name), TextColor = INK } }, wcf, tostring(name))
		end
		return b(S, wcf, o)
	end
	function R.mesh(assetName, cf, size)
		local folder = ReplicatedStorage:FindFirstChild("SkinAssets")
		local src = folder and folder:FindFirstChild(assetName)
		if not src then
			return nil
		end
		local obj = src:Clone()
		local parts = {}
		if obj:IsA("BasePart") then
			table.insert(parts, obj)
		end
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(parts, d)
			elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
				d:Destroy()
			end
		end
		for _, p in ipairs(parts) do
			p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		end
		local wcf = WCF(S, cf or CFn())
		if obj:IsA("Model") then
			if size then
				local _, ext = obj:GetBoundingBox()
				local m = math.max(ext.X, ext.Y, ext.Z)
				if m > 0 then
					pcall(function()
						obj:ScaleTo(obj:GetScale() * size / m)
					end)
				end
			end
			obj:PivotTo(wcf)
		else
			if size then
				local m = math.max(obj.Size.X, obj.Size.Y, obj.Size.Z)
				if m > 0 then
					obj.Size = obj.Size * (size / m)
				end
			end
			obj.CFrame = wcf
		end
		obj.Parent = S.set
		return obj
	end
	local function limbOf(where)
		if typeof(where) == "Instance" then
			return where, CFn()
		end
		local rig = S.rig
		if where == "LeftHand" then
			return rig:FindFirstChild("Left Arm"), CFn(0, -1.1, 0)
		elseif where == "Head" then
			return rig:FindFirstChild("Head"), CFn(0, 0.6, 0)
		elseif where == "Torso" then
			return rig:FindFirstChild("Torso"), CFn()
		elseif where == "Back" then
			return rig:FindFirstChild("Torso"), CFn(0, 0, 0.7)
		end
		return rig:FindFirstChild("Right Arm"), CFn(0, -1.1, 0)
	end
	local function partsOf(obj)
		local list = {}
		if obj:IsA("BasePart") then
			table.insert(list, obj)
		end
		for _, d in ipairs(obj:GetDescendants()) do
			if d:IsA("BasePart") then
				table.insert(list, d)
			end
		end
		return list
	end
	function R.attach(obj, where, off)
		if typeof(obj) ~= "Instance" then
			return obj
		end
		R.detach(obj)
		local limb, base = limbOf(where)
		if not limb then
			return obj
		end
		local cf = limb.CFrame * base * (off or CFn())
		if obj:IsA("Model") then
			obj:PivotTo(cf)
		else
			obj.CFrame = cf
		end
		local welds = {}
		for _, p in ipairs(partsOf(obj)) do
			p.Anchored = false
			p.Massless = true
			p.CanCollide = false
			local w = Instance.new("WeldConstraint")
			w.Part0 = limb
			w.Part1 = p
			w.Parent = p
			table.insert(welds, w)
		end
		S.attached[obj] = welds
		return obj
	end
	function R.detach(obj)
		local welds = S.attached[obj]
		if not welds then
			return obj
		end
		S.attached[obj] = nil
		for _, w in ipairs(welds) do
			w:Destroy()
		end
		for _, p in ipairs(partsOf(obj)) do
			p.Anchored = true
		end
		return obj
	end
	local function setSignatureVisible(on)
		if S.signature then
			for _, p in ipairs(S.signature:GetDescendants()) do
				if p:IsA("BasePart") and S.vis[p] then
					p.Transparency = on and S.vis[p] or 1
				end
			end
		end
	end
	function R.hold(name, hand, off)
		hand = hand == "Left" and "Left" or "Right"
		local arm = S.rig:FindFirstChild(hand .. " Arm")
		if not arm then
			return nil
		end
		local obj
		local def = type(name) == "string" and S.data.Props[name]
		if type(def) == "table" and not PROPS[name] then
			obj = Instance.new("Model")
			obj.Name = "Held_" .. name
			for _, d in ipairs(def) do
				if type(d) == "table" and typeof(d[1]) == "Vector3" then
					local p = Instance.new("Part")
					if typeof(d[4]) == "EnumItem" then
						p.Shape = d[4]
					end
					p.Size = d[1]
					p.Color = typeof(d[3]) == "Color3" and d[3] or WHITE
					p.Material = Enum.Material.SmoothPlastic
					p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
					p.CFrame = arm.CFrame * (typeof(d[2]) == "CFrame" and d[2] or CFn()) * (off or CFn())
					local w = Instance.new("WeldConstraint")
					w.Part0 = arm
					w.Part1 = p
					w.Parent = p
					p.Parent = obj
				end
			end
			obj.Parent = S.rig
		else
			obj = R.prop(name, CFn(0, -50, 0))
			R.attach(obj, hand .. "Hand", off or ANG(-PI / 2, 0, 0))
		end
		if hand == S.signatureHand then
			setSignatureVisible(false)
		end
		table.insert(S.held, { obj = obj, hand = hand })
		return obj
	end
	function R.drop(obj)
		for i = #S.held, 1, -1 do
			local h = S.held[i]
			if obj == nil or h.obj == obj then
				S.attached[h.obj] = nil
				pcall(function()
					h.obj:Destroy()
				end)
				table.remove(S.held, i)
			end
		end
		local stillSig = false
		for _, h in ipairs(S.held) do
			if h.hand == S.signatureHand then
				stillSig = true
			end
		end
		if not stillSig then
			setSignatureVisible(true)
		end
	end
	function R.show(obj, visible, t)
		if typeof(obj) ~= "Instance" then
			return 0
		end
		local list = partsOf(obj)
		local from = {}
		for _, p in ipairs(list) do
			if S.origTr[p] == nil then
				S.origTr[p] = (p.Transparency >= 1 and not visible) and 0 or (p.Transparency < 1 and p.Transparency or 0)
			end
			from[p] = p.Transparency
		end
		return S:mover(t or 0.001, function(a)
			for _, p in ipairs(list) do
				local goal = visible and S.origTr[p] or 1
				p.Transparency = from[p] + (goal - from[p]) * a
			end
		end, obj)
	end
	function R.destroy(obj, kind)
		if typeof(obj) ~= "Instance" then
			return
		end
		local p = W(S, obj)
		if kind == "puff" then
			pcall(CartoonFX.puff, p, 3)
		elseif kind == "sparks" then
			pcall(CartoonFX.sparks, p, 18, S.col)
		elseif kind == "pop" then
			pcall(CartoonFX.puff, p, 2)
			pcall(CartoonFX.shards, p, 10, { WHITE, C3(190, 235, 255) }, 0.8)
		end
		S.attached[obj] = nil
		obj:Destroy()
	end

	-- perso
	R.rig, R.root = S.rig, S.root
	function R.place(cf)
		for _, m in ipairs(S.movers) do
			if m.key == S.rig then
				m.dead = true
			end
		end
		S.root.CFrame = WCF(S, cf)
	end
	function R.face(target, t)
		local p = S.root.Position
		local tp = W(S, target)
		local cf = CFrame.lookAt(p, V3(tp.X, p.Y, tp.Z))
		if not t or t <= 0 then
			S.root.CFrame = cf
			return 0
		end
		return R.moveTo(S.rig, cf - S.O.Position, t)
	end
	function R.alpha(a, t)
		local a0 = S.curAlpha or 1
		S.curAlpha = a
		if not t or t <= 0 then
			S:alpha(a)
			return 0
		end
		return S:mover(t, function(x)
			S:alpha(a0 + (a - a0) * x)
		end, "rigAlpha")
	end
	function R.transform(on)
		on = on ~= false
		S.rig:SetAttribute("Transformed", on)
		S:flash(WHITE, 0.03, 0.03, 0.25, 0.3)
		pcall(CartoonFX.sparks, S.root.Position, 16, S.col)
	end
	local function resolveFrames(nameOrFrames)
		if type(nameOrFrames) == "table" then
			if nameOrFrames[1] then
				return nameOrFrames
			end
			return holdAnim(nameOrFrames)
		end
		if type(nameOrFrames) ~= "string" then
			return nil
		end
		return MOVES[nameOrFrames] or POSE_HOLD[nameOrFrames] or ProcAnim.Anims[nameOrFrames]
	end
	function R.anim(nameOrFrames, speed)
		local frames = resolveFrames(nameOrFrames)
		if not frames then
			warn("[SkinReveal] animation inconnue", nameOrFrames)
			return 0
		end
		return S:playTrack(frames, speed or 1)
	end
	function R.pose(nameOrTable)
		local frames
		if type(nameOrTable) == "table" then
			frames = holdAnim(nameOrTable)
		else
			frames = POSE_HOLD[nameOrTable] or resolveFrames(nameOrTable)
		end
		if not frames then
			warn("[SkinReveal] pose inconnue", nameOrTable)
			frames = POSE_HOLD.Hero
		end
		return S:playTrack(frames, 1)
	end
	function R.attackAnim(id, speed)
		id = id or (type(S.charDef.Attacks) == "table" and S.charDef.Attacks[1])
		local atk = attacks[id] or S.data.Attacks[id or ""]
		if type(atk) ~= "table" then
			return 0
		end
		local animName = (atk.Anim and ProcAnim.Anims[atk.Anim]) and atk.Anim or "Punch4"
		local frames = ProcAnim.Anims[animName]
		local strikeT, len = strikeTime(frames)
		speed = speed or 1
		local held = atk.Prop and R.hold(atk.Prop) or nil
		S:playTrack(frames, speed)
		if held then
			R.delay(math.max(len / speed, 0.3), function()
				R.drop(held)
			end)
		end
		return strikeT / speed
	end

	-- mouvements
	local function moverKey(obj)
		return obj == "rig" and S.rig or obj
	end
	function R.moveTo(obj, cf, t, style, dir)
		obj = moverKey(obj)
		local from = getCF(S, obj)
		if not from then
			return 0
		end
		local to = WCF(S, cf)
		if typeof(cf) == "Vector3" then
			to = CFn(to.Position) * from.Rotation
		end
		if not t or t <= 0 then
			setCF(S, obj, to)
			return 0
		end
		return S:mover(t, function(a)
			setCF(S, obj, from:Lerp(to, ease(a, style, dir)))
		end, obj)
	end
	function R.walk(cf, t, gait)
		local from = S.root.CFrame
		local to = WCF(S, cf)
		local flat = V3(to.X - from.X, 0, to.Z - from.Z)
		local dirCF = flat.Magnitude > 0.05 and CFrame.lookAt(from.Position, from.Position + flat) or from
		if typeof(cf) == "Vector3" then
			to = CFn(to.Position) * dirCF.Rotation
		end
		S.root.CFrame = dirCF
		local g = MOVES[gait or "Walk"] or MOVES.Walk
		S:playTrack(g, 1)
		local start = dirCF
		return S:mover(t, function(a)
			local p = start.Position:Lerp(to.Position, a)
			local rot = a > 0.85 and dirCF.Rotation:Lerp(to.Rotation, (a - 0.85) / 0.15) or dirCF.Rotation
			S.root.CFrame = CFn(p) * rot
		end, S.rig, function()
			if S.alive then
				S:playTrack(MOVES.Stop, 1)
			end
		end)
	end
	function R.jump(obj, cf, t, height)
		obj = moverKey(obj)
		local from = getCF(S, obj)
		if not from then
			return 0
		end
		local to = WCF(S, cf)
		if typeof(cf) == "Vector3" then
			to = CFn(to.Position) * from.Rotation
		end
		height = height or 5
		local isRig = obj == S.rig
		if isRig then
			S:playTrack(MOVES.Jump, math.clamp(1.2 / math.max(t, 0.3), 0.6, 2))
		end
		return S:mover(t, function(a)
			setCF(S, obj, from:Lerp(to, a) + V3(0, math.sin(a * PI) * height, 0))
		end, obj, isRig and function()
			if S.alive then
				S:playTrack(MOVES.Land, 1)
				pcall(CartoonFX.dust, S.root.Position - V3(0, 3, 0), 4)
			end
		end or nil)
	end
	function R.fly(obj, points, t, o)
		obj = moverKey(obj)
		o = o or {}
		local from = getCF(S, obj)
		if not from or type(points) ~= "table" or #points == 0 then
			return 0
		end
		local pts = { from.Position }
		for _, p in ipairs(points) do
			table.insert(pts, W(S, p))
		end
		local lastRot = typeof(points[#points]) == "CFrame" and (S.O * points[#points]).Rotation or from.Rotation
		local n = #pts
		local function at(u)
			local seg = math.clamp(u * (n - 1), 0, n - 1 - 1e-6)
			local i = math.floor(seg) + 1
			local f = seg - (i - 1)
			local p0, p1, p2, p3 = pts[math.max(i - 1, 1)], pts[i], pts[math.min(i + 1, n)], pts[math.min(i + 2, n)]
			local f2, f3 = f * f, f * f * f
			return 0.5 * ((2 * p1) + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f2 + (-p0 + 3 * p1 - 3 * p2 + p3) * f3)
		end
		return S:mover(t, function(a)
			local u = ease(a, o.style or ES.Sine, o.dir or ED.InOut)
			local p = at(u)
			local rot
			if o.face then
				local q = at(math.min(u + 0.01, 1))
				local d = q - p
				if d.Magnitude < 1e-3 then
					rot = getCF(S, obj).Rotation
				else
					rot = CFrame.lookAt(Vector3.zero, d).Rotation
				end
			else
				rot = from.Rotation:Lerp(lastRot, u)
			end
			setCF(S, obj, CFn(p) * rot)
		end, obj)
	end
	function R.spin(obj, turns, t, axis)
		obj = moverKey(obj)
		local from = getCF(S, obj)
		if not from then
			return 0
		end
		local total = (turns or 1) * 2 * PI
		return S:mover(t or 1, function(a)
			local e = ease(a, ES.Quad, ED.InOut) * total
			local r = (axis == "X" and ANG(e, 0, 0)) or (axis == "Z" and ANG(0, 0, e)) or ANG(0, e, 0)
			setCF(S, obj, from * r)
		end, obj)
	end
	function R.teleport(obj, cf, kind)
		obj = moverKey(obj)
		local p0 = W(S, obj)
		local to = WCF(S, cf)
		local function burst(p)
			if kind == "puff" then
				pcall(CartoonFX.puff, p, 3)
			elseif kind == "glitch" then
				S:cubes(p, 12, { C3(0, 255, 200), C3(255, 0, 200), WHITE }, 2)
				S:glitchBars()
			elseif kind == "flash" then
				S:flash(WHITE, 0.02, 0.03, 0.2, 0.3)
				pcall(CartoonFX.light, p, S.col, 20, 5, 0.3)
			elseif kind == "sparkle" then
				pcall(CartoonFX.sparks, p, 16, S.col)
				pcall(CartoonFX.twinkle, p)
			end
		end
		burst(p0)
		if typeof(cf) == "Vector3" then
			local cur = getCF(S, obj)
			to = CFn(to.Position) * (cur and cur.Rotation or CFn())
		end
		setCF(S, obj, to)
		burst(to.Position)
		return 0
	end
	function R.tween(obj, t, props, style, dir)
		if typeof(obj) ~= "Instance" then
			return 0
		end
		local from = {}
		for k in pairs(props) do
			from[k] = obj[k]
		end
		return S:mover(t, function(a)
			if not obj.Parent then
				return
			end
			local e = ease(a, style or ES.Quad, dir or ED.Out)
			for k, v in pairs(props) do
				obj[k] = lerpAny(from[k], v, e)
			end
		end)
	end
	function R.scale(model, factor, t)
		if typeof(model) ~= "Instance" or not model:IsA("Model") then
			return 0
		end
		local s0 = model:GetScale()
		local s1 = s0 * factor
		return S:mover(t or 0.001, function(a)
			pcall(function()
				model:ScaleTo(s0 + (s1 - s0) * ease(a, ES.Back, ED.Out))
			end)
		end, model)
	end

	-- caméra
	local function look(pos, target)
		return CFrame.lookAt(W(S, pos), W(S, target))
	end
	function cam.cut(pos, target, fov, roll)
		S:cam(look(pos, target), fov)
		if roll then
			S.camRoll = roll
		end
		return 0
	end
	function cam.move(pos, target, t, fov, style, dir)
		S:shot(look(pos, target), t, fov, style, dir)
		return t
	end
	function cam.dolly(from, to, target, t, fov)
		local f, tt, tg = W(S, from), W(S, to), target
		local fov0 = S.camFov
		S:camFn(t, function(a)
			local e = ease(a, ES.Sine, ED.InOut)
			return CFrame.lookAt(f:Lerp(tt, e), W(S, tg)), fov and (fov0 + (fov - fov0) * e) or nil
		end)
		return t
	end
	local function around(center, yaw, dist, h)
		return W(S, center) + V3(math.sin(yaw) * dist, h, -math.cos(yaw) * dist)
	end
	function cam.pushIn(target, d0, d1, t, o)
		o = o or {}
		local yaw, h = o.yaw or 0, o.height or 1.5
		local fov0 = S.camFov
		S:camFn(t, function(a)
			local e = ease(a, o.style or ES.Sine, o.dir or ED.Out)
			local c = W(S, target)
			return CFrame.lookAt(around(target, yaw, d0 + (d1 - d0) * e, h), c), o.fov and (fov0 + (o.fov - fov0) * e) or nil
		end)
		return t
	end
	cam.pullOut = cam.pushIn
	function cam.orbit(center, radius, height, a0, a1, t, fov0, fov1)
		local f0 = fov0 or S.camFov
		S:camFn(t, function(a)
			local e = ease(a, ES.Sine, ED.InOut)
			local ang = a0 + (a1 - a0) * e
			return CFrame.lookAt(around(center, ang, radius, height), W(S, center)), f0 + ((fov1 or f0) - f0) * e
		end)
		return t
	end
	function cam.crane(center, h0, h1, dist, t, o)
		o = o or {}
		local fov0 = S.camFov
		S:camFn(t, function(a)
			local e = ease(a, ES.Sine, ED.InOut)
			return CFrame.lookAt(around(center, o.yaw or 0, dist, h0 + (h1 - h0) * e), W(S, center) + V3(0, o.lookUp or 0, 0)), o.fov and (fov0 + (o.fov - fov0) * e) or nil
		end)
		return t
	end
	function cam.whip(pos, target, t)
		t = t or 0.18
		pcall(CartoonFX.speedLines, t + 0.15, WHITE)
		local blur = Instance.new("BlurEffect")
		blur.Name = "SkinRevealBlur"
		blur.Size = 0
		blur.Parent = Lighting
		table.insert(S.lfx, blur)
		S:mover(t + 0.1, function(a)
			blur.Size = math.sin(a * PI) * 22
		end, nil, function()
			blur:Destroy()
		end)
		S:shot(look(pos, target), t, nil, ES.Quart, ED.InOut)
		S:sound("Whoosh", nil, 0.5)
		return t
	end
	function cam.lowAngle(target, dist, t)
		dist = dist or 9
		local c = W(S, target)
		local cf = CFrame.lookAt(c + V3(dist * 0.3, -2.4, -dist), c + V3(0, 1.4, 0))
		if t and t > 0 then
			S:shot(cf, t, 42)
		else
			S:cam(cf, 42)
		end
		return t or 0
	end
	function cam.topDown(target, h, t)
		local c = W(S, target)
		local cf = CFrame.lookAt(c + V3(0, h or 22, -0.5), c, V3(0, 0, 1))
		if t and t > 0 then
			S:shot(cf, t)
		else
			S:cam(cf)
		end
		return t or 0
	end
	function cam.roll(angle, t)
		local r0 = S.camRoll or 0
		return S:mover(t or 0.001, function(a)
			S.camRoll = r0 + (angle - r0) * ease(a)
		end, "camRoll")
	end
	cam.dutch = cam.roll
	function cam.follow(obj, offset, t, o)
		o = o or {}
		offset = offset or V3(0, 3, -12)
		local lag = o.lag or 0
		S:camFn(t, function()
			local p = W(S, obj)
			local want = CFrame.lookAt(p + offset, p + (o.look or V3(0, 1, 0)))
			return lag > 0 and S.camCF:Lerp(want, 1 - lag) or want, o.fov
		end)
		return t
	end
	function cam.track(t, fn)
		S:camFn(t, function(a, e)
			local p, l, f = fn(a, e)
			return CFrame.lookAt(W(S, p), W(S, l)), f
		end)
		return t
	end
	function cam.hero(t)
		local h = S.heroCF
		local cf = CFrame.lookAt(h * V3(-0.8, -0.6, -17.5), h * V3(4.6, -0.1, 0))
		if t and t > 0 then
			S:shot(cf, t, 37, ES.Quart, ED.Out)
		else
			S:cam(cf, 37)
		end
		return t or 0
	end
	function cam.shake(a)
		CartoonFX.shake(a or 0.5)
	end
	function cam.punch(a)
		S:punch(a or 6)
	end
	function cam.fov(f, t)
		local f0 = S.camFov
		if not t or t <= 0 then
			S.camFov = f
			return 0
		end
		return S:mover(t, function(a)
			S.camFov = f0 + (f - f0) * ease(a)
		end, "camFov")
	end
	cam.slowmo, cam.freeze = R.slowmo, R.freeze

	-- effets (ne lèvent jamais d'erreur)
	local function safe(fn)
		return function(...)
			local ok, r = pcall(fn, ...)
			if not ok then
				warn("[SkinReveal] fx :", r)
				return nil
			end
			return r
		end
	end
	local function floaters(pos, n, build, life, rise, drift, spin)
		local base = W(S, pos)
		for i = 1, n do
			local obj = build(i)
			local p0 = base + V3(rng:NextNumber(-1, 1), rng:NextNumber(-0.5, 0.5), rng:NextNumber(-1, 1)) * (drift or 1.5)
			local d = V3(rng:NextNumber(-1, 1) * (drift or 1.5), rise * rng:NextNumber(0.7, 1.3), rng:NextNumber(-1, 1) * (drift or 1.5))
			local ph = rng:NextNumber(0, 6)
			local l = life * rng:NextNumber(0.8, 1.2)
			local list = partsOf(obj)
			local base0 = {}
			for _, p in ipairs(list) do
				base0[p] = p.Transparency
			end
			S:mover(l, function(a)
				local q = p0 + d * ease(a, ES.Sine, ED.Out) + V3(math.sin(a * 6 + ph) * 0.4, 0, 0)
				local cf = CFn(q) * ANG(0, (spin or 0) * a + ph, 0)
				if obj:IsA("Model") then
					obj:PivotTo(cf)
				else
					obj.CFrame = cf
				end
				if a > 0.7 then
					for _, p in ipairs(list) do
						p.Transparency = base0[p] + (1 - base0[p]) * (a - 0.7) / 0.3
					end
				end
			end, nil, function()
				obj:Destroy()
			end)
		end
	end
	fx.smoke = safe(function(pos, n, color, size)
		local base = W(S, pos)
		for _ = 1, n or 10 do
			local s = (size or 2.5) * rng:NextNumber(0.7, 1.3)
			local p = S:part({ Shape = Enum.PartType.Ball, Size = V3(s, s, s), CFrame = CFn(base + V3(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * s), Color = color or C3(200, 200, 210), Transparency = 0.3, CanQuery = false, CastShadow = false })
			local d = V3(rng:NextNumber(-1, 1) * s * 1.6, rng:NextNumber(0.6, 1.6) * s, rng:NextNumber(-1, 1) * s * 1.6)
			local c0 = p.CFrame
			S:mover(rng:NextNumber(1.2, 2), function(a)
				local k = 1 + a * 1.2
				p.Size = V3(s, s, s) * k
				p.CFrame = c0 + d * ease(a, ES.Quad, ED.Out)
				p.Transparency = 0.3 + 0.7 * a
			end, nil, function()
				p:Destroy()
			end)
		end
	end)
	fx.sparks = safe(function(pos, n, color)
		CartoonFX.sparks(W(S, pos), n or 16, color or S.col)
	end)
	fx.confetti = safe(function(pos, n, colors, spread, up)
		S:confetti(W(S, pos), n or 24, colors or { S.rc, S.col, WHITE, C3(255, 220, 60) }, spread or 5, up or 8)
	end)
	fx.money = safe(function(pos, dur, count)
		local c = W(S, pos or CFn(0, 3, 0))
		local floorY = S.O.Position.Y
		count = math.clamp(count or 40, 1, 120)
		dur = dur or 2.5
		for i = 1, count do
			R.delay((i / count) * dur, function()
				local start = c + V3(rng:NextNumber(-9, 9), rng:NextNumber(12, 18), rng:NextNumber(-7, 7))
				local b = R.prop("Bill", CFn(start - S.O.Position))
				local fall = rng:NextNumber(1.6, 2.6)
				local ph = rng:NextNumber(0, 6)
				local yEnd = floorY + 0.05
				S:mover(fall, function(a)
					local p = start:Lerp(V3(start.X, yEnd, start.Z), ease(a, ES.Sine, ED.In)) + V3(math.sin(a * 8 + ph) * 0.8, 0, math.cos(a * 6 + ph) * 0.5)
					b:PivotTo(CFn(p) * ANG(math.sin(a * 9 + ph) * (1 - a) * 0.9, a * 5 + ph, math.cos(a * 7) * (1 - a) * 0.7))
				end, nil, function()
					task.delay(1.2, function()
						b:Destroy()
					end)
				end)
			end)
		end
		return dur
	end)
	fx.coins = safe(function(pos, n)
		local base = W(S, pos)
		local floorY = S.O.Position.Y
		for _ = 1, n or 14 do
			local c = R.prop("Coin", CFn(base - S.O.Position), { size = rng:NextNumber(0.8, 1.3) })
			local d = V3(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)).Unit * rng:NextNumber(2, 6)
			local up = rng:NextNumber(4, 9)
			local t = rng:NextNumber(0.8, 1.2)
			local spin = rng:NextNumber(10, 20)
			S:mover(t, function(a)
				local y = base.Y + up * math.sin(a * PI * 0.85) - (base.Y - floorY) * a * a
				c:PivotTo(CFn(base.X + d.X * a, math.max(y, floorY), base.Z + d.Z * a) * ANG(0, a * spin, 0))
			end, nil, function()
				task.delay(0.8, function()
					c:Destroy()
				end)
			end)
		end
	end)
	fx.hearts = safe(function(pos, n, color)
		floaters(pos, n or 12, function()
			local cols = { C3(255, 70, 120), C3(255, 120, 170), C3(255, 50, 80) }
			return R.prop("Heart", CFn(0, -50, 0), { color = color or cols[rng:NextInteger(1, 3)], size = rng:NextNumber(0.6, 1.2) })
		end, 1.8, 7, 2.5, 0)
	end)
	fx.bubbles = safe(function(pos, n, size)
		floaters(pos, n or 12, function()
			local d = (size or 1.2) * rng:NextNumber(0.6, 1.4)
			local cols = { C3(190, 235, 255), C3(255, 200, 250), C3(200, 255, 220) }
			return S:part({ Shape = Enum.PartType.Ball, Size = V3(d, d, d), CFrame = CFn(0, -50, 0), Color = cols[rng:NextInteger(1, 3)], Material = Enum.Material.Glass, Transparency = 0.35, CanQuery = false, CastShadow = false })
		end, 2.4, 6, 3, 0)
	end)
	fx.fire = safe(function(posOrPart, dur, color, size)
		local host = posOrPart
		if typeof(host) ~= "Instance" or not host:IsA("BasePart") then
			host = S:part({ Size = V3(0.5, 0.5, 0.5), CFrame = CFn(W(S, posOrPart)), Transparency = 1, CanQuery = false })
		end
		local f = Instance.new("Fire")
		f.Color = color or C3(255, 130, 30)
		f.SecondaryColor = C3(255, 230, 120)
		f.Size = size or 6
		f.Heat = 12
		f.Parent = host
		local l = S:light(host, color or C3(255, 140, 40), 16, 3)
		if dur then
			task.delay(dur, function()
				f.Enabled = false
				if l.Parent then
					l:Destroy()
				end
			end)
		end
		return f
	end)
	fx.explosion = safe(function(pos, size, color)
		local p = W(S, pos)
		size = size or 1
		CartoonFX.bigImpact(p, V3(0, 1, 0), 1.2 * size, color or C3(255, 150, 40))
		CartoonFX.sparks(p, math.floor(24 * size), color or C3(255, 200, 80))
		CartoonFX.light(p, color or C3(255, 160, 60), 30 * size, 6, 0.4)
		CartoonFX.shockwave(p, 8 * size, color or C3(255, 180, 80))
		fx.smoke(R.loc(p), math.floor(8 * size), C3(90, 90, 100), 2.5 * size)
	end)
	fx.lightning = safe(function(from, to, color)
		local p0, target = W(S, from), W(S, to)
		for i = 1, 6 do
			local p1 = p0:Lerp(target, 1 / (7 - i)) + (i < 6 and V3(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5)) or Vector3.zero)
			CartoonFX.beam(p0, p1, 0.8, color or C3(200, 230, 255), 0.35)
			p0 = p1
		end
		CartoonFX.light(target, color or C3(200, 230, 255), 30, 6, 0.3)
	end)
	fx.beam = safe(function(from, to, width, color, dur)
		CartoonFX.beam(W(S, from), W(S, to), width or 1, color or S.col, dur or 0.4)
	end)
	fx.shockwave = safe(function(pos, radius, color)
		CartoonFX.shockwave(W(S, pos), radius or 10, color or S.rc)
	end)
	fx.ring = safe(function(pos, dir, size, color)
		CartoonFX.airRing(W(S, pos), dir or V3(0, 1, 0), size or 4, color or WHITE, 0.4)
	end)
	fx.bigImpact = safe(function(pos, dir, power, color)
		CartoonFX.bigImpact(W(S, pos), dir or V3(0, 0, -1), power or 1.2, color or S.col)
	end)
	fx.flash = safe(function(color, inT, hold, outT)
		S:flash(color or WHITE, inT, hold, outT)
	end)
	fx.impact = safe(function(strength)
		CartoonFX.impactFrame(strength or 0.7)
	end)
	fx.word = safe(function(text, pos, power, cat)
		S:word(text, pos and W(S, pos) or (S.root.Position + V3(0, 3.5, 0)), power or 1.2, cat or "Heavy")
	end)
	fx.banner = safe(function(text, o)
		o = o or {}
		local l = UITheme.label({ Name = "Banner", Text = text, TextColor3 = o.color or WHITE, AnchorPoint = V2(0.5, 0.5), Position = UDim2.fromScale(0.5, o.y or 0.42), Size = UDim2.fromScale(0.9, o.size or 0.18), ZIndex = 40, Stroke = 6 })
		local sc = Instance.new("UIScale")
		sc.Scale = 0.2
		sc.Parent = l
		l.Parent = S.gui
		TweenService:Create(sc, TweenInfo.new(0.16, ES.Back, ED.Out), { Scale = 1 }):Play()
		local life = o.t or 0.8
		task.delay(life, function()
			if l.Parent then
				TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1.4 }):Play()
				TweenService:Create(l, TweenInfo.new(0.12), { TextTransparency = 1 }):Play()
				Debris:AddItem(l, 0.15)
			end
		end)
		return l
	end)
	fx.rain = safe(function(spec, dur)
		S:rain(spec, dur)
	end)
	fx.rays = safe(function(color, pos)
		local folder = Instance.new("Folder")
		folder.Name = "Rays"
		folder.Parent = S.set
		local n = 12
		local parts = {}
		for i = 1, n do
			local p = S:part({ Size = V3((i % 2 == 0) and 0.7 or 0.4, 26, 0.05), Color = color or S.rc, Material = Enum.Material.Neon, Transparency = 1, CanQuery = false }, folder)
			parts[i] = p
			S:tween(p, 0.6, { Transparency = (i % 2 == 0) and 0.72 or 0.82 })
		end
		local center = pos and W(S, pos) or (S.heroCF * CFn(0, 1.2, 3.5)).Position
		local spin = 0
		table.insert(S.conns, RunService.RenderStepped:Connect(function(dt)
			if not folder.Parent then
				return
			end
			spin += dt * 0.35
			local c = CFrame.lookAt(center, workspace.CurrentCamera.CFrame.Position)
			for i, p in ipairs(parts) do
				p.CFrame = c * ANG(0, 0, spin + i * 2 * PI / n) * CFn(0, 13.5, 0)
			end
		end))
		return folder
	end)
	fx.glitch = safe(function()
		for i = 1, 6 do
			S:delay(i * 0.06, function()
				S:glitchBars()
			end)
		end
		S:cubes(S.root.Position, 14, { C3(0, 255, 200), C3(255, 0, 200) }, 2.2)
	end)
	fx.speedLines = safe(function(dur, color)
		CartoonFX.speedLines(dur or 0.5, color or S.rc)
	end)
	fx.dust = safe(function(pos, radius)
		CartoonFX.dust(W(S, pos), radius or 5)
	end)
	fx.puff = safe(function(pos, size)
		CartoonFX.puff(W(S, pos), size or 2)
	end)
	fx.implode = safe(function(pos, radius, colors)
		CartoonFX.implode(W(S, pos), radius or 7, colors or { S.col, WHITE }, 14, 0.35)
	end)
	fx.swirl = safe(function(pos, radius, height, colors)
		CartoonFX.swirl(W(S, pos), radius or 4, height or 6, colors or { S.col, WHITE }, 16, 0.8)
	end)
	fx.pillar = safe(function(pos, radius, height, color)
		CartoonFX.pillar(W(S, pos), radius or 3, height or 14, color or S.col, 0.5)
	end)
	fx.quake = safe(function(pos, radius, color)
		CartoonFX.quake(W(S, pos), radius or 12, color or S.rc, 1.2)
	end)
	fx.shards = safe(function(pos, n, colors)
		CartoonFX.shards(W(S, pos), n or 14, colors or { S.rc, WHITE }, 1.2)
	end)
	fx.debris = safe(function(pos, n, colors)
		CartoonFX.debris(W(S, pos), n or 10, colors or { C3(120, 120, 130) }, 1, 0.6)
	end)
	fx.light = safe(function(pos, color, range, bright, dur)
		CartoonFX.light(W(S, pos), color or S.col, range or 24, bright or 5, dur or 0.4)
	end)
	fx.trail = safe(function(part, color, dur)
		CartoonFX.trailOn(part, color or S.col, dur or 1)
	end)
	fx.fireworks = safe(function(pos, n)
		local c = W(S, pos or CFn(0, 14, 8))
		for i = 1, n or 5 do
			S:delay(i * 0.14, function()
				local p = c + V3(rng:NextNumber(-10, 10), rng:NextNumber(-3, 3), rng:NextNumber(-3, 3))
				local col = Color3.fromHSV(rng:NextNumber(), 0.7, 1)
				pcall(CartoonFX.sparks, p, 30, col)
				pcall(CartoonFX.light, p, col, 30, 4, 0.4)
				S:confetti(p, 10, { col, WHITE }, 8, 3)
			end)
		end
	end)
	fx.twinkle = safe(function(pos)
		CartoonFX.twinkle(W(S, pos))
	end)
	local function grade(prop, value, t)
		local v0 = S.cc[prop]
		if not t or t <= 0 then
			S.cc[prop] = value
			return 0
		end
		return S:mover(t, function(a)
			S.cc[prop] = lerpAny(v0, value, ease(a))
		end, "cc" .. prop)
	end
	fx.tint = function(color, t)
		return grade("TintColor", color or WHITE, t)
	end
	fx.dark = function(amount, t)
		return grade("Brightness", -(amount or 0.5) * 0.6, t)
	end
	fx.saturation = function(x, t)
		return grade("Saturation", x or 0.12, t)
	end
	fx.contrast = function(x, t)
		return grade("Contrast", x or 0.08, t)
	end

	-- son et bandeaux
	function R.sound(key, pos, vol, pitch)
		local p = pos and W(S, pos) or nil
		if type(key) == "number" or (type(key) == "string" and key:find("rbxassetid")) then
			local s = Instance.new("Sound")
			s.SoundId = type(key) == "number" and ("rbxassetid://" .. key) or key
			s.Volume = vol or 0.8
			s.PlaybackSpeed = pitch or 1
			s.Parent = S.sandbox
			s:Play()
			Debris:AddItem(s, 15)
			return s
		end
		local ok, s = pcall(CartoonFX.sound, key, p or (S.heroCF and S.heroCF.Position), vol or 0.8)
		if ok and s and pitch then
			s.PlaybackSpeed = pitch
		end
		return ok and s or nil
	end
	function R.caption(text)
		S:setLower(text)
	end
	function R.location(text)
		S:setLocation(text)
	end
	return R, ctx
end

-- état final quand le joueur passe une chorégraphie
function Engine.skipTableau(S)
	S.gen += 1
	S.movers = {}
	S.timeScale = 1
	S.frozenUntil = 0
	S.camRoll = 0
	S.token += 1
	S:flash(WHITE, 0.02, 0.04, 0.35)
	local R = S.R
	local done = false
	if type(S.onSkip) == "function" and R then
		local ok, err = pcall(S.onSkip, R)
		if ok then
			done = true
		elseif err ~= SKIP then
			warn("[SkinReveal] onSkip", S.id, err)
		end
	end
	if not done then
		S.root.CFrame = S.heroCF
		S:alpha(1)
		S:playTrack(POSE_HOLD.Hero, 1)
		if R then
			R.cam.hero(0)
		end
	end
end

-- erreur dans un script : on vide la scène et on joue une révélation générique
function Engine.fallback(S)
	S.gen += 1
	S.movers = {}
	S.timeScale = 1
	S.frozenUntil = 0
	S.camRoll = 0
	for obj in pairs(S.attached) do
		pcall(function()
			obj:Destroy()
		end)
	end
	S.attached, S.held = {}, {}
	for _, ch in ipairs(S.set:GetChildren()) do
		if ch ~= S.rig then
			ch:Destroy()
		end
	end
	for _, e in ipairs(S.lfx) do
		pcall(function()
			e:Destroy()
		end)
	end
	S.cc.Brightness, S.cc.Contrast, S.cc.Saturation, S.cc.TintColor = 0, 0.08, 0.12, WHITE
	S.heroCF = S:at(0, 3, 0)
	S.scene = SCENES.Spotlight
	S.scene.build(S)
	S.root.CFrame = S.heroCF
	S.rig:SetAttribute("Transformed", false)
	S:alpha(1)
	hero(S, true)
end

------------------------------------------------------------------------
-- DEMO REVEALS — deux chorégraphies Legendary de référence (exemples pour les agents des packs).
-- Jouables : SkinRevealDebug:Fire("demo", "RocketMogul") ; utilisées pour CEO_Legendary / Intern_Legendary
-- tant que leur pack ne définit pas de Reveal.
------------------------------------------------------------------------
DemoReveals.RocketMogul = function(R, ctx)
	local C, V, CF, A = Color3.fromRGB, Vector3.new, CFrame.new, CFrame.Angles
	local ES_, ED_ = Enum.EasingStyle, Enum.EasingDirection
	R.stage("Night")
	R.location("Launch Pad 9 - Corporate Rooftop")
	-- décor : aire de lancement, tour, projecteurs qui balaient le ciel
	R.cyl(0.4, 24, V(0, 0.2, 10), C(70, 74, 90), "Concrete")
	R.cyl(0.42, 16, V(0, 0.21, 10), C(255, 200, 40))
	R.cyl(0.44, 14, V(0, 0.22, 10), C(55, 58, 72), "Concrete")
	for _, x in ipairs({ -9, 9 }) do
		R.box(V(1.6, 24, 1.6), CF(x, 12, 12), C(205, 60, 50), "Metal")
		for y = 3, 21, 6 do
			R.box(V(0.3, 0.3, 8), CF(x, y, 9), C(160, 160, 170), "Metal")
		end
		local beacon = R.ball(0.8, V(x, 24.6, 12), C(255, 40, 40), "Neon")
		R.every(0.5, function(i)
			beacon.Transparency = (i % 2 == 0) and 0 or 0.8
		end)
	end
	local beamA = R.spot(V(-16, 0.5, -4), V(-6, 40, 30), { color = C(190, 210, 255), width = 3, on = true, brightness = 0 })
	local beamB = R.spot(V(16, 0.5, -4), V(6, 40, 30), { color = C(190, 210, 255), width = 3, on = true, brightness = 0 })
	R.every(1.1, function(i)
		local s = (i % 2 == 0) and 1 or -1
		beamA.aim(V(-6 + 10 * s, 40, 30), 1.1)
		beamB.aim(V(6 - 10 * s, 40, 30), 1.1)
	end)
	local logo = R.prop("Sign", CF(-14, 0, 6) * A(0, 0.5, 0), { text = "MOGUL AEROSPACE", w = 9, h = 2, y = 3, color = C(25, 25, 40), textColor = C(255, 200, 40) })
	local _ = logo
	-- la fusée descend du ciel, le héros est caché dedans
	local rocket = R.prop("Rocket", CF(0, 70, 10), { color = C(245, 245, 250), accent = C(220, 45, 50) })
	local flame, core, hatch, door = rocket.Flame, rocket.FlameCore, rocket.Hatch, rocket.Door
	R.tween(flame, 0.01, { Transparency = 0.15 })
	R.tween(core, 0.01, { Transparency = 0.05 })
	R.alpha(0)
	R.place(CF(0, 4.2, 9.8)) -- caché dans le corps de la fusée
	local flag
	R.onSkip(function(R2)
		-- tableau final si le joueur passe : fusée partie, drapeau planté, salut
		rocket:PivotTo(R2.at(0, 300, 10))
		R2.place(CF(0, 3, 0))
		R2.alpha(1)
		flag = flag or R2.prop("Flag", CF(1.5, -0.6, -1), { text = "MINE", color = C(220, 45, 50) })
		R2.moveTo(flag, CF(1.5, -0.6, -1), 0)
		R2.pose("Salute")
		R2.cam.hero()
	end)

	-- BEAT 1 : atterrissage dans la fumée (plan large en contre-plongée qui suit la fusée)
	R.sound("Rumble", nil, 1)
	R.cam.cut(V(7, 1.4, -18), V(0, 40, 10), 58)
	R.cam.track(2.4, function(a)
		local rp = R.pos(rocket)
		return V(7 - a * 2, 1.4, -18 + a * 2), rp + V(0, 5 - a * 2, 0), 58 - a * 12
	end)
	local descending = true
	R.spawn(function()
		while descending do
			R.fx.smoke(R.pos(rocket) + V(0, -2.5, 0), 2, C(235, 225, 210), 1.8)
			R.wait(0.09)
		end
	end)
	R.moveTo(rocket, CF(0, 0, 10), 2.4, ES_.Quart, ED_.Out)
	R.wait(1.7)
	R.fx.smoke(V(0, 0.5, 10), 8, C(230, 230, 236), 2.6)
	R.wait(0.7)
	descending = false
	R.sound("GroundSlam")
	R.sound("Explosion", nil, 0.5)
	R.cam.shake(0.8)
	R.cam.punch(8)
	R.fx.smoke(V(-3.5, 0.6, 10), 7, C(225, 225, 232), 2.6)
	R.fx.smoke(V(3.5, 0.6, 10), 7, C(225, 225, 232), 2.6)
	R.fx.dust(V(0, 0.2, 10), 12)
	R.fx.shockwave(V(0, 0.3, 10), 16, C(255, 210, 140))
	R.tween(flame, 0.5, { Transparency = 1 })
	R.tween(core, 0.4, { Transparency = 1 })
	R.wait(0.35)

	-- BEAT 2 : la trappe s'abat en rampe, lumière dorée, il sort en se pavanant
	local P = rocket:GetPivot()
	local hingeRel = CF(0, 1.2, -2.45)
	local hatchRel = P:ToObjectSpace(hatch.CFrame)
	R.cam.pushIn(V(0, 4.5, 7.5), 15, 9, 1.4, { height = 0.4, yaw = -0.3, fov = 44 })
	R.sound("Clang")
	R.over(0.6, function(_, e)
		hatch.CFrame = P * hingeRel * A(-1.79 * e, 0, 0) * hingeRel:Inverse() * hatchRel
	end, ES_.Bounce, ED_.Out)
	R.fx.smoke(V(-1.8, 1.5, 7.2), 2, C(255, 255, 255), 1)
	R.fx.smoke(V(1.8, 1.5, 7.2), 2, C(255, 255, 255), 1)
	R.wait(0.45)
	door.Color = C(255, 196, 110)
	R.tween(door, 0.2, { Transparency = 0.35 })
	R.light(door, C(255, 210, 140), 18, 2.5)
	R.sound("PowerUp", nil, 0.6)
	R.place(CF(0, 4.2, 7.4)) -- dans l'encadrement de la porte
	R.alpha(1, 0.25)
	R.pose("HandsHips")
	R.wait(0.55)
	R.cam.follow(R.rig, V(3.4, 0.6, -9), 1.3, { look = V(0, 0.6, 0) })
	R.walk(CF(0, 3, 0), 1.25, "Strut")
	R.wait(1.25)

	-- BEAT 3 : il plante son drapeau (ralenti + arrêt sur image à l'impact)
	flag = R.prop("Flag", CF(1.5, 1.2, -1), { text = "MINE", color = C(220, 45, 50) })
	R.fx.sparks(V(1.5, 5, -1), 14, C(255, 220, 120))
	R.cam.lowAngle(V(0.6, 3, 0), 9, 0.35)
	R.anim("FlagPlant")
	R.moveTo(flag, CF(1.5, 3.4, -1), 0.3, ES_.Back, ED_.Out)
	R.sound("Whoosh")
	R.wait(0.3)
	R.slowmo(0.3)
	R.moveTo(flag, CF(1.5, -0.6, -1), 0.16, ES_.Quad, ED_.In)
	R.wait(0.16)
	R.freeze(0.14)
	R.sound("GroundSlam")
	R.sound("MetalHit", nil, 0.7)
	R.cam.shake(1)
	R.fx.shockwave(V(1.5, 0.15, -1), 12, ctx.color)
	R.fx.quake(V(1.5, 0, -1), 10)
	R.fx.debris(V(1.5, 0.3, -1), 10)
	R.fx.word("CLAIMED!", V(1.5, 7.5, -1), 1.4, "KO")
	R.wait(0.22)
	R.slowmo(1)
	R.pose("Salute")
	R.sound("Ding")
	R.wait(0.45)

	-- BEAT 4 : décollage derrière lui, carte titre pendant que la fusée part en feu d'artifice
	R.over(0.3, function(_, e)
		hatch.CFrame = P * hingeRel * A(-1.79 * (1 - e), 0, 0) * hingeRel:Inverse() * hatchRel
	end)
	R.tween(door, 0.2, { Transparency = 1 })
	R.cam.cut(V(1.2, 1.3, -13.5), V(4.6, 4, 6), 50)
	R.cam.track(3.2, function(a)
		return V(1.2, 1.3 - a * 0.3, -13.5 - a * 2), V(4.6, 4 + a * 9, 6), 50 + a * 6
	end)
	R.wait(0.25)
	R.tween(flame, 0.1, { Transparency = 0.1 })
	R.tween(core, 0.1, { Transparency = 0 })
	R.sound("Explosion")
	R.sound("Rumble", nil, 1)
	R.fx.light(V(0, 1, 10), C(255, 170, 60), 50, 8, 0.8)
	R.fx.tint(C(255, 228, 200), 0.3)
	R.cam.shake(1.1)
	R.fx.smoke(V(-3, 0.5, 10), 9, C(235, 230, 225), 3)
	R.fx.smoke(V(3, 0.5, 10), 9, C(235, 230, 225), 3)
	local rising = true
	R.spawn(function()
		while rising do
			R.fx.smoke(R.pos(rocket) + V(0, -2, 0), 2, C(240, 220, 200), 2)
			R.wait(0.08)
		end
	end)
	R.moveTo(rocket, CF(0, 150, 10), 3.4, ES_.Quad, ED_.In)
	R.wait(0.9)
	R.title()
	R.wait(1.3)
	R.fx.fireworks(V(4, 26, 14), 6)
	R.sound("Explosion", nil, 0.4)
	R.wait(1.0)
	rising = false
end

DemoReveals.LivestreamLegend = function(R, ctx)
	local C, V, CF, A = Color3.fromRGB, Vector3.new, CFrame.new, CFrame.Angles
	R.stage("Room", { dark = true, color = C(40, 36, 60), floor = C(52, 40, 74), w = 40, d = 52, h = 15 })
	R.location("Bedroom Studio - 3:00 AM")
	R.mark(CF(0, 3, -1.5))
	-- décor : mur néon, bureau, 3 écrans, bande RGB, chaise gamer, ring light, drone caméra
	R.box(V(22, 15, 0.5), CF(0, 7.5, 8.5), C(28, 24, 44))
	for i = 1, 6 do
		local hex = R.ball(1.1, V(-9 + i * 2.6, 9 + (i % 2) * 1.6, 8.2), Color3.fromHSV(i / 6, 0.8, 1), "Neon", 0.6)
		R.every(0.25, function(k)
			hex.Color = Color3.fromHSV(((i + k) % 12) / 12, 0.8, 1)
		end)
	end
	local onAir = R.box(V(5, 1.4, 0.3), CF(0, 12, 8.1), C(60, 10, 14), "Neon")
	local onAirLbl = R.text(onAir, "ON AIR", { Color = C(255, 230, 230) })
	onAirLbl.TextTransparency = 0.7
	R.prop("Desk", CF(0, 0, 5), { color = C(30, 30, 36) })
	local screens, labels = {}, {}
	for i, x in ipairs({ 3.8, 0, -3.8 }) do -- (de gauche à droite à l'écran)
		local m, l = R.prop("Monitor", CF(x, 2.75, 5.2) * A(0, x * 0.1, 0), { color = C(8, 8, 14), text = "" })
		screens[i], labels[i] = m.Screen, l
	end
	local glow = R.light(V(0, 4, 3.5), C(90, 150, 255), 18, 0)
	local strip = R.box(V(11, 0.15, 0.15), CF(0, 2.42, 3.45), C(255, 0, 150), "Neon")
	R.every(0.06, function(k)
		strip.Color = Color3.fromHSV((k * 0.03) % 1, 1, 1)
	end)
	local chair = R.prop("GamingChair", CF(0, 0, 1.6) * A(0, math.pi, 0), { accent = C(0, 255, 200) })
	local ring = R.prop("RingLight", CF(-6, 0, 1.5) * A(0, -1.1, 0))
	local leds = {}
	for _, p in ipairs(ring:GetChildren()) do
		if p.Name:sub(1, 3) == "Led" then
			p.Transparency = 0.85
			table.insert(leds, p)
		end
	end
	local drone = R.prop("Drone", CF(5, 6.5, -4) * A(0, 0.6, 0))
	R.every(0.4, function(k)
		drone.Rec.Transparency = (k % 2 == 0) and 0 or 0.9
	end)
	R.every(0.05, function(k)
		for i = 1, 4 do
			local r = drone:FindFirstChild("Rotor" .. i)
			if r then
				r.CFrame = r.CFrame * A(k * 0.9, 0, 0)
			end
		end
	end)
	-- le héros assis dos à la caméra, il tape au clavier
	local seatedTyping = { { t = 0 } }
	for k = 1, 30 do
		local s = (k % 2 == 0) and 1 or -1
		table.insert(seatedTyping, { t = k * 0.085, RS = { p = 1.35 + 0.12 * s, r = -0.15 }, LS = { p = 1.35 - 0.12 * s, r = -0.15 }, RJ = { ln = 0.12 }, RH = { p = 1.57 }, LH = { p = 1.57 } })
	end
	R.place(CF(0, 3.45, 1.6) * A(0, math.pi, 0))
	R.anim(seatedTyping)
	local function lightsOn()
		R.fx.dark(0, 0.25)
		R.fx.contrast(0.1, 0.25)
		for _, p in ipairs(leds) do
			p.Transparency = 0
		end
		onAir.Color = C(255, 40, 60)
		onAirLbl.TextTransparency = 0
		glow.Brightness = 3
	end
	R.onSkip(function(R2)
		lightsOn()
		for i, s in ipairs(screens) do
			s.Color = C(40, 90, 220)
			labels[i].Text = i == 2 and "1,000,000" or "LIVE"
		end
		chair:PivotTo(R2.at(0.6, 0, 3.4))
		R2.place(CF(0, 3, -1.5))
		R2.pose("Victory")
		R2.cam.hero()
	end)

	-- BEAT 1 : nuit noire, les écrans clignotent et s'allument un à un (travelling derrière la chaise)
	R.cam.cut(V(-3, 6.4, -8), V(0, 4, 5), 48)
	R.cam.dolly(V(-3, 6.4, -8), V(2.6, 5.8, -6), V(0, 4, 5), 2.3, 42)
	R.wait(0.35)
	for i, s in ipairs(screens) do
		for k = 1, 3 do
			s.Color = (k % 2 == 1) and C(60, 120, 255) or C(8, 8, 14)
			R.sound("Electric", nil, 0.25)
			R.wait(0.05)
		end
		s.Color = C(40, 90, 220)
		labels[i].Text = ({ "CHAT", "STARTING...", "0 VIEWERS" })[i]
		glow.Brightness = i
		R.sound("UIClick", nil, 0.5)
		R.wait(0.33)
	end
	R.wait(0.2)

	-- BEAT 2 : compte à rebours, la lumière s'allume, la chaise pivote vers la caméra (whip-pan)
	for n = 3, 1, -1 do
		labels[2].Text = tostring(n)
		R.fx.banner(tostring(n), { t = 0.3, color = C(255, 255, 255), size = 0.22 })
		R.sound("UIClick", nil, 0.8)
		R.wait(0.42)
	end
	labels[2].Text = "LIVE"
	labels[1].Text = "HYPE!!"
	labels[3].Text = "12,408 VIEWERS"
	R.fx.banner("GOING LIVE!", { t = 0.7, color = C(255, 60, 90) })
	R.sound("PowerUp")
	lightsOn()
	R.fx.flash(C(255, 240, 255), 0.03, 0.03, 0.3)
	R.pose({ RS = { p = 0.5, r = 0.3 }, LS = { p = 0.5, r = 0.3 }, RJ = { ln = -0.1 }, RH = { p = 1.57 }, LH = { p = 1.57 } })
	R.spin(chair, 1.5, 0.85)
	R.spin(R.rig, 1.5, 0.85)
	R.sound("Whoosh")
	R.wait(0.45)
	R.cam.whip(V(0.6, 4.1, -7.6), V(0, 3.9, 1.6), 0.2)
	R.wait(0.4)
	R.pose({ RS = { p = 2.6, y = 1.2, r = -0.45 }, LS = { p = 0.6, r = 0.3 }, RJ = { ln = -0.12 }, RH = { p = 1.57 }, LH = { p = 1.57 } })
	R.sound("Ding")
	R.wait(0.35)

	-- BEAT 3 : il bondit de la chaise, le chat explose (coeurs, messages, drone en orbite, ralenti)
	R.jump(R.rig, CF(0, 3, -1.5), 0.5, 2.6)
	R.moveTo(chair, V(0.6, 0, 3.4), 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	R.sound("Boing")
	R.wait(0.5)
	R.cam.shake(0.4)
	R.slowmo(0.4, 1.4)
	R.cam.orbit(V(0, 3.6, -1.5), 9.5, 1.0, -1.0, 0.85, 2.4, 46, 40)
	R.fly(drone, { V(3, 6, -6), V(0, 6.8, -7.5), V(-4, 6.2, -5), V(-5, 6, -1), V(-2, 7, 1) }, 2.6, { face = true })
	R.anim("Wave")
	local msgs = { "W", "POG", "LETS GOOO", "+1 SUB", "GOAT", "CLIP IT!", "<3 <3 <3", "1M HYPE" }
	R.spawn(function()
		for i, m in ipairs(msgs) do
			local x = (i % 2 == 0) and R.rand(2.5, 5) or R.rand(-5, -2.5)
			local g, anchor = R.billboard(m, V(x, R.rand(3, 5), R.rand(-1, 3)), { size = 1.1, Color = Color3.fromHSV(R.rand(), 0.6, 1) })
			local _g = g
			R.moveTo(anchor, R.pos(anchor) + V(0, 5, 0), 1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
			R.delay(1.6, function()
				anchor:Destroy()
			end)
			R.fx.hearts(V(R.rand(-3, 3), 3.5, 4.5), 4)
			R.sound("Pickup", nil, 0.3)
			R.wait(0.16)
		end
	end)
	R.wait(1.6)

	-- BEAT 4 : le compteur passe 1 000 000, confettis, pose de victoire, carte titre
	R.cam.pushIn(V(0, 4, -1.5), 12, 9.5, 1.2, { height = 0.6, yaw = 0.15, fov = 42 })
	R.pose("Point")
	local subs = 999990
	for _ = 1, 10 do
		subs += 1
		labels[2].Text = string.format("%d,%03d,%03d", subs // 1000000, (subs // 1000) % 1000, subs % 1000)
		R.sound("UIClick", nil, 0.4)
		R.wait(0.06)
	end
	R.fx.banner("1,000,000 SUBS!", { t = 0.9, color = C(255, 215, 60) })
	R.sound("Explosion", nil, 0.5)
	R.sound("LevelUp")
	R.fx.confetti(V(-5, 0.5, 0), 30, nil, 3, 12)
	R.fx.confetti(V(5, 0.5, 0), 30, nil, 3, 12)
	R.fx.hearts(V(0, 3, -1.5), 18)
	R.fx.shockwave(V(0, 0.2, -1.5), 14, ctx.rarityColor)
	R.fx.word("GO LIVE!", V(0, 7, -1.5), 1.4, "KO")
	R.pose("Victory")
	R.cam.hero(0.5)
	R.wait(0.6)
	R.title({ push = true })
	R.every(0.5, function()
		R.fx.hearts(V(R.rand(-4, 4), 2, R.rand(-2, 3)), 3)
	end)
	R.wait(1.5)
end
-- test du repli sur erreur (SkinRevealDebug:Fire("demo", "_ErrorTest")) : doit avertir puis jouer une révélation générique
DemoReveals._ErrorTest = function(R)
	R.stage("Studio")
	R.prop("Crate", CFrame.new(3, 0, 2))
	R.wait(0.4)
	error("_ErrorTest : erreur volontaire")
end
local DEMO_FOR_SKIN = { CEO_Legendary = "RocketMogul", Intern_Legendary = "LivestreamLegend" }
SkinRevealController.DemoReveals = {}
for name in pairs(DemoReveals) do
	if string.sub(name, 1, 1) ~= "_" then
		table.insert(SkinRevealController.DemoReveals, name)
	end
end

------------------------------------------------------------------------
-- Construction : GUI, perso, décor
------------------------------------------------------------------------
local function buildGui(S)
	local pg = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "SkinRevealGui"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 250
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local btn = Instance.new("TextButton")
	btn.Name = "Skip"
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.Modal = true
	btn.ZIndex = 1
	btn.Parent = gui
	btn.Activated:Connect(function()
		S:skip()
	end)
	local function bar(name, y)
		return UITheme.new("Frame", { Name = name, AnchorPoint = V2(0, y), Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, 0), BackgroundColor3 = BLACK, BorderSizePixel = 0, ZIndex = 10, Parent = gui })
	end
	S.topBar = bar("Top", 0)
	S.botBar = bar("Bottom", 1)
	S.locLbl = UITheme.label({ Name = "Location", Body = true, Text = "", TextColor3 = UITheme.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = V2(0, 0.5), Position = UDim2.new(0.03, 0, 0.5, 0), Size = UDim2.new(0.6, 0, 0.34, 0), ZIndex = 11, Stroke = false, MaxText = 26 })
	S.locLbl.Parent = S.topBar
	local rec = UITheme.label({ Name = "Rec", Body = true, Text = S.label, TextColor3 = S.rc, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = V2(1, 0.5), Position = UDim2.new(0.97, 0, 0.5, 0), Size = UDim2.new(0.25, 0, 0.34, 0), ZIndex = 11, Stroke = false, MaxText = 26 })
	rec.Parent = S.topBar
	S.lowLbl = UITheme.label({ Name = "Lower", Body = true, Text = "", TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Left, AnchorPoint = V2(0, 0.5), Position = UDim2.new(0.03, 0, 0.5, 0), Size = UDim2.new(0.6, 0, 0.34, 0), ZIndex = 11, Stroke = false, MaxText = 26 })
	S.lowLbl.Parent = S.botBar
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	S.hintLbl = UITheme.label({ Name = "Hint", Body = true, Text = touchOnly and "TAP TO SKIP" or "CLICK TO SKIP", TextColor3 = UITheme.Colors.Muted, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = V2(1, 0.5), Position = UDim2.new(0.97, 0, 0.5, 0), Size = UDim2.new(0.3, 0, 0.3, 0), ZIndex = 11, Stroke = false, MaxText = 22 })
	S.hintLbl.Parent = S.botBar
	S.cardRoot = UITheme.new("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20, Parent = gui })
	S.flashF = UITheme.new("Frame", { Name = "Flash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 55, Parent = gui })
	S.fade = UITheme.new("Frame", { Name = "Fade", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = 60, Parent = gui })
	gui.Parent = pg
	S.gui = gui
end

local function buildRig(S)
	local model = Instance.new("Model")
	model.Name = "RevealRig"
	local skinTone = C3(255, 204, 153)
	local function limb(name, size, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	local shirt = typeof(S.charDef.Shirt) == "Color3" and S.charDef.Shirt or C3(200, 200, 210)
	local pants = typeof(S.charDef.Pants) == "Color3" and S.charDef.Pants or C3(80, 90, 115)
	local root = limb("HumanoidRootPart", V3(2, 2, 1), WHITE)
	root.Transparency = 1
	root.Anchored = true
	root.Massless = false
	root.CFrame = S.startCF
	local torso = limb("Torso", V3(2, 2, 1), shirt)
	local head = limb("Head", V3(2, 1, 1), skinTone)
	local rarm = limb("Right Arm", V3(1, 2, 1), shirt)
	local larm = limb("Left Arm", V3(1, 2, 1), shirt)
	local rleg = limb("Right Leg", V3(1, 2, 1), pants)
	local lleg = limb("Left Leg", V3(1, 2, 1), pants)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = V3(1.25, 1.25, 1.25)
	mesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Face = Enum.NormalId.Front
	face.Texture = "rbxasset://textures/face.png"
	face.Parent = head
	local function motor(name, p0, p1, c0, c1)
		p1.CFrame = p0.CFrame * c0 * c1:Inverse()
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0 = p0
		m.Part1 = p1
		m.C0 = c0
		m.C1 = c1
		m.Parent = p0
		return m
	end
	local RJ = CFn(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	motor("RootJoint", root, torso, RJ, RJ)
	motor("Neck", torso, head, CFn(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0), CFn(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0))
	motor("Right Shoulder", torso, rarm, CFn(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFn(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Shoulder", torso, larm, CFn(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFn(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	motor("Right Hip", torso, rleg, CFn(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0), CFn(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0))
	motor("Left Hip", torso, lleg, CFn(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0), CFn(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0))
	local hum = Instance.new("Humanoid")
	hum.RigType = Enum.HumanoidRigType.R6
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	pcall(function()
		hum.EvaluateStateMachine = false
		hum.RequiresNeck = false
		hum.BreakJointsOnDeath = false
	end)
	hum.Parent = model
	local bc = Instance.new("BodyColors")
	bc.HeadColor3, bc.LeftArmColor3, bc.RightArmColor3 = skinTone, shirt, shirt
	bc.TorsoColor3, bc.LeftLegColor3, bc.RightLegColor3 = shirt, pants, pants
	bc.Parent = model
	model.PrimaryPart = root
	model.Parent = S.set
	S.rig, S.root = model, root
	-- tenue + accessoires de métier + arme fétiche
	local ok, err = pcall(SkinBuilder.dress, model, S.def)
	if not ok then
		warn("[SkinReveal] dress", S.id, err)
	end
	if S.def.HideIdentity ~= true then
		pcall(SkinBuilder.identity, model, S.charId)
	end
	local content = S.data.Content[S.charId]
	if content and type(content.Signature) == "table" and type(content.Signature.Build) == "function" then
		local hand = content.Signature.Hand == "Left" and "Left" or "Right"
		local f = Instance.new("Folder")
		f.Name = "Signature"
		f.Parent = model
		local okS = pcall(content.Signature.Build, f, model:FindFirstChild(hand .. " Arm"), SkinBuilder.prop)
		if okS then
			S.signature, S.signatureHand = f, hand
		else
			f:Destroy()
		end
	end
	local colors = model:FindFirstChildOfClass("BodyColors")
	if colors then
		head.Color, torso.Color = colors.HeadColor3, colors.TorsoColor3
		larm.Color, rarm.Color = colors.LeftArmColor3, colors.RightArmColor3
		lleg.Color, rleg.Color = colors.LeftLegColor3, colors.RightLegColor3
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if d ~= root then
				S.vis[d] = d.Transparency
			end
			d.CanQuery = false
			d.CanCollide = false
			d.CanTouch = false
		elseif d:IsA("Decal") then
			S.visDecals[d] = d.Transparency
		elseif d:IsA("ParticleEmitter") or d:IsA("Sparkles") or d:IsA("Fire") or d:IsA("Trail") or d:IsA("Light") or d:IsA("Beam") then
			table.insert(S.fxObjs, d)
		end
	end
	ProcAnim.register(model)
end

local function setup(S)
	local d = loadData()
	S.data = d
	local def = type(d.Skins.get) == "function" and d.Skins.get(S.id) or nil
	if not def then
		local charId = tostring(S.id):match("^(%w+)_") or "Intern"
		def = { Id = tostring(S.id), Character = charId, Name = tostring(S.id), Rarity = "Rare", Outfit = {}, Parts = {} }
	end
	S.def = def
	S.charId = def.Character
	S.charDef = type(d.Characters[def.Character]) == "table" and d.Characters[def.Character] or {}
	S.rarity = def.Rarity or "Base"
	S.tier = TIER[S.rarity] or 1
	local rar = type(d.Skins.Rarities) == "table" and d.Skins.Rarities[S.rarity] or nil
	S.rc = UITheme.Rarity[S.rarity] or (rar and rar.Color) or RARITY_FALLBACK.Rare
	S.label = (rar and rar.Label) or string.upper(S.rarity)
	local R = d.Reveals
	local charE = type(R._Characters) == "table" and type(R._Characters[S.charId]) == "table" and R._Characters[S.charId] or {}
	local defE = type(R._Default) == "table" and R._Default or {}
	S.entry = type(R[S.id]) == "table" and R[S.id] or {}
	-- v2 : chorégraphie scriptée ? (opts.demo > Reveal de l'entrée > démo de référence du skin)
	local rv = S.entry.Reveal
	if type(S.opts.demo) == "string" and DemoReveals[S.opts.demo] then
		rv = DemoReveals[S.opts.demo]
	elseif type(rv) ~= "function" and type(rv) ~= "table" and DEMO_FOR_SKIN[S.id] and not S.opts.scene then
		rv = DemoReveals[DEMO_FOR_SKIN[S.id]]
	end
	if S.opts.scene then
		rv = nil -- scène forcée = flux générique
	end
	if type(rv) == "function" or type(rv) == "table" then
		S.reveal = rv
	end
	S.sceneName = S.opts.scene or S.entry.Scene or charE.Scene or defE.Scene or "Cubicle"
	if not SCENES[S.sceneName] then
		warn("[SkinReveal] scène inconnue", S.sceneName)
		S.sceneName = "Cubicle"
	end
	S.scene = SCENES[S.sceneName]
	local atks = type(S.charDef.Attacks) == "table" and S.charDef.Attacks or {}
	S.showcaseId = S.opts.showcase or S.entry.Showcase or charE.Showcase or atks[1]
	S.caption = S.entry.Caption or (S.rarity == "Base" and charE.Caption) or def.Desc or ""
	S.col = skinColor(def, S.charDef, S.entry)
	-- caméra et interface
	local cam = workspace.CurrentCamera
	S.prevCam = { type = cam.CameraType, cf = cam.CFrame, fov = cam.FieldOfView, subject = cam.CameraSubject }
	buildGui(S)
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if pg then
		for _, g in ipairs(pg:GetChildren()) do
			if g:IsA("ScreenGui") and g ~= S.gui and g.Enabled and g.Name ~= "SpeedLines" then
				g.Enabled = false
				table.insert(S.hidden, g)
			end
		end
	end
	ContextActionService:BindActionAtPriority("SkinRevealSink", function(_, state, input)
		if state == Enum.UserInputState.Begin and SKIP_KEYS[input.KeyCode] then
			S:skip()
		end
		return Enum.ContextActionResult.Sink
	end, false, 3000, table.unpack(SINK_KEYS))
	-- éclairage du plateau (retiré à la fin)
	S.cc = Instance.new("ColorCorrectionEffect")
	S.cc.Name = "SkinRevealCC"
	S.cc.Saturation = 0.12
	S.cc.Contrast = 0.08
	S.cc.Parent = Lighting
	S.bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if S.bloom then
		S.bloomSaved = S.bloom.Intensity
		S.bloom.Intensity = math.min(S.bloom.Intensity, 0.35)
	end
	S.dof = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
	if S.dof then
		S.dofSaved = { Enabled = S.dof.Enabled, FarIntensity = S.dof.FarIntensity, NearIntensity = S.dof.NearIntensity, FocusDistance = S.dof.FocusDistance, InFocusRadius = S.dof.InFocusRadius }
		S.dof.Enabled = true
		S.dof.FarIntensity = 0.22
		S.dof.NearIntensity = 0
		S.dof.InFocusRadius = 14
	end
	-- bac à sable
	local sb = Instance.new("Folder")
	sb.Name = "_SkinRevealSandbox"
	sb.Parent = workspace
	S.sandbox, S.set = sb, sb
	S.O = CFn(ORIGIN)
	S.heroCF = S:at(0, 3, 0)
	if not S.reveal then
		S.scene.build(S)
	end
	S.startCF = S.startCF or S.heroCF
	-- accessoires propres à l'entrée (repère : sol sous le héros) — flux générique uniquement
	if type(S.entry.Props) == "table" and not S.reveal then
		local floorCF = S.heroCF * CFn(0, -3, 0)
		local anim = {}
		for _, pd in ipairs(S.entry.Props) do
			if type(pd) == "table" and typeof(pd.Size) == "Vector3" then
				local base = floorCF * (typeof(pd.Offset) == "CFrame" and pd.Offset or CFn())
				local p = S:part({ ClassName = pd.Shape == "Wedge" and "WedgePart" or "Part", Size = pd.Size, CFrame = base, Color = typeof(pd.Color) == "Color3" and pd.Color or WHITE, Material = MATS[pd.Material or ""] or Enum.Material.SmoothPlastic, Transparency = pd.Transparency or 0 })
				if pd.Shape == "Ball" or pd.Shape == "Cyl" then
					p.Shape = pd.Shape == "Ball" and Enum.PartType.Ball or Enum.PartType.Cylinder
					p.Size = pd.Size
					p.CFrame = base
				end
				if type(pd.Text) == "string" then
					S:sign(p, pd.Text, { Color = typeof(pd.TextColor) == "Color3" and pd.TextColor or nil, Face = pd.Face and Enum.NormalId[pd.Face] or nil })
				end
				if typeof(pd.Light) == "Color3" then
					S:light(p, pd.Light, 14, 2)
				end
				if pd.Spin or pd.Bob then
					table.insert(anim, { p = p, base = base, spin = pd.Spin or 0, bob = pd.Bob or 0, ph = rng:NextNumber(0, 6) })
				end
			end
		end
		if #anim > 0 then
			local t0 = os.clock()
			table.insert(S.conns, RunService.RenderStepped:Connect(function()
				local t = os.clock() - t0
				for _, a in ipairs(anim) do
					-- rotation autour de la verticale du monde (disques couchés, barres, boules...) + flottement
					a.p.CFrame = CFn(a.base.Position + V3(0, math.sin(t * 2 + a.ph) * a.bob, 0)) * ANG(0, t * a.spin, 0) * a.base.Rotation
				end
			end))
		end
	end
	if typeof(S.entry.Tint) == "Color3" and not S.reveal then
		S.cc.TintColor = S.entry.Tint
	end
	buildRig(S)
	-- caméra pilotée à chaque image (les secousses de CartoonFX s'ajoutent juste après)
	S.camCF = CFrame.lookAt(S:hl(0, 1.5, -12), S.heroCF.Position)
	S.camFov = 50
	RunService:BindToRenderStep("SkinRevealCam", Enum.RenderPriority.Camera.Value, function(dt)
		if not S.alive then
			return
		end
		S:stepMovers(dt)
		local j = S.camJob
		if j and debugPause then
			ProcAnim.freeze(S.rig, 0.1)
		elseif j then
			j.t += S:sdt(dt)
			local a = math.clamp(j.t / j.dur, 0, 1)
			if j.fn then
				local okF, cf, fov = pcall(j.fn, a, j.t)
				if okF then
					S.camCF = cf or S.camCF
					S.camFov = fov or S.camFov
				end
			else
				local e = TweenService:GetValue(a, j.style, j.dir)
				S.camCF = j.from:Lerp(j.to, e)
				S.camFov = j.fov0 + (j.fov1 - j.fov0) * e
			end
			if a >= 1 and S.camJob == j then
				S.camJob = nil
			end
		end
		S.punchV *= math.exp(-dt * 8)
		local c = workspace.CurrentCamera
		c.CameraType = Enum.CameraType.Scriptable
		c.CFrame = (S.camRoll and S.camRoll ~= 0) and (S.camCF * ANG(0, 0, S.camRoll)) or S.camCF
		c.FieldOfView = math.clamp(S.camFov - S.punchV, 8, 100)
		if S.dof and S.root then
			S.dof.FocusDistance = (S.camCF.Position - S.root.Position).Magnitude
		end
	end)
	S:tween(S.topBar, 0.4, { Size = UDim2.fromScale(1, 0.11) })
	S:tween(S.botBar, 0.4, { Size = UDim2.fromScale(1, 0.11) })
end

local function cleanup(S)
	S.alive = false
	S.token += 1
	for _, c in ipairs(S.conns) do
		pcall(function()
			c:Disconnect()
		end)
	end
	pcall(function()
		RunService:UnbindFromRenderStep("SkinRevealCam")
	end)
	pcall(function()
		ContextActionService:UnbindAction("SkinRevealSink")
	end)
	if S.sandbox then
		pcall(function()
			S.sandbox:Destroy()
		end)
	end
	if S.cc then
		S.cc:Destroy()
	end
	for _, e in ipairs(S.lfx or {}) do
		pcall(function()
			e:Destroy()
		end)
	end
	if S.bloom and S.bloomSaved then
		S.bloom.Intensity = S.bloomSaved
	end
	if S.dof and S.dofSaved then
		for k, v in pairs(S.dofSaved) do
			pcall(function()
				S.dof[k] = v
			end)
		end
	end
	local cam = workspace.CurrentCamera
	if cam and S.prevCam then
		cam.FieldOfView = S.prevCam.fov
		if S.prevCam.type == Enum.CameraType.Scriptable then
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = S.prevCam.cf
		else
			cam.CameraType = S.prevCam.type
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			cam.CameraSubject = hum or S.prevCam.subject
		end
	end
	for _, g in ipairs(S.hidden) do
		if g.Parent then
			g.Enabled = true
		end
	end
	if S.gui then
		for _, ch in ipairs(S.gui:GetChildren()) do
			if ch ~= S.fade then
				ch:Destroy()
			end
		end
		if S.fade then
			TweenService:Create(S.fade, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		end
		Debris:AddItem(S.gui, 0.35)
	end
end

------------------------------------------------------------------------
-- Lecture
------------------------------------------------------------------------
local current
local queue = {}

local function flow(S)
	if type(S.entry.Sound) == "string" then
		S:sound(S.entry.Sound)
	end
	if type(S.entry.Rain) == "table" then
		S:rain(S.entry.Rain, 2.4)
	end
	S.scene.intro(S)
	if S.tier >= 2 or S.entry.ForceShowcase then
		showcase(S)
	end
end

local runReveal
runReveal = function(skinId, opts)
	local S = setmetatable({
		id = skinId, opts = type(opts) == "table" and opts or {}, alive = true, skipped = false, phase = "setup", token = 0,
		conns = {}, hidden = {}, vis = {}, visDecals = {}, fxObjs = {}, punchV = 0, camFov = 50, started = os.clock(), entry = {},
		-- v2 (moteur de chorégraphie)
		movers = {}, timeScale = 1, frozenUntil = 0, camRoll = 0, attached = {}, held = {}, origTr = {}, lfx = {}, gen = 0,
		threadGen = setmetatable({}, { __mode = "k" }),
	}, Session)
	current = S
	local ok, err = xpcall(function()
		setup(S)
		S:tween(S.fade, 0.35, { BackgroundTransparency = 1 })
		if S.reveal then
			-- v2 : chorégraphie scriptée
			if S.entry.Location then
				S:setLocation(S.entry.Location)
			end
			S.phase = "scene"
			local R, ctx = Engine.makeR(S)
			S.R = R
			task.spawn(function()
				-- garde-fou : 20 s de scène (hors pause de debug) -> passage forcé
				local e = 0
				while S.alive and S.phase == "scene" do
					local dt = task.wait(0.25)
					if not debugPause then
						e += dt
					end
					if e > 20 and S.alive and S.phase == "scene" then
						warn("[SkinReveal] script trop long, passage forcé :", S.id)
						S.skipped = true
						break
					end
				end
			end)
			local fns = type(S.reveal) == "function" and { S.reveal } or S.reveal
			local okS, errS = true, nil
			for _, fn in ipairs(fns) do
				if type(fn) == "function" then
					okS, errS = pcall(fn, R, ctx)
					if not okS then
						break
					end
				end
			end
			if not okS and errS ~= SKIP then
				warn("[SkinReveal] script " .. tostring(S.id) .. " failed: " .. tostring(errS))
				if not S.cardShown and S.alive then
					local okFb, errFb = pcall(Engine.fallback, S)
					if not okFb and errFb ~= SKIP then
						warn("[SkinReveal] fallback", errFb)
					end
				end
			elseif not okS and S.alive and not S.endNow and not S.cardShown then
				Engine.skipTableau(S)
			end
			if S.alive and not S.endNow and S.phase ~= "card" then
				S.cardShown = true
				showCard(S)
			end
			S.cardAt = S.cardAt or os.clock()
		else
			S:setLocation(S.entry.Location or S.scene.Location)
			S.phase = "scene"
			local okF, errF = pcall(flow, S)
			if not okF and errF ~= SKIP then
				warn("[SkinReveal] scène", S.sceneName, errF)
			end
			hero(S, S.skipped or not okF)
		end
		local dur = CARD_TIME[S.tier] or 2
		local t0 = S.R and S.cardAt or os.clock()
		while S.alive and not S.endNow and os.clock() - t0 < dur do
			task.wait()
			if debugPause then
				t0 = os.clock() - math.min(os.clock() - t0, dur - 0.05)
			end
		end
	end, debug.traceback)
	if not ok then
		warn("[SkinReveal] erreur :", err)
	end
	if S.fade and S.fade.Parent then
		TweenService:Create(S.fade, TweenInfo.new(0.22), { BackgroundTransparency = 0 }):Play()
		task.wait(0.24)
	end
	cleanup(S)
	current = nil
	if type(S.opts.onDone) == "function" then
		task.spawn(S.opts.onDone, skinId)
	end
	local nxt = table.remove(queue, 1)
	if nxt then
		task.spawn(runReveal, nxt[1], nxt[2])
	end
end

function SkinRevealController.play(skinId, opts)
	if current then
		table.insert(queue, { skinId, opts })
		return
	end
	task.spawn(runReveal, skinId, opts)
end

function SkinRevealController.isPlaying()
	return current ~= nil or #queue > 0
end

function SkinRevealController.skip()
	if current then
		current:skip()
	end
end

function SkinRevealController.init(_ctx)
	_G.SkinReveal = SkinRevealController
	-- debug (tests via execute_luau, autre VM) : BindableEvent local au client
	-- ReplicatedStorage.SkinRevealDebug:Fire("play", skinId, { scene = ..., isNew = ... }) | :Fire("skip")
	-- l'état est publié dans l'attribut SkinRevealPlaying de ce même objet
	local dbg = Instance.new("BindableEvent")
	dbg.Name = "SkinRevealDebug"
	dbg.Event:Connect(function(op, a, b)
		if op == "play" then
			SkinRevealController.play(a, type(b) == "table" and b or nil)
		elseif op == "skip" then
			SkinRevealController.skip()
		elseif op == "pause" then
			debugPause = a == true
		elseif op == "demo" then
			local o = type(b) == "table" and table.clone(b) or {}
			o.demo = a
			SkinRevealController.play(o.skin or (a == "LivestreamLegend" and "Intern_Legendary" or "CEO_Legendary"), o)
		end
	end)
	dbg.Parent = ReplicatedStorage
	RunService.Heartbeat:Connect(function()
		dbg:SetAttribute("SkinRevealPlaying", SkinRevealController.isPlaying())
		dbg:SetAttribute("Phase", current and current.phase or "idle")
	end)
end

return SkinRevealController
