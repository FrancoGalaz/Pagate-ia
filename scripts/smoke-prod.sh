#!/usr/bin/env bash
# Prueba de humo contra producción, para correr después de desplegar.
# No usa credenciales: todo lo que hace es leer o llamar sin sesión.
#
#   ./scripts/smoke-prod.sh
#
# Las URL se pueden cambiar por variables de entorno (por ejemplo, para
# probar contra los emuladores o contra otra URL de la landing):
#   FIRESTORE_URL  (por defecto https://firestore.googleapis.com)
#   FUNCTIONS_URL  (por defecto https://southamerica-west1-pagate-17211.cloudfunctions.net)
#   LANDING_URL    (por defecto https://francogalaz.github.io/Pagate-ia/landing-page)
#
# Sale con 0 si todo pasa y con 1 si algo falla.

set -u
export LC_ALL=C.UTF-8

PROJECT=pagate-17211
FIRESTORE_URL=${FIRESTORE_URL:-https://firestore.googleapis.com}
FUNCTIONS_URL=${FUNCTIONS_URL:-https://southamerica-west1-$PROJECT.cloudfunctions.net}
LANDING_URL=${LANDING_URL:-https://francogalaz.github.io/Pagate-ia/landing-page}
LANDING_URL=${LANDING_URL%/}
LEGAL_META="$(dirname "$0")/../landing/src/content/legal-meta.ts"

# Un marcador es un corchete seguido de una palabra en mayúsculas, como
# «[RUT DEL RESPONSABLE]». Así no confunde los arreglos del JS minificado.
MARCADOR='\[[A-ZÁÉÍÓÚÑ]{3,}[ :]'

fallos=0
ok() { echo "OK    $1"; }
falla() { echo "FALLA $1"; fallos=$((fallos + 1)); }
cuerpo=$(mktemp)
trap 'rm -f "$cuerpo"' EXIT

# 1. Reglas de Firestore: una lectura sin sesión de users/x se rechaza.
#    Ojo: con la API deshabilitada Google también responde 403
#    PERMISSION_DENIED, pero con un ErrorInfo (`"reason": "SERVICE_DISABLED"`).
#    El rechazo de las reglas no trae `reason`.
codigo=$(curl -s -o "$cuerpo" -w '%{http_code}' \
  "$FIRESTORE_URL/v1/projects/$PROJECT/databases/(default)/documents/users/x")
if [ "$codigo" = 403 ] && grep -q PERMISSION_DENIED "$cuerpo" \
  && ! grep -q '"reason"' "$cuerpo"; then
  ok "Firestore rechaza leer users/x sin sesión"
else
  falla "Firestore: se esperaba el rechazo de las reglas (403 PERMISSION_DENIED sin reason) y llegó $codigo: $(head -c 200 "$cuerpo")"
fi

# 2. Functions en southamerica-west1: chat sin sesión da unauthenticated.
codigo=$(curl -s -o "$cuerpo" -w '%{http_code}' -X POST \
  -H 'Content-Type: application/json' -d '{"data":{"message":"hola"}}' \
  "$FUNCTIONS_URL/chat")
if [ "$codigo" = 401 ] && grep -q UNAUTHENTICATED "$cuerpo"; then
  ok "chat responde unauthenticated sin sesión"
else
  falla "chat: se esperaba 401 UNAUTHENTICATED y llegó $codigo: $(head -c 200 "$cuerpo")"
fi

# 3. Landing: las cuatro páginas responden 200.
for ruta in "" privacidad/ terminos/ eliminar-cuenta/; do
  codigo=$(curl -s -o /dev/null -w '%{http_code}' "$LANDING_URL/$ruta")
  if [ "$codigo" = 200 ]; then
    ok "landing /$ruta responde 200"
  else
    falla "landing /$ruta: se esperaba 200 y llegó $codigo"
  fi
done

# 4. /privacidad/ sin marcadores. La página la pinta el JS, así que se revisan
#    el HTML y los .js que carga, no solo el HTML.
origen=$(echo "$LANDING_URL" | grep -oE '^https?://[^/]+')
if curl -sf -o "$cuerpo" "$LANDING_URL/privacidad/"; then
  encontrados=$(grep -oE "$MARCADOR" "$cuerpo")
  for js in $(grep -oE '(src|href)="[^"]+\.js"' "$cuerpo" | cut -d'"' -f2); do
    case "$js" in
      http*) url=$js ;;
      /*) url=$origen$js ;;
      *) url=$LANDING_URL/privacidad/$js ;;
    esac
    encontrados+=$(curl -s "$url" | grep -oE "$MARCADOR")
  done
  if [ -z "$encontrados" ]; then
    ok "/privacidad/ no tiene marcadores sin reemplazar"
  else
    falla "/privacidad/ tiene marcadores: $(echo "$encontrados" | sort -u | tr '\n' ' ')"
  fi
else
  falla "/privacidad/ no se pudo descargar para buscar marcadores"
fi

# 5. legal-meta.ts sin marcadores (solo en los textos entre comillas, no en
#    los comentarios que los explican).
encontrados=$(grep -nE "'$MARCADOR" "$LEGAL_META")
if [ -z "$encontrados" ]; then
  ok "legal-meta.ts no tiene marcadores"
else
  falla "legal-meta.ts tiene marcadores:"
  echo "$encontrados" | sed 's/^/      /'
fi

echo
if [ "$fallos" -eq 0 ]; then
  echo "Todo OK."
  exit 0
fi
echo "$fallos chequeo(s) fallaron."
exit 1
