import '../../../../core/services/receipt_scan_service.dart';
import '../../domain/entities/receipt_document.dart';
import '../../domain/entities/receipt_reading.dart';
import '../../domain/entities/scanned_line_item.dart';
import '../../domain/repositories/receipt_scan_repository.dart';
import '../datasources/mlkit_text_reader.dart';
import '../datasources/receipt_picker_datasource.dart';
import '../parsers/local_line_item_parser.dart';
import '../parsers/remote_line_item_parser.dart';

/// Implementación del lector sobre ML Kit, `image_picker` y el callable.
///
/// Las tres piezas se inyectan para poder probar el provider y la pantalla
/// sin cámara, sin ML Kit y sin Cloud Functions, que es lo que exige
/// AGENTS.md para los widget tests.
class ReceiptScanRepositoryImpl implements ReceiptScanRepository {
  final ReceiptPickerDatasource _picker;
  final MlkitTextReader _reader;
  final ReceiptScanService _service;

  ReceiptScanRepositoryImpl({
    required final ReceiptPickerDatasource picker,
    required final MlkitTextReader reader,
    required final ReceiptScanService service,
  })  : _picker = picker,
        _reader = reader,
        _service = service;

  @override
  Future<ReceiptDocument?> tomarFoto() => _picker.tomarFoto();

  @override
  Future<ReceiptDocument?> elegirImagen() => _picker.elegirImagen();

  @override
  Future<ReceiptReading> leer(final ReceiptDocument documento) =>
      _reader.leer(documento);

  @override
  LocalParse parseLocal(final ReceiptReading lectura) =>
      parseLineasDeBoleta(lectura);

  @override
  Future<StructuredReceipt> structure({
    required final ReceiptReading lectura,
    required final List<ScannedLineItem> local,
    required final bool esPdf,
  }) =>
      estructurarConElModelo(
        servicio: _service,
        lectura: lectura,
        local: local,
        // El contrato del callable admite 'photo' | 'pdf' y solo lo usa
        // para el registro y para matizar su prompt.
        source: esPdf ? 'pdf' : 'photo',
      );
}
