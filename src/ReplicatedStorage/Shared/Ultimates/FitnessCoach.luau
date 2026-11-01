--[[
	Ultimate du Fitness Coach : MAXIMUM REP
	Cloche de boxe DING DING + sifflet ; ruée de 10 coups de poing comptés (1..10) avec poings rémanents et caméra qui tourne ;
	une barre géante de 1000 LB se matérialise : squat -> épaulé -> développé au-dessus de la tête (la foule hurle) ;
	il saute et ÉCRASE la barre sur la victime : PLAQUÉE au sol, énorme cratère, « NEW PR! ».
	Raté : il soulève la barre, la lâche devant lui, « NO REP! » et se tient le dos.
]]
-- ===== PRELUDE ult3 (commun aux 4 modules, copié dans chacun) =====
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Enum.PartType.Cylinder, Enum.PartType.Ball, CFrame.Angles(0, 0, math.pi / 2)
local rng = Random.new()
local function now()
	return workspace:GetServerTimeNow()
end
local function flat(v, fb)
	v = Vector3.new(v.X, 0, v.Z)
	if v.Magnitude < 0.05 then
		return fb or Vector3.new(0, 0, -1)
	end
	return v.Unit
end
local function rootOf(c)
	return c and c.Parent and c:FindFirstChild("HumanoidRootPart")
end
local function alive(c)
	local h = c and c.Parent and c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end
-- ===== FIN PRELUDE =====
local LIME = Color3.fromRGB(140, 225, 30)
local LIME2 = Color3.fromRGB(200, 255, 110)
local IRON = Color3.fromRGB(55, 58, 66)
local DARK = Color3.fromRGB(30, 30, 36)
local WHITE = Color3.fromRGB(250, 250, 250)
local GOLD = Color3.fromRGB(255, 200, 40)
local SILVER = Color3.fromRGB(205, 210, 220)
local SWEAT = Color3.fromRGB(150, 210, 255)

local SND = {
	Bell = "rbxassetid://135309651997361",
	Cheer = "rbxassetid://126615573673174",
	Cheer2 = "rbxassetid://7755719721",
	Punch = "rbxassetid://9113573976",
	Barrage = "rbxassetid://126111468668751",
	Clank = "rbxassetid://9125670743",
	Clank2 = "rbxassetid://9125672524",
	Boom = "rbxassetid://9114362625",
	Bass = "rbxassetid://9119388384",
	Riser = "rbxassetid://1837834302",
	PanDrop = "rbxassetid://9117197553",
}

local T = { Rush0 = 0.3, RushStep = 0.105, Reps = 10, Bar = 1.45, Clean = 1.75, Press = 2.05, Jump = 2.45, Slam = 2.8, End = 3.4 }
local DMG = { Rep = 1.6, Final = 18, Splash = 12, SplashR = 12 }

