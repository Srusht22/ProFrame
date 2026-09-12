import 'package:flutter/material.dart';

import '../../core/design/tokens.dart';
import '../../core/i18n/strings.dart';
import '../../domain/rendering/scene_builder.dart';
import 'design_renderer.dart';
import 'scene_painter.dart';
import 'surface_shading.dart';

/// The 2.5D isometric view.
///
/// One of possibly many [DesignRenderer]s. It builds a scene from the design,
/// projects it, and paints it — and it is the *only* file that has to be
/// replaced to put a real 3D engine behind the same screen.
///
/// It is called a 2.5D preview rather than 3D everywhere the user can see,
/// because that is what it is (spec section 9: do not describe a rendering
/// library as something it is not).
class IsometricRenderer implements DesignRenderer {
  const IsometricRenderer();

  @override
  String labelIn(AppStrings strings) => strings(T.preview25d);

  @override
  bool get supportsOpeningAnimation => true;

  @override
  Widget build(BuildContext context, RenderRequest request) =>
      _IsometricView(request: request);
}

class _IsometricView extends StatelessWidget {
  final RenderRequest request;

  const _IsometricView({required this.request});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Built from the design and nothing else (spec Phase 3, item 1).
    final scene = SceneBuilder.build(
      request.design,
      openFractions: request.openPanels,
      profile: request.profile,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = SceneViewport.fit(
          scene,
          constraints.biggest,
          projection: request.projection,
          zoom: request.zoom,
          pan: request.pan,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final panelId = viewport.panelAt(scene, details.localPosition);
            if (panelId != null) request.onPanelTapped?.call(panelId);
          },
          child: CustomPaint(
            size: constraints.biggest,
            painter: ScenePainter(
              scene: scene,
              viewport: viewport,
              // Every tone is derived from the finish the user chose; none is
              // hardcoded (spec Phase 3, item 2).
              shading: SurfaceShading(request.finish),
              glassColor: AppColors.glassTint,
              glassHighlight: AppColors.glassHighlight,
              glyphColor: AppColors.deepGreen,
              meshColor: AppColors.deepGreen.withValues(alpha: 0.45),
              noteMarkerColor: AppColors.deepGreen,
              noteMarkerInk: scheme.onPrimary,
              hardwareColor: AppColors.hardware,
              hardwareEdgeColor: AppColors.hardwareEdge,
            ),
          ),
        );
      },
    );
  }
}
