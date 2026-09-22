# Plan de trabajo — Págate-IA

Derivado de [AUDITORIA-2026-09.md](AUDITORIA-2026-09.md). Fecha base 2026-09-21.

Convenciones: **DUEÑO** = necesita consola Firebase/GCP, keystore, secretos de GitHub o decisión de producto. **AGENTE** = lo hace un agente solo. Tamaño S/M/L relativo. Estados: `todo` / `doing` / `review` / `done` / `blocked-DUEÑO` / `blocked-<ID>`.

Principios: primero que la app real funcione y no gaste sin tope; todo cambio de contrato pasa antes por `ARQUITECTURA.md`; reglas y cliente se despliegan juntos; push solo con los bloques de verificación en verde (AGENTS.md).

## Bloques de verificación

```bash
flutter analyze && flutter test
npm --prefix functions run lint && npm --prefix functions run build && npm --prefix functions test
npm --prefix landing run lint && npm --prefix landing test && npm --prefix landing run build
```

---

## Fase 0 — Recuperar producción

Objetivo: login funciona en web y Android contra el proyecto real, el chat responde, el trigger recalcula meses, la landing pública guarda leads, el gasto tiene tope.

### Tareas DUEÑO

| ID | Tarea | Estado | Cómo |
| --- | --- | --- | --- |
| F0-01 | Config real de la app web en `lib/firebase_options.dart` | todo | `dart pub global activate flutterfire_cli && flutterfire configure --project=pagate-17211 --platforms=android,web`, o copiar `apiKey`/`appId` web desde Consola → Project settings → Your apps. Confirmar que la app Android registrada es `com.pagate.apppagate` |
| F0-04 | Blaze + alertas de presupuesto (USD 5 / 20); clave OpenRouter nueva con límite de gasto; revocar la antigua | todo | `npm --prefix functions exec -- firebase functions:secrets:set OPENROUTER_API_KEY`. **VERIFICAR** revocación de la clave compilada en builds viejos |
| F0-07 | Deploy manual | blocked-F0-01 | `APP_CHECK_SITE_KEY=... ./scripts/deploy-web.sh` tras los bloques de verificación. **VERIFICAR** ubicación de la base Firestore vs `southamerica-west1` |
| F0-08 | Smoke test en producción (checklist abajo) | blocked-F0-07 | |

### Tareas AGENTE

| ID | Tarea | Carril | Tam | Estado | Depende | Rama | Notas |
| --- | --- | --- | --- | --- | --- | --- | --- |
| F0-02 | `firebase_options.dart`: `currentPlatform` con `UnsupportedError` para plataformas sin config; valores web pendientes de F0-01 | C | S | todo | F0-01 | `lane/client-auth` | Sin inventar keys |
| F0-03 | `main.dart`: try/catch alrededor de `bootstrapFirebase()`, pantalla de error con reintento, widget test | C | S | todo | — | `lane/client-auth` | Reutilizar `session_error_view.dart` / `pagate_error_state.dart` |
| F0-05 | `maxInstances` (`chat` 5, `onTransactionWritten` 10, `waitlist` 2), `cors` restringido en `chat`, `functions/.env` (`ENFORCE_APP_CHECK=false`, `OPENROUTER_MODEL=deepseek/deepseek-v4-flash`) + `.env.example` | A | S | todo | — | `lane/backend` | `.gitignore` ya tiene `!functions/.env` |
| F0-06 | `landing/.env.production` con `VITE_WAITLIST_URL`, rebuild de `landing-page/`, workflow `landing-pages.yml` | E | M | todo | — | `lane/infra` | URL pública ya en `landing/.env.example` |

### Smoke test de producción (F0-08, reutilizable en cada deploy)

- [ ] Registro con email → onboarding → documento `users/{uid}` creado
- [ ] Google Sign-In en web
- [ ] Crear transacción → `users/{uid}/months/{yyyy-MM}` actualizado
- [ ] Chat responde y `meta/usage.chatCountDay` incrementa
- [ ] Formulario de la landing pública → documento en `waitlist/`
- [ ] APK debug instala y autentica

### Criterio de salida

- [ ] Los 6 puntos del smoke test pasan
- [ ] Alertas de presupuesto activas
- [ ] Clave antigua de OpenRouter revocada
- [ ] `landing-page/` contiene un build con la URL real de `waitlist`
- Commit desplegado: _pendiente_

---

## Fase 1 — Endurecimiento de seguridad

