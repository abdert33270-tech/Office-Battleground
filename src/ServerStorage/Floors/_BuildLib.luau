--[[
	_BuildLib — outils d'ÉDITION pour construire les étages (pas utilisé en jeu).
	Tous les étages : sol dont le dessus est à Y=0, emprise 220x220 centrée sur l'origine.
]]
local CS = game:GetService("CollectionService")
local L = {}
L.SIZE = 220
L.HALF = 110

function L.C(r, g, b) return Color3.fromRGB(r, g, b) end

function L.folder(parent, name)
	local f = parent:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name; f.Parent = parent; return f
end

function L.new(name, display, palette)
	local old = game.ServerStorage.Floors:FindFirstChild(name)
	if old then old:Destroy() end
	local m = Instance.new("Model")
	m.Name = name
	m:SetAttribute("FloorName", name)
	m:SetAttribute("DisplayName", display)
	m:SetAttribute("Palette", palette)
	for _, f in ipairs({"FloorTiles","Structure","Decor","ItemSpawns","PlayerSpawns","DummySpawns","EventPoints"}) do
		L.folder(m, f)
	end
	m.Parent = game.ServerStorage.Floors
	return m
end

-- opts: shape, transparency, material, name, collide(bool), query(bool), cast(bool)
function L.part(parent, size, cf, color, opts)
	opts = opts or {}
	local p = Instance.new("Part")
	p.Name = opts.name or "Part"
	if opts.shape then p.Shape = opts.shape end
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = opts.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = true
	p.Transparency = opts.transparency or 0
	if opts.collide == false then p.CanCollide = false end
	if opts.query == false then p.CanQuery = false end
	if opts.cast == false then p.CastShadow = false end
	p.Parent = parent
	return p
end

local CYL = CFrame.Angles(0, 0, math.pi / 2)
L.CYL = CYL

function L.model(parent, name, breakable)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	if breakable then CS:AddTag(m, "Breakable") end
	return m
end

function L.finish(m)
	local best, vol = nil, -1
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			local v = p.Size.X * p.Size.Y * p.Size.Z
			if v > vol then best, vol = p, v end
		end
	end
	m.PrimaryPart = best
	return m
end

-- Sol en dalles pré-découpées (n x n), deux teintes en damier discret
function L.tiles(floor, colorA, colorB, n)
	n = n or 10
	local s = L.SIZE / n
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local x = -L.HALF + s * (i + 0.5)
			local z = -L.HALF + s * (j + 0.5)
			local col = ((i + j) % 2 == 0) and colorA or colorB
			local t = L.part(floor.FloorTiles, Vector3.new(s, 2, s), Vector3.new(x, -1, z), col, { name = "FloorTile" })
			t:SetAttribute("Gx", i); t:SetAttribute("Gz", j)
		end
	end
end

-- Mur plein
function L.wall(parent, a, b, height, thick, color, y0)
	y0 = y0 or 0
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(Vector3.new(mid.X, y0 + height / 2, mid.Z), Vector3.new(b.X, y0 + height / 2, b.Z))
	return L.part(parent, Vector3.new(thick, height, len), cf, color, { name = "Wall" })
end

-- Murs extérieurs (4 côtés) + plinthe + bande déco. windows = {N=true,...} : fenêtres (vitre bleue) sur ces côtés
function L.outerWalls(floor, height, color, trim, stripe, windows)
	local h = L.HALF
	local sides = {
		N = { Vector3.new(-h, 0, -h - 0.5), Vector3.new(h, 0, -h - 0.5) },
		S = { Vector3.new(-h, 0, h + 0.5), Vector3.new(h, 0, h + 0.5) },
		W = { Vector3.new(-h - 0.5, 0, -h - 1), Vector3.new(-h - 0.5, 0, h + 1) },
		E = { Vector3.new(h + 0.5, 0, -h - 1), Vector3.new(h + 0.5, 0, h + 1) },
	}
	for name, ab in pairs(sides) do
		local a, b = ab[1], ab[2]
		if windows and windows[name] then
			-- bas plein, vitrage, haut plein
			L.wall(floor.Structure, a, b, 4, 1, color, 0)
			local glass = L.wall(floor.Structure, a, b, height - 8, 0.5, L.C(170, 215, 255), 4)
			glass.Transparency = 0.5; glass.CastShadow = false; glass.Name = "Glass"
			L.wall(floor.Structure, a, b, 4, 1, color, height - 4)
			-- montants
			local dir = (b - a).Unit
			local len = (b - a).Magnitude
			for d = 0, len, 20 do
				local p = a + dir * d
				L.part(floor.Structure, Vector3.new(1.2, height, 1.2), Vector3.new(p.X, height / 2, p.Z), trim, { name = "Mullion" })
			end
		else
			L.wall(floor.Structure, a, b, height, 1, color, 0)
			if stripe then
				local s = L.wall(floor.Structure, a, b, 1, 1.2, stripe, 7)
				s.Name = "Stripe"
			end
		end
		local base = L.wall(floor.Structure, a, b, 1, 1.4, trim, 0)
		base.Name = "Baseboard"
	end
