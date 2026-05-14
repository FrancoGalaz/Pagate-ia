import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../features/finances/domain/entities/finances_summary_entity.dart';
import '../../features/finances/domain/entities/finances_transaction_entity.dart';
import '../../features/finances/domain/entities/fixed_expense_entity.dart';

/// Generates financial report PDFs.
///
/// Produces a branded report with the app's style:
/// - Header with month name
/// - Summary card (income, expenses, balance)
/// - Monthly goal progress
/// - Fixed expenses table
/// - Recent transactions
/// - Footer with generation date
class PdfReportService {
  static const PdfColor _brand = PdfColor.fromInt(0xFF006B5F);
  static const PdfColor _accent = PdfColor.fromInt(0xFFFF735C);
  static const PdfColor _success = PdfColor.fromInt(0xFF10B981);
  static const PdfColor _error = PdfColor.fromInt(0xFFEF4444);
  static const PdfColor _textPrimary = PdfColor.fromInt(0xFF16213E);
  static const PdfColor _textSecondary = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _surface = PdfColor.fromInt(0xFFFFFFFF);
  static const PdfColor _bg = PdfColor.fromInt(0xFFF3F4F6);
  static const PdfColor _border = PdfColor.fromInt(0xFFE5E7EB);

  /// Formats a number as currency: $1,234,567
  static String _fmt(double value) {
    final negative = value < 0;
    final abs = value.abs();
    final parts = abs.toStringAsFixed(0).split('.');
    final intPart = parts[0];
    final formatted = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) {
        formatted.write('.');
      }
      formatted.write(intPart[i]);
    }
    return '${negative ? '-' : ''}\$$formatted';
  }

  /// Generates a PDF report for a given month's finances.
  static Future<Uint8List> generateReport({
    required FinancesSummaryEntity summary,
    required List<FinancesTransactionEntity> transactions,
  }) async {
    final fontRegular = await PdfGoogleFonts.nunitoRegular();
    final fontBold = await PdfGoogleFonts.nunitoBold();

    final doc = pw.Document(
      title: 'Reporte Financiero - ${summary.month}',
      author: 'Págate-IA',
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) => [
          // ─── Header ────────────────────────────────────────────────
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

          // ─── Summary Section ───────────────────────────────────────
          _sectionTitle('Resumen del Mes', fontBold),
          pw.SizedBox(height: 12),
          _summaryRow('Ingresos', summary.totalIncome, _success, fontRegular, fontBold),
          pw.Divider(color: _border, height: 20),
          _summaryRow('Gastos', summary.totalExpenses, _error, fontRegular, fontBold),
          pw.Divider(color: _border, height: 20),
          _summaryRow(
            'Balance',
            summary.balance,
            summary.balance >= 0 ? _brand : _error,
            fontRegular,
            fontBold,
            isBold: true,
          ),

          pw.SizedBox(height: 28),

          // ─── Monthly Goal ──────────────────────────────────────────
          _sectionTitle('Meta Mensual', fontBold),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: _bg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
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
                      '${(summary.goalProgress * 100).toStringAsFixed(0)}%',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 14,
                        color: _brand,
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  height: 10,
                  decoration: pw.BoxDecoration(
                    color: _border,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  child: pw.ClipRRect(
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                    child: pw.LinearProgressBar(
                      value: summary.goalProgress,
                      color: _brand,
                      backgroundColor: PdfColors.transparent,
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Objetivo: ${_fmt(summary.monthlyGoal)}',
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

          // ─── Fixed Expenses ────────────────────────────────────────
          if (summary.fixedExpenses.isNotEmpty) ...[
            _sectionTitle('Gastos Fijos', fontBold),
            pw.SizedBox(height: 12),
            _expensesTable(summary.fixedExpenses, fontRegular, fontBold),
            pw.SizedBox(height: 28),
          ],

          // ─── Recent Transactions ──────────────────────────────────
          if (transactions.isNotEmpty) ...[
            _sectionTitle('Transacciones Recientes', fontBold),
            pw.SizedBox(height: 12),
            _transactionsTable(transactions, fontRegular, fontBold),
          ],

          // ─── Footer ───────────────────────────────────────────────
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

  /// Shares the PDF using the platform share sheet or downloads on web.
  static Future<void> share({required Uint8List pdfBytes, required String month}) async {
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Reporte_${month.replaceAll(' ', '_')}.pdf',
    );
  }

  // ─── Private Helpers ──────────────────────────────────────────────

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
    return pw.Table(
      border: pw.TableBorder.all(color: _border, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
      },
      children: [
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF006B5F)),
          children: [
            _tableCell('Nombre', boldFont, PdfColors.white, isHeader: true),
            _tableCell('Categoría', boldFont, PdfColors.white, isHeader: true),
            _tableCell('Monto', boldFont, PdfColors.white, isHeader: true, align: pw.Alignment.centerRight),
          ],
        ),
        // Data rows
        ...expenses.map((e) => pw.TableRow(
              children: [
                _tableCell(e.name, regularFont, _textPrimary),
                _tableCell(e.category, regularFont, _textSecondary),
                _tableCell(
                  '-${_fmt(e.amount)}',
                  boldFont,
                  _error,
                  align: pw.Alignment.centerRight,
                ),
              ],
            )),
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
        // Header row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF006B5F)),
          children: [
            _tableCell('Descripción', boldFont, PdfColors.white, isHeader: true),
            _tableCell('Categoría', boldFont, PdfColors.white, isHeader: true),
            _tableCell('Fecha', boldFont, PdfColors.white, isHeader: true),
            _tableCell('Monto', boldFont, PdfColors.white, isHeader: true, align: pw.Alignment.centerRight),
          ],
        ),
        // Data rows
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
                isIncome ? _fmt(t.amount) : '-${_fmt(t.amount)}',
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

  static String _formatDate(DateTime date) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${date.day} de ${months[date.month - 1]} de ${date.year}';
  }
}
