# AGENTS

Guía para agentes que trabajan en este repo. La fuente de verdad del modelo de
datos, la API del backend y las convenciones del cliente es
`docs/ARQUITECTURA.md`: léelo antes de tocar `lib/`, `functions/` o
`firestore.rules`. La del sistema visual es `docs/diseno/widgets.md` junto con
el código (`lib/core/theme/`, `lib/core/constants/app_constants.dart`,
`lib/core/widgets/`): léelos antes de tocar cualquiera de ellos o una
pantalla. `docs/DISENO-v2.md` y `docs/diseno/variantes-cabal.html` son
históricos. Lo que falta para subir a Google Play está en `docs/FICHA-PLAY.md`.

## Entorno y toolchain
- Flutter/Dart del canal **beta**: `pubspec.yaml` exige `sdk: ^3.12.0-113.1.beta` y `.metadata` está en `channel: beta`.
- Node 22 para `functions/` y `landing/`. Java 21 para el emulador de Firestore.
- Fuente **Manrope** empaquetada como variable font en `assets/fonts/Manrope[wght].ttf`.
- Bootstrap: `flutter pub get`, `npm --prefix functions ci`, `npm --prefix landing ci`.

## Comandos de verificación
- Análisis estático: `flutter analyze`
- Tests Flutter: `flutter test` (un archivo: `flutter test test/widget_test.dart`)
- Backend: `npm --prefix functions run lint && npm --prefix functions run build && npm --prefix functions test`
  (el último levanta su propio emulador de Firestore en el puerto **8181**, con
  `firebase.test.json`, para no tocar el de desarrollo del 8080). Los tests de
  reglas borran la base en cada caso: **nunca** los lances con `vitest` a mano,
  o apuntan el borrado al emulador que tenga datos; fallan rápido si lo
  intentas.
- Landing: `npm --prefix landing run lint && npm --prefix landing test && npm --prefix landing run build`
- App en local contra emuladores: `./scripts/dev.sh` y luego `flutter run --dart-define=PAGATE_ENV=dev`
- App contra producción: `flutter run` (o `flutter run -d chrome`)

## Cómo está cableada la app
- Entrada: `lib/main.dart` → `PagateIAApp` (solo provee
  `FirebaseAuthService`) → `AuthGate`
  (`lib/features/auth/presentation/pages/auth_gate.dart`), que escucha
  `authStateChanges`: sin usuario → `WelcomeScreen`; con usuario sin
  `users/{uid}` → onboarding; con perfil → `DashboardScreen`.
- El `MaterialApp` lo monta `AppShell`
  (`lib/features/auth/presentation/widgets/app_shell.dart`), con
  `AppTheme.lightTheme` y `themeMode: ThemeMode.light`. Su `key` cambia con la
  sesión para que el `Navigator` se cree de cero y ninguna ruta apilada
  sobreviva a un cambio de usuario.
- Los providers con alcance de usuario se crean **debajo** del auth gate con
  `key: ValueKey(uid)`. No existe el usuario `'anonymous'`.
- Entorno con `--dart-define=PAGATE_ENV=dev|prod` (`prod` por defecto). En
  `dev` el cliente apunta a los emuladores (Auth 9099, Firestore 8080,
  Functions 5001; `10.0.2.2` en el emulador Android).
- App Check: proveedores debug en modo debug; Play Integrity (Android) y
  reCAPTCHA v3 (web, `--dart-define=APP_CHECK_SITE_KEY=...`) en release.
- Estructura por feature: `features/<feature>/{data,domain,presentation}` con
  Provider (no Bloc/Cubit). Constructores estables de datasources/providers en
  `docs/ARQUITECTURA.md`.

## Capa de datos
- Todo dato de usuario cuelga de `users/{uid}`:
  `inventory/`, `transactions/`, `fixedExpenses/`, `aiReports/`,
  `months/` (solo backend), `conversations/{id}/messages/` (solo backend),
  `meta/usage` (solo backend).
