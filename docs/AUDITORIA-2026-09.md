# Auditoría técnica — Págate-IA (2026-09-21)

Resultado de una revisión de solo lectura del repo en la rama `arquitectura-segura` (HEAD `0867f46`). Cada hallazgo tiene archivo:línea. Lo marcado **VERIFICAR** requiere acceso del dueño (consola Firebase/GCP) o prueba en dispositivo real. El plan de ejecución derivado de esta auditoría está en [PLAN.md](PLAN.md).

## 1. Estado actual

### Lo que está en verde (ejecutado localmente)

| Verificación | Resultado |
| --- | --- |
| `flutter analyze` (Flutter 3.42.0-0.0.pre beta, Dart 3.12.0-113.1.beta) | 0 issues |
| `flutter test` | 10/10 |
| `functions`: `tsc --noEmit`, `eslint src test` | limpio |
| `functions`: `vitest test/prompt.test.ts` | 6/6 |
| `functions`: `test/rules.test.ts` contra emulador Firestore | 25/25 |
| `landing`: eslint, `tsc -b`, `vitest` | limpio, 6/6 |

Entorno local: Flutter no está en PATH (vive en `C:\Users\Franco\flutter\bin`). Node local es 25 (functions pide 22), Java 25 (docs piden 21). Funcionan pero divergen de producción.

### Veredicto: el repo está verde, pero la app NO es funcional contra Firebase real

Tres bloqueos independientes:

1. **API key de Firebase redactada en el código.** `lib/firebase_options.dart:13` y `:29` tienen literalmente `'AIzaSy...r-vA'` (la key real se comprometió en `8b4bb15` el 2026-05-11 y se reemplazó por ese placeholder en `d519534` el 2026-05-13). El `appId` web es `1:390581596119:web:xxxxxxxxxxxx`. Como `lib/core/config/firebase_bootstrap.dart:17` pasa estas opciones explícitamente, ni Android ni web pueden autenticar contra el proyecto real. Solo funciona contra emuladores (`PAGATE_ENV=dev`). La key real sigue en `android/app/google-services.json` y en el historial de git.
2. **Arranque sin red de seguridad.** `lib/main.dart:10` hace `await bootstrapFirebase()` sin `try/catch`: si `initializeApp` falla, `runApp` nunca corre y el usuario ve pantalla negra.
3. **Backend sin configuración de producción.** No existe `functions/.env`, así que `ENFORCE_APP_CHECK` queda en `false` (`functions/src/config.ts:16-19`, `functions/src/chat.ts:148`). El modelo por defecto `deepseek/deepseek-v4-flash` sí existe en OpenRouter (verificado contra `api/v1/models/.../endpoints`).

Además, **la landing pública no capta leads**: `landing-page/` (GitHub Pages) es un build de mayo 2026 cuyo handler guarda el formulario en `localStorage` y hace `console.log` del email. El código en `landing/` ya llama al endpoint `waitlist`, pero nadie lo reconstruyó ni hay workflow que lo publique.

### Lo que está bien y no hay que tocar

- Arquitectura de sesión: providers keyed por uid bajo `AuthGate` → `UserScope` → `AppShell`, `MaterialApp` recreado por `sessionKey`, todos los providers cancelan streams en `dispose`. Sin fuga de datos entre sesiones en memoria.
- Disciplina de datos: todas las lecturas de UI son `snapshots()`; los 5 providers exponen `error` + `retry()`; el cliente nunca escribe `months`, `conversations`, `meta` ni `plan`; los `toFirestore()` coinciden campo a campo con `firestore.rules`.
- Chat: cero rastro de OpenRouter o claves en `lib/`; región `southamerica-west1` consistente; `conversationId` validado con regex y siempre bajo `users/{uid}` (sin IDOR).
- Reglas: deny-by-default, `hasOnly`/`hasAll`, `plan` no escalable free→pro por ningún camino, waitlist inaccesible desde cliente.
- Cuota diaria del chat atómica (`runTransaction`).
- Higiene: ningún `.env`, `.secret.local`, `.mcp.json` ni log rastreado; el `.mcp.json` histórico no contenía tokens.

