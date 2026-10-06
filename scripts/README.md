# scripts/

Utilidades de desarrollo y publicación. Ninguna forma parte del build de la app.

| Script | Qué hace |
|---|---|
| `dev.sh` | Levanta los emuladores de Firebase (Auth 9099, Firestore 8080, Functions 5001, panel 4000). |
| `seed-demo.js` | Siembra la cuenta de demostración en los emuladores. |
| `generate-android-icons.py` | Regenera los PNG del icono de Android desde la geometría del vector. |
| `deploy-web.sh` | Despliegue a Firebase Hosting (hosting + firestore + functions). |

---

## `seed-demo.js` — cuenta de demostración

Crea `demo@pagate.cl` con un taller de cerámica chileno completo: perfil, valor
hora, 35 movimientos repartidos en los últimos tres meses, 12 ítems de
inventario (4 bajo el stock mínimo, para que se vea el estado de alerta) y 4
gastos fijos.

Sirve para tres cosas: las capturas de la ficha de Google Play, la cuenta de
prueba que hay que entregar en **Play Console → Prueba y publicación → Acceso a
la app**, y probar la app a mano sin teclear treinta movimientos.

### Credenciales

```
correo:      demo@pagate.cl
contraseña:  PagateDemo2026
uid:         demo-pagate-cl
```

### Cómo ejecutarlo

Requisitos: `npm --prefix functions ci` hecho al menos una vez (el script
reutiliza el `firebase-admin` de `functions/` en lugar de instalar el suyo).

```bash
# Terminal 1 — emuladores
./scripts/dev.sh

# Terminal 2 — siembra
FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 \
FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \
GCLOUD_PROJECT=pagate-17211 \
node scripts/seed-demo.js
```

En PowerShell:

```powershell
$env:FIRESTORE_EMULATOR_HOST     = '127.0.0.1:8080'
$env:FIREBASE_AUTH_EMULATOR_HOST = '127.0.0.1:9099'
$env:GCLOUD_PROJECT              = 'pagate-17211'
node scripts/seed-demo.js
```

Luego, la app contra los emuladores:

```bash
flutter run --dart-define=PAGATE_ENV=dev
```

### Solo escribe en los emuladores

El script **aborta** si no están definidas `FIRESTORE_EMULATOR_HOST` y
`FIREBASE_AUTH_EMULATOR_HOST`. Es a propósito: el Admin SDK no pasa por
`firestore.rules`, así que sin esa comprobación una variable de entorno mal
puesta volcaría datos inventados en el proyecto real.

Es idempotente: los ids de documento son fijos y las subcolecciones se vacían
antes de escribir, así que reejecutarlo deja el mismo estado en vez de duplicar.

### Cómo comprobar que quedó sembrado

En el panel: <http://localhost:4000/firestore> → `users/demo-pagate-cl`.

Desde la terminal, contra el emulador (el token `owner` salta las reglas, cosa
que solo funciona en el emulador):

```bash
BASE='http://127.0.0.1:8080/v1/projects/pagate-17211/databases/(default)/documents'
curl -s -H 'Authorization: Bearer owner' "$BASE/users/demo-pagate-cl"
curl -s -H 'Authorization: Bearer owner' "$BASE/users/demo-pagate-cl/transactions?pageSize=300"
```

> Sin la cabecera `Authorization` la respuesta es un **403 PERMISSION_DENIED**:
> el REST del emulador sí evalúa `firestore.rules`, y las reglas exigen ser el
> dueño del documento. Eso no significa que falte el dato.

### Si cambias los datos sembrados

Las categorías de los movimientos tienen que seguir siendo las seis de
`transactionCategories`
(`lib/features/finances/presentation/widgets/transaction_form_sheet.dart`), y la
forma de cada documento, la del contrato de `docs/ARQUITECTURA.md`, que es
además lo que validan las reglas. El Admin SDK no las comprueba: un documento
mal formado se escribe sin protestar y revienta después en el cliente.

---

## `generate-android-icons.py`

Regenera los PNG del lanzador y el icono de 512×512 de la ficha de Play a partir
de la misma geometría que el vector adaptativo
(`android/app/src/main/res/drawable/ic_launcher_foreground.xml`).

```bash
python scripts/generate-android-icons.py   # requiere Pillow
```

Escribe `mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`, los
`ic_launcher_round.png` y `android/play/icon-512.png`. Si tocas el `pathData`
del vector, hay que replicar el cambio en las constantes del script y volver a
ejecutarlo: son dos copias de la misma forma y nada automático las sincroniza.
