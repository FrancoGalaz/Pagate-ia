/// PROPÓSITO: una sola fuente de verdad para el `.limit()` que
/// `firestore.rules` exige en toda consulta de colección.
///
/// POR QUÉ EXISTE ESTE ARCHIVO. El endurecimiento S-02 de las reglas separó
/// `read` en `get` y `list`, y ató `list` a este helper:
///
/// ```
/// function isLimitedList() {
///   return request.query.limit is int
///     && request.query.limit > 0
///     && request.query.limit <= 200;
/// }
/// ```
///
/// `request.query.limit` vale `null` en una consulta SIN `.limit()` explícito,
/// y `null is int` es falso, así que la regla deniega. Es decir: una consulta
/// de colección sin tope no devuelve "menos datos", devuelve
/// `permission-denied` y el usuario entra a la app y no ve nada. Ningún test
/// de widget lo detecta porque ninguno habla con Firestore.
///
/// REGLA DURA PARA QUIEN AÑADA UNA CONSULTA: toda consulta de colección del
/// cliente —`snapshots()` o `get()` sobre una `CollectionReference` o `Query`—
/// lleva `.limit()` o `.limitToLast()` con un valor de aquí. Las lecturas de
/// documento (`doc(id).snapshots()`) no: esas caen en `get`, que no mira el
/// tope.
library;

/// Topes de documentos por consulta de colección.
class FirestoreLimits {
  FirestoreLimits._();

  /// Tope máximo que aceptan las reglas (`request.query.limit <= 200`).
  ///
  /// Se usa el máximo en todas las colecciones del usuario a propósito: el
  /// tope no es una decisión de producto sino el techo de la regla, y pedir
  /// menos solo esconde datos que el usuario sí registró. Cuando una
  /// colección pase de 200 documentos habrá que paginar, y el sitio donde se
  /// decide eso es este archivo.
  static const int maxList = 200;
}
