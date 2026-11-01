--[[
	Ultime du JANITOR — « INDUSTRIAL FLOOD » (G pendant l'Overtime « Deep Clean »).
	Chorégraphie (touché) :
		0) glissade savonneuse vers la cible (ruée)
		1) colonne d'eau tourbillonnante qui soulève la victime pendant que le Janitor fait l'hélicoptère avec un mop géant (3 coups)
		2) il fonce et récure : 4 frottés (SCRUB / RUB / POLISH / SHINE), bulles et mousse
		3) bond arrière sur un panneau WET FLOOR en guise de planche : une vague géante se lève derrière lui
		4) il surfe la vague à travers la victime -> dôme d'éclaboussures, ÉJECTION, inondation au sol
	Raté : petite vague qui roule devant lui et s'écrase, « MISSED A SPOT! ».
	Dégâts : 3x2 + 4x3 + 16 = 34 (+ 10 de zone).
]]
local RunService = game:GetService("RunService")

local WATER, FOAM, JBLUE, DEEP, YELLOW = Color3.fromRGB(110, 200, 255), Color3.fromRGB(225, 245, 255), Color3.fromRGB(80, 170, 255), Color3.fromRGB(40, 110, 220), Color3.fromRGB(255, 220, 40)
local BROWN, GREY, DARK = Color3.fromRGB(120, 70, 40), Color3.fromRGB(150, 160, 175), Color3.fromRGB(30, 30, 35)
local SFX = { Roar = 9120551511, Splash = 9119481909, Dive = 132575463084009, Thrash = 124100101089791, Pop = 109359226723492, Boom = 2103404398, Thunder = 9126082854 }

-- minutage commun serveur / client (secondes depuis la phase "Connect")
local T = { hits = { 0.35, 0.6, 0.85 }, scrub = 1.0, scrubs = { 1.15, 1.35, 1.55, 1.75 }, leap = 1.9, surge = 2.3, impact = 2.5, land = 2.68, done = 3.2 }

local ULT = {
	Name = "Industrial Flood",
	Desc = "Lift them in a water vortex, scrub them clean, then surf a tidal wave right through them.",
	Color = JBLUE,
	Color2 = YELLOW,
	Range = 25,
	Angle = 70,
	Startup = 1.0,
}

