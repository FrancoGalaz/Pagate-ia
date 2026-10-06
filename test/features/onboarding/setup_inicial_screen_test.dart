// Widget test de SetupInicialScreen, sin Firebase.
//
// Especificación: docs/DISENO-v2.md, paso 6.3.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/services/firebase_auth_service.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';
import 'package:pagate_ia/features/onboarding/presentation/pages/setup_inicial_screen.dart';
import 'package:pagate_ia/features/user_profile/presentation/providers/user_profile_provider.dart';

/// Doble del servicio de Auth. [displayName] es lo único que la pantalla le
/// pide, y `signOut` lo que ofrece el botón del pie.
class _AuthFalso extends ChangeNotifier implements FirebaseAuthService {
  _AuthFalso({this.displayName});

  @override
  String? displayName;

  int cierresDeSesion = 0;

  @override
  Future<void> signOut() async => cierresDeSesion++;

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Doble del proveedor de perfil: anota lo que se le mandó guardar.
class _PerfilFalso extends ChangeNotifier implements UserProfileProvider {
  final List<Map<String, Object?>> guardados = [];

  @override
  Future<void> updateFromSetup({
    required final String name,
    required final String businessName,
    required final String businessType,
    required final String currency,
    required final double monthlyGoal,
  }) async {
    guardados.add({
      'name': name,
      'businessName': businessName,
      'businessType': businessType,
      'currency': currency,
      'monthlyGoal': monthlyGoal,
    });
  }

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _Dobles {
  _Dobles(this.auth, this.perfil);
  final _AuthFalso auth;
  final _PerfilFalso perfil;
}

Future<_Dobles> _montar(
  final WidgetTester tester, {
  final String? displayName,
  final double textScale = 1.0,
}) async {
  tester.view
    ..physicalSize = const Size(360, 900)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final auth = _AuthFalso(displayName: displayName);
  final perfil = _PerfilFalso();

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<FirebaseAuthService>.value(value: auth),
          ChangeNotifierProvider<UserProfileProvider>.value(value: perfil),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SetupInicialScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  return _Dobles(auth, perfil);
}

void main() {
  testWidgets('precarga el nombre del registro UNA sola vez', (
    final tester,
  ) async {
    final dobles = await _montar(tester, displayName: 'Valentina Soto');
    expect(find.text('Valentina Soto'), findsOneWidget);

    // El usuario lo borra para escribir otro.
    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.pump();

    // Y algo cambia las dependencias: el teclado, una rotación, el tamaño
    // de fuente del sistema. Antes bastaba con eso para que el campo se
    // rellenara solo y el cursor saltara al inicio.
    dobles.auth.notifyListeners();
    await tester.pump();

    expect(find.text('Valentina Soto'), findsNothing);
  });

  testWidgets('sin displayName el campo arranca vacío', (final tester) async {
    await _montar(tester);
    final campo = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(campo.first.controller.text, isEmpty);
  });

  testWidgets('cada error sale debajo de su campo', (final tester) async {
    final dobles = await _montar(tester);

    await tester.tap(find.text('Guardar y empezar'));
    await tester.pump();

    expect(find.text('Escribe tu nombre'), findsOneWidget);
    expect(find.text('Escribe el nombre de tu taller'), findsOneWidget);
    expect(find.text('Escribe cuánto quieres ganar al mes'), findsOneWidget);
    expect(find.text('Elige tu rubro para continuar'), findsOneWidget);
    expect(dobles.perfil.guardados, isEmpty);
  });

  testWidgets('una meta escrita como la escribe un chileno se guarda entera', (
    final tester,
  ) async {
    final dobles = await _montar(tester, displayName: 'Valentina Soto');

    await tester.enterText(find.byType(TextFormField).at(1), 'Greda Austral');
    await tester.tap(find.text('Cerámica'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(2), '800.000');
    await tester.tap(find.text('Guardar y empezar'));
    await tester.pumpAndSettle();

    // El defecto que esto vigila: `double.tryParse('800.000')` devuelve
    // 800.0 y la validación `goal <= 0` lo dejaba pasar, así que la meta
    // entraba al perfil como OCHOCIENTOS pesos y la barra de progreso de
    // Inicio marcaba 100% con la primera venta.
    expect(dobles.perfil.guardados, [
      {
        'name': 'Valentina Soto',
        'businessName': 'Greda Austral',
        'businessType': 'Cerámica',
        'currency': 'CLP',
        'monthlyGoal': 800000.0,
      },
    ]);
  });

  testWidgets('el rubro y la moneda son chips de Material, no pastillas', (
    final tester,
  ) async {
    await _montar(tester);

    // Dos de los cuatro criterios de selección que coexistían en la app
    // (_PillSelector aquí, _TypeTab en inventario, las pastillas de perfil)
    // desaparecen a favor de uno solo con rol y estado.
    expect(find.byType(PagateChipSelector), findsNWidgets(2));
    expect(find.text('CLP'), findsOneWidget);
    expect(find.text('USD'), findsOneWidget);
  });

  testWidgets('el botón de guardar está fijo, no al final del scroll', (
    final tester,
  ) async {
    await _montar(tester);
    expect(find.byType(PagateActionBar), findsOneWidget);
    expect(find.text('Guardar y empezar'), findsOneWidget);
  });

  testWidgets('se puede cerrar sesión para usar otra cuenta', (
    final tester,
  ) async {
    final dobles = await _montar(tester);

    await tester.ensureVisible(find.text('Usar otra cuenta'));
    await tester.pump();
    await tester.tap(find.text('Usar otra cuenta'));
    await tester.pump();

    expect(dobles.auth.cierresDeSesion, 1);
  });

  testWidgets('el margen lateral es el del sistema', (final tester) async {
    await _montar(tester);
    expect(
      tester.getTopLeft(find.text('Configura tu taller')).dx,
      AppSpacing.x4,
    );
  });

  testWidgets('no desborda a 1,3x ni a 2,0x', (final tester) async {
    await _montar(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);

    await _montar(tester, textScale: 2.0);
    expect(tester.takeException(), isNull);
  });
}
