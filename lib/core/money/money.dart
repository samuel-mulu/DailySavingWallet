class MoneyEtb {
  MoneyEtb._();

  // 1 ETB = 100 cents for storage.
  static int parseEtbToCents(String input) {
    final s = input.trim().replaceAll(',', '');
    final m = RegExp(r'^\d+(\.\d{1,2})?$').firstMatch(s);
    if (m == null) throw const FormatException('Invalid amount');

    final parts = s.split('.');
    final whole = int.parse(parts[0]);
    final frac = parts.length == 2 ? parts[1] : '';
    final frac2 = '${frac}00'.substring(0, 2);
    return whole * 100 + int.parse(frac2);
  }

  static String formatCents(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final whole = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(2, '0');
    return 'ETB $sign$whole.$frac';
  }
}
