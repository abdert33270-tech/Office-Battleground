--[[
	Items — une fiche par objet ramassable.
	Ajouter un objet = une fiche ici + un Model du même nom dans ServerStorage.Items
	(PrimaryPart "Handle" invisible = point de prise en main) + des ItemSpawns (attribut ItemId) dans les étages.

	Family   : "Melee" | "Throwable" | "Heavy" | "Zone" | "Food"
	Hold     : "Hand" (main droite) | "TwoHands" (au-dessus de la tête, ralentit)
	Grip     : HANG = l'objet pend sous la main (chaise, extincteur…) ; STICK = l'objet prolonge le bras (clavier, balai…)
	           UP = objet debout tenu par sa base (trophée, lampe, canard…)
	Material : clé de son d'impact / de casse (Wood, Metal, Plastic, Ceramic, Glass, Rubber, Food)
	Kitchen  : objet de cuisine (passif de la Lunch Lady : +25 % de dégâts)
	Use      : clic gauche (remplace le M1). Special = "Spray" | "Splash" | "Eat" | "Squeak" (cri en cône, sans Damage)
	           | "Sticky" (flaque de peinture qui ralentit devant soi)
	Throw    : touche R. TOUS les objets lancés se cassent à l'impact, étourdissent et soulèvent un peu
	           la victime (on peut enchaîner un combo). Special = "Smoke" | "Puddle" | "Dirt" | "Blind" | "Roll"
	           | "Bounce" (rebondit vers la cible suivante, Bounces) | "Burst" (gerbe : dégâts autour, Radius)
	           | "Sticky" (peinture qui ralentit, Radius) | "Flash" (aveugle tout le monde autour, Radius/BlindTime)
	           Options : Spin = true (lancer à plat qui tourne), ImpactWords = mots de l'explosion (Smoke/Dirt/Burst)
	Durability : chaque coup qui touche coûte 1
]]
local HANG = CFrame.Angles(math.pi / 2, 0, 0)
local STICK = CFrame.new()
local UP = CFrame.Angles(-math.pi / 2, 0, 0)

