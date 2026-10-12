import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);
  runApp(const KiraciTakipApp());
}

class KiraciTakipApp extends StatelessWidget {
  const KiraciTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    const warmBackground = Color(0xFFF5F0EC);
    const warmPanel = Color(0xFFF1E9E4);
    const warmCard = Color(0xFFF6F1EE);
    const border = Color(0xFFD9C7BE);
    const accent = Color(0xFFD8B3A5);
    const accentStrong = Color(0xFFC99583);
    const text = Color(0xFF2D2826);
    const muted = Color(0xFF756864);

    return MaterialApp(
      title: 'Kiracı Ödeme Takip Sistemi',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr', 'TR'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.light,
          primary: accent,
          secondary: accentStrong,
          surface: warmCard,
          onSurface: text,
        ),
        scaffoldBackgroundColor: warmBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: warmBackground,
          foregroundColor: text,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: text,
            fontSize: 19,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: warmCard,
          surfaceTintColor: warmCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: border),
          ),
        ),
        dividerTheme: const DividerThemeData(color: border, thickness: 1),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: text,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: text,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: text,
            side: const BorderSide(color: border),
            backgroundColor: warmPanel,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: text),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: accentStrong, width: 1.4),
          ),
          labelStyle: const TextStyle(color: muted),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.bold, color: text),
          titleMedium: TextStyle(fontWeight: FontWeight.w600, color: text),
          bodyMedium: TextStyle(color: text),
        ),
        listTileTheme: const ListTileThemeData(iconColor: muted),
      ),
      home: const HomeScreen(),
    );
  }
}
