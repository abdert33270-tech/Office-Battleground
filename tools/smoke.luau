--[[
	smoke.luau — test de fumée hors Studio : construit l'arbre d'instances depuis src/ (dossiers + .luau),
	simule les API Roblox de façon permissive, puis require() chaque ModuleScript visé.
	Attrape les erreurs d'exécution au chargement (nil appelé, champ manquant, require cassé, syntaxe).
	Usage : tools/luaurun tools/smoke.luau <racine src> <IsServer:true|false> [filtre de chemin...]
]]
local ROOT, SIDE = ARGV[1], ARGV[2] == "true"
local FILTERS = {}
for i = 3, #ARGV do table.insert(FILTERS, ARGV[i]) end

-- ===== Mock permissif =====
local Mock
local mockMT = {}
local function newMock(name) return setmetatable({ __name = name or "Mock" }, mockMT) end
Mock = newMock
mockMT.__index = function(t, k)
	if k == "Connect" or k == "Once" then return function() return newMock("Connection") end end
	if k == "Wait" then return function() return nil end end
	local m = newMock(tostring(rawget(t, "__name")) .. "." .. tostring(k))
	rawset(t, k, m)
	return m
end
mockMT.__call = function() return newMock("ret") end
for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__mod", "__pow", "__unm", "__idiv" }) do
	mockMT[op] = function() return newMock("arith") end
end
mockMT.__lt = function() return false end
mockMT.__le = function() return false end
mockMT.__concat = function(a, b) return tostring(a) .. tostring(b) end
mockMT.__tostring = function(t) return "Mock(" .. tostring(rawget(t, "__name")) .. ")" end
mockMT.__len = function() return 0 end

-- ===== Types de valeur simplifiés =====
local function vtype(tname, fields)
	local mt = {}
	mt.__index = function(t, k)
		if k == "Magnitude" then return 1 end
		if k == "Unit" then return t end
		local f = rawget(fields, k)
		if f ~= nil then return f end
		return newMock(tname .. "." .. tostring(k))
	end
	for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__unm", "__idiv", "__mod" }) do
		mt[op] = function(a) return type(a) == "table" and getmetatable(a) == mt and a or newMock("arith") end
	end
	mt.__eq = function(a, b) return rawequal(a, b) end
	mt.__tostring = function() return tname end
	local lib = setmetatable({}, { __index = function(_, k)
		return function(...) return setmetatable({ __args = { ... } }, mt) end
	end })
	return lib
end
Vector3 = vtype("Vector3", {}); Vector3.zero = Vector3.new(0, 0, 0); Vector3.one = Vector3.new(1, 1, 1)
rawset(Vector3, "xAxis", Vector3.new()); rawset(Vector3, "yAxis", Vector3.new()); rawset(Vector3, "zAxis", Vector3.new())
Vector2 = vtype("Vector2", {}); rawset(Vector2, "zero", Vector2.new())
CFrame = vtype("CFrame", {}); rawset(CFrame, "identity", CFrame.new())
Color3 = vtype("Color3", {}); UDim2 = vtype("UDim2", {}); UDim = vtype("UDim", {})
NumberSequence = vtype("NumberSequence", {}); ColorSequence = vtype("ColorSequence", {})
NumberSequenceKeypoint = vtype("NSK", {}); ColorSequenceKeypoint = vtype("CSK", {})
NumberRange = vtype("NumberRange", {}); TweenInfo = vtype("TweenInfo", {}); Rect = vtype("Rect", {})
Region3 = vtype("Region3", {}); Ray = vtype("Ray", {}); BrickColor = vtype("BrickColor", {})
PhysicalProperties = vtype("PhysicalProperties", {}); Font = vtype("Font", {}); DateTime = vtype("DateTime", {})
RaycastParams = vtype("RaycastParams", {}); OverlapParams = vtype("OverlapParams", {})
Random = vtype("Random", {}); Faces = vtype("Faces", {}); Axes = vtype("Axes", {})
Enum = newMock("Enum")
task = { wait = function() return 0 end, spawn = function() end, defer = function() end, delay = function() end,
	cancel = function() end, synchronize = function() end, desynchronize = function() end }
wait = task.wait; spawn = task.spawn; delay = task.delay
tick = os.clock; time = os.clock; elapsedTime = os.clock
warn = function(...) WARNS = (WARNS or 0) + 1; print("  [warn]", ...) end
typeof = function(v)
	if type(v) == "table" then
		local mt = getmetatable(v)
		if mt == mockMT then return "Instance" end
		if mt and mt.__tostring then local ok, s = pcall(tostring, v) if ok then return s end end
	end
	return type(v)
