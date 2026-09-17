# Arquitectura Págate-IA (contrato v1)

Este documento es la fuente de verdad para el modelo de datos, la API del backend
y las convenciones del cliente. Cualquier cambio aquí debe reflejarse en
`firestore.rules`, `functions/` y los datasources de `lib/`.

## Principios

1. **Ningún secreto viaja en el cliente.** La clave de OpenRouter vive en Secret
   Manager y solo la usa Cloud Functions.
2. **Todo dato de usuario cuelga de `users/{uid}`.** Una sola regla de propiedad
   cubre el árbol completo. No hay colecciones globales filtradas por `userId`.
3. **Los agregados se derivan, no se escriben desde el cliente.** Los totales
   mensuales los calcula un trigger de Firestore.
4. **El cliente lee con streams** (`snapshots()`), no con `get()` puntuales.
   Firestore entrega tiempo real y offline sin código extra.
5. **Los errores no se silencian.** Un fallo de red o de permisos se muestra con
   opción de reintentar. Nunca se devuelve una lista vacía como si fuera un
   estado válido.

## Modelo de datos (Firestore)

Fechas siempre como `Timestamp`. Ids de documento generados por Firestore, no
duplicados en un campo `id`.

```
users/{uid}                              perfil + configuración (owner: read/write)
  name: string
  businessName: string
  businessType: string
  currency: 'CLP' | 'USD'     ('CLP' por defecto)
  monthlyGoal: number
  avatarInitials: string
  plan: 'free' | 'pro'        (solo lo escribe el backend; el cliente lo lee)
  hourlyRate: {               (map opcional)
    desiredMonthlySalary: number
    availableHoursPerMonth: number
    hourlyValue: number
  }
  createdAt, updatedAt: Timestamp

users/{uid}/inventory/{itemId}           (owner: read/write)
  name: string
  type: 'product' | 'material'
  price: number (>= 0)
  stock: number (int >= 0)
  minStock: number (int >= 0)
  unit: string
  supplier: string | null
  code: string | null
  createdAt, updatedAt: Timestamp

users/{uid}/transactions/{txId}          (owner: read/write)
  title: string
  description: string
  amount: number (> 0)
  type: 'income' | 'expense'
  category: string
  date: Timestamp
  monthKey: string 'yyyy-MM'  (derivado de date en el cliente; validado por regex)
  createdAt, updatedAt: Timestamp

users/{uid}/fixedExpenses/{id}           (owner: read/write) gastos fijos recurrentes
  name: string
  amount: number (> 0)
  createdAt, updatedAt: Timestamp

users/{uid}/months/{yyyy-MM}             (owner: read; write SOLO backend)
  totalIncome: number
  totalExpenses: number
  transactionCount: number
  updatedAt: Timestamp

users/{uid}/conversations/{convId}       (owner: read; write SOLO backend)
  title: string
  createdAt, updatedAt: Timestamp
  messageCount: number
users/{uid}/conversations/{convId}/messages/{msgId}   (owner: read; write SOLO backend)
  role: 'user' | 'assistant'
  text: string
  createdAt: Timestamp

users/{uid}/meta/usage                   (owner: read; write SOLO backend)
  dayKey: string 'yyyy-MM-dd'
  chatCountDay: number

waitlist/{id}                            (sin acceso desde cliente; solo backend)
  name, email, source: string
  createdAt: Timestamp
```

Validaciones en reglas: `hasOnly` de campos permitidos, tipos, rangos,
strings de máximo 200 caracteres (2000 para `description`), `monthKey` con
regex `^\d{4}-\d{2}$`.

## Backend (Cloud Functions 2ª gen, TypeScript, Node 22, región `southamerica-west1`)

### `chat` (callable)

```
request:  { conversationId?: string, message: string }
response: { conversationId: string, reply: string }
errores:  unauthenticated | invalid-argument | resource-exhausted | internal
```

Flujo:
1. Verifica `request.auth`. App Check se exige cuando el parámetro
   `ENFORCE_APP_CHECK` es `true` (por defecto `false` hasta activarlo en consola).
2. Lee `users/{uid}/meta/usage`; cuota diaria: `free` 30 mensajes, `pro` 300.
   Si se excede → `resource-exhausted`.
3. Si no hay `conversationId`, crea la conversación.
4. Guarda el mensaje del usuario en `messages`.
5. Arma el system prompt del lado servidor con: perfil, `hourlyRate`, último
   `months/*`, últimas 10 transacciones, conteo de inventario, y los últimos 20
   mensajes de la conversación.
