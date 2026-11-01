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
- **Guard break** : un coup **lourd** (`Category = "Heavy"` dans Config/Attacks, Config/Items, lancers lourds,
  finisher d'objet, 5e M1, uppercut, downslam, dash strike, ou `p.heavy = true`) casse directement un block normal ;
  ou la jauge tombe à 0. Victime étourdie `GuardBreakStun` 1,6 s, ne peut plus bloquer (attribut `GuardBrokenUntil`,
  pose « sonné », « GUARD BREAK! »). Exception : Tray Guard (`p.trayGuard`).
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

Finisher, downslam, dash strike : la victime est au sol `Duration` 1 s, **intouchable** (sauf ultimes, `unblockable`),
puis se relève avec `GetUpIFrames` 0,6 s d'invulnérabilité : pas de jongle infini. Attribut `KnockdownUntil`.
Effet `Knockdown` (poussière + thud) envoyé quand la victime touche le sol (sauf downslam : l'effet `Slam` suffit) ;
ProcAnim joue `GetUp` automatiquement à la fin du renversé (relevé lisible).

## Anti-infini (`ComboCap`)

Chaque victime suit son **combo vrai** (coups reçus pendant son hitstun, `Grace` 0,05 s). Dès `MaxLinks` = 7 coups
« collants » (M1 1-4 et coups en l'air) ou `MaxTime` = 4,8 s de combo, le coup suivant **renverse de force**
(knockdown + relevé invulnérable, mots « BREAK AWAY! »). Le combo complet légitime (4 M1 + uppercut + 2 en l'air +
downslam = 6 collants, ~3,5 s) passe. Les ultimes (`unblockable`) ne sont pas concernées. Le compteur repart après
un renversé ou quand la victime a récupéré.

## Coup fatal (`PendingKO`)

Un coup fatal est **engagé** : `state.pendingKO` + attribut `PendingKO`, victime étourdie pendant le hit-stop K.O.,
EVASIVE refusée, `applyHit` ignore tout autre coup sur elle ; à la fin du gel `Health = 0` est posé directement
(une bulle ForceField apparue entre-temps ne la sauve pas). Plot Armor de Bacon agit avant (dans `damageMods`) :
un coup qu'elle sauve n'est jamais fatal.

## Endlag visible

Coup lourd (finisher, uppercut raté, downslam, dash strike) : attribut `EndlagUntil` (server time) ; ProcAnim tient la
pose `Winded` (buste plié, bras ballants) tant qu'il n'est pas passé → l'attaquant est lisiblement punissable.

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

- `CombatService.applyHit(p)` : nouveaux champs optionnels `p.heavy`, `p.knockdown` ; nouveau retour `"GuardBreak"`.
- `CombatService.swing(attacker, spec, seq)` -> `landed, hits` (2e retour = vraiment touchés) ; `spec.Heavy`, `spec.Knockdown`.
- `CharacterState.recentAttackers(victim, window)` -> liste des attaquants récents.
- `CharacterState.setBlocking(c, on, noParry?)`, `protect(c, duration?, visible?)`, `knockdown(c, duration?)`,
  `guardBreak(c, duration?)`, `drainGuard`, `guardNow`, `isGuardBroken`, `isKnockedDown`, `inSafeZone`.
- `Signals.GuardBroken(victim, attacker)`.
