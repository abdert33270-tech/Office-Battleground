--[[
	CartoonFX — module central des effets cartoon (client).
	Appelé par tous les systèmes : coups, objets, attaques (Content), ultimes (UltKit), étages, événements.

	CartoonFX.hit(data)        effet complet d'un coup (onomatopée, étoiles, chiffres, flash, son, shake, hit-stop)
	CartoonFX.word(pos, text, power, category, opts?)
	                           onomatopée BD placée AUTOUR du combat (ComicWords.place) ; opts = { a = attaquant,
	                           v = victime, force = true (ignore le filtre de pertinence), exact = true (pas de placement) }
	CartoonFX.impact(pos, power)
	CartoonFX.damageNumber(pos, amount, power, opts?)   opts = { a, v, force } comme word
	CartoonFX.sound(key, pos, volume, pitch?)           toujours routé dans le SoundGroup « SFX »
	CartoonFX.shake(intensity) (× réglage ScreenShake), CartoonFX.fovKick(amount) (réglage FOVKick)
	CartoonFX.twinkle(pos), dizzy(character, duration), alert(character), puff(pos, size), setSweat(character, on)

	Nouvelles aides combat :
	CartoonFX.guardBreak(character | data, attacker?)   bouclier qui vole en éclats + « GUARD BREAK! » + vertige
	CartoonFX.perfectBlock(character | data, attacker?) éclair cyan « PERFECT! » + ting
	CartoonFX.blockHit(pos, normal?, data?)             étincelles de garde orientées + disque de bouclier
	CartoonFX.dashFX(character, direction?)             poussière, traînée, lignes de vent, whoosh
	CartoonFX.knockdown(character | pos)                poussière d'atterrissage au sol + « THUD »
	CartoonFX.hitSpark(pos, dir?, power?, color?)        éclat blanc + étincelles dans l'axe du coup
	CartoonFX.slowFlash(color?, dur?)                    teinte froide « ralenti » (parade parfaite)

	POIDS DES COUPS (hit) : léger = PunchLight aigu + petite étincelle ; lourd / finisher = PunchHeavy + couche grave
	(Thud + LowThump) + BigImpact, onde d'air (finisher / K.O. : Boom) ; r = "Slam" = sol fendu + poussière.
	Garde : blockHit = Block + BlockThud mat ; guardBreak = GlassShatter + LowThump ; perfectBlock = Ting + ralenti.
	Sons : jamais deux fois de suite le même fichier pour une clé, hauteur / volume selon Sounds.Variation.

	FILTRE DE PERTINENCE (onomatopées + chiffres de dégâts) : chaque client ne voit que les mots des combats
	où SON personnage est l'attaquant ou la victime.
	- contexte explicite : opts.a / opts.v, ou CartoonFX.withContext(a, v, fn, ...) (posé sur le thread courant
	  par les dispatchers FXController / AbilityFXController avant d'appeler les handlers / MoveFX) ;
	- sinon déduction : ultime en cours à proximité (CartoonFX.noteUlt, alimenté par FXController sur « UltFX »),
	  personnages proches du mot (moi, ou un ennemi avec qui j'ai échangé un coup il y a < 3,5 s : noteEngage),
	  ou mot sans personnage autour (décor / événement d'étage / révélation de skin) = visible.
	CartoonFX.isRelevant(pos, a?, v?) est publique (les autres systèmes peuvent s'en servir).

	RÉGLAGES (ClientSettings) : ComicWords, DamageNumbers, ReducedFlashes, Quality (Low/Medium/High), ScreenShake,
	FOVKick, SFXVolume (SoundGroup « SFX » de SoundService, créé ici côté client).

	Tous les éléments sont créés localement (jamais répliqués) et nettoyés automatiquement (Debris).
	Budget : CartoonFX.count(n) réduit les quantités selon la qualité ET la charge récente (pas d'avalanche de parts).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = ReplicatedStorage.Shared.Config
local Words = require(Config.Words)
local Sounds = require(Config.Sounds)
local CombatConfig = require(Config.Combat)
local ProcAnim = require(ReplicatedStorage.Shared.Modules.ProcAnim)
local UITheme = require(ReplicatedStorage.Shared.Modules.UITheme)
local PIXEL = UITheme.Display

local CartoonFX = {}
local rng = Random.new()
local localPlayer = Players.LocalPlayer

local function tween(obj, time, props, style, dir)
	local t = TweenService:Create(obj, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local function myChar()
	return localPlayer and localPlayer.Character
end

local function fxFolder()
	return workspace:FindFirstChild("FX") or workspace
end

------------------------------------------------------------------------
-- Réglages joueur (lecture tolérante : si ClientSettings manque, valeurs par défaut)
------------------------------------------------------------------------
local ClientSettings
do
	local m = ReplicatedStorage.Shared.Modules:FindFirstChild("ClientSettings")
	if m then
		local ok, mod = pcall(require, m)
		if ok and type(mod) == "table" and type(mod.get) == "function" then
			ClientSettings = mod
		end
	end
end
local SETTING_DEFAULTS = { ComicWords = true, DamageNumbers = true, ReducedFlashes = false, Quality = "High", ScreenShake = 1, FOVKick = true, SFXVolume = 1 }
local function setting(key)
	if ClientSettings then
		local ok, v = pcall(ClientSettings.get, key)
		if ok and v ~= nil then
			return v
		end
	end
	return SETTING_DEFAULTS[key]
end
CartoonFX.setting = setting

local function reducedFlashes()
	return setting("ReducedFlashes") == true
end
CartoonFX.reducedFlashes = reducedFlashes

local QUALITY_K = { Low = 0.4, Medium = 0.7, High = 1 }
function CartoonFX.quality(): number
	return QUALITY_K[setting("Quality")] or 1
end

-- charge récente d'effets (parts / particules créées) qui décroît toute seule : au-delà, on réduit les quantités
local fxLoad, loadT = 0, os.clock()
local function addLoad(n)
	local now = os.clock()
	fxLoad = fxLoad * math.exp(-(now - loadT) * 2.5) + n
	loadT = now
end
local function budgetScale()
	local now = os.clock()
	local l = fxLoad * math.exp(-(now - loadT) * 2.5)
	return math.clamp(1 - (l - 160) / 320, 0.3, 1)
end
-- quantité ajustée (qualité × budget), au moins 1 si n > 0
local function qn(n: number?): number
	n = n or 0
	if n <= 0 then
		return 0
	end
	local k = CartoonFX.quality() * budgetScale()
	local r = math.max(1, math.floor(n * k + 0.5))
	addLoad(r)
	return r
end
CartoonFX.count = qn

-- point d'ancrage invisible dans le monde (attachment dans Terrain)
local function anchorAt(pos: Vector3, life: number)
	local att = Instance.new("Attachment")
	att.WorldPosition = pos
	att.Parent = workspace.Terrain
	Debris:AddItem(att, life)
	return att
end

local function billboard(adornee, sizeStuds: number, life: number?)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(sizeStuds, sizeStuds)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 160
	bb.ResetOnSpawn = false
	bb.Adornee = adornee
	bb.Parent = adornee
	if life then
		Debris:AddItem(bb, life)
	end
	return bb
end

local function colorForPower(power: number): Color3
	local c = Words.TextColors
	if power <= 0.5 then
		return c[1]:Lerp(c[2], power / 0.5)
	end
	return c[2]:Lerp(c[3], math.clamp((power - 0.5) / 0.5, 0, 1))
end

-- appels tolérants à ProcAnim (le module est en cours de réécriture par le système de combat)
local function anim(model, name)
	if model and type(ProcAnim.play) == "function" then
		pcall(ProcAnim.play, model, name)
	end
end
local function freezeAnim(model, t)
	if model and type(ProcAnim.freeze) == "function" then
		pcall(ProcAnim.freeze, model, t)
	end
end

-- valeurs de Config/Combat avec repli (la structure peut changer)
local function combatValue(group: string, key: string, default: number): number
	local g = CombatConfig[group]
	local v = type(g) == "table" and g[key]
	return type(v) == "number" and v or default
end

local function rootOf(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

------------------------------------------------------------------------
-- Sons (SoundGroup « SFX » réglable depuis le menu)
------------------------------------------------------------------------
local groups = {}
local function soundGroup(name: string, settingKey: string): SoundGroup
	local g = groups[name]
	if g and g.Parent then
		return g
	end
	g = SoundService:FindFirstChild(name)
	if not (g and g:IsA("SoundGroup")) then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
	end
	local v = tonumber(setting(settingKey))
	g.Volume = v or 1
	groups[name] = g
	return g
end
function CartoonFX.sfxGroup(): SoundGroup
	return soundGroup("SFX", "SFXVolume")
end

if RunService:IsClient() then
	CartoonFX.sfxGroup()
	if ClientSettings and ClientSettings.Changed then
		ClientSettings.Changed:Connect(function(key, value)
			if key == "SFXVolume" then
				CartoonFX.sfxGroup().Volume = tonumber(value) or 1
			end
		end)
	end
	-- tout son local sans groupe créé dans le monde (UltKit, Content, contrôleurs) passe aussi par « SFX »
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Sound") and d.SoundGroup == nil then
			d.SoundGroup = CartoonFX.sfxGroup()
		end
	end)
end

local lastSoundAt = {} -- [clé] = os.clock() : évite d'empiler 5 fois le même son dans la même image
local lastSoundIdx = {} -- [clé] = dernier index joué (anti-répétition)
local DEFAULT_VAR = { 0.92, 1.1, 0.88, 1.05 }
local liveSounds = 0
local MAX_SOUNDS = 28
function CartoonFX.sound(key: string, pos: Vector3?, volume: number?, pitch: number?)
	local list = Sounds[key]
	if type(list) ~= "table" or #list == 0 then
		return nil
	end
	local now = os.clock()
	if (lastSoundAt[key] or 0) > now - 0.035 or liveSounds >= MAX_SOUNDS then
		return nil
	end
	-- anti-répétition : jamais deux fois de suite le même fichier pour une clé (si la liste en a plusieurs)
	local idx = rng:NextInteger(1, #list)
	if #list > 1 and idx == lastSoundIdx[key] then
		idx = idx % #list + 1
	end
	local id = list[idx]
	if type(id) ~= "string" then
		return nil
	end
	lastSoundAt[key] = now
	lastSoundIdx[key] = idx
	local var = (type(Sounds.Variation) == "table" and Sounds.Variation[key]) or Sounds.DefaultVariation or DEFAULT_VAR
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = math.clamp((volume or 0.7) * rng:NextNumber(var[3], var[4]), 0, 3)
	s.PlaybackSpeed = math.clamp((pitch or 1) * rng:NextNumber(var[1], var[2]), 0.3, 3)
	s.RollOffMaxDistance = 150
	s.RollOffMinDistance = 14
	s.SoundGroup = CartoonFX.sfxGroup()
	if pos then
		s.Parent = anchorAt(pos, 4)
	else
		s.Parent = workspace.CurrentCamera
		Debris:AddItem(s, 4)
	end
	liveSounds += 1
	task.delay(1.5, function()
		liveSounds -= 1
	end)
	s:Play()
	return s
end

-- plusieurs sons d'un coup : { {clé, volume, pitch?, délai?}, ... }
function CartoonFX.soundLayer(list, pos: Vector3?)
	for _, e in ipairs(list) do
		if e[4] and e[4] > 0 then
			task.delay(e[4], CartoonFX.sound, e[1], pos, e[2], e[3])
		else
			CartoonFX.sound(e[1], pos, e[2], e[3])
		end
	end
end

------------------------------------------------------------------------
-- Tremblement d'écran (× réglage ScreenShake)
------------------------------------------------------------------------
local shakeAmp = 0
function CartoonFX.shake(intensity: number)
	local k = tonumber(setting("ScreenShake")) or 1
	shakeAmp = math.max(shakeAmp, (intensity or 0) * math.clamp(k, 0, 1))
end
if RunService:IsClient() then
	RunService:BindToRenderStep("CartoonShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		if shakeAmp > 0.005 then
			local cam = workspace.CurrentCamera
			local a = shakeAmp
			cam.CFrame = cam.CFrame
				* CFrame.new(rng:NextNumber(-a, a) * 0.6, rng:NextNumber(-a, a) * 0.6, 0)
				* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-a, a) * 2))
			shakeAmp *= math.exp(-dt * 14)
		else
			shakeAmp = 0
		end
	end)
end

------------------------------------------------------------------------
-- FILTRE DE PERTINENCE des onomatopées / chiffres
------------------------------------------------------------------------
local ENGAGE_TIME = 3.5
local engagedAt = setmetatable({}, { __mode = "k" }) -- [Model] = os.clock() du dernier coup échangé avec moi
local threadCtx = setmetatable({}, { __mode = "k" }) -- [thread] = { a, v }
local ults = {} -- [seq] = { caster, targets = {[Model]=true}, untilT }
local lastLocalCast = -100

-- note qu'un coup a été échangé entre a et v (si l'un des deux est moi)
function CartoonFX.noteEngage(a, v)
	local me = myChar()
	if not me then
		return
	end
	local now = os.clock()
	if a == me and v and v ~= me then
		engagedAt[v] = now
	elseif v == me and a and a ~= me then
		engagedAt[a] = now
	end
end

local function engaged(m): boolean
	local t = m and engagedAt[m]
	return t ~= nil and os.clock() - t < ENGAGE_TIME
end
CartoonFX.engaged = engaged

-- le joueur local vient de lancer une attaque (les mots de ses attaques arrivent avant le 1er « Hit »)
function CartoonFX.noteLocalCast()
	lastLocalCast = os.clock()
end

-- suivi des ultimes en cours (payloads de la remote « UltFX » : seq, phase, caster, target)
function CartoonFX.noteUlt(d)
	if type(d) ~= "table" or d.seq == nil then
		return
	end
	local u = ults[d.seq]
	if d.phase == "End" then
		if u then
			u.untilT = os.clock() + 0.8
		end
		return
	end
	if not u then
		u = { targets = {}, untilT = 0 }
		ults[d.seq] = u
	end
	if typeof(d.caster) == "Instance" then
		u.caster = d.caster
	end
	if typeof(d.target) == "Instance" then
		u.targets[d.target] = true
	end
	u.untilT = os.clock() + 15 -- sécurité si « End » se perd
end

local function ultInvolvesMe(u): boolean
	local me = myChar()
	if not me then
		return false
	end
	return u.caster == me or u.targets[me] == true or engaged(u.caster)
end

-- ultime en cours dont la zone (40 studs autour du lanceur ou d'une cible) contient pos
local function ultAt(pos: Vector3)
	local now = os.clock()
	local found
	for seq, u in pairs(ults) do
		if now > u.untilT then
			ults[seq] = nil
		elseif not found then
			local near = false
			local r = rootOf(u.caster)
			if r and (r.Position - pos).Magnitude < 40 then
				near = true
			else
				for t in pairs(u.targets) do
					local tr = rootOf(t)
					if tr and (tr.Position - pos).Magnitude < 40 then
						near = true
						break
					end
				end
			end
			if near then
				found = u
			end
		end
	end
	return found
end

-- personnages (joueurs + mannequins) proches d'un point (distance horizontale, tolérance verticale)
local function charactersNear(pos: Vector3, radius: number)
	local out = {}
	local function consider(c)
		local r = rootOf(c)
		if r then
			local d = r.Position - pos
			if Vector3.new(d.X, 0, d.Z).Magnitude <= radius and math.abs(d.Y) <= radius + 4 then
				table.insert(out, c)
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			consider(p.Character)
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		for _, d in ipairs(dummies:GetChildren()) do
			if d:IsA("Model") then
				consider(d)
			end
		end
	end
	return out
end
CartoonFX.charactersNear = charactersNear

local function nearMe(pos: Vector3, radius: number): boolean
	local r = rootOf(myChar())
	return r ~= nil and (r.Position - pos).Magnitude <= radius
end

-- pose un contexte (attaquant, victime) sur le thread courant pendant fn(...) : les mots créés
-- de façon synchrone dans fn sont filtrés selon ce contexte (les task.delay internes retombent sur la déduction)
function CartoonFX.withContext(a, v, fn, ...)
	local th = coroutine.running()
	local prev = threadCtx[th]
	threadCtx[th] = { a = a, v = v }
	local ok, err = pcall(fn, ...)
	threadCtx[th] = prev
	if not ok then
		warn("[CartoonFX] handler :", err)
	end
	return ok
end

function CartoonFX.isRelevant(pos: Vector3?, a, v): boolean
	local me = myChar()
	if a == nil and v == nil then
		local c = threadCtx[coroutine.running()]
		if c then
			a, v = c.a, c.v
		end
	end
	if me and (a == me or v == me) then
		return true
	end
	if a ~= nil and v ~= nil then
		return false -- combat entre deux autres personnages
	end
	if v ~= nil then
		return engaged(v) -- dégâts sur quelqu'un (brûlure…) : visible si c'est mon adversaire
	end
	if a ~= nil then
		-- seul le lanceur est connu : visible s'il se bat contre moi ou si le mot est collé à moi
		return engaged(a) or (typeof(pos) == "Vector3" and nearMe(pos, 8))
	end
	if typeof(pos) ~= "Vector3" then
		return true
	end
	-- déduction spatiale
	local u = ultAt(pos)
	if u then
		return ultInvolvesMe(u)
	end
	local list = charactersNear(pos, 7)
	if #list == 0 then
		return true -- mot de décor / d'événement
	end
	for _, m in ipairs(list) do
		if m == me or engaged(m) then
			return true
		end
	end
	return os.clock() - lastLocalCast < 1.6 and nearMe(pos, 50)
end

------------------------------------------------------------------------
-- Onomatopée BD (ComicWords, placée autour du combat)
------------------------------------------------------------------------
local function makeBurst(parent, color: Color3, scale: number, z: number)
	local holder = Instance.new("Frame")
	holder.Name = "Burst"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(scale, scale)
	holder.BackgroundTransparency = 1
	holder.ZIndex = z
	holder.Parent = parent
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = holder
	-- 8 rectangles fins tournés (longueurs alternées) = étoile à 16 pointes + disque central
	for i = 0, 7 do
		local spike = Instance.new("Frame")
		spike.AnchorPoint = Vector2.new(0.5, 0.5)
		spike.Position = UDim2.fromScale(0.5, 0.5)
		spike.Size = UDim2.fromScale(i % 2 == 0 and 1 or 0.78, 0.13)
		spike.Rotation = i * 22.5 + rng:NextNumber(-4, 4)
		spike.BackgroundColor3 = color
		spike.BorderSizePixel = 0
		spike.ZIndex = z
		spike.Parent = holder
	end
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.5, 0.5)
	core.BackgroundColor3 = color
	core.BorderSizePixel = 0
	core.ZIndex = z
	core.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = core
	return holder
end

local function fadeDescendants(root, time)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Frame") then
			tween(d, time, { BackgroundTransparency = 1 })
		elseif d:IsA("TextLabel") then
			tween(d, time, { TextTransparency = 1 })
		elseif d:IsA("UIStroke") then
			tween(d, time, { Transparency = 1 })
		end
	end
end

local ComicWords
local function comicWords()
	if ComicWords == nil then
		local m = script.Parent:FindFirstChild("ComicWords")
		local ok, mod = false, nil
		if m then
			ok, mod = pcall(require, m)
		end
		ComicWords = (ok and type(mod) == "table" and mod.create) and mod or false
	end
	return ComicWords
end

-- place un élément (mot, chiffre) autour du combat ; repli : au-dessus du point
local function placeAround(pos: Vector3, w: number, h: number, opts)
	local CW = comicWords()
	if CW and CW.place then
		local ok, p, drift = pcall(CW.place, pos, w, h, opts)
		if ok and typeof(p) == "Vector3" then
			return p, drift
		end
	end
	return pos + Vector3.new(rng:NextNumber(-1.5, 1.5), 2.5, rng:NextNumber(-1.5, 1.5)), Vector3.yAxis
end

function CartoonFX.word(pos: Vector3, text: string, power: number?, category: string?, opts)
	if typeof(pos) ~= "Vector3" then
		return
	end
	if setting("ComicWords") == false then
		return
	end
	opts = type(opts) == "table" and opts or {}
	if not opts.force and not CartoonFX.isRelevant(pos, opts.a, opts.v) then
		return
	end
	local CW = comicWords()
	if CW then
		local ok, err = pcall(CW.create, pos, text, power, category, opts)
		if ok then
			return
		end
		warn("[ComicWords]", err)
	end
	return CartoonFX.wordLegacy(pos, text, power, category)
end

function CartoonFX.wordLegacy(pos: Vector3, text: string, power: number?, category: string?)
	power = math.clamp(power or 0.4, 0, 1.5)
	local isKO = category == "KO"
	local size = 2.8 + power * 2.8 + (isKO and 3 or 0)
	local life = isKO and 1.2 or 0.65
	local att = anchorAt(placeAround(pos, size * 1.5, size), life + 0.1)
	local bb = billboard(att, size, life + 0.1)
	bb.Size = UDim2.fromScale(size * 1.5, size) -- plus large que haut : le mot déborde de l'étoile, façon BD

	local root = Instance.new("Frame")
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.Position = UDim2.fromScale(0.5, 0.5)
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Rotation = rng:NextNumber(-14, 14)
	root.Parent = bb
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 0
	uiScale.Parent = root

	local burstColor = Words.CategoryBurst[category or ""] or Words.BurstColors[rng:NextInteger(1, #Words.BurstColors)]
	makeBurst(root, Color3.new(0, 0, 0), 1, 1) -- contour noir
	local burst = makeBurst(root, burstColor, 0.9, 2)
	burst.Rotation = rng:NextNumber(0, 30)

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromScale(0.98, 0.5)
	label.BackgroundTransparency = 1
	label.FontFace = PIXEL
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = isKO and Color3.fromRGB(255, 255, 255) or colorForPower(power)
	label.ZIndex = 3
	label.Parent = root
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = isKO and 6 or 4
	stroke.Color = Color3.new(0, 0, 0)
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label

	-- pop : 0 -> 1.3 -> 1, puis disparition qui monte un peu
	task.spawn(function()
		tween(uiScale, 0.08, { Scale = 1.3 }, Enum.EasingStyle.Back)
		task.wait(0.08)
		tween(uiScale, 0.08, { Scale = 1 })
		tween(burst, 0.5, { Rotation = burst.Rotation + rng:NextNumber(-25, 25) })
		task.wait(life - 0.36)
		if bb.Parent then
			tween(uiScale, 0.2, { Scale = 0.75 })
			tween(bb, 0.2, { StudsOffsetWorldSpace = Vector3.new(0, 0.8, 0) })
			fadeDescendants(root, 0.2)
		end
	end)
end

------------------------------------------------------------------------
-- Étoiles d'impact + lignes de vitesse
------------------------------------------------------------------------
function CartoonFX.impact(pos: Vector3, power: number?)
	power = math.clamp(power or 0.4, 0, 1.5)
	local size = 6 + power * 5
	local att = anchorAt(pos, 0.6)
	local bb = billboard(att, size, 0.6)
	bb.AlwaysOnTop = false
	local stars = qn(4 + math.floor(power * 4))
	for i = 1, stars do
		local a = (i / stars) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local star = Instance.new("TextLabel")
		star.AnchorPoint = Vector2.new(0.5, 0.5)
		star.Position = UDim2.fromScale(0.5, 0.5)
		star.Size = UDim2.fromScale(0.16, 0.16)
		star.BackgroundTransparency = 1
		star.Text = "★"
		star.TextScaled = true
		star.Font = Enum.Font.GothamBlack
		star.TextColor3 = (i % 2 == 0) and Color3.fromRGB(255, 235, 60) or Color3.fromRGB(255, 255, 255)
		star.Rotation = rng:NextNumber(0, 90)
		star.Parent = bb
		local st = Instance.new("UIStroke")
		st.Thickness = 2
		st.Parent = star
		local r = rng:NextNumber(0.32, 0.46)
		tween(star, 0.45, {
			Position = UDim2.fromScale(0.5 + math.cos(a) * r, 0.5 + math.sin(a) * r),
			Rotation = star.Rotation + 180,
			TextTransparency = 1,
			Size = UDim2.fromScale(0.08, 0.08),
		})
		tween(st, 0.45, { Transparency = 1 })
	end
	-- lignes de vitesse
	local n = qn(8)
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.18, 0.5 + math.sin(a) * 0.18)
		line.Size = UDim2.fromScale(0.22, 0.025)
		line.Rotation = math.deg(a)
		line.BackgroundColor3 = Color3.new(1, 1, 1)
		line.BorderSizePixel = 0
		line.Parent = bb
		tween(line, 0.25, {
			Position = UDim2.fromScale(0.5 + math.cos(a) * 0.45, 0.5 + math.sin(a) * 0.45),
			Size = UDim2.fromScale(0.08, 0.012),
			BackgroundTransparency = 1,
		})
	end
end

-- éclat de coup : étoile blanche à 4 branches (billboard, non AlwaysOnTop) + étincelles dans l'axe du coup
function CartoonFX.hitSpark(pos: Vector3, dir: Vector3?, power: number?, color: Color3?)
	local pw = math.clamp(power or 0.4, 0, 1.5)
	local size = 3 + pw * 3.5
	local att = anchorAt(pos, 0.3)
	local bb = billboard(att, size, 0.3)
	bb.AlwaysOnTop = false
	local holder = Instance.new("Frame")
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Rotation = rng:NextNumber(0, 90)
	holder.Parent = bb
	local sc = Instance.new("UIScale")
	sc.Scale = 0.3
	sc.Parent = holder
	for i = 0, 1 do
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromScale(0.5, 0.5)
		f.Size = UDim2.fromScale(1, 0.12)
		f.Rotation = i * 90
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.Parent = holder
		local g = Instance.new("UIGradient")
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		tween(f, 0.16, { BackgroundTransparency = 1 })
	end
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.32, 0.32)
	core.BackgroundColor3 = color or Color3.fromRGB(255, 250, 200)
	core.BorderSizePixel = 0
	core.Parent = holder
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0.5, 0)
	cc.Parent = core
	tween(core, 0.14, { BackgroundTransparency = 1, Size = UDim2.fromScale(0.6, 0.6) })
	tween(sc, 0.09, { Scale = 1.15 }, Enum.EasingStyle.Back)
	tween(holder, 0.2, { Rotation = holder.Rotation + 25 })
	-- étincelles directionnelles
	local n = qn(6 + math.floor(pw * 10))
	local a2 = Instance.new("Attachment")
	if dir and dir.Magnitude > 0.05 then
		-- +Y de l'attachment = direction du coup (EmissionDirection Top)
		a2.WorldCFrame = CFrame.lookAt(pos, pos + dir.Unit) * CFrame.Angles(-math.pi / 2, 0, 0)
	else
		a2.WorldPosition = pos
	end
	a2.Parent = workspace.Terrain
	Debris:AddItem(a2, 0.8)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Color3.new(1, 1, 1), color or Color3.fromRGB(255, 220, 90))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7 + pw * 0.5), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.12, 0.3)
	pe.Speed = NumberRange.new(30, 55)
	pe.SpreadAngle = (dir and dir.Magnitude > 0.05) and Vector2.new(38, 38) or Vector2.new(180, 180)
	pe.Drag = 8
	pe.Rate = 0
	pe.Parent = a2
	pe:Emit(n)
end

------------------------------------------------------------------------
-- Chiffres de dégâts (placés à côté du corps, du côté opposé au dernier mot)
------------------------------------------------------------------------
function CartoonFX.damageNumber(pos: Vector3, amount: number, power: number?, opts)
	if typeof(pos) ~= "Vector3" or type(amount) ~= "number" then
		return
	end
	if setting("DamageNumbers") == false then
		return
	end
	opts = type(opts) == "table" and opts or {}
	if not opts.force and not CartoonFX.isRelevant(pos, opts.a, opts.v) then
		return
	end
	local pw = power or 0.4
	local big = pw >= 0.7
	local size = 2.4 + pw * 1.8
	local placed, drift = placeAround(pos, size * 0.8, size * 0.45, { small = true, prefer = "low", avoid = opts.avoid, a = opts.a, v = opts.v })
	local att = anchorAt(placed, 1.05)
	local bb = billboard(att, size, 1.05)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.5)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Rotation = rng:NextNumber(-8, 8)
	label.BackgroundTransparency = 1
	label.FontFace = PIXEL
	label.TextScaled = true
	label.Text = tostring(math.floor(amount + 0.5))
	-- dégradé 2 tons façon arcade (blanc -> jaune, ou jaune -> rouge pour les gros coups)
	label.TextColor3 = Color3.new(1, 1, 1)
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = big and ColorSequence.new(Color3.fromRGB(255, 235, 80), Color3.fromRGB(255, 60, 50))
		or ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 215, 90))
	g.Parent = label
	label.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = big and 4 or 3
	st.Color = UITheme.Colors.Ink
	st.LineJoinMode = Enum.LineJoinMode.Miter
	st.Parent = label
	local sc = Instance.new("UIScale")
	sc.Scale = 0.2
	sc.Parent = label
	tween(sc, 0.1, { Scale = big and 1.6 or 1.25 }, Enum.EasingStyle.Back)
	task.delay(0.1, function()
		tween(sc, 0.12, { Scale = 1 })
	end)
	-- jaillit du point d'impact puis dérive vers l'extérieur et monte
	local d = typeof(drift) == "Vector3" and drift or Vector3.yAxis
	bb.StudsOffsetWorldSpace = (pos - placed) * 0.5
	tween(bb, 0.14, { StudsOffsetWorldSpace = Vector3.zero }, Enum.EasingStyle.Quad)
	task.delay(0.14, function()
		if bb.Parent then
			tween(bb, 0.8, { StudsOffsetWorldSpace = d * 0.7 + Vector3.new(0, 1.2, 0) }, Enum.EasingStyle.Sine)
		end
	end)
	task.delay(0.6, function()
		tween(label, 0.35, { TextTransparency = 1 })
		tween(st, 0.35, { Transparency = 1 })
	end)
