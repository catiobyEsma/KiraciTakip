class ContractChange {
  int? id;
  int tenantId;
  DateTime changedAt;
  DateTime oldEnd;
  DateTime newEnd;
  double oldRent;
  double newRent;
  String note;

  ContractChange({
    this.id,
    required this.tenantId,
    required this.changedAt,
    required this.oldEnd,
    required this.newEnd,
    required this.oldRent,
    required this.newRent,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenantId': tenantId,
      'changedAt': changedAt.toIso8601String(),
      'oldEnd': oldEnd.toIso8601String(),
      'newEnd': newEnd.toIso8601String(),
      'oldRent': oldRent,
      'newRent': newRent,
      'note': note,
    };
  }

  factory ContractChange.fromMap(Map<String, dynamic> map) {
    return ContractChange(
      id: map['id'] as int?,
      tenantId: map['tenantId'] as int,
      changedAt: DateTime.parse(map['changedAt'] as String),
      oldEnd: DateTime.parse(map['oldEnd'] as String),
      newEnd: DateTime.parse(map['newEnd'] as String),
      oldRent: (map['oldRent'] as num).toDouble(),
      newRent: (map['newRent'] as num).toDouble(),
      note: map['note'] as String? ?? '',
    );
  }
}
