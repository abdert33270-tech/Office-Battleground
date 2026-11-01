--[[
	FloorService — étages qui s'effondrent (master prompt §8).
	Cycle : Business -> Events -> Warning -> Collapse -> étage suivant (préchargé 60 studs dessous).
	Le numéro descend (Floor 30 -> 1), puis « NEW BUILDING! » : on repart en haut (Y=0) avec un fondu.
	Modèles d'étage : ServerStorage.Floors.<Nom> (sol = FloorTiles pré-découpées, Decor, ItemSpawns, PlayerSpawns,
	DummySpawns, EventPoints). Durées et pool : Config/Floors. Test rapide : ReplicatedStorage attribut FastFloors = true.

	API (admin) : forceCollapse(nextName?), setNextFloor(name), getFloorNames(), skipPhase(), getCurrent()
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local FloorConfig = require(Shared.Config.Floors)
local Net = require(Shared.Modules.Net)
local World = require(script.Parent.World)
local Signals = require(script.Parent.Signals)
local Announce = require(script.Parent.Announce)
local ItemService = require(script.Parent.ItemService)
local DummyService = require(script.Parent.DummyService)

local FloorService = {}
FloorService.Priority = 30

local building = nil       -- workspace.Building
local current = nil        -- { model, name, number, y }
local upcoming = nil       -- étage préchargé
local forcedNext = nil     -- nom imposé par l'admin
local forced = false       -- effondrement forcé
local skip = false
local FloorFX = nil
local rng = Random.new()

local function eventService()
	local mod = script.Parent:FindFirstChild("EventService")
	if not mod then
		return nil
	end
	local ok, es = pcall(require, mod)
	return ok and es or nil
end

local function durations()
	return ReplicatedStorage:GetAttribute("FastFloors") and FloorConfig.FastDurations or FloorConfig.Durations
end

local function yForNumber(n: number): number
	return -(FloorConfig.StartFloor - n) * FloorConfig.Spacing
end

local function templates()
	return ServerStorage:WaitForChild("Floors")
end

local function pickName(exclude: string?): string
	if forcedNext and templates():FindFirstChild(forcedNext) then
		local n = forcedNext
		forcedNext = nil
		return n
	end
	local pool = {}
	for _, n in ipairs(FloorConfig.Pool) do
		if n ~= exclude and templates():FindFirstChild(n) then
			table.insert(pool, n)
		end
	end
	if #pool == 0 then
		return exclude or FloorConfig.Pool[1]
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function buildFloor(name: string, number: number, y: number)
	local tpl = templates():FindFirstChild(name)
	local m = tpl:Clone()
	m.Name = string.format("Floor%02d_%s", number, name)
	m:PivotTo(CFrame.new(0, y, 0))
	m:SetAttribute("FloorY", y)
	m:SetAttribute("FloorNumber", number)
	m.Parent = building
	local f = { model = m, name = name, number = number, y = y }
	task.spawn(ItemService.spawnFloorItems, m) -- objets déjà en place à l'arrivée
	return f
end

local function applyCurrent()
	World.floorModel = current.model
	World.floorNumber = current.number
	World.floorName = current.name
	ReplicatedStorage:SetAttribute("FloorNumber", current.number)
	ReplicatedStorage:SetAttribute("FloorName", current.name)
	ReplicatedStorage:SetAttribute("FloorDisplay", current.model:GetAttribute("DisplayName") or current.name)
end

local function preloadNext()
	if current.number <= 1 then
		upcoming = buildFloor(pickName(current.name), FloorConfig.StartFloor, 0) -- nouvel immeuble, en haut
	else
		upcoming = buildFloor(pickName(current.name), current.number - 1, yForNumber(current.number - 1))
	end
end

local function setPhase(name: string, dur: number)
	ReplicatedStorage:SetAttribute("Phase", name)
	ReplicatedStorage:SetAttribute("PhaseEndsAt", workspace:GetServerTimeNow() + dur)
end

-- attend dur secondes ; sort plus tôt sur skipPhase() ou forceCollapse()
local function waitPhase(dur: number)
	local t0 = os.clock()
	while os.clock() - t0 < dur do
		if skip then
			skip = false
			return
		end
		if forced then
			return
		end
		task.wait(0.2)
	end
end

local function allCharacters()
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		-- les joueurs en salle AFK (SafeZone) ne participent ni aux effondrements ni aux événements
		if h and h.Health > 0 and c:FindFirstChild("HumanoidRootPart") and c:GetAttribute("SafeZone") ~= true then
			table.insert(list, c)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		for _, d in ipairs(dummies:GetChildren()) do
			local h = d:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 and d:FindFirstChild("HumanoidRootPart") then
				table.insert(list, d)
			end
		end
	end
	return list
end

------------------------------------------------------------------------
-- Warning : fissures, poussière, alarme, bannière
------------------------------------------------------------------------
local function addCrack(tile: BasePart)
	for _ = 1, 2 do
		local c = Instance.new("Part")
		c.Name = "Crack"
		c.Anchored = true
		c.CanCollide = false
		c.CanQuery = false
		c.CanTouch = false
		c.CastShadow = false
		c.Material = Enum.Material.SmoothPlastic
		c.Color = Color3.fromRGB(35, 30, 30)
		c.Size = Vector3.new(rng:NextNumber(6, 14), 0.08, rng:NextNumber(0.35, 0.7))
		c.CFrame = tile.CFrame
			* CFrame.new(rng:NextNumber(-6, 6), tile.Size.Y / 2 + 0.12, rng:NextNumber(-6, 6))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		c.Parent = tile
	end
end

local function doWarning(dur: number)
	local n = current.number
	Announce.banner("FLOOR " .. n .. " IS COLLAPSING!", "Brace yourselves!", FloorConfig.Colors.Warning, math.min(dur, 4), "Big")
	FloorFX:FireAllClients({ k = "Warning", dur = dur, y = current.y })
	Signals.CollapseWarning:Fire(n)
	local tiles = {}
	local folder = current.model:FindFirstChild("FloorTiles")
	if folder then
		tiles = folder:GetChildren()
	end
	local t0 = os.clock()
	while os.clock() - t0 < dur do
		if skip then
			skip = false
			break
		end
		-- fissures de plus en plus nombreuses + dalles qui s'assombrissent
		for _ = 1, 3 do
			local tile = tiles[rng:NextInteger(1, math.max(1, #tiles))]
			if tile and tile:IsA("BasePart") then
				addCrack(tile)
				tile.Color = tile.Color:Lerp(Color3.fromRGB(90, 80, 75), 0.12)
			end
		end
		task.wait(0.35)
	end
end

------------------------------------------------------------------------
-- Collapse
------------------------------------------------------------------------
local function dropOldFloor(old)
	local spread = FloorConfig.TileFallSpread
	local tiles = old.model:FindFirstChild("FloorTiles")
	if tiles then
		for _, tile in ipairs(tiles:GetChildren()) do
			if tile:IsA("BasePart") then
				local dist = Vector3.new(tile.Position.X, 0, tile.Position.Z).Magnitude
				task.delay(rng:NextNumber(0, spread * 0.6) + (1 - math.clamp(dist / 160, 0, 1)) * spread * 0.4, function()
					if tile.Parent then
						for _, c in ipairs(tile:GetChildren()) do
							if c:IsA("BasePart") then
								c:Destroy()
							end
						end
						tile.Anchored = false
						tile.CollisionGroup = "Debris"
						tile.AssemblyLinearVelocity = Vector3.new(0, -8, 0)
						tile.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-2, 2), rng:NextNumber(-3, 3))
					end
				end)
			end
		end
	end
	-- le décor tombe aussi (sans collisions, pour ne pas laguer)
	for _, folderName in ipairs({ "Decor", "EventPoints" }) do
		local folder = old.model:FindFirstChild(folderName)
		if folder then
			for _, p in ipairs(folder:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
					task.delay(rng:NextNumber(0.05, spread), function()
						if p.Parent then
							p.Anchored = false
						end
					end)
				end
			end
		end
	end
end

local function protect(character: Model)
	local ff = character:FindFirstChild("CollapseFF")
	if not ff then
		ff = Instance.new("ForceField")
		ff.Name = "CollapseFF"
		ff.Visible = true
		ff.Parent = character
	end
end

local function unprotect(character: Model)
	local ff = character and character:FindFirstChild("CollapseFF")
	if ff then
		ff:Destroy()
	end
end

local function doCollapse()
	World.collapsing = true
	setPhase("Collapse", 4)
	local es = eventService()
	if es then
		pcall(es.stopAll, false)
	end
	local old = current
	local newBuilding = old.number <= 1
	if not upcoming then
		preloadNext()
	end
	local nextF = upcoming
	upcoming = nil

	local falling = allCharacters()
	for _, c in ipairs(falling) do
		protect(c)
	end
	ItemService.clearGroundItems(old.y - 5, old.y + 40)
	FloorFX:FireAllClients({ k = "Collapse", newBuilding = newBuilding })

	current = nextF
	applyCurrent()
	dropOldFloor(old)

	if newBuilding then
		task.wait(1.0)
		FloorFX:FireAllClients({ k = "Fade", dir = "out" })
		task.wait(0.7)
		for _, c in ipairs(allCharacters()) do
			protect(c)
			c:PivotTo(World.getPlayerSpawn())
			local root = c:FindFirstChild("HumanoidRootPart")
			if root then
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end
		task.wait(0.3)
		FloorFX:FireAllClients({ k = "Fade", dir = "in" })
		Announce.banner("NEW BUILDING!", "Back to the top floor. Clock in!", FloorConfig.Colors.NewBuilding, 3.5, "Big")
	end

	-- atterrissage de chacun : THUD! + 3 s de protection
	local pending = {}
	for _, c in ipairs(falling) do
		pending[c] = true
	end
	local announced = false
	local t0 = os.clock()
	while next(pending) and os.clock() - t0 < 7 do
		for c in pairs(pending) do
			local hum = c:FindFirstChildOfClass("Humanoid")
			local root = c:FindFirstChild("HumanoidRootPart")
			if not c.Parent or not hum or hum.Health <= 0 or not root then
				pending[c] = nil
			elseif root.Position.Y < current.y + 12 and hum.FloorMaterial ~= Enum.Material.Air then
				pending[c] = nil
				FloorFX:FireAllClients({ k = "Land", p = root.Position - Vector3.new(0, 2.8, 0), c = c })
				Signals.SurvivedCollapse:Fire(c)
				task.delay(FloorConfig.LandingProtection, unprotect, c)
				if not announced then
					announced = true
					Announce.banner("FLOOR " .. current.number, current.model:GetAttribute("DisplayName"), current.model:GetAttribute("Palette"), 3, "Floor")
				end
			end
		end
		task.wait(0.05)
	end
	-- coincés quelque part : on les pose sur le nouvel étage
	for c in pairs(pending) do
		if c.Parent then
			c:PivotTo(World.getPlayerSpawn())
			task.delay(FloorConfig.LandingProtection, unprotect, c)
		end
	end
	if not announced then
		Announce.banner("FLOOR " .. current.number, current.model:GetAttribute("DisplayName"), current.model:GetAttribute("Palette"), 3, "Floor")
	end
	-- personnages apparus pendant la chute : enlever une éventuelle protection restante
	for _, c in ipairs(allCharacters()) do
		if c:FindFirstChild("CollapseFF") and not table.find(falling, c) then
			task.delay(FloorConfig.LandingProtection, unprotect, c)
		end
	end

	task.wait(1.2)
	old.model:Destroy()
	World.collapsing = false
	pcall(DummyService.respawn)
	Signals.FloorChanged:Fire(current.number, current.name, current.model)
	preloadNext()
end

------------------------------------------------------------------------
-- Boucle principale
------------------------------------------------------------------------
local function cycle()
	while true do
		local d = durations()
		if not forced then
			setPhase("Business", d.Business)
			waitPhase(d.Business)
		end
		if not forced then
			d = durations()
			setPhase("Events", d.Events)
			local es = eventService()
			if es then
				task.spawn(function()
					pcall(es.runForFloor, current.name, d.Events)
				end)
			end
			waitPhase(d.Events)
		end
		local es = eventService()
		if es then
			pcall(es.stopAll, false)
		end
		d = durations()
		local warnTime = forced and math.min(4, d.Warning) or d.Warning
		forced = false
		setPhase("Warning", warnTime)
		doWarning(warnTime)
		local ok, err = pcall(doCollapse)
		if not ok then
			warn("[FloorService] erreur pendant l'effondrement :", err)
			World.collapsing = false
			if not upcoming then
				pcall(preloadNext)
			end
		end
	end
end

-- chute hors de la map => « resigned »
local function fallWatch()
	while true do
		task.wait(0.5)
		if not World.collapsing and current then
			local limit = current.y - FloorConfig.FallKillMargin
			for _, c in ipairs(allCharacters()) do
				local root = c:FindFirstChild("HumanoidRootPart")
				if root and root.Position.Y < limit then
					local hum = c:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.Health = 0
					end
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- API admin
------------------------------------------------------------------------
function FloorService.getFloorNames()
	return table.clone(FloorConfig.Pool)
end

function FloorService.getCurrent()
	return current
end

function FloorService.setNextFloor(name: string): boolean
	if not templates():FindFirstChild(name) then
		return false
	end
	if upcoming and not World.collapsing then
		if upcoming.name ~= name then
			local old = upcoming
			upcoming = nil
			ItemService.clearGroundItems(old.y - 5, old.y + 40)
			old.model:Destroy()
			forcedNext = name
			preloadNext()
		end
	else
		forcedNext = name
	end
	return true
end

function FloorService.forceCollapse(nextName: string?)
	if nextName then
		FloorService.setNextFloor(nextName)
	end
	forced = true
end

function FloorService.skipPhase()
	skip = true
end

function FloorService.init()
	World.managed = true
	-- FallenPartsDestroyHeight est réglé à -5000 dans la place (non modifiable par script).
	-- Les étages descendent au plus à -(StartFloor-1)*Spacing = -1740, puis NEW BUILDING repart à Y=0.
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		arena:Destroy()
	end
	local preview = workspace:FindFirstChild("_FloorPreview")
	if preview then
		preview:Destroy()
	end
	building = workspace:FindFirstChild("Building") or Instance.new("Folder")
	building.Name = "Building"
	building.Parent = workspace
	FloorFX = Net.get("FloorFX")
	if ReplicatedStorage:GetAttribute("XPMultiplier") == nil then
		ReplicatedStorage:SetAttribute("XPMultiplier", 1)
	end
	current = buildFloor(pickName(nil), FloorConfig.StartFloor, 0)
	applyCurrent()
	setPhase("Business", durations().Business)
	preloadNext()
	task.spawn(cycle)
	task.spawn(fallWatch)
	-- Studio uniquement : attribut ReplicatedStorage "_FloorCmd" = "collapse" | "collapse:<Nom>" | "skip" (tests MCP)
	if game:GetService("RunService"):IsStudio() then
		ReplicatedStorage:GetAttributeChangedSignal("_FloorCmd"):Connect(function()
			local v = ReplicatedStorage:GetAttribute("_FloorCmd")
			if type(v) ~= "string" or v == "" then
				return
			end
			ReplicatedStorage:SetAttribute("_FloorCmd", nil)
			if v == "skip" then
				FloorService.skipPhase()
			elseif v:sub(1, 8) == "collapse" then
				local name = v:match("^collapse:(.+)$")
				FloorService.forceCollapse(name)
			end
		end)
	end
end

return FloorService