end

function L.marker(folder, name, pos, attrs)
	local p = L.part(folder, Vector3.new(2, 1, 2), pos, L.C(255, 0, 255), { name = name, transparency = 1, collide = false, query = false, cast = false })
	p.CanTouch = false
	for k, v in pairs(attrs or {}) do p:SetAttribute(k, v) end
	return p
end

-- ItemSpawn : y = hauteur de la surface où l'objet repose
function L.item(floor, id, x, y, z)
	local p = L.part(floor.ItemSpawns, Vector3.new(1, 1, 1), Vector3.new(x, y + 0.5, z), L.C(255, 0, 255), { name = "ItemSpawn", transparency = 1, collide = false, query = false, cast = false })
	p.CanTouch = false
	p:SetAttribute("ItemId", id)
	return p
end

function L.playerSpawn(floor, x, z) return L.marker(floor.PlayerSpawns, "PlayerSpawn", Vector3.new(x, 0.5, z)) end
function L.dummySpawn(floor, x, z) return L.marker(floor.DummySpawns, "DummySpawn", Vector3.new(x, 0.5, z)) end
function L.event(floor, name, x, y, z, attrs) return L.marker(floor.EventPoints, name, Vector3.new(x, y, z), attrs) end

---------------------------------------------------------------- décor
-- cf = position au sol (Y=0) + orientation ; l'avant du meuble = -Z local
function L.monitor(parent, cf, screen)
	local m = L.model(parent, "Monitor", true)
	L.part(m, Vector3.new(1.2, 0.15, 0.9), cf * CFrame.new(0, 0.075, 0), L.C(45, 45, 55))
	L.part(m, Vector3.new(0.25, 0.9, 0.25), cf * CFrame.new(0, 0.6, 0.1), L.C(45, 45, 55))
	L.part(m, Vector3.new(2.6, 1.6, 0.2), cf * CFrame.new(0, 1.6, 0), L.C(40, 40, 50))
	local s = L.part(m, Vector3.new(2.3, 1.3, 0.05), cf * CFrame.new(0, 1.6, -0.12), screen or L.C(70, 190, 255))
	s.Name = "Screen"
	return L.finish(m)
end

function L.desk(parent, cf, top, leg, withMonitor, screen)
	local m = L.model(parent, "Desk", false)
	top = top or L.C(240, 240, 245); leg = leg or L.C(40, 90, 200)
	L.part(m, Vector3.new(6, 0.4, 3), cf * CFrame.new(0, 2.8, 0), top)
	L.part(m, Vector3.new(0.4, 2.6, 2.6), cf * CFrame.new(-2.7, 1.3, 0), leg)
	L.part(m, Vector3.new(0.4, 2.6, 2.6), cf * CFrame.new(2.7, 1.3, 0), leg)
	L.part(m, Vector3.new(5.0, 1.6, 0.2), cf * CFrame.new(0, 1.8, 1.3), leg)
	L.finish(m)
	if withMonitor ~= false then L.monitor(parent, cf * CFrame.new(0, 3, 0.4), screen) end
	return m
end

function L.decoChair(parent, cf, color)
	local m = L.model(parent, "DecoChair", true)
	color = color or L.C(40, 90, 200)
	L.part(m, Vector3.new(2.2, 0.4, 2.2), cf * CFrame.new(0, 1.8, 0), color)
	L.part(m, Vector3.new(2.2, 2.2, 0.35), cf * CFrame.new(0, 3.0, 1.0), color)
	L.part(m, Vector3.new(1.4, 0.4, 0.4), cf * CFrame.new(0, 0.9, 0) * CYL, L.C(150, 150, 160), { shape = Enum.PartType.Cylinder })
	L.part(m, Vector3.new(2.2, 0.3, 0.3), cf * CFrame.new(0, 0.15, 0), L.C(45, 45, 55))
	L.part(m, Vector3.new(0.3, 0.3, 2.2), cf * CFrame.new(0, 0.15, 0), L.C(45, 45, 55))
	return L.finish(m)
end

function L.plant(parent, cf, big)
	local m = L.model(parent, "Plant", true)
	local s = big and 1.5 or 1
	L.part(m, Vector3.new(1.6 * s, 1.8 * s, 1.8 * s), cf * CFrame.new(0, 0.8 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), L.C(200, 100, 60), { shape = Enum.PartType.Cylinder })
	L.part(m, Vector3.new(1.6 * s, 2.2 * s, 1.6 * s), cf * CFrame.new(0, 2.6 * s, 0), L.C(60, 180, 80))
	L.part(m, Vector3.new(1.0 * s, 1.4 * s, 1.0 * s), cf * CFrame.new(0.5 * s, 3.8 * s, 0.2 * s) * CFrame.Angles(0, 0.6, 0.3), L.C(90, 210, 100))
	L.part(m, Vector3.new(1.0 * s, 1.2 * s, 1.0 * s), cf * CFrame.new(-0.5 * s, 3.6 * s, -0.3 * s) * CFrame.Angles(0, -0.4, -0.3), L.C(50, 160, 70))
	return L.finish(m)