------------------------------------------------------------------------
-- SERVEUR
------------------------------------------------------------------------
function ULT.Server(U, caster, target, ctx)
	U.fx(ctx, "Rush")
	if not U.rush(ctx, target, { speed = 115, contact = 6, maxTime = 0.42 }) then
		U.fx(ctx, "Whiff", { cf = U.currentCF(ctx, caster) })
		U.wait(ctx, 0.9)
		return
	end
	local cf = U.currentCF(ctx, caster)
	local look = U.flat(cf.LookVector)
	cf = CFrame.lookAt(cf.Position, cf.Position + look)
	local vp = U.wallSafe(cf.Position, (cf * CFrame.new(0, 0, -7)).Position, 1.5)
	local dist = math.max(4.5, (vp - cf.Position).Magnitude)
	local vface = U.facing(vp, cf.Position)
	local h = math.clamp(U.headroom(vp, 9) - 1, 1.5, 4.5)
	local backPos = (cf * CFrame.new(0, 0, 9)).Position
	local up = math.clamp(U.headroom(backPos, 7), 1.5, 6.5)
	local function held()
		return ctx.held[target] ~= nil
	end
	U.hold(ctx, target, vface)
	local c0 = os.clock()
	local function at(t)
		return U.wait(ctx, math.max(0, t - (os.clock() - c0)))
	end
	U.fx(ctx, "Connect", { cf = cf, vp = vp, h = h, dist = dist, up = up })

	-- 1) la colonne d'eau soulève et fait tourner la victime
	task.spawn(function()
		local s = os.clock()
		while U.alive(ctx) and held() and os.clock() - s < 0.85 do
			local a = (os.clock() - s) / 0.85
			U.place(ctx, target, vface * CFrame.new(0, h * (1 - (1 - a) ^ 2), 0) * CFrame.Angles(0, a * math.pi * 6, 0))
			RunService.Heartbeat:Wait()
		end
	end)
	local words = { { "SPLASH!" }, { "SPLOOSH!" }, { "GLUG!" } }
	for i, t in ipairs(T.hits) do
		if not at(t) then
			return
		end
		U.hit(ctx, target, 2, { words = words[i], power = 0.5 })
	end

	-- 2) récurage au corps à corps
	if not at(T.scrub) then
		return
	end
	local vhold = vface * CFrame.new(0, math.min(h, 2.2), 0)
	if held() then
		U.glide(ctx, target, vhold, 0.12, "Out")
	end
	local scf = cf * CFrame.new(0, 0, -(dist - 3.4))
	U.glide(ctx, caster, scf, 0.12, "Out")
	local sw = { { "SCRUB!" }, { "RUB!" }, { "POLISH!" }, { "SHINE!" } }
	for i, t in ipairs(T.scrubs) do
		if not at(t) then
			return
		end
		U.hit(ctx, target, 3, { words = sw[i], power = 0.65 })
		if held() then
			U.place(ctx, target, vhold * CFrame.new(0, 0, 0.35 * i) * CFrame.Angles(0, (i % 2 == 0) and 0.25 or -0.25, 0))
		end
	end

	-- 3) bond arrière sur le panneau, la vague se lève
	if not at(T.leap) then
		return
	end
	local back = U.wallSafe(scf.Position, (cf * CFrame.new(0, up, 9)).Position, 2)
	U.glide(ctx, caster, CFrame.lookAt(back, back + look), 0.3, "Out")
	if held() then
		U.glide(ctx, target, vface * CFrame.new(0, 1.2, 0), 0.3, "Out")
	end

	-- 4) surf à travers la victime
	if not at(T.surge) then
		return
	end
	local fin = U.wallSafe(back, (cf * CFrame.new(0, 0.5, -(dist + 6))).Position, 2)
	U.glide(ctx, caster, CFrame.lookAt(fin, fin + look), 0.3, "In")
	if not at(T.impact) then
		return
	end
	U.fx(ctx, "Impact", { p = U.root(target) and U.root(target).Position or vp })
	U.finish(ctx, target, 16, { launch = look * 78 + Vector3.new(0, 58, 0), words = { "INDUSTRIAL FLOOD!" }, splash = { radius = 12, damage = 10 } })
	if not at(T.land) then
		return
	end
	local landY = cf.Position.Y
	U.glide(ctx, caster, CFrame.lookAt(Vector3.new(fin.X, landY, fin.Z), Vector3.new(fin.X, landY, fin.Z) + look), 0.18, "In")
	at(T.done)
end

------------------------------------------------------------------------
-- CLIENT
------------------------------------------------------------------------
local runs = {} -- [seq] = { alive, conns }

local ANIM = {}
do -- hélicoptère : mop géant au-dessus de la tête, tout le corps tourne
	local hold = function(tw)
		return { RS = { p = 3.05, r = -0.15 }, LS = { p = 3.0, r = -0.15 }, RJ = { ln = -0.25, tw = tw }, RH = { p = 0.35, r = -0.45 }, LH = { p = 0.35, r = -0.45 } }
	end
	local f = { { t = 0 }, (function() local k = hold(0) k.t = 0.1 return k end)() }
	local t, a = 0.1, 0
	while t < 0.92 do
		t += 0.05
		a += 1.5
		local k = hold(a)
		k.t = t
		table.insert(f, k)
	end
	local k = hold(a % (math.pi * 2) - math.pi * 2)
	k.t = t + 0.001
	table.insert(f, k)
	table.insert(f, { t = t + 0.09, RS = { p = 1.6, y = 0.4 }, LS = { p = 1.5, y = 0.6 }, RJ = { ln = 0.3 }, RH = { p = -0.4 }, LH = { p = 0.6 } })
	ANIM.Spin = f
end
do -- récurage : 4 frottés alternés, buste qui vrille, jambes en fente
	local f = { { t = 0 } }
	for i = 1, 4 do
		local s = (i % 2 == 1) and 1 or -1
		local t0 = 0.05 + (i - 1) * 0.2
		table.insert(f, { t = t0, RS = { p = 1.15, y = 0.35 * s }, LS = { p = 1.05, y = 0.6 }, RJ = { tw = -0.85 * s, ln = 0.3 }, RH = { p = -0.3 }, LH = { p = 0.6 } })
		table.insert(f, { t = t0 + 0.09, RS = { p = 1.8, y = -0.25 * s }, LS = { p = 1.65, y = 0.4 }, RJ = { tw = 0.95 * s, ln = 0.55, sd = 0.12 * s }, RH = { p = -0.65 }, LH = { p = 0.95 } })
	end
	table.insert(f, { t = 0.92 })
	ANIM.Scrub = f
