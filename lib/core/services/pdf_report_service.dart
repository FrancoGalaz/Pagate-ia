import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../constants/app_brand.dart';
import '../utils/currency_formatter.dart';
import '../utils/month_labels.dart';
import '../../features/finances/domain/entities/finances_summary_entity.dart';
import '../../features/finances/domain/entities/finances_transaction_entity.dart';
import '../../features/finances/domain/entities/fixed_expense_entity.dart';

/// Genera reportes financieros en PDF con el estilo de la app:
/// encabezado con el mes, resumen (ingresos, gastos, balance), progreso de la
/// meta mensual, tabla de gastos fijos, transacciones y pie con la fecha.
class PdfReportService {
  // ─── Paleta ─────────────────────────────────────────────────────────
  // Los mismos siete valores que `AppPalette` (docs/DISENO-v2.md, "Color").
  // No se importan desde `app_constants.dart` porque `PdfColor` no es
  // `Color` y el paquete `pdf` no depende de Flutter: aquí van los enteros,
  // con el nombre del token al lado para que cuadren de un vistazo.
  //
  // Los cuatro que cambian respecto al informe anterior son los que estaban
  // en la paleta vieja: el verde #10B981 (2,54 sobre blanco), el rojo
  // #EF4444 (3,76), el azul noche #16213E y el gris #6B7280 (4,39 sobre un
  // fondo de app). Todos fallaban AA en pantalla y en papel se leen peor.

  /// `brand`.
  static const PdfColor _brand = PdfColor.fromInt(0xFF006B5F);

  /// `moneyIn`. Era #10B981.
  static const PdfColor _success = PdfColor.fromInt(0xFF0B6A47);

  /// `danger`. Era #EF4444.
  static const PdfColor _error = PdfColor.fromInt(0xFFA32019);

  /// `textPrimary`. Era el azul noche #16213E.
  static const PdfColor _textPrimary = PdfColor.fromInt(0xFF101828);

  /// `textSecondary`. Era #6B7280.
  static const PdfColor _textSecondary = PdfColor.fromInt(0xFF475467);

  /// `sunken`. Era #F3F4F6.
  static const PdfColor _bg = PdfColor.fromInt(0xFFF1F3F5);

  /// `border`. Era #E5E7EB.
  static const PdfColor _border = PdfColor.fromInt(0xFFE4E7EC);

  // ─── Tipografía ─────────────────────────────────────────────────────

  /// Ruta de los dos TTF empaquetados, declarados en `pubspec.yaml` bajo
  /// `assets:` (no bajo `fonts:`: ver el comentario de allí).
  static const String _fuenteRegular = 'assets/fonts/pdf/Manrope-Regular.ttf';
  static const String _fuenteNegrita = 'assets/fonts/pdf/Manrope-Bold.ttf';

  /// Las dos caras, cargadas una sola vez por sesión.
  ///
  /// SUSTITUYE A `PdfGoogleFonts.nunitoRegular()` Y `nunitoBold()`, QUE
  /// DESCARGABAN LA FUENTE DE GOOGLE EN CALIENTE. Sin red, la descarga
  /// lanzaba y el informe no se generaba: justo la función que la pantalla
  /// de bienvenida promete como "Reporte en PDF para tu contador". Y además
  /// era Nunito, no la fuente de la app.
  ///
  /// `rootBundle.load` lee del paquete instalado: no hay red, no hay caché
  /// que caducar y el resultado es byte a byte el mismo en cada teléfono.
  static pw.Font? _regularCache;
  static pw.Font? _negritaCache;

  static Future<pw.Font> _cargarFuente(
    final String ruta,
    final pw.Font? cache,
  ) async {
    if (cache != null) return cache;
    final bytes = await rootBundle.load(ruta);
    return pw.Font.ttf(bytes);
  }

  /// Formatea un monto para el informe.
  ///
  /// Los dígitos salen del formateador único de la app
  /// (`core/utils/currency_formatter.dart`).
  static String _fmt(final double value) =>
      formatCurrency(value.abs(), currency: kFallbackCurrency);

