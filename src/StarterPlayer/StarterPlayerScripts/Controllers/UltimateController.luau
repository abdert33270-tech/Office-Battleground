--[[
	UltimateController — côté client des ULTIMES (voir ServerScriptService.Services.UltimateService et Modules.UltKit).
	- Écoute la remote "UltFX" : pour chaque phase, appelle Client(K, data) du module ReplicatedStorage.Shared.Ultimates.<Id>.
	- Phase "Cutin" (automatique) : panneau cut-in (lanceur + victime), bandeau pour les spectateurs proches,
	  assombrissement du monde (< 80 studs), son, mini hit-stop, caméra dramatique du lanceur (orbite sur son visage).
	- Phase "End" (automatique) : rend la caméra, retire bandes noires / assombrissement / objets suivis (K.track / K.prop).
	- Sécurité : si "End" n'arrive jamais, nettoyage forcé au bout de 10 s.
	- Garde le personnage local ancré tant que le serveur l'ancre (attribut UltAnchor), même si un hit-stop local le relâche.
	API : UltimateController.request(target) = ce que fait la touche G pendant l'Overtime (CombatController.transform le fait déjà).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local K = require(Shared.Modules.UltKit)

local UltimateController = {}
UltimateController.Priority = 45

local player = Players.LocalPlayer
local defs = {}
local live = {} -- [seq] = true tant que l'ulti n'est pas finie

local function getDef(id)
	if type(id) ~= "string" then
		return nil
	end
	if defs[id] ~= nil then
		return defs[id] or nil
	end
	local folder = Shared:FindFirstChild("Ultimates")
	local m = folder and folder:FindFirstChild(id)
	local def = false
	if m and m:IsA("ModuleScript") then
		local ok, res = pcall(require, m)
		if ok and type(res) == "table" then
			def = res
		else
			warn("[UltimateController] module", id, res)
		end
	end
	defs[id] = def
	return def or nil
end

local function displayName(id)
	local ok, Characters = pcall(require, Shared.Config.Characters)
	local d = ok and Characters[id or ""]
	return d and d.DisplayName or id or ""
end

local function runClient(def, data)
	if def and type(def.Client) == "function" then
		task.spawn(function()
			local ok, err = pcall(def.Client, K, data)
			if not ok then
				warn("[Ultimate]", data.id, data.phase, err)
			end
		end)
	end
end

-- cut-in automatique
local function builtinCutin(data)
	local c = data.caster
	local root = K.root(c)
	local pos = root and root.Position
	local dur = data.dur or 1
	local near = pos ~= nil and K.near(pos, 80)
	local who = displayName(data.id)
	if K.involved(data) then
		K.cutin(data, { dur = dur * 0.88, sub = who ~= "" and (who .. "  -  ULTIMATE") or "ULTIMATE" })
		K.sound("CutIn", nil, 1.1)
		K.sound("Sting", nil, 0.45)
		K.impactFrames("W", 0.05)
	elseif near then
		K.cutin(data, { small = true, dur = dur, sub = who })
		K.sound("CutIn", pos, 0.8)
	end
	if near then
		K.darken(true, 1, 0.12)
		K.at(data, dur, function()
			if live[data.seq] then
				K.darken(false, nil, 0.35)
			end
		end)
	end
	if c then
		K.freezeAnim(c, 0.12)
	end
	-- caméra du lanceur : orbite serrée sur le visage, devant lui
	if root then
		local head = c:FindFirstChild("Head") or root
		K.shot(data, "orbit", {
			only = "caster", tag = "cutin", at = head, basis = root.CFrame,
			r0 = 9, r1 = 5.2, dur = dur, height = 0.6, angle = 35, speed = -28,
			lookOffset = Vector3.new(0, -0.3, 0), fov = 55,
		})
		-- si le module ne reprend pas la caméra, on la rend à la fin du cut-in
		K.at(data, dur + 0.05, function()
			if K.shotTag and K.shotTag() == "cutin" then
				K.release(data)
			end
		end)
	end
end

local function onFX(data)
	if type(data) ~= "table" or type(data.seq) ~= "number" then
		return
	end
	local def = getDef(data.id)
	if data.phase == "Cutin" then
		live[data.seq] = true
		local ok, err = pcall(builtinCutin, data)
		if not ok then
			warn("[UltimateController] cut-in", err)
		end
		task.delay(10, function()
			if live[data.seq] then
				live[data.seq] = nil
				K._cleanup(data)
			end
		end)
	end
	runClient(def, data)
	if data.phase == "End" then
		live[data.seq] = nil
		task.delay(0.05, function()
			K._cleanup(data)
		end)
	end
end

-- touche G pendant l'Overtime (CombatController.transform le fait déjà quand UltReady)
function UltimateController.request(target)
	Net.get("Ultimate"):FireServer(target)
end

function UltimateController.init()
	Net.get("UltFX").OnClientEvent:Connect(onFX)
	-- garde le perso local ancré tant que le serveur l'ancre (un hit-stop local ne doit pas le relâcher)
	local function hook(c)
		c:GetAttributeChangedSignal("UltAnchor"):Connect(function()
			if not c:GetAttribute("UltAnchor") then
				task.defer(function()
					local r = c:FindFirstChild("HumanoidRootPart")
					if r and r.Anchored and not c:GetAttribute("UltAnchor") then
						r.Anchored = false
					end
				end)
			end
		end)
	end
	player.CharacterAdded:Connect(hook)
	if player.Character then
		hook(player.Character)
	end
	RunService.Stepped:Connect(function()
		local c = player.Character
		if c and c:GetAttribute("UltAnchor") then
			local r = c:FindFirstChild("HumanoidRootPart")
			if r and not r.Anchored then
				r.Anchored = true
			end
		end
	end)
end

return UltimateController
