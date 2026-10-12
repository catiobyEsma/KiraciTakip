import 'package:intl/intl.dart';

/// Kullanıcının bir tutar giriş kutusuna yazdığı Türkçe formatlı metni
/// (örn. "40.000" veya "40.000,50" veya "40000") doğru şekilde sayıya
/// çevirir. Türkçe'de nokta (.) binlik ayraç, virgül (,) ondalık
/// ayraçtır — bu yüzden düz `double.tryParse` kullanmak "40.000" gibi
/// bir girdiyi yanlışlıkla 40.0 olarak okur. Bu fonksiyon o hatayı önler.
double? parseTLAmount(String input) {
  String cleaned = input.trim().replaceAll(' ', '').replaceAll('TL', '').replaceAll('₺', '');
  if (cleaned.isEmpty) return null;

  final hasComma = cleaned.contains(',');
  final hasDot = cleaned.contains('.');

  if (hasComma && hasDot) {
    // "40.000,50" -> nokta binlik ayraç, virgül ondalık ayraç
    cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
  } else if (hasComma) {
    // "40000,50" -> virgülü ondalık noktaya çevir
    cleaned = cleaned.replaceAll(',', '.');
  } else if (hasDot) {
    // "40.000" -> Türkçe kullanımda nokta binlik ayraçtır, kaldır.
    cleaned = cleaned.replaceAll('.', '');
  }

  return double.tryParse(cleaned);
}

/// Bir tutarı giriş kutusunda göstermek için Türkçe binlik ayraçlı metne
/// çevirir (örn. 40000.0 -> "40.000"). "TL" ibaresi eklenmez.
String formatAmountForInput(double amount) {
  final formatter = NumberFormat.decimalPattern('tr_TR');
  formatter.maximumFractionDigits = 2;
  return formatter.format(amount);
}

/// 30000.0 -> "30.000 TL" şeklinde, ekran görüntülerindeki stille
/// birebir uyumlu formatlama.
String formatTL(double amount) {
  final formatter = NumberFormat.decimalPattern('tr_TR');
  formatter.minimumFractionDigits = amount % 1 == 0 ? 0 : 2;
  formatter.maximumFractionDigits = 2;
  return '${formatter.format(amount)} TL';
}

/// 09/04/2026 -> "09/04/2026" (gün/ay/yıl) formatı, ekran görüntüsündeki
/// tarih biçimiyle uyumlu.
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