local ANIMS = {
	FitUltRush = (function() -- 10 directs alternés très appuyés, garde basse, appuis qui pivotent
		local f = { { t = 0 }, { t = 0.06, RS = { p = 1.0, y = 0.6 }, LS = { p = 1.0, y = 0.6 }, RJ = { ln = 0.3 }, RH = { p = -0.45 }, LH = { p = 0.6 } } }
		for i = 1, 10 do
			local right = i % 2 == 1
			local t = 0.06 + i * 0.105
			table.insert(f, { t = t - 0.05, RS = { p = right and 0.9 or 1.95, y = right and 0.6 or 0.1 }, LS = { p = right and 1.95 or 0.9, y = right and 0.1 or 0.6 }, RJ = { tw = right and -0.5 or 0.5, ln = 0.35 }, RH = { p = -0.5 }, LH = { p = 0.65 } })
			table.insert(f, { t = t, RS = { p = right and 2.0 or 0.9, y = right and 0.1 or 0.6 }, LS = { p = right and 0.9 or 2.0, y = right and 0.6 or 0.1 }, RJ = { tw = right and 0.6 or -0.6, ln = 0.4, sd = right and 0.06 or -0.06 }, RH = { p = -0.5 }, LH = { p = 0.7 } })
		end
		table.insert(f, { t = 1.25, RS = { p = 3.2, y = 0.2 }, LS = { p = -0.4, r = -0.3 }, RJ = { tw = 0.7, ln = -0.4 }, RH = { p = -0.3 }, LH = { p = 1.2 } }) -- 10e : uppercut
		table.insert(f, { t = 1.4 })
		return f
	end)(),
	FitUltLift = (function() -- squat -> épaulé -> développé, puis tremblement sous la charge
		local f = {
			{ t = 0 },
			{ t = 0.2, RS = { p = 0.35 }, LS = { p = 0.35 }, RJ = { ln = 0.6 }, RH = { p = 1.3, r = -0.25 }, LH = { p = 1.3, r = -0.25 } },
			{ t = 0.32, RS = { p = 0.4 }, LS = { p = 0.4 }, RJ = { ln = 0.55 }, RH = { p = 1.25, r = -0.25 }, LH = { p = 1.25, r = -0.25 } },
			{ t = 0.45, RS = { p = 2.0, r = -0.6 }, LS = { p = 2.0, r = -0.6 }, RJ = { ln = -0.15 }, RH = { p = 0.1, r = -0.2 }, LH = { p = 0.1, r = -0.2 } }, -- épaulé
			{ t = 0.62, RS = { p = 1.9, r = -0.6 }, LS = { p = 1.9, r = -0.6 }, RJ = { ln = 0.15 }, RH = { p = 0.45, r = -0.2 }, LH = { p = 0.45, r = -0.2 } }, -- flexion
			{ t = 0.75, RS = { p = 3.15, r = -0.4 }, LS = { p = 3.15, r = -0.4 }, RJ = { ln = -0.25 }, RH = { p = 0, r = -0.2 }, LH = { p = 0, r = -0.2 } }, -- développé
		}
		local t, s = 0.75, 1
		while t < 1.15 do
			t += 0.05
			s = -s
			table.insert(f, { t = t, RS = { p = 3.15 + 0.06 * s, r = -0.4 }, LS = { p = 3.15 - 0.06 * s, r = -0.4 }, RJ = { ln = -0.25, sd = 0.05 * s }, RH = { p = 0.05 * s, r = -0.2 }, LH = { p = -0.05 * s, r = -0.2 } })
		end
		table.insert(f, { t = 1.3, RS = { p = 3.2, r = -0.4 }, LS = { p = 3.2, r = -0.4 }, RJ = { ln = -0.3 }, RH = { p = 1.0 }, LH = { p = 0.6 } }) -- saut, genoux rentrés
		return f
	end)(),
	FitUltSlam = { -- abat la barre de tout son corps
		{ t = 0 },
		{ t = 0.08, RS = { p = 3.4, r = -0.4 }, LS = { p = 3.4, r = -0.4 }, RJ = { ln = -0.5 }, RH = { p = 1.1 }, LH = { p = 0.8 } },
		{ t = 0.16, RS = { p = 0.9, r = -0.35 }, LS = { p = 0.9, r = -0.35 }, RJ = { ln = 0.95 }, RH = { p = 1.15, r = -0.3 }, LH = { p = 1.15, r = -0.3 } },
		{ t = 0.5, RS = { p = 1.0, r = -0.35 }, LS = { p = 1.0, r = -0.35 }, RJ = { ln = 0.85 }, RH = { p = 1.0, r = -0.3 }, LH = { p = 1.0, r = -0.3 } },
		{ t = 0.6 },
	},
	FitUltFlex = { -- double biceps triomphant
		{ t = 0 },
		{ t = 0.15, RS = { p = 2.3, r = -1.25, y = 1.2 }, LS = { p = 2.3, r = -1.25, y = 1.2 }, RJ = { ln = -0.25 }, RH = { r = -0.2 }, LH = { r = -0.2 } },
		{ t = 0.3, RS = { p = 2.45, r = -1.3, y = 1.3 }, LS = { p = 2.45, r = -1.3, y = 1.3 }, RJ = { ln = -0.3 }, RH = { r = -0.2 }, LH = { r = -0.2 } },
		{ t = 0.45, RS = { p = 2.3, r = -1.25, y = 1.2 }, LS = { p = 2.3, r = -1.25, y = 1.2 }, RJ = { ln = -0.25 }, RH = { r = -0.2 }, LH = { r = -0.2 } },
		{ t = 0.8 },
	},
	FitUltBack = { -- raté : lâche la barre, se tient le dos, plié en deux
		{ t = 0 },
		{ t = 0.1, RS = { p = -0.6, r = 0.3 }, LS = { p = -0.6, r = 0.3 }, RJ = { ln = 0.75, sd = 0.15 }, RH = { p = 0.4 }, LH = { p = -0.1 } },
		{ t = 0.55, RS = { p = -0.65, r = 0.3 }, LS = { p = -0.55, r = 0.3 }, RJ = { ln = 0.7, sd = 0.2 }, RH = { p = 0.4 }, LH = { p = -0.1 } },
		{ t = 0.75 },
	},
	FitUltCharge = { -- charge épaule en avant
		{ t = 0 },
		{ t = 0.08, RS = { p = 0.4, r = -0.2 }, LS = { p = 1.4, y = 0.8 }, RJ = { ln = 0.6, tw = 0.6 }, RH = { p = -0.8 }, LH = { p = 1.0 } },
		{ t = 0.2, RS = { p = 0.3, r = -0.2 }, LS = { p = 1.5, y = 0.8 }, RJ = { ln = 0.6, tw = 0.6 }, RH = { p = 1.0 }, LH = { p = -0.8 } },
		{ t = 0.32, RS = { p = 0.4, r = -0.2 }, LS = { p = 1.4, y = 0.8 }, RJ = { ln = 0.6, tw = 0.6 }, RH = { p = -0.8 }, LH = { p = 1.0 } },
		{ t = 0.45 },
	},
}

