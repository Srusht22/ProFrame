import 'package:flutter/widgets.dart';

import '../../domain/design_document.dart';
import '../../domain/product/profile_system.dart';

/// How far open each panel is, keyed by panel id, 0 closed to 1 open.
typedef PanelOpenState = Map<String, double>;

/// What a renderer is handed, beyond the design itself.
@immutable
class RenderRequest {
  /// The only thing that describes the product. A renderer never sees the
  /// strokes (spec Phase 3, item 1).
  final DesignDocument design;

  /// The profile system to build from.
  final ProfileSystem profile;

  /// The colour of the product itself, not the app.
  final Color finish;

  final PanelOpenState openPanels;

  /// View transform, owned by the screen so it survives a renderer swap.
  final double zoom;
  final Offset pan;

  /// Called when the user taps a panel in the view.
  final void Function(String panelId)? onPanelTapped;

  const RenderRequest({
    required this.design,
    required this.profile,
    required this.finish,
    this.openPanels = const {},
    this.zoom = 1,
    this.pan = Offset.zero,
    this.onPanelTapped,
  });
}

/// Draws a design.
///
/// The seam between the design and however it is shown. The 2.5D isometric
/// painter implements this today; a real 3D engine — a GPU scene graph, a
/// WebGL view — can implement it tomorrow **without any other layer changing**
/// (spec Phase 3, item 1), because everything upstream deals in
/// [DesignDocument] and everything downstream deals in the widget this
/// returns.
///
/// It is an interface rather than a base class so an implementation is free to
/// extend whatever it needs to.
abstract interface class DesignRenderer {
  /// A name for the view, shown to the user so they know what they are
  /// looking at — "2.5D preview" is an honest label and "3D" would not be.
  String get label;

  /// Whether this renderer can show a panel opening. A renderer that cannot
  /// must say so rather than silently ignoring the request.
  bool get supportsOpeningAnimation;

  /// Builds the view.
  Widget build(BuildContext context, RenderRequest request);
}
