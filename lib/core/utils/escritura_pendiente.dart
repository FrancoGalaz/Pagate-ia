import 'dart:async';

import 'package:flutter/foundation.dart';

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

/// Espera [escritura] como mucho [kEsperaConfirmacion].
///
/// Devuelve `true` si el servidor la confirmó y `false` si sigue pendiente.
/// Si falla dentro del plazo, el error se propaga igual que antes. Si el
/// servidor la rechaza después, ya no hay pantalla a la que avisar: se
/// registra.
Future<bool> confirmadaATiempo(final Future<void> escritura) async {
  try {
    await escritura.timeout(kEsperaConfirmacion);
    return true;
  } on TimeoutException {
    unawaited(
      escritura.catchError((final Object e) {
        debugPrint('El servidor rechazó una escritura hecha sin conexión: $e');
      }),
    );
    return false;
  }
}
