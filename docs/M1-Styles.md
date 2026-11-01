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
| `CombatController.luau` / `CombatService.luau` | Une seule substitution : `M1Style.remap(personnage, anim)` sur les anims de M1 (client) et sur la remote `Anim` (serveur) |

## Résolution

1. **Objet tenu** stylé (`M1Styles.Items[id]`, sinon `Families[Family]`) → traînée / arc / impact de l'objet
   (la fin de la traînée est teintée par `MaterialTint[Material]`). Objets sans coup (`Eat`, `Squeak`, `Spray`) : rien.
2. Sinon **arme fétiche** du personnage (`M1Styles.Characters[CharacterName]`) : style + surcharges (`Hits`, `Colors`,
   `Impact`, `Whoosh`).
3. Sinon **Fists** (Punch1-5 d'origine).

La chaîne de 5 M1 (et uppercut / downslam / jongle si le style les surcharge) utilise toujours le style du personnage :
tenir un objet remplace le M1 par le `Use` de l'objet. Arme en **main gauche** (`Hand = "Left"`, lu sur l'attribut du
dossier `Signature`, sinon dans les données) → version miroir `<Nom>_L` de chaque animation (membres échangés,
rotation du buste inversée), générée automatiquement par ProcAnim pour toutes les entrées de `Moves`.

## Timing (hit serveur inchangé)

Toutes les animations de M1 passent par `swing(i, …)` : impact **pile au `M1.Windup[i]`** de Config/Combat
(0,14 / 0,14 / 0,15 / 0,16 / 0,22 s, lu dans la config), mêmes durées que Punch1-5 (0,58 / 0,58 / 0,6 / 0,62 / 1,2 s).
Coups 1-4 : armé à `Windup − 0,04`, suivi tenu jusqu'à `Windup + 0,14`, retour en garde. 5e coup : armé en deux temps
(`Windup − 0,1` puis `− 0,04`), suivi, puis pose « souffle » (endlag lisible). `WeaponUppercut` (impact 0,2 s) et
`WeaponDownslam` (0,16 s) gardent les timings de `Uppercut` / `Downslam`. Le serveur ne fait que renvoyer un autre
nom d'animation : fenêtres, dégâts et hitbox sont strictement identiques.

## Archétypes

| Style | Coups 1 → 5 | Uppercut / Downslam | Traînée | Arc | Whoosh | Impact |
|---|---|---|---|---|---|---|
| Fists | jab D, crochet G, corps D, direct G, coup de pied retourné | d'origine | poing blanc | — | Whoosh | Punch : anneau d'air |
| Brawler | Punch1-3, `Brawl4Hook` (crochet main forte), `Brawl5Haymaker` (crochet plongeant) | d'origine | poing chaud | finisher | Whoosh grave | Punch |
| Blunt | coup droit diagonal, revers, frappe verticale, remontée, smash enroulé | Weapon* | arme, ambre | finisher | Whoosh grave | Blunt : double anneau + poussière |
| Heavy | pendule, crochet chargé, chute verticale, revers tournant, lancer de marteau | Weapon* | large, acier | tous | DashWhoosh grave | Heavy : onde au sol + poussière (+ fissures au finisher) |
| Long | balayage, balayage retour, estoc, fauchage bas, moulinet abattu | Weapon* | longue, bleue | tous | DashWhoosh | Slash : entaille + étincelles |
| Slap | gifle à plat, revers, tape sur la tête, gifle autre main, revers tournant | d'origine | plate, blanche | finisher | Whoosh aigu | Slap : feuilles qui volettent + étoile |
| Claws | patte D, patte G, double griffure, griffure montante, bond double ratissage | WeaponUppercut | fine, orange | tous | Whoosh très aigu | Claws : 3 griffures |
| Tech | paume D, paume G, swipe montant, double poussée, « surcharge » | d'origine | cyan → magenta | finisher | Electric | Tech : explosion de pixels + cadre |
| Bacon | fouet par-dessus, fouetté latéral, fouetté déhanché, moulinet, « Crispy Cyclone » | Weapon* | rouge → doré, longue | tous | SlideWhistle | Bacon : gouttes de graisse + flaques |
| Splash (objets) | = Blunt | — | eau | finisher | Water | Splash : gouttelettes |

Variantes : `Brawl4Elbow`, `Brawl5Shoulder` (charge d'épaule), `Blunt4Thrust` (estoc), `Blunt5Hammer` (marteau à deux
mains), `Blunt5Golf` (swing de golf), `Heavy4Shove` (bélier à deux mains), `Heavy5Ground` (écrasement au sol),
`Long5Spin` (tour complet), `Slap4Double` (double claque), `Slap5Overhead` (tape à deux mains), `Tech4Swipe`.

## Les 21 personnages (chaînes toutes différentes)

