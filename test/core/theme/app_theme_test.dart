import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jusplay/core/theme/app_theme.dart';

void main() {
  group('AppTheme.forAccent', () {
    test('goldAmber returns amber primary', () {
      final theme = AppTheme.forAccent('goldAmber');
      expect(theme.colorScheme.primary, const Color(0xFFF59E0B));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0A0A0A));
    });

    test('cyanTeal returns cyan primary', () {
      final theme = AppTheme.forAccent('cyanTeal');
      expect(theme.colorScheme.primary, const Color(0xFF06B6D4));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF030A0A));
    });

    test('coralOrange returns orange primary', () {
      final theme = AppTheme.forAccent('coralOrange');
      expect(theme.colorScheme.primary, const Color(0xFFF97316));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0A0500));
    });

    test('oledWhite returns white primary on pure black', () {
      final theme = AppTheme.forAccent('oledWhite');
      expect(theme.colorScheme.primary, const Color(0xFFFFFFFF));
      expect(theme.scaffoldBackgroundColor, const Color(0xFF000000));
    });

    test('unknown key falls back to goldAmber', () {
      final theme = AppTheme.forAccent('invalid');
      expect(theme.colorScheme.primary, const Color(0xFFF59E0B));
    });

    test('AppTheme.themeConfigs exposes display names', () {
      expect(AppTheme.themeConfigs['goldAmber']!.displayName, 'Dark + Gold/Amber');
      expect(AppTheme.themeConfigs.length, 4);
    });
  });
}