end

-- cloison vitrée cassable (longueur le long de X local)
function L.glassWall(parent, cf, length, height, frame)
	local m = L.model(parent, "GlassPartition", true)
	frame = frame or L.C(200, 205, 215)
	height = height or 10
	L.part(m, Vector3.new(length, 0.6, 0.6), cf * CFrame.new(0, 0.3, 0), frame)
	L.part(m, Vector3.new(length, 0.6, 0.6), cf * CFrame.new(0, height - 0.3, 0), frame)
	local g = L.part(m, Vector3.new(length, height - 1.2, 0.3), cf * CFrame.new(0, height / 2, 0), L.C(170, 215, 255), { transparency = 0.45, cast = false })
	g.Name = "Glass"
	return L.finish(m)
end

function L.pillar(parent, x, z, height, color, trim)
	L.part(parent, Vector3.new(4, height, 4), Vector3.new(x, height / 2, z), color, { name = "Pillar" })
	L.part(parent, Vector3.new(4.4, 1, 4.4), Vector3.new(x, 0.5, z), trim, { name = "PillarBase" })
	L.part(parent, Vector3.new(4.2, 0.8, 4.2), Vector3.new(x, 8, z), trim, { name = "PillarBand" })
end

-- table générique (dessus à 3)
function L.tableTop(parent, cf, w, d, top, leg)
	local m = L.model(parent, "Table", false)
	L.part(m, Vector3.new(w, 0.4, d), cf * CFrame.new(0, 2.8, 0), top)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			L.part(m, Vector3.new(0.4, 2.6, 0.4), cf * CFrame.new(sx * (w / 2 - 0.5), 1.3, sz * (d / 2 - 0.5)), leg)
		end
	end
	return L.finish(m)
end

function L.cabinet(parent, cf, color)
	local m = L.model(parent, "FileCabinet", false)
	L.part(m, Vector3.new(2.2, 4, 2.2), cf * CFrame.new(0, 2, 0), color or L.C(190, 195, 205))
	for i = 0, 2 do
		L.part(m, Vector3.new(1.9, 1.0, 0.1), cf * CFrame.new(0, 0.7 + i * 1.3, -1.12), L.C(160, 165, 175))
		L.part(m, Vector3.new(0.8, 0.15, 0.15), cf * CFrame.new(0, 0.9 + i * 1.3, -1.2), L.C(60, 60, 70))
	end
	return L.finish(m)
end

function L.photocopier(parent, cf, name)
	local m = L.model(parent, name or "Printer", false)
	L.part(m, Vector3.new(4, 3.2, 3), cf * CFrame.new(0, 1.6, 0), L.C(215, 215, 222))
	L.part(m, Vector3.new(4.1, 0.5, 3.1), cf * CFrame.new(0, 0.25, 0), L.C(80, 85, 100))
	L.part(m, Vector3.new(3.8, 0.3, 2.8), cf * CFrame.new(0, 3.35, 0), L.C(60, 65, 80))
	L.part(m, Vector3.new(0.8, 0.1, 0.45), cf * CFrame.new(1.0, 3.55, -1.1), L.C(80, 200, 255))
	L.part(m, Vector3.new(2.2, 0.15, 0.7), cf * CFrame.new(0, 2.2, -1.8), L.C(255, 255, 255))
	return L.finish(m)
end

-- Voiture en parts (déco). cf au sol, avant = -Z
function L.car(parent, cf, color, name)
	local m = L.model(parent, name or "Car", false)
	L.part(m, Vector3.new(6, 2.2, 12), cf * CFrame.new(0, 1.9, 0), color)
	L.part(m, Vector3.new(5.4, 2.0, 6), cf * CFrame.new(0, 4.0, 0.6), color)
	local w = L.part(m, Vector3.new(5.0, 1.6, 0.2), cf * CFrame.new(0, 4.0, -2.45), L.C(150, 210, 255), { transparency = 0.2 })
	w.Name = "Windshield"
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			L.part(m, Vector3.new(0.9, 2.2, 2.2), cf * CFrame.new(sx * 2.9, 1.1, sz * 3.8) * CYL, L.C(25, 25, 30), { shape = Enum.PartType.Cylinder })
		end
		L.part(m, Vector3.new(1.2, 0.6, 0.2), cf * CFrame.new(sx * 2, 2.2, -6.05), L.C(255, 250, 200))
		L.part(m, Vector3.new(1.2, 0.6, 0.2), cf * CFrame.new(sx * 2, 2.2, 6.05), L.C(230, 40, 40))
	end
	return L.finish(m)
end

