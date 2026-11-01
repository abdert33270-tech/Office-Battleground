--[[
	ULTIME — The Consultant : « THE FINAL PRESENTATION »
	Rayon de pointeur laser vers la cible. Touché → la victime est tractée devant un écran de projection géant qui
	sort du sol ; chaque « diapo » est une attaque : MARKET SHARE (parts de camembert qui s'écrasent sur elle),
	GROWTH (barres d'histogramme qui jaillissent), KEY TAKEAWAY (3 tirs laser cerclés), puis « NEXT SLIDE » :
	Q4 FORECAST, une flèche de croissance dorée colossale jaillit du sol et l'envoie dans le ciel (finisher LAUNCH).
	Raté → la diapo plante : « TECHNICAL DIFFICULTIES », « LET'S CIRCLE BACK... ».
]]
local ROYAL = Color3.fromRGB(40, 100, 240)
local ROYAL2 = Color3.fromRGB(120, 175, 255)
local NAVY = Color3.fromRGB(28, 36, 64)
local LASER = Color3.fromRGB(255, 40, 50)
local ORANGE = Color3.fromRGB(255, 150, 40)
local TEAL = Color3.fromRGB(40, 200, 170)
local YELLOW = Color3.fromRGB(255, 215, 50)
local PINK = Color3.fromRGB(255, 90, 140)
local WHITE = Color3.fromRGB(250, 250, 250)
local GOLD = Color3.fromRGB(255, 200, 60)
local CHART = { ORANGE, TEAL, YELLOW, PINK }

local T = { Pie = 0.6, Bar = 1.1, Laser = { 1.5, 1.66, 1.82 }, Next = 2.1, Launch = 2.5, End = 3.35 }

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local A = {}
A.Point = { -- bras tendu, l'autre main dans le dos
	{ t = 0 },
	{ t = 0.12, RS = { p = 1.65, y = 0.1 }, LS = { p = -0.3, r = 0.5, y = 0.6 }, RJ = { tw = 0.35, ln = 0.1 }, RH = { p = 0.3 }, LH = { p = -0.25 } },
	{ t = 0.6, RS = { p = 1.6 }, LS = { p = -0.3, r = 0.5, y = 0.6 }, RJ = { tw = 0.4, ln = 0.15 }, RH = { p = 0.3 }, LH = { p = -0.25 } },
}
A.Toss = { -- lance les parts de camembert à deux mains
	{ t = 0 },
	{ t = 0.12, RS = { p = 0.4, y = -1.0, r = -0.6 }, LS = { p = 0.4, y = 1.0, r = 0.6 }, RJ = { ln = -0.25 } },
	{ t = 0.22, RS = { p = 1.8, y = 0.7 }, LS = { p = 1.8, y = -0.7 }, RJ = { ln = 0.45 }, RH = { p = -0.5 }, LH = { p = 0.7 } },
	{ t = 0.45 },
}
A.Rise = { -- geste ascendant : les barres montent
	{ t = 0 },
	{ t = 0.1, RS = { p = 0.3, r = 0.3 }, LS = { p = 0.3, r = -0.3 }, RJ = { ln = 0.5 }, RH = { p = 0.8 }, LH = { p = 0.8 } },
	{ t = 0.22, RS = { p = 3.0, r = 0.6 }, LS = { p = 3.0, r = -0.6 }, RJ = { ln = -0.45 }, RH = { p = -0.1 }, LH = { p = -0.1 } },
	{ t = 0.4 },
}
A.Click = { -- lève la télécommande : NEXT SLIDE
	{ t = 0 },
	{ t = 0.12, RS = { p = 2.7, y = 0.2 }, LS = { p = -0.2, r = 0.5, y = 0.6 }, RJ = { ln = -0.25, tw = 0.2 } },
	{ t = 0.3, RS = { p = 2.5, y = 0.2 }, LS = { p = -0.2, r = 0.5, y = 0.6 }, RJ = { ln = -0.2, tw = 0.2 } },
	{ t = 0.36, RS = { p = 1.7, y = 0.2 }, LS = { p = -0.2, r = 0.5, y = 0.6 }, RJ = { ln = 0.3, tw = 0.25 }, RH = { p = -0.4 }, LH = { p = 0.6 } },
	{ t = 0.8, RS = { p = 1.7, y = 0.2 }, LS = { p = -0.2, r = 0.5, y = 0.6 }, RJ = { ln = 0.25, tw = 0.2 }, RH = { p = -0.35 }, LH = { p = 0.55 } },
}
A.Victory = { -- bras en V, buste cambré
	{ t = 0 },
	{ t = 0.15, RS = { p = 3.0, r = 0.7 }, LS = { p = 3.0, r = -0.7 }, RJ = { ln = -0.45 }, RH = { r = 0.15 }, LH = { r = -0.15 } },
	{ t = 0.75, RS = { p = 2.95, r = 0.75 }, LS = { p = 2.95, r = -0.75 }, RJ = { ln = -0.4 } },
	{ t = 0.95 },
}
A.Whiff = { -- haussement d'épaules, tapote la télécommande
	{ t = 0 },
	{ t = 0.15, RS = { p = 1.4, y = 0.3 }, LS = { p = 1.0, y = 1.2, r = -0.6 }, RJ = { sd = 0.12, ln = 0.15 } },
	{ t = 0.35, RS = { p = 1.6, y = 0.3 }, LS = { p = 1.0, y = 1.2, r = -0.6 }, RJ = { sd = -0.1, ln = 0.15 } },
	{ t = 0.55, RS = { p = 1.4, y = 0.3 }, LS = { p = 1.0, y = 1.2, r = -0.6 }, RJ = { sd = 0.1, ln = 0.15 } },
	{ t = 0.8 },
}
A.VHeld = { { t = 0 }, { t = 0.1, RS = { p = 0.3, r = 0.5 }, LS = { p = 0.3, r = -0.5 }, RJ = { ln = -0.15 }, RH = { r = 0.1 }, LH = { r = -0.1 } }, { t = 2.4, RS = { p = 0.3, r = 0.5 }, LS = { p = 0.3, r = -0.5 }, RJ = { ln = -0.1 } } }
A.VJolt = { { t = 0 }, { t = 0.05, RS = { p = 0.8, r = 0.6 }, LS = { p = 0.8, r = -0.6 }, RJ = { ln = -0.5 } }, { t = 0.25, RS = { p = 0.3, r = 0.5 }, LS = { p = 0.3, r = -0.5 }, RJ = { ln = -0.1 } } }
A.VUp = { { t = 0 }, { t = 0.06, RS = { p = 3.0, r = 0.4 }, LS = { p = 3.0, r = -0.4 }, RJ = { ln = -0.6 }, RH = { p = -0.4 }, LH = { p = 0.3 } }, { t = 0.3, RS = { p = 0.3, r = 0.5 }, LS = { p = 0.3, r = -0.5 }, RJ = { ln = -0.1 } } }

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
local function handPos(ch, fallback)
	local arm = ch and ch:FindFirstChild("Right Arm")
	return arm and (arm.CFrame * CFrame.new(0, -1.2, -0.3)).Position or fallback
end
local function surfaceText(part, face, text, color, font)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 30
	sg.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = font or Enum.Font.GothamBlack
	l.TextColor3 = color
	l.Parent = sg
	return l
end
local function laserLine(K, data, from, to, w, life)
	local len = (to - from).Magnitude
	local p = K.part({ Size = Vector3.new(w, w, len), CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2), Color = LASER, Material = Enum.Material.Neon }, life + 0.05)
	K.tween(p, life, { Size = Vector3.new(w * 0.2, w * 0.2, len), Transparency = 1 })
	return p
end

------------------------------------------------------------------------
local M = {
	Name = "THE FINAL PRESENTATION",
	Desc = "Beam them into a giant slideshow where every slide hits harder, then NEXT SLIDE: a colossal growth arrow sends them to the moon.",
	Color = ROYAL,
	Color2 = GOLD,
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
			play(K, caster, A.Click)
			K.sound("Ding", r.Position, 1, 1.2)
			K.at(data, 0.3, function()
				K.ring(CFrame.lookAt(r.Position - Vector3.new(0, 2.8, 0), r.Position + Vector3.new(0, 5, 0)), 11, ROYAL2, 0.5, 0.3)
				K.light(r.Position, ROYAL, 22, 5, 0.6)
				K.word(r.Position + Vector3.new(0, 5, 0), "NEXT SLIDE!", 0.9, "Light")
			end)
		end
		return
	end

	if phase == "Rush" then
		play(K, caster, A.Point)
		local r = K.root(caster)
		if not r then
			return
		end
		local dir = data.dir or r.CFrame.LookVector
		local stop = data.hitPos and (data.hitPos - r.Position).Magnitude or (data.range or 26)
		K.sound("Electric", r.Position, 1, 1.2)
		-- rayon laser de « convocation » qui s'allonge
		run(0.3, function(a)
			local from = handPos(caster, r.Position)
			laserLine(K, data, from, from + dir * stop * a, 0.25, 0.08)
		end)
		K.at(data, 0.32, function()
			local hp = data.hitPos or (r.Position + dir * stop)
			K.sparks(hp, 12, LASER)
			K.ring(CFrame.lookAt(hp, hp - dir), 5, LASER, 0.35, 0.3)
			K.word(hp + Vector3.new(0, 3.5, 0), "YOU. MY OFFICE.", 0.9, "Light")
		end)
		return
	end

	if phase == "Whiff" then
		play(K, caster, A.Whiff)
		local r = K.root(caster)
		if r then
			local dir = r.CFrame.LookVector
			local scr = K.part({ Size = Vector3.new(6, 3.6, 0.2), CFrame = CFrame.lookAt(r.Position + dir * 5 + Vector3.new(0, 2, 0), r.Position + Vector3.new(0, 2, 0)), Color = Color3.fromRGB(30, 60, 200), Material = Enum.Material.Neon }, 1.3)
			surfaceText(scr, Enum.NormalId.Front, "TECHNICAL DIFFICULTIES", WHITE)
			surfaceText(scr, Enum.NormalId.Back, "TECHNICAL DIFFICULTIES", WHITE)
			K.tween(scr, 0.3, { Transparency = 0 })
			K.at(data, 0.9, function()
				K.tween(scr, 0.3, { Transparency = 1 })
			end)
			K.sound("SlideWhistle", r.Position, 0.9, 0.8)
			K.word(r.Position + Vector3.new(0, 5, 0), "LET'S CIRCLE BACK...", 1.0, "Light")
		end
		return
	end

	if phase ~= "Connect" then
		return
	end
	K.letterbox(data, true, 0.2)
	local cf = data.cf or CFrame.new()
	local vp0 = data.vp or (cf.Position + cf.LookVector * 8)
	local look, right, up = cf.LookVector, cf.RightVector, Vector3.yAxis
	local function vp()
		return rootPos(target, vp0)
	end
	local g0 = K.groundPos(vp0)
	play(K, caster, A.Point)
	play(K, target, A.VHeld)
	K.sound("Electric", vp0, 1.2, 0.9)
	K.sound(K.SFX.Sting, nil, 0.5, 1)
	-- traction laser pendant le glissement de la victime
	run(0.3, function()
		laserLine(K, data, handPos(caster, cf.Position), vp(), 0.3, 0.06)
	end)
	K.shot(data, "orbit", { at = function() return vp() + up * 1.5 end, radius = 14, height = 3.5, angle = 150, speed = 40, basis = cf, fov = 62 })

	-- écran de projection géant qui sort du sol derrière la victime
	local scf = CFrame.lookAt(g0 + look * 4.5, g0 + look * 4.5 - look)
	local parts = {}
	local function add(size, off, color, mat)
		local p = K.part({ Size = size, CFrame = scf * off * CFrame.new(0, -12, 0), Color = color, Material = mat or Enum.Material.SmoothPlastic }, 5)
		K.track(data, p)
		table.insert(parts, { p = p, cf = scf * off })
		return p
	end
	add(Vector3.new(0.5, 9, 0.5), CFrame.new(-6.4, 4.5, 0.4), NAVY)
	add(Vector3.new(0.5, 9, 0.5), CFrame.new(6.4, 4.5, 0.4), NAVY)
	add(Vector3.new(13.4, 7.6, 0.4), CFrame.new(0, 6.2, 0.2), NAVY)
	local screen = add(Vector3.new(12.6, 6.8, 0.45), CFrame.new(0, 6.2, 0), WHITE)
	local header = add(Vector3.new(12.6, 1.2, 0.5), CFrame.new(0, 9.0, 0), ROYAL)
	local title = surfaceText(header, Enum.NormalId.Front, "AGENDA", WHITE)
	local body = surfaceText(screen, Enum.NormalId.Front, "1. YOU  2. ME  3. PAIN", NAVY, Enum.Font.GothamBold)
	body.Size = UDim2.fromScale(1, 0.6)
	body.Position = UDim2.fromScale(0, 0.3)
	for _, e in ipairs(parts) do
		K.tween(e.p, 0.35, { CFrame = e.cf }, Enum.EasingStyle.Back)
	end
	K.dust(g0 + look * 4.5, 7, nil, 10)
	K.sound("Rumble", g0, 1, 1)
	K.darken(true, 0.4, 0.3)
	-- faisceau de projecteur depuis le lanceur
	local beam = K.part({ Size = Vector3.new(1, 1, 1), Color = ROYAL2, Material = Enum.Material.Neon, Transparency = 1 }, 5)
	K.track(data, beam)
	K.at(data, 0.35, function()
		local from = cf.Position + up * 2.5 - look * 1
		local to = (scf * CFrame.new(0, 6.2, 0)).Position
		local len = (to - from).Magnitude
		beam.Size = Vector3.new(6, 3.5, len)
		beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -len / 2)
		K.tween(beam, 0.3, { Transparency = 0.88 })
		K.light(to, ROYAL2, 25, 3, 2)
	end)
	local function slide(t, text, sub)
		K.at(data, t, function()
			title.Text = text
			body.Text = sub
			K.sound("Ding", (scf * CFrame.new(0, 6, 0)).Position, 0.6, 1.3)
			K.flash(WHITE, 0.06, 0.25)
		end)
	end
	slide(T.Pie - 0.25, "MARKET SHARE", "YOUR SHARE: 0%")
	slide(T.Bar - 0.2, "GROWTH", "MINE: +300%")
	slide(T.Laser[1] - 0.2, "KEY TAKEAWAY", "YOU LOSE.")
	slide(T.Next, "Q4 FORECAST", "UP. WAY UP.")

	-- 1) MARKET SHARE : parts de camembert qui s'écrasent
	K.at(data, T.Pie - 0.22, function()
		play(K, caster, A.Toss)
		K.shot(data, "fixed", { pos = vp0 - right * 9 + up * 2 - look * 2, lookAt = vp0 + up * 0.5, fov = 58 })
		for k = 1, 4 do
			local ang = k * math.pi / 2 + math.pi / 4
			local from = vp0 + Vector3.new(math.cos(ang) * 9, 3 + k * 0.5, math.sin(ang) * 9)
			local w = K.part({ Size = Vector3.new(0.6, 3, 3), CFrame = CFrame.new(from), Color = CHART[k] }, 0.4)
			K.track(data, w)
			local p0 = from
			run(0.22, function(a)
				local c = vp() + up * 0.5
				w.CFrame = CFrame.lookAt(p0:Lerp(c, a), c) * CFrame.Angles(0, math.pi / 2, a * 8)
			end)
		end
		K.sound("Whoosh", vp0, 1.2, 1)
	end)
	K.at(data, T.Pie, function()
		local c = vp()
		play(K, target, A.VJolt)
		K.impactFrames("BW", 0.04)
		K.layer({ { "PunchHeavy", 1.3 }, { K.SFX.Hit, 1 } }, c)
		K.shake(0.9)
		K.shards(c, 14, CHART, 1.4)
		K.ring(CFrame.lookAt(c, c + up), 8, ORANGE, 0.3, 0.4)
		K.word(c + up * 3, "MARKET SHARE!", 1.2, "Heavy")
	end)

	-- 2) GROWTH : barres qui jaillissent sous la victime
	K.at(data, T.Bar - 0.15, function()
		play(K, caster, A.Rise)
		K.shot(data, "fixed", { pos = vp0 - look * 5 + right * 4 + up * 0.3, lookAt = vp0 + up * 3, fov = 70 })
	end)
	K.at(data, T.Bar, function()
		local c = vp()
		local g = K.groundPos(c)
		play(K, target, A.VUp)
		for k = 1, 3 do
			local off = right * (k - 2) * 1.6
			local h = 3 + k * 1.3
			local b = K.part({ Size = Vector3.new(1.4, 0.2, 1.4), CFrame = CFrame.new(g + off), Color = CHART[k + 1] }, 1.2)
			K.track(data, b)
			K.tween(b, 0.1, { Size = Vector3.new(1.4, h, 1.4), CFrame = CFrame.new(g + off + up * h / 2) }, Enum.EasingStyle.Back)
			K.at(data, T.Bar + 0.5, function()
				K.tween(b, 0.3, { Size = Vector3.new(1.4, 0.2, 1.4), CFrame = CFrame.new(g + off), Transparency = 1 })
			end)
		end
		K.impactFrames("W", 0.04)
		K.layer({ { "Uppercut", 1.3 }, { "GroundSlam", 1, 1.1 } }, c)
		K.shake(1.0)
		K.debris(g, 6, { NAVY, TEAL }, 1, 0.7)
		K.bigImpact(c, up, 1.0, TEAL)
		K.word(c + up * 3.5, "+300%!", 1.3, "Heavy")
	end)

	-- 3) KEY TAKEAWAY : cercle laser + 3 tirs
	K.at(data, T.Laser[1] - 0.25, function()
		play(K, caster, A.Point)
		K.shot(data, "fixed", { pos = cf.Position - look * 3 + up * 2.5 + right * 2, lookAt = vp0 + up * 0.5, fov = 55 })
		local ring = K.part({ Shape = K.CYL, Size = Vector3.new(0.12, 4.5, 4.5), Color = LASER, Material = Enum.Material.Neon, Transparency = 0.3 }, 1)
		K.track(data, ring)
		run(0.75, function(a)
			ring.CFrame = CFrame.lookAt(vp(), vp() - look) * CFrame.Angles(0, math.pi / 2, a * 6)
			ring.Transparency = 0.3 + a * 0.5
		end)
	end)
	for i, t in ipairs(T.Laser) do
		K.at(data, t, function()
			local c = vp()
			local from = handPos(caster, cf.Position)
			laserLine(K, data, from, c, 0.6, 0.2)
			play(K, target, A.VJolt)
			K.sound("Electric", c, 1.1, 0.9 + i * 0.1)
			K.sound("Punch", c, 0.9, 1.2)
			K.sparks(c, 12, LASER)
			K.light(c, LASER, 18, 5, 0.2)
			K.shake(0.5 + i * 0.1)
			K.impactFrames("R", 0.035)
			K.word(c + up * 2.5 + right * (i - 2) * 1.8, ({ "KEY TAKEAWAY!", "ACTION ITEM!", "LOW-HANGING FRUIT!" })[i], 0.9, "Heavy")
		end)
	end

	-- 4) NEXT SLIDE : Q4 FORECAST
	K.at(data, T.Next, function()
		play(K, caster, A.Click)
		K.sound("Ding", cf.Position, 1.2, 1)
		K.sound(K.SFX.FinalCharge, cf.Position, 0.9, 1)
		if K.involved(data) then
			K.cutin(data, { title = "NEXT SLIDE: Q4 FORECAST", sub = "THE FINAL PRESENTATION", color = ROYAL, color2 = GOLD, dur = 0.55, small = true })
		end
		K.shot(data, "fixed", { pos = cf.Position - look * 6 + up * 3 - right * 3, lookAt = vp0 + up * 3, fov = 68 })
		-- flèche géante dessinée sur l'écran
		local a1 = K.part({ Size = Vector3.new(1, 0.1, 0.1), CFrame = scf * CFrame.new(0, 6, -0.3), Color = GOLD, Material = Enum.Material.Neon }, 2)
		K.track(data, a1)
		K.tween(a1, 0.3, { Size = Vector3.new(1, 5, 0.1) })
		local ground = K.groundPos(vp0)
		K.cracks(ground, 8, 4, 1)
		K.implode(ground + up, 6, { GOLD, WHITE }, 14, 0.35)
		K.sound("Rumble", ground, 1.2, 0.8)
	end)
	-- 5) LANCEMENT : flèche dorée colossale
	K.at(data, T.Launch, function()
		local c = vp()
		local g = K.groundPos(c)
		play(K, caster, A.Victory)
		local shaft = K.part({ Size = Vector3.new(2.2, 0.3, 2.2), CFrame = CFrame.new(g), Color = GOLD, Material = Enum.Material.Neon }, 2)
		local head = K.part({ Size = Vector3.new(2.2, 3.5, 5), CFrame = CFrame.new(g) * CFrame.Angles(0, 0, 0), Color = GOLD, Material = Enum.Material.Neon }, 2)
		local head2 = K.part({ Size = Vector3.new(2.2, 3.5, 5), CFrame = CFrame.new(g), Color = GOLD, Material = Enum.Material.Neon }, 2)
		for _, p in ipairs({ shaft, head, head2 }) do
			K.track(data, p)
		end
		head.Shape = Enum.PartType.Block
		local w1 = Instance.new("SpecialMesh")
		w1.MeshType = Enum.MeshType.Wedge
		w1.Parent = head
		local w2 = Instance.new("SpecialMesh")
		w2.MeshType = Enum.MeshType.Wedge
		w2.Parent = head2
		run(0.35, function(a)
			local hgt = 2 + 26 * a
			shaft.Size = Vector3.new(2.2, hgt, 2.2)
			shaft.CFrame = CFrame.new(g + up * hgt / 2)
			local top = g + up * (hgt + 1.7)
			local fr = CFrame.lookAt(top, top + look)
			head.CFrame = fr * CFrame.new(0, 0, -1.25) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, 0, 0) * CFrame.new(0, 0, 0)
			head.CFrame = CFrame.fromMatrix(top - look * 1.25, look, up) * CFrame.Angles(0, -math.pi / 2, 0)
			head2.CFrame = CFrame.fromMatrix(top + look * 1.25, -look, up) * CFrame.Angles(0, -math.pi / 2, 0)
		end)
		K.impactFrames("BWBWB", 0.045)
		K.layer({ { "Boom", 1.6 }, { "Bass", 1.4, 0.85 }, { "Explosion", 1.2, 1, 0.03 }, { "Uppercut", 1.4, 0.8 }, { "PowerUp", 1, 1.2, 0.1 } }, c)
		K.shake(2.0)
		K.fov(14)
		K.crater(g, 9, GOLD, 3)
		K.shockwave(g + up * 0.3, 18, GOLD)
		K.shockwave(g + up * 0.4, 10, ROYAL2)
		K.pillar(g, 3, 30, GOLD, 0.6)
		K.light(c, GOLD, 50, 10, 0.6)
		K.debris(g, 8, { NAVY, GOLD, WHITE }, 1.5, 1.1)
		K.word(c + up * 6, "STONKS!!", 2.0, "Heavy")
		K.darken(false, 0, 0.4)
		K.shot(data, "track", { from = g - look * 12 + right * 6 + up * 2, at = function() return vp() end, fov = 70 })
		K.at(data, T.Launch + 0.55, function()
			for _, p in ipairs({ shaft, head, head2 }) do
				K.tween(p, 0.35, { Transparency = 1 })
			end
			for _, e in ipairs(parts) do
				K.tween(e.p, 0.4, { CFrame = e.cf * CFrame.new(0, -12, 0) })
			end
			K.tween(beam, 0.2, { Transparency = 1 })
		end)
	end)
	K.at(data, T.Launch + 0.5, function()
		K.word(vp0 + up * 4 + right * 3, "MEETING ADJOURNED.", 1.0, "Light")
	end)
