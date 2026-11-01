# Ultimes v3 — lisibilité des cinématiques

Demande : « qu'on voie mieux ce qui se passe pendant les ultimes ». L'essentiel est mutualisé dans
`Modules/UltKit`, `Controllers/UltimateController` et `Services/UltimateService` : les 20 ultis en profitent sans
réécriture. Non testé en jeu (pas de Studio) : à rejouer en priorité.

## Caméra (UltKit)
- **Seuls le lanceur et la victime** ont la caméra cinématique (`opts.everyone` est ignoré).
- **Transitions douces** entre plans (0,25 s ; 0,35 s depuis la caméra du joueur ; `opts.cut = true` pour couper net).
- **Recadrage automatique** : si le lanceur ou la victime sort du champ, la caméra recule dans son axe (≤ 14 studs,
  `opts.fit = false` pour désactiver).
- **Anti-mur** : rayon du point regardé vers la caméra (`RespectCanCollide`), la caméra s'arrête devant l'obstacle.
- Nouveau plan **`"duo"`** : regarde le milieu lanceur/victime, recule selon leur écart (`side`, `angle`, `height`,
  `dist`, `min`, `speed`, `fov`).
- Orbites bornées à ±70°/s (certaines tournaient à 150–170°/s), lissage des plans qui suivent un sujet.
- **Retour en douceur** vers la caméra du joueur (0,45 s), avec l'orientation d'avant l'ulti ; retour immédiat à la
  mort, au respawn, si le lanceur disparaît, ou après 14 s de caméra imposée.
- Réglages : `UltCinematics = false` → aucun plan, pas de bandes noires, tremblements ×0,5 ;
  `ReducedFlashes` → pas d'images d'impact, flashs quasi transparents ; `ScreenShake` / `FOVKick` / `Quality`
  sont appliqués par CartoonFX.

## Rythme et lisibilité
- **Bandes noires** pendant toute l'ulti (lanceur + victime), posées au cut-in.
- **Contour (Highlight)** sur le lanceur au cut-in, sur la victime dès qu'elle est tenue (rouge).
- **Hit-stop** sur chaque `U.hit` / `U.finish` (phase interne `_Hit`) : gel des animations 0,07 s (0,16 s au finisher)
  et +0,05 s / +0,12 s sur la prochaine attente serveur.
- **Titres de temps forts** en bas de l'écran : `def.Beats[phase]` (texte ou `{ {t, "TEXTE"}, ... }`) ou `payload.beat`.
- **Anticipation** : `U.windup(ctx, t)` (serveur) ou `def.Anticipate[phase] = { t, ... }` → pose d'armement 0,2 s avant.
- **Rythme** : les modules à table `T` partagée la multiplient par 1,15 au chargement (serveur et client restent
  synchrones) ; `def.Tempo` ralentit les `U.wait` des modules à attentes relatives (Intern : 1,15).
- **Anti-fouillis** : sparks/débris/éclats −30 %, au plus 1 onomatopée `K.word` / 0,45 s, 2 ondes / sphères /
  anneaux / lumières par 0,12 s ; images d'impact ≤ 3 images, une série / 0,4 s, blanc moins cramé ; flashs blancs
  plafonnés (55 %, 0,22 s). `K.CFX` est enveloppé pour que les modules « ult3 » suivent les mêmes règles.

## Robustesse (UltimateService)
- Victime tenue morte / partie / téléportée avant le finisher → l'ulti s'arrête 0,5 s après (nettoyage complet).
- Perso téléporté par un autre système (> 25 studs) → relâché au lieu d'être ramené de force ; lanceur → ulti annulée.
- Démarrage protégé (`pcall`) : une erreur ne laisse plus `UltActive` bloqué. Durée max 10 s.
- Plafond de 40 dégâts par victime et par ulti conservé.

## Par ulti
- Les 18 ultis à minutage `T` : rythme ×1,15, 3–4 titres de temps forts ; anticipation ajoutée avant le coup de pied
  final (DeliveryGuy), le 1er coup de clavier (ITGuy), l'uppercut (Mascot) et le gros coup de matraque (SecurityGuard).
- Intern : `Tempo = 1.15`, titres par phase, `U.windup` avant l'uppercut.
- Barista : appels `snd` à 5 arguments corrigés (erreurs selene).
- Bacon : non modifié (autre agent) ; l'API reste rétro-compatible.

## À vérifier en jeu
- Le recadrage peut élargir des gros plans voulus (visage) : passer `fit = false` sur ces plans si besoin.
- Retour caméra en douceur : dépend du module caméra Roblox (priorité Camera) ; vérifier en shift-lock.
- Titres de temps forts : textes à ajuster selon le rendu réel.