end

------------------------------------------------------------------------
-- Flash blanc sur la victime
------------------------------------------------------------------------
function CartoonFX.flash(character: Model, duration: number?, color: Color3?)
	if not character or typeof(character) ~= "Instance" then
		return
	end
	local hl = Instance.new("Highlight")
	hl.FillColor = color or Color3.new(1, 1, 1)
	hl.FillTransparency = reducedFlashes() and 0.55 or 0.12
	hl.OutlineColor = Color3.new(1, 1, 1)
	hl.OutlineTransparency = 1
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Adornee = character
	hl.Parent = character
	Debris:AddItem(hl, duration or 0.08)
end

------------------------------------------------------------------------
-- Nuage de fumée cartoon
------------------------------------------------------------------------
function CartoonFX.puff(pos: Vector3, size: number?)
	size = size or 1
	local n = qn(6)
	for i = 1, n do
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(245, 245, 245)
		local s = rng:NextNumber(1, 1.8) * size
		p.Size = Vector3.one * s
		local a = (i / n) * math.pi * 2
		p.Position = pos + Vector3.new(math.cos(a), 0.2, math.sin(a)) * 0.6 * size
		p.Parent = fxFolder()
		tween(p, 0.45, {
			Position = pos + Vector3.new(math.cos(a) * 2.6, rng:NextNumber(0.4, 1.4), math.sin(a) * 2.6) * size,
			Size = Vector3.one * s * 1.8,
			Transparency = 1,
		})
		Debris:AddItem(p, 0.5)
	end