Contrato **C-1** (coordinador, en `ARQUITECTURA.md`, antes de paralelizar): `createdAt` inmutable y `updatedAt == request.time`; `list` con `limit <= 200` (los datasources añaden `.limit()`); topes numéricos (`amount`/`price`/`monthlyGoal` ≤ 1e12, `stock` ≤ 1e9); `monthKey` coherente con `date`; `hourlyRate` con `hasAll`; borrado de cuenta solo por callable `deleteAccount`; waitlist con id `sha256(email)` y `name` obligatorio en ambos lados.

### Tareas DUEÑO

| ID | Tarea | Estado |
| --- | --- | --- |
| S1-01 | Keystore de release + `android/key.properties` (ignorado) + secretos GitHub; añadir `*.jks`, `key.properties` a `.gitignore` | todo |
| S1-03 | App Check en consola (Play Integrity con SHA-256 release, reCAPTCHA v3 web), secreto `APP_CHECK_SITE_KEY`; restringir API keys por package+SHA / referrer | blocked-S1-01 |
| S1-13 | (Opcional) proyecto staging en `.firebaserc` | todo |

### Tareas AGENTE

| ID | Tarea | Carril | Tam | Estado | Depende |
| --- | --- | --- | --- | --- | --- |
| C-1 | Contrato en `ARQUITECTURA.md` | Coord | S | todo | — |
| S1-02 | `build.gradle.kts`: `signingConfigs.release` desde `key.properties`, `minSdk 23` | C | S | blocked-S1-01 | S1-01 |
| S1-04 | `ENFORCE_APP_CHECK=true` + `enforceAppCheck: true` en `onCall`; fallar build web prod sin site key | A + C | S | blocked-S1-03 | S1-03 |
| S1-05 | `waitlist.ts`: último salto de XFF (**VERIFICAR** formato), dedupe por email, localhost solo en emulador; tests | A | M | todo | C-1 |
| S1-06 | `firestore.rules` según C-1 + casos en `rules.test.ts`. No desplegar hasta que B/C tengan `.limit()` | A | M | todo | C-1 |
| S1-07 | Callable `deleteAccount` + cliente + botón en Configuración | A + C | M | todo | C-1 |
| S1-08 | `prompt.ts`: `sanitizeField()`, delimitadores, tope de tamaño; tests de inyección | A | S | todo | — |
| S1-09 | `firebase.json`: cache correcto y cabeceras de seguridad; CSP en Report-Only primero (**VERIFICAR**) | A | S | todo | — |
| S1-10 | `deploy-web.yml` con tests previos, auth keyless o limpieza `if: always()`, sin `--force`, `permissions`, SHAs, Flutter fijo; `deploy-web.sh` con verificación y `--project` | E | M | todo | — |
| S1-11 | README (package real, checklist), `dev.sh` con `--project demo-pagate` | E | S | todo | — |
| S1-12 | `dependabot.yml` + `npm audit` en CI | E | S | todo | — |

### Criterio de salida

- [ ] `curl` a `chat` con ID token válido pero sin App Check → rechazado
- [ ] `curl` repetido a `waitlist` con el mismo email no duplica
- [ ] `deploy-web.yml` falla si falla un test
- [ ] APK release firmado con keystore propio
- [ ] `curl -I https://pagate-17211.web.app` muestra las cabeceras
- [ ] Tras un deploy, recargar entrega el build nuevo

---

## Fase 2 — Corrección de bugs

Contrato **C-2** (coordinador): `lib/core/utils/currency_formatter.dart` (`formatCurrency(num, {required String currency})` con `intl`, CLP sin decimales, USD con 2) y `month_labels.dart`; `pubspec.yaml` sin `http`/`build_runner`/`json_serializable`; cuota en `America/Santiago`; `DetalleItemScreen(itemId)`.

| ID | Tarea | Carril | Tam | Estado |
| --- | --- | --- | --- | --- |
| C-2 | Contrato + utilidades compartidas + `pubspec.yaml` | Coord | S | todo |
| B2-01 | `months.ts` en transacción (**VERIFICAR** aggregate en transacción en `firebase-admin` 14), `retry: true`, borrar mes vacío; test | A | M | todo |
| B2-02 | `chat.ts`: cuota en zona Chile, cuota y `messageCount` coherentes en fallo, timeout + reintento, `res.json()` en try; tests | A | M | todo |
| B2-03 | Formateo de moneda y meses; negativos; `maxY`; `DetalleItemScreen` por id; parseo `1.234,56`; controllers; messenger; `IndexedStack`; `_MonthlyGoalSync`; búsqueda con controller | B | L | todo |
| B2-04 | `IdentityStepScreen` con tokens dark; quitar país y moneda; `totalSteps` real | C | S | todo |
| B2-05 | `HourlyRateModel.fromJson` null-safe; quitar `assert`; `createdAt` solo al crear | C | S | todo |
| B2-06 | Verificación de email | C | M | todo |
| B2-07 | Quitar "$830 extra"; FAQ; `signOut` con try/catch; `clearPersistence()`; ocultar stubs; Google en móvil (decisión) | C | M | todo |
| B2-08 | `AiProvider` dedupe por id; `ai_service.dart` sin `?conversationId`; no reintentar `resource-exhausted`; `_renderedCount` fuera de `build` | D | S | todo |
| B2-09 | `web/index.html` y `manifest.json` reales | C | S | todo |
| B2-10 | Landing honesta (DUEÑO decide copy), `WaitlistForm` con `name` requerido, borrar `vercel.json` | E | S | todo |
| B2-11 | Código muerto; conservar `updateTransaction`/`updateItem` (P4-01); decidir índice compuesto | B / C / A | S | todo |

