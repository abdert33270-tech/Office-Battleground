--[[
	ULTIME — The Maintenance Guy : « DEMOLITION DAY »
	Lasso en ruban « CAUTION » lancé devant. Touché → la victime est ramenée et momifiée dans le ruban,
	perceuse géante (6 ticks), câbles de démarrage (3 éclairs), puis il siffle : une boule de démolition
	traverse l'écran au bout de sa chaîne et envoie la victime très loin (finisher LAUNCH).
	Raté → la clé géante s'écrase au sol dans une gerbe d'étincelles (« MISSED THE NAIL! »).
]]
local HIVIS = Color3.fromRGB(210, 245, 25)
local ORANGE = Color3.fromRGB(255, 130, 20)
local STEEL = Color3.fromRGB(175, 180, 190)
local DARK = Color3.fromRGB(35, 38, 45)
local SPARK = Color3.fromRGB(120, 220, 255)
local YELLOW = Color3.fromRGB(255, 220, 40)

local SND = {
	Drill = "rbxassetid://9117875538",
	Zap = "rbxassetid://9116274992",
	Zap2 = "rbxassetid://9116275998",
	Chain = "rbxassetid://9113763639",
	Metal = "rbxassetid://132846127748664",
	MetalBoom = "rbxassetid://115664312809163",
}

-- temps des coups (secondes après "Connect") — partagés serveur / client
local T = { Drill0 = 0.55, DrillStep = 0.12, Cables = 1.5, Whistle = 1.95, Wreck = 2.6, End = 3.35 }

------------------------------------------------------------------------
-- Animations (format ProcAnim)
------------------------------------------------------------------------
local A = {}
-- lasso : fait tourner le ruban au-dessus de la tête puis le lance
A.Lasso = {
	{ t = 0 },
	{ t = 0.1, RS = { p = 3.0, y = 0.5, r = -0.4 }, LS = { p = 0.3, r = -0.3 }, RJ = { tw = 0.35, ln = -0.08 }, RH = { p = 0.2 }, LH = { p = -0.2 } },
	{ t = 0.2, RS = { p = 3.0, y = -0.7, r = -0.6 }, RJ = { tw = -0.15, ln = -0.05 } },
	{ t = 0.3, RS = { p = 3.0, y = 0.6, r = -0.3 }, RJ = { tw = 0.4 } },
	{ t = 0.4, RS = { p = 1.7, y = 0.2 }, LS = { p = -0.5 }, RJ = { tw = -0.7, ln = 0.4 }, RH = { p = -0.7 }, LH = { p = 0.9 } },
	{ t = 0.62, RS = { p = 1.0, y = 0.1 }, LS = { p = -0.8 }, RJ = { tw = -0.25, ln = 0.3 }, RH = { p = -0.4 }, LH = { p = 0.4 } },
	{ t = 0.8 },
}
-- tire le ruban vers lui (main sur la poitrine)
A.Yank = {
	{ t = 0 },
	{ t = 0.08, RS = { p = 1.6 }, LS = { p = 1.6 }, RJ = { ln = 0.2 } },
	{ t = 0.22, RS = { p = 0.4, y = 0.9 }, LS = { p = 0.4, y = 0.9 }, RJ = { ln = -0.25 }, RH = { p = 0.5 }, LH = { p = -0.4 } },
	{ t = 0.5, RS = { p = 0.6, y = 0.6 }, LS = { p = 0.6, y = 0.6 }, RJ = { ln = -0.1 } },
}
-- perceuse : poussée à deux mains, tout le corps tremble
local function drillAnim()
	local f = {
		{ t = 0 },
		{ t = 0.12, RS = { p = 0.6, y = 0.3 }, LS = { p = 0.9, y = 0.6 }, RJ = { tw = 0.5, ln = -0.1 }, RH = { p = 0.4 }, LH = { p = -0.3 } }, -- armé
		{ t = 0.2, RS = { p = 1.65, y = 0.05 }, LS = { p = 1.5, y = 0.75 }, RJ = { tw = -0.25, ln = 0.35 }, RH = { p = -0.65 }, LH = { p = 0.85 } }, -- planté
	}
	local t, s = 0.2, 1
	while t < 0.95 do
		t += 0.045
		s = -s
		table.insert(f, { t = t, RS = { p = 1.65 + 0.07 * s, y = 0.05 }, LS = { p = 1.5 - 0.06 * s, y = 0.75 }, RJ = { tw = -0.25 + 0.06 * s, ln = 0.35 + 0.03 * s, sd = 0.04 * s }, RH = { p = -0.65 }, LH = { p = 0.85 } })
	end
	table.insert(f, { t = 1.05, RS = { p = 1.2 }, LS = { p = 1.0, y = 0.6 }, RJ = { ln = 0.15 } })
	return f
