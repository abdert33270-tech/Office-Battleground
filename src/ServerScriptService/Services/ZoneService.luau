--[[
	ZoneService — zones et décor interactif (tags CollectionService).
	- SlipZone   : flaque glissante -> on glisse et on tombe (sauf Janitor, qui glisse plus vite)
	- DamageZone : attributs Damage (par 0,5 s), Weapon, Owner -> dégâts tant qu'on est dedans
	- HealPickup : attribut Heal -> soigne au contact puis disparaît
	- Breakable  : Model de décor qui éclate (corps éjecté, objet lancé, onde de choc) puis réapparaît après 25 s
	Fabriques : ZoneService.puddle(), .smoke(), .damageZone(), .healPickup()
]]
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Hitbox = require(ReplicatedStorage.Shared.Modules.Hitbox)
local CharacterState = require(script.Parent.CharacterState)

local ZoneService = {}
ZoneService.Priority = 15

local RESTORE_TIME = 25
local FX
local rng = Random.new()

local function zoneFolder()
	local f = workspace:FindFirstChild("Zones")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Zones"
		f.Parent = workspace
	end
	return f
end

local function combat()
	return require(script.Parent.CombatService)
end

------------------------------------------------------------------------
-- Décor cassable
------------------------------------------------------------------------
local broken = {} -- [model] = true pendant qu'il est cassé

function ZoneService.isBreakable(part: Instance): Model?
	local m = part
	while m and m ~= workspace do
		if m:IsA("Model") and CollectionService:HasTag(m, "Breakable") then
			return (not broken[m]) and m or nil
		end
		m = m.Parent
	end
	return nil
end

function ZoneService.shatterModel(model: Model, impulse: Vector3?)
	if broken[model] or not model.Parent then
		return
	end
	broken[model] = true
	impulse = impulse or Vector3.zero
	local saved = {}
	local center = model:GetPivot().Position
	local count = 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			saved[p] = { p.Transparency, p.CanCollide, p.CanQuery }
			if p.Transparency < 1 and count < 14 then
				count += 1
				local d = p:Clone()
				for _, c in ipairs(d:GetChildren()) do
					if not c:IsA("SpecialMesh") then
						c:Destroy()
					end
				end
				CollectionService:RemoveTag(d, "Breakable")
				d.Anchored = false
				d.CanCollide = true
				d.CanQuery = false
				d.CanTouch = false
				d.CollisionGroup = "Debris"
				if d.Size.Magnitude > 4 then
					d.Size = d.Size * 0.6
				end
				d.Parent = workspace.FX
				local out = (d.Position - center)
				out = out.Magnitude > 0.1 and out.Unit or Vector3.yAxis
				d.AssemblyLinearVelocity = out * rng:NextNumber(12, 24) + impulse * 0.35 + Vector3.new(0, rng:NextNumber(16, 30), 0)
				d.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(-14, 14), rng:NextNumber(-14, 14))
				Debris:AddItem(d, 4)
			end
			p.Transparency = 1
			p.CanCollide = false
			p.CanQuery = false
		end
	end
	FX:FireAllClients({ k = "Break", p = center, m = model:GetAttribute("Material") or "Glass", decor = true })
	task.delay(RESTORE_TIME, function()
		for p, v in pairs(saved) do
			if p.Parent then
				p.Transparency, p.CanCollide, p.CanQuery = v[1], v[2], v[3]
			end
		end
		broken[model] = nil
	end)
end

local breakParams = OverlapParams.new()
breakParams.FilterType = Enum.RaycastFilterType.Include
local breakableParts, partsDirty = {}, true

local function refreshBreakables()
	breakableParts = {}
	for _, m in ipairs(CollectionService:GetTagged("Breakable")) do
		if m:IsDescendantOf(workspace) then
			table.insert(breakableParts, m)
		end
	end
	partsDirty = false
end

-- casse tout le décor cassable dans un rayon
function ZoneService.shatterAround(pos: Vector3, radius: number, impulse: Vector3?)
	if partsDirty then
		refreshBreakables()
	end
	if #breakableParts == 0 then
		return
	end
	breakParams.FilterDescendantsInstances = breakableParts
	for _, part in ipairs(workspace:GetPartBoundsInRadius(pos, radius, breakParams)) do
		local m = ZoneService.isBreakable(part)
		if m then
			ZoneService.shatterModel(m, impulse)
		end
	end
end

------------------------------------------------------------------------
-- Fabriques de zones
------------------------------------------------------------------------
local function flatPart(name, pos, radius, color, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.15, radius * 2, radius * 2)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = true
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.Transparency = transparency
	p.Parent = zoneFolder()
	return p
end

local function groundBelow(pos: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { zoneFolder(), workspace.FX, workspace:FindFirstChild("ActiveItems"), workspace:FindFirstChild("Dummies") }
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(ex, pl.Character)
		end
	end
	params.FilterDescendantsInstances = ex
	local r = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), params)
	return r and (r.Position + Vector3.new(0, 0.08, 0)) or pos
end
ZoneService.groundBelow = groundBelow

-- flaque glissante
function ZoneService.puddle(pos: Vector3, radius: number, duration: number, owner: Model?)
	local p = flatPart("Puddle", groundBelow(pos), radius, Color3.fromRGB(90, 180, 255), 0.35)
	if owner then
		p:SetAttribute("Owner", owner.Name)
	end
	CollectionService:AddTag(p, "SlipZone")
	Debris:AddItem(p, duration)
	return p
end

