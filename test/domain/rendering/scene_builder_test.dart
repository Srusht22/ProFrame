import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/design_document.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/panel.dart';
import 'package:proframe/domain/panel_divider.dart';
import 'package:proframe/domain/panel_note.dart';
import 'package:proframe/domain/product/infill.dart';
import 'package:proframe/domain/product/opening.dart';
import 'package:proframe/domain/product/product_basics.dart';
import 'package:proframe/domain/product/profile_system.dart';
import 'package:proframe/domain/rendering/point3.dart';
import 'package:proframe/domain/rendering/scene.dart';
import 'package:proframe/domain/rendering/scene_builder.dart';

/// A 1200 x 900 window, one whole panel, unless [panels] says otherwise.
DesignDocument window({
  List<Panel>? panels,
  List<PanelDivider> dividers = const [],
  FrameMaterial material = FrameMaterial.pvc,
}) {
  final outline = Polygon.rectangle(width: 1200, height: 900);
  return DesignDocument.blank(
    id: 'd1',
    category: ProductCategory.window,
    material: material,
    now: DateTime.utc(2026, 9, 12),
  ).copyWith(
    outline: outline,
    dividers: dividers,
    panels: panels ?? [Panel.fixed(id: 'p1', boundary: outline)],
  );
}

Panel sash(
  OpeningMechanism mechanism, {
  HingeSide hinge = HingeSide.left,
  OpeningDirection direction = OpeningDirection.inward,
  String id = 'p1',
  Polygon? boundary,
}) =>
    Panel.opening(
      id: id,
      boundary: boundary ?? Polygon.rectangle(width: 1200, height: 900),
      opening: OpeningSpec(
        mechanism: mechanism,
        hingeSide: hinge,
        direction: direction,
        isConfirmed: true,
      ),
    );

/// The four corners of the face belonging to [panelId].
List<Point3> panelFace(RenderScene scene, String panelId) => scene.faces
    .firstWhere(
      (f) =>
          f.panelId == panelId &&
          (f.role == PartRole.glass || f.role == PartRole.panel),
    )
    .corners;

