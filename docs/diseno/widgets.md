# Widgets compartidos para el sistema tomado de Cabal

Acompaña a `variantes-cabal.html`. Todo vive en `lib/core/widgets/`. Lista de
lo que hay que crear o cambiar cuando se elija una variante. Todavía no se toca
nada.

Regla común: ningún widget declara colores sueltos. Leen `AppPalette` y el
tema, y la variante elegida solo cambia esos valores.

## Tema (`lib/core/theme/`)

| Archivo | Cambio |
|---|---|
| `app_theme.dart` | `ColorScheme`:<br>• `primary` es el color de acción.<br>• `secondary`/`onSurface` es el oscuro.<br>• El lienzo usa el tinte.<br>Agregar `ingreso`/`gasto` a `AppPalette`.<br>Las sombras `sombra-1` y `sombra-2` van como constantes. |
| `app_text.dart` | Títulos de 600 a 800.<br>Nuevo estilo `cifraDominante` 34/800 tabular.<br>`amountRow` pasa a 800. |
| Radios | Pasan a 10 (campos y botones), 16 (tarjetas), 20 (diálogos), 24 (cabecera) y píldora. Hoy son r4/r8/r12/r16. |

## Nuevos

| Widget | Para qué | Dónde se usa |
|---|---|---|
| `PagateSegmented` | Selector segmentado en píldora, de 2 o 3 opciones con selección única. La opción activa es blanca, con `sombra-1` y en el color oscuro. Con letra 2.0 el texto pasa a dos líneas centradas y no se corta. | Inventario (Productos/Materiales), Finanzas (período), Registrar (Ingreso/Gasto) |
| `PagateMetricCard` | Monto en 800 con una etiqueta debajo. `tone` puede ser neutro, ingreso o gasto: cambia el color del monto y la flecha. | Finanzas (4 tarjetas en una grilla de 2) |
| `PagateFormRow` | Ícono en un cuadro tintado, etiqueta (y subtítulo), valor y flecha. Toca para abrir un selector. El valor no se envuelve: si no cabe, baja bajo la etiqueta. | Registrar movimiento, Inicio (valor hora, gastos fijos, stock), Configuración |
| `PagateClearCreateBar` | Par Limpiar (secundario) y Crear (acción), en proporción 1 : 1,4. Con letra 2.0 se apilan. | Registrar movimiento, formularios de inventario |
| `PagateConfirmDialog` | Título, texto y el par Cancelar / confirmar, en radio 20. Una función `confirmar(context, …)` que devuelve `bool`. Reemplaza los `AlertDialog` sueltos. | Borrar historial, cerrar sesión, eliminar ítem, salir sin guardar |
| `PagateHeroHeader` | Cabecera en el color oscuro con saludo y avatar. Lleva un `child` superpuesto 48 dp hacia arriba (la tarjeta blanca). Regla: el color de acción no va directo sobre la cabecera. | Inicio |
| `PagateChecklist` | Primeros pasos: N de M, barra de progreso y filas con marca y enlace «ir a». Se oculta al completar los pasos o al descartarla. | Inicio (usuario nuevo) |

## Cambian

| Widget | Cambio |
|---|---|
| `PagateDataRow` | Queda para filas de solo lectura. Las que navegan pasan a `PagateFormRow`. Arreglo de desborde ya aprobado: el valor no se envuelve (`softWrap: false`) y baja de línea con letra grande. |
| `PagateMovementRow` | Ícono en un cuadro tintado. El monto con signo va en 800, verde o carmesí. Mismo arreglo de desborde. |
| `PagateSectionHeader` | Título en 800. La acción («Ver todos») en color de acción, alineada a la derecha y sin repartir el ancho a la mitad: arregla los cortes de «Movimiento/s». |
| `PagateSectionCard` | Radio 16 y `sombra-1` en lugar del borde de 1 px. Separadores internos al 10 % del oscuro. |
| `PagateEmptyState` | Agrega una ilustración: la vasija, un SVG de dos colores que sale del tema. El texto queda igual. |
| `PagatePrimaryButton` | Primario en el color de acción. Secundario con contorno de 1,5 en el oscuro. Radio 10 y alto 48. |
| `PagateTextField` | Borde en el token «borde» (3:1 o más) y radio 10. Etiqueta flotante en texto 2. |
| `PagateBottomNav` | Pestaña activa en el oscuro con una barra de 3 dp. Las inactivas en el apagado. Sin la píldora de color de Material 3. |
| `PagateSheet` | Registrar movimiento deja de ser hoja y pasa a pantalla completa (#54–57). Las demás hojas quedan, con radio 20. |
| `PagateChipSelector` | Donde haya 2 o 3 opciones excluyentes, se reemplaza por `PagateSegmented`. Queda para las categorías. |
| `PagateMonthSelector` | En Finanzas lo reemplaza `PagateSegmented` (Este mes / Mes pasado / Año). Decidir si se conserva para elegir un mes anterior. |

## Fuera

- Mosaicos de colores, inicio como menú de módulos y tablas densas (#61–72).
- `PagateWordmark`, `PagateSocialButton` y `PagateStepHeader` solo cambian
  colores por el tema.

## Orden sugerido (por capas)

1. Tema y tokens. Con eso solo ya cambia todo el color.
2. Arreglos de desborde ya aprobados (filas, encabezado de sección, avatar,
   FAB).
3. Widgets nuevos y sus tests de widget.
4. Pantallas: Inicio, Registrar, Finanzas, Inventario y Configuración.
5. `scripts/capturas.sh` en las 3 escalas y revisión de las láminas.
