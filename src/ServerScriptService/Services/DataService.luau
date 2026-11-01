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

local DataService = {}
DataService.Priority = 60
DataService.onLoaded = {}

local STORE_NAME = "OfficeBattlegrounds_v1"
local AUTOSAVE = 120

local store = nil
local profiles = {} -- [player] = { data = {...}, canSave = bool, frac = number }

local function key(player)
	return "u_" .. player.UserId
end

-- Cash / Skins / Equipped / Crates : système de skins (SkinService). Champs manquants => valeurs par défaut.
local function defaultData()
	return {
		XP = 0, KOs = 0, Tasks = nil, Cash = 0, Skins = {}, Equipped = {}, Crates = 0, Characters = {}, Level = 1,
		Daily = {}, Codes = {}, Settings = {}, AFK = {},
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

local function save(player)
	local p = profiles[player]
	if not p or not p.canSave or not store then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync(key(player), function()
			return p.data
		end)
	end)
	if not ok then
		warn("[DataService] sauvegarde échouée pour", player.Name, err)
	end
end
DataService.save = save

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

	local data, canSave = nil, false
	if store then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if ok then
				data = result
				canSave = true
				break
			end
			if string.find(tostring(result), "Studio access", 1, true) or string.find(tostring(result), "StudioAccessToApis", 1, true) then
				-- Studio sans accès API : mémoire seule (active « Enable Studio Access to API Services » pour tester la sauvegarde)
				store = nil
				warn("[DataService] Studio sans accès aux API : progression en mémoire seulement")
				break
			end
			warn("[DataService] chargement échoué (essai " .. attempt .. ")", result)
			task.wait(1)
		end
	end
	if type(data) ~= "table" then
		data = defaultData()
	end
	for k, v in pairs(defaultData()) do
		if data[k] == nil or (type(v) == "table" and type(data[k]) ~= "table") or (type(v) == "number" and type(data[k]) ~= "number") then
			data[k] = v
		end
	end
	-- anciennes sauvegardes : niveaux déjà atteints sans récompense rétroactive
	data.Level = math.max(data.Level, (Levels.levelFor(data.XP)))
	if not player.Parent then
		return
	end
	profiles[player] = { data = data, canSave = canSave, frac = 0 }
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
		save(player)
		profiles[player] = nil
	end)
	game:BindToClose(function()
		if RunService:IsStudio() then
			task.wait(0.5)
		end
		for _, p in ipairs(Players:GetPlayers()) do
			task.spawn(save, p)
		end
		task.wait(2)
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
			DataService.addXP(player, damage * Grades.XPPerDamage)
		end
	end)
	Signals.Died:Connect(function(victim, killer)
		local player = playerOf(killer)
		if player and killer ~= victim and not isDummy(victim) then
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
