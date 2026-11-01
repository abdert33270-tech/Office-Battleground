# Combat « ABA » (Office Battlegrounds)

Refonte du combat commun sur le modèle d'**Anime Battle Arena** : plus lent, plus lisible, chaque coup a une anticipation
visible. Toutes les valeurs sont dans `src/ReplicatedStorage/Shared/Config/Combat.luau` (ne rien coder en dur ailleurs).

## Commandes

| Action | PC | Mobile / manette |
|---|---|---|
| Chaîne de M1 (5 coups) | Clic gauche (maintenu = enchaîne) | HIT / R2 |
| **Uppercut** | Espace maintenu sur le **5e** clic | SAUT maintenu + 5e HIT / A + R2 |
| **Downslam** | 5e clic **en l'air** ; ou 3e clic du jongle après un uppercut | idem |
| Block | F maintenu | BLOCK / L2 |
| **Perfect block** | F appuyé **juste avant** le coup (`Block.PerfectWindow` = 0,22 s) | idem |
| **Dash** directionnel | Q + W/A/S/D (relatif à la caméra ; sans direction = avant) | DASH (direction du joystick) / B |
| **Dash strike** | Dash **avant** puis clic dans `DashStrike.Window` (0,4 s) | DASH puis HIT |
| **Evasive** | Q pendant un hitstun | DASH (le bouton affiche « EVADE! ») |

Supprimés : Rising Duo, Uppercut « 3 M1 + Espace », Ground Pin, Dropkick Ctrl+clic, Combo Breaker à 5 coups
(attributs `LiftUp/LiftStall/LiftAt`, `FollowUntil`, `ComboStep`, `AirMax`, `CanBreak`, `CDBreak`, `CDDropkick`).

## Chaîne de M1 (`M1`)

