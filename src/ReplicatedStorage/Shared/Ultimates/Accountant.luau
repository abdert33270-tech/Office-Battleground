--[[
	Ultime de l'Accountant : « TAX SEASON »
	Ruée facture en main : il colle une FACTURE sur la victime, le ruban de caisse l'enroule et la ligote, puis 4 coups de plus en plus chers
	(l'étiquette LCD au-dessus d'elle grimpe : $100 -> $1,000 -> $100,000 -> $1,000,000) : direct à la calculatrice,
	crochet, coup de pied retourné, double uppercut qui l'envoie en l'air. Il bondit au-dessus d'elle et l'écrase au sol
	avec une calculatrice géante : PLAQUÉE (cratère doré, fontaine de pièces, ticket « TOTAL DUE » géant).
	Raté : la facture vole dans le vide et retombe, « NO FUNDS ».
]]
local GREEN = Color3.fromRGB(90, 200, 90)
local LCD = Color3.fromRGB(175, 205, 150)
local LCDDARK = Color3.fromRGB(40, 60, 35)
local PAPER = Color3.fromRGB(250, 250, 245)
local RED = Color3.fromRGB(220, 40, 40)
local GOLD = Color3.fromRGB(255, 205, 50)
local CALC = Color3.fromRGB(80, 90, 110)
local WHITE = Color3.new(1, 1, 1)

-- sons Creator Store vérifiés (ils se chargent)
local S = {
	Register = "rbxassetid://120891770644830",
	Coins = "rbxassetid://9113849583",
	Paper = "rbxassetid://9125724621",
	Bell = "rbxassetid://128317117113671",
}

-- minutage partagé serveur / client (secondes depuis la phase "Connect")
local T = { slap = 0.12, h1 = 0.62, h2 = 0.98, h3 = 1.34, h4 = 1.72, leap = 1.98, spike = 2.6, total = 3.3 }
local PRICES = { "$100", "$1,000", "$100,000", "$1,000,000" }
local LIFT = 9 -- hauteur de la victime après l'uppercut
local DIST = 4.5

