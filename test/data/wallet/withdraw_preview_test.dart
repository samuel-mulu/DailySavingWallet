import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/wallet/models.dart';

void main() {
  group('WithdrawPreview.calculate', () {
    test('uses the exact one-thirtieth fee rule for 3000 ETB', () {
      final preview = WithdrawPreview.calculate(300000);

      expect(preview.amountCents, 300000);
      expect(preview.feeCents, 10000);
      expect(preview.totalDebitCents, 310000);
    });

    test('stays consistent for other amounts', () {
      final preview2500 = WithdrawPreview.calculate(250000);
      final preview4500 = WithdrawPreview.calculate(450000);

      expect(preview2500.amountCents, 250000);
      expect(preview2500.feeCents, 8333);
      expect(preview2500.totalDebitCents, 258333);

      expect(preview4500.amountCents, 450000);
      expect(preview4500.feeCents, 15000);
      expect(preview4500.totalDebitCents, 465000);
    });
  });
}
