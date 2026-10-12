import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/tenant.dart';
import '../models/due_payment.dart';
import '../models/payment_record.dart';
import '../utils/contract_utils.dart';
import '../utils/currency_utils.dart';
import '../utils/payment_calculator.dart';
import '../utils/withholding_utils.dart';
import '../widgets/tenant_notes_panel.dart';
import 'add_payment_dialog.dart';
import 'contract_extend_dialog.dart';

class TenantDetailScreen extends StatefulWidget {
  final Tenant tenant;
  const TenantDetailScreen({super.key, required this.tenant});

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  final _db = DatabaseHelper.instance;
  late Tenant _tenant;
  List<DuePayment> _allDue = [];
  List<PaymentRecord> _allPayments = [];
  bool _loading = true;
  bool _changed = false; // geri dönüldüğünde ana ekran yenilensin mi

  // Varsayılan: tüm sözleşme aralığı gösterilir (ileri tarihli aylar
  // dahil). Borç hesabı yine de yalnızca bugüne kadarki satırlardan
  // yapılır, bu yüzden ileri tarihleri göstermek borcu şişirmez.
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _tenant = widget.tenant;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final fresh = await _db.getTenant(_tenant.id!);
    final due = await _db.getDuePaymentsForTenant(_tenant.id!);
    final payments = await _db.getPaymentRecordsForTenant(_tenant.id!);
    if (!mounted) return;
    setState(() {
      if (fresh != null) _tenant = fresh;
      _allDue = due;
      _allPayments = payments;
      _loading = false;
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: (_rangeStart != null &&
              _rangeEnd != null &&
              !_rangeStart!.isAfter(_rangeEnd!))
          ? DateTimeRange(start: _rangeStart!, end: _rangeEnd!)
          : null,
      helpText: 'Sorgulama Yapılacak Tarih Aralığını Giriniz',
    );
    if (picked != null) {
      setState(() {
        _rangeStart = picked.start;
        _rangeEnd = picked.end;
      });
    }
  }