end
settings = function() return newMock("settings") end
UserSettings = settings

-- ===== Arbre d'instances depuis src/ =====
local Inst = {}
Inst.__index = function(t, k)
	if k == "Parent" then return rawget(t, "_parent") end
	local m = rawget(Inst, k)
	if m then return m end
	local kids = rawget(t, "_children")
	if kids then for _, c in ipairs(kids) do if c.Name == k then return c end end end
	local props = rawget(t, "_props")
	if props[k] ~= nil then return props[k] end
	local v = newMock(t.Name .. "." .. tostring(k))
	props[k] = v
	return v
end
Inst.__newindex = function(t, k, v)
	if k == "Parent" then
		local old = rawget(t, "_parent")
		if old then for i, c in ipairs(old._children) do if c == t then table.remove(old._children, i) break end end end
		rawset(t, "_parent", v)
		if type(v) == "table" and getmetatable(v) == Inst then table.insert(v._children, t) end
		return
	end
	rawget(t, "_props")[k] = v
end
Inst.__tostring = function(t) return t.Name end
local function makeInst(class, name)
	local o = setmetatable({ _children = {}, _props = {}, _attrs = {} }, Inst)
	rawset(o, "ClassName", class); rawset(o, "Name", name or class)
	return o
end
function Inst:GetChildren() local r = {} for i, c in ipairs(self._children) do r[i] = c end return r end
function Inst:GetDescendants()
	local r = {}
	local function walk(n) for _, c in ipairs(n._children) do table.insert(r, c) walk(c) end end
	walk(self) return r
end
function Inst:FindFirstChild(n, rec)
	for _, c in ipairs(self._children) do if c.Name == n then return c end end
	if rec then for _, c in ipairs(self._children) do local f = c:FindFirstChild(n, true) if f then return f end end end
	return nil