return {
	Chair = {
		DisplayName = "Chair", Family = "Melee", Hold = "Hand", Grip = HANG, Material = "Wood",
		Durability = 8, RespawnTime = 8,
		Use = { Damage = 11, Cooldown = 0.6, Windup = 0.16, HitboxSize = Vector3.new(7, 6, 7), HitboxOffset = 4,
			Knockback = 34, KnockUp = 16, Stun = 0.8, Power = 0.8, Category = "Heavy", Anim = "OverheadSwing",
			Lunge = 16, Words = { "BONK!", "WHAM!", "CRASH!" } },
		Throw = { Damage = 13, Speed = 80, Up = 16, Knockback = 14, Stun = 0.9, Category = "Heavy" },
	},
	Keyboard = {
		DisplayName = "Keyboard", Family = "Melee", Hold = "Hand", Grip = STICK, Material = "Plastic",
		Durability = 10, RespawnTime = 6,
		Use = { Damage = 7, Cooldown = 0.36, Windup = 0.08, HitboxSize = Vector3.new(6, 5, 6.5), HitboxOffset = 3.6,
			Knockback = 10, KnockUp = 3, Stun = 0.6, Power = 0.5, Category = "Light", Anim = "SideSwing",
			Lunge = 12, Words = { "SMACK!", "WHAP!", "CLACK!" } },
		Throw = { Damage = 9, Speed = 100, Up = 8, Knockback = 10, Stun = 0.8, Category = "Projectile" },
	},
	Stapler = {
		DisplayName = "Stapler", Family = "Throwable", Hold = "Hand", Grip = STICK, Material = "Metal",
		Durability = 6, RespawnTime = 5,
		Use = { Damage = 5, Cooldown = 0.3, Windup = 0.06, HitboxSize = Vector3.new(5, 5, 5.5), HitboxOffset = 3,
			Knockback = 6, KnockUp = 0, Stun = 0.55, Power = 0.4, Category = "Light", Anim = "Jab", Lunge = 10,
			Words = { "CHUNK!", "POW!" } },
		Throw = { Damage = 11, Speed = 135, Up = 5, Knockback = 10, Stun = 0.9, Category = "Projectile" },
	},
	CoffeeMug = {
		DisplayName = "Coffee Mug", Family = "Throwable", Hold = "Hand", Grip = CFrame.new(0, 0, -0.2) * HANG, Material = "Ceramic",
		Durability = 3, RespawnTime = 6,
		Use = { Damage = 5, Cooldown = 0.33, Windup = 0.06, HitboxSize = Vector3.new(5, 5, 5.5), HitboxOffset = 3,
			Knockback = 6, KnockUp = 0, Stun = 0.55, Power = 0.4, Category = "Light", Anim = "Jab", Lunge = 10 },
		Throw = { Damage = 8, Speed = 115, Up = 9, Knockback = 8, Stun = 0.9, Category = "Splat",
			Burn = { Ticks = 3, Damage = 2, Interval = 0.6 } },
	},
	Photocopier = {
		DisplayName = "Photocopier", Family = "Heavy", Hold = "TwoHands", Material = "Metal",
		Durability = 4, RespawnTime = 12, SpeedMultiplier = 0.62,
		HoldOffset = CFrame.new(0, 3.8, -0.4),
		SlamPath = {
			{ t = 0.26, cf = CFrame.new(0, 4.3, 0.8) * CFrame.Angles(math.rad(25), 0, 0) },
			{ t = 0.12, cf = CFrame.new(0, 0.2, -3.6) * CFrame.Angles(math.rad(-70), 0, 0) },
			{ t = 0.3, cf = CFrame.new(0, 3.8, -0.4) },
		},
		Use = { Damage = 20, Cooldown = 1.2, Windup = 0.36, HitboxSize = Vector3.new(10, 8, 10), HitboxOffset = 4.5,
			Knockback = 85, KnockUp = 36, Stun = 1.2, Power = 1.1, Category = "Heavy", Anim = "Slam",
			Lunge = 8, Shockwave = 9, Words = { "KABOOM!", "CRASH!", "BONK!" } },
		Throw = { Damage = 24, Speed = 58, Up = 26, Knockback = 60, Stun = 1.2, Category = "Heavy" },
	},
	Monitor = {
		DisplayName = "Monitor", Family = "Melee", Hold = "Hand", Grip = HANG, Material = "Glass",
		Durability = 5, RespawnTime = 8,
		Use = { Damage = 10, Cooldown = 0.55, Windup = 0.14, HitboxSize = Vector3.new(7, 6, 7), HitboxOffset = 4,
			Knockback = 26, KnockUp = 10, Stun = 0.8, Power = 0.75, Category = "Heavy", Anim = "OverheadSwing",
			Lunge = 14, Words = { "BLUE SCREEN!", "CRASH!", "SMASH!" } },
		Throw = { Damage = 12, Speed = 85, Up = 12, Knockback = 14, Stun = 0.9, Category = "Heavy" },
	},
	Broom = {
		DisplayName = "Broom", Family = "Melee", Hold = "Hand", Grip = STICK, Material = "Wood",
		Durability = 10, RespawnTime = 7,
		Use = { Damage = 7, Cooldown = 0.42, Windup = 0.1, HitboxSize = Vector3.new(7, 5, 9), HitboxOffset = 5,
			Knockback = 16, KnockUp = 6, Stun = 0.65, Power = 0.55, Category = "Light", Anim = "SideSwing",
			Lunge = 10, Words = { "SWEEP!", "WHACK!", "THWAP!" } },
		Throw = { Damage = 10, Speed = 90, Up = 8, Knockback = 12, Stun = 0.9, Category = "Projectile" },
	},
	FireExtinguisher = {
		DisplayName = "Fire Extinguisher", Family = "Zone", Hold = "Hand", Grip = HANG, Material = "Metal",
		Durability = 5, RespawnTime = 10,
		Use = { Special = "Spray", Damage = 3, Cooldown = 0.7, Windup = 0.05, HitboxSize = Vector3.new(7, 6, 12), HitboxOffset = 7,
			Knockback = 30, KnockUp = 4, Stun = 0.5, Power = 0.4, Category = "Light", Anim = "Jab",
			Words = { "PSSHHH!", "FWOOSH!" } },
		Throw = { Special = "Smoke", Damage = 10, Speed = 75, Up = 14, Knockback = 20, Stun = 1.1, Category = "Heavy", Radius = 9 },
	},
	WaterBucket = {
		DisplayName = "Water Bucket", Family = "Zone", Hold = "Hand", Grip = HANG, Material = "Plastic",
		Durability = 3, RespawnTime = 9,
		Use = { Special = "Splash", Damage = 4, Cooldown = 0.8, Windup = 0.12, HitboxSize = Vector3.new(7, 5, 8), HitboxOffset = 4.5,
			Knockback = 14, KnockUp = 4, Stun = 0.7, Power = 0.45, Category = "Splat", Anim = "SideSwing",
			Words = { "SPLASH!", "SPLOOSH!" } },
		Throw = { Special = "Puddle", Damage = 8, Speed = 80, Up = 14, Knockback = 10, Stun = 1.0, Category = "Splat", Radius = 9 },
	},
	PottedPlant = {
		DisplayName = "Potted Plant", Family = "Zone", Hold = "Hand", Grip = HANG, Material = "Ceramic",
		Durability = 2, RespawnTime = 8,
		Use = { Damage = 8, Cooldown = 0.5, Windup = 0.12, HitboxSize = Vector3.new(6, 6, 6.5), HitboxOffset = 3.6,
			Knockback = 12, KnockUp = 6, Stun = 1.0, Power = 0.6, Category = "Heavy", Anim = "OverheadSwing",
			Lunge = 12, Words = { "BONK!", "THUNK!" } },
		Throw = { Special = "Dirt", Damage = 8, Speed = 85, Up = 14, Knockback = 10, Stun = 1.4, Category = "Heavy", Radius = 8 },
	},
	Tray = {
		DisplayName = "Tray", Family = "Melee", Hold = "Hand", Grip = STICK, Material = "Metal", Kitchen = true,
		Durability = 10, RespawnTime = 6,
		Use = { Damage = 7, Cooldown = 0.36, Windup = 0.08, HitboxSize = Vector3.new(6, 5, 6.5), HitboxOffset = 3.6,
			Knockback = 10, KnockUp = 3, Stun = 0.6, Power = 0.5, Category = "Light", Anim = "SideSwing",
			Lunge = 12, Words = { "CLANG!", "WHAP!", "TONK!" } },
		Throw = { Damage = 10, Speed = 105, Up = 6, Knockback = 10, Stun = 0.9, Category = "Projectile" },
	},
	Pan = {
		DisplayName = "Frying Pan", Family = "Melee", Hold = "Hand", Grip = STICK, Material = "Metal", Kitchen = true,
		Durability = 8, RespawnTime = 8,
		Use = { Damage = 11, Cooldown = 0.55, Windup = 0.14, HitboxSize = Vector3.new(6.5, 6, 7), HitboxOffset = 4,
			Knockback = 30, KnockUp = 12, Stun = 0.9, Power = 0.85, Category = "Heavy", Anim = "OverheadSwing",
			Lunge = 14, Words = { "CLANG!", "BONK!", "DONG!" } },
		Throw = { Damage = 12, Speed = 90, Up = 10, Knockback = 14, Stun = 1.0, Category = "Heavy" },
	},
	Burger = {
		DisplayName = "Burger", Family = "Food", Hold = "Hand", Grip = STICK, Material = "Food", Kitchen = true,
		Durability = 1, RespawnTime = 10,
		Use = { Special = "Eat", Heal = 20, KitchenHeal = 35, Cooldown = 0.5, Windup = 0.3, Anim = "Eat" },
		Throw = { Damage = 6, Speed = 100, Up = 10, Knockback = 8, Stun = 0.8, Category = "Splat" },
	},
	Cable = {
		DisplayName = "Cable", Family = "Melee", Hold = "Hand", Grip = STICK, Material = "Plastic",
		Durability = 10, RespawnTime = 7,
		Use = { Damage = 8, Cooldown = 0.45, Windup = 0.1, HitboxSize = Vector3.new(7, 5, 10), HitboxOffset = 6,
			Knockback = 12, KnockUp = 4, Stun = 0.75, Power = 0.6, Category = "Light", Anim = "SideSwing",
			Lunge = 8, Words = { "ZAP!", "WHIP!", "BZZT!" } },
		Throw = { Damage = 9, Speed = 95, Up = 8, Knockback = 10, Stun = 0.9, Category = "Projectile" },
	},
	ServerRack = {
		DisplayName = "Server Rack", Family = "Heavy", Hold = "TwoHands", Material = "Metal",
		Durability = 4, RespawnTime = 12, SpeedMultiplier = 0.6,
		HoldOffset = CFrame.new(0, 4.4, -0.3),
		SlamPath = {
			{ t = 0.26, cf = CFrame.new(0, 4.9, 0.8) * CFrame.Angles(math.rad(25), 0, 0) },
			{ t = 0.12, cf = CFrame.new(0, 0.6, -3.8) * CFrame.Angles(math.rad(-75), 0, 0) },
			{ t = 0.3, cf = CFrame.new(0, 4.4, -0.3) },
		},
		Use = { Damage = 22, Cooldown = 1.25, Windup = 0.36, HitboxSize = Vector3.new(10, 8, 10), HitboxOffset = 4.5,
			Knockback = 90, KnockUp = 36, Stun = 1.2, Power = 1.15, Category = "Heavy", Anim = "Slam",
			Lunge = 8, Shockwave = 9, Words = { "SYSTEM CRASH!", "KABOOM!", "CRASH!" } },
		Throw = { Damage = 24, Speed = 55, Up = 26, Knockback = 60, Stun = 1.2, Category = "Heavy" },
	},
	TrafficCone = {
		DisplayName = "Traffic Cone", Family = "Throwable", Hold = "Hand", Grip = HANG, Material = "Plastic",
		Durability = 4, RespawnTime = 7,
		Use = { Damage = 6, Cooldown = 0.38, Windup = 0.08, HitboxSize = Vector3.new(6, 5, 6), HitboxOffset = 3.4,
			Knockback = 8, KnockUp = 2, Stun = 0.6, Power = 0.45, Category = "Light", Anim = "SideSwing", Lunge = 10,
			Words = { "BOINK!", "WHAP!" } },
		Throw = { Special = "Blind", Damage = 7, Speed = 95, Up = 10, Knockback = 6, Stun = 1.0, Category = "Projectile", BlindTime = 1.6 },
	},
	Tire = {
		DisplayName = "Tire", Family = "Throwable", Hold = "Hand", Grip = STICK, Material = "Rubber",
		Durability = 3, RespawnTime = 9,
		Use = { Damage = 8, Cooldown = 0.5, Windup = 0.12, HitboxSize = Vector3.new(6, 6, 6), HitboxOffset = 3.5,
			Knockback = 22, KnockUp = 10, Stun = 0.7, Power = 0.6, Category = "Heavy", Anim = "OverheadSwing", Lunge = 10,
			Words = { "BOING!", "BONK!" } },
		Throw = { Special = "Roll", Damage = 12, Speed = 75, Up = 4, Knockback = 45, Stun = 1.0, Category = "Heavy" },
	},

	------------------------------------------------------------------
	-- Lot 2 : objets thématiques par étage (bureau, hall, toit, archives, salle de jeux,
	-- crèche, auditorium, entrepôt, spa, salle de sport)
	------------------------------------------------------------------
	-- Bureau (général)
	WaterJug = {
		DisplayName = "Water Cooler Jug", Family = "Zone", Hold = "Hand", Grip = HANG, Material = "Plastic",
		Durability = 3, RespawnTime = 9, SpeedMultiplier = 0.92,
		Use = { Special = "Splash", Damage = 4, Cooldown = 0.85, Windup = 0.14, HitboxSize = Vector3.new(7, 5, 8), HitboxOffset = 4.5,
			Knockback = 16, KnockUp = 4, Stun = 0.7, Power = 0.45, Category = "Splat", Anim = "SideSwing",
			Words = { "GLUG!", "SPLOOSH!" } },
		Throw = { Special = "Puddle", Damage = 8, Speed = 70, Up = 18, Knockback = 10, Stun = 1.0, Category = "Splat", Radius = 11 },
	},
	Laptop = {
		DisplayName = "Laptop", Family = "Melee", Hold = "Hand", Grip = STICK, Material = "Plastic",
		Durability = 7, RespawnTime = 7,
		Use = { Damage = 8, Cooldown = 0.42, Windup = 0.1, HitboxSize = Vector3.new(6, 5, 7), HitboxOffset = 3.8,
			Knockback = 14, KnockUp = 5, Stun = 0.65, Power = 0.55, Category = "Light", Anim = "SideSwing",
			Lunge = 12, Words = { "CTRL+ALT+DEL!", "BLUE SCREEN!", "404!" } },
		Throw = { Damage = 11, Speed = 120, Up = 4, Knockback = 12, Stun = 0.9, Category = "Projectile", Spin = true },
	},
	DeskLamp = {
		DisplayName = "Desk Lamp", Family = "Melee", Hold = "Hand", Grip = UP, Material = "Glass",
		Durability = 5, RespawnTime = 8,
		Use = { Damage = 9, Cooldown = 0.48, Windup = 0.12, HitboxSize = Vector3.new(6.5, 6, 7), HitboxOffset = 4,
			Knockback = 20, KnockUp = 8, Stun = 0.75, Power = 0.65, Category = "Heavy", Anim = "OverheadSwing",
			Lunge = 12, Words = { "LIGHTS OUT!", "CLICK!", "BONK!" } },
		Throw = { Special = "Flash", Damage = 8, Speed = 95, Up = 10, Knockback = 10, Stun = 0.9, Category = "Projectile",
			Radius = 7, BlindTime = 1.0 },
	},
	Trophy = {
		DisplayName = "Trophy", Family = "Throwable", Hold = "Hand", Grip = UP, Material = "Metal",
		Durability = 5, RespawnTime = 8,
		Use = { Damage = 7, Cooldown = 0.38, Windup = 0.08, HitboxSize = Vector3.new(5.5, 5, 6), HitboxOffset = 3.2,
			Knockback = 10, KnockUp = 4, Stun = 0.6, Power = 0.5, Category = "Light", Anim = "Jab", Lunge = 10,
			Words = { "WINNER!", "#1!", "DING!" } },
		Throw = { Damage = 12, Speed = 115, Up = 7, Knockback = 12, Stun = 0.95, Category = "Projectile" },
	},
	Whiteboard = {
		DisplayName = "Whiteboard", Family = "Heavy", Hold = "TwoHands", Material = "Plastic",
		Durability = 4, RespawnTime = 12, SpeedMultiplier = 0.7,
		HoldOffset = CFrame.new(0, 4.6, -0.4),
		SlamPath = {
			{ t = 0.24, cf = CFrame.new(0, 5.1, 0.8) * CFrame.Angles(math.rad(25), 0, 0) },
			{ t = 0.12, cf = CFrame.new(0, 1.0, -3.8) * CFrame.Angles(math.rad(-75), 0, 0) },
			{ t = 0.3, cf = CFrame.new(0, 4.6, -0.4) },
		},
		Use = { Damage = 17, Cooldown = 1.0, Windup = 0.32, HitboxSize = Vector3.new(12, 8, 9), HitboxOffset = 4.5,
			Knockback = 70, KnockUp = 30, Stun = 1.1, Power = 1.0, Category = "Heavy", Anim = "Slam",
			Lunge = 8, Shockwave = 7, Words = { "ERASED!", "MEETING OVER!", "WHAM!" } },
		Throw = { Damage = 19, Speed = 62, Up = 24, Knockback = 48, Stun = 1.1, Category = "Heavy" },
	},
	-- Hall d'entrée
	VelvetRope = {
		DisplayName = "Velvet Rope Post", Family = "Melee", Hold = "Hand", Grip = HANG, Material = "Metal",
		Durability = 8, RespawnTime = 8,
		Use = { Damage = 10, Cooldown = 0.55, Windup = 0.14, HitboxSize = Vector3.new(6.5, 6, 8), HitboxOffset = 4.5,
			Knockback = 28, KnockUp = 10, Stun = 0.8, Power = 0.75, Category = "Heavy", Anim = "OverheadSwing",
			Lunge = 12, Words = { "VIP ONLY!", "BACK OF THE LINE!", "CLONK!" } },
		Throw = { Damage = 11, Speed = 80, Up = 14, Knockback = 14, Stun = 0.9, Category = "Heavy" },
	},
	Umbrella = {
		DisplayName = "Umbrella", Family = "Melee", Hold = "Hand", Grip = STICK, Material = "Plastic",
		Durability = 9, RespawnTime = 7,
		Use = { Damage = 6, Cooldown = 0.32, Windup = 0.07, HitboxSize = Vector3.new(5, 5, 9), HitboxOffset = 5,
			Knockback = 12, KnockUp = 2, Stun = 0.55, Power = 0.45, Category = "Light", Anim = "Jab",
			Lunge = 14, Words = { "POKE!", "EN GARDE!", "FWUMP!" } },
		Throw = { Damage = 8, Speed = 115, Up = 6, Knockback = 8, Stun = 0.85, Category = "Projectile" },
	},
	Suitcase = {
		DisplayName = "Suitcase", Family = "Melee", Hold = "Hand", Grip = HANG, Material = "Wood",
		Durability = 7, RespawnTime = 9, SpeedMultiplier = 0.92,
		Use = { Damage = 12, Cooldown = 0.68, Windup = 0.18, HitboxSize = Vector3.new(7, 6, 7), HitboxOffset = 4,
			Knockback = 38, KnockUp = 14, Stun = 0.85, Power = 0.85, Category = "Heavy", Anim = "OverheadSwing",
			Lunge = 14, Words = { "EXCESS BAGGAGE!", "THWUMP!", "BONK!" } },
		Throw = { Damage = 12, Speed = 72, Up = 16, Knockback = 18, Stun = 0.95, Category = "Heavy" },
	},
	-- Toit
	SatelliteDish = {
		DisplayName = "Satellite Dish", Family = "Heavy", Hold = "TwoHands", Material = "Metal",
		Durability = 4, RespawnTime = 12, SpeedMultiplier = 0.72,
		HoldOffset = CFrame.new(0, 4.1, -0.4),
		SlamPath = {
			{ t = 0.24, cf = CFrame.new(0, 4.6, 0.8) * CFrame.Angles(math.rad(25), 0, 0) },
			{ t = 0.12, cf = CFrame.new(0, 0.4, -3.6) * CFrame.Angles(math.rad(-70), 0, 0) },
			{ t = 0.3, cf = CFrame.new(0, 4.1, -0.4) },
		},
		Use = { Damage = 16, Cooldown = 1.0, Windup = 0.3, HitboxSize = Vector3.new(11, 8, 10), HitboxOffset = 4.5,
			Knockback = 75, KnockUp = 34, Stun = 1.1, Power = 1.0, Category = "Heavy", Anim = "Slam",
			Lunge = 8, Shockwave = 8, Words = { "NO SIGNAL!", "STATIC!", "KRZZT!" } },
		Throw = { Damage = 18, Speed = 70, Up = 22, Knockback = 50, Stun = 1.1, Category = "Heavy", Spin = true },
	},
	PigeonStatue = {
		DisplayName = "Pigeon Statue", Family = "Zone", Hold = "Hand", Grip = UP, Material = "Ceramic",
		Durability = 3, RespawnTime = 8,
		Use = { Damage = 8, Cooldown = 0.5, Windup = 0.12, HitboxSize = Vector3.new(6, 6, 6.5), HitboxOffset = 3.6,
			Knockback = 12, KnockUp = 6, Stun = 0.9, Power = 0.6, Category = "Heavy", Anim = "OverheadSwing",
			Lunge = 12, Words = { "COO!", "BONK!" } },
		Throw = { Special = "Dirt", Damage = 8, Speed = 88, Up = 14, Knockback = 10, Stun = 1.3, Category = "Heavy", Radius = 8,
			ImpactWords = { "COO COO!", "STONED!" } },
	},
	FanBlade = {
		DisplayName = "Fan Blade", Family = "Melee", Hold = "Hand", Grip = HANG, Material = "Metal",
		Durability = 7, RespawnTime = 8,
		Use = { Damage = 7, Cooldown = 0.4, Windup = 0.09, HitboxSize = Vector3.new(9, 5, 7), HitboxOffset = 3.6,
			Knockback = 16, KnockUp = 4, Stun = 0.65, Power = 0.55, Category = "Light", Anim = "SideSwing",
			Lunge = 10, Words = { "WHIRR!", "CHOP!", "FWOOM!" } },
		Throw = { Damage = 10, Speed = 125, Up = 3, Knockback = 12, Stun = 0.85, Category = "Projectile", Spin = true },
	},
	-- Archives
	FilingDrawer = {
		DisplayName = "Filing Drawer", Family = "Heavy", Hold = "TwoHands", Material = "Metal",
		Durability = 4, RespawnTime = 12, SpeedMultiplier = 0.66,
		HoldOffset = CFrame.new(0, 3.4, -0.4),
		SlamPath = {
			{ t = 0.26, cf = CFrame.new(0, 3.9, 0.8) * CFrame.Angles(math.rad(25), 0, 0) },
			{ t = 0.12, cf = CFrame.new(0, 0.1, -3.6) * CFrame.Angles(math.rad(-70), 0, 0) },
			{ t = 0.3, cf = CFrame.new(0, 3.4, -0.4) },
		},
		Use = { Damage = 19, Cooldown = 1.15, Windup = 0.34, HitboxSize = Vector3.new(10, 8, 10), HitboxOffset = 4.5,
			Knockback = 82, KnockUp = 34, Stun = 1.2, Power = 1.1, Category = "Heavy", Anim = "Slam",
			Lunge = 8, Shockwave = 9, Words = { "FILED!", "ARCHIVED!", "CRASH!" } },
		Throw = { Special = "Burst", Damage = 20, Speed = 58, Up = 26, Knockback = 50, Stun = 1.1, Category = "Heavy", Radius = 10,
			ImpactWords = { "PAPERWORK!", "PAPERCUT!" } },
	},
	BookStack = {
		DisplayName = "Book Stack", Family = "Throwable", Hold = "Hand", Grip = HANG, Material = "Wood",
		Durability = 4, RespawnTime = 8,
		Use = { Damage = 8, Cooldown = 0.48, Windup = 0.12, HitboxSize = Vector3.new(6, 6, 6.5), HitboxOffset = 3.6,
			Knockback = 18, KnockUp = 8, Stun = 0.75, Power = 0.6, Category = "Heavy", Anim = "OverheadSwing",
			Lunge = 12, Words = { "STUDY!", "THWACK!", "SHHH!" } },
		Throw = { Special = "Burst", Damage = 8, Speed = 90, Up = 12, Knockback = 10, Stun = 0.9, Category = "Heavy", Radius = 9,
			ImpactWords = { "PAPERCUT!", "FLAP!" } },
	},
	Blueprint = {
		DisplayName = "Rolled Blueprint", Family = "Melee", Hold = "Hand", Grip = STICK, Material = "Plastic",
		Durability = 8, RespawnTime = 6,
		Use = { Damage = 5, Cooldown = 0.27, Windup = 0.06, HitboxSize = Vector3.new(5.5, 5, 7), HitboxOffset = 4,
			Knockback = 8, KnockUp = 2, Stun = 0.5, Power = 0.4, Category = "Light", Anim = "SideSwing",
			Lunge = 12, Words = { "THWAP!", "REVISED!", "SWAT!" } },
		Throw = { Damage = 7, Speed = 130, Up = 5, Knockback = 8, Stun = 0.8, Category = "Projectile" },
	},
	-- Salle de jeux
	PingPongPaddle = {
		DisplayName = "Ping Pong Paddle", Family = "Melee", Hold = "Hand", Grip = STICK, Material = "Wood",
		Durability = 9, RespawnTime = 6,
		Use = { Damage = 6, Cooldown = 0.3, Windup = 0.07, HitboxSize = Vector3.new(6, 5, 6), HitboxOffset = 3.4,
			Knockback = 20, KnockUp = 6, Stun = 0.55, Power = 0.5, Category = "Light", Anim = "SideSwing",
			Lunge = 12, Words = { "PING!", "PONG!", "SMASH!" } },
		Throw = { Damage = 8, Speed = 140, Up = 4, Knockback = 10, Stun = 0.85, Category = "Projectile", Spin = true },
	},
	BowlingBall = {
		DisplayName = "Bowling Ball", Family = "Throwable", Hold = "Hand", Grip = HANG, Material = "Wood",
		Durability = 4, RespawnTime = 10, SpeedMultiplier = 0.9,
		Use = { Damage = 10, Cooldown = 0.6, Windup = 0.15, HitboxSize = Vector3.new(5.5, 5, 6), HitboxOffset = 3.2,
			Knockback = 30, KnockUp = 10, Stun = 0.85, Power = 0.8, Category = "Heavy", Anim = "Jab",
			Lunge = 10, Words = { "STRIKE!", "GUTTER!", "BONK!" } },
		Throw = { Special = "Roll", Damage = 13, Speed = 70, Up = 2, Knockback = 50, Stun = 1.0, Category = "Heavy" },
	},
	BeanBag = {
		DisplayName = "Bean Bag", Family = "Zone", Hold = "Hand", Grip = HANG, Material = "Rubber",
		Durability = 4, RespawnTime = 8, SpeedMultiplier = 0.95,
		Use = { Damage = 5, Cooldown = 0.45, Windup = 0.1, HitboxSize = Vector3.new(7, 6, 7), HitboxOffset = 3.8,
			Knockback = 40, KnockUp = 14, Stun = 0.5, Power = 0.5, Category = "Light", Anim = "OverheadSwing",
			Lunge = 10, Words = { "FLOMP!", "FWUMP!" } },
		Throw = { Special = "Dirt", Damage = 7, Speed = 80, Up = 16, Knockback = 20, Stun = 1.2, Category = "Heavy", Radius = 9,
			ImpactWords = { "BEANS!", "FLOMP!" } },
	},
	-- Crèche
	TeddyBear = {
		DisplayName = "Giant Teddy", Family = "Heavy", Hold = "TwoHands", Material = "Rubber",
		Durability = 5, RespawnTime = 12, SpeedMultiplier = 0.85,
		HoldOffset = CFrame.new(0, 4.5, -0.4),
		SlamPath = {
			{ t = 0.2, cf = CFrame.new(0, 5.0, 0.8) * CFrame.Angles(math.rad(25), 0, 0) },
			{ t = 0.12, cf = CFrame.new(0, 1.2, -3.6) * CFrame.Angles(math.rad(-60), 0, 0) },
			{ t = 0.28, cf = CFrame.new(0, 4.5, -0.4) },
		},
		Use = { Damage = 10, Cooldown = 0.8, Windup = 0.25, HitboxSize = Vector3.new(10, 8, 9), HitboxOffset = 4.5,
			Knockback = 95, KnockUp = 40, Stun = 0.7, Power = 0.7, Category = "Heavy", Anim = "Slam",
			Lunge = 10, Words = { "BEAR HUG!", "FLUFF!", "SQUISH!" } },
		Throw = { Damage = 10, Speed = 75, Up = 18, Knockback = 65, Stun = 0.9, Category = "Heavy" },
	},
	ToyBlock = {
		DisplayName = "Toy Block", Family = "Throwable", Hold = "Hand", Grip = STICK, Material = "Wood",
		Durability = 5, RespawnTime = 6,
		Use = { Damage = 6, Cooldown = 0.36, Windup = 0.07, HitboxSize = Vector3.new(5, 5, 5.5), HitboxOffset = 3,
			Knockback = 8, KnockUp = 2, Stun = 0.6, Power = 0.45, Category = "Light", Anim = "Jab", Lunge = 10,
			Words = { "ABC!", "BLOCK!", "THUNK!" } },
		Throw = { Damage = 10, Speed = 125, Up = 7, Knockback = 10, Stun = 0.9, Category = "Projectile" },
	},
	RubberDuck = {
		DisplayName = "Rubber Duck", Family = "Zone", Hold = "Hand", Grip = UP, Material = "Rubber",
		Durability = 4, RespawnTime = 7,
		-- Squeak : pas de swing, cri en cône devant (petits dégâts, gros étourdissement, sans recul)
		Use = { Special = "Squeak", SqueakDamage = 2, Radius = 9, Stun = 0.9, Cooldown = 1.1, Windup = 0.1, Anim = "Jab" },
		Throw = { Special = "Bounce", Damage = 7, Speed = 110, Up = 8, Knockback = 8, Stun = 0.8, Category = "Projectile", Bounces = 2 },
	},
	RockingHorse = {
		DisplayName = "Rocking Horse", Family = "Heavy", Hold = "TwoHands", Material = "Wood",
		Durability = 4, RespawnTime = 12, SpeedMultiplier = 0.7,
		HoldOffset = CFrame.new(0, 4.1, -0.4),
		SlamPath = {
			{ t = 0.26, cf = CFrame.new(0, 4.6, 0.8) * CFrame.Angles(math.rad(25), 0, 0) },
			{ t = 0.12, cf = CFrame.new(0, 0.5, -3.7) * CFrame.Angles(math.rad(-70), 0, 0) },
			{ t = 0.3, cf = CFrame.new(0, 4.1, -0.4) },
		},
		Use = { Damage = 18, Cooldown = 1.1, Windup = 0.34, HitboxSize = Vector3.new(10, 8, 10), HitboxOffset = 4.5,
			Knockback = 80, KnockUp = 36, Stun = 1.15, Power = 1.05, Category = "Heavy", Anim = "Slam",
			Lunge = 8, Shockwave = 8, Words = { "YEEHAW!", "GIDDY-UP!", "NEIGH!" } },
		Throw = { Damage = 21, Speed = 60, Up = 24, Knockback = 55, Stun = 1.15, Category = "Heavy" },
	},
	-- Auditorium
	MicStand = {
		DisplayName = "Microphone Stand", Family = "Melee", Hold = "Hand", Grip = UP, Material = "Metal",
		Durability = 8, RespawnTime = 8,
		Use = { Damage = 9, Cooldown = 0.5, Windup = 0.12, HitboxSize = Vector3.new(7, 5, 10), HitboxOffset = 5.5,
			Knockback = 18, KnockUp = 6, Stun = 0.7, Power = 0.65, Category = "Light", Anim = "SideSwing",
			Lunge = 8, Words = { "MIC DROP!", "FEEDBACK!", "CHECK 1-2!" } },
		Throw = { Damage = 10, Speed = 95, Up = 8, Knockback = 12, Stun = 0.9, Category = "Projectile" },
	},
	Spotlight = {
		DisplayName = "Spotlight Lamp", Family = "Zone", Hold = "Hand", Grip = HANG, Material = "Glass",
		Durability = 4, RespawnTime = 10,
		Use = { Damage = 7, Cooldown = 0.45, Windup = 0.1, HitboxSize = Vector3.new(6, 6, 6.5), HitboxOffset = 3.6,
			Knockback = 14, KnockUp = 6, Stun = 0.7, Power = 0.55, Category = "Heavy", Anim = "OverheadSwing",
			Lunge = 12, Words = { "SPOTLIGHT!", "BONK!" } },
		Throw = { Special = "Flash", Damage = 9, Speed = 85, Up = 12, Knockback = 12, Stun = 1.0, Category = "Heavy",
			Radius = 12, BlindTime = 1.4 },
	},
	FoldingSeat = {
		DisplayName = "Folding Seat", Family = "Melee", Hold = "Hand", Grip = HANG, Material = "Metal",
		Durability = 6, RespawnTime = 8,
		Use = { Damage = 11, Cooldown = 0.58, Windup = 0.15, HitboxSize = Vector3.new(7, 6, 7), HitboxOffset = 4,
			Knockback = 30, KnockUp = 14, Stun = 0.9, Power = 0.8, Category = "Heavy", Anim = "OverheadSwing",
			Lunge = 16, Words = { "STEEL CHAIR!", "CLANG!", "OH NO!" } },
		Throw = { Damage = 12, Speed = 85, Up = 14, Knockback = 14, Stun = 0.9, Category = "Heavy" },
	},
	-- Entrepôt
	Pallet = {
		DisplayName = "Pallet", Family = "Heavy", Hold = "TwoHands", Material = "Wood",
		Durability = 4, RespawnTime = 12, SpeedMultiplier = 0.7,
		HoldOffset = CFrame.new(0, 3.2, -0.4),
		SlamPath = {
			{ t = 0.26, cf = CFrame.new(0, 3.7, 0.8) * CFrame.Angles(math.rad(25), 0, 0) },
			{ t = 0.12, cf = CFrame.new(0, 0.2, -3.8) * CFrame.Angles(math.rad(-75), 0, 0) },
			{ t = 0.3, cf = CFrame.new(0, 3.2, -0.4) },
		},
		Use = { Damage = 17, Cooldown = 1.05, Windup = 0.32, HitboxSize = Vector3.new(12, 8, 10), HitboxOffset = 4.5,
			Knockback = 78, KnockUp = 32, Stun = 1.1, Power = 1.0, Category = "Heavy", Anim = "Slam",
			Lunge = 8, Shockwave = 9, Words = { "SPLINTER!", "FORKLIFT!", "CRASH!" } },
		Throw = { Damage = 20, Speed = 60, Up = 24, Knockback = 52, Stun = 1.1, Category = "Heavy" },
	},
	CardboardBox = {
		DisplayName = "Cardboard Box", Family = "Zone", Hold = "Hand", Grip = HANG, Material = "Wood",
		Durability = 3, RespawnTime = 7,
		Use = { Damage = 6, Cooldown = 0.42, Windup = 0.1, HitboxSize = Vector3.new(6.5, 6, 6.5), HitboxOffset = 3.6,
			Knockback = 14, KnockUp = 6, Stun = 0.7, Power = 0.5, Category = "Light", Anim = "OverheadSwing",
			Lunge = 12, Words = { "THUD!", "FRAGILE!" } },
		Throw = { Special = "Smoke", Damage = 7, Speed = 85, Up = 14, Knockback = 12, Stun = 1.0, Category = "Heavy", Radius = 8,
			ImpactWords = { "POOF!", "PACKING PEANUTS!" } },
	},
	HandTruck = {
		DisplayName = "Hand Truck", Family = "Melee", Hold = "Hand", Grip = HANG, Material = "Metal",
		Durability = 7, RespawnTime = 10, SpeedMultiplier = 0.88,
		Use = { Damage = 12, Cooldown = 0.7, Windup = 0.18, HitboxSize = Vector3.new(8, 6, 7), HitboxOffset = 4.2,
			Knockback = 40, KnockUp = 12, Stun = 0.85, Power = 0.85, Category = "Heavy", Anim = "SideSwing",
			Lunge = 14, Words = { "DELIVERY!", "SIGN HERE!", "CLANG!" } },
		Throw = { Special = "Roll", Damage = 12, Speed = 72, Up = 3, Knockback = 46, Stun = 1.0, Category = "Heavy" },
	},
	PaintBucket = {
		DisplayName = "Paint Bucket", Family = "Zone", Hold = "Hand", Grip = HANG, Material = "Plastic",
		Durability = 3, RespawnTime = 9,
		Use = { Special = "Sticky", Radius = 6, Damage = 4, Cooldown = 0.85, Windup = 0.12, HitboxSize = Vector3.new(7, 5, 8), HitboxOffset = 4.5,
			Knockback = 12, KnockUp = 4, Stun = 0.65, Power = 0.45, Category = "Splat", Anim = "SideSwing",
			Words = { "SPLAT!", "FRESH PAINT!" } },
		Throw = { Special = "Sticky", Damage = 8, Speed = 80, Up = 14, Knockback = 10, Stun = 1.0, Category = "Splat", Radius = 9 },
	},
	-- Spa
	TowelRoll = {
		DisplayName = "Towel Roll", Family = "Melee", Hold = "Hand", Grip = STICK, Material = "Rubber",
		Durability = 9, RespawnTime = 6,
		Use = { Damage = 6, Cooldown = 0.3, Windup = 0.06, HitboxSize = Vector3.new(6, 5, 8), HitboxOffset = 4.2,
			Knockback = 6, KnockUp = 2, Stun = 0.85, Power = 0.45, Category = "Light", Anim = "SideSwing",
			Lunge = 10, Words = { "SNAP!", "WHIP!", "TOWEL SNAP!" } },
		Throw = { Damage = 6, Speed = 110, Up = 8, Knockback = 6, Stun = 1.1, Category = "Projectile" },
	},
	BambooPole = {
		DisplayName = "Bamboo Pole", Family = "Melee", Hold = "Hand", Grip = STICK, Material = "Wood",
		Durability = 8, RespawnTime = 7,
		Use = { Damage = 8, Cooldown = 0.5, Windup = 0.1, HitboxSize = Vector3.new(5, 5, 12), HitboxOffset = 6.5,
			Knockback = 22, KnockUp = 6, Stun = 0.65, Power = 0.55, Category = "Light", Anim = "Jab",
			Lunge = 6, Words = { "BONK!", "THWACK!", "HI-YAH!" } },
		Throw = { Damage = 10, Speed = 120, Up = 3, Knockback = 14, Stun = 0.85, Category = "Projectile" },
	},
	HotStone = {
		DisplayName = "Hot Stone", Family = "Throwable", Hold = "Hand", Grip = STICK, Material = "Ceramic",
		Durability = 5, RespawnTime = 7,
		Use = { Damage = 5, Cooldown = 0.32, Windup = 0.06, HitboxSize = Vector3.new(5, 5, 5.5), HitboxOffset = 3,
			Knockback = 6, KnockUp = 0, Stun = 0.55, Power = 0.4, Category = "Light", Anim = "Jab", Lunge = 10,
			Words = { "HOT!", "SIZZLE!" } },
		Throw = { Special = "Bounce", Damage = 7, Speed = 125, Up = 5, Knockback = 8, Stun = 0.8, Category = "Projectile", Bounces = 1,
			Burn = { Ticks = 3, Damage = 2, Interval = 0.6 } },
	},
	LotusCandle = {
		DisplayName = "Lotus Candle", Family = "Zone", Hold = "Hand", Grip = UP, Material = "Ceramic",
		Durability = 3, RespawnTime = 8,
		Use = { Damage = 5, Cooldown = 0.4, Windup = 0.08, HitboxSize = Vector3.new(5, 5, 5.5), HitboxOffset = 3,
			Knockback = 8, KnockUp = 2, Stun = 0.6, Power = 0.4, Category = "Light", Anim = "Jab", Lunge = 10,
			Words = { "ZEN!", "OM!" } },
		Throw = { Special = "Smoke", Damage = 6, Speed = 95, Up = 12, Knockback = 10, Stun = 1.0, Category = "Splat", Radius = 7,
			Burn = { Ticks = 3, Damage = 2, Interval = 0.6 }, ImpactWords = { "ZEN!", "OMMM!" } },
	},
	-- Salle de sport
	Dumbbell = {
		DisplayName = "Dumbbell", Family = "Throwable", Hold = "Hand", Grip = STICK, Material = "Metal",
		Durability = 6, RespawnTime = 8, SpeedMultiplier = 0.9,
		Use = { Damage = 10, Cooldown = 0.55, Windup = 0.12, HitboxSize = Vector3.new(5.5, 5, 6), HitboxOffset = 3.2,
			Knockback = 24, KnockUp = 8, Stun = 0.8, Power = 0.75, Category = "Heavy", Anim = "Jab",
			Lunge = 12, Words = { "GAINS!", "PUMP!", "CLANK!" } },
		Throw = { Damage = 13, Speed = 75, Up = 10, Knockback = 20, Stun = 1.0, Category = "Heavy" },
	},
}
