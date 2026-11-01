--[[
	DummyService — UN mannequin « Coworker » pour s'entraîner.
	Apparaît sur DummySpawns de l'étage actuel (World), réapparaît 4 s après le K.O.
	FloorService appelle DummyService.respawn() à chaque nouvel étage.
]]
local CharacterState = require(script.Parent.CharacterState)
local Ragdoll = require(script.Parent.Ragdoll)
local RigBuilder = require(script.Parent.RigBuilder)
local World = require(script.Parent.World)

local DummyService = {}
DummyService.Priority = 85
DummyService.enabled = true

local current = nil

local function spawnDummy()
	if not DummyService.enabled then
		return
	end
	local cf = World.getDummySpawn() or (World.getPlayerSpawn() * CFrame.new(0, 0, -8))
	local dummy = RigBuilder.r6("Coworker", {
		Shirt = Color3.fromRGB(150, 200, 255),
		Tie = Color3.fromRGB(220, 50, 50),
	})
	dummy:PivotTo(cf * CFrame.Angles(0, math.rad(math.random(0, 359)), 0))
	dummy.Parent = workspace.Dummies
	CharacterState.setup(dummy)
	dummy:SetAttribute("IsDummy", true)
	for _, p in ipairs(dummy:GetChildren()) do
		if p:IsA("BasePart") then
			p:SetNetworkOwner(nil)
		end
	end
	current = dummy
	local hum = dummy:FindFirstChildOfClass("Humanoid")
	hum.Died:Connect(function()
		Ragdoll.apply(dummy, dummy:GetAttribute("KOLaunch"))
		task.delay(4, function()
			dummy:Destroy()
			if current == dummy then
				current = nil
				spawnDummy()
			end
		end)
	end)
end

-- (ré)place le mannequin sur l'étage actuel
function DummyService.respawn()
	if current then
		local old = current
		current = nil
		old:Destroy()
	end
	spawnDummy()
end

function DummyService.init()
	workspace.Dummies:ClearAllChildren()
	task.defer(function()
		-- évite le mannequin qui flotte au-dessus d'un étage pas encore chargé
		local t0 = os.clock()
		while not World.floorModel and os.clock() - t0 < 15 do
			task.wait(0.2)
		end
		if not current then
			spawnDummy()
		end
	end)
end

return DummyService
