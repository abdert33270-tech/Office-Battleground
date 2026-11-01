# Équilibrage — objets, attaques, passifs

Référence chiffrée de la passe d'équilibrage (tâches B9 à B14). Les tableaux sont générés par les scripts de
parsing (dump Luau des fiches `Config/Items`, `Config/Attacks` + `Content/*`), avant → après.

## Référence : la boucle de M1

Chaîne de 5 M1 (`Config/Combat.luau`) : 3 + 3 + 3 + 4 + 7 = **20 dégâts** en ~3,5 s (cooldowns 0,46 / 0,46 / 0,48 /
0,5 / 1,35 + windups) → **~5,7 DPS**. Plafond fixé pour un objet : **1,4 × M1 ≈ 8 DPS soutenus**.

## B9 — Objets (clic gauche)

Règles :

| Catégorie | Cooldown | Windup | Stun | Dégâts |
|---|---|---|---|---|
| Light (et Splat / spéciaux) | ≥ 0,5 s (0,27–0,5 → 0,5–0,65, ordre conservé) | ≥ 0,14 s (ancien + 0,04) | ≤ Cooldown + 0,1 | ≤ ⌊8 × (3 CD + 0,7) / 3⌋ |
| Heavy (une main) | 0,85–1,0 s | ≥ 0,28 s (ancien + 0,12) | ≤ Cooldown + 0,2 | idem |
| Heavy (deux mains, famille Heavy) | 1,25–1,5 s | ancien + 0,12 (0,37–0,48 s) | idem | idem |

DPS soutenu = 3 × Dégâts / (3 × Cooldown + 0,7) — trois coups puis l'endlag de chaîne (B10).
Identité conservée : les objets légers restent rapides (0,5–0,65 s, 5–7 dégâts), les lourds lents et massifs
(9–13 dégâts, gros windup télégraphié).

