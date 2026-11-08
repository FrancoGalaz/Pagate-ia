// Cierre de sesión contra los emuladores de Firebase, en el emulador de
// Android. No corre con `flutter test`: ver README, "Test de integración".

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagate_ia/core/config/env.dart';
import 'package:pagate_ia/core/config/firebase_bootstrap.dart';
import 'package:pagate_ia/core/services/firebase_auth_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'otro usuario en el mismo teléfono no hereda la caché del anterior, '
      'y conserva la persistencia offline', (final tester) async {
    expect(Env.isDev, isTrue, reason: 'correr con --dart-define=PAGATE_ENV=dev');
    await bootstrapFirebase();
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuthService();
    final sufijo = DateTime.now().microsecondsSinceEpoch;

    Future<void> cerrar() async {
      final cierre = auth.cerrarSesion();
      await tester.pump();
      expect(await cierre, isTrue);
    }

    // 1. A inicia sesión y escribe.
    final a = await auth.createUserWithEmailAndPassword(
      email: 'a$sufijo@prueba.cl',
      password: 'clave-123456',
    );
    final docA = db.doc('users/${a.user!.uid}/fixedExpenses/arriendo');
    await docA.set({
      'name': 'Arriendo de A',
      'amount': 250000,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    final antes = await docA.get(const GetOptions(source: Source.cache));
    expect(antes.data()?['name'], 'Arriendo de A',
        reason: 'control: antes de cerrar, el dato sí está en caché');

    // 2. A cierra sesión.
    await cerrar();

    // 3. La caché ya no tiene el documento de A.
    await expectLater(
      docA.get(const GetOptions(source: Source.cache)),
      throwsA(isA<FirebaseException>()),
    );
    final cacheA = await db
        .collection('users/${a.user!.uid}/fixedExpenses')
        .get(const GetOptions(source: Source.cache));
    expect(cacheA.docs, isEmpty);

    // 4. B inicia sesión y lee lo suyo sin errores.
    final b = await auth.createUserWithEmailAndPassword(
      email: 'b$sufijo@prueba.cl',
      password: 'clave-123456',
    );
    final gastosB = db.collection('users/${b.user!.uid}/fixedExpenses');
    final servidorB = await gastosB
        .limit(10)
        .get(const GetOptions(source: Source.server));
    expect(servidorB.docs, isEmpty);

    // 5. B tiene persistencia activa: escribe sin conexión y lo lee de caché.
    await db.disableNetwork();
    final escrituraB = gastosB.doc('luz').set({
      'name': 'Luz de B',
      'amount': 30000,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // El plugin de Android corre `set` y `get` en hilos distintos: sin esta
    // espera, la lectura puede adelantarse a que la escritura entre en caché.
    await gastosB
        .doc('luz')
        .snapshots()
        .firstWhere((final s) => s.exists)
        .timeout(const Duration(seconds: 10));
    expect(db.settings.persistenceEnabled, isTrue);
    final offline =
        await gastosB.doc('luz').get(const GetOptions(source: Source.cache));
    expect(offline.data()?['name'], 'Luz de B');
    await db.enableNetwork();
    await escrituraB.timeout(const Duration(seconds: 20));

    await cerrar();
  });
}
