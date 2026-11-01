--[[
	SkinReveals — mise en scène de la révélation de chaque skin (lu par SkinRevealController, côté client).

	[skinId] = {
		Scene    = modèle de scène : Elevator | Spotlight | SkyDrop | ChairSpin | Delivery | Hologram | Kitchen
		           | ServerRoom | Boardroom | RedCarpet | GymPodium | PaperPortal | Cubicle
		Caption  = phrase drôle affichée sur la carte titre (anglais)
		Showcase = id d'attaque du perso (Config/Attacks ou Content) montrée pendant la démonstration (Epic/Legendary)
		Pose     = pose héroïque finale : Hero | Point | Victory | Boss | Power | Salute | Thinker | Lean | Flex
		Word     = onomatopée de la pose héroïque (défaut "EPIC!" / "LEGENDARY!")
		Location = texte du bandeau du haut (défaut : celui de la scène)
		Beat     = temps fort bonus pendant la pose : Thunder | Fireworks | Glitch | Rain | Quake | Confetti
		Rain     = pluie d'objets pendant le scénario : { Colors = {Color3...}, Size = Vector3, Shape = "Block"|"Ball"|"Cyl", Material, Count, Slow }
		Props    = parts en plus, repère = sol sous le héros (le héros regarde vers -Z, +Z = derrière lui, +X = sa droite) :
		           { Size, Offset = CFrame, Color, Material, Shape = "Block"|"Ball"|"Cyl"|"Wedge", Transparency, Text, TextColor, Light = Color3, Spin = rad/s, Bob = studs }
		           (garder libre la zone de démonstration : x de -11 à +2, z de -6 à +1)
		Tint     = teinte de l'image (ColorCorrection), Rays = couleur des rayons Legendary, Color = couleur des effets
		ShowcaseKind = force le type d'effet de la démonstration (Projectile, Lunge, Cone, Slam, SkyDrop, AoE, Grab, Melee)
	}
	_Characters[charId] = valeurs par défaut d'un perso (skins Base et skins sans entrée) ; _Default = dernier recours.
]]
local C = Color3.fromRGB
local V = Vector3.new
local CF = CFrame.new
local A = CFrame.Angles

local GOLD = C(255, 196, 40)
local CASH = C(110, 200, 90)

local R = {}

R._Default = { Scene = "Cubicle" }

R._Characters = {
	Intern = { Scene = "Elevator", Showcase = "CoffeeRun", Caption = "First day. Already lost. Already legendary." },
	Janitor = { Scene = "Cubicle", Showcase = "MopSweep", Caption = "Wet floor. You have been warned." },
	LunchLady = { Scene = "Kitchen", Showcase = "LadleBonk", Caption = "No seconds. No refunds. No mercy." },
	SecurityGuard = { Scene = "ServerRoom", Showcase = "Detain", Caption = "Badge, please. Wrong answer." },
	ITGuy = { Scene = "ServerRoom", Showcase = "CtrlAltDel", Caption = "Have you tried turning your coworker off and on again?" },
	Accountant = { Scene = "Boardroom", Showcase = "CalculatorThrow", Caption = "Your attitude has been audited. You owe." },
	CEO = { Scene = "ChairSpin", Showcase = "BriefcaseSwing", Caption = "Synergy. Leverage. Violence." },
	HRManager = { Scene = "Boardroom", Showcase = "WriteUp", Caption = "This conversation is being documented." },
	Barista = { Scene = "Kitchen", Showcase = "EspressoExpress", Caption = "Your name is spelled wrong on purpose." },
	MaintenanceGuy = { Scene = "SkyDrop", Showcase = "MonkeyWrench", Caption = "Came to fix the ceiling. From above." },
	DeliveryGuy = { Scene = "Delivery", Showcase = "HandTruckRush", Caption = "Signature required. Yours. On the floor." },
	MarketingGuru = { Scene = "Spotlight", Showcase = "MegaphoneBlast", Caption = "Engagement is up 400%. So is the volume." },
	Receptionist = { Scene = "Elevator", Showcase = "ServiceBell", Caption = "Please hold. Your beating is important to us." },
	Lawyer = { Scene = "Spotlight", Showcase = "GavelSlam", Caption = "Objection overruled. By force." },
	FitnessCoach = { Scene = "GymPodium", Showcase = "KettlebellSwing", Caption = "One more rep. One more coworker." },
	Mascot = { Scene = "RedCarpet", Showcase = "FoamFinger", Caption = "Nobody knows who is inside. Nobody asks." },
}