end
ANIM.Surf = { -- bond arrière, surf de profil sur le panneau, puis estoc du mop à l'impact
	{ t = 0 },
	{ t = 0.1, RS = { p = -0.8 }, LS = { p = -0.8 }, RJ = { ln = 0.55 }, RH = { p = 1.0 }, LH = { p = 1.0 } },
	{ t = 0.3, RS = { p = 1.3, r = -1.1 }, LS = { p = 1.0, r = -1.25 }, RJ = { tw = -1.25, sd = 0.25, ln = 0.2 }, RH = { p = 0.75, r = -0.35 }, LH = { p = -0.35, r = -0.35 } },
	{ t = 0.55, RS = { p = 1.45, r = -1.0 }, LS = { p = 1.1, r = -1.3 }, RJ = { tw = -1.2, sd = 0.3, ln = 0.25 }, RH = { p = 0.8, r = -0.35 }, LH = { p = -0.3, r = -0.35 } },
	{ t = 0.62, RS = { p = 2.05, y = 0.2 }, LS = { p = 1.85, y = 0.5 }, RJ = { tw = 0.7, ln = 0.55 }, RH = { p = -0.65 }, LH = { p = 0.95 } },
	{ t = 0.95, RS = { p = 1.95, y = 0.2 }, LS = { p = 1.75, y = 0.5 }, RJ = { tw = 0.6, ln = 0.45 }, RH = { p = -0.55 }, LH = { p = 0.85 } },
	{ t = 1.2 },
}
ANIM.Slide = { -- glissade de baseball sur le savon (ruée)
	{ t = 0 },
	{ t = 0.06, RJ = { ln = -1.2, sd = 0.1 }, RH = { p = 1.6 }, LH = { p = 0.35, r = -0.2 }, RS = { p = 3.0, r = -0.35 }, LS = { p = -0.7, r = -0.7 } },
	{ t = 0.4, RJ = { ln = -1.15, sd = 0.12 }, RH = { p = 1.55 }, LH = { p = 0.35, r = -0.2 }, RS = { p = 3.0, r = -0.35 }, LS = { p = -0.7, r = -0.7 } },
	{ t = 0.5 },
}
ANIM.Cutin = { -- fait tournoyer le mop puis le pointe vers l'adversaire
	{ t = 0 },
	{ t = 0.15, RS = { p = 3.1, y = 0.4 }, LS = { p = 0.4, r = -0.6 }, RJ = { ln = -0.3, tw = 0.4 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
	{ t = 0.5, RS = { p = 3.1, y = 2.6 }, LS = { p = 0.4, r = -0.6 }, RJ = { ln = -0.3, tw = -0.3 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
	{ t = 0.62, RS = { p = 1.75, y = 0.1 }, LS = { p = 0.8, r = -0.8 }, RJ = { ln = 0.2, tw = 0.35 }, RH = { p = -0.5 }, LH = { p = 0.7 } },
	{ t = 0.95, RS = { p = 1.7, y = 0.1 }, LS = { p = 0.8, r = -0.8 }, RJ = { ln = 0.18, tw = 0.3 }, RH = { p = -0.45 }, LH = { p = 0.65 } },
	{ t = 1.1 },
}
ANIM.Flail = { -- victime ballotée dans le tourbillon
	{ t = 0 },
	{ t = 0.12, RS = { p = 2.6, r = -0.8 }, LS = { p = 2.2, r = -1.0 }, RH = { p = 0.6, r = -0.5 }, LH = { p = -0.4, r = -0.5 }, RJ = { ln = -0.3 } },
	{ t = 0.3, RS = { p = 1.6, r = -1.2 }, LS = { p = 2.8, r = -0.6 }, RH = { p = -0.5, r = -0.4 }, LH = { p = 0.7, r = -0.4 }, RJ = { ln = 0.2 } },
	{ t = 0.5, RS = { p = 2.7, r = -0.7 }, LS = { p = 2.0, r = -1.1 }, RH = { p = 0.6, r = -0.5 }, LH = { p = -0.4, r = -0.5 }, RJ = { ln = -0.3 } },
	{ t = 0.7, RS = { p = 1.6, r = -1.2 }, LS = { p = 2.8, r = -0.6 }, RH = { p = -0.5, r = -0.4 }, LH = { p = 0.7, r = -0.4 }, RJ = { ln = 0.2 } },
	{ t = 0.95 },
}

local function rootOf(m)
	return m and m.Parent and m:FindFirstChild("HumanoidRootPart")
end

-- position de caméra qui ne traverse pas les murs (rayon depuis la cible)
local function camSafe(target, want)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { workspace:FindFirstChild("FX"), workspace:FindFirstChild("Dummies") }
	for _, pl in ipairs(game:GetService("Players"):GetPlayers()) do
		if pl.Character then
			table.insert(ex, pl.Character)
		end
	end
	params.FilterDescendantsInstances = ex
	local d = want - target
	local r = workspace:Raycast(target, d, params)
	if r then
		return r.Position - d.Unit * 1.2
	end
	return want
end

-- mop géant tenu dans la main droite (repère du bras : -Y = prolongement)
local function giantMop(K, data, c)
	local A = CFrame.Angles(0, 0, math.pi / 2)
	K.prop(data, c, "Right Arm", Vector3.new(7.5, 0.4, 0.4), CFrame.new(0, -3.6, 0) * A, BROWN, K.CYL)
	K.prop(data, c, "Right Arm", Vector3.new(0.5, 0.55, 0.55), CFrame.new(0, -7.2, 0) * A, YELLOW, K.CYL)
	K.prop(data, c, "Right Arm", Vector3.new(3.2, 0.9, 1.5), CFrame.new(0, -7.7, 0), GREY)
	K.prop(data, c, "Right Arm", Vector3.new(3.0, 1.1, 1.3), CFrame.new(0, -8.6, 0), Color3.fromRGB(235, 235, 240))
end

local function vortex(K, data, st, base, h, dur)
	local col = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(1, 6.4, 6.4), Color = WATER, Transparency = 0.5, Material = Enum.Material.Glass }, dur + 1))
	local inner = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(1, 4.4, 4.4), Color = DEEP, Transparency = 0.72 }, dur + 1))
	local orbs = {}
	for i = 1, 14 do
		orbs[i] = K.track(data, K.part({ Shape = (i % 3 == 0) and K.BALL or Enum.PartType.Block, Size = Vector3.one * K.rng:NextNumber(0.6, 1.2), Color = (i % 2 == 0) and FOAM or WATER, Transparency = 0.1 }, dur + 1))
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - t0
		if el > dur or not st.alive then
			conn:Disconnect()
			for _, o in ipairs(orbs) do
				K.tween(o, 0.2, { Transparency = 1 })
			end
			K.tween(col, 0.25, { Size = Vector3.new(0.3, 15, 15), Transparency = 1 })
			K.tween(inner, 0.2, { Transparency = 1 })
			return
		end
		local hh = math.min(1, el / 0.3) * (h + 8)
		local wob = math.sin(el * 30) * 0.3
		col.Size = Vector3.new(hh, 6.4 + wob, 6.4 + wob)
		col.CFrame = CFrame.new(base + Vector3.new(0, hh / 2, 0)) * K.UPRIGHT * CFrame.Angles(el * 6, 0, 0)
		inner.Size = Vector3.new(hh * 0.96, 4.4, 4.4)
		inner.CFrame = CFrame.new(base + Vector3.new(0, hh / 2, 0)) * K.UPRIGHT
		for i, o in ipairs(orbs) do
			local a = el * 9 + i * (math.pi * 2 / 14)
			local y = (el * 8 + i * 0.7) % math.max(hh, 0.5)
			local rad = 3.7 - y * 0.06
			o.CFrame = CFrame.new(base + Vector3.new(math.cos(a) * rad, y, math.sin(a) * rad)) * CFrame.Angles(a, a, 0)
		end
	end)
	table.insert(st.conns, conn)
