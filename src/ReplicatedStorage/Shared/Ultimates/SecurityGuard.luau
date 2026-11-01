--[[
	Ultime du SECURITY GUARD — « MAXIMUM SECURITY » (G pendant l'Overtime « Lockdown »).
	Chorégraphie (touché) :
		1) sirènes rouge/bleu + projecteur venu du ciel qui fige la victime : « FREEZE! »
		2) lancer de menottes avec chaîne, CLIC, il tire la victime à lui, puis 5 coups de matraque (le dernier la renvoie)
		3) une cellule de prison tombe du ciel autour d'elle (CLANG, poussière)
		4) il presse la télécommande LOCKDOWN : barreaux électrifiés (3 décharges), puis la cage implose
		   -> explosion de sirène rouge/bleu, victime PLAQUÉE au sol, cratère, « CASE CLOSED! »
	Raté : le projecteur balaie le sol, les menottes retombent dans le vide, « SUSPECT ESCAPED! ».
	Dégâts : 2 + 4x2.5 + 4 + 3x2 + 14 = 36 (+ 10 de zone).
]]
local RunService = game:GetService("RunService")

local NAVY, RED, BLUE, STEEL, DARK = Color3.fromRGB(60, 80, 140), Color3.fromRGB(255, 50, 50), Color3.fromRGB(60, 140, 255), Color3.fromRGB(200, 205, 215), Color3.fromRGB(25, 25, 32)
local LIGHT, ZAP = Color3.fromRGB(255, 250, 190), Color3.fromRGB(170, 230, 255)
local SFX = { Wail = 4832498807, Cuffs = 9114764731, Bang = 9114225758, Grate = 9116635173, Thunder = 9126082854, Boom = 2103404398, Blast = 9114362625, Buzz = 9113086839 }

local T = { cuffThrow = 0.5, cuffHit = 0.72, yank = 0.78, batons = { 1.05, 1.22, 1.39, 1.56 }, big = 1.8, cage = 2.05, cageLand = 2.3, remote = 2.45, zaps = { 2.6, 2.75, 2.9 }, implode = 3.1, done = 3.45 }
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

local ULT = {
	Name = "Maximum Security",
	-- v3 : titres de temps forts (UltimateController) ; Anticipate = poses d'armement avant ces coups
	Beats = { Lock = { { 0, "FREEZE!" }, { T.batons[1], "BATON CHECK" } }, Cage = { { T.cage - T.big, "LOCKDOWN" } } },
	Anticipate = { Lock = { T.big } },
	Desc = "Spotlight, cuff and beat them down, drop a jail cell on them and electrify it.",
	Color = NAVY,
	Color2 = RED,
	Range = 25,
	Angle = 70,
	Startup = 1.0,
}

------------------------------------------------------------------------
-- SERVEUR
------------------------------------------------------------------------
function ULT.Server(U, caster, target, ctx)
	local cf = U.currentCF(ctx, caster)
	local look = U.flat(cf.LookVector)
	cf = CFrame.lookAt(cf.Position, cf.Position + look)
	if not target or not U.valid(target, ctx) then
		U.fx(ctx, "Whiff", { cf = cf })
		U.wait(ctx, 1.0)
		return
	end
	local vr = U.root(target)
	local function held()
		return ctx.held[target] ~= nil
	end
	local start = U.facing(vr.Position, cf.Position)
	U.hold(ctx, target, start)
	local c0 = os.clock()
	local function at(t)
		return U.wait(ctx, math.max(0, t - (os.clock() - c0)))
	end
	U.fx(ctx, "Lock", { cf = cf, vp = vr.Position })

	-- 2) menottes + traction
	if not at(T.cuffHit) then
		return
	end
	U.hit(ctx, target, 2, { words = { "CUFFED!" }, power = 0.5 })
	local near = U.wallSafe(cf.Position, (cf * CFrame.new(0, 0, -3.8)).Position, 1)
	local nearCF = U.facing(Vector3.new(near.X, vr.Position.Y, near.Z), cf.Position)
	if not at(T.yank) then
		return
	end
	if held() then
		U.glide(ctx, target, nearCF, 0.2, "In")
	end
	local bw = { { "BONK!" }, { "WHACK!" }, { "THWACK!" }, { "BAM!" } }
	for i, t in ipairs(T.batons) do
		if not at(t) then
			return
		end
		U.hit(ctx, target, 2.5, { words = bw[i], power = 0.6 })
		if held() then
			U.place(ctx, target, nearCF * CFrame.new(0, 0, 0.25 * i) * CFrame.Angles(0, (i % 2 == 0) and 0.3 or -0.3, (i % 2 == 0) and 0.12 or -0.12))
		end
	end
	if not at(T.big) then
		return
	end
	U.hit(ctx, target, 4, { words = { "OUT!" }, power = 0.9 })
	local cp = U.wallSafe(near, (cf * CFrame.new(0, 0, -9)).Position, 2)
	local cageCF = U.facing(Vector3.new(cp.X, vr.Position.Y, cp.Z), cf.Position)
	if held() then
		U.glide(ctx, target, cageCF, 0.22, "Out")
	end
	U.fx(ctx, "Cage", { cf = cf, cp = U.ground(cp) })

	-- 4) électrocution puis implosion
	local zw = { { "ZAP!" }, { "BZZT!" }, { "ZZZT!" } }
	for i, t in ipairs(T.zaps) do
		if not at(t) then
			return
		end
		U.hit(ctx, target, 2, { words = zw[i], power = 0.55 })
		if held() then
			U.place(ctx, target, cageCF * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, (i % 2 == 0) and 0.2 or -0.2))
		end
	end
	if not at(T.implode) then
		return
	end
	if held() then
		U.place(ctx, target, cageCF)
	end
	U.fx(ctx, "Implode", { p = U.ground(cp), cf = cf })
	U.finish(ctx, target, 14, { pin = true, words = { "CASE CLOSED!" }, splash = { radius = 12, damage = 10 } })
	at(T.done)
