# Seguridad de los datos — respuestas para Google Play Console

Tarea **P-09**. Este documento es la hoja de respuestas del formulario *Play
Console → Contenido de la aplicación → Seguridad de los datos*, tipo de dato por
tipo de dato.

No es un borrador orientativo: cada fila está derivada de código verificado, con
el archivo que lo justifica. Si cambia el modelo de datos, cambia este documento
y se vuelve a enviar el formulario. Una declaración que no coincida con lo que la
app hace es causa de retirada de la ficha, y Google compara la declaración con el
comportamiento real del binario.

> **Las referencias al código son por nombre de función, no por número de
> línea.** Antes eran números (`prompt.ts:82`, `chat.ts:232-239`) y se
> desplazaron todos: `prompt.ts` se reescribió con el contrato C-3 y las citas
> acabaron apuntando a líneas que no dicen nada de lo que el documento afirmaba.
> Peor que una cita rota es una cita que apunta a otra cosa, porque quien
> comprueba la encuentra y no la cuestiona. Un nombre de función se mueve con su
> código y, si desaparece, no se puede confundir con otro.

**Fuentes normativas usadas** (consultadas el 6 de octubre de 2026):

- [Proporcionar información para la sección Seguridad de los datos](https://support.google.com/googleplay/android-developer/answer/10787469)
  — definiciones de *recopilar*, *compartir*, categorías y excepciones.
- [Política de eliminación de cuentas y datos de usuario](https://support.google.com/googleplay/android-developer/answer/13327111)

---

## 0. Las dos decisiones que mandan sobre todo lo demás

### 0.1 Los datos financieros del usuario son categoría sensible

Google define la categoría **Información financiera** con cuatro subtipos:
*Información de pago del usuario*, *Historial de compras*, *Puntuación de
crédito* y ***Otra información financiera*** («cualquier otra información
financiera, como el salario o las deudas del usuario»).

Todo lo que Págate-IA guarda sobre el dinero del usuario —meta mensual, sueldo
objetivo, valor hora, montos de transacciones, agregados mensuales, precios y
valor del inventario— cae en **Otra información financiera**. Play la trata como
sensible: no se puede usar para publicidad, no se puede vender y la casilla de
*compartida con terceros* es de las más auditadas del formulario.

### 0.2 Enviar datos a OpenRouter SÍ cuenta como compartir (razonado, no asumido)

Google define compartir como «transferir datos de usuario recopilados por tu app
a un tercero», e incluye expresamente las **transferencias de servidor a
servidor**. Eso es literalmente lo que hace `callOpenRouter()` en `functions/src/openrouter.ts`:
un `POST` desde nuestra Cloud Function a `https://openrouter.ai/api/v1/chat/completions`.

Hay cuatro excepciones que eximen de declararlo. Las descarto una por una:

| Excepción | ¿Aplica? | Por qué |
|---|---|---|
| **Proveedor de servicios** que procesa por cuenta del desarrollador | **No, hoy no** | Ver el razonamiento abajo. Es la única candidata real. |
| Fines legales (obligación legal) | No | No hay obligación legal; es el funcionamiento normal del producto. |
| Acción iniciada por el usuario, donde el usuario espera razonablemente que se comparta | No | El usuario escribe un mensaje al asistente. No elige el destino, no se le nombra el tercero y hoy la app no le dice nada: el envío del perfil, los totales del mes y las últimas 10 transacciones ocurre sin que lo pida ni lo vea. |
| Datos totalmente anonimizados | No | Va el nombre del usuario y el de su negocio (`profileSection()` de `prompt.ts`) y los títulos libres de sus transacciones (`transactionsSection()`). Es lo contrario de anónimo. |

**Por qué la excepción de proveedor de servicios no se sostiene hoy.** Para
invocarla, el tercero tiene que tratar los datos únicamente por cuenta del
desarrollador y según sus instrucciones. Tres hechos del código lo impiden:

1. La petición de `openrouter.ts` **no envía ninguna cabecera de política de
   datos**. Rige el ajuste por defecto de la cuenta de OpenRouter, que puede
   permitir registro y entrenamiento. No hay instrucción nuestra que lo limite.
2. OpenRouter **es un enrutador, no el modelo**. `functions/src/config.ts`
   fija `OPENROUTER_MODEL` por defecto en `deepseek/deepseek-v4-flash`, y el
   parámetro es cambiable en caliente. El procesador final lo elige el
   enrutamiento, no nosotros, y no tenemos relación contractual con él.
3. No hay ningún acuerdo de tratamiento de datos firmado con OpenRouter que
   documente la relación de encargo.

**Decisión: se declara COMPARTIDO.** Declarar de más no infringe ninguna
política; declarar de menos sí, y es exactamente el hallazgo por el que se
retiran fichas de apps financieras.

**Qué haría falta para poder reclasificarlo** (no lo doy por hecho, lo dejo como
condición): firmar un acuerdo de tratamiento con OpenRouter, fijar en la cuenta
la política de datos más restrictiva, enviarla además de forma explícita desde
`openrouter.ts` para no depender de un ajuste de consola, y fijar el modelo a un
proveedor concreto con el que exista la misma garantía. Mientras los cuatro no
se cumplan, la casilla sigue marcada.

**Google sí es proveedor de servicios.** Firebase Authentication, Cloud Firestore
y Cloud Functions procesan los datos por nuestra cuenta bajo el acuerdo de
tratamiento de datos de Google Cloud. Son **recopilación**, no **compartición**.

---

## 1. Tabla de respuestas

Leyenda: **Rec.** = se recopila · **Comp.** = se comparte · **Oblig.** =
obligatorio u opcional · **Trán.** = cifrado en tránsito · **Borr.** = el usuario
puede solicitar su eliminación.

### 1.1 Información personal

| Tipo de dato | Rec. | Comp. | Oblig. | Finalidad | Trán. | Borr. | Fuente en el código |
|---|---|---|---|---|---|---|---|
| Nombre | **Sí** | **Sí** (OpenRouter) | Obligatorio | Funciones de la app | Sí | Sí (ver §3) | `users/{uid}.name`; sale en `profileSection()` de `prompt.ts` |
| Dirección de correo electrónico | **Sí** | No | Obligatorio | Gestión de la cuenta; funciones de la app | Sí | Sí | Firebase Auth; `signInWithEmailAndPassword()` y `createUserWithEmailAndPassword()` de `lib/core/services/firebase_auth_service.dart`. **No** entra en el prompt |
| Identificadores de usuario | **Sí** | No | Obligatorio | Gestión de la cuenta; funciones de la app | Sí | Sí | El `uid` de Firebase Auth. No se envía a OpenRouter. |
| Otra información (nombre y rubro del negocio, moneda) | **Sí** | **Sí** (OpenRouter) | Obligatorio | Funciones de la app; personalización | Sí | Sí | `users/{uid}`; sale en `profileSection()` de `prompt.ts` |
| Número de teléfono | No | — | — | — | — | — | No se pide en ninguna pantalla. |
| Dirección física | No | — | — | — | — | — | — |
| Raza, etnia, orientación sexual, creencias políticas o religiosas | No | — | — | — | — | — | — |

*Obligatorio en las cuatro primeras filas porque
`_validarObligatorio()` de `setup_inicial_screen.dart` no deja pasar el
onboarding sin nombre, nombre
del negocio y tipo de negocio.*

### 1.2 Información financiera

| Tipo de dato | Rec. | Comp. | Oblig. | Finalidad | Trán. | Borr. | Fuente en el código |
|---|---|---|---|---|---|---|---|
| **Otra información financiera** | **Sí** | **Sí, pero no toda** (OpenRouter) | Obligatorio | Funciones de la app | Sí | Sí | **Se recopila:** meta mensual (`users/{uid}.monthlyGoal`), sueldo objetivo + horas + valor hora (`users/{uid}.hourlyRate`), montos de `transactions/` con su `docType` y su `platformFee`, montos de `fixedExpenses/`, precios y stock de `inventory/`, agregados de `months/`. **Se comparte** con OpenRouter: el perfil y el valor hora (`profileSection`, `hourlyRateSection`), los totales del último mes incluidas las comisiones (`monthSection`) y las últimas 10 transacciones (`transactionsSection`). **Ver el §1.6: los gastos fijos y el detalle del inventario NO salen** |
| Información de pago del usuario | No | — | — | — | — | — | La app no cobra, no guarda tarjetas y no tiene pasarela. `functions/src/index.ts` solo exporta `chat`, `onTransactionWritten` y `waitlist`. |
| Historial de compras | **No** — decisión argumentada | — | — | — | — | — | Ver §2.1. |
| Puntuación de crédito | No | — | — | — | — | — | — |

*Obligatorio porque el onboarding exige una meta mensual mayor que cero
(`_validarMeta()` del mismo archivo). Las transacciones y el inventario son
opcionales, pero el formulario se responde por tipo de dato y basta con que un
elemento del tipo sea obligatorio.*

### 1.3 Mensajes

| Tipo de dato | Rec. | Comp. | Oblig. | Finalidad | Trán. | Borr. | Fuente en el código |
|---|---|---|---|---|---|---|---|
| Otros mensajes en la app | **Sí** | **Sí** (OpenRouter) | Opcional | Funciones de la app | Sí | Sí | `users/{uid}/conversations/{id}/messages`, que escribe **solo** `chat.ts` (el cliente no puede). Se reenvían los últimos **`HISTORY_LIMIT` = 6**, no 20: la cifra de 20 era de una versión anterior y estaba además escrita en la política de privacidad, donde la corrigió este mismo cambio |
| Correos electrónicos | No | — | — | — | — | — | — |
| SMS o MMS | No | — | — | — | — | — | — |

*Opcional: la app funciona completa sin tocar el asistente.*

### 1.4 Actividad en la aplicación

| Tipo de dato | Rec. | Comp. | Oblig. | Finalidad | Trán. | Borr. | Fuente en el código |
|---|---|---|---|---|---|---|---|
| Interacciones con la app | **Sí** | No | Opcional | Funciones de la app; prevención de fraude y abuso | Sí | Sí | `users/{uid}/meta/usage`: `{dayKey, chatCountDay, chatCountLifetime}`, escrito por `reserveChatQuota()` de `functions/src/quota.ts` dentro de la transacción de cuota. `chatCountLifetime` es el contador que aplica el tope del plan free, que **no es diario**: son `FREE_LIFETIME_QUOTA` = 25 mensajes en total |
| Otro contenido generado por el usuario | **Sí** | **Sí, solo los títulos** (OpenRouter) | Opcional | Funciones de la app | Sí | Sí | Texto libre que se **recopila**: `title` y `description` de `transactions/`, `name`/`supplier`/`code` de `inventory/`, `name` de `fixedExpenses/`, y el `comment` de `aiReports/`. Lo único que se **comparte** es el `title` de las últimas 10 transacciones (`transactionsSection()`), que es justo el campo donde la gente escribe el nombre de un cliente: la política de privacidad lo advierte expresamente. Ver el §1.6 |
| Historial de búsqueda en la app | No | — | — | — | — | — | No hay buscador que persista nada. |
| Apps instaladas | No | — | — | — | — | — | — |
| Otras acciones | No | — | — | — | — | — | — |

### 1.5 Tipos que NO se recopilan

Ubicación (aproximada o exacta), salud y forma física, fotos y vídeos, archivos y
documentos, audio, contactos, calendario, historial de navegación web,
rendimiento de la app (diagnósticos, bloqueos), identificadores de dispositivo e
identificador de publicidad.

**Verificado, no supuesto.** `pubspec.yaml` no declara `firebase_analytics`,
`firebase_crashlytics`, `firebase_messaging` ni ningún SDK de atribución o
publicidad. El manifiesto de release no pide ningún permiso de runtime (solo
`INTERNET` y `ACCESS_NETWORK_STATE`, que no son de runtime). No hay `MobileAds`,
`AppsFlyer`, `Facebook SDK` ni equivalente.

### 1.6 Qué cruza exactamente hacia OpenRouter, y qué no

Las tres tablas de arriba decían «Sí» en la columna *Comp.* para tipos enteros, y
en dos filas eso **declaraba de más**: daba por compartidos con el proveedor del
modelo los importes de los gastos fijos y el detalle del inventario, que no
salen. Declarar de más no infringe ninguna política —el riesgo está siempre en la
dirección contraria— pero sí hace falsa la política de privacidad, que promete
decir «campo por campo» lo que viaja. Así que aquí queda la lista exacta, leída
de `functions/src/prompt.ts` y `functions/src/chat.ts`.

**Sí sale, en cada mensaje al asistente:**

| Qué | De dónde |
|---|---|
| Nombre, nombre del negocio, rubro, moneda, meta mensual y plan | `profileSection()` |
| Sueldo mensual deseado, horas disponibles y valor hora calculado | `hourlyRateSection()` |
| Totales del último mes con movimientos: ingresos, **comisiones de los medios de pago**, ingresos netos de esas comisiones, gastos y número de movimientos | `monthSection()`, a partir de `months/{yyyy-MM}` |
| Las **últimas 10** transacciones (`RECENT_TRANSACTIONS_LIMIT`), cada una con fecha, tipo, categoría, título, monto y, cuando los tiene, `docType` y `platformFee` | `transactionsSection()` |
| Cuántos productos y cuántos materiales hay en el inventario: **dos números y nada más** | `inventorySection()`, que recibe un `InventoryCounts { products, materials }` calculado con `count()` en `chat.ts` |
| Los **últimos 6** mensajes de la conversación (`HISTORY_LIMIT`) | `chat.ts` |

**No sale, aunque la app lo guarde:**

| Qué | Por qué se puede afirmar |
|---|---|
| El correo y el `uid` | No aparecen en ninguna sección de `prompt.ts` |
| **Los gastos fijos**, ni sus nombres ni sus importes | `fixedExpenses` no se menciona en `chat.ts` ni en `prompt.ts`: no se lee para el prompt |
| **El detalle del inventario**: nombres, precios, stock, unidades, proveedores y códigos | `chat.ts` solo hace dos `count()` sobre `inventory`; el tipo `InventoryCounts` tiene exactamente dos campos numéricos, así que no hay por dónde colar un nombre |
| La transacción número 11 hacia atrás, y los meses anteriores al último con movimientos | Los dos límites están arriba |
| Los reportes de `aiReports/` | Nadie los lee para construir el prompt |

**Qué hacer con esto en el formulario.** Las casillas de Play se marcan por
**tipo de dato**, no por campo, y basta con que un elemento del tipo se comparta
para que el tipo esté compartido. Así que las casillas **no cambian**: *Otra
información financiera* y *Otro contenido generado por el usuario* siguen
marcadas como compartidas. Lo que cambia es que ahora la columna dice la verdad
sobre qué parte, y la política de privacidad puede sostener su «sin excepción».

---

## 2. Las tres decisiones discutibles, documentadas

### 2.1 Por qué *Historial de compras* se responde «No»

Google define *Historial de compras* como «información sobre compras o
transacciones que un usuario ha realizado». Leído literalmente, el libro de
ingresos y gastos encaja.

Lo respondo **No** por dos razones. Primera: la subcategoría existe para el
historial de compras **que la app observa** —compras dentro de la app, pedidos,
pagos procesados—, y Págate-IA no observa ninguna: no hay pasarela y las entradas
son anotaciones manuales del usuario sobre operaciones ocurridas fuera. Segunda:
todo ese contenido ya queda declarado, y declarado como **compartido**, bajo
*Otra información financiera*, así que no se oculta nada.

**Si el dueño prefiere marcarla también, márquela.** Añadir una casilla que ya
está cubierta por otra no causa ningún problema; el riesgo está siempre en la
dirección contraria. Es una decisión de producto, y queda anotada como tal.

### 2.2 Por qué la lista de espera de la web no entra en el formulario

`functions/src/waitlist.ts` guarda nombre, correo y origen en
`waitlist/{id}`, y su limitador por IP (`hitsByIp`) usa la IP del cliente para
acotar el
número de inscripciones por hora.

Eso **no se declara en Seguridad de los datos**, porque el formulario cubre los
datos que recopila *la aplicación*, y esa inscripción ocurre en un formulario web
de la landing: la app Android no tiene ninguna pantalla que llame a `waitlist`.
Sí está declarado en la política de privacidad (§2.5), que es donde corresponde.

La IP, además, se guarda solo en memoria de la instancia de la función
(`const hitsByIp = new Map<string, number[]>()` en `waitlist.ts`) y nunca se
escribe junto a la inscripción, lo que la acerca a la excepción de procesamiento
efímero de Google.

### 2.3 Por qué App Check no se declara

En release, App Check usa Play Integrity en Android y reCAPTCHA v3 en web. Los
datos que recoge Play Integrity los trata Google como parte de los servicios de
la plataforma, y Google no exige declarar en Seguridad de los datos lo que
recopilan sus propios servicios de Play. reCAPTCHA v3 solo corre en la versión
web, que no es el binario de la ficha.

---

## 3. Sección de prácticas de seguridad

| Pregunta del formulario | Respuesta | Justificación |
|---|---|---|
| ¿Los datos se cifran en tránsito? | **Sí** | Firestore y los callables van por TLS (SDK de Firebase). La llamada a OpenRouter es HTTPS (la constante `ENDPOINT` de `openrouter.ts` es `https://openrouter.ai/...`). No hay ningún `http://` en producción. |
| ¿Los usuarios pueden solicitar que se eliminen sus datos? | **Sí** | Las dos vías que Play pide, y las dos existen: la URL pública `/eliminar-cuenta/` con el procedimiento y el plazo, y el borrado **dentro de la app** en *Perfil → Configuración → Eliminar cuenta*, que ejecuta el callable `deleteAccount`. El detalle, con archivos, en el **§4.2**. Lo que falta es publicar la landing para que la URL deje de dar 404. |
| ¿Los datos se eliminan automáticamente? | **No** | Se conservan mientras exista la cuenta. No hay caducidad automática. |
| ¿La app se sometió a una revisión de seguridad independiente? | **No** | No se ha hecho ninguna. No marcar la casilla sin un informe que respalde. |
| ¿Compromiso con la Política de Familias? | **No aplica** | La app no se dirige a menores y así lo dicen los términos. |
| ¿Hay recopilación efímera que no se declara? | Sí, una | La IP de la landing (§2.2), que además no es de la app. |

### URLs que hay que pegar en Play Console

| Campo de Play Console | Valor |
|---|---|
| Ficha → Política de Privacidad | `https://francogalaz.github.io/Pagate-ia/landing-page/privacidad/` |
| Seguridad de los datos → Eliminación de cuenta | `https://francogalaz.github.io/Pagate-ia/landing-page/eliminar-cuenta/` |
| Términos (opcional, enlazado desde la ficha) | `https://francogalaz.github.io/Pagate-ia/landing-page/terminos/` |

Las tres rutas salen del `base` de `landing/vite.config.ts`
(`/Pagate-ia/landing-page/`). Si la landing se muda a Firebase Hosting, el
prefijo cambia y hay que actualizar `base`, las tres URLs de arriba y las de la
ficha. **Antes de pegarlas hay que confirmar que están vivas**: el build
publicado en `landing-page/` se regenera con el workflow, no a mano, y hoy ese
workflow solo dispara en `main`.

---

## 4. Marcadores sin rellenar y bloqueos

### 4.1 Marcadores que el dueño tiene que reemplazar

> **El inventario operativo —con número de línea, qué decidir y qué ve el
> visitante mientras falte— está en `docs/FICHA-PLAY.md §8`.** Esta sección queda
> como el contexto de por qué el formulario de Seguridad de los datos depende de
> ellos; la lista de referencia es la de allí.

Viven todos en `landing/src/content/legal-meta.ts`, en un solo sitio a propósito.
**Ya no se imprimen entre corchetes**: cada página tiene dos redacciones y elige
la que corresponde al estado del dato (`esMarcador()` en `legal-meta.ts`), porque
una política publicada con corchetes visibles es motivo de rechazo. Lo que eso
cierra es el rechazo por plantilla sin revisar; **no** rellena el dato, y sin los
cinco la política identifica al responsable por descripción y no por nombre.

| Constante | Marcador | Qué hay que decidir |
|---|---|---|
| `RESPONSIBLE.legalName` | `[RAZÓN SOCIAL O NOMBRE COMPLETO DEL RESPONSABLE]` | Si se publica como persona natural o como sociedad. |
| `RESPONSIBLE.taxId` | `[RUT DEL RESPONSABLE]` | El RUT que corresponda a la decisión anterior. |
| `RESPONSIBLE.address` | `[DOMICILIO: calle, número, comuna, región, Chile]` | Domicilio para notificaciones. |
| `CONTACT.privacy` | `[CORREO DE CONTACTO DE PRIVACIDAD]` | Buzón atendido. Es el que recibirá las solicitudes de borrado. |
| `CONTACT.support` | `[CORREO DE SOPORTE DECLARADO EN GOOGLE PLAY]` | Debe ser **el mismo** que se declare en la ficha. |

Sobre el correo: **la app ya no muestra ninguno.** La pantalla de Ayuda son solo
preguntas frecuentes. El `soporte@pagate-ia.com` que mostraba antes usa un
dominio que el dueño no controla, así que **no lo reutilices** si reaparece en un
documento viejo. Lo más barato es el correo de la cuenta de desarrollador de
Google Play.

**Consecuencia para este formulario.** Play pide, en *Seguridad de los datos →
Eliminación de cuenta*, una URL pública con el procedimiento de borrado. Esa URL
existe y describe el canal, pero mientras `CONTACT.privacy` siga sin rellenar la
página **no renderiza el botón `mailto:`** —un `mailto:[CORREO…]` es un enlace
roto— y deriva al correo de contacto del desarrollador que Play publica en la
ficha. Funciona, pero **el camino bueno es rellenar el buzón**: así la solicitud
llega a una dirección que el dueño puede filtrar y archivar.

### 4.2 El borrado de datos: ya se sostiene, y así se comprueba

Esta sección decía que dos filas de la tabla del §1 afirmaban algo que el código
no cumplía. **Ya lo cumple**, y queda escrito con el archivo al lado, porque una
celda «Sí» en este formulario que no se pueda señalar en el código es exactamente
el hallazgo por el que se retira una ficha:

| Lo que pide Play | Qué hay hoy |
|---|---|
| Una **URL pública** con el procedimiento de borrado | La genera `landing/` en `/eliminar-cuenta/`. **Sigue respondiendo 404** hasta publicar la landing: es el punto 4 del §0 de `docs/FICHA-PLAY.md` |
| Un **camino dentro de la app** (lo exige la *Política de eliminación de cuentas y datos*, no este formulario) | *Perfil → Configuración → Eliminar cuenta*: `configuracion_screen.dart` abre `EliminarCuentaScreen`, que llama al callable `deleteAccount` a través de `lib/core/services/account_service.dart` |
| Que el borrado **alcance de verdad a todo** | `functions/src/account.ts` → `deleteUserData()` hace `recursiveDelete(users/{uid})`, que recorre `inventory`, `transactions`, `fixedExpenses`, `months`, `meta`, `aiReports` y `conversations/{id}/messages` **descubriendo las subcolecciones en tiempo de ejecución**: una colección nueva queda cubierta sin tocar ese archivo. Después **verifica** que no quedó nada y devuelve las rutas sobrantes, porque `recursiveDelete` usa un `BulkWriter` que resuelve sin lanzar aunque algún lote se quede atrás. Luego borra la cuenta de Auth con `getAuth().deleteUser(uid)` |
| Que el cliente no pueda dejar datos huérfanos | `firestore.rules` pone `allow delete: if false` en `users/{uid}`, con el motivo escrito al lado: borrar solo el documento padre dejaría `inventory`, `transactions`, `fixedExpenses`, `months`, `conversations` y `meta` colgando sin dueño y sin forma de volver a alcanzarlas. El único camino es el callable |

**Consecuencia para el formulario:** la celda *Borr.* de la fila **Mensajes** ya
no es un «Sí» prestado. `conversations/` y `months/` siguen siendo inescribibles
para el cliente (`allow write: if false`, que es lo correcto: los escribe el
backend), pero el borrado **de cuenta** los alcanza en servidor.

**De aquel bloqueo solo queda la URL**, y es de publicación, no de código:
mientras `/eliminar-cuenta/` responda 404 no se puede pegar en *Seguridad de los
datos → Eliminación de cuenta*, que es un campo obligatorio.

### 4.3 Dos cosas que la tabla del §1 todavía no nombraba

El contrato C-3 y el aviso de IA añadieron campos y una colección después de
escribir el §1. Ninguno cambia una casilla del formulario, pero la tabla tiene
que nombrarlos o deja de describir la app:

| Qué | Dónde vive | Cómo se declara |
|---|---|---|
| `docType` y `platformFee` de una transacción: con qué documento se respaldó un ingreso y cuánto se quedó el medio de pago | `users/{uid}/transactions/{id}`, los dos **opcionales** | Dentro de **Otra información financiera**, que ya está marcada como recopilada y **compartida**. No es un tipo nuevo: es más de lo mismo, y llega al asistente por el mismo camino que el resto del mes |
| Los reportes de respuestas de la IA: `reason`, un `comment` libre y `reportedText` (hasta 2.000 caracteres de la respuesta reportada) | `users/{uid}/aiReports/{id}`, escrito por `ai_provider.dart` | Dentro de **Otro contenido generado por el usuario** —el comentario lo escribe la persona— y, por `reportedText`, de **Mensajes**. **No se comparte:** no sale del proyecto, no va a OpenRouter, y `firestore.rules` solo permite `create` (ni `update` ni `delete`), así que es un registro de solo añadir. Lo borra `deleteAccount` con el resto del árbol |

### 4.4 Lo que ya no bloquea, y lo que sí

**Ya no bloquea.** Comprobado en el código de hoy, 6 de octubre de 2026, no
heredado de la redacción anterior:

- El permiso **`INTERNET` sí está** en
  `android/app/src/main/AndroidManifest.xml` (línea 10), junto a
  `ACCESS_NETWORK_STATE`. Ya no es verdad que el binario de Play saldría sin red.
- La app **sí avisa** de que responde una IA: el aviso va fijo bajo la cabecera
  del asistente (`ia_tab.dart`), no escondido en un menú ni en un diálogo de
  primera vez. Y **sí tiene mecanismo de reporte**: el botón «Reportar respuesta»
  de cada mensaje, que escribe en `aiReports`. Eran los dos requisitos de la
  política de Play para apps con IA generativa.

**Sigue bloqueando:**

- `ENFORCE_APP_CHECK=false` en `functions/.env`, que **está versionado**. Así,
  `chat` queda abierto a cualquier cuenta autoregistrada y la factura es del
  dueño. Hay que ponerlo en `true` **después** de registrar las dos apps en App
  Check y comprobar que reportan tokens válidos, no antes: en el orden inverso la
  app deja de responder. La secuencia está en el *Checklist de configuración en
  consola* del `README.md`.
- El release se firma con el keystore de **depuración** mientras no exista
  `android/key.properties`, que hoy no existe. Punto 7 del §0 de
  `docs/FICHA-PLAY.md`.
- **Y el bloqueo mayor, que no estaba escrito en ninguna parte:** el proyecto de
  producción `pagate-17211` no tiene Authentication encendido, no tiene base de
  datos de Firestore creada y no tiene funciones ni reglas desplegadas.
  Comprobado contra las APIs reales; las sondas y sus respuestas literales están
  en el **§0.0 de `docs/FICHA-PLAY.md`**. Hasta que eso cambie, este formulario
  describiría una app que no puede ni registrar al revisor: todas las respuestas
  de arriba son correctas sobre el código, y ninguna es comprobable en
  producción.
