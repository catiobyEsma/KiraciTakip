
class PaymentRecord {
  int? id;
  int tenantId;
  int? duePaymentId;
  DateTime paidDate;
  double paidAmount;
  String note;

  PaymentRecord({
    this.id,
    required this.tenantId,
    this.duePaymentId,
    required this.paidDate,
    required this.paidAmount,
    this.note = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenantId': tenantId,
      'duePaymentId': duePaymentId,
      'paidDate': paidDate.toIso8601String(),
      'paidAmount': paidAmount,
      'note': note,
    };
  }

  factory PaymentRecord.fromMap(Map<String, dynamic> map) {
    return PaymentRecord(
      id: map['id'] as int?,
      tenantId: map['tenantId'] as int,
      duePaymentId: map['duePaymentId'] as int?,
      paidDate: DateTime.parse(map['paidDate'] as String),
      paidAmount: (map['paidAmount'] as num).toDouble(),
      note: map['note'] as String? ?? '',
    );
  }
}
