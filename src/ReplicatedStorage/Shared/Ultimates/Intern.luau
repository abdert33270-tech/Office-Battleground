--[[
	Ultimate — THE INTERN : « CAFFEINE OVERLOAD »  (module de RÉFÉRENCE pour les autres ultis)
	Cut-in : il descend un gobelet géant de café, l'écrase, l'aura explose.
	Attaque : ruée-éclair vers la cible (soft-lock devant, ~25 studs).
	Touché : cinématique ~3,2 s — blitz de 6 coups en téléportation autour de la victime (images rémanentes,
	coupes de caméra), uppercut qui l'envoie en l'air, gobelet géant invoqué au-dessus de la tête,
	SMASH vers le sol : cratère, éclaboussure de café, ondes de choc, victime PLAQUÉE au sol.
	Raté : ruée dans le vide, dérapage, café renversé (0,8 s, sans dégâts).
	Dégâts : 3 (prise) + 6×3 (blitz) + 4 (uppercut) + 12 (finisher) = 37 ; zone 10 au finisher.
	Phases envoyées au client : Cutin (auto) · Rush · Whiff · Connect · Strike(i) · Launch · Charge · Slam · Impact · End (auto)
]]
local COL = Color3.fromRGB(255, 170, 40)
local COL2 = Color3.fromRGB(255, 240, 200)
local COFFEE = Color3.fromRGB(110, 62, 30)
local CREAM = Color3.fromRGB(235, 210, 170)
local CUPW = Color3.fromRGB(250, 250, 250)

