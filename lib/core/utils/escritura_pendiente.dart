import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/crash_reporter.dart';

// ═══════════════════════════════════════════════════════════════════════
// GUARDAR SIN CONEXIÓN
//
// Con la caché de Firestore activa, el `Future` de una escritura solo termina
// cuando el SERVIDOR la confirma. Sin red no termina nunca, aunque la
// escritura ya esté a salvo en la cola local y las listas la muestren. Una
// pantalla que haga `await` de ese `Future` se queda cargando sin fin, y lo
// razonable para quien la mira es cerrar la app y anotar lo mismo otra vez.
//
// [confirmadaATiempo] le pone plazo a esa espera. NO reintenta ni reenvía
// nada: la escritura sigue en la cola de Firestore, que la sube una sola vez
// cuando vuelve la conexión.
// ═══════════════════════════════════════════════════════════════════════

/// Cuánto se espera la confirmación del servidor antes de dar una escritura
/// por guardada en el teléfono y pendiente de sincronizar.
const Duration kEsperaConfirmacion = Duration(seconds: 4);

/// Lo que lee el usuario cuando su guardado quedó en el teléfono.
const String kGuardadoEnElTelefono =
    'Guardado en el teléfono. Se sincronizará cuando vuelva la conexión.';

/// Lo mismo para un borrado: «guardado» haría pensar que la cosa sigue ahí.
const String kEliminadoEnElTelefono =
    'Eliminado en el teléfono. Se sincronizará cuando vuelva la conexión.';

/// Quién le avisa al usuario que el servidor rechazó, al sincronizar, algo
/// que se había guardado sin conexión.
///
/// Lo registra `AppShell` mientras la app está montada. La pantalla que
/// guardó ya avisó «Guardado en el teléfono» y probablemente ya se cerró, así
/// que el aviso no puede depender de ella.
abstract final class RechazoAlSincronizar {
  /// `null` sin app montada (tests, cierre): queda solo el informe de fallos.
  static void Function(String mensaje)? avisar;
}

/// Espera [escritura] como mucho [kEsperaConfirmacion].
///
/// Devuelve `true` si el servidor la confirmó y `false` si sigue pendiente.
/// Si falla dentro del plazo, el error se propaga igual que antes.
///
/// Si el servidor la rechaza DESPUÉS del plazo, se le muestra al usuario
/// [siSeRechaza] por medio de [RechazoAlSincronizar], y el error se reporta
/// con [CrashReporter]. [siSeRechaza] tiene que decir QUÉ no se guardó
/// («No se pudo guardar el movimiento «Venta en feria».»): con varios
/// guardados pendientes, «algo falló» no le sirve a nadie. Ese texto va solo
/// a la pantalla; al informe de fallos no llega.
///
/// Límite que no se puede cubrir: si la app se cierra antes de sincronizar,
/// Firestore sube la escritura al volver a abrirla, pero ya no queda ningún
/// `Future` que escuche la respuesta.
Future<bool> confirmadaATiempo(
  final Future<void> escritura, {
  required final String siSeRechaza,
}) async {
  try {
    await escritura.timeout(kEsperaConfirmacion);
    return true;
  } on TimeoutException {
    unawaited(
      escritura.catchError((final Object e, final StackTrace traza) {
        debugPrint('El servidor rechazó una escritura hecha sin conexión: $e');
        RechazoAlSincronizar.avisar?.call(siSeRechaza);
        CrashReporter.reportar(
          e,
          traza,
          motivo: 'escritura rechazada al sincronizar',
        );
      }),
    );
    return false;
  }
}
