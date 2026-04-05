import 'dart:convert';
import 'package:hive/hive.dart';

// ─── ReceiptItem (plain Dart, serialized as JSON inside Receipt) ───────────
class ReceiptItem {
  final String id;
  final String receiptId;
  final String rawName;
  final String canonicalName;
  final double unitPrice;
  final int quantity;
  final String storeName;

  ReceiptItem({
    required this.id,
    required this.receiptId,
    required this.rawName,
    required this.canonicalName,
    required this.unitPrice,
    required this.quantity,
    required this.storeName,
  });

  double get lineTotal => unitPrice * quantity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'receiptId': receiptId,
        'rawName': rawName,
        'canonicalName': canonicalName,
        'unitPrice': unitPrice,
        'quantity': quantity,
        'storeName': storeName,
      };

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        id: json['id'] as String? ?? '',
        receiptId: json['receiptId'] as String? ?? '',
        rawName: json['rawName'] as String? ?? '',
        canonicalName: json['canonicalName'] as String? ?? '',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        storeName: json['storeName'] as String? ?? '',
      );

  ReceiptItem copyWith({
    String? canonicalName,
    double? unitPrice,
    int? quantity,
  }) =>
      ReceiptItem(
        id: id,
        receiptId: receiptId,
        rawName: rawName,
        canonicalName: canonicalName ?? this.canonicalName,
        unitPrice: unitPrice ?? this.unitPrice,
        quantity: quantity ?? this.quantity,
        storeName: storeName,
      );
}

// ─── Receipt (Hive typeId=2, box='receipts_v1', String-keyed) ─────────────
class Receipt extends HiveObject {
  String id;
  String storeName;
  DateTime date;
  double total;
  String categoryId; // '' if none
  String transactionId;
  String imagePath; // '' if none
  String itemsJson; // JSON-encoded List<ReceiptItem>

  Receipt({
    required this.id,
    required this.storeName,
    required this.date,
    required this.total,
    this.categoryId = '',
    required this.transactionId,
    this.imagePath = '',
    required this.itemsJson,
  });

  List<ReceiptItem> get items {
    if (itemsJson.isEmpty) return [];
    final decoded = jsonDecode(itemsJson) as List;
    return decoded.map((e) => ReceiptItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  set items(List<ReceiptItem> value) {
    itemsJson = jsonEncode(value.map((i) => i.toJson()).toList());
  }

  String? get categoryIdOrNull => categoryId.isEmpty ? null : categoryId;
  String? get imagePathOrNull => imagePath.isEmpty ? null : imagePath;
}

class ReceiptAdapter extends TypeAdapter<Receipt> {
  @override
  final int typeId = 2;

  @override
  Receipt read(BinaryReader reader) {
    return Receipt(
      id: reader.readString(),
      storeName: reader.readString(),
      date: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      total: reader.readDouble(),
      categoryId: reader.readString(),
      transactionId: reader.readString(),
      imagePath: reader.readString(),
      itemsJson: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, Receipt obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.storeName);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeDouble(obj.total);
    writer.writeString(obj.categoryId);
    writer.writeString(obj.transactionId);
    writer.writeString(obj.imagePath);
    writer.writeString(obj.itemsJson);
  }
}

// ─── ReceiptItemEntry (item paired with its receipt date for price queries) ─
class ReceiptItemEntry {
  final ReceiptItem item;
  final DateTime date;

  const ReceiptItemEntry({required this.item, required this.date});
}

// ─── ParsedReceipt (transient, returned by AI service) ────────────────────
class ParsedReceipt {
  final String storeName;
  final DateTime date;
  final double totalAmount;
  final List<ReceiptItem> items;

  const ParsedReceipt({
    required this.storeName,
    required this.date,
    required this.totalAmount,
    required this.items,
  });

  factory ParsedReceipt.empty() => ParsedReceipt(
        storeName: '',
        date: DateTime.now(),
        totalAmount: 0,
        items: [],
      );
}
