import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/tenant.dart';
import '../utils/contract_utils.dart';
import '../utils/currency_utils.dart';
import '../utils/withholding_utils.dart';

class TenantFormScreen extends StatefulWidget {
  final Tenant? tenant; 
  const TenantFormScreen({super.key, this.tenant});

  @override
  State<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends State<TenantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseHelper.instance;

  late TextEditingController _nameCtrl;
  late TextEditingController _surnameCtrl;
  late TextEditingController _rentCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _addressCtrl;

  // Depozito
  late TextEditingController _depositCtrl;
  late TextEditingController _depositNoteCtrl;
  DateTime? _depositReceivedDate;
  DateTime? _depositReturnedDate;

  // Stopaj
  bool _withholdingEnabled = false;
  late TextEditingController _withholdingRateCtrl;
  bool _rentIsNet = true;

  // Sözleşme bitiş hatırlatması
  int _reminderDaysBefore = 60;

  DateTime _contractStart = DateTime.now();
  DateTime _contractEnd = DateTime(
      DateTime.now().year + 1, DateTime.now().month, DateTime.now().day);
  int _paymentDay = DateTime.now().day > 28 ? 28 : DateTime.now().day;
  bool _saving = false;

  bool get _isEditing => widget.tenant != null;

  @override
  void initState() {
    super.initState();
    final t = widget.tenant;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _surnameCtrl = TextEditingController(text: t?.surname ?? '');
    _rentCtrl = TextEditingController(
        text: t != null ? formatAmountForInput(t.monthlyRent) : '');
    _phoneCtrl = TextEditingController(text: t?.phone ?? '');
    _notesCtrl = TextEditingController(text: t?.notes ?? '');
    _addressCtrl = TextEditingController(text: t?.propertyAddress ?? '');

    _depositCtrl = TextEditingController(
        text: (t != null && t.depositAmount > 0)
            ? formatAmountForInput(t.depositAmount)
            : '');
    _depositNoteCtrl = TextEditingController(text: t?.depositNote ?? '');
    _depositReceivedDate = t?.depositReceivedDate;
    _depositReturnedDate = t?.depositReturnedDate;

    _withholdingEnabled = t?.withholdingEnabled ?? false;
    _withholdingRateCtrl = TextEditingController(
        text: (t?.withholdingRate ?? 20).toStringAsFixed(0));
    _rentIsNet = t?.rentIsNet ?? true;
    _reminderDaysBefore = t?.reminderDaysBefore ?? 60;

    if (t != null) {
      _contractStart = t.contractStart;
      _contractEnd = t.contractEnd;
      _paymentDay = t.paymentDay;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _rentCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    _addressCtrl.dispose();
    _depositCtrl.dispose();
    _depositNoteCtrl.dispose();
    _withholdingRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _contractStart : _contractEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isStart ? 'Sözleşme Başlangıç Tarihi' : 'Sözleşme Bitiş Tarihi',
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _contractStart = picked;
        } else {
          _contractEnd = picked;
        }
      });
    }
  }

  Future<void> _pickDepositDate({required bool isReceived}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isReceived ? _depositReceivedDate : _depositReturnedDate) ??
          DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: isReceived
          ? 'Depozitonun Alındığı Tarih'
          : 'Depozitonun İade Edildiği Tarih',
    );
    if (picked != null) {
      setState(() {
        if (isReceived) {
          _depositReceivedDate = picked;
        } else {
          _depositReturnedDate = picked;
        }
      });
    }
  }

  double get _withholdingRate =>
      double.tryParse(_withholdingRateCtrl.text.trim().replaceAll(',', '.')) ??
      20;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contractEnd.isBefore(_contractStart)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Bitiş tarihi başlangıç tarihinden önce olamaz.')),
      );
      return;
    }
    setState(() => _saving = true);

    final rent = parseTLAmount(_rentCtrl.text) ?? 0;

    final tenant = Tenant(
      id: widget.tenant?.id,
      name: _nameCtrl.text.trim(),
      surname: _surnameCtrl.text.trim(),
      contractStart: _contractStart,
      contractEnd: _contractEnd,
      monthlyRent: _isEditing ? widget.tenant!.monthlyRent : rent,
      paymentDay: _paymentDay,
      phone: _phoneCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      propertyAddress:
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      depositAmount: parseTLAmount(_depositCtrl.text) ?? 0,
      depositReceivedDate: _depositReceivedDate,
      depositReturnedDate: _depositReturnedDate,
      depositNote: _depositNoteCtrl.text.trim(),
      withholdingEnabled: _withholdingEnabled,
      withholdingRate: _withholdingRate,
      rentIsNet: _rentIsNet,
      reminderDaysBefore: _reminderDaysBefore,
    );

    if (_isEditing) {
      await _db.updateTenant(tenant);
    } else {
      final newId = await _db.insertTenant(tenant);
      // Yeni kiracı için otomatik aylık ödeme takvimi oluştur.
      final duePayments = generateMonthlyDuePayments(
        tenantId: newId,
        periodStart: _contractStart,
        periodEnd: _contractEnd,
        paymentDay: _paymentDay,
        amount: rent,
      );
      for (final d in duePayments) {
        await _db.insertDuePayment(d);
      }
    }

    if (mounted) {
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 480;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Kiracıyı Düzenle' : 'Kiracı Oluştur'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isCompact ? 14 : 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isCompact) ...[
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Ad'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Ad giriniz' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _surnameCtrl,
                      decoration: const InputDecoration(labelText: 'Soyad'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Soyad giriniz'
                          : null,
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(labelText: 'Ad'),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Ad giriniz'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _surnameCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Soyad'),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Soyad giriniz'
                                : null,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Mülk Adresi (opsiyonel)'),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Telefon (opsiyonel)'),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _rentCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Aylık Kira Tutarı (TL)',
                      hintText: 'Örn: 40.000',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Tutar giriniz';
                      if (parseTLAmount(v) == null) {
                        return 'Geçerli bir sayı giriniz';
                      }
                      return null;
                    },
                    enabled:
                        !_isEditing,
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_isEditing)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Kira tutarını değiştirmek isterseniz "Ödemeleri Düzenle" ekranından ilgili satırları güncelleyebilir, sözleşme yenilemesi için "Sözleşme Uzat" işlemini kullanabilirsiniz.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  const SizedBox(height: 16),
                  if (isCompact) ...[
                    _DatePickTile(
                      label: 'Sözleşme Başlangıç',
                      date: _contractStart,
                      onTap: () => _pickDate(isStart: true),
                    ),
                    const SizedBox(height: 12),
                    _DatePickTile(
                      label: 'Sözleşme Bitiş',
                      date: _contractEnd,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _DatePickTile(
                            label: 'Sözleşme Başlangıç',
                            date: _contractStart,
                            onTap: () => _pickDate(isStart: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DatePickTile(
                            label: 'Sözleşme Bitiş',
                            date: _contractEnd,
                            onTap: () => _pickDate(isStart: false),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _paymentDay,
                    decoration: const InputDecoration(
                      labelText: 'Aylık Kontrol Referans Günü',
                      helperText:
                          'Her ay için bir borç satırı bu günden oluşturulur; kiracının bu tarihte ödeyip ödemediği zorunlu değildir, siz ay içinde istediğiniz an ödeme girip durumu kontrol edersiniz.',
                      helperMaxLines: 3,
                    ),
                    items: List.generate(28, (i) => i + 1)
                        .map((d) => DropdownMenuItem(
                            value: d, child: Text('Her ayın $d. günü')))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _paymentDay = v ?? _paymentDay),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _reminderDaysBefore,
                    decoration: const InputDecoration(
                      labelText: 'Sözleşme Bitiş Hatırlatması',
                      helperText:
                          'Sözleşmenin bitmesine bu kadar gün kala ana ekranda uyarı gösterilir. Her kiracı için ayrı ayarlanır.',
                      helperMaxLines: 2,
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 0, child: Text('Hatırlatma gösterme')),
                      DropdownMenuItem(value: 15, child: Text('15 gün kala')),
                      DropdownMenuItem(value: 30, child: Text('30 gün kala')),
                      DropdownMenuItem(value: 45, child: Text('45 gün kala')),
                      DropdownMenuItem(value: 60, child: Text('60 gün kala')),
                      DropdownMenuItem(value: 90, child: Text('90 gün kala')),
                    ],
                    onChanged: (v) => setState(
                        () => _reminderDaysBefore = v ?? _reminderDaysBefore),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Notlar (opsiyonel)'),
                    maxLines: 3,
                  ),

                  // ----------------------------------------------------
                  // DEPOZİTO (kiracı bazlı)
                  // ----------------------------------------------------
                  const SizedBox(height: 22),
                  const _SectionTitle('Depozito'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _depositCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Depozito Tutarı (TL)',
                      hintText: 'Depozito yoksa boş bırakın',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      if (parseTLAmount(v) == null) {
                        return 'Geçerli bir sayı giriniz';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  if (isCompact) ...[
                    _OptionalDateTile(
                      label: 'Alındığı Tarih',
                      date: _depositReceivedDate,
                      onTap: () => _pickDepositDate(isReceived: true),
                      onClear: () =>
                          setState(() => _depositReceivedDate = null),
                    ),
                    const SizedBox(height: 12),
                    _OptionalDateTile(
                      label: 'İade Tarihi',
                      date: _depositReturnedDate,
                      hint: 'İade edilmedi',
                      onTap: () => _pickDepositDate(isReceived: false),
                      onClear: () =>
                          setState(() => _depositReturnedDate = null),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: _OptionalDateTile(
                            label: 'Alındığı Tarih',
                            date: _depositReceivedDate,
                            onTap: () => _pickDepositDate(isReceived: true),
                            onClear: () =>
                                setState(() => _depositReceivedDate = null),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _OptionalDateTile(
                            label: 'İade Tarihi',
                            date: _depositReturnedDate,
                            hint: 'İade edilmedi',
                            onTap: () => _pickDepositDate(isReceived: false),
                            onClear: () =>
                                setState(() => _depositReturnedDate = null),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _depositNoteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Depozito Notu (opsiyonel)',
                      hintText: 'Örn: 2 aylık kira karşılığı, elden alındı',
                    ),
                  ),

                  // ----------------------------------------------------
                  // STOPAJ (kiracı bazlı)
                  // ----------------------------------------------------
                  const SizedBox(height: 22),
                  const _SectionTitle('Stopaj'),
                  SwitchListTile(
                    value: _withholdingEnabled,
                    onChanged: (v) => setState(() => _withholdingEnabled = v),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Bu kiracı için stopaj hesabı yapılsın',
                        style: TextStyle(fontSize: 14)),
                    subtitle: const Text(
                      'İş yeri kiralarında kiracı, kirayı brütten keserek net öder. Açarsanız brüt / stopaj / net kırılımı hesaplanır.',
                      style: TextStyle(fontSize: 11.5),
                    ),
                  ),
                  if (_withholdingEnabled) ...[
                    const SizedBox(height: 8),
                    if (isCompact) ...[
                      TextFormField(
                        controller: _withholdingRateCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Stopaj Oranı (%)',
                          hintText: 'Örn: 20',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<bool>(
                        value: _rentIsNet,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Girilen Kira Tutarı'),
                        items: const [
                          DropdownMenuItem(
                              value: true, child: Text('NET (elime geçen)')),
                          DropdownMenuItem(
                              value: false, child: Text('BRÜT (sözleşmedeki)')),
                        ],
                        onChanged: (v) =>
                            setState(() => _rentIsNet = v ?? true),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _withholdingRateCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Stopaj Oranı (%)',
                                hintText: 'Örn: 20',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<bool>(
                              value: _rentIsNet,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                  labelText: 'Girilen Kira Tutarı'),
                              items: const [
                                DropdownMenuItem(
                                    value: true,
                                    child: Text('NET (elime geçen)')),
                                DropdownMenuItem(
                                    value: false,
                                    child: Text('BRÜT (sözleşmedeki)')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _rentIsNet = v ?? true),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),
                    _withholdingPreview(),
                  ],

                  const SizedBox(height: 18),
                  if (!_isEditing)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1EDEF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18, color: Colors.black54),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Kaydettiğinizde, seçtiğiniz tarih aralığı için aylık ödeme takvimi otomatik oluşturulacaktır. Bu takvimi daha sonra "Ödemeleri Düzenle" ekranından değiştirebilirsiniz.',
                              style: TextStyle(
                                  fontSize: 12.5, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_isEditing
                        ? 'Değişiklikleri Kaydet'
                        : 'Kiracıyı Kaydet'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Girilen kira ve orana göre anlık brüt/stopaj/net önizlemesi.
  Widget _withholdingPreview() {
    final rent = _isEditing
        ? widget.tenant!.monthlyRent
        : (parseTLAmount(_rentCtrl.text) ?? 0);
    if (rent <= 0) {
      return const Text(
          'Aylık kira tutarını girdiğinizde kırılım burada gösterilir.',
          style: TextStyle(fontSize: 11.5, color: Colors.black54));
    }
    final b = calcWithholding(
      amount: rent,
      ratePercent: _withholdingRate,
      amountIsNet: _rentIsNet,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDEF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aylık kırılım',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Brüt kira: ${formatTL(b.gross)}',
              style: const TextStyle(fontSize: 12.5)),
          Text(
              'Stopaj (%${_withholdingRate.toStringAsFixed(_withholdingRate % 1 == 0 ? 0 : 2)}): ${formatTL(b.withheld)}',
              style: const TextStyle(fontSize: 12.5)),
          Text('Net (elinize geçen): ${formatTL(b.net)}',
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        const Expanded(child: Divider(height: 1)),
      ],
    );
  }
}

class _DatePickTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DatePickTile(
      {required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatDate(date)),
            const Icon(Icons.calendar_today, size: 16),
          ],
        ),
      ),
    );
  }
}

/// Boş bırakılabilen (opsiyonel) tarih alanı.
class _OptionalDateTile extends StatelessWidget {
  final String label;
  final DateTime? date;
  final String hint;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _OptionalDateTile({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
    this.hint = 'Seçilmedi',
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date != null ? formatDate(date!) : hint,
              style: TextStyle(color: date != null ? null : Colors.black45),
            ),
            date != null
                ? InkWell(
                    onTap: onClear,
                    child: const Icon(Icons.close, size: 16),
                  )
                : const Icon(Icons.calendar_today, size: 16),
          ],
        ),
      ),
    );
  }
}