- 5 coups : dégâts `3, 3, 3, 4, 7` ; impact au bout de `Windup` (0,14 → 0,22 s) ; coup suivant après `Cooldown`
  (0,46 – 0,5 s). Coups 1-4 = **vrai hitstun** (`Stun` 0,66 – 0,72 s, victime immobile, petit recul, laisse
  `ComboTether` qui la garde devant l'attaquant). 5e = **FINISHER** lourd : éjection, renversé (knockdown).
- **Endlag** : 1,35 s après le 5e coup (ni attaque, ni dash, ni block). Chaîne lâchée avant le 5e : pas de block ni
  d'attaque de perso pendant `Cooldown + DropEndlag` (0,3 s). Sans clic pendant `ComboReset` (1 s) la chaîne repart à 1.
- L'attaquant est ralenti (`AttackSlow` 0,55) pendant ses M1 ; verrouillage doux (`SoftLock`), mémoire de clic
  (`InputBuffer` 0,25 s), petit pas en avant (`Lunge`) qui recolle à la cible.
- Le client envoie l'index du coup (`mods.i`) ; le serveur ne l'accepte que s'il continue SA chaîne (ou repart de 1).
- Animations, traînées et impacts **par arme / personnage** (même timing que Punch1-5) : voir `docs/M1-Styles.md`.

## Variantes du 5e coup

- **Uppercut** (`Uppercut`) : la victime décolle (`LaunchUp` 58). S'il touche, le serveur pose l'attribut
  `AutoFollow` ; le client de l'attaquant saute tout seul derrière elle (`FollowJump`, `FollowForward`) et dispose de
  `AirWindow` (2,4 s) pour `AirHits` = 3 M1 en l'air, le 3e = **Downslam**. Raté = endlag complet.
- **Downslam** (`Downslam`) : écrase au sol (« PINNED! »), puis renversé ; l'attaquant retombe (attribut `AirRelease`).
- Jongle (`Air`) : chaque coup aérien suspend victime et attaquant `Stall` = 0,5 s.

## Dash (`Dash`) et Dash strike (`DashStrike`)

- Avant / arrière / **côté** (anims `Dash`, `DashBack`, `SideDashL`, `SideDashR`) ; recharge 2 s, 0,2 s de poussée,
  **sans invulnérabilité**. Arrière / côté : le personnage garde l'adversaire en face. Le dash annule une chaîne lâchée
  (jamais un endlag de coup lourd) et le block (il faut rappuyer sur F).
- **Dash cancel** : la chaîne **continue** (serveur et client gardent `combo`) : dash après le 4e coup = le prochain
  clic est le FINISHER (ou un dash strike si dash avant), jamais un retour au 1er coup. Le dash relâche la laisse
  (`ComboTether`) des victimes de l'attaquant : il ne les traîne plus.
- Dash strike : coup de pied volant lourd, renverse, recharge `Cooldown` 7 s (attribut `CDDashStrike`).

## Block, perfect block, guard break (`Block`)

- Block de face uniquement : `Reduction` 85 % des dégâts, marche à `WalkSpeed` 7. **Jauge de garde** `MaxGuard` 40 :
  chaque coup bloqué la vide de ses dégâts ; elle remonte de `GuardRegen`/s après `GuardRegenDelay` (attribut `Guard`,
  barre sous le viseur).
- **Règle du propriétaire** : les coups lourds cassent le block, **sauf perfect block** (qui bat tout). Concrètement :
  - **Casse-garde** (`p.guardBreak` / `spec.GuardBreak`) : **5e M1 (finisher), uppercut, downslam, dash strike**, et les
    attaques de perso marquées `GuardBreak = true` dans leur fiche → cassent **directement** un block normal.
  - **Lourds sans casse-garde** (`Category = "Heavy"` des attaques de perso / objets / lancers, finisher d'objet,
    `p.heavy = true`) → ne cassent plus d'un coup : ils vident la jauge **`HeavyGuardMult` = 2,5×** plus vite
    (ex. 10 dégâts = 25 de garde sur 40). Jauge à 0 = guard break.
- **Guard break** : victime étourdie `GuardBreakStun` 1,6 s, ne peut plus bloquer (attribut `GuardBrokenUntil`,
  pose « sonné », « GUARD BREAK! »). Exception : Tray Guard (`p.trayGuard`).
- **Avantage au bloqueur** : chaque coup bloqué repousse le prochain coup de l'attaquant de `BlockAdvantage` 0,12 s
  (`nextAttack`). Un clic de M1 arrivé pendant ce retard est mis en attente côté serveur et part à la fin (pas perdu).
- **Latence** : l'appui sur F est daté de `min(ping/2, PingAllowance 0,1 s)` plus tôt (`Player:GetNetworkPing`) : la
  fenêtre de perfect block se mesure depuis le vrai moment de l'appui (plus juste, pas plus large).
- Pendant un **endlag** (coup lourd ou attaque de perso) le block est refusé ; F maintenu le lève à la fin, **sans**
  fenêtre de perfect block (pas de parade « bufferisée » pendant l'endlag).
- **Perfect block** : F pressé dans les `PerfectWindow` s avant le coup. Annule le coup, même lourd ; l'attaquant est
  repoussé, étourdi `ParryStun` et désarmé (effet `PerfectBlock`). Anti-spam : `ParryRearm` (0,5 s) entre deux
  appuis, et une tentative **ratée** (fenêtre écoulée sans coup) verrouille la parade `ParryFailRearm` (1 s) après la
  fin de la fenêtre : rappuyer sur F pendant ce verrou donne un block normal. Taper F en boucle ≈ 15 % du temps en
  fenêtre (au lieu de 44 %). Maintenir F ne renouvelle jamais la fenêtre ; le block réactivé automatiquement
  (F maintenu à la fin d'un hitstun) ne donne **pas** de perfect block.

## Evasive (`Evasive`)

Q pendant un hitstun : on se libère (suspensions et laisse retirées), `IFrames` 0,5 s d'invulnérabilité, les
**attaquants récents** de l'évadé (touché dans les `AttackerMemory` 2 s, ou qui le tenaient en laisse) dans `Radius`
sont repoussés et étourdis `AttackerStun` — plus les passants. Recharge **18 s** (attributs `CDEvasive` / `CDMaxEvasive`,
icône dans le HUD). **Interdit pendant un guard break** (le block cassé doit rester punissable), quand on est renversé
(déjà intouchable) et quand on est tenu par une ultime.

## Renversé (`Knockdown`)

Finisher, downslam, dash strike : la victime est au sol `Duration` 1 s, **intouchable** (sauf **ultimes** :
`category = "Ultimate"` ou `p.ultimate` ; les prises « imparables » — Detain, Tax Audit, Box Ambush, Espresso Counter… —
**ne** passent **pas** : `applyHit` renvoie nil, et `Kinds.Grab` ne saisit pas une victime au sol),
puis se relève avec `GetUpIFrames` 0,6 s d'invulnérabilité : pas de jongle infini. Attribut `KnockdownUntil`.
Effet `Knockdown` (poussière + thud) envoyé quand la victime touche le sol (sauf downslam : l'effet `Slam` suffit) ;
ProcAnim joue `GetUp` automatiquement à la fin du renversé (relevé lisible).

## Anti-infini (`ComboCap`)

Chaque victime suit son **combo vrai** (coups reçus pendant son hitstun, `Grace` 0,05 s). **Tous** les coups comptent :
M1, jongle, objets (ItemService), attaques de perso, zones… — `chainLinks += (p.tether and 1 or (p.linkWeight or 1))`.
Une attaque multi-coups (`Hits` > 1) compte `max(0,25, 2/Hits)` par coup et un cône continu ≈ 2 liens au total
(surchargeable par `LinkWeight` dans la fiche). Dès `MaxLinks` = 9 liens ou `MaxTime` = 4,8 s, le coup suivant
**renverse de force** (knockdown + relevé invulnérable, « BREAK AWAY! »). Combo légitime : 4 M1 + uppercut + 2 en l'air
= 7 liens, puis downslam (renverse) → passe, avec la place pour une attaque / un objet. **Seules les ultimes** sont
exemptées. Le compteur repart après un renversé ou quand la victime a récupéré.

## Coup fatal (`PendingKO`)

Un coup fatal est **engagé** : `state.pendingKO` + attribut `PendingKO`, victime étourdie pendant le hit-stop K.O.,
EVASIVE refusée, `applyHit` ignore tout autre coup sur elle ; à la fin du gel `Health = 0` est posé directement
(une bulle ForceField apparue entre-temps ne la sauve pas). Plot Armor de Bacon agit avant (dans `damageMods`) :
un coup qu'elle sauve n'est jamais fatal.

## Endlag visible

Coup lourd (finisher, uppercut raté, downslam, dash strike) : attribut `EndlagUntil` (server time) ; ProcAnim tient la
pose `Winded` (buste plié, bras ballants) tant qu'il n'est pas passé → l'attaquant est lisiblement punissable.

**Attaques de perso** (AbilityService) : pendant l'anticipation + la phase active estimée (`Windup + Time + HoldTime +
0,35`, borné 0,35–2,5 s) ni M1, ni block, ni autre attaque ; puis **endlag** `cfg.Endlag` (secondes, 0 = aucun) ou
`AbilityEndlag` = `{ Heavy = 0,45, Light = 0,25 }` selon `Category`, posé **quand le Kind se termine** (ou au plus tard au
bout de la phase active estimée pour les Kinds qui laissent tourner un effet). Kinds « posés » (Zone, Barrier, Buff,
Guard) : endlag dès le lancement (Guard : 0 par défaut). Attaque interrompue (lanceur étourdi) : pas d'endlag.
`CharacterState.endlag(c, d)` pose `busyUntil`, `endlagUntil`, `nextAttack` et `EndlagUntil` ; dash et block refusés.

## Anticipation interruptible, télégraphes, super armure

`AbilityService.windup(attaquant, t, cfg?, tele?)` (aussi `api.windup` pour les Kinds de Content) attend `t` s et
renvoie **false** si le lanceur est étourdi, meurt ou réapparaît pendant l'attente : l'attaque est annulée. Utilisé par
Melee, AoE, Cone, Lunge (qui vérifie en plus l'étourdissement à **chaque pas** de la charge), Grab (qui lâche la victime
si le lanceur est étourdi pendant la prise), Slam (descente). Toute anticipation ≥ `TelegraphMin` 0,12 s envoie un
`{k="Telegraph"}` (forme déduite de la fiche : Cone si `Range`+`Angle`, Box si `HitboxSize` — couloir parcouru pour
Lunge —, Circle si `Radius` ; `tele = false` si le Kind envoie le sien). **Super armure** uniquement si
`cfg.Armor == true` : pendant l'anticipation les coups font leurs dégâts sans hitstun, recul, laisse ni renversé (ni
lien d'anti-infini) ; casse-garde et ultimes la percent et interrompent.

## Compensation de latence (hitboxes)

`Hitbox.startHistory()` (lancé par CombatService) garde ~1 s de CFrames de HumanoidRootPart par personnage (20 Hz).
`CombatService.swing` et les Kinds Melee / Grab appellent `Hitbox.box(cf, size, exclude, max, rewind)` avec
`rewind = CombatService.rewindFor(attaquant)` = `GetNetworkPing()` borné à `LagComp.MaxRewind` 0,15 s (0 pour un PNJ) :
une victime est touchée si elle est dans la boîte **maintenant ou** à sa position d'il y a `rewind` s.

## Ressenti

`HitStop` (Light 0,08 / Heavy 0,2 / KO 0,42), `Shake`, `FOVKick` par catégorie (lus par CartoonFX). Le réglage
joueur `ScreenShake` est appliqué une seule fois (dans `CartoonFX.shake`), le zoom est coupé si `FOVKick` = false.

**Prédiction** (attaquant) : étincelles, impact, sons, réaction, hit-stop et caméra partent tout de suite ; les mots,
le chiffre de dégâts et le K.O. attendent le `Hit` serveur du même `seq` (CombatController `confirmHit`). Un coup
parré / bloqué au dernier moment n'affiche donc jamais de dégâts. Cibles qui bloquent : rien n'est prédit.

**Effets serveur** : `{type="PerfectBlock", character, a, p}` (remplace `Parry` + `ComboName`), `{type="BlockHit", p,
dir, v, a, d}` (remplace `Block` pour les coups bloqués de CombatService), `{type="GuardBreak"...}` inchangé
(`k="GuardBreak"`), `{type="DashFX", character, dir, skipSelf=true}` (remplace `Dash` ; le client envoie sa direction
en 2e argument de la remote `Dash`), `{type="Knockdown", v, p}`.

## Zones sûres

Attribut personnage `SafeZone = true` (zone AFK) : `CombatService.applyHit` ignore tout coup dont la victime OU
l'attaquant est en zone sûre ; M1, dash, objets et attaques sont refusés (`CombatService.canStartAttack`).

## API serveur (compatibles)

- `CombatService.applyHit(p)` : champs optionnels `p.heavy`, `p.guardBreak`, `p.knockdown`, `p.ultimate`,
  `p.linkWeight` ; retour `"GuardBreak"`. `p.unblockable` traverse le block, plus le renversé ni l'anti-infini.
- `CombatService.swing(attacker, spec, seq)` -> `landed, hits` ; `spec.Heavy`, `spec.GuardBreak`, `spec.Knockdown`,
  `spec.LinkWeight`. `CombatService.rewindFor(attacker)`.
- `CharacterState.endlag(c, d)`, `inEndlag(c)`, `hasArmor(c)` ; `Hitbox.startHistory`, `Hitbox.rootAt(c, t)`.

## Points d'entrée PNJ (bot d'entraînement)

Mêmes règles que les remotes, sans `Player` et **sans limite de débit** (`Net.allow` reste sur les remotes). Le PNJ
est un Model avec `Humanoid` + `HumanoidRootPart`, rangé dans `workspace.Dummies` (sinon intouchable :
`Hitbox.characters`), `CharacterState.setup(model)` appelé, physique possédée par le serveur.

- `CombatService.performM1(c, mods?)` -> bool ; `mods = { i = 1..5, up = bool (uppercut), air = bool }`.
- `CombatService.performBlock(c, on, auto?)` -> bool (true = garde levée / baissée tout de suite). Le perfect block
  s'obtient en levant la garde juste avant l'impact ; rabaisser puis relever (respecter `ParryRearm`).
- `CombatService.performDash(c, kind?, dir?)` -> `"Dash"` | `"Evasive"` (si étourdi) | nil ; `kind` = "F"|"B"|"L"|"R".
  Pour un PNJ le serveur applique la poussée (`DashPush`).
- `AbilityService.performAbility(c, slot, aim?)` -> bool (kit via `AbilityService.getKit`).
- Limites : pas de saut auto après uppercut ni de petit pas des M1 (faits par le client du joueur).
- `CharacterState.recentAttackers(victim, window)` -> liste des attaquants récents.
- `CharacterState.setBlocking(c, on, noParry?)`, `protect(c, duration?, visible?)`, `knockdown(c, duration?)`,
  `guardBreak(c, duration?)`, `drainGuard`, `guardNow`, `isGuardBroken`, `isKnockedDown`, `inSafeZone`.
- `Signals.GuardBroken(victim, attacker)`.
