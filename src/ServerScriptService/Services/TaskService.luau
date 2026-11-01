--[[
	TaskService — Daily Tasks : 3 tâches par jour (UTC) et par joueur, tirées de Config/Tasks.
	Progression via Signals ; récompense en XP ; sauvegardé dans les données de DataService.
	Le client lit l'attribut Player "Tasks" (JSON : {{t=texte, p=progrès, g=objectif, d=fini, x=xp}}).
]]
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TasksConfig = require(ReplicatedStorage.Shared.Config.Tasks)
local Signals = require(script.Parent.Signals)
local Announce = require(script.Parent.Announce)
local DataService = require(script.Parent.DataService)
local World = require(script.Parent.World)

local TaskService = {}
TaskService.Priority = 61

local byId = {}
for _, t in ipairs(TasksConfig.List) do
	byId[t.Id] = t
end

local function today()
	return math.floor(os.time() / 86400)
end

local function norm(s)
	return s and string.lower((string.gsub(tostring(s), "[%s_%-]", ""))) or ""
end

local function sync(player)
	local data = DataService.get(player)
	if not data or not data.Tasks then
		return
	end
	local list = {}
	for _, e in ipairs(data.Tasks.list) do
		local t = byId[e.id]
		if t then
			table.insert(list, { t = t.Text, p = e.p, g = t.Goal, d = e.done, x = t.XP })
		end
	end
	player:SetAttribute("Tasks", HttpService:JSONEncode(list))
end

local function ensure(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local valid = data.Tasks and data.Tasks.day == today()
	if valid then
		for _, e in ipairs(data.Tasks.list) do
			if not byId[e.id] then
				valid = false
			end
		end
	end
	if not valid then
		local rng = Random.new(today() * 7919 + player.UserId)
		local pool = table.clone(TasksConfig.List)
		local list = {}
		for _ = 1, math.min(TasksConfig.PerDay, #pool) do
			local t = table.remove(pool, rng:NextInteger(1, #pool))
			table.insert(list, { id = t.Id, p = 0, done = false })
		end
		data.Tasks = { day = today(), list = list }
	end
	sync(player)
end

-- Fait avancer les tâches d'un joueur. match(t) -> bool ; amount (défaut 1) ; complete = true pour finir d'un coup
local function progress(player, kind, match, amount, complete)
	if not player then
		return
	end
	local data = DataService.get(player)
	if not data or not data.Tasks then
		return
	end
	if data.Tasks.day ~= today() then
		ensure(player)
	end
	local changed = false
	for _, e in ipairs(data.Tasks.list) do
		local t = byId[e.id]
		if t and not e.done and t.Kind == kind and (not match or match(t)) then
			e.p = complete and t.Goal or math.min(t.Goal, e.p + (amount or 1))
			changed = true
			if e.p >= t.Goal then
				e.done = true
				DataService.addXP(player, t.XP)
				Signals.TaskCompleted:Fire(player, t.Id) -- SkinService : +Cash
				Announce.toast(player, "TASK DONE: " .. t.Text .. "  +" .. t.XP .. " XP", Color3.fromRGB(120, 255, 140))
			end
		end
	end
	if changed then
		sync(player)
	end
end
TaskService.progress = progress

local function playerOf(model)
	return model and Players:GetPlayerFromCharacter(model) or nil
end

local function isDummy(model)
	return model and model:GetAttribute("IsDummy") == true
end

function TaskService.init()
	table.insert(DataService.onLoaded, function(player)
		ensure(player)
	end)

	Signals.Died:Connect(function(victim, killer, weapon)
		local player = playerOf(killer)
		if not player or killer == victim or isDummy(victim) then
			return
		end
		progress(player, "KO", function(t)
			return t.Weapon == nil or norm(t.Weapon) == norm(weapon)
		end)
		progress(player, "KOOnFloor", function(t)
			return norm(t.Floor) == norm(World.floorName)
		end)
	end)
	Signals.EventEnded:Connect(function(name)
		for _, p in ipairs(Players:GetPlayers()) do
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				progress(p, "SurviveEvent", function(t)
					return norm(t.Event) == norm(name)
				end)
			end
		end
	end)
	Signals.Parried:Connect(function(defender)
		progress(playerOf(defender), "Parry")
	end)
	Signals.Hit:Connect(function(attacker, victim, damage, info)
		local player = playerOf(attacker)
		if not player or attacker == victim then
			return
		end
		if not isDummy(victim) and type(damage) == "number" then
			progress(player, "Damage", nil, math.floor(damage + 0.5))
		end
		local combo = type(info) == "table" and info.combo or 0
		if combo and combo > 0 then
			progress(player, "Combo", function(t)
				return combo >= (t.Min or 10)
			end, 1, true)
		end
	end)
	-- ItemBroken(itemId, character?) : le 2e argument (porteur / lanceur) est nécessaire pour attribuer la tâche
	Signals.ItemBroken:Connect(function(_, character)
		progress(playerOf(character), "BreakItem")
	end)
	Signals.SurvivedCollapse:Connect(function(character)
		progress(playerOf(character), "SurviveCollapse")
	end)
	Signals.Transformed:Connect(function(character)
		progress(playerOf(character), "Transform")
	end)
	Signals.ItemPickedUp:Connect(function(character, itemId)
		progress(playerOf(character), "Pickup", function(t)
			return norm(t.Item) == norm(itemId)
		end)
	end)
end

return TaskService
