--[[
	Grades — grades de carrière (niveaux). XP = XP totale nécessaire.
	Les grades ne donnent JAMAIS de puissance : seulement un titre et des cosmétiques.
	Seuils abaissés de ~50 % (progression plus rapide) ; niveau numérique 1..100 : Config/Levels.
]]
return {
	List = {
		{ Name = "Trainee", XP = 0, Color = Color3.fromRGB(200, 200, 200) },
		{ Name = "Temp", XP = 75, Color = Color3.fromRGB(170, 230, 170) },
		{ Name = "Employee", XP = 250, Color = Color3.fromRGB(120, 210, 255) },
		{ Name = "Senior", XP = 600, Color = Color3.fromRGB(90, 150, 255) },
		{ Name = "Team Lead", XP = 1250, Color = Color3.fromRGB(180, 120, 255) },
		{ Name = "Manager", XP = 2500, Color = Color3.fromRGB(255, 120, 220) },
		{ Name = "Director", XP = 4500, Color = Color3.fromRGB(255, 170, 60) },
		{ Name = "Vice President", XP = 7500, Color = Color3.fromRGB(255, 90, 70) },
		{ Name = "CEO", XP = 12500, Color = Color3.fromRGB(255, 215, 40) },
	},
	-- XP gagnée
	XPPerDamage = 0.5,      -- 1 XP pour 2 dégâts
	XPPerKO = 25,
	XPSurviveCollapse = 15,
}
