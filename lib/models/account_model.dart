import 'package:hive/hive.dart';

// Sentinel so copyWith() can distinguish "not provided" from "set to null".
const _sentinel = Object();

enum BankType { bml, islamicBank, other }
enum AccountType { current, savings }

BankType bankTypeFromName(String value) {
  switch (value) {
    case 'bml':
      return BankType.bml;
    case 'islamicBank':
      return BankType.islamicBank;
    default:
      return BankType.other;
  }
}

String bankTypeName(BankType bank) {
  switch (bank) {
    case BankType.bml:
      return 'bml';
    case BankType.islamicBank:
      return 'islamicBank';
    case BankType.other:
      return 'other';
  }
}

AccountType accountTypeFromName(String value) =>
    value == 'savings' ? AccountType.savings : AccountType.current;

String accountTypeName(AccountType type) =>
    type == AccountType.savings ? 'savings' : 'current';

class Account extends HiveObject {
  final String id;
  String name;
  BankType bank;
  AccountType type;
  double openingBalance;
  bool includeInBudget;
  bool archived;
  DateTime createdAt;
  int version;
  DateTime? deletedAt;

  Account({
    required this.id,
    required this.name,
    required this.bank,
    required this.type,
    this.openingBalance = 0,
    bool? includeInBudget,
    this.archived = false,
    DateTime? createdAt,
    this.version = 1,
    this.deletedAt,
  })  : includeInBudget = includeInBudget ?? (type == AccountType.current),
        createdAt = createdAt ?? DateTime.now();

  bool get isSavings => type == AccountType.savings;

  Account copyWith({
    String? name,
    BankType? bank,
    AccountType? type,
    double? openingBalance,
    bool? includeInBudget,
    bool? archived,
    DateTime? createdAt,
    int? version,
    Object? deletedAt = _sentinel,
  }) {
    return Account(
      id: id,
      name: name ?? this.name,
      bank: bank ?? this.bank,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      includeInBudget: includeInBudget ?? this.includeInBudget,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
      version: version ?? this.version,
      deletedAt: identical(deletedAt, _sentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }
}

class AccountAdapter extends TypeAdapter<Account> {
  @override
  final int typeId = 4;

  @override
  Account read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final bank = bankTypeFromName(reader.readString());
    final type = accountTypeFromName(reader.readString());
    final openingBalance = reader.readDouble();
    final includeInBudget = reader.readBool();
    final archived = reader.readBool();
    final createdAt =
        DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final version = reader.readInt();
    final deletedAtMs = reader.readInt();
    final deletedAt = deletedAtMs == 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(deletedAtMs);

    return Account(
      id: id,
      name: name,
      bank: bank,
      type: type,
      openingBalance: openingBalance,
      includeInBudget: includeInBudget,
      archived: archived,
      createdAt: createdAt,
      version: version,
      deletedAt: deletedAt,
    );
  }

  @override
  void write(BinaryWriter writer, Account obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(bankTypeName(obj.bank));
    writer.writeString(accountTypeName(obj.type));
    writer.writeDouble(obj.openingBalance);
    writer.writeBool(obj.includeInBudget);
    writer.writeBool(obj.archived);
    writer.writeInt(obj.createdAt.millisecondsSinceEpoch);
    writer.writeInt(obj.version);
    writer.writeInt(obj.deletedAt?.millisecondsSinceEpoch ?? 0);
  }
}
