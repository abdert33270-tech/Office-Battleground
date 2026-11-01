--[[
	The Fitness Coach — personnage complet (format : voir Modules/ContentLoader).
	Passif No Pain No Gain : sous 50 % de PV, +20 % de dégâts et +10 % de vitesse.
	Attaques : Kettlebell Swing (énorme swing à deux mains), Medicine Ball (ballon lourd qui traverse et rebondit sur les murs),
	           Spot Me! (saisie : développé-couché de la victime au-dessus de la tête, 3 reps, puis lancer).
	Transformation Beast Mode : Protein Shake (buff : soin, +25 % dégâts, -30 % de recul subi + onde de flex),
	           Jump Rope Whirlwind (corde à sauter qui fouette tout autour, 6 coups), Push-Up Shockwave (pompe géante :
	           l'onde de choc PLAQUE tout le monde au sol autour de lui).
]]
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT
local ALONG_Y = CFrame.Angles(0, 0, math.pi / 2)
local ALONG_Z = CFrame.Angles(0, math.pi / 2, 0)

local LIME = Color3.fromRGB(140, 225, 30) -- couleur du perso
local LIME2 = Color3.fromRGB(200, 255, 110)
local IRON = Color3.fromRGB(55, 58, 66)
local DARK = Color3.fromRGB(30, 30, 36)
local WHITE = Color3.fromRGB(250, 250, 250)
local SHAKE = Color3.fromRGB(245, 175, 205)
local ROPE = Color3.fromRGB(255, 120, 40)
local SWEAT = Color3.fromRGB(150, 210, 255)
local GOLD = Color3.fromRGB(255, 200, 40)
local SILVER = Color3.fromRGB(205, 210, 220)

local M = { Id = "FitnessCoach", Order = 12 }

M.Character = {
	DisplayName = "The Fitness Coach",
	Role = "Bruiser",
	Color = LIME,
	Shirt = Color3.fromRGB(150, 230, 40), Pants = Color3.fromRGB(40, 40, 55), Tie = DARK,
	Passive = { Name = "No Pain No Gain", Desc = "Below 50% HP he deals +20% damage and gets +10% speed." },
	Attacks = { "KettlebellSwing", "MedicineBall", "SpotMe" },
	Transformation = { Name = "Beast Mode", Desc = "Giant headphones, champion belt and bulging shoulders.", Duration = 20, SpeedMultiplier = 1.1 },
	TransAttacks = { "ProteinShake", "JumpRopeWhirlwind", "PushUpShockwave" },
}

M.Attacks = {
	KettlebellSwing = { Name = "Kettlebell Swing", Kind = "Melee", Desc = "Hike a huge kettlebell between your legs and swing it up: launches everything in front.", Prop = "FitKettlebell", Cooldown = 7, Anim = "FitSwing", Sound = "Whoosh",
		Windup = 0.34, HitboxOffset = 4, HitboxSize = Vector3.new(9, 6, 7), Damage = 13, Knockback = 52, KnockUp = 26, Stun = 1.0, Category = "Heavy", Power = 1.05, Material = "Metal",
		Words = { "KETTLEBELL!", "ONE REP!", "WHAM!" } },
	MedicineBall = { Name = "Medicine Ball", Kind = "FitBall", Desc = "Chest-pass a heavy medicine ball: it plows through coworkers and bounces off walls.", Prop = "FitMedBall", Cooldown = 7, Anim = "FitBall", Sound = "Throw",
		Speed = 78, Range = 80, Bounces = 2, Damage = 8, Knockback = 30, KnockUp = 12, Stun = 0.8, Category = "Heavy", Power = 0.75, Words = { "MEDICINE BALL!", "BOOF!" } },
	SpotMe = { Name = "Spot Me!", Kind = "FitSpot", Desc = "Grab a coworker, bench-press them overhead for 3 reps, then hurl them forward.", Cooldown = 10, Anim = "FitSpot", Sound = "Whoosh",
		HitboxOffset = 3.5, HitboxSize = Vector3.new(6, 6, 7), Reps = 3, RepTime = 0.25, RepDamage = 1.5, Damage = 9, ThrowKnockback = 58, ThrowUp = 28, Stun = 1.0, Category = "Heavy", Power = 1.0,
		Words = { "SPOT ME!", "LIGHTWEIGHT!" } },
	ProteinShake = { Name = "Protein Shake", Kind = "FitShake", Desc = "Chug a protein shake: heal 15, then 6s of +25% damage and -30% knockback taken. Flex blast!", Prop = "FitShaker", Cooldown = 16, Anim = "FitShake", Sound = "Eat",
		Heal = 15, BuffTime = 6, Radius = 8, Damage = 4, Knockback = 30, KnockUp = 8, Stun = 0.4, Category = "Light", Power = 0.5, Words = { "GAINS!", "FLEX!" } },
	JumpRopeWhirlwind = { Name = "Jump Rope Whirlwind", Kind = "FitWhirl", Desc = "Whirl your jump rope around you: 6 fast lashes on everyone close, the last one launches.", Prop = "FitRope", Cooldown = 11, Anim = "FitWhirl", Sound = "Whoosh",
		Radius = 10, Hits = 6, Interval = 0.17, Damage = 2, Knockback = 8, KnockUp = 4, Stun = 0.45, Category = "Light", Power = 0.3, Words = { "WHIP!", "SNAP!", "DOUBLE UNDER!" },
		Final = { Damage = 6, Knockback = 44, KnockUp = 30, Stun = 1.0, Category = "Heavy", Power = 1.0, Words = { "FEEL THE BURN!" } } },
	PushUpShockwave = { Name = "Push-Up Shockwave", Kind = "FitPushUp", Desc = "Drop and do ONE mega push-up: the floor shockwave PINS everyone around you.", Cooldown = 13, Anim = "FitPushUp", Sound = "GroundSlam",
		Windup = 0.45, Radius = 14, Damage = 13, Knockback = 0, Stun = 1.4, Category = "Heavy", Power = 1.2,
		Words = { "DROP AND GIVE ME 20!", "NO PAIN NO GAIN!" }, Effects = { Pin = true } },
}

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local function spotAnim()
	local f = {
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.6, y = 0.5 }, LS = { p = 1.6, y = 0.5 }, RJ = { ln = 0.45 }, RH = { p = 0.55 }, LH = { p = 0.55 } },
		{ t = 0.32, RS = { p = 3.1 }, LS = { p = 3.1 }, RJ = { ln = -0.15 }, RH = { p = 0.1 }, LH = { p = 0.1 } },
	}
	for i = 1, 3 do -- 3 reps : coudes écartés (bras qui descendent) puis poussée
		local t = 0.32 + (i - 1) * 0.25
		table.insert(f, { t = t + 0.12, RS = { p = 2.5, r = -0.65 }, LS = { p = 2.5, r = -0.65 }, RJ = { ln = 0.08 }, RH = { p = 0.35 }, LH = { p = 0.35 } })
		table.insert(f, { t = t + 0.25, RS = { p = 3.2 }, LS = { p = 3.2 }, RJ = { ln = -0.22 }, RH = { p = 0 }, LH = { p = 0 } })
	end
	table.insert(f, { t = 1.15, RS = { p = 3.35 }, LS = { p = 3.35 }, RJ = { ln = -0.55 }, RH = { p = -0.2 }, LH = { p = 0.3 } })
	table.insert(f, { t = 1.25, RS = { p = 1.2, y = 0.2 }, LS = { p = 1.2, y = 0.2 }, RJ = { ln = 0.85 }, LH = { p = 0.85 }, RH = { p = -0.5 } })
	table.insert(f, { t = 1.45, RS = { p = 1.25, y = 0.2 }, LS = { p = 1.25, y = 0.2 }, RJ = { ln = 0.75 }, LH = { p = 0.75 }, RH = { p = -0.45 } })
	table.insert(f, { t = 1.6 })
	return f
