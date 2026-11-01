--[[
	ULTIME — The Temp : « CONTRACT TERMINATED »
	Il disparaît dans un nuage d'encre et réapparaît sur la cible. Touché → blizzard de post-it, 6 clones en post-it
	surgissent en cercle et traversent la victime l'un après l'autre (entailles, coupes de caméra), puis le Temp
	réapparaît au-dessus d'elle avec une agrafeuse géante : une agrafe colossale s'abat et la PLAQUE au sol (cratère).
	Raté → il réapparaît dans un nuage de papier, un post-it lui tombe dessus : « WRONG DEPARTMENT ».
]]
local INDIGO = Color3.fromRGB(95, 85, 255)
local INDIGO2 = Color3.fromRGB(160, 150, 255)
local INK = Color3.fromRGB(30, 28, 45)
local NOTE = Color3.fromRGB(255, 230, 70)
local NOTE2 = Color3.fromRGB(255, 160, 200)
local PAPER = Color3.fromRGB(245, 242, 232)
local STEEL = Color3.fromRGB(200, 205, 215)
local DARKSTEEL = Color3.fromRGB(70, 72, 85)

local T = { Cut = { 0.35, 0.55, 0.75, 0.95, 1.15, 1.35 }, Rise = 1.6, Slam = 2.35, End = 3.2 }
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

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local A = {}
A.Vanish = { -- sceau des mains puis plongeon
	{ t = 0 },
	{ t = 0.08, RS = { p = 1.7, y = 0.7 }, LS = { p = 1.7, y = -0.7 }, RJ = { ln = 0.4 }, RH = { p = 0.8 }, LH = { p = 0.8 } },
	{ t = 0.18, RS = { p = -1.3, r = -0.3 }, LS = { p = -1.3, r = 0.3 }, RJ = { ln = 0.9 }, RH = { p = -0.9 }, LH = { p = 1.2 } },
	{ t = 0.5 },
}
local function slashAnim(s)
	return {
		{ t = 0 },
		{ t = 0.04, RS = { p = 1.3, y = -1.1 * s, r = 0.6 * s }, LS = { p = -0.6, r = -0.3 }, RJ = { ln = 0.4, tw = 0.8 * s }, RH = { p = -0.6 * s }, LH = { p = 0.6 * s } },
		{ t = 0.1, RS = { p = 1.6, y = 1.2 * s, r = -0.4 * s }, LS = { p = -0.8, r = -0.3 }, RJ = { ln = 0.55, tw = -0.9 * s, sd = 0.12 * s }, RH = { p = 0.7 * s }, LH = { p = -0.7 * s } },
		{ t = 0.2, RS = { p = 1.5, y = 1.1 * s, r = -0.4 * s }, LS = { p = -0.8, r = -0.3 }, RJ = { ln = 0.5, tw = -0.8 * s }, RH = { p = 0.6 * s }, LH = { p = -0.6 * s } },
	}