---------------------------------------------------------------- outils ajoutés (Gym, Mailroom, MeetingRooms, CEOOffice)
-- Rampe (WedgePart) du point bas au point haut (Y des points ignoré), dessus qui monte jusqu'à height
function L.ramp(parent, low, high, width, height, color, name)
	local lo = Vector3.new(low.X, 0, low.Z)
	local hi = Vector3.new(high.X, 0, high.Z)
	local len = (hi - lo).Magnitude
	local mid = (lo + hi) / 2 + Vector3.new(0, height / 2, 0)
	-- le côté haut d'un WedgePart est en +Z local : on regarde vers le point bas
	local cf = CFrame.lookAt(mid, mid + (lo - hi))
	local w = Instance.new("WedgePart")
	w.Name = name or "Ramp"
	w.Size = Vector3.new(width, height, len)
	w.CFrame = cf
	w.Color = color
	w.Material = Enum.Material.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Anchored = true
	w.Parent = parent
	return w
end

-- Plateforme pleine : rectangle (x0,z0)-(x1,z1), dessus à height, liseré en haut
function L.platform(parent, x0, z0, x1, z1, height, color, trim, name)
	local sx, sz = math.abs(x1 - x0), math.abs(z1 - z0)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local p = L.part(parent, Vector3.new(sx, height, sz), Vector3.new(cx, height / 2, cz), color, { name = name or "Platform" })
	if trim then
		L.part(parent, Vector3.new(sx + 0.4, 0.6, sz + 0.4), Vector3.new(cx, height - 0.29, cz), trim, { name = "PlatformTrim" })
	end
	return p
end

-- Garde-corps simple de a à b (Vector3 au sol), posé à y
function L.railing(parent, a, b, y, color, h)
	h = h or 3
	local r = L.wall(parent, a, b, 0.5, 0.5, color, y + h - 0.5)
	r.Name = "Railing"
	local dir = (b - a)
	local len = dir.Magnitude
	local n = math.max(1, math.floor(len / 8))
	for i = 0, n do
		local p = a + dir * (i / n)
		L.part(parent, Vector3.new(0.4, h, 0.4), Vector3.new(p.X, y + h / 2, p.Z), color, { name = "RailPost" })
	end
	return r
end

-- Tapis / bande au sol (épaisseur 0.1, au-dessus de la surface y)
function L.rug(parent, cf, sx, sz, color, name, y)
	return L.part(parent, Vector3.new(sx, 0.1, sz), cf * CFrame.new(0, (y or 0) + 0.05, 0), color, { name = name or "Rug", cast = false })
end

-- Carton (avec bande de scotch). breakable => Model tagué Breakable
function L.crate(parent, cf, size, color, breakable, tape)
	local m = L.model(parent, "Crate", breakable)
	if breakable then m:SetAttribute("Material", "Wood") end
	color = color or L.C(196, 150, 95)
	L.part(m, size, cf * CFrame.new(0, size.Y / 2, 0), color)
	L.part(m, Vector3.new(size.X + 0.05, 0.06, size.Z * 0.28), cf * CFrame.new(0, size.Y + 0.03, 0), tape or L.C(240, 200, 80), { cast = false })
	return L.finish(m)
end

-- Pile de cartons cassable (levels étages)
function L.crateStack(parent, cf, levels, s)
	local m = L.model(parent, "BoxStack", true)
	m:SetAttribute("Material", "Wood")
	s = s or 3
	local y = 0
	local cols = { L.C(196, 150, 95), L.C(180, 132, 80), L.C(210, 168, 110) }
	for i = 1, levels do
		local sz = s * (1 - (i - 1) * 0.12)
		local c = cf * CFrame.new((i % 2) * 0.3, 0, 0) * CFrame.Angles(0, (i - 1) * 0.25, 0)
		L.part(m, Vector3.new(sz, sz * 0.8, sz), c * CFrame.new(0, y + sz * 0.4, 0), cols[(i - 1) % 3 + 1])
		L.part(m, Vector3.new(sz + 0.05, 0.06, sz * 0.28), c * CFrame.new(0, y + sz * 0.8 + 0.03, 0), L.C(240, 200, 80), { cast = false })
		y += sz * 0.8
	end
	return L.finish(m)
end

-- Canapé (avant = -Z local), largeur w
function L.sofa(parent, cf, w, color, name, breakable)
	local m = L.model(parent, name or "Sofa", breakable)
	if breakable then m:SetAttribute("Material", "Wood") end
	L.part(m, Vector3.new(w, 1.6, 3.2), cf * CFrame.new(0, 0.8, 0), color)
	L.part(m, Vector3.new(w, 2.4, 0.9), cf * CFrame.new(0, 2.0, 1.15), color)
	L.part(m, Vector3.new(0.9, 1.0, 2.3), cf * CFrame.new(-w / 2 + 0.45, 2.1, -0.45), color)
	L.part(m, Vector3.new(0.9, 1.0, 2.3), cf * CFrame.new(w / 2 - 0.45, 2.1, -0.45), color)
	return L.finish(m)
end

