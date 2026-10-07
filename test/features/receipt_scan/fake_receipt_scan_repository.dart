// Repositorio de lectura falso, compartido por los tests de la feature.
//
// Sin cámara, sin ML Kit y sin Cloud Functions: el test dice qué texto
// "leyó" la boleta y qué contestó el modelo, y comprueba qué llega a la
// pantalla y qué se escribe en el inventario.

import 'package:pagate_ia/features/receipt_scan/data/parsers/local_line_item_parser.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_document.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/receipt_reading.dart';
import 'package:pagate_ia/features/receipt_scan/domain/entities/scanned_line_item.dart';
import 'package:pagate_ia/features/receipt_scan/domain/repositories/receipt_scan_repository.dart';

class FakeReceiptScanRepository implements ReceiptScanRepository {
  FakeReceiptScanRepository({
    this.lectura = ReceiptReading.vacia,
    this.errorDeLectura,
    this.estructurada,
    this.retrasoDelModelo,
  });

  /// Lo que "leyó" ML Kit.
  ReceiptReading lectura;

  /// Si no es nulo, [leer] lo lanza.
  ReceiptScanException? errorDeLectura;

  /// Lo que contesta el modelo. `null` = conserva la lista local sin
  /// degradación, como si no hubiera backend que avisar.
  StructuredReceipt? estructurada;

  /// Para probar que la lista local se publica ANTES de que el modelo
  /// conteste.
  Duration? retrasoDelModelo;

  ReceiptDocument? documentoLeido;
  bool? pdfDeclarado;
  int lecturas = 0;

  @override
  Future<ReceiptDocument?> tomarFoto() async => null;

  @override
  Future<ReceiptDocument?> elegirImagen() async => null;

  @override
  Future<ReceiptReading> leer(final ReceiptDocument documento) async {
    lecturas++;
    documentoLeido = documento;
    final error = errorDeLectura;
    if (error != null) throw error;
    return lectura;
  }

  @override
  LocalParse parseLocal(final ReceiptReading lectura) =>
      parseLineasDeBoleta(lectura);

  @override
  Future<StructuredReceipt> structure({
    required final ReceiptReading lectura,
    required final List<ScannedLineItem> local,
    required final bool esPdf,
  }) async {
    pdfDeclarado = esPdf;
    final retraso = retrasoDelModelo;
    if (retraso != null) await Future<void>.delayed(retraso);
    return estructurada ??
        StructuredReceipt(items: local, degradation: ScanDegradation.ninguna);
  }
}
