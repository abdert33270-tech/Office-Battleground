# Office Battlegrounds

Projet Rojo 7.7 du jeu Roblox **Office Battlegrounds**.

- `places/office_battleground_original.rbxl` : place d'origine.
- `places/office_battleground_v2.rbxl` : place reconstruite avec toutes les nouveautés (`rojo build`).
- `archives/Roblox-lite.rar` : notes de projet (vault Obsidian).
- `src/` + `default.project.json` : code source (synchroniser avec `rojo serve`).
- `docs/` : notes de design (combat ABA, M1 par arme, ultimes, skins, systèmes méta).
- `tools/check.sh` (selene + build), `tools/smoke.sh` (chargement de tous les modules hors Studio).

## À faire par le propriétaire
- Créer le Game Pass **The Bacon (499 R$)** et mettre son id dans `src/ReplicatedStorage/Shared/Config/Unlocks.luau` (et ceux des autres persos Robux).
- Game Settings → Avatar → R6 ; activer l'accès API (DataStore) ; tester à 2 joueurs (parade, guard break, AFK).
