import 'dart:math';
import '../models/receipt_model.dart';

class PriceSearchResult {
  final String canonicalName;
  final List<PriceOccurrence> occurrences;

  const PriceSearchResult({
    required this.canonicalName,
    required this.occurrences,
  });

  double get lowestPrice => occurrences.map((o) => o.unitPrice).reduce(min);
  double get highestPrice => occurrences.map((o) => o.unitPrice).reduce(max);

  String get cheapestStore =>
      occurrences.firstWhere((o) => o.unitPrice == lowestPrice).storeName;
}

class PriceOccurrence {
  final String storeName;
  final double unitPrice;
  final DateTime date;
  final int quantity;

  const PriceOccurrence({
    required this.storeName,
    required this.unitPrice,
    required this.date,
    required this.quantity,
  });
}

class PriceSearchService {
  /// Returns a value between 0.0 (no similarity) and 1.0 (identical).
  static double levenshteinSimilarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final rows = a.length + 1;
    final cols = b.length + 1;
    final d = List.generate(rows, (_) => List.filled(cols, 0));

    for (var i = 0; i < rows; i++) d[i][0] = i;
    for (var j = 0; j < cols; j++) d[0][j] = j;

    for (var i = 1; i < rows; i++) {
      for (var j = 1; j < cols; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }

    final distance = d[a.length][b.length];
    return 1.0 - distance / max(a.length, b.length);
  }

  static bool _matches(String query, String canonicalName) {
    final q = query.toLowerCase().trim();
    final c = canonicalName.toLowerCase();
    if (c.contains(q)) return true;
    return levenshteinSimilarity(q, c) >= 0.55;
  }

  static List<PriceSearchResult> search(
    String query,
    List<ReceiptItemEntry> entries,
  ) {
    if (query.trim().isEmpty) return [];

    final matched = entries.where((e) => _matches(query, e.item.canonicalName));

    // Group by canonical name (lowercase key, preserve original casing)
    final Map<String, List<ReceiptItemEntry>> grouped = {};
    for (final entry in matched) {
      final key = entry.item.canonicalName.toLowerCase();
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    return grouped.entries.map((e) {
      final entries = e.value..sort((a, b) => b.date.compareTo(a.date));
      final canonicalName = entries.first.item.canonicalName;

      final occurrences = entries
          .map((entry) => PriceOccurrence(
                storeName: entry.item.storeName,
                unitPrice: entry.item.unitPrice,
                date: entry.date,
                quantity: entry.item.quantity,
              ))
          .toList();

      return PriceSearchResult(
        canonicalName: canonicalName,
        occurrences: occurrences,
      );
    }).toList()
      ..sort((a, b) => a.canonicalName.compareTo(b.canonicalName));
  }
}
