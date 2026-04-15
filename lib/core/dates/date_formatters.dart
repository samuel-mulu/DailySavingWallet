import 'package:ethiopian_datetime/ethiopian_datetime.dart';
import 'package:intl/intl.dart';

import '../settings/calendar_mode.dart';

/// East Africa Time (UTC+3) as a [DateTime] with `isUtc: true` whose getters
/// match the civil clock in Ethiopia (no DST). Display-only.
DateTime eatWallClockFromInstant(DateTime instant) {
  return DateTime.fromMillisecondsSinceEpoch(
    instant.toUtc().millisecondsSinceEpoch +
        const Duration(hours: 3).inMilliseconds,
    isUtc: true,
  );
}

/// Clock in Ethiopia (EAT) for [instant], `HH:mm`.
String formatEatTime(DateTime instant) {
  final eat = eatWallClockFromInstant(instant);
  final h = eat.hour.toString().padLeft(2, '0');
  final m = eat.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

/// Civil calendar date in Ethiopia (EAT) for this instant, per [CalendarMode].
String formatInstantDate(
  DateTime instant,
  CalendarMode mode, {
  String locale = 'am',
}) {
  final eat = eatWallClockFromInstant(instant);
  final civilNoon = DateTime.utc(eat.year, eat.month, eat.day, 12);
  if (mode == CalendarMode.ethiopian) {
    final ethDate = civilNoon.convertToEthiopian();
    return ETDateFormat('dd-MMMM-yyyy', locale).format(ethDate);
  }
  return DateFormat('dd MMM yyyy').format(civilNoon);
}

String formatTxDay(String txDay, CalendarMode mode, {String locale = 'am'}) {
  try {
    final parts = txDay.split('-');
    if (parts.length != 3) return txDay;

    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final day = int.parse(parts[2]);

    // API civil day: stable at UTC noon (not device-local noon).
    final gregorianDate = DateTime.utc(year, month, day, 12);

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

/// Formats a **calendar** date for pickers and local UI (uses [date]’s local
/// civil day). For server timestamps use [formatInstantDate] instead.
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

/// Display header for API month key `yyyy-MM` (Gregorian month boundary).
String formatApiMonth(
  String yyyyMm,
  CalendarMode mode, {
  String locale = 'am',
}) {
  try {
    final parts = yyyyMm.split('-');
    if (parts.length != 2) return yyyyMm;
    final y = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final ref = DateTime.utc(y, m, 1, 12);
    if (mode == CalendarMode.ethiopian) {
      final ethDate = ref.convertToEthiopian();
      return ETDateFormat('MMMM yyyy', locale).format(ethDate);
    }
    return DateFormat('MMMM yyyy').format(ref);
  } catch (_) {
    return yyyyMm;
  }
}

String toTxDay(DateTime date) {
  final u = date.toUtc();
  final y = u.year.toString();
  final m = u.month.toString().padLeft(2, '0');
  final d = u.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime parseTxDay(String txDay) {
  final parts = txDay.split('-');
  return DateTime.utc(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
    12,
  );
}
