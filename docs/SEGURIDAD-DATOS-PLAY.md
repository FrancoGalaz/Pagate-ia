# Seguridad de los datos — respuestas para Google Play Console

Tarea **P-09**. Este documento es la hoja de respuestas del formulario *Play
Console → Contenido de la aplicación → Seguridad de los datos*, tipo de dato por
tipo de dato.

No es un borrador orientativo: cada fila está derivada de código verificado, con
el archivo que lo justifica. Si cambia el modelo de datos, cambia este documento
y se vuelve a enviar el formulario. Una declaración que no coincida con lo que la
app hace es causa de retirada de la ficha, y Google compara la declaración con el
comportamiento real del binario.

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
servidor**. Eso es literalmente lo que hace `functions/src/openrouter.ts:49-64`:
un `POST` desde nuestra Cloud Function a `https://openrouter.ai/api/v1/chat/completions`.

Hay cuatro excepciones que eximen de declararlo. Las descarto una por una:

| Excepción | ¿Aplica? | Por qué |
|---|---|---|
| **Proveedor de servicios** que procesa por cuenta del desarrollador | **No, hoy no** | Ver el razonamiento abajo. Es la única candidata real. |
| Fines legales (obligación legal) | No | No hay obligación legal; es el funcionamiento normal del producto. |
| Acción iniciada por el usuario, donde el usuario espera razonablemente que se comparta | No | El usuario escribe un mensaje al asistente. No elige el destino, no se le nombra el tercero y hoy la app no le dice nada: el envío del perfil, los totales del mes y las últimas 10 transacciones ocurre sin que lo pida ni lo vea. |
| Datos totalmente anonimizados | No | Va el nombre del usuario (`prompt.ts:82`), el del negocio (`:83`) y los títulos libres de sus transacciones (`:125-131`). Es lo contrario de anónimo. |

**Por qué la excepción de proveedor de servicios no se sostiene hoy.** Para
invocarla, el tercero tiene que tratar los datos únicamente por cuenta del
desarrollador y según sus instrucciones. Tres hechos del código lo impiden:

1. `functions/src/openrouter.ts:51-56` **no envía ninguna cabecera de política de
   datos**. Rige el ajuste por defecto de la cuenta de OpenRouter, que puede
   permitir registro y entrenamiento. No hay instrucción nuestra que lo limite.
2. OpenRouter **es un enrutador, no el modelo**. `functions/src/config.ts:15`
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
| Nombre | **Sí** | **Sí** (OpenRouter) | Obligatorio | Funciones de la app | Sí | Sí (ver §3) | `users/{uid}.name`; `prompt.ts:82` |
| Dirección de correo electrónico | **Sí** | No | Obligatorio | Gestión de la cuenta; funciones de la app | Sí | Sí | Firebase Auth; `firebase_auth_service.dart:36-49` |
| Identificadores de usuario | **Sí** | No | Obligatorio | Gestión de la cuenta; funciones de la app | Sí | Sí | El `uid` de Firebase Auth. No se envía a OpenRouter. |
| Otra información (nombre y rubro del negocio, moneda) | **Sí** | **Sí** (OpenRouter) | Obligatorio | Funciones de la app; personalización | Sí | Sí | `users/{uid}`; `prompt.ts:83-85` |
| Número de teléfono | No | — | — | — | — | — | No se pide en ninguna pantalla. |
| Dirección física | No | — | — | — | — | — | — |
| Raza, etnia, orientación sexual, creencias políticas o religiosas | No | — | — | — | — | — | — |

*Obligatorio en las cuatro primeras filas porque
`setup_inicial_screen.dart:61-79` no deja pasar el onboarding sin nombre, nombre
del negocio y tipo de negocio.*

### 1.2 Información financiera

