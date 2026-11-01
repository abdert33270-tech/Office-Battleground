--[[
	The Bacon — personnage PHARE (format : voir Modules/ContentLoader). Robux uniquement (Config/Unlocks), AUCUN skin.
	Le célèbre « Bacon Hair » de Roblox (le débutant à l'avatar par défaut) devenu légende du bureau : il a l'air d'un
	noob, mais c'est secrètement le GOAT. Voulu par le propriétaire comme le perso LE PLUS FORT du jeu (sans one-shot).

	Look signature (Character.Look) : un skin complet au format SkinBuilder, porté de force en jeu quel que soit le
	skin équipé (SkinService.applyTo -> M.Identity ; puis surveillance ÉVÉNEMENTIELLE : accessoires / vêtements de
	l'avatar qui arrivent en retard, dossier du look retiré ; contrôle lent toutes les 3 s en secours) et utilisé
	tel quel par le menu (CharacterSelectController). Couleurs classiques de
	l'avatar par défaut (tête/mains jaunes, t-shirt bleu, pantalon vert), cheveux en tranches de bacon ondulées,
	lunettes pixel « Deal With It », blouson noir à revers bacon, chaîne en or (médaillon R$), écharpe-bacon, baskets.
	Transformation « Extra Crispy » (M.Transform) : cheveux en flammes, lunettes néon, poêle dans le dos, graisse qui grésille.

	Passif « Main Character » : +10 % de dégâts infligés, -15 % de dégâts subis ; une fois par vie, un coup fatal le
	laisse à 1 PV (« OOF! »), il est intouchable 1,8 s dès ce coup et reprend 25 PV. La sauvegarde n'est consommée que
	si le coup va VRAIMENT le tuer (pas sur une parade / un block dont le chip n'est pas mortel).
	Attaques : Oof (cri en cône qui repousse), Bacon Whip (fouet-bacon qui attrape, tire et claque),
	           Free Robux? (panneau-appât qui ATTIRE tout le monde... puis explose : arnaque !).
	Extra Crispy : Noob Rush (ruée bras tendus façon noob qui renverse tout, finit en plat-ventre),
	           Sizzling Pan (poêle géante du ciel qui PLAQUE + flaque de graisse brûlante qui ralentit),
	           Grease Slide (glissade sur le ventre ; la traînée de graisse fait tomber ceux qui marchent dedans).
	Ultime : Ultimates/Bacon (« MAXIMUM OOF »).
]]
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)
local SoundsCfg = require(Shared.Config.Sounds)
local CombatCfg = require(Shared.Config.Combat)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT
local C = Color3.fromRGB

local BACON = C(232, 92, 64) -- couleur du perso
local MEAT = C(196, 64, 50)
local MEAT2 = C(160, 44, 38)
local FAT = C(255, 218, 196)
local HAIR = C(178, 70, 50)
local YELLOW = C(245, 205, 48) -- « Bright yellow » de l'avatar par défaut
local BLUE = C(13, 105, 172) -- « Bright blue »
local GREEN = C(40, 127, 71) -- « Dark green »
local JACKET = C(32, 32, 40)
local DARK = C(22, 22, 26)
local WHITE = C(250, 250, 250)
local GOLD = C(255, 200, 50)
local GOLD2 = C(120, 80, 10)
local GREASE = C(255, 214, 90)
local FLAME = C(255, 120, 30)
local FLAME2 = C(255, 210, 60)
local ROBUX = C(0, 176, 111)
local BITS = { MEAT, FAT, GREASE }

local DEAL_MULT = 1.1 -- dégâts infligés
local TAKE_MULT = 0.85 -- dégâts subis
local OOF_HEAL = 25
local OOF_SHIELD = 1.5

local M = { Id = "Bacon", Order = 0 }

------------------------------------------------------------------------
-- Look signature (skin SkinBuilder, jamais vendu ni dans les caisses)
------------------------------------------------------------------------
local V, CF, ANG = Vector3.new, CFrame.new, CFrame.Angles

local LOOK_PARTS = {
	-- cheveux : calotte + arrière, puis 4 tranches de bacon ondulées (gras crème sur la 1re moitié) et la mèche avant
	{ Limb = "Head", Mesh = "Sphere", Size = V(1.38, 0.72, 1.4), Color = HAIR, Offset = CF(0, 0.42, 0.05) },
	{ Limb = "Head", Mesh = "Sphere", Size = V(1.34, 1.0, 0.62), Color = HAIR, Offset = CF(0, 0.14, 0.42) },
}
for i, x in ipairs({ -0.45, -0.15, 0.15, 0.45 }) do
	local col = (i % 2 == 0) and MEAT or MEAT2
	local lift = (i % 2) * 0.05
	local front = CF(x, 0.77 + lift, -0.2) * ANG(0.42, 0, x * 0.25)
	table.insert(LOOK_PARTS, { Limb = "Head", Mesh = "Sphere", Size = V(0.32, 0.18, 0.82), Color = col, Offset = front })
	table.insert(LOOK_PARTS, { Limb = "Head", Mesh = "Sphere", Size = V(0.11, 0.2, 0.74), Color = FAT, Offset = front * CF(0.07, 0.005, 0) })
	table.insert(LOOK_PARTS, { Limb = "Head", Mesh = "Sphere", Size = V(0.32, 0.18, 0.86), Color = col, Offset = CF(x, 0.68 + lift * 0.5, 0.36) * ANG(0.6, 0, -x * 0.2) })
end
for _, pd in ipairs({
	-- mèche « swoop » au-dessus du front (la signature du Bacon Hair)
	{ Limb = "Head", Mesh = "Sphere", Size = V(0.62, 0.34, 0.52), Color = MEAT, Offset = CF(0.3, 0.86, -0.5) * ANG(0.5, 0, -0.3) },
	{ Limb = "Head", Mesh = "Sphere", Size = V(0.6, 0.36, 0.14), Color = FAT, Offset = CF(0.3, 0.87, -0.5) * ANG(0.5, 0, -0.3) },
	-- lunettes pixel « Deal With It » (+ reflets blancs, branches)
	{ Limb = "Head", Size = V(1.2, 0.1, 0.06), Color = DARK, Offset = CF(0, 0.27, -0.62) },
	{ Limb = "Head", Size = V(0.46, 0.2, 0.06), Color = DARK, Offset = CF(-0.27, 0.15, -0.63) },
	{ Limb = "Head", Size = V(0.46, 0.2, 0.06), Color = DARK, Offset = CF(0.27, 0.15, -0.63) },
	{ Limb = "Head", Size = V(0.28, 0.09, 0.06), Color = DARK, Offset = CF(-0.27, 0.01, -0.63) },
	{ Limb = "Head", Size = V(0.28, 0.09, 0.06), Color = DARK, Offset = CF(0.27, 0.01, -0.63) },
	{ Limb = "Head", Size = V(0.08, 0.08, 0.03), Color = WHITE, Offset = CF(-0.42, 0.19, -0.665) },
	{ Limb = "Head", Size = V(0.08, 0.08, 0.03), Color = WHITE, Offset = CF(0.12, 0.19, -0.665) },
	{ Limb = "Head", Size = V(0.05, 0.07, 0.62), Color = DARK, Offset = CF(-0.6, 0.25, -0.32) },
	{ Limb = "Head", Size = V(0.05, 0.07, 0.62), Color = DARK, Offset = CF(0.6, 0.25, -0.32) },
	-- blouson noir ouvert sur le t-shirt bleu : dos, côtés, pans avant, revers bacon, col relevé, manches, poignets dorés
	{ Limb = "Torso", Size = V(2.06, 2.04, 0.1), Color = JACKET, Offset = CF(0, 0, 0.53) },
	{ Limb = "Torso", Size = V(0.1, 2.04, 1.1), Color = JACKET, Offset = CF(-1.03, 0, 0) },
	{ Limb = "Torso", Size = V(0.1, 2.04, 1.1), Color = JACKET, Offset = CF(1.03, 0, 0) },
	{ Limb = "Torso", Size = V(0.62, 2.04, 0.1), Color = JACKET, Offset = CF(-0.72, 0, -0.54) },
	{ Limb = "Torso", Size = V(0.62, 2.04, 0.1), Color = JACKET, Offset = CF(0.72, 0, -0.54) },
	{ Limb = "Torso", Size = V(0.2, 0.95, 0.04), Color = BACON, Offset = CF(-0.43, 0.5, -0.6) * ANG(0, 0, 0.3) },
	{ Limb = "Torso", Size = V(0.2, 0.95, 0.04), Color = BACON, Offset = CF(0.43, 0.5, -0.6) * ANG(0, 0, -0.3) },
	{ Limb = "Torso", Size = V(2.0, 0.42, 0.14), Color = JACKET, Offset = CF(0, 1.12, 0.42) * ANG(0.35, 0, 0) },
	{ Limb = "Left Arm", Size = V(1.08, 1.5, 1.08), Color = JACKET, Offset = CF(0, 0.27, 0) },
	{ Limb = "Right Arm", Size = V(1.08, 1.5, 1.08), Color = JACKET, Offset = CF(0, 0.27, 0) },
	{ Limb = "Left Arm", Size = V(1.1, 0.12, 1.1), Color = GOLD, Offset = CF(0, -0.5, 0) },
	{ Limb = "Right Arm", Size = V(1.1, 0.12, 1.1), Color = GOLD, Offset = CF(0, -0.5, 0) },
	-- chaîne en or + médaillon R$
	{ Limb = "Torso", Size = V(0.06, 0.75, 0.06), Color = GOLD, Material = "Foil", Offset = CF(-0.17, 0.36, -0.56) * ANG(0, 0, 0.42) },
	{ Limb = "Torso", Size = V(0.06, 0.75, 0.06), Color = GOLD, Material = "Foil", Offset = CF(0.17, 0.36, -0.56) * ANG(0, 0, -0.42) },
	{ Limb = "Torso", Size = V(0.44, 0.44, 0.08), Color = GOLD, Material = "Foil", Offset = CF(0, -0.06, -0.58), Text = { Text = "R$", Color = GOLD2, Font = "Black", Face = "Front" } },
	-- écharpe en tranche de bacon (le bout flotte dans le dos)
	{ Limb = "Torso", Shape = "Cylinder", Size = V(0.34, 1.3, 1.3), Color = MEAT, Offset = CF(0, 1.07, 0) * UP },
	{ Limb = "Torso", Shape = "Cylinder", Size = V(0.1, 1.33, 1.33), Color = FAT, Offset = CF(0, 1.12, 0) * UP },
	{ Limb = "Torso", Size = V(0.42, 1.25, 0.1), Color = MEAT, Offset = CF(0.5, 0.45, 0.62) * ANG(0, 0, 0.12), Anim = { Swing = 7, SwingSpeed = 2.2, SwingAxis = "X", Seed = 11 } },
	{ Limb = "Torso", Size = V(0.13, 1.23, 0.12), Color = FAT, Offset = CF(0.5, 0.45, 0.62) * ANG(0, 0, 0.12), Anim = { Swing = 7, SwingSpeed = 2.2, SwingAxis = "X", Seed = 11 } },
	-- baskets blanches, semelle bacon
	{ Limb = "Left Leg", Size = V(1.06, 0.42, 1.14), Color = WHITE, Offset = CF(0, -0.8, -0.07) },
	{ Limb = "Right Leg", Size = V(1.06, 0.42, 1.14), Color = WHITE, Offset = CF(0, -0.8, -0.07) },
	{ Limb = "Left Leg", Size = V(1.08, 0.12, 1.18), Color = BACON, Offset = CF(0, -0.97, -0.07) },
	{ Limb = "Right Leg", Size = V(1.08, 0.12, 1.18), Color = BACON, Offset = CF(0, -0.97, -0.07) },
}) do
	table.insert(LOOK_PARTS, pd)
end

local LOOK = {
	Id = "Bacon_Signature", Character = "Bacon", Name = "Signature Look", Rarity = "Legendary", Signature = true,
	Desc = "No skins. No need. The Bacon is already perfect.",
	Outfit = { Shirt = BLUE, Pants = GREEN, Skin = YELLOW, ArmsSkin = true },
	HideIdentity = true, HideFace = true, HideHair = true, HideAccessories = true,
	Parts = LOOK_PARTS,
	Paint = {
		-- sourire en coin + sourcil levé au-dessus des lunettes
		{ Limb = "Head", Face = "Front", Elements = {
			{ Type = "Line", From = { 0.36, 0.69 }, To = { 0.52, 0.72 }, Width = 5, Color = DARK },
			{ Type = "Line", From = { 0.52, 0.72 }, To = { 0.67, 0.63 }, Width = 5, Color = DARK },
			{ Type = "Line", From = { 0.58, 0.2 }, To = { 0.75, 0.15 }, Width = 5, Color = HAIR },
		} },
		-- t-shirt : tranche de bacon + « PRO » (ironie)
		{ Limb = "Torso", Face = "Front", Elements = {
			{ Type = "Box", Pos = { 0.5, 0.42 }, Size = { 0.3, 0.12 }, Corner = 0.5, Color = MEAT, Rotation = -12 },
			{ Type = "Box", Pos = { 0.5, 0.41 }, Size = { 0.27, 0.035 }, Corner = 1, Color = FAT, Rotation = -12 },
			{ Type = "Text", Pos = { 0.5, 0.62 }, Size = { 0.34, 0.12 }, Text = "PRO", Font = "Black", Color = WHITE },
		} },
	},
	FX = { PowerAura = FLAME },
	HitColor = BACON,
}

M.Character = {
	DisplayName = "The Bacon",
	Role = "Legendary noob",
	Color = BACON,
	Shirt = BLUE, Pants = GREEN, Tie = BACON,
	Featured = true, -- en tête du menu des persos + badge LEGENDARY (CharacterSelectController)
	NoSkins = true, -- aucun skin : son look signature (Look) est toujours porté
	Look = LOOK,
	Passive = { Name = "Main Character", Desc = "Deals 10% more and takes 15% less damage. Once per life, a KO hit leaves him at 1 HP instead (OOF!): he heals 25 and is untouchable for 1.8s." },
	Attacks = { "BaconOof", "BaconWhip", "FreeRobux" },
	Transformation = { Name = "Extra Crispy", Desc = "Hair on fire, neon shades, a frying pan on his back and sizzling grease everywhere. Faster and hotter.", Duration = 20, SpeedMultiplier = 1.25 },
	TransAttacks = { "NoobRush", "SizzlingPan", "GreaseSlide" },
}

-- Look signature porté via l'Identity (appelée par SkinBuilder.identity : SkinService pour les persos sans skins,
-- aperçus du menu) : habille le modèle (vrai perso OU mannequin de ViewportFrame) avec LOOK.
-- force = true : rhabille même si le dossier du look est déjà là (vêtements / accessoires de l'avatar revenus)
local SkinBuilder
local trackLook -- (serveur) surveillance événementielle du look, définie avec le passif
local function wearLook(c, force)
	if not SkinBuilder then
		local ok, mod = pcall(require, Shared.Modules.SkinBuilder)
		if not ok then
			return
		end
		SkinBuilder = mod
	end
	local f = c:FindFirstChild(SkinBuilder.FOLDER or "SkinParts")
	if not force and f and f:GetAttribute("SkinId") == LOOK.Id then
		return
	end
	SkinBuilder.dress(c, LOOK)
end

function M.Identity(_f, _head, _torso, c)
	wearLook(c)
	-- appelé par SkinService.applyTo juste après l'habillage : on branche la surveillance du vrai perso
	if trackLook and c:GetAttribute("CharacterName") == "Bacon" then
		trackLook(c)
	end
end

M.Attacks = {
	BaconOof = { Name = "Oof", Kind = "BaconOof", Desc = "Take a deep breath and let out the legendary OOF: a sound blast that sends everyone in front flying.", Cooldown = 7, Anim = "BaconShout", Sound = "Whoosh",
		Windup = 0.32, Range = 17, Angle = 38, Damage = 9, Knockback = 55, KnockUp = 16, Stun = 0.9, Category = "Heavy", Power = 0.9, Words = { "OOF!", "OOOOF!" } },
	BaconWhip = { Name = "Bacon Whip", Kind = "BaconWhip", Desc = "Crack a crispy bacon strip: it grabs the first coworker in line, yanks them in and SMACKS them away.", Prop = "BaconStrip", Cooldown = 8, Anim = "BaconWhip", Sound = "Whoosh",
		Windup = 0.2, Range = 22, Width = 5, LashSpeed = 140, PullSpeed = 90,
		Damage = 5, Knockback = 0, Stun = 1.0, Category = "Light", Power = 0.5, Words = { "CRACK!", "SIZZLE SNAP!" },
		Final = { Damage = 8, Knockback = 44, KnockUp = 12, Stun = 0.9, Category = "Heavy", Power = 0.95, Words = { "CRISPY!", "BACON'D!" } } },
	FreeRobux = { Name = "Free Robux?", Kind = "BaconBait", Desc = "Drop a shiny FREE ROBUX sign: everyone nearby gets sucked in... then it explodes. It was a scam all along.", Cooldown = 12, Anim = "BaconBait", Sound = "Pickup",
		Windup = 0.15, Drop = 0.35, Offset = 11, LureRadius = 16, LureTime = 0.8, PullSpeed = 40, BlastRadius = 8,
		Damage = 12, Knockback = 20, Launch = Vector3.new(8, 58, 0), Stun = 1.1, Category = "Heavy", Power = 1.0, Words = { "SCAMMED!", "NO REFUNDS!" } },
	NoobRush = { Name = "Noob Rush", Kind = "BaconRush", Desc = "Arms out, full noob mode: bulldoze through everyone, then faceplant so hard the floor shakes.", Cooldown = 8, Anim = "BaconNoobRun", Sound = "Dash",
		Windup = 0.15, Speed = 82, Time = 0.55, HitboxSize = Vector3.new(6.5, 6, 6), Radius = 7,
		Damage = 8, Knockback = 36, KnockUp = 16, Stun = 0.9, Category = "Heavy", Power = 0.85, Words = { "NOOB RUSH!", "COMING THROUGH!" },
		Final = { Damage = 6, Knockback = 30, KnockUp = 20, Stun = 0.8, Category = "Heavy", Power = 0.8, Words = { "FACEPLANT!", "OOF!" } } },
	SizzlingPan = { Name = "Sizzling Pan", Kind = "BaconPan", Desc = "A GIANT frying pan drops from the sky and PINS them, leaving a pool of sizzling grease that burns and slows.", Cooldown = 12, Anim = "BaconPan", Sound = "Pickup",
		Windup = 0.55, Range = 28, Offset = 12, Radius = 8, GreaseTime = 4, GreaseSlow = 0.6,
		Damage = 12, Knockback = 0, Stun = 1.2, Category = "Heavy", Power = 1.2, Words = { "SIZZLE!", "PAN-DEMIC!" },
		Effects = { Pin = true, Burn = { Ticks = 3, Damage = 2, Interval = 0.6 } } },
	GreaseSlide = { Name = "Grease Slide", Kind = "BaconSlide", Desc = "Belly-slide on a trail of bacon grease, tripping everyone in the way. Anyone who walks in the grease falls too.", Cooldown = 9, Anim = "BaconSlide", Sound = "Dash",
		Windup = 0.12, Speed = 76, Time = 0.6, HitboxSize = Vector3.new(6, 5, 6), GreaseTime = 5, GreaseRadius = 3.5,
		Damage = 9, Knockback = 18, KnockUp = 26, Stun = 1.0, Category = "Heavy", Power = 0.8, Words = { "WHEEE!", "GREASED!" },
		Effects = { Trip = true },
		Slip = { Damage = 3, Knockback = 22, KnockUp = 12, Stun = 0.8, Category = "Light", Power = 0.4, Words = { "SLIPPED!", "GREASY!" } } },
}

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local function shoutAnim()
	return {
		{ t = 0 },
		-- grande inspiration, buste en arrière
		{ t = 0.22, RS = { p = 0.5, r = -0.7 }, LS = { p = 0.5, r = -0.7 }, RJ = { ln = -0.35 }, RH = { p = 0.15 }, LH = { p = -0.1 } },
		-- OOF ! bras écartés vers l'avant
		{ t = 0.34, RS = { p = 1.5, y = 0.5, r = -0.5 }, LS = { p = 1.5, y = 0.5, r = -0.5 }, RJ = { ln = 0.35 }, RH = { p = -0.35 }, LH = { p = 0.55 } },
		{ t = 0.7, RS = { p = 1.45, y = 0.5, r = -0.55 }, LS = { p = 1.45, y = 0.5, r = -0.55 }, RJ = { ln = 0.3, sd = 0.05 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
		{ t = 0.9 },
	}
end

local function whipAnim()
	return {
		{ t = 0 },
		{ t = 0.12, RS = { p = 2.9, y = -0.5 }, LS = { p = 0.5, r = -0.3 }, RJ = { tw = -0.4, ln = -0.1 }, RH = { p = 0.2 }, LH = { p = -0.2 } },
		{ t = 0.24, RS = { p = 1.3, y = 0.5 }, LS = { p = 0.4, r = -0.3 }, RJ = { tw = 0.35, ln = 0.25 }, RH = { p = -0.35 }, LH = { p = 0.5 } },
		{ t = 0.42, RS = { p = 0.7, y = -0.3 }, LS = { p = 0.4, r = -0.3 }, RJ = { tw = -0.2, ln = -0.2 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.56, RS = { p = 2.1, y = 0.4 }, LS = { p = 0.3, r = -0.3 }, RJ = { tw = 0.45, ln = 0.35 }, RH = { p = -0.4 }, LH = { p = 0.6 } },
		{ t = 0.85 },
	}
end

local function baitAnim()
	local f = {
		{ t = 0 },
		{ t = 0.12, RS = { p = 1.4, r = -0.2 }, LS = { p = 1.4, r = -0.2 }, RJ = { ln = 0.2 } },
	}
	for i = 1, 4 do -- se frotte les mains (affaire du siècle)
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = 0.12 + i * 0.1, RS = { p = 1.2, y = 0.6 + 0.2 * s }, LS = { p = 1.2, y = 0.6 - 0.2 * s }, RJ = { ln = 0.15, tw = 0.08 * s } })
	end
	table.insert(f, { t = 0.75, RS = { p = 2.0, y = 0.2 }, LS = { p = 0.2, r = -0.3 }, RJ = { ln = -0.12, tw = 0.2 } }) -- montre le panneau
	table.insert(f, { t = 1.05, RS = { p = 1.9, y = 0.2 }, LS = { p = 0.2, r = -0.3 }, RJ = { ln = -0.1, tw = 0.2 } })
	table.insert(f, { t = 1.2 })
	return f
end

local function noobRunAnim()
	local f = { { t = 0 }, { t = 0.1, RS = { p = 1.57 }, LS = { p = 1.57 }, RJ = { ln = 0.25 }, RH = { p = 0.6 }, LH = { p = -0.6 } } }
	local t = 0.1
	for i = 1, 8 do -- la course du noob : bras tendus droit devant, petites jambes très rapides
		t += 0.07
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = t, RS = { p = 1.57 + 0.08 * s }, LS = { p = 1.57 - 0.08 * s }, RJ = { ln = 0.28, sd = 0.06 * s }, RH = { p = 0.9 * s }, LH = { p = -0.9 * s } })
	end
	-- plat-ventre
	table.insert(f, { t = t + 0.08, RS = { p = 3.0, r = -0.3 }, LS = { p = 3.0, r = -0.3 }, RJ = { ln = 1.25 }, RH = { p = -0.5 }, LH = { p = -0.3 } })
	table.insert(f, { t = t + 0.4, RS = { p = 3.0, r = -0.35 }, LS = { p = 3.0, r = -0.35 }, RJ = { ln = 1.3 }, RH = { p = -0.45 }, LH = { p = -0.35 } })
	table.insert(f, { t = t + 0.6 })
	return f
end

local function panAnim()
	return {
		{ t = 0 },
		{ t = 0.12, RS = { p = 3.1, r = -0.15 }, LS = { p = 0.4, r = -0.3 }, RJ = { ln = -0.25 }, RH = { p = 0.15 } }, -- montre le ciel
		{ t = 0.45, RS = { p = 3.14, r = -0.1 }, LS = { p = 0.4, r = -0.3 }, RJ = { ln = -0.3 }, RH = { p = 0.15 } },
		{ t = 0.58, RS = { p = 0.9, y = 0.3 }, LS = { p = 0.9, y = 0.3 }, RJ = { ln = 0.4 }, RH = { p = -0.3 }, LH = { p = 0.5 } }, -- BAM
		{ t = 0.9, RS = { p = 0.8, y = 0.3 }, LS = { p = 0.8, y = 0.3 }, RJ = { ln = 0.3 } },
		{ t = 1.05 },
	}
end

local function slideAnim()
	return {
		{ t = 0 },
		{ t = 0.1, RS = { p = 3.0, r = -0.2 }, LS = { p = 3.0, r = -0.2 }, RJ = { ln = 1.3 }, RH = { p = -0.2 }, LH = { p = -0.2 } },
		{ t = 0.65, RS = { p = 3.05, r = -0.25 }, LS = { p = 3.05, r = -0.25 }, RJ = { ln = 1.35, sd = 0.05 }, RH = { p = -0.25 }, LH = { p = -0.15 } },
		{ t = 0.85, RS = { p = 1.2 }, LS = { p = 1.2 }, RJ = { ln = 0.3 } },
		{ t = 1.0 },
	}
end

M.Anims = {
	BaconShout = shoutAnim(), -- inspire, puis OOF bras écartés
	BaconWhip = whipAnim(), -- fouette, tire, claque
	BaconBait = baitAnim(), -- se frotte les mains, montre le panneau
	BaconNoobRun = noobRunAnim(), -- course de noob bras tendus, plat-ventre
	BaconPan = panAnim(), -- montre le ciel, abat les bras
	BaconSlide = slideAnim(), -- glissade sur le ventre (superman)
	BaconOofPose = { -- coup fatal évité : il se relève en époussetant son blouson
		{ t = 0 },
		{ t = 0.1, RS = { p = 0.3, r = -1.2 }, LS = { p = 0.3, r = -1.2 }, RJ = { ln = -0.4, sd = 0.2 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.45, RS = { p = 1.2, y = 0.9 }, LS = { p = 0.3, r = -0.3 }, RJ = { ln = 0.05 } },
		{ t = 0.7 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main (repère bras droit : main en (0,-1,0), -Y = prolongement du bras)
------------------------------------------------------------------------
M.Props = {
	BaconStrip = { -- manche du fouet : bout de tranche de bacon
		{ Vector3.new(0.34, 0.14, 1.3), CFrame.new(0, -1.1, -0.45), MEAT },
		{ Vector3.new(0.12, 0.16, 1.2), CFrame.new(0.06, -1.1, -0.45), FAT },
		{ Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, -1.0, 0), GOLD },
	},
}

-- arme fétiche : canette de Bloxy Cola (main gauche)
M.Signature = { Hand = "Left", Build = function(f, a, prop)
	prop(f, a, Vector3.new(0.85, 0.55, 0.55), CFrame.new(0, -1.2, -0.3) * UP, C(200, 30, 40), CYL)
	prop(f, a, Vector3.new(0.22, 0.57, 0.57), CFrame.new(0, -1.2, -0.3) * UP, WHITE, CYL)
	prop(f, a, Vector3.new(0.06, 0.48, 0.48), CFrame.new(0, -0.77, -0.3) * UP, C(200, 205, 215), CYL)
end }

------------------------------------------------------------------------
-- Transformation « Extra Crispy » (serveur) : cheveux en flammes, lunettes néon, poêle dans le dos, graisse
------------------------------------------------------------------------
local function emitter(parent, texture, color, rate, speed, size, life, spread)
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.Rate = rate
	e.Speed = NumberRange.new(speed * 0.6, speed)
	e.Size = NumberSequence.new(size, 0)
	e.Lifetime = NumberRange.new(life * 0.6, life)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.LightEmission = 0.8
	e.Transparency = NumberSequence.new(0.1, 1)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
	return e
end

function M.Transform(f, head, torso, c, prop)
	-- couronne de flammes sur les cheveux
	for i, o in ipairs({ { 0, 1.02, 0, 0.75 }, { -0.4, 0.92, 0.1, 0.5 }, { 0.4, 0.92, 0.1, 0.5 }, { 0, 0.95, 0.45, 0.55 }, { 0.2, 1.3, -0.05, 0.4 } }) do
		local p = prop(f, head, Vector3.one * o[4], CFrame.new(o[1], o[2], o[3]), (i % 2 == 0) and FLAME2 or FLAME, BALL)
		p.Material = Enum.Material.Neon
		p.Transparency = 0.15
		if i == 1 then
			p.Name = "BaconFlame"
			emitter(p, "rbxasset://textures/particles/fire_main.dds", FLAME, 22, 5, 1.1, 0.5, 15)
			local l = Instance.new("PointLight")
			l.Color = FLAME
			l.Range = 12
			l.Brightness = 2
			l.Shadows = false
			l.Parent = p
		end
	end
	-- lunettes : bande néon
	local lens = prop(f, head, Vector3.new(1.0, 0.06, 0.02), CFrame.new(0, 0.13, -0.665), C(255, 80, 40))
	lens.Material = Enum.Material.Neon
	-- poêle dans le dos (bouclier de chef)
	prop(f, torso, Vector3.new(0.14, 1.75, 1.75), CFrame.new(0, 0.05, 0.7) * CFrame.Angles(0, math.pi / 2, 0), DARK, CYL)
	prop(f, torso, Vector3.new(0.06, 1.45, 1.45), CFrame.new(0, 0.05, 0.79) * CFrame.Angles(0, math.pi / 2, 0), C(70, 70, 80), CYL)
	prop(f, torso, Vector3.new(0.2, 1.2, 0.2), CFrame.new(0.35, 1.3, 0.72) * CFrame.Angles(0, 0, -0.3), C(90, 50, 30))
	-- graisse qui grésille autour du buste
	local host = prop(f, torso, Vector3.new(2.2, 2.2, 1.2), CFrame.new(), DARK)
	host.Transparency = 1
	host.Name = "BaconGrease"
	local g = emitter(host, "rbxasset://textures/particles/fire_sparks_main.dds", GREASE, 14, 7, 0.35, 0.45, 60)
	g.Acceleration = Vector3.new(0, -25, 0)
end

------------------------------------------------------------------------
-- Comportements serveur (Kinds)
------------------------------------------------------------------------
local function ready(api, c)
	return api.CharacterState.isAlive(c) and not api.CharacterState.isStunned(c)
end

-- cible légitime pour les effets qui ne passent pas par applyHit (attraction, ralentissement) :
-- pas protégée, pas dans la zone AFK, pas tenue par une ulti
local function affectable(api, v)
	return not Kit.isProtected(v) and not v:GetAttribute("UltHeld")
		and not (api.CharacterState.inSafeZone and api.CharacterState.inSafeZone(v))
end

M.Kinds = {
	-- Oof : cri en cône (souffle), repousse tout le monde devant
	BaconOof = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		if not root then
			return
		end
		local dir = Kit.aimDir(attacker, aim)
		Kit.fx({ id = "Bacon_Inhale", a = attacker, dur = cfg.Windup })
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		root = Kit.root(attacker)
		if not root then
			return
		end
		Kit.fx({ id = "Bacon_Shout", a = attacker, dir = dir, range = cfg.Range, angle = cfg.Angle })
		local cosA = math.cos(math.rad(cfg.Angle))
		for _, v in ipairs(Kit.enemies(attacker)) do
			local vr = Kit.root(v)
			local to = vr.Position - root.Position
			local d = to.Magnitude
			if d <= cfg.Range and math.abs(to.Y) < 8 and not Kit.isProtected(v) and (d < 4 or Kit.flat(to, dir):Dot(dir) >= cosA) then
				api.hit(attacker, v, cfg, Kit.flat(to, dir), { hitPos = vr.Position + Vector3.new(0, 1, 0) })
			end
		end
	end,

	-- Bacon Whip : le fouet attrape le 1er en ligne, le tire, puis le claque au loin
	BaconWhip = function(attacker, cfg, aim, api)
		local dir = Kit.aimDir(attacker, aim)
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local root = Kit.root(attacker)
		if not root then
			return
		end
		local target = Kit.firstInLine(attacker, root.Position, dir, cfg.Range, cfg.Width)
		if target and Kit.isProtected(target) then
			target = nil
		end
		local travel = 0.18
		if target then
			travel = math.clamp((Kit.root(target).Position - root.Position).Magnitude / cfg.LashSpeed, 0.05, 0.3)
		end
		Kit.fx({ id = "Bacon_Whip", a = attacker, v = target, dir = dir, range = cfg.Range, t = travel })
		if not target then
			return
		end
		task.wait(travel)
		if not ready(api, attacker) or not api.CharacterState.isAlive(target) then
			return
		end
		if api.hit(attacker, target, cfg, dir) ~= "Hit" then
			return
		end
		root = Kit.root(attacker)
		if not root then
			return
		end
		local t = Kit.pull(target, root.Position + dir * 1.5, cfg.PullSpeed, 3.5)
		task.wait(t + 0.05)
		root = Kit.root(attacker)
		local vr = Kit.root(target)
		if not root or not vr or not ready(api, attacker) or not api.CharacterState.isAlive(target) then
			return
		end
		Kit.fx({ id = "Bacon_WhipSmack", a = attacker, v = target })
		api.hit(attacker, target, cfg, api.flat(vr.Position - root.Position, dir), cfg.Final)
	end,

	-- Free Robux? : panneau-appât ; attire tout le monde autour, puis explose
	BaconBait = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		if not root then
			return
		end
		local dir = Kit.aimDir(attacker, aim)
		local center = Kit.ground(Kit.safePoint(root.Position, root.Position + dir * cfg.Offset, 2))
		local lureAt = cfg.Windup + cfg.Drop
		Kit.fx({ id = "Bacon_Sign", a = attacker, c = center, dir = dir, drop = cfg.Drop, t = lureAt, lure = cfg.LureTime, r = cfg.LureRadius })
		task.wait(lureAt)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		for _, v in ipairs(Kit.inCircle(attacker, center + Vector3.new(0, 3, 0), cfg.LureRadius, 8)) do
			if affectable(api, v) then
				Kit.pull(v, center, cfg.PullSpeed, 2.5)
				api.CharacterState.setSpeedMod(v, "BaconBait", 0.5, cfg.LureTime)
			end
		end
		Kit.fx({ id = "Telegraph", p = center, r = cfg.BlastRadius, dur = cfg.LureTime, a = attacker })
		task.wait(cfg.LureTime)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		Kit.fx({ id = "Bacon_Scam", a = attacker, c = center, r = cfg.BlastRadius })
		for _, v in ipairs(Kit.inCircle(attacker, center + Vector3.new(0, 3, 0), cfg.BlastRadius, 8)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - center, dir))
		end
		api.ZoneService.shatterAround(center, cfg.BlastRadius * 0.6, Vector3.new(0, 30, 0))
	end,

	-- Noob Rush : ruée qui renverse tout (1 coup par cible), puis plat-ventre (onde autour pour les autres)
	BaconRush = function(attacker, cfg, aim, api)
		local dir = Kit.aimDir(attacker, aim)
		Kit.fx({ id = "Bacon_Rush", a = attacker, dur = cfg.Windup + cfg.Time })
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		local hitSet = {}
		Kit.dash(attacker, dir, cfg.Speed, cfg.Time, function(r)
			for _, v in ipairs(api.Hitbox.box(r.CFrame * CFrame.new(0, 0, -2), cfg.HitboxSize, attacker, 4)) do
				local vr = Kit.root(v)
				if not hitSet[v] and vr then
					hitSet[v] = true
					api.hit(attacker, v, cfg, api.flat(vr.Position - r.Position, dir))
				end
			end
			return not ready(api, attacker)
		end)
		local root = Kit.root(attacker)
		if not root or not ready(api, attacker) then
			return
		end
		local p = Kit.ground(root.Position)
		api.CharacterState.setSpeedMod(attacker, "BaconFaceplant", 0.35, 0.4)
		Kit.fx({ id = "Bacon_Faceplant", a = attacker, p = p, r = cfg.Radius, dir = dir })
		for _, v in ipairs(Kit.inCircle(attacker, p + Vector3.new(0, 3, 0), cfg.Radius, 7)) do
			if not hitSet[v] then
				api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - p, dir), cfg.Final)
			end
		end
	end,

	-- Sizzling Pan : poêle géante sur la cible devant (ou devant soi), PLAQUE ; graisse brûlante qui ralentit
	BaconPan = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		if not root then
			return
		end
		local dir = Kit.aimDir(attacker, aim)
		local target = Kit.firstInLine(attacker, root.Position, dir, cfg.Range, 9)
		if target and Kit.isProtected(target) then
			target = nil
		end
		local spot = target and Kit.root(target).Position or (root.Position + dir * cfg.Offset)
		local center = Kit.ground(Kit.safePoint(root.Position + Vector3.new(0, 1, 0), spot, 2))
		Kit.fx({ id = "Telegraph", p = center, r = cfg.Radius, dur = cfg.Windup, a = attacker })
		Kit.fx({ id = "Bacon_Pan", a = attacker, c = center, r = cfg.Radius, fall = cfg.Windup, dir = dir, grease = cfg.GreaseTime })
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		for _, v in ipairs(Kit.inCircle(attacker, center + Vector3.new(0, 3, 0), cfg.Radius, 8)) do
			local vr = Kit.root(v)
			api.hit(attacker, v, cfg, api.flat(vr.Position - center, dir), { hitPos = vr.Position + Vector3.new(0, 1, 0) })
		end
		api.ZoneService.shatterAround(center, cfg.Radius * 0.7, Vector3.new(0, 30, 0))
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < cfg.GreaseTime do
				for _, v in ipairs(Kit.inCircle(attacker, center + Vector3.new(0, 3, 0), cfg.Radius, 6)) do
					if affectable(api, v) then
						api.CharacterState.setSpeedMod(v, "BaconGrease", cfg.GreaseSlow, 0.45)
					end
				end
				task.wait(0.25)
			end
		end)
	end,

	-- Grease Slide : glissade ; renverse au passage, la traînée de graisse fait tomber ceux qui marchent dedans
	BaconSlide = function(attacker, cfg, aim, api)
		local dir = Kit.aimDir(attacker, aim)
		task.wait(cfg.Windup)
		if not ready(api, attacker) then
			return
		end
		Kit.fx({ id = "Bacon_Slide", a = attacker, dur = cfg.Time, grease = cfg.GreaseTime, r = cfg.GreaseRadius })
		local hitSet, trail, last = {}, {}, 0
		Kit.dash(attacker, dir, cfg.Speed, cfg.Time, function(r)
			if os.clock() - last > 0.06 then
				last = os.clock()
				table.insert(trail, r.Position)
			end
			for _, v in ipairs(api.Hitbox.box(r.CFrame * CFrame.new(0, -0.5, -1.5), cfg.HitboxSize, attacker, 4)) do
				local vr = Kit.root(v)
				if not hitSet[v] and vr then
					hitSet[v] = true
					api.hit(attacker, v, cfg, api.flat(vr.Position - r.Position, dir))
				end
			end
			return not ready(api, attacker)
		end)
		-- traînée de graisse (le Bacon n'y glisse pas : c'est SA graisse)
		if #trail == 0 then
			return
		end
		task.spawn(function()
			local slipped = {}
			local t0 = os.clock()
			while os.clock() - t0 < cfg.GreaseTime do
				for _, v in ipairs(Kit.enemies(attacker)) do
					local vr = Kit.root(v)
					if vr and not slipped[v] and affectable(api, v) then
						local vel = Vector3.new(vr.AssemblyLinearVelocity.X, 0, vr.AssemblyLinearVelocity.Z)
						for _, pt in ipairs(trail) do
							local d = Vector3.new(vr.Position.X - pt.X, 0, vr.Position.Z - pt.Z).Magnitude
							if d <= cfg.GreaseRadius and math.abs(vr.Position.Y - pt.Y) < 5 then
								if vel.Magnitude > 6 then
									slipped[v] = true
									api.hit(attacker, v, cfg, Kit.flat(vel, dir), cfg.Slip)
								end
								break
							end
						end
					end
				end
				task.wait(0.15)
			end
		end)
	end,
}

