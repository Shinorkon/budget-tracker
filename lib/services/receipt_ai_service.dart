import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../models/receipt_model.dart';

const _uuid = Uuid();
const _geminiKey = String.fromEnvironment('GEMINI_KEY');

class ReceiptAiService {
  static GenerativeModel get _model => GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _geminiKey,
      );

  static const _parsePrompt =
      'You are a receipt parser. Extract from this receipt image:\n'
      '- store_name (string, the shop or restaurant name)\n'
      '- date (string, ISO 8601 format YYYY-MM-DD, use today\'s date if not visible)\n'
      '- total_amount (number, the final total paid)\n'
      '- items (array of objects with fields: raw_name, canonical_name, unit_price, quantity)\n\n'
      'For canonical_name: expand abbreviations and produce a clean human-readable product name.\n\n'
      'Return ONLY valid JSON with no markdown fences, no explanation.';

  /// Parses a receipt image using Gemini Vision.
  /// Throws a descriptive [Exception] on failure so callers can show the error.
  static Future<ParsedReceipt> parseReceipt(Uint8List imageBytes) async {
    if (_geminiKey.isEmpty) {
      throw Exception(
          'GEMINI_KEY is not set. Build with --dart-define=GEMINI_KEY=...');
    }

    final content = [
      Content.multi([
        DataPart('image/jpeg', imageBytes),
        TextPart(_parsePrompt),
      ])
    ];

    // First attempt
    String raw;
    try {
      final response = await _model.generateContent(content);
      raw = response.text ?? '';
    } catch (e) {
      throw Exception('Gemini API error: $e');
    }

    // Try to parse; on failure retry once with an explicit re-prompt
    try {
      return _parseJson(raw);
    } catch (_) {
      // Retry
      try {
        final retry = await _model.generateContent([
          Content.multi([
            DataPart('image/jpeg', imageBytes),
            TextPart(
                '$_parsePrompt\n\nPrevious response was not valid JSON. Return ONLY valid JSON.'),
          ])
        ]);
        return _parseJson(retry.text ?? '');
      } catch (e) {
        throw Exception(
            'Could not parse receipt JSON after retry. Raw response: "$raw". Error: $e');
      }
    }
  }

  static ParsedReceipt _parseJson(String raw) {
    var cleaned = raw.trim();
    // Strip markdown fences if present
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```[a-z]*\n?'), '')
          .replaceFirst(RegExp(r'\n?```$'), '');
    }

    if (cleaned.isEmpty) throw FormatException('Empty response from Gemini');

    final Map<String, dynamic> json = jsonDecode(cleaned);

    final storeName = json['store_name'] as String? ?? '';
    final dateStr = json['date'] as String? ?? '';
    final totalAmount = (json['total_amount'] as num?)?.toDouble() ?? 0.0;
    final rawItems = json['items'] as List? ?? [];

    DateTime date;
    try {
      date = dateStr.isNotEmpty ? DateTime.parse(dateStr) : DateTime.now();
    } catch (_) {
      date = DateTime.now();
    }

    final items = rawItems.map((e) {
      final m = e as Map<String, dynamic>;
      return ReceiptItem(
        id: _uuid.v4(),
        receiptId: '',
        rawName: m['raw_name'] as String? ?? '',
        canonicalName: m['canonical_name'] as String? ?? '',
        unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0.0,
        quantity: (m['quantity'] as num?)?.toInt() ?? 1,
        storeName: storeName,
      );
    }).toList();

    return ParsedReceipt(
      storeName: storeName,
      date: date,
      totalAmount: totalAmount,
      items: items,
    );
  }

  /// Suggests a category name. Returns null silently on failure (non-critical).
  static Future<String?> suggestCategory({
    required String storeName,
    required List<String> canonicalNames,
    required List<String> categoryNames,
  }) async {
    if (_geminiKey.isEmpty || categoryNames.isEmpty) return null;

    final prompt =
        'Given the store "$storeName" and these purchased items: ${canonicalNames.join(', ')}, '
        'which single category from this list fits best: ${categoryNames.join(', ')}? '
        'Return ONLY the category name, nothing else.';

    try {
      final response = await _model.generateContent([Content.text(prompt)]);
      final suggestion = response.text?.trim() ?? '';
      return categoryNames.firstWhere(
        (c) => c.toLowerCase() == suggestion.toLowerCase(),
        orElse: () => categoryNames.first,
      );
    } catch (_) {
      return null;
    }
  }
}
