--[[
	Combat — fiche de données du combat commun (tous les personnages), système « ABA » (Anime Battle Arena).
	Toutes les valeurs d'équilibrage sont ici : ne pas les coder en dur ailleurs. Détails : docs/Combat-ABA.md

	COMMANDES (PC) :
		Clic x5            chaîne de M1 (coups 1-4 légers qui étourdissent, 5e = FINISHER lourd qui renverse)
		Espace + 5e clic   UPPERCUT : la victime décolle, on la suit automatiquement, puis 3 clics en l'air (le 3e = DOWNSLAM)
		5e clic en l'air   DOWNSLAM (écrase au sol)
		F maintenu         BLOCK (jauge de garde) ; F juste avant le coup (PerfectWindow) = PERFECT BLOCK (parade)
		Q + direction      DASH avant / arrière / CÔTÉ (relatif à la caméra) ; dash avant + clic = DASH STRIKE (lourd)
		Q pendant un combo EVASIVE : on se libère (longue recharge)
	GARDE (Block) : un PERFECT BLOCK bat tout (même les coups qui cassent la garde).
	  - CASSE-GARDE (p.guardBreak) : 5e M1 (finisher), uppercut, downslam, dash strike, attaques de perso avec
	    GuardBreak = true -> cassent DIRECTEMENT un block normal (GUARD BREAK).
	  - LOURD (Category "Heavy" ou p.heavy, sans guardBreak : attaques de perso / objets / lancers lourds) -> vident la
	    jauge de garde Block.HeavyGuardMult (x2,5) plus vite ; jauge vide = GUARD BREAK.
	  - Chaque coup bloqué repousse le prochain coup de l'attaquant de Block.BlockAdvantage (avantage au bloqueur).
	ULTIMES (category "Ultimate" ou p.ultimate) : seules à ignorer le renversé (knockdown) et l'anti-infini (ComboCap).
	ENDLAG des attaques de perso : AbilityEndlag (ou cfg.Endlag) après la fin de l'attaque : ni attaque, ni dash, ni block.

	ZONES SÛRES : un personnage avec l'attribut SafeZone = true (zone AFK) ne peut ni frapper ni être frappé
	(CombatService.applyHit ignore le coup) et ne peut pas lancer de M1 / dash / attaque.
]]
return {
	MaxHealth = 100,
	BaseWalkSpeed = 16,
	BaseJumpPower = 50,
	RespawnTime = 4,

	-- M1 au sol : chaîne de 5 coups, cadence lente et lisible (anticipation visible avant chaque impact).
	M1 = {
		Hits = 5,
		Damage = { 3, 3, 3, 4, 7 },
		Windup = { 0.14, 0.14, 0.15, 0.16, 0.22 },   -- délai entre le clic et l'impact (l'armé se voit)
		Cooldown = { 0.46, 0.46, 0.48, 0.5, 1.35 },  -- délai avant le M1 suivant ; le 5e = endlag (punissable)
		DropEndlag = 0.3,   -- chaîne lâchée avant le 5e coup : ni block ni attaque de perso pendant Cooldown + DropEndlag
		ComboReset = 1.0,   -- sans clic pendant ce délai, la chaîne repart du 1er coup
		HitboxSize = Vector3.new(5.5, 5.5, 6),
		HitboxOffset = 3,
		Knockback = { 2, 2, 2, 2.5, 58 }, -- coups 1-4 : la victime reste à portée ; 5e : éjection
		KnockUp = { 0, 0, 0, 0, 18 },
		Stun = { 0.66, 0.66, 0.68, 0.72, 1.0 }, -- vrai hitstun : couvre l'intervalle jusqu'au coup suivant
		Power = { 0.3, 0.33, 0.38, 0.45, 0.95 },
		Category = { "Light", "Light", "Light", "Light", "Heavy" },
		Anim = { "Punch1", "Punch2", "Punch3", "Punch4", "Punch5" },
		Lunge = { 11, 11, 12, 12, 16 }, -- petit pas en avant à chaque coup (studs/s pendant 0,1 s)
		MaxTargets = 3,
		FinisherWords = { "FINISHER!", "WHAM!", "KAPOW!" },
	},

	-- Espace maintenu sur le 5e coup : la victime décolle, l'attaquant saute automatiquement derrière elle.
	Uppercut = {
		Damage = 6, LaunchUp = 58, LaunchForward = 3, Stun = 1.3, Power = 0.95, Anim = "Uppercut", Windup = 0.2,
		FollowJump = 60, FollowForward = 10, -- saut automatique de l'attaquant (client) après un uppercut réussi
		AirHits = 3, AirWindow = 2.4,        -- 3 M1 en l'air (le 3e = DOWNSLAM) pendant AirWindow
		Words = { "UPPERCUT!", "SKY HIGH!", "BOING!" },
	},
	-- M1 en l'air (jongle) : la victime et l'attaquant restent suspendus un instant
	Air = {
		Damage = { 3, 3, 3, 4 },
		Stun = 0.85, Stall = 0.5, Windup = 0.11, Cooldown = 0.4,
		HitboxSize = Vector3.new(7, 10, 7.5), HitboxOffset = 3,
		Anim = { "Air1", "Air2", "Air3" },
	},
	-- 5e M1 en l'air / 3e coup du jongle d'uppercut : écrase au sol, puis renversé (Knockdown)
	Downslam = {
		Damage = 7, SlamSpeed = 140, Stun = 1.2, Power = 1.1, Anim = "Downslam", Windup = 0.16, Endlag = 0.9,
		BounceUp = 0, Pin = true, Knockdown = true,
		Words = { "WHAM!", "KABOOM!", "SLAM!" },
	},
	-- Dash AVANT puis clic dans la fenêtre : coup de pied volant lourd (remplace l'ancien Dropkick)
	DashStrike = {
		Damage = 7, Knockback = 72, KnockUp = 14, Stun = 1.0, Power = 1.0, Anim = "DashStrike",
		LungeSpeed = 56, LungeTime = 0.22, Windup = 0.16, Endlag = 0.8, Cooldown = 7, Window = 0.4,
		HitboxSize = Vector3.new(6, 6, 8), HitboxOffset = 4,
		Words = { "DASH STRIKE!", "WHAM!", "KAPOW!" },
	},
	-- Renversé (finisher, downslam, dash strike) : au sol, intouchable (sauf ultimes), puis relevé invulnérable
	Knockdown = { Duration = 1.0, GetUpIFrames = 0.6 },

	AttackSlow = 0.55,         -- l'attaquant ralentit pendant ses M1 (multiplicateur de vitesse)
	AbilityGCD = 0.6,          -- délai minimum entre deux attaques de personnage
	-- endlag des attaques de perso (après la fin du Kind, ou au plus tard après son temps actif estimé) selon la
	-- Category de la fiche ; une fiche peut forcer cfg.Endlag = secondes (0 = aucun). Pose EndlagUntil (pose « Winded »).
	AbilityEndlag = { Heavy = 0.45, Light = 0.25 },
	TelegraphMin = 0.12,       -- toute anticipation (windup) d'attaque de perso >= ce délai envoie un télégraphe
	-- compensation de latence des hitboxes : positions des victimes « rembobinées » de la latence de l'attaquant
	LagComp = { MaxRewind = 0.15, History = 1.0, Rate = 20 },
	PinStun = 1.4,             -- durée au sol des attaques qui plaquent (Effects.Pin)
	SoftLock = { Range = 11, Angle = 75 }, -- les M1 et les attaques se tournent vers l'ennemi le plus proche devant soi
	InputBuffer = 0.25,        -- un clic trop tôt est gardé en mémoire et joué dès que possible
	ItemFinisher = { MinCombo = 2, Window = 1.6, DamageMult = 1.5, KnockbackMult = 1.3 },

	ComboWindow = 1.6,         -- délai max entre deux coups pour garder le compteur de combo (HUD)
	Run = { SpeedMultiplier = 1.65, DoubleTapWindow = 0.3 }, -- double W = courir (mobile : bouton RUN)
	-- Dash directionnel (WASD relatif à la caméra ; sans direction = avant). Pas d'invulnérabilité.
	Dash = { Speed = 64, BackSpeed = 56, SideSpeed = 60, Time = 0.2, Cooldown = 2 },
	Block = {
		Reduction = 0.85,     -- dégâts bloqués (le reste passe en « chip »)
		WalkSpeed = 7,
		MaxGuard = 40,        -- jauge de garde : chaque coup bloqué la vide de ses dégâts ; vide = GUARD BREAK
		GuardRegen = 12,      -- points par seconde
		GuardRegenDelay = 1.2, -- la jauge ne remonte qu'après ce délai sans coup bloqué
		GuardBreakStun = 1.6, -- étourdi (et sans block) après un guard break
		HeavyBreaks = true,   -- un coup CASSE-GARDE (p.guardBreak : finisher, uppercut, downslam, dash strike, GuardBreak = true) casse direct
		HeavyGuardMult = 2.5, -- un coup lourd (Heavy) sans guardBreak vide la jauge 2,5x plus vite (au lieu de casser)
		BlockAdvantage = 0.12, -- chaque coup bloqué retarde le prochain coup de l'attaquant (s)
		PingAllowance = 0.1,  -- perfect block : l'appui est daté de min(ping/2, PingAllowance) plus tôt (latence du bloqueur)
		PerfectWindow = 0.22, -- PERFECT BLOCK : F appuyé dans ce délai avant le coup (marche aussi contre les lourds)
		ParryWindow = 0.22,   -- (ancien nom, gardé pour compatibilité)
		ParryStun = 1.4, ParryRearm = 0.5, ParryKnockback = 22,
		ParryFailRearm = 1.0, -- perfect block RATÉ (fenêtre écoulée sans coup) : pas de nouvelle fenêtre pendant ce délai
	},
	-- ANTI-INFINI : combo vrai subi (chaque coup arrive pendant le hitstun du précédent). TOUS les coups comptent
	-- (M1, jongle, objets, attaques de perso : 1 lien chacun, ou p.linkWeight ; multi-coups / cônes ≈ 2 liens au total).
	-- Dès MaxLinks liens OU MaxTime secondes, le coup suivant RENVERSE de force la victime (knockdown = intouchable
	-- puis relevé invulnérable). Le combo complet légitime (4 M1 + uppercut + 2 en l'air = 7 liens, downslam qui
	-- renverse) passe, avec la place pour 1 attaque / objet. Seules les ULTIMES ne sont pas concernées.
	ComboCap = { MaxLinks = 9, MaxTime = 4.8, Grace = 0.05, Knockback = 30, Up = 14, Words = { "BREAK AWAY!", "TOO LONG!" } },
	-- EVASIVE (combo breaker) : Q pendant un hitstun -> on se libère, invulnérable un instant, les attaquants proches
	-- sont repoussés. Interdit pendant un guard break (punition du block) et quand on est renversé (déjà intouchable).
	Evasive = { Cooldown = 18, IFrames = 0.5, Radius = 10, Knockback = 46, AttackerStun = 0.45, Hop = 22,
		AttackerMemory = 2 }, -- seuls ceux qui ont touché l'évadé dans les AttackerMemory s (ou le tiennent en laisse) sont repoussés
	WallSplat = { MinSpeed = 36, Damage = 5, Stun = 0.9 },
	Overtime = { Max = 100, DealMult = 0.4, TakeMult = 0.22, Parry = 5, DurationMult = 1.75 }, -- ~250 dégâts infligés pour remplir

	-- ressenti par catégorie (lus par CartoonFX) : un peu plus de gel sur les coups lourds pour la lisibilité
	HitStop = { Light = 0.08, Heavy = 0.2, KO = 0.42 },
	Shake = { Light = 0.3, Heavy = 1.0, KO = 1.6 },
	FOVKick = { Light = 1.5, Heavy = 7, KO = 12 },

	LatencyTolerance = 2,
	PickupRange = 9,
	StunWalkSpeed = 0, -- étourdi = immobile (on ne peut plus rien faire pendant les M1 adverses)
	DizzyThreshold = 0.8,
	LowHealth = 30,
	SpawnProtection = 3,
	KOLaunch = { Speed = 95, Up = 60 },
	SafeZoneAttribute = "SafeZone", -- attribut posé par la zone AFK (voir en-tête)

	RemoteRate = { Run = 8, Attack = 12, Pickup = 6, Throw = 4, Dash = 5, Block = 14, Ability = 6, Transform = 2 },
}