end

------------------------------------------------------------------------
-- CLIENT
------------------------------------------------------------------------
local runs = {}

local ANIM = {}
ANIM.Radio = { -- radio à la bouche pendant le cut-in, puis désigne la cible
	{ t = 0 },
	{ t = 0.12, RS = { p = 2.7, y = 1.25 }, LS = { p = 0.3, r = -0.4 }, RJ = { tw = 0.2, ln = 0.1 }, RH = { p = -0.15 }, LH = { p = 0.25 } },
	{ t = 0.55, RS = { p = 2.75, y = 1.25 }, LS = { p = 0.35, r = -0.4 }, RJ = { tw = 0.25, ln = 0.12 } },
	{ t = 0.7, RS = { p = 2.7, y = 1.25 }, LS = { p = 1.7, y = 0 }, RJ = { tw = -0.3, ln = 0.05 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
	{ t = 1.0, RS = { p = 2.7, y = 1.25 }, LS = { p = 1.75, y = 0 }, RJ = { tw = -0.3, ln = 0.05 }, RH = { p = -0.3 }, LH = { p = 0.4 } },
	{ t = 1.15 },
}
ANIM.Freeze = { -- bras tendu « FREEZE! », jambes campées
	{ t = 0 },
	{ t = 0.08, LS = { p = 1.75, y = 0.05 }, RS = { p = 1.6, y = -0.3 }, RJ = { tw = -0.35, ln = 0.15 }, RH = { p = -0.5, r = -0.2 }, LH = { p = 0.6, r = -0.2 } },
	{ t = 0.45, LS = { p = 1.7, y = 0.05 }, RS = { p = 1.6, y = -0.3 }, RJ = { tw = -0.3, ln = 0.12 }, RH = { p = -0.45, r = -0.2 }, LH = { p = 0.55, r = -0.2 } },
	{ t = 0.5 },
}
ANIM.Cuff = { -- armé, lancer latéral des menottes, puis traction en arrière
	{ t = 0 },
	{ t = 0.1, RS = { p = -0.9, r = -0.4 }, LS = { p = 0.9, y = 0.6 }, RJ = { tw = -0.65, ln = -0.05 }, RH = { p = 0.3 }, LH = { p = -0.2 } },
	{ t = 0.18, RS = { p = 1.75, y = 0.2 }, LS = { p = 0.4 }, RJ = { tw = 0.55, ln = 0.25 }, RH = { p = -0.5 }, LH = { p = 0.75 } },
	{ t = 0.28, RS = { p = 1.65, y = 0.2 }, LS = { p = 0.4 }, RJ = { tw = 0.5, ln = 0.2 }, RH = { p = -0.45 }, LH = { p = 0.7 } },
	{ t = 0.34, RS = { p = 0.4, r = -0.3 }, LS = { p = 1.2, y = 0.5 }, RJ = { tw = -0.35, ln = -0.35 }, RH = { p = 0.6 }, LH = { p = -0.5 } },
	{ t = 0.5, RS = { p = 0.5, r = -0.3 }, LS = { p = 1.1, y = 0.5 }, RJ = { tw = -0.3, ln = -0.25 }, RH = { p = 0.5 }, LH = { p = -0.4 } },
	{ t = 0.55 },
}
ANIM.Baton = { -- 4 coups de matraque variés puis grand revers tournoyant
	{ t = 0 },
	{ t = 0.02, RS = { p = 3.25, y = 0.2 }, LS = { p = 1.2, y = 0.6 }, RJ = { ln = -0.25 }, RH = { p = -0.2 }, LH = { p = 0.3 } }, -- haut
	{ t = 0.07, RS = { p = 0.9, y = 0.2 }, LS = { p = 1.0, y = 0.6 }, RJ = { ln = 0.55 }, RH = { p = -0.55 }, LH = { p = 0.8 } }, -- abattu
	{ t = 0.15, RS = { p = 1.5, y = -1.3 }, LS = { p = 0.8 }, RJ = { tw = -0.8, ln = 0.2 }, RH = { p = 0.2 }, LH = { p = 0.2 } }, -- armé revers
	{ t = 0.22, RS = { p = 1.6, y = 1.2 }, LS = { p = 0.5, r = -0.4 }, RJ = { tw = 0.85, ln = 0.3 }, RH = { p = -0.5 }, LH = { p = 0.7 } }, -- revers
	{ t = 0.3, RS = { p = 0.7, y = 0.3 }, LS = { p = 1.3, y = 0.6 }, RJ = { tw = -0.2, ln = 0.1 }, RH = { p = 0.4 }, LH = { p = -0.2 } }, -- recul
	{ t = 0.39, RS = { p = 1.95, y = 0.1 }, LS = { p = 0.6 }, RJ = { tw = 0.5, ln = 0.45 }, RH = { p = -0.65 }, LH = { p = 0.95 } }, -- estoc
	{ t = 0.46, RS = { p = -0.6, r = -0.2 }, LS = { p = 1.0, y = 0.6 }, RJ = { ln = 0.5, tw = -0.3 }, RH = { p = 0.8 }, LH = { p = 0.6 } }, -- accroupi
	{ t = 0.56, RS = { p = 3.2, y = 0.2 }, LS = { p = -0.4, r = -0.4 }, RJ = { ln = -0.5, tw = 0.4 }, RH = { p = -0.35 }, LH = { p = 1.3 } }, -- uppercut
	{ t = 0.66, RS = { p = 1.4, y = -1.2, r = -0.3 }, LS = { p = 1.1, r = -0.6 }, RJ = { tw = -1.6, ln = 0.2 }, RH = { p = 0.4, r = -0.3 }, LH = { p = 0.2, r = -0.3 } }, -- élan
	{ t = 0.8, RS = { p = 1.6, y = 1.3 }, LS = { p = 0.8, r = -0.9 }, RJ = { tw = 1.9, ln = 0.35 }, RH = { p = -0.6, r = -0.3 }, LH = { p = 0.8, r = -0.3 } }, -- grand revers
	{ t = 1.0, RS = { p = 1.5, y = 1.2 }, LS = { p = 0.8, r = -0.8 }, RJ = { tw = 1.6, ln = 0.3 }, RH = { p = -0.5, r = -0.3 }, LH = { p = 0.7, r = -0.3 } },
	{ t = 1.15 },
}
ANIM.Remote = { -- brandit la télécommande, presse, puis bras croisés
	{ t = 0 },
	{ t = 0.1, RS = { p = 2.9, y = 0.3 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = -0.15 }, RH = { p = -0.2 }, LH = { p = 0.3 } },
	{ t = 0.2, RS = { p = 2.75, y = 0.3 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = -0.1 } },
	{ t = 0.26, RS = { p = 2.95, y = 0.3 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = -0.18 } },
	{ t = 0.62, RS = { p = 2.9, y = 0.3 }, LS = { p = 0.3, r = -0.4 }, RJ = { ln = -0.15 } },
	{ t = 0.72, RS = { p = 1.45, y = 1.35 }, LS = { p = 1.45, y = 1.35 }, RJ = { ln = -0.12 }, RH = { p = -0.2, r = -0.15 }, LH = { p = 0.25, r = -0.15 } },
	{ t = 1.2, RS = { p = 1.45, y = 1.35 }, LS = { p = 1.45, y = 1.35 }, RJ = { ln = -0.12 }, RH = { p = -0.2, r = -0.15 }, LH = { p = 0.25, r = -0.15 } },
	{ t = 1.35 },
}
ANIM.HandsUp = { -- victime : mains en l'air sous le projecteur
	{ t = 0 },
	{ t = 0.12, RS = { p = 3.0, r = -0.4 }, LS = { p = 3.0, r = -0.4 }, RJ = { ln = -0.15 } },
	{ t = 0.6, RS = { p = 3.05, r = -0.45 }, LS = { p = 2.95, r = -0.35 }, RJ = { ln = -0.15 } },
	{ t = 0.7 },
}
ANIM.Shock = { -- victime électrocutée
	{ t = 0 },
	{ t = 0.05, RS = { p = 2.2, r = -1.2 }, LS = { p = 2.4, r = -1.0 }, RH = { r = -0.5 }, LH = { r = -0.5 }, RJ = { ln = -0.3 } },
	{ t = 0.1, RS = { p = 1.6, r = -1.5 }, LS = { p = 2.8, r = -0.8 }, RH = { r = -0.3 }, LH = { r = -0.6 }, RJ = { ln = -0.1, sd = 0.2 } },
	{ t = 0.15, RS = { p = 2.6, r = -1.0 }, LS = { p = 1.8, r = -1.4 }, RH = { r = -0.6 }, LH = { r = -0.3 }, RJ = { ln = -0.35, sd = -0.2 } },
	{ t = 0.2, RS = { p = 1.8, r = -1.4 }, LS = { p = 2.6, r = -1.0 }, RH = { r = -0.4 }, LH = { r = -0.6 }, RJ = { ln = -0.1, sd = 0.2 } },
	{ t = 0.3 },
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

-- gyrophares rouge / bleu qui tournent au-dessus des épaules du garde
local function sirens(K, data, st, c, dur)
	local torso = c:FindFirstChild("Torso")
	if not torso then
		return
	end
	local parts = {}
	for i, col in ipairs({ RED, BLUE }) do
		local base = K.prop(data, c, "Torso", Vector3.new(0.6, 0.55, 0.6), CFrame.new(i == 1 and 0.85 or -0.85, 1.3, 0) * A, col, K.CYL, Enum.Material.Neon)
		local pl = Instance.new("PointLight")
		pl.Color = col
		pl.Range = 20
		pl.Brightness = 4
		pl.Parent = base
		parts[i] = { base = base, light = pl, beam = K.track(data, K.part({ Size = Vector3.new(0.3, 0.3, 9), Color = col, Material = Enum.Material.Neon, Transparency = 0.45 }, dur + 0.5)) }
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - t0
		if not st.alive or el > dur or not torso.Parent then
			conn:Disconnect()
			for _, p in ipairs(parts) do
				if p.beam.Parent then
					p.beam:Destroy()
				end
			end
			return
		end
		for i, p in ipairs(parts) do
			if p.base.Parent then
				local a = el * 11 + (i == 1 and 0 or math.pi)
				local o = p.base.Position
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				p.beam.CFrame = CFrame.lookAt(o + dir * 4.6, o + dir * 9)
				p.light.Brightness = (math.sin(el * 22 + i * math.pi) > 0) and 6 or 0.5
			end
		end
	end)
	table.insert(st.conns, conn)
end

-- projecteur venu du ciel sur une position (ou un modèle)
local function searchlight(K, data, st, follow, dur, color)
	local beam = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(70, 7, 7), Color = color or LIGHT, Material = Enum.Material.Neon, Transparency = 0.78 }, dur + 0.5))
	local core = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(70, 3.2, 3.2), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Transparency = 0.82 }, dur + 0.5))
	local disc = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(0.1, 8.5, 8.5), Color = color or LIGHT, Material = Enum.Material.Neon, Transparency = 0.35 }, dur + 0.5))
	local lp = K.track(data, K.part({ Size = Vector3.one * 0.2, Transparency = 1 }, dur + 0.5))
	local sl = Instance.new("SpotLight")
	sl.Face = Enum.NormalId.Bottom
	sl.Range = 40
	sl.Angle = 30
	sl.Brightness = 4
	sl.Color = color or LIGHT
	sl.Parent = lp
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - t0
		local p = follow()
		if not st.alive or el > dur or not p then
			conn:Disconnect()
			for _, x in ipairs({ beam, core, disc }) do
				if x.Parent then
					K.tween(x, 0.2, { Transparency = 1 })
				end
			end
			return
		end
		local g = K.groundPos(p)
		local tilt = CFrame.Angles(0.12, 0, 0.12)
		beam.CFrame = CFrame.new(g) * tilt * CFrame.new(0, 35, 0) * K.UPRIGHT
		core.CFrame = beam.CFrame
		disc.CFrame = CFrame.new(g + Vector3.new(0, 0.08, 0)) * K.UPRIGHT
		disc.Transparency = 0.55 + math.sin(el * 20) * 0.08
		lp.CFrame = CFrame.new(g + Vector3.new(0, 14, 0))
	end)
	table.insert(st.conns, conn)