6. Llama a OpenRouter con `OPENROUTER_API_KEY` (secreto) y modelo
   `OPENROUTER_MODEL` (parámetro, default `deepseek/deepseek-v4-flash`).
7. Guarda la respuesta en `messages`, actualiza `messageCount`, `updatedAt` y
   la cuota en `meta/usage`.
8. Devuelve `{ conversationId, reply }`.

### `onTransactionWritten` (trigger Firestore)

Al crear, editar o borrar `users/{uid}/transactions/{txId}`, recalcula
`users/{uid}/months/{monthKey}` con una consulta agregada
(`sum`/`count`) sobre las transacciones de ese `monthKey`. Si cambió el
`monthKey` entre before/after, recalcula ambos meses. Idempotente.

### `waitlist` (HTTP, CORS abierto solo a los dominios de la landing)

```
POST { name: string, email: string, source?: string }
200 { ok: true } | 400 { error } | 429 { error }
```

Valida email, largo de campos, límite simple por IP en memoria, y escribe en
`waitlist/{id}`.

## Cliente Flutter

- **Entorno:** `--dart-define=PAGATE_ENV=dev|prod` (default `prod`). En `dev`
  el cliente se conecta a los emuladores (Auth 9099, Firestore 8080,
  Functions 5001) en `localhost` (`10.0.2.2` en emulador Android).
- **App Check:** en modo debug usa los proveedores debug; en release usa
  Play Integrity (Android) y reCAPTCHA v3 en web con
  `--dart-define=APP_CHECK_SITE_KEY=...`. Si falta la site key en web, no se
  activa y se registra una advertencia.
- **Auth gate:** el widget raíz escucha `authStateChanges`. Sin usuario →
  `WelcomeScreen`. Con usuario y sin `users/{uid}` → onboarding. Con perfil →
  `DashboardScreen`. Los providers con alcance de usuario se crean debajo del
  gate con `key: ValueKey(uid)`; desaparece el usuario `'anonymous'`.
- **Constructores estables (los usan `main.dart` y los tests):**
  - `FinancesFirebaseDataSource({required FirebaseFirestore firestore, required String userId})`
  - `InventoryFirebaseDataSource({required FirebaseFirestore firestore, required String userId})`
  - `UserProfileFirebaseDatasource({required FirebaseFirestore firestore, required String userId})`
  - `HourlyRateLocalDataSource({required FirebaseFirestore firestore, required String userId})`
  - `FinancesProvider({required FinancesRepository repository})`
  - `InventoryProvider({required InventoryRepository repository})`
  - `UserProfileProvider({required UserProfileRepository repository})`
  - `HourlyRateProvider({required CalculateHourlyRate calculateUseCase, required HourlyRateRepository repository})`
  - `AiService({FirebaseFunctions? functions})`
  - `AiProvider({required AiService service, required String userId, FirebaseFirestore? firestore})`
- **Chat:** el cliente NO escribe en `messages`. Llama a `chat` y escucha el
  stream de `messages` de la conversación activa. Muestra el mensaje propio de
  forma optimista mientras llega la confirmación.
- **Errores:** los providers exponen `error` (String?) y `retry()`. Las
  pantallas muestran un estado de error con botón de reintento.

## Propiedad de archivos durante la migración

| Área | Archivos |
|---|---|
| Backend | `functions/**`, `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `.firebaserc` |
| Finanzas + inventario | `lib/features/finances/**`, `lib/features/inventory/**`, `lib/core/services/pdf_report_service.dart`, `lib/features/dashboard/presentation/pages/dashboard_screen.dart`, `.../tabs/home_tab.dart`, `.../widgets/financial_charts.dart` |
| Auth + perfil + valor hora + arranque | `lib/main.dart`, `lib/core/services/firebase_auth_service.dart`, `lib/core/services/google_auth_service.dart`, `lib/core/config/**`, `lib/features/auth/**`, `lib/features/onboarding/**`, `lib/features/user_profile/**`, `lib/features/hourly_value/**`, `.../pages/ayuda_screen.dart`, `.../pages/configuracion_screen.dart`, `.../pages/editar_perfil_screen.dart` |
| IA | `lib/core/services/ai_service.dart`, `.../providers/ai_provider.dart`, `.../tabs/ia_tab.dart` |
| CI, tests, landing, docs | `.github/**`, `test/**`, `landing/**`, `scripts/**`, `README.md`, `AGENTS.md`, `.gitignore`, borrado de archivos muertos |