- `aiReports/` son los reportes de respuestas del asistente (**P-12**: la
  política de IA generativa de Google Play exige poder marcar contenido
  ofensivo o dañino dentro de la app). Es la única subcolección que el cliente
  **crea y después no puede tocar**: `create` y `read` para el dueño, `update` y
  `delete` denegados. Un reporte es la prueba de que alguien marcó una
  respuesta; si se pudiera editar o borrar, esa prueba desaparece. Campos:
  `messageId`, `conversationId` (opcional), `reason`
  (`ofensivo` | `incorrecto` | `peligroso` | `otro`), `comment` (opcional,
  ≤1000), `reportedText` (≤2000) y las dos marcas de tiempo del servidor.
- Ids generados por Firestore, fechas como `Timestamp`, sin campo `userId`
  duplicado. `monthKey` es `yyyy-MM` derivado de `date` en el cliente, con el
  mes acotado a 01-12 (mismo regex en reglas y en `months.ts`).
- Contrato **C-3** en `transactions`: `docType`
  (`boleta_venta` | `boleta_honorarios` | `sin_documento`) y `platformFee`
  (`0 <= platformFee <= amount`, **solo en los ingresos**), los dos
  **opcionales**. Ausentes valen `'sin_documento'` y `0`. El neto de una
  transacción **no se guarda**: se deriva como `amount - platformFee`. La app
  registra y muestra, **no asesora**: nada de calcular impuestos a pagar ni dar
  consejo tributario, ni en el cliente ni en el prompt del asistente.
- Las lecturas son **streams** (`snapshots()`), nunca `get()` puntuales.
- Los providers exponen `error` (String?) y `retry()`. Nunca devolver una
  lista vacía como si fuera un estado válido ante un error.
- Los agregados mensuales los calcula el trigger `onTransactionWritten`; el
  cliente no escribe `months/*`.
- `meta/usage` lleva **cuatro** contadores de IA y un solo `dayKey`:
  `chatCountDay` / `chatCountLifetime` (asistente) y `scanCountDay` /
  `scanCountLifetime` (lector de boletas). Las cuotas son independientes, pero
  el `dayKey` es compartido, así que escribirlo por una AVALA el contador diario
  de la otra: al cambiar el día se reinician **los dos**. Está en `quota.ts` con
  su test en los dos sentidos; no quitarlo.
- El lector de boletas no añade campos al inventario: `supplier` y `code` ya
  estaban permitidos en `validInventoryItem` y eran código muerto. `stock` y
  `minStock` siguen siendo **enteros** (`isCount` exige `v is int`); una
  cantidad fraccionaria del OCR la redondea el cliente delante del usuario.

## Backend (`functions/`, TypeScript, Node 22, `southamerica-west1`)
- `chat` (callable): auth + App Check + cuota + prompt del lado servidor +
  OpenRouter con el secreto `OPENROUTER_API_KEY` + persistencia de la
  conversación. El cliente **no** escribe en `messages`.
  - Cuota: plan `free` **25 mensajes DE POR VIDA** (`chatCountLifetime`), NO
    diarios; plan `pro` **300 al día** (`chatCountDay`). Más un tope global
    diario con interruptor en `system/aiConfig`, que el dueño cambia desde la
    consola sin desplegar. El día se calcula en `America/Santiago`.
  - Historial reenviado al modelo: **6** mensajes (`HISTORY_LIMIT`). Era 20; el
    historial viaja completo en cada turno, así que ese número multiplica los
    tokens de entrada de toda la conversación.
  - Si OpenRouter falla, la cuota se devuelve y lo escrito se deshace.
  - **No existe ningún plan Pro que se pueda comprar**: no hay
    `in_app_purchase` ni integración de facturación en el proyecto. `pro` es un
    valor del campo `plan` que solo escribe el backend o el dueño a mano.
    Ningún texto que lea el usuario puede ofrecerlo: anunciar dentro de la app
    un plan de pago que no pasa por la facturación de Google Play incumple su
    política. El candado está en `functions/test/quota.test.ts`.
  - El prompt lleva los campos chilenos de C-3 (documento de cada ingreso, y
    bruto/comisión/neto) y prohíbe explícitamente la asesoría tributaria.
