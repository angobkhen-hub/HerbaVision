import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'services/auth_state.dart';
import 'services/settings_state.dart';
import 'theme/app_colors.dart';
import 'theme/page_transitions.dart';

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
      seedColor: const Color(0xFF16A05A),
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: AppColors.brand,
      onPrimary: AppColors.onBrand,
      secondary: AppColors.lime,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: dark ? Brightness.dark : Brightness.light,
    );

    final textTheme = base.textTheme
        .apply(
          fontFamily: 'Sora',
          bodyColor: AppColors.textPrimary,
          displayColor: AppColors.textPrimary,
        )
        .copyWith(
          displayLarge: TextStyle(
            fontFamily: 'Sora',
            fontSize: 52,
            height: 1.02,
            fontWeight: FontWeight.w800,
            letterSpacing: -2.0,
            color: AppColors.textPrimary,
          ),
          displayMedium: TextStyle(
            fontFamily: 'Sora',
            fontSize: 40,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
            color: AppColors.textPrimary,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'Sora',
            fontSize: 30,
            height: 1.1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
            color: AppColors.textPrimary,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Sora',
            fontSize: 24,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: AppColors.textPrimary,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Sora',
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
          titleMedium: TextStyle(
            fontFamily: 'Sora',
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Sora',
            fontSize: 15,
            height: 1.5,
            color: AppColors.textPrimary,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'Sora',
            fontSize: 13.8,
            height: 1.5,
            color: AppColors.textSecondary,
          ),
          bodySmall: TextStyle(
            fontFamily: 'Sora',
            fontSize: 12.5,
            height: 1.4,
            color: AppColors.textMuted,
          ),
          labelLarge: TextStyle(
            fontFamily: 'Sora',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
            color: AppColors.textPrimary,
          ),
          labelSmall: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.6,
            color: AppColors.textMuted,
          ),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: textTheme,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: HerbaPageTransitionsBuilder(),
          TargetPlatform.iOS: HerbaPageTransitionsBuilder(),
          TargetPlatform.linux: HerbaPageTransitionsBuilder(),
          TargetPlatform.macOS: HerbaPageTransitionsBuilder(),
          TargetPlatform.windows: HerbaPageTransitionsBuilder(),
          TargetPlatform.fuchsia: HerbaPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Sora',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.textPrimary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 24,
      ),
      iconTheme: IconThemeData(color: AppColors.textSecondary, size: 22),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.isDark
            ? const Color(0x0DFFFFFF)
            : const Color(0xFFF3F8F2),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14.5),
        labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14.5),
        floatingLabelStyle: TextStyle(
          color: AppColors.textAccent,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.brand, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.danger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.danger, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.onBrand,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textMuted,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.onBrand,
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: BorderSide(color: AppColors.border, width: 1.2),
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textAccent,
          textStyle: const TextStyle(
            fontFamily: 'Sora',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceAlt,
        contentTextStyle: TextStyle(
          fontFamily: 'Sora',
          color: AppColors.textPrimary,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.brand,
        linearTrackColor: AppColors.border,
        circularTrackColor: AppColors.border,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.onBrand
              : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.brand
              : AppColors.border,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        textStyle: TextStyle(color: AppColors.textPrimary, fontSize: 12.5),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.border),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(6),
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