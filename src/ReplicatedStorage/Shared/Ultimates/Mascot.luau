--[[
	ULTIME — The Mascot : « HALFTIME SPECTACULAR »
	Roue rebondissante vers la cible. Touché → les projecteurs du stade convergent sur la victime (foule en délire),
	uppercut au doigt en mousse qui l'envoie en l'air, il la rejoint pour une toupie de pom-poms (5 coups),
	salve de T-shirts à bout portant, un panier de basket géant sort du sol et il la SMASHE à travers le cercle
	jusqu'au sol (finisher PIN + cratère), feu d'artifice et tableau des scores.
	Raté → il trébuche sur sa grosse tête, la foule hue.
]]
local RED = Color3.fromRGB(230, 45, 45)
local YELLOW = Color3.fromRGB(255, 215, 40)
local WHITE = Color3.fromRGB(250, 250, 250)
local BLUE = Color3.fromRGB(50, 120, 255)
local ORANGE = Color3.fromRGB(255, 120, 30)
local PARTY = { RED, YELLOW, WHITE, BLUE, Color3.fromRGB(255, 90, 200), Color3.fromRGB(80, 230, 120) }

local SND = {
	Crowd = "rbxassetid://9120973900",
	Cheer = "rbxassetid://132079977802654",
	Boo = "rbxassetid://9120974911",
	Horn = "rbxassetid://132844961288199",
	Firework = "rbxassetid://75191072171555",
}

