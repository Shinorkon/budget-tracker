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
  /// True if this was parsed via an income/salary pattern rather than an
  /// expense pattern. Drives TransactionType on the resulting Transaction.
  final bool isIncome;
  bool selected;
  String? categoryId;

  ParsedSmsTransaction({
    required this.currency,
    required this.amount,
    required this.merchant,
    required this.date,
    required this.referenceNo,
    required this.smsBody,
    this.isIncome = false,
    this.selected = true,
    this.categoryId,
  });
}

class SmsTransactionService {
  static const _channel = MethodChannel('com.budgy.app/sms');

  // Pref keys
  static const _keySender = 'sms_sender_address';
  static const _keySenders = 'sms_sender_addresses';
  static const _keyPattern = 'sms_tx_pattern';
  static const _keyIncomePattern = 'sms_income_pattern';
  static const _keyIncomeEnabled = 'sms_income_enabled';
  static const _keyAutoListenEnabled = 'sms_auto_listen_enabled';

  // Default BML pattern (groups: date, time, currency, amount, merchant, refNo)
  static const defaultPattern =
      r'Transaction from \d+ on (\d{2}/\d{2}/\d{2}) at (\d{2}:\d{2}:\d{2}) for ([A-Z]+)([\d,.]+) at (.+?) was processed.*?Reference No:(\d+)';
  static const defaultSender = '455';

  // IslamicBank pattern (groups: amount, currency, merchant, date, time, approvalCode)
  // Handles POS PURCHASE, E-COMMERCE TRX, and other transaction types
  static const islamicBankPattern =
      r'Your (?:POS PURCHASE|E-COMMERCE TRX|PURCHASE|ATM WITHDRAWAL) from \S+ for ([\d,.]+) ([A-Z]+) at (.+?), \S+ on (\d{2}\.\d{2}\.\d{2}) (\d{2}:\d{2}) was processed successfully\. Approval Code: (\w+)';

  // ─── Income / Salary patterns ──────────────────────────────
  // IslamicBank salary: "Salary Transfer to your account 9040...1000 for MVR 2225.00 was
  // processed on 24/08/2025 09:34:49. Ref. no. 17549121-54255064"
  // Groups: currency, amount, date(DD/MM/YYYY), time(HH:MM:SS), refNo
  static const islamicBankSalaryPattern =
      r'Salary Transfer to your account \S+ for ([A-Z]+) ([\d,.]+) was processed on (\d{2}/\d{2}/\d{4}) (\d{2}:\d{2}:\d{2})\.\s*Ref\.\s*no\.\s*(\S+)';

  // Generic salary fallback: any message containing "salary" + an amount.
  // Groups: currency, amount. Date falls back to the parse moment.
  static const genericSalaryPattern =
      r'(?i)\bsalary\b[\s\S]*?([A-Z]{3})\s*([\d,.]+)';

  // Built-in vendor patterns keyed by sender name (case-insensitive)
  static const Map<String, String> vendorPatterns = {
    '455': defaultPattern,
    'islamicbank': islamicBankPattern,
  };

  // Built-in income patterns. User-configured pattern is tried first.
  static const List<String> defaultIncomePatterns = [
    islamicBankSalaryPattern,
    genericSalaryPattern,
  ];

  // ─── Settings persistence ──────────────────────────────────

  static Future<String> getSender() async {
    final senders = await getSenders();
    return senders.isNotEmpty ? senders.first : defaultSender;
  }

  static Future<void> setSender(String sender) async {
    await setSenders([sender]);
  }

  static Future<List<String>> getSenders() async {
    final prefs = await SharedPreferences.getInstance();

    final list = prefs.getStringList(_keySenders);
    if (list != null && list.isNotEmpty) {
      return list
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    // Backward compatibility with old single sender setting.
    final legacy = prefs.getString(_keySender)?.trim();
    if (legacy != null && legacy.isNotEmpty) {
      return [legacy];
    }
    return [defaultSender];
  }

  static Future<void> setSenders(List<String> senders) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = senders
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    await prefs.setStringList(_keySenders, normalized);
    await prefs.setString(
      _keySender,
      normalized.isNotEmpty ? normalized.first : defaultSender,
    );
  }

