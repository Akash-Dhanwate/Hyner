import 'package:flutter/material.dart';

abstract final class HynerTheme {
  static const violet = Color(0xFF6952D9);
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: violet,
          brightness: brightness,
        ).copyWith(
          primary: dark ? const Color(0xFFC4B5FD) : violet,
          surface: dark ? const Color(0xFF15141B) : const Color(0xFFFAF9FC),
          onSurface: dark ? const Color(0xFFF3F0FA) : const Color(0xFF24212D),
          surfaceContainerLow: dark ? const Color(0xFF1D1C24) : Colors.white,
          outlineVariant: dark
              ? const Color(0xFF34313D)
              : const Color(0xFFE8E5EE),
        );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: base.textTheme
          .apply(fontFamily: 'Manrope')
          .copyWith(
            displaySmall: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 38,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
              height: 1.15,
              color: scheme.onSurface,
            ),
            headlineMedium: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              color: scheme.onSurface,
            ),
            titleLarge: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: scheme.onSurface,
            ),
            bodyLarge: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              height: 1.6,
              color: scheme.onSurface,
            ),
            bodyMedium: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              height: 1.55,
              color: scheme.onSurface,
            ),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 56),
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 56),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 76,
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Manrope',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 0, vertical: 6),
        minVerticalPadding: 12,
      ),
    );
  }
}
