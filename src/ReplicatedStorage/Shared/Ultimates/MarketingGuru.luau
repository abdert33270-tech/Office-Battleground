--[[
	ULTIME — The Marketing Guru : « BREAK THE INTERNET »
	« SAY CHEESE! » : flash de téléphone en cône devant. Touché → la victime est figée dans un écran de
	téléphone géant (LIVE), bombardée de notifications (cœurs, étoiles, +1) pendant que le compteur
	d'abonnés explose, puis un hurlement au mégaphone, et une flèche STONKS jaillit du sol et l'envoie
	dans le ciel au milieu d'un feu d'artifice de confettis (finisher LAUNCH vertical).
	Raté → selfie tout seul, « NO SIGNAL ».
]]
local MAGENTA = Color3.fromRGB(235, 35, 200)
local CYAN = Color3.fromRGB(40, 220, 255)
local YELLOW = Color3.fromRGB(255, 230, 40)
local WHITE = Color3.fromRGB(250, 250, 255)
local DARK = Color3.fromRGB(30, 30, 40)
local STONKS = Color3.fromRGB(40, 220, 90)
local RED = Color3.fromRGB(255, 50, 80)
local CONFETTI = { MAGENTA, CYAN, YELLOW, Color3.fromRGB(120, 255, 90), Color3.fromRGB(255, 120, 40), WHITE }

local SND = {
	Shutter = "rbxassetid://9113692497",
	Horn = "rbxassetid://132844961288199",
	Firework = "rbxassetid://75191072171555",
	Cheer = "rbxassetid://132079977802654",
}

local T = { Barrage0 = 0.45, BarrageStep = 0.11, BarrageN = 8, Scream = 1.6, Stonks = 2.2, Launch = 2.55, End = 3.4 }
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
-- « SAY CHEESE! » : téléphone tendu devant (main gauche), signe V de l'autre main
A.Cheese = {
	{ t = 0 },
	{ t = 0.12, LS = { p = 1.95, y = -0.25 }, RS = { p = 2.7, y = 0.3, r = -0.35 }, RJ = { ln = -0.2, sd = 0.12, tw = 0.2 }, RH = { p = 0.2 }, LH = { p = -0.25 } },
	{ t = 0.34, LS = { p = 1.95, y = -0.25 }, RS = { p = 2.75, y = 0.3, r = -0.35 }, RJ = { ln = -0.22, sd = 0.14, tw = 0.2 } },
	{ t = 0.42, LS = { p = 1.75, y = -0.15 }, RS = { p = 2.4, y = 0.3, r = -0.4 }, RJ = { ln = 0.1, sd = 0.05, tw = 0.1 } }, -- clic
	{ t = 0.7 },
}
-- bombardement : il « lance » les notifications des deux mains en rythme
local function barrageAnim()
	local f = { { t = 0 }, { t = 0.1, RS = { p = 0.4, r = -0.6 }, LS = { p = 0.4, r = -0.6 }, RJ = { ln = -0.1 } } }
	local t = 0.1
	for i = 1, 8 do
		t += 0.11
		local r = i % 2 == 1
		table.insert(f, { t = t, RS = { p = r and 2.0 or 0.6, y = r and 0.2 or 0, r = r and 0 or -0.6 }, LS = { p = r and 0.6 or 2.0, y = r and 0 or 0.2, r = r and -0.6 or 0 }, RJ = { tw = r and -0.35 or 0.35, ln = 0.15 }, RH = { p = r and -0.3 or 0.3 }, LH = { p = r and 0.3 or -0.3 } })
	end
	table.insert(f, { t = t + 0.12 })
	return f