end
A.Drill = drillAnim()
-- câbles de démarrage : bras en V au-dessus de la tête, puis double frappe vers la victime
A.Cables = {
	{ t = 0 },
	{ t = 0.16, RS = { p = 3.0, r = -0.6 }, LS = { p = 3.0, r = -0.6 }, RJ = { ln = -0.35 }, RH = { p = 0.15, r = -0.2 }, LH = { p = 0.15, r = -0.2 } },
	{ t = 0.26, RS = { p = 1.75, r = -0.1 }, LS = { p = 1.75, r = -0.1 }, RJ = { ln = 0.45 }, RH = { p = -0.6 }, LH = { p = 0.9 } },
	{ t = 0.55, RS = { p = 1.65, r = -0.15 }, LS = { p = 1.65, r = -0.15 }, RJ = { ln = 0.4, sd = 0.05 }, RH = { p = -0.6 }, LH = { p = 0.9 } },
	{ t = 0.7 },
}
-- sifflet + bras tendu vers le ciel (appelle la grue)
A.Whistle = {
	{ t = 0 },
	{ t = 0.12, LS = { p = 2.4, y = 0.9, r = 0.4 }, RS = { p = 3.1, r = -0.15 }, RJ = { ln = -0.3, tw = 0.25 }, RH = { p = 0.3 }, LH = { p = -0.25 } },
	{ t = 0.5, LS = { p = 2.4, y = 0.9, r = 0.4 }, RS = { p = 3.1, r = -0.15 }, RJ = { ln = -0.25, tw = 0.25 } },
	{ t = 0.62, RS = { p = 2.2, y = 0.6, r = -0.8 }, LS = { p = 0.4 }, RJ = { tw = -0.6, ln = 0.1 } }, -- montre la boule
	{ t = 1.1, RS = { p = 2.0, y = 0.6, r = -0.8 }, LS = { p = 0.4 }, RJ = { tw = -0.5, ln = 0.1 } },
	{ t = 1.3 },
}
-- raté : grande clé abattue au sol
A.Whiff = {
	{ t = 0 },
	{ t = 0.18, RS = { p = 3.05, y = 0.2 }, LS = { p = 3.0, y = 0.2 }, RJ = { ln = -0.4 }, RH = { p = 0.25 }, LH = { p = -0.2 } },
	{ t = 0.3, RS = { p = 1.1 }, LS = { p = 1.1 }, RJ = { ln = 0.65 }, RH = { p = -0.8 }, LH = { p = 1.0 } },
	{ t = 0.75, RS = { p = 1.0 }, LS = { p = 1.0 }, RJ = { ln = 0.55 }, RH = { p = -0.7 }, LH = { p = 0.9 } },
	{ t = 0.9 },
}
-- victime : se tortille dans le ruban / électrocutée
local function jitterAnim(dur, amp, base)
	local f = { { t = 0 } }
	local t, s = 0, 1
	while t < dur do
		t += 0.05
		s = -s
		table.insert(f, { t = t, RS = { p = (base.p or 0.2) + amp * s, r = -0.3 }, LS = { p = (base.p or 0.2) - amp * s, r = -0.3 }, RJ = { sd = 0.12 * s * amp * 3, ln = base.ln or 0.1 }, RH = { p = 0.2 * s }, LH = { p = -0.2 * s } })
	end
	table.insert(f, { t = dur + 0.1 })
	return f
end
A.VWrapped = jitterAnim(1.3, 0.06, { p = 0.05, ln = 0 })
A.VZapped = jitterAnim(0.6, 0.5, { p = 1.5, ln = -0.3 })

