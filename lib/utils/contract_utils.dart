import '../models/due_payment.dart';
import '../models/tenant.dart';

DateTime _dateForMonth(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  final safeDay = day > lastDay ? lastDay : day;
  return DateTime(year, month, safeDay);
}

String monthNameTR(int month) {
  const months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];
  return months[month - 1];
}

List<DuePayment> generateMonthlyDuePayments({
  required int tenantId,
  required DateTime periodStart,
  required DateTime periodEnd,
  required int paymentDay,
  required double amount,
  bool includeYearInDescription = false,
}) {
  if (periodEnd.isBefore(periodStart)) return const [];

  final result = <DuePayment>[];
  var cursor = DateTime(periodStart.year, periodStart.month, 1);
  final lastMonth = DateTime(periodEnd.year, periodEnd.month, 1);

  while (!cursor.isAfter(lastMonth)) {
    final dueDate = _dateForMonth(cursor.year, cursor.month, paymentDay);
    if (!dueDate.isBefore(periodStart) && !dueDate.isAfter(periodEnd)) {
      final description = includeYearInDescription
          ? '${monthNameTR(cursor.month)} ${cursor.year}'
          : monthNameTR(cursor.month);
      result.add(DuePayment(
        tenantId: tenantId,
        dueDate: dueDate,
        dueAmount: amount,
        description: description,
      ));
    }
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }

  return result;
}

String contractRemainingLabel(Tenant tenant) {
  final days = tenant.daysUntilContractEnd();
  if (days < 0) {
    return 'Sözleşme ${-days} gün önce sona erdi.';
  }
  if (days == 0) {
    return 'Sözleşme bugün sona eriyor.';
  }
  return 'Kalan süre: $days gün';
}
