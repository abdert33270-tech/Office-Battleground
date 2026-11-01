--[[
	ULTIME — The AI Assistant : « SYSTEM OVERRIDE »
	Téléportation glitchée sur la cible. Touché → la victime est enfermée dans un cube holographique (ACCESS DENIED),
	bombardée de fenêtres pop-up qui restent collées autour d'elle (ERROR / ARE YOU SURE? / YES-YES / Did you mean: DEFEAT?),
	zappée par 3 drones, soulevée, puis une TOUCHE « DELETE » GÉANTE s'abat du ciel (finisher PIN + explosion glitch).
	Elle salue : « TASK COMPLETE :) ». Raté → « 404 : TARGET NOT FOUND » et elle bugge (cercle de chargement).
]]
local CYAN = Color3.fromRGB(60, 220, 255)
local HOLO = Color3.fromRGB(160, 240, 255)
local MAG = Color3.fromRGB(255, 70, 200)
local NAVY = Color3.fromRGB(25, 35, 70)
local WHITE = Color3.fromRGB(245, 250, 255)
local LIME = Color3.fromRGB(110, 255, 150)
local RED = Color3.fromRGB(255, 70, 70)
local SCREEN = Color3.fromRGB(15, 25, 45)
local HOLOS = { CYAN, HOLO, WHITE, MAG }

local SND = {
	Ping = "rbxassetid://122293143209564",
	Glitch = "rbxassetid://119121567196332",
	Error = "rbxassetid://133031003123734",
	Laser = "rbxassetid://87085224980395",
}

local T = { Cage = 0.1, Spam0 = 0.5, SpamStep = 0.12, Drones0 = 1.0, ZapStep = 0.1, Lift = 1.75, Key0 = 1.95, Slam = 2.45, End = 3.3 }
local SPAM = { { "ERROR", RED }, { "ARE YOU SURE?", CYAN }, { "YES / YES", LIME }, { "Did you mean: DEFEAT?", MAG } }

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local A = {}
A.Glitch = {
	{ t = 0 },
	{ t = 0.06, RS = { p = -0.6, r = -0.3 }, LS = { p = -0.6, r = 0.3 }, RJ = { ln = 0.55 }, RH = { p = -0.4 }, LH = { p = 0.5 } },
	{ t = 0.38, RS = { p = -0.7, r = -0.3 }, LS = { p = -0.7, r = 0.3 }, RJ = { ln = 0.6 }, RH = { p = -0.45 }, LH = { p = 0.55 } },
	{ t = 0.48 },
}
local function typeAnim(dur)
	local f = { { t = 0 } }
	local t, s = 0, 1
	while t < dur do -- tape dans le vide, hyper rapide
		t += 0.07
		s = -s
		table.insert(f, { t = t, RS = { p = 1.5 + 0.18 * s, y = 0.5 }, LS = { p = 1.5 - 0.18 * s, y = -0.5 }, RJ = { ln = 0.15, tw = 0.06 * s } })
	end
	table.insert(f, { t = dur + 0.1 })
	return f
end
A.Type = typeAnim(1.1)
A.Raise = {
	{ t = 0 },
	{ t = 0.12, RS = { p = 3.1, r = -0.15 }, LS = { p = 0.5, r = 0.5 }, RJ = { ln = -0.3, tw = 0.2 }, RH = { p = 0.2 }, LH = { p = -0.2 } },
	{ t = 0.6, RS = { p = 3.14, r = -0.1 }, LS = { p = 0.5, r = 0.5 }, RJ = { ln = -0.35, tw = 0.2 } },
	{ t = 0.68, RS = { p = 0.6, r = -0.2 }, LS = { p = 0.5, r = 0.5 }, RJ = { ln = 0.6, tw = -0.2 }, RH = { p = -0.4 }, LH = { p = 0.8 } },
	{ t = 0.95, RS = { p = 0.65 }, LS = { p = 0.5, r = 0.5 }, RJ = { ln = 0.5 } },
	{ t = 1.05 },
}
A.Bow = {
	{ t = 0 },
	{ t = 0.15, RS = { p = 0.9, y = 1.1 }, LS = { p = -0.3, r = 0.3 }, RJ = { ln = 0.75 } },
	{ t = 0.55, RS = { p = 0.9, y = 1.1 }, LS = { p = -0.3, r = 0.3 }, RJ = { ln = 0.75 } },
	{ t = 0.75 },
}
local function bufferAnim()
	local f = { { t = 0 } }
	for i = 1, 10 do -- elle bugge : saccades
		local s = (i % 2 == 0) and 1 or -1
		table.insert(f, { t = i * 0.08, RS = { p = 0.4 * s, r = -0.3 }, LS = { p = -0.4 * s, r = 0.3 }, RJ = { tw = 0.35 * s, sd = 0.12 * s, ln = 0.1 * s } })
	end
	table.insert(f, { t = 0.95 })
	return f
