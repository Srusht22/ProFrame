import 'package:flutter/widgets.dart';

/// How much horizontal room the workspace has.
///
/// Derived from the constraints the widget is actually given, never from a
/// device name or platform check (spec section 8) — a phone app in a resizable
/// window on a tablet gets the layout its width deserves.
enum WindowWidthClass {
  /// One workspace at a time; tabs switch between drawing and 3D, properties
  /// arrive in a bottom sheet.
  compact,

  /// Larger canvas with a collapsible property panel.
  medium,

  /// Tools left, canvas centre, properties right, optionally 2D and 3D
  /// side by side.
  expanded;

  bool get isCompact => this == WindowWidthClass.compact;
  bool get isMedium => this == WindowWidthClass.medium;
  bool get isExpanded => this == WindowWidthClass.expanded;

  /// True where there is room for a persistent side panel.
  bool get hasRoomForSidePanel => this != WindowWidthClass.compact;
}

/// How much vertical room there is.
///
/// A phone held in landscape is wide but only ~360dp tall. Width alone would
/// call that `medium` and hand it a layout with a toolbar above and a panel
/// below, leaving a canvas too short to draw in. Height is therefore a
/// first-class part of the decision (spec section 8, "Landscape phones").
enum WindowHeightClass {
  /// Under [Breakpoints.compactHeight]: chrome must collapse to leave the
  /// canvas usable.
  compact,

  /// Normal upright phone, tablet or desktop window.
  regular;

  bool get isCompact => this == WindowHeightClass.compact;
}

/// The breakpoints, in logical pixels, in one place.
///
/// The width thresholds follow the Material 3 window size classes for compact
/// and medium. The expanded threshold is raised to 1024 rather than Material's
/// 840 because this app's expanded layout puts a tool rail (88) and a
/// properties panel (320) on either side of the canvas: at 840 that leaves
/// about 430 for drawing, which is narrower than the compact layout's own
/// canvas and so would be a downgrade.
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 1024;

  /// Below this height the layout treats the window as a landscape phone.
  static const double compactHeight = 480;

  const Breakpoints._();
}

/// The resolved size classes for a piece of the layout, plus the raw size.
@immutable
class WindowSize {
  final double width;
  final double height;

  const WindowSize({required this.width, required this.height});

  /// Reads the size from [constraints].
  ///
  /// Unbounded constraints fall back to the compact classes: it is the
  /// conservative choice, and a workspace is never laid out inside an
  /// unbounded box in practice.
  factory WindowSize.fromConstraints(BoxConstraints constraints) => WindowSize(
        width: constraints.hasBoundedWidth ? constraints.maxWidth : 0,
        height: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
      );

  WindowWidthClass get widthClass {
    if (width >= Breakpoints.expanded) return WindowWidthClass.expanded;
    if (width >= Breakpoints.medium) return WindowWidthClass.medium;
    return WindowWidthClass.compact;
  }

  WindowHeightClass get heightClass => height < Breakpoints.compactHeight
      ? WindowHeightClass.compact
      : WindowHeightClass.regular;

  bool get isLandscape => width > height;

  /// True for a window that is wide but short — a phone on its side. The
  /// workspace keeps a horizontal arrangement here but sheds vertical chrome.
  bool get isLandscapePhone =>
      heightClass.isCompact && widthClass != WindowWidthClass.expanded;

  @override
  bool operator ==(Object other) =>
      other is WindowSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  String toString() => 'WindowSize(${width}x$height, '
      '${widthClass.name}/${heightClass.name})';
}