end
A.SlashL = slashAnim(-1)
A.SlashR = slashAnim(1)
A.Raise = { -- agrafeuse géante levée à deux mains, cambré, genoux repliés (en l'air)
	{ t = 0 },
	{ t = 0.2, RS = { p = 3.1, r = -0.15 }, LS = { p = 3.1, r = 0.15 }, RJ = { ln = -0.55 }, RH = { p = 1.2 }, LH = { p = 0.6 } },
	{ t = 0.7, RS = { p = 3.2, r = -0.15 }, LS = { p = 3.2, r = 0.15 }, RJ = { ln = -0.65 }, RH = { p = 1.3 }, LH = { p = 0.7 } },
}
A.Slam = {
	{ t = 0 },
	{ t = 0.1, RS = { p = 0.6, y = 0.2 }, LS = { p = 0.6, y = -0.2 }, RJ = { ln = 1.1 }, RH = { p = 1.3 }, LH = { p = -0.5 } },
	{ t = 0.6, RS = { p = 0.65, y = 0.2 }, LS = { p = 0.65, y = -0.2 }, RJ = { ln = 1.0 }, RH = { p = 1.2 }, LH = { p = -0.45 } },
	{ t = 0.85 },
}
A.Whiff = { -- se gratte la tête, perdu
	{ t = 0 },
	{ t = 0.15, RS = { p = 2.9, y = 0.4, r = 0.3 }, LS = { p = 0.6, r = 0.6, y = -0.4 }, RJ = { sd = 0.15, ln = -0.05 } },
	{ t = 0.7, RS = { p = 2.8, y = 0.5, r = 0.3 }, LS = { p = 0.6, r = 0.6, y = -0.4 }, RJ = { sd = -0.1, ln = -0.05 } },
	{ t = 0.9 },
}
A.VJolt = { { t = 0 }, { t = 0.05, RS = { p = 0.6, r = 0.4 }, LS = { p = 0.6, r = -0.4 }, RJ = { ln = -0.4, sd = 0.2 } }, { t = 0.18 } }
A.VJolt2 = { { t = 0 }, { t = 0.05, RS = { p = 0.6, r = 0.4 }, LS = { p = 0.6, r = -0.4 }, RJ = { ln = 0.35, sd = -0.2 } }, { t = 0.18 } }

------------------------------------------------------------------------
local RunService = game:GetService("RunService")
local function play(K, ch, frames)
	if ch and ch.Parent and ch:FindFirstChild("Torso") then
		pcall(K.anim, ch, frames)
	end
end
local function run(dur, fn)
	task.spawn(function()
		local t0 = os.clock()
		while true do
			local a = math.clamp((os.clock() - t0) / dur, 0, 1)
			local ok = pcall(fn, a)
			if not ok or a >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
end
local function rootPos(m, fallback)
	local r = m and m:FindFirstChild("HumanoidRootPart")
	return r and r.Position or fallback
end
-- fumée d'encre indigo
local function inkPuff(K, pos, n, r)
	for _ = 1, n do
		local off = Vector3.new(K.rng:NextNumber(-r, r), K.rng:NextNumber(-r * 0.4, r), K.rng:NextNumber(-r, r))
		local s = K.rng:NextNumber(1.4, 2.6)
		local b = K.part({ Shape = K.BALL, Size = Vector3.one * s, CFrame = CFrame.new(pos + off * 0.3), Color = (K.rng:NextNumber() < 0.5) and INDIGO or INK, Transparency = 0.2 }, 0.8)
		K.tween(b, 0.7, { Size = Vector3.one * s * 2.3, CFrame = CFrame.new(pos + off + Vector3.new(0, 1.2, 0)), Transparency = 1 }, Enum.EasingStyle.Quad)
	end
end
local function noteBurst(K, pos, n, dist, life)
	local cols = { NOTE, NOTE, NOTE2, PAPER }
	for _ = 1, n do
		local d = Vector3.new(K.rng:NextNumber(-1, 1), K.rng:NextNumber(-0.3, 1), K.rng:NextNumber(-1, 1))
		if d.Magnitude < 0.1 then
			d = Vector3.yAxis
		end
		local p = K.part({ Size = Vector3.new(0.7, 0.04, 0.7), CFrame = CFrame.new(pos) * CFrame.Angles(K.rng:NextNumber(0, 6), K.rng:NextNumber(0, 6), 0), Color = cols[K.rng:NextInteger(1, #cols)] }, life + 0.1)
		K.tween(p, life, { CFrame = CFrame.new(pos + d.Unit * dist * K.rng:NextNumber(0.5, 1)) * CFrame.Angles(K.rng:NextNumber(0, 6), K.rng:NextNumber(0, 6), 0), Transparency = 1 }, Enum.EasingStyle.Quad)
	end
end
-- clone en post-it (silhouette)
local function doll(K, data, cf)
	local defs = {
		{ Vector3.new(2, 2, 0.35), CFrame.new(0, 0, 0), NOTE }, { Vector3.new(1.2, 1.2, 0.35), CFrame.new(0, 1.6, 0), NOTE2 },
		{ Vector3.new(0.9, 2, 0.3), CFrame.new(-1.5, 0.2, 0) * CFrame.Angles(0, 0, -0.3), NOTE }, { Vector3.new(0.9, 2, 0.3), CFrame.new(1.5, 0.6, -0.4) * CFrame.Angles(1.3, 0, 0.2), NOTE },
		{ Vector3.new(0.9, 2, 0.3), CFrame.new(-0.6, -2, 0.3) * CFrame.Angles(0.4, 0, 0), NOTE }, { Vector3.new(0.9, 2, 0.3), CFrame.new(0.6, -1.9, -0.4) * CFrame.Angles(-0.5, 0, 0), NOTE },
		{ Vector3.new(1.3, 0.22, 0.42), CFrame.new(0, 1.95, 0), INDIGO, Enum.Material.Neon },
		{ Vector3.new(0.12, 0.08, 1.8), CFrame.new(1.5, 0.6, -1.9) * CFrame.Angles(0.2, 0, 0), INDIGO2, Enum.Material.Neon }, -- coupe-papier lumineux
	}
	local list = {}
	for _, d in ipairs(defs) do
		local p = K.part({ Size = d[1], CFrame = cf * d[2], Color = d[3], Material = d[4] or Enum.Material.SmoothPlastic, Transparency = 1 }, 4)
		K.track(data, p)
		table.insert(list, { p = p, off = d[2] })
	end
	local o = {}
	function o.place(c)
		for _, e in ipairs(list) do
			e.p.CFrame = c * e.off
		end
	end
	function o.fade(t, a)
		for _, e in ipairs(list) do
			K.tween(e.p, t, { Transparency = a })
		end
	end
	return o
end

------------------------------------------------------------------------
local M = {
	Name = "CONTRACT TERMINATED",
	-- v3 : titres de temps forts (UltimateController) ; Anticipate = poses d'armement avant ces coups
	Beats = { Connect = { { 0, "POST-IT BLIZZARD" }, { T.Cut[1], "TEMP CLONES" }, { T.Rise, "STAPLED" } } },
	Desc = "Vanish, surround them with sticky-note clones that slice through one by one, then staple them into the floor for good.",
	Color = INDIGO,
	Color2 = NOTE,
	Range = 26,
	Angle = 70,
	Timing = T,
}

function M.Client(K, data)
	local caster, target = data.caster, data.target
	local phase = data.phase

	if phase == "Cutin" then
		local r = K.root(caster)
		if r then
			play(K, caster, A.Vanish)
			K.sound(K.SFX.Charge, r.Position, 0.8, 1.2)
			K.at(data, 0.35, function()
				noteBurst(K, r.Position, 18, 6, 0.8)
				K.ring(CFrame.lookAt(r.Position - Vector3.new(0, 2.8, 0), r.Position + Vector3.new(0, 5, 0)), 10, INDIGO, 0.5, 0.3)
				K.light(r.Position, INDIGO, 20, 5, 0.6)
			end)
		end
		return
	end

	if phase == "Rush" then
		local r = K.root(caster)
		if not r then
			return
		end
		play(K, caster, A.Vanish)
		K.sound("Teleport", r.Position, 1, 1)
		inkPuff(K, r.Position, 8, 2)
		noteBurst(K, r.Position, 14, 5, 0.6)
		K.afterimage(caster, INDIGO, 0.5, 0.3)
		if K.isCaster(data) then
			K.speedLines(0.4, INDIGO2)
		end
		return
	end

	if phase == "Whiff" then
		local r = K.root(caster)
		if r then
			play(K, caster, A.Whiff)
			inkPuff(K, r.Position, 5, 1.5)
			K.sound("SlideWhistle", r.Position, 0.9, 0.9)
			-- un post-it lui tombe sur la tête
			local n = K.part({ Size = Vector3.new(1.4, 0.05, 1.4), CFrame = CFrame.new(r.Position + Vector3.new(0, 7, 0)), Color = NOTE }, 1.2)
			K.tween(n, 0.5, { CFrame = CFrame.new(r.Position + Vector3.new(0, 2.05, 0)) * CFrame.Angles(0, 0.4, 0) }, Enum.EasingStyle.Bounce)
			K.word(r.Position + Vector3.new(0, 5, 0), "WRONG DEPARTMENT...", 1.0, "Light")
		end
		return
	end

	if phase ~= "Connect" then
		return
	end
	K.letterbox(data, true, 0.2)
	local cf = data.cf or CFrame.new()
	local vp0 = data.vp or (cf.Position + cf.LookVector * 4)
	local look, right, up = cf.LookVector, cf.RightVector, Vector3.yAxis
	local function vp()
		return rootPos(target, vp0)
	end
	K.impactFrames("W", 0.05)
	K.sound(K.SFX.Hit, vp0, 1, 1)
	K.sound(K.SFX.Sting, nil, 0.5, 1.1)
	K.darken(true, 0.45, 0.25)
	K.word(vp0 + up * 4, "YOU'RE NOT ON THE LIST.", 0.9, "Light")
	K.shot(data, "orbit", { at = function() return vp() end, radius = 13, height = 4, angle = 200, speed = 70, basis = cf, fov = 62 })

	-- blizzard de post-it en spirale autour de la victime
	local swirl = {}
	for i = 1, 26 do
		local p = K.part({ Size = Vector3.new(0.7, 0.04, 0.7), Color = (i % 4 == 0) and NOTE2 or NOTE }, 4)
		K.track(data, p)
		swirl[i] = { p = p, a = i * 0.24 * math.pi, h = (i % 7) * 0.8 - 2, r = 3 + (i % 3) }
	end
	run(T.Slam, function(a)
		local c = vp()
		local el = a * T.Slam
		for _, s in ipairs(swirl) do
			local ang = s.a + el * 4
			local rr = s.r * (1 - a * 0.4)
			s.p.CFrame = CFrame.new(c + Vector3.new(math.cos(ang) * rr, s.h + math.sin(el * 3 + s.a), math.sin(ang) * rr)) * CFrame.Angles(el * 5, ang, 0.4)
		end
	end)

	-- 6 clones en cercle, qui traversent la victime chacun à leur tour
	local clones = {}
	for i = 1, 6 do
		local ang = math.rad(i * 60 + 15)
		local p = vp0 + Vector3.new(math.sin(ang) * 6, 0, -math.cos(ang) * 6)
		local ccf = CFrame.lookAt(p, Vector3.new(vp0.X, p.Y, vp0.Z))
		clones[i] = { o = doll(K, data, ccf), cf = ccf, ang = ang }
		K.at(data, 0.05 + i * 0.03, function()
			clones[i].o.fade(0.12, 0.05)
			inkPuff(K, p, 2, 1)
		end)
	end
	K.at(data, 0.15, function()
		K.sound("Whoosh", vp0, 1, 1.3)
		K.word(vp0 + up * 5.5, "CLONE PROTOCOL", 0.9, "Light")
	end)
	local cams = {
		[3] = { pos = vp0 - look * 3 + up * 0.5 - right * 6, at = vp0 + up * 0.8, fov = 58 },
		[5] = { pos = vp0 + up * 9 + look * 1, at = vp0, fov = 70 },
	}
	for i, at in ipairs(T.Cut) do
		K.at(data, at - 0.06, function()
			local cl = clones[i]
			local c = vp()
			local from = cl.cf.Position
			local to = c + (c - from).Unit * 6
			to = Vector3.new(to.X, from.Y, to.Z)
			run(0.08, function(a)
				cl.o.place(CFrame.lookAt(from:Lerp(to, a), to) * CFrame.Angles(-0.3, 0, 0))
			end)
			K.streak(from, to, (i % 2 == 0) and INDIGO2 or NOTE, 1.4, 0.25)
			if cams[i] then
				K.shot(data, "fixed", { pos = cams[i].pos, lookAt = cams[i].at, fov = cams[i].fov })
			end
		end)
		K.at(data, at, function()
			local c = vp()
			local cl = clones[i]
			play(K, caster, (i % 2 == 0) and A.SlashR or A.SlashL)
			play(K, target, (i % 2 == 0) and A.VJolt or A.VJolt2)
			K.slashArc(CFrame.lookAt(c, c + (c - cl.cf.Position)) * CFrame.Angles(0, 0, (i % 2 == 0) and 0.8 or -0.8), 4.2, (i % 2 == 0) and INDIGO2 or PAPER)
			K.sparks(c, 10, INDIGO2)
			K.shards(c, 8, { PAPER, NOTE, INDIGO }, 1.2)
			K.sound("Punch", c, 1, 0.9 + i * 0.06)
			K.sound(K.SFX.Whoosh2, c, 0.7, 1.2)
			K.shake(0.45 + i * 0.05)
			K.impactFrames((i == 6) and "BW" or "W", 0.035)
			K.word(c + up * 2.5 + right * ((i % 2 == 0) and 2 or -2), ({ "SNIP!", "SLICE!", "FWIP!", "CUT!", "SNIKT!", "FILED!" })[i], 0.9 + i * 0.05, "Heavy")
			K.afterimage(caster, INDIGO, 0.35, 0.35)
			K.at(data, at + 0.12, function()
				cl.o.fade(0.15, 1)
				noteBurst(K, c + (c - cl.cf.Position).Unit * 6, 8, 3, 0.5)
			end)
		end)
	end

	-- l'agrafeuse géante au-dessus de la victime
	K.at(data, T.Rise, function()
		play(K, caster, A.Raise)
		local c = vp()
		inkPuff(K, c + up * 7 - look * 2, 3, 1.2)
		K.sound("Teleport", c, 1, 0.8)
		K.sound(K.SFX.Charge2, c, 0.9, 1)
		K.shot(data, "fixed", { pos = c + look * 3.5 + right * 3 + up * 0.5, lookAt = c + up * 8, fov = 72 })
		if K.involved(data) then
			K.cutin(data, { title = "YOUR CONTRACT IS...", sub = "CONTRACT TERMINATED", color = INDIGO, color2 = NOTE, dur = 0.6, small = true })
		end
		-- agrafeuse géante tenue à deux mains (soudée au bras droit)
		if caster and caster:FindFirstChild("Right Arm") then
			local base = K.prop(data, caster, "Right Arm", Vector3.new(1.4, 1.0, 6.5), CFrame.new(-0.5, -1.2, -2.8), DARKSTEEL)
			K.prop(data, caster, "Right Arm", Vector3.new(1.2, 1.1, 6.2), CFrame.new(-0.5, -0.2, -2.7), INDIGO, nil, Enum.Material.SmoothPlastic)
			K.prop(data, caster, "Right Arm", Vector3.new(1.0, 0.3, 1.2), CFrame.new(-0.5, -0.3, -5.6), STEEL, nil, Enum.Material.Metal)
			K.prop(data, caster, "Right Arm", Vector3.new(0.6, 0.6, 0.6), CFrame.new(-0.5, -0.7, 0.3), STEEL, K.BALL, Enum.Material.Metal)
		end
		K.implode(c + up * 7, 7, { INDIGO, NOTE, K.WHITE }, 16, 0.6)
		K.light(c + up * 7, INDIGO, 30, 6, 0.8)
	end)
	-- l'agrafe colossale tombe
	local staple = {}
	K.at(data, T.Slam - 0.18, function()
		local c = vp()
		local g = K.groundPos(c)
		local scf = CFrame.lookAt(g, g + right)
		local defs = {
			{ Vector3.new(7, 0.7, 0.7), CFrame.new(0, 4.2, 0) },
			{ Vector3.new(0.7, 4.6, 0.7), CFrame.new(3.15, 2.0, 0) },
			{ Vector3.new(0.7, 4.6, 0.7), CFrame.new(-3.15, 2.0, 0) },
		}
		for _, d in ipairs(defs) do
			local p = K.part({ Size = d[1], CFrame = scf * d[2] * CFrame.new(0, 14, 0), Color = STEEL, Material = Enum.Material.Metal }, 3)
			K.track(data, p)
			table.insert(staple, p)
			K.tween(p, 0.18, { CFrame = scf * d[2] * CFrame.new(0, -1.2, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
		K.sound(K.SFX.Whoosh3, c, 1.4, 0.7)
		K.shot(data, "fixed", { pos = c - look * 9 + right * 7 + up * 4, lookAt = c + up * 1.5, fov = 64 })
	end)
	K.at(data, T.Slam, function()
		local c = vp()
		local g = K.groundPos(c)
		play(K, caster, A.Slam)
		K.impactFrames("BWBWB", 0.045)
		K.layer({ { "Boom", 1.6 }, { "Bass", 1.4, 0.85 }, { "Explosion", 1.1, 1, 0.03 }, { "MetalHit", 1.6, 0.7 }, { "GroundSlam", 1.3, 0.8, 0.05 } }, c)
		K.shake(2.0)
		K.fov(12)
		K.crater(g, 10, INDIGO, 3)
		K.quake(g, 12, INDIGO, 1.2)
		K.shockwave(g + up * 0.3, 18, INDIGO)
		K.shockwave(g + up * 0.4, 10, NOTE)
		K.sphere(c, 12, INDIGO2, 0.35, 3)
		K.light(c, INDIGO, 45, 10, 0.5)
		K.debris(g, 8, { DARKSTEEL, INDIGO, PAPER }, 1.4, 1.1)
		noteBurst(K, c + up, 40, 12, 1.2)
		K.word(c + up * 6, "TERMINATED!!", 2.0, "Heavy")
		K.darken(false, 0, 0.4)
		for _, s in ipairs(swirl) do
			if s.p.Parent then
				K.tween(s.p, 0.5, { CFrame = s.p.CFrame + (s.p.Position - c).Unit * 6, Transparency = 1 })
			end
		end
		K.at(data, T.Slam + 0.6, function()
			for _, p in ipairs(staple) do
				K.tween(p, 0.35, { Transparency = 1 })
			end
		end)
		K.shot(data, "orbit", { at = c, radius = 15, height = 6, angle = 40, speed = 25, basis = cf, fov = 66 })
	end)
	K.at(data, T.Slam + 0.45, function()
		K.word(vp0 + up * 3 + right * 3, "CLEAR YOUR DESK.", 1.0, "Light")
	end)
end

function M.Server(U, caster, target, ctx)
	U.fx(ctx, "Rush")
	if not U.rush(ctx, target, { speed = 150, contact = 4.5, maxTime = 0.4 }) then
		U.fx(ctx, "Whiff")
		U.wait(ctx, 0.85)
		return
	end
	local vr = U.root(target)
	local cf = U.currentCF(ctx, caster)
	local look = U.flat(vr.Position - cf.Position, cf.LookVector)
	cf = CFrame.lookAt(cf.Position, cf.Position + look)
	local vp = vr.Position
	U.hold(ctx, target, U.facing(vp, cf.Position))
	U.fx(ctx, "Connect", { cf = cf, vp = vp })
	local tc = os.clock()
	local function at(t)
		return U.wait(ctx, math.max(0, t - (os.clock() - tc)))
	end
	for i, t in ipairs(T.Cut) do
		if not at(t) then
			return
		end
		-- le Temp clignote autour de la victime à chaque entaille
		local pos = U.wallSafe(vp, U.around(vp, i * 60 + 195, 4.5, 0), 1.5)
		U.place(ctx, caster, U.facing(pos, vp))
		U.hit(ctx, target, 2.5, { power = 0.4 + i * 0.05, words = { "SNIP!", "SLICE!", "CUT!" }, stun = 0.6 })
	end
	if not at(T.Rise) then
		return
	end
	local h = math.clamp(U.headroom(vp, 9), 2, 7)
	local top = vp - look * 1.5 + Vector3.new(0, h, 0)
	U.place(ctx, caster, CFrame.lookAt(top, top + look))
	if not at(T.Slam - 0.12) then
		return
	end
	local land = U.wallSafe(vp, vp - look * 2.6, 1)
	U.glide(ctx, caster, U.facing(land, vp), 0.12, "In")
	if not at(T.Slam) then
		return
	end
	U.finish(ctx, target, 20, { pin = true, words = { "TERMINATED!" }, splash = { radius = 12, damage = 10, center = vp } })
	at(T.End)
end

return M