end

local function shakeAnim()
	local f = { { t = 0 } }
	for i = 1, 5 do -- secoue le shaker comme un fou
		local up = i % 2 == 0
		table.insert(f, { t = i * 0.07, RS = { p = up and 2.4 or 1.5, y = 0.5 }, LS = { p = 0.3, r = -0.3 }, RJ = { ln = up and -0.1 or 0.1, sd = up and 0.08 or -0.08 }, RH = { p = up and 0.1 or -0.1 } })
	end
	table.insert(f, { t = 0.48, RS = { p = 2.85, y = 0.9 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = -0.55 } }) -- glou glou
	table.insert(f, { t = 0.58, RS = { p = 2.9, y = 0.9 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = -0.6 } })
	table.insert(f, { t = 0.68, RS = { p = 0.4, r = -1.5, y = -1.0 }, LS = { p = 0.4, r = -1.5, y = -1.0 }, RJ = { ln = 0.25 }, RH = { r = -0.35 }, LH = { r = -0.35 } }) -- double biceps
	table.insert(f, { t = 1.0, RS = { p = 0.45, r = -1.55, y = -1.1 }, LS = { p = 0.45, r = -1.55, y = -1.1 }, RJ = { ln = 0.3 }, RH = { r = -0.35 }, LH = { r = -0.35 } })
	table.insert(f, { t = 1.15 })
	return f
end