  /// Monto negativo del informe: `−$35.000`, con U+2212 MINUS SIGN.
  ///
  /// Antes usaba el guion ASCII porque la fuente se descargaba de Google
  /// Fonts y no estaba verificado que su subconjunto trajera el signo menos
  /// tipográfico: un glifo ausente habría salido como una caja en el informe
  /// que el usuario le manda a su contador. Ahora la fuente va empaquetada y
  /// lo comprobé en el binario: U+2212 está en su `cmap`. Así el informe usa
  /// el mismo signo que la pantalla.
  static String _fmtNegative(final double value) => '−${_fmt(value)}';

  /// Genera el reporte de un mes. La meta mensual vive en el perfil y los
  /// gastos fijos en su propia colección, por eso llegan por separado.
  static Future<Uint8List> generateReport({
    required FinancesSummaryEntity summary,
    required List<FinancesTransactionEntity> transactions,
    List<FixedExpenseEntity> fixedExpenses = const [],
    double monthlyGoal = 0,
  }) async {
    final fontRegular = _regularCache ??=
        await _cargarFuente(_fuenteRegular, _regularCache);
    final fontBold = _negritaCache ??=
        await _cargarFuente(_fuenteNegrita, _negritaCache);
    final goalProgress = summary.goalProgress(monthlyGoal);

    final doc = pw.Document(
      title: 'Reporte Financiero - ${summary.month}',
      author: kAppName,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          // ─── Encabezado ────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 24),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _brand, width: 3),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      kAppName,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 22,
                        color: _brand,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Reporte financiero',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 14,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  summary.month,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 18,
                    color: _textPrimary,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 28),

          // ─── Resumen ───────────────────────────────────────────────
          _sectionTitle('Resumen del mes', fontBold),
          pw.SizedBox(height: 12),
          _summaryRow(
              'Ingresos', summary.totalIncome, _success, fontRegular, fontBold),
          pw.Divider(color: _border, height: 20),
          _summaryRow(
              'Gastos', summary.totalExpenses, _error, fontRegular, fontBold),
          pw.Divider(color: _border, height: 20),
          _summaryRow(
            'Balance',
            summary.balance,
            summary.balance >= 0 ? _brand : _error,
            fontRegular,
            fontBold,
            isBold: true,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            // El "(s)" de antes aparecía también con un solo movimiento y
            // con cero. Es un informe que el usuario le pasa a su contador.
            summary.transactionCount == 1
                ? '1 movimiento registrado'
                : '${summary.transactionCount} movimientos registrados',
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 10,
              color: _textSecondary,
            ),
          ),

          pw.SizedBox(height: 28),

