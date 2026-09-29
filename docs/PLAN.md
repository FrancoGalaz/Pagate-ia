# Plan de trabajo — Págate-IA

Objetivo: **publicar en Google Play**. Derivado de [AUDITORIA-2026-09-29.md](AUDITORIA-2026-09-29.md)
y del sistema visual [DISENO-v2.md](DISENO-v2.md). Fecha base 2026-09-29.

Convenciones: **DUEÑO** = solo Franco puede hacerlo (consola Firebase/GCP, keystore, Play Console,
decisión de producto). **AGENTE** = lo hace un agente. Tamaño S/M/L relativo.
Estados: `todo` / `doing` / `review` / `done` / `blocked-<ID>`.

Decisiones de producto tomadas el 2026-09-29: dirección visual **fintech sobria y densa**,
**tema claro único**, rediseño a fondo de bienvenida, registro, onboarding, inicio y finanzas,
limpieza del resto, y los cuatro frentes de Play (build, privacidad, ficha, políticas).

## Bloques de verificación

```bash
flutter analyze && flutter test
npm --prefix functions run lint && npm --prefix functions run build && npm --prefix functions test
npm --prefix landing run lint && npm --prefix landing test && npm --prefix landing run build
```

Flutter vive en `C:\Users\Franco\flutter\bin` y no está en el PATH.

---

## Fase 0 — Encender el proyecto (bloquea absolutamente todo)

Hoy la app no funciona para nadie: Authentication nunca se inicializó, la API de Firestore está
deshabilitada, no hay funciones desplegadas y Hosting no existe. Nada de esto es código.

### Tareas DUEÑO

| ID | Tarea | Estado | Cómo |
| --- | --- | --- | --- |
| F0-A | Inicializar **Authentication** y habilitar el proveedor Correo/Contraseña, y Google si se quiere | todo | Consola → Authentication → Comenzar. Verificar con la app: el registro debe pasar |
| F0-B | Habilitar la **API de Cloud Firestore** y crear la base | todo | Consola → Firestore Database → Crear. **Elegir la ubicación con cuidado**: debe ser compatible con `southamerica-west1`, que es la región del trigger. No se puede cambiar después |
| F0-C | Registrar la **app web** y pegar `apiKey` y `appId` en `lib/firebase_options.dart` | todo | `flutterfire configure --project=pagate-17211 --platforms=android,web` |
| F0-D | Plan **Blaze** + alertas de presupuesto (USD 5 y 20). Las funciones de 2ª generación lo exigen | todo | Consola → Uso y facturación; alertas en Google Cloud → Billing → Budgets |
| F0-E | Clave nueva de **OpenRouter** con límite de gasto, guardarla como secreto, y **revocar la antigua** | todo | `npm --prefix functions exec -- firebase functions:secrets:set OPENROUTER_API_KEY` |
| F0-F | Instalar **Android SDK Command-line Tools** | todo | Android Studio → SDK Manager → SDK Tools → marcar "Android SDK Command-line Tools (latest)". Sin esto `flutter build appbundle` falla |
| F0-G | Desplegar reglas, funciones y hosting | blocked-F0-B | `./scripts/deploy-web.sh` tras los bloques de verificación |

### Criterio de salida

- [ ] Registro y sesión funcionan en el APK de depuración contra producción
- [ ] Crear una transacción escribe `users/{uid}/months/{yyyy-MM}`
- [ ] El chat responde y descuenta cuota en `meta/usage`
- [ ] `flutter build appbundle --release` termina sin error
- [ ] Alertas de presupuesto activas y clave antigua revocada

---

## Fase R — Rediseño visual

Los diez pasos están detallados en [DISENO-v2.md](DISENO-v2.md), sección "Plan de migración".
El orden no es negociable: el paso 3 es el que permite cambiar toda la app a tema claro sin un
commit gigante imposible de revisar.

