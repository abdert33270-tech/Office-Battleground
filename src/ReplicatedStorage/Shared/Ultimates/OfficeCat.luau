--[[
	ULTIME — The Office Cat : « CAT-ASTROPHE »
	Bond sur la cible. Touché → un point laser rouge se pose sur la victime, le chat part en ZOOMIES : 9 coups de griffes
	depuis 9 directions (un par vie, comptés à l'écran), il saute en l'air et invoque une PATTE DE CHAT GÉANTE qui descend
	du ciel et écrase la victime (finisher PIN + cratère + empreinte de patte), puis il s'assoit et se lèche la patte.
	Raté → il se fait distraire par un point laser et tourne après sa queue.
]]
local GINGER = Color3.fromRGB(255, 150, 50)
local STRIPE = Color3.fromRGB(205, 95, 25)
local CREAM = Color3.fromRGB(255, 238, 205)
local PINK = Color3.fromRGB(255, 140, 175)
local WHITE = Color3.fromRGB(250, 250, 250)
local LASER = Color3.fromRGB(255, 35, 45)
local GOLD = Color3.fromRGB(255, 205, 50)
local FUR = { GINGER, STRIPE, CREAM, PINK }

local SND = {
	Meow = "rbxassetid://134699420140804",
	Meow2 = "rbxassetid://136138461897866",
	Hiss = "rbxassetid://71522230632243",
}

local T = { Tackle = 0.12, Zoom0 = 0.45, ZoomStep = 0.11, Leap = 1.5, Paw0 = 1.6, Slam = 2.1, Land = 2.45, End = 3.3 }

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local A = {}
A.Pounce = {
	{ t = 0 },
	{ t = 0.08, RS = { p = 3.0, r = -0.3 }, LS = { p = 3.0, r = 0.3 }, RJ = { ln = 0.5 }, RH = { p = -0.8 }, LH = { p = -0.8 } },
	{ t = 0.4, RS = { p = 2.8, r = -0.4 }, LS = { p = 2.8, r = 0.4 }, RJ = { ln = 0.6 }, RH = { p = -0.7 }, LH = { p = -0.6 } },
	{ t = 0.5 },
}
A.SwipeR = {
	{ t = 0 },
	{ t = 0.04, RS = { p = 2.9, y = 0.5 }, LS = { p = 1.0, y = -0.5 }, RJ = { tw = -0.45, ln = 0.4 }, RH = { p = 0.4 }, LH = { p = -0.3 } },
	{ t = 0.1, RS = { p = 1.0, y = -0.9 }, LS = { p = 1.0, y = -0.5 }, RJ = { tw = 0.5, ln = 0.55 }, RH = { p = -0.5 }, LH = { p = 0.6 } },
	{ t = 0.16 },
}
A.SwipeL = {
	{ t = 0 },
	{ t = 0.04, LS = { p = 2.9, y = -0.5 }, RS = { p = 1.0, y = 0.5 }, RJ = { tw = 0.45, ln = 0.4 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
	{ t = 0.1, LS = { p = 1.0, y = 0.9 }, RS = { p = 1.0, y = 0.5 }, RJ = { tw = -0.5, ln = 0.55 }, RH = { p = 0.6 }, LH = { p = -0.5 } },
	{ t = 0.16 },
}
A.Summon = { -- en l'air, pattes levées vers le ciel, puis les abat avec la patte géante
	{ t = 0 },
	{ t = 0.1, RS = { p = 3.1, r = -0.25 }, LS = { p = 3.1, r = 0.25 }, RJ = { ln = -0.45 }, RH = { p = 1.2 }, LH = { p = 1.2 } },
	{ t = 0.52, RS = { p = 3.14, r = -0.2 }, LS = { p = 3.14, r = 0.2 }, RJ = { ln = -0.55 }, RH = { p = 1.35 }, LH = { p = 1.35 } },
	{ t = 0.6, RS = { p = 0.6 }, LS = { p = 0.6 }, RJ = { ln = 0.85 }, RH = { p = 0.9 }, LH = { p = 0.9 } },
	{ t = 0.9, RS = { p = 0.65 }, LS = { p = 0.65 }, RJ = { ln = 0.75 }, RH = { p = 0.85 }, LH = { p = 0.85 } },
	{ t = 1.0 },
}
local function lickAnim()
	local f = { { t = 0 }, { t = 0.15, RS = { p = 2.4, y = 0.9 }, LS = { p = 0.3, r = 0.3 }, RJ = { ln = 0.15, sd = 0.1 }, RH = { p = 1.3 }, LH = { p = 1.3 } } }
	for i = 1, 5 do -- se lèche la patte, très fier
		local up = i % 2 == 1
		table.insert(f, { t = 0.15 + i * 0.13, RS = { p = up and 2.7 or 2.35, y = up and 1.05 or 0.85 }, LS = { p = 0.3, r = 0.3 }, RJ = { ln = up and 0.25 or 0.12, sd = 0.1 }, RH = { p = 1.3 }, LH = { p = 1.3 } })
	end
	table.insert(f, { t = 1.0 })
	return f
end
A.Lick = lickAnim()
local function whiffAnim()
	local f = { { t = 0 }, { t = 0.08, RS = { p = 1.0 }, LS = { p = 1.0 }, RJ = { ln = 0.8 }, RH = { p = 0.8 }, LH = { p = 0.8 } } }
	for i = 1, 8 do -- tourne après sa queue
		table.insert(f, { t = 0.08 + i * 0.09, RS = { p = 1.0 }, LS = { p = 1.0 }, RJ = { ln = 0.8, tw = i * 1.57 }, RH = { p = 0.8 + 0.2 * (i % 2) }, LH = { p = 0.8 - 0.2 * (i % 2) } })
	end
	table.insert(f, { t = 0.81, RJ = { tw = 0 } })
	table.insert(f, { t = 1.05, RS = { p = 0.3, r = -0.6 }, LS = { p = 0.3, r = 0.6 }, RJ = { sd = 0.2 } })
	table.insert(f, { t = 1.25 })
	return f
end
A.Whiff = whiffAnim()
local function flailAnim(dur)
	local f = { { t = 0 } }
	local t, s = 0, 1
	while t < dur do
		t += 0.11
		s = -s
		table.insert(f, { t = t, RS = { p = 2.2 + 0.6 * s, r = -0.5 }, LS = { p = 2.2 - 0.6 * s, r = -0.5 }, RJ = { ln = -0.25, sd = 0.18 * s, tw = 0.25 * s }, RH = { p = 0.4 * s }, LH = { p = -0.4 * s } })
	end
	table.insert(f, { t = dur + 0.1 })
	return f
end
A.VFlail = flailAnim(1.5)
A.VSquash = { { t = 0 }, { t = 0.08, RS = { p = 0.3, r = -1.4 }, LS = { p = 0.3, r = 1.4 }, RJ = { ln = 0.4 }, RH = { p = 0.9 }, LH = { p = 0.9 } }, { t = 0.5, RS = { p = 0.3, r = -1.4 }, LS = { p = 0.3, r = 1.4 }, RJ = { ln = 0.4 }, RH = { p = 0.9 }, LH = { p = 0.9 } }, { t = 0.6 } }

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

-- empreinte de patte au sol (disques roses), dure life secondes
local function pawPrint(K, data, pos, look, scale, life)
	local base = CFrame.lookAt(pos, pos + look)
	local function disc(x, z, d)
		local p = K.part({ Shape = K.CYL, Size = Vector3.new(0.1, d * scale, d * scale), CFrame = base * CFrame.new(x * scale, 0.1, z * scale) * K.UPRIGHT, Color = PINK }, life)
		K.track(data, p)
		task.delay(life - 0.4, function()
			if p.Parent then
				K.tween(p, 0.35, { Transparency = 1 })
			end
		end)
	end
	disc(0, 0.4, 2.4)
	for _, o in ipairs({ { -1.15, -0.8 }, { -0.42, -1.45 }, { 0.42, -1.45 }, { 1.15, -0.8 } }) do
		disc(o[1], o[2], 0.95)
	end
end

------------------------------------------------------------------------
local M = {
	Name = "CAT-ASTROPHE",
	Desc = "Pounce, 9 zoomies claw strikes (one per life), then a GIANT paw from the sky flattens them.",
	Color = GINGER,
	Color2 = CREAM,
	Range = 24,
	Angle = 70,
	Timing = T,
}

function M.Client(K, data)
	local caster, target = data.caster, data.target
	local phase = data.phase

	if phase == "Cutin" then
		local r = K.root(caster)
		if r then
			K.sound(SND.Hiss, r.Position, 0.9, 1)
			K.at(data, 0.45, function()
				K.sound(SND.Meow, r.Position, 1, 0.9)
				K.shards(r.Position + Vector3.new(0, 2, 0), 12, FUR, 0.9)
			end)
		end
		return
	end

	if phase == "Rush" then
		play(K, caster, A.Pounce)
		local r = K.root(caster)
		if not r then
			return
		end
		K.sound("Whoosh2", r.Position, 1, 1.1)
		K.sound(SND.Meow2, r.Position, 0.9, 1.3)
		for i = 0, 4 do
			K.at(data, i * 0.08, function()
				local rr = K.root(caster)
				if rr then
					K.afterimage(caster, i % 2 == 0 and GINGER or CREAM, 0.25, 0.5)
					K.shards(rr.Position, 3, FUR, 0.4)
				end
			end)
		end
		return
	end

	if phase == "Whiff" then
		local r = K.root(caster)
		if not r then
			return
		end
		K.at(data, 0.15, function()
			play(K, caster, A.Whiff)
			local g = K.groundPos(r.Position)
			local dot = K.part({ Shape = K.CYL, Size = Vector3.new(0.1, 0.9, 0.9), CFrame = CFrame.new(g) * K.UPRIGHT, Color = LASER, Material = Enum.Material.Neon }, 1.1)
			K.track(data, dot)
			run(0.9, function(a)
				local rr = K.root(caster)
				local c = rr and K.groundPos(rr.Position) or g
				local ang = a * math.pi * 6
				dot.CFrame = CFrame.new(c + Vector3.new(math.cos(ang) * 2.5, 0.1, math.sin(ang) * 2.5)) * K.UPRIGHT
			end)
			K.word(r.Position + Vector3.new(0, 4, 0), "RED DOT?!", 1.0, "Light")
		end)
		K.at(data, 1.0, function()
			local rr = K.root(caster)
			if rr then
				K.sound(SND.Meow2, rr.Position, 1, 0.8)
				K.word(rr.Position + Vector3.new(0, 4, 0), "...MEOW?", 1.1, "Light")
				K.CFX.dizzy(caster, 0.6)
			end
		end)
		return
	end

	if phase == "Zoom" then
		local i = data.i or 0
		local vp = rootPos(target, data.vp or data.p)
		local p = data.p
		play(K, caster, (i % 2 == 0) and A.SwipeR or A.SwipeL)
		if data.prev then
			K.streak(data.prev, p, (i % 2 == 0) and GINGER or CREAM, 1.5, 0.22)
		end
		K.afterimage(caster, (i % 2 == 0) and GINGER or STRIPE, 0.25, 0.45)
		K.slashArc(CFrame.lookAt(p, vp), 4.2, (i % 2 == 0) and GINGER or WHITE, -110, 110, 0.12, (i % 3 - 1) * 35, 0.55)
		K.sparks(vp, 8, (i % 2 == 0) and WHITE or GINGER)
		K.sound(i % 2 == 0 and "Punch" or "Punch2", vp, 0.9, 1 + i * 0.04)
		K.sound("Whoosh", vp, 0.5, 1.4)
		K.shake(0.35)
		K.word(vp + Vector3.new(K.rng:NextNumber(-2, 2), 2.5 + i * 0.25, K.rng:NextNumber(-1, 1)), tostring(i + 1), 0.8 + i * 0.06, "Light")
		if i == 8 then
			K.impactFrames("W", 0.05)
			K.word(vp + Vector3.new(0, 5.5, 0), "NINE LIVES!!", 1.4, "Heavy")
			K.sound(SND.Hiss, vp, 1, 1.1)
		end
		return
	end

	if phase ~= "Connect" then
		return
	end
	K.letterbox(data, true, 0.2)
	----------------------------------------------------------------
	local cf = data.cf
	if not cf then
		local r = K.root(caster)
		cf = r and r.CFrame or CFrame.new()
	end
	local look, right, up = cf.LookVector, cf.RightVector, Vector3.yAxis
	local vp0 = data.vp or (cf.Position + look * 4)
	local function vp()
		return rootPos(target, vp0)
	end
	local function cp()
		return rootPos(caster, cf.Position)
	end
	local g0 = K.groundPos(vp0)

	-- 1) PLAQUAGE + POINT LASER -------------------------------------
	K.shot(data, "fixed", { pos = cp() - look * 4 + right * 5 + up * 1.5, lookAt = vp(), fov = 60 })
	K.at(data, T.Tackle, function()
		local c = vp()
		play(K, target, A.VFlail)
		K.layer({ { "PunchHeavy", 1.2 }, { SND.Meow, 1, 1.1 } }, c)
		K.impactFrames("B", 0.05)
		K.bigImpact(c, look, 1.0, GINGER)
		K.word(c + up * 3, "POUNCE!", 1.2, "Heavy")
		K.shake(0.8)
		-- le point laser rouge se pose sur la victime
		local dot = K.part({ Shape = K.BALL, Size = Vector3.one * 0.6, Color = LASER, Material = Enum.Material.Neon }, 2.2)
		K.track(data, dot)
		local sky = g0 + Vector3.new(-10, 40, 8)
		local beam = K.part({ Size = Vector3.new(0.12, 0.12, 1), Color = LASER, Material = Enum.Material.Neon, Transparency = 0.45 }, 2.2)
		K.track(data, beam)
		run(T.Leap - T.Tackle, function(a)
			local tr = target and target:FindFirstChild("Torso")
			local p = tr and (tr.CFrame * CFrame.new(math.sin(os.clock() * 9) * 0.4, math.cos(os.clock() * 7) * 0.4, -0.6)).Position or vp()
			dot.Position = p
			local len = (p - sky).Magnitude
			beam.Size = Vector3.new(0.12, 0.12, len)
			beam.CFrame = CFrame.lookAt(sky, p) * CFrame.new(0, 0, -len / 2)
			if a >= 1 then
				dot:Destroy()
				beam:Destroy()
			end
		end)
	end)

	-- 2) ZOOMIES : caméra qui tourne vite autour de la victime --------
	K.at(data, T.Zoom0 - 0.1, function()
		K.speedLines(T.Leap - T.Zoom0, GINGER)
		K.shot(data, "orbit", { at = function() return vp() end, radius = 12, height = 3, angle = 40, speed = 170, basis = cf, fov = 66 })
	end)

	-- 3) SAUT + PATTE GÉANTE DU CIEL --------------------------------
	K.at(data, T.Leap, function()
		play(K, caster, A.Summon)
		K.sound("Whoosh3", cp(), 1, 1)
		K.sound(SND.Meow2, cp(), 1, 0.7)
		K.shot(data, "fixed", { pos = g0 - look * 12 + right * 5 + up * 1.2, lookAt = g0 + up * 9, fov = 74 })
	end)
	local paw = {}
	K.at(data, T.Paw0, function()
		local base = CFrame.lookAt(g0, g0 + look)
		local function piece(size, off, color, shape)
			local p = K.part({ Size = size, CFrame = base * CFrame.new(0, 45, 0) * off, Color = color, Shape = shape or Enum.PartType.Block }, 3)
			K.track(data, p)
			table.insert(paw, { p = p, off = off })
		end
		-- coussinets (dessous), moufle crème, bras roux rayé qui monte vers le ciel
		piece(Vector3.new(0.5, 4.6, 4.6), CFrame.new(0, 0.3, 0.6) * K.UPRIGHT, PINK, K.CYL)
		for _, o in ipairs({ { -2.2, -1.6 }, { -0.8, -2.8 }, { 0.8, -2.8 }, { 2.2, -1.6 } }) do
			piece(Vector3.new(0.5, 1.9, 1.9), CFrame.new(o[1], 0.35, o[2]) * K.UPRIGHT, PINK, K.CYL)
		end
		piece(Vector3.one * 8.5, CFrame.new(0, 3.9, 0), CREAM, K.BALL)
		piece(Vector3.new(32, 6, 6), CFrame.new(0, 22, 0.8) * K.UPRIGHT, GINGER, K.CYL)
		for k = 0, 3 do
			piece(Vector3.new(1.2, 6.2, 6.2), CFrame.new(0, 11 + k * 6, 0.8) * K.UPRIGHT, STRIPE, K.CYL)
		end
		-- ombre qui grandit au sol
		local shadow = K.part({ Shape = K.CYL, Size = Vector3.new(0.1, 2, 2), CFrame = CFrame.new(g0 + up * 0.08) * K.UPRIGHT, Color = Color3.fromRGB(20, 15, 15), Transparency = 0.6 }, 1)
		K.track(data, shadow)
		K.tween(shadow, T.Slam - T.Paw0, { Size = Vector3.new(0.1, 10, 10), Transparency = 0.25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		K.sound("Rumble", g0, 1, 1.2)
		K.word(g0 + up * 12, "BOOP INCOMING", 1.0, "Light")
		run(T.Slam - T.Paw0, function(a)
			local y = 45 * (1 - a * a)
			for _, e in ipairs(paw) do
				e.p.CFrame = base * CFrame.new(0, y, 0) * e.off
			end
			if a >= 1 and shadow.Parent then
				shadow:Destroy()
			end
		end)
	end)
	K.at(data, T.Slam, function()
		local c = g0 + up * 1
		play(K, target, A.VSquash)
		K.impactFrames("WBWB", 0.05)
		K.layer({ { "Boom", 1.6 }, { "Bass", 1.4, 0.85 }, { "GroundSlam", 1.3 }, { SND.Meow, 1.2, 0.75, 0.1 } }, c)
		K.shake(2)
		K.fov(12)
		K.crater(c, 10, GINGER, 3)
		K.quake(c, 12, STRIPE, 1.2)
		K.sphere(c, 12, CREAM, 0.35, 3)
		K.light(c, GINGER, 40, 8, 0.5)
		K.debris(c, 10, nil, 1.3, 1.1)
		K.shards(c + up * 2, 18, FUR, 1.6)
		K.word(c + up * 7, "CAT-ASTROPHE!!", 2.0, "Heavy")
		pawPrint(K, data, g0, look, 2.2, 1.2)
		K.shot(data, "orbit", { at = c, radius = 17, height = 6, angle = 25, speed = 25, basis = cf, fov = 66 })
		K.at(data, T.Slam + 0.4, function()
			for _, e in ipairs(paw) do
				if e.p.Parent then
					K.tween(e.p, 0.45, { CFrame = e.p.CFrame + up * 40, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end
			end
		end)
	end)
	-- 4) ASSIS, IL SE LÈCHE LA PATTE -----------------------------------
	K.at(data, T.Land + 0.25, function()
		play(K, caster, A.Lick)
		K.sound(SND.Meow2, cp(), 1, 1.1)
		K.word(cp() + up * 3.5, "=^.^=", 1.1, "Light")
		K.shards(cp() + up * 3, 6, { GOLD, WHITE }, 0.5)
	end)
end

function M.Server(U, caster, target, ctx)
	U.fx(ctx, "Rush")
	if not U.rush(ctx, target, { speed = 115, contact = 4.2, maxTime = 0.5, whiffDist = 16, whiffTime = 0.3 }) then
		U.fx(ctx, "Whiff")
		U.wait(ctx, 1.25)
		return
	end
	local cf = U.currentCF(ctx, caster)
	local vr = U.root(target)
	cf = U.facing(cf.Position, vr.Position)
	U.place(ctx, caster, cf)
	local vp = U.wallSafe(cf.Position, cf.Position + cf.LookVector * 4, 1.5)
	vp = Vector3.new(vp.X, cf.Position.Y, vp.Z)
	local H = math.clamp(U.headroom(vp, 12), 4, 10)
	local vcf = U.facing(vp, cf.Position)
	U.hold(ctx, target, vcf)
	U.fx(ctx, "Connect", { cf = cf, vp = vp, h = H })
	local tc = os.clock()
	local function at(t)
		return U.wait(ctx, math.max(0, t - (os.clock() - tc)))
	end
	if not at(T.Tackle) then
		return
	end
	U.hit(ctx, target, 4, { power = 0.7, words = { "POUNCE!" }, stun = 0.8 })
	-- zoomies : 9 griffures depuis 9 directions
	local prev = cf.Position
	for i = 0, 8 do
		if not at(T.Zoom0 + i * T.ZoomStep) then
			return
		end
		local pos = U.wallSafe(vp, U.around(vp, 180 + i * 140, 3.4, 0, cf), 1)
		pos = Vector3.new(pos.X, vp.Y, pos.Z)
		U.place(ctx, caster, U.facing(pos, vp))
		U.fx(ctx, "Zoom", { i = i, p = pos, prev = prev, vp = vp })
		prev = pos
		U.hit(ctx, target, 2, { power = 0.35, words = { "SCRITCH!", "MREOW!", "SWIPE!", "HISS!" }, stun = 0.6 })
	end
	-- saut au-dessus de la victime pendant que la patte géante descend
	if not at(T.Leap) then
		return
	end
	local behind = U.wallSafe(vp, vp - cf.LookVector * 4, 1)
	U.glide(ctx, caster, U.facing(Vector3.new(behind.X, vp.Y + H - 1.5, behind.Z), vp), 0.35, "Out")
	if not at(T.Slam) then
		return
	end
	U.finish(ctx, target, 12, { pin = true, words = { "CAT-ASTROPHE!" }, splash = { radius = 12, damage = 10, center = vp } })
	if not at(T.Land) then
		return
	end
	local land = U.wallSafe(vp, vp - cf.LookVector * 5, 1)
	U.glide(ctx, caster, U.facing(Vector3.new(land.X, vp.Y, land.Z), vp), 0.25, "In")
	at(T.End)
end

return M
