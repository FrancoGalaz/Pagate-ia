// Widget tests de los componentes nuevos de la variante A
// (docs/diseno/variantes-cabal.html): selector segmentado, tarjeta de
// métrica, par Limpiar/Crear y diálogo de confirmación.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';

import 'harness.dart';

void main() {
  group('PagateSegmented', () {
    testWidgets('marca la opción activa y avisa solo al cambiar', (
      final tester,
    ) async {
      final elegidos = <int>[];
      await pumpComponent(
        tester,
        PagateSegmented<int>(
          options: const [(1, 'Este mes'), (2, 'Mes pasado'), (3, 'Año')],
          selected: 1,
          onChanged: elegidos.add,
        ),
      );

      await tester.tap(find.text('Este mes'));
      await tester.tap(find.text('Año'));
      expect(elegidos, [3], reason: 'tocar la activa no dispara nada');

      final activa = tester.widget<Text>(find.text('Este mes'));
      expect(activa.style?.color, AppPalette.ink);
      expect(
        tester.getSemantics(find.text('Este mes')),
        isSemantics(isSelected: true),
      );
    });

    testWidgets('con letra 2,0 cuatro opciones no desbordan', (
      final tester,
    ) async {
      await pumpComponent(
        tester,
        PagateSegmented<int>(
          options: const [
            (1, 'Este mes'),
            (2, 'Mes pasado'),
            (3, 'Año'),
            (4, 'Otro mes'),
          ],
          selected: 1,
          onChanged: (_) {},
        ),
        textScale: 2,
      );
      esperarSinDesborde(tester);
    });
  });

  group('PagateMetricCard', () {
    testWidgets('el ingreso va en verde y el gasto en el oscuro', (
      final tester,
    ) async {
      await pumpComponent(
        tester,
        const Column(
          children: [
            PagateMetricCard(
              value: r'+$390.500',
              label: 'Ingresos',
              tone: PagateMetricTone.income,
            ),
            PagateMetricCard(
              value: r'−$330.000',
              label: 'Gastos',
              tone: PagateMetricTone.expense,
            ),
          ],
        ),
      );
      Color? color(final String t) =>
          tester.widget<Text>(find.text(t)).style?.color;
      expect(color(r'+$390.500'), AppPalette.moneyIn);
      expect(color(r'−$330.000'), AppPalette.ink);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
    });
  });

  group('PagateClearCreateBar', () {
    testWidgets('lado a lado en 1,0 y apilado en 2,0, sin desborde', (
      final tester,
    ) async {
      Widget barra() => PagateClearCreateBar(
        createLabel: 'Crear ingreso',
        onCreate: () {},
        onClear: () {},
      );

      await pumpComponent(tester, barra());
      expect(
        tester.getTopLeft(find.text('Limpiar')).dy,
        tester.getTopLeft(find.text('Crear ingreso')).dy,
      );

      await pumpComponent(tester, barra(), textScale: 2);
      esperarSinDesborde(tester);
      expect(
        tester.getTopLeft(find.text('Crear ingreso')).dy,
        lessThan(tester.getTopLeft(find.text('Limpiar')).dy),
        reason: 'apilados, con la acción arriba',
      );
    });
  });

  group('confirmar', () {
    Future<bool?> abrir(
      final WidgetTester tester, {
      required final bool destructive,
      required final String tocar,
    }) async {
      bool? resultado;
      await pumpComponent(
        tester,
        Builder(
          builder: (final context) => TextButton(
            onPressed: () async => resultado = await confirmar(
              context,
              title: '¿Borrar el historial?',
              message: 'No se puede deshacer.',
              confirmLabel: 'Borrar',
              destructive: destructive,
            ),
            child: const Text('abrir'),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      if (destructive) {
        final boton = tester.widget<ElevatedButton>(
          find.ancestor(
            of: find.text('Borrar'),
            matching: find.byType(ElevatedButton),
          ),
        );
        expect(
          boton.style?.backgroundColor?.resolve(const {}),
          AppPalette.danger,
          reason: 'la acción destructiva va en carmesí, no en la greda',
        );
      }
      await tester.tap(find.text(tocar));
      await tester.pumpAndSettle();
      return resultado;
    }

    testWidgets('confirmar devuelve true y el botón va en carmesí', (
      final tester,
    ) async {
      expect(await abrir(tester, destructive: true, tocar: 'Borrar'), isTrue);
    });

    testWidgets('cancelar devuelve false', (final tester) async {
      expect(
        await abrir(tester, destructive: false, tocar: 'Cancelar'),
        isFalse,
      );
    });
  });
}
