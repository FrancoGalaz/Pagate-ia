# Sistema visual — Cartola — sistema visual Págate v2 (tema claro único)

> **Reemplazado (2026-11-12).** Este documento ya no es la fuente de verdad del
> sistema visual. Lo reemplaza el rediseño de la variante A («Greda y carbón»):
> `docs/diseno/widgets.md` y el código (`lib/core/theme/`,
> `lib/core/constants/app_constants.dart`, `lib/core/widgets/`). Se conserva
> como registro de la v2.

Especificación única resultante de tres propuestas independientes, fusionadas y verificadas.
Propuestas evaluadas: *Esmeralda disciplinada — sistema visual Págate v2 (tema claro único)*, *Extracto — sistema visual monocromo orientado a cifras*, *Libreta — sistema visual de Págate-IA (tema claro único)*.

Decisiones de producto que la enmarcan (Franco, 2026-09-29): dirección **fintech sobria y densa**,
**tema claro único**, rediseño a fondo de bienvenida, registro, onboarding, inicio y finanzas, y
limpieza del resto. Objetivo: publicar en Google Play.

## Principios

1. Base elegida: la propuesta "Libreta". Se le injerta la disciplina tipográfica de "Extracto" (fontVariations, leadingDistribution, signo U+2212, helper de moneda) y la cirugía de tokens y la migración por alias de "Esmeralda disciplinada". Lo que descarté de cada una y por qué está en riesgos.

2. La cifra manda, pero solo una por pantalla. Cada pantalla tiene exactamente un número dominante alineado a la izquierda, en figuras tabulares y sin abreviar: $1.284.500, nunca $1.3K. Hoy hay cuatro formateadores distintos que abrevian (home_tab.dart:243-244, :277, :610-611 y finanzas_tab.dart:15-24) y el balance principal se dibuja literalmente como '$1234.6K' en home_tab.dart:196.

3. Tema único claro. `darkTheme` (app_theme.dart:398-560, 163 líneas) y `themeMode: ThemeMode.dark` (app_shell.dart:28) desaparecen. Verifiqué el coste con grep: 251 referencias a los 8 tokens `*Dark` (textSecondaryDark 84, textPrimaryDark 56, borderDark 47, surfaceDark 36, backgroundDark 15, surfaceDarkSecondary 10, textTertiaryDark 3, surfaceDarkElevated 0). Ningún widget vuelve a decidir su propio brillo: se va el `Theme(data: AppTheme.lightTheme)` de welcome_screen.dart:28-29 y el `if (brightness == dark)` de pagate_section_card.dart:29-31.

4. Se separa con línea y superficie, nunca con sombra ni con radio. Hay sombra en exactamente tres sitios del sistema (hoja modal, menú desplegable, snackbar) y en ninguno más. Comprobación objetiva de que terminó: `grep -rn "AppShadows\|boxShadow" lib/` pasa de 14 resultados a 0.

5. El color significa algo o no se usa. Verde marca = acción primaria, selección, foco, enlace y relleno de progreso. Verde dinero = un ingreso. Rojo = balance negativo, error o acción destructiva. Ámbar = stock bajo. Un gasto corriente NO va en rojo: va en tinta con el signo − (hoy sí va en rojo: home_tab.dart:540 y finanzas_tab.dart:790 hacen `isIncome ? AppColors.success : AppColors.error`).

6. Todo a la izquierda, en una columna. Lo único centrado es el contenido de un botón; lo único a la derecha es el valor numérico de una fila. Hoy en la bienvenida no queda un solo elemento alineado a la izquierda (welcome_screen.dart:70, :178, :206, :298).

7. Ningún píxel afirma algo que Firestore no diga. Se borran '+24%' y 'Optimizado' (welcome_screen.dart:153-154, :166-167), 'ganar $830 extra este mes' (ayuda_screen.dart:100), 'La primera herramienta financiera' (welcome_screen.dart:202) y el punto rojo de notificaciones siempre encendido que abre la pantalla de Ayuda (home_tab.dart:115-122 → dashboard_screen.dart:66).

8. Toda altura es un mínimo, nunca fija. `ConstrainedBox(minHeight:)` o `IntrinsicHeight`, jamás `SizedBox(height:)` alrededor de texto, y ningún `Row` con dos hijos de ancho intrínseco sin `Flexible`. Es requisito de publicación: hoy Inicio desborda con el ajuste 'Grande' de Android (1,3x) en home_tab.dart:165.

9. Todo control es un control. Cero `GestureDetector` haciendo de botón (hoy hay 19), cero controles de solo icono sin etiqueta (hoy `Semantics`, `semanticLabel` y `ExcludeSemantics` aparecen 0 veces en todo lib/ y solo hay 3 `tooltip:`), y área táctil mínima de 48×48 aunque el píxel visible mida menos.

10. El widget no elige colores ni tamaños: consume tokens semánticos. Si un widget necesita un color que no existe como token, falta el token, no el color. Hoy hay 162 violaciones en 17 archivos y el propio tema hardcodea 10 `fontSize` fuera del `TextTheme` (app_theme.dart:254, :280, :292, :309, :315, :385, :457, :462, :516, :534).

11. Densidad real: margen lateral 16 dp (hoy 24, app_constants.dart:138), fila de dato 48 dp mínimo, fila de movimiento 64 dp mínimo, divisores a sangre, máximo dos niveles de jerarquía por pantalla y cero tarjetas dentro de tarjetas.

12. Cada pantalla respeta la barra de estado. `SafeArea` en el `body` del dashboard: hoy `dashboard_screen.dart:208` monta el `IndexedStack` sin ninguna, y el único `SafeArea` del archivo (:219) es `top: false` para la barra inferior. Ninguna de las 5 pestañas la pone por su cuenta.

## Tipografía

FAMILIA: se conserva **Manrope**. Cero fuentes nuevas, cero KB nuevos.

DATOS VERIFICADOS EN EL BINARIO (`assets/fonts/Manrope[wght].ttf`, 165.420 bytes), no de catálogo:
- `head.unitsPerEm` = 2000. `OS/2` v4: `sxHeight` 1080 (**0,540 em**), `sCapHeight` 1440 (0,720 em). Altura de x prácticamente idéntica a la de Inter (0,546): aguanta 11-13 dp sin empastarse.
- `fvar`: **1 solo eje**, `wght`, min 200, **default 200**, max 800, con 7 instancias nombradas (200/300/400/500/600/700/800). No hay eje `ital` ni `slnt` ni `opsz`. La app no usa cursiva (0 `FontStyle.italic`), así que no bloquea.
- `GSUB` expone: `aalt, calt, case, dnom, frac, liga, locl, numr, ordn, pnum, sinf, subs, sups, **tnum**`. `GPOS`: `kern`. **No existe la feature `zero`**, así que `FontFeature.slashedZero()` sería un no-op: no lo especifico.
- `name` ID 13: "This Font Software is licensed under the SIL Open Font License, Version 1.1". ID 0: "Copyright 2019 The Manrope Project Authors". Autor Mikhail Sharanda. **OFL 1.1 confirmada en el archivo**: uso comercial y empaquetado permitidos, sin atribución en pantalla, pero con obligación de redistribuir el texto de la licencia (ver `migracion`, paso 9).
- `name` ID 1 es literalmente **"Manrope ExtraLight"** y `OS/2.usWeightClass` = **200**.

DEFECTO BLOQUEANTE QUE SE ARREGLA PRIMERO. `pubspec.yaml:37-40` declara un único asset sin campo `weight:`. Con `usWeightClass 200` y el default de `fvar` en 200, la familia se registra como una sola cara ExtraLight, y en todo `lib/` hay **0 usos de `fontVariations`** (grep verificado). Los w600/w700/w800 del tema (app_theme.dart:25, :32, :39, :47 y 120 `fontWeight` repartidos por los widgets) no están seleccionando pesos reales del eje: en el mejor caso el motor lo instancia, en el peor sintetiza negrita. Es la causa más probable de que la app se vea blanda con una escala que sobre el papel es razonable.

CORRECCIÓN — un único helper, y que nadie construya `TextStyle` a mano:

```dart
// lib/core/theme/app_text.dart
const String kFont = 'Manrope';

TextStyle _t(double size, int w, double lh, double ls, {bool tab = false}) => TextStyle(
      fontFamily: kFont,
      fontSize: size,
      height: lh / size,                       // lh en dp -> multiplicador
      letterSpacing: ls,
      fontWeight: FontWeight.values[(w ~/ 100) - 1],
      fontVariations: [FontVariation('wght', w.toDouble())],
      leadingDistribution: TextLeadingDistribution.even,
      fontFeatures: tab ? const [FontFeature.tabularFigures()] : null,
    );
```

`leadingDistribution: even` **no es opcional**: verifiqué `hhea`/`OS/2` y Manrope declara ascent 2132 + descent 600 = 2732/2000 = **1,366 em de caja intrínseca**. Cualquier `height` por debajo de ~1,37 (y la cifra héroe va en 1,05) hace que Flutter reparta el leading de forma asimétrica y descentre la línea. Es el detalle que hace que una cifra de 40 dp se vea "colgada".

`fontWeight` se conserva junto a `fontVariations` para que el texto que caiga en el fallback del sistema reciba negrita sintética en vez de pelo.

ESCALA (los 15 slots de Material 3, para que los ~130 `Theme.of(context).textTheme.*` que ya existen sigan funcionando; `lh` en dp, `ls` en dp):

| slot M3 | dp | wght | lh | ls | tnum | rol exacto |
|---|---|---|---|---|---|---|
| displayLarge | 40 | 700 | 42 | -1,0 | **sí** | la cifra que ES la pantalla: balance del mes en Inicio. Una por app |
| displayMedium | 32 | 700 | 35 | -0,6 | **sí** | cifra principal de Finanzas; titular de Bienvenida; caída de displayLarge |
| displaySmall | 24 | 700 | 28 | -0,3 | **sí** | total de sección (gastos fijos, valor hora) |
| headlineLarge | 24 | 700 | 30 | -0,3 | no | titular de pantalla sin barra (Bienvenida) |
| headlineMedium | 20 | 700 | 26 | -0,2 | no | título de pantalla en la barra ("Finanzas", "Inventario") |
| headlineSmall | 18 | 600 | 24 | 0 | no | título de hoja modal y de diálogo |
| titleLarge | 16 | 600 | 22 | 0 | no | encabezado de sección ("Movimientos", "Gastos fijos") |
| titleMedium | 15 | 600 | 21 | 0 | no | título de fila de movimiento, nombre de ítem |
| titleSmall | 14 | 600 | 20 | 0 | no | etiqueta de campo y de fila de dato |
| bodyLarge | 16 | 400 | 23 | 0 | no | texto dentro de campos; párrafo principal |
| bodyMedium | 14 | 400 | 20 | 0 | no | texto corriente, descripciones, estados vacíos |
| bodySmall | 13 | 400 | 18 | 0 | no | metadato: `12 oct · Materiales`; texto legal |
| labelLarge | 15 | 600 | 18 | 0 | no | texto de botón primario y secundario |
| labelMedium | 13 | 600 | 16 | 0,1 | no | chip, botón de texto, ítem del selector de periodo |
| labelSmall | 11 | 600 | 13 | 0,6 | no | **única versalita del sistema**: línea guía sobre la cifra héroe y etiqueta de la barra inferior. Máximo una por sección |

Regla dura: **la familia `display*` es la familia numérica**. Los tres llevan `tnum` y nunca se usan para texto. Los `headline*` son títulos y nunca llevan `tnum`. Así se evita el problema de las cifras tabulares en prosa (dejan huecos feos) sin tener que decidirlo en cada pantalla.

ESTILOS NUMÉRICOS DE FILA — fuera del `TextTheme`, en `AppText`, porque un monto dentro de una fila no puede robarle el slot a un título:
- `AppText.amountRow` = `_t(16, 600, 20, 0, tab: true)` — monto de fila de movimiento y de fila de dato.
- `AppText.amountSmall` = `_t(14, 600, 19, 0, tab: true)` — monto secundario (gasto fijo, stock "2 de 6 un.").
- `AppText.amountField` = `_t(20, 600, 24, 0, tab: true)` — valor escrito en un campo de monto.

QUÉ DESAPARECE DE LA ESCALA ACTUAL (app_theme.dart:21-120): el peso **w800 entero** (hoy en displayLarge 48, displayMedium 36, displaySmall 30 y headlineLarge 28 — el máximo pasa a 700; el 800 de Manrope a 14-16 dp se empasta); los tamaños 48 y 36, que son de landing y además tienen **0 usos** en todo lib/; `height: 1.5` en los tres slots de body (:85, :91, :97, demasiado aireado para densidad); y el `letterSpacing: 0.5/0.6` de labelLarge (:103) y labelMedium (:110), que hincha los botones — el tracking positivo solo sobrevive en labelSmall, el único nivel en mayúsculas. bodySmall sube de 12 a 13 dp porque hoy la fecha y la categoría de cada movimiento son ilegibles a 12/400 en gris.

CIFRAS TABULARES — verificado glifo a glifo, no supuesto:
1. Por defecto los dígitos de Manrope son **proporcionales**: el `1` mide 716/2000 (0,358 em) y el `9` mide 1240/2000 (0,620 em), un 73% de diferencia. Por eso hoy toda columna de montos baila (finanzas_tab.dart:317, :845; home_tab.dart:277, :590; detalle_item_screen.dart:383).
2. Resolví la sustitución GSUB de `tnum` (lookup 21, tipo 1): los 10 dígitos pasan a los glifos 551-560, **todos con avance 1240/2000 = 0,620 em**.
3. Comprobé además la tabla `HVAR`: **el avance de los dígitos tabulares no varía con el peso** (1240 en w200, w600 y w700). El `$` sí varía (1126 → 1256) y el punto de millar también (440 → 607). Consecuencia práctica en el siguiente punto.
4. **Prohibido fijar el ancho de la columna de monto con un `SizedBox`.** El monto va en un `Text` con `textAlign: TextAlign.right` dentro de la fila, con el título en `Expanded`. Medí que `−$1.234.567` a 17 dp ocupa 100,0 dp en w200 pero 103,9 dp en w700: un ancho fijo calculado a un peso se rompe a otro, y sobre todo se rompe con el escalado de fuente del sistema, que es justamente lo que hoy revienta Inicio a 1,3x. Con `tnum` los dígitos ya no se mueven entre frames; eso es todo lo que hace falta para que la columna se lea en vertical.
5. **Signo:** se usa U+2212 MINUS SIGN (`−`), no el guion ASCII. Verificado: el guion mide 840/2000 y el minus 1080/2000; el guion hunde la columna. El signo va antes del símbolo (`+$12.400`, `−$3.150`) y **dentro del mismo `Text`** que la cifra, nunca como widget aparte. Los ingresos llevan `+` explícito.

MONEDA — una sola función, en `lib/core/utils/currency_formatter.dart`, que es la tarea **C-2 ya escrita en docs/PLAN.md (Fase 2)** y que hay que hacer **antes** de tocar Inicio y Finanzas o esas dos pantallas se reescriben dos veces:

```dart
String formatCurrency(num v, {required String currency}) => NumberFormat.currency(
      locale: currency == 'USD' ? 'en_US' : 'es_CL',
      symbol: r'$',
      decimalDigits: currency == 'USD' ? 2 : 0,
    ).format(v);

String formatSigned(num v, {required String currency}) =>
    '${v < 0 ? '−' : '+'}${formatCurrency(v.abs(), currency: currency)}';
```

`intl: ^0.20.2` ya está en pubspec.yaml:17 y hoy no se usa para dinero. Un widget `PagateAmount(value, {signed})` lee `profile.currency` y aplica `AppText.amountRow`. Ninguna pantalla vuelve a formatear dinero: mueren `_money` (finanzas_tab.dart:15-24), las tres `_fmt` de home_tab y las de financial_charts.dart:499 y pdf_report_service.dart:22. Esto cierra el hallazgo A de la auditoría previa (2.5, "5 implementaciones de moneda").

Único sitio donde se abrevia: los **ejes** de los gráficos, con `NumberFormat.compactCurrency(locale: 'es_CL', symbol: r'$')` → "$23,8 mil". Nunca "23.8K".

`ThemeData.fontFamily: 'Manrope'` se declara también a nivel raíz para que lo que construya su propio `TextStyle` (fl_chart, tooltips) no caiga en Roboto.

