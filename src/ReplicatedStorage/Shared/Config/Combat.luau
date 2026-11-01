--[[
	Combat — fiche de données du combat commun (tous les personnages).
	Toutes les valeurs d'équilibrage sont ici : ne pas les coder en dur ailleurs.
]]
return {
	MaxHealth = 100,
	BaseWalkSpeed = 16,
	BaseJumpPower = 50,
	RespawnTime = 4,

	-- M1 au sol : combo de 4 coups (le 4e repousse). Lunge = petit pas en avant à chaque coup.
	M1 = {
		Damage = { 4, 4, 5, 7 },
		Cooldown = { 0.3, 0.3, 0.32, 1.15 }, -- le 4e coup a un gros temps de récupération (anti-spam)
		ComboReset = 1.0,
		Windup = 0.06,
		HitboxSize = Vector3.new(5.5, 5.5, 6),
		HitboxOffset = 3,
		Knockback = { 2.5, 2.5, 3, 60 }, -- petits reculs : la victime reste à portée (combos fluides)
		KnockUp = { 0, 0, 0, 20 },
		Stun = { 0.6, 0.6, 0.65, 0.9 },
		Power = { 0.3, 0.35, 0.45, 0.85 },
		Category = { "Light", "Light", "Light", "Heavy" },
		Anim = { "Punch1", "Punch2", "Punch3", "Punch4" },
		Lunge = { 14, 14, 16, 20 },
		MaxTargets = 3,
	},

	-- Variantes (M1 directionnels)
	Uppercut = { -- Espace maintenu sur le 4e coup : envoie en l'air
		Damage = 7, LaunchUp = 56, Knockback = 4, Stun = 1.1, Power = 0.85, Anim = "Uppercut",
		FollowWindow = 0.9, FollowJump = 82, -- l'attaquant peut sauter pour suivre
		Words = { "UPPERCUT!", "POW!", "BOING!" },
	},
	Air = { -- M1 en l'air : jongle
		Damage = { 4, 4, 5 },
		Stall = 0.55,             -- suspension en l'air (victime + attaquant) après chaque coup aérien
		Anim = { "Air1", "Air2", "Air3" },
	},
	Downslam = { -- 4e coup en l'air : écrase au sol
		Damage = 9, SlamSpeed = 140, Stun = 1.3, Power = 1.1, Anim = "Downslam", BounceUp = 0, Pin = true,
		Words = { "WHAM!", "KABOOM!", "SLAM!" },
	},
	Dropkick = { -- Ctrl+M1 (ou M1 juste après un dash) : coup qui traverse et envoie très loin
		Damage = 8, Knockback = 100, KnockUp = 16, Stun = 1.0, Power = 0.95, Anim = "Dropkick",
		LungeSpeed = 60, LungeTime = 0.2, Cooldown = 6, Windup = 0.12,
		HitboxSize = Vector3.new(6, 6, 9), HitboxOffset = 4,
		Words = { "DROPKICK!", "WHAM!", "KAPOW!" },
	},
	-- COMBOS (Espace pendant la chaîne de M1)
	--   2 M1 + Espace : RISING DUO  -> les DEUX joueurs montent ; en l'air 2 M1, le 2e écrase la victime au sol
	--   3 M1 + Espace : UPPERCUT    -> seule la victime monte ; sauter pour suivre, 3 M1 en l'air, le 3e écrase
	--   4 M1          : FINISHER    -> gros recul ; Ctrl + M1 (ou M1 juste après un dash) : DROPKICK (recharge 6 s)
	Combos = {
		Window = 0.85,         -- délai max après le dernier M1 pour appuyer sur Espace
		RisingDuo = { Damage = 6, VictimUp = 52, AttackerUp = 52, Stall = 1.0, AirHits = 2, Power = 0.8, Words = { "RISING DUO!", "UP WE GO!" } },
		Uppercut = { Damage = 8, VictimUp = 58, AirHits = 3, Power = 0.9, Words = { "UPPERCUT!", "SKY HIGH!" } },
		AirMaxDefault = 3,     -- M1 en l'air sans lanceur : 3 coups, le dernier écrase
	},
	AttackSlow = 0.7,         -- l'attaquant ralentit pendant ses M1 (multiplicateur de vitesse)
	AbilityGCD = 0.6,          -- délai minimum entre deux attaques de personnage
	-- 3 M1 + saut + M1 : GROUND PIN (plaque la victime au sol avec une onde de choc au lieu de l'expulser)
	GroundPin = { Damage = 10, SlamSpeed = 150, Stun = 1.5, Power = 1.15, Window = 1.1, Words = { "PINNED!", "GROUND POUND!", "STAY DOWN!" } },
	PinStun = 1.4,            -- durée au sol des attaques qui plaquent (Effects.Pin)
	SoftLock = { Range = 11, Angle = 75 }, -- les M1 et les attaques se tournent vers l'ennemi le plus proche devant soi
	InputBuffer = 0.22,       -- un clic trop tôt est gardé en mémoire et joué dès que possible
	ItemFinisher = { MinCombo = 2, Window = 1.6, DamageMult = 1.5, KnockbackMult = 1.3 },

	ComboWindow = 1.6,        -- délai max entre deux coups pour garder le compteur
	Run = { SpeedMultiplier = 1.65, DoubleTapWindow = 0.3 }, -- double W = courir (mobile : bouton RUN)
	Dash = { Speed = 72, Time = 0.18, Cooldown = 1.4, AttackWindow = 0.3 },
	Block = {
		Reduction = 0.8, WalkSpeed = 8, MaxGuard = 45, GuardRegen = 15,
		GuardBreakStun = 1.5, ParryWindow = 0.25, ParryStun = 1.5, ParryRearm = 0.5, ParryKnockback = 22,
	},
	ComboBreaker = { Hits = 5, Window = 1.4, Cooldown = 15, Radius = 11, Knockback = 60, Protect = 0.7 },
	WallSplat = { MinSpeed = 36, Damage = 5, Stun = 0.9 },
	Overtime = { Max = 100, DealMult = 0.4, TakeMult = 0.22, Parry = 5, DurationMult = 1.75 }, -- ~250 dégâts infligés pour remplir

	HitStop = { Light = 0.08, Heavy = 0.17, KO = 0.4 },
	Shake = { Light = 0.35, Heavy = 1.05, KO = 1.6 },
	FOVKick = { Light = 2, Heavy = 8, KO = 13 },

	LatencyTolerance = 2,
	PickupRange = 9,
	StunWalkSpeed = 0, -- étourdi = immobile (on ne peut plus rien faire pendant les M1 adverses)
	DizzyThreshold = 0.8,
	LowHealth = 30,
	SpawnProtection = 3,
	KOLaunch = { Speed = 95, Up = 60 },

	RemoteRate = { Run = 8, Attack = 14, Pickup = 6, Throw = 4, Dash = 4, Block = 12, Ability = 6, Transform = 2 },
}
