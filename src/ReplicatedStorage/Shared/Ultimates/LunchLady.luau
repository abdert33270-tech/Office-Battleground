--[[
	Ultime de la LUNCH LADY — « CHEF'S SPECIAL » (G pendant l'Overtime « Kitchen Nightmare »).
	Chorégraphie (touché) :
		0) charge bouclier-plateau (ruée)
		1) uppercut au plateau : la victime atterrit sur une plaque de cuisson géante qui flotte, brûlante
		2) 3 retournements de crêpe à la spatule géante (CLANG + grésillement, la victime tourne en l'air)
		3) dernier lancer très haut : elle bondit, l'attrape et la plonge tête la première dans une marmite géante, couvercle claqué
		4) la marmite bout, tremble... et EXPLOSE en geyser de soupe -> victime PLAQUÉE au sol, cratère, « ORDER UP! »
	Raté : elle sonne la cloche de service et écrase sa spatule sur une plaque vide, « NO SHOW?! ».
	Dégâts : 6 + 3x4 + 16 = 34 (+ 10 de zone).
]]
local RunService = game:GetService("RunService")

local PINK, ORANGE, CREAM, STEEL, DARK = Color3.fromRGB(255, 110, 140), Color3.fromRGB(255, 150, 40), Color3.fromRGB(255, 240, 220), Color3.fromRGB(200, 205, 215), Color3.fromRGB(45, 45, 52)
local SOUP, HOT, BROWN, GREEN = Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 90, 30), Color3.fromRGB(120, 70, 40), Color3.fromRGB(120, 200, 80)
local SFX = { Sizzle = 9114542867, Pan = 9125781406, Pan2 = 9125782023, Lid = 9113911811, Splash = 9119481909, Pop = 109359226723492, Boom = 2103404398, Blast = 9114362625, Gong = 9114630316 }

local T = { upper = 0.18, flips = { 0.8, 1.2, 1.6 }, flipDur = 0.36, toss = 1.95, dunk = 2.3, lid = 2.55, boom = 3.05, done = 3.45 }

local ULT = {
	Name = "Chef's Special",
	Desc = "Flip them like a pancake on a giant griddle, dunk them in the soup pot and let it blow.",
	Color = PINK,
	Color2 = ORANGE,
	Range = 25,
	Angle = 70,
	Startup = 1.0,
}

------------------------------------------------------------------------
-- SERVEUR
------------------------------------------------------------------------
function ULT.Server(U, caster, target, ctx)
	U.fx(ctx, "Rush")
	if not U.rush(ctx, target, { speed = 105, contact = 5, maxTime = 0.42 }) then
		U.fx(ctx, "Whiff", { cf = U.currentCF(ctx, caster) })
		U.wait(ctx, 0.9)
		return
	end
	local cf = U.currentCF(ctx, caster)
	local look = U.flat(cf.LookVector)
	cf = CFrame.lookAt(cf.Position, cf.Position + look)
	local vp = U.wallSafe(cf.Position, (cf * CFrame.new(0, 0, -5)).Position, 1.5)
	local dist = math.max(3.5, (vp - cf.Position).Magnitude)
	local G = U.ground(vp)
	local hr = U.headroom(vp, 14)
	local gh = math.clamp(hr - 5, 2.5, 7) -- hauteur du dessus de la plaque au-dessus du sol
	local potPos = U.ground(U.wallSafe(cf.Position, (cf * CFrame.new(0, 0, -(dist + 3.5))).Position, 4.5))
	local rot = U.facing(vp, cf.Position) - U.facing(vp, cf.Position).Position
	local function lie(y, pitch)
		return CFrame.new(vp.X, G.Y + y, vp.Z) * rot * CFrame.Angles(math.pi / 2 + (pitch or 0), 0, 0)
	end
	local function held()
		return ctx.held[target] ~= nil
	end
	U.hold(ctx, target, U.facing(vp, cf.Position))
	local c0 = os.clock()
	local function at(t)
		return U.wait(ctx, math.max(0, t - (os.clock() - c0)))
	end
	U.fx(ctx, "Connect", { cf = cf, vp = vp, gy = G.Y, gh = gh, dist = dist, pot = potPos })

	-- 1) uppercut : envoie la victime sur la plaque
	if not at(T.upper) then
		return
	end
	U.hit(ctx, target, 6, { words = { "UPPERCUT!" }, power = 0.8 })
	if held() then
		U.glide(ctx, target, lie(gh + 1), 0.42, "Out")
	end

	-- 2) trois crêpes
	local function flip(height, dur, turns)
		task.spawn(function()
			local s = os.clock()
			while U.alive(ctx) and held() and os.clock() - s < dur do
				local a = (os.clock() - s) / dur
				U.place(ctx, target, lie(gh + 1 + height * math.sin(math.pi * a), -a * math.pi * 2 * turns))
				RunService.Heartbeat:Wait()
			end
			if U.alive(ctx) and held() then
				U.place(ctx, target, lie(gh + 1))
			end
		end)
	end
	local fw = { { "FLIP!" }, { "FLOP!" }, { "SIZZLE!" } }
	for i, t in ipairs(T.flips) do
		if not at(t) then
			return
		end
		U.hit(ctx, target, 4, { words = fw[i], power = 0.6 })
		flip(4 + i, T.flipDur, 1)
	end

	-- 3) dernier lancer, elle bondit et plonge la victime dans la marmite
	if not at(T.toss) then
		return
	end
	local top = math.clamp(hr - 1, gh + 3, gh + 8)
	if held() then
		U.glide(ctx, target, lie(top, -math.pi), 0.32, "Out")
	end
	local jump = math.clamp(U.headroom(cf.Position, 10) - 1, 2, top - 1)
	U.glide(ctx, caster, cf * CFrame.new(0, jump, -(dist - 2)), 0.3, "Out")
	if not at(T.dunk) then
		return
	end
	if held() then
		U.glide(ctx, target, CFrame.new(potPos + Vector3.new(0, 2.4, 0)) * rot * CFrame.Angles(math.pi, 0, 0), 0.22, "In")
	end
	local land = cf * CFrame.new(0, 0, -math.max(1, dist - 2.2))
	U.glide(ctx, caster, land, 0.22, "In")

	-- 4) la marmite explose
	if not at(T.boom) then
		return
	end
	if held() then
		U.place(ctx, target, CFrame.new(potPos + Vector3.new(0, 3, 0)) * rot)
	end
	U.fx(ctx, "Boom", { p = potPos })
	U.finish(ctx, target, 16, { pin = true, words = { "ORDER UP!" }, splash = { radius = 12, damage = 10, center = potPos + Vector3.new(0, 3, 0) } })
	at(T.done)
