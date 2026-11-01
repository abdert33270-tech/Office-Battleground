--[[
	Unlocks — déblocage des personnages (Free / Cash / Robux).
	- Free  : toujours possédés.
	- Cash  : achat permanent avec le Cash du jeu (Price).
	- Robux : achat permanent via Game Pass (GamePassId ; 0 = pas encore créé sur le site => « COMING SOON »).
	          Robux = prix affiché seulement (le vrai prix se règle sur le site Roblox).
	Un perso absent de cette liste est GRATUIT (aucun perso ne devient injouable par oubli).
	Les persos Robux restent équilibrés comme les autres (jamais plus forts).
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

	-- Robux (4) : Game Pass permanent (mettre l'id du Game Pass créé sur le site à la place de 0)
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
