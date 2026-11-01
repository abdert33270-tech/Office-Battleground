--[[
	CombatController — entrées de combat du joueur local (système « ABA », voir Config/Combat et docs/Combat-ABA.md).
	PC : clic gauche = chaîne de 5 M1 (maintenu = enchaîne) ; Espace maintenu sur le 5e coup = UPPERCUT (saut automatique,
	     puis 3 clics en l'air, le 3e = DOWNSLAM) ; 5e clic en l'air = DOWNSLAM ;
	     Q = dash directionnel (avant / arrière / côté, relatif à la caméra) ; dash avant + clic = DASH STRIKE ;
	     Q pendant un hitstun = EVASIVE ; F = block (maintenu) / PERFECT BLOCK (au bon moment) ;
	     E = ramasser/lâcher, R = lancer, 1/2/3 = attaques, G = transformation / ultime.
	Molette (clic du milieu) / R3 = LOCK-ON (caméra entre soi et la cible, décalée sur l'épaule ; relâché si la cible
	meurt, s'éloigne à plus de 60 studs, ou pendant une cinématique d'ulti).
	Manette : R2, X, Y, B (dash), L2 (block), L1 (transformation). Saut (A) = Espace.
	Mobile : AUCUN bouton ici — le HUD crée les boutons et appelle l'API publique :
	         attack(), pickup(), throw(), dash(), setBlock(on), ability(i), transform(). Bouton saut = Espace.
	Réactivité : animation, pas en avant, whoosh et effets de coup (prédiction locale) sont joués tout de suite.
	Le serveur reste seul juge des dégâts ; le client lui envoie seulement l'index du coup (vérifié côté serveur).
	Anti « coup fantôme » : pas de prédiction sur une victime qui vient d'EVASIVE / de changer de block (0,25 s) ;
	ping > 120 ms : seuls étincelle + son sont prédits, hit-stop / caméra / réaction attendent la confirmation.
	Dash : avant = 0,06 s d'accroupi avant la poussée ; côté = orbite autour de la cible du soft-lock.
	Endlag (attribut EndlagUntil, heure serveur) : ni dash ni block prédits tant qu'il dure (le serveur les refuse).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.Combat)
local ItemsConfig = require(Shared.Config.Items)
local WordsConfig = require(Shared.Config.Words)
local SoundsConfig = require(Shared.Config.Sounds)
local Net = require(Shared.Modules.Net)
local Hitbox = require(Shared.Modules.Hitbox)
local ProcAnim = require(Shared.Modules.ProcAnim)
local M1Style = require(Shared.Modules.M1Style) -- animation de M1 selon l'arme fétiche (Config/M1Styles)
local CartoonFX = require(Shared.Modules.CartoonFX)
local UITheme = require(Shared.Modules.UITheme)
local ClientSettings = require(Shared.Modules.ClientSettings)

local CombatController = {}
CombatController.Priority = 10

local GHOST_WINDOW = 0.25 -- s : victime instable (evasive / block qui vient de changer) = pas de prédiction
local LITE_PING = 0.12 -- s : au-delà, prédiction réduite à étincelle + son
local LOCK_RANGE = 60
local ctxRef = {}

local player = Players.LocalPlayer
local M1 = CombatConfig.M1
local U = CombatConfig.Uppercut
local A = CombatConfig.Air
local DS = CombatConfig.DashStrike
local SL = CombatConfig.Downslam
local DASH_ANIMS = { F = "Dash", B = "DashBack", L = "SideDashL", R = "SideDashR" }

local seq = 0
-- chaîne de M1 (miroir de la logique serveur : CombatService.nextIndex)
local combo, lastM1 = 0, -10
local nextAttack, nextThrow, nextDash, nextDashStrike = 0, 0, 0, 0
local busyUntil, endlagUntil = 0, 0 -- récupération (pas de block) / endlag d'un coup lourd (pas de dash)
local lastDash, lastDashKind = -10, "F"
local airCombo, airChainUntil = 0, 0 -- jongle après un uppercut réussi
local riseLockUntil = 0 -- pas de saut normal pendant l'armé de l'uppercut
local holdingAttack, holdingWithMouse = false, false
local wantBlock, blocking, blockSentAt = false, false, 0
local buffered = false

CombatController.predicted = {} -- [seq] = {[victime] = true}

local function character()
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	-- pendant une ulti / une prise d'ulti / l'animation de transformation : aucune action
	if hum and hum.Health > 0 and not c:GetAttribute("UltAnchor") and not c:GetAttribute("UltActive") then
		return c, hum
	end
	return nil
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function isStunned(c)
	return serverNow() < (c:GetAttribute("StunUntil") or 0)
end

local function guardBroken(c)
	return serverNow() < (c:GetAttribute("GuardBrokenUntil") or 0)
end

local function knockedDown(c)
	return serverNow() < (c:GetAttribute("KnockdownUntil") or 0)
end

-- endlag serveur (attaques, coups lourds) : le serveur refuse dash et block pendant ce temps
local function inEndlag(c)
	return serverNow() < (tonumber(c:GetAttribute("EndlagUntil")) or 0)
end

local function inSafeZone(c)
	return c:GetAttribute(CombatConfig.SafeZoneAttribute or "SafeZone") == true
end

-- caméra : CartoonFX.shake applique déjà le réglage joueur ScreenShake (ne pas le multiplier ici) ;
-- zoom FOV désactivable (FOVKick)
local function camShake(amount: number)
	CartoonFX.shake(amount)
end
local function camKick(amount: number)
	if ClientSettings.get("FOVKick") ~= false then
		CartoonFX.fovKick(amount)
	end
end

-- Espace / bouton saut maintenu (sert à l'UPPERCUT)
local function jumpHeld(hum)
	return UserInputService:IsKeyDown(Enum.KeyCode.Space)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
		or (hum ~= nil and hum.Jump == true) -- bouton saut mobile (et toute entrée de saut du ControlModule)
end

-- fin de chaîne au sol (après le 3e coup) : Espace sert à l'UPPERCUT, il ne doit pas faire sauter.
-- (sauter pendant les coups 1-3 reste possible : la chaîne continue en l'air et le 5e coup devient un DOWNSLAM)
local function uppercutReady()
	return combo >= 3 and combo < M1.Hits and os.clock() - lastM1 <= M1.ComboReset
end

-- ennemi le plus proche dans le cône devant la caméra (verrouillage doux)
local function softTarget(c)
	local root = c:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not root or not cam then
		return nil
	end
	local L = CombatConfig.SoftLock
	-- lock-on actif : la cible verrouillée est prioritaire si elle est à portée de coup
	local locked = CombatController.lockTarget and CombatController.lockTarget()
	local lr = locked and locked:FindFirstChild("HumanoidRootPart")
	if lr and (Vector3.new(lr.Position.X - root.Position.X, 0, lr.Position.Z - root.Position.Z)).Magnitude <= L.Range * 1.2 then
		return lr
	end
	local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	look = look.Magnitude > 0.05 and look.Unit or root.CFrame.LookVector
	local best, bestScore = nil, math.huge
	for _, other in ipairs(Hitbox.characters()) do
		local r = other ~= c and other:FindFirstChild("HumanoidRootPart")
		if r then
			local to = Vector3.new(r.Position.X - root.Position.X, 0, r.Position.Z - root.Position.Z)
			local d = to.Magnitude
			if d > 0.1 and d <= L.Range and math.abs(r.Position.Y - root.Position.Y) < 12 then
				local ang = math.deg(math.acos(math.clamp(to.Unit:Dot(look), -1, 1)))
				-- victime tenue en laisse par notre combo (elle nous suit) : prioritaire, même hors du cône de la caméra
				local held = d <= 7 and r:FindFirstChild("ComboTether") and os.clock() - lastM1 < 1.2
				if held and d - 100 < bestScore then
					best, bestScore = r, d - 100
				elseif ang <= L.Angle and d + ang * 0.08 < bestScore then
					best, bestScore = r, d + ang * 0.08
				end
			end
		end
	end
	return best
end

local function faceCamera(c)
	local root = c:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local target = softTarget(c)
	if target then
		local to = Vector3.new(target.Position.X, root.Position.Y, target.Position.Z)
		if (to - root.Position).Magnitude > 0.05 then
			root.CFrame = CFrame.lookAt(root.Position, to)
		end
		return target
	end
	local cam = workspace.CurrentCamera
	if not cam then
		return nil
	end
	local flat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	if flat.Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
	return nil
end

-- petite poussée physique locale (pas en avant, dash, dash strike)
local function push(c, velocity: Vector3, duration: number)
	local root = c:FindFirstChild("HumanoidRootPart")
	if not root or root.Anchored then
		return
	end
	local att = root:FindFirstChild("PushAtt") or Instance.new("Attachment")
	att.Name = "PushAtt"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Push"
	lv.Attachment0 = att
	lv.MaxForce = 1e5
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.Parent = root
	Debris:AddItem(lv, duration)
end

-- DASH DE CÔTÉ autour de la cible : vitesse tangentielle recalculée à chaque image (trajectoire courbe) + rappel
-- radial pour garder la distance de départ ; on reste tourné vers la cible. sign = 1 : vers la droite.
local FORWARD_ANTIC = 0.06
local function orbitDash(c, target: BasePart, sign: number, speed: number, duration: number)
	local root = c:FindFirstChild("HumanoidRootPart")
	if not root or root.Anchored then
		return
	end
	local function flatTo()
		return Vector3.new(target.Position.X - root.Position.X, 0, target.Position.Z - root.Position.Z)
	end
	local r0 = flatTo().Magnitude
	if r0 < 1 or r0 > 18 then
		local look = root.CFrame.RightVector * sign
		push(c, look * speed, duration)
		return
	end
	-- au plus ~100° de rotation sur la durée du dash (une cible collée ne fait pas tourner en toupie)
	local tangential = math.min(speed, math.max(r0, 4) * 1.75 / duration)
	local att = root:FindFirstChild("PushAtt") or Instance.new("Attachment")
	att.Name = "PushAtt"
	att.Parent = root
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Push"
	lv.Attachment0 = att
	lv.MaxForce = 1e5
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	local t0 = os.clock()
	local function step()
		local to = flatTo()
		local d = to.Magnitude
		if d < 0.5 then
			return
		end
		local inward = to / d
		local tangent = inward:Cross(Vector3.yAxis) * sign -- (vers la cible) x (haut) = droite
		local v = tangent * tangential + inward * math.clamp((d - r0) * 8, -20, 20)
		lv.PlaneVelocity = Vector2.new(v.X, v.Z)
		if not root.Anchored then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + inward)
		end
	end
	step()
	lv.Parent = root
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not lv.Parent or not root.Parent or not target.Parent or os.clock() - t0 >= duration then
			conn:Disconnect()
			if lv.Parent then
				lv:Destroy()
			end
			return
		end
		step()
	end)
	Debris:AddItem(lv, duration + 0.05)
end

-- suspension locale en l'air (jongles)
local function stallLocal(c, duration)
	local root = c:FindFirstChild("HumanoidRootPart")
	if not root or root.Anchored then
		return
	end
	local att = root:FindFirstChild("PushAtt") or Instance.new("Attachment")
	att.Name = "PushAtt"
	att.Parent = root
	local old = root:FindFirstChild("LocalStall")
	if old then
		old:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "LocalStall"
	lv.Attachment0 = att
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	lv.LineDirection = Vector3.yAxis
	lv.LineVelocity = 0.5
	lv.MaxForce = 1e6
	lv.Parent = root
	Debris:AddItem(lv, duration)
end
CombatController.stallLocal = stallLocal

-- fin de jongle (slam / evasive) : on retire toutes les suspensions et on retombe tout de suite (jamais coincé en l'air)
local function releaseAir(c)
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	airChainUntil = 0
	for _, ch in ipairs(root:GetChildren()) do
		if ch.Name == "LocalStall" or ch.Name == "LocalLift" or ch.Name == "AirStall" then
			ch:Destroy()
		end
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum and hum.FloorMaterial == Enum.Material.Air and not root.Anchored then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X * 0.3, math.min(v.Y, -28), v.Z * 0.3)
	end
end
CombatController.releaseAir = releaseAir

-- PRÉDICTION d'un coup (attaquant local) : tout le « ressenti » part tout de suite (étincelles, impact, sons,
-- réaction de la victime, hit-stop, caméra) ; les MOTS, le CHIFFRE de dégâts et le K.O. attendent la confirmation
-- du serveur (payload « Hit » de ce seq, voir confirmHit) : un coup parré / bloqué au dernier moment n'affiche
-- donc jamais « POW! 3 » à tort. FXController saute le « Hit » serveur déjà prédit (CombatController.predicted).
-- « ressenti » d'un coup : réaction directionnelle de la victime, hit-stop, caméra (prédit, ou à la confirmation si ping élevé)
local function hitFeel(c, victim, category: string, reaction: string?)
	local heavy = category == "Heavy"
	CartoonFX.reaction(victim, c, reaction or "Light")
	local HS, SH, FK = CombatConfig.HitStop, CombatConfig.Shake, CombatConfig.FOVKick
	local hs = heavy and HS.Heavy or HS.Light
	ProcAnim.freeze(c, hs)
	ProcAnim.freeze(victim, hs)
	CartoonFX.freezeLocal(hs)
	camShake(heavy and SH.Heavy or SH.Light)
	camKick(heavy and FK.Heavy or FK.Light)
	if heavy then
		CartoonFX.impactFrame(1)
		CartoonFX.speedLines(0.3)
	end
end

-- lite = true (ping élevé) : seulement étincelle + son ; le reste attend la confirmation du serveur (confirmHit)
local function predictVisual(c, victim, pos: Vector3, spec, extra, lite: boolean?)
	local category = spec.Category or "Light"
	local power = tonumber(spec.Power) or 0.4
	local heavy = category == "Heavy"
	local vRoot = victim:FindFirstChild("HumanoidRootPart")
	local aRoot = c:FindFirstChild("HumanoidRootPart")
	local dir = (vRoot and aRoot) and (vRoot.Position - aRoot.Position) or nil
	CartoonFX.noteEngage(c, victim)
	CartoonFX.hitSpark(pos, dir, power + (heavy and 0.4 or 0))
	CartoonFX.sound(SoundsConfig.Category[category] or "Punch", pos, 0.9 + power * 0.5, heavy and 0.92 or 1.05)
	if lite then
		return
	end
	CartoonFX.impact(pos, power)
	CartoonFX.flash(victim, heavy and 0.12 or 0.07)
	CartoonFX.sparks(pos, heavy and 18 or 8)
	CartoonFX.shards(pos, heavy and 10 or 4, nil, heavy and 1.2 or 0.8)
	if heavy then
		CartoonFX.bigImpact(pos, dir, power)
	end
	local r = extra and extra.Reaction or "Light"
	CartoonFX.sound("Thud", pos, 0.45, heavy and 0.8 or 1.15)
	if heavy then
		CartoonFX.sound("BigImpact", pos, 1.1)
		CartoonFX.sound("AnimeHit", pos, 0.7)
	end
	if extra and extra.Material and SoundsConfig.MaterialHit and SoundsConfig.MaterialHit[extra.Material] then
		CartoonFX.sound(SoundsConfig.MaterialHit[extra.Material], pos, 1)
	end
	if r == "Launch" then
		CartoonFX.sound("Boing", pos, 0.6)
	end
	hitFeel(c, victim, category, r)
end

-- confirmation serveur d'un coup prédit : mot + chiffre (+ K.O.), que FXController ne jouera pas (déjà prédit)
local function confirmHit(data, lite)
	if lite and data.a and data.v then
		-- ping élevé : impact, réaction, hit-stop et caméra joués maintenant (le serveur a validé le coup)
		local p = typeof(data.p) == "Vector3" and data.p or nil
		if p then
			CartoonFX.impact(p, tonumber(data.pw) or 0.4)
			CartoonFX.sparks(p, data.c == "Heavy" and 18 or 8)
		end
		CartoonFX.flash(data.v, data.c == "Heavy" and 0.12 or 0.07)
		hitFeel(data.a, data.v, data.c or "Light", data.r)
	end
	local pos = data.p
	if typeof(pos) ~= "Vector3" then
		local r = data.v and data.v:FindFirstChild("HumanoidRootPart")
		pos = r and r.Position
	end
	if typeof(pos) ~= "Vector3" then
		return
	end
	local category = data.c or "Light"
	local power = tonumber(data.pw) or 0.4
	local list = (type(data.w) == "table" and #data.w > 0) and data.w or WordsConfig[category] or WordsConfig.Light
	local ctx = { a = data.a, v = data.v, avoid = { data.a, data.v } }
	CartoonFX.word(pos, list[math.random(1, #list)], power + (data.fin and 0.4 or 0), category, ctx)
	if type(data.d) == "number" and data.d > 0 then
		CartoonFX.damageNumber(pos, data.d, power, ctx)
	end
	if data.ko then
		CartoonFX.ko(data.v, pos, true, data.a)
		camShake(CombatConfig.Shake.KO)
		camKick(CombatConfig.FOVKick.KO)
	end
end

-- victimes « instables » : changement de block / EVASIVE dans les GHOST_WINDOW dernières secondes
local blockChangedAt = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })
local function watchVictim(v)
	if watched[v] then
		return
	end
	watched[v] = true
	v:GetAttributeChangedSignal("Blocking"):Connect(function()
		blockChangedAt[v] = os.clock()
	end)
end
local function unstable(v): boolean
	watchVictim(v)
	if serverNow() - (tonumber(v:GetAttribute("EvasiveAt")) or -100) < GHOST_WINDOW then
		return true
	end
	return os.clock() - (blockChangedAt[v] or -100) < GHOST_WINDOW
end
local function highPing(): boolean
	local ok, ping = pcall(player.GetNetworkPing, player)
	return ok and type(ping) == "number" and ping > LITE_PING
end

local function predictHits(c, spec, mySeq, extra)
	task.delay(spec.Windup or 0.1, function()
		if not character() then
			return
		end
		local cf = Hitbox.frontCFrame(c, spec.HitboxOffset)
		local root = c:FindFirstChild("HumanoidRootPart")
		if not cf or not root then
			return
		end
		local lite = highPing()
		for _, victim in ipairs(Hitbox.box(cf, spec.HitboxSize, c, 3)) do
			local vRoot = victim:FindFirstChild("HumanoidRootPart")
			local hum = victim:FindFirstChildOfClass("Humanoid")
			-- (cible qui bloque / renversée / protégée : rien de prédit, le serveur enverra Block / PerfectBlock)
			if vRoot and hum and hum.Health > 0 and not victim:FindFirstChildOfClass("ForceField") and not victim:GetAttribute("Blocking")
				and not victim:GetAttribute("PendingKO") and not knockedDown(victim) and not inSafeZone(victim) and not unstable(victim) then
				CombatController.predicted[mySeq] = CombatController.predicted[mySeq] or {}
				CombatController.predicted[mySeq][victim] = lite and "lite" or true
				predictVisual(c, victim, vRoot.Position:Lerp(root.Position, 0.3) + Vector3.new(0, 0.6, 0), spec, extra, lite)
			end
		end
		task.delay(2, function()
			CombatController.predicted[mySeq] = nil
		end)
	end)
end

-- récupération locale (même règle que le serveur : setRecovery)
local function setRecovery(t: number, cooldown: number, heavy: boolean)
	nextAttack = t + cooldown
	busyUntil = t + cooldown + (heavy and 0 or M1.DropEndlag)
	endlagUntil = heavy and (t + cooldown) or 0
end

-- index du prochain coup de la chaîne (1..5)
local function nextIndex(t: number): number
	local i = (combo > 0 and combo < M1.Hits and t - lastM1 <= M1.ComboReset) and combo + 1 or 1
	lastM1 = t
	combo = (i >= M1.Hits) and 0 or i
	return i
end

local function airSpec(i)
	return { Windup = A.Windup, HitboxOffset = A.HitboxOffset, HitboxSize = A.HitboxSize, Damage = A.Damage[((i - 1) % #A.Damage) + 1],
		Category = "Light", Power = 0.4 }
end

------------------------------------------------------------------------
-- API publique
------------------------------------------------------------------------
function CombatController.attack()
	local c, hum = character()
	if not c or isStunned(c) or blocking or inSafeZone(c) then
		return
	end
	local t = os.clock()
	if t < nextAttack then
		-- mémoire de clic : un clic un peu trop tôt part dès que possible
		if not buffered and nextAttack - t <= CombatConfig.InputBuffer then
			buffered = true
			task.delay(nextAttack - t + 0.01, function()
				buffered = false
				CombatController.attack()
			end)
		end
		return
	end
	local root = c:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	seq += 1
	local target = faceCamera(c)
	if target then
		ProcAnim.setLookTarget(c, target, 0.8) -- la tête suit la cible pendant le coup
	end
	local look = root.CFrame.LookVector
	local gap = target and (Vector3.new(target.Position.X, 0, target.Position.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude or 0
	local extraLunge = (gap > 4.5) and math.min((gap - 3.5) * 9, 40) or 0 -- on recolle à la cible si elle s'éloigne
	if target and target:FindFirstChild("ComboTether") then
		extraLunge = 0 -- elle est tenue en laisse : c'est elle qui nous suit
	end
	local heldId = c:GetAttribute("HeldItem")
	local itemCfg = heldId and ItemsConfig[heldId]
	local airborne = hum.FloorMaterial == Enum.Material.Air
	local mods = { up = jumpHeld(hum), air = airborne }

	if itemCfg then
		local use = itemCfg.Use
		nextAttack = t + use.Cooldown
		busyUntil = nextAttack
		combo = 0
		local useAnim, chainIndex = M1Style.itemAnim(c, use.Anim or "Jab")
		mods.ic = chainIndex -- le serveur rejoue la même variante pour les autres joueurs
		ProcAnim.play(c, useAnim)
		if use.Lunge then
			push(c, look * use.Lunge, 0.1)
		end
		if use.Damage then
			predictHits(c, use, seq, { Words = use.Words, Material = itemCfg.Material, Reaction = use.Category == "Heavy" and "Heavy" or "Light" })
		end
	elseif not airborne and lastDashKind == "F" and t - lastDash <= DS.Window and t >= nextDashStrike then
		-- DASH STRIKE
		nextDashStrike = t + DS.Cooldown
		lastDash = -10
		combo = 0
		setRecovery(t, DS.Endlag, true)
		ProcAnim.play(c, M1Style.remap(c, DS.Anim))
		push(c, look * DS.LungeSpeed, DS.LungeTime)
		predictHits(c, { Windup = DS.Windup, HitboxOffset = DS.HitboxOffset, HitboxSize = DS.HitboxSize, Damage = DS.Damage,
			Category = "Heavy", Power = DS.Power }, seq, { Words = DS.Words, Reaction = "Heavy" })
	elseif airborne and t < airChainUntil then
		-- jongle après l'uppercut : le dernier coup écrase
		airCombo += 1
		if airCombo >= U.AirHits then
			airCombo, airChainUntil = 0, 0
			setRecovery(t, SL.Endlag, true)
			ProcAnim.play(c, M1Style.remap(c, SL.Anim))
			task.delay(SL.Windup + 0.03, releaseAir, c) -- le coup qui écrase : l'attaquant retombe juste après
			predictHits(c, { Windup = SL.Windup, HitboxOffset = A.HitboxOffset, HitboxSize = A.HitboxSize, Damage = SL.Damage,
				Category = "Heavy", Power = SL.Power }, seq, { Words = SL.Words, Reaction = "Slam" })
		else
			setRecovery(t, A.Cooldown, false)
			ProcAnim.play(c, M1Style.remap(c, A.Anim[((airCombo - 1) % #A.Anim) + 1]))
			if not root:FindFirstChild("LocalLift") then
				stallLocal(c, A.Stall) -- on reste en l'air pendant la jongle (jamais pendant la montée)
			end
			predictHits(c, airSpec(airCombo), seq)
		end
	elseif airborne then
		-- chaîne en l'air : le 5e coup = DOWNSLAM
		local i = nextIndex(t)
		mods.i = i
		if i >= M1.Hits then
			setRecovery(t, SL.Endlag, true)
			ProcAnim.play(c, M1Style.remap(c, SL.Anim))
			task.delay(SL.Windup + 0.03, releaseAir, c)
			predictHits(c, { Windup = SL.Windup, HitboxOffset = A.HitboxOffset, HitboxSize = A.HitboxSize, Damage = SL.Damage,
				Category = "Heavy", Power = SL.Power }, seq, { Words = SL.Words, Reaction = "Slam" })
		else
			setRecovery(t, M1.Cooldown[i], false)
			ProcAnim.play(c, M1Style.remap(c, A.Anim[((i - 1) % #A.Anim) + 1]))
			predictHits(c, airSpec(i), seq)
		end
	else
		local i = nextIndex(t)
		mods.i = i
		if i >= M1.Hits and mods.up then
			-- UPPERCUT : on reste au sol pendant l'armé, le saut automatique vient après confirmation du serveur
			riseLockUntil = t + U.Windup + 0.35
			setRecovery(t, M1.Cooldown[M1.Hits], true)
			ProcAnim.play(c, M1Style.remap(c, U.Anim))
			push(c, look * (M1.Lunge[i] + extraLunge), 0.1)
			CartoonFX.sound("Uppercut", root.Position, 0.8)
			predictHits(c, { Windup = U.Windup, HitboxOffset = M1.HitboxOffset, HitboxSize = M1.HitboxSize, Damage = U.Damage,
				Category = "Heavy", Power = U.Power }, seq, { Words = U.Words, Reaction = "Launch" })
		else
			setRecovery(t, M1.Cooldown[i], i >= M1.Hits)
			push(c, look * (M1.Lunge[i] + extraLunge), 0.1)
			ProcAnim.play(c, M1Style.remap(c, M1.Anim[i]))
			predictHits(c, { Windup = M1.Windup[i], HitboxOffset = M1.HitboxOffset, HitboxSize = M1.HitboxSize, Damage = M1.Damage[i],
				Category = M1.Category[i], Power = M1.Power[i] }, seq,
				{ Reaction = i >= M1.Hits and "Heavy" or "Light", Words = i >= M1.Hits and M1.FinisherWords or nil })
		end
	end
	CartoonFX.sound("Whoosh", root.Position, 0.5)
	Net.get("Attack"):FireServer(seq, mods)
end

function CombatController.pickup()
	if character() then
		Net.get("Pickup"):FireServer()
	end
end

local function aimDirection(c): Vector3
	local root = c:FindFirstChild("HumanoidRootPart")
	local dir = workspace.CurrentCamera.CFrame.LookVector
	if not root then
		return dir
	end
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		local best, bestScore = nil, math.huge
		for _, other in ipairs(Hitbox.characters()) do
			local oRoot = other ~= c and other:FindFirstChild("HumanoidRootPart")
			if oRoot then
				local to = oRoot.Position - root.Position
				local dist = to.Magnitude
				if dist < 70 and dist > 0 then
					local angle = math.deg(math.acos(math.clamp(to.Unit:Dot(dir), -1, 1)))
					if angle < 35 and dist + angle < bestScore then
						best, bestScore = to.Unit, dist + angle
					end
				end
			end
		end
		return best or dir
	end
	local d = player:GetMouse().Hit.Position - (root.Position + Vector3.new(0, 1.5, 0))
	return d.Magnitude > 4 and d.Unit or dir
end
CombatController.aimDirection = aimDirection

function CombatController.throw()
	local c = character()
	if not c or isStunned(c) or inSafeZone(c) then
		return
	end
	local heldId = c:GetAttribute("HeldItem")
	local cfg = heldId and ItemsConfig[heldId]
	local t = os.clock()
	if not cfg or t < nextThrow then
		return
	end
	nextThrow = t + 0.45
	nextAttack = math.max(nextAttack, t + 0.3)
	local dir = aimDirection(c)
	local root = c:FindFirstChild("HumanoidRootPart")
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if root and flat.Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
	ProcAnim.play(c, cfg.Hold == "TwoHands" and "HeavyThrow" or "Throw")
	Net.get("Throw"):FireServer(dir)
end

-- direction du dash : WASD relatif à la caméra (MoveDirection) ; type (avant / arrière / côté) relatif à la caméra
local function dashDirection(c, hum): (string, Vector3)
	local root = c:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	local fwd = cam and Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z) or Vector3.zero
	if fwd.Magnitude < 0.05 then
		fwd = root.CFrame.LookVector
	end
	fwd = Vector3.new(fwd.X, 0, fwd.Z).Unit
	local move = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
	if move.Magnitude < 0.1 then
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		return "F", look.Magnitude > 0.05 and look.Unit or fwd
	end
	move = move.Unit
	local right = fwd:Cross(Vector3.yAxis) -- droite de la caméra
	local f, r = move:Dot(fwd), move:Dot(right)
	if f >= 0.6 then
		return "F", move
	elseif f <= -0.6 then
		return "B", move
	end
	return (r >= 0) and "R" or "L", move
end

function CombatController.setBlock(on: boolean)
	wantBlock = on
	if on then
		CombatController.tryBlock(false)
	elseif blocking then
		blocking = false
		Net.get("Block"):FireServer(false)
	end
end

-- auto = true : block réactivé tout seul (F maintenu à la fin d'un hitstun / d'une récupération) : pas de perfect block
function CombatController.tryBlock(auto: boolean)
	local c = character()
	if not c or blocking or isStunned(c) or guardBroken(c) or os.clock() < busyUntil or inEndlag(c) then
		return
	end
	blocking = true
	blockSentAt = os.clock()
	holdingAttack = false
	ProcAnim.play(c, "BlockStart")
	Net.get("Block"):FireServer(true, auto)
end

function CombatController.dash()
	local c, hum = character()
	if not c then
		return
	end
	local t = os.clock()
	if isStunned(c) then
		-- EVASIVE : se libérer d'un combo (pas pendant un guard break ni au sol)
		if serverNow() >= (c:GetAttribute("CDEvasive") or 0) and not guardBroken(c) and not knockedDown(c)
			and not c:GetAttribute("PendingKO") then
			Net.get("Dash"):FireServer("F")
		end
		return
	end
	if inSafeZone(c) or t < nextDash or t < endlagUntil or inEndlag(c) then
		return
	end
	local root = c:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local D = CombatConfig.Dash
	local kind, dir = dashDirection(c, hum)
	nextDash = t + D.Cooldown
	lastDash, lastDashKind = t, kind
	-- dash cancel au milieu de la chaîne : la chaîne CONTINUE (pas de retour au 1er coup, même règle que le serveur)
	nextAttack = math.min(nextAttack, t)
	busyUntil = math.min(busyUntil, t)
	if blocking then
		wantBlock = false -- le dash annule le block ; il faut rappuyer sur F
		blocking = false
		Net.get("Block"):FireServer(false)
	end
	if kind == "F" then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	else
		-- arrière / côté : on garde l'adversaire (ou la caméra) en face pendant le dash
		faceCamera(c)
		if hum.AutoRotate then
			hum.AutoRotate = false
			task.delay(D.Time + 0.05, function()
				if hum.Parent and not hum.AutoRotate then
					hum.AutoRotate = true
				end
			end)
		end
	end
	local speed = kind == "F" and D.Speed or (kind == "B" and D.BackSpeed or D.SideSpeed)
	local orbitTarget = (kind == "L" or kind == "R") and softTarget(c) or nil
	if kind == "F" then
		-- 0,06 s d'anticipation accroupie (anim « Dash »), puis la poussée ; le serveur est prévenu tout de suite
		-- (fenêtre du DASH STRIKE et recharge inchangées côté serveur)
		task.delay(FORWARD_ANTIC, function()
			if root.Parent and hum.Health > 0 and not isStunned(c) then
				push(c, dir * speed, D.Time)
			end
		end)
	elseif orbitTarget then
		orbitDash(c, orbitTarget, kind == "R" and 1 or -1, speed, D.Time)
	else
		push(c, dir * speed, D.Time)
	end
	CartoonFX.dash(c) -- poussière + son (joue l'anim « Dash »)
	ProcAnim.play(c, DASH_ANIMS[kind]) -- puis l'anim directionnelle
	if kind == "F" then
		CartoonFX.speedLines(0.15)
	end
	Net.get("Dash"):FireServer(kind, dir)
end

function CombatController.ability(i: number)
	local c = character()
	if not c or isStunned(c) or blocking or inSafeZone(c) then
		return
	end
	local target = faceCamera(c)
	local aim = aimDirection(c)
	local root = c:FindFirstChild("HumanoidRootPart")
	if target and root and (target.Position - root.Position).Magnitude > 0.05 then
		aim = (target.Position - root.Position).Unit
	end
	Net.get("Ability"):FireServer(i, aim)
end

-- cible de l'ulti : ennemi le plus proche devant la caméra (portée plus longue que le soft-lock des coups)
local function ultTarget(c)
	local root = c:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not root or not cam then
		return nil
	end
	local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	look = look.Magnitude > 0.05 and look.Unit or root.CFrame.LookVector
	local best, bestScore = nil, math.huge
	for _, other in ipairs(Hitbox.characters()) do
		local r = other ~= c and other:FindFirstChild("HumanoidRootPart")
		if r then
			local to = Vector3.new(r.Position.X - root.Position.X, 0, r.Position.Z - root.Position.Z)
			local d = to.Magnitude
			if d > 0.1 and d <= 28 and math.abs(r.Position.Y - root.Position.Y) < 14 then
				local ang = math.deg(math.acos(math.clamp(to.Unit:Dot(look), -1, 1)))
				if ang <= 80 and d + ang * 0.1 < bestScore then
					best, bestScore = other, d + ang * 0.1
				end
			end
		end
	end
	return best
end

------------------------------------------------------------------------
-- LOCK-ON (molette / R3) : caméra au milieu de soi et de la cible, décalée sur l'épaule droite ; le perso fait face
-- à la cible, la tête la suit. Relâché : cible morte / partie, > LOCK_RANGE studs, ma mort, ulti (plan cinématique
-- UltKit, UltActive / UltAnchor / UltHeld), zone AFK.
------------------------------------------------------------------------
local lock = { target = nil, cf = nil, marker = nil }
local lockRay = RaycastParams.new()
lockRay.FilterType = Enum.RaycastFilterType.Exclude
local UltKitMod
local function ultCameraBusy(c): boolean
	if c and (c:GetAttribute("UltActive") or c:GetAttribute("UltAnchor") or c:GetAttribute("UltHeld")) then
		return true
	end
	if UltKitMod == nil then
		local ok, m = pcall(require, Shared.Modules.UltKit)
		UltKitMod = ok and m or false
	end
	return UltKitMod and type(UltKitMod.cameraBusy) == "function" and UltKitMod.cameraBusy() or false
end

function CombatController.lockTarget(): Model?
	return lock.target
end

local function lockCandidate(c)
	local root = c:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not root or not cam then
		return nil
	end
	local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	look = look.Magnitude > 0.05 and look.Unit or root.CFrame.LookVector
	local best, bestScore = nil, math.huge
	for _, other in ipairs(Hitbox.characters()) do
		local r = other ~= c and other:FindFirstChild("HumanoidRootPart")
		if r then
			local to = Vector3.new(r.Position.X - root.Position.X, 0, r.Position.Z - root.Position.Z)
			local d = to.Magnitude
			if d > 0.1 and d <= LOCK_RANGE then
				local ang = math.deg(math.acos(math.clamp(to.Unit:Dot(look), -1, 1)))
				if ang <= 60 and d * 0.5 + ang < bestScore then
					best, bestScore = other, d * 0.5 + ang
				end
			end
		end
	end
	return best
end

local function setMarker(target)
	if lock.marker then
		lock.marker:Destroy()
		lock.marker = nil
	end
	local head = target and (target:FindFirstChild("Head") or target:FindFirstChild("HumanoidRootPart"))
	if not head then
		return
	end
	local bb = Instance.new("BillboardGui")
	bb.Name = "OB_LockMarker"
	bb.AlwaysOnTop = true
	bb.Size = UDim2.fromOffset(18, 18)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
	bb.Adornee = head
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(10, 10)
	f.Rotation = 45
	f.BackgroundColor3 = Color3.fromRGB(255, 70, 60)
	f.BorderSizePixel = 0
	f.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.Color = UITheme.Colors.Ink
	st.Parent = f
	bb.Parent = player:FindFirstChildOfClass("PlayerGui")
	lock.marker = bb
end

local function releaseLock()
	if not lock.target and not lock.cf then
		return
	end
	lock.target, lock.cf = nil, nil
	setMarker(nil)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local cam = workspace.CurrentCamera
	if cam and cam.CameraType == Enum.CameraType.Scriptable and not ultCameraBusy(nil) then
		cam.CameraType = Enum.CameraType.Custom
		if hum then
			cam.CameraSubject = hum
		end
	end
	local sl = ctxRef.ShiftLockController
	if hum and hum.Health > 0 then
		hum.AutoRotate = not (sl and sl.isEnabled and sl.isEnabled())
	end
end
CombatController.releaseLock = releaseLock

function CombatController.toggleLock()
	if lock.target then
		releaseLock()
		return
	end
	local c = character()
	if not c or inSafeZone(c) or ultCameraBusy(c) then
		return
	end
	local target = lockCandidate(c)
	local cam = workspace.CurrentCamera
	if not target or not cam then
		return
	end
	lock.target = target
	lock.cf = cam.CFrame
	cam.CameraType = Enum.CameraType.Scriptable
	setMarker(target)
	CartoonFX.sound("Whoosh", nil, 0.25, 1.4)
end

local function lockStep(dt)
	local target = lock.target
	if not target then
		return
	end
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	local tHum = target:FindFirstChildOfClass("Humanoid")
	local tRoot = target:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not (hum and root and tHum and tRoot and cam) or hum.Health <= 0 or tHum.Health <= 0 or not target.Parent
		or (tRoot.Position - root.Position).Magnitude > LOCK_RANGE or inSafeZone(c) or ultCameraBusy(c) then
		releaseLock()
		return
	end
	local myP, tP = root.Position, tRoot.Position
	local away = Vector3.new(myP.X - tP.X, 0, myP.Z - tP.Z)
	local sep = away.Magnitude
	away = sep > 0.1 and away / sep or -Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
	local fwd = -away
	local right = fwd:Cross(Vector3.yAxis)
	local dist = math.clamp(10 + sep * 0.35, 10, 22)
	local pivot = myP + Vector3.new(0, 2, 0)
	local wanted = pivot + away * dist + Vector3.new(0, 2 + sep * 0.08, 0) + right * 2.2
	-- anti-traversée des murs : la caméra s'arrête devant l'obstacle
	lockRay.FilterDescendantsInstances = { c, target }
	local hit = workspace:Raycast(pivot, wanted - pivot, lockRay)
	if hit then
		wanted = hit.Position + (pivot - wanted).Unit * 0.6
	end
	local focus = myP:Lerp(tP, 0.5) + Vector3.new(0, 1.5, 0)
	local goal = CFrame.lookAt(wanted, focus)
	lock.cf = (lock.cf or cam.CFrame):Lerp(goal, 1 - math.exp(-dt * 10))
	if cam.CameraType ~= Enum.CameraType.Scriptable then
		cam.CameraType = Enum.CameraType.Scriptable
	end
	cam.CFrame = lock.cf
	-- le perso fait face à la cible (sauf ancré / renversé / shift lock qui s'en charge déjà)
	local sl = ctxRef.ShiftLockController
	local shift = sl and sl.isEnabled and sl.isEnabled()
	if not shift and not root.Anchored and not hum.PlatformStand and sep > 0.5 then
		hum.AutoRotate = false
		root.CFrame = CFrame.lookAt(myP, myP + fwd)
	end
	ProcAnim.setLookTarget(c, tRoot, 0.3)
end

-- G (ou le bouton ULT / OVERTIME sur mobile) : transformation, puis pendant l'Overtime l'ULTIME (une fois, quand UltReady)
function CombatController.transform()
	local c = character()
	if not c then
		return
	end
	if c:GetAttribute("Transformed") then
		if c:GetAttribute("UltReady") then
			Net.get("Ultimate"):FireServer(ultTarget(c))
		end
		return
	end
	if (c:GetAttribute("Overtime") or 0) >= CombatConfig.Overtime.Max then
		-- même règle que le serveur : pas pendant un stun / guard break / mise au sol / K.O.
		if isStunned(c) or guardBroken(c) or knockedDown(c) or c:GetAttribute("PendingKO") or c:GetAttribute("UltHeld") then
			return
		end
		Net.get("Transform"):FireServer()
	end
end

-- l'ultime est-il prêt ? (HUD / bouton mobile)
function CombatController.ultReady(): boolean
	local c = player.Character
	return c ~= nil and c:GetAttribute("Transformed") == true and c:GetAttribute("UltReady") == true
end

------------------------------------------------------------------------
-- Jauge de garde (sous le viseur) + rappel EVASIVE pendant un hitstun
------------------------------------------------------------------------
local function buildGuardMeter()
	local gui = Instance.new("ScreenGui")
	gui.Name = "GuardMeter"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 3
	gui.Parent = player:WaitForChild("PlayerGui")
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0.5, 46)
	holder.Size = UDim2.fromOffset(150, 40)
	holder.BackgroundTransparency = 1
	holder.Visible = false
	holder.Parent = gui
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.Size = UDim2.new(1, 0, 0, 10)
	bar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	bar.BackgroundTransparency = 0.2
	bar.BorderSizePixel = 0
	bar.Parent = holder
	local bc = Instance.new("UICorner")
	bc.CornerRadius = UDim.new(0, 4)
	bc.Parent = bar
	local bs = Instance.new("UIStroke")
	bs.Thickness = 2
	bs.Color = Color3.new(0, 0, 0)
	bs.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 4)
	fc.Parent = fill
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 13)
	label.Size = UDim2.new(1.6, 0, 0, 22)
	label.BackgroundTransparency = 1
	label.FontFace = UITheme.Display
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = ""
	label.Parent = holder
	local ls = Instance.new("UIStroke")
	ls.Thickness = 2
	ls.Parent = label

	RunService.RenderStepped:Connect(function()
		local c = player.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not c or not hum or hum.Health <= 0 then
			holder.Visible = false
			return
		end
		local maxG = c:GetAttribute("MaxGuard") or CombatConfig.Block.MaxGuard
		local g = c:GetAttribute("Guard") or maxG
		local broken = guardBroken(c)
		local stunned = isStunned(c)
		local evasiveReady = stunned and not broken and not knockedDown(c) and not c:GetAttribute("PendingKO")
			and serverNow() >= (c:GetAttribute("CDEvasive") or 0)
		local showBar = c:GetAttribute("Blocking") == true or g < maxG - 0.5 or broken
		holder.Visible = showBar or evasiveReady
		bar.Visible = showBar
		local k = math.clamp(g / math.max(maxG, 1), 0, 1)
		fill.Size = UDim2.fromScale(broken and 0 or k, 1)
		fill.BackgroundColor3 = (k < 0.3) and Color3.fromRGB(255, 90, 70) or Color3.fromRGB(120, 200, 255)
		if broken then
			label.Text = "GUARD BROKEN!"
			label.TextColor3 = Color3.fromRGB(255, 90, 70)
		elseif evasiveReady then
			label.Text = (UserInputService.TouchEnabled and not UserInputService.MouseEnabled) and "DASH = EVASIVE!" or "Q = EVASIVE!"
			label.TextColor3 = Color3.fromRGB(255, 220, 80)
		else
			label.Text = ""
		end
	end)
end

function CombatController.init(ctx)
	ctxRef = type(ctx) == "table" and ctx or {}
	local function bind(name, fn, ...)
		ContextActionService:BindAction(name, function(_, state, input)
			if state == Enum.UserInputState.Begin then
				fn(true, input)
			elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
				fn(false, input)
			end
			return Enum.ContextActionResult.Sink
		end, false, ...)
	end
	ContextActionService:BindAction("OB_Attack", function(_, state, input)
		if state == Enum.UserInputState.Begin then
			holdingAttack = true
			holdingWithMouse = input and input.UserInputType == Enum.UserInputType.MouseButton1
			CombatController.attack()
		elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
			holdingAttack = false
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.ButtonR2)
	bind("OB_Pickup", function(d) if d then CombatController.pickup() end end, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	bind("OB_Throw", function(d) if d then CombatController.throw() end end, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	bind("OB_Dash", function(d) if d then CombatController.dash() end end, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	bind("OB_Block", function(d) CombatController.setBlock(d) end, Enum.KeyCode.F, Enum.KeyCode.ButtonL2)
	bind("OB_Transform", function(d) if d then CombatController.transform() end end, Enum.KeyCode.G, Enum.KeyCode.ButtonL1)
	bind("OB_Ability1", function(d) if d then CombatController.ability(1) end end, Enum.KeyCode.One)
	bind("OB_Ability2", function(d) if d then CombatController.ability(2) end end, Enum.KeyCode.Two)
	bind("OB_Ability3", function(d) if d then CombatController.ability(3) end end, Enum.KeyCode.Three)
	bind("OB_LockOn", function(d) if d then CombatController.toggleLock() end end, Enum.UserInputType.MouseButton3, Enum.KeyCode.ButtonR3)
	RunService:BindToRenderStep("OB_LockOn", Enum.RenderPriority.Camera.Value - 2, lockStep)
	-- surveillance des changements de block de tous les combattants (anti coup fantôme)
	task.spawn(function()
		while true do
			for _, ch in ipairs(Hitbox.characters()) do
				watchVictim(ch)
			end
			task.wait(0.5)
		end
	end)

	-- verrou de saut : fin de chaîne au sol et armé de l'uppercut (Espace maintenu ne doit pas faire sauter)
	local jumpLocked, jumpLockHum = false, nil
	local function setJumpLock(hum, on)
		if jumpLocked == on and jumpLockHum == hum then
			return
		end
		if jumpLockHum and jumpLockHum ~= hum and jumpLockHum.Parent then
			jumpLockHum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
		jumpLocked, jumpLockHum = on, hum
		if hum then
			hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, not on)
		end
	end
	CombatController.unlockJump = function()
		riseLockUntil = 0
		local c = player.Character
		setJumpLock(c and c:FindFirstChildOfClass("Humanoid"), false)
	end

	RunService.Heartbeat:Connect(function()
		local c = player.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			setJumpLock(nil, false)
			return
		end
		local t = os.clock()
		setJumpLock(hum, (uppercutReady() or t < riseLockUntil) and hum.FloorMaterial ~= Enum.Material.Air)
		-- clic maintenu = enchaîne
		if holdingAttack then
			if holdingWithMouse and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				holdingAttack = false
			else
				CombatController.attack()
			end
		end
		-- block : resynchronisation avec le serveur (hitstun / guard break / ulti l'ont coupé) puis réactivation si F est maintenu
		if blocking and (isStunned(c) or guardBroken(c)
			or (c:GetAttribute("Blocking") ~= true and t - blockSentAt > 0.6)) then
			blocking = false
		end
		if wantBlock and not blocking then
			CombatController.tryBlock(true)
		end
	end)

	-- retours du serveur qui concernent notre personnage (FXController ne joue pas nos propres anims)
	Net.get("FX").OnClientEvent:Connect(function(data)
		local c = player.Character
		if type(data) ~= "table" or not c then
			return
		end
		local kind = data.k or data.type
		local blocker = data.character or data.v
		if kind == "Hit" and data.a == c and data.seq then
			-- coup prédit confirmé par le serveur : mot + chiffre maintenant
			local set = CombatController.predicted[data.seq]
			if type(set) == "table" and set[data.v] then
				confirmHit(data, set[data.v] == "lite")
			end
		elseif kind == "BlockHit" and data.a == c then
			-- avantage au bloqueur (même règle que le serveur) : notre prochain coup part après le délai ; le clic est
			-- gardé en mémoire tampon et envoyé UNE fois, au lieu d'être joué en local puis tenu / rejoué par le serveur
			local adv = CombatConfig.Block.BlockAdvantage or 0
			if adv > 0 then
				nextAttack = math.max(nextAttack, os.clock()) + adv
			end
		elseif (kind == "PerfectBlock" or kind == "Parry") and blocker == c then
			ProcAnim.play(c, "PerfectBlock")
		elseif kind == "GuardBreak" and blocker == c then
			blocking = false
			ProcAnim.play(c, "GuardBroken")
			camShake(0.4)
		elseif (kind == "PerfectBlock" or kind == "Parry") and data.a == c then
			-- notre coup a été parfaitement bloqué : la chaîne est perdue, on recule sonné
			combo, airChainUntil = 0, 0
			holdingAttack = false
			ProcAnim.play(c, "HitHeavy")
		end
	end)

	-- après un uppercut réussi : saut automatique derrière la victime
	local function autoFollow(c)
		local hum = c:FindFirstChildOfClass("Humanoid")
		local root = c:FindFirstChild("HumanoidRootPart")
		if not hum or not root then
			return
		end
		local at = os.clock()
		airCombo, airChainUntil = 0, at + U.AirWindow
		nextAttack = math.min(nextAttack, at + 0.2)
		busyUntil = math.min(busyUntil, at + 0.2)
		endlagUntil = 0
		-- on attend la fin du hit-stop local (le personnage est ancré pendant le gel)
		while root.Parent and root.Anchored and os.clock() - at < 0.6 do
			task.wait()
		end
		if not root.Parent or hum.Health <= 0 or os.clock() > airChainUntil then
			return
		end
		CombatController.unlockJump()
		local target = softTarget(c)
		local fwd = root.CFrame.LookVector
		if target then
			local to = Vector3.new(target.Position.X - root.Position.X, 0, target.Position.Z - root.Position.Z)
			if to.Magnitude > 0.1 then
				fwd = to.Unit
			end
		end
		local att = root:FindFirstChild("PushAtt") or Instance.new("Attachment")
		att.Name = "PushAtt"
		att.Parent = root
		local lift = Instance.new("LinearVelocity")
		lift.Name = "LocalLift"
		lift.Attachment0 = att
		lift.MaxForce = 1e6
		lift.VectorVelocity = Vector3.new(fwd.X * U.FollowForward, U.FollowJump, fwd.Z * U.FollowForward)
		lift.Parent = root
		Debris:AddItem(lift, 0.15)
		CartoonFX.puff(root.Position - Vector3.new(0, 2.5, 0), 1)
		CartoonFX.sound("Boing", root.Position, 0.8)
		CartoonFX.speedLines(0.25)
	end

	-- EVASIVE confirmé : petit bond en arrière
	local function evasiveHop(c)
		local root = c:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		releaseAir(c)
		ProcAnim.play(c, "Evasive")
		camShake(0.5)
		task.defer(function()
			if root.Parent and not root.Anchored then
				local back = -root.CFrame.LookVector
				root.AssemblyLinearVelocity = Vector3.new(back.X * CombatConfig.Evasive.Hop, 18, back.Z * CombatConfig.Evasive.Hop)
			end
		end)
	end

	local function hookCharacter(c)
		releaseLock()
		combo, lastM1, airCombo, airChainUntil = 0, -10, 0, 0
		nextAttack, busyUntil, endlagUntil, riseLockUntil = 0, 0, 0, 0
		nextDash, nextDashStrike, lastDash, lastDashKind = 0, 0, -10, "F" -- l'état serveur repart à zéro au respawn
		holdingAttack, wantBlock, blocking = false, false, false
		c:GetAttributeChangedSignal("AutoFollow"):Connect(function()
			task.spawn(autoFollow, c)
		end)
		-- le serveur confirme le slam : on retombe
		c:GetAttributeChangedSignal("AirRelease"):Connect(function()
			releaseAir(c)
		end)
		c:GetAttributeChangedSignal("EvasiveAt"):Connect(function()
			evasiveHop(c)
		end)
	end
	player.CharacterAdded:Connect(hookCharacter)
	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end

	buildGuardMeter()
end

return CombatController