end

-- cellule de prison : socle, toit, barreaux ; renvoie la liste des barreaux et des plaques
local function buildCage(K, data, g, life)
	local bars, plates = {}, {}
	plates[1] = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(0.6, 8.2, 8.2), CFrame = CFrame.new(g + Vector3.new(0, 0.3, 0)) * K.UPRIGHT, Color = DARK, Material = Enum.Material.Metal }, life))
	plates[2] = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(0.7, 8.4, 8.4), CFrame = CFrame.new(g + Vector3.new(0, 8.4, 0)) * K.UPRIGHT, Color = NAVY, Material = Enum.Material.Metal }, life))
	plates[3] = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(0.9, 1.3, 1.3), CFrame = CFrame.new(g + Vector3.new(0, 9.1, 0)) * K.UPRIGHT, Color = RED, Material = Enum.Material.Neon }, life))
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2
		bars[i] = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(8, 0.42, 0.42), CFrame = CFrame.new(g + Vector3.new(math.cos(a) * 3.7, 4.3, math.sin(a) * 3.7)) * K.UPRIGHT, Color = STEEL, Material = Enum.Material.Metal }, life))
	end
	for i = 1, 2 do
		plates[#plates + 1] = K.track(data, K.part({ Shape = K.CYL, Size = Vector3.new(0.35, 7.8, 7.8), CFrame = CFrame.new(g + Vector3.new(0, i == 1 and 2.6 or 6, 0)) * K.UPRIGHT, Color = STEEL, Material = Enum.Material.Metal, Transparency = 0.82 }, life))
	end
	local all = {}
	for _, p in ipairs(bars) do
		table.insert(all, p)
	end
	for _, p in ipairs(plates) do
		table.insert(all, p)
	end
	return bars, plates, all
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
			if st.wail then
				st.wail:Destroy()
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
	local function vpos(fallback)
		local r = rootOf(v)
		return r and r.Position or fallback
	end

	if data.phase == "Cutin" then
		K.anim(c, ANIM.Radio)
		swap(st, {
			K.prop(data, c, "Right Arm", Vector3.new(0.5, 1.1, 0.35), CFrame.new(0, -1.3, -0.2), DARK),
			K.prop(data, c, "Right Arm", Vector3.new(0.09, 0.9, 0.09), CFrame.new(0.14, -0.4, -0.2), DARK),
		})
		K.sound("Electric", cr.Position, 0.7)
		K.sound("Charge", cr.Position, 0.5)
		sirens(K, data, st, c, 1.0)
		at(0.2, function()
			K.word(cr.Position + Vector3.new(-1.5, 4, 0), "ALL UNITS!", 0.6, "Light")
		end)

	elseif data.phase == "Whiff" then
		local cf = data.cf or cr.CFrame
		swap(st, {})
		K.anim(c, ANIM.Cuff)
		local buzz = K.sound(SFX.Buzz, cf.Position, 0.6)
		task.delay(0.9, function()
			if buzz then
				buzz:Destroy()
			end
		end)
		local t0 = os.clock()
		searchlight(K, data, st, function()
			local a = math.sin((os.clock() - t0) * 5) * 0.9
			return cf.Position + (CFrame.Angles(0, a, 0) * cf.LookVector) * 12
		end, 0.95, LIGHT)
		at(0.18, function()
			local hand = c:FindFirstChild("Right Arm")
			local from = hand and hand.Position or cf.Position
			local to = K.groundPos(cf.Position + cf.LookVector * 14) + Vector3.new(0, 0.3, 0)
			local cuff = K.part({ Shape = K.CYL, Size = Vector3.new(0.25, 1, 1), Position = from, Color = STEEL, Material = Enum.Material.Metal }, 1.5)
			K.tween(cuff, 0.35, { Position = to }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.35, function()
				K.sound(SFX.Cuffs, to, 1)
				K.sound("Clang", to, 0.6, 1.4)
				K.sparks(to, 8, STEEL)
				K.word(to + Vector3.new(0, 4, 0), "SUSPECT ESCAPED!", 0.8, "Light")
			end)
		end)

	elseif data.phase == "Lock" then
		local cf, vp0 = data.cf, data.vp
		local look = cf.LookVector
		swap(st, {})
		K.letterbox(data, true)
		K.anim(c, ANIM.Freeze)
		if v then
			K.anim(v, ANIM.HandsUp)
		end
		sirens(K, data, st, c, T.implode + 0.3)
		searchlight(K, data, st, function()
			return vpos(vp0)
		end, T.cage, LIGHT)
		st.wail = K.sound(SFX.Wail, cr.Position, 0.9)
		K.layer({ { "Whistle", 0.8 }, { "Sting", 0.8 } }, cr.Position)
		K.impactFrames("WB")
		K.flash(LIGHT, 0.3, 0.5)
		K.shake(0.7)
		K.word(cr.Position + Vector3.new(0, 4.5, 0), "FREEZE!", 1.1, "Heavy")
		K.light(vp0, LIGHT, 26, 6, 0.6)
		-- caméra 1 : depuis derrière la victime, le garde dans les sirènes
		K.shot(data, "track", { from = camSafe(vp0, vp0 - look * 7 + cf.RightVector * 3 + Vector3.new(0, 3, 0)), at = c, lookOffset = Vector3.new(0, 1, 0), fov = 55 })

		-- 2) menottes
		at(T.cuffThrow, function()
			K.anim(c, ANIM.Cuff)
			K.sound("Whoosh", cr.Position, 0.9)
			local hand = c:FindFirstChild("Right Arm")
			local from = hand and hand.Position or cr.Position
			local to = vpos(vp0)
			for i = -1, 1, 2 do
				local cuff = K.part({ Shape = K.CYL, Size = Vector3.new(0.3, 1.1, 1.1), Position = from, Color = STEEL, Material = Enum.Material.Metal }, 0.5)
				K.tween(cuff, T.cuffHit - T.cuffThrow, { Position = to + cr.CFrame.RightVector * 0.6 * i, Orientation = Vector3.new(0, 0, 720) })
			end
			-- caméra 2 : plan latéral
			local mid = cr.Position:Lerp(to, 0.5)
			K.shot(data, "fixed", { pos = camSafe(mid, mid + cf.RightVector * 14 + Vector3.new(0, 2.5, 0)), lookAt = mid + Vector3.new(0, 1, 0), fov = 60 })
		end)
		at(T.cuffHit, function()
			local p = vpos(vp0)
			K.layer({ { SFX.Cuffs, 1.2 }, { "Clang", 0.7, 1.3 } }, p)
			K.sparks(p, 14, STEEL)
			K.word(p + Vector3.new(0, 4, 0), "CUFFED!", 0.8, "Light")
			if v then
				for _, arm in ipairs({ "Left Arm", "Right Arm" }) do
					K.prop(data, v, arm, Vector3.new(0.35, 1.25, 1.25), CFrame.new(0, -0.7, 0) * A, STEEL, K.CYL, Enum.Material.Metal)
				end
			end
			-- chaîne entre la main du garde et la victime
			local chain = K.track(data, K.part({ Size = Vector3.new(0.22, 0.22, 1), Color = STEEL, Material = Enum.Material.Metal }, 2))
			local t0 = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local hand = c:FindFirstChild("Right Arm")
				local vr = rootOf(v)
				if not st.alive or os.clock() - t0 > (T.batons[1] - T.cuffHit) or not hand or not vr then
					conn:Disconnect()
					chain:Destroy()
					return
				end
				local a, b = (hand.CFrame * CFrame.new(0, -1, 0)).Position, vr.Position
				chain.Size = Vector3.new(0.22, 0.22, (b - a).Magnitude)
				chain.CFrame = CFrame.lookAt(a:Lerp(b, 0.5), b)
			end)
			table.insert(st.conns, conn)
		end)
		at(T.yank, function()
			K.sound("Whoosh2", cr.Position, 1)
			K.word(cr.Position + Vector3.new(0, 4, 0), "GET OVER HERE!", 0.7, "Light")
			if v then
				for _ = 1, 3 do
					K.afterimage(v, NAVY, 0.3, 0.5)
				end
			end
		end)

		-- matraque
		at(T.batons[1] - 0.04, function()
			K.anim(c, ANIM.Baton)
			swap(st, {
				K.prop(data, c, "Right Arm", Vector3.new(3.4, 0.38, 0.38), CFrame.new(0, -2.7, 0) * A, DARK, K.CYL),
				K.prop(data, c, "Right Arm", Vector3.new(0.4, 0.45, 0.45), CFrame.new(0, -4.3, 0) * A, BLUE, K.CYL, Enum.Material.Neon),
			})
			K.CFX.trailOn(c:FindFirstChild("Right Arm"), BLUE, 1.0, 2, 2.4)
			-- caméra 3 : travelling serré de côté
			local m = cr.Position:Lerp(vpos(vp0), 0.5) + Vector3.new(0, 0.5, 0)
			K.shot(data, "dolly", { from = CFrame.lookAt(camSafe(m, m + cf.RightVector * 9 + Vector3.new(0, 1.5, 0) + look * 3), m), to = CFrame.lookAt(camSafe(m, m + cf.RightVector * 7 + Vector3.new(0, 2.5, 0) - look * 4), m), dur = 0.8, fov0 = 58, fov1 = 52 })
		end)
		local tilts = { 90, 10, -20, 70 }
		for i, t in ipairs(T.batons) do
			at(t, function()
				local p = vpos(vp0)
				K.slashArc(CFrame.lookAt(p + look * 2.5, p) * CFrame.Angles(0, math.pi, 0), 3.2, (i % 2 == 0) and RED or BLUE, -60, 60, 0.06, tilts[i], 0.5)
				K.sparks(p, 12, (i % 2 == 0) and RED or BLUE)
				K.sound(i % 2 == 0 and "PunchHeavy" or "Bonk", p, 1, 0.95 + i * 0.05)
				K.sound("Punch", p, 0.7)
				K.airRing(p, look, 5 + i, Color3.new(1, 1, 1), 0.18)
				K.shake(0.45 + i * 0.08)
			end)
		end
	elseif data.phase == "Cage" then
		local cf, g = data.cf, data.cp
		local look = cf.LookVector
		local p = g + Vector3.new(0, 3, 0)
		K.impactFrames("BW")
		K.bigImpact(cr.Position + look * 3.5, look, 1.2, BLUE)
		K.layer({ { "PunchHeavy", 1.2 }, { "Punch", 0.9, 0.8 }, { "Whoosh3", 0.8 } }, p)
		K.shake(1)
		-- caméra 4 : plan large en contre-plongée vers la zone de la cage
		K.shot(data, "fixed", { pos = camSafe(g + Vector3.new(0, 4, 0), g - look * 4 + cf.RightVector * 13 + Vector3.new(0, 2, 0)), lookAt = g + Vector3.new(0, 4, 0), fov = 66 })
		local bars, plates, all = buildCage(K, data, g, 4.5)
		st.cage = { bars = bars, plates = plates, all = all, g = g }
		local drop = T.cageLand - T.cage
		for _, prt in ipairs(all) do
			prt.CFrame = prt.CFrame + Vector3.new(0, 60, 0)
		end
		K.CFX.bigTelegraph(g, 4.5, T.cageLand - T.big, RED)
		at(T.cage - T.big, function()
			K.sound("Whoosh2", g, 1, 0.7)
			for _, prt in ipairs(all) do
				if prt.Parent then
					K.tween(prt, drop, { CFrame = prt.CFrame - Vector3.new(0, 60, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				end
			end
		end)
		at(T.cageLand - T.big, function()
			K.layer({ { SFX.Bang, 1.3 }, { SFX.Grate, 0.8 }, { "GroundSlam", 1.1 } }, g)
			K.shake(1.3)
			K.impactFrames("W")
			K.dust(g, 9, nil, 12)
			K.shockwave(g + Vector3.new(0, 0.2, 0), 12, NAVY)
			K.CFX.cracks(g, 8, 5, 2)
			K.debris(g, 5, nil, 1)
			K.word(g + Vector3.new(0, 11, 0), "LOCKED UP!", 1.2, "Heavy")
		end)
		-- télécommande
		at(T.remote - T.big, function()
			K.anim(c, ANIM.Remote)
			swap(st, {
				K.prop(data, c, "Right Arm", Vector3.new(0.6, 1.0, 0.35), CFrame.new(0, -1.35, -0.25), DARK),
				K.prop(data, c, "Right Arm", Vector3.new(0.35, 0.2, 0.35), CFrame.new(0, -1.0, -0.45), RED, K.CYL, Enum.Material.Neon),
			})
			K.sound("Ding", cr.Position, 0.9, 1.4)
			K.sound("FinalCharge", g, 0.8)
			K.word(cr.Position + Vector3.new(0, 4.5, 0), "LOCKDOWN!", 0.9, "Light")
			-- caméra 5 : gros plan sur la cage, poussée lente
			local gc = g + Vector3.new(0, 4, 0)
			local from = CFrame.lookAt(camSafe(gc, g - look * 3 + Vector3.new(0, 5, 0) + cf.RightVector * 11), gc)
			local to = CFrame.lookAt(camSafe(gc, g - look * 1 + Vector3.new(0, 4.5, 0) + cf.RightVector * 8), gc)
			K.shot(data, "dolly", { from = from, to = to, dur = 0.65, fov0 = 60, fov1 = 52 })
		end)
		for i, t in ipairs(T.zaps) do
			at(t - T.big, function()
				local vp = vpos(g + Vector3.new(0, 3, 0))
				for _, b in ipairs(bars) do
					if b.Parent then
						b.Color = (i % 2 == 1) and ZAP or Color3.fromRGB(255, 240, 120)
						b.Material = Enum.Material.Neon
					end
				end
				for j = 1, 5 do
					local b = bars[((i * 3 + j * 2) % #bars) + 1]
					if b and b.Parent then
						K.bolt(b.Position + Vector3.new(0, K.rng:NextNumber(-3, 3), 0), vp, (j % 2 == 0) and ZAP or Color3.fromRGB(255, 240, 120), 0.3, 0.15, 1.3)
					end
				end
				K.sparks(vp, 14, ZAP)
				K.light(vp, ZAP, 24, 7, 0.15)
				K.layer({ { "Electric", 1.2 }, { "Lightning", 0.8, 1 + i * 0.1 } }, vp)
				K.shake(0.6)
				K.flash(ZAP, 0.12, 0.25)
				if v then
					K.anim(v, ANIM.Shock)
					K.CFX.flash(v, 0.12)
				end
				task.delay(0.1, function()
					for _, b in ipairs(bars) do
						if b.Parent then
							b.Color = STEEL
							b.Material = Enum.Material.Metal
						end
					end
				end)
			end)
		end

	elseif data.phase == "Implode" then
		local g, cf = data.p, data.cf
		local look = cf.LookVector
		if st.wail then
			st.wail:Destroy()
			st.wail = nil
		end
		K.impactFrames("RWBWB", 0.045)
		K.slowmo({ c, v }, 0.14)
		K.shake(2.1)
		K.fov(14)
		K.flash(RED, 0.25, 0.55)
		task.delay(0.12, function()
			K.flash(BLUE, 0.25, 0.5)
		end)
		K.layer({ { "Explosion", 1.3 }, { SFX.Blast, 1.1 }, { SFX.Bang, 1.2, 0.8 }, { SFX.Boom, 1.3, 0.9, 0.03 }, { "Bass", 1.3, 1, 0.05 }, { "Siren", 0.8, 1.2, 0.08 } }, g)
		-- caméra 6 : plongée large
		K.shot(data, "fixed", { pos = camSafe(g + Vector3.new(0, 2, 0), g - look * 17 + cf.RightVector * 10 + Vector3.new(0, 11, 0)), lookAt = g + Vector3.new(0, 1, 0), fov = 72 })
		-- la cage implose puis ses barreaux sont soufflés
		local cage = st.cage
		if cage then
			for i, b in ipairs(cage.bars) do
				if b.Parent then
					local a = (i / #cage.bars) * math.pi * 2
					local dir = Vector3.new(math.cos(a), 0, math.sin(a))
					K.tween(b, 0.08, { CFrame = CFrame.new(g + Vector3.new(0, 4.3, 0) + dir * 0.8) * K.UPRIGHT })
					task.delay(0.09, function()
						if b.Parent then
							K.tween(b, 0.7, { CFrame = CFrame.new(g + dir * 18 + Vector3.new(0, K.rng:NextNumber(3, 9), 0)) * CFrame.Angles(K.rng:NextNumber(0, 6), a, K.rng:NextNumber(0, 6)), Transparency = 1 }, Enum.EasingStyle.Quad)
						end
					end)
				end
			end
			for _, p in ipairs(cage.plates) do
				if p.Parent then
					K.tween(p, 0.4, { Size = p.Size * Vector3.new(1, 1.6, 1.6), Transparency = 1 })
				end
			end
		end
		task.delay(0.08, function()
			K.pillar(g, 3, 26, RED, 0.45)
			K.pillar(g + Vector3.new(0.1, 0, 0.1), 2.2, 30, BLUE, 0.5)
			K.sphere(g + Vector3.new(0, 3, 0), 18, RED, 0.35, 4)
			K.sphere(g + Vector3.new(0, 3, 0), 24, BLUE, 0.5, 4)
			K.bigImpact(g + Vector3.new(0, 1, 0), Vector3.new(0, -1, 0), 1.4, NAVY)
			K.crater(g, 10, RED, 3.5)
			for i = 0, 3 do
				task.delay(i * 0.07, function()
					K.shockwave(g + Vector3.new(0, 0.25 + i * 0.04, 0), 12 + i * 5, (i % 2 == 0) and RED or BLUE)
				end)
			end
			K.ring(CFrame.lookAt(g + Vector3.new(0, 3, 0), g + Vector3.new(0, 3, 0) + look), 20, Color3.new(1, 1, 1), 0.4, 0.6)
			K.debris(g, 5, nil, 1.3, 1.1)
			K.light(g + Vector3.new(0, 4, 0), RED, 45, 9, 0.7)
			K.word(g + Vector3.new(0, 9, 0), "CASE CLOSED!", 1.6, "Heavy")
		end)
	end
end

return ULT