-- Tableau blanc sur pied (avant = -Z local)
function L.whiteboard(parent, cf, w, frame, breakable)
	local m = L.model(parent, "Whiteboard", breakable)
	w = w or 8
	frame = frame or L.C(170, 175, 185)
	L.part(m, Vector3.new(w, 4.4, 0.3), cf * CFrame.new(0, 5.2, 0), frame)
	L.part(m, Vector3.new(w - 0.6, 3.8, 0.1), cf * CFrame.new(0, 5.2, -0.2), L.C(250, 250, 252))
	L.part(m, Vector3.new(w * 0.5, 0.25, 0.1), cf * CFrame.new(-w * 0.12, 6.2, -0.28), L.C(60, 140, 230), { cast = false })
	L.part(m, Vector3.new(w * 0.35, 0.25, 0.1), cf * CFrame.new(w * 0.05, 5.4, -0.28), L.C(230, 70, 60), { cast = false })
	L.part(m, Vector3.new(0.3, 3, 0.3), cf * CFrame.new(-w / 2 + 0.3, 1.5, 0), frame)
	L.part(m, Vector3.new(0.3, 3, 0.3), cf * CFrame.new(w / 2 - 0.3, 1.5, 0), frame)
	L.part(m, Vector3.new(w, 0.3, 1.6), cf * CFrame.new(0, 0.15, 0), frame)
	return L.finish(m)
end

-- Chaise simple (3 parts), avant = -Z local
function L.simpleChair(parent, cf, color, breakable)
	local m = L.model(parent, "DecoChair", breakable)
	L.part(m, Vector3.new(2.2, 0.5, 2.2), cf * CFrame.new(0, 1.85, 0), color)
	L.part(m, Vector3.new(2.2, 2.2, 0.4), cf * CFrame.new(0, 3.2, 0.95), color)
	L.part(m, Vector3.new(0.5, 1.6, 0.5), cf * CFrame.new(0, 0.8, 0), L.C(60, 60, 70))
	return L.finish(m)
end

-- Fontaine à eau cassable
function L.waterCooler(parent, cf)
	local m = L.model(parent, "WaterCooler", true)
	m:SetAttribute("Material", "Plastic")
	L.part(m, Vector3.new(2, 3.6, 2), cf * CFrame.new(0, 1.8, 0), L.C(240, 240, 245))
	L.part(m, Vector3.new(1.8, 1.8, 1.8), cf * CFrame.new(0, 4.5, 0), L.C(120, 190, 255), { shape = Enum.PartType.Ball, transparency = 0.25 })
	L.part(m, Vector3.new(0.5, 0.3, 0.3), cf * CFrame.new(0, 2.6, -1.1), L.C(60, 140, 230))
	return L.finish(m)
end

-- Table de réunion « MeetingTable » (utilisée par SurpriseMeeting) + chaises autour + marqueur
function L.meetingTable(floor, cf, w, d, top, leg, chair)
	local m = L.model(floor.Decor, "MeetingTable", false)
	L.part(m, Vector3.new(w, 0.5, d), cf * CFrame.new(0, 2.85, 0), top)
	L.part(m, Vector3.new(1.2, 2.6, d * 0.6), cf * CFrame.new(-w / 2 + 2, 1.3, 0), leg)
	L.part(m, Vector3.new(1.2, 2.6, d * 0.6), cf * CFrame.new(w / 2 - 2, 1.3, 0), leg)
	L.finish(m)
	local n = math.max(1, math.floor(w / 5))
	for i = 1, n do
		local x = -w / 2 + (i - 0.5) * (w / n)
		L.simpleChair(floor.Decor, cf * CFrame.new(x, 0, -d / 2 - 1.6) * CFrame.Angles(0, math.pi, 0), chair, false)
		L.simpleChair(floor.Decor, cf * CFrame.new(x, 0, d / 2 + 1.6), chair, false)
	end
	local p = cf.Position
	L.event(floor, "MeetingTable", p.X, 3.5, p.Z)
	return m
end

-- Casier (vestiaire), avant = -Z local
function L.locker(parent, cf, color, h)
	h = h or 7
	local m = L.model(parent, "Locker", false)
	L.part(m, Vector3.new(2.4, h, 2.2), cf * CFrame.new(0, h / 2, 0), color)
	L.part(m, Vector3.new(1.6, 0.25, 0.08), cf * CFrame.new(0, h - 1.2, -1.14), L.C(40, 40, 50), { cast = false })
	L.part(m, Vector3.new(0.2, 0.9, 0.12), cf * CFrame.new(0.75, h / 2, -1.16), L.C(200, 200, 210), { cast = false })
	return L.finish(m)
end

-- Étagère (rayonnage) longueur w (X local), profondeur d, hauteur h, niveaux -> (model, {y des dessus})
function L.rack(parent, cf, w, d, h, levels, upright, beam, name)
	local m = L.model(parent, name or "Rack", false)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			L.part(m, Vector3.new(0.5, h, 0.5), cf * CFrame.new(sx * (w / 2 - 0.25), h / 2, sz * (d / 2 - 0.25)), upright)
		end
	end
	local tops = {}
	for i = 1, levels do
		local y = (i == 1) and 0.6 or (0.6 + (h - 1.0) * (i - 1) / math.max(1, levels - 1))
		L.part(m, Vector3.new(w - 1, 0.3, d - 0.1), cf * CFrame.new(0, y, 0), beam)
		table.insert(tops, y + 0.15)
	end
	L.finish(m)
	return m, tops
