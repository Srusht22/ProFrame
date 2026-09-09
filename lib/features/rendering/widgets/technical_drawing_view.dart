import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/opening_model.dart';
import '../painters/technical_drawing_painter.dart';

/// The 2D technical drawing, pan- and zoom-able, on a paper-like ground.
class TechnicalDrawingView extends StatelessWidget {
  final OpeningModel model;
  final bool showDimensions;
  final bool showLabels;
  final String? highlightCellPath;
  final bool interactive;

  const TechnicalDrawingView({
    super.key,
    required this.model,
    this.showDimensions = true,
    this.showLabels = true,
    this.highlightCellPath,
    this.interactive = true,
  });

  @override
  Widget build(BuildContext context) {
    final painter = CustomPaint(
      painter: TechnicalDrawingPainter(
        model: model,
        showDimensions: showDimensions,
        showLabels: showLabels,
        highlightCellPath: highlightCellPath,
      ),
      child: const SizedBox.expand(),
    );

    final surface = ColoredBox(
      color: AppColors.neutralOffWhite,
      child: Padding(padding: const EdgeInsets.all(12), child: painter),
    );

    if (!interactive) return surface;
    return InteractiveViewer(minScale: 0.5, maxScale: 6, child: surface);
  }
}

/// Small preview used on design cards. Never a stored image — it is redrawn
/// from the model, so a card can never show a stale design.
class DesignThumbnail extends StatelessWidget {
  final OpeningModel model;

  const DesignThumbnail({super.key, required this.model});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.neutralOffWhite,
        child: CustomPaint(
          painter: TechnicalDrawingPainter(
            model: model,
            showDimensions: false,
            showLabels: false,
            margin: 10,
          ),
          child: const SizedBox.expand(),
        ),
      );
}
