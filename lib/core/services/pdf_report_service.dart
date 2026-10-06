import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../utils/currency_formatter.dart';
import '../utils/month_labels.dart';
import '../../features/finances/domain/entities/finances_summary_entity.dart';
import '../../features/finances/domain/entities/finances_transaction_entity.dart';
import '../../features/finances/domain/entities/fixed_expense_entity.dart';

/// Genera reportes financieros en PDF con el estilo de la app:
/// encabezado con el mes, resumen (ingresos, gastos, balance), progreso de la
/// meta mensual, tabla de gastos fijos, transacciones y pie con la fecha.
class PdfReportService {
  static const PdfColor _brand = PdfColor.fromInt(0xFF006B5F);
  static const PdfColor _success = PdfColor.fromInt(0xFF10B981);
  static const PdfColor _error = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor _textPrimary = PdfColor.fromInt(0xFF16213E);
  static const PdfColor _textSecondary = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _bg = PdfColor.fromInt(0xFFF3F4F6);
  static const PdfColor _border = PdfColor.fromInt(0xFFE5E7EB);

  /// Formatea un monto para el informe.
  ///
  /// Los dígitos salen del formateador único de la app
  /// (`core/utils/currency_formatter.dart`), pero el signo negativo se
  /// escribe con el guion ASCII en vez de con U+2212 como en pantalla: la
  /// fuente del PDF se descarga en tiempo de ejecución desde Google Fonts y
  /// no está verificado que su subconjunto incluya el signo menos
  /// tipográfico; un glifo ausente saldría como una caja en el informe que el
  /// usuario manda a su contador. Queda unificado cuando el PDF cargue
  /// Manrope desde los assets.
  static String _fmt(final double value) =>
      formatCurrency(value.abs(), currency: kFallbackCurrency);

  /// Monto negativo del informe: `-$35.000`.
  static String _fmtNegative(final double value) => '-${_fmt(value)}';

  /// Genera el reporte de un mes. La meta mensual vive en el perfil y los
  /// gastos fijos en su propia colección, por eso llegan por separado.
  static Future<Uint8List> generateReport({
    required FinancesSummaryEntity summary,
    required List<FinancesTransactionEntity> transactions,
    List<FixedExpenseEntity> fixedExpenses = const [],
    double monthlyGoal = 0,
  }) async {
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();
    final goalProgress = summary.goalProgress(monthlyGoal);

    final doc = pw.Document(
      title: 'Reporte Financiero - ${summary.month}',
      author: 'Págate-IA',
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
                      'Págate-IA',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 22,
                        color: _brand,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Reporte Financiero',
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
          _sectionTitle('Resumen del Mes', fontBold),
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
            '${summary.transactionCount} movimiento(s) registrado(s)',
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 10,
              color: _textSecondary,
            ),
          ),

          pw.SizedBox(height: 28),

          // ─── Meta mensual ──────────────────────────────────────────
          if (monthlyGoal > 0) ...[
            _sectionTitle('Meta Mensual', fontBold),
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
            _sectionTitle('Gastos Fijos', fontBold),
            pw.SizedBox(height: 12),
            _expensesTable(fixedExpenses, fontRegular, fontBold),
            pw.SizedBox(height: 28),
          ],

          // ─── Transacciones ─────────────────────────────────────────
          if (transactions.isNotEmpty) ...[
            _sectionTitle('Movimientos del Mes', fontBold),
            pw.SizedBox(height: 12),
            _transactionsTable(transactions, fontRegular, fontBold),
          ],

          // ─── Pie ───────────────────────────────────────────────────
          pw.SizedBox(height: 40),
          pw.Divider(color: _border),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generado el ${_formatDate(DateTime.now())} por Págate-IA',
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 9,
              color: _textSecondary,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Págate-IA — Asistente financiero para independientes',
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 9,
              color: _textSecondary,
            ),
          ),
        ],
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
