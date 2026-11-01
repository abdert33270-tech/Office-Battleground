# Entraînement : mannequins, relevé de combo, bot de sparring

Fichiers : `Services/DummyService.luau`, `Services/TrainingService.luau`, `Services/SparringBotService.luau`,
`Services/RigBuilder.luau` (rig R6 + étiquette `RigBuilder.tag`), `Controllers/TrainingController.luau` (menus + relevé).
Toutes les valeurs de combat viennent de `Config/Combat` et `Config/Attacks` (voir `docs/Combat-ABA.md`).

## Mannequins (`DummyService`)

- Un mannequin « Coworker » par étage (`COUNT`), posé sur `DummySpawns`, dans `workspace.Dummies`, attribut
  `IsDummy = true` : **aucune récompense** (DataService, TaskService, KillFeedService ignorent `IsDummy`).
- **PV remplis 3 s** (`REFILL_DELAY`) après le dernier échange (coup reçu, donné, bloqué ou paré). Un K.O. reste
  possible : réapparition 4 s plus tard, **avec le même mode**. Un nouvel étage (`DummyService.respawn`) remet Idle.
- Étiquette au-dessus de la tête : `DUMMY · <MODE>`.

### Modes (attribut `DummyMode`)

| Mode | Comportement |
|---|---|
| `Idle` | Ne fait rien. |
| `Block` | Garde levée en permanence (block **normal**, pas de perfect block), se tourne vers l'attaquant le plus proche. La jauge de garde et le guard break s'appliquent normalement. |
| `PerfectBlock` | Dès qu'un attaquant proche (14 studs, joueur ou bot) **lance** un coup (son `nextAttack` ou son délai global d'attaque avance côté serveur), le mannequin se tourne, bloque et garde la fenêtre de perfect block ouverte pendant la menace (0,45 s pour un M1, 1,2 s pour une attaque de perso) : tout coup de face est **paré** (l'attaquant est étourdi). Sert à apprendre à ne pas spammer. |
| `CounterM1` | Après votre combo (quand son étourdissement se termine, attaquant à moins de 8 studs), riposte avec **2 M1** (recharge 1,8 s). |
| `Evasive` | Au **3e coup** d'un même combo (coup reçu pendant l'étourdissement du précédent), fait une **EVASIVE** (se libère, i-frames, repousse les attaquants récents). Pas de recharge pour le mannequin. |

### Choix du mode

`ProximityPrompt` **« DummyModePrompt »** sur le mannequin (touche **V**, manette D-pad haut ; E = ramasser et
G = transformation sont déjà pris) → menu `TrainingController` → remote `Training` `("SetMode", dummy, mode)`.
Le serveur valide : mannequin connu de DummyService, vivant, joueur à moins de 16 studs, mode existant, limite de
fréquence (6/s via `Net.allow`).

## Relevé d'entraînement (`TrainingService` + `TrainingController`)

Quand le **joueur local** touche un mannequin ou un bot (`IsDummy`), le serveur lui envoie `("Readout", data)` à
partir des **mêmes événements que les dégâts** : `Signals.Hit` (et `Blocked`, `Parried`, `GuardBroken`).

