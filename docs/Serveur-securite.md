# Sécurité serveur : sauvegardes, achats, anti-farm, changement de perso, admin

Tout est vérifié côté serveur. Le client ne fait que demander.

## Sauvegardes (DataService)
- **Verrou de session** : l'enregistrement DataStore contient `__lock = {job = game.JobId, t = os.time()}` (jamais gardé dans `data` en mémoire).
  - Chargement par `UpdateAsync` : pose notre verrou. Verrou d'un **autre** serveur de moins de 5 min => on réessaie toutes les 3 s pendant 15 s, puis on le **vole** (serveur mort ou bloqué) avec un `warn`.
  - Chaque écriture vérifie le verrou dans la fonction de transformation : s'il appartient à un autre serveur, elle renvoie `nil` (rien n'est écrit), le profil passe `canSave = false` (« verrou perdu »). Un vieux serveur ne peut donc **jamais** écraser une session plus récente.
  - Sortie du joueur (`PlayerRemoving`) et fermeture : écriture finale avec `__lock = nil` => le serveur suivant charge tout de suite.
  - L'autosave (120 s) rafraîchit `t` (battement bien inférieur aux 5 min).
- **Écritures** : 3 essais (attente 1 s puis 2 s). `DataService.save(player, release?)` renvoie `true` seulement si les données sont réellement écrites. Une seule écriture à la fois par joueur (file d'attente dans l'ordre, pas d'écritures qui se chevauchent).
- `data.Version` : incrémentée à chaque écriture réussie (lue dans l'enregistrement précédent).
- **BindToClose** : écriture finale de chaque profil encore présent, puis attente jusqu'à `pendingSaves() == 0` (25 s max, Roblox coupe à 30 s).
- Reconnexion AFK : `AFKService` appelle `DataService.save` avant `TeleportAsync` ; le serveur d'arrivée attend que l'ancien libère le verrou (sortie du joueur) ou le vole après 15 s — dans les deux cas il lit les données sauvées avant la téléportation, et une écriture tardive de l'ancien serveur est refusée. Pas de retour en arrière.
- API ajoutée (compatible avec l'existant) : `DataService.canSave(player)`, `DataService.saveAll(release?, timeout?) -> nOk, total`, `DataService.pendingSaves()`.
- Studio sans accès API : mémoire seule (inchangé), `save` renvoie `false`.

## Achats Robux (SkinService.ProcessReceipt)
- `NotProcessedYet` si : joueur absent, données pas chargées, `loadFailed`, `canSave == false` (verrou perdu, Studio sans API, profil libéré), produit inconnu, ou même `PurchaseId` déjà en cours de traitement.
- Octroi en mémoire -> `PurchaseId` ajouté à `data.Receipts` (50 derniers) -> `DataService.save`. Si la sauvegarde échoue : octroi **annulé** (Cash / caisses retirés, reçu retiré) et `NotProcessedYet` (Roblox rappellera).
- `PurchaseId` déjà dans `data.Receipts` => `PurchaseGranted` sans rien redonner.

## Anti-farm (FarmGuard)
- Même paire tueur -> victime : plus de 3 K.O. sur 10 min => K.O. sans aucune récompense (ni XP, ni Cash, ni compteur KOs) pour cette paire. Compté une seule fois par mort (même verdict pour DataService et SkinService). Le compteur est par UserId : sortir / revenir ne le remet pas à zéro.
- Victime passive : pas d'XP ni de Cash de dégâts contre un joueur qui n'a infligé aucun dégât à un autre joueur depuis 60 s (alt, AFK).
- Mannequins : toujours 0 (inchangé).

## Changement de personnage (CharacterService)
- Remote `SelectCharacter` limitée à 1 / s. Re-choisir le perso actuel ne fait rien (annule seulement un changement en attente).
- En combat (coup donné ou reçu, bloqué, garde cassée, paré dans les 8 dernières secondes) : le changement est mis en file pour la **prochaine apparition** (toast, attribut Player `PendingCharacter`).
- Changement en direct : les recharges ne sont **jamais** remises à zéro. Chaque emplacement 1..3 du nouveau kit reprend le temps restant de l'ancien emplacement (ou sa propre recharge si elle est plus longue : aller-retour A -> B -> A inutile). Remise à zéro seulement sur un perso neuf (apparition) et à la transformation (voulu).
- `usable()` refuse si la vérification de possession plante.

## Admin (AdminService)
- Admins : ensemble `ADMINS` (UserId), ou rang >= `ADMIN_GROUP.MinRank` dans `ADMIN_GROUP.Id` (0 = désactivé, rang lu à l'arrivée). Tout le monde en Studio.
- Un non-admin n'obtient aucune réaction (ni toast, ni erreur). Chaque commande d'admin laisse une ligne `[AdminAudit] nom (UserId) : commande` dans le journal serveur.
- `/kick <name> [reason]` : nom exact ou début de nom unique (jamais « me » implicite), pas sur un autre admin.
- `/announce <text>` : bannière pour tout le serveur, texte filtré par `TextService` (rien n'est envoyé si le filtre échoue).
- `/shutdown` : bannière, sauvegarde de tous les profils (`saveAll`, 20 s max), puis expulsion de tout le monde avec un message ; les arrivants sont expulsés aussi. Bouton SHUTDOWN (double appui) dans le panneau admin.
