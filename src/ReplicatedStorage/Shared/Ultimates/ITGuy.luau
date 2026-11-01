--[[
	Ultime de l'IT Guy : « FORMAT C:\ »
	Rayon de scan depuis le portable -> la victime est numérisée (sol cyberespace + monolithes binaires),
	3 coups de CLAVIER GÉANT (les touches ESC / ALT / DEL s'envolent), barre « DELETING… » pendant qu'il tape,
	puis 4 murs .ZIP se referment sur la victime et il l'écrase d'un coup de marteau-poing : PLAQUÉE au sol (cratère).
	Raté : le rayon de scan part dans le vide, panneau « 404 TARGET NOT FOUND ».
]]
local TEAL = Color3.fromRGB(0, 200, 170)
local NEON = Color3.fromRGB(0, 255, 190)
local BLUE = Color3.fromRGB(40, 140, 255)
local BSOD = Color3.fromRGB(20, 90, 220)
local DARK = Color3.fromRGB(25, 28, 34)
local NAVY = Color3.fromRGB(8, 16, 34)
local RED = Color3.fromRGB(255, 60, 90)
local WHITE = Color3.new(1, 1, 1)
local GLITCH = { NEON, Color3.fromRGB(20, 20, 25), WHITE, Color3.fromRGB(255, 40, 160), BLUE }

-- sons Creator Store vérifiés (ils se chargent)
local S = {
	Glitch = "rbxassetid://119121567196332",
	Typing = "rbxassetid://9116157899",
	Zap = "rbxassetid://9114277402",
	Zap2 = "rbxassetid://9114277757",
}

-- minutage partagé serveur / client (secondes depuis la phase "Connect")
local T = { s1 = 0.55, s2 = 0.95, s3 = 1.4, del = 1.6, walls = 2.35, slam = 2.85, total = 3.4 }
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
local DIST = 5 -- distance victime / lanceur pendant la séquence

------------------------------------------------------------------------
-- Animations (ProcAnim)
------------------------------------------------------------------------
local A = {}
A.Cast = { -- ouvre le portable, tape comme un fou, index levé
	{ t = 0 },
	{ t = 0.1, RS = { p = 1.3, y = 0.5 }, LS = { p = 1.35, y = 0.7 }, RJ = { ln = 0.25 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
}
for i = 1, 8 do
	table.insert(A.Cast, { t = 0.1 + i * 0.07, RS = { p = (i % 2 == 0) and 1.55 or 1.15, y = 0.5 }, LS = { p = 1.35, y = 0.7 }, RJ = { ln = (i % 2 == 0) and 0.3 or 0.22, tw = (i % 2 == 0) and 0.05 or -0.05 }, RH = { p = -0.2 }, LH = { p = 0.3 } })
end
table.insert(A.Cast, { t = 0.8, RS = { p = 2.9, y = 0.1, r = -0.2 }, LS = { p = 1.3, y = 0.7 }, RJ = { ln = -0.25, tw = 0.25 } })
table.insert(A.Cast, { t = 1.15, RS = { p = 2.95, y = 0.1, r = -0.2 }, LS = { p = 1.3, y = 0.7 }, RJ = { ln = -0.28, tw = 0.25 } })
table.insert(A.Cast, { t = 1.3 })

A.Scan = { -- paume tendue : le rayon part du portable
	{ t = 0 },
	{ t = 0.06, RS = { p = 1.0, y = 0.4 }, LS = { p = 1.4, y = 0.6 }, RJ = { ln = 0.15, tw = -0.3 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
	{ t = 0.14, RS = { p = 1.75, y = 0, r = 0.1 }, LS = { p = 1.55, y = 0.3 }, RJ = { ln = -0.1, tw = 0.25 }, RH = { p = -0.35 }, LH = { p = 0.45 } },
	{ t = 0.42, RS = { p = 1.7, y = 0, r = 0.1 }, LS = { p = 1.5, y = 0.3 }, RJ = { ln = -0.08, tw = 0.22 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
	{ t = 0.5 },
}
A.Swing1 = { -- clavier géant à deux mains : swing de droite à gauche
	{ t = 0 },
	{ t = 0.12, RS = { p = 1.5, y = -1.35, r = -0.4 }, LS = { p = 1.3, y = 1.1 }, RJ = { tw = -1.0, ln = 0.05 }, RH = { p = 0.35 }, LH = { p = -0.25 } },
	{ t = 0.2, RS = { p = 1.6, y = 1.3, r = -0.1 }, LS = { p = 1.45, y = -0.4 }, RJ = { tw = 1.0, ln = 0.2 }, RH = { p = -0.4 }, LH = { p = 0.55 } },
	{ t = 0.34, RS = { p = 1.5, y = 1.2 }, LS = { p = 1.4, y = -0.35 }, RJ = { tw = 0.85, ln = 0.18 }, RH = { p = -0.35 }, LH = { p = 0.5 } },
}
A.Swing2 = { -- revers de gauche à droite
	{ t = 0, RS = { p = 1.5, y = 1.2 }, LS = { p = 1.4, y = -0.35 }, RJ = { tw = 0.85, ln = 0.18 } },
	{ t = 0.1, RS = { p = 1.7, y = 1.6, r = -0.2 }, LS = { p = 1.5, y = -0.1 }, RJ = { tw = 1.15, ln = 0.05 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
	{ t = 0.18, RS = { p = 1.45, y = -1.35, r = -0.5 }, LS = { p = 1.35, y = 1.0 }, RJ = { tw = -1.05, ln = 0.25 }, RH = { p = 0.5 }, LH = { p = -0.4 } },
	{ t = 0.34, RS = { p = 1.4, y = -1.2, r = -0.4 }, LS = { p = 1.3, y = 0.9 }, RJ = { tw = -0.9, ln = 0.2 }, RH = { p = 0.45 }, LH = { p = -0.35 } },
}
A.Swing3 = { -- clavier levé au-dessus de la tête, écrasé droit devant
	{ t = 0, RS = { p = 1.4, y = -1.2, r = -0.4 }, LS = { p = 1.3, y = 0.9 }, RJ = { tw = -0.9, ln = 0.2 } },
	{ t = 0.16, RS = { p = 3.15, r = -0.15 }, LS = { p = 3.1, r = -0.15 }, RJ = { ln = -0.5 }, RH = { p = 0.2 }, LH = { p = 0.2 } },
	{ t = 0.26, RS = { p = 3.25, r = -0.1 }, LS = { p = 3.2, r = -0.1 }, RJ = { ln = -0.58 }, RH = { p = 0.15 }, LH = { p = 0.15 } },
	{ t = 0.34, RS = { p = 0.85, r = -0.1 }, LS = { p = 0.85, r = -0.1 }, RJ = { ln = 0.75 }, RH = { p = 0.95 }, LH = { p = -0.3 } },
	{ t = 0.55, RS = { p = 0.9, r = -0.1 }, LS = { p = 0.9, r = -0.1 }, RJ = { ln = 0.7 }, RH = { p = 0.9 }, LH = { p = -0.3 } },
	{ t = 0.65 },
}
A.Type = { { t = 0 } } -- frappe frénétique sur le portable holographique
for i = 1, 11 do
	table.insert(A.Type, { t = i * 0.065, RS = { p = (i % 2 == 0) and 1.5 or 1.1, y = 0.45 }, LS = { p = (i % 2 == 0) and 1.1 or 1.5, y = 0.45 }, RJ = { ln = 0.32, tw = (i % 2 == 0) and 0.07 or -0.07 }, RH = { p = -0.2 }, LH = { p = 0.35 } })
end
table.insert(A.Type, { t = 0.8, RS = { p = 2.5, y = 0.2 }, LS = { p = 1.1, y = 0.45 }, RJ = { ln = -0.1 } })
A.Slam = { -- bond, deux poings joints au ciel, marteau-poing au sol (genou à terre)
	{ t = 0 },
	{ t = 0.12, RS = { p = -0.6 }, LS = { p = -0.6 }, RJ = { ln = 0.55 }, RH = { p = 0.9 }, LH = { p = 0.9 } },
	{ t = 0.28, RS = { p = 3.15, r = 0.25 }, LS = { p = 3.15, r = 0.25 }, RJ = { ln = -0.55 }, RH = { p = 1.2 }, LH = { p = 0.4 } },
	{ t = 0.42, RS = { p = 3.2, r = 0.28 }, LS = { p = 3.2, r = 0.28 }, RJ = { ln = -0.62 }, RH = { p = 1.3 }, LH = { p = 0.35 } },
	{ t = 0.5, RS = { p = 0.55, r = 0.3 }, LS = { p = 0.55, r = 0.3 }, RJ = { ln = 1.0 }, RH = { p = 1.35 }, LH = { p = -0.5 } },
	{ t = 0.95, RS = { p = 0.6, r = 0.3 }, LS = { p = 0.6, r = 0.3 }, RJ = { ln = 0.95 }, RH = { p = 1.3 }, LH = { p = -0.45 } },
	{ t = 1.15 },
}
A.Shrug = { -- raté : « hein ? »
	{ t = 0 },
	{ t = 0.12, RS = { p = 1.75, y = 0 }, LS = { p = 1.4, y = 0.4 }, RJ = { ln = -0.1, tw = 0.25 } },
	{ t = 0.45, RS = { p = 1.7 }, LS = { p = 1.4, y = 0.4 }, RJ = { ln = -0.08, tw = 0.22 } },
	{ t = 0.6, RS = { p = 0.6, r = -1.2 }, LS = { p = 0.6, r = -1.2 }, RJ = { sd = 0.15 } },
	{ t = 0.9 },
}

------------------------------------------------------------------------
-- Aides client
------------------------------------------------------------------------
local PIXEL = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Bold)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)

local function flatCF(from, to)
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
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

local function cubes(K, pos, n, colors, size, speed, life)
	for _ = 1, n do
		local s = (size or 0.6) * K.rng:NextNumber(0.6, 1.4)
		local c = K.part({ Size = Vector3.one * s, CFrame = CFrame.new(pos) * CFrame.Angles(K.rng:NextNumber(0, 6), K.rng:NextNumber(0, 6), 0), Color = colors[K.rng:NextInteger(1, #colors)], Material = Enum.Material.Neon }, (life or 0.5) + 0.05)
		local dir = Vector3.new(K.rng:NextNumber(-1, 1), K.rng:NextNumber(-0.1, 1), K.rng:NextNumber(-1, 1)).Unit
		K.tween(c, life or 0.5, { CFrame = CFrame.new(pos + dir * (speed or 8) * K.rng:NextNumber(0.5, 1.2)) * CFrame.Angles(K.rng:NextNumber(0, 6), K.rng:NextNumber(0, 6), 0), Transparency = 1, Size = Vector3.one * s * 0.3 })
	end
end

-- touche de clavier qui s'envole en tournoyant
local function keycap(K, pos, dir, text)
	local k = K.part({ Size = Vector3.new(1.6, 0.8, 1.6), CFrame = CFrame.new(pos), Color = Color3.fromRGB(235, 238, 245) }, 0.9)
	for _, f in ipairs({ Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
		label(k, text, DARK, f)
	end
	local goal = pos + dir * 14 + Vector3.new(0, 6, 0)
	K.tween(k, 0.8, { CFrame = CFrame.new(goal) * CFrame.Angles(6, 4, 2) }, Enum.EasingStyle.Quad)
	task.delay(0.55, function()
		if k.Parent then
			K.tween(k, 0.25, { Transparency = 1 })
		end
	end)
end

-- impact d'un coup de clavier
local function keyHit(K, d, idx, text, power)
	local v, c = d.target, d.caster
	local vr, cr = K.root(v), K.root(c)
	if not vr or not cr then
		return
	end
	local pos = vr.Position + Vector3.new(0, 0.6, 0)
	local dir = (vr.Position - cr.Position)
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local side = flatCF(cr.Position, vr.Position).RightVector * (idx == 2 and 1 or -1)
	local axis = idx == 3 and Vector3.new(0, -1, 0) or side
	K.bigImpact(pos, axis, power, TEAL)
	K.sphere(pos, 7 * power, NEON, 0.18, 1)
	K.ring(CFrame.lookAt(pos, pos + (idx == 3 and dir or side)), 9 * power, WHITE, 0.25, 0.5)
	cubes(K, pos, 14, GLITCH, 0.5, 9, 0.45)
	keycap(K, pos, idx == 3 and dir or side, text)
	K.sparks(pos, 18, NEON)
	K.light(pos, NEON, 18, 5, 0.25)
	K.word(pos + Vector3.new(0, 2.5, 0), idx == 1 and "CLACK!" or (idx == 2 and "THWACK!" or "DELETE!"), 1 + power * 0.3, "Heavy")
	K.layer({ { "PunchHeavy", 1 }, { "Punch", 0.9, 1.1 }, { "PlasticHit", 1.1, 0.9 }, { S.Zap2, 0.5, 1.2 } }, pos)
	local sd = idx == 1 and 0.4 or (idx == 2 and -0.4 or 0)
	pcall(K.anim, v, { { t = 0 }, { t = 0.06, RS = { p = 0.5, r = -1.0 }, LS = { p = 0.5, r = -1.0 }, RJ = { ln = idx == 3 and 0.6 or -0.2, sd = sd, tw = -sd } }, { t = 0.3, RS = { p = 0.3, r = -0.6 }, LS = { p = 0.3, r = -0.6 }, RJ = { ln = 0.2, sd = sd * 0.5 } } })
	if K.involved(d) then
		K.impactFrames(idx == 3 and "BWB" or "BW", 0.035)
		K.shake(0.5 + power * 0.4)
		K.fov(5 * power)
	elseif K.near(pos, 60) then
		K.shake(0.3)
	end
	pcall(K.slowmo, { c, v }, 0.07)
end

------------------------------------------------------------------------
-- Séquence complète (phase "Connect")
------------------------------------------------------------------------
local function connect(K, d)
	local c, v = d.caster, d.target
	local cr, vr = K.root(c), K.root(v)
	if not cr or not vr then
		return
	end
	local basis = flatCF(cr.Position, cr.Position + (d.dir or cr.CFrame.LookVector))
	local right = basis.RightVector
	local fwd = basis.LookVector
	local mid = cr.Position + fwd * (DIST * 0.5)
	local g = K.groundPos(mid)
	local function vpos()
		local r = K.root(v)
		return r and r.Position or vr.Position
	end
	local function cpos()
		local r = K.root(c)
		return r and r.Position or cr.Position
	end

	-- 0 : rayon de scan + numérisation
	K.anim(c, A.Scan)
	K.letterbox(d, true, 0.15)
	K.shot(d, "orbit", { at = function() return vpos() end, basis = basis, angle = 160, r0 = 11, r1 = 8.5, dur = 0.5, height = 2.6, speed = 18, lookOffset = Vector3.new(0, 0.5, 0), fov = 62 })
	local hand = c:FindFirstChild("Left Arm")
	local from = hand and (hand.CFrame * CFrame.new(0, -1.5, -0.5)).Position or cr.Position
	K.beam(from, vpos(), 1.4, NEON, 0.35)
	K.beam(from, vpos(), 0.5, WHITE, 0.25)
	K.layer({ { S.Zap, 1 }, { S.Glitch, 0.9 }, { "Whoosh2", 0.7 } }, cr.Position)
	-- lignes de scan qui descendent sur la victime
	for i = 0, 3 do
		task.delay(i * 0.06, function()
			local p = vpos()
			local sl = K.part({ Size = Vector3.new(4.5, 0.15, 4.5), CFrame = CFrame.new(p + Vector3.new(0, 3, 0)), Color = NEON, Material = Enum.Material.Neon, Transparency = 0.2 }, 0.35)
			K.tween(sl, 0.3, { CFrame = CFrame.new(p - Vector3.new(0, 3, 0)), Transparency = 1 })
		end)
	end
	-- sol du cyberespace + grille + monolithes binaires
	local floor = K.track(d, K.part({ Shape = K.CYL, Size = Vector3.new(0.12, 2, 2), CFrame = CFrame.new(g + Vector3.new(0, 0.07, 0)) * K.UPRIGHT, Color = NAVY, Transparency = 0.1 }, 6))
	K.tween(floor, 0.3, { Size = Vector3.new(0.12, 30, 30) }, Enum.EasingStyle.Back)
	for i = -3, 3 do
		for _, axis in ipairs({ right, fwd }) do
			local other = axis == right and fwd or right
			local o = g + other * i * 3.6 + Vector3.new(0, 0.16, 0)
			local ln = K.track(d, K.part({ Size = Vector3.new(0.14, 0.06, 0.1), CFrame = CFrame.lookAt(o, o + axis), Color = TEAL, Material = Enum.Material.Neon, Transparency = 0.25 }, 6))
			K.tween(ln, 0.35, { Size = Vector3.new(0.14, 0.06, 26 - math.abs(i) * 3) })
		end
	end
	for i = 1, 6 do
		local a = (i / 6) * math.pi * 2 + 0.3
		local p = g + (right * math.cos(a) + fwd * math.sin(a)) * 13
		local look = CFrame.lookAt(p, Vector3.new(g.X, p.Y, g.Z))
		local m = K.track(d, K.part({ Size = Vector3.new(2.2, 10, 0.6), CFrame = look * CFrame.new(0, -5.5, 0), Color = DARK }, 6))
		label(m, (i % 2 == 0) and "0101\n1100\n0110\n1010" or "1001\n0011\n1101\n0100", NEON, Enum.NormalId.Front)
		local edge = K.track(d, K.part({ Size = Vector3.new(2.4, 0.2, 0.7), CFrame = look * CFrame.new(0, -0.4, 0), Color = NEON, Material = Enum.Material.Neon }, 6))
		K.tween(m, 0.35, { CFrame = look * CFrame.new(0, 5, 0) }, Enum.EasingStyle.Back)
		K.tween(edge, 0.35, { CFrame = look * CFrame.new(0, 10.1, 0) }, Enum.EasingStyle.Back)
	end
	K.ring(CFrame.new(g + Vector3.new(0, 0.3, 0)) * CFrame.Angles(math.pi / 2, 0, 0), 32, NEON, 0.45, 0.6)
	K.light(g + Vector3.new(0, 4, 0), NEON, 30, 3, 3)

	-- clavier géant dans les mains
	K.at(d, 0.38, function()
		local arm = c:FindFirstChild("Right Arm")
		if not arm then
			return
		end
		local base = CFrame.new(0, -1.15, -0.2)
		local kb = K.prop(d, c, "Right Arm", Vector3.new(0.45, 5.4, 1.7), base * CFrame.new(0, -2.5, 0), Color3.fromRGB(45, 48, 58))
		K.prop(d, c, "Right Arm", Vector3.new(0.5, 5.0, 0.12), base * CFrame.new(0, -2.6, -0.82), NEON, nil, Enum.Material.Neon)
		for row = 0, 2 do
			for col = 0, 4 do
				K.prop(d, c, "Right Arm", Vector3.new(0.12, 0.75, 0.38), base * CFrame.new(-0.27, -0.6 - col * 0.95, -0.5 + row * 0.5), Color3.fromRGB(230, 232, 240))
			end
		end
		if kb then
			cubes(K, kb.Position, 10, GLITCH, 0.4, 4, 0.3)
		end
		K.sound("Pickup", arm.Position, 0.8)
		K.sound(S.Glitch, arm.Position, 0.6, 1.3)
	end)

	-- 3 coups de clavier
	K.at(d, T.s1 - 0.2, function()
		K.anim(c, A.Swing1)
		K.sound("Whoosh", cpos(), 1)
		K.shot(d, "orbit", { at = function() return cpos():Lerp(vpos(), 0.55) end, basis = basis, angle = 90, radius = 9, height = 1.2, speed = -35, fov = 58 })
	end)
	K.at(d, T.s1, function()
		keyHit(K, d, 1, "ESC", 1)
	end)
	K.at(d, T.s2 - 0.18, function()
		K.anim(c, A.Swing2)
		K.sound("Whoosh2", cpos(), 0.9)
		K.shot(d, "orbit", { at = function() return cpos():Lerp(vpos(), 0.55) end, basis = basis, angle = -95, radius = 9, height = 1.6, speed = 35, fov = 58 })
	end)
	K.at(d, T.s2, function()
		keyHit(K, d, 2, "ALT", 1.1)
	end)
	K.at(d, T.s3 - 0.34, function()
		K.anim(c, A.Swing3)
		K.sound("Whoosh3", cpos(), 1)
		K.shot(d, "orbit", { at = function() return vpos() end, basis = basis, angle = 205, radius = 7, height = 8, speed = 12, fov = 60 })
	end)
	K.at(d, T.s3, function()
		keyHit(K, d, 3, "DEL", 1.35)
		K.cracks(vpos(), 6, 4)
	end)

	-- barre DELETING… + portable holographique + pluie binaire
	K.at(d, T.del, function()
		K.anim(c, A.Type)
		K.sound(S.Typing, cpos(), 1.2, 1.15)
		K.shot(d, "orbit", { at = function() return vpos() end, basis = basis, angle = 15, r0 = 9, r1 = 6.5, dur = 0.7, height = 2.5, speed = 10, lookOffset = Vector3.new(0, 1.6, 0), fov = 60 })
		local crf = K.root(c) and K.root(c).CFrame or cr.CFrame
		local hp = crf * CFrame.new(0, -0.2, -2.2)
		local lap = K.track(d, K.part({ Size = Vector3.new(2.6, 0.12, 1.6), CFrame = hp, Color = Color3.fromRGB(190, 195, 205) }, 2))
		local scr = K.track(d, K.part({ Size = Vector3.new(2.6, 1.7, 0.1), CFrame = hp * CFrame.new(0, 0.85, 0.8) * CFrame.Angles(math.rad(-15), 0, 0), Color = NAVY, Material = Enum.Material.Neon, Transparency = 0.15 }, 2))
		local term = label(scr, "C:\\> format C: /y\nDELETING...", NEON, Enum.NormalId.Back, MONO)
		term.TextXAlignment = Enum.TextXAlignment.Left
		label(scr, "C:\\> format C: /y", NEON, Enum.NormalId.Front, MONO)
		-- barre de progression au-dessus de la victime
		local vr2 = K.root(v)
		if vr2 then
			local anchor = K.track(d, K.part({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(vr2.Position + Vector3.new(0, 4.6, 0)) }, 2))
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromScale(7, 1.6)
			bb.LightInfluence = 0
			bb.Parent = anchor
			local frame = Instance.new("Frame")
			frame.Size = UDim2.fromScale(1, 0.55)
			frame.Position = UDim2.fromScale(0, 0.45)
			frame.BackgroundColor3 = NAVY
			frame.BorderSizePixel = 0
			frame.Parent = bb
			local st = Instance.new("UIStroke")
			st.Color = NEON
			st.Thickness = 3
			st.Parent = frame
			local fill = Instance.new("Frame")
			fill.Size = UDim2.fromScale(0, 1)
			fill.BackgroundColor3 = NEON
			fill.BorderSizePixel = 0
			fill.Parent = frame
			local txt = Instance.new("TextLabel")
			txt.Size = UDim2.fromScale(1, 0.42)
			txt.BackgroundTransparency = 1
			txt.FontFace = PIXEL
			txt.TextScaled = true
			txt.TextColor3 = WHITE
			txt.Text = "DELETING... 0%"
			txt.Parent = bb
			local ts = Instance.new("UIStroke")
			ts.Thickness = 2
			ts.Parent = txt
			K.tween(fill, 0.7, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
			task.spawn(function()
				local t0 = os.clock()
				while bb.Parent and os.clock() - t0 < 0.72 do
					local pct = math.floor(math.clamp((os.clock() - t0) / 0.7, 0, 1) * 100)
					txt.Text = "DELETING... " .. pct .. "%"
					term.Text = "C:\\> format C: /y\nDELETING... " .. pct .. "%"
					task.wait(0.03)
				end
				if bb.Parent then
					txt.Text = "100% DELETED"
					txt.TextColor3 = RED
					fill.BackgroundColor3 = RED
				end
			end)
		end
		-- pluie binaire
		for i = 1, 16 do
			task.delay(i * 0.045, function()
				local p = vpos() + Vector3.new(K.rng:NextNumber(-4, 4), 7, K.rng:NextNumber(-4, 4))
				local b = K.part({ Size = Vector3.new(0.25, 1.2, 0.25), CFrame = CFrame.new(p), Color = (i % 3 == 0) and WHITE or NEON, Material = Enum.Material.Neon }, 0.5)
				K.tween(b, 0.45, { CFrame = CFrame.new(p - Vector3.new(0, 9, 0)), Transparency = 0.8 }, Enum.EasingStyle.Linear)
			end)
		end
		K.implode(vpos(), 7, { NEON, WHITE, BLUE }, 14, 0.6)
	end)

	-- 4 murs .ZIP qui se referment
	local walls = {}
	K.at(d, T.walls, function()
		K.shot(d, "orbit", { at = function() return vpos() end, basis = basis, angle = 40, r0 = 10, r1 = 16, dur = 0.5, height = 6, speed = 20, fov = 62 })
		K.layer({ { S.Glitch, 1, 0.8 }, { "Windup", 0.8 }, { S.Zap2, 0.7, 0.8 } }, vpos())
		local p0 = vpos()
		for i, dir in ipairs({ fwd, -fwd, right, -right }) do
			local cf0 = CFrame.lookAt(p0 + dir * 7, p0)
			local w = K.track(d, K.part({ Size = Vector3.new(6, 7.5, 0.5), CFrame = cf0, Color = (i % 2 == 0) and TEAL or BLUE, Material = Enum.Material.Neon, Transparency = 0.45 }, 2))
			label(w, ".ZIP", WHITE, Enum.NormalId.Back)
			label(w, ".ZIP", WHITE, Enum.NormalId.Front)
			local fr = K.track(d, K.part({ Size = Vector3.new(6.4, 7.9, 0.3), CFrame = cf0 * CFrame.new(0, 0, 0.3), Color = DARK, Transparency = 0.1 }, 2))
			table.insert(walls, w)
			table.insert(walls, fr)
			K.tween(w, 0.42, { CFrame = CFrame.lookAt(p0 + dir * 1.5, p0) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			K.tween(fr, 0.42, { CFrame = CFrame.lookAt(p0 + dir * 1.5, p0) * CFrame.new(0, 0, 0.3) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		end
		K.at(d, T.walls + 0.42, function()
			K.layer({ { "Clang", 1 }, { "MetalHit", 0.9, 0.8 } }, p0)
			K.word(p0 + Vector3.new(0, 4.5, 0), "COMPRESSING!", 1.2, "Heavy")
			K.shake(0.7)
			cubes(K, p0 + Vector3.new(0, 3.5, 0), 12, GLITCH, 0.5, 6, 0.35)
		end)
		-- bond du lanceur
		K.at(d, T.slam - 0.42, function()
			K.anim(c, A.Slam)
			K.sound("Whoosh3", cpos(), 1, 0.85)
			K.sound("FinalCharge", cpos(), 0.8)
			K.afterimage(c, NEON, 0.35, 0.4)
			K.speedLines(0.4, NEON)
			K.shot(d, "fixed", { pos = g + right * 8 - fwd * 1 + Vector3.new(0, 0.9, 0), lookAt = function() return vpos() + Vector3.new(0, 1.5, 0) end, fov = 66 })
		end)
	end)

	-- marteau-poing final : PLAQUÉ au sol
	K.at(d, T.slam, function()
		local p = vpos()
		local gp = K.groundPos(p)
		for _, w in ipairs(walls) do
			if w.Parent then
				w:Destroy()
			end
		end
		local UP = CFrame.Angles(math.pi / 2, 0, 0)
		K.impactFrames("BWBWI", 0.04)
		K.flash(NEON, 0.3, 0.7)
		K.crater(gp, 10, NEON, 3.5)
		K.quake(gp, 14, TEAL, 1.5)
		K.pillar(gp, 4, 22, NEON, 0.45)
		K.sphere(p, 18, WHITE, 0.25, 2)
		K.sphere(p, 14, NEON, 0.4, 2)
		K.ring(CFrame.new(gp + Vector3.new(0, 0.4, 0)) * UP, 34, NEON, 0.5, 0.8)
		K.ring(CFrame.new(gp + Vector3.new(0, 0.6, 0)) * UP, 22, WHITE, 0.35, 0.6)
		cubes(K, p, 40, GLITCH, 0.8, 18, 0.8)
		for _ = 1, 6 do
			local a = K.rng:NextNumber(0, math.pi * 2)
			K.bolt(gp + Vector3.new(0, 0.5, 0), gp + Vector3.new(math.cos(a) * 12, K.rng:NextNumber(0.5, 6), math.sin(a) * 12), NEON, 0.35, 0.25, 1.5)
		end
		K.debris(gp, 10, { DARK, NAVY, TEAL }, 1.3, 1.2)
		K.light(gp + Vector3.new(0, 3, 0), NEON, 45, 8, 0.6)
		K.word(p + Vector3.new(0, 5, 0), "FORMATTED!", 1.8, "Heavy")
		K.layer({ { "Boom", 1.3 }, { "Bass", 1.2 }, { "Explosion", 0.9 }, { S.Glitch, 1, 0.7 }, { "GroundSlam", 1 }, { S.Zap, 0.8, 0.7, 0.1 } }, gp)
		if K.involved(d) then
			K.shake(1.8)
			K.fov(14)
			K.shot(d, "orbit", { at = gp + Vector3.new(0, 1, 0), basis = basis, angle = 120, r0 = 8, r1 = 15, dur = 0.55, height = 4, speed = 25, fov = 66 })
		elseif K.near(gp, 80) then
			K.shake(0.8)
		end
		pcall(K.slowmo, { c, v }, 0.12)
		-- le monde numérique se dissout
		task.delay(0.35, function()
			if floor.Parent then
				K.tween(floor, 0.4, { Transparency = 1, Size = Vector3.new(0.12, 34, 34) })
			end
		end)
	end)
	K.at(d, T.total - 0.25, function()
		K.letterbox(d, false, 0.25)
	end)
end

------------------------------------------------------------------------
-- Raté
------------------------------------------------------------------------
local function whiff(K, d)
	local c = d.caster
	local cr = K.root(c)
	if not cr then
		return
	end
	K.anim(c, A.Shrug)
	local dir = d.dir or cr.CFrame.LookVector
	local from = cr.Position + dir * 1.5
	local to = from + dir * 26
	K.beam(from, to, 1.2, NEON, 0.4)
	K.beam(from, to, 0.4, WHITE, 0.3)
	K.layer({ { S.Zap, 1 }, { S.Glitch, 1 } }, cr.Position)
	cubes(K, to, 18, GLITCH, 0.6, 8, 0.5)
	K.at(d, 0.2, function()
		local p = cr.Position + dir * 4 + Vector3.new(0, 2.5, 0)
		local panel = K.part({ Size = Vector3.new(5.5, 0.1, 0.2), CFrame = CFrame.lookAt(p, p - dir), Color = BSOD, Material = Enum.Material.Neon, Transparency = 0.15 }, 0.9)
		label(panel, "404\nTARGET NOT FOUND", WHITE, Enum.NormalId.Front)
		label(panel, "404\nTARGET NOT FOUND", WHITE, Enum.NormalId.Back)
		K.tween(panel, 0.12, { Size = Vector3.new(5.5, 2.6, 0.2) }, Enum.EasingStyle.Back)
		K.sound("Ding", p, 0.7, 0.6)
		task.delay(0.55, function()
			if panel.Parent then
				cubes(K, panel.Position, 14, { BSOD, WHITE }, 0.5, 5, 0.3)
				panel:Destroy()
			end
		end)
	end)
end

------------------------------------------------------------------------
return {
	Name = "FORMAT C:",
	-- v3 : titres de temps forts (UltimateController) ; Anticipate = poses d'armement avant ces coups
	Beats = { Connect = { { 0, "SCANNING..." }, { T.s1, "KEYBOARD SMASH" }, { T.del, "DELETING..." }, { T.walls, "ZIP & FORMAT" } } },
	Anticipate = { Connect = { T.s1 } },
	Desc = "Scan beam, three giant-keyboard smashes, DELETING... then .ZIP walls crush the target into the floor (PIN).",
	Color = TEAL,
	Color2 = BLUE,
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
		-- la victime est aspirée par le rayon devant le lanceur
		local cpos = cr.Position
		U.place(ctx, caster, CFrame.lookAt(cpos, cpos + look))
		local vp = U.wallSafe(cpos, cpos + look * DIST, 1.2)
		U.hold(ctx, target, CFrame.lookAt(vp, vp - look))
		U.fx(ctx, "Connect", { dir = look })
		local s = os.clock()
		local function at(t)
			return U.wait(ctx, math.max(0, s + t - os.clock()))
		end
		if not at(T.s1) then return end
		U.hit(ctx, target, 6, { words = { "CLACK!" }, power = 0.8 })
		if not at(T.s2) then return end
		U.hit(ctx, target, 6, { words = { "THWACK!" }, power = 0.9 })
		if not at(T.s3) then return end
		U.hit(ctx, target, 8, { words = { "DELETE!" }, power = 1.1 })
		if not at(T.slam) then return end
		U.finish(ctx, target, 16, { pin = true, words = { "FORMATTED!" }, splash = { radius = 11, damage = 10 } })
		at(T.total)
	end,

	Client = function(K, data)
		if data.phase == "Cutin" then
			K.anim(data.caster, A.Cast)
			local r = K.root(data.caster)
			if r then
				K.implode(r.Position, 7, { NEON, WHITE, BLUE }, 16, 0.5)
				K.sound(S.Typing, r.Position, 0.9, 1.3)
				K.at(data, 0.6, function()
					K.sound(S.Glitch, r.Position, 0.8)
					cubes(K, r.Position + Vector3.new(0, 1, 0), 16, GLITCH, 0.5, 6, 0.4)
				end)
			end
		elseif data.phase == "Connect" then
			connect(K, data)
		elseif data.phase == "Whiff" then
			whiff(K, data)
		end
	end,
}
