--[[
	DataService — progression du joueur : XP, grades de carrière, K.O., sauvegarde DataStore.
	- XP : dégâts infligés (Signals.Hit), K.O. (Signals.Died), survie aux effondrements, tâches.
	- Multiplicateur : attribut ReplicatedStorage.XPMultiplier (Friday 5PM = 2).
	- Les mannequins ne rapportent rien (pas de farm AFK).
	- DataStore indisponible (Studio sans accès API) => mémoire seule, sans planter.
	Attributs Player : XP, Grade, Level, LevelXP (XP faite dans le niveau), LevelNeed. leaderstats : Level, Grade, KOs.
	Tag « LV 12  GRADE » au-dessus de la tête.
	Niveaux (Config/Levels) : calculés depuis l'XP ; data.Level = plus haut niveau déjà récompensé.
	Chaque nouveau niveau => Cash (Levels.reward, via SkinService.addCash) + remote "LevelUp" {level, cash, grade} au client.
	Champ Characters = {[charId]=true} : persos débloqués (UnlockService).

	API : DataService.get(player) -> data | DataService.addXP(player, amount, raw?) |
	      DataService.setGrade(player, gradeName) | DataService.gradeFor(xp) -> index, grade
	      DataService.setLevel(player, n) | DataService.onLoaded : liste de hooks function(player, data)
	      DataService.whenLoaded(fn) : ajoute un hook ET l'appelle pour les joueurs déjà chargés (services tardifs)
      DataService.loadFailed(player) : chargement DataStore raté (session en mémoire, non sauvée)
	  DataService.save(player, release?) -> ok (écrit pour de vrai ; file par joueur, 3 essais) |
	  DataService.canSave(player) | DataService.saveAll(release?, timeout?) -> nOk, total | DataService.pendingSaves()
	Sécurité (docs/Serveur-securite.md) : verrou de session __lock {job, t} posé par UpdateAsync, data.Version
	incrémentée à chaque écriture, BindToClose attend la fin de toutes les écritures (25 s max), FarmGuard sur les gains.
	Méta-systèmes (voir docs/Meta-systemes.md) : Daily {Streak, LastDay, LastClaim, Total} (DailyRewardService),
	Codes {[CODE]=os.time()} (CodeService), Settings {[clé]=valeur} (SettingsService), AFK {Day, Earned} (AFKService).
]]
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Grades = require(ReplicatedStorage.Shared.Config.Grades)
local Levels = require(ReplicatedStorage.Shared.Config.Levels)
local Signals = require(script.Parent.Signals)
local Announce = require(script.Parent.Announce)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local FarmGuard = require(script.Parent.FarmGuard)

local DataService = {}
DataService.Priority = 60
DataService.onLoaded = {}

local STORE_NAME = "OfficeBattlegrounds_v1"
local AUTOSAVE = 120 -- sert aussi de battement du verrou (bien < LOCK_TTL)
local LOCK_TTL = 300 -- verrou d'un autre serveur plus vieux => considéré mort
local LOCK_WAIT = 15 -- attente max d'un verrou vivant avant de le voler
local LOCK_RETRY = 3
local SAVE_TRIES = 3
local CLOSE_TIMEOUT = 25 -- BindToClose : 30 s max côté Roblox

local store = nil
local profiles = {} -- [player] = { data, canSave, frac, failed, busy, waiters = {thread}, released?, lost? }
local pendingSaves = 0 -- écritures en cours ou en file (BindToClose attend 0)

local function key(player)
	return "u_" .. player.UserId
end

-- Cash / Skins / Equipped / Crates : système de skins (SkinService). Champs manquants => valeurs par défaut.
local function defaultData()
	return {
		XP = 0, KOs = 0, Tasks = nil, Cash = 0, Skins = {}, Equipped = {}, Crates = 0, Characters = {}, Level = 1,
		Daily = {}, Codes = {}, Settings = {}, AFK = {}, Receipts = {}, Version = 0,
	}
end

function DataService.gradeFor(xp: number)
	local index = 1
	for i, g in ipairs(Grades.List) do
		if xp >= g.XP then
			index = i
		end
	end
	return index, Grades.List[index]
