--[[
	M1Styles — styles de M1 par arme (données pures, lues par le client ET le serveur). Détails : docs/M1-Styles.md

	Résolution (Modules/M1Style) : objet tenu > arme fétiche du personnage (Signature) > Fists.
	- Chaîne de 5 M1 (+ uppercut / downslam / jongle optionnels) : style du PERSONNAGE (un objet tenu remplace le M1
	  par son propre « Use », dont l'animation et le timing restent ceux de Config/Items).
	- Traînées, arc de taillade, whoosh et effet d'impact : style de l'objet tenu s'il y en a un, sinon du personnage.

	Animations (définies dans Modules/ProcAnim, impact pile au Windup de Config/Combat.M1) : écrites pour une arme
	en main DROITE ; ProcAnim génère une version miroir « <Nom>_L » de chaque entrée de Moves, utilisée quand
	l'arme fétiche est en main gauche (Hand = "Left").

	Moves[nom] = méta d'une animation :
		Kind  : "M1" (I = index 1..5 -> Windup M1[I]) | "Up" (uppercut) | "Slam" (downslam) | "Air" (jongle)
		        | "Dash" (dash strike) | "Item" (Use d'un objet : Windup de Config/Items)
		Limb  : membre qui frappe : "M" main de l'arme | "O" autre main | "B" les deux mains | "K" jambe (côté arme)
		Arc   : { a0, a1, tilt, radius?, y? } arc de taillade (CartoonFX.slashArc : degrés, 0 = devant, + = droite ;
		        tilt 90 = vertical, + vers le haut). Joué seulement si le style l'autorise (Trail.Arc).

	Styles[id] :
		Anims    = { 5 noms d'animation }, Uppercut / Downslam / Dash = nom, Air = { 3 noms } (optionnels : base sinon)
		Trail    = { Colors = { début, fin }, Width (échelle), Lifetime (s), Light (LightEmission), Fist (taille de la
		           traînée de poing si pas d'arme), Arc = "All" | "Finisher" | nil, ArcWidth }
		Whoosh   = { Key (Config/Sounds), Volume, Pitch, Layer = false : pas de couche en plus du whoosh local,
		           FinisherKey : son réservé aux coups lourds }
		Impact   = "Punch" | "Blunt" | "Heavy" | "Slash" | "Slap" | "Claws" | "Tech" | "Bacon" | "Splash"
	Characters[id] = { Style, Hand ("Left"/"Right" : main de l'arme fétiche), Hits = { [i] = anim } (remplace des coups),
		Colors = { début, fin } (traînée), Impact?, Whoosh? (remplacent ceux du style), Weapon = description (doc) }
	Items : style par objet (Items) sinon par famille (Families) ; MaterialTint teinte la fin de la traînée.
]]
local C = Color3.fromRGB

local M = {}

M.Default = "Fists"

------------------------------------------------------------------------
-- Méta des animations (nom de base, sans le suffixe _L)
------------------------------------------------------------------------
local SIDE_R = { 75, -75, 15 } -- coup droit (de la droite, en haut, vers la gauche)
local SIDE_L = { -75, 75, 0 } -- revers
local OVER = { 85, -55, 90 }   -- de haut en bas (vertical)
local RISE = { -60, 80, 90 }   -- de bas en haut

M.Moves = {
	-- poings (Config/Combat.M1.Anim) : coups 1/3 main droite, 2/4 main gauche, 5 = coup de pied retourné
	Punch1 = { Kind = "M1", I = 1, Limb = "M" },
	Punch2 = { Kind = "M1", I = 2, Limb = "O" },
	Punch3 = { Kind = "M1", I = 3, Limb = "M" },
	Punch4 = { Kind = "M1", I = 4, Limb = "O" },
	Punch5 = { Kind = "M1", I = 5, Limb = "K", Arc = { 110, -80, 0, 5 } },
	Uppercut = { Kind = "Up", Limb = "M" },
	Downslam = { Kind = "Slam", Limb = "B" },
	Air1 = { Kind = "Air", Limb = "M" },
	Air2 = { Kind = "Air", Limb = "O" },
	Air3 = { Kind = "Air", Limb = "K" },
	DashStrike = { Kind = "Dash", Limb = "K" },
	-- bagarreur
	Brawl4Hook = { Kind = "M1", I = 4, Limb = "M", Arc = { 70, -50, 0, 4 } },
	Brawl4Elbow = { Kind = "M1", I = 4, Limb = "M" },
	Brawl5Haymaker = { Kind = "M1", I = 5, Limb = "M", Arc = { 80, -40, 35, 4.5 } },
	Brawl5Shoulder = { Kind = "M1", I = 5, Limb = "M" },
	-- contondant une main
	Blunt1 = { Kind = "M1", I = 1, Limb = "M", Arc = SIDE_R },
	Blunt2 = { Kind = "M1", I = 2, Limb = "M", Arc = SIDE_L },
	Blunt3 = { Kind = "M1", I = 3, Limb = "M", Arc = OVER },
	Blunt4 = { Kind = "M1", I = 4, Limb = "M", Arc = RISE },
	Blunt5 = { Kind = "M1", I = 5, Limb = "M", Arc = { 95, -80, 40, 5.5 } },
	Blunt4Thrust = { Kind = "M1", I = 4, Limb = "M" },
	Blunt5Hammer = { Kind = "M1", I = 5, Limb = "B", Arc = { 90, -60, 90, 5 } },
	Blunt5Golf = { Kind = "M1", I = 5, Limb = "B", Arc = { 85, -85, -60, 5.5 } },
	-- lourd (poids au bout du bras)
	Heavy1 = { Kind = "M1", I = 1, Limb = "M", Arc = { -70, 15, 90, 4.5 } },
	Heavy2 = { Kind = "M1", I = 2, Limb = "M", Arc = { 85, -60, 0, 4.5 } },
	Heavy3 = { Kind = "M1", I = 3, Limb = "M", Arc = OVER },
	Heavy4 = { Kind = "M1", I = 4, Limb = "M", Arc = { -80, 70, 5, 4.5 } },
	Heavy5 = { Kind = "M1", I = 5, Limb = "M", Arc = { 110, -90, 0, 6 } },
	Heavy4Shove = { Kind = "M1", I = 4, Limb = "B" },
	Heavy5Ground = { Kind = "M1", I = 5, Limb = "B", Arc = { 90, -75, 90, 5.5 } },
	-- long / balayage
	Long1 = { Kind = "M1", I = 1, Limb = "M", Arc = { 100, -100, 5, 6.5 } },
	Long2 = { Kind = "M1", I = 2, Limb = "M", Arc = { -100, 100, 0, 6.5 } },
	Long3 = { Kind = "M1", I = 3, Limb = "M" },
	Long4 = { Kind = "M1", I = 4, Limb = "M", Arc = { 90, -90, 25, 6, -1.4 } },
	Long5 = { Kind = "M1", I = 5, Limb = "M", Arc = { 90, -60, 90, 6.5 } },
	Long5Spin = { Kind = "M1", I = 5, Limb = "M", Arc = { 175, -175, 0, 6.5 } },
	-- plat / claque
	Slap1 = { Kind = "M1", I = 1, Limb = "M", Arc = { 70, -70, 0, 4 } },
	Slap2 = { Kind = "M1", I = 2, Limb = "M", Arc = { -70, 70, 0, 4 } },
	Slap3 = { Kind = "M1", I = 3, Limb = "M", Arc = { 75, -30, 90, 3.8 } },
	Slap4 = { Kind = "M1", I = 4, Limb = "O" },
	Slap5 = { Kind = "M1", I = 5, Limb = "M", Arc = { -110, 90, 0, 5 } },
	Slap4Double = { Kind = "M1", I = 4, Limb = "B" },
	Slap5Overhead = { Kind = "M1", I = 5, Limb = "B", Arc = { 85, -40, 90, 4.5 } },
	-- griffes
	Claw1 = { Kind = "M1", I = 1, Limb = "M", Arc = { 70, -70, 55, 3.8 } },
	Claw2 = { Kind = "M1", I = 2, Limb = "O", Arc = { -70, 70, -55, 3.8 } },
	Claw3 = { Kind = "M1", I = 3, Limb = "B", Arc = OVER },
	Claw4 = { Kind = "M1", I = 4, Limb = "M", Arc = { 70, -70, -55, 4 } },
	Claw5 = { Kind = "M1", I = 5, Limb = "B", Arc = { 90, -60, 90, 5 } },
	-- tech / holo
	Tech1 = { Kind = "M1", I = 1, Limb = "M" },
	Tech2 = { Kind = "M1", I = 2, Limb = "O" },
	Tech3 = { Kind = "M1", I = 3, Limb = "M", Arc = { 70, -70, -55, 4 } },
	Tech4 = { Kind = "M1", I = 4, Limb = "B" },
	Tech5 = { Kind = "M1", I = 5, Limb = "B", Arc = { 80, -80, 0, 5 } },
	Tech4Swipe = { Kind = "M1", I = 4, Limb = "M", Arc = { 80, -60, 0, 4.5 } },
	-- bacon (fouet mou)
	Bacon1 = { Kind = "M1", I = 1, Limb = "M", Arc = { 85, -50, 90, 5 } },
	Bacon2 = { Kind = "M1", I = 2, Limb = "M", Arc = { -90, 90, 0, 5 } },
	Bacon3 = { Kind = "M1", I = 3, Limb = "M", Arc = { 80, -80, -20, 5, -0.8 } },
	Bacon4 = { Kind = "M1", I = 4, Limb = "M", Arc = { -80, 70, -45, 5 } },
	Bacon5 = { Kind = "M1", I = 5, Limb = "M", Arc = { 160, -120, -20, 5.5 } },
	-- variantes d'arme de l'uppercut et du downslam
	WeaponUppercut = { Kind = "Up", Limb = "M", Arc = RISE },
	WeaponDownslam = { Kind = "Slam", Limb = "M", Arc = OVER },
	-- variantes uniques (au moins un coup 1-3 propre à chaque personnage)
	Brawl1Lead = { Kind = "M1", I = 1, Limb = "M" },
	Brawl2Back = { Kind = "M1", I = 2, Limb = "M", Arc = { -80, 70, 0, 4 } },
	Brawl3Knee = { Kind = "M1", I = 3, Limb = "K" },
	Brawl4Point = { Kind = "M1", I = 4, Limb = "M" },
	Slap1Edge = { Kind = "M1", I = 1, Limb = "M", Arc = { 75, -50, 25, 4 } },
	Slap2Fan = { Kind = "M1", I = 2, Limb = "M", Arc = { -70, 70, -30, 4 } },
	Slap3Stamp = { Kind = "M1", I = 3, Limb = "M" },
	Blunt1Snap = { Kind = "M1", I = 1, Limb = "M" },
	Blunt2Baton = { Kind = "M1", I = 2, Limb = "M", Arc = { -75, 75, -20, 4.5 } },
	Blunt2Crank = { Kind = "M1", I = 2, Limb = "M", Arc = { -75, 75, -10, 4, -0.6 } },
	Blunt3Gavel = { Kind = "M1", I = 3, Limb = "M", Arc = OVER },
	Blunt3Tamp = { Kind = "M1", I = 3, Limb = "B" },
	Heavy1Curl = { Kind = "M1", I = 1, Limb = "B", Arc = RISE },
	Tech3Present = { Kind = "M1", I = 3, Limb = "M" },
	-- uppercut (impact 0,2 s) / downslam (0,16 s) / dash strike (0,16 s) par archétype : timings des originaux
	BrawlUppercut = { Kind = "Up", Limb = "M" },
	BrawlDownslam = { Kind = "Slam", Limb = "M" },
	BrawlDash = { Kind = "Dash", Limb = "M" },
	BluntDash = { Kind = "Dash", Limb = "M", Arc = OVER },
	HeavyUppercut = { Kind = "Up", Limb = "B", Arc = RISE },
	HeavyDownslam = { Kind = "Slam", Limb = "B", Arc = OVER },
	HeavyDash = { Kind = "Dash", Limb = "M", Arc = { -60, 80, 60, 5 } },
	LongUppercut = { Kind = "Up", Limb = "M", Arc = RISE },
	LongDownslam = { Kind = "Slam", Limb = "M", Arc = OVER },
	LongDash = { Kind = "Dash", Limb = "M" },
	SlapUppercut = { Kind = "Up", Limb = "M", Arc = RISE },
	SlapDownslam = { Kind = "Slam", Limb = "B" },
	SlapDash = { Kind = "Dash", Limb = "M", Arc = { 70, -70, 0, 4 } },
	ClawUppercut = { Kind = "Up", Limb = "B", Arc = RISE },
	ClawDownslam = { Kind = "Slam", Limb = "B", Arc = OVER },
	ClawDash = { Kind = "Dash", Limb = "B" },
	TechUppercut = { Kind = "Up", Limb = "B" },
	TechDownslam = { Kind = "Slam", Limb = "B" },
	TechDash = { Kind = "Dash", Limb = "B" },
	BaconUppercut = { Kind = "Up", Limb = "M", Arc = RISE },
	BaconDownslam = { Kind = "Slam", Limb = "M", Arc = OVER },
	BaconDash = { Kind = "Dash", Limb = "M", Arc = { 85, -50, 90, 5 } },
	-- Use des objets (Config/Items) : animation et timing propres à l'objet
	Jab = { Kind = "Item", Limb = "M" },
	SideSwing = { Kind = "Item", Limb = "M", Arc = { 80, -80, 0, 5 } },
	OverheadSwing = { Kind = "Item", Limb = "M", Arc = { 85, -55, 90, 5 } },
	Slam = { Kind = "Item", Limb = "B", Arc = { 90, -70, 90, 6 } },
	-- variantes alternées (mini-chaîne d'objet, mêmes keyframes que l'original : ItemChains)
	JabB = { Kind = "Item", Limb = "M" },
	SideSwingB = { Kind = "Item", Limb = "M", Arc = { -80, 80, 0, 5 } },
	OverheadSwingB = { Kind = "Item", Limb = "M", Arc = { 95, -60, 40, 5 } },
}

-- jongle aérien par archétype : dérivé des poses des coups au sol (ProcAnim : armé 0,07 s, impact au Windup
-- Air 0,11 s, jambes repliées). AirFrom[nom] = coup au sol source ; la méta (Limb, Arc) est copiée.
M.AirFrom = {}
for prefix, src in pairs({
	BrawlAir = { "Brawl1Lead", "Brawl2Back", "Brawl3Knee" }, BluntAir = { "Blunt1", "Blunt2", "Blunt3" },
	HeavyAir = { "Heavy1", "Heavy2", "Heavy3" }, LongAir = { "Long1", "Long2", "Long3" },
	SlapAir = { "Slap1", "Slap2", "Slap3" }, ClawAir = { "Claw1", "Claw2", "Claw3" },
	TechAir = { "Tech1", "Tech2", "Tech3" }, BaconAir = { "Bacon1", "Bacon2", "Bacon3" },
}) do
	for i, from in ipairs(src) do
		local name = prefix .. i
		M.AirFrom[name] = from
		M.Moves[name] = { Kind = "Air", Limb = M.Moves[from].Limb, Arc = M.Moves[from].Arc }
	end
end

-- mini-chaîne des objets : chaque Use alterne entre ces animations (M1Style.itemAnim, même choix serveur / client :
-- compteur par personnage remis à zéro si l'objet change ou après ItemChainReset s sans Use). Slam (objets à deux
-- mains) : pas de variante (sa trajectoire SlamPath est jouée par ItemService).
M.ItemChains = { Jab = { "Jab", "JabB" }, SideSwing = { "SideSwing", "SideSwingB" }, OverheadSwing = { "OverheadSwing", "OverheadSwingB" } }
M.ItemChainReset = 1.2

------------------------------------------------------------------------
-- Styles par archétype d'arme
------------------------------------------------------------------------
M.Styles = {
	Fists = {
		Name = "Poings",
		Anims = { "Punch1", "Punch2", "Punch3", "Punch4", "Punch5" },
		Trail = { Colors = { C(255, 255, 255), C(255, 220, 120) }, Width = 0.7, Lifetime = 0.14, Light = 0.4, Fist = 0.9, Arc = nil },
		Whoosh = { Key = "Whoosh", Volume = 0.35, Pitch = 1.05, Layer = false },
		Impact = "Punch",
	},
	Brawler = {
		Name = "Bagarreur",
		Anims = { "Punch1", "Punch2", "Punch3", "Brawl4Hook", "Brawl5Haymaker" },
		Uppercut = "BrawlUppercut", Downslam = "BrawlDownslam", Dash = "BrawlDash", Air = { "BrawlAir1", "BrawlAir2", "BrawlAir3" },
		Trail = { Colors = { C(255, 245, 220), C(255, 150, 60) }, Width = 0.8, Lifetime = 0.16, Light = 0.45, Fist = 1.0, Arc = "Finisher" },
		Whoosh = { Key = "Whoosh", Volume = 0.4, Pitch = 0.92, Layer = false },
		Impact = "Punch",
	},
	Blunt = {
		Name = "Contondant (une main)",
		Anims = { "Blunt1", "Blunt2", "Blunt3", "Blunt4", "Blunt5" },
		Uppercut = "WeaponUppercut", Downslam = "WeaponDownslam", Dash = "BluntDash", Air = { "BluntAir1", "BluntAir2", "BluntAir3" },
		Trail = { Colors = { C(255, 240, 200), C(255, 170, 60) }, Width = 1, Lifetime = 0.16, Light = 0.5, Arc = "Finisher" },
		Whoosh = { Key = "Whoosh", Volume = 0.45, Pitch = 0.86 },
		Impact = "Blunt",
	},
	Heavy = {
		Name = "Lourd",
		Anims = { "Heavy1", "Heavy2", "Heavy3", "Heavy4", "Heavy5" },
		Uppercut = "HeavyUppercut", Downslam = "HeavyDownslam", Dash = "HeavyDash", Air = { "HeavyAir1", "HeavyAir2", "HeavyAir3" },
		Trail = { Colors = { C(230, 230, 240), C(120, 120, 140) }, Width = 1.25, Lifetime = 0.2, Light = 0.25, Arc = "All", ArcWidth = 0.7 },
		Whoosh = { Key = "DashWhoosh", Volume = 0.5, Pitch = 0.75 },
		Impact = "Heavy",
	},
	Long = {
		Name = "Long / balayage",
		Anims = { "Long1", "Long2", "Long3", "Long4", "Long5" },
		Uppercut = "LongUppercut", Downslam = "LongDownslam", Dash = "LongDash", Air = { "LongAir1", "LongAir2", "LongAir3" },
		Trail = { Colors = { C(200, 240, 255), C(80, 170, 255) }, Width = 0.9, Lifetime = 0.22, Light = 0.55, Arc = "All", ArcWidth = 0.4 },
		Whoosh = { Key = "DashWhoosh", Volume = 0.45, Pitch = 1.0 },
		Impact = "Slash",
	},
	Slap = {
		Name = "Plat / claque",
		Anims = { "Slap1", "Slap2", "Slap3", "Slap4", "Slap5" },
		Uppercut = "SlapUppercut", Downslam = "SlapDownslam", Dash = "SlapDash", Air = { "SlapAir1", "SlapAir2", "SlapAir3" },
		Trail = { Colors = { C(255, 255, 255), C(255, 230, 150) }, Width = 1.1, Lifetime = 0.13, Light = 0.5, Fist = 0.9, Arc = "Finisher" },
		Whoosh = { Key = "Whoosh", Volume = 0.42, Pitch = 1.18 },
		Impact = "Slap",
	},
	Claws = {
		Name = "Griffes",
		Anims = { "Claw1", "Claw2", "Claw3", "Claw4", "Claw5" },
		Uppercut = "ClawUppercut", Downslam = "ClawDownslam", Dash = "ClawDash", Air = { "ClawAir1", "ClawAir2", "ClawAir3" },
		Trail = { Colors = { C(255, 255, 255), C(255, 150, 60) }, Width = 0.6, Lifetime = 0.12, Light = 0.6, Fist = 0.8, Arc = "All", ArcWidth = 0.25 },
		Whoosh = { Key = "Whoosh", Volume = 0.4, Pitch = 1.3 },
		Impact = "Claws",
	},
	Tech = {
		Name = "Tech / holo",
		Anims = { "Tech1", "Tech2", "Tech3", "Tech4", "Tech5" },
		Uppercut = "TechUppercut", Downslam = "TechDownslam", Dash = "TechDash", Air = { "TechAir1", "TechAir2", "TechAir3" },
		Trail = { Colors = { C(120, 255, 255), C(255, 80, 230) }, Width = 0.9, Lifetime = 0.18, Light = 1, Fist = 1.0, Arc = "Finisher" },
		Whoosh = { Key = "Electric", Volume = 0.3, Pitch = 1.4 },
		Impact = "Tech",
	},
	Bacon = {
		Name = "Bacon (fouet)",
		Anims = { "Bacon1", "Bacon2", "Bacon3", "Bacon4", "Bacon5" },
		Uppercut = "BaconUppercut", Downslam = "BaconDownslam", Dash = "BaconDash", Air = { "BaconAir1", "BaconAir2", "BaconAir3" },
		Trail = { Colors = { C(255, 120, 90), C(255, 210, 120) }, Width = 1.1, Lifetime = 0.24, Light = 0.6, Arc = "All", ArcWidth = 0.55 },
		Whoosh = { Key = "Whoosh", Volume = 0.4, Pitch = 1.1, FinisherKey = "SlideWhistle" }, -- sifflet : 5e coup seulement
		Impact = "Bacon",
	},
	-- objets à liquide (seaux, pichets, mug, peinture) : contondant mais éclaboussure
	Splash = {
		Name = "Éclaboussure",
		Anims = { "Blunt1", "Blunt2", "Blunt3", "Blunt4", "Blunt5" },
		Uppercut = "WeaponUppercut", Downslam = "WeaponDownslam", Dash = "BluntDash", Air = { "BluntAir1", "BluntAir2", "BluntAir3" },
		Trail = { Colors = { C(200, 245, 255), C(60, 160, 255) }, Width = 1, Lifetime = 0.2, Light = 0.4, Arc = "Finisher" },
		Whoosh = { Key = "Water", Volume = 0.25, Pitch = 1.2 },
		Impact = "Splash",
	},
}

------------------------------------------------------------------------
-- Les 21 personnages (arme fétiche = Content/<Id>.luau ou CharacterService pour les 4 de base)
-- Chaque chaîne est unique (coups 4-5 et/ou main miroir et/ou couleurs).
------------------------------------------------------------------------
M.Characters = {
	Intern = { Style = "Brawler", Hand = "Left", Weapon = "Gobelet de café",
		Hits = { [3] = "Brawl3Knee", [4] = "Brawl4Elbow", [5] = "Brawl5Shoulder" },
		Colors = { C(255, 235, 200), C(160, 95, 45) }, Impact = "Splash",
		Whoosh = { Key = "Whoosh", Volume = 0.4, Pitch = 1.15, Layer = false } },
	Janitor = { Style = "Long", Hand = "Left", Weapon = "Seau (et serpillière)",
		Hits = { [5] = "Long5Spin" }, Colors = { C(200, 245, 255), C(60, 150, 255) }, Impact = "Splash" },
	LunchLady = { Style = "Slap", Hand = "Right", Weapon = "Spatule",
		Hits = { [4] = "Slap4Double", [5] = "Slap5Overhead" }, Colors = { C(255, 255, 255), C(255, 120, 150) } },
	SecurityGuard = { Style = "Blunt", Hand = "Right", Weapon = "Matraque",
		Hits = { [2] = "Blunt2Baton" }, Colors = { C(200, 215, 255), C(40, 60, 160) } },
	AIAssistant = { Style = "Tech", Hand = "Left", Weapon = "Tablette holographique",
		Colors = { C(120, 255, 255), C(255, 80, 230) } },
	Accountant = { Style = "Slap", Hand = "Left", Weapon = "Calculatrice",
		Hits = { [2] = "Slap2Fan", [5] = "Slap5Overhead" }, Colors = { C(200, 255, 200), C(40, 200, 90) } },
	Bacon = { Style = "Bacon", Hand = "Left", Weapon = "Tranche de bacon" },
	Barista = { Style = "Blunt", Hand = "Right", Weapon = "Porte-filtre",
		Hits = { [3] = "Blunt3Tamp", [4] = "Blunt4Thrust", [5] = "Blunt5Golf" }, Colors = { C(255, 240, 215), C(130, 80, 40) }, Impact = "Splash",
		Whoosh = { Key = "Spray", Volume = 0.22, Pitch = 1.3 } },
	CEO = { Style = "Heavy", Hand = "Right", Weapon = "Mallette noire et or",
		Colors = { C(255, 240, 160), C(200, 150, 30) } },
	Consultant = { Style = "Tech", Hand = "Left", Weapon = "Tablette à graphiques",
		Hits = { [3] = "Tech3Present", [4] = "Tech4Swipe" }, Colors = { C(150, 190, 255), C(255, 150, 40) } },
	DeliveryGuy = { Style = "Brawler", Hand = "Left", Weapon = "Colis sous le bras",
		Hits = { [1] = "Brawl1Lead", [5] = "Brawl5Shoulder" }, Colors = { C(255, 240, 190), C(190, 130, 60) }, Impact = "Blunt" },
	FitnessCoach = { Style = "Heavy", Hand = "Right", Weapon = "Kettlebell",
		Hits = { [1] = "Heavy1Curl", [4] = "Heavy4Shove", [5] = "Heavy5Ground" }, Colors = { C(230, 255, 160), C(120, 220, 30) } },
	HRManager = { Style = "Slap", Hand = "Left", Weapon = "Clipboard",
		Hits = { [3] = "Slap3Stamp" }, Colors = { C(240, 220, 255), C(150, 80, 220) } },
	ITGuy = { Style = "Slap", Hand = "Left", Weapon = "Portable fermé",
		Hits = { [1] = "Slap1Edge", [4] = "Slap4Double" }, Colors = { C(180, 255, 245), C(30, 190, 200) }, Impact = "Tech" },
	Lawyer = { Style = "Blunt", Hand = "Right", Weapon = "Marteau de juge",
		Hits = { [3] = "Blunt3Gavel", [5] = "Blunt5Hammer" }, Colors = { C(255, 225, 150), C(130, 30, 50) } },
	MaintenanceGuy = { Style = "Blunt", Hand = "Right", Weapon = "Clé à molette",
		Hits = { [2] = "Blunt2Crank", [4] = "Blunt4Thrust" }, Colors = { C(255, 245, 120), C(255, 130, 20) }, Impact = "Heavy",
		Whoosh = { Key = "DashWhoosh", Volume = 0.45, Pitch = 0.85 } },
	MarketingGuru = { Style = "Blunt", Hand = "Left", Weapon = "Mégaphone",
		Hits = { [5] = "Blunt5Golf" }, Colors = { C(255, 200, 245), C(230, 40, 170) } },
	Mascot = { Style = "Brawler", Hand = "Left", Weapon = "Main en mousse",
		Hits = { [2] = "Brawl2Back", [4] = "Brawl4Point" }, Colors = { C(255, 250, 150), C(230, 40, 40) },
		Whoosh = { Key = "Boing", Volume = 0.2, Pitch = 1.4 } },
	OfficeCat = { Style = "Claws", Hand = "Left", Weapon = "Pelote de laine (griffes)" },
	Receptionist = { Style = "Long", Hand = "Right", Weapon = "Combiné de téléphone (fil en fouet)",
		Colors = { C(255, 230, 245), C(240, 90, 160) }, Impact = "Slap",
		Whoosh = { Key = "Whoosh", Volume = 0.4, Pitch = 1.25 } },
	Temp = { Style = "Blunt", Hand = "Right", Weapon = "Agrafeuse",
		Hits = { [1] = "Blunt1Snap", [4] = "Blunt4Thrust", [5] = "Blunt5Hammer" }, Colors = { C(210, 200, 255), C(90, 70, 220) } },
}

------------------------------------------------------------------------
-- Objets tenus (Config/Items) : par objet, sinon par famille. Objets sans coup (Eat, Squeak, Spray) : aucun style.
------------------------------------------------------------------------
M.Families = { Melee = "Blunt", Throwable = "Blunt", Heavy = "Heavy", Zone = "Blunt" }
M.NoStyleSpecials = { Eat = true, Squeak = true, Spray = true }
M.Items = {
	-- plats
	Tray = "Slap", Laptop = "Slap", Keyboard = "Slap", Blueprint = "Slap", PingPongPaddle = "Slap", CardboardBox = "Slap",
	-- longs
	Broom = "Long", Cable = "Long", Umbrella = "Long", BambooPole = "Long", MicStand = "Long", TowelRoll = "Long",
	FanBlade = "Long", VelvetRope = "Long",
	-- lourds tenus à une main
	Chair = "Heavy", Suitcase = "Heavy", HandTruck = "Heavy", FoldingSeat = "Heavy", BowlingBall = "Heavy", Dumbbell = "Heavy",
	-- liquides
	CoffeeMug = "Splash", WaterBucket = "Splash", WaterJug = "Splash", PaintBucket = "Splash",
}
M.MaterialTint = {
	Wood = C(190, 130, 70), Metal = C(170, 185, 205), Plastic = C(120, 200, 255), Ceramic = C(240, 225, 200),
	Glass = C(180, 240, 255), Rubber = C(255, 210, 60), Food = C(255, 160, 80),
}

return M