  static Future<bool> getAutoListenEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAutoListenEnabled) ?? true;
  }

  static Future<void> setAutoListenEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoListenEnabled, enabled);
  }

  static Future<String> getPattern() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyPattern) ?? defaultPattern;
  }

  /// Saves the SMS regex pattern after validating it compiles.
  /// Returns true on success, false if the pattern is invalid.
  static Future<bool> setPattern(String pattern) async {
    final trimmed = pattern.trim();
    try {
      RegExp(trimmed, dotAll: true);
    } catch (_) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPattern, trimmed);
    return true;
  }

  /// Optional user-defined salary / income pattern. Empty string means "none
  /// configured — rely on built-in patterns only".
  static Future<String> getIncomePattern() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyIncomePattern) ?? '';
  }

  /// Validates and persists a user-defined income pattern. Pass an empty
  /// string to clear it. Returns false if a non-empty pattern doesn't compile.
  static Future<bool> setIncomePattern(String pattern) async {
    final trimmed = pattern.trim();
    if (trimmed.isNotEmpty) {
      try {
        RegExp(trimmed, dotAll: true);
      } catch (_) {
        return false;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyIncomePattern, trimmed);
    return true;
  }

  static Future<bool> getIncomeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIncomeEnabled) ?? true;
  }

  static Future<void> setIncomeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIncomeEnabled, enabled);
  }

  // ─── Core logic ────────────────────────────────────────────

  /// Build the list of expense regex patterns to try (user custom + built-in vendor patterns).
  static Future<List<RegExp>> _buildPatterns() async {
    final userPattern = await getPattern();
    final patterns = <String>{userPattern};
    for (final p in vendorPatterns.values) {
      patterns.add(p);
    }
    return patterns.map((p) => RegExp(p, dotAll: true)).toList();
  }

  /// Build the list of income regex patterns to try (user custom + built-in
  /// salary patterns). User pattern is evaluated first so it can override.
  static Future<List<RegExp>> _buildIncomePatterns() async {
    final userPattern = (await getIncomePattern()).trim();
    final patterns = <String>{};
    if (userPattern.isNotEmpty) patterns.add(userPattern);
    patterns.addAll(defaultIncomePatterns);
    return patterns.map((p) => RegExp(p, dotAll: true)).toList();
  }

  /// Request SMS permission and read bank transactions (expense + income).
  static Future<List<ParsedSmsTransaction>> fetchBankTransactions() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) return [];

    final senders = await getSenders();
    final patterns = await _buildPatterns();
    final incomeEnabled = await getIncomeEnabled();
    final incomePatterns = incomeEnabled ? await _buildIncomePatterns() : const <RegExp>[];

    final allMessages = <dynamic>[];
    for (final sender in senders) {
      final List<dynamic> messages =
          await _channel.invokeMethod('getSms', {'address': sender});
      allMessages.addAll(messages);
    }

    final parsed = <ParsedSmsTransaction>[];
    final seenRefs = <String>{};
    for (final msg in allMessages) {
      final body = msg['body'] as String? ?? '';
      final sender = (msg['address'] as String? ?? '').toUpperCase();

      // Expense patterns first; if none match, try income patterns.
      var tx = _parseSmsMulti(body, patterns);
      if (tx == null && incomePatterns.isNotEmpty) {
        tx = _parseIncomeMulti(body, incomePatterns);
      }
      if (tx == null) continue;

      final dedupeKey = '$sender|${tx.referenceNo}|${tx.date.toIso8601String()}';
      if (seenRefs.contains(dedupeKey)) continue;
      seenRefs.add(dedupeKey);
      parsed.add(tx);
    }
    return parsed;
  }

  /// Parse a single SMS body using all known patterns (expense + income).
  static Future<ParsedSmsTransaction?> parseBodyWithCurrentPattern(String body) async {
    final patterns = await _buildPatterns();
    final expense = _parseSmsMulti(body, patterns);
    if (expense != null) return expense;

    if (await getIncomeEnabled()) {
      final incomePatterns = await _buildIncomePatterns();
      return _parseIncomeMulti(body, incomePatterns);
    }
    return null;
  }

  /// Whether an incoming SMS sender matches configured sender rule.
  static Future<bool> isConfiguredSender(String incomingAddress) async {
    final configuredSenders = (await getSenders())
      .map((e) => e.trim().toUpperCase())
      .where((e) => e.isNotEmpty)
      .toList();
    if (configuredSenders.isEmpty) return true;

    final incoming = incomingAddress.trim().toUpperCase();
    if (incoming.isEmpty) return false;

    return configuredSenders.any((configured) =>
      incoming == configured ||
      incoming.startsWith(configured) ||
      incoming.endsWith(configured));
  }

  /// Try all known patterns against the body and return the first match.
  static ParsedSmsTransaction? _parseSmsMulti(String body, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final result = _parseSms(body, pattern);
      if (result != null) return result;
    }
    return null;
  }

  /// Try each income pattern in order and return the first match as an income
  /// ParsedSmsTransaction. Order matters: user pattern, then built-in.
  static ParsedSmsTransaction? _parseIncomeMulti(
    String body,
    List<RegExp> patterns,
  ) {
    for (final pattern in patterns) {
      final result = _parseIncome(body, pattern);
      if (result != null) return result;
    }
    return null;
  }

  static ParsedSmsTransaction? _parseIncome(String body, RegExp pattern) {
    final match = pattern.firstMatch(body);
    if (match == null) return null;

    // Known full-salary shape (5 groups): currency, amount, date, time, ref.
    if (pattern.pattern == islamicBankSalaryPattern && match.groupCount >= 5) {
      final currency = match.group(1)!;
      final amount = double.tryParse(match.group(2)!.replaceAll(',', ''));
      final dateStr = match.group(3)!; // DD/MM/YYYY
      final timeStr = match.group(4)!; // HH:MM:SS
      final refNo = match.group(5)!;

      if (amount == null || amount <= 0) return null;
      final dp = dateStr.split('/');
      final tp = timeStr.split(':');
      if (dp.length < 3 || tp.length < 3) return null;

      return ParsedSmsTransaction(
        currency: currency,
        amount: amount,
        merchant: 'Salary',
        date: DateTime(
          int.parse(dp[2]),
          int.parse(dp[1]),
          int.parse(dp[0]),
          int.parse(tp[0]),
          int.parse(tp[1]),
          int.parse(tp[2]),
        ),
        referenceNo: refNo,
        smsBody: body,
        isIncome: true,
      );
    }

    // Generic fallback: just need currency + amount. Date = now, ref = hash
    // of body so dedup still works across replays of the same SMS.
    if (match.groupCount >= 2) {
      final currency = match.group(1)!.toUpperCase();
      final amount = double.tryParse(match.group(2)!.replaceAll(',', ''));
      if (amount == null || amount <= 0) return null;

      return ParsedSmsTransaction(
        currency: currency,
        amount: amount,
        merchant: 'Salary',
        date: DateTime.now(),
        referenceNo: 'SALARY-${body.hashCode.toUnsigned(32).toRadixString(16)}',
        smsBody: body,
        isIncome: true,
      );
    }

    return null;
  }

  static ParsedSmsTransaction? _parseSms(String body, RegExp pattern) {
    final match = pattern.firstMatch(body);
    if (match == null || match.groupCount < 6) return null;

    final patternStr = pattern.pattern;

    // IslamicBank format: amount, currency, merchant, date(DD.MM.YY), time(HH:MM), approvalCode
    if (patternStr == islamicBankPattern) {
      return _parseIslamicBank(match, body);
    }

    // Default BML format: date, time, currency, amount, merchant, refNo
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

  static ParsedSmsTransaction? _parseIslamicBank(RegExpMatch match, String body) {
    final amountStr = match.group(1)!.replaceAll(',', '');
    final currency = match.group(2)!;
    final merchant = match.group(3)!.trim();
    final dateStr = match.group(4)!; // DD.MM.YY
    final timeStr = match.group(5)!; // HH:MM
    final approvalCode = match.group(6)!;

    final dp = dateStr.split('.');
    final tp = timeStr.split(':');
    if (dp.length < 3 || tp.length < 2) return null;

    final date = DateTime(
      2000 + int.parse(dp[2]),
      int.parse(dp[1]),
      int.parse(dp[0]),
      int.parse(tp[0]),
      int.parse(tp[1]),
    );

    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;

    return ParsedSmsTransaction(
      currency: currency,
      amount: amount,
      merchant: merchant,
      date: date,
      referenceNo: approvalCode,
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
      type: parsed.isIncome ? TransactionType.income : TransactionType.expense,
      storeName: parsed.merchant,
      categoryId: parsed.categoryId,
      currency: sourceCurrency,
      exchangeRate: exchangeRate,
    );
  }

  /// Category suggestion for a merchant name. Priority order:
  ///   1. User-defined [VendorRule]s (if supplied)
  ///   2. Built-in keyword fallback
  ///   3. null → caller may fall back to AI (Gemini) or leave uncategorized
  ///
  /// [vendorRules] is optional for backward compatibility with callers that
  /// don't have access to [BudgetProvider]. Pass them whenever possible so
  /// the user's own mapping wins over the built-in keyword list.
  static String? suggestCategory(
    String merchant,
    List<Category> categories, {
    List<VendorRule>? vendorRules,
  }) {
    // 1. User-defined rules win outright.
    if (vendorRules != null) {
      for (final r in vendorRules) {
        if (r.matches(merchant)) return r.categoryId;
      }
    }

    // 2. Built-in keyword fallback. Kept intentionally narrow — any miscategori-
    //    sation here is now user-fixable by adding a VendorRule.
    final m = merchant.toUpperCase();
    final keywords = <String, List<String>>{
      'Food': [
        'RESTAURANT', 'CAFE', 'COFFEE', 'PIZZA', 'BURGER', 'FOOD',
        'BAKERY', 'GRILL', 'DINE', 'BISTRO',
      ],
      'Shopping': [
        'MART', 'AGORA', 'BIZAARA', 'MALL', 'RETAIL', 'MARKET',
      ],
      'Transport': ['FUEL', 'GAS STATION', 'PETROL', 'TAXI', 'UBER'],
      'Entertainment': [
        'MOVIE', 'CINEMA', 'NETFLIX', 'SPOTIFY', 'STEAM',
      ],
      'Bills': [
        'ELECTRIC', 'WATER BILL', 'INTERNET', 'DHIRAAGU', 'OOREDOO',
        'STELCO', 'FENAKA', 'ADOBE',
      ],
      'Rent': ['RENT PAYMENT', 'LEASE PAYMENT'],
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