end

------------------------------------------------------------------------
-- Étoile qui scintille (« ding! »)
------------------------------------------------------------------------
function CartoonFX.twinkle(pos: Vector3)
	local att = anchorAt(pos, 1)
	local bb = billboard(att, 6, 1)
	local star = Instance.new("TextLabel")
	star.AnchorPoint = Vector2.new(0.5, 0.5)
	star.Position = UDim2.fromScale(0.5, 0.5)
	star.Size = UDim2.fromScale(1, 1)
	star.BackgroundTransparency = 1
	star.Text = "✦"
	star.Font = Enum.Font.GothamBlack
	star.TextScaled = true
	star.TextColor3 = Color3.fromRGB(255, 250, 170)
	star.Parent = bb
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = star
	tween(sc, 0.18, { Scale = 1.4 }, Enum.EasingStyle.Back)
	tween(star, 0.9, { Rotation = 200 })
	task.delay(0.35, function()
		tween(sc, 0.4, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	end)
	CartoonFX.sound("Ding", nil, 0.6)
end

------------------------------------------------------------------------
-- Vertige, sueur, alerte (attachés à la tête)
------------------------------------------------------------------------
local dizzyState = {} -- [character] = {bb, untilT}
function CartoonFX.dizzy(character: Model, duration: number)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	duration = tonumber(duration) or 1
	local st = dizzyState[character]
	if st and st.bb.Parent then
		st.untilT = math.max(st.untilT, os.clock() + duration)
		return
	end
	local bb = billboard(head, 4)
	bb.StudsOffset = Vector3.new(0, 1.6, 0)
	bb.AlwaysOnTop = false
	local stars = {}
	for i = 1, 3 do
		local s = Instance.new("TextLabel")
		s.AnchorPoint = Vector2.new(0.5, 0.5)
		s.Size = UDim2.fromScale(0.28, 0.28)
		s.BackgroundTransparency = 1
		s.Text = "★"
		s.Font = Enum.Font.GothamBlack
		s.TextScaled = true
		s.TextColor3 = Color3.fromRGB(255, 225, 50)
		s.Parent = bb
		local k = Instance.new("UIStroke")
		k.Thickness = 2
		k.Parent = s
		stars[i] = s
	end
	st = { bb = bb, untilT = os.clock() + duration, stars = stars }
	dizzyState[character] = st
end

local sweatState = {}
function CartoonFX.setSweat(character: Model, on: boolean)
	local st = sweatState[character]
	if on and not st then
		local head = character:FindFirstChild("Head")
		if not head then
			return
		end
		local bb = billboard(head, 3)
		bb.StudsOffset = Vector3.new(0, 0.3, 0)
		bb.AlwaysOnTop = false
		local drops = {}
		for i = 1, 2 do
			local d = Instance.new("TextLabel")
			d.AnchorPoint = Vector2.new(0.5, 0.5)
			d.Size = UDim2.fromScale(0.3, 0.3)
			d.BackgroundTransparency = 1
			d.Text = "💧"
			d.TextScaled = true
			d.Parent = bb
			drops[i] = d
		end
		sweatState[character] = { bb = bb, drops = drops }
	elseif not on and st then
		st.bb:Destroy()
		sweatState[character] = nil
	end
end

function CartoonFX.alert(character: Model)
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local bb = billboard(head, 3, 0.8)
	bb.StudsOffset = Vector3.new(0, 2.4, 0)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = "!"
	l.FontFace = PIXEL
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 60, 60)
	l.Parent = bb
	local k = Instance.new("UIStroke")
	k.Thickness = 4
	k.Parent = l
	local sc = Instance.new("UIScale")
	sc.Scale = 0
	sc.Parent = l
	tween(sc, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
end

if RunService:IsClient() then
	RunService.RenderStepped:Connect(function()
		local now = os.clock()
		for character, st in pairs(dizzyState) do
			if not st.bb.Parent or now > st.untilT then
				st.bb:Destroy()
				dizzyState[character] = nil
			else
				for i, s in ipairs(st.stars) do
					local a = now * 6 + i * (math.pi * 2 / 3)
					s.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.36, 0.5 + math.sin(a) * 0.12)
					s.ZIndex = math.sin(a) > 0 and 2 or 1
				end
			end
		end
		for character, st in pairs(sweatState) do
			if not st.bb.Parent then
				sweatState[character] = nil
			else
				for i, d in ipairs(st.drops) do
					local phase = (now * 1.6 + i * 0.5) % 1
					local side = i == 1 and 0.12 or 0.88
					d.Position = UDim2.fromScale(side, 0.2 + phase * 0.6)
					d.TextTransparency = phase
				end
			end
		end
	end)