local T = { Up = 0.4, Spin0 = 0.85, SpinStep = 0.12, Shirt0 = 1.55, ShirtStep = 0.08, Hoop = 1.75, Grab = 2.1, Dunk = 2.32, Slam = 2.6, End = 3.45 }
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
-- roue / saut de mains vers la cible
A.Cartwheel = {
	{ t = 0 },
	{ t = 0.08, RS = { p = 0.3, r = -0.4 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = 0.4 }, RH = { p = 0.8 }, LH = { p = 0.8 } },
	{ t = 0.18, RS = { p = 3.0, r = -0.6 }, LS = { p = 3.0, r = -0.6 }, RJ = { sd = 1.2, ln = 0.1 }, RH = { r = -0.8 }, LH = { r = -0.8 } },
	{ t = 0.3, RS = { p = 3.0, r = -0.6 }, LS = { p = 3.0, r = -0.6 }, RJ = { sd = 2.6 }, RH = { r = -0.9 }, LH = { r = -0.9 } },
	{ t = 0.42, RS = { p = 2.0, r = -0.8 }, LS = { p = 2.0, r = -0.8 }, RJ = { sd = 0.2, ln = 0.2 }, RH = { p = 0.5 }, LH = { p = -0.2 } },
	{ t = 0.55 },
}
-- uppercut au doigt en mousse (main gauche)
A.Upper = {
	{ t = 0 },
	{ t = 0.12, LS = { p = -0.4, r = -0.2 }, RS = { p = 0.6 }, RJ = { ln = 0.55, tw = 0.4 }, RH = { p = 1.0 }, LH = { p = 1.0 } }, -- accroupi
	{ t = 0.22, LS = { p = 3.15, y = 0.1 }, RS = { p = 0.2, r = -0.5 }, RJ = { ln = -0.4, tw = -0.35 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
	{ t = 0.45, LS = { p = 3.1, y = 0.1 }, RS = { p = 0.3, r = -0.5 }, RJ = { ln = -0.3, tw = -0.3 } },
	{ t = 0.55 },
}
-- toupie de pom-poms : tour complet du buste à chaque coup, bras écartés
local function spinAnim()
	local f = { { t = 0 }, { t = 0.06, RS = { p = 1.6, r = -1.3 }, LS = { p = 1.6, r = -1.3 }, RJ = { tw = 0 }, RH = { p = 0.4 }, LH = { p = -0.3 } } }
	local t = 0.06
	for i = 1, 5 do
		t += 0.12
		table.insert(f, { t = t, RS = { p = 1.6, r = -1.3 }, LS = { p = 1.6, r = -1.3 }, RJ = { tw = i * 6.283, ln = (i % 2) * 0.15 }, RH = { p = 0.4 * ((i % 2) * 2 - 1) }, LH = { p = -0.4 * ((i % 2) * 2 - 1) } })
	end
	table.insert(f, { t = t + 0.001, RS = { p = 1.6, r = -1.3 }, LS = { p = 1.6, r = -1.3 }, RJ = { tw = 0 } })
	table.insert(f, { t = t + 0.1 })
	return f
end
A.Spin = spinAnim()
-- canon à T-shirts calé sur l'épaule (main droite)
local function shirtAnim()
	local f = { { t = 0 }, { t = 0.1, RS = { p = 1.7, y = 0.1 }, LS = { p = 1.5, y = 0.7 }, RJ = { ln = 0.1, tw = -0.15 } } }
	local t = 0.1
	for i = 1, 4 do
		t += 0.04
		table.insert(f, { t = t, RS = { p = 1.95, y = 0.1 }, LS = { p = 1.75, y = 0.7 }, RJ = { ln = -0.12, tw = -0.15 } })
		t += 0.04
		table.insert(f, { t = t, RS = { p = 1.7, y = 0.1 }, LS = { p = 1.5, y = 0.7 }, RJ = { ln = 0.1, tw = -0.15 } })
	end
	table.insert(f, { t = t + 0.15 })
	return f
end
A.Shirt = shirtAnim()
-- smash : bras au-dessus de la tête puis abattus, pieds groupés
A.Dunk = {
	{ t = 0 },
	{ t = 0.15, RS = { p = 3.1, r = -0.15 }, LS = { p = 3.1, r = -0.15 }, RJ = { ln = -0.5 }, RH = { p = -0.4 }, LH = { p = -0.4 } },
	{ t = 0.3, RS = { p = 3.1, r = -0.15 }, LS = { p = 3.1, r = -0.15 }, RJ = { ln = -0.4 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
	{ t = 0.42, RS = { p = 1.0 }, LS = { p = 1.0 }, RJ = { ln = 0.75 }, RH = { p = 1.2 }, LH = { p = 1.2 } },
	{ t = 0.75, RS = { p = 0.9 }, LS = { p = 0.9 }, RJ = { ln = 0.6 }, RH = { p = 1.0 }, LH = { p = 1.0 } },
	{ t = 0.95, RS = { p = 3.1, r = -0.4 }, LS = { p = 3.1, r = -0.4 }, RJ = { ln = -0.2 } }, -- bras levés, victoire
	{ t = 1.25 },
}
-- raté : trébuche et plante sa grosse tête au sol
A.Whiff = {
	{ t = 0 },
	{ t = 0.12, RS = { p = 2.2, r = -0.8 }, LS = { p = 2.6, r = -0.4 }, RJ = { ln = 0.6, sd = 0.2 }, RH = { p = -0.6 }, LH = { p = 0.9 } },
	{ t = 0.25, RS = { p = 3.0, r = -1.0 }, LS = { p = 3.0, r = -1.0 }, RJ = { ln = 1.45 }, RH = { p = -1.2 }, LH = { p = -1.0 } },
	{ t = 0.65, RS = { p = 3.0, r = -1.1 }, LS = { p = 3.0, r = -1.1 }, RJ = { ln = 1.4, sd = 0.1 }, RH = { p = -1.1 }, LH = { p = -0.9 } },
	{ t = 0.85 },
}
-- victime : projetée, bras qui battent / groupée pendant le smash
local function flailAnim(dur)
	local f = { { t = 0 } }
	local t, s = 0, 1
	while t < dur do
		t += 0.08
		s = -s
		table.insert(f, { t = t, RS = { p = 2.4 + 0.5 * s, r = -0.6 }, LS = { p = 2.4 - 0.5 * s, r = -0.6 }, RJ = { ln = -0.3, sd = 0.15 * s }, RH = { p = 0.4 * s }, LH = { p = -0.4 * s } })
	end
	table.insert(f, { t = dur + 0.1 })
	return f
end
A.VFlail = flailAnim(1.6)
A.VDunk = { { t = 0 }, { t = 0.08, RS = { p = 3.1 }, LS = { p = 3.1 }, RJ = { ln = 0.5 }, RH = { p = 1.2 }, LH = { p = 1.2 } }, { t = 0.4, RS = { p = 3.1 }, LS = { p = 3.1 }, RJ = { ln = 0.5 }, RH = { p = 1.2 }, LH = { p = 1.2 } }, { t = 0.5 } }

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

------------------------------------------------------------------------
local M = {
	Name = "HALFTIME SPECTACULAR",
	-- v3 : titres de temps forts (UltimateController) ; Anticipate = poses d'armement avant ces coups
	Beats = { Connect = { { 0, "SPOTLIGHT" }, { T.Spin0, "POM-POM SPIN" }, { T.Shirt0, "T-SHIRT CANNON" }, { T.Hoop, "BUZZER BEATER" } } },
	Anticipate = { Connect = { T.Up } },
	Desc = "Spotlight, foam-finger launch, pom-pom tornado, T-shirt volley and a SLAM DUNK through a giant hoop.",
	Color = RED,
	Color2 = YELLOW,
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
			K.sound("Boing", r.Position, 1, 1.1)
			K.sound(SND.Cheer, r.Position, 0.6, 1.05)
			for i = 0, 2 do
				K.at(data, 0.1 + i * 0.25, function()
					K.shards(r.Position + Vector3.new(0, 3, 0), 10, PARTY, 0.8)
				end)
			end
		end
		return
	end

	if phase == "Rush" then
		play(K, caster, A.Cartwheel)
		local r = K.root(caster)
		if not r then
			return
		end
		K.sound("Boing", r.Position, 1, 1.2)
		K.sound("Whoosh", r.Position, 1, 1.1)
		for i = 0, 4 do
			K.at(data, i * 0.09, function()
				local rr = K.root(caster)
				if rr then
					K.shards(rr.Position, 4, PARTY, 0.5)
					K.afterimage(caster, PARTY[(i % #PARTY) + 1], 0.25, 0.5)
				end
			end)
		end
		return
	end

	if phase == "Whiff" then
		play(K, caster, A.Whiff)
		local r = K.root(caster)
		if r then
			K.at(data, 0.25, function()
				local g = K.groundPos(r.Position + r.CFrame.LookVector * 2)
				K.sound("Boing", g, 1.3, 0.8)
				K.sound(SND.Boo, g, 0.9, 1)
				K.dust(g, 4, nil, 8)
				K.word(r.Position + Vector3.new(0, 4, 0), "OOPS!", 1.2, "Heavy")
				K.CFX.dizzy(caster, 0.6)
			end)
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
	local H = data.h or 9
	local function vp()
		return rootPos(target, vp0)
	end
	local function cp()
		return rootPos(caster, cf.Position)
	end
	local g0 = K.groundPos(vp0)

	-- 1) PROJECTEURS DU STADE ------------------------------------
	local crowd = K.sound(SND.Crowd, nil, 0.0, 1)
	if crowd then
		crowd.TimePosition = 1
		K.tween(crowd, 0.4, { Volume = 0.7 })
		K.at(data, T.End - 0.4, function()
			K.tween(crowd, 0.5, { Volume = 0 })
		end)
	end
	K.word(vp0 + up * 4.5, "IT'S SHOWTIME!", 1.2, "Heavy")
	K.shot(data, "orbit", { at = function() return cp():Lerp(vp(), 0.5) end, radius = 13, height = 2.5, angle = 70, speed = 40, basis = cf, fov = 62 })
	local beams = {}
	for k = 1, 4 do
		local a = math.rad(45 + k * 90)
		local top = g0 + Vector3.new(math.cos(a) * 14, 24, math.sin(a) * 14)
		local b = K.part({ Size = Vector3.new(2.2, 2.2, 1), Color = Color3.fromRGB(255, 250, 210), Material = Enum.Material.Neon, Transparency = 1 }, 4)
		K.track(data, b)
		beams[k] = { p = b, top = top }
	end
	run(T.Slam + 0.3, function(a)
		local c = vp()
		for _, b in ipairs(beams) do
			local d = c - b.top
			b.p.Size = Vector3.new(2.4, 2.4, d.Magnitude)
			b.p.CFrame = CFrame.lookAt(b.top + d / 2, c)
			b.p.Transparency = 0.72 + 0.1 * math.sin(os.clock() * 20)
		end
		if a >= 1 then
			for _, b in ipairs(beams) do
				K.tween(b.p, 0.3, { Transparency = 1 })
			end
		end
	end)
	K.light(vp0, Color3.fromRGB(255, 250, 210), 25, 4, 3)

	-- 2) UPPERCUT AU DOIGT EN MOUSSE ------------------------------
	K.at(data, T.Up - 0.22, function()
		play(K, caster, A.Upper)
		K.sound("Whoosh2", cp(), 1, 1)
	end)
	K.at(data, T.Up, function()
		local c = vp()
		play(K, target, A.VFlail)
		K.layer({ { "Uppercut", 1.3 }, { "Boing", 1, 0.9 }, { "PunchHeavy", 1 } }, c)
		K.impactFrames("W", 0.05)
		K.shake(1)
		K.bigImpact(c, up, 1.1, YELLOW)
		K.airRing(c, up, 9, YELLOW, 0.3)
		K.word(c + up * 3, "WE'RE #1!", 1.4, "Heavy")
		K.shot(data, "track", { from = c + look * 7 - right * 8 + up * 0.5, at = function() return vp() end, fov = 70 })
		if target then
			local tr = target:FindFirstChild("Torso")
			if tr then
				K.CFX.trailOn(tr, YELLOW, 0.4, 0, 1.5)
			end
		end
	end)

	-- 3) TOUPIE DE POM-POMS EN L'AIR -------------------------------
	K.at(data, T.Spin0 - 0.12, function()
		play(K, caster, A.Spin)
		local pomR = K.prop(data, caster, "Right Arm", Vector3.one * 1.5, CFrame.new(0, -1.2, 0), RED, K.BALL)
		local pomL = K.prop(data, caster, "Left Arm", Vector3.one * 1.5, CFrame.new(0, -1.2, 0), YELLOW, K.BALL)
		K.sound("Whoosh3", cp(), 1, 1.2)
		K.shot(data, "orbit", { at = function() return cp():Lerp(vp(), 0.5) end, radius = 12, height = 1, angle = -60, speed = 140, basis = cf, fov = 64 })
		for i = 0, 4 do
			K.at(data, T.Spin0 + i * T.SpinStep, function()
				local c = vp()
				K.sound("Punch", c, 0.9, 1.1 + i * 0.05)
				K.sound("Whoosh", c, 0.6, 1.4)
				K.shards(c, 8, PARTY, 1.1)
				K.slashArc(CFrame.lookAt(cp(), c), 4.5, PARTY[i + 1], -120, 120, 0.1, i * 25 - 50, 0.5)
				K.sparks(c, 10, PARTY[i + 1])
				K.shake(0.45)
				if i == 1 then
					K.word(c + up * 2.5 - right * 2, "GO!", 1.0, "Light")
				elseif i == 3 then
					K.word(c + up * 2.5 + right * 2, "TEAM!", 1.1, "Light")
				end
			end)
		end
		K.at(data, T.Shirt0 - 0.1, function()
			if pomR then pomR:Destroy() end
			if pomL then pomL:Destroy() end
		end)
	end)

	-- 4) SALVE DE T-SHIRTS ----------------------------------------
	K.at(data, T.Shirt0 - 0.12, function()
		play(K, caster, A.Shirt)
		local barrel = K.prop(data, caster, "Right Arm", Vector3.new(3.2, 1.0, 1.0), CFrame.new(0, -1.9, 0) * K.UPRIGHT, Color3.fromRGB(150, 155, 165), K.CYL, Enum.Material.Metal)
		local mouth = K.prop(data, caster, "Right Arm", Vector3.new(0.3, 1.25, 1.25), CFrame.new(0, -3.5, 0) * K.UPRIGHT, RED, K.CYL)
		K.shot(data, "fixed", { pos = cp() - look * 3 + right * 2.5 + up * 1.2, lookAt = vp(), fov = 56 })
		for i = 0, 3 do
			K.at(data, T.Shirt0 + i * T.ShirtStep - 0.06, function()
				local from = (mouth and mouth.Position) or cp()
				local to = vp()
				K.sound("Throw", from, 1, 0.8 + i * 0.1)
				K.puff(from, 1.2)
				local shirt = K.part({ Shape = K.CYL, Size = Vector3.new(1.6, 0.9, 0.9), CFrame = CFrame.lookAt(from, to) * CFrame.Angles(0, math.pi / 2, 0), Color = ({ RED, WHITE, YELLOW, BLUE })[i + 1] }, 0.4)
				K.tween(shirt, 0.06, { CFrame = CFrame.lookAt(to, to + (to - from).Unit) * CFrame.Angles(0, math.pi / 2, 0) })
				K.at(data, T.Shirt0 + i * T.ShirtStep, function()
					shirt:Destroy()
					K.sound("PlasticHit", to, 1, 1.2)
					K.sparks(to, 8, WHITE)
					K.ring(CFrame.lookAt(to, from), 4, WHITE, 0.2, 0.25)
					if i == 3 then
						K.word(to + up * 2.5, "FREE SHIRT!", 1.1, "Heavy")
						K.impactFrames("I", 0.04)
					end
				end)
			end)
		end
		K.at(data, T.Grab - 0.05, function()
			if barrel then barrel:Destroy() end
			if mouth then mouth:Destroy() end
		end)
	end)

	-- 5) PANIER GÉANT ---------------------------------------------
	local rimH = math.max(3.5, math.min(H - 1, 8.5))
	local hoopParts = {}
	K.at(data, T.Hoop, function()
		local base = CFrame.lookAt(g0, g0 - look) -- dos tourné au lanceur
		local function piece(size, off, color, shape, mat)
			local p = K.part({ Size = size, CFrame = base * off * CFrame.new(0, -14, 0), Color = color, Shape = shape or Enum.PartType.Block, Material = mat or Enum.Material.SmoothPlastic }, 3)
			K.track(data, p)
			table.insert(hoopParts, { p = p, cf = base * off })
			return p
		end
		-- poteau derrière la victime (côté opposé au lanceur), panneau, cercle orange
		piece(Vector3.new(rimH + 3, 0.8, 0.8), CFrame.new(0, (rimH + 3) / 2, -4.6) * K.UPRIGHT, Color3.fromRGB(140, 145, 155), K.CYL, Enum.Material.Metal)
		piece(Vector3.new(0.6, 0.6, 2.4), CFrame.new(0, rimH + 1.5, -3.4), Color3.fromRGB(140, 145, 155), nil, Enum.Material.Metal)
		piece(Vector3.new(6, 4, 0.3), CFrame.new(0, rimH + 1.6, -2.2), WHITE)
		piece(Vector3.new(2.2, 1.6, 0.32), CFrame.new(0, rimH + 1.0, -2.2), RED)
		local n = 10
		for i = 1, n do
			local a = (i / n) * math.pi * 2
			piece(Vector3.new(0.3, 0.3, 1.2), CFrame.new(math.cos(a) * 1.9, rimH, math.sin(a) * 1.9 - 0.1) * CFrame.Angles(0, -a, 0), ORANGE, nil, Enum.Material.Neon)
		end
		-- filet
		for i = 1, 5 do
			local a = (i / 5) * math.pi * 2
			piece(Vector3.new(0.12, 1.6, 0.12), CFrame.new(math.cos(a) * 1.5, rimH - 0.8, math.sin(a) * 1.5 - 0.1), WHITE)
		end
		for _, h in ipairs(hoopParts) do
			K.tween(h.p, 0.35, { CFrame = h.cf }, Enum.EasingStyle.Back)
		end
		K.sound("Rumble", g0, 1, 1.3)
		K.sound("Clang", g0, 0.8, 0.8)
		K.dust(g0 + look * 4, 6, nil, 10)
		K.word(g0 + up * (rimH + 4), "BUZZER BEATER!", 1.0, "Light")
	end)

	-- 6) SLAM DUNK ------------------------------------------------
	K.at(data, T.Grab, function()
		play(K, caster, A.Dunk)
		play(K, target, A.VDunk)
		K.sound("Whoosh", vp(), 1.2, 0.8)
		K.speedLines(0.4, YELLOW)
		-- caméra sous le panier, vers le haut
		K.shot(data, "fixed", { pos = g0 - look * 2 + right * 8 + up * 1.5, lookAt = g0 + up * (rimH * 0.6), fov = 72 })
	end)
	K.at(data, T.Dunk, function()
		K.sound("Whoosh2", vp(), 1.4, 0.6)
		local last = vp()
		run(T.Slam - T.Dunk, function()
			local c = vp()
			if (c - last).Magnitude > 0.5 then
				K.streak(last, c, ORANGE, 1.6, 0.18)
			end
			last = c
		end)
	end)
	K.at(data, T.Slam, function()
		local c = g0 + up * 1
		K.impactFrames("WBWB", 0.05)
		K.layer({ { "Boom", 1.6 }, { "Bass", 1.4, 0.85 }, { "GroundSlam", 1.3 }, { "Boing", 1, 0.6 }, { SND.Horn, 1.2, 1, 0.12 }, { SND.Cheer, 1, 1, 0.15 } }, c)
		K.shake(2)
		K.fov(12)
		K.crater(c, 10, YELLOW, 3)
		K.quake(c, 12, RED, 1.2)
		K.sphere(c, 12, YELLOW, 0.35, 3)
		K.light(c, YELLOW, 40, 10, 0.5)
		K.debris(c, 8, nil, 1.3, 1.1)
		K.shards(c + up * 2, 16, PARTY, 1.6)
		K.word(c + up * 6, "SLAM DUNK!!", 2.0, "Heavy")
		-- le cercle tremble
		for _, h in ipairs(hoopParts) do
			if h.p.Parent then
				K.tween(h.p, 0.08, { CFrame = h.cf * CFrame.new(0, -0.35, 0) }).Completed:Connect(function()
					if h.p.Parent then
						K.tween(h.p, 0.3, { CFrame = h.cf }, Enum.EasingStyle.Elastic)
					end
				end)
			end
		end
		K.at(data, T.Slam + 0.55, function()
			for _, h in ipairs(hoopParts) do
				if h.p.Parent then
					K.tween(h.p, 0.35, { CFrame = h.cf * CFrame.new(0, -14, 0) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				end
			end
		end)
		-- feu d'artifice derrière le panier
		for k = 1, 4 do
			K.at(data, T.Slam + 0.12 + k * 0.1, function()
				local p = g0 + look * 6 + right * K.rng:NextNumber(-8, 8) + up * K.rng:NextNumber(9, 15)
				K.sound(SND.Firework, p, 0.9, 0.9 + k * 0.08)
				K.sphere(p, 8, PARTY[k], 0.4, 1)
				K.shards(p, 12, PARTY, 1.3)
				K.light(p, PARTY[k], 35, 6, 0.4)
			end)
		end
		K.shot(data, "orbit", { at = c, radius = 15, height = 5, angle = 30, speed = 30, basis = cf, fov = 66 })
		K.at(data, T.Slam + 0.4, function()
			K.word(g0 + up * 9 + look * 3, "HOME 2 : 0 AWAY", 1.0, "Light")
		end)
	end)
end

function M.Server(U, caster, target, ctx)
	U.fx(ctx, "Rush")
	if not U.rush(ctx, target, { speed = 95, contact = 4.5, maxTime = 0.55, whiffDist = 14, whiffTime = 0.3 }) then
		U.fx(ctx, "Whiff")
		U.wait(ctx, 0.85)
		return
	end
	local cf = U.currentCF(ctx, caster)
	local vr = U.root(target)
	cf = U.facing(cf.Position, vr.Position)
	U.place(ctx, caster, cf)
	local vp = U.wallSafe(cf.Position, cf.Position + cf.LookVector * 4, 1.5)
	vp = Vector3.new(vp.X, cf.Position.Y, vp.Z)
	local H = math.clamp(U.headroom(vp, 12), 3, 9)
	local vcf = U.facing(vp, cf.Position)
	U.hold(ctx, target, vcf)
	U.fx(ctx, "Connect", { cf = cf, vp = vp, h = H })
	local tc = os.clock()
	local function at(t)
		return U.wait(ctx, math.max(0, t - (os.clock() - tc)))
	end
	local upV = Vector3.new(0, H, 0)
	-- uppercut : la victime monte
	if not at(T.Up) then
		return
	end
	U.hit(ctx, target, 4, { power = 0.8, words = { "WE'RE #1!" }, stun = 0.8 })
	U.glide(ctx, target, vcf + upV, 0.35, "Out")
	-- il la rejoint en l'air
	if not at(T.Up + 0.2) then
		return
	end
	U.glide(ctx, caster, cf + upV * 0.85 + cf.LookVector * 0.8, 0.3, "Out")
	for i = 0, 4 do
		if not at(T.Spin0 + i * T.SpinStep) then
			return
		end
		U.hit(ctx, target, 2, { power = 0.4, words = { "GO!", "TEAM!", "RAH!" }, stun = 0.6 })
	end
	for i = 0, 3 do
		if not at(T.Shirt0 + i * T.ShirtStep) then
			return
		end
		U.hit(ctx, target, 1.5, { power = 0.35, words = { "THWUMP!", "FREE SHIRT!" }, stun = 0.6 })
		U.place(ctx, target, vcf + upV + Vector3.new(0, 0.25 * (i + 1), 0))
	end
	-- il passe au-dessus d'elle et l'attrape
	if not at(T.Grab) then
		return
	end
	U.glide(ctx, caster, U.facing(vp + upV + Vector3.new(0, 3.2, 0) - cf.LookVector * 1.2, vp), 0.2, "Out")
	-- smash : les deux redescendent
	if not at(T.Dunk) then
		return
	end
	U.glide(ctx, target, vcf, T.Slam - T.Dunk, "In")
	U.glide(ctx, caster, U.facing(vp + Vector3.new(0, 2.6, 0) - cf.LookVector * 2.2, vp), T.Slam - T.Dunk, "In")
	if not at(T.Slam) then
		return
	end
	U.finish(ctx, target, 14, { pin = true, words = { "SLAM DUNK!" }, splash = { radius = 12, damage = 10, center = vp } })
	U.glide(ctx, caster, cf, 0.25, "Out")
	at(T.End)
end

return M
