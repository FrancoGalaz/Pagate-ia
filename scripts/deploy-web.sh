#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────
# Págate-IA — Web Deploy Script
# ──────────────────────────────────────────────────────────────────────
# Prerequisitos:
#   1. flutter pub get
#   2. flutter build web
#   3. firebase deploy
#
# Uso:
#   ./scripts/deploy-web.sh
#
# Para compilar con API key del chat:
#   ./scripts/deploy-web.sh --dart-define=OPENROUTER_API_KEY=sk-or-...
# ──────────────────────────────────────────────────────────────────────
set -euo pipefail

DART_DEFINES="${*}"

echo "🚀 Págate-IA — Deploy Web"
echo "══════════════════════════"
echo ""

# 1. Build Flutter Web
echo "📦 Compilando Flutter Web..."
cd "$(dirname "$0")/.."
flutter clean
flutter pub get
if [ -n "$DART_DEFINES" ]; then
  flutter build web --release $DART_DEFINES
else
  flutter build web --release
fi
echo "✅ Build completado en build/web/"
echo ""

# 2. Deploy to Firebase
echo "☁️  Deployando a Firebase Hosting..."
firebase deploy --only hosting
echo "✅ Deploy completado"
echo ""

# 3. Show URL
echo "🌐  https://pagate-17211.web.app"
