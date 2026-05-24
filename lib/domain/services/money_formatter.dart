import 'package:intl/intl.dart';

class MoneyFormatter {
  MoneyFormatter._();

  static final NumberFormat _formatter = NumberFormat('#,##0.00', 'en_US');

  static String formatKobo(int kobo) {
    final sign = kobo < 0 ? '-' : '';
    final naira = kobo.abs() / 100;
    return '$sign₦${_formatter.format(naira)}';
  }

  static int? parseNairaToKobo(String input) {
    final normalized = input
        .replaceAll('₦', '')
        .replaceAll(',', '')
        .replaceAll('NGN', '')
        .trim();
    if (normalized.isEmpty) return null;
    final value = double.tryParse(normalized);
    if (value == null) return null;
    return (value * 100).round();
  }
}
