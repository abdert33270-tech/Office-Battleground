--[[
	DummyService — mannequin(s) « Coworker » pour s'entraîner (voir docs/Entrainement.md).
	Apparaît sur DummySpawns de l'étage actuel (World), réapparaît 4 s après le K.O.
	FloorService appelle DummyService.respawn() à chaque nouvel étage.

	MODES (attribut DummyMode, choisi avec le ProximityPrompt « DummyModePrompt » -> menu TrainingController ->
	remote "Training" op "SetMode" validé ici : mannequin connu, joueur à portée, mode existant) :
		Idle          ne fait rien
		Block         garde levée en permanence (block normal, sans perfect block), se tourne vers vous
		PerfectBlock  pare (perfect block) tous les coups de face : dès qu'un attaquant proche lance un coup
		CounterM1     après votre combo (fin de son étourdissement), riposte avec 2 M1
		Evasive       au 3e coup d'un combo, EVASIVE (se libère et repousse les attaquants)
	PV remplis 3 s après le dernier échange (coup reçu / donné / bloqué). Aucune récompense (IsDummy).
	Le mode est gardé quand le mannequin réapparaît après un K.O. (pas après un changement d'étage).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local CombatConfig = require(game.ReplicatedStorage.Shared.Config.Combat)
local CharacterState = require(script.Parent.CharacterState)
local Ragdoll = require(script.Parent.Ragdoll)
local RigBuilder = require(script.Parent.RigBuilder)
local Signals = require(script.Parent.Signals)
local TrainingService = require(script.Parent.TrainingService)
local World = require(script.Parent.World)

local DummyService = {}
DummyService.Priority = 85
DummyService.enabled = true
DummyService.MODES = { "Idle", "Block", "PerfectBlock", "CounterM1", "Evasive" }

local Npc = TrainingService.npc
local COUNT = 1          -- mannequins par étage
local REFILL_DELAY = 3   -- PV remplis après ce délai sans combat
local THREAT_RANGE = 14  -- PerfectBlock / facing : attaquants dans ce rayon
local EVASIVE_AT = 3     -- mode Evasive : coups de combo avant de se libérer
local MODE_COLORS = {
	Idle = Color3.fromRGB(220, 220, 230),
	Block = Color3.fromRGB(90, 170, 255),
	PerfectBlock = Color3.fromRGB(80, 230, 255),
	CounterM1 = Color3.fromRGB(255, 120, 90),
	Evasive = Color3.fromRGB(190, 120, 255),
}
local MODE_LABELS = { Idle = "IDLE", Block = "BLOCK", PerfectBlock = "PERFECT BLOCK", CounterM1 = "COUNTER", Evasive = "EVASIVE" }

local dummies = {}   -- [dummy] = data { slot, lastCombat, comboHits, lastAttacker, lastHitT, threatUntil, seen, nextCounter }
local slotMode = {}  -- [slot] = mode (gardé entre deux K.O.)
local generation = 0 -- incrémenté par respawn() : les réapparitions en attente d'une ancienne génération sont annulées

local function isMode(m): boolean
	return type(m) == "string" and table.find(DummyService.MODES, m) ~= nil
end

-- attaquants potentiels : joueurs + bots (pas les mannequins)
local function fighters(): { Model }
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c and CharacterState.isAlive(c) and c:FindFirstChild("HumanoidRootPart") then
			table.insert(list, c)
		end
	end
	local folder = workspace:FindFirstChild("Dummies")
	if folder then
		for _, m in ipairs(folder:GetChildren()) do
			if m:GetAttribute("IsBot") and CharacterState.isAlive(m) then
				table.insert(list, m)
			end
		end
	end
	return list
end

local function nearest(dummy: Model, range: number): (Model?, number)
	local root = dummy:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil, math.huge
	end
	local best, bestD = nil, range
	for _, c in ipairs(fighters()) do
		local r = c:FindFirstChild("HumanoidRootPart")
		local d = r and (r.Position - root.Position).Magnitude or math.huge
		if d < bestD then
			best, bestD = c, d
		end
	end
	return best, bestD
end

local function refreshLabel(dummy: Model)
	local mode = dummy:GetAttribute("DummyMode") or "Idle"
	RigBuilder.tag(dummy, "DUMMY · " .. (MODE_LABELS[mode] or mode), MODE_COLORS[mode])
	local root = dummy:FindFirstChild("HumanoidRootPart")
	local prompt = root and root:FindFirstChild("DummyModePrompt")
	if prompt then
		prompt.ObjectText = "Dummy: " .. (MODE_LABELS[mode] or mode)
	end
end

function DummyService.setMode(dummy: Model, mode: string)
	local d = dummies[dummy]
	if not d or not isMode(mode) then
		return false
	end
	slotMode[d.slot] = mode
	dummy:SetAttribute("DummyMode", mode)
	d.comboHits, d.lastAttacker, d.threatUntil = 0, nil, 0
	if mode ~= "Block" and mode ~= "PerfectBlock" then
		Npc.block(dummy, false)
	end
	refreshLabel(dummy)
	return true
end

local spawnDummy

local function onDied(dummy: Model, slot: number, gen: number)
	Ragdoll.apply(dummy, dummy:GetAttribute("KOLaunch"))
	task.delay(4, function()
		local known = dummies[dummy] ~= nil
		dummies[dummy] = nil
		dummy:Destroy()
		if known and gen == generation then
			spawnDummy(slot)
		end
	end)
end

function spawnDummy(slot: number)
	if not DummyService.enabled then
		return
	end
	local cf = World.getDummySpawn() or (World.getPlayerSpawn() * CFrame.new(0, 0, -8))
	if slot > 1 then
		cf = cf * CFrame.new((slot - 1) * 6, 0, 0)
	end
	local dummy = RigBuilder.r6("Coworker", {
		Shirt = Color3.fromRGB(150, 200, 255),
		Tie = Color3.fromRGB(220, 50, 50),
	})
	dummy:PivotTo(cf * CFrame.Angles(0, math.rad(math.random(0, 359)), 0))
	dummy.Parent = workspace.Dummies
	CharacterState.setup(dummy)
	dummy:SetAttribute("IsDummy", true)
	for _, p in ipairs(dummy:GetChildren()) do
		if p:IsA("BasePart") then
			p:SetNetworkOwner(nil)
		end
	end
	local mode = slotMode[slot] or "Idle"
	dummy:SetAttribute("DummyMode", mode)
	dummies[dummy] = {
		slot = slot, lastCombat = -100, comboHits = 0, lastHitT = -100, threatUntil = 0, seen = setmetatable({}, { __mode = "k" }), nextCounter = 0,
	}
	-- invite « changer de mode » : ouvre le menu côté client (TrainingController), validé par le serveur
	local root = dummy:FindFirstChild("HumanoidRootPart")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DummyModePrompt"
	prompt.ActionText = "Training mode"
	prompt.ObjectText = "Dummy"
	prompt.KeyboardKeyCode = Enum.KeyCode.V -- (E = ramasser, G = transformation)
	prompt.GamepadKeyCode = Enum.KeyCode.DPadUp
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	refreshLabel(dummy)
	local gen = generation
	local hum = dummy:FindFirstChildOfClass("Humanoid")
	hum.Died:Connect(function()
		prompt.Enabled = false
		onDied(dummy, slot, gen)
	end)
end

-- (ré)place les mannequins sur l'étage actuel (le mode repart à Idle)
function DummyService.respawn()
	generation += 1
	for dummy in pairs(dummies) do
		dummy:Destroy()
	end
	table.clear(dummies)
	table.clear(slotMode)
	for slot = 1, COUNT do
		spawnDummy(slot)
	end
end

------------------------------------------------------------------------
-- Comportements
------------------------------------------------------------------------
-- PerfectBlock : un attaquant proche vient-il de lancer un coup ? (nextAttack / délai global des attaques avancés)
local function newThreat(d, attacker: Model): number?
	local s = CharacterState.get(attacker)
	local seen = d.seen[attacker]
	local na, gcd = s.nextAttack or 0, s.gcdUntil or 0
	if not seen then
		d.seen[attacker] = { na = na, gcd = gcd }
		return nil
	end
	local res
	if gcd > seen.gcd + 0.01 then
		res = 1.2 -- attaque de perso : windup plus long
	elseif na > seen.na + 0.01 then
		res = 0.45
	end
	seen.na, seen.gcd = na, gcd
	return res
end

local function perfectBlockStep(dummy: Model, d)
	local root = dummy:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local t = os.clock()
	local closest, closestD = nil, THREAT_RANGE
	for _, c in ipairs(fighters()) do
		local r = c:FindFirstChild("HumanoidRootPart")
		if r then
			local dist = (r.Position - root.Position).Magnitude
			if dist <= THREAT_RANGE then
				local dur = newThreat(d, c)
				if dur then
					d.threatUntil = math.max(d.threatUntil, t + dur)
				end
				if dist < closestD then
					closest, closestD = c, dist
				end
			end
		end
	end
	local s = CharacterState.get(dummy)
	if t < d.threatUntil then
		if closest then
			Npc.face(dummy, closest.HumanoidRootPart.Position)
		end
		if not s.blocking then
			Npc.block(dummy, true, true)
		end
		-- mannequin de démonstration : la fenêtre de perfect block reste toujours ouverte pendant la menace
		if s.blocking then
			local B = CombatConfig.Block
			if t - (s.blockStart or -10) > (B.PerfectWindow or 0.22) * 0.6 then
				s.blockStart = t
				s.parryAttempt = nil
				s.parryLockUntil = 0
			end
		end
	elseif s.blocking then
		Npc.block(dummy, false)
	end
end

local function slowStep(dummy: Model, d)
	local hum = dummy:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local t = os.clock()
	-- PV remplis 3 s après le combat
	if t - d.lastCombat >= REFILL_DELAY and hum.Health < hum.MaxHealth and not dummy:GetAttribute("PendingKO") then
		hum.Health = hum.MaxHealth
		d.comboHits = 0
	end
	local mode = dummy:GetAttribute("DummyMode") or "Idle"
	if mode == "Block" then
		local target = nearest(dummy, THREAT_RANGE)
		if target then
			Npc.face(dummy, target.HumanoidRootPart.Position)
		end
		if not CharacterState.get(dummy).blocking then
			Npc.block(dummy, true, false)
		end
	elseif mode == "CounterM1" then
		local a = d.lastAttacker
		if a and a.Parent and CharacterState.isAlive(a) and t - d.lastHitT < 2 and t >= d.nextCounter
			and not CharacterState.isStunned(dummy) and not CharacterState.isKnockedDown(dummy) then
			local ar, root = a:FindFirstChild("HumanoidRootPart"), dummy:FindFirstChild("HumanoidRootPart")
			if ar and root and (ar.Position - root.Position).Magnitude <= 8 then
				d.nextCounter = t + 1.8
				d.lastAttacker = nil
				Npc.face(dummy, ar.Position)
				task.spawn(function()
					if Npc.m1(dummy, 1) then
						task.wait(CombatConfig.M1.Cooldown[1] or 0.46)
						if ar.Parent then
							Npc.face(dummy, ar.Position)
						end
						Npc.m1(dummy, 2)
					end
				end)
			end
		end
	end
end

local function onHit(attacker, victim)
	local t = os.clock()
	local dv = dummies[victim]
	if dv then
		-- (synchrone, avant l'étourdissement de ce coup) : encore étourdi = coup du même combo
		if CharacterState.isStunned(victim) then
			dv.comboHits += 1
		else
			dv.comboHits = 1
		end
		dv.lastCombat = t
		dv.lastHitT = t
		dv.lastAttacker = attacker
		if victim:GetAttribute("DummyMode") == "Evasive" and dv.comboHits >= EVASIVE_AT then
			dv.comboHits = 0
			-- après le hit-stop (le recul part après le gel) : la victime est étourdie, EVASIVE possible
			task.delay((CombatConfig.HitStop.Light or 0.08) + 0.06, function()
				if victim.Parent and CharacterState.isAlive(victim) then
					CharacterState.get(victim).nextBreak = 0 -- mannequin : pas de recharge
					Npc.evasive(victim)
				end
			end)
		end
	end
	local da = attacker and dummies[attacker]
	if da then
		da.lastCombat = t
	end
end

local function touch(model)
	local d = model and dummies[model]
	if d then
		d.lastCombat = os.clock()
	end
end

function DummyService.init()
	workspace.Dummies:ClearAllChildren()
	TrainingService.handlers.SetMode = function(player: Player, dummy, mode)
		if typeof(dummy) ~= "Instance" or not dummies[dummy] or not isMode(mode) then
			return
		end
		local c = player.Character
		local r = c and c:FindFirstChild("HumanoidRootPart")
		local dr = dummy:FindFirstChild("HumanoidRootPart")
		if not r or not dr or (r.Position - dr.Position).Magnitude > 16 or not CharacterState.isAlive(dummy) then
			TrainingService.toast(player, "Get closer to the dummy", true)
			return
		end
		if DummyService.setMode(dummy, mode) then
			TrainingService.toast(player, "Dummy mode: " .. (MODE_LABELS[mode] or mode))
		end
	end
	Signals.Hit:Connect(onHit)
	Signals.Blocked:Connect(function(a, v)
		touch(a)
		touch(v)
	end)
	Signals.Parried:Connect(function(defender, attacker)
		touch(defender)
		touch(attacker)
	end)
	RunService.Heartbeat:Connect(function()
		for dummy, d in pairs(dummies) do
			if dummy.Parent and dummy:GetAttribute("DummyMode") == "PerfectBlock" and CharacterState.isAlive(dummy) then
				perfectBlockStep(dummy, d)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			for dummy, d in pairs(dummies) do
				if dummy.Parent then
					local ok, err = pcall(slowStep, dummy, d)
					if not ok then
						warn("[DummyService]", err)
					end
				end
			end
		end
	end)
	task.defer(function()
		-- évite le mannequin qui flotte au-dessus d'un étage pas encore chargé
		local t0 = os.clock()
		while not World.floorModel and os.clock() - t0 < 15 do
			task.wait(0.2)
		end
		if next(dummies) == nil then
			for slot = 1, COUNT do
				spawnDummy(slot)
			end
		end
	end)
end

return DummyService
