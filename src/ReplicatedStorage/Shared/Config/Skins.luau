--[[
	Skins — tenues des personnages (cosmétique uniquement).
	- Chaque perso de Config/Characters.Order reçoit automatiquement un skin "Base" (uniforme gratuit).
	- Les skins Rare / Epic / Legendary viennent de Config/SkinList (entrées invalides ignorées avec un warn).
	- "Avatar" = l'avatar Roblox du joueur (choix par défaut).
	API : Skins.List[id], Skins.ByCharacter[charId] (trié par rareté), Skins.get(id), Skins.baseId(charId),
	      Skins.isValid(id), Skins.Rarities, Skins.Crate, Skins.Earn, Skins.Products, Skins.productById(productId)
	Caisses : Skins.Crates (ordre d'affichage), Skins.CrateById[id], Skins.getCrate(id?) (nil => "Briefcase"),
	          crate.Odds = {Rare, Epic, Legendary} (somme 100, Legendary <= 5 vérifié au chargement),
	          crate.Pool = nil (tous) | {charId...}, crate.SkinPool = {Rare={ids}, Epic={ids}, Legendary={ids}} (calculé).
	          Skins.Crate = alias de la Mystery Briefcase.
]]
local Characters = require(script.Parent.Characters)

local Skins = {}

Skins.AVATAR = "Avatar"

Skins.Rarities = {
	Order = { "Base", "Rare", "Epic", "Legendary" },
	Base = { Color = Color3.fromRGB(170, 170, 170), Weight = 0, Label = "BASE" },
	Rare = { Color = Color3.fromRGB(60, 140, 255), Weight = 70, Label = "RARE" },
	Epic = { Color = Color3.fromRGB(170, 70, 255), Weight = 25, Label = "EPIC" },
	Legendary = { Color = Color3.fromRGB(255, 190, 30), Weight = 5, Label = "LEGENDARY" },
}

local REFUND = { Rare = 60, Epic = 150, Legendary = 400 }

-- Caisses de skins (décision du joueur : prix et chances différents, Legendary JAMAIS au-dessus de 5 %)
-- Odds = poids par rareté (somme 100). Pool = nil (tous les persos) ou liste de persos.
-- Shape = indice pour le dessin de l'UI : "Box" | "Briefcase" | "Crate" | "Safe"
Skins.Crates = {
	{ Id = "SupplyBox", Name = "Office Supply Box", Price = 150, Shape = "Box",
	  Color = Color3.fromRGB(214, 165, 100), Accent = Color3.fromRGB(150, 105, 55),
	  Desc = "A cheap cardboard box from the supply closet. Mostly Rares.",
	  Odds = { Rare = 85, Epic = 14, Legendary = 1 }, Pool = nil, Refund = REFUND },
	{ Id = "Briefcase", Name = "Mystery Briefcase", Price = 300, Shape = "Briefcase",
	  Color = Color3.fromRGB(70, 130, 255), Accent = Color3.fromRGB(255, 205, 60),
	  Desc = "The classic. Any skin from any coworker.",
	  Odds = { Rare = 70, Epic = 25, Legendary = 5 }, Pool = nil, Refund = REFUND },
	{ Id = "BreakRoom", Name = "Break Room Crate", Price = 400, Shape = "Crate",
	  Color = Color3.fromRGB(255, 140, 50), Accent = Color3.fromRGB(255, 230, 120),
	  Desc = "Smells like burnt coffee. Break room staff only.",
	  Odds = { Rare = 65, Epic = 30, Legendary = 5 }, Pool = { "LunchLady", "Barista", "Janitor", "FitnessCoach" }, Refund = REFUND },
	{ Id = "TechCrate", Name = "Server Room Crate", Price = 400, Shape = "Crate",
	  Color = Color3.fromRGB(40, 210, 160), Accent = Color3.fromRGB(30, 60, 70),
	  Desc = "Still warm from the servers. Tech and building crew.",
	  Odds = { Rare = 65, Epic = 30, Legendary = 5 }, Pool = { "ITGuy", "MaintenanceGuy", "SecurityGuard", "DeliveryGuy" }, Refund = REFUND },
	{ Id = "Corporate", Name = "Boardroom Crate", Price = 400, Shape = "Crate",
	  Color = Color3.fromRGB(225, 55, 75), Accent = Color3.fromRGB(255, 215, 90),
	  Desc = "Signed in triplicate. Management only.",
	  Odds = { Rare = 65, Epic = 30, Legendary = 5 }, Pool = { "CEO", "Accountant", "Lawyer", "HRManager" }, Refund = REFUND },
	{ Id = "FrontDesk", Name = "Front Desk Crate", Price = 400, Shape = "Crate",
	  Color = Color3.fromRGB(255, 100, 190), Accent = Color3.fromRGB(255, 240, 250),
	  Desc = "Left at reception, no name on it. Front-of-house crew.",
	  Odds = { Rare = 65, Epic = 30, Legendary = 5 }, Pool = { "Receptionist", "MarketingGuru", "Mascot", "Intern" }, Refund = REFUND },
	{ Id = "ExecSafe", Name = "Executive Safe", Price = 800, Shape = "Safe",
	  Color = Color3.fromRGB(150, 70, 255), Accent = Color3.fromRGB(255, 200, 40),
	  Desc = "The CEO's private safe. Epic guaranteed!",
	  Odds = { Rare = 0, Epic = 95, Legendary = 5 }, Pool = nil, Refund = REFUND },
}
Skins.CrateById = {}
for i, c in ipairs(Skins.Crates) do
	-- validation : Legendary <= 5 % et somme des poids = 100
	assert(type(c.Id) == "string" and not Skins.CrateById[c.Id], "[Skins] crate #" .. i .. " : Id manquant ou en double")
	local o = c.Odds
	assert(type(o) == "table", "[Skins] crate " .. c.Id .. " : Odds manquant")
	local sum = (o.Rare or 0) + (o.Epic or 0) + (o.Legendary or 0)
	assert((o.Legendary or 0) <= 5, "[Skins] crate " .. c.Id .. " : Legendary > 5 %")
	assert(math.abs(sum - 100) < 1e-6, "[Skins] crate " .. c.Id .. " : la somme des poids doit faire 100 (" .. sum .. ")")
	assert(type(c.Price) == "number" and c.Price > 0, "[Skins] crate " .. c.Id .. " : Price invalide")
	c.Order = i
	Skins.CrateById[c.Id] = c
end
Skins.DEFAULT_CRATE = "Briefcase"
Skins.Crate = Skins.CrateById.Briefcase -- alias de compatibilité (Name, Price, Refund)

function Skins.getCrate(id)
	if id == nil then
		id = Skins.DEFAULT_CRATE
	end
	return type(id) == "string" and Skins.CrateById[id] or nil
end

Skins.Earn = { KO = 30, Per100Damage = 10, SurviveCollapse = 15, Task = 50, GradeUp = 150 }

-- Produits développeur Robux (ProductId 0 = pas encore créé sur le site => "COMING SOON")
Skins.Products = {
	{ Id = "Cash500", Name = "Stack of Cash", Cash = 500, Robux = 49, ProductId = 0 },
	{ Id = "Cash1500", Name = "Briefcase of Cash", Cash = 1500, Robux = 129, ProductId = 0 },
	{ Id = "Cash5000", Name = "Vault of Cash", Cash = 5000, Robux = 399, ProductId = 0 },
	{ Id = "Crate1", Name = "1 Mystery Briefcase", Crates = 1, Robux = 35, ProductId = 0 },
	{ Id = "Crate5", Name = "5 Mystery Briefcases", Crates = 5, Robux = 149, ProductId = 0 },
}

Skins.List = {}
Skins.ByCharacter = {}

local rarityIndex = {}
for i, r in ipairs(Skins.Rarities.Order) do
	rarityIndex[r] = i
end
Skins.rarityIndex = rarityIndex

function Skins.baseId(charId: string): string
	return charId .. "_Base"
end

-- skins de base générés depuis Config/Characters (nouveau perso = nouveau skin Base automatiquement)
for _, charId in ipairs(Characters.Order) do
	local def = Characters[charId]
	if type(def) == "table" then
		local skin = {
			Id = Skins.baseId(charId),
			Character = charId,
			Name = "Uniform",
			Rarity = "Base",
			Desc = "The classic " .. (def.DisplayName or charId) .. " work uniform.",
			Outfit = {
				Shirt = typeof(def.Shirt) == "Color3" and def.Shirt or nil,
				Pants = typeof(def.Pants) == "Color3" and def.Pants or nil,
			},
			HideIdentity = false,
			Parts = {},
		}
		Skins.List[skin.Id] = skin
		Skins.ByCharacter[charId] = { skin }
	end
end

-- validation légère d'une entrée de SkinList
local function check(e)
	if type(e) ~= "table" then
		return "not a table"
	end
	if type(e.Id) ~= "string" or e.Id == "" then
		return "missing Id"
	end
	if Skins.List[e.Id] then
		return "duplicate Id"
	end
	if type(e.Character) ~= "string" or not Skins.ByCharacter[e.Character] then
		return "unknown Character " .. tostring(e.Character)
	end
	if e.Rarity ~= "Rare" and e.Rarity ~= "Epic" and e.Rarity ~= "Legendary" then
		return "bad Rarity " .. tostring(e.Rarity)
	end
	if e.Outfit ~= nil and type(e.Outfit) ~= "table" then
		return "Outfit must be a table"
	end
	if e.Parts ~= nil and type(e.Parts) ~= "table" then
		return "Parts must be a table"
	end
	if e.FX ~= nil and type(e.FX) ~= "table" then
		return "FX must be a table"
	end
	return nil
end

local okList, list = pcall(require, script.Parent:FindFirstChild("SkinList") or Instance.new("ModuleScript"))
if not okList then
	warn("[Skins] SkinList ne se charge pas :", list)
	list = {}
end
if type(list) ~= "table" then
	list = {}
end
for i, e in ipairs(list) do
	local err = check(e)
	if err then
		warn("[Skins] entrée SkinList #" .. i .. " ignorée (" .. tostring(type(e) == "table" and e.Id or "?") .. ") : " .. err)
	else
		e.Name = type(e.Name) == "string" and e.Name or e.Id
		e.Desc = type(e.Desc) == "string" and e.Desc or ""
		e.Outfit = e.Outfit or {}
		e.Parts = e.Parts or {}
		Skins.List[e.Id] = e
		table.insert(Skins.ByCharacter[e.Character], e)
	end
end

for _, arr in pairs(Skins.ByCharacter) do
	table.sort(arr, function(a, b)
		local ra, rb = rarityIndex[a.Rarity] or 9, rarityIndex[b.Rarity] or 9
		if ra ~= rb then
			return ra < rb
		end
		return a.Id < b.Id
	end)
end

-- skins tirables dans la mallette, rangés par rareté
Skins.Pool = { Rare = {}, Epic = {}, Legendary = {} }
for id, s in pairs(Skins.List) do
	if Skins.Pool[s.Rarity] then
		table.insert(Skins.Pool[s.Rarity], id)
	end
end
for _, arr in pairs(Skins.Pool) do
	table.sort(arr)
end

-- pool de chaque caisse, par rareté (ids triés) : persos de crate.Pool, ou tous si nil
for _, c in ipairs(Skins.Crates) do
	local allowed
	if c.Pool then
		allowed = {}
		for _, charId in ipairs(c.Pool) do
			if not Skins.ByCharacter[charId] then
				warn("[Skins] crate " .. c.Id .. " : perso inconnu " .. tostring(charId))
			end
			allowed[charId] = true
		end
	end
	c.SkinPool = { Rare = {}, Epic = {}, Legendary = {} }
	for r, ids in pairs(Skins.Pool) do
		for _, id in ipairs(ids) do
			if not allowed or allowed[Skins.List[id].Character] then
				table.insert(c.SkinPool[r], id)
			end
		end
	end
end

function Skins.get(id)
	return type(id) == "string" and Skins.List[id] or nil
end

function Skins.isValid(id)
	return id == Skins.AVATAR or Skins.get(id) ~= nil
end

function Skins.productById(productId)
	for _, p in ipairs(Skins.Products) do
		if p.ProductId ~= 0 and p.ProductId == productId then
			return p
		end
	end
	return nil
end

function Skins.productByKey(key)
	for _, p in ipairs(Skins.Products) do
		if p.Id == key then
			return p
		end
	end
	return nil
end

return Skins
