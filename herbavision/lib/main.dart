import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const HerbaVisionApp());
}

class HerbaVisionApp extends StatelessWidget {
  const HerbaVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HerbaVision',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF6F7F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F7A4F),
          primary: const Color(0xFF2F7A4F),
        ),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Color(0xFF1C1E1B),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}