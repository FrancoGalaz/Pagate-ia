// PROPÓSITO: que no vuelva a entrar en lib/ un texto que miente, que promete
// algo que la app no hace, o que trae un emoji en un título.
//
// Cada cadena de la lista estuvo de verdad en la app y se quitó por un motivo
// concreto, no por estilo. La peor: el registro prometía "recibir pagos
// globalmente" cuando Págate-IA no cobra ni recibe un solo peso; y la pantalla
// de Ayuda mostraba "Reduce tus gastos fijos en 10% para ganar $830 extra
// este mes" como si fuera un cálculo sobre el negocio del usuario, con una
// cifra escrita a mano en el widget.
//
// Si una de estas frases vuelve, este test falla y dice cuál y dónde.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Quita comentarios: este mismo archivo y los comentarios del código citan
/// las frases prohibidas para explicar por qué se fueron.
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

/// Frase prohibida → por qué.
const Map<String, String> _prohibidas = {
  'recibir pagos globalmente':
      'la app no recibe pagos, y el mercado es Chile',
  'La primera herramienta':
      'ser "la primera" no se puede comprobar',
  'maximiza tus ganancias':
      'la app no aumenta los ingresos de nadie',
  'Empezar a ganar más':
      'un botón no hace ganar más',
  'Solo tarda 2 minutos':
      'cifra inventada sobre el propio producto',
  r'$830':
      'cifra inventada presentada como un cálculo del negocio',
  'Sugerencia del día':
      'no existe ninguna sugerencia calculada',
  'soporte@pagate-ia.com':
      'dominio que no se controla: prometía una atención que no existe',
  'Próximamente disponible':
      '"próximamente" es un compromiso de fecha',
  'estará disponible próximamente':
      '"próximamente" es un compromiso de fecha',
  'Pronto abriremos':
      '"pronto" es un compromiso de fecha',
  'revisar los términos desde configuración':
      'no hay términos en Configuración',
  'costo real de tus productos':
      'la app no calcula el costo de un producto',
  'sin perder dinero':
      'eso es un consejo, y además no se puede garantizar',
  "?? 'Artesano'":
      'nombre inventado mientras carga el perfil',
  "?? 'Mi Negocio'":
      'negocio inventado mientras carga el perfil',
  "?? 'Tu Nombre'":
      'nombre inventado en el perfil mientras carga',
  "?? 'IA'":
      'iniciales inventadas en el avatar',
};

/// Emojis: el sistema visual (docs/DISENO-v2.md) no los admite en la
/// interfaz. Cubre los bloques donde caen los que había (👋).
final RegExp _emoji = RegExp(
  '[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]',
  unicode: true,
);

void main() {
  late List<File> fuentes;

  setUp(() {
    final lib = Directory('lib');
    expect(lib.existsSync(), isTrue, reason: 'se ejecuta desde la raíz');
    fuentes = lib
        .listSync(recursive: true)
        .whereType<File>()
        .where((final f) => f.path.endsWith('.dart'))
        .toList();
    expect(fuentes.length, greaterThan(20));
  });

  test('ninguna frase retirada volvió a lib/', () {
    final culpables = <String>[];
    for (final fuente in fuentes) {
      final codigo = _sinComentarios(fuente.readAsStringSync());
      for (final entrada in _prohibidas.entries) {
        if (codigo.contains(entrada.key)) {
          culpables.add(
            '${fuente.path}: "${entrada.key}" — ${entrada.value}',
          );
        }
      }
    }
    expect(culpables, isEmpty, reason: culpables.join('\n'));
  });

  test('no hay emojis en la interfaz', () {
    final culpables = <String>[];
    for (final fuente in fuentes) {
      final lineas = _sinComentarios(fuente.readAsStringSync()).split('\n');
      for (var i = 0; i < lineas.length; i++) {
        if (_emoji.hasMatch(lineas[i])) {
          culpables.add('${fuente.path}:${i + 1}: ${lineas[i].trim()}');
        }
      }
    }
    expect(culpables, isEmpty, reason: culpables.join('\n'));
  });
}
