--[[
	SkinService — skins des personnages, Cash, Mystery Briefcase, produits Robux (cosmétique uniquement).
	Données (DataService, sauvegardées) : Cash, Skins {[id]=true}, Equipped {[charId]=id|"Avatar"}, Crates.
	Attributs Player répliqués : Cash, Crates.
	Réseau (ReplicatedStorage.Remotes) :
		RemoteFunction SkinRequest:InvokeServer(op, ...)
			"State"                 -> state
			"Equip", charId, skinId -> ok, state
			"OpenCrate", crateId?   -> { ok, skinId, rarity, duplicate, refund, reel = {30 ids du pool de la caisse, gagné en [25]}, paidWith, crateId, price } | { ok=false, reason }
				(crateId nil => "Briefcase" ; les Crates gratuites ne servent que sur la Briefcase)
			"Crates"                -> liste des caisses (Config/Skins.Crates)
			"Buy", productKey|productId -> ok, reason?   ("COMING_SOON" tant que ProductId == 0)
		RemoteEvent SkinState (serveur -> client) : state à chaque changement
		RemoteEvent CashPopup (serveur -> client) : { amount, reason }
	state = { Cash, Crates, Owned = {[id]=true} (skins Base inclus), Equipped = {[charId]=id} (tous les persos, "Avatar" par défaut) }
	API serveur : SkinService.applyTo(character, player?, charName) | addCash(player, n, reason?) | addCrates(player, n)
	              grantAll(player) | getState(player) | equip(player, charId, skinId) | openCrate(player, crateId?)
	              rollSkin(crateId?, rng?) (debug, ne donne rien) | crateList()
	Gains : jamais sur les mannequins (Hit / Died ne comptent que des victimes joueurs) ; FarmGuard : 0 contre une
victime passive (aucun dégât depuis 60 s) et pour une paire tueur -> victime au-delà de 3 K.O. / 10 min.
Robux : ProcessReceipt n'octroie que si les données sont sauvables et SAUVÉES (sinon annulation + NotProcessedYet),
PurchaseId gardés dans data.Receipts (anti double octroi). Voir docs/Serveur-securite.md.
	Persos sans skins (Skins.hasSkins(charId) == false, ex. Bacon) : look fixe (avatar d'origine + accessoires de
	métier), Equip refusé sauf "Avatar", jamais dans les caisses.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage.Shared
local Skins = require(Shared.Config.Skins)
local Characters = require(Shared.Config.Characters)
local SkinBuilder = require(Shared.Modules.SkinBuilder)
local Net = require(Shared.Modules.Net)
local Signals = require(script.Parent.Signals)
local DataService = require(script.Parent.DataService)
local FarmGuard = require(script.Parent.FarmGuard)

local SkinService = {}
SkinService.Priority = 62 -- après DataService (60) et TaskService (61)

local AVATAR = Skins.AVATAR
local REEL_SIZE, REEL_WIN = 30, 25

local stateRemote, popupRemote
local snaps = {} -- [character] = instantané de l'avatar d'origine
local dmgAcc = {} -- [player] = dégâts accumulés (Cash tous les 100)
local rng = Random.new()

local function data(player)
	return DataService.get(player)
end

local function syncAttributes(player, d)
	player:SetAttribute("Cash", d.Cash)
	player:SetAttribute("Crates", d.Crates)
end

function SkinService.getState(player: Player)
	local d = data(player)
	local owned, equipped = {}, {}
	for _, charId in ipairs(Characters.Order) do
		if Skins.hasSkins(charId) then
			owned[Skins.baseId(charId)] = true
		end
		equipped[charId] = AVATAR
	end
	if d then
		for id in pairs(d.Skins) do
			if Skins.List[id] then
				owned[id] = true
			end
		end
		for charId, id in pairs(d.Equipped) do
			if equipped[charId] and (id == AVATAR or owned[id]) then
				equipped[charId] = id
			end
		end
	end
	return {
		Cash = d and d.Cash or 0,
		Crates = d and d.Crates or 0,
		Owned = owned,
		Equipped = equipped,
	}
end

local function push(player)
	local d = data(player)
	if d then
		syncAttributes(player, d)
	end
	if stateRemote and player.Parent then
		stateRemote:FireClient(player, SkinService.getState(player))
	end
end
SkinService.push = push

function SkinService.addCash(player: Player, amount: number, reason: string?)
	local d = data(player)
	amount = math.floor(tonumber(amount) or 0)
	if not d or amount == 0 then
		return false
	end
	d.Cash = math.max(0, d.Cash + amount)
	if reason and popupRemote and amount > 0 then
		popupRemote:FireClient(player, { amount = amount, reason = reason })
	end
	push(player)
	return true
end

function SkinService.addCrates(player: Player, n: number)
	local d = data(player)
	n = math.floor(tonumber(n) or 0)
	if not d or n == 0 then
		return false
	end
	d.Crates = math.max(0, d.Crates + n)
	push(player)
	return true
end

function SkinService.grantAll(player: Player)
	local d = data(player)
	if not d then
		return false
	end
	for id, s in pairs(Skins.List) do
		if s.Rarity ~= "Base" then
			d.Skins[id] = true
		end
	end
	push(player)
	return true
end

-- skin réellement porté pour ce perso (vérifie la possession)
local function equippedFor(player, charName)
	local d = data(player)
	local id = d and d.Equipped[charName] or AVATAR
	if id == AVATAR or not Skins.hasSkins(charName) then
		return AVATAR
	end
	local s = Skins.get(id)
	if not s or s.Character ~= charName then
		return AVATAR
	end
	if s.Rarity ~= "Base" and not d.Skins[id] then
		return AVATAR
	end
	return id
end
SkinService.equippedFor = equippedFor

------------------------------------------------------------------------
-- Apparence
------------------------------------------------------------------------
local function snapshotOf(character)
	local snap = snaps[character]
	if not snap then
		snap = SkinBuilder.snapshot(character)
		snaps[character] = snap
		character.Destroying:Connect(function()
			snaps[character] = nil
		end)
	end
	return snap
end

-- appelé par CharacterService.apply (et à chaque changement d'équipement)
function SkinService.applyTo(character: Model, player: Player?, charName: string)
	if not character or not Characters[charName] then
		return
	end
	if not player then
		-- mannequins : on garde leur look ; autres PNJ : uniforme (perso sans skins : rien à mettre)
		if not character:GetAttribute("IsDummy") and Skins.hasSkins(charName) then
			SkinBuilder.dress(character, Skins.baseId(charName))
		end
		SkinBuilder.identity(character, charName)
		return
	end
	local snap = snapshotOf(character)
	if not Skins.hasSkins(charName) then
		-- perso unique (Bacon) : avatar d'origine + son look de métier, aucun skin possible
		SkinBuilder.restore(character, snap)
		SkinBuilder.identity(character, charName)
		character:SetAttribute("SkinId", AVATAR)
		return
	end
	local id = equippedFor(player, charName)
	if id == AVATAR then
		SkinBuilder.restore(character, snap)
		SkinBuilder.clearIdentity(character)
	else
		SkinBuilder.dress(character, id, { snapshot = snap })
		local def = Skins.get(id)
		if def and def.HideIdentity then
			SkinBuilder.clearIdentity(character)
		else
			SkinBuilder.identity(character, charName)
		end
	end
	character:SetAttribute("SkinId", id)
end

local function refreshLive(player, charId)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if c and hum and hum.Health > 0 and c:GetAttribute("CharacterName") == charId then
		SkinService.applyTo(c, player, charId)
	end
end

function SkinService.equip(player: Player, charId, skinId)
	local d = data(player)
	if not d or type(charId) ~= "string" or type(skinId) ~= "string" or not Characters[charId] then
		return false
	end
	if skinId ~= AVATAR then
		if not Skins.hasSkins(charId) then
			return false
		end
		local s = Skins.get(skinId)
		if not s or s.Character ~= charId then
			return false
		end
		if s.Rarity ~= "Base" and not d.Skins[skinId] then
			return false
		end
	end
	d.Equipped[charId] = skinId
	refreshLive(player, charId)
	push(player)
	return true
end

------------------------------------------------------------------------
-- Mystery Briefcase
------------------------------------------------------------------------
-- tirage : rareté pondérée par crate.Odds (raretés vides ignorées), puis skin uniforme dans le pool de la caisse
local function rollRarity(crate, r)
	r = r or rng
	local order = Skins.Rarities.Order
	local total = 0
	for _, rar in ipairs(order) do
		local pool = crate.SkinPool[rar]
		local w = crate.Odds[rar] or 0
		if pool and #pool > 0 and w > 0 then
			total += w
		end
	end
	if total <= 0 then
		return nil
	end
	local x = r:NextNumber() * total
	local last
	for _, rar in ipairs(order) do
		local pool = crate.SkinPool[rar]
		local w = crate.Odds[rar] or 0
		if pool and #pool > 0 and w > 0 then
			last = rar
			x -= w
			if x <= 0 then
				return rar
			end
		end
	end
	return last
end

local function rollSkin(crate, r)
	r = r or rng
	local rar = rollRarity(crate, r)
	if not rar then
		return nil
	end
	local pool = crate.SkinPool[rar]
	return pool[r:NextInteger(1, #pool)], rar
end

-- accès debug / tests : SkinService.rollSkin(crateId?, rng?) -> skinId, rarity (ne donne rien au joueur)
function SkinService.rollSkin(crateId, r)
	local crate = Skins.getCrate(crateId)
	if not crate then
		return nil
	end
	return rollSkin(crate, r)
end

-- liste des caisses pour l'UI (données de Config/Skins, sans les pools d'ids)
function SkinService.crateList()
	local out = {}
	for _, c in ipairs(Skins.Crates) do
		table.insert(out, {
			Id = c.Id, Name = c.Name, Price = c.Price, Shape = c.Shape, Color = c.Color, Accent = c.Accent,
			Desc = c.Desc, Odds = c.Odds, Pool = c.Pool, Refund = c.Refund,
		})
	end
	return out
end

function SkinService.openCrate(player: Player, crateId)
	local d = data(player)
	if not d then
		return { ok = false, reason = "NOT_LOADED" }
	end
	local crate = Skins.getCrate(crateId)
	if not crate then
		return { ok = false, reason = "UNKNOWN_CRATE" }
	end
	if not rollRarity(crate) then
		return { ok = false, reason = "NO_SKINS", crateId = crate.Id }
	end
	local paidWith
	-- les caisses gratuites (Robux) sont génériques : seulement sur la Mystery Briefcase
	if crate.Id == Skins.DEFAULT_CRATE and d.Crates > 0 then
		d.Crates -= 1
		paidWith = "Crate"
	elseif d.Cash >= crate.Price then
		d.Cash -= crate.Price
		paidWith = "Cash"
	else
		return { ok = false, reason = "NOT_ENOUGH_CASH", crateId = crate.Id, price = crate.Price }
	end
	local id, rarity = rollSkin(crate)
	local duplicate = d.Skins[id] == true
	local refund = 0
	if duplicate then
		refund = (crate.Refund and crate.Refund[rarity]) or 0
		d.Cash += refund
	else
		d.Skins[id] = true
	end
	local reel = {}
	for i = 1, REEL_SIZE do
		reel[i] = (i == REEL_WIN) and id or (rollSkin(crate))
	end
	push(player)
	return {
		ok = true, skinId = id, rarity = rarity, duplicate = duplicate, refund = refund, reel = reel,
		paidWith = paidWith, crateId = crate.Id, price = crate.Price,
	}
end

------------------------------------------------------------------------
-- Robux
------------------------------------------------------------------------
local function findProduct(key)
	if type(key) == "string" then
		return Skins.productByKey(key)
	elseif type(key) == "number" then
		for _, p in ipairs(Skins.Products) do
			if p.ProductId == key and key ~= 0 then
				return p
			end
		end
	end
	return nil
end

local function buy(player, key)
	local p = findProduct(key)
	if not p then
		return false, "UNKNOWN"
	end
	if not p.ProductId or p.ProductId == 0 then
		return false, "COMING_SOON"
	end
	local ok, err = pcall(function()
		MarketplaceService:PromptProductPurchase(player, p.ProductId)
	end)
	if not ok then
		warn("[SkinService] PromptProductPurchase :", err)
		return false, "ERROR"
	end
	return true
end

-- ProcessReceipt : Roblox rappelle tant qu'on ne renvoie pas PurchaseGranted (même après un rejoin).
-- On ne renvoie PurchaseGranted QUE si l'achat est écrit dans le DataStore (DataService.save -> true) ;
-- sinon on annule l'octroi en mémoire et on renvoie NotProcessedYet (Roblox réessaiera plus tard).
-- data.Receipts = PurchaseId déjà octroyés (50 derniers) : jamais deux fois le même achat.
local RECEIPTS_KEPT = 50
local processing = {} -- [PurchaseId] = true pendant le traitement (deux appels simultanés)

local function processReceipt(info)
	local NOT_YET = Enum.ProductPurchaseDecision.NotProcessedYet
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local d = player and data(player)
	if not player or not d then
		return NOT_YET -- pas là / données pas encore chargées
	end
	if DataService.loadFailed(player) or (DataService.canSave and not DataService.canSave(player)) then
		return NOT_YET -- session non sauvable : on n'octroie rien qui serait perdu
	end
	local product = Skins.productById(info.ProductId)
	if not product then
		warn("[SkinService] produit inconnu", info.ProductId)
		return NOT_YET
	end
	local pid = tostring(info.PurchaseId)
	if processing[pid] then
		return NOT_YET
	end
	d.Receipts = type(d.Receipts) == "table" and d.Receipts or {}
	if table.find(d.Receipts, pid) or table.find(d.Receipts, info.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- déjà octroyé ET sauvé
	end
	processing[pid] = true
	local cash = math.max(0, math.floor(tonumber(product.Cash) or 0))
	local crates = math.max(0, math.floor(tonumber(product.Crates) or 0))
	d.Cash += cash
	d.Crates += crates
	table.insert(d.Receipts, pid)
	while #d.Receipts > RECEIPTS_KEPT do
		table.remove(d.Receipts, 1)
	end
	local ok, saved = pcall(DataService.save, player)
	if not (ok and saved == true) then
		-- annulation : rien n'a été écrit, Roblox nous rappellera
		local i = table.find(d.Receipts, pid)
		if i then
			table.remove(d.Receipts, i)
		end
		d.Cash = math.max(0, d.Cash - cash)
		d.Crates = math.max(0, d.Crates - crates)
		processing[pid] = nil
		push(player)
		warn("[SkinService] achat " .. pid .. " de " .. player.Name .. " non sauvé : NotProcessedYet (" .. tostring(saved) .. ")")
		return NOT_YET
	end
	processing[pid] = nil
	if cash > 0 and popupRemote then
		popupRemote:FireClient(player, { amount = cash, reason = "PURCHASE" })
	end
	push(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

------------------------------------------------------------------------
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

local function playerOf(model)
	return model and Players:GetPlayerFromCharacter(model) or nil
end

function SkinService.init()
	stateRemote = Net.get("SkinState")
	popupRemote = Net.get("CashPopup")
	local request = remoteFunction("SkinRequest")
	request.OnServerInvoke = function(player, op, a, b)
		if not Net.allow(player, "SkinRequest", 8) then
			return nil
		end
		if op == "State" then
			return SkinService.getState(player)
		elseif op == "Equip" then
			local ok = SkinService.equip(player, a, b)
			return ok, SkinService.getState(player)
		elseif op == "OpenCrate" then
			return SkinService.openCrate(player, a)
		elseif op == "Crates" then
			return SkinService.crateList()
		elseif op == "Buy" then
			return buy(player, a)
		end
		return nil
	end

	MarketplaceService.ProcessReceipt = processReceipt

	table.insert(DataService.onLoaded, function(player, d)
		syncAttributes(player, d)
		push(player)
		-- données arrivées après l'apparition : remet le bon skin
		local c = player.Character
		local name = c and c:GetAttribute("CharacterName")
		if name then
			refreshLive(player, name)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		dmgAcc[p] = nil
	end)

	-- gains de Cash (jamais sur les mannequins : victimes joueurs uniquement)
	local E = Skins.Earn
	Signals.Hit:Connect(function(attacker, victim, damage)
		local player = playerOf(attacker)
		if not player or attacker == victim or type(damage) ~= "number" or damage <= 0 then
			return
		end
		local vp = playerOf(victim)
		if not vp or not FarmGuard.damageRewarded(player, vp) then
			return -- mannequin / PNJ, ou victime passive (alt / AFK : aucun dégât infligé depuis 60 s)
		end
		local acc = (dmgAcc[player] or 0) + damage
		local packs = math.floor(acc / 100)
		dmgAcc[player] = acc - packs * 100
		if packs > 0 then
			SkinService.addCash(player, packs * E.Per100Damage, "DAMAGE")
		end
	end)
	Signals.Died:Connect(function(victim, killer)
		local player = playerOf(killer)
		if player and killer ~= victim and playerOf(victim) and FarmGuard.koRewarded(killer, victim) then
			SkinService.addCash(player, E.KO, "K.O.")
		end
	end)
	Signals.SurvivedCollapse:Connect(function(character)
		local player = playerOf(character)
		if player then
			SkinService.addCash(player, E.SurviveCollapse, "SURVIVED")
		end
	end)
	Signals.TaskCompleted:Connect(function(player)
		if typeof(player) == "Instance" and player:IsA("Player") then
			SkinService.addCash(player, E.Task, "DAILY TASK")
		end
	end)
	Signals.GradeUp:Connect(function(player)
		if typeof(player) == "Instance" and player:IsA("Player") then
			SkinService.addCash(player, E.GradeUp, "PROMOTION")
		end
	end)
end

return SkinService
