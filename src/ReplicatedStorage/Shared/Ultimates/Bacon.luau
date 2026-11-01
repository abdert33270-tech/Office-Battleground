--[[
	ULTIME — The Bacon : « MAXIMUM OOF »
	Course de noob bras tendus jusqu'à la cible. Touché → plaquage « OOF! », 6 baffes de noob (comptées à l'écran),
	coup de pied « YEET! » qui envoie la victime en l'air ; le Bacon recule, montre le ciel : une TRANCHE DE BACON
	GÉANTE tombe et écrase la victime au sol (finisher PIN + cratère + graisse), puis des lunettes pixel géantes
	descendent du ciel sur son visage : « DEAL WITH IT ».
	Raté → il trébuche, s'étale (« oof. ») et accuse le lag.
	Caméras : toujours cadrées pour voir les DEUX persos (plan latéral qui suit le milieu, contre-plongée sur
	l'envol, plan large derrière le Bacon pour la chute, orbite sur l'impact, plan final à travers la victime).
	Dégâts : 4 + 6x2 + 5 + 15 = 36 (+10 % du passif) + 10 de zone.
]]
local BACON = Color3.fromRGB(232, 92, 64)
local MEAT = Color3.fromRGB(196, 64, 50)
local MEAT2 = Color3.fromRGB(160, 44, 38)
local FAT = Color3.fromRGB(255, 218, 196)
local GREASE = Color3.fromRGB(255, 214, 90)
local FLAME = Color3.fromRGB(255, 120, 30)
local GOLD = Color3.fromRGB(255, 200, 50)
local WHITE = Color3.fromRGB(250, 250, 250)
local DARK = Color3.fromRGB(22, 22, 26)
local BITS = { MEAT, FAT, GREASE, BACON }

local T = { Tackle = 0.1, Slap0 = 0.42, SlapStep = 0.12, Kick = 1.25, Summon = 1.5, Slam = 2.15, Shades0 = 2.6, ShadesOn = 3.05, End = 3.65 }
-- rythme v3 : temps forts ~12 % plus lents (le serveur ET le client lisent cette même table T)
for k, v in pairs(T) do
	T[k] = v * 1.12
end

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local A = {}
A.Cutin = { -- remonte ses lunettes, sûr de lui
	{ t = 0 },
	{ t = 0.15, RS = { p = 2.6, y = 0.9 }, LS = { p = 0.2, r = -0.4 }, RJ = { ln = -0.1 } },
	{ t = 0.45, RS = { p = 2.75, y = 0.95 }, LS = { p = 0.2, r = -0.4 }, RJ = { ln = -0.15, sd = 0.08 } },
	{ t = 0.6, RS = { p = 0.3, r = -0.5 }, LS = { p = 0.3, r = -0.5 }, RJ = { ln = -0.05 } },
	{ t = 0.9 },
}
local function runAnim(dur)
	local f = { { t = 0 } }
	local t, s = 0, 1
	while t < dur do
		t += 0.07
		s = -s
		table.insert(f, { t = t, RS = { p = 1.57 + 0.08 * s }, LS = { p = 1.57 - 0.08 * s }, RJ = { ln = 0.28, sd = 0.06 * s }, RH = { p = 0.9 * s }, LH = { p = -0.9 * s } })
	end
	table.insert(f, { t = t + 0.1 })
	return f
