--[[
	ULTIME — The Lawyer : « SUPREME VERDICT »
	Coup de marteau au sol : une ligne de citation dorée file vers la cible. Touché → des chaînes dorées
	jaillissent, la victime est traînée dans un box des témoins qui sort du sol, bombardée de pièces à
	conviction (EXHIBIT A/B/C, coupes de caméra), puis le banc du juge s'élève, le monde s'assombrit,
	« THE COURT FINDS YOU... », le marteau devient colossal et s'abat : « GUILTY! » (finisher PIN + cratère).
	Raté → la citation s'éteint, « OVERRULED! ».
]]
local BURGUNDY = Color3.fromRGB(140, 22, 50)
local GOLD = Color3.fromRGB(235, 190, 60)
local WOOD = Color3.fromRGB(120, 70, 35)
local DARKWOOD = Color3.fromRGB(80, 45, 25)
local PAPER = Color3.fromRGB(245, 240, 225)
local WHITE = Color3.fromRGB(255, 255, 255)

local SND = {
	GavelBig = "rbxassetid://9114559389",
	GavelTriple = "rbxassetid://9125574353",
	Chain = "rbxassetid://9113763590",
	Chain2 = "rbxassetid://9113763639",
	Sting = "rbxassetid://1848016523",
}

local T = { Ex = { 0.6, 0.95, 1.3 }, Bench = 1.5, Verdict = 1.65, Raise = 1.85, Swing = 2.45, Slam = 2.68, End = 3.45 }
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
-- citation : marteau levé puis frappé au sol, buste plongé
A.Summon = {
	{ t = 0 },
	{ t = 0.16, RS = { p = 3.1, y = 0.2 }, LS = { p = 0.6, r = -0.4 }, RJ = { ln = -0.35, tw = 0.2 }, RH = { p = 0.2 }, LH = { p = -0.2 } },
	{ t = 0.3, RS = { p = 0.9, y = 0.1 }, LS = { p = 0.3, r = -0.5 }, RJ = { ln = 0.7, tw = -0.1 }, RH = { p = -0.8 }, LH = { p = 1.0 } },
	{ t = 0.55, RS = { p = 0.8 }, LS = { p = 1.7, y = -0.2 }, RJ = { ln = 0.4 }, RH = { p = -0.6 }, LH = { p = 0.8 } }, -- pointe du doigt
	{ t = 0.75 },
}
-- tire sur les chaînes
A.Drag = {
	{ t = 0 },
	{ t = 0.1, RS = { p = 1.7 }, LS = { p = 1.7 }, RJ = { ln = 0.3 } },
	{ t = 0.3, RS = { p = 0.5, y = 1.0 }, LS = { p = 0.5, y = 1.0 }, RJ = { ln = -0.3 }, RH = { p = 0.6 }, LH = { p = -0.5 } },
	{ t = 0.45 },
}
-- lance un dossier (alterné), petit pas en avant
local function throwAnim(left)
	local S, O = left and "LS" or "RS", left and "RS" or "LS"
	return {
		{ t = 0 },
		{ t = 0.1, [S] = { p = 2.6, y = -0.4, r = -0.5 }, [O] = { p = 0.5 }, RJ = { tw = left and -0.6 or 0.6, ln = -0.1 }, RH = { p = 0.3 }, LH = { p = -0.3 } },
		{ t = 0.18, [S] = { p = 1.5, y = 0.3 }, [O] = { p = -0.3 }, RJ = { tw = left and 0.5 or -0.5, ln = 0.3 }, RH = { p = -0.5 }, LH = { p = 0.6 } },
		{ t = 0.32 },
	}
