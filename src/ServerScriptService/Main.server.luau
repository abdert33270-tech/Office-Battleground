--[[
	Main — point d'entrée serveur d'Office Battlegrounds.
	Charge AUTOMATIQUEMENT chaque ModuleScript de Services qui expose init().
	Ordre : champ Priority du module (petit = démarre tôt, défaut 50), puis nom.
	Ajouter un système = ajouter un module dans Services (aucune ligne à écrire ici).
	Règle : le haut d'un module ne fait que définir des fonctions ; le travail se fait dans init().
]]
local Services = script.Parent.Services

require(game.ReplicatedStorage.Shared.Modules.Net)

local list = {}
for _, m in ipairs(Services:GetChildren()) do
	if m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if not ok then
			warn("[Main] erreur au chargement de", m.Name, mod)
		elseif type(mod) == "table" and type(mod.init) == "function" then
			table.insert(list, { name = m.Name, mod = mod, p = mod.Priority or 50 })
		end
	end
end
table.sort(list, function(a, b)
	if a.p ~= b.p then
		return a.p < b.p
	end
	return a.name < b.name
end)
for _, e in ipairs(list) do
	local ok, err = pcall(e.mod.init)
	if not ok then
		warn("[Main] erreur dans", e.name .. ".init :", err)
	end
end

print("[Office Battlegrounds] serveur prêt")
