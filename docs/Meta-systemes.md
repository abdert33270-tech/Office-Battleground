# Méta-systèmes : récompense quotidienne, codes, réglages, salle AFK

Tout est en modules auto-chargés (aucun câblage). Textes du jeu en anglais.

## Boutons (client)
`MetaDockController` : colonne DAILY / CODES / SETTINGS / AFK.
- PC : en bas à gauche (sous le menu du HUD). Mobile : 3e colonne de tuiles à droite des tuiles du menu du HUD.
- ScreenGui `MetaDock` (DisplayOrder 4, sous le HUD) et `Meta` (panneaux, DisplayOrder 7, sous la sélection de perso).
- Panneau ouvert => souris libérée même en shift-lock.

## Récompense quotidienne
- `Config/DailyRewards` : 100, 150, 200, 300, 400, 500, puis jour 7 = 1 000 Cash + 2 Mystery Briefcases (≈ 2 650 Cash + 2 caisses / semaine).
- Une fois par jour UTC (`os.time()` serveur). Plus de 48 h sans réclamer => retour au jour 1. Après le jour 7 : nouveau cycle.
- Données : `data.Daily = {Streak, LastDay, LastClaim, Total}`. Attribut `DailyClaimable` (pastille rouge).
- Remote `DailyReward` : client `"State"` / `"Claim"` ; serveur renvoie `{day, claimed, claimable, nextAt, expiresAt, lost, total, now, result?}`.
- Le panneau s'ouvre seul à la connexion s'il y a quelque chose à prendre (après la fermeture de la sélection de perso).

## Codes
- `Config/Codes` : `{Code, Reward = {Cash, Crates, XP}, Expires?, MaxUses?}`. RELEASE 500, BACON 250, OVERTIME 300 + 1 caisse, COFFEEBREAK 200 + 150 XP, THANKYOU 750 + 1 caisse.
- Insensible à la casse / aux espaces, une fois par joueur (`data.Codes[CODE] = os.time()`), MaxUses = compteur DataStore `OfficeBattlegrounds_CodeUses`.
- Anti-spam : 1 essai / 1,5 s, 6 codes invalides => 60 s de blocage.
- Remote `RedeemCode` : client envoie le texte ; réponse `{ok, message, code, reward}` ("Invalid code", "Already redeemed", "Expired"...).

## Réglages
- Schéma : `Shared/Modules/ClientSettings` (SCHEMA groupé par Section). `ClientSettings.resetAll()` ajouté.
- `SettingsService` : remote `Settings (key, value)` (12/s), nettoyé par `ClientSettings.sanitize`, sauvé dans `data.Settings`, répliqué en JSON dans l'attribut Player `Settings`.
- `SettingsController` : panneau (toggles, sliders, choix), applique MusicVolume / SFXVolume (SoundGroups `Music` / `SFX`), AutoShiftLock (à chaque apparition), ShowHints (`PlayerGui.ControlsHint`). Les autres clés sont lues par CartoonFX & co.

## Salle AFK (« AFK BREAK ROOM »)
- Construite en Parts au démarrage dans `workspace.BreakRoom`, centre `Config/AFK.Origin` = (2600, 400, 2600), loin des étages (X/Z ±110, Y 0 à -1 800).
- Canapés avec Seats, table basse, poufs, comptoir café (vapeur), distributeur, plantes, baie vitrée + skyline, lumières douces, enseigne, tableau des gains, porte EXIT (ProximityPrompt) + dalle verte « BACK TO WORK ».
- Entrée : bouton AFK (remote `AFK` `"Enter"`/`"Exit"`/`"Toggle"`). Refusée si : données pas chargées, K.O., étourdi, touché il y a < 8 s, effondrement en cours, recharge 5 s. L'objet tenu est lâché.
- Dedans : attribut perso `SafeZone = true` (CombatService ignore les coups). 25 Cash / min, +100 toutes les 10 min sans sortir, plafond 3 000 Cash AFK / jour UTC (`data.AFK = {Day, Earned}`).
- HUD : « AFK 03:12 - next +25 in 00:48 - earned 150 » + barre + EXIT (attributs `AFKActive`, `AFKSince`, `AFKNextPay`, `AFKNextBonus`, `AFKEarned`, `AFKCapLeft`).
- Mort / réapparition / départ : fin de session. Un joueur AFK déplacé hors de la salle (effondrement, « Surprise Meeting ») est remis dans la salle à la seconde suivante.
- Sortie : retour sur un spawn de l'étage + 3 s de bulle ; pendant un effondrement on attend que l'étage soit posé.

## Admin
`/resetdaily [full]` (récompense réclamable à nouveau ; full = série à zéro), `/afkpay` (versement AFK immédiat).

## À faire ailleurs (fichiers d'autres agents)
- FloorService / EventService `allCharacters()` : ignorer les persos `SafeZone` (évite le petit aller-retour salle -> étage -> salle pendant un effondrement / une réunion surprise).
- ShiftLockController `MENUS` : ajouter `{ "Meta", "DailyPanel" }`, `{ "Meta", "CodesPanel" }`, `{ "Meta", "SettingsPanel" }` (cache aussi le viseur).
- Roblox expulse les joueurs inactifs au bout de 20 min : la paie AFK s'arrête alors (normal, pas de contournement).
