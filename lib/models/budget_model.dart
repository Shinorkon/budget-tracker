import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

// ─── Category ─────────────────────────────────────────────────
class Category extends HiveObject {
  final String id;
  final String name;
  final int iconCode;
  final int colorValue;
  double budgetLimit;

  Category({
    required this.id,
    required this.name,
    required IconData icon,
    required Color color,
    this.budgetLimit = 0,
  })  : iconCode = icon.codePoint,
        colorValue = color.toARGB32();

  IconData get icon => IconData(iconCode, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);

  Category copyWith({
    String? name,
    IconData? icon,
    Color? color,
    double? budgetLimit,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      budgetLimit: budgetLimit ?? this.budgetLimit,
    );
  }
}

class CategoryAdapter extends TypeAdapter<Category> {
  @override
  final int typeId = 0;

  @override
  Category read(BinaryReader reader) {
    return Category(
      id: reader.readString(),
      name: reader.readString(),
      icon: IconData(reader.readInt(), fontFamily: 'MaterialIcons'),
      color: Color(reader.readInt()),
      budgetLimit: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, Category obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeInt(obj.iconCode);
    writer.writeInt(obj.colorValue);
    writer.writeDouble(obj.budgetLimit);
  }
}

// ─── Transaction ──────────────────────────────────────────────
enum TransactionType { expense, income }

class Transaction extends HiveObject {
  final String id;
  final String? categoryId;
  final double amount;
  final DateTime date;
  final String note;
  final TransactionType type;
  final String storeName;
  final String imagePath;

  Transaction({
    required this.id,
    this.categoryId,
    required this.amount,
    required this.date,
    this.note = '',
    required this.type,
    this.storeName = '',
    this.imagePath = '',
  });

  String? get storeNameOrNull => storeName.isEmpty ? null : storeName;
  String? get imagePathOrNull => imagePath.isEmpty ? null : imagePath;

  Transaction copyWith({
    String? categoryId,
    double? amount,
    DateTime? date,
    String? note,
    TransactionType? type,
    String? storeName,
    String? imagePath,
  }) {
    return Transaction(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      type: type ?? this.type,
      storeName: storeName ?? this.storeName,
      imagePath: imagePath ?? this.imagePath,
    );
  }
}

class TransactionAdapter extends TypeAdapter<Transaction> {
  @override
  final int typeId = 1;

  @override
  Transaction read(BinaryReader reader) {
    final id = reader.readString();
    final categoryId = reader.readString();
    final amount = reader.readDouble();
    final date = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final note = reader.readString();
    final type =
        reader.readBool() ? TransactionType.income : TransactionType.expense;

    // v2 fields — backward compatible with old data
    String storeName = '';
    String imagePath = '';
    try {
      storeName = reader.readString();
      imagePath = reader.readString();
    } catch (_) {}

    return Transaction(
      id: id,
      categoryId: categoryId,
      amount: amount,
      date: date,
      note: note,
      type: type,
      storeName: storeName,
      imagePath: imagePath,
    );
  }

  @override
  void write(BinaryWriter writer, Transaction obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.categoryId ?? '');
    writer.writeDouble(obj.amount);
    writer.writeInt(obj.date.millisecondsSinceEpoch);
    writer.writeString(obj.note);
    writer.writeBool(obj.type == TransactionType.income);
    // v2 fields
    writer.writeString(obj.storeName);
    writer.writeString(obj.imagePath);
  }
}

// ─── Available icons for category picker ──────────────────────
const List<IconData> availableCategoryIcons = [
  Icons.home_rounded,
  Icons.restaurant_rounded,
  Icons.directions_car_rounded,
  Icons.shopping_bag_rounded,
  Icons.local_hospital_rounded,
  Icons.school_rounded,
  Icons.movie_rounded,
  Icons.flight_rounded,
  Icons.fitness_center_rounded,
  Icons.pets_rounded,
  Icons.wifi_rounded,
  Icons.phone_android_rounded,
  Icons.checkroom_rounded,
  Icons.local_gas_station_rounded,
  Icons.savings_rounded,
  Icons.child_care_rounded,
  Icons.work_rounded,
  Icons.attach_money_rounded,
  Icons.card_giftcard_rounded,
  Icons.sports_esports_rounded,
  Icons.music_note_rounded,
  Icons.coffee_rounded,
  Icons.local_grocery_store_rounded,
  Icons.bolt_rounded,
  Icons.water_drop_rounded,
  Icons.construction_rounded,
  Icons.laptop_rounded,
  Icons.subscriptions_rounded,
  Icons.receipt_long_rounded,
  Icons.account_balance_rounded,
];
