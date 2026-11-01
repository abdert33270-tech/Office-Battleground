--[[
	ProcAnim v2 — animations R6 procédurales (client uniquement). Détails : docs/Animation-v2.md
	On modifie le C0 des Motor6D (épaules, hanches, RootJoint, cou) ; les pistes Animator (saut, chute, escalade,
	assis : StarterCharacterScripts/Animate) s'appliquent par-dessus (Transform).
	Aucun asset d'animation à publier : tout est défini ici en keyframes.

	Angles (radians), identiques pour les membres gauche et droit (le miroir est géré ici) :
		p = pitch : vers l'avant (0 = le long du corps, 1.57 = tendu devant, 3.1 = au-dessus de la tête)
		y = twist du membre, r = écarter sur le côté : POSITIF = vers l'extérieur (calcul du C0 R6 + vérifié en jeu, voir
		SkinRevealController) ; négatif = ramené devant / en travers du corps. NB : beaucoup d'anciennes animations ont
		été écrites avec la convention inverse (r < 0 « écarté ») : elles restent telles quelles (docs/Animation-v2.md).
	Joints : RS / LS (épaules), RH / LH (hanches),
		RJ (buste : tw = rotation (+ = épaule droite en avant), ln = penché en avant, sd = penché à gauche,
		    dy = hauteur du corps en studs (négatif = accroupi), dz = translation vers l'avant en studs (fente)),
		N (cou : p = baisser la tête, y = tourner à gauche, r = pencher à gauche ; mêmes signes que tw / sd).
	Keyframe : { t = temps, e = easing du segment qui ARRIVE sur cette clé : "out" (défaut) | "in" | "inout" | "linear" | "back" }
	Joint absent d'une clé = pose de maintien (locomotion / block / objet…). Anciennes animations valides telles quelles.
	Locomotion (v2) : garde de combat par archétype (M1Style.resolve) + respiration, cycle marche / course phasé par
	la vitesse (AssemblyLinearVelocity), pour chaque personnage visible à moins de LOCO_RANGE studs. Une action
	(play) remplace la locomotion joint par joint, avec fondu à l'entrée (clé t = 0) et à la sortie.
	Tête : suit la cible pendant les M1 (setLookTarget / cible automatique la plus proche devant soi).
	Le hit-stop gèle le temps de l'animation (ProcAnim.freeze).
	Ajouter une animation = ajouter une entrée dans ANIMS (aucun autre code).
]]
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local ProcAnim = {}

local LIMBS = { "RS", "LS", "RH", "LH" }
local ZERO_LIMB = { p = 0, y = 0, r = 0 }
local ZERO_RJ = { tw = 0, ln = 0, sd = 0, dy = 0, dz = 0 }
local ZERO_N = { p = 0, y = 0, r = 0 }

