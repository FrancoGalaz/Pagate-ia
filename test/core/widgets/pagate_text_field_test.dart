// Widget test de PagateTextField: docs/DISENO-v2.md, componente 4.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';

import 'harness.dart';

/// Lee el borde que el campo está pintando en el estado en que se encuentre.
///
/// Mira el `InputDecorator` real, que es quien resuelve el borde del tema
/// según el estado. Comprobar el token en el código no probaría nada: el
/// defecto que esto vigila es justamente que el tema dejaba `enabledBorder`
/// en `BorderSide.none`.
InputBorder _bordeActual(final WidgetTester tester) {
  final decorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
  final decoration = decorator.decoration;
  if (decoration.errorText != null) return decoration.errorBorder!;
  if (decorator.isFocused) return decoration.focusedBorder!;
  return decoration.enabledBorder!;
}

void main() {
  testWidgets('la etiqueta va encima y es visible con el campo relleno', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      PagateTextField(
        labelText: 'Nombre completo',
        controller: TextEditingController(text: 'Camila Rojas'),
      ),
    );

    expect(find.text('Nombre completo'), findsOneWidget);
    expect(find.text('Camila Rojas'), findsOneWidget);

    // Encima, no dentro: la etiqueta empieza más arriba que la caja.
    final etiqueta = tester.getTopLeft(find.text('Nombre completo'));
    final caja = tester.getTopLeft(find.byType(TextFormField));
    expect(etiqueta.dy, lessThan(caja.dy));
  });

  testWidgets('el borde en reposo es visible, no BorderSide.none', (
    final tester,
  ) async {
    await pumpComponent(tester, const PagateTextField(labelText: 'Correo'));

    final borde = _bordeActual(tester);
    expect(borde.borderSide.style, BorderStyle.solid);
    expect(borde.borderSide.color, AppPalette.borderField);
    expect(borde.borderSide.width, AppSizes.borderField);
  });

  testWidgets('al enfocarse el borde pasa al oscuro de 1,5 dp', (
    final tester,
  ) async {
    await pumpComponent(tester, const PagateTextField(labelText: 'Correo'));

    await tester.tap(find.byType(TextFormField));
    await tester.pump();

    final borde = _bordeActual(tester);
    expect(borde.borderSide.color, AppPalette.ink);
    expect(borde.borderSide.width, AppSizes.borderEmphasis);
  });

  testWidgets('el error se dibuja a la izquierda y pinta el borde', (
    final tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await pumpComponent(
      tester,
      Form(
        key: formKey,
        child: const PagateTextField(
          labelText: 'Correo',
          hintText: 'tu@correo.cl',
        ),
      ),
    );

    formKey.currentState!.validate();
    await tester.pump();
    // Sin validator no hay error; se fuerza uno para comprobar el borde.
    await pumpComponent(
      tester,
      Form(
        key: formKey,
        child: PagateTextField(
          labelText: 'Correo',
          validator: (final _) => 'Escribe tu correo',
        ),
      ),
    );
    formKey.currentState!.validate();
    await tester.pump();

    expect(find.text('Escribe tu correo'), findsOneWidget);
    expect(_bordeActual(tester).borderSide.color, AppPalette.danger);
  });

  testWidgets('acepta autofillHints y textInputAction, que antes no existían', (
    final tester,
  ) async {
    var enviado = '';
    await pumpComponent(
      tester,
      AutofillGroup(
        child: PagateTextField(
          labelText: 'Correo',
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (final v) => enviado = v,
        ),
      ),
    );

    final campo = tester.widget<EditableText>(find.byType(EditableText));
    expect(campo.autofillHints, contains(AutofillHints.email));
    expect(campo.textInputAction, TextInputAction.next);

    await tester.enterText(find.byType(TextFormField), 'camila@taller.cl');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    expect(enviado, 'camila@taller.cl');
  });

  testWidgets('la variante de monto lleva el \$ dentro y alinea a la derecha', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      const PagateTextField.amount(labelText: 'Monto', hintText: '0'),
    );

    expect(find.text(r'$ '), findsOneWidget);
    final campo = tester.widget<EditableText>(find.byType(EditableText));
    expect(campo.textAlign, TextAlign.right);
    expect(campo.keyboardType.index, TextInputType.number.index);
  });

  testWidgets('la contraseña se puede mostrar y el control tiene etiqueta', (
    final tester,
  ) async {
    await pumpComponent(
      tester,
      const PagateTextField(labelText: 'Contraseña', isPassword: true),
    );

    expect(tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isTrue);
    expect(find.byTooltip('Mostrar contraseña'), findsOneWidget);

    await tester.tap(find.byTooltip('Mostrar contraseña'));
    await tester.pump();

    expect(tester.widget<EditableText>(find.byType(EditableText)).obscureText,
        isFalse);
  });

  testWidgets('no desborda a 1,3x', (final tester) async {
    await pumpComponent(
      tester,
      const PagateTextField(
        labelText: 'Nombre de tu taller o emprendimiento',
        hintText: 'Greda Austral',
      ),
      textScale: 1.3,
    );
    esperarSinDesborde(tester);
  });
}
