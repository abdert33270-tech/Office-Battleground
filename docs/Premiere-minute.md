# Première minute (Office Battlegrounds)

Objectif : un nouveau joueur comprend le jeu et donne ses premiers coups en moins d'une minute, sans écran bloquant.

## 1. Écran de chargement — `src/ReplicatedFirst/LoadingScreen.client.luau`

- `ReplicatedFirst:RemoveDefaultLoadingScreen()` juste après avoir affiché notre propre `ScreenGui` (`DisplayOrder` 1000).
- Titre « OFFICE BATTLEGROUNDS » en Press Start 2P (jaune, contour encre, ombre orange), textes en Silkscreen.
  UITheme n'est pas encore répliqué dans ReplicatedFirst : les couleurs du thème y sont **recopiées** (à garder alignées).
- Barre de progression : 70 % = `ContentProvider:PreloadAsync` (polices via les TextLabels + 8 sons recopiés de
  `Config/Sounds`), 15 % = `game:IsLoaded()`, 15 % = ScreenGui `HUD` présent dans le PlayerGui.
- Fondu (`CanvasGroup.GroupTransparency`) dès que tout est prêt (minimum 1,5 s), au plus tard après **15 s**.
- Astuces de bureau tirées au hasard toutes les 3,5 s. Colonne bornée (`UISizeConstraint` 760×420) : OK téléphone.
- Projet Rojo : `default.project.json` → `"ReplicatedFirst": { "$path": "src/ReplicatedFirst" }`.

## 2. Première apparition sans danger

- **PlayerService** : la première apparition de la session reçoit une bulle `ForceField` **visible**
  nommée `FirstSpawnShield` pendant 12 s. Si le joueur choisit son perso plus tard (remote `SelectCharacter`),
  les 12 s repartent de ce choix (plafond 40 s après l'apparition). La bulle saute dès la première attaque
  (remotes `Attack`, `Ability`, `Throw`, `Ultimate`). La protection habituelle de 3 s (`CharacterState.protect`) reste.
- **CharacterSelectController** : la **première** ouverture de la session n'a pas de choix automatique
  (« Take your time »). Les ouvertures suivantes avec `withTimer` gardent le compte à rebours de 8 s.
  Grille triée : persos phares (`Featured`, ruban LEGENDARY, ex. The Bacon) en tête, puis possédés / gratuits,
  puis verrouillés ; à égalité, l'ordre de `Config/Characters.Order`. Le tri est réappliqué à chaque `paintLocks`
  (achat, état de déblocage).

## 3. Premier match guidé — `Config/Tutorial`, `TutorialService`, `TutorialController`

Liste NON bloquante en haut au centre (sous la sélection de perso et les panneaux Meta), flèches au-dessus du
mannequin / de l'objet le plus proche / du bouton concerné (HUD `Slot1` / `SlotQ`, `MobileControls`, `MetaDock` Daily).

| Étape | Validation serveur |
|---|---|
| Frapper le mannequin ×5 | `Signals.Hit` (attaquant = joueur, victime `IsDummy`) |
| Bloquer | `Signals.Blocked` / `Signals.Parried`, ou garde (`Blocking`) tenue 1,2 s (jeu en solo) |
| Dash | `CharacterState.lastDash` modifié (dash accepté par CombatService) |
| Capacité 1 | remote `Ability(1)` + `gcdUntil` posé par AbilityService |
| Ramasser et lancer | l'objet tenu (`held`) quitte la main après un remote `Throw` |
| (optionnel) Ouvrir DAILY | signalé par le client à l'ouverture de `Meta.DailyPanel` (aucune récompense propre) |

- Étapes requises dans l'ordre ; seule l'étape en cours progresse.
- Données : `data.Tutorial = { Done, Steps = {[id] = n}, Skipped?, Rewarded? }` (créé par TutorialService).
  Profil **neuf** (XP = 0 et KOs = 0) → tutoriel ; ancien profil sans champ → `Done = true` (jamais montré).
  Chargement échoué (`DataService.loadFailed`) → pas de tutoriel cette session.
- Récompense **une seule fois** à la fin : `SkinService.addCash(500, "Training complete!")` + `SkinService.addCrates(1)`
  (Mystery Briefcase). Bouton **SKIP** (deux appuis) : `Done = true`, sans récompense.
- Remote `Tutorial` : client → `"State" | "Skip" | "Daily"` ; serveur → `{ active, done, current, steps, finished?, reward? }`.
  Attribut Player `TutorialDone`.
- Téléphone (petit écran) : en-tête + étape en cours seulement.

## 4. Carte des contrôles — `HintController`

- À la première apparition de la session (si `TutorialDone` n'est pas vrai) : carte refermable (« GOT IT! »)
  avec les commandes de l'appareil actif : `UserInputService.PreferredInput` (pcall), sinon `GetLastInputType()`.
  Clavier/souris, tactile, manette ; reconstruite si l'appareil change.
- Rouvrable : bouton « ? » à gauche du bandeau de commandes, touches **H** / **?** (Maj + /), **croix haut** (manette).
- API : `HintController.device()`, `onDeviceChanged(fn)`, `showControls()`, `hideControls()`, `toggleControls()`.
- Le bandeau de commandes a maintenant une variante manette (R2, L2, B, X, Y).
- Calculs de couleur / taille d'écran protégés (`tonumber`) : le test de fumée hors Studio passe.

## Tester

- Profil neuf en Studio (sans accès API : mémoire seule) → liste TRAINING + carte des contrôles.
- `ReplicatedStorage:SetAttribute("DebugTouch", true)` → textes / flèches tactiles.
- Vérifier la récompense : +500 Cash, `Crates` +1, puis plus jamais de liste (même session ou reconnexion).
