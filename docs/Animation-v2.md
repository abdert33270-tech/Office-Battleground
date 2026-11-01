# Animation v2 — ProcAnim, locomotion, réactions, dash, lock-on

Fichiers : `Shared/Modules/ProcAnim.luau`, `StarterCharacterScripts/Animate.client.luau`,
`Controllers/CombatController.luau`, `Controllers/RunController.luau`, `Shared/Modules/CartoonFX.luau` (réactions).

## 1. Format des keyframes (ProcAnim v2)

```lua
{ t = 0.22, e = "back",
  RS = { p, y, r }, LS = {…}, RH = {…}, LH = {…},     -- épaules / hanches
  RJ = { tw, ln, sd, dy, dz },                          -- buste + translation du corps
  N  = { p, y, r } }                                    -- cou (NOUVEAU)
```

| Canal | Sens (+) | Unité |
|---|---|---|
| `p` (membre) | vers l'avant | rad |
| `r` (membre) | **vers l'extérieur** (voir §6) | rad |
| `RJ.tw` | rotation à gauche (épaule droite en avant) | rad |
| `RJ.ln` | penché en avant | rad |
| `RJ.sd` | penché à gauche | rad |
| `RJ.dy` | **hauteur du corps** (négatif = accroupi) | studs |
| `RJ.dz` | **translation vers l'avant** (fente) | studs |
| `N.p` | baisser la tête | rad |
| `N.y` | tourner la tête à gauche | rad |
| `N.r` | pencher la tête à gauche | rad |

