// Widget test de PagateMovementRow: docs/DISENO-v2.md, componente 7.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';

import 'harness.dart';

void main() {
  testWidgets('título, metadato y monto, sin círculo de icono', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      const PagateMovementRow(
        title: 'Venta feria Lastarria',
        meta: '12 oct · Ventas',
        amount: r'+$120.000',
        isIncome: true,
      ),
    );

    expect(find.text('Venta feria Lastarria'), findsOneWidget);
    expect(find.text('12 oct · Ventas'), findsOneWidget);
    expect(find.text(r'+$120.000'), findsOneWidget);

    // El círculo teñido de 36 dp duplicaba lo que el signo ya dice y robaba
    // ~48 dp de ancho al nombre.
    expect(
      find.descendant(
        of: find.byType(PagateMovementRow),
        matching: find.byWidgetPredicate(
          (final w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('el ingreso va en verde dinero y el gasto en tinta', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      const Column(
        children: [
          PagateMovementRow(
            title: 'Venta feria',
            meta: '12 oct · Ventas',
            amount: r'+$120.000',
            isIncome: true,
          ),
          PagateMovementRow(
            title: 'Greda 25 kg',
            meta: '11 oct · Materiales',
            amount: r'−$35.000',
            isIncome: false,
          ),
        ],
      ),
    );

    Color colorDe(final String texto) =>
        tester.widget<Text>(find.text(texto)).style!.color!;

    expect(colorDe(r'+$120.000'), AppPalette.moneyIn);
    expect(
      colorDe(r'−$35.000'),
      AppPalette.textPrimary,
      reason: 'un gasto corriente no es un error: lo distingue el signo',
    );
  });

  testWidgets('la fila mide al menos 64 dp', (final tester) async {
    await pumpComponent(
      tester,
      const PagateMovementRow(
        title: 'Esmalte celadón',
        meta: '10 oct · Materiales',
        amount: r'−$18.900',
        isIncome: false,
      ),
    );

    // 64 de fila + 1 de divisor.
    expect(
      tester.getSize(find.byType(PagateMovementRow)).height,
      greaterThanOrEqualTo(64),
    );
  });

  testWidgets('deslizar pide confirmación y avisa cuando ya salió', (
    final tester,
  ) async {
    var confirmaciones = 0;
    var eliminados = 0;

    await pumpComponent(
      tester,
      PagateMovementRow(
        title: 'Greda 25 kg',
        meta: '11 oct · Materiales',
        amount: r'−$35.000',
        isIncome: false,
        dismissKey: 'tx-1',
        onConfirmDelete: () async {
          confirmaciones++;
          return true;
        },
        onDeleted: () => eliminados++,
      ),
    );

    await tester.drag(find.text('Greda 25 kg'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(confirmaciones, 1);
    // Lo que faltaba en finanzas_tab: sin `onDismissed` la fila desaparecía
    // de la pantalla pero seguía en el árbol hasta que el stream reemitía.
    expect(eliminados, 1);
  });

  testWidgets('el borrado también es alcanzable sin deslizar', (
    final tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      PagateMovementRow(
        title: 'Greda 25 kg',
        meta: '11 oct · Materiales',
        amount: r'−$35.000',
        isIncome: false,
        dismissKey: 'tx-1',
        onConfirmDelete: () async => true,
        onDeleted: () {},
      ),
    );

    // Un gesto de deslizar no existe para un lector de pantalla ni para
    // alguien con temblor: la acción personalizada es su único camino.
    final semantica = tester.getSemantics(find.text('Greda 25 kg'));
    expect(
      semantica.getSemanticsData().customSemanticsActionIds,
      isNotEmpty,
    );
    handle.dispose();
  });

  testWidgets('sin confirmación no se puede deslizar', (final tester) async {
    await pumpComponent(
      tester,
      const PagateMovementRow(
        title: 'Greda 25 kg',
        meta: '11 oct · Materiales',
        amount: r'−$35.000',
        isIncome: false,
      ),
    );
    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('no desborda a 1,3x con un título largo', (final tester) async {
    await pumpComponent(
      tester,
      const PagateMovementRow(
        title: 'Venta de set de tazas en la feria de Lastarria',
        meta: '12 oct · Ventas por encargo',
        amount: r'+$1.234.567',
        isIncome: true,
      ),
      textScale: 1.3,
    );
    esperarSinDesborde(tester);
  });
}
