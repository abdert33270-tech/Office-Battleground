--[[
	World — état du monde partagé entre services.
	FloorService remplace floorModel à chaque étage et met managed = true.
	Un étage (ou workspace.Arena) contient : PlayerSpawns, DummySpawns, ItemSpawns (Parts invisibles).
]]
local World = {
	managed = false,      -- true quand FloorService gère les étages
	floorModel = nil,     -- étage actuel (Model/Folder)
	floorNumber = 30,
	floorName = "OpenSpace",
	collapsing = false,   -- pendant la chute (pas de "resigned")
}

function World.current()
	return World.floorModel or workspace:FindFirstChild("Arena")
end

local function pickFrom(folderName: string): CFrame?
	local floor = World.current()
	local folder = floor and floor:FindFirstChild(folderName, true)
	local list = {}
	if folder then
		for _, p in ipairs(folder:GetChildren()) do
			if p:IsA("BasePart") then
				table.insert(list, p)
			end
		end
	end
	if #list == 0 then
		return nil
	end
	local p = list[math.random(#list)]
	return CFrame.new(p.Position + Vector3.new(0, 3, 0)) * (p.CFrame - p.Position)
end

function World.getPlayerSpawn(): CFrame
	return pickFrom("PlayerSpawns") or CFrame.new(0, 6, 0)
end

function World.getDummySpawn(): CFrame?
	return pickFrom("DummySpawns")
end

-- Hauteur du sol de l'étage actuel (pour détecter les chutes hors map)
function World.getFloorY(): number
	local floor = World.current()
	if floor and floor:GetAttribute("FloorY") then
		return floor:GetAttribute("FloorY")
	end
	return 0
end

return World