------------------------------------------------------------------ THE INTERN
R.Intern_Rare = { Scene = "Delivery", Showcase = "StickySlap",
	Caption = "Camped outside for 9 hours for this hoodie. Clocked in 9 hours late." }
R.Intern_Epic = { Scene = "Elevator", Showcase = "CoffeeRun", Pose = "Point", Word = "NEW PB!",
	Caption = "Found an elevator skip. Lobby to desk in 4.2 seconds. World record." }
R.Intern_Legendary = { Scene = "Spotlight", Showcase = "DeadlineDrop", Pose = "Victory", Word = "GO LIVE!", Beat = "Confetti",
	Location = "Main Stage - 1 Million Subs Party",
	Caption = "Smash that like button. He smashed the actual button. And the desk.",
	Rain = { Colors = { C(255, 70, 90), C(255, 140, 180), C(255, 255, 255) }, Size = V(0.7, 0.7, 0.7), Shape = "Ball", Count = 30 },
	Props = {
		{ Size = V(4.2, 3.2, 0.3), Offset = CF(0, 5.6, 3.6), Color = GOLD, Material = "Metal", Text = "1M", TextColor = C(255, 255, 255) },
		{ Size = V(1.6, 0.6, 0.2), Offset = CF(-2.6, 7.6, 3.4) * A(0, 0, -0.15), Color = C(240, 40, 40), Text = "LIVE", Bob = 0.25 },
	} }

------------------------------------------------------------------ THE JANITOR
R.Janitor_Rare = { Scene = "Spotlight", Showcase = "MopSweep", Pose = "Point",
	Location = "Main Stage - Friday Night Cleanup",
	Caption = "The floor is clean. The floor is also his. Night fever, mop edition.",
	Props = { { Size = V(2.2, 2.2, 2.2), Offset = CF(0, 12, 1.5), Color = C(220, 225, 235), Material = "Foil", Shape = "Ball", Spin = 2, Light = C(255, 120, 255) } } }
R.Janitor_Epic = { Scene = "Cubicle", Showcase = "PowerWash", Pose = "Power", Word = "SPOTLESS!",
	Caption = "Before: coffee stain. After: 10 million views. Deeply satisfying." }
R.Janitor_Legendary = { Scene = "ChairSpin", Showcase = "BubblePrison", Pose = "Boss", Word = "KNEEL!", Beat = "Rain",
	Location = "Throne Room - Formerly The Supply Closet", Tint = C(225, 240, 255),
	Caption = "All hail the Emperor of Clean. Kneel. But not on the wet part.",
	Rain = { Colors = { C(200, 240, 255), C(255, 200, 250) }, Size = V(1.1, 1.1, 1.1), Shape = "Ball", Material = "Glass", Count = 26, Slow = 1.8 },
	Props = {
		{ Size = V(1.6, 1.6, 1.6), Offset = CF(-3, 6, 3), Color = C(190, 235, 255), Material = "Glass", Shape = "Ball", Transparency = 0.3, Bob = 0.6 },
		{ Size = V(1.1, 1.1, 1.1), Offset = CF(2.6, 7.2, 2.6), Color = C(255, 200, 250), Material = "Glass", Shape = "Ball", Transparency = 0.3, Bob = 0.5 },
		{ Size = V(0.9, 0.9, 0.9), Offset = CF(-1.5, 8.4, 4), Color = C(200, 255, 220), Material = "Glass", Shape = "Ball", Transparency = 0.3, Bob = 0.4 },
	} }

------------------------------------------------------------------ THE LUNCH LADY
R.LunchLady_Rare = { Scene = "Delivery", Showcase = "MysteryMeat", Pose = "Victory",
	Caption = "The pizza party you were promised in 2019 has finally been delivered." }
R.LunchLady_Epic = { Scene = "Spotlight", Showcase = "HotSoup", Pose = "Point", Word = "FABULOUS!",
	Location = "Studio B - Live Studio Audience",
	Caption = "And now we add a pinch of salt... and a pinch of VIOLENCE, darling." }