end

---------------------------------------------------------------- outils ajoutés (Lobby, Rooftop, Archives, GameRoom, Daycare, Auditorium, Warehouse, Spa)
L.BALL = Enum.PartType.Ball
L.CYLINDER = Enum.PartType.Cylinder

-- Cylindre VERTICAL de diamètre d et hauteur h, posé sur cf (base à cf.Y)
function L.cyl(parent, cf, d, h, color, opts)
	opts = opts or {}
	opts.shape = Enum.PartType.Cylinder
	cf = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	return L.part(parent, Vector3.new(h, d, d), cf * CFrame.new(0, h / 2, 0) * CYL, color, opts)
end

-- Boule de diamètre d centrée sur pos
function L.ball(parent, pos, d, color, opts)
	opts = opts or {}
	opts.shape = Enum.PartType.Ball
	return L.part(parent, Vector3.new(d, d, d), pos, color, opts)
end

-- Clôture de sécurité HAUTE sur les 4 bords (toit) : poteaux, grillage semi-transparent, lisses
function L.safetyFence(floor, height, post, panel, rail)
	local h = L.HALF
	local sides = {
		{ Vector3.new(-h, 0, -h - 0.5), Vector3.new(h, 0, -h - 0.5) },
		{ Vector3.new(-h, 0, h + 0.5), Vector3.new(h, 0, h + 0.5) },
		{ Vector3.new(-h - 0.5, 0, -h - 1), Vector3.new(-h - 0.5, 0, h + 1) },
		{ Vector3.new(h + 0.5, 0, -h - 1), Vector3.new(h + 0.5, 0, h + 1) },
	}
	for _, ab in ipairs(sides) do
		local a, b = ab[1], ab[2]
		local mesh = L.wall(floor.Structure, a, b, height, 0.4, panel, 0)
		mesh.Name = "FenceMesh"; mesh.Transparency = 0.55; mesh.CastShadow = false
		L.wall(floor.Structure, a, b, 2.5, 1.2, post, 0).Name = "FenceCurb"
		for _, y in ipairs({ height * 0.5, height - 0.6 }) do
			L.wall(floor.Structure, a, b, 0.6, 0.8, rail, y).Name = "FenceRail"
		end
		local dir = (b - a).Unit
		local len = (b - a).Magnitude
		for d = 0, len, 20 do
			local p = a + dir * d
			L.part(floor.Structure, Vector3.new(1, height + 1, 1), Vector3.new(p.X, (height + 1) / 2, p.Z), post, { name = "FencePost" })
		end
	end
end

-- Échelle grimpable (montants + barreaux tous les 1,2 stud), avant = -Z local
function L.ladder(parent, cf, h, color)
	local m = L.model(parent, "Ladder", false)
	for _, sx in ipairs({ -1, 1 }) do
		L.part(m, Vector3.new(0.35, h, 0.35), cf * CFrame.new(sx * 1.1, h / 2, 0), color)
	end
	for y = 0.8, h - 0.3, 1.2 do
		L.part(m, Vector3.new(2.2, 0.25, 0.3), cf * CFrame.new(0, y, 0), color)
	end
	return L.finish(m)
end

-- Lampe : ampoule néon + PointLight (lumière chaude par défaut)
function L.lamp(parent, pos, color, range, brightness, size)
	color = color or L.C(255, 210, 140)
	local b = L.part(parent, size or Vector3.new(1.2, 1.2, 1.2), pos, color, { name = "Lamp", material = Enum.Material.Neon, cast = false, shape = Enum.PartType.Ball })
	local l = Instance.new("PointLight")
	l.Color = color; l.Range = range or 18; l.Brightness = brightness or 1.2; l.Shadows = false
	l.Parent = b
	return b
end

-- Couloir d'événement : paire de marqueurs <prefix>Start / <prefix>End avec attribut Lane
function L.lane(floor, prefix, a, b, lane)
	L.event(floor, prefix .. "Start", a.X, 0, a.Z, { Lane = lane })
	L.event(floor, prefix .. "End", b.X, 0, b.Z, { Lane = lane })
end

-- Zone taguée invisible (SlipZone, SlowZone...) : boîte posée au sol
function L.zone(parent, tag, cf, size, attrs, visibleColor)
	local p = L.part(parent, size, cf * CFrame.new(0, size.Y / 2, 0), visibleColor or L.C(255, 255, 255), {
		name = tag, transparency = visibleColor and 0.5 or 1, collide = false, cast = false,
	})
	p.CanQuery = true
	p.CanTouch = true
	CS:AddTag(p, tag)
	for k, v in pairs(attrs or {}) do p:SetAttribute(k, v) end
	return p
end

