--[[
	Ultime de l'HR Manager : « EXIT INTERVIEW »
	Un projecteur violet tombe sur la victime : elle est téléportée sur une CHAISE de bureau, un bureau tombe entre elles.
	L'HR claque le clipboard sur le bureau, puis 3 gifles de clipboard (tampons TARDY / STOLE LUNCH / REPLY-ALL),
	déchire une lettre géante « TERMINATED » et écrase le gros bouton rouge : la chaise devient un SIÈGE ÉJECTABLE
	et la victime est propulsée droit vers le plafond (éjection verticale, explosion violette au sol).
	Raté : le projecteur éclaire une chaise vide qui tourne, « NO-SHOW ».
]]
local PURPLE = Color3.fromRGB(190, 90, 230)
local PINK = Color3.fromRGB(255, 150, 210)
local WOOD = Color3.fromRGB(140, 95, 60)
local PAPER = Color3.fromRGB(250, 250, 245)
local DARK = Color3.fromRGB(40, 40, 50)
local RED = Color3.fromRGB(225, 45, 45)
local FLAME = Color3.fromRGB(255, 140, 40)
local WHITE = Color3.new(1, 1, 1)
local MEMO = { PAPER, Color3.fromRGB(255, 240, 120), PINK, Color3.fromRGB(170, 220, 255) }

-- sons Creator Store vérifiés (ils se chargent)
local S = {
	Table = "rbxassetid://9114773735",
	Paper = "rbxassetid://9125724621",
	Paper2 = "rbxassetid://9125724895",
	Rocket = "rbxassetid://12222065",
	Stamp = "rbxassetid://9113573976",
}

