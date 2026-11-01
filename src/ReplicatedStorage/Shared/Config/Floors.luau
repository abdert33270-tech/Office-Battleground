--[[
	Floors — fiche du système d'étages (FloorService).
	Ajouter un étage = construire un Model dans ServerStorage.Floors (voir vault) + l'ajouter à Pool.
]]
return {
	StartFloor = 30,          -- on commence en haut, le numéro descend
	Spacing = 60,             -- distance verticale entre deux étages (studs)
	Pool = { "OpenSpace", "Cafeteria", "ServerRoom", "ParkingGarage", "CorporateGym", "Mailroom", "MeetingRooms", "CEOOffice",
		"Lobby", "Rooftop", "Archives", "GameRoom", "Daycare", "Auditorium", "Warehouse", "Spa" },

	-- durées des phases (secondes)
	Durations = { Business = 90, Events = 60, Warning = 15 },
	-- ReplicatedStorage:SetAttribute("FastFloors", true) => durées de test
	FastDurations = { Business = 12, Events = 25, Warning = 6 },

	EventsPerFloor = { 1, 2 },   -- nombre d'événements pendant la phase Events (min, max)
	SpecialChance = 0.65,        -- chance que l'un d'eux soit l'événement spécial de l'étage
	Special = {
		OpenSpace = "PrinterRampage",
		Cafeteria = "FoodFight",
		ServerRoom = "Overheat",
		ParkingGarage = "CarAlarm",
		CorporateGym = "FitnessChallenge",
		Mailroom = "PackageAvalanche",
		MeetingRooms = "ReplyAll",
		CEOOffice = "ShareholderMeeting",
		Lobby = "RushHour",
		Rooftop = "HelicopterLanding",
		Archives = "PaperStorm",
		GameRoom = "PingPongBarrage",
		Daycare = "NapTime",
		Auditorium = "Keynote",
		Warehouse = "ForkliftFrenzy",
		Spa = "SteamBurst",
	},

	LandingProtection = 3,       -- secondes d'invincibilité après l'atterrissage
	FallKillMargin = 40,         -- sous l'étage actuel - marge => "resigned"
	TileFallSpread = 0.9,        -- étalement (s) de la chute des dalles

	Colors = {
		Warning = Color3.fromRGB(255, 70, 50),
		NewBuilding = Color3.fromRGB(255, 220, 60),
	},
}
