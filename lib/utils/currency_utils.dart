import 'package:intl/intl.dart';

double? parseTLAmount(String input) {
  String cleaned = input.trim().replaceAll(' ', '').replaceAll('TL', '').replaceAll('₺', '');
  if (cleaned.isEmpty) return null;

  final hasComma = cleaned.contains(',');
  final hasDot = cleaned.contains('.');

  if (hasComma && hasDot) {
   
    cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
  } else if (hasComma) {
    
    cleaned = cleaned.replaceAll(',', '.');
  } else if (hasDot) {
 
    cleaned = cleaned.replaceAll('.', '');
  }

  return double.tryParse(cleaned);
}

String formatAmountForInput(double amount) {
  final formatter = NumberFormat.decimalPattern('tr_TR');
  formatter.maximumFractionDigits = 2;
  return formatter.format(amount);
}

String formatTL(double amount) {
  final formatter = NumberFormat.decimalPattern('tr_TR');
  formatter.minimumFractionDigits = amount % 1 == 0 ? 0 : 2;
  formatter.maximumFractionDigits = 2;
  return '${formatter.format(amount)} TL';
}


String formatDate(DateTime date) {
  final dd = date.day.toString().padLeft(2, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final yyyy = date.year.toString();
  return '$dd/$mm/$yyyy';
}

String formatMonthYear(DateTime date) {
  const months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];
  return '${months[date.month - 1]} ${date.year}';
}

String monthNameTR(int month) {
  const months = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];
  return months[month - 1];
}
