import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show PdfGoogleFonts;

import '../../../core/money/money.dart';
import '../../../data/customers/customer_model.dart';
import '../../../data/wallet/models.dart';

/// Client-generated balance report: one section per customer, one row per wallet.
Future<Uint8List> buildCustomerBalancesPdf({
  required List<Customer> customers,
  required Map<String, List<CustomerWallet>> walletsByCustomerId,
  required String title,
  required DateTime generatedAt,
  String? filterDescription,
}) async {
  // Noto Sans covers Latin + Ethiopic and common punctuation (e.g. middle dot);
  // default Helvetica cannot render most Unicode and logs warnings.
  final base = await PdfGoogleFonts.notoSansRegular();
  final bold = await PdfGoogleFonts.notoSansBold();
  final italic = await PdfGoogleFonts.notoSansItalic();
  final boldItalic = await PdfGoogleFonts.notoSansBoldItalic();

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(
      base: base,
      bold: bold,
      italic: italic,
      boldItalic: boldItalic,
    ),
  );

  final walletRows = <CustomerWallet>[];
  for (final c in customers) {
    final list = walletsByCustomerId[c.customerId] ?? const <CustomerWallet>[];
    walletRows.addAll(list);
  }

  var totalPositiveCents = 0;
  var totalNegativeCents = 0;
  for (final w in walletRows) {
    if (w.balanceCents > 0) {
      totalPositiveCents += w.balanceCents;
    } else if (w.balanceCents < 0) {
      totalNegativeCents += w.balanceCents;
    }
  }
  final netCents = totalPositiveCents + totalNegativeCents;

  final dateStr =
      '${generatedAt.year}-${generatedAt.month.toString().padLeft(2, '0')}-${generatedAt.day.toString().padLeft(2, '0')} '
      '${generatedAt.hour.toString().padLeft(2, '0')}:${generatedAt.minute.toString().padLeft(2, '0')}';

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      build: (context) => [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Generated: $dateStr',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        if (filterDescription != null && filterDescription.isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            filterDescription,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
          ),
        ],
        pw.SizedBox(height: 16),
        pw.Text(
          'Customers: ${customers.length} · Wallets: ${walletRows.length}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        for (final customer in customers) ...[
          _customerSection(
            context,
            customer,
            walletsByCustomerId[customer.customerId],
          ),
          pw.SizedBox(height: 14),
        ],
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 10),
        pw.Text(
          'Summary (wallet balances)',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Total savings (positive balances): ${MoneyEtb.formatCents(totalPositiveCents)}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          'Total debt (negative balances, sum): ${MoneyEtb.formatCents(totalNegativeCents)}',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.Text(
          'Net total: ${MoneyEtb.formatCents(netCents)}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Based on customers currently shown in the app (search/filter; pagination). '
          'Load more in the list before exporting to include additional pages.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _customerSection(
  pw.Context context,
  Customer customer,
  List<CustomerWallet>? wallets,
) {
  final rows = wallets ?? const <CustomerWallet>[];
  if (rows.isEmpty) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          customer.fullName,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          '${customer.companyName} · ${customer.phone}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 4),
          child: pw.Text(
            'No wallet rows loaded.',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
      ],
    );
  }

  final data = <List<dynamic>>[
    ['Wallet', 'Status', 'Balance', 'Daily target', 'Credit limit'],
  ];
  for (final w in rows) {
    data.add([
      '${w.label}${w.isPrimary ? ' (primary)' : ''}',
      w.status,
      MoneyEtb.formatCents(w.balanceCents),
      MoneyEtb.formatCents(w.dailyTargetCents),
      MoneyEtb.formatCents(w.creditLimitCents),
    ]);
  }

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        customer.fullName,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ),
      pw.Text(
        '${customer.companyName} · ${customer.phone}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800),
      ),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        context: context,
        data: data,
        headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
        cellAlignment: pw.Alignment.centerLeft,
        cellAlignments: {
          2: pw.Alignment.centerRight,
          3: pw.Alignment.centerRight,
          4: pw.Alignment.centerRight,
        },
      ),
    ],
  );
}