## 2. Hallazgos priorizados

Severidad: **C** crítico (bloquea producción o expone dinero/datos), **A** alto, **M** medio, **B** bajo.

### 2.1 Producción / configuración

| Sev | Dónde | Problema | Corrección |
| --- | --- | --- | --- |
| C | `lib/firebase_options.dart` | Keys redactadas, appId web placeholder, sin iOS, `currentPlatform` devuelve android para todo lo no-web | Regenerar con `flutterfire configure` (dueño). Restringir las keys en GCP por package+SHA / referrer |
| C | `lib/main.dart:10` | Init sin try/catch → pantalla negra | try/catch y `runApp` de una pantalla de error con reintento |
| C | `functions/.env` ausente; `.github/workflows/deploy-web.yml:58-67` | App Check no se exige en prod; cualquier cuenta autoregistrada llama `chat` desde curl y consume OpenRouter | `functions/.env` con `ENFORCE_APP_CHECK=true` + `enforceAppCheck: true` en `onCall`. Requiere App Check en consola (dueño) |
| A | `functions/src/chat.ts:136-142`, `functions/src/months.ts:44-49` | Sin `maxInstances`, sin `cors` restringido, sin tope de gasto | `maxInstances`, `cors: [dominios]`, log de `usage`, alertas de presupuesto (dueño) |
| A | `android/app/build.gradle.kts:36-38` | Release firmado con keystore debug; `minSdk 21` | Keystore de release + `key.properties` (dueño); `minSdk 23` |
| A | `README.md:87` | Rotación de la key antigua de OpenRouter sigue pendiente | **VERIFICAR** revocación (dueño) |
| A | `firebase.json:25-32` | `Cache-Control` 1 año en `**/*.js` sin hash (`main.dart.js`, `flutter_bootstrap.js`) | Cache largo solo en `assets/**` y `canvaskit/**`; `no-cache` en bootstrap/`index.html` |
| M | `firebase.json:15-33` | Sin CSP, HSTS, X-Frame-Options, nosniff, Referrer-Policy | Bloque de headers `**` |
| M | `.firebaserc`, `scripts/dev.sh` | Sin staging; `dev.sh` usa el project id real con el secreto real | `--project demo-pagate` en dev.sh |
| M | `firebase-debug.log:108` | Node 25 local vs `engines.node 22` | `.nvmrc` |

### 2.2 CI/CD

| Sev | Dónde | Problema | Corrección |
| --- | --- | --- | --- |
| A | `deploy-web.yml`, `scripts/deploy-web.sh` | Despliegan reglas+functions+hosting sin correr ningún test; el script no pasa `--project` ni comprueba rama | Job de tests con `needs:`; verificación en el script; `--project pagate-17211` |
| A | `deploy-web.yml:59-67` | JSON de service account escrito con `echo`, `rm -f` no corre si falla el deploy, `--force` borra functions no exportadas | Workload Identity Federation o limpieza `if: always()`; quitar `--force` |
| M | ambos workflows | Actions sin pin a SHA, sin `permissions:`, Flutter beta sin versión | Pinear, `permissions: contents: read`, versión fija |
| M | `deploy-web.yml:37-39`, `firebase_bootstrap.dart:64-69` | Sin `APP_CHECK_SITE_KEY` el build prod sale con App Check apagado y solo un `debugPrint` | Fallar build prod web sin site key |
| M | `functions/tsconfig.json:17`, `functions/eslint.config.mjs` | Tests sin typecheck; eslint no type-aware; sin `npm audit`/Dependabot | `tsconfig.test.json`, `recommendedTypeChecked`, Dependabot |
| M | ninguno | No hay workflow que construya y publique `landing-page/` | Workflow `landing-pages.yml` |
| B | `ci.yml:5` | Dispara en `arquitectura-segura` | Limpiar tras merge |

### 2.3 Backend (Functions)