| Objet | Cat. | Windup | Dégâts | Cooldown | Stun | DPS avant | DPS après |
|---|---|---|---|---|---|---|---|
| Chair | Heavy | 0.16 → 0.28 | 11 → 9 | 0.6 → 0.93 | 0.8 → 0.8 | 18.3 | 7.7 |
| Keyboard | Light | 0.08 → 0.14 | 7 → 6 | 0.36 → 0.56 | 0.6 → 0.6 | 19.4 | 7.6 |
| Stapler | Light | 0.06 → 0.14 | 5 → 5 | 0.3 → 0.52 | 0.55 → 0.55 | 16.7 | 6.6 |
| CoffeeMug | Light | 0.06 → 0.14 | 5 → 5 | 0.33 → 0.54 | 0.55 → 0.55 | 15.2 | 6.5 |
| Photocopier | Heavy | 0.36 → 0.48 | 20 → 13 | 1.2 → 1.47 | 1.2 → 1.2 | 16.7 | 7.6 |
| Monitor | Heavy | 0.14 → 0.28 | 10 → 9 | 0.55 → 0.9 | 0.8 → 0.8 | 18.2 | 7.9 |
| Broom | Light | 0.1 → 0.14 | 7 → 6 | 0.42 → 0.6 | 0.65 → 0.65 | 16.7 | 7.2 |
| FireExtinguisher | Light | 0.05 → 0.14 | 3 → 3 | 0.7 → 0.7 | 0.5 → 0.5 | 4.3 | 3.2 |
| WaterBucket | Splat | 0.12 → 0.16 | 4 → 4 | 0.8 → 0.8 | 0.7 → 0.7 | 5.0 | 3.9 |
| PottedPlant | Heavy | 0.12 → 0.28 | 8 → 8 | 0.5 → 0.86 | 1 → 1 | 16.0 | 7.3 |
| Tray | Light | 0.08 → 0.14 | 7 → 6 | 0.36 → 0.56 | 0.6 → 0.6 | 19.4 | 7.6 |
| Pan | Heavy | 0.14 → 0.28 | 11 → 9 | 0.55 → 0.9 | 0.9 → 0.9 | 20.0 | 7.9 |
| Burger | - | 0.3 → 0.3 | - → - | 0.5 → 0.5 | - → - | 0.0 | 0.0 |
| Cable | Light | 0.1 → 0.14 | 8 → 6 | 0.45 → 0.62 | 0.75 → 0.72 | 17.8 | 7.0 |
| ServerRack | Heavy | 0.36 → 0.48 | 22 → 13 | 1.25 → 1.5 | 1.2 → 1.2 | 17.6 | 7.5 |
| TrafficCone | Light | 0.08 → 0.14 | 6 → 6 | 0.38 → 0.57 | 0.6 → 0.6 | 15.8 | 7.5 |
| Tire | Heavy | 0.12 → 0.28 | 8 → 8 | 0.5 → 0.86 | 0.7 → 0.7 | 16.0 | 7.3 |
| WaterJug | Splat | 0.14 → 0.18 | 4 → 4 | 0.85 → 0.85 | 0.7 → 0.7 | 4.7 | 3.7 |
| Laptop | Light | 0.1 → 0.14 | 8 → 6 | 0.42 → 0.6 | 0.65 → 0.65 | 19.0 | 7.2 |
| DeskLamp | Heavy | 0.12 → 0.28 | 9 → 8 | 0.48 → 0.85 | 0.75 → 0.75 | 18.8 | 7.4 |
| Trophy | Light | 0.08 → 0.14 | 7 → 6 | 0.38 → 0.57 | 0.6 → 0.6 | 18.4 | 7.5 |
| Whiteboard | Heavy | 0.32 → 0.44 | 17 → 12 | 1 → 1.36 | 1.1 → 1.1 | 17.0 | 7.5 |
| VelvetRope | Heavy | 0.14 → 0.28 | 10 → 9 | 0.55 → 0.9 | 0.8 → 0.8 | 18.2 | 7.9 |
| Umbrella | Light | 0.07 → 0.14 | 6 → 6 | 0.32 → 0.53 | 0.55 → 0.55 | 18.8 | 7.9 |
| Suitcase | Heavy | 0.18 → 0.3 | 12 → 9 | 0.68 → 0.99 | 0.85 → 0.85 | 17.6 | 7.4 |
| SatelliteDish | Heavy | 0.3 → 0.42 | 16 → 12 | 1 → 1.36 | 1.1 → 1.1 | 16.0 | 7.5 |
| PigeonStatue | Heavy | 0.12 → 0.28 | 8 → 8 | 0.5 → 0.86 | 0.9 → 0.9 | 16.0 | 7.3 |
| FanBlade | Light | 0.09 → 0.14 | 7 → 6 | 0.4 → 0.58 | 0.65 → 0.65 | 17.5 | 7.4 |
| FilingDrawer | Heavy | 0.34 → 0.46 | 19 → 13 | 1.15 → 1.44 | 1.2 → 1.2 | 16.5 | 7.8 |
| BookStack | Heavy | 0.12 → 0.28 | 8 → 8 | 0.48 → 0.85 | 0.75 → 0.75 | 16.7 | 7.4 |
| Blueprint | Light | 0.06 → 0.14 | 5 → 5 | 0.27 → 0.5 | 0.5 → 0.5 | 18.5 | 6.8 |
| PingPongPaddle | Light | 0.07 → 0.14 | 6 → 6 | 0.3 → 0.52 | 0.55 → 0.55 | 20.0 | 8.0 |
| BowlingBall | Heavy | 0.15 → 0.28 | 10 → 9 | 0.6 → 0.93 | 0.85 → 0.85 | 16.7 | 7.7 |
| BeanBag | Light | 0.1 → 0.14 | 5 → 5 | 0.45 → 0.62 | 0.5 → 0.5 | 11.1 | 5.9 |
| TeddyBear | Heavy | 0.25 → 0.37 | 10 → 10 | 0.8 → 1.25 | 0.7 → 0.7 | 12.5 | 6.7 |
| ToyBlock | Light | 0.07 → 0.14 | 6 → 6 | 0.36 → 0.56 | 0.6 → 0.6 | 16.7 | 7.6 |
| RubberDuck | - | 0.1 → 0.14 | - → - | 1.1 → 1.1 | 0.9 → 0.9 | 0.0 | 0.0 |
| RockingHorse | Heavy | 0.34 → 0.46 | 18 → 13 | 1.1 → 1.42 | 1.15 → 1.15 | 16.4 | 7.9 |
| MicStand | Light | 0.12 → 0.16 | 9 → 7 | 0.5 → 0.65 | 0.7 → 0.7 | 18.0 | 7.9 |
| Spotlight | Heavy | 0.1 → 0.28 | 7 → 7 | 0.45 → 0.85 | 0.7 → 0.7 | 15.6 | 6.5 |
| FoldingSeat | Heavy | 0.15 → 0.28 | 11 → 9 | 0.58 → 0.92 | 0.9 → 0.9 | 19.0 | 7.8 |
| Pallet | Heavy | 0.32 → 0.44 | 17 → 12 | 1.05 → 1.39 | 1.1 → 1.1 | 16.2 | 7.4 |
| CardboardBox | Light | 0.1 → 0.14 | 6 → 6 | 0.42 → 0.6 | 0.7 → 0.7 | 14.3 | 7.2 |
| HandTruck | Heavy | 0.18 → 0.3 | 12 → 9 | 0.7 → 1 | 0.85 → 0.85 | 17.1 | 7.3 |
| PaintBucket | Splat | 0.12 → 0.16 | 4 → 4 | 0.85 → 0.85 | 0.65 → 0.65 | 4.7 | 3.7 |
| TowelRoll | Light | 0.06 → 0.14 | 6 → 6 | 0.3 → 0.52 | 0.85 → 0.62 | 20.0 | 8.0 |
| BambooPole | Light | 0.1 → 0.14 | 8 → 7 | 0.5 → 0.65 | 0.65 → 0.65 | 16.0 | 7.9 |
| HotStone | Light | 0.06 → 0.14 | 5 → 5 | 0.32 → 0.53 | 0.55 → 0.55 | 15.6 | 6.6 |
| LotusCandle | Light | 0.08 → 0.14 | 5 → 5 | 0.4 → 0.58 | 0.6 → 0.6 | 12.5 | 6.1 |
| Dumbbell | Heavy | 0.12 → 0.28 | 10 → 9 | 0.55 → 0.9 | 0.8 → 0.8 | 18.2 | 7.9 |

