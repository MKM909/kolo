import 'package:kolo/domain/models/models.dart';

class TransactionParser {
  TransactionParser._();

  static TransactionDraft? parse(String rawText) {
    final amount = _parseFirstMoney(rawText);
    if (amount == null) return null;

    final source = _inferSource(rawText);
    final type = _inferType(rawText);
    final merchant = _extractMerchant(rawText, type);
    final balance = _parseBalance(rawText);

    return TransactionDraft(
      amountKobo: amount,
      type: type,
      merchantName: merchant,
      source: source,
      rawText: rawText,
      balanceAfterKobo: balance,
      category: _guessCategory(merchant),
      occurredAt: _parseTransactionDate(rawText),
    );
  }

  static int? _parseFirstMoney(String text) {
    final match = RegExp(
      r'(?:NGN|N|₦)\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    return match == null ? null : _toKobo(match.group(1)!);
  }

  static int? _parseBalance(String text) {
    final match = RegExp(
      r'(?:bal(?:ance)?(?: is)?[:\s]+)(?:NGN|N|₦)\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    ).firstMatch(text);
    return match == null ? null : _toKobo(match.group(1)!);
  }

  static int _toKobo(String value) {
    final normalized = value.replaceAll(',', '');
    return (double.parse(normalized) * 100).round();
  }

  static TransactionSource _inferSource(String text) {
    final lower = text.toLowerCase();
    const fintechs = [
      'kuda',
      'opay',
      'palmpay',
      'moniepoint',
      'carbon',
      'fairmoney',
    ];
    return fintechs.any(lower.contains)
        ? TransactionSource.notification
        : TransactionSource.sms;
  }

  static TransactionType _inferType(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('received') ||
        lower.contains('credited') ||
        lower.contains(' credit') ||
        lower.contains(' cr ')) {
      return TransactionType.income;
    }
    return TransactionType.expense;
  }

  static String _extractMerchant(String text, TransactionType type) {
    final patterns = type == TransactionType.income
        ? [
            RegExp(r'from\s+(.+?)(?:\s+for\s+|\.|,|$)', caseSensitive: false),
            RegExp(r'by\s+(.+?)(?:\s+on\s+|\.|,|$)', caseSensitive: false),
            RegExp(
              r'ref[:\s]+(.+?)(?:\.|,|Bal|Balance|$)',
              caseSensitive: false,
            ),
          ]
        : [
            RegExp(
              r'(?:desc|description|narration)[:\s]+(.+?)(?:\s+Bal|Balance|\.|,|$)',
              caseSensitive: false,
            ),
            RegExp(
              r'(?:pos/web\s+)?purchase(?:\s+-|:)\s*(.+?)(?:\.|,|Bal|Balance|$)',
              caseSensitive: false,
            ),
            RegExp(
              r'at\s+(.+?)(?:\s+was\s+successful|\.|,|Bal|Balance|$)',
              caseSensitive: false,
            ),
            RegExp(
              r'to\s+(.+?)(?:\s+successful|\.|,|Bal|Balance|$)',
              caseSensitive: false,
            ),
          ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1)!.trim();
    }

    return type == TransactionType.income ? 'Incoming money' : 'Merchant';
  }

  static String _guessCategory(String merchant) {
    final lower = merchant.toLowerCase();
    if (lower.contains('chicken') ||
        lower.contains('food') ||
        lower.contains('restaurant')) {
      return 'Food & Snacks';
    }
    if (lower.contains('uber') || lower.contains('bolt')) return 'Transport';
    if (lower.contains('mtn') || lower.contains('airtime')) {
      return 'Data & Airtime';
    }
    return 'Miscellaneous';
  }

  static DateTime? _parseTransactionDate(String text) {
    final monthNameMatch = RegExp(
      r'\b(?:date|dt|on)[:\s]+(\d{1,2})[-/\s]([a-z]{3,9})[-/\s](\d{2,4})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (monthNameMatch != null) {
      return _dateFromParts(
        day: monthNameMatch.group(1)!,
        month: monthNameMatch.group(2)!,
        year: monthNameMatch.group(3)!,
      );
    }

    final numericMatch = RegExp(
      r'\b(?:date|dt|on)[:\s]+(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (numericMatch == null) return null;
    return _dateFromParts(
      day: numericMatch.group(1)!,
      month: numericMatch.group(2)!,
      year: numericMatch.group(3)!,
    );
  }

  static DateTime? _dateFromParts({
    required String day,
    required String month,
    required String year,
  }) {
    final parsedDay = int.tryParse(day);
    final parsedMonth = int.tryParse(month) ?? _monthNumber(month);
    var parsedYear = int.tryParse(year);
    if (parsedDay == null || parsedMonth == null || parsedYear == null) {
      return null;
    }
    if (parsedYear < 100) parsedYear += 2000;
    if (parsedMonth < 1 || parsedMonth > 12) return null;
    if (parsedDay < 1 || parsedDay > 31) return null;
    return DateTime(parsedYear, parsedMonth, parsedDay);
  }

  static int? _monthNumber(String value) {
    return switch (value.toLowerCase().substring(0, 3)) {
      'jan' => 1,
      'feb' => 2,
      'mar' => 3,
      'apr' => 4,
      'may' => 5,
      'jun' => 6,
      'jul' => 7,
      'aug' => 8,
      'sep' => 9,
      'oct' => 10,
      'nov' => 11,
      'dec' => 12,
      _ => null,
    };
  }
}