-- Distributeur (vending machine) cassable, avant = -Z local
function L.vending(parent, cf, color)
	local m = L.model(parent, "Vending", true)
	m:SetAttribute("Material", "Metal")
	L.part(m, Vector3.new(4, 7, 3), cf * CFrame.new(0, 3.5, 0), color)
	local g = L.part(m, Vector3.new(2.6, 4.6, 0.2), cf * CFrame.new(-0.5, 4.2, -1.5), L.C(150, 220, 255), { transparency = 0.25 })
	g.Name = "VendingGlass"
	for i = 0, 3 do
		L.part(m, Vector3.new(2.4, 0.5, 0.3), cf * CFrame.new(-0.5, 2.6 + i * 1.1, -1.25), ({ L.C(255, 80, 80), L.C(255, 210, 60), L.C(80, 200, 120), L.C(80, 150, 255) })[i + 1])
	end
	L.part(m, Vector3.new(0.8, 2.4, 0.2), cf * CFrame.new(1.45, 4.4, -1.55), L.C(50, 50, 60))
	L.part(m, Vector3.new(2.6, 0.8, 0.2), cf * CFrame.new(-0.5, 1.0, -1.55), L.C(40, 40, 50))
	return L.finish(m)
end

-- Pouf (bean bag) cassable
function L.beanBag(parent, cf, color)
	local m = L.model(parent, "BeanBag", true)
	m:SetAttribute("Material", "Rubber")
	L.part(m, Vector3.new(4, 2.4, 4), cf * CFrame.new(0, 1.1, 0), color, { shape = Enum.PartType.Ball })
	L.part(m, Vector3.new(3.2, 2.6, 1.6), cf * CFrame.new(0, 2.0, 1.2), color, { shape = Enum.PartType.Ball })
	return L.finish(m)
end

-- Palette de bois (déco), dessus à 0.6
function L.pallet(parent, cf, color)
	color = color or L.C(190, 145, 90)
	local m = L.model(parent, "Pallet", false)
	for i = -1, 1 do
		L.part(m, Vector3.new(4, 0.3, 0.6), cf * CFrame.new(0, 0.15, i * 1.6), color)
		L.part(m, Vector3.new(0.6, 0.3, 4), cf * CFrame.new(i * 1.6, 0.45, 0), color)
	end
	return L.finish(m)
end

---------------------------------------------------------------- outils ajoutés (2) : helpers génériques des 8 nouveaux étages
-- Model cassable + matériau d'impact (Wood, Metal, Plastic, Ceramic, Glass, Rubber)
function L.breakable(parent, name, material)
	local m = L.model(parent, name, true)
	m:SetAttribute("Material", material or "Wood")
	return m
end

-- Liste de points d'apparition joueurs {{x,z},...}
function L.spawns(floor, list)
	for _, p in ipairs(list) do
		L.playerSpawn(floor, p[1], p[2])
	end
end

-- Marqueur d'événement orienté (LookVector = direction utile, ex. canon)
function L.eventCF(floor, name, cf, attrs)
	local p = L.event(floor, name, cf.Position.X, cf.Position.Y, cf.Position.Z, attrs)
	p.CFrame = cf
	return p
end

-- Finalise : pivot du Model à l'origine (FloorService fait PivotTo(0, y, 0)) ; renvoie le nombre de parts
function L.done(floor)
	floor.WorldPivot = CFrame.new()
	local n = 0
	for _, d in ipairs(floor:GetDescendants()) do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end

-- Escalier plein de a (bas) vers b (haut) : marches de profondeur step, largeur w, jusqu'à height
function L.stairs(parent, a, b, w, height, color, steps)
	steps = steps or math.max(2, math.floor(height / 1.2))
	local lo = Vector3.new(a.X, 0, a.Z)
	local hi = Vector3.new(b.X, 0, b.Z)
	local dir = (hi - lo)
	local len = dir.Magnitude
	local unit = dir.Unit
	for i = 1, steps do
		local h = height * i / steps
		local d0 = len * (i - 1) / steps
		local p = lo + unit * (d0 + (len - d0) / 2)
		L.part(parent, Vector3.new(w, h, len - d0), CFrame.lookAt(Vector3.new(p.X, h / 2, p.Z), Vector3.new(p.X, h / 2, p.Z) + unit), color, { name = "Step" })
	end
end

-- Cube de jouet géant (deux faces décorées)
function L.toyBlock(parent, cf, s, color, face, breakable)
	local m = breakable and L.breakable(parent, "ToyBlock", "Wood") or L.model(parent, "ToyBlock", false)
	L.part(m, Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), color)
	L.part(m, Vector3.new(s * 0.6, s * 0.6, 0.2), cf * CFrame.new(0, s / 2, -s / 2 - 0.08), face, { cast = false })
	L.part(m, Vector3.new(0.2, s * 0.6, s * 0.6), cf * CFrame.new(s / 2 + 0.08, s / 2, 0), face, { cast = false })
	return L.finish(m)
end