end
function Inst:WaitForChild(n) local c = self:FindFirstChild(n) if not c then MISSING_WAIT = (MISSING_WAIT or {}) MISSING_WAIT[#MISSING_WAIT + 1] = self.Name .. "." .. n return makeInst("Folder", n) end return c end
function Inst:FindFirstChildOfClass(c) for _, x in ipairs(self._children) do if x.ClassName == c then return x end end return nil end
function Inst:FindFirstChildWhichIsA(c) return self:FindFirstChildOfClass(c) end
function Inst:FindFirstAncestor(n) local p = rawget(self, "_parent") while p do if p.Name == n then return p end p = rawget(p, "_parent") end return nil end
function Inst:IsA(c) return self.ClassName == c or (c == "LuaSourceContainer" and (self.ClassName == "ModuleScript")) or c == "Instance" end
function Inst:IsDescendantOf(a) local p = rawget(self, "_parent") while p do if p == a then return true end p = rawget(p, "_parent") end return false end
function Inst:GetAttribute(k) return self._attrs[k] end
function Inst:SetAttribute(k, v) self._attrs[k] = v end
function Inst:GetAttributes() return self._attrs end
function Inst:GetFullName() local s, p = self.Name, rawget(self, "_parent") while p do s = p.Name .. "." .. s p = rawget(p, "_parent") end return s end
function Inst:Clone() return makeInst(self.ClassName, self.Name) end
function Inst:Destroy() self.Parent = nil end
function Inst:ClearAllChildren() self._children = {} end
-- tout le reste (méthodes de service, signaux...) : mock
setmetatable(Inst, { __index = function(_, k) return function() return newMock(k) end end })

local game = makeInst("DataModel", "game")
_G_GAME = game
local services = {}
function Inst:GetService(n)
	if self ~= game then return newMock(n) end
	if not services[n] then
		local s = self:FindFirstChild(n) or makeInst(n, n)
		if not rawget(s, "_parent") then s.Parent = game end
		services[n] = s
	end
	return services[n]
end
local run = game:GetService("RunService")
rawset(run, "IsServer", function() return SIDE end)
rawset(run, "IsClient", function() return not SIDE end)
rawset(run, "IsStudio", function() return true end)
local players = game:GetService("Players")
if not SIDE then
	local lp = makeInst("Player", "LocalPlayer")
	lp._props.UserId = 1
	lp.Parent = players
	rawget(players, "_props").LocalPlayer = lp
	lp:FindFirstChild("PlayerGui")
	local pg = makeInst("PlayerGui", "PlayerGui"); pg.Parent = lp
	local ps = makeInst("PlayerScripts", "PlayerScripts"); ps.Parent = lp
end
rawset(players, "GetPlayers", function() return {} end)
local http = game:GetService("HttpService")
rawset(http, "JSONEncode", function() return "{}" end)
rawset(http, "JSONDecode", function() return {} end)
rawset(http, "GenerateGUID", function() return "guid" end)
workspace = game:GetService("Workspace")
rawset(workspace, "_props", rawget(workspace, "_props")); workspace._props.CurrentCamera = makeInst("Camera", "Camera")

Instance = { new = function(class, parent) local o = makeInst(class, class) if parent then o.Parent = parent end return o end,
	fromExisting = function(o) return makeInst(o.ClassName, o.Name) end }

-- ===== Chargement de src/ =====
local SOURCES = {}
local function strip(n) return (n:gsub("%.server%.luau$", ""):gsub("%.client%.luau$", ""):gsub("%.luau$", ""):gsub("%.lua$", "")) end
local function load(dir, parent, rel)
	for _, name in ipairs(listdir(dir)) do
		local p = dir .. "/" .. name
		if isdir(p) then
			local init = readfile(p .. "/init.luau")
			local node
			if init then node = makeInst("ModuleScript", name); SOURCES[node] = { init, rel .. "/" .. name .. "/init.luau" }
			else node = makeInst("Folder", name) end
			node.Parent = parent
			load(p, node, rel .. "/" .. name)
		elseif name:match("%.luau$") and name ~= "init.luau" then
			local class = name:match("%.server%.luau$") and "Script" or name:match("%.client%.luau$") and "LocalScript" or "ModuleScript"
			local node = makeInst(class, strip(name))
			node.Parent = parent
			SOURCES[node] = { readfile(p), rel .. "/" .. name }
		end
	end
end
for _, svc in ipairs(listdir(ROOT)) do
	if isdir(ROOT .. "/" .. svc) then
		local s = game:FindFirstChild(svc) or makeInst(svc, svc)
		s.Parent = game
		services[svc] = s
		if svc == "StarterPlayer" then
			for _, sub in ipairs(listdir(ROOT .. "/StarterPlayer")) do
				local n = makeInst(sub, sub); n.Parent = s
				load(ROOT .. "/StarterPlayer/" .. sub, n, svc .. "/" .. sub)
			end
		else
			load(ROOT .. "/" .. svc, s, svc)
		end
	end
end
-- client : PlayerScripts = copie de StarterPlayerScripts (même objets)
if not SIDE then
	local lp = players.LocalPlayer
	local sps = game.StarterPlayer.StarterPlayerScripts
	rawset(lp, "_children", { lp.PlayerGui, sps })
	rawset(sps, "Name", "PlayerScripts")
end

local cache, loading = {}, {}
local realRequire = require
local function envFor(scriptInst)
	local env = setmetatable({ script = scriptInst, game = game, workspace = workspace }, { __index = _G })
	env.require = function(m)
		if type(m) ~= "table" or getmetatable(m) ~= Inst then return newMock("require") end
		if cache[m] ~= nil then return cache[m] end
		if loading[m] then error("cyclic require of " .. m:GetFullName()) end
		local src = SOURCES[m]
		if not src then error("require: pas de source pour " .. m:GetFullName()) end
		loading[m] = true
		local fn, err = loadsrc(src[1], src[2])
		if not fn then error("syntax: " .. tostring(err)) end
		setfenv(fn, envFor(m))
		local ok, res = pcall(fn)
		loading[m] = nil
		if not ok then error(src[2] .. ": " .. tostring(res), 0) end
		cache[m] = res
		return res
	end
	return env
end
setfenv(1, setmetatable({}, { __index = _G }))

local fails, okc = 0, 0
local list = {}
for node, src in pairs(SOURCES) do table.insert(list, { node, src }) end
table.sort(list, function(a, b) return a[2][2] < b[2][2] end)
for _, e in ipairs(list) do
	local node, path = e[1], e[2][2]
	local want = #FILTERS == 0
	for _, f in ipairs(FILTERS) do if path:find(f, 1, true) then want = true end end
	if want and node.ClassName == "ModuleScript" then
		local env = envFor(node)
		local ok, err = pcall(env.require, node)
		if ok then okc += 1 else fails += 1 print("FAIL " .. path .. "\n     " .. tostring(err)) end
	end
end
print(string.format("smoke(%s): %d ok, %d fail", SIDE and "server" or "client", okc, fails))
if fails > 0 then error("smoke failures: " .. fails, 0) end