| Tipo de dato | Rec. | Comp. | Oblig. | Finalidad | Trán. | Borr. | Fuente en el código |
|---|---|---|---|---|---|---|---|
| **Otra información financiera** | **Sí** | **Sí** (OpenRouter) | Obligatorio | Funciones de la app | Sí | Sí | Meta mensual (`users/{uid}.monthlyGoal`), sueldo objetivo + horas + valor hora (`users/{uid}.hourlyRate`), montos de `transactions/`, `fixedExpenses/`, precios de `inventory/`, agregados de `months/`; sale en `prompt.ts:86-88, 99-101, 112-116, 125-131` |
| Información de pago del usuario | No | — | — | — | — | — | La app no cobra, no guarda tarjetas y no tiene pasarela. `functions/src/index.ts` solo exporta `chat`, `onTransactionWritten` y `waitlist`. |
| Historial de compras | **No** — decisión argumentada | — | — | — | — | — | Ver §2.1. |
| Puntuación de crédito | No | — | — | — | — | — | — |

*Obligatorio porque el onboarding exige una meta mensual mayor que cero
(`setup_inicial_screen.dart:77-80`). Las transacciones y el inventario son
opcionales, pero el formulario se responde por tipo de dato y basta con que un
elemento del tipo sea obligatorio.*

### 1.3 Mensajes

| Tipo de dato | Rec. | Comp. | Oblig. | Finalidad | Trán. | Borr. | Fuente en el código |
|---|---|---|---|---|---|---|---|
| Otros mensajes en la app | **Sí** | **Sí** (OpenRouter) | Opcional | Funciones de la app | Sí | Sí | `users/{uid}/conversations/{id}/messages`, escritos por `chat.ts:209` y `:257`; se reenvían los últimos 20 (`chat.ts:24, :218, :232-239`) |
| Correos electrónicos | No | — | — | — | — | — | — |
| SMS o MMS | No | — | — | — | — | — | — |

*Opcional: la app funciona completa sin tocar el asistente.*

### 1.4 Actividad en la aplicación

| Tipo de dato | Rec. | Comp. | Oblig. | Finalidad | Trán. | Borr. | Fuente en el código |
|---|---|---|---|---|---|---|---|
| Interacciones con la app | **Sí** | No | Opcional | Funciones de la app; prevención de fraude y abuso | Sí | Sí | `users/{uid}/meta/usage`: `{dayKey, chatCountDay}`, escrito por `chat.ts` en la transacción de cuota |
| Otro contenido generado por el usuario | **Sí** | **Sí** (OpenRouter) | Opcional | Funciones de la app | Sí | Sí | Texto libre: `title` y `description` de `transactions/`, `name`/`supplier`/`code` de `inventory/`, `name` de `fixedExpenses/`. Los títulos salen en `prompt.ts:125-131` |
| Historial de búsqueda en la app | No | — | — | — | — | — | No hay buscador que persista nada. |
| Apps instaladas | No | — | — | — | — | — | — |
| Otras acciones | No | — | — | — | — | — | — |

### 1.5 Tipos que NO se recopilan

Ubicación (aproximada o exacta), salud y forma física, fotos y vídeos, archivos y
documentos, audio, contactos, calendario, historial de navegación web,
rendimiento de la app (diagnósticos, bloqueos), identificadores de dispositivo e
identificador de publicidad.

**Verificado, no supuesto.** `pubspec.yaml:10-26` no declara
`firebase_analytics`, `firebase_crashlytics`, `firebase_messaging` ni ningún SDK
de atribución o publicidad. El manifiesto de release no pide ningún permiso de
runtime. No hay `MobileAds`, `AppsFlyer`, `Facebook SDK` ni equivalente.

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

`functions/src/waitlist.ts:148-150` guarda nombre, correo y origen en
`waitlist/{id}`, y `waitlist.ts:26-42` usa la IP del cliente para limitar el
número de inscripciones por hora.

Eso **no se declara en Seguridad de los datos**, porque el formulario cubre los
datos que recopila *la aplicación*, y esa inscripción ocurre en un formulario web
de la landing: la app Android no tiene ninguna pantalla que llame a `waitlist`.
Sí está declarado en la política de privacidad (§2.5), que es donde corresponde.

La IP, además, se guarda solo en memoria de la instancia de la función
(`const hitsByIp = new Map<string, number[]>()`, `waitlist.ts:24`) y nunca se
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
| ¿Los datos se cifran en tránsito? | **Sí** | Firestore y los callables van por TLS (SDK de Firebase). La llamada a OpenRouter es HTTPS (`openrouter.ts:38`: `https://openrouter.ai/...`). No hay ningún `http://` en producción. |
| ¿Los usuarios pueden solicitar que se eliminen sus datos? | **Sí** | Existe la URL pública `/eliminar-cuenta/` con el procedimiento y el plazo. Ver el bloqueo de §4. |
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