Criterio de salida: `flutter analyze` limpio; un solo formateador de moneda; test de `recalcMonth` concurrente correcto; cuota reinicia a medianoche Chile; registro legible; `flutter build apk --release` con keystore propio.

---

## Fase 3 — Deuda técnica y tests

| ID | Tarea | Carril | Tam | Estado |
| --- | --- | --- | --- | --- |
| T3-01 | `functions/tsconfig` incluye `test`; eslint `recommendedTypeChecked` | A | S | todo |
| T3-02 | Tests de funciones puras; `chat.ts` con handler inyectable; `test:unit` sin archivo hardcodeado | A | M | todo |
| T3-03 | `rules.test.ts` completo | A | M | todo |
| T3-04 | Flutter: serialización de modelos, `AuthGate`/`UserScope`/`ProfileGate` con stream inyectado, `currency_formatter`, providers, `AiService`, `TransactionFormSheet` | QA | L | todo |
| T3-05 | Landing: `jsdom` por archivo, test de `WaitlistForm` | E | S | todo |
| T3-06 | `.githooks/pre-commit` + `core.hooksPath` en AGENTS.md; `.nvmrc` | E | S | todo |
| T3-07 | SDK a stable si Dart 3.12 ya está (**VERIFICAR**) | Coord | S | todo |
| T3-08 | `ARQUITECTURA.md` v1.1; README y AGENTS al día | Coord | S | todo |

Criterio de salida: cada archivo de `functions/src` tiene test; `AuthGate` con tests de sus 3 estados; CI hace typecheck de tests; Dependabot activo; hooks documentados.

---

## Fase 4 — Features de producto (solo tras Fase 3)

Cada feature: contrato en `ARQUITECTURA.md` → reglas + tests → datasource/modelo → UI → tests.

| ID | Feature | Tam | Estado | Nota |
| --- | --- | --- | --- | --- |
| P4-01 | UI de edición de transacciones e items | S | todo | Prerrequisito de importación |
| P4-02 | Importación bancaria Fase 1: CSV + callable `categorize` + confirmación. PDF después (Storage: DUEÑO) | L | todo | |
| P4-03 | CRM: `users/{uid}/clients/{id}` + `transactions.clientId?` | M | todo | |
| P4-04 | Calendario de proyectos: `users/{uid}/projects/{id}` | M | todo | |
| P4-05 | IA para presupuestos: callable `quote` | M | todo | |
| P4-06 | Reportes Excel | M | todo | |
| P4-07 | Google Sign-In móvil, Apple Sign-In (DUEÑO), notificaciones (DUEÑO) | M | todo | |
| P4-08 | Multi-usuario/equipos: contrato v2 (`workspaces/`) | L | todo | Último, diseño aparte |

---

## Agent teams

### Carriles y archivos exclusivos

