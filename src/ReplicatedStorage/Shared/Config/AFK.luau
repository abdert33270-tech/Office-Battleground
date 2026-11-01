--[[
	AFK — salle de pause « AFK BREAK ROOM » (AFKService / AFKController).
	Zone sûre loin de l'arène : attribut SafeZone = true sur le perso (CombatService ignore les dégâts).
	Paie : PayAmount Cash toutes les PayInterval s, + BonusAmount toutes les BonusEvery s sans sortir.
	DailyCap : plafond de Cash AFK par jour UTC (0 = pas de plafond).
]]
return {
	Origin = Vector3.new(2600, 400, 2600), -- centre du sol de la salle (loin des étages : X/Z ±110, Y 0 à -1 800)
	PayInterval = 60,
	PayAmount = 25,
	BonusEvery = 600,
	BonusAmount = 100,
	DailyCap = 1500, -- 25/min + 100/10 min = 175 Cash / 10 min => plafond atteint en ~1 h 25 de pause
	ToggleCooldown = 5, -- s entre deux entrées / sorties
	CombatLockout = 8, -- pas d'entrée si touché OU si on a frappé / bloqué / paré il y a moins de 8 s
	-- anti-expulsion (Roblox expulse après 20 min sans entrée) : si l'astuce VirtualUser ne marche pas, le client
	-- demande au bout de RejoinIdle s d'inactivité une reconnexion (TeleportService) qui le remet dans la salle
	RejoinIdle = 17 * 60,
	RejoinCooldown = 600, -- s : au plus une reconnexion AFK par joueur et par serveur toutes les 10 min
	RejoinAutoEnterTimeout = 45, -- s : à l'arrivée, délai max pour remettre le joueur dans la salle
	-- ambiance sonore calme de la salle (AmbienceController, même format que Config/Floors.Ambience)
	Ambience = {
		{ Src = "Events", Key = "Lullaby", Volume = 0.06, Pitch = 0.9 }, -- boîte à musique douce, plus grave
	},
}
