import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/budget_model.dart';
import 'currency_conversion_service.dart';

class ParsedSmsTransaction {
  final String currency;
  final double amount;
  final String merchant;
  final DateTime date;
  final String referenceNo;
  final String smsBody;
  bool selected;
  String? categoryId;

  ParsedSmsTransaction({
    required this.currency,
    required this.amount,
    required this.merchant,
    required this.date,
    required this.referenceNo,
    required this.smsBody,
    this.selected = true,
    this.categoryId,
  });
}

class SmsTransactionService {
  static const _channel = MethodChannel('com.budgy.app/sms');

  // Pref keys
  static const _keySender = 'sms_sender_address';
  static const _keyPattern = 'sms_tx_pattern';

  // Default BML pattern
  static const defaultPattern =
      r'Transaction from \d+ on (\d{2}/\d{2}/\d{2}) at (\d{2}:\d{2}:\d{2}) for ([A-Z]+)([\d,.]+) at (.+?) was processed.*?Reference No:(\d+)';
  static const defaultSender = '455';

  // ─── Settings persistence ──────────────────────────────────

  static Future<String> getSender() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySender) ?? defaultSender;
  }

  static Future<void> setSender(String sender) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySender, sender.trim());
  }

  static Future<String> getPattern() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPattern) ?? defaultPattern;
  }

  static Future<void> setPattern(String pattern) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPattern, pattern.trim());
  }

  // ─── Core logic ────────────────────────────────────────────

  /// Request SMS permission and read bank transactions.
  static Future<List<ParsedSmsTransaction>> fetchBankTransactions() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) return [];

    final sender = await getSender();
    final patternStr = await getPattern();
    final pattern = RegExp(patternStr, dotAll: true);

    final List<dynamic> messages =
        await _channel.invokeMethod('getSms', {'address': sender});

    final parsed = <ParsedSmsTransaction>[];
    for (final msg in messages) {
      final body = msg['body'] as String? ?? '';
      final tx = _parseSms(body, pattern);
      if (tx != null) parsed.add(tx);
    }
    return parsed;
  }

  static ParsedSmsTransaction? _parseSms(String body, RegExp pattern) {
    final match = pattern.firstMatch(body);
    if (match == null || match.groupCount < 6) return null;

    final dateStr = match.group(1)!;
    final timeStr = match.group(2)!;
    final currency = match.group(3)!;
    final amountStr = match.group(4)!.replaceAll(',', '');
    final merchant = match.group(5)!.trim();
    final refNo = match.group(6)!;

    final dp = dateStr.split('/');
    final tp = timeStr.split(':');
    if (dp.length < 3 || tp.length < 3) return null;

    final date = DateTime(
      2000 + int.parse(dp[2]),
      int.parse(dp[1]),
      int.parse(dp[0]),
      int.parse(tp[0]),
      int.parse(tp[1]),
      int.parse(tp[2]),
    );

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;

    return ParsedSmsTransaction(
      currency: currency,
      amount: amount,
      merchant: merchant,
      date: date,
      referenceNo: refNo,
      smsBody: body,
    );
  }

  /// Filter out transactions already imported into the app.
  static List<ParsedSmsTransaction> filterNew(
    List<ParsedSmsTransaction> parsed,
    List<Transaction> existing,
  ) {
    return parsed.where((p) {
      final alreadyByReference = existing.any((e) =>
          e.note.toUpperCase().contains('REF ${p.referenceNo.toUpperCase()}'));
      if (alreadyByReference) return false;

      return !existing.any((e) =>
          e.amount == p.amount &&
          e.date.year == p.date.year &&
          e.date.month == p.date.month &&
          e.date.day == p.date.day &&
          e.storeName.toUpperCase() == p.merchant.toUpperCase());
    }).toList();
  }

  /// Filter transactions by date range.
  static List<ParsedSmsTransaction> filterByDateRange(
    List<ParsedSmsTransaction> transactions,
    DateTime fromDate,
    DateTime toDate,
  ) {
    // Normalize dates to start and end of day
    final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final to = DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59);

    return transactions
        .where((t) => t.date.isAfter(from) && t.date.isBefore(to))
        .toList();
  }

  /// Convert a parsed SMS transaction to an app Transaction.
  static Future<Transaction> toTransaction(
    ParsedSmsTransaction parsed, {
    required String primaryCurrency,
  }) async {
    final sourceCurrency = parsed.currency.toUpperCase();
    final targetCurrency = primaryCurrency.toUpperCase();

    double amount = parsed.amount;
    double? exchangeRate;

    if (sourceCurrency != targetCurrency) {
      final conversion = CurrencyConversionService();
      final rate = await conversion.getExchangeRate(sourceCurrency, targetCurrency);
      if (rate != null) {
        exchangeRate = rate;
        amount = parsed.amount * rate;
      }
    }

    final note = exchangeRate == null
        ? '$sourceCurrency · Ref ${parsed.referenceNo}'
        : '$sourceCurrency ${parsed.amount.toStringAsFixed(2)} @ ${exchangeRate.toStringAsFixed(4)} · Ref ${parsed.referenceNo}';

    return Transaction(
      id: const Uuid().v4(),
      amount: amount,
      date: parsed.date,
      note: note,
      type: TransactionType.expense,
      storeName: parsed.merchant,
      categoryId: parsed.categoryId,
      currency: sourceCurrency,
      exchangeRate: exchangeRate,
    );
  }

  /// Simple keyword-based category suggestion.
  static String? suggestCategory(
    String merchant,
    List<Category> categories,
  ) {
    final m = merchant.toUpperCase();
    final keywords = <String, List<String>>{
      'Food': [
        'RESTAURANT', 'CAFE', 'COFFEE', 'PIZZA', 'BURGER', 'FOOD',
        'BAKERY', 'SEAVIEW', 'GARDEN', 'KITCHEN', 'GRILL', 'DINE',
        'BISTRO', 'CHINA',
      ],
      'Shopping': [
        'MART', 'STORE', 'SHOP', 'AGORA', 'BIZAARA', 'MALL',
        'RETAIL', 'MARKET',
      ],
      'Transport': ['FUEL', 'GAS', 'PETROL', 'TAXI', 'UBER', 'CAR'],
      'Entertainment': [
        'GAME', 'MOVIE', 'CINEMA', 'NETFLIX', 'SPOTIFY',
        'GRYPHLINE', 'STEAM', 'PLAY',
      ],
      'Bills': [
        'ELECTRIC', 'WATER', 'INTERNET', 'PHONE', 'MOBILE',
        'DHIRAAGU', 'OOREDOO', 'STELCO', 'FENAKA', 'ADOBE',
      ],
      'Rent': ['RENT', 'LEASE', 'NORTH STAR'],
    };

    for (final entry in keywords.entries) {
      if (entry.value.any((kw) => m.contains(kw))) {
        final match = categories
            .where((c) => c.name.toUpperCase() == entry.key.toUpperCase())
            .firstOrNull;
        if (match != null) return match.id;
      }
    }
    return null;
  }
}
