# Interface v3 : un dock, un panneau, liste des joueurs, classements, contrats, titres

Textes du jeu en anglais, tout est auto-chargé (aucun câblage).

## 1. Un seul dock (`MetaDockController`)
- Tous les boutons de menu sont dans le dock unique (ScreenGui `MetaDock`, DisplayOrder 4). `HUD.addMenuButton(text, color, cb, order)` délègue à `MetaDock.addButton` (id = 1er mot : `Character`, `Tasks`, `Shop`, `Combos`, `Admin`).
- Ordre : CHARACTER 2, TASKS 4, COMBOS 5, SHOP 6, PLAYERS 7, RANKS 8, DAILY 10, CODES 20, SETTINGS 30, AFK 40, ADMIN 95.
- PC : colonne en bas à gauche (sous la carte de statut). Mobile : **2 rangées** de tuiles 72 px en haut à gauche, sous la carte de statut (le bas-gauche reste au joystick). Libellés mobiles courts (`JOBS`, `SETUP`, `MOVES`, `LIST`…), police Body, **14 px minimum**.
- Même id = bouton réutilisé (pas de doublon si un contrôleur se relance).

## 2. Un seul panneau ouvert (registre `UIKit`)
- `UIKit.registerPanel(obj, {name, close, noClose, passive})` : dès que `obj` devient visible (peu importe le code qui l'ouvre), les autres panneaux inscrits se ferment.
- `UIKit.openPanel / closePanel / togglePanel / closeAllPanels(except?) / anyPanelOpen() / openPanelObject()` (panneau ouvert, pour le focus manette).
- L'écran du dock garde le nom `MetaDock` (manette, réglage « Hide HUD ») et ses UIScale `AutoScale` portent l'attribut `Base` (réglage d'échelle).
- Inscrits : tous les `MetaDock.panel` (TasksPanel, ShopPanel, CombosPanel, PlayerListPanel, LeaderboardPanel, DailyPanel, CodesPanel, SettingsPanel), `CharacterSelect.Root` (fermé par `CharacterSelectController.close`, sans modifier ce fichier) et `CharacterSelect.CrateShop` en **passif** (s'ouvre par-dessus la sélection, jamais fermé par le registre).
- Souris libre en shift-lock dès qu'un panneau inscrit est ouvert (`MetaDock` RenderStep + `ShiftLockController.menuOpen` qui lit aussi `UIKit.anyPanelOpen`). Liste `MENUS` mise à jour (les panneaux du HUD sont maintenant dans l'écran `Meta`).

## 3. Liste des joueurs (`PlayerListController`)
- Touche **TAB** ou bouton PLAYERS. La PlayerList Roblox reste désactivée.
- Ligne : icône du perso joué (`UITheme.attackIcon("Ult:<perso>")` sur sa couleur, repli silhouette), nom + titre, LV, grade (couleur Config/Grades), K.O. (leaderstats). Tri : niveau, puis XP, puis nom. Rafraîchie chaque seconde quand ouverte.

## 4. Classements mondiaux (`LeaderboardService` / `LeaderboardController`)
- OrderedDataStores : `OB_LB_XP_v1` (XP totale → niveau), `OB_LB_KOs_v1`, `OB_LB_WeekKOs_v1_<AAAA-Www>` (semaine ISO, lundi 00:00 UTC). Clé `u_<UserId>`.
- Toutes les 120 s : écriture des joueurs présents **seulement si la valeur a changé** (`SetAsync`), puis lecture du top 50 (`GetSortedAsync(false, 50):GetCurrentPage()`). Écriture aussi au départ d'un joueur. Chaque appel en `pcall`, budget vérifié avant (`GetRequestBudgetForRequestType` SetIncrementSortedAsync / GetSortedAsync, réserve laissée). Noms : `UserService:GetUserInfosByUserIdsAsync` (cache).
- K.O. de la semaine : `data.WeekKOs = {week, n}` (ajouté si absent, remis à zéro à chaque semaine).
- Remote `Leaderboard` : `"Get"` → `{online, pending, reason, week, weekEnds, updated, boards, server}`.
- Panneau RANKS : onglets LEVEL / K.O.s / THIS WEEK (compte à rebours), bascule WORLD / SERVER. Studio sans accès API ou place non publiée : texte d'explication + classement de ce serveur.

## 5. Boutique honnête (HUD `ShopPanel`, `Config/Shop`)
- Jamais vide : **YOUR STUFF** (Cash → panneau des tâches, mallettes gratuites → OPEN, persos débloqués → sélection), **JOBS** (persos à débloquer en Cash, Robux seulement si le Game Pass existe ; ouvre `CharacterSelectController.open(false)`), **SKIN CRATES** (Cash, `Config/Skins.Crates`).
- Offres Robux (`Config/Skins.Products`) et cosmétiques (`Config/Shop.Items`) affichés **seulement si ProductId ~= 0**. Aucune section « SOON » (`Shop.isHiddenSection`).

## 6. Tâches + contrats (`TaskService`, `Config/Tasks`, HUD `TasksPanel`)
- Daily : 3 tâches/jour UTC, XP (+ Cash). **1 relance gratuite par jour** (`RerollsPerDay`) d'une tâche non finie (bouton REROLL, remote `TaskRequest` `("Reroll", index)`).
- Weekly : 3 contrats/semaine ISO tirés de `Config/Tasks.Weekly`, payés **Cash + Briefcase** (`SkinService.addCash` / `addCrates`), `Signals.WeeklyCompleted(player, id)`. Nouveau Kind `DailyDone`. Un combo compte une fois (coup qui atteint `Min`).
- Données : `data.Tasks = {day, list, rerolls}`, `data.Weekly = {week, list}` (ajoutés défensivement). Attributs : `Tasks`, `TasksWeekly` (JSON), `TasksReset`, `TasksWeeklyReset`, `TaskRerolls`. Renouvellement automatique (boucle 30 s) à minuit UTC / lundi.
- Panneau : sections DAILY et WEEKLY avec comptes à rebours ; pastille du bouton TASKS = tâches restantes.

## 7. Titres (`Config/Titles`, `TaskService`)
- Chaque promotion de grade et chaque 10e niveau débloque un titre ; le meilleur rang est porté automatiquement.
- `data.Titles = {[id]=os.time()}`, `data.Title` ; attributs Player `Title` (texte) et `TitleColor` (Color3). Toast « NEW TITLE UNLOCKED ».
- Affiché dans la liste des joueurs et dans le kill feed (HUD : `[TITRE]` après le nom, lu sur l'attribut du joueur via `killerId` / `victimId`).

## 8. Dette de thème
- `UITheme.Rarity` / `UITheme.RarityLabel` lus dans `Config/Skins.Rarities` (partie lancée seulement ; repli local).
- `UITheme.HUD` : palette sémantique du HUD ; `UITheme.Colors.Black` (noir pur). HUDController : **0** Color3 en dur.