R.LunchLady_Legendary = { Scene = "Kitchen", Showcase = "FryingPanSmash", Pose = "Boss", Word = "IT'S RAW!", Beat = "Quake",
	Location = "Break Room - Hell's Cafeteria", Tint = C(255, 225, 200),
	Caption = "Five stars. Zero patience. Your sandwich is RAW and so is this beatdown.",
	Props = {
		{ Size = V(6, 1.2, 0.3), Offset = CF(0, 8.2, 4.2), Color = C(30, 20, 20), Text = "*****", TextColor = GOLD },
		{ Size = V(1.4, 1.4, 1.4), Offset = CF(-3.5, 0.7, 3.5), Color = C(255, 110, 30), Material = "Neon", Shape = "Ball", Bob = 0.3, Light = C(255, 140, 40) },
		{ Size = V(1.4, 1.4, 1.4), Offset = CF(3.5, 0.7, 3.5), Color = C(255, 110, 30), Material = "Neon", Shape = "Ball", Bob = 0.3, Light = C(255, 140, 40) },
	} }

------------------------------------------------------------------ THE SECURITY GUARD
R.SecurityGuard_Rare = { Scene = "Elevator", Showcase = "Flashlight", Pose = "Salute",
	Caption = "Patrolling the lobby at a blistering 12 mph. Nobody gets past. Eventually." }
R.SecurityGuard_Epic = { Scene = "SkyDrop", Showcase = "ElbowDrop", Pose = "Power", Word = "YIPPEE!",
	Caption = "Came in through the ceiling vent. Barefoot. Wrong building. Right guard." }
R.SecurityGuard_Legendary = { Scene = "ServerRoom", Showcase = "TotalLockdown", Pose = "Boss", Word = "VIOLATION!", Beat = "Glitch",
	Location = "Server Room B2 - Lockdown Protocol", Tint = C(255, 220, 220), Rays = C(255, 60, 60),
	Caption = "Scanning for overtime violations... 47 found. Initiating lockdown.",
	Props = {
		{ Size = V(9, 0.15, 0.15), Offset = CF(0, 6, 3), Color = C(255, 40, 40), Material = "Neon", Spin = 3 },
		{ Size = V(0.6, 0.6, 0.6), Offset = CF(0, 8.5, 3), Color = C(255, 40, 40), Material = "Neon", Shape = "Ball", Light = C(255, 40, 40), Bob = 0.2 },
	} }

------------------------------------------------------------------ THE IT GUY
R.ITGuy_Rare = { Scene = "Cubicle", Showcase = "CtrlAltDel", Pose = "Thinker",
	Caption = "\"I'm in.\" He is not in. He forgot his password again." }
R.ITGuy_Epic = { Scene = "Hologram", Showcase = "DDoS", Pose = "Point", Word = "COMBO x99!",
	Location = "R&D Lab - Player 1 Ready",
	Caption = "Press START to take a break. There is no break. There is only high score." }
R.ITGuy_Legendary = { Scene = "ServerRoom", Showcase = "VirusUpload", Pose = "Power", Word = "SUDO!", Beat = "Thunder",
	Location = "Server Room B2 - Root Directory", Tint = C(215, 255, 225), Rays = C(60, 255, 120),
	Caption = "Admin privileges granted: the building, the printer, and you.",
	Rain = { Colors = { C(60, 255, 120), C(20, 180, 80) }, Size = V(0.3, 0.6, 0.3), Material = "Neon", Count = 50, Slow = 0.8 },
	Props = {
		{ Size = V(3, 2, 0.1), Offset = CF(-3, 6, 3) * A(0, 0.3, 0), Color = C(10, 40, 20), Material = "Neon", Transparency = 0.3, Text = "ROOT", TextColor = C(60, 255, 120), Bob = 0.3 },
		{ Size = V(3, 2, 0.1), Offset = CF(3, 6.5, 3) * A(0, -0.3, 0), Color = C(10, 40, 20), Material = "Neon", Transparency = 0.3, Text = "rm -rf", TextColor = C(60, 255, 120), Bob = 0.3 },
	} }

------------------------------------------------------------------ THE ACCOUNTANT
R.Accountant_Rare = { Scene = "ChairSpin", Showcase = "TaxAudit", Pose = "Thinker", Tint = C(215, 220, 235),
	Location = "Corner Office - It Was Raining. It Always Is.",
	Caption = "The numbers never lie. The receipts do. And he has all of them." }
