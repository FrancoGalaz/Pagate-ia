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
