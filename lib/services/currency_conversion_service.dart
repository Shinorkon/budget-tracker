import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';

class CurrencyConversionService {
  static const String _apiKey = 'latest'; // ExchangeRate-API uses 'latest' for free tier
  static const String _apiBase = 'https://api.exchangerate-api.com/v4/latest/';
  static const String _cacheBoxName = 'currency_rates';
  static const String _manualRatesBoxName = 'currency_manual_rates';
  static const String _rateCacheDurationKey = 'cache_timestamp';
  static const int _cacheDurationHours = 12;

  // Singleton
  static final CurrencyConversionService _instance =
      CurrencyConversionService._internal();

  factory CurrencyConversionService() {
    return _instance;
  }

  CurrencyConversionService._internal();

  /// Get automatic exchange rate from API or cache
  /// Returns rates like: { "USD": 1.0, "EUR": 0.92, "INR": 83.5 }
  /// [baseCurrency] is the currency to get rates for (e.g., "MVR")
  Future<Map<String, double>?> getExchangeRates(String baseCurrency) async {
    try {
      // Check cache first
      final box = await Hive.openBox<dynamic>(_cacheBoxName);
      final cacheKey = 'rates_$baseCurrency';
      final timestamp = box.get(_rateCacheDurationKey) as int?;

      if (timestamp != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final ageHours = (now - timestamp) / (1000 * 60 * 60);

        if (ageHours < _cacheDurationHours) {
          final cached = box.get(cacheKey) as Map<dynamic, dynamic>?;
          if (cached != null) {
            return cached.cast<String, double>();
          }
        }
      }

      // Fetch from API
      final response = await http
          .get(Uri.parse('$_apiBase$baseCurrency'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rates = Map<String, double>.from(
          Map<String, dynamic>.from(data['rates'] ?? {})
              .map((k, v) => MapEntry(k, (v as num).toDouble())),
        );

        // Cache the rates
        await box.put(cacheKey, rates);
        await box.put(
          _rateCacheDurationKey,
          DateTime.now().millisecondsSinceEpoch,
        );

        return rates;
      }
      return null;
    } catch (e) {
      print('Error fetching exchange rates: $e');
      return null;
    }
  }

  /// Set a manual exchange rate
  /// [fromCurrency] -> [toCurrency] = [rate]
  /// Example: setManualRate("USD", "MVR", 17.5)
  Future<void> setManualRate(
    String fromCurrency,
    String toCurrency,
    double rate,
  ) async {
    try {
      final box = await Hive.openBox<dynamic>(_manualRatesBoxName);
      final key = '${fromCurrency}_to_$toCurrency';
      await box.put(key, rate);
    } catch (e) {
      print('Error setting manual rate: $e');
    }
  }

  /// Get a manual exchange rate
  Future<double?> getManualRate(String fromCurrency, String toCurrency) async {
    try {
      final box = await Hive.openBox<dynamic>(_manualRatesBoxName);
      final key = '${fromCurrency}_to_$toCurrency';
      return box.get(key) as double?;
    } catch (e) {
      print('Error getting manual rate: $e');
      return null;
    }
  }

  /// Get all manual rates
  Future<Map<String, double>> getAllManualRates() async {
    try {
      final box = await Hive.openBox<dynamic>(_manualRatesBoxName);
      return box.toMap().cast<String, double>();
    } catch (e) {
      print('Error getting all manual rates: $e');
      return {};
    }
  }

  /// Delete a manual rate
  Future<void> deleteManualRate(String fromCurrency, String toCurrency) async {
    try {
      final box = await Hive.openBox<dynamic>(_manualRatesBoxName);
      final key = '${fromCurrency}_to_$toCurrency';
      await box.delete(key);
    } catch (e) {
      print('Error deleting manual rate: $e');
    }
  }

  /// Convert an amount from one currency to another
  /// [useManual] = true to prioritize manual rates over API rates
  Future<double?> convertCurrency(
    double amount,
    String fromCurrency,
    String toCurrency, {
    bool useManual = false,
    String? baseCurrency = 'MVR',
  }) async {
    if (fromCurrency == toCurrency) return amount;

    try {
      // Try manual rate first if useManual is true
      if (useManual) {
        final manualRate = await getManualRate(fromCurrency, toCurrency);
        if (manualRate != null) {
          return amount * manualRate;
        }
      }

      // Try API rates
      if (baseCurrency == null || baseCurrency.isEmpty) {
        baseCurrency = 'MVR';
      }

      // Get rates for the base currency
      final rates = await getExchangeRates(baseCurrency) ?? {};
      if (rates.isEmpty) return null;

      // Calculate conversion
      // If converting from base to target: amount * rates[toCurrency]
      if (fromCurrency == baseCurrency && rates.containsKey(toCurrency)) {
        return amount * rates[toCurrency]!;
      }

      // If converting from source to base: amount / rates[fromCurrency]
      if (toCurrency == baseCurrency && rates.containsKey(fromCurrency)) {
        return amount / rates[fromCurrency]!;
      }

      // If neither source nor target is base currency:
      // Convert source -> base, then base -> target
      if (rates.containsKey(fromCurrency) && rates.containsKey(toCurrency)) {
        final toBase = amount / rates[fromCurrency]!;
        return toBase * rates[toCurrency]!;
      }

      return null;
    } catch (e) {
      print('Error converting currency: $e');
      return null;
    }
  }

  /// Get the exchange rate between two currencies
  /// Returns the multiplication factor to convert from -> to
  /// Example: getExchangeRate("USD", "INR", baseCurrency: "MVR") returns ~83
  Future<double?> getExchangeRate(
    String fromCurrency,
    String toCurrency, {
    String? baseCurrency = 'MVR',
  }) async {
    if (fromCurrency == toCurrency) return 1.0;

    try {
      // Try manual rate first
      final manualRate = await getManualRate(fromCurrency, toCurrency);
      if (manualRate != null) return manualRate;

      // Try API rates
      if (baseCurrency == null || baseCurrency.isEmpty) {
        baseCurrency = 'MVR';
      }

      final rates = await getExchangeRates(baseCurrency) ?? {};
      if (rates.isEmpty) return null;

      if (fromCurrency == baseCurrency && rates.containsKey(toCurrency)) {
        return rates[toCurrency];
      }

      if (toCurrency == baseCurrency && rates.containsKey(fromCurrency)) {
        return 1.0 / rates[fromCurrency]!;
      }

      if (rates.containsKey(fromCurrency) && rates.containsKey(toCurrency)) {
        return rates[toCurrency]! / rates[fromCurrency]!;
      }

      return null;
    } catch (e) {
      print('Error getting exchange rate: $e');
      return null;
    }
  }

  /// Clear the cache (useful for testing or manual refresh)
  Future<void> clearCache() async {
    try {
      final box = await Hive.openBox<dynamic>(_cacheBoxName);
      await box.clear();
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// Format a converted amount for display
  /// Example: "100 USD (~₹8,300 MVR)"
  String formatConvertedAmount(
    double originalAmount,
    String originalCurrency,
    double convertedAmount,
    String convertedCurrency,
  ) {
    final numberfmt = NumberFormat('#,##0.00', 'en_US');
    final original = numberfmt.format(originalAmount);
    final converted = numberfmt.format(convertedAmount);
    return '$original $originalCurrency (~$converted $convertedCurrency)';
  }
}
