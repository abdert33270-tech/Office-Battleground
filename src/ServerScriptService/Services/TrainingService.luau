--[[
	TrainingService — outils d'entraînement (voir docs/Entrainement.md).
	1) Relevé d'entraînement : quand un JOUEUR frappe un mannequin / bot (IsDummy), on lui envoie (remote "Training",
	   op "Readout") le nombre de coups du combo, les dégâts cumulés, « DROPPED » si l'étourdissement de la victime
	   s'est terminé entre deux coups, le nom du dernier coup et son windup / endlag lus dans Config.
	   Source : Signals.Hit / Blocked / Parried / GuardBroken (mêmes événements que les dégâts serveur).
	2) Remote "Training" (client -> serveur) : TrainingService.handlers[op](player, ...) — DummyService (SetMode) et
	   SparringBotService (Spar, DismissBot) y branchent leurs validations.
	3) TrainingService.npc : actions de combat pour PNJ (mannequins, bots) : m1, block, dash, evasive, face.
	   Utilise CombatService.performM1 / performBlock / performDash s'ils existent (pcall), sinon un repli
	   basé sur CombatService.swing / applyHit et CharacterState.
	Aucune récompense : les victimes IsDummy sont ignorées par DataService / TaskService / KillFeedService.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.Combat)
local Attacks = require(Shared.Config.Attacks)
local Net = require(Shared.Modules.Net)
local CharacterState = require(script.Parent.CharacterState)
local CombatService = require(script.Parent.CombatService)
local Signals = require(script.Parent.Signals)

local okItems, Items = pcall(require, Shared.Config.Items)
if not okItems then
	Items = {}
end
local okStyle, M1Style = pcall(require, Shared.Modules.M1Style)
if not okStyle then
	M1Style = nil
end

local TrainingService = {}
TrainingService.Priority = 80
TrainingService.handlers = {} -- [op] = function(player, ...)

local remote -- RemoteEvent "Training"
local sessions = {} -- [player] = { victim, hits, dmg, lastT, ender }

local function now()
	return workspace:GetServerTimeNow()
end

local function fx()
	return Net.get("FX")
end

local function anim()
	return Net.get("Anim")
end

------------------------------------------------------------------------
-- Actions de PNJ
------------------------------------------------------------------------
local Npc = {}
TrainingService.npc = Npc

local function combatFn(name)
	local f = CombatService[name]
	return type(f) == "function" and f or nil
end