end

function DataService.get(player: Player)
	local p = profiles[player]
	return p and p.data or nil
end

-- true si le DataStore existe mais que le chargement a échoué : profil par défaut en mémoire, jamais sauvé.
-- Les récompenses « une fois » (quotidienne, codes) refusent alors pour ne pas les gaspiller. (Studio sans API => false)
function DataService.loadFailed(player: Player): boolean
	local p = profiles[player]
	return p ~= nil and p.failed == true
end

-- hook de chargement pour un service qui démarre après DataService : appelé aussi pour les joueurs déjà chargés
-- (ajout puis parcours sans yield entre les deux => jamais appelé deux fois pour le même chargement)
function DataService.whenLoaded(fn)
	table.insert(DataService.onLoaded, fn)
	for player, p in pairs(profiles) do
		if player.Parent then
			task.spawn(fn, player, p.data)
		end
	end
end

local function isDummy(model)
	return model and model:GetAttribute("IsDummy") == true
end

local function playerOf(model)
	return model and Players:GetPlayerFromCharacter(model) or nil
end

-- Tag de grade au-dessus de la tête
local function updateTag(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then
		return
	end
	local _, grade = DataService.gradeFor(player:GetAttribute("XP") or 0)
	local level = player:GetAttribute("Level") or 1
	local tag = head:FindFirstChild("GradeTag")
	if not tag then
		tag = Instance.new("BillboardGui")
		tag.Name = "GradeTag"
		tag.Size = UDim2.fromOffset(210, 26)
		tag.StudsOffset = Vector3.new(0, 2.4, 0)
		tag.MaxDistance = 70
		tag.LightInfluence = 0
		tag.ResetOnSpawn = false
		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.FontFace = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Bold) -- police pixel (UITheme.Display)
		label.TextScaled = true
		label.RichText = true
		label.Parent = tag
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Parent = label
		tag.Parent = head
	end
	tag.Label.Text = '<font color="#FFE650">LV ' .. level .. "</font>  " .. string.upper(grade.Name)
	tag.Label.TextColor3 = grade.Color
end

local function applyAttributes(player, data)
	local _, grade = DataService.gradeFor(data.XP)
	player:SetAttribute("XP", data.XP)
	player:SetAttribute("Grade", grade.Name)
	local level, into, need = Levels.levelFor(data.XP)
	player:SetAttribute("Level", level)
	player:SetAttribute("LevelXP", into)
	player:SetAttribute("LevelNeed", need)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Grade.Value = grade.Name
		ls.KOs.Value = data.KOs
		if ls:FindFirstChild("Level") then
			ls.Level.Value = level
		end
	end
	updateTag(player)
end

-- nouveaux niveaux atteints (au-delà de data.Level) : Cash + popup « LEVEL UP »
local levelRemote
local function checkLevelUp(player, data)
	local level = Levels.levelFor(data.XP)
	local last = math.max(1, tonumber(data.Level) or 1)
	if level <= last then
		return
	end
	local cash = 0
	for L = last + 1, level do
		cash += Levels.reward(L)
	end
	data.Level = level
	local ok, SkinService = pcall(require, script.Parent.SkinService)
	if ok and SkinService and SkinService.addCash then
		SkinService.addCash(player, cash, "LEVEL " .. level)
	else
		data.Cash = (data.Cash or 0) + cash
		player:SetAttribute("Cash", data.Cash)
	end
	local _, grade = DataService.gradeFor(data.XP)
	levelRemote = levelRemote or Net.get("LevelUp")
	levelRemote:FireClient(player, { level = level, from = last, cash = cash, grade = grade.Name })
	Signals.LevelUp:Fire(player, level)
end

