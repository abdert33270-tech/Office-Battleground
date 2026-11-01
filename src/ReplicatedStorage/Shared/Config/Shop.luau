--[[
	Shop — fiches de la boutique (cosmétiques Robux, aucun pay-to-win).
	BOUTIQUE HONNÊTE : une fiche n'est affichée QUE si son ProductId (produit développeur créé sur le site) est ~= 0.
	Aucune section « SOON » / « COMING SOON » n'est jamais montrée (Shop.isHiddenSection).
	Ce qui est toujours affiché (jamais vide) : portefeuille (Cash, mallettes gratuites, persos débloqués),
	JOBS (déblocage des persos -> écran de sélection), caisses de skins payées en Cash (Config/Skins.Crates).
	Les offres Robux de Cash / mallettes sont dans Config/Skins.Products (même règle ProductId ~= 0).
	TODO propriétaire : créer le produit sur le site, copier son id dans ProductId ; aucun autre code à toucher
	(l'achat des cosmétiques n'est pas encore branché côté serveur : laisser 0 tant que ce n'est pas le cas).
	API : Shop.isLive(entry) -> bool | Shop.liveItems() -> liste | Shop.isHiddenSection(nom) -> bool
]]
local Shop = {}

Shop.Categories = { "Item Skins", "KO Effects", "Emotes", "Packs" }
Shop.Items = {
	{ Id = "GoldenChair", Name = "Golden Chair", Category = "Item Skins", Price = 149, ProductId = 0, Color = Color3.fromRGB(255, 210, 40) },
	{ Id = "RainbowStapler", Name = "Rainbow Stapler", Category = "Item Skins", Price = 99, ProductId = 0, Color = Color3.fromRGB(255, 90, 200) },
	{ Id = "NeonExtinguisher", Name = "Neon Fire Extinguisher", Category = "Item Skins", Price = 129, ProductId = 0, Color = Color3.fromRGB(90, 255, 140) },
	{ Id = "Confetti", Name = "Confetti K.O.", Category = "KO Effects", Price = 79, ProductId = 0, Color = Color3.fromRGB(255, 170, 60) },
	{ Id = "PaperStorm", Name = "Paper Storm K.O.", Category = "KO Effects", Price = 79, ProductId = 0, Color = Color3.fromRGB(240, 240, 240) },
	{ Id = "FiredStamp", Name = "Giant FIRED! Stamp", Category = "KO Effects", Price = 129, ProductId = 0, Color = Color3.fromRGB(255, 60, 60) },
	{ Id = "CoffeeBreak", Name = "Coffee Break Emote", Category = "Emotes", Price = 49, ProductId = 0, Color = Color3.fromRGB(150, 90, 50) },
	{ Id = "SpinChair", Name = "Office Chair Spin Emote", Category = "Emotes", Price = 49, ProductId = 0, Color = Color3.fromRGB(80, 140, 255) },
	{ Id = "StarterPack", Name = "Starter Pack", Category = "Packs", Price = 99, ProductId = 0, Color = Color3.fromRGB(255, 215, 40), Desc = "1 costume + 1 KO effect" },
}

-- vendable pour de vrai : produit créé sur le site
function Shop.isLive(entry): boolean
	return type(entry) == "table" and (tonumber(entry.ProductId) or 0) ~= 0
end

function Shop.liveItems()
	local out = {}
	for _, it in ipairs(Shop.Items) do
		if Shop.isLive(it) then
			table.insert(out, it)
		end
	end
	return out
end

function Shop.isHiddenSection(name: string?): boolean
	local n = string.upper(tostring(name or ""))
	return string.find(n, "SOON", 1, true) ~= nil
end

return Shop
