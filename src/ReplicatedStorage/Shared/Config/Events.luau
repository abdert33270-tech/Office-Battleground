--[[
	Events — fiche de chaque événement de bureau (EventService).
	Weight = probabilité relative de tirage parmi les génériques. Persistent = survit au changement d'étage.
	Floor = événement spécial réservé à cet étage.
]]
return {
	Generic = { "FireAlarm", "PizzaDelivery", "SurpriseMeeting", "PowerOutage", "BossVisit", "Friday5PM" },

	FireAlarm = {
		Title = "FIRE ALARM!", Sub = "Sprinklers on. Watch your step!", Color = Color3.fromRGB(255, 60, 50),
		Duration = 25, Weight = 3, Puddles = 12,
	},
	PizzaDelivery = {
		Title = "PIZZA DELIVERY!", Sub = "Free pizza! First come, first served.", Color = Color3.fromRGB(255, 170, 40),
		Duration = 30, Weight = 3, Boxes = 5, Heal = 25,
	},
	SurpriseMeeting = {
		Title = "SURPRISE MEETING!", Sub = "Everyone to the meeting table. NOW.", Color = Color3.fromRGB(90, 140, 255),
		Duration = 30, Weight = 2,
	},
	PowerOutage = {
		Title = "POWER OUTAGE!", Sub = "Who turned off the lights?!", Color = Color3.fromRGB(60, 60, 90),
		Duration = 25, Weight = 2,
	},
	BossVisit = {
		Title = "BOSS VISIT!", Sub = "Look busy!!", Color = Color3.fromRGB(180, 40, 40),
		Duration = 22, Weight = 2, Damage = 15, Knockback = 95, Up = 55, Scale = 4,
	},
	Friday5PM = {
		Title = "FRIDAY 5PM!", Sub = "Double XP. Party time!", Color = Color3.fromRGB(255, 80, 200),
		Duration = 120, Weight = 1, Persistent = true,
	},
	PrinterRampage = {
		Title = "PRINTER RAMPAGE!", Sub = "The printers have become self-aware.", Color = Color3.fromRGB(80, 160, 255),
		Duration = 25, Floor = "OpenSpace", Damage = 4, Interval = 0.7, Speed = 70,
	},
	FoodFight = {
		Title = "FOOD FIGHT!", Sub = "Incoming lunch from above!", Color = Color3.fromRGB(255, 140, 40),
		Duration = 25, Floor = "Cafeteria", Damage = 4, Interval = 0.22, HealChance = 0.12, Heal = 10,
	},
	Overheat = {
		Title = "OVERHEAT!", Sub = "Servers are frying. Avoid the sparks!", Color = Color3.fromRGB(80, 255, 120),
		Duration = 25, Floor = "ServerRoom", Damage = 6, OnTime = 3, OffTime = 2.5,
	},
	CarAlarm = {
		Title = "CAR ALARM!", Sub = "Somebody left the handbrake off!", Color = Color3.fromRGB(255, 205, 40),
		Duration = 25, Floor = "ParkingGarage", Damage = 12, Interval = 4, Speed = 70,
	},
	FitnessChallenge = {
		Title = "FITNESS CHALLENGE!", Sub = "Treadmills on MAX. Dodge the medicine balls!", Color = Color3.fromRGB(230, 50, 50),
		Duration = 25, Floor = "CorporateGym", BeltSpeed = 28, LaneSpeed = 20, Balls = 5, BallSpeed = 30,
		Gravity = 70, Bounce = 34, Damage = 5, Knockback = 40, Up = 24,
	},
	PackageAvalanche = {
		Title = "PACKAGE AVALANCHE!", Sub = "Incoming deliveries. Watch the shadows!", Color = Color3.fromRGB(240, 180, 40),
		Duration = 25, Floor = "Mailroom", Damage = 10, Knockback = 50, Up = 32, Interval = 0.55, PerWave = 2,
		Telegraph = 1.2, TargetChance = 0.45, Radius = 5,
	},
	ReplyAll = {
		Title = "REPLY ALL!", Sub = "Someone hit Reply All. Duck!", Color = Color3.fromRGB(40, 195, 190),
		Duration = 25, Floor = "MeetingRooms", Damage = 3, Interval = 1.3, PerWave = 3, Fan = 5, Speed = 48,
	},
	ShareholderMeeting = {
		Title = "SHAREHOLDER MEETING!", Sub = "Grab the gold. Dodge the golden CEO!", Color = Color3.fromRGB(255, 200, 50),
		Duration = 28, Floor = "CEOOffice", Damage = 12, Knockback = 75, Up = 45, Radius = 18, Telegraph = 0.9,
		StompEvery = 3.2, WalkSpeed = 9, Scale = 4.5, CoinInterval = 0.3, HealChance = 0.45, Heal = 6,
		Overtime = 10, CoinLife = 9, MaxCoins = 30,
	},

	-- Spéciaux des 8 étages ajoutés (Lobby, Rooftop, Archives, GameRoom, Daycare, Auditorium, Warehouse, Spa)
	RushHour = {
		Title = "RUSH HOUR!", Sub = "Commuters incoming. Don't get trampled!", Color = Color3.fromRGB(70, 110, 230),
		Duration = 25, Floor = "Lobby", Damage = 4, Knockback = 55, Up = 22, Speed = 28, Crowd = 7, Interval = 2.6, Telegraph = 1.4,
	},
	HelicopterLanding = {
		Title = "HELICOPTER LANDING!", Sub = "Hold on tight. Supply crates incoming!", Color = Color3.fromRGB(90, 200, 255),
		Duration = 26, Floor = "Rooftop", HoverHeight = 24, WindRadius = 34, WindEvery = 1.2, WindPush = 48, WindUp = 14, WindDamage = 1,
		Crates = 4, CrateEvery = 3.5, CrateDamage = 12, CrateRadius = 6, Heal = 20, Telegraph = 1.4,
	},
	PaperStorm = {
		Title = "PAPER STORM!", Sub = "The archives are alive. Avoid the tornadoes!", Color = Color3.fromRGB(210, 160, 90),
		Duration = 25, Floor = "Archives", Tornadoes = 3, Radius = 7, Speed = 13, Damage = 5, Launch = 70, Spin = 38, Telegraph = 1.5,
	},
	PingPongBarrage = {
		Title = "PING PONG BARRAGE!", Sub = "The ball machines went wild!", Color = Color3.fromRGB(160, 80, 240),
		Duration = 24, Floor = "GameRoom", Interval = 0.4, Speed = 60, Gravity = 70, Bounce = 28, Damage = 3, Knockback = 22, Up = 10,
		Life = 3.5, VolleyEvery = 5, Volley = 5,
	},
	NapTime = {
		Title = "NAP TIME!", Sub = "Shhh... don't let the teddies hug you!", Color = Color3.fromRGB(255, 150, 200),
		Duration = 26, Floor = "Daycare", Clouds = 5, CloudRadius = 9, SlowMult = 0.4, CloudSpeed = 7,
		TeddyEvery = 3.2, TeddySpeed = 24, TeddyDamage = 8, Knockback = 60, Up = 32, Telegraph = 1.5,
	},
	Keynote = {
		Title = "KEYNOTE!", Sub = "Don't hog the spotlight!", Color = Color3.fromRGB(220, 40, 70),
		Duration = 26, Floor = "Auditorium", Spots = 3, Radius = 6, Speed = 10, Heat = 1.5, Damage = 9, Knockback = 30, Up = 24,
	},
	ForkliftFrenzy = {
		Title = "FORKLIFT FRENZY!", Sub = "Stay off the yellow lanes!", Color = Color3.fromRGB(240, 110, 30),
		Duration = 25, Floor = "Warehouse", Speed = 34, Damage = 10, Knockback = 75, Up = 35, Telegraph = 1.5, Pause = 1.2,
	},
	SteamBurst = {
		Title = "STEAM BURST!", Sub = "Hot vents! Watch the orange glow!", Color = Color3.fromRGB(130, 210, 150),
		Duration = 25, Floor = "Spa", Interval = 1.5, PerWave = 3, Telegraph = 1.3, Radius = 5.5, Launch = 95, Damage = 4, TargetChance = 0.6,
	},

	-- sons publics vérifiés (chargent en Studio)
	Sounds = {
		Helicopter = "rbxassetid://109810223981955",  -- rotor (boucle)
		Steam = "rbxassetid://6695868929",
		ForkliftBeep = "rbxassetid://5471337533",     -- bip de recul (boucle)
		Lullaby = "rbxassetid://9047785119",          -- berceuse boîte à musique
		Applause = "rbxassetid://1425780550",
		PingPong = "rbxassetid://9117374026",
		Wind = "rbxassetid://123812440037767",        -- tornade (boucle)
		Crowd = "rbxassetid://9112879448",            -- foule (boucle)
		Alarm = "rbxassetid://136815208367984",       -- sonnerie incendie (boucle)
		FireBell = "rbxassetid://140176777321375",
		Rumble = "rbxassetid://9112775165",           -- grondement (effondrement)
		Crumble = "rbxassetid://9114220835",          -- débris qui tombent
		Party = "rbxassetid://1845764031",            -- musique Friday 5PM
		CarAlarm = "rbxassetid://6762866945",
		Horn = "rbxassetid://137100035389921",
		Spark = "rbxassetid://135688197376970",
		Printer = "rbxassetid://9125699413",
		Doorbell = "rbxassetid://139039661050341",
		PowerDown = "rbxassetid://124307033081669",
	},
}
