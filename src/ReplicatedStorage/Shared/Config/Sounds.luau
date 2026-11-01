--[[
	Sounds — sons publics du Creator Store (vérifiés : ils se chargent).
	Chaque clé = liste d'IDs ; on en tire un au hasard + hauteur/volume légèrement aléatoires.
]]
local Sounds = {
	Punch = { "rbxassetid://139795256698131", "rbxassetid://109316755832781" },
	PunchHeavy = { "rbxassetid://127429272097426", "rbxassetid://137499859855978" },
	Bonk = { "rbxassetid://132937320140224", "rbxassetid://122682383632262" },
	Whoosh = { "rbxassetid://137081214744553", "rbxassetid://138890894929151" },
	Crash = { "rbxassetid://9120957636", "rbxassetid://97870330505207" },
	WoodBreak = { "rbxassetid://104568144438070", "rbxassetid://6629890936" },
	MetalHit = { "rbxassetid://9119072660", "rbxassetid://9116524438" },
	PlasticHit = { "rbxassetid://9117458008", "rbxassetid://9119637082" },
	Splat = { "rbxassetid://90416226721742", "rbxassetid://87295773843957" },
	SlideWhistle = { "rbxassetid://97197794979302", "rbxassetid://9119197913" },
	Ding = { "rbxassetid://9126073001", "rbxassetid://107978604605265" },
	Boing = { "rbxassetid://131916027000817", "rbxassetid://2772396665" },
	Thud = { "rbxassetid://9113480915", "rbxassetid://74880966299019" },
	Pickup = { "rbxassetid://9113263454", "rbxassetid://9118833449" },
	Throw = { "rbxassetid://120706760824134", "rbxassetid://129467477219437" },
	KO = { "rbxassetid://1093200386" },
	Squeak = { "rbxassetid://9125994570", "rbxassetid://129088013422694" },	-- lot 2 (gros impacts, mécaniques de combat, ambiance)
	Oof = { "rbxassetid://79348298352567", "rbxassetid://7672649705" },
	BigImpact = { "rbxassetid://82235785832022", "rbxassetid://138232937818879" },
	AnimeHit = { "rbxassetid://8789851536" },
	Explosion = { "rbxassetid://9125616655", "rbxassetid://74149238738530" },
	GlassBreak = { "rbxassetid://139826391278483", "rbxassetid://118987440163311" },
	Clang = { "rbxassetid://9119072660", "rbxassetid://9119072674" },
	Block = { "rbxassetid://80809123525734", "rbxassetid://72616318807516" },
	Parry = { "rbxassetid://140506552189589", "rbxassetid://137580087669661" },
	Dash = { "rbxassetid://136934236721060" },
	Uppercut = { "rbxassetid://124837936201770", "rbxassetid://130806684872330" },
	GroundSlam = { "rbxassetid://97522871949213", "rbxassetid://81133751975280" },
	WallSplat = { "rbxassetid://9120957636", "rbxassetid://97870330505207" },
	PowerUp = { "rbxassetid://3406813517", "rbxassetid://131677760492710" },
	Siren = { "rbxassetid://127714289075929", "rbxassetid://123701789907032" },
	Whistle = { "rbxassetid://9117261163", "rbxassetid://9118114334" },
	Rumble = { "rbxassetid://9112775165", "rbxassetid://9112775181" },
	Crumble = { "rbxassetid://98198697429095", "rbxassetid://102760501381978" },
	Alarm = { "rbxassetid://130120948912994", "rbxassetid://18682406265" },
	Combo = { "rbxassetid://137117829572972", "rbxassetid://90802128572840" },
	Eat = { "rbxassetid://3043029786", "rbxassetid://95814274264109" },
	Water = { "rbxassetid://126105529228330", "rbxassetid://128701355933535" },
	Spray = { "rbxassetid://9114437231", "rbxassetid://9114437277" },
	Electric = { "rbxassetid://9114277757", "rbxassetid://97096310054904" },
	Slip = { "rbxassetid://129432532096499", "rbxassetid://4390298761" },
	LevelUp = { "rbxassetid://112485797063762", "rbxassetid://3120909354" },
	UIClick = { "rbxassetid://116080744084010", "rbxassetid://88442833509532" },
}

-- son d'impact selon la matière de l'objet
Sounds.MaterialHit = { Wood = "Bonk", Metal = "MetalHit", Plastic = "PlasticHit", Ceramic = "PlasticHit", Glass = "Crash", Rubber = "Boing", Food = "Splat" }
-- son de casse selon la matière
Sounds.MaterialBreak = { Wood = "WoodBreak", Metal = "Crash", Plastic = "Crash", Ceramic = "Crash", Glass = "Crash", Rubber = "Boing", Food = "Splat" }
-- son de base selon la catégorie de coup
Sounds.Category = { Light = "Punch", Heavy = "PunchHeavy", Projectile = "Punch", Splat = "Splat", Parry = "Parry", Land = "Thud" }

return Sounds
