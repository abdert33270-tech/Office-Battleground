--[[
	TutorialService — premier match guidé (Config/Tutorial). Le SERVEUR valide chaque étape :
		HitDummy : Signals.Hit (attaquant = perso du joueur, victime IsDummy)
		Block    : Signals.Blocked / Signals.Parried (victime = joueur) OU garde maintenue Tutorial.BlockHoldTime s
		Dash     : CharacterState.lastDash qui change (dash accepté par CombatService)
		Ability  : remote Ability(slot 1) + délai global (gcdUntil) posé par AbilityService juste après
		Throw    : l'objet tenu (CharacterState.held) quitte la main en vol (rec.state = "Flight")
		Daily    : (optionnelle) signalée par le client à l'ouverture du panneau DAILY (sans récompense propre)
	Données (DataService, sauvegardées) : data.Tutorial = { Done, Steps = {[id] = n}, Skipped?, Rewarded? }
		Profil neuf (XP = 0, KOs = 0) sans champ => tutoriel actif ; ancien profil sans champ => Done (jamais montré).
		Chargement échoué (DataService.loadFailed) => pas de tutoriel pour la session (récompense jamais gaspillée).
	Récompense une seule fois à la fin des étapes requises : SkinService.addCash + SkinService.addCrates.
	Attribut Player : TutorialDone (bool).
	Remote « Tutorial » :
		client -> serveur : "State" | "Skip" | "Daily"
		serveur -> client : { active, done, current = id?, steps = {[id] = n}, finished = bool?, reward = {Cash, Crates}? }
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local TutorialCfg = require(ReplicatedStorage.Shared.Config.Tutorial)
local Signals = require(script.Parent.Signals)
local DataService = require(script.Parent.DataService)
local SkinService = require(script.Parent.SkinService)
local CharacterState = require(script.Parent.CharacterState)

local TutorialService = {}
TutorialService.Priority = 70 -- après DataService (60) et SkinService (62)

local remote
local sessions = {} -- [player] = suivi de la session (bases de comparaison, minuteries)

local function tut(player)
	local d = DataService.get(player)
	local t = d and d.Tutorial
	if type(t) ~= "table" or type(t.Steps) ~= "table" then
		return nil
	end
	return t
end

local function currentStep(t)
	for _, s in ipairs(TutorialCfg.Steps) do
		if not s.Optional and (tonumber(t.Steps[s.Id]) or 0) < s.Goal then
			return s
		end
	end
	return nil
end

local function isActive(player)
	local t = tut(player)
	return t ~= nil and not t.Done and not DataService.loadFailed(player)
end

function TutorialService.getState(player: Player)
	local t = tut(player)
	if not t or DataService.loadFailed(player) then
		return { active = false, done = true, steps = {} }
	end
	local steps = {}
	for _, s in ipairs(TutorialCfg.Steps) do
		steps[s.Id] = math.min(s.Goal, tonumber(t.Steps[s.Id]) or 0)
	end
	local cur = currentStep(t)
	return { active = not t.Done, done = t.Done == true, current = cur and cur.Id or nil, steps = steps }
end

local function push(player, extra)
	if not remote or not player.Parent then
		return
	end
	local st = TutorialService.getState(player)
	for k, v in pairs(extra or {}) do
		st[k] = v
	end
	remote:FireClient(player, st)
end

local function finish(player, t)
	if t.Done then
		return
	end
	t.Done = true
	player:SetAttribute("TutorialDone", true)
	local R = TutorialCfg.Reward
	if not t.Rewarded then
		t.Rewarded = true
		SkinService.addCash(player, R.Cash, "Training complete!")
		SkinService.addCrates(player, R.Crates)
	end
	push(player, { finished = true, reward = { Cash = R.Cash, Crates = R.Crates } })
end

-- avance l'étape id de n (étapes requises : seulement l'étape en cours)
function TutorialService.progress(player: Player, id: string, n: number?)
	if not isActive(player) then
		return
	end
	local t = tut(player)
	local s = TutorialCfg.ById[id]
	if not t or not s then
		return
	end
	if not s.Optional then
		local cur = currentStep(t)
		if not cur or cur.Id ~= id then
			return
		end
	end
	local v = tonumber(t.Steps[id]) or 0
	if v >= s.Goal then
		return
	end
	t.Steps[id] = math.min(s.Goal, v + (n or 1))
	if currentStep(t) == nil then
		finish(player, t)
	else
		push(player)
	end
end

function TutorialService.skip(player: Player)
	local t = tut(player)
	if not t or t.Done then
		return
	end
	t.Done = true
	t.Skipped = true
	player:SetAttribute("TutorialDone", true)
	push(player, { skipped = true })
end

local function playerOf(model)
	return model and Players:GetPlayerFromCharacter(model) or nil
end

-- suivi par sondage des états serveur (garde, dash, capacité, lancer)
local function poll(player, sess)
	local c = player.Character
	if not c or not CharacterState.isAlive(c) then
		return
	end
	local t = tut(player)
	local cur = t and currentStep(t)
	if not cur then
		return
	end
	local s = CharacterState.get(c)
	if sess.char ~= c then
		-- nouveau perso / nouvel état : on repart des valeurs actuelles
		sess.char = c
		sess.lastDash = s.lastDash
		sess.gcd = s.gcdUntil or 0
		sess.held = s.held
		sess.blockSince = nil
	end
	local now = os.clock()
	if cur.Id == "Block" then
		if c:GetAttribute("Blocking") == true or s.blocking then
			sess.blockSince = sess.blockSince or now
			if now - sess.blockSince >= TutorialCfg.BlockHoldTime then
				sess.blockSince = nil
				TutorialService.progress(player, "Block")
			end
		else
			sess.blockSince = nil
		end
	elseif cur.Id == "Dash" then
		if s.lastDash ~= sess.lastDash and s.lastDash > now - 2 then
			TutorialService.progress(player, "Dash")
		end
	elseif cur.Id == "Ability" then
		local g = s.gcdUntil or 0
		if g ~= sess.gcd and g > now and sess.abilityAt and now - sess.abilityAt < 1 then
			TutorialService.progress(player, "Ability")
		end
	elseif cur.Id == "Throw" then
		local prev = sess.held
		if prev and s.held ~= prev and prev.state ~= "Held" and sess.throwAt and now - sess.throwAt < TutorialCfg.ThrowWindow then
			TutorialService.progress(player, "Throw")
		end
	end
	sess.lastDash = s.lastDash
	sess.gcd = s.gcdUntil or 0
	sess.held = s.held
end

function TutorialService.init()
	remote = Net.get("Tutorial")
	remote.OnServerEvent:Connect(function(player, op)
		if not Net.allow(player, "Tutorial", 4) then
			return
		end
		if op == "Skip" then
			TutorialService.skip(player)
		elseif op == "Daily" then
			TutorialService.progress(player, "Daily")
		else
			push(player)
		end
	end)

	DataService.whenLoaded(function(player, data)
		if type(data) ~= "table" then
			return
		end
		if type(data.Tutorial) ~= "table" then
			-- profil neuf => tutoriel ; ancien profil (déjà joué) => considéré comme terminé, sans récompense
			local veteran = (tonumber(data.XP) or 0) > 0 or (tonumber(data.KOs) or 0) > 0
			data.Tutorial = { Done = veteran, Steps = {}, Skipped = veteran or nil }
		end
		if type(data.Tutorial.Steps) ~= "table" then
			data.Tutorial.Steps = {}
		end
		data.Tutorial.Done = data.Tutorial.Done == true
		player:SetAttribute("TutorialDone", data.Tutorial.Done or DataService.loadFailed(player))
		sessions[player] = sessions[player] or {}
		push(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		sessions[p] = nil
	end)

	Signals.Hit:Connect(function(attacker, victim)
		if victim and victim:GetAttribute("IsDummy") == true then
			local p = playerOf(attacker)
			if p then
				TutorialService.progress(p, "HitDummy")
			end
		end
	end)
	Signals.Blocked:Connect(function(_attacker, victim)
		local p = playerOf(victim)
		if p then
			TutorialService.progress(p, "Block")
		end
	end)
	Signals.Parried:Connect(function(defender)
		local p = playerOf(defender)
		if p then
			TutorialService.progress(p, "Block")
		end
	end)
	-- demandes du client (la validation réelle se fait dans poll via l'état serveur)
	Net.get("Ability").OnServerEvent:Connect(function(player, slot)
		local sess = sessions[player]
		if sess and slot == 1 then
			sess.abilityAt = os.clock()
		end
	end)
	Net.get("Throw").OnServerEvent:Connect(function(player)
		local sess = sessions[player]
		if sess then
			sess.throwAt = os.clock()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			for player, sess in pairs(sessions) do
				if player.Parent and isActive(player) then
					local ok, err = pcall(poll, player, sess)
					if not ok and not sess.warned then
						sess.warned = true
						warn("[TutorialService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return TutorialService