local function whirlAnim()
	local f = { { t = 0 }, { t = 0.1, RS = { p = 0.9, r = -1.2 }, LS = { p = 0.9, r = -1.2 }, RJ = { ln = 0.1 } } }
	local tw = 0
	for i = 1, 12 do -- 4 tours sur lui-même en sautillant
		tw += 2.1
		local hop = i % 2 == 0
		table.insert(f, { t = 0.1 + i * 0.085, RS = { p = 0.9, r = -1.3 }, LS = { p = 0.9, r = -1.3 }, RJ = { tw = tw, ln = hop and 0.15 or 0 }, RH = { p = hop and 0.5 or 0.1 }, LH = { p = hop and 0.5 or 0.1 } })
	end
	table.insert(f, { t = 1.13, RS = { p = 2.8, r = -0.6 }, LS = { p = 2.8, r = -0.6 }, RJ = { tw = 0, ln = -0.25 } })
	table.insert(f, { t = 1.3, RS = { p = 2.7, r = -0.6 }, LS = { p = 2.7, r = -0.6 }, RJ = { ln = -0.2 } })
	table.insert(f, { t = 1.45 })
	return f
end

M.Anims = {
	FitSwing = { -- kettlebell entre les jambes (hanches en arrière), coup de hanche explosif, le poids monte au-dessus de la tête
		{ t = 0 },
		{ t = 0.12, RS = { p = 0.6, y = 0.3 }, LS = { p = 0.6, y = 0.3 }, RJ = { ln = 0.3 } },
		{ t = 0.3, RS = { p = -0.6, y = 0.3 }, LS = { p = -0.6, y = 0.3 }, RJ = { ln = 0.9 }, RH = { p = 0.65, r = -0.2 }, LH = { p = 0.65, r = -0.2 } },
		{ t = 0.38, RS = { p = 1.75, y = 0.3 }, LS = { p = 1.75, y = 0.3 }, RJ = { ln = -0.35 }, RH = { p = -0.2 }, LH = { p = -0.2 } },
		{ t = 0.47, RS = { p = 2.7, y = 0.3 }, LS = { p = 2.7, y = 0.3 }, RJ = { ln = -0.5 }, RH = { p = -0.15 }, LH = { p = -0.15 } },
		{ t = 0.7, RS = { p = 2.45 }, LS = { p = 2.45 }, RJ = { ln = -0.35 } },
		{ t = 0.86 },
	},
	FitBall = { -- ballon armé contre la poitrine, gros pas en avant et passe explosive à deux mains
		{ t = 0 },
		{ t = 0.12, RS = { p = 1.2, y = 0.9 }, LS = { p = 1.2, y = 0.9 }, RJ = { ln = -0.2 }, RH = { p = -0.1 }, LH = { p = 0.2 } },
		{ t = 0.2, RS = { p = 1.05, y = 1.0 }, LS = { p = 1.05, y = 1.0 }, RJ = { ln = -0.32 }, RH = { p = -0.15 }, LH = { p = 0.25 } },
		{ t = 0.27, RS = { p = 1.65, y = 0.15 }, LS = { p = 1.65, y = 0.15 }, RJ = { ln = 0.5 }, LH = { p = 0.85 }, RH = { p = -0.55 } },
		{ t = 0.5, RS = { p = 1.6, y = 0.15 }, LS = { p = 1.6, y = 0.15 }, RJ = { ln = 0.42 }, LH = { p = 0.75 }, RH = { p = -0.5 } },
		{ t = 0.65 },
	},
	FitSpot = spotAnim(), -- saisie, soulève au-dessus de la tête, 3 reps, lancer
	FitShake = shakeAnim(), -- secoue le shaker, boit, double biceps
	FitWhirl = whirlAnim(), -- bras écartés, 4 tours en sautillant, bras levés à la fin
	FitPushUp = { -- bras au ciel, plonge en planche, descend, POUSSE (impact), se relève bras levés
		{ t = 0 },
		{ t = 0.15, RS = { p = 2.8 }, LS = { p = 2.8 }, RJ = { ln = -0.3 }, RH = { p = 0.3 }, LH = { p = 0.3 } },
		{ t = 0.3, RS = { p = 1.35, r = -0.3 }, LS = { p = 1.35, r = -0.3 }, RJ = { ln = 1.3 }, RH = { p = -0.2 }, LH = { p = -0.2 } },
		{ t = 0.42, RS = { p = 1.05, r = -0.55 }, LS = { p = 1.05, r = -0.55 }, RJ = { ln = 1.48 }, RH = { p = -0.25 }, LH = { p = -0.25 } },
		{ t = 0.47, RS = { p = 1.6, r = -0.1 }, LS = { p = 1.6, r = -0.1 }, RJ = { ln = 1.0 }, RH = { p = -0.1 }, LH = { p = -0.1 } },
		{ t = 0.85, RS = { p = 1.55, r = -0.1 }, LS = { p = 1.55, r = -0.1 }, RJ = { ln = 1.05 } },
		{ t = 1.0, RS = { p = 2.6, r = -0.5 }, LS = { p = 2.6, r = -0.5 }, RJ = { ln = -0.3 } },
		{ t = 1.15 },
	},
}

