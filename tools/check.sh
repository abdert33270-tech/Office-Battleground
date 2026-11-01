#!/usr/bin/env bash
# Vérifications rapides : lint Luau (selene) + construction de la place (rojo).
# Usage : tools/check.sh [chemin...]   (défaut : src)
set -u
cd "$(dirname "$0")/.."
SELENE="${SELENE:-$HOME/.cargo/bin/selene}"
ROJO="${ROJO:-$HOME/.cargo/bin/rojo}"
targets=("$@"); [ ${#targets[@]} -eq 0 ] && targets=(src)
out=$("$SELENE" --display-style quiet "${targets[@]}" 2>&1)
errors=$(echo "$out" | grep -c ": error\[" || true)
echo "$out" | grep ": error\[" | head -50
echo "selene: $errors error(s)"
mkdir -p build
if "$ROJO" build -o build/OfficeBattlegrounds.rbxl >/dev/null 2>build/rojo.log; then
  echo "rojo: build OK -> build/OfficeBattlegrounds.rbxl"
else
  cat build/rojo.log; echo "rojo: BUILD FAILED"; exit 1
fi
[ "$errors" -eq 0 ] || exit 2
