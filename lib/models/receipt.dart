
class Receipt {
  int? id;
  int tenantId;
  String filePath; 
  DateTime addedDate;
  String description;

  Receipt({
    this.id,
    required this.tenantId,
    required this.filePath,
    required this.addedDate,
    this.description = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenantId': tenantId,
      'filePath': filePath,
      'addedDate': addedDate.toIso8601String(),
      'description': description,
    };
  }

  factory Receipt.fromMap(Map<String, dynamic> map) {
    return Receipt(
      id: map['id'] as int?,
      tenantId: map['tenantId'] as int,
      filePath: map['filePath'] as String,
      addedDate: DateTime.parse(map['addedDate'] as String),
      description: map['description'] as String? ?? '',
    );
  }
}
