import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_text.dart';

// ═══════════════════════════════════════════════════════════════════════
// FILA DE DATO — etiqueta a la izquierda, valor a la derecha
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componente 5.
//
// EL COMPONENTE MÁS NECESARIO DE LA APP Y EL QUE NO EXISTÍA. Estaba
// reinventado SEIS veces con seis criterios distintos de peso, color y
// alineación, y ninguna con cifras tabulares: `_StatRow` (finanzas_tab),
// `_DetailRow` (detalle_item_screen), `_ContactRow` (ayuda_screen),
// `_ItemRow` (configuracion_screen), `_MiniStat` (home_tab) y `_StatItem`
// (perfil_tab).
//
// LA COLUMNA DE MONTOS NO LLEVA ANCHO FIJO, y es deliberado. Medí que
// `−$1.234.567` a 17 dp ocupa 100,0 dp en w200 y 103,9 dp en w700 porque el
// `$` y el punto de millar SÍ varían con el peso aunque los dígitos
// tabulares no; y un `SizedBox(width:)` además no escala con `textScaler`,
// que es justo lo que hace desbordar Inicio al 130%. La etiqueta va en
// `Expanded` y el valor en un `Text` alineado a la derecha: con `tnum` eso
// basta para que la columna no baile entre frames.
// ═══════════════════════════════════════════════════════════════════════

/// Fila de etiqueta y valor.
///
/// El valor se pasa ya formateado: esta fila no sabe de monedas. Quien la
/// usa llama antes a `formatCurrency` o a `formatSigned`.
class PagateDataRow extends StatelessWidget {
  final String label;

  /// Valor ya formateado. Se dibuja en [AppText.amountRow], con cifras
  /// tabulares, aunque no sea un monto: así una columna de "3 meses" y
  /// "12 meses" tampoco baila.
  final String value;

  /// Segunda línea bajo la etiqueta, en `bodySmall` `textMuted`. Opcional.
  final String? subtitle;

  /// Si se pasa, la fila es pulsable: gana un chevron de 20 dp y fondo
  /// `sunken` al presionar.
  final VoidCallback? onTap;

  /// Dibuja el divisor inferior. La última fila de una sección lo omite.
  final bool showDivider;

  /// Variante de énfasis: el valor sube a `displaySmall` 24/700. Se usa para
  /// el total de una sección, nunca para más de una fila del mismo bloque.
  final bool emphasis;

  /// Tiñe el valor. Si es `null`, el color lo decide la fila:
  /// `textPrimary`, o `moneyOut` cuando [emphasis] está activo y el valor
  /// empieza por el signo menos.
  ///
  /// Se expone porque el stock bajo de Inicio necesita `danger` y `warning`
  /// en el mismo componente, y son los dos únicos sitios de esa pantalla
  /// donde aparece rojo o ámbar.
  final Color? valueColor;

  const PagateDataRow({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.onTap,
    this.showDivider = true,
    this.emphasis = false,
    this.valueColor,
  });

  /// U+2212 MINUS SIGN, el que usa `currency_formatter.dart`.
  static const String _minusSign = '−';

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    final colorValor = valueColor ??
        (emphasis && value.startsWith(_minusSign)
            ? AppPalette.moneyOut
            : AppPalette.textPrimary);

    final contenido = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x3,
      ),
      child: ConstrainedBox(
        // Mínimo, nunca fijo: a 2,0x la fila crece en vez de recortar.
        constraints: const BoxConstraints(minHeight: _altoMinimo),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppPalette.textSecondary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Text(
              value,
              textAlign: TextAlign.right,
              style: (emphasis
                      ? theme.textTheme.displaySmall ?? AppText.displaySmall
                      : AppText.amountRow)
                  .copyWith(color: colorValor),
            ),
            if (onTap != null) ...[
              const SizedBox(width: AppSpacing.x2),
              const Icon(
                Icons.chevron_right_rounded,
                size: AppIconSize.sm,
                color: AppPalette.textMuted,
              ),
            ],
          ],
        ),
      ),
    );

    final fila = onTap == null
        ? ColoredBox(color: AppPalette.surface, child: contenido)
        : Material(
            color: AppPalette.surface,
            child: InkWell(
              onTap: onTap,

              // Sin onda circular de color: la pulsación se comunica con un
              // cambio de fondo, que es instantáneo y legible.
              highlightColor: AppPalette.sunken,
              splashFactory: NoSplash.splashFactory,
              child: contenido,
            ),
          );

    if (!showDivider) return fila;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        fila,
        // A sangre completa, sin `indent`: es lo que hace que una lista se
        // lea como cartola y no como tarjetas apiladas.
        const Divider(
          height: AppSizes.borderHairline,
          thickness: AppSizes.borderHairline,
          color: AppPalette.hairline,
        ),
      ],
    );
  }

  /// 24 de contenido + 12 + 12 de relleno = los 48 dp que manda el sistema.
  /// Se expresa así, y no como un alto de 48 sobre el `Padding`, para que el
  /// relleno no se coma el crecimiento cuando el texto escala.
  static const double _altoMinimo = 24;
}
