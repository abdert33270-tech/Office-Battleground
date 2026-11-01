--[[
	Codes — codes promo (CodeService). Saisie insensible à la casse et aux espaces ; une fois par joueur.
	Champs :
		Code    = "TEXTE" (majuscules)
		Reward  = { Cash = n?, Crates = n? (Mystery Briefcases), XP = n? (XP brute, sans multiplicateur) }
		Expires = os.time() UTC de fin (nil = jamais). Ex. : os.time({ year = 2026, month = 12, day = 31, hour = 23 }) (UTC)
		MaxUses = nombre total d'utilisations tous serveurs confondus (nil = illimité ; compteur DataStore)
	Ajouter un code = ajouter une ligne ici (rien d'autre à faire).
]]
return {
	{ Code = "RELEASE", Reward = { Cash = 500 } },
	{ Code = "BACON", Reward = { Cash = 250 } },
	{ Code = "OVERTIME", Reward = { Cash = 300, Crates = 1 } },
	{ Code = "COFFEEBREAK", Reward = { Cash = 200, XP = 150 } },
	{ Code = "THANKYOU", Reward = { Cash = 750, Crates = 1 } },
}
