import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:intl/intl.dart';

import '../settings/calendar_mode.dart';

String formatTxDay(String txDay, CalendarMode mode, {String locale = 'am'}) {
  try {
    final parts = txDay.split('-');
    if (parts.length != 3) return txDay;

    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    final gregorianDate = DateTime(year, month, day, 12);

    if (mode == CalendarMode.ethiopian) {
      final ethDate = gregorianDate.convertToEthiopian();
      return ETDateFormat('dd-MMMM-yyyy', locale).format(ethDate);
    } else {
      return DateFormat('dd MMM yyyy').format(gregorianDate);
    }
  } catch (_) {
    return txDay;
  }
}

String formatDateTime(
  DateTime date,
  CalendarMode mode, {
  String locale = 'am',
}) {
  if (mode == CalendarMode.ethiopian) {
    final ethDate = date.convertToEthiopian();
    return ETDateFormat('dd-MMMM-yyyy', locale).format(ethDate);
  } else {
    return DateFormat('dd MMM yyyy').format(date);
  }
}

String toTxDayFromEth(ETDateTime eth) {
  final gregorian = eth.convertToGregorian();
  final y = gregorian.year.toString();
  final m = gregorian.month.toString().padLeft(2, '0');
  final d = gregorian.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String toTxDay(DateTime date) {
  final y = date.year.toString();
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime parseTxDay(String txDay) {
  final parts = txDay.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
    12,
  );
}
