--[[
	Attacks — une fiche par attaque de personnage (touches 1, 2, 3 ; transformées pendant la transformation).
	Ajouter une attaque = une fiche ici (Kind existant) ; ajouter un nouveau comportement = un Kind dans AbilityService.

	Kinds (+ Content/CoreKinds : SkyDrop, BubblePrison, CartRush, ElbowDrop, Counter) :
		Lunge      ruée vers l'avant qui percute (Pierce = traverse tout le monde ; Charges = utilisations enchaînables ; Trail = flaques)
		Projectile projectile(s) (Count, Spread en degrés, Gravity 0..1, Up = élan vertical)
		Melee      coup(s) devant soi (Hits, Interval ; Final = surcharge du dernier coup)
		AoE        onde autour de soi (Radius)
		Slam       saut puis écrasement au sol (JumpUp, Forward, Radius)
		Cone       cône devant soi (Range, Angle, Duration, Tick)
		Grab       saisie puis projection (HoldTime, ThrowKnockback, ThrowUp)
		Zone       flaque (Puddle) ou inondation (Flood)
		Barrier    anneau de barrières (Radius, Duration)
		Buff       vitesse + révélation des ennemis
		Guard      garde qui bloque tout de face et renvoie les projectiles (Duration)
	Effects : Blind = s, Slow = {mult, s}, Burn = {Ticks, Damage, Interval}, Mark = bonus de dégâts, Trip = true (fait tomber), Pin = true (plaque au sol avec onde de choc au lieu d'expulser)
	Communs : Name, Desc (texte du HUD), Prop (accessoire en main, AbilityFXController), Cooldown, Anim (ProcAnim), Sound (Config/Sounds), Words, Category, Power, Damage, Knockback, KnockUp, Stun
	Garde / rythme (docs/Equilibrage.md) : GuardBreak = true (brise la garde d'un coup ; au plus 1 par kit de base et 1 par kit
	transformé, le coup lourd le plus télégraphié), Armor = true (super armure), Endlag (s, défaut Heavy 0,45 / Light 0,25).
	Planchers de Windup : Heavy >= 0,25 s, Unblockable >= 0,35 s, ruées >= 0,15 s (sauf contres / pièges / buffs réactifs).
]]
local Attacks = {
	------------------------------------------------------------------ THE INTERN (ruée / projectile / gifle-marque / contre / rafale / chute du ciel)
	CoffeeRun = { Name = "Coffee Run", Kind = "Lunge", Desc = "Sprint forward cup-first and ram the first coworker you meet.", Prop = "BigCup", Cooldown = 6, Anim = "CoffeeRun", Sound = "Dash",
		Speed = 82, Time = 0.32, HitboxSize = Vector3.new(6, 6, 6),
		Windup = 0.25, Damage = 9, Knockback = 38, KnockUp = 10, Stun = 0.8, Category = "Heavy", Power = 0.8, Words = { "COFFEE RUN!", "WHAM!" } },
	PaperJam = { Name = "Paper Jam", Kind = "Projectile", Desc = "Shove a fan of 3 paper sheets. Stuns whoever they hit.", Prop = "PaperStack", Cooldown = 7, Anim = "PaperJam", Sound = "Throw",
		Speed = 95, Range = 70, Count = 3, Spread = 12, Size = Vector3.new(2, 0.25, 2.6), Color = Color3.fromRGB(255, 255, 255),
		Damage = 5, Knockback = 6, Stun = 1.1, Category = "Projectile", Power = 0.45, Words = { "PAPER JAM!", "FWIP!" } },
	StickySlap = { Name = "Sticky Slap", Kind = "Melee", Desc = "A huge backhand slap that sticks a note on their face: your next hit on them deals +9 damage.", Prop = "StickyPad", Cooldown = 5, Anim = "StickySlap", Sound = "Punch", Windup = 0.25,
		HitboxOffset = 3, HitboxSize = Vector3.new(6, 6, 6),
		Damage = 6, Knockback = 20, KnockUp = 6, Stun = 0.8, Category = "Heavy", Power = 0.6, Words = { "SLAP!", "STICKY!" }, Effects = { Mark = 9 } },
	EspressoCounter = { Name = "Espresso Shot", Kind = "Counter", Desc = "Chug an espresso and go jittery for 1s: if anyone hits you, you dodge, zip behind them and counter with a spinning backfist.", Prop = "EspressoCup", Cooldown = 8, Anim = "EspressoCounter", Sound = "Electric",
		Window = 1.0, CounterAnim = "EspressoStrike", Unblockable = true,
		Damage = 11, Knockback = 48, KnockUp = 16, Stun = 1.0, Category = "Heavy", Power = 1.0, Words = { "TOO SLOW!", "DECAF!" } },
	OvertimeFlurry = { Name = "Overtime Flurry", Kind = "Melee", Desc = "8 rapid punches, then a big launcher uppercut.", Cooldown = 7, Anim = "OvertimeFlurry", Sound = "Punch",
		Hits = 8, Interval = 0.07, HitboxOffset = 3, HitboxSize = Vector3.new(6, 6, 6.5),
		Damage = 2.5, Knockback = 3, Stun = 0.45, Category = "Light", Power = 0.3, Words = { "BAP!", "POW!", "BOP!" },
		Final = { Damage = 6, Knockback = 50, KnockUp = 16, Stun = 0.9, Category = "Heavy", Power = 1, Words = { "OVERTIME!" } } },
	DeadlineDrop = { Name = "Deadline", Kind = "SkyDrop", Desc = "Call the deadline: a giant DUE TODAY calendar crashes down on the coworker in front of you and PINS everyone under it.", Cooldown = 11, Anim = "DeadlineDrop", Sound = "Alarm",
		Model = "Calendar", Range = 34, Offset = 12, Radius = 9, Windup = 0.6,
		Damage = 15, Knockback = 0, KnockUp = 0, Stun = 1.2, Category = "Heavy", GuardBreak = true, Power = 1.2, Words = { "DEADLINE!", "DUE TODAY!" }, Effects = { Pin = true } },

	------------------------------------------------------------------ THE JANITOR (balayage / flaque / lobe / jet / glissade / bulle)
	MopSweep = { Name = "Mop Sweep", Kind = "Melee", Desc = "Low 360 mop sweep that knocks everyone around you off their feet.", Prop = "Mop", Cooldown = 5, Anim = "MopSweep", Sound = "Whoosh", Windup = 0.25,
		HitboxOffset = 2.5, HitboxSize = Vector3.new(13, 4, 9),
		Damage = 7, Knockback = 10, KnockUp = 12, Stun = 1.1, Category = "Heavy", Power = 0.6, Words = { "SWEEP!", "TRIP!" },
		Effects = { Trip = true } },
	WetFloorSign = { Name = "Wet Floor Sign", Kind = "Zone", Desc = "Slam down a WET FLOOR sign and a slippery puddle. Enemies slip, you don't.", Prop = "WetSign", Zone = "Puddle", Cooldown = 9, Anim = "SignSlam", Sound = "Water",
		Radius = 9, Duration = 12, Offset = 7 },
	BucketToss = { Name = "Bucket Toss", Kind = "Projectile", Desc = "Lob your bucket: it lands on their head and blinds them.", Prop = "Bucket", Cooldown = 8, Anim = "BucketToss", Sound = "Throw",
		Speed = 75, Range = 60, Gravity = 0.6, Up = 14, Size = Vector3.new(1.6, 1.6, 1.6), Shape = "Bucket", Color = Color3.fromRGB(150, 160, 175),
		Damage = 6, Knockback = 4, Stun = 0.9, Category = "Projectile", Power = 0.5, Words = { "BUCKET!", "CLONK!" }, Effects = { Blind = 2 } },
	PowerWash = { Name = "Power Wash", Kind = "Cone", Desc = "Blast a high-pressure stream that keeps pushing enemies back.", Prop = "PowerWasher", Cooldown = 9, Anim = "PowerWash", Sound = "Spray",
		Range = 20, Angle = 28, Duration = 1.6, Tick = 0.15, Color = Color3.fromRGB(110, 200, 255),
		Damage = 1.5, Knockback = 24, KnockUp = 3, Stun = 0.3, Category = "Light", Power = 0.25, Words = { "SPLASH!", "PSSSH!" } },
	SoapSlide = { Name = "Soap Slide", Kind = "Lunge", Desc = "Baseball-slide on soap, launching everyone you hit into the air.", Cooldown = 6, Pierce = true, Trail = true, Anim = "SoapSlide", Sound = "Slip",
		Speed = 82, Time = 0.45, HitboxSize = Vector3.new(7, 4, 7),
		Windup = 0.25, Damage = 8, Knockback = 10, Launch = Vector3.new(6, 48, 0), Stun = 1.1, Category = "Heavy", Power = 0.8, Words = { "SLIDE TACKLE!", "WHEE!" } },
	BubblePrison = { Name = "Bubble Prison", Kind = "BubblePrison", Desc = "Blow a giant soap bubble: it traps the first coworker in front of you, floats them up, then POPS and slams them into the floor.", Prop = "BubbleWand", Cooldown = 13, Anim = "BubbleBlow", Sound = "Boing",
		Windup = 0.28, Range = 36, Width = 6, Speed = 70, RiseTime = 1.0, RiseSpeed = 13,
		Damage = 14, Knockback = 0, KnockUp = 0, Stun = 1.2, Category = "Heavy", GuardBreak = true, Power = 1.1, Words = { "POP!", "BUBBLE TROUBLE!" }, Effects = { Pin = true } },

	------------------------------------------------------------------ THE LUNCH LADY (garde / louche qui plaque / lobe / onde / cône / chariot)
	TrayGuard = { Name = "Tray Guard", Kind = "Guard", Desc = "Raise a tray shield: blocks everything in front and reflects projectiles.", Prop = "TrayShield", Cooldown = 7, Anim = "TrayGuard", Sound = "Clang", Duration = 1.6, Words = { "TRAY GUARD!" } },
	LadleBonk = { Name = "Ladle Bonk", Kind = "Melee", Desc = "Jumping overhead ladle chop that PINS them to the floor.", Prop = "Ladle", Cooldown = 7, Anim = "LadleBonk", Sound = "Clang", Windup = 0.25, Kitchen = true,
		HitboxOffset = 3.5, HitboxSize = Vector3.new(6, 7, 7), Material = "Metal",
		Damage = 12, Knockback = 0, KnockUp = 0, Stun = 1.3, Category = "Heavy", Power = 0.9, Words = { "LADLE BONK!", "DONG!" }, Effects = { Pin = true } },
	MysteryMeat = { Name = "Mystery Meat", Kind = "Projectile", Desc = "Lob a blob of mystery meat that slows on impact.", Prop = "Meat", Cooldown = 6, Anim = "MeatLob", Sound = "Throw",
		Speed = 78, Range = 60, Gravity = 0.5, Up = 10, Size = Vector3.new(1.5, 1.5, 1.5), Shape = "Ball", Color = Color3.fromRGB(140, 90, 60),
		Damage = 7, Knockback = 6, Stun = 0.5, Category = "Splat", Power = 0.5, Words = { "SPLAT!", "EWW!" }, Effects = { Slow = { 0.55, 2.5 } } },
	FryingPanSmash = { Name = "Frying Pan Smash", Kind = "AoE", Desc = "Smash a giant frying pan into the floor: shockwave all around you.", Prop = "GiantPan", Cooldown = 8, Anim = "PanSmash", Sound = "GroundSlam", Windup = 0.4,
		Radius = 13, Shockwave = true, Kitchen = true,
		Damage = 14, Knockback = 42, KnockUp = 26, Stun = 1.0, Category = "Heavy", GuardBreak = true, Power = 1.1, Words = { "PAN SMASH!", "KABOOM!" } },
	HotSoup = { Name = "Hot Soup", Kind = "Cone", Desc = "Splash scalding soup in a cone. Burns over time.", Prop = "SoupPot", Cooldown = 8, Anim = "SoupToss", Sound = "Splat", Kitchen = true,
		Range = 15, Angle = 40, Duration = 0.3, Tick = 0.3, Color = Color3.fromRGB(255, 150, 40),
		Damage = 8, Knockback = 14, KnockUp = 4, Stun = 0.6, Category = "Splat", Power = 0.6, Words = { "HOT SOUP!", "SIZZLE!" },
		Effects = { Burn = { Ticks = 4, Damage = 2, Interval = 0.5 } } },
	FoodCartRush = { Name = "Food Cart Rush", Kind = "CartRush", Desc = "Shove a loaded food cart forward: it scoops up everyone in its path, then crashes and PINS them to the floor.", Cooldown = 11, Anim = "CartPush", Sound = "Dash", Kitchen = true,
		Windup = 0.25, Speed = 60, Time = 0.85, HitboxSize = Vector3.new(7, 6, 5),
		Damage = 13, Knockback = 0, KnockUp = 0, Stun = 1.2, Category = "Heavy", Power = 1.1, Words = { "ORDER UP!", "CLEAN UP!" }, Effects = { Pin = true } },

	------------------------------------------------------------------ THE SECURITY GUARD (saisie / lampe / renfort / sifflet / coude du ciel / barrière)
	Detain = { Name = "Detain", Kind = "Grab", Desc = "Grab the closest enemy (goes through block) and slam them away.", Prop = "Handcuffs", Cooldown = 8, Anim = "Detain", Sound = "Whoosh", Unblockable = true,
		HitboxOffset = 3.5, HitboxSize = Vector3.new(5, 6, 6), HoldTime = 0.55,
		Windup = 0.35, Damage = 10, ThrowKnockback = 58, ThrowUp = 26, Stun = 1.0, Category = "Heavy", Power = 0.9, Words = { "DETAINED!", "SLAM!" } },
	Flashlight = { Name = "Flashlight", Kind = "Cone", Desc = "Shine a blinding flashlight in a long cone.", Prop = "FlashlightProp", Cooldown = 9, Anim = "Flashlight", Sound = "Electric",
		Range = 28, Angle = 25, Duration = 0.2, Tick = 0.2, Color = Color3.fromRGB(255, 250, 190),
		Damage = 2, Knockback = 2, Stun = 0.4, Category = "Light", Power = 0.3, Words = { "FLASH!" }, Effects = { Blind = 2.2 } },
	WalkieTalkie = { Name = "Walkie-Talkie", Kind = "Buff", Desc = "Call backup: speed boost and reveals every enemy nearby.", Prop = "Walkie", Cooldown = 14, Anim = "Walkie", Sound = "Electric",
		SpeedMultiplier = 1.35, Duration = 5, RevealRadius = 90, Words = { "COPY THAT!" } },
	WhistleBlast = { Name = "Whistle Blast", Kind = "AoE", Desc = "Blow the whistle: a ring of sound that stuns everyone around you.", Prop = "WhistleProp", Cooldown = 8, Anim = "Whistle", Sound = "Whistle", Windup = 0.3,
		Radius = 15, Shockwave = true,
		Damage = 6, Knockback = 26, KnockUp = 10, Stun = 1.4, Category = "Heavy", GuardBreak = true, Power = 0.7, Words = { "TWEEEET!" } },
	ElbowDrop = { Name = "Elbow Drop", Kind = "ElbowDrop", Desc = "Leap onto the closest coworker in front of you and crash down elbow-first: PINS them, with a shockwave around.", Cooldown = 10, Anim = "ElbowDrop", Sound = "Whoosh",
		Windup = 0.25, Range = 40, Offset = 18, AirTime = 0.55, Height = 13, Radius = 7.5, SplashRadius = 11, SplashDamage = 6,
		Damage = 16, Knockback = 0, KnockUp = 0, Stun = 1.2, Category = "Heavy", Power = 1.2, Words = { "ELBOW DROP!", "OHHH YEAH!" }, Effects = { Pin = true } },
	TotalLockdown = { Name = "Total Lockdown", Kind = "Barrier", Desc = "Trap everyone around you inside a ring of barriers for 5 seconds.", Prop = "Baton", Cooldown = 16, Anim = "Lockdown", Sound = "Siren",
		Radius = 16, Duration = 5, Height = 40, Words = { "LOCKDOWN!" } },
}

-- attaques ajoutées par les modules de Content
require(script.Parent.Parent.Modules.ContentLoader).merge(Attacks, "Attacks")

return Attacks
