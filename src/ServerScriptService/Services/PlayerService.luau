--[[
	PlayerService — apparition des joueurs en R6 + mort / ragdoll / réapparition.
	R6 forcé : le réglage "Avatar Type" n'est pas modifiable par script, donc on recrée
	chaque avatar en R6 depuis sa HumanoidDescription (apparence du joueur conservée).
	À faire aussi à la publication : Game Settings > Avatar > R6.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.Config.Combat)
local CharacterState = require(script.Parent.CharacterState)
local Ragdoll = require(script.Parent.Ragdoll)
local RigBuilder = require(script.Parent.RigBuilder)
local World = require(script.Parent.World)

local PlayerService = {}
PlayerService.Priority = 90
PlayerService.afterSpawn = {} -- hooks : function(player, character) appelés après chaque apparition (CharacterService...)

local descCache = {}
local rng = Random.new()

local function pickSpawn(): CFrame
	return World.getPlayerSpawn()
end

local function buildR6(player: Player): Model
	local desc = descCache[player]
	if not desc then
		local ok, result = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(math.max(player.UserId, 1))
		end)
		if ok then
			desc = result
			descCache[player] = desc
		end
	end
	local character
	if desc then
		local ok, result = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
		end)
		if ok then
			character = result
		end
	end
	if not character then
		warn("[PlayerService] avatar R6 de secours pour", player.Name)
		character = RigBuilder.r6(player.Name)
	end
	character.Name = player.Name
	return character
end

function PlayerService.spawn(player: Player)
	if not player.Parent then
		return
	end
	local character = buildR6(player)
	character:PivotTo(pickSpawn())
	player.Character = character
	character.Parent = workspace
	CharacterState.setup(character)
	CharacterState.protect(character)
	for _, hook in ipairs(PlayerService.afterSpawn) do
		task.spawn(hook, player, character)
	end

	local hum = character:FindFirstChildOfClass("Humanoid")
	hum.Died:Connect(function()
		Ragdoll.apply(character, character:GetAttribute("KOLaunch"))
		task.delay(Players.RespawnTime, function()
			if player.Parent and player.Character == character then
				character:Destroy()
				PlayerService.spawn(player)
			end
		end)
	end)
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") and d.CollisionGroup == "Default" then
			d.CollisionGroup = "Characters"
		end
	end)
end

function PlayerService.init()
	Players.CharacterAutoLoads = false
	Players.RespawnTime = CombatConfig.RespawnTime or 4
	local function onPlayer(player)
		PlayerService.spawn(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayer, p)
	end
	Players.PlayerRemoving:Connect(function(p)
		descCache[p] = nil
	end)
end

return PlayerService
