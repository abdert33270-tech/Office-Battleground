# Styles de M1 par arme

Chaque personnage frappe avec **son arme fétiche** (dossier `Signature` construit par CharacterService) : animations de
M1 propres, traînée qui suit l'arme ou le bras, arc de taillade pour les armes larges, whoosh et effet d'impact.
Les objets tenus (Config/Items) ont aussi leur style (traînée, arc, impact) ; leur animation reste celle de leur `Use`.

## Fichiers

| Fichier | Rôle |
|---|---|
| `src/ReplicatedStorage/Shared/Config/M1Styles.luau` | Données : `Moves` (méta des anims), `Styles` (archétypes), `Characters` (21 persos), `Items` / `Families` / `MaterialTint` |
| `src/ReplicatedStorage/Shared/Modules/M1Style.luau` | Résolution partagée client / serveur : `remap`, `resolve`, `forCharacter`, `forItem`, `info`, `hand` |
| `src/ReplicatedStorage/Shared/Modules/ProcAnim.luau` | Bloc « STYLES DE M1 PAR ARME » : les animations (`swing(i, armé, impact)`), miroirs `<Nom>_L`, `ProcAnim.onPlay` |
| `src/StarterPlayer/StarterPlayerScripts/Controllers/M1StyleController.luau` | Client : traînées, arcs, whoosh, impacts (local et autres joueurs) |
| `CombatController.luau` / `CombatService.luau` | `M1Style.remap(personnage, anim)` sur les anims de M1 / uppercut / downslam / jongle / dash strike (client) et sur la remote `Anim` (serveur) ; champ `wp` (arme) ajouté au payload FX `Hit` |
| `ItemService.luau` / `CombatController.luau` | `M1Style.itemAnim(personnage, use.Anim)` : mini-chaîne des Use d'objets |

## Résolution

1. **Objet tenu** stylé (`M1Styles.Items[id]`, sinon `Families[Family]`) → traînée / arc / impact de l'objet
   (la fin de la traînée est teintée par `MaterialTint[Material]`). Objets sans coup (`Eat`, `Squeak`, `Spray`) : rien.
2. Sinon **arme fétiche** du personnage (`M1Styles.Characters[CharacterName]`) : style + surcharges (`Hits`, `Colors`,
   `Impact`, `Whoosh`).
3. Sinon **Fists** (Punch1-5 d'origine).

La chaîne de 5 M1, l'uppercut, le downslam, les 3 coups du jongle et le dash strike utilisent toujours le style du personnage :
tenir un objet remplace le M1 par le `Use` de l'objet. Arme en **main gauche** (`Hand = "Left"`, lu sur l'attribut du
dossier `Signature`, sinon dans les données) → version miroir `<Nom>_L` de chaque animation (membres échangés,
rotation du buste inversée), générée automatiquement par ProcAnim pour toutes les entrées de `Moves`.

## Timing (hit serveur inchangé)

Toutes les animations de M1 passent par `swing(i, …)` : impact **pile au `M1.Windup[i]`** de Config/Combat
(0,14 / 0,14 / 0,15 / 0,16 / 0,22 s, lu dans la config), mêmes durées que Punch1-5 (0,58 / 0,58 / 0,6 / 0,62 / 1,2 s).
Coups 1-4 : armé à `Windup − 0,04`, suivi tenu jusqu'à `Windup + 0,14`, retour en garde. 5e coup : armé en deux temps
(`Windup − 0,1` puis `− 0,04`), suivi, puis pose « souffle » (endlag lisible). `WeaponUppercut` (impact 0,2 s) et
`WeaponDownslam` (0,16 s) et toutes les variantes `<Arch>Uppercut` / `<Arch>Downslam` / `<Arch>Dash` (DashStrike : impact
0,16 s, réception 0,62 s, fin 0,8 s) gardent les timings des originaux. Jongle `<Arch>Air1-3` : dérivé des poses des coups
1-3 au sol (`M1Styles.AirFrom`), jambes repliées, impact au `Air.Windup` (0,11 s), fin 0,4 s. Le serveur ne fait que renvoyer un autre
nom d'animation : fenêtres, dégâts et hitbox sont strictement identiques.

