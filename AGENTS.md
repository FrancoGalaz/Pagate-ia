# AGENTS

Guía para agentes que trabajan en este repo. La fuente de verdad del modelo de
datos, la API del backend y las convenciones del cliente es
`docs/ARQUITECTURA.md`: léelo antes de tocar `lib/`, `functions/` o
`firestore.rules`.

## Entorno y toolchain
- Flutter/Dart del canal **beta**: `pubspec.yaml` exige `sdk: ^3.12.0-113.1.beta` y `.metadata` está en `channel: beta`.
- Node 22 para `functions/` y `landing/`. Java 21 para el emulador de Firestore.
- Fuente **Manrope** empaquetada como variable font en `assets/fonts/Manrope[wght].ttf`.
- Bootstrap: `flutter pub get`, `npm --prefix functions ci`, `npm --prefix landing ci`.

## Comandos de verificación
- Análisis estático: `flutter analyze`
- Tests Flutter: `flutter test` (un archivo: `flutter test test/widget_test.dart`)
- Backend: `npm --prefix functions run build && npm --prefix functions test` (levanta el emulador de Firestore)
- Landing: `npm --prefix landing run lint && npm --prefix landing test && npm --prefix landing run build`
- App en local contra emuladores: `./scripts/dev.sh` y luego `flutter run --dart-define=PAGATE_ENV=dev`
- App contra producción: `flutter run` (o `flutter run -d chrome`)

## Cómo está cableada la app
- Entrada: `lib/main.dart`. El widget raíz escucha `authStateChanges`:
  sin usuario → `WelcomeScreen`; con usuario sin `users/{uid}` → onboarding;
  con perfil → `DashboardScreen`.
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
  `inventory/`, `transactions/`, `fixedExpenses/`, `months/` (solo backend),
  `conversations/{id}/messages/` (solo backend), `meta/usage` (solo backend).
- Ids generados por Firestore, fechas como `Timestamp`, sin campo `userId`
  duplicado. `monthKey` es `yyyy-MM` derivado de `date` en el cliente, con el
  mes acotado a 01-12 (mismo regex en reglas y en `months.ts`).
- Contrato **C-3** en `transactions`: `docType`
  (`boleta_venta` | `boleta_honorarios` | `sin_documento`) y `platformFee`
  (`0 <= platformFee <= amount`), los dos **opcionales**. Ausentes valen
  `'sin_documento'` y `0`. El neto **no se guarda**: se deriva como
  `amount - platformFee`. La app registra y muestra, **no asesora**: nada de
  calcular impuestos a pagar ni dar consejo tributario.
- Las lecturas son **streams** (`snapshots()`), nunca `get()` puntuales.
- Los providers exponen `error` (String?) y `retry()`. Nunca devolver una
  lista vacía como si fuera un estado válido ante un error.
- Los agregados mensuales los calcula el trigger `onTransactionWritten`; el
  cliente no escribe `months/*`.

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
- `deleteAccount` (callable): auth + App Check, borra `users/{uid}` y todo su
  árbol y luego el usuario de Authentication, en ese orden. Lo exige la política
  de borrado de datos de Google Play. Por eso las reglas deniegan `delete` en
  `users/{uid}`.
- `onTransactionWritten`: recalcula `months/{monthKey}` (ambos meses si cambió
  `monthKey`) dentro de una transacción. Idempotente. `months/*` suma `amount`
  (bruto); `platformFee` no entra en los agregados.
- `waitlist` (HTTP): `POST {name, email, source}` → `200 {ok:true}` |
  `400/429 {error}`. Lo consume `landing/src/services/waitlist-service.ts`. El
  id del documento es el sha256 del correo normalizado: reenviar no duplica.
- Parámetros: `ENFORCE_APP_CHECK` (default `false`, aplica a los DOS callables),
  `OPENROUTER_MODEL`.
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
  único**: solo existe `lightTheme`, no hay `darkTheme` ni `themeMode`, y ningún
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
- Commits locales, atómicos y descriptivos. **Push solo tras** `flutter analyze`,
  `flutter test` y `npm --prefix functions test` en verde.
- Usar los tokens de `app_constants.dart`; seguir `data/domain/presentation`
  con Provider para features nuevas.
- Tests: unitarios de casos de uso en `test/features/<feature>/`, widget tests
  sin Firebase (fakes de repositorios, `MaterialApp` + `AppTheme`).
- Lints activos además de `flutter_lints`: `prefer_single_quotes`,
  `avoid_print`, `unawaited_futures`, `prefer_const_constructors`.
