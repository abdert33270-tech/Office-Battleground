--[[
	ContentKit — outils partagés par les personnages de ReplicatedStorage.Shared.Content (serveur ET client).
	Serveur : Kit.fx (effet client "Content"), Kit.enemies, Kit.inRadius, Kit.firstInLine, Kit.pull (tirer une cible),
	          Kit.hold (gel sur place), Kit.projectile (projectile perso : rebonds, callback onHit), Kit.ground, Kit.sPart.
	Client  : Kit.on(id, fn) (reçoit les Kit.fx du serveur), Kit.part, Kit.cubes, Kit.flatText, Kit.telegraph.
	Aucun effet de bord au require : la connexion client se fait au premier Kit.on().
	Filtre des mots : chaque payload Kit.fx porte le lanceur (a, ou ca déduit du thread serveur) et la victime connue
	(v / cv / vs) ; Kit.on appelle les handlers dans CartoonFX.withContext(lanceur, victime) (voir Kit.context).
	Kit.withCaster(attaquant, victime, fn, ...) pose ce contexte à la main (threads créés par le code Content).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Modules.Net)
local Hitbox = require(Shared.Modules.Hitbox)

local Kit = {}
Kit.rng = Random.new()
Kit.CYL = Enum.PartType.Cylinder
Kit.BALL = Enum.PartType.Ball
Kit.UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylindre vertical

local function now()
	return workspace:GetServerTimeNow()
end
Kit.now = now

function Kit.root(c)
	return c and c:FindFirstChild("HumanoidRootPart")
end

function Kit.flat(v, fallback)
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.05 then
		f = fallback and Vector3.new(fallback.X, 0, fallback.Z) or Vector3.new(0, 0, -1)
	end
	return f.Magnitude > 0 and f.Unit or Vector3.new(0, 0, -1)
end

-- direction de visée validée (comme Kinds.Projectile)
function Kit.aimDir(attacker, aim)
	Kit.noteCaster(attacker)
	local root = Kit.root(attacker)
	local look = root and root.CFrame.LookVector or Vector3.new(0, 0, -1)
	local base = (typeof(aim) == "Vector3" and aim.Magnitude > 0.5 and aim.Magnitude < 2) and aim.Unit or look
	return Kit.flat(base, look)
end

------------------------------------------------------------------------
-- SERVEUR
------------------------------------------------------------------------
-- CONTEXTE (lanceur / victime) des Kit.fx : le filtre des onomatopées côté client (CartoonFX.isRelevant)
-- a besoin de savoir qui attaque qui. Les Kinds de Content tournent chacun dans un thread neuf
-- (task.spawn d'AbilityService) : toute fonction du Kit qui reçoit l'attaquant le note sur le thread courant,
-- et Kit.fx l'ajoute au payload (clés ca / cv : jamais a / v, pour ne pas changer le comportement des handlers
-- qui testent d.a / d.v). Les callbacks onHit de Kit.projectile reçoivent (attaquant, victime) explicitement.
local CTX_LIFE = 8 -- s : au-delà, un indice est jugé périmé (threads de connexions réutilisés)
local threadCtx = setmetatable({}, { __mode = "k" }) -- [thread] = { a, v, t }

local function isChar(m)
	return typeof(m) == "Instance" and m:IsA("Model")
end

-- note l'attaquant (et la victime) du thread courant
function Kit.noteCaster(attacker, victim)
	if not isChar(attacker) then
		return
	end
	local th = coroutine.running()
	local c = threadCtx[th]
	if c and c.a == attacker then
		c.t = os.clock()
		if victim ~= nil then
			c.v = victim
		end
	else
		threadCtx[th] = { a = attacker, v = victim, t = os.clock() }
	end
end

-- exécute fn(...) avec un contexte explicite (pour du code Content qui crée ses propres threads)
function Kit.withCaster(attacker, victim, fn, ...)
	local th = coroutine.running()
	local prev = threadCtx[th]
	threadCtx[th] = isChar(attacker) and { a = attacker, v = victim, t = os.clock() } or prev
	local res = table.pack(pcall(fn, ...))
	threadCtx[th] = prev
	if not res[1] then
		error(res[2], 0)
	end
	return table.unpack(res, 2, res.n)
end

local fxRemote
function Kit.fx(data)
	fxRemote = fxRemote or Net.get("FX")
	data.k = "Content"
	if isChar(data.a) then
		Kit.noteCaster(data.a) -- payload explicite : rafraîchit l'indice pour les Kit.fx suivants
	else
		local c = threadCtx[coroutine.running()]
		if c and os.clock() - c.t < CTX_LIFE and c.a.Parent then
			data.ca = c.a
			if data.v == nil and data.cv == nil and isChar(c.v) then
				data.cv = c.v
			end
		end
	end
	fxRemote:FireAllClients(data)
end
function Kit.rawFX(data)
	fxRemote = fxRemote or Net.get("FX")
	fxRemote:FireAllClients(data)
end

function Kit.isProtected(c)
	return c:FindFirstChildOfClass("ForceField") ~= nil or c:GetAttribute("God") == true
end

function Kit.enemies(attacker)
	Kit.noteCaster(attacker)
	local list = {}
	for _, c in ipairs(Hitbox.characters()) do
		if c ~= attacker and Kit.root(c) then
			table.insert(list, c)
		end
	end
	return list
end

function Kit.inRadius(attacker, center, radius)
	local list = {}
	for _, c in ipairs(Kit.enemies(attacker)) do
		local r = Kit.root(c)
		if (r.Position - center).Magnitude <= radius then
			table.insert(list, c)
		end
	end
	return list
end

-- premier ennemi sur une ligne (origine, direction, portée, largeur)
function Kit.firstInLine(attacker, origin, dir, range, width)
	Kit.noteCaster(attacker)
	local cf = CFrame.lookAt(origin + dir * range / 2, origin + dir * range)
	local hits = Hitbox.box(cf, Vector3.new(width, 7, range), attacker)
	local best, bestD = nil, math.huge
	for _, v in ipairs(hits) do
		local d = (Kit.root(v).Position - origin).Magnitude
		if d < bestD then
			best, bestD = v, d
		end
	end
	return best, bestD
end

local function rootAtt(r)
	local att = r:FindFirstChild("KBAtt")
	if not att then
		att = Instance.new("Attachment")
		att.Name = "KBAtt"
		att.Parent = r
	end
	return att
end

-- tire la victime vers target (vitesse en studs/s), renvoie la durée du trajet
function Kit.pull(victim, target, speed, stopDist)
	local vr = Kit.root(victim)
	if not vr then
		return 0
	end
	local to = Vector3.new(target.X - vr.Position.X, 0, target.Z - vr.Position.Z)
	local dist = to.Magnitude - (stopDist or 3.5)
	if dist <= 0.5 then
		return 0
	end
	for _, n in ipairs({ "KB", "ContentPull", "ContentHold" }) do
		local o = vr:FindFirstChild(n)
		if o then
			o:Destroy()
		end
	end
	local t = math.clamp(dist / speed, 0.08, 0.9)
	local lv = Instance.new("LinearVelocity")
	lv.Name = "ContentPull"
	lv.Attachment0 = rootAtt(vr)
	lv.MaxForce = 1e7
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = to.Unit * (dist / t) + Vector3.new(0, 2, 0)
	lv.Parent = vr
	Debris:AddItem(lv, t)
	return t
end

-- gèle la victime sur place (vitesse nulle imposée)
function Kit.hold(victim, duration)
	local vr = Kit.root(victim)
	if not vr then
		return
	end
	local old = vr:FindFirstChild("ContentHold")
	if old then
		old:Destroy()
	end
	local lv = Instance.new("LinearVelocity")
	lv.Name = "ContentHold"
	lv.Attachment0 = rootAtt(vr)
	lv.MaxForce = 1e7
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = Vector3.zero
	lv.Parent = vr
	Debris:AddItem(lv, duration)
end

local function excludeList()
	local ex = { workspace:FindFirstChild("FX"), workspace:FindFirstChild("Zones"), workspace:FindFirstChild("ActiveItems"), workspace:FindFirstChild("Dummies") }
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character then
			table.insert(ex, pl.Character)
		end
	end
	return ex
end
Kit.excludeList = excludeList

-- sol sous une position (ignore personnages / effets)
function Kit.ground(pos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList()
	local r = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), params)
	return r and r.Position or (pos - Vector3.new(0, 3, 0))
