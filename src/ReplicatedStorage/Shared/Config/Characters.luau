--[[
	Characters — fiche de chaque personnage (affichage + kit).
	Les attaques sont des IDs de Config/Attacks (logique et valeurs là-bas).
	Ajouter un personnage = ajouter une fiche ici + ses attaques dans Attacks + son nom dans Order.
]]
local Characters = {
	Order = { "Intern", "Janitor", "LunchLady", "SecurityGuard" },

	Intern = {
		DisplayName = "The Intern",
		Role = "Fast & fragile",
		Color = Color3.fromRGB(255, 170, 40),
		Shirt = Color3.fromRGB(255, 255, 255), Pants = Color3.fromRGB(70, 90, 140), Tie = Color3.fromRGB(255, 140, 0),
		Passive = { Name = "Caffeine Addict", Desc = "Coffee Mugs give +30% speed for 5s. Throws fly 25% farther. Carries Heavy items without slowing down." },
		Attacks = { "CoffeeRun", "PaperJam", "StickySlap" },
		Transformation = { Name = "Monday Rush", Desc = "Red eyes, shaky caffeine aura, more speed.", Duration = 20, SpeedMultiplier = 1.3 },
		TransAttacks = { "EspressoCounter", "OvertimeFlurry", "DeadlineDrop" },
	},

	Janitor = {
		DisplayName = "The Janitor",
		Role = "Zone control",
		Color = Color3.fromRGB(80, 170, 255),
		Shirt = Color3.fromRGB(70, 120, 200), Pants = Color3.fromRGB(40, 60, 110), Tie = Color3.fromRGB(255, 220, 40),
		Passive = { Name = "Slip Proof", Desc = "Immune to slippery floors. Slides faster on any puddle." },
		Attacks = { "MopSweep", "WetFloorSign", "BucketToss" },
		Transformation = { Name = "Deep Clean", Desc = "Soap bubble aura and rubber gloves.", Duration = 20, SpeedMultiplier = 1.1 },
		TransAttacks = { "PowerWash", "SoapSlide", "BubblePrison" },
	},

	LunchLady = {
		DisplayName = "The Lunch Lady",
		Role = "Tank",
		Color = Color3.fromRGB(255, 110, 140),
		Shirt = Color3.fromRGB(255, 255, 255), Pants = Color3.fromRGB(230, 120, 150), Tie = Color3.fromRGB(255, 255, 255),
		Passive = { Name = "Second Helping", Desc = "Kitchen items deal +25% damage. Food heals her more." },
		Attacks = { "TrayGuard", "LadleBonk", "MysteryMeat" },
		Transformation = { Name = "Kitchen Nightmare", Desc = "Giant chef hat, apron, grows a little.", Duration = 20, SpeedMultiplier = 1.0 },
		TransAttacks = { "FryingPanSmash", "HotSoup", "FoodCartRush" },
	},

	SecurityGuard = {
		DisplayName = "The Security Guard",
		Role = "Grappler",
		Color = Color3.fromRGB(60, 80, 140),
		Shirt = Color3.fromRGB(60, 80, 140), Pants = Color3.fromRGB(30, 35, 50), Tie = Color3.fromRGB(20, 20, 30),
		Passive = { Name = "On Patrol", Desc = "Sees low-HP enemies through walls. Grabs go through block." },
		Attacks = { "Detain", "Flashlight", "WalkieTalkie" },
		Transformation = { Name = "Lockdown", Desc = "Cap, shoulder siren light, wailing siren.", Duration = 20, SpeedMultiplier = 1.1 },
		TransAttacks = { "WhistleBlast", "ElbowDrop", "TotalLockdown" },
	},
}

-- personnages ajoutés par les modules de Content (un module = un perso complet)
for _, def in ipairs(require(script.Parent.Parent.Modules.ContentLoader).all()) do
	if def.Character then
		Characters[def.Id] = def.Character
		if not table.find(Characters.Order, def.Id) then
			table.insert(Characters.Order, def.Id)
		end
	end
end

-- persos phares (fiche avec Featured = true, ex. The Bacon) : en TÊTE de la liste (menu de sélection, admin...)
-- Le perso par défaut reste Unlocks.DEFAULT (Intern) : rien ne suppose que Order[1] est gratuit.
do
	local featured = {}
	for _, id in ipairs(Characters.Order) do
		local def = Characters[id]
		if type(def) == "table" and def.Featured then
			table.insert(featured, id)
		end
	end
	for i = #featured, 1, -1 do
		local id = featured[i]
		local at = table.find(Characters.Order, id)
		if at then
			table.remove(Characters.Order, at)
		end
		table.insert(Characters.Order, 1, id)
	end
end

return Characters
