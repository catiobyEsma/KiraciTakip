class TenantNote {
  int? id;
  int tenantId;
  DateTime createdAt;
  String text;
  bool pinned;

  TenantNote({
    this.id,
    required this.tenantId,
    required this.createdAt,
    required this.text,
    this.pinned = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenantId': tenantId,
      'createdAt': createdAt.toIso8601String(),
      'text': text,
      'pinned': pinned ? 1 : 0,
    };
  }

  factory TenantNote.fromMap(Map<String, dynamic> map) {
    return TenantNote(
      id: map['id'] as int?,
      tenantId: map['tenantId'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
      text: map['text'] as String? ?? '',
      pinned: (map['pinned'] as num? ?? 0) == 1,
    );
  }

  TenantNote copyWith({
    int? id,
    int? tenantId,
    DateTime? createdAt,
    String? text,
    bool? pinned,
  }) {
    return TenantNote(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      createdAt: createdAt ?? this.createdAt,
      text: text ?? this.text,
      pinned: pinned ?? this.pinned,
    );
  }
}
