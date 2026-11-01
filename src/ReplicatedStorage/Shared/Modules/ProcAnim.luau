--[[
	ProcAnim — animations R6 procédurales (client uniquement).
	On modifie le C0 des Motor6D (épaules, hanches, RootJoint) par-dessus les animations par défaut.
	Aucun asset d'animation à publier : tout est défini ici en keyframes.

	Angles (radians), identiques pour les membres gauche et droit (le miroir est géré ici) :
		p = pitch : vers l'avant (0 = le long du corps, 1.57 = tendu devant, 3.1 = au-dessus de la tête)
		y = twist du membre, r = écarter sur le côté (négatif = vers l'extérieur)
	Joints : RS / LS (épaules), RH / LH (hanches), RJ (buste : tw = rotation, ln = penché en avant, sd = penché sur le côté)
	Le hit-stop gèle le temps de l'animation (ProcAnim.freeze).
	Ajouter une animation = ajouter une entrée dans ANIMS (aucun autre code).
]]
local RunService = game:GetService("RunService")

local ProcAnim = {}

local LIMBS = { "RS", "LS", "RH", "LH" }
local ZERO_LIMB = { p = 0, y = 0, r = 0 }
local ZERO_RJ = { tw = 0, ln = 0, sd = 0 }

-- poses tenues en permanence
local HOLD_POSES = {
	Hand = { RS = { p = 0.45, y = 0.1 } },
	TwoHands = { RS = { p = 2.7, y = 0.25 }, LS = { p = 2.7, y = 0.25 } },
	Block = { RS = { p = 1.65, y = 0.95, r = 0.15 }, LS = { p = 1.65, y = 0.95, r = 0.15 }, RJ = { ln = 0.12 }, RH = { p = 0.25 }, LH = { p = -0.15 } },
	Stunned = { RS = { p = 0.25, r = -0.25 }, LS = { p = 0.25, r = -0.25 }, RJ = { ln = 0.25, sd = 0.1 } },
}

-- générateurs d'animations répétitives (rafales, tremblements, course)
local function genFlurry(n, step, t0)
	local f = { { t = 0 }, { t = t0, RS = { p = -0.5 }, LS = { p = 0.9, y = 0.6 }, RJ = { tw = -0.5, ln = 0.2 }, RH = { p = -0.4 }, LH = { p = 0.7 } } }
	local t = t0
	for i = 1, n do
		t += step
		local right = i % 2 == 1
		local ext = (i % 3 == 0) and 2.1 or 1.9
		table.insert(f, { t = t, RS = { p = right and ext or 0.4, y = right and 0.15 or 0.6 }, LS = { p = right and 0.4 or ext, y = right and 0.6 or 0.15 }, RJ = { tw = right and 0.5 or -0.5, ln = 0.32, sd = right and 0.05 or -0.05 }, RH = { p = -0.45 }, LH = { p = 0.75 } })
	end
	return f, t
end

local function genJitter(f, from, to, base, amp)
	local t, s = from, 1
	while t < to do
		t += 0.055
		s = -s
		local k = {}
		for j, v in pairs(base) do
			local c = table.clone(v)
			if j == "RJ" then
				c.sd = (c.sd or 0) + 0.07 * s * amp
				c.tw = (c.tw or 0) + 0.09 * s * amp
			else
				c.p = (c.p or 0) + 0.08 * s * amp
			end
			k[j] = c
		end
		k.t = math.min(t, to)
		table.insert(f, k)
	end
	return f
end

local function genRun(f, from, to, step, arms, lean)
	local t, s = from, 1
	while t < to do
		t += step
		s = -s
		local k = { t = math.min(t, to), RJ = { ln = lean, tw = 0.08 * s }, RH = { p = 1.0 * s }, LH = { p = -1.0 * s } }
		for j, v in pairs(arms) do
			k[j] = v
		end
		table.insert(f, k)
	end
	return f
end

local function overtimeFlurry()
	local f, t = genFlurry(7, 0.06, 0.06)
	table.insert(f, { t = t + 0.07, RS = { p = -1.0, r = -0.2 }, LS = { p = 1.0, y = 0.6 }, RJ = { tw = -0.85, ln = 0.5 }, RH = { p = 0.65 }, LH = { p = 0.65 } }) -- armé bas
	table.insert(f, { t = t + 0.14, RS = { p = 3.2, y = 0.2 }, LS = { p = -0.5, r = -0.3 }, RJ = { tw = 0.85, ln = -0.5 }, RH = { p = -0.35 }, LH = { p = 1.35 } }) -- uppercut + genou
	table.insert(f, { t = t + 0.36, RS = { p = 3.05, y = 0.2 }, LS = { p = -0.45, r = -0.3 }, RJ = { tw = 0.75, ln = -0.42 }, RH = { p = -0.3 }, LH = { p = 1.15 } })
	table.insert(f, { t = t + 0.52 })
	return f
end

local function espressoCounter()
	local f = {
		{ t = 0 },
		{ t = 0.1, RS = { p = 2.7, y = 0.95 }, LS = { p = 0.3, r = -0.5 }, RJ = { ln = -0.45 }, LH = { p = 0.2 } }, -- cul sec
		{ t = 0.24, RS = { p = 2.9, y = 0.95 }, LS = { p = 0.35, r = -0.6 }, RJ = { ln = -0.6 }, LH = { p = 0.25 } },
		{ t = 0.3, RS = { p = 1.3, y = 0.7 }, LS = { p = 1.45, y = 0.6 }, RJ = { ln = 0.3, tw = -0.15 }, RH = { p = 0.5, r = -0.2 }, LH = { p = -0.25, r = -0.2 } }, -- garde nerveuse
	}
	genJitter(f, 0.3, 1.05, { RS = { p = 1.3, y = 0.7 }, LS = { p = 1.45, y = 0.6 }, RJ = { ln = 0.3, tw = -0.15 }, RH = { p = 0.5, r = -0.2 }, LH = { p = -0.25, r = -0.2 } }, 1)
	table.insert(f, { t = 1.2 })
	return f
end

local function powerWash()
	local f = { { t = 0 }, { t = 0.1, RS = { p = 1.6, y = 0.35 }, LS = { p = 1.55, y = 0.65 }, RJ = { ln = -0.1 }, RH = { p = -0.55, r = -0.15 }, LH = { p = 0.6, r = -0.15 } } }
	genJitter(f, 0.1, 1.6, { RS = { p = 1.55, y = 0.35 }, LS = { p = 1.5, y = 0.65 }, RJ = { ln = -0.14 }, RH = { p = -0.55, r = -0.15 }, LH = { p = 0.6, r = -0.15 } }, 0.8)
	table.insert(f, { t = 1.78 })
	return f
end

local function cartPush()
	local arms = { RS = { p = 1.25, y = 0.25 }, LS = { p = 1.25, y = 0.25 } }
	local f = { { t = 0 }, { t = 0.1, RS = { p = 1.0, y = 0.25 }, LS = { p = 1.0, y = 0.25 }, RJ = { ln = 0.75 }, RH = { p = 1.1 }, LH = { p = -0.7 } } }
	genRun(f, 0.1, 0.9, 0.11, arms, 0.7)
	table.insert(f, { t = 0.98, RS = { p = 2.0, y = 0.4 }, LS = { p = 2.0, y = 0.4 }, RJ = { ln = 0.25 }, RH = { p = -0.5 }, LH = { p = 1.0 } }) -- grosse poussée finale
	table.insert(f, { t = 1.2, RS = { p = 1.9, y = 0.4 }, LS = { p = 1.9, y = 0.4 }, RJ = { ln = 0.2 }, RH = { p = -0.4 }, LH = { p = 0.8 } })
	table.insert(f, { t = 1.35 })
	return f
end

local function coffeeRun()
	local arms = { RS = { p = 1.9, y = 0.1 }, LS = { p = -1.1 } }
	local f = { { t = 0 }, { t = 0.05, RS = { p = -0.6, r = -0.2 }, LS = { p = -0.8 }, RJ = { ln = 0.75, tw = -0.3 }, RH = { p = 1.0 }, LH = { p = -0.5 } } }
	genRun(f, 0.05, 0.27, 0.065, arms, 0.6)
	table.insert(f, { t = 0.33, RS = { p = 2.35, y = 0.2 }, LS = { p = -0.6, r = -0.4 }, RJ = { ln = 0.45, tw = 0.55 }, RH = { p = -0.5 }, LH = { p = 0.9 } }) -- percute
	table.insert(f, { t = 0.44, RS = { p = 2.1, y = 0.2 }, LS = { p = -0.5, r = -0.4 }, RJ = { ln = 0.35, tw = 0.45 }, RH = { p = -0.3 }, LH = { p = 0.6 } })
	table.insert(f, { t = 0.58 })
	return f
end

local ANIMS = {
	-- M1 au sol
	Punch1 = { -- jab lourd : armé en arrière, coup qui dépasse, buste qui suit
		{ t = 0 },
		{ t = 0.05, RS = { p = -0.7, r = -0.2 }, LS = { p = 0.9, y = 0.7 }, RJ = { tw = -0.45, ln = -0.05 }, LH = { p = 0.35 }, RH = { p = -0.1 } },
		{ t = 0.1, RS = { p = 1.95, y = 0.25 }, LS = { p = 0.6, y = 0.7 }, RJ = { tw = 0.75, ln = 0.3 }, LH = { p = 0.75 }, RH = { p = -0.5 } },
		{ t = 0.16, RS = { p = 1.8, y = 0.2 }, LS = { p = 0.6, y = 0.7 }, RJ = { tw = 0.65, ln = 0.26 }, LH = { p = 0.7 }, RH = { p = -0.45 } },
		{ t = 0.3 },
	},
	Punch2 = { -- crochet gauche appuyé
		{ t = 0 },
		{ t = 0.05, LS = { p = 1.0, y = -1.1, r = -0.35 }, RS = { p = 0.9, y = 0.7 }, RJ = { tw = 0.5 }, RH = { p = 0.3 } },
		{ t = 0.11, LS = { p = 1.6, y = 0.95 }, RS = { p = 0.6, y = 0.7 }, RJ = { tw = -0.85, ln = 0.25 }, RH = { p = 0.75 }, LH = { p = -0.45 } },
		{ t = 0.17, LS = { p = 1.5, y = 0.85 }, RS = { p = 0.6, y = 0.7 }, RJ = { tw = -0.75, ln = 0.22 }, RH = { p = 0.7 }, LH = { p = -0.4 } },
		{ t = 0.3 },
	},
	Punch3 = { -- coup au corps : on plonge sous la garde puis on remonte
		{ t = 0 },
		{ t = 0.06, RS = { p = -0.5 }, RJ = { tw = -0.55, ln = 0.5 }, LH = { p = 0.6 }, RH = { p = 0.35 }, LS = { p = 1.0, y = 0.6 } },
		{ t = 0.13, RS = { p = 2.4, y = 0.35 }, LS = { p = 0.5, y = 0.6 }, RJ = { tw = 0.7, ln = -0.15 }, LH = { p = 0.7 }, RH = { p = -0.35 } },
		{ t = 0.2, RS = { p = 2.25, y = 0.3 }, LS = { p = 0.5, y = 0.6 }, RJ = { tw = 0.6, ln = -0.1 }, LH = { p = 0.6 }, RH = { p = -0.3 } },
		{ t = 0.32 },
	},
	Punch4 = { -- FINISHER : grosse rotation, coup de pied retourné très appuyé
		{ t = 0 },
		{ t = 0.12, RH = { p = 0.3, r = -0.7 }, LH = { p = 0.4 }, RJ = { tw = -1.0, ln = 0.1 }, RS = { p = 0.4, r = -0.9 }, LS = { p = 0.4, r = -0.9 } },
		{ t = 0.2, RH = { p = 1.95, r = -0.4 }, RJ = { tw = 1.25, ln = -0.45, sd = -0.2 }, RS = { p = 0.4, r = -1.3 }, LS = { p = 0.4, r = -1.3 }, LH = { p = -0.2 } },
		{ t = 0.4, RH = { p = 1.75, r = -0.35 }, RJ = { tw = 1.1, ln = -0.35, sd = -0.15 }, RS = { p = 0.35, r = -1.2 }, LS = { p = 0.35, r = -1.2 } },
		{ t = 0.62 },
	},
	RisingDuo = { -- on attrape et on s'envole avec la victime : double uppercut + genou
		{ t = 0 },
		{ t = 0.06, RS = { p = -0.6 }, LS = { p = -0.6 }, RJ = { ln = 0.5 }, RH = { p = 0.5 }, LH = { p = 0.5 } },
		{ t = 0.16, RS = { p = 3.1, y = 0.2 }, LS = { p = 3.1, y = 0.2 }, RJ = { ln = -0.4 }, RH = { p = 1.5 }, LH = { p = -0.3 } },
		{ t = 0.5, RS = { p = 2.9, y = 0.2 }, LS = { p = 2.9, y = 0.2 }, RJ = { ln = -0.3 }, RH = { p = 1.3 } },
		{ t = 0.65 },
	},
	Uppercut = {
		{ t = 0 },
		{ t = 0.06, RS = { p = -0.5 }, RJ = { ln = 0.4, tw = -0.35 }, RH = { p = 0.35 }, LH = { p = 0.35 } },
		{ t = 0.14, RS = { p = 3.05, y = 0.2 }, LS = { p = -0.4 }, RJ = { ln = -0.3, tw = 0.45 }, LH = { p = 0.7 }, RH = { p = -0.2 } },
		{ t = 0.32, RS = { p = 3.0, y = 0.2 }, LS = { p = -0.4 }, RJ = { ln = -0.28, tw = 0.4 }, LH = { p = 0.6 } },
		{ t = 0.46 },
	},
	Dropkick = {
		{ t = 0 },
		{ t = 0.06, RJ = { ln = -0.3 }, RH = { p = 0.9 }, LH = { p = 0.8 } },
		{ t = 0.12, RH = { p = 1.65 }, LH = { p = 1.55 }, RJ = { ln = -0.95 }, RS = { p = -0.9, r = -0.4 }, LS = { p = -0.9, r = -0.4 } },
		{ t = 0.42, RH = { p = 1.6 }, LH = { p = 1.5 }, RJ = { ln = -0.9 }, RS = { p = -0.9, r = -0.4 }, LS = { p = -0.9, r = -0.4 } },
		{ t = 0.56 },
	},
	-- jongle aérien
	Air1 = {
		{ t = 0 },
		{ t = 0.06, RS = { p = 1.8, y = 0.2 }, LH = { p = 1.3 }, RJ = { tw = 0.5, ln = 0.2 } },
		{ t = 0.2, RS = { p = 1.7, y = 0.2 }, LH = { p = 1.2 }, RJ = { tw = 0.45, ln = 0.2 } },
		{ t = 0.27 },
	},
	Air2 = {
		{ t = 0 },
		{ t = 0.06, LS = { p = 1.8, y = 0.2 }, RH = { p = 1.3 }, RJ = { tw = -0.5, ln = 0.2 } },
		{ t = 0.2, LS = { p = 1.7, y = 0.2 }, RH = { p = 1.2 }, RJ = { tw = -0.45, ln = 0.2 } },
		{ t = 0.27 },
	},
	Air3 = {
		{ t = 0 },
		{ t = 0.05, RS = { p = 2.6 }, LS = { p = 2.6 }, RJ = { ln = -0.2 } },
		{ t = 0.11, RS = { p = 1.6, y = 0.3 }, LS = { p = 1.6, y = 0.3 }, RJ = { ln = 0.35 }, RH = { p = 0.8 }, LH = { p = 0.8 } },
		{ t = 0.27 },
	},
	Downslam = {
		{ t = 0 },
		{ t = 0.08, RS = { p = 3.25 }, LS = { p = 3.25 }, RJ = { ln = -0.35 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
		{ t = 0.16, RS = { p = 0.9, y = 0.3 }, LS = { p = 0.9, y = 0.3 }, RJ = { ln = 0.75 }, RH = { p = 0.9 }, LH = { p = 0.9 } },
		{ t = 0.36, RS = { p = 0.9, y = 0.3 }, LS = { p = 0.9, y = 0.3 }, RJ = { ln = 0.7 } },
		{ t = 0.5 },
	},
	-- objets
	Jab = {
		{ t = 0 },
		{ t = 0.05, RS = { p = -0.3 }, RJ = { tw = -0.25 }, LH = { p = 0.25 } },
		{ t = 0.1, RS = { p = 1.65, y = 0.1 }, RJ = { tw = 0.45, ln = 0.15 }, LH = { p = 0.5 }, RH = { p = -0.3 } },
		{ t = 0.2, RS = { p = 1.55, y = 0.1 }, RJ = { tw = 0.4, ln = 0.12 }, LH = { p = 0.45 } },
		{ t = 0.3 },
	},
	OverheadSwing = {
		{ t = 0 },
		{ t = 0.15, RS = { p = 3.35, y = 0.2 }, LS = { p = 2.2 }, RJ = { ln = -0.35, tw = -0.25 }, RH = { p = -0.2 } },
		{ t = 0.24, RS = { p = 0.8, y = 0.3 }, LS = { p = 0.4 }, RJ = { ln = 0.6, tw = 0.35 }, LH = { p = 0.65 }, RH = { p = -0.45 } },
		{ t = 0.4, RS = { p = 0.85, y = 0.3 }, RJ = { ln = 0.5, tw = 0.3 }, LH = { p = 0.6 }, RH = { p = -0.4 } },
		{ t = 0.55 },
	},
	SideSwing = {
		{ t = 0 },
		{ t = 0.09, RS = { p = 1.35, y = -1.2, r = -0.3 }, RJ = { tw = -0.75 }, RH = { p = 0.3 } },
		{ t = 0.17, RS = { p = 1.45, y = 1.0 }, RJ = { tw = 0.85, ln = 0.15 }, LH = { p = 0.55 }, RH = { p = -0.3 } },
		{ t = 0.3, RS = { p = 1.4, y = 0.95 }, RJ = { tw = 0.8, ln = 0.12 }, LH = { p = 0.5 } },
		{ t = 0.42 },
	},
	Slam = {
		{ t = 0 },
		{ t = 0.26, RS = { p = 3.3, y = 0.25 }, LS = { p = 3.3, y = 0.25 }, RJ = { ln = -0.35 }, RH = { p = -0.1 } },
		{ t = 0.38, RS = { p = 1.2, y = 0.25 }, LS = { p = 1.2, y = 0.25 }, RJ = { ln = 0.55 }, LH = { p = 0.7 }, RH = { p = -0.4 } },
		{ t = 0.62, RS = { p = 1.25, y = 0.25 }, LS = { p = 1.25, y = 0.25 }, RJ = { ln = 0.45 }, LH = { p = 0.6 } },
		{ t = 0.8 },
	},
	Throw = {
		{ t = 0 },
		{ t = 0.1, RS = { p = 3.1, r = -0.4 }, RJ = { tw = -0.65, ln = -0.15 }, LH = { p = 0.5 }, LS = { p = 1.2 } },
		{ t = 0.17, RS = { p = 1.2, y = 0.3 }, RJ = { tw = 0.75, ln = 0.25 }, LH = { p = 0.65 }, RH = { p = -0.35 } },
		{ t = 0.32, RS = { p = 1.0, y = 0.3 }, RJ = { tw = 0.6, ln = 0.2 }, LH = { p = 0.55 } },
		{ t = 0.45 },
	},
	HeavyThrow = {
		{ t = 0 },
		{ t = 0.15, RS = { p = 3.2 }, LS = { p = 3.2 }, RJ = { ln = -0.35 } },
		{ t = 0.26, RS = { p = 1.6 }, LS = { p = 1.6 }, RJ = { ln = 0.4 }, LH = { p = 0.7 }, RH = { p = -0.3 } },
		{ t = 0.5 },
	},
	Eat = {
		{ t = 0 },
		{ t = 0.12, RS = { p = 2.5, y = 0.7 } },
		{ t = 0.22, RS = { p = 2.3, y = 0.7 }, RJ = { ln = -0.1 } },
		{ t = 0.32, RS = { p = 2.5, y = 0.7 } },
		{ t = 0.45 },
	},
	Dash = {
		{ t = 0 },
		{ t = 0.05, RS = { p = -0.8 }, LS = { p = -0.8 }, RJ = { ln = 0.45 }, RH = { p = -0.4 }, LH = { p = 0.6 } },
		{ t = 0.2, RS = { p = -0.7 }, LS = { p = -0.7 }, RJ = { ln = 0.4 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
		{ t = 0.3 },
	},
	BlockStart = {
		{ t = 0 },
		{ t = 0.06, RS = { p = 1.9, y = 1.0 }, LS = { p = 1.9, y = 1.0 }, RJ = { ln = 0.2 } },
		{ t = 0.12 },
	},
	-- réactions de la victime
	HitLight = {
		{ t = 0 },
		{ t = 0.05, RJ = { ln = -0.35, tw = 0.3 }, RS = { p = 0.5, r = -0.45 }, LS = { p = 0.5, r = -0.45 }, LH = { p = -0.2 } },
		{ t = 0.28 },
	},
	HitLight2 = {
		{ t = 0 },
		{ t = 0.05, RJ = { ln = -0.3, tw = -0.35, sd = 0.15 }, RS = { p = 0.4, r = -0.5 }, LS = { p = 0.6, r = -0.3 }, RH = { p = -0.2 } },
		{ t = 0.28 },
	},
	HitHeavy = {
		{ t = 0 },
		{ t = 0.06, RJ = { ln = -0.65, tw = 0.45 }, RS = { p = 1.3, r = -1.0 }, LS = { p = 1.3, r = -1.0 }, RH = { p = 0.7 }, LH = { p = -0.3 } },
		{ t = 0.3, RJ = { ln = -0.55, tw = 0.4 }, RS = { p = 1.2, r = -0.9 }, LS = { p = 1.2, r = -0.9 }, RH = { p = 0.6 } },
		{ t = 0.5 },
	},
	Launch = {
		{ t = 0 },
		{ t = 0.08, RS = { p = 2.9, r = -0.5 }, LS = { p = 2.9, r = -0.5 }, RJ = { ln = -0.45 }, RH = { p = 0.4 }, LH = { p = -0.2 } },
		{ t = 0.6, RS = { p = 2.6, r = -0.6 }, LS = { p = 2.7, r = -0.4 }, RJ = { ln = -0.4 }, RH = { p = 0.6 }, LH = { p = 0.1 } },
		{ t = 0.8 },
	},
	-- attaques de personnages (génériques)
	CastForward = {
		{ t = 0 },
		{ t = 0.1, RS = { p = 0.6, y = -0.3 }, LS = { p = 0.6, y = -0.3 }, RJ = { ln = -0.15 } },
		{ t = 0.18, RS = { p = 1.65, y = 0.2 }, LS = { p = 1.65, y = 0.2 }, RJ = { ln = 0.25 }, LH = { p = 0.5 }, RH = { p = -0.3 } },
		{ t = 0.4, RS = { p = 1.6, y = 0.2 }, LS = { p = 1.6, y = 0.2 }, RJ = { ln = 0.2 } },
		{ t = 0.55 },
	},
	CastUp = {
		{ t = 0 },
		{ t = 0.12, RS = { p = 3.1 }, LS = { p = 3.1 }, RJ = { ln = -0.3 } },
		{ t = 0.5, RS = { p = 3.0 }, LS = { p = 3.0 }, RJ = { ln = -0.25 } },
		{ t = 0.65 },
	},
	Spin = {
		{ t = 0 },
		{ t = 0.1, RS = { r = -1.3 }, LS = { r = -1.3 }, RJ = { tw = 2.1 } },
		{ t = 0.2, RS = { r = -1.3 }, LS = { r = -1.3 }, RJ = { tw = 4.2 } },
		{ t = 0.3, RS = { r = -1.3 }, LS = { r = -1.3 }, RJ = { tw = 6.28 } },
		{ t = 0.31, RS = { r = -1.3 }, LS = { r = -1.3 }, RJ = { tw = 0 } },
		{ t = 0.42 },
	},
	GroundPound = {
		{ t = 0 },
		{ t = 0.18, RS = { p = 3.2 }, LS = { p = 3.2 }, RJ = { ln = -0.3 }, RH = { p = 0.5 }, LH = { p = 0.5 } },
		{ t = 0.28, RS = { p = 0.5, r = -0.6 }, LS = { p = 0.5, r = -0.6 }, RJ = { ln = 0.7 }, RH = { p = 1.0 }, LH = { p = 1.0 } },
		{ t = 0.5, RS = { p = 0.5, r = -0.6 }, LS = { p = 0.5, r = -0.6 }, RJ = { ln = 0.6 } },
		{ t = 0.65 },
	},
	Grab = {
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.7, y = 0.5 }, LS = { p = 1.7, y = 0.5 }, RJ = { ln = 0.3 }, LH = { p = 0.6 } },
		{ t = 0.3, RS = { p = 3.0 }, LS = { p = 3.0 }, RJ = { ln = -0.4, tw = 0.6 } },
		{ t = 0.45, RS = { p = 1.0 }, LS = { p = 1.0 }, RJ = { ln = 0.5, tw = -0.6 } },
		{ t = 0.65 },
	},
	Flurry = {
		{ t = 0 },
		{ t = 0.05, RS = { p = 1.8 }, LS = { p = 0.4 }, RJ = { tw = 0.4, ln = 0.2 } },
		{ t = 0.1, LS = { p = 1.8 }, RS = { p = 0.4 }, RJ = { tw = -0.4, ln = 0.2 } },
		{ t = 0.15, RS = { p = 1.8, y = 0.3 }, LS = { p = 0.4 }, RJ = { tw = 0.4, ln = 0.2 } },
		{ t = 0.2, LS = { p = 1.8, y = 0.3 }, RS = { p = 0.4 }, RJ = { tw = -0.4, ln = 0.2 } },
		{ t = 0.25, RS = { p = 1.8 }, LS = { p = 0.4 }, RJ = { tw = 0.4, ln = 0.2 } },
		{ t = 0.3, LS = { p = 1.8 }, RS = { p = 0.4 }, RJ = { tw = -0.4, ln = 0.2 } },
		{ t = 0.4 },
	},
	Transform = {
		{ t = 0 },
		{ t = 0.15, RS = { p = 0.4, r = -0.9 }, LS = { p = 0.4, r = -0.9 }, RJ = { ln = 0.4 }, RH = { r = -0.3 }, LH = { r = -0.3 } },
		{ t = 0.5, RS = { p = 2.9, r = -0.6 }, LS = { p = 2.9, r = -0.6 }, RJ = { ln = -0.35 }, RH = { r = -0.3 }, LH = { r = -0.3 } },
		{ t = 0.9, RS = { p = 2.9, r = -0.6 }, LS = { p = 2.9, r = -0.6 }, RJ = { ln = -0.35 } },
		{ t = 1.05 },
	},
	------------------------------------------------------------------
	-- Attaques de personnages : UNE animation unique par attaque
	------------------------------------------------------------------
	-- THE INTERN
	CoffeeRun = coffeeRun(), -- départ accroupi explosif, sprint gobelet en avant, percussion qui dépasse
	PaperJam = { -- bras repliés contre la poitrine, poussée à deux mains, buste et jambe avant qui suivent
		{ t = 0 },
		{ t = 0.08, RS = { p = 0.2, y = -1.0, r = -0.5 }, LS = { p = 0.2, y = -1.0, r = -0.5 }, RJ = { ln = -0.35 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
		{ t = 0.14, RS = { p = 1.9, y = 0.55 }, LS = { p = 1.9, y = 0.55 }, RJ = { ln = 0.5 }, LH = { p = 0.85 }, RH = { p = -0.55 } },
		{ t = 0.22, RS = { p = 1.75, y = 0.5 }, LS = { p = 1.75, y = 0.5 }, RJ = { ln = 0.42 }, LH = { p = 0.75 }, RH = { p = -0.5 } },
		{ t = 0.4, RS = { p = 1.6, y = 0.5 }, LS = { p = 1.6, y = 0.5 }, RJ = { ln = 0.35 }, LH = { p = 0.6 }, RH = { p = -0.4 } },
		{ t = 0.55 },
	},
	StickySlap = { -- bras armé en travers du corps, énorme revers qui dépasse, le buste vrille
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.2, y = 1.4, r = 0.3 }, LS = { p = 0.6, r = -0.3 }, RJ = { tw = 0.85, ln = -0.1 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.14, RS = { p = 1.3, y = 1.5, r = 0.35 }, LS = { p = 0.6, r = -0.3 }, RJ = { tw = 0.95, ln = -0.12 }, RH = { p = 0.35 } },
		{ t = 0.19, RS = { p = 1.6, y = -1.35, r = -0.65 }, LS = { p = -0.35, r = -0.45 }, RJ = { tw = -1.0, ln = 0.32, sd = 0.1 }, RH = { p = -0.45 }, LH = { p = 0.75 } },
		{ t = 0.32, RS = { p = 1.45, y = -1.2, r = -0.55 }, LS = { p = -0.3, r = -0.4 }, RJ = { tw = -0.85, ln = 0.25 }, RH = { p = -0.35 }, LH = { p = 0.6 } },
		{ t = 0.5 },
	},
	EspressoCounter = espressoCounter(), -- espresso cul sec, puis garde qui tremble (caféine)
	EspressoStrike = { -- contre : revers tournoyant derrière l'adversaire
		{ t = 0 },
		{ t = 0.04, RS = { p = 0.4, y = 1.2, r = 0.2 }, LS = { p = 0.8 }, RJ = { tw = 1.15, ln = 0.1 }, RH = { p = 0.4 }, LH = { p = -0.2 } },
		{ t = 0.1, RS = { p = 1.65, y = -1.25, r = -0.7 }, LS = { p = 0.4, r = -0.6 }, RJ = { tw = -1.25, ln = 0.3 }, RH = { p = -0.5 }, LH = { p = 0.85 } },
		{ t = 0.28, RS = { p = 1.5, y = -1.1, r = -0.6 }, LS = { p = 0.4, r = -0.6 }, RJ = { tw = -1.0, ln = 0.22 }, RH = { p = -0.4 }, LH = { p = 0.7 } },
		{ t = 0.45 },
	},
	OvertimeFlurry = overtimeFlurry(), -- 7 coups alternés appuyés, armé très bas puis uppercut + coup de genou
	DeadlineDrop = { -- regarde sa montre, invoque l'échéance bras au ciel, puis abat les bras : BOUM
		{ t = 0 },
		{ t = 0.08, LS = { p = 1.9, y = 1.0 }, RS = { p = 1.5, y = 1.2 }, RJ = { ln = 0.2 }, LH = { p = 0.2 } },
		{ t = 0.14, LS = { p = 1.9, y = 1.0 }, RS = { p = 1.8, y = 1.2 }, RJ = { ln = 0.24 } },
		{ t = 0.2, LS = { p = 1.9, y = 1.0 }, RS = { p = 1.5, y = 1.2 }, RJ = { ln = 0.2 } },
		{ t = 0.32, RS = { p = 3.25, r = -0.35 }, LS = { p = 3.25, r = -0.35 }, RJ = { ln = -0.5 }, RH = { p = -0.25 }, LH = { p = 0.35 } },
		{ t = 0.5, RS = { p = 3.35, r = -0.45 }, LS = { p = 3.35, r = -0.45 }, RJ = { ln = -0.55 }, RH = { p = -0.25 }, LH = { p = 0.35 } },
		{ t = 0.6, RS = { p = 0.75, y = 0.4 }, LS = { p = 0.75, y = 0.4 }, RJ = { ln = 0.85 }, RH = { p = 1.05 }, LH = { p = -0.45 } },
		{ t = 0.85, RS = { p = 0.85, y = 0.4 }, LS = { p = 0.85, y = 0.4 }, RJ = { ln = 0.72 }, RH = { p = 0.9 }, LH = { p = -0.35 } },
		{ t = 1.0 },
	},
	-- THE JANITOR
	MopSweep = { -- accroupi vrillé (anticipation), balayage de 360° jambes écartées qui dépasse, retour
		{ t = 0 },
		{ t = 0.14, RS = { p = 1.0, y = -0.9, r = -0.4 }, LS = { p = 1.3, y = 0.8 }, RJ = { tw = -1.5, ln = 0.6, sd = -0.1 }, RH = { p = 0.9, r = -0.3 }, LH = { p = 0.5, r = -0.3 } },
		{ t = 0.22, RS = { p = 1.1, y = -1.0, r = -0.45 }, LS = { p = 1.35, y = 0.85 }, RJ = { tw = -1.65, ln = 0.65 }, RH = { p = 0.95, r = -0.35 }, LH = { p = 0.55, r = -0.35 } },
		{ t = 0.3, RS = { p = 1.0, y = 0.4 }, LS = { p = 1.0, y = 0.4 }, RJ = { tw = 1.4, ln = 0.6 }, RH = { p = 0.6, r = -0.6 }, LH = { p = 0.6 } },
		{ t = 0.38, RS = { p = 1.0, y = 0.4 }, LS = { p = 1.0, y = 0.4 }, RJ = { tw = 3.5, ln = 0.6 }, RH = { p = 0.6, r = -0.6 }, LH = { p = 0.6 } },
		{ t = 0.46, RS = { p = 1.0, y = 0.4 }, LS = { p = 1.0, y = 0.4 }, RJ = { tw = 5.6, ln = 0.55 }, RH = { p = 0.6, r = -0.6 }, LH = { p = 0.6 } },
		{ t = 0.5, RS = { p = 1.0, y = 0.4 }, LS = { p = 1.0, y = 0.4 }, RJ = { tw = 6.6, ln = 0.5 }, RH = { p = 0.5, r = -0.5 }, LH = { p = 0.5 } },
		{ t = 0.501, RS = { p = 1.0, y = 0.4 }, LS = { p = 1.0, y = 0.4 }, RJ = { tw = 0.32, ln = 0.5 }, RH = { p = 0.5, r = -0.5 }, LH = { p = 0.5 } },
		{ t = 0.62, RS = { p = 0.9, y = 0.3 }, LS = { p = 0.9, y = 0.3 }, RJ = { tw = 0.1, ln = 0.4 }, RH = { p = 0.4 }, LH = { p = 0.4 } },
		{ t = 0.78 },
	},
	SignSlam = { -- panneau soulevé très haut sur la pointe des pieds, puis planté de tout son poids
		{ t = 0 },
		{ t = 0.12, RS = { p = 3.35 }, LS = { p = 3.35 }, RJ = { ln = -0.5 }, RH = { p = -0.15 }, LH = { p = 0.35 } },
		{ t = 0.2, RS = { p = 0.85, y = 0.2 }, LS = { p = 0.85, y = 0.2 }, RJ = { ln = 0.9 }, RH = { p = 1.05 }, LH = { p = -0.45 } },
		{ t = 0.45, RS = { p = 0.95, y = 0.2 }, LS = { p = 0.95, y = 0.2 }, RJ = { ln = 0.75 }, RH = { p = 0.9 }, LH = { p = -0.4 } },
		{ t = 0.62 },
	},
	BucketToss = { -- grand élan par en dessous, genou levé, bras qui finit au-dessus de la tête
		{ t = 0 },
		{ t = 0.1, RS = { p = -1.25, r = -0.2 }, LS = { p = 0.8 }, RJ = { ln = 0.45, tw = -0.45 }, RH = { p = 0.6 }, LH = { p = -0.3 } },
		{ t = 0.17, RS = { p = 2.7, y = 0.2 }, LS = { p = -0.4 }, RJ = { ln = -0.3, tw = 0.45 }, LH = { p = 0.75 }, RH = { p = -0.45 } },
		{ t = 0.35, RS = { p = 2.45, y = 0.2 }, LS = { p = -0.3 }, RJ = { ln = -0.2, tw = 0.3 }, LH = { p = 0.5 } },
		{ t = 0.52 },
	},
	PowerWash = powerWash(), -- campé, lance tenue à deux mains, recul qui fait trembler tout le corps
	SoapSlide = { -- prise d'élan accroupie puis glissade de baseball, jambe tendue, bras en l'air
		{ t = 0 },
		{ t = 0.05, RJ = { ln = 0.6 }, RS = { p = -0.6 }, LS = { p = -0.6 }, RH = { p = -0.5 }, LH = { p = 0.8 } },
		{ t = 0.11, RJ = { ln = -1.25, sd = 0.1 }, RH = { p = 1.65 }, LH = { p = 0.35, r = -0.2 }, RS = { p = 3.0, r = -0.35 }, LS = { p = -0.7, r = -0.7 } },
		{ t = 0.45, RJ = { ln = -1.2, sd = 0.12 }, RH = { p = 1.6 }, LH = { p = 0.35, r = -0.2 }, RS = { p = 3.0, r = -0.35 }, LS = { p = -0.7, r = -0.7 } },
		{ t = 0.53, RJ = { ln = -0.45 }, RH = { p = 0.8 }, RS = { p = 2.0 }, LS = { p = -0.3 } },
		{ t = 0.66 },
	},
	BubbleBlow = { -- baguette à bulles à la bouche, grande inspiration en arrière, puis souffle penché en avant
		{ t = 0 },
		{ t = 0.1, RS = { p = 2.3, y = 0.9 }, LS = { p = 0.5, r = -0.5 }, RJ = { ln = -0.35 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
		{ t = 0.22, RS = { p = 2.4, y = 0.9 }, LS = { p = 0.6, r = -0.6 }, RJ = { ln = -0.5 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
		{ t = 0.3, RS = { p = 1.75, y = 0.3 }, LS = { p = 1.5, y = 0.6 }, RJ = { ln = 0.5 }, RH = { p = -0.55 }, LH = { p = 0.75 } },
		{ t = 0.6, RS = { p = 1.65, y = 0.3 }, LS = { p = 1.45, y = 0.6 }, RJ = { ln = 0.4 }, RH = { p = -0.45 }, LH = { p = 0.65 } },
		{ t = 0.75 },
	},
	BubblePop = { -- claque des doigts en l'air puis tire le poing vers le sol (la bulle éclate)
		{ t = 0 },
		{ t = 0.08, RS = { p = 3.0, r = -0.3 }, RJ = { ln = -0.25 }, LS = { p = 0.4, r = -0.4 } },
		{ t = 0.16, RS = { p = 0.55, y = 0.3 }, LS = { p = -0.3 }, RJ = { ln = 0.6 }, RH = { p = 0.7 }, LH = { p = -0.35 } },
		{ t = 0.4, RS = { p = 0.6, y = 0.3 }, RJ = { ln = 0.5 }, RH = { p = 0.6 }, LH = { p = -0.3 } },
		{ t = 0.55 },
	},
	-- THE LUNCH LADY
	TrayGuard = { -- plateau planté devant, appuis écartés et bas, buste penché dans le coup
		{ t = 0 },
		{ t = 0.06, RS = { p = 1.95, y = 0.6 }, LS = { p = 1.95, y = 0.6 }, RJ = { ln = 0.28 }, RH = { p = -0.55, r = -0.18 }, LH = { p = 0.65, r = -0.18 } },
		{ t = 0.12, RS = { p = 1.8, y = 0.55 }, LS = { p = 1.8, y = 0.55 }, RJ = { ln = 0.2 }, RH = { p = -0.45, r = -0.15 }, LH = { p = 0.55, r = -0.15 } },
		{ t = 1.5, RS = { p = 1.8, y = 0.55 }, LS = { p = 1.8, y = 0.55 }, RJ = { ln = 0.2 }, RH = { p = -0.45, r = -0.15 }, LH = { p = 0.55, r = -0.15 } },
		{ t = 1.65 },
	},
	LadleBonk = { -- accroupie, bond louche à deux mains loin derrière la tête, écrasement qui plie tout le corps
		{ t = 0 },
		{ t = 0.08, RS = { p = -0.4 }, LS = { p = -0.4 }, RJ = { ln = 0.5 }, RH = { p = 0.7 }, LH = { p = 0.7 } },
		{ t = 0.18, RS = { p = 3.45, y = 0.15 }, LS = { p = 3.35, y = 0.15 }, RJ = { ln = -0.6 }, RH = { p = 0.55 }, LH = { p = -0.3 } },
		{ t = 0.24, RS = { p = 0.55, y = 0.2 }, LS = { p = 0.55, y = 0.2 }, RJ = { ln = 1.0 }, LH = { p = 0.95 }, RH = { p = -0.55 } },
		{ t = 0.5, RS = { p = 0.7, y = 0.2 }, LS = { p = 0.7, y = 0.2 }, RJ = { ln = 0.82 }, LH = { p = 0.8 }, RH = { p = -0.45 } },
		{ t = 0.68 },
	},
	MeatLob = { -- moulinet complet du bras, lancer par-dessus avec tout le buste
		{ t = 0 },
		{ t = 0.07, RS = { p = -1.2, r = -0.4 }, LS = { p = 1.2 }, RJ = { tw = -0.6, ln = -0.1 }, LH = { p = 0.5 } },
		{ t = 0.14, RS = { p = 3.4 }, LS = { p = 0.9 }, RJ = { tw = -0.3, ln = -0.3 }, LH = { p = 0.4 } },
		{ t = 0.21, RS = { p = 1.2, y = 0.3 }, LS = { p = -0.5 }, RJ = { tw = 0.65, ln = 0.42 }, LH = { p = 0.85 }, RH = { p = -0.5 } },
		{ t = 0.4, RS = { p = 1.0, y = 0.3 }, LS = { p = -0.4 }, RJ = { tw = 0.5, ln = 0.3 }, LH = { p = 0.6 } },
		{ t = 0.55 },
	},
	PanSmash = { -- ramasse, soulève la poêle géante très haut sur la pointe des pieds, puis l'écrase genoux pliés
		{ t = 0 },
		{ t = 0.12, RS = { p = 1.5, y = -0.5 }, LS = { p = 1.5, y = -0.5 }, RJ = { tw = -0.5, ln = 0.35 }, RH = { p = 0.45 } },
		{ t = 0.32, RS = { p = 3.45 }, LS = { p = 3.45 }, RJ = { ln = -0.6 }, RH = { p = -0.2, r = -0.35 }, LH = { p = 0.2, r = -0.35 } },
		{ t = 0.4, RS = { p = 3.5 }, LS = { p = 3.5 }, RJ = { ln = -0.65 }, RH = { p = -0.2, r = -0.35 }, LH = { p = 0.2, r = -0.35 } },
		{ t = 0.45, RS = { p = 0.4 }, LS = { p = 0.4 }, RJ = { ln = 1.05 }, RH = { p = 1.15, r = -0.35 }, LH = { p = 1.15, r = -0.35 } },
		{ t = 0.75, RS = { p = 0.5 }, LS = { p = 0.5 }, RJ = { ln = 0.9 }, RH = { p = 1.0, r = -0.3 }, LH = { p = 1.0, r = -0.3 } },
		{ t = 0.95 },
	},
	SoupToss = { -- marmite ramenée sur la hanche, puis jetée à deux mains vers l'avant, jambe d'appui en avant
		{ t = 0 },
		{ t = 0.1, RS = { p = 0.1, y = -0.8, r = -0.3 }, LS = { p = 0.2, y = -0.5 }, RJ = { tw = -0.85, ln = 0.2 }, RH = { p = 0.4 } },
		{ t = 0.17, RS = { p = 2.15, y = 0.4 }, LS = { p = 2.15, y = 0.4 }, RJ = { tw = 0.6, ln = 0.42 }, LH = { p = 0.85 }, RH = { p = -0.45 } },
		{ t = 0.42, RS = { p = 1.95, y = 0.4 }, LS = { p = 1.95, y = 0.4 }, RJ = { tw = 0.45, ln = 0.35 }, LH = { p = 0.7 } },
		{ t = 0.6 },
	},
	CartPush = cartPush(), -- penchée sur le chariot, grosses enjambées, poussée finale bras tendus
	-- THE SECURITY GUARD
	Detain = { -- plongeon pour saisir, soulève au-dessus de la tête cambré, écrase devant de tout son poids
		{ t = 0 },
		{ t = 0.08, RS = { p = 1.95, y = 0.7 }, LS = { p = 1.95, y = 0.7 }, RJ = { ln = 0.55 }, LH = { p = 0.85 }, RH = { p = -0.45 } },
		{ t = 0.3, RS = { p = 3.2 }, LS = { p = 3.2 }, RJ = { ln = -0.5 }, RH = { p = 0.2, r = -0.3 }, LH = { p = -0.2, r = -0.3 } },
		{ t = 0.6, RS = { p = 3.3 }, LS = { p = 3.3 }, RJ = { ln = -0.62, tw = -0.3 }, RH = { r = -0.3 }, LH = { r = -0.3 } },
		{ t = 0.68, RS = { p = 0.75 }, LS = { p = 0.75 }, RJ = { ln = 1.0, tw = 0.2 }, LH = { p = 0.95 }, RH = { p = -0.5 } },
		{ t = 0.9, RS = { p = 0.85 }, LS = { p = 0.85 }, RJ = { ln = 0.82 }, LH = { p = 0.8 } },
		{ t = 1.05 },
	},
	Flashlight = { -- lampe ramenée à l'épaule puis braquée d'un coup sec, l'autre main devant les yeux
		{ t = 0 },
		{ t = 0.06, RS = { p = 0.6, y = 0.6 }, LS = { p = 2.4, y = 1.1 }, RJ = { ln = -0.15, tw = -0.3 } },
		{ t = 0.12, RS = { p = 1.75, y = 0.05 }, LS = { p = 2.4, y = 1.0 }, RJ = { ln = 0.18, tw = 0.18 }, RH = { p = -0.45 }, LH = { p = 0.55 } },
		{ t = 0.48, RS = { p = 1.65, y = 0.05 }, LS = { p = 2.35, y = 1.0 }, RJ = { ln = 0.12, tw = 0.12 }, RH = { p = -0.4 }, LH = { p = 0.5 } },
		{ t = 0.65 },
	},
	Walkie = { -- radio à la bouche, l'autre bras pointe et donne des ordres (petits rebonds)
		{ t = 0 },
		{ t = 0.1, RS = { p = 2.7, y = 1.25 }, LS = { p = 1.8, y = 0.1 }, RJ = { tw = 0.25, ln = 0.12 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
		{ t = 0.25, RS = { p = 2.7, y = 1.25 }, LS = { p = 1.5, y = -0.2 }, RJ = { tw = 0.15, ln = 0.04 }, RH = { p = -0.15 }, LH = { p = 0.25 } },
		{ t = 0.4, RS = { p = 2.7, y = 1.25 }, LS = { p = 1.85, y = 0.2 }, RJ = { tw = 0.3, ln = 0.12 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
		{ t = 0.6, RS = { p = 2.65, y = 1.2 }, LS = { p = 1.7 }, RJ = { tw = 0.2 } },
		{ t = 0.75 },
	},
	Whistle = { -- grande inspiration cambrée, puis souffle : bras et jambes écartés dans l'onde
		{ t = 0 },
		{ t = 0.15, RS = { p = 2.5, y = 1.15 }, LS = { p = 0.3, r = -0.7 }, RJ = { ln = -0.5 }, RH = { p = -0.25 }, LH = { p = 0.35 } },
		{ t = 0.28, RS = { p = 2.6, y = 1.2 }, LS = { p = 0.35, r = -0.75 }, RJ = { ln = -0.58 }, RH = { p = -0.25 }, LH = { p = 0.35 } },
		{ t = 0.33, RS = { p = 1.4, r = -1.45 }, LS = { p = 1.4, r = -1.45 }, RJ = { ln = 0.45 }, RH = { p = -0.4, r = -0.35 }, LH = { p = 0.5, r = -0.35 } },
		{ t = 0.6, RS = { p = 1.35, r = -1.35 }, LS = { p = 1.35, r = -1.35 }, RJ = { ln = 0.38 }, RH = { p = -0.35, r = -0.3 }, LH = { p = 0.45, r = -0.3 } },
		{ t = 0.78 },
	},
	ElbowDrop = { -- accroupi, saut bras au ciel, coude armé au sommet, plongeon coude en premier
		{ t = 0 },
		{ t = 0.18, RS = { p = -0.7 }, LS = { p = -0.7 }, RJ = { ln = 0.6 }, RH = { p = 1.0 }, LH = { p = 1.0 } },
		{ t = 0.3, RS = { p = 3.1, r = -0.3 }, LS = { p = 3.1, r = -0.3 }, RJ = { ln = -0.3 }, RH = { p = 1.4 }, LH = { p = 0.3 } },
		{ t = 0.55, RS = { p = 2.6, y = 1.4, r = 0.3 }, LS = { p = 1.2, r = -0.8 }, RJ = { ln = 0.2, tw = 0.5 }, RH = { p = 1.2 }, LH = { p = 0.6 } },
		{ t = 0.8, RS = { p = 0.6, y = 1.5, r = 0.5 }, LS = { p = 1.3, r = -1.0 }, RJ = { ln = 1.1, tw = 0.4 }, RH = { p = -0.2 }, LH = { p = -0.2 } },
		{ t = 1.1, RS = { p = 0.65, y = 1.5, r = 0.5 }, LS = { p = 1.2, r = -0.9 }, RJ = { ln = 0.9, tw = 0.3 }, RH = { p = 0.6 }, LH = { p = -0.3 } },
		{ t = 1.3 },
	},
	Lockdown = { -- tape du pied, matraque qui tournoie au-dessus de la tête, main tendue « STOP »
		{ t = 0 },
		{ t = 0.1, RS = { p = 3.15, r = -0.2 }, LS = { p = 1.7, y = -0.2 }, RJ = { ln = -0.2 }, RH = { p = 0.6 }, LH = { p = -0.1 } },
		{ t = 0.18, RS = { p = 3.15, y = 1.5, r = -0.2 }, LS = { p = 1.75, y = -0.2 }, RJ = { ln = 0.15 }, RH = { p = 0 }, LH = { p = 0 } },
		{ t = 0.3, RS = { p = 3.1, y = -1.5, r = -0.2 }, LS = { p = 1.75, y = -0.2 }, RJ = { ln = 0.1 } },
		{ t = 0.42, RS = { p = 3.15, y = 1.5, r = -0.2 }, LS = { p = 1.75, y = -0.2 }, RJ = { ln = 0.1 } },
		{ t = 0.54, RS = { p = 3.1, y = -1.5, r = -0.2 }, LS = { p = 1.75, y = -0.2 }, RJ = { ln = 0.1 } },
		{ t = 0.66, RS = { p = 1.2, y = 0.3 }, LS = { p = 1.9, y = -0.2 }, RJ = { ln = 0.45 }, RH = { p = 0.7 }, LH = { p = -0.3 } },
		{ t = 0.85, RS = { p = 1.2, y = 0.3 }, LS = { p = 1.85, y = -0.2 }, RJ = { ln = 0.4 }, RH = { p = 0.6 }, LH = { p = -0.3 } },
		{ t = 1.0 },
	},
}
-- animations ajoutées par les modules de Content
require(script.Parent.ContentLoader).merge(ANIMS, "Anims")
ProcAnim.Anims = ANIMS

local states = {}

local function getMotors(character)
	local torso = character:FindFirstChild("Torso")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not torso or not root then
		return nil
	end
	local m = {
		RS = torso:FindFirstChild("Right Shoulder"),
		LS = torso:FindFirstChild("Left Shoulder"),
		RH = torso:FindFirstChild("Right Hip"),
		LH = torso:FindFirstChild("Left Hip"),
		RJ = root:FindFirstChild("RootJoint"),
	}
	-- pairs() saute les clés nil : on vérifie chaque articulation explicitement
	for _, k in ipairs({ "RS", "LS", "RH", "LH", "RJ" }) do
		local v = m[k]
		if not v or not v:IsA("Motor6D") then
			return nil
		end
	end
	return m
end

local function getState(character)
	local s = states[character]
	if s and s.motors.RS.Parent and s.motors.LS.Parent and s.motors.RH.Parent and s.motors.LH.Parent and s.motors.RJ.Parent then
		return s
	end
	local motors = getMotors(character)
	if not motors then
		return nil
	end
	s = {
		motors = motors,
		base = { RS = motors.RS.C0, LS = motors.LS.C0, RH = motors.RH.C0, LH = motors.LH.C0, RJ = motors.RJ.C0 },
		track = nil, frozenUntil = 0, blend = nil, current = nil,
	}
	states[character] = s
	return s
end

local function lerpTable(a, b, alpha, zero)
	local out = {}
	for k in pairs(zero) do
		local va, vb = (a and a[k]) or 0, (b and b[k]) or 0
		out[k] = va + (vb - va) * alpha
	end
	return out
end

local function holdPose(character)
	local pose = {}
	local base = HOLD_POSES[character:GetAttribute("HoldPose") or ""] or {}
	for k, v in pairs(base) do
		pose[k] = v
	end
	-- course : buste penché, grands mouvements de bras et de jambes en opposition (cycle continu)
	if character:GetAttribute("Running") and character:GetAttribute("HoldPose") ~= "TwoHands" then
		local hum = character:FindFirstChildOfClass("Humanoid")
		local moving = hum and hum.MoveDirection.Magnitude > 0.1 and hum.FloorMaterial ~= Enum.Material.Air
		local t = os.clock() * 11
		local s = moving and math.sin(t) or 0
		local holding = character:GetAttribute("HoldPose") == "Hand"
		pose.RJ = { ln = 0.38, tw = s * 0.12 }
		pose.RS = holding and pose.RS or { p = s * 1.1 + 0.15, r = -0.12 }
		pose.LS = { p = -s * 1.1 + 0.15, r = -0.12 }
		pose.RH = { p = -s * 0.55 }
		pose.LH = { p = s * 0.55 }
		if not moving then
			pose.RJ = { ln = 0.15 }
		end
	end
	if character:GetAttribute("Blocking") then
		for k, v in pairs(HOLD_POSES.Block) do
			pose[k] = v
		end
	elseif workspace:GetServerTimeNow() < (character:GetAttribute("StunUntil") or 0) then
		for k, v in pairs(HOLD_POSES.Stunned) do
			if not pose[k] then
				pose[k] = v
			end
		end
	end
	return pose
end

local function full(pose)
	return {
		RS = pose.RS or ZERO_LIMB, LS = pose.LS or ZERO_LIMB,
		RH = pose.RH or ZERO_LIMB, LH = pose.LH or ZERO_LIMB,
		RJ = pose.RJ or ZERO_RJ,
	}
end

local function easeOut(x)
	return 1 - (1 - x) * (1 - x)
end

local function evalTrack(track, hold)
	local frames = track.frames
	local t = track.t
	for i = 1, #frames - 1 do
		local a, b = frames[i], frames[i + 1]
		if t <= b.t then
			local alpha = easeOut(math.clamp((t - a.t) / math.max(b.t - a.t, 1e-3), 0, 1))
			local pose = {}
			for _, j in ipairs(LIMBS) do
				pose[j] = lerpTable(a[j] or hold[j], b[j] or hold[j], alpha, ZERO_LIMB)
			end
			pose.RJ = lerpTable(a.RJ or hold.RJ, b.RJ or hold.RJ, alpha, ZERO_RJ)
			return pose, false
		end
	end
	return nil, true
end

local function limbOffset(j, mirror)
	local s = mirror and -1 or 1
	return CFrame.Angles(0, (j.y or 0) * s, 0) * CFrame.Angles(0, 0, (j.p or 0) * s) * CFrame.Angles(-(j.r or 0), 0, 0)
end

local function apply(s, pose)
	s.motors.RS.C0 = s.base.RS * limbOffset(pose.RS, false)
	s.motors.LS.C0 = s.base.LS * limbOffset(pose.LS, true)
	s.motors.RH.C0 = s.base.RH * limbOffset(pose.RH, false)
	s.motors.LH.C0 = s.base.LH * limbOffset(pose.LH, true)
	s.motors.RJ.C0 = s.base.RJ * CFrame.Angles(pose.RJ.ln or 0, pose.RJ.sd or 0, 0) * CFrame.Angles(0, 0, pose.RJ.tw or 0)
end

function ProcAnim.play(character: Model, name: string, speed: number?)
	local frames = ANIMS[name]
	local s = character and getState(character)
	if not frames or not s then
		return
	end
	s.track = { frames = frames, t = 0, speed = speed or 1 }
	s.blend = nil
end

-- Ultimates / effets : jouer une piste de keyframes fournie directement (même format qu'une entrée de ANIMS)
function ProcAnim.playFrames(character: Model, frames, speed: number?)
	local s = character and getState(character)
	if type(frames) ~= "table" or #frames < 2 or not s then
		return
	end
	s.track = { frames = frames, t = 0, speed = speed or 1 }
	s.blend = nil
end

-- enregistre une animation nommée (utilisable ensuite par ProcAnim.play / la remote Anim)
function ProcAnim.define(name: string, frames)
	if type(name) == "string" and type(frames) == "table" then
		ANIMS[name] = frames
	end
end

function ProcAnim.freeze(character: Model, duration: number)
	local s = character and getState(character)
	if s then
		s.frozenUntil = math.max(s.frozenUntil, os.clock() + duration)
	end
end

function ProcAnim.isPlaying(character: Model): boolean
	local s = states[character]
	return s ~= nil and s.track ~= nil
end

function ProcAnim.register(character: Model)
	getState(character)
end

local BLEND_TIME = 0.12
RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for character, s in pairs(states) do
		if not s.motors.RS.Parent or not s.motors.RJ.Parent or not character.Parent or s.motors.RS.Enabled == false then
			if not character.Parent then
				states[character] = nil
			end
			continue
		end
		local hold = full(holdPose(character))
		local pose
		if s.track then
			if now >= s.frozenUntil then
				s.track.t += dt * s.track.speed
			end
			local p, done = evalTrack(s.track, hold)
			if done then
				s.track = nil
				s.blend = { from = s.current or hold, t = 0 }
				pose = s.current or hold
			else
				pose = p
			end
		elseif s.blend then
			s.blend.t += dt
			local a = math.clamp(s.blend.t / BLEND_TIME, 0, 1)
			pose = {}
			for _, j in ipairs(LIMBS) do
				pose[j] = lerpTable(s.blend.from[j], hold[j], a, ZERO_LIMB)
			end
			pose.RJ = lerpTable(s.blend.from.RJ, hold.RJ, a, ZERO_RJ)
			if a >= 1 then
				s.blend = nil
			end
		else
			-- glisse doucement vers la pose de maintien (block, stun, objet…)
			local cur = s.current or hold
			local a = math.clamp(dt * 14, 0, 1)
			pose = {}
			for _, j in ipairs(LIMBS) do
				pose[j] = lerpTable(cur[j], hold[j], a, ZERO_LIMB)
			end
			pose.RJ = lerpTable(cur.RJ, hold.RJ, a, ZERO_RJ)
		end
		s.current = pose
		apply(s, pose)
	end
end)

return ProcAnim
