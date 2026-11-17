// Widget tests de PagateSectionCard y PagateSectionHeader:
// docs/DISENO-v2.md, componentes 6 y 8.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';

import 'harness.dart';

BoxDecoration _decoracionDe(final WidgetTester tester, final Type tipo) {
  final contenedor = tester.widget<Container>(
    find
        .descendant(of: find.byType(tipo), matching: find.byType(Container))
        .first,
  );
  return contenedor.decoration! as BoxDecoration;
}

void main() {
  group('PagateSectionCard', () {
    testWidgets('en móvil es una tarjeta de radio 16 con sombra suave', (
      final tester,
    ) async {
      await pumpComponent(
        tester,
        const PagateSectionCard(child: Text('Movimientos')),
      );

      final decoracion = _decoracionDe(tester, PagateSectionCard);
      expect(decoracion.color, AppPalette.surface);
      expect(decoracion.borderRadius, AppRadius.r16Border);
      expect(decoracion.boxShadow, AppShadows.level1);

      // Separada 16 dp de cada borde del lienzo de 360 dp.
      expect(
        tester.getSize(find.text('Movimientos')).width,
        lessThanOrEqualTo(360 - 2 * AppSpacing.x4),
      );
      expect(
        tester.getTopLeft(find.text('Movimientos')).dx,
        greaterThanOrEqualTo(AppSpacing.x4),
      );
    });

    testWidgets('en escritorio recupera radio 12 y margen lateral', (
      final tester,
    ) async {
      await pumpComponent(
        tester,
        const PagateSectionCard(child: Text('Movimientos')),
        width: 1000,
      );

      final decoracion = _decoracionDe(tester, PagateSectionCard);
      expect(decoracion.borderRadius, AppRadius.r12Border);
      expect(decoracion.border, isA<Border>());

      // El margen lateral lo pone el propio Container, así que el ancho del
      // widget sigue siendo el de la ventana: lo que encoge es la superficie
      // pintada.
      final contenedor = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PagateSectionCard),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        contenedor.margin,
        const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      );
    });
  });

  group('PagateSectionHeader', () {
    testWidgets('título a la izquierda y acción a la derecha', (
      final tester,
    ) async {
      var pulsado = 0;
      await pumpComponent(
        tester,
        PagateSectionHeader(
          title: 'Movimientos',
          actionLabel: 'Ver todos',
          onAction: () => pulsado++,
        ),
      );

      final titulo = tester.getTopLeft(find.text('Movimientos'));
      final accion = tester.getTopLeft(find.text('Ver todos'));
      expect(titulo.dx, lessThan(accion.dx));
      expect(titulo.dx, AppSpacing.x4);

      await tester.tap(find.text('Ver todos'));
      expect(pulsado, 1);
    });

    testWidgets('sin acción no dibuja botón', (final tester) async {
      await pumpComponent(
        tester,
        const PagateSectionHeader(title: 'Gastos fijos'),
      );
      expect(find.byType(PagatePrimaryButton), findsNothing);
    });

    testWidgets('la variante overline es el único sitio con mayúsculas', (
      final tester,
    ) async {
      await pumpComponent(
        tester,
        const PagateSectionHeader.overline(title: 'hoy'),
      );

      expect(find.text('HOY'), findsOneWidget);
      final fondo = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PagateSectionHeader),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(fondo.color, AppPalette.sunken);
    });

    testWidgets('no desborda a 1,3x con título y acción largos', (
      final tester,
    ) async {
      await pumpComponent(
        tester,
        PagateSectionHeader(
          title: 'Movimientos de septiembre',
          actionLabel: 'Ver todos',
          onAction: () {},
        ),
        textScale: 1.3,
      );
      esperarSinDesborde(tester);
    });
  });
}