R.Accountant_Epic = { Scene = "Elevator", Showcase = "CalculatorThrow", Pose = "Point", Word = "BUY BUY BUY!",
	Rain = { Colors = { CASH }, Size = V(1.2, 0.05, 0.6), Count = 24 },
	Caption = "Going up! Like his portfolio. Like his voice on the brick phone." }
R.Accountant_Legendary = { Scene = "Boardroom", Showcase = "Bankrupt", Pose = "Power", Word = "BULL RUN!", Beat = "Fireworks",
	Location = "Boardroom - Market Open",
	Caption = "When he charges, stocks go up. So does your insurance premium.",
	Rain = { Colors = { CASH, C(90, 170, 70) }, Size = V(1.3, 0.05, 0.65), Count = 50 },
	Props = {
		{ Size = V(3.6, 2, 1.6), Offset = CF(3.2, 4.2, 4) * A(0, -0.4, 0), Color = GOLD, Material = "Metal" },
		{ Size = V(1.3, 1.3, 1.3), Offset = CF(1.6, 5, 3.4) * A(0, -0.4, 0), Color = GOLD, Material = "Metal" },
		{ Size = V(0.3, 0.3, 1.4), Offset = CF(1.1, 6, 2.9) * A(0.6, -0.4, 0), Color = C(255, 245, 220) },
		{ Size = V(0.3, 0.3, 1.4), Offset = CF(2.1, 6, 2.9) * A(0.6, -0.4, 0), Color = C(255, 245, 220) },
		{ Size = V(2.2, 0.8, 2.2), Offset = CF(3.2, 0.4, 4), Color = C(40, 30, 30), Material = "Marble" },
	} }

------------------------------------------------------------------ THE CEO
R.CEO_Rare = { Scene = "Cubicle", Showcase = "BriefcaseSwing", Pose = "Lean",
	Location = "Garage Startup - Cubicle 1 Of 1",
	Caption = "Dropped out of a stapling course. Now worth 40 billion. Still wears sandals." }
R.CEO_Epic = { Scene = "Hologram", Showcase = "YoureFired", Pose = "Point", Word = "ONE MORE THING!",
	Location = "Keynote Stage - Product Reveal",
	Caption = "It's not a stapler. It's a revolution. Now with no headphone jack." }
R.CEO_Legendary = { Scene = "SkyDrop", Showcase = "StockCrash", Pose = "Hero", Word = "TO THE MOON!", Beat = "Fireworks",
	Location = "Open Space - Landing Zone",
	Caption = "Moving head office to orbit. Parking up there is still a nightmare.",
	Props = {
		{ Size = V(8, 2.4, 2.4), Offset = CF(4.2, 4, 4.5) * A(0, 0, math.pi / 2), Color = C(240, 240, 245), Material = "Metal", Shape = "Cyl" },
		{ Size = V(2.4, 2.4, 2.4), Offset = CF(4.2, 8.2, 4.5), Color = C(220, 40, 40), Shape = "Ball" },
		{ Size = V(0.8, 0.8, 0.1), Offset = CF(4.2, 5.4, 3.25), Color = C(80, 200, 255), Material = "Neon", Shape = "Ball" },
		{ Size = V(0.3, 2, 1.6), Offset = CF(5.6, 1.2, 4.5), Color = C(220, 40, 40), Shape = "Wedge" },
		{ Size = V(0.3, 2, 1.6), Offset = CF(2.8, 1.2, 4.5), Color = C(220, 40, 40), Shape = "Wedge" },
		{ Size = V(1.6, 1.6, 1.6), Offset = CF(4.2, -0.2, 4.5), Color = C(255, 140, 30), Material = "Neon", Shape = "Ball", Light = C(255, 150, 40), Bob = 0.2 },
	} }

------------------------------------------------------------------ THE HR MANAGER
R.HRManager_Rare = { Scene = "GymPodium", Showcase = "TeamBuilding", Pose = "Salute",
	Location = "Company Gym - Mandatory Wellness Hour",
	Caption = "Breathe in. Breathe out. You're fired. Namaste." }
