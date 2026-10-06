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

El script no pregunta nada y termina en segundos. Esta es su salida real
(ejecutada el 2026-10-06 contra los emuladores; los meses son relativos a hoy,
así que las tres líneas del resumen cambian de nombre cada mes):

```
Auth: usuario demo@pagate.cl actualizado (uid demo-pagate-cl)
Perfil: Camila Rojas · Greda Austral · meta 1.200.000 CLP · valor hora 7.500 CLP
Limpieza: 35 documentos en transactions
Limpieza: 12 documentos en inventory
Limpieza: 4 documentos en fixedExpenses
Limpieza: 3 documentos en months
Transacciones: 35
Inventario: 12 ítems (4 en alerta de stock)
Gastos fijos: 4

  2026-08  ingresos 550.500  gastos 602.700  saldo -52.200  (10 movimientos)
  2026-09  ingresos 1.139.400  gastos 667.600  saldo 471.800  (13 movimientos)
  2026-10  ingresos 644.000  gastos 640.500  saldo 3.500  (12 movimientos)
```

Las líneas de «Limpieza» solo aparecen si ya había datos de una siembra
anterior; la primera vez no salen. Los agregados de `months/` los escribe aquí
el propio script —con la misma fórmula que `functions/src/months.ts`— porque
actúa como backend; si el emulador de Functions está arriba, el trigger
`onTransactionWritten` se dispara además y llega al mismo resultado, así que
las dos escrituras convergen en vez de pelearse.

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

## `generate-android-icons.py` — iconos de Android

Regenera los PNG del lanzador y el icono de 512×512 de la ficha de Play a partir
de la misma geometría que el vector adaptativo
(`android/app/src/main/res/drawable/ic_launcher_foreground.xml`).

### Cuándo hay que ejecutarlo

Solo si cambia el dibujo del icono: el `pathData` del vector o el color de
`android/app/src/main/res/values/ic_launcher_colors.xml`. En un día normal no se
toca: los PNG ya están versionados.

### Cómo ejecutarlo

```bash
pip install Pillow          # única dependencia
python scripts/generate-android-icons.py
```

Reescribe once archivos y los lista por pantalla:

```
android/app/src/main/res/mipmap-mdpi/ic_launcher.png      (48x48)
android/app/src/main/res/mipmap-mdpi/ic_launcher_round.png  (48x48)
android/app/src/main/res/mipmap-hdpi/...                  (72x72)
android/app/src/main/res/mipmap-xhdpi/...                 (96x96)
android/app/src/main/res/mipmap-xxhdpi/...                (144x144)
android/app/src/main/res/mipmap-xxxhdpi/...               (192x192)
android/play/icon-512.png                                 (512x512)
```

Es determinista: ejecutarlo sin cambiar nada deja los archivos **idénticos byte
a byte**, así que `git status` no debe reportar nada después. Comprobado el
2026-10-06. Si reporta cambios, es que alguien editó un PNG a mano.

### Si tocas el vector, hay que tocar el script

La geometría está escrita **dos veces**: en el `pathData` del vector y en las
constantes del script. Nada las sincroniza. El script lo advierte en su propia
cabecera; si solo se cambia una de las dos, el icono adaptativo (Android 8+) y
los PNG legacy (API 24–25) dejan de ser el mismo dibujo y el fallo no se ve
hasta instalarlo en un teléfono viejo.

### Cómo comprobar que el icono se ve bien de verdad

Mirar el PNG en el editor no sirve: lo que pinta el lanzador en Android 8+ es el
vector recortado por la máscara del sistema, no el PNG. Hay que instalarlo:

```bash
PATH=$PATH:"$LOCALAPPDATA/Android/Sdk/platform-tools"

flutter build apk --release
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-release.apk

# Cajón de aplicaciones y captura
adb -s emulator-5554 shell input keyevent KEYCODE_HOME
adb -s emulator-5554 shell input swipe 540 2000 540 500 150
adb -s emulator-5554 exec-out screencap -p > docs/capturas/icono.png
```

> Si `adb install` responde `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, es que en el
> emulador hay una instalación anterior firmada con otra clave (típicamente un
> build de depuración). Se quita con
> `adb -s emulator-5554 uninstall com.pagate.apppagate`.

Y mirar la captura de verdad, a tamaño real: que el símbolo no quede cortado por
la máscara circular, que no se vea borroso y que se distinga del resto del
cajón. La última comprobación hecha así está en
`docs/capturas/06-icono-adaptativo-cajon-aplicaciones.png` (Android 16, 420 dpi):
el glifo ocupa el 58 % del ancho del disco y queda centrado, muy dentro del
círculo seguro de 66 dp.

El nombre que sale bajo el icono no lo decide este script: es
`@string/app_name`, en `android/app/src/main/res/values/strings.xml`.
