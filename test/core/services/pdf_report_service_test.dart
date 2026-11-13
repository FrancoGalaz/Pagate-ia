// PROPÓSITO: que el informe en PDF se pueda generar SIN RED.
//
// Antes cargaba la tipografía con `PdfGoogleFonts.nunitoRegular()`, que la
// descarga de Google Fonts en tiempo de ejecución: en un teléfono sin datos
// la descarga lanzaba y no había informe. Y es justo la función que la
// pantalla de bienvenida promete como "Reporte en PDF para tu contador".
//
// Este test no puede apagar la red del runner, pero sí comprueba lo que la
// hacía necesaria: que las dos caras salen de `rootBundle` (es decir, del
// paquete instalado) y que el documento se arma con ellas. Si alguien
// reintroduce `PdfGoogleFonts`, la carga por bundle desaparece y el test de
// la fuente empaquetada falla.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/services/pdf_report_service.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_summary_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/fixed_expense_entity.dart';

/// Las dos caras empaquetadas, tal como las declara `pubspec.yaml`.
const List<String> _fuentesDelInforme = [
  'assets/fonts/pdf/Manrope-Regular.ttf',
  'assets/fonts/pdf/Manrope-Bold.ttf',
];

FinancesSummaryEntity _resumen() => const FinancesSummaryEntity(
      monthKey: '2026-09',
      totalIncome: 1850000,
      totalExpenses: 940000,
      transactionCount: 2,
    );

List<FinancesTransactionEntity> _movimientos() => [
      FinancesTransactionEntity(
        id: 'a',
        title: 'Venta en la feria de Ñuñoa',
        description: 'Tres tazas y un jarro',
        amount: 1850000,
        type: TransactionType.income,
        category: 'Venta en feria',
        date: DateTime(2026, 9, 12),
      ),
      FinancesTransactionEntity(
        id: 'b',
        title: 'Greda 25 kg',
        description: '',
        amount: 940000,
        type: TransactionType.expense,
        category: 'Insumos y materiales',
        date: DateTime(2026, 9, 3),
      ),
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('la tipografía del informe va empaquetada', () {
    for (final ruta in _fuentesDelInforme) {
      test('$ruta está en el paquete y es un TTF real', () async {
        final bytes = await rootBundle.load(ruta);
        expect(
          bytes.lengthInBytes,
          greaterThan(50000),
          reason: 'una cara completa de Manrope pesa ~96 kB',
        );

        // Cabecera `sfnt` de una fuente TrueType: 0x00010000. Si alguien
        // sustituye el archivo por la fuente variable, esto sigue pasando;
        // lo que no pasaría es el peso del eje, que se comprueba abajo.
        expect(bytes.getUint32(0), 0x00010000);
      });
    }

    test('no son la fuente variable: no traen tabla fvar', () async {
      // La variable `Manrope[wght].ttf` tiene `fvar` y su eje `wght` vale
      // 200 (ExtraLight) por defecto. El paquete `pdf` no interpreta
      // `fvar`/`gvar`, así que embeberla pondría el informe entero en
      // ExtraLight y sin diferencia entre un total y una línea de detalle.
      // Estas dos son instancias estáticas en 400 y 700.
      for (final ruta in _fuentesDelInforme) {
        final bytes = await rootBundle.load(ruta);
        expect(
          _tieneTabla(bytes, 'fvar'),
          isFalse,
          reason: '$ruta no puede ser la fuente variable',
        );
        expect(_tieneTabla(bytes, 'glyf'), isTrue, reason: ruta);
      }
    });
  });

  group('el informe se genera', () {
    test('devuelve un PDF con contenido', () async {
      final bytes = await PdfReportService.generateReport(
        summary: _resumen(),
        transactions: _movimientos(),
        fixedExpenses: [
          const FixedExpenseEntity(
            id: 'f',
            name: 'Arriendo del taller',
            amount: 320000,
          ),
        ],
        monthlyGoal: 2000000,
      );

      // `%PDF` y el marcador de fin de archivo: el documento está completo.
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
      expect(
        String.fromCharCodes(bytes.sublist(bytes.length - 6)),
        contains('EOF'),
      );

      // Con la fuente embebida el archivo pesa varios kB: el paquete `pdf`
      // la recorta a los glifos usados, así que un informe de dos
      // movimientos ronda los 13 kB y no los 96 de la cara completa. Si
      // volviera a depender de la descarga y esta fallara, no habría
      // archivo en absoluto.
      expect(bytes.lengthInBytes, greaterThan(8000));
    });

    test('un mes sin movimientos tampoco rompe', () async {
      final bytes = await PdfReportService.generateReport(
        summary: const FinancesSummaryEntity(
          monthKey: '2026-10',
          totalIncome: 0,
          totalExpenses: 0,
          transactionCount: 0,
        ),
        transactions: const [],
      );
      expect(String.fromCharCodes(bytes.sublist(0, 4)), '%PDF');
    });
  });
}

/// `true` si el directorio de tablas `sfnt` declara [tag].
bool _tieneTabla(final ByteData fuente, final String tag) {
  final total = fuente.getUint16(4);
  for (var i = 0; i < total; i++) {
    final offset = 12 + 16 * i;
    final leido = String.fromCharCodes([
      for (var b = 0; b < 4; b++) fuente.getUint8(offset + b),
    ]);
    if (leido == tag) return true;
  }
  return false;
}