------------------------------------------------------------------------
-- Aides client
------------------------------------------------------------------------
local RunService = game:GetService("RunService")
-- joue une anim sans planter si le perso a disparu (mort, ragdoll)
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

-- anneau de ruban (segments rayés) autour d'un point
local function tapeBand(K, data, n, radius, colorA, colorB)
	local segs = {}
	for i = 1, n do
		local p = K.part({ Size = Vector3.new(radius * 1.15, 0.42, 0.16), Color = (i % 2 == 0) and colorA or colorB }, 4)
		K.track(data, p)
		segs[i] = p
	end
	return segs
end
local function placeBand(segs, center, radius, spin, tilt)
	local n = #segs
	for i, p in ipairs(segs) do
		local a = spin + (i / n) * math.pi * 2
		p.CFrame = CFrame.new(center) * CFrame.Angles(tilt, 0, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius)
	end
end

------------------------------------------------------------------------
local M = {
	Name = "DEMOLITION DAY",
	Desc = "Lasso them with caution tape, drill, jump-start, then call in the wrecking ball.",
	Color = HIVIS,
	Color2 = ORANGE,
	Range = 26,
	Angle = 70,
	Timing = T,
}

------------------------------------------------------------------------
-- CLIENT
------------------------------------------------------------------------
function M.Client(K, data)
	local caster, target = data.caster, data.target
	local phase = data.phase

	if phase == "Cutin" then
		-- pendant le cut-in : le gyrophare du casque clignote, étincelles dans la main
		local r = K.root(caster)
		if r then
			K.sound(SND.Chain, r.Position, 0.8, 1.1)
			for i = 0, 4 do
				K.at(data, 0.15 + i * 0.18, function()
					K.light(r.Position + Vector3.new(0, 3, 0), (i % 2 == 0) and ORANGE or HIVIS, 18, 6, 0.15)
					K.sparks(r.Position + r.CFrame.RightVector * 1.5, 6, SPARK)
				end)
			end
		end
		return
	end

	if phase == "Rush" then
		-- lancer du lasso
		play(K, caster, A.Lasso)
		local r = K.root(caster)
		if not r then
			return
		end
		local dir = data.dir or r.CFrame.LookVector
		K.sound("Whoosh", r.Position, 1, 0.8)
		K.at(data, 0.12, function()
			K.sound("Whoosh2", r.Position, 0.9, 1.2)
		end)
		-- boucle de ruban qui tourne au-dessus de la tête
		local loop = tapeBand(K, data, 8, 1.6, HIVIS, DARK)
		run(0.38, function(a)
			placeBand(loop, r.Position + Vector3.new(0, 3.6, 0), 1.6, a * 14, 0)
			if a >= 1 then
				for _, p in ipairs(loop) do
					p:Destroy()
				end
			end
		end)
		-- le ruban part en ligne droite
		K.at(data, 0.38, function()
			local from = r.Position + Vector3.new(0, 1.5, 0)
			local to = data.hitPos or (from + dir * (data.range or 26))
			local n = 10
			for i = 1, n do
				K.at(data, 0.38 + i * 0.012, function()
					local a0, a1 = (i - 1) / n, i / n
					local p0, p1 = from:Lerp(to, a0), from:Lerp(to, a1)
					local seg = K.part({ Size = Vector3.new(0.9, 0.12, (p1 - p0).Magnitude + 0.1), CFrame = CFrame.lookAt(p0:Lerp(p1, 0.5), p1) * CFrame.Angles(0, 0, a1 * 3), Color = (i % 2 == 0) and HIVIS or DARK }, 0.9)
					K.tween(seg, 0.6, { Transparency = 1 })
				end)
			end
			K.streak(from, to, HIVIS, 0.5, 0.25)
			K.word(to + Vector3.new(0, 3, 0), "CAUTION!", 0.9, "Light")
		end)
		return
	end

	if phase == "Whiff" then
		play(K, caster, A.Whiff)
		local r = K.root(caster)
		if not r then
			return
		end
		local wrench = K.prop(data, caster, "Right Arm", Vector3.new(0.6, 4.6, 0.6), CFrame.new(0, -2.6, 0), STEEL, nil, Enum.Material.Metal)
		local head = K.prop(data, caster, "Right Arm", Vector3.new(1.8, 1.2, 1.0), CFrame.new(0, -4.9, 0), STEEL, nil, Enum.Material.Metal)
		K.sound("Whoosh", r.Position, 1, 0.7)
		K.at(data, 0.3, function()
			local pos = K.groundPos(r.Position + r.CFrame.LookVector * 5)
			K.sound("Clang", pos, 1.3, 0.8)
			K.sound(SND.Metal, pos, 1, 1)
			K.shake(0.6)
			K.sparks(pos + Vector3.new(0, 0.5, 0), 30, YELLOW)
			K.sparks(pos + Vector3.new(0, 0.5, 0), 20, SPARK)
			K.shockwave(pos + Vector3.new(0, 0.2, 0), 7, HIVIS)
			K.cracks(pos, 5, 3)
			K.word(pos + Vector3.new(0, 4, 0), "MISSED THE NAIL!", 1.0, "Heavy")
		end)
		K.at(data, 0.85, function()
			if wrench then wrench:Destroy() end
			if head then head:Destroy() end
		end)
		return
	end

	if phase ~= "Connect" then
		return
	end
	K.letterbox(data, true, 0.2)
	----------------------------------------------------------------
	-- SÉQUENCE CINÉMATIQUE
	----------------------------------------------------------------
	local cf = data.cf -- repère du lanceur (face à la victime)
	if not cf then
		local r = K.root(caster)
		cf = r and r.CFrame or CFrame.new()
	end
	local look, right, up = cf.LookVector, cf.RightVector, Vector3.yAxis
	local vp0 = data.vp or (cf.Position + look * 5)
	local function vp()
		return rootPos(target, vp0)
	end
	play(K, caster, A.Yank)
	play(K, target, A.VWrapped)

	-- 1) MOMIFICATION AU RUBAN ------------------------------------
	K.sound(SND.Chain, vp0, 1, 1.3)
	K.sound("Whoosh3", vp0, 0.8, 1.2)
	K.word(vp0 + Vector3.new(0, 4, 0), "TAPED UP!", 1.0, "Heavy")
	K.shot(data, "orbit", { at = function() return vp() end, radius = 10, height = 2.5, angle = 30, speed = 70, basis = cf, lookOffset = Vector3.new(0, 0.5, 0), fov = 60 })
	local bands = {}
	for b = 1, 3 do
		bands[b] = tapeBand(K, data, 7, 1.5, (b % 2 == 0) and HIVIS or DARK, (b % 2 == 0) and DARK or HIVIS)
	end
	run(0.5, function(a)
		local c = vp()
		for b, segs in ipairs(bands) do
			local rad = 1.45 + (1 - a) * 5
			local h = (b - 2) * 1.0 + (1 - a) * 4
			placeBand(segs, c + Vector3.new(0, h, 0), rad, a * 10 + b, (b - 2) * 0.18)
		end
	end)
	-- les bandes restent collées à la victime jusqu'au finisher
	K.at(data, 0.5, function()
		run(T.Wreck - 0.5, function(a)
			local c = vp()
			for b, segs in ipairs(bands) do
				placeBand(segs, c + Vector3.new(0, (b - 2) * 1.0, 0), 1.45, 0.5 * b + math.sin(os.clock() * 30) * 0.03, (b - 2) * 0.18)
			end
		end)
	end)

	-- 2) PERCEUSE GÉANTE -----------------------------------------
	K.at(data, T.Drill0 - 0.2, function()
		play(K, caster, A.Drill)
		local body = K.prop(data, caster, "Right Arm", Vector3.new(1.3, 1.6, 1.3), CFrame.new(0, -1.5, 0), ORANGE)
		local grip = K.prop(data, caster, "Right Arm", Vector3.new(0.8, 1.0, 0.8), CFrame.new(0, -1.1, 0.75), DARK)
		local chuck = K.prop(data, caster, "Right Arm", Vector3.new(0.6, 1.0, 1.0), CFrame.new(0, -2.5, 0) * K.UPRIGHT, DARK, K.CYL)
		local bit1 = K.prop(data, caster, "Right Arm", Vector3.new(1.2, 0.6, 0.6), CFrame.new(0, -3.4, 0) * K.UPRIGHT, STEEL, K.CYL, Enum.Material.Metal)
		local bit2 = K.prop(data, caster, "Right Arm", Vector3.new(1.0, 0.35, 0.35), CFrame.new(0, -4.4, 0) * K.UPRIGHT, STEEL, K.CYL, Enum.Material.Metal)
		K.sound(SND.Drill, vp0, 1.4, 1.1)
		K.shot(data, "fixed", { pos = cf.Position + right * 3.2 + up * 2.2 - look * 3.5, lookAt = vp0 + up * 0.5, fov = 52 })
		for i = 0, 5 do
			K.at(data, T.Drill0 + i * T.DrillStep, function()
				local c = vp()
				local hit = c - look * 0.9 + up * 0.2
				K.sparks(hit, 18, YELLOW)
				K.sparks(hit, 10, SPARK)
				K.shards(hit, 3, { STEEL, YELLOW, HIVIS }, 0.8)
				K.ring(CFrame.lookAt(hit, hit + look), 3 + i * 0.6, (i % 2 == 0) and HIVIS or ORANGE, 0.18, 0.25)
				K.shake(0.35 + i * 0.05)
				K.sound("MetalHit", hit, 0.7, 1.3 + i * 0.06)
				if K.isCaster(data) or K.isVictim(data) then
					K.fov(2)
				end
				if i == 0 then
					K.word(c + up * 3.5, "DRRRRR!", 1.1, "Heavy")
				elseif i == 5 then
					K.impactFrames("W", 0.04)
					K.word(c + up * 3 + right * 2, "SCREWED!", 1.0, "Heavy")
				end
			end)
		end
		K.at(data, T.Cables - 0.3, function()
			for _, p in ipairs({ body, grip, chuck, bit1, bit2 }) do
				if p then p:Destroy() end
			end
		end)
	end)

	-- 3) CÂBLES DE DÉMARRAGE -------------------------------------
	K.at(data, T.Cables - 0.26, function()
		play(K, caster, A.Cables)
		local clampR = K.prop(data, caster, "Right Arm", Vector3.new(0.7, 0.9, 0.5), CFrame.new(0, -1.3, 0), Color3.fromRGB(220, 40, 35))
		local clampL = K.prop(data, caster, "Left Arm", Vector3.new(0.7, 0.9, 0.5), CFrame.new(0, -1.3, 0), DARK)
		K.sound("Electric", cf.Position, 1, 0.9)
		K.shot(data, "fixed", { pos = vp0 + look * 7.5 + up * 0.6 + right * 1.5, lookAt = cf.Position:Lerp(vp0, 0.45) + up * 1, fov = 62 })
		for i = 0, 5 do
			K.at(data, T.Cables - 0.24 + i * 0.04, function()
				if clampR then
					K.sparks(clampR.Position, 4, SPARK)
				end
			end)
		end
		K.at(data, T.Cables, function()
			play(K, target, A.VZapped)
			local c = vp()
			K.sound(SND.Zap, c, 1.4, 1)
			K.sound(SND.Zap2, c, 1.2, 0.8)
			K.sound("Lightning", c, 1, 1)
			K.impactFrames("IBIW", 0.045)
			K.shake(1.1)
			for k = 1, 3 do
				local from = (k == 1 and clampR and clampR.Position) or (k == 2 and clampL and clampL.Position) or (c + up * 14)
				K.bolt(from, c, SPARK, 0.45, 0.25, 1.4)
				K.bolt(from, c + Vector3.new(K.rng:NextNumber(-1, 1), 1, K.rng:NextNumber(-1, 1)), Color3.new(1, 1, 1), 0.2, 0.2, 1.8)
			end
			K.sphere(c, 9, SPARK, 0.3, 2)
			K.light(c, SPARK, 30, 8, 0.4)
			K.sparks(c, 40, SPARK)
			K.word(c + up * 4, "BZZZZT!", 1.4, "Heavy")
			-- la victime devient silhouette électrique
			if target then
				K.afterimage(target, SPARK, 0.4, 0.2)
				K.at(data, T.Cables + 0.15, function()
					K.afterimage(target, Color3.new(1, 1, 1), 0.3, 0.3)
					K.bolt(c + up * 3, c - up * 2, SPARK, 0.3, 0.2, 2)
				end)
			end
		end)
		K.at(data, T.Whistle, function()
			if clampR then clampR:Destroy() end
			if clampL then clampL:Destroy() end
		end)
	end)

	-- 4) BOULE DE DÉMOLITION -------------------------------------
	K.at(data, T.Whistle, function()
		play(K, caster, A.Whistle)
		K.sound("Whistle", cf.Position, 1.2, 1)
		K.word(cf.Position + up * 4.5, "FWEEEET!", 0.9, "Light")
		local mid = cf.Position:Lerp(vp0, 0.5)
		K.shot(data, "fixed", { pos = mid - right * 17 + up * 3.5 - look * 4, lookAt = vp0 + right * 3 + up * 2.5, fov = 64 })
		-- la boule arrive de la droite (du côté +right), pendule autour d'un pivot au-dessus de la victime
		local pivot = vp0 + up * 17
		local L = 16
		local ball = K.part({ Shape = K.BALL, Size = Vector3.one * 6.5, Color = DARK, Material = Enum.Material.Metal }, 4)
		local band = K.part({ Shape = K.CYL, Size = Vector3.new(1.2, 6.7, 6.7), Color = HIVIS }, 4)
		local hook = K.part({ Size = Vector3.new(1.2, 1.6, 1.2), Color = STEEL, Material = Enum.Material.Metal }, 4)
		K.track(data, ball)
		K.track(data, band)
		K.track(data, hook)
		local links = {}
		for i = 1, 7 do
			links[i] = K.part({ Size = Vector3.new(0.5, 2.0, 0.9), Color = STEEL, Material = Enum.Material.Metal }, 4)
			K.track(data, links[i])
		end
		local function placeBall(angle)
			-- angle 0 = en bas (sur la victime), + = vers la droite
			local off = right * math.sin(angle) * L - up * math.cos(angle) * L
			local bp = pivot + off
			ball.CFrame = CFrame.lookAt(bp, bp + look) * CFrame.Angles(0, 0, angle)
			band.CFrame = CFrame.lookAt(bp, pivot) * CFrame.Angles(0, math.pi / 2, 0)
			hook.CFrame = CFrame.lookAt(bp + (pivot - bp).Unit * 3.6, pivot)
			for i, l in ipairs(links) do
				local a = (i - 0.5) / #links
				local lp = pivot:Lerp(bp, a * 0.8)
				l.CFrame = CFrame.lookAt(lp, pivot) * CFrame.Angles(math.pi / 2, (i % 2) * math.pi / 2, 0)
			end
			return bp
		end
		placeBall(1.35)
		-- grincement + armement
		K.sound(SND.Chain, pivot, 1.2, 0.7)
		K.at(data, T.Wreck - 0.45, function()
			K.sound("Whoosh", vp0 + right * 6, 1.4, 0.55)
			K.sound("Whoosh2", vp0 + right * 6, 1, 0.7)
			local last = nil
			run(0.45, function(a)
				local e = a * a
				local bp = placeBall(1.35 * (1 - e))
				if last and (bp - last).Magnitude > 0.5 then
					K.streak(last, bp, Color3.new(1, 1, 1), 2.5, 0.15)
				end
				last = bp
			end)
		end)
		-- IMPACT
		K.at(data, T.Wreck, function()
			local c = vp0
			K.impactFrames("WBWB", 0.05)
			K.layer({ { SND.MetalBoom, 1.6 }, { "Boom", 1.5 }, { "Bass", 1.3, 0.9 }, { "Explosion", 1.2, 1, 0.05 }, { SND.Metal, 1.2, 0.8 } }, c)
			K.shake(2)
			K.fov(10)
			K.bigImpact(c, -right, 1.6, HIVIS)
			K.ring(CFrame.lookAt(c, c - right), 18, HIVIS, 0.35, 0.6)
			K.ring(CFrame.lookAt(c, c - right), 26, Color3.new(1, 1, 1), 0.45, 0.4)
			K.sphere(c, 14, ORANGE, 0.35, 3)
			K.light(c, ORANGE, 40, 10, 0.5)
			K.debris(c, 10, { DARK, HIVIS, STEEL }, 1.4, 1.2)
			K.shards(c, 12, { HIVIS, DARK, YELLOW }, 1.6)
			K.quake(c, 12, HIVIS, 1.2)
			K.word(c + up * 5, "WRECKED!!", 1.8, "Heavy")
			-- ruban qui explose en confettis rayés
			for _, segs in ipairs(bands) do
				for _, p in ipairs(segs) do
					if p.Parent then
						local d = (p.Position - c)
						d = (d.Magnitude > 0.1 and d.Unit or Vector3.yAxis) - right
						K.tween(p, 0.6, { CFrame = p.CFrame + d * 9 + up * 3, Transparency = 1 })
					end
				end
			end
			-- la boule continue sa course et disparaît
			run(0.5, function(a)
				placeBall(-1.2 * a)
				if a >= 1 then
					for _, p in ipairs({ ball, band, hook }) do
						K.tween(p, 0.3, { Transparency = 1 })
					end
					for _, l in ipairs(links) do
						K.tween(l, 0.3, { Transparency = 1 })
					end
				end
			end)
			-- caméra : on suit le vol de la victime
			K.shot(data, "track", { from = c + right * 9 + up * 4 + look * 6, at = function() return vp() end, fov = 70 })
			-- traînée de vol
			K.at(data, T.Wreck + 0.05, function()
				if target then
					local tr = target:FindFirstChild("Torso")
					if tr then
						K.CFX.trailOn(tr, HIVIS, 0.7, 0, 2)
					end
				end
			end)
		end)
		K.at(data, T.Wreck + 0.55, function()
			K.word(vp() + up * 3, "UNDER CONSTRUCTION", 0.9, "Light")
		end)
	end)
