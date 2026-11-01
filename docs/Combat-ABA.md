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
- Dash strike : coup de pied volant lourd, renverse, recharge `Cooldown` 7 s (attribut `CDDashStrike`).

## Block, perfect block, guard break (`Block`)

- Block de face uniquement : `Reduction` 85 % des dégâts, marche à `WalkSpeed` 7. **Jauge de garde** `MaxGuard` 40 :
  chaque coup bloqué la vide de ses dégâts ; elle remonte de `GuardRegen`/s après `GuardRegenDelay` (attribut `Guard`,
  barre sous le viseur).
- **Guard break** : un coup **lourd** (`Category = "Heavy"` dans Config/Attacks, Config/Items, lancers lourds,
  finisher d'objet, 5e M1, uppercut, downslam, dash strike, ou `p.heavy = true`) casse directement un block normal ;
  ou la jauge tombe à 0. Victime étourdie `GuardBreakStun` 1,6 s, ne peut plus bloquer (attribut `GuardBrokenUntil`,
  pose « sonné », « GUARD BREAK! »). Exception : Tray Guard (`p.trayGuard`).
- **Perfect block** : F pressé dans les `PerfectWindow` s avant le coup (spam interdit : `ParryRearm`). Annule le coup,
  même lourd ; l'attaquant est repoussé, étourdi `ParryStun` et désarmé (« PERFECT BLOCK! »). Le block réactivé
  automatiquement (F maintenu à la fin d'un hitstun) ne donne **pas** de perfect block.

## Evasive (`Evasive`)

Q pendant un hitstun : on se libère (suspensions et laisse retirées), `IFrames` 0,5 s d'invulnérabilité, les ennemis
dans `Radius` sont repoussés et étourdis `AttackerStun`. Recharge **18 s** (attributs `CDEvasive` / `CDMaxEvasive`,
icône dans le HUD). **Interdit pendant un guard break** (le block cassé doit rester punissable), quand on est renversé
(déjà intouchable) et quand on est tenu par une ultime.

## Renversé (`Knockdown`)

Finisher, downslam, dash strike : la victime est au sol `Duration` 1 s, **intouchable** (sauf ultimes, `unblockable`),
puis se relève avec `GetUpIFrames` 0,6 s d'invulnérabilité : pas de jongle infini. Attribut `KnockdownUntil`.

## Ressenti

`HitStop` (Light 0,08 / Heavy 0,2 / KO 0,42), `Shake`, `FOVKick` par catégorie (lus par CartoonFX). Côté contrôleur
de combat, le tremblement est multiplié par le réglage joueur `ScreenShake` et le zoom est coupé si `FOVKick` = false.

## Zones sûres

Attribut personnage `SafeZone = true` (zone AFK) : `CombatService.applyHit` ignore tout coup dont la victime OU
l'attaquant est en zone sûre ; M1, dash, objets et attaques sont refusés (`CombatService.canStartAttack`).

## API serveur (compatibles)

- `CombatService.applyHit(p)` : nouveaux champs optionnels `p.heavy`, `p.knockdown` ; nouveau retour `"GuardBreak"`.
- `CombatService.swing(attacker, spec, seq)` -> `landed, hits` (2e retour = vraiment touchés) ; `spec.Heavy`, `spec.Knockdown`.
- `CharacterState.setBlocking(c, on, noParry?)`, `protect(c, duration?, visible?)`, `knockdown(c, duration?)`,
  `guardBreak(c, duration?)`, `drainGuard`, `guardNow`, `isGuardBroken`, `isKnockedDown`, `inSafeZone`.
- `Signals.GuardBroken(victim, attacker)`.
