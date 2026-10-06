// PROPÓSITO: impedir que vuelva a aparecer un `copyWith(fontWeight: ...)`.
//
// EL DEFECTO QUE CIERRA. Manrope es una fuente variable y entra al motor como
// una única cara: `name` ID 1 es "Manrope ExtraLight", `OS/2.usWeightClass` es
// 200 y el eje `wght` de `fvar` tiene su valor por defecto en 200. Con una
// sola cara registrada, `fontWeight` no selecciona ninguna otra: el trazo real
// lo decide `fontVariations`.
//
// `TextStyle.copyWith(fontWeight: ...)` NO toca `fontVariations`. O sea que
// `AppText.titleLarge.copyWith(fontWeight: FontWeight.w800)` se sigue
// dibujando en 600, que es el `wght` que trae el estilo. Eran 81 sitios en 26
// archivos, todos convencidos de estar cambiando el peso.
//
// La forma correcta es `AppText.weight(estilo, peso)`, que mueve los dos.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Quita comentarios para que un ejemplo escrito dentro de un docstring —como
/// los de `app_text.dart`— no cuente como código.
String _sinComentarios(final String fuente) {
  final sinBloques = fuente.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return sinBloques
      .split('\n')
      .map((final linea) {
        final i = linea.indexOf('//');
        return i == -1 ? linea : linea.substring(0, i);
      })
      .join('\n');
}

void main() {
  test('ningún widget de lib/ cambia el peso con copyWith(fontWeight:)', () {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'se ejecuta desde la raíz');

    // `app_text.dart` es el único sitio donde `copyWith(fontWeight:)` es
    // correcto: ahí va acompañado de `fontVariations`, que es justo lo que
    // hace `AppText.weight`.
    const permitido = 'app_text.dart';

    final culpables = <String>[];
    for (final e in lib.listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      if (e.path.endsWith(permitido)) continue;
      final codigo = _sinComentarios(e.readAsStringSync());

      // Busca `copyWith(` y mira si dentro de sus paréntesis, al nivel de
      // argumentos, aparece `fontWeight`. El PDF usa `pw.FontWeight` de otra
      // librería y no entra aquí porque no se construye con `copyWith`.
      for (final m in RegExp(r'\.copyWith\(').allMatches(codigo)) {
        var profundidad = 0;
        var i = m.end - 1;
        final buffer = StringBuffer();
        while (i < codigo.length) {
          final c = codigo[i];
          if (c == '(' || c == '[' || c == '{') profundidad++;
          if (c == ')' || c == ']' || c == '}') {
            profundidad--;
            if (profundidad == 0) break;
          }
          buffer.write(c);
          i++;
        }
        if (buffer.toString().contains('fontWeight')) {
          culpables.add(e.path);
          break;
        }
      }
    }

    expect(
      culpables,
      isEmpty,
      reason:
          'copyWith(fontWeight:) no mueve fontVariations y en una fuente '
          'variable gana fontVariations: el peso no cambia. Usa '
          'AppText.weight(estilo, peso).\n${culpables.join('\n')}',
    );
  });
}
