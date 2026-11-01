--[[
	Tasks — modèles de Daily Tasks (3 tirées par jour UTC et par joueur).
	Kind : "KO" (Weapon optionnel), "KOOnFloor" (Floor), "SurviveEvent" (Event), "Parry",
	       "Combo" (Min), "BreakItem", "SurviveCollapse", "Damage", "Pickup" (Item), "Transform"
	Ajouter une tâche = ajouter une ligne.
]]
return {
	PerDay = 3,
	List = {
		{ Id = "KOChair", Text = "Knock out 3 coworkers with a chair", Kind = "KO", Weapon = "Chair", Goal = 3, XP = 120 },
		{ Id = "KO5", Text = "Fire 5 coworkers", Kind = "KO", Goal = 5, XP = 100 },
		{ Id = "KOStapler", Text = "Knock out 2 coworkers with a Stapler", Kind = "KO", Weapon = "Stapler", Goal = 2, XP = 110 },
		{ Id = "KOCopier", Text = "Flatten a coworker with a Photocopier", Kind = "KO", Weapon = "Photocopier", Goal = 1, XP = 90 },
		{ Id = "SurviveMeeting", Text = "Survive a Surprise Meeting", Kind = "SurviveEvent", Event = "SurpriseMeeting", Goal = 1, XP = 80 },
		{ Id = "SurviveFire", Text = "Survive a Fire Alarm", Kind = "SurviveEvent", Event = "FireAlarm", Goal = 1, XP = 80 },
		{ Id = "Parry10", Text = "Parry 10 attacks", Kind = "Parry", Goal = 10, XP = 120 },
		{ Id = "WinCafeteria", Text = "Win a fight on the Cafeteria floor", Kind = "KOOnFloor", Floor = "Cafeteria", Goal = 1, XP = 80 },
		{ Id = "WinServer", Text = "Win a fight in the Server Room", Kind = "KOOnFloor", Floor = "ServerRoom", Goal = 1, XP = 80 },
		{ Id = "Combo10", Text = "Land a 10-hit combo", Kind = "Combo", Min = 10, Goal = 1, XP = 100 },
		{ Id = "Break5", Text = "Break 5 items", Kind = "BreakItem", Goal = 5, XP = 80 },
		{ Id = "Collapse3", Text = "Survive 3 floor collapses", Kind = "SurviveCollapse", Goal = 3, XP = 90 },
		{ Id = "Damage500", Text = "Deal 500 damage", Kind = "Damage", Goal = 500, XP = 100 },
		{ Id = "Coffee5", Text = "Grab 5 Coffee Mugs", Kind = "Pickup", Item = "CoffeeMug", Goal = 5, XP = 60 },
		{ Id = "Overtime2", Text = "Work Overtime 2 times", Kind = "Transform", Goal = 2, XP = 90 },
	},
}
