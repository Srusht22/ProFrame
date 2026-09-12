import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/design/app_theme.dart';
import 'package:proframe/core/design/contrast.dart';
import 'package:proframe/core/design/tokens.dart';

void main() {
  group('the brand colours are exactly the ones specified', () {
    // Spec section 7 gives these two values. A seeded ColorScheme would shift
    // them, so this test is what stops that happening by accident.
    test('cream is #ffefb3', () {
      expect(AppColors.cream, const Color(0xFFFFEFB3));
    });

    test('deep green is #013e37', () {
      expect(AppColors.deepGreen, const Color(0xFF013E37));
    });

    test('the theme uses them for the primary pairing', () {
      final scheme = AppTheme.colorScheme;

      expect(scheme.primary, AppColors.deepGreen);
      expect(scheme.onPrimary, AppColors.cream);
    });

    test('the scaffold is cream', () {
      expect(AppTheme.light().scaffoldBackgroundColor, AppColors.cream);
    });
  });

  group('contrast', () {
    test('cream on deep green clears AAA, so it is safe for body text', () {
      final ratio = Contrast.ratio(AppColors.cream, AppColors.deepGreen);

      expect(ratio, greaterThan(Contrast.aaa));
      expect(ratio, closeTo(10.45, 0.05));
    });

    test('deep green on every neutral surface clears AA', () {
      for (final surface in [
        AppColors.cream,
        AppColors.surface,
        AppColors.canvasSurface,
      ]) {
        expect(
          Contrast.ratio(AppColors.deepGreen, surface),
          greaterThan(Contrast.aa),
          reason: 'deep green must be readable on $surface',
        );
      }
    });

    test('muted text still clears AA on the surfaces it is used on', () {
      // Muted text is for secondary labels, but secondary is not the same as
      // unreadable.
      for (final surface in [AppColors.surface, AppColors.canvasSurface]) {
        expect(
          Contrast.ratio(AppColors.mutedText, surface),
          greaterThan(Contrast.aa),
          reason: 'muted text must be readable on $surface',
        );
      }
    });

    test('status colours clear AA on their own backgrounds', () {
      expect(
        Contrast.ratio(AppColors.danger, AppColors.dangerSurface),
        greaterThan(Contrast.aa),
      );
      expect(
        Contrast.ratio(AppColors.caution, AppColors.cautionSurface),
        greaterThan(Contrast.aa),
      );
    });

    test('the reference values are right', () {
      // Sanity-checks the implementation itself against the two ratios
      // everyone knows.
      expect(
        Contrast.ratio(const Color(0xFF000000), const Color(0xFFFFFFFF)),
        closeTo(21, 0.01),
      );
      expect(
        Contrast.ratio(const Color(0xFF777777), const Color(0xFFFFFFFF)),
        closeTo(4.48, 0.02),
      );
    });

    test('the readable-label helper picks the better of two', () {
      const options = [Color(0xFF000000), Color(0xFFFFFFFF)];

      expect(Contrast.mostReadableOn(const Color(0xFF111111), options),
          const Color(0xFFFFFFFF));
      expect(Contrast.mostReadableOn(const Color(0xFFEEEEEE), options),
          const Color(0xFF000000));
    });
  });

  group('touch targets', () {
    test('the floor is 48 logical pixels', () {
      expect(AppSizing.minTouchTarget, 48);
    });

    test('every themed button is at least that tall', () {
      final theme = AppTheme.light();
      final styles = <String, ButtonStyle?>{
        'filled': theme.filledButtonTheme.style,
        'outlined': theme.outlinedButtonTheme.style,
        'text': theme.textButtonTheme.style,
        'icon': theme.iconButtonTheme.style,
      };

      styles.forEach((name, style) {
        final size = style?.minimumSize?.resolve({});
        expect(size, isNotNull, reason: '$name button must set a minimum size');
        expect(
          size!.height,
          greaterThanOrEqualTo(AppSizing.minTouchTarget),
          reason: '$name button is under the 48dp floor',
        );
      });
    });
  });
}
