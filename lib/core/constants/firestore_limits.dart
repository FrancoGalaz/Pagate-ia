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

  /// Operaciones que caben en un `WriteBatch` de Firestore.
  ///
  /// POR QUÉ ESTÁ AQUÍ Y NO ESCRITO EN EL DATASOURCE. El lector de boletas
  /// escribe todo lo que el usuario confirmó en UN lote atómico, y su tope
  /// de artículos (`kMaxArticulosPorBoleta`, en
  /// `features/receipt_scan/data/parsers/local_line_item_parser.dart`) vive
  /// en otro archivo. Mientras el 500 estuviera solo en un comentario del
  /// datasource, nada ataba las dos cifras: subir el tope de la boleta a
  /// 600 compilaba, pasaba todos los tests y reventaba en producción con un
  /// error del servidor, con la boleta entera sin guardar.
  ///
  /// Ahora los dos extremos están atados por código y por un test:
  ///   · `InventoryProvider.applyScannedItems` cuenta las operaciones y se
  ///     niega a mandar un lote que no quepa, con un mensaje propio en vez
  ///     de un fallo opaco del servidor;
  ///   · `test/features/inventory/inventory_provider_test.dart` fija que el
  ///     tope de artículos por boleta cabe en este presupuesto, así que
  ///     subirlo sin mirar pone el test rojo.
  ///
  /// El número es el de la documentación de Firestore: un lote admite hasta
  /// 500 operaciones de escritura.
  static const int maxBatchWrites = 500;
}
