// PROPÓSITO: blindar el borrado de cuenta dentro de la app.
//
// Es un requisito de la política de eliminación de datos de Google Play: toda
// app que permita crear una cuenta tiene que ofrecer un camino para borrarla
// DESDE DENTRO, además de la URL pública. El callable `deleteAccount` existía
// en el backend desde hace tiempo, pero en `lib/` no había una sola
// referencia, así que el camino que el revisor prueba de verdad no existía.
//
// Lo que se prueba aquí y por qué:
//  - que la pantalla diga qué se borra y que es irreversible (si eso se cae,
//    el consentimiento deja de ser informado);
//  - que el botón no se pueda pulsar hasta escribir la palabra de
//    confirmación (es lo único que separa un borrado de un toque accidental);
//  - que el cierre de sesión ocurra DESPUÉS de que el callable confirme;
//  - que un fallo NO cierre la sesión y muestre el mensaje del servidor.
//
// Sin Firebase: la pantalla recibe el correo y el cierre de sesión por
// parámetro, y el servicio por inyección.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/services/account_service.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/features/dashboard/presentation/pages/eliminar_cuenta_screen.dart';

/// Doble de [AccountService] que no habla con Cloud Functions.
class _FakeAccountService extends AccountService {
  _FakeAccountService({this.error});

  /// Si no es nulo, [deleteAccount] lo lanza.
  final AccountDeletionException? error;

  int llamadas = 0;

  @override
  Future<void> deleteAccount() async {
    llamadas++;
    final e = error;
    if (e != null) throw e;
  }
}

void main() {
  Future<void> montar(
    final WidgetTester tester, {
    required final AccountService servicio,
    required final void Function() alBorrar,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: EliminarCuentaScreen(
          email: 'camila@greda.cl',
          accountService: servicio,
          onDeleted: () async => alBorrar(),
        ),
      ),
    );
    await tester.pump();
  }

  /// Baja hasta el campo de confirmación y el botón: el cuerpo es un
  /// `ListView` y lo que no entra en pantalla todavía no está construido.
  Future<void> bajarAlPie(final WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Eliminar mi cuenta'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  testWidgets('explica que es irreversible y qué datos se borran', (
    final tester,
  ) async {
    await montar(
      tester,
      servicio: _FakeAccountService(),
      alBorrar: () {},
    );

    expect(find.text('Esto no se puede deshacer'), findsOneWidget);
    expect(find.textContaining('camila@greda.cl'), findsOneWidget);
    // Las seis líneas de qué se pierde tienen que estar, no una genérica.
    for (final dato in kDatosQueSeBorran) {
      expect(find.text(dato), findsOneWidget, reason: dato);
    }
  });

  testWidgets('el botón no hace nada hasta escribir la confirmación', (
    final tester,
  ) async {
    final servicio = _FakeAccountService();
    var cerroSesion = false;
    await montar(
      tester,
      servicio: servicio,
      alBorrar: () => cerroSesion = true,
    );

    await bajarAlPie(tester);
    await tester.tap(find.text('Eliminar mi cuenta'));
    await tester.pumpAndSettle();
    expect(servicio.llamadas, 0, reason: 'sin confirmar no se llama al borrado');
    expect(cerroSesion, isFalse);

    // Una palabra parecida tampoco vale.
    await tester.enterText(find.byType(TextFormField), 'ELIMINA');
    await tester.pump();
    await tester.tap(find.text('Eliminar mi cuenta'));
    await tester.pumpAndSettle();
    expect(servicio.llamadas, 0);
  });

  testWidgets('con la confirmación escrita borra y después cierra sesión', (
    final tester,
  ) async {
    final servicio = _FakeAccountService();
    var cerroSesion = false;
    await montar(
      tester,
      servicio: servicio,
      alBorrar: () => cerroSesion = true,
    );

    await bajarAlPie(tester);
    await tester.enterText(find.byType(TextFormField), kConfirmacionBorrado);
    await tester.pump();
    await tester.tap(find.text('Eliminar mi cuenta'));
    // `pump` y no `pumpAndSettle`: tras un borrado correcto el botón se queda
    // en carga a propósito (el indicador gira para siempre) porque la
    // pantalla desaparece sola cuando el `AuthGate` rehace la sesión.
    // `pumpAndSettle` esperaría a que esa animación terminara y nunca
    // termina.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(servicio.llamadas, 1);
    expect(cerroSesion, isTrue);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('si el borrado falla muestra el mensaje y NO cierra sesión', (
    final tester,
  ) async {
    const mensajeServidor =
        'El borrado quedó incompleto. Intenta de nuevo en unos minutos.';
    final servicio = _FakeAccountService(
      error: const AccountDeletionException('internal', mensajeServidor),
    );
    var cerroSesion = false;
    await montar(
      tester,
      servicio: servicio,
      alBorrar: () => cerroSesion = true,
    );

    await bajarAlPie(tester);
    await tester.enterText(find.byType(TextFormField), kConfirmacionBorrado);
    await tester.pump();
    await tester.tap(find.text('Eliminar mi cuenta'));
    await tester.pumpAndSettle();

    expect(servicio.llamadas, 1);
    // Si la sesión se cerrara ante un fallo, la persona se quedaría fuera de
    // una cuenta que sigue existiendo y sin forma de reintentar.
    expect(cerroSesion, isFalse);
    expect(find.text(mensajeServidor), findsOneWidget);
  });

  group('AccountDeletionException.from', () {
    test('usa el mensaje del servidor cuando viene escrito', () {
      const servidor =
          'Tus datos se borraron, pero no se pudo cerrar la cuenta. '
          'Intenta de nuevo en unos minutos.';
      final error = AccountDeletionException.from('internal', servidor);
      expect(error.message, servidor);
      expect(error.fromServer, isTrue);
    });

    test('descarta los marcadores del SDK y no afirma que no se borró nada '
        'cuando no lo sabe', () {
      final error = AccountDeletionException.from('internal', 'INTERNAL');
      expect(error.fromServer, isFalse);
      expect(error.message, isNot(contains('INTERNAL')));
      expect(error.message.trim(), isNotEmpty);
    });
  });
}
