--[[
	AmbienceController — boucles d'ambiance par étage (client), fondu croisé au changement d'étage.
	Étage courant : attribut ReplicatedStorage « FloorName » (posé par FloorService.applyCurrent au début de
	l'effondrement, répliqué) ; on attend AmbienceDelay s pour que le changement de son tombe vers l'atterrissage.
	Salle de pause : attribut Player « AFKActive » (AFKService) => Config/AFK.Ambience (calme) à la place de l'étage.
	Sons : Config/Floors.Ambience[étage] = liste { Src = "Sounds"|"Events", Key, Volume, Pitch } ; UNIQUEMENT des IDs
	déjà présents (Config/Sounds[Key][1], Config/Events.Sounds[Key]). Lecture en boucle (Looped), non positionnelle
	(parent = SoundService.AmbienceLoops), SoundGroup « Ambience » (volume = réglage AmbienceVolume, appliqué par
	SettingsController). Fondu croisé Config/Floors.AmbienceFade s (2,5).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FloorConfig = require(Shared.Config.Floors)
local AFKConfig = require(Shared.Config.AFK)
local SoundsConfig = require(Shared.Config.Sounds)
local EventsConfig = require(Shared.Config.Events)

local Ambience = {}
Ambience.Priority = 61

local AMBIENCE_DELAY = 1.2
local player = Players.LocalPlayer
local group, folder
local currentKey = nil
local currentSounds = {}
local token = 0

local function soundId(layer)
	if type(layer) ~= "table" then
		return nil
	end
	if layer.Src == "Sounds" then
		local list = SoundsConfig[layer.Key]
		return type(list) == "table" and list[1] or nil
	elseif layer.Src == "Events" then
		local id = EventsConfig.Sounds and EventsConfig.Sounds[layer.Key]
		return type(id) == "string" and id or nil
	end
	return nil
end

local function fadeOut(list, time)
	for _, s in ipairs(list) do
		local t = TweenService:Create(s, TweenInfo.new(time), { Volume = 0 })
		t.Completed:Connect(function()
			s:Stop()
			s:Destroy()
		end)
		t:Play()
	end
end

local function play(key, layers)
	if key == currentKey then
		return
	end
	currentKey = key
	local fade = FloorConfig.AmbienceFade or 2.5
	fadeOut(currentSounds, fade)
	currentSounds = {}
	for _, layer in ipairs(layers or {}) do
		local id = soundId(layer)
		if id then
			local s = Instance.new("Sound")
			s.Name = "Amb_" .. tostring(layer.Key)
			s.SoundId = id
			s.Looped = true
			s.Volume = 0
			s.PlaybackSpeed = layer.Pitch or 1
			s.SoundGroup = group
			s.Parent = folder
			s:Play()
			TweenService:Create(s, TweenInfo.new(fade), { Volume = layer.Volume or 0.15 }):Play()
			table.insert(currentSounds, s)
		end
	end
end

local function refresh(delay)
	token += 1
	local my = token
	local function go()
		if my ~= token then
			return
		end
		if player:GetAttribute("AFKActive") == true then
			play("_AFK", AFKConfig.Ambience)
		else
			local name = ReplicatedStorage:GetAttribute("FloorName")
			if type(name) == "string" then
				play(name, FloorConfig.Ambience and FloorConfig.Ambience[name])
			end
		end
	end
	if delay and delay > 0 then
		task.delay(delay, go)
	else
		go()
	end
end

function Ambience.init(ctx)
	local settings = ctx.SettingsController
	if settings and type(settings.group) == "function" then
		group = settings.group("Ambience")
	else
		group = SoundService:FindFirstChild("Ambience")
		if not group then
			group = Instance.new("SoundGroup")
			group.Name = "Ambience"
			group.Parent = SoundService
		end
	end
	folder = Instance.new("Folder")
	folder.Name = "AmbienceLoops"
	folder.Parent = SoundService
	ReplicatedStorage:GetAttributeChangedSignal("FloorName"):Connect(function()
		refresh(AMBIENCE_DELAY)
	end)
	player:GetAttributeChangedSignal("AFKActive"):Connect(function()
		refresh(0.3) -- après le fondu noir d'entrée / sortie
	end)
	refresh(0)
end

return Ambience
