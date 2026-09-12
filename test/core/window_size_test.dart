import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/layout/window_size.dart';

void main() {
  WindowSize sized(double width, double height) =>
      WindowSize(width: width, height: height);

  group('the four widths the spec names', () {
    // Spec section 12D asks for these representative widths by name.
    test('360 is compact', () {
      expect(sized(360, 800).widthClass, WindowWidthClass.compact);
    });

    test('600 is medium', () {
      expect(sized(600, 900).widthClass, WindowWidthClass.medium);
    });

    test('900 is medium', () {
      expect(sized(900, 900).widthClass, WindowWidthClass.medium);
    });

    test('1440 is expanded', () {
      expect(sized(1440, 900).widthClass, WindowWidthClass.expanded);
    });
  });

  group('boundaries', () {
    test('the class changes exactly at the breakpoint, not around it', () {
      expect(sized(599.9, 800).widthClass, WindowWidthClass.compact);
      expect(sized(600, 800).widthClass, WindowWidthClass.medium);
      expect(sized(1023.9, 800).widthClass, WindowWidthClass.medium);
      expect(sized(1024, 800).widthClass, WindowWidthClass.expanded);
    });

    test('only compact lacks room for a side panel', () {
      expect(sized(360, 800).widthClass.hasRoomForSidePanel, isFalse);
      expect(sized(700, 800).widthClass.hasRoomForSidePanel, isTrue);
      expect(sized(1440, 800).widthClass.hasRoomForSidePanel, isTrue);
    });
  });

  group('height is part of the decision, not an afterthought', () {
    test('a phone on its side is recognised as a landscape phone', () {
      // 800x360: wide enough to call medium on width alone, but only 360 tall.
      final phone = sized(800, 360);

      expect(phone.widthClass, WindowWidthClass.medium);
      expect(phone.heightClass, WindowHeightClass.compact);
      expect(phone.isLandscapePhone, isTrue);
      expect(phone.isLandscape, isTrue);
    });

    test('a short desktop window is not a landscape phone', () {
      // Wide enough for the three-pane layout, so the chrome stays.
      final desktop = sized(1440, 400);

      expect(desktop.heightClass, WindowHeightClass.compact);
      expect(desktop.isLandscapePhone, isFalse);
    });

    test('an upright phone is not a landscape phone', () {
      final phone = sized(390, 844);

      expect(phone.heightClass, WindowHeightClass.regular);
      expect(phone.isLandscapePhone, isFalse);
      expect(phone.isLandscape, isFalse);
    });
  });

  group('the size comes from constraints, never from a device name', () {
    test('bounded constraints are read straight through', () {
      final size = WindowSize.fromConstraints(
        const BoxConstraints(maxWidth: 1440, maxHeight: 900),
      );

      expect(size.width, 1440);
      expect(size.widthClass, WindowWidthClass.expanded);
    });

    test('unbounded constraints fall back to compact rather than guessing', () {
      final size = WindowSize.fromConstraints(const BoxConstraints());

      expect(size.widthClass, WindowWidthClass.compact);
      expect(size.heightClass, WindowHeightClass.compact);
    });

    test('a panel is measured by its own width, not the window it is in', () {
      // This is the reason the size comes from constraints: a 320-wide
      // properties panel inside a 1440 window must lay out as compact.
      final panel = WindowSize.fromConstraints(
        const BoxConstraints(maxWidth: 320, maxHeight: 900),
      );

      expect(panel.widthClass, WindowWidthClass.compact);
    });
  });
}