------------------------------------------------------------------------
-- Passif (serveur) : Main Character + look signature toujours porté
------------------------------------------------------------------------
local function isBacon(c)
	return c ~= nil and c:GetAttribute("CharacterName") == "Bacon"
end

local LOOK_SAFETY = 3 -- s, contrôle lent de secours (tout le reste est événementiel)
local CLOTHES = { Shirt = true, Pants = true, ShirtGraphic = true }

local function lookReady(c)
	local hum = c and c.Parent and c:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and c:FindFirstChild("Torso") ~= nil and c:FindFirstChild("Head") ~= nil
end

-- le look a-t-il été abîmé ? (dossier absent / autre skin, vêtements ou accessoires de l'avatar visibles)
local function lookBroken(c)
	local f = c:FindFirstChild("SkinParts")
	if not f or f:GetAttribute("SkinId") ~= LOOK.Id then
		return true
	end
	for _, ch in ipairs(c:GetChildren()) do
		if CLOTHES[ch.ClassName] then
			return true
		elseif ch:IsA("Accessory") then
			local h = ch:FindFirstChild("Handle")
			if h and h:IsA("BasePart") and h.Transparency < 1 and h:GetAttribute("_SkinHid") == nil then
				return true
			end
		end
	end
	return false
end

local function checkLook(c)
	if not isBacon(c) or not lookReady(c) then
		return
	end
	local ok, err = pcall(function()
		if lookBroken(c) then
			-- rhabillage complet (SkinBuilder.dress retire l'ancien dossier, recache les accessoires, vide les vêtements)
			wearLook(c, true)
		end
	end)
	if not ok then
		warn("[Bacon] look :", err)
	end
end

-- re-pose regroupée (plusieurs accessoires qui arrivent d'un coup = un seul rhabillage)
local pendingLook = setmetatable({}, { __mode = "k" })
local function scheduleLook(c)
	if not c or pendingLook[c] then
		return
	end
	pendingLook[c] = true
	task.delay(0.1, function()
		pendingLook[c] = nil
		checkLook(c)
	end)
end

-- branché une fois par perso (serveur) : accessoires / vêtements ajoutés, dossier du look retiré
local tracked = setmetatable({}, { __mode = "k" })
function trackLook(c)
	if not c or tracked[c] or not RunService:IsServer() then
		return
	end
	tracked[c] = true
	c.ChildAdded:Connect(function(ch)
		if isBacon(c) and ch.Parent == c and (ch:IsA("Accessory") or CLOTHES[ch.ClassName] or ch:IsA("BodyColors")) then
			scheduleLook(c)
		end
	end)
	c.ChildRemoved:Connect(function(ch)
		if ch.Name == "SkinParts" and isBacon(c) then
			scheduleLook(c)
		end
	end)
end

-- état « K.O. en cours » posé par CombatService (le coup fatal est déjà parti : rien à sauver)
local function pendingKO(api, v)
	if v:GetAttribute("PendingKO") then
		return true
	end
	local ok, st = pcall(api.CharacterState.get, v)
	return ok and type(st) == "table" and st.pendingKO ~= nil and st.pendingKO ~= false
end

-- dégâts que ce coup va VRAIMENT infliger, en rejouant l'ordre de CombatService.applyHit (garde de face) :
-- renvoie (dégâts, multiplicateur) ; paré => 0 ; bloqué / garde cassée => chip = dégâts x (1 - Reduction)
local function landed(api, v, p)
	if p.unblockable then
		return p.damage, 1
	end
	local ok, st = pcall(api.CharacterState.get, v)
	local root = v:FindFirstChild("HumanoidRootPart")
	if not ok or type(st) ~= "table" or not st.blocking or not root then
		return p.damage, 1
	end
	local dir = p.dir or Vector3.new(0, 0, -1)
	if root.CFrame.LookVector:Dot(-dir) <= 0.1 then
		return p.damage, 1 -- block de dos : le coup passe
	end
	local B = CombatCfg.Block or {}
	if os.clock() - (st.blockStart or -10) <= (B.PerfectWindow or B.ParryWindow or 0) then
		return 0, 1 -- PERFECT BLOCK : aucun dégât
	end
	local mult = math.max(0.01, 1 - (B.Reduction or 0.85))
	return p.damage * mult, mult
end

function M.ServerInit(api)
	local CS = api.CombatService
	-- Main Character : +10 % infligés, -15 % subis
	table.insert(CS.damageMods, function(p)
		local a, v = p.attacker, p.victim
		if (p.damage or 0) <= 0 then
			return
		end
		if a and a ~= v and isBacon(a) then
			p.damage *= DEAL_MULT
		end
		if v and v ~= a and isBacon(v) then
			p.damage *= TAKE_MULT
		end
	end)
	-- Plot Armor (OOF!) : ajouté en DERNIER (après tous les autres bonus) pour juger du vrai coup fatal.
	-- Les damageMods tournent AVANT la garde (CombatService.applyHit) : on prédit ici l'issue du coup pour ne
	-- brûler la sauvegarde que si le coup va VRAIMENT le tuer (pas sur un coup paré / bloqué non mortel).
	task.delay(1.5, function()
		table.insert(CS.damageMods, function(p)
			local v = p.victim
			if not isBacon(v) or v:GetAttribute("BaconOofUsed") or (p.damage or 0) <= 0 or p.trayGuard then
				return
			end
			local hum = v:FindFirstChildOfClass("Humanoid")
			if not hum or hum.Health <= 0 or pendingKO(api, v) then
				return
			end
			local taken, chipMult = landed(api, v, p)
			if taken <= 0 or hum.Health - taken > 0 then
				return -- paré, ou pas mortel (bloqué : seul le « chip » passe)
			end
			v:SetAttribute("BaconOofUsed", true)
			-- reste à 1 PV : coup normal => dégâts = PV - 1 ; bloqué => le chip (dégâts x chipMult) laisse 1 PV
			p.damage = math.max(0, hum.Health - 1) / chipMult
			p.words = { "OOF!", "PLOT ARMOR!" }
			p.launch = nil
			p.knockback = math.min(p.knockback or 0, 30)
			Kit.fx({ id = "Bacon_PlotArmor", v = v })
			-- intouchable dès la fin de CE coup (task.defer : après son TakeDamage, qu'un ForceField annulerait),
			-- sinon le coup suivant d'un combo le finirait pendant le relevé ; soin 0,3 s plus tard
			task.defer(function()
				if v.Parent and hum.Health > 0 then
					local ff = Instance.new("ForceField")
					ff.Name = "BaconPlotArmor"
					ff.Visible = false
					ff.Parent = v
					Debris:AddItem(ff, 0.3 + OOF_SHIELD)
				end
			end)
			task.delay(0.3, function()
				if hum.Parent and hum.Health > 0 and v.Parent then
					hum.Health = math.min(hum.MaxHealth, hum.Health + OOF_HEAL)
				end
			end)
		end)
	end)

	-- look signature : porté quel que soit le skin équipé. Appliqué par SkinService.applyTo (-> M.Identity, qui
	-- branche aussi trackLook) ; ici : changement de perso / respawn / avatar chargé en retard, puis contrôle lent.
	local function watch(pl)
		pl:GetAttributeChangedSignal("CharacterName"):Connect(function()
			task.delay(0.1, function()
				checkLook(pl.Character)
			end)
		end)
		pl.CharacterAdded:Connect(function(c)
			trackLook(c)
			task.delay(0.2, function()
				checkLook(c)
			end)
		end)
		pl.CharacterAppearanceLoaded:Connect(function(c)
			scheduleLook(c) -- vêtements / accessoires de l'avatar arrivés après l'habillage
		end)
		if pl.Character then
			trackLook(pl.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, pl in ipairs(Players:GetPlayers()) do
		watch(pl)
	end
	-- filet de sécurité LENT (les cas normaux sont tous événementiels) : toutes les 3 s
	task.spawn(function()
		while true do
			task.wait(LOOK_SAFETY)
			for _, pl in ipairs(Players:GetPlayers()) do
				local c = pl.Character
				if c and isBacon(c) and lookBroken(c) then
					scheduleLook(c)
				end
			end
		end
	end)
end

------------------------------------------------------------------------
-- Effets client
------------------------------------------------------------------------
local ProcAnim -- branché dans ClientInit

local function snd(key, pos, vol, pitch)
	local list = SoundsCfg[key]
	local id = type(list) == "table" and list[1] or nil
	if not id then
		return
	end
	local holder = Kit.part({ Size = Vector3.one * 0.2, Transparency = 1, Position = pos })
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol or 1
	s.PlaybackSpeed = pitch or 1
	s.RollOffMaxDistance = 140
	s.Parent = holder
	s:Play()
	Debris:AddItem(holder, 4)
end

-- texte 3D (BillboardGui) qui avance dans une direction en grossissant
local function flyText(from, dir, dist, text, color, size0, size1, life)
	local p = Kit.part({ Size = Vector3.one * 0.2, Transparency = 1, Position = from })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size0, size0 * 0.5)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Parent = l
	Kit.tween(p, life, { Position = from + dir * dist })
	Kit.tween(bb, life, { Size = UDim2.fromScale(size1, size1 * 0.5) })
	task.delay(life * 0.55, function()
		Kit.tween(l, life * 0.45, { TextTransparency = 1 })
		Kit.tween(st, life * 0.45, { Transparency = 1 })
	end)
	Debris:AddItem(p, life + 0.05)
end

-- disque plat au sol
local function disc(pos, d, color, transp)
	return Kit.part({ Shape = CYL, Size = Vector3.new(0.1, d, d), CFrame = CFrame.new(pos + Vector3.new(0, 0.08, 0)) * UP, Color = color, Transparency = transp or 0 })
end

local function fadeAll(list, t)
	for _, p in ipairs(list) do
		if p.Parent then
			Kit.tween(p, t, { Transparency = 1 })
			Debris:AddItem(p, t + 0.02)
		end
	end
end

-- panneau FREE ROBUX (repère : base au sol, -Z = vers le Bacon)
local function buildSign(cf)
	local list = {}
	local function add(size, off, color, shape)
		local p = Kit.part({ Size = size, CFrame = cf * off, Color = color })
		if shape then
			p.Shape = shape
		end
		table.insert(list, { p = p, off = off })
		return p
	end
	add(Vector3.new(0.4, 4.2, 0.4), CFrame.new(0, 2.1, 0.2), C(150, 150, 160))
	add(Vector3.new(2.2, 0.25, 1.6), CFrame.new(0, 0.12, 0.2), C(110, 110, 120))
	local board = add(Vector3.new(5.6, 2.6, 0.3), CFrame.new(0, 4.6, 0), ROBUX)
	add(Vector3.new(5.9, 2.9, 0.2), CFrame.new(0, 4.6, 0), GOLD) -- cadre doré (dépasse sur les bords)
	Kit.flatText(board, "FREE ROBUX!!", WHITE, Enum.NormalId.Front)
	Kit.flatText(board, "FREE ROBUX!!", WHITE, Enum.NormalId.Back)
	local coin = add(Vector3.new(0.25, 1.6, 1.6), CFrame.new(0, 6.9, 0) * CFrame.Angles(0, math.pi / 2, 0), GOLD, CYL)
	coin.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 14
	light.Brightness = 2
	light.Parent = board
	return list, coin
end

M.MoveFX = {
	BaconOof = function(c, d, api) end,
	BaconWhip = function(c, d, api) end,
	FreeRobux = function(c, d, api) end,
	NoobRush = function(c, d, api)
		api.afterimages(c, 0.7, BACON)
		if Kit.mine(c) then
			task.delay(0.12, function()
				api.CartoonFX.speedLines(0.55, BACON)
			end)
		end
	end,
	SizzlingPan = function(c, d, api) end,
	GreaseSlide = function(c, d, api)
		api.afterimages(c, 0.65, GREASE)
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	ProcAnim = api.ProcAnim
	Kit.setupClient()

	-- Oof : inspiration (petites bulles), puis « OOF » géant qui part en cône
	Kit.on("Bacon_Inhale", function(d)
		local head = d.a and d.a:FindFirstChild("Head")
		if not head then
			return
		end
		Kit.floatText(head.Position + Vector3.new(0, 1.6, 0), "*inhales*", WHITE, 2.2, 0.5, 1)
		CartoonFX.sound("Whoosh", head.Position, 0.6)
	end)
	Kit.on("Bacon_Shout", function(d)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		local dir = d.dir or r.CFrame.LookVector
		local mouth = r.Position + Vector3.new(0, 1.6, 0) + dir * 1.2
		snd("Oof", mouth, 1.6, 0.75)
		snd("Oof", mouth, 1.0, 1.0)
		flyText(mouth, dir, d.range or 17, "OOF!", BACON, 4, 11, 0.45)
		task.delay(0.07, function()
			flyText(mouth + Vector3.new(0, 0.6, 0), dir, (d.range or 17) * 0.85, "OOF", FAT, 3, 8, 0.4)
		end)
		for i = 0, 3 do
			task.delay(i * 0.06, function()
				local p = mouth + dir * (2 + i * 3.5)
				CartoonFX.airRing(p, dir, 3 + i * 2.2, i % 2 == 0 and WHITE or BACON, 0.3)
			end)
		end
		CartoonFX.dust(CartoonFX.groundPos(r.Position + dir * 4), 5, nil, 8)
		Kit.cubes(mouth + dir * 2, 10, { WHITE, YELLOW, BACON }, 0.4, 12, 0.45)
		if Kit.mine(d.a) then
			CartoonFX.shake(0.8)
		end
	end)

	-- Bacon Whip : corde-bacon + claquement
	Kit.on("Bacon_Whip", function(d)
		local c = d.a
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		CartoonFX.sound("Whoosh", r.Position, 0.9)
		Kit.rope(c, d.v, d.dir, d.range or 22, d.v and 0.75 or 0.4, MEAT, 0.32, FAT, Vector3.new(0.6, 0.25, 0.9))
		task.delay(d.t or 0.15, function()
			local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
			if vr then
				CartoonFX.sound("Splat", vr.Position, 0.9)
				CartoonFX.word(vr.Position + Vector3.new(0, 3.5, 0), "CRACK!", 1.1, "Light")
				Kit.cubes(vr.Position, 8, BITS, 0.35, 6, 0.4)
			end
		end)
	end)
	Kit.on("Bacon_WhipSmack", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		CartoonFX.sound("PunchHeavy", vr.Position, 1)
		CartoonFX.bigImpact(vr.Position, Vector3.new(0, 1, 0), 0.9, BACON)
		Kit.cubes(vr.Position, 12, BITS, 0.45, 9, 0.5)
		if Kit.mine(d.a) then
			CartoonFX.shake(0.6)
		end
	end)

	-- Free Robux? : panneau qui tombe, attire... et explose
	local signs = {}
	Kit.on("Bacon_Sign", function(d)
		local look = d.dir or Vector3.new(0, 0, -1)
		local cf = CFrame.lookAt(d.c, d.c - look) -- face au Bacon
		local list, coin = buildSign(cf * CFrame.new(0, 14, 0))
		for _, e in ipairs(list) do
			Kit.tween(e.p, d.drop or 0.35, { CFrame = cf * e.off }, Enum.EasingStyle.Bounce)
		end
		local st = { list = list, t0 = os.clock() }
		signs[d.a or 0] = st
		CartoonFX.sound("Ding", d.c, 1)
		task.delay(d.drop or 0.35, function()
			CartoonFX.sound("Thud", d.c, 1)
			CartoonFX.dust(d.c, 4, nil, 8)
			Kit.floatText(d.c + Vector3.new(0, 8.5, 0), "100% LEGIT", GOLD, 2.6, 1.1, 1)
			-- rayon d'attraction : pièces qui tournent vers le panneau
			for i = 1, 10 do
				local a = i / 10 * math.pi * 2
				local from = d.c + Vector3.new(math.cos(a) * (d.r or 16), 2, math.sin(a) * (d.r or 16))
				local coinP = Kit.part({ Shape = CYL, Size = Vector3.new(0.15, 0.9, 0.9), CFrame = CFrame.new(from), Color = GOLD, Material = Enum.Material.Neon })
				Kit.tween(coinP, d.lure or 0.8, { CFrame = CFrame.new(d.c + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, a * 3, 0), Size = Vector3.new(0.1, 0.3, 0.3) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				Debris:AddItem(coinP, (d.lure or 0.8) + 0.05)
			end
			CartoonFX.shockwave(d.c + Vector3.new(0, 0.2, 0), d.r or 16, GOLD)
		end)
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not coin.Parent or os.clock() - t0 > 3 then
				conn:Disconnect()
				return
			end
			coin.CFrame = coin.CFrame * CFrame.Angles(0.12, 0, 0)
		end)
		task.delay(3, function()
			if signs[d.a or 0] == st then
				signs[d.a or 0] = nil -- Bacon mort avant l'explosion : on oublie le panneau
			end
			for _, e in ipairs(list) do
				if e.p.Parent then
					e.p:Destroy()
				end
			end
		end)
	end)
	Kit.on("Bacon_Scam", function(d)
		local st = signs[d.a or 0]
		signs[d.a or 0] = nil
		if st then
			for _, e in ipairs(st.list) do
				local p = e.p
				if p.Parent then
					local away = (p.Position - d.c)
					away = Vector3.new(away.X, 0, away.Z)
					away = (away.Magnitude > 0.1 and away.Unit or Vector3.xAxis) + Vector3.new(0, 1.2, 0)
					Kit.tween(p, 0.5, { CFrame = p.CFrame * CFrame.Angles(Kit.rng:NextNumber(-2, 2), 0, Kit.rng:NextNumber(-2, 2)) + away * 8, Transparency = 1 })
					Debris:AddItem(p, 0.52)
				end
			end
		end
		CartoonFX.sound("Explosion", d.c, 1.2)
		CartoonFX.sound("BigImpact", d.c, 0.9)
		CartoonFX.bigImpact(d.c + Vector3.new(0, 2, 0), Vector3.new(0, 1, 0), 1.4, ROBUX)
		CartoonFX.shockwave(d.c + Vector3.new(0, 0.2, 0), (d.r or 8) * 1.3, GOLD)
		CartoonFX.shards(d.c + Vector3.new(0, 2, 0), 18, { GOLD, ROBUX, WHITE }, 1.4)
		CartoonFX.word(d.c + Vector3.new(0, 7, 0), "SCAMMED!", 1.6, "Heavy")
		Kit.cubes(d.c + Vector3.new(0, 2, 0), 16, { GOLD, ROBUX }, 0.5, 14, 0.6)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 4, 0), "no refunds :)", WHITE, 2.4, 1.1, 1.4)
		end
		if Kit.mine(d.a) then
			CartoonFX.shake(1)
			CartoonFX.impactFrame(0.6)
		end
	end)

	-- Noob Rush
	Kit.on("Bacon_Rush", function(d)
		local c = d.a
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		CartoonFX.sound("Dash", r.Position, 1)
		Kit.floatText(r.Position + Vector3.new(0, 4, 0), "NOOB MODE", BACON, 2.6, 0.7, 1.4)
		local tr = c:FindFirstChild("Torso")
		if tr then
			CartoonFX.trailOn(tr, BACON, d.dur + 0.1, 0, 1.6)
		end
	end)
	Kit.on("Bacon_Faceplant", function(d)
		CartoonFX.sound("GroundSlam", d.p, 1)
		snd("Oof", d.p, 1.1, 1.0)
		CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r or 7, BACON)
		CartoonFX.dust(d.p, d.r or 7, nil, 14)
		CartoonFX.word(d.p + Vector3.new(0, 4.5, 0), "FACEPLANT!", 1.3, "Heavy")
		Kit.cubes(d.p + Vector3.new(0, 0.5, 0), 12, { C(120, 110, 100), YELLOW, BACON }, 0.5, 9, 0.5)
		if d.a then
			local head = d.a:FindFirstChild("Head")
			if head then
				CartoonFX.dizzy(d.a, 0.8)
			end
		end
		if Kit.mine(d.a) then
			CartoonFX.shake(0.9)
		end
	end)

	-- Sizzling Pan : poêle géante qui tombe + flaque de graisse
	Kit.on("Bacon_Pan", function(d)
		local look = d.dir or Vector3.new(0, 0, -1)
		local base = CFrame.lookAt(d.c, d.c + look)
		local R = d.r or 8
		local pieces = {}
		local function piece(size, off, color, shape)
			local p = Kit.part({ Size = size, CFrame = base * CFrame.new(0, 40, 0) * off, Color = color })
			if shape then
				p.Shape = shape
			end
			table.insert(pieces, { p = p, off = off })
			return p
		end
		piece(Vector3.new(0.6, R * 2, R * 2), CFrame.new(0, 0.3, 0) * UP, DARK, CYL) -- fond
		piece(Vector3.new(1.4, R * 2 + 0.6, R * 2 + 0.6), CFrame.new(0, 0.9, 0) * UP, C(55, 55, 62), CYL) -- rebord
		piece(Vector3.new(1.5, R * 2 - 0.8, R * 2 - 0.8), CFrame.new(0, 0.95, 0) * UP, C(90, 90, 100), CYL) -- intérieur
		piece(Vector3.new(1.4, 1.2, R * 1.4), CFrame.new(0, 1.2, R + R * 0.65), C(90, 50, 30)) -- manche
		-- deux tranches de bacon qui grésillent dedans
		for k = -1, 1, 2 do
			piece(Vector3.new(R * 0.5, 0.3, R * 1.3), CFrame.new(k * R * 0.32, 1.75, 0) * CFrame.Angles(0, 0, 0.1 * k), MEAT)
			piece(Vector3.new(R * 0.14, 0.32, R * 1.25), CFrame.new(k * R * 0.32 + 0.4, 1.76, 0) * CFrame.Angles(0, 0, 0.1 * k), FAT)
		end
		local shadow = disc(d.c, 2, C(20, 15, 15), 0.6)
		Kit.tween(shadow, d.fall or 0.55, { Size = Vector3.new(0.1, R * 2, R * 2), Transparency = 0.3 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(shadow, (d.fall or 0.55) + 0.05)
		CartoonFX.sound("Whoosh", d.c, 1)
		local fall = d.fall or 0.55
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local a = math.clamp((os.clock() - t0) / fall, 0, 1)
			local y = 40 * (1 - a * a)
			for _, e in ipairs(pieces) do
				if e.p.Parent then
					e.p.CFrame = base * CFrame.new(0, y, 0) * e.off
				end
			end
			if a >= 1 then
				conn:Disconnect()
			end
		end)
		task.delay(fall, function()
			CartoonFX.sound("Clang", d.c, 1.3)
			CartoonFX.sound("BigImpact", d.c, 1)
			CartoonFX.bigImpact(d.c + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.4, FLAME)
			CartoonFX.shockwave(d.c + Vector3.new(0, 0.2, 0), R * 1.3, GREASE)
			CartoonFX.word(d.c + Vector3.new(0, 6, 0), "SIZZLE!!", 1.5, "Heavy")
			Kit.cubes(d.c + Vector3.new(0, 1, 0), 18, { GREASE, FLAME, MEAT }, 0.45, 12, 0.55)
			if Kit.mine(d.a) then
				CartoonFX.shake(1.1)
				CartoonFX.impactFrame(0.7)
			end
			-- la poêle repart, la graisse reste
			task.delay(0.35, function()
				for _, e in ipairs(pieces) do
					if e.p.Parent then
						Kit.tween(e.p, 0.4, { CFrame = e.p.CFrame + Vector3.new(0, 30, 0), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
						Debris:AddItem(e.p, 0.42)
					end
				end
			end)
			local pool = disc(d.c, 1, GREASE, 0.2)
			pool.Material = Enum.Material.Neon
			Kit.tween(pool, 0.25, { Size = Vector3.new(0.1, R * 2, R * 2) }, Enum.EasingStyle.Back)
			local dur = d.grease or 4
			task.spawn(function()
				local tt = os.clock()
				while os.clock() - tt < dur do
					local a, rr = Kit.rng:NextNumber(0, math.pi * 2), Kit.rng:NextNumber(0, R * 0.9)
					local pos = d.c + Vector3.new(math.cos(a) * rr, 0.2, math.sin(a) * rr)
					local bub = Kit.part({ Shape = BALL, Size = Vector3.one * 0.3, Position = pos, Color = (Kit.rng:NextNumber() < 0.5) and GREASE or WHITE, Material = Enum.Material.Neon })
					Kit.tween(bub, 0.45, { Size = Vector3.one * 0.7, Position = pos + Vector3.new(0, 1.2, 0), Transparency = 1 })
					Debris:AddItem(bub, 0.47)
					task.wait(0.07)
				end
				fadeAll({ pool }, 0.4)
			end)
		end)
		task.delay(fall + 2, function()
			for _, e in ipairs(pieces) do
				if e.p.Parent then
					e.p:Destroy()
				end
			end
		end)
	end)

	-- Grease Slide : traînée de graisse dorée qui reste au sol
	Kit.on("Bacon_Slide", function(d)
		local c = d.a
		local r = c and c:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		CartoonFX.sound("Slip", r.Position, 1)
		Kit.floatText(r.Position + Vector3.new(0, 4, 0), "WHEEE!", GREASE, 2.4, 0.7, 1.2)
		local puddles = {}
		local t0 = os.clock()
		task.spawn(function()
			while os.clock() - t0 < (d.dur or 0.6) and r.Parent do
				local g = CartoonFX.groundPos(r.Position)
				local p = disc(g, (d.r or 3.5) * 2, GREASE, 0.25)
				p.Material = Enum.Material.Neon
				table.insert(puddles, p)
				Kit.cubes(g + Vector3.new(0, 0.4, 0), 2, BITS, 0.3, 4, 0.35)
				task.wait(0.06)
			end
			task.wait(d.grease or 5)
			fadeAll(puddles, 0.4)
		end)
	end)

	-- Plot Armor : il évite le K.O. (silhouettes dorées, OOF!)
	Kit.on("Bacon_PlotArmor", function(d)
		local v = d.v
		local r = v and v:FindFirstChild("HumanoidRootPart")
		if not r then
			return
		end
		snd("Oof", r.Position, 1.6, 0.9)
		CartoonFX.sound("PowerUp", r.Position, 0.9)
		Kit.floatText(r.Position + Vector3.new(0, 4.6, 0), "PLOT ARMOR!", GOLD, 3.2, 1.3, 2)
		CartoonFX.word(r.Position + Vector3.new(0, 3, 0), "OOF!", 1.6, "Heavy")
		CartoonFX.sparks(r.Position + Vector3.new(0, 1, 0), 14, GOLD)
		CartoonFX.shockwave(CartoonFX.groundPos(r.Position) + Vector3.new(0, 0.2, 0), 8, GOLD)
		for _, n in ipairs({ "Torso", "Head", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
			local src = v:FindFirstChild(n)
			if src and src:IsA("BasePart") then
				local g = Kit.part({ Size = src.Size, CFrame = src.CFrame, Color = GOLD, Transparency = 0.35, Material = Enum.Material.Neon })
				Kit.tween(g, 0.6, { CFrame = src.CFrame + Vector3.new(0, 3, 0), Transparency = 1 })
				Debris:AddItem(g, 0.62)
			end
		end
		if ProcAnim then
			task.delay(0.3, function()
				if v.Parent then
					pcall(ProcAnim.play, v, "BaconOofPose")
				end
			end)
		end
		if Kit.mine(v) then
			CartoonFX.shake(1)
		end
	end)

	-- aura Extra Crispy : gouttes de graisse qui sautent, « *sizzle* » de temps en temps
	task.spawn(function()
		local lastSizzle = {}
		while true do
			task.wait(0.12)
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "Bacon" and c:GetAttribute("Transformed") then
					local r = c:FindFirstChild("HumanoidRootPart")
					if r then
						if Kit.rng:NextNumber() < 0.45 then
							Kit.cubes(r.Position + Vector3.new(Kit.rng:NextNumber(-1, 1), Kit.rng:NextNumber(-0.5, 1.5), Kit.rng:NextNumber(-0.6, 0.6)), 1, { GREASE, FLAME2 }, 0.18, 2.5, 0.35)
						end
						local t = os.clock()
						if t - (lastSizzle[c] or 0) > 2.4 then
							lastSizzle[c] = t
							Kit.floatText(r.Position + Vector3.new(Kit.rng:NextNumber(-1.5, 1.5), 3.2, 0), "*sizzle*", GREASE, 1.6, 0.8, 1)
						end
					end
				end
			end
			for c in pairs(lastSizzle) do
				if not c.Parent then
					lastSizzle[c] = nil
				end
			end
		end
	end)
end

return M