local function flatUnit(v: Vector3, fallback: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.05 then
		return fallback
	end
	return f.Unit
end

-- tourne le PNJ vers une position (pas pendant un étourdissement / renversé / gel de hit-stop)
function Npc.face(model: Model, pos: Vector3)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or root.Anchored then
		return
	end
	if CharacterState.isStunned(model) or CharacterState.isKnockedDown(model) then
		return
	end
	local flat = Vector3.new(pos.X, root.Position.Y, pos.Z)
	if (flat - root.Position).Magnitude < 0.3 then
		return
	end
	root.CFrame = CFrame.lookAt(root.Position, flat)
end

-- le PNJ peut-il frapper maintenant ? (règle de doM1 : nextAttack, pas de block, pas étourdi)
function Npc.canM1(model: Model): boolean
	if not CharacterState.isAlive(model) or CharacterState.isStunned(model) or CharacterState.inSafeZone(model) then
		return false
	end
	if CharacterState.isKnockedDown(model) or model:GetAttribute("PendingKO") then
		return false
	end
	local s = CharacterState.get(model)
	return os.clock() >= (s.nextAttack or 0) - 0.03 and not s.blocking
end

local function m1Spec(i: number)
	local M1 = CombatConfig.M1
	local spec = {
		HitboxOffset = M1.HitboxOffset, HitboxSize = M1.HitboxSize, MaxTargets = M1.MaxTargets,
		Damage = M1.Damage[i], Knockback = M1.Knockback[i], KnockUp = M1.KnockUp[i], Stun = M1.Stun[i],
		Category = M1.Category[i], Power = M1.Power[i], Weapon = "Punch",
		Tether = i < M1.Hits,
	}
	if i >= M1.Hits then
		spec.Words = M1.FinisherWords
		spec.Heavy = true
		spec.Knockdown = true
	end
	return spec
end

-- repli : même cadence et mêmes valeurs que la chaîne de M1 des joueurs (Config/Combat.M1)
local function fallbackM1(model: Model, i: number): boolean
	local M1 = CombatConfig.M1
	local s = CharacterState.get(model)
	local t = os.clock()
	i = math.clamp(math.floor(i), 1, M1.Hits)
	local cooldown = M1.Cooldown[i] or 0.5
	local heavy = i >= M1.Hits
	s.nextAttack = t + cooldown
	s.busyUntil = t + cooldown + (heavy and 0 or (M1.DropEndlag or 0))
	s.endlagUntil = heavy and (t + cooldown) or 0
	s.lastM1 = t
	s.combo = heavy and 0 or i
	model:SetAttribute("EndlagUntil", heavy and (now() + cooldown) or 0)
	CharacterState.setSpeedMod(model, "Attack", CombatConfig.AttackSlow, cooldown + 0.05)
	local a = M1.Anim[i]
	if M1Style and type(M1Style.remap) == "function" then
		local ok, r = pcall(M1Style.remap, model, a)
		if ok and r then
			a = r
		end
	end
	anim():FireAllClients(model, a)
	local spec = m1Spec(i)
	task.delay(M1.Windup[i] or 0.15, function()
		if CharacterState.isAlive(model) and not CharacterState.isStunned(model) and model.Parent then
			pcall(CombatService.swing, model, spec, nil)
		end
	end)
	return true
end

-- M1 n° i de la chaîne (1..5). Renvoie true si le coup part.
function Npc.m1(model: Model, i: number): boolean
	if not Npc.canM1(model) then
		return false
	end
	local f = combatFn("performM1")
	if f then
		local ok, res = pcall(f, model, { i = i })
		if ok then
			return res ~= false
		end
	end
	return fallbackM1(model, i)
end

-- block (allowParry = fenêtre de perfect block ouverte à l'appui)
function Npc.block(model: Model, on: boolean, allowParry: boolean?)
	if on and (CharacterState.isStunned(model) or CharacterState.isGuardBroken(model) or CharacterState.isKnockedDown(model)) then
		return
	end
	local s = CharacterState.get(model)
	if s.blocking == on then
		return
	end
	local f = combatFn("performBlock")
	if f then
		local ok = pcall(f, model, on)
		if ok and s.blocking == on then
			return
		end
	end
	CharacterState.setBlocking(model, on, not allowParry)
	if on then
		CharacterState.setRunning(model, false)
		anim():FireAllClients(model, "BlockStart")
	end
end

local DASH_ANIMS = { F = "Dash", B = "DashBack", L = "SideDashL", R = "SideDashR" }

-- dash directionnel (kind = F/B/L/R) ; étourdi = EVASIVE
function Npc.dash(model: Model, kind: string): boolean
	if CharacterState.isStunned(model) then
		return Npc.evasive(model)
	end
	if not DASH_ANIMS[kind] then
		kind = "F"
	end
	local s = CharacterState.get(model)
	local t = os.clock()
	if t < (s.nextDash or 0) or t < (s.endlagUntil or 0) or CharacterState.inSafeZone(model) then
		return false
	end
	local f = combatFn("performDash")
	if f then
		local ok, res = pcall(f, model, kind)
		if ok then
			return res ~= false
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local D = CombatConfig.Dash
	s.nextDash = t + D.Cooldown
	s.lastDash = t
	s.lastDashKind = kind
	if t < s.nextAttack then
		s.nextAttack = t
	end
	s.busyUntil = math.min(s.busyUntil, t)
	CharacterState.setBlocking(model, false)
	model:SetAttribute("CDDash", now() + D.Cooldown)
	local cf = root.CFrame
	local dir = (kind == "B" and -cf.LookVector) or (kind == "L" and -cf.RightVector) or (kind == "R" and cf.RightVector) or cf.LookVector
	dir = flatUnit(dir, cf.LookVector)
	local speed = (kind == "B" and D.BackSpeed) or ((kind == "L" or kind == "R") and D.SideSpeed) or D.Speed
	local att = Instance.new("Attachment")
	att.Name = "NpcDashAtt"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "NpcDash"
	lv.Attachment0 = att
	lv.MaxForce = 1e5
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(dir.X * (speed or 60), dir.Z * (speed or 60))
	lv.Parent = root
	task.delay(D.Time or 0.2, function()
		lv:Destroy()
		att:Destroy()
	end)
	fx():FireAllClients({ type = "DashFX", character = model, dir = dir })
	anim():FireAllClients(model, DASH_ANIMS[kind])
	return true
end

-- EVASIVE pendant un hitstun (règles de CombatService : pas pendant guard break / renversé / K.O. engagé)
function Npc.evasive(model: Model): boolean
	if not CharacterState.isStunned(model) then
		return false
	end
	local s = CharacterState.get(model)
	local E = CombatConfig.Evasive
	local t = os.clock()
	if t < (s.nextBreak or 0) or CharacterState.isGuardBroken(model) or CharacterState.isKnockedDown(model)
		or s.pendingKO or model:GetAttribute("UltHeld") ~= nil or model:GetAttribute("UltAnchor") then
		return false
	end
	local f = combatFn("performDash")
	if f then
		local ok = pcall(f, model, "B")
		if ok and not CharacterState.isStunned(model) then
			return true
		end
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	s.nextBreak = t + E.Cooldown
	model:SetAttribute("CDEvasive", now() + E.Cooldown)
	model:SetAttribute("CDMaxEvasive", E.Cooldown)
	for _, n in ipairs({ "KB", "AirStall", "Spin" }) do
		local c = root:FindFirstChild(n)
		if c then
			c:Destroy()
		end
	end
	CharacterState.clearStun(model)
	CharacterState.protect(model, E.IFrames, false)
	model:SetAttribute("EvasiveAt", now())
	-- attaquants récents repoussés + étourdis (coup sans dégâts, passe par applyHit pour le recul)
	for _, other in ipairs(CharacterState.recentAttackers(model, E.AttackerMemory or 2)) do
		local oRoot = other ~= model and other:FindFirstChild("HumanoidRootPart")
		if oRoot and (oRoot.Position - root.Position).Magnitude <= E.Radius and CharacterState.isAlive(other) then
			pcall(CombatService.applyHit, {
				attacker = model, victim = other, damage = 0, dir = flatUnit(oRoot.Position - root.Position, root.CFrame.LookVector),
				knockback = E.Knockback, up = 16, stun = E.AttackerStun, category = "Light", power = 0.6,
				words = { "EVADED!" }, weapon = "Evasive", unblockable = true,
			})
		end
	end
	-- petit bond en arrière (le PNJ appartient au serveur)
	root.AssemblyLinearVelocity = -root.CFrame.LookVector * (E.Hop or 22) + Vector3.new(0, 18, 0)
	fx():FireAllClients({ k = "Breaker", p = root.Position, a = model })
	anim():FireAllClients(model, "Evasive")
	return true
end

------------------------------------------------------------------------
-- Relevé d'entraînement
------------------------------------------------------------------------
local nameCache = {}

-- nom lisible + windup / endlag (Config) du coup qui vient de toucher
local function moveInfo(attacker: Model, info)
	local C = CombatConfig
	local w = info and info.weapon
	if w == "Punch" then
		local s = CharacterState.get(attacker)
		if info.category == "Heavy" then
			return "M1 #5 FINISHER", C.M1.Windup[5], C.M1.Cooldown[5]
		end
		if os.clock() < (s.airChainUntil or 0) or CharacterState.isAirborne(attacker) then
			local idx = (s.airCombo or 0) > 0 and s.airCombo or math.max(1, s.combo or 1)
			return "AIR M1 #" .. idx, C.Air.Windup, C.Air.Cooldown
		end
		local i = math.clamp((s.combo or 0) > 0 and s.combo or 1, 1, 4)
		return "M1 #" .. i, C.M1.Windup[i], C.M1.Cooldown[i]
	elseif w == "Uppercut" then
		return "UPPERCUT", C.Uppercut.Windup, C.M1.Cooldown[C.M1.Hits]
	elseif w == "Downslam" then
		return "DOWNSLAM", C.Downslam.Windup, C.Downslam.Endlag
	elseif w == "Dash Strike" then
		return "DASH STRIKE", C.DashStrike.Windup, C.DashStrike.Endlag
	end
	if type(w) ~= "string" then
		return "?", nil, nil
	end
	local cached = nameCache[w]
	if cached == nil then
		cached = false
		for id, cfg in pairs(Attacks) do
			if type(cfg) == "table" and (cfg.Name == w or id == w) then
				cached = { string.upper(cfg.Name or id), cfg.Windup or 0, cfg.Endlag or C.AbilityGCD }
				break
			end
		end
		if not cached then
			for id, cfg in pairs(Items) do
				if type(cfg) == "table" and (cfg.DisplayName == w or id == w) and type(cfg.Use) == "table" then
					cached = { string.upper(cfg.DisplayName or id), cfg.Use.Windup, cfg.Use.Cooldown }
					break
				end
			end
		end
		nameCache[w] = cached
	end
	if cached then
		return cached[1], cached[2], cached[3]
	end
	return string.upper(w), nil, nil
end

local function targetLabel(victim: Model): string
	if victim:GetAttribute("IsBot") then
		return "BOT " .. string.upper(tostring(victim:GetAttribute("BotDifficulty") or ""))
	end
	return "DUMMY " .. string.upper(tostring(victim:GetAttribute("DummyMode") or "Idle"))
end

local function send(player: Player, payload)
	if remote and player.Parent then
		remote:FireClient(player, "Readout", payload)
	end
end

local function onHit(attacker, victim, damage, info)
	if not attacker or not victim or not victim:GetAttribute("IsDummy") then
		return
	end
	local player = Players:GetPlayerFromCharacter(attacker)
	if not player then
		return
	end
	-- (appelé de façon synchrone par Signals.Hit:Fire, AVANT que applyHit pose l'étourdissement de ce coup :
	--  isStunned = la victime était-elle encore étourdie par le coup précédent ?)
	local stunned = CharacterState.isStunned(victim)
	local t = os.clock()
	local sess = sessions[player]
	local dropped, prevHits = false, 0
	if sess and sess.victim == victim and t - sess.lastT < 3 then
		if not stunned then
			if not sess.ender then
				dropped, prevHits = true, sess.hits
			end
			sess = nil
		end
	else
		sess = nil
	end
	if not sess then
		sess = { victim = victim, hits = 0, dmg = 0, lastT = t }
		sessions[player] = sess
	end
	sess.hits += 1
	sess.dmg += (type(damage) == "number" and damage or 0)
	sess.lastT = t
	local weapon = info and info.weapon
	-- coup qui termine normalement un combo (renverse) : le suivant ne compte pas comme « dropped »
	sess.ender = (info and info.category == "Heavy" and weapon ~= "Uppercut") or false
	local move, windup, endlag = moveInfo(attacker, info)
	send(player, {
		hits = sess.hits, dmg = math.floor(sess.dmg * 10 + 0.5) / 10, dropped = dropped, prev = prevHits,
		move = move, windup = windup, endlag = endlag, target = targetLabel(victim), dummy = victim,
	})
end

local function onEvent(player: Player?, victim: Model?, ev: string, attacker: Model?)
	if not player or not victim or not victim:GetAttribute("IsDummy") then
		return
	end
	local sess = sessions[player]
	if ev == "PARRIED" then
		sessions[player] = nil
	end
	local move, windup, endlag
	if attacker then
		local s = CharacterState.get(attacker)
		local w = s.lastWeapon
		if w then
			move, windup, endlag = moveInfo(attacker, { weapon = w })
		end
	end
	send(player, {
		ev = ev, hits = sess and sess.victim == victim and sess.hits or 0, dmg = sess and sess.victim == victim and sess.dmg or 0,
		target = targetLabel(victim), dummy = victim, move = move, windup = windup, endlag = endlag,
	})
end

------------------------------------------------------------------------
function TrainingService.init()
	remote = Net.get("Training")
	remote.OnServerEvent:Connect(function(player, op, ...)
		if type(op) ~= "string" or not Net.allow(player, "Training", 6) then
			return
		end
		local fn = TrainingService.handlers[op]
		if fn then
			local ok, err = pcall(fn, player, ...)
			if not ok then
				warn("[TrainingService]", op, err)
			end
		end
	end)
	Signals.Hit:Connect(onHit)
	Signals.Blocked:Connect(function(attacker, victim)
		onEvent(attacker and Players:GetPlayerFromCharacter(attacker), victim, "BLOCKED", nil)
	end)
	Signals.Parried:Connect(function(defender, attacker)
		onEvent(attacker and Players:GetPlayerFromCharacter(attacker), defender, "PARRIED", nil)
	end)
	Signals.GuardBroken:Connect(function(victim, attacker)
		onEvent(attacker and Players:GetPlayerFromCharacter(attacker), victim, "GUARD BREAK", nil)
	end)
	Players.PlayerRemoving:Connect(function(p)
		sessions[p] = nil
	end)
end

-- message court pour un joueur (Announce.toast)
function TrainingService.toast(player: Player, text: string, bad: boolean?)
	Net.get("Toast"):FireClient(player, { text = text, color = bad and Color3.fromRGB(255, 110, 90) or Color3.fromRGB(140, 220, 255) })
end

return TrainingService
