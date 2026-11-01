--[[
	ClientSettings — paramètres du joueur (lus partout côté client).
	Source de vérité : attribut Player "Settings" (JSON) répliqué par SettingsService (serveur, sauvegardé dans DataService).
	API (client) :
		ClientSettings.get(key)            -> valeur (défaut si absente)
		ClientSettings.set(key, value)     -> applique tout de suite en local + envoie au serveur (remote "Settings")
		ClientSettings.Changed             -> BindableEvent:Event (key, value)
		ClientSettings.DEFAULTS / ClientSettings.SCHEMA (pour construire le menu)
	Côté serveur, get() renvoie toujours le défaut (les réglages sont purement visuels / audio / contrôles).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local ClientSettings = {}

-- Ordre = ordre d'affichage dans le menu PARAMÈTRES. Type : "toggle" | "slider" (Min/Max/Step) | "choice" (Options)
ClientSettings.SCHEMA = {
	{ Key = "MusicVolume", Label = "Music", Type = "slider", Min = 0, Max = 1, Step = 0.05, Default = 0.5, Section = "Audio" },
	{ Key = "SFXVolume", Label = "Sound effects", Type = "slider", Min = 0, Max = 1, Step = 0.05, Default = 1, Section = "Audio" },
	{ Key = "ScreenShake", Label = "Screen shake", Type = "slider", Min = 0, Max = 1, Step = 0.1, Default = 1, Section = "Camera" },
	{ Key = "FOVKick", Label = "Camera zoom on hits", Type = "toggle", Default = true, Section = "Camera" },
	{ Key = "UltCinematics", Label = "Ultimate cinematic camera", Type = "toggle", Default = true, Section = "Camera" },
	{ Key = "ComicWords", Label = "Comic words (POW!)", Type = "toggle", Default = true, Section = "Effects" },
	{ Key = "DamageNumbers", Label = "Damage numbers", Type = "toggle", Default = true, Section = "Effects" },
	{ Key = "ReducedFlashes", Label = "Reduce flashes", Type = "toggle", Default = false, Section = "Effects" },
	{ Key = "Quality", Label = "Effects quality", Type = "choice", Options = { "Low", "Medium", "High" }, Default = "High", Section = "Effects" },
	{ Key = "AutoShiftLock", Label = "Shift-lock on spawn", Type = "toggle", Default = false, Section = "Controls" },
	{ Key = "ShowHints", Label = "Control hints", Type = "toggle", Default = true, Section = "Controls" },
}

ClientSettings.DEFAULTS = {}
local byKey = {}
for _, s in ipairs(ClientSettings.SCHEMA) do
	ClientSettings.DEFAULTS[s.Key] = s.Default
	byKey[s.Key] = s
end

local changed = Instance.new("BindableEvent")
ClientSettings.Changed = changed.Event

local values = {}

-- borne / valide une valeur selon le schéma (sert aussi au serveur)
function ClientSettings.sanitize(key, value)
	local s = byKey[key]
	if not s then
		return nil
	end
	if s.Type == "toggle" then
		return value == true
	elseif s.Type == "slider" then
		local n = tonumber(value)
		if not n or n ~= n then
			return s.Default
		end
		return math.clamp(n, s.Min, s.Max)
	elseif s.Type == "choice" then
		return table.find(s.Options, value) and value or s.Default
	end
	return nil
end

function ClientSettings.get(key)
	local v = values[key]
	if v == nil then
		return ClientSettings.DEFAULTS[key]
	end
	return v
end

local remote
function ClientSettings.set(key, value)
	value = ClientSettings.sanitize(key, value)
	if value == nil then
		return
	end
	if values[key] == value then
		return
	end
	values[key] = value
	changed:Fire(key, value)
	if RunService:IsClient() then
		if not remote then
			local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
			remote = folder and folder:FindFirstChild("Settings")
		end
		if remote then
			remote:FireServer(key, value)
		end
	end
end

-- client : suit l'attribut "Settings" du joueur local
if RunService:IsClient() then
	local player = Players.LocalPlayer
	local function pull()
		local raw = player:GetAttribute("Settings")
		if type(raw) ~= "string" or raw == "" then
			return
		end
		local ok, decoded = pcall(HttpService.JSONDecode, HttpService, raw)
		if not ok or type(decoded) ~= "table" then
			return
		end
		for k, v in pairs(decoded) do
			local clean = ClientSettings.sanitize(k, v)
			if clean ~= nil and values[k] ~= clean then
				values[k] = clean
				changed:Fire(k, clean)
			end
		end
	end
	if player then
		pull()
		player:GetAttributeChangedSignal("Settings"):Connect(pull)
	end
end

return ClientSettings