## Color

TEMA CLARO ÚNICO. **21 tokens planos**, cero degradados, cero glass, cero sombras de color. Todos los ratios están calculados con la fórmula WCAG 2.1 de luminancia relativa y **verificados uno a uno por par de uso real** (umbral AA: 4,5:1 texto normal; 3:1 texto ≥18,66dp/700 o ≥24dp, y objetos gráficos y bordes por 1.4.11).

**SUPERFICIES**
- `canvas` **#F6F7F8** — fondo de `Scaffold` en todas las pantallas. Cambia desde `background #F3F4F6` (app_constants.dart:45).
- `surface` **#FFFFFF** — secciones, filas, campos, barra inferior, hoja modal. *Sobrevive* (:46).
- `sunken` **#F1F3F5** — pista de barra de progreso, campo deshabilitado, fondo de encabezado agrupador. Sustituye a `surfaceSecondary #F8FAFC` (:47) y `surfaceTertiary #F1F5F9` (:48).
- `skeleton` **#EAECF0** — bloques del esqueleto de carga. Nuevo.
- `scrim` **#101828 al 40%** — detrás de hoja modal y diálogo. Nuevo.

**TEXTO** (ratios: surface / canvas / sunken)
- `textPrimary` **#101828** — 17,75 / 16,55 / 15,95 ✅ AAA en las tres. Cambia desde #16213E (:58). El azul noche tiñe todo de marca; la cifra tiene que leerse como tinta.
- `textSecondary` **#475467** — 7,69 / 7,17 / 6,91 ✅ AAA. Cambia desde #6B7280 (:59), que da 4,83 sobre blanco pero **4,39 sobre el fondo de app y falla AA**.
- `textMuted` **#636C7A** — 5,31 / 4,95 / 4,77 ✅ AA **en las tres superficies**. Metadatos (`12 oct · Materiales`), placeholders, etiquetas no seleccionadas de la barra inferior. Sustituye a `textTertiary #9CA3AF` (:60), que da **2,54 sobre blanco y 2,31 sobre el fondo**: hoy es un fallo de AA repetido en 17 sitios (pagate_label.dart:22, pagate_text_field.dart:104, pagate_step_header.dart:106, welcome_screen.dart:271 y :295, identity_step_screen.dart:207, :278, :297, :342, entre otros).
- `textDisabled` **#98A2B3** — 2,58 sobre blanco. **Nunca texto informativo**: solo controles deshabilitados, que WCAG 1.4.3 exime. Cambia desde #CBD5E1 (:61), que da 1,48.
- `textOnBrand` **#FFFFFF** — 6,43 sobre `brand` ✅. *Sobrevive* (:62).

**LÍNEAS**
- `hairline` **#EDEFF2** — 1,15 sobre blanco. Divisor entre filas de una lista, a sangre completa (sin `indent`). Decorativo: 1.4.11 no aplica porque la separación también la da el espaciado.
- `border` **#E4E7EC** — 1,24 sobre blanco. Contorno de sección, borde superior de la barra inferior, borde de botón secundario. Cambia desde #E5E7EB (:71). Decorativo.
- `borderField` **#7E8794** — **3,63 / 3,39 / 3,27** ✅ **1.4.11 en las tres superficies**. Contorno de campo de texto, casilla e interruptor: son componentes cuyo límite es el único indicador y por eso necesitan 3:1. Nuevo, y es la diferencia que hoy no existe: `app_theme.dart:192-199` deja `border` y `enabledBorder` con **`borderSide: BorderSide.none`** sobre un relleno `surfaceSecondary` que contra el blanco de la tarjeta da 1,05:1 — un campo literalmente invisible.
- `borderFocus` = `brand` **#006B5F**, 1,5 dp. *Sobrevive el token* (:73), reapuntado.

**MARCA**
- `brand` **#006B5F** — 6,43 / 5,99 / 5,78 ✅ AA como texto, icono y relleno. *Sobrevive sin cambio de valor* (:25). Es el único token de la paleta actual que aguanta AA como color de texto y de fondo.
- `brandPressed` **#005A50** — blanco encima 8,14 ✅. *Sobrevive de valor*, renombra `brandDark` (:27).
- `brandSurface` **#E6F2F0** — `brand` encima **5,61** ✅ AA, `textPrimary` encima 15,48 ✅. *Sobrevive sin cambio de valor* (`brandLight`, :26). Dos de las tres propuestas lo movían un punto para "cruzar 5,5"; comprobé que el valor actual ya pasa y no lo toco.

**DINERO** (el rol que hoy no existe; cierra el hallazgo "faltan tokens semánticos de finanzas")
- `moneyIn` **#0B6A47** — 6,63 / 6,18 / 5,96 ✅ AA. Sustituye a `success #10B981` (:35), que da **2,54 sobre blanco** y hoy pinta los montos de ingreso en home_tab.dart:540 y finanzas_tab.dart:790.
- `moneyOut` **#A32019** — 7,56 / 7,05 / 6,80 ✅ AAA/AA; blanco encima 7,56 ✅. Sustituye a `error #EF4444` (:39) como texto, que da **3,76 y no cumple AA**.
- `moneyInSurface` **#E6F2EC** — `moneyIn` encima 5,77 ✅, `textPrimary` 15,45 ✅.

Regla de aplicación, y es estrecha a propósito: **el color del dinero se aplica solo al monto de una fila de movimiento y al balance cuando es negativo.** Nunca a un fondo, nunca a un círculo de icono, nunca a las filas de Ingresos/Gastos del resumen (esas van en `textPrimary`, diferenciadas por el signo −). Un gasto corriente no es un error y pintar media lista de rojo destruye la jerarquía.

**ESTADO**
- `danger` **#A32019** (mismo valor que `moneyOut`, token aparte por semántica) — error de formulario, acción destructiva, balance negativo.
- `dangerSurface` **#FBEAE8** — `danger` encima 6,49 ✅, `textPrimary` 15,24 ✅. Fondo del deslizar-para-eliminar y del bloque de error.
- `warning` **#B54708** — 5,43 / 5,06 / 4,88 ✅ AA. Stock bajo. Sustituye a `warning #F59E0B` (:37), que da **2,15 sobre blanco y 1,93 sobre su propio `warningLight`**.
- `warningSurface` **#FBF0DC** — `warning` encima 4,81 ✅, `textPrimary` 15,72 ✅.

**SERIES DE DATOS** — una sola, no diez:
- `seriesOther` **#7E8794** (mismo valor que `borderField`) — 3,63 sobre blanco, 3,27 sobre `sunken` ✅ 1.4.11 como objeto gráfico.
Las barras de categoría usan `brand` #006B5F sobre pista `sunken` (5,78 ✅) y `seriesOther` para la fila "Otros". El gráfico de barras de Finanzas usa dos tintas: `moneyIn` para ingresos y `textPrimary` para gastos.

