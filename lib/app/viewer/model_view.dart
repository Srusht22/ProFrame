import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/solid/camera.dart';
import '../../domain/solid/mesh_builder.dart';
import '../state/workspace.dart';
import '../theme/app_theme.dart';

/// The model, turned by dragging.
///
/// Tapping a face picks the part of the design that face came from, so the
/// 3D view is another way into the same design rather than a picture of it.
class ModelView extends ConsumerStatefulWidget {
  const ModelView({super.key});

  @override
  ConsumerState<ModelView> createState() => _ModelViewState();
}

class _ModelViewState extends ConsumerState<ModelView> {
  Offset? _from;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(workspaceProvider);
    final controller = ref.read(workspaceProvider.notifier);

    if (state.design.frame == null) {
      return const _NothingYet();
    }

    final mesh = MeshBuilder.build(
      state.design,
      openFraction: state.openFraction,
    );
    final faces = state.camera.project(mesh);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final painter = ModelPainter(
          faces: faces,
          size: size,
          selectedId: state.selectedId,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) => _from = details.localPosition,
          onPanUpdate: (details) {
            final from = _from ?? details.localPosition;
            final delta = details.localPosition - from;
            _from = details.localPosition;
            // Kept well inside a right angle. Past about fifty degrees a
            // window is being looked at edge-on, which tells the user
            // nothing and reads as the model falling over.
            controller.turnCamera(
              turn: (state.camera.turnDegrees + delta.dx * 0.22)
                  .clamp(-52.0, 52.0),
              tilt: (state.camera.tiltDegrees - delta.dy * 0.14)
                  .clamp(-28.0, 28.0),
            );
          },
          onPanEnd: (_) => _from = null,
          onTapUp: (details) {
            final id = painter.elementAt(details.localPosition);
            controller.select(id);
          },
          child: CustomPaint(size: size, painter: painter),
        );
      },
    );
  }
}

/// Paints the projected faces, far ones first.
class ModelPainter extends CustomPainter {
  final List<ProjectedFacet> faces;
  final Size size;
  final String? selectedId;

  late final double _scale;
  late final Offset _centre;

  ModelPainter({
    required this.faces,
    required this.size,
    this.selectedId,
  }) {
    var left = double.infinity, right = -double.infinity;
    var top = double.infinity, bottom = -double.infinity;
    for (final face in faces) {
      for (final c in face.corners) {
        left = math.min(left, c.x);
        right = math.max(right, c.x);
        top = math.min(top, c.y);
        bottom = math.max(bottom, c.y);
      }
    }
    if (!left.isFinite) {
      _scale = 1;
      _centre = Offset.zero;
      return;
    }
    final width = math.max(right - left, 1.0);
    final height = math.max(bottom - top, 1.0);
    _scale = math.min(size.width * 0.82 / width, size.height * 0.82 / height);
    _centre = Offset(
      size.width / 2 - (left + width / 2) * _scale,
      size.height / 2 - (top + height / 2) * _scale,
    );
  }

  Offset _place(double x, double y) =>
      Offset(_centre.dx + x * _scale, _centre.dy + y * _scale);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          const [Color(0xFFF7F8F7), Color(0xFFE4E9E7)],
        ),
    );

    if (faces.isEmpty) return;

    // A soft shadow on the ground, so the thing sits somewhere rather than
    // floating.
    var lowest = -double.infinity;
    var left = double.infinity, right = -double.infinity;
    for (final face in faces) {
      for (final c in face.corners) {
        lowest = math.max(lowest, c.y);
        left = math.min(left, c.x);
        right = math.max(right, c.x);
      }
    }
    final ground = _place((left + right) / 2, lowest);
    canvas.drawOval(
      Rect.fromCenter(
        center: ground + const Offset(6, 10),
        width: (right - left) * _scale * 0.95,
        height: math.max(12, (right - left) * _scale * 0.09),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.14)
        ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 14),
    );

    for (final face in faces) {
      final path = Path();
      final first = _place(face.corners.first.x, face.corners.first.y);
      path.moveTo(first.dx, first.dy);
      for (final corner in face.corners.skip(1)) {
        final at = _place(corner.x, corner.y);
        path.lineTo(at.dx, at.dy);
      }
      path.close();

      final base = Color(face.source.colour);
      final lit = Color.from(
        alpha: base.a,
        red: (base.r * face.light).clamp(0.0, 1.0),
        green: (base.g * face.light).clamp(0.0, 1.0),
        blue: (base.b * face.light).clamp(0.0, 1.0),
      );
      final opacity = 1 - face.source.transparency;

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = lit.withValues(alpha: opacity.clamp(0.12, 1.0)),
      );

      // Glass is mostly what it reflects. Without this it is a hole showing
      // the dark inside of the frame, which reads as grey metal rather than
      // as a pane.
      if (face.source.transparency > 0.2) {
        final bounds = path.getBounds();
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..shader = ui.Gradient.linear(
              bounds.topLeft,
              bounds.bottomRight,
              [
                const Color(0xFFEAF3F8)
                    .withValues(alpha: 0.72 * face.source.transparency),
                const Color(0xFFBFD4DE)
                    .withValues(alpha: 0.34 * face.source.transparency),
                const Color(0xFFE8F1F4)
                    .withValues(alpha: 0.52 * face.source.transparency),
              ],
              const [0, 0.55, 1],
            ),
        );
      }

      // A highlight on a glossy face, which is what makes aluminium read as
      // metal rather than as painted board.
      if (face.source.gloss > 0.4 && face.light > 0.72) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.fill
            ..color = Colors.white
                .withValues(alpha: (face.source.gloss - 0.4) * 0.3),
        );
      }

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.7
          ..color = Colors.black.withValues(alpha: 0.16),
      );

      if (face.elementId == selectedId) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..color = AppTheme.selection,
        );
      }
    }
  }

  /// Which part of the design is under [pixel] — the nearest face, since the
  /// list is painted far to near.
  String? elementAt(Offset pixel) {
    for (final face in faces.reversed) {
      final path = Path();
      final first = _place(face.corners.first.x, face.corners.first.y);
      path.moveTo(first.dx, first.dy);
      for (final corner in face.corners.skip(1)) {
        final at = _place(corner.x, corner.y);
        path.lineTo(at.dx, at.dy);
      }
      path.close();
      if (path.contains(pixel)) return face.elementId;
    }
    return null;
  }

  @override
  bool shouldRepaint(ModelPainter old) =>
      old.faces.length != faces.length ||
      old.selectedId != selectedId ||
      old.size != size ||
      (faces.isNotEmpty &&
          old.faces.isNotEmpty &&
          old.faces.first.depth != faces.first.depth);
}

class _NothingYet extends StatelessWidget {
  const _NothingYet();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_in_ar_outlined,
                  size: 44, color: AppTheme.muted),
              const SizedBox(height: 14),
              Text(
                'Nothing to show yet',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Draw an outline and read the drawing. The model is built '
                'from your lines — there is no stock model to show in the '
                'meantime.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      );
}