end

------------------------------------------------------------------------
-- CLIENT
------------------------------------------------------------------------
local runs = {}

local ANIM = {}
ANIM.Cutin = { -- aiguise la spatule contre la louche, puis la pointe
	{ t = 0 },
	{ t = 0.1, RS = { p = 1.7, y = 0.9 }, LS = { p = 1.7, y = -0.9 }, RJ = { ln = 0.1 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
	{ t = 0.22, RS = { p = 1.5, y = 0.2 }, LS = { p = 1.9, y = -0.2 }, RJ = { ln = 0.1, tw = 0.2 } },
	{ t = 0.34, RS = { p = 1.7, y = 0.9 }, LS = { p = 1.7, y = -0.9 }, RJ = { ln = 0.1 } },
	{ t = 0.46, RS = { p = 1.5, y = 0.2 }, LS = { p = 1.9, y = -0.2 }, RJ = { ln = 0.1, tw = 0.2 } },
	{ t = 0.62, RS = { p = 2.9, y = 0.3 }, LS = { p = 0.5, r = -0.8 }, RJ = { ln = -0.35, tw = -0.2 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
	{ t = 0.95, RS = { p = 2.8, y = 0.3 }, LS = { p = 0.5, r = -0.8 }, RJ = { ln = -0.3, tw = -0.2 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
	{ t = 1.1 },
}
ANIM.Bash = { -- charge épaule en avant derrière le plateau
	{ t = 0 },
	{ t = 0.06, RS = { p = 1.9, y = 0.6 }, LS = { p = 1.9, y = 0.6 }, RJ = { ln = 0.55, tw = -0.3 }, RH = { p = 1.0 }, LH = { p = -0.6 } },
	{ t = 0.4, RS = { p = 1.9, y = 0.6 }, LS = { p = 1.9, y = 0.6 }, RJ = { ln = 0.5, tw = -0.3 }, RH = { p = -0.6 }, LH = { p = 0.9 } },
	{ t = 0.5 },
}
ANIM.Uppercut = { -- accroupie puis uppercut au plateau à deux mains, genou levé
	{ t = 0 },
	{ t = 0.1, RS = { p = -0.6 }, LS = { p = -0.6 }, RJ = { ln = 0.65 }, RH = { p = 1.05 }, LH = { p = 0.9 } },
	{ t = 0.2, RS = { p = 3.25, y = 0.2 }, LS = { p = 3.15, y = 0.2 }, RJ = { ln = -0.5 }, RH = { p = -0.3 }, LH = { p = 1.3 } },
	{ t = 0.45, RS = { p = 3.1, y = 0.2 }, LS = { p = 3.0, y = 0.2 }, RJ = { ln = -0.42 }, RH = { p = -0.25 }, LH = { p = 1.0 } },
	{ t = 0.6 },
}
do -- 3 coups de poignet à la spatule géante (prise à deux mains, cambrée)
	local f = { { t = 0 } }
	for i = 1, 3 do
		local t0 = 0.2 + (i - 1) * 0.4
		table.insert(f, { t = t0 - 0.12, RS = { p = 1.25, y = 0.3 }, LS = { p = 1.3, y = 0.6 }, RJ = { ln = 0.35, tw = (i % 2 == 0) and 0.3 or -0.3 }, RH = { p = 0.55 }, LH = { p = 0.55 } })
		table.insert(f, { t = t0, RS = { p = 2.75, y = 0.2 }, LS = { p = 2.6, y = 0.5 }, RJ = { ln = -0.45, tw = (i % 2 == 0) and -0.25 or 0.25 }, RH = { p = -0.35 }, LH = { p = 0.75 } })
		table.insert(f, { t = t0 + 0.12, RS = { p = 2.5, y = 0.2 }, LS = { p = 2.35, y = 0.5 }, RJ = { ln = -0.3 }, RH = { p = -0.25 }, LH = { p = 0.55 } })
	end
	table.insert(f, { t = 1.3 })
	ANIM.Flip = f
end
ANIM.Dunk = { -- bond bras au ciel, attrape, smash vers la marmite, puis baiser du chef
	{ t = 0 },
	{ t = 0.12, RS = { p = -0.7 }, LS = { p = -0.7 }, RJ = { ln = 0.6 }, RH = { p = 1.0 }, LH = { p = 1.0 } },
	{ t = 0.28, RS = { p = 3.3, r = -0.2 }, LS = { p = 3.3, r = -0.2 }, RJ = { ln = -0.45 }, RH = { p = 1.3 }, LH = { p = 0.4 } },
	{ t = 0.36, RS = { p = 3.4 }, LS = { p = 3.4 }, RJ = { ln = -0.6 }, RH = { p = 1.2 }, LH = { p = 0.5 } },
	{ t = 0.46, RS = { p = 0.55 }, LS = { p = 0.55 }, RJ = { ln = 1.05 }, RH = { p = -0.35 }, LH = { p = 0.9 } },
	{ t = 0.7, RS = { p = 0.65 }, LS = { p = 0.65 }, RJ = { ln = 0.9 }, RH = { p = -0.3 }, LH = { p = 0.8 } },
	{ t = 0.85, RS = { p = 1.0, r = -0.5 }, LS = { p = 1.0, r = -0.5 }, RJ = { ln = 0.1 }, RH = { p = -0.1 }, LH = { p = 0.2 } },
	{ t = 1.1, RS = { p = 1.0, r = -0.5 }, LS = { p = 1.0, r = -0.5 }, RJ = { ln = 0.05 } },
}
ANIM.Kiss = { -- baiser du chef : doigts à la bouche, puis main lancée vers le ciel
	{ t = 0 },
	{ t = 0.1, RS = { p = 2.5, y = 1.35 }, LS = { p = 0.4, r = -0.5 }, RJ = { ln = -0.1 } },
	{ t = 0.3, RS = { p = 2.55, y = 1.35 }, LS = { p = 0.4, r = -0.5 }, RJ = { ln = -0.1 } },
	{ t = 0.4, RS = { p = 3.0, y = 0.2, r = -0.6 }, LS = { p = 0.4, r = -0.6 }, RJ = { ln = -0.3, tw = 0.2 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
	{ t = 0.85, RS = { p = 2.95, y = 0.2, r = -0.6 }, LS = { p = 0.4, r = -0.6 }, RJ = { ln = -0.25, tw = 0.2 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
	{ t = 1.0 },
}
ANIM.Bell = { -- frappe la cloche de service, puis abat la spatule
	{ t = 0 },
	{ t = 0.08, LS = { p = 1.4, y = 0.2 }, RS = { p = 0.4 }, RJ = { ln = 0.2 } },
	{ t = 0.14, LS = { p = 1.0, y = 0.2 }, RS = { p = 0.4 }, RJ = { ln = 0.3 } },
	{ t = 0.28, RS = { p = 3.2 }, LS = { p = 0.6, r = -0.5 }, RJ = { ln = -0.4 }, RH = { p = -0.2 }, LH = { p = 0.4 } },
	{ t = 0.4, RS = { p = 0.9, y = 0.2 }, LS = { p = 0.6, r = -0.5 }, RJ = { ln = 0.85 }, RH = { p = 0.9 }, LH = { p = -0.4 } },
	{ t = 0.75, RS = { p = 0.95, y = 0.2 }, RJ = { ln = 0.7 }, RH = { p = 0.8 }, LH = { p = -0.35 } },
	{ t = 0.9 },
}
ANIM.Pancake = { -- victime en étoile (bras et jambes écartés) pendant les crêpes
	{ t = 0 },
	{ t = 0.15, RS = { p = 0.3, r = -1.5 }, LS = { p = 0.3, r = -1.5 }, RH = { r = -0.6 }, LH = { r = -0.6 } },
	{ t = 1.9, RS = { p = 0.4, r = -1.6 }, LS = { p = 0.2, r = -1.4 }, RH = { r = -0.65 }, LH = { r = -0.55 } },
	{ t = 2.1 },
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

local A = CFrame.Angles(0, 0, math.pi / 2)
-- un seul accessoire en main à la fois (st.held = liste des parts)
local function swap(st, list)
	for _, p in ipairs(st.held or {}) do
		if p and p.Parent then
			p:Destroy()
		end
	end
	st.held = list
end
local function tray(K, data, st, c)
	swap(st, {
		K.prop(data, c, "Right Arm", Vector3.new(3.2, 0.22, 2.4), CFrame.new(-0.6, -1.6, 0), ORANGE),
		K.prop(data, c, "Right Arm", Vector3.new(2.9, 0.24, 2.1), CFrame.new(-0.6, -1.55, 0), Color3.fromRGB(255, 190, 90)),
	})
end
local function spatula(K, data, st, c)
	local l = {
		K.prop(data, c, "Right Arm", Vector3.new(7, 0.4, 0.4), CFrame.new(0, -3.3, 0) * A, BROWN, K.CYL),
		K.prop(data, c, "Right Arm", Vector3.new(0.6, 0.5, 0.5), CFrame.new(0, -6.8, 0) * A, DARK, K.CYL),
		K.prop(data, c, "Right Arm", Vector3.new(3.4, 3.8, 0.25), CFrame.new(0, -8.7, -0.2), STEEL, nil, Enum.Material.Metal),
	}
	for i = -1, 1 do
		table.insert(l, K.prop(data, c, "Right Arm", Vector3.new(0.35, 2.6, 0.27), CFrame.new(i * 0.9, -8.8, -0.2), DARK))
	end
	swap(st, l)
end

-- plaque de cuisson géante qui flotte (flammes dessous), renvoie le centre du dessus
local function griddle(K, data, st, center, life)
	local slab = K.track(data, K.part({ Size = Vector3.new(10, 0.9, 10), CFrame = CFrame.new(center - Vector3.new(0, 0.45, 0)), Color = DARK }, life))
	local plate = K.track(data, K.part({ Size = Vector3.new(9.2, 0.12, 9.2), CFrame = CFrame.new(center + Vector3.new(0, 0.03, 0)), Color = HOT, Material = Enum.Material.Neon, Transparency = 0.55 }, life))
	local rim = K.track(data, K.part({ Size = Vector3.new(10.4, 0.5, 10.4), CFrame = CFrame.new(center - Vector3.new(0, 0.85, 0)), Color = STEEL, Material = Enum.Material.Metal }, life))
	local flames = {}
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2
		flames[i] = K.track(data, K.part({ Size = Vector3.new(1.4, 2.2, 1.4), Color = (i % 2 == 0) and ORANGE or Color3.fromRGB(255, 220, 80), Material = Enum.Material.Neon, Transparency = 0.2 }, life))
		flames[i].CFrame = CFrame.new(center + Vector3.new(math.cos(a) * 3, -2.3, math.sin(a) * 3))
	end
	for _, p in ipairs({ slab, plate, rim }) do
		local s = p.Size
		p.Size = s * Vector3.new(0.05, 1, 0.05)
		K.tween(p, 0.22, { Size = s }, Enum.EasingStyle.Back)
	end
	local light = Instance.new("PointLight")
	light.Color = ORANGE
	light.Range = 18
	light.Brightness = 3
	light.Parent = plate
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - t0
		if not st.alive or not slab.Parent then
			conn:Disconnect()
			return
		end
		plate.Transparency = 0.45 + math.sin(el * 18) * 0.1
		for i, f in ipairs(flames) do
			local a = (i / 6) * math.pi * 2 + el * 2
			local s = 1 + math.sin(el * 25 + i) * 0.3
			f.Size = Vector3.new(1.3, 2.2 * s, 1.3)
			f.CFrame = CFrame.new(center + Vector3.new(math.cos(a) * 3, -1.4 - 1.1 * s, math.sin(a) * 3)) * CFrame.Angles(0, el * 4 + i, 0)
		end
		if K.rng:NextNumber() < 0.25 then -- vapeur
			local p0 = center + Vector3.new(K.rng:NextNumber(-4, 4), 0.3, K.rng:NextNumber(-4, 4))
			local s = K.part({ Shape = K.BALL, Size = Vector3.one * 1.2, Position = p0, Color = Color3.fromRGB(245, 245, 245), Transparency = 0.45 }, 1)
			K.tween(s, 0.9, { Position = p0 + Vector3.new(0, 4, 0), Size = Vector3.one * 3, Transparency = 1 })
		end
	end)
	table.insert(st.conns, conn)
	return function()
		for _, p in ipairs({ slab, plate, rim }) do
			if p.Parent then
				K.tween(p, 0.25, { Size = p.Size * Vector3.new(0.05, 1, 0.05), Transparency = 1 })
			end
		end
		for _, f in ipairs(flames) do
			if f.Parent then
				K.tween(f, 0.2, { Transparency = 1 })
			end
		end
	end
end

-- marmite géante (corps, bord, soupe, flammes) ; renvoie la table de ses parts
local function pot(K, data, st, g, life)
	local m = {}
	m.body = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(5.6, 8.4, 8.4), CFrame = CFrame.new(g + Vector3.new(0, 2.9, 0)) * K.UPRIGHT, Color = STEEL, Material = Enum.Material.Metal }, life))
	m.band = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(0.8, 8.6, 8.6), CFrame = CFrame.new(g + Vector3.new(0, 4.2, 0)) * K.UPRIGHT, Color = PINK }, life))
	m.rim = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(0.5, 9.0, 9.0), CFrame = CFrame.new(g + Vector3.new(0, 5.7, 0)) * K.UPRIGHT, Color = Color3.fromRGB(170, 175, 185), Material = Enum.Material.Metal }, life))
	m.soup = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(0.2, 7.6, 7.6), CFrame = CFrame.new(g + Vector3.new(0, 5.6, 0)) * K.UPRIGHT, Color = SOUP, Material = Enum.Material.Neon, Transparency = 0.15 }, life))
	m.hl = K.track(data, K.part({ Size = Vector3.new(0.6, 0.6, 2.2), CFrame = CFrame.new(g + Vector3.new(4.6, 4.8, 0)), Color = DARK }, life))
	m.hr = K.track(data, K.part({ Size = Vector3.new(0.6, 0.6, 2.2), CFrame = CFrame.new(g + Vector3.new(-4.6, 4.8, 0)), Color = DARK }, life))
	for _, p in pairs(m) do
		local cf = p.CFrame
		p.CFrame = cf + Vector3.new(0, 14, 0)
		K.tween(p, 0.2, { CFrame = cf }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	return m
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
			if st.sizzle then
				st.sizzle:Destroy()
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
		spatula(K, data, st, c)
		for i = 0, 1 do
			at(0.22 + i * 0.24, function()
				local r = rootOf(c)
				if r then
					K.sparks(r.Position + r.CFrame.LookVector * 2 + Vector3.new(0, 1.2, 0), 14, ORANGE)
					K.sound(SFX.Pan2, r.Position, 0.8, 1.2 + i * 0.15)
				end
			end)
		end
		at(0.62, function()
			local r = rootOf(c)
			if r then
				K.CFX.swirl(r.Position - Vector3.new(0, 2.5, 0), 3, 7, { PINK, ORANGE, CREAM }, 14, 0.5)
				K.sound("Charge", r.Position, 0.6)
				K.light(r.Position, ORANGE, 16, 3, 0.4)
			end
		end)

	elseif data.phase == "Rush" then
		K.anim(c, ANIM.Bash)
		tray(K, data, st, c)
		K.sound("Dash", cr.Position, 1)
		K.sound("Whoosh2", cr.Position, 0.8)
		K.dust(cr.Position - Vector3.new(0, 2.8, 0), 5, nil, 8)
		task.spawn(function()
			for _ = 1, 7 do
				if not st.alive or not rootOf(c) then
					break
				end
				K.afterimage(c, PINK, 0.3, 0.45)
				task.wait(0.055)
			end
		end)
		if K.isCaster(data) then
			K.speedLines(0.4, PINK)
		end

	elseif data.phase == "Whiff" then
		local cf = data.cf or cr.CFrame
		K.anim(c, ANIM.Bell)
		spatula(K, data, st, c)
		-- cloche de service dans la main gauche
		K.prop(data, c, "Left Arm", Vector3.new(0.9, 0.7, 0.9), CFrame.new(0, -1.4, 0), Color3.fromRGB(240, 200, 60), K.BALL, Enum.Material.Metal)
		at(0.12, function()
			K.sound("Ding", cr.Position, 1.2)
			K.word(cr.Position + Vector3.new(0, 4, 0), "DING!", 0.6, "Light")
		end)
		local center = K.groundPos(cf.Position + cf.LookVector * 6) + Vector3.new(0, 1.2, 0)
		local kill
		at(0.15, function()
			kill = griddle(K, data, st, center, 2)
		end)
		at(0.4, function()
			K.sound(SFX.Pan, center, 1.2)
			K.sparks(center + Vector3.new(0, 0.5, 0), 22, ORANGE)
			K.shards(center + Vector3.new(0, 0.5, 0), 10, { SOUP, ORANGE, CREAM }, 0.8)
			K.shockwave(center + Vector3.new(0, -1, 0), 8, PINK)
			K.word(center + Vector3.new(0, 4, 0), "NO SHOW?!", 0.85, "Light")
			K.shake(0.5)
		end)
		at(0.85, function()
			if kill then
				kill()
			end
		end)

	elseif data.phase == "Connect" then
		local cf, vp, gy, gh, dist, potPos = data.cf, data.vp, data.gy, data.gh or 4, data.dist or 5, data.pot
		local look = cf.LookVector
		local gcenter = Vector3.new(vp.X, gy + gh, vp.Z)
		K.letterbox(data, true)
		K.anim(c, ANIM.Uppercut)
		tray(K, data, st, c)
		K.sound("Whoosh", cr.Position, 1)
		-- caméra 1 : contre-plongée à côté d'elle, regarde la victime monter
		K.shot(data, "track", { from = camSafe(cf.Position, (cf * CFrame.new(5, 0.5, 3)).Position), at = function()
			local r = rootOf(v)
			return r and r.Position or vp
		end, fov = 66 })
		at(T.upper, function()
			local r = rootOf(v)
			local p = r and r.Position or vp
			K.impactFrames("WB")
			K.airRing(p, Vector3.new(0, 1, 0), 10, PINK, 0.3)
			K.airRing(p + Vector3.new(0, 1.5, 0), Vector3.new(0, 1, 0), 7, CREAM, 0.3)
			K.sparks(p, 16, ORANGE)
			K.layer({ { "Uppercut", 1.1 }, { "PunchHeavy", 1 }, { SFX.Pan2, 0.7, 1.3 } }, p)
			K.shake(0.9)
			K.pillar(p, 1.6, 10, PINK, 0.3)
			if v then
				K.anim(v, ANIM.Pancake)
			end
		end)
		local killG
		at(0.26, function()
			killG = griddle(K, data, st, gcenter, 3.2)
			st.sizzle = K.sound(SFX.Sizzle, gcenter, 1.1)
			K.sound(SFX.Gong, gcenter, 0.35, 1.4)
		end)
		-- 2) crêpes à la spatule géante
		at(0.6, function()
			K.anim(c, ANIM.Flip)
			spatula(K, data, st, c)
			-- caméra 2 : orbite autour de la plaque
			K.shot(data, "dolly", { from = CFrame.lookAt(camSafe(gcenter, gcenter + cf.RightVector * 14 - look * 3), gcenter + Vector3.new(0, 1.5, 0)), to = CFrame.lookAt(camSafe(gcenter, gcenter + cf.RightVector * 10 + look * 6 + Vector3.new(0, 1, 0)), gcenter + Vector3.new(0, 1.5, 0)), dur = 1.3, fov0 = 62, fov1 = 56 })
		end)
		local fwords = { "FLIP!", "FLOP!", "SIZZLE!" }
		for i, t in ipairs(T.flips) do
			at(t, function()
				local p = gcenter + Vector3.new(0, 1, 0)
				K.sound(i == 2 and SFX.Pan2 or SFX.Pan, p, 1.2, 0.95 + i * 0.07)
				K.sound("Whoosh3", p, 0.6)
				K.sparks(p, 18, ORANGE)
				K.shards(p, 8, { SOUP, ORANGE, Color3.fromRGB(255, 220, 90) }, 0.9)
				K.shockwave(p, 6 + i, HOT)
				K.word(p + Vector3.new(K.rng:NextNumber(-2, 2), 4, 0), fwords[i], 0.6 + i * 0.12, "Light")
				K.shake(0.5 + i * 0.1)
				K.light(p, ORANGE, 20, 4, 0.25)
				for _ = 1, 3 do -- vapeur qui jaillit
					local s = K.part({ Shape = K.BALL, Size = Vector3.one * 1.4, Position = p, Color = CREAM, Transparency = 0.5 }, 0.9)
					K.tween(s, 0.8, { Position = p + Vector3.new(K.rng:NextNumber(-3, 3), K.rng:NextNumber(3, 6), K.rng:NextNumber(-3, 3)), Size = Vector3.one * 3, Transparency = 1 })
				end
				if i == 3 then
					K.impactFrames("B")
				end
			end)
		end
		-- 3) lancer + bond + marmite
		local potParts
		at(T.toss, function()
			K.anim(c, ANIM.Dunk)
			K.sound("Whoosh2", cr.Position, 1.1)
			K.word(gcenter + Vector3.new(0, 6, 0), "HUP!", 0.7, "Light")
			if killG then
				killG()
			end
			if st.sizzle then
				K.tween(st.sizzle, 0.5, { Volume = 0.3 })
			end
			potParts = pot(K, data, st, potPos, 3)
			task.delay(0.2, function()
				K.sound(SFX.Lid, potPos, 1.1, 0.8)
				K.shockwave(potPos + Vector3.new(0, 0.2, 0), 9, STEEL)
				K.dust(potPos, 7, nil, 10)
				K.shake(0.6)
			end)
			-- caméra 3 : plan large qui monte
			local side = cf.RightVector
			local mid = cf.Position:Lerp(potPos, 0.5)
			K.shot(data, "dolly", { from = CFrame.lookAt(camSafe(mid, mid + side * 18 + Vector3.new(0, 2, 0)), mid + Vector3.new(0, 4, 0)), to = CFrame.lookAt(camSafe(mid, mid + side * 20 + Vector3.new(0, 9, 0)), mid + Vector3.new(0, 4, 0)), dur = 0.6, fov0 = 68, fov1 = 62 })
			for _ = 1, 4 do
				K.afterimage(c, PINK, 0.35, 0.5)
			end
		end)
		at(T.dunk + 0.2, function()
			local p = potPos + Vector3.new(0, 5.8, 0)
			K.impactFrames("BW")
			K.shake(1.1)
			K.layer({ { SFX.Splash, 1.3 }, { "Splat", 1.1 }, { "PunchHeavy", 0.9 } }, p)
			K.shards(p, 16, { SOUP, ORANGE, GREEN, BROWN }, 1.2)
			K.word(p + Vector3.new(0, 4, 0), "SPLOOSH!", 1, "Heavy")
			local sp = K.part({ Shape = K.BALL, Size = Vector3.one * 3, Position = p, Color = SOUP, Transparency = 0.2 }, 0.6)
			K.tween(sp, 0.35, { Size = Vector3.new(14, 6, 14), Transparency = 1 })
			-- couvercle qui tombe du ciel
			local lid = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(0.6, 9.2, 9.2), CFrame = CFrame.new(potPos + Vector3.new(0, 18, 0)) * K.UPRIGHT, Color = Color3.fromRGB(170, 175, 185), Material = Enum.Material.Metal }, 3))
			local knob = K.track(data, K.part({ Shape = K.BALL, Size = Vector3.one * 1.4, CFrame = CFrame.new(potPos + Vector3.new(0, 18.8, 0)), Color = PINK }, 3))
			K.tween(lid, T.lid - T.dunk - 0.2, { CFrame = CFrame.new(potPos + Vector3.new(0, 6.1, 0)) * K.UPRIGHT }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			K.tween(knob, T.lid - T.dunk - 0.2, { CFrame = CFrame.new(potPos + Vector3.new(0, 6.9, 0)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			st.lid, st.knob = lid, knob
		end)
		at(T.lid, function()
			local p = potPos + Vector3.new(0, 6, 0)
			K.sound(SFX.Lid, p, 1.3)
			K.sound(SFX.Pan, p, 1, 0.8)
			K.sparks(p, 16, CREAM)
			K.shake(0.8)
			K.word(p + Vector3.new(0, 3, 0), "CLANG!", 0.8, "Heavy")
			-- caméra 4 : gros plan sur la marmite qui se resserre
			local side = cf.RightVector
			local pc = potPos + Vector3.new(0, 4, 0)
			local cfrom = CFrame.lookAt(camSafe(pc, potPos + side * 12 - look * 3 + Vector3.new(0, 5, 0)), pc)
			local cto = CFrame.lookAt(camSafe(pc, potPos + side * 8.5 - look * 1.5 + Vector3.new(0, 4.5, 0)), pc)
			K.shot(data, "dolly", { from = cfrom, to = cto, dur = 0.5, fov0 = 60, fov1 = 50 })
			K.anim(c, ANIM.Kiss)
			-- ébullition : la marmite tremble, le couvercle saute, vapeur
			local t0 = os.clock()
			local base = {}
			if potParts then
				for k, prt in pairs(potParts) do
					base[k] = prt.CFrame
				end
			end
			local lid0, knob0 = st.lid and st.lid.CFrame, st.knob and st.knob.CFrame
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local el = os.clock() - t0
				if not st.alive or el > T.boom - T.lid then
					conn:Disconnect()
					return
				end
				local amp = 0.08 + el * 0.5
				local off = Vector3.new(K.rng:NextNumber(-amp, amp), 0, K.rng:NextNumber(-amp, amp))
				if potParts then
					for k, prt in pairs(potParts) do
						if prt.Parent then
							prt.CFrame = base[k] + off
						end
					end
					potParts.soup.Color = SOUP:Lerp(Color3.fromRGB(255, 60, 20), math.min(1, el * 2))
				end
				local hop = math.abs(math.sin(el * 30)) * (0.2 + el * 1.4)
				if st.lid and st.lid.Parent and lid0 then
					st.lid.CFrame = lid0 + off + Vector3.new(0, hop, 0)
					st.knob.CFrame = knob0 + off + Vector3.new(0, hop, 0)
				end
				if K.rng:NextNumber() < 0.4 then
					local p0 = potPos + Vector3.new(K.rng:NextNumber(-4, 4), 6.3, K.rng:NextNumber(-4, 4))
					local s = K.part({ Shape = K.BALL, Size = Vector3.one * 1.3, Position = p0, Color = CREAM, Transparency = 0.35 }, 0.8)
					K.tween(s, 0.7, { Position = p0 + Vector3.new(0, 5, 0), Size = Vector3.one * 3.5, Transparency = 1 })
				end
			end)
			table.insert(st.conns, conn)
			for i = 0, 2 do
				task.delay(0.08 + i * 0.13, function()
					if st.alive then
						K.sound(SFX.Pop, potPos, 1, 0.8 + i * 0.2)
						K.word(potPos + Vector3.new(K.rng:NextNumber(-3, 3), 9 + i, 0), "BLUB!", 0.5 + i * 0.15, "Light")
					end
				end)
			end
			K.sound("Rumble", potPos, 1)
			K.sound("FinalCharge", potPos, 0.7)
		end)
		st.potParts = function()
			return potParts
		end

	elseif data.phase == "Boom" then
		local p = data.p or cr.Position
		local look = cr.CFrame.LookVector
		if st.sizzle then
			st.sizzle:Destroy()
			st.sizzle = nil
		end
		K.impactFrames("WBWBR", 0.045)
		K.slowmo({ c, v }, 0.14)
		K.shake(2.1)
		K.fov(15)
		K.flash(ORANGE, 0.4, 0.6)
		K.layer({ { "Explosion", 1.3 }, { SFX.Blast, 1.2 }, { SFX.Boom, 1.3, 0.85 }, { "Bass", 1.3, 1, 0.04 }, { SFX.Pan, 1, 0.7, 0.06 }, { SFX.Splash, 1.1, 0.8, 0.1 } }, p)
		-- caméra 5 : plan large en contre-plongée
		K.shot(data, "fixed", { pos = camSafe(p + Vector3.new(0, 3, 0), p - look * 20 + cr.CFrame.RightVector * 8 + Vector3.new(0, 3, 0)), lookAt = p + Vector3.new(0, 6, 0), fov = 74 })
		-- éclats de marmite projetés
		local parts = st.potParts and st.potParts()
		if parts then
			for _, prt in pairs(parts) do
				if prt.Parent then
					prt:Destroy()
				end
			end
		end
		for i = 1, 8 do
			local a = (i / 8) * math.pi * 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local sh = K.part({ Size = Vector3.new(3.2, 3.8, 0.5), CFrame = CFrame.lookAt(p + dir * 3.8 + Vector3.new(0, 3, 0), p + Vector3.new(0, 3, 0)), Color = (i % 4 == 0) and PINK or STEEL, Material = Enum.Material.Metal }, 1.2)
			K.tween(sh, 0.9, { CFrame = sh.CFrame + dir * 16 + Vector3.new(0, K.rng:NextNumber(2, 8), 0), Transparency = 1 }, Enum.EasingStyle.Quad)
		end
		if st.lid and st.lid.Parent then -- le couvercle part en toupie vers le ciel
			K.tween(st.lid, 1.0, { CFrame = st.lid.CFrame * CFrame.new(30, 0, 0) * CFrame.Angles(4, 2, 0), Transparency = 1 }, Enum.EasingStyle.Quad)
			K.tween(st.knob, 1.0, { CFrame = st.knob.CFrame + Vector3.new(0, 30, 0), Transparency = 1 })
		end
		-- geyser de soupe
		local gey = K.part({ Shape = K.CYL, Size = Vector3.new(2, 7, 7), CFrame = CFrame.new(p + Vector3.new(0, 1, 0)) * K.UPRIGHT, Color = SOUP, Material = Enum.Material.Neon, Transparency = 0.1 }, 1)
		K.tween(gey, 0.35, { Size = Vector3.new(34, 5, 5), CFrame = CFrame.new(p + Vector3.new(0, 17, 0)) * K.UPRIGHT }, Enum.EasingStyle.Quad)
		task.delay(0.35, function()
			K.tween(gey, 0.45, { Size = Vector3.new(34, 0.5, 0.5), Transparency = 1 })
		end)
		K.sphere(p + Vector3.new(0, 3, 0), 20, ORANGE, 0.45, 5)
		K.sphere(p + Vector3.new(0, 3, 0), 12, CREAM, 0.3, 3)
		K.crater(p, 10, HOT, 3.5)
		for i = 0, 2 do
			task.delay(i * 0.08, function()
				K.shockwave(p + Vector3.new(0, 0.25 + i * 0.05, 0), 13 + i * 6, i == 1 and ORANGE or PINK)
			end)
		end
		K.debris(p + Vector3.new(0, 2, 0), 5, { GREEN, ORANGE, BROWN, CREAM }, 1.3, 0.9)
		K.shards(p + Vector3.new(0, 4, 0), 10, { SOUP, ORANGE, GREEN }, 1.5)
		K.light(p + Vector3.new(0, 4, 0), ORANGE, 45, 9, 0.7)
		K.word(p + Vector3.new(0, 9, 0), "ORDER UP!", 1.6, "Heavy")
		-- pluie de soupe
		for _ = 1, 8 do
			local d0 = p + Vector3.new(K.rng:NextNumber(-9, 9), K.rng:NextNumber(12, 18), K.rng:NextNumber(-9, 9))
			local d = K.part({ Shape = K.BALL, Size = Vector3.one * K.rng:NextNumber(0.5, 1), Position = d0, Color = (K.rng:NextNumber() < 0.7) and SOUP or GREEN }, 1.3)
			K.tween(d, K.rng:NextNumber(0.7, 1.1), { Position = Vector3.new(d0.X, p.Y + 0.3, d0.Z) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end
	end
end

return ULT
