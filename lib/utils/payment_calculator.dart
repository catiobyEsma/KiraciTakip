import '../models/due_payment.dart';
import '../models/payment_record.dart';

enum DueStatus { paid, partial, unpaid, overpaid, upcoming }

class DuePaymentSummary {
  final DuePayment duePayment;
  final List<PaymentRecord> linkedPayments;
  final double totalPaidForRow;
  final double remainingForRow;
  final DueStatus status;

  final bool isFuture;

  DuePaymentSummary({
    required this.duePayment,
    required this.linkedPayments,
    required this.totalPaidForRow,
    required this.remainingForRow,
    required this.status,
    this.isFuture = false,
  });

  String get statusLabel {
    switch (status) {
      case DueStatus.paid:
        return 'Ödendi';
      case DueStatus.partial:
        return 'Kısmen Ödendi';
      case DueStatus.unpaid:
        return 'Bu aya dair ödeme bilgisi bulunamadı.';
      case DueStatus.overpaid:
        return 'Fazla Ödendi';
      case DueStatus.upcoming:
        return 'Vadesi gelmedi (ileri tarihli)';
    }
  }
}

class TenantPaymentReport {
  final List<DuePaymentSummary> rows;
  final double totalDue;
  final double totalPaid;
  final double remainingDebt;
  final double totalUpcomingDue;
  final double totalPrepaid;
  double get totalDueAll => totalDue + totalUpcomingDue;

  TenantPaymentReport({
    required this.rows,
    required this.totalDue,
    required this.totalPaid,
    required this.remainingDebt,
    this.totalUpcomingDue = 0,
    this.totalPrepaid = 0,
  });
}

class PaymentCalculator {
  static TenantPaymentReport calculate({
    required List<DuePayment> dueList,
    required List<PaymentRecord> paymentList,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final cutoff = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final sortedDue = [...dueList]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final unlinked = paymentList.where((p) => p.duePaymentId == null).toList()
      ..sort((a, b) => a.paidDate.compareTo(b.paidDate));
    final unlinkedQueue = [...unlinked];

    final rows = <DuePaymentSummary>[];
    double totalDue = 0;
    double totalPaid = 0;
    double totalUpcomingDue = 0;
    double totalPrepaid = 0;

    for (final due in sortedDue) {
      final isFuture = due.dueDate.isAfter(cutoff);

      final linked = paymentList.where((p) => p.duePaymentId == due.id).toList()
        ..sort((a, b) => a.paidDate.compareTo(b.paidDate));

      double paidForRow = linked.fold(0.0, (sum, p) => sum + p.paidAmount);

      double remainingBeforeAuto = due.dueAmount - paidForRow;
      while (remainingBeforeAuto > 0 && unlinkedQueue.isNotEmpty) {
        final p = unlinkedQueue.first;
        final applied =
            p.paidAmount <= remainingBeforeAuto ? p.paidAmount : remainingBeforeAuto;
        paidForRow += applied;
        remainingBeforeAuto -= applied;
        linked.add(p);
        unlinkedQueue.removeAt(0);
      }

      if (isFuture) {
        totalUpcomingDue += due.dueAmount;
        totalPrepaid += paidForRow;
      } else {
        totalDue += due.dueAmount;
        totalPaid += paidForRow;
      }

      final remaining = due.dueAmount - paidForRow;

      DueStatus status;
      if (remaining <= 0.009 && remaining >= -0.009) {
        status = DueStatus.paid;
      } else if (remaining < 0) {
        status = DueStatus.overpaid;
      } else if (paidForRow > 0) {
        status = DueStatus.partial;
      } else {
        status = isFuture ? DueStatus.upcoming : DueStatus.unpaid;
      }

      rows.add(DuePaymentSummary(
        duePayment: due,
        linkedPayments: linked,
        totalPaidForRow: paidForRow,
        remainingForRow: remaining < 0 ? 0 : remaining,
        status: status,
        isFuture: isFuture,
      ));
    }

    for (final p in unlinkedQueue) {
      totalPaid += p.paidAmount;
    }

    final remainingDebt = totalDue - totalPaid;

    return TenantPaymentReport(
      rows: rows,
      totalDue: totalDue,
      totalPaid: totalPaid,
      remainingDebt: remainingDebt < 0 ? 0 : remainingDebt,
      totalUpcomingDue: totalUpcomingDue,
      totalPrepaid: totalPrepaid,
    );
  }
}