  Future<void> _openAddPayment() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => AddPaymentDialog(tenant: _tenant),
    );
    if (added == true) {
      _changed = true;
      _load();
    }
  }

  Future<void> _openExtendContract() async {
    final done = await showDialog<bool>(
      context: context,
      builder: (_) => ContractExtendDialog(tenant: _tenant),
    );
    if (done == true) {
      _changed = true;
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Sözleşme uzatıldı ve yeni ödeme takvimi eklendi.')),
        );
      }
    }
  }

  Future<void> _toggleDepositReturned() async {
    final t = _tenant;
    if (t.depositReturned) {
      await _db.updateTenant(t.copyWith(clearDepositReturnedDate: true));
    } else {
      final picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        helpText: 'Depozitonun İade Edildiği Tarih',
      );
      if (picked == null) return;
      await _db.updateTenant(t.copyWith(depositReturnedDate: picked));
    }
    _changed = true;
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final filteredDue = _allDue.where((d) {
      if (_rangeStart != null && d.dueDate.isBefore(_rangeStart!)) return false;
      if (_rangeEnd != null && d.dueDate.isAfter(_rangeEnd!)) return false;
      return true;
    }).toList();

    final report = PaymentCalculator.calculate(
      dueList: filteredDue,
      paymentList: _allPayments,
    );
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final rangeCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _rangeStart != null && _rangeEnd != null
                  ? '${formatDate(_rangeStart!)} - ${formatDate(_rangeEnd!)}'
                  : 'Tüm sözleşme gösteriliyor (ileri tarihli aylar dahil)',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 4,
              runSpacing: 0,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    final now = DateTime.now();
                    _rangeStart = _tenant.contractStart;
                    _rangeEnd = now.isBefore(_tenant.contractEnd)
                        ? now
                        : _tenant.contractEnd;
                  }),
                  child: const Text('Bugüne Kadar'),
                ),
                TextButton(
                    onPressed: _pickRange, child: const Text('Aralık Seç')),
                if (_rangeStart != null || _rangeEnd != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _rangeStart = null;
                      _rangeEnd = null;
                    }),
                    child: const Text('Tüm Sözleşmeyi Göster'),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'İleri tarihli (vadesi gelmemiş) aylar listede soluk renkte görünür; "Kalan Borç" yalnızca bugüne kadar vadesi gelen ödemelerden hesaplanır.',
              style: TextStyle(
                  fontSize: 11.5, color: Colors.black.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
    final dueList = filteredDue.isEmpty
        ? const Center(
            child: Text('Bu tarih aralığında ödeme kaydı bulunmuyor.'))
        : ListView.separated(
            shrinkWrap: isCompact,
            physics: isCompact ? const NeverScrollableScrollPhysics() : null,
            itemCount: report.rows.length,
            separatorBuilder: (_, __) => const Divider(height: 20),
            itemBuilder: (context, index) =>
                _DueRowTile(row: report.rows[index], tenant: _tenant),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text('Kiracı: ${_tenant.fullName.toUpperCase()}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_changed),
        ),
        actions: [
          IconButton(
            tooltip: 'Kiracı Notları',
            onPressed: () => showTenantNotesDialog(context, _tenant),
            icon: const Icon(Icons.sticky_note_2_outlined),
          ),
          IconButton(
            tooltip: 'Sözleşmeyi Uzat',
            onPressed: _openExtendContract,
            icon: const Icon(Icons.update),
          ),
          IconButton(
            tooltip: 'Yeni Ödeme Gir',
            onPressed: _openAddPayment,
            icon: const Icon(Icons.add_card_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Padding(
                  padding: EdgeInsets.all(isCompact ? 12 : 20),
                  child: isCompact
                      ? SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _contractAndDepositCard(),
                              const SizedBox(height: 12),
                              rangeCard,
                              const SizedBox(height: 12),
                              dueList,
                              const SizedBox(height: 12),
                              _summaryCard(report),
                            ],
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _contractAndDepositCard(),
                            const SizedBox(height: 12),
                            rangeCard,
                            const SizedBox(height: 16),
                            Expanded(child: dueList),
                            const SizedBox(height: 12),
                            _summaryCard(report),
                          ],
                        ),
                ),
              ),
            ),
    );
  }


  // Sözleşme + Depozito + Stopaj özeti

  Widget _contractAndDepositCard() {
    final t = _tenant;
    final days = t.daysUntilContractEnd();
    final ending = t.needsContractReminder();
    final wh = calcWithholdingForTenant(t, t.monthlyRent);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 18,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _infoBlock(
                  'Sözleşme',
                  '${formatDate(t.contractStart)} - ${formatDate(t.contractEnd)}',
                  sub: contractRemainingLabel(t),
                  subColor: ending
                      ? (days < 0
                          ? const Color(0xFF8A1F1F)
                          : const Color(0xFF8A6D1F))
                      : Colors.black54,
                ),
                _infoBlock(
                  'Depozito',
                  t.hasDeposit ? formatTL(t.depositAmount) : 'Yok',
                  sub: !t.hasDeposit
                      ? null
                      : t.depositReturned
                          ? 'İade edildi: ${formatDate(t.depositReturnedDate!)}'
                          : t.depositReceivedDate != null
                              ? 'Alındı: ${formatDate(t.depositReceivedDate!)} • elde'
                              : 'Elde tutuluyor',
                  subColor: t.hasDeposit && !t.depositReturned
                      ? const Color(0xFF2E8B57)
                      : Colors.black54,
                ),
                if (t.withholdingEnabled)
                  _infoBlock(
                    'Stopaj (%${_ratePretty(t.withholdingRate)})',
                    'Aylık kesinti: ${formatTL(wh.withheld)}',
                    sub: 'Brüt ${formatTL(wh.gross)} → Net ${formatTL(wh.net)}',
                  ),
              ],
            ),
            if (t.depositNote.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Depozito notu: ${t.depositNote}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _openExtendContract,
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12.5),
                  ),
                  icon: const Icon(Icons.update, size: 16),
                  label: const Text('Sözleşmeyi Uzat'),
                ),
                if (t.hasDeposit)
                  OutlinedButton.icon(
                    onPressed: _toggleDepositReturned,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12.5),
                    ),
                    icon: Icon(
                      t.depositReturned
                          ? Icons.undo
                          : Icons.assignment_turned_in_outlined,
                      size: 16,
                    ),
                    label: Text(t.depositReturned
                        ? 'Depozito İadesini Geri Al'
                        : 'Depozitoyu İade Edildi İşaretle'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => showTenantNotesDialog(context, t),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12.5),
                  ),
                  icon: const Icon(Icons.sticky_note_2_outlined, size: 16),
                  label: const Text('Kiracı Notları'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _ratePretty(double rate) =>
      rate.toStringAsFixed(rate % 1 == 0 ? 0 : 2);

  Widget _infoBlock(String label, String value,
      {String? sub, Color? subColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11.5, color: Colors.black54)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        if (sub != null)
          Text(sub,
              style:
                  TextStyle(fontSize: 11.5, color: subColor ?? Colors.black54)),
      ],
    );
  }


  Widget _summaryCard(TenantPaymentReport report) {
    final t = _tenant;
    final whDue = calcWithholdingForTenant(t, report.totalDue);
    final whPaid = calcWithholdingForTenant(t, report.totalPaid);

    return Card(
      color: const Color(0xFF1A1A1D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text('Bugün: ${formatDate(DateTime.now())}',
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _openAddPayment,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('ÖDEME GİR',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            const SizedBox(height: 6),
            _summaryLine(
                'Toplam Yapılan Ödeme', report.totalPaid, Colors.white),
            _summaryLine('Toplam Yapılması Gereken Ödeme (bugüne kadar)',
                report.totalDue, Colors.white70),
            const Divider(color: Colors.white24, height: 20),
            _summaryLine('Kalan Borç (bugüne kadar)', report.remainingDebt,
                report.remainingDebt > 0 ? Colors.white : Colors.white70,
                bold: true),
            if (report.totalUpcomingDue > 0) ...[
              const SizedBox(height: 6),
              _summaryLine('Vadesi Gelmemiş (ileri tarihli) Ödemeler',
                  report.totalUpcomingDue, Colors.white38),
              if (report.totalPrepaid > 0)
                _summaryLine('Bunlara Şimdiden Yapılan Ödeme',
                    report.totalPrepaid, Colors.white38),
            ],
            if (t.withholdingEnabled) ...[
              const Divider(color: Colors.white24, height: 20),
              Text('Stopaj Özeti (%${_ratePretty(t.withholdingRate)})',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              _summaryLine('Brüt Kira Toplamı (bugüne kadar)', whDue.gross,
                  Colors.white70),
              _summaryLine(
                  'Kesilen Stopaj Toplamı', whDue.withheld, Colors.white70),
              _summaryLine('Tahsil Edilen Üzerinden Stopaj', whPaid.withheld,
                  Colors.white38),
              const SizedBox(height: 4),
              const Text(
                'Stopaj tutarları bilgi amaçlıdır; beyan ve mahsup için mali müşavirinize danışın.',
                style: TextStyle(color: Colors.white38, fontSize: 10.5),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryLine(String label, double amount, Color color,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Text(
        '$label: ${formatTL(amount)}',
        style: TextStyle(
          color: color,
          fontWeight: bold ? FontWeight.bold : FontWeight.w500,
          fontSize: bold ? 16 : 14,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _DueRowTile extends StatelessWidget {
  final DuePaymentSummary row;
  final Tenant tenant;
  const _DueRowTile({required this.row, required this.tenant});

  Color get _statusColor {
    switch (row.status) {
      case DueStatus.paid:
        return const Color(0xFF2E8B57);
      case DueStatus.partial:
        return const Color(0xFFB8860B);
      case DueStatus.unpaid:
        return Colors.black45;
      case DueStatus.overpaid:
        return const Color(0xFF2E8B57);
      case DueStatus.upcoming:
        return Colors.black38;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = row.duePayment;

    final opacity = row.isFuture ? 0.55 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                          '${formatTL(d.dueAmount)} - ${formatDate(d.dueDate)}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    if (row.isFuture) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7E7E9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('İLERİ TARİHLİ',
                            style:
                                TextStyle(fontSize: 9.5, letterSpacing: 0.4)),
                      ),
                    ],
                  ],
                ),
                Text(d.description,
                    style:
                        const TextStyle(color: Colors.black54, fontSize: 12)),
                if (tenant.withholdingEnabled)
                  Builder(builder: (_) {
                    final b = calcWithholdingForTenant(tenant, d.dueAmount);
                    return Text(
                      'Brüt ${formatTL(b.gross)} • Stopaj ${formatTL(b.withheld)}',
                      style:
                          const TextStyle(color: Colors.black38, fontSize: 11),
                    );
                  }),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (row.linkedPayments.isEmpty)
                  const Text('—', style: TextStyle(color: Colors.black38))
                else
                  ...row.linkedPayments.map((p) => Text(
                        '+ ${formatTL(p.paidAmount)} - ${formatDate(p.paidDate)}',
                        style: const TextStyle(
                            color: Color(0xFF2E8B57),
                            fontWeight: FontWeight.w600),
                      )),
                const SizedBox(height: 4),
                Text(
                  row.status == DueStatus.unpaid ||
                          row.status == DueStatus.upcoming
                      ? row.statusLabel
                      : '${row.statusLabel}. "${d.description}" için kalan borç: ${formatTL(row.remainingForRow)}',
                  style: TextStyle(color: _statusColor, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
