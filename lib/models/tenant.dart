class Tenant {
  int? id;
  String name; // Ad
  String surname; // Soyad
  DateTime contractStart; // Sözleşme / kiracılık başlangıç tarihi
  DateTime contractEnd; // Sözleşme / kiracılık bitiş tarihi
  double monthlyRent; // Aylık kira tutarı (varsayılan, yapılması gereken ödeme üretirken kullanılır)
  int paymentDay; // Ayın kaçında ödeme yapılması gerektiği (1-31)
  String phone; // Telefon (opsiyonel)
  String notes; // Notlar
  String? propertyAddress; // Kiralanan mülkün adresi (opsiyonel)

  // Ekstra kiracı bazlı alanlar: depozito, stopaj, sözleşme hatırlatması
  double depositAmount;
  DateTime? depositReceivedDate;
  DateTime? depositReturnedDate;
  String depositNote;
  bool withholdingEnabled;
  double withholdingRate;
  bool rentIsNet;
  int reminderDaysBefore;

  Tenant({
    this.id,
    required this.name,
    required this.surname,
    required this.contractStart,
    required this.contractEnd,
    required this.monthlyRent,
    required this.paymentDay,
    this.phone = '',
    this.notes = '',
    this.propertyAddress,
    this.depositAmount = 0,
    this.depositReceivedDate,
    this.depositReturnedDate,
    this.depositNote = '',
    this.withholdingEnabled = false,
    this.withholdingRate = 20,
    this.rentIsNet = true,
    this.reminderDaysBefore = 60,
  });

  String get fullName => '$name $surname';

  // Liste/dropdown'larda "Duygu K." gibi kısaltılmış görünüm için
  String get shortName {
    final trimmedSurname = surname.trim();
    if (trimmedSurname.isEmpty) return name;
    return '$name ${trimmedSurname[0]}.';
  }

  bool get hasDeposit => depositAmount > 0;
  bool get depositReturned => depositReturnedDate != null;

  int daysUntilContractEnd() {
    return contractEnd.difference(DateTime.now()).inDays;
  }

  bool needsContractReminder() {
    if (reminderDaysBefore <= 0) return false;
    final days = daysUntilContractEnd();
    return days >= 0 && days <= reminderDaysBefore;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'contractStart': contractStart.toIso8601String(),
      'contractEnd': contractEnd.toIso8601String(),
      'monthlyRent': monthlyRent,
      'paymentDay': paymentDay,
      'phone': phone,
      'notes': notes,
      'propertyAddress': propertyAddress,
      'depositAmount': depositAmount,
      'depositReceivedDate': depositReceivedDate?.toIso8601String(),
      'depositReturnedDate': depositReturnedDate?.toIso8601String(),
      'depositNote': depositNote,
      'withholdingEnabled': withholdingEnabled ? 1 : 0,
      'withholdingRate': withholdingRate,
      'rentIsNet': rentIsNet ? 1 : 0,
      'reminderDaysBefore': reminderDaysBefore,
    };
  }

  factory Tenant.fromMap(Map<String, dynamic> map) {
    final depositReceived = map['depositReceivedDate'] as String?;
    final depositReturned = map['depositReturnedDate'] as String?;

    return Tenant(
      id: map['id'] as int?,
      name: map['name'] as String,
      surname: map['surname'] as String,
      contractStart: DateTime.parse(map['contractStart'] as String),
      contractEnd: DateTime.parse(map['contractEnd'] as String),
      monthlyRent: (map['monthlyRent'] as num).toDouble(),
      paymentDay: map['paymentDay'] as int,
      phone: map['phone'] as String? ?? '',
      notes: map['notes'] as String? ?? '',
      propertyAddress: map['propertyAddress'] as String?,
      depositAmount: (map['depositAmount'] as num? ?? 0).toDouble(),
      depositReceivedDate: depositReceived != null ? DateTime.parse(depositReceived) : null,
      depositReturnedDate: depositReturned != null ? DateTime.parse(depositReturned) : null,
      depositNote: map['depositNote'] as String? ?? '',
      withholdingEnabled: map['withholdingEnabled'] == true || (map['withholdingEnabled'] as num? ?? 0) == 1,
      withholdingRate: (map['withholdingRate'] as num? ?? 20).toDouble(),
      rentIsNet: map['rentIsNet'] == true || (map['rentIsNet'] as num? ?? 1) == 1,
      reminderDaysBefore: (map['reminderDaysBefore'] as num? ?? 60).toInt(),
    );
  }

  Tenant copyWith({
    int? id,
    String? name,
    String? surname,
    DateTime? contractStart,
    DateTime? contractEnd,
    double? monthlyRent,
    int? paymentDay,
    String? phone,
    String? notes,
    String? propertyAddress,
    double? depositAmount,
    DateTime? depositReceivedDate,
    DateTime? depositReturnedDate,
    bool clearDepositReturnedDate = false,
    String? depositNote,
    bool? withholdingEnabled,
    double? withholdingRate,
    bool? rentIsNet,
    int? reminderDaysBefore,
  }) {
    return Tenant(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      contractStart: contractStart ?? this.contractStart,
      contractEnd: contractEnd ?? this.contractEnd,
      monthlyRent: monthlyRent ?? this.monthlyRent,
      paymentDay: paymentDay ?? this.paymentDay,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      propertyAddress: propertyAddress ?? this.propertyAddress,
      depositAmount: depositAmount ?? this.depositAmount,
      depositReceivedDate: depositReceivedDate ?? this.depositReceivedDate,
      depositReturnedDate: clearDepositReturnedDate ? null : (depositReturnedDate ?? this.depositReturnedDate),
      depositNote: depositNote ?? this.depositNote,
      withholdingEnabled: withholdingEnabled ?? this.withholdingEnabled,
      withholdingRate: withholdingRate ?? this.withholdingRate,
      rentIsNet: rentIsNet ?? this.rentIsNet,
      reminderDaysBefore: reminderDaysBefore ?? this.reminderDaysBefore,
    );
  }
}
