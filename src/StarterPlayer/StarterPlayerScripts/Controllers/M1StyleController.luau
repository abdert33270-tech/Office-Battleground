--[[
	M1StyleController — effets des M1 par arme (traînées, arc de taillade, whoosh, impact). Voir docs/M1-Styles.md.
	Données : Config/M1Styles ; résolution : Modules/M1Style (objet tenu > arme fétiche > Fists).

	Déclenchement : ProcAnim.onPlay. Toute animation listée dans M1Styles.Moves jouée sur un personnage de joueur
	(ou un mannequin) lance la traînée pendant la fenêtre du coup (Windup de Config/Combat ou de Config/Items) :
	- joueur local : CombatController joue l'anim au clic -> effets immédiats, impact prédit au Windup sur les cibles
	  de la hitbox (mêmes filtres que la prédiction de CombatController : block, renversé, bulle, zone sûre...) ;
	- autres joueurs : l'anim arrive par la remote « Anim » (FXController -> ProcAnim.play) ; l'impact stylé est joué
	  à la réception du « Hit » serveur (remote FX) de cet attaquant pendant la fenêtre du coup.
	Traînée : Attachments sur l'arme (dossier « Signature » visible ou objet tenu via sa HoldWeld), sinon sur le bras
	/ la jambe qui frappe. Limite de traînées simultanées selon la qualité ; tout est nettoyé par Debris.
	Réglages : Quality (Low/Medium/High : quantités, arcs, durée des traînées), ReducedFlashes (ni néon, ni lumière).
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatConfig = require(Shared.Config.Combat)
local ItemsConfig = require(Shared.Config.Items)
local Net = require(Shared.Modules.Net)
local Hitbox = require(Shared.Modules.Hitbox)
local ProcAnim = require(Shared.Modules.ProcAnim)
local CartoonFX = require(Shared.Modules.CartoonFX)
local M1Style = require(Shared.Modules.M1Style)

local M1StyleController = {}
M1StyleController.Priority = 60

local player = Players.LocalPlayer
local M1 = CombatConfig.M1
local rng = Random.new()

local MAX_TRAILS = { Low = 4, Medium = 8, High = 14 }
local REMOTE_RANGE = 150 -- au-delà (distance caméra), pas d'effets pour les coups des autres
local HIT_GRACE = 0.5    -- fenêtre (après le Windup) pendant laquelle un « Hit » serveur reçoit l'impact stylé

local swings = setmetatable({}, { __mode = "k" })   -- [attaquant] = { style, mirrored, heavy, hitUntil }
local tipCache = setmetatable({}, { __mode = "k" }) -- [dossier Signature | Handle] = { part, near, tip }
local activeTrails = {}

------------------------------------------------------------------------
-- utilitaires
------------------------------------------------------------------------
local function reduced(): boolean
	return CartoonFX.reducedFlashes() == true
end

local function qualityName(): string
	local q = CartoonFX.setting("Quality")
	return (q == "Low" or q == "Medium") and q or "High"
end

local function fxFolder()
	return workspace:FindFirstChild("FX") or workspace
end

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function fxPart(size: Vector3, cf: CFrame, color: Color3, glow: boolean?, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = (glow and not reduced()) and Enum.Material.Neon or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Parent = fxFolder()
	return p
end

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function isFighter(c: Model): boolean
	if not c or not c.Parent or not c:FindFirstChild("HumanoidRootPart") then
		return false
	end
	return Players:GetPlayerFromCharacter(c) ~= nil or c:GetAttribute("IsDummy") == true
end

local function nearCamera(pos: Vector3): boolean
	local cam = workspace.CurrentCamera
	return cam == nil or (cam.CFrame.Position - pos).Magnitude <= REMOTE_RANGE
end

------------------------------------------------------------------------
-- points d'accroche de la traînée (arme fétiche, objet tenu, bras / jambe)
------------------------------------------------------------------------
local function farthest(parts, space: CFrame, from: Vector3)
	local best, bestD = nil, -1
	for _, p in ipairs(parts) do
		local lp = space:PointToObjectSpace(p.Position)
		local d = (lp - from).Magnitude
		if d > bestD then
			local half = math.max(p.Size.X, p.Size.Y, p.Size.Z) * 0.5
			local dir = (lp - from).Magnitude > 0.01 and (lp - from).Unit or Vector3.new(0, -1, 0)
			best, bestD = lp + dir * half, d
		end
	end
	return best
end

local function baseParts(root: Instance)
	local list = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- arme fétiche : tout est soudé au bras -> attachments sur le BRAS, de la main au bout de l'arme
local function signatureAnchor(c: Model, side: string)
	local sig = c:FindFirstChild("Signature")
	if not sig or sig:GetAttribute("Hand") ~= side then
		return nil
	end
	if side == "Right" and c:GetAttribute("HeldItem") ~= nil then
		return nil -- cachée quand la main droite tient un objet
	end
	local arm = c:FindFirstChild(side .. " Arm")
	if not arm or not arm:IsA("BasePart") then
		return nil
	end
	local first = sig:FindFirstChildWhichIsA("BasePart", true)
	if not first or first.LocalTransparencyModifier >= 1 then
		return nil -- arme cachée (main occupée par une attaque) : traînée de poing
	end
	local cached = tipCache[sig]
	if cached and cached.part == arm then
		return cached
	end
	local near = Vector3.new(0, -0.9, 0)
	local tip = farthest(baseParts(sig), arm.CFrame, Vector3.new(0, 1, 0))
	if not tip or (tip - near).Magnitude < 0.6 then
		tip = near + Vector3.new(0, -1.1, 0)
	end
	cached = { part = arm, near = near:Lerp(tip, 0.2), tip = tip }
	tipCache[sig] = cached
	return cached
end

local function findHandle(c: Model): BasePart?
	for _, name in ipairs({ "Right Arm", "Torso" }) do
		local part = c:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			local ok, joints = pcall(part.GetJoints, part)
			if ok and type(joints) == "table" then
				for _, j in ipairs(joints) do
					if j.Name == "HoldWeld" and j:IsA("Weld") and j.Part1 then
						return j.Part1
					end
				end
			end
		end
	end
	return nil
end

-- objet tenu : attachments sur le Handle, du point de prise au bout de l'objet
local function itemAnchor(c: Model, cfg)
	local handle = findHandle(c)
	if not handle then
		return nil
	end
	local cached = tipCache[handle]
	if cached then
		return cached
	end
	local model = handle.Parent
	local parts = (model and model:IsA("Model")) and baseParts(model) or { handle }
	local near = Vector3.zero
	local arm = c:FindFirstChild("Right Arm")
	if cfg.Hold ~= "TwoHands" and arm and arm:IsA("BasePart") then
		near = handle.CFrame:PointToObjectSpace(arm.CFrame:PointToWorldSpace(Vector3.new(0, -1, 0)))
	end
	local tip = farthest(parts, handle.CFrame, near)
	if not tip or (tip - near).Magnitude < 0.6 then
		return nil
	end
	cached = { part = handle, near = near:Lerp(tip, 0.25), tip = tip }
	tipCache[handle] = cached
	return cached
end

-- poing / pied : petit ruban le long du bout du membre
local function limbAnchor(c: Model, side: string, leg: boolean, size: number)
	local part = c:FindFirstChild(side .. (leg and " Leg" or " Arm"))
	if not part or not part:IsA("BasePart") then
		return nil
	end
	local s = size or 0.9
	return { part = part, near = Vector3.new(0, -1 + 0.55 * s, 0), tip = Vector3.new(0, -1.05, 0) }
end

------------------------------------------------------------------------
-- traînées (fenêtre du coup uniquement) + limite globale
------------------------------------------------------------------------
local function pruneTrails()
	local max = MAX_TRAILS[qualityName()]
	for i = #activeTrails, 1, -1 do
		if not activeTrails[i].trail.Parent then
			table.remove(activeTrails, i)
		end
	end
	while #activeTrails >= max do
		local old = table.remove(activeTrails, 1)
		for _, inst in ipairs({ old.trail, old.a0, old.a1 }) do
			inst:Destroy()
		end
	end
end

local function makeTrail(anchor, trail, colors, onAt: number, offAt: number)
	pruneTrails()
	local mid = (anchor.near + anchor.tip) / 2
	local half = (anchor.tip - anchor.near) / 2 * math.clamp(trail.Width or 1, 0.3, 1.6)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Name, a1.Name = "M1TrailA", "M1TrailB"
	a0.Position, a1.Position = mid - half, mid + half
	a0.Parent, a1.Parent = anchor.part, anchor.part
	local low = qualityName() == "Low"
	local life = (trail.Lifetime or 0.16) * (low and 0.7 or 1)
	local tr = Instance.new("Trail")
	tr.Name = "M1Trail"
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(colors[1], colors[2] or colors[1])
	tr.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, reduced() and 0.45 or 0.1),
		NumberSequenceKeypoint.new(0.6, reduced() and 0.8 or 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	tr.WidthScale = NumberSequence.new(1, 0.15)
	tr.Lifetime = life
	tr.MinLength = 0.05
	tr.LightEmission = reduced() and 0 or (trail.Light or 0.5)
	tr.LightInfluence = reduced() and 1 or 0.4
	tr.Enabled = false
	tr.Parent = anchor.part
	table.insert(activeTrails, { trail = tr, a0 = a0, a1 = a1 })
	task.delay(onAt, function()
		if tr.Parent then
			tr.Enabled = true
		end
	end)
	task.delay(offAt, function()
		if tr.Parent then
			tr.Enabled = false
		end
	end)
	Debris:AddItem(tr, offAt + life + 0.1)
	Debris:AddItem(a0, offAt + life + 0.15)
	Debris:AddItem(a1, offAt + life + 0.15)
end

------------------------------------------------------------------------
-- impacts par style
------------------------------------------------------------------------
local UP = Vector3.new(0, 1, 0)
local GREASE = { Color3.fromRGB(255, 205, 90), Color3.fromRGB(230, 150, 50), Color3.fromRGB(255, 240, 170) }

local function camFacing(pos: Vector3): CFrame
	local cam = workspace.CurrentCamera
	if cam then
		return CFrame.lookAt(pos, cam.CFrame.Position)
	end
	return CFrame.new(pos)
end

local function star(pos: Vector3, color: Color3, size: number)
	local base = camFacing(pos)
	for i = 0, 1 do
		local p = fxPart(Vector3.new(0.1, 0.1, 0.05), base * CFrame.Angles(0, 0, math.rad(45 * i)), color, true)
		tween(p, 0.12, { Size = Vector3.new(size, size * 0.3, 0.05) }, Enum.EasingStyle.Back)
		task.delay(0.12, function()
			tween(p, 0.22, { Size = Vector3.new(size * 0.2, 0.05, 0.05), Transparency = 1 })
		end)
		Debris:AddItem(p, 0.4)
		local q = fxPart(Vector3.new(0.1, 0.1, 0.05), base * CFrame.Angles(0, 0, math.rad(45 * i + 90)), color, true)
		tween(q, 0.12, { Size = Vector3.new(size, size * 0.3, 0.05) }, Enum.EasingStyle.Back)
		task.delay(0.12, function()
			tween(q, 0.22, { Size = Vector3.new(size * 0.2, 0.05, 0.05), Transparency = 1 })
		end)
		Debris:AddItem(q, 0.4)
	end
end

local IMPACTS = {}

function IMPACTS.Punch(pos, dir, colors, heavy)
	CartoonFX.airRing(pos, dir, heavy and 9 or 5, colors[2], 0.22)
end

function IMPACTS.Blunt(pos, dir, colors, heavy)
	CartoonFX.airRing(pos, dir, heavy and 10 or 6.5, colors[1], 0.25)
	task.delay(0.05, function()
		CartoonFX.airRing(pos, dir, heavy and 14 or 9, colors[2], 0.3)
	end)
	CartoonFX.puff(pos - Vector3.new(0, 0.6, 0), heavy and 1.15 or 0.65)
end

function IMPACTS.Heavy(pos, dir, colors, heavy)
	local g = CartoonFX.groundPos(pos)
	CartoonFX.shockwave(g + Vector3.new(0, 0.12, 0), heavy and 9 or 5.5, colors[1])
	CartoonFX.dust(pos, heavy and 7 or 4.5, nil, heavy and 12 or 6)
	CartoonFX.airRing(pos, dir, heavy and 10 or 6, colors[2], 0.25)
	if heavy then
		CartoonFX.cracks(pos, 5, 3.5, 1.0)
	end
end

function IMPACTS.Slash(pos, dir, colors, heavy)
	local side = dir:Cross(UP)
	if side.Magnitude < 0.05 then
		side = Vector3.new(1, 0, 0)
	end
	for k = 0, heavy and 1 or 0 do
		local base = CFrame.lookAt(pos, pos + side.Unit) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-35, 35) + k * 60))
		local len = heavy and 7 or 5
		local s = fxPart(Vector3.new(0.35, 0.18, len * 0.5), base, colors[2], true)
		local core = fxPart(Vector3.new(0.18, 0.08, len * 0.45), base, Color3.new(1, 1, 1), true)
		tween(s, 0.2, { Size = Vector3.new(0.05, 0.03, len), Transparency = 1 })
		tween(core, 0.14, { Size = Vector3.new(0.03, 0.02, len * 0.9), Transparency = 1 })
		Debris:AddItem(s, 0.25)
		Debris:AddItem(core, 0.18)
	end
	CartoonFX.sparks(pos, heavy and 14 or 6, colors[2])