end

------------------------------------------------------------------------
-- « JUICE » : gel réel, zoom caméra, impact frames, ondes de choc, éclats, étincelles, lignes de vitesse
------------------------------------------------------------------------
local function involvesLocal(model)
	return model ~= nil and localPlayer ~= nil and model == localPlayer.Character
end
CartoonFX.involvesLocal = involvesLocal

-- gel réel du personnage local (hit-stop physique) : on ancre son HumanoidRootPart
local frozenUntil = 0
function CartoonFX.freezeLocal(duration: number)
	local c = localPlayer.Character
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	frozenUntil = math.max(frozenUntil, os.clock() + duration)
	if root.Anchored then
		return
	end
	local vel = root.AssemblyLinearVelocity
	root.Anchored = true
	task.spawn(function()
		while os.clock() < frozenUntil do
			task.wait()
		end
		if root.Parent then
			root.Anchored = false
			root.AssemblyLinearVelocity = vel * 0.3
		end
	end)
end

-- coup de zoom (FOV) — désactivable (réglage FOVKick)
local fovBase, fovKick = nil, 0
function CartoonFX.fovKick(amount: number)
	if setting("FOVKick") == false then
		return
	end
	fovKick = math.max(fovKick, amount or 0)
end
if RunService:IsClient() then
	RunService:BindToRenderStep("CartoonFOV", Enum.RenderPriority.Camera.Value + 2, function(dt)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		if fovKick > 0.05 then
			fovBase = fovBase or cam.FieldOfView
			cam.FieldOfView = fovBase - fovKick
			fovKick *= math.exp(-dt * 10)
		elseif fovBase then
			cam.FieldOfView = fovBase
			fovBase = nil
			fovKick = 0
		end
	end)
end

-- impact frame : 1–2 images très contrastées (façon anime) ; adouci si « Reduce flashes »
local cc
local ccToken = 0
function CartoonFX.impactFrame(strength: number?)
	strength = strength or 1
	if not cc or not cc.Parent then
		cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "ImpactFrame"
		cc.Parent = game:GetService("Lighting")
	end
	ccToken += 1
	local token = ccToken
	cc.Enabled = true
	if reducedFlashes() then
		cc.Saturation = -0.25
		cc.Contrast = 0.15 * strength
		cc.Brightness = 0
	else
		cc.Saturation = -1
		cc.Contrast = 0.9 * strength
		cc.Brightness = 0.15 * strength
	end
	task.delay(0.045, function()
		if token ~= ccToken then
			return
		end
		cc.Saturation = reducedFlashes() and 0.1 or 0.4
		cc.Contrast = reducedFlashes() and 0.05 or 0.3
		cc.Brightness = 0
		task.delay(0.05, function()
			if token == ccToken then
				cc.Enabled = false
			end
		end)
	end)
end

-- flash « ralenti » (parade parfaite) : teinte froide + désaturation qui revient en douceur ;
-- un seul effet réutilisé, adouci si « Reduce flashes »
local slowCC
local slowToken = 0
function CartoonFX.slowFlash(color: Color3?, dur: number?)
	if not RunService:IsClient() then
		return
	end
	dur = dur or 0.4
	if not slowCC or not slowCC.Parent then
		slowCC = Instance.new("ColorCorrectionEffect")
		slowCC.Name = "SlowFlash"
		slowCC.Parent = game:GetService("Lighting")
	end
	slowToken += 1
	local token = slowToken
	local soft = reducedFlashes()
	slowCC.Enabled = true
	slowCC.TintColor = color or Color3.fromRGB(200, 240, 255)
	slowCC.Brightness = soft and 0.03 or 0.18
	slowCC.Saturation = soft and -0.15 or -0.45
	slowCC.Contrast = soft and 0 or 0.1
	tween(slowCC, dur, { TintColor = Color3.new(1, 1, 1), Brightness = 0, Saturation = 0, Contrast = 0 }, Enum.EasingStyle.Sine)
	task.delay(dur + 0.05, function()
		if token == slowToken and slowCC then
			slowCC.Enabled = false
		end
	end)
end

-- lignes de vitesse plein écran (style manga)
local linesGui
function CartoonFX.speedLines(duration: number?, color: Color3?)
	if not localPlayer then
		return
	end
	if not linesGui or not linesGui.Parent then
		linesGui = Instance.new("ScreenGui")
		linesGui.Name = "SpeedLines"
		linesGui.IgnoreGuiInset = true
		linesGui.ResetOnSpawn = false
		linesGui.DisplayOrder = 5
		linesGui.Parent = localPlayer:WaitForChild("PlayerGui")
	end
	local soft = reducedFlashes()
	local n = qn(soft and 10 or 22)
	for _ = 1, n do
		local a = rng:NextNumber(0, math.pi * 2)
		local l = Instance.new("Frame")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5 + math.cos(a) * 0.55, 0.5 + math.sin(a) * 0.55)
		l.Size = UDim2.fromScale(rng:NextNumber(0.25, 0.45), 0.006)
		l.Rotation = math.deg(a)
		l.BackgroundColor3 = color or Color3.new(1, 1, 1)
		l.BackgroundTransparency = soft and 0.55 or 0.1
		l.BorderSizePixel = 0
		l.Parent = linesGui
		tween(l, duration or 0.3, { Position = UDim2.fromScale(0.5 + math.cos(a) * 0.7, 0.5 + math.sin(a) * 0.7), BackgroundTransparency = 1 })
		Debris:AddItem(l, (duration or 0.3) + 0.05)
	end
end

-- onde de choc au sol (anneau qui s'élargit)
function CartoonFX.shockwave(pos: Vector3, radius: number?, color: Color3?)
	radius = radius or 8
	addLoad(1)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 1, 1)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.SmoothPlastic
	ring.Color = color or Color3.new(1, 1, 1)
	ring.Transparency = 0.2
	ring.Parent = fxFolder()
	tween(ring, 0.35, { Size = Vector3.new(0.15, radius * 2, radius * 2), Transparency = 1 })
	Debris:AddItem(ring, 0.4)
end

-- éclats colorés qui rebondissent (physique locale)
local SHARD_COLORS = { Color3.fromRGB(255, 230, 60), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 110, 70), Color3.fromRGB(110, 210, 255) }
function CartoonFX.shards(pos: Vector3, count: number, colors, speed: number?)
	colors = colors or SHARD_COLORS
	for _ = 1, qn(count or 6) do
		local p = Instance.new("Part")
		p.Size = Vector3.one * rng:NextNumber(0.25, 0.55)
		p.Position = pos + Vector3.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 0.5), rng:NextNumber(-0.5, 0.5))
		p.Color = colors[rng:NextInteger(1, #colors)]
		p.Material = Enum.Material.SmoothPlastic
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CollisionGroup = "Debris"
		p.Parent = fxFolder()
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0.4, 1.2), rng:NextNumber(-1, 1)).Unit
		p.AssemblyLinearVelocity = dir * rng:NextNumber(18, 34) * (speed or 1)
		p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-20, 20), rng:NextNumber(-20, 20), rng:NextNumber(-20, 20))
		Debris:AddItem(p, rng:NextNumber(0.8, 1.3))
	end
end

-- étincelles (particules intégrées à Roblox)
function CartoonFX.sparks(pos: Vector3, count: number?, color: Color3?)
	local att = anchorAt(pos, 1)
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(color or Color3.fromRGB(255, 240, 120))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
	pe.Lifetime = NumberRange.new(0.2, 0.4)
	pe.Speed = NumberRange.new(25, 45)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Drag = 6
	pe.Rate = 0
	pe.Parent = att
	pe:Emit(qn(count or 14))
end

-- GROS IMPACT : flash, double onde de choc au sol, anneau d'air dans l'axe du coup, poussière, débris, fissures
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundAt(pos: Vector3): Vector3
	local ex = {}
	for _, n in ipairs({ "FX", "Dummies", "ActiveItems", "Zones" }) do
		local f = workspace:FindFirstChild(n)
		if f then
			table.insert(ex, f)
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ex, p.Character)
		end
	end
	groundParams.FilterDescendantsInstances = ex
	local r = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -14, 0), groundParams)
	return r and r.Position or (pos - Vector3.new(0, 3, 0)), r ~= nil
end

local function fxPart(props)
	addLoad(1)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = fxFolder()
	return p
end
CartoonFX.fxPart = fxPart

