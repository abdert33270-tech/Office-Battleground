--[[
	FarmGuard — anti-farm des récompenses de combat (XP + Cash), côté serveur. Voir docs/Serveur-securite.md.
	- K.O. répétés : même paire tueur -> victime, plus de MaxPairKOs K.O. sur PairWindow s => K.O. à 0 récompense
	  (ni XP, ni Cash, ni compteur KOs) pour CETTE paire. Les autres victimes rapportent normalement.
	- Victime passive (alt / AFK) : pas d'XP ni de Cash de dégâts contre un joueur qui n'a infligé AUCUN dégât
	  à un autre joueur depuis IdleWindow s.
	API (appelée par DataService et SkinService, les deux reçoivent la même réponse pour une même mort) :
		FarmGuard.koRewarded(killerModel, victimModel) -> bool   (mémorisé par modèle de victime : compté une fois)
		FarmGuard.damageRewarded(attackerPlayer, victimPlayer) -> bool
		FarmGuard.noteDamage(attackerPlayer) : appelé par Signals.Hit (branché dans init)
	Le module se branche lui-même sur Signals.Hit (init, Priority 59 : avant DataService).
]]
local Players = game:GetService("Players")

local Signals = require(script.Parent.Signals)

local FarmGuard = {}
FarmGuard.Priority = 59

FarmGuard.MaxPairKOs = 3 -- au-delà (4e K.O. et suivants) : 0 récompense
FarmGuard.PairWindow = 600 -- 10 min
FarmGuard.IdleWindow = 60

local pairKOs = {} -- ["killerId:victimId"] = { os.clock(), ... }
local lastDamage = {} -- [UserId] = os.clock() du dernier dégât infligé à un autre joueur
local koVerdict = setmetatable({}, { __mode = "k" }) -- [victimModel] = bool (même verdict pour tous les services)

local function playerOf(model)
	if typeof(model) ~= "Instance" then
		return nil
	end
	if model:IsA("Player") then
		return model
	end
	return Players:GetPlayerFromCharacter(model)
end

function FarmGuard.noteDamage(attacker: Player)
	if attacker then
		lastDamage[attacker.UserId] = os.clock()
	end
end

-- dégâts sur un joueur : récompensés seulement si la victime s'est battue (dégâts infligés) récemment
function FarmGuard.damageRewarded(attacker: Player?, victim: Player?): boolean
	if not attacker or not victim or attacker == victim then
		return false
	end
	local t = lastDamage[victim.UserId]
	return t ~= nil and os.clock() - t <= FarmGuard.IdleWindow
end

-- K.O. d'un joueur par un joueur : compté UNE fois par mort (modèle de la victime), même verdict ensuite
function FarmGuard.koRewarded(killerModel, victimModel): boolean
	local killer, victim = playerOf(killerModel), playerOf(victimModel)
	if not killer or not victim or killer == victim then
		return false
	end
	local cached = koVerdict[victimModel]
	if cached ~= nil then
		return cached
	end
	local k = killer.UserId .. ":" .. victim.UserId
	local list = pairKOs[k] or {}
	local t = os.clock()
	local kept = {}
	for _, x in ipairs(list) do
		if t - x < FarmGuard.PairWindow then
			table.insert(kept, x)
		end
	end
	table.insert(kept, t)
	pairKOs[k] = kept
	local ok = #kept <= FarmGuard.MaxPairKOs
	if not ok then
		warn(("[FarmGuard] K.O. répété %s -> %s (%d en %d s) : 0 récompense"):format(killer.Name, victim.Name, #kept, FarmGuard.PairWindow))
	end
	koVerdict[victimModel] = ok
	return ok
end

-- (tests) remet tout à zéro
function FarmGuard.reset()
	table.clear(pairKOs)
	table.clear(lastDamage)
end

function FarmGuard.init()
	Signals.Hit:Connect(function(attacker, victim, damage)
		local a, v = playerOf(attacker), playerOf(victim)
		if a and v and a ~= v and type(damage) == "number" and damage > 0 then
			FarmGuard.noteDamage(a)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		-- pairKOs est gardé (par UserId) : sortir / revenir ne remet pas le compteur de la paire à zéro
		lastDamage[p.UserId] = nil
	end)
	-- ménage : paires expirées
	task.spawn(function()
		while true do
			task.wait(120)
			local t = os.clock()
			for k, list in pairs(pairKOs) do
				if #list == 0 or t - list[#list] >= FarmGuard.PairWindow then
					pairKOs[k] = nil
				end
			end
		end
	end)
end

return FarmGuard