end

function IMPACTS.Slap(pos, dir, colors, heavy)
	-- feuilles de papier qui volettent + petite étoile
	for _ = 1, CartoonFX.count(heavy and 8 or 4) do
		local cf = CFrame.new(pos + Vector3.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.3, 0.5), rng:NextNumber(-0.5, 0.5)))
			* CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		local sheet = fxPart(Vector3.new(0.7, 0.04, 0.9), cf, Color3.fromRGB(250, 250, 245))
		local out = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * rng:NextNumber(1.5, 3) + dir * 1.5
		local top = cf.Position + out + Vector3.new(0, rng:NextNumber(1, 2.2), 0)
		tween(sheet, 0.25, { CFrame = CFrame.new(top) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0) })
		task.delay(0.25, function()
			if sheet.Parent then
				tween(sheet, 0.6, { CFrame = CFrame.new(top + out * 0.4 - Vector3.new(0, 2.5, 0)) * CFrame.Angles(rng:NextNumber(0, 6), 0, rng:NextNumber(0, 6)), Transparency = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
			end
		end)
		Debris:AddItem(sheet, 0.9)
	end
	star(pos + Vector3.new(0, 0.8, 0), colors[2], heavy and 2.6 or 1.6)
	if heavy then
		CartoonFX.twinkle(pos + Vector3.new(0, 1.5, 0))
	end
end

function IMPACTS.Claws(pos, dir, colors, heavy, mirrored)
	local base = CFrame.lookAt(pos - dir * 0.4, pos - dir * 1.4) * CFrame.Angles(0, 0, math.rad(mirrored and -32 or 32))
	local len = heavy and 4 or 3
	for k = -1, 1 do
		task.delay((k + 1) * 0.025, function()
			local cf = base * CFrame.new(k * 0.5, 0, 0)
			local line = fxPart(Vector3.new(0.16, 0.2, 0.06), cf * CFrame.new(0, len * 0.5, 0), colors[2], true)
			local core = fxPart(Vector3.new(0.07, 0.2, 0.07), cf * CFrame.new(0, len * 0.5, 0), Color3.new(1, 1, 1), true)
			tween(line, 0.07, { Size = Vector3.new(0.16, len, 0.06), CFrame = cf })
			tween(core, 0.07, { Size = Vector3.new(0.07, len * 0.9, 0.07), CFrame = cf })
			task.delay(0.12, function()
				if line.Parent then
					tween(line, 0.25, { Transparency = 1, Size = Vector3.new(0.04, len, 0.04) })
					tween(core, 0.18, { Transparency = 1 })
				end
			end)
			Debris:AddItem(line, 0.42)
			Debris:AddItem(core, 0.35)
		end)
	end
end

function IMPACTS.Tech(pos, dir, colors, heavy)
	for _ = 1, CartoonFX.count(heavy and 16 or 9) do
		local c = rng:NextNumber() < 0.5 and colors[1] or colors[2]
		local px = fxPart(Vector3.one * rng:NextNumber(0.25, 0.45), CFrame.new(pos), c, true)
		local d = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 1), rng:NextNumber(-1, 1))
		d = (d.Magnitude > 0.05 and d.Unit or UP) + dir * 0.6
		tween(px, 0.35, { CFrame = CFrame.new(pos + d * rng:NextNumber(2.5, 4.5)), Size = Vector3.one * 0.05, Transparency = 0.6 }, Enum.EasingStyle.Linear)
		Debris:AddItem(px, 0.38)
	end
	local frame = fxPart(Vector3.new(0.4, 0.4, 0.04), camFacing(pos) * CFrame.Angles(0, 0, math.rad(45)), colors[1], true)
	frame.Transparency = 0.3
	tween(frame, 0.22, { Size = Vector3.new(heavy and 5 or 3.2, heavy and 5 or 3.2, 0.02), Transparency = 1 })
	Debris:AddItem(frame, 0.25)
	if not reduced() then
		CartoonFX.light(pos, colors[1], 10, 2, 0.15)
	end
	CartoonFX.sound("Electric", pos, 0.25, 1.6)
