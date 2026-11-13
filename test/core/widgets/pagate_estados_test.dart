// Widget tests de PagateEmptyState, PagateErrorState y PagateSkeleton:
// docs/DISENO-v2.md, componentes 11 y 12.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';

import 'harness.dart';

void main() {
  group('PagateEmptyState', () {
    testWidgets('centrado, con la vasija y sin iconos', (
      final tester,
    ) async {
      await pumpComponent(
        tester,
        PagateEmptyState(
          title: 'Sin movimientos en octubre',
          description: 'Registra tu primera venta o tu primer gasto del mes.',
          actionLabel: 'Registrar ingreso',
          onAction: () {},
        ),
      );

      // Variante A: la ilustración de greda arriba y el texto centrado.
      expect(find.byType(PagateVasija), findsOneWidget);
      expect(find.byType(Icon), findsNothing);
      expect(
        tester.widget<Text>(find.text('Sin movimientos en octubre')).textAlign,
        TextAlign.center,
      );
    });

    testWidgets('la acción está al lado de la descripción', (
      final tester,
    ) async {
      var pulsos = 0;
      await pumpComponent(
        tester,
        PagateEmptyState(
          title: 'Sin movimientos en octubre',
          description: 'Registra tu primera venta.',
          actionLabel: 'Registrar ingreso',
          onAction: () => pulsos++,
        ),
      );

      await tester.tap(find.text('Registrar ingreso'));
      expect(pulsos, 1);

      // Ancho de contenido, no completo: si ocupara la línea entera sería el
      // elemento dominante de una pantalla que no tiene nada que mostrar.
      expect(
        tester.getSize(find.byType(PagatePrimaryButton)).width,
        lessThan(360 - AppSpacing.x4 * 2),
      );
    });

    testWidgets('sin acción no dibuja botón', (final tester) async {
      await pumpComponent(
        tester,
        const PagateEmptyState(
          title: 'Sin stock bajo',
          description: 'Todos tus materiales están por sobre el mínimo.',
        ),
      );
      expect(find.byType(PagatePrimaryButton), findsNothing);
    });
  });

  group('PagateErrorState', () {
    testWidgets('muestra el mensaje del servidor tal cual y reintenta', (
      final tester,
    ) async {
      var reintentos = 0;
      await pumpComponent(
        tester,
        PagateErrorState(
          message: 'No tienes permiso para leer estos movimientos.',
          onRetry: () => reintentos++,
        ),
      );

      // El principio 5 de docs/ARQUITECTURA.md: un fallo nunca se presenta
      // como si el usuario no tuviera datos.
      expect(
        find.text('No tienes permiso para leer estos movimientos.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Reintentar'));
      expect(reintentos, 1);
    });

    testWidgets('se distingue por fondo y borde, no por un icono', (
      final tester,
    ) async {
      await pumpComponent(
        tester,
        const PagateErrorState(message: 'Sin conexión.'),
      );

      final decoracion = tester
          .widget<Container>(
            find
                .descendant(
                  of: find.byType(PagateErrorState),
                  matching: find.byType(Container),
                )
                .first,
          )
          .decoration! as BoxDecoration;

      expect(decoracion.color, AppPalette.dangerSurface);
      expect(decoracion.borderRadius, AppRadius.r8Border);
      expect(find.byType(Icon), findsNothing);
    });

    testWidgets('sin reintento no dibuja botón', (final tester) async {
      await pumpComponent(
        tester,
        const PagateErrorState(message: 'Tu cuenta fue cerrada.'),
      );
      expect(find.byType(PagatePrimaryButton), findsNothing);
    });

    testWidgets('no desborda a 1,3x', (final tester) async {
      await pumpComponent(
        tester,
        PagateErrorState(
          message: 'No pudimos conectar con el servidor. Revisa tu conexión '
              'e inténtalo de nuevo.',
          onRetry: () {},
        ),
        textScale: 1.3,
      );
      esperarSinDesborde(tester);
    });
  });

  group('PagateSkeleton', () {
    testWidgets('los bloques tienen la altura del texto que sustituyen', (
      final tester,
    ) async {
      await pumpComponent(
        tester,
        const PagateSkeleton(height: PagateSkeleton.lineaTitulo),
      );
      expect(
        tester.getSize(find.byType(PagateSkeleton)).height,
        PagateSkeleton.lineaTitulo,
      );
    });

    testWidgets('el pulso es de opacidad, sin gradiente ni barrido', (
      final tester,
    ) async {
      await pumpComponent(tester, PagateSkeleton.balance());
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        find.descendant(
          of: find.byType(PagateSkeletonGroup),
          matching: find.byType(FadeTransition),
        ),
        findsOneWidget,
      );
      // No hay gradientes en el sistema; un barrido diagonal sería uno.
      expect(
        find.byWidgetPredicate(
          (final w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).gradient != null,
        ),
        findsNothing,
      );

      // El controlador queda en marcha; se detiene al desmontar.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('rows dibuja la cantidad pedida y no la anuncia', (
      final tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpComponent(tester, PagateSkeleton.rows(5));

      // Dos bloques por fila: título y metadato.
      expect(find.byType(PagateSkeleton), findsNWidgets(10));
      expect(
        find.descendant(
          of: find.byType(PagateSkeletonGroup),
          matching: find.byType(ExcludeSemantics),
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      handle.dispose();
    });
  });
}
