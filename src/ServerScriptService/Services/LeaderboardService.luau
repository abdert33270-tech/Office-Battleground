--[[
	LeaderboardService — classements mondiaux (OrderedDataStore) : XP totale (= niveau), K.O. totaux, K.O. de la semaine.
	- Toutes les 120 s : écrit les valeurs des joueurs présents (seulement si elles ont changé) puis relit le top 50
	  de chaque tableau (GetSortedAsync(false, 50) -> 1re page). Écriture aussi au départ d'un joueur.
	- Prudent : chaque appel en pcall, budget vérifié avant (GetRequestBudgetForRequestType), une réserve est laissée.
	- Semaine = semaine ISO (lundi 00:00 UTC, TaskService.weekInfo) : un OrderedDataStore par semaine
	  ("OB_LB_WeekKOs_v1_2026-W44"). Compteur : data.WeekKOs = { week = index, n = K.O. } (ajouté si absent).
	- Studio sans accès API / place non publiée : mode hors ligne (online = false + raison) ; le client affiche alors
	  un texte d'explication et le classement de CE serveur (toujours envoyé).
	Remote "Leaderboard" : client -> "Get" ; serveur -> payload
		{ online, reason?, week, weekEnds, updated, boards = {Level, KOs, Weekly}, server = {Level, KOs, Weekly} }
		entrée = { rank, userId, name, value }  (Level : value = XP totale, le client en déduit le niveau)
]]
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Signals = require(script.Parent.Signals)
local DataService = require(script.Parent.DataService)
local TaskService = require(script.Parent.TaskService)

local LeaderboardService = {}
LeaderboardService.Priority = 63

local INTERVAL = 120
local FIRST_DELAY = 20
local TOP = 50
local WRITE_RESERVE = 6 -- requêtes laissées aux autres systèmes
local READ_RESERVE = 1
local STORE = { Level = "OB_LB_XP_v1", KOs = "OB_LB_KOs_v1", Weekly = "OB_LB_WeekKOs_v1_" }
local BOARDS = { "Level", "KOs", "Weekly" }

local online = nil -- nil = pas encore testé, false = hors ligne
local offlineReason = nil
local stores = {}
local written = {} -- ["store|userId"] = dernière valeur écrite
local known = {} -- [userId] = { Level, KOs, Weekly, week } (gardé pour l'écriture au départ)
local names = {} -- [userId] = nom affiché
local cache = { boards = { Level = {}, KOs = {}, Weekly = {} }, updated = 0, week = "" }
local remote

local function isDummy(model)
	return model and model:GetAttribute("IsDummy") == true
end

local function markOffline(err)
	local msg = tostring(err)
	-- Studio sans « Enable Studio Access to API Services », place jamais publiée, service coupé
	if string.find(msg, "Studio", 1, true) or string.find(msg, "publish", 1, true) or string.find(msg, "403", 1, true) then
		online = false
		offlineReason = "Global leaderboards are offline here (Studio without API access or unpublished place)."
		warn("[Leaderboard] hors ligne : " .. msg)
		return true
	end
	warn("[Leaderboard] " .. msg)
	return false
end

local function budget(kind): number
	local ok, n = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType(kind)
	end)
	return ok and tonumber(n) or 0
end

local function storeFor(name: string)
	if stores[name] then
		return stores[name]
	end
	local ok, s = pcall(function()
		return DataStoreService:GetOrderedDataStore(name)
	end)
	if not ok then
		markOffline(s)
		return nil
	end
	stores[name] = s
	return s
end

local function storeName(board: string, weekKey: string): string
	return board == "Weekly" and (STORE.Weekly .. weekKey) or STORE[board]
end

-- semaine en cours pour les K.O. hebdomadaires (remise à zéro au changement de semaine ISO)
local function weekCounter(data)
	local week = TaskService.weekInfo()
	if type(data.WeekKOs) ~= "table" or data.WeekKOs.week ~= week or type(data.WeekKOs.n) ~= "number" then
		data.WeekKOs = { week = week, n = 0 }
	end
	return data.WeekKOs
end

local function snapshot(player)
	local data = DataService.get(player)
	if not data then
		return known[player.UserId]
	end
	local _, weekKey = TaskService.weekInfo()
	local e = {
		Level = math.max(0, math.floor(tonumber(data.XP) or 0)),
		KOs = math.max(0, math.floor(tonumber(data.KOs) or 0)),
		Weekly = weekCounter(data).n,
		week = weekKey,
	}
	known[player.UserId] = e
	names[player.UserId] = player.DisplayName
	return e
end

-- écrit les valeurs d'un joueur (seulement ce qui a changé) ; false si le budget manque
local function writePlayer(userId: number, e): boolean
	if online == false or not e then
		return true
	end
	for _, board in ipairs(BOARDS) do
		local value = e[board]
		local name = storeName(board, e.week)
		local k = name .. "|" .. userId
		if value and value > 0 and written[k] ~= value then
			if budget(Enum.DataStoreRequestType.SetIncrementSortedAsync) <= WRITE_RESERVE then
				return false
			end
			local s = storeFor(name)
			if not s then
				return true
			end
			local ok, err = pcall(function()
				s:SetAsync("u_" .. userId, value)
			end)
			if ok then
				written[k] = value
				online = true
			elseif markOffline(err) then
				return true
			end
		end
	end
	return true
