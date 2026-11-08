# Reglas de trabajo

## 1. Pensar antes de codificar
- Antes de escribir código, lista los supuestos que estás haciendo.
- Si el requerimiento es ambiguo, pregunta. No elijas una interpretación en silencio.
- Si ves un enfoque más simple que el que pedí, dilo y espera mi respuesta.

## 2. Simplicidad primero
- Escribe el mínimo código que resuelva el problema. Nada especulativo.
- Sin abstracciones, clases ni configurabilidad que no se hayan pedido.
- Test: ¿un ingeniero senior diría que está sobrecomplicado? Si sí, simplifica.

## 3. Cambios quirúrgicos
- Toca solo lo necesario para la tarea.
- No refactorices, renombres ni reformatees código que no está relacionado.
- Cada línea cambiada debe tener relación directa con mi pedido.
- Si ves otros problemas, menciónalos al final; no los arregles.

## 4. Ejecución guiada por objetivos
- Convierte cada tarea en un objetivo verificable:
  - "Arreglar bug" → escribe un test que lo reproduzca y luego hazlo pasar.
  - "Agregar validación" → tests para entradas inválidas y luego hacerlos pasar.
  - "Optimizar" → la versión simple queda como referencia; la versión optimizada debe dar los mismos resultados.
- En tareas de varios pasos: plan corto, con una verificación por paso.
- Itera solo (corre los tests, lee los errores, corrige) hasta que todo pase. Solo entonces reporta.
- Al terminar: qué cambiaste, cómo lo verificaste y qué quedó pendiente.

# Contexto del proyecto

Estado al 2026-11-08. Las fuentes de verdad técnicas siguen siendo
`docs/ARQUITECTURA.md` (contrato) y `AGENTS.md` (cómo trabajar en el repo).

## Prioridad

Publicar en Google Play. Lo que no bloquee eso queda para después.

## Decisiones tomadas

- **Cuota del asistente:** manda el código. Plan `free` 25 mensajes **de por
  vida**, plan `pro` 300 al día (`functions/src/quota.ts`).
- **Flujo de registro:** registro → configuración del taller → dashboard. El
  valor hora es opcional y se configura desde Inicio.
- **App web:** fuera de alcance por ahora. El README ya no enlaza a
  `pagate-17211.web.app`.
- **iOS:** fuera de alcance.
- **Tema:** claro único; `app_shell.dart` fija `themeMode: ThemeMode.light`.
- **`get()` en el chat:** `AiProvider._loadLatestConversation` puede quedarse
  con `get()` porque es una carga única.
- **`.env` versionados:** `functions/.env` y `landing/.env.production` se
  versionan a propósito y no contienen secretos.
- **Saludo del asistente:** se cambia para que no prometa más de lo que sabe
  (no se amplía el contexto del prompt).
- **Ramas `int/*`:** se mantienen por ahora.
- **Inicio de sesión:** Google solo existe en web (`isAvailable => kIsWeb`);
  en Android todas las cuentas son de correo y contraseña.
- **Correo verificado:** `chat` y `scanReceipt` lo exigen antes de reservar
  cuota. Sin verificar, el lector de boletas se queda con la lista local.
- **Historial del asistente:** se borra con `deleteChatHistory`; no toca la
  cuota ni `aiReports`.

## Estado

- **Consola de Firebase:** sin cambios desde el 2026-10-06 (Authentication sin
  habilitar, sin base de Firestore, sin plan Blaze, sin clave de OpenRouter,
  nada desplegado). Lo que falta en consola está en `docs/PLAN.md` y
  `docs/CHECKLIST-PUBLICACION.md`.
- **Git:** `arquitectura-segura` y `docs/reglas-trabajo` están en GitHub. El PR
  `docs/reglas-trabajo` → `arquitectura-segura` está por abrir (`gh` sin
  sesión). `origin/main` solo recibió este CLAUDE.md (PR #1).
- **Tests (2026-11-08, rama `docs/reglas-trabajo`, commit `9be9618`):**
  `flutter analyze` sin problemas; `flutter test` 532 pasan; functions `lint`
  y `build` OK y `npm --prefix functions test` 316 pasan (12 archivos, con los
  de reglas); landing `lint`, 72 tests y `build` OK. El test de integración
  `integration_test/cierre_sesion_test.dart` pasó en el emulador antes de la
  verificación de correo; no se volvió a correr después.

## Hallazgos de la auditoría abiertos

Revisados contra el código el 2026-11-08. No es un recuento de los 81 de
`docs/AUDITORIA-2026-09-29.md` uno por uno: es la lista priorizada.

Bloquean la publicación (todos son de consola o del dueño, no de código):

- Proyecto de Firebase vacío: Authentication, Firestore, plan Blaze, despliegue.
- Keystore de subida definitivo (`key.properties`).
- Publicar la landing (privacidad, términos, eliminar cuenta).
- Clave de OpenRouter nueva y revocar la antigua.
- Datos del responsable y correos reales: `landing/src/content/legal-meta.ts`
  sigue con marcadores (`[RUT DEL RESPONSABLE]`, `[CORREO DE SOPORTE…]`).
- Formulario de Seguridad de los datos en Play Console, declarando OpenRouter
  (el texto está en `docs/SEGURIDAD-DATOS-PLAY.md`).
- Confirmar `com.pagate.apppagate` antes de la primera subida.

Antes de publicar:

- App Check: el código está listo; activar `ENFORCE_APP_CHECK` es la tarea 4.
- Plantilla del correo de verificación en español (consola, paso en el
  checklist).
- Probar en un teléfono: el flujo de verificación de correo, contraste WCAG,
  desbordes con letra grande y peso de los gráficos de Inicio y Finanzas.

Después:

- CI: no construye Android, `deploy-web` no corre tests, actions sin pin a SHA,
  Flutter en `channel: beta` sin versión fija, `dev.sh` apunta al proyecto
  real, sin pre-commit.
- Higiene: `catch (_)` sin registro en `ai_provider.dart` (líneas 203 y 314),
  cast sin comprobar nulos en `HourlyRateModel.fromJson`, `validHourlyRate`
  acepta un mapa parcial, `describeFirebaseError` todavía muestra el error
  crudo cuando no es de Firebase.
- Producto: compra del plan Pro, stock decimal (decisión pendiente en
  `docs/ARQUITECTURA.md`). Web e iOS fuera de alcance.

Cerrados en `docs/reglas-trabajo`: `allowBackup` y reglas de extracción,
caché de Firestore al cerrar sesión, borrar historial del asistente, aviso de
privacidad en la lista de espera, Material en es_CL, error crudo en el arranque
y en `SessionErrorView`, verificación de correo, mensaje genérico en
`describeFirebaseError` y log único en `AuthGate`.

## Tareas de código

Hechas:

1. [x] Quitar iOS de `lecturaDeBoletasDisponible`
   (`receipt_scan_availability.dart`) — commit `212abc5`.
2. [x] Borrar los `get()` sin uso (`getProfile()`, `getHourlyRate()`,
   `hasConfiguration()`) de datasources, interfaces y fakes — commit `5a5b346`.
3. [x] Cambiar el saludo del asistente (`_welcomeText` en `ai_provider.dart`)
   para que no prometa más de lo que ve — commit `2506b47`.

Pendiente, bloqueada por consola:

4. [ ] Activar `ENFORCE_APP_CHECK` (`functions/.env`) después de validar Play
   Integrity. Es el último paso de `docs/CHECKLIST-PUBLICACION.md`; no antes.