function CartoonFX.bigImpact(pos: Vector3, dir: Vector3?, power: number?, color: Color3?)
	power = math.clamp(power or 1, 0.5, 1.6)
	color = color or Color3.new(1, 1, 1)
	-- flash sphérique
	local flash = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one, Position = pos, Color = Color3.new(1, 1, 1), Transparency = reducedFlashes() and 0.5 or 0.1 })
	tween(flash, 0.18, { Size = Vector3.one * 7 * power, Transparency = 1 })
	Debris:AddItem(flash, 0.2)
	-- anneau d'air perpendiculaire au coup
	if dir and dir.Magnitude > 0.1 then
		local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2, 2), CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi / 2, 0), Color = color, Transparency = 0.15 })
		tween(ring, 0.3, { Size = Vector3.new(0.1, 10 * power, 10 * power), Transparency = 1 })
		Debris:AddItem(ring, 0.32)
		-- traînée de choc qui part dans la direction du coup
		for _ = 1, qn(3) do
			local l = fxPart({ Size = Vector3.new(0.25, 0.25, 3), CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), -1), Color = Color3.new(1, 1, 1), Transparency = 0.2 })
			tween(l, 0.22, { CFrame = l.CFrame * CFrame.new(0, 0, -6 * power), Transparency = 1, Size = Vector3.new(0.1, 0.1, 5) })
			Debris:AddItem(l, 0.25)
		end
	end
	-- au sol : double onde de choc + poussière + débris + fissures
	local ground, hit = groundAt(pos)
	if hit and (pos - ground).Magnitude < 8 then
		CartoonFX.shockwave(ground + Vector3.new(0, 0.15, 0), 9 * power, color)
		task.delay(0.07, function()
			CartoonFX.shockwave(ground + Vector3.new(0, 0.2, 0), 14 * power, Color3.fromRGB(230, 230, 235))
		end)
		local nd = qn(8)
		for i = 1, nd do
			local a = (i / nd) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local d = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(1.2, 2), Position = ground + out * 1.5 + Vector3.new(0, 0.6, 0), Color = Color3.fromRGB(225, 220, 210), Transparency = 0.2 })
			tween(d, 0.55, { Position = ground + out * 7 * power + Vector3.new(0, rng:NextNumber(0.6, 1.8), 0), Size = d.Size * 2.2, Transparency = 1 })
			Debris:AddItem(d, 0.6)
		end
		for _ = 1, qn(5) do
			local a = rng:NextNumber(0, math.pi * 2)
			local crack = fxPart({ Size = Vector3.new(0.25, 0.06, rng:NextNumber(2, 4.5) * power), CFrame = CFrame.new(ground + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -1.6 * power), Color = Color3.fromRGB(40, 40, 45), Transparency = 0.15 })
			task.delay(1.2, function()
				tween(crack, 0.5, { Transparency = 1 })
			end)
			Debris:AddItem(crack, 1.8)
		end
		CartoonFX.shards(ground + Vector3.new(0, 0.5, 0), math.floor(6 * power), { Color3.fromRGB(170, 170, 180), Color3.fromRGB(120, 120, 130) }, 1.1)
	end
end

local function onScreen(pos)
	local cam = workspace.CurrentCamera
	return cam and (cam.CFrame.Position - pos).Magnitude < 70
end

