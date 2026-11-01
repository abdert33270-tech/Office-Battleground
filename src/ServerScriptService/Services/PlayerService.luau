--[[
	PlayerService — apparition des joueurs en R6 + mort / ragdoll / réapparition.
	R6 forcé : le réglage "Avatar Type" n'est pas modifiable par script, donc on recrée
	chaque avatar en R6 depuis sa HumanoidDescription (apparence du joueur conservée).
	À faire aussi à la publication : Game Settings > Avatar > R6.
	Première apparition de la session : bulle ForceField VISIBLE « FirstSpawnShield » (FIRST_SHIELD s, comptées à partir
	du choix du perso s'il arrive plus tard, plafond FIRST_SHIELD_MAX s) ; elle saute dès que le joueur attaque
	(remotes Attack / Ability / Throw / Ultimate).
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Modules.Net)

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

local FIRST_SHIELD = 12 -- s de bulle visible à la première apparition de la session
local FIRST_SHIELD_MAX = 40 -- plafond (joueur resté longtemps dans le menu de sélection)
local SHIELD_NAME = "FirstSpawnShield"
local firstSpawned = {} -- [player] = true après la première apparition de la session
local shields = {} -- [player] = { ff = ForceField, start = os.clock(), endAt = os.clock() }

local function dropShield(player)
	local sh = shields[player]
	shields[player] = nil
	if sh and sh.ff.Parent then
		sh.ff:Destroy()
	end
end

local function giveFirstShield(player, character)
	local ff = Instance.new("ForceField")
	ff.Name = SHIELD_NAME
	ff.Visible = true
	ff.Parent = character
	local t = os.clock()
	shields[player] = { ff = ff, start = t, endAt = t + FIRST_SHIELD }
end

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
	if not firstSpawned[player] then
		firstSpawned[player] = true
		giveFirstShield(player, character)
	end
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
		firstSpawned[p] = nil
		shields[p] = nil
	end)

	-- bulle de première apparition : saute à la première attaque
	for _, name in ipairs({ "Attack", "Ability", "Throw", "Ultimate" }) do
		Net.get(name).OnServerEvent:Connect(function(p)
			if shields[p] then
				dropShield(p)
			end
		end)
	end
	-- choix du perso (souvent après un moment dans le menu) : les FIRST_SHIELD s repartent de là
	Net.get("SelectCharacter").OnServerEvent:Connect(function(p)
		local sh = shields[p]
		if sh then
			sh.endAt = math.min(sh.start + FIRST_SHIELD_MAX, math.max(sh.endAt, os.clock() + FIRST_SHIELD))
		end
	end)
	task.spawn(function()
		while true do
			task.wait(0.25)
			local t = os.clock()
			for p, sh in pairs(shields) do
				if t >= sh.endAt or not sh.ff.Parent or not p.Parent then
					dropShield(p)
				end
			end
		end
	end)
end

return PlayerService