## Archétypes

| Style | Coups 1 → 5 | Uppercut / Downslam / Dash strike / Jongle | Traînée | Arc | Whoosh | Impact |
|---|---|---|---|---|---|---|
| Fists | jab D, crochet G, corps D, direct G, coup de pied retourné | d'origine | poing blanc | — | Whoosh | Punch : anneau d'air |
| Brawler | Punch1-3, `Brawl4Hook`, `Brawl5Haymaker` | `BrawlUppercut` crochet montant / `BrawlDownslam` marteau du poing / `BrawlDash` superman punch / `BrawlAir1-3` | poing chaud | finisher | Whoosh grave | Punch |
| Blunt | coup droit diagonal, revers, frappe verticale, remontée, smash enroulé | `WeaponUppercut` / `WeaponDownslam` / `BluntDash` bond-massue / `BluntAir1-3` | arme, ambre | finisher | Whoosh grave | Blunt : double anneau + poussière |
| Heavy | pendule, crochet chargé, chute verticale, revers tournant, lancer de marteau | arraché à deux mains / écrasement à deux mains / ruée en balancier / `HeavyAir1-3` | large, acier | tous | DashWhoosh grave | Heavy : onde au sol + poussière (+ fissures) |
| Long | balayage, balayage retour, estoc, fauchage bas, moulinet abattu | balayage montant / abattu / charge à la lance / `LongAir1-3` | longue, bleue | tous | DashWhoosh | Slash : entaille + étincelles |
| Slap | gifle à plat, revers, tape sur la tête, gifle autre main, revers tournant | tape montante / claque au sol à deux mains / gifle volante / `SlapAir1-3` | plate, blanche | finisher | Whoosh aigu | Slap : feuilles + étoile |
| Claws | patte D, patte G, double griffure, griffure montante, bond double ratissage | double griffure montante / ratissage au sol / bond du chat / `ClawAir1-3` | fine, orange | tous | Whoosh très aigu | Claws : 3 griffures |
| Tech | paume D, paume G, swipe montant, double poussée, « surcharge » | paumes lanceuses / décharge au sol / poussée glissée / `TechAir1-3` | cyan → magenta | finisher | Electric | Tech : pixels + cadre |
| Bacon | fouet par-dessus, fouetté latéral, fouetté déhanché, moulinet, « Crispy Cyclone » | lasso montant / fouet abattu / fouet volant / `BaconAir1-3` | rouge → doré | tous | Whoosh (SlideWhistle au 5e coup seulement) | Bacon : graisse + flaques |
| Splash (objets) | = Blunt | = Blunt | eau | finisher | Water | Splash : gouttelettes |

Variantes : `Brawl4Elbow`, `Brawl5Shoulder` (charge d'épaule), `Blunt4Thrust` (estoc), `Blunt5Hammer` (marteau à deux
mains), `Blunt5Golf` (swing de golf), `Heavy4Shove` (bélier à deux mains), `Heavy5Ground` (écrasement au sol),
`Long5Spin` (tour complet), `Slap4Double` (double claque), `Slap5Overhead` (tape à deux mains), `Tech4Swipe`.
Coups 1-3 propres à un personnage : `Brawl1Lead` (jab plongeant), `Brawl2Back` (revers tournant), `Brawl3Knee`
(genou), `Brawl4Point` (index en mousse), `Slap1Edge` (manchette), `Slap2Fan` (éventail), `Slap3Stamp` (tampon),
`Blunt1Snap` (coup sec), `Blunt2Baton` (moulinet de matraque), `Blunt2Crank` (tour de clé), `Blunt3Gavel` (« order! »),
`Blunt3Tamp` (tassage), `Heavy1Curl` (curl), `Tech3Present` (pointeur).

## Les 21 personnages

Chaque personnage a au moins un coup 1-3 qu'aucun autre ne joue (en comptant le miroir `_L`) et une chaîne complète
différente (vérifié par script). Uppercut / downslam / dash strike / jongle = ceux de son archétype.