end

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
	if not U.wait(ctx, 0.5) then
		return
	end
	if ok then
		local vr = U.root(target)
		ok = U.valid(target, ctx) and vr ~= nil and (vr.Position - cf.Position).Magnitude <= ctx.range + 6
	end
	if not ok then
		U.fx(ctx, "Whiff")
		U.wait(ctx, 0.85)
		return
	end
	local vr = U.root(target)
	cf = U.facing(cf.Position, vr.Position)
	U.place(ctx, caster, cf)
	local vp = U.wallSafe(cf.Position, cf.Position + cf.LookVector * 8, 2)
	U.hold(ctx, target, U.facing(vr.Position, cf.Position))
	U.glide(ctx, target, U.facing(vp, cf.Position), 0.3, "Out")
	U.fx(ctx, "Connect", { cf = cf, vp = vp })
	local tc = os.clock()
	local function at(t)
		return U.wait(ctx, math.max(0, t - (os.clock() - tc)))
	end
	if not at(T.Pie) then
		return
	end
	U.hit(ctx, target, 6, { power = 0.8, words = { "MARKET SHARE!" }, stun = 0.8 })
	if not at(T.Bar) then
		return
	end
	U.hit(ctx, target, 6, { power = 0.8, words = { "+300%!" }, stun = 0.8 })
	for i, t in ipairs(T.Laser) do
		if not at(t) then
			return
		end
		U.hit(ctx, target, 2, { power = 0.5, words = { "KEY TAKEAWAY!", "ACTION ITEM!", "SYNERGY!" }, stun = 0.6 })
	end
	if not at(T.Launch) then
		return
	end
	U.finish(ctx, target, 17, { launch = Vector3.new(0, 95, 0) + cf.LookVector * 12, words = { "STONKS!!" }, splash = { radius = 12, damage = 10, center = vp } })
	at(T.End)
end

return M
