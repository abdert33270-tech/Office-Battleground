#!/usr/bin/env bash
# Test de fumée : require() de chaque ModuleScript hors Studio (API Roblox simulées), côté serveur puis client.
# Construit l'interpréteur Luau (tools/luaurun, Rust + mlua) au premier lancement.
set -u
cd "$(dirname "$0")/.."
BIN="${LUAURUN:-tools/luaurun/target/release/luaurun}"
if [ ! -x "$BIN" ]; then (cd tools/luaurun && cargo build --release -q) || exit 1; fi
rc=0
"$BIN" tools/smoke.luau src true ReplicatedStorage ServerScriptService ServerStorage 2>&1 | grep -v "^\s*\[warn\]" | tail -40 || rc=1
"$BIN" tools/smoke.luau src false ReplicatedStorage StarterPlayer 2>&1 | grep -v "^\s*\[warn\]" | tail -40 || rc=1
exit $rc
