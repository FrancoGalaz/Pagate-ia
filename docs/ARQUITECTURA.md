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
   Firestore entrega tiempo real y offline sin código extra. Excepción
   aceptada: `AiProvider._loadLatestConversation` usa un `get()` para
   localizar la última conversación una sola vez al abrir el chat; sus
   mensajes se leen después por stream.
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
  amount: number (> 0)           BRUTO: lo que el cliente pagó
  type: 'income' | 'expense'
  category: string
  date: Timestamp
  monthKey: string 'yyyy-MM'  (derivado de date en el cliente; mes acotado a 01-12)
  docType: 'boleta_venta' | 'boleta_honorarios' | 'sin_documento'   (OPCIONAL, C-3)
  platformFee: number (>= 0 y <= amount; SOLO si type == 'income')  (OPCIONAL, C-3)
  createdAt, updatedAt: Timestamp

users/{uid}/fixedExpenses/{id}           (owner: read/write) gastos fijos recurrentes
  name: string
  amount: number (> 0)
  createdAt, updatedAt: Timestamp

users/{uid}/aiReports/{reportId}         (owner: create + read; SIN update ni delete)
  messageId: string                 id del mensaje reportado
  conversationId: string            (OPCIONAL; ausente = mensaje sin conversación guardada)
  reason: 'ofensivo' | 'incorrecto' | 'peligroso' | 'otro'
  comment: string (<= 1000)         (OPCIONAL, texto libre de la persona)
  reportedText: string (<= 2000)    copia del texto reportado
  createdAt, updatedAt: Timestamp

users/{uid}/months/{yyyy-MM}             (owner: read; write SOLO backend)
  totalIncome: number         BRUTO: suma de amount de los ingresos del mes
  totalExpenses: number
  totalPlatformFees: number   suma de platformFee de los INGRESOS del mes (C-3)
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
  dayKey: string 'yyyy-MM-dd'  (día, en hora de Santiago, de LOS DOS contadores diarios)
  chatCountDay: number         (mensajes del día; es la cuota de chat del plan pro)
  chatCountLifetime: number    (mensajes de toda la vida; es la cuota de chat del plan free)
  scanCountDay: number         (lecturas de boleta del día; cuota del plan pro)
  scanCountLifetime: number    (lecturas de toda la vida; cuota del plan free)

system/aiConfig                          (sin acceso desde cliente; solo backend)
  freeLifetimeQuota: number       (default 25)
  proDailyQuota: number           (default 300)
  freeLifetimeScanQuota: number   (default 40)
  proDailyScanQuota: number       (default 200)
  globalDailyCapEnabled: boolean  (default false)
  globalDailyCap: number          (default 2000; se compara contra calls + scanCalls)
system/aiUsage/days/{yyyy-MM-dd}         (sin acceso desde cliente; solo backend)
  calls: number                   (mensajes del asistente servidos hoy)
  scanCalls: number               (lecturas de boleta servidas hoy)
  dayKey: string
  updatedAt: Timestamp

waitlist/{id}                            (sin acceso desde cliente; solo backend)
  name, email, source: string     (id = sha256 del email normalizado → sin duplicados)
  submissions: number             (reenvíos del mismo correo)
  createdAt, updatedAt: Timestamp
