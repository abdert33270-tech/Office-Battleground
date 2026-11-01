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
	DailyCap = 3000,
	ToggleCooldown = 5, -- s entre deux entrées / sorties
	CombatLockout = 8, -- pas d'entrée si touché il y a moins de 8 s
}
