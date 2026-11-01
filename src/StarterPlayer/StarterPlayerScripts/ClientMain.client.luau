--[[
	ClientMain — point d'entrée client d'Office Battlegrounds.
]]
--	Charge AUTOMATIQUEMENT chaque ModuleScript de Controllers qui expose init(ctx).
--	ctx = table de tous les contrôleurs par nom (ctx.CombatController, ctx.HUDController...).
--	Ordre : champ Priority (défaut 50), puis nom.
local Controllers = script.Parent:WaitForChild("Controllers")
task.wait() -- laisse répliquer tous les modules

local ctx, list = {}, {}
for _, m in ipairs(Controllers:GetChildren()) do
	if m:IsA("ModuleScript") then
		local ok, mod = pcall(require, m)
		if not ok then
			warn("[ClientMain] erreur au chargement de", m.Name, mod)
		elseif type(mod) == "table" then
			ctx[m.Name] = mod
			if type(mod.init) == "function" then
				table.insert(list, { name = m.Name, mod = mod, p = mod.Priority or 50 })
			end
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
	local ok, err = pcall(e.mod.init, ctx)
	if not ok then
		warn("[ClientMain] erreur dans", e.name .. ".init :", err)
	end
end

print("[Office Battlegrounds] client prêt")