function DataService.addXP(player: Player, amount: number, raw: boolean?)
	local p = profiles[player]
	if not p or amount == 0 then
		return
	end
	if not raw then
		amount *= (ReplicatedStorage:GetAttribute("XPMultiplier") or 1)
	end
	p.frac += amount
	local whole = math.floor(p.frac)
	if whole == 0 then
		return
	end
	p.frac -= whole
	local before = DataService.gradeFor(p.data.XP)
	p.data.XP = math.max(0, p.data.XP + whole)
	local after, grade = DataService.gradeFor(p.data.XP)
	applyAttributes(player, p.data)
	checkLevelUp(player, p.data)
	if after > before then
		Signals.GradeUp:Fire(player, grade.Name)
		Announce.toast(player, "PROMOTED TO " .. string.upper(grade.Name) .. "!", grade.Color)
		Net.get("Banner"):FireClient(player, {
			text = "PROMOTED!",
			sub = "You are now a " .. grade.Name,
			color = grade.Color,
			duration = 3,
			style = "Big",
		})
	end
end

function DataService.setGrade(player: Player, gradeName: string)
	local p = profiles[player]
	if not p then
		return false
	end
	for _, g in ipairs(Grades.List) do
		if string.lower(g.Name) == string.lower(gradeName) then
			p.data.XP = g.XP
			applyAttributes(player, p.data)
			return true
		end
	end
	return false
end

-- admin / tests : met l'XP au début du niveau n (récompense les niveaux jamais atteints)
function DataService.setLevel(player: Player, n: number)
	local p = profiles[player]
	if not p then
		return false
	end
	p.data.XP = Levels.total(n)
	p.frac = 0
	applyAttributes(player, p.data)
	checkLevelUp(player, p.data)
	return true
end

function DataService.addKO(player: Player)
	local p = profiles[player]
	if p then
		p.data.KOs += 1
		applyAttributes(player, p.data)
	end
end

