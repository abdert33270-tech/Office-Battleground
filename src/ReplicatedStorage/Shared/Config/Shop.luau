--[[
	Shop — squelette de la boutique (aucun achat réel pour l'instant, aucun pay-to-win).
	Plus tard : ProductId / GamePassId sur chaque fiche.
]]
return {
	Categories = { "Item Skins", "KO Effects", "Emotes", "Packs" },
	Items = {
		{ Id = "GoldenChair", Name = "Golden Chair", Category = "Item Skins", Price = 149, Color = Color3.fromRGB(255, 210, 40) },
		{ Id = "RainbowStapler", Name = "Rainbow Stapler", Category = "Item Skins", Price = 99, Color = Color3.fromRGB(255, 90, 200) },
		{ Id = "NeonExtinguisher", Name = "Neon Fire Extinguisher", Category = "Item Skins", Price = 129, Color = Color3.fromRGB(90, 255, 140) },
		{ Id = "Confetti", Name = "Confetti K.O.", Category = "KO Effects", Price = 79, Color = Color3.fromRGB(255, 170, 60) },
		{ Id = "PaperStorm", Name = "Paper Storm K.O.", Category = "KO Effects", Price = 79, Color = Color3.fromRGB(240, 240, 240) },
		{ Id = "FiredStamp", Name = "Giant FIRED! Stamp", Category = "KO Effects", Price = 129, Color = Color3.fromRGB(255, 60, 60) },
		{ Id = "CoffeeBreak", Name = "Coffee Break Emote", Category = "Emotes", Price = 49, Color = Color3.fromRGB(150, 90, 50) },
		{ Id = "SpinChair", Name = "Office Chair Spin Emote", Category = "Emotes", Price = 49, Color = Color3.fromRGB(80, 140, 255) },
		{ Id = "StarterPack", Name = "Starter Pack", Category = "Packs", Price = 99, Color = Color3.fromRGB(255, 215, 40), Desc = "1 costume + 1 KO effect" },
	},
}