------------------------------------------------------------------------
-- Effet complet d'un coup
-- data = { a = attaquant, v = victime, p = position, c = catégorie, pw = puissance, d = dégâts,
--          w = liste de mots, m = matière, ko = bool, r = réaction ("Light"|"Heavy"|"Launch"|"Slam"), fin = finisher }
------------------------------------------------------------------------
function CartoonFX.hit(data)
	if type(data) ~= "table" then
		return
	end
	local pos = data.p
	if typeof(pos) ~= "Vector3" then
		local r = rootOf(data.v)
		if not r then
			return
		end
		pos = r.Position
	end
	local category = data.c or "Light"
	local power = tonumber(data.pw) or 0.4
	local heavy = category == "Heavy" or data.ko or data.fin
	local list = (type(data.w) == "table" and #data.w > 0) and data.w or Words[category] or Words.Light
	local text = list[rng:NextInteger(1, #list)]
	local mine = involvesLocal(data.a) or involvesLocal(data.v)
	CartoonFX.noteEngage(data.a, data.v)
	local ctx = { a = data.a, v = data.v, avoid = { data.a, data.v } }

	local dir
	local ar, vr = rootOf(data.a), rootOf(data.v)
	if ar and vr then
		dir = vr.Position - ar.Position
	end

	CartoonFX.word(pos, text, power + (data.fin and 0.4 or 0), category, ctx)
	CartoonFX.impact(pos, power)
	CartoonFX.hitSpark(pos, dir, power + (heavy and 0.4 or 0))
	if type(data.d) == "number" and data.d > 0 then
		CartoonFX.damageNumber(pos, data.d, power, ctx)
	end
	CartoonFX.flash(data.v, heavy and 0.12 or 0.05)
	if heavy then
		-- LOURD / FINISHER : gros impact, onde d'air dans l'axe du coup, double onde au sol (bigImpact)
		CartoonFX.sparks(pos, 18)
		CartoonFX.shards(pos, 10, nil, 1.2)
		CartoonFX.bigImpact(pos, dir, power + (data.fin and 0.3 or 0) + (data.ko and 0.4 or 0))
		if dir and (data.fin or data.ko) then
			CartoonFX.airRing(pos, dir, 11, Color3.fromRGB(255, 245, 220), 0.3)
			task.delay(0.06, CartoonFX.airRing, pos, dir, 7, Color3.new(1, 1, 1), 0.25)
		end
		if mine then
			CartoonFX.light(pos, Color3.fromRGB(255, 240, 200), 14, 3, 0.18)
		end
	else
		-- LÉGER (M1) : petite étincelle sèche, peu de débris
		CartoonFX.sparks(pos, 6)
		CartoonFX.shards(pos, 3, nil, 0.7)
	end
	-- PLAQUÉ AU SOL : sol fendu + poussière
	if data.r == "Slam" then
		local g = groundAt(pos)
		if (pos - g).Magnitude < 8 then
			CartoonFX.cracks(g, 5, 3.5, 1)
			CartoonFX.dust(g, 6, nil, 8)
			CartoonFX.sound("GroundCrack", g, 0.8, 0.95)
		end
	end

	-- réaction de la victime
	if data.v then
		local r = data.r or "Light"
		if r == "Launch" then
			anim(data.v, "Launch")
		elseif r == "Heavy" or r == "Slam" then
			anim(data.v, "HitHeavy")
		else
			anim(data.v, rng:NextNumber() < 0.5 and "HitLight" or "HitLight2")
		end
	end

	-- sons superposés : claque principale + corps (grave) + gros impact + matière + « oof »
	local vol = mine and 1 or 0.75
	local base = Sounds.Category[category] or "Punch"
	if not heavy and base == "Punch" then
		base = "PunchLight" -- M1 : claque courte et aiguë
	end
	CartoonFX.sound(base, pos, (0.9 + power * 0.5) * vol, heavy and 0.9 or 1.12)
	if heavy then
		-- couche grave (basse + corps) sous le gros impact
		CartoonFX.sound("Thud", pos, 0.6 * vol, 0.78)
		CartoonFX.sound("LowThump", pos, 0.9 * vol, 0.92)
		CartoonFX.sound("BigImpact", pos, 1.1 * vol)
		CartoonFX.sound("AnimeHit", pos, 0.7 * vol)
		if data.fin or data.ko then
			CartoonFX.sound("Boom", pos, 0.6 * vol, 1.05)
			CartoonFX.sound("Explosion", pos, 0.4 * vol, 1.35)
		end
	else
		CartoonFX.sound("Thud", pos, 0.25 * vol, 1.3)
	end
	if data.m and Sounds.MaterialHit[data.m] then
		CartoonFX.sound(Sounds.MaterialHit[data.m], pos, 1.0 * vol)
	end
	if data.r == "Launch" then
		CartoonFX.sound("Uppercut", pos, 1 * vol)
		CartoonFX.sound("Boing", pos, 0.6 * vol)
	end
	if rng:NextNumber() < (heavy and 0.6 or 0.2) then
		CartoonFX.sound("Oof", pos, 0.8 * vol)
	end

	-- hit-stop : animations gelées pour tout le monde, physique gelée pour le joueur concerné
	local hs = data.ko and combatValue("HitStop", "KO", 0.16)
		or (heavy and combatValue("HitStop", "Heavy", 0.1))
		or combatValue("HitStop", "Light", 0.05)
	freezeAnim(data.a, hs)
	freezeAnim(data.v, hs)
	if mine then
		CartoonFX.freezeLocal(hs)
	end

	-- caméra
	local shake = data.ko and combatValue("Shake", "KO", 1.2) or (heavy and combatValue("Shake", "Heavy", 0.7)) or combatValue("Shake", "Light", 0.25)
	local fov = data.ko and combatValue("FOVKick", "KO", 10) or (heavy and combatValue("FOVKick", "Heavy", 6)) or combatValue("FOVKick", "Light", 2)
	if mine then
		CartoonFX.shake(shake)
		CartoonFX.fovKick(fov)
		if heavy then
			CartoonFX.impactFrame(data.ko and 1.3 or 1)
			CartoonFX.speedLines(0.3)
		end
	elseif onScreen(pos) then
		CartoonFX.shake(shake * 0.3)
	end

	if data.ko then
		CartoonFX.ko(data.v, pos, mine, data.a)
	end
end

-- K.O. : gel, gros mot, cloche, sifflet de glissade, puis étoile qui scintille là où il a atterri
function CartoonFX.ko(victim: Model?, pos: Vector3, mine: boolean?, attacker: Model?)
	task.delay(0.05, function()
		CartoonFX.word(pos + Vector3.new(0, 1.5, 0), "K.O.!", 1.3, "KO", { a = attacker, v = victim, prefer = "up", avoid = { attacker, victim } })
	end)
	CartoonFX.sound("KO", pos, 1)
	CartoonFX.sound("BigImpact", pos, 1.2)
	task.delay(combatValue("HitStop", "KO", 0.16), function()
		CartoonFX.sound("SlideWhistle", pos, 1)
	end)
	CartoonFX.shards(pos, 18, nil, 1.4)
	CartoonFX.shockwave(pos, 14, Color3.fromRGB(255, 80, 80))
	if mine then
		CartoonFX.speedLines(0.6, Color3.fromRGB(255, 255, 255))
	end
	if victim then
		task.delay(1.1, function()
			local torso = victim:FindFirstChild("Torso") or victim:FindFirstChild("HumanoidRootPart")
			if torso and torso.Parent then
				CartoonFX.twinkle(torso.Position)
			end
		end)
	end
end

-- Objet (ou décor) qui casse
function CartoonFX.breakItem(pos: Vector3, material: string?)
	local list = Words.Break
	CartoonFX.word(pos, list[rng:NextInteger(1, #list)], 0.75, "Break")
	CartoonFX.sound(Sounds.MaterialBreak[material or ""] or "Crash", pos, 1.1)
	if material == "Glass" then
		CartoonFX.sound("GlassBreak", pos, 1)
	end
	CartoonFX.puff(pos, 0.9)
	CartoonFX.shards(pos, 12)
	CartoonFX.sparks(pos, 10, Color3.new(1, 1, 1))
end

------------------------------------------------------------------------
-- Mécaniques de combat
------------------------------------------------------------------------
local GUARD_BLUE = Color3.fromRGB(150, 220, 255)
local GUARD_GLASS = Color3.fromRGB(190, 235, 255)

function CartoonFX.parry(data)
	if type(data) ~= "table" or typeof(data.p) ~= "Vector3" then
		return
	end
	CartoonFX.noteEngage(data.a, data.v)
	CartoonFX.word(data.p, "PARRY!", 1.25, "Parry", { a = data.a, v = data.v, avoid = { data.a, data.v } })
	if data.a and data.a:FindFirstChild("Head") then
		CartoonFX.word(data.a.Head.Position + Vector3.new(0, 2, 0), "STUNNED!", 0.9, "Funny", { a = data.a, v = data.v, prefer = "up", avoid = { data.a, data.v } })
	end
	CartoonFX.sound("Parry", data.p, 1.2)
	CartoonFX.sound("Clang", data.p, 1, 1.15)
	CartoonFX.sound("Ding", data.p, 0.5, 1.3)
	CartoonFX.sparks(data.p, 30, GUARD_BLUE)
	CartoonFX.shockwave(data.p, 9, GUARD_BLUE)
	CartoonFX.flash(data.v, 0.15, Color3.fromRGB(200, 240, 255))
	if data.a then
		anim(data.a, "HitHeavy")
		CartoonFX.dizzy(data.a, 1.1)
	end
	if involvesLocal(data.a) or involvesLocal(data.v) then
		CartoonFX.freezeLocal(0.12)
		CartoonFX.impactFrame(1)
		CartoonFX.fovKick(7)
		CartoonFX.shake(0.6)
		CartoonFX.speedLines(0.35, Color3.fromRGB(170, 230, 255))
	end
end

function CartoonFX.pinned(data)
	if type(data) ~= "table" or typeof(data.p) ~= "Vector3" then
		return
	end
	CartoonFX.noteEngage(data.a, data.v)
	CartoonFX.bigImpact(data.p + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.35, Color3.fromRGB(255, 220, 80))
	CartoonFX.word(data.p + Vector3.new(0, 3, 0), "PINNED!", 1.2, "Heavy", { a = data.a, v = data.v, avoid = { data.a, data.v } })
	CartoonFX.sound("GroundSlam", data.p, 1.3)
	CartoonFX.sound("BigImpact", data.p, 1.2)
	if data.v then
		CartoonFX.dizzy(data.v, 1.4)
	end
	if involvesLocal(data.a) or involvesLocal(data.v) then
		CartoonFX.freezeLocal(0.12)
		CartoonFX.impactFrame(1.2)
		CartoonFX.shake(1.3)
		CartoonFX.fovKick(10)
		CartoonFX.speedLines(0.4)
	end
end

-- coup bloqué : étincelles orientées (normal = direction de rebond, vers l'attaquant) + disque de bouclier
function CartoonFX.blockHit(pos: Vector3, normal: Vector3?, data)
	if typeof(pos) ~= "Vector3" then
		return
	end
	data = type(data) == "table" and data or {}
	local n = (typeof(normal) == "Vector3" and normal.Magnitude > 0.05) and normal.Unit or nil
	if not n then
		local ar, vr = rootOf(data.a), rootOf(data.v or data.character)
		if ar and vr then
			local d = ar.Position - vr.Position
			n = d.Magnitude > 0.05 and d.Unit or nil
		end
	end
	-- disque hexagonal du bouclier qui s'illumine puis s'élargit
	if n then
		local disc = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 2.2, 2.2), CFrame = CFrame.lookAt(pos, pos + n) * CFrame.Angles(0, math.pi / 2, 0), Color = GUARD_GLASS, Material = Enum.Material.Neon, Transparency = 0.25 })
		tween(disc, 0.18, { Size = Vector3.new(0.05, 4.4, 4.4), Transparency = 1 })
		Debris:AddItem(disc, 0.2)
		local a2 = Instance.new("Attachment")
		a2.WorldCFrame = CFrame.lookAt(pos, pos + n) * CFrame.Angles(-math.pi / 2, 0, 0)
		a2.Parent = workspace.Terrain
		Debris:AddItem(a2, 0.7)
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Color3.new(1, 1, 1), GUARD_BLUE)
		pe.LightEmission = 1
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		pe.Lifetime = NumberRange.new(0.15, 0.32)
		pe.Speed = NumberRange.new(28, 48)
		pe.SpreadAngle = Vector2.new(55, 55)
		pe.Acceleration = Vector3.new(0, -40, 0)
		pe.Drag = 5
		pe.Rate = 0
		pe.Parent = a2
		pe:Emit(qn(14))
	else
		CartoonFX.sparks(pos, 10, GUARD_BLUE)
	end
	-- coup encaissé : bruit mat (bois / corps) + petit tintement métallique discret
	CartoonFX.sound("Block", pos, 0.9)
	CartoonFX.sound("BlockThud", pos, 0.8, 0.85)
	CartoonFX.sound("Clang", pos, 0.22, 1.3)
	local me = involvesLocal(data.v or data.character) or involvesLocal(data.a)
	if me then
		CartoonFX.shake(0.18)
	end
end

function CartoonFX.block(data)
	if type(data) ~= "table" or typeof(data.p) ~= "Vector3" then
		return
	end
	CartoonFX.noteEngage(data.a, data.v)
	local n
	if typeof(data.dir) == "Vector3" then
		n = data.dir
	elseif typeof(data.n) == "Vector3" then
		n = data.n
	end
	CartoonFX.blockHit(data.p, n, data)
	-- mot discret, seulement pour les combattants concernés
	if rng:NextNumber() < 0.5 then
		local list = Words.Block or { "BLOCK!" }
		CartoonFX.word(data.p, list[rng:NextInteger(1, #list)], 0.2, "Parry", { a = data.a, v = data.v, avoid = { data.a, data.v } })
	end
	if type(data.d) == "number" and data.d > 0 then
		CartoonFX.damageNumber(data.p, data.d, 0.2, { a = data.a, v = data.v })
	end
end

-- accepte un personnage (nouvelle API) ou un payload { p, v | character, a } (ancienne API)
local function unpackTarget(arg, attacker)
	if typeof(arg) == "Instance" then
		local r = rootOf(arg)
		return arg, attacker, r and (r.Position + Vector3.new(0, 1.5, 0)) or nil
	elseif type(arg) == "table" then
		local c = arg.character or arg.v
		local p = arg.p
		if typeof(p) ~= "Vector3" then
			local r = rootOf(c)
			p = r and (r.Position + Vector3.new(0, 1.5, 0)) or nil
		end
		return c, arg.a or attacker, p
	end
	return nil, attacker, nil
end

-- GARDE BRISÉE : la bulle de garde vitrée apparaît puis vole en éclats
function CartoonFX.guardBreak(arg, attacker)
	local victim, a, p = unpackTarget(arg, attacker)
	if typeof(p) ~= "Vector3" then
		return
	end
	CartoonFX.noteEngage(a, victim)
	local center = p - Vector3.new(0, 0.5, 0)
	local shell = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 6, Position = center, Color = GUARD_GLASS, Material = Enum.Material.Glass, Transparency = 0.45 })
	tween(shell, 0.08, { Size = Vector3.one * 6.6, Transparency = 0.25 })
	task.delay(0.08, function()
		if shell.Parent then
			shell:Destroy()
		end
		-- éclats de verre (coins) projetés vers l'extérieur
		for _ = 1, qn(16) do
			local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 1), rng:NextNumber(-1, 1))
			if dir.Magnitude < 0.05 then
				dir = Vector3.yAxis
			end
			dir = dir.Unit
			local w = Instance.new("WedgePart")
			w.Size = Vector3.new(0.1, rng:NextNumber(0.6, 1.3), rng:NextNumber(0.6, 1.3))
			w.CFrame = CFrame.lookAt(center + dir * 3, center + dir * 4) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
			w.Color = rng:NextNumber() < 0.5 and GUARD_GLASS or Color3.new(1, 1, 1)
			w.Material = Enum.Material.Glass
			w.Transparency = 0.2
			w.CanCollide = false
			w.CanQuery = false
			w.CanTouch = false
			w.CastShadow = false
			w.Massless = true
			w.Parent = fxFolder()
			w.AssemblyLinearVelocity = dir * rng:NextNumber(22, 38) + Vector3.new(0, 8, 0)
			w.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-25, 25), rng:NextNumber(-25, 25), rng:NextNumber(-25, 25))
			task.delay(0.45, function()
				if w.Parent then
					tween(w, 0.3, { Transparency = 1 })
				end
			end)
			Debris:AddItem(w, 0.8)
		end
		CartoonFX.sparks(center, 20, GUARD_BLUE)
		CartoonFX.shockwave(center, 10, GUARD_BLUE)
	end)
	local glist = Words.GuardBreak or { "GUARD BREAK!" }
	CartoonFX.word(p, glist[rng:NextInteger(1, #glist)], 1.1, "KO", { a = a, v = victim, prefer = "up", avoid = { a, victim } })
	CartoonFX.soundLayer({ { "GlassShatter", 1.1 }, { "GlassBreak", 0.8, 1.05, 0.03 }, { "LowThump", 1.1, 0.85 }, { "Clang", 0.6, 0.85 }, { "BigImpact", 0.6, 1.1, 0.04 } }, p)
	if victim then
		CartoonFX.flash(victim, 0.14, GUARD_BLUE)
		CartoonFX.dizzy(victim, 1.5)
		anim(victim, "HitHeavy")
	end
	if involvesLocal(a) or involvesLocal(victim) then
		CartoonFX.freezeLocal(0.08)
		CartoonFX.impactFrame(1)
		CartoonFX.shake(0.8)
		CartoonFX.fovKick(6)
		CartoonFX.speedLines(0.3, GUARD_BLUE)
	end
end

-- PARADE PARFAITE (garde au dernier moment) : éclair cyan, anneau, « PERFECT! », ting aigu
function CartoonFX.perfectBlock(arg, attacker)
	local blocker, a, p = unpackTarget(arg, attacker)
	if typeof(p) ~= "Vector3" then
		return
	end
	CartoonFX.noteEngage(a, blocker)
	local br = rootOf(blocker)
	local front = p
	if br then
		front = br.Position + br.CFrame.LookVector * 1.4 + Vector3.new(0, 0.8, 0)
	end
	local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 1.5, 1.5), CFrame = br and (CFrame.lookAt(front, front + br.CFrame.LookVector) * CFrame.Angles(0, math.pi / 2, 0)) or CFrame.new(front), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.1 })
	tween(ring, 0.22, { Size = Vector3.new(0.05, 8, 8), Transparency = 1 })
	Debris:AddItem(ring, 0.25)
	local orb = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * 1.2, Position = front, Color = GUARD_GLASS, Material = Enum.Material.Neon, Transparency = reducedFlashes() and 0.5 or 0.05 })
	tween(orb, 0.16, { Size = Vector3.one * 4.5, Transparency = 1 })
	Debris:AddItem(orb, 0.18)
	CartoonFX.sparks(front, 24, Color3.fromRGB(220, 245, 255))
	CartoonFX.light(front, GUARD_BLUE, 16, 4, 0.25)
	if blocker then
		CartoonFX.flash(blocker, 0.1, Color3.fromRGB(200, 240, 255))
	end
	local plist = Words.Perfect or { "PERFECT!" }
	CartoonFX.word(front, plist[rng:NextInteger(1, #plist)], 1.0, "Parry", { a = a, v = blocker, avoid = { a, blocker } })
	CartoonFX.soundLayer({ { "Ting", 1.1, 1.15 }, { "Parry", 0.9, 1.1 }, { "Ding", 0.6, 1.4, 0.03 }, { "Clang", 0.4, 1.25 } }, front)
	-- ralenti : les deux combattants figés un court instant (animations), flash froid à l'écran
	freezeAnim(a, 0.14)
	freezeAnim(blocker, 0.14)
	if involvesLocal(a) or involvesLocal(blocker) then
		CartoonFX.slowFlash(Color3.fromRGB(200, 240, 255), 0.4)
		CartoonFX.freezeLocal(0.07)
		CartoonFX.fovKick(5)
		CartoonFX.shake(0.35)
		if not reducedFlashes() then
			CartoonFX.speedLines(0.25, Color3.fromRGB(200, 240, 255))
		end
	end
end

function CartoonFX.wallSplat(data)
	if type(data) ~= "table" or typeof(data.p) ~= "Vector3" then
		return
	end
	CartoonFX.noteEngage(data.a, data.v)
	local ctx = { a = data.a, v = data.v, avoid = { data.a, data.v } }
	CartoonFX.bigImpact(data.p, data.n and -data.n or nil, 1.1)
	CartoonFX.word(data.p, rng:NextNumber() < 0.5 and "SPLAT!" or "CRASH!", 1.1, "Heavy", ctx)
	CartoonFX.sound("WallSplat", data.p, 1.2)
	CartoonFX.sound("BigImpact", data.p, 1)
	CartoonFX.shockwave(data.p, 7)
	CartoonFX.shards(data.p, 16, { Color3.fromRGB(200, 200, 210), Color3.fromRGB(255, 255, 255) }, 1.2)
	CartoonFX.puff(data.p, 1.2)
	if data.d then
		CartoonFX.damageNumber(data.p, data.d, 0.8, ctx)
	end
	if data.v then
		CartoonFX.dizzy(data.v, 1)
	end
	if involvesLocal(data.a) or involvesLocal(data.v) then
		CartoonFX.shake(0.9)
		CartoonFX.impactFrame(0.8)
	end
end

function CartoonFX.slam(data)
	if type(data) ~= "table" or typeof(data.p) ~= "Vector3" then
		return
	end
	local big = not data.small
	CartoonFX.bigImpact(data.p + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), big and 1.4 or 0.9)
	CartoonFX.word(data.p + Vector3.new(0, 1, 0), big and "KABOOM!" or "THOOM!", big and 1.2 or 0.8, "Heavy", { a = data.a, v = data.v, avoid = { data.a, data.v } })
	CartoonFX.sound("GroundSlam", data.p, 1.2)
	CartoonFX.sound("GroundCrack", data.p, big and 1 or 0.7, 0.9)
	CartoonFX.sound("LowThump", data.p, big and 1 or 0.6, 0.85)
	CartoonFX.sound("Rumble", data.p, 0.5)
	CartoonFX.cracks(data.p, big and 7 or 4, big and 5 or 3, 1.3)
	CartoonFX.dust(data.p, big and 9 or 6, nil, big and 12 or 8)
	CartoonFX.shockwave(data.p + Vector3.new(0, 0.3, 0), big and 14 or 9)
	CartoonFX.shockwave(data.p + Vector3.new(0, 0.3, 0), big and 9 or 6, Color3.fromRGB(255, 230, 120))
	CartoonFX.puff(data.p, big and 1.8 or 1.2)
	CartoonFX.shards(data.p, big and 20 or 10, { Color3.fromRGB(180, 180, 190), Color3.fromRGB(240, 240, 240) }, 1.3)
	local cam = workspace.CurrentCamera
	if involvesLocal(data.a) or involvesLocal(data.v) then
		CartoonFX.shake(1.1)
		CartoonFX.impactFrame(1)
		CartoonFX.fovKick(8)
	elseif cam and (cam.CFrame.Position - data.p).Magnitude < 50 then
		CartoonFX.shake(0.5)
	end
end

function CartoonFX.breaker(data)
	if type(data) ~= "table" or typeof(data.p) ~= "Vector3" then
		return
	end
	CartoonFX.word(data.p + Vector3.new(0, 2, 0), "BREAK FREE!", 1.2, "Break", { a = data.a, prefer = "up", avoid = { data.a } })
	CartoonFX.sound("Explosion", data.p, 1.2)
	CartoonFX.shockwave(data.p, 13, Color3.fromRGB(255, 220, 80))
	CartoonFX.puff(data.p, 2)
	CartoonFX.sparks(data.p, 30)
	if involvesLocal(data.a) then
		CartoonFX.shake(0.8)
		CartoonFX.impactFrame(0.8)
	end
end

function CartoonFX.slip(data)
	if type(data) ~= "table" or typeof(data.p) ~= "Vector3" then
		return
	end
	CartoonFX.word(data.p, "SLIP!", 0.6, "Splat", { v = data.v, avoid = { data.v } })
	CartoonFX.sound("Slip", data.p, 1)
	CartoonFX.sound("Water", data.p, 0.6)
	if data.v then
		CartoonFX.dizzy(data.v, 1)
	end
end

function CartoonFX.heal(data)
	if type(data) ~= "table" or typeof(data.p) ~= "Vector3" then
		return
	end
	CartoonFX.word(data.p, data.eat and "NOM!" or "YUM!", 0.4, "Splat", { v = data.v, avoid = { data.v } })
	CartoonFX.sound(data.eat and "Eat" or "Combo", data.p, 1)
	if setting("DamageNumbers") == false or not CartoonFX.isRelevant(data.p, nil, data.v) then
		return
	end
	local att = anchorAt(data.p + Vector3.new(0, 3, 0), 1)
	local bb = billboard(att, 3, 1)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 0.6)
	l.BackgroundTransparency = 1
	l.FontFace = PIXEL
	l.TextScaled = true
	l.Text = "+" .. tostring(math.floor(tonumber(data.d) or 0))
	l.TextColor3 = Color3.fromRGB(90, 255, 120)
	l.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Parent = l
	tween(l, 0.9, { Position = UDim2.fromScale(0, -0.6), TextTransparency = 1 })
	tween(st, 0.9, { Transparency = 1 })
end

-- ancien effet de dash (gardé : CombatController / FXController « Dash »)
function CartoonFX.dash(character: Model)
	local root = rootOf(character)
	if not root then
		return
	end
	CartoonFX.dashFX(character, nil)
	anim(character, "Dash")
end

-- DASH : poussière au départ, lignes de vent derrière, traînée sur le torse, anneau d'air, whoosh
function CartoonFX.dashFX(character: Model, direction: Vector3?)
	local root = rootOf(character)
	if not root then
		return
	end
	local dir = direction
	if typeof(dir) ~= "Vector3" or dir.Magnitude < 0.05 then
		local v = root.AssemblyLinearVelocity
		v = Vector3.new(v.X, 0, v.Z)
		dir = v.Magnitude > 4 and v or root.CFrame.LookVector
	end
	dir = Vector3.new(dir.X, 0, dir.Z)
	if dir.Magnitude < 0.05 then
		dir = Vector3.new(0, 0, -1)
	end
	dir = dir.Unit
	local feetPos = root.Position - Vector3.new(0, 2.6, 0)
	CartoonFX.puff(feetPos - dir * 0.8, 0.7)
	CartoonFX.airRing(root.Position - dir * 1.2, -dir, 5, Color3.new(1, 1, 1), 0.2)
	-- lignes de vent (repère du perso, laissées derrière)
	for _ = 1, qn(5) do
		local off = Vector3.new(rng:NextNumber(-1.4, 1.4), rng:NextNumber(-1.8, 1.6), 0)
		local cf = CFrame.lookAt(root.Position, root.Position + dir)
		local start = cf * CFrame.new(off.X, off.Y, 1.5)
		local l = fxPart({ Size = Vector3.new(0.12, 0.12, rng:NextNumber(2.5, 4)), CFrame = start, Color = Color3.new(1, 1, 1), Transparency = 0.35 })
		tween(l, 0.25, { CFrame = start * CFrame.new(0, 0, 3), Size = Vector3.new(0.04, 0.04, 1), Transparency = 1 })
		Debris:AddItem(l, 0.27)
	end
	CartoonFX.trailOn(character:FindFirstChild("Torso") or root, Color3.fromRGB(235, 245, 255), 0.3, -1, 2)
	CartoonFX.sound("Dash", root.Position, 0.8)
	CartoonFX.sound("DashWhoosh", root.Position, 0.75, 1.05)
	if involvesLocal(character) then
		CartoonFX.fovKick(3)
	end
end

-- personnage qui retombe au sol (knockdown) : poussière en anneau, onde, « thud »
function CartoonFX.knockdown(arg)
	local pos
	if typeof(arg) == "Vector3" then
		pos = arg
	else
		local r = rootOf(arg)
		pos = r and r.Position or nil
	end
	if not pos then
		return
	end
	local g = groundAt(pos)
	CartoonFX.dust(g, 5, nil, 9)
	CartoonFX.cracks(g, 3, 2.2, 0.8)
	CartoonFX.shockwave(g + Vector3.new(0, 0.12, 0), 5, Color3.fromRGB(235, 230, 220))
	CartoonFX.sound("Thud", g, 0.9, 0.85)
	CartoonFX.sound("GroundCrack", g, 0.45, 1.1)
	if typeof(arg) == "Instance" and involvesLocal(arg) then
		CartoonFX.shake(0.3)
	end
end

------------------------------------------------------------------------
-- AIDES VFX DES KITS (ajoutées pour les attaques de personnages ; n'altèrent rien d'autre)
-- slashArc, cracks, debris, light, pillar, trailOn, swirl, implode, airRing, bigTelegraph, casterShake, dust, quake, beam
------------------------------------------------------------------------
function CartoonFX.groundPos(pos: Vector3): Vector3
	local g = groundAt(pos)
	return g
end

-- arc de taillade : cf = repère (le personnage), a0 -> a1 en degrés (0 = devant, + = vers la droite), tilt en degrés (90 = vertical)
function CartoonFX.slashArc(cf: CFrame, radius: number?, color: Color3?, a0: number?, a1: number?, dur: number?, tilt: number?, width: number?)
	radius = radius or 5
	dur = dur or 0.12
	width = width or 0.45
	a0, a1 = a0 or -80, a1 or 80
	local base = cf * CFrame.Angles(0, 0, math.rad(tilt or 0))
	local n = 10
	if CartoonFX.quality() < 0.5 then
		n = 6
	end
	for i = 0, n do
		local a = math.rad(a0 + (a1 - a0) * i / n)
		task.delay(dur * i / n, function()
			local seg = fxPart({ Size = Vector3.new(radius * 0.4, width, 0.3), CFrame = base * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, -radius), Color = color or Color3.new(1, 1, 1), Transparency = 0.05 })
			local core = fxPart({ Size = Vector3.new(radius * 0.36, width * 0.45, 0.32), CFrame = seg.CFrame, Color = Color3.new(1, 1, 1), Transparency = 0.1 })
			tween(seg, 0.22, { Size = Vector3.new(radius * 0.5, 0.05, 0.08), Transparency = 1 })
			tween(core, 0.14, { Size = Vector3.new(radius * 0.4, 0.04, 0.05), Transparency = 1 })
			Debris:AddItem(seg, 0.24)
			Debris:AddItem(core, 0.16)
		end)
	end