end

-- vague géante : corps, pente arrière, crête d'écume, lèvre blanche + embruns
local function wave(K, data, st, fromCF, toCF, hold, dur, scale, life)
	scale = scale or 1
	local W, H = 26 * scale, 10 * scale
	local m = {
		body = K.track(data, K.part({ Size = Vector3.new(W, 1, 5 * scale), Color = WATER, Transparency = 0.22 }, life)),
		back = K.track(data, K.part({ Shape = Enum.PartType.Wedge, Size = Vector3.new(W, 1, 9 * scale), Color = JBLUE, Transparency = 0.28 }, life)),
		crest = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(W + 1, 4.6 * scale, 4.6 * scale), Color = FOAM, Transparency = 0.05 }, life)),
		lip = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(W + 0.4, 2.6 * scale, 2.6 * scale), Color = Color3.new(1, 1, 1) }, life)),
	}
	local function place(cf, grow)
		local hh = math.max(0.3, H * grow)
		m.body.Size = Vector3.new(W, hh, 5 * scale)
		m.body.CFrame = cf * CFrame.new(0, hh / 2, 0)
		m.back.Size = Vector3.new(W, hh, 9 * scale)
		m.back.CFrame = cf * CFrame.new(0, hh / 2, 7 * scale) * CFrame.Angles(0, math.pi, 0)
		m.crest.CFrame = cf * CFrame.new(0, hh, -0.8 * scale)
		m.lip.CFrame = cf * CFrame.new(0, hh + 0.6 * scale, -2.6 * scale)
	end
	place(fromCF, 0.05)
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - t0
		if not st.alive or not m.body.Parent then
			conn:Disconnect()
			return
		end
		local a = math.clamp((el - hold) / dur, 0, 1)
		place(fromCF:Lerp(toCF, a * a), math.min(1, el / 0.3))
		if K.rng:NextNumber() < 0.55 then
			local p0 = m.lip.Position + fromCF.RightVector * K.rng:NextNumber(-W / 2, W / 2)
			local d = K.part({ Shape = K.BALL, Size = Vector3.one * K.rng:NextNumber(0.8, 1.6), Position = p0, Color = FOAM, Transparency = 0.1 }, 0.6)
			K.tween(d, 0.5, { Position = p0 + Vector3.new(K.rng:NextNumber(-2, 2), K.rng:NextNumber(2, 5), 0) + fromCF.LookVector * 3, Transparency = 1, Size = d.Size * 0.3 })
		end
		if el >= hold + dur then
			conn:Disconnect()
		end
	end)
	table.insert(st.conns, conn)
	return function(t)
		for _, p in pairs(m) do
			if p.Parent then
				K.tween(p, t or 0.35, { Transparency = 1, Size = p.Size * Vector3.new(1.1, 0.25, 1.6) })
			end
		end
	end
