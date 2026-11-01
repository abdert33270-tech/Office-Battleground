--[[
	CoreKinds — nouveaux comportements d'attaque (Kinds) partagés, utilisables par n'importe quel personnage
	(surtout les 4 d'origine : Intern, Janitor, LunchLady, SecurityGuard). Pas de personnage ici (pas de champ Character).
	Kinds :
		SkyDrop      un objet géant tombe du ciel sur la cible devant (Model = "Calendar" | "Safe"), Effects.Pin conseillé
		             (Range, Offset, Radius, Windup = temps de chute)
		BubblePrison bulle qui piège la 1re cible en ligne, la fait monter puis éclate et la plaque au sol
		             (Windup, Range, Width, Speed, RiseTime, RiseSpeed)
		CartRush     pousse un chariot : ramasse tout le monde sur son passage puis s'écrase (Windup, Speed, Time, HitboxSize)
		ElbowDrop    bond en cloche sur la cible devant puis coude au sol ; plaque dans Radius, onde jusqu'à SplashRadius
		             (Windup, Range, Offset, AirTime, Height, Radius, SplashRadius, SplashDamage)
		Counter      posture de contre pendant Window s : le prochain coup reçu est bloqué, on se téléporte dans le dos
		             de l'attaquant et on le frappe (Window, CounterAnim)
	Effets client : Kit.on("CoreDrop" | "CoreBubbleShot" | "CoreBubble" | "CoreBubblePop" | "CoreCart" | "CoreScoop" |
	                "CoreCartCrash" | "CoreElbowMark" | "CoreElbowLand" | "CoreCounter" | "CoreCounterEnd")
]]
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Shared = script.Parent.Parent
local Kit = require(Shared.Modules.ContentKit)

local CYL, BALL, UP = Kit.CYL, Kit.BALL, Kit.UPRIGHT

local M = { Id = "CoreKinds", Order = 1 }

local counterHits = setmetatable({}, { __mode = "k" }) -- [personnage en contre] = premier attaquant

------------------------------------------------------------------------
-- outils serveur
------------------------------------------------------------------------
local function alive(api, c)
	return api.CharacterState.isAlive(c)
end

local function busy(api, c)
	return not api.CharacterState.isAlive(c) or api.CharacterState.isStunned(c)
end

-- ennemi le plus proche devant (cône large), non protégé
local function frontTarget(attacker, dir, range)
	local root = Kit.root(attacker)
	local best, bestD = nil, math.huge
	for _, v in ipairs(Kit.enemies(attacker)) do
		local to = Kit.root(v).Position - root.Position
		local d = to.Magnitude
		if d <= range and not Kit.isProtected(v) then
			local facing = Kit.flat(to):Dot(dir)
			if (facing >= 0.35 or d < 8) and d < bestD then
				best, bestD = v, d
			end
		end
	end
	return best
end

local function inArea(attacker, center, radius)
	local list = {}
	for _, v in ipairs(Kit.enemies(attacker)) do
		local vp = Kit.root(v).Position
		if Vector3.new(vp.X - center.X, 0, vp.Z - center.Z).Magnitude <= radius and math.abs(vp.Y - center.Y) < 10 then
			table.insert(list, v)
		end
	end
	return list
end

local function kbAtt(root)
	local att = root:FindFirstChild("KBAtt")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "KBAtt"
		att.Parent = root
	end
	return att
end

local function clearMovers(root)
	for _, n in ipairs({ "KB", "ContentPull", "ContentHold", "AirStall", "BubbleRise" }) do
		local o = root:FindFirstChild(n)
		if o then
			o:Destroy()
		end
	end
end

local function unstand(c)
	local h = c and c:FindFirstChildOfClass("Humanoid")
	if h and h.Health > 0 then
		h.PlatformStand = false
	end
end

------------------------------------------------------------------------
-- Kinds (serveur)
------------------------------------------------------------------------
M.Kinds = {
	-- objet géant qui tombe du ciel sur la cible verrouillée devant soi (ou le point visé)
	SkyDrop = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		local target = frontTarget(attacker, dir, cfg.Range or 30)
		local spot = target and Kit.root(target).Position or (root.Position + dir * (cfg.Offset or 12))
		local center = Kit.ground(Kit.safePoint(root.Position + Vector3.new(0, 1, 0), spot, 2))
		Kit.fx({ id = "CoreDrop", p = center, r = cfg.Radius, fall = cfg.Windup, model = cfg.Model, a = attacker, look = dir })
		task.wait(cfg.Windup)
		if not alive(api, attacker) then
			return
		end
		for _, v in ipairs(inArea(attacker, center, cfg.Radius)) do
			local vp = Kit.root(v).Position
			api.hit(attacker, v, cfg, api.flat(vp - center, dir), { hitPos = vp + Vector3.new(0, 1, 0) })
		end
		api.ZoneService.shatterAround(center, cfg.Radius * 0.8, Vector3.new(0, 30, 0))
	end,

	-- bulle de savon : piège, fait flotter, éclate et plaque au sol
	BubblePrison = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local dir = Kit.aimDir(attacker, aim)
		task.wait(cfg.Windup or 0.25)
		if busy(api, attacker) then
			return
		end
		local victim = Kit.firstInLine(attacker, root.Position, dir, cfg.Range, cfg.Width)
		if victim and Kit.isProtected(victim) then
			victim = nil
		end
		local travel = cfg.Range / cfg.Speed
		if victim then
			travel = math.clamp((Kit.root(victim).Position - root.Position).Magnitude / cfg.Speed, 0.05, 0.6)
		end
		Kit.fx({ id = "CoreBubbleShot", a = attacker, v = victim, dir = dir, range = cfg.Range, t = travel })
		if not victim then
			return
		end
		task.wait(travel)
		local vr = Kit.root(victim)
		local vh = victim:FindFirstChildOfClass("Humanoid")
		if not vr or not vh or not alive(api, victim) or Kit.isProtected(victim) then
			return
		end
		api.CharacterState.stun(victim, cfg.RiseTime + 0.7)
		clearMovers(vr)
		vh.PlatformStand = true
		local lv = Instance.new("LinearVelocity")
		lv.Name = "BubbleRise"
		lv.Attachment0 = kbAtt(vr)
		lv.MaxForce = 1e7
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VectorVelocity = Vector3.new(0, cfg.RiseSpeed, 0)
		lv.Parent = vr
		Kit.fx({ id = "CoreBubble", v = victim, dur = cfg.RiseTime })
		local t0 = os.clock()
		while os.clock() - t0 < cfg.RiseTime and lv.Parent and vr.Parent do
			local k = (os.clock() - t0) / cfg.RiseTime
			lv.VectorVelocity = Vector3.new(math.sin(k * 9) * 1.5, cfg.RiseSpeed * (1 - k * 0.8), 0) -- flotte en ondulant
			RunService.Heartbeat:Wait()
		end
		lv:Destroy()
		if not vr.Parent or not alive(api, victim) then
			unstand(victim)
			return
		end
		Kit.fx({ id = "CoreBubblePop", p = vr.Position, a = attacker })
		if api.hit(attacker, victim, cfg, api.flat(vr.Position - root.Position, dir), { hitPos = vr.Position }) ~= "Hit" then
			unstand(victim)
		end
	end,

	-- chariot de cantine : ramasse les ennemis sur son passage, puis crash qui les plaque
	CartRush = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local look = Kit.flat(root.CFrame.LookVector)
		local len = cfg.Speed * cfg.Time
		Kit.rawFX({ k = "Telegraph", shape = "Box", a = attacker, size = Vector3.new(7, 1, len), offset = len / 2 + 2, dur = (cfg.Windup or 0.1) + 0.12 })
		Kit.fx({ id = "CoreCart", a = attacker, dur = (cfg.Windup or 0.1) + cfg.Time + 0.12 })
		task.wait(cfg.Windup or 0.1)
		if busy(api, attacker) then
			return
		end
		look = Kit.flat(root.CFrame.LookVector)
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Lunge"
		lv.Attachment0 = kbAtt(root)
		lv.MaxForce = 1e6
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.xAxis
		lv.SecondaryTangentAxis = Vector3.zAxis
		lv.PlaneVelocity = Vector2.new(look.X * cfg.Speed, look.Z * cfg.Speed)
		lv.Parent = root
		Debris:AddItem(lv, cfg.Time + 0.1)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = Kit.excludeList()
		local scooped, links = {}, {}
		local t0 = os.clock()
		while os.clock() - t0 < cfg.Time and root.Parent and lv.Parent do
			if busy(api, attacker) then
				break
			end
			local wall = workspace:Raycast(root.Position, look * 6.5, params)
			if wall and wall.Instance.CanCollide then
				break
			end
			local cf = root.CFrame * CFrame.new(0, 0, -3.6)
			for _, v in ipairs(api.Hitbox.box(cf, cfg.HitboxSize + Vector3.one * 1.5, attacker, 5)) do
				if not scooped[v] and not Kit.isProtected(v) then
					scooped[v] = true
					local vr = Kit.root(v)
					local vh = v:FindFirstChildOfClass("Humanoid")
					if vr and vh then
						clearMovers(vr)
						api.CharacterState.stun(v, cfg.Time + 1)
						vh.PlatformStand = true
						local n = #links
						local a0 = Instance.new("Attachment")
						a0.Parent = vr
						local a1 = Instance.new("Attachment")
						a1.Position = Vector3.new((n % 2 == 0 and 1 or -1) * math.min(n, 2) * 0.9, 1.6 + n * 0.7, -4.4)
						a1.Parent = root
						local ap = Instance.new("AlignPosition")
						ap.Attachment0 = a0
						ap.Attachment1 = a1
						ap.RigidityEnabled = true
						ap.Parent = vr
						table.insert(links, { v = v, a0 = a0, a1 = a1, ap = ap })
						Kit.fx({ id = "CoreScoop", v = v, p = vr.Position })
					end
				end
			end
			RunService.Heartbeat:Wait()
		end
		if lv.Parent then
			lv:Destroy()
		end
		for _, l in ipairs(links) do
			l.ap:Destroy()
			l.a0:Destroy()
			l.a1:Destroy()
		end
		if not root.Parent then
			return
		end
		local crash = root.Position + look * 4.5
		Kit.fx({ id = "CoreCartCrash", p = crash, a = attacker, look = look })
		api.ZoneService.shatterAround(Kit.ground(crash), 6, Vector3.new(0, 30, 0))
		local done = {}
		for _, l in ipairs(links) do
			done[l.v] = true
			if alive(api, l.v) and alive(api, attacker) then
				if api.hit(attacker, l.v, cfg, look, { hitPos = Kit.root(l.v).Position }) ~= "Hit" then
					unstand(l.v)
				end
			else
				unstand(l.v)
			end
		end
		-- ceux qui sont juste devant au moment du crash prennent l'onde (sans plaquage)
		for _, v in ipairs(Kit.inRadius(attacker, crash, 6)) do
			if not done[v] then
				api.hit(attacker, v, cfg, api.flat(Kit.root(v).Position - root.Position, look), { Pin = false, Damage = cfg.Damage * 0.5, Knockback = 34, KnockUp = 14 })
			end
		end
	end,

	-- bond en cloche sur la cible puis coude au sol
	ElbowDrop = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		local hum = attacker:FindFirstChildOfClass("Humanoid")
		local dir = Kit.aimDir(attacker, aim)
		local target = frontTarget(attacker, dir, cfg.Range)
		local land = target and Kit.root(target).Position or (root.Position + dir * cfg.Offset)
		land = Kit.safePoint(root.Position + Vector3.new(0, 1, 0), Vector3.new(land.X, root.Position.Y + 1, land.Z), 2.5)
		local ground = Kit.ground(land)
		Kit.fx({ id = "CoreElbowMark", p = ground, r = cfg.Radius, dur = cfg.Windup + cfg.AirTime + 0.1, a = attacker })
		task.wait(cfg.Windup)
		if busy(api, attacker) or not root.Parent then
			return
		end
		local from = root.Position
		local flatD = Vector3.new(land.X - from.X, 0, land.Z - from.Z)
		local T, H = cfg.AirTime, cfg.Height or 12
		local hv = flatD / T
		local vy0, G = 4 * H / T, 8 * H / (T * T)
		root.CFrame = CFrame.lookAt(root.Position, root.Position + Kit.flat(flatD, dir))
		local lv = Instance.new("LinearVelocity")
		lv.Name = "ElbowDrop"
		lv.Attachment0 = kbAtt(root)
		lv.MaxForce = 1e6
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VectorVelocity = hv + Vector3.new(0, vy0, 0)
		lv.Parent = root
		Debris:AddItem(lv, T + 1)
		local t0 = os.clock()
		while root.Parent and lv.Parent do
			local t = os.clock() - t0
			if t >= T then
				break
			end
			lv.VectorVelocity = hv + Vector3.new(0, vy0 - G * t, 0)
			RunService.Heartbeat:Wait()
		end
		-- plongeon final
		lv.VectorVelocity = Vector3.new(0, -120, 0)
		local t1 = os.clock()
		while os.clock() - t1 < 0.6 and root.Parent and hum and hum.FloorMaterial == Enum.Material.Air do
			RunService.Heartbeat:Wait()
		end
		lv:Destroy()
		if not alive(api, attacker) or not root.Parent then
			return
		end
		-- l'impact a lieu là où l'alerte au sol l'annonçait (on recale le garde si la physique a dérivé)
		local off = Vector3.new(land.X - root.Position.X, 0, land.Z - root.Position.Z)
		if off.Magnitude > 1.5 and off.Magnitude < 25 then
			root.CFrame = root.CFrame + off
		end
		local center = Vector3.new(land.X, root.Position.Y, land.Z)
		Kit.fx({ id = "CoreElbowLand", p = Kit.ground(center), a = attacker })
		for _, v in ipairs(Kit.inRadius(attacker, center, cfg.SplashRadius)) do
			local vp = Kit.root(v).Position
			local d = Vector3.new(vp.X - center.X, 0, vp.Z - center.Z).Magnitude
			if d <= cfg.Radius then
				api.hit(attacker, v, cfg, api.flat(vp - center, dir), { hitPos = vp })
			else
				api.hit(attacker, v, cfg, api.flat(vp - center, dir), { Pin = false, Damage = cfg.SplashDamage, Knockback = 30, KnockUp = 16, Stun = 0.7, Power = 0.6 })
			end
		end
		api.ZoneService.shatterAround(Kit.ground(center), cfg.Radius, Vector3.new(0, 30, 0))
	end,

	-- contre : bloque le prochain coup, se téléporte dans le dos de l'agresseur et frappe
	Counter = function(attacker, cfg, aim, api)
		local root = Kit.root(attacker)
		counterHits[attacker] = nil
		attacker:SetAttribute("CounterUntil", Kit.now() + cfg.Window)
		api.CharacterState.setBlocking(attacker, true)
		local t0 = os.clock()
		while os.clock() - t0 < cfg.Window and alive(api, attacker) and not counterHits[attacker] do
			RunService.Heartbeat:Wait()
		end
		attacker:SetAttribute("CounterUntil", 0)
		api.CharacterState.setBlocking(attacker, false)
		local foe = counterHits[attacker]
		counterHits[attacker] = nil
		local fr = foe and Kit.root(foe)
		if not fr or not root.Parent or not alive(api, attacker) or not alive(api, foe) then
			Kit.fx({ id = "CoreCounterEnd", a = attacker })
			return
		end
		api.CharacterState.clearStun(attacker)
		local back = Kit.flat(fr.CFrame.LookVector)
		local dest = Kit.safePoint(fr.Position, fr.Position - back * 3.5, 1.2)
		local from = root.Position
		root.CFrame = CFrame.lookAt(dest, Vector3.new(fr.Position.X, dest.Y, fr.Position.Z))
		Kit.fx({ id = "CoreCounter", a = attacker, from = from, to = dest, anim = cfg.CounterAnim })
		task.wait(0.1)
		if alive(api, attacker) and alive(api, foe) then
			api.hit(attacker, foe, cfg, api.flat(fr.Position - root.Position, back), { hitPos = fr.Position + Vector3.new(0, 1, 0) })
		end
	end,
}

function M.ServerInit(api)
	-- contre : le coup reçu pendant la fenêtre devient un blocage frontal sans dégâts, et on retient l'agresseur
	table.insert(api.CombatService.damageMods, function(p)
		local v, a = p.victim, p.attacker
		if a and a ~= v and (v:GetAttribute("CounterUntil") or 0) > Kit.now() then
			local vr = Kit.root(v)
			if vr then
				p.dir = -Kit.flat(vr.CFrame.LookVector)
			end
			p.unblockable = false
			p.trayGuard = true
			if not counterHits[v] then
				counterHits[v] = a
			end
		end
	end)
end

------------------------------------------------------------------------
-- Client
------------------------------------------------------------------------
local WHITE = Color3.new(1, 1, 1)
local ORANGE = Color3.fromRGB(255, 170, 40)
local SOAP = Color3.fromRGB(190, 235, 255)
local FOOD = { Color3.fromRGB(255, 80, 60), Color3.fromRGB(255, 220, 60), Color3.fromRGB(120, 220, 80), Color3.fromRGB(160, 100, 60), Color3.fromRGB(255, 255, 255) }
local GOLD = Color3.fromRGB(255, 205, 50)
local RED = Color3.fromRGB(230, 50, 50)

-- objets qui tombent du ciel (parts en repère local, autour de (0,0,0) = point d'impact au sol)
local function buildDrop(kind, base)
	local parts = {}
	local function add(size, off, color, shape)
		local p = Kit.part({ Size = size, CFrame = base * off, Color = color })
		if shape then
			p.Shape = shape
		end
		table.insert(parts, { p = p, off = off })
		return p
	end
	if kind == "Safe" then
		local body = add(Vector3.new(6.5, 6, 6.5), CFrame.new(0, 3, 0), Color3.fromRGB(75, 80, 92))
		add(Vector3.new(5.2, 4.8, 0.3), CFrame.new(0, 3, -3.3), Color3.fromRGB(105, 112, 125))
		add(Vector3.new(0.4, 1.8, 1.8), CFrame.new(0, 3.4, -3.5) * CFrame.Angles(0, math.pi / 2, 0), GOLD, CYL)
		add(Vector3.new(1.6, 0.35, 0.4), CFrame.new(1.5, 2.2, -3.55), GOLD)
		Kit.flatText(body, "$", GOLD, Enum.NormalId.Top)
		Kit.flatText(body, "$", GOLD, Enum.NormalId.Back)
		return parts, Color3.fromRGB(90, 200, 90)
	end
	-- Calendar (par défaut) : grand calendrier de bureau à plat, page « DUE TODAY! »
	local page = add(Vector3.new(11, 1, 9), CFrame.new(0, 0.5, 0), WHITE)
	add(Vector3.new(11.2, 1.25, 2.2), CFrame.new(0, 0.6, -3.6), RED)
	for i = -1.5, 1.5 do
		add(Vector3.new(1.6, 0.35, 0.35), CFrame.new(i * 2.6, 1.3, -3.6) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(40, 40, 45), CYL)
	end
	for gx = -2, 1 do -- cases de la grille
		add(Vector3.new(0.12, 1.04, 6.4), CFrame.new(gx * 2.1 + 1.05, 0.5, 1.0), Color3.fromRGB(200, 200, 205))
	end
	local l = Kit.flatText(page, "DUE TODAY!", RED, Enum.NormalId.Top)
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = WHITE
	return parts, ORANGE
end

local function bubble(size)
	local b = Kit.part({ Shape = BALL, Size = Vector3.one * size, Color = SOAP, Transparency = 0.55 })
	local shine = Kit.part({ Shape = BALL, Size = Vector3.one * size * 0.22, Color = WHITE, Transparency = 0.2 })
	local rim = Kit.part({ Shape = BALL, Size = Vector3.one * size * 1.04, Color = Color3.fromRGB(255, 190, 255), Transparency = 0.85 })
	return b, shine, rim
end

function M.ClientInit(api)
	local CartoonFX = api.CartoonFX
	local ProcAnim = api.ProcAnim
	Kit.setupClient()

	------------------------------------------------------------------ chute du ciel
	Kit.on("CoreDrop", function(d)
		local col = Kit.mine(d.a) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 70, 60)
		CartoonFX.bigTelegraph(d.p, d.r, d.fall, col)
		-- ombre qui grandit pendant la chute
		local shadow = Kit.part({ Shape = CYL, Size = Vector3.new(0.1, d.r * 0.4, d.r * 0.4), CFrame = CFrame.new(d.p + Vector3.new(0, 0.12, 0)) * UP, Color = Color3.new(0, 0, 0), Transparency = 0.7 })
		Kit.tween(shadow, d.fall, { Size = Vector3.new(0.1, d.r * 1.7, d.r * 1.7), Transparency = 0.35 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(shadow, d.fall + 0.05)
		local look = d.look and Kit.flat(d.look) or Vector3.new(0, 0, -1)
		local final = CFrame.lookAt(d.p, d.p + look)
		local top = final + Vector3.new(0, 55, 0)
		local parts, impactCol = buildDrop(d.model, top * CFrame.Angles(0, math.rad(25), 0))
		for _, e in ipairs(parts) do
			Kit.tween(e.p, d.fall, { CFrame = final * e.off }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Debris:AddItem(e.p, d.fall + 1.2)
		end
		CartoonFX.sound("Whoosh", d.p, 1)
		task.delay(d.fall, function()
			CartoonFX.quake(d.p, d.r * 1.2, impactCol, 1.4)
			CartoonFX.sound("GroundSlam", d.p, 1.4)
			CartoonFX.sound("Crash", d.p, 1.1)
			CartoonFX.word(d.p + Vector3.new(0, 5, 0), d.model == "Safe" and "BANKRUPT!" or "DEADLINE!", 1.3, "Heavy")
			CartoonFX.casterShake(d.a, 1.2)
			-- feuilles / billets qui volent
			for i = 1, 10 do
				local a = (i / 10) * math.pi * 2
				local s = Kit.part({ Size = Vector3.new(1.2, 0.06, 1.5), CFrame = CFrame.new(d.p + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, a, 0), Color = (d.model == "Safe") and Color3.fromRGB(110, 200, 100) or WHITE })
				Kit.tween(s, 0.8, { CFrame = CFrame.new(d.p + Vector3.new(math.cos(a) * (d.r + 3), Kit.rng:NextNumber(3, 7), math.sin(a) * (d.r + 3))) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Transparency = 1 })
				Debris:AddItem(s, 0.82)
			end
			-- l'objet s'écrase (léger tassement) puis disparaît
			for _, e in ipairs(parts) do
				if e.p.Parent then
					Kit.tween(e.p, 0.08, { CFrame = final * CFrame.new(0, -0.3, 0) * e.off })
					task.delay(0.75, function()
						if e.p.Parent then
							Kit.tween(e.p, 0.35, { Transparency = 1 })
						end
					end)
				end
			end
		end)
	end)

	------------------------------------------------------------------ bulle de savon
	Kit.on("CoreBubbleShot", function(d)
		local arm = d.a and d.a:FindFirstChild("Right Arm")
		if not arm then
			return
		end
		local b, shine, rim = bubble(2.4)
		local start = (arm.CFrame * CFrame.new(0, -1.5, -0.6)).Position
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local k = math.clamp((os.clock() - t0) / math.max(d.t, 0.05), 0, 1)
			local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
			local goal = vr and vr.Position or (start + d.dir * d.range)
			local pos = start:Lerp(goal, k) + Vector3.new(0, math.sin(k * math.pi) * 1.5, 0)
			local s = 2.4 + k * (vr and 4 or 1)
			b.Size, rim.Size, shine.Size = Vector3.one * s, Vector3.one * s * 1.04, Vector3.one * s * 0.22
			b.CFrame, rim.CFrame = CFrame.new(pos), CFrame.new(pos)
			shine.CFrame = CFrame.new(pos + Vector3.new(-s * 0.22, s * 0.22, -s * 0.1))
			if k >= 1 then
				conn:Disconnect()
				b:Destroy()
				shine:Destroy()
				rim:Destroy()
				if not vr then
					CartoonFX.puff(pos, 0.6)
					CartoonFX.shards(pos, 8, { SOAP, WHITE }, 0.7)
					CartoonFX.sound("Boing", pos, 0.6)
				end
			end
		end)
		for i = 1, 6 do -- petites bulles en traînée
			task.delay(i * 0.04, function()
				local p = start + d.dir * (i * 1.4) + Vector3.new(Kit.rng:NextNumber(-0.5, 0.5), Kit.rng:NextNumber(-0.3, 0.6), Kit.rng:NextNumber(-0.5, 0.5))
				local s = Kit.part({ Shape = BALL, Size = Vector3.one * Kit.rng:NextNumber(0.3, 0.7), CFrame = CFrame.new(p), Color = SOAP, Transparency = 0.4 })
				Kit.tween(s, 0.6, { CFrame = CFrame.new(p + Vector3.new(0, 2, 0)), Transparency = 1 })
				Debris:AddItem(s, 0.62)
			end)
		end
	end)

	Kit.on("CoreBubble", function(d)
		local vr = d.v and d.v:FindFirstChild("HumanoidRootPart")
		if not vr then
			return
		end
		local b, shine, rim = bubble(7.5)
		CartoonFX.sound("Boing", vr.Position, 1)
		CartoonFX.word(vr.Position + Vector3.new(0, 4.5, 0), "TRAPPED!", 0.9, "Splat")
		local t0 = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			if el > d.dur or not vr.Parent then
				conn:Disconnect()
				b:Destroy()
				shine:Destroy()
				rim:Destroy()
				return
			end
			local wob = 1 + math.sin(el * 14) * 0.05
			local s = 7.5 * wob
			b.Size, rim.Size = Vector3.new(s, 7.5 / wob, s), Vector3.new(s, 7.5 / wob, s) * 1.04
			b.CFrame, rim.CFrame = CFrame.new(vr.Position), CFrame.new(vr.Position)
			shine.CFrame = CFrame.new(vr.Position + Vector3.new(-1.8, 1.9, -1.2))
		end)
		task.spawn(function()
			while os.clock() - t0 < d.dur and vr.Parent do
				local p = vr.Position + Vector3.new(Kit.rng:NextNumber(-3, 3), -3, Kit.rng:NextNumber(-3, 3))
				local s = Kit.part({ Shape = BALL, Size = Vector3.one * Kit.rng:NextNumber(0.3, 0.8), CFrame = CFrame.new(p), Color = SOAP, Transparency = 0.4 })
				Kit.tween(s, 0.8, { CFrame = CFrame.new(p + Vector3.new(0, 4, 0)), Transparency = 1 })
				Debris:AddItem(s, 0.82)
				task.wait(0.08)
			end
		end)
	end)

	Kit.on("CoreBubblePop", function(d)
		CartoonFX.word(d.p + Vector3.new(0, 3, 0), "POP!", 1.2, "Splat")
		CartoonFX.sound("Boing", d.p, 1.2)
		CartoonFX.sound("Splat", d.p, 1)
		CartoonFX.puff(d.p, 1.4)
		CartoonFX.shards(d.p, 18, { SOAP, WHITE, Color3.fromRGB(255, 190, 255) }, 1.2)
		CartoonFX.sparks(d.p, 20, SOAP)
		CartoonFX.airRing(d.p, Vector3.new(0, -1, 0), 12, SOAP, 0.3)
		CartoonFX.light(d.p, SOAP, 18, 4, 0.25)
		if d.a then
			ProcAnim.play(d.a, "BubblePop")
		end
	end)

	------------------------------------------------------------------ chariot de cantine
	Kit.on("CoreCart", function(d)
		local c = d.a
		local root = c and c:FindFirstChild("HumanoidRootPart")
		if not root then
			return
		end
		local STEEL = Color3.fromRGB(200, 205, 215)
		local TIRE = Color3.fromRGB(30, 30, 35)
		local defs = {
			{ Vector3.new(4.6, 0.35, 3.4), CFrame.new(0, -1.3, -4.0), STEEL },
			{ Vector3.new(4.6, 0.3, 3.4), CFrame.new(0, 0.3, -4.0), STEEL },
			{ Vector3.new(0.25, 1.9, 0.25), CFrame.new(2.15, -0.5, -2.45), STEEL },
			{ Vector3.new(0.25, 1.9, 0.25), CFrame.new(-2.15, -0.5, -2.45), STEEL },
			{ Vector3.new(0.25, 1.9, 0.25), CFrame.new(2.15, -0.5, -5.55), STEEL },
			{ Vector3.new(0.25, 1.9, 0.25), CFrame.new(-2.15, -0.5, -5.55), STEEL },
			{ Vector3.new(4.4, 0.25, 0.25), CFrame.new(0, 0.7, -2.0) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(60, 60, 70), CYL },
			{ Vector3.new(1.4, 0.7, 1.4), CFrame.new(-1.3, 0.8, -4.3), FOOD[1] },
			{ Vector3.new(1.4, 0.9, 1.4), CFrame.new(0.4, 0.9, -3.6), FOOD[2] },
			{ Vector3.new(1.1, 0.6, 1.1), CFrame.new(1.4, 0.75, -4.6), FOOD[3] },
			{ Vector3.new(0.7, 0.7, 0.7), CFrame.new(-1.6, -2.0, -2.6), TIRE, BALL },
			{ Vector3.new(0.7, 0.7, 0.7), CFrame.new(1.6, -2.0, -2.6), TIRE, BALL },
			{ Vector3.new(0.7, 0.7, 0.7), CFrame.new(-1.6, -2.0, -5.4), TIRE, BALL },
			{ Vector3.new(0.7, 0.7, 0.7), CFrame.new(1.6, -2.0, -5.4), TIRE, BALL },
		}
		local parts = {}
		for _, def in ipairs(defs) do
			local p = Kit.part({ Size = def[1], Color = def[3], CFrame = root.CFrame * def[2] })
			if def[4] then
				p.Shape = def[4]
			end
			table.insert(parts, { p = p, off = def[2] })
		end
		local t0 = os.clock()
		local lastSpark = 0
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local el = os.clock() - t0
			if el > d.dur or not root.Parent then
				conn:Disconnect()
				for _, e in ipairs(parts) do
					e.p:Destroy()
				end
				return
			end
			local bounce = CFrame.new(0, math.abs(math.sin(el * 30)) * 0.12, 0)
			for _, e in ipairs(parts) do
				e.p.CFrame = root.CFrame * bounce * e.off
			end
			if el - lastSpark > 0.05 and el > 0.12 then
				lastSpark = el
				local w = (root.CFrame * CFrame.new(Kit.rng:NextNumber(-1.6, 1.6), -2.3, -2.6)).Position
				CartoonFX.sparks(w, 3, Color3.fromRGB(255, 220, 120))
				local f = Kit.part({ Size = Vector3.one * Kit.rng:NextNumber(0.3, 0.6), CFrame = root.CFrame * CFrame.new(Kit.rng:NextNumber(-1.5, 1.5), 1.2, -4), Color = FOOD[Kit.rng:NextInteger(1, #FOOD)] })
				Kit.tween(f, 0.5, { CFrame = f.CFrame * CFrame.new(Kit.rng:NextNumber(-2, 2), -2.5, 3) * CFrame.Angles(2, 2, 0), Transparency = 1 })
				Debris:AddItem(f, 0.52)
			end
		end)
		if Kit.mine(c) then
			task.delay(0.12, function()
				CartoonFX.speedLines(0.8, Color3.fromRGB(255, 110, 140))
			end)
		end
	end)

	Kit.on("CoreScoop", function(d)
		CartoonFX.word(d.p + Vector3.new(0, 2.5, 0), "SCOOPED!", 0.8, "Splat")
		CartoonFX.sound("Bonk", d.p, 1)
		CartoonFX.shards(d.p, 8, FOOD, 0.9)
	end)

	Kit.on("CoreCartCrash", function(d)
		CartoonFX.quake(d.p, 9, Color3.fromRGB(255, 110, 140), 1.1)
		CartoonFX.debris(d.p, 8, FOOD, 1.1, 0.9)
		CartoonFX.debris(d.p, 5, { Color3.fromRGB(200, 205, 215), Color3.fromRGB(160, 165, 175) }, 1.2, 1.1)
		CartoonFX.word(d.p + Vector3.new(0, 3.5, 0), "CRASH!", 1.2, "Heavy")
		CartoonFX.sound("Crash", d.p, 1.3)
		CartoonFX.sound("MetalHit", d.p, 1)
		CartoonFX.casterShake(d.a, 1)
	end)

	------------------------------------------------------------------ coude du ciel
	Kit.on("CoreElbowMark", function(d)
		local col = Kit.mine(d.a) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 70, 60)
		CartoonFX.bigTelegraph(d.p, d.r, d.dur, col)
		local r = d.a and d.a:FindFirstChild("HumanoidRootPart")
		task.delay(0.2, function()
			if r and r.Parent then
				CartoonFX.dust(r.Position - Vector3.new(0, 2.6, 0), 6)
				CartoonFX.airRing(r.Position - Vector3.new(0, 2, 0), Vector3.new(0, 1, 0), 7, WHITE, 0.25)
				CartoonFX.sound("Boing", r.Position, 0.7)
			end
		end)
	end)

	Kit.on("CoreElbowLand", function(d)
		CartoonFX.quake(d.p, 12, GOLD, 1.5)
		CartoonFX.pillar(d.p, 3, 14, Color3.fromRGB(255, 60, 60), 0.3)
		task.delay(0.05, function()
			CartoonFX.pillar(d.p, 2.2, 12, Color3.fromRGB(60, 140, 255), 0.3)
		end)
		CartoonFX.sound("GroundSlam", d.p, 1.4)
		CartoonFX.sound("BigImpact", d.p, 1.2)
		CartoonFX.casterShake(d.a, 1.3)
	end)

	------------------------------------------------------------------ contre
	Kit.on("CoreCounter", function(d)
		CartoonFX.puff(d.from, 0.9)
		CartoonFX.puff(d.to, 0.7)
		CartoonFX.beam(d.from + Vector3.new(0, 0.5, 0), d.to + Vector3.new(0, 0.5, 0), 1.2, Color3.fromRGB(120, 70, 40), 0.25)
		CartoonFX.word(d.to + Vector3.new(0, 4, 0), "TOO SLOW!", 1.1, "Parry")
		CartoonFX.sound("Whoosh", d.to, 1.2)
		CartoonFX.sound("Parry", d.to, 0.8)
		if d.a then
			if d.anim then
				ProcAnim.play(d.a, d.anim)
			end
			local r = d.a:FindFirstChild("HumanoidRootPart")
			task.delay(0.08, function()
				if r and r.Parent then
					CartoonFX.slashArc(r.CFrame, 4.5, ORANGE, 70, -90, 0.1, 0, 0.6)
				end
			end)
			if Kit.mine(d.a) then
				CartoonFX.speedLines(0.4, ORANGE)
				CartoonFX.impactFrame(0.8)
			end
		end
	end)

	Kit.on("CoreCounterEnd", function(d)
		local head = d.a and d.a:FindFirstChild("Head")
		if head then
			Kit.floatText(head.Position + Vector3.new(0, 1.5, 0), "...", Color3.fromRGB(255, 220, 160), 1.6, 0.6, 1)
		end
	end)
end

return M
