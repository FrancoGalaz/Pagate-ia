// Registrar un movimiento sin conexión, contra los emuladores de Firebase, en
// el emulador de Android. No corre con `flutter test`: ver README, "Test de
// integración".
//
// Los widget tests prueban el formulario con un repositorio falso. Este
// prueba lo que ellos dan por supuesto: que con Firestore de verdad y la red
// cortada el guardado vuelve sin quedarse esperando, y que al reconectar hay
// UN movimiento en el servidor, no dos.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagate_ia/core/config/env.dart';
import 'package:pagate_ia/core/config/firebase_bootstrap.dart';
import 'package:pagate_ia/core/services/firebase_auth_service.dart';
import 'package:pagate_ia/features/finances/data/datasources/finances_firebase_datasource.dart';
import 'package:pagate_ia/features/finances/data/repositories/finances_repository_impl.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/finances/presentation/providers/finances_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'un movimiento guardado sin conexión no deja esperando y sube una sola vez',
    (final tester) async {
      expect(
        Env.isDev,
        isTrue,
        reason: 'correr con --dart-define=PAGATE_ENV=dev',
      );
      await bootstrapFirebase();
      final db = FirebaseFirestore.instance;
      final auth = FirebaseAuthService();
      final sufijo = DateTime.now().microsecondsSinceEpoch;

      final usuario = await auth.createUserWithEmailAndPassword(
        email: 'offline$sufijo@prueba.cl',
        password: 'clave-123456',
      );
      final uid = usuario.user!.uid;
      final provider = FinancesProvider(
        repository: FinancesRepositoryImpl(
          dataSource: FinancesFirebaseDataSource(firestore: db, userId: uid),
        ),
      );
      final movimientos = db.collection('users/$uid/transactions');

      // 1. Sin red, guardar vuelve dentro del plazo y dice "sin confirmar".
      await db.disableNetwork();
      final reloj = Stopwatch()..start();
      final confirmado = await provider.addTransaction(
        title: 'Venta en feria',
        amount: 120000,
        type: TransactionType.income,
        category: 'Venta en feria',
        date: DateTime.now(),
      );
      reloj.stop();
      expect(confirmado, isFalse);
      expect(
        reloj.elapsed,
        lessThan(
          FinancesProvider.esperaConfirmacion + const Duration(seconds: 3),
        ),
      );

      // 2. El movimiento ya está en el teléfono: las listas lo muestran.
      final enCache = await movimientos
          .limit(10)
          .get(const GetOptions(source: Source.cache));
      expect(enCache.docs, hasLength(1));
      expect(enCache.docs.single.metadata.hasPendingWrites, isTrue);

      // 3. Vuelve la red: sube solo, y en el servidor hay uno, no dos.
      await db.enableNetwork();
      await db.waitForPendingWrites().timeout(const Duration(seconds: 30));
      final enServidor = await movimientos
          .limit(10)
          .get(const GetOptions(source: Source.server));
      expect(enServidor.docs, hasLength(1));
      expect(enServidor.docs.single.data()['title'], 'Venta en feria');

      provider.dispose();
      final cierre = auth.cerrarSesion();
      await tester.pump();
      expect(await cierre, isTrue);
    },
  );
}
