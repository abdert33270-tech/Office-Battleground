--[[
	UnlockService — déblocage des personnages (Config/Unlocks : Free / Cash / Robux Game Pass).
	Données (DataService, sauvegardées) : Characters = {[charId]=true} (persos achetés / donnés).
	Les persos Free sont toujours possédés ; un Game Pass possédé débloque son perso (vérifié à l'arrivée
	avec UserOwnsGamePassAsync et à PromptGamePassPurchaseFinished).
	CharacterService.canUse = UnlockService.owns (SelectCharacter refuse un perso non possédé, repli Intern).
	Réseau (ReplicatedStorage.Remotes) :
		RemoteFunction UnlockRequest:InvokeServer(op, ...)
			"State"             -> state
			"BuyCash", charId   -> ok, reason?, state   (reason : "OWNED" | "NOT_CASH" | "NOT_ENOUGH_CASH" | "NOT_LOADED" | "UNKNOWN")
			"BuyRobux", charId  -> ok, reason?          ("COMING_SOON" tant que GamePassId == 0)
		RemoteEvent UnlockState (serveur -> client) : state à chaque changement
	state = { Owned = {[charId]=true} (tous les persos de Characters.Order possédés), Cash }
	API serveur : UnlockService.owns(player, id) | give(player, id) | take(player, id) | giveAll(player) | takeAll(player)
	              getState(player) | push(player)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage.Shared
local Characters = require(Shared.Config.Characters)
local Unlocks = require(Shared.Config.Unlocks)
local Net = require(Shared.Modules.Net)
local DataService = require(script.Parent.DataService)

local UnlockService = {}
UnlockService.Priority = 64 -- après DataService (60) et SkinService (62)

local stateRemote
local passCache = {} -- [player] = {[passId]=true}

local function data(player)
	return DataService.get(player)
end

local function service(name)
	local m = script.Parent:FindFirstChild(name)
	local ok, mod = pcall(require, m)
	return ok and mod or nil
end

function UnlockService.owns(player: Player, id: string): boolean
	if not Characters[id] then
		return false
	end
	local e = Unlocks.get(id)
	if e.Tier == "Free" then
		return true
	end
	local d = data(player)
	if d and type(d.Characters) == "table" and d.Characters[id] then
		return true
	end
	if e.Tier == "Robux" and e.GamePassId and e.GamePassId ~= 0 then
		local c = passCache[player]
		if c and c[e.GamePassId] then
			return true
		end
	end
	return false
end

function UnlockService.getState(player: Player)
	local owned = {}
	for _, id in ipairs(Characters.Order) do
		if UnlockService.owns(player, id) then
			owned[id] = true
		end
	end
	local d = data(player)
	return { Owned = owned, Cash = d and d.Cash or 0 }
end

function UnlockService.push(player: Player)
	if stateRemote and player.Parent then
		stateRemote:FireClient(player, UnlockService.getState(player))
	end
end

local function save(player)
	if DataService.save then
		task.spawn(DataService.save, player)
	end
end

-- si le perso joué n'est plus possédé : retour à l'Intern
local function recheckCurrent(player)
	local cs = service("CharacterService")
	local cur = player:GetAttribute("CharacterName")
	if cs and cur and cs.usable and not cs.usable(player, cur) then
		cs.setCharacter(player, Unlocks.DEFAULT, true)
	end
end

function UnlockService.give(player: Player, id: string)
	local d = data(player)
	if not d or not Characters[id] then
		return false
	end
	if type(d.Characters) ~= "table" then
		d.Characters = {}
	end
	if Unlocks.isFree(id) then
		return true
	end
	d.Characters[id] = true
	UnlockService.push(player)
	save(player)
	return true
end

function UnlockService.take(player: Player, id: string)
	local d = data(player)
	if not d or not Characters[id] or Unlocks.isFree(id) then
		return false
	end
	if type(d.Characters) == "table" then
		d.Characters[id] = nil
	end
	recheckCurrent(player)
	UnlockService.push(player)
	save(player)
	return true
end

function UnlockService.giveAll(player: Player)
	local d = data(player)
	if not d then
		return false
	end
	if type(d.Characters) ~= "table" then
		d.Characters = {}
	end
	for _, id in ipairs(Characters.Order) do
		if not Unlocks.isFree(id) then
			d.Characters[id] = true
		end
	end
	UnlockService.push(player)
	save(player)
	return true
end

function UnlockService.takeAll(player: Player)
	local d = data(player)
	if not d then
		return false
	end
	d.Characters = {}
	recheckCurrent(player)
	UnlockService.push(player)
	save(player)
	return true
end

local function buyCash(player, id)
	local d = data(player)
	if not d then
		return false, "NOT_LOADED"
	end
	if type(id) ~= "string" or not Characters[id] then
		return false, "UNKNOWN"
	end
	if UnlockService.owns(player, id) then
		return false, "OWNED"
	end
	local e = Unlocks.get(id)
	if e.Tier ~= "Cash" then
		return false, "NOT_CASH"
	end
	local price = math.max(0, math.floor(e.Price or 0))
	if (d.Cash or 0) < price then
		return false, "NOT_ENOUGH_CASH"
	end
	local skins = service("SkinService")
	if skins and skins.addCash then
		skins.addCash(player, -price) -- pas de popup pour une dépense ; met à jour l'attribut Cash
	else
		d.Cash -= price
		player:SetAttribute("Cash", d.Cash)
	end
	if type(d.Characters) ~= "table" then
		d.Characters = {}
	end
	d.Characters[id] = true
	UnlockService.push(player)
	save(player)
	return true
end

local function buyRobux(player, id)
	if type(id) ~= "string" or not Characters[id] then
		return false, "UNKNOWN"
	end
	if UnlockService.owns(player, id) then
		return false, "OWNED"
	end
	local e = Unlocks.get(id)
	if e.Tier ~= "Robux" then
		return false, "NOT_ROBUX"
	end
	if not e.GamePassId or e.GamePassId == 0 then
		return false, "COMING_SOON"
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptGamePassPurchase(player, e.GamePassId)
	end)
	if not ok then
		warn("[UnlockService] PromptGamePassPurchase :", err)
		return false, "ERROR"
	end
	return true
end

-- Game Pass : vérifie la possession de tous les passes configurés (à l'arrivée)
local function checkPasses(player)
	local c = passCache[player] or {}
	passCache[player] = c
	local changed = false
	for id, e in pairs(Unlocks.List) do
		if e.Tier == "Robux" and e.GamePassId and e.GamePassId ~= 0 and not c[e.GamePassId] then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, e.GamePassId)
			end)
			if ok and has then
				c[e.GamePassId] = true
				local d = data(player)
				if d and type(d.Characters) == "table" then
					d.Characters[id] = true
				end
				changed = true
			end
		end
	end
	if changed then
		UnlockService.push(player)
	end
