#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# Págate-IA — Deploy completo: Flutter web + hosting + reglas + functions
# ──────────────────────────────────────────────────────────────────────
# Uso:
#   ./scripts/deploy-web.sh
#   APP_CHECK_SITE_KEY=6Lc... ./scripts/deploy-web.sh   # reCAPTCHA v3 (web)
#
# Requisitos: flutter (beta), node 22, sesión iniciada con
#   npm --prefix functions exec -- firebase login
# La clave de OpenRouter NO se compila en el cliente: vive en Secret Manager
# (npm --prefix functions exec -- firebase functions:secrets:set OPENROUTER_API_KEY).
# ──────────────────────────────────────────────────────────────────────
set -euo pipefail

cd "$(dirname "$0")/.."

DART_DEFINES=(--dart-define=PAGATE_ENV=prod)
if [ -n "${APP_CHECK_SITE_KEY:-}" ]; then
  DART_DEFINES+=(--dart-define=APP_CHECK_SITE_KEY="$APP_CHECK_SITE_KEY")
else
  echo "⚠️  APP_CHECK_SITE_KEY no definida: App Check no se activará en web."
fi

echo "📦 Compilando Flutter Web..."
flutter pub get
flutter build web --release "${DART_DEFINES[@]}"
echo "✅ build/web listo"

echo "📦 Compilando Cloud Functions..."
npm --prefix functions ci
npm --prefix functions run build

echo "☁️  Desplegando hosting, firestore y functions..."
npm --prefix functions exec -- firebase deploy --only hosting,firestore,functions

echo "🌐 https://pagate-17211.web.app"
