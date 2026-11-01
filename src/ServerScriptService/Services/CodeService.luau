--[[
	CodeService — codes promo (Config/Codes).
	- Saisie insensible à la casse ; tout sauf lettres / chiffres ASCII ignoré (espaces, espaces insécables, tirets...) ;
	  un code = une fois par joueur (data.Codes[CODE] = os.time()). Expires : valable jusqu'à cette seconde incluse.
	- Chargement DataStore raté (DataService.loadFailed) : refusé (« rejoin »), rien n'est consommé.
	- Expires (os.time UTC) et MaxUses (compteur global DataStore "OfficeBattlegrounds_CodeUses" ; repli mémoire).
	  Utilisation réservée avant la dernière vérification ; rendue (décrément) si le joueur part pendant l'attente.
	- Anti-spam : 1 essai / 1,5 s ; 6 codes invalides de suite => bloqué 60 s.
	Remote "RedeemCode" :
		client -> serveur : code (string)
		serveur -> client : { ok = bool, message = string, code = string?, reward = {Cash, Crates, XP}? }
	Messages : "Invalid code" | "Already redeemed" | "Expired" | "This code has reached its limit" | "Slow down!" ...
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local CodesConfig = require(ReplicatedStorage.Shared.Config.Codes)
local Net = require(ReplicatedStorage.Shared.Modules.Net)
local DataService = require(script.Parent.DataService)

local CodeService = {}
CodeService.Priority = 67

local ATTEMPT_GAP = 1.5
local MAX_FAILS = 6
local LOCKOUT = 60

local remote
local byCode = {}
local usesStore = nil
local localUses = {} -- repli si DataStore indisponible
local limits = {} -- [player] = { last, fails, lockedUntil, busy }

local function normalize(text)
	if type(text) ~= "string" then
		return nil
	end
	if #text > 200 then
		return nil
	end
	-- garde lettres + chiffres ASCII : enlève espaces, tabulations, retours, espaces insécables / largeur nulle
	-- (claviers mobiles, copier-coller) et ponctuation. Appliqué aussi aux codes de Config => toujours cohérent.
	text = string.upper((string.gsub(text, "[^%w]", "")))
	if text == "" or #text > 30 then
		return nil
	end
	return text
end

-- réserve une utilisation globale ; renvoie (autorisé, source) — source = "store" | "local" | nil (pas de MaxUses),
-- à passer à releaseUse si la récompense n'est finalement pas donnée
local function reserveUse(entry)
	local max = tonumber(entry.MaxUses)
	if not max then
		return true, nil
	end
	if usesStore then
		local allowed = false
		local ok, err = pcall(function()
			usesStore:UpdateAsync(entry.Code, function(old)
				local n = tonumber(old) or 0
				if n >= max then
					allowed = false
					return nil -- pas d'écriture
				end
				allowed = true
				return n + 1
			end)
		end)
		if ok then
			return allowed, allowed and "store" or nil
		end
		warn("[CodeService] compteur MaxUses indisponible :", err)
	end
	local n = localUses[entry.Code] or 0
	if n >= max then
		return false, nil
	end
	localUses[entry.Code] = n + 1
	return true, "local"
end

-- rend une utilisation réservée mais pas consommée (joueur parti pendant l'attente du DataStore, double requête)
local function releaseUse(entry, source)
	if source == "local" then
		localUses[entry.Code] = math.max(0, (localUses[entry.Code] or 1) - 1)
	elseif source == "store" and usesStore then
		task.spawn(function()
			local ok, err = pcall(function()
				usesStore:UpdateAsync(entry.Code, function(old)
					local n = tonumber(old) or 0
					if n <= 0 then
						return nil
					end
					return n - 1
				end)
			end)
			if not ok then
				warn("[CodeService] impossible de rendre une utilisation de " .. entry.Code .. " :", err)
			end
		end)
	end
end

local function grant(player, reward)
	local ok, SkinService = pcall(require, script.Parent.SkinService)
	local cash = math.floor(tonumber(reward.Cash) or 0)
	local crates = math.floor(tonumber(reward.Crates) or 0)
	local xp = math.floor(tonumber(reward.XP) or 0)
	local d = DataService.get(player)
	if cash > 0 then
		if ok and SkinService and SkinService.addCash then
			SkinService.addCash(player, cash, "CODE")
		elseif d then
			d.Cash = (d.Cash or 0) + cash
			player:SetAttribute("Cash", d.Cash)
		end
	end
	if crates > 0 then
		if ok and SkinService and SkinService.addCrates then
			SkinService.addCrates(player, crates)
		elseif d then
			d.Crates = (d.Crates or 0) + crates
			player:SetAttribute("Crates", d.Crates)
		end
	end
	if xp > 0 then
		DataService.addXP(player, xp, true)
	end
	return { Cash = cash, Crates = crates, XP = xp }
end

local function describe(r)
	local parts = {}
	if r.Cash > 0 then
		table.insert(parts, "+" .. r.Cash .. " Cash")
	end
	if r.Crates > 0 then
		table.insert(parts, "+" .. r.Crates .. " Mystery Briefcase" .. (r.Crates > 1 and "s" or ""))
	end
	if r.XP > 0 then
		table.insert(parts, "+" .. r.XP .. " XP")
	end
	return table.concat(parts, "  ")
end

-- renvoie ok, message, reward?
function CodeService.redeem(player: Player, raw)
	local code = normalize(raw)
	if not code then
		return false, "Invalid code"
	end
	local d = DataService.get(player)
	if not d then
		return false, "Your data is still loading, try again"
	end
	if DataService.loadFailed(player) then
		-- profil en mémoire seulement : la récompense et le « déjà utilisé » seraient perdus à la déconnexion
		return false, "Your progress didn't load - rejoin to redeem"
	end
	if type(d.Codes) ~= "table" then
		d.Codes = {}
	end
	local entry = byCode[code]
	if not entry then
		return false, "Invalid code"
	end
	if d.Codes[code] then
		return false, "Already redeemed"
	end
	if entry.Expires and os.time() > entry.Expires then
		return false, "Expired"
	end
	local allowed, source = reserveUse(entry)
	if not allowed then
		return false, "This code has reached its limit"
	end
	-- reserveUse a pu attendre le DataStore : si on ne donne finalement rien, l'utilisation globale est rendue
	if not player.Parent or DataService.get(player) ~= d then
		releaseUse(entry, source)
		return false, "Try again"
	end
	if d.Codes[code] then -- double requête pendant l'attente du DataStore
		releaseUse(entry, source)
		return false, "Already redeemed"
	end
	d.Codes[code] = os.time()
	local r = grant(player, entry.Reward or {})
	return true, "Code redeemed! " .. describe(r), r
end

local function onRequest(player, raw)
	local l = limits[player]
	if not l then
		l = { last = 0, fails = 0, lockedUntil = 0, busy = false }
		limits[player] = l
	end
	local now = os.clock()
	local function answer(ok, message, reward)
		if player.Parent then
			remote:FireClient(player, { ok = ok, message = message, code = normalize(raw), reward = reward })
		end
	end
	if now < l.lockedUntil then
		return answer(false, "Too many tries. Wait " .. math.ceil(l.lockedUntil - now) .. "s")
	end
	if l.busy or now - l.last < ATTEMPT_GAP then
		return answer(false, "Slow down!")
	end
	l.last = now
	l.busy = true
	local ok, okRedeem, message, reward = pcall(CodeService.redeem, player, raw)
	l.busy = false
	if not ok then
		warn("[CodeService]", okRedeem)
		return answer(false, "Something went wrong, try again")
	end
	if okRedeem then
		l.fails = 0
	elseif message == "Invalid code" then
		l.fails += 1
		if l.fails >= MAX_FAILS then
			l.fails = 0
			l.lockedUntil = now + LOCKOUT
		end
	end
	answer(okRedeem, message, reward)
end

function CodeService.init()
	for _, c in ipairs(CodesConfig) do
		local key = normalize(c.Code)
		if key then
			byCode[key] = { Code = key, Reward = c.Reward, Expires = tonumber(c.Expires), MaxUses = c.MaxUses }
		end
	end
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("OfficeBattlegrounds_CodeUses")
	end)
	usesStore = ok and store or nil

	remote = Net.get("RedeemCode")
	remote.OnServerEvent:Connect(onRequest)
	Players.PlayerRemoving:Connect(function(p)
		limits[p] = nil
	end)
end

return CodeService
