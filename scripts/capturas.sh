#!/usr/bin/env bash
# Capturas de todas las pantallas en el emulador de Android, con letra normal,
# grande y máxima. Un solo comando, desde la raíz del repo:
#
#   ./scripts/capturas.sh
#
# Deja los PNG en capturas/<fecha>/<escala>/<nn>_<pantalla>.png y una lámina
# por escala en capturas/<fecha>/lamina_<escala>.png. Si no están corriendo,
# levanta los emuladores de Firebase (auth, firestore y functions) y el de Android, y los
# apaga al terminar. Siempre deja font_scale en 1.0.
#
# Variables opcionales: FLUTTER (por defecto `flutter`), AVD (por defecto
# Medium_Phone_API_36.1), ANDROID_SDK.

set -euo pipefail
cd "$(dirname "$0")/.."

FLUTTER=${FLUTTER:-flutter}
AVD=${AVD:-Medium_Phone_API_36.1}
ANDROID_SDK=${ANDROID_SDK:-${ANDROID_HOME:-${LOCALAPPDATA:-$HOME}/Android/Sdk}}
ADB="$ANDROID_SDK/platform-tools/adb"
FECHA=$(date +%F)
pids=()

limpiar() {
  "$ADB" shell settings put system font_scale 1.0 2>/dev/null || true
  for pid in "${pids[@]}"; do kill "$pid" 2>/dev/null || true; done
}
trap limpiar EXIT

# Emuladores de Firebase. Functions hace falta por el trigger que escribe
# los resúmenes mensuales (months/), de los que salen los gráficos.
arriba() { curl -s -o /dev/null "http://127.0.0.1:$1/"; }
if arriba 9099 && arriba 8080 && arriba 5001; then
  echo "Usando los emuladores de Firebase que ya están corriendo."
elif arriba 9099 || arriba 8080; then
  echo "Hay emuladores de Firebase corriendo sin Functions. Apágalos y vuelve a correr." >&2
  exit 1
else
  echo "Levantando los emuladores de Firebase…"
  npm --prefix functions run build > /dev/null
  npm --prefix functions exec -- firebase emulators:start --only auth,firestore,functions     > "${TMPDIR:-/tmp}/capturas-firebase.log" 2>&1 &
  pids+=($!)
  until arriba 9099 && arriba 8080 && arriba 5001; do sleep 2; done
fi

# Emulador de Android.
if ! "$ADB" devices | grep -q 'emulator-.*device$'; then
  echo "Arrancando el emulador $AVD…"
  "$ANDROID_SDK/emulator/emulator" -avd "$AVD" -no-snapshot-save -no-audio \
    > "${TMPDIR:-/tmp}/capturas-emulador.log" 2>&1 &
  pids+=($!)
  "$ADB" wait-for-device
  until [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]; do sleep 2; done
fi
DISPOSITIVO=$("$ADB" devices | grep -o '^emulator-[0-9]*' | head -1)

for escala in 1.0 1.5 2.0; do
  echo "=== font_scale $escala ==="
  "$ADB" -s "$DISPOSITIVO" shell settings put system font_scale "$escala"
  rm -rf "capturas/$FECHA/$escala"
  CAPTURAS_DIR="capturas/$FECHA/$escala" "$FLUTTER" drive \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/capturas_test.dart \
    -d "$DISPOSITIVO" --dart-define=PAGATE_ENV=dev
  python scripts/lamina.py "capturas/$FECHA/$escala" "capturas/$FECHA/lamina_$escala.png"
done

echo "Listo: capturas/$FECHA"
