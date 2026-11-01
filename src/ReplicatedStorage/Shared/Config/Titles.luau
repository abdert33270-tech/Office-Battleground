--[[
	Titles — titres de carrière (cosmétique pur : JAMAIS de puissance).
	Débloqués par TaskService : chaque PROMOTION (grade de Config/Grades) et chaque 10e niveau (Config/Levels).
	Le titre le plus récent/élevé est porté automatiquement : attribut Player "Title" (texte) + "TitleColor" (Color3).
	Affiché dans la liste des joueurs (PlayerListController) et le kill feed (HUDController, via l'attribut).
	Sauvegarde : data.Titles = {[id] = os.time()} (débloqués), data.Title = id porté.
	API : Titles.List (ordre = rang, du plus bas au plus haut) | Titles.get(id) | Titles.unlockedFor(level, gradeIndex) -> {ids}
]]
local Titles = {}

-- Rank : plus grand = plus prestigieux (le titre porté = meilleur rang débloqué)
Titles.List = {
	{ Id = "G_Temp", Text = "Clipboard Carrier", Grade = 2, Color = Color3.fromRGB(170, 230, 170) },
	{ Id = "L10", Text = "Coffee Runner", Level = 10, Color = Color3.fromRGB(200, 150, 100) },
	{ Id = "G_Employee", Text = "Badge Holder", Grade = 3, Color = Color3.fromRGB(120, 210, 255) },
	{ Id = "L20", Text = "Spreadsheet Slayer", Level = 20, Color = Color3.fromRGB(110, 230, 120) },
	{ Id = "G_Senior", Text = "Senior Brawler", Grade = 4, Color = Color3.fromRGB(90, 150, 255) },
	{ Id = "L30", Text = "Stapler Sniper", Level = 30, Color = Color3.fromRGB(255, 120, 120) },
	{ Id = "G_TeamLead", Text = "Team Wrecker", Grade = 5, Color = Color3.fromRGB(180, 120, 255) },
	{ Id = "L40", Text = "Meeting Survivor", Level = 40, Color = Color3.fromRGB(255, 200, 90) },
	{ Id = "G_Manager", Text = "Middle Manager", Grade = 6, Color = Color3.fromRGB(255, 120, 220) },
	{ Id = "L50", Text = "Overtime Legend", Level = 50, Color = Color3.fromRGB(255, 140, 30) },
	{ Id = "G_Director", Text = "Corner Office", Grade = 7, Color = Color3.fromRGB(255, 170, 60) },
	{ Id = "L60", Text = "Printer Whisperer", Level = 60, Color = Color3.fromRGB(80, 215, 255) },
	{ Id = "L70", Text = "Golden Parachute", Level = 70, Color = Color3.fromRGB(255, 214, 50) },
	{ Id = "G_VP", Text = "Vice President of Pain", Grade = 8, Color = Color3.fromRGB(255, 90, 70) },
	{ Id = "L80", Text = "Board Member", Level = 80, Color = Color3.fromRGB(200, 160, 255) },
	{ Id = "L90", Text = "Office Myth", Level = 90, Color = Color3.fromRGB(255, 95, 200) },
	{ Id = "G_CEO", Text = "The Big Boss", Grade = 9, Color = Color3.fromRGB(255, 215, 40) },
	{ Id = "L100", Text = "Employee of the Century", Level = 100, Color = Color3.fromRGB(255, 240, 120) },
}

local byId = {}
for i, t in ipairs(Titles.List) do
	t.Rank = i
	byId[t.Id] = t
end

function Titles.get(id)
	return id and byId[id] or nil
end

-- titres mérités pour un niveau et un index de grade (Config/Grades.List) donnés
function Titles.unlockedFor(level: number, gradeIndex: number)
	local out = {}
	for _, t in ipairs(Titles.List) do
		if (t.Level and level >= t.Level) or (t.Grade and gradeIndex >= t.Grade) then
			table.insert(out, t.Id)
		end
	end
	return out
end

return Titles