void main() {
  group('the frame is built from the real profile', () {
    test('a design with no outline produces nothing', () {
      final blank = DesignDocument.blank(
        id: 'd',
        category: ProductCategory.window,
        material: FrameMaterial.pvc,
      );

      expect(SceneBuilder.build(blank).isEmpty, isTrue);
    });

    test('four frame members are built, each with depth', () {
      final scene = SceneBuilder.build(window());

      final frameFaces =
          scene.faces.where((f) => f.role == PartRole.frame).toList();
      // Four members, each contributing a front face and two depth faces.
      expect(frameFaces.where((f) => f.kind == FaceKind.front), hasLength(4));
      expect(frameFaces.where((f) => f.kind != FaceKind.front), hasLength(8));
    });

    test('the frame corners are exactly the outline the user confirmed', () {
      final scene = SceneBuilder.build(window());

      final head = scene.faces.firstWhere(
        (f) => f.role == PartRole.frame && f.kind == FaceKind.front,
      );

      // The head runs the full width at the top, one frame face deep.
      expect(head.corners[0], const Point3(0, 0, 0));
      expect(head.corners[1].x, 1200);
      expect(head.corners[2].y, GenericProfiles.pvcCasement.frameFaceMm);
    });

    test('PVC reads thicker than aluminium, from the Phase 1 profile data', () {
      // Spec Phase 3, item 2: the material must be visible in the drawing.
      final pvc = SceneBuilder.build(window());
      final aluminium =
          SceneBuilder.build(window(material: FrameMaterial.aluminium));

      double frameDepth(RenderScene scene) => scene.faces
          .where((f) => f.role == PartRole.frame)
          .expand((f) => f.corners)
          .map((p) => p.z)
          .reduce(math.max);
      double faceWidth(RenderScene scene) => scene.faces
          .firstWhere((f) => f.role == PartRole.frame && f.kind == FaceKind.front)
          .corners[2]
          .y;

      expect(frameDepth(pvc), GenericProfiles.pvcCasement.frameDepthMm);
      expect(
        frameDepth(aluminium),
        GenericProfiles.aluminiumCasement.frameDepthMm,
      );
      expect(frameDepth(pvc), greaterThan(frameDepth(aluminium)));
      expect(faceWidth(pvc), greaterThan(faceWidth(aluminium)));
    });

    test('an explicit profile overrides the material default', () {
      final scene = SceneBuilder.build(
        window(),
        profile: GenericProfiles.aluminiumCasement,
      );

      expect(
        scene.faces
            .where((f) => f.role == PartRole.frame)
            .expand((f) => f.corners)
            .map((p) => p.z)
            .reduce(math.max),
        GenericProfiles.aluminiumCasement.frameDepthMm,
      );
    });
  });

  group('dividers land where the model says', () {
    test('a vertical divider is centred on its own line', () {
      final scene = SceneBuilder.build(window(
        dividers: const [
          PanelDivider(
            id: 'd1',
            start: Point2(400, 0),
            end: Point2(400, 900),
            spansFullFrame: true,
          ),
        ],
      ));

      final divider = scene.faces.firstWhere(
        (f) => f.role == PartRole.divider && f.kind == FaceKind.front,
      );
      final half = GenericProfiles.pvcCasement.dividerFaceMm / 2;

      expect(divider.corners[0].x, 400 - half);
      expect(divider.corners[1].x, 400 + half);
      expect(divider.corners[0].y, 0);
      expect(divider.corners[2].y, 900);
    });

    test('a horizontal divider runs across, not down', () {
      final scene = SceneBuilder.build(window(
        dividers: const [
          PanelDivider(
            id: 'd1',
            start: Point2(0, 300),
            end: Point2(1200, 300),
            spansFullFrame: true,
          ),
        ],
      ));

      final divider = scene.faces.firstWhere(
        (f) => f.role == PartRole.divider && f.kind == FaceKind.front,
      );
      final half = GenericProfiles.pvcCasement.dividerFaceMm / 2;

      expect(divider.corners[0].x, 0);
      expect(divider.corners[1].x, 1200);
      expect(divider.corners[0].y, 300 - half);
      expect(divider.corners[2].y, 300 + half);
    });

    test('a partial divider stops where it was drawn', () {
      // Spec section 4: a T-junction is not completed into a full cross.
      final scene = SceneBuilder.build(window(
        dividers: const [
          PanelDivider(
            id: 'd1',
            start: Point2(600, 0),
            end: Point2(600, 400),
            spansFullFrame: false,
          ),
        ],
      ));

      final divider = scene.faces.firstWhere(
        (f) => f.role == PartRole.divider && f.kind == FaceKind.front,
      );

      expect(divider.corners[2].y, 400);
    });
  });

  group('panel rectangles sit at the drawn fractions', () {
    test('two unequal panels keep their proportions', () {
      final scene = SceneBuilder.build(window(
        panels: [
          Panel.fixed(
            id: 'left',
            boundary: Polygon.rectangle(width: 400, height: 900),
          ),
          Panel.fixed(
            id: 'right',
            boundary: Polygon.rectangle(
              width: 800,
              height: 900,
              topLeft: const Point2(400, 0),
            ),
          ),
        ],
      ));

      final left = panelFace(scene, 'left');
      final right = panelFace(scene, 'right');
      final inset = GenericProfiles.pvcCasement.frameFaceMm / 2;

      expect(left.first.x, 0 + inset);
      expect(left[1].x, 400 - inset);
      expect(right.first.x, 400 + inset);
      expect(right[1].x, 1200 - inset);
      // One third to two thirds, as drawn.
      final leftWidth = left[1].x - left[0].x;
      final rightWidth = right[1].x - right[0].x;
      expect(leftWidth / (leftWidth + rightWidth), closeTo(1 / 3, 0.02));
    });

    test('an empty panel has no glass to draw', () {
      // Spec Phase 3, item 2: فارغ is visually distinct.
      final scene = SceneBuilder.build(window(
        panels: [
          Panel.fixed(
            id: 'p1',
            boundary: Polygon.rectangle(width: 1200, height: 900),
          ).copyWith(isEmpty: true),
        ],
      ));

      expect(
        scene.faces.where(
          (f) => f.role == PartRole.glass || f.role == PartRole.panel,
        ),
        isEmpty,
      );
      // The frame around it is still there.
      expect(scene.faces.where((f) => f.role == PartRole.frame), isNotEmpty);
    });

    test('a solid panel is a panel face, not a glass one', () {
      final scene = SceneBuilder.build(window(
        panels: [
          Panel.fixed(
            id: 'p1',
            boundary: Polygon.rectangle(width: 1200, height: 900),
            infill: const SolidPanel(),
          ),
        ],
      ));

      expect(scene.faces.where((f) => f.role == PartRole.panel), hasLength(1));
      expect(scene.faces.where((f) => f.role == PartRole.glass), isEmpty);
    });

    test('a mesh panel gets a hatch over its glass', () {
      final scene = SceneBuilder.build(window(
        panels: [
          Panel.fixed(
            id: 'p1',
            boundary: Polygon.rectangle(width: 1200, height: 900),
          ).copyWith(hasMesh: true),
        ],
      ));

      expect(scene.lines.where((l) => l.role == PartRole.mesh), isNotEmpty);
    });

    test('an empty panel gets no mesh, because there is nothing to screen', () {
      final scene = SceneBuilder.build(window(
        panels: [
          Panel.fixed(
            id: 'p1',
            boundary: Polygon.rectangle(width: 1200, height: 900),
          ).copyWith(hasMesh: true, isEmpty: true),
        ],
      ));

      expect(scene.lines.where((l) => l.role == PartRole.mesh), isEmpty);
    });

    test('a panel with a note gets a marker', () {
      final scene = SceneBuilder.build(window(
        panels: [
          Panel.fixed(
            id: 'p1',
            boundary: Polygon.rectangle(width: 1200, height: 900),
          ).copyWith(
            notes: const [PanelNote(id: 'n1', text: 'توري')],
          ),
        ],
      ));

      expect(
        scene.faces.where((f) => f.role == PartRole.noteMarker),
        hasLength(1),
      );
    });
  });

  group('opening symbols', () {
    test('a CH panel gets none at all', () {
      // Spec Phase 3, item 2.
      final scene = SceneBuilder.build(window());

      expect(
        scene.lines.where((l) => l.role == PartRole.openingGlyph),
        isEmpty,
      );
    });

    test('a Z panel gets a dashed glyph', () {
      final scene =
          SceneBuilder.build(window(panels: [sash(OpeningMechanism.hinged)]));

      final glyphs =
          scene.lines.where((l) => l.role == PartRole.openingGlyph).toList();
      expect(glyphs, isNotEmpty);
      expect(glyphs.every((l) => l.dashed), isTrue);
    });

    test('the glyph points at the hinge edge, whichever side that is', () {
      for (final (hinge, expectApexNear) in [
        (HingeSide.left, 0.0),
        (HingeSide.right, 1200.0),
      ]) {
        final scene = SceneBuilder.build(
          window(panels: [sash(OpeningMechanism.hinged, hinge: hinge)]),
        );
        final glyphs = scene.lines
            .where((l) => l.role == PartRole.openingGlyph)
            .toList();

        // Both dashes converge on the apex, which sits on the hinge edge.
        expect(glyphs, hasLength(2));
        expect(glyphs[0].to.x, closeTo(glyphs[1].to.x, 0.001));
        expect(
          glyphs[0].to.x,
          closeTo(expectApexNear, 100),
          reason: 'apex should be on the $hinge edge',
        );
      }
    });

    test('a tilt glyph points at the bottom, because it is bottom-hung', () {
      final scene =
          SceneBuilder.build(window(panels: [sash(OpeningMechanism.tilt)]));

      final glyphs =
          scene.lines.where((l) => l.role == PartRole.openingGlyph).toList();
      expect(glyphs, hasLength(2));
      expect(glyphs[0].to.y, closeTo(glyphs[1].to.y, 0.001));
      expect(glyphs[0].to.y, greaterThan(450));
    });

    test('a sliding glyph is an arrow pointing the way it travels', () {
      final left = SceneBuilder.build(
        window(panels: [sash(OpeningMechanism.slidingLeft)]),
      );
      final right = SceneBuilder.build(
        window(panels: [sash(OpeningMechanism.slidingRight)]),
      );

      // A shaft plus two barbs, both directions.
      expect(
        left.lines.where((l) => l.role == PartRole.openingGlyph),
        hasLength(3),
      );
      expect(
        right.lines.where((l) => l.role == PartRole.openingGlyph),
        hasLength(3),
      );
    });
  });

  group('opening animation', () {
    test('closed is exactly the panel rectangle', () {
      final scene = SceneBuilder.build(
        window(panels: [sash(OpeningMechanism.hinged)]),
        openFractions: const {'p1': 0},
      );

      final face = panelFace(scene, 'p1');
      expect(face[0].y, face[1].y);
      expect(face[0].z, face[1].z);
    });

    test('a left-hinged sash keeps its hinge edge exactly still', () {
      final closed = panelFace(
        SceneBuilder.build(window(panels: [sash(OpeningMechanism.hinged)])),
        'p1',
      );
      final open = panelFace(
        SceneBuilder.build(
          window(panels: [sash(OpeningMechanism.hinged)]),
          openFractions: const {'p1': 1},
        ),
        'p1',
      );

      // Hinge edge (corners 0 and 3) unchanged.
      expect(open[0], closed[0]);
      expect(open[3], closed[3]);
      // Free edge has swung: nearer the hinge, and deeper.
      expect(open[1].x, lessThan(closed[1].x));
      expect(open[1].z, greaterThan(closed[1].z));
    });

    test('a right-hinged sash keeps its right edge still', () {
      final panels = [sash(OpeningMechanism.hinged, hinge: HingeSide.right)];
      final closed = panelFace(SceneBuilder.build(window(panels: panels)), 'p1');
      final open = panelFace(
        SceneBuilder.build(window(panels: panels),
            openFractions: const {'p1': 1}),
        'p1',
      );

      expect(open[1], closed[1]);
      expect(open[2], closed[2]);
      expect(open[0].x, greaterThan(closed[0].x));
    });

    test('outward opening comes towards the viewer, inward goes away', () {
      List<Point3> faceFor(OpeningDirection direction) => panelFace(
            SceneBuilder.build(
              window(
                panels: [sash(OpeningMechanism.hinged, direction: direction)],
              ),
              openFractions: const {'p1': 1},
            ),
            'p1',
          );

      final inward = faceFor(OpeningDirection.inward);
      final outward = faceFor(OpeningDirection.outward);

      expect(inward[1].z, greaterThan(inward[0].z));
      expect(outward[1].z, lessThan(outward[0].z));
    });

    test('a tilt keeps the bottom edge down and lifts the top inward', () {
      final panels = [sash(OpeningMechanism.tilt)];
      final closed = panelFace(SceneBuilder.build(window(panels: panels)), 'p1');
      final open = panelFace(
        SceneBuilder.build(window(panels: panels),
            openFractions: const {'p1': 1}),
        'p1',
      );

      // Bottom corners unmoved.
      expect(open[2], closed[2]);
      expect(open[3], closed[3]);
      // Top edge has gone back into the room.
      expect(open[0].z, greaterThan(closed[0].z));
      expect(open[1].z, greaterThan(closed[1].z));
    });

    test('a sliding sash keeps its size and moves sideways', () {
      final panels = [sash(OpeningMechanism.slidingRight)];
      final closed = panelFace(SceneBuilder.build(window(panels: panels)), 'p1');
      final open = panelFace(
        SceneBuilder.build(window(panels: panels),
            openFractions: const {'p1': 1}),
        'p1',
      );

      final closedWidth = closed[1].x - closed[0].x;
      final openWidth = open[1].x - open[0].x;
      expect(openWidth, closeTo(closedWidth, 0.001));
      expect(open[0].x, greaterThan(closed[0].x));
    });

    test('sliding left and sliding right go opposite ways', () {
      double travel(OpeningMechanism mechanism) {
        final panels = [sash(mechanism)];
        final closed =
            panelFace(SceneBuilder.build(window(panels: panels)), 'p1');
        final open = panelFace(
          SceneBuilder.build(window(panels: panels),
              openFractions: const {'p1': 1}),
          'p1',
        );
        return open[0].x - closed[0].x;
      }

      expect(travel(OpeningMechanism.slidingLeft), lessThan(0));
      expect(travel(OpeningMechanism.slidingRight), greaterThan(0));
    });

    test('half open is between closed and open', () {
      List<Point3> at(double fraction) => panelFace(
            SceneBuilder.build(
              window(panels: [sash(OpeningMechanism.hinged)]),
              openFractions: {'p1': fraction},
            ),
            'p1',
          );

      final closed = at(0);
      final half = at(0.5);
      final open = at(1);

      expect(half[1].z, greaterThan(closed[1].z));
      expect(half[1].z, lessThan(open[1].z));
    });

    test('a CH panel never moves, whatever fraction it is given', () {
      // Spec section 3E: CH panels stay fixed during opening animations.
      final closed = panelFace(SceneBuilder.build(window()), 'p1');
      final animated = panelFace(
        SceneBuilder.build(window(), openFractions: const {'p1': 1}),
        'p1',
      );

      expect(animated, closed);
    });

    test('an out-of-range fraction is clamped rather than exploding', () {
      final over = panelFace(
        SceneBuilder.build(
          window(panels: [sash(OpeningMechanism.hinged)]),
          openFractions: const {'p1': 4},
        ),
        'p1',
      );
      final full = panelFace(
        SceneBuilder.build(
          window(panels: [sash(OpeningMechanism.hinged)]),
          openFractions: const {'p1': 1},
        ),
        'p1',
      );

      expect(over, full);
    });

    test('opening one panel leaves its neighbour alone', () {
      final scene = SceneBuilder.build(
        window(panels: [
          sash(
            OpeningMechanism.hinged,
            id: 'left',
            boundary: Polygon.rectangle(width: 600, height: 900),
          ),
          Panel.fixed(
            id: 'right',
            boundary: Polygon.rectangle(
              width: 600,
              height: 900,
              topLeft: const Point2(600, 0),
            ),
          ),
        ]),
        openFractions: const {'left': 1},
      );

      final right = panelFace(scene, 'right');
      final inset = GenericProfiles.pvcCasement.frameFaceMm / 2;
      expect(right[0].x, 600 + inset);
      expect(right[0].z, right[1].z);
    });
  });

  group('drawing order', () {
    test('faces come back sorted back to front', () {
      final scene = SceneBuilder.build(window());

      for (var i = 1; i < scene.faces.length; i++) {
        expect(
          scene.faces[i].sortDepth,
          greaterThanOrEqualTo(scene.faces[i - 1].sortDepth),
        );
      }
    });

    test('a sash swung towards the viewer is drawn over the frame', () {
      final scene = SceneBuilder.build(
        window(panels: [sash(OpeningMechanism.hinged)]),
        openFractions: const {'p1': 1},
      );

      final sashIndex = scene.faces.indexWhere((f) => f.panelId == 'p1');
      final lastFrame =
          scene.faces.lastIndexWhere((f) => f.role == PartRole.frame);
      expect(sashIndex, greaterThan(lastFrame));
    });
  });

  test('the scene is rebuilt from the document alone', () {
    // Spec Phase 3, item 1: the renderer consumes only the design entity, so
    // the same document always gives the same scene.
    final design = window();

    final first = SceneBuilder.build(design);
    final second = SceneBuilder.build(design);

    expect(first.faces.length, second.faces.length);
    for (var i = 0; i < first.faces.length; i++) {
      expect(first.faces[i].corners, second.faces[i].corners);
    }
  });
}
