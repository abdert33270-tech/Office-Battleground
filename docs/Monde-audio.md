# Monde & audio : éclairage par étage, ambiance sonore, manette, réglages d'interface

## Éclairage par étage (serveur)
- Données : `Config/Floors.Lighting[étage]` = `Ambient`, `OutdoorAmbient`, `ClockTime`, `Brightness`, `Atmosphere = {Density, Color, Decay}`, `Grade = {TintColor, Saturation, Contrast}`. Étage absent => `LightingDefault` (valeurs de la place). Durée : `LightingTween` = 1,5 s.
- `FloorService` : instantané au démarrage ; fondu quand le premier perso atterrit sur le nouvel étage (là où part la bannière « FLOOR n »), ou à la fin de l'attente d'atterrissage si personne n'a atterri. `Grade` = `ColorCorrectionEffect` « FloorGrade » dans Lighting (créé par FloorService, ne gêne pas les CC « Friday5PM » / « NapTime » / ultimes, qui se multiplient).
- Ambiances : OpenSpace néons neutres, Cafeteria chaud midi, ServerRoom bleu froid sombre, ParkingGarage sodium, CorporateGym matin saturé, Mailroom beige, MeetingRooms corporate froid, CEOOffice heure dorée, Lobby marbre clair, Rooftop plein soleil, Archives sépia poussiéreux, GameRoom néons violets, Daycare pastel, Auditorium scène sombre, Warehouse industriel, Spa chaud vapeur.
- Coupure de courant (`EventService` PowerOutage) : elle ne pose **aucun attribut** ; elle sauve Lighting (Brightness, ClockTime, Ambient, OutdoorAmbient, ExposureCompensation, EnvironmentDiffuse/SpecularScale) au début et remet ces valeurs à la fin. FloorService :
  - ne touche à rien tant que `EventService.isActive("PowerOutage")` ;
  - annule son fondu en cours sur `Signals.EventStarted("PowerOutage")` ;
  - refait un fondu vers l'étage actuel sur `Signals.EventEnded("PowerOutage")` (après la remise en état).
  - ExposureCompensation / EnvironmentDiffuseScale ne sont jamais modifiés par l'éclairage d'étage.
