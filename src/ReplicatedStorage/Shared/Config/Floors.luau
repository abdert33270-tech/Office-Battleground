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

	-- Éclairage par étage (FloorService, serveur => répliqué) : fondu de LightingTween s à l'atterrissage.
	-- Ambient / OutdoorAmbient / ClockTime / Brightness = Lighting ; Atmosphere = Lighting.Atmosphere ;
	-- Grade = ColorCorrectionEffect « FloorGrade » (créé par FloorService). Étage absent => LightingDefault.
	-- Pas d'ExposureCompensation / EnvironmentDiffuseScale ici : réservés à la coupure de courant (EventService).
	LightingTween = 1.5,
	LightingDefault = {
		Ambient = Color3.fromRGB(70, 70, 70), OutdoorAmbient = Color3.fromRGB(70, 70, 70), ClockTime = 14.5, Brightness = 3,
		Atmosphere = { Density = 0.3, Color = Color3.fromRGB(199, 199, 199), Decay = Color3.fromRGB(106, 112, 125) },
		Grade = { TintColor = Color3.fromRGB(255, 255, 255), Saturation = 0, Contrast = 0 },
	},
	Lighting = {
		-- open space : néons de bureau neutres, lumineux
		OpenSpace = {
			Ambient = Color3.fromRGB(95, 95, 100), OutdoorAmbient = Color3.fromRGB(130, 130, 135), ClockTime = 14, Brightness = 3,
			Atmosphere = { Density = 0.28, Color = Color3.fromRGB(205, 210, 220), Decay = Color3.fromRGB(110, 115, 130) },
			Grade = { TintColor = Color3.fromRGB(255, 255, 250), Saturation = 0.05, Contrast = 0.03 },
		},
		-- cafétéria : chaud, midi
		Cafeteria = {
			Ambient = Color3.fromRGB(110, 95, 75), OutdoorAmbient = Color3.fromRGB(150, 130, 105), ClockTime = 12.5, Brightness = 3.2,
			Atmosphere = { Density = 0.27, Color = Color3.fromRGB(235, 215, 185), Decay = Color3.fromRGB(140, 115, 90) },
			Grade = { TintColor = Color3.fromRGB(255, 245, 230), Saturation = 0.12, Contrast = 0.04 },
		},
		-- salle serveurs : bleu froid, sombre, contrasté
		ServerRoom = {
			Ambient = Color3.fromRGB(55, 80, 120), OutdoorAmbient = Color3.fromRGB(60, 90, 140), ClockTime = 19, Brightness = 1.6,
			Atmosphere = { Density = 0.38, Color = Color3.fromRGB(120, 160, 220), Decay = Color3.fromRGB(60, 90, 150) },
			Grade = { TintColor = Color3.fromRGB(200, 225, 255), Saturation = -0.15, Contrast = 0.12 },
		},
		-- parking : béton, lampes au sodium
		ParkingGarage = {
			Ambient = Color3.fromRGB(70, 65, 55), OutdoorAmbient = Color3.fromRGB(85, 80, 70), ClockTime = 17.5, Brightness = 1.8,
			Atmosphere = { Density = 0.4, Color = Color3.fromRGB(170, 160, 140), Decay = Color3.fromRGB(100, 90, 75) },
			Grade = { TintColor = Color3.fromRGB(255, 240, 210), Saturation = -0.2, Contrast = 0.1 },
		},
		-- salle de sport : matin, très lumineux, saturé
		CorporateGym = {
			Ambient = Color3.fromRGB(110, 105, 100), OutdoorAmbient = Color3.fromRGB(150, 145, 140), ClockTime = 10, Brightness = 3.4,
			Atmosphere = { Density = 0.22, Color = Color3.fromRGB(220, 225, 235), Decay = Color3.fromRGB(120, 130, 150) },
			Grade = { TintColor = Color3.fromRGB(255, 250, 245), Saturation = 0.2, Contrast = 0.08 },
		},
		-- courrier : beige papier
		Mailroom = {
			Ambient = Color3.fromRGB(100, 90, 75), OutdoorAmbient = Color3.fromRGB(135, 120, 100), ClockTime = 15.5, Brightness = 2.8,
			Atmosphere = { Density = 0.32, Color = Color3.fromRGB(215, 200, 170), Decay = Color3.fromRGB(130, 115, 90) },
			Grade = { TintColor = Color3.fromRGB(255, 245, 225), Saturation = -0.05, Contrast = 0.03 },
		},
		-- salles de réunion : corporate froid
		MeetingRooms = {
			Ambient = Color3.fromRGB(90, 95, 105), OutdoorAmbient = Color3.fromRGB(125, 130, 145), ClockTime = 13, Brightness = 2.9,
			Atmosphere = { Density = 0.27, Color = Color3.fromRGB(200, 210, 230), Decay = Color3.fromRGB(105, 115, 140) },
			Grade = { TintColor = Color3.fromRGB(245, 250, 255), Saturation = -0.05, Contrast = 0.05 },
		},
		-- bureau du PDG : heure dorée, luxe
		CEOOffice = {
			Ambient = Color3.fromRGB(120, 95, 70), OutdoorAmbient = Color3.fromRGB(170, 130, 90), ClockTime = 17.2, Brightness = 3,
			Atmosphere = { Density = 0.3, Color = Color3.fromRGB(240, 200, 150), Decay = Color3.fromRGB(150, 100, 70) },
			Grade = { TintColor = Color3.fromRGB(255, 235, 205), Saturation = 0.15, Contrast = 0.08 },
		},
		-- hall : marbre clair, propre
		Lobby = {
			Ambient = Color3.fromRGB(115, 115, 120), OutdoorAmbient = Color3.fromRGB(160, 160, 165), ClockTime = 11, Brightness = 3.3,
			Atmosphere = { Density = 0.25, Color = Color3.fromRGB(215, 220, 230), Decay = Color3.fromRGB(115, 120, 135) },
			Grade = { TintColor = Color3.fromRGB(255, 255, 255), Saturation = 0.05, Contrast = 0.02 },
		},
		-- toit : plein soleil, ciel bleu
		Rooftop = {
			Ambient = Color3.fromRGB(120, 120, 130), OutdoorAmbient = Color3.fromRGB(170, 175, 190), ClockTime = 13, Brightness = 4,
			Atmosphere = { Density = 0.2, Color = Color3.fromRGB(190, 215, 255), Decay = Color3.fromRGB(110, 140, 200) },
			Grade = { TintColor = Color3.fromRGB(255, 252, 240), Saturation = 0.18, Contrast = 0.06 },
		},
		-- archives : poussiéreux, sépia, sombre
		Archives = {
			Ambient = Color3.fromRGB(80, 70, 55), OutdoorAmbient = Color3.fromRGB(100, 88, 70), ClockTime = 16.8, Brightness = 1.9,
			Atmosphere = { Density = 0.45, Color = Color3.fromRGB(190, 170, 135), Decay = Color3.fromRGB(120, 100, 70) },
			Grade = { TintColor = Color3.fromRGB(255, 235, 200), Saturation = -0.25, Contrast = 0.06 },
		},
		-- salle de jeux : néons violets, soirée
		GameRoom = {
			Ambient = Color3.fromRGB(100, 70, 130), OutdoorAmbient = Color3.fromRGB(120, 90, 160), ClockTime = 19.5, Brightness = 2,
			Atmosphere = { Density = 0.3, Color = Color3.fromRGB(190, 150, 240), Decay = Color3.fromRGB(110, 70, 160) },
			Grade = { TintColor = Color3.fromRGB(240, 225, 255), Saturation = 0.25, Contrast = 0.1 },
		},
		-- crèche : pastel doux
		Daycare = {
			Ambient = Color3.fromRGB(125, 110, 120), OutdoorAmbient = Color3.fromRGB(170, 155, 170), ClockTime = 10.5, Brightness = 3,
			Atmosphere = { Density = 0.25, Color = Color3.fromRGB(255, 225, 240), Decay = Color3.fromRGB(170, 130, 160) },
			Grade = { TintColor = Color3.fromRGB(255, 245, 250), Saturation = 0.15, Contrast = -0.02 },
		},
		-- auditorium : scène sombre, contrastée
		Auditorium = {
			Ambient = Color3.fromRGB(60, 55, 70), OutdoorAmbient = Color3.fromRGB(75, 70, 90), ClockTime = 19, Brightness = 1.5,
			Atmosphere = { Density = 0.35, Color = Color3.fromRGB(150, 140, 180), Decay = Color3.fromRGB(80, 70, 110) },
			Grade = { TintColor = Color3.fromRGB(245, 235, 255), Saturation = 0.05, Contrast = 0.14 },
		},
		-- entrepôt : industriel, poussière
		Warehouse = {
			Ambient = Color3.fromRGB(75, 72, 65), OutdoorAmbient = Color3.fromRGB(95, 92, 85), ClockTime = 16, Brightness = 2.1,
			Atmosphere = { Density = 0.42, Color = Color3.fromRGB(180, 175, 160), Decay = Color3.fromRGB(105, 100, 85) },
			Grade = { TintColor = Color3.fromRGB(250, 245, 230), Saturation = -0.15, Contrast = 0.1 },
		},
		-- spa : chaud, vapeur, doux
		Spa = {
			Ambient = Color3.fromRGB(125, 100, 85), OutdoorAmbient = Color3.fromRGB(170, 140, 115), ClockTime = 16.5, Brightness = 2.6,
			Atmosphere = { Density = 0.36, Color = Color3.fromRGB(245, 210, 180), Decay = Color3.fromRGB(170, 120, 100) },
			Grade = { TintColor = Color3.fromRGB(255, 232, 215), Saturation = 0.05, Contrast = -0.03 },
		},
	},

	-- Ambiance sonore par étage (AmbienceController, client) : boucles dans le SoundGroup « Ambience »
	-- (volume du groupe = réglage AmbienceVolume). UNIQUEMENT des sons déjà présents dans le jeu :
	-- Src = "Sounds" => Config/Sounds[Key][1] ; Src = "Events" => Config/Events.Sounds[Key].
	-- Volume ~0.15 ; Pitch < 1 = plus grave. Fondu croisé AmbienceFade s au changement d'étage.
	AmbienceFade = 2.5,
	Ambience = {
		OpenSpace = { { Src = "Sounds", Key = "Typing", Volume = 0.15 }, { Src = "Events", Key = "Printer", Volume = 0.04, Pitch = 0.9 } },
		Cafeteria = { { Src = "Events", Key = "Crowd", Volume = 0.12 } },
		ServerRoom = { { Src = "Sounds", Key = "Electric", Volume = 0.12, Pitch = 0.3 } }, -- bourdonnement électrique grave
		ParkingGarage = { { Src = "Events", Key = "Rumble", Volume = 0.13, Pitch = 0.6 } },
		CorporateGym = { { Src = "Events", Key = "Crowd", Volume = 0.08, Pitch = 1.08 } },
		Mailroom = { { Src = "Events", Key = "Printer", Volume = 0.08, Pitch = 0.8 } },
		MeetingRooms = { { Src = "Events", Key = "Crowd", Volume = 0.06, Pitch = 0.9 } },
		CEOOffice = { { Src = "Events", Key = "Wind", Volume = 0.06, Pitch = 0.7 } },
		Lobby = { { Src = "Events", Key = "Crowd", Volume = 0.12 } },
		Rooftop = { { Src = "Events", Key = "Wind", Volume = 0.15 } },
		Archives = { { Src = "Events", Key = "Wind", Volume = 0.06, Pitch = 0.5 } },
		GameRoom = { { Src = "Events", Key = "Crowd", Volume = 0.1, Pitch = 1.1 } },
		Daycare = { { Src = "Events", Key = "Lullaby", Volume = 0.07 } },
		Auditorium = { { Src = "Events", Key = "Crowd", Volume = 0.09, Pitch = 0.85 } },
		Warehouse = { { Src = "Events", Key = "Rumble", Volume = 0.14, Pitch = 0.5 } },
		Spa = { { Src = "Sounds", Key = "Water", Volume = 0.15, Pitch = 0.8 } },
	},
}