------------------------------------------------------------------------
-- Accessoires de main
------------------------------------------------------------------------
M.Props = {
	FitKettlebell = { -- kettlebell géant tenu à deux mains
		{ Vector3.new(1.5, 0.3, 0.3), CFrame.new(-0.75, -1.25, 0), IRON },
		{ Vector3.new(0.3, 0.9, 0.3), CFrame.new(-0.1, -1.6, 0), IRON },
		{ Vector3.new(0.3, 0.9, 0.3), CFrame.new(-1.4, -1.6, 0), IRON },
		{ Vector3.new(2.2, 2.2, 2.2), CFrame.new(-0.75, -2.8, 0), IRON, BALL },
		{ Vector3.new(0.35, 2.25, 2.25), CFrame.new(-0.75, -2.8, 0) * ALONG_Z, LIME, CYL },
	},
	FitMedBall = { -- médecine-ball
		{ Vector3.new(1.9, 1.9, 1.9), CFrame.new(-0.75, -1.5, -0.75), Color3.fromRGB(80, 80, 92), BALL },
		{ Vector3.new(0.3, 1.95, 1.95), CFrame.new(-0.75, -1.5, -0.75), LIME, CYL },
	},
	FitShaker = { -- shaker de protéines
		{ Vector3.new(1.6, 0.85, 0.85), CFrame.new(0, -1.75, 0) * ALONG_Y, SHAKE, CYL },
		{ Vector3.new(0.4, 0.9, 0.9), CFrame.new(0, -2.7, 0) * ALONG_Y, DARK, CYL },
		{ Vector3.new(0.3, 0.3, 0.3), CFrame.new(0, -3.0, -0.2) * ALONG_Y, LIME, CYL },
		{ Vector3.new(0.5, 0.9, 0.9), CFrame.new(0, -1.3, 0) * ALONG_Y, LIME, CYL },
	},
	FitRope = { -- poignées de corde à sauter
		{ Vector3.new(0.32, 1.0, 0.32), CFrame.new(0, -1.35, 0), ROPE },
		{ Vector3.new(0.36, 0.2, 0.36), CFrame.new(0, -1.9, 0), DARK },
		{ Vector3.new(0.12, 1.2, 0.12), CFrame.new(0, -2.5, 0.2) * CFrame.Angles(0.4, 0, 0), ROPE },
	},
}

------------------------------------------------------------------------
-- Accessoires permanents : bandeau, sifflet, bracelets, cheveux ras ; kettlebell à la main droite
------------------------------------------------------------------------
function M.Identity(f, head, torso, c, prop)
	prop(f, head, Vector3.new(1.3, 0.2, 1.3), CFrame.new(0, 0.62, 0), Color3.fromRGB(45, 35, 30)) -- cheveux ras
	prop(f, head, Vector3.new(1.34, 0.28, 1.34), CFrame.new(0, 0.38, 0), WHITE) -- bandeau
	prop(f, head, Vector3.new(1.35, 0.1, 1.35), CFrame.new(0, 0.38, 0), LIME)
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.35, 0.08, 0.06), CFrame.new(0.25 * s, 0.32, -0.62) * CFrame.Angles(0, 0, 0.25 * s), Color3.fromRGB(45, 35, 30)) -- sourcils déterminés
		local a = c:FindFirstChild(s < 0 and "Left Arm" or "Right Arm")
		if a then
			prop(f, a, Vector3.new(1.08, 0.35, 1.08), CFrame.new(0, -0.65, 0), LIME) -- bracelets
		end
		prop(f, torso, Vector3.new(0.08, 1.0, 0.06), CFrame.new(0.28 * s, 0.5, -0.54) * CFrame.Angles(0, 0, -0.35 * s), WHITE) -- cordon du sifflet
	end
	prop(f, torso, Vector3.new(0.45, 0.28, 0.3), CFrame.new(0, 0.0, -0.62), SILVER) -- sifflet
	prop(f, torso, Vector3.new(0.2, 0.15, 0.25), CFrame.new(0.28, 0.0, -0.62), SILVER)
end

M.Signature = { Hand = "Right", Build = function(f, a, prop) -- kettlebell
	prop(f, a, Vector3.new(0.25, 0.25, 0.9), CFrame.new(0, -1.05, 0), IRON)
	prop(f, a, Vector3.new(1.3, 1.3, 1.3), CFrame.new(0, -1.85, 0), IRON, BALL)
	prop(f, a, Vector3.new(0.25, 1.33, 1.33), CFrame.new(0, -1.85, 0), LIME, CYL)
end }

