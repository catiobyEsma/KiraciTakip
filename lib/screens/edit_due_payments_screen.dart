import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/tenant.dart';
import '../models/due_payment.dart';
import '../utils/currency_utils.dart';

/// Ekran görüntüsündeki "Kiracı: DUYGU K." + "Ödemesi Gereken Tutar / Tarih"
/// tablosunun (MacBook Air - 3/4) birebir karşılığı. Kullanıcı burada
/// "Yapılması Gereken Ödemeler" satırlarını elle ekleyip, düzenleyip,
/// silip "Kaydet" ile veritabanına yazabilir.
class EditDuePaymentsScreen extends StatefulWidget {
  final Tenant tenant;
  const EditDuePaymentsScreen({super.key, required this.tenant});

  @override
  State<EditDuePaymentsScreen> createState() => _EditDuePaymentsScreenState();
}

class _RowData {
  int? id; // null ise henüz kaydedilmemiş yeni satır
  final TextEditingController amountCtrl;
  DateTime? rangeStart;
  DateTime? rangeEnd;
  final TextEditingController descCtrl;

  _RowData(
      {this.id,
      required this.amountCtrl,
      this.rangeStart,
      this.rangeEnd,
      required this.descCtrl});
}

class _EditDuePaymentsScreenState extends State<EditDuePaymentsScreen> {
  final _db = DatabaseHelper.instance;
  final List<_RowData> _rows = [];
  bool _loading = true;
  bool _saving = false;
  final List<int> _deletedIds = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final due = await _db.getDuePaymentsForTenant(widget.tenant.id!);
    setState(() {
      _rows.clear();
      for (final d in due) {
        _rows.add(_RowData(
          id: d.id,
          amountCtrl:
              TextEditingController(text: formatAmountForInput(d.dueAmount)),
          rangeStart: d.dueDate,
          rangeEnd: d.dueDate,
          descCtrl: TextEditingController(text: d.description),
        ));
      }
      _loading = false;
    });
  }

  void _addRow() {
    setState(() {
      _rows.add(_RowData(
        amountCtrl: TextEditingController(),
        descCtrl: TextEditingController(),
      ));
    });
  }

  void _removeRow(int index) {
    final row = _rows[index];
    if (row.id != null) _deletedIds.add(row.id!);
    setState(() => _rows.removeAt(index));
  }

  Future<void> _pickDate(_RowData row) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: row.rangeStart ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Ödemenin Yapılması Gereken Tarih',
    );
    if (picked != null) {
      setState(() {
        row.rangeStart = picked;
        row.rangeEnd = picked;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    for (final id in _deletedIds) {
      await _db.deleteDuePayment(id);
    }

    for (final row in _rows) {
      final amount = parseTLAmount(row.amountCtrl.text);
      if (amount == null || row.rangeStart == null) continue;
      final duePayment = DuePayment(
        id: row.id,
        tenantId: widget.tenant.id!,
        dueDate: row.rangeStart!,
        dueAmount: amount,
        description: row.descCtrl.text.trim().isEmpty
            ? 'Kira Ödemesi'
            : row.descCtrl.text.trim(),
      );
      if (row.id == null) {
        final newId = await _db.insertDuePayment(duePayment);
        row.id = newId;
      } else {
        await _db.updateDuePayment(duePayment);
      }
    }

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ödeme takvimi kaydedildi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    return Scaffold(
      appBar: AppBar(
          title: Text('Kiracı: ${widget.tenant.fullName.toUpperCase()}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: EdgeInsets.all(isCompact ? 12 : 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isCompact)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: const [
                                Expanded(
                                    flex: 3,
                                    child: Text('Ödemesi Gereken Tutar',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                Expanded(
                                    flex: 2,
                                    child: Text('Tarih',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                Expanded(
                                    flex: 3,
                                    child: Text('Açıklama',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold))),
                                SizedBox(width: 40),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 8),
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            if (isCompact) {
                              return Card(
                                margin: EdgeInsets.zero,
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      TextField(
                                        controller: row.amountCtrl,
                                        decoration: const InputDecoration(
                                          labelText: 'Ödemesi Gereken Tutar',
                                          suffixText: 'TL',
                                        ),
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                      ),
                                      const SizedBox(height: 10),
                                      InkWell(
                                        onTap: () => _pickDate(row),
                                        child: InputDecorator(
                                          decoration: const InputDecoration(
                                              labelText: 'Tarih'),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(row.rangeStart != null
                                                  ? formatDate(row.rangeStart!)
                                                  : 'Tarih seç'),
                                              const Icon(Icons.calendar_today,
                                                  size: 16),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextField(
                                        controller: row.descCtrl,
                                        decoration: const InputDecoration(
                                            labelText: 'Açıklama'),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: IconButton(
                                          tooltip: 'Satırı sil',
                                          icon:
                                              const Icon(Icons.delete_outline),
                                          onPressed: () => _removeRow(index),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return Container(
                              color: const Color(0xFFEDEDEF),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: row.amountCtrl,
                                      decoration: const InputDecoration(
                                          isDense: true,
                                          suffixText: 'TL',
                                          border: InputBorder.none),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: InkWell(
                                      onTap: () => _pickDate(row),
                                      child: Text(
                                        row.rangeStart != null
                                            ? formatDate(row.rangeStart!)
                                            : 'Tarih seç',
                                        style: const TextStyle(
                                            decoration:
                                                TextDecoration.underline),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      controller: row.descCtrl,
                                      decoration: const InputDecoration(
                                          isDense: true,
                                          border: InputBorder.none,
                                          hintText: 'Açıklama'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: 40,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () => _removeRow(index),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _addRow,
                            icon: const Icon(Icons.add),
                            label: const Text('Satır Ekle'),
                          ),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.save_outlined),
                            label: const Text('Kaydet'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
