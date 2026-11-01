--[[
	Ultime du CEO : « HOSTILE LIQUIDATION »
	Il lance un CONTRAT doré qui ramène la victime devant lui et la scelle (anneaux d'or en orbite, soulevée),
	ouvre sa mallette : un torrent de lingots et de billets la mitraille, puis il lance la mallette en l'air :
	elle devient GÉANTE et se referme sur la victime comme une mâchoire (CHOMP). Il claque des doigts :
	la mallette explose en pluie d'or et la victime est ÉJECTÉE très loin.
	Raté : le contrat part dans le vide et brûle, « DEAL DECLINED ».
]]
local GOLD = Color3.fromRGB(255, 200, 40)
local LGOLD = Color3.fromRGB(255, 240, 160)
local BLACK = Color3.fromRGB(30, 30, 36)
local CASH = Color3.fromRGB(110, 200, 100)
local DCASH = Color3.fromRGB(60, 150, 70)
local RED = Color3.fromRGB(230, 40, 40)
local PAPER = Color3.fromRGB(255, 248, 225)
local WHITE = Color3.new(1, 1, 1)

-- sons Creator Store vérifiés (ils se chargent)
local S = {
	Register = "rbxassetid://101396758527961",
	Coins = "rbxassetid://9113849583",
	Metal = "rbxassetid://9116654063",
	Paper = "rbxassetid://9125724621",
	Bell = "rbxassetid://128317117113671",
}

-- minutage partagé serveur / client (secondes depuis la phase "Connect")
local T = { seal = 0.18, bar0 = 0.5, bars = 8, barStep = 0.11, toss = 1.5, chomp = 2.12, snap = 2.7, total = 3.35 }
local DIST = 6
local RISE = 2.2

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local A = {}
A.Cast = { -- ajuste sa cravate, puis index tendu « vous »
	{ t = 0 },
	{ t = 0.15, RS = { p = 2.3, y = 0.9, r = 0.6 }, LS = { p = 2.3, y = -0.9, r = 0.6 }, RJ = { ln = -0.15 } },
	{ t = 0.35, RS = { p = 2.4, y = 0.8, r = 0.65 }, LS = { p = 2.2, y = -0.8, r = 0.55 }, RJ = { ln = -0.2 } },
	{ t = 0.55, RS = { p = 1.65, y = 0 }, LS = { p = 0.3, r = -0.2 }, RJ = { tw = 0.3, ln = -0.1 } },
	{ t = 1.1, RS = { p = 1.6, y = 0 }, LS = { p = 0.3, r = -0.2 }, RJ = { tw = 0.32, ln = -0.12 } },
	{ t = 1.2 },
}
A.Contract = { -- lance le contrat comme une carte
	{ t = 0 },
	{ t = 0.08, RS = { p = 1.4, y = -1.4, r = -0.5 }, RJ = { tw = -0.6 } },
	{ t = 0.16, RS = { p = 1.6, y = 0.9, r = -0.1 }, RJ = { tw = 0.55, ln = 0.15 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
	{ t = 0.4, RS = { p = 1.5, y = 0.9 }, RJ = { tw = 0.45, ln = 0.1 } },
}
A.Barrage = { -- mallette ouverte tenue à deux mains, recul à chaque rafale
	{ t = 0 },
	{ t = 0.1, RS = { p = 1.5, y = 0.35 }, LS = { p = 1.5, y = -0.35 }, RJ = { ln = -0.15 }, RH = { p = -0.3 }, LH = { p = 0.45 } },
}
for i = 1, 8 do
	table.insert(A.Barrage, { t = 0.1 + i * 0.11, RS = { p = (i % 2 == 0) and 1.55 or 1.75, y = 0.35 }, LS = { p = (i % 2 == 0) and 1.55 or 1.75, y = -0.35 }, RJ = { ln = (i % 2 == 0) and -0.15 or -0.3, sd = (i % 2 == 0) and 0.05 or -0.05 }, RH = { p = -0.35 }, LH = { p = 0.5 } })
end
A.Toss = { -- lance la mallette au ciel
	{ t = 0, RS = { p = 1.5, y = 0.35 }, LS = { p = 1.5, y = -0.35 } },
	{ t = 0.1, RS = { p = 0.4, r = -0.3 }, LS = { p = 0.4, r = -0.3 }, RJ = { ln = 0.4 }, RH = { p = 0.6 }, LH = { p = 0.6 } },
	{ t = 0.2, RS = { p = 3.2, r = -0.2 }, LS = { p = 3.2, r = -0.2 }, RJ = { ln = -0.4 }, RH = { p = -0.1 }, LH = { p = 0.1 } },
	{ t = 0.5, RS = { p = 3.1, r = -0.3 }, LS = { p = 3.1, r = -0.3 }, RJ = { ln = -0.35 } },
	{ t = 0.62, RS = { p = 0.3, r = -0.4 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = 0 } },
}
A.Snap = { -- bras levé, claquement de doigts, puis pose « next »
	{ t = 0, RS = { p = 0.3, r = -0.4 }, LS = { p = 0.3, r = -0.4 } },
	{ t = 0.12, RS = { p = 2.4, y = 0.4, r = 0.3 }, LS = { p = 0.9, y = 0.8, r = 0.5 }, RJ = { ln = -0.1, tw = 0.2 } },
	{ t = 0.22, RS = { p = 2.55, y = 0.3, r = 0.25 }, LS = { p = 0.9, y = 0.8, r = 0.5 }, RJ = { ln = -0.12, tw = 0.25 } },
	{ t = 0.3, RS = { p = 2.3, y = 0.6, r = 0.3 }, LS = { p = 0.9, y = 0.8, r = 0.5 }, RJ = { ln = -0.08, tw = 0.3 } },
	{ t = 0.75, RS = { p = 2.25, y = 0.6, r = 0.3 }, LS = { p = 0.9, y = 0.8, r = 0.5 }, RJ = { ln = -0.05, tw = 0.45 } },
	{ t = 0.95 },
}
A.Decline = { -- raté : bras croisés, dédain
	{ t = 0 },
	{ t = 0.12, RS = { p = 1.6, y = 0.8 }, RJ = { tw = 0.5 } },
	{ t = 0.4, RS = { p = 1.5, y = -1.1, r = 0.2 }, LS = { p = 1.5, y = -1.1, r = 0.2 }, RJ = { ln = -0.15 } },
	{ t = 0.8, RS = { p = 1.5, y = -1.1, r = 0.2 }, LS = { p = 1.5, y = -1.1, r = 0.2 }, RJ = { ln = -0.18 } },
	{ t = 0.95 },
}

------------------------------------------------------------------------
-- Aides
------------------------------------------------------------------------
local PIXEL = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Bold)
local RunService = game:GetService("RunService")

local function flatCF(from, dir)
	local d = Vector3.new(dir.X, 0, dir.Z)
	if d.Magnitude < 0.05 then
		d = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(from, from + d.Unit)
end

local function label(part, text, color, face, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.FontFace = font or PIXEL
	l.TextScaled = true
	l.TextColor3 = color or WHITE
	l.Parent = gui
	return l
end

-- pluie de pièces et de billets
local function coinBurst(K, pos, n, speed, life)
	for _ = 1, n do
		local isBill = K.rng:NextNumber() < 0.35
		local c = K.part(isBill and { Size = Vector3.new(1.3, 0.06, 0.65), CFrame = CFrame.new(pos), Color = (K.rng:NextNumber() < 0.5) and CASH or DCASH }
			or { Shape = K.CYL, Size = Vector3.new(0.2, 0.9, 0.9), CFrame = CFrame.new(pos), Color = GOLD, Material = Enum.Material.Neon }, (life or 0.9) + 0.05)
		local dir = Vector3.new(K.rng:NextNumber(-1, 1), K.rng:NextNumber(-0.2, 1.1), K.rng:NextNumber(-1, 1)).Unit
		local goal = pos + dir * (speed or 12) * K.rng:NextNumber(0.5, 1.2) - Vector3.new(0, 2, 0)
		K.tween(c, life or 0.9, { CFrame = CFrame.new(goal) * CFrame.Angles(K.rng:NextNumber(0, 8), K.rng:NextNumber(0, 8), 0), Transparency = 0.7 }, Enum.EasingStyle.Quad)
	end
end

------------------------------------------------------------------------
-- Séquence
------------------------------------------------------------------------
local function connect(K, d)
	local c, v = d.caster, d.target
	local cr, vr = K.root(c), K.root(v)
	if not cr or not vr then
		return
	end
	local basis = flatCF(cr.Position, d.dir or cr.CFrame.LookVector)
	local right, fwd = basis.RightVector, basis.LookVector
	local function vpos()
		local r = K.root(v)
		return r and r.Position or vr.Position
	end
	local function cpos()
		local r = K.root(c)
		return r and r.Position or cr.Position
	end
	K.letterbox(d, true, 0.15)

	-- contrat lancé : il ramène la victime et la scelle
	K.anim(c, A.Contract)
	K.sound("Throw", cpos(), 1)
	K.shot(d, "orbit", { at = function() return cpos():Lerp(vpos(), 0.5) end, basis = basis, angle = 110, r0 = 12, r1 = 9, dur = 0.5, height = 2.5, speed = 15, fov = 62 })
	local slip = K.part({ Size = Vector3.new(1.2, 0.08, 1.6), CFrame = CFrame.new(cpos() + fwd * 1.5 + Vector3.new(0, 1, 0)), Color = PAPER, Material = Enum.Material.Neon }, 0.5)
	K.tween(slip, T.seal, { CFrame = CFrame.new(cpos() + fwd * DIST + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 6, 0) }, Enum.EasingStyle.Linear)
	K.at(d, T.seal, function()
		local p = vpos()
		K.layer({ { S.Paper, 0.9, 1.2 }, { "Ding", 1, 0.8 }, { "Charge", 0.6, 1.3 } }, p)
		K.word(p + Vector3.new(0, 3, 0), "ACQUIRED!", 1.3, "Heavy")
		K.sphere(p, 9, GOLD, 0.25, 1)
		K.sparks(p, 20, GOLD)
		-- sceau doré sur la poitrine
		local seal = K.prop(d, v, "Torso", Vector3.new(0.1, 1.4, 1.4), CFrame.new(0, 0, -0.58) * CFrame.Angles(0, math.pi / 2, 0), GOLD, K.CYL, Enum.Material.Neon)
		if seal then
			label(seal, "$", BLACK, Enum.NormalId.Right)
			label(seal, "$", BLACK, Enum.NormalId.Left)
		end
		-- 3 anneaux d'or en orbite
		local rings = {}
		for i = 1, 3 do
			rings[i] = K.track(d, K.part({ Shape = K.CYL, Size = Vector3.new(0.25, 6, 6), Color = (i == 2) and LGOLD or GOLD, Material = Enum.Material.Neon, Transparency = 0.35 }, 6))
		end
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not rings[1].Parent then
				conn:Disconnect()
				return
			end
			if d._ringsGone then
				return
			end
			local el = os.clock() - t0
			local pp = vpos()
			for i, r in ipairs(rings) do
				r.CFrame = CFrame.new(pp) * CFrame.Angles(el * (2 + i), el * 1.5 * i, i * 1.1) * CFrame.Angles(0, 0, math.pi / 2)
			end
		end)
		d._rings = rings
		-- la mallette s'ouvre dans les mains
		local base = CFrame.new(0, -1.1, 0)
		K.prop(d, c, "Right Arm", Vector3.new(0.5, 1.4, 2.2), base * CFrame.new(0.2, -0.9, -0.4), BLACK)
		local lid = K.prop(d, c, "Right Arm", Vector3.new(0.12, 1.4, 2.2), base * CFrame.new(0.2, -0.9, -1.3) * CFrame.Angles(0.9, 0, 0), BLACK)
		K.prop(d, c, "Right Arm", Vector3.new(0.52, 1.0, 1.8), base * CFrame.new(0.2, -0.9, -0.5), GOLD, nil, Enum.Material.Neon)
		if lid then
			K.light(lid.Position, GOLD, 14, 3, 1.2)
		end
	end)

	-- torrent de lingots et de billets
	K.at(d, T.bar0 - 0.1, function()
		K.anim(c, A.Barrage)
		K.shot(d, "orbit", { at = function() return cpos():Lerp(vpos(), 0.4) end, basis = basis, angle = -70, radius = 9, height = 1.5, speed = 30, fov = 60 })
		K.layer({ { S.Register, 1 }, { "Barrage", 0.8 } }, cpos())
	end)
	for i = 0, T.bars - 1 do
		K.at(d, T.bar0 + i * T.barStep - 0.09, function()
			local arm = c:FindFirstChild("Right Arm")
			local from = arm and (arm.CFrame * CFrame.new(0, -2, -0.6)).Position or cpos()
			for j = 1, 3 do
				local isBar = j ~= 2
				local b = K.part(isBar and { Size = Vector3.new(0.7, 0.45, 1.3), CFrame = CFrame.lookAt(from, vpos()), Color = GOLD, Material = Enum.Material.Neon }
					or { Size = Vector3.new(1.3, 0.06, 0.65), CFrame = CFrame.lookAt(from, vpos()), Color = CASH }, 0.2)
				local to = vpos() + Vector3.new(K.rng:NextNumber(-0.8, 0.8), K.rng:NextNumber(-0.5, 1.2), K.rng:NextNumber(-0.8, 0.8))
				K.tween(b, 0.09, { CFrame = CFrame.lookAt(to, to + (to - from).Unit) * CFrame.Angles(K.rng:NextNumber(-1, 1), 0, K.rng:NextNumber(-1, 1)) }, Enum.EasingStyle.Linear)
			end
			K.streak(from, vpos(), GOLD, 0.5, 0.12)
		end)
		K.at(d, T.bar0 + i * T.barStep, function()
			local p = vpos()
			coinBurst(K, p, 4, 8, 0.5)
			K.sparks(p, 8, GOLD)
			K.sound(i % 2 == 0 and "Punch" or "MetalHit", p, 0.8, 1 + i * 0.03)
			if i % 3 == 0 then
				K.sound(S.Coins, p, 0.7, 1.1)
			end
			K.word(p + Vector3.new(K.rng:NextNumber(-1.5, 1.5), 2.5, 0), (i % 2 == 0) and "$$$!" or "CHA-CHING!", 0.7, "Light")
			if K.involved(d) then
				K.shake(0.25)
			end
			if i == T.bars - 1 then
				K.bigImpact(p, fwd, 1.2, GOLD)
				if K.involved(d) then
					K.impactFrames("BW", 0.035)
				end
			end
		end)
	end

	-- la mallette lancée devient géante, s'ouvre et CROQUE la victime
	local halves = {}
	K.at(d, T.toss, function()
		K.anim(c, A.Toss)
		K.sound("Whoosh3", cpos(), 1)
		K.sound("Windup", cpos(), 0.8)
		K.shot(d, "orbit", { at = function() return vpos() + Vector3.new(0, 3, 0) end, basis = basis, angle = 150, r0 = 11, r1 = 17, dur = 0.6, height = 4, speed = 18, fov = 68 })
		local p = vpos()
		local top = p + Vector3.new(0, 9, 0)
		-- deux moitiés de mâchoire, ouvertes en V au-dessus de la victime
		for side = -1, 1, 2 do
			local function open(ang, h)
				return CFrame.lookAt(h, h + fwd) * CFrame.Angles(0, 0, side * ang) * CFrame.new(side * 3.6, 0, 0)
			end
			local half = {}
			for _, spec in ipairs({
				{ Vector3.new(7, 0.9, 5.4), Vector3.new(0, 0, 0), BLACK },
				{ Vector3.new(7.05, 0.3, 5.45), Vector3.new(0, side * 0.1, 0), GOLD, Enum.Material.Neon },
				{ Vector3.new(0.9, 0.7, 0.5), Vector3.new(side * -2.8, 0, -2.9), GOLD },
			}) do
				local part = K.track(d, K.part({ Size = spec[1] * 0.2, CFrame = open(1.2, top), Color = spec[3], Material = spec[4] or Enum.Material.SmoothPlastic }, 5))
				table.insert(half, { p = part, size = spec[1], off = spec[2] })
			end
			halves[side] = half
			for _, e in ipairs(half) do
				K.tween(e.p, 0.35, { Size = e.size, CFrame = open(1.2, top) * CFrame.new(e.off) }, Enum.EasingStyle.Back)
			end
		end
		halves.handle = K.track(d, K.part({ Size = Vector3.new(1.5, 1.4, 0.5), CFrame = CFrame.lookAt(top + Vector3.new(0, 0.9, 0), top + Vector3.new(0, 0.9, 0) + fwd), Color = GOLD, Material = Enum.Material.Neon }, 5))
		K.light(top, GOLD, 30, 4, 1)
		K.sparks(top, 24, GOLD)
	end)
	K.at(d, T.chomp - 0.22, function()
		local p = vpos()
		local center = p + Vector3.new(0, 0.6, 0)
		for side = -1, 1, 2 do
			for _, e in ipairs(halves[side] or {}) do
				if e.p.Parent then
					-- descend et se referme : deux parois verticales serrées autour de la victime
					local closed = CFrame.lookAt(center, center + fwd) * CFrame.new(side * 1.9, 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2)
					K.tween(e.p, 0.22, { CFrame = closed * CFrame.new(e.off) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
				end
			end
		end
		if halves.handle and halves.handle.Parent then
			K.tween(halves.handle, 0.22, { CFrame = CFrame.lookAt(center + Vector3.new(0, 4.4, 0), center + Vector3.new(0, 4.4, 0) + fwd) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		end
		K.sound("Whoosh2", p, 1, 0.7)
	end)
	K.at(d, T.chomp, function()
		local p = vpos()
		if K.involved(d) then
			K.impactFrames("BWB", 0.04)
		end
		K.layer({ { "Clang", 1.2 }, { S.Metal, 1, 0.8 }, { "Bass", 0.9 }, { "PunchHeavy", 1 } }, p)
		K.word(p + Vector3.new(0, 5.5, 0), "CHOMP!", 1.5, "Heavy")
		K.ring(CFrame.lookAt(p, p + fwd), 14, GOLD, 0.3, 0.6)
		K.shockwave(K.groundPos(p) + Vector3.new(0, 0.2, 0), 12, GOLD)
		K.dust(p, 8, nil, 10)
		if K.involved(d) then
			K.shake(1)
			K.fov(8)
			K.shot(d, "orbit", { at = function() return vpos() + Vector3.new(0, 1.5, 0) end, basis = basis, angle = 60, radius = 11, height = 2, speed = -15, fov = 60 })
		end
		pcall(K.slowmo, { c, v }, 0.1)
		-- la mallette tremble, de la lumière dorée fuit par la fente
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < T.snap - T.chomp - 0.05 do
				for side = -1, 1, 2 do
					for _, e in ipairs(halves[side] or {}) do
						if e.p.Parent then
							e.p.CFrame = e.p.CFrame + Vector3.new(K.rng:NextNumber(-0.12, 0.12), K.rng:NextNumber(-0.08, 0.08), K.rng:NextNumber(-0.12, 0.12))
						end
					end
				end
				local q = vpos() + Vector3.new(0, 0.6, 0)
				local dir = (right * K.rng:NextNumber(-1, 1) + fwd * K.rng:NextNumber(-1, 1) + Vector3.new(0, 0.01, 0)).Unit
				K.beam(q, q + dir * 9 + Vector3.new(0, K.rng:NextNumber(-0.5, 1.5), 0), 0.35, LGOLD, 0.15)
				task.wait(0.05)
			end
		end)
		K.sound("Rumble", p, 0.8)
	end)

	-- claquement de doigts : explosion d'or, ÉJECTION
	K.at(d, T.snap - 0.3, function()
		K.anim(c, A.Snap)
		K.shot(d, "follow", { subject = c, offset = CFrame.new(2.2, 1.4, -4.2), lookOffset = Vector3.new(0, 1.3, 0), flat = true, fov = 45 })
		K.sound("FinalCharge", cpos(), 0.7)
	end)
	K.at(d, T.snap - 0.08, function()
		local arm = c:FindFirstChild("Right Arm")
		if arm then
			local hp = (arm.CFrame * CFrame.new(0, -1.1, 0)).Position
			K.sound("Punch2", hp, 0.6, 1.8)
			K.sphere(hp, 3, LGOLD, 0.15, 0.4)
			K.sparks(hp, 10, GOLD)
		end
	end)
	K.at(d, T.snap, function()
		local p = vpos()
		local gp = K.groundPos(p)
		for side = -1, 1, 2 do
			for _, e in ipairs(halves[side] or {}) do
				if e.p.Parent then
					local out = right * side * 16 + Vector3.new(0, 10, 0) + fwd * K.rng:NextNumber(-4, 4)
					K.tween(e.p, 0.6, { CFrame = e.p.CFrame * CFrame.Angles(K.rng:NextNumber(-3, 3), K.rng:NextNumber(-3, 3), 0) + out, Transparency = 1 })
				end
			end
		end
		if halves.handle and halves.handle.Parent then
			K.tween(halves.handle, 0.6, { CFrame = halves.handle.CFrame + Vector3.new(0, 18, 0), Transparency = 1 })
		end
		d._ringsGone = true
		for _, r in ipairs(d._rings or {}) do
			if r.Parent then
				K.tween(r, 0.3, { Size = Vector3.new(0.1, 22, 22), Transparency = 1 })
			end
		end
		if K.involved(d) then
			K.impactFrames("WBWBR", 0.04)
			K.flash(GOLD, 0.35, 0.75)
		end
		K.sphere(p, 22, WHITE, 0.25, 2)
		K.sphere(p, 16, GOLD, 0.5, 2)
		K.ring(CFrame.lookAt(p, p + fwd), 30, GOLD, 0.45, 0.8)
		K.ring(CFrame.new(gp + Vector3.new(0, 0.4, 0)) * CFrame.Angles(math.pi / 2, 0, 0), 36, LGOLD, 0.5, 0.7)
		K.airRing(p, fwd, 18, WHITE, 0.3)
		coinBurst(K, p, 45, 22, 1.2)
		K.bigImpact(p, fwd, 1.6, GOLD)
		K.quake(gp, 12, GOLD, 1.2)
		K.light(p, GOLD, 50, 9, 0.7)
		K.streak(p, p + fwd * 30 + Vector3.new(0, 20, 0), GOLD, 2.4, 0.4)
		K.word(p + Vector3.new(0, 5, 0), "LIQUIDATED!", 1.9, "Heavy")
		K.layer({ { "Explosion", 1.2 }, { "Boom", 1.3 }, { "Bass", 1.2 }, { S.Register, 1.2, 0.9, 0.05 }, { S.Coins, 1.1, 0.9, 0.12 }, { "Explosion2", 0.8, 1, 0.08 } }, p)
		if K.involved(d) then
			K.shake(2)
			K.fov(16)
			K.shot(d, "track", { from = cpos() - fwd * 5 + right * 3 + Vector3.new(0, 3, 0), at = function() return vpos() end, fov = 70 })
		elseif K.near(p, 80) then
			K.shake(0.9)
		end
		pcall(K.slowmo, { c }, 0.12)
		-- traînée d'or derrière la victime éjectée
		task.spawn(function()
			local last = vpos()
			for _ = 1, 8 do
				task.wait(0.05)
				local now = vpos()
				K.streak(last, now, GOLD, 1.2, 0.35)
				last = now
			end
		end)
	end)
	K.at(d, T.total - 0.25, function()
		K.letterbox(d, false, 0.25)
	end)
end

local function whiff(K, d)
	local c = d.caster
	local cr = K.root(c)
	if not cr then
		return
	end
	K.anim(c, A.Decline)
	local dir = d.dir or cr.CFrame.LookVector
	K.sound("Throw", cr.Position, 1)
	local p0 = cr.Position + dir * 1.5 + Vector3.new(0, 1, 0)
	local slip = K.part({ Size = Vector3.new(1.2, 0.08, 1.6), CFrame = CFrame.new(p0), Color = PAPER, Material = Enum.Material.Neon }, 1)
	local p1 = p0 + dir * 18
	K.tween(slip, 0.3, { CFrame = CFrame.new(p1) * CFrame.Angles(0, 8, 0) }, Enum.EasingStyle.Linear)
	K.at(d, 0.3, function()
		if slip.Parent then
			slip.Color = Color3.fromRGB(255, 120, 30)
			K.tween(slip, 0.3, { Transparency = 1, Size = Vector3.new(0.2, 0.05, 0.2) })
		end
		for _ = 1, 8 do
			local e = K.part({ Size = Vector3.one * K.rng:NextNumber(0.3, 0.6), CFrame = CFrame.new(p1), Color = (K.rng:NextNumber() < 0.5) and Color3.fromRGB(255, 120, 30) or RED, Material = Enum.Material.Neon }, 0.6)
			K.tween(e, 0.5, { CFrame = CFrame.new(p1 + Vector3.new(K.rng:NextNumber(-1.5, 1.5), K.rng:NextNumber(1, 3), K.rng:NextNumber(-1.5, 1.5))), Transparency = 1 })
		end
		K.word(cr.Position + dir * 5 + Vector3.new(0, 3, 0), "DEAL DECLINED!", 1.1, "Light")
		K.sound("Ding", cr.Position, 0.6, 0.5)
	end)
end

return {
	Name = "Hostile Liquidation",
	Desc = "A golden contract seals the target, a torrent of gold bars, a giant briefcase CHOMP, then a finger snap blows them away.",
	Color = GOLD,
	Color2 = BLACK,
	Range = 25,
	Angle = 70,
	T = T,

	Server = function(U, caster, target, ctx)
		local cr = U.root(caster)
		if not cr then
			return
		end
		local tr = target and U.root(target)
		local look = U.flat(tr and (tr.Position - cr.Position) or cr.CFrame.LookVector, cr.CFrame.LookVector)
		if not tr or not U.valid(target, ctx) or (tr.Position - cr.Position).Magnitude > 34 then
			U.fx(ctx, "Whiff", { dir = look })
			U.wait(ctx, 0.9)
			return
		end
		local cpos = cr.Position
		U.place(ctx, caster, CFrame.lookAt(cpos, cpos + look))
		local vp = U.wallSafe(cpos, cpos + look * DIST, 1.2)
		local rise = math.clamp(U.headroom(vp, RISE + 3), 0, RISE)
		-- le contrat ramène la victime devant lui
		U.hold(ctx, target)
		U.fx(ctx, "Connect", { dir = look })
		local s = os.clock()
		local function at(t)
			return U.wait(ctx, math.max(0, s + t - os.clock()))
		end
		U.glide(ctx, target, CFrame.lookAt(vp, vp - look), T.seal, "In")
		if not at(T.seal) then return end
		U.glide(ctx, target, CFrame.lookAt(vp + Vector3.new(0, rise, 0), vp - look + Vector3.new(0, rise, 0)), 0.3, "Out")
		U.hit(ctx, target, 2, { words = { "ACQUIRED!" }, power = 0.5 })
		for i = 0, T.bars - 1 do
			if not at(T.bar0 + i * T.barStep) then return end
			U.hit(ctx, target, 2, { power = 0.35 })
		end
		if not at(T.chomp) then return end
		U.hit(ctx, target, 6, { words = { "CHOMP!" }, power = 1.0 })
		if not at(T.snap) then return end
		U.finish(ctx, target, 12, { launch = look * 95 + Vector3.new(0, 70, 0), words = { "LIQUIDATED!" }, splash = { radius = 11, damage = 10, center = vp } })
		at(T.total)
	end,

	Client = function(K, data)
		if data.phase == "Cutin" then
			K.anim(data.caster, A.Cast)
			local r = K.root(data.caster)
			if r then
				K.sound(S.Bell, r.Position, 0.7, 0.9)
				K.at(data, 0.5, function()
					coinBurst(K, r.Position + Vector3.new(0, 1, 0), 10, 6, 0.6)
					K.sound(S.Coins, r.Position, 0.7)
				end)
			end
		elseif data.phase == "Connect" then
			connect(K, data)
		elseif data.phase == "Whiff" then
			whiff(K, data)
		end
	end,
}
