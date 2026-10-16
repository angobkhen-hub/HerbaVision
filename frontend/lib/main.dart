import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'services/auth_state.dart';
import 'services/settings_state.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(const HerbaVisionApp());
}

class NoStretchScrollBehavior extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class HerbaVisionApp extends StatelessWidget {
  const HerbaVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => SettingsState()..load()),
      ],
      child: const _ThemedApp(),
    );
  }
}

/// Rebuilds every widget currently on screen. AppColors reads its values
/// from a global switch, so screens that are already open have to be
/// rebuilt for the new colors to show up.
void _rebuildAll() {
  void visit(Element element) {
    element.markNeedsBuild();
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
}

class _ThemedApp extends StatelessWidget {
  const _ThemedApp();

  ThemeData _buildTheme(bool dark) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2F7A4F),
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: AppColors.brand,
      onPrimary: AppColors.onBrand,
      surface: AppColors.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.bg,
      fontFamily: 'Roboto',
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.select<SettingsState, bool>((s) => s.darkMode);

    if (AppColors.dark != dark) {
      AppColors.dark = dark;
      // Wait until this frame finishes, then redraw the open screens.
      WidgetsBinding.instance.addPostFrameCallback((_) => _rebuildAll());
    }

    return MaterialApp(
      title: 'HerbaVision',
      debugShowCheckedModeBanner: false,
      scrollBehavior: NoStretchScrollBehavior(),
      theme: _buildTheme(dark),
      home: const SplashScreen(),
    );
  }
}