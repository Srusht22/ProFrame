import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/app/state/tools.dart';
import 'package:proframe/app/state/workspace.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

ProviderContainer drawn() {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  container.read(workspaceProvider.notifier)
    ..startDesign(DesignKind.door)
    ..addStroke(
      const [
        StrokeSample(Vec2(0, 0)),
        StrokeSample(Vec2(1600, 0)),
        StrokeSample(Vec2(1600, 2100)),
        StrokeSample(Vec2(0, 2100)),
        StrokeSample(Vec2(0, 0)),
      ],
      tool: Tool.pen,
    )
    ..addStroke(
      const [StrokeSample(Vec2(620, 0)), StrokeSample(Vec2(620, 2100))],
      tool: Tool.pen,
    )
    ..readDrawing();
  return container;
}

/// What the 3D view would draw, built the way the 3D view builds it: from
/// whatever is in the workspace at this moment, with nothing kept.
Mesh asShown(ProviderContainer container) {
  final state = container.read(workspaceProvider);
  return MeshBuilder.build(state.design, openFraction: state.openFraction);
}

void main() {
  group('the model shown is always the design as it stands', () {
    test('moving a bar shows in the model at once', () {
      final container = drawn();
      final controller = container.read(workspaceProvider.notifier);
      final bar = container.read(workspaceProvider).design.dividers.single;

      double barMiddle() {
        var sum = 0.0;
        var count = 0;
        for (final facet in asShown(container).facets) {
          if (facet.elementId != bar.id) continue;
          sum += facet.centre.x;
          count++;
        }
        return sum / count;
      }

      expect(barMiddle(), closeTo(620, 2));
      controller.moveDividerAcross(bar.id, const Vec2(1000, 1000));
      expect(barMiddle(), closeTo(1000, 2));
    });

    test('a section changed from glass to panel shows as a panel', () {
      final container = drawn();
      final controller = container.read(workspaceProvider.notifier);
      final section = container.read(workspaceProvider).design.sections.first;

      expect(
        asShown(container)
            .facets
            .any((f) => f.elementId == section.id && f.role == FacetRole.glazing),
        isTrue,
      );

      controller.setFinish(
        section.id,
        const Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel),
      );

      expect(
        asShown(container)
            .facets
            .any((f) => f.elementId == section.id && f.role == FacetRole.panel),
        isTrue,
      );
      expect(
        asShown(container)
            .facets
            .any((f) => f.elementId == section.id && f.role == FacetRole.glazing),
        isFalse,
      );
    });

    test('an opening set in the drawing appears as a leaf in the model', () {
      final container = drawn();
      final controller = container.read(workspaceProvider.notifier);
      final section = container.read(workspaceProvider).design.sections.first;

      expect(
        asShown(container).facets.any((f) => f.role == FacetRole.sash),
        isFalse,
      );

      controller.setOpening(section.id, OpeningMechanism.hingedRight);

      expect(
        asShown(container)
            .facets
            .any((f) => f.elementId == section.id && f.role == FacetRole.sash),
        isTrue,
      );
    });

    test('a real size typed in the drawing resizes the model', () {
      final container = drawn();
      final controller = container.read(workspaceProvider.notifier);

      double widest() {
        var right = -1e9;
        for (final facet in asShown(container).facets) {
          for (final c in facet.corners) {
            if (c.x > right) right = c.x;
          }
        }
        return right;
      }

      expect(widest(), closeTo(1600, 2));
      controller.setRealWidth(2400);
      expect(widest(), closeTo(2400, 2));
    });

    test('undo puts both views back together', () {
      final container = drawn();
      final controller = container.read(workspaceProvider.notifier);
      final bar = container.read(workspaceProvider).design.dividers.single;

      // Every corner of every face, so nothing that moved can hide behind
      // a count or an overall size that happened not to change.
      String shown() {
        final lines = [
          for (final facet in asShown(container).facets)
            '${facet.elementId}|${facet.corners.map((c) => '${c.x.toStringAsFixed(3)},'
                '${c.y.toStringAsFixed(3)},${c.z.toStringAsFixed(3)}').join(';')}',
        ]..sort();
        return lines.join('\n');
      }

      final before = shown();
      controller
        ..moveDividerAcross(bar.id, const Vec2(1100, 1000))
        ..endGesture();
      expect(shown(), isNot(before));

      controller.undo();
      expect(shown(), before);
      expect(
        container.read(workspaceProvider).design.dividers.single.a.x,
        closeTo(bar.a.x, 0.01),
      );
    });
  });

  group('a change made on the solid reaches the drawing', () {
    test('depth set in the 3D view is the design', () {
      final container = drawn();
      final controller = container.read(workspaceProvider.notifier);

      double thickness() {
        var front = -1e9, back = 1e9;
        for (final facet in asShown(container).facets) {
          for (final c in facet.corners) {
            if (c.z > front) front = c.z;
            if (c.z < back) back = c.z;
          }
        }
        return front - back;
      }

      controller.setDepth(150);
      expect(thickness(), closeTo(150, 0.01));
      expect(container.read(workspaceProvider).design.depthMm, 150);
    });

    test('the frame profile set in the 3D view changes the drawing', () {
      final container = drawn();
      final controller = container.read(workspaceProvider.notifier);

      final before = container.read(workspaceProvider).design.sections
          .reduce((a, b) => a.widthMm > b.widthMm ? a : b)
          .widthMm;

      controller.setProfile(140);

      final after = container.read(workspaceProvider).design.sections
          .reduce((a, b) => a.widthMm > b.widthMm ? a : b)
          .widthMm;
      expect(after, closeTo(before - 80, 1));
    });
  });

  group('selection is shared between the views', () {
    test('a face in the model names a part of the drawing', () {
      final container = drawn();
      final controller = container.read(workspaceProvider.notifier);
      final section = container.read(workspaceProvider).design.sections.last;

      // What a tap in the 3D view does: select whatever the face belongs to.
      final face = asShown(container)
          .facets
          .firstWhere((f) => f.elementId == section.id);
      controller.select(face.elementId);

      final selected = container.read(workspaceProvider).selected;
      expect(selected, isA<SectionElement>());
      expect(selected!.id, section.id);
    });

    test('swinging the leaves open changes no part of the design', () {
      final container = drawn();
      final controller = container.read(workspaceProvider.notifier);
      final section = container.read(workspaceProvider).design.sections.first;
      controller.setOpening(section.id, OpeningMechanism.hingedLeft);

      final before =
          container.read(workspaceProvider).design.toJson().toString();
      controller.setOpenFraction(0.75);

      expect(
        container.read(workspaceProvider).design.toJson().toString(),
        before,
      );
      // But the model being looked at does change.
      expect(container.read(workspaceProvider).openFraction, 0.75);
    });
  });
}
