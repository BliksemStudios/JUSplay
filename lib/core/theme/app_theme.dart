import 'package:flutter/material.dart';

class AppThemeConfig {
  const AppThemeConfig({
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.displayName,
  });
  final Color accent;
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final String displayName;
}

class AppTheme {
  AppTheme._();

  static const Map<String, AppThemeConfig> themeConfigs = {
    'goldAmber': AppThemeConfig(
      accent: Color(0xFFF59E0B),
      background: Color(0xFF0A0A0A),
      surface: Color(0xFF1A1500),
      surfaceHigh: Color(0xFF2A2000),
      displayName: 'Dark + Gold/Amber',
    ),
    'cyanTeal': AppThemeConfig(
      accent: Color(0xFF06B6D4),
      background: Color(0xFF030A0A),
      surface: Color(0xFF001515),
      surfaceHigh: Color(0xFF002020),
      displayName: 'Dark + Cyan/Teal',
    ),
    'coralOrange': AppThemeConfig(
      accent: Color(0xFFF97316),
      background: Color(0xFF0A0500),
      surface: Color(0xFF1A0A00),
      surfaceHigh: Color(0xFF2A1000),
      displayName: 'Dark + Coral/Orange',
    ),
    'oledWhite': AppThemeConfig(
      accent: Color(0xFFFFFFFF),
      background: Color(0xFF000000),
      surface: Color(0xFF111111),
      surfaceHigh: Color(0xFF1A1A1A),
      displayName: 'OLED + White',
    ),
  };

  static const Color _onSurface = Color(0xFFE6E1E5);
  static const Color _onSurfaceVariant = Color(0xFFCAC4D0);

  static ThemeData forAccent(String themeKey) {
    final config = themeConfigs[themeKey] ?? themeConfigs['goldAmber']!;
    return _buildDarkTheme(config);
  }

  static ThemeData _buildDarkTheme(AppThemeConfig c) {
    final colorScheme = ColorScheme.dark(
      primary: c.accent,
      onPrimary: c.background,
      primaryContainer: c.accent.withValues(alpha: 0.3),
      onPrimaryContainer: const Color(0xFFEADDFF),
      secondary: const Color(0xFFCCC2DC),
      onSecondary: const Color(0xFF332D41),
      secondaryContainer: const Color(0xFF4A4458),
      onSecondaryContainer: const Color(0xFFE8DEF8),
      tertiary: const Color(0xFFEFB8C8),
      onTertiary: const Color(0xFF492532),
      tertiaryContainer: const Color(0xFF633B48),
      onTertiaryContainer: const Color(0xFFFFD8E4),
      error: const Color(0xFFF2B8B5),
      onError: const Color(0xFF601410),
      surface: c.background,
      onSurface: _onSurface,
      onSurfaceVariant: _onSurfaceVariant,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.background,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceHigh,
      surfaceContainerHighest: c.surfaceHigh,
      outline: const Color(0xFF938F99),
      outlineVariant: const Color(0xFF49454F),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: c.background,
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: _onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: _onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.background,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: c.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.accent,
          side: BorderSide(color: c.accent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: _onSurface),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.accent.withValues(alpha: 0.24),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: c.accent);
          }
          return const IconThemeData(color: _onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.accent,
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: _onSurfaceVariant,
          );
        }),
        elevation: 4,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c.accent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: c.accent,
        inactiveTrackColor: c.accent.withValues(alpha: 0.24),
        thumbColor: c.accent,
        overlayColor: c.accent.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.accent,
        linearTrackColor: c.surfaceHigh,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surfaceHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceHigh,
        contentTextStyle: const TextStyle(color: _onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _onSurfaceVariant,
        textColor: _onSurface,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF49454F),
        thickness: 0.5,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceHigh,
        selectedColor: c.accent.withValues(alpha: 0.24),
        labelStyle: const TextStyle(fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
    );
  }

  // Keep light theme as alias for now
  static ThemeData get lightTheme => forAccent('goldAmber');

  // Keep dark theme as alias for backward compatibility
  static ThemeData get darkTheme => forAccent('goldAmber');
}
