// LA CAJA DE LOS NOMBRES QUE SALEN DE UNA BOLETA.
//
// EL DEFECTO QUE FIJA, VISTO EN PANTALLA. Una boleta chilena se imprime
// entera en mayúsculas, así que `ARCILLA GRES 25K` entraba tal cual al
// inventario y quedaba en la lista de Materiales al lado de `Caolín` y
// `Esmalte transparente`, que los escribió el usuario. La pestaña parecía
// dos inventarios distintos pegados.
//
// Y LO QUE FIJA ADEMÁS ES LO QUE **NO** SE TOCA, que es la parte que un
// `toLowerCase()` habría roto: las medidas (`25K`, `250G`), los códigos
// (`N6`), las siglas de material (`PVC`, `MDF`) y las tildes que el
// reconocimiento no trajo. `OXIDO` se queda `Oxido`: inventar la tilde
// obligaría a un diccionario del español, y un diccionario se equivoca en
// nombres propios y en marcas.

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/receipt_scan/data/parsers/item_name_case.dart';

void main() {
  group('baja la mayúscula de la boleta a caja de frase', () {
    test('un nombre de dos palabras', () {
      expect(normalizarCajaDeNombre('ARCILLA GRES'), 'Arcilla gres');
    });

    test('con artículos y preposiciones en medio', () {
      expect(normalizarCajaDeNombre('OXIDO DE COBRE'), 'Oxido de cobre');
      expect(
        normalizarCajaDeNombre('PAPEL DE LIJA PARA MADERA'),
        'Papel de lija para madera',
      );
    });

    test('la Y de unión también baja', () {
      expect(
        normalizarCajaDeNombre('PINTURA Y BARNIZ'),
        'Pintura y barniz',
      );
    });
  });

  group('lo que NO se toca', () {
    test('las medidas y los gramajes, porque llevan un número', () {
      expect(normalizarCajaDeNombre('ARCILLA GRES 25K'), 'Arcilla gres 25K');
      expect(
        normalizarCajaDeNombre('OXIDO DE COBRE 250G'),
        'Oxido de cobre 250G',
      );
    });

    test('un código de artículo', () {
      expect(normalizarCajaDeNombre('PINCEL CHINO N6'), 'Pincel chino N6');
    });

    test('un error del OCR con letra dentro del número se conserva', () {
      // `10.20O` con una letra O: el usuario tiene que VERLO para
      // corregirlo, así que no se disimula.
      expect(
        normalizarCajaDeNombre('CAOLIN BLANCO 10.20O'),
        'Caolin blanco 10.20O',
      );
    });

    test('las siglas de material', () {
      expect(normalizarCajaDeNombre('TUBO PVC 20MM'), 'Tubo PVC 20MM');
      expect(normalizarCajaDeNombre('PLANCHA MDF'), 'Plancha MDF');
      expect(normalizarCajaDeNombre('GOMA EVA ROJA'), 'Goma EVA roja');
    });

    test('una sigla con puntos', () {
      expect(
        normalizarCajaDeNombre('CERAMICAS DEL SUR S.A.'),
        'Ceramicas del sur S.A.',
      );
    });

    test('NO se inventa ninguna tilde que el texto no traía', () {
      // Es la regla dura: el reconocimiento pierde las tildes de las
      // mayúsculas y aquí no hay ningún diccionario que las devuelva.
      final salida = normalizarCajaDeNombre('OXIDO DE ESTANO CERAMICO');
      expect(salida, 'Oxido de estano ceramico');
      expect(salida, isNot(contains('Ó')));
      expect(salida, isNot(contains('ó')));
      expect(salida, isNot(contains('á')));
    });
  });

  group('las formas sociales del proveedor', () {
    test('LTDA queda Ltda, no ltda', () {
      expect(
        normalizarCajaDeNombre('CERAMICAS DEL SUR LTDA'),
        'Ceramicas del sur Ltda',
      );
    });

    test('SPA queda SpA, que es como se escribe en Chile', () {
      expect(
        normalizarCajaDeNombre('INSUMOS AUSTRALES SPA'),
        'Insumos australes SpA',
      );
    });

    test('EIRL se queda entera', () {
      expect(
        normalizarCajaDeNombre('TALLER LOS ROBLES EIRL'),
        'Taller los robles EIRL',
      );
    });
  });

  group('es idempotente, y por eso vale para los dos caminos', () {
    test('un nombre que ya trae minúsculas pasa intacto', () {
      // Lo que devuelve el modelo, o lo que escribió el usuario en la hoja
      // de revisión: esta función no es quien lo reescribe.
      for (final nombre in [
        'Arcilla gres 25 kg',
        'Esmalte transparente',
        'Tubo PVC de 20 mm',
        'Caolín',
      ]) {
        expect(normalizarCajaDeNombre(nombre), nombre);
      }
    });

    test('aplicarla dos veces da lo mismo que aplicarla una', () {
      for (final nombre in [
        'ARCILLA GRES 25K',
        'TUBO PVC 20MM',
        'CERAMICAS DEL SUR LTDA',
        'OXIDO DE COBRE 250G',
      ]) {
        final una = normalizarCajaDeNombre(nombre);
        expect(normalizarCajaDeNombre(una), una);
      }
    });
  });

  group('casos de borde', () {
    test('la cadena vacía sale vacía y no revienta', () {
      expect(normalizarCajaDeNombre(''), '');
      expect(normalizarCajaDeNombre('   '), '');
    });

    test('los espacios de más se colapsan', () {
      expect(
        normalizarCajaDeNombre('  ARCILLA    GRES  '),
        'Arcilla gres',
      );
    });

    test('un nombre que empieza por un número no gana una mayúscula dentro', () {
      // `25K Arcilla` no es caja de frase, es un título a medias.
      expect(normalizarCajaDeNombre('25K ARCILLA'), '25K arcilla');
    });
  });
}