-- ===== OUTILS CLIENT ult3 (s'appuient sur UltKit = KK, fourni à chaque appel Client) =====
local KK, CFX, CUR
local LIVE, ENDED = {}, {}
-- garde une connexion pour la couper à "End"
local function keep(d, conn)
	local k = d.seq or 0
	LIVE[k] = LIVE[k] or {}
	table.insert(LIVE[k], conn)
	return conn
end
local function finishSeq(d)
	local k = d.seq or 0
	ENDED[k] = true
	for _, cn in ipairs(LIVE[k] or {}) do
		cn:Disconnect()
	end
	LIVE[k] = nil
	task.delay(10, function()
		ENDED[k] = nil
	end)
end
local function play(c, name, speed)
	if c and c.Parent then
		if ANIMS[name] then
			KK.anim(c, ANIMS[name], speed)
		else
			KK.ProcAnim.play(c, name, speed) -- animations partagées (HitHeavy, HitLight…)
		end
	end
end
-- planifie fn à l'instant t de la phase (synchro sur l'horloge serveur via data.t0)
local function at(d, t, fn)
	KK.at(d, t, function()
		if ENDED[d.seq or 0] then -- ulti terminée / annulée : on ne lance plus rien
			return
		end
		local ok, err = pcall(fn)
		if not ok then
			warn("[Ult " .. tostring(d.id) .. "]", err)
		end
	end)
end
local function fxPart(props, life)
	return KK.part(props, life or 4)
end
local function tw(o, t, props, style, dir)
	return KK.tween(o, t, props, style, dir)
end
local function snd(id, pos, vol, pitch)
	return KK.sound(id, pos, vol, pitch)
end
local function word(pos, text, power)
	KK.word(pos, text, power or 1, "Heavy")
end
local function label(pos, text, color, size, life, rise)
	Kit.floatText(pos, text, color, size or 3, life or 1, rise or 1.5)
end
local function ball(pos, size, color, transp, life)
	return fxPart({ Shape = BALL, Size = Vector3.one * size, Position = pos, Color = color, Transparency = transp or 0 }, life)
end
local function puff(pos, size, life, rise, color)
	local b = ball(pos, size, color or Color3.fromRGB(235, 240, 245), 0.25, life + 0.1)
	tw(b, life, { Position = pos + Vector3.new(0, rise, 0), Size = Vector3.one * size * 2.2, Transparency = 1 })
end
-- boule qui grossit et s'efface (explosion, flash)
local function blast(pos, from, to, color, life, transp)
	local b = ball(pos, from, color, transp or 0.1, life + 0.1)
	tw(b, life, { Size = Vector3.one * to, Transparency = 1 })
	return b
