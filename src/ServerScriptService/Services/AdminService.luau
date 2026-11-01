--[[
	AdminService — commandes réservées aux admins, et à tout le monde en Studio.
	Admins : ensemble ADMINS (UserId : xiregxyt 1676557658 + liste) OU rang >= ADMIN_GROUP.MinRank dans le groupe
	ADMIN_GROUP.Id (0 = désactivé ; rang lu une fois à l'arrivée, en pcall).
	Sources : chat (TextChatService ou Player.Chatted) + panneau admin (remote "AdminCommand").
	Vérification TOUJOURS côté serveur ; un non-admin n'obtient AUCUNE réaction (ni toast, ni erreur).
	Chaque commande d'admin exécutée => ligne d'audit warn("[AdminAudit] ...") (journal serveur / Developer Console).
	Modération : /kick <name> [reason]   /announce <text> (filtré TextService)   /shutdown (sauve tout puis expulse)

	/spawn <Item> [n]     /event <Name>     /events     /collapse [Floor]     /nextfloor <Floor>     /skip
	/overtime     /char <Name>     /god     /heal     /dummy     /xp <n>     /grade <Name>     /help
	/cash <n>     /crate [n]     /allskins   (skins : SkinService)
	/givechar <playerName|me> <charId|all>     /takechar <playerName|me> <charId|all>   (UnlockService)
	/level <n> [playerName|me]   (DataService.setLevel : niveau + récompenses des niveaux jamais atteints)
	/resetdaily [full]   (récompense quotidienne réclamable de nouveau ; full = série à zéro)     /afkpay   (paie AFK tout de suite)
	/char force le perso (sans déblocage, pour les tests).
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local Net = require(ReplicatedStorage.Shared.Modules.Net)
local Announce = require(script.Parent.Announce)

local AdminService = {}
AdminService.Priority = 70

-- UserId des admins (ajouter une ligne par admin)
local ADMINS = {
	[1676557658] = true, -- xiregxyt
}
-- groupe optionnel : Id = 0 => désactivé
local ADMIN_GROUP = { Id = 0, MinRank = 254 }
local Services = script.Parent
local Config = ReplicatedStorage.Shared.Config

local groupAdmin = setmetatable({}, { __mode = "k" }) -- [player] = true (rang suffisant, lu à l'arrivée)
local shuttingDown = false

function AdminService.isAdmin(player: Player): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	return ADMINS[player.UserId] == true or groupAdmin[player] == true or RunService:IsStudio()
end

local function checkGroup(player: Player)
	if ADMIN_GROUP.Id == 0 then
		return
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(ADMIN_GROUP.Id)
	end)
	if ok and type(rank) == "number" and rank >= ADMIN_GROUP.MinRank then
		groupAdmin[player] = true
		player:SetAttribute("IsAdmin", true)
	end
end

local function service(name)
	local m = Services:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, mod = pcall(require, m)
	return ok and mod or nil
end

local function config(name)
	local m = Config:FindFirstChild(name)
	if not m then
		return nil
	end
	local ok, mod = pcall(require, m)
	return ok and mod or nil
end

-- Listes pour le panneau et la résolution des noms
local function lists()
	local items, seen = {}, {}
	for id, cfg in pairs(config("Items") or {}) do
		if type(cfg) == "table" and not seen[id] then
			seen[id] = true
			table.insert(items, id)
		end
	end
	for _, m in ipairs(ServerStorage:FindFirstChild("Items") and ServerStorage.Items:GetChildren() or {}) do
		if not seen[m.Name] then
			seen[m.Name] = true
			table.insert(items, m.Name)
		end
	end
	table.sort(items)

	local events = {}
	local es = service("EventService")
	if es and type(es.list) == "function" then
		local ok, l = pcall(es.list)
		if ok and type(l) == "table" then
			events = l
		end
	end
	if #events == 0 then
		for name, e in pairs(config("Events") or {}) do
			if type(e) == "table" then
				table.insert(events, name)
			end
		end
	end
	table.sort(events)

	local floors = {}
	local fs = service("FloorService")
	if fs and type(fs.getFloorNames) == "function" then
		local ok, l = pcall(fs.getFloorNames)
		if ok and type(l) == "table" then
			floors = l
		end
	end
	if #floors == 0 and ServerStorage:FindFirstChild("Floors") then
		for _, f in ipairs(ServerStorage.Floors:GetChildren()) do
			table.insert(floors, f.Name)
		end
	end
	table.sort(floors)

	local chars = {}
	local cc = config("Characters")
	if cc and cc.Order then
		chars = table.clone(cc.Order)
	end
	local grades = {}
	for _, g in ipairs((config("Grades") or { List = {} }).List) do
		table.insert(grades, g.Name)
	end
	-- joueurs du serveur + persos possédés (section GIVE CHARACTER)
	local players, owned = {}, {}
	local us = service("UnlockService")
	for _, p in ipairs(Players:GetPlayers()) do
		table.insert(players, p.Name)
		if us and type(us.getState) == "function" then
			local ok, st = pcall(us.getState, p)
			if ok and type(st) == "table" then
				owned[p.Name] = st.Owned
			end
		end
	end
	table.sort(players)
	return { items = items, events = events, floors = floors, characters = chars, grades = grades, players = players, owned = owned }
end

-- "me" | nom (ou début de nom / nom affiché) d'un joueur du serveur
local function findPlayer(caller, name)
	if not name or name == "" or string.lower(name) == "me" then
		return caller
	end
	local n = string.lower(name)
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == n or string.lower(p.DisplayName) == n then
			return p
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if string.find(string.lower(p.Name), n, 1, true) == 1 or string.find(string.lower(p.DisplayName), n, 1, true) == 1 then
			return p
		end
	end
	return nil
end

local function resolve(name, list)
	if not name or name == "" then
		return nil
	end
	local n = string.lower((string.gsub(name, "[%s_]", "")))
	for _, v in ipairs(list) do
		if string.lower((string.gsub(v, "[%s_]", ""))) == n then
			return v
		end
	end
	for _, v in ipairs(list) do
		if string.find(string.lower(v), n, 1, true) == 1 then
			return v
		end
	end
	return nil
end

local function reply(player, text, ok)
	Announce.toast(player, text, ok == false and Color3.fromRGB(255, 110, 90) or Color3.fromRGB(140, 220, 255))
end

local function call(player, svcName, fnName, ...)
	local mod = service(svcName)
	if not mod or type(mod[fnName]) ~= "function" then
		reply(player, svcName .. "." .. fnName .. " is not available yet", false)
		return false
	end
	local ok, err = pcall(mod[fnName], ...)
	if not ok then
		reply(player, "Error: " .. tostring(err), false)
		warn("[AdminService]", err)
		return false
	end
	return true
end

local COMMANDS = {}

COMMANDS.help = function(player)
	reply(player, "/spawn /event /events /collapse /nextfloor /skip /overtime /char /god /heal /dummy /xp /grade /level /cash /crate /allskins /givechar /takechar /resetdaily /afkpay /kick /announce /shutdown")
end

-- joueur exact (nom ou nom affiché), sinon début de nom UNIQUE (jamais « me » implicite : modération)
local function findExact(name)
	if not name or name == "" then
		return nil
	end
	local n = string.lower(name)
	for _, p in ipairs(Players:GetPlayers()) do
		if string.lower(p.Name) == n then
			return p
		end
	end
	local found
	for _, p in ipairs(Players:GetPlayers()) do
		if string.find(string.lower(p.Name), n, 1, true) == 1 or string.find(string.lower(p.DisplayName), n, 1, true) == 1 then
			if found and found ~= p then
				return nil -- ambigu
			end
			found = p
		end
	end
	return found
end

-- texte libre diffusé à tout le serveur : filtré par Roblox (obligatoire), sinon rien n'est envoyé
local function filterBroadcast(player, text)
	local ok, res = pcall(function()
		local r = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return r:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(res) == "string" then
		return res
	end
	warn("[AdminService] filtre de texte indisponible :", res)
	return nil
end

COMMANDS.kick = function(player, args)
	local target = findExact(args[1])
	if not target then
		return reply(player, "Usage: /kick <name> [reason] (unknown or ambiguous name)", false)
	end
	if target ~= player and AdminService.isAdmin(target) and not RunService:IsStudio() then
		return reply(player, "Cannot kick another admin", false)
	end
	local reason = table.concat(args, " ", 2)
	if reason ~= "" then
		reason = filterBroadcast(player, reason) or ""
	end
	local name = target.Name
	target:Kick(reason ~= "" and ("Kicked by an admin: " .. reason) or "Kicked by an admin.")
	reply(player, "Kicked " .. name)
end

COMMANDS.announce = function(player, _args, raw)
	local text = raw and string.gsub(raw, "^%s+", "") or ""
	text = string.sub((string.gsub(text, "%s+$", "")), 1, 100)
	if text == "" then
		return reply(player, "Usage: /announce <text>", false)
	end
	local clean = filterBroadcast(player, text)
	if not clean then
		return reply(player, "Text filter unavailable, try again", false)
	end
	Announce.banner("ANNOUNCEMENT", clean, Color3.fromRGB(255, 200, 40), 6)
	reply(player, "Announced")
end

local SHUTDOWN_MSG = "The server is restarting for an update. Your progress was saved, please rejoin!"
COMMANDS.shutdown = function(player)
	if shuttingDown then
		return reply(player, "Shutdown already in progress", false)
	end
	shuttingDown = true
	Announce.banner("SERVER RESTARTING", "Saving everyone's progress...", Color3.fromRGB(255, 110, 90), 5)
	reply(player, "Saving all players, then kicking...")
	task.spawn(function()
		local okCount, total = 0, 0
		local ds = service("DataService")
		if ds and type(ds.saveAll) == "function" then
			local ok, a, b = pcall(ds.saveAll, false, 20)
			if ok then
				okCount, total = a, b
			end
		end
		warn(("[AdminAudit] /shutdown : %d/%d profils sauvés, expulsion de tous les joueurs"):format(okCount, total))
		task.wait(1)
		for _, p in ipairs(Players:GetPlayers()) do
			p:Kick(SHUTDOWN_MSG) -- PlayerRemoving refait une sauvegarde finale (libère le verrou)
		end
	end)
end

COMMANDS.spawn = function(player, args)
	local l = lists()
	local id = resolve(args[1], l.items)
	if not id then
		return reply(player, "Unknown item: " .. tostring(args[1]), false)
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local n = math.clamp(tonumber(args[2]) or 1, 1, 10)
	for i = 1, n do
		local offset = CFrame.new((i - (n + 1) / 2) * 4, 0, -7)
		local cf = root.CFrame * offset
		call(player, "ItemService", "spawn", id, cf, nil, cf.Position - Vector3.new(0, 3, 0))
	end
	reply(player, "Spawned " .. n .. " x " .. id)
end

COMMANDS.event = function(player, args)
	local name = resolve(args[1], lists().events) or args[1]
	if not name then
		return reply(player, "Usage: /event <Name>", false)
	end
	if call(player, "EventService", "start", name) then
		reply(player, "Event started: " .. name)
	end
end

COMMANDS.events = function(player)
	reply(player, "Events: " .. table.concat(lists().events, ", "))
end

COMMANDS.collapse = function(player, args)
	local floor = args[1] and (resolve(args[1], lists().floors) or args[1]) or nil
	if call(player, "FloorService", "forceCollapse", floor) then
		reply(player, "Collapsing!" .. (floor and (" Next: " .. floor) or ""))
	end
end

COMMANDS.nextfloor = function(player, args)
	local floor = resolve(args[1], lists().floors) or args[1]
	if not floor then
		return reply(player, "Usage: /nextfloor <Floor>", false)
	end
	if call(player, "FloorService", "setNextFloor", floor) then
		reply(player, "Next floor: " .. floor)
	end
end

COMMANDS.skip = function(player)
	if call(player, "FloorService", "skipPhase") then
		reply(player, "Phase skipped")
	end
end

COMMANDS.overtime = function(player)
	local c = player.Character
	if c then
		c:SetAttribute("Overtime", 100)
		reply(player, "Overtime meter filled")
	end
end

COMMANDS.char = function(player, args)
	local name = resolve(args[1], lists().characters)
	if not name then
		return reply(player, "Unknown character: " .. tostring(args[1]), false)
	end
	if call(player, "CharacterService", "setCharacter", player, name, true) then
		reply(player, "Character: " .. name)
	end
end

COMMANDS.god = function(player)
	local c = player.Character
	if c then
		local on = not c:GetAttribute("God")
		c:SetAttribute("God", on)
		reply(player, "God mode " .. (on and "ON" or "OFF"))
	end
end

COMMANDS.heal = function(player)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = hum.MaxHealth
		reply(player, "Healed")
	end
end

COMMANDS.dummy = function(player)
	if call(player, "DummyService", "respawn") then
		reply(player, "Dummy respawned")
	end
end

COMMANDS.xp = function(player, args)
	local n = tonumber(args[1])
	if not n then
		return reply(player, "Usage: /xp <amount>", false)
	end
	if call(player, "DataService", "addXP", player, n, true) then
		reply(player, "+" .. n .. " XP")
	end
end

COMMANDS.grade = function(player, args)
	local name = resolve(table.concat(args, " "), lists().grades)
	if not name then
		return reply(player, "Unknown grade", false)
	end
	if call(player, "DataService", "setGrade", player, name) then
		reply(player, "Grade: " .. name)
	end
end

COMMANDS.level = function(player, args)
	local n = tonumber(args[1])
	if not n then
		return reply(player, "Usage: /level <1-100> [player]", false)
	end
	local target = findPlayer(player, args[2])
	if not target then
		return reply(player, "Unknown player: " .. tostring(args[2]), false)
	end
	n = math.clamp(math.floor(n), 1, 100)
	if call(player, "DataService", "setLevel", target, n) then
		reply(player, target.Name .. " is now level " .. n)
	end
end

-- rafraîchit seulement la section GIVE CHARACTER du panneau de l'admin
local function pushOwned(player)
	local l = lists()
	Net.get("AdminInfo"):FireClient(player, { ownedUpdate = true, players = l.players, owned = l.owned })
end

-- /givechar <playerName|me> <charId|all>  et  /takechar ... (persos débloqués, sauvegardés)
local function charCommand(give)
	return function(player, args)
		local verb = give and "givechar" or "takechar"
		if #args < 2 then
			return reply(player, "Usage: /" .. verb .. " <playerName|me> <charId|all>", false)
		end
		local target = findPlayer(player, args[1])
		if not target then
			return reply(player, "Unknown player: " .. tostring(args[1]), false)
		end
		if string.lower(args[2]) == "all" then
			if call(player, "UnlockService", give and "giveAll" or "takeAll", target) then
				reply(player, (give and "Gave ALL characters to " or "Removed all paid characters from ") .. target.Name)
				pushOwned(player)
			end
			return
		end
		local id = resolve(args[2], lists().characters)
		if not id then
			return reply(player, "Unknown character: " .. tostring(args[2]), false)
		end
		local us = service("UnlockService")
		if not us then
			return reply(player, "UnlockService is not available yet", false)
		end
		local ok, res = pcall(give and us.give or us.take, target, id)
		if ok and res then
			reply(player, (give and "Gave " or "Removed ") .. id .. (give and " to " or " from ") .. target.Name)
			pushOwned(player)
		else
			reply(player, give and ("Could not give " .. id) or (id .. " is free (always owned)"), false)
		end
	end
end
COMMANDS.givechar = charCommand(true)
COMMANDS.takechar = charCommand(false)

COMMANDS.cash = function(player, args)
	local n = tonumber(args[1])
	if not n then
		return reply(player, "Usage: /cash <amount>", false)
	end
	if call(player, "SkinService", "addCash", player, n, "ADMIN") then
		reply(player, (n >= 0 and "+" or "") .. n .. " Cash")
	end
end

COMMANDS.crate = function(player, args)
	local n = math.clamp(math.floor(tonumber(args[1]) or 1), -100, 100)
	if call(player, "SkinService", "addCrates", player, n) then
		reply(player, (n >= 0 and "+" or "") .. n .. " Mystery Briefcase(s)")
	end
end

COMMANDS.allskins = function(player)
	if call(player, "SkinService", "grantAll", player) then
		reply(player, "All skins unlocked")
	end
end

COMMANDS.resetdaily = function(player, args)
	local full = string.lower(args[1] or "") == "full"
	if call(player, "DailyRewardService", "reset", player, full) then
		reply(player, full and "Daily streak wiped" or "Daily reward claimable again")
	end
end

COMMANDS.afkpay = function(player)
	local afk = service("AFKService")
	if not afk or type(afk.forcePay) ~= "function" then
		return reply(player, "AFKService is not available yet", false)
	end
	if afk.forcePay(player) then
		reply(player, "AFK payout incoming")
	else
		reply(player, "Enter the AFK Break Room first", false)
	end
end

local recent = {} -- anti-doublon chat (TextChatCommand + Chatted)
function AdminService.run(player: Player, text: string)
	if type(text) ~= "string" or not AdminService.isAdmin(player) then
		return
	end
	text = string.sub(text, 1, 120)
	if string.sub(text, 1, 1) ~= "/" then
		return
	end
	local stamp = player.UserId .. text
	if recent[stamp] and os.clock() - recent[stamp] < 0.4 then
		return
	end
	recent[stamp] = os.clock()
	local body = string.sub(text, 2)
	local parts = string.split(body, " ")
	local cmd = string.lower(table.remove(parts, 1) or "")
	local raw = string.sub(body, #cmd + 2) -- texte brut après la commande (/announce)
	local args = {}
	for _, a in ipairs(parts) do
		if a ~= "" then
			table.insert(args, a)
		end
	end
	local fn = COMMANDS[cmd]
	if fn then
		warn(("[AdminAudit] %s (%d) : %s"):format(player.Name, player.UserId, text))
		local ok, err = pcall(fn, player, args, raw)
		if not ok then
			reply(player, "Error: " .. tostring(err), false)
		end
	end
end

function AdminService.init()
	local cmdRemote = Net.get("AdminCommand")
	local infoRemote = Net.get("AdminInfo")
	cmdRemote.OnServerEvent:Connect(function(player, text)
		if AdminService.isAdmin(player) and Net.allow(player, "AdminCommand", 8) then
			AdminService.run(player, text)
		end
	end)
	infoRemote.OnServerEvent:Connect(function(player)
		if AdminService.isAdmin(player) and Net.allow(player, "AdminInfo", 2) then
			infoRemote:FireClient(player, lists())
		end
	end)

	local function onPlayer(player)
		if shuttingDown then
			player:Kick(SHUTDOWN_MSG)
			return
		end
		if AdminService.isAdmin(player) then
			player:SetAttribute("IsAdmin", true)
		end
		task.spawn(checkGroup, player)
		player.Chatted:Connect(function(msg)
			AdminService.run(player, msg)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in ipairs(Players:GetPlayers()) do
		onPlayer(p)
	end

	-- TextChatService : commandes « / » déclarées pour qu'elles ne s'affichent pas dans le chat
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local folder = TextChatService:FindFirstChild("TextChatCommands") or Instance.new("Folder")
		folder.Name = "TextChatCommands"
		folder.Parent = TextChatService
		for name in pairs(COMMANDS) do
			local c = Instance.new("TextChatCommand")
			c.Name = "OB_" .. name
			c.PrimaryAlias = "/" .. name
			c.Parent = folder
			c.Triggered:Connect(function(source, text)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					AdminService.run(player, text)
				end
			end)
		end
	end
end

return AdminService