R.HRManager_Epic = { Scene = "ChairSpin", Showcase = "WriteUp", Pose = "Thinker", Word = "AND HOW DO WE FEEL?",
	Location = "Studio C - Daytime Television",
	Caption = "Tell me... how does that performance review make you FEEL?" }
R.HRManager_Legendary = { Scene = "RedCarpet", Showcase = "PerformanceReview", Pose = "Victory", Word = "SPIN THE WHEEL!", Beat = "Confetti",
	Location = "Prime Time - Live From The Lobby",
	Caption = "It's time to spin the Wheel... of Performance Reviews! Live, in front of everyone!",
	Props = {
		{ Size = V(5, 1.4, 0.3), Offset = CF(6, 15, 23) * A(0, -0.2, 0), Color = C(255, 60, 60), Material = "Neon", Text = "APPLAUSE", Bob = 0.2 },
		{ Size = V(1.6, 1.6, 1.6), Offset = CF(-9, 14, 23), Color = GOLD, Material = "Neon", Shape = "Ball", Light = GOLD, Bob = 0.5 },
		{ Size = V(1.6, 1.6, 1.6), Offset = CF(9, 15, 23), Color = C(255, 90, 200), Material = "Neon", Shape = "Ball", Light = C(255, 90, 200), Bob = 0.5 },
		{ Size = V(10, 2, 0.3), Offset = CF(-1, 15.5, 23.3), Color = C(120, 40, 200), Text = "PRIME TIME", TextColor = GOLD },
	} }

------------------------------------------------------------------ THE BARISTA
R.Barista_Rare = { Scene = "Kitchen", Showcase = "LatteArt", Pose = "Point",
	Caption = "Posted the foam heart. 12K likes. The coffee got cold. Worth it." }
R.Barista_Epic = { Scene = "Cubicle", Showcase = "BeanBarrage", Pose = "Thinker", Word = "*whisper*",
	Location = "Open Space - Quiet Zone",
	Caption = "*whispers* ...your espresso... is ready... *tap tap* ...and so is your doom..." }
R.Barista_Legendary = { Scene = "PaperPortal", Showcase = "CaffeineOverload", Pose = "Power", Word = "BREW-NADO!", Beat = "Thunder",
	Location = "Copy Room - The Forbidden Roast", Tint = C(235, 215, 255), Rays = C(190, 110, 255),
	Caption = "Brews forbidden potions. Mostly espresso. One sip and you can hear colors.",
	Props = {
		{ Size = V(1, 1.2, 1.2), Offset = CF(-6, 6, 5) * A(0, 0, math.pi / 2), Color = C(255, 255, 255), Shape = "Cyl", Bob = 0.5, Spin = 1 },
		{ Size = V(1, 1.2, 1.2), Offset = CF(6, 7, 5) * A(0, 0, math.pi / 2), Color = C(255, 255, 255), Shape = "Cyl", Bob = 0.5, Spin = -1 },
		{ Size = V(0.9, 0.9, 0.9), Offset = CF(0, 10, 5), Color = C(180, 100, 255), Material = "Neon", Shape = "Ball", Light = C(180, 100, 255), Bob = 0.4 },
	} }

------------------------------------------------------------------ THE DELIVERY GUY
R.DeliveryGuy_Rare = { Scene = "Elevator", Showcase = "ExpressParcel", Pose = "Salute",
	Caption = "Your order is 2 minutes away. It has been 2 minutes away for 40 minutes." }
R.DeliveryGuy_Epic = { Scene = "GymPodium", Showcase = "HandTruckRush", Pose = "Victory", Word = "PIT STOP!",
	Location = "Company Gym - Grand Prix Finish Line",
	Caption = "Delivered in 2.3 seconds. Also changed the tires on your office chair." }
R.DeliveryGuy_Legendary = { Scene = "Delivery", Showcase = "FragileCrate", Pose = "Victory", Word = "EVERYONE WINS!", Beat = "Confetti",
	Location = "Loading Dock B - The Giveaway",
	Caption = "EVERYONE GETS A PACKAGE! Smash subscribe for a chance to win... a stapler!",
	Rain = { Colors = { C(200, 160, 105), C(220, 185, 130) }, Size = V(1.4, 1.4, 1.4), Count = 30 },
	Props = {
		{ Size = V(2, 2, 2), Offset = CF(-3.5, 1, 3), Color = C(200, 160, 105), Text = "WIN!", TextColor = C(220, 40, 40) },
		{ Size = V(2, 2, 2), Offset = CF(3.2, 1, 3.4), Color = C(200, 160, 105), Text = "FREE", TextColor = C(220, 40, 40) },
		{ Size = V(1.6, 1.6, 1.6), Offset = CF(3.2, 2.8, 3.4) * A(0, 0.4, 0), Color = GOLD, Material = "Metal", Text = "?", TextColor = C(255, 255, 255) },
	} }