end
-- anneau plat (cf : repère d'un cylindre ; défaut = horizontal au sol)
local function ring(pos, cf, from, to, color, life, thick)
	local r = fxPart({ Shape = CYL, Size = Vector3.new(thick or 0.4, from, from), CFrame = cf or (CFrame.new(pos) * UP), Color = color, Transparency = 0.1 }, life + 0.1)
	tw(r, life, { Size = Vector3.new(0.1, to, to), Transparency = 1 })
end
-- teinte globale temporaire (sépia…) : ColorCorrection local, suivi par l'ulti (nettoyé à "End")
local function tint(d, props, dur, fadeIn, fadeOut)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Ult3Tint"
	cc.Parent = game:GetService("Lighting")
	KK.track(d, cc)
	tw(cc, fadeIn or 0.15, props)
	task.delay(dur, function()
		if cc.Parent then
			tw(cc, fadeOut or 0.25, { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = Color3.new(1, 1, 1) })
			Debris:AddItem(cc, (fadeOut or 0.25) + 0.05)
		end
	end)
	Debris:AddItem(cc, dur + (fadeOut or 0.25) + 2)
	return cc
end
local function near(d, pos)
	return KK.involved(d) or KK.near(pos, 70)
end
-- ===== FIN OUTILS CLIENT =====

-- ===== RIG client (groupe de parts ancrées déplacé d'un bloc) =====
local Rig = {}
Rig.__index = Rig
local function newRig(cf)
	local folder = Instance.new("Folder")
	folder.Name = "Ult3Rig"
	folder.Parent = workspace:FindFirstChild("FX") or workspace
	if CUR then
		KK.track(CUR, folder) -- détruit à "End" quoi qu'il arrive
	end
	Debris:AddItem(folder, 9)
	return setmetatable({ folder = folder, parts = {}, offs = {}, cf = cf, conns = {} }, Rig)
end
function Rig:add(size, off, color, shape, transp, mat)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = mat or Enum.Material.SmoothPlastic
	p.Size, p.Color = size, color
	if shape then
		p.Shape = shape
	end
	p.Transparency = transp or 0
	p.CFrame = self.cf * off
	if not self.folder.Parent then -- ulti déjà nettoyée
		return p
	end
	p.Parent = self.folder
	table.insert(self.parts, p)
	table.insert(self.offs, off)
	return p
end
function Rig:set(cf)
	self.cf = cf
	for i, p in ipairs(self.parts) do
		p.CFrame = cf * self.offs[i]
	end
end
-- déplace le rig de son CFrame actuel vers cf en t secondes (style d'easing : fonction alpha -> alpha)
function Rig:move(cf, t, ease)
	local from = self.cf
	local t0 = os.clock()
	if self.mover then
		self.mover:Disconnect()
	end
	self.mover = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / math.max(t, 1e-3), 0, 1)
		local e = ease and ease(a) or (1 - (1 - a) * (1 - a))
		if self.folder.Parent then
			self:set(from:Lerp(cf, e))
		end
		if a >= 1 and self.mover then
			self.mover:Disconnect()
			self.mover = nil
		end
	end)
end
function Rig:text(part, text, color, face)
	return Kit.flatText(part, text, color, face)
end
function Rig:fade(t)
	if self.mover then
		self.mover:Disconnect()
		self.mover = nil
	end
	for _, p in ipairs(self.parts) do
		if p.Parent then
			TweenService:Create(p, TweenInfo.new(t), { Transparency = 1 }):Play()
			for _, g in ipairs(p:GetDescendants()) do
				if g:IsA("TextLabel") then
					TweenService:Create(g, TweenInfo.new(t), { TextTransparency = 1 }):Play()
				end
			end
		end
	end
	Debris:AddItem(self.folder, t + 0.05)
end
function Rig:destroy()
	if self.mover then
		self.mover:Disconnect()
		self.mover = nil
	end
	self.folder:Destroy()
end
-- ===== FIN RIG =====

-- enchaîne des évènements { {t, fn}, ... } (t en s depuis le début, horloge absolue : pas de dérive) ; false si annulée
local function run(U, ctx, events)
	table.sort(events, function(a, b)
		return a[1] < b[1]
	end)
	local start = os.clock()
	for _, e in ipairs(events) do
		local dt = e[1] - (os.clock() - start)
		if dt > 0.005 then
			if not U.wait(ctx, dt) then
				return false
			end
		elseif not U.alive(ctx) then
			return false
		end
		local ok, err = pcall(e[2])
		if not ok then
			warn("[Ult " .. tostring(ctx.id) .. "]", err)
		end
	end
	return true
end

------------------------------------------------------------------------
-- SERVEUR
------------------------------------------------------------------------
local function server(U, caster, target, ctx)
	local cr = U.root(caster)
	if not cr then
		return
	end
	-- attaque : charge à l'épaule
	U.fx(ctx, "Dash")
	if not target or not U.rush(ctx, target, { speed = 110, contact = 3.6, maxTime = 0.45, whiffDist = 14, whiffTime = 0.25 }) then
		cr = U.root(caster)
		if cr then
			U.fx(ctx, "Whiff", { base = U.ground(cr.Position), dir = U.flat(cr.CFrame.LookVector) })
		end
		U.wait(ctx, 0.9)
		return
	end
	cr = U.root(caster)
	local vr = U.root(target)
	if not cr or not vr then
		return
	end
	local dir = U.flat(vr.Position - cr.Position, cr.CFrame.LookVector)
	local base = U.ground(vr.Position)
	local V0 = base + Vector3.new(0, 3, 0)
	local V1 = Kit.safePoint(V0, V0 + dir * 4, 2)
	U.hold(ctx, target, CFrame.lookAt(V0, V0 - dir))
	U.place(ctx, caster, CFrame.lookAt(V0 - dir * 3.2, V0))
	U.fx(ctx, "Hit", { base = base, dir = dir, v1 = V1 })
	local apex = V1 - dir * 2.6 + Vector3.new(0, math.min(9, (U.headroom(V1, 9) or 9) - 1.5), 0)
	local land = U.ground(V1 - dir * 2.4) + Vector3.new(0, 3, 0)
	local ev = {
		{ T.Jump, function()
			U.glide(ctx, caster, CFrame.lookAt(apex, apex + dir), T.Slam - T.Jump - 0.12, "Out")
		end },
		{ T.Slam - 0.12, function()
			U.glide(ctx, caster, CFrame.lookAt(land, land + dir), 0.12, "In")
		end },
		{ T.Slam, function()
			U.finish(ctx, target, DMG.Final, { pin = true, stun = 1.7, words = { "NEW PR!" },
				splash = { radius = DMG.SplashR, damage = DMG.Splash, center = V1 } })
		end },
		{ T.End, function() end },
	}
	for i = 1, T.Reps do
		table.insert(ev, { T.Rush0 + i * T.RushStep, function()
			U.hit(ctx, target, DMG.Rep, { words = { tostring(i) .. "!" } })
			if i == T.Reps then
				U.glide(ctx, target, CFrame.lookAt(V1, V1 - dir), 0.18)
			end
		end })
	end
	run(U, ctx, ev)
end

------------------------------------------------------------------------
-- CLIENT
------------------------------------------------------------------------
-- barre géante (repère : centre de la barre, axe X = la barre)
local function buildBarbell(cf)
	local r = newRig(cf)
	r:add(Vector3.new(14, 0.45, 0.45), CFrame.new(), SILVER, CYL) -- barre (axe X)
	for _, s in ipairs({ -1, 1 }) do
		for k, x in ipairs({ 4.6, 5.5 }) do
			r:add(Vector3.new(0.75, 6.2 - k * 0.9, 6.2 - k * 0.9), CFrame.new(x * s, 0, 0), k == 1 and IRON or DARK, CYL)
			if k == 1 then
				r:add(Vector3.new(0.78, 2.4, 2.4), CFrame.new(x * s, 0, 0), LIME, CYL)
				local lab = r:add(Vector3.new(0.05, 1.2, 3.2), CFrame.new((x + 0.4) * s, 1.8, 0), IRON)
				r:text(lab, "1000 LB", GOLD, s > 0 and Enum.NormalId.Right or Enum.NormalId.Left)
			end
		end
		r:add(Vector3.new(0.5, 0.9, 0.9), CFrame.new(3.9 * s, 0, 0), SILVER, CYL) -- butées
	end
	return r
end

-- la barre suit les mains du caster
local function holdBar(c, bar)
	return RunService.RenderStepped:Connect(function()
		local ra, la, r = c:FindFirstChild("Right Arm"), c:FindFirstChild("Left Arm"), rootOf(c)
		if not (ra and la and r) or not bar.folder.Parent or bar.mover then
			return
		end
		local mid = ((ra.CFrame * CFrame.new(0, -1.1, 0)).Position + (la.CFrame * CFrame.new(0, -1.1, 0)).Position) / 2
		bar:set(CFrame.fromMatrix(mid, r.CFrame.RightVector, Vector3.yAxis))
	end)
end

local function clientWhiff(K, d)
	local c = d.caster
	local r = rootOf(c)
	local p = r and r.Position or d.base + Vector3.new(0, 3, 0)
	local bar = buildBarbell(CFrame.new(p))
	local conn = keep(d, holdBar(c, bar))
	play(c, "FitUltLift", 1.6)
	snd(SND.Riser, p, 0.4, 1.8)
	at(d, 0.5, function()
		conn:Disconnect()
		local g = Kit.ground(p + d.dir * 3)
		bar:move(CFrame.fromMatrix(g + Vector3.new(0, 2.6, 0), bar.cf.RightVector, Vector3.yAxis), 0.16, function(a)
			return a * a
		end)
		play(c, "FitUltBack")
		task.delay(0.16, function()
			snd(SND.Clank, g, 1.2)
			snd(SND.PanDrop, g, 0.8)
			CFX.shockwave(g + Vector3.new(0, 0.2, 0), 8, LIME)
			CFX.dust(g, 6, nil, 8)
			label(g + Vector3.new(0, 5, 0), "NO REP!", Color3.fromRGB(255, 80, 70), 4, 1.1, 1.5)
			puff(p + Vector3.new(0.6, 2, 0), 0.4, 0.6, -1.5, SWEAT)
		end)
		task.delay(0.6, function()
			bar:fade(0.3)
		end)
	end)
end

local function clientHit(K, d)
	local c, v = d.caster, d.target
	local base, dir, V1 = d.base, d.dir, d.v1
	local V0 = base + Vector3.new(0, 3, 0)
	local isNear = near(d, d.base)
	KK.letterbox(d, true)
	KK.impactFrames("BWB", 0.04)
	-- DING DING + sifflet
	snd(SND.Bell, V0, 1.3)
	snd("Whistle", V0, 0.9)
	label(V0 + Vector3.new(0, 6, 0), "BEAST MODE!", LIME, 4, 0.9, 1)
	play(c, "FitUltFlex", 2)
	local rt = dir:Cross(Vector3.yAxis)
	KK.shot(d, "follow", { subject = c, offset = CFrame.new(-1.5, 0.8, -6), lookOffset = Vector3.new(0, 1.2, 0), fov = 50, flat = true })
	at(d, T.Rush0, function()
		KK.shot(d, "orbit", { at = V0 - dir * 1.6, radius = 11, height = 2.2, angle = 70, speed = 115, basis = CFrame.lookAt(Vector3.zero, dir), fov = 64 })
		play(c, "FitUltRush")
		snd(SND.Barrage, V0, 0.9, 1.1)
	end)
	-- 10 répétitions comptées
	local counter
	for i = 1, T.Reps do
		at(d, T.Rush0 + i * T.RushStep, function()
			local cr = rootOf(c)
			local from = cr and (cr.Position + cr.CFrame.RightVector * ((i % 2 == 1) and 0.8 or -0.8) + Vector3.new(0, 0.6, 0)) or (V0 - dir * 3)
			local to = V0 + Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(-0.3, 1.2), rng:NextNumber(-0.8, 0.8))
			for k = 1, 2 do -- poings rémanents
				local fist = ball(from + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.6, 0.8), 0), 1.3, k == 1 and LIME or LIME2, 0.25)
				tw(fist, 0.09, { Position = to, Size = Vector3.one * 0.6, Transparency = 0.8 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				Debris:AddItem(fist, 0.1)
			end
			snd(SND.Punch, V0, 1, 0.9 + i * 0.04)
			CFX.airRing(to, dir, 4 + i * 0.3, i % 2 == 0 and LIME or WHITE, 0.18)
			CFX.sparks(to, 6, LIME2)
			-- compteur de reps
			if counter then
				counter:Destroy()
			end
			counter = fxPart({ Size = Vector3.one * 0.2, Transparency = 1, Position = V0 + Vector3.new(0, 5, 0) })
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(3 + i * 0.35, 3 + i * 0.35)
			bb.AlwaysOnTop = true
			bb.LightInfluence = 0
			bb.Parent = counter
			local l = Instance.new("TextLabel")
			l.Size = UDim2.fromScale(1, 1)
			l.BackgroundTransparency = 1
			l.FontFace = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Bold)
			l.TextScaled = true
			l.Text = tostring(i)
			l.TextColor3 = i == T.Reps and GOLD or LIME
			l.Rotation = rng:NextNumber(-12, 12)
			l.Parent = bb
			local st = Instance.new("UIStroke")
			st.Thickness = 3
			st.Parent = l
			Debris:AddItem(counter, i == T.Reps and 0.8 or 0.3)
			if v then
				play(v, i % 2 == 0 and "HitLight" or "HitLight2")
			end
			if i == T.Reps then
				snd("Uppercut", V0, 1.2)
				CFX.bigImpact(V0, dir, 1.1, LIME)
				word(V0 + Vector3.new(0, 3, 0), "TEN!", 1.2)
				if v then
					play(v, "HitHeavy")
				end
			end
			if isNear then
				CFX.shake(i == T.Reps and 0.8 or 0.2)
			end
		end)
	end
	-- la barre de 1000 LB
	local bar, conn
	at(d, T.Bar, function()
		local cr = rootOf(c)
		-- contre-plongée héroïque
		local cp = cr and cr.Position or (V0 - dir * 3.2)
		KK.shot(d, "fixed", { pos = cp + dir * 10.5 + rt * 3 + Vector3.new(0, -1.5, 0), lookAt = cp + Vector3.new(0, 3, 0), fov = 66 })
		bar = buildBarbell(cr and cr.CFrame or CFrame.new(V0))
		conn = keep(d, holdBar(c, bar))
		play(c, "FitUltLift")
		snd(SND.Clank2, V0, 1)
		snd(SND.Riser, V0, 0.6, 1.3)
		for _, part in ipairs(bar.parts) do
			local sz = part.Size
			part.Size = sz * 0.2
			tw(part, 0.2, { Size = sz }, Enum.EasingStyle.Back)
		end
		if cr then
			CFX.pillar(cr.Position, 3, 14, LIME, 0.4)
			CFX.shockwave(Kit.ground(cr.Position) + Vector3.new(0, 0.2, 0), 7, LIME)
		end
	end)
	at(d, T.Press, function()
		snd(SND.Cheer, V0, 1.3)
		local cr = rootOf(c)
		if cr then
			CFX.cracks(Kit.ground(cr.Position), 6, 4)
			label(cr.Position + Vector3.new(0, 8, 0), "LIGHTWEIGHT BABY!", GOLD, 4, 1.1, 1)
			for _ = 1, 5 do
				puff(cr.Position + Vector3.new(rng:NextNumber(-1, 1), 1.5, rng:NextNumber(-1, 1)), 0.35, 0.5, -1.2, SWEAT)
			end
			CFX.light(cr.Position + Vector3.new(0, 5, 0), LIME, 22, 4, 0.6)
		end
		if isNear then
			CFX.shake(0.5)
		end
	end)
	at(d, T.Jump, function()
		KK.shot(d, "track", { from = base + rt * 15 - dir * 2 + Vector3.new(0, 3, 0), at = c, fov = 62 })
		snd("Whoosh", V0, 1, 0.8)
		if isNear then
			CFX.speedLines(0.35, LIME)
		end
	end)
	at(d, T.Slam - 0.12, function()
		play(c, "FitUltSlam")
		CFX.bigTelegraph(Kit.ground(V1), 9, 0.12, LIME)
	end)
	-- ÉCRASEMENT
	at(d, T.Slam, function()
		if conn then
			conn:Disconnect()
		end
		local g = Kit.ground(V1)
		KK.shot(d, "orbit", { at = g + Vector3.new(0, 1, 0), r0 = 11, r1 = 25, dur = 0.6, height = 10, angle = 120, speed = 22, basis = CFrame.lookAt(Vector3.zero, dir), fov = 70 })
		if bar then
			bar:set(CFrame.fromMatrix(g + Vector3.new(0, 1.8, 0), bar.cf.RightVector, Vector3.yAxis))
		end
		snd(SND.Clank, g, 1.5)
		snd(SND.Boom, g, 1.4)
		snd(SND.Bass, g, 1.6)
		snd("GroundSlam", g, 1.3)
		CFX.quake(g, 18, LIME, 1.6)
		blast(g + Vector3.new(0, 1, 0), 2, 18, LIME, 0.35, 0.1)
		blast(g + Vector3.new(0, 1, 0), 1, 9, WHITE, 0.15, 0)
		local crater = fxPart({ Shape = CYL, Size = Vector3.new(0.12, 14, 14), CFrame = CFrame.new(g + Vector3.new(0, 0.06, 0)) * UP, Color = Color3.fromRGB(40, 40, 46), Transparency = 0.05 })
		local rim = fxPart({ Shape = CYL, Size = Vector3.new(0.6, 16, 16), CFrame = CFrame.new(g + Vector3.new(0, 0.02, 0)) * UP, Color = Color3.fromRGB(110, 110, 118), Transparency = 0.1 })
		for k = 1, 8 do -- blocs de dalle soulevés autour du cratère
			local a = k / 8 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local o = Vector3.new(math.cos(a), 0, math.sin(a))
			local slab = fxPart({ Size = Vector3.new(3, 0.6, 2.2), CFrame = CFrame.lookAt(g + o * 7.5, g + o * 9) * CFrame.Angles(0.5, 0, 0) + Vector3.new(0, 0.5, 0), Color = Color3.fromRGB(130, 130, 138) })
			task.delay(1.5, function()
				tw(slab, 0.5, { Transparency = 1 })
			end)
			Debris:AddItem(slab, 2.05)
		end
		for _, p in ipairs({ crater, rim }) do
			task.delay(1.6, function()
				tw(p, 0.5, { Transparency = 1 })
			end)
			Debris:AddItem(p, 2.15)
		end
		CFX.debris(g, 12, { Color3.fromRGB(150, 150, 158), LIME }, 1.4, 1.2)
		CFX.light(g + Vector3.new(0, 3, 0), LIME, 40, 7, 0.5)
		word(g + Vector3.new(0, 4, 0), "NEW PR!", 1.8)
		label(g + Vector3.new(0, 8, 0), "MAXIMUM REP", GOLD, 5, 1.6, 2)
		task.delay(0.15, function()
			snd(SND.Cheer2, g, 1.2)
			snd(SND.Bell, g, 0.9)
		end)
		if isNear then
			KK.impactFrames("WBWB", 0.045)
			CFX.shake(1.7)
		end
	end)
	at(d, T.End - 0.05, function()
		KK.release(d)
	end)
	at(d, T.Slam + 0.5, function()
		play(c, "FitUltFlex")
		if bar then
			bar:fade(0.5)
		end
	end)