end

------------------------------------------------------------------------
-- SERVEUR (logique, temps, dégâts) — voir en-tête de UltimateService
------------------------------------------------------------------------
function M.Server(U, caster, target, ctx)
	local cf = U.currentCF(ctx, caster)
	local look = U.flat(cf.LookVector)
	local ok = target ~= nil and U.valid(target, ctx)
	if ok then
		look = U.flat(U.root(target).Position - cf.Position, look)
		cf = CFrame.lookAt(cf.Position, cf.Position + look)
		U.place(ctx, caster, cf)
	end
	U.fx(ctx, "Rush", { dir = look, range = ctx.range, hitPos = ok and U.root(target).Position or nil })
	if not U.wait(ctx, 0.42) then
		return
	end
	if ok then
		local vr = U.root(target)
		ok = U.valid(target, ctx) and vr ~= nil and (vr.Position - cf.Position).Magnitude <= ctx.range + 6
	end
	if not ok then
		U.fx(ctx, "Whiff")
		U.wait(ctx, 0.95)
		return
	end
	-- le ruban ramène la victime juste devant lui
	local vr = U.root(target)
	cf = U.facing(cf.Position, vr.Position)
	U.place(ctx, caster, cf)
	local vp = U.wallSafe(cf.Position, cf.Position + cf.LookVector * 5, 1.5)
	U.hold(ctx, target, U.facing(vr.Position, cf.Position))
	U.glide(ctx, target, U.facing(vp, cf.Position), 0.22, "In")
	U.fx(ctx, "Connect", { cf = cf, vp = vp })
	local tc = os.clock()
	local function at(t)
		return U.wait(ctx, math.max(0, t - (os.clock() - tc)))
	end
	-- perceuse : 6 ticks
	for i = 0, 5 do
		if not at(T.Drill0 + i * T.DrillStep) then
			return
		end
		U.hit(ctx, target, 1.5, { power = 0.35, words = { "DRRR!", "BZZ!", "GRIND!" }, stun = 0.6 })
	end
	-- câbles de démarrage
	if not at(T.Cables) then
		return
	end
	U.hit(ctx, target, 8, { power = 0.9, words = { "ZAP!", "SHOCKED!" }, stun = 0.8 })
	-- boule de démolition : éjection latérale très loin
	if not at(T.Wreck) then
		return
	end
	local away = -cf.RightVector
	U.finish(ctx, target, 15, { launch = away * 95 + Vector3.new(0, 42, 0), words = { "WRECKED!" }, splash = { radius = 12, damage = 10, center = vp } })
	at(T.End)
end

return M