| Carril | Archivos exclusivos | Verificación antes de integrar |
| --- | --- | --- |
| **A · Backend/reglas** | `functions/**`, `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `.firebaserc` | bloque functions |
| **B · Cliente finanzas/inventario/dashboard** | `lib/features/finances/**`, `lib/features/inventory/**`, `lib/core/services/pdf_report_service.dart`, `dashboard_screen.dart`, `tabs/home_tab.dart`, `widgets/financial_charts.dart`, `test/features/{finances,inventory}/**` | bloque flutter |
| **C · Cliente auth/perfil/onboarding/arranque/Android/web** | `lib/main.dart`, `lib/firebase_options.dart`, `lib/core/config/**`, `firebase_auth_service.dart`, `google_auth_service.dart`, `lib/features/{auth,onboarding,user_profile,hourly_value}/**`, `ayuda_screen.dart`, `configuracion_screen.dart`, `editar_perfil_screen.dart`, `android/**`, `web/**`, `test/features/{auth,hourly_value}/**`, `test/widget_test.dart` | bloque flutter |
| **D · IA cliente** | `ai_service.dart`, `ai_provider.dart`, `tabs/ia_tab.dart`, `test/features/dashboard/**` | bloque flutter |
| **E · CI/infra/landing/docs** | `.github/**`, `scripts/**`, `landing/**`, `landing-page/**`, `README.md`, `.gitignore`, `.githooks/**` | bloque landing |
| **QA · Tests transversales** (Fase 3) | `test/**` nuevos fuera de B/C/D; pide inyección al carril dueño, no edita `lib/` | bloque flutter |
| **Coordinador / revisor** | `docs/ARQUITECTURA.md`, `docs/PLAN.md`, `AGENTS.md`, `pubspec.yaml`, `lib/core/{constants,theme,utils,widgets}/**` | los 3 bloques sobre la rama de integración |

Regla: un carril que necesite tocar un archivo de otro abre una tarea aquí para el dueño; no lo edita. Los archivos compartidos los toca solo el coordinador, en commits pequeños al inicio de cada fase.

### Contratos que se fijan antes de paralelizar

1. **C-0** (Fase 0): valores reales de `firebase_options.dart` (DUEÑO).
2. **C-1** (Fase 1): reglas nuevas, `deleteAccount`, waitlist.
3. **C-2** (Fase 2): `currency_formatter`/`month_labels`, `pubspec.yaml`, `DetalleItemScreen`, zona horaria.
4. **C-3** (Fase 4, por feature): modelo + reglas + firma del callable antes de la UI.

### Orden de integración

```
Fase 0: F0-01(DUEÑO) → F0-02(C) ‖ F0-03(C) ‖ F0-05(A) ‖ F0-06(E) → F0-07(DUEÑO) → F0-08
Fase 1: C-1 → [A: S1-05,06,07b,08,09] ‖ [B,C: .limit() + S1-07c] ‖ [E: S1-10,11,12] ‖ [DUEÑO: S1-01,03]
        → integrar B/C, luego A (reglas) → deploy conjunto → S1-02 → S1-04
Fase 2: C-2 → A ‖ B ‖ C ‖ D ‖ E → integrar A, C, B, D, E → deploy
Fase 3: T3-01/02/03 (A) ‖ T3-04 (QA) ‖ T3-05/06 (E) → T3-07/08 (Coord)
Fase 4: una feature a la vez: A + carril cliente correspondiente
```

### Worktrees

Uno por carril, rama `lane/<carril>`, sub-ramas `lane/<carril>/<ID>` por tarea:

```bash
git worktree add ../pagate-wt-backend  -b lane/backend
git worktree add ../pagate-wt-finanzas -b lane/client-finanzas
git worktree add ../pagate-wt-auth     -b lane/client-auth
git worktree add ../pagate-wt-ia       -b lane/client-ia
git worktree add ../pagate-wt-infra    -b lane/infra
```

Cada worktree necesita su `flutter pub get` y `npm ci`. El emulador de Firestore usa el puerto 8080 fijo: solo el carril A (y QA) corre `npm --prefix functions test`, y el coordinador lo ejecuta al integrar. `landing-page/` lo genera solo el workflow (o E en Fase 0).

### Rol del coordinador

Escribe los contratos C-x antes de abrir cada fase; mantiene este archivo; revisa cada PR (alcance dentro del carril, contrato respetado, tests por cada regla o función tocada, sin secretos, sin `landing-page/` a mano); integra con `git rebase` en el orden indicado; corre los bloques; es el único que ejecuta o pide al DUEÑO el deploy y lo anota aquí.

### Commits y PR

Commits en español con el ID al inicio (`[S1-06] rules: createdAt inmutable`), atómicos, un carril por commit; push solo tras verificación en verde; PR por tarea con ID, contrato afectado, comandos ejecutados y tareas DUEÑO que desbloquea. Terminar commits con `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.

### Lista consolidada de VERIFICAR

Rotación de la clave antigua de OpenRouter (F0-04) · ubicación de la base Firestore vs `southamerica-west1` (F0-07) · formato de `X-Forwarded-For` en Functions 2ª gen (S1-05) · CSP mínima que no rompe Flutter web ni reCAPTCHA (S1-09) · aggregate queries dentro de transacción en `firebase-admin` 14 (B2-01) · Dart 3.12 en stable (T3-07) · Storage habilitado para PDF (P4-02). Resuelto: el slug `deepseek/deepseek-v4-flash` existe; `functions/.env` no queda ignorado.
