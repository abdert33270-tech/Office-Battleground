--[[
	DailyRewardService — calendrier de connexion 7 jours (Config/DailyRewards), 100 % serveur (os.time()).
	- Une réclamation par jour UTC (jour = os.time() // 86400).
	- Série gardée si on a réclamé il y a au plus GRACE_DAYS jours UTC (GraceHours 48 => 2 : on peut sauter UN jour),
	  sinon retour au jour 1. Tout en jours entiers (os.time() lu une fois par requête) : rien d'ambigu à minuit pile.
	- Chargement DataStore raté (DataService.loadFailed) : pas de réclamation (elle serait perdue), état unsaved = true.
	- Après le jour 7 : nouveau cycle.
	Données (DataService, sauvegardées) : data.Daily = { Streak (0-7, dernier jour réclamé du cycle), LastDay, LastClaim, Total }.
	Attribut Player : DailyClaimable (bool) -> pastille rouge du bouton DAILY.
	Remote "DailyReward" :
		client -> serveur : "State" | "Claim"
		serveur -> client : state = { day, claimed, claimable, nextAt?, expiresAt?, lost, total, now, unsaved?, result? }
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

local function dayOf(t: number): number
	return t // DAY
end

local function today(): number
	return dayOf(os.time())
end

-- jours de calendrier UTC qu'on peut manquer sans perdre la série : GraceHours 48 => on peut sauter 1 jour
-- (réclamé lundi, mercredi garde la série, jeudi la perd). Calcul en jours entiers : pas d'effet de bord à minuit pile.
local GRACE_DAYS = math.max(1, math.ceil((Config.GraceHours or 48) / 24))

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

-- état calculé (ne modifie rien) ; now = os.time() lu UNE fois par l'appelant (claim et état cohérents autour de minuit)
local function compute(daily, now: number?)
	local n = #Config.Days
	local t = now or os.time()
	local day0 = dayOf(t)
	local streak = math.clamp(math.floor(tonumber(daily.Streak) or 0), 0, n)
	local lastDay = math.floor(tonumber(daily.LastDay) or -1)
	local lost = false
	if lastDay < 0 then
		streak = 0 -- première connexion
	elseif day0 - lastDay > GRACE_DAYS then
		lost = streak > 0
		streak = 0
	end
	-- lastDay > day0 (horloge d'un autre serveur en avance de quelques secondes) : pas réclamable, rien de perdu
	local claimable = day0 > lastDay
	local day = (streak % n) + 1 -- jour à réclamer (aujourd'hui si claimable, sinon demain)
	local claimed = claimable and (day - 1) or streak
	return {
		day = day,
		claimed = claimed,
		streak = streak,
		claimable = claimable,
		lost = lost,
		nextAt = (not claimable) and (math.max(day0, lastDay) + 1) * DAY or nil,
		-- moment où la série sera perdue si on ne réclame pas d'ici là
		expiresAt = (streak > 0 and lastDay >= 0) and (lastDay + GRACE_DAYS + 1) * DAY or nil,
		total = tonumber(daily.Total) or 0,
		now = t,
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
	if DataService.loadFailed(player) then
		st.claimable = false
		st.unsaved = true
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
	if DataService.loadFailed(player) then
		return false, "Your progress didn't load - rejoin to claim (nothing is lost)"
	end
	local now = os.time()
	local st = compute(daily, now)
	if not st.claimable then
		return false, "Already claimed today"
	end
	local reward = Config.Days[st.day]
	if not reward then
		return false, "Invalid day"
	end
	daily.Streak = st.day
	daily.LastDay = dayOf(now)
	daily.LastClaim = now
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
				if st and not DataService.loadFailed(p) and p:GetAttribute("DailyClaimable") ~= st.claimable then
					push(p)
				end
			end
		end
	end)
end

return DailyRewardService
