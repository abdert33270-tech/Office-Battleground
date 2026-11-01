--[[
	Ultimate de la Receptionist : OUT OF OFFICE
	Huit téléphones qui sonnent apparaissent en cercle autour de la victime, soulevée ; 5 coups de fouet avec le fil du
	combiné (arcs roses croisés) ; 8 fils jaillissent des téléphones et ligotent la victime, elle tire : tous les
	téléphones s'écrasent dessus en même temps ; « WE'RE CLOSED! » : hurlement sonique, la victime est projetée en l'air
	puis retombe : PLAQUÉE au sol, cratère, et un panneau CLOSED planté à côté.
	Raté : elle décroche, « WRONG NUMBER! », et jette le combiné.
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
local FUCHSIA = Color3.fromRGB(235, 60, 170)
local PINKL = Color3.fromRGB(255, 170, 220)
local PHONE = Color3.fromRGB(45, 42, 52)
local WHITE = Color3.fromRGB(250, 250, 250)
local REDC = Color3.fromRGB(220, 30, 40)
local VIOLET = Color3.fromRGB(150, 110, 255)

local SND = {
	Ring = "rbxassetid://9117305740",
	Ring2 = "rbxassetid://130006548046091",
	Slam = "rbxassetid://9126096095",
	Slam2 = "rbxassetid://9126096220",
	Sonic = "rbxassetid://100261872009811",
	Crack = "rbxassetid://5689401424",
	Whip = "rbxassetid://113349194250207",
	Boom = "rbxassetid://9114362625",
	Bass = "rbxassetid://9119388384",
	Riser = "rbxassetid://1837834302",
}

local T = { Phones = 0.05, Whip0 = 0.5, WhipStep = 0.2, Whips = 5, Web = 1.6, Yank = 1.95, Scream = 2.3, Crash = 2.95, End = 3.4 }
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
-- base 34.5 (+15 % du passif Visitor Badge sur les coups suivants = ~38.5)
local DMG = { Lift = 3, Whip = 2.5, Yank = 5.5, Scream = 4, Final = 9.5, Splash = 10, SplashR = 11 }

local ANIMS = {
	RecUltPoint = { -- montre la victime du doigt, l'autre main sur la hanche
		{ t = 0 },
		{ t = 0.1, RS = { p = 1.7, y = 0.1 }, LS = { p = 0.35, r = -0.75 }, RJ = { tw = 0.3, ln = 0.05 }, LH = { p = 0.2 } },
		{ t = 0.4, RS = { p = 1.65, y = 0.1 }, LS = { p = 0.35, r = -0.75 }, RJ = { tw = 0.3 }, LH = { p = 0.2 } },
		{ t = 0.5 },
	},
	RecUltWhip = (function() -- 5 coups de fouet en diagonale, alternés
		local f = { { t = 0 } }
		for i = 1, 5 do
			local s = (i % 2 == 1) and 1 or -1
			local t0 = (i - 1) * 0.2
			table.insert(f, { t = t0 + 0.07, RS = { p = 3.2, y = 0.9 * s, r = -0.3 }, LS = { p = 0.6, r = -0.5 }, RJ = { tw = -0.6 * s, ln = -0.3 }, RH = { p = 0.3 * s }, LH = { p = -0.3 * s } })
			table.insert(f, { t = t0 + 0.15, RS = { p = 0.9, y = -0.9 * s, r = -0.4 }, LS = { p = 0.4, r = -0.6 }, RJ = { tw = 0.7 * s, ln = 0.45 }, RH = { p = -0.4 * s }, LH = { p = 0.5 * s } })
		end
		table.insert(f, { t = 1.1 })
		return f
	end)(),
	RecUltYank = { -- saisit les fils à deux mains et tire de tout son poids en arrière
		{ t = 0 },
		{ t = 0.12, RS = { p = 1.8, y = 0.4 }, LS = { p = 1.8, y = 0.4 }, RJ = { ln = 0.4 }, RH = { p = -0.3 }, LH = { p = 0.6 } },
		{ t = 0.22, RS = { p = 0.6, r = -0.3 }, LS = { p = 0.6, r = -0.3 }, RJ = { ln = -0.55 }, RH = { p = 0.8 }, LH = { p = -0.4 } },
		{ t = 0.34, RS = { p = 0.5, r = -0.3 }, LS = { p = 0.5, r = -0.3 }, RJ = { ln = -0.5 }, RH = { p = 0.7 }, LH = { p = -0.35 } },
		{ t = 0.4 },
	},
	RecUltScream = { -- se cambre (inspiration), puis hurle penchée en avant, bras écartés, poings serrés
		{ t = 0 },
		{ t = 0.18, RS = { p = -0.4, r = -0.6 }, LS = { p = -0.4, r = -0.6 }, RJ = { ln = -0.55 }, RH = { p = -0.2 }, LH = { p = 0.25 } },
		{ t = 0.26, RS = { p = 0.9, r = -1.45 }, LS = { p = 0.9, r = -1.45 }, RJ = { ln = 0.6 }, RH = { p = -0.55, r = -0.3 }, LH = { p = 0.65, r = -0.3 } },
		{ t = 0.33, RS = { p = 1.0, r = -1.5 }, LS = { p = 0.8, r = -1.4 }, RJ = { ln = 0.62, sd = 0.08 }, RH = { p = -0.55, r = -0.3 }, LH = { p = 0.65, r = -0.3 } },
		{ t = 0.4, RS = { p = 0.8, r = -1.4 }, LS = { p = 1.0, r = -1.5 }, RJ = { ln = 0.62, sd = -0.08 }, RH = { p = -0.55, r = -0.3 }, LH = { p = 0.65, r = -0.3 } },
		{ t = 0.62, RS = { p = 0.9, r = -1.4 }, LS = { p = 0.9, r = -1.4 }, RJ = { ln = 0.55 }, RH = { p = -0.5, r = -0.3 }, LH = { p = 0.6, r = -0.3 } },
		{ t = 0.75 },
	},
	RecUltGlasses = { -- remonte ses lunettes, déhanché satisfait
		{ t = 0 },
		{ t = 0.15, RS = { p = 2.75, y = 1.35 }, LS = { p = 0.35, r = -0.75 }, RJ = { sd = 0.15, tw = -0.2 }, RH = { r = -0.15 }, LH = { p = 0.2 } },
		{ t = 0.6, RS = { p = 2.7, y = 1.3 }, LS = { p = 0.35, r = -0.75 }, RJ = { sd = 0.18, tw = -0.2 }, RH = { r = -0.15 }, LH = { p = 0.2 } },
		{ t = 0.8 },
	},
	RecUltAnswer = { -- raté : décroche, écoute, puis jette le combiné par-dessus l'épaule
		{ t = 0 },
		{ t = 0.1, RS = { p = 2.6, y = 1.3 }, RJ = { sd = 0.12 } },
		{ t = 0.35, RS = { p = 2.6, y = 1.3 }, RJ = { sd = 0.15, ln = -0.1 } },
		{ t = 0.45, RS = { p = 3.2, r = -0.4 }, RJ = { tw = -0.6, ln = -0.2 }, LH = { p = 0.4 } },
		{ t = 0.55, RS = { p = 1.1, y = 0.3 }, RJ = { tw = 0.7, ln = 0.3 }, LH = { p = 0.6 }, RH = { p = -0.3 } },
		{ t = 0.75 },
	},
	RecUltLasso = { -- lance le combiné au bout du fil, bras tendu
		{ t = 0 },
		{ t = 0.08, RS = { p = 3.0, r = -0.4 }, RJ = { tw = -0.5, ln = -0.15 }, LS = { p = 0.6 }, LH = { p = 0.4 } },
		{ t = 0.15, RS = { p = 1.65, y = 0.1 }, RJ = { tw = 0.4, ln = 0.25 }, LS = { p = -0.3 }, LH = { p = 0.6 }, RH = { p = -0.35 } },
		{ t = 0.4, RS = { p = 1.6, y = 0.1 }, RJ = { tw = 0.35, ln = 0.2 }, LS = { p = -0.3 }, LH = { p = 0.5 } },
		{ t = 0.5 },
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
	-- attaque : elle lance le combiné au bout de son fil
	local tr = target and U.root(target)
	U.fx(ctx, "Lasso", { to = tr and tr.Position or (cr.Position + U.flat(cr.CFrame.LookVector) * 18) })
	if not U.wait(ctx, 0.22) then
		return
	end
	tr = target and U.valid(target, ctx) and U.root(target)
	if not tr or (tr.Position - cr.Position).Magnitude > (ctx.range or 25) + 6 then
		U.fx(ctx, "Whiff", { base = U.ground(cr.Position), dir = U.flat(cr.CFrame.LookVector) })
		U.wait(ctx, 0.85)
		return
	end
	local dir = U.flat(tr.Position - cr.Position, cr.CFrame.LookVector)
	local base = U.ground(tr.Position)
	local V0 = base + Vector3.new(0, 3, 0)
	local Vup = V0 + Vector3.new(0, 2.5, 0)
	local Vsky = V0 + Vector3.new(0, math.min(16, (U.headroom(V0, 16) or 16) - 1), 0)
	local C0 = Kit.safePoint(V0, V0 - dir * 7, 1.5)
	U.hold(ctx, target, CFrame.lookAt(V0, V0 - dir))
	U.place(ctx, caster, CFrame.lookAt(C0, Vector3.new(V0.X, C0.Y, V0.Z)))
	U.fx(ctx, "Hit", { base = base, dir = dir, vup = Vup, vsky = Vsky, c0 = C0 })
	local ev = {
		{ T.Phones + 0.1, function()
			U.glide(ctx, target, CFrame.lookAt(Vup, Vup - dir), 0.3)
			U.hit(ctx, target, DMG.Lift, { words = { "RING RING!" } })
		end },
		{ T.Yank + 0.1, function()
			U.hit(ctx, target, DMG.Yank, { words = { "HOLD THE LINE!" } })
		end },
		{ T.Scream + 0.22, function()
			U.hit(ctx, target, DMG.Scream, { words = { "WE'RE CLOSED!" } })
			U.glide(ctx, target, CFrame.lookAt(Vsky, Vsky - dir) * CFrame.Angles(1.2, 0, 0), 0.38, "Out")
		end },
		{ T.Crash - 0.2, function()
			U.glide(ctx, target, CFrame.lookAt(V0, V0 - dir) * CFrame.Angles(-1.4, 0, 0), 0.2, "In")
		end },
		{ T.Crash, function()
			U.finish(ctx, target, DMG.Final, { pin = true, stun = 1.6, words = { "CLOSED!" },
				splash = { radius = DMG.SplashR, damage = DMG.Splash, center = V0 } })
		end },
		{ T.End, function() end },
	}
	for i = 1, T.Whips do
		table.insert(ev, { T.Whip0 + (i - 1) * T.WhipStep + 0.08, function()
			U.hit(ctx, target, DMG.Whip, { words = { ({ "SNAP!", "CRACK!", "WHIP!" })[(i - 1) % 3 + 1] } })
		end })
	end
	run(U, ctx, ev)
end

------------------------------------------------------------------------
-- CLIENT
------------------------------------------------------------------------
-- téléphone de bureau géant (repère : centre)
local function buildPhone(cf, scale)
	local s = scale or 1
	local r = newRig(cf)
	r:add(Vector3.new(2.2, 0.9, 1.8) * s, CFrame.new(0, -0.3 * s, 0), FUCHSIA) -- socle
	r:add(Vector3.new(1.2, 0.12, 1.0) * s, CFrame.new(0, 0.17 * s, 0.1 * s), WHITE) -- clavier
	r:add(Vector3.new(2.6, 0.45, 0.55) * s, CFrame.new(0, 0.45 * s, -0.55 * s), PHONE) -- combiné
	r:add(Vector3.new(0.6, 0.55, 0.75) * s, CFrame.new(-1.05 * s, 0.55 * s, -0.55 * s), PHONE)
	r:add(Vector3.new(0.6, 0.55, 0.75) * s, CFrame.new(1.05 * s, 0.55 * s, -0.55 * s), PHONE)
	return r
end

-- panneau CLOSED planté (repère : pied au sol)
local function buildSign(cf)
	local r = newRig(cf)
	r:add(Vector3.new(0.35, 6, 0.35), CFrame.new(0, 3, 0), PHONE) -- poteau
	local board = r:add(Vector3.new(5.5, 2.2, 0.3), CFrame.new(0, 6.2, 0), REDC)
	r:text(board, "CLOSED", WHITE, Enum.NormalId.Front)
	r:text(board, "CLOSED", WHITE, Enum.NormalId.Back)
	r:add(Vector3.new(5.8, 0.2, 0.32), CFrame.new(0, 7.35, 0), WHITE)
	r:add(Vector3.new(5.8, 0.2, 0.32), CFrame.new(0, 5.05, 0), WHITE)
	local pl = Instance.new("PointLight")
	pl.Color = Color3.fromRGB(255, 60, 60)
	pl.Range = 16
	pl.Brightness = 3
	pl.Parent = board
	return r, pl
end

local function clientWhiff(K, d)
	local c = d.caster
	play(c, "RecUltAnswer")
	local r = rootOf(c)
	local p = r and r.Position or d.base
	snd(SND.Ring, p, 1)
	label(p + Vector3.new(0, 4.5, 0), "RING RING...", PINKL, 2.6, 0.5, 1)
	at(d, 0.42, function()
		snd(SND.Slam2, p, 1.2)
		label(p + Vector3.new(0, 4.5, 0), "WRONG NUMBER!", FUCHSIA, 4, 1.1, 1.5)
		local ph = fxPart({ Size = Vector3.new(0.5, 1.6, 0.5), CFrame = CFrame.new(p + Vector3.new(0, 2, 0)), Color = PHONE })
		local to = Kit.ground(p + d.dir * 9)
		tw(ph, 0.35, { CFrame = CFrame.new(to + Vector3.new(0, 0.3, 0)) * CFrame.Angles(1.5, 3, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.delay(0.35, function()
			CFX.shockwave(to + Vector3.new(0, 0.2, 0), 5, FUCHSIA)
			CFX.sparks(to, 10, PINKL)
			snd("Bonk", to, 1)
		end)
		Debris:AddItem(ph, 0.9)
		ring(p, CFrame.lookAt(p, p + d.dir) * CFrame.Angles(0, math.pi / 2, 0), 2, 9, FUCHSIA, 0.3)
	end)
end

local function clientHit(K, d)
	local c, v = d.caster, d.target
	local base, dir, vup, vsky = d.base, d.dir, d.vup, d.vsky
	local V0 = base + Vector3.new(0, 3, 0)
	local isNear = near(d, d.base)
	KK.letterbox(d, true)
	KK.impactFrames("BWB", 0.04)
	local phones = {}
	local cords = {}
	play(c, "RecUltPoint")
	local rt = dir:Cross(Vector3.yAxis)
	local C0 = d.c0 or (V0 - dir * 7)
	KK.shot(d, "orbit", { at = vup, radius = 18, height = 6, angle = 200, speed = 60, basis = CFrame.lookAt(Vector3.zero, dir), fov = 66 })
	-- 8 téléphones qui sonnent en cercle
	at(d, T.Phones, function()
		for i = 1, 8 do
			local a = i / 8 * math.pi * 2
			local p = vup + Vector3.new(math.cos(a) * 6.5, (i % 2 == 0) and 1.2 or -0.6, math.sin(a) * 6.5)
			local ph = buildPhone(CFrame.lookAt(p, vup), 1.1)
			ph.base = p
			table.insert(phones, ph)
			for _, part in ipairs(ph.parts) do
				local sz = part.Size
				part.Size = sz * 0.1
				tw(part, 0.25, { Size = sz }, Enum.EasingStyle.Back)
			end
		end
		snd(SND.Ring, vup, 1.2)
		snd(SND.Ring2, vup, 0.8, 1.1)
		label(vup + Vector3.new(0, 5, 0), "RING! RING! RING!", PINKL, 4, 1.2, 1)
	end)
	-- les téléphones vibrent en sonnant
	local t0 = os.clock()
	local shakeConn
	shakeConn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - t0
		for i, ph in ipairs(phones) do
			if ph.folder.Parent and not ph.mover and ph.base then
				local j = math.sin(el * 55 + i) * 0.12
				ph:set(CFrame.lookAt(ph.base, vup) * CFrame.new(j, math.abs(j), 0) * CFrame.Angles(0, 0, j * 2))
			end
		end
	end)
	keep(d, shakeConn)
	at(d, T.Phones + 0.1, function()
		if v then
			play(v, "HitHeavy")
		end
		for i = 1, 6 do
			task.delay(i * 0.12, function()
				label(vup + Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(0, 4), rng:NextNumber(-5, 5)), i % 2 == 0 and "RING!" or "BRRING!", i % 2 == 0 and PINKL or VIOLET, 2.2, 0.8, 2)
			end)
		end
	end)
	-- coups de fouet
	for i = 1, T.Whips do
		local tt = T.Whip0 + (i - 1) * T.WhipStep
		if i == 1 then
			at(d, tt - 0.05, function()
				play(c, "RecUltWhip")
			end)
		end
		at(d, tt, function()
			local s = (i % 2 == 1) and 1 or -1
			if s > 0 then -- par-dessus son épaule
				KK.shot(d, "fixed", { pos = C0 - dir * 3.5 + rt * 2.5 + Vector3.new(0, 2.5, 0), lookAt = vup, fov = 60 })
			else -- contre-champ côté victime
				KK.shot(d, "fixed", { pos = vup + dir * 5 + rt * 5 + Vector3.new(0, 1, 0), lookAt = vup:Lerp(C0, 0.4), fov = 62 })
			end
		end)
		at(d, tt + 0.08, function()
			local s = (i % 2 == 1) and 1 or -1
			local cr = rootOf(c)
			local hand = cr and (cr.Position + Vector3.new(0, 1.5, 0)) or C0
			CFX.beam(hand, vup, 0.25, PHONE, 0.15)
			CFX.slashArc(CFrame.lookAt(vup - dir * 2.5, vup), 3.5, FUCHSIA, -70 * s, 70 * s, 0.1, 55 * s, 0.6)
			CFX.sparks(vup, 10, PINKL)
			snd(SND.Crack, vup, 0.8, 1.2 + i * 0.05)
			snd(SND.Whip, vup, 0.6, 1.4)
			if v then
				play(v, s > 0 and "HitLight" or "HitLight2")
			end
			if isNear then
				CFX.shake(0.3)
			end
		end)
	end
	-- 8 fils ligotent la victime
	at(d, T.Web, function()
		KK.shot(d, "orbit", { at = vup, radius = 15, height = 3, angle = 0, speed = -100, basis = CFrame.lookAt(Vector3.zero, dir), fov = 62 })
		snd(SND.Whip, vup, 1, 0.8)
		for _, ph in ipairs(phones) do
			if ph.base then
				local from = ph.base
				local len = (vup - from).Magnitude
				local cord = fxPart({ Size = Vector3.new(0.18, 0.18, 0.2), CFrame = CFrame.lookAt(from, vup), Color = PHONE })
				tw(cord, 0.15, { Size = Vector3.new(0.18, 0.18, len), CFrame = CFrame.lookAt(from, vup) * CFrame.new(0, 0, -len / 2) })
				table.insert(cords, cord)
			end
		end
		for k = 1, 4 do -- spirales de fil autour de la victime
			local coil = fxPart({ Shape = CYL, Size = Vector3.new(0.35, 3.4, 3.4), CFrame = CFrame.new(vup + Vector3.new(0, -1.8 + k * 0.8, 0)) * UP, Color = k % 2 == 0 and PHONE or FUCHSIA, Transparency = 0.2 })
			table.insert(cords, coil)
		end
		label(vup + Vector3.new(0, 4.5, 0), "PLEASE HOLD...", PINKL, 3.5, 1, 1)
	end)
	at(d, T.Yank - 0.15, function()
		play(c, "RecUltYank")
	end)
	-- elle tire : tous les téléphones s'écrasent sur la victime
	at(d, T.Yank, function()
		for _, cd in ipairs(cords) do
			cd:Destroy()
		end
		for _, ph in ipairs(phones) do
			ph:move(CFrame.new(vup) * (ph.cf - ph.cf.Position), 0.1, function(a)
				return a * a
			end)
		end
	end)
	at(d, T.Yank + 0.1, function()
		for _, ph in ipairs(phones) do
			ph:destroy()
		end
		phones = {}
		shakeConn:Disconnect()
		snd(SND.Slam, vup, 1.4)
		snd(SND.Slam2, vup, 1.2, 0.9)
		snd("BigImpact", vup, 1.2)
		Kit.cubes(vup, 26, { FUCHSIA, PHONE, WHITE }, 0.9, 12, 0.6)
		blast(vup, 2, 12, FUCHSIA, 0.25, 0.1)
		CFX.bigImpact(vup, -dir, 1.2, FUCHSIA)
		word(vup + Vector3.new(0, 3, 0), "HOLD THE LINE!", 1.2)
		if isNear then
			KK.impactFrames("BW", 0.04)
			CFX.shake(1)
		end
	end)
	-- hurlement sonique
	at(d, T.Scream, function()
		-- gros plan sur son visage qui hurle
		KK.shot(d, "follow", { subject = c, offset = CFrame.new(6, 1.4, -3), lookOffset = Vector3.new(0, 1.4, -2), fov = 48, flat = true })
		play(c, "RecUltScream")
		snd(SND.Riser, vup, 0.5, 1.6)
	end)
	at(d, T.Scream + 0.22, function()
		local head = c and c:FindFirstChild("Head")
		local mouth = head and head.Position or (C0 + Vector3.new(0, 1.5, 0))
		local aim = (vup - mouth).Unit
		snd(SND.Sonic, mouth, 1.5)
		snd(SND.Crack, mouth, 1, 0.7)
		snd(SND.Ring2, mouth, 0.7, 0.6)
		for k = 0, 6 do
			task.delay(k * 0.04, function()
				local p = mouth + aim * (1.5 + k * 1.4)
				ring(p, CFrame.lookAt(p, p + aim) * CFrame.Angles(0, math.pi / 2, 0), 1, 4 + k * 2.2, k % 2 == 0 and FUCHSIA or WHITE, 0.3, 0.35)
			end)
		end
		label(mouth + Vector3.new(0, 3, 0), "WE'RE CLOSED!!", REDC, 5, 1.2, 2)
		task.delay(0.18, function()
			KK.shot(d, "track", { from = base - dir * 12 + rt * 4 + Vector3.new(0, 1, 0), at = v or vsky, fov = 70 })
		end)
		CFX.dust(base, 12, PINKL, 14)
		if isNear then
			CFX.shake(1.2)
			CFX.fovKick(14)
		end
	end)
	-- elle retombe : PLAQUÉE + panneau CLOSED planté
	at(d, T.Crash, function()
		KK.shot(d, "orbit", { at = base + Vector3.new(0, 1, 0), r0 = 10, r1 = 22, dur = 0.6, height = 9, angle = 160, speed = 20, basis = CFrame.lookAt(Vector3.zero, dir), fov = 68 })
		snd(SND.Boom, base, 1.3)
		snd(SND.Bass, base, 1.6)
		snd("GroundSlam", base, 1.3)
		CFX.quake(base, 16, FUCHSIA, 1.5)
		blast(base + Vector3.new(0, 1, 0), 2, 14, PINKL, 0.3, 0.1)
		-- cratère
		local crater = fxPart({ Shape = CYL, Size = Vector3.new(0.12, 11, 11), CFrame = CFrame.new(base + Vector3.new(0, 0.06, 0)) * UP, Color = Color3.fromRGB(45, 40, 50), Transparency = 0.05 })
		local rim = fxPart({ Shape = CYL, Size = Vector3.new(0.5, 12.5, 12.5), CFrame = CFrame.new(base + Vector3.new(0, 0.02, 0)) * UP, Color = Color3.fromRGB(120, 110, 120), Transparency = 0.1 })
		for _, p in ipairs({ crater, rim }) do
			task.delay(1.6, function()
				tw(p, 0.5, { Transparency = 1 })
			end)
			Debris:AddItem(p, 2.15)
		end
		CFX.debris(base, 10, { Color3.fromRGB(150, 140, 150), FUCHSIA }, 1.2, 1)
		local sp = base + rt * 6.5 + dir * 1
		local sign, pl = buildSign(CFrame.lookAt(sp + Vector3.new(0, 12, 0), sp + Vector3.new(0, 12, 0) - dir))
		sign:move(CFrame.lookAt(sp, sp - dir) * CFrame.Angles(0, 0, 0.12), 0.15, function(a)
			return a * a
		end)
		task.delay(0.15, function()
			snd("Clang", sp, 1.2)
			CFX.shockwave(sp + Vector3.new(0, 0.2, 0), 5, REDC)
		end)
		task.spawn(function()
			for k = 1, 8 do
				task.wait(0.14)
				if pl.Parent then
					pl.Enabled = k % 2 == 0
				end
			end
		end)
		task.delay(1.6, function()
			sign:fade(0.4)
		end)
		word(V0 + Vector3.new(0, 3, 0), "CLOSED!", 1.7)
		label(base + Vector3.new(0, 7, 0), "OUT OF OFFICE", FUCHSIA, 5, 1.6, 2)
		if isNear then
			KK.impactFrames("WBWB", 0.045)
			CFX.shake(1.6)
		end
	end)
	at(d, T.Crash + 0.45, function()
		play(c, "RecUltGlasses")
	end)
	at(d, T.End - 0.05, function()
		KK.release(d)
	end)
end

-- attaque : le combiné file au bout de son fil vers la cible
local function clientLasso(K, d)
	local c = d.caster
	play(c, "RecUltLasso")
	local r = rootOf(c)
	if not r then
		return
	end
	local from = r.Position + Vector3.new(0, 1, 0)
	local to = d.to or (from + r.CFrame.LookVector * 18)
	snd(SND.Whip, from, 1, 1.1)
	snd(SND.Ring, from, 0.6, 1.2)
	local cord = fxPart({ Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.lookAt(from, to), Color = PHONE }, 0.8)
	local tip = fxPart({ Size = Vector3.new(0.6, 0.6, 1.8), CFrame = CFrame.lookAt(from, to), Color = PHONE }, 0.8)
	local len = (to - from).Magnitude
	tw(cord, 0.2, { Size = Vector3.new(0.2, 0.2, len), CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2) })
	tw(tip, 0.2, { CFrame = CFrame.lookAt(to, to + (to - from)) })
	task.delay(0.6, function()
		tw(cord, 0.15, { Transparency = 1 })
		tw(tip, 0.15, { Transparency = 1 })
	end)
	at(d, 0.2, function()
		K.sparks(to, 10, PINKL)
		K.ring(CFrame.lookAt(to, from), 5, FUCHSIA, 0.25, 0.3)
	end)
end

local function client(K, d)
	KK, CFX, CUR = K, K.CFX, d
	if d.phase == "Cutin" then
		local r = rootOf(d.caster)
		snd(SND.Ring2, r and r.Position, 0.6, 1.2)
	elseif d.phase == "Lasso" then
		clientLasso(K, d)
	elseif d.phase == "Whiff" then
		clientWhiff(K, d)
	elseif d.phase == "Hit" then
		clientHit(K, d)
	elseif d.phase == "End" then
		finishSeq(d)
	end
end

return {
	Name = "Out of Office",
	-- v3 : titres de temps forts (UltimateController) ; Anticipate = poses d'armement avant ces coups
	Beats = { Hit = { { 0, "INCOMING CALLS" }, { T.Whip0, "PHONE CORD WHIP" }, { T.Web, "ON HOLD" }, { T.Scream, "OFFICE CLOSED" } } },
	Desc = "Eight ringing phones, a cord-whip flurry, then a WE'RE CLOSED scream that sends them up and slams them down.",
	Color = FUCHSIA,
	Color2 = PINKL,
	Range = 25,
	Angle = 70,
	Startup = 1.0,
	Server = server,
	Client = client,
}