-- Transformation : casque audio géant, ceinture de champion, épaules gonflées, veines
function M.Transform(f, head, torso, c, prop)
	prop(f, head, Vector3.new(1.5, 0.22, 0.3), CFrame.new(0, 0.78, 0), DARK) -- arceau
	for _, s in ipairs({ -1, 1 }) do
		prop(f, head, Vector3.new(0.45, 1.0, 1.0), CFrame.new(0.72 * s, 0.1, 0), DARK, CYL) -- écouteurs
		prop(f, head, Vector3.new(0.47, 0.6, 0.6), CFrame.new(0.74 * s, 0.1, 0), LIME, CYL)
		prop(f, torso, Vector3.new(1.3, 1.1, 1.3), CFrame.new(1.05 * s, 0.85, 0), LIME, BALL) -- épaules gonflées
		prop(f, torso, Vector3.new(0.08, 0.6, 0.06), CFrame.new(0.35 * s, 1.0, -0.6) * CFrame.Angles(0, 0, 0.3 * s), Color3.fromRGB(230, 70, 60)) -- veines
	end
	prop(f, torso, Vector3.new(2.1, 0.5, 1.1), CFrame.new(0, -0.8, 0), Color3.fromRGB(180, 30, 30)) -- ceinture de champion
	prop(f, torso, Vector3.new(1.0, 0.75, 0.12), CFrame.new(0, -0.8, -0.58), GOLD)
	prop(f, torso, Vector3.new(0.5, 0.4, 0.13), CFrame.new(0, -0.8, -0.6), Color3.fromRGB(255, 240, 150))
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
	return p
end

M.Kinds = {
	-- Medicine Ball : ballon lourd qui traverse les collègues et rebondit sur 2 murs
	FitBall = function(attacker, cfg, aim, api)
		task.wait(0.26)
		if not ready(attacker, api) then
			return
		end
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		Kit.projectile(attacker, {
			origin = root.Position + Vector3.new(0, 0.6, 0) + dir * 2.5, dir = dir, speed = cfg.Speed, range = cfg.Range, bounces = cfg.Bounces,
			size = Vector3.new(2.2, 2.2, 2.2), color = Color3.fromRGB(80, 80, 92), shape = BALL, spin = 0,
			decorate = function(part)
				local band = decor(part, Vector3.new(0.35, 2.25, 2.25), CFrame.new(), LIME, CYL)
				local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
				a0.Position, a1.Position = Vector3.new(0, 0.9, 0), Vector3.new(0, -0.9, 0)
				a0.Parent, a1.Parent = part, part
				local tr = Instance.new("Trail")
				tr.Attachment0, tr.Attachment1 = a0, a1
				tr.Lifetime = 0.3
				tr.Color = ColorSequence.new(LIME)
				tr.Transparency = NumberSequence.new(0.3, 1)
				tr.LightEmission = 0.5
				tr.Parent = part
				band.Name = "Band"
			end,
			onHit = function(v, pos, vel)
				api.hit(attacker, v, cfg, api.flat(vel, dir), { hitPos = pos })
				Kit.fx({ id = "FitBoof", p = pos })
				return true -- continue (traverse)
			end,
		})
	end,

	-- Spot Me! : saisie, développé-couché de la victime au-dessus de la tête (3 reps), puis lancer
	FitSpot = function(attacker, cfg, aim, api)
		task.wait(0.12)
		if not ready(attacker, api) then
			return
		end
		local RunService = game:GetService("RunService")
		local root = Kit.root(attacker)
		local victim = api.Hitbox.box(root.CFrame * CFrame.new(0, 0, -cfg.HitboxOffset), cfg.HitboxSize, attacker, 1)[1]
		if not victim or Kit.isProtected(victim) then
			return
		end
		local vh = victim:FindFirstChildOfClass("Humanoid")
		api.CharacterState.stun(victim, 0.2 + cfg.Reps * cfg.RepTime + 0.7)
		local release, att = Kit.holdAt(victim, attacker, Vector3.new(0, 2, -2.5))
		Kit.fx({ id = "FitGrab", a = attacker, v = victim })
		local t0 = os.clock()
		while os.clock() - t0 < 0.2 and att.Parent do
			local k = (os.clock() - t0) / 0.2
			att.Position = Vector3.new(0, 2 + 3.2 * k, -2.5 + 2 * k)
			RunService.Heartbeat:Wait()
		end
		for i = 1, cfg.Reps do
			local t1 = os.clock()
			while os.clock() - t1 < cfg.RepTime and att.Parent do
				local k = (os.clock() - t1) / cfg.RepTime
				att.Position = Vector3.new(0, 5.2 - math.sin(k * math.pi) * 1.5, -0.5)
				RunService.Heartbeat:Wait()
			end
			if not api.CharacterState.isAlive(attacker) or not api.CharacterState.isAlive(victim) then
				break
			end
			Kit.fx({ id = "FitRep", p = Kit.root(victim).Position, n = i })
			api.hit(attacker, victim, cfg, root.CFrame.LookVector, { Damage = cfg.RepDamage, Knockback = 0, KnockUp = 0, Stun = 0.6, Category = "Light", Power = 0.2, Words = { tostring(i) .. "!" } })
		end
		release(true)
		if api.CharacterState.isAlive(attacker) and api.CharacterState.isAlive(victim) then
			api.hit(attacker, victim, cfg, root.CFrame.LookVector, { Knockback = cfg.ThrowKnockback, KnockUp = cfg.ThrowUp })
		end
		task.delay(0.6, function()
			if vh and vh.Parent and vh.Health > 0 and not api.CharacterState.isStunned(victim) then
				vh.PlatformStand = false
			end
		end)
	end,

	-- Protein Shake : soin + buff (dégâts / résistance au recul, voir ServerInit) + onde de flex
	FitShake = function(attacker, cfg, aim, api)
		task.wait(0.62)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		local root = Kit.root(attacker)
		local hum = attacker:FindFirstChildOfClass("Humanoid")
		hum.Health = math.min(hum.MaxHealth, hum.Health + cfg.Heal)
		attacker:SetAttribute("FitPumpUntil", api.now() + cfg.BuffTime)
		Kit.fx({ id = "FitGains", a = attacker, p = root.Position, r = cfg.Radius, heal = cfg.Heal })
		for _, v in ipairs(Kit.inCircle(attacker, root.Position, cfg.Radius, 7)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - root.Position, root.CFrame.LookVector))
		end
	end,

	-- Jump Rope Whirlwind : 6 coups de corde tout autour, le dernier éjecte
	FitWhirl = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		Kit.fx({ id = "Telegraph", p = Kit.ground(root.Position), r = cfg.Radius, dur = 0.15, a = attacker })
		Kit.fx({ id = "FitRopeFX", a = attacker, r = cfg.Radius, dur = cfg.Hits * cfg.Interval + 0.15 })
		task.wait(0.12)
		for i = 1, cfg.Hits do
			if not ready(attacker, api) then
				return
			end
			local over = (i == cfg.Hits) and cfg.Final or nil
			for _, v in ipairs(Kit.inCircle(attacker, root.Position, cfg.Radius, 6)) do
				api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - root.Position, root.CFrame.LookVector), over)
			end
			if i < cfg.Hits then
				task.wait(cfg.Interval)
			end
		end
	end,

	-- Push-Up Shockwave : pompe géante, l'onde PLAQUE au sol tout le monde autour
	FitPushUp = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local ground = Kit.ground(root.Position)
		Kit.fx({ id = "Telegraph", p = ground, r = cfg.Radius, dur = cfg.Windup, a = attacker })
		task.wait(cfg.Windup)
		if not api.CharacterState.isAlive(attacker) then
			return
		end
		ground = Kit.ground(root.Position)
		Kit.fx({ id = "FitQuake", p = ground, r = cfg.Radius, a = attacker })
		for _, v in ipairs(Kit.inCircle(attacker, ground, cfg.Radius, 8)) do
			api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - ground, root.CFrame.LookVector))
		end
		api.ZoneService.shatterAround(ground, cfg.Radius * 0.7, Vector3.new(0, 30, 0))
	end,
}

