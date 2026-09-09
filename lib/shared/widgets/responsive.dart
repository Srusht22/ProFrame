import 'package:flutter/widgets.dart';

import '../../core/theme/app_spacing.dart';

/// The three shapes the app takes. Each one is a different arrangement, not a
/// scaled copy of the others (§34).
enum ScreenSize { compact, medium, expanded }

extension ScreenSizeInfo on ScreenSize {
  bool get isCompact => this == ScreenSize.compact;
  bool get isExpanded => this == ScreenSize.expanded;
  bool get isAtLeastMedium => this != ScreenSize.compact;
}

ScreenSize screenSizeOf(BuildContext context) =>
    screenSizeForWidth(MediaQuery.sizeOf(context).width);

ScreenSize screenSizeForWidth(double width) {
  if (width < AppSpacing.breakpointCompact) return ScreenSize.compact;
  if (width < AppSpacing.breakpointExpanded) return ScreenSize.medium;
  return ScreenSize.expanded;
}

/// Builds a different layout per size class.
class ResponsiveLayout extends StatelessWidget {
  final Widget Function(BuildContext context) compact;
  final Widget Function(BuildContext context)? medium;
  final Widget Function(BuildContext context) expanded;

  const ResponsiveLayout({
    super.key,
    required this.compact,
    this.medium,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = screenSizeForWidth(constraints.maxWidth);
        return switch (size) {
          ScreenSize.compact => compact(context),
          ScreenSize.medium => (medium ?? expanded)(context),
          ScreenSize.expanded => expanded(context),
        };
      },
    );
  }
}