end

-- mur entre deux points ? (renvoie la position sûre la plus loin)
function Kit.safePoint(from, to, margin)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList()
	local d = to - from
	local r = workspace:Raycast(from, d, params)
	if r and r.Instance.CanCollide then
		return r.Position - d.Unit * (margin or 2)
	end
	return to
end

-- part serveur simple (dans workspace.FX)
function Kit.sPart(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent or workspace:FindFirstChild("FX") or workspace
	return p
end

--[[ projectile serveur personnalisé
	opts = { origin, dir, speed, range, size, color, shape, gravity, up, bounces, spin,
	         decorate = function(part) (parts soudées), onHit = function(victim, pos, vel, part) -> true pour continuer,
	         onEnd = function(pos) }
]]
function Kit.projectile(attacker, opts)
	Kit.noteCaster(attacker)
	local part = Kit.sPart({ Name = "Projectile", Size = opts.size or Vector3.one, Color = opts.color or Color3.new(1, 1, 1) })
	if opts.shape then
		part.Shape = opts.shape
	end
	local dir = opts.dir
	part.CFrame = CFrame.lookAt(opts.origin, opts.origin + dir)
	if opts.decorate then
		opts.decorate(part)
	end
	local vel = dir * opts.speed + Vector3.new(0, opts.up or 0, 0)
	local traveled, bounces = 0, opts.bounces or 0
	local hitSet = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList()
	local spin = opts.spin or 0
	local conn
	local function finish(pos)
		conn:Disconnect()
		Kit.rawFX({ k = "ProjPop", p = pos, c = part.Color })
		part:Destroy()
		if opts.onEnd then
			Kit.withCaster(attacker, nil, opts.onEnd, pos)
		end
	end
	conn = RunService.Heartbeat:Connect(function(dt)
		if not part.Parent then
			conn:Disconnect()
			return
		end
		vel -= Vector3.new(0, workspace.Gravity * (opts.gravity or 0) * dt, 0)
		local step = vel * dt
		local wall = workspace:Raycast(part.Position, step, params)
		if wall then
			if bounces > 0 and math.abs(wall.Normal.Y) < 0.7 then
				bounces -= 1
				vel = vel - 2 * vel:Dot(wall.Normal) * wall.Normal
				part.CFrame = CFrame.new(wall.Position + wall.Normal * 0.6) * (part.CFrame - part.Position)
				Kit.rawFX({ k = "ProjPop", p = wall.Position, c = part.Color })
				return
			end
			finish(wall.Position)
			return
		end
		local newPos = part.Position + step
		traveled += step.Magnitude
		part.CFrame = CFrame.new(newPos) * (part.CFrame - part.Position) * CFrame.Angles(0, spin * dt, 0)
		for _, v in ipairs(Hitbox.box(CFrame.new(newPos), part.Size + Vector3.one * 2.5, attacker, 3)) do
			if not hitSet[v] then
				hitSet[v] = true
				local keep = opts.onHit and Kit.withCaster(attacker, v, opts.onHit, v, newPos, vel, part)
				if keep and typeof(keep) == "Vector3" then
					vel = keep -- nouvelle vitesse (rebond vers une autre cible)
					traveled = 0
					return
				elseif not keep then
					finish(newPos)
					return
				end
			end
		end
		if traveled > (opts.range or 60) then
			finish(newPos)
		end
	end)
	return part
end

------------------------------------------------------------------------
-- CLIENT
------------------------------------------------------------------------
local handlers = {}
local connected = false
local player = Players.LocalPlayer

function Kit.mine(c)
	return player ~= nil and c ~= nil and c == player.Character
end

-- (attaquant, victime) d'un payload Kit.fx pour le filtre des mots : a / v explicites, sinon ca / cv
-- (contexte serveur), et si je fais partie de la liste vs je suis la victime
function Kit.context(d)
	local a = isChar(d.a) and d.a or (isChar(d.ca) and d.ca or nil)
	local v = isChar(d.v) and d.v or (isChar(d.cv) and d.cv or nil)
	local me = player and player.Character
	if me and v == nil and a ~= me and type(d.vs) == "table" then
		for _, m in ipairs(d.vs) do
			if m == me then
				v = me
				break
			end
		end
	end
	return a, v
end

function Kit.on(id, fn)
	handlers[id] = fn
	if connected or RunService:IsServer() then
		return
	end
	connected = true
	task.spawn(function()
		local CartoonFX = require(Shared.Modules.CartoonFX) -- paresseux : jamais requis côté serveur
		Net.get("FX").OnClientEvent:Connect(function(d)
			if type(d) == "table" and d.k == "Content" then
				local h = handlers[d.id or ""]
				if h then
					local a, v = Kit.context(d)
					if not CartoonFX.withContext(a, v, h, d) then
						warn("[ContentKit] handler en erreur :", d.id)
					end
				end
			end
		end)
	end)
end

function Kit.part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = workspace:FindFirstChild("FX") or workspace
	return p
end

function Kit.tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- petits cubes qui jaillissent (glitch, pixels, pièces…)
function Kit.cubes(pos, n, colors, size, speed, life)
	for _ = 1, n do
		local s = (size or 0.6) * Kit.rng:NextNumber(0.6, 1.4)
		local c = Kit.part({ Size = Vector3.one * s, CFrame = CFrame.new(pos) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Color = colors[Kit.rng:NextInteger(1, #colors)] })
		local dir = Vector3.new(Kit.rng:NextNumber(-1, 1), Kit.rng:NextNumber(-0.2, 1), Kit.rng:NextNumber(-1, 1)).Unit
		local l = life or 0.5
		Kit.tween(c, l, { CFrame = CFrame.new(pos + dir * (speed or 8)) * CFrame.Angles(Kit.rng:NextNumber(0, 6), Kit.rng:NextNumber(0, 6), 0), Transparency = 1, Size = Vector3.one * s * 0.4 })
		Debris:AddItem(c, l + 0.05)
	end
end

-- texte posé sur une face de part (SurfaceGui)
function Kit.flatText(partObj, text, color, face, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face or Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = partObj
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = font or Enum.Font.LuckiestGuy
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Parent = gui
	return l
end

-- cercle d'alerte au sol (jaune pour moi, rouge pour les autres)
function Kit.telegraph(pos, radius, dur, attacker)
	local col = Kit.mine(attacker) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 70, 60)
	local p = Kit.part({ Shape = Kit.CYL, Size = Vector3.new(0.12, radius * 2, radius * 2), CFrame = CFrame.new(pos + Vector3.new(0, 0.1, 0)) * Kit.UPRIGHT, Color = col, Transparency = 0.6 })
	local ring = Kit.part({ Shape = Kit.CYL, Size = Vector3.new(0.14, 0.5, 0.5), CFrame = CFrame.new(pos + Vector3.new(0, 0.12, 0)) * Kit.UPRIGHT, Color = col, Transparency = 0.3 })
	Kit.tween(p, dur, { Transparency = 0.35 })
	Kit.tween(ring, dur, { Size = Vector3.new(0.14, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)
	task.delay(dur, function()
		Kit.tween(p, 0.2, { Transparency = 1 })
		ring:Destroy()
	end)
	Debris:AddItem(p, dur + 0.25)
end

-- texte flottant qui monte et s'efface (chiffres, $, etc.)
function Kit.floatText(pos, text, color, size, life, rise)
	life = life or 0.8
	local p = Kit.part({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, Position = pos })
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(size or 2, size or 2)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = p
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.FontFace = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Bold) -- police pixel (UITheme.Display)
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Parent = bb
	local st = Instance.new("UIStroke")
	st.Thickness = 2
	st.LineJoinMode = Enum.LineJoinMode.Miter
	st.Parent = l
	Kit.tween(p, life, { Position = pos + Vector3.new(0, rise or 3, 0) })
	task.delay(life * 0.5, function()
		Kit.tween(l, life * 0.5, { TextTransparency = 1 })
		Kit.tween(st, life * 0.5, { Transparency = 1 })
	end)
	Debris:AddItem(p, life + 0.05)
end

-- étiquette permanente au-dessus de la tête (marque d'audit, write-up…) ; text = nil pour l'enlever
function Kit.mark(c, name, text, color)
	local head = c:FindFirstChild("Head")
	local bb = head and head:FindFirstChild(name)
	if not text then
		if bb then
			bb:Destroy()
		end
		return
	end
	if not head then
		return
	end
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = name
		bb.Size = UDim2.fromScale(4.5, 1.2)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.Parent = head
		local f = Instance.new("TextLabel")
		f.Name = "L"
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = color or Color3.new(1, 0, 0)
		f.FontFace = Font.new("rbxasset://fonts/families/PressStart2P.json", Enum.FontWeight.Bold)
		f.TextScaled = true
		f.TextColor3 = Color3.new(1, 1, 1)
		f.Rotation = -6
		f.Parent = bb
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(0.25, 0)
		cr.Parent = f
		local st = Instance.new("UIStroke")
		st.Thickness = 2
		st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		st.Parent = f
	end
	bb.L.Text = text
	bb.L.BackgroundColor3 = color or bb.L.BackgroundColor3
end

------------------------------------------------------------------------
-- Ajouts (Barista / Delivery Guy / Receptionist / Fitness Coach)
-- Serveur : Kit.inCircle, Kit.inRect, Kit.dash, Kit.leap, Kit.holdAt
-- Client  : Kit.rectTelegraph, Kit.rope (corde / câble / fil de téléphone en spirale)
------------------------------------------------------------------------
-- ennemis non protégés dans un disque horizontal (dy = tolérance verticale)
function Kit.inCircle(attacker, center, radius, dy)
	local list = {}
	for _, c in ipairs(Kit.enemies(attacker)) do
		local p = Kit.root(c).Position
		if Vector3.new(p.X - center.X, 0, p.Z - center.Z).Magnitude <= radius and math.abs(p.Y - center.Y) <= (dy or 9) and not Kit.isProtected(c) then
			table.insert(list, c)
		end
	end
	return list
end

-- ennemis non protégés dans un rectangle (cf = repère au début du rectangle, -Z = vers l'avant)
function Kit.inRect(attacker, cf, width, length, dy)
	local list = {}
	for _, c in ipairs(Kit.enemies(attacker)) do
		local lp = cf:PointToObjectSpace(Kit.root(c).Position)
		if math.abs(lp.X) <= width / 2 and lp.Z <= 1.5 and lp.Z >= -length and math.abs(lp.Y) <= (dy or 9) and not Kit.isProtected(c) then
			table.insert(list, c)
		end
	end
	return list
end

-- ruée horizontale (s'arrête devant un mur) ; onStep(root) renvoie true pour arrêter
function Kit.dash(attacker, dir, speed, duration, onStep)
	Kit.noteCaster(attacker)
	local root = Kit.root(attacker)
	if not root then
		return
	end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	local lv = Instance.new("LinearVelocity")
	lv.Name = "ContentDash"
	lv.Attachment0 = rootAtt(root)
	lv.MaxForce = 1e6
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(dir.X * speed, dir.Z * speed)
	lv.Parent = root
	Debris:AddItem(lv, duration)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = excludeList()
	local t0 = os.clock()
	while os.clock() - t0 < duration and root.Parent and lv.Parent do
		local wall = workspace:Raycast(root.Position, dir * 4, params)
		if wall and wall.Instance.CanCollide then
			break
		end
		if onStep and onStep(root) then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if lv.Parent then
		lv:Destroy()
	end
end

-- bond vers un point : montée (up studs/s pendant rise s) puis chute rapide ; rend la main à l'atterrissage
function Kit.leap(attacker, dest, up, rise)
	Kit.noteCaster(attacker)
	local root = Kit.root(attacker)
	local hum = attacker:FindFirstChildOfClass("Humanoid")
	if not root or not hum then
		return
	end
	local flatTo = Vector3.new(dest.X - root.Position.X, 0, dest.Z - root.Position.Z)
	local hv = flatTo / (rise + 0.18)
	local lv = Instance.new("LinearVelocity")
	lv.Name = "ContentLeap"
	lv.Attachment0 = rootAtt(root)
	lv.MaxForce = 1e6
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VectorVelocity = hv + Vector3.new(0, up, 0)
	lv.Parent = root
	Debris:AddItem(lv, rise + 1.3)
	task.wait(rise)
	lv.VectorVelocity = hv + Vector3.new(0, -130, 0)
	local t0 = os.clock()
	while os.clock() - t0 < 1.1 and root.Parent and lv.Parent do
		if os.clock() - t0 > 0.04 and hum.FloorMaterial ~= Enum.Material.Air then
			break
		end
		local rem = Vector3.new(dest.X - root.Position.X, 0, dest.Z - root.Position.Z)
		if rem.Magnitude < 1.5 or rem:Dot(flatTo) < 0 then
			lv.VectorVelocity = Vector3.new(0, -130, 0)
		end
		RunService.Heartbeat:Wait()
	end
	if lv.Parent then
		lv:Destroy()
	end
end

-- maintient la victime à offset (repère de la racine de l'attaquant) ; renvoie release(keepDown), attachment (bouger a1.Position)
function Kit.holdAt(victim, attacker, offset)
	Kit.noteCaster(attacker, victim)
	local vr, ar = Kit.root(victim), Kit.root(attacker)
	local hum = victim:FindFirstChildOfClass("Humanoid")
	if not vr or not ar then
		return function() end
	end
	for _, n in ipairs({ "KB", "ContentPull", "ContentHold" }) do
		local o = vr:FindFirstChild(n)
		if o then
			o:Destroy()
		end
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "ContentGrabA0"
	a0.Parent = vr
	local a1 = Instance.new("Attachment")
	a1.Name = "ContentGrabA1"
	a1.Position = offset
	a1.Parent = ar
	local ap = Instance.new("AlignPosition")
	ap.Name = "ContentGrab"
	ap.Attachment0 = a0
	ap.Attachment1 = a1
	ap.RigidityEnabled = true
	ap.Parent = vr
	if hum then
		hum.PlatformStand = true
	end
	local done = false
	return function(keepDown)
		if done then
			return
		end
		done = true
		ap:Destroy()
		a0:Destroy()
		a1:Destroy()
		if not keepDown and hum then
			task.delay(0.7, function()
				if hum.Parent and hum.Health > 0 then
					hum.PlatformStand = false
				end
			end)
		end
	end, a1
end

-- rectangle d'alerte au sol (cf = début du rectangle au sol, -Z = vers l'avant) — client
function Kit.rectTelegraph(cf, width, length, dur, attacker)
	local col = Kit.mine(attacker) and Color3.fromRGB(255, 220, 80) or Color3.fromRGB(255, 70, 60)
	local base = cf * CFrame.new(0, 0.1, -length / 2)
	local p = Kit.part({ Size = Vector3.new(width, 0.12, length), CFrame = base, Color = col, Transparency = 0.6 })
	local fill = Kit.part({ Size = Vector3.new(width, 0.14, 0.2), CFrame = cf * CFrame.new(0, 0.12, -0.1), Color = col, Transparency = 0.3 })
	Kit.tween(p, dur, { Transparency = 0.35 })
	Kit.tween(fill, dur, { Size = Vector3.new(width, 0.14, length), CFrame = base * CFrame.new(0, 0.02, 0) }, Enum.EasingStyle.Linear)
	task.delay(dur, function()
		Kit.tween(p, 0.2, { Transparency = 1 })
		fill:Destroy()
	end)
	Debris:AddItem(p, dur + 0.25)
end

-- corde entre la main droite de c et la victime v (ou lancée dans dir sur range) — client
-- coil = true : fil de téléphone en spirale
function Kit.rope(c, v, dir, range, dur, color, thick, tipColor, tipSize, coil)
	local rope = Kit.part({ Size = Vector3.new(thick, thick, 1), Color = color })
	local tip = Kit.part({ Size = tipSize or Vector3.one * thick * 2.4, Color = tipColor or color })
	local coils = {}
	if coil then
		rope.Transparency = 1
		for i = 1, 22 do
			coils[i] = Kit.part({ Shape = Kit.BALL, Size = Vector3.one * thick * 1.6, Color = color })
		end
	end
	local t0 = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local el = os.clock() - t0
		local arm = c and c:FindFirstChild("Right Arm")
		if el > dur or not arm then
			conn:Disconnect()
			rope:Destroy()
			tip:Destroy()
			for _, s in ipairs(coils) do
				s:Destroy()
			end
			return
		end
		local from = (arm.CFrame * CFrame.new(0, -1.1, 0)).Position
		local to
		local vr = v and v:FindFirstChild("HumanoidRootPart")
		if vr then
			to = from:Lerp(vr.Position + Vector3.new(0, 0.5, 0), math.clamp(el / 0.1, 0, 1))
		else
			local k = el < dur * 0.5 and el / (dur * 0.5) or (dur - el) / (dur * 0.5)
			to = from + (dir or Vector3.new(0, 0, -1)) * (range or 20) * math.clamp(k, 0, 1)
		end
		local len = math.max((to - from).Magnitude, 0.1)
		local cf = CFrame.lookAt(from, to)
		rope.Size = Vector3.new(thick, thick, len)
		rope.CFrame = cf * CFrame.new(0, 0, -len / 2)
		tip.CFrame = cf * CFrame.new(0, 0, -len)
		for i, s in ipairs(coils) do
			local a = i * 1.9 + el * 20
			s.CFrame = cf * CFrame.new(math.cos(a) * 0.32, math.sin(a) * 0.32, -len * i / (#coils + 1))
		end
	end)
end

function Kit.setupClient()
	Kit.on("Telegraph", function(d)
		Kit.telegraph(d.p, d.r, d.dur or 0.3, d.a)
	end)
end

return Kit
