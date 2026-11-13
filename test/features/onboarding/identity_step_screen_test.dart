// Widget test de IdentityStepScreen, sin Firebase.
//
// El servicio de autenticación se inyecta como doble que registra lo que se
// le pidió, así que la pantalla se prueba entera sin red ni emulador.
//
// Especificación: docs/DISENO-v2.md, paso 6.2, y tarea B2-04 de
// docs/PLAN.md.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/services/firebase_auth_service.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';
import 'package:pagate_ia/features/onboarding/presentation/pages/identity_step_screen.dart';

/// Doble del servicio de Auth: no llama a Firebase, solo anota la llamada.
class _AuthFalso implements FirebaseAuthService {
  final List<Map<String, String?>> registros = [];

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required final String email,
    required final String password,
    final String? displayName,
  }) async {
    registros.add({
      'email': email,
      'password': password,
      'displayName': displayName,
    });
    // La pantalla no lee el credential: espera a que la llamada termine y
    // deja la navegación al AuthGate. Se devuelve un doble vacío solo para
    // respetar la firma.
    return _CredencialFalsa();
  }

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Doble vacío de [UserCredential]. Nadie le pide nada.
class _CredencialFalsa implements UserCredential {
  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Future<_AuthFalso> _montar(
  final WidgetTester tester, {
  final double textScale = 1.0,
}) async {
  tester.view
    ..physicalSize = const Size(360, 800)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final auth = _AuthFalso();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 800),
        textScaler: TextScaler.linear(textScale),
      ),
      // `InheritedProvider` y no `Provider`: el servicio real extiende
      // ChangeNotifier y `Provider` rechaza un Listenable. La pantalla lo
      // lee con `context.read`, que no escucha, así que no hace falta
      // propagar notificaciones.
      child: InheritedProvider<FirebaseAuthService>.value(
        value: auth,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const IdentityStepScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  return auth;
}

void main() {
  testWidgets('pide tres datos y ninguno más', (final tester) async {
    await _montar(tester);

    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.byType(PagateTextField), findsNWidgets(3));
    expect(find.text('Nombre completo'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });

  testWidgets('no queda rastro de la configuración regional (B2-04)', (
    final tester,
  ) async {
    await _montar(tester);

    // ~130 px que no producían ningún dato: el selector de país no tenía
    // onTap en ninguna línea y la moneda que se elegía aquí no la leía
    // nadie, porque el onboarding volvía a preguntarla.
    for (final muerto in ['País', 'Moneda', 'Chile', 'CLP', 'USD']) {
      expect(find.text(muerto), findsNothing, reason: muerto);
    }
  });

  testWidgets('no promete pasos que no existen', (final tester) async {
    await _montar(tester);

    // Los pasos 2 y 3 nunca existieron: en la carpeta de onboarding solo hay
    // dos pantallas y la segunda no usa PagateStepHeader.
    expect(find.byType(PagateStepHeader), findsNothing);
    expect(find.textContaining('Paso '), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('cada error sale debajo de su campo, no en un snackbar', (
    final tester,
  ) async {
    final auth = await _montar(tester);

    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(find.text('Escribe tu nombre'), findsOneWidget);
    expect(find.text('Escribe tu correo'), findsOneWidget);
    expect(find.text('Escribe una contraseña'), findsOneWidget);
    expect(auth.registros, isEmpty);
  });

  testWidgets('con los tres campos bien, crea la cuenta', (
    final tester,
  ) async {
    final auth = await _montar(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Camila Rojas');
    await tester.enterText(find.byType(TextFormField).at(1), 'camila@taller.cl');
    await tester.enterText(find.byType(TextFormField).at(2), 'greda2026');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pumpAndSettle();

    expect(auth.registros, [
      {
        'email': 'camila@taller.cl',
        'password': 'greda2026',
        'displayName': 'Camila Rojas',
      },
    ]);
  });

  testWidgets('una contraseña corta no llega a Firebase', (
    final tester,
  ) async {
    final auth = await _montar(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Camila');
    await tester.enterText(find.byType(TextFormField).at(1), 'camila@taller.cl');
    await tester.enterText(find.byType(TextFormField).at(2), '123');
    await tester.tap(find.text('Crear cuenta'));
    await tester.pump();

    expect(find.text('Usa al menos 6 caracteres'), findsOneWidget);
    expect(auth.registros, isEmpty);
  });

  testWidgets('los campos traen autocompletado y encadenamiento', (
    final tester,
  ) async {
    await _montar(tester);

    // En todo lib/ había UN textInputAction y CERO autofillHints, porque el
    // constructor del campo no los aceptaba.
    final campos = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(campos.elementAt(0).autofillHints, contains(AutofillHints.name));
    expect(campos.elementAt(1).autofillHints, contains(AutofillHints.email));
    expect(
      campos.elementAt(2).autofillHints,
      contains(AutofillHints.newPassword),
    );
    expect(campos.elementAt(0).textInputAction, TextInputAction.next);
    expect(campos.elementAt(2).textInputAction, TextInputAction.done);
    expect(find.byType(AutofillGroup), findsOneWidget);
  });

  testWidgets('salir con algo escrito pide confirmación', (
    final tester,
  ) async {
    await _montar(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Camila Rojas');
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    // En todo lib/ había CERO PopScope y el botón atrás descartaba lo
    // escrito sin avisar.
    expect(find.text('¿Descartar lo escrito?'), findsOneWidget);
  });

  testWidgets('salir sin nada escrito no molesta', (final tester) async {
    await _montar(tester);

    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar lo escrito?'), findsNothing);
  });

  testWidgets('el pie es una barra con línea, no un degradado', (
    final tester,
  ) async {
    await _montar(tester);

    expect(find.byType(PagateActionBar), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (final w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient != null,
      ),
      findsNothing,
    );
  });

  testWidgets('no desborda a 1,3x ni a 2,0x', (final tester) async {
    await _montar(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);

    await _montar(tester, textScale: 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el formulario respeta el margen lateral del sistema', (
    final tester,
  ) async {
    await _montar(tester);
    expect(
      tester.getTopLeft(find.text('Crea tu cuenta')).dx,
      AppSpacing.x4,
    );
  });
}