-- minutage partagé serveur / client (secondes depuis la phase "Connect")
local T = { desk = 0.5, s1 = 0.85, s2 = 1.15, s3 = 1.45, rip = 1.72, button = 2.22, launch = 2.68, total = 3.4 }
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
local DIST = 5
local SEAT = 1.0 -- la victime est assise (racine abaissée)
local STAMPS = { "TARDY!", "STOLE LUNCH!", "REPLY-ALL!" }

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local A = {}
A.Cast = { -- casque : main à l'oreille, puis doigt pointé « you, my office »
	{ t = 0 },
	{ t = 0.15, LS = { p = 2.6, y = 0.3, r = 0.9 }, RS = { p = 0.5, r = -0.2 }, RJ = { sd = 0.12 } },
	{ t = 0.5, LS = { p = 2.6, y = 0.35, r = 0.95 }, RS = { p = 0.5, r = -0.2 }, RJ = { sd = 0.14 } },
	{ t = 0.65, RS = { p = 1.7, y = 0 }, LS = { p = 0.5, r = -0.3 }, RJ = { tw = 0.3, ln = -0.1 } },
	{ t = 1.1, RS = { p = 1.65 }, LS = { p = 0.5, r = -0.3 }, RJ = { tw = 0.32, ln = -0.12 } },
	{ t = 1.2 },
}
A.Point = {
	{ t = 0 },
	{ t = 0.1, RS = { p = 2.4, y = 0 }, RJ = { tw = 0.35, ln = -0.2 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
	{ t = 0.4, RS = { p = 2.35, y = 0 }, RJ = { tw = 0.3, ln = -0.18 } },
	{ t = 0.5 },
}
A.DeskSlam = { -- les deux mains (et le clipboard) claquées sur le bureau
	{ t = 0 },
	{ t = 0.14, RS = { p = 2.8, r = -0.2 }, LS = { p = 2.8, r = -0.2 }, RJ = { ln = -0.3 } },
	{ t = 0.22, RS = { p = 1.15, r = -0.25 }, LS = { p = 1.15, r = -0.25 }, RJ = { ln = 0.55 }, RH = { p = 0.4 }, LH = { p = -0.2 } },
	{ t = 0.35, RS = { p = 1.2, r = -0.25 }, LS = { p = 1.2, r = -0.25 }, RJ = { ln = 0.5 }, RH = { p = 0.35 }, LH = { p = -0.2 } },
}
local function slap(side)
	-- side = 1 : coup droit, -1 : revers ; le clipboard est dans la main GAUCHE
	return {
		{ t = 0, RJ = { ln = 0.3 } },
		{ t = 0.1, LS = { p = 1.6, y = -1.3 * side, r = -0.3 }, RS = { p = 0.6, r = -0.4 }, RJ = { tw = 0.8 * side, ln = 0.35 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
		{ t = 0.17, LS = { p = 1.65, y = 1.3 * side, r = -0.1 }, RS = { p = 0.5, r = -0.6 }, RJ = { tw = -0.85 * side, ln = 0.45 }, RH = { p = -0.3 }, LH = { p = 0.45 } },
		{ t = 0.28, LS = { p = 1.55, y = 1.2 * side }, RS = { p = 0.5, r = -0.6 }, RJ = { tw = -0.75 * side, ln = 0.4 } },
	}
end
A.Slap1, A.Slap2, A.Slap3 = slap(1), slap(-1), slap(1)
A.Rip = { -- lettre géante tenue à deux mains, déchirée en deux
	{ t = 0 },
	{ t = 0.12, RS = { p = 2.2, y = 0.5 }, LS = { p = 2.2, y = -0.5 }, RJ = { ln = -0.15 } },
	{ t = 0.3, RS = { p = 2.25, y = 0.4 }, LS = { p = 2.25, y = -0.4 }, RJ = { ln = -0.2 } },
	{ t = 0.38, RS = { p = 1.9, r = -1.2 }, LS = { p = 1.9, r = -1.2 }, RJ = { ln = -0.25 }, RH = { r = -0.2 }, LH = { r = -0.2 } },
	{ t = 0.5, RS = { p = 1.85, r = -1.25 }, LS = { p = 1.85, r = -1.25 }, RJ = { ln = -0.22 } },
}
A.Button = { -- poing levé, écrase le bouton, puis salut « bye bye »
	{ t = 0, RS = { p = 1.85, r = -1.25 }, LS = { p = 1.85, r = -1.25 } },
	{ t = 0.12, RS = { p = 3.0, r = -0.1 }, LS = { p = 0.4, r = -0.3 }, RJ = { ln = -0.3, tw = 0.2 } },
	{ t = 0.2, RS = { p = 1.0, r = -0.1 }, LS = { p = 0.4, r = -0.3 }, RJ = { ln = 0.6, tw = 0.1 }, RH = { p = 0.4 }, LH = { p = -0.2 } },
	{ t = 0.4, RS = { p = 1.05, r = -0.1 }, LS = { p = 0.4, r = -0.3 }, RJ = { ln = 0.55 } },
	{ t = 0.5, RS = { p = 0.3 }, LS = { p = 0.3 }, RJ = { ln = 0 } },
	{ t = 0.62, RS = { p = 2.6, y = 0.6, r = 0.4 }, LS = { p = 0.6, r = -0.4 }, RJ = { ln = -0.1 } },
	{ t = 0.8, RS = { p = 2.7, y = 0.3, r = 0.5 }, LS = { p = 0.6, r = -0.4 } },
	{ t = 1.0, RS = { p = 2.6, y = 0.6, r = 0.4 }, LS = { p = 0.6, r = -0.4 } },
	{ t = 1.2 },
}
A.Seated = { -- la victime assise sur la chaise
	{ t = 0 },
	{ t = 0.15, RH = { p = 1.5 }, LH = { p = 1.5 }, RS = { p = 0.7, r = -0.2 }, LS = { p = 0.7, r = -0.2 }, RJ = { ln = -0.05 } },
	{ t = 3.2, RH = { p = 1.5 }, LH = { p = 1.5 }, RS = { p = 0.7, r = -0.2 }, LS = { p = 0.7, r = -0.2 }, RJ = { ln = -0.05 } },
}
local function seatedHit(side)
	return {
		{ t = 0, RH = { p = 1.5 }, LH = { p = 1.5 }, RS = { p = 0.7 }, LS = { p = 0.7 } },
		{ t = 0.06, RH = { p = 1.6 }, LH = { p = 1.4 }, RS = { p = 0.4, r = -1.1 }, LS = { p = 0.4, r = -1.1 }, RJ = { tw = 0.5 * side, sd = 0.35 * side, ln = -0.2 } },
		{ t = 0.25, RH = { p = 1.5 }, LH = { p = 1.5 }, RS = { p = 0.6, r = -0.5 }, LS = { p = 0.6, r = -0.5 }, RJ = { tw = 0.2 * side, sd = 0.15 * side } },
		{ t = 3, RH = { p = 1.5 }, LH = { p = 1.5 }, RS = { p = 0.6, r = -0.5 }, LS = { p = 0.6, r = -0.5 }, RJ = { tw = 0.1 * side } },
	}
end

------------------------------------------------------------------------
-- Aides
------------------------------------------------------------------------
local PIXEL = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Bold)
local CARTOON = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
local RunService = game:GetService("RunService")
local UP = CFrame.Angles(math.pi / 2, 0, 0)

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

local function memos(K, pos, n, speed, life)
	for _ = 1, n do
		local m = K.part({ Size = Vector3.new(0.9, 0.05, 1.1), CFrame = CFrame.new(pos), Color = MEMO[K.rng:NextInteger(1, #MEMO)] }, (life or 0.8) + 0.05)
		local dir = Vector3.new(K.rng:NextNumber(-1, 1), K.rng:NextNumber(0, 1.2), K.rng:NextNumber(-1, 1)).Unit
		K.tween(m, life or 0.8, { CFrame = CFrame.new(pos + dir * (speed or 8) * K.rng:NextNumber(0.5, 1.2)) * CFrame.Angles(K.rng:NextNumber(-3, 3), K.rng:NextNumber(-3, 3), K.rng:NextNumber(-3, 3)), Transparency = 1 })
	end
end

-- chaise de bureau construite autour du CFrame du siège ; renvoie la liste { p, off }
local function buildChair(K, d, seatCF, life)
	local list = {}
	local function add(size, off, color, shape)
		local p = K.track(d, K.part({ Size = size, CFrame = seatCF * off, Color = color, Shape = shape or Enum.PartType.Block }, life))
		table.insert(list, { p = p, off = off })
		return p
	end
	add(Vector3.new(2.6, 0.5, 2.4), CFrame.new(0, 0, 0), PURPLE) -- assise
	add(Vector3.new(2.6, 3.0, 0.45), CFrame.new(0, 1.6, 1.15), PURPLE) -- dossier
	add(Vector3.new(2.2, 2.4, 0.2), CFrame.new(0, 1.6, 0.9), Color3.fromRGB(150, 60, 190))
	add(Vector3.new(0.7, 0.45, 0.45), CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), DARK, Enum.PartType.Cylinder) -- vérin
	for i = 0, 4 do
		add(Vector3.new(0.35, 0.25, 1.6), CFrame.new(0, -0.85, 0) * CFrame.Angles(0, i * math.pi * 2 / 5, 0) * CFrame.new(0, 0, -0.8), DARK)
	end
	return list
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
	local vp0 = d.vp or (cr.Position + fwd * DIST)
	local g = K.groundPos(vp0)
	local function vpos()
		local r = K.root(v)
		return r and r.Position or vr.Position
	end
	local function cpos()
		local r = K.root(c)
		return r and r.Position or cr.Position
	end
	K.letterbox(d, true, 0.15)
	if K.involved(d) then
		K.darken(true, 1.3, 0.2)
	end

	-- projecteur + chaise + bureau
	K.anim(c, A.Point)
	pcall(K.anim, v, A.Seated)
	K.layer({ { "Ding", 0.9, 0.7 }, { "Teleport", 0.8 }, { "Thud", 1 } }, vp0)
	local cone = K.track(d, K.part({ Shape = K.CYL, Size = Vector3.new(16, 0.5, 0.5), CFrame = CFrame.new(g + Vector3.new(0, 8, 0)) * K.UPRIGHT, Color = Color3.fromRGB(235, 200, 255), Material = Enum.Material.Neon, Transparency = 0.82 }, 6))
	K.tween(cone, 0.18, { Size = Vector3.new(16, 6.5, 6.5) }, Enum.EasingStyle.Back)
	K.track(d, K.part({ Shape = K.CYL, Size = Vector3.new(0.1, 7, 7), CFrame = CFrame.new(g + Vector3.new(0, 0.06, 0)) * K.UPRIGHT, Color = Color3.fromRGB(245, 225, 255), Material = Enum.Material.Neon, Transparency = 0.45 }, 6))
	local spotTop = g + Vector3.new(0, 16, 0)
	local lamp = K.track(d, K.part({ Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.lookAt(spotTop, g), Transparency = 1 }, 6))
	local sl = Instance.new("SpotLight")
	sl.Face = Enum.NormalId.Front
	sl.Angle = 40
	sl.Range = 24
	sl.Brightness = 6
	sl.Color = Color3.fromRGB(230, 190, 255)
	sl.Parent = lamp
	local seatCF = CFrame.lookAt(g + Vector3.new(0, 1.0, 0), g + Vector3.new(0, 1.0, 0) - fwd)
	local chair = buildChair(K, d, seatCF, 8)
	for _, e in ipairs(chair) do
		e.p.Transparency = 1
		K.tween(e.p, 0.15, { Transparency = 0 })
	end
	local deskC = cr.Position:Lerp(vp0, 0.52)
	local dg = K.groundPos(deskC)
	local deskCF = CFrame.lookAt(dg, dg + fwd)
	local desk = {}
	local function dpart(size, off, color, mat, shape)
		local p = K.track(d, K.part({ Size = size, CFrame = deskCF * off + Vector3.new(0, 12, 0), Color = color, Material = mat or Enum.Material.SmoothPlastic, Shape = shape or Enum.PartType.Block }, 8))
		table.insert(desk, { p = p, off = off })
		K.tween(p, 0.22, { CFrame = deskCF * off }, Enum.EasingStyle.Bounce)
		return p
	end
	dpart(Vector3.new(5.5, 0.35, 2.2), CFrame.new(0, 2.6, 0), WOOD)
	dpart(Vector3.new(5.3, 2.4, 0.2), CFrame.new(0, 1.3, 0.95), Color3.fromRGB(120, 80, 50))
	dpart(Vector3.new(0.3, 2.4, 2.0), CFrame.new(-2.55, 1.3, 0), Color3.fromRGB(120, 80, 50))
	dpart(Vector3.new(0.3, 2.4, 2.0), CFrame.new(2.55, 1.3, 0), Color3.fromRGB(120, 80, 50))
	local plate = dpart(Vector3.new(1.8, 0.5, 0.25), CFrame.new(-1.3, 3.05, 0.6) * CFrame.Angles(-0.4, 0, 0), Color3.fromRGB(255, 215, 40))
	label(plate, "HR", DARK, Enum.NormalId.Back)
	label(plate, "HR", DARK, Enum.NormalId.Front)
	dpart(Vector3.new(1.0, 0.5, 1.3), CFrame.new(1.4, 3.03, 0), PAPER)
	dpart(Vector3.new(0.25, 1.4, 1.4), CFrame.new(0.2, 2.82, -0.2) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(230, 200, 40), nil, Enum.PartType.Cylinder)
	local button = dpart(Vector3.new(0.5, 1.0, 1.0), CFrame.new(0.2, 2.95, -0.2) * CFrame.Angles(0, 0, math.pi / 2), RED, Enum.Material.Neon, Enum.PartType.Cylinder)
	K.at(d, 0.22, function()
		K.dust(dg, 5, nil, 8)
		K.sound("Thud", dg, 1)
		if K.involved(d) then
			K.shake(0.3)
		end
	end)
	K.shot(d, "orbit", { at = function() return deskC + Vector3.new(0, 2.5, 0) end, basis = basis, angle = 90, r0 = 14, r1 = 10, dur = 0.5, height = 3, speed = 10, fov = 60 })

	-- clipboard claqué sur le bureau
	K.at(d, T.desk - 0.22, function()
		K.anim(c, A.DeskSlam)
	end)
	K.at(d, T.desk, function()
		local top = (deskCF * CFrame.new(0, 2.8, 0)).Position
		K.layer({ { S.Table, 1.2 }, { "Thud", 1 }, { "PunchHeavy", 0.8 } }, top)
		K.word(top + Vector3.new(0, 3, 0), "SIT DOWN!", 1.2, "Heavy")
		K.ring(CFrame.new(top) * UP, 12, PURPLE, 0.3, 0.4)
		memos(K, top, 12, 7, 0.8)
		for _, e in ipairs(desk) do
			if e.p.Parent then
				K.tween(e.p, 0.06, { CFrame = deskCF * CFrame.new(0, 0.3, 0) * e.off }, Enum.EasingStyle.Quad)
				task.delay(0.07, function()
					if e.p.Parent then
						K.tween(e.p, 0.1, { CFrame = deskCF * e.off }, Enum.EasingStyle.Bounce)
					end
				end)
			end
		end
		pcall(K.anim, v, seatedHit(1))
		if K.involved(d) then
			K.impactFrames("BW", 0.035)
			K.shake(0.6)
		end
	end)

	-- 3 gifles de clipboard + tampons
	for i = 1, 3 do
		local key = "s" .. i
		K.at(d, T[key] - 0.17, function()
			K.anim(c, A["Slap" .. i])
			K.sound(i == 2 and "Whoosh2" or "Whoosh", cpos(), 0.9, 1.1)
			if i == 1 then
				K.shot(d, "orbit", { at = function() return vpos() + Vector3.new(0, 1, 0) end, basis = basis, angle = 35, radius = 7, height = 2, speed = -25, fov = 58 })
			elseif i == 3 then
				K.shot(d, "orbit", { at = function() return cpos():Lerp(vpos(), 0.6) end, basis = basis, angle = -100, radius = 8, height = 1.5, speed = 25, fov = 58 })
			end
		end)
		K.at(d, T[key], function()
			local p = vpos() + Vector3.new(0, 1.2, 0)
			local side = (i == 2) and -1 or 1
			K.bigImpact(p, right * -side, 1 + i * 0.1, PURPLE)
			K.sphere(p, 6, PINK, 0.16, 1)
			memos(K, p, 6, 6, 0.6)
			K.sparks(p, 12, PINK)
			K.layer({ { "Punch", 1.1, 1.15 }, { "PunchHeavy", 0.7 }, { S.Stamp, 1 }, { "Splat", 0.4, 1.4 } }, p)
			-- tampon rouge géant qui s'écrase dans l'air
			local stampPos = p + Vector3.new(0, 1.8, 0) + right * side * 1.5
			local st = K.part({ Size = Vector3.new(11, 3.5, 0.15), CFrame = CFrame.lookAt(stampPos, stampPos - fwd) * CFrame.Angles(0, 0, math.rad(side * 12)), Color = WHITE, Transparency = 1 }, 1)
			local l = label(st, STAMPS[i], RED, Enum.NormalId.Front, CARTOON)
			local l2 = label(st, STAMPS[i], RED, Enum.NormalId.Back, CARTOON)
			K.tween(st, 0.08, { Size = Vector3.new(5, 1.6, 0.15) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.6, function()
				K.tween(l, 0.3, { TextTransparency = 1 })
				K.tween(l2, 0.3, { TextTransparency = 1 })
			end)
			pcall(K.anim, v, seatedHit(side))
			-- la chaise pivote sous l'impact
			for _, e in ipairs(chair) do
				if e.p.Parent then
					K.tween(e.p, 0.1, { CFrame = seatCF * CFrame.Angles(0, side * 0.35, 0) * e.off })
					task.delay(0.12, function()
						if e.p.Parent and not d._launched then
							K.tween(e.p, 0.18, { CFrame = seatCF * e.off }, Enum.EasingStyle.Back)
						end
					end)
				end
			end
			if K.involved(d) then
				K.impactFrames(i == 3 and "BWB" or "BW", 0.035)
				K.shake(0.5 + i * 0.12)
				K.fov(4 + i)
			end
			pcall(K.slowmo, { c, v }, 0.06)
		end)
	end

	-- lettre de licenciement déchirée
	local letter = {}
	K.at(d, T.rip - 0.15, function()
		K.anim(c, A.Rip)
		K.shot(d, "follow", { subject = c, offset = CFrame.new(-1.5, 1.6, -6.5), lookOffset = Vector3.new(0, 2, 0), flat = true, fov = 50 })
		local p = cpos() + fwd * 1.6 + Vector3.new(0, 2.4, 0)
		for side = -1, 1, 2 do
			local pos = p + right * side * 0.8
			local half = K.track(d, K.part({ Size = Vector3.new(1.6, 0.2, 0.08), CFrame = CFrame.lookAt(pos, pos - fwd), Color = PAPER }, 3))
			label(half, side == 1 and "TERMI" or "NATED", RED, Enum.NormalId.Front, CARTOON)
			label(half, side == 1 and "NATED" or "TERMI", RED, Enum.NormalId.Back, CARTOON)
			letter[side] = half
			K.tween(half, 0.12, { Size = Vector3.new(1.6, 4.2, 0.08) }, Enum.EasingStyle.Back)
		end
		K.sound(S.Paper2, p, 0.6, 1.2)
	end)
	K.at(d, T.rip + 0.22, function()
		local p = cpos() + fwd * 1.6 + Vector3.new(0, 2.4, 0)
		K.layer({ { S.Paper, 1.3 }, { "Whoosh", 0.7, 1.3 } }, p)
		K.word(p + Vector3.new(0, 3, 0), "TERMINATED!", 1.3, "Heavy")
		memos(K, p, 10, 6, 0.7)
		for side = -1, 1, 2 do
			local half = letter[side]
			if half and half.Parent then
				K.tween(half, 0.45, { CFrame = half.CFrame * CFrame.new(side * 4, -2, 0) * CFrame.Angles(0, side * 1.2, side * 1.6), Transparency = 1 })
			end
		end
		if K.involved(d) then
			K.shake(0.4)
		end
	end)

	-- gros bouton rouge : siège éjectable
	K.at(d, T.button - 0.2, function()
		K.anim(c, A.Button)
		K.shot(d, "orbit", { at = function() return (deskCF * CFrame.new(0.2, 3, -0.2)).Position end, basis = basis, angle = 200, radius = 4.5, height = 3.5, speed = 0, fov = 55 })
	end)
	K.at(d, T.button, function()
		local bp = button.Parent and button.Position or deskC
		if button.Parent then
			K.tween(button, 0.06, { CFrame = button.CFrame - Vector3.new(0, 0.3, 0) })
		end
		K.layer({ { "UIClick", 1.4, 0.7 }, { "Alarm", 0.9 }, { "Siren", 0.5, 1.2 } }, bp)
		K.word(bp + Vector3.new(0, 2.5, 0), "CLICK!", 1, "Light")
		K.sparks(bp, 10, RED)
		K.light(bp, RED, 14, 5, 0.4)
		-- la chaise vire au rouge, flammes sous le siège
		for i, e in ipairs(chair) do
			if e.p.Parent and i <= 2 then
				K.tween(e.p, 0.2, { Color = RED })
			end
		end
		K.shot(d, "orbit", { at = function() return vpos() end, basis = basis, angle = 60, radius = 10, height = 0.5, speed = 20, fov = 62 })
		K.sound(S.Rocket, vpos(), 1, 0.9)
		K.sound("Rumble", vpos(), 1)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < T.launch - T.button do
				local base = (seatCF * CFrame.new(0, -0.9, 0)).Position
				local f = K.part({ Size = Vector3.new(0.8, 1.6, 0.8), CFrame = CFrame.new(base + Vector3.new(K.rng:NextNumber(-0.6, 0.6), 0, K.rng:NextNumber(-0.6, 0.6))) * CFrame.Angles(0, K.rng:NextNumber(0, 6), 0), Color = (K.rng:NextNumber() < 0.5) and FLAME or Color3.fromRGB(255, 220, 80), Material = Enum.Material.Neon }, 0.3)
				K.tween(f, 0.25, { CFrame = f.CFrame - Vector3.new(0, 1.2, 0), Size = Vector3.new(0.2, 0.4, 0.2), Transparency = 1 })
				K.puff(base, 0.6)
				if K.involved(d) then
					K.shake(0.15)
				end
				task.wait(0.04)
			end
		end)
	end)

	-- ÉJECTION
	K.at(d, T.launch, function()
		d._launched = true
		local p = vpos()
		local gp = K.groundPos(p)
		if K.involved(d) then
			K.impactFrames("WBWBI", 0.04)
			K.flash(PINK, 0.3, 0.6)
		end
		K.sphere(gp + Vector3.new(0, 1, 0), 16, WHITE, 0.25, 2)
		K.sphere(gp + Vector3.new(0, 1, 0), 12, FLAME, 0.45, 2)
		K.ring(CFrame.new(gp + Vector3.new(0, 0.4, 0)) * UP, 30, PURPLE, 0.5, 0.8)
		K.ring(CFrame.new(gp + Vector3.new(0, 0.6, 0)) * UP, 20, FLAME, 0.35, 0.6)
		K.crater(gp, 7, FLAME, 3)
		K.quake(gp, 12, PURPLE, 1.2)
		K.pillar(gp, 3, 30, PINK, 0.5)
		K.light(gp + Vector3.new(0, 3, 0), FLAME, 40, 8, 0.6)
		memos(K, gp + Vector3.new(0, 2, 0), 18, 14, 1)
		K.word(p + Vector3.new(0, 5, 0), "EJECTED!", 1.9, "Heavy")
		K.layer({ { "Explosion", 1.2 }, { "Boom", 1.3 }, { "Bass", 1.2 }, { S.Rocket, 1.2, 1.1 }, { "Explosion2", 0.8, 1, 0.06 } }, gp)
		-- le bureau est soufflé
		for _, e in ipairs(desk) do
			if e.p.Parent then
				K.tween(e.p, 0.7, { CFrame = e.p.CFrame * CFrame.Angles(K.rng:NextNumber(-2, 2), K.rng:NextNumber(-2, 2), K.rng:NextNumber(-2, 2)) - fwd * 10 + Vector3.new(K.rng:NextNumber(-3, 3), 7, 0), Transparency = 1 })
			end
		end
		if cone.Parent then
			K.tween(cone, 0.4, { Transparency = 1 })
		end
		K.darken(false, nil, 0.4)
		-- la chaise décolle avec la victime
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			local r = K.root(v)
			if el > 0.9 or not r or not chair[1].p.Parent then
				conn:Disconnect()
				for _, e in ipairs(chair) do
					if e.p.Parent then
						K.tween(e.p, 0.3, { Transparency = 1 })
					end
				end
				return
			end
			local q = r.Position - Vector3.new(0, SEAT, 0)
			local cf = CFrame.lookAt(q, q - fwd)
			for _, e in ipairs(chair) do
				if e.p.Parent then
					e.p.CFrame = cf * e.off
				end
			end
		end)
		-- traînée de flammes
		task.spawn(function()
			local last = vpos() - Vector3.new(0, 2, 0)
			for _ = 1, 9 do
				task.wait(0.05)
				local now = vpos() - Vector3.new(0, 2.5, 0)
				K.streak(last, now, FLAME, 1.6, 0.4)
				K.puff(now, 0.8)
				last = now
			end
		end)
		if K.involved(d) then
			K.shake(1.8)
			K.fov(14)
			K.shot(d, "track", { from = gp - fwd * 6 + right * 5 + Vector3.new(0, 1.2, 0), at = function() return vpos() end, fov = 72 })
		elseif K.near(gp, 80) then
			K.shake(0.8)
		end
		pcall(K.slowmo, { c }, 0.12)
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
	K.anim(c, A.Point)
	local dir = d.dir or cr.CFrame.LookVector
	local g = K.groundPos(cr.Position + dir * 8)
	local cone = K.part({ Shape = K.CYL, Size = Vector3.new(16, 6, 6), CFrame = CFrame.new(g + Vector3.new(0, 8, 0)) * K.UPRIGHT, Color = Color3.fromRGB(235, 200, 255), Material = Enum.Material.Neon, Transparency = 0.82 }, 0.9)
	local seatCF = CFrame.lookAt(g + Vector3.new(0, 1.0, 0), g + Vector3.new(0, 1.0, 0) - dir)
	local chair = buildChair(K, d, seatCF, 0.9)
	K.sound("Ding", g, 0.8, 0.7)
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < 0.7 do
			local el = os.clock() - t0
			for _, e in ipairs(chair) do
				if e.p.Parent then
					e.p.CFrame = seatCF * CFrame.Angles(0, el * 14, 0) * e.off
				end
			end
			task.wait()
		end
		for _, e in ipairs(chair) do
			if e.p.Parent then
				K.tween(e.p, 0.15, { Transparency = 1 })
			end
		end
		if cone.Parent then
			K.tween(cone, 0.15, { Transparency = 1 })
		end
	end)
	K.at(d, 0.25, function()
		K.word(g + Vector3.new(0, 5, 0), "NO-SHOW!", 1.1, "Light")
		K.sound("Squeak", g, 0.8)
	end)
end

return {
	Name = "Exit Interview",
	-- v3 : titres de temps forts (UltimateController) ; Anticipate = poses d'armement avant ces coups
	Beats = { Connect = { { T.desk, "TAKE A SEAT" }, { T.s1, "PERFORMANCE REVIEW" }, { T.rip, "YOU'RE FIRED" }, { T.button, "EJECT" } } },
	Desc = "Spotlight, chair and desk: a clipboard-slap interview, the TERMINATED letter is ripped and the ejector seat blasts them sky-high.",
	Color = PURPLE,
	Color2 = PINK,
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
		-- téléportée sur la chaise (racine abaissée : assise)
		local seat = vp - Vector3.new(0, SEAT, 0)
		U.hold(ctx, target, CFrame.lookAt(seat, seat - look))
		U.fx(ctx, "Connect", { dir = look, vp = vp })
		local s = os.clock()
		local function at(t)
			return U.wait(ctx, math.max(0, s + t - os.clock()))
		end
		if not at(T.desk) then return end
		U.hit(ctx, target, 4, { words = { "SIT DOWN!" }, power = 0.6 })
		for i = 1, 3 do
			if not at(T["s" .. i]) then return end
			U.hit(ctx, target, i == 3 and 5 or 4, { words = { STAMPS[i] }, power = 0.7 + i * 0.1 })
		end
		if not at(T.button + 0.2) then return end
		-- le siège tremble et monte un peu avant l'éjection
		U.glide(ctx, target, CFrame.lookAt(seat + Vector3.new(0, 0.6, 0), seat + Vector3.new(0, 0.6, 0) - look), T.launch - T.button - 0.2, "In")
		if not at(T.launch) then return end
		U.finish(ctx, target, 15, { launch = Vector3.new(0, 135, 0) + look * 6, words = { "EJECTED!" }, splash = { radius = 11, damage = 10, center = vp } })
		at(T.total)
	end,

	Client = function(K, data)
		if data.phase == "Cutin" then
			K.anim(data.caster, A.Cast)
			local r = K.root(data.caster)
			if r then
				K.sound("Ding", r.Position, 0.7, 1.2)
				K.at(data, 0.6, function()
					memos(K, r.Position + Vector3.new(0, 1.5, 0), 8, 5, 0.6)
					K.sound(S.Paper2, r.Position, 0.5, 1.3)
				end)
			end
		elseif data.phase == "Connect" then
			connect(K, data)
		elseif data.phase == "Whiff" then
			whiff(K, data)
		end
	end,
}
