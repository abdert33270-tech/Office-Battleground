--[[
	CombatController — entrées de combat du joueur local.
	PC : clic gauche (M1 / utiliser l'objet ; maintien = enchaîne), 2 M1 + Espace = Rising Duo, 3 M1 + Espace = Uppercut, 3 M1 + Espace + clic en l'air = Ground Pin, M1 en l'air = jongle,
	     Ctrl + clic = Dropkick (Shift = shift lock), Q = dash (et Combo Breaker quand on est enfermé dans un combo), F = block (maintenu)
	     / parade (au bon moment), E = ramasser/lâcher, R = lancer, 1/2/3 = attaques, G = transformation.
	Manette : R2, X, Y, B (dash), L2 (block), L1 (transformation).
	Mobile : AUCUN bouton ici — le HUD crée les boutons et appelle l'API publique :
	         attack(), pickup(), throw(), dash(), setBlock(on), ability(i), transform().
	Réactivité : animation, pas en avant, whoosh et effets de coup (prédiction locale) sont joués tout de suite.
	Le serveur reste seul juge des dégâts.
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
local Net = require(Shared.Modules.Net)
local Hitbox = require(Shared.Modules.Hitbox)
local ProcAnim = require(Shared.Modules.ProcAnim)
local CartoonFX = require(Shared.Modules.CartoonFX)

local CombatController = {}
CombatController.Priority = 10

local player = Players.LocalPlayer
local M1 = CombatConfig.M1
local seq = 0
local combo, lastM1, nextAttack, nextThrow, nextDash, nextDropkick, lastDash = 0, 0, 0, 0, 0, 0, -10
local airCombo, lastAir = 0, 0
local holdingAttack, holdingWithMouse, blocking = false, false, false

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

local pinWindowUntil, buffered = 0, false
local riseLockUntil = 0 -- après un Rising Duo : pas de saut normal (Espace maintenu) pendant la montée
local liftPendingUntil = 0 -- montée du Rising Duo en cours : aucune suspension ne doit la freiner
local duoAirUntil = 0 -- Rising Duo confirmé : les M1 comptent comme aériens même avant que la montée décolle

-- ennemi le plus proche dans le cône devant la caméra (verrouillage doux)
local function softTarget(c)
	local root = c:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not root or not cam then
		return nil
	end
	local L = CombatConfig.SoftLock
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
				local held = d <= 7 and r:FindFirstChild("ComboTether") and (os.clock() - lastM1 < 1.2 or os.clock() - lastAir < 1.2)
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
	local target = softTarget(c)
	local root = c:FindFirstChild("HumanoidRootPart")
	if target and root then
		local to = Vector3.new(target.Position.X, root.Position.Y, target.Position.Z)
		root.CFrame = CFrame.lookAt(root.Position, to)
		return target
	end
	local root = c:FindFirstChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	if not root or not cam then
		return
	end
	local flat = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
	if flat.Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
end

-- petite poussée physique locale (pas en avant, dash, dropkick)
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

-- suspension locale en l'air (jongles)
local stallLocal
function CombatController.stallLocal(c, d)
	return stallLocal(c, d)
end
function stallLocal(c, duration)
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

-- fin de jongle (slam) : on retire toutes les suspensions et on retombe tout de suite (jamais coincé en l'air)
local airReleasedAt = 0
local function releaseAir(c)
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	airReleasedAt = os.clock()
	duoAirUntil = 0
	riseLockUntil = os.clock() + 0.5 -- Espace encore maintenu : on ne rebondit pas tout de suite sur la victime plaquée
	for _, n in ipairs({ "LocalStall", "LocalLift", "AirStall", "Lift" }) do
		for _, ch in ipairs(root:GetChildren()) do
			if ch.Name == n then
				ch:Destroy()
			end
		end
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	if hum and hum.FloorMaterial == Enum.Material.Air and not root.Anchored then
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X * 0.3, math.min(v.Y, -28), v.Z * 0.3)
	end
end
CombatController.releaseAir = releaseAir

local function predictHits(c, spec, mySeq, extra)
	task.delay(spec.Windup or M1.Windup, function()
		if not character() then
			return
		end
		local cf = Hitbox.frontCFrame(c, spec.HitboxOffset)
		local root = c:FindFirstChild("HumanoidRootPart")
		if not cf or not root then
			return
		end
		for _, victim in ipairs(Hitbox.box(cf, spec.HitboxSize, c, 3)) do
			local vRoot = victim:FindFirstChild("HumanoidRootPart")
			local hum = victim:FindFirstChildOfClass("Humanoid")
			if vRoot and hum and not victim:FindFirstChildOfClass("ForceField") and not victim:GetAttribute("Blocking") then
				CombatController.predicted[mySeq] = CombatController.predicted[mySeq] or {}
				CombatController.predicted[mySeq][victim] = true
				CartoonFX.hit({
					a = c, v = victim, p = vRoot.Position:Lerp(root.Position, 0.3) + Vector3.new(0, 0.6, 0),
					c = spec.Category, pw = spec.Power, d = spec.Damage, w = extra and extra.Words, m = extra and extra.Material,
					ko = hum.Health - spec.Damage <= 0, r = extra and extra.Reaction,
				})
			end
		end
		task.delay(2, function()
			CombatController.predicted[mySeq] = nil
		end)
	end)
end

------------------------------------------------------------------------
-- API publique
------------------------------------------------------------------------
function CombatController.attack()
	local c, hum = character()
	if not c or isStunned(c) or blocking then
		return
	end
	local t = os.clock()
	if t < nextAttack then
		if not buffered and nextAttack - t <= CombatConfig.InputBuffer then
			buffered = true
			task.delay(nextAttack - t + 0.01, function()
				buffered = false
				CombatController.attack()
			end)
		end
		return
	end
	-- 3 M1 + saut + M1 : GROUND PIN (le clic en l'air juste après le saut)
	if os.clock() < pinWindowUntil and hum.FloorMaterial == Enum.Material.Air and (c:GetAttribute("ComboStep") or 0) == 3 then
		pinWindowUntil = 0
		seq += 1
		nextAttack = t + 0.7
		ProcAnim.play(c, "Downslam")
		CombatController.stallLocal(c, 0.15)
		task.delay(0.16, releaseAir, c)
		local root0 = c:FindFirstChild("HumanoidRootPart")
		CartoonFX.sound("Whoosh", root0.Position, 0.7)
		Net.get("Attack"):FireServer(seq, { pin = true })
		return
	end
	seq += 1
	local target = faceCamera(c)
	local root = c:FindFirstChild("HumanoidRootPart")
	local look = root.CFrame.LookVector
	local gap = target and (Vector3.new(target.Position.X, 0, target.Position.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude or 0
	local extraLunge = (gap > 4.5) and math.min((gap - 3.5) * 9, 40) or 0 -- on recolle à la cible si elle s'éloigne
	if target and target:FindFirstChild("ComboTether") then
		extraLunge = 0 -- elle est tenue en laisse : c'est elle qui nous suit
	end
	local heldId = c:GetAttribute("HeldItem")
	local itemCfg = heldId and ItemsConfig[heldId]
	local airborne = hum.FloorMaterial == Enum.Material.Air or os.clock() < duoAirUntil
	local mods = {
		up = UserInputService:IsKeyDown(Enum.KeyCode.Space) or hum.Jump,
		shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl), -- Ctrl + clic = Dropkick
	}
	if itemCfg then
		local use = itemCfg.Use
		nextAttack = t + use.Cooldown
		combo = 0
		ProcAnim.play(c, use.Anim or "Jab")
		if use.Lunge then
			push(c, look * use.Lunge, 0.1)
		end
		if use.Damage then
			predictHits(c, use, seq, { Words = use.Words, Material = itemCfg.Material, Reaction = use.Category == "Heavy" and "Heavy" or "Light" })
		end
	elseif (mods.shift or t - lastDash < CombatConfig.Dash.AttackWindow) and not airborne and t >= nextDropkick then
		local D = CombatConfig.Dropkick
		nextDropkick = t + D.Cooldown
		nextAttack = t + 0.55
		combo = 0
		ProcAnim.play(c, D.Anim)
		push(c, look * D.LungeSpeed, D.LungeTime)
		predictHits(c, { Windup = D.Windup, HitboxOffset = D.HitboxOffset, HitboxSize = D.HitboxSize, Damage = D.Damage,
			Category = "Heavy", Power = D.Power }, seq, { Words = D.Words, Reaction = "Heavy" })
		mods.shift = true
	elseif airborne then
		if t - lastAir > 1.0 then
			airCombo = 0
		end
		airCombo += 1
		lastAir = t
		if airCombo >= (c:GetAttribute("AirMax") or 3) then
			local S = CombatConfig.Downslam
			airCombo = 0
			nextAttack = t + 0.6
			ProcAnim.play(c, S.Anim)
			task.delay(0.14, releaseAir, c) -- le coup qui écrase : l'attaquant retombe juste après
			predictHits(c, { Windup = 0.1, HitboxOffset = 3, HitboxSize = Vector3.new(6, 8, 6.5), Damage = S.Damage,
				Category = "Heavy", Power = S.Power }, seq, { Words = S.Words, Reaction = "Slam" })
		else
			local A = CombatConfig.Air
			nextAttack = t + 0.27
			ProcAnim.play(c, A.Anim[((airCombo - 1) % #A.Anim) + 1])
			if os.clock() > liftPendingUntil and not root:FindFirstChild("LocalLift") then
				stallLocal(c, 0.4) -- on reste en l'air pendant la jongle (jamais pendant la montée du Rising Duo)
			end
			predictHits(c, { Windup = 0.05, HitboxOffset = 3, HitboxSize = Vector3.new(7, 11, 7.5), Damage = A.Damage[((airCombo - 1) % #A.Damage) + 1],
				Category = "Light", Power = 0.4 }, seq)
		end
	else
		if t - lastM1 > M1.ComboReset then
			combo = 0
		end
		combo = combo % 4 + 1
		local i = combo
		lastM1 = t
		nextAttack = t + M1.Cooldown[i]
		if i == 4 then
			combo = 0
		end
		push(c, look * (M1.Lunge[i] + extraLunge), 0.1)
		ProcAnim.play(c, M1.Anim[i])
		predictHits(c, { Windup = M1.Windup, HitboxOffset = M1.HitboxOffset, HitboxSize = M1.HitboxSize, Damage = M1.Damage[i],
			Category = M1.Category[i], Power = M1.Power[i] }, seq, { Reaction = i == 4 and "Heavy" or "Light", Words = i == 4 and { "FINISHER!", "WHAM!", "KAPOW!" } or nil })
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
	if not c or isStunned(c) then
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
	if flat.Magnitude > 0.1 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
	ProcAnim.play(c, cfg.Hold == "TwoHands" and "HeavyThrow" or "Throw")
	Net.get("Throw"):FireServer(dir)
end

function CombatController.dash()
	local c, hum = character()
	if not c then
		return
	end
	local t = os.clock()
	if isStunned(c) then
		if c:GetAttribute("CanBreak") then
			Net.get("Dash"):FireServer()
		end
		return
	end
	if t < nextDash then
		return
	end
	local D = CombatConfig.Dash
	nextDash = t + D.Cooldown
	lastDash = t
	nextAttack = math.min(nextAttack, t)
	if blocking then
		CombatController.setBlock(false)
	end
	local root = c:FindFirstChild("HumanoidRootPart")
	local dir = hum.MoveDirection.Magnitude > 0.1 and hum.MoveDirection or root.CFrame.LookVector
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	push(c, dir * D.Speed, D.Time)
	CartoonFX.dash(c)
	CartoonFX.fovKick(-4)
	Net.get("Dash"):FireServer()
end

function CombatController.setBlock(on: boolean)
	local c = character()
	if not c or (on and isStunned(c)) or on == blocking then
		return
	end
	blocking = on
	if on then
		holdingAttack = false
		ProcAnim.play(c, "BlockStart")
	end
	Net.get("Block"):FireServer(on)
end

function CombatController.ability(i: number)
	local c = character()
	if not c or isStunned(c) or blocking then
		return
	end
	local target = faceCamera(c)
	local aim = aimDirection(c)
	if target then
		local root = c:FindFirstChild("HumanoidRootPart")
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
		Net.get("Transform"):FireServer()
	end
end

-- l'ultime est-il prêt ? (HUD / bouton mobile)
function CombatController.ultReady(): boolean
	local c = player.Character
	return c ~= nil and c:GetAttribute("Transformed") == true and c:GetAttribute("UltReady") == true
end

function CombatController.init()
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

	RunService.Heartbeat:Connect(function()
		if holdingAttack then
			if holdingWithMouse and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
				holdingAttack = false
				return
			end
			CombatController.attack()
		end
	end)

	-- LANCEURS : appuyer sur Espace (ou le maintenir) juste après 2 M1 réussis (Rising Duo) ou 3 M1 réussis (Uppercut)
	local stepChangedAt = 0
	local launchTriedAt = -1 -- un seul essai de lanceur par palier de combo (Espace maintenu)
	local function tryLaunch(c)
		local step = c:GetAttribute("ComboStep") or 0
		if step == 3 and os.clock() - stepChangedAt <= CombatConfig.Combos.Window and not isStunned(c) and not blocking and os.clock() > pinWindowUntil then
			-- on laisse 0,22 s pour cliquer en l'air (GROUND PIN) ; sinon c'est l'UPPERCUT
			pinWindowUntil = os.clock() + 0.22
			task.delay(0.23, function()
				if pinWindowUntil > 0 and (c:GetAttribute("ComboStep") or 0) == 3 then
					pinWindowUntil = 0
					seq += 1
					ProcAnim.play(c, "Uppercut")
					CartoonFX.sound("Uppercut", c.HumanoidRootPart.Position, 1)
					airCombo, lastAir = 0, os.clock()
					nextAttack = os.clock() + 0.3
					Net.get("Attack"):FireServer(seq, { launch = true })
				end
			end)
			return true
		end
		if step == 2 and os.clock() - stepChangedAt <= CombatConfig.Combos.Window and not isStunned(c) and not blocking then
			riseLockUntil = os.clock() + 0.6
			seq += 1
			ProcAnim.play(c, step == 2 and "RisingDuo" or "Uppercut")
			CartoonFX.sound("Uppercut", c.HumanoidRootPart.Position, 1)
			airCombo, lastAir = 0, os.clock()
			nextAttack = os.clock() + 0.3
			Net.get("Attack"):FireServer(seq, { launch = true })
			return true
		end
		return false
	end
	CombatController.tryLaunch = function()
		local c = character()
		return c and tryLaunch(c)
	end
	UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.ButtonA then
			local c = character()
			if c then
				launchTriedAt = stepChangedAt
				tryLaunch(c)
			end
		end
	end)

	-- ESPACE MAINTENU : compte aussi pour le lanceur (2 M1 = Rising Duo, 3 M1 = Uppercut / Ground Pin).
	-- Pendant la chaîne au sol (1 ou 2 M1 réussis), le saut normal est bloqué : Espace maintenu ne fait pas sauter
	-- (sinon le M1 suivant deviendrait un coup aérien) ; à 3 M1 le saut revient (il sert au Ground Pin / à suivre l'Uppercut).
	local function jumpHeld(hum)
		return UserInputService:IsKeyDown(Enum.KeyCode.Space)
			or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
			or (hum ~= nil and hum.Jump == true) -- bouton saut mobile (et toute entrée de saut du ControlModule)
	end
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
	RunService.Heartbeat:Connect(function()
		local c = player.Character
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			setJumpLock(nil, false)
			return
		end
		local step = c:GetAttribute("ComboStep") or 0
		local inWindow = os.clock() - stepChangedAt <= CombatConfig.Combos.Window
		setJumpLock(hum, (((step == 1 or step == 2) and inWindow) or os.clock() < riseLockUntil) and hum.FloorMaterial ~= Enum.Material.Air)
		if (step == 2 or step == 3) and inWindow and launchTriedAt ~= stepChangedAt and jumpHeld(hum) and character() then
			launchTriedAt = stepChangedAt
			tryLaunch(c)
		end
	end)

	-- après un Uppercut réussi : sauter = super saut pour suivre la victime en l'air
	local function boostFollow(c)
		local root = c:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		c:SetAttribute("FollowUntil", 0)
		root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, CombatConfig.Uppercut.FollowJump, root.AssemblyLinearVelocity.Z)
			+ root.CFrame.LookVector * 10
		CartoonFX.puff(root.Position - Vector3.new(0, 2.5, 0), 1)
		CartoonFX.sound("Boing", root.Position, 0.8)
		CartoonFX.speedLines(0.25)
	end
	local function hookCharacter(c)
		c:GetAttributeChangedSignal("ComboStep"):Connect(function()
			stepChangedAt = os.clock()
		end)
		-- Rising Duo : le serveur demande à notre client de nous faire monter puis de nous suspendre en haut
		c:GetAttributeChangedSignal("LiftAt"):Connect(function()
			local root = c:FindFirstChild("HumanoidRootPart")
			if not root then
				return
			end
			local up, stall = c:GetAttribute("LiftUp") or 50, c:GetAttribute("LiftStall") or 0.8
			local liftStart = os.clock()
			duoAirUntil = liftStart + stall + 0.75
			liftPendingUntil = liftStart + 0.8
			-- on attend la fin du hit-stop (le personnage est ancré pendant le gel), puis on monte
			task.wait(0.2)
			while root.Anchored and root.Parent do
				task.wait()
			end
			if not root.Parent or airReleasedAt > liftStart then
				return -- déjà écrasé (slam très rapide) : on ne monte plus
			end
			liftPendingUntil = os.clock() + 0.4
			local st = root:FindFirstChild("LocalStall")
			if st then
				st:Destroy()
			end
			local att = root:FindFirstChild("PushAtt") or Instance.new("Attachment")
			att.Name = "PushAtt"
			att.Parent = root
			local lift = Instance.new("LinearVelocity")
			lift.Name = "LocalLift"
			lift.Attachment0 = att
			lift.MaxForce = 1e6
			lift.VectorVelocity = Vector3.new(0, up, 0) + root.CFrame.LookVector * 3
			lift.Parent = root
			Debris:AddItem(lift, 0.2)
			CartoonFX.puff(root.Position - Vector3.new(0, 2.5, 0), 1.2)
			CartoonFX.speedLines(0.3)
			task.delay(0.42, function()
				if not root.Parent or airReleasedAt > liftStart then
					return -- déjà écrasé : pas de suspension
				end
				local att = root:FindFirstChild("PushAtt") or Instance.new("Attachment")
				att.Name = "PushAtt"
				att.Parent = root
				local lv = Instance.new("LinearVelocity")
				lv.Name = "LocalStall"
				lv.Attachment0 = att
				lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
				lv.LineDirection = Vector3.yAxis
				lv.LineVelocity = 1
				lv.MaxForce = 1e6
				lv.Parent = root
				Debris:AddItem(lv, stall)
			end)
		end)
		-- le serveur confirme le slam : on retombe
		c:GetAttributeChangedSignal("AirRelease"):Connect(function()
			releaseAir(c)
		end)
		c:GetAttributeChangedSignal("FollowUntil"):Connect(function()
			local hum = c:FindFirstChildOfClass("Humanoid")
			if serverNow() < (c:GetAttribute("FollowUntil") or 0) and hum and hum.FloorMaterial == Enum.Material.Air then
				task.defer(boostFollow, c) -- déjà en l'air (on a sauté en appuyant sur Espace) : on suit tout de suite
			end
		end)
		holdingAttack, combo, airCombo, blocking = false, 0, 0, false
		local hum = c:WaitForChild("Humanoid", 10)
		if not hum then
			return
		end
		hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				if serverNow() < (c:GetAttribute("FollowUntil") or 0) then
					task.defer(boostFollow, c)
				elseif UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
					tryLaunch(c) -- mobile : le bouton saut sert aussi de lanceur
				end
			end
		end)
	end
	player.CharacterAdded:Connect(hookCharacter)
	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end
end

return CombatController