end
A.Barrage = barrageAnim()
-- hurlement au mégaphone (main gauche), penché en avant, jambes écartées
A.Scream = {
	{ t = 0 },
	{ t = 0.15, LS = { p = 1.2, y = -0.4 }, RS = { p = 0.4, r = -0.9 }, RJ = { ln = -0.45, tw = 0.25 }, RH = { p = 0.25, r = -0.25 }, LH = { p = 0.25, r = -0.25 } }, -- inspire
	{ t = 0.25, LS = { p = 1.7, y = -0.1 }, RS = { p = 0.9, r = -1.2 }, RJ = { ln = 0.45, tw = -0.1 }, RH = { p = -0.5, r = -0.3 }, LH = { p = 0.7, r = -0.3 } },
	{ t = 0.55, LS = { p = 1.7, y = -0.1 }, RS = { p = 0.9, r = -1.2 }, RJ = { ln = 0.5, tw = -0.1, sd = 0.05 }, RH = { p = -0.5, r = -0.3 }, LH = { p = 0.7, r = -0.3 } },
	{ t = 0.7 },
}
-- STONKS : poing levé vers le ciel, pose de victoire
A.Stonks = {
	{ t = 0 },
	{ t = 0.12, RS = { p = 0.3, y = 0.4 }, LS = { p = 0.2 }, RJ = { ln = 0.35 }, RH = { p = 0.7 }, LH = { p = 0.7 } }, -- s'accroupit
	{ t = 0.24, RS = { p = 3.1, r = -0.1 }, LS = { p = 0.4, r = -0.5 }, RJ = { ln = -0.3, tw = 0.2 }, RH = { p = -0.2 }, LH = { p = 0.35 } },
	{ t = 0.9, RS = { p = 3.1, r = -0.1 }, LS = { p = 1.2, y = 1.2, r = -0.3 }, RJ = { ln = -0.25, tw = 0.25 } },
	{ t = 1.05 },
}
-- raté : selfie tout seul, la tête penchée
A.Whiff = {
	{ t = 0 },
	{ t = 0.15, LS = { p = 2.3, y = 1.0, r = -0.6 }, RS = { p = 2.9, r = -0.4 }, RJ = { sd = 0.25, tw = -0.3 } },
	{ t = 0.5, LS = { p = 2.3, y = 1.0, r = -0.6 }, RS = { p = 2.9, r = -0.4 }, RJ = { sd = 0.28, tw = -0.3 } },
	{ t = 0.65, LS = { p = 0.6 }, RS = { p = 0.3 }, RJ = { ln = 0.35 } }, -- épaules qui tombent
	{ t = 0.9 },
}
-- victime : figée « sur la photo », puis criblée
A.VSnap = { { t = 0 }, { t = 0.06, RS = { p = 2.6, r = -0.5 }, LS = { p = 2.6, r = -0.5 }, RJ = { ln = -0.2 }, RH = { r = -0.25 }, LH = { r = -0.25 } }, { t = 0.5, RS = { p = 2.6, r = -0.5 }, LS = { p = 2.6, r = -0.5 }, RJ = { ln = -0.2 }, RH = { r = -0.25 }, LH = { r = -0.25 } }, { t = 0.6 } }
local function peltAnim()
	local f = { { t = 0 } }
	local t, s = 0, 1
	while t < 1.0 do
		t += 0.11
		s = -s
		table.insert(f, { t = t, RS = { p = 1.0 + 0.4 * s, r = -0.4 }, LS = { p = 1.0 - 0.4 * s, r = -0.4 }, RJ = { tw = 0.3 * s, ln = -0.1, sd = 0.1 * s } })
	end
	table.insert(f, { t = t + 0.1 })
	return f
end
A.VPelt = peltAnim()

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

local function label(part, face, text, color, bg)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.LightInfluence = 0
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = bg and 0 or 1
	l.BackgroundColor3 = bg or Color3.new(0, 0, 0)
	l.Text = text
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = color
	l.TextStrokeTransparency = 0.2
	l.Parent = sg
	return l
end

