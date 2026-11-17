import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_strings.dart';
import 'screens/home_screen.dart';
import 'screens/language_selection_screen.dart';

void main() {
  runApp(const CowHealthScannerApp());
}

class CowHealthScannerApp extends StatefulWidget {
  const CowHealthScannerApp({super.key});

  @override
  State<CowHealthScannerApp> createState() => _CowHealthScannerAppState();
}

class _CowHealthScannerAppState extends State<CowHealthScannerApp> {
  AppLanguage? _language;

  void _onLanguageSelected(AppLanguage language) {
    setState(() {
      _language = language;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color seed = const Color(0xFF1E8E5A);

    final AppLanguage effectiveLanguage = _language ?? AppLanguage.english;
    final strings = AppStrings(effectiveLanguage);

    final home = _language == null
        ? LanguageSelectionScreen(onSelected: _onLanguageSelected)
        : const HomeScreen();

    return AppStringsScope(
      strings: strings,
      child: MaterialApp(
        title: strings.appTitle,
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.light,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: seed,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFF7FAF8),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black87,
          ),
          cardTheme: CardThemeData(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        locale: effectiveLanguage == AppLanguage.urdu
            ? const Locale('ur')
            : const Locale('en'),
        supportedLocales: const [
          Locale('en'),
          Locale('ur'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: effectiveLanguage == AppLanguage.urdu
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: home,
        ),
      ),
    );
  }
}