(« DPS avant » = Dégâts / Cooldown sans endlag, comme le jeu le permettait ; « DPS après » = formule soutenue.)

## B10 — Endlag de chaîne d'objet

`ItemService.onUse` : compteur serveur `s.itemString` (indépendant de l'index client `mods.ic` de
`M1Style.itemAnim`, qui reste purement visuel). Le **3e coup consécutif** ajoute **0,7 s** d'endlag :
`s.nextAttack` et `s.busyUntil` = t + Cooldown + 0,7 (ni attaque, ni block), attribut `EndlagUntil` (pose
« essoufflé » visible par tous). Le compteur repart à 0 après 1,2 s sans frapper (au-delà du Cooldown de l'objet)
ou si l'objet tenu change. La nourriture (`Eat`) n'est pas concernée.

## B11 / B12 — Windups des attaques et brise-garde

Planchers : toute attaque **Heavy** ≥ 0,25 s de windup, **Unblockable** ≥ 0,35 s, ruées ≥ 0,15 s.
Exclues (réactives, pas de windup au sens strict) : `Counter` (Espresso Shot), `CatBox` (Box Ambush),
`DelReturn` (Return to Sender), `TPTrap` (Shredder Trap), `BarOverload` (Caffeine Overload) ; `DelParcel` et
`FitBall` attendent déjà ≥ 0,26 s en dur.

Brise-garde (`GuardBreak = true`) : au plus 1 par kit de base et 1 par kit transformé — le coup lourd (ni
imparable, ni saisie, ni contre) au windup le plus long, et seulement s'il atteint ≥ 0,28 s. Les autres coups
lourds sont de simples Heavy (drainent la garde ×2,5 sans la briser, règle CombatService). Les kits sans coup assez
télégraphié n'ont pas de brise-garde (le finisher M1 reste disponible).

28 attaques Heavy trop rapides relevées ; tableau des changements :

| Perso | Kit | Attaque | Kind | Windup | GuardBreak |
|---|---|---|---|---|---|
| AIAssistant | transfo | Captcha | AICaptcha | 0.7 → 0.7 | oui |
| Accountant | base | TaxAudit | AcctStampGrab | 0.1 → 0.35 |  |
| Accountant | base | SpreadsheetSlam | Melee | 0.32 → 0.32 | oui |
| Accountant | transfo | BudgetCut | Lunge | — → 0.25 |  |
| Accountant | transfo | Bankrupt | AcctBankrupt | 0.6 → 0.6 | oui |
| Bacon | base | BaconOof | BaconOof | 0.32 → 0.32 | oui |
| Bacon | base | FreeRobux | BaconBait | 0.15 → 0.25 |  |
| Bacon | transfo | NoobRush | BaconRush | 0.15 → 0.25 |  |
| Bacon | transfo | SizzlingPan | BaconPan | 0.55 → 0.55 | oui |
| Bacon | transfo | GreaseSlide | BaconSlide | 0.12 → 0.25 |  |
| Barista | base | EspressoExpress | BarSteamDash | 0.12 → 0.25 |  |
| Barista | transfo | PortafilterSmash | BarLeap | 0.3 → 0.3 | oui |
| Barista | transfo | ToGoOrder | BarToGo | — → 0.25 |  |
| CEO | base | BriefcaseSwing | Melee | 0.28 → 0.28 | oui |
| CEO | base | HostileTakeover | Grab | — → 0.25 |  |
| CEO | transfo | StockCrash | CEOStockCrash | 0.55 → 0.55 | oui |
| Consultant | transfo | GrowthChart | CSGrowth | 0.35 → 0.35 | oui |
| Consultant | transfo | TakeOffline | CSOffline | — → 0.25 |  |
| DeliveryGuy | base | HandTruckRush | DelDolly | 0.15 → 0.25 |  |
| DeliveryGuy | transfo | TapeGun | DelTape | 0.22 → 0.25 |  |
| DeliveryGuy | transfo | FragileCrate | DelCrate | 0.62 → 0.62 | oui |
| FitnessCoach | base | KettlebellSwing | Melee | 0.34 → 0.34 | oui |
| FitnessCoach | base | SpotMe | FitSpot | — → 0.25 |  |
| FitnessCoach | transfo | PushUpShockwave | FitPushUp | 0.45 → 0.45 | oui |
| HRManager | base | TeamBuilding | HRTeamBuilding | 0.2 → 0.25 |  |
| HRManager | transfo | Layoffs | Lunge | — → 0.25 |  |
| HRManager | transfo | TerminationLetter | AoE | 0.45 → 0.45 | oui |
| ITGuy | base | CtrlAltDel | ITTeleport | 0.18 → 0.25 |  |
| ITGuy | base | CableWhip | ITLasso | 0.24 → 0.25 |  |
| ITGuy | transfo | BlueScreen | ITBlueScreen | 0.38 → 0.38 | oui |
| Intern | base | CoffeeRun | Lunge | — → 0.25 |  |
| Intern | base | StickySlap | Melee | 0.15 → 0.25 |  |
| Intern | transfo | DeadlineDrop | SkyDrop | 0.6 → 0.6 | oui |
| Janitor | base | MopSweep | Melee | 0.22 → 0.25 |  |
| Janitor | transfo | SoapSlide | Lunge | — → 0.25 |  |
| Janitor | transfo | BubblePrison | BubblePrison | 0.28 → 0.28 | oui |
| Lawyer | base | GavelSlam | LWGavel | 0.4 → 0.4 | oui |
| Lawyer | transfo | SignHere | LWContract | 0.45 → 0.45 | oui |
| LunchLady | base | LadleBonk | Melee | 0.22 → 0.25 |  |
| LunchLady | transfo | FryingPanSmash | AoE | 0.4 → 0.4 | oui |
| LunchLady | transfo | FoodCartRush | CartRush | 0.12 → 0.25 |  |
| MaintenanceGuy | base | MonkeyWrench | Melee | 0.32 → 0.32 | oui |
| MaintenanceGuy | transfo | ToolboxDrop | MGToolbox | 0.55 → 0.55 | oui |
| MarketingGuru | base | BillboardDrop | MKBillboard | 0.5 → 0.5 | oui |
| MarketingGuru | transfo | Synergy | MKSynergy | 0.3 → 0.3 | oui |
| MarketingGuru | transfo | HypeTrain | Lunge | — → 0.25 |  |
| Mascot | base | FoamFinger | Melee | 0.22 → 0.25 |  |
| Mascot | transfo | HeadBounce | MSHeadBounce | 0.55 → 0.55 | oui |
| OfficeCat | base | CatPounce | CatPounce | 0.42 → 0.42 | oui |
| OfficeCat | transfo | OffTheDesk | CatDesk | 0.32 → 0.32 | oui |
| Receptionist | base | ServiceBell | RecBell | 0.34 → 0.34 | oui |
| Receptionist | transfo | HangUp | RecHangUp | 0.5 → 0.5 | oui |
| Receptionist | transfo | TransferCall | RecTransfer | 0.2 → 0.25 |  |
| SecurityGuard | base | Detain | Grab | — → 0.35 |  |
| SecurityGuard | transfo | WhistleBlast | AoE | 0.3 → 0.3 | oui |
| SecurityGuard | transfo | ElbowDrop | ElbowDrop | 0.2 → 0.25 |  |
| Temp | base | ClockOut | TPVanishDash | 0.14 → 0.25 |  |

> Kinds qui **n'utilisent pas encore** `cfg.Windup` (le champ est posé pour la règle générique de CombatService /
> AbilityService) : `Lunge` et `Grab` (AbilityService), `CSOffline`, `BarToGo`, `FitSpot` (attente en dur 0,12 s).