end
A.Whiff = bufferAnim()
local function struggle(dur)
	local f = { { t = 0 } }
	local t, s = 0, 1
	while t < dur do
		t += 0.12
		s = -s
		table.insert(f, { t = t, RS = { p = 2.6 + 0.4 * s, r = -0.4 }, LS = { p = 2.6 - 0.4 * s, r = 0.4 }, RJ = { ln = -0.15, tw = 0.2 * s }, RH = { p = 0.3 * s }, LH = { p = -0.3 * s } })
	end
	table.insert(f, { t = dur + 0.1 })
	return f
end
A.VStruggle = struggle(2.2)

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
local function text(part, str, color, face)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.FontFace = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Bold)
	l.TextScaled = true
	l.TextColor3 = color or WHITE
	l.Text = str
	l.Parent = gui
	return l
end
-- fenêtre holographique (parts suivies), face texte tournée vers +look
local function window(K, data, cf, w, h, str, col)
	local body = K.part({ Size = Vector3.new(w, h, 0.1), CFrame = cf, Color = SCREEN, Transparency = 0.1 }, 4)
	local bar = K.part({ Size = Vector3.new(w, h * 0.22, 0.12), CFrame = cf * CFrame.new(0, h * 0.39, 0), Color = col }, 4)
	local x = K.part({ Size = Vector3.new(h * 0.15, h * 0.15, 0.14), CFrame = cf * CFrame.new(w * 0.42, h * 0.39, -0.01), Color = RED }, 4)
	text(body, str, col, Enum.NormalId.Front)
	for _, p in ipairs({ body, bar, x }) do
		K.track(data, p)
	end
	return { { p = body, off = CFrame.new() }, { p = bar, off = CFrame.new(0, h * 0.39, 0) }, { p = x, off = CFrame.new(w * 0.42, h * 0.39, -0.01) } }
end
local function moveGroup(g, cf)
	for _, e in ipairs(g) do
		if e.p.Parent then
			e.p.CFrame = cf * e.off
		end
	end
end

------------------------------------------------------------------------
local M = {
	Name = "SYSTEM OVERRIDE",
	Desc = "Lock them in a hologram cage, spam them with pop-ups, zap them with drones, then press a GIANT delete key.",
	Color = CYAN,
	Color2 = MAG,
	Range = 24,
	Angle = 70,
	Timing = T,
}

local cages = {} -- par seq : état client de l'ulti (cage, fenêtres, drones)

