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
}