end

-- fissures au sol en étoile (avec branches)
function CartoonFX.cracks(pos: Vector3, count: number?, length: number?, life: number?)
	local g = groundAt(pos)
	count = qn(count or 6)
	life = life or 1.4
	local dark = Color3.fromRGB(35, 35, 40)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local len = (length or 5) * rng:NextNumber(0.6, 1.2)
		local c = fxPart({ Size = Vector3.new(rng:NextNumber(0.22, 0.4), 0.07, len), CFrame = CFrame.new(g + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -len / 2 - 0.5), Color = dark })
		local b = fxPart({ Size = Vector3.new(0.16, 0.07, len * 0.5), CFrame = c.CFrame * CFrame.new(0, 0, -len * 0.2) * CFrame.Angles(0, rng:NextNumber(-0.9, 0.9), 0) * CFrame.new(0, 0, -len * 0.25), Color = dark })
		for _, p in ipairs({ c, b }) do
			task.delay(life, function()
				tween(p, 0.5, { Transparency = 1 })
			end)
			Debris:AddItem(p, life + 0.55)
		end
	end
end

-- gros blocs de sol projetés (physique locale)
function CartoonFX.debris(pos: Vector3, count: number?, colors, speed: number?, size: number?)
	colors = colors or { Color3.fromRGB(170, 170, 180), Color3.fromRGB(120, 120, 130) }
	for _ = 1, qn(count or 6) do
		local p = Instance.new("Part")
		p.Size = Vector3.new(rng:NextNumber(0.6, 1.3), rng:NextNumber(0.4, 0.9), rng:NextNumber(0.6, 1.3)) * (size or 1)
		p.CFrame = CFrame.new(pos + Vector3.new(rng:NextNumber(-1, 1), 0.7, rng:NextNumber(-1, 1))) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0)
		p.Color = colors[rng:NextInteger(1, #colors)]
		p.Material = Enum.Material.SmoothPlastic
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CollisionGroup = "Debris"
		p.Parent = fxFolder()
		local dir = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(1.2, 2.2), rng:NextNumber(-1, 1)).Unit
		p.AssemblyLinearVelocity = dir * rng:NextNumber(20, 36) * (speed or 1)
		p.AssemblyAngularVelocity = Vector3.new(rng:NextNumber(-15, 15), rng:NextNumber(-15, 15), rng:NextNumber(-15, 15))
		task.delay(1.1, function()
			if p.Parent then
				tween(p, 0.35, { Transparency = 1 })
			end
		end)
		Debris:AddItem(p, 1.5)
	end
end

-- éclair de lumière bref
function CartoonFX.light(pos: Vector3, color: Color3?, range: number?, brightness: number?, dur: number?)
	dur = dur or 0.25
	local att = anchorAt(pos, dur + 0.05)
	local l = Instance.new("PointLight")
	l.Color = color or Color3.new(1, 1, 1)
	l.Range = range or 16
	l.Brightness = brightness or 4
	l.Shadows = false
	l.Parent = att
	tween(l, dur, { Brightness = 0 })
end

-- colonne d'énergie verticale qui se resserre
function CartoonFX.pillar(pos: Vector3, radius: number?, height: number?, color: Color3?, dur: number?)
	radius, height, dur = radius or 2, height or 12, dur or 0.35
	local g = groundAt(pos)
	local p = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, radius * 2, radius * 2), CFrame = CFrame.new(g + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = color or Color3.new(1, 1, 1), Transparency = 0.25 })
	tween(p, dur, { Size = Vector3.new(height * 1.25, 0.2, 0.2), Transparency = 1 })
	Debris:AddItem(p, dur + 0.05)
