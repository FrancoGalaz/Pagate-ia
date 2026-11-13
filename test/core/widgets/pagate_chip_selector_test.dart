// Widget test de PagateChipSelector: docs/DISENO-v2.md, componente 10.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';

import 'harness.dart';

void main() {
  const categorias = ['Ventas', 'Materiales', 'Feria', 'Encargos'];

  testWidgets('dibuja una opción por elemento y avisa del toque', (
    final tester,
  ) async {
    final tocadas = <String>[];
    await pumpComponent(
      tester,
      PagateChipSelector(
        options: categorias,
        selected: const {'Ventas'},
        onToggle: tocadas.add,
      ),
    );

    expect(find.byType(PagateChip), findsNWidgets(4));
    await tester.tap(find.text('Feria'));
    expect(tocadas, ['Feria']);
  });

  testWidgets('el seleccionado se distingue por color y por borde', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      PagateChipSelector(
        options: categorias,
        selected: const {'Ventas'},
        onToggle: (final _) {},
      ),
    );

    ChoiceChip chipDe(final String etiqueta) => tester.widget<ChoiceChip>(
          find.ancestor(
            of: find.text(etiqueta),
            matching: find.byType(ChoiceChip),
          ),
        );

    // Variante A: el seleccionado va en el oscuro sobre `sunken`; la greda
    // queda para la acción principal.
    expect(chipDe('Ventas').selectedColor, AppPalette.sunken);
    expect(chipDe('Ventas').side?.color, AppPalette.ink);
    expect(chipDe('Feria').backgroundColor, AppPalette.surface);
    expect(chipDe('Feria').side?.color, AppPalette.border);
  });

  testWidgets('expone el rol y el estado al lector de pantalla', (
    final tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpComponent(
      tester,
      PagateChipSelector(
        options: categorias,
        selected: const {'Ventas'},
        onToggle: (final _) {},
      ),
    );

    // Lo que el `GestureDetector` anterior no daba: TalkBack no sabía ni que
    // era un control ni cuál estaba activo.
    final semantica = tester.getSemantics(find.text('Ventas'));
    expect(semantica.flagsCollection.isButton, isTrue);
    expect(semantica.flagsCollection.isSelected, Tristate.isTrue);
    expect(
      tester.getSemantics(find.text('Feria')).flagsCollection.isSelected,
      Tristate.isFalse,
    );

    // Y el rol sale de Material: selección única es `ChoiceChip`, que se
    // anuncia como opción de un grupo excluyente.
    expect(find.byType(ChoiceChip), findsNWidgets(4));
    expect(find.byType(FilterChip), findsNothing);
    handle.dispose();
  });

  testWidgets('la caja táctil mide 48 aunque el chip mida 32', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      PagateChipSelector(
        options: const ['Ventas'],
        selected: const {},
        onToggle: (final _) {},
      ),
    );

    final alto = tester.getSize(find.byType(PagateChip)).height;
    expect(
      alto,
      greaterThanOrEqualTo(AppSizes.minTouchTarget),
      reason: 'el informe previo de Google Play marca el área táctil mínima',
    );
  });

  testWidgets('con selección múltiple el rol pasa a casilla marcable', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      PagateChipSelector(
        options: categorias,
        selected: const {'Ventas', 'Feria'},
        allowMultiple: true,
        onToggle: (final _) {},
      ),
    );

    expect(find.byType(FilterChip), findsNWidgets(4));
    expect(find.byType(ChoiceChip), findsNothing);
  });

  testWidgets('una opción deshabilitada no dispara el toque', (
    final tester,
  ) async {
    final tocadas = <String>[];
    await pumpComponent(
      tester,
      PagateChipSelector(
        options: categorias,
        selected: const {},
        disabled: const {'Feria'},
        onToggle: tocadas.add,
      ),
    );

    await tester.tap(find.text('Feria'));
    expect(tocadas, isEmpty);
  });

  testWidgets('no desborda a 1,3x con etiquetas largas', (final tester) async {
    await pumpComponent(
      tester,
      PagateChipSelector(
        options: const ['Materiales y arcilla', 'Arriendo del taller'],
        selected: const {},
        onToggle: (final _) {},
      ),
      textScale: 1.3,
    );
    esperarSinDesborde(tester);
  });
}