- **Coups** du combo et **dégâts** cumulés.
- **DROPPED** : l'étourdissement de la victime s'est terminé entre deux coups (lu au moment du `Hit`, avant que le
  nouveau coup n'étourdisse : `Signals.Hit` est appelé de façon synchrone avant `CharacterState.stun`). Un coup qui
  termine normalement un combo (catégorie Heavy sauf Uppercut : finisher, downslam, dash strike…) ne déclenche pas
  DROPPED au coup suivant. Plus de 3 s sans coup = nouveau combo silencieux.
- **Dernier coup** + **windup / endlag** lus dans Config : M1 n° (`M1.Windup[i]` / `M1.Cooldown[i]`), M1 aérien
  (`Air`), `Uppercut`, `Downslam`, `DashStrike`, attaques de perso (`Config/Attacks` : `Windup`, `Endlag` ou
  `AbilityGCD`), objets (`Config/Items` : `Use.Windup` / `Use.Cooldown`).
- Événements : `BLOCKED!`, `PARRIED!` (remet le combo à zéro), `GUARD BREAK!`.
- Panneau à droite de l'écran (UIKit / UITheme), caché après 5 s sans coup.

## Bot de sparring (`SparringBotService`)

- Rig R6 (`RigBuilder.r6`) dans `workspace.Dummies`, attributs `IsDummy = true`, `IsBot = true`,
  `BotDifficulty`, `BotOwner` (UserId, 0 = admin). Les effondrements de FloorService / EventService le traitent
  comme un mannequin (protection, chute, téléportation vers le nouvel immeuble) ; l'IA se met en pause pendant
  `World.collapsing`.
- **Apparition** :
  - `/bot <easy|normal|hard>` (admins, via `AdminService.isAdmin` en lecture seule ; chat `Player.Chatted` +
    `TextChatCommand` `OB_bot`), `/bot clear` retire tous les bots.
  - Borne **SPAR** (`SparStation`, `ProximityPrompt` « SparPrompt », touche V) posée à côté des mannequins de
    l'étage ; menu de difficulté pour tout le monde → `("Spar", difficulté)` / `("DismissBot")`. Validé : joueur
    vivant à moins de 18 studs de la borne. Un bot par joueur (le précédent est remplacé).
  - **2 bots max** par serveur (`MAX_BOTS`).
- **Disparition** : 3 min sans combat (`IDLE_TIME`), 3 s après sa mort, quand son joueur quitte, chute hors carte.
- **IA** (tick 0,05 s) : cible = son joueur (sinon le joueur le plus proche, hors zone sûre) ; s'approche
  (court au-delà de 18 studs), chaîne de M1, attaque de perso générique (`StickySlap`, `MopSweep`, `WhistleBlast`
  ou `FryingPanSmash`, avec son télégraphe AbilityService) toutes les ~8 s, **réagit** au début d'attaque de la
  cible (windup du M1 / télégraphe d'attaque de perso, vus côté serveur) en bloquant (fenêtre de perfect block
  ouverte à l'appui : parade si la réaction tombe juste) ou en dashant de côté / en arrière.

| Difficulté | Réaction | Chance de réagir | Chaîne M1 | Attaque de perso | EVASIVE |
|---|---|---|---|---|---|
| Easy | 0,42 s | 30 % | 2-3 coups | ~10 s | jamais |
| Normal | 0,24 s | 55 % | 3-5 coups | ~8 s | au 5e coup subi |
| Hard | 0,11 s | 85 % | 5 coups | ~7 s | au 3e coup subi |

## Actions de PNJ (`TrainingService.npc`)

`m1(model, i)`, `block(model, on, allowParry)`, `dash(model, kind)`, `evasive(model)`, `face(model, pos)`,
`canM1(model)`. Elles appellent `CombatService.performM1(character, mods)`, `performBlock(character, on)`,
`performDash(character, kind)` quand ils existent (détection + `pcall`), sinon un **repli** : chaîne de M1 recopiée
de Config (`CombatService.swing`), `CharacterState.setBlocking`, dash par `LinearVelocity`, EVASIVE émulée
(attaquants repoussés par un `applyHit` sans dégâts). `performDash` renvoie `"Dash"` / `"Evasive"` / nil ;
`performBlock(c, on, auto)` : `auto = true` = pas de perfect block. Les bots n'ont pas de kit de perso :
`AbilityService.performAbility` n'est pas utilisé, l'attaque générique passe par `AbilityService.api.Kinds`.

## Remote `Training`

Client → serveur : `("SetMode", dummy, mode)`, `("Spar", difficulté)`, `("DismissBot")` — distribués par
`TrainingService.handlers[op]`. Serveur → client : `("Readout", data)`.