          // ─── Meta mensual ──────────────────────────────────────────
          if (monthlyGoal > 0) ...[
            _sectionTitle('Meta del mes', fontBold),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: _bg,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Progreso',
                        style: pw.TextStyle(
                          font: fontRegular,
                          fontSize: 12,
                          color: _textSecondary,
                        ),
                      ),
                      pw.Text(
                        '${(goalProgress * 100).toStringAsFixed(0)}%',
                        style: pw.TextStyle(
                          font: fontBold,
                          fontSize: 14,
                          color: _brand,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.LinearProgressIndicator(
                    value: goalProgress,
                    valueColor: _brand,
                    backgroundColor: PdfColors.grey300,
                    minHeight: 10,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Objetivo: ${_fmt(monthlyGoal)}',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 11,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 28),
          ],

          // ─── Gastos fijos ──────────────────────────────────────────
          if (fixedExpenses.isNotEmpty) ...[
            _sectionTitle('Gastos fijos', fontBold),
            pw.SizedBox(height: 12),
            _expensesTable(fixedExpenses, fontRegular, fontBold),
            pw.SizedBox(height: 28),
          ],

          // ─── Transacciones ─────────────────────────────────────────
          if (transactions.isNotEmpty) ...[
            _sectionTitle('Movimientos del mes', fontBold),
            pw.SizedBox(height: 12),
            _transactionsTable(transactions, fontRegular, fontBold),
          ],

        ],

        // EL PIE VA EN `footer:` Y NO AL FINAL DEL CONTENIDO.
        //
        // Antes eran dos `pw.Text` más un `SizedBox(40)` dentro de `build`,
        // así que el pie fluía como un bloque más: con el informe de ejemplo
        // de tres movimientos no cabía en la primera página y abría UNA
        // SEGUNDA PÁGINA CASI EN BLANCO, con dos líneas arriba y el resto
        // vacío. Comprobado renderizando el PDF. En `footer:` se dibuja al
        // pie de cada página y no empuja nada.
        footer: (final context) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _border)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generado el ${_formatDate(DateTime.now())} por $kAppName',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 9,
                  color: _textSecondary,
                ),
              ),
              pw.Text(
                'Página ${context.pageNumber} de ${context.pagesCount}',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 9,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return doc.save();
  }

  /// Comparte el PDF con la hoja de compartir de la plataforma (o descarga
  /// en web).
  static Future<void> share({
    required Uint8List pdfBytes,
    required String month,
  }) async {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Reporte_${month.replaceAll(' ', '_')}.pdf',
    );
  }

  // ─── Helpers privados ─────────────────────────────────────────────

  static pw.Widget _sectionTitle(String title, pw.Font font) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        font: font,
        fontSize: 14,
        color: _brand,
      ),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    double value,
    PdfColor color,
    pw.Font regularFont,
    pw.Font boldFont, {
    bool isBold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: regularFont,
            fontSize: 12,
            color: _textSecondary,
          ),
        ),
        pw.Text(
          _fmt(value),
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 14,
            color: color,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      ],
    );
  }

  static pw.Widget _expensesTable(
    List<FixedExpenseEntity> expenses,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    final total = expenses.fold<double>(0, (s, e) => s + e.amount);
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(4),
        1: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _brand),
          children: [
            _tableCell('Nombre', boldFont, PdfColors.white, isHeader: true),
            _tableCell('Monto', boldFont, PdfColors.white,
                isHeader: true, align: pw.Alignment.centerRight),
          ],
        ),
        ...expenses.map((e) => pw.TableRow(
              children: [
                _tableCell(e.name, regularFont, _textPrimary),
                _tableCell(
                  _fmtNegative(e.amount),
                  boldFont,
                  _error,
                  align: pw.Alignment.centerRight,
                ),
              ],
            )),
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _bg),
          children: [
            _tableCell('Total mensual', boldFont, _textPrimary),
            _tableCell(
              _fmtNegative(total),
              boldFont,
              _error,
              align: pw.Alignment.centerRight,
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _transactionsTable(
    List<FinancesTransactionEntity> transactions,
    pw.Font regularFont,
    pw.Font boldFont,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _brand),
          children: [
            _tableCell('Título', boldFont, PdfColors.white, isHeader: true),
            _tableCell('Categoría', boldFont, PdfColors.white, isHeader: true),
            _tableCell('Fecha', boldFont, PdfColors.white, isHeader: true),
            _tableCell('Monto', boldFont, PdfColors.white,
                isHeader: true, align: pw.Alignment.centerRight),
          ],
        ),
        ...transactions.map((t) {
          final isIncome = t.type == TransactionType.income;
          return pw.TableRow(
            children: [
              _tableCell(t.title, regularFont, _textPrimary),
              _tableCell(t.category, regularFont, _textSecondary),
              _tableCell(
                '${t.date.day}/${t.date.month}/${t.date.year}',
                regularFont,
                _textSecondary,
              ),
              _tableCell(
                isIncome ? _fmt(t.amount) : _fmtNegative(t.amount),
                boldFont,
                isIncome ? _success : _error,
                align: pw.Alignment.centerRight,
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableCell(
    String text,
    pw.Font font,
    PdfColor color, {
    bool isHeader = false,
    pw.Alignment align = pw.Alignment.centerLeft,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 10 : 9,
          color: color,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static String _formatDate(final DateTime date) => formatLongDate(date);
}