| Sev | Dónde | Problema | Corrección |
| --- | --- | --- | --- |
| A | `functions/src/waitlist.ts:44-51` | Primer valor de `X-Forwarded-For` (controlado por el cliente) → rate limit anulable; limitador en memoria por instancia; sin App Check/CAPTCHA; `.add()` sin dedupe; `localhost:5173` en allowlist de prod | Último salto de XFF; id `sha256(email)` con `set(merge)`; App Check o Turnstile; localhost solo en emulador |
| A | `functions/src/months.ts:27-36` | Read-then-write fuera de transacción (last-writer-wins), sin `retry: true` → `months/*` puede quedar mal para siempre | `runTransaction` o `FieldValue.increment`; `retry: true`; `maxInstances`; reconciliación programada |
| A | `functions/src/prompt.ts:82-84`, `:127-129` | Campos del perfil y transacciones interpolados sin escapar en el system prompt → prompt injection | `sanitizeField()`; delimitadores; tests de inyección |
| M | `functions/src/chat.ts:42-44` | Cuota diaria en UTC (Chile UTC-3/-4) | Zona `America/Santiago` |
| M | `functions/src/chat.ts:246-258` | Cuota no se devuelve si OpenRouter falla; `messageCount` desfasado; sin retry/backoff; sin tope de tamaño del prompt | Ajustar batches; 1 reintento; recortar historial |
| M | `functions/src/months.ts:31`, `functions/src/chat.ts:210` | Meses vaciados no se borran y el chat elige "último mes" por id | Borrar doc si `transactionCount == 0` |
| M | `functions/src/months.ts:47` | Región del trigger debe ser compatible con la ubicación de la base | **VERIFICAR** |
| B | `functions/src/openrouter.ts:77` | `res.json()` fuera del try; sin test | Mover al try; tests con `fetch` stub |

### 2.4 Reglas de Firestore

| Sev | Dónde | Problema | Corrección |
| --- | --- | --- | --- |
| A | `firestore.rules:53-55`, `:97` | `createdAt` mutable en update; `updatedAt` no atado a `request.time`. El cliente lo explota: `user_profile_firebase_datasource.dart:15-46` reescribe `createdAt` si guarda antes del primer snapshot | Inmutabilidad + `request.time`; cliente solo escribe `createdAt` al crear |
| A | `firestore.rules:98` | `delete` de `users/{uid}` deja huérfanas las subcolecciones | Denegar delete; callable `deleteAccount` con `recursiveDelete` |
| M | todas las `allow read` | Sin `request.query.limit` | `list` con `limit <= 200` |
| M | `firestore.rules:37-43` | Sin tope superior numérico → `Infinity` en agregados | `<= 1e12` |
| M | `firestore.rules:137-139` | `monthKey` no validado contra `date` | Derivar en trigger o validar |
| B | `firestore.rules:59-65` | `validHourlyRate` acepta `{}` y parciales | `hasAll` |
| B | `firestore.rules:17-19` | `isOwner` no excluye anónimos | Condición por `sign_in_provider` |
| B | `functions/test/rules.test.ts` | No cubre createdAt inmutable, delete de `users/{uid}`, `limit`, delete backend-only, longitudes, `collectionGroup`, `stock: 1.5`, hourlyRate negativos | Añadir casos con cada cambio |

### 2.5 Cliente Flutter