------------------------------------------------------------------------
-- Sauvegarde : verrou de session + file par joueur (voir docs/Serveur-securite.md)
------------------------------------------------------------------------
-- Enregistrement DataStore = data + __lock = {job = game.JobId, t = os.time()} (jamais gardé dans data en mémoire).
-- Chargement : UpdateAsync pose notre verrou ; verrou d'un AUTRE serveur de moins de LOCK_TTL s => on réessaie
-- toutes les LOCK_RETRY s pendant LOCK_WAIT s, puis on le vole (serveur mort / bloqué).
-- Écriture : refusée (transform -> nil, rien n'est écrit) si le verrou appartient à un autre serveur => un vieux
-- serveur ne peut jamais écraser une session plus récente (pas de retour en arrière, ex. reconnexion AFK).
-- Sortie / fermeture : dernière écriture avec __lock = nil (libère tout de suite le serveur suivant).
local function writeRecord(k: string, snapshot, release: boolean)
	local outcome = nil -- nombre (Version écrite) | "lost"
	for attempt = 1, SAVE_TRIES do
		outcome = nil
		local ok, err = pcall(function()
			store:UpdateAsync(k, function(old)
				-- peut être rappelée par Roblox (conflit) : toujours repartir de zéro, jamais de yield ici
				outcome = nil
				local lk = type(old) == "table" and old.__lock or nil
				if type(lk) == "table" and lk.job ~= game.JobId then
					outcome = "lost"
					return nil -- annule l'écriture
				end
				local rec = table.clone(snapshot)
				rec.__lock = (not release) and { job = game.JobId, t = os.time() } or nil
				rec.Version = ((type(old) == "table" and tonumber(old.Version)) or 0) + 1
				outcome = rec.Version
				return rec
			end)
		end)
		if ok then
			return outcome
		end
		warn(("[DataService] écriture échouée (%s, essai %d/%d) : %s"):format(k, attempt, SAVE_TRIES, tostring(err)))
		if attempt < SAVE_TRIES then
			task.wait(2 ^ (attempt - 1)) -- 1 s, 2 s
		end
	end
	return nil
end

-- file par joueur : une seule écriture à la fois, les suivantes attendent leur tour (dans l'ordre)
local function acquire(p)
	if p.busy then
		table.insert(p.waiters, coroutine.running())
		coroutine.yield()
		return -- p.busy nous a été transmis par release()
	end
	p.busy = true
end

local function releaseTurn(p)
	local nxt = table.remove(p.waiters, 1)
	if nxt then
		task.spawn(nxt)
	else
		p.busy = false
	end
end

-- DataService.save(player, release?) -> ok : true si les données sont réellement écrites dans le DataStore.
-- release = true (sortie du joueur / fermeture) : libère le verrou, plus aucune écriture ensuite pour ce profil.
local function save(player: Player, release: boolean?): boolean
	local p = profiles[player]
	if not p or not store then
		return false
	end
	pendingSaves += 1
	acquire(p)
	local ok = false
	if p.canSave and not p.released then
		local outcome = writeRecord(key(player), p.data, release == true)
		if outcome == "lost" then
			p.canSave = false
			p.lost = true
			warn("[DataService] verrou de " .. player.Name .. " pris par un autre serveur : plus aucune sauvegarde ici")
		elseif type(outcome) == "number" then
			ok = true
			p.data.Version = outcome
			if release then
				p.released = true
			end
		else
			warn("[DataService] sauvegarde ABANDONNÉE pour " .. player.Name .. " après " .. SAVE_TRIES .. " essais")
		end
	end
	releaseTurn(p)
	pendingSaves -= 1
	return ok
end
DataService.save = save

-- true si ce profil peut être sauvé (chargé, DataStore OK, verrou à nous)
function DataService.canSave(player: Player): boolean
	local p = profiles[player]
	return p ~= nil and store ~= nil and p.canSave == true and not p.released
end

-- sauve tout le monde en parallèle et attend (max timeout s) ; -> nombre de réussites, nombre de profils
function DataService.saveAll(release: boolean?, timeout: number?)
	local done, okCount, total = 0, 0, 0
	for player in pairs(profiles) do
		total += 1
		task.spawn(function()
			if save(player, release) then
				okCount += 1
			end
			done += 1
		end)
	end
	local t0 = os.clock()
	while done < total and os.clock() - t0 < (timeout or 25) do
		task.wait(0.1)
	end
	return okCount, total
end

function DataService.pendingSaves(): number
	return pendingSaves
end

-- chargement + pose du verrou -> "ok", record | "studio" | "left" | "error"
local function readAndLock(player)
	local k = key(player)
	local deadline = os.clock() + LOCK_WAIT
	local errors = 0
	while true do
		local steal = os.clock() >= deadline
		local value, heldBy = nil, nil
		local ok, err = pcall(function()
			store:UpdateAsync(k, function(old)
				value, heldBy = nil, nil
				local lk = type(old) == "table" and old.__lock or nil
				if not steal and type(lk) == "table" and lk.job ~= game.JobId and type(lk.t) == "number" and os.time() - lk.t < LOCK_TTL then
					heldBy = lk
					return nil -- verrou vivant d'un autre serveur : on n'écrit rien
				end
				if type(lk) == "table" and lk.job ~= game.JobId then
					heldBy = lk -- verrou volé (vieux ou après attente)
				end
				local rec = type(old) == "table" and old or {}
				rec.__lock = { job = game.JobId, t = os.time() }
				value = rec
				return rec
			end)
		end)
		if ok and value then
			if heldBy then
				warn(("[DataService] verrou de %s repris au serveur %s"):format(player.Name, tostring(heldBy.job)))
			end
			return "ok", value
		elseif ok then
			if not player.Parent then
				return "left"
			end
			task.wait(LOCK_RETRY) -- l'autre serveur est en train de sauver / libérer
		else
			local msg = tostring(err)
			if string.find(msg, "Studio access", 1, true) or string.find(msg, "StudioAccessToApis", 1, true) then
				return "studio"
			end
			errors += 1
			warn("[DataService] chargement échoué (essai " .. errors .. ")", msg)
			if errors >= SAVE_TRIES or not player.Parent then
				return "error"
			end
			task.wait(errors)
		end
	end
end

local function load(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local levelValue = Instance.new("IntValue")
	levelValue.Name = "Level"
	levelValue.Value = 1
	levelValue.Parent = ls
	local gradeValue = Instance.new("StringValue")
	gradeValue.Name = "Grade"
	gradeValue.Value = "Trainee"
	gradeValue.Parent = ls
	local kos = Instance.new("IntValue")
	kos.Name = "KOs"
	kos.Parent = ls
	ls.Parent = player

	local data, canSave, failed = nil, false, false
	if store then
		local status, rec = readAndLock(player)
		if status == "ok" then
			data, canSave = rec, true
		elseif status == "studio" then
			-- Studio sans accès API : mémoire seule (active « Enable Studio Access to API Services » pour tester la sauvegarde)
			store = nil
			warn("[DataService] Studio sans accès aux API : progression en mémoire seulement")
		elseif status == "left" then
			return
		else
			failed = true
		end
	end
	if type(data) ~= "table" then
		data = defaultData()
	end
	data.__lock = nil
	for k, v in pairs(defaultData()) do
		if data[k] == nil or (type(v) == "table" and type(data[k]) ~= "table") or (type(v) == "number" and type(data[k]) ~= "number") then
			data[k] = v
		end
	end
	-- anciennes sauvegardes : niveaux déjà atteints sans récompense rétroactive
	data.Level = math.max(data.Level, (Levels.levelFor(data.XP)))
	if not player.Parent then
		if canSave then
			-- parti pendant le chargement : on rend le verrou tout de suite (sinon le serveur suivant attend 15 s)
			task.spawn(writeRecord, key(player), data, true)
		end
		return
	end
	if failed then
		warn("[DataService] données de " .. player.Name .. " non chargées : session en mémoire seulement (rien ne sera sauvé)")
	end
	profiles[player] = { data = data, canSave = canSave, frac = 0, failed = failed, busy = false, waiters = {} }
	applyAttributes(player, data)
	for _, hook in ipairs(DataService.onLoaded) do
		task.spawn(hook, player, data)
	end
end

function DataService.init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore indisponible, progression en mémoire seulement :", result)
	end

	levelRemote = Net.get("LevelUp")
	Players.PlayerAdded:Connect(load)
	task.defer(function()
		for _, p in ipairs(Players:GetPlayers()) do
			if not profiles[p] then
				task.spawn(load, p)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		save(player, true) -- dernière écriture : libère le verrou
		profiles[player] = nil
	end)
	game:BindToClose(function()
		if RunService:IsStudio() then
			task.wait(0.5)
		end
		-- profils encore là (PlayerRemoving pas encore passé) : écriture finale ; puis on attend TOUTES les écritures
		for player in pairs(profiles) do
			task.spawn(save, player, true)
		end
		local t0 = os.clock()
		repeat
			task.wait(0.1)
		until pendingSaves <= 0 or os.clock() - t0 > CLOSE_TIMEOUT
		if pendingSaves > 0 then
			warn("[DataService] fermeture : " .. pendingSaves .. " sauvegarde(s) non terminée(s)")
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for _, p in ipairs(Players:GetPlayers()) do
				task.spawn(save, p)
			end
		end
	end)

	-- XP
	Signals.Hit:Connect(function(attacker, victim, damage)
		local player = playerOf(attacker)
		if player and victim ~= attacker and not isDummy(victim) and type(damage) == "number" then
			-- joueur passif (alt / AFK, aucun dégât infligé depuis 60 s) : pas d'XP (FarmGuard)
			local vp = playerOf(victim)
			if vp and not FarmGuard.damageRewarded(player, vp) then
				return
			end
			DataService.addXP(player, damage * Grades.XPPerDamage)
		end
	end)
	Signals.Died:Connect(function(victim, killer)
		local player = playerOf(killer)
		if player and killer ~= victim and not isDummy(victim) then
			-- même paire tueur -> victime > 3 K.O. / 10 min : K.O. sans récompense (FarmGuard)
			if playerOf(victim) and not FarmGuard.koRewarded(killer, victim) then
				return
			end
			DataService.addKO(player)
			DataService.addXP(player, Grades.XPPerKO)
		end
	end)
	Signals.SurvivedCollapse:Connect(function(character)
		local player = playerOf(character)
		if player then
			DataService.addXP(player, Grades.XPSurviveCollapse)
		end
	end)
	Signals.CharacterSpawned:Connect(function(character, player)
		if player then
			task.defer(updateTag, player)
		end
	end)
end

return DataService