-- nuage de fumée (réduit la visibilité, purement visuel)
function ZoneService.smoke(pos: Vector3, radius: number, duration: number)
	local folder = Instance.new("Model")
	folder.Name = "Smoke"
	for i = 1, 9 do
		local b = Instance.new("Part")
		b.Shape = Enum.PartType.Ball
		local s = rng:NextNumber(radius * 0.7, radius * 1.1)
		b.Size = Vector3.one * s
		b.Position = pos + Vector3.new(rng:NextNumber(-radius, radius) * 0.6, rng:NextNumber(0, radius * 0.6), rng:NextNumber(-radius, radius) * 0.6)
		b.Anchored = true
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.CastShadow = false
		b.Material = Enum.Material.SmoothPlastic
		b.Color = Color3.fromRGB(235, 235, 240)
		b.Transparency = 0.15
		b.Parent = folder
	end
	folder.Parent = zoneFolder()
	task.delay(duration - 1.5, function()
		for _, b in ipairs(folder:GetChildren()) do
			game:GetService("TweenService"):Create(b, TweenInfo.new(1.5), { Transparency = 1 }):Play()
		end
	end)
	Debris:AddItem(folder, duration)
	return folder
end

function ZoneService.damageZone(pos: Vector3, radius: number, duration: number, damage: number, weapon: string, owner: Model?, color: Color3?)
	local p = flatPart("DamageZone", groundBelow(pos), radius, color or Color3.fromRGB(255, 120, 40), 0.4)
	p.Size = Vector3.new(4, radius * 2, radius * 2)
	p:SetAttribute("Damage", damage)
	p:SetAttribute("Weapon", weapon)
	if owner then
		p:SetAttribute("Owner", owner.Name)
		p:SetAttribute("OwnerRef", true)
		ZoneService._owners[p] = owner
	end
	CollectionService:AddTag(p, "DamageZone")
	Debris:AddItem(p, duration)
	return p
end
ZoneService._owners = setmetatable({}, { __mode = "k" })

function ZoneService.healPickup(model: Instance, heal: number)
	model:SetAttribute("Heal", heal)
	CollectionService:AddTag(model, "HealPickup")
end

------------------------------------------------------------------------
-- Boucle : glissades, dégâts de zone, soins
------------------------------------------------------------------------
local zoneParams = OverlapParams.new()
zoneParams.FilterType = Enum.RaycastFilterType.Include
local lastSlip = setmetatable({}, { __mode = "k" })
local lastZap = setmetatable({}, { __mode = "k" })

local function taggedList(tag)
	local list = {}
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		if inst:IsDescendantOf(workspace) then
			table.insert(list, inst)
		end
	end
	return list
end

local function zonesTouching(root: BasePart, list)
	if #list == 0 then
		return {}
	end
	zoneParams.FilterDescendantsInstances = list
	return workspace:GetPartBoundsInBox(root.CFrame * CFrame.new(0, -2, 0), Vector3.new(2.5, 3, 2.5), zoneParams)
end

local function tick()
	local slip = taggedList("SlipZone")
	local dmg = taggedList("DamageZone")
	local heal = taggedList("HealPickup")
	local t = os.clock()
	for _, c in ipairs(Hitbox.characters()) do
		local root = c:FindFirstChild("HumanoidRootPart")
		local hum = c:FindFirstChildOfClass("Humanoid")
		if not root or not hum then
			continue
		end
		local isJanitor = c:GetAttribute("CharacterName") == "Janitor"
		-- flaques
		local inPuddle = #zonesTouching(root, slip) > 0
		if isJanitor then
			CharacterState.setSpeedMod(c, "Zone", inPuddle and 1.45 or nil)
		elseif inPuddle and not CharacterState.isProtected(c) then
			local vel = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
			if vel.Magnitude > 7 and t - (lastSlip[c] or -10) > 2.5 then
				lastSlip[c] = t
				CharacterState.stun(c, 1.0)
				combat().knockback(c, vel.Unit * 34 + Vector3.new(0, 14, 0), true, 1.0, nil, 0.4)
				FX:FireAllClients({ k = "Slip", p = root.Position, v = c })
			end
		end
		-- zones de dégâts
		for _, z in ipairs(zonesTouching(root, dmg)) do
			if t - (lastZap[c] or -10) >= 0.5 then
				local owner = ZoneService._owners[z]
				if owner ~= c then
					lastZap[c] = t
					combat().applyHit({
						attacker = owner, victim = c, damage = z:GetAttribute("Damage") or 5,
						dir = Vector3.new(0, 0, 0.001), knockback = 4, up = 6, stun = 0.3, category = "Light",
						power = 0.3, words = { "ZAP!", "OUCH!", "HOT!" }, weapon = z:GetAttribute("Weapon") or "Zone",
						cause = owner and "Combat" or "Event", unblockable = true,
					})
				end
				break
			end
		end
		-- soins
		for _, part in ipairs(zonesTouching(root, heal)) do
			local m = part:GetAttribute("Heal") and part or part:FindFirstAncestorWhichIsA("Model")
			if m and m.Parent and hum.Health > 0 then
				local amount = m:GetAttribute("Heal") or 20
				hum.Health = math.min(hum.MaxHealth, hum.Health + amount)
				FX:FireAllClients({ k = "Heal", p = root.Position, v = c, d = amount })
				m:Destroy()
			end
			break
		end
	end
end

function ZoneService.init()
	FX = Net.get("FX")
	CollectionService:GetInstanceAddedSignal("Breakable"):Connect(function()
		partsDirty = true
	end)
	CollectionService:GetInstanceRemovedSignal("Breakable"):Connect(function()
		partsDirty = true
	end)
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Model") and CollectionService:HasTag(d, "Breakable") then
			partsDirty = true
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(tick)
			if not ok then
				warn("[ZoneService]", err)
				task.wait(1)
			end
		end
	end)
end

return ZoneService