end
A.Run = runAnim(0.5)
A.Tackle = {
	{ t = 0 },
	{ t = 0.05, RS = { p = 1.7, r = -0.2 }, LS = { p = 1.7, r = -0.2 }, RJ = { ln = 0.5 }, RH = { p = -0.5 }, LH = { p = 0.7 } },
	{ t = 0.25, RS = { p = 1.5 }, LS = { p = 1.5 }, RJ = { ln = 0.3 } },
	{ t = 0.32 },
}
A.SlapR = {
	{ t = 0 },
	{ t = 0.04, RS = { p = 1.9, y = -0.8 }, LS = { p = 0.5, r = -0.3 }, RJ = { tw = -0.35, ln = 0.15 } },
	{ t = 0.09, RS = { p = 1.6, y = 0.9 }, LS = { p = 0.5, r = -0.3 }, RJ = { tw = 0.4, ln = 0.25 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
	{ t = 0.14 },
}
A.SlapL = {
	{ t = 0 },
	{ t = 0.04, LS = { p = 1.9, y = -0.8 }, RS = { p = 0.5, r = -0.3 }, RJ = { tw = 0.35, ln = 0.15 } },
	{ t = 0.09, LS = { p = 1.6, y = 0.9 }, RS = { p = 0.5, r = -0.3 }, RJ = { tw = -0.4, ln = 0.25 }, RH = { p = 0.4 }, LH = { p = -0.3 } },
	{ t = 0.14 },
}
A.Kick = {
	{ t = 0 },
	{ t = 0.06, RS = { p = -0.4 }, LS = { p = 1.0, r = -0.4 }, RJ = { ln = -0.25 }, RH = { p = -0.6 }, LH = { p = 0.1 } },
	{ t = 0.14, RS = { p = 0.8, r = -0.6 }, LS = { p = 0.8, r = -0.6 }, RJ = { ln = -0.35 }, RH = { p = 2.3 }, LH = { p = -0.1 } },
	{ t = 0.32, RS = { p = 0.7, r = -0.6 }, LS = { p = 0.7, r = -0.6 }, RJ = { ln = -0.3 }, RH = { p = 2.0 }, LH = { p = -0.1 } },
	{ t = 0.45 },
}
A.Point = { -- montre le ciel, puis abat le bras
	{ t = 0 },
	{ t = 0.12, RS = { p = 3.1, r = -0.15 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = -0.3 }, RH = { p = 0.2 } },
	{ t = 0.55, RS = { p = 3.14, r = -0.1 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = -0.35 }, RH = { p = 0.2 } },
	{ t = 0.66, RS = { p = 1.2, y = 0.4 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = 0.35 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
	{ t = 0.95, RS = { p = 1.1, y = 0.4 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = 0.25 } },
	{ t = 1.05 },
}
A.Pose = { -- les mains sur les hanches, menton levé
	{ t = 0 },
	{ t = 0.15, RS = { p = 0.35, r = -0.9, y = 0.9 }, LS = { p = 0.35, r = -0.9, y = 0.9 }, RJ = { ln = -0.18 }, RH = { p = 0.1, r = -0.15 }, LH = { p = 0.1, r = -0.15 } },
	{ t = 0.95, RS = { p = 0.35, r = -0.9, y = 0.9 }, LS = { p = 0.35, r = -0.9, y = 0.9 }, RJ = { ln = -0.2, sd = 0.06 }, RH = { p = 0.1, r = -0.15 }, LH = { p = 0.1, r = -0.15 } },
	{ t = 1.1 },
}
A.Trip = {
	{ t = 0 },
	{ t = 0.1, RS = { p = 3.0, r = -0.3 }, LS = { p = 3.0, r = -0.3 }, RJ = { ln = 1.2 }, RH = { p = -0.5 }, LH = { p = -0.3 } },
	{ t = 0.9, RS = { p = 3.0, r = -0.35 }, LS = { p = 3.0, r = -0.35 }, RJ = { ln = 1.3 }, RH = { p = -0.45 }, LH = { p = -0.35 } },
	{ t = 1.1, RS = { p = 0.6, r = -0.7 }, LS = { p = 0.6, r = -0.7 }, RJ = { ln = 0.1 } },
	{ t = 1.3 },
}
local function flailAnim(dur)
	local f = { { t = 0 } }
	local t, s = 0, 1
	while t < dur do
		t += 0.12
		s = -s
		table.insert(f, { t = t, RS = { p = 1.0 + 0.5 * s, r = -0.6 }, LS = { p = 1.0 - 0.5 * s, r = -0.6 }, RJ = { ln = -0.2, sd = 0.2 * s, tw = 0.3 * s }, RH = { p = 0.3 * s }, LH = { p = -0.3 * s } })
	end
	table.insert(f, { t = dur + 0.1 })
	return f
end
A.VFlail = flailAnim(1.1)
A.VAir = flailAnim(0.8)
A.VSquash = { { t = 0 }, { t = 0.08, RS = { p = 0.3, r = -1.4 }, LS = { p = 0.3, r = -1.4 }, RJ = { ln = 0.4 }, RH = { p = 0.9 }, LH = { p = 0.9 } }, { t = 0.9, RS = { p = 0.3, r = -1.4 }, LS = { p = 0.3, r = -1.4 }, RJ = { ln = 0.4 }, RH = { p = 0.9 }, LH = { p = 0.9 } }, { t = 1.0 } }

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

-- tranche de bacon géante (repère : centre du dessous, -Z = sens de la longueur) : liste { p, off }
local function giantStrip(K, data, base)
	local list = {}
	local n, segLen, width = 7, 3.4, 7
	for i = 1, n do
		local z = (i - (n + 1) / 2) * segLen * 0.95
		local wave = math.sin(i * 1.25) * 0.8
		local pitch = math.cos(i * 1.25) * 0.28
		local off = CFrame.new(0, 0.45 + wave, z) * CFrame.Angles(pitch, 0, 0)
		local meat = K.part({ Size = Vector3.new(width, 0.9, segLen), CFrame = base * off, Color = (i % 2 == 0) and MEAT or MEAT2 }, 4)
		K.track(data, meat)
		table.insert(list, { p = meat, off = off })
		for _, x in ipairs({ -1.7, 1.6 }) do
			local o2 = off * CFrame.new(x, 0.02, 0)
			local fat = K.part({ Size = Vector3.new(1.1, 0.95, segLen + 0.02), CFrame = base * o2, Color = FAT }, 4)
			K.track(data, fat)
			table.insert(list, { p = fat, off = o2 })
		end
	end
	return list
end

-- lunettes pixel géantes (repère : centre des verres, -Z = devant)
local SHADES = {
	{ Vector3.new(1.5, 0.13, 0.08), CFrame.new(0, 0.12, 0), DARK },
	{ Vector3.new(0.58, 0.25, 0.08), CFrame.new(-0.34, 0, 0), DARK },
	{ Vector3.new(0.58, 0.25, 0.08), CFrame.new(0.34, 0, 0), DARK },
	{ Vector3.new(0.36, 0.12, 0.08), CFrame.new(-0.34, -0.18, 0), DARK },
	{ Vector3.new(0.36, 0.12, 0.08), CFrame.new(0.34, -0.18, 0), DARK },
	{ Vector3.new(0.1, 0.1, 0.04), CFrame.new(-0.52, 0.04, -0.05), WHITE },
	{ Vector3.new(0.1, 0.1, 0.04), CFrame.new(0.16, 0.04, -0.05), WHITE },
}

------------------------------------------------------------------------
local M = {
	Name = "MAXIMUM OOF",
	-- v3 : titres de temps forts (UltimateController)
	Beats = {
		Rush = "NOOB RUSH",
		Connect = { { 0, "NOOB COMBO" }, { T.Kick, "YEET" }, { T.Summon, "BACON FROM THE SKY" }, { T.Shades0, "DEAL WITH IT" } },
		Whiff = "IT WAS LAG, I SWEAR",
	},
	Desc = "Noob-rush them, 6 noob slaps and a YEET, then a GIANT bacon strip from the sky flattens them. Deal with it.",
	Color = BACON,
	Color2 = GOLD,
	Range = 24,
	Angle = 70,
	Timing = T,
}

local function connect(K, data)
	local caster, target = data.caster, data.target
	K.letterbox(data, true, 0.2)
	local cf = data.cf
	if not cf then
		local r = K.root(caster)
		cf = r and r.CFrame or CFrame.new()
	end
	local look, right, up = cf.LookVector, cf.RightVector, Vector3.yAxis
	local vp0 = data.vp or (cf.Position + look * 3.6)
	local H = data.h or 6
	local function vp()
		return rootPos(target, vp0)
	end
	local function cp()
		return rootPos(caster, cf.Position)
	end
	local g0 = K.groundPos(vp0)

	-- 1) PLAQUAGE + BAFFES : plan latéral qui suit le milieu des deux persos -----------
	K.shot(data, "duo", { side = 1, angle = 12, height = 2.2, fov = 58 })
	K.at(data, T.Tackle, function()
		local c = vp()
		play(K, caster, A.Tackle)
		play(K, target, A.VFlail)
		K.layer({ { "PunchHeavy", 1.2 }, { "Oof", 1.1, 0.9 } }, c)
		K.impactFrames("B", 0.04)
		K.bigImpact(c, look, 1.0, BACON)
		K.word(c + up * 3, "OOF!", 1.3, "Heavy")
		K.shake(0.8)
	end)

	-- 2) YEET : contre-plongée qui voit le Bacon au sol et la victime qui monte -----------
	K.at(data, T.Kick - 0.08, function()
		K.shot(data, "fixed", { pos = cp() + right * 7 - look * 4 + up * 0.6, lookAt = vp0 + up * (H * 0.55), fov = 70 })
	end)
	K.at(data, T.Kick, function()
		local c = vp()
		play(K, caster, A.Kick)
		play(K, target, A.VAir)
		K.layer({ { "Uppercut", 1.1 }, { "Whoosh2", 1 } }, c)
		K.airRing(c, up, 6, WHITE, 0.3)
		K.word(c + up * 2.5, "YEET!", 1.5, "Heavy")
		K.speedLines(0.35, BACON)
		K.shake(0.9)
	end)

	-- 3) LA TRANCHE DE BACON GÉANTE : plan large derrière le Bacon -----------------------
	local strip = {}
	K.at(data, T.Summon, function()
		play(K, caster, A.Point)
		K.sound("Rumble", cp(), 1, 1.1)
		K.word(cp() + up * 4.5, "ADMIN, PLS", 1.0, "Light")
		K.shot(data, "fixed", { pos = cp() - look * 11 + right * 5 + up * 3, lookAt = vp0 + up * 6, fov = 74 })
		local base = CFrame.lookAt(g0, g0 + look)
		strip = giantStrip(K, data, base * CFrame.new(0, 45, 0))
		local shadow = K.part({ Shape = K.CYL, Size = Vector3.new(0.1, 3, 3), CFrame = CFrame.new(g0 + up * 0.08) * K.UPRIGHT, Color = Color3.fromRGB(20, 15, 15), Transparency = 0.6 }, 1.2)
		K.track(data, shadow)
		K.tween(shadow, T.Slam - T.Summon, { Size = Vector3.new(0.1, 16, 16), Transparency = 0.25 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		run(T.Slam - T.Summon, function(a)
			local y = 45 * (1 - a * a)
			local wob = math.sin(a * 18) * 0.06 * (1 - a)
			for _, e in ipairs(strip) do
				if e.p.Parent then
					e.p.CFrame = base * CFrame.new(0, y, 0) * CFrame.Angles(0, wob, 0) * e.off
				end
			end
			if a >= 1 and shadow.Parent then
				shadow:Destroy()
			end
		end)
	end)
	K.at(data, T.Summon + 0.25, function()
		K.sound("Whoosh3", g0 + up * 20, 1, 0.8)
		K.word(g0 + up * 14, "INCOMING BACON", 1.1, "Light")
	end)

	-- 4) IMPACT ----------------------------------------------------------------------
	K.at(data, T.Slam, function()
		local c = g0 + up * 1
		play(K, target, A.VSquash)
		K.impactFrames("WBW", 0.04)
		K.layer({ { "Boom", 1.6 }, { "Bass", 1.4, 0.85 }, { "GroundSlam", 1.3 }, { "Oof", 1.6, 0.7, 0.08 } }, c)
		K.shake(2)
		K.fov(12)
		K.crater(c, 10, MEAT, 3)
		K.quake(c, 12, BACON, 1.2)
		K.sphere(c, 12, GREASE, 0.35, 3)
		K.light(c, FLAME, 40, 8, 0.5)
		K.debris(c, 10, nil, 1.3, 1.1)
		K.shards(c + up * 2, 22, BITS, 1.6)
		K.word(c + up * 7, "MAXIMUM OOF!!", 2.0, "Heavy")
		K.shot(data, "orbit", { at = c, radius = 17, height = 6, angle = 30, speed = 22, basis = cf, fov = 66 })
		-- graisse qui gicle et fume
		for i = 1, 8 do
			local ang = i / 8 * math.pi * 2
			local p = c + Vector3.new(math.cos(ang), 0, math.sin(ang)) * 7
			K.at(data, T.Slam + i * 0.03, function()
				K.puff(p, 1.4)
			end)
		end
		K.at(data, T.Slam + 0.45, function()
			for _, e in ipairs(strip) do
				if e.p.Parent then
					K.tween(e.p, 0.45, { CFrame = e.p.CFrame + up * 40, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end
			end
		end)
	end)

	-- 5) DEAL WITH IT : plan à travers la victime (au premier plan) sur le Bacon --------------
	K.at(data, T.Shades0 - 0.1, function()
		play(K, caster, A.Pose)
		K.shot(data, "fixed", { pos = vp0 + look * 4 + right * 2.2 + up * 3.4, lookAt = cp() + up * 1.4, fov = 50 })
	end)
	K.at(data, T.Shades0, function()
		local head = caster and caster:FindFirstChild("Head")
		if not head then
			return
		end
		local parts = {}
		for _, s in ipairs(SHADES) do
			local p = K.part({ Size = s[1] * 1.35, Color = s[3], CFrame = head.CFrame }, 2)
			K.track(data, p)
			table.insert(parts, { p = p, off = CFrame.new(s[2].Position * 1.35) })
		end
		K.sound("Whoosh", head.Position, 0.7, 1.4)
		local fall = T.ShadesOn - T.Shades0
		run(fall + 0.55, function(a)
			local h = caster:FindFirstChild("Head")
			if not h then
				return
			end
			local k = math.clamp(a * (fall + 0.55) / fall, 0, 1)
			local y = 7 * (1 - k)
			local face = h.CFrame * CFrame.new(0, 0.18 + y, -0.72)
			for _, e in ipairs(parts) do
				if e.p.Parent then
					e.p.CFrame = face * e.off
				end
			end
		end)
	end)
	K.at(data, T.ShadesOn, function()
		local p = cp() + up * 1.6
		K.layer({ { "Ding", 1.2 }, { "Sting", 0.8 } }, p)
		K.sparks(p + up * 0.4, 10, WHITE)
		K.word(p + up * 2.8, "DEAL WITH IT", 1.4, "Heavy")
		K.shake(0.4)
	end)
end

function M.Client(K, data)
	local caster = data.caster
	local phase = data.phase

	if phase == "Cutin" then
		play(K, caster, A.Cutin)
		local r = K.root(caster)
		if r then
			K.sound("Oof", r.Position, 0.7, 1.3)
			K.at(data, 0.45, function()
				local head = caster:FindFirstChild("Head")
				local p = head and (head.CFrame * CFrame.new(0, 0.2, -0.7)).Position or r.Position + Vector3.new(0, 1.6, 0)
				K.sparks(p, 8, WHITE)
				K.shards(p, 8, BITS, 0.6)
				K.sound("Ding", p, 0.8, 1.2)
			end)
		end
		return
	end

	if phase == "Rush" then
		play(K, caster, A.Run)
		local r = K.root(caster)
		if not r then
			return
		end
		K.layer({ { "Dash", 1 }, { "Whoosh2", 0.9, 1.1 } }, r.Position)
		K.word(r.Position + Vector3.new(0, 4, 0), "COMING THROUGH!", 1.0, "Light")
		for i = 0, 4 do
			K.at(data, i * 0.08, function()
				local rr = K.root(caster)
				if rr then
					K.afterimage(caster, i % 2 == 0 and BACON or GOLD, 0.25, 0.5)
					K.shards(rr.Position, 3, BITS, 0.4)
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
		K.at(data, 0.1, function()
			play(K, caster, A.Trip)
			local rr = K.root(caster)
			local g = K.groundPos(rr and rr.Position or r.Position)
			K.sound("Thud", g, 1, 1)
			K.sound("Oof", g, 1, 1.1)
			K.dust(g, 5, nil, 10)
			K.word(g + Vector3.new(0, 3, 0), "oof.", 1.0, "Light")
		end)
		K.at(data, 0.95, function()
			local rr = K.root(caster)
			if rr then
				K.word(rr.Position + Vector3.new(0, 4, 0), "LAG!!", 1.1, "Light")
				K.CFX.dizzy(caster, 0.5)
			end
		end)
		return
	end

	if phase == "Slap" then
		local i = data.i or 1
		local vp = rootPos(data.target, data.vp)
		if not vp then
			return
		end
		play(K, caster, (i % 2 == 0) and A.SlapL or A.SlapR)
		local cr = K.root(caster)
		local from = cr and cr.Position or vp
		local dirTo = (vp - from).Magnitude > 0.1 and (vp - from).Unit or Vector3.new(0, 0, -1)
		K.slashArc(CFrame.lookAt(from + Vector3.new(0, 1, 0), vp + Vector3.new(0, 1, 0)), 3.2, (i % 2 == 0) and WHITE or GOLD, -100, 100, 0.1, (i % 2 == 0) and 30 or -30, 0.5)
		K.sparks(vp + Vector3.new(0, 1, 0), 8, (i % 2 == 0) and WHITE or GOLD)
		K.sound(i % 2 == 0 and "Punch" or "Punch2", vp, 0.9, 1 + i * 0.05)
		K.shake(0.35)
		K.word(vp + Vector3.new(K.rng:NextNumber(-1.5, 1.5), 2.6 + i * 0.25, 0) - dirTo * 0.5, (i == 6) and "OOF x6!" or ("OOF x" .. i), 0.8 + i * 0.07, "Light")
		if i == 6 then
			K.impactFrames("W", 0.04)
			K.sound("Oof", vp, 1.2, 0.85)
		end
		return
	end

	if phase == "Connect" then
		connect(K, data)
	end
end

function M.Server(U, caster, target, ctx)
	U.fx(ctx, "Rush")
	if not U.rush(ctx, target, { speed = 120, contact = 4.0, maxTime = 0.5, whiffDist = 16, whiffTime = 0.3 }) then
		U.fx(ctx, "Whiff")
		U.wait(ctx, 1.3)
		return
	end
	local vr = U.root(target)
	if not vr or not U.valid(target, ctx) then
		return
	end
	local cf = U.currentCF(ctx, caster)
	cf = U.facing(cf.Position, vr.Position)
	U.place(ctx, caster, cf)
	local look = cf.LookVector
	local vp = U.wallSafe(cf.Position, cf.Position + look * 3.6, 1.5)
	vp = Vector3.new(vp.X, cf.Position.Y, vp.Z)
	local H = math.clamp(U.headroom(vp, 12), 3, 9)
	local vcf = U.facing(vp, cf.Position)
	-- prise refusée (cible passée en zone AFK, tenue par une autre ulti...) : on rate plutôt que frapper une cible libre
	if not U.hold(ctx, target, vcf) then
		U.fx(ctx, "Whiff")
		U.wait(ctx, 1.3)
		return
	end
	U.fx(ctx, "Connect", { cf = cf, vp = vp, h = H })
	local tc = os.clock()
	local function at(t)
		return U.wait(ctx, math.max(0, t - (os.clock() - tc)))
	end
	if not at(T.Tackle) then
		return
	end
	U.hit(ctx, target, 4, { power = 0.7, words = { "OOF!" }, stun = 0.8 })
	-- 6 baffes de noob
	for i = 1, 6 do
		if not at(T.Slap0 + (i - 1) * T.SlapStep) then
			return
		end
		U.fx(ctx, "Slap", { i = i, vp = vp })
		U.hit(ctx, target, 2, { power = 0.35 + i * 0.03, words = { "SLAP!", "NOOB'D!", "BONK!", "OOF!" }, stun = 0.6 })
	end
	-- YEET : la victime monte, le Bacon recule de deux pas
	if not at(T.Kick) then
		return
	end
	U.hit(ctx, target, 5, { power = 0.85, words = { "YEET!" }, stun = 1.2 })
	U.glide(ctx, target, vcf + Vector3.new(0, H, 0), 0.32, "Out")
	local back = U.wallSafe(cf.Position, cf.Position - look * 2.5, 1)
	U.glide(ctx, caster, U.facing(Vector3.new(back.X, cf.Position.Y, back.Z), vp), 0.25, "Out")
	-- la tranche de bacon géante l'écrase au sol
	if not at(T.Slam - 0.12) then
		return
	end
	U.glide(ctx, target, vcf, 0.12, "In")
	if not at(T.Slam) then
		return
	end
	U.finish(ctx, target, 15, { pin = true, words = { "MAXIMUM OOF!" }, splash = { radius = 12, damage = 10, center = vp } })
	at(T.End)
end

return M
