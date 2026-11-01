--[[
	ClientSettings — paramètres du joueur (lus partout côté client).
	Source de vérité : attribut Player "Settings" (JSON) répliqué par SettingsService (serveur, sauvegardé dans DataService).
	API (client) :
		ClientSettings.get(key)            -> valeur (défaut si absente)
		ClientSettings.set(key, value)     -> applique tout de suite en local + envoie au serveur (remote "Settings"),
		                                      regroupé par clé (dernière valeur, 0,15 s après le dernier changement, <= 8 / s)
		ClientSettings.resetAll()          -> remet toutes les valeurs par défaut (menu SETTINGS)
		ClientSettings.Changed             -> BindableEvent:Event (key, value)
		ClientSettings.DEFAULTS / ClientSettings.SCHEMA (pour construire le menu)
	Côté serveur, get() renvoie toujours le défaut (les réglages sont purement visuels / audio / contrôles).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local ClientSettings = {}

-- Ordre = ordre d'affichage dans le menu PARAMÈTRES. Type : "toggle" | "slider" (Min/Max/Step) | "choice" (Options)
-- Pas de « MusicVolume » : le jeu n'a aucune musique. Une ancienne sauvegarde qui contient la clé reste valide :
-- sanitize renvoie nil pour une clé inconnue => ignorée par pull() et retirée de data.Settings par SettingsService.
ClientSettings.SCHEMA = {
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

-- Envoi au serveur : regroupé par clé (on n'envoie que la dernière valeur, SEND_DELAY s après le dernier clic)
-- et limité à SEND_RATE / s (le serveur coupe au-delà de 12 / s). Tant qu'une écriture locale n'est pas confirmée
-- par l'attribut répliqué, pull() ignore cette clé (sinon un vieux JSON ferait « sauter » le bouton en arrière).
local SEND_DELAY = 0.15
local SEND_RATE = 8
local CONFIRM_TIMEOUT = 3
local remote
local pending = {} -- [key] = value à envoyer
local awaiting = {} -- [key] = { value, untilT } : envoyé, pas encore revenu dans l'attribut
local serverValues = {} -- [key] = dernière valeur lue dans l'attribut
local lastChange = 0
local flushScheduled = false
local tokens, tokensAt = SEND_RATE, 0

local function findRemote()
	if not remote then
		local folder = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
		remote = folder and folder:FindFirstChild("Settings")
	end
	return remote
end

local flush
local function schedule(delay)
	if flushScheduled then
		return
	end
	flushScheduled = true
	task.delay(delay, function()
		flushScheduled = false
		flush()
	end)
end

function flush()
	local now = os.clock()
	if now - lastChange < SEND_DELAY then
		return schedule(SEND_DELAY - (now - lastChange) + 0.01)
	end
	local r = findRemote()
	if not r then
		return schedule(0.5)
	end
	tokens = math.min(SEND_RATE, tokens + (now - tokensAt) * SEND_RATE)
	tokensAt = now
	for key, value in pairs(pending) do
		local w = awaiting[key]
		if w and now > w.untilT then
			awaiting[key] = nil
			w = nil
		end
		if serverValues[key] == value and w == nil then
			-- revenu à la valeur déjà sauvegardée et rien en vol : rien à envoyer.
			-- (Si une autre valeur est encore en vol — A envoyé, retour à S avant l'écho de A —, on renvoie S :
			-- sinon l'écho de A ferait repasser le serveur et le bouton sur A.)
			pending[key] = nil
		elseif tokens >= 1 then
			tokens -= 1
			pending[key] = nil
			awaiting[key] = { value = value, untilT = now + CONFIRM_TIMEOUT }
			r:FireServer(key, value)
		end
	end
	if next(pending) ~= nil then
		schedule(1 / SEND_RATE + 0.02)
	end
end

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
		pending[key] = value
		lastChange = os.clock()
		schedule(SEND_DELAY)
	end
end

function ClientSettings.resetAll()
	for _, s in ipairs(ClientSettings.SCHEMA) do
		ClientSettings.set(s.Key, s.Default)
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
		local now = os.clock()
		for k, v in pairs(decoded) do
			local clean = ClientSettings.sanitize(k, v)
			if clean ~= nil then
				serverValues[k] = clean
				local w = awaiting[k]
				if w and (w.value == clean or now > w.untilT) then
					awaiting[k] = nil
					w = nil
				end
				-- écriture locale en attente (pas encore envoyée, ou envoyée mais pas encore revenue) : on garde la valeur locale
				if pending[k] == nil and w == nil and values[k] ~= clean then
					values[k] = clean
					changed:Fire(k, clean)
				end
			end
		end
	end
	if player then
		pull()
		player:GetAttributeChangedSignal("Settings"):Connect(pull)
	end
end

return ClientSettings