end

-- attaque : charge à l'épaule
local function clientDash(K, d)
	local c = d.caster
	play(c, "FitUltCharge")
	local r = rootOf(c)
	snd("Dash", r and r.Position, 1)
	snd("Whistle", r and r.Position, 0.7)
	for i = 0, 6 do
		at(d, i * 0.06, function()
			local rr = rootOf(c)
			if rr then
				K.streak(rr.Position - rr.CFrame.LookVector * 3.5, rr.Position, LIME, 0.6, 0.2)
				K.dust(rr.Position - Vector3.new(0, 2.6, 0), 3, nil, 3)
			end
		end)
	end
	if K.isCaster(d) then
		K.speedLines(0.4, LIME)
	end
end

local function client(K, d)
	KK, CFX, CUR = K, K.CFX, d
	if d.phase == "Cutin" then
		local r = rootOf(d.caster)
		snd(SND.Bell, r and r.Position, 0.6, 1.1)
	elseif d.phase == "Dash" then
		clientDash(K, d)
	elseif d.phase == "Whiff" then
		clientWhiff(K, d)
	elseif d.phase == "Hit" then
		clientHit(K, d)
	elseif d.phase == "End" then
		finishSeq(d)
	end
end

return {
	Name = "Maximum Rep",
	Desc = "A ten-rep punch rush, then a 1000 LB barbell pressed overhead and slammed down for a NEW PR.",
	Color = LIME,
	Color2 = GOLD,
	Range = 25,
	Angle = 70,
	Startup = 1.0,
	Server = server,
	Client = client,
}