| ID | Paso | Carril | Tam | Estado |
| --- | --- | --- | --- | --- |
| R-0 | Formateador de moneda y nombres de meses (`currency_formatter.dart`, `month_labels.dart`); sustituir las 6 implementaciones | Coord | M | todo |
| R-1 | Tokens nuevos **en paralelo** a los viejos, sin borrar nada | Coord | S | todo |
| R-2 | Tipografía real: `app_text.dart` con `fontVariations` y `leadingDistribution`, escala nueva | Coord | M | todo |
| R-3 | **El interruptor**: tokens oscuros como alias `@Deprecated`, sombras vacías, degradados planos, `ThemeMode.light` | Coord | M | todo |
| R-4 | `lightTheme` reescrito completo | Coord | M | todo |
| R-5 | Componentes base nuevos (3 commits: básicos, de datos, de navegación) | Coord | L | todo |
| R-6 | Las cinco pantallas, una por commit: bienvenida, registro, onboarding, inicio, finanzas | B + C | L | todo |
| R-7 | Barrido del resto de pantallas sin rediseñar | B + C | M | todo |
| R-8 | Accesibilidad y localización (`flutter_localizations`, `SafeArea`, semántica, áreas táctiles, licencia OFL) | C | M | todo |
| R-9 | Borrar los alias: `flutter analyze` falla en cualquier resto sin migrar | Coord | S | todo |
| R-10 | Verificación en Android físico a 100%, 130% y 200% de tamaño de letra, y con TalkBack | QA | M | todo |

**Causa raíz del aspecto blando**, que R-2 arregla: `pubspec.yaml` declara Manrope como fuente
variable sin `fontVariations`, y el peso por defecto del archivo es ExtraLight (200). Todos los
`fontWeight: w600/w700` del tema nunca han seleccionado un peso real.

---

## Fase P — Google Play

### Técnico

| ID | Tarea | Quién | Tam | Estado |
| --- | --- | --- | --- | --- |
| P-01 | Keystore de release, `android/key.properties`, `signingConfigs.release` en gradle, entradas en `.gitignore` | DUEÑO + AGENTE | M | todo |
| P-02 | Icono propio: adaptativo (`mipmap-anydpi-v26`) más las cinco densidades, y el icono de la ficha a 512×512 | AGENTE | M | todo |
| P-03 | Quitar los permisos de mensajería push que no se usan, con `tools:node="remove"` | AGENTE | S | todo |
| P-04 | Activar R8 y `shrinkResources` con las reglas proguard de Firebase, `pdf` y `printing` | AGENTE | M | todo |
| P-05 | Configuración de seguridad de red que permita texto claro **solo en depuración** | AGENTE | S | todo |
| P-06 | Commitear el cambio de `minSdk` que está sin commitear | AGENTE | S | todo |

### Legal y datos

| ID | Tarea | Quién | Tam | Estado |
| --- | --- | --- | --- | --- |
| P-07 | **Borrado de cuenta**: callable `deleteAccount` con borrado recursivo, botón en Configuración, y página web pública de solicitud. Play lo exige en los dos formatos | AGENTE | L | todo |
| P-08 | Política de privacidad publicada en una URL, enlazada desde la app y desde la ficha | AGENTE | M | todo |
| P-09 | Respuestas del formulario de Seguridad de Datos, con el inventario real de lo que se recoge y lo que viaja a OpenRouter | AGENTE | M | todo |
| P-10 | Términos de servicio, y que "Ver términos" deje de ser un callejón sin salida | AGENTE | M | todo |
| P-11 | Quitar toda cifra y testimonio inventado de la app y de la landing | AGENTE | M | todo |
| P-12 | Requisitos de IA generativa: aviso de contenido generado y mecanismo de reporte en el chat | AGENTE | M | todo |

### Ficha de tienda

| ID | Tarea | Quién | Tam | Estado |
| --- | --- | --- | --- | --- |
| P-13 | Título, descripción corta y larga en español | AGENTE | S | todo |
| P-14 | Capturas de las pantallas rediseñadas y gráfico destacado | AGENTE | M | blocked-R-6 |
| P-15 | Cuenta de demostración con datos cargados para el revisor | DUEÑO | S | blocked-F0-A |

---

## Fase S — Seguridad y backend

Hereda lo que quedó abierto de la auditoría anterior. Detalle en
[AUDITORIA-2026-09-29.md](AUDITORIA-2026-09-29.md), dimensiones *backend* y *play-politicas*.

