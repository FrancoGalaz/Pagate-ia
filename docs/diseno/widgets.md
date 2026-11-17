# Widgets compartidos para el sistema tomado de Cabal

Acompaña a `variantes-cabal.html`. Todo vive en `lib/core/widgets/`. Se eligió
la variante A; esta lista dice qué se creó o cambió y dónde se usa. Algunos
nombres de la propuesta no llegaron a ser widgets propios: lo indica la tabla.

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
| `PagateSegmented` | Selector segmentado en píldora, de 2 a 4 opciones con selección única. La opción activa es blanca, con `sombra-1` y en el color oscuro. Con letra grande el texto pasa a dos líneas centradas; si una palabra no cabe, la letra se achica en vez de cortarla. `onReselected` avisa al tocar la opción ya elegida. | Inventario (Productos/Materiales), Finanzas (Este mes / Mes pasado / Año / Otro mes), Registrar (Ingreso/Gasto) |
| `PagateMetricCard` | Monto en 800 con una etiqueta debajo. `tone` puede ser neutro, ingreso o gasto: cambia el color del monto y la flecha. | Finanzas (grilla de 2; de 1 con letra 1.5 o más; la que queda sola va a todo el ancho) |
| `PagateFormRow` | No es un widget propio. En Inicio y Configuración es `PagateDataRow` con `icon`; en Registrar, la fila local `_FilaFormulario`, porque su valor es texto y tiene que poder partirse. | Registrar movimiento, Inicio (valor hora, gastos fijos, stock), Configuración |
| `confirmar()` (`pagate_confirm_dialog.dart`) | Título, texto y el par Cancelar / confirmar, en radio 20. Devuelve `bool`. Con `destructive: true` el botón va en carmesí. Reemplaza los `AlertDialog` sueltos. | Borrar historial, cerrar sesión, eliminar ítem o movimiento, salir sin guardar |
| `PagateIconSquare` | Ícono en un cuadro tintado. | Filas de Inicio, Registrar y Configuración |
| `PagateVasija` | Ilustración de dos colores de los estados vacíos. | `PagateEmptyState` |
| Cabecera de Inicio | No es un widget compartido: `_Portada` en `home_tab.dart`, en el color oscuro con saludo y avatar, y la tarjeta del saldo superpuesta 48 dp. Regla: el color de acción no va directo sobre la cabecera. | Inicio |
| Primeros pasos | No es un widget compartido: `_PrimerosPasos` en `home_tab.dart`. N de 4, barra de progreso y filas con marca y enlace. Se oculta cuando la cuenta tiene movimientos. | Inicio (cuenta nueva) |

## Cambian

| Widget | Cambio |
|---|---|
| `PagateDataRow` | Filas de dato, con `icon` opcional (el cuadro tintado) y flecha si navegan. Arreglo de desborde: el valor no se envuelve (`softWrap: false`) y baja bajo la etiqueta con letra 1.5 o más. `subtitleMaxLines` deja el subtítulo en más de una línea (Gastos fijos en Inicio). |
| `PagateMovementRow` | Ícono en un cuadro tintado. El monto con signo va en 800, verde o carmesí. Mismo arreglo de desborde. |
| `PagateSectionHeader` | Título en 800. La acción («Ver todos») en color de acción, alineada a la derecha y sin repartir el ancho a la mitad: arregla los cortes de «Movimiento/s». |
| `PagateSectionCard` | Radio 16 y `sombra-1` en lugar del borde de 1 px. Separadores internos al 10 % del oscuro. |
| `PagateEmptyState` | Agrega una ilustración: la vasija, un SVG de dos colores que sale del tema. El texto queda igual. |
| `PagatePrimaryButton` | Primario en el color de acción. Secundario con contorno de 1,5 en el oscuro. Radio 10 y alto 48. |
| `PagateTextField` | Borde en el token «borde» (3:1 o más) y radio 10. Etiqueta flotante en texto 2. |
| `PagateBottomNav` | Pestaña activa en el oscuro con una barra de 3 dp. Las inactivas en el apagado. Sin la píldora de color de Material 3. |
| `PagateSheet` | Registrar movimiento deja de ser hoja y pasa a pantalla completa (#54–57), con «Limpiar» en la barra superior y solo «Crear» abajo. Las demás hojas quedan, con radio 20. |
| `PagateSectionCard` (margen) | Gana `margin`; `EdgeInsets.zero` cuando el padre ya trae el margen de pantalla (la lista de Registrar). |
| `PagateChipSelector` | Donde haya 2 o 3 opciones excluyentes, se reemplaza por `PagateSegmented`. Queda para las categorías. |
| `PagateMonthSelector` | En Finanzas lo reemplaza `PagateSegmented`; «Otro mes» abre una hoja con la lista de meses. Hoy no lo usa ninguna pantalla. |

## Fuera

- `PagateClearCreateBar`: Registrar pasó «Limpiar» a la barra superior y
  ningún otro formulario la usaba. Borrado con su test.
- El gráfico de línea «Cómo va tu balance» (`NetBalanceLineChart`): la
  variante A deja en Finanzas solo las barras por mes y las categorías.

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
