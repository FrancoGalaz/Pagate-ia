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

## Estado

- **Consola de Firebase:** sin cambios desde el 2026-10-06 (Authentication sin
  habilitar, sin base de Firestore, sin plan Blaze, sin clave de OpenRouter,
  nada desplegado). Lo que falta en consola está en `docs/PLAN.md`.
- **Git:** `arquitectura-segura` tiene 144 commits que no están en GitHub.
  `origin/main` solo recibió este CLAUDE.md (PR #1).
- **Tests (2026-11-08, rama `docs/reglas-trabajo`):** `flutter analyze` sin
  problemas; `flutter test` 497 pasan; functions `lint` y `build` OK y
  `npm --prefix functions test` 303 pasan (11 archivos, 80 de ellos de reglas).
  La landing no se corrió.

## Tareas de código pendientes (decididas, sin hacer)

1. Quitar iOS de `lecturaDeBoletasDisponible`
   (`lib/features/receipt_scan/domain/receipt_scan_availability.dart:18`) para
   que sea coherente con iOS fuera de alcance.
2. Borrar los `get()` sin uso: `getProfile()`
   (`user_profile_firebase_datasource.dart:33`, `user_profile_repository.dart:8`,
   `user_profile_repository_impl.dart:17`) y `getHourlyRate()` /
   `hasConfiguration()` (`hourly_rate_local_datasource.dart:35,46`,
   `hourly_rate_repository.dart:8,12`, `hourly_rate_repository_impl.dart:16,24`).
   Solo los implementan los fakes de `test/features/hourly_value/`; nadie los
   llama.
3. Cambiar el saludo del asistente (`_welcomeText`,
   `lib/features/dashboard/presentation/providers/ai_provider.dart:77`): hoy
   dice que conoce el inventario, pero el backend solo envía el conteo de
   productos y materiales, y los gastos fijos no viajan.
