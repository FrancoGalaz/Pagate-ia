#!/usr/bin/env bash
# Levanta los emuladores de Firebase (Auth 9099, Firestore 8080, Functions 5001).
# En otra terminal, corre la app apuntando a los emuladores:
#   flutter run --dart-define=PAGATE_ENV=dev
# Los datos se guardan en emulator-data/ al cerrar (Ctrl+C) y se cargan al
# volver a levantar. Para empezar de cero, borra esa carpeta.
set -euo pipefail
cd "$(dirname "$0")/.."

[ -d functions/node_modules ] || npm --prefix functions ci
npm --prefix functions run build

echo ""
echo "▶ App contra emuladores:  flutter run --dart-define=PAGATE_ENV=dev"
echo "▶ UI de emuladores:       http://localhost:4000"
echo ""
exec npm --prefix functions exec -- firebase emulators:start \
  --import=./emulator-data --export-on-exit