```

`system/aiConfig` existe para que el dueño pueda cambiar los límites del
asistente y del lector de boletas, o cortarlos del todo, editando un documento
en la consola de Firestore sin desplegar nada. Cualquier campo ausente o
malformado cae al default.

**Las dos cuotas son independientes y comparten un solo `dayKey`.** Leer
boletas no gasta mensajes del asistente ni al revés: son cuatro contadores
separados. Pero `meta/usage` tiene UN solo campo `dayKey`, y los dos contadores
diarios se interpretan contra él, así que escribirlo por una de las dos cuotas
AVALA el contador de la otra. Por eso `quota.ts` reinicia LOS DOS contadores
diarios en la misma escritura cuando el día cambia: sin eso, la primera lectura
de boleta del día nuevo haría que el `chatCountDay` de ayer se leyera como el de
hoy y un usuario pro se quedaría sin asistente sin haber escrito un mensaje.
Está probado en `functions/test/quota.test.ts`, en los dos sentidos.

**El tope global suma los dos gastos** (`calls + scanCalls`). Es el freno de
mano del dueño y tiene que frenar todo el gasto de IA; los campos van separados
para que el registro y el mensaje de error puedan decir cuál de las dos cosas se
disparó.

Validaciones en reglas: `hasOnly` de campos permitidos, tipos, rangos con tope
SUPERIOR (1e12 para dinero, 1e9 para unidades; sin tope, `Infinity` pasaba como
número y contaminaba para siempre las sumas de `months`), strings de máximo 200
caracteres (2000 para `description`), `monthKey` con regex
`^\d{4}-(0[1-9]|1[0-2])$`, `createdAt` inmutable, `updatedAt == request.time`
(o sea, `serverTimestamp()`), `read` separado en `get` y `list` con `list`
acotado a 200 documentos, y `delete` de `users/{uid}` denegado.

**`aiReports` es la excepción a la forma del resto del árbol (P-12).** Es la
única subcolección que el dueño **crea y después no puede modificar ni borrar**:
`create` y `read` sí, `update` y `delete` denegados. Existe porque la política de
Google Play para apps con IA generativa exige un mecanismo **dentro de la app**
para marcar contenido ofensivo o dañino, y el botón «Reportar respuesta» de la
pestaña de IA escribe ahí. Un reporte es la prueba de que alguien marcó una
respuesta: quien puede editarlo o borrarlo después puede hacer esa prueba
desaparecer, así que si la persona se equivocó de motivo manda otro reporte. El
borrado de cuenta sigue cubierto sin tocar nada, porque `deleteAccount` usa
`recursiveDelete`, que descubre las subcolecciones en tiempo de ejecución.

Hasta este cambio no había ningún `match` para esa ruta, así que caía en el
`match /{document=**} { allow read, write: if false; }` del final y **toda
escritura se denegaba**: el requisito de Play estaba dibujado en la interfaz y no
funcionaba.

El mismo regex de `monthKey` vive en `functions/src/months.ts`
(`MONTH_KEY_RE`). No es redundante: las reglas cubren lo que escribe el cliente
y el regex del trigger cubre lo que escribe el Admin SDK (sembrado de datos,
migraciones), que no pasa por las reglas. Si cambia uno, cambia el otro.

## Contrato C-3: orientación al mercado chileno

`docType` y `platformFee` existen porque en Chile un "ingreso" a secas no se
puede agrupar de forma útil: una boleta de honorarios y una boleta de venta no
son el mismo documento, y la comisión del medio de pago sale del monto cobrado.
Sin estos dos campos, cualquier total derivado del bruto sobreestima lo que el
negocio realmente recibió.

- Los dos campos son **opcionales**, para no invalidar ningún documento ya
  escrito. Si falta `docType`, se asume `'sin_documento'`. Si falta
  `platformFee`, es `0`.
- `docType` se escribe **omitido o con uno de los tres valores**. `null` lo
  rechazan las reglas a propósito: "sin documento" tiene que tener una sola
  representación.
- `platformFee` va acotado a `[0, amount]`. Por encima de `amount`, el neto
  derivado saldría negativo.
- `platformFee` se acepta **solo en los ingresos** (`type == 'income'`). La
  comisión es lo que descuenta el medio de pago de una venta cobrada; en un
  gasto no significa nada. Antes se aceptaba en los dos tipos, y era un dato
  que nada podía interpretar: el agregado `totalPlatformFees` suma las
  comisiones de los ingresos, así que una comisión guardada en un gasto se
  ignoraba en silencio. El formulario del cliente nunca escribe una (en un
  gasto borra el campo). El gasto que sí existe —la liquidación mensual que un
  marketplace cobra aparte— se registra como gasto normal con la categoría
  `Comisión de plataforma`.
- **El neto NO se guarda.** Se deriva siempre como `amount - platformFee`. Un
  neto guardado se puede contradecir con sus propios operandos.

### Decisión: `months/*` guarda la SUMA de las comisiones, no el neto

`users/{uid}/months/{yyyy-MM}` guarda `totalPlatformFees`, y **no** guarda
ningún neto. Las dos mitades de la decisión:

**Por qué sí se guarda la suma de comisiones.** `months/*` es el único sitio del
que el cliente y el asistente sacan el resumen de un mes, y solo tenía el bruto.
El neto del mes no se podía derivar de él: había que recorrer las transacciones,
que es exactamente lo que el agregado existe para evitar, y además el cliente
solo puede leer **200 documentos por consulta** (el tope de `firestore.rules`),
así que a partir del movimiento 201 de un mes el neto calculado en el cliente
habría salido mal **sin avisar**. Un negocio que cobra con Mercado Pago o
Transbank ve en pantalla un ingreso mensual que no recibió, y el asistente
razona sobre esa misma cifra inflada.

**Por qué no se guarda el neto.** Es la regla de C-3 y sigue en pie: un neto
guardado se puede contradecir con sus propios operandos. `totalPlatformFees` es
un **operando**, una suma más, del mismo tipo que `totalIncome` y recalculada de
cero en cada pasada del trigger. El neto se deriva donde se muestra, como
`totalIncome - totalPlatformFees`.

Límite que no se cruza, y que vale para el cliente, para el backend y para el
prompt del asistente: la app **registra y muestra**, no **asesora**. No calcula
impuestos a pagar, no dice cuánto declarar y no da consejo tributario. Lo
permitido es agrupar lo que el usuario registró de forma que le sirva para
hablar con su contador.

`functions/src/prompt.ts` se lo impone al modelo, y desde que el asistente VE
los documentos el bloque es explícito, no una frase de cortesía: no calcular
impuestos, retenciones, IVA ni PPM; no decir cuánto declarar ni cuándo; no
interpretar normas del SII; no recomendar emitir un documento en vez de otro; y
decir claro, cuando se lo pidan, que la app registra y muestra sus números pero
no asesora, y que eso lo ve un contador. El tipo de documento está en el
contexto para **describir y agrupar** (cuánto vendió con boleta de venta este
mes), no para deducir obligaciones. Un número de impuestos equivocado no es un
error cosmético: es dinero de la persona y una afirmación que la app no puede
sostener. `functions/test/prompt.test.ts` vigila que esas instrucciones estén
presentes y **fuera** del bloque de datos, donde serían inertes.

## Backend (Cloud Functions 2ª gen, TypeScript, Node 22, región `southamerica-west1`)

Todas: `region: southamerica-west1`. Los tres callables (`chat`,
`scanReceipt` y `deleteAccount`) exigen App Check cuando el parámetro
`ENFORCE_APP_CHECK` es `true` (por defecto `false`, hasta activarlo en consola)
y aceptan CORS solo desde el hosting de producción; el `localhost` de desarrollo
se añade únicamente bajo el emulador.

### `chat` (callable)

```
request:  { conversationId?: string, message: string }
response: { conversationId: string, reply: string }
errores:  unauthenticated | invalid-argument | resource-exhausted | internal
```

`timeoutSeconds: 60`, `memory: 256MiB`, `maxInstances: 5`,
`secrets: [OPENROUTER_API_KEY]`.

Flujo:
1. Verifica `request.auth` y, si `ENFORCE_APP_CHECK`, `request.app`.
2. Valida la entrada: `message` no vacío y de hasta 2.000 caracteres
   (`MAX_MESSAGE_CHARS`), `conversationId` con forma `^[A-Za-z0-9_-]{1,128}$`.
3. **Reserva** cuota de forma atómica (`reserveChatQuota`), ANTES de llamar al
   modelo. Si no queda → `resource-exhausted`. Los límites:
   - plan `free`: **25 mensajes DE POR VIDA** (`chatCountLifetime`), no diarios.
     El registro es abierto, así que una cuota diaria era un grifo que se
     reabría cada día por cada cuenta nueva, y lo paga el dueño.
   - plan `pro`: **300 mensajes al día** (`chatCountDay`).
   - tope **global** diario con interruptor en `system/aiConfig`: el freno de
     mano del dueño, que corta todo el gasto de IA sin desplegar.
   - el día se calcula en `America/Santiago`, no en UTC.

   **`pro` no se puede comprar, y ningún texto de la app lo ofrece.** No existe
   `in_app_purchase` ni integración de facturación en el proyecto: `pro` es un
   valor del campo `plan` que solo escribe el backend, o el dueño a mano en la
   consola, para abrir la mano con una cuenta concreta. El mensaje de cuota
   agotada decía «Cambia a Pro para seguir conversando»: pedía una acción
   imposible y, al anunciar dentro de la app un plan de pago que no pasa por la
   facturación de Google Play, incumplía su política. Ahora
   (`freeQuotaExhaustedMessage`) dice solo que los mensajes eran un total y no
   se renuevan. `functions/test/quota.test.ts` tiene el candado: el texto no
   puede contener pro, plan, pago, pagar, comprar, premium, suscri, mejora ni
   upgrade. El día que exista una compra real, este es el sitio donde se
   menciona, y no antes.
4. Si no hay `conversationId`, crea la conversación.
5. Guarda el mensaje del usuario en `messages`.
6. Arma el system prompt del lado servidor con: perfil, `hourlyRate`, último
   `months/*`, últimas 10 transacciones (`RECENT_TRANSACTIONS_LIMIT`), conteo de
   inventario, y los últimos **6** mensajes de la conversación
   (`HISTORY_LIMIT`). Era 20: el historial se reenvía completo en cada turno,
   así que ese número multiplica los tokens de entrada de toda la conversación.
   El prompt tiene tope duro de 12.000 caracteres (`MAX_PROMPT_CHARS`) y los
   datos del usuario van saneados y dentro de un bloque delimitado, declarado
   como datos y no como instrucciones (defensa contra inyección de prompt).

   **El contexto incluye los campos chilenos de C-3.** El resumen del mes lleva
   tres renglones separados y etiquetados —ingresos brutos, comisiones de medios
   de pago e ingresos netos de comisiones— y cada ingreso de la lista lleva su
   documento (`doc: boleta de venta` / `boleta de honorarios` /
   `sin documento`) y, si tuvo comisión, su bruto, su comisión y su neto. Antes
   solo viajaba el bruto, así que el asistente hablaba de lo que el negocio
   "ganó" con una cifra que el negocio nunca recibió, y no podía distinguir los
   documentos ni cuando se le preguntaba de frente.

   El **balance** del mes se sigue calculando bruto menos gastos, y la etiqueta
   lo dice. No se calcula con el neto a propósito: es la cifra que el gráfico de
   la app muestra en pantalla, y si el asistente diera otra con el mismo nombre
   nadie podría saber cuál de las dos miente.

   Los valores se acotan otra vez aquí (`docType` contra el conjunto cerrado,
   comisiones a `[0, monto]`), porque el Admin SDK no pasa por
   `firestore.rules` y de este punto los datos salen directos al modelo.
7. Llama a OpenRouter con `OPENROUTER_API_KEY` (secreto) y modelo
   `OPENROUTER_MODEL` (parámetro, default `deepseek/deepseek-v4-flash`).
8. Guarda la respuesta en `messages` y actualiza `messageCount` y `updatedAt`.
   Si OpenRouter falla, **devuelve** la cuota (`refundChatQuota`) y deshace lo
   escrito: un fallo del proveedor no le gasta el mensaje al usuario.
9. Devuelve `{ conversationId, reply }`.

### `scanReceipt` (callable)

```
request:  { text: string, source?: 'photo' | 'pdf' }
response: { items: Array<{ name, quantity, unit, unitPrice, code }>,
            supplier: string | null, documentNumber: string | null,
            total: number | null, truncated: boolean }
errores:  unauthenticated | invalid-argument | resource-exhausted
          | unavailable | deadline-exceeded | internal
```

`timeoutSeconds: 60`, `memory: 256MiB`, `maxInstances: 5`,
`secrets: [OPENROUTER_API_KEY]`, modelo `OPENROUTER_SCAN_MODEL` (parámetro
propio, default `deepseek/deepseek-v4-flash`).

Convierte el texto de una boleta o factura de **compra** en una lista de
artículos para que el usuario la revise y la meta al inventario.

**RECIBE TEXTO. NUNCA UNA IMAGEN.** El reconocimiento de texto corre en el
teléfono con ML Kit (en el dispositivo, sin conexión y gratis) y la imagen se
borra ahí mismo, haya ido bien o mal. Lo único que sale del teléfono es el texto
ya extraído. No es un detalle de implementación: es la decisión de producto que
hace que el proyecto **no** tenga Firebase Storage, **no** tenga que declarar
fotos en Seguridad de Datos de Google Play, **no** tenga imágenes que borrar
cuando alguien borra su cuenta y **no** tenga coste de almacenamiento. Si esta
función aceptara algún día una imagen, todo eso volvería de golpe.

**Es un repaso, no el camino único.** El cliente ordena siempre la lista él
solo primero, con una heurística local que funciona sin conexión y sin cuota.
Este callable es la segunda pasada, que sobre texto limpio acierta mucho más que
una regla. De ahí tres consecuencias que son contrato:

1. Un fallo de aquí **no rompe nada**: el cliente se queda con su lista local.
2. `resource-exhausted` **no es un error para el cliente**, es información: la
   lista ya está en pantalla, se muestra el mensaje del servidor en una franja
   informativa y se sigue. Agotar la cuota de lectura baja la calidad del
   ordenado, no bloquea la función.
3. **Nada de lo que devuelve se guarda sin que el usuario lo revise.** La app
   propone, el usuario confirma. Mismo principio que lo tributario.

Flujo:
1. Verifica `request.auth` y, si `ENFORCE_APP_CHECK`, `request.app`.
2. Valida la entrada **antes de la cuota**: `text` no vacío y de hasta 8.000
   caracteres (`MAX_SCAN_TEXT_CHARS`). Un texto inválido no le gasta al usuario
   una de sus lecturas. `source` solo matiza el prompt y el registro, así que un
   valor desconocido se ignora en vez de rechazar la llamada.
3. **Reserva** cuota propia (`reserveScanQuota`), con contadores separados de los
   del chat: `scanCountLifetime` (free, 40 de por vida) y `scanCountDay` (pro,
   200 al día), configurables en `system/aiConfig`. El tope global del dueño
   cuenta `calls + scanCalls`.
4. Arma el prompt del lado servidor (`scanPrompt.ts`) y llama a OpenRouter con
   `response_format` de tipo `json_schema` en modo `strict`, `temperature: 0`
   (la misma boleta tiene que dar la misma lista) y `maxTokens: 1500`.
5. **Valida la salida campo por campo en TypeScript, sin creerse el esquema.**
   El esquema es una petición al proveedor, no una garantía: un proveedor que lo
   ignore devuelve prosa. Un artículo con nombre vacío, `quantity` fuera de
   `[1, 10000]` o `unitPrice` fuera de `[1, 1e8]` se **descarta** y se registra;
   una unidad vacía o rara no descarta el artículo, cae en `unidades`. Por
   encima de 40 artículos se recorta y se devuelve `truncated: true`.
6. Devuelve `items: []` —que es una respuesta válida— si no quedó ninguno.

**Cuándo se devuelve la cuota, y cuándo no.** Se devuelve
(`refundScanQuota`) ante un fallo del proveedor: `OpenRouterError`, plazo
agotado, o una salida irrecuperable (ni JSON, ni objeto, ni lista). **No** se
devuelve cuando el modelo contestó bien y la lista salió vacía, aunque el
usuario no reciba nada útil: el texto de entrada lo controla entero quien llama,
así que devolver la cuota ante una respuesta vacía sería una vía para hacer
llamadas al modelo sin límite a costa del dueño.

Errores, con el mensaje del servidor como única fuente de lo que lee el usuario:

| Código | Cuándo | Mensaje |
|---|---|---|
| `unauthenticated` | sin `request.auth`, o `ENFORCE_APP_CHECK` sin `request.app` | «Inicia sesión para leer boletas.» |
| `invalid-argument` | `text` no es texto, está vacío o pasa de 8.000 caracteres | «El texto de la boleta está vacío o es demasiado largo.» |
| `resource-exhausted` | cuota propia agotada, o tope global del día | `freeScanQuotaExhaustedMessage` / el del tope global |
| `unavailable` | `OpenRouterError` | «El lector no responde. Intenta de nuevo.» |
| `deadline-exceeded` | plazo de OpenRouter agotado | ídem |
| `internal` | salida del modelo irrecuperable | «No pude ordenar la boleta.» |

**Inyección de prompt desde una boleta impresa.** Una boleta puede llevar
impreso texto hostil (un sello, una etiqueta, un volante dentro del encuadre).
El prompt del lector usa los MISMOS exports que `prompt.ts` —`DATA_OPEN`,
`DATA_CLOSE` y `sanitizeField`— y no una defensa paralela, porque dos defensas
se desincronizan. La diferencia es que `sanitizeOcrText` aplica `sanitizeField`
**línea por línea**: la estructura de una boleta ES el salto de línea, y
aplanarla a un párrafo dejaría al modelo adivinando dónde acaba cada artículo.

**Lo que se escribe en `users/{uid}/inventory`: nada nuevo.** Un documento
normal por artículo confirmado, con `type` `'material'` por defecto, `minStock`
1, y `supplier` / `code` rellenos cuando se leyeron. `firestore.rules` **no
cambia**: `validInventoryItem` ya aceptaba los dos campos. Hasta ahora eran
código muerto porque el formulario manual no los pedía; el lector es el primer
sitio que los rellena de verdad, y la forma exacta queda fijada en
`functions/test/rules.test.ts`.

**Decisión de producto pendiente: `stock` es entero.** `isCount` de las reglas
exige `v is int`, y `stock`/`minStock` son `int` en `InventoryItemEntity`. Una
cantidad fraccionaria del OCR (`2,5 kg`) llega entera desde este callable —aquí
**no** se redondea— y el cliente la redondea hacia arriba diciéndoselo al
usuario en la ficha de revisión. Pasar `stock` a decimal es un cambio de
contrato que toca reglas, entidad, formularios y agregados: queda anotado, sin
hacer.

### `deleteAccount` (callable)

```
request:  (sin cuerpo)
response: { ok: true, uid: string, authDeleted: boolean, deletedAt: string }
errores:  unauthenticated | internal
```

`timeoutSeconds: 300`, `memory: 256MiB`, `maxInstances: 2`.

Existe porque la política de eliminación de datos de Google Play exige dos
caminos para borrar una cuenta: uno dentro de la app (este callable) y una URL
pública accesible sin instalarla (la página de la landing).

Borra en este orden, y el orden importa: **primero** los datos
(`recursiveDelete` de `users/{uid}` y todo su árbol) y **después** el usuario de
Authentication. Al revés, si el paso de datos fallara quedarían documentos
huérfanos sin ninguna sesión capaz de volver a pedir su borrado. Tras el borrado
verifica que no quedó nada (`recursiveDelete` usa un `BulkWriter` que resuelve
sin lanzar aunque algún lote quede atrás) y si queda algo responde `internal`.
Es idempotente: `auth/user-not-found` se trata como el estado final buscado.

Por eso `firestore.rules` deniega `delete` en `users/{uid}`: borrar solo ese
documento desde el cliente dejaba colgando todas las subcolecciones.

### `onTransactionWritten` (trigger Firestore)

Al crear, editar o borrar `users/{uid}/transactions/{txId}`, recalcula
`users/{uid}/months/{monthKey}` con una consulta agregada
(`sum`/`count`) sobre las transacciones de ese `monthKey`. Si cambió el
`monthKey` entre before/after, recalcula ambos meses. Idempotente, con
`retry: true` y `maxInstances: 10`.

Detalles que no son negociables:
- La lectura agregada y la escritura van **dentro de una misma transacción**.
  Con dos escrituras seguidas sobre el mismo mes (el caso normal), las dos
  invocaciones del trigger se solapaban y la que había leído el estado más viejo
  podía commitear la última, dejando los totales mal de forma permanente.
- Solo recalcula meses cuyo `monthKey` pasa `MONTH_KEY_RE` (mes 01-12).
- Si el mes se queda sin transacciones, el documento se **borra** en vez de
  quedarse en ceros: un mes en cero hacía que `chat` eligiera como "último mes"
  un documento vacío y le contara al asistente que el negocio no facturó nada.
- Suma también `totalPlatformFees` (comisiones de los **ingresos** del mes). El
  bruto sigue siendo `totalIncome`; el neto se deriva donde se muestra.
- **Las comisiones se suman en una agregación APARTE**, y eso no es una
  redundancia que se pueda simplificar metiéndolas en la misma `aggregate()` que
  el total y la cuenta. Comprobado contra el emulador: en una agregación
  combinada, un `sum('platformFee')` restringe el conjunto entero a los
  documentos que **tienen** ese campo. Con dos ingresos de 100 y 50, y solo el
  primero con comisión,
  `{ total: sum('amount'), fees: sum('platformFee'), count: count() }` devuelve
  `{ total: 100, fees: 7, count: 1 }`: el ingreso de 50 desaparece del total y de
  la cuenta. Y como `platformFee` es opcional, lo normal es que la mayoría de los
  ingresos no lo tengan, así que los totales del mes habrían contado solo las
  ventas con comisión. En consulta propia el comportamiento es el correcto.
  `functions/test/months.test.ts` tiene el test que lo caza
  («mezcla ingresos con y sin comision sin perder ninguno»).
- Cada agregación de suma necesita su **índice compuesto** con el campo sumado
  al final. `firestore.indexes.json` ya traía
  `(type, monthKey, amount)` para `sum('amount')`; la suma de comisiones añade
  `(type, monthKey, platformFee)`. El emulador no exige índices, así que esto
  **no lo detecta ningún test**: sin la entrada, el recálculo del mes puede
  fallar en producción con `FAILED_PRECONDITION`. Los dos caminos de despliegue
  ya lo cubren, porque los dos usan `--only ...,firestore,...`, que sube reglas
  **e** índices: `scripts/deploy-web.sh` y
  `.github/workflows/deploy-web.yml`.
- Las sumas pasan por un filtro de finitud y `totalPlatformFees` se acota a
  `[0, totalIncome]`. Por documento las reglas ya garantizan
  `0 <= platformFee <= amount`, pero el Admin SDK (sembrado, migraciones) no pasa
  por las reglas, y un `Infinity` o un neto negativo en `months/*` es permanente:
  nada vuelve a recalcular ese mes hasta la siguiente escritura en él.
- **El cliente no necesita cambiar para que esto no le rompa nada**:
  `FinancesSummaryModel.fromDoc` lee los campos que conoce e ignora el resto, y
  un `months/*` escrito antes de este cambio (sin el campo) se lee como 0.

### `waitlist` (HTTP, CORS abierto solo a los dominios de la landing)

```
POST { name: string, email: string, source?: string }
200 { ok: true } | 400 { error } | 429 { error }
```

Valida email, largo de campos y un límite por IP en memoria (5 por hora). El id
del documento es el **sha256 del correo normalizado**, así que reenviar el mismo
correo no crea un duplicado: se conserva el `createdAt` original y se incrementa
`submissions`.

## Hosting: cabeceras HTTP y el namespace reservado `/__/`

`firebase.json` sirve el mismo build en `pagate-17211.web.app` y en
`pagate-17211.firebaseapp.com`, y el segundo es el **`authDomain`** del
proyecto. El SDK de Auth (lo que usa `signInWithPopup` por debajo, también en
Flutter web) **mete en un iframe** `https://<authDomain>/__/auth/iframe` para
recibir los eventos de autenticación.

Por eso las cabeceras están partidas en dos grupos:

| Cabeceras | `source` | Por qué |
|---|---|---|
| HSTS, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy` | `**` | No estorban en `/__/`. |
| `X-Frame-Options: DENY`, CSP con `frame-ancestors 'none'` | `/`, `/!(__)`, `/!(__)/**` | Entre los tres cubren toda la app y **ninguno casa con `/__/**`**. |

Antes, `X-Frame-Options: DENY` estaba sobre `**`, o sea también sobre
`/__/auth/iframe`: el navegador se niega a enmarcar ese documento y el inicio de
sesión con Google queda colgado. Lo mismo haría `frame-ancestors 'none'` el día
que la CSP deje de ser `Report-Only`.

Dos cosas que conviene saber antes de "simplificar" esto:
- **`SAMEORIGIN` no arregla nada.** La página está en `web.app` y el iframe en
  `firebaseapp.com`: son orígenes distintos, así que `SAMEORIGIN` bloquea igual.
- **Una cabecera no se puede "quitar" para una ruta.** `headers` solo sabe PONER
  valores, así que un bloque posterior para `/__/**` no puede borrar lo que puso
  `**`. El único arreglo posible es que el patrón que la pone no llegue a casar
  con `/__/`, que es exactamente lo que hacen los tres `source` de arriba.

`functions/test/hosting-headers.test.ts` vigila esto: comprueba contra el
`firebase.json` real, con el mismo extglob que usa Hosting, que ninguna cabecera
de enmarcado alcanza `/__/auth/iframe` y que las rutas de la app (incluidas las
de navegación que reescriben a `index.html`) sí quedan protegidas.

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
- **Reportes de IA (P-12):** `AiProvider.reportMessage` es la ÚNICA escritura
  que el cliente hace en el árbol del chat, y va a `users/{uid}/aiReports`, no a
  `messages`. Devuelve `false` si Firestore rechazó la escritura, y la interfaz
  dice que no se pudo: un reporte que no se guardó no se da por enviado. No hay
  reintento ni cola local.
- **Errores:** los providers exponen `error` (String?) y `retry()`. Las
  pantallas muestran un estado de error con botón de reintento.
- **Tema claro único.** `AppTheme.lightTheme` es el único tema y lo aplica
  `app_shell.dart`, que además fija `themeMode: ThemeMode.light` para que la
  app no siga al sistema. **No existe `AppTheme.darkTheme`**: no hay
  tema oscuro que mantener, así que ningún widget debe volver a consultar
  `Theme.of(context).brightness` ni `MediaQuery.platformBrightness` para decidir
  colores. Los tokens salen de `lib/core/constants/app_constants.dart`.
- **Moneda:** un único formateador con `intl`. No se construyen strings de
  dinero a mano.
- **C-3:** el neto de una transacción se **deriva** (`amount - platformFee`),
  nunca se guarda. El cliente tampoco calcula impuestos ni da indicaciones
  tributarias: ver el límite al final de la sección del contrato C-3.

## Propiedad de archivos durante la migración

| Área | Archivos |
|---|---|
| Backend | `functions/**`, `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `.firebaserc` |
| Finanzas + inventario | `lib/features/finances/**`, `lib/features/inventory/**`, `lib/core/services/pdf_report_service.dart`, `lib/features/dashboard/presentation/pages/dashboard_screen.dart`, `.../tabs/home_tab.dart`, `.../widgets/financial_charts.dart` |
| Auth + perfil + valor hora + arranque | `lib/main.dart`, `lib/core/services/firebase_auth_service.dart`, `lib/core/services/google_auth_service.dart`, `lib/core/config/**`, `lib/features/auth/**`, `lib/features/onboarding/**`, `lib/features/user_profile/**`, `lib/features/hourly_value/**`, `.../pages/ayuda_screen.dart`, `.../pages/configuracion_screen.dart`, `.../pages/editar_perfil_screen.dart` |
| IA | `lib/core/services/ai_service.dart`, `.../providers/ai_provider.dart`, `.../tabs/ia_tab.dart` |
| CI, tests, landing, docs | `.github/**`, `test/**`, `landing/**`, `scripts/**`, `README.md`, `AGENTS.md`, `.gitignore`, borrado de archivos muertos |
