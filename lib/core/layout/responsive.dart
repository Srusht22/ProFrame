import 'package:flutter/widgets.dart';

import 'window_size.dart';

/// Builds against the [WindowSize] of the box it is placed in.
///
/// Use this instead of `MediaQuery.of(context).size`: a widget inside a panel
/// should respond to the panel's width, not the window's, and taking the size
/// from constraints is what makes that true (spec section 8).
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, WindowSize size) builder;

  const ResponsiveBuilder({required this.builder, super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) =>
            builder(context, WindowSize.fromConstraints(constraints)),
      );
}

/// Picks one of three layouts by width class.
///
/// [medium] falls back to [compact] and [expanded] falls back to [medium],
/// so a screen only supplies the arrangements it actually has.
class ResponsiveLayout extends StatelessWidget {
  final WidgetBuilder compact;
  final WidgetBuilder? medium;
  final WidgetBuilder? expanded;

  const ResponsiveLayout({
    required this.compact,
    this.medium,
    this.expanded,
    super.key,
  });

  @override
  Widget build(BuildContext context) => ResponsiveBuilder(
        builder: (context, size) => switch (size.widthClass) {
          WindowWidthClass.expanded =>
            (expanded ?? medium ?? compact)(context),
          WindowWidthClass.medium => (medium ?? compact)(context),
          WindowWidthClass.compact => compact(context),
        },
      );
}

/// Caps how far the OS text-size setting scales text inside [child].
///
/// Large text must work (spec section 7), but a 2.0x scale on a landscape
/// phone can push the drawing tools off screen entirely. Clamping to 1.6
/// keeps the app readable at the largest useful setting while guaranteeing the
/// workspace survives; anything beyond that is handled by scrolling the panels
/// rather than shrinking the canvas.
class BoundedTextScale extends StatelessWidget {
  static const double maxScale = 1.6;

  final Widget child;

  const BoundedTextScale({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(maxScaleFactor: maxScale),
      ),
      child: child,
    );
  }
}
