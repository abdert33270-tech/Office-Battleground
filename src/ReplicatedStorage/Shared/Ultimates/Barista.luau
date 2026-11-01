--[[
	Ultimate du Barista : ZERO-SECOND ESPRESSO
	Il descend un triple espresso cul sec : le monde passe en sépia, la victime reste figée en l'air.
	Blitz caféiné : 8 « téléportations » autour de la victime (une image rémanente figée à chaque fois + un coup),
	puis il réapparaît dans son dos, de dos, et sirote... « ORDER'S READY. » ; la tasse tinte sur la soucoupe :
	toutes les images rémanentes convergent, EXPLOSION DE VAPEUR, la victime est éjectée en l'air (pluie de grains).
	Raté : il boit, file tout droit dans le vide, tremble de partout : « ...DECAF?! ».
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


local BREW = Color3.fromRGB(140, 80, 42)
local DARKC = Color3.fromRGB(62, 36, 20)
local CREAM = Color3.fromRGB(240, 222, 190)
local FOAM = Color3.fromRGB(255, 250, 240)
local CARAMEL = Color3.fromRGB(215, 145, 60)
local STEAM = Color3.fromRGB(235, 240, 245)
local WHITE = Color3.fromRGB(250, 250, 250)

local SND = {
	Slurp = "rbxassetid://9114889946",
	Sip = "rbxassetid://119577615087331",
	Riser = "rbxassetid://1837834302",
	Hiss = "rbxassetid://117580991143452",
	Hiss2 = "rbxassetid://78235728120622",
	Blink = "rbxassetid://113349194250207",
	Ting = "rbxassetid://9119933232",
	Clink = "rbxassetid://9119516524",
	Grind = "rbxassetid://9113459621",
	Boom = "rbxassetid://9114362625",
	Bass = "rbxassetid://9119388384",
	GlassBoom = "rbxassetid://9114589343",
	Hit = "rbxassetid://9113573976",
}

-- timeline (secondes après le début de la séquence) — partagée serveur/client
local T = { Lift = 0.35, Blink0 = 0.5, BlinkStep = 0.14, Blinks = 8, Behind = 1.7, Clink = 2.5, Boom = 2.66, End = 3.25 }
-- rythme v3 : temps forts ~15 % plus lents (le serveur ET le client lisent cette même table T)
do
	local PACE, COUNTS = 1.15, { bars = true, Blinks = true, Reps = true, BarrageN = true, Whips = true }
	local function pace(t)
		for k, v in pairs(t) do
			if type(v) == "number" and not COUNTS[k] then
				t[k] = v * PACE
			elseif type(v) == "table" then
				pace(v)
			end
		end
	end
	pace(T)
end
-- base 27 (+ 2 ou 3 « Extra Shot » du passif = 35..39 au total)
local DMG = { First = 2, Blink = 1.5, Final = 13, Splash = 10, SplashR = 11 }

-- animations uniques (format ProcAnim)
local ANIMS = {
	BarUltChug = { -- cul sec : tête en arrière, tasse au ciel, puis tremblement caféiné
		{ t = 0 },
		{ t = 0.08, RS = { p = 2.9, y = 0.9 }, LS = { p = 0.2, r = -0.6 }, RJ = { ln = -0.55 }, RH = { p = -0.1 }, LH = { p = 0.2 } },
		{ t = 0.22, RS = { p = 3.1, y = 0.9 }, LS = { p = 0.3, r = -0.7 }, RJ = { ln = -0.7 }, RH = { p = -0.1 }, LH = { p = 0.2 } },
		{ t = 0.26, RS = { p = 0.9, r = -0.9 }, LS = { p = 0.9, r = -0.9 }, RJ = { ln = 0.45, sd = 0.1 }, RH = { p = 0.6, r = -0.3 }, LH = { p = 0.6, r = -0.3 } },
		{ t = 0.3, RS = { p = 1.0, r = -1.0 }, LS = { p = 0.8, r = -0.8 }, RJ = { ln = 0.5, sd = -0.12 }, RH = { p = 0.65, r = -0.3 }, LH = { p = 0.55, r = -0.3 } },
		{ t = 0.34, RS = { p = 0.9, r = -0.9 }, LS = { p = 0.9, r = -1.0 }, RJ = { ln = 0.45, sd = 0.12 }, RH = { p = 0.6, r = -0.3 }, LH = { p = 0.6, r = -0.3 } },
		{ t = 0.42 },
	},
	BarUltStrikeA = { -- revers portafilter de droite à gauche
		{ t = 0 },
		{ t = 0.04, RS = { p = 1.3, y = 1.4, r = 0.3 }, RJ = { tw = 0.9, ln = 0.2 }, RH = { p = 0.5 }, LH = { p = -0.3 } },
		{ t = 0.08, RS = { p = 1.6, y = -1.3, r = -0.7 }, LS = { p = -0.5, r = -0.4 }, RJ = { tw = -1.0, ln = 0.35 }, RH = { p = -0.5 }, LH = { p = 0.8 } },
		{ t = 0.14 },
	},
	BarUltStrikeB = { -- genou volant + coude
		{ t = 0 },
		{ t = 0.04, RH = { p = 1.6 }, LH = { p = -0.4 }, RS = { p = 1.8, y = 1.2, r = 0.4 }, LS = { p = -0.6 }, RJ = { ln = -0.2, tw = 0.4 } },
		{ t = 0.14 },
	},
	BarUltStrikeC = { -- marteau à deux mains par-dessus
		{ t = 0 },
		{ t = 0.03, RS = { p = 3.3 }, LS = { p = 3.3 }, RJ = { ln = -0.4 } },
		{ t = 0.08, RS = { p = 0.8, y = 0.3 }, LS = { p = 0.8, y = 0.3 }, RJ = { ln = 0.9 }, RH = { p = 1.0 }, LH = { p = -0.4 } },
		{ t = 0.14 },
	},
	BarUltStrikeD = { -- coup de pied retourné
		{ t = 0 },
		{ t = 0.04, RJ = { tw = -1.2, ln = -0.3, sd = -0.25 }, LH = { p = 1.9, r = -0.4 }, RS = { p = 0.4, r = -1.3 }, LS = { p = 0.4, r = -1.3 } },
		{ t = 0.14 },
	},
	BarUltSip = { -- de dos, main sur la hanche, tasse portée lentement aux lèvres
		{ t = 0 },
		{ t = 0.25, RS = { p = 1.5, y = 0.8 }, LS = { p = 0.35, r = -0.75 }, RJ = { ln = -0.05, tw = 0.15 }, LH = { p = 0.15, r = -0.1 } },
		{ t = 0.55, RS = { p = 2.45, y = 1.0 }, LS = { p = 0.35, r = -0.75 }, RJ = { ln = -0.25, tw = 0.15 }, LH = { p = 0.15, r = -0.1 } },
		{ t = 0.75, RS = { p = 2.5, y = 1.0 }, LS = { p = 0.35, r = -0.75 }, RJ = { ln = -0.3, tw = 0.15 }, LH = { p = 0.15, r = -0.1 } },
		{ t = 0.85, RS = { p = 1.35, y = 0.7 }, LS = { p = 1.1, y = 0.9 }, RJ = { ln = 0.05 }, LH = { p = 0.1 } }, -- repose la tasse sur la soucoupe
		{ t = 1.4, RS = { p = 1.3, y = 0.7 }, LS = { p = 1.1, y = 0.9 }, RJ = { ln = 0.0 }, LH = { p = 0.1 } },
		{ t = 1.6 },
	},
	BarUltDecaf = { -- raté : tremblote, bras ballants
		{ t = 0 },
		{ t = 0.06, RS = { p = 0.4, r = -0.5 }, LS = { p = 0.4, r = -0.5 }, RJ = { ln = 0.35, sd = 0.2 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.12, RS = { p = 0.5, r = -0.4 }, LS = { p = 0.3, r = -0.6 }, RJ = { ln = 0.35, sd = -0.2 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
		{ t = 0.18, RS = { p = 0.4, r = -0.5 }, LS = { p = 0.4, r = -0.5 }, RJ = { ln = 0.35, sd = 0.2 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.24, RS = { p = 0.5, r = -0.4 }, LS = { p = 0.3, r = -0.6 }, RJ = { ln = 0.35, sd = -0.2 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
		{ t = 0.4, RS = { p = 0.2, r = -0.2 }, LS = { p = 0.2, r = -0.2 }, RJ = { ln = 0.6 } },
		{ t = 0.6 },
	},
}
local STRIKES = { "BarUltStrikeA", "BarUltStrikeB", "BarUltStrikeC", "BarUltStrikeD" }

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
	-- attaque : il disparaît et réapparaît collé à la cible
	U.fx(ctx, "Dash")
	if not target or not U.rush(ctx, target, { speed = 210, contact = 4, maxTime = 0.3, whiffDist = 14, whiffTime = 0.16 }) then
		cr = U.root(caster)
		if cr then
			U.fx(ctx, "Whiff", { p = cr.Position, dir = U.flat(cr.CFrame.LookVector) })
		end
		U.wait(ctx, 0.8)
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
	local Vair = V0 + Vector3.new(0, 3.2, 0)
	U.hold(ctx, target, CFrame.lookAt(V0, V0 - dir))
	U.place(ctx, caster, CFrame.lookAt(V0 - dir * 4, V0))
	-- positions des 8 téléportations (autour de la victime, hauteurs alternées)
	local blinks = {}
	for i = 1, T.Blinks do
		local off = (CFrame.lookAt(Vector3.zero, -dir) * CFrame.Angles(0, math.rad(i * 137.5), 0)).LookVector * 4.2
		table.insert(blinks, Vair + off + Vector3.new(0, (i % 2 == 0) and 1.6 or -1.2, 0))
	end
	local behind = Kit.safePoint(V0, V0 + dir * 9, 2)
	U.fx(ctx, "Hit", { base = base, dir = dir, vair = Vair, blinks = blinks, behind = behind })
	local ev = {
		{ T.Lift, function()
			U.glide(ctx, target, CFrame.lookAt(Vair, Vair - dir), 0.2, "Out")
			U.hit(ctx, target, DMG.First, { words = { "TRIPLE SHOT!" } })
		end },
		{ T.Behind, function()
			U.place(ctx, caster, CFrame.lookAt(behind, behind + dir))
		end },
		{ T.Boom, function()
			U.finish(ctx, target, DMG.Final, { launch = -dir * 38 + Vector3.new(0, 92, 0), stun = 1.6, words = { "ESPRESSO!" },
				splash = { radius = DMG.SplashR, damage = DMG.Splash, center = Vair } })
		end },
		{ T.End, function() end },
	}
	for i, p in ipairs(blinks) do
		table.insert(ev, { T.Blink0 + (i - 1) * T.BlinkStep, function()
			U.place(ctx, caster, CFrame.lookAt(p, Vair))
			U.hit(ctx, target, DMG.Blink, { words = { ({ "SHOT!", "TAP!", "BREW!", "JOLT!" })[(i - 1) % 4 + 1] } })
		end })
	end
	run(U, ctx, ev)
end

------------------------------------------------------------------------
-- CLIENT
------------------------------------------------------------------------
local BODY = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
-- image rémanente figée du caster (pose actuelle), placée au repère cf
local function ghost(c, cf, color, transp)
	local r = rootOf(c)
	if not r then
		return {}
	end
	local parts = {}
	for _, n in ipairs(BODY) do
		local b = c:FindFirstChild(n)
		if b then
			local g = fxPart({ Size = b.Size * 1.02, CFrame = cf * r.CFrame:ToObjectSpace(b.CFrame), Color = color, Transparency = transp or 0.45, Material = Enum.Material.Neon })
			table.insert(parts, g)
		end
	end
	return parts
end

local function clientWhiff(K, d)
	local c = d.caster
	snd(SND.Slurp, d.p, 1, 1.3)
	d.from = d.p - d.dir * 12
	d.to = d.p
	at(d, 0.05, function()
		snd(SND.Blink, d.from, 1, 1.2)
		for i = 1, 3 do
			local p = d.from:Lerp(d.to, i / 4)
			local gs = ghost(c, CFrame.lookAt(p, p + d.dir), CARAMEL, 0.5)
			for _, g in ipairs(gs) do
				tw(g, 0.5, { Transparency = 1 })
				Debris:AddItem(g, 0.55)
			end
		end
		CFX.speedLines(0.3, CREAM)
	end)
	at(d, 0.15, function()
		play(c, "BarUltDecaf")
		local r = rootOf(c)
		local p = r and r.Position or d.to
		snd(SND.Grind, p, 0.7, 0.55)
		snd(SND.Hiss2, p, 0.6, 0.8)
		for i = 1, 6 do
			puff(p + Vector3.new(rng:NextNumber(-1.5, 1.5), rng:NextNumber(0, 2), rng:NextNumber(-1.5, 1.5)), 0.8, 0.6, 2, i % 2 == 0 and CARAMEL or STEAM)
		end
		label(p + Vector3.new(0, 4, 0), "...DECAF?!", CARAMEL, 3.5, 1.1, 1.5)
	end)
end

local function clientHit(K, d)
	local c, v = d.caster, d.target
	local vair, dir, base = d.vair, d.dir, d.base
	local isNear = near(d, d.base)
	KK.letterbox(d, true)
	KK.impactFrames("BWB", 0.04)
	local ghosts = {}
	-- 0 : cul sec + monde sépia (gros plan sur le visage)
	play(c, "BarUltChug")
	KK.shot(d, "follow", { subject = c, offset = CFrame.new(1.2, 1.4, -5.5), lookOffset = Vector3.new(0, 1.3, 0), fov = 45, flat = true })
	snd(SND.Slurp, vair, 1.2)
	snd(SND.Riser, vair, 0.7, 1.15)
	if isNear then
		tint(d, { TintColor = Color3.fromRGB(255, 214, 160), Saturation = -0.55, Contrast = 0.15 }, T.Boom - 0.05, 0.25, 0.1)
	end
	local cr = rootOf(c)
	if cr then
		for i = 1, 8 do
			puff(cr.Position + Vector3.new(rng:NextNumber(-1, 1), 2 + rng:NextNumber(0, 1), rng:NextNumber(-1, 1)), 0.9, 0.7, 3, i % 3 == 0 and CARAMEL or STEAM)
		end
		label(cr.Position + Vector3.new(0, 4.5, 0), "TRIPLE SHOT!", CARAMEL, 3.2, 0.9, 1.5)
	end
	-- la victime est figée en l'air
	at(d, T.Blink0 - 0.06, function()
		KK.shot(d, "orbit", { at = vair, radius = 13, height = 2.5, angle = 30, speed = 150, basis = CFrame.lookAt(Vector3.zero, dir), fov = 68 })
		KK.speedLines(1.1, CREAM)
	end)
	at(d, T.Lift, function()
		snd(SND.Hiss, vair, 0.9, 1.3)
		CFX.sparks(vair, 16, CARAMEL)
		ring(vair, CFrame.new(base + Vector3.new(0, 0.2, 0)) * UP, 2, 12, CREAM, 0.35)
		if v then
			play(v, "HitHeavy")
		end
	end)
	-- blitz : 8 téléportations
	for i, p in ipairs(d.blinks) do
		at(d, T.Blink0 + (i - 1) * T.BlinkStep, function()
			play(c, STRIKES[(i - 1) % 4 + 1])
			snd(SND.Blink, p, 0.8, 1 + i * 0.07)
			snd(SND.Hit, vair, 1, 0.9 + i * 0.05)
			-- trait de taillade qui traverse la victime
			local a = CFrame.lookAt(p, vair)
			local slash = fxPart({ Size = Vector3.new(0.25, 0.25, 9), CFrame = a * CFrame.new(0, 0, -4.2) * CFrame.Angles(0, 0, rng:NextNumber(0, 3)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), 0, 0), Color = WHITE, Transparency = 0.05 })
			tw(slash, 0.18, { Size = Vector3.new(0.05, 0.05, 12), Transparency = 1 })
			Debris:AddItem(slash, 0.2)
			CFX.sparks(vair, 8, i % 2 == 0 and CARAMEL or WHITE)
			CFX.airRing(vair, (vair - p), 6, CREAM, 0.2)
			if i % 3 == 0 then
				word(vair + Vector3.new(0, 2, 0), ({ "SHOT!", "BREW!", "JOLT!" })[i / 3], 0.8)
			end
			if v then
				play(v, i % 2 == 0 and "HitLight" or "HitLight2")
			end
			-- image rémanente qui reste figée jusqu'au tintement
			task.delay(0.07, function()
				for _, g in ipairs(ghost(c, CFrame.lookAt(p, vair), i % 2 == 0 and CARAMEL or BREW, 0.55)) do
					table.insert(ghosts, g)
				end
			end)
			if isNear then
				CFX.shake(0.25)
			end
		end)
	end
	-- de dos, il sirote
	local cup
	at(d, T.Behind, function()
		-- plan bas : son visage au premier plan, la victime figée derrière lui
		local rt = dir:Cross(Vector3.yAxis)
		KK.shot(d, "fixed", { pos = d.behind + dir * 5 + rt * 1.6 + Vector3.new(0, 0.6, 0), lookAt = d.behind:Lerp(vair, 0.35) + Vector3.new(0, 1.2, 0), fov = 50 })
		play(c, "BarUltSip")
		snd(SND.Blink, d.behind, 0.9, 0.8)
		cup = fxPart({ Shape = CYL, Size = Vector3.new(0.7, 0.75, 0.75), Color = WHITE })
		local saucer = fxPart({ Shape = CYL, Size = Vector3.new(0.1, 1.3, 1.3), Color = WHITE })
		local coffee = fxPart({ Shape = CYL, Size = Vector3.new(0.05, 0.6, 0.6), Color = DARKC })
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local ra, la = c:FindFirstChild("Right Arm"), c:FindFirstChild("Left Arm")
			if os.clock() - t0 > 1.15 or not ra or not cup.Parent then
				conn:Disconnect()
				cup:Destroy()
				saucer:Destroy()
				coffee:Destroy()
				return
			end
			local h = ra.CFrame * CFrame.new(0, -1.25, -0.2)
			cup.CFrame = CFrame.new(h.Position) * UP
			coffee.CFrame = CFrame.new(h.Position + Vector3.new(0, 0.36, 0)) * UP
			if la then
				saucer.CFrame = CFrame.new((la.CFrame * CFrame.new(0, -1.15, -0.2)).Position) * UP
			end
			if rng:NextNumber() < 0.25 then
				puff(h.Position + Vector3.new(0, 0.6, 0), 0.3, 0.6, 1.5)
			end
		end)
		keep(d, conn)
		label(d.behind + Vector3.new(0, 4.2, 0), "...ORDER'S READY.", CREAM, 3.4, 1.3, 1)
	end)
	at(d, T.Behind + 0.55, function()
		snd(SND.Sip, d.behind, 1.1)
	end)
	-- tintement : toutes les images rémanentes convergent
	at(d, T.Clink, function()
		local rt = dir:Cross(Vector3.yAxis)
		KK.shot(d, "dolly", { from = CFrame.lookAt(vair + rt * 14 + Vector3.new(0, 2, 0), vair), to = CFrame.lookAt(vair + rt * 7 + Vector3.new(0, 1, 0), vair), dur = 0.16, fov0 = 60, fov1 = 50 })
		snd(SND.Ting, d.behind, 1.3)
		snd(SND.Clink, d.behind, 1)
		for i, g in ipairs(ghosts) do
			if g.Parent then
				if i % 6 == 2 then
					CFX.beam(g.Position, vair, 0.35, CARAMEL, 0.2)
				end
				tw(g, 0.14, { CFrame = CFrame.new(vair) * (g.CFrame - g.Position), Size = g.Size * 0.4, Transparency = 0.2 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				Debris:AddItem(g, 0.16)
			end
		end
		CFX.implode(vair, 9, { CARAMEL, CREAM, WHITE }, 14, 0.15)
	end)
	-- EXPLOSION DE VAPEUR
	at(d, T.Boom, function()
		KK.shot(d, "orbit", { at = vair, r0 = 9, r1 = 24, dur = 0.6, height = 5, angle = 70, speed = 25, basis = CFrame.lookAt(Vector3.zero, dir), fov = 70 })
		snd(SND.Boom, vair, 1.4)
		snd(SND.Bass, vair, 1.5)
		snd(SND.GlassBoom, vair, 0.7, 1.2)
		snd(SND.Hiss, vair, 1.2, 0.8)
		blast(vair, 2, 24, BREW, 0.45, 0.05)
		blast(vair, 2, 17, CREAM, 0.35, 0)
		blast(vair, 1, 10, WHITE, 0.18, 0)
		CFX.bigImpact(vair, Vector3.new(0, 1, 0), 1.6, CARAMEL)
		CFX.shockwave(base + Vector3.new(0, 0.2, 0), 20, BREW)
		task.delay(0.08, function()
			CFX.shockwave(base + Vector3.new(0, 0.3, 0), 28, CREAM)
		end)
		ring(vair, CFrame.lookAt(vair, vair + dir) * CFrame.Angles(0, math.pi / 2, 0), 3, 22, CARAMEL, 0.4, 0.6)
		CFX.pillar(base, 4, 34, CREAM, 0.6)
		CFX.light(vair, CARAMEL, 40, 8, 0.5)
		CFX.debris(vair, 14, { BREW, DARKC, CARAMEL }, 1.3, 0.7)
		for i = 1, 14 do
			local a = i / 14 * math.pi * 2
			local o = Vector3.new(math.cos(a), 0, math.sin(a))
			local b = ball(base + o * 2 + Vector3.new(0, 1, 0), 2.4, i % 3 == 0 and CARAMEL or STEAM, 0.15)
			tw(b, 0.7, { Position = base + o * 15 + Vector3.new(0, rng:NextNumber(1, 4), 0), Size = Vector3.one * 6, Transparency = 1 })
			Debris:AddItem(b, 0.75)
		end
		word(vair + Vector3.new(0, 3, 0), "ESPRESSO!", 1.7)
		label(vair + Vector3.new(0, 6, 0), "ZERO-SECOND ESPRESSO", CARAMEL, 5, 1.6, 2)
		if isNear then
			KK.impactFrames("WBWB", 0.045)
			CFX.shake(1.6)
		end
	end)
	at(d, T.End - 0.1, function()
		KK.release(d)
	end)
	-- pluie de grains de café
	at(d, T.Boom + 0.35, function()
		for _ = 1, 12 do
			local p = base + Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(10, 16), rng:NextNumber(-10, 10))
			local bean = fxPart({ Shape = BALL, Size = Vector3.new(0.7, 0.5, 0.9), Position = p, Color = DARKC })
			tw(bean, 0.7, { Position = Vector3.new(p.X, base.Y + 0.3, p.Z), Transparency = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(bean, 0.72)
		end
	end)
end

-- attaque : il disparaît, traînée d'images rémanentes jusqu'à la cible
local function clientDash(K, d)
	local c = d.caster
	play(c, "BarUltChug", 2.2)
	snd(SND.Blink, rootOf(c) and rootOf(c).Position, 1, 1.1)
	snd(SND.Slurp, rootOf(c) and rootOf(c).Position, 0.8, 1.4)
	for i = 0, 6 do
		at(d, i * 0.045, function()
			K.afterimage(c, i % 2 == 0 and CARAMEL or BREW, 0.35, 0.4)
		end)
	end
	if K.isCaster(d) then
		K.speedLines(0.35, CREAM)
	end
end

local function client(K, d)
	KK, CFX, CUR = K, K.CFX, d
	if d.phase == "Cutin" then
		-- pendant le cut-in : la vapeur s'échappe de son gobelet-chapeau
		local head = d.caster and d.caster:FindFirstChild("Head")
		if head then
			for i = 1, 10 do
				at(d, i * 0.07, function()
					puff(head.Position + Vector3.new(rng:NextNumber(-0.5, 0.5), 3.2, rng:NextNumber(-0.5, 0.5)), 0.8, 0.8, 3, i % 3 == 0 and CARAMEL or STEAM)
				end)
			end
			snd(SND.Hiss2, head.Position, 0.7, 1.1)
		end
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
	Name = "Zero-Second Espresso",
	-- v3 : titres de temps forts (UltimateController) ; Anticipate = poses d'armement avant ces coups
	Beats = { Hit = { { 0, "TRIPLE SHOT" }, { T.Blink0, "ESPRESSO BLITZ" }, { T.Behind, "ORDER'S READY" } } },
	Desc = "Chug a triple shot, blitz the target from 8 angles in zero seconds, sip... then everything hits at once.",
	Color = CARAMEL,
	Color2 = CREAM,
	Range = 26,
	Angle = 70,
	Startup = 1.0,
	Server = server,
	Client = client,
}