end

local function splash(K, pos, n, sz)
	K.shards(pos, n or 10, { WATER, FOAM, JBLUE }, sz or 1)
	local b = K.part({ Shape = K.BALL, Size = Vector3.one * 2, Position = pos, Color = FOAM, Transparency = 0.2 }, 0.5)
	K.tween(b, 0.35, { Size = Vector3.one * 7 * (sz or 1), Transparency = 1 })
end

local function puddle(K, data, pos, r, life)
	local g = K.groundPos(pos)
	local p = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(0.12, 2, 2), CFrame = CFrame.new(g + Vector3.new(0, 0.07, 0)) * K.UPRIGHT, Color = WATER, Transparency = 0.3 }, life + 0.6))
	local rim = K.part({ Shape = K.CYL, Size = Vector3.new(0.1, 2.4, 2.4), CFrame = CFrame.new(g + Vector3.new(0, 0.05, 0)) * K.UPRIGHT, Color = FOAM, Transparency = 0.4 }, life + 0.6)
	K.tween(p, 0.4, { Size = Vector3.new(0.12, r * 2, r * 2) })
	K.tween(rim, 0.4, { Size = Vector3.new(0.1, r * 2 + 1, r * 2 + 1) })
	task.delay(life, function()
		if p.Parent then
			K.tween(p, 0.5, { Transparency = 1 })
			K.tween(rim, 0.5, { Transparency = 1 })
		end
	end)
end

