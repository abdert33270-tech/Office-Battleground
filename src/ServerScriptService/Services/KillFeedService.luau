--[[
	KillFeedService — transforme chaque mort (Signals.Died) en ligne de kill feed façon bureau.
	« [Killer] fired [Victim] (Stapler) » / « [Victim] was let go by HR » / « [Victim] resigned »
	Séries : 3 K.O. sans mourir (puis tous les 3) => « [Name] is EMPLOYEE OF THE MONTH! »
	Les mannequins apparaissent dans le feed mais ne comptent pas pour les séries.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signals = require(script.Parent.Signals)
local Announce = require(script.Parent.Announce)
local Net = require(ReplicatedStorage.Shared.Modules.Net)

local KillFeedService = {}
KillFeedService.Priority = 62

local streaks = {} -- [userId] = nombre de K.O. depuis la dernière mort

local function prettyWeapon(weapon)
	if type(weapon) ~= "string" or weapon == "" then
		return nil
	end
	local ok, Items = pcall(require, ReplicatedStorage.Shared.Config.Items)
	if ok and Items[weapon] and Items[weapon].DisplayName then
		return Items[weapon].DisplayName
	end
	local okA, Attacks = pcall(function()
		return require(ReplicatedStorage.Shared.Config:FindFirstChild("Attacks"))
	end)
	if okA and type(Attacks) == "table" and type(Attacks[weapon]) == "table" and Attacks[weapon].Name then
		return Attacks[weapon].Name
	end
	-- "CoffeeRun" -> "Coffee Run"
	return (string.gsub(weapon, "(%l)(%u)", "%1 %2"))
end

local function describe(model)
	if not model then
		return nil, 0, nil
	end
	local player = Players:GetPlayerFromCharacter(model)
	return player and player.DisplayName or model.Name, player and player.UserId or 0, model:GetAttribute("CharacterName")
end

function KillFeedService.init()
	-- les clients attendent ces remotes : on les crée dès le démarrage
	for _, name in ipairs({ "Banner", "KillFeed", "Toast", "SelectCharacter" }) do
		Net.get(name)
	end

	Signals.Died:Connect(function(victim, killer, weapon, cause)
		local vName, vId, vChar = describe(victim)
		local entry = { victim = vName, victimId = vId, victimChar = vChar }
		if killer and killer ~= victim then
			local kName, kId, kChar = describe(killer)
			entry.kind = "Fired"
			entry.killer, entry.killerId, entry.killerChar = kName, kId, kChar
			entry.weapon = prettyWeapon(weapon)
		elseif cause == "Event" then
			entry.kind = "HR"
		else
			entry.kind = "Resigned"
		end
		Announce.killfeed(entry)

		if vId ~= 0 then
			streaks[vId] = 0
		end
		if entry.kind == "Fired" and entry.killerId ~= 0 and not victim:GetAttribute("IsDummy") then
			local n = (streaks[entry.killerId] or 0) + 1
			streaks[entry.killerId] = n
			if n % 3 == 0 then
				Announce.killfeed({ kind = "Streak", killer = entry.killer, killerId = entry.killerId, killerChar = entry.killerChar, count = n })
				Announce.banner(string.upper(entry.killer) .. " IS EMPLOYEE OF THE MONTH!", n .. " coworkers fired in a row", Color3.fromRGB(255, 200, 40), 3, "Event")
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		streaks[p.UserId] = nil
	end)
end

return KillFeedService
