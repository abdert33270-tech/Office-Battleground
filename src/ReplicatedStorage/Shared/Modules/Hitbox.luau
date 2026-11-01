--[[
	Hitbox — requêtes spatiales partagées.
	Côté client : prédiction des effets (réactivité).
	Côté serveur : seule source de vérité pour les dégâts.
	COMPENSATION DE LATENCE (serveur) : Hitbox.startHistory() enregistre ~20 fois/s la CFrame du HumanoidRootPart de
	chaque personnage (anneau de ~1 s) ; Hitbox.rootAt(c, t) la relit (interpolée) ; Hitbox.box(..., rewind) teste
	AUSSI la position des victimes `rewind` secondes plus tôt (ce que l'attaquant voyait à l'écran).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Hitbox = {}

-- Tous les personnages vivants (joueurs + mannequins)
function Hitbox.characters(): { Model }
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		if c then
			local h = c:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 then
				table.insert(list, c)
			end
		end
	end
	local dummies = workspace:FindFirstChild("Dummies")
	if dummies then
		for _, d in ipairs(dummies:GetChildren()) do
			local h = d:FindFirstChildOfClass("Humanoid")
			if h and h.Health > 0 then
				table.insert(list, d)
			end
		end
	end
	return list
end

------------------------------------------------------------------------
-- Historique des positions (compensation de latence, serveur uniquement)
------------------------------------------------------------------------
local HISTORY_LEN, HISTORY_STEP = 22, 0.05 -- 22 échantillons à 20 Hz ≈ 1,1 s
local history = setmetatable({}, { __mode = "k" }) -- [character] = { i = dernier index, t = {}, cf = {} }
local historyConn

local function record(c: Model, t: number)
	local root = c:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local h = history[c]
	if not h then
		h = { i = 0, t = {}, cf = {} }
		history[c] = h
	end
	h.i = h.i % HISTORY_LEN + 1
	h.t[h.i] = t
	h.cf[h.i] = root.CFrame
end

-- à appeler une fois côté serveur (CombatService.init) ; idempotent. rate = échantillons / s, len = secondes gardées
function Hitbox.startHistory(rate: number?, len: number?)
	if historyConn or not RunService:IsServer() then
		return
	end
	HISTORY_STEP = 1 / math.max(5, rate or 20)
	HISTORY_LEN = math.max(4, math.ceil((len or 1) / HISTORY_STEP) + 2)
	local acc = 0
	historyConn = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < HISTORY_STEP then
			return
		end
		acc = 0
		local t = os.clock()
		for _, c in ipairs(Hitbox.characters()) do
			record(c, t)
		end
	end)
end

-- CFrame du HumanoidRootPart de `c` à l'instant os.clock() `t` (interpolée entre deux échantillons) ;
-- nil si aucun historique ne couvre cet instant (le plus vieux échantillon est utilisé s'il est un peu trop récent)
function Hitbox.rootAt(c: Model, t: number): CFrame?
	local h = history[c]
	if not h or h.i == 0 then
		return nil
	end
	local newer, newerT -- échantillon juste après t
	for k = 0, HISTORY_LEN - 1 do
		local idx = (h.i - 1 - k) % HISTORY_LEN + 1
		local st = h.t[idx]
		if not st then
			break
		end
		if st <= t then
			if not newer then
				return h.cf[idx] -- t plus récent que le dernier échantillon
			end
			local a = math.clamp((t - st) / math.max(newerT - st, 1e-3), 0, 1)
			return h.cf[idx]:Lerp(newer, a)
		end
		newer, newerT = h.cf[idx], st
	end
	return newer -- historique plus court que le rembobinage demandé : le plus vieux connu
end

-- demi-gabarit d'un personnage autour de son HumanoidRootPart (test du point rembobiné dans la boîte)
local BODY_HALF = Vector3.new(1.5, 2.6, 1)

-- Renvoie les personnages touchés par une boîte, triés du plus proche au plus loin.
-- rewind (s, serveur) : un personnage est aussi touché si sa position d'il y a `rewind` s était dans la boîte
-- (compensation de la latence de l'attaquant ; voir CombatService.rewindFor).
function Hitbox.box(cf: CFrame, size: Vector3, exclude: Model?, maxTargets: number?, rewind: number?): { Model }
	local include = {}
	for _, c in ipairs(Hitbox.characters()) do
		if c ~= exclude then
			table.insert(include, c)
		end
	end
	if #include == 0 then
		return {}
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = include
	local parts = workspace:GetPartBoundsInBox(cf, size, params)
	local seen, hits = {}, {}
	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		while model and not model:FindFirstChildOfClass("Humanoid") do
			model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
		end
		if model and not seen[model] then
			seen[model] = true
			table.insert(hits, model)
		end
	end
	if rewind and rewind > 0.005 then
		local t = os.clock() - rewind
		local half = size / 2 + BODY_HALF
		for _, c in ipairs(include) do
			if not seen[c] then
				local past = Hitbox.rootAt(c, t)
				if past then
					local l = cf:PointToObjectSpace(past.Position)
					if math.abs(l.X) <= half.X and math.abs(l.Y) <= half.Y and math.abs(l.Z) <= half.Z then
						seen[c] = true
						table.insert(hits, c)
					end
				end
			end
		end
	end
	table.sort(hits, function(a, b)
		local pa, pb = a:GetPivot().Position, b:GetPivot().Position
		return (pa - cf.Position).Magnitude < (pb - cf.Position).Magnitude
	end)
	if maxTargets and #hits > maxTargets then
		for i = #hits, maxTargets + 1, -1 do
			table.remove(hits, i)
		end
	end
	return hits
end

-- CFrame de la hitbox devant un personnage
function Hitbox.frontCFrame(character: Model, offset: number): CFrame?
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	return root.CFrame * CFrame.new(0, 0, -offset)
end

return Hitbox