end

local function remoteFunction(name)
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	local r = folder:FindFirstChild(name)
	if r and not r:IsA("RemoteFunction") then
		r:Destroy()
		r = nil
	end
	if not r then
		r = Instance.new("RemoteFunction")
		r.Name = name
		r.Parent = folder
	end
	return r
end

function UnlockService.init()
	stateRemote = Net.get("UnlockState")
	local request = remoteFunction("UnlockRequest")
	request.OnServerInvoke = function(player, op, a)
		if not Net.allow(player, "UnlockRequest", 6) then
			return nil
		end
		if op == "State" then
			return UnlockService.getState(player)
		elseif op == "BuyCash" then
			local ok, reason = buyCash(player, a)
			return ok, reason, UnlockService.getState(player)
		elseif op == "BuyRobux" then
			return buyRobux(player, a)
		end
		return nil
	end

	-- possession vérifiée côté serveur (CharacterService.setCharacter / réapparition)
	local cs = service("CharacterService")
	if cs then
		cs.canUse = UnlockService.owns
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local id = Unlocks.byGamePass(passId)
		if id then
			passCache[player] = passCache[player] or {}
			passCache[player][passId] = true
			UnlockService.give(player, id)
			local kit = Characters[id]
			require(script.Parent.Announce).toast(player, "UNLOCKED " .. string.upper(kit and kit.DisplayName or id) .. "!", Color3.fromRGB(255, 200, 40))
		end
	end)

	table.insert(DataService.onLoaded, function(player, d)
		if type(d.Characters) ~= "table" then
			d.Characters = {}
		end
		task.spawn(checkPasses, player)
		recheckCurrent(player)
		UnlockService.push(player)
	end)
	Players.PlayerRemoving:Connect(function(p)
		passCache[p] = nil
	end)
end

return UnlockService
