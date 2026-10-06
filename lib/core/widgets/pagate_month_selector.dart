import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../utils/month_labels.dart';
import 'pagate_chip_selector.dart';

// ═══════════════════════════════════════════════════════════════════════
// SELECTOR DE PERIODO
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componente 9.
//
// ERA EL CONTROL MÁS IMPORTANTE DE FINANZAS y estaba enterrado dentro de un
// `_FinanzasHeaderState` privado. Aquí se extrae para compartirlo con
// Inicio, y eso arregla un bug real, no es estética: las dos pantallas leen
// el mismo `FinancesProvider`, cuyo resumen depende de `selectedMonthKey`.
// Si el usuario tocaba "julio" en Finanzas y volvía a Inicio, la tarjeta
// titulada "Balance del Mes" mostraba julio sin decirlo. Con el selector
// arriba en las dos, el mes deja de ser un estado invisible compartido y
// pasa a ser el filtro global explícito de la app.
//
// EL ARREGLO OBLIGATORIO: la lista salía de `provider.months`, que solo
// contiene los meses que el trigger del backend llegó a escribir. Con datos
// de enero a agosto y el mes en curso sin movimientos, no había chip del mes
// actual y la selección caía a agosto: la pantalla abría en un mes pasado
// sin forma de volver. [PagateMonthSelector] GARANTIZA siempre un chip para
// el mes en curso.
//
// SIN BORDE EN LOS NO SELECCIONADOS. La versión anterior pintaba un borde en
// cada uno y convertía la fila en una reja donde el seleccionado no
// destacaba.
// ═══════════════════════════════════════════════════════════════════════

/// Fila horizontal de meses, con el mes en curso siempre presente.
class PagateMonthSelector extends StatefulWidget {
  /// Claves `yyyy-MM` que el backend tiene escritas. Puede venir vacía o sin
  /// el mes en curso: el componente lo añade.
  final List<String> monthKeys;

  /// Clave seleccionada.
  final String selectedMonthKey;

  final ValueChanged<String> onSelected;

  /// Mes que se considera "en curso". Se inyecta para poder probarlo sin
  /// depender del reloj de la máquina.
  final String currentMonthKey;

  const PagateMonthSelector({
    super.key,
    required this.monthKeys,
    required this.selectedMonthKey,
    required this.onSelected,
    required this.currentMonthKey,
  });

  @override
  State<PagateMonthSelector> createState() => _PagateMonthSelectorState();
}

class _PagateMonthSelectorState extends State<PagateMonthSelector> {
  final ScrollController _scroll = ScrollController();

  /// Meses a dibujar: los que hay más el actual si falta, de más reciente a
  /// más antiguo.
  List<String> get _meses {
    final claves = {...widget.monthKeys, widget.currentMonthKey}.toList()
      ..sort((final a, final b) => b.compareTo(a));
    return claves;
  }

  @override
  void initState() {
    super.initState();
    // Posicionar el scroll en el seleccionado: si el usuario está mirando
    // marzo y la lista abre en el extremo, no ve cuál está activo.
    WidgetsBinding.instance.addPostFrameCallback((final _) => _verSeleccion());
  }

  @override
  void didUpdateWidget(final PagateMonthSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMonthKey != widget.selectedMonthKey) {
      WidgetsBinding.instance.addPostFrameCallback(
        (final _) => _verSeleccion(),
      );
    }
  }

  void _verSeleccion() {
    if (!_scroll.hasClients) return;
    final indice = _meses.indexOf(widget.selectedMonthKey);
    if (indice <= 0) return;

    // Estimación deliberada y acotada: el ancho real de cada chip depende
    // del texto y del escalado de fuente, así que no se puede calcular sin
    // medir. 96 dp es el ancho medio de "sep 25" con su separación, y el
    // `clamp` contra `maxScrollExtent` impide pasarse. Lo que importa es que
    // el seleccionado entre en pantalla, no que quede centrado al píxel.
    final destino = (indice * 96.0).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(destino);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// El mes en curso se llama "Este mes"; los anteriores, "sep 25".
  String _etiqueta(final String monthKey) => monthKey == widget.currentMonthKey
      ? 'Este mes'
      : shortMonthLabelFromMonthKey(monthKey);

  @override
  Widget build(final BuildContext context) {
    final meses = _meses;

    // Con un solo mes no hay nada que elegir y la fila sería ruido.
    if (meses.length <= 1) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppPalette.canvas,
        border: Border(
          bottom: BorderSide(
            color: AppPalette.border,
            width: AppSizes.borderHairline,
          ),
        ),
      ),
      child: SingleChildScrollView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
        child: Row(
          children: [
            for (final mes in meses) ...[
              PagateChip.period(
                label: _etiqueta(mes),
                isSelected: mes == widget.selectedMonthKey,
                onSelected: () => widget.onSelected(mes),
              ),
              if (mes != meses.last) const SizedBox(width: AppSpacing.x2),
            ],
          ],
        ),
      ),
    );
  }
}
