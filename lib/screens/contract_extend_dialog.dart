import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/contract_change.dart';
import '../models/tenant.dart';
import '../utils/contract_utils.dart';
import '../utils/currency_utils.dart';

class ContractExtendDialog extends StatefulWidget {
  final Tenant tenant;
  const ContractExtendDialog({super.key, required this.tenant});

  @override
  State<ContractExtendDialog> createState() => _ContractExtendDialogState();
}

class _ContractExtendDialogState extends State<ContractExtendDialog> {
  final _db = DatabaseHelper.instance;
  late TextEditingController _rentCtrl;
  late TextEditingController _increaseCtrl;
  final _noteCtrl = TextEditingController();

  late DateTime _newEnd;
  bool _generateDues = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.tenant;

    final base = t.contractEnd.isBefore(DateTime.now()) ? DateTime.now() : t.contractEnd;
    _newEnd = DateTime(base.year + 1, base.month, base.day);
    _rentCtrl = TextEditingController(text: formatAmountForInput(t.monthlyRent));
    _increaseCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _increaseCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _applyIncrease() {
    final pct = double.tryParse(_increaseCtrl.text.trim().replaceAll(',', '.'));
    if (pct == null) return;
    final newRent = widget.tenant.monthlyRent * (1 + pct / 100);
    setState(() => _rentCtrl.text = formatAmountForInput(newRent));
  }

  Future<void> _pickNewEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _newEnd,
      firstDate: widget.tenant.contractEnd,
      lastDate: DateTime(2100),
      helpText: 'Yeni Sözleşme Bitiş Tarihi',
    );
    if (picked != null) setState(() => _newEnd = picked);
  }

  Future<void> _save() async {
    final newRent = parseTLAmount(_rentCtrl.text);
    if (newRent == null || newRent <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir kira tutarı giriniz.')),
      );
      return;
    }
    if (!_newEnd.isAfter(widget.tenant.contractEnd)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yeni bitiş tarihi mevcut bitiş tarihinden sonra olmalı.')),
      );
      return;
    }

    setState(() => _saving = true);
    final t = widget.tenant;

    if (_generateDues) {

      final existing = await _db.getDuePaymentsForTenant(t.id!);
      DateTime anchor = t.contractEnd;
      if (existing.isNotEmpty) {
        final lastDue = existing.last.dueDate;
        if (lastDue.isAfter(anchor)) anchor = lastDue;
      }
      final periodStart = anchor.add(const Duration(days: 1));

      final newDues = generateMonthlyDuePayments(
        tenantId: t.id!,
        periodStart: periodStart,
        periodEnd: _newEnd,
        paymentDay: t.paymentDay,
        amount: newRent,
        includeYearInDescription: true,
      );
      for (final d in newDues) {
        await _db.insertDuePayment(d);
      }
    }

    await _db.updateTenant(t.copyWith(contractEnd: _newEnd, monthlyRent: newRent));
    await _db.insertContractChange(ContractChange(
      tenantId: t.id!,
      changedAt: DateTime.now(),
      oldEnd: t.contractEnd,
      newEnd: _newEnd,
      oldRent: t.monthlyRent,
      newRent: newRent,
      note: _noteCtrl.text.trim(),
    ));

    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tenant;
    return AlertDialog(
      title: Text('Sözleşme Uzat — ${t.fullName}'),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 64).clamp(0.0, 460.0).toDouble(),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1EDEF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mevcut bitiş: ${formatDate(t.contractEnd)}',
                        style: const TextStyle(fontSize: 12.5)),
                    Text('Mevcut kira: ${formatTL(t.monthlyRent)}',
                        style: const TextStyle(fontSize: 12.5)),
                    Text(contractRemainingLabel(t),
                        style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickNewEnd,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Yeni Sözleşme Bitiş Tarihi'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDate(_newEnd)),
                      const Icon(Icons.calendar_today, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _increaseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Zam Oranı (%)',
                        hintText: 'Örn: 25',
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _applyIncrease(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _rentCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Yeni Aylık Kira (TL)',
                        isDense: true,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Zam oranı girerseniz yeni kira otomatik hesaplanır; tutarı elle de yazabilirsiniz.',
                style: TextStyle(fontSize: 11.5, color: Colors.black54),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                value: _generateDues,
                onChanged: (v) => setState(() => _generateDues = v ?? true),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                title: const Text('Uzatılan dönem için ödeme takvimini otomatik oluştur',
                    style: TextStyle(fontSize: 13)),
                subtitle: const Text(
                  'Mevcut borç satırlarına ve geçmiş ödemelere dokunulmaz; yalnızca yeni aylar eklenir.',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Not (opsiyonel)',
                  hintText: 'Örn: TÜFE oranında artış, yeni sözleşme imzalandı.',
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Sözleşmeyi Uzat'),
        ),
      ],
    );
  }
}