-- poses tenues en permanence
local HOLD_POSES = {
	Hand = { RS = { p = 0.45, y = 0.1 } },
	TwoHands = { RS = { p = 2.7, y = 0.25 }, LS = { p = 2.7, y = 0.25 } },
	Block = { RS = { p = 1.65, y = 0.95, r = 0.15 }, LS = { p = 1.65, y = 0.95, r = 0.15 }, RJ = { ln = 0.12, dy = -0.1 }, RH = { p = 0.25 }, LH = { p = -0.15 }, N = { p = 0.25 } },
	Stunned = { RS = { p = 0.25, r = -0.25 }, LS = { p = 0.25, r = -0.25 }, RJ = { ln = 0.25, sd = 0.1, dy = -0.1 }, N = { p = 0.3, r = 0.15 } },
	GuardBroken = { RS = { p = 0.35, r = -0.45 }, LS = { p = 0.35, r = -0.45 }, RJ = { ln = 0.4, sd = 0.15, dy = -0.2 }, RH = { p = 0.15 }, LH = { p = -0.1 }, N = { p = 0.4, r = 0.2 } },
	-- ENDLAG (attribut EndlagUntil, coup lourd raté ou réussi) : essoufflé, bras ballants, buste plié -> « punissable »
	Winded = { RS = { p = 0.15, r = -0.15 }, LS = { p = 0.15, r = -0.15 }, RJ = { ln = 0.42, dy = -0.2 }, RH = { p = 0.3 }, LH = { p = -0.2 }, N = { p = 0.3 } },
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
	-- M1 au sol (système ABA, cadence lente) : ANTICIPATION lisible -> IMPACT pile au Windup de Config/Combat.M1
	-- (0,14 / 0,14 / 0,15 / 0,16 / 0,22 s) -> SUIVI tenu -> retour en garde. Le hit-stop gèle l'impact.
	Punch1 = { -- jab droit : épaule armée en arrière, buste vrillé, pas de la jambe gauche, coup qui dépasse
		{ t = 0 },
		{ t = 0.1, RS = { p = -0.65, r = -0.25 }, LS = { p = 1.25, y = 0.8 }, RJ = { tw = -0.55, ln = -0.08 }, LH = { p = 0.3 }, RH = { p = -0.1 } },
		{ t = 0.14, RS = { p = 2.05, y = 0.2 }, LS = { p = 0.75, y = 0.8 }, RJ = { tw = 0.75, ln = 0.3 }, LH = { p = 0.75 }, RH = { p = -0.5 } },
		{ t = 0.28, RS = { p = 1.9, y = 0.2 }, LS = { p = 0.75, y = 0.8 }, RJ = { tw = 0.65, ln = 0.26 }, LH = { p = 0.7 }, RH = { p = -0.45 } },
		{ t = 0.44, RS = { p = 1.1, y = 0.7 }, LS = { p = 1.2, y = 0.75 }, RJ = { tw = 0.1, ln = 0.12 }, LH = { p = 0.3 }, RH = { p = -0.2 } },
		{ t = 0.58 },
	},
	Punch2 = { -- crochet gauche : bras gauche ramené loin sur le côté, rotation complète des hanches
		{ t = 0 },
		{ t = 0.1, LS = { p = 1.0, y = -1.2, r = -0.45 }, RS = { p = 1.2, y = 0.8 }, RJ = { tw = 0.6, ln = 0.02 }, RH = { p = 0.35 }, LH = { p = -0.1 } },
		{ t = 0.14, LS = { p = 1.65, y = 1.0 }, RS = { p = 0.75, y = 0.8 }, RJ = { tw = -0.9, ln = 0.27 }, RH = { p = 0.75 }, LH = { p = -0.45 } },
		{ t = 0.28, LS = { p = 1.55, y = 0.9 }, RS = { p = 0.75, y = 0.8 }, RJ = { tw = -0.8, ln = 0.24 }, RH = { p = 0.7 }, LH = { p = -0.4 } },
		{ t = 0.44, LS = { p = 1.15, y = 0.75 }, RS = { p = 1.1, y = 0.7 }, RJ = { tw = -0.1, ln = 0.12 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.58 },
	},
	Punch3 = { -- coup au corps : on plonge sous la garde (genoux pliés) puis on remonte dans le ventre
		{ t = 0 },
		{ t = 0.11, RS = { p = -0.45, r = -0.15 }, LS = { p = 1.2, y = 0.7 }, RJ = { tw = -0.6, ln = 0.6 }, LH = { p = 0.65 }, RH = { p = 0.45 } },
		{ t = 0.15, RS = { p = 1.65, y = 0.45 }, LS = { p = 0.65, y = 0.7 }, RJ = { tw = 0.7, ln = 0.42 }, LH = { p = 0.8 }, RH = { p = -0.35 } },
		{ t = 0.3, RS = { p = 1.55, y = 0.4 }, LS = { p = 0.65, y = 0.7 }, RJ = { tw = 0.6, ln = 0.36 }, LH = { p = 0.7 }, RH = { p = -0.3 } },
		{ t = 0.46, RS = { p = 1.1, y = 0.7 }, LS = { p = 1.2, y = 0.75 }, RJ = { tw = 0.1, ln = 0.14 }, LH = { p = 0.3 } },
		{ t = 0.6 },
	},
	Punch4 = { -- direct appuyé : grand pas en avant, tout le poids du corps derrière le poing gauche
		{ t = 0 },
		{ t = 0.12, LS = { p = -0.5, r = -0.25 }, RS = { p = 1.3, y = 0.8 }, RJ = { tw = 0.55, ln = -0.12 }, RH = { p = 0.35 }, LH = { p = -0.2 } },
		{ t = 0.16, LS = { p = 2.1, y = 0.2 }, RS = { p = 0.6, y = 0.8, r = -0.2 }, RJ = { tw = -0.8, ln = 0.38 }, RH = { p = 0.85 }, LH = { p = -0.55 } },
		{ t = 0.32, LS = { p = 1.95, y = 0.2 }, RS = { p = 0.6, y = 0.8, r = -0.2 }, RJ = { tw = -0.7, ln = 0.34 }, RH = { p = 0.8 }, LH = { p = -0.5 } },
		{ t = 0.48, LS = { p = 1.15, y = 0.75 }, RS = { p = 1.1, y = 0.7 }, RJ = { tw = -0.1, ln = 0.14 }, RH = { p = 0.3 } },
		{ t = 0.62 },
	},
	Punch5 = { -- FINISHER : grosse anticipation (accroupi bas, buste enroulé, menton rentré), coup de pied retourné
		-- qui se déplie en se grandissant (easing « back » = claquement), longue récupération essoufflée
		{ t = 0 },
		{ t = 0.12, RH = { p = 0.9, r = -0.2 }, LH = { p = -0.05 }, RJ = { tw = -1.15, ln = 0.35, dy = -0.35 }, RS = { p = 0.5, r = -0.8 }, LS = { p = 1.2, y = 0.7 }, N = { p = 0.2, y = 0.5 } },
		{ t = 0.18, RH = { p = 1.0, r = -0.5 }, LH = { p = -0.1 }, RJ = { tw = -1.3, ln = 0.3, dy = -0.4 }, RS = { p = 0.4, r = -1.0 }, LS = { p = 0.6, r = -0.8 }, N = { p = 0.25, y = 0.6 }, e = "inout" },
		{ t = 0.22, RH = { p = 2.0, r = -0.45 }, RJ = { tw = 1.3, ln = -0.45, sd = -0.22, dy = 0.1, dz = 0.15 }, RS = { p = 0.4, r = -1.35 }, LS = { p = 0.4, r = -1.35 }, LH = { p = -0.2 }, N = { p = 0.35, y = -0.6 }, e = "back" },
		{ t = 0.5, RH = { p = 1.8, r = -0.4 }, RJ = { tw = 1.15, ln = -0.38, sd = -0.16, dy = 0.05, dz = 0.12 }, RS = { p = 0.35, r = -1.25 }, LS = { p = 0.35, r = -1.25 }, LH = { p = -0.15 }, N = { p = 0.3, y = -0.5 } },
		{ t = 0.75, RH = { p = 0.5 }, RJ = { tw = 0.35, ln = 0.2, dy = -0.25 }, RS = { p = 0.6, r = -0.5 }, LS = { p = 0.6, r = -0.5 }, LH = { p = 0.2 }, e = "inout" }, -- réception
		{ t = 1.0, RS = { p = 0.4, r = -0.3 }, LS = { p = 0.4, r = -0.3 }, RJ = { ln = 0.25, dy = -0.15 }, N = { p = 0.3 } }, -- souffle (endlag visible)
		{ t = 1.2, e = "inout" },
	},

	Uppercut = { -- Espace + 5e coup : accroupi très bas, puis tout le corps se déplie, le poing monte au ciel avec le genou
		{ t = 0 },
		{ t = 0.15, RS = { p = -0.7, r = -0.15 }, LS = { p = 1.1, y = 0.7 }, RJ = { ln = 0.6, tw = -0.45, dy = -0.45 }, RH = { p = 1.15 }, LH = { p = 0.15 }, N = { p = -0.35 }, e = "inout" },
		{ t = 0.2, RS = { p = 3.15, y = 0.2 }, LS = { p = -0.45 }, RJ = { ln = -0.42, tw = 0.5, dy = 0.3, dz = 0.2 }, LH = { p = 0.95 }, RH = { p = -0.25 }, N = { p = -0.3 }, e = "back" },
		{ t = 0.45, RS = { p = 3.05, y = 0.2 }, LS = { p = -0.4 }, RJ = { ln = -0.36, tw = 0.42, dy = 0.2, dz = 0.15 }, LH = { p = 0.8 }, N = { p = -0.25 } },
		{ t = 0.65, e = "inout" },
	},

	DashStrike = { -- dash avant + clic : accroupi, puis coup de pied volant à deux pieds, bras rejetés en arrière
		{ t = 0 },
		{ t = 0.1, RJ = { ln = 0.45, dy = -0.45 }, RH = { p = -0.1 }, LH = { p = 1.0 }, RS = { p = -0.9 }, LS = { p = -0.9 }, N = { p = -0.3 } },
		{ t = 0.16, RH = { p = 1.75 }, LH = { p = 1.5 }, RJ = { ln = -1.0, dy = 0.35, dz = 0.4 }, RS = { p = -1.0, r = -0.45 }, LS = { p = -1.0, r = -0.45 }, N = { p = 0.55 }, e = "back" },
		{ t = 0.48, RH = { p = 1.65 }, LH = { p = 1.45 }, RJ = { ln = -0.92, dy = 0.3, dz = 0.35 }, RS = { p = -0.95, r = -0.4 }, LS = { p = -0.95, r = -0.4 }, N = { p = 0.5 } },
		{ t = 0.62, RJ = { ln = 0.3, dy = -0.3, dz = 0.1 }, RH = { p = 0.9 }, LH = { p = -0.2 }, RS = { p = 0.6 }, LS = { p = 0.6 }, N = { p = -0.1 }, e = "in" }, -- réception écrasée
		{ t = 0.8, e = "inout" },
	},

	-- jongle aérien (impact au Windup de Config/Combat.Air : 0,11 s)
	Air1 = {
		{ t = 0 },
		{ t = 0.07, RS = { p = -0.4 }, LS = { p = 1.0, y = 0.6 }, LH = { p = 1.1 }, RH = { p = 0.6 }, RJ = { tw = -0.4 } },
		{ t = 0.11, RS = { p = 1.9, y = 0.2 }, LH = { p = 1.3 }, RH = { p = 0.4 }, RJ = { tw = 0.55, ln = 0.25 } },
		{ t = 0.26, RS = { p = 1.75, y = 0.2 }, LH = { p = 1.2 }, RJ = { tw = 0.45, ln = 0.2 } },
		{ t = 0.4 },
	},
	Air2 = {
		{ t = 0 },
		{ t = 0.07, LS = { p = -0.4 }, RS = { p = 1.0, y = 0.6 }, RH = { p = 1.1 }, LH = { p = 0.6 }, RJ = { tw = 0.4 } },
		{ t = 0.11, LS = { p = 1.9, y = 0.2 }, RH = { p = 1.3 }, LH = { p = 0.4 }, RJ = { tw = -0.55, ln = 0.25 } },
		{ t = 0.26, LS = { p = 1.75, y = 0.2 }, RH = { p = 1.2 }, RJ = { tw = -0.45, ln = 0.2 } },
		{ t = 0.4 },
	},
	Air3 = { -- coup de genou : on attrape et on remonte le genou
		{ t = 0 },
		{ t = 0.07, RS = { p = 1.9, y = 0.6 }, LS = { p = 1.9, y = 0.6 }, RJ = { ln = -0.2 }, RH = { p = -0.3 } },
		{ t = 0.11, RS = { p = 1.5, y = 0.5 }, LS = { p = 1.5, y = 0.5 }, RJ = { ln = 0.45 }, RH = { p = 1.6 }, LH = { p = -0.2 } },
		{ t = 0.26, RS = { p = 1.45, y = 0.5 }, LS = { p = 1.45, y = 0.5 }, RJ = { ln = 0.4 }, RH = { p = 1.45 } },
		{ t = 0.4 },
	},
	Downslam = { -- bras joints très haut sur la pointe des pieds (regard levé), puis marteau à deux mains, genoux pliés
		{ t = 0 },
		{ t = 0.12, RS = { p = 3.35 }, LS = { p = 3.35 }, RJ = { ln = -0.5, dy = 0.15 }, RH = { p = 0.7 }, LH = { p = 0.5 }, N = { p = -0.3 }, e = "inout" },
		{ t = 0.16, RS = { p = 0.8, y = 0.3 }, LS = { p = 0.8, y = 0.3 }, RJ = { ln = 0.9, dy = -0.45, dz = 0.35 }, RH = { p = 1.15 }, LH = { p = 1.05 }, N = { p = -0.4 }, e = "in" },
		{ t = 0.45, RS = { p = 0.85, y = 0.3 }, LS = { p = 0.85, y = 0.3 }, RJ = { ln = 0.75, dy = -0.35, dz = 0.3 }, RH = { p = 0.95 }, N = { p = -0.3 } },
		{ t = 0.7, e = "inout" },
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
	-- dashs directionnels (Config/Combat.Dash.Time = 0,2 s)
	Dash = { -- avant : 0,06 s d'anticipation accroupie (CombatController retarde la poussée d'autant), puis buste plongé
		{ t = 0 },
		{ t = 0.06, RS = { p = 0.35, r = -0.2 }, LS = { p = 0.35, r = -0.2 }, RJ = { ln = 0.35, dy = -0.35 }, RH = { p = 0.95 }, LH = { p = -0.15 }, N = { p = -0.2 }, e = "inout" },
		{ t = 0.11, RS = { p = -0.85 }, LS = { p = -0.85 }, RJ = { ln = 0.5, dy = -0.15, dz = 0.3 }, RH = { p = -0.45 }, LH = { p = 0.7 }, N = { p = -0.35 }, e = "back" },
		{ t = 0.28, RS = { p = -0.75 }, LS = { p = -0.75 }, RJ = { ln = 0.42, dy = -0.1, dz = 0.2 }, RH = { p = -0.3 }, LH = { p = 0.5 }, N = { p = -0.3 } },
		{ t = 0.4, e = "inout" },
	},

	DashBack = { -- arrière : buste en arrière, garde haute, jambes devant, corps abaissé
		{ t = 0 },
		{ t = 0.05, RS = { p = 1.5, y = 0.8 }, LS = { p = 1.5, y = 0.8 }, RJ = { ln = -0.35, dy = -0.3, dz = -0.2 }, RH = { p = 0.6 }, LH = { p = 0.3 }, N = { p = 0.3 } },
		{ t = 0.22, RS = { p = 1.4, y = 0.8 }, LS = { p = 1.4, y = 0.8 }, RJ = { ln = -0.28, dy = -0.25, dz = -0.15 }, RH = { p = 0.45 }, LH = { p = 0.2 }, N = { p = 0.25 } },
		{ t = 0.34, e = "inout" },
	},

	SideDashL = { -- pas chassé à gauche : penché dans le sens du dash, jambe gauche qui s'ouvre, garde, regard sur la cible
		{ t = 0 },
		{ t = 0.05, RS = { p = 1.3, y = 0.8 }, LS = { p = 0.6, r = -0.9 }, RJ = { sd = 0.32, ln = 0.12, dy = -0.2 }, LH = { r = -0.6 }, RH = { r = 0.25 }, N = { r = -0.3 } },
		{ t = 0.22, RS = { p = 1.2, y = 0.8 }, LS = { p = 0.5, r = -0.8 }, RJ = { sd = 0.25, ln = 0.1, dy = -0.15 }, LH = { r = -0.45 }, RH = { r = 0.2 }, N = { r = -0.25 } },
		{ t = 0.34, e = "inout" },
	},

	SideDashR = {
		{ t = 0 },
		{ t = 0.05, LS = { p = 1.3, y = 0.8 }, RS = { p = 0.6, r = -0.9 }, RJ = { sd = -0.32, ln = 0.12, dy = -0.2 }, RH = { r = -0.6 }, LH = { r = 0.25 }, N = { r = 0.3 } },
		{ t = 0.22, LS = { p = 1.2, y = 0.8 }, RS = { p = 0.5, r = -0.8 }, RJ = { sd = -0.25, ln = 0.1, dy = -0.15 }, RH = { r = -0.45 }, LH = { r = 0.2 }, N = { r = 0.25 } },
		{ t = 0.34, e = "inout" },
	},

	PerfectBlock = { -- PERFECT BLOCK : garde croisée qui claque, puis repousse à deux mains
		{ t = 0 },
		{ t = 0.05, RS = { p = 1.95, y = 1.05 }, LS = { p = 1.95, y = 1.05 }, RJ = { ln = 0.25 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.13, RS = { p = 1.7, y = 0.1, r = -0.3 }, LS = { p = 1.7, y = 0.1, r = -0.3 }, RJ = { ln = 0.35 }, RH = { p = -0.45 }, LH = { p = 0.7 } },
		{ t = 0.4, RS = { p = 1.6, y = 0.15, r = -0.25 }, LS = { p = 1.6, y = 0.15, r = -0.25 }, RJ = { ln = 0.3 }, RH = { p = -0.35 }, LH = { p = 0.6 } },
		{ t = 0.55 },
	},
	GuardBroken = { -- GUARD BREAK : bras arrachés vers le haut, recule en titubant (puis pose « sonné » tenue)
		{ t = 0 },
		{ t = 0.07, RS = { p = 2.5, r = -0.95 }, LS = { p = 2.5, r = -0.95 }, RJ = { ln = -0.55, tw = 0.2 }, RH = { p = 0.55 }, LH = { p = -0.25 } },
		{ t = 0.35, RS = { p = 2.2, r = -1.0 }, LS = { p = 2.3, r = -0.85 }, RJ = { ln = -0.45, tw = 0.15, sd = 0.1 }, RH = { p = 0.4 } },
		{ t = 0.7, RS = { p = 0.35, r = -0.45 }, LS = { p = 0.35, r = -0.45 }, RJ = { ln = 0.4, sd = 0.15 }, RH = { p = 0.15 }, LH = { p = -0.1 } },
	},
	Evasive = { -- EVASIVE : on se ramasse puis on explose bras et jambes écartés
		{ t = 0 },
		{ t = 0.06, RS = { p = 1.4, y = 0.9 }, LS = { p = 1.4, y = 0.9 }, RJ = { ln = 0.45 }, RH = { p = 0.8 }, LH = { p = 0.8 } },
		{ t = 0.14, RS = { p = 1.0, r = -1.45 }, LS = { p = 1.0, r = -1.45 }, RJ = { ln = -0.3 }, RH = { r = -0.45 }, LH = { r = -0.45 } },
		{ t = 0.4, RS = { p = 0.9, r = -1.3 }, LS = { p = 0.9, r = -1.3 }, RJ = { ln = -0.2 }, RH = { r = -0.35 }, LH = { r = -0.35 } },
		{ t = 0.55 },
	},
	GetUp = { -- fin du renversé (KnockdownUntil) : accroupi, mains au sol, puis on se redresse (joué automatiquement)
		{ t = 0 },
		{ t = 0.05, RS = { p = 1.2, r = -0.3 }, LS = { p = 1.2, r = -0.3 }, RJ = { ln = 0.75 }, RH = { p = 1.1 }, LH = { p = 0.9 } },
		{ t = 0.3, RS = { p = 0.6, r = -0.5 }, LS = { p = 0.6, r = -0.5 }, RJ = { ln = 0.35 }, RH = { p = 0.45 }, LH = { p = 0.2 } },
		{ t = 0.5 },
	},
	BlockStart = {
		{ t = 0 },
		{ t = 0.06, RS = { p = 1.9, y = 1.0 }, LS = { p = 1.9, y = 1.0 }, RJ = { ln = 0.2 } },
		{ t = 0.12 },
	},
	-- réactions de la victime
	HitLight = { -- coup de face : tête rejetée en arrière, petit recul
		{ t = 0 },
		{ t = 0.05, RJ = { ln = -0.35, tw = 0.3, dz = -0.15 }, RS = { p = 0.5, r = -0.45 }, LS = { p = 0.5, r = -0.45 }, LH = { p = -0.2 }, N = { p = -0.4, y = 0.2 }, e = "back" },
		{ t = 0.28, e = "inout" },
	},

	HitLight2 = {
		{ t = 0 },
		{ t = 0.05, RJ = { ln = -0.3, tw = -0.35, sd = 0.15, dz = -0.15 }, RS = { p = 0.4, r = -0.5 }, LS = { p = 0.6, r = -0.3 }, RH = { p = -0.2 }, N = { p = -0.35, y = -0.25, r = 0.15 }, e = "back" },
		{ t = 0.28, e = "inout" },
	},
	-- réactions DIRECTIONNELLES (ProcAnim.reactionFor : direction de l'attaquant vs LookVector / RightVector de la victime)
	HitLightL = { -- frappé côté GAUCHE : l'épaule gauche part en arrière, buste et tête rejetés vers la droite
		{ t = 0 },
		{ t = 0.05, RJ = { tw = 0.4, sd = -0.22, ln = -0.08, dz = -0.05 }, LS = { p = 0.35, r = 0.75 }, RS = { p = 0.55, r = -0.2 }, LH = { r = 0.2 }, RH = { r = -0.05 }, N = { y = -0.55, r = -0.3, p = -0.1 }, e = "back" },
		{ t = 0.3, e = "inout" },
	},
	HitLightR = { -- frappé côté DROIT (miroir)
		{ t = 0 },
		{ t = 0.05, RJ = { tw = -0.4, sd = 0.22, ln = -0.08, dz = -0.05 }, RS = { p = 0.35, r = 0.75 }, LS = { p = 0.55, r = -0.2 }, RH = { r = 0.2 }, LH = { r = -0.05 }, N = { y = 0.55, r = 0.3, p = -0.1 }, e = "back" },
		{ t = 0.3, e = "inout" },
	},
	HitBack = { -- frappé dans le DOS : poitrine projetée en avant, dos cambré, tête qui part en arrière, bras rejetés
		{ t = 0 },
		{ t = 0.05, RJ = { ln = -0.3, dz = 0.3, dy = -0.05 }, RS = { p = -0.6, r = 0.35 }, LS = { p = -0.6, r = 0.35 }, RH = { p = -0.35 }, LH = { p = 0.25 }, N = { p = -0.5 }, e = "back" },
		{ t = 0.18, RJ = { ln = -0.2, dz = 0.2 }, RS = { p = -0.45, r = 0.3 }, LS = { p = -0.45, r = 0.3 }, RH = { p = -0.25 }, LH = { p = 0.2 }, N = { p = -0.3 } },
		{ t = 0.36, e = "inout" },
	},
	AirHit = { -- frappé EN L'AIR : jambes repliées, buste qui bascule en arrière, bras ballants écartés
		{ t = 0 },
		{ t = 0.05, RJ = { ln = -0.5, tw = 0.15 }, RS = { p = 1.0, r = 1.0 }, LS = { p = 1.0, r = 1.0 }, RH = { p = 1.0 }, LH = { p = 0.55 }, N = { p = -0.4 }, e = "back" },
		{ t = 0.3, RJ = { ln = -0.4, tw = 0.1 }, RS = { p = 0.9, r = 0.9 }, LS = { p = 0.9, r = 0.9 }, RH = { p = 0.85 }, LH = { p = 0.5 }, N = { p = -0.3 } },
		{ t = 0.45, e = "inout" },
	},
	BlockPush = { -- coup encaissé en garde : la garde tient, mais on glisse en arrière, genoux qui plient
		{ t = 0 },
		{ t = 0.04, RS = { p = 1.85, y = 1.0, r = 0.15 }, LS = { p = 1.85, y = 1.0, r = 0.15 }, RJ = { ln = -0.12, dy = -0.2, dz = -0.3 }, RH = { p = 0.55 }, LH = { p = -0.5 }, N = { p = 0.35 }, e = "back" },
		{ t = 0.24, e = "inout" },
	},

	HitHeavy = {
		{ t = 0 },
		{ t = 0.06, RJ = { ln = -0.65, tw = 0.45, dz = -0.3 }, RS = { p = 1.3, r = -1.0 }, LS = { p = 1.3, r = -1.0 }, RH = { p = 0.7 }, LH = { p = -0.3 }, N = { p = -0.5, y = 0.2 }, e = "back" },
		{ t = 0.3, RJ = { ln = -0.55, tw = 0.4, dz = -0.25 }, RS = { p = 1.2, r = -0.9 }, LS = { p = 1.2, r = -0.9 }, RH = { p = 0.6 }, N = { p = -0.35 } },
		{ t = 0.5, e = "inout" },
	},

	Launch = {
		{ t = 0 },
		{ t = 0.08, RS = { p = 2.9, r = -0.5 }, LS = { p = 2.9, r = -0.5 }, RJ = { ln = -0.45 }, RH = { p = 0.4 }, LH = { p = -0.2 }, N = { p = -0.5 }, e = "back" },
		{ t = 0.6, RS = { p = 2.6, r = -0.6 }, LS = { p = 2.7, r = -0.4 }, RJ = { ln = -0.4 }, RH = { p = 0.6 }, LH = { p = 0.1 }, N = { p = -0.35 } },
		{ t = 0.8, e = "inout" },
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
-- anciens noms (compatibilité)
ANIMS.Dropkick = ANIMS.DashStrike
-- animations ajoutées par les modules de Content
require(script.Parent.ContentLoader).merge(ANIMS, "Anims")

------------------------------------------------------------------------
-- STYLES DE M1 PAR ARME (Config/M1Styles, Modules/M1Style, docs/M1-Styles.md)
-- Écrites pour une arme en main DROITE (RS) ; la version miroir « <Nom>_L » est générée plus bas.
-- swing(i, armé, impact) : même timing que Punch1-5 -> impact pile au Windup de Config/Combat.M1 (hit serveur
-- inchangé), suivi tenu, puis retour en garde. Le 5e coup a un armé en 2 temps (enroulé lisible) et un souffle.
------------------------------------------------------------------------
local CombatCfg = require(script.Parent.Parent.Config.Combat)
local M1Cfg = CombatCfg.M1
local M1_DUR = { 0.58, 0.58, 0.6, 0.62, 1.2 } -- durées des Punch1-5

local function scaled(pose, k)
	local out = {}
	for j, v in pairs(pose) do
		local o = {}
		for a, x in pairs(v) do
			o[a] = x * k
		end
		out[j] = o
	end
	return out
end

local function at(t, pose)
	local f = table.clone(pose)
	f.t = t
	return f
end

-- v2 : poids du corps (accroupi à l'armé, fente vers l'avant à l'impact, menton) ajouté aux poses écrites
local function withBody(pose, dy, dz, n)
	local o = table.clone(pose)
	local rj = table.clone(pose.RJ or {})
	rj.dy = (rj.dy or 0) + dy
	rj.dz = (rj.dz or 0) + dz
	o.RJ = rj
	if n and not pose.N then
		o.N = n
	end
	return o
end
local function eased(frame, e)
	frame.e = e
	return frame
end

local POSES = setmetatable({}, { __mode = "k" }) -- [frames] = { armé (final), impact } : sert au jongle dérivé
local function swing(i, antic, impact)
	local w, d = M1Cfg.Windup[i] or 0.15, M1_DUR[i]
	local f = { { t = 0 } }
	POSES[f] = { i >= 5 and antic[2] or antic, impact }
	if i >= 5 then
		-- FINISHER d'archétype : enroulé accroupi en 2 temps, impact qui se déplie en fente (easing « back »)
		local hit = withBody(impact, 0.05, 0.32, { p = -0.05 })
		table.insert(f, at(w - 0.1, withBody(antic[1], -0.3, -0.05, { p = 0.2 })))
		table.insert(f, eased(at(w - 0.04, withBody(antic[2], -0.38, -0.08, { p = 0.25 })), "inout"))
		table.insert(f, eased(at(w, hit), "back"))
		table.insert(f, at(0.5, scaled(hit, 0.92)))
		table.insert(f, eased(at(0.75, scaled(hit, 0.35)), "inout"))
		table.insert(f, { t = 1.0, RS = { p = 0.4, r = -0.3 }, LS = { p = 0.4, r = -0.3 }, RJ = { ln = 0.25, dy = -0.15 }, N = { p = 0.3 } }) -- souffle (endlag)
	else
		-- coups 1-4 : léger poids du corps (genoux à l'armé, buste qui suit le coup)
		local hit = withBody(impact, 0, 0.14)
		table.insert(f, at(w - 0.04, withBody(antic, -0.1, -0.04)))
		table.insert(f, eased(at(w, hit), "back"))
		table.insert(f, at(w + 0.14, scaled(hit, 0.92)))
		table.insert(f, eased(at(d - 0.14, scaled(hit, 0.3)), "inout"))
	end
	table.insert(f, eased({ t = d }, "inout"))
	return f
end

-- variantes au timing d'une anim de base : armé à tA, impact à tI, suivi tenu à tH, fin à tE (+ réception optionnelle)
local function timed(tA, tI, tH, tE, antic, impact, landing, impactEase)
	local f = { { t = 0 }, eased(at(tA, antic), "inout"), eased(at(tI, impact), impactEase or "back"), at(tH, scaled(impact, 0.94)) }
	if landing then
		table.insert(f, at(tH + (tE - tH) * 0.45, landing))
	end
	table.insert(f, eased({ t = tE }, "inout"))
	return f
end
local UpCfg, SlamCfg, DashCfg, AirCfg = CombatCfg.Uppercut, CombatCfg.Downslam, CombatCfg.DashStrike, CombatCfg.Air
-- (v2 : accroupi à l'armé, extension / fente à l'impact, regard vers la cible)
local function up(antic, impact) -- comme Uppercut : impact 0,2 s, fin 0,65 s
	return timed(UpCfg.Windup - 0.05, UpCfg.Windup, 0.45, 0.65, withBody(antic, -0.4, 0, { p = -0.3 }), withBody(impact, 0.25, 0.15, { p = -0.3 }))
end
local function slam(antic, impact) -- comme Downslam : impact 0,16 s, fin 0,7 s
	return timed(SlamCfg.Windup - 0.04, SlamCfg.Windup, 0.45, 0.7, withBody(antic, 0.12, 0, { p = -0.3 }), withBody(impact, -0.4, 0.3, { p = -0.35 }), nil, "in")
end
local DASH_LAND = { RJ = { ln = 0.3, dy = -0.3, dz = 0.1 }, RH = { p = 0.85 }, LH = { p = -0.2 }, RS = { p = 0.6 }, LS = { p = 0.6 }, N = { p = -0.1 } }
local function dash(antic, impact) -- comme DashStrike : impact 0,16 s, tenu jusqu'à 0,48 s, réception, fin 0,8 s
	return timed(DashCfg.Windup - 0.06, DashCfg.Windup, 0.48, 0.8, withBody(antic, -0.4, 0, { p = -0.25 }), withBody(impact, 0.05, 0.35, { p = -0.2 }), DASH_LAND)
end
-- jongle : poses d'un coup au sol, jambes repliées, buste moins penché (impact au Windup Air = 0,11 s, fin 0,4 s)
local AIR_LEGS = { RH = { p = 1.1 }, LH = { p = 0.6 } }
local function airPose(pose)
	local o = table.clone(pose)
	o.RH, o.LH = AIR_LEGS.RH, AIR_LEGS.LH
	if pose.RJ then
		o.RJ = { tw = pose.RJ.tw, ln = (pose.RJ.ln or 0) * 0.6, sd = pose.RJ.sd }
	end
	return o
end
local function airFrom(ground)
	local p = POSES[ground]
	if not p then
		return nil
	end
	return timed(AirCfg.Windup - 0.04, AirCfg.Windup, 0.26, 0.4, airPose(p[1]), airPose(p[2]))
end

local STYLE_ANIMS = {
	-- BAGARREUR (main de l'arme = droite)
	Brawl4Hook = swing(4,
		{ RS = { p = 1.0, y = -1.25, r = -0.5 }, LS = { p = 1.25, y = 0.8 }, RJ = { tw = -0.7 }, RH = { p = 0.35 }, LH = { p = -0.1 } },
		{ RS = { p = 1.6, y = 0.95 }, LS = { p = 0.75, y = 0.8 }, RJ = { tw = 0.9, ln = 0.28 }, LH = { p = 0.75 }, RH = { p = -0.45 } }),
	Brawl4Elbow = swing(4, -- bras plié en travers (« coude ») qui balaie au visage
		{ RS = { p = 1.5, y = -0.6, r = -0.6 }, LS = { p = 1.2, y = 0.7 }, RJ = { tw = -0.8, ln = 0.05 }, RH = { p = 0.3 } },
		{ RS = { p = 1.55, y = 1.45 }, LS = { p = 0.6, y = 0.8 }, RJ = { tw = 1.05, ln = 0.3 }, LH = { p = 0.8 }, RH = { p = -0.45 } }),
	Brawl5Haymaker = swing(5, -- grand crochet plongeant par-dessus
		{
			{ RS = { p = -0.6, r = -0.6 }, LS = { p = 1.4, y = 0.6 }, RJ = { tw = -1.1, ln = -0.15 }, RH = { p = 0.45 }, LH = { p = 0.2 } },
			{ RS = { p = 2.4, y = -0.9, r = -0.7 }, LS = { p = 1.2, y = 0.6 }, RJ = { tw = -1.25, ln = -0.25 }, RH = { p = 0.5 }, LH = { p = 0.3 } },
		},
		{ RS = { p = 1.7, y = 0.55 }, LS = { p = 0.3, r = -0.9 }, RJ = { tw = 1.2, ln = 0.55, sd = -0.1 }, LH = { p = 1.0 }, RH = { p = -0.55 } }),
	Brawl5Shoulder = swing(5, -- charge d'épaule : on s'enroule, épaule droite en avant, gros pas
		{
			{ RS = { p = 0.6, r = 0.1 }, LS = { p = 1.3, y = 0.8 }, RJ = { tw = 0.7, ln = 0.45 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
			{ RS = { p = 0.4, r = 0.15 }, LS = { p = 1.0, y = 0.8 }, RJ = { tw = 0.9, ln = 0.55 }, RH = { p = 0.75 }, LH = { p = 0.7 } },
		},
		{ RS = { p = 0.3, r = 0.15 }, LS = { p = 1.0, y = 0.9 }, RJ = { tw = 1.35, ln = 0.3, sd = -0.1 }, LH = { p = 1.1 }, RH = { p = -0.6 } }),

	-- CONTONDANT UNE MAIN (tasse, agrafeuse, marteau, clé, matraque)
	Blunt1 = swing(1, -- coup droit en diagonale
		{ RS = { p = 1.75, y = -1.2, r = -0.45 }, LS = { p = 1.0, y = 0.7 }, RJ = { tw = -0.7, ln = -0.05 }, LH = { p = 0.25 }, RH = { p = -0.1 } },
		{ RS = { p = 1.35, y = 0.85, r = 0.05 }, LS = { p = 0.6, y = 0.6, r = -0.2 }, RJ = { tw = 0.8, ln = 0.28 }, LH = { p = 0.7 }, RH = { p = -0.45 } }),
	Blunt2 = swing(2, -- revers
		{ RS = { p = 1.45, y = 1.25, r = 0.1 }, LS = { p = 0.5, r = -0.3 }, RJ = { tw = 0.75, ln = 0.05 }, RH = { p = 0.3 }, LH = { p = -0.1 } },
		{ RS = { p = 1.5, y = -0.9, r = -0.4 }, LS = { p = 0.9, y = 0.6 }, RJ = { tw = -0.7, ln = 0.24 }, RH = { p = 0.7 }, LH = { p = -0.4 } }),
	Blunt3 = swing(3, -- frappe verticale sur le crâne
		{ RS = { p = 3.25, y = 0.15, r = -0.1 }, LS = { p = 1.1, y = 0.6 }, RJ = { tw = -0.3, ln = -0.3 }, RH = { p = -0.15 }, LH = { p = 0.2 } },
		{ RS = { p = 1.05, y = 0.3 }, LS = { p = 0.5, r = -0.2 }, RJ = { tw = 0.35, ln = 0.6 }, LH = { p = 0.8 }, RH = { p = -0.35 } }),
	Blunt4 = swing(4, -- remontée sous le menton
		{ RS = { p = -0.55, r = -0.3 }, LS = { p = 1.1, y = 0.7 }, RJ = { tw = -0.55, ln = 0.5 }, LH = { p = 0.6 }, RH = { p = 0.45 } },
		{ RS = { p = 2.55, y = 0.35 }, LS = { p = 0.4, r = -0.3 }, RJ = { tw = 0.55, ln = -0.22 }, LH = { p = 0.9 }, RH = { p = -0.3 } }),
	Blunt5 = swing(5, -- FINISHER : enroulé du buste, gros smash en diagonale descendante
		{
			{ RS = { p = 2.4, y = -1.3, r = -0.6 }, LS = { p = 1.0, y = 0.8 }, RJ = { tw = -1.15, ln = -0.15 }, RH = { p = 0.35 }, LH = { p = 0.3 } },
			{ RS = { p = 3.0, y = -1.0, r = -0.5 }, LS = { p = 0.5, r = -0.6 }, RJ = { tw = -1.3, ln = -0.3 }, RH = { p = 0.45 }, LH = { p = 0.45 } },
		},
		{ RS = { p = 1.0, y = 0.75 }, LS = { p = 0.35, r = -1.0 }, RJ = { tw = 1.15, ln = 0.6, sd = -0.1 }, LH = { p = 0.95 }, RH = { p = -0.5 } }),
	Blunt4Thrust = swing(4, -- estoc : l'arme part droit devant, l'autre main pousse le manche
		{ RS = { p = 1.2, y = 0.5, r = 0.15 }, LS = { p = 1.3, y = 0.4 }, RJ = { tw = -0.6, ln = -0.1 }, LH = { p = 0.2 }, RH = { p = 0.1 } },
		{ RS = { p = 1.75, y = 0.05 }, LS = { p = 1.6, y = 0.2 }, RJ = { tw = 0.45, ln = 0.42 }, LH = { p = 0.95 }, RH = { p = -0.6 } }),
	Blunt5Hammer = swing(5, -- marteau à deux mains au-dessus de la tête
		{
			{ RS = { p = 2.6, y = 0.2 }, LS = { p = 2.6, y = 0.2 }, RJ = { ln = -0.25 }, RH = { p = 0.3 }, LH = { p = 0.3 } },
			{ RS = { p = 3.4, y = 0.2 }, LS = { p = 3.4, y = 0.2 }, RJ = { ln = -0.5 }, RH = { p = 0.1 }, LH = { p = 0.4 } },
		},
		{ RS = { p = 0.9, y = 0.35 }, LS = { p = 0.9, y = 0.35 }, RJ = { ln = 0.85 }, RH = { p = 1.0 }, LH = { p = -0.2 } }),
	Blunt5Golf = swing(5, -- swing de golf à deux mains, du bas à droite vers le haut à gauche
		{
			{ RS = { p = 0.35, y = -0.8, r = -0.4 }, LS = { p = 0.45, y = 1.1 }, RJ = { tw = -1.0, ln = 0.45 }, RH = { p = 0.4 }, LH = { p = 0.4 } },
			{ RS = { p = 0.1, y = -1.0, r = -0.5 }, LS = { p = 0.25, y = 1.2 }, RJ = { tw = -1.2, ln = 0.55 }, RH = { p = 0.5 }, LH = { p = 0.5 } },
		},
		{ RS = { p = 2.4, y = 0.6 }, LS = { p = 2.2, y = -0.4 }, RJ = { tw = 1.1, ln = -0.2 }, LH = { p = 0.6 }, RH = { p = -0.3 } }),

	-- LOURD (kettlebell, mallette, caisse à outils) : armés amples, le poids entraîne le buste
	Heavy1 = swing(1, -- pendule par en dessous
		{ RS = { p = -0.85, r = -0.15 }, LS = { p = 0.9, y = 0.6 }, RJ = { tw = -0.35, ln = 0.35 }, LH = { p = 0.5 }, RH = { p = 0.2 } },
		{ RS = { p = 1.65, y = 0.2 }, LS = { p = 0.4, r = -0.3 }, RJ = { tw = 0.45, ln = 0.05 }, LH = { p = 0.8 }, RH = { p = -0.4 } }),
	Heavy2 = swing(2, -- crochet horizontal chargé
		{ RS = { p = 1.0, y = -1.45, r = -0.6 }, LS = { p = 1.1, y = 0.7 }, RJ = { tw = -0.9, ln = 0.05 }, LH = { p = 0.35 }, RH = { p = -0.1 } },
		{ RS = { p = 1.3, y = 1.05 }, LS = { p = 0.5, r = -0.4 }, RJ = { tw = 0.95, ln = 0.3 }, LH = { p = 0.75 }, RH = { p = -0.45 } }),
	Heavy3 = swing(3, -- chute verticale, l'autre main accompagne
		{ RS = { p = 3.2, y = 0.1 }, LS = { p = 2.7, y = 0.2 }, RJ = { ln = -0.35, tw = -0.15 }, RH = { p = -0.1 }, LH = { p = 0.25 } },
		{ RS = { p = 1.0, y = 0.3 }, LS = { p = 0.85, y = 0.35 }, RJ = { ln = 0.75, tw = 0.15 }, LH = { p = 0.85 }, RH = { p = -0.3 } }),
	Heavy4 = swing(4, -- revers tournant
		{ RS = { p = 1.25, y = 1.3 }, LS = { p = 0.4, r = -0.5 }, RJ = { tw = 0.95 }, RH = { p = 0.3 }, LH = { p = -0.15 } },
		{ RS = { p = 1.4, y = -1.05, r = -0.45 }, LS = { p = 0.9, y = 0.6 }, RJ = { tw = -0.95, ln = 0.25 }, RH = { p = 0.75 }, LH = { p = -0.4 } }),
	Heavy5 = swing(5, -- FINISHER : lancer de marteau (le poids part loin derrière puis traverse)
		{
			{ RS = { p = 0.9, y = -1.45, r = -0.7 }, LS = { p = 0.9, y = -0.6, r = -0.4 }, RJ = { tw = -1.25, ln = 0.25 }, RH = { p = 0.5 }, LH = { p = 0.5 } },
			{ RS = { p = 0.7, y = -1.5, r = -0.8 }, LS = { p = 0.6, r = -0.8 }, RJ = { tw = -1.35, ln = 0.35 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
		},
		{ RS = { p = 1.5, y = 0.9 }, LS = { p = 0.4, r = -1.1 }, RJ = { tw = 1.25, ln = 0.4, sd = -0.12 }, LH = { p = 1.0 }, RH = { p = -0.55 } }),
	Heavy4Shove = swing(4, -- poussée à deux mains (l'objet en bélier)
		{ RS = { p = 1.2, y = 0.8, r = 0.1 }, LS = { p = 1.2, y = 0.8, r = 0.1 }, RJ = { ln = -0.15, tw = -0.3 }, RH = { p = 0.2 }, LH = { p = 0.1 } },
		{ RS = { p = 1.7, y = 0.1 }, LS = { p = 1.7, y = 0.1 }, RJ = { ln = 0.45, tw = 0.1 }, LH = { p = 1.0 }, RH = { p = -0.6 } }),
	Heavy5Ground = swing(5, -- écrasement au sol à deux mains, genoux pliés
		{
			{ RS = { p = 2.8, y = 0.2 }, LS = { p = 2.8, y = 0.2 }, RJ = { ln = -0.35 }, RH = { p = 0.25 }, LH = { p = 0.25 } },
			{ RS = { p = 3.45, y = 0.2 }, LS = { p = 3.45, y = 0.2 }, RJ = { ln = -0.55 }, RH = { p = 0.1 }, LH = { p = 0.55 } },
		},
		{ RS = { p = 0.55, y = 0.35 }, LS = { p = 0.55, y = 0.35 }, RJ = { ln = 1.0 }, RH = { p = 1.1 }, LH = { p = 0.9 } }),

	-- LONG / BALAYAGE (serpillière, échelle, câble, parapluie, fil de téléphone)
	Long1 = swing(1, -- grand balayage horizontal
		{ RS = { p = 1.3, y = -1.5, r = -0.55 }, LS = { p = 1.2, y = 0.9 }, RJ = { tw = -1.0, ln = -0.05 }, LH = { p = 0.3 }, RH = { p = -0.1 } },
		{ RS = { p = 1.4, y = 1.3 }, LS = { p = 0.4, r = -0.4 }, RJ = { tw = 1.0, ln = 0.18 }, LH = { p = 0.6 }, RH = { p = -0.35 } }),
	Long2 = swing(2, -- balayage retour
		{ RS = { p = 1.35, y = 1.4 }, LS = { p = 0.4, r = -0.4 }, RJ = { tw = 0.95 }, RH = { p = 0.3 }, LH = { p = -0.1 } },
		{ RS = { p = 1.4, y = -1.3, r = -0.5 }, LS = { p = 1.1, y = 0.8 }, RJ = { tw = -1.0, ln = 0.15 }, RH = { p = 0.6 }, LH = { p = -0.35 } }),
	Long3 = swing(3, -- estoc de lance à deux mains, grand pas
		{ RS = { p = 1.1, y = 0.45, r = 0.15 }, LS = { p = 1.25, y = 0.5 }, RJ = { tw = -0.7, ln = -0.12 }, LH = { p = 0.15 }, RH = { p = 0.2 } },
		{ RS = { p = 1.65, y = 0.0 }, LS = { p = 1.55, y = 0.15 }, RJ = { tw = 0.35, ln = 0.45 }, LH = { p = 1.0 }, RH = { p = -0.65 } }),
	Long4 = swing(4, -- fauchage bas dans les jambes, accroupi
		{ RS = { p = 2.3, y = -0.9, r = -0.4 }, LS = { p = 1.0, y = 0.7 }, RJ = { tw = -0.8, ln = -0.1 }, RH = { p = 0.1 }, LH = { p = 0.3 } },
		{ RS = { p = 0.75, y = 1.2 }, LS = { p = 0.3, r = -0.5 }, RJ = { tw = 0.95, ln = 0.6 }, LH = { p = 0.9 }, RH = { p = 0.5 } }),
	Long5 = swing(5, -- FINISHER : moulinet au-dessus de la tête puis on abat
		{
			{ RS = { p = 2.6, y = -1.2, r = -0.6 }, LS = { p = 1.0, y = 0.8 }, RJ = { tw = -0.9, ln = -0.25 }, RH = { p = 0.2 }, LH = { p = 0.2 } },
			{ RS = { p = 3.4, y = -0.3 }, LS = { p = 0.6, r = -0.5 }, RJ = { tw = -0.5, ln = -0.4 }, LH = { p = 0.4 } },
		},
		{ RS = { p = 0.95, y = 0.4 }, LS = { p = 0.4, r = -0.9 }, RJ = { tw = 0.5, ln = 0.75 }, LH = { p = 0.95 }, RH = { p = -0.45 } }),
	Long5Spin = swing(5, -- FINISHER : tour complet (revers puis balayage à 360°)
		{
			{ RS = { p = 1.35, y = 1.4 }, LS = { p = 0.5, r = -0.6 }, RJ = { tw = 1.1, ln = 0.1 }, RH = { p = 0.3 }, LH = { p = 0.2 } },
			{ RS = { p = 1.4, y = -1.5, r = -0.6 }, LS = { p = 1.0, y = 0.9 }, RJ = { tw = -1.35, ln = 0.05 }, RH = { p = 0.1 }, LH = { p = 0.4 } },
		},
		{ RS = { p = 1.4, y = 1.35 }, LS = { p = 0.4, r = -1.0 }, RJ = { tw = 1.3, ln = 0.3, sd = -0.1 }, LH = { p = 0.85 }, RH = { p = -0.4 } }),

	-- PLAT / CLAQUE (clipboard, plateau, calculatrice, portable, spatule)
	Slap1 = swing(1, -- gifle à plat, poignet cassé
		{ RS = { p = 1.8, y = -1.3, r = -0.7 }, LS = { p = 1.1, y = 0.75 }, RJ = { tw = -0.6 }, LH = { p = 0.2 } },
		{ RS = { p = 1.55, y = 0.95, r = 0.15 }, LS = { p = 0.7, y = 0.7 }, RJ = { tw = 0.7, ln = 0.2 }, LH = { p = 0.6 }, RH = { p = -0.3 } }),
	Slap2 = swing(2, -- revers à plat
		{ RS = { p = 1.6, y = 1.35, r = 0.15 }, LS = { p = 0.6, r = -0.3 }, RJ = { tw = 0.7 }, RH = { p = 0.25 } },
		{ RS = { p = 1.65, y = -0.95, r = -0.55 }, LS = { p = 1.0, y = 0.7 }, RJ = { tw = -0.65, ln = 0.2 }, RH = { p = 0.6 }, LH = { p = -0.3 } }),
	Slap3 = swing(3, -- tape sur la tête (s'arrête à hauteur du crâne)
		{ RS = { p = 2.9, y = 0.45, r = -0.2 }, LS = { p = 1.0, y = 0.7 }, RJ = { ln = -0.25, tw = -0.25 }, LH = { p = 0.2 } },
		{ RS = { p = 1.55, y = 0.2 }, LS = { p = 0.6, r = -0.2 }, RJ = { ln = 0.4, tw = 0.25 }, LH = { p = 0.7 }, RH = { p = -0.35 } }),
	Slap4 = swing(4, -- gifle de l'autre main
		{ LS = { p = 1.7, y = -1.2, r = -0.6 }, RS = { p = 1.0, y = 0.6 }, RJ = { tw = 0.6 }, RH = { p = 0.2 } },
		{ LS = { p = 1.5, y = 0.95, r = 0.1 }, RS = { p = 0.7, y = 0.6 }, RJ = { tw = -0.7, ln = 0.2 }, RH = { p = 0.6 }, LH = { p = -0.3 } }),
	Slap5 = swing(5, -- FINISHER : revers tournant
		{
			{ RS = { p = 1.5, y = 1.35 }, LS = { p = 0.4, r = -0.6 }, RJ = { tw = 1.1 }, RH = { p = 0.35 }, LH = { p = 0.15 } },
			{ RS = { p = 1.7, y = 1.45, r = 0.1 }, LS = { p = 0.3, r = -0.8 }, RJ = { tw = 1.3, ln = -0.1 }, RH = { p = 0.45 }, LH = { p = 0.25 } },
		},
		{ RS = { p = 1.65, y = -1.25, r = -0.6 }, LS = { p = 0.5, r = -1.0 }, RJ = { tw = -1.2, ln = 0.3, sd = 0.1 }, RH = { p = 0.85 }, LH = { p = -0.45 } }),
	Slap4Double = swing(4, -- double claque (les deux mains se referment devant)
		{ RS = { p = 1.5, y = -1.2, r = -0.7 }, LS = { p = 1.5, y = -1.2, r = -0.7 }, RJ = { ln = -0.1 }, RH = { p = 0.2 } },
		{ RS = { p = 1.6, y = 0.55 }, LS = { p = 1.6, y = 0.55 }, RJ = { ln = 0.3 }, RH = { p = 0.6 }, LH = { p = -0.3 } }),
	Slap5Overhead = swing(5, -- FINISHER : grosse tape à deux mains par-dessus la tête
		{
			{ RS = { p = 2.7, y = 0.3 }, LS = { p = 2.7, y = 0.3 }, RJ = { ln = -0.3 }, RH = { p = 0.4 }, LH = { p = 0.4 } },
			{ RS = { p = 3.3, y = 0.3 }, LS = { p = 3.3, y = 0.3 }, RJ = { ln = -0.45 }, RH = { p = 0.2 }, LH = { p = 0.2 } },
		},
		{ RS = { p = 1.35, y = 0.3 }, LS = { p = 1.35, y = 0.3 }, RJ = { ln = 0.65 }, RH = { p = 0.8 }, LH = { p = -0.2 } }),

	-- GRIFFES (Office Cat) : coups de patte en diagonale, alternés, puis bond
	Claw1 = swing(1,
		{ RS = { p = 2.8, y = -0.6, r = -0.35 }, LS = { p = 1.3, y = 0.5 }, RJ = { tw = -0.45, ln = -0.1 }, LH = { p = 0.4 }, RH = { p = 0.1 } },
		{ RS = { p = 1.0, y = 0.75 }, LS = { p = 1.1, y = 0.5 }, RJ = { tw = 0.6, ln = 0.4 }, LH = { p = 0.75 }, RH = { p = -0.35 } }),
	Claw2 = swing(2,
		{ LS = { p = 2.85, y = -0.6, r = -0.35 }, RS = { p = 1.2, y = 0.5 }, RJ = { tw = 0.5, ln = -0.1 }, RH = { p = 0.4 }, LH = { p = 0.1 } },
		{ LS = { p = 0.95, y = 0.75 }, RS = { p = 1.1, y = 0.5 }, RJ = { tw = -0.6, ln = 0.42 }, RH = { p = 0.75 }, LH = { p = -0.35 } }),
	Claw3 = swing(3, -- double griffure vers le bas
		{ RS = { p = 3.0, y = -0.4, r = -0.45 }, LS = { p = 3.0, y = -0.4, r = -0.45 }, RJ = { ln = -0.35 }, RH = { p = 0.2 }, LH = { p = 0.2 } },
		{ RS = { p = 1.05, y = 0.45 }, LS = { p = 1.05, y = 0.45 }, RJ = { ln = 0.6 }, RH = { p = 0.7 }, LH = { p = -0.2 } }),
	Claw4 = swing(4, -- griffure montante depuis l'accroupi
		{ RS = { p = 0.3, y = -0.7, r = -0.5 }, LS = { p = 1.2, y = 0.6 }, RJ = { tw = -0.5, ln = 0.7 }, RH = { p = 0.7 }, LH = { p = 0.75 } },
		{ RS = { p = 2.1, y = 0.8 }, LS = { p = 0.6, r = -0.3 }, RJ = { tw = 0.7, ln = 0.05 }, LH = { p = 0.6 }, RH = { p = -0.3 } }),
	Claw5 = swing(5, -- FINISHER : bond, double ratissage
		{
			{ RS = { p = -0.7, r = -0.35 }, LS = { p = -0.7, r = -0.35 }, RJ = { ln = 0.65 }, RH = { p = 0.8 }, LH = { p = 0.8 } },
			{ RS = { p = 3.05, y = -0.3, r = -0.4 }, LS = { p = 3.05, y = -0.3, r = -0.4 }, RJ = { ln = -0.4 }, RH = { p = -0.2 }, LH = { p = 0.6 } },
		},
		{ RS = { p = 0.95, y = 0.55 }, LS = { p = 0.95, y = 0.55 }, RJ = { ln = 0.85 }, RH = { p = 1.15 }, LH = { p = -0.35 } }),

	-- TECH / HOLO (AI Assistant, Consultant) : paumes ouvertes, poussées d'énergie
	Tech1 = swing(1,
		{ RS = { p = 1.05, y = 0.65, r = 0.15 }, LS = { p = 1.3, y = 0.6 }, RJ = { tw = -0.55 }, LH = { p = 0.3 }, RH = { p = -0.05 } },
		{ RS = { p = 1.75, y = -0.05 }, LS = { p = 0.8, y = 0.7 }, RJ = { tw = 0.6, ln = 0.25 }, LH = { p = 0.75 }, RH = { p = -0.45 } }),
	Tech2 = swing(2,
		{ LS = { p = 1.05, y = 0.65, r = 0.15 }, RS = { p = 1.3, y = 0.6 }, RJ = { tw = 0.55 }, RH = { p = 0.3 } },
		{ LS = { p = 1.75, y = -0.05 }, RS = { p = 0.8, y = 0.7 }, RJ = { tw = -0.6, ln = 0.25 }, RH = { p = 0.75 }, LH = { p = -0.45 } }),
	Tech3 = swing(3, -- balayage montant de la tablette
		{ RS = { p = 0.25, y = -0.85, r = -0.55 }, LS = { p = 1.2, y = 0.6 }, RJ = { tw = -0.55, ln = 0.3 }, LH = { p = 0.45 }, RH = { p = 0.25 } },
		{ RS = { p = 2.35, y = 0.8 }, LS = { p = 0.6, r = -0.3 }, RJ = { tw = 0.6, ln = -0.15 }, LH = { p = 0.7 }, RH = { p = -0.3 } }),
	Tech4 = swing(4, -- double poussée
		{ RS = { p = 1.0, y = 0.95, r = 0.1 }, LS = { p = 1.0, y = 0.95, r = 0.1 }, RJ = { ln = -0.15 }, RH = { p = 0.2 } },
		{ RS = { p = 1.65, y = 0.15 }, LS = { p = 1.65, y = 0.15 }, RJ = { ln = 0.38 }, LH = { p = 0.95 }, RH = { p = -0.55 } }),
	Tech5 = swing(5, -- FINISHER : « surcharge » (mains au ciel, puis décharge devant)
		{
			{ RS = { p = 2.6, r = -0.5 }, LS = { p = 2.6, r = -0.5 }, RJ = { ln = -0.3 }, RH = { p = 0.2 }, LH = { p = 0.2 } },
			{ RS = { p = 3.1, r = -0.7 }, LS = { p = 3.1, r = -0.7 }, RJ = { ln = -0.45 }, RH = { p = 0.05 }, LH = { p = 0.35 } },
		},
		{ RS = { p = 1.7, y = 0.1 }, LS = { p = 1.7, y = 0.1 }, RJ = { ln = 0.4 }, LH = { p = 1.0 }, RH = { p = -0.6 } }),
	Tech4Swipe = swing(4, -- glissé horizontal (« swipe »)
		{ RS = { p = 1.5, y = -1.3, r = -0.5 }, LS = { p = 1.4, y = 0.8 }, RJ = { tw = -0.75 }, LH = { p = 0.3 } },
		{ RS = { p = 1.5, y = 1.1 }, LS = { p = 0.6, r = -0.4 }, RJ = { tw = 0.8, ln = 0.2 }, LH = { p = 0.7 }, RH = { p = -0.4 } }),

	-- BACON (tranche molle en fouet, hanches qui se dandinent)
	Bacon1 = swing(1, -- claquement de fouet par-dessus
		{ RS = { p = 3.35, y = -0.3, r = -0.2 }, LS = { p = 0.6, r = -0.5 }, RJ = { ln = -0.35, tw = -0.35 }, RH = { p = -0.1 }, LH = { p = 0.25 } },
		{ RS = { p = 1.25, y = 0.4 }, LS = { p = 0.4, r = -0.6 }, RJ = { ln = 0.4, tw = 0.45 }, LH = { p = 0.75 }, RH = { p = -0.35 } }),
	Bacon2 = swing(2, -- fouetté latéral
		{ RS = { p = 1.25, y = 1.4 }, LS = { p = 0.5, r = -0.6 }, RJ = { tw = 0.85 }, RH = { p = 0.3 } },
		{ RS = { p = 1.3, y = -1.35, r = -0.6 }, LS = { p = 0.9, y = 0.6 }, RJ = { tw = -0.85, ln = 0.2 }, RH = { p = 0.65 }, LH = { p = -0.35 } }),
	Bacon3 = swing(3, -- fouetté bas avec déhanché
		{ RS = { p = 0.5, y = -1.2, r = -0.6 }, LS = { p = 1.6, r = -0.6 }, RJ = { tw = -0.6, ln = 0.3, sd = 0.2 }, RH = { p = 0.5 }, LH = { p = -0.2 } },
		{ RS = { p = 1.45, y = 1.1 }, LS = { p = 1.4, r = -0.8 }, RJ = { tw = 0.75, ln = 0.35, sd = -0.2 }, LH = { p = 0.7 }, RH = { p = -0.3 } }),
	Bacon4 = swing(4, -- moulinet au-dessus de la tête puis diagonale
		{ RS = { p = 2.9, y = 1.2, r = -0.4 }, LS = { p = 0.3, r = -0.9 }, RJ = { tw = 0.5, ln = -0.2 }, RH = { p = 0.4 }, LH = { p = 0.3 } },
		{ RS = { p = 1.6, y = -0.6, r = -0.3 }, LS = { p = 0.6, r = -0.5 }, RJ = { tw = -0.55, ln = 0.35 }, RH = { p = 0.7 }, LH = { p = -0.35 } }),
	Bacon5 = swing(5, -- FINISHER « Crispy Cyclone » : lasso au-dessus de la tête puis grand fouetté
		{
			{ RS = { p = 3.0, y = -1.2, r = -0.6 }, LS = { p = 0.5, r = -0.8 }, RJ = { tw = -0.9, ln = -0.2 }, RH = { p = 0.3 }, LH = { p = 0.3 } },
			{ RS = { p = 3.2, y = 1.1, r = -0.5 }, LS = { p = 0.4, r = -1.0 }, RJ = { tw = 0.6, ln = -0.3 }, RH = { p = 0.4 }, LH = { p = 0.4 } },
		},
		{ RS = { p = 1.4, y = 0.55 }, LS = { p = 0.3, r = -1.2 }, RJ = { tw = 1.0, ln = 0.45, sd = -0.12 }, LH = { p = 0.95 }, RH = { p = -0.5 } }),

	-- variantes d'arme de l'uppercut (impact 0,2 s) et du downslam (impact 0,16 s) : mêmes timings que les originaux
	WeaponUppercut = {
		{ t = 0 },
		{ t = 0.15, RS = { p = -0.6, r = -0.25 }, LS = { p = 1.1, y = 0.7 }, RJ = { ln = 0.6, tw = -0.5 }, RH = { p = 0.7 }, LH = { p = 0.7 } },
		{ t = 0.2, RS = { p = 3.0, y = 0.3 }, LS = { p = -0.4 }, RJ = { ln = -0.4, tw = 0.5 }, LH = { p = 0.95 }, RH = { p = -0.25 } },
		{ t = 0.45, RS = { p = 2.9, y = 0.3 }, LS = { p = -0.35 }, RJ = { ln = -0.34, tw = 0.42 }, LH = { p = 0.8 } },
		{ t = 0.65 },
	},
	WeaponDownslam = {
		{ t = 0 },
		{ t = 0.12, RS = { p = 3.4, y = 0.1 }, LS = { p = 2.2 }, RJ = { ln = -0.5 }, RH = { p = 0.7 }, LH = { p = 0.5 } },
		{ t = 0.16, RS = { p = 0.7, y = 0.3 }, LS = { p = 0.4, r = -0.5 }, RJ = { ln = 0.9 }, RH = { p = 1.0 }, LH = { p = 0.9 } },
		{ t = 0.45, RS = { p = 0.75, y = 0.3 }, LS = { p = 0.45, r = -0.5 }, RJ = { ln = 0.75 }, RH = { p = 0.8 } },
		{ t = 0.7 },
	},
	-- VARIANTES UNIQUES (au moins un coup 1-3 propre à chaque personnage)
	Brawl1Lead = swing(1, -- jab plongeant, grand pas
		{ RS = { p = 1.0, y = 0.6 }, LS = { p = 1.3, y = 0.8 }, RJ = { tw = -0.4, ln = -0.1 }, LH = { p = 0.2 } },
		{ RS = { p = 1.85, y = 0.0 }, LS = { p = 1.1, y = 0.8 }, RJ = { tw = 0.5, ln = 0.45 }, LH = { p = 1.0 }, RH = { p = -0.7 } }),
	Brawl2Back = swing(2, -- revers du poing tournant
		{ RS = { p = 1.2, y = 1.3 }, LS = { p = 1.0, y = 0.8 }, RJ = { tw = 1.0 }, RH = { p = 0.3 } },
		{ RS = { p = 1.5, y = -1.1, r = -0.5 }, LS = { p = 0.8, y = 0.7 }, RJ = { tw = -1.0, ln = 0.2 }, RH = { p = 0.7 }, LH = { p = -0.4 } }),
	Brawl3Knee = swing(3, -- on agrippe et coup de genou
		{ RS = { p = 1.9, y = 0.6 }, LS = { p = 1.9, y = 0.6 }, RJ = { ln = -0.2 }, RH = { p = -0.3 } },
		{ RS = { p = 1.4, y = 0.5 }, LS = { p = 1.4, y = 0.5 }, RJ = { ln = 0.45 }, RH = { p = 1.7 }, LH = { p = -0.2 } }),
	Brawl4Point = swing(4, -- index en mousse qui pique vers le haut
		{ RS = { p = 0.6, y = 0.4 }, LS = { p = 1.2, y = 0.7 }, RJ = { tw = -0.6, ln = 0.3 }, RH = { p = 0.4 }, LH = { p = 0.4 } },
		{ RS = { p = 2.3, y = 0.1 }, LS = { p = -0.3, r = -0.4 }, RJ = { tw = 0.6, ln = -0.1 }, LH = { p = 0.8 }, RH = { p = -0.4 } }),
	Slap1Edge = swing(1, -- manchette (tranche de l'objet), de haut à l'extérieur
		{ RS = { p = 2.4, y = -0.9, r = -0.6 }, LS = { p = 1.0, y = 0.8 }, RJ = { tw = -0.7 }, LH = { p = 0.3 } },
		{ RS = { p = 1.45, y = 0.6 }, LS = { p = 0.6, y = 0.7 }, RJ = { tw = 0.6, ln = 0.3 }, LH = { p = 0.7 }, RH = { p = -0.35 } }),
	Slap2Fan = swing(2, -- revers en éventail, du bas vers le haut
		{ RS = { p = 0.6, y = 1.2 }, LS = { p = 0.8, r = -0.3 }, RJ = { tw = 0.6, ln = 0.25 }, RH = { p = 0.4 } },
		{ RS = { p = 2.1, y = -0.8, r = -0.4 }, LS = { p = 1.0, y = 0.7 }, RJ = { tw = -0.6, ln = -0.05 }, RH = { p = 0.6 }, LH = { p = -0.3 } }),
	Slap3Stamp = swing(3, -- « tamponné ! » : on écrase à plat droit devant
		{ RS = { p = 2.6, y = 0.2 }, LS = { p = 1.6, y = 0.6 }, RJ = { ln = -0.2 }, LH = { p = 0.2 } },
		{ RS = { p = 1.3, y = 0.05 }, LS = { p = 1.1, y = 0.5 }, RJ = { ln = 0.55 }, LH = { p = 0.8 }, RH = { p = -0.4 } }),
	Blunt1Snap = swing(1, -- coup sec et court (agrafeuse)
		{ RS = { p = 1.1, y = 0.3, r = 0.1 }, LS = { p = 1.2, y = 0.7 }, RJ = { tw = -0.4 }, LH = { p = 0.2 } },
		{ RS = { p = 1.8, y = 0.15 }, LS = { p = 0.8, y = 0.7 }, RJ = { tw = 0.55, ln = 0.3 }, LH = { p = 0.7 }, RH = { p = -0.4 } }),
	Blunt2Baton = swing(2, -- moulinet de matraque en revers haut
		{ RS = { p = 2.2, y = 1.2 }, LS = { p = 0.9, y = 0.6 }, RJ = { tw = 0.8, ln = -0.1 }, RH = { p = 0.3 } },
		{ RS = { p = 1.3, y = -1.1, r = -0.5 }, LS = { p = 1.0, y = 0.6 }, RJ = { tw = -0.8, ln = 0.3 }, RH = { p = 0.7 }, LH = { p = -0.4 } }),
	Blunt2Crank = swing(2, -- tour de clé bas dans les côtes
		{ RS = { p = 0.8, y = 1.3, r = 0.1 }, LS = { p = 0.6, r = -0.3 }, RJ = { tw = 0.85, ln = 0.3 }, RH = { p = 0.4 }, LH = { p = 0.2 } },
		{ RS = { p = 1.2, y = -1.0, r = -0.4 }, LS = { p = 1.0, y = 0.6 }, RJ = { tw = -0.8, ln = 0.4 }, RH = { p = 0.8 }, LH = { p = -0.3 } }),
	Blunt3Gavel = swing(3, -- « order ! » : coup de poignet sec vers le bas
		{ RS = { p = 2.7, y = 0.3 }, LS = { p = 0.9, y = 0.6 }, RJ = { ln = -0.15 }, LH = { p = 0.2 } },
		{ RS = { p = 1.25, y = 0.3 }, LS = { p = 0.7, y = 0.6 }, RJ = { ln = 0.5, tw = 0.2 }, LH = { p = 0.7 }, RH = { p = -0.3 } }),
	Blunt3Tamp = swing(3, -- tassage à deux mains (porte-filtre)
		{ RS = { p = 2.3, y = 0.3 }, LS = { p = 2.3, y = 0.3 }, RJ = { ln = -0.2 }, RH = { p = 0.2 } },
		{ RS = { p = 1.1, y = 0.3 }, LS = { p = 1.1, y = 0.3 }, RJ = { ln = 0.6 }, RH = { p = 0.7 }, LH = { p = -0.3 } }),
	Heavy1Curl = swing(1, -- curl explosif à deux mains (kettlebell)
		{ RS = { p = -0.3, r = -0.1 }, LS = { p = -0.3, r = -0.1 }, RJ = { ln = 0.45 }, RH = { p = 0.5 }, LH = { p = 0.5 } },
		{ RS = { p = 2.0, y = 0.3 }, LS = { p = 1.6, y = 0.4 }, RJ = { ln = -0.1 }, LH = { p = 0.8 }, RH = { p = -0.4 } }),
	Tech1Holo = swing(1, -- glissé de doigt sur l'hologramme puis paume
		{ RS = { p = 1.6, y = -0.5, r = -0.5 }, LS = { p = 1.3, y = 0.7 }, RJ = { tw = -0.45, ln = -0.05 }, LH = { p = 0.2 } },
		{ RS = { p = 1.5, y = 0.5, r = 0.1 }, LS = { p = 0.8, y = 0.7 }, RJ = { tw = 0.5, ln = 0.3 }, LH = { p = 0.7 }, RH = { p = -0.4 } }),
	Slap1Flip = swing(1, -- coup de spatule retourné, du bas vers le haut
		{ RS = { p = 0.2, y = 0.3, r = -0.3 }, LS = { p = 1.1, y = 0.7 }, RJ = { tw = -0.4, ln = 0.3 }, RH = { p = 0.35 }, LH = { p = 0.3 } },
		{ RS = { p = 2.5, y = 0.2 }, LS = { p = 0.6, r = -0.3 }, RJ = { tw = 0.45, ln = -0.15 }, LH = { p = 0.7 }, RH = { p = -0.35 } }),
	Blunt2Blare = swing(2, -- coup du pavillon du mégaphone, buste qui pousse
		{ RS = { p = 1.3, y = 0.9, r = 0.1 }, LS = { p = 0.8, r = -0.3 }, RJ = { tw = 0.6, ln = -0.15 }, RH = { p = 0.2 } },
		{ RS = { p = 1.7, y = -0.35, r = -0.2 }, LS = { p = 0.6, r = -0.6 }, RJ = { tw = -0.45, ln = 0.45 }, RH = { p = 0.85 }, LH = { p = -0.5 } }),
	Long1Cord = swing(1, -- claquement du fil par-dessus l'épaule
		{ RS = { p = 3.3, y = -0.6, r = -0.3 }, LS = { p = 1.0, y = 0.7 }, RJ = { tw = -0.5, ln = -0.3 }, RH = { p = -0.1 }, LH = { p = 0.25 } },
		{ RS = { p = 1.2, y = 0.5 }, LS = { p = 0.5, r = -0.4 }, RJ = { tw = 0.5, ln = 0.4 }, LH = { p = 0.75 }, RH = { p = -0.35 } }),
	Long2Mop = swing(2, -- coup de serpillière au ras du sol, retour
		{ RS = { p = 0.9, y = 1.3 }, LS = { p = 0.9, y = 0.9 }, RJ = { tw = 0.8, ln = 0.4 }, RH = { p = 0.5 }, LH = { p = 0.2 } },
		{ RS = { p = 0.8, y = -1.2, r = -0.4 }, LS = { p = 0.8, y = -0.6 }, RJ = { tw = -0.9, ln = 0.55 }, RH = { p = 0.8 }, LH = { p = -0.3 } }),
	Heavy3Briefcase = swing(3, -- mallette tenue à plat à deux mains, poussée au visage
		{ RS = { p = 1.0, y = 0.7 }, LS = { p = 1.0, y = 0.7 }, RJ = { ln = -0.2, tw = -0.35 }, RH = { p = 0.25 } },
		{ RS = { p = 1.8, y = 0.2 }, LS = { p = 1.8, y = 0.2 }, RJ = { ln = 0.45, tw = 0.2 }, LH = { p = 0.9 }, RH = { p = -0.55 } }),
	Tech3Present = swing(3, -- pointeur de présentation en estoc
		{ RS = { p = 0.9, y = -0.8, r = -0.4 }, LS = { p = 1.4, y = 0.6 }, RJ = { tw = -0.6 }, LH = { p = 0.3 } },
		{ RS = { p = 1.9, y = -0.3, r = -0.2 }, LS = { p = 0.9, y = 0.6 }, RJ = { tw = 0.4, ln = 0.3 }, LH = { p = 0.8 }, RH = { p = -0.45 } }),

	-- UPPERCUT / DOWNSLAM / DASH STRIKE par archétype (mêmes impacts et durées que les originaux)
	BrawlUppercut = up(
		{ RS = { p = -0.5, r = -0.2 }, LS = { p = 1.2, y = 0.7 }, RJ = { ln = 0.55, tw = -0.6 }, RH = { p = 0.7 }, LH = { p = 0.7 } },
		{ RS = { p = 2.9, y = 0.4 }, LS = { p = 0.9, y = 0.7 }, RJ = { ln = -0.3, tw = 0.7 }, LH = { p = 1.0 }, RH = { p = -0.3 } }),
	BrawlDownslam = slam(
		{ RS = { p = 3.3, r = -0.3 }, LS = { p = 1.0, y = 0.7 }, RJ = { ln = -0.4, tw = -0.3 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
		{ RS = { p = 0.6, y = 0.2 }, LS = { p = 0.5, r = -0.6 }, RJ = { ln = 0.85, tw = 0.3 }, RH = { p = 1.0 }, LH = { p = 0.9 } }),
	BrawlDash = dash( -- « superman punch »
		{ RS = { p = -0.8, r = -0.2 }, LS = { p = 1.2, y = 0.6 }, RJ = { ln = 0.4, tw = -0.6 }, RH = { p = -0.5 }, LH = { p = 0.8 } },
		{ RS = { p = 1.75, y = 0.1 }, LS = { p = -0.6 }, RJ = { ln = 0.35, tw = 0.6 }, RH = { p = -0.6 }, LH = { p = 0.9 } }),
	BluntDash = dash( -- bond et coup de massue
		{ RS = { p = 3.2, y = 0.2 }, LS = { p = 1.0, y = 0.7 }, RJ = { ln = -0.3 }, RH = { p = 0.6 }, LH = { p = -0.3 } },
		{ RS = { p = 1.1, y = 0.3 }, LS = { p = 0.4, r = -0.5 }, RJ = { ln = 0.6, tw = 0.3 }, RH = { p = 1.0 }, LH = { p = -0.5 } }),
	HeavyUppercut = up( -- arraché à deux mains
		{ RS = { p = -0.5 }, LS = { p = -0.5 }, RJ = { ln = 0.7 }, RH = { p = 0.8 }, LH = { p = 0.8 } },
		{ RS = { p = 3.0, y = 0.2 }, LS = { p = 3.0, y = 0.2 }, RJ = { ln = -0.45 }, RH = { p = -0.2 }, LH = { p = 0.3 } }),
	HeavyDownslam = slam(
		{ RS = { p = 3.45 }, LS = { p = 3.45 }, RJ = { ln = -0.55 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
		{ RS = { p = 0.5, y = 0.3 }, LS = { p = 0.5, y = 0.3 }, RJ = { ln = 1.0 }, RH = { p = 1.1 }, LH = { p = 1.0 } }),
	HeavyDash = dash( -- ruée, le poids part en balancier
		{ RS = { p = -0.7, r = -0.3 }, LS = { p = 1.0, y = 0.8 }, RJ = { tw = -0.8, ln = 0.3 }, RH = { p = 0.5 }, LH = { p = 0.4 } },
		{ RS = { p = 1.6, y = 0.6 }, LS = { p = 0.4, r = -0.8 }, RJ = { tw = 0.9, ln = 0.35 }, RH = { p = -0.5 }, LH = { p = 0.9 } }),
	LongUppercut = up( -- balayage montant
		{ RS = { p = 0.3, y = -1.0, r = -0.5 }, LS = { p = 1.0, y = 0.8 }, RJ = { ln = 0.5, tw = -0.7 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
		{ RS = { p = 3.1, y = 0.6 }, LS = { p = 0.4, r = -0.6 }, RJ = { ln = -0.35, tw = 0.6 }, LH = { p = 1.0 }, RH = { p = -0.3 } }),
	LongDownslam = slam(
		{ RS = { p = 3.4, y = -0.4 }, LS = { p = 2.4, y = 0.3 }, RJ = { ln = -0.45, tw = -0.3 }, RH = { p = 0.6 }, LH = { p = 0.5 } },
		{ RS = { p = 0.85, y = 0.35 }, LS = { p = 0.6, y = 0.4 }, RJ = { ln = 0.9, tw = 0.2 }, RH = { p = 1.0 }, LH = { p = 0.9 } }),
	LongDash = dash( -- charge à la lance
		{ RS = { p = 1.1, y = 0.45, r = 0.15 }, LS = { p = 1.25, y = 0.5 }, RJ = { tw = -0.8, ln = 0.1 }, RH = { p = 0.6 }, LH = { p = -0.2 } },
		{ RS = { p = 1.6 }, LS = { p = 1.5, y = 0.15 }, RJ = { tw = 0.3, ln = 0.5 }, RH = { p = -0.6 }, LH = { p = 1.0 } }),
	SlapUppercut = up( -- tape montante à plat
		{ RS = { p = 0.2, y = -0.6, r = -0.6 }, LS = { p = 1.1, y = 0.7 }, RJ = { ln = 0.5, tw = -0.5 }, RH = { p = 0.7 }, LH = { p = 0.7 } },
		{ RS = { p = 2.8, y = 0.2, r = 0.2 }, LS = { p = 0.6, r = -0.4 }, RJ = { ln = -0.3, tw = 0.5 }, LH = { p = 1.0 }, RH = { p = -0.25 } }),
	SlapDownslam = slam( -- claque à deux mains vers le sol
		{ RS = { p = 3.2, y = 0.3 }, LS = { p = 3.2, y = 0.3 }, RJ = { ln = -0.45 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
		{ RS = { p = 1.0, y = 0.4 }, LS = { p = 1.0, y = 0.4 }, RJ = { ln = 0.85 }, RH = { p = 1.0 }, LH = { p = 0.9 } }),
	SlapDash = dash( -- gifle volante
		{ RS = { p = 1.7, y = -1.3, r = -0.7 }, LS = { p = 0.8, r = -0.4 }, RJ = { tw = -0.7, ln = 0.2 }, RH = { p = -0.4 }, LH = { p = 0.8 } },
		{ RS = { p = 1.55, y = 1.0, r = 0.15 }, LS = { p = 0.4, r = -0.6 }, RJ = { tw = 0.8, ln = 0.35 }, RH = { p = -0.5 }, LH = { p = 0.9 } }),
	ClawUppercut = up( -- double griffure montante
		{ RS = { p = -0.5, r = -0.4 }, LS = { p = -0.5, r = -0.4 }, RJ = { ln = 0.7 }, RH = { p = 0.8 }, LH = { p = 0.8 } },
		{ RS = { p = 3.0, y = 0.4 }, LS = { p = 3.0, y = 0.4 }, RJ = { ln = -0.4 }, RH = { p = -0.2 }, LH = { p = 0.4 } }),
	ClawDownslam = slam(
		{ RS = { p = 3.2, y = -0.3, r = -0.4 }, LS = { p = 3.2, y = -0.3, r = -0.4 }, RJ = { ln = -0.45 }, RH = { p = 0.8 }, LH = { p = 0.8 } },
		{ RS = { p = 0.8, y = 0.5 }, LS = { p = 0.8, y = 0.5 }, RJ = { ln = 1.0 }, RH = { p = 1.2 }, LH = { p = 1.1 } }),
	ClawDash = dash( -- bond du chat, pattes en avant
		{ RS = { p = -0.6, r = -0.3 }, LS = { p = -0.6, r = -0.3 }, RJ = { ln = 0.7 }, RH = { p = 0.9 }, LH = { p = 0.9 } },
		{ RS = { p = 1.9, y = 0.3 }, LS = { p = 1.9, y = 0.3 }, RJ = { ln = 0.2 }, RH = { p = -0.5 }, LH = { p = -0.3 } }),
	TechUppercut = up( -- paumes qui lancent vers le haut
		{ RS = { p = 0.4, y = 0.8 }, LS = { p = 0.4, y = 0.8 }, RJ = { ln = 0.5 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
		{ RS = { p = 2.9, y = 0.1 }, LS = { p = 2.9, y = 0.1 }, RJ = { ln = -0.35 }, LH = { p = 0.9 }, RH = { p = -0.2 } }),
	TechDownslam = slam(
		{ RS = { p = 3.2, r = -0.6 }, LS = { p = 3.2, r = -0.6 }, RJ = { ln = -0.45 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
		{ RS = { p = 1.2, y = 0.1 }, LS = { p = 1.2, y = 0.1 }, RJ = { ln = 0.8 }, RH = { p = 1.0 }, LH = { p = 0.9 } }),
	TechDash = dash( -- poussée d'énergie en glissant
		{ RS = { p = 1.0, y = 0.9 }, LS = { p = 1.0, y = 0.9 }, RJ = { ln = -0.1 }, RH = { p = -0.4 }, LH = { p = 0.8 } },
		{ RS = { p = 1.7 }, LS = { p = 1.7 }, RJ = { ln = 0.4 }, RH = { p = -0.6 }, LH = { p = 0.9 } }),
	BaconUppercut = up( -- lasso montant, déhanché
		{ RS = { p = 0.4, y = -1.3, r = -0.6 }, LS = { p = 1.4, r = -0.6 }, RJ = { ln = 0.45, tw = -0.6, sd = 0.15 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
		{ RS = { p = 3.2, y = 0.9 }, LS = { p = 1.2, r = -0.8 }, RJ = { ln = -0.35, tw = 0.6, sd = -0.15 }, LH = { p = 1.0 }, RH = { p = -0.3 } }),
	BaconDownslam = slam(
		{ RS = { p = 3.4, y = 1.0, r = -0.4 }, LS = { p = 0.4, r = -0.9 }, RJ = { ln = -0.45, tw = 0.4 }, RH = { p = 0.6 }, LH = { p = 0.5 } },
		{ RS = { p = 0.9, y = -0.3 }, LS = { p = 0.5, r = -0.7 }, RJ = { ln = 0.9, tw = -0.3 }, RH = { p = 1.0 }, LH = { p = 0.9 } }),
	BaconDash = dash( -- fouet volant
		{ RS = { p = 3.2, y = -0.4 }, LS = { p = 0.5, r = -0.7 }, RJ = { ln = -0.2, tw = -0.4 }, RH = { p = -0.4 }, LH = { p = 0.8 } },
		{ RS = { p = 1.3, y = 0.5 }, LS = { p = 0.4, r = -0.8 }, RJ = { ln = 0.45, tw = 0.5 }, RH = { p = -0.5 }, LH = { p = 0.9 } }),

	-- OBJETS : variantes alternées (mêmes temps de keyframes que Jab / SideSwing / OverheadSwing)
	JabB = {
		{ t = 0 },
		{ t = 0.05, RS = { p = 2.4, y = -0.3 }, RJ = { tw = -0.25, ln = -0.1 } },
		{ t = 0.1, RS = { p = 1.4, y = 0.3 }, RJ = { tw = 0.4, ln = 0.3 }, LH = { p = 0.5 }, RH = { p = -0.3 } },
		{ t = 0.2, RS = { p = 1.35, y = 0.3 }, RJ = { tw = 0.35, ln = 0.25 }, LH = { p = 0.45 } },
		{ t = 0.3 },
	},
	SideSwingB = {
		{ t = 0 },
		{ t = 0.09, RS = { p = 1.4, y = 1.2 }, RJ = { tw = 0.75 }, RH = { p = 0.3 } },
		{ t = 0.17, RS = { p = 1.45, y = -1.0, r = -0.4 }, RJ = { tw = -0.8, ln = 0.15 }, RH = { p = 0.55 }, LH = { p = -0.3 } },
		{ t = 0.3, RS = { p = 1.4, y = -0.95, r = -0.35 }, RJ = { tw = -0.75, ln = 0.12 }, RH = { p = 0.5 } },
		{ t = 0.42 },
	},
	OverheadSwingB = {
		{ t = 0 },
		{ t = 0.15, RS = { p = 3.0, y = -0.9, r = -0.4 }, LS = { p = 1.6 }, RJ = { ln = -0.25, tw = -0.6 }, RH = { p = -0.2 } },
		{ t = 0.24, RS = { p = 1.0, y = 0.7 }, LS = { p = 0.4 }, RJ = { ln = 0.5, tw = 0.6 }, LH = { p = 0.65 }, RH = { p = -0.45 } },
		{ t = 0.4, RS = { p = 1.0, y = 0.7 }, RJ = { ln = 0.45, tw = 0.55 }, LH = { p = 0.6 }, RH = { p = -0.4 } },
		{ t = 0.55 },
	},
}
local M1StylesData = require(script.Parent.Parent.Config.M1Styles)
-- jongle de chaque archétype, dérivé des coups au sol (Config/M1Styles.AirFrom)
for name, from in pairs(M1StylesData.AirFrom) do
	STYLE_ANIMS[name] = STYLE_ANIMS[name] or airFrom(STYLE_ANIMS[from])
end
for name, frames in pairs(STYLE_ANIMS) do
	if not ANIMS[name] then
		ANIMS[name] = frames
	end
end

-- miroir gauche/droite : on échange les membres et on inverse la rotation / l'inclinaison latérale du buste
local MIRROR_SWAP = { RS = "LS", LS = "RS", RH = "LH", LH = "RH" }
local function mirrorFrames(frames)
	local out = {}
	for i, f in ipairs(frames) do
		local m = { t = f.t }
		for k, v in pairs(f) do
			if MIRROR_SWAP[k] then
				m[MIRROR_SWAP[k]] = v
			elseif k == "RJ" then
				m.RJ = { tw = -(v.tw or 0), ln = v.ln or 0, sd = -(v.sd or 0) }
			end
		end
		out[i] = m
	end
	return out
end
ProcAnim.mirrorFrames = mirrorFrames
-- version « _L » (arme fétiche en main gauche : M1Style.remap) construite à la demande au premier play : seules les
-- animations réellement jouées en miroir existent (jamais pour les Use d'objets)
local function animFrames(name)
	local frames = ANIMS[name]
	if frames == nil and type(name) == "string" then
		local base = string.match(name, "^(.+)_L$")
		local meta = base and M1StylesData.Moves[base]
		if meta and meta.Kind ~= "Item" and ANIMS[base] then
			frames = mirrorFrames(ANIMS[base])
			ANIMS[name] = frames
		end
	end
	return frames
end
ProcAnim.animFrames = animFrames

ProcAnim.Anims = ANIMS

local states = {}
local playHooks = {}

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
	local pose = table.clone(HOLD_POSES[character:GetAttribute("HoldPose") or ""] or {})
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
	local serverNow = workspace:GetServerTimeNow()
	if character:GetAttribute("Blocking") then
		for k, v in pairs(HOLD_POSES.Block) do
			pose[k] = v
		end
	elseif serverNow < (character:GetAttribute("GuardBrokenUntil") or 0) then
		-- guard break : sonné, garde baissée (lisible de loin : « punissez-le ! »)
		for k, v in pairs(HOLD_POSES.GuardBroken) do
			pose[k] = v
		end
	elseif serverNow < (character:GetAttribute("StunUntil") or 0) then
		for k, v in pairs(HOLD_POSES.Stunned) do
			if not pose[k] then
				pose[k] = v
			end
		end
	elseif serverNow < (character:GetAttribute("EndlagUntil") or 0) then
		for k, v in pairs(HOLD_POSES.Winded) do
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
	local frames = animFrames(name)
	local s = character and getState(character)
	if not frames or not s then
		return
	end
	s.track = { frames = frames, t = 0, speed = speed or 1 }
	s.blend = nil
	for _, fn in ipairs(playHooks) do
		task.spawn(fn, character, name)
	end
end

-- écoute des animations nommées jouées (M1StyleController : traînées / impacts des M1, local ET autres joueurs)
function ProcAnim.onPlay(fn)
	if type(fn) == "function" then
		table.insert(playHooks, fn)
	end
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
		-- fin du renversé : animation de relevé (lisible : « il se relève, invulnérable un instant »)
		local down = workspace:GetServerTimeNow() < (character:GetAttribute("KnockdownUntil") or 0)
		if s.wasDown and not down then
			local hum = character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				s.track = { frames = ANIMS.GetUp, t = 0, speed = 1 }
				s.blend = nil
			end
		end
		s.wasDown = down
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