| Perso | Arme fétiche (main) | Style | Coups 4 / 5 | Couleurs traînée | Impact |
|---|---|---|---|---|---|
| Intern | gobelet de café (G) | Brawler | Elbow / Shoulder | crème → café | Splash |
| Janitor | seau, serpillière (G) | Long | Long4 / **Long5Spin** | eau | Splash |
| LunchLady | spatule (D) | Slap | **Double** / **Overhead** | blanc → rose | Slap |
| SecurityGuard | matraque (D) | Blunt | Blunt4 / Blunt5 | bleu nuit | Blunt |
| AIAssistant | tablette holo (G) | Tech | Tech4 / Tech5 | cyan → magenta | Tech |
| Accountant | calculatrice (G) | Slap | Slap4 / **Overhead** | vert LCD | Slap |
| Bacon | tranche de bacon (G) | Bacon | Bacon4 / Bacon5 | rouge → doré | Bacon |
| Barista | porte-filtre (D) | Blunt | **Thrust** / **Golf** | crème → café | Splash |
| CEO | mallette (D) | Heavy | Heavy4 / Heavy5 | or | Heavy |
| Consultant | tablette graphiques (G) | Tech | **Swipe** / Tech5 | bleu → orange | Tech |
| DeliveryGuy | colis (G) | Brawler | Hook / **Shoulder** | carton | Blunt |
| FitnessCoach | kettlebell (D) | Heavy | **Shove** / **Ground** | vert citron | Heavy |
| HRManager | clipboard (G) | Slap | Slap4 / Slap5 | violet | Slap |
| ITGuy | portable (G) | Slap | **Double** / Slap5 | turquoise | Tech |
| Lawyer | marteau de juge (D) | Blunt | Blunt4 / **Hammer** | or → bordeaux | Blunt |
| MaintenanceGuy | clé à molette (D) | Blunt | **Thrust** / Blunt5 | jaune → orange | Heavy |
| MarketingGuru | mégaphone (G) | Blunt | Blunt4 / **Golf** | rose → magenta | Blunt |
| Mascot | main en mousse (G) | Brawler | Hook / Haymaker | jaune → rouge | Punch |
| OfficeCat | pelote, griffes (G) | Claws | Claw4 / Claw5 | blanc → orange | Claws |
| Receptionist | combiné, fil en fouet (D) | Long | Long4 / Long5 | rose | Slap |
| Temp | agrafeuse (D) | Blunt | **Thrust** / **Hammer** | indigo | Blunt |

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

## Effets (M1StyleController)

- **Déclenchement** : `ProcAnim.onPlay` ; toute animation de `Moves` jouée sur un personnage de joueur / mannequin.
  Joueur local : au clic (CombatController joue l'anim). Autres joueurs : via la remote `Anim` (FXController).
- **Traînée** : 2 Attachments + Trail, activée seulement de `Windup − 0,05` (− 0,07 coups lourds) à `Windup + 0,09`
  (+ 0,12). Sur l'arme fétiche si elle est dans la main qui frappe et visible (points calculés dans l'espace du bras :
  de la main au bout de l'arme, mis en cache par dossier), sur l'objet tenu (Handle trouvé par sa `HoldWeld`), sinon
  ruban au bout du bras / de la jambe (`Limb` de `Moves` : M, O, B = deux mains, K = jambe).
- **Arc de taillade** (`CartoonFX.slashArc`) : `Trail.Arc = "All"` ou `"Finisher"` (coups lourds) ; miroir pour la main
  gauche ; jamais en qualité Low.
- **Impact** : joueur local = prédit au `Windup` sur les cibles de la hitbox (mêmes filtres que la prédiction de
  CombatController : block, renversé, bulle, PendingKO, zone sûre) ; autres joueurs = au `Hit` serveur de cet
  attaquant reçu dans `Windup + 0,5 s`. S'ajoute à l'effet de coup générique de CartoonFX.
- **Réglages** : `Quality` (Low / Medium / High : quantités via `CartoonFX.count`, traînées max 4 / 8 / 14, durée des
  traînées −30 % en Low, pas d'arc en Low) ; `ReducedFlashes` (pas de néon, `LightEmission` 0, traînée plus
  transparente, pas de lumière). Coups des autres au-delà de 150 studs de la caméra : ignorés.
- **Nettoyage** : tout passe par Debris ; traînées au-delà de la limite détruites (les plus anciennes) ; tables
  d'état à clés faibles ; attachments sur les membres (détruits avec le personnage au respawn).

## Ajouter / modifier

- Nouvelle animation : une entrée `swing(i, armé, impact)` dans `STYLE_ANIMS` (ProcAnim) **et** sa méta dans
  `M1Styles.Moves` (même `I` que l'emplacement). Le miroir `_L` est automatique.
- Nouveau personnage : une ligne dans `M1Styles.Characters` (`Style`, `Hand`, `Hits`, `Colors`…).
- Nouvel objet : rien à faire (famille) ou une ligne dans `M1Styles.Items`.