| Perso | Arme fétiche (main) | Style | Coups 1-5 (surcharges en gras) | Couleurs traînée | Impact |
|---|---|---|---|---|---|
| Intern | gobelet de café (G) | Brawler | P1, P2, **Knee**, **Elbow**, **Shoulder** | crème → café | Splash |
| Janitor | seau, serpillière (G) | Long | Long1-4, **Long5Spin** | eau | Splash |
| LunchLady | spatule (D) | Slap | Slap1-3, **Double**, **Overhead** | blanc → rose | Slap |
| SecurityGuard | matraque (D) | Blunt | B1, **Baton**, B3, B4, B5 | bleu nuit | Blunt |
| AIAssistant | tablette holo (G) | Tech | Tech1-5 | cyan → magenta | Tech |
| Accountant | calculatrice (G) | Slap | S1, **Fan**, S3, S4, **Overhead** | vert LCD | Slap |
| Bacon | tranche de bacon (G) | Bacon | Bacon1-5 | rouge → doré | Bacon |
| Barista | porte-filtre (D) | Blunt | B1, B2, **Tamp**, **Thrust**, **Golf** | crème → café | Splash |
| CEO | mallette (D) | Heavy | Heavy1-5 | or | Heavy |
| Consultant | tablette graphiques (G) | Tech | T1, T2, **Present**, **Swipe**, T5 | bleu → orange | Tech |
| DeliveryGuy | colis (G) | Brawler | **Lead**, P2, P3, Hook, **Shoulder** | carton | Blunt |
| FitnessCoach | kettlebell (D) | Heavy | **Curl**, H2, H3, **Shove**, **Ground** | vert citron | Heavy |
| HRManager | clipboard (G) | Slap | S1, S2, **Stamp**, S4, S5 | violet | Slap |
| ITGuy | portable (G) | Slap | **Edge**, S2, S3, **Double**, S5 | turquoise | Tech |
| Lawyer | marteau de juge (D) | Blunt | B1, B2, **Gavel**, B4, **Hammer** | or → bordeaux | Blunt |
| MaintenanceGuy | clé à molette (D) | Blunt | B1, **Crank**, B3, **Thrust**, B5 | jaune → orange | Heavy |
| MarketingGuru | mégaphone (G) | Blunt | B1-4, **Golf** | rose → magenta | Blunt |
| Mascot | main en mousse (G) | Brawler | P1, **Back**, P3, **Point**, Haymaker | jaune → rouge | Punch |
| OfficeCat | pelote, griffes (G) | Claws | Claw1-5 | blanc → orange | Claws |
| Receptionist | combiné, fil en fouet (D) | Long | Long1-5 | rose | Slap |
| Temp | agrafeuse (D) | Blunt | **Snap**, B2, B3, **Thrust**, **Hammer** | indigo | Blunt |

(G) = main gauche → toute la chaîne est jouée en miroir (`_L`). Personnage inconnu → Fists.

## Objets tenus

| Style | Objets |
|---|---|
| Slap | Tray, Laptop, Keyboard, Blueprint, PingPongPaddle, CardboardBox |
| Long | Broom, Cable, Umbrella, BambooPole, MicStand, TowelRoll, FanBlade, VelvetRope |
| Heavy | Chair, Suitcase, HandTruck, FoldingSeat, BowlingBall, Dumbbell + famille **Heavy** (Photocopier, ServerRack, Whiteboard, SatelliteDish, FilingDrawer, TeddyBear, RockingHorse, Pallet) |
| Splash | CoffeeMug, WaterBucket, WaterJug, PaintBucket |
| Blunt | familles **Melee / Throwable / Zone** restantes (Stapler, Monitor, PottedPlant, Pan, TrafficCone, Tire, DeskLamp, Trophy, PigeonStatue, BookStack, BeanBag, ToyBlock, Spotlight, HotStone, LotusCandle) |
| aucun | Burger (Eat), RubberDuck (Squeak), FireExtinguisher (Spray) |

