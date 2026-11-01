--[[
	Hitbox — requêtes spatiales partagées.
	Côté client : prédiction des effets (réactivité).
	Côté serveur : seule source de vérité pour les dégâts.
]]
local Players = game:GetService("Players")

local Hitbox = {}

-- Tous les personnages vivants (joueurs + mannequins)
function Hitbox.characters(): { Model }
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c then
			local h = c:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 then
				table.insert(list, c)
			end
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		for _, d in ipairs(dummies:GetChildren()) do
			local h = d:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 then
				table.insert(list, d)
			end
		end
	end
	return list
end

-- Renvoie les personnages touchés par une boîte, triés du plus proche au plus loin
function Hitbox.box(cf: CFrame, size: Vector3, exclude: Model?, maxTargets: number?): { Model }
	local include = {}
	for _, c in ipairs(Hitbox.characters()) do
		if c ~= exclude then
			table.insert(include, c)
		end
	end
	if #include == 0 then
		return {}
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	local parts = workspace:GetPartBoundsInBox(cf, size, params)
	local seen, hits = {}, {}
	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		while model and not model:FindFirstChildOfClass("Humanoid") do
			model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
		end
		if model and not seen[model] then
			seen[model] = true
			table.insert(hits, model)
		end
	end
	table.sort(hits, function(a, b)
		local pa, pb = a:GetPivot().Position, b:GetPivot().Position
		return (pa - cf.Position).Magnitude < (pb - cf.Position).Magnitude
	end)
	if maxTargets and #hits > maxTargets then
		for i = #hits, maxTargets + 1, -1 do
			table.remove(hits, i)
		end
	end
	return hits
end

-- CFrame de la hitbox devant un personnage
function Hitbox.frontCFrame(character: Model, offset: number): CFrame?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	return root.CFrame * CFrame.new(0, 0, -offset)
end

return Hitbox
