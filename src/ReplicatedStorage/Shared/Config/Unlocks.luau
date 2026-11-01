--[[
	Unlocks — déblocage des personnages (Free / Cash / Robux).
	- Free  : toujours possédés.
	- Cash  : achat permanent avec le Cash du jeu (Price).
	- Robux : achat permanent via Game Pass (GamePassId ; 0 = pas encore créé sur le site => « COMING SOON »).
	          Robux = prix affiché seulement (le vrai prix se règle sur le site Roblox).
	Un perso absent de cette liste est GRATUIT (aucun perso ne devient injouable par oubli).
	Les persos Robux restent équilibrés comme les autres (jamais plus forts), SAUF The Bacon : perso phare voulu
	par le propriétaire comme le plus cher ET le plus fort du jeu (passif Main Character), sans aucun skin.
	TODO PROPRIÉTAIRE (Game Pass) — tant que GamePassId = 0, le menu affiche le prix (« R$ 499 » pour The Bacon)
	mais le bouton reste « COMING SOON ». Pour ouvrir la vente :
	  1) create.roblox.com > l'expérience > Monetization > Passes > Create a Pass (ex. « The Bacon », image du perso) ;
	  2) mettre le pass en vente au prix voulu (The Bacon : 499 Robux ; garder `Robux` ci-dessous identique au prix réel) ;
	  3) copier l'id du pass (nombre dans l'URL) dans `GamePassId` de l'entrée correspondante (Bacon = { ... GamePassId = <id> }).
	  Même chose pour OfficeCat / AIAssistant / CEO / Mascot. Aucun autre code à toucher (UnlockService lit GamePassId).
	API : Unlocks.get(id) -> entrée {Tier, Price?, GamePassId?, Robux?}
	      Unlocks.isFree(id) | Unlocks.priceText(id) -> "FREE" | "$2,500" | "R$ 299" | Unlocks.byGamePass(passId) -> id
]]
local Unlocks = {}

Unlocks.DEFAULT = "Intern"

Unlocks.List = {
	-- Free (4)
	Intern = { Tier = "Free" },
	Janitor = { Tier = "Free" },
	LunchLady = { Tier = "Free" },
	SecurityGuard = { Tier = "Free" },

	-- Cash (12)
	ITGuy = { Tier = "Cash", Price = 1500 },
	Accountant = { Tier = "Cash", Price = 1500 },
	HRManager = { Tier = "Cash", Price = 2000 },
	Barista = { Tier = "Cash", Price = 2000 },
	DeliveryGuy = { Tier = "Cash", Price = 2500 },
	Receptionist = { Tier = "Cash", Price = 2500 },
	FitnessCoach = { Tier = "Cash", Price = 3000 },
	MaintenanceGuy = { Tier = "Cash", Price = 3000 },
	MarketingGuru = { Tier = "Cash", Price = 3500 },
	Lawyer = { Tier = "Cash", Price = 4000 },
	Temp = { Tier = "Cash", Price = 5000 },
	Consultant = { Tier = "Cash", Price = 5000 },

	-- Robux (5) : Game Pass permanent (mettre l'id du Game Pass créé sur le site à la place de 0)
	Bacon = { Tier = "Robux", GamePassId = 0, Robux = 499 }, -- perso phare : le plus cher et le plus fort (TODO propriétaire : id du Game Pass, voir en-tête)
	OfficeCat = { Tier = "Robux", GamePassId = 0, Robux = 299 },
	AIAssistant = { Tier = "Robux", GamePassId = 0, Robux = 299 },
	CEO = { Tier = "Robux", GamePassId = 0, Robux = 249 },
	Mascot = { Tier = "Robux", GamePassId = 0, Robux = 199 },
}

local FREE = { Tier = "Free" }

function Unlocks.get(id)
	return Unlocks.List[id or ""] or FREE
end

function Unlocks.isFree(id)
	return Unlocks.get(id).Tier == "Free"
end

local function commas(n)
	local s = tostring(math.floor(math.abs(tonumber(n) or 0)))
	local out = ""
	while #s > 3 do
		out = "," .. string.sub(s, -3) .. out
		s = string.sub(s, 1, -4)
	end
	return s .. out
end
Unlocks.commas = commas

function Unlocks.priceText(id)
	local e = Unlocks.get(id)
	if e.Tier == "Cash" then
		return "$" .. commas(e.Price or 0)
	elseif e.Tier == "Robux" then
		return "R$ " .. commas(e.Robux or 0)
	end
	return "FREE"
end

function Unlocks.byGamePass(passId)
	if type(passId) ~= "number" or passId == 0 then
		return nil
	end
	for id, e in pairs(Unlocks.List) do
		if e.Tier == "Robux" and e.GamePassId == passId then
			return id
		end
	end
	return nil
end

return Unlocks
