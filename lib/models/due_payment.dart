
class DuePayment {
  int? id;
  int tenantId;
  DateTime dueDate; // Ödemenin yapılması gereken tarih
  double dueAmount; // Ödenmesi gereken tutar
  String description; 

  DuePayment({
    this.id,
    required this.tenantId,
    required this.dueDate,
    required this.dueAmount,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenantId': tenantId,
      'dueDate': dueDate.toIso8601String(),
      'dueAmount': dueAmount,
      'description': description,
    };
  }

  factory DuePayment.fromMap(Map<String, dynamic> map) {
    return DuePayment(
      id: map['id'] as int?,
      tenantId: map['tenantId'] as int,
      dueDate: DateTime.parse(map['dueDate'] as String),
      dueAmount: (map['dueAmount'] as num).toDouble(),
      description: map['description'] as String? ?? '',
    );
  }

  DuePayment copyWith({
    int? id,
    int? tenantId,
    DateTime? dueDate,
    double? dueAmount,
    String? description,
  }) {
    return DuePayment(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      dueDate: dueDate ?? this.dueDate,
      dueAmount: dueAmount ?? this.dueAmount,
      description: description ?? this.description,
    );
  }
}
