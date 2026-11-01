--[[
	SettingsService — réglages du joueur (schéma : Shared/Modules/ClientSettings).
	- Remote "Settings" (client -> serveur) : (key, value), limité à 12/s, nettoyé par ClientSettings.sanitize.
	- Sauvegarde : data.Settings = { [key] = value } (seulement les clés connues du schéma).
	- Réplication : attribut Player "Settings" = JSON (lu par ClientSettings côté client).
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local ClientSettings = require(ReplicatedStorage.Shared.Modules.ClientSettings)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local DataService = require(script.Parent.DataService)

local SettingsService = {}
SettingsService.Priority = 65

local function clean(saved)
	local out = {}
	if type(saved) ~= "table" then
		return out
	end
	for key, value in pairs(saved) do
		if type(key) == "string" then
			local v = ClientSettings.sanitize(key, value)
			if v ~= nil then
				out[key] = v
			end
		end
	end
	return out
end

local function replicate(player, settings)
	local ok, json = pcall(HttpService.JSONEncode, HttpService, settings)
	if ok then
		player:SetAttribute("Settings", json)
	end
end

function SettingsService.get(player: Player, key: string)
	local d = DataService.get(player)
	local v = d and type(d.Settings) == "table" and d.Settings[key]
	if v == nil then
		return ClientSettings.DEFAULTS[key]
	end
	return v
end

function SettingsService.init()
	DataService.whenLoaded(function(player, data)
		data.Settings = clean(data.Settings)
		replicate(player, data.Settings)
	end)

	Net.get("Settings").OnServerEvent:Connect(function(player, key, value)
		if type(key) ~= "string" or #key > 40 or not Net.allow(player, "Settings", 12) then
			return
		end
		local d = DataService.get(player)
		if not d then
			return
		end
		local v = ClientSettings.sanitize(key, value)
		if v == nil then
			return
		end
		if type(d.Settings) ~= "table" then
			d.Settings = {}
		end
		if d.Settings[key] == v then
			return
		end
		d.Settings[key] = v
		replicate(player, d.Settings)
	end)
end

return SettingsService