------------------------------------------------------------------ THE RECEPTIONIST
R.Receptionist_Rare = { Scene = "PaperPortal", Showcase = "HoldTheLine", Pose = "Lean",
	Location = "Copy Room - Portal To 1986",
	Caption = "Hold, please. Forever. Your call is very important to her nails." }
R.Receptionist_Epic = { Scene = "Boardroom", Showcase = "ServiceBell", Pose = "Point", Word = "BREAKING!",
	Location = "Newsroom - Live At Eleven",
	Caption = "Good evening. Tonight: the printer is on fire. More at eleven." }
R.Receptionist_Legendary = { Scene = "Spotlight", Showcase = "HoldMusic", Pose = "Victory", Word = "ENCORE!", Beat = "Fireworks",
	Location = "Main Stage - Sold Out World Tour",
	Caption = "Sold out 40 stadiums. Still answers the front desk phone between songs.",
	Rain = { Colors = { C(255, 90, 200), C(255, 220, 60), C(120, 220, 255) }, Size = V(0.4, 0.05, 0.3), Count = 40 },
	Props = {
		{ Size = V(0.2, 3.6, 0.2), Offset = CF(1.6, 1.8, -1.2), Color = C(40, 40, 46), Material = "Metal" },
		{ Size = V(0.5, 0.5, 0.5), Offset = CF(1.6, 3.8, -1.2), Color = C(60, 60, 66), Material = "Metal", Shape = "Ball" },
		{ Size = V(2.6, 4, 2), Offset = CF(-5, 2, 3.5), Color = C(30, 30, 36), Text = "((O))", TextColor = C(255, 90, 200) },
		{ Size = V(2.6, 4, 2), Offset = CF(5, 2, 3.5), Color = C(30, 30, 36), Text = "((O))", TextColor = C(255, 90, 200) },
	} }

------------------------------------------------------------------ THE FITNESS COACH
R.FitnessCoach_Rare = { Scene = "GymPodium", Showcase = "JumpRopeWhirlwind", Pose = "Victory",
	Location = "Company Gym - 1983 Aerobics Tape",
	Caption = "Feel the burn! And the deadline! Five, six, seven, EIGHT!" }
R.FitnessCoach_Epic = { Scene = "RedCarpet", Showcase = "MedicineBall", Pose = "Flex", Word = "#GAINS!",
	Location = "Lobby - Influencer Meet & Greet",
	Caption = "Do you even lift... the office morale? #blessed #legday #mondays" }
R.FitnessCoach_Legendary = { Scene = "GymPodium", Showcase = "PushUpShockwave", Pose = "Flex", Word = "UNDISPUTED!", Beat = "Quake",
	Location = "Company Gym - Title Fight Night", Rays = C(255, 60, 60),
	Caption = "Undefeated in 47 office fights. Trains on the stairs. All 80 floors.",
	Props = {
		{ Size = V(0.5, 4.5, 0.5), Offset = CF(-4.5, 2.25, 2), Color = C(220, 40, 40) },
		{ Size = V(0.5, 4.5, 0.5), Offset = CF(4.5, 2.25, 2), Color = C(40, 80, 220) },
		{ Size = V(9, 0.2, 0.2), Offset = CF(0, 3.2, 2), Color = C(255, 255, 255) },
		{ Size = V(9, 0.2, 0.2), Offset = CF(0, 4.2, 2), Color = C(255, 255, 255) },
		{ Size = V(3, 1, 0.3), Offset = CF(0, 9, 4), Color = GOLD, Material = "Metal", Text = "CHAMP", TextColor = C(30, 20, 20), Bob = 0.3 },
	} }

------------------------------------------------------------------ THE MAINTENANCE GUY
R.MaintenanceGuy_Rare = { Scene = "SkyDrop", Showcase = "MonkeyWrench", Pose = "Salute",
	Location = "Open Space - Ceiling Tile 7B",
	Caption = "Fixes everything with tape. Everything. Including the ceiling he just fell through." }
