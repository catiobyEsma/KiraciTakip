import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../db/database_helper.dart';
import '../models/tenant.dart';
import '../models/due_payment.dart';
import '../models/payment_record.dart';
import '../utils/currency_utils.dart';

/// Ana ekrandaki takvim paneli. Bir günde:
///  - Ödenmesi GEREKEN bir tarih varsa (kiracı ismi, ne kadar atması
///    gerektiği) kırmızı/turuncu nokta,
///  - O gün fiilen bir ödeme YAPILDIYSA (kiracı ismi, ne kadar attığı)
///    yeşil nokta ile işaretlenir.
/// Güne tıklandığında bu bilgiler bir liste halinde gösterilir.
class CalendarPanel extends StatefulWidget {
  final VoidCallback onCreateTenant;
  const CalendarPanel({super.key, required this.onCreateTenant});

  @override
  State<CalendarPanel> createState() => _CalendarPanelState();
}

class _CalendarPanelState extends State<CalendarPanel> {
  final _db = DatabaseHelper.instance;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<int, Tenant> _tenantsById = {};
  List<DuePayment> _dueList = [];
  List<PaymentRecord> _paymentList = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final tenants = await _db.getAllTenants();
    final due = await _db.getAllDuePayments();
    final payments = await _db.getAllPaymentRecords();
    setState(() {
      _tenantsById = {for (final t in tenants) t.id!: t};
      _dueList = due;
      _paymentList = payments;
      _loading = false;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<DuePayment> _dueOn(DateTime day) =>
      _dueList.where((d) => _isSameDay(d.dueDate, day)).toList();

  List<PaymentRecord> _paidOn(DateTime day) =>
      _paymentList.where((p) => _isSameDay(p.paidDate, day)).toList();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Takvim',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                FilledButton.icon(
                  onPressed: () async {
                    widget.onCreateTenant();
                    _loadData();
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12.5),
                  ),
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  label: const Text('Kiracı Oluştur'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // Minik takvim: sabit genişlik, düşük satır yüksekliği,
              // küçük yazı tipi.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: TableCalendar(
                  firstDay: DateTime(2015, 1, 1),
                  lastDay: DateTime(2100, 12, 31),
                  focusedDay: _focusedDay,
                  rowHeight: 30,
                  daysOfWeekHeight: 18,
                  selectedDayPredicate: (day) =>
                      _selectedDay != null && _isSameDay(_selectedDay!, day),
                  onDaySelected: (selected, focused) {
                    setState(() {
                      _selectedDay = selected;
                      _focusedDay = focused;
                    });
                  },
                  onPageChanged: (focused) => _focusedDay = focused,
                  calendarFormat: CalendarFormat.month,
                  availableCalendarFormats: const {CalendarFormat.month: 'Ay'},
                  locale: 'tr_TR',
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(fontSize: 10.5, color: Colors.black54),
                    weekendStyle: TextStyle(fontSize: 10.5, color: Colors.black54),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    leftChevronIcon: Icon(Icons.chevron_left, size: 18),
                    rightChevronIcon: Icon(Icons.chevron_right, size: 18),
                    headerPadding: EdgeInsets.symmetric(vertical: 4),
                  ),
                  calendarStyle: const CalendarStyle(
                    cellMargin: EdgeInsets.all(2),
                    defaultTextStyle: TextStyle(fontSize: 11.5, color: Color(0xFF2D2826)),
                    weekendTextStyle: TextStyle(fontSize: 11.5, color: Color(0xFF2D2826)),
                    outsideTextStyle: TextStyle(fontSize: 11, color: Color(0xFFC1A79B)),
                    todayDecoration: BoxDecoration(
                      color: Color(0xFFE4CFC7),
                      shape: BoxShape.circle,
                    ),
                    todayTextStyle: TextStyle(fontSize: 11.5, color: Color(0xFF2D2826)),
                    selectedDecoration: BoxDecoration(
                      color: Color(0xFFD8B3A5),
                      shape: BoxShape.circle,
                    ),
                    selectedTextStyle: TextStyle(fontSize: 11.5, color: Color(0xFF2D2826)),
                    markersMaxCount: 2,
                  ),
                  eventLoader: (day) => [
                    ..._dueOn(day),
                    ..._paidOn(day),
                  ],
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      final due = _dueOn(day);
                      final paid = _paidOn(day);
                      if (due.isEmpty && paid.isEmpty) return null;
                      return Positioned(
                        bottom: 1,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (due.isNotEmpty) _dot(const Color(0xFFD39A8B)),
                            if (paid.isNotEmpty) _dot(const Color(0xFF8AB7AA)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const Divider(height: 20),
              _buildSelectedDayInfo(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dot(Color color) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _buildSelectedDayInfo() {
    if (_selectedDay == null) return const SizedBox.shrink();
    final due = _dueOn(_selectedDay!);
    final paid = _paidOn(_selectedDay!);

    if (due.isEmpty && paid.isEmpty) {
      return Text(
        '${formatDate(_selectedDay!)} tarihinde herhangi bir ödeme kaydı bulunmuyor.',
        style: const TextStyle(color: Colors.black54),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(formatDate(_selectedDay!),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 8),
        ...due.map((d) {
          final tenant = _tenantsById[d.tenantId];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                const Icon(Icons.radio_button_unchecked, size: 14, color: Color(0xFF8A8A8E)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${tenant?.fullName ?? "Bilinmeyen Kiracı"} — ${formatTL(d.dueAmount)} ödemesi gerekiyor (${d.description})',
                  ),
                ),
              ],
            ),
          );
        }),
        ...paid.map((p) {
          final tenant = _tenantsById[p.tenantId];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E8B57)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${tenant?.fullName ?? "Bilinmeyen Kiracı"} — ${formatTL(p.paidAmount)} ödedi',
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
