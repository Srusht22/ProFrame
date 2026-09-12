import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../domain/design_document.dart';
import '../../domain/product/profile_system.dart';
import '../../domain/rendering/isometric_projection.dart';
import 'design_renderer.dart';

/// Drives the open/close animation and hands the result to a [DesignRenderer].
///
/// The renderer stays a pure function of its request; the tweening lives here,
/// which is why swapping in a different renderer needs no animation code of
/// its own (spec Phase 3, item 1).
///
/// Each panel animates on its own clock, so opening a second sash while the
/// first is still moving does not restart it.
class AnimatedDesignView extends StatefulWidget {
  final DesignRenderer renderer;
  final DesignDocument design;
  final ProfileSystem profile;
  final Color finish;

  /// The panels that should end up open.
  final Set<String> openPanels;

  final double zoom;
  final Offset pan;

  /// Where the camera is.
  final IsometricProjection projection;

  final void Function(String panelId) onPanelTapped;

  const AnimatedDesignView({
    required this.renderer,
    required this.design,
    required this.profile,
    required this.finish,
    required this.openPanels,
    required this.onPanelTapped,
    this.zoom = 1,
    this.pan = Offset.zero,
    this.projection = const IsometricProjection(),
    super.key,
  });

  @override
  State<AnimatedDesignView> createState() => _AnimatedDesignViewState();
}

class _AnimatedDesignViewState extends State<AnimatedDesignView>
    with TickerProviderStateMixin {
  /// One controller per panel that has ever been opened.
  final Map<String, AnimationController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(AnimatedDesignView old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Points every controller at where its panel should be.
  void _sync() {
    for (final panelId in widget.openPanels) {
      _controllerFor(panelId).forward();
    }
    for (final entry in _controllers.entries) {
      if (!widget.openPanels.contains(entry.key)) entry.value.reverse();
    }
    // A panel deleted from the design while open leaves a controller behind.
    final live = widget.design.panels.map((p) => p.id).toSet();
    final stale = _controllers.keys.where((id) => !live.contains(id)).toList();
    for (final id in stale) {
      _controllers.remove(id)?.dispose();
    }
  }

  AnimationController _controllerFor(String panelId) =>
      _controllers.putIfAbsent(panelId, () {
        final controller = AnimationController(
          vsync: this,
          duration: AppDurations.sashSwing,
        );
        // Repaint as it moves. setState is right here: the tween is transient
        // visual state that nothing outside this widget needs.
        controller.addListener(() => setState(() {}));
        return controller;
      });

  @override
  Widget build(BuildContext context) {
    final fractions = <String, double>{
      for (final entry in _controllers.entries)
        if (entry.value.value > 0)
          entry.key: Curves.easeInOutCubic.transform(entry.value.value),
    };

    return widget.renderer.build(
      context,
      RenderRequest(
        design: widget.design,
        profile: widget.profile,
        finish: widget.finish,
        openPanels: fractions,
        zoom: widget.zoom,
        pan: widget.pan,
        projection: widget.projection,
        onPanelTapped: widget.onPanelTapped,
      ),
    );
  }
}
