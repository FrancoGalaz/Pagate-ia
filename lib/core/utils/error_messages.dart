import 'package:firebase_core/firebase_core.dart';

// ═══════════════════════════════════════════════════════════════════════
// MENSAJES DE ERROR DE LA CAPA DE DATOS
// ═══════════════════════════════════════════════════════════════════════
// POR QUÉ EXISTE ESTE ARCHIVO: había DOS copias idénticas de `describeError`
// (FinancesProvider e InventoryProvider) y las dos traducían
// `permission-denied` a "No tienes permiso para VER estos datos" también
// cuando el fallo había ocurrido al GUARDAR o al ELIMINAR. El usuario pulsaba
// "Registrar ingreso", el guardado se rechazaba y la app le contestaba que no
// podía ver sus datos, que es un diagnóstico falso: los estaba viendo.
//
// La traducción pasa a depender de la operación. Un mismo código de Firestore
// se cuenta distinto según lo que se estaba intentando hacer.
// ═══════════════════════════════════════════════════════════════════════

/// Qué estaba intentando hacer la app cuando falló.
///
/// No es un detalle cosmético: el mismo `permission-denied` significa "no
/// puedes leer esto" en una lectura y "el guardado fue rechazado" en una
/// escritura, y el usuario tiene que poder distinguirlo para saber si perdió
/// lo que escribió.
enum DataOperation {
  /// Suscripción o consulta: un `snapshots()` que emite error.
  read,

  /// Alta o actualización de un documento.
  write,

  /// Borrado de un documento.
  delete,
}

/// Texto por defecto cuando no se reconoce el error.
String _fallbackPorOperacion(final DataOperation operation) =>
    switch (operation) {
      DataOperation.read => 'Error al cargar',
      DataOperation.write => 'No se pudo guardar',
      DataOperation.delete => 'No se pudo eliminar',
    };

/// Traduce una excepción de la capa de datos a un mensaje corto en español.
///
/// [operation] decide el texto: sin ella, un fallo al guardar se contaba como
/// un fallo al leer. [fallback] permite al llamante poner el verbo de su
/// propia acción ("No se pudo exportar"); si no se pasa, se usa el de la
/// operación.
String describeDataError(
  final Object error, {
  final DataOperation operation = DataOperation.read,
  final String? fallback,
}) {
  final porDefecto = fallback ?? _fallbackPorOperacion(operation);

  if (error is FirebaseException) {
    switch (error.code) {
      // Las reglas rechazaron la operación. En una lectura el usuario no
      // llega a ver el dato; en una escritura SÍ lo tiene delante, escrito,
      // y lo que necesita saber es que no quedó guardado.
      case 'permission-denied':
        return switch (operation) {
          DataOperation.read => 'No tienes permiso para ver estos datos',
          DataOperation.write =>
            'No se guardó: esta cuenta no tiene permiso para escribir aquí',
          DataOperation.delete =>
            'No se eliminó: esta cuenta no tiene permiso para borrar aquí',
        };

      // La sesión dejó de ser válida. Reintentar no sirve: hay que volver a
      // entrar, y eso es lo único que se le puede pedir al usuario.
      case 'unauthenticated':
        return 'Tu sesión se cerró. Vuelve a entrar para continuar';

      // Sin red, o Firestore inalcanzable. En una escritura importa decir que
      // NO quedó guardado: el usuario acaba de escribir un monto.
      case 'unavailable':
        return switch (operation) {
          DataOperation.read => 'Sin conexión',
          DataOperation.write => 'Sin conexión: no se guardó',
          DataOperation.delete => 'Sin conexión: no se eliminó',
        };

      case 'deadline-exceeded':
        return switch (operation) {
          DataOperation.read => 'La conexión tardó demasiado',
          DataOperation.write => 'La conexión tardó demasiado: no se guardó',
          DataOperation.delete => 'La conexión tardó demasiado: no se eliminó',
        };

      // Solo puede pasar al actualizar o borrar algo que ya no está, por
      // ejemplo porque se eliminó desde otro dispositivo.
      case 'not-found':
        return 'Ese dato ya no existe: puede que se haya eliminado';

      default:
        return porDefecto;
    }
  }

  // Validaciones del propio cliente (los datasources lanzan ArgumentError con
  // el motivo ya escrito para una persona).
  if (error is ArgumentError) {
    return error.message?.toString() ?? porDefecto;
  }

  return porDefecto;
}