Viven todos en `landing/src/content/legal-meta.ts`, en un solo sitio a propósito.
Las tres páginas legales los muestran tal cual, entre corchetes. **Una política
de privacidad publicada con corchetes visibles es motivo de rechazo**, así que
esto es lo primero que hay que cerrar.

| Constante | Marcador | Qué hay que decidir |
|---|---|---|
| `RESPONSIBLE.legalName` | `[RAZÓN SOCIAL O NOMBRE COMPLETO DEL RESPONSABLE]` | Si se publica como persona natural o como sociedad. |
| `RESPONSIBLE.taxId` | `[RUT DEL RESPONSABLE]` | El RUT que corresponda a la decisión anterior. |
| `RESPONSIBLE.address` | `[DOMICILIO: calle, número, comuna, región, Chile]` | Domicilio para notificaciones. |
| `CONTACT.privacy` | `[CORREO DE CONTACTO DE PRIVACIDAD]` | Buzón atendido. Es el que recibirá las solicitudes de borrado. |
| `CONTACT.support` | `[CORREO DE SOPORTE DECLARADO EN GOOGLE PLAY]` | Debe ser **el mismo** que se declare en la ficha. |

Sobre el correo: `ayuda_screen.dart:235` muestra hoy `soporte@pagate-ia.com`, y
el dominio `pagate-ia.com` no aparece en ningún sitio del repo ni lo controla el
dueño. **No lo reutilices.** Lo más barato es el correo de la cuenta de
desarrollador de Google Play.

### 4.2 Lo que bloquea enviar el formulario con estas respuestas

Dos filas de la tabla de §1 afirman hoy algo que el código todavía no cumple, y
las dos dependen de trabajo que está en otro carril:

1. **«El usuario puede solicitar la eliminación» = Sí** se sostiene por la URL
   pública que crea este carril, y eso es lo que pregunta el formulario. Pero la
   *Política de eliminación de cuentas y datos* de Play exige **además** un
   camino dentro de la app, y hoy no existe: el menú del perfil termina en
   «Cerrar Sesión» (`perfil_tab.dart:185`) y `firebase_auth_service.dart` no
   expone `delete()`. Depende de **S1-07** (callable `deleteAccount` con
   `recursiveDelete` + `auth().deleteUser`) y de denegar el `delete` directo en
   `firestore.rules:98`, que hoy permite borrar `users/{uid}` dejando huérfanas
   todas las subcolecciones.
2. **El borrado de `conversations/` y `months/`.** `firestore.rules:165-178` fija
   `allow write: if false`: el cliente no puede borrarlos por ningún medio, y
   «Nueva conversación» en `ia_tab.dart` solo vacía la lista en memoria. Hasta
   que `deleteAccount` los borre en servidor, la respuesta honesta para el tipo
   *Mensajes* sería «No». La tabla dice «Sí» porque la URL pública cubre la
   solicitud manual y el borrado lo ejecutaría el dueño; **si S1-07 no entra
   antes de publicar, cambia esa celda a No**.

### 4.3 Otros bloqueos de este formulario que no son de este carril

- `android/app/src/main/AndroidManifest.xml` **no declara el permiso
  `INTERNET`** (solo lo declaran los manifiestos de `debug` y `profile`). En el
  binario de Play la app no tendría red: el revisor recibiría una app muerta.
- El release se firma con el keystore de depuración
  (`android/app/build.gradle.kts:38`), así que el AAB ni se sube.
- `ENFORCE_APP_CHECK=false` en `functions/.env`: `chat` queda abierto a cualquier
  cuenta autoregistrada y se factura al dueño.
- La app no avisa dentro del chat de qué contexto se envía ni a quién, y no tiene
  mecanismo de reporte de contenido generado por IA, que la política de Play para
  apps con IA generativa exige. Ninguna declaración de este formulario arregla
  eso.