function ULT.Client(K, data)
	local c, v = data.caster, data.target
	local seq = data.seq or 0
	if data.phase == "End" then
		local st = runs[seq]
		if st then
			st.alive = false
			for _, cn in ipairs(st.conns) do
				cn:Disconnect()
			end
			runs[seq] = nil
		end
		return
	end
	runs[seq] = runs[seq] or { alive = true, conns = {} }
	local st = runs[seq]
	local cr = rootOf(c)
	if not cr then
		return
	end
	local function at(dt, fn)
		K.at(data, dt, function()
			if st.alive then
				fn()
			end
		end)
	end

	if data.phase == "Cutin" then
		K.anim(c, ANIM.Cutin)
		giantMop(K, data, c)
		local g = K.groundPos(cr.Position)
		K.sound(SFX.Thrash, cr.Position, 0.7)
		K.sound("Charge", cr.Position, 0.6)
		for i = 0, 2 do
			at(0.15 + i * 0.25, function()
				K.CFX.swirl(g + Vector3.new(0, 0.5, 0), 3.5, 6, { WATER, FOAM, JBLUE }, 12, 0.5)
				K.shockwave(g + Vector3.new(0, 0.15, 0), 7 + i * 2, WATER)
			end)
		end
		at(0.62, function()
			K.sparks(cr.Position + cr.CFrame.LookVector * 6 + Vector3.new(0, 1, 0), 10, YELLOW)
			K.sound("Ding", cr.Position, 0.9)
		end)

	elseif data.phase == "Rush" then
		K.anim(c, ANIM.Slide)
		K.sound("Slip", cr.Position, 1)
		K.sound("Whoosh2", cr.Position, 0.9)
		task.spawn(function()
			for _ = 1, 8 do
				local r = rootOf(c)
				if not r or not st.alive then
					break
				end
				K.afterimage(c, FOAM, 0.3, 0.5)
				local p0 = r.Position - Vector3.new(0, 2.6, 0)
				local b = K.part({ Shape = K.BALL, Size = Vector3.one * K.rng:NextNumber(0.8, 1.5), Position = p0, Color = (K.rng:NextNumber() < 0.5) and FOAM or Color3.fromRGB(255, 200, 255), Transparency = 0.1 }, 0.7)
				K.tween(b, 0.6, { Position = p0 + Vector3.new(0, 2, 0), Transparency = 1, Size = b.Size * 1.6 })
				task.wait(0.05)
			end
		end)
		if K.isCaster(data) then
			K.speedLines(0.4, FOAM)
		end

	elseif data.phase == "Whiff" then
		local cf = data.cf or cr.CFrame
		local g = K.groundPos(cf.Position)
		K.anim(c, ANIM.Surf, 1.4)
		K.sound(SFX.Splash, cf.Position, 1)
		local kill = wave(K, data, st, CFrame.lookAt(g, g + cf.LookVector) * CFrame.new(0, 0, -2), CFrame.lookAt(g, g + cf.LookVector) * CFrame.new(0, 0, -16), 0.15, 0.4, 0.5, 2)
		at(0.55, function()
			kill(0.3)
			local p = g + cf.LookVector * 16
			splash(K, p + Vector3.new(0, 1.5, 0), 12, 1)
			K.shockwave(p + Vector3.new(0, 0.2, 0), 9, WATER)
			puddle(K, data, p, 6, 1.5)
			K.word(p + Vector3.new(0, 4, 0), "MISSED A SPOT!", 0.8, "Light")
			K.sound(SFX.Dive, p, 1)
			K.sound("Boing", p, 0.6)
		end)

	elseif data.phase == "Connect" then
		local cf, vp, h, dist = data.cf, data.vp, data.h or 3, data.dist or 7
		local wscale = math.clamp(((data.up or 5) + 0.6) / 10, 0.45, 1)
		local g = K.groundPos(vp)
		local look = cf.LookVector
		K.letterbox(data, true)
		K.impactFrames("WB")
		K.shake(0.8)
		-- caméra 1 : plan de côté qui glisse en 3/4 (Janitor + colonne d'eau)
		local side = cf.RightVector
		local mid = cf.Position:Lerp(vp, 0.5) + Vector3.new(0, 1.5, 0)
		K.shot(data, "dolly", { from = CFrame.lookAt(camSafe(mid, mid + side * 15 + Vector3.new(0, 2, 0) + look * 3), mid + Vector3.new(0, 1, 0)), to = CFrame.lookAt(camSafe(mid, mid + side * 12 + Vector3.new(0, 3.5, 0) - look * 4), mid + Vector3.new(0, 2, 0)), dur = 1.0, fov0 = 64, fov1 = 58 })
		K.anim(c, ANIM.Spin)
		if v then
			K.anim(v, ANIM.Flail)
		end
		local roar = K.sound(SFX.Roar, vp, 1.1)
		K.sound(SFX.Splash, vp, 1.2)
		K.sound("Whoosh3", cr.Position, 1)
		vortex(K, data, st, g, h, 0.98)
		K.shockwave(g + Vector3.new(0, 0.2, 0), 10, WATER)
		K.light(vp + Vector3.new(0, 3, 0), WATER, 22, 4, 1.0)
		-- traînée du mop qui tourne
		for _, n in ipairs({ "Right Arm", "Left Arm" }) do
			K.CFX.trailOn(c:FindFirstChild(n), WATER, 0.95, 6, 2.5)
		end
		for i, t in ipairs(T.hits) do
			at(t, function()
				local r = rootOf(v)
				local p = r and r.Position or vp
				splash(K, p, 8, 0.8)
				K.airRing(p, Vector3.new(0, 1, 0), 9, FOAM, 0.25)
				K.sound(i == 2 and SFX.Dive or "Splat", p, 1.1, 0.9 + i * 0.1)
				K.sound("Water", p, 0.8)
				K.shake(0.5)
			end)
		end
		at(0.98, function()
			if roar then
				K.tween(roar, 0.4, { Volume = 0 })
			end
			splash(K, g + Vector3.new(0, 4, 0), 14, 1.3)
			K.sound(SFX.Splash, vp, 1)
		end)

		-- 2) récurage
		at(T.scrub, function()
			K.anim(c, ANIM.Scrub)
			K.sound("Whoosh2", cr.Position, 1)
			K.afterimage(c, WATER, 0.3)
			-- caméra 2 : plan serré de profil sur le récurage
			local m2 = (cf * CFrame.new(0, 0.8, -(dist - 1.7))).Position
			K.shot(data, "dolly", { from = CFrame.lookAt(camSafe(m2, m2 - cf.RightVector * 10 + Vector3.new(0, 1.5, 0) - look * 2), m2), to = CFrame.lookAt(camSafe(m2, m2 - cf.RightVector * 8 + Vector3.new(0, 2.5, 0) + look * 1.5), m2), dur = 0.9, fov0 = 56, fov1 = 50 })
		end)
		local scrubWords = { "SCRUB!", "RUB!", "POLISH!", "SHINE!" }
		for i, t in ipairs(T.scrubs) do
			at(t, function()
				local r = rootOf(v)
				local p = r and r.Position or vp
				local s = (i % 2 == 1) and 1 or -1
				K.slashArc(CFrame.lookAt(p + look * 1.5, p + look * 3) * CFrame.Angles(0, math.pi, 0), 4, (i % 2 == 0) and YELLOW or WATER, -70 * s, 70 * s, 0.08, 15 * s, 0.6)
				for _ = 1, 6 do
					local b = K.part({ Shape = K.BALL, Size = Vector3.one * K.rng:NextNumber(0.6, 1.4), Position = p + Vector3.new(K.rng:NextNumber(-1.5, 1.5), K.rng:NextNumber(-1, 1.5), K.rng:NextNumber(-1.5, 1.5)), Color = (K.rng:NextNumber() < 0.5) and FOAM or Color3.fromRGB(255, 200, 255), Transparency = 0.15 }, 0.8)
					K.tween(b, 0.6, { Position = b.Position + Vector3.new(0, K.rng:NextNumber(1.5, 3.5), 0), Size = b.Size * 1.8, Transparency = 1 })
				end
				K.sparks(p, 8, FOAM)
				K.word(p + Vector3.new(K.rng:NextNumber(-2, 2), 3, 0), scrubWords[i], 0.6 + i * 0.1, "Light")
				K.sound(SFX.Pop, p, 0.9, 0.9 + i * 0.08)
				K.sound(i == 4 and "PunchHeavy" or "Punch", p, 0.9)
				K.shake(0.45 + i * 0.08)
				if i == 4 then
					K.impactFrames("B")
				end
			end)
		end

		-- 3) bond arrière, panneau-planche, la vague se lève
		at(T.leap, function()
			K.anim(c, ANIM.Surf)
			K.sound("Whoosh", cr.Position, 1)
			K.sound(SFX.Thunder, vp, 0.6)
			-- planche WET FLOOR sous les pieds (soudée à la racine)
			K.prop(data, c, "HumanoidRootPart", Vector3.new(5.8, 0.35, 2.3), CFrame.new(0, -3.15, 0), YELLOW)
			K.prop(data, c, "HumanoidRootPart", Vector3.new(4.4, 0.37, 0.5), CFrame.new(0, -3.15, 0.2), DARK)
			local wcf = CFrame.lookAt(g, g + look)
			local behind = cf * CFrame.new(0, 0, 9)
			local wfrom = CFrame.lookAt(K.groundPos(behind.Position), K.groundPos(behind.Position) + look) * CFrame.new(0, 0, 3)
			local wto = wcf * CFrame.new(0, 0, -7)
			-- la vague monte (0.4 s) puis déferle (0.3 s)
			st.killWave = wave(K, data, st, wfrom, wto, T.surge - T.leap, 0.3, wscale, 3.5)
			-- caméra 3 : grand plan 3/4 arrière (la vague se lève derrière lui, la victime devant)
			local tgt = vp + Vector3.new(0, 2, 0)
			K.shot(data, "dolly", { from = CFrame.lookAt(camSafe(tgt, (cf * CFrame.new(13, 7, 15)).Position), tgt), to = CFrame.lookAt(camSafe(tgt, (cf * CFrame.new(10, 9, 9)).Position), tgt), dur = 0.9, fov0 = 70, fov1 = 64 })
			at(T.surge, function()
				K.sound(SFX.Roar, cr.Position, 1.2)
				K.sound("Whoosh3", cr.Position, 1.1)
				if K.isCaster(data) then
					K.speedLines(0.35, FOAM)
				end
				task.spawn(function()
					for _ = 1, 5 do
						if not st.alive then
							break
						end
						K.afterimage(c, WATER, 0.25)
						task.wait(0.05)
					end
				end)
			end)
		end)
	elseif data.phase == "Impact" then
		local p = data.p or cr.Position
		local look = cr.CFrame.LookVector
		local g = K.groundPos(p)
		K.impactFrames("WBWB", 0.045)
		K.slowmo({ c, v }, 0.12)
		if st.killWave then
			task.delay(0.12, st.killWave)
		end
		K.shake(2)
		K.fov(14)
		K.flash(FOAM, 0.35, 0.6)
		K.layer({ { SFX.Splash, 1.4 }, { "Explosion", 1.1 }, { SFX.Boom, 1.3, 0.9 }, { "Bass", 1.2, 1, 0.05 }, { SFX.Dive, 1.1, 0.8, 0.1 } }, p)
		-- caméra 4 : plan large 3/4, la victime part en vol plané
		K.shot(data, "fixed", { pos = camSafe(p, p - look * 6 + cr.CFrame.RightVector * 14 + Vector3.new(0, 5, 0)), lookAt = p + look * 5 + Vector3.new(0, 2, 0), fov = 74 })
		K.bigImpact(p, look, 1.6, WATER)
		K.sphere(p, 13, FOAM, 0.35, 3)
		local dome = K.part({ Shape = K.BALL, Size = Vector3.one * 5, Position = g, Color = WATER, Transparency = 0.45 }, 0.8)
		K.tween(dome, 0.5, { Size = Vector3.new(22, 9, 22), Transparency = 1 })
		for i = 0, 2 do
			task.delay(i * 0.08, function()
				K.shockwave(g + Vector3.new(0, 0.2 + i * 0.05, 0), 14 + i * 7, i == 1 and FOAM or WATER)
			end)
		end
		K.ring(CFrame.lookAt(p, p + look), 18, FOAM, 0.4, 0.6)
		K.debris(g, 6, { WATER, FOAM, JBLUE }, 1.3, 1.2)
		splash(K, p, 18, 1.5)
		K.light(p, WATER, 40, 8, 0.6)
		K.word(p + Vector3.new(0, 6, 0), "INDUSTRIAL FLOOD!", 1.6, "Heavy")
		puddle(K, data, g, 13, 2.5)
		-- pluie de gouttes qui retombent
		for _ = 1, 16 do
			local d0 = g + Vector3.new(K.rng:NextNumber(-10, 10), K.rng:NextNumber(10, 16), K.rng:NextNumber(-10, 10))
			local d = K.part({ Shape = K.BALL, Size = Vector3.one * K.rng:NextNumber(0.4, 0.8), Position = d0, Color = WATER, Transparency = 0.2 }, 1.2)
			K.tween(d, K.rng:NextNumber(0.6, 1.0), { Position = Vector3.new(d0.X, g.Y + 0.3, d0.Z) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		K.anim(c, { { t = 0 }, { t = 0.08, RS = { p = 2.9, r = -0.3 }, LS = { p = 0.4, r = -0.7 }, RJ = { ln = -0.2, tw = 0.3 }, RH = { p = -0.3 }, LH = { p = 0.4 } }, { t = 0.6, RS = { p = 2.9, r = -0.3 }, LS = { p = 0.4, r = -0.7 }, RJ = { ln = -0.2, tw = 0.3 }, RH = { p = -0.3 }, LH = { p = 0.4 } }, { t = 0.75 } })
	end
end

return ULT