end
A.ThrowL = throwAnim(true)
A.ThrowR = throwAnim(false)
-- marteau colossal : levé à deux mains au-dessus de la tête, cambré
A.Raise = {
	{ t = 0 },
	{ t = 0.25, RS = { p = 3.0, y = 0.1 }, LS = { p = 3.0, y = 0.1 }, RJ = { ln = -0.45 }, RH = { p = 0.35 }, LH = { p = -0.3 } },
	{ t = 0.6, RS = { p = 3.15, y = 0.1 }, LS = { p = 3.15, y = 0.1 }, RJ = { ln = -0.55 }, RH = { p = 0.35 }, LH = { p = -0.3 } },
}
A.Slam = {
	{ t = 0 },
	{ t = 0.2, RS = { p = 1.15 }, LS = { p = 1.15 }, RJ = { ln = 0.75 }, RH = { p = -0.9 }, LH = { p = 1.1 } },
	{ t = 0.6, RS = { p = 1.1 }, LS = { p = 1.1 }, RJ = { ln = 0.65 }, RH = { p = -0.8 }, LH = { p = 1.0 } },
	{ t = 0.8 },
}
-- raté : haussement d'épaules
A.Whiff = {
	{ t = 0 },
	{ t = 0.15, RS = { p = 1.0, y = 1.2, r = -0.6 }, LS = { p = 1.0, y = 1.2, r = -0.6 }, RJ = { sd = 0.15, ln = -0.1 } },
	{ t = 0.6, RS = { p = 1.0, y = 1.2, r = -0.6 }, LS = { p = 1.0, y = 1.2, r = -0.6 }, RJ = { sd = -0.1, ln = -0.1 } },
	{ t = 0.8 },
}
-- victime : enchaînée (bras collés au corps), secouée à chaque pièce
A.VChained = { { t = 0 }, { t = 0.1, RS = { p = 0, r = 0.12 }, LS = { p = 0, r = 0.12 }, RJ = { ln = -0.15 }, RH = { r = 0.08 }, LH = { r = 0.08 } }, { t = 2.6, RS = { p = 0, r = 0.12 }, LS = { p = 0, r = 0.12 }, RJ = { ln = -0.1 } } }
A.VJolt = { { t = 0 }, { t = 0.05, RS = { p = 0.3, r = 0.12 }, LS = { p = 0.3, r = 0.12 }, RJ = { ln = -0.45, sd = 0.15 } }, { t = 0.25, RS = { p = 0, r = 0.12 }, LS = { p = 0, r = 0.12 }, RJ = { ln = -0.1 } } }

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
local function surfaceText(part, face, text, color, ppS)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = ppS or 40
	sg.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.Bodoni
	l.TextColor3 = color
	l.Parent = sg
	return l
end
-- anneau de maillons dorés autour d'un point
local function chainRing(K, data, n)
	local links = {}
	for i = 1, n do
		local l = K.part({ Size = Vector3.new(0.35, 0.7, 1.1), Color = GOLD, Material = Enum.Material.Metal }, 4)
		K.track(data, l)
		links[i] = l
	end
	return links
end
local function placeRing(links, c, radius, spin, tilt)
	local n = #links
	for i, l in ipairs(links) do
		local a = spin + (i / n) * math.pi * 2
		l.CFrame = CFrame.new(c) * CFrame.Angles(tilt, 0, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius) * CFrame.Angles(0, math.pi / 2, (i % 2) * math.pi / 2)
	end
end

