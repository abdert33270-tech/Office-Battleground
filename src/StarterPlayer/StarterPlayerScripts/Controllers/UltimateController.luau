--[[
	UltimateController — côté client des ULTIMES (voir ServerScriptService.Services.UltimateService et Modules.UltKit).
	- Écoute la remote "UltFX" : pour chaque phase, appelle Client(K, data) du module ReplicatedStorage.Shared.Ultimates.<Id>.
	- Phase "Cutin" (automatique) : panneau cut-in (lanceur + victime), bandeau pour les spectateurs proches,
	  assombrissement du monde (< 80 studs), son, mini hit-stop, caméra dramatique du lanceur (orbite sur son visage).
	- Phase "End" (automatique) : rend la caméra, retire bandes noires / assombrissement / objets suivis (K.track / K.prop).
	- Lisibilité (v3) : bandes noires pendant toute l'ulti (lanceur + victime), contour (Highlight) sur le lanceur puis sur la
	  victime dès qu'elle est tenue, titres de temps forts (def.Beats[phase] = texte ou { {t, texte}, ... }, ou payload.beat),
	  poses d'anticipation (def.Anticipate[phase] = { t, ... }), hit-stop sur chaque coup
	  (phase interne "_Hit" envoyée par U.hit / U.finish), pose d'anticipation (phase interne "_Windup" de U.windup).
	  Les phases qui commencent par "_" ne sont PAS transmises au Client du module.
	- Sécurité : si "End" n'arrive jamais, nettoyage forcé au bout de 12 s ; caméra rendue tout de suite à la mort / au respawn
	  et si le lanceur disparaît.
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
local live = {} -- [seq] = data de la phase "Cutin" tant que l'ulti n'est pas finie
local lit = {} -- [seq] = { [model] = true } persos déjà entourés

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

local function highlightOnce(data, model, color)
	if typeof(model) ~= "Instance" or not model.Parent then
		return
	end
	local set = lit[data.seq]
	if not set then
		set = {}
		lit[data.seq] = set
	end
	if set[model] then
		return
	end
	set[model] = true
	K.highlight(data, model, color, 0.85)
end

-- la victime est entourée dès qu'elle est tenue par CETTE ulti (attribut UltHeld = seq)
local function checkVictim(data)
	local v = data.target
	if typeof(v) == "Instance" and v.Parent and v:GetAttribute("UltHeld") == data.seq then
		local r = K.root(v)
		if r and K.near(r.Position, 90) then
			highlightOnce(data, v, Color3.fromRGB(255, 70, 70))
		end
	end
end

-- hit-stop automatique sur chaque coup d'ulti (U.hit / U.finish)
local function builtinHit(data)
	local v = data.victim
	local vr = K.root(v)
	if not (K.involved(data) or (vr and K.near(vr.Position, 90))) then
		return
	end
	if typeof(v) == "Instance" and v == data.target then
		highlightOnce(data, v, Color3.fromRGB(255, 70, 70))
	end
	local fin = data.fin == true
	-- laisse la pose de frappe arriver, puis gèle
	K.at(data, 0.035, function()
		K.hitStop({ data.caster, v }, fin and 0.16 or 0.07)
	end)
	if fin and K.involved(data) then
		K.fov(6)
	end
end

-- anticipation automatique (U.windup)
local function builtinWindup(data)
	local c = data.caster
	local r = K.root(c)
	if not r or not (K.involved(data) or K.near(r.Position, 90)) then
		return
	end
	K.windup(c, data.t or 0.2, data.color)
	if K.involved(data) then
		K.fov(3)
	end
end

-- titres de temps forts (def.Beats[phase] = "TEXTE" ou { {t, "TEXTE"}, ... } ; ou payload.beat)
-- + poses d'anticipation (def.Anticipate[phase] = { t, ... })
local function beatTitle(def, data)
	local text = data.beat
	if text == nil and def and type(def.Beats) == "table" then
		text = def.Beats[data.phase]
	end
	if type(text) == "string" then
		local r = K.root(data.caster)
		if K.involved(data) or (r and K.near(r.Position, 80)) then
			K.beatTitle(data, text, data.color)
		end
	elseif type(text) == "table" then
		K.beats(data, text)
	end
	local ant = def and type(def.Anticipate) == "table" and def.Anticipate[data.phase]
	if type(ant) == "table" then
		local r = K.root(data.caster)
		if r and (K.involved(data) or K.near(r.Position, 90)) then
			for _, t in ipairs(ant) do
				if type(t) == "number" then
					K.anticipate(data, t, data.caster, 0.2, data.color)
				end
			end
		end
	end
end

local function cleanupSeq(data)
	live[data.seq] = nil
	lit[data.seq] = nil
	K._cleanup(data)
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
	-- bandes noires pendant toute l'ulti (lanceur + victime), contour sur le lanceur
	K.letterbox(data, true, 0.25)
	if near then
		highlightOnce(data, c, data.color)
	end
	-- caméra du lanceur : orbite serrée sur le visage, devant lui
	if root then
		local head = c:FindFirstChild("Head") or root
		K.shot(data, "orbit", {
			only = "caster", tag = "cutin", at = head, basis = root.CFrame, fit = false,
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
	local phase = data.phase
	-- phases internes (ne vont pas au module)
	if phase == "_Hit" then
		if live[data.seq] then
			pcall(builtinHit, data)
		end
		return
	elseif phase == "_Windup" then
		if live[data.seq] then
			pcall(builtinWindup, data)
		end
		return
	end
	local def = getDef(data.id)
	if phase == "Cutin" then
		live[data.seq] = data
		local ok, err = pcall(builtinCutin, data)
		if not ok then
			warn("[UltimateController] cut-in", err)
		end
		-- si le lanceur disparaît (mort, départ) sans "End", on nettoie quand même
		local c = data.caster
		if typeof(c) == "Instance" then
			local conn
			conn = c.AncestryChanged:Connect(function(_, parent)
				if parent == nil then
					conn:Disconnect()
					task.delay(0.6, function()
						if live[data.seq] then
							cleanupSeq(data)
						end
					end)
				end
			end)
			task.delay(12, function()
				if conn.Connected then
					conn:Disconnect()
				end
			end)
		end
		task.delay(12, function()
			if live[data.seq] then
				cleanupSeq(data)
			end
		end)
	elseif phase ~= "End" and live[data.seq] then
		pcall(checkVictim, data)
		pcall(beatTitle, def, data)
	end
	runClient(def, data)
	if phase == "End" then
		live[data.seq] = nil
		task.delay(0.05, function()
			lit[data.seq] = nil
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
	-- mort / respawn : la caméra et les bandes noires sont rendues tout de suite
	local function onCharacter(c)
		hook(c)
		K.releaseAll(true)
		K.letterbox(nil, false, 0.1)
		local hum = c:WaitForChild("Humanoid", 10)
		if hum and hum:IsA("Humanoid") then
			hum.Died:Connect(function()
				K.releaseAll(true)
				K.letterbox(nil, false, 0.2)
			end)
		end
	end
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then
		task.spawn(onCharacter, player.Character)
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
