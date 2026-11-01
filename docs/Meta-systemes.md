# Méta-systèmes : récompense quotidienne, codes, réglages, salle AFK

Tout est en modules auto-chargés (aucun câblage). Textes du jeu en anglais.

## Boutons (client)
`MetaDockController` : colonne DAILY / CODES / SETTINGS / AFK.
- PC : en bas à gauche (sous le menu du HUD). Mobile : 3e colonne de tuiles à droite des tuiles du menu du HUD.
- ScreenGui `MetaDock` (DisplayOrder 4, sous le HUD) et `Meta` (panneaux, DisplayOrder 7, sous la sélection de perso).
- Panneau ouvert => souris libérée même en shift-lock.

## Récompense quotidienne
- `Config/DailyRewards` : 100, 150, 200, 300, 400, 500, puis jour 7 = 1 000 Cash + 2 Mystery Briefcases (≈ 2 650 Cash + 2 caisses / semaine).
- Une fois par jour UTC (`os.time()` serveur, lu une fois par requête). Série calculée en jours UTC entiers : `GraceHours` 48 => on peut sauter UN jour (réclamé lundi : mercredi garde la série, jeudi la perd) ; aucun effet de bord à minuit pile. Après le jour 7 : nouveau cycle.
- Première connexion : `Daily = {}` => jour 1 réclamable, panneau ouvert tout seul.
- Chargement DataStore raté (`DataService.loadFailed`, session en mémoire jamais sauvée) : pas de réclamation (« Rejoin to claim »), pas de pastille. Studio sans accès API = mode test normal (réclamation possible).
- Panneau : compte à rebours avant la perte de série (`expiresAt` = minuit UTC du jour où elle serait perdue).
- Données : `data.Daily = {Streak, LastDay, LastClaim, Total}`. Attribut `DailyClaimable` (pastille rouge).
- Remote `DailyReward` : client `"State"` / `"Claim"` ; serveur renvoie `{day, claimed, claimable, nextAt, expiresAt, lost, total, now, unsaved?, result?}`.
- Le panneau s'ouvre seul à la connexion s'il y a quelque chose à prendre (après la fermeture de la sélection de perso).

## Codes
- `Config/Codes` : `{Code, Reward = {Cash, Crates, XP}, Expires?, MaxUses?}`. RELEASE 500, BACON 250, OVERTIME 300 + 1 caisse, COFFEEBREAK 200 + 150 XP, THANKYOU 750 + 1 caisse.
- Insensible à la casse ; seuls lettres et chiffres ASCII comptent (espaces, tabulations, espaces insécables / largeur nulle des claviers mobiles, tirets ignorés — même règle appliquée aux codes de la config). Une fois par joueur (`data.Codes[CODE] = os.time()`), `Expires` valable jusqu'à cette seconde incluse, MaxUses = compteur DataStore `OfficeBattlegrounds_CodeUses` (repli mémoire par serveur si le DataStore répond mal) ; utilisation réservée puis rendue (décrément) si le joueur part pendant l'attente du DataStore ou en cas de double requête.
- Chargement DataStore raté : refusé (« rejoin to redeem »), rien n'est consommé.
- Anti-spam : 1 essai / 1,5 s, 6 codes invalides => 60 s de blocage.
- Remote `RedeemCode` : client envoie le texte ; réponse `{ok, message, code, reward}` ("Invalid code", "Already redeemed", "Expired"...).

## Réglages
- Schéma : `Shared/Modules/ClientSettings` (SCHEMA groupé par Section). `ClientSettings.resetAll()` ajouté.
- `SettingsService` : remote `Settings (key, value)` (12/s), nettoyé par `ClientSettings.sanitize`, sauvé dans `data.Settings`, répliqué en JSON dans l'attribut Player `Settings`.
- Envoi client regroupé : `ClientSettings.set` applique tout de suite en local, puis n'envoie que la dernière valeur de chaque clé 0,15 s après le dernier changement, au plus 8 / s (jamais coupé par la limite serveur). Tant qu'une écriture locale n'est pas revenue dans l'attribut (3 s max), le JSON répliqué est ignoré pour cette clé : plus de bouton qui « saute » en arrière quand on spamme. Retour à la valeur sauvegardée S alors qu'une autre valeur A est encore en vol (ping élevé) : S est renvoyée quand même (sinon l'écho de A gagnerait).
- `SettingsController` : panneau (toggles, sliders, choix), applique SFXVolume (SoundGroup `SFX`), AutoShiftLock (à chaque apparition), ShowHints (`PlayerGui.ControlsHint`). Les autres clés sont lues par CartoonFX & co.
- Pas de réglage « Music » : le jeu n'a aucune musique (aucun ID de piste dans le projet). Une ancienne sauvegarde avec `MusicVolume` reste valide (clé inconnue => ignorée par le client, retirée de `data.Settings` au chargement).

