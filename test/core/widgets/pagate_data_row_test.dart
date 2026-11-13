// Widget test de PagateDataRow: docs/DISENO-v2.md, componente 5.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';

import 'harness.dart';

TextStyle _estiloDe(final WidgetTester tester, final String texto) =>
    tester.widget<Text>(find.text(texto)).style!;

void main() {
  testWidgets('etiqueta a la izquierda, valor a la derecha', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      const PagateDataRow(label: 'Ingresos', value: r'$1.240.000'),
    );

    final etiqueta = tester.getTopLeft(find.text('Ingresos'));
    final valor = tester.getTopRight(find.text(r'$1.240.000'));
    expect(etiqueta.dx, AppSpacing.x4);
    expect(valor.dx, 360 - AppSpacing.x4);
  });

  testWidgets('el valor va en cifras tabulares y sin ancho fijo', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      const PagateDataRow(label: 'Gastos', value: r'−$860.000'),
    );

    final estilo = _estiloDe(tester, r'−$860.000');
    expect(
      estilo.fontFeatures,
      contains(const FontFeature.tabularFigures()),
      reason: 'sin tnum la columna de montos baila: el 1 mide 0,358 em y el '
          '9 mide 0,620 em',
    );

    // El motivo de no fijar el ancho: un SizedBox no escala con textScaler y
    // reintroduciría el desborde que hoy bloquea la publicación.
    expect(
      find.descendant(
        of: find.byType(PagateDataRow),
        matching: find.byWidgetPredicate(
          (final w) => w is SizedBox && (w.width ?? 0) > AppSpacing.x4,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('la fila mide al menos 48 dp', (final tester) async {
    await pumpComponent(
      tester,
      const PagateDataRow(
        label: 'Gastos fijos',
        value: r'−$320.000',
        showDivider: false,
      ),
    );
    expect(
      tester.getSize(find.byType(PagateDataRow)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('la variante de énfasis pinta en rojo solo si es negativa', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      const Column(
        children: [
          PagateDataRow(
            label: 'Balance',
            value: r'$380.000',
            emphasis: true,
          ),
          PagateDataRow(
            label: 'Balance',
            value: r'−$120.000',
            emphasis: true,
          ),
        ],
      ),
    );

    expect(_estiloDe(tester, r'$380.000').color, AppPalette.textPrimary);
    expect(_estiloDe(tester, r'−$120.000').color, AppPalette.moneyOut);
  });

  testWidgets('pulsable gana chevron y dispara la acción', (
    final tester,
  ) async {
    var pulsos = 0;
    await pumpComponent(
      tester,
      PagateDataRow(
        label: 'Valor de tu hora',
        value: r'$4.800',
        onTap: () => pulsos++,
      ),
    );

    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    await tester.tap(find.byType(PagateDataRow));
    expect(pulsos, 1);
  });

  testWidgets('el divisor va a sangre completa, sin indentar', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      const PagateDataRow(label: 'Ingresos', value: r'$1.240.000'),
    );

    final divisor = tester.widget<Divider>(find.byType(Divider));
    expect(divisor.color, AppPalette.hairline);
    expect(tester.getSize(find.byType(Divider)).width, 360);
  });

  testWidgets('no desborda a 1,3x con etiqueta larga y monto de ocho cifras', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      const PagateDataRow(
        label: 'Gastos fijos del mes en curso',
        value: r'−$12.345.678',
      ),
      textScale: 1.3,
    );
    esperarSinDesborde(tester);
  });
}