-- notification volante (carré blanc arrondi + symbole) : BillboardGui non AlwaysOnTop
local ICONS = { { "♥", RED }, { "★", YELLOW }, { "+1", CYAN }, { "♥", MAGENTA }, { "@", MAGENTA }, { "#", STONKS }, { "♥", RED }, { "LIKE", CYAN } }
local function notif(K, data, pos, i)
	local p = K.part({ Size = Vector3.one * 0.4, Position = pos, Transparency = 1 }, 1.2)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(2.6, 2.6)
	bb.LightInfluence = 0
	bb.Parent = p
	local f = Instance.new("Frame")
	f.Size = UDim2.fromScale(1, 1)
	f.BackgroundColor3 = WHITE
	f.Parent = bb
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.3, 0)
	c.Parent = f
	local s = Instance.new("UIStroke")
	s.Thickness = 3
	s.Color = ICONS[i][2]
	s.Parent = f
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(0.9, 0.9)
	l.Position = UDim2.fromScale(0.05, 0.05)
	l.BackgroundTransparency = 1
	l.Text = ICONS[i][1]
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = ICONS[i][2]
	l.Parent = f
	K.track(data, p)
	return p
end

------------------------------------------------------------------------
local M = {
	Name = "BREAK THE INTERNET",
	-- v3 : titres de temps forts (UltimateController) ; Anticipate = poses d'armement avant ces coups
	Beats = { Connect = { { 0, "GOING LIVE" }, { T.Barrage0, "NOTIFICATIONS" }, { T.Scream, "MEGAPHONE" }, { T.Stonks, "STONKS" } } },
	Desc = "Snap them into a viral post, drown them in likes, then ride the STONKS arrow to the sky.",
	Color = MAGENTA,
	Color2 = CYAN,
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
			-- anneau lumineux + confettis autour de lui
			K.sound("PowerUp", r.Position, 0.9, 1.2)
			for i = 0, 3 do
				K.at(data, 0.1 + i * 0.22, function()
					K.ring(CFrame.lookAt(r.Position, r.Position + Vector3.yAxis), 8 + i * 2, (i % 2 == 0) and MAGENTA or CYAN, 0.35, 0.3)
					K.shards(r.Position + Vector3.new(0, 2, 0), 6, CONFETTI, 0.7)
				end)
			end
		end
		return
	end

	if phase == "Rush" then
		play(K, caster, A.Cheese)
		local r = K.root(caster)
		if not r then
			return
		end
		local phone = K.prop(data, caster, "Left Arm", Vector3.new(1.1, 0.15, 1.9), CFrame.new(0, -1.2, -0.3), DARK)
		local screen = phone and K.prop(data, caster, "Left Arm", Vector3.new(0.95, 0.05, 1.7), CFrame.new(0, -1.13, -0.3), CYAN, nil, Enum.Material.Neon)
		K.word(r.Position + Vector3.new(0, 4.5, 0), "SAY CHEESE!", 1.0, "Light")
		K.sound("Ding", r.Position, 0.8, 1.4)
		K.at(data, 0.42, function()
			local dir = data.dir or r.CFrame.LookVector
			local from = (phone and phone.Position) or (r.Position + Vector3.new(0, 1.5, 0))
			K.sound(SND.Shutter, from, 1.3, 1)
			K.sphere(from, 7, WHITE, 0.25, 1)
			K.light(from, WHITE, 40, 12, 0.3)
			-- cône de flash
			for k = -3, 3 do
				local d = (CFrame.fromAxisAngle(Vector3.yAxis, math.rad(k * 9)) * CFrame.new(Vector3.zero, dir)).LookVector
				K.beam(from, from + d * (data.range or 24) + Vector3.new(0, K.rng:NextNumber(-1, 1.5), 0), 0.5, (k % 2 == 0) and WHITE or Color3.fromRGB(255, 240, 200), 0.25)
			end
			if K.involved(data) or K.near(from, 30) then
				K.flash(WHITE, 0.25, 0.4)
			end
		end)
		K.at(data, 0.75, function()
			if phone then phone:Destroy() end
			if screen then screen:Destroy() end
		end)
		return
	end

	if phase == "Whiff" then
		play(K, caster, A.Whiff)
		local r = K.root(caster)
		if not r then
			return
		end
		local phone = K.prop(data, caster, "Left Arm", Vector3.new(1.1, 0.15, 1.9), CFrame.new(0, -1.2, -0.3), DARK)
		K.at(data, 0.2, function()
			K.sound(SND.Shutter, r.Position, 1, 1.1)
			K.sphere(r.Position + Vector3.new(0, 2, 0), 5, WHITE, 0.2, 1)
		end)
		K.at(data, 0.45, function()
			K.sound("SlideWhistle", r.Position, 1, 0.9)
			K.word(r.Position + Vector3.new(0, 5, 0), "NO SIGNAL...", 1.0, "Light")
			K.puff(r.Position + Vector3.new(0, 4, 0), 2)
			K.shards(r.Position + Vector3.new(0, 3, 0), 6, { Color3.fromRGB(120, 120, 130) }, 0.4)
		end)
		K.at(data, 0.85, function()
			if phone then phone:Destroy() end
		end)
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
	local vp0 = data.vp or (cf.Position + look * 5)
	local function vp()
		return rootPos(target, vp0)
	end

	-- 1) SNAP : la victime est figée dans un écran de téléphone géant ----
	play(K, target, A.VSnap)
	K.impactFrames("WW", 0.05)
	K.sound(SND.Shutter, vp0, 1.4, 0.9)
	K.sound("Boom", vp0, 0.8, 1.3)
	K.word(vp0 + up * 5, "SNAP!", 1.3, "Heavy")
	K.shot(data, "fixed", { pos = cf.Position - look * 4 + up * 2.2 + right * 1.2, lookAt = vp0 + up * 0.6, fov = 55 })
	local screenCF = CFrame.lookAt(vp0 + up * 0.4, vp0 + up * 0.4 - look) -- face au lanceur
	local W, H = 6.2, 9.4
	local frame = {}
	local function bar(size, off, color, mat)
		local p = K.part({ Size = size, CFrame = screenCF * off, Color = color, Material = mat or Enum.Material.SmoothPlastic, Transparency = 1 }, 4)
		K.track(data, p)
		table.insert(frame, p)
		return p
	end
	bar(Vector3.new(W + 1, 0.7, 0.5), CFrame.new(0, H / 2, 0), DARK)
	bar(Vector3.new(W + 1, 0.9, 0.5), CFrame.new(0, -H / 2, 0), DARK)
	bar(Vector3.new(0.6, H, 0.5), CFrame.new(W / 2, 0, 0), DARK)
	bar(Vector3.new(0.6, H, 0.5), CFrame.new(-W / 2, 0, 0), DARK)
	bar(Vector3.new(W + 1.5, 0.2, 0.3), CFrame.new(0, H / 2 + 0.45, 0), MAGENTA, Enum.Material.Neon)
	bar(Vector3.new(W + 1.5, 0.2, 0.3), CFrame.new(0, -H / 2 - 0.55, 0), MAGENTA, Enum.Material.Neon)
	bar(Vector3.new(0.2, H + 1, 0.3), CFrame.new(W / 2 + 0.4, 0, 0), CYAN, Enum.Material.Neon)
	bar(Vector3.new(0.2, H + 1, 0.3), CFrame.new(-W / 2 - 0.4, 0, 0), CYAN, Enum.Material.Neon)
	local live = bar(Vector3.new(1.8, 0.8, 0.2), CFrame.new(-W / 2 + 1.3, H / 2 - 1, -0.3), RED)
	label(live, Enum.NormalId.Front, "LIVE", WHITE)
	label(live, Enum.NormalId.Back, "LIVE", WHITE)
	local glass = bar(Vector3.new(W, H, 0.1), CFrame.new(0, 0, 0.1), CYAN, Enum.Material.Glass)
	for _, p in ipairs(frame) do
		local goal = (p == glass) and 0.85 or 0
		local s = p.Size
		p.Size = s * 0.2
		K.tween(p, 0.22, { Transparency = goal, Size = s }, Enum.EasingStyle.Back)
	end
	-- compteur d'abonnés au-dessus de l'écran
	local counterPart = K.part({ Size = Vector3.one * 0.3, Position = vp0 + up * (H / 2 + 2.2), Transparency = 1 }, 4)
	K.track(data, counterPart)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(10, 2.2)
	bb.LightInfluence = 0
	bb.Parent = counterPart
	local cnt = Instance.new("TextLabel")
	cnt.Size = UDim2.fromScale(1, 1)
	cnt.BackgroundTransparency = 1
	cnt.Font = Enum.Font.FredokaOne
	cnt.TextScaled = true
	cnt.TextColor3 = WHITE
	cnt.TextStrokeColor3 = MAGENTA
	cnt.TextStrokeTransparency = 0
	cnt.Text = "0 FOLLOWERS"
	cnt.Parent = bb
	local function fmt(n)
		local s = tostring(math.floor(n))
		local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		return (out:gsub("^,", ""))
	end

	-- 2) BARRAGE DE NOTIFICATIONS --------------------------------
	K.at(data, T.Barrage0 - 0.1, function()
		play(K, caster, A.Barrage)
		play(K, target, A.VPelt)
		K.shot(data, "orbit", { at = function() return vp() end, radius = 12, height = 3, angle = -40, speed = -55, basis = cf, fov = 62 })
		run(T.BarrageN * T.BarrageStep + 0.3, function(a)
			cnt.Text = fmt((10 ^ (a * 6))) .. " FOLLOWERS"
			cnt.TextColor3 = a >= 1 and YELLOW or WHITE
		end)
	end)
	for i = 1, T.BarrageN do
		local at = T.Barrage0 + (i - 1) * T.BarrageStep
		K.at(data, at - 0.18, function()
			local ang = K.rng:NextNumber(0, math.pi * 2)
			local from = vp0 + Vector3.new(math.cos(ang) * 14, K.rng:NextNumber(1, 7), math.sin(ang) * 14)
			local p = notif(K, data, from, i)
			K.tween(p, 0.18, { Position = vp0 + Vector3.new(K.rng:NextNumber(-1, 1), K.rng:NextNumber(-0.5, 2), K.rng:NextNumber(-1, 1)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			K.at(data, at, function()
				local hp = p.Position
				p:Destroy()
				K.sound("Ding", hp, 0.7, 1.2 + i * 0.08)
				K.sound("Punch", hp, 0.6, 1.2)
				K.sparks(hp, 10, ICONS[i][2])
				K.ring(CFrame.lookAt(hp, cf.Position), 4, ICONS[i][2], 0.2, 0.25)
				K.shake(0.3)
				if i == 3 then
					K.word(hp + up * 2, "+1K!", 0.9, "Light")
				elseif i == 6 then
					K.word(hp + up * 2 - right * 2, "GOING VIRAL!", 1.1, "Heavy")
				end
			end)
		end)
	end

	-- 3) HURLEMENT AU MÉGAPHONE -----------------------------------
	K.at(data, T.Scream - 0.25, function()
		play(K, caster, A.Scream)
		local mega = K.prop(data, caster, "Left Arm", Vector3.new(1.0, 1.6, 1.0), CFrame.new(0, -1.6, -0.2) * K.UPRIGHT, WHITE, K.CYL)
		local bell = K.prop(data, caster, "Left Arm", Vector3.new(0.3, 2.2, 2.2), CFrame.new(0, -2.55, -0.2) * K.UPRIGHT, MAGENTA, K.CYL)
		K.shot(data, "fixed", { pos = cf.Position + look * 2.6 + up * 1.4 - right * 2.8, lookAt = cf.Position + up * 1.2, fov = 58 })
		K.sound("Whoosh3", cf.Position, 1, 0.7)
		K.at(data, T.Scream, function()
			local from = (bell and bell.Position) or (cf.Position + look * 2 + up * 1.5)
			K.layer({ { "Siren", 0.7, 1.4 }, { "Boom", 1.3, 0.8 }, { "Bass", 1.2, 1.1 }, { "Oof", 1, 0.8, 0.08 } }, from)
			K.impactFrames("BIB", 0.04)
			K.shake(1.3)
			K.fov(8)
			K.speedLines(0.5, MAGENTA)
			for k = 0, 5 do
				K.at(data, T.Scream + k * 0.06, function()
					local c = from:Lerp(vp(), k / 5)
					K.ring(CFrame.lookAt(c, c + look), 4 + k * 2.2, (k % 2 == 0) and MAGENTA or CYAN, 0.3, 0.45)
				end)
			end
			K.word(cf.Position + look * 3 + up * 4.5, "LIKE & SUBSCRIBE!", 1.5, "Heavy")
			-- l'écran du téléphone se fissure et éclate
			for _, p in ipairs(frame) do
				if p.Parent then
					local d = (p.Position - vp0)
					d = d.Magnitude > 0.1 and d.Unit or look
					K.tween(p, 0.45, { CFrame = p.CFrame * CFrame.Angles(K.rng:NextNumber(-1, 1), K.rng:NextNumber(-1, 1), 0) + d * 7 + look * 4, Transparency = 1 })
				end
			end
			K.shards(vp(), 14, { CYAN, WHITE, MAGENTA }, 1.3)
			K.sound("GlassBreak", vp(), 1.2, 1)
		end)
		K.at(data, T.Stonks - 0.05, function()
			if mega then mega:Destroy() end
			if bell then bell:Destroy() end
		end)
	end)

	-- 4) STONKS ! ------------------------------------------------
	K.at(data, T.Stonks, function()
		play(K, caster, A.Stonks)
		local g = K.groundPos(vp0)
		-- caméra basse qui regarde vers le haut
		K.shot(data, "fixed", { pos = g + look * 9 + right * 6 + up * 1.2, lookAt = g + up * 7, fov = 72 })
		K.sound("Rumble", g, 1, 1.2)
		K.CFX.bigTelegraph(g, 5, T.Launch - T.Stonks, STONKS)
		K.cracks(g, 6, 4)
		-- flèche en zigzag qui pousse du sol vers le ciel
		local pts = { g - look * 3 - right * 2, g + up * 2, g + up * 5 + look * 1.5 - right * 1, g + up * 9 + look * 0.5, g + up * 16 + look * 2 + right * 1, g + up * 24 + look * 1 }
		local segs = {}
		for i = 1, #pts - 1 do
			local s = K.part({ Size = Vector3.new(1.4, 1.4, 0.1), CFrame = CFrame.lookAt(pts[i], pts[i + 1]), Color = STONKS, Material = Enum.Material.Neon, Transparency = 1 }, 3.5)
			K.track(data, s)
			segs[i] = s
		end
		local head = K.part({ Size = Vector3.new(1, 4, 4), CFrame = CFrame.new(pts[1]), Color = STONKS, Material = Enum.Material.Neon, Transparency = 1 }, 3.5)
		K.track(data, head)
		local function grow(a)
			-- avance le long de la polyligne
			local total = #pts - 1
			local x = a * total
			for i = 1, total do
				local p0, p1 = pts[i], pts[i + 1]
				local f = math.clamp(x - (i - 1), 0, 1)
				local e = p0:Lerp(p1, f)
				local len = (e - p0).Magnitude
				segs[i].Size = Vector3.new(1.4, 1.4, math.max(0.1, len))
				segs[i].CFrame = CFrame.lookAt(p0:Lerp(e, 0.5), p1)
				segs[i].Transparency = f > 0 and 0 or 1
				if (f > 0 and f < 1) or (i == total and f >= 1) then
					head.Transparency = 0
					head.CFrame = CFrame.lookAt(e, e + (p1 - p0).Unit) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.rad(45), 0, 0)
				end
			end
		end
		-- 1er bout : jaillit jusqu'à la victime (anticipation), puis tout le reste au lancement
		run(T.Launch - T.Stonks, function(a)
			grow(a * 0.3)
		end)
		K.at(data, T.Launch, function()
			run(0.45, function(a)
				grow(0.3 + a * 0.7)
			end)
			K.impactFrames("WBW", 0.05)
			K.layer({ { "Boom", 1.5 }, { "Bass", 1.3, 0.9 }, { "Explosion", 1.1, 1.1 }, { SND.Horn, 1.2, 1, 0.1 } }, g)
			K.shake(1.8)
			K.fov(10)
			K.quake(g, 11, STONKS, 1.1)
			K.pillar(g, 3, 28, STONKS, 0.45)
			K.light(g + up * 3, STONKS, 40, 8, 0.5)
			K.word(vp() + up * 3, "STONKS!!", 1.6, "Heavy")
			if target then
				local tr = target:FindFirstChild("Torso")
				if tr then
					K.CFX.trailOn(tr, STONKS, 1.0, 0, 2)
				end
			end
			-- la caméra suit la victime vers le ciel
			K.shot(data, "track", { from = g + look * 10 + right * 7 + up * 3, at = function() return vp() end, fov = 74 })
		end)
		-- feu d'artifice de confettis là-haut
		K.at(data, T.Launch + 0.45, function()
			local sky = vp() + up * 2
			K.sound(SND.Firework, sky, 1.5, 1)
			K.sound(SND.Cheer, sky, 0.8, 1)
			for k = 1, 3 do
				K.at(data, T.Launch + 0.45 + k * 0.1, function()
					local p = sky + Vector3.new(K.rng:NextNumber(-6, 6), K.rng:NextNumber(-2, 5), K.rng:NextNumber(-6, 6))
					K.sphere(p, 10, CONFETTI[k], 0.4, 1)
					K.shards(p, 16, CONFETTI, 1.4)
					K.light(p, CONFETTI[k], 40, 6, 0.4)
				end)
			end
			K.word(sky + up * 3, "#1 TRENDING!", 1.8, "Heavy")
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
	U.fx(ctx, "Rush", { dir = look, range = ctx.range })
	if not U.wait(ctx, 0.42) then
		return
	end
	if ok then
		local vr = U.root(target)
		ok = U.valid(target, ctx) and vr ~= nil and (vr.Position - cf.Position).Magnitude <= ctx.range + 6
	end
	if not ok then
		U.fx(ctx, "Whiff")
		U.wait(ctx, 0.9)
		return
	end
	-- la victime est figée sur la photo, là où elle est (au plus 12 studs, sinon on la rapproche)
	local vr = U.root(target)
	cf = U.facing(cf.Position, vr.Position)
	U.place(ctx, caster, cf)
	local d = U.flat(vr.Position - cf.Position, cf.LookVector)
	local dist = math.min((vr.Position - cf.Position).Magnitude, 12)
	local vp = U.wallSafe(cf.Position, cf.Position + d * math.max(dist, 6), 1.5)
	vp = Vector3.new(vp.X, cf.Position.Y, vp.Z)
	U.hold(ctx, target, U.facing(vp, cf.Position))
	U.fx(ctx, "Connect", { cf = cf, vp = vp })
	local tc = os.clock()
	local function at(t)
		return U.wait(ctx, math.max(0, t - (os.clock() - tc)))
	end
	for i = 1, T.BarrageN do
		if not at(T.Barrage0 + (i - 1) * T.BarrageStep) then
			return
		end
		U.hit(ctx, target, 1.2, { power = 0.3, words = { "LIKED!", "+1!", "LOVED!", "SHARED!" }, stun = 0.6 })
	end
	if not at(T.Scream + 0.12) then
		return
	end
	U.hit(ctx, target, 8, { power = 0.9, words = { "LOUD!", "HYPE!" }, stun = 0.8 })
	if not at(T.Launch) then
		return
	end
	local up = math.clamp(U.headroom(vp, 60) * 2.2, 60, 125)
	U.finish(ctx, target, 15, { launch = Vector3.new(0, up, 0) + d * 6, words = { "VIRAL!" }, splash = { radius = 12, damage = 10, center = vp } })
	at(T.End)
end

return M