R.MaintenanceGuy_Epic = { Scene = "Boardroom", Showcase = "LadderSpin", Pose = "Point", Word = "MOVE THAT DESK!",
	Location = "Boardroom - Extreme Makeover",
	Caption = "MOVE! THAT! DESK! He renovated your cubicle. You did not ask." }
R.MaintenanceGuy_Legendary = { Scene = "Hologram", Showcase = "ToolboxDrop", Pose = "Power", Word = "MECH ONLINE!", Beat = "Thunder",
	Location = "R&D Lab - Hangar 9", Tint = C(255, 235, 210), Rays = C(255, 150, 40),
	Caption = "Brought a giant robot to a desk fight. Warranty void. Worth it.",
	Props = {
		{ Size = V(2.2, 7, 2.2), Offset = CF(-4.5, 3.5, 3.5), Color = C(255, 160, 40), Material = "Metal" },
		{ Size = V(2.2, 7, 2.2), Offset = CF(4.5, 3.5, 3.5), Color = C(255, 160, 40), Material = "Metal" },
		{ Size = V(11, 1.4, 1.6), Offset = CF(0, 7.6, 3.5), Color = C(60, 60, 70), Material = "DiamondPlate" },
		{ Size = V(1.2, 1.2, 1.2), Offset = CF(-4.5, 8.6, 3.5), Color = C(255, 60, 40), Material = "Neon", Shape = "Ball", Light = C(255, 80, 40) },
		{ Size = V(1.2, 1.2, 1.2), Offset = CF(4.5, 8.6, 3.5), Color = C(255, 60, 40), Material = "Neon", Shape = "Ball", Light = C(255, 80, 40) },
	} }

------------------------------------------------------------------ THE MARKETING GURU
R.MarketingGuru_Rare = { Scene = "RedCarpet", Showcase = "ViralTrend", Pose = "Point",
	Caption = "Personal brand: 100%. Actual work: to be determined. #hustle" }
R.MarketingGuru_Epic = { Scene = "Delivery", Showcase = "ConfettiCannon", Pose = "Victory", Word = "LET'S GOOO!",
	Location = "Loading Dock B - Hype Unboxing",
	Caption = "LET'S GOOOO! (to the 3pm meeting about the 4pm meeting)" }
R.MarketingGuru_Legendary = { Scene = "Hologram", Showcase = "BillboardDrop", Pose = "Victory", Word = "SKIP AD IN 5!", Beat = "Glitch",
	Location = "R&D Lab - Sponsored Content", Tint = C(255, 230, 250), Rays = C(255, 90, 200),
	Caption = "This skin is sponsored by... this skin. You cannot skip this ad.",
	Props = {
		{ Size = V(3, 1.6, 0.1), Offset = CF(-3.6, 6.4, 2.8) * A(0, 0.35, 0), Color = C(255, 90, 200), Material = "Neon", Transparency = 0.15, Text = "BUY NOW", Bob = 0.4 },
		{ Size = V(3, 1.6, 0.1), Offset = CF(3.4, 7.2, 3) * A(0, -0.35, 0), Color = C(255, 220, 60), Material = "Neon", Transparency = 0.15, Text = "50% OFF", TextColor = C(30, 20, 20), Bob = 0.4 },
		{ Size = V(3.4, 1.2, 0.1), Offset = CF(0, 9.4, 3.6), Color = C(30, 30, 40), Material = "Neon", Transparency = 0.15, Text = "SKIP AD >", Bob = 0.3 },
	} }

------------------------------------------------------------------ THE LAWYER
R.Lawyer_Rare = { Scene = "Boardroom", Showcase = "LawBooks", Pose = "Thinker",
	Caption = "Powdered wig. Unpowdered arguments. Bills you for this sentence." }
R.Lawyer_Epic = { Scene = "ChairSpin", Showcase = "GavelSlam", Pose = "Point", Word = "GUILTY!",
	Location = "Courtroom 3 - Daytime TV Edition",
	Caption = "Order in the break room! Case dismissed. You are ALL guilty." }
