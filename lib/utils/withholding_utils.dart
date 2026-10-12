import '../models/tenant.dart';

class WithholdingBreakdown {
  final double gross;
  final double net;
  final double withheld;

  const WithholdingBreakdown({
    required this.gross,
    required this.net,
    required this.withheld,
  });
}

WithholdingBreakdown calcWithholding({
  required double amount,
  required double ratePercent,
  required bool amountIsNet,
}) {
  final rate = ratePercent <= 0 ? 0 : ratePercent;

  if (!amountIsNet) {
    final withheld = amount * rate / 100;
    return WithholdingBreakdown(
      gross: amount,
      net: amount - withheld,
      withheld: withheld,
    );
  }

  final gross = amount / (1 - (rate / 100));
  final withheld = gross - amount;
  return WithholdingBreakdown(
    gross: gross,
    net: amount,
    withheld: withheld,
  );
}

WithholdingBreakdown calcWithholdingForTenant(Tenant tenant, double amount) {
  if (!tenant.withholdingEnabled) {
    return WithholdingBreakdown(
      gross: amount,
      net: amount,
      withheld: 0,
    );
  }

  return calcWithholding(
    amount: amount,
    ratePercent: tenant.withholdingRate,
    amountIsNet: tenant.rentIsNet,
  );
}