------------------------------------------------------------------------
-- Passif (serveur) : No Pain No Gain + buff du Protein Shake
------------------------------------------------------------------------
local function lowHP(c)
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and hum.Health < hum.MaxHealth * 0.5
end

function M.ServerInit(api)
	local function now()
		return workspace:GetServerTimeNow()
	end
	table.insert(api.CombatService.damageMods, function(p)
		local a, v = p.attacker, p.victim
		if a and a:GetAttribute("CharacterName") == "FitnessCoach" then
			if lowHP(a) then
				p.damage *= 1.2
			end
			if (a:GetAttribute("FitPumpUntil") or 0) > now() then
				p.damage *= 1.25
			end
		end
		if v:GetAttribute("CharacterName") == "FitnessCoach" and (v:GetAttribute("FitPumpUntil") or 0) > now() then
			p.knockback = (p.knockback or 0) * 0.7
			p.up = (p.up or 0) * 0.7
		end
	end)
	-- +10 % de vitesse sous 50 % de PV
	task.spawn(function()
		while true do
			task.wait(0.4)
			for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
				local c = pl.Character
				if c and api.CharacterState.isAlive(c) then
					local s = api.CharacterState.get(c)
					local want = c:GetAttribute("CharacterName") == "FitnessCoach" and lowHP(c)
					c:SetAttribute("FitRage", want or nil)
					if want and s.speedMods.FitRage == nil then
						api.CharacterState.setSpeedMod(c, "FitRage", 1.1)
					elseif not want and s.speedMods.FitRage ~= nil then
						api.CharacterState.setSpeedMod(c, "FitRage", nil)
					end
				end
			end
		end
	end)
end

------------------------------------------------------------------------
-- Effets client
------------------------------------------------------------------------
local function sweat(pos, n)
	for _ = 1, n do
		local d = Kit.part({ Shape = BALL, Size = Vector3.one * 0.35, Position = pos, Color = SWEAT, Transparency = 0.1 })
		local dest = pos + Vector3.new(Kit.rng:NextNumber(-2, 2), Kit.rng:NextNumber(0.5, 2), Kit.rng:NextNumber(-2, 2))
		Kit.tween(d, 0.4, { Position = dest, Transparency = 1 })
		game:GetService("Debris"):AddItem(d, 0.42)
	end