------------------------------------------------------------------------
-- Animations
------------------------------------------------------------------------
local A = {}
A.Cast = { -- lèche son doigt, sort la facture, sourire
	{ t = 0 },
	{ t = 0.15, RS = { p = 2.5, y = 0.6, r = 0.4 }, LS = { p = 1.2, y = 0.6 }, RJ = { ln = 0.1 } },
	{ t = 0.4, RS = { p = 2.6, y = 0.7, r = 0.45 }, LS = { p = 1.2, y = 0.6 }, RJ = { ln = 0.12 } },
	{ t = 0.6, RS = { p = 1.0, y = -0.8, r = -0.6 }, LS = { p = 1.3, y = 0.6 }, RJ = { tw = -0.4 } },
	{ t = 1.0, RS = { p = 1.0, y = -0.8, r = -0.6 }, LS = { p = 1.3, y = 0.6 }, RJ = { tw = -0.45 } },
	{ t = 1.2 },
}
A.Slap = { -- plaque la facture sur la poitrine
	{ t = 0, RS = { p = 1.0, y = -0.8, r = -0.6 }, RJ = { tw = -0.45 } },
	{ t = 0.1, RS = { p = 1.65, y = 0.2 }, RJ = { tw = 0.4, ln = 0.2 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
	{ t = 0.4, RS = { p = 1.6, y = 0.2 }, RJ = { tw = 0.35, ln = 0.18 }, RH = { p = -0.3 }, LH = { p = 0.45 } },
}
A.Jab = { -- direct de la calculatrice (main gauche)
	{ t = 0 },
	{ t = 0.08, LS = { p = 1.1, y = 0.4 }, RS = { p = 1.0, y = -0.5 }, RJ = { tw = 0.35, ln = 0.05 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
	{ t = 0.14, LS = { p = 1.7, y = 0 }, RS = { p = 0.9, y = -0.6 }, RJ = { tw = -0.55, ln = 0.25 }, RH = { p = -0.35 }, LH = { p = 0.55 } },
	{ t = 0.3, LS = { p = 1.6 }, RS = { p = 0.9, y = -0.6 }, RJ = { tw = -0.5, ln = 0.22 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
}
A.Hook = { -- crochet du droit
	{ t = 0, LS = { p = 1.6 }, RJ = { tw = -0.5, ln = 0.22 } },
	{ t = 0.1, RS = { p = 1.4, y = -1.3, r = -0.7 }, LS = { p = 1.0, y = 0.6 }, RJ = { tw = -0.85, ln = 0.1 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
	{ t = 0.18, RS = { p = 1.5, y = 1.3, r = -0.2 }, LS = { p = 0.6, y = 0.8 }, RJ = { tw = 0.9, ln = 0.3 }, RH = { p = -0.4 }, LH = { p = 0.55 } },
	{ t = 0.34, RS = { p = 1.4, y = 1.2 }, LS = { p = 0.6, y = 0.8 }, RJ = { tw = 0.8, ln = 0.25 } },
}
A.Kick = { -- coup de pied retourné (buste vrillé, jambe droite haute)
	{ t = 0, RS = { p = 1.4, y = 1.2 }, RJ = { tw = 0.8, ln = 0.25 } },
	{ t = 0.12, RS = { p = 0.6, r = -1.3 }, LS = { p = 0.6, r = -1.3 }, RJ = { tw = 1.5, ln = -0.1, sd = 0.2 }, RH = { p = 0.4 }, LH = { p = -0.2 } },
	{ t = 0.2, RS = { p = 0.9, r = -1.5 }, LS = { p = 0.9, r = -1.5 }, RJ = { tw = -1.2, ln = -0.35, sd = -0.4 }, RH = { p = 1.9, r = -0.4 }, LH = { p = -0.3 } },
	{ t = 0.34, RS = { p = 0.8, r = -1.4 }, LS = { p = 0.8, r = -1.4 }, RJ = { tw = -1.0, ln = -0.3, sd = -0.35 }, RH = { p = 1.7, r = -0.35 }, LH = { p = -0.25 } },
}
A.Uppercut = { -- accroupi, double uppercut vers le ciel
	{ t = 0 },
	{ t = 0.12, RS = { p = 0.2, r = -0.3 }, LS = { p = 0.2, r = -0.3 }, RJ = { ln = 0.65 }, RH = { p = 0.9 }, LH = { p = 0.9 } },
	{ t = 0.2, RS = { p = 3.1, r = 0.15 }, LS = { p = 3.1, r = 0.15 }, RJ = { ln = -0.45 }, RH = { p = -0.2 }, LH = { p = 0.5 } },
	{ t = 0.4, RS = { p = 3.0, r = 0.15 }, LS = { p = 3.0, r = 0.15 }, RJ = { ln = -0.4 }, RH = { p = -0.15 }, LH = { p = 0.4 } },
}
A.Leap = { -- saut groupé, calculatrice géante levée à deux mains, smash
	{ t = 0, RS = { p = 3.0 }, LS = { p = 3.0 }, RJ = { ln = -0.4 } },
	{ t = 0.2, RS = { p = 2.9, r = 0.3 }, LS = { p = 2.9, r = 0.3 }, RJ = { ln = -0.2 }, RH = { p = 1.4 }, LH = { p = 1.4 } },
	{ t = 0.45, RS = { p = 3.3, r = 0.25 }, LS = { p = 3.3, r = 0.25 }, RJ = { ln = -0.65 }, RH = { p = 0.8 }, LH = { p = 1.2 } },
	{ t = 0.58, RS = { p = 3.35, r = 0.25 }, LS = { p = 3.35, r = 0.25 }, RJ = { ln = -0.7 }, RH = { p = 0.7 }, LH = { p = 1.1 } },
	{ t = 0.66, RS = { p = 0.7, r = 0.25 }, LS = { p = 0.7, r = 0.25 }, RJ = { ln = 1.0 }, RH = { p = 1.2 }, LH = { p = -0.6 } },
	{ t = 1.1, RS = { p = 0.75, r = 0.25 }, LS = { p = 0.75, r = 0.25 }, RJ = { ln = 0.9 }, RH = { p = 1.1 }, LH = { p = -0.5 } },
	{ t = 1.3 },
}
A.Dash = { -- ruée penchée, facture tendue
	{ t = 0 },
	{ t = 0.08, RS = { p = 1.6, y = 0.2 }, LS = { p = -0.6, r = -0.2 }, RJ = { ln = 0.55, tw = 0.2 }, RH = { p = -0.7 }, LH = { p = 0.8 } },
	{ t = 0.4, RS = { p = 1.6, y = 0.2 }, LS = { p = -0.6, r = -0.2 }, RJ = { ln = 0.5, tw = 0.2 }, RH = { p = -0.6 }, LH = { p = 0.7 } },
}
A.Throw = { -- raté : lance la facture
	{ t = 0 },
	{ t = 0.1, RS = { p = 2.6, y = -0.4 }, RJ = { tw = -0.4, ln = -0.15 }, LH = { p = 0.3 } },
	{ t = 0.18, RS = { p = 1.3, y = 0.3 }, RJ = { tw = 0.45, ln = 0.25 }, RH = { p = -0.3 }, LH = { p = 0.5 } },
	{ t = 0.5, RS = { p = 0.4, r = -0.8 }, LS = { p = 0.4, r = -0.8 }, RJ = { sd = -0.15 } },
	{ t = 0.85 },
}

------------------------------------------------------------------------
-- Aides
------------------------------------------------------------------------
local PIXEL = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Bold)
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local RunService = game:GetService("RunService")

local function flatCF(from, to)
	local d = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if d.Magnitude < 0.05 then
		d = Vector3.new(0, 0, -1)
	end
	return CFrame.lookAt(from, from + d.Unit)
end

-- repère dont le LookVector = n (gère la verticale)
local function facingCF(p, n)
	if math.abs(n.Unit.Y) > 0.98 then
		return CFrame.new(p) * CFrame.Angles(n.Y > 0 and math.pi / 2 or -math.pi / 2, 0, 0)
	end
	return CFrame.lookAt(p, p + n)
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

-- pièces d'or qui jaillissent en arc
local function coins(K, pos, n, power, life)
	for _ = 1, n do
		local c = K.part({ Shape = K.CYL, Size = Vector3.new(0.18, 0.9, 0.9), CFrame = CFrame.new(pos), Color = GOLD, Material = Enum.Material.Neon }, (life or 0.8) + 0.05)
		local out = Vector3.new(K.rng:NextNumber(-1, 1), 0, K.rng:NextNumber(-1, 1))
		out = out.Magnitude > 0.05 and out.Unit or Vector3.new(1, 0, 0)
		local apex = pos + out * K.rng:NextNumber(2, 6) * power + Vector3.new(0, K.rng:NextNumber(4, 9) * power, 0)
		local land = pos + out * K.rng:NextNumber(5, 11) * power - Vector3.new(0, 2.5, 0)
		local l = life or 0.8
		K.tween(c, l * 0.45, { CFrame = CFrame.new(apex) * CFrame.Angles(K.rng:NextNumber(0, 6), K.rng:NextNumber(0, 6), 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(l * 0.45, function()
			if c.Parent then
				K.tween(c, l * 0.55, { CFrame = CFrame.new(land) * CFrame.Angles(K.rng:NextNumber(0, 6), 0, 0), Transparency = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end)
	end
end

-- chiffres LCD qui s'envolent
local function digits(K, pos, n)
	local D = { "$", "+", "%", "=", "7", "9", "x" }
	for _ = 1, n do
		local p = pos + Vector3.new(K.rng:NextNumber(-2, 2), K.rng:NextNumber(-0.5, 1.5), K.rng:NextNumber(-2, 2))
		local b = K.part({ Size = Vector3.new(1.2, 1.2, 0.1), CFrame = CFrame.new(p), Color = LCD, Transparency = 1 }, 0.7)
		local l1 = label(b, D[K.rng:NextInteger(1, #D)], GREEN, Enum.NormalId.Front)
		local l2 = label(b, l1.Text, GREEN, Enum.NormalId.Back)
		local st = Instance.new("UIStroke")
		st.Thickness = 2
		st.Parent = l1
		K.tween(b, 0.6, { CFrame = CFrame.new(p + Vector3.new(K.rng:NextNumber(-3, 3), 3.5, K.rng:NextNumber(-3, 3))) * CFrame.Angles(0, K.rng:NextNumber(-2, 2), 0) })
		task.delay(0.35, function()
			K.tween(l1, 0.3, { TextTransparency = 1 })
			K.tween(l2, 0.3, { TextTransparency = 1 })
			K.tween(st, 0.3, { Transparency = 1 })
		end)
	end
end

local function money(n)
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	s = s:gsub("^,", "")
	return "$" .. s
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
	local basis = flatCF(cr.Position, cr.Position + (d.dir or cr.CFrame.LookVector))
	local right, fwd = basis.RightVector, basis.LookVector
	local g = K.groundPos(vr.Position)
	local function vpos()
		local r = K.root(v)
		return r and r.Position or vr.Position
	end
	local function cpos()
		local r = K.root(c)
		return r and r.Position or cr.Position
	end
	K.letterbox(d, true, 0.15)

	-- facture plaquée
	K.anim(c, A.Slap)
	K.shot(d, "orbit", { at = function() return cpos():Lerp(vpos(), 0.5) end, basis = basis, angle = 100, r0 = 10, r1 = 8, dur = 0.5, height = 1.8, speed = 15, fov = 60 })
	K.at(d, T.slap, function()
		local inv = K.prop(d, v, "Torso", Vector3.new(1.5, 1.9, 0.08), CFrame.new(0, 0, -0.56) * CFrame.Angles(0, 0, 0.15), PAPER)
		if inv then
			local l = label(inv, "INVOICE\n$$$", RED, Enum.NormalId.Front)
			l.TextYAlignment = Enum.TextYAlignment.Top
			label(inv, "INVOICE\n$$$", RED, Enum.NormalId.Back)
		end
		local p = vpos()
		K.layer({ { "Splat", 0.8, 1.3 }, { "Punch", 1 }, { S.Paper, 0.8, 1.2 } }, p)
		K.word(p + Vector3.new(0, 3, 0), "BILLED!", 1.1, "Heavy")
		K.sparks(p, 12, GOLD)
		-- ruban de caisse qui s'enroule (3 anneaux de segments qui se resserrent puis suivent la victime)
		local segs = {}
		for h = 0, 2 do
			for i = 1, 8 do
				local a = (i / 8) * math.pi * 2 + h * 0.4
				local y = -1.2 + h * 1.3
				local seg = K.track(d, K.part({ Size = Vector3.new(1.3, 0.55, 0.08), Color = PAPER, CFrame = CFrame.new(p) }, 5))
				local function place(r, rot)
					local aa = a + rot
					local q = vpos()
					local pp = q + Vector3.new(math.cos(aa) * r, y, math.sin(aa) * r)
					return CFrame.lookAt(pp, q + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, 0.25)
				end
				seg.CFrame = place(5, -1.5)
				K.tween(seg, 0.35, { CFrame = place(1.25, 0) }, Enum.EasingStyle.Back)
				table.insert(segs, { seg = seg, place = place })
			end
		end
		task.delay(0.36, function()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				if not segs[1].seg.Parent or not v.Parent then
					conn:Disconnect()
					return
				end
				for _, e in ipairs(segs) do
					if e.seg.Parent then
						e.seg.CFrame = e.place(1.25, 0)
					end
				end
			end)
		end)
		K.sound(S.Paper, p, 1, 0.9)
		-- étiquette LCD au-dessus de la victime
		local anchor = K.track(d, K.part({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(p + Vector3.new(0, 4.4, 0)) }, 5))
		local bb = Instance.new("BillboardGui")
		bb.Name = "TaxTag"
		bb.Size = UDim2.fromScale(7, 1.8)
		bb.LightInfluence = 0
		bb.Parent = anchor
		local fr = Instance.new("Frame")
		fr.Size = UDim2.fromScale(1, 1)
		fr.BackgroundColor3 = LCD
		fr.BorderSizePixel = 0
		fr.Parent = bb
		local st = Instance.new("UIStroke")
		st.Thickness = 4
		st.Color = CALC
		st.Parent = fr
		local tl = Instance.new("TextLabel")
		tl.Name = "Amount"
		tl.Size = UDim2.fromScale(0.94, 0.8)
		tl.Position = UDim2.fromScale(0.03, 0.1)
		tl.BackgroundTransparency = 1
		tl.FontFace = PIXEL
		tl.TextScaled = true
		tl.TextColor3 = LCDDARK
		tl.TextXAlignment = Enum.TextXAlignment.Right
		tl.Text = "$0"
		tl.Parent = fr
		d._tag, d._tagAnchor, d._tagFrame = tl, anchor, fr
		local conn
		conn = RunService.RenderStepped:Connect(function()
			if not anchor.Parent then
				conn:Disconnect()
				return
			end
			anchor.CFrame = CFrame.new(vpos() + Vector3.new(0, 4.4, 0))
		end)
	end)

	-- 4 coups de plus en plus chers
	local VALUES = { 100, 1000, 100000, 1000000 }
	local function priced(i, power, word, dirv, anim)
		K.at(d, T["h" .. i] - (i == 4 and 0.2 or 0.14), function()
			K.anim(c, anim)
			K.sound(i % 2 == 0 and "Whoosh2" or "Whoosh", cpos(), 0.9)
		end)
		K.at(d, T["h" .. i], function()
			local p = vpos() + Vector3.new(0, 0.5, 0)
			K.bigImpact(p, dirv(), power, GOLD)
			K.sphere(p, 6 * power, GOLD, 0.18, 1)
			K.ring(facingCF(p, dirv()), 8 * power, WHITE, 0.25, 0.4)
			digits(K, p, 5 + i)
			coins(K, p, 4 + i * 2, 0.8 + i * 0.15, 0.8)
			K.light(p, GOLD, 16, 4, 0.2)
			K.word(p + Vector3.new(0, 2.5, 0), word, 0.9 + i * 0.2, "Heavy")
			K.layer({ { i == 4 and "Uppercut" or "PunchHeavy", 1 }, { "Punch2", 0.8 }, { S.Register, i == 4 and 1 or 0.45, 1 + (4 - i) * 0.08 } }, p)
			if i == 4 then
				K.sound(S.Coins, p, 1)
			end
			local tl = d._tag
			if tl and tl.Parent then
				task.spawn(function()
					local from = i == 1 and 0 or VALUES[i - 1]
					local to = VALUES[i]
					for k = 1, 6 do
						if not tl.Parent then
							return
						end
						tl.Text = money(from + (to - from) * (k / 6))
						task.wait(0.025)
					end
					tl.Text = PRICES[i]
					if i == 4 and d._tagFrame then
						d._tagFrame.BackgroundColor3 = RED
						tl.TextColor3 = WHITE
					end
				end)
			end
			pcall(K.anim, v, { { t = 0 }, { t = 0.06, RS = { p = 0.4, r = -0.9 }, LS = { p = 0.4, r = -0.9 }, RJ = { ln = -0.3, sd = (i % 2 == 0) and -0.35 or 0.35 } }, { t = 0.3, RJ = { ln = -0.1, sd = (i % 2 == 0) and -0.15 or 0.15 } } })
			if K.involved(d) then
				K.impactFrames(i >= 3 and "BWB" or "BW", 0.035)
				K.shake(0.4 + i * 0.15)
				K.fov(3 + i * 1.5)
			end
			pcall(K.slowmo, { c, v }, 0.06)
		end)
	end
	priced(1, 0.8, "+$100!", function() return fwd end, A.Jab)
	priced(2, 0.95, "+$1,000!", function() return right end, A.Hook)
	priced(3, 1.1, "+$100,000!", function() return -right end, A.Kick)
	priced(4, 1.3, "+$1,000,000!", function() return Vector3.new(0, 1, 0) end, A.Uppercut)
	K.at(d, T.h1 - 0.14, function()
		K.shot(d, "orbit", { at = function() return cpos():Lerp(vpos(), 0.5) end, basis = basis, angle = -80, radius = 8.5, height = 1.5, speed = 30, fov = 58 })
	end)
	K.at(d, T.h3 - 0.14, function()
		K.shot(d, "orbit", { at = function() return vpos() end, basis = basis, angle = 30, radius = 7.5, height = 2.2, speed = -40, fov = 58 })
	end)
	K.at(d, T.h4, function()
		K.shot(d, "track", { from = g - fwd * 5 + right * 7 + Vector3.new(0, 1.2, 0), at = function() return vpos() end, fov = 64 })
		-- traînée verticale de l'uppercut
		local p = vpos()
		K.streak(p, p + Vector3.new(0, (d.lift or LIFT) + 2, 0), GOLD, 1.2, 0.35)
		K.pillar(p, 2, 14, GOLD, 0.35)
	end)

	-- bond au-dessus de la victime + calculatrice géante
	K.at(d, T.leap, function()
		K.anim(c, A.Leap)
		K.layer({ { "Whoosh3", 1 }, { "FinalCharge", 0.8 }, { S.Bell, 0.5, 1.4 } }, cpos())
		K.speedLines(0.5, GOLD)
		local base = CFrame.new(0, -1.1, -0.1)
		local big = K.prop(d, c, "Right Arm", Vector3.new(0.8, 4.2, 3.2), base * CFrame.new(0, -1.9, -0.6), CALC)
		if big then
			K.prop(d, c, "Right Arm", Vector3.new(0.85, 1.0, 2.6), base * CFrame.new(0, -0.6, -0.6), LCD)
			for row = 0, 2 do
				for col = 0, 2 do
					K.prop(d, c, "Right Arm", Vector3.new(0.9, 0.6, 0.6), base * CFrame.new(0, -1.6 - row * 0.85, -1.5 + col * 0.9), (row == 2 and col == 2) and Color3.fromRGB(255, 150, 40) or Color3.fromRGB(225, 225, 230))
				end
			end
			local gl = K.prop(d, c, "Right Arm", Vector3.new(0.9, 0.9, 2.2), base * CFrame.new(0, -0.6, -0.6), Color3.fromRGB(120, 255, 140), nil, Enum.Material.Neon)
			if gl then
				gl.Transparency = 0
				label(gl, "TOTAL", LCDDARK, Enum.NormalId.Left)
				label(gl, "TOTAL", LCDDARK, Enum.NormalId.Right)
			end
			K.sparks(big.Position, 16, GOLD)
		end
		K.shot(d, "fixed", { pos = g + right * 9 - fwd * 2 + Vector3.new(0, 2, 0), lookAt = function() return vpos() + Vector3.new(0, 2, 0) end, fov = 70 })
		task.spawn(function()
			for _ = 1, 4 do
				task.wait(0.08)
				K.afterimage(c, GOLD, 0.3, 0.45)
			end
		end)
	end)

	-- smash : PLAQUÉE au sol
	K.at(d, T.spike - 0.06, function()
		K.streak(vpos() + Vector3.new(0, 4, 0), g, GOLD, 2.2, 0.25)
	end)
	K.at(d, T.spike, function()
		local p = vpos()
		local gp = K.groundPos(p)
		local UP = CFrame.Angles(math.pi / 2, 0, 0)
		K.impactFrames("BWRWB", 0.04)
		K.flash(GOLD, 0.3, 0.6)
		K.crater(gp, 10, GOLD, 3.5)
		K.quake(gp, 14, GOLD, 1.5)
		K.sphere(gp + Vector3.new(0, 1, 0), 16, WHITE, 0.25, 2)
		K.sphere(gp + Vector3.new(0, 1, 0), 12, GOLD, 0.45, 2)
		K.ring(CFrame.new(gp + Vector3.new(0, 0.4, 0)) * UP, 34, GOLD, 0.5, 0.8)
		K.ring(CFrame.new(gp + Vector3.new(0, 0.6, 0)) * UP, 22, WHITE, 0.35, 0.6)
		coins(K, gp + Vector3.new(0, 1, 0), 30, 1.6, 1.1)
		K.debris(gp, 10, nil, 1.3, 1.2)
		K.light(gp + Vector3.new(0, 3, 0), GOLD, 45, 8, 0.6)
		K.word(p + Vector3.new(0, 5, 0), "PAID IN FULL!", 1.8, "Heavy")
		K.layer({ { "Boom", 1.3 }, { "Bass", 1.2 }, { "GroundSlam", 1 }, { S.Register, 1.1, 0.9, 0.08 }, { S.Coins, 1, 1, 0.15 }, { "Explosion2", 0.8 } }, gp)
		-- ticket de caisse géant qui sort du sol derrière la victime
		local back = gp + fwd * 4.5
		local rcf = CFrame.lookAt(back, back - fwd)
		local r = K.track(d, K.part({ Size = Vector3.new(4, 0.2, 0.15), CFrame = rcf, Color = PAPER }, 3))
		local l = label(r, "TAX SEASON\n------\nSALARY  $0\nFEES   $999\n------\nTOTAL DUE\n$9,999,999", Color3.fromRGB(40, 40, 40), Enum.NormalId.Front, MONO)
		l.TextYAlignment = Enum.TextYAlignment.Top
		label(r, "$$$", RED, Enum.NormalId.Back)
		K.tween(r, 0.35, { Size = Vector3.new(4, 9, 0.15), CFrame = rcf * CFrame.new(0, 4.5, 0) }, Enum.EasingStyle.Back)
		task.delay(1.3, function()
			if r.Parent then
				K.tween(r, 0.3, { Transparency = 1 })
				K.tween(l, 0.3, { TextTransparency = 1 })
			end
		end)
		if d._tagAnchor and d._tagAnchor.Parent then
			digits(K, d._tagAnchor.Position, 8)
			d._tagAnchor:Destroy()
		end
		if K.involved(d) then
			K.shake(1.8)
			K.fov(14)
			K.shot(d, "orbit", { at = gp + Vector3.new(0, 1, 0), basis = basis, angle = 150, r0 = 8, r1 = 15, dur = 0.6, height = 4.5, speed = 22, fov = 66 })
		elseif K.near(gp, 80) then
			K.shake(0.8)
		end
		pcall(K.slowmo, { c, v }, 0.12)
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
	K.anim(c, A.Throw)
	local dir = d.dir or cr.CFrame.LookVector
	K.sound("Throw", cr.Position, 1)
	local p0 = cr.Position + dir * 1.5 + Vector3.new(0, 1, 0)
	local inv = K.part({ Size = Vector3.new(1.5, 1.9, 0.08), CFrame = CFrame.lookAt(p0, p0 + dir), Color = PAPER }, 1)
	label(inv, "INVOICE", RED, Enum.NormalId.Front)
	label(inv, "INVOICE", RED, Enum.NormalId.Back)
	local p1 = p0 + dir * 16 + Vector3.new(0, 1.5, 0)
	K.tween(inv, 0.35, { CFrame = CFrame.lookAt(p1, p1 + dir) * CFrame.Angles(0, 0, 3) }, Enum.EasingStyle.Quad)
	task.delay(0.35, function()
		if inv.Parent then
			K.tween(inv, 0.5, { CFrame = CFrame.new(p1 + dir * 2 - Vector3.new(0, 3, 0)) * CFrame.Angles(1.5, 0.6, 0.3), Transparency = 0.5 }, Enum.EasingStyle.Sine)
		end
	end)
	K.at(d, 0.3, function()
		local p = cr.Position + dir * 4 + Vector3.new(0, 3, 0)
		K.word(p, "NO FUNDS!", 1.1, "Light")
		K.sound("Ding", p, 0.6, 0.5)
		K.sound(S.Coins, p, 0.5, 1.3)
		coins(K, cr.Position + dir * 2, 3, 0.5, 0.6)
	end)
end

return {
	Name = "Tax Season",
	Desc = "Bill them, bind them in receipt tape, 4 ever-pricier hits, then spike them into the floor with a giant calculator (PIN).",
	Color = GREEN,
	Color2 = GOLD,
	Range = 25,
	Angle = 70,
	T = T,

	Server = function(U, caster, target, ctx)
		local cr = U.root(caster)
		if not cr then
			return
		end
		-- ruée « facture en main » jusqu'à la cible
		U.fx(ctx, "Dash")
		if not U.rush(ctx, target, { speed = 130, contact = DIST, maxTime = 0.4 }) then
			U.fx(ctx, "Whiff", { dir = U.flat(cr.CFrame.LookVector) })
			U.wait(ctx, 0.9)
			return
		end
		local tr = U.root(target)
		if not tr or not U.valid(target, ctx) then
			return
		end
		cr = U.root(caster)
		local look = U.flat(tr.Position - cr.Position, cr.CFrame.LookVector)
		local cpos = cr.Position
		local vp = U.wallSafe(cpos, cpos + look * DIST, 1)
		U.place(ctx, caster, CFrame.lookAt(cpos, cpos + look))
		U.hold(ctx, target, CFrame.lookAt(vp, vp - look))
		local lift = math.clamp(U.headroom(vp, LIFT + 4) - 1, 3, LIFT)
		U.fx(ctx, "Connect", { dir = look, lift = lift })
		local s = os.clock()
		local function at(t)
			return U.wait(ctx, math.max(0, s + t - os.clock()))
		end
		-- dégâts de base réduits : le passif Compound Interest ajoute +10 % par coup (x1.0 -> x1.4) => ~34 au total
		if not at(T.h1) then return end
		U.hit(ctx, target, 3, { words = { "+$100!" }, power = 0.6 })
		if not at(T.h2) then return end
		U.hit(ctx, target, 4, { words = { "+$1,000!" }, power = 0.75 })
		if not at(T.h3) then return end
		U.hit(ctx, target, 5, { words = { "+$100,000!" }, power = 0.9 })
		if not at(T.h4) then return end
		U.hit(ctx, target, 5, { words = { "+$1,000,000!" }, power = 1.0 })
		U.glide(ctx, target, CFrame.lookAt(vp + Vector3.new(0, lift, 0), vp + Vector3.new(0, lift, 0) - look), 0.3, "Out")
		if not at(T.leap) then return end
		local apex = vp - look * 1.6 + Vector3.new(0, lift + 3.5, 0)
		U.glide(ctx, caster, CFrame.lookAt(apex, apex + look), 0.45, "Out")
		if not at(T.spike - 0.1) then return end
		U.glide(ctx, target, CFrame.lookAt(vp, vp - look), 0.1, "In")
		local land = U.wallSafe(vp, vp - look * 2.6, 1)
		U.glide(ctx, caster, CFrame.lookAt(land, land + look), 0.1, "In")
		if not at(T.spike) then return end
		U.finish(ctx, target, 10, { pin = true, words = { "PAID IN FULL!" }, splash = { radius = 11, damage = 10, center = vp } })
		at(T.total)
	end,

	Client = function(K, data)
		if data.phase == "Cutin" then
			K.anim(data.caster, A.Cast)
			local r = K.root(data.caster)
			if r then
				K.sound(S.Register, r.Position, 0.8)
				K.at(data, 0.5, function()
					digits(K, r.Position + Vector3.new(0, 1.5, 0), 8)
					K.sound(S.Paper, r.Position, 0.6, 1.3)
				end)
			end
		elseif data.phase == "Dash" then
			local c = data.caster
			local r = K.root(c)
			K.anim(c, A.Dash)
			K.layer({ { "Dash", 1 }, { "Whoosh2", 0.8 }, { S.Paper, 0.5, 1.4 } }, r and r.Position)
			if K.isCaster(data) then
				K.speedLines(0.35, GOLD)
			end
			task.spawn(function()
				for _ = 1, 5 do
					K.afterimage(c, GOLD, 0.3, 0.5)
					task.wait(0.06)
				end
			end)
		elseif data.phase == "Connect" then
			connect(K, data)
		elseif data.phase == "Whiff" then
			whiff(K, data)
		end
	end,
}