## Salle AFK (« AFK BREAK ROOM »)
- Construite en Parts au démarrage dans `workspace.BreakRoom` (Model, streaming Atomic), centre `Config/AFK.Origin` = (2600, 400, 2600). Étages : X/Z ±110 autour de 0, Y de 0 à -1 800 ; skyline jusqu'à ±450 en X autour de la salle => rien ne croise l'arène ni le chemin des effondrements. FloorService / EventService ignorent les persos `SafeZone`.
- Contenu : 3 canapés (7 places), 4 poufs face à la baie vitrée, 3 tabourets au comptoir café (tous des `Seat`), table basse + tasse fumante, machine à café (vapeur), distributeur (LED qui clignotent, néon), plantes, horloge à l'heure locale, lampadaires, enseigne « AFK BREAK ROOM », skyline (fenêtres qui s'allument / s'éteignent, balises rouges) + nuages qui défilent.
- Ambiance animée côté client (`AFKController`, seulement quand on est AFK et caméra à < 400 studs) via attributs posés par le serveur : `AmbSway`, `AmbBlink`/`AmbPhase`/`AmbMode`/`AmbBaseT`, `AmbCloud`, `AmbHand`/`AmbPivot`, Parts `Window`. Qualité « Low » => horloge seule ; « Reduce flashes » => pulsations douces, pas de créneaux.
- Musique : aucune piste « Music » n'existe dans le projet (`Config/Sounds` = effets seulement) => pas de musique (ne pas inventer d'ID ; une piste ajoutée plus tard irait dans le SoundGroup `Music`).
- Tableau des gains (mur droit) : en-tête fixe (taux, plafond) + `PayoutScreen` où le client pose sa propre SurfaceGui (PlayerGui, `Adornee` = l'écran, `Face = Left` = -X = vers la salle) : gagné pendant la pause, prochain versement, temps de pause, reste du jour.
- Sortie claire : porte encadrée de néon vert, enseigne « EXIT - back to the arena » (face Front = -Z = vers la salle), dalle verte avec 3 chevrons qui défilent vers la porte, ProximityPrompt « Back to work ». (Plus de texte sur la face Top de la dalle : orientation ambiguë.)
- Entrée : bouton AFK (remote `AFK` `"Enter"`/`"Exit"`/`"Toggle"`/`"Rejoin"`). Refusée si : données pas chargées, K.O., étourdi, échange de combat il y a < 8 s — touché, bloqué, garde cassée ou paré, des deux côtés (`Signals.Hit` / `Blocked` (attaquant, victime) / `GuardBroken` (victime, attaquant) / `Parried` (défenseur, attaquant)), effondrement en cours, recharge 5 s. L'objet tenu est lâché.
- Dedans : attribut perso `SafeZone = true` (CombatService ignore les coups). 25 Cash / min, +100 toutes les 10 min sans sortir, plafond 1 500 Cash AFK / jour UTC (`data.AFK = {Day, Earned}`).
- Chaque versement : « +25 CASH » qui jaillit au-dessus du perso + son (`Ding`, `LevelUp` pour le bonus) en plus du popup Cash habituel.
- HUD compact (440 px, UIScale propre ~0,9 sur téléphone, jamais plus large que l'écran) : « AFK 03:12 … $150 », barre, « next +25 in 00:48 · bonus in 9:12 · $2,850 left today », gros bouton EXIT.
- Anti-inactivité (Roblox expulse après 20 min sans entrée) : pendant `AFKActive`, `LocalPlayer.Idled` => essai `VirtualUser:CaptureController()` + `ClickButton2` en pcall (probablement réservé aux scripts privilégiés => sans effet en jeu). Filet de sécurité : le client estime le début de l'inactivité avec le temps passé par `Idled` (remis à zéro par toute entrée `UserInputService`) ; à `Config/AFK.RejoinIdle` = 17 min toujours AFK, il envoie `AFK` `"Rejoin"` (au plus 1 / min). Le serveur vérifie (joueur AFK, pas en transit, 1 fois / 10 min `RejoinCooldown`), sauve (`DataService.save` : Cash et `data.AFK.Earned` du jour sont déjà dans les données), puis `TeleportService:TeleportAsync(game.PlaceId, {player}, TeleportOptions)` avec `SetTeleportData({afkRejoin = true, afkEarned})` en pcall. Studio : la téléportation échoue => simple `warn`, le joueur reste (et sera expulsé à 20 min). À l'arrivée : `player:GetJoinData().TeleportData.afkRejoin` (même PlaceId) => remis dans la salle dès que données + perso sont prêts (2 s après, réessais sans spam, 45 s max), toast + attribut `AFKRejoined` => le HUD affiche « Reconnected to keep you AFK » 10 s. `afkEarned` (borné) ne sert qu'à l'affichage « gagné pendant la pause ». Le bonus des 10 min repart de zéro.
- Mort / réapparition / départ : fin de session. Un joueur AFK déplacé hors de la salle est remis dans la salle à la seconde suivante.
- Sortie : retour sur un spawn de l'étage courant vérifié (hauteur de l'étage + sol collidable dessous par raycast, 6 essais), sinon centre de l'étage ; + 3 s de bulle. Pendant un effondrement on reste protégé dans la salle jusqu'à ce que l'étage soit posé (45 s max).

## Admin
`/resetdaily [full]` (récompense réclamable à nouveau ; full = série à zéro), `/afkpay` (versement AFK immédiat).

## Fait ailleurs (vérifié)
- FloorService / EventService `allCharacters()` ignorent les persos `SafeZone`.
- ShiftLockController `MENUS` contient `Meta/DailyPanel`, `Meta/CodesPanel`, `Meta/SettingsPanel`.
- CombatService émet `Signals.Blocked:Fire(attacker, victim)` dans la branche « Blocked » d'applyHit (verrou de combat AFK).
