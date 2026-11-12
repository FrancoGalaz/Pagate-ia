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

Estado al 2026-11-12. Las fuentes de verdad técnicas siguen siendo
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
- **Rediseño (variante A):** capas 1 a 3 hechas en `docs/reglas-trabajo`
  (tema, widgets compartidos, diálogos, Inicio, Registrar, Finanzas e
  Inventario, cada una con sus retoques). Falta la capa 4. Ver
  «Rediseño (variante A)» y «Pendiente».
- **Git:** la rama de trabajo es `docs/reglas-trabajo`. PR #1 (este CLAUDE.md
  → `main`) y PR #2 (`docs/reglas-trabajo` → `arquitectura-segura`)
  integrados. PR #3 (`arquitectura-segura` → `main`) abierto.
- **Tests (2026-11-12, rama `docs/reglas-trabajo`, commit `550611d`):**
  `flutter analyze` sin problemas; `flutter test` 579 pasan; functions `lint`
  y `build` OK y `npm --prefix functions test` 316 pasan (12 archivos, con los
  de reglas); landing `lint`, 72 tests y `build` OK. El test de integración
  `integration_test/cierre_sesion_test.dart` pasa en el emulador después de la
  verificación de correo. `scripts/smoke-prod.sh` se probó contra los
  emuladores y un build local de la landing; contra producción falla porque
  no hay nada desplegado.

## Pendiente

En este orden:

1. Prueba del dueño en su teléfono (APK de debug contra los emuladores, con
   `EMULATOR_HOST=127.0.0.1` y `adb reverse`). No se empieza la capa 4 antes.
2. Capa 4 del rediseño: Configuración, Perfil, Bienvenida, Login, Onboarding,
   Asistente, Detalle de ítem y Ayuda, una pantalla por vez con el ciclo de
   abajo.
3. Merge del PR #3 (`arquitectura-segura` → `main`) si sigue abierto.

## Rediseño (variante A)

Estructura tomada de la app Cabal (cabecera oscura, tarjetas con sombra,
selector segmentado, cifras en 800) con paleta propia: **A · Greda y carbón**.
Fuente de verdad: `docs/diseno/widgets.md` y el código. `docs/DISENO-v2.md` y
`docs/diseno/variantes-cabal.html` son históricos; si no coinciden con el
código, manda el código. Los «#N» de `widgets.md` son capturas de Cabal en
`docs/referencias/cabal/`, locales y fuera de git a propósito.

Capas: 1 tema y tokens, 2 widgets compartidos, 3 pantallas principales
(Inicio, Registrar, Finanzas, Inventario: hechas), 4 el resto (pendiente).

Color:

- Acción `#B04A26` (greda): solo la acción principal. **Nunca** directo sobre
  la cabecera oscura (2,7:1); los botones de Inicio van en la tarjeta blanca.
- Oscuro `#2E2622` (carbón): títulos, íconos, pestaña activa, secundarios y
  gastos. Fondo `#FBF6F2`.
- Ingreso en verde `#1D6B45`. Gasto en el oscuro con «−», sin color propio.
- Carmesí `#A3213F`: solo alertas («Sin stock», bajo el mínimo) y acciones
  destructivas.
- Contraste AA en todo par y 7:1 para el oscuro. `python
  docs/diseno/contraste.py` sale con 1 si algún par no llega: correrlo si
  cambia un color.
- Ningún widget declara colores sueltos: todo sale de `AppPalette` y el tema.

Componentes:

- Radios: 10 campos y botones, 16 tarjetas y listas, 18 FAB, 20 diálogos y
  hojas, 24 cabecera, píldora en segmentado y chips. Sombras: `sombra-1`
  (tarjetas, listas, segmento activo) y `sombra-2` (tarjeta superpuesta, FAB,
  diálogos).
- `PagateSegmented` para 2 a 4 opciones excluyentes (los chips quedan para
  categorías). `confirmar()` para todo diálogo; `destructive: true` en
  carmesí. `PagateMetricCard`, `PagateIconSquare` y la vasija de
  `PagateEmptyState`.
- Letra grande: con 1,5 o más los montos bajan bajo la etiqueta; las
  palabras no se cortan (la letra se achica). Las listas con FAB dejan 88 dp
  al final.

## Ciclo por pantalla

1. Antes de cada arreglo, un test que falle; después, hacerlo pasar. Cada
   pantalla nueva lleva su test de widget.
2. `flutter analyze` y `flutter test` en verde (y functions si se tocó).
3. Capturas con letra 1.0, 1.5 y 2.0:
   `SALIDA=capturas/capa<N>-<pantalla> ./scripts/capturas.sh`.
4. Antes y después con `python scripts/comparar.py capturas/<antes>
   capturas/<despues> <salida>.png --solo-cambios` y revisar las láminas.
   Los retoques van en otra pasada (`capturas/...-b`).
5. Commit local, atómico, en español.
6. Al cerrar la pantalla, `git push` a la rama de trabajo (**nunca** a
   `main`) y **esperar el OK del dueño** antes de empezar la siguiente.

Además:

- Nunca `dart format` sobre líneas que no se tocaron.
- No commitear los registrantes generados de `linux/`, `macos/` y `windows/`
  (`generated_plugin_registrant.*`, `generated_plugins.cmake`,
  `GeneratedPluginRegistrant.swift`): Flutter los reescribe solo.

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
  acepta un mapa parcial.
- Producto: compra del plan Pro, stock decimal (decisión pendiente en
  `docs/ARQUITECTURA.md`). Web e iOS fuera de alcance.

Cerrados en `docs/reglas-trabajo`: `allowBackup` y reglas de extracción,
caché de Firestore al cerrar sesión, borrar historial del asistente, aviso de
privacidad en la lista de espera, Material en es_CL, error crudo en el arranque
y en `SessionErrorView`, verificación de correo, mensaje genérico en
`describeFirebaseError` (también para errores que no son de Firebase) y log
único en `AuthGate`.

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
