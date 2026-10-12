/// "Dekont" - kiracının banka dekontu / makbuz fotoğrafı gibi kanıt
/// belgelerini temsil eder. Dosyalar uygulamanın kendi belgeler klasörüne
/// kopyalanır, böylece cihaz hafızasında kalıcı olarak saklanır.
class Receipt {
  int? id;
  int tenantId;
  String filePath; // Cihazdaki yerel dosya yolu
  DateTime addedDate;
  String description; // Örn: "Mayıs ayı kira dekontu"

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
