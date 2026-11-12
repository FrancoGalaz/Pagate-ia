# scripts/

Utilidades de desarrollo y publicación. Ninguna forma parte del build de la app.

| Script | Qué hace |
|---|---|
| `dev.sh` | Levanta los emuladores de Firebase (Auth 9099, Firestore 8080, Functions 5001, panel 4000). Guarda los datos en `emulator-data/` al cerrar con Ctrl+C y los carga al volver a levantar; para empezar de cero, borra esa carpeta. |
| `seed-demo.js` | Siembra la cuenta de demostración en los emuladores. |
| `generate-android-icons.py` | Regenera los PNG del icono de Android desde la geometría del vector. |
| `deploy-web.sh` | Despliegue a Firebase Hosting (hosting + firestore + functions). |

---

## `seed-demo.js` — cuenta de demostración

Crea `demo@pagate.cl` con un taller de cerámica chileno completo: perfil, valor
hora, 38 movimientos repartidos en los últimos tres meses, 12 ítems de
inventario (4 bajo el stock mínimo, para que se vea el estado de alerta) y 3
gastos fijos.

Tres cosas que los datos **sí** respetan, porque de lo contrario salen en una
captura de la tienda y no cuadran:

- **Los gastos fijos no duplican la cartola.** Son la referencia de lo que se
  paga todos los meses; el arriendo del taller, que es una transacción real con
  su fecha, ya no está además como gasto fijo. Antes estaba en los dos sitios y
  la pantalla de Inicio mostraba las dos cifras una debajo de la otra.
- **El mes en curso no tiene movimientos del futuro.** Los días del mes actual
  se comprimen en los días ya transcurridos (`diaEfectivo`), así que sembrar el
  día 6 no deja ventas fechadas el 24.
- **Los tres meses cierran en positivo**, y el script lo comprueba antes de
  escribir nada.

Sirve para tres cosas: las capturas de la ficha de Google Play, la cuenta de
prueba que hay que entregar en **Play Console → Prueba y publicación → Acceso a
la app**, y probar la app a mano sin teclear treinta movimientos.

### El sembrado manda sobre toda la cuenta demo, no solo sobre lo que escribe

Vacía **siete** subcolecciones de `users/demo-pagate-cl`: las cuatro que escribe
(`transactions`, `inventory`, `fixedExpenses`, `months`) y tres que no escribe
nadie aquí (`conversations`, `aiReports`, `meta`). Las tres últimas son las que
el emulador va acumulando al probar la app a mano, y lo que quedaba dentro no era
dato de demostración. Comprobado en el emulador el 2026-10-06, antes de
ampliarlo: había una conversación con un solo mensaje del usuario y
`messageCount: 0` —una pregunta que el asistente nunca contestó— y `meta/usage`
con `chatCountLifetime: 1`, o sea **un mensaje de los 25 del plan free ya
gastado**. La cuenta que se le entrega al revisor de Play tiene que llegar con
los 25 enteros, y esto es lo único que los devuelve.

El borrado es **recursivo**: `conversations/{id}/messages/` es una subcolección y
un `batch.delete()` sobre el documento padre dejaba los mensajes dentro,
alcanzables por ruta.

Lo que el sembrado **no** toca: otros usuarios del emulador. Si alguien se
registró a mano para probar, su `users/{uid}` sigue ahí. No estorba —las capturas
se toman con la cuenta demo— pero conviene saberlo antes de contar documentos en
el panel.

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
Limpieza: 38 documentos en transactions
Limpieza: 12 documentos en inventory
Limpieza: 3 documentos en fixedExpenses
Limpieza: 3 documentos en months
Transacciones: 38
Inventario: 12 ítems (4 en alerta de stock)
Gastos fijos: 3 (103.490 CLP al mes, sin duplicar ninguna transacción de la cartola)
Contrato C-3: 6 ingresos con docType, 2 con comisión del medio de pago

  2026-08  ingresos 695.500  gastos 602.700  saldo 92.800  comisiones 0  (11 movimientos)
  2026-09  ingresos 1.139.400  gastos 667.600  saldo 471.800  comisiones 0  (13 movimientos)
  2026-10  ingresos 980.000  gastos 640.500  saldo 339.500  comisiones 8.995  (14 movimientos)