- Alerte incendie (`FireAlarm`, sauve / remet l'Atmosphere) : l'Atmosphere de l'étage n'est pas touchée pendant qu'elle dure.

## Ambiance sonore (client, `AmbienceController`)
- Étage courant = attribut `ReplicatedStorage.FloorName` (posé par FloorService au début de l'effondrement) ; changement appliqué 1,2 s après (vers l'atterrissage), fondu croisé `Config/Floors.AmbienceFade` = 2,5 s.
- Salle de pause : attribut Player `AFKActive` => `Config/AFK.Ambience` (boîte à musique douce, plus grave).
- Uniquement des IDs déjà dans le jeu : `{Src = "Sounds", Key}` => `Config/Sounds[Key][1]`, `{Src = "Events", Key}` => `Config/Events.Sounds[Key]`.
  OpenSpace clavier (Typing) + imprimante, ServerRoom bourdonnement (Electric, pitch 0,3), ParkingGarage / Warehouse grondement grave (Rumble), Spa eau (Water), Rooftop vent, Cafeteria / Lobby / GameRoom / Auditorium / MeetingRooms / Gym foule (Crowd) à divers volumes / hauteurs, Mailroom imprimante, CEOOffice / Archives vent faible, Daycare berceuse.
- Boucles (`Looped`) non positionnelles dans `SoundService.AmbienceLoops`, volume ~0,06-0,15, SoundGroup **« Ambience »** dont le volume = réglage `AmbienceVolume` (SettingsController).

## Manette (`GamepadController`)
| Bouton | Action |
|---|---|
| A | saut (Roblox) / valider en menu |
| R2 | frappe (maintenir = combo) |
| L2 | garde |
| B | dash ; en menu : retour / fermer |
| X / Y | ramasser-lâcher / lancer |
| L1 | Overtime / ultime |
| L3 | course (RunController) |
| Croix gauche / bas / droite | attaques 1 / 2 / 3 |
| Croix haut | carte des commandes (HintController) |
| SELECT | entrer / sortir du mode menu |

- Mode menu = `GuiService.SelectedObject ~= nil`. SELECT : panneau ouvert (registre `UIKit.isPanel`, attribut `MetaMenu`, sélection de perso) => son premier bouton ; sinon premier bouton du dock (`MetaDock`, à défaut `HUD`, ou « SHOW HUD » si le HUD est caché). `GuiService.AutoSelectGuiEnabled = false`.
- En mode menu, la croix navigue (les attaques passent la main), l'appui sur X / Y / R2 / L1 / L2 est avalé (les relâchements passent : pas de garde bloquée).
- Panneau qui s'ouvre seul avec la manette comme dernière entrée => sélection sur son premier bouton.
- Aide `GamepadHints` (bas-droit) : glyphes `UserInputService:GetImageForKeyCode` (repli texte), noms des attaques du perso, liste « menu » en mode menu ; visible si dernière entrée = manette et `ShowHints`.
- Réglages : sliders avec boutons `-` / `+` (sélectionnables), ScrollingFrame non sélectionnable.

## Réglages d'interface (`ClientSettings` / `SettingsController`)
- `AmbienceVolume` (0-1), `UIScale` (0,8-1,2, pas 0,05), `HideHUD` : sauvegardés comme les autres (SettingsService, `data.Settings`), appliqués en direct.
- **UIScale** — convention existante de `UITheme.pop/open/close` : un `UIScale` nommé `AutoScale` ou `PopScale` dont l'attribut `Base` est l'échelle de repos. Pour chaque cadre racine (enfant direct) de chaque ScreenGui :
  - `AutoScale` / `PopScale` présent : adopté ; `RawBase` = base du propriétaire, `Base` = `RawBase` x réglage ; si le propriétaire réécrit `Base`, on remultiplie juste après.
  - aucun UIScale (et réglage ≠ 100 %) : création d'un `PopScale` (attribut `UserScaleOwned`) ; s'il arrive ensuite un UIScale du propriétaire, le nôtre est retiré.
  - autre UIScale (animation maison), cadre plein écran : ignoré.
  - ScreenGui ignorés : `TouchGui`, `MobileControls`, `RunButton`, `ShiftLock`, et tout ScreenGui avec l'attribut `NoUserScale`.
  - Pour un contrôleur qui calcule lui-même sa base : écrire `Base` puis `Scale = Base` (comme `UIKit.autoScale`) suffit ; ou lire `SettingsController.uiScale()`.
- **HideHUD** : `Enabled = false` sur `HUD`, `MetaDock`, `ControlsHint`, `GuardMeter`, `GamepadHints` (un Enabled = true écrit par le propriétaire pendant ce temps est mémorisé et rendu à la fin) ; bouton « SHOW HUD » (ScreenGui `HUDHiddenTab`, haut-gauche). Panneaux et commandes tactiles restent.

## Mobile (`MobileController`)
- Arc du pouce droit centré sur le bouton SAUT de Roblox (lu dans `TouchGui`, sinon règle Roblox : 70 px à (-95, -90) si côté min ≤ 500, sinon 120 px à (-170, -210)). Échelle k = clamp(min(H/560, L/1000), 0,7, 1,2).
- Arc intérieur : HIT, attaques 1/2/3 ; arc extérieur : PICK UP, BLOCK, OT (l'ULT prend sa place quand prêt) ; DASH au-dessus du saut.
- À 667x375 et 844x390 (k = 0,7) : rien à moins de 330 px du bord droit côté gauche (joystick dynamique 40 %, dock 260x140 bas-gauche libres), colonne RUN / LOCK (14-78 px du bord droit) évitée, haut de l'arc à ~280 px du bas.

## Salle AFK
- `Config/AFK.DailyCap` = 1 500 (25 / min + 100 toutes les 10 min). HUD : ligne dorée « NEXT BONUS +100 in mm:ss » avec sa barre (pulse la dernière minute) ; tableau de la salle : case « NEXT BONUS ».