`e` = easing du segment qui **arrive** sur la clé : `"out"` (défaut, comportement v1), `"in"`, `"inout"`,
`"linear"`, `"back"` (dépasse légèrement puis revient : claquement d'impact). Les temps des clés ne bougent pas :
l'impact reste pile au Windup de `Config/Combat`.

Toutes les anciennes animations restent valides (canaux absents = pose de maintien). Le miroir `_L` gère aussi
`N` (y, r inversés) et `RJ.dy/dz` (inchangés).

### Maths R6 (sans Studio)
- `RootJoint.C0 = Angles(-π/2, 0, π)` : axes locaux du C0 dans le repère du HumanoidRootPart = X → gauche,
  Y → arrière, Z → haut. Donc `C0 = base * CFrame.new(0, -dz, dy) * Angles(ln, sd, 0) * Angles(0, 0, tw)`.
- `Neck.C0 = CFrame.new(0,1,0) * Angles(-π/2, 0, π)` : même rotation dans le repère du Torse →
  `C0 = base * Angles(0, 0, y) * Angles(p, r, 0)` (lacet d'abord, puis tangage dans le repère tourné).
- Pencher le buste (`ln`) soulève les pieds d'environ `3·(1 − cos ln)` ; écarter une jambe de θ les soulève de
  `2·(1 − cos θ)`. Un accroupi = `dy` négatif **compensé** par l'écart des jambes (pas de genoux en R6), sinon
  les pieds passent sous le sol. Les valeurs de `dy` des nouvelles animations suivent cette règle.

## 2. Animations mises à jour
- `Punch5`, `Uppercut`, `Downslam`, `DashStrike`, `Dash`, `DashBack`, `SideDashL/R` : accroupi à l'armé, extension
  / fente à l'impact (easing `back`), réception écrasée, tête qui reste sur la cible.
- Générateurs d'archétypes (`swing`, `up`, `slam`, `dash`) : tous les **finishers** (5e coup) des styles
  reçoivent automatiquement l'enroulé accroupi en 2 temps + la fente ; les coups 1-4 un léger poids du corps.
- Poses tenues `Block`, `Stunned`, `GuardBroken`, `Winded` : corps abaissé, tête basse.

## 3. Locomotion procédurale (remplace l'Animate par défaut)
- `StarterCharacterScripts/Animate` (LocalScript du même nom = remplace celui de Roblox) : pistes Animator R6
  standard pour **saut 125750702, chute 180436148, escalade 180436334, assis 178130996, outil 182393478**
  (nage = marche 180426354 au ralenti). Jouées par le propriétaire → répliquées à tous.
- Repos / marche / course : **ProcAnim**, sur chaque client, pour chaque personnage joueur (et
  `workspace.Dummies`) à moins de 120 studs de la caméra (au-delà de 60 studs : une image sur deux).
  - Garde de combat par archétype (`M1Style.resolve`, relu chaque seconde) : Fists, Brawler (rebond), Blunt, Heavy,
    Long, Slap, Claws, Tech, Bacon ; miroir si l'arme fétiche est en main gauche ; `Relaxed` en zone AFK.
  - Respiration (buste, épaules, tête).
  - Foulée phasée par `AssemblyLinearVelocity` : fréquence `3 + 0,45·vitesse` rad/s ; marche complète à 8 studs/s,
    course complète à 24 studs/s (penché, bras qui pompent) ; déplacement latéral = jambes qui s'écartent.
- Neutre (les pistes Animator dominent) : en l'air (autres joueurs : vitesse verticale + rayon 10×/s), assis,
  escalade, ragdoll, renversé, `UltAnchor` / `UltActive` / `UltHeld`. Transition lissée (pas de saut de pose).
- Priorités : action (`play`) > pose tenue (`HoldPose`, block, stun…) > locomotion. Une action remplace la
  locomotion joint par joint ; fondu d'entrée (clé t = 0) et de sortie (0,12 s, smoothstep).
- `playFrames` (ultis, UltKit) : les joints absents retombent sur une pose **neutre** (pas de garde) : les poses
  d'ulti restent exactes.
- Une action ProcAnim en l'air atténue la piste saut / chute (poids 0,15) pour que le coup se lise.

## 4. Tête
- Pendant un M1 (toute anim de `Config/M1Styles.Moves` sauf `Item`), la tête suit la cible : celle du soft-lock
  (`ProcAnim.setLookTarget`, joueur local) ou, pour les autres, l'ennemi le plus proche devant (< 11 studs).
- Débattement par rapport au root : lacet ±0,7, tangage ±0,45 ; compense 60 % de la rotation du buste.
- Le lock-on garde la tête sur la cible verrouillée.

## 5. Réactions directionnelles (`ProcAnim.reactionFor`, `CartoonFX.reaction`)
Direction de l'attaquant comparée au `LookVector` / `RightVector` de la victime :
- en l'air (coup léger) → `AirHit` ; derrière (dot < −0,4) → `HitBack` (aussi pour les lourds) ;
- côté droit / gauche (|dot droite| > 0,5) → `HitLightR` / `HitLightL` ; de face → `HitLight` / `HitLight2` ;
- lourd → `HitHeavy`, lancé → `Launch`. Coup bloqué → `BlockPush` sur le bloqueur (`CartoonFX.blockHit`).

## 6. Signe de `r` (important)
Le calcul du C0 R6 (et une vérification en jeu notée dans SkinRevealController) donne **r > 0 = membre écarté
vers l'extérieur**. L'ancien en-tête de ProcAnim disait l'inverse, et beaucoup d'animations existantes (ProcAnim,
Ultimates, Content) ont été écrites avec `r < 0` pour « écarter » : elles ramènent en fait le membre devant le
corps. Elles n'ont **pas** été modifiées (risque de casser des poses validées à l'œil, dont celles de
SkinRevealController). Les nouvelles animations v2 utilisent le bon signe. À corriger au cas par cas en jeu.

## 7. Combat côté client (CombatController)
- **Coups fantômes** : aucune prédiction sur une victime dont `EvasiveAt` (heure serveur) ou `Blocking` a changé
  depuis moins de 0,25 s. Ping > 120 ms : seuls étincelle + son sont prédits ; impact, réaction, hit-stop et
  caméra sont joués à la confirmation du serveur (`predicted[seq][victime] = "lite"`).
- **Endlag** (`EndlagUntil`, heure serveur) : ni dash ni block prédits tant qu'il dure.
- **Avantage au bloqueur** : à la réception d'un `BlockHit` dont on est l'attaquant, le prochain M1 local est
  retardé de `Block.BlockAdvantage` (le clic part de la mémoire tampon, une seule fois).
- **Dash** : la remote reçoit toujours `(kind, direction)` tout de suite (timing serveur inchangé).
  Avant : 0,06 s d'accroupi (anim `Dash`) puis poussée. Côté : **orbite** autour de la cible du soft-lock
  (vitesse tangentielle recalculée à chaque image + rappel radial, ≤ ~100° par dash), face à la cible.
- **Lock-on** : clic molette (MouseButton3) / R3. Caméra scriptée au milieu soi / cible, décalée sur l'épaule
  droite (2,2 studs), distance 10–22 selon l'écart, anti-murs ; perso tourné vers la cible (sauf shift lock).
  Relâché : cible morte, > 60 studs, ma mort / respawn, zone AFK, plan d'ulti (`UltKit.cameraBusy()` ou attributs
  `UltActive` / `UltAnchor` / `UltHeld`). La cible verrouillée est prioritaire pour le soft-lock des coups.

## 8. Course (RunController)
Double W (inchangé), L3 manette, bouton RUN mobile, **et maintien de Ctrl gauche** sur PC (Shift est déjà le shift
lock maison de ShiftLockController). Ctrl tenu : la course reprend dès qu'on rebouge.