R.Lawyer_Legendary = { Scene = "Spotlight", Showcase = "Objection", Pose = "Point", Word = "CASE CLOSED!", Beat = "Thunder",
	Location = "Supreme Court Of The Break Room", Rays = C(255, 60, 60),
	Caption = "Case closed. Building closed. Everything closed. Objection SUSTAINED.",
	Props = {
		{ Size = V(9, 3.2, 2), Offset = CF(0, 1.6, 4.5), Color = C(90, 55, 35), Material = "Wood" },
		{ Size = V(3, 0.9, 0.2), Offset = CF(0, 2.4, 3.45), Color = GOLD, Material = "Metal", Text = "JUSTICE", TextColor = C(30, 20, 20) },
		{ Size = V(0.6, 0.6, 3), Offset = CF(3, 3.6, 4.5) * A(0, 0.5, 0), Color = C(120, 75, 45), Material = "Wood" },
		{ Size = V(1.4, 1.4, 1), Offset = CF(3.6, 3.6, 3.6) * A(0, 0.5, 0), Color = C(120, 75, 45), Material = "Wood" },
	} }

------------------------------------------------------------------ THE MASCOT
R.Mascot_Rare = { Scene = "Kitchen", Showcase = "FoamFinger", Pose = "Victory",
	Location = "Break Room - Hot Dog Day",
	Caption = "Relish the moment. Ketchup is extra. Mustard is a war crime." }
R.Mascot_Epic = { Scene = "SkyDrop", Showcase = "TShirtCannon", Pose = "Hero", Word = "UP UP & AWAY!",
	Location = "Open Space - Hero Landing Zone",
	Caption = "Faster than a speeding T-shirt cannon. Weakness: the stairs." }
R.Mascot_Legendary = { Scene = "RedCarpet", Showcase = "GrandFinale", Pose = "Victory", Word = "TOUCHDOWN!", Beat = "Fireworks",
	Location = "Halftime Show - Lobby Stadium",
	Caption = "The crowd goes WILD. The office goes WILDER. Jumbotron included.",
	Rain = { Colors = { C(255, 80, 80), C(255, 220, 60), C(80, 200, 255), C(120, 255, 120) }, Size = V(0.4, 0.05, 0.3), Count = 50 },
	Props = {
		{ Size = V(14, 5, 0.4), Offset = CF(0, 16, 23.3), Color = C(20, 20, 26), Material = "Neon", Transparency = 0.1, Text = "HOME 99 - 0 AWAY", TextColor = C(255, 220, 60) },
		{ Size = V(1.4, 1.4, 1.4), Offset = CF(-8.5, 19, 23), Color = C(255, 250, 220), Material = "Neon", Shape = "Ball", Light = C(255, 250, 220) },
		{ Size = V(1.4, 1.4, 1.4), Offset = CF(8.5, 19, 23), Color = C(255, 250, 220), Material = "Neon", Shape = "Ball", Light = C(255, 250, 220) },
	} }


------------------------------------------------------------------ PACKS v2 (chorégraphies scriptées)
-- Enfants Pack1..Pack5 : { [skinId] = entrée } (ou tableau d'entrées avec Id). Chaque entrée est fusionnée
-- par-dessus l'entrée de même Id ci-dessus (Caption / Location conservées si absentes).
-- Reveal = function(R, ctx) (ou liste de fonctions) : chorégraphie propre au skin, voir l'en-tête de
-- SkinRevealController et scratchpad/REVEAL_API.md. Une entrée avec Reveal n'utilise plus Scene/Showcase/Pose/Props.
do
	local function merge(id, e)
		if type(id) ~= "string" or type(e) ~= "table" or string.sub(id, 1, 1) == "_" then
			return
		end
		local out = type(R[id]) == "table" and table.clone(R[id]) or {}
		for k, v in pairs(e) do
			out[k] = v
		end
		R[id] = out
	end
	for i = 1, 9 do
		local m = script:FindFirstChild("Pack" .. i)
		if m and m:IsA("ModuleScript") then
			local ok, pack = pcall(require, m)
			if ok and type(pack) == "table" then
				for _, e in ipairs(pack) do
					if type(e) == "table" then
						merge(e.Id, e)
					end
				end
				for id, e in pairs(pack) do
					if type(id) == "string" then
						merge(id, e)
					end
				end
			else
				warn("[SkinReveals] pack invalide", m.Name, pack)
			end
		end
	end
end

return R
