// Guardar sin conexión en gastos fijos, inventario, lote de una boleta,
// perfil y valor hora, contra los emuladores de Firebase, en el emulador de
// Android. No corre con `flutter test`: ver README, "Test de integración".
//
// Los widget tests prueban cada pantalla con un repositorio falso. Este
// prueba lo que ellos dan por supuesto: que con Firestore de verdad y la red
// cortada cada guardado vuelve sin quedarse esperando, y que al reconectar
// cada cosa está UNA vez en el servidor, con las reglas de verdad.
// El de registrar un movimiento está en `movimiento_sin_conexion_test.dart`.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pagate_ia/core/config/env.dart';
import 'package:pagate_ia/core/config/firebase_bootstrap.dart';
import 'package:pagate_ia/core/services/firebase_auth_service.dart';
import 'package:pagate_ia/core/utils/escritura_pendiente.dart';
import 'package:pagate_ia/features/auth/presentation/widgets/user_scope.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_entity.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_type.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'guardar sin conexión no deja esperando y sube cada cosa una sola vez',
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
        email: 'guardar$sufijo@prueba.cl',
        password: 'clave-123456',
      );
      final uid = usuario.user!.uid;
      final finanzas = createFinancesProvider(firestore: db, userId: uid);
      final inventario = createInventoryProvider(firestore: db, userId: uid);
      final perfil = createUserProfileProvider(firestore: db, userId: uid);
      final valorHora = createHourlyRateProvider(firestore: db, userId: uid);
      final fichas = db.collection('users/$uid/inventory');
      final gastos = db.collection('users/$uid/fixedExpenses');

      // 0. Con red: una ficha que ya existe, para ajustarle el stock después.
      expect(
        await inventario.addItem(
          name: 'Arcilla gres',
          type: InventoryItemType.material,
          price: 18990,
          stock: 4,
          minStock: 1,
          unit: 'sacos',
        ),
        isTrue,
        reason: 'control: con red el servidor confirma',
      );
      final arcilla = (await fichas
              .limit(10)
              .get(const GetOptions(source: Source.server)))
          .docs
          .single
          .id;

      await db.disableNetwork();

      /// Corre [guardar] sin red y comprueba que vuelve dentro del plazo.
      Future<T> sinEsperar<T>(final Future<T> Function() guardar) async {
        final reloj = Stopwatch()..start();
        final resultado = await guardar();
        expect(
          reloj.elapsed,
          lessThan(kEsperaConfirmacion + const Duration(seconds: 3)),
        );
        return resultado;
      }

      // 1. Gasto fijo.
      expect(
        await sinEsperar(
          () => finanzas.addFixedExpense(name: 'Arriendo', amount: 250000),
        ),
        isFalse,
      );

      // 2. Inventario: una ficha nueva y un ajuste de stock.
      expect(
        await sinEsperar(
          () => inventario.addItem(
            name: 'Taza de greda',
            type: InventoryItemType.product,
            price: 12500,
            stock: 6,
            minStock: 1,
            unit: 'unidades',
          ),
        ),
        isFalse,
      );
      expect(
        await sinEsperar(
          () => inventario.updateStock(itemId: arcilla, newStock: 9),
        ),
        isFalse,
      );

      // 3. Confirmar los materiales de una boleta: un alta y una suma de
      //    stock en el mismo lote.
      expect(
        await sinEsperar(
          () => inventario.applyScannedItems(
            nuevos: const [
              InventoryItemEntity(
                id: '',
                name: 'Esmalte transparente',
                type: InventoryItemType.material,
                price: 12500,
                stock: 1,
                minStock: 1,
                unit: 'kg',
              ),
            ],
            stocksFinales: {arcilla: 12},
            preciosNuevos: const {},
          ),
        ),
        isFalse,
      );

      // 4. Perfil del onboarding y valor hora.
      expect(
        await sinEsperar(
          () => perfil.updateFromSetup(
            name: 'Valentina Soto',
            businessName: 'Greda Austral',
            businessType: 'Cerámica',
            currency: 'CLP',
            monthlyGoal: 800000,
          ),
        ),
        isFalse,
      );
      expect(perfil.isSaving, isFalse);
      expect(
        await sinEsperar(
          () => valorHora.saveMonthlyHours(
            desiredSalary: 800000,
            availableHoursPerMonth: 160,
          ),
        ),
        isTrue,
      );
      expect(valorHora.guardadoSinConexion, isTrue);

      // 5. Vuelve la red: todo sube solo y cada cosa está una sola vez.
      await db.enableNetwork();
      await db.waitForPendingWrites().timeout(const Duration(seconds: 30));
      const servidor = GetOptions(source: Source.server);

      final gastosEnServidor = await gastos.limit(10).get(servidor);
      expect(gastosEnServidor.docs, hasLength(1));
      expect(gastosEnServidor.docs.single.data()['name'], 'Arriendo');

      final fichasEnServidor = await fichas.limit(10).get(servidor);
      final nombres = [
        for (final d in fichasEnServidor.docs) d.data()['name'] as String,
      ]..sort();
      expect(nombres, ['Arcilla gres', 'Esmalte transparente', 'Taza de greda']);
      final arcillaEnServidor = await fichas.doc(arcilla).get(servidor);
      expect(arcillaEnServidor.data()?['stock'], 12);

      final perfilEnServidor = await db.doc('users/$uid').get(servidor);
      expect(perfilEnServidor.data()?['businessName'], 'Greda Austral');
      expect(
        (perfilEnServidor.data()?['hourlyRate'] as Map?)?['hourlyValue'],
        5000,
      );

      finanzas.dispose();
      inventario.dispose();
      perfil.dispose();
      valorHora.dispose();
      final cierre = auth.cerrarSesion();
      await tester.pump();
      expect(await cierre, isTrue);
    },
  );
}
