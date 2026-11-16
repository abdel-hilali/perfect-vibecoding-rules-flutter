import 'dart:math' as math;

import 'package:intl/intl.dart';

/// Money from minor units (cents), for the current locale (F11): "4,50 €" in French, "€4.50" in English. Never
/// string building, never a double from the server: amounts travel as whole minor units.
String formatMoney(int minorUnits, String currency, String locale) {
  final format = NumberFormat.simpleCurrency(locale: locale, name: currency);
  final digits = format.decimalDigits ?? 2;
  return format.format(minorUnits / math.pow(10, digits));
}