| Sev | Dónde | Problema | Corrección |
| --- | --- | --- | --- |
| A | `finanzas_tab.dart:15-24`, `home_tab.dart:243`, `financial_charts.dart:499`, `pdf_report_service.dart:22`, `inventario_tab.dart:435` | Moneda: 5 implementaciones, `$` y `.` hardcodeados, `profile.currency` ignorado, negativos como `$-5000`, `intl` sin usar | `lib/core/utils/currency_formatter.dart` con `NumberFormat.currency` |
| A | `detalle_item_screen.dart:11-13` | Recibe `item` inmutable; tras `updateStock` muestra el valor viejo | Recibir `itemId` y `watch` |
| A | `identity_step_screen.dart:81`, `app_shell.dart:28` | Pantalla clara bajo `ThemeMode.dark` forzado; país sin `onTap`; `_selectedCurrency` nunca se persiste; "paso 1 de 3" sin pasos 2 y 3 | Reescribir con tokens dark; quitar país/moneda |
| A | `hourly_rate_model.dart:12-14` | `as num` sin null-check dentro del `map()` de un stream | Null-safe + test |
| A | `firebase_auth_service.dart` | Sin verificación de email | `sendEmailVerification` + aviso |
| M | `ayuda_screen.dart:99-108` | "ganar $830 extra" inventado presentado como IA | Quitar o conectar a datos reales |
| M | `ai_provider.dart:164-169` | Dedupe de optimistas por `role+text` | Por id/timestamp |
| M | `ai_service.dart:58` | `?conversationId` ata el proyecto al SDK beta | `if (conversationId != null)` |
| M | `firebase_bootstrap.dart`, `signOut` | Persistencia offline nunca se limpia al cerrar sesión | `terminate()` + `clearPersistence()` |
| M | `transaction_form_sheet.dart:117-122` | `1.234,56` no parsea | Normalizar separadores |
| M | `finanzas_tab.dart:395-442`, `transaction_form_sheet.dart:144-150`, `dashboard_screen.dart:252-262` | Controllers dispuestos en animación; `showMessage` con context popeado; `_MonthlyGoalSync` sobre provider dispuesto | StatefulWidget; capturar messenger; flag disposed |
| M | `dashboard_screen.dart:105-113` | `IndexedStack` vs `_pages[i]` según ancho → pierde estado al cruzar 720px | `IndexedStack` en ambos |
| M | `google_auth_service.dart:20` | Google Sign-In solo web; Apple stub | Añadir `google_sign_in` o documentar; ocultar Apple |
| M | `inventory_provider.dart:58-63` | Búsqueda sin controller | `TextEditingController` |
| B | `pubspec.yaml` | `http`, `build_runner`, `json_serializable`, `cupertino_icons` sin uso | Quitar; conservar `intl` |
| B | varios | Código muerto (`getProfile`, `PagateInfoCard`, `selectMonth`, `firstDay`, `isGoogleUser`, `clearSaveError`), tokens sin uso, ~50 magic numbers, `_pieColors` duplicando tokens, índice compuesto sin uso, FAQ desactualizada, stubs "próximamente", versión hardcodeada, PDF con fuente por red | Limpieza incremental |

### 2.6 Landing y producto

| Sev | Dónde | Problema | Corrección |
| --- | --- | --- | --- |
| A | `landing-page/` | Build de mayo: leads a `localStorage` + `console.log(email)` | Reconstruir con `VITE_WAITLIST_URL` y publicar por workflow |
| M | `WaitlistForm.tsx:13` vs `waitlist.ts:65` | Nombre opcional en cliente, obligatorio en servidor | `required` en el form |
| M | `Stats.tsx:8-11`, `Testimonials.tsx:10-27`, `Roadmap.tsx` | Métricas y testimonios inventados; "Roadmap 2025"; CRM y multi-usuario al "60%" sin código | Decisión de producto |
| B | `landing/vite.config.ts:12` | `environment: 'node'` impide tests de componentes | `jsdom` + test de `WaitlistForm` |
| B | `web/index.html` | Título/description de plantilla Flutter | Metadatos reales |
| B | `README.md:90` | Dice `com.example.pagate_ia`; el id real es `com.pagate.apppagate` | Corregir |

### 2.7 Cobertura de tests (huecos)

- Functions: 0 tests de `chat.ts`, `months.ts`, `waitlist.ts`, `openrouter.ts` aunque exportan funciones puras. `test:unit` hardcodeado a un archivo.
- Flutter: 0 tests de `AuthGate`/`UserScope`/`ProfileGate`, de serialización de modelos, de `AiService`/`AiProvider`, de formularios.
- Rules: ver 2.4.