## B14 — Passifs

| Perso | Passif | Avant | Après |
|---|---|---|---|
| Accountant | Compound Interest | +10 %/coup, max +50 % | +5 %/coup, max +25 % |
| Office Cat | Nine Lives | esquive le 9e coup subi | le 12e, jamais sur un coup imparable |
| Consultant | Move the Needle | KPI max 5 (+20 %) | KPI max 4 (+16 %) |
| Fitness Coach | No Pain No Gain | +20 % dégâts sous 50 % PV | +12 % |
| Delivery Guy | Express Shipping | objets +20 % | objets +15 % (les objets restent sous ~9 DPS) |
| IT Guy | Have You Tried… | électronique +25 % | +15 % |
| Receptionist | Visitor Badge | +15 % de dégâts subis 5 s | +10 % |
| The Bacon | Main Character | +10 % infligés, −15 % subis, Plot Armor : 1 PV + 25 PV + 1,8 s intouchable | plus aucun multiplicateur ; Plot Armor : 1 PV + 10 PV + 1 s intouchable |

Inchangés (dans la norme) : Spam Filter (−30 % projectiles), Extra Shot (+4 tous les 4 coups), Executive Privilege,
Mandatory Meeting, Billable Hours (+6 tous les 5 coups), Duct Tape Fix, Trending, Foam Padding, Nobody Knows My
Name (+5), et les persos de base (`Config/Characters`, hors périmètre).

## The Bacon — perso phare équilibré

Décision du propriétaire : The Bacon reste le perso **phare / légendaire** et le plus cher (Robux), mais il est
**équilibré comme les autres** — son style et son humour font la différence, pas ses chiffres.

- Passif : `DEAL_MULT` / `TAKE_MULT` supprimés (le damageMod correspondant est retiré) ; la Plot Armor (une fois par
  vie) est conservée avec un soin de 10 PV (`OOF_HEAL`) et ~1 s d'invulnérabilité (`OOF_SHIELD` 0,7 + 0,3).
- Attaques : planchers de windup appliqués (Free Robux?, Noob Rush, Grease Slide 0,12–0,15 → 0,25 s) ;
  brise-garde : Oof (base, 0,32 s) et Sizzling Pan (transfo, 0,55 s). Dégâts / cooldowns déjà dans la moyenne.
- Transformation Extra Crispy : vitesse ×1,25 → ×1,2 (comme les persos rapides du roster).
- Textes : en-tête de `Content/Bacon.luau`, description du passif et en-tête de `Config/Unlocks.luau` ne parlent
  plus du « plus fort du jeu » mais du perso phare / légendaire.
