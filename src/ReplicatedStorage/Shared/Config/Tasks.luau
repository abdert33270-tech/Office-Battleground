--[[
	Tasks — Daily Tasks (3 tirées par jour UTC et par joueur) + Weekly Contracts (3 par semaine ISO, lundi 00:00 UTC).
	Kind : "KO" (Weapon optionnel), "KOOnFloor" (Floor), "SurviveEvent" (Event optionnel), "Parry",
	       "Combo" (Min), "BreakItem", "SurviveCollapse", "Damage", "Pickup" (Item optionnel), "Transform",
	       "DailyDone" (tâches du jour terminées : contrats seulement)
	Daily : XP (+ Cash via SkinService, Signals.TaskCompleted). Weekly : Cash + Briefcase (mallettes gratuites).
	RerollsPerDay : relances GRATUITES d'une tâche du jour non finie (remises à zéro avec les tâches).
	Ajouter une tâche = ajouter une ligne.
]]
return {
	PerDay = 3,
	PerWeek = 3,
	RerollsPerDay = 1,
	Weekly = {
		{ Id = "W_KO40", Text = "Fire 40 coworkers", Kind = "KO", Goal = 40, Cash = 600, Crates = 1 },
		{ Id = "W_Damage8k", Text = "Deal 8,000 damage", Kind = "Damage", Goal = 8000, Cash = 500, Crates = 1 },
		{ Id = "W_Parry40", Text = "Parry 40 attacks", Kind = "Parry", Goal = 40, Cash = 500, Crates = 1 },
		{ Id = "W_Daily10", Text = "Finish 10 daily tasks", Kind = "DailyDone", Goal = 10, Cash = 700, Crates = 1 },
		{ Id = "W_Collapse10", Text = "Survive 10 floor collapses", Kind = "SurviveCollapse", Goal = 10, Cash = 500, Crates = 1 },
		{ Id = "W_Event8", Text = "Survive 8 office events", Kind = "SurviveEvent", Goal = 8, Cash = 500, Crates = 1 },
		{ Id = "W_Combo5", Text = "Land five 10-hit combos", Kind = "Combo", Min = 10, Goal = 5, Cash = 600, Crates = 1 },
		{ Id = "W_Overtime10", Text = "Work Overtime 10 times", Kind = "Transform", Goal = 10, Cash = 500, Crates = 1 },
		{ Id = "W_Break25", Text = "Break 25 items", Kind = "BreakItem", Goal = 25, Cash = 450, Crates = 1 },
	},
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
