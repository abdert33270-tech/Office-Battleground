--[[
	DailyRewardService — calendrier de connexion 7 jours (Config/DailyRewards), 100 % serveur (os.time()).
	- Une réclamation par jour UTC (jour = os.time() // 86400).
	- Plus de GraceHours (48 h) depuis la dernière réclamation => série perdue, retour au jour 1.
	- Après le jour 7 : nouveau cycle.
	Données (DataService, sauvegardées) : data.Daily = { Streak (0-7, dernier jour réclamé du cycle), LastDay, LastClaim, Total }.
	Attribut Player : DailyClaimable (bool) -> pastille rouge du bouton DAILY.
	Remote "DailyReward" :
		client -> serveur : "State" | "Claim"
		serveur -> client : state = { day, claimed, claimable, nextAt?, expiresAt?, lost, total, now, result? }
			day = jour à réclamer (1-7) ; claimed = cases déjà cochées dans le cycle affiché
			result (après un Claim réussi) = { day, Cash, Crates }
	API : DailyRewardService.getState(player) | claim(player) | reset(player, full?) (admin /resetdaily)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config.DailyRewards)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local DataService = require(script.Parent.DataService)
local Announce = require(script.Parent.Announce)

local DailyRewardService = {}
DailyRewardService.Priority = 66 -- après DataService (60) et SkinService (62)

local DAY = 86400
local remote

local function today(): number
	return os.time() // DAY
end

local function skinService()
	local ok, mod = pcall(require, script.Parent.SkinService)
	return ok and mod or nil
end

local function dailyOf(player)
	local d = DataService.get(player)
	if not d then
		return nil
	end
	if type(d.Daily) ~= "table" then
		d.Daily = {}
	end
	return d.Daily
end

-- état calculé (ne modifie rien)
local function compute(daily)
	local n = #Config.Days
	local now = os.time()
	local streak = math.clamp(math.floor(tonumber(daily.Streak) or 0), 0, n)
	local lastDay = tonumber(daily.LastDay) or -1
	local lastClaim = tonumber(daily.LastClaim) or 0
	local lost = false
	if lastClaim <= 0 then
		streak = 0
	elseif now - lastClaim > Config.GraceHours * 3600 then
		lost = streak > 0
		streak = 0
	end
	local claimable = today() > lastDay
	local day, claimed
	if claimable then
		day = (streak % n) + 1
		claimed = day - 1
	else
		day = (streak % n) + 1 -- prochain jour (demain)
		claimed = streak
	end
	return {
		day = day,
		claimed = claimed,
		streak = streak,
		claimable = claimable,
		lost = lost,
		nextAt = (not claimable) and (today() + 1) * DAY or nil,
		expiresAt = (streak > 0 and lastClaim > 0) and (lastClaim + Config.GraceHours * 3600) or nil,
		total = tonumber(daily.Total) or 0,
		now = now,
	}
end

function DailyRewardService.getState(player: Player)
	local daily = dailyOf(player)
	if not daily then
		return nil
	end
	return compute(daily)
end

local function push(player, result)
	local st = DailyRewardService.getState(player)
	if not st then
		return
	end
	player:SetAttribute("DailyClaimable", st.claimable)
	if remote and player.Parent then
		st.result = result
		remote:FireClient(player, st)
	end
end
DailyRewardService.push = push

function DailyRewardService.claim(player: Player)
	local daily = dailyOf(player)
	if not daily then
		return false, "Data not loaded yet"
	end
	local st = compute(daily)
	if not st.claimable then
		return false, "Already claimed today"
	end
	local reward = Config.Days[st.day]
	if not reward then
		return false, "Invalid day"
	end
	daily.Streak = st.day
	daily.LastDay = today()
	daily.LastClaim = os.time()
	daily.Total = (tonumber(daily.Total) or 0) + 1
	local ss = skinService()
	local cash = math.floor(tonumber(reward.Cash) or 0)
	local crates = math.floor(tonumber(reward.Crates) or 0)
	if cash > 0 then
		if ss and ss.addCash then
			ss.addCash(player, cash, "DAILY DAY " .. st.day)
		else
			local d = DataService.get(player)
			d.Cash = (d.Cash or 0) + cash
			player:SetAttribute("Cash", d.Cash)
		end
	end
	if crates > 0 then
		if ss and ss.addCrates then
			ss.addCrates(player, crates)
		else
			local d = DataService.get(player)
			d.Crates = (d.Crates or 0) + crates
			player:SetAttribute("Crates", d.Crates)
		end
	end
	if reward.Big then
		Net.get("Banner"):FireClient(player, {
			text = "DAY " .. st.day .. " JACKPOT!",
			sub = "+" .. cash .. " Cash" .. (crates > 0 and ("  +" .. crates .. " Mystery Briefcase" .. (crates > 1 and "s" or "")) or ""),
			color = Color3.fromRGB(255, 196, 40),
			duration = 3.5,
			style = "Big",
		})
	else
		Announce.toast(player, "Daily reward claimed! Come back tomorrow for day " .. ((st.day % #Config.Days) + 1) .. ".", Color3.fromRGB(110, 235, 120))
	end
	push(player, { day = st.day, Cash = cash, Crates = crates })
	return true
end

-- admin / tests : full = remet tout à zéro, sinon permet de réclamer à nouveau aujourd'hui (série gardée)
function DailyRewardService.reset(player: Player, full: boolean?)
	local d = DataService.get(player)
	if not d then
		return false
	end
	if full or type(d.Daily) ~= "table" then
		d.Daily = {}
	else
		d.Daily.LastDay = today() - 1
		if (tonumber(d.Daily.LastClaim) or 0) > 0 then
			d.Daily.LastClaim = os.time() - DAY
		end
	end
	push(player)
	return true
end

function DailyRewardService.init()
	remote = Net.get("DailyReward")
	remote.OnServerEvent:Connect(function(player, op)
		if not Net.allow(player, "DailyReward", 3) then
			return
		end
		if op == "Claim" then
			local ok, err = DailyRewardService.claim(player)
			if not ok then
				Announce.toast(player, err or "Can't claim right now", Color3.fromRGB(255, 110, 90))
				push(player)
			end
		else
			push(player)
		end
	end)

	DataService.whenLoaded(function(player)
		push(player)
	end)

	-- passage de minuit UTC : la pastille se rallume sans reconnexion
	task.spawn(function()
		while true do
			task.wait(30)
			for _, p in ipairs(Players:GetPlayers()) do
				local st = DailyRewardService.getState(p)
				if st and p:GetAttribute("DailyClaimable") ~= st.claimable then
					push(p)
				end
			end
		end
	end)
end

return DailyRewardService
