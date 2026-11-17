// Widget test de PagatePrimaryButton: docs/DISENO-v2.md, componentes 1-3.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';

import 'harness.dart';

void main() {
  testWidgets('muestra su etiqueta y responde al tap', (final tester) async {
    var taps = 0;
    await pumpComponent(
      tester,
      PagatePrimaryButton(label: 'Continuar', onPressed: () => taps++),
    );

    expect(find.text('Continuar'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    expect(taps, 1);
  });

  testWidgets('en carga no responde al tap y conserva el ancho', (
    final tester,
  ) async {
    var taps = 0;

    // Primero sin cargar, para medir el ancho de referencia. Va dentro de un
    // `Row` para que el botón se ajuste a su contenido: con el ancho completo
    // el test no probaría nada.
    await pumpComponent(
      tester,
      Row(
        children: [
          PagatePrimaryButton(
            label: 'Guardar',
            fullWidth: false,
            onPressed: () => taps++,
          ),
        ],
      ),
    );
    final anchoEnReposo = tester.getSize(find.byType(PagatePrimaryButton)).width;

    await pumpComponent(
      tester,
      Row(
        children: [
          PagatePrimaryButton(
            label: 'Guardar',
            fullWidth: false,
            isLoading: true,
            onPressed: () => taps++,
          ),
        ],
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(PagatePrimaryButton));
    expect(taps, 0, reason: 'un botón cargando no puede aceptar un segundo tap');

    // El motivo de dibujar el texto a opacidad cero debajo del indicador: si
    // el texto se sustituyera, el botón encogería a ~24 dp y la fila
    // saltaría al pulsar.
    expect(
      tester.getSize(find.byType(PagatePrimaryButton)).width,
      anchoEnReposo,
    );
  });

  testWidgets('cumple el alto mínimo del sistema en las tres variantes', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      Column(
        children: [
          PagatePrimaryButton(label: 'Primario', onPressed: () {}),
          PagatePrimaryButton.secondary(label: 'Secundario', onPressed: () {}),
          PagatePrimaryButton.text(label: 'Texto', onPressed: () {}),
        ],
      ),
    );

    final primario = tester.getSize(find.text('Primario').first);
    expect(primario.height, lessThanOrEqualTo(AppSizes.buttonHeight));

    // El alto real del control, no el del texto.
    for (final etiqueta in ['Primario', 'Secundario']) {
      final caja = tester.getSize(
        find.ancestor(
          of: find.text(etiqueta),
          matching: find.byType(PagatePrimaryButton),
        ),
      );
      expect(
        caja.height,
        greaterThanOrEqualTo(AppSizes.buttonHeight),
        reason: '$etiqueta debe medir al menos 48 dp de alto',
      );
    }

    // El botón de texto mide 40 visibles pero su caja táctil es de 48 por
    // `tapTargetSize: padded`, así que el widget entero mide 48.
    final texto = tester.getSize(
      find.ancestor(
        of: find.text('Texto'),
        matching: find.byType(PagatePrimaryButton),
      ),
    );
    expect(texto.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
  });

  testWidgets('deshabilitado no dispara la acción', (final tester) async {
    await pumpComponent(
      tester,
      const PagatePrimaryButton(label: 'Guardar'),
    );

    await tester.tap(find.byType(PagatePrimaryButton));
    // No hay callback que contar: lo que se comprueba es que el tap no
    // lanza. `ElevatedButton` con `onPressed: null` ignora el gesto.
    expect(tester.takeException(), isNull);
  });

  testWidgets('no lleva sombra: la regla del sistema', (final tester) async {
    await pumpComponent(
      tester,
      PagatePrimaryButton(label: 'Crear cuenta', onPressed: () {}),
    );

    // El `Container` con `boxShadow` que envolvía al botón (y que existía
    // SOLO para el glow verde de marca) ya no está en el árbol.
    final conSombra = find.byWidgetPredicate((final w) {
      if (w is! DecoratedBox) return false;
      final decoration = w.decoration;
      return decoration is BoxDecoration &&
          (decoration.boxShadow?.isNotEmpty ?? false);
    });
    expect(conSombra, findsNothing);
  });

  testWidgets('no desborda con el ajuste Grande de Android (1,3x)', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      PagatePrimaryButton(
        label: 'Crear cuenta gratis ahora mismo',
        leadingIcon: Icons.add,
        onPressed: () {},
      ),
      textScale: 1.3,
    );
    esperarSinDesborde(tester);
  });
}