------------------------------------------------------------------------
-- Animations (format ProcAnim : p = vers l'avant, y = torsion, r = écarter ; RJ : tw, ln, sd)
------------------------------------------------------------------------
local A = {}
A.Chug = {
	{ t = 0 },
	{ t = 0.12, RS = { p = 2.5, y = 0.5, r = 0.35 }, LS = { p = 0.35, r = -0.5 }, RJ = { ln = -0.3, tw = 0.1 }, RH = { p = 0.1 }, LH = { p = -0.1 } },
	{ t = 0.3, RS = { p = 2.75, y = 0.5, r = 0.35 }, LS = { p = 0.3, r = -0.55 }, RJ = { ln = -0.42, tw = 0.12 }, RH = { p = 0.1 }, LH = { p = -0.1 } },
	{ t = 0.55, RS = { p = 2.85, y = 0.55, r = 0.3 }, LS = { p = 0.25, r = -0.6 }, RJ = { ln = -0.5, tw = 0.08 } },
	{ t = 0.7, RS = { p = 2.7, y = 0.5, r = 0.35 }, LS = { p = 0.3, r = -0.55 }, RJ = { ln = -0.45, tw = 0.14 } },
	-- écrase le gobelet (poing serré devant)
	{ t = 0.8, RS = { p = 1.5, y = 0.2, r = -0.3 }, LS = { p = 1.4, y = -0.4, r = -0.2 }, RJ = { ln = 0.35, tw = -0.1 }, RH = { p = 0.45, r = -0.25 }, LH = { p = 0.45, r = -0.25 } },
	{ t = 0.86, RS = { p = 1.55, y = 0.3, r = -0.3 }, LS = { p = 1.45, y = -0.45, r = -0.2 }, RJ = { ln = 0.42, sd = 0.06 }, RH = { p = 0.5, r = -0.3 }, LH = { p = 0.5, r = -0.3 } },
	-- explosion d'aura : bras grands ouverts, buste en arrière
	{ t = 0.95, RS = { p = 1.0, r = -1.45 }, LS = { p = 1.0, r = -1.45 }, RJ = { ln = -0.38 }, RH = { p = -0.15, r = -0.4 }, LH = { p = -0.15, r = -0.4 } },
	{ t = 1.25, RS = { p = 0.9, r = -1.35 }, LS = { p = 0.9, r = -1.35 }, RJ = { ln = -0.3 }, RH = { p = -0.1, r = -0.35 }, LH = { p = -0.1, r = -0.35 } },
}
A.Dash = {
	{ t = 0 },
	{ t = 0.06, RS = { p = -1.1, r = -0.2 }, LS = { p = -1.1, r = -0.2 }, RJ = { ln = 0.75 }, RH = { p = 0.9 }, LH = { p = -0.8 } },
	{ t = 0.45, RS = { p = -1.2, r = -0.2 }, LS = { p = -1.2, r = -0.2 }, RJ = { ln = 0.8 }, RH = { p = -0.7 }, LH = { p = 0.9 } },
}
A.Skid = {
	{ t = 0 },
	{ t = 0.08, RS = { p = 1.2, r = -0.9 }, LS = { p = 1.6, r = -0.6 }, RJ = { ln = -0.35, sd = 0.2 }, RH = { p = 1.0 }, LH = { p = -0.6 } },
	{ t = 0.4, RS = { p = 1.0, r = -1.1 }, LS = { p = 1.3, r = -0.8 }, RJ = { ln = -0.25, sd = 0.25 }, RH = { p = 0.8 }, LH = { p = -0.5 } },
	{ t = 0.75, RS = { p = 0.2, r = -0.2 }, LS = { p = 0.4, r = -0.3 }, RJ = { ln = 0.45, sd = -0.1 } },
}
A.Grab = {
	{ t = 0 },
	{ t = 0.05, RS = { p = 1.75, y = 0.1 }, LS = { p = 0.6, y = 0.7 }, RJ = { tw = 0.55, ln = 0.3 }, RH = { p = -0.6 }, LH = { p = 0.8 } },
	{ t = 0.35, RS = { p = 1.8, y = 0.1 }, LS = { p = 0.6, y = 0.7 }, RJ = { tw = 0.5, ln = 0.32 }, RH = { p = -0.6 }, LH = { p = 0.8 } },
}
-- coups du blitz (un par téléportation)
A.Strikes = {
	{ { t = 0 }, { t = 0.04, RS = { p = 2.0, y = 0.1 }, LS = { p = 0.4, y = 0.7 }, RJ = { tw = 0.65, ln = 0.3 }, RH = { p = -0.6 }, LH = { p = 0.8 } }, { t = 0.16, RS = { p = 1.9, y = 0.1 }, LS = { p = 0.45, y = 0.7 }, RJ = { tw = 0.55, ln = 0.28 }, RH = { p = -0.55 }, LH = { p = 0.75 } } },
	{ { t = 0 }, { t = 0.04, LS = { p = 2.0, y = 0.1 }, RS = { p = 0.4, y = 0.7 }, RJ = { tw = -0.65, ln = 0.3 }, LH = { p = -0.6 }, RH = { p = 0.8 } }, { t = 0.16, LS = { p = 1.9, y = 0.1 }, RS = { p = 0.45, y = 0.7 }, RJ = { tw = -0.55, ln = 0.28 }, LH = { p = -0.55 }, RH = { p = 0.75 } } },
	-- coup de pied retourné
	{ { t = 0 }, { t = 0.04, RH = { p = 1.9, r = -0.3 }, LH = { p = -0.3 }, RS = { p = 0.5, r = -0.8 }, LS = { p = 0.9, r = -0.6 }, RJ = { tw = -0.7, ln = -0.25, sd = 0.2 } }, { t = 0.16, RH = { p = 1.7, r = -0.25 }, LH = { p = -0.25 }, RS = { p = 0.45, r = -0.8 }, LS = { p = 0.8, r = -0.6 }, RJ = { tw = -0.6, ln = -0.2, sd = 0.18 } } },
	-- coude
	{ { t = 0 }, { t = 0.04, LS = { p = 1.5, y = 1.2, r = 0.4 }, RS = { p = -0.5, r = -0.3 }, RJ = { tw = -0.85, ln = 0.2 }, RH = { p = 0.5 }, LH = { p = -0.4 } }, { t = 0.16, LS = { p = 1.45, y = 1.15, r = 0.4 }, RS = { p = -0.45, r = -0.3 }, RJ = { tw = -0.75, ln = 0.2 }, RH = { p = 0.45 }, LH = { p = -0.35 } } },
	-- revers tournoyant
	{ { t = 0 }, { t = 0.04, RS = { p = 1.6, y = -0.4, r = -1.2 }, LS = { p = 0.3, r = -0.5 }, RJ = { tw = 0.95, ln = 0.15 }, RH = { p = -0.3, r = -0.2 }, LH = { p = 0.5 } }, { t = 0.16, RS = { p = 1.5, y = -0.35, r = -1.1 }, LS = { p = 0.3, r = -0.5 }, RJ = { tw = 0.85, ln = 0.15 } } },
	-- double poing
	{ { t = 0 }, { t = 0.04, RS = { p = 1.85, y = 0.15, r = 0.2 }, LS = { p = 1.85, y = 0.15, r = 0.2 }, RJ = { ln = 0.45 }, RH = { p = -0.7 }, LH = { p = 0.9 } }, { t = 0.16, RS = { p = 1.8, y = 0.15, r = 0.2 }, LS = { p = 1.8, y = 0.15, r = 0.2 }, RJ = { ln = 0.42 }, RH = { p = -0.65 }, LH = { p = 0.85 } } },
}
A.Uppercut = {
	{ t = 0, RS = { p = -0.5, r = -0.2 }, LS = { p = 0.8, y = 0.6 }, RJ = { ln = 0.5, tw = 0.4 }, RH = { p = 0.7 }, LH = { p = 0.7 } },
	{ t = 0.07, RS = { p = 3.05, y = 0.2, r = 0.2 }, LS = { p = -0.4, r = -0.4 }, RJ = { ln = -0.4, tw = -0.35 }, RH = { p = -0.3 }, LH = { p = 1.3 } },
	{ t = 0.35, RS = { p = 3.0, y = 0.2, r = 0.2 }, LS = { p = -0.35, r = -0.4 }, RJ = { ln = -0.35, tw = -0.3 }, RH = { p = -0.25 }, LH = { p = 1.2 } },
}
A.Overhead = {
	{ t = 0 },
	{ t = 0.12, RS = { p = 3.1, r = 0.2 }, LS = { p = 3.1, r = 0.2 }, RJ = { ln = -0.4 }, RH = { p = 0.4 }, LH = { p = -0.6 } },
	{ t = 0.5, RS = { p = 3.0, r = 0.25 }, LS = { p = 3.0, r = 0.25 }, RJ = { ln = -0.5 }, RH = { p = 0.45 }, LH = { p = -0.65 } },
}
A.Slam = {
	{ t = 0, RS = { p = 3.1, r = 0.2 }, LS = { p = 3.1, r = 0.2 }, RJ = { ln = -0.5 } },
	{ t = 0.1, RS = { p = 0.9, r = 0.15 }, LS = { p = 0.9, r = 0.15 }, RJ = { ln = 0.85 }, RH = { p = 1.0 }, LH = { p = -0.5 } },
	{ t = 0.7, RS = { p = 0.8, r = 0.1 }, LS = { p = 0.8, r = 0.1 }, RJ = { ln = 0.8 }, RH = { p = 0.95 }, LH = { p = -0.45 } },
}
A.Land = {
	{ t = 0, RS = { p = 0.8 }, LS = { p = 0.8 }, RJ = { ln = 0.8 } },
	{ t = 0.25, RS = { p = -0.7, r = -0.45 }, LS = { p = 1.35, y = 0.3 }, RJ = { ln = 0.3, tw = 0.35 }, RH = { p = 0.9 }, LH = { p = -0.55 } },
	{ t = 0.75, RS = { p = -0.65, r = -0.45 }, LS = { p = 1.3, y = 0.3 }, RJ = { ln = 0.28, tw = 0.3 }, RH = { p = 0.85 }, LH = { p = -0.5 } },
}

local state = {} -- [seq] = données partagées entre phases (client)

------------------------------------------------------------------------
-- Gobelet géant (client)
------------------------------------------------------------------------
local function giantCup(K, data, scale)
	local parts = {}
	local function add(size, off, color, mat)
		local p = K.part({ Shape = K.CYL, Size = size * scale, Color = color, Material = mat or Enum.Material.SmoothPlastic }, 4)
		K.track(data, p)
		table.insert(parts, { p = p, off = CFrame.new(off * scale) * K.UPRIGHT })
		return p
	end
	add(Vector3.new(7, 5.6, 5.6), Vector3.new(0, 0, 0), CUPW)                        -- corps
	add(Vector3.new(2.6, 5.8, 5.8), Vector3.new(0, -0.6, 0), COFFEE)                 -- manchon
	add(Vector3.new(0.7, 6, 6), Vector3.new(0, 3.6, 0), Color3.fromRGB(60, 40, 30))  -- couvercle
	add(Vector3.new(0.3, 4.6, 4.6), Vector3.new(0, 4.0, 0), COL, Enum.Material.Neon) -- café qui déborde (lueur)
	local glow = K.part({ Shape = K.BALL, Size = Vector3.one * 9 * scale, Color = COL, Material = Enum.Material.Neon, Transparency = 0.75 }, 4)
	K.track(data, glow)
	table.insert(parts, { p = glow, off = CFrame.new() })
	return parts
end

local function placeCup(parts, cf)
	for _, e in ipairs(parts) do
		if e.p.Parent then
			e.p.CFrame = cf * e.off
		end
	end
end

------------------------------------------------------------------------
-- Effets par phase (client)
------------------------------------------------------------------------
local Phase = {}

function Phase.Cutin(K, data)
	local c = data.caster
	local root = K.root(c)
	if not root then
		return
	end
	K.anim(c, A.Chug)
	-- gobelet dans la main droite (le bras pointe vers -Y)
	local cup = K.prop(data, c, "Right Arm", Vector3.new(1.9, 1.35, 1.35), CFrame.new(0, -1.7, -0.25) * K.UPRIGHT, CUPW, K.CYL)
	local sleeve = K.prop(data, c, "Right Arm", Vector3.new(0.8, 1.42, 1.42), CFrame.new(0, -1.55, -0.25) * K.UPRIGHT, COFFEE, K.CYL)
	local lid = K.prop(data, c, "Right Arm", Vector3.new(0.25, 1.4, 1.4), CFrame.new(0, -0.72, -0.25) * K.UPRIGHT, Color3.fromRGB(60, 40, 30), K.CYL)
	if cup then
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(0.9, 0, 0)
		att.Parent = cup
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/smoke_main.dds"
		pe.Color = ColorSequence.new(Color3.new(1, 1, 1))
		pe.Transparency = NumberSequence.new(0.5, 1)
		pe.Size = NumberSequence.new(0.5, 1.6)
		pe.Lifetime = NumberRange.new(0.5, 0.8)
		pe.Speed = NumberRange.new(2, 4)
		pe.Rate = 30
		pe.Parent = att
	end
	K.sound("Charge", root.Position, 0.9)
	K.at(data, 0.25, function()
		K.sound("Eat", root.Position, 1)
	end)
	K.at(data, 0.5, function()
		K.sound("Eat", root.Position, 1, 1.15)
		K.implode(root.Position + Vector3.new(0, 1, 0), 6, { COL, K.WHITE }, 14, 0.3)
	end)
	-- gobelet écrasé
	K.at(data, 0.8, function()
		local hand = c:FindFirstChild("Right Arm")
		local hp = hand and (hand.CFrame * CFrame.new(0, -1.2, 0)).Position or root.Position
		for _, p in ipairs({ cup, sleeve, lid }) do
			if p and p.Parent then
				p:Destroy()
			end
		end
		K.shards(hp, 8, { CUPW, COFFEE }, 1)
		K.sound("Crash", hp, 1)
		K.sound("Splat", hp, 1)
		K.sparks(hp, 18, COL)
		K.debris(hp, 8, { COFFEE, CREAM }, 18, 0.5)
		K.freezeAnim(c, 0.06)
	end)
	-- explosion d'aura
	K.at(data, 0.92, function()
		local p = root.Position
		local g = K.groundPos(p)
		K.layer({ { "PowerUp", 1.2 }, { "Lightning", 0.8 }, { "Boom", 0.7, 1.1 } }, p)
		K.shockwave(g + Vector3.new(0, 0.2, 0), 14, COL)
		K.shockwave(g + Vector3.new(0, 0.25, 0), 9, K.WHITE)
		K.sphere(p, 10, COL, 0.3)
		K.light(p, COL, 26, 6, 0.4)
		K.pillar(g, 2.5, 16, COL, 0.35)
		for i = 1, 4 do
			local a = i * math.pi / 2 + K.rng:NextNumber(-0.4, 0.4)
			K.bolt(p + Vector3.new(0, 1, 0), p + Vector3.new(math.cos(a) * 6, K.rng:NextNumber(-1, 4), math.sin(a) * 6), i % 2 == 0 and K.WHITE or COL, 0.3, 0.2, 1)
		end
		local head = c:FindFirstChild("Head")
		K.word((head and head.Position or p) + Vector3.new(0, 3, 0), "CAFFEINE!", 1.25)
		if K.isCaster(data) then
			K.shake(1.1)
			K.fov(10)
		end
	end)
end

function Phase.Rush(K, data)
	local c = data.caster
	local root = K.root(c)
	if not root then
		return
	end
	K.anim(c, A.Dash)
	K.layer({ { "Whoosh", 1.2 }, { "Dash", 1 }, { "Whoosh3", 0.7, 1.2 } }, root.Position)
	K.shot(data, "follow", { only = "caster", subject = c, offset = CFrame.new(2.5, 2.2, 9), lookOffset = Vector3.new(0, 1, -6), fov = 82, flat = true })
	if K.isCaster(data) then
		K.speedLines(0.45, COL)
	end
	local t0 = os.clock()
	local last = root.Position
	task.spawn(function()
		local n = 0
		while os.clock() - t0 < 0.45 and root.Parent do
			n += 1
			local p = root.Position
			if (p - last).Magnitude > 1 then
				K.streak(last, p, COL, 0.9, 0.25)
				if n % 2 == 0 then
					K.afterimage(c, COL, 0.3, 0.45)
				end
				K.dust(K.groundPos(p), 2, CREAM, 2)
			end
			last = p
			task.wait(0.05)
		end
	end)
end

function Phase.Whiff(K, data)
	local c = data.caster
	local p = data.p
	local g = data.g or K.groundPos(p)
	K.anim(c, A.Skid)
	K.release(data)
	K.layer({ { "Slip", 1 }, { "Splat", 1 }, { "SlideWhistle", 0.7, 1, 0.25 } }, p)
	K.dust(g, 5, CREAM, 8)
	K.shockwave(g + Vector3.new(0, 0.2, 0), 7, COFFEE)
	-- flaque de café renversé
	local puddle = K.part({ Shape = K.CYL, Size = Vector3.new(0.1, 1, 1), CFrame = CFrame.new(g + Vector3.new(0, 0.07, 0) + (data.dir or Vector3.zero) * 2) * K.UPRIGHT, Color = COFFEE, Transparency = 0.15 }, 2.4)
	K.tween(puddle, 0.3, { Size = Vector3.new(0.1, 7, 7) }, Enum.EasingStyle.Back)
	task.delay(1.8, function()
		if puddle.Parent then
			K.tween(puddle, 0.5, { Transparency = 1 })
		end
	end)
	K.debris(p, 10, { COFFEE, CREAM }, 16, 0.5)
	K.word(p + Vector3.new(0, 3.5, 0), "MISSED!", 0.9, "Funny")
end

function Phase.Connect(K, data)
	local c, v = data.caster, data.target
	local p, a = data.p, data.a
	local toC = (a - p)
	toC = Vector3.new(toC.X, 0, toC.Z)
	toC = toC.Magnitude > 0.05 and toC.Unit or Vector3.new(0, 0, 1)
	state[data.seq] = { p = p, toC = toC }
	K.anim(c, A.Grab)
	K.impactFrames("BWB", 0.035)
	K.slowmo({ c, v }, 0.15)
	K.letterbox(data, true, 0.15)
	K.layer({ { "Punch", 1.3 }, { "BigImpact", 1.1 }, { "AnimeHit", 0.9 } }, p)
	if K.involved(data) then
		K.sound("Sting", nil, 0.55)
		K.shake(1.2)
	end
	K.sphere(p, 8, COL, 0.25)
	K.ring(CFrame.lookAt(p, a), 12, K.WHITE, 0.3)
	K.sparks(p, 24, COL)
	-- caméra : de côté, légère orbite autour du duo
	local side = toC:Cross(Vector3.yAxis)
	K.shot(data, "orbit", { at = p, radius = 12, height = 3, angle = 0, speed = 38, basis = CFrame.lookAt(p, p + side), lookOffset = Vector3.new(0, 0.3, 0), fov = 58 })
end

local STRIKE_SND = { "Punch", "Punch2", "Hit", "Punch", "Punch2", "Explosion2" }
function Phase.Strike(K, data)
	local c = data.caster
	local i = data.i or 1
	local p, from, to = data.p, data.from, data.to
	local st = state[data.seq] or { p = p, toC = Vector3.new(0, 0, 1) }
	K.afterimage(c, COL, 0.28, 0.4)
	K.streak(from + Vector3.new(0, 0.6, 0), to + Vector3.new(0, 0.6, 0), COL, 0.8, 0.2)
	K.sound("Teleport", to, 0.35, 1.4)
	K.anim(c, A.Strikes[((i - 1) % #A.Strikes) + 1])
	local dir = p - to
	dir = dir.Magnitude > 0.05 and dir.Unit or Vector3.new(0, 0, -1)
	K.at(data, 0.03, function()
		K.sparks(p, 14, COL)
		K.ring(CFrame.lookAt(p, p + dir), 7, K.WHITE, 0.2, 0.3)
		K.sound(STRIKE_SND[i] or "Punch", p, 1.1, 0.95 + i * 0.04)
		K.sound("Whoosh2", p, 0.5, 1.3)
		K.light(p, COL, 14, 3, 0.15)
		if i == 3 or i == 6 then
			K.bigImpact(p, dir, 0.9, COL)
		end
		if K.involved(data) then
			K.shake(0.55 + i * 0.06)
			if i % 2 == 0 then
				K.impactFrames(i == 6 and "BW" or "W", 0.035)
			end
		end
	end)
	-- coupes de caméra (tous les 2 coups)
	if i == 1 or i == 3 or i == 5 then
		local angles = { [1] = 55, [3] = -130, [5] = 160 }
		local heights = { [1] = 1.5, [3] = -0.6, [5] = 6 }
		local basis = CFrame.lookAt(st.p, st.p + st.toC)
		local camPos = st.p + (basis - basis.Position) * Vector3.new(math.sin(math.rad(angles[i])) * 13, heights[i], -math.cos(math.rad(angles[i])) * 13)
		K.shot(data, "fixed", { pos = camPos, lookAt = st.p + Vector3.new(0, 0.4, 0), fov = i == 5 and 64 or 54 })
	end
end

function Phase.Launch(K, data)
	local c = data.caster
	local p, top, g = data.p, data.top, data.g
	K.anim(c, A.Uppercut)
	K.layer({ { "Uppercut", 1.3 }, { "Whoosh3", 1 }, { "PunchHeavy", 1.1 } }, p)
	K.airRing(p, Vector3.yAxis, 10, COL, 0.35)
	K.ring(CFrame.lookAt(p, p + Vector3.yAxis), 11, K.WHITE, 0.3)
	K.pillar(g, 2.6, (top - g).Magnitude + 6, COL, 0.35)
	K.sphere(p, 7, COL2, 0.2)
	K.word(p + Vector3.new(0, 2, 0), "UP!", 1)
	if K.involved(data) then
		K.impactFrames("BW", 0.035)
		K.shake(1.1)
		K.speedLines(0.4, K.WHITE)
	end
	local st = state[data.seq]
	local side = st and st.toC:Cross(Vector3.yAxis) or Vector3.xAxis
	local v = data.target
	K.shot(data, "track", { from = g + side * 7 + Vector3.new(0, 1.2, 0), at = function()
		return K.root(v) and K.root(v).Position or top
	end, fov = 72 })
end

function Phase.Charge(K, data)
	local c = data.caster
	local root = K.root(c)
	local top, g = data.p, data.g
	if not root then
		return
	end
	K.anim(c, A.Overhead)
	local parts = giantCup(K, data, 0.25)
	state[data.seq] = state[data.seq] or {}
	state[data.seq].cup = parts
	local t0 = os.clock()
	local cupScale = 0.25
	task.spawn(function()
		while os.clock() - t0 < 0.55 and root.Parent do
			local a = math.clamp((os.clock() - t0) / 0.25, 0, 1)
			local s = 0.25 + 0.75 * (1 - (1 - a) ^ 3)
			if math.abs(s - cupScale) > 0.01 then
				for _, e in ipairs(parts) do
					local base = e.p:GetAttribute("BaseSize") or e.p.Size / cupScale
					e.p:SetAttribute("BaseSize", base)
					e.p.Size = base * s
					e.off = CFrame.new(e.off.Position / cupScale * s) * e.off.Rotation
				end
				cupScale = s
			end
			placeCup(parts, root.CFrame * CFrame.new(0, 3.2 + 4.5 * s, 0) * CFrame.Angles(0, (os.clock() - t0) * 6, 0))
			task.wait()
		end
	end)
	K.layer({ { "FinalCharge", 1.1 }, { "Windup", 0.8 } }, root.Position)
	K.implode(root.Position + Vector3.new(0, 7, 0), 9, { COL, K.WHITE, COL2 }, 16, 0.45)
	K.light(root.Position + Vector3.new(0, 7, 0), COL, 30, 5, 0.6)
	K.darken(true, 0.6, 0.15)
	local st = state[data.seq]
	local side = st and st.toC and st.toC:Cross(Vector3.yAxis) or Vector3.xAxis
	K.shot(data, "fixed", { pos = top + side * 13 + Vector3.new(0, -5, 0), lookAt = top + Vector3.new(0, 3, 0), fov = 66 })
	if K.involved(data) then
		K.shake(0.5)
	end
end

function Phase.Slam(K, data)
	local c = data.caster
	local from, g = data.from, data.g
	K.anim(c, A.Slam)
	K.sound("Whoosh", from, 1.3, 0.8)
	K.streak(from, g + Vector3.new(0, 1, 0), COL, 2.2, 0.3)
	local st = state[data.seq]
	local parts = st and st.cup
	if parts then
		local start = os.clock()
		local root = K.root(c)
		local cf0 = root and root.CFrame * CFrame.new(0, 7.7, 0) or CFrame.new(from + Vector3.new(0, 6, 0))
		task.spawn(function()
			while os.clock() - start < 0.12 do
				local a = (os.clock() - start) / 0.12
				placeCup(parts, cf0:Lerp(CFrame.new(g + Vector3.new(0, 3.5, 0)) * CFrame.Angles(0.5, 0, 0), a * a))
				task.wait()
			end
		end)
	end
	local side = st and st.toC and st.toC:Cross(Vector3.yAxis) or Vector3.xAxis
	K.shot(data, "fixed", { pos = g + side * 16 + (st and st.toC or Vector3.zero) * 6 + Vector3.new(0, 2.2, 0), lookAt = g + Vector3.new(0, 2, 0), fov = 62 })
end

function Phase.Impact(K, data)
	local c = data.caster
	local g = data.g
	local st = state[data.seq]
	-- le gobelet éclate
	if st and st.cup then
		for _, e in ipairs(st.cup) do
			if e.p.Parent then
				e.p:Destroy()
			end
		end
		st.cup = nil
	end
	K.impactFrames("BWBWB", 0.04)
	K.layer({ { "Explosion", 1.3 }, { "Bass", 1.2 }, { "Boom", 1.1, 1, 0.04 }, { "GroundSlam", 1.2 }, { "Splash", 1.2 } }, g)
	if K.involved(data) then
		K.shake(2.2)
		K.fov(16)
		K.flash(K.WHITE, 0.35, 0.9)
	elseif K.near(g, 90) then
		K.shake(1)
		K.flash(COL, 0.3, 0.4)
	end
	K.shockwave(g + Vector3.new(0, 0.2, 0), 22, COL)
	task.delay(0.07, function()
		K.shockwave(g + Vector3.new(0, 0.25, 0), 30, K.WHITE)
	end)
	task.delay(0.14, function()
		K.shockwave(g + Vector3.new(0, 0.3, 0), 16, COFFEE)
	end)
	K.crater(g, 10, COL, 3.5)
	K.sphere(g + Vector3.new(0, 2, 0), 18, COL, 0.35)
	K.sphere(g + Vector3.new(0, 2, 0), 10, K.WHITE, 0.2)
	K.pillar(g, 4.5, 30, COL, 0.5)
	K.light(g + Vector3.new(0, 4, 0), COL, 45, 8, 0.7)
	K.debris(g + Vector3.new(0, 1, 0), 12, { COFFEE, CREAM, Color3.fromRGB(140, 130, 120) }, 38, 1.1)
	K.shards(g + Vector3.new(0, 2, 0), 16, { CUPW, COFFEE }, 1.6)
	K.word(g + Vector3.new(0, 7, 0), "OVERLOADED!", 1.6)
	-- vapeur de café qui monte
	for i = 1, 4 do
		task.delay(0.1 * i, function()
			K.puff(g + Vector3.new(K.rng:NextNumber(-4, 4), 1 + i, K.rng:NextNumber(-4, 4)), 2.2)
		end)
	end
	K.anim(c, A.Land)
	local side = st and st.toC and st.toC:Cross(Vector3.yAxis) or Vector3.xAxis
	local toC = st and st.toC or Vector3.new(0, 0, 1)
	local camA = g + side * 15 + toC * 9 + Vector3.new(0, 1.5, 0)
	local camB = g + side * 21 + toC * 13 + Vector3.new(0, 7, 0)
	K.shot(data, "dolly", { from = CFrame.lookAt(camA, g + Vector3.new(0, 1.5, 0)), to = CFrame.lookAt(camB, g), dur = 0.8, style = Enum.EasingStyle.Quart, fov0 = 50, fov1 = 70 })
	K.at(data, 0.5, function()
		K.letterbox(data, false, 0.3)
	end)
end

function Phase.End(K, data)
	state[data.seq] = nil
end

------------------------------------------------------------------------
return {
	Name = "Caffeine Overload",
	Desc = "Chug a giant coffee, blitz your target with 6 teleport strikes, launch them and SLAM them into the floor with a giant cup.",
	Color = COL,
	Color2 = COL2,
	Range = 25,
	Angle = 70,
	Startup = 1.1,

	Server = function(U, caster, target, ctx)
		U.fx(ctx, "Rush")
		local hit = U.rush(ctx, target, { speed = 130, contact = 4.2, maxTime = 0.45 })
		if not hit then
			local cf = U.currentCF(ctx, caster)
			U.fx(ctx, "Whiff", { p = cf.Position, dir = cf.LookVector, g = U.ground(cf.Position) })
			U.wait(ctx, 0.8)
			return
		end
		local vr = U.root(target)
		local ccf = U.currentCF(ctx, caster)
		local g = U.ground(vr.Position)
		local center = Vector3.new(vr.Position.X, g.Y + 3.2, vr.Position.Z)
		local toC = U.flat(ccf.Position - center, -ccf.LookVector)
		local yaw = math.atan2(-toC.X, -toC.Z)
		-- PRISE : la victime est figée face au stagiaire
		U.hold(ctx, target, U.facing(center, center + toC))
		local a0 = center + toC * 4
		U.place(ctx, caster, U.facing(a0, center))
		U.fx(ctx, "Connect", { p = center, a = a0 })
		U.hit(ctx, target, 3, { words = { "GOTCHA!" }, power = 0.7 })
		if not U.wait(ctx, 0.4) then
			return
		end
		-- BLITZ : 6 coups en téléportation autour de la victime
		local base = math.deg(math.atan2(toC.X, -toC.Z))
		local ANG = { 150, -70, 60, -150, 100, -20 }
		local WORDS = { { "BAP!" }, { "ZIP!" }, { "POW!" }, { "WHAM!" }, { "BOP!" }, { "KAPOW!" } }
		local last = a0
		for i, a in ipairs(ANG) do
			local pos = U.around(center, base + a, 3.8, 0)
			pos = U.wallSafe(center, pos, 1.2)
			U.place(ctx, caster, U.facing(pos, center))
			U.fx(ctx, "Strike", { i = i, from = last, to = pos, p = center })
			last = pos
			U.hit(ctx, target, 3, { words = WORDS[i], power = 0.55 + i * 0.06 })
			if not U.wait(ctx, 0.18) then
				return
			end
		end
		-- UPPERCUT : la victime monte (plafond vérifié)
		local up = math.clamp(U.headroom(center, 16), 3, 13)
		local top = center + Vector3.new(0, up, 0)
		local front = center + toC * 3
		U.place(ctx, caster, U.facing(front, center))
		U.fx(ctx, "Launch", { p = center, top = top, g = g })
		U.hit(ctx, target, 4, { words = { "UPPERCUT!" }, power = 0.95 })
		U.glide(ctx, target, CFrame.new(top) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(-0.6, 0, 0), 0.3, "Out")
		U.glide(ctx, caster, U.facing(front + Vector3.new(0, up * 0.55, 0), top), 0.3, "Out")
		if not U.wait(ctx, 0.32) then
			return
		end
		-- CHARGE : gobelet géant au-dessus de la tête
		local cPos = top + toC * 2.6 + Vector3.new(0, math.clamp(U.headroom(top, 6) - 1, 0, 2), 0)
		U.place(ctx, caster, U.facing(cPos, top))
		U.fx(ctx, "Charge", { p = top, g = g })
		if not U.wait(ctx, 0.5) then
			return
		end
		-- SMASH vers le sol
		U.fx(ctx, "Slam", { from = top, g = g })
		U.glide(ctx, target, CFrame.new(g + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.pi / 2, 0, 0), 0.12, "In")
		U.glide(ctx, caster, U.facing(g + toC * 3 + Vector3.new(0, 3, 0), g), 0.12, "In")
		if not U.wait(ctx, 0.12) then
			return
		end
		U.fx(ctx, "Impact", { g = g })
		U.finish(ctx, target, 12, { pin = true, words = { "OVERLOADED!" }, power = 1.6, splash = { radius = 13, damage = 10, center = g } })
		U.wait(ctx, 0.75)
	end,

	Client = function(K, data)
		local fn = Phase[data.phase]
		if fn then
			fn(K, data)
		end
	end,
}
