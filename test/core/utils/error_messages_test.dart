// PROPÓSITO: que un fallo al GUARDAR no se cuente como un fallo al LEER.
//
// EL DEFECTO QUE ARREGLA: `describeError` estaba duplicado en
// FinancesProvider e InventoryProvider y traducía `permission-denied` a
// "No tienes permiso para ver estos datos" SIEMPRE. El usuario pulsaba
// "Registrar ingreso", las reglas rechazaban la escritura, y la app le
// contestaba que no podía ver sus datos: un diagnóstico falso, porque los
// estaba viendo, y que además no decía lo único que importaba, que el
// movimiento NO quedó guardado.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/utils/error_messages.dart';
import 'package:pagate_ia/features/finances/presentation/providers/finances_provider.dart';
import 'package:pagate_ia/features/inventory/presentation/providers/inventory_provider.dart';

FirebaseException _firestore(final String code) =>
    FirebaseException(plugin: 'cloud_firestore', code: code);

void main() {
  group('permission-denied dice qué operación falló', () {
    test('en una lectura habla de ver', () {
      expect(
        describeDataError(_firestore('permission-denied')),
        'No tienes permiso para ver estos datos',
      );
    });

    test('en una escritura dice que NO se guardó', () {
      final mensaje = describeDataError(
        _firestore('permission-denied'),
        operation: DataOperation.write,
      );

      expect(mensaje, contains('No se guardó'));
      // Lo que decía antes, y era falso: el usuario tenía los datos
      // delante, escritos en el formulario.
      expect(mensaje, isNot(contains('ver estos datos')));
    });

    test('en un borrado dice que NO se eliminó', () {
      final mensaje = describeDataError(
        _firestore('permission-denied'),
        operation: DataOperation.delete,
      );

      expect(mensaje, contains('No se eliminó'));
      expect(mensaje, isNot(contains('ver estos datos')));
    });
  });

  group('sin conexión', () {
    test('en una lectura basta decir que no hay conexión', () {
      expect(describeDataError(_firestore('unavailable')), 'Sin conexión');
    });

    test('en una escritura hay que decir que no quedó guardado', () {
      expect(
        describeDataError(
          _firestore('unavailable'),
          operation: DataOperation.write,
        ),
        'Sin conexión: no se guardó',
      );
    });
  });

  test('una sesión caída se cuenta igual en cualquier operación', () {
    for (final operacion in DataOperation.values) {
      expect(
        describeDataError(
          _firestore('unauthenticated'),
          operation: operacion,
        ),
        contains('Vuelve a entrar'),
        reason: operacion.name,
      );
    }
  });

  test('un código desconocido usa el texto del llamante', () {
    expect(
      describeDataError(
        _firestore('cuota-inventada'),
        operation: DataOperation.write,
        fallback: 'No se pudo exportar el informe',
      ),
      'No se pudo exportar el informe',
    );
  });

  test('sin fallback, el texto por defecto lo decide la operación', () {
    expect(
      describeDataError(_firestore('internal')),
      'Error al cargar',
    );
    expect(
      describeDataError(
        _firestore('internal'),
        operation: DataOperation.write,
      ),
      'No se pudo guardar',
    );
    expect(
      describeDataError(
        _firestore('internal'),
        operation: DataOperation.delete,
      ),
      'No se pudo eliminar',
    );
  });

  test('una validación del cliente se muestra tal cual', () {
    expect(
      describeDataError(ArgumentError('El monto no puede ser negativo')),
      'El monto no puede ser negativo',
    );
  });

  test('un error cualquiera no filtra su texto técnico', () {
    expect(
      describeDataError(
        StateError('Bad state: null check operator'),
        operation: DataOperation.write,
      ),
      'No se pudo guardar',
    );
  });

  group('los dos providers comparten la misma traducción', () {
    test('finanzas delega', () {
      expect(
        FinancesProvider.describeError(
          _firestore('permission-denied'),
          operation: DataOperation.write,
        ),
        describeDataError(
          _firestore('permission-denied'),
          operation: DataOperation.write,
        ),
      );
    });

    test('inventario delega', () {
      expect(
        InventoryProvider.describeError(
          _firestore('permission-denied'),
          operation: DataOperation.delete,
        ),
        describeDataError(
          _firestore('permission-denied'),
          operation: DataOperation.delete,
        ),
      );
    });

    test('sin operación siguen contando una lectura, como antes', () {
      expect(
        FinancesProvider.describeError(_firestore('unavailable')),
        'Sin conexión',
      );
    });
  });
}
