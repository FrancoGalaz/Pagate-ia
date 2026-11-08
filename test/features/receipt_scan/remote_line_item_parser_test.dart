// El modelo ordena el texto, y cuando no puede se conserva la lista local.
//
// LO QUE ESTE ARCHIVO PROTEGE es la promesa de que la función no se cae en
// una feria sin señal: cada fallo imaginable del callable tiene aquí un
// test que comprueba que la lista local sigue en pie y que la degradación
// se declara en vez de disimularse.
//
// Sin Firebase: el servicio se sustituye por un doble que hereda de
// `ReceiptScanService` y sobrescribe `structure`.

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/services/receipt_scan_service.dart';
import 'package:pagate_ia/features/receipt_scan/data/parsers/remote_line_item_parser.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_reading.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/scanned_line_item.dart';

class _ServicioFalso extends ReceiptScanService {
  _ServicioFalso({this.respuesta, this.error});

  final ScanReceiptResult? respuesta;
  final Object? error;

  String? textoRecibido;
  String? fuenteRecibida;
  int llamadas = 0;

  @override
  Future<ScanReceiptResult> structure({
    required final String text,
    final String? source,
  }) async {
    llamadas++;
    textoRecibido = text;
    fuenteRecibida = source;
    final e = error;
    if (e != null) throw e;
    return respuesta ?? const ScanReceiptResult(items: []);
  }
}

const String _textoDeBoleta = '''
CERAMICAS DEL SUR LTDA
2 SACOS ARCILLA GRES 25K 18.990
1 KG ESMALTE TRANSPARENTE 12.500
TOTAL 31.490
''';

const ReceiptReading _lectura = ReceiptReading(
  lines: [OcrLine(text: '2 SACOS ARCILLA GRES 25K 18.990')],
  rawText: _textoDeBoleta,
);

final List<ScannedLineItem> _local = [
  const ScannedLineItem(
    name: 'ARCILLA GRES 25K',
    rawQuantity: 2,
    unit: 'sacos',
    unitPrice: 18990,
    ambiguous: true,
  ),
];

ScanReceiptItem _item(
  final String name, {
  final double quantity = 2,
  final double unitPrice = 18990,
  final String unit = 'sacos',
  final String? code,
}) =>
    ScanReceiptItem(
      name: name,
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
      code: code,
    );

