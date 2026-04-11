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
  final base = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final italic = await PdfGoogleFonts.notoSansItalic();
  final boldItalic = await PdfGoogleFonts.notoSansBoldItalic();
  return pw.Document(
    theme: pw.ThemeData.withFont(
      base: base,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
    ),
  );
}

String _companyLine(String companyName) {
  final c = companyName.trim();
  return c.isEmpty ? '—' : c;
}

/// Admin report: one day, saved vs pending wallet rows with names (from API).
Future<Uint8List> buildDailySavingsReportPdf({
  required Map<String, dynamic> data,
  required DateTime generatedAt,
}) async {
  final doc = await _documentWithNotoFonts();
  final txDay = '${data['txDay'] ?? ''}';
  final saved = _mapList(data['savedBreakdown'])
    ..sort((a, b) {
      final n = '${a['customerName']}'.compareTo('${b['customerName']}');
      if (n != 0) return n;
      return '${a['walletLabel']}'.compareTo('${b['walletLabel']}');
    });
  final pending = _mapList(data['pendingBreakdown'])
    ..sort((a, b) {
      final n = '${a['customerName']}'.compareTo('${b['customerName']}');
      if (n != 0) return n;
      return '${a['walletLabel']}'.compareTo('${b['walletLabel']}');
    });

  final dateStr =
      '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')} '
      '${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Text(
          'Daily savings report',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Day: $txDay · Generated: $dateStr',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Summary',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Active customers: ${data['activeCustomers'] ?? 0} · '
          'Active wallets: ${data['activeWallets'] ?? 0} · '
          'Saved wallets: ${data['savedWalletCount'] ?? 0} · '
          'Pending wallets: ${data['pendingWalletCount'] ?? 0}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          'Total saved: ${MoneyEtb.formatCents(_toInt(data['totalSavedCents']))} · '
          'Progress: ${data['progressPct'] ?? 0}%',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Saved today (${saved.length})',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (saved.isEmpty)
          pw.Text(
            'No wallets recorded for this day.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          )
        else
          pw.TableHelper.fromTextArray(
            context: context,
            headers: const ['Customer', 'Company', 'Wallet', 'Amount'],
            data: saved
                .map(
                  (r) => [
                    '${r['customerName'] ?? ''}',
                    _companyLine('${r['companyName'] ?? ''}'),
                    '${r['walletLabel'] ?? ''}',
                    MoneyEtb.formatCents(_toInt(r['amountCents'])),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {3: pw.Alignment.centerRight},
          ),
        pw.SizedBox(height: 16),
        pw.Text(
          'Pending (${pending.length})',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        if (pending.isEmpty)
          pw.Text(
            'All active wallets have a saving recorded for this day.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          )
        else
          pw.TableHelper.fromTextArray(
            context: context,
            headers: const ['Customer', 'Company', 'Wallet', 'Daily target'],
            data: pending
                .map(
                  (r) => [
                    '${r['customerName'] ?? ''}',
                    _companyLine('${r['companyName'] ?? ''}'),
                    '${r['walletLabel'] ?? ''}',
                    MoneyEtb.formatCents(_toInt(r['dailyTargetCents'])),
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {3: pw.Alignment.centerRight},
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

  final dateStr =
      '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')} '
      '${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Text(
          'Monthly savings report',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Month: $month · Generated: $dateStr',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 14),
        pw.Text(
          'Total saved: ${MoneyEtb.formatCents(_toInt(data['totalSavedCents']))}',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Days with activity: ${daily.length}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 16),
        if (daily.isEmpty)
          pw.Text(
            'No daily savings recorded in this month.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          )
        else
          pw.TableHelper.fromTextArray(
            context: context,
            headers: const ['Date', 'Total saved', 'Wallets saved'],
            data: daily
                .map(
                  (r) => [
                    '${r['txDay'] ?? ''}',
                    MoneyEtb.formatCents(_toInt(r['totalSavedCents'])),
                    '${r['savedWalletCount'] ?? 0}',
                  ],
                )
                .toList(),
            headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
          ),
      ],
    ),
  );

  return doc.save();
}
