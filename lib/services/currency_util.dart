/// Currency-aware amount tolerance for duplicate detection.
class CurrencyUtil {
  /// Currencies with zero decimal places.
  static const _zeroDecimal = {
    'JPY', 'KRW', 'VND', 'IDR', 'CLP', 'ISK', 'HUF',
  };

  /// Returns the appropriate tolerance for comparing amounts in [currencyCode].
  static double tolerance(String currencyCode) {
    final code = currencyCode.trim().toUpperCase();
    if (_zeroDecimal.contains(code)) return 1.0;
    return 0.01;
  }
}