end

function IMPACTS.Bacon(pos, dir, colors, heavy)
	CartoonFX.shards(pos, heavy and 10 or 5, GREASE, 0.7)
	local g = CartoonFX.groundPos(pos)
	for _ = 1, CartoonFX.count(heavy and 5 or 3) do
		local r = rng:NextNumber(0.6, 1.4)
		local off = Vector3.new(rng:NextNumber(-2, 2), 0.06, rng:NextNumber(-2, 2)) + dir * 1.2
		local splat = fxPart(Vector3.new(0.08, r * 2, r * 2), CFrame.new(g + off) * CFrame.Angles(0, 0, math.pi / 2), GREASE[rng:NextInteger(1, #GREASE)], false, Enum.PartType.Cylinder)
		splat.Transparency = 0.35
		splat.Size = Vector3.new(0.08, 0.2, 0.2)
		tween(splat, 0.12, { Size = Vector3.new(0.08, r * 2, r * 2) }, Enum.EasingStyle.Back)
		task.delay(1.0, function()
			if splat.Parent then
				tween(splat, 0.5, { Transparency = 1 })
			end
		end)
		Debris:AddItem(splat, 1.6)
	end
	CartoonFX.airRing(pos, dir, heavy and 8 or 5, colors[1], 0.2)
	CartoonFX.sound("Splat", pos, 0.35, 1.45)
end

function IMPACTS.Splash(pos, dir, colors, heavy)
	for _ = 1, CartoonFX.count(heavy and 12 or 7) do
		local drop = fxPart(Vector3.one * rng:NextNumber(0.25, 0.45), CFrame.new(pos), colors[2], false, Enum.PartType.Ball)
		drop.Transparency = 0.2
		local out = (Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) + dir).Unit * rng:NextNumber(1.5, 3.5)
		local top = pos + out * 0.6 + Vector3.new(0, rng:NextNumber(0.8, 1.8), 0)
		tween(drop, 0.18, { CFrame = CFrame.new(top) })
		task.delay(0.18, function()
			if drop.Parent then
				tween(drop, 0.3, { CFrame = CFrame.new(top + out * 0.5 - Vector3.new(0, 2.2, 0)), Transparency = 1, Size = Vector3.one * 0.1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
		Debris:AddItem(drop, 0.55)
	end
	CartoonFX.airRing(pos, dir, heavy and 8 or 5, colors[1], 0.2)
	CartoonFX.sound("Water", pos, 0.2, 1.3)
end

local function playImpact(style, pos: Vector3, dir: Vector3?, heavy: boolean, mirrored: boolean)
	local fn = IMPACTS[style.Impact or "Punch"] or IMPACTS.Punch
	local d = dir and Vector3.new(dir.X, 0, dir.Z) or Vector3.zero
	d = d.Magnitude > 0.05 and d.Unit or Vector3.new(0, 0, -1)
	local ok, err = pcall(fn, pos, d, style.Trail.Colors, heavy, mirrored)
	if not ok then
		warn("[M1StyleController] impact", style.Impact, err)
	end
end

------------------------------------------------------------------------
-- un coup commence (ProcAnim.onPlay)
------------------------------------------------------------------------
local function windupOf(meta, itemCfg): number
	local k = meta.Kind
	if k == "M1" then
		return M1.Windup[meta.I] or 0.15
	elseif k == "Up" then
		return CombatConfig.Uppercut.Windup
	elseif k == "Slam" then
		return CombatConfig.Downslam.Windup
	elseif k == "Air" then
		return CombatConfig.Air.Windup
	elseif k == "Dash" then
		return CombatConfig.DashStrike.Windup
	end
	return (itemCfg and itemCfg.Use and itemCfg.Use.Windup) or 0.1
end

local function heavyOf(meta, itemCfg): boolean
	local k = meta.Kind
	if k == "M1" then
		return (meta.I or 1) >= M1.Hits
	elseif k == "Item" then
		return itemCfg ~= nil and itemCfg.Use ~= nil and itemCfg.Use.Category == "Heavy"
	end
	return true -- uppercut, downslam, dash strike
end

local function hitboxOf(meta, itemCfg)
	local k = meta.Kind
	if k == "Item" then
		local u = itemCfg and itemCfg.Use
		if u and u.Damage and u.HitboxSize then
			return u.HitboxOffset or 3, u.HitboxSize
		end
		return nil
	elseif k == "Air" or k == "Slam" then
		return CombatConfig.Air.HitboxOffset, CombatConfig.Air.HitboxSize
	elseif k == "Dash" then
		return CombatConfig.DashStrike.HitboxOffset, CombatConfig.DashStrike.HitboxSize
	end
	return M1.HitboxOffset, M1.HitboxSize
end

-- impact prédit du joueur local (même règle de cibles que CombatController.predictHits)
local function predictImpact(c: Model, style, meta, itemCfg, w: number, heavy: boolean, mirrored: boolean)
	local offset, size = hitboxOf(meta, itemCfg)
	if not offset then
		return
	end
	task.delay(w, function()
		local hum = c:FindFirstChildOfClass("Humanoid")
		local root = c:FindFirstChild("HumanoidRootPart")
		if not hum or hum.Health <= 0 or not root or c:GetAttribute("UltAnchor") or serverNow() < (c:GetAttribute("StunUntil") or 0) then
			return
		end
		local cf = Hitbox.frontCFrame(c, offset)
		if not cf then
			return
		end
		for _, victim in ipairs(Hitbox.box(cf, size, c, 3)) do
			local vRoot = victim:FindFirstChild("HumanoidRootPart")
			local vHum = victim:FindFirstChildOfClass("Humanoid")
			if vRoot and vHum and vHum.Health > 0 and not victim:FindFirstChildOfClass("ForceField") and not victim:GetAttribute("Blocking")
				and not victim:GetAttribute("PendingKO") and serverNow() >= (victim:GetAttribute("KnockdownUntil") or 0)
				and victim:GetAttribute(CombatConfig.SafeZoneAttribute or "SafeZone") ~= true then
				local pos = vRoot.Position:Lerp(root.Position, 0.3) + Vector3.new(0, 0.6, 0)
				playImpact(style, pos, vRoot.Position - root.Position, heavy, mirrored)
			end
		end
	end)
end

local function onSwing(c: Model, animName: string)
	local meta, mirrored = M1Style.info(animName)
	if not meta or not isFighter(c) then
		return
	end
	local style, source, itemId = M1Style.resolve(c)
	local itemCfg = nil
	if meta.Kind == "Item" then
		if source ~= "Item" then
			return -- animation d'objet jouée hors d'un Use d'objet stylé (ou objet sans coup)
		end
		itemCfg = ItemsConfig[itemId]
	elseif source == "Item" then
		style = M1Style.forCharacter(c:GetAttribute("CharacterName"))
		source = "Signature"
	end
	local root = c:FindFirstChild("HumanoidRootPart")
	local isLocal = c == player.Character
	if not isLocal and not nearCamera(root.Position) then
		return
	end
	local w = windupOf(meta, itemCfg)
	local heavy = heavyOf(meta, itemCfg)
	local onAt = math.max(0, w - (heavy and 0.07 or 0.05))
	local offAt = w + (heavy and 0.12 or 0.09)
	local trail = style.Trail

	-- traînées : arme si elle est dans la main qui frappe, sinon bras / jambe
	local main = mirrored and "Left" or "Right"
	local other = mirrored and "Right" or "Left"
	local limbs
	if meta.Kind == "Item" then
		limbs = { { side = "Right", item = true } }
	elseif meta.Limb == "O" then
		limbs = { { side = other } }
	elseif meta.Limb == "B" then
		limbs = { { side = main }, { side = other } }
	elseif meta.Limb == "K" then
		limbs = { { side = main, leg = true } }
	else
		limbs = { { side = main } }
	end
	for _, l in ipairs(limbs) do
		local anchor
		if l.item then
			anchor = itemCfg and itemAnchor(c, itemCfg)
			if not anchor and itemCfg and itemCfg.Hold ~= "TwoHands" then
				anchor = limbAnchor(c, "Right", false, trail.Fist)
			end
		else
			anchor = (not l.leg and signatureAnchor(c, l.side)) or limbAnchor(c, l.side, l.leg == true, trail.Fist)
		end
		if anchor then
			makeTrail(anchor, trail, trail.Colors, onAt, offAt)
		end
	end

	-- arc de taillade (armes larges) : selon le style, jamais en qualité Low
	local arc = meta.Arc
	local arcMode = trail.Arc
	if arc and (arcMode == "All" or (arcMode == "Finisher" and heavy)) and qualityName() ~= "Low" then
		task.delay(math.max(0, w - 0.04), function()
			if not root.Parent then
				return
			end
			local s = mirrored and -1 or 1
			local cf = root.CFrame * CFrame.new(0, arc[5] or 0.3, 0)
			CartoonFX.slashArc(cf, arc[4] or 5, trail.Colors[2], arc[1] * s, arc[2] * s, heavy and 0.1 or 0.07, (arc[3] or 0) * s, trail.ArcWidth or 0.45)
		end)
	end

	-- whoosh (le joueur local a déjà le whoosh de CombatController : couche en plus seulement si le style en a une)
	local wh = style.Whoosh
	if wh and (not isLocal or wh.Layer ~= false) then
		task.delay(math.max(0, w - 0.06), function()
			if root.Parent then
				CartoonFX.sound(wh.Key or "Whoosh", root.Position, (wh.Volume or 0.4) * (isLocal and 1 or 0.8), wh.Pitch)
			end
		end)
	end

	if isLocal then
		predictImpact(c, style, meta, itemCfg, w, heavy, mirrored)
	else
		swings[c] = { style = style, mirrored = mirrored, heavy = heavy, hitUntil = os.clock() + w + HIT_GRACE }
	end
end

function M1StyleController.init()
	ProcAnim.onPlay(onSwing)
	-- impact stylé des coups des AUTRES joueurs : à la réception du « Hit » serveur pendant la fenêtre de leur coup
	Net.get("FX").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" or (data.k or data.type) ~= "Hit" or typeof(data.p) ~= "Vector3" then
			return
		end
		local a = data.a
		if typeof(a) ~= "Instance" or a == player.Character then
			return
		end
		local sw = swings[a]
		if not sw or os.clock() > sw.hitUntil then
			return
		end
		local aRoot = a:FindFirstChild("HumanoidRootPart")
		local dir = aRoot and (data.p - aRoot.Position) or nil
		playImpact(sw.style, data.p, dir, sw.heavy or data.c == "Heavy", sw.mirrored)
	end)
end

return M1StyleController
