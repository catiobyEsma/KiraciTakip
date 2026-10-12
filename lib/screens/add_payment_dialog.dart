import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/tenant.dart';
import '../models/due_payment.dart';
import '../models/payment_record.dart';
import '../utils/currency_utils.dart';

/// "Yeni Ödeme Gir" diyaloğu. Kullanıcı hangi borç satırına (hangi ay/
/// döneme) ödeme yaptığını seçer, tutar ve tarihi girer. İsterse
/// herhangi bir satıra bağlamadan (serbest) da ödeme girebilir; bu
/// durumda ödeme otomatik olarak en eski açık borca uygulanır.
class AddPaymentDialog extends StatefulWidget {
  final Tenant tenant;
  const AddPaymentDialog({super.key, required this.tenant});

  @override
  State<AddPaymentDialog> createState() => _AddPaymentDialogState();
}

class _AddPaymentDialogState extends State<AddPaymentDialog> {
  final _db = DatabaseHelper.instance;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _paidDate = DateTime.now();
  DuePayment? _selectedDue;
  List<DuePayment> _dueList = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final due = await _db.getDuePaymentsForTenant(widget.tenant.id!);
    setState(() {
      _dueList = due;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _paidDate = picked);
  }

  Future<void> _save() async {
    final amount = parseTLAmount(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir tutar giriniz.')),
      );
      return;
    }
    setState(() => _saving = true);
    final record = PaymentRecord(
      tenantId: widget.tenant.id!,
      duePaymentId: _selectedDue?.id,
      paidDate: _paidDate,
      paidAmount: amount,
      note: _noteCtrl.text.trim(),
    );
    await _db.insertPaymentRecord(record);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Yeni Ödeme Gir — ${widget.tenant.fullName}'),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 64).clamp(0.0, 420.0).toDouble(),
        child: _loading
            ? const SizedBox(
                height: 120, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<DuePayment?>(
                      value: _selectedDue,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Hangi Ödemeye Ait (opsiyonel)',
                      ),
                      items: [
                        const DropdownMenuItem<DuePayment?>(
                          value: null,
                          child: Text('Otomatik (en eski açık borca uygula)'),
                        ),
                        ..._dueList.map((d) => DropdownMenuItem<DuePayment?>(
                              value: d,
                              child: Text(
                                  '${d.description} — ${formatTL(d.dueAmount)} (${formatDate(d.dueDate)})'),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedDue = v),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Ödenen Tutar (TL)',
                        hintText: 'Örn: 40.000',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Ödeme Tarihi'),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(formatDate(_paidDate)),
                            const Icon(Icons.calendar_today, size: 16),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(labelText: 'Not (opsiyonel)'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Kaydet'),
        ),
      ],
    );
  }
}