end

-- traînée attachée à une part (bras, accessoire) pendant dur secondes
function CartoonFX.trailOn(part: BasePart?, color: Color3?, dur: number?, offset: number?, width: number?)
	if not part then
		return
	end
	dur = dur or 0.5
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position = Vector3.new(0, -(offset or 0.6), 0)
	a1.Position = Vector3.new(0, -(offset or 0.6) - (width or 1.1), 0)
	a0.Parent, a1.Parent = part, part
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Lifetime = 0.2
	tr.Color = ColorSequence.new(color or Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	tr.Transparency = NumberSequence.new(0.1, 1)
	tr.WidthScale = NumberSequence.new(1, 0.15)
	tr.LightEmission = 0.5
	tr.Parent = part
	Debris:AddItem(tr, dur)
	Debris:AddItem(a0, dur + 0.25)
	Debris:AddItem(a1, dur + 0.25)
end

-- tourbillon de petites parts qui montent en spirale
function CartoonFX.swirl(pos: Vector3, radius: number?, height: number?, colors, count: number?, dur: number?)
	radius, count, dur = radius or 3, qn(count or 12), dur or 0.5
	colors = colors or { Color3.new(1, 1, 1) }
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		local p = fxPart({ Size = Vector3.one * rng:NextNumber(0.35, 0.7), CFrame = CFrame.new(pos + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)), Color = colors[rng:NextInteger(1, #colors)] })
		local a2 = a + 2.4
		tween(p, dur, { CFrame = CFrame.new(pos + Vector3.new(math.cos(a2) * radius * 0.3, height or 5, math.sin(a2) * radius * 0.3)) * CFrame.Angles(2, 2, 0), Transparency = 1, Size = Vector3.one * 0.15 })
		Debris:AddItem(p, dur + 0.05)
	end
end

-- implosion : traits aspirés vers un point (charge d'énergie)
function CartoonFX.implode(pos: Vector3, radius: number?, colors, count: number?, dur: number?)
	radius, count, dur = radius or 6, qn(count or 10), dur or 0.25
	colors = colors or { Color3.new(1, 1, 1) }
	for _ = 1, count do
		local off = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.4, 1), rng:NextNumber(-1, 1)).Unit * radius
		local p = fxPart({ Size = Vector3.new(0.18, 0.18, rng:NextNumber(1, 2.2)), CFrame = CFrame.lookAt(pos + off, pos), Color = colors[rng:NextInteger(1, #colors)], Transparency = 0.1 })
		tween(p, dur, { CFrame = CFrame.lookAt(pos + off * 0.1, pos), Size = Vector3.new(0.08, 0.08, 0.4), Transparency = 0.7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(p, dur + 0.02)
	end
end

-- anneau d'air orienté (coup qui part dans une direction)
function CartoonFX.airRing(pos: Vector3, dir: Vector3, size: number?, color: Color3?, dur: number?)
	if not dir or dir.Magnitude < 0.05 then
		return
	end
	dir = dir.Unit
	dur = dur or 0.25
	local ring = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 1.5, 1.5), CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.pi / 2, 0), Color = color or Color3.new(1, 1, 1), Transparency = 0.15 })
	tween(ring, dur, { Size = Vector3.new(0.08, size or 8, size or 8), Transparency = 1, CFrame = ring.CFrame + dir * 2.5 })
	Debris:AddItem(ring, dur + 0.03)
end

-- grande alerte au sol : disque, bord, anneau blanc qui se resserre jusqu'à l'impact
function CartoonFX.bigTelegraph(pos: Vector3, radius: number, dur: number, color: Color3?)
	color = color or Color3.fromRGB(255, 70, 60)
	local UP = CFrame.Angles(0, 0, math.pi / 2)
	local disc = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, radius * 2, radius * 2), CFrame = CFrame.new(pos + Vector3.new(0, 0.09, 0)) * UP, Color = color, Transparency = 0.75 })
	local edge = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.08, radius * 2 + 0.7, radius * 2 + 0.7), CFrame = CFrame.new(pos + Vector3.new(0, 0.06, 0)) * UP, Color = color, Transparency = 0.3 })
	local inner = fxPart({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, radius * 2.4, radius * 2.4), CFrame = CFrame.new(pos + Vector3.new(0, 0.11, 0)) * UP, Color = Color3.new(1, 1, 1), Transparency = 0.65 })
	tween(disc, dur, { Transparency = 0.4 })
	tween(inner, dur, { Size = Vector3.new(0.12, 0.3, 0.3), Transparency = 0.25 }, Enum.EasingStyle.Linear)
	task.delay(dur, function()
		tween(disc, 0.2, { Transparency = 1 })
		tween(edge, 0.2, { Transparency = 1 })
		inner:Destroy()
	end)
	Debris:AddItem(disc, dur + 0.25)
	Debris:AddItem(edge, dur + 0.25)
	Debris:AddItem(inner, dur + 0.05)
end

-- secousse : forte si c'est le joueur local, légère s'il est proche
function CartoonFX.casterShake(character: Model?, amount: number)
	if involvesLocal(character) then
		CartoonFX.shake(amount)
		CartoonFX.fovKick(amount * 6)
	else
		local r = character and character:FindFirstChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera
		if r and cam and (cam.CFrame.Position - r.Position).Magnitude < 45 then
			CartoonFX.shake(amount * 0.35)
		end
	end
end

-- poussière au sol qui part en anneau
function CartoonFX.dust(pos: Vector3, radius: number?, color: Color3?, count: number?)
	local g = groundAt(pos)
	count = qn(count or 10)
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local d = fxPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * rng:NextNumber(1, 1.8), Position = g + out + Vector3.new(0, 0.5, 0), Color = color or Color3.fromRGB(225, 220, 210), Transparency = 0.25 })
		tween(d, 0.5, { Position = g + out * (radius or 6) + Vector3.new(0, rng:NextNumber(0.4, 1.4), 0), Size = d.Size * 2, Transparency = 1 })
		Debris:AddItem(d, 0.55)
	end
end

-- TREMBLEMENT DE TERRE : gros impact au sol complet (onde de choc, fissures, débris, poussière, lumière)
function CartoonFX.quake(pos: Vector3, radius: number?, color: Color3?, power: number?)
	radius, power = radius or 10, power or 1
	color = color or Color3.new(1, 1, 1)
	local g = groundAt(pos)
	CartoonFX.bigImpact(g + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.2 * power, color)
	CartoonFX.shockwave(g + Vector3.new(0, 0.25, 0), radius, color)
	task.delay(0.08, function()
		CartoonFX.shockwave(g + Vector3.new(0, 0.3, 0), radius * 1.35, Color3.new(1, 1, 1))
	end)
	CartoonFX.cracks(g, 8, radius * 0.45)
	CartoonFX.debris(g, math.floor(5 * power + 1), nil, power)
	CartoonFX.dust(g, radius * 0.8, nil, 12)
	CartoonFX.light(g + Vector3.new(0, 2, 0), color, radius * 2.2, 5, 0.3)
end

-- rayon entre deux points (laser, jet d'eau, câble…)
function CartoonFX.beam(from: Vector3, to: Vector3, width: number?, color: Color3?, dur: number?)
	local len = (to - from).Magnitude
	if len < 0.1 then
		return nil
	end
	local p = fxPart({ Size = Vector3.new(width or 0.6, width or 0.6, len), CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2), Color = color or Color3.new(1, 1, 1), Transparency = 0.1 })
	tween(p, dur or 0.2, { Size = Vector3.new(0.05, 0.05, len), Transparency = 1 })
	Debris:AddItem(p, (dur or 0.2) + 0.03)
	return p
end

return CartoonFX