end

M.MoveFX = {
	KettlebellSwing = function(c, d, api)
		-- arc de métal qui suit le kettlebell + gros impact devant
		task.delay(0.34, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if not r then
				return
			end
			for i = 0, 7 do
				local a = -1.2 + i * 0.38
				local pos = (r.CFrame * CFrame.new(0, math.sin(a) * 3.5 + 0.5, -math.cos(a) * 3.5)).Position
				local s = api.part({ Size = Vector3.new(2.2, 0.5, 0.9), CFrame = CFrame.lookAt(pos, r.Position) * CFrame.Angles(a, 0, 0), Color = i % 2 == 0 and LIME or LIME2, Transparency = 0.25 })
				api.TweenService:Create(s, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(2.6, 0.1, 0.9) }):Play()
				api.Debris:AddItem(s, 0.32)
			end
			api.CartoonFX.bigImpact(r.Position + r.CFrame.LookVector * 4.5 + Vector3.new(0, 1, 0), r.CFrame.LookVector, 1, LIME)
			api.CartoonFX.shockwave(r.Position + r.CFrame.LookVector * 4 - Vector3.new(0, 2.7, 0), 7, LIME)
			if Kit.mine(c) then
				api.CartoonFX.shake(0.4)
			end
		end)
	end,
	MedicineBall = function(c, d, api)
		task.delay(0.26, function()
			local r = c:FindFirstChild("HumanoidRootPart")
			if r then
				api.CartoonFX.puff(r.Position + r.CFrame.LookVector * 2.5, 1)
				sweat(r.Position + Vector3.new(0, 1.5, 0), 6)
			end
		end)
	end,
	SpotMe = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 4.5, 0), "SPOT ME!", LIME, 2.6, 0.7, 1)
		end
	end,
	ProteinShake = function(c, d, api)
		task.spawn(function()
			for _ = 1, 5 do
				local arm = c:FindFirstChild("Right Arm")
				if not arm then
					return
				end
				local pos = (arm.CFrame * CFrame.new(0, -2.8, 0)).Position
				Kit.cubes(pos, 3, { SHAKE, WHITE }, 0.3, 2, 0.3)
				task.wait(0.07)
			end
		end)
	end,
	JumpRopeWhirlwind = function(c, d, api)
		api.afterimages(c, 0.5, LIME)
	end,
	PushUpShockwave = function(c, d, api)
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			Kit.floatText(r.Position + Vector3.new(0, 4.5, 0), "DROP AND GIVE ME 20!", LIME, 3.2, 0.7, 1)
		end
	end,
}

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	local RunService = game:GetService("RunService")
	local Debris = game:GetService("Debris")
	Kit.setupClient()

	Kit.on("FitBoof", function(d)
		CartoonFX.sound("Thud", d.p, 1.1)
		CartoonFX.shockwave(d.p - Vector3.new(0, 1.5, 0), 5, LIME)
		Kit.floatText(d.p + Vector3.new(0, 2.5, 0), "BOOF!", LIME, 2.6, 0.6, 1.5)
	end)

	Kit.on("FitGrab", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if vr then
			CartoonFX.word(vr.Position + Vector3.new(0, 2.5, 0), "LIGHTWEIGHT!", 0.8, "Heavy")
			CartoonFX.alert(d.v)
		end
	end)

	-- compteur de reps
	Kit.on("FitRep", function(d)
		CartoonFX.sound("Thud", d.p, 0.8)
		Kit.floatText(d.p + Vector3.new(0, 3, 0), tostring(d.n) .. (d.n >= 3 and "! BEAST!" or "!"), d.n >= 3 and GOLD or LIME, 2.6 + d.n * 0.4, 0.6, 2)
		sweat(d.p, 5)
		CartoonFX.sparks(d.p, 8, LIME)
	end)

	-- soin + onde de flex
	Kit.on("FitGains", function(d)
		CartoonFX.sound("PowerUp", d.p, 1)
		CartoonFX.shockwave(d.p - Vector3.new(0, 2.7, 0), d.r, LIME)
		CartoonFX.shockwave(d.p - Vector3.new(0, 2.5, 0), d.r * 0.6, SHAKE)
		CartoonFX.sparks(d.p, 24, LIME)
		Kit.floatText(d.p + Vector3.new(0, 4.2, 0), "+" .. tostring(d.heal) .. " GAINS!", LIME2, 3.4, 1, 2)
		if Kit.mine(d.a) then
			CartoonFX.fovKick(8)
		end
	end)

	-- corde à sauter qui tournoie autour de lui (anneau de segments en rotation)
	Kit.on("FitRopeFX", function(d)
		local c = d.a
		local segs = {}
		local n = 18
		for i = 1, n do
			segs[i] = Kit.part({ Size = Vector3.new(0.3, 0.3, d.r * 2 * math.pi / n + 0.2), Color = i % 3 == 0 and ROPE or Color3.fromRGB(255, 160, 80) })
		end
		local t0 = os.clock()
		local lastLash = -1
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			local r = c and c:FindFirstChild("HumanoidRootPart")
			if el > d.dur or not r then
				conn:Disconnect()
				for _, s in ipairs(segs) do
					s:Destroy()
				end
				return
			end
			local spin = el * 26
			local rad = d.r * math.clamp(el / 0.12, 0.2, 1) * 0.92
			for i, s in ipairs(segs) do
				local a = i / n * math.pi * 2 + spin
				local tilt = math.sin(a * 2 + el * 10) * 0.6
				s.CFrame = CFrame.new(r.Position + Vector3.new(math.cos(a) * rad, -1.2 + tilt, math.sin(a) * rad)) * CFrame.Angles(0, -a, 0)
			end
			local lash = math.floor(el / 0.17)
			if lash ~= lastLash then
				lastLash = lash
				CartoonFX.sound("Whoosh", r.Position, 0.7)
				CartoonFX.shockwave(r.Position - Vector3.new(0, 2.7, 0), d.r, lash % 2 == 0 and LIME or ROPE)
			end
		end)
	end)

	-- onde de choc de la pompe : fissures, ondes, gros impact
	Kit.on("FitQuake", function(d)
		CartoonFX.sound("GroundSlam", d.p, 1.4)
		CartoonFX.sound("Rumble", d.p, 1)
		CartoonFX.bigImpact(d.p + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.3, LIME)
		for i = 0, 2 do
			task.delay(i * 0.08, function()
				CartoonFX.shockwave(d.p + Vector3.new(0, 0.2, 0), d.r * (0.5 + i * 0.3), i == 1 and WHITE or LIME)
			end)
		end
		local cracks = {}
		for i = 1, 10 do
			local a = i / 10 * math.pi * 2 + Kit.rng:NextNumber(-0.2, 0.2)
			local len = Kit.rng:NextNumber(d.r * 0.5, d.r * 0.9)
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local cr = Kit.part({ Size = Vector3.new(0.35, 0.08, 0.2), CFrame = CFrame.lookAt(d.p + Vector3.new(0, 0.06, 0), d.p + Vector3.new(0, 0.06, 0) + dir), Color = DARK })
			Kit.tween(cr, 0.15, { Size = Vector3.new(0.35, 0.08, len), CFrame = CFrame.lookAt(d.p + Vector3.new(0, 0.06, 0), d.p + Vector3.new(0, 0.06, 0) + dir) * CFrame.new(0, 0, -len / 2) })
			table.insert(cracks, cr)
		end
		Kit.cubes(d.p + Vector3.new(0, 0.6, 0), 24, { Color3.fromRGB(150, 150, 160), LIME, DARK }, 0.8, 12, 0.6)
		Kit.floatText(d.p + Vector3.new(0, 4.5, 0), "20!", LIME, 4.5, 1, 2.5)
		if Kit.mine(d.a) then
			CartoonFX.shake(1.1)
			CartoonFX.impactFrame(0.9)
		end
		task.delay(1, function()
			for _, cr in ipairs(cracks) do
				Kit.tween(cr, 0.4, { Transparency = 1 })
			end
		end)
		for _, cr in ipairs(cracks) do
			Debris:AddItem(cr, 1.45)
		end
	end)

	-- auras : transformation (étincelles vertes), Protein Shake (GAINS), No Pain No Gain (sueur rouge à bas PV)
	task.spawn(function()
		local tick = 0
		while true do
			task.wait(0.3)
			tick += 1
			local now = workspace:GetServerTimeNow()
			for _, c in ipairs(api.Hitbox.characters()) do
				if c:GetAttribute("CharacterName") == "FitnessCoach" then
					local r = c:FindFirstChild("HumanoidRootPart")
					local head = c:FindFirstChild("Head")
					if r and head then
						if c:GetAttribute("Transformed") then
							sweat(head.Position + Vector3.new(0, 0.6, 0), 2)
						end
						if (c:GetAttribute("FitPumpUntil") or 0) > now then
							CartoonFX.sparks(r.Position + Vector3.new(Kit.rng:NextNumber(-1.5, 1.5), Kit.rng:NextNumber(-1, 2), Kit.rng:NextNumber(-1.5, 1.5)), 4, LIME)
						end
						if c:GetAttribute("FitRage") and tick % 6 == 0 then
							Kit.floatText(head.Position + Vector3.new(0, 2, 0), "NO PAIN NO GAIN!", Color3.fromRGB(255, 80, 60), 2.4, 0.8, 1.5)
						end
					end
				end
			end
		end
	end)
end

return M
