--[[
	CharacterState — état de combat de chaque personnage (joueurs + mannequin), côté serveur.
	Étourdissement, vitesse (modificateurs cumulés), garde, compteur de combo, série de coups reçus,
	statuts (aveuglé, marqué, ralenti), protection, dernier attaquant (kill feed).
	Les attributs répliqués servent aux effets et au HUD côté client (voir CONTRACT).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local Signals = require(script.Parent.Signals)

local CharacterState = {}

local states = setmetatable({}, { __mode = "k" }) -- [character] = state

local function now()
	return workspace:GetServerTimeNow()
end
CharacterState.now = now

function CharacterState.get(character: Model)
	local s = states[character]
	if not s then
		s = {
			stunUntil = 0,
			speedMods = {},      -- [nom] = multiplicateur (Item, Transform, Zone, Buff, Slow…)
			combo = 0, lastM1 = 0, airCombo = 0, lastAir = 0,
			nextAttack = 0, nextThrow = 0, nextDropkick = 0, nextDash = 0, nextBreak = 0,
			comboCount = 0, comboLast = 0,  -- coups réussis (attaquant)
			hitStreak = 0, streakLast = 0,  -- coups reçus d'affilée (combo breaker)
			recentVictims = {},             -- [victime] = os.clock() du dernier coup (finishers)
			blocking = false, blockStart = 0, lastBlockPress = -10, guard = CombatConfig.Block.MaxGuard,
			held = nil,
		}
		states[character] = s
	end
	return s
end

function CharacterState.setup(character: Model)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	states[character] = nil
	CharacterState.get(character)
	hum.MaxHealth = CombatConfig.MaxHealth
	hum.Health = CombatConfig.MaxHealth
	hum.BreakJointsOnDeath = false
	hum.UseJumpPower = true
	hum.JumpPower = CombatConfig.BaseJumpPower
	hum.WalkSpeed = CombatConfig.BaseWalkSpeed
	for _, p in ipairs(character:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CollisionGroup = "Characters"
		end
	end
	for _, a in ipairs({ "StunUntil", "DizzyUntil", "BlindUntil", "CD1", "CD2", "CD3", "CDDash", "CDBreak" }) do
		character:SetAttribute(a, 0)
	end
	character:SetAttribute("ComboCount", 0)
	character:SetAttribute("ComboStep", 0)
	character:SetAttribute("AirMax", CombatConfig.Combos.AirMaxDefault)
	character:SetAttribute("CDDropkick", 0)
	character:SetAttribute("CDMaxDropkick", CombatConfig.Dropkick.Cooldown)
	character:SetAttribute("Blocking", false)
	character:SetAttribute("CanBreak", false)
	character:SetAttribute("CDMaxDash", CombatConfig.Dash.Cooldown)

	-- mort : un seul endroit calcule le tueur, l'arme et la cause, puis prévient tout le monde
	hum.Died:Connect(function()
		local s = CharacterState.get(character)
		local recent = os.clock() - (s.lastHitTime or -100) < 10
		local killer = recent and s.lastAttacker or nil
		if killer and not killer.Parent then
			killer = nil
		end
		local cause = (recent and s.lastCause) or "Fall"
		if killer then
			cause = "Combat"
		end
		Signals.Died:Fire(character, killer, recent and s.lastWeapon or nil, cause)
	end)
	Signals.CharacterSpawned:Fire(character, Players:GetPlayerFromCharacter(character))
end

-- Mémorise qui a touché en dernier (kill feed, XP). cause = "Combat" | "Event"
function CharacterState.recordHit(victim: Model, attacker: Model?, weapon: string?, cause: string?)
	local s = CharacterState.get(victim)
	s.lastAttacker = attacker
	s.lastWeapon = weapon
	s.lastCause = cause or (attacker and "Combat" or "Event")
	s.lastHitTime = os.clock()
end

------------------------------------------------------------------------
-- Vitesse
------------------------------------------------------------------------
function CharacterState.refreshSpeed(character: Model)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local s = CharacterState.get(character)
	if now() < s.stunUntil then
		hum.WalkSpeed = CombatConfig.StunWalkSpeed
		hum.JumpPower = 0
		return
	end
	local mult = 1
	for name, m in pairs(s.speedMods) do
		if name ~= "Run" or not s.blocking then
			mult *= m
		end
	end
	local speed = CombatConfig.BaseWalkSpeed * mult
	if s.blocking then
		speed = math.min(speed, CombatConfig.Block.WalkSpeed)
	end
	hum.WalkSpeed = speed
	hum.JumpPower = s.blocking and 0 or CombatConfig.BaseJumpPower * math.clamp(mult + 0.2, 0.6, 1.2)
end

-- mult = nil pour retirer le modificateur ; duration optionnelle (retrait automatique)
function CharacterState.setSpeedMod(character: Model, name: string, mult: number?, duration: number?)
	local s = CharacterState.get(character)
	s.speedMods[name] = mult
	CharacterState.refreshSpeed(character)
	if mult and duration then
		local token = {}
		s["tok_" .. name] = token
		task.delay(duration, function()
			if s["tok_" .. name] == token then
				s.speedMods[name] = nil
				if character.Parent then
					CharacterState.refreshSpeed(character)
				end
			end
		end)
	end
end

-- compatibilité : multiplicateur de l'objet tenu
function CharacterState.setSpeedMult(character: Model, mult: number)
	CharacterState.setSpeedMod(character, "Item", mult ~= 1 and mult or nil)
end

------------------------------------------------------------------------
-- Étourdissement / statuts
------------------------------------------------------------------------
function CharacterState.stun(character: Model, duration: number)
	local s = CharacterState.get(character)
	local untilT = math.max(s.stunUntil, now() + duration)
	s.stunUntil = untilT
	character:SetAttribute("StunUntil", untilT)
	if duration >= CombatConfig.DizzyThreshold then
		character:SetAttribute("DizzyUntil", untilT)
	end
	if s.blocking then
		CharacterState.setBlocking(character, false)
	end
	CharacterState.setRunning(character, false)
	CharacterState.refreshSpeed(character)
	task.delay(duration + 0.02, function()
		if character.Parent then
			CharacterState.refreshSpeed(character)
		end
	end)
end

function CharacterState.clearStun(character: Model)
	local s = CharacterState.get(character)
	s.stunUntil = 0
	character:SetAttribute("StunUntil", 0)
	character:SetAttribute("DizzyUntil", 0)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.PlatformStand = false
	end
	CharacterState.refreshSpeed(character)
end

function CharacterState.isStunned(character: Model): boolean
	return now() < CharacterState.get(character).stunUntil
end

function CharacterState.blind(character: Model, duration: number)
	character:SetAttribute("BlindUntil", math.max(character:GetAttribute("BlindUntil") or 0, now() + duration))
end

function CharacterState.isAlive(character: Model?): boolean
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

function CharacterState.isAirborne(character: Model): boolean
	local hum = character:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.FloorMaterial == Enum.Material.Air
end

------------------------------------------------------------------------
-- Course (double W)
------------------------------------------------------------------------
function CharacterState.setRunning(character: Model, on: boolean)
	if (character:GetAttribute("Running") == true) == on then
		return
	end
	character:SetAttribute("Running", on)
	CharacterState.setSpeedMod(character, "Run", on and CombatConfig.Run.SpeedMultiplier or nil)
end

------------------------------------------------------------------------
-- Garde (block / parry)
------------------------------------------------------------------------
function CharacterState.setBlocking(character: Model, on: boolean)
	local s = CharacterState.get(character)
	if on == s.blocking then
		return
	end
	s.blocking = on
	if on then
		local t = os.clock()
		-- fenêtre de parade seulement si on n'a pas spammé la touche
		s.blockStart = (t - s.lastBlockPress >= CombatConfig.Block.ParryRearm) and t or -10
		s.lastBlockPress = t
	end
	character:SetAttribute("Blocking", on)
	CharacterState.refreshSpeed(character)
end

------------------------------------------------------------------------
-- Compteurs de combo
------------------------------------------------------------------------
function CharacterState.addCombo(attacker: Model, victim: Model): number
	local s = CharacterState.get(attacker)
	local t = os.clock()
	if t - s.comboLast > CombatConfig.ComboWindow then
		s.comboCount = 0
	end
	s.comboCount += 1
	s.comboLast = t
	s.recentVictims[victim] = t
	attacker:SetAttribute("ComboCount", s.comboCount)
	local mine = s.comboCount
	task.delay(CombatConfig.ComboWindow, function()
		if s.comboCount == mine and attacker.Parent then
			s.comboCount = 0
			attacker:SetAttribute("ComboCount", 0)
		end
	end)
	return s.comboCount
end

-- l'attaquant enchaîne-t-il sur cette victime ? (pour les finishers d'objet)
function CharacterState.inComboOn(attacker: Model, victim: Model): boolean
	local s = CharacterState.get(attacker)
	local t = s.recentVictims[victim]
	return t ~= nil and os.clock() - t < CombatConfig.ItemFinisher.Window and s.comboCount >= CombatConfig.ItemFinisher.MinCombo
end

-- série de coups reçus (combo breaker)
function CharacterState.addStreak(victim: Model)
	local s = CharacterState.get(victim)
	local t = os.clock()
	if t - s.streakLast > CombatConfig.ComboBreaker.Window then
		s.hitStreak = 0
	end
	s.hitStreak += 1
	s.streakLast = t
	victim:SetAttribute("CanBreak", s.hitStreak >= CombatConfig.ComboBreaker.Hits and os.clock() >= s.nextBreak)
	local mine = s.hitStreak
	task.delay(CombatConfig.ComboBreaker.Window, function()
		if s.hitStreak == mine and victim.Parent then
			s.hitStreak = 0
			victim:SetAttribute("CanBreak", false)
		end
	end)
end

------------------------------------------------------------------------
-- Protection d'apparition (bulle ForceField)
------------------------------------------------------------------------
function CharacterState.protect(character: Model, duration: number?)
	local ff = Instance.new("ForceField")
	ff.Visible = true
	ff.Parent = character
	game:GetService("Debris"):AddItem(ff, duration or CombatConfig.SpawnProtection)
end

function CharacterState.isProtected(character: Model): boolean
	return character:FindFirstChildOfClass("ForceField") ~= nil or character:GetAttribute("God") == true
end

return CharacterState