void main() {
  group('camino bueno', () {
    test('la lista del modelo reemplaza a la local', () async {
      final servicio = _ServicioFalso(
        respuesta: ScanReceiptResult(
          items: [_item('Arcilla gres 25 kg', code: 'GR-25')],
          supplier: 'Cerámicas del Sur',
          documentNumber: '1234',
          total: 31490,
        ),
      );

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: _local,
        source: 'photo',
      );

      expect(r.degradation, ScanDegradation.ninguna);
      expect(r.items, hasLength(1));
      expect(r.items.single.name, 'Arcilla gres 25 kg');
      expect(r.items.single.code, 'GR-25');
      expect(
        r.items.single.supplier,
        'Cerámicas del Sur',
        reason: 'el proveedor de la boleta va a la ficha de cada artículo',
      );
      expect(r.items.single.included, isTrue);
    });

    test('si el modelo no trae proveedor, se conserva el de la heurística',
        () async {
      // Los dos leen el MISMO texto, así que no es inventar nada: es no
      // perder un dato que ya se tenía. Antes, una respuesta sin
      // `supplier` borraba el proveedor que la cabecera sí decía y dejaba
      // el campo vacío.
      final servicio = _ServicioFalso(
        respuesta: ScanReceiptResult(items: [_item('Arcilla gres 25 kg')]),
      );

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: [
          const ScannedLineItem(
            name: 'Arcilla gres 25K',
            rawQuantity: 2,
            unit: 'sacos',
            unitPrice: 18990,
            supplier: 'Ceramicas del sur Ltda',
          ),
        ],
      );

      expect(r.items.single.supplier, 'Ceramicas del sur Ltda');
    });

    test('el proveedor del servidor manda sobre el de la heurística',
        () async {
      final servicio = _ServicioFalso(
        respuesta: ScanReceiptResult(
          items: [_item('Arcilla gres 25 kg')],
          supplier: 'Cerámicas del Sur Ltda.',
        ),
      );

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: [
          const ScannedLineItem(
            name: 'Arcilla gres 25K',
            rawQuantity: 2,
            unit: 'sacos',
            unitPrice: 18990,
            supplier: 'Ceramicas del sur Ltda',
          ),
        ],
      );

      expect(r.items.single.supplier, 'Cerámicas del Sur Ltda.');
    });

    test('si el modelo contestara en mayúsculas, la caja se normaliza igual',
        () async {
      // El modelo normalmente devuelve el nombre ya bien escrito, pero la
      // lista no puede quedar con dos estilos según qué camino la armó.
      final servicio = _ServicioFalso(
        respuesta: ScanReceiptResult(items: [_item('ARCILLA GRES 25K')]),
      );

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: _local,
      );

      expect(r.items.single.name, 'Arcilla gres 25K');
    });

    test('solo viaja TEXTO, nunca la imagen, y con la fuente declarada',
        () async {
      final servicio = _ServicioFalso(
        respuesta: ScanReceiptResult(items: [_item('Arcilla gres 25 kg')]),
      );

      await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: _local,
        source: 'pdf',
      );

      expect(servicio.textoRecibido, _textoDeBoleta);
      expect(servicio.fuenteRecibida, 'pdf');
    });

    test('la ambigüedad que midió la heurística se conserva', () async {
      // El modelo recibe el texto entero, no línea a línea, así que no
      // puede saber cuántos montos había. La heurística sí lo midió.
      final servicio = _ServicioFalso(
        respuesta: ScanReceiptResult(items: [_item('Arcilla gres 25 kg')]),
      );

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: _local,
      );

      expect(r.items.single.ambiguous, isTrue);
    });
  });

  group('guarda contra alucinación', () {
    test('un nombre que no está en el texto se marca y llega desmarcado',
        () async {
      final servicio = _ServicioFalso(
        respuesta: ScanReceiptResult(items: [_item('Despacho a domicilio')]),
      );

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: _local,
      );

      final item = r.items.single;
      expect(item.notInText, isTrue);
      expect(
        item.included,
        isFalse,
        reason: 'dejarlo marcado violaría "la app propone, el usuario '
            'confirma"',
      );
      expect(
        r.items,
        hasLength(1),
        reason: 'NO se descarta: descartarlo en silencio perdería lecturas '
            'correctas',
      );
    });

    test('una expansión legítima del nombre NO se marca', () async {
      // El texto dice "ARCILLA GRES 25K"; el modelo devuelve "Arcilla gres
      // 25 kg". Dos de las tres palabras largas están en el texto.
      final servicio = _ServicioFalso(
        respuesta: ScanReceiptResult(items: [_item('Arcilla gres 25 kg')]),
      );

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: _local,
      );

      expect(r.items.single.notInText, isFalse);
      expect(r.items.single.included, isTrue);
    });

    test('un nombre sin palabras largas se da por bueno', () async {
      // "Kg" no se puede comprobar por este camino; marcarlo como
      // inventado sería afirmar algo que el código no sabe.
      final servicio = _ServicioFalso(
        respuesta: ScanReceiptResult(items: [_item('Kg')]),
      );

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: _local,
      );

      expect(r.items.single.notInText, isFalse);
    });
  });

  group('la lista local nunca se pierde', () {
    test('cuota agotada: lista local, bandera de cuota y mensaje del servidor',
        () async {
      final servicio = _ServicioFalso(
        error: ReceiptScanServiceException.from(
          'resource-exhausted',
          'Usaste las 40 lecturas de boleta de tu plan.',
        ),
      );

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: _local,
      );

      expect(r.items, same(_local));
      expect(r.degradation, ScanDegradation.sinCuota);
      expect(r.serverMessage, 'Usaste las 40 lecturas de boleta de tu plan.');
    });

    test('correo sin verificar: lista local, sin error ni mensaje', () async {
      final servicio = _ServicioFalso(
        error: ReceiptScanServiceException.from(
          'failed-precondition',
          'Verifica tu correo para leer boletas con el asistente.',
        ),
      );

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: _local,
      );

      expect(r.items, same(_local));
      expect(r.degradation, ScanDegradation.modeloFallo);
    });

    test('sin red: lista local y bandera de fallo', () async {
      final servicio = _ServicioFalso(
        error: ReceiptScanServiceException.from('unavailable', null),
      );

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: _local,
      );

      expect(r.items, same(_local));
      expect(r.degradation, ScanDegradation.modeloFallo);
      expect(
        r.serverMessage,
        isNull,
        reason: 'el respaldo local no se muestra como si lo hubiera dicho el '
            'servidor',
      );
    });

    test('el callable no existe (not-found): lista local', () async {
      // Es el caso real de una app cuyo backend todavía no se desplegó.
      final servicio = _ServicioFalso(
        error: ReceiptScanServiceException.from('not-found', null),
      );

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: _local,
      );

      expect(r.items, same(_local));
      expect(r.degradation, ScanDegradation.modeloFallo);
    });

    test('una excepción inesperada tampoco se escapa', () async {
      final servicio = _ServicioFalso(error: StateError('vaya'));

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: _local,
      );

      expect(r.items, same(_local));
      expect(r.degradation, ScanDegradation.modeloFallo);
    });

    test('el modelo contesta bien y sin artículos: lista local y aviso',
        () async {
      final servicio = _ServicioFalso(
        respuesta: const ScanReceiptResult(items: []),
      );

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: _lectura,
        local: _local,
      );

      expect(r.items, same(_local));
      expect(r.degradation, ScanDegradation.modeloVacio);
    });

    test('con texto vacío no se gasta una llamada', () async {
      final servicio = _ServicioFalso();

      final r = await estructurarConElModelo(
        servicio: servicio,
        lectura: ReceiptReading.vacia,
        local: const [],
      );

      expect(servicio.llamadas, 0);
      expect(r.degradation, ScanDegradation.ninguna);
    });
  });

  test('el tope de 40 se respeta también sobre la lista del modelo', () async {
    final servicio = _ServicioFalso(
      respuesta: ScanReceiptResult(
        items: [for (var i = 0; i < 45; i++) _item('Arcilla gres 25 kg')],
      ),
    );

    final r = await estructurarConElModelo(
      servicio: servicio,
      lectura: _lectura,
      local: _local,
    );

    expect(r.items, hasLength(40));
    expect(r.truncated, isTrue);
  });
}