end

local function resolveNames(ids)
	local missing = {}
	for _, id in ipairs(ids) do
		if not names[id] then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then
		return
	end
	local ok, infos = pcall(function()
		return game:GetService("UserService"):GetUserInfosByUserIdsAsync(missing)
	end)
	if ok and type(infos) == "table" then
		for _, info in ipairs(infos) do
			if type(info) == "table" and info.Id then
				names[info.Id] = info.DisplayName or info.Username
			end
		end
	end
	for _, id in ipairs(missing) do
		if not names[id] then
			local ok2, n = pcall(function()
				return Players:GetNameFromUserIdAsync(id)
			end)
			names[id] = ok2 and n or ("Player " .. id)
		end
	end
end

local function readBoard(board: string, weekKey: string)
	if online == false then
		return nil
	end
	if budget(Enum.DataStoreRequestType.GetSortedAsync) <= READ_RESERVE then
		return nil
	end
	local s = storeFor(storeName(board, weekKey))
	if not s then
		return nil
	end
	-- 1re page seulement = top 50 (pageSize max 100) ; entrées { key = "u_123", value = 4567 }
	local ok, page = pcall(function()
		return s:GetSortedAsync(false, TOP):GetCurrentPage()
	end)
	if not ok then
		markOffline(page)
		return nil
	end
	online = true
	local out, ids = {}, {}
	for i, entry in ipairs(page) do
		local id = tonumber(string.match(tostring(entry.key), "^u_(%d+)$"))
		if id then
			table.insert(out, { rank = i, userId = id, value = tonumber(entry.value) or 0 })
			table.insert(ids, id)
		end
	end
	resolveNames(ids)
	for _, e in ipairs(out) do
		e.name = names[e.userId] or ("Player " .. e.userId)
	end
	return out
end

-- classement des joueurs présents (toujours disponible, même hors ligne)
local function serverBoards()
	local rows = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local e = snapshot(p)
		if e then
			table.insert(rows, { userId = p.UserId, name = p.DisplayName, e = e })
		end
	end
	local out = {}
	for _, board in ipairs(BOARDS) do
		table.sort(rows, function(a, b)
			if a.e[board] ~= b.e[board] then
				return a.e[board] > b.e[board]
			end
			return a.userId < b.userId
		end)
		local list = {}
		for i, r in ipairs(rows) do
			list[i] = { rank = i, userId = r.userId, name = r.name, value = r.e[board] }
		end
		out[board] = list
	end
	return out
end

local function payload()
	local _, weekKey, weekEnds = TaskService.weekInfo()
	return {
		online = online ~= false and cache.updated > 0,
		pending = online ~= false and cache.updated == 0,
		reason = online == false and offlineReason or nil,
		week = weekKey,
		weekEnds = weekEnds,
		updated = cache.updated,
		boards = cache.week == weekKey and cache.boards or { Level = cache.boards.Level, KOs = cache.boards.KOs, Weekly = {} },
		server = serverBoards(),
	}
end

local function cycle()
	for _, p in ipairs(Players:GetPlayers()) do
		if not writePlayer(p.UserId, snapshot(p)) then
			break -- budget épuisé : la suite au prochain tour
		end
		task.wait(0.1)
	end
	if online == false then
		return
	end
	local _, weekKey = TaskService.weekInfo()
	local fresh = {}
	for _, board in ipairs(BOARDS) do
		fresh[board] = readBoard(board, weekKey)
		task.wait(0.2)
	end
	local any = false
	for _, board in ipairs(BOARDS) do
		if fresh[board] then
			cache.boards[board] = fresh[board]
			any = true
		elseif board == "Weekly" and cache.week ~= weekKey then
			cache.boards.Weekly = {}
		end
	end
	if any then
		cache.updated = os.time()
		cache.week = weekKey
	end
end

function LeaderboardService.init()
	remote = Net.get("Leaderboard")
	remote.OnServerEvent:Connect(function(player, op)
		if op ~= "Get" or not Net.allow(player, "Leaderboard", 1) then
			return
		end
		remote:FireClient(player, payload())
	end)

	Signals.Died:Connect(function(victim, killer)
		local player = killer and Players:GetPlayerFromCharacter(killer)
		if not player or killer == victim or isDummy(victim) then
			return
		end
		local data = DataService.get(player)
		if data then
			local w = weekCounter(data)
			w.n += 1
		end
	end)

	Players.PlayerAdded:Connect(function(p)
		names[p.UserId] = p.DisplayName
	end)
	Players.PlayerRemoving:Connect(function(p)
		local e = snapshot(p) -- profil peut-être déjà retiré par DataService : repli sur la dernière photo
		known[p.UserId] = nil
		task.spawn(writePlayer, p.UserId, e)
	end)

	task.spawn(function()
		task.wait(FIRST_DELAY)
		while true do
			local ok, err = pcall(cycle)
			if not ok then
				warn("[Leaderboard] " .. tostring(err))
			end
			task.wait(INTERVAL)
		end
	end)
end

return LeaderboardService
