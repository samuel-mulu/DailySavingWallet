import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/data/wallet/models.dart';

void main() {
  group('WithdrawPreview.calculate', () {
    test('uses the exact one-thirtieth fee rule for 3000 ETB', () {
      final preview = WithdrawPreview.calculate(300000);

      expect(preview.requestedAmountCents, 300000);
      expect(preview.feeCents, 10000);
      expect(preview.netPayoutCents, 290000);
    });

    test('stays consistent for other amounts', () {
      final preview2500 = WithdrawPreview.calculate(250000);
      final preview4500 = WithdrawPreview.calculate(450000);

      expect(preview2500.requestedAmountCents, 250000);
      expect(preview2500.feeCents, 8333);
      expect(preview2500.netPayoutCents, 241667);

      expect(preview4500.requestedAmountCents, 450000);
      expect(preview4500.feeCents, 15000);
      expect(preview4500.netPayoutCents, 435000);
    });
  });
}