Agregados comprobados LEYÉNDOLOS de Firestore: 3 meses con los cuatro campos correctos en 6 lecturas seguidas (6 en total, 5 s estables).
  months/2026-08  totalIncome 695500  totalExpenses 602700  totalPlatformFees 0  transactionCount 11
  months/2026-09  totalIncome 1139400  totalExpenses 667600  totalPlatformFees 0  transactionCount 13
  months/2026-10  totalIncome 980000  totalExpenses 640500  totalPlatformFees 8995  transactionCount 14

Listo. Entra con demo@pagate.cl / PagateDemo2026
Panel de los emuladores: http://localhost:4000/firestore
```

Las líneas de «Limpieza» solo aparecen si ya había datos de una siembra
anterior; la primera vez no salen.

### El bloque de «Agregados comprobados», y cuándo el script sale con 1

`months/{yyyy-MM}` lo escriben **dos** cosas: este script, que actúa de backend
con la misma fórmula que `functions/src/months.ts`, y el trigger
`onTransactionWritten`, que recalcula el mes por cada una de las 38
transacciones que acaba de ver nacer. Quién commitea la última versión no está
en manos del script.

Eso ya falló una vez, y en silencio. El contrato C-3 añadió un cuarto campo,
`totalPlatformFees`, al agregado; el script seguía escribiendo tres, y con el
emulador de Functions corriendo una compilación anterior del trigger los tres
meses de la cuenta demo quedaron **sin las comisiones**. El valor hora neto
salía idéntico al bruto: una cifra que cuadra con otra cosa no se ve como un
error, se ve como un número. Comprobado en el panel: los tres documentos estaban
sin el campo.

Por eso el script termina **volviendo a leer** `months/` y comparándolo con lo
que sembró, y exige **seis lecturas correctas seguidas** (≈5 s) antes de dar
verde: una sola lectura puede caer antes de que el trigger escriba, y entonces
el verde certificaría un estado que cuatro segundos después ya no existe. Si no
cuadra, imprime campo por campo lo que falta, el mensaje final dice «SEMBRADO
INCOMPLETO» y **sale con código 1**.

Si falla ahí, lo primero es reconstruir el backend **en el directorio desde el
que se levantaron los emuladores** —es de ahí de donde el emulador de Functions
sirve `functions/lib/`— y volver a sembrar:

```bash
npm --prefix functions run build
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

El Admin SDK **no** pasa por `firestore.rules`: un documento mal formado se
escribe sin protestar y revienta después, en el cliente. Por eso el script lleva
su propia `validarDatos()`, que corre **antes** de tocar Firestore y aborta sin
escribir nada si:

- un **gasto fijo duplica** una transacción del mes en curso (por nombre o por
  monto);
- una **categoría** no está entre las de `incomeCategories` /
  `expenseCategories`
  (`lib/features/finances/presentation/widgets/transaction_form_sheet.dart`);
- un `docType` no es uno de los tres del contrato C-3, o va en un gasto;
- una comisión no cabe en el monto (`platformFee <= amount`, el mismo tope que
  `firestore.rules`);
- algún mes **cierra en rojo**.

La forma de cada documento sigue siendo la del contrato de
`docs/ARQUITECTURA.md`, que es lo que validan las reglas; eso la validación del
script no lo cubre.

### Los campos chilenos del contrato C-3

El mes en curso siembra `docType` y `platformFee` para que se vean funcionando:
seis ingresos con documento (boleta de venta, boleta de honorarios y sin
documento) y dos con comisión del medio de pago. Los **meses cerrados quedan sin
esos campos a propósito**: son opcionales, es el caso real de los movimientos
registrados antes del contrato, y así queda sembrada la prueba de que la app los
sigue leyendo.

La comisión se calcula en el script (3,19 % del monto, redondeado). Ese
porcentaje es el que circula para Mercado Pago en Chile y
`docs/FICHA-PLAY.md` §3 lo marca como **no verificado en la fuente**: aquí es el
número que la usuaria de la demostración anotó, no una afirmación sobre la
tarifa de nadie. La app nunca aplica una tasa por su cuenta.

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