- `scanReceipt` (callable): ordena el **texto** de una boleta de compra como
  lista de artículos para el inventario. Lo nuevo que hay que tener claro:
  - **Recibe TEXTO, nunca una imagen.** El OCR corre en el teléfono con ML Kit
    y la imagen se borra ahí. Por eso el proyecto no tiene Firebase Storage, ni
    fotos que declarar en Seguridad de Datos, ni imágenes que borrar al borrar
    una cuenta. No añadir un campo de imagen a este callable.
  - **Es un repaso, no el camino único.** El cliente ya ordenó la lista él solo,
    sin conexión. Un fallo de aquí no rompe nada, y `resource-exhausted` el
    cliente lo trata como **información**, no como error.
  - **Nada se guarda sin que el usuario lo revise.** La app propone, confirma
    el usuario.
  - Cuota **propia**: `scanCountLifetime` (free, 40 de por vida) y
    `scanCountDay` (pro, 200 al día), con `freeLifetimeScanQuota` y
    `proDailyScanQuota` en `system/aiConfig`. Los contadores del chat no se
    tocan. El tope global del dueño sí suma los dos (`calls + scanCalls`).
  - La salida del modelo se **valida campo por campo** en TypeScript: el
    `response_format` de tipo `json_schema` es una petición al proveedor, no una
    garantía. Un artículo inválido se descarta; `items: []` es una respuesta
    válida y el cliente se queda con su lista local.
  - La cuota se devuelve ante un fallo del proveedor (red, plazo, salida
    irrecuperable). **No** se devuelve cuando el modelo contestó bien y la lista
    salió vacía: el texto lo controla quien llama, y devolverla ahí abriría una
    vía para llamar al modelo sin límite a costa del dueño.
  - El prompt reutiliza `DATA_OPEN`, `DATA_CLOSE` y `sanitizeField` de
    `prompt.ts`, pero saneando **línea por línea** (`sanitizeOcrText`): aplanar
    los saltos de línea destruiría la estructura de la boleta.
- `deleteAccount` (callable): auth + App Check, borra `users/{uid}` y todo su
  árbol y luego el usuario de Authentication, en ese orden. Lo exige la política
  de borrado de datos de Google Play. Por eso las reglas deniegan `delete` en
  `users/{uid}`.
- `onTransactionWritten`: recalcula `months/{monthKey}` (ambos meses si cambió
  `monthKey`) dentro de una transacción. Idempotente. `months/*` guarda
  `totalIncome` (bruto), `totalExpenses`, `totalPlatformFees` (comisiones de los
  **ingresos** del mes) y `transactionCount`. El neto del mes se **deriva**
  (`totalIncome - totalPlatformFees`); no se guarda ningún neto.
  - Las comisiones se suman en una agregación **aparte**, y eso no se puede
    "simplificar" metiéndolas en la misma `aggregate()`: en agregación
    combinada, un `sum('platformFee')` restringe el conjunto a los documentos
    que **tienen** el campo, y como es opcional, los totales del mes pasarían a
    contar solo las ventas con comisión. El por qué, medido contra el emulador,
    está en `docs/ARQUITECTURA.md` y en el test
    «mezcla ingresos con y sin comision sin perder ninguno».
- `waitlist` (HTTP): `POST {name, email, source}` → `200 {ok:true}` |
  `400/429 {error}`. Lo consume `landing/src/services/waitlist-service.ts`. El
  id del documento es el sha256 del correo normalizado: reenviar no duplica.
