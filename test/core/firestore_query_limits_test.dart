// PROPÓSITO: impedir que vuelva a aparecer una consulta de colección sin
// `.limit()`.
//
// POR QUÉ ESTE TEST LEE EL CÓDIGO FUENTE Y NO EJECUTA NADA. El endurecimiento
// S-02 de `firestore.rules` ató la operación `list` a este helper:
//
//   function isLimitedList() {
//     return request.query.limit is int
//       && request.query.limit > 0
//       && request.query.limit <= 200;
//   }
//
// En una consulta sin `.limit()` explícito `request.query.limit` vale `null`,
// `null is int` es falso y la regla DENIEGA. El síntoma no es "veo menos
// datos": es `permission-denied`, el usuario entra a la app y no ve ninguno de
// sus datos. Cinco consultas del cliente estaban así y ningún test lo
// detectaba, porque ningún test de widget ni de unidad habla con Firestore: la
// única forma de verlo era arrancar la app contra los emuladores.
//
// Este test cierra ese agujero sin necesitar emulador: recorre `lib/`, aísla
// cada sentencia que termina en `.snapshots()` o en `.get()` y exige un tope a
// las que consultan una COLECCIÓN. Las lecturas de documento
// (`doc(id).snapshots()`) quedan fuera a propósito: caen en la operación `get`,
// que no mira `request.query.limit`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/constants/firestore_limits.dart';

/// Quita comentarios de línea y de bloque para que un ejemplo escrito dentro
/// de un docstring (este archivo está lleno de ellos) no cuente como código.
String _stripComments(final String source) {
  final withoutBlocks = source.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return withoutBlocks
      .split('\n')
      .map((final line) {
        final i = line.indexOf('//');
        return i == -1 ? line : line.substring(0, i);
      })
      .join('\n');
}

/// Marcas que solo pueden aparecer sobre una `Query`/`CollectionReference`.
const List<String> _collectionTokens = [
  '.collection(',
  '.where(',
  '.orderBy(',
];

const List<String> _limitTokens = ['.limit(', '.limitToLast('];

void main() {
  test('toda consulta de colección de lib/ lleva .limit() o .limitToLast()', () {
    final lib = Directory('lib');
    expect(
      lib.existsSync(),
      isTrue,
      reason: 'el test se ejecuta desde la raíz del repo',
    );

    final offenders = <String>[];
    var collectionQueries = 0;

    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final code = _stripComments(entity.readAsStringSync());

      for (final statement in code.split(';')) {
        for (final reader in const ['.snapshots()', '.get()']) {
          final at = statement.indexOf(reader);
          if (at == -1) continue;
          final chain = statement.substring(0, at);

          // ¿La cadena termina sobre una colección o sobre un documento? Se
          // compara la última marca de colección con el último `.doc(`: si el
          // `.doc(` es lo último, es una lectura de documento y la regla
          // aplicable es `get`, que no exige tope.
          final lastDoc = chain.lastIndexOf('.doc(');
          final lastCollection = _collectionTokens
              .map(chain.lastIndexOf)
              .fold(-1, (final a, final b) => a > b ? a : b);
          if (lastCollection == -1 || lastCollection < lastDoc) continue;

          collectionQueries++;
          final hasLimit = _limitTokens.any(chain.contains);
          if (!hasLimit) {
            offenders.add('${entity.path}: ${chain.trim().split('\n').last}');
          }
        }
      }
    }

    // Si esta cuenta baja de golpe, el heurístico dejó de encontrar las
    // consultas y el test estaría pasando en vacío.
    expect(
      collectionQueries,
      greaterThanOrEqualTo(6),
      reason: 'se esperaban al menos las 6 consultas de colección conocidas',
    );
    expect(
      offenders,
      isEmpty,
      reason:
          'consultas de colección sin tope: la regla `list` de firestore.rules '
          'las deniega y el usuario no ve ningún dato.\n'
          '${offenders.join('\n')}',
    );
  });

  test('el tope no supera el máximo que aceptan las reglas', () {
    expect(FirestoreLimits.maxList, greaterThan(0));
    expect(FirestoreLimits.maxList, lessThanOrEqualTo(200));
  });
}
