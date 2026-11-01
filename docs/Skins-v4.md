# Skins v4 — journal des changements

Passe « Améliorer les skins » (2026-11-01). Les Id, les noms et les thèmes ne changent pas : les révélations
cinématiques (`Config/SkinReveals`) restent valides.

## Méthode
Studio n'était pas disponible : les 60 skins (Pack1..Pack6) ont été chargés hors Roblox (Lua + stubs
Vector3/CFrame/Color3) puis audités par calcul : pièces qui flottent par rapport à leur membre R6, pièces enfouies,
pièces qui traversent un autre membre, plafonds de pièces, part du Neon, présence des « emplacements » de
silhouette (coiffe, épaules, dos, objet tenu) sur les Epic / Legendary.

Rappel de convention : `CFrame.Angles(rx, 0, 0)` avec rx **positif** fait avancer le **bas** de la pièce (vers -Z).
Une cape ou une queue-de-pie qui doit s'écarter du corps vers le bas prend donc un rx **négatif**.

## Moteur (Modules/SkinBuilder)
- **Échelle du perso** : tailles, offsets, assets et offsets de mesh suivent `Torso.Size.Y / 2`. L'animateur client
  recalcule l'offset des pièces animées avec l'échelle courante : les pièces animées ne « décrochent » plus quand
  un perso est agrandi par `Model:ScaleTo` (transformation de la Lunch Lady, x1,15).
- **Ball / Cylinder non uniformes** : convertis en bloc + SpecialMesh Sphere / Cylinder, l'ellipsoïde voulu est
  respecté (Roblox forçait une sphère). Concerne 4 pièces (flammes, yeux, boutons).
- **Reflet Legendary** (« shimmer ») : un éclat qui monte le long des pièces Metal / Foil toutes les ~3,5 s
  (client, 24 pièces max par skin, coupé au-delà de 80 studs). `Shimmer = false` sur un skin pour le désactiver.
- Limite connue : les `Highlight` ne s'affichent pas dans les ViewportFrame (aperçus du menu) ; le contour reste
  réservé à la transformation (et à la démonstration de pouvoir de la révélation).

## Données (Config/Skins)
- `Skins.NoSkins` (Bacon) + `Skins.hasSkins(charId)` (ou `NoSkins = true` sur la fiche du perso) : pas d'uniforme
  Base, `ByCharacter[id] = {}`, exclu des pools de toutes les caisses, entrées SkinList pour ce perso refusées.
- Avertissement au chargement si un skin dépasse son plafond de pièces (Rare 30 / Epic 40 / Legendary 60).

## Serveur (SkinService)
- Perso sans skins : look fixe (avatar d'origine + accessoires de métier), `Equip` refusé (sauf "Avatar"),
  pas de skin Base dans `Owned`, PNJ non habillés.

## Menu (CharacterSelectController, retouches locales)
- Perso sans skins : rangée de skins remplacée par « ONE OF A KIND - NO SKINS », aperçu 3D de son look fixe
  (étiquette NO SKINS), bouton NO SKINS grisé, vignette de la grille « UNIQUE ».

## Contenu, par pack
- **Pack1** : correction des erreurs `WHT` (palette déclarée avant `faceKit`). Speedrun Intern (Epic) : sac
  d'hydratation dorsal + tuyau sur l'épaule (silhouette de dos). Livestream Legend : bras de fixation du ring light
  (il flottait à 0,3 derrière la tête). Cyber Sentinel : matraque à impulsion néon (objet tenu).
- **Pack2** : Bull Market Baron : lumière dorée sur la pièce-auréole, émeraude du pommeau, montre à gousset,
  flèches boursières flottantes (34 pièces, enfin au-dessus de l'Epic). Prime Time Host : queue-de-pie à sequins.
- **Pack3** : Giveaway King : cape et liseré inclinés dans le bon sens (le bas rentrait dans les jambes).
  Pit Stop Racer : aileron reposé sur le casque.
- **Pack4** : Super Mascot : cape et emblème inclinés dans le bon sens. Halftime Legend : canon à t-shirts posé
  sur l'épaule. Hype Coach Live : mégaphone (objet tenu, 40/40).
- **Pack5** : Synergy Overlord : palette resserrée (or / noir / accent bleu roi, fin de l'arc-en-ciel),
  épaulettes « power suit » à liseré néon, col relevé doré, cape marine bordée d'or (34 pièces).
- **Pack6** : queue de chat : perles agrandies (elles ne se touchaient pas). Tuxedo Cat : pans de queue-de-pie
  inclinés dans le bon sens. Cyber Kitty : moins de néon (cordons, anneaux de queue), seul le bout de la queue
  brille. Lucky Fortune Cat : mantelet rouge et or, nœud du grelot, porte-bonheur dans la patte droite, grelot
  lumineux (38 pièces).

## À vérifier en jeu
- Reflet Legendary : intensité (0,3 de Reflectance au pic) à ajuster si trop discret / trop fort.
- Capes corrigées (Giveaway King, Super Mascot, Synergy Overlord) en course.
- Bacon : son look fixe dépend de son `Identity` (module de Content) ; sans Identity il garde l'avatar du joueur.