function M.Client(K, data)
	local caster, target = data.caster, data.target
	local phase = data.phase

	if phase == "Cutin" then
		local r = K.root(caster)
		if r then
			K.sound(SND.Glitch, r.Position, 1, 1)
			for i = 0, 2 do
				K.at(data, 0.1 + i * 0.25, function()
					K.shards(r.Position + Vector3.new(0, 2.5, 0), 10, HOLOS, 0.8)
				end)
			end
		end
		return
	end

	if phase == "Rush" then
		play(K, caster, A.Glitch)
		local r = K.root(caster)
		if not r then
			return
		end
		K.sound("Teleport", r.Position, 1, 1.2)
		K.sound(SND.Glitch, r.Position, 0.7, 1.3)
		for i = 0, 4 do
			K.at(data, i * 0.07, function()
				local rr = K.root(caster)
				if rr then
					K.afterimage(caster, i % 2 == 0 and CYAN or MAG, 0.3, 0.4)
					K.shards(rr.Position, 5, HOLOS, 0.5)
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
		K.at(data, 0.2, function()
			play(K, caster, A.Whiff)
			local rr = K.root(caster) or r
			K.sound(SND.Error, rr.Position, 1, 1)
			local look = rr.CFrame.LookVector
			local cf = CFrame.lookAt(rr.Position + look * 3 + Vector3.new(0, 3, 0), rr.Position + look * 6 + Vector3.new(0, 3, 0))
			window(K, data, cf * CFrame.Angles(0, math.pi, 0), 4.2, 2, "404: TARGET NOT FOUND", RED)
			-- cercle de chargement au-dessus de la tête
			local dots = {}
			for k = 1, 8 do
				dots[k] = K.part({ Size = Vector3.one * 0.3, Color = (k == 1) and WHITE or CYAN, Material = Enum.Material.Neon, Transparency = k * 0.09 }, 1.2)
				K.track(data, dots[k])
			end
			run(1.0, function(a)
				local r2 = K.root(caster)
				if not r2 then
					return
				end
				for k, d in ipairs(dots) do
					local ang = -a * math.pi * 6 + k * math.pi / 4
					d.Position = r2.Position + Vector3.new(0, 4.4, 0) + r2.CFrame.RightVector * math.cos(ang) * 0.9 + Vector3.new(0, math.sin(ang) * 0.9, 0)
				end
			end)
			K.word(rr.Position + Vector3.new(0, 6, 0), "BUFFERING...", 1.0, "Light")
		end)
		return
	end

	local st = cages[data.seq]
	if phase == "Spam" and st then
		local i = data.i or 0
		local vp = rootPos(target, st.vp)
		local ang = math.rad(45 + i * 90)
		local off = Vector3.new(math.cos(ang) * 2.6, 1.2 + (i % 2) * 1.4, math.sin(ang) * 2.6)
		local from = vp + off * 4 + Vector3.new(0, 3, 0)
		local def = SPAM[i + 1] or SPAM[1]
		local g = window(K, data, CFrame.lookAt(from, from + off), 3, 1.6, def[1], def[2])
		table.insert(st.windows, { g = g, off = off })
		run(0.12, function(a)
			local p = from:Lerp(rootPos(target, vp) + off, a)
			moveGroup(g, CFrame.lookAt(p, p + off))
		end)
		K.at(data, 0.12, function()
			local p = rootPos(target, vp)
			K.sound(i % 2 == 0 and SND.Error or SND.Ping, p, 0.9, 1 + i * 0.08)
			K.sound("Punch", p, 0.7, 1.2)
			K.sparks(p + off * 0.5, 10, def[2])
			K.shake(0.4)
			if i == 3 then
				K.impactFrames("I", 0.05)
			end
		end)
		return
	end

	if phase == "Zap" and st then
		local i = data.i or 0
		local dr = st.drones[(i % 3) + 1]
		local vp = rootPos(target, st.vp)
		local from = dr and dr[1].p.Position or vp + Vector3.new(0, 4, 0)
		local col = (i % 2 == 0) and CYAN or MAG
		K.bolt(from, vp, col, 0.35, 0.15, 0.6)
		K.sparks(vp, 10, col)
		K.sound(SND.Laser, vp, 0.7, 1 + (i % 3) * 0.12)
		K.shake(0.3)
		if i == 5 then
			K.word(vp + Vector3.new(0, 4, 0), "ZZZAP!", 1.1, "Light")
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
	st = { vp = vp0, windows = {}, drones = {} }
	cages[data.seq] = st
	K.at(data, T.End + 0.5, function()
		cages[data.seq] = nil
	end)

	-- 1) CAGE HOLOGRAPHIQUE --------------------------------------
	K.shot(data, "orbit", { at = function() return cp():Lerp(vp(), 0.5) end, radius = 13, height = 2.5, angle = 65, speed = 35, basis = cf, fov = 62 })
	play(K, caster, A.Type)
	local edges = {}
	local s = Vector3.new(4.6, 6.4, 4.6)
	for _, a in ipairs({ -1, 1 }) do
		for _, b in ipairs({ -1, 1 }) do
			for _, e in ipairs({ { Vector3.new(s.X, 0.14, 0.14), Vector3.new(0, a * s.Y / 2, b * s.Z / 2) }, { Vector3.new(0.14, s.Y, 0.14), Vector3.new(a * s.X / 2, 0, b * s.Z / 2) }, { Vector3.new(0.14, 0.14, s.Z), Vector3.new(a * s.X / 2, b * s.Y / 2, 0) } }) do
				local p = K.part({ Size = e[1], Color = CYAN, Material = Enum.Material.Neon, Transparency = 1 }, 4)
				K.track(data, p)
				table.insert(edges, { p = p, off = e[2] })
			end
		end
	end
	local walls = {}
	for _, e in ipairs({ { Vector3.new(s.X, s.Y, 0.05), Vector3.new(0, 0, s.Z / 2) }, { Vector3.new(s.X, s.Y, 0.05), Vector3.new(0, 0, -s.Z / 2) }, { Vector3.new(0.05, s.Y, s.Z), Vector3.new(s.X / 2, 0, 0) }, { Vector3.new(0.05, s.Y, s.Z), Vector3.new(-s.X / 2, 0, 0) } }) do
		local p = K.part({ Size = e[1], Color = HOLO, Transparency = 1 }, 4)
		K.track(data, p)
		table.insert(walls, { p = p, off = e[2] })
	end
	K.at(data, T.Cage, function()
		local c = vp()
		play(K, target, A.VStruggle)
		K.layer({ { SND.Glitch, 1 }, { "Electric", 1, 1.2 }, { "PunchHeavy", 0.8 } }, c)
		K.impactFrames("B", 0.05)
		K.word(c + up * 4.5, "ACCESS DENIED", 1.2, "Heavy")
		K.shards(c, 14, HOLOS, 1)
		for _, e in ipairs(edges) do
			e.p.Transparency = 0
		end
		for _, e in ipairs(walls) do
			e.p.Transparency = 0.82
		end
		run(T.Slam - T.Cage, function(a)
			local p = vp()
			local k = 1 + 0.05 * math.sin(os.clock() * 30)
			local base = CFrame.new(p) * CFrame.Angles(0, os.clock() * 0.8, 0)
			for _, e in ipairs(edges) do
				e.p.CFrame = base * CFrame.new(e.off * k)
			end
			for _, e in ipairs(walls) do
				e.p.CFrame = base * CFrame.new(e.off * k)
			end
			-- les pop-ups collées suivent la victime
			for _, w in ipairs(st.windows) do
				local wp = p + w.off
				if w.stuck then
					moveGroup(w.g, CFrame.lookAt(wp, wp + w.off))
				end
			end
		end)
	end)
	K.at(data, T.Spam0 + 0.2, function()
		for _, w in ipairs(st.windows) do
			w.stuck = true
		end
	end)
	K.at(data, T.Spam0 + 3 * T.SpamStep + 0.15, function()
		for _, w in ipairs(st.windows) do
			w.stuck = true
		end
	end)

	-- 2) DRONES ---------------------------------------------------
	K.at(data, T.Drones0 - 0.25, function()
		K.shot(data, "orbit", { at = function() return vp() end, radius = 11, height = 4, angle = -40, speed = 90, basis = cf, fov = 64 })
		K.sound("Electric", vp(), 0.8, 1.4)
		for k = 1, 3 do
			local hub = K.part({ Shape = K.BALL, Size = Vector3.one * 0.8, Color = WHITE }, 3)
			local ring = K.part({ Shape = K.CYL, Size = Vector3.new(0.14, 1.6, 1.6), Color = (k == 2) and MAG or CYAN, Material = Enum.Material.Neon }, 3)
			K.track(data, hub)
			K.track(data, ring)
			st.drones[k] = { { p = hub, off = CFrame.new() }, { p = ring, off = K.UPRIGHT } }
		end
		run(T.Lift - T.Drones0 + 0.25, function(a)
			local p = vp()
			for k, dr in ipairs(st.drones) do
				local ang = os.clock() * 4 + k * math.pi * 2 / 3
				local pos = p + Vector3.new(math.cos(ang) * 4.2, 3 + math.sin(os.clock() * 6 + k) * 0.4, math.sin(ang) * 4.2)
				moveGroup(dr, CFrame.new(pos))
			end
			if a >= 1 then
				for _, dr in ipairs(st.drones) do
					K.shards(dr[1].p.Position, 5, HOLOS, 0.6)
					for _, e in ipairs(dr) do
						e.p:Destroy()
					end
				end
			end
		end)
	end)

	-- 3) TOUCHE DELETE GÉANTE ----------------------------------
	K.at(data, T.Lift, function()
		play(K, caster, A.Raise)
		K.sound("Whoosh3", cp(), 1, 0.9)
		K.shot(data, "fixed", { pos = g0 - look * 11 + right * 6 + up * 1.2, lookAt = g0 + up * 7, fov = 72 })
	end)
	local key = {}
	K.at(data, T.Key0, function()
		local base = CFrame.lookAt(g0, g0 - look)
		local function piece(size, off, color, mat)
			local p = K.part({ Size = size, CFrame = base * CFrame.new(0, 30, 0) * off, Color = color, Material = mat or Enum.Material.SmoothPlastic }, 3)
			K.track(data, p)
			table.insert(key, { p = p, off = off })
			return p
		end
		piece(Vector3.new(7.4, 0.35, 7.4), CFrame.new(0, 0.2, 0), CYAN, Enum.Material.Neon)
		piece(Vector3.new(7, 1.8, 7), CFrame.new(0, 1.2, 0), NAVY)
		local cap = piece(Vector3.new(6, 1.4, 6), CFrame.new(0, 2.6, 0), WHITE)
		text(cap, "DELETE", RED, Enum.NormalId.Back)
		text(cap, "DELETE", RED, Enum.NormalId.Front)
		text(cap, "DEL", RED, Enum.NormalId.Bottom)
		piece(Vector3.new(6.2, 0.2, 6.2), CFrame.new(0, 3.35, 0), HOLO)
		local shadow = K.part({ Shape = K.CYL, Size = Vector3.new(0.1, 2, 2), CFrame = CFrame.new(g0 + up * 0.08) * K.UPRIGHT, Color = SCREEN, Transparency = 0.6 }, 1)
		K.track(data, shadow)
		K.tween(shadow, T.Slam - T.Key0, { Size = Vector3.new(0.1, 9, 9), Transparency = 0.25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		K.word(g0 + up * 11, "DELETE? [YES]", 1.0, "Light")
		K.sound(SND.Ping, g0, 1, 0.7)
		run(T.Slam - T.Key0, function(a)
			local y = 30 * (1 - a * a) + 1.2
			for _, e in ipairs(key) do
				e.p.CFrame = base * CFrame.new(0, y, 0) * e.off
			end
			if a >= 1 and shadow.Parent then
				shadow:Destroy()
			end
		end)
	end)
	K.at(data, T.Slam, function()
		local c = g0 + up * 1
		K.impactFrames("WBWB", 0.05)
		K.layer({ { "Boom", 1.6 }, { "Bass", 1.4, 0.85 }, { "GroundSlam", 1.2 }, { SND.Glitch, 1.2, 0.9, 0.05 } }, c)
		K.shake(2)
		K.fov(12)
		K.crater(c, 10, CYAN, 3)
		K.quake(c, 12, MAG, 1.2)
		K.sphere(c, 12, CYAN, 0.35, 3)
		K.light(c, CYAN, 40, 10, 0.5)
		K.shards(c + up * 2, 24, HOLOS, 1.8)
		K.word(c + up * 7, "FILE DELETED!!", 2.0, "Heavy")
		-- cage et fenêtres volent en éclats
		for _, e in ipairs(edges) do
			if e.p.Parent then
				K.tween(e.p, 0.4, { CFrame = e.p.CFrame + (e.p.Position - c).Unit * 6, Transparency = 1 })
			end
		end
		for _, e in ipairs(walls) do
			if e.p.Parent then
				e.p:Destroy()
			end
		end
		for _, w in ipairs(st.windows) do
			w.stuck = false
			for _, e in ipairs(w.g) do
				if e.p.Parent then
					K.tween(e.p, 0.45, { CFrame = e.p.CFrame + w.off.Unit * 8 + up * 3, Transparency = 1 })
				end
			end
		end
		K.shot(data, "orbit", { at = c, radius = 17, height = 6, angle = 20, speed = 25, basis = cf, fov = 66 })
		K.at(data, T.Slam + 0.45, function()
			for _, e in ipairs(key) do
				if e.p.Parent then
					K.tween(e.p, 0.3, { Size = e.p.Size * Vector3.new(1, 0.05, 1), Transparency = 1 })
				end
			end
		end)
	end)
	K.at(data, T.Slam + 0.35, function()
		play(K, caster, A.Bow)
		K.word(cp() + up * 4, "TASK COMPLETE :)", 1.0, "Light")
		K.sound(SND.Ping, cp(), 1, 1.2)
	end)
end

function M.Server(U, caster, target, ctx)
	U.fx(ctx, "Rush")
	if not U.rush(ctx, target, { speed = 130, contact = 4.5, maxTime = 0.45, whiffDist = 14, whiffTime = 0.25 }) then
		U.fx(ctx, "Whiff")
		U.wait(ctx, 1.2)
		return
	end
	local cf = U.currentCF(ctx, caster)
	local vr = U.root(target)
	cf = U.facing(cf.Position, vr.Position)
	U.place(ctx, caster, cf)
	local vp = U.wallSafe(cf.Position, cf.Position + cf.LookVector * 5, 1.5)
	vp = Vector3.new(vp.X, cf.Position.Y, vp.Z)
	local H = math.clamp(U.headroom(vp, 12), 4, 10)
	local vcf = U.facing(vp, cf.Position)
	U.hold(ctx, target, vcf)
	U.fx(ctx, "Connect", { cf = cf, vp = vp, h = H })
	local tc = os.clock()
	local function at(t)
		return U.wait(ctx, math.max(0, t - (os.clock() - tc)))
	end
	if not at(T.Cage) then
		return
	end
	U.hit(ctx, target, 4, { power = 0.7, words = { "ACCESS DENIED" }, stun = 0.8 })
	for i = 0, 3 do
		if not at(T.Spam0 + i * T.SpamStep) then
			return
		end
		U.fx(ctx, "Spam", { i = i })
		if not U.wait(ctx, 0.1) then
			return
		end
		U.hit(ctx, target, 2, { power = 0.4, words = { "ERROR!", "POP-UP!", "SPAM!" }, stun = 0.6 })
	end
	for i = 0, 5 do
		if not at(T.Drones0 + i * T.ZapStep) then
			return
		end
		U.fx(ctx, "Zap", { i = i })
		U.hit(ctx, target, 2, { power = 0.35, words = { "ZAP!", "BZZT!" }, stun = 0.6 })
	end
	if not at(T.Lift) then
		return
	end
	local lift = math.clamp(H - 6, 0.5, 2.5)
	U.glide(ctx, target, vcf + Vector3.new(0, lift, 0), 0.3, "Out")
	U.glide(ctx, caster, U.facing(U.wallSafe(vp, cf.Position - cf.LookVector * 2, 1), vp), 0.3, "Out")
	if not at(T.Slam - 0.12) then
		return
	end
	U.glide(ctx, target, vcf, 0.12, "In")
	if not at(T.Slam) then
		return
	end
	U.finish(ctx, target, 12, { pin = true, words = { "DELETED!" }, splash = { radius = 12, damage = 10, center = vp } })
	at(T.End)
end

return M
