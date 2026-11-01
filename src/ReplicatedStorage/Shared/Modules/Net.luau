--[[
	Net — RemoteEvents du jeu + limiteur de fréquence côté serveur.
	Client -> Serveur : Attack, Pickup, Throw
	Serveur -> Client : FX (effets cartoon), Anim (animations des autres joueurs)
]]
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NAMES = { "Attack", "Pickup", "Throw", "FX", "Anim" }

local Net = {}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in ipairs(NAMES) do
		if not folder:FindFirstChild(name) then
			local r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes")
end

-- Serveur : crée la RemoteEvent si elle n'existe pas (n'importe quel module peut ajouter les siennes).
-- Client : attend qu'elle existe.
function Net.get(name: string): RemoteEvent
	if RunService:IsServer() then
		local r = folder:FindFirstChild(name)
		if not r then
			r = Instance.new("RemoteEvent")
			r.Name = name
			r.Parent = folder
		end
		return r
	end
	return folder:WaitForChild(name)
end

-- Limiteur "seau de jetons" par joueur et par remote (buckets[UserId][remote])
local buckets = {}
function Net.allow(player: Player, name: string, perSecond: number): boolean
	local mine = buckets[player.UserId]
	if not mine then
		mine = {}
		buckets[player.UserId] = mine
	end
	local now = os.clock()
	local b = mine[name]
	if not b then
		b = { tokens = perSecond, t = now }
		mine[name] = b
	end
	b.tokens = math.min(perSecond, b.tokens + (now - b.t) * perSecond)
	b.t = now
	if b.tokens < 1 then
		return false
	end
	b.tokens -= 1
	return true
end

if RunService:IsServer() then
	-- on oublie tous les seaux du joueur (y compris ceux des remotes créées par les services : Dash, Block, Ability...)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		buckets[p.UserId] = nil
	end)
end

return Net