- Parámetros: `ENFORCE_APP_CHECK` (default `false`, aplica a los TRES
  callables), `OPENROUTER_MODEL` y `OPENROUTER_SCAN_MODEL` (mandos separados a
  propósito: el chat y el lector piden cosas distintas al modelo).
- `firebase.json`: las cabeceras de enmarcado (`X-Frame-Options`,
  `frame-ancestors`) van en los `source` `/`, `/!(__)` y `/!(__)/**`, NUNCA en
  `**`. Sobre `**` alcanzan a `/__/auth/iframe`, que es el iframe del login con
  Google, y lo rompen. El por qué completo está en `docs/ARQUITECTURA.md`.
- Ningún secreto se compila en el cliente. No reintroducir
  `--dart-define=OPENROUTER_API_KEY`.

## UI y theming
- `lib/core/constants/app_constants.dart` es la fuente de tokens (colores,
  spacing, radios, tamaños, duraciones). No hardcodear estilos.
- `lib/core/theme/app_theme.dart` centraliza el tema Material. **Tema claro
  único**: solo existe `lightTheme` y no hay `darkTheme`; `app_shell.dart` fija
  `themeMode: ThemeMode.light` para que la app no siga al sistema, y ningún
  widget decide colores según `brightness`.
- Widgets compartidos en `lib/core/widgets/` (export en `widgets.dart`).
- Breakpoint web/mobile 720 px: NavigationRail en escritorio,
  BottomNavigationBar en móvil.

## Límites del repo / archivos que no son app
- `landing/` es la landing (Vite + React). `landing-page/` es su build
  publicado en GitHub Pages: no editarlo a mano.
- `docs/prototipos/` contiene los prototipos HTML/JSX de diseño; no forman
  parte del build ni de los tests.
- `.mcp.json` está ignorado por git (contiene tokens locales). No versionarlo.
- Secretos y entornos locales ignorados: `*.env`, `.env.*`, `landing/.env*`,
  `functions/.npmrc`, `landing/.npmrc`, `.firebase/`, logs de emuladores.
- Excepción intencional: `functions/.env` (parámetros no secretos de Functions)
  y `landing/.env.production` (URL pública de `waitlist`) **sí se versionan**,
  con su `!` en `.gitignore`. No contienen secretos y no deben contenerlos: los
  secretos van a Secret Manager.

## Despliegue
- Local: `APP_CHECK_SITE_KEY=... ./scripts/deploy-web.sh` (hosting +
  firestore + functions).
- CI: `.github/workflows/ci.yml` en cada push/PR; `deploy-web.yml` manual o por
  tag `v*` (secretos `FIREBASE_SERVICE_ACCOUNT`, `APP_CHECK_SITE_KEY`).
- Lo que solo puede hacer el dueño en consola está en el README
  (checklist de configuración).

## Reglas para agentes autónomos
- Avanzar sin preguntar; pausar solo ante bloqueos reales (credenciales,
  consola de Firebase, decisiones de producto).
- Respetar el contrato de `docs/ARQUITECTURA.md`. Si hay que cambiarlo, cambiar
  primero el documento y luego reglas, funciones y datasources.
- Commits locales, atómicos y descriptivos, en español. **Nada de `git push` ni
  de cualquier otra operación contra `origin` sin que el dueño lo pida
  explícitamente**, y él lo comprueba. Verificación en verde
  (`flutter analyze`, `flutter test`, `npm --prefix functions run lint`,
  `run build` y `test`) **antes de commitear**, no antes de subir.
- Usar los tokens de `app_constants.dart`; seguir `data/domain/presentation`
  con Provider para features nuevas.
- Tests: unitarios de casos de uso en `test/features/<feature>/`, widget tests
  sin Firebase (fakes de repositorios, `MaterialApp` + `AppTheme`).
- Lints activos además de `flutter_lints`: `prefer_single_quotes`,
  `avoid_print`, `unawaited_futures`, `prefer_const_constructors`.
