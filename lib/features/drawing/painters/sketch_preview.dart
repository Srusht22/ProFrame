import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/models/sketch.dart';
import 'sketch_painter.dart';

/// The original drawing, scaled to fit — never redrawn, never cleaned up.
///
/// This is the user's own ink, kept exactly as they made it, so they can hold
/// it up against the generated design and judge for themselves.
class SketchPreview extends StatelessWidget {
  final Sketch sketch;
  final EdgeInsets padding;

  const SketchPreview({
    super.key,
    required this.sketch,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    if (sketch.isEmpty) {
      return const ColoredBox(
        color: AppColors.neutralOffWhite,
        child: Center(
          child: Text(
            'Nothing drawn yet',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ),
      );
    }
    return ColoredBox(
      color: AppColors.neutralOffWhite,
      child: CustomPaint(
        painter: _FittedSketchPainter(sketch: sketch, padding: padding),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _FittedSketchPainter extends CustomPainter {
  final Sketch sketch;
  final EdgeInsets padding;

  const _FittedSketchPainter({required this.sketch, required this.padding});

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = sketch.bounds;
    if (bounds.width <= 0 && bounds.height <= 0) return;

    final availableWidth = (size.width - padding.horizontal).clamp(1.0, size.width);
    final availableHeight = (size.height - padding.vertical).clamp(1.0, size.height);
    final scale = [
      availableWidth / (bounds.width <= 0 ? 1 : bounds.width),
      availableHeight / (bounds.height <= 0 ? 1 : bounds.height),
      3.0,
    ].reduce((a, b) => a < b ? a : b);

    canvas.save();
    canvas.translate(
      padding.left + (availableWidth - bounds.width * scale) / 2,
      padding.top + (availableHeight - bounds.height * scale) / 2,
    );
    canvas.scale(scale);
    canvas.translate(-bounds.left, -bounds.top);

    for (final stroke in sketch.strokes) {
      SketchPainter.paintStroke(canvas, stroke);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _FittedSketchPainter oldDelegate) =>
      oldDelegate.sketch != sketch;
}
