import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_text.dart';

// ═══════════════════════════════════════════════════════════════════════
// SELECTOR SEGMENTADO
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/diseno/variantes-cabal.html, componente 1.
//
// Píldora de 2 a 4 opciones excluyentes. La activa es blanca, con sombra
// suave, en el oscuro y en 800; las otras, en `textMuted` sobre `sunken`.
// El estado activo se comunica con fondo, peso y color, no solo con color
// (WCAG 1.4.1), y cada opción se anuncia como botón seleccionado o no.
//
// CON LETRA GRANDE NO SE CORTA: la etiqueta puede bajar a dos líneas
// centradas. Las opciones se reparten el ancho por igual.
// ═══════════════════════════════════════════════════════════════════════

/// Selector de una opción entre varias, en píldora.
class PagateSegmented<T> extends StatelessWidget {
  /// Valor y etiqueta de cada opción, en orden.
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Al tocar la opción que ya está elegida. Para las que abren algo, como
  /// «Otro mes», que vuelve a abrir la lista.
  final ValueChanged<T>? onReselected;

  const PagateSegmented({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.onReselected,
  });

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.x1),
      decoration: BoxDecoration(
        color: AppPalette.sunken,
        borderRadius: AppRadius.fullBorder,
      ),
      child: Row(
        children: [
          for (final (valor, etiqueta) in options)
            Expanded(
              child: _Opcion(
                etiqueta: etiqueta,
                activa: valor == selected,
                onTap: () {
                  if (valor != selected) {
                    onChanged(valor);
                  } else {
                    onReselected?.call(valor);
                  }
                },
                estilo: theme.textTheme.labelMedium,
              ),
            ),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final String etiqueta;
  final bool activa;
  final VoidCallback onTap;
  final TextStyle? estilo;

  const _Opcion({
    required this.etiqueta,
    required this.activa,
    required this.onTap,
    required this.estilo,
  });

  @override
  Widget build(final BuildContext context) => Semantics(
    button: true,
    selected: activa,
    inMutuallyExclusiveGroup: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        constraints: const BoxConstraints(minHeight: _altoMinimo),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x1,
          vertical: AppSpacing.x2,
        ),
        decoration: BoxDecoration(
          color: activa ? AppPalette.surface : Colors.transparent,
          borderRadius: AppRadius.fullBorder,
          boxShadow: activa ? AppShadows.level1 : null,
        ),
        child: LayoutBuilder(
          builder: (final context, final limites) {
            final style = AppText.weight(
              estilo ?? AppText.labelMedium,
              activa ? 800 : 600,
            ).copyWith(color: activa ? AppPalette.ink : AppPalette.textMuted);
            return Text(
              etiqueta,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: style,
              textScaler: _escalaQueCabe(context, style, limites.maxWidth),
            );
          },
        ),
      ),
    ),
  );

  /// 40 dentro de la píldora + 4 + 4 de relleno = 48 de objetivo táctil.
  static const double _altoMinimo = 40;

  /// La etiqueta parte en dos líneas por las palabras; si aun así la
  /// palabra más larga no cabe («pasado» en un cuarto de pantalla con letra
  /// 2,0), la letra se achica lo justo en vez de cortarla.
  TextScaler _escalaQueCabe(
    final BuildContext context,
    final TextStyle style,
    final double ancho,
  ) {
    final escala = MediaQuery.textScalerOf(context);
    final pintor = TextPainter(
      text: TextSpan(text: etiqueta, style: style),
      textScaler: escala,
      textDirection: TextDirection.ltr,
    )..layout();
    // El ancho mínimo de un párrafo es el de su palabra más larga.
    final palabra = pintor.minIntrinsicWidth;
    pintor.dispose();
    if (!ancho.isFinite || palabra <= ancho) return escala;
    final tamano = style.fontSize ?? 14;
    // Un 5 % de holgura: con la medida justa, el redondeo del motor volvía
    // a partir la palabra («pasad / o»).
    return TextScaler.linear(
      escala.scale(tamano) / tamano * ancho / palabra * 0.95,
    );
  }
}