**Mini-chaîne d'objet** (`M1Styles.ItemChains`) : chaque Use alterne `Jab ↔ JabB` (estoc plongeant),
`SideSwing ↔ SideSwingB` (revers), `OverheadSwing ↔ OverheadSwingB` (diagonale). Les variantes ont exactement les
mêmes temps de keyframes que l'original et le hit d'ItemService (Use.Windup) ne change pas. Le serveur
(`ItemService.onUse`) choisit l'animation envoyée aux autres via `M1Style.itemAnim` ; le client local fait le même
calcul au même moment (compteur par personnage, remis à zéro si l'objet change ou après `ItemChainReset` = 1,2 s
sans Use). Seul un Use refusé par le serveur peut décaler l'alternance locale jusqu'à la remise à zéro.
`Slam` (objets à deux mains, trajectoire SlamPath) n'a pas de variante.

## Effets (M1StyleController)

- **Déclenchement** : `ProcAnim.onPlay` ; toute animation de `Moves` jouée sur un personnage de joueur / mannequin.
  Joueur local : au clic (CombatController joue l'anim). Autres joueurs : via la remote `Anim` (FXController).
- **Traînée** : 2 Attachments + Trail, activée seulement de `Windup − 0,05` (− 0,07 coups lourds) à `Windup + 0,09`
  (+ 0,12). Sur l'arme fétiche si elle est dans la main qui frappe et visible (points calculés dans l'espace du bras :
  de la main au bout de l'arme, mis en cache par dossier), sur l'objet tenu (Handle trouvé par sa `HoldWeld`), sinon
  ruban au bout du bras / de la jambe (`Limb` de `Moves` : M, O, B = deux mains, K = jambe).
- **Arc de taillade** (`CartoonFX.slashArc`) : `Trail.Arc = "All"` ou `"Finisher"` (coups lourds) ; miroir pour la main
  gauche ; jamais en Low ; arcs des autres joueurs seulement en High ; toujours soumis à la charge d'effets
  (`CartoonFX.count(11)` doit rendre ≥ 6 en local, ≥ 9 pour les autres, et compte l'arc dans la charge).
- **Impact** : joueur local = petit éclair prédit au `Windup` sur les cibles de la hitbox (mêmes filtres que
  CombatController) ; **l'impact stylé complet** (local et autres) part au `Hit` serveur de l'attaquant reçu dans
  `Windup + 0,5 s` **et** dont l'arme `wp` (= `spec.Weapon`) correspond au coup : `Punch` / `Uppercut` / `Downslam` /
  `Dash Strike` pour la chaîne, `DisplayName` de l'objet pour un Use (les attaques / projectiles sont ignorés). Un coup
  paré ou bloqué n'a donc jamais d'impact stylé. S'ajoute à l'effet générique de CartoonFX.
- **Whoosh** : couche du style (le local garde le Whoosh de CombatController) ; autres joueurs : finishers toujours,
  sinon seulement à < 50 studs et au plus 3 par 0,35 s. `FinisherKey` = son réservé aux coups lourds (sifflet du Bacon).
- **Réglages** : `Quality` (Low / Medium / High : quantités via `CartoonFX.count`, traînées max 4 / 8 / 14, durée des
  traînées −30 % en Low) ; `ReducedFlashes` (pas de néon, `LightEmission` 0, traînée plus transparente, pas de
  lumière). Chaque part d'impact est comptée dans la charge de CartoonFX. Coups des autres au-delà de 80 studs de la
  caméra : ignorés.
- **Nettoyage** : tout passe par Debris ; traînées au-delà de la limite détruites (les plus anciennes) ; tables
  d'état à clés faibles ; attachments sur les membres (détruits avec le personnage au respawn).

## Ajouter / modifier

- Nouvelle animation : une entrée `swing(i, armé, impact)` dans `STYLE_ANIMS` (ProcAnim) **et** sa méta dans
  `M1Styles.Moves` (même `I` que l'emplacement). Le miroir `_L` est automatique (sauf Use d'objets, jamais remappés).
  Variantes d'uppercut / downslam / dash : helpers `up`, `slam`, `dash` ; jongle : une entrée dans `AirFrom`.
- Nouveau personnage : une ligne dans `M1Styles.Characters` (`Style`, `Hand`, `Hits`, `Colors`…).
- Nouvel objet : rien à faire (famille) ou une ligne dans `M1Styles.Items`.
