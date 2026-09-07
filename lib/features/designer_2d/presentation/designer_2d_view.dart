import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/configuration/product_configuration.dart';
import 'widgets/technical_drawing_painter.dart';

/// Interactive 2D elevation: zoom, pan, dimension toggle, and PNG export
/// (spec §11, §62 — "Export design").
class Designer2DView extends StatefulWidget {
  final ProductConfiguration config;
  const Designer2DView({super.key, required this.config});

  @override
  State<Designer2DView> createState() => Designer2DViewState();
}

class Designer2DViewState extends State<Designer2DView> {
  bool _showDimensions = true;
  final _repaintKey = GlobalKey();
  final _transformController = TransformationController();

  Future<Uint8List?> exportPng() async {
    final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2.5);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  void _resetView() => _transformController.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(
            children: [
              IconButton(
                tooltip: _showDimensions ? 'Hide measurements' : 'Show measurements',
                icon: Icon(_showDimensions ? Icons.straighten_rounded : Icons.straighten_outlined),
                onPressed: () => setState(() => _showDimensions = !_showDimensions),
              ),
              IconButton(
                tooltip: 'Reset view',
                icon: const Icon(Icons.center_focus_strong_rounded),
                onPressed: _resetView,
              ),
              const Spacer(),
              Text('${widget.config.formattedDimensions()}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: RepaintBoundary(
              key: _repaintKey,
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 6,
                boundaryMargin: const EdgeInsets.all(200),
                child: SizedBox.expand(
                  child: CustomPaint(
                    painter: TechnicalDrawingPainter(
                      config: widget.config,
                      showDimensions: _showDimensions,
                      frameColor: AppColors.brandDarkGreenDeep,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
