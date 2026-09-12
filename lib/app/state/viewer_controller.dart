import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/tokens.dart';

/// What the viewer is showing: which panels are open, and where the camera is.
///
/// Held in a provider rather than in the screen's `State`, so it survives a
/// rotation and a trip back to the canvas and forward again — the round trip
/// the spec requires to work indefinitely (spec Phase 3, item 4).
class ViewerState {
  /// Panels the user has opened, by id. A panel not listed is closed.
  final Set<String> openPanels;

  final double zoom;
  final Offset pan;

  const ViewerState({
    this.openPanels = const {},
    this.zoom = 1,
    this.pan = Offset.zero,
  });

  bool isOpen(String panelId) => openPanels.contains(panelId);

  ViewerState copyWith({Set<String>? openPanels, double? zoom, Offset? pan}) =>
      ViewerState(
        openPanels: openPanels ?? this.openPanels,
        zoom: zoom ?? this.zoom,
        pan: pan ?? this.pan,
      );
}

/// Owns the viewer's camera and which panels are open.
///
/// The *animation* between open and closed is not here — it belongs to the
/// widget, because it is transient visual state that nothing else needs and
/// that should not survive a rebuild. What survives is the destination: which
/// panels the user has chosen to have open.
class ViewerController extends Notifier<ViewerState> {
  @override
  ViewerState build() => const ViewerState();

  /// Opens a closed panel or closes an open one.
  ///
  /// Callers must only pass an opening (Z) panel: a fixed one has no motion,
  /// and the spec requires CH panels to stay put during an animation
  /// (spec section 3E).
  void toggle(String panelId) {
    final open = {...state.openPanels};
    if (!open.remove(panelId)) open.add(panelId);
    state = state.copyWith(openPanels: open);
  }

  void closeAll() => state = state.copyWith(openPanels: const {});

  /// Drops any panel that is no longer in the design.
  ///
  /// A panel id can disappear when the user goes back to the canvas and moves
  /// a divider, which merges two panels into a new one. Without this the
  /// viewer would hold an id forever and the "close all" button would look
  /// enabled with nothing to close.
  void retainOnly(Iterable<String> livePanelIds) {
    final live = livePanelIds.toSet();
    final kept = state.openPanels.where(live.contains).toSet();
    if (kept.length == state.openPanels.length) return;
    state = state.copyWith(openPanels: kept);
  }

  void setZoom(double zoom) => state = state.copyWith(
        zoom: zoom.clamp(AppViewerMetrics.minZoom, AppViewerMetrics.maxZoom),
      );

  void panBy(Offset delta) => state = state.copyWith(pan: state.pan + delta);

  void resetView() => state = state.copyWith(zoom: 1, pan: Offset.zero);
}

final viewerControllerProvider =
    NotifierProvider<ViewerController, ViewerState>(ViewerController.new);