-- Nounours assis (s = échelle), avant = -Z local
function L.teddy(parent, cf, s, color, breakable)
	s = s or 1
	color = color or L.C(190, 130, 80)
	local m = breakable == false and L.model(parent, "Teddy", false) or L.breakable(parent, "Teddy", "Rubber")
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.25)
	local function b(d, x, y, z, c)
		L.part(m, Vector3.new(d, d, d) * s, cf * CFrame.new(x * s, y * s, z * s), c or color, { shape = Enum.PartType.Ball })
	end
	b(3.2, 0, 1.6, 0)
	b(2.4, 0, 3.8, 0)
	b(0.9, -0.95, 4.8, 0, dark)
	b(0.9, 0.95, 4.8, 0, dark)
	b(1.0, 0, 3.55, -1.05, L.C(245, 225, 195))
	b(0.35, -0.45, 4.15, -1.0, L.C(25, 25, 30))
	b(0.35, 0.45, 4.15, -1.0, L.C(25, 25, 30))
	b(1.2, -0.95, 0.6, -1.0)
	b(1.2, 0.95, 0.6, -1.0)
	return L.finish(m)
end

-- Borne d'arcade cassable (écran = "Screen", s'allume pendant la panne), avant = -Z local
function L.arcade(parent, cf, body, screen)
	local m = L.breakable(parent, "Arcade", "Metal")
	L.part(m, Vector3.new(4, 7.5, 3.6), cf * CFrame.new(0, 3.75, 0.2), body)
	local s = L.part(m, Vector3.new(3.2, 2.6, 0.2), cf * CFrame.new(0, 5.3, -1.62) * CFrame.Angles(math.rad(-12), 0, 0), screen, { material = Enum.Material.Neon })
	s.Name = "Screen"
	L.part(m, Vector3.new(4.1, 1.1, 1.0), cf * CFrame.new(0, 7.0, -1.3), screen:Lerp(Color3.new(1, 1, 1), 0.35), { material = Enum.Material.Neon })
	L.part(m, Vector3.new(4, 0.5, 1.6), cf * CFrame.new(0, 3.6, -2.1) * CFrame.Angles(math.rad(10), 0, 0), L.C(40, 40, 50))
	L.part(m, Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(-0.8, 3.95, -2.25), L.C(255, 60, 60), { shape = Enum.PartType.Ball })
	L.part(m, Vector3.new(0.5, 0.5, 0.5), cf * CFrame.new(0.6, 3.95, -2.25), L.C(60, 200, 255), { shape = Enum.PartType.Ball })
	return L.finish(m)
end

-- Chariot élévateur (déco, non cassable), avant (fourches) = -Z local
function L.forklift(parent, cf, body)
	local m = L.model(parent, "Forklift", false)
	body = body or L.C(250, 190, 30)
	local dark, steel = L.C(40, 40, 45), L.C(70, 70, 78)
	L.part(m, Vector3.new(5, 3, 7), cf * CFrame.new(0, 2.2, 0.5), body)
	L.part(m, Vector3.new(4.6, 2.4, 2.2), cf * CFrame.new(0, 2.8, 3.6), L.C(60, 60, 70))
	L.part(m, Vector3.new(2.6, 0.7, 2.4), cf * CFrame.new(0, 4.05, 1.2), dark)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			L.part(m, Vector3.new(0.35, 4.6, 0.35), cf * CFrame.new(sx * 2.2, 6.0, 1.0 + sz * 1.9), dark)
		end
		L.part(m, Vector3.new(0.5, 9, 0.5), cf * CFrame.new(sx * 1.4, 4.8, -3.2), steel)
		L.part(m, Vector3.new(0.5, 0.3, 4), cf * CFrame.new(sx * 1.0, 0.5, -5.1), steel)
		L.part(m, Vector3.new(0.9, 2.2, 2.2), cf * CFrame.new(sx * 2.6, 1.1, -1.8) * CYL, L.C(25, 25, 30), { shape = Enum.PartType.Cylinder })
		L.part(m, Vector3.new(0.9, 1.8, 1.8), cf * CFrame.new(sx * 2.5, 0.9, 3.4) * CYL, L.C(25, 25, 30), { shape = Enum.PartType.Cylinder })
	end
	L.part(m, Vector3.new(4.8, 0.3, 4.4), cf * CFrame.new(0, 8.4, 1.0), body)
	L.part(m, Vector3.new(3.4, 2.2, 0.4), cf * CFrame.new(0, 1.6, -3.5), steel)
	L.part(m, Vector3.new(0.8, 0.6, 0.8), cf * CFrame.new(0, 8.85, 1.0), L.C(255, 150, 30), { material = Enum.Material.Neon, name = "Beacon" })
	return L.finish(m)
end

-- Tige de bambou (cylindre vertical + bagues + touffe)
function L.bamboo(parent, x, z, h, color)
	color = color or L.C(120, 190, 80)
	L.cyl(parent, CFrame.new(x, 0, z), 1, h, color, { name = "Bamboo" })
	L.part(parent, Vector3.new(2.6, 2.6, 2.6), Vector3.new(x + 0.6, h, z), L.C(90, 170, 70), { shape = Enum.PartType.Ball, name = "BambooLeaves", collide = false })
end

return L
