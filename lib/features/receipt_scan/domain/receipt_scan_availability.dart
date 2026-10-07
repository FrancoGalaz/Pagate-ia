import 'package:flutter/foundation.dart';

/// `true` solo donde existen los plugins nativos de lectura.
///
/// LA GUARDA NO ES DEFENSIVA, ES OBLIGATORIA. La app se sirve también en web
/// (el hosting de producción, `scripts/deploy-web.sh`) y ahí ML Kit,
/// `image_picker` en modo cámara y `receive_sharing_intent` no están
/// registrados: llamarlos lanza `MissingPluginException`, que es una traza
/// de consola y no un error que una persona pueda entender.
///
/// Cuando es `false` el FAB de Inventario va DIRECTO al formulario manual,
/// exactamente como antes de este carril. La hoja de origen no se abre, así
/// que en web no aparece ni una opción que no se pueda cumplir.
///
/// `kIsWeb` se consulta ANTES de `defaultTargetPlatform` a propósito: en el
/// navegador `defaultTargetPlatform` devuelve el sistema anfitrión, así que
/// Chrome en Android diría `TargetPlatform.android` y pasaría la guarda.
bool get lecturaDeBoletasDisponible =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
