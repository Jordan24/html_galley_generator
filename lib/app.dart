import 'package:flutter/material.dart';
import 'features/generator/screens/generator_screen.dart';

/// Root widget that configures [MaterialApp] with the app's theme.
class HtmlGalleyGeneratorApp extends StatelessWidget {
  const HtmlGalleyGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OJS HTML Galley Generator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF334155),
          surface: const Color(0xFFF7F9FB),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
          ),
          bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14),
          labelSmall: TextStyle(fontFamily: 'Inter', fontSize: 12),
        ),
      ),
      home: const GeneratorScreen(),
    );
  }
}