| ID | Tarea | Tam | Estado |
| --- | --- | --- | --- |
| S-01 | Exigir App Check: `ENFORCE_APP_CHECK=true` y `enforceAppCheck: true` en el callable | S | blocked-F0-D |
| S-02 | Reglas: `createdAt` inmutable, `updatedAt == request.time`, topes numéricos, `list` con límite | M | todo |
| S-03 | `recalcMonth` en transacción, con reintento y borrado de meses vacíos | M | todo |
| S-04 | `waitlist`: IP del último salto, deduplicación por correo, localhost solo en emulador | M | todo |
| S-05 | `prompt.ts`: sanear los campos del usuario contra inyección de instrucciones | S | todo |
| S-06 | Cuota del chat en zona horaria de Chile, y devolverla si OpenRouter falla | M | todo |
| S-07 | Cabeceras de seguridad y caché correcta en `firebase.json` | S | todo |
| S-08 | Quitar `localhost` de la lista de orígenes de `chat` en producción | S | todo |

---

## Fase Q — Calidad

| ID | Tarea | Tam | Estado |
| --- | --- | --- | --- |
| Q-01 | Tests de las funciones sin cobertura: `recalcMonth`, `validateWaitlistBody`, `isRateLimited`, `dayKeyOf`, `parseInput` | M | todo |
| Q-02 | Tests de reglas: `createdAt` inmutable, borrado de `users/{uid}`, límites de consulta | M | todo |
| Q-03 | Test de regresión de desbordamiento: las cinco pantallas a 1,3x y 2,0x | M | blocked-R-6 |
| Q-04 | Tests de serialización de los cinco modelos | S | todo |
| Q-05 | CI que compile Android, que hoy no lo hace pese a ser el objetivo | S | todo |
| Q-06 | `deploy-web.yml` con tests previos y credenciales sin fichero en disco | M | todo |

---

## Agent teams

Carriles y propiedad de archivos, sin cambios respecto al acuerdo anterior:

| Carril | Archivos exclusivos |
| --- | --- |
| **Coordinador** | `docs/**`, `AGENTS.md`, `pubspec.yaml`, `lib/core/{constants,theme,utils,widgets}/**` |
| **A · Backend** | `functions/**`, `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `.firebaserc` |
| **B · Cliente finanzas/inventario** | `lib/features/{finances,inventory}/**`, `dashboard_screen.dart`, `tabs/home_tab.dart`, `widgets/financial_charts.dart`, `lib/core/services/pdf_report_service.dart` |
| **C · Cliente auth/perfil/Android** | `lib/main.dart`, `lib/firebase_options.dart`, `lib/core/config/**`, `lib/features/{auth,onboarding,user_profile,hourly_value}/**`, `ayuda_screen.dart`, `configuracion_screen.dart`, `editar_perfil_screen.dart`, `android/**`, `web/**` |
| **D · IA cliente** | `ai_service.dart`, `ai_provider.dart`, `tabs/ia_tab.dart` |
| **E · Infra/landing** | `.github/**`, `scripts/**`, `landing/**`, `landing-page/**`, `README.md`, `.gitignore` |

Regla durante la Fase R: **nadie toca `app_constants.dart`, `app_theme.dart` ni `core/widgets/`
fuera de los pasos R-0 a R-5**, que son del Coordinador. Si un carril necesita un token que no
existe, abre tarea aquí en vez de añadirlo.

Worktrees ya creados: `../pagate-wt-backend` (lane/backend), `../pagate-wt-auth` (lane/client-auth),
`../pagate-wt-infra` (lane/infra). El emulador de Firestore usa el puerto 8080 fijo, así que solo un
carril corre `npm --prefix functions test` a la vez.

Commits en español con el identificador delante, por ejemplo `[R-3] tema: interruptor a claro único`.
**Sin push**: Franco revisa antes de que nada salga al remoto.

---

## Documentación que hay que corregir

Estas tres apuntan en dirección contraria a lo decidido y se arreglan dentro de la Fase R:

- `AGENTS.md` describe `lightTheme`/`darkTheme` como el contrato de theming, y un `BottomNavigationBar` que la app no usa.
- `README.md` enlaza `pagate-17211.web.app` como "App web", y hoy responde 404.
- La tabla de propiedad de archivos de `docs/ARQUITECTURA.md` quedó obsoleta tras la integración.
