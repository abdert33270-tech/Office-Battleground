--[[
	Words — onomatopées BD par catégorie de coup + couleurs.
	La catégorie vient de la fiche de l'attaque ; un objet peut fournir sa propre liste (Use.Words).
	Les mots sont affichés par ReplicatedStorage.Shared.Modules.ComicWords (autocollants BD) ;
	la catégorie choisit la forme de la bulle (CategoryShapes) et la palette (CategoryPalettes).
]]
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

return {
	Light = { "POW!", "BAP!", "WHAP!", "SMACK!", "BIFF!", "THWIP!", "OOF!", "SOCK!", "BOP!", "WHACK!", "SLAP!", "THWAP!" },
	Heavy = { "BONK!", "WHAM!", "KABOOM!", "CRASH!", "BOOM!", "KRAK!", "THOOM!", "BANG!", "KAPOW!", "BLAM!", "WHOMP!" },
	Break = { "CRUNCH!", "SMASH!", "CRACK!", "SHATTER!", "KRUNCH!", "SNAP!", "CRASH!" },
	Projectile = { "THWACK!", "ZING!", "WHIZZ!", "THUNK!", "PLINK!", "FWIP!", "BONK!" },
	Splat = { "SPLAT!", "SPLOOSH!", "SQUISH!", "GLOOP!", "SPLORT!", "SQUELCH!" },
	Parry = { "CLANG!", "TING!", "NOPE!", "KLANG!", "SHING!", "DENIED!" },
	Land = { "THUD!", "WHUMP!", "THUMP!", "FLOMP!", "KA-THUD!" },
	KO = { "K.O.!", "FIRED!", "BOOM!", "KNOCKOUT!", "TIMBER!" },
	Electric = { "ZAP!", "BZZT!", "ZZAP!", "KZZT!", "FZZT!" },
	Air = { "WHOOSH!", "BOING!", "YEET!", "SWOOSH!", "ZOOM!", "FWOOSH!" },
	Funny = { "OOPS!", "OMG!", "WOW!", "YEAH!", "NO!", "OK!", "COOL!", "YES!", "SUPER!", "HELLO!" },

	-- couleur du texte selon la puissance (0 = faible, 1 = fort) — ancien affichage (CartoonFX.wordLegacy)
	TextColors = {
		rgb(255, 240, 70), -- jaune
		rgb(255, 170, 40), -- orange
		rgb(255, 70, 50), -- rouge
	},
	-- couleurs de l'étoile d'explosion derrière le mot (ancien affichage)
	BurstColors = {
		rgb(255, 255, 255),
		rgb(110, 210, 255),
		rgb(255, 120, 200),
		rgb(130, 255, 140),
	},
	CategoryBurst = {
		Break = rgb(255, 200, 80),
		Splat = rgb(150, 90, 50),
		KO = rgb(255, 50, 50),
		Parry = rgb(200, 220, 255),
	},
	Font = Enum.Font.LuckiestGuy,

	------------------------------------------------------------------
	-- Autocollants BD (ComicWords)
	------------------------------------------------------------------
	-- polices tirées au hasard pour chaque mot (le K.O. utilise toujours LuckiestGuy)
	ComicFonts = { Enum.Font.Bangers, Enum.Font.Bangers, Enum.Font.LuckiestGuy },

	-- Bubble = dégradé de la bulle (haut -> bas), Text = dégradé du texte (haut -> bas)
	Palettes = {
		{ Name = "Sunny", Bubble = { rgb(255, 238, 70), rgb(255, 170, 25) }, Text = { rgb(255, 95, 70), rgb(205, 20, 45) } },
		{ Name = "Sky", Bubble = { rgb(120, 228, 255), rgb(30, 135, 250) }, Text = { rgb(255, 250, 120), rgb(255, 165, 30) } },
		{ Name = "Bubblegum", Bubble = { rgb(255, 150, 215), rgb(225, 55, 170) }, Text = { rgb(255, 255, 255), rgb(255, 225, 80) } },
		{ Name = "Lime", Bubble = { rgb(180, 252, 95), rgb(55, 185, 70) }, Text = { rgb(255, 125, 220), rgb(185, 35, 200) } },
		{ Name = "Tangerine", Bubble = { rgb(255, 190, 70), rgb(255, 100, 25) }, Text = { rgb(130, 238, 255), rgb(40, 115, 255) } },
		{ Name = "Grape", Bubble = { rgb(190, 140, 255), rgb(115, 55, 230) }, Text = { rgb(255, 250, 115), rgb(255, 160, 30) } },
		{ Name = "Cherry", Bubble = { rgb(255, 100, 85), rgb(210, 25, 50) }, Text = { rgb(255, 255, 160), rgb(255, 195, 40) } },
		{ Name = "Snow", Bubble = { rgb(255, 255, 255), rgb(205, 222, 255) }, Text = { rgb(70, 195, 255), rgb(30, 75, 230) } },
		{ Name = "Mint", Bubble = { rgb(140, 255, 215), rgb(25, 195, 165) }, Text = { rgb(255, 110, 150), rgb(215, 25, 90) } },
	},
	-- K.O. : toujours gros, rouge / blanc / jaune
	KOPalette = {
		Name = "KO",
		Bubble = { rgb(255, 75, 60), rgb(195, 15, 40) },
		Text = { rgb(255, 255, 255), rgb(255, 232, 90) },
		Rim = rgb(255, 225, 50),
		Dots = rgb(255, 220, 60),
	},
	-- palettes préférées par catégorie (70 % du temps), sinon palette au hasard
	CategoryPalettes = {
		Heavy = { "Sunny", "Cherry", "Grape", "Tangerine" },
		Break = { "Tangerine", "Sunny", "Snow" },
		Splat = { "Lime", "Grape", "Bubblegum", "Mint" },
		Parry = { "Sky", "Snow", "Mint" },
		Electric = { "Sky", "Grape", "Sunny" },
		Air = { "Snow", "Sky", "Mint" },
		Land = { "Tangerine", "Snow", "Sunny" },
	},
	-- formes de bulle par catégorie (poids) :
	-- Star = étoile d'explosion, Bang = explosion à longues pointes, Cloud = nuage « POOF »,
	-- Speech = bulle ronde, Banner = bandeau penché, Zigzag = badge électrique, Plain = mot seul + étoiles
	CategoryShapes = {
		Light = { Star = 40, Speech = 30, Plain = 15, Banner = 15 },
		Heavy = { Bang = 55, Star = 35, Cloud = 10 },
		Break = { Cloud = 55, Bang = 45 },
		Splat = { Cloud = 65, Speech = 15, Plain = 20 },
		Parry = { Speech = 40, Banner = 45, Zigzag = 15 },
		Projectile = { Banner = 30, Star = 30, Plain = 25, Speech = 15 },
		Land = { Cloud = 50, Banner = 25, Bang = 25 },
		Electric = { Zigzag = 85, Bang = 15 },
		Air = { Plain = 35, Cloud = 30, Banner = 35 },
		Funny = { Speech = 35, Banner = 25, Star = 20, Cloud = 20 },
		KO = { Bang = 100 },
		Default = { Star = 20, Bang = 15, Cloud = 15, Speech = 15, Banner = 15, Zigzag = 5, Plain = 15 },
	},
}
