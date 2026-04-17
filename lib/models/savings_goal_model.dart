import 'package:hive/hive.dart';

const _sentinel = Object();

class SavingsGoal extends HiveObject {
  final String id;
  String accountId;
  String name;
  double targetAmount;
  double monthlyTarget;
  DateTime startMonth;
  DateTime? targetDate;
  int version;
  DateTime? deletedAt;

  SavingsGoal({
    required this.id,
    required this.accountId,
    required this.name,
    required this.targetAmount,
    required this.monthlyTarget,
    required this.startMonth,
    this.targetDate,
    this.version = 1,
    this.deletedAt,
  });

  SavingsGoal copyWith({
    String? accountId,
    String? name,
    double? targetAmount,
    double? monthlyTarget,
    DateTime? startMonth,
    Object? targetDate = _sentinel,
    int? version,
    Object? deletedAt = _sentinel,
  }) {
    return SavingsGoal(
      id: id,
      accountId: accountId ?? this.accountId,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      monthlyTarget: monthlyTarget ?? this.monthlyTarget,
      startMonth: startMonth ?? this.startMonth,
      targetDate: identical(targetDate, _sentinel)
          ? this.targetDate
          : targetDate as DateTime?,
      version: version ?? this.version,
      deletedAt: identical(deletedAt, _sentinel)
          ? this.deletedAt
          : deletedAt as DateTime?,
    );
  }
}

class SavingsGoalAdapter extends TypeAdapter<SavingsGoal> {
  @override
  final int typeId = 5;

  @override
  SavingsGoal read(BinaryReader reader) {
    final id = reader.readString();
    final accountId = reader.readString();
    final name = reader.readString();
    final targetAmount = reader.readDouble();
    final monthlyTarget = reader.readDouble();
    final startMonth =
        DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final targetDateMs = reader.readInt();
    final targetDate = targetDateMs == 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(targetDateMs);
    final version = reader.readInt();
    final deletedAtMs = reader.readInt();
    final deletedAt = deletedAtMs == 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(deletedAtMs);

    return SavingsGoal(
      id: id,
      accountId: accountId,
      name: name,
      targetAmount: targetAmount,
      monthlyTarget: monthlyTarget,
      startMonth: startMonth,
      targetDate: targetDate,
      version: version,
      deletedAt: deletedAt,
    );
  }

  @override
  void write(BinaryWriter writer, SavingsGoal obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.accountId);
    writer.writeString(obj.name);
    writer.writeDouble(obj.targetAmount);
    writer.writeDouble(obj.monthlyTarget);
    writer.writeInt(obj.startMonth.millisecondsSinceEpoch);
    writer.writeInt(obj.targetDate?.millisecondsSinceEpoch ?? 0);
    writer.writeInt(obj.version);
    writer.writeInt(obj.deletedAt?.millisecondsSinceEpoch ?? 0);
  }
}