------------------------------------------------------------------------
local M = {
	Name = "SUPREME VERDICT",
	-- v3 : titres de temps forts (UltimateController) ; Anticipate = poses d'armement avant ces coups
	Beats = { Connect = { { 0, "TAKE THE STAND" }, { T.Ex[1], "EXHIBITS A, B, C" }, { T.Verdict, "THE COURT FINDS YOU..." } } },
	Desc = "Summon them to court, present the evidence, then bring down the colossal gavel: GUILTY!",
	Color = GOLD,
	Color2 = BURGUNDY,
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
			K.sound(SND.GavelTriple, r.Position, 1, 1)
			K.at(data, 0.3, function()
				K.ring(CFrame.lookAt(r.Position - Vector3.new(0, 2.8, 0), r.Position + Vector3.new(0, 5, 0)), 12, GOLD, 0.5, 0.3)
				K.light(r.Position, GOLD, 22, 5, 0.6)
			end)
		end
		return
	end

	if phase == "Rush" then
		play(K, caster, A.Summon)
		local r = K.root(caster)
		if not r then
			return
		end
		K.sound("Whoosh", r.Position, 1, 0.8)
		local dir = data.dir or r.CFrame.LookVector
		local range = data.range or 26
		K.at(data, 0.3, function()
			local g = K.groundPos(r.Position + dir * 2.5)
			K.sound(SND.GavelBig, g, 1.3, 1)
			K.shake(0.5)
			K.shockwave(g + Vector3.new(0, 0.2, 0), 6, GOLD)
			K.word(r.Position + Vector3.new(0, 4.5, 0), "ORDER!", 1.0, "Heavy")
			-- ligne de citation : dalles dorées qui filent au sol
			local stop = data.hitPos and (data.hitPos - r.Position).Magnitude or range
			local n = 12
			for i = 1, n do
				K.at(data, 0.3 + i * 0.022, function()
					local p = K.groundPos(r.Position + dir * (2.5 + (stop - 2.5) * i / n))
					local tile = K.part({ Size = Vector3.new(1.8, 0.12, 1.6), CFrame = CFrame.lookAt(p + Vector3.new(0, 0.08, 0), p + Vector3.new(0, 0.08, 0) + dir), Color = GOLD, Material = Enum.Material.Neon }, 0.9)
					K.tween(tile, 0.7, { Transparency = 1, Size = Vector3.new(0.4, 0.05, 1.6) })
					if i % 3 == 0 then
						K.sparks(p + Vector3.new(0, 0.5, 0), 4, GOLD)
					end
				end)
			end
		end)
		return
	end

	if phase == "Whiff" then
		play(K, caster, A.Whiff)
		local r = K.root(caster)
		if r then
			K.sound("SlideWhistle", r.Position, 0.9, 0.8)
			K.puff(r.Position + (data.dir or r.CFrame.LookVector) * 10, 2)
			K.word(r.Position + Vector3.new(0, 5, 0), "OVERRULED!", 1.2, "Heavy")
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
	local vp0 = data.vp or (cf.Position + look * 6)
	local function vp()
		return rootPos(target, vp0)
	end
	local g0 = K.groundPos(vp0)

	-- 1) CHAÎNES + BOX DES TÉMOINS --------------------------------
	play(K, caster, A.Drag)
	play(K, target, A.VChained)
	K.sound(SND.Chain, vp0, 1.3, 1)
	K.sound(SND.Chain2, vp0, 1, 0.8)
	K.word(vp0 + up * 4, "SUBPOENAED!", 1.1, "Heavy")
	K.shot(data, "orbit", { at = function() return vp() end, radius = 11, height = 3, angle = 145, speed = 50, basis = cf, fov = 60 })
	-- chaînes qui jaillissent du sol puis s'enroulent
	local rings = { chainRing(K, data, 9), chainRing(K, data, 9) }
	run(0.35, function(a)
		local c = vp()
		for k, links in ipairs(rings) do
			placeRing(links, c + Vector3.new(0, -3 + a * (2.5 + k * 0.9), 0), 1.6 + (1 - a) * 2, a * 6 * (k == 1 and 1 or -1), (k == 1) and 0.3 or -0.3)
		end
	end)
	K.at(data, 0.35, function()
		run(T.Slam - 0.35, function()
			local c = vp()
			for k, links in ipairs(rings) do
				placeRing(links, c + Vector3.new(0, -0.5 + k * 0.9, 0), 1.6, os.clock() * 0.5 * (k == 1 and 1 or -1), (k == 1) and 0.3 or -0.3)
			end
		end)
	end)
	-- box des témoins : 4 panneaux en bois + liseré doré, sortent du sol
	local boxCF = CFrame.lookAt(g0, g0 - look)
	local box = {}
	local function panel(size, off, color, mat)
		local p = K.part({ Size = size, CFrame = boxCF * off * CFrame.new(0, -3.5, 0), Color = color, Material = mat or Enum.Material.Wood }, 4.5)
		K.track(data, p)
		table.insert(box, { p = p, cf = boxCF * off })
		return p
	end
	panel(Vector3.new(4.6, 3.2, 0.4), CFrame.new(0, 1.6, 2.1), WOOD) -- façade (côté lanceur)
	panel(Vector3.new(4.6, 3.2, 0.4), CFrame.new(0, 1.6, -2.1), WOOD)
	panel(Vector3.new(0.4, 3.2, 4.2), CFrame.new(2.1, 1.6, 0), WOOD)
	panel(Vector3.new(0.4, 3.2, 4.2), CFrame.new(-2.1, 1.6, 0), WOOD)
	panel(Vector3.new(5, 0.3, 0.6), CFrame.new(0, 3.3, -2.1), GOLD, Enum.Material.Metal)
	panel(Vector3.new(5, 0.3, 0.6), CFrame.new(0, 3.3, 2.1), GOLD, Enum.Material.Metal)
	local plaque = panel(Vector3.new(2.6, 0.8, 0.1), CFrame.new(0, 2.2, 2.35), GOLD, Enum.Material.Metal)
	surfaceText(plaque, Enum.NormalId.Back, "WITNESS", DARKWOOD)
	for _, b in ipairs(box) do
		K.tween(b.p, 0.3, { CFrame = b.cf }, Enum.EasingStyle.Back)
	end
	K.at(data, 0.15, function()
		K.dust(g0, 6, nil, 10)
		K.sound("Thud", g0, 1.2, 0.8)
	end)

	-- 2) PIÈCES À CONVICTION -------------------------------------
	local cams = {
		{ pos = cf.Position - look * 3.5 + up * 2 + right * 2.5, at = vp0 + up * 0.8, fov = 55 },
		{ pos = cf.Position:Lerp(vp0, 0.5) - right * 7 + up * 2, at = vp0 + up * 0.5, fov = 60 },
		{ pos = cf.Position + right * 7 + up * 5 + look * 2, at = vp0, fov = 58 },
	}
	for i, at in ipairs(T.Ex) do
		local letter = string.char(64 + i)
		K.at(data, at - 0.2, function()
			play(K, caster, (i % 2 == 1) and A.ThrowL or A.ThrowR)
			K.shot(data, "fixed", { pos = cams[i].pos, lookAt = cams[i].at, fov = cams[i].fov })
			local hand = caster and caster:FindFirstChild((i % 2 == 1) and "Left Arm" or "Right Arm")
			local from = hand and hand.Position or (cf.Position + up * 1.5)
			local file = K.part({ Size = Vector3.new(2.6, 0.3, 3.4), CFrame = CFrame.new(from), Color = PAPER }, 1)
			local tab = K.part({ Size = Vector3.new(1.0, 0.32, 0.5), CFrame = file.CFrame * CFrame.new(0.6, 0, -1.9), Color = BURGUNDY }, 1)
			local w = Instance.new("WeldConstraint")
			w.Part0, w.Part1 = file, tab
			w.Parent = file
			tab.Anchored = false
			surfaceText(file, Enum.NormalId.Top, "EXHIBIT " .. letter, BURGUNDY)
			surfaceText(file, Enum.NormalId.Bottom, "EXHIBIT " .. letter, BURGUNDY)
			K.sound("Throw", from, 1, 1)
			local p0 = from
			run(0.2, function(a)
				local c = vp() + up * 0.6
				local pos = p0:Lerp(c, a) + up * math.sin(a * math.pi) * 1.5
				file.CFrame = CFrame.lookAt(pos, c) * CFrame.Angles(math.pi / 2, a * 9, 0)
			end)
			K.at(data, at, function()
				local c = vp() + up * 0.6
				file:Destroy()
				play(K, target, A.VJolt)
				K.sound(SND.GavelTriple, c, 0.8, 1.2)
				K.sound("PunchHeavy", c, 1, 1)
				K.shake(0.6 + i * 0.15)
				K.impactFrames(i == 3 and "BW" or "W", 0.04)
				K.shards(c, 10, { PAPER, WHITE, BURGUNDY }, 1.2)
				K.ring(CFrame.lookAt(c, c - look), 6 + i, GOLD, 0.25, 0.3)
				K.word(c + up * 2.5 + right * (i - 2) * 1.5, "EXHIBIT " .. letter .. "!", 1.0 + i * 0.1, "Heavy")
			end)
		end)
	end

	-- 3) LE BANC DU JUGE ------------------------------------------
	K.at(data, T.Bench, function()
		local gc = K.groundPos(cf.Position)
		local bcf = CFrame.lookAt(gc - look * 3.2, gc - look * 3.2 + look)
		local parts = {}
		local function bench(size, off, color, mat)
			local p = K.part({ Size = size, CFrame = bcf * off * CFrame.new(0, -6, 0), Color = color, Material = mat or Enum.Material.Wood }, 3)
			K.track(data, p)
			table.insert(parts, { p = p, cf = bcf * off })
			return p
		end
		bench(Vector3.new(9, 5, 2.4), CFrame.new(0, 2.5, 0), DARKWOOD)
		bench(Vector3.new(9.6, 0.4, 3), CFrame.new(0, 5.1, 0), WOOD)
		bench(Vector3.new(9.2, 0.35, 0.2), CFrame.new(0, 4.2, -1.25), GOLD, Enum.Material.Metal)
		local seal = bench(Vector3.new(2.4, 2.4, 0.2), CFrame.new(0, 2.6, -1.25), GOLD, Enum.Material.Metal)
		surfaceText(seal, Enum.NormalId.Front, "§", BURGUNDY)
		-- balance de la justice au-dessus
		bench(Vector3.new(0.3, 3.5, 0.3), CFrame.new(0, 7.0, 0), GOLD, Enum.Material.Metal)
		bench(Vector3.new(4.2, 0.25, 0.25), CFrame.new(0, 8.7, 0), GOLD, Enum.Material.Metal)
		bench(Vector3.new(1.4, 0.2, 1.4), CFrame.new(1.9, 7.6, 0), GOLD, Enum.Material.Metal)
		bench(Vector3.new(1.4, 0.2, 1.4), CFrame.new(-1.9, 7.6, 0), GOLD, Enum.Material.Metal)
		for _, b in ipairs(parts) do
			K.tween(b.p, 0.35, { CFrame = b.cf }, Enum.EasingStyle.Back)
		end
		K.sound("Rumble", gc, 1, 1)
		K.sound(SND.Sting, nil, 0.6, 1)
		K.dust(gc - look * 3, 7, nil, 10)
		K.darken(true, 0.55, 0.25)
		-- rayons dorés derrière le banc
		for k = 1, 7 do
			local a = math.rad(-60 + k * 15)
			local base = gc - look * 4 + up * 7
			local d = (up * math.cos(a) + right * math.sin(a))
			local ray = K.part({ Size = Vector3.new(0.5, 0.5, 16), CFrame = CFrame.lookAt(base + d * 9, base + d * 18), Color = GOLD, Material = Enum.Material.Neon, Transparency = 1 }, 2.2)
			K.track(data, ray)
			K.tween(ray, 0.3, { Transparency = 0.35 })
			K.at(data, T.Slam + 0.1, function()
				K.tween(ray, 0.3, { Transparency = 1 })
			end)
		end
		K.light(gc + up * 8, GOLD, 40, 6, 1.5)
	end)
	K.at(data, T.Verdict, function()
		if K.involved(data) then
			K.cutin(data, { title = "THE COURT FINDS YOU...", sub = "SUPREME VERDICT", color = GOLD, color2 = BURGUNDY, dur = 0.75, small = true })
		end
		K.word(cf.Position + up * 6, "THE COURT FINDS YOU...", 1.0, "Light")
	end)

	-- 4) MARTEAU COLOSSAL ------------------------------------------
	K.at(data, T.Raise, function()
		play(K, caster, A.Raise)
		K.sound("PowerUp", cf.Position, 1, 0.7)
		K.sound(SND.Chain2, cf.Position, 0.8, 0.6)
		-- caméra en contre-plongée depuis la victime
		K.shot(data, "fixed", { pos = vp0 + look * 2.8 - right * 3 + up * 0.2, lookAt = cf.Position + up * 7, fov = 70 })
		local handle = K.part({ Size = Vector3.new(0.5, 0.5, 2), Color = WOOD, Material = Enum.Material.Wood }, 2)
		local head = K.part({ Shape = K.CYL, Size = Vector3.new(2, 1, 1), Color = DARKWOOD, Material = Enum.Material.Wood }, 2)
		local bandA = K.part({ Shape = K.CYL, Size = Vector3.new(0.3, 1.05, 1.05), Color = GOLD, Material = Enum.Material.Metal }, 2)
		local bandB = K.part({ Shape = K.CYL, Size = Vector3.new(0.3, 1.05, 1.05), Color = GOLD, Material = Enum.Material.Metal }, 2)
		for _, p in ipairs({ handle, head, bandA, bandB }) do
			K.track(data, p)
		end
		local pivot = cf.Position + up * 1.6 + look * 0.4
		local scale, theta = 1, 0.6
		local function place()
			local dirv = up * math.cos(theta) + look * math.sin(theta)
			local L = 1.4 + 3.8 * (scale - 1) / 3 -- longueur du manche jusqu'à la tête
			local hlen, hdia = 2 + 6 * (scale - 1) / 3, 1 + 3.6 * (scale - 1) / 3
			handle.Size = Vector3.new(0.4 * scale, 0.4 * scale, L)
			handle.CFrame = CFrame.lookAt(pivot + dirv * L / 2, pivot + dirv * L)
			local hc = pivot + dirv * (L + hdia * 0.3)
			local hcf = CFrame.fromMatrix(hc, right, dirv:Cross(right), -dirv)
			head.Size = Vector3.new(hlen, hdia, hdia)
			head.CFrame = hcf
			bandA.Size = Vector3.new(0.3 * scale, hdia * 1.06, hdia * 1.06)
			bandB.Size = bandA.Size
			bandA.CFrame = hcf * CFrame.new(hlen * 0.36, 0, 0)
			bandB.CFrame = hcf * CFrame.new(-hlen * 0.36, 0, 0)
			return hc, hdia
		end
		place()
		-- levée + croissance
		run(T.Swing - T.Raise, function(a)
			scale = 1 + 3 * a
			theta = 0.6 - 1.15 * a
			local hc = place()
			if a > 0.3 and K.rng:NextNumber() < 0.3 then
				K.sparks(hc, 3, GOLD)
			end
		end)
		K.at(data, T.Swing - 0.3, function()
			K.implode(pivot + up * 6, 8, { GOLD, WHITE }, 14, 0.3)
			K.sound("Charge", cf.Position, 0.8, 1.3)
		end)
		-- frappe
		K.at(data, T.Swing, function()
			play(K, caster, A.Slam)
			K.sound("Whoosh", vp0, 1.5, 0.5)
			K.shot(data, "fixed", { pos = cf.Position:Lerp(vp0, 0.5) + right * 16 + up * 4, lookAt = cf.Position:Lerp(vp0, 0.6) + up * 3, fov = 62 })
			local last
			run(T.Slam - T.Swing, function(a)
				theta = -0.55 + (1.78 + 0.55) * a * a
				local hc = place()
				if last then
					K.streak(last, hc, GOLD, 2.2, 0.12)
				end
				last = hc
			end)
		end)
		-- GUILTY!
		K.at(data, T.Slam, function()
			local c = vp0
			K.impactFrames("BRWB", 0.05)
			K.layer({ { SND.GavelBig, 2 }, { "Boom", 1.5 }, { "Bass", 1.4, 0.85 }, { "Explosion", 1.2, 0.9, 0.04 }, { SND.GavelTriple, 1, 0.8, 0.25 } }, c)
			K.shake(2.1)
			K.fov(12)
			K.crater(c, 11, GOLD, 3)
			K.quake(c, 13, GOLD, 1.3)
			K.shockwave(g0 + up * 0.3, 18, GOLD)
			K.sphere(c, 13, GOLD, 0.35, 3)
			K.light(c, GOLD, 45, 10, 0.5)
			K.debris(c, 8, { WOOD, DARKWOOD, GOLD }, 1.4, 1.2)
			K.word(c + up * 6, "GUILTY!!", 2.0, "Heavy")
			K.darken(false, 0, 0.4)
			-- le box vole en éclats, les chaînes tombent
			for _, b in ipairs(box) do
				if b.p.Parent then
					local d = b.p.Position - c
					d = Vector3.new(d.X, 0, d.Z)
					d = d.Magnitude > 0.1 and d.Unit or look
					K.tween(b.p, 0.5, { CFrame = b.p.CFrame * CFrame.Angles(K.rng:NextNumber(-1.5, 1.5), 0, K.rng:NextNumber(-1.5, 1.5)) + d * 7 + up * 2, Transparency = 1 })
				end
			end
			for _, links in ipairs(rings) do
				for _, l in ipairs(links) do
					K.tween(l, 0.4, { CFrame = l.CFrame + Vector3.new(K.rng:NextNumber(-4, 4), -1, K.rng:NextNumber(-4, 4)), Transparency = 1 })
				end
			end
			-- le marteau reste planté puis s'efface
			K.at(data, T.Slam + 0.4, function()
				for _, p in ipairs({ handle, head, bandA, bandB }) do
					K.tween(p, 0.3, { Transparency = 1 })
				end
			end)
			K.shot(data, "orbit", { at = c, radius = 15, height = 6, angle = 60, speed = 25, basis = cf, fov = 65 })
		end)
		K.at(data, T.Slam + 0.45, function()
			K.word(vp0 + up * 3 + right * 3, "CASE CLOSED", 1.0, "Light")
		end)
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
	if not U.wait(ctx, 0.6) then
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
	-- les chaînes traînent la victime dans le box, à 6 studs
	local vr = U.root(target)
	cf = U.facing(cf.Position, vr.Position)
	U.place(ctx, caster, cf)
	local vp = U.wallSafe(cf.Position, cf.Position + cf.LookVector * 6, 1.5)
	U.hold(ctx, target, U.facing(vr.Position, cf.Position))
	U.glide(ctx, target, U.facing(vp, cf.Position), 0.3, "Out")
	U.fx(ctx, "Connect", { cf = cf, vp = vp })
	local tc = os.clock()
	local function at(t)
		return U.wait(ctx, math.max(0, t - (os.clock() - tc)))
	end
	for i, t in ipairs(T.Ex) do
		if not at(t) then
			return
		end
		U.hit(ctx, target, 3.5, { power = 0.5 + i * 0.1, words = { "OBJECTION!", "EVIDENCE!", "SUSTAINED!" }, stun = 0.7 })
	end
	if not at(T.Slam) then
		return
	end
	U.finish(ctx, target, 21, { pin = true, words = { "GUILTY!" }, splash = { radius = 12, damage = 10, center = vp } })
	at(T.End)
end

return M
