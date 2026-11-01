--[[
	CharacterState — état de combat de chaque personnage (joueurs + mannequin), côté serveur.
	Étourdissement, vitesse (modificateurs cumulés), garde (jauge, guard break), renversé (knockdown),
	compteur de combo, statuts (aveuglé, marqué, ralenti), protection, zone sûre, dernier attaquant (kill feed).
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
			combo = 0, lastM1 = -10, airCombo = 0, airChainUntil = 0,
			nextAttack = 0, nextThrow = 0, nextDash = 0, nextDashStrike = 0,
			nextBreak = 0,                  -- prochaine EVASIVE possible (os.clock) ; UltimateService le repousse pendant une ulti
			busyUntil = 0,                  -- récupération d'attaque (os.clock) : pas de block ni d'attaque de perso
			endlagUntil = 0,                -- endlag d'un coup lourd (os.clock) : pas de dash non plus
			lastDash = -10, lastDashKind = "F",
			comboCount = 0, comboLast = 0,  -- coups réussis (attaquant)
			hitStreak = 0, streakLast = 0,  -- (compatibilité : remis à zéro par UltimateService)
			recentVictims = {},             -- [victime] = os.clock() du dernier coup (finishers)
			blocking = false, wantBlock = false, blockStart = -10, lastBlockPress = -10,
			parryAttempt = nil, parryLockUntil = 0, -- tentative de PERFECT BLOCK en cours / ratée -> verrou (os.clock)
			pendingKO = false,              -- coup fatal engagé (hit-stop K.O.) : plus aucun coup, mort assurée
			recentAttackers = {},           -- [attaquant] = os.clock() du dernier coup reçu (EVASIVE)
			chainStart = nil, chainLinks = 0, -- combo vrai subi (server time) : plafond anti-infini (CombatConfig.ComboCap)
			armorUntil = 0,                 -- super armure (server time) : windup d'une attaque Armor = true (AbilityService)
			guard = CombatConfig.Block.MaxGuard, guardT = 0, guardHitT = -100,
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
	for _, a in ipairs({ "StunUntil", "DizzyUntil", "BlindUntil", "CD1", "CD2", "CD3", "CDDash", "CDDashStrike", "CDEvasive", "KnockdownUntil", "GuardBrokenUntil", "EndlagUntil" }) do
		character:SetAttribute(a, 0)
	end
	character:SetAttribute("PendingKO", nil)
	character:SetAttribute("ComboCount", 0)
	character:SetAttribute("Blocking", false)
	character:SetAttribute("Guard", CombatConfig.Block.MaxGuard)
	character:SetAttribute("MaxGuard", CombatConfig.Block.MaxGuard)
	character:SetAttribute("CDMaxDash", CombatConfig.Dash.Cooldown)
	character:SetAttribute("CDMaxDashStrike", CombatConfig.DashStrike.Cooldown)
	character:SetAttribute("CDMaxEvasive", CombatConfig.Evasive.Cooldown)

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
	if attacker and attacker ~= victim then
		s.recentAttackers[attacker] = s.lastHitTime
	end
end

-- attaquants qui ont touché la victime dans les `window` dernières secondes (EVASIVE)
function CharacterState.recentAttackers(victim: Model, window: number): { Model }
	local s = CharacterState.get(victim)
	local t = os.clock()
	local out = {}
	for a, at in pairs(s.recentAttackers) do
		if t - at <= window and a.Parent then
			table.insert(out, a)
		elseif t - at > window then
			s.recentAttackers[a] = nil
		end
	end
	return out
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

-- ENDLAG (attaques lourdes, attaques de perso) : ni attaque, ni dash, ni block pendant `duration` ; le block en cours
-- est lâché. Attribut EndlagUntil (server time) -> ProcAnim tient la pose « Winded ».
function CharacterState.endlag(character: Model, duration: number?)
	if not duration or duration <= 0 then
		return
	end
	local s = CharacterState.get(character)
	local t = os.clock()
	s.busyUntil = math.max(s.busyUntil, t + duration)
	s.endlagUntil = math.max(s.endlagUntil, t + duration)
	s.nextAttack = math.max(s.nextAttack, t + duration)
	character:SetAttribute("EndlagUntil", math.max(character:GetAttribute("EndlagUntil") or 0, now() + duration))
	if s.blocking then
		CharacterState.setBlocking(character, false)
	end
end

function CharacterState.inEndlag(character: Model): boolean
	return os.clock() < CharacterState.get(character).endlagUntil
end

-- super armure : encaisse les coups sans hitstun ni recul (sauf ultimes et casse-garde)
function CharacterState.hasArmor(character: Model): boolean
	return now() < (CharacterState.get(character).armorUntil or 0)
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
-- Garde (block / perfect block / guard break)
------------------------------------------------------------------------
-- noParry = true : block activé automatiquement (F maintenu à la fin d'un hitstun / d'une récupération) :
-- pas de fenêtre de PERFECT BLOCK (sinon maintenir F pendant un combo donnerait une parade gratuite).
-- Anti-spam : une tentative de perfect block RATÉE (fenêtre écoulée sans coup) verrouille la parade pendant
-- ParryFailRearm après la fin de la fenêtre : rappuyer sur F pendant ce verrou ne donne qu'un block normal.
-- Maintenir F ne renouvelle jamais la fenêtre (elle ne s'ouvre qu'à l'appui).
function CharacterState.setBlocking(character: Model, on: boolean, noParry: boolean?)
	local s = CharacterState.get(character)
	if on == s.blocking then
		return
	end
	s.blocking = on
	if on then
		local t = os.clock()
		local B = CombatConfig.Block
		local window = B.PerfectWindow or B.ParryWindow
		-- tentative précédente jamais consommée par un coup : ratée -> verrou
		if s.parryAttempt and t - s.parryAttempt > window then
			s.parryLockUntil = math.max(s.parryLockUntil, s.parryAttempt + window + (B.ParryFailRearm or 1))
			s.parryAttempt = nil
		end
		local can = not noParry and t - s.lastBlockPress >= B.ParryRearm and t >= s.parryLockUntil and not s.parryAttempt
		-- latence du bloqueur : l'appui est daté de son vrai moment (arrivée - ping/2, au plus PingAllowance),
		-- la fenêtre de PERFECT BLOCK est mesurée depuis ce moment-là (PNJ / mannequins : pas de correction)
		local lag = 0
		local pl = Players:GetPlayerFromCharacter(character)
		if pl then
			local ok, ping = pcall(pl.GetNetworkPing, pl)
			if ok and type(ping) == "number" and ping == ping then
				lag = math.clamp(ping / 2, 0, B.PingAllowance or 0.1)
			end
		end
		s.blockStart = can and (t - lag) or -10
		if can then
			s.parryAttempt = t
		end
		s.lastBlockPress = t
	end
	character:SetAttribute("Blocking", on)
	CharacterState.refreshSpeed(character)
end

-- jauge de garde à l'instant présent (régénération paresseuse après GuardRegenDelay sans coup bloqué)
function CharacterState.guardNow(character: Model): number
	local s = CharacterState.get(character)
	local B = CombatConfig.Block
	local t = os.clock()
	if s.guard < B.MaxGuard then
		local from = math.max(s.guardT or t, (s.guardHitT or -100) + B.GuardRegenDelay)
		if t > from then
			s.guard = math.min(B.MaxGuard, s.guard + (t - from) * B.GuardRegen)
		end
	end
	s.guardT = t
	return s.guard
end

-- retire de la garde ; renvoie la garde restante
function CharacterState.drainGuard(character: Model, amount: number): number
	local s = CharacterState.get(character)
	CharacterState.guardNow(character)
	s.guard = math.max(0, s.guard - math.max(0, amount))
	s.guardHitT = os.clock()
	character:SetAttribute("Guard", math.floor(s.guard + 0.5))
	return s.guard
end

-- GUARD BREAK : block cassé, étourdi, impossible de rebloquer pendant la durée ; la jauge repart pleine
function CharacterState.guardBreak(character: Model, duration: number?)
	local s = CharacterState.get(character)
	duration = duration or CombatConfig.Block.GuardBreakStun
	s.guard = CombatConfig.Block.MaxGuard
	s.guardHitT = os.clock()
	s.wantBlock = false
	character:SetAttribute("Guard", CombatConfig.Block.MaxGuard)
	character:SetAttribute("GuardBrokenUntil", now() + duration)
	CharacterState.setBlocking(character, false)
	CharacterState.stun(character, duration)
end

function CharacterState.isGuardBroken(character: Model): boolean
	return now() < (character:GetAttribute("GuardBrokenUntil") or 0)
end

-- mise à jour de l'attribut Guard (HUD) pour les jauges qui remontent ; appelé régulièrement par CombatService
function CharacterState.tickGuards()
	for character, s in pairs(states) do
		if s.guard < CombatConfig.Block.MaxGuard and character.Parent then
			CharacterState.guardNow(character)
			character:SetAttribute("Guard", math.floor(s.guard + 0.5))
		end
	end
end

------------------------------------------------------------------------
-- Renversé (knockdown) : au sol, intouchable sauf ultimes, puis relevé avec une courte invulnérabilité
------------------------------------------------------------------------
function CharacterState.knockdown(character: Model, duration: number?)
	local K = CombatConfig.Knockdown
	duration = duration or K.Duration
	local s = CharacterState.get(character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local untilT = math.max(character:GetAttribute("KnockdownUntil") or 0, now() + duration)
	character:SetAttribute("KnockdownUntil", untilT)
	s.chainStart, s.chainLinks = nil, 0 -- le combo subi s'arrête au sol
	CharacterState.stun(character, untilT - now())
	hum.PlatformStand = true
	local token = {}
	s.kdToken = token
	task.delay(untilT - now(), function()
		if s.kdToken ~= token or not character.Parent then
			return
		end
		s.kdToken = nil
		s.chainStart, s.chainLinks = nil, 0
		character:SetAttribute("KnockdownUntil", 0)
		local h = character:FindFirstChildOfClass("Humanoid")
		if h and h.Health > 0 then
			h.PlatformStand = false
			CharacterState.protect(character, K.GetUpIFrames, false)
		end
	end)
end

function CharacterState.isKnockedDown(character: Model): boolean
	return now() < (character:GetAttribute("KnockdownUntil") or 0)
end

-- zone sûre (zone AFK) : ni coups donnés ni coups reçus
function CharacterState.inSafeZone(character: Model?): boolean
	return character ~= nil and character:GetAttribute(CombatConfig.SafeZoneAttribute or "SafeZone") == true
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

------------------------------------------------------------------------
-- Protection d'apparition (bulle ForceField)
------------------------------------------------------------------------
-- visible = false : invulnérabilité discrète (relevé, evasive)
function CharacterState.protect(character: Model, duration: number?, visible: boolean?)
	local ff = Instance.new("ForceField")
	ff.Visible = visible ~= false
	ff.Parent = character
	game:GetService("Debris"):AddItem(ff, duration or CombatConfig.SpawnProtection)
end

function CharacterState.isProtected(character: Model): boolean
	return character:FindFirstChildOfClass("ForceField") ~= nil or character:GetAttribute("God") == true
end

return CharacterState
