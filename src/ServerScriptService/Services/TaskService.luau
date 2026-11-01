--[[
	TaskService — Daily Tasks + Weekly Contracts + titres de carrière.
	DAILY : 3 tâches par jour (UTC) et par joueur, tirées de Config/Tasks.List ; récompense XP (+ Cash par SkinService
	        via Signals.TaskCompleted). 1 relance GRATUITE par jour (Config/Tasks.RerollsPerDay) d'une tâche non finie.
	WEEKLY : 3 contrats par semaine ISO (lundi 00:00 UTC), tirés de Config/Tasks.Weekly ; récompense Cash + mallettes
	        (SkinService.addCash / addCrates). Signals.WeeklyCompleted(player, id).
	TITRES : Config/Titles (chaque promotion + chaque 10e niveau) ; le meilleur titre débloqué est porté.
	Données (DataService.get(player), champs ajoutés ici avec valeurs par défaut si absents) :
		data.Tasks  = { day, list = {{id, p, done}}, rerolls }
		data.Weekly = { week, list = {{id, p, done}} }
		data.Titles = { [titleId] = os.time() } ; data.Title = titleId porté
	Client (attributs Player) :
		"Tasks"        JSON {{t=texte, p=progrès, g=objectif, d=fini, x=xp}}
		"TasksWeekly"  JSON {{t, p, g, d, c=cash, b=mallettes}}
		"TasksReset" / "TasksWeeklyReset" : os.time() du prochain renouvellement ; "TaskRerolls" : relances restantes
		"Title" (texte) + "TitleColor" (Color3)
	Remote "TaskRequest" (client -> serveur) : ("Reroll", index de la tâche du jour).
	API : TaskService.progress(player, kind, match?, amount?) | TaskService.weekInfo(t?) -> index, "2026-W44", resetAt
]]
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TasksConfig = require(ReplicatedStorage.Shared.Config.Tasks)
local Titles = require(ReplicatedStorage.Shared.Config.Titles)
local Levels = require(ReplicatedStorage.Shared.Config.Levels)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Signals = require(script.Parent.Signals)
local Announce = require(script.Parent.Announce)
local DataService = require(script.Parent.DataService)
local World = require(script.Parent.World)

local TaskService = {}
TaskService.Priority = 61

local DAY = 86400
local GREEN = Color3.fromRGB(120, 255, 140)
local GOLD = Color3.fromRGB(255, 205, 60)

local byId = {}
for _, t in ipairs(TasksConfig.List) do
	byId[t.Id] = t
end
local weeklyById = {}
for _, t in ipairs(TasksConfig.Weekly or {}) do
	weeklyById[t.Id] = t
end

local function today(t: number?)
	return math.floor((t or os.time()) / DAY)
end

-- semaine ISO : lundi 00:00 UTC. Le 1er janvier 1970 (jour 0) était un jeudi => lundi = (jour + 3) % 7 == 0
-- -> index monotone, clé ISO "AAAA-Www" (année ISO = année du jeudi de la semaine), heure de fin
function TaskService.weekInfo(t: number?)
	local d = today(t)
	local monday = d - (d + 3) % 7
	local thursday = monday + 3
	local th = os.date("!*t", thursday * DAY)
	local week = (th.yday - 1) // 7 + 1
	return (d + 3) // 7, string.format("%04d-W%02d", th.year, week), (monday + 7) * DAY
end

local function norm(s)
	return s and string.lower((string.gsub(tostring(s), "[%s_%-]", ""))) or ""
end

