import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;

import '../../../core/money/money.dart';

int _toInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

List<Map<String, dynamic>> _mapList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList(growable: false);
}

Future<pw.Document> _documentWithNotoFonts() async {
  final fallbackItalic = await PdfGoogleFonts.notoSansItalic();
  final fallbackBoldItalic = await PdfGoogleFonts.notoSansBoldItalic();

  // Ethiopic-capable base font to render Amharic/Tigrinya text in PDFs.
  final base = await PdfGoogleFonts.notoSansEthiopicRegular();
  final bold = await PdfGoogleFonts.notoSansEthiopicBold();
  return pw.Document(
    theme: pw.ThemeData.withFont(
      base: base,
      bold: bold,
      italic: fallbackItalic,
      boldItalic: fallbackBoldItalic,
    ),
  );
}

String _companyLine(String companyName) {
  final c = companyName.trim();
  return c.isEmpty ? '—' : c;
}

/// Admin daily collections PDF (by posting day).
Future<Uint8List> buildDailySavingsActivityReportPdf({
  required Map<String, dynamic> data,
  required DateTime generatedAt,
}) async {
  final doc = await _documentWithNotoFonts();
  final activityDay = '${data['activityDay'] ?? ''}';
  final lines = _mapList(data['lines'])
    ..sort((a, b) {
      final n = '${a['customerName']}'.compareTo('${b['customerName']}');
      if (n != 0) return n;
      final d = '${a['coveredTxDay'] ?? ''}'.compareTo('${b['coveredTxDay'] ?? ''}');
      if (d != 0) return d;
      return '${a['walletLabel']}'.compareTo('${b['walletLabel']}');
    });
  final totalCollected = _toInt(
    data['combinedTotalCents'] ?? data['totalCollectedCents'],
  );
  final dailySavingTotal = _toInt(data['dailySavingTotalCents']);
  final depositTotal = _toInt(data['depositTotalCents']);

  final dateStr =
      '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')} '
      '${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Text(
          'Daily collections',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Day: $activityDay · Generated: $dateStr',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Summary',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Customers: ${data['distinctCustomerCount'] ?? 0} · '
          'Wallets: ${data['distinctWalletCount'] ?? 0} · '
          'Payments: ${data['paymentCount'] ?? 0}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          'Total collected (Saving + Deposit): ${MoneyEtb.formatCents(totalCollected)}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          'Saving: ${MoneyEtb.formatCents(dailySavingTotal)} · Deposit: ${MoneyEtb.formatCents(depositTotal)}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Payments (${lines.length})',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (lines.isEmpty)
          pw.Text(
            'Nothing recorded for this day.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          )
        else
          pw.TableHelper.fromTextArray(
            context: context,
            headers: const [
              'Customer',
              'Type',
              'Company',
              'Wallet',
              'Saving day',
              'Amount',
            ],
            data: lines
                .map(
                  (r) => [
                    '${r['customerName'] ?? ''}',
                    r['entryType'] == 'DEPOSIT' ? 'Deposit' : 'Saving',
                    _companyLine('${r['companyName'] ?? ''}'),
                    '${r['walletLabel'] ?? ''}',
                    '${r['coveredTxDay'] ?? ''}'.trim().isEmpty
                        ? '—'
                        : '${r['coveredTxDay']}',
                    MoneyEtb.formatCents(_toInt(r['amountCents'])),
                  ],
                )
                .toList()
              ..add(<String>[
                'TOTAL',
                '',
                '',
                '',
                '',
                MoneyEtb.formatCents(totalCollected),
              ]),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {5: pw.Alignment.centerRight},
          ),
      ],
    ),
  );

  return doc.save();
}

/// Admin report: month total and per-day aggregates.
Future<Uint8List> buildMonthlySavingsReportPdf({
  required Map<String, dynamic> data,
  required String month,
  required DateTime generatedAt,
}) async {
  final doc = await _documentWithNotoFonts();
  final daily = _mapList(data['daily'])
    ..sort((a, b) => '${a['txDay']}'.compareTo('${b['txDay']}'));
  final totalSaved = _toInt(data['combinedTotalCents'] ?? data['totalSavedCents']);
  final dailySavingTotal = _toInt(data['dailySavingTotalCents']);
  final depositTotal = _toInt(data['depositTotalCents']);
  final totalWalletDays = daily.fold<int>(
    0,
    (sum, row) => sum + _toInt(row['savedWalletCount']),
  );

  final dateStr =
      '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')} '
      '${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Text(
          'Monthly overview',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Month: $month · Generated: $dateStr',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Total (Saving + Deposit): ${MoneyEtb.formatCents(totalSaved)}',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Saving: ${MoneyEtb.formatCents(dailySavingTotal)} · Deposit: ${MoneyEtb.formatCents(depositTotal)}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Days with activity: ${daily.length}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 16),
        if (daily.isEmpty)
          pw.Text(
            'No data for this month.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          )
        else
          pw.TableHelper.fromTextArray(
            context: context,
            headers: const [
              'Day',
              'Total (S+D)',
              'Saving',
              'Deposit',
              'Wallets',
            ],
            data: daily
                .map(
                  (r) => [
                    '${r['txDay'] ?? ''}',
                    MoneyEtb.formatCents(
                      _toInt(r['combinedTotalCents'] ?? r['totalSavedCents']),
                    ),
                    MoneyEtb.formatCents(_toInt(r['dailySavingTotalCents'])),
                    MoneyEtb.formatCents(_toInt(r['depositTotalCents'])),
                    '${r['savedWalletCount'] ?? 0}',
                  ],
                )
                .toList()
              ..add(<String>[
                'TOTAL',
                MoneyEtb.formatCents(totalSaved),
                MoneyEtb.formatCents(dailySavingTotal),
                MoneyEtb.formatCents(depositTotal),
                '$totalWalletDays',
              ]),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
          ),
      ],
    ),
  );

  return doc.save();
}