Se borra `_pieColors` (financial_charts.dart:511-520), diez `Color(0x…)` de los cuales seis duplican tokens y cuatro (#8B5CF6 violeta, #EC4899 rosa, #14B8A6 turquesa, #6366F1 índigo) no existen en la paleta. **No la sustituyo por una rampa de seis series**: calculé que el texto blanco de 11 dp que hoy va dentro de cada porción (financial_charts.dart:362-366) falla en **9 de los 10 colores** (2,15 el ámbar, 2,49 el teal, 2,54 el verde, 2,67 el coral, 3,53 el rosa, 3,68 el azul, 3,76 el rojo, 4,23 el violeta, 4,47 el índigo; solo el #006B5F pasa con 6,43). El donut se reemplaza por barras horizontales con etiqueta, monto y porcentaje, donde el color es redundante y no hay problema de contraste entre segmentos adyacentes. El hallazgo se resuelve eliminando la necesidad, no inventando seis colores más.

**RESUMEN DE VERIFICACIÓN**: 30 pares de texto AA, 5 pares de no-texto a 3:1 y 4 de blanco sobre relleno sólido. **Cero fallos.** Todos los pares que la app usa de verdad quedan comprobados, incluidos los que ninguna de las tres propuestas comprobó (texto sobre `sunken`, borde de campo sobre `sunken`, barra "Otros" sobre la pista).

**TOKENS QUE SE BORRAN** (con línea en `lib/core/constants/app_constants.dart`): `:26-28` brandLight/brandDark/brandSubtle (se renombran dos, muere `brandSubtle`, 0 usos) · `:30-32` accent/accentLight/accentDark — el coral da 2,67 sobre blanco, no cumple AA como texto y no tiene trabajo semántico en una app de dinero · `:36, :38, :40, :41, :42` successLight/warningLight/errorLight/info/infoLight · `:47-48` surfaceSecondary/surfaceTertiary · `:51-55` los cinco fondos oscuros · `:61` textDisabled (cambia de valor) · `:63` textLink (0 usos) · `:66-68` los tres textos oscuros · `:72` borderLight (se convierte en `hairline`) · `:77-78` glass/glassStrong · `:81-83` shadowLight/shadowMedium/shadowBrand (`shadowBrand` tiene 0 usos) · `:86-114` los cuatro degradados.

La paleta pasa de 38 colores + 4 degradados a **21 tokens planos**, todos con un rol nombrado y un ratio verificado.

## Espaciado, radios y elevación

**ESPACIADO** — rejilla de 4, 9 pasos con un uso por valor (hoy hay 12 pasos en app_constants.dart:124-135, lo que garantiza que nadie elija el mismo dos veces):

| token | dp | uso exacto |
|---|---|---|
| `x0` | 0 | filas pegadas a un divisor |
| `x1` | 4 | entre línea de título y línea de metadato dentro de una fila |
| `x2` | 8 | entre etiqueta y campo; entre elementos de un grupo apretado |
| `x3` | 12 | padding vertical de fila compacta; hueco entre dos botones de una fila |
| `x4` | **16** | **margen lateral de pantalla**, padding horizontal de toda fila, padding de hoja modal, hueco entre secciones hermanas |
| `x5` | 20 | entre la cifra héroe y la línea de contexto |
| `x6` | 24 | aire entre bloques distintos de una pantalla |
| `x8` | 32 | aire antes del bloque de acciones del pie |
| `x10` | 40 | aire superior del titular de Bienvenida |

**`screenHorizontal` pasa de 24 a 16** (app_constants.dart:138, 48 usos). Es el cambio que más densidad gana con una sola línea: recupera 16 dp de ancho útil en cada fila de toda la app. Se borran `xxxs 2` (:124, rompe la rejilla de 4 que el propio comentario promete), `xxxxl 48` (:133, 0 usos), `section 56` (:134, 1 uso) y `hero 64` (:135, 2 usos): ningún espacio vertical de la app supera 40 dp.

Los **divisores van a sangre completa** (de 0 al ancho total), nunca indentados. Es lo que hace que una lista se lea como cartola y no como tarjetas apiladas.

**RADIOS** — 5 valores. Ninguno supera 16 dp en toda la app (hoy la escala llega a 32 y a 100, app_constants.dart:152-158):

| token | dp | uso |
|---|---|---|
| `r0` | 0 | secciones a sangre en móvil, divisores, filas de lista, barra inferior |
| `r4` | 4 | bloque de esqueleto, barra de progreso, asa de la hoja modal, insignia |
| `r8` | 8 | campo de formulario, chip, ítem del selector de periodo, avatar cuadrado, contenedor de icono |
| `r12` | 12 | **valor por defecto**: botón, sección con contorno (solo ≥720 dp), diálogo |
| `r16` | 16 | únicamente el borde superior de la hoja modal. Radio máximo del sistema |

Se borran `lg 20` (:155), `xl 24` (:156), `xxl 32` (:157) y `pill 100` (:158) con sus `BorderRadius` prefabricados (:164-167). Conté los usos reales: **`xxlBorder` 31, `pillBorder` 20, `xlBorder` 18, `lgBorder` 13** — 82 de los 99 usos de radio son de 20 dp para arriba. Y está cableado en el tema, no solo en pantallas: `inputDecorationTheme` usa `xxlBorder` en **los cinco borders** (app_theme.dart:193, :197, :201, :208, :215), `cardTheme` usa `xlBorder` (:180), `elevatedButtonTheme` y `outlinedButtonTheme` usan `pillBorder` (:250, :276) y `chipTheme` usa `lgBorder` (:320). Los botones pastilla de 56 dp de alto y los campos de radio 32 son la firma visual exacta que hay que borrar.

Formas circulares: solo dos supervivientes en toda la app, el avatar de perfil (`BoxShape.circle`) y el punto de estado de stock (8 dp). Todo lo demás es rectángulo.

**GROSORES DE BORDE** — 3 valores (hoy 3 también, pero mal repartidos: app_constants.dart:206-208):
- `hairline 1,0` — divisor, contorno de sección, borde de botón secundario. El 90% de los casos.
- `field 1,0` — mismo grosor, distinto color (`borderField` #7E8794): es el contorno de campo, casilla e interruptor, el único con obligación de 3:1.
- `emphasis 1,5` — solo foco (`brand`) y error (`danger`), **dibujado hacia adentro** para que el campo no cambie de tamaño al enfocarse y el texto no salte.

Se borra `borderThick 2,0` (:208). Se borra `borderNormal 1,5` como borde en reposo (hoy lo usa `focusedBorder` en app_theme.dart:204, que se conserva como `emphasis`).

Barras de progreso y de categoría: **6 dp de alto**, radio 4, relleno `brand` sobre pista `sunken` (5,78:1 ✅). `progressBarHeight` baja de 8 a 6 (:191). `chipHeight` baja de 36 a 32 (:190) pero con `MaterialTapTargetSize.padded`. `buttonHeight` e `inputHeight` bajan de 56 a **48** (:188-189).

**ÁREAS TÁCTILES** — nuevo token `AppSizes.minTouchTarget = 48.0`, y es obligatorio aunque el píxel visible mida menos. Medidos hoy por debajo del mínimo: botón de volver 40×40 (`backButtonSize`, app_constants.dart:194, usado en pagate_back_button.dart y duplicado en pagate_step_header.dart:48-49), chip 35, chip de mes 36 (finanzas_tab.dart:154), pestaña CLP/USD 40 (identity_step_screen.dart:326), pastillas de perfil y de onboarding ~29 (editar_perfil_screen.dart:189-192 y :239-242, setup_inicial_screen.dart:263-266), pestañas de inventario ~33 (inventario_tab.dart:303-306), y dos controles con `minimumSize: Size.zero` + `tapTargetSize: shrinkWrap` (ia_tab.dart:292-306, login_screen.dart:264-270) de los cuales el botón de cerrar del banner del chat mide ~16×16. Los once suben a 48 de caja táctil. El informe previo al lanzamiento de Google Play marca "touch target size" de forma explícita.

**SOMBRAS — la regla, entera.** Hay sombra **solo** cuando el sistema coloca una superficie encima del contenido y el usuario puede volver atrás de ella. Son tres casos y ninguno se personaliza:
- hoja modal: `0 2 16 rgba(16,24,40,0.10)` además del scrim;
- menú desplegable / `PopupMenu`: `0 4 12 rgba(16,24,40,0.10)`;
- `SnackBar` flotante: `0 2 8 rgba(16,24,40,0.12)`.

Todo lo demás —tarjeta, sección, fila, botón primario, botón secundario, FAB, barra inferior, barra superior, chip, avatar, gráfico— **no lleva sombra jamás**. Se separa con 1 px de `border` o con 8-24 dp de `canvas` visible.

`AppShadows` (app_constants.dart:212-264) desaparece entero y se sustituye por `AppElevation.sheet / menu / snackbar`. Conté 14 líneas con `AppShadows.*` o `boxShadow` en lib/, repartidas en: `AppShadows.brandStrong` 4, `sm` 2, `brand` 2, `xl` 1, `md` 1, `lg` 1, `none` 1. Las que más daño hacen: pagate_primary_button.dart:36 (el `Container` de las líneas 30-38 existe **solo** para llevar el glow verde bajo el CTA de toda la app) y home_tab.dart:160 (`brandStrong`, el glow al 40% bajo la tarjeta de balance). También welcome_screen.dart:78, :134, :345 y pagate_section_card.dart:29-31.

El `FloatingActionButton.extended` de finanzas_tab.dart:56 pierde su elevación por defecto (`elevation/focusElevation/hoverElevation/highlightElevation: 0`) — o, mejor, desaparece y se convierte en barra de acción fija (ver componentes).

**MOVIMIENTO** — `AppDurations` se reduce a `instant 100` y `fast 200`; se borran `normal 300` (:272), `slow 500` (:273) y `emphasis 700` (:274). `AppCurves` se reduce a `standard` (`easeInOut`); se borran `exit` (:283, 0 usos) y sobre todo `bounce` (:285, `Curves.elasticOut`), que es lo contrario de sobrio. Las únicas animaciones del sistema son tres: pulsación de fila (100 ms, cambio de fondo), apertura de hoja modal (la de Material) y pulso del esqueleto (1200 ms). Se quitan el `AnimatedContainer` de los chips (pagate_chip_selector.dart:51-53) y del selector de mes (finanzas_tab.dart:167-168) y el `AnimatedSwitcher` del icono de la barra inferior (dashboard_screen.dart:320-330): un cambio de selección tiene que sentirse instantáneo.

Y se quita la onda de Material en las filas: `InkWell` con `highlightColor: sunken` y `splashFactory: NoSplash.splashFactory`. El splash circular de color es lo único "de plantilla" que quedaría.

## Componentes

Todos viven en `lib/core/widgets/` y se exportan desde `widgets.dart` —**incluido el estado de error, que hoy no lo está**: `pagate_error_state.dart:7` lo admite en su propio docstring ("No está en el barrel; impórtalo directo") y el barrel exporta 9 de los 10 componentes. Toda altura es un mínimo. Estados obligatorios en cada uno: reposo / presionado / deshabilitado / foco / cargando.

**1. Botón primario — `PagatePrimaryButton`** (14 usos, el botón principal de la app)
Alto mín. 48 (hoy 56). Padding H 16. Radio 12. Ancho completo salvo en estados vacíos. `labelLarge` 15/600. Fondo `brand` #006B5F, texto blanco (6,43 ✅). **Sin sombra**: se borra el `Container` envolvente (pagate_primary_button.dart:30-38) y la propiedad pública `hasShadow` (:14, :23), que por defecto está en `true`.
Presionado `brandPressed` #005A50 · **deshabilitado fondo `sunken` #F1F3F5 + texto `textMuted` #636C7A (4,77 ✅ — hoy es `textDisabled` #CBD5E1 con blanco encima, 1,48:1, ilegible)** · foco anillo 1,5 dp `brand` a 2 dp · cargando: el texto se reemplaza por `CircularProgressIndicator` de 18 dp, `strokeWidth: 2`, blanco, **manteniendo el ancho**.
`isLoading` deja de ser opcional en la práctica: los cuatro sitios que hoy no lo usan y permiten doble envío (inventario_tab.dart:98, finanzas_tab.dart:430, detalle_item_screen.dart:280, welcome_screen.dart:240) pasan a usarlo. `PagateSocialButton` gana `isLoading` (hoy no lo acepta, pagate_social_button.dart:7-17) y pierde la aritmética mágica `AppSizes.buttonHeight - 2` (:22).

**2. Botón secundario — `PagatePrimaryButton.secondary`**
Alto mín. 48, padding H 16, radio 12. Fondo `surface`, borde 1 `border` #E4E7EC, texto `textPrimary` #101828 (17,75 ✅), `labelLarge` 15/600.
Presionado fondo `sunken` · deshabilitado borde `hairline` + texto `textMuted` · foco borde 1,5 `brand`.

**3. Botón de texto — `PagatePrimaryButton.text`**
Alto 40 (caja táctil 48), padding H 8, radio 8, `labelMedium` 13/600, color `brand` (6,43 ✅). Sin subrayado, sin icono. Presionado fondo `brandSurface` #E6F2F0 (brand encima 5,61 ✅). Variante destructiva en `danger`, presionado `dangerSurface`.

**4. Campo de formulario — `PagateTextField`**
Etiqueta **encima y siempre visible**, `titleSmall` 14/600 `textSecondary`, 8 dp de separación. Se borra el `toUpperCase()` con tracking 0,8 de `PagateLabel` (pagate_label.dart:20-25) y el propio widget: la etiqueta se integra en el campo.
Caja: alto mín. 48, padding 12/12, radio 8, fondo `surface` **blanco** (no gris: es lo que permite que el placeholder cumpla AA), borde 1 `borderField` #7E8794 (3,63 ✅ 1.4.11). Texto escrito `bodyLarge` 16/400 `textPrimary`; placeholder `bodyMedium` 14/400 `textMuted` #636C7A (5,31 ✅).
Foco borde 1,5 `brand` dibujado hacia adentro · error borde 1,5 `danger` + mensaje `bodySmall` 13 `danger` a 4 dp, a la izquierda · deshabilitado fondo `sunken`, borde `hairline`, texto `textMuted` · solo lectura igual pero texto `textPrimary`.
Sin `prefixIcon` decorativo: se quitan los de email/candado (pagate_text_field.dart:76-91) y los de lápiz/dólar/notas (transaction_form_sheet.dart:228, :241, :276). La etiqueta ya dice qué es.
Variante `.amount`: prefijo `$` fijo en `textMuted` dentro del campo, `AppText.amountField` 20/600 tabular, alineado a la derecha, teclado numérico.
**Adiciones obligatorias al constructor** (hoy no existen, y por eso ninguna pantalla puede ponerlas): `textInputAction`, `onFieldSubmitted`, `autofillHints`, `focusNode`, `textCapitalization`. En todo lib/ hay **1 solo `textInputAction`** (ia_tab.dart:344) y **0 `autofillHints`**. Login y registro se envuelven en `AutofillGroup` con `.name / .email / .newPassword`, `next` entre campos y `done` en el último.
Esto reemplaza `app_theme.dart:189-234` entero.

**5. Fila de dato — `PagateDataRow` (etiqueta / valor)**
El componente más necesario de la app y el que no existe: hoy está reinventado **seis veces** con seis criterios distintos de peso, color y alineación, y ninguna con cifras tabulares — `_StatRow` (finanzas_tab.dart:280), `_DetailRow` (detalle_item_screen.dart:383), `_ContactRow` (ayuda_screen.dart:259), `_ItemRow` (configuracion_screen.dart:235), `_MiniStat` (home_tab.dart:247), `_StatItem` (perfil_tab.dart:208).
Alto mín. 48, padding H 16 V 12, fondo `surface`. Etiqueta `bodyMedium` 14/400 `textSecondary` en `Expanded`; valor `AppText.amountRow` 16/600 tabular `textPrimary`, `textAlign: right`, **sin ancho fijo**. Divisor `hairline` 1 dp a sangre salvo en la última fila.
Variante `emphasis`: valor en `displaySmall` 24/700, `textPrimary` si ≥0 y `moneyOut` si <0.
Si navega: `InkWell` + chevron 20 dp `textMuted`, presionado fondo `sunken`.

**6. Sección — `PagateSectionCard`**
No es una tarjeta. Móvil (<720 dp): fondo `surface` a sangre, ancho completo, **radio 0**, borde superior e inferior 1 dp `border`, padding vertical 4 y horizontal 0 (las filas traen el suyo). Escritorio (≥720 dp): radio 12, margen H 16, borde en los cuatro lados. **Cero sombra** y se elimina el `Theme.of(context).brightness == Brightness.dark ? AppShadows.none : AppShadows.sm` de pagate_section_card.dart:29-31 y el `xxlBorder` de :24.
Separación entre secciones: 24 dp de `canvas` visible. Prohibido anidar una dentro de otra.

**7. Fila de movimiento — `PagateMovementRow`**
Alto mín. 64, padding H 16 V 12. **Sin círculo de icono de color a la izquierda**: hoy home_tab.dart:551-563 y finanzas_tab.dart:806-820 dibujan un círculo de 36 dp teñido que duplica una información que el signo del monto ya da, y roba ~48 dp de ancho al nombre.
Izquierda (`Expanded`): título `titleMedium` 15/600 `textPrimary`, `maxLines: 1`, `ellipsis`; 4 dp; metadato `bodySmall` 13/400 `textMuted` con formato `12 oct · Materiales`.
Derecha: monto en `AppText.amountRow` 16/600 tabular, `textAlign: right`. Ingreso `+$120.000` en `moneyIn` #0B6A47 (6,63 ✅). Gasto `−$35.000` con U+2212 en `textPrimary`, **no en rojo**.
Divisor `hairline` a sangre. Presionado fondo `sunken`. Deslizar de derecha a izquierda: fondo `dangerSurface` #FBEAE8, icono `delete_outline` 20 dp + "Eliminar" en `danger` (6,49 ✅), a 16 dp del borde, con `confirmDismiss`.
Dos arreglos obligatorios: (a) el `Dismissible` de finanzas_tab.dart:738 **no define `onDismissed`** y depende de que el stream de Firestore reemita antes de que termine la animación — hay que definirlo; (b) el gesto es hoy el **único** camino para borrar un movimiento, lo que lo hace imposible para un usuario de lector de pantalla o con temblor: se añade `customSemanticsActions: {CustomSemanticsAction(label: 'Eliminar movimiento'): …}` y, mejor, un toque que abra el detalle con acciones explícitas.

**8. Encabezado de sección — `PagateSectionHeader`**
Alto 44, padding H 16, 16 dp de aire arriba y 8 abajo, fondo `canvas` (va **fuera** de la sección blanca). Izquierda `titleLarge` 16/600 `textPrimary`; derecha opcional un botón de texto ("Ver todos", "Agregar"). Sin versalitas, sin icono, sin contador entre paréntesis, sin línea debajo.
Variante `overline` para agrupar dentro de una lista larga ("HOY", "AYER"): alto 32, fondo `sunken`, `labelSmall` 11/600 mayúsculas `textSecondary` (6,91 ✅), pegajosa. Es el único sitio de la app con mayúsculas.
Sustituye a `_Section` (configuracion_screen.dart:192-220, mayúsculas con `letterSpacing: 1.2` sobre un contenedor de radio 32) y a `_SectionLabel` (setup_inicial_screen.dart:228-240), que hoy son criterios opuestos.

**9. Selector de periodo — `PagateMonthSelector`**
Hoy está enterrado dentro de `_FinanzasHeaderState` (finanzas_tab.dart:152-192) y es el control más importante de la pantalla. Se extrae a `core/widgets/` y se comparte con Inicio.
Alto total 44 (32 del ítem + 6+6), `ListView` horizontal, padding H 16, separación 8, con **scroll inicial posicionado en el seleccionado** (hoy no lo hace). Ítem: alto 32 (caja táctil 48), padding H 12, radio 8, `labelMedium` 13/600.
Seleccionado fondo `brand`, texto blanco (6,43 ✅). No seleccionado fondo transparente, texto `textSecondary`, **sin borde** (hoy finanzas_tab.dart:177-181 pinta un borde en cada no seleccionado y convierte la fila en una reja).
Etiquetas: el mes en curso se llama "Este mes"; los anteriores "sep 25". Borde inferior 1 dp `border` a ancho completo, `pinned`.
**Arreglo obligatorio**: la lista sale de `provider.months` (finanzas_tab.dart:107-109), que solo contiene los meses que el trigger llegó a escribir. Si hay datos de enero a agosto y estamos en septiembre sin movimientos, no hay chip de septiembre y `selectedMonthKey` cae a agosto: la pantalla abre en un mes pasado sin forma de volver al actual. El componente garantiza siempre un chip para `currentMonthKey`. Si solo hay un mes, no se dibuja.
Semántica: `Semantics(selected: isSelected, inMutuallyExclusiveGroup: true)` o, mejor, `ChoiceChip`.

**10. Chip de filtro — `PagateChipSelector`**
Alto 32 (caja táctil 48), padding H 12, radio 8, borde 1, `labelMedium` 13/600. `Wrap` con spacing 8.
No seleccionado: fondo `surface`, borde `border`, texto `textSecondary`. Seleccionado: fondo `brandSurface` #E6F2F0, borde `brand`, texto `brand` (5,61 ✅). Deshabilitado: fondo `sunken`, borde `border`, texto `textDisabled`.
Sin animación y **sin opacidades**: hoy pinta `brand` al 15% y un borde al 40% (pagate_chip_selector.dart:60, :65), que es lo que impide saber el ratio real.
Unifica los cuatro patrones de selección que hoy coexisten: este, `_TypeTab` (inventario_tab.dart:286), `_PillSelector` (setup_inicial_screen.dart:242) y las pastillas de editar_perfil_screen.dart:189 y :239.

**11. Estado vacío y de error — `PagateEmptyState` / `PagateErrorState`**
Alineados a la **izquierda**, padding H 16 V 24, dentro de una sección. **Sin ilustración y sin icono grande**: hoy hay cuatro reimplementaciones con iconos de 32-48 dp centrados (finanzas_tab.dart:685 y :700-704, financial_charts.dart:475, inventario_tab.dart:335-353, home_tab.dart:478-502).
Vacío: título `titleLarge` 16/600 `textPrimary` ("Sin movimientos en septiembre") · 8 dp · descripción `bodyMedium` 14/400 `textSecondary`, máx. 2 líneas, que dice qué hacer · 16 dp · botón secundario con la acción. Regla de copy: la descripción dice qué falta y el botón dice qué hacer; prohibido un "Aún no hay actividad registrada" (home_tab.dart:489) sin acción al lado.
Error: mismo bloque con fondo `dangerSurface` #FBEAE8, radio 8, borde 1 `danger`, título en `danger` (6,49 ✅) y botón secundario "Reintentar". Se borra el icono `AppIconSize.hero` de 48 dp (pagate_error_state.dart:32), el `Center` (:73), el `textAlign: center` (:37) y el `pillBorder` (:53). **Se exporta en `widgets.dart`.**

**12. Esqueleto de carga — `PagateSkeleton`**
No existe: grep de `Shimmer|Skeleton` sobre lib/ da 0 resultados, y hay 11 `CircularProgressIndicator`, varios a pantalla completa (finanzas_tab.dart:35 y :651, home_tab.dart:467-470). Un spinner centrado no dice cuánto contenido viene ni evita el salto de layout.
Rectángulos fondo `skeleton` #EAECF0, radio 4, con la **altura del texto que sustituyen**: 13 dp para `bodySmall`, 16 para `titleMedium`, 24 para `displaySmall`, 42 para la cifra héroe. Anchos fijos por posición (60%, 40%, 80%), nunca aleatorios entre frames.
Animación: opacidad 1,0 → 0,55 → 1,0 en 1200 ms, `Curves.easeInOut`, en bucle, con `TweenAnimationBuilder`. **Sin barrido diagonal ni gradiente** (no hay gradientes en el sistema) y sin paquete extra.
Composiciones listas: `PagateSkeleton.balance()` y `PagateSkeleton.rows(5)`. El `CircularProgressIndicator` sobrevive en un solo sitio: dentro del botón primario mientras guarda.

**13. Barra de navegación inferior — `PagateBottomNav`**
Sustituye al `Container` + `Row` de `_NavButton` montado a mano (dashboard_screen.dart:205-240, :279-352). **Se usa `NavigationBar` de Material 3**, que trae de fábrica el rol de pestaña, el estado seleccionado y el alto mínimo — que es exactamente lo que hoy falta: `_NavButton` es un `GestureDetector` (:293) y TalkBack no sabe ni que es una pestaña ni cuál está activa.
Alto 56 + `SafeArea` inferior. Fondo `surface`, borde superior 1 dp `border`, `elevation: 0`, `indicatorColor: Colors.transparent`, `labelBehavior: alwaysShow`. **Sin sombra y sin degradado**: se borra el indicador de 3 dp pintado con `brandGradient` (:306-314).
Icono 24 dp: activo relleno en `brand`, inactivo contorno en `textMuted` #636C7A (5,31 ✅). Etiqueta `labelSmall` 11/600. El estado activo se comunica por color + relleno del icono + peso: tres señales, ninguna es solo color.
Se elimina la variante `compact` por debajo de 380 dp que hoy esconde las etiquetas (:222, :331): un icono sin etiqueta no se entiende. Si no cabe, la etiqueta baja a 10 dp.
El `NavigationRail` de escritorio (:126-178) se estiliza hoy inline con 8 colores oscuros porque **no existe `navigationRailTheme` en ninguno de los dos temas**: se añade al tema claro.

**14. Hoja modal — `PagateSheet`**
`showModalBottomSheet(isScrollControlled: true, useSafeArea: true, backgroundColor: surface, elevation: 0)` con scrim `#101828` al 40%. Radio 16 arriba, 0 abajo. Altura máxima 0,9 de pantalla.
Asa 32×4, radio 4, `borderField`, 8 dp de margen superior. Cabecera alto 52: título `headlineSmall` 18/600 `textPrimary` **a la izquierda**, botón de cerrar 24 dp con caja de 48 y `tooltip: 'Cerrar'` a la derecha, `hairline` debajo. Sin icono de color a la izquierda del título (hoy transaction_form_sheet.dart:187-201 pone un cuadrado teñido según el tipo).
Cuerpo: padding H 16, scroll propio, respetando `MediaQuery.viewInsets.bottom`. Pie fijo: `hairline` arriba, padding 16, fondo `surface`, botón primario a ancho completo; si hay acción secundaria va **encima**, no al lado. **El pie no lleva degradado de desvanecido** (se borra `fadeToWhite`, identity_step_screen.dart:236-239).
Absorbe los cuatro `AlertDialog` de finanzas_tab.dart:400 y :865 y detalle_item_screen.dart:275 y :332. Y corrige que hoy el `elevatedButtonTheme` impone `minimumSize: Size(double.infinity, 56)` (app_theme.dart:244), lo que dentro del `OverflowBar` de un diálogo apila los botones a ancho completo y descoloca la jerarquía Cancelar / Eliminar: las acciones de diálogo llevan su propio `styleFrom` sin `minimumSize` infinito.
**`PopScope` obligatorio** en las dos hojas con formulario (transaction_form_sheet.dart:33, inventario_tab.dart:28) y en las dos pantallas de formulario: hoy hay **0 `PopScope`** en todo lib/ y el botón atrás descarta cinco campos escritos sin avisar.

**15. Barra de acción fija — `PagateActionBar`**
Sustituye al `FloatingActionButton.extended` de finanzas_tab.dart:53-66, que flota con sombra propia, tapa la última fila de la lista y además, cuando se deshabilita por error de stream, **sigue viéndose verde y blanco** porque `backgroundColor` y `foregroundColor` están fijados explícitamente (:61-62) y ganan sobre el estado deshabilitado del tema.
Misma estructura que el pie de la hoja modal: `hairline` arriba, fondo `surface`, padding 16, botón primario a ancho completo, sobre la barra de navegación.

**BAJAS** (tres archivos que se borran): `pagate_info_card.dart` (0 consumidores fuera de su archivo, verificado; hay que quitar también `export 'pagate_info_card.dart';` del barrel), `pagate_label.dart` (se integra en el campo) y `pagate_back_button.dart` (círculo de 40 dp → `IconButton(tooltip: 'Volver')` con caja de 48). Fuera de `core/`: `hourly_value/presentation/widgets/glass_card.dart` (1 uso) y `premium_text_field.dart` (3 usos, duplica `PagateTextField`; el propio nombre "Premium" delata que el sistema no cubría el caso).

**ACCESIBILIDAD, transversal a todos los componentes.** Cada control de solo icono lleva `tooltip` o `Semantics(button: true, label:)`; cada control construido con `GestureDetector` pasa a `InkWell`/`IconButton`/`ChoiceChip` (hoy hay 19); cada decorativo va en `ExcludeSemantics` (hoy hay 0); cada gráfico se envuelve en `Semantics(label: 'Ingresos de septiembre 1.850.000 pesos, gastos 940.000, balance 910.000')` con el `CustomPaint` excluido, porque hoy la sección de gráficos es un hueco mudo para el lector. Etiquetas concretas que faltan: `PagateBackButton` → 'Volver' (usado en configuracion_screen.dart:35, ayuda_screen.dart:54, detalle_item_screen.dart:53, editar_perfil_screen.dart:116), home_tab.dart:107 → 'Ayuda' (y el icono pasa de campana a `help_outline`, porque su destino es la Ayuda), detalle_item_screen.dart:65 → 'Actualizar stock', inventario_tab.dart:192 → 'Agregar producto', ia_tab.dart:376 → 'Enviar'.

## Pantalla de inicio

Sustituye a `lib/features/dashboard/presentation/pages/tabs/home_tab.dart` (620 líneas). El orden de arriba abajo es el orden de la pregunta que el usuario trae al abrir la app: *cuánto me queda → de dónde sale → cómo voy → registrar → cuánto vale mi hora → qué pasó → qué me falta*.

Lo primero: el `body` del dashboard se envuelve en `SafeArea(bottom: false)` (dashboard_screen.dart:208). Hoy no la tiene y las cinco pestañas empiezan con 24 dp de padding desde el borde **físico**, así que el avatar y el título quedan bajo la barra de estado en cualquier móvil con notch.

```
┌──────────────────────────────────────────┐
│ ▢  Taller Raíz                        ?  │ 56  titleMedium 15/600
│    María González                        │     bodySmall 13 textMuted
├──────────────────────────────────────────┤ border 1dp
│  Este mes   sep 25   ago 25   jul 25     │ 44  selector pinned
├──────────────────────────────────────────┤ border 1dp
│                                          │ 24
│  BALANCE DE SEPTIEMBRE                   │     labelSmall 11/600/0.6
│  $380.000                                │ 42  displayLarge 40/700 tnum
│                                          │ 20
│  Meta del mes $500.000             76 %  │ 18  bodySmall + tnum brand
│  ████████████████████░░░░░░░              │  6  brand sobre sunken, r4
│                                          │ 24
├──────────────────────────────────────────┤ 8 de canvas
│  Ingresos                    $1.240.000  │ 48  PagateDataRow
│  ────────────────────────────────────────│     hairline a sangre
│  Gastos                       −$860.000  │ 48
│  ────────────────────────────────────────│
│  Gastos fijos                 −$320.000  │ 48
├──────────────────────────────────────────┤ 24
│  ┌───────────────┐   ┌───────────────┐   │
│  │  + Ingreso    │   │  − Gasto      │   │ 48  secundarios, gap 12
│  └───────────────┘   └───────────────┘   │
├──────────────────────────────────────────┤ 24
│  Valor de tu hora           $4.800    ›  │ 48  PagateDataRow pulsable
├──────────────────────────────────────────┤ 24
│  Movimientos                   Ver todos │ 44  PagateSectionHeader
│  ────────────────────────────────────────│
│  Venta feria Lastarria       +$120.000   │ 64  moneyIn
│  12 oct · Ventas                         │
│  ────────────────────────────────────────│
│  Greda 25 kg                  −$35.000   │ 64  textPrimary, no rojo
│  11 oct · Materiales                     │
│  ────────────────────────────────────────│
│  Esmalte celadón              −$18.900   │ 64
│  10 oct · Materiales                     │
├──────────────────────────────────────────┤ 24
│  Stock bajo                          (2) │ 44  solo si hay
│  ────────────────────────────────────────│
│  Filtro de aceite           0 de 5 un.   │ 48  danger
│  ────────────────────────────────────────│
│  Pastillas de freno         2 de 6 un.   │ 48  warning
├──────────────────────────────────────────┤ 32
│    ⌂       ▤       ▣       ◇       ○     │ 56 + SafeArea
│  Inicio Finanzas Invent.   IA    Perfil  │
└──────────────────────────────────────────┘
```

**Por qué cada zona lleva ese dato**

*Barra de identidad (56)*. Avatar cuadrado 32 radio 8, fondo `brandSurface`, iniciales en `labelMedium` `brand` (5,61 ✅). A la derecha `businessName` en `titleMedium` y `name` en `bodySmall` `textMuted`. A la derecha del todo `help_outline` 24 dp con caja de 48 y `tooltip: 'Ayuda'`.
Sustituye a home_tab.dart:65-127, que gasta un círculo de 44 dp con `brandGradient` (:69), un saludo `'Hola, ${…} 👋'` (:90) y una campana con un punto rojo de 8 dp **siempre encendido** (:115-122) que abre la pantalla de Ayuda (dashboard_screen.dart:66). El nombre del negocio informa; el saludo con emoji no. Y se van los tres datos inventados que hoy se presentan como del usuario mientras el perfil carga: `'IA'` como iniciales (:74 — y también en `user_profile_entity.dart:55`), `'Artesano'` (:90) y `'Mi Negocio'` (:97). Mientras no haya perfil se pinta el esqueleto, no un nombre falso.

*Selector de periodo (44, pinned)*. El mismo `PagateMonthSelector` que Finanzas, alimentado por `FinancesProvider.months`. **Esto arregla un bug real, no es estética**: hoy `_BalanceCard` (:141) y `_RecentActivity` (:443) leen el mismo provider compartido, cuyo `summary` depende de `selectedMonthKey`. Si el usuario toca "Julio" en la cabecera de Finanzas y vuelve a Inicio, la tarjeta titulada "Balance del Mes" muestra julio y "Actividad Reciente" muestra los movimientos de julio, sin decirlo. Poniendo el selector arriba, el mes deja de ser un estado invisible y compartido y pasa a ser el filtro global explícito de la app. El título de la sección nombra el mes ("BALANCE DE SEPTIEMBRE"), no "del Mes".

*Bloque de saldo (dato: `finances.summary.balance`)*. Sobre `canvas`, **sin tarjeta, sin fondo de color, sin borde**: es la propia página. Cifra en `displayLarge` 40/700 tabular, `textPrimary` si ≥0 y `moneyOut` si <0, con caída a `displayMedium` 32 si el string supera 11 caracteres (`$123.456.789` son 12) resuelto con `LayoutBuilder`, nunca abreviando.
Sustituye a `_BalanceCard` (:154-161), que combina las cuatro cosas prohibidas a la vez: `brandGradient` (:158), `xxlBorder` 32 dp (:159) y `AppShadows.brandStrong` (:160), un glow verde al 40% con 24 dp de blur. Encerrar la cifra en un degradado obliga a texto blanco sobre verde, que es la razón por la que hoy los mini-stats están en `Colors.white70` (:263, :271) y son ilegibles. Sobre blanco, el número es lo primero que ve el ojo a un brazo de distancia.

*Meta (datos: `finances.monthlyGoal`, `goalProgress`)*. Es el único juicio de valor honesto que la app puede emitir y sale de un campo real del perfil. Si `monthlyGoal == 0`, **la sección no se dibuja**: una línea `bodySmall` con un botón de texto "Definir meta". Barra 6 dp, radio 4, `brand` sobre `sunken` (5,78 ✅).

*Composición (datos: `summary.totalIncome`, `summary.totalExpenses`, `fixedExpenses.fold`)*. Tres `PagateDataRow` responden "de dónde sale ese número" sin abrir Finanzas. Ocupan 144 dp; la tarjeta con degradado de hoy ocupa ~209 dp y dice menos. Los tres valores van en `textPrimary` con el signo − en los gastos: el color del dinero se reserva para las filas de movimiento, que es donde discrimina.

*Registrar*. Dos botones secundarios de 48 dp que abren la misma hoja modal con el tipo preseleccionado (`showTransactionSheet(context, initialType:)` ya existe, dashboard_screen.dart:78, :80). Se eliminan las cuatro "Acciones Rápidas" (:297-322) con sus cuatro `Color(0x…)` literales — `#00C2B8` (:301), `#EF4444` (:307), `#3B82F6` (:313), `#F97316` (:319), de los cuales el turquesa y el naranja **no existen en `AppColors`** — y el icono robot `smart_toy_outlined` (:317). Dos de las cuatro (Inventario, IA) no son acciones sino destinos que ya están en la barra inferior: duplicar la navegación en la portada es ruido.

*Valor de tu hora (dato: `profile.hourlyRate.hourlyValue`)*. Una `PagateDataRow` pulsable, con "Calcular" en `brand` si es `null`. Es la promesa diferencial del producto y hoy no aparece en ninguna parte de la portada: está enterrada detrás de Perfil. Cuesta 48 dp.

*Movimientos (dato: `finances.transactions.take(5)`)*. `PagateSectionHeader` + "Ver todos" (cambia a Finanzas con el mismo mes) + cinco `PagateMovementRow`.
Estados, y aquí hay otro arreglo funcional: `_BalanceCard.build` (:140-241) **no consulta `finances.error` ni `isLoading` en ninguna línea**, así que ante un `permission-denied` o un fallo de red muestra "$0" (:196), la etiqueta "Sin datos" (:185) y "Registra tus primeros ingresos y gastos" (:232) — presenta un fallo como si el usuario no tuviera datos, contra el principio 5 de `docs/ARQUITECTURA.md`. Solo `_RecentActivity` (:460-465) lo hace bien con `PagateErrorState` + `finances.retry`. Ese patrón se replica en el bloque de saldo y en la composición: si `error != null` → error con reintento; si `isLoading` → `PagateSkeleton`.

*Stock bajo (dato: `inventory` con `stockStatus != ok`)*. **Solo existe si hay algo que decir**; si no hay, la sección no se dibuja y no hay estado vacío de stock en Inicio. Hasta 3 filas: nombre a la izquierda, "0 de 5 un." en `AppText.amountSmall` tabular a la derecha, en `danger` si `stock == 0` y `warning` si `0 < stock <= minStock`. Es el único sitio de Inicio donde aparece ámbar o rojo, y por eso se ve.

*Lo que ya no está: los tres gráficos.* `_ChartsSection` (:408-435) apila `MonthlyBarChart` (220 dp), `NetBalanceLineChart` (200 dp) y `CategoryPieChart` (140 dp), cada uno dentro de un `_ChartCard` con padding y título. Suman ~834 dp de los ~1.697 totales de la pantalla: el **49% del scroll**. En 360×800 el viewport útil es ~712 dp, así que "Actividad Reciente" empieza a los ~1.183 dp, a 1,7 viewports. Y dos de los tres muestran "Aún no hay datos mensuales" (financial_charts.dart:30 y :170) hasta que el usuario tiene dos meses registrados: durante las primeras semanas ese 49% es espacio vacío con un mensaje. Los gráficos se van a Finanzas, que es donde el usuario llega con intención de analizar; el de torta se sustituye allí por barras horizontales de categoría con etiqueta, monto y porcentaje.

**Resultado medido**: con el nuevo orden, los primeros 712 dp entregan el balance, la meta, las tres cifras de composición, las dos acciones, el valor hora y **4 movimientos reales**. Hoy entregan 4 cifras, 4 botones de colores y medio gráfico vacío.

**Desbordes que hay que arreglar de paso**, verificados a 1,3x: la cabecera "Balance del Mes" + la pastilla del mes (:165) desborda **+13 px con el ajuste "Grande" de Android**, y la fila de dos `_MiniStat` (:203) desborda +42 px a 2,0x en 360 dp. Causa común: `Row` con hijos de ancho intrínseco sin `Flexible`. En el diseño nuevo no hay ninguna fila así: el título va en `Expanded` y el valor en un `Text` alineado a la derecha sin ancho fijo.

## Pantalla de bienvenida

Sustituye a `lib/features/auth/presentation/pages/welcome_screen.dart` (388 líneas; se borran unas 250). Es la primera pantalla que ve un revisor de Google Play y un usuario nuevo: tiene que contar qué hace la app en cinco segundos y no prometer nada que la app no haga.

Se borra el `Theme(data: AppTheme.lightTheme)` de :28-29, que existía solo porque el resto de la app corre forzada en oscuro; con tema único claro sobra. Con él se va el `import 'dart:ui'` de :1.

```
┌──────────────────────────────────────────┐
│                                          │ 40
│ ▪ Págate                                 │ 28  wordmark 20/700
│                                          │ 40
│ Saber cuánto ganas                       │
│ cada mes y cuánto                        │ 30x3  headlineLarge 24/700
│ vale tu hora.                            │
│                                          │ 16
│ Registra tus ventas y tus gastos en      │
│ segundos. Págate calcula tu resultado    │ 23x3  bodyLarge 16/400
│ del mes y el precio mínimo de tu         │       textSecondary
│ trabajo.                                 │
│                                          │ 32
│ ▫  Ingresos y gastos del mes, al día     │ 28
│                                          │ 12
│ ▫  Valor de tu hora según tus horas      │ 28
│    reales                                │
│                                          │ 12
│ ▫  Reporte en PDF para tu contador       │ 28
│                                          │
│            (espacio flexible)            │ Spacer
│                                          │
│ ┌──────────────────────────────────────┐ │
│ │            Crear cuenta              │ │ 48  primario brand
│ └──────────────────────────────────────┘ │
│                                          │ 16
│ ¿Ya tienes cuenta?  Inicia sesión        │ 48  bodyMedium + brand
│                                          │ 16
│ Al continuar aceptas los Términos y la   │ 18  bodySmall 13
│ Política de privacidad.                  │ 18  textMuted + 2 enlaces
│                                          │ 24 + SafeArea
└──────────────────────────────────────────┘
```

**Por qué cada zona**

*Wordmark a la izquierda (40 dp de aire)*. Cuadrado 28 dp radio 8 en `brand` + "Págate" en `headlineMedium` 20/700 `textPrimary`. Hoy el logo es un `Icons.paid_outlined` (:81) dentro de un círculo con `AppShadows.brand` (:78) y centrado (`MainAxisAlignment.center`, :70), mientras en el splash y en el rail la marca es `Icons.bolt_rounded` (dashboard_screen.dart:146): son dos marcas distintas para la misma app. Hasta que exista un logotipo, el wordmark es honesto, consistente y no cuesta nada. El logo centrado es el gesto de landing page que hay que quitar; en el eje izquierdo se lee igual y el resto de la pantalla hereda la alineación.

*Titular de tres líneas, alineado a la izquierda*. "Saber cuánto ganas cada mes y cuánto vale tu hora." Dice literalmente lo que la app calcula, con las palabras que el usuario usaría. Reemplaza a "Tu talento crea, / nosotros calculamos." (:184-186), que además lleva un `TextDecoration.underline` en color de marca sobre media frase (:189) — subrayar para dar énfasis es decoración, no jerarquía; si hace falta énfasis, es peso tipográfico. Y "nosotros calculamos" es una promesa vaga.

*Párrafo*. Descriptivo, sin superlativo. Se borra "La primera herramienta financiera diseñada por y para artesanos" (:202): es una afirmación de primacía no verificable, y en la ficha de Play una afirmación así es material para rechazo por *misleading claims*.

*Tres pruebas*. Icono de contorno 20 dp `textMuted` + `bodyMedium` 14/400 `textPrimary`. Cada una corresponde a una funcionalidad **que existe en el repo**: `FinancesProvider` + `months/`, la feature `hourly_value`, y `core/services/pdf_report_service.dart`. Son tres afirmaciones comprobables, sin tarjeta, sin iconos de colores, sin cifras.
Sustituyen al bloque de ilustración entero (:108-172): un `SizedBox` de 340×340 con un círculo de 280 dp que lleva `LinearGradient` decorativo (:120-127), un borde blanco al 50% sobre fondo claro (invisible), `AppShadows.xl` con 40 dp de blur y 20 de offset (:134), y un `Icons.handyman_outlined` de 80 dp al 30% de opacidad sin función (:137). Y sobre todo sustituyen a las dos `_FloatingStatsCard` que flotan encima mostrando **"+24%" con etiqueta "GANANCIA"** (:149-154) y **"Optimizado" con etiqueta "STOCK"** (:162-167): cifras fabricadas presentadas con el lenguaje visual de un dato real del usuario. La clase `_FloatingStatsCard` entera (:321-387) existe solo para eso y se borra. Es el patrón prohibido completo —tarjetas flotando sobre un hero + métricas inventadas— en un solo bloque, y además un usuario de TalkBack **oye literalmente "GANANCIA, +24%"** como si fuera su dato, porque no hay un solo `ExcludeSemantics` en la app.
Se borra también el "orbe" de :41-58: un `Positioned(top: -100, left: -50)` con un círculo de 400×400 en `brand` al 8% envuelto en `BackdropFilter(ImageFilter.blur(sigmaX: 80, sigmaY: 80))` (:53-54) cuyo hijo es un `SizedBox.shrink()` — el filtro se aplica sobre un área de 0×0, no produce ningún efecto visible y solo cuesta un `saveLayer`. Es el blob de fondo prohibido, y ni siquiera funciona.
El espacio recuperado son ~380 dp que hoy empujan el mensaje real fuera de la primera pantalla en dispositivos de 640 dp.

*Acciones — y aquí hay un bug funcional que se ve en el APK que va a Play.* `GoogleAuthService.isAvailable` es `kIsWeb` (google_auth_service.dart:20), así que el bloque `if (googleAvailable)` (:239-246) **no se renderiza nunca en Android**. El botón de Apple (:247-254) sí se renderiza siempre y al pulsarlo solo muestra "Apple Sign-In estará disponible próximamente" (:252). Resultado hoy en el build de Play: el usuario ve dos opciones de arranque y la única visible es un botón muerto.
Se elimina el botón de Apple. Queda un único botón primario, "Crear cuenta", que lleva a `IdentityStepScreen`. Se quita el "(Gratis)" de "Empezar ahora (Gratis)" (:225): el precio va en la ficha de Play, no dentro de un botón, y comprometerlo ahí ata el modelo de precios. El botón de Google vuelve a aparecer en cuanto exista `google_sign_in` en móvil, con el asset oficial de marca y no el `Icons.g_mobiledata` genérico que hoy usa (:242), que incumple las directrices de *Sign in with Google*.

*Enlace de sesión*. "¿Ya tienes cuenta? " en `bodyMedium` `textSecondary` + "Inicia sesión" en `bodyMedium` 14/600 `brand` (6,43 ✅), dentro de un `InkWell` de 48 dp de alto, a la izquierda. Se elimina "¿Ya eres parte de la comunidad?" (:275).

*Legal — bloqueante de publicación.* Una sola línea en `bodySmall` 13/400 `textMuted` #636C7A (5,31 ✅, hoy es `textTertiary` a 2,54 y además con `fontSize: 10` forzado en :296) con "Términos" y "Política de privacidad" como dos `TapGestureRecognizer` en `brand` que **abren las URLs reales** con `url_launcher`.
Hoy la línea :292 afirma "Al continuar, aceptas nuestros Términos y Privacidad" y el `TextButton` de :301-306 responde con un snackbar: "Puedes revisar los términos desde configuración". En `configuracion_screen.dart` no existe ninguna sección de términos ni de privacidad, y un grep por `érmino|Privacidad|privacy` en todo `lib/` devuelve 5 coincidencias: las 3 de esta pantalla y las 2 de `identity_step_screen.dart:214,219`, que también están pintadas en color de marca como si fueran enlaces pero son `TextSpan` **sin `recognizer`**. No existe ni pantalla, ni URL, ni webview. **Google Play exige una política de privacidad publicada y enlazada desde la ficha y desde la app.** Esto bloquea el lanzamiento y no lo resuelve el diseño (ver `riesgos`).

**Decisión de contenido que tomé y conviene saber**: descarté poner en la bienvenida un bloque de muestra con cifras de ejemplo rotuladas "Datos de ejemplo". Enseña mejor el producto, pero reintroduce exactamente la superficie de revisión que acabamos de quitar con el "+24%", por cero necesidad: la muestra del producto va en las **capturas de la ficha de Play**, tomadas de Inicio con datos reales después del rediseño, no dentro de la app.

## Lector de boletas

Tres superficies nuevas que entraron con el carril del lector y que este documento no describía: la **hoja de origen** (`lib/features/receipt_scan/presentation/widgets/hoja_origen_de_ficha.dart`), la **pantalla de revisión** (`…/pages/lectura_boleta_screen.dart`) y la **hoja de revisar el artículo** (`…/widgets/hoja_revisar_articulo.dart`). Se documentan aquí a posteriori, que es una deuda y conviene decirlo: entró una pantalla completa y dos hojas modales sin pasar por la especificación visual aprobada.

El principio que ordena las tres es uno y no es estético: **la app propone, el usuario confirma**. Nada de lo que sale de una fotografía entra al inventario sin que una persona lo haya visto en una lista y pulsado un botón. De ahí salen las dos decisiones que más forma le dan al diseño: que la revisión sea una pantalla y no una hoja, y que la lista no sea editable en línea.

### Hoja de origen — de dónde sale la ficha

Cuelga del FAB de la pestaña de inventario y de la acción del estado vacío, los dos a través de `abrirAgregarAlInventario()`. Es el componente 14 (`PagateSheet`, alto máximo 90% de la pantalla) con cuatro filas del componente 5 (`PagateDataRow` navegable, 48 dp, chevron, presionado `sunken`).

```
┌──────────────────────────────────────────┐
│  Agregar al inventario                ✕  │ 56  PagateSheet, titleLarge 16/600
├──────────────────────────────────────────┤ hairline
│  Escribir la ficha a mano             ›  │ 48  PagateDataRow navegable
│  Como hasta ahora                        │     bodySmall 13 textMuted
│  ────────────────────────────────────────│     hairline a sangre
│  Tomar una foto de la boleta          ›  │ 48
│  Se abre la cámara del teléfono          │
│  ────────────────────────────────────────│
│  Elegir una imagen de la galería      ›  │ 48
│  Una que ya tengas guardada              │
│  ────────────────────────────────────────│
│  Buscar el archivo en el teléfono     ›  │ 48  última: sin divisor
│  Un PDF o una imagen, por ejemplo en     │     bodySmall 13 textMuted
│  Descargas                               │
│                                          │ 16
│  También puedes compartir una boleta o   │     bodySmall 13 textMuted
│  un PDF a Págate-IA desde WhatsApp o el  │     texto, NO un control
│  correo, sin pasar por aquí.             │
│                                          │ 16  bodyPadding
└──────────────────────────────────────────┘
```

**Cuatro entradas de lectura, y la cuenta importa porque los documentos de Play la copian.** Cámara, galería, archivo guardado en el teléfono y compartir desde otra app. El contrato del repositorio lo dice literalmente («Las cuatro entradas se reducen a `ReceiptDocument`»). Las tres primeras son filas pulsables porque la app puede iniciarlas; la cuarta llega de fuera y por eso es texto. Lo que fija la de compartir es el manifiesto: `AndroidManifest.xml` declara `ACTION_SEND` y `ACTION_SEND_MULTIPLE` para `image/*` y `application/pdf`, y **ningún** `ACTION_VIEW`. La de archivo usa `file_picker` sobre el marco de acceso al almacenamiento de Android, que **no exige ningún permiso**: verificado con `aapt2 dump permissions` sobre el APK de release, que mantiene solo `INTERNET` y `ACCESS_NETWORK_STATE`.

*Por qué compartir es una línea de texto y no una fila.* Las otras tres filas se pueden pulsar porque la app puede iniciar esos caminos. El de compartir empieza **fuera**: lo inicia WhatsApp o el correo. Una fila pulsable que no puede hacer nada al pulsarla es un rótulo que no se cumple, así que informa y no promete. La entrega llega por `receive_sharing_intent` y la recoge `receipt_share_listener.dart`, que la convierte en la misma pantalla de revisión con un aviso de entrada («Llegaron 3 archivos. Leí el primero.»).

*Por qué cuelga del FAB y no de un segundo control.* El principio 2 pide una sola acción dominante por pantalla y el 11 pide densidad. Un botón secundario bajo los chips le roba altura a la lista, que es lo que se viene a ver, y un segundo FAB serían dos controles flotantes. El coste es un toque extra en el camino manual, que se paga una vez por ficha.

*En web y escritorio esta hoja no se abre.* `abrirAgregarAlInventario()` va directo al formulario manual cuando `lecturaDeBoletasDisponible` es falso. Ofrecer «tomar una foto» donde el plugin no está registrado produce un `MissingPluginException`, que es un error nativo que no entiende nadie.

*La fila de la galería dice «una imagen», no «una imagen o un PDF».* `image_picker` no tiene ninguna API que devuelva un PDF. El PDF entra por el camino de compartir, que sí lo da, y el pie lo dice.

### Pantalla de revisión — «Revisar la boleta»

```
┌──────────────────────────────────────────┐
│ ←  Revisar la boleta                     │ 56  AppBar, leading tooltip 'Volver'
├──────────────────────────────────────────┤
│                                          │ 16
│  ┌────────────────────────────────────┐  │     franja de avisos
│  │ Saqué pocos artículos. Si la       │  │     warningSurface #FBF0DC
│  │ boleta tenía más, no los leí.      │  │     borde 1 dp warning #B54708
│  │                                    │  │  8  separación entre avisos
│  │ Lo que no aparezca en esta lista   │  │     bodySmall 13 warning (4,81 ✅)
│  │ no lo leí. Compara con la boleta   │  │     r8, padding 12
│  │ antes de guardar.                  │  │
│  └────────────────────────────────────┘  │
│                                          │ 16
├──────────────────────────────────────────┤     PagateSectionCard
│ ☑  Arcilla gres 25 kg     2 × $18.990 ›  │ 48  titleMedium 15/600
│    material · sacos · $37.980 en total   │     bodySmall 13 textMuted
│  ────────────────────────────────────────│     hairline a sangre
│ ☑  Esmalte celadón         1 × $8.500 ›  │ 48
│    Ya existe · stock 3 → 4               │
│  ────────────────────────────────────────│
│ ☐  Pigmento de óxido       1 × $4.200 ›  │ 48  casilla DESMARCADA
│    No encontré este nombre en la boleta  │     bodySmall 13 warning
├──────────────────────────────────────────┤ 24
│  Descartar la lectura                    │ 40  botón de texto destructivo
│  ┌────────────────────────────────────┐  │
│  │        Guardar 2 artículos         │  │ 48  PagatePrimaryButton
│  └────────────────────────────────────┘  │     PagateActionBar + SafeArea
└──────────────────────────────────────────┘
```

**Por qué cada zona es como es**

*Es una pantalla y no una hoja modal.* La lista propuesta puede llevar 40 filas (`kMaxArticulosPorBoleta`). Necesita `Scaffold` propio, `AppBar` con botón de volver y una `PagateActionBar` fija abajo. Una hoja al 90% de alto con 40 filas dentro deja el botón de guardar fuera del alcance del pulgar, que es justo donde no puede estar el único control que confirma la operación.

*Franja de avisos (`warningSurface` + borde `warning`).* No es decoración: es el sitio donde la app admite lo que no sabe. Puede acumular hasta seis avisos y **el último va siempre, en todos los casos**: «Lo que no aparezca en esta lista no lo leí. Compara con la boleta antes de guardar.» Ningún aviso condicional lo sustituye, porque lo que el reconocimiento no vio no aparece en ninguna lista y esa es la única forma honesta de decir que la lista puede estar incompleta. Los condicionales son el aviso de entrada, la degradación del ordenado (cuatro variantes: sin conexión, el modelo falló, no queda cuota, el modelo no reconoció nada), la confianza baja de ML Kit y el recorte por el tope de 40.

*Dos avisos distintos para «salieron pocos», y no uno.* «El texto salió con poco contraste» solo se afirma cuando ML Kit informó una confianza baja de verdad. Decirlo porque salieron dos artículos sería inventar una causa: una boleta de dos materiales es perfectamente normal. Lo que sí se puede afirmar con pocos artículos es que salieron pocos.

*Fila de artículo propuesto (`fila_articulo_propuesto.dart`), alto mín. 48.* Casilla con su propia caja táctil de 48 a la izquierda, y el resto de la fila es un `InkWell` que abre la hoja de revisión: dos zonas inequívocas y grandes, porque tocar el nombre y tocar la casilla hacen cosas distintas. Nombre en `titleMedium` 15/600, `maxLines: 1`, `ellipsis`. Subtítulo en `bodySmall` 13, `maxLines: 2`, en `textMuted` normalmente y en `warning` cuando hay algo que revisar. Chevron 20 dp `textMuted`.

*La cifra de la derecha es `cantidad × precio unitario`, nunca abreviada y con figuras tabulares.* Es la que deja la consecuencia a la vista antes de guardar: con un solo monto en la línea, la diferencia entre leerlo como unitario o como total es el doble de dinero, y esta fila es el único sitio donde el usuario puede verlo antes de que entre al inventario.

*La fila no es editable en línea, y es a propósito.* Cinco campos editables en una fila serían cinco cajas táctiles por debajo de los 48 dp que manda este documento. La fila muestra; la hoja edita.

*El subtítulo carga la información que el color no puede dar.* «No encontré este nombre en la boleta», «Ya existe · stock 3 → 4», «un solo monto en la línea». El ámbar acompaña, nunca es el único portador (WCAG 1.4.1).

*Guarda contra alucinación, y no es un descarte.* Si el nombre que devuelve el modelo no comparte suficientes palabras con el texto del OCR (`kUmbralDePalabrasEnTexto`, 0,6), el artículo **no se tira**: llega con la casilla desmarcada y con la etiqueta que lo dice. Descartarlo en silencio perdería lecturas correctas —el modelo expande legítimamente `ARC GRES` a «Arcilla gres»—; dejarlo marcado violaría «la app propone, el usuario confirma».

*Pie (`PagateActionBar`).* Primario con el recuento vivo: «Guardar 1 artículo» / «Guardar 3 artículos», y con cero seleccionados queda **deshabilitado** y dice «Guardar artículos», no «Guardar 0». Secundario destructivo «Descartar la lectura», que se deshabilita mientras guarda.

*El error de guardado va dentro de la pantalla, no en un aviso flotante.* `PagateInlineError` sobre `surface`, justo encima de la barra de acciones. Un aviso de seis segundos encima del botón que el usuario acaba de pulsar tapa exactamente lo que tiene que volver a pulsar, y el error en línea no se va solo.

*Salir pierde trabajo, así que se pregunta.* `PopScope(canPop: false)` intercepta el gesto del sistema, la flecha de volver y el botón de descartar, y abre un diálogo: «¿Descartar la lectura? Se pierde la lista que revisaste. La boleta no se guardó en ningún sitio, así que tendrías que volver a leerla.» La segunda frase no es relleno: explica por qué no se puede recuperar.

### Los cuatro estados, y ninguno promete lo que no sabe

*Cargando — `ReceiptScanPhase.leyendo`.* «Leyendo la boleta…» en `bodyMedium` y un `PagateSkeleton.rows(4)` dentro de una `PagateSectionCard`. **Sin barra de progreso**: ni ML Kit ni el rasterizado de PDF informan de avance, así que una barra que se mueve afirmaría algo que el código no sabe (principio 7). El esqueleto dice dónde va a estar el contenido sin prometer cuándo. El pie desaparece entero (`SizedBox.shrink`): no hay nada que confirmar todavía.

*Error de reconocimiento — `sinTexto`.* `PagateErrorState` con título «No pude leer nada de esa imagen» y una descripción que da las tres causas accionables: más luz, sin sombra encima, toda la boleta dentro del encuadre. Y cierra admitiendo el límite: «Si el papel está muy desvaído, escribir la ficha a mano va a ser más rápido.»

*Error de archivo — `errorDeLectura`.* El título y la descripción salen de `ReceiptScanException`, que trae su propio texto ya escrito para el usuario y una pista de qué hacer. No hay un «ocurrió un error» genérico: «este PDF está protegido» y «la foto pesa demasiado» se arreglan de formas distintas, y un mensaje único obligaría a adivinar cuál es la tuya.

En los dos errores el pie ofrece **dos salidas y ninguna es un callejón**: primario «Probar con otra foto», secundario «Escribir la ficha a mano».

*Vacío — leyó pero no sacó artículos.* `PagateEmptyState` dentro de una `PagateSectionCard`: «Leí la boleta pero no saqué ningún artículo», con las dos causas posibles dichas como posibles («puede que la foto haya salido con poco contraste, o que esa boleta no tenga una lista de artículos que yo sepa reconocer»). Es un estado vacío de verdad y no un error disfrazado: el archivo se leyó.

*Lectura pobre — hay lista, pero hay que desconfiar de ella.* No es una pantalla aparte: es la lista normal con la franja de avisos cargada y, cuando corresponde, filas con la casilla desmarcada. Esto es deliberado. Una pantalla de «lectura de baja calidad» invitaría a descartarla entera, cuando lo útil es casi siempre quedarse con tres de cinco artículos y corregir los otros dos.

### Hoja de revisar el artículo

Se abre tocando cualquier fila. Es el «el usuario confirma» de «la app propone, el usuario confirma»: todo lo que el reconocimiento pudo equivocar se arregla aquí.

```
┌──────────────────────────────────────────┐
│  Revisar el artículo                  ✕  │ 56  PagateSheet
├──────────────────────────────────────────┤
│  ┌────────────────────────────────────┐  │     solo si notInText
│  │ Este nombre no aparece en el texto │  │     warningSurface + borde warning
│  │ que leí de la boleta. (…)          │  │
│  └────────────────────────────────────┘  │
│  Nombre                                  │ 48  PagateTextField
│  [ Arcilla gres 25 kg                 ]  │
│  Precio por unidad                       │ 48  PagateTextField.amount
│  [ $18.990                            ]  │     tabular, teclado numérico
│  En la boleta había un solo monto en     │     helperText, solo si ambiguous
│  esta línea. Lo tomé como el precio…     │
│  Cantidad          Unidad                │ 48  dos campos, gap 12
│  [ 2          ]    [ sacos          ]    │
│  Tipo                                    │     titleSmall 14/600
│  (Material)  ( Producto )                │ 32  PagateChip, caja táctil 48
│  ── solo si la ficha ya existe ──────────│ 24
│  Ya tienes una ficha así                 │     titleSmall 14/600
│  «Arcilla gres», con 3 sacos en stock.   │     bodySmall 13 textMuted
│  (Sumar al stock)  ( Crear ficha nueva ) │ 32  PagateChip
│  El stock queda en 5 sacos.              │     bodySmall 13 textSecondary
│  Guardado $17.500 · en la boleta $18.990 │     bodySmall 13 textMuted
│  [○──] Actualizar el precio guardado     │ 48  SwitchListTile, APAGADO
│  ──────────────────────────────────────  │ 24
│  Código (opcional)        Ej: GR-25      │ 48
│  Proveedor (opcional)     Ej: Cerámicas… │ 48
├──────────────────────────────────────────┤
│  ┌────────────────────────────────────┐  │
│  │          Guardar cambios           │  │ 48  primaryAction de la hoja
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

**Cada cosa que el código sabe que puede estar mal lo dice en su propio campo**, con `helperText` y no con un aviso general: cantidad fraccionaria → el número que decía la boleta y el que se va a guardar, sin esconder el redondeo; un solo monto en la línea → que se tomó como precio por unidad; nombre que no estaba en el texto → la franja de arriba, con «compáralo con el papel antes de guardarlo».

*El precio guardado no se actualiza por defecto, y no es pereza.* El precio de un producto es a cuánto lo **vende** el usuario; sobrescribirlo con un precio de compra le rompe sus propias finanzas en silencio. Para un material suele interesar, así que está a un toque —con los dos precios a la vista para poder decidir— pero el toque lo da él.

*Los dos campos que el modelo de datos ya tenía y nadie rellenaba.* «Código» y «Proveedor», marcados `(opcional)`. Van al final porque son los únicos que no salen de la lectura. Que ahora se puedan escribir es lo que hace verdad la frase de la política de privacidad que los nombra, y lo que vigila `FUNCIONES_APP.fichaInventarioCompleta` en `landing/src/content/legal-meta.ts`.

*El precio se lee con `parseCurrencyInput`, nunca con `double.tryParse`.* Es el defecto ya documentado en `currency_formatter.dart`: `150.000` escrito como lo escribe un chileno se guardaba como 150 pesos.

*Cerrar con cambios sin guardar pregunta antes* («¿Descartar los cambios?»), por la misma razón que en la pantalla: lo que se pierde no se puede recuperar.

## Qué se elimina

Todos los conteos son de grep verificado sobre `lib/` en la rama `arquitectura-segura`, no estimaciones.

**A. TEMA OSCURO COMPLETO — 251 referencias en 21 archivos**
- `lib/core/theme/app_theme.dart:398-560` — el getter `darkTheme` entero (163 líneas).
- `lib/features/auth/presentation/widgets/app_shell.dart:27-28` — `darkTheme:` y `themeMode: ThemeMode.dark`. La app entera corre en oscuro desde aquí, aunque `lightTheme` existe en :26.
- `lib/features/auth/presentation/widgets/bootstrap_error_app.dart:27` — `theme: AppTheme.darkTheme`.
- `lib/features/auth/presentation/pages/welcome_screen.dart:28-29` — el `Theme(data: AppTheme.lightTheme)` que parcheaba la incoherencia.
- `lib/core/widgets/pagate_section_card.dart:29-31` — la rama `brightness == Brightness.dark`.
- `app_constants.dart:51-55` y `:66-68` — los 8 tokens. Usos: `textSecondaryDark` 84, `textPrimaryDark` 56, `borderDark` 47, `surfaceDark` 36, `backgroundDark` 15, `surfaceDarkSecondary` 10, `textTertiaryDark` 3, `surfaceDarkElevated` **0**.
- 3 tests que montan `darkTheme`: `test/widget_test.dart:16` y `:39`, `test/features/auth/welcome_screen_test.dart:17`.
- Archivos a reescribir: finanzas_tab (42), inventario_tab (23), app_theme (19), ia_tab (19), home_tab (17), detalle_item_screen (16), perfil_tab (15), ayuda_screen (15), editar_perfil_screen (14), financial_charts (13), dashboard_screen (11), configuracion_screen (9), setup_inicial_screen (8), hourly_rate_setup_page (7), transaction_form_sheet (7), login_screen (5), bootstrap_error_app (4), session_error_view (3), splash_screen (2), premium_text_field (1), glass_card (1).

**B. GLASSMORFISMO Y DESENFOQUE**
- `app_constants.dart:77-78` — `glass` (`0x1AFFFFFF`) y `glassStrong` (`0x33FFFFFF`), con 6 consumidores: app_theme.dart:419, :420, :476, :526, :540 y glass_card.dart:27.
- `lib/features/hourly_value/presentation/widgets/glass_card.dart` — **archivo entero**, 37 líneas, docstring literal "Glassmorphism card with blur effect (Dark theme)". Un solo consumidor: hourly_rate_setup_page.dart:231.
- `hourly_rate_setup_page.dart:11` — el comentario que declara "Gradient background, glassmorphism, smooth animations" como característica del archivo.
- `welcome_screen.dart:41-58` — el orbe de 400×400 con `BackdropFilter(ImageFilter.blur(80, 80))` sobre un `SizedBox.shrink()`, y el `import 'dart:ui'` de :1 que queda huérfano.

**C. DEGRADADOS — 4 presets, 16 apariciones**
- `app_constants.dart:86-114` — `brandGradient` (:86-90), `heroGradient` (:92-96, **0 usos**), `fadeToBackground` (:98-105, **0 usos**), `fadeToWhite` (:107-114, 1 uso).
- Los **15 call sites de `brandGradient`**: login_screen.dart:147 · splash_screen.dart:20 · ayuda_screen.dart:76 · dashboard_screen.dart:142 (logo del rail) y :309 (indicador de nav activo) · home_tab.dart:69 (avatar) y :158 (tarjeta de balance) · ia_tab.dart:140, :385, :409 · hourly_rate_setup_page.dart:127 y :207 · detalle_item_screen.dart:89 · perfil_tab.dart:31 y :70.
- `identity_step_screen.dart:238` — el único `fadeToWhite`, que además no puede funcionar: el árbol de :84 es un `Column` con cabecera + `Expanded(scroll)` + contenedor del botón, así que el botón nunca se superpone al scroll y el degradado se dibuja sobre fondo blanco. Con él se va el `SizedBox(height: AppSpacing.hero + AppSpacing.xxl)` = **96 px de espacio vacío puro** de :229.
- 2 degradados declarados inline fuera de tokens: welcome_screen.dart:120-127 y hourly_rate_setup_page.dart.

**D. SOMBRAS — 14 apariciones**
- `app_constants.dart:212-264` — `AppShadows` entero (`none`, `sm`, `md`, `lg`, `xl`, `brand` :249-255, `brandStrong` :257-263) y `:83` `shadowBrand` (`0x40006B5F`, **0 usos**).
- Call sites: `pagate_primary_button.dart:36` (el `Container` de :30-38 existe solo para el glow del CTA de toda la app, con `hasShadow` por defecto en `true` en :14 y :23) · `home_tab.dart:160` (`brandStrong` bajo la tarjeta de balance) · `pagate_section_card.dart:29-31` · `welcome_screen.dart:78`, `:134`, `:345` · `login_screen.dart:149` · `splash_screen.dart:22` · `perfil_tab.dart:33` · `glass_card.dart:30` · `identity_step_screen.dart:334`.

**E. RADIOS ENORMES Y PASTILLAS — 82 de 99 usos son ≥20 dp**
- `app_constants.dart:155-158` (`lg 20`, `xl 24`, `xxl 32`, `pill 100`) y sus `BorderRadius` de `:164-167`.
- Conteo: `xxlBorder` **31**, `pillBorder` **20**, `xlBorder` **18**, `lgBorder` **13**. `AppRadius.pill` como `double` suelto tiene 0 usos directos.
- Cableado en el tema, no en las pantallas: `inputDecorationTheme` con `xxlBorder` en los cinco borders (app_theme.dart:193, :197, :201, :208, :215) · `cardTheme` con `xlBorder` (:180) · `elevatedButtonTheme` (:250) y `outlinedButtonTheme` (:276) con `pillBorder` · `chipTheme` con `lgBorder` (:320) · y sus equivalentes oscuros (:512, :530).

**F. DATOS INVENTADOS Y MARCAS DE "HECHO POR IA"**
- `welcome_screen.dart:149-154` "GANANCIA / +24%" · `:162-167` "STOCK / Optimizado" · `:321-387` la clase `_FloatingStatsCard` entera · `:136-142` el icono `handyman_outlined` de 80 dp al 30% como ilustración.
- `welcome_screen.dart:202` — "La primera herramienta financiera diseñada por y para artesanos."
- `ayuda_screen.dart:73-114` — la tarjeta "Sugerencia del día" con `brandGradient` (:76) e icono de robot, cuyo texto fijo es "Reduce tus gastos fijos en 10% para ganar $830 extra este mes" (:100). Cifra escrita a mano presentada como salida de la IA. Ya estaba registrada como **B2-07 en docs/PLAN.md, sigue en `todo`**.
- `home_tab.dart:115-122` — el punto rojo de 8 dp en `AppColors.error` sobre la campana, sin ninguna condición: siempre encendido, sin sistema de notificaciones detrás, y con destino la pantalla de Ayuda.
- `home_tab.dart:74` `'IA'` como iniciales por defecto (también en `user_profile_entity.dart:55`), `:90` `'Artesano'`, `:97` `'Mi Negocio'`.
- `home_tab.dart:317` `Icons.smart_toy_outlined`, el robot genérico.
- `setup_inicial_screen.dart:123` "Solo tarda 2 minutos" (afirmación inventada sobre un formulario de 4 campos) y `:203` "Empezar a ganar más" como etiqueta de un botón que guarda un perfil.
- `identity_step_screen.dart:111` — "para que puedas recibir pagos globalmente": la app no procesa pagos ni tiene pasarela.

**G. EMOJIS EN TÍTULOS — 2 ocurrencias, las únicas del proyecto**
- `home_tab.dart:90` — `'Hola, ${…} 👋'` (U+1F44B).
- `identity_step_screen.dart:104` — `'¡Hola, artesano! 👋'`.

**H. TITLE CASE INGLÉS — 10 ocurrencias**
`home_tab.dart:169` "Balance del Mes", `:331` "Acciones Rápidas", `:419` "Métricas Financieras", `:453` "Actividad Reciente" · `finanzas_tab.dart:348` "Meta Mensual", `:490` "Gastos Fijos" · `identity_step_screen.dart:160` "Configuración Regional" · `financial_charts.dart:18` "Ingresos vs Gastos", `:163` "Tendencia Mensual", `:312` "Gastos por Categoría". El único correcto hoy es `finanzas_tab.dart:672` "Movimientos del mes". En español la mayúscula va solo en la primera palabra; el Title Case es un calco del inglés y una de las señales más rápidas de texto generado.

**I. STUBS Y AFORDANCIAS FALSAS**
- `welcome_screen.dart:247-254` y `login_screen.dart:95-99` — botón "Continuar con Apple" que solo muestra "estará disponible próximamente".
- `welcome_screen.dart:301-306` — "Ver términos" que muestra un snackbar. **Bloqueante de publicación.**
- `identity_step_screen.dart:214` y `:219` — "Términos" y "Privacidad" pintados en `brand` pero son `TextSpan` sin `recognizer`: no responden al toque. Y el bloque va envuelto en `Center` (:202), rompiendo la alineación del formulario.
- `configuracion_screen.dart:138-155` — dos filas con subtítulo "Próximamente" y snackbar "Próximamente disponible."
- `identity_step_screen.dart:86-90` — `PagateStepHeader(currentStep: 1, totalSteps: 3)` con barra de progreso al 33%, cuando en `features/onboarding/presentation/pages/` solo hay dos archivos y el segundo (`setup_inicial_screen.dart`) no usa `PagateStepHeader` en ninguna línea. Los pasos 2 y 3 nunca existen. Se quita el indicador de ambas: dos pantallas no necesitan barra de progreso.
- `identity_step_screen.dart:159-197` y sus dos builders `:259-302` y `:318-347` — la sección "Configuración Regional" entera, ~130 px que no producen ningún dato: el selector de país es un `Container` con un chevron `expand_more` que **no tiene `GestureDetector`, `InkWell` ni `onTap` en ninguna línea** y no hay campo `country` en el modelo de `docs/ARQUITECTURA.md`; y `_selectedCurrency` (:26) cambia con los tabs pero `_onNext` (:37-73) nunca lo lee, y acto seguido `setup_inicial_screen.dart:31` lo reinicializa y vuelve a preguntar la moneda (:181-186). Coincide con la tarea **B2-04 de docs/PLAN.md** ("quitar país y moneda").

**J. COLORES FUERA DEL SISTEMA — 14 literales**
- `financial_charts.dart:511-520` — `_pieColors`, 10 `Color(0x…)`: seis duplican tokens (006B5F, FF735C, 3B82F6, F59E0B, 10B981, EF4444) y cuatro no existen en la paleta (8B5CF6, EC4899, 14B8A6, 6366F1).
- `home_tab.dart:301, :307, :313, :319` — `#00C2B8`, `#EF4444`, `#3B82F6`, `#F97316`. El turquesa y el naranja tampoco existen en `AppColors`.
- En total, **162 violaciones de tokens en 17 archivos** (colores crudos, `fontSize` numéricos y dimensiones sueltas), concentradas en financial_charts.dart (34) y home_tab.dart (31). De los 51 colores crudos de Material, 38 son `Colors.white` y 7 `Colors.white70`: todos son consecuencia del tema oscuro y desaparecen con la migración.

**K. CONFIGURACIÓN DE TEMA MUERTA — verificada por grep**
- `cardTheme` (app_theme.dart:175-186 y :437-448): el widget `Card` de Material **nunca se usa**; todos los `Card(` del repo son clases propias (`_BalanceCard`, `_ChartCard`, `_DetailCard`, `PagateSectionCard`).
- `chipTheme` (:303-327): `Chip`/`FilterChip`/`ChoiceChip` **nunca se usan**.
- `sliderTheme` (:359-370): no hay ningún `Slider` en la app.
- `bottomNavigationBarTheme` (:449-465): existe **solo en `darkTheme`** y además la app no usa `BottomNavigationBar`.
Los cuatro se borran. A cambio se añade al tema claro lo que la app **sí** usa y hoy no está tematizado: `navigationRailTheme` (dashboard_screen.dart:126 se estiliza inline con 8 colores oscuros), `iconButtonTheme`, `tooltipTheme` y `listTileTheme`.

**L. TOKENS SIN UN SOLO USO — 22, verificados uno a uno**
`brandSubtle` (:28) · `successLight` (:36) · `warningLight` (:38) · `infoLight` (:42) · `surfaceDarkElevated` (:53) · `textLink` (:63) · `shadowLight` (:81) · `shadowMedium` (:82) · `shadowBrand` (:83) · `heroGradient` (:92) · `fadeToBackground` (:98) · `AppSpacing.xxxs` (:124, y además 2.0 rompe la rejilla de 4) · `AppSpacing.xxxxl` (:133) · `AppRadius.pill` como double (:158) · `avatarLarge` (:197) · `avatarHero` (:198) · `iconContainerMedium` (:202) · `iconContainerLarge` (:203) · `borderThick` (:208) · `AppDurations.instant` (:270) · `AppCurves.exit` (:283) · `AppCurves.bounce` (:285, `elasticOut`). Más `AppSpacing.section` (:134, 1 uso) y `hero` (:135, 2 usos), nombres semánticos para lo que debería ser una rejilla numérica.

**M. COMPONENTES QUE SE RETIRAN**
- `lib/core/widgets/pagate_info_card.dart` — **0 consumidores fuera de su propio archivo** (verificado). Hay que quitar `export 'pagate_info_card.dart';` de `widgets.dart:11`. Ya estaba marcado como código muerto en la auditoría previa (2.5, fila B).
- `lib/core/widgets/pagate_label.dart` — las versalitas con tracking 0,8 en `textTertiary` a 2,54:1 (:22-25); se integra en el campo.
- `lib/core/widgets/pagate_back_button.dart` — círculo de 40 dp; pasa a `IconButton` estándar con caja de 48. El mismo círculo está duplicado en `pagate_step_header.dart:45-64`.
- `pagate_step_header.dart:67-83` — la insignia "Paso X de Y" en pastilla `brandLight`.
- `lib/features/hourly_value/presentation/widgets/premium_text_field.dart` (3 usos) y `glass_card.dart` (1 uso).
- `finanzas_tab.dart:53-66` — el `FloatingActionButton.extended` flotante.

**N. CÍRCULOS DE ICONO TEÑIDOS EN FILAS — 4 usos, ~48 dp de ancho robado cada uno**
`home_tab.dart:551-563` · `finanzas_tab.dart:297-305`, `:592-604`, `:806-820`.

**O. DUPLICACIÓN DE FORMATO — cierra el hallazgo A de la auditoría 2.5**
`finanzas_tab.dart:15-24` (`_money`) · `home_tab.dart:243-244`, `:277`, `:610-611` (tres copias de `_fmt` que abrevian a "K") · `financial_charts.dart:499-500` · `pdf_report_service.dart:22-24` · `inventario_tab.dart:435`. Más dos tablas de nombres de mes: `home_tab.dart:613-619` y `finanzas_tab.dart:782-785`.

**P. FUERA DE `lib/`, PERO ENGAÑA A QUIEN DISEÑE DESPUÉS**
`docs/prototipos/components/tokens.jsx:4` declara `brand: '#00C2B8'` (turquesa) contra el `#006B5F` real, `:7` `accent: '#F97316'` (naranja) contra el coral, y `:18-22` define superficies oscuras. Los prototipos describen un producto que ya no existe. O se regeneran desde el sistema nuevo o se borran; dejarlos garantiza que en dos meses alguien los abra creyéndolos la referencia.

## Plan de migración

Diez pasos. Después de cada uno la app compila, `flutter analyze` sigue limpio y `flutter test` pasa. El truco que lo hace posible está en el paso 3, y no es opcional: si alguien intenta pasar la app a claro **borrando** los tokens oscuros en vez de aliasándolos, 21 archivos dejan de compilar a la vez y la única salida es un commit gigante imposible de revisar.

**PASO 0 — Moneda y meses (invisible salvo por las cifras). 1 commit.**
`lib/core/utils/currency_formatter.dart` (`formatCurrency`, `formatSigned`) y `month_labels.dart`. Es la tarea **C-2 que ya está en docs/PLAN.md, Fase 2**, y hay que hacerla **antes** de tocar Inicio y Finanzas o se reescriben esas dos pantallas dos veces. Sustituir las seis implementaciones de formato. Nada de color ni de layout cambia.
Verificación: test de `formatCurrency(1234567, currency: 'CLP') == '$1.234.567'` y de que `formatSigned(-320, …)` empieza por U+2212. Resultado visible: desaparece el "$1234.6K".

**PASO 1 — Tokens nuevos EN PARALELO a los viejos. 1 commit, riesgo cero.**
Se añaden a `app_constants.dart` los 21 tokens nuevos, la escala de espaciado (`x0..x10`), los radios (`r0..r16`), los grosores, `AppSizes.minTouchTarget = 48` y `AppElevation`. **No se borra ni se renombra nada.** La app se ve exactamente igual. Este paso existe para que el resto se revise en diffs pequeños.

**PASO 2 — Tipografía real. 1 commit, aislado a propósito.**
`lib/core/theme/app_text.dart` con el helper `_t` (`fontVariations` + `leadingDistribution: even` + `fontFeatures`), y `_baseTextTheme` (app_theme.dart:21-120) reescrito con la escala nueva. `pubspec.yaml:37-40` se deja como está.
Va **solo** porque es el commit que más cambia la percepción de toda la app y hay que verlo aislado. **Verificación obligatoria en un Android físico, no en emulador**: si hoy todo se está dibujando en ExtraLight sintético, el salto es enorme y hay que ajustar pesos mirando la pantalla, no el código. Es el punto de no retorno del sistema (ver riesgo 1).

**PASO 3 — EL INTERRUPTOR. 1 commit, y es el paso crítico.**
En `app_constants.dart`, los 8 tokens oscuros dejan de ser colores propios y pasan a ser **alias `@Deprecated` de los claros**, conservando su nombre:
```dart
@Deprecated('Tema único claro. Migrar a AppColors.textPrimary. Se borra en el paso 9.')
static const Color textPrimaryDark = textPrimary;      // y surfaceDark = surface,
// backgroundDark = canvas, borderDark = border, surfaceDarkSecondary = sunken,
// textSecondaryDark = textSecondary, textTertiaryDark = textMuted
```
Y en el mismo commit: `AppShadows.* = const []`, `brandGradient = LinearGradient(colors: [brand, brand])` (plano), `AppRadius.pill = 12`, `AppRadius.xxl = 12`, `glass`/`glassStrong` a colores planos; `app_shell.dart:28` → `ThemeMode.light` y fuera `darkTheme:` (:27); borrar `AppTheme.darkTheme` (app_theme.dart:398-560); `bootstrap_error_app.dart:27` → `lightTheme`; fuera el `Theme(data: AppTheme.lightTheme)` de `welcome_screen.dart:28-29`; los 3 tests a `lightTheme`.
**Efecto: sin tocar una sola pantalla, las 251 referencias siguen compilando y toda la app pasa a tema claro, sin sombras, sin degradados y sin radios de 32/100.** `@Deprecated` produce avisos, no errores, así que `flutter analyze` sigue en verde. Todavía es fea, pero es usable, legible, con contraste AA y demostrable: **aquí ya se puede publicar una beta interna.**
Verificación obligatoria: correr la app en un Android real y recorrer las 9 pantallas. Es el único paso donde puede aparecer un texto invisible.

**PASO 4 — `lightTheme` reescrito. 1 commit.**
`colorScheme` con los tokens nuevos; `inputDecorationTheme` con radio 8, borde visible de 1 dp `borderField` y `contentPadding` 12/12; `elevatedButtonTheme`/`outlinedButtonTheme`/`textButtonTheme` con radio 12 y alto 48; `dividerTheme`, `bottomSheetTheme` (radio 16), `dialogTheme`, `snackBarTheme`, y los nuevos `navigationRailTheme`, `iconButtonTheme`, `tooltipTheme`, `listTileTheme`. Se borran `cardTheme`, `chipTheme`, `sliderTheme` y `bottomNavigationBarTheme`, que no pintan nada.
Regla de este commit: **ningún `TextStyle` de componente se construye desde cero**. Los diez `fontSize` que hoy se escriben a mano fuera del `TextTheme` (app_theme.dart:254, :280, :292, :309, :315, :385, :457, :462, :516, :534) pasan a `textTheme.labelLarge?.copyWith(...)`. Si no, esos diez no heredan ni `fontVariations` ni `fontFeatures` y el paso 2 queda a medias.
Toda la app mejora de golpe sin tocar ninguna pantalla, porque casi todo consume el tema.

**PASO 5 — Componentes base. 1 commit por grupo, 3 commits. Solo añade archivos.**
5a: `PagatePrimaryButton` (sin `Container` de sombra, sin `hasShadow`), `PagateTextField` (etiqueta integrada, borde visible, `autofillHints`/`textInputAction`/`onFieldSubmitted`), `PagateChipSelector`. Como los viejos conservan su API pública, las ~20 pantallas que los usan mejoran sin tocarlas.
5b: `PagateSectionCard`, `PagateSectionHeader`, `PagateDataRow`, `PagateMovementRow`, `PagateEmptyState`, `PagateErrorState` (reescrito **y exportado en el barrel**), `PagateSkeleton`.
5c: `PagateBottomNav` (sobre `NavigationBar` de M3), `PagateSheet`, `PagateMonthSelector`, `PagateActionBar`, con reemplazo directo en dashboard_screen.dart y transaction_form_sheet.dart.
Bajas: `PagateInfoCard`, `PagateLabel`, `PagateBackButton`, y `widgets.dart` actualizado.
Verificación: un widget test por componente con `MaterialApp(theme: AppTheme.lightTheme)`, sin Firebase, como ya manda AGENTS.md. Es la red que permite refactorizar pantallas sin miedo.

**PASO 6 — Las cinco pantallas, 1 commit cada una, en este orden de menos a más dependencias.**
6.1 **Bienvenida** (`welcome_screen.dart`) — primera porque no depende de providers y su reescritura es la más agresiva.
6.2 **Registro** (`identity_step_screen.dart`) — hereda campo y botón de 6.1; aquí entra `totalSteps` y el borrado de "Configuración Regional" (tarea **B2-04** del plan).
6.3 **Onboarding** (`setup_inicial_screen.dart`) — hereda chip y sección.
6.4 **Inicio** (`home_tab.dart`, `financial_charts.dart`) — la más compleja: necesita `PagateMonthSelector`, `PagateMovementRow`, `PagateSkeleton` y el formateador, todos ya rodados.
6.5 **Finanzas** (`finanzas_tab.dart`, `transaction_form_sheet.dart`) — reutiliza el 80% de lo que 6.4 dejó montado, y aquí llegan los gráficos que salieron de Inicio, con el donut sustituido por barras de categoría.
Regla en cada commit: al terminar, esa pantalla no contiene ni un `*Dark`, ni un `AppShadows`, ni un gradiente, ni un `pillBorder`, ni un `Color(0x`, ni un `fontSize:` numérico.

**PASO 7 — Barrido del resto. 3-4 commits, sin rediseñar.**
`inventario_tab` + `detalle_item_screen`; `ia_tab` + `ayuda_screen` (fuera el "$830 extra"); `perfil_tab` + `configuracion_screen` (fuera los dos "Próximamente") + `editar_perfil_screen`; `hourly_rate_setup_page` (+ borrar `glass_card.dart` y `premium_text_field.dart`), `login_screen`, `splash_screen`, `session_error_view`, `bootstrap_error_app`.
Solo cinco cosas: sustituir degradados y sombras por borde+superficie, cambiar radios, borrar los stubs y datos inventados de la lista, pasar los montos por el formateador, y añadir `tooltip`/`Semantics` a los controles de solo icono. No se toca el layout.

**PASO 8 — Accesibilidad y localización. 1 commit.**
- `flutter_localizations` en `pubspec.yaml` y, en `app_shell.dart`, `locale: const Locale('es')`, `supportedLocales: const [Locale('es'), Locale('en')]`, `localizationsDelegates: GlobalMaterialLocalizations.delegates`. Son 6 líneas y arreglan que hoy TalkBack lea los roles en inglés y que el `showDatePicker` de transaction_form_sheet.dart:104 se abra en inglés dentro de una app en español.
- `SafeArea(bottom: false)` en `dashboard_screen.dart:208` y en el `Row` del layout de escritorio; `useSafeArea: true` en `showModalBottomSheet` de inventario_tab.dart:28.
- Los 19 `GestureDetector` a `InkWell`/`IconButton`/`ChoiceChip`; las etiquetas de los controles de solo icono; `ExcludeSemantics` en los decorativos; `Semantics(label:)` en los tres gráficos; `customSemanticsActions` en el `Dismissible`; las 11 cajas táctiles a 48.
- `PopScope` en las dos hojas con formulario y en las dos pantallas de formulario.
- `assets/fonts/OFL.txt` con el texto de la licencia, declarado en la sección `assets:` de `pubspec.yaml` y registrado con `LicenseRegistry.addLicense`; entrada "Licencias de terceros" en `configuracion_screen.dart` que abra `showLicensePage`. La SIL OFL exige que la notificación de copyright y el texto acompañen al software de fuente en cualquier redistribución, y hoy la licencia solo existe dentro de la tabla `name` del binario. Media hora de trabajo que cierra un frente legal.

**PASO 9 — Borrar los alias. 1 commit, y es el que valida todo lo anterior.**
Se eliminan de `app_constants.dart` los `@Deprecated` del paso 3 y todos los tokens de la lista `que_se_elimina`. A partir de ahí `flutter analyze` **falla con error de compilación en cualquier referencia superviviente**: es imposible dejar un resto a medias, y cada error señala exactamente una pantalla que el paso 6 o 7 se saltó.
Comprobaciones, todas ejecutables y todas deben dar 0:
```
grep -rn "Dark\b"            lib/ --include=*.dart
grep -rn "AppShadows\|boxShadow" lib/ --include=*.dart
grep -rn "Gradient\|BackdropFilter" lib/ --include=*.dart
grep -rn "pillBorder\|AppRadius.xxl\|AppRadius.xl\|AppRadius.lg" lib/ --include=*.dart
grep -rn "Color(0x"          lib/ --include=*.dart   # fuera de app_constants.dart
grep -rn "GestureDetector("  lib/ --include=*.dart
```

**PASO 10 — Verificación de publicación.**
`flutter analyze` (0 issues), `flutter test`. En un Android **físico**: recorrido completo de las cinco pantallas con el tamaño de fuente del sistema al 100%, **130%** y 200% comprobando que ninguna fila recorta (el 130% es el ajuste "Grande", corriente, y hoy ya desborda Inicio); recorrido con TalkBack sobre la barra inferior, el selector de mes y los botones de solo icono; y pantalla de 320 dp de ancho. Después, capturas de Bienvenida, Inicio y Finanzas a 1080×1920 para la ficha de Play. Y `flutter build appbundle --release` con keystore propio.
Test de regresión que conviene dejar puesto: montar las 5 pantallas a 1,3x y 2,0x y fallar si aparece `RenderFlex overflowed`.

**Documentación que hay que corregir en el mismo hito** (si no, el trabajo se deshace solo): `docs/PLAN.md:109` define B2-04 como "`IdentityStepScreen` con **tokens dark**", que tras la decisión de tema único manda en dirección contraria; `AGENTS.md:64-65` sigue describiendo `lightTheme`/`darkTheme` como el contrato de theming; y `AGENTS.md:67-68` describe un `BottomNavigationBar` que la app no usa (hoy la nav está montada a mano; con el paso 5c pasará a `NavigationBar`, que tampoco es lo mismo). Añadir a PLAN.md un bloque de rediseño con estos diez pasos.

**Regla durante toda la migración**: nadie toca `app_constants.dart`, `app_theme.dart` ni `core/widgets/` fuera de los pasos 0-5. Si un carril necesita un token que no existe, abre tarea al Coordinador; no lo añade. Es el mismo contrato de propiedad de archivos que ya está en `docs/ARQUITECTURA.md`.

## Riesgos y descartes

**QUÉ DESCARTÉ DE CADA PROPUESTA Y POR QUÉ**

1. **El botón primario en negro de "Extracto" (`ink` #0B0F14, 19,22:1).** Descartado. Tiene el mejor contraste posible y resuelve la competencia entre el verde de marca y el verde de ingresos, pero un botón negro en una fintech chilena lee como herramienta de desarrollador, no como Fintual o Mercado Pago, que usan su color de marca para la acción primaria. La propia propuesta lo admite en su riesgo 4: "la app deja de verse Págate". El primario es `brand` #006B5F, blanco encima 6,43 ✅.

2. **El lienzo blanco puro de "Extracto".** Descartado. Con `bg` #FFFFFF y `sunken` #F4F5F7 el contraste entre superficie y fondo es **1,09:1**: los bloques no se separan y toda la jerarquía cae sobre las líneas de 1 px. El par `canvas` #F6F7F8 / `surface` #FFFFFF da la separación con cero coste de contraste de texto.

3. **El lienzo #F6F7F9 con `textSecondary` #6B7280 de "Esmeralda disciplinada".** Descartado. Calculé el par: **4,51:1** contra un mínimo de 4,50. Pasa por 0,01, es decir por un redondeo. Cualquier antialiasing subpíxel, cualquier ajuste de un punto en el lienzo, y falla. `textSecondary` #475467 da 7,69 / 7,17 / 6,91 y no obliga a nadie a vigilarlo.

4. **El ajuste de `brandSurface` de #E6F2F0 a #E7F1EF (o #E8F2F0).** Descartado en las dos propuestas que lo proponían. Comprobé que el valor **actual** #E6F2F0 ya da 5,61:1 con `brand` encima: pasa AA sin tocarlo. Un hex menos que cambiar es un hex menos que revisar.

5. **La columna de monto de ancho fijo (104 dp) de "Extracto".** Descartado, y es el descarte más importante. Verifiqué en `HVAR` que los dígitos tabulares sí son invariantes con el peso (1240/2000 en w200, w600 y w700), pero el `$` va de 1126 a 1256 y el punto de millar de 440 a 607, así que `−$1.234.567` a 17 dp mide 100,0 dp en w200 y 103,9 en w700. Peor: un `SizedBox(width: 104)` **no escala con `textScaler`**, así que reintroduciría exactamente el desborde a 1,3x que hoy bloquea la publicación. El monto va en un `Text` con `textAlign: right` y el título en `Expanded`. Con `tnum` eso basta para que la columna no baile.

6. **La rampa monocroma de gráficos de "Esmeralda disciplinada".** Descartada por su propio autor, con razón: el contraste entre pasos adyacentes es 1,59-1,82, muy por debajo del 3:1 que pide WCAG 1.4.11 cuando el color es el único diferenciador. Y descarté también inventar seis colores de serie: el donut se sustituye por barras horizontales con etiqueta, monto y porcentaje, donde el color es redundante. El hallazgo se cierra eliminando la necesidad.

7. **El bloque de muestra "Datos de ejemplo" en la bienvenida, de "Extracto".** Descartado. Es honesto y enseña el producto en un segundo, pero vuelve a poner cifras fabricadas en la primera pantalla que ve un revisor de Play, que es justo la superficie de riesgo que acabamos de quitar con el "+24%". La muestra del producto va en las capturas de la ficha, tomadas de Inicio con datos reales.

**DOS ERRORES QUE CORREGÍ Y QUE NADIE HABÍA DETECTADO**

8. **`borderField` #868E9B falla 1.4.11 sobre su propio `sunken`.** "Esmeralda disciplinada" lo declara "✅ 1.4.11" comprobándolo solo sobre blanco (3,30) y sobre su lienzo (3,08), pero nunca sobre su propia superficie hundida #EFF1F4: calculado, da **2,92**. Con un campo deshabilitado de fondo hundido, el borde deja de cumplir. Lo subí a **#7E8794**, que da 3,63 / 3,39 / 3,27 en las tres superficies.

9. **`textTertiary` #667085 de "Libreta" falla sobre `sunken`.** La propia propuesta lo admite (4,47 contra 4,50) y lo esquiva exigiendo que los campos tengan fondo blanco, pero deja el color disponible para cualquier metadato sobre una superficie hundida. Lo subí a **#636C7A** (5,31 / 4,95 / 4,77), que cumple en las tres sin excepciones que haya que recordar.

Verifiqué además las **114 relaciones de contraste** que declaraban las tres propuestas: todas correctas, cero discrepancias. Y la paleta final la volví a verificar entera: 30 pares de texto a 4,5:1, 5 de no-texto a 3:1 y 4 de blanco sobre relleno sólido, **cero fallos**.

**RIESGOS REALES DEL SISTEMA**

10. **El peso de la fuente es el único punto que no puedo cerrar desde aquí.** Verifiqué en el binario que `usWeightClass` es 200, que el default de `fvar` es 200 y que `pubspec.yaml:37-40` la registra con un solo asset sin `weight:`, y que en todo `lib/` hay 0 usos de `fontVariations`. Lo que no puedo ejecutar es el render: si el motor de Flutter de esta versión ya mapea `fontWeight` al eje `wght`, hoy se ve bien y añadir `fontVariations` es inocuo; si no lo hace, **toda la app está en ExtraLight con negrita sintética** y la escala hay que reajustarla mirando la pantalla. Se resuelve en el paso 2, en un Android físico, antes de tocar ninguna pantalla. **Plan B si falla**: extraer instancias estáticas 400/600/700 con `fonttools varLib.instancer` y declararlas con `weight:` en `pubspec.yaml`; sube el peso de 161 KB a unos 250-300 KB y obliga a quitar `fontVariations`. Solo entonces es decisión del dueño (aceptar el peso extra).

11. **Los dos verdes.** `brand` #006B5F (teal) y `moneyIn` #0B6A47 (verde) conviven. Los acoté para que no compitan: `moneyIn` aparece **solo** en el monto de una fila de movimiento, a 16 dp; `brand` aparece en el botón primario, la selección de nav, el foco, los enlaces y el relleno de progreso. Son roles y tamaños distintos, pero **hay que mirarlo en dispositivo en el paso 6.4**. Si chocan, la salida no es cambiar el verde de marca: es quitar el color al ingreso y dejar solo el signo `+`.

12. **El gasto corriente en tinta y no en rojo.** Lo propongo porque pintar media lista de rojo mata la jerarquía y convierte un hecho normal en una alarma, y es lo que hacen Mercado Pago y la app del Banco de Chile en el detalle de movimientos. Pero contradice lo que hace hoy el código (home_tab.dart:540, finanzas_tab.dart:790) y es el cambio con más probabilidad de que el dueño diga "no se distingue". **Si lo rechaza, el reemplazo correcto NO es volver a #EF4444 (3,76, falla AA) sino usar `moneyOut` #A32019 (7,56).** Es una línea en `PagateMovementRow`; se puede probar con las dos y elegir en el dispositivo.

13. **Botón de 56→48 y radio de 100→12 cambian la sensación de toda la app.** Es el cambio más visible y el más subjetivo. No hay usuarios en producción todavía, así que el coste es cero ahora y alto después del lanzamiento. Decisión del dueño **antes del paso 4**: confirmar 48 dp de alto y 12 de radio, o fijar otro par y que yo recalcule los componentes.

14. **Densidad contra escalado de fuente.** `bodySmall` 13 dp y `labelSmall` 11 dp son el precio de la densidad. A 200% (que usa buena parte del público mayor de 50), una fila de movimiento de 64 dp necesita crecer a ~110. Por eso todas las alturas son mínimos. Si en el paso 10 algo recorta, la salida **no** es `TextScaler.noScaling` —empeora la accesibilidad y es mal visto en la revisión de Play— sino subir el mínimo de la fila a 72 dp y aceptar menos movimientos por pantalla.

15. **La cifra héroe puede no caber.** `$123.456.789` a 40 dp no entra en 328 dp útiles. La regla es bajar a `displayMedium` 32 por encima de 11 caracteres, con `LayoutBuilder`. La alternativa es abreviar, que es justo lo que estamos eliminando. **Si el dueño prefiere abreviar a reducir, hay que decirlo antes del paso 6.4** porque cambia el componente, no solo el estilo.

16. **Los alias mienten durante 4 o 5 commits.** Entre el paso 3 y el paso 9, `AppColors.textPrimaryDark` devuelve un gris casi negro para texto sobre blanco. Es el precio de no romper la app, pero **si el paso 9 no se ejecuta, esos alias se quedan para siempre** y el sistema vuelve a ser ilegible en seis meses. El paso 9 no es opcional y debe ir en el mismo hito que los pasos 6-8, no "más adelante". Mitigación en el propio commit: `@Deprecated` con mensaje que remite al paso 9, más un comentario de bloque.

**HALLAZGOS DE LA AUDITORÍA QUE ESTA ESPECIFICACIÓN NO RESUELVE**

Cuatro son bugs funcionales, no visuales. Los nombro porque uno de ellos **bloquea la publicación** y ninguno se arregla dibujando:

- **`setup_inicial_screen.dart:58-59` guarda "800.000" como 800 pesos.** `double.tryParse('800.000')` devuelve 800.0 y la validación de :77 (`goal <= 0`) lo deja pasar en silencio. La meta contamina la barra de progreso de Inicio y de Finanzas, que marcarán 100% con la primera venta. El mismo defecto está en `finanzas_tab.dart:440` (un gasto fijo de "50.000" se guarda como 50) y en `transaction_form_sheet.dart:117-122`. Es una app de dinero que hoy guarda mil veces menos de lo que el usuario escribió. **Bloquea publicación.** Corresponde al contrato C-2 y a la tarea B2-03 de docs/PLAN.md; hay que centralizar el parseo junto al formateador del paso 0.
- **`finanzas_tab.dart:393-456`**: el diálogo de gasto fijo cierra con `Navigator.pop(dialogContext, true)` pase lo que pase y libera los controllers en :441-442, así que ante un error el usuario pierde todo lo escrito. Se arregla al convertirlo en `PagateSheet` con `Form` y validación (paso 6.5), pero la validación en sí es trabajo funcional.
- **`setup_inicial_screen.dart:35-45`**: `didChangeDependencies` reinyecta el `displayName` si el campo está vacío, y se dispara con cada cambio de dependencia (teclado, rotación). Si el usuario borra el nombre para escribir otro, se lo vuelve a rellenar, y el cursor salta al inicio.
- **`pdf_report_service.dart:43-44`**: `PdfGoogleFonts.nunitoRegular()` descarga la fuente de fonts.gstatic.com en tiempo de ejecución, así que sin red el botón de exportar gira hasta fallar; y la fuente es Nunito, no Manrope, de modo que el informe que el artesano manda a su contador no se parece a la app. Debería cargar Manrope desde los assets con `pw.Font.ttf(await rootBundle.load(...))` y heredar esta paleta. No bloquea la publicación.

**LO QUE BLOQUEA LA PUBLICACIÓN Y SOLO PUEDE RESOLVER EL DUEÑO**

- **No existen los textos de Términos ni de Política de privacidad.** `welcome_screen.dart:301-306` es un snackbar y `identity_step_screen.dart:214,219` son enlaces falsos sin `recognizer`. Google Play exige una política de privacidad publicada y enlazada desde la ficha y desde la app. Hay que publicarlas en el dominio de la landing y abrirlas con `url_launcher`. **Bloquea el paso 6.1 y el lanzamiento.**
- **No existe logotipo, y hoy hay tres marcas distintas**: `Icons.paid_outlined` en la bienvenida (welcome_screen.dart:81), `Icons.bolt_rounded` en el rail (dashboard_screen.dart:146) e iniciales "IA" como avatar por defecto (home_tab.dart:74). Propongo el wordmark en Manrope 700 como solución provisional honesta, pero **el icono adaptativo de Play no puede ser texto**: hace falta un icono real de 512×512 y un *feature graphic* de 1024×500. Entrega del dueño, fuera de esta especificación.
- **Google Sign-In en móvil.** `google_auth_service.dart:20` es `isAvailable => kIsWeb`. Decisión: integrar `google_sign_in` con el asset oficial de marca, o lanzar solo con correo. Mi propuesta asume lo segundo y por eso la bienvenida tiene un único botón.
- **¿Entra la pestaña IA en el lanzamiento?** Es la que concentra más marcas de "hecho por IA" (ia_tab.dart:140, :385, :409) y obliga a declarar IA generativa en la ficha de Play. Si entra, su limpieza va en el paso 7; si no, se oculta el destino y la barra baja a 4.
- **¿Se mantiene la moneda configurable?** El modelo acepta `CLP | USD` (docs/ARQUITECTURA.md) pero toda la UI escribe "$" fijo y `profile.currency` se ignora. Si el lanzamiento es solo Chile, lo limpio es fijar CLP y quitar el selector; si no, el formateador del paso 0 tiene que leer el perfil desde el primer commit.
- **`docs/prototipos/`**: regenerarlos desde este sistema o borrarlos. `tokens.jsx:4` dice `brand: '#00C2B8'` y `:7` `accent: '#F97316'` — ni el verde ni el coral reales. Dejarlos garantiza que alguien los use de guía.
- **Firma de release con keystore propio** (registrado en la auditoría previa como `android/app/build.gradle.kts:36-38`, hoy firmado con el keystore de debug). Fuera de lo visual, pero es lo último que impide subir el AAB.

**LO QUE ESTA PROPUESTA NO CUBRE A PROPÓSITO**: la iconografía (se sigue con Material Icons outline a 24 dp, correcto pero genérico), el splash nativo de Android, y el contraste del PDF exportado. El informe debería heredar esta tipografía y esta paleta, pero es un trabajo aparte y no bloquea el lanzamiento en Play.