local function sync(player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local list = {}
	if type(data.Tasks) == "table" and type(data.Tasks.list) == "table" then
		for _, e in ipairs(data.Tasks.list) do
			local t = byId[e.id]
			if t then
				table.insert(list, { t = t.Text, p = e.p, g = t.Goal, d = e.done, x = t.XP })
			end
		end
	end
	local weekly = {}
	if type(data.Weekly) == "table" and type(data.Weekly.list) == "table" then
		for _, e in ipairs(data.Weekly.list) do
			local t = weeklyById[e.id]
			if t then
				table.insert(weekly, { t = t.Text, p = e.p, g = t.Goal, d = e.done, c = t.Cash or 0, b = t.Crates or 0 })
			end
		end
	end
	local _, _, weekEnds = TaskService.weekInfo()
	player:SetAttribute("Tasks", HttpService:JSONEncode(list))
	player:SetAttribute("TasksWeekly", HttpService:JSONEncode(weekly))
	player:SetAttribute("TasksReset", (today() + 1) * DAY)
	player:SetAttribute("TasksWeeklyReset", weekEnds)
	player:SetAttribute("TaskRerolls", type(data.Tasks) == "table" and tonumber(data.Tasks.rerolls) or 0)
end

local function pick(pool, n, rng, exclude)
	local copy = {}
	for _, t in ipairs(pool) do
		if not (exclude and exclude[t.Id]) then
			table.insert(copy, t)
		end
	end
	local out = {}
	for _ = 1, math.min(n, #copy) do
		local t = table.remove(copy, rng:NextInteger(1, #copy))
		table.insert(out, { id = t.Id, p = 0, done = false })
	end
	return out
end

local function validList(list, ids)
	if type(list) ~= "table" then
		return false
	end
	for _, e in ipairs(list) do
		if type(e) ~= "table" or not ids[e.id] or type(e.p) ~= "number" then
			return false
		end
	end
	return true
end

-- crée / renouvelle les tâches du jour et les contrats de la semaine ; true si quelque chose a changé
local function refresh(player): boolean
	local data = DataService.get(player)
	if not data then
		return false
	end
	local changed = false
	local day = today()
	if not (type(data.Tasks) == "table" and data.Tasks.day == day and validList(data.Tasks.list, byId)) then
		local rng = Random.new(day * 7919 + player.UserId)
		data.Tasks = { day = day, list = pick(TasksConfig.List, TasksConfig.PerDay, rng), rerolls = TasksConfig.RerollsPerDay or 1 }
		changed = true
	elseif type(data.Tasks.rerolls) ~= "number" then
		data.Tasks.rerolls = TasksConfig.RerollsPerDay or 1 -- ancienne sauvegarde du jour
		changed = true
	end
	local week = TaskService.weekInfo()
	if not (type(data.Weekly) == "table" and data.Weekly.week == week and validList(data.Weekly.list, weeklyById)) then
		local rng = Random.new(week * 104729 + player.UserId)
		data.Weekly = { week = week, list = pick(TasksConfig.Weekly or {}, TasksConfig.PerWeek or 3, rng) }
		changed = true
	end
	return changed
end

local function ensure(player)
	refresh(player)
	sync(player)
end

------------------------------------------------------------------------
-- Titres
------------------------------------------------------------------------
local function applyTitle(player, data)
	local t = Titles.get(data.Title)
	player:SetAttribute("Title", t and t.Text or nil)
	player:SetAttribute("TitleColor", t and t.Color or nil)
end

local function updateTitles(player, announce: boolean)
	local data = DataService.get(player)
	if not data then
		return
	end
	if type(data.Titles) ~= "table" then
		data.Titles = {}
	end
	local level = Levels.levelFor(data.XP or 0)
	local gradeIndex = DataService.gradeFor(data.XP or 0)
	local best = Titles.get(data.Title)
	local newest
	for _, id in ipairs(Titles.unlockedFor(level, gradeIndex)) do
		local t = Titles.get(id)
		if not data.Titles[id] then
			data.Titles[id] = os.time()
			newest = t
		end
		if not best or t.Rank > best.Rank then
			best = t
		end
	end
	data.Title = best and best.Id or nil
	applyTitle(player, data)
	if announce and newest then
		Announce.toast(player, "NEW TITLE UNLOCKED: " .. string.upper(newest.Text) .. "!", newest.Color)
	end
end

------------------------------------------------------------------------
-- Progression
------------------------------------------------------------------------
local SkinService
local function skins()
	if SkinService == nil then
		local ok, mod = pcall(require, script.Parent.SkinService)
		SkinService = ok and mod or false
	end
	return SkinService or nil
end

local progress

local function step(list, cfg, kind, match, amount, onDone)
	local changed = false
	for _, e in ipairs(list) do
		local t = cfg[e.id]
		if t and not e.done and t.Kind == kind and (not match or match(t)) then
			e.p = math.min(t.Goal, e.p + (amount or 1))
			changed = true
			if e.p >= t.Goal then
				e.done = true
				onDone(t)
			end
		end
	end
	return changed
end

-- Fait avancer les tâches et contrats d'un joueur. match(t) -> bool ; amount (défaut 1)
progress = function(player, kind, match, amount)
	if not player then
		return
	end
	local data = DataService.get(player)
	if not data then
		return
	end
	local renewed = refresh(player)
	local dailyDone = 0
	local a = step(data.Tasks.list, byId, kind, match, amount, function(t)
		dailyDone += 1
		DataService.addXP(player, t.XP)
		Signals.TaskCompleted:Fire(player, t.Id) -- SkinService : +Cash
		Announce.toast(player, "TASK DONE: " .. t.Text .. "  +" .. t.XP .. " XP", GREEN)
	end)
	local b = step(data.Weekly.list, weeklyById, kind, match, amount, function(t)
		local S = skins()
		if S then
			if (t.Cash or 0) > 0 then
				S.addCash(player, t.Cash, "CONTRACT")
			end
			if (t.Crates or 0) > 0 then
				S.addCrates(player, t.Crates)
			end
		end
		Signals.WeeklyCompleted:Fire(player, t.Id)
		Announce.toast(player, "CONTRACT DONE: " .. t.Text .. "  +$" .. (t.Cash or 0) .. ((t.Crates or 0) > 0 and (" + " .. t.Crates .. " BRIEFCASE") or ""), GOLD)
	end)
	if renewed or a or b then
		sync(player)
	end
	if dailyDone > 0 then
		task.defer(progress, player, "DailyDone", nil, dailyDone)
	end
end
TaskService.progress = progress

-- relance gratuite d'une tâche du jour non finie (nouvelle tâche absente de la liste)
local function reroll(player, index)
	local data = DataService.get(player)
	if not data or type(index) ~= "number" then
		return
	end
	refresh(player)
	local T = data.Tasks
	local e = T.list[math.floor(index)]
	if not e or e.done or (tonumber(T.rerolls) or 0) <= 0 then
		sync(player)
		return
	end
	local exclude = {}
	for _, x in ipairs(T.list) do
		exclude[x.id] = true
	end
	local fresh = pick(TasksConfig.List, 1, Random.new(), exclude)[1]
	if not fresh then
		sync(player)
		return
	end
	T.list[math.floor(index)] = fresh
	T.rerolls -= 1
	Announce.toast(player, "New task: " .. byId[fresh.id].Text, GREEN)
	sync(player)
end

local function playerOf(model)
	return model and Players:GetPlayerFromCharacter(model) or nil
end

local function isDummy(model)
	return model and model:GetAttribute("IsDummy") == true
end

function TaskService.init()
	DataService.whenLoaded(function(player)
		ensure(player)
		updateTitles(player, false)
	end)
	Signals.LevelUp:Connect(function(player)
		updateTitles(player, true)
	end)
	Signals.GradeUp:Connect(function(player)
		updateTitles(player, true)
	end)

	local remote = Net.get("TaskRequest")
	remote.OnServerEvent:Connect(function(player, op, a)
		if not Net.allow(player, "TaskRequest", 2) then
			return
		end
		if op == "Reroll" then
			reroll(player, a)
		end
	end)

	-- minuit UTC / lundi : renouvelle sans attendre une action du joueur
	task.spawn(function()
		while true do
			task.wait(30)
			for _, p in ipairs(Players:GetPlayers()) do
				if refresh(p) then
					sync(p)
				end
			end
		end
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
			return t.Floor == nil or norm(t.Floor) == norm(World.floorName)
		end)
	end)
	Signals.EventEnded:Connect(function(name)
		for _, p in ipairs(Players:GetPlayers()) do
			local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				progress(p, "SurviveEvent", function(t)
					return t.Event == nil or norm(t.Event) == norm(name)
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
		-- un combo compte une fois : au coup qui atteint exactement le seuil
		local combo = type(info) == "table" and tonumber(info.combo) or 0
		if combo and combo > 0 and not isDummy(victim) then
			progress(player, "Combo", function(t)
				return combo == (t.Min or 10)
			end)
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
			return t.Item == nil or norm(t.Item) == norm(itemId)
		end)
	end)
end

return TaskService
