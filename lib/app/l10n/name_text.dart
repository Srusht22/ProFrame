import 'package:flutter/material.dart';

/// A name somebody typed — a design's, a customer's — shown as they typed
/// it, in whichever language the screen is in.
///
/// A name is the user's and is never translated, so an English name can
/// stand in a Kurdish title. Laid out right to left with the screen, it was
/// cut short at its left-hand end — which, for English, is its start — so
/// *Basement Door - New PVC* read as *…New PVC*. Here a name is laid out in
/// its own direction, the one its first letter has, and placed at the
/// start of the line as the screen reads: an English name in a Kurdish
/// title is right-aligned and, where it must be cut, is cut at its end. It
/// may take a second line before it is cut at all; where [whole] is said,
/// a long press or a hover shows all of it. (Not on a card, whose long
/// press is the card's own.)
class NameText extends StatelessWidget {
  final String name;
  final TextStyle? style;
  final int maxLines;

  /// Whether the whole name is shown on a long press or a hover.
  final bool whole;

  const NameText(
    this.name, {
    super.key,
    this.style,
    this.maxLines = 1,
    this.whole = false,
  });

  /// The direction [name] reads in: its first letter's, or the screen's
  /// where it has no letter of either kind.
  static TextDirection directionOf(String name, TextDirection screen) {
    for (final c in name.runes) {
      if (_rightToLeft(c)) return TextDirection.rtl;
      if (_leftToRight(c)) return TextDirection.ltr;
    }
    return screen;
  }

  static bool _rightToLeft(int c) =>
      (c >= 0x0590 && c <= 0x08FF) ||
      (c >= 0xFB1D && c <= 0xFDFF) ||
      (c >= 0xFE70 && c <= 0xFEFF);

  static bool _leftToRight(int c) =>
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      (c >= 0xC0 && c <= 0x24F) ||
      (c >= 0x370 && c <= 0x52F);

  @override
  Widget build(BuildContext context) {
    final screen = Directionality.of(context);
    final own = directionOf(name, screen);
    final text = Text(
      name,
      textDirection: own,
      // At the start of the line as the screen reads it, whichever way
      // the name itself runs.
      textAlign: screen == TextDirection.rtl ? TextAlign.right : TextAlign.left,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
    return whole
        ? Tooltip(message: name, excludeFromSemantics: true, child: text)
        : text;
  }
}

