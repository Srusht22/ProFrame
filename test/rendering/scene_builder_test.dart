import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/features/geometry/model_editor.dart';
import 'package:proframe/features/rendering/three_d/scene_builder.dart';
import 'package:proframe/shared/models/materials.dart';
import 'package:proframe/shared/models/opening_model.dart';
import 'package:proframe/shared/models/scene_3d.dart';

const builder = SceneBuilder();

OpeningModel casementWindow({
  double width = 1200,
  double height = 1400,
  CellOperation operation = CellOperation.casementRight,
}) =>
    ModelEditor.setCellOperation(
      OpeningModel(
        id: 'w',
        kind: OpeningKind.window,
        widthMm: width,
        heightMm: height,
        hasSill: true,
        layout: OpeningLayout.single(const LayoutCell(id: 'c0')),
      ),
      'c0',
      operation,
    );

void main() {
  group('the assembly is built from real parts', () {
    test('the frame is four separate members, not one slab', () {
      final scene = builder.build(casementWindow());
      final frame = scene.parts.where((p) => p.role.isFrame).toList();

      expect(frame, hasLength(4));
      expect(scene.partsWithRole(PartRole.frameHead), hasLength(1));
      expect(scene.partsWithRole(PartRole.frameSill), hasLength(1));
      expect(scene.partsWithRole(PartRole.frameJambLeft), hasLength(1));
      expect(scene.partsWithRole(PartRole.frameJambRight), hasLength(1));
    });

    test('an opening leaf has its own four-sided sash', () {
      final scene = builder.build(casementWindow());

      expect(scene.partsWithRole(PartRole.sashStile), hasLength(2));
      expect(scene.partsWithRole(PartRole.sashRail), hasLength(2));
    });

    test('the frame has real depth and the glass a real thickness', () {
      final model = casementWindow();
      final scene = builder.build(model);
      final head = scene.partsWithRole(PartRole.frameHead).single;
      final glass = scene.partsWithRole(PartRole.glass).single;

      expect(head.size.z, model.material.frameDepthMm);
      expect(head.size.z, greaterThan(0));
      expect(glass.size.z, GlassType.clearDouble.thicknessMm);
    });

    test('a window with three sections produces three panes and two mullions', () {
      var model = casementWindow();
      model = ModelEditor.addMullion(model, 0);
      model = ModelEditor.addMullion(model, 0);
      final scene = builder.build(model);

      expect(scene.glassCount, 3);
      expect(scene.partsWithRole(PartRole.mullion), hasLength(2));
    });
  });

  group('proportions and placement', () {
    test('every part stays inside the outer dimensions of the product', () {
      final model = casementWindow(width: 1600, height: 2200);
      final scene = builder.build(model);
      final halfWidth = model.widthMm / 2;
      final halfHeight = model.heightMm / 2;

      for (final part in scene.parts.where((p) => p.role != PartRole.windowSill)) {
        expect(
          part.center.x.abs() + part.size.x / 2,
          lessThanOrEqualTo(halfWidth + 1),
          reason: '${part.id} sticks out sideways',
        );
        expect(
          part.center.y.abs() + part.size.y / 2,
          lessThanOrEqualTo(halfHeight + 30),
          reason: '${part.id} sticks out vertically',
        );
      }
    });

    test('the glass is smaller than the frame it sits in', () {
      final model = casementWindow();
      final scene = builder.build(model);
      final glass = scene.partsWithRole(PartRole.glass).single;

      expect(glass.size.x, lessThan(model.widthMm));
      expect(glass.size.y, lessThan(model.heightMm));
      expect(glass.size.x, greaterThan(model.widthMm * 0.5));
    });

    test('the frame members meet at the corners without overlapping the jambs', () {
      final model = casementWindow();
      final scene = builder.build(model);
      final head = scene.partsWithRole(PartRole.frameHead).single;
      final jamb = scene.partsWithRole(PartRole.frameJambLeft).single;

      expect(head.size.x, model.widthMm);
      expect(jamb.size.y, model.heightMm - 2 * model.material.frameFaceMm);
    });

    test('a window sill sits below the frame and projects outwards', () {
      final model = casementWindow();
      final scene = builder.build(model);
      final sill = scene.partsWithRole(PartRole.windowSill).single;

      expect(sill.center.y, lessThan(-model.heightMm / 2));
      expect(sill.size.z, greaterThan(model.material.frameDepthMm));
      expect(sill.size.x, greaterThan(model.widthMm));
    });

    test('a door gets a threshold, a window does not', () {
      final door = OpeningModel.blank(OpeningKind.door);
      final window = casementWindow();

      expect(builder.build(door).partsWithRole(PartRole.threshold), hasLength(1));
      expect(builder.build(window).partsWithRole(PartRole.threshold), isEmpty);
    });
  });

  group('hardware is attached where it belongs', () {
    test('hinges are on the hinge side of the leaf', () {
      final rightHung = builder.build(casementWindow(operation: CellOperation.casementRight));
      final leftHung = builder.build(casementWindow(operation: CellOperation.casementLeft));

      final rightHinges = rightHung.partsWithRole(PartRole.hinge);
      final leftHinges = leftHung.partsWithRole(PartRole.hinge);

      expect(rightHinges, isNotEmpty);
      expect(leftHinges, isNotEmpty);
      for (final hinge in rightHinges) {
        expect(hinge.center.x, greaterThan(0), reason: 'right-hung hinges belong on the right');
      }
      for (final hinge in leftHinges) {
        expect(hinge.center.x, lessThan(0), reason: 'left-hung hinges belong on the left');
      }
    });

    test('the handle is on the opposite side to the hinges', () {
      final scene = builder.build(casementWindow(operation: CellOperation.casementRight));
      final handle = scene.partsWithRole(PartRole.handle).single;
      final hinge = scene.partsWithRole(PartRole.hinge).first;

      expect(handle.center.x.sign, isNot(hinge.center.x.sign));
    });

    test('hinge count follows the height of the leaf', () {
      expect(SceneBuilder.hingeCountFor(800), 2);
      expect(SceneBuilder.hingeCountFor(1400), 3);
      expect(SceneBuilder.hingeCountFor(2000), 4);
      expect(SceneBuilder.hingeCountFor(2100, isDoor: true), 3);
      expect(SceneBuilder.hingeCountFor(2400, isDoor: true), 4);
    });

    test('a taller window really does get more hinges in the 3D model', () {
      final short = builder.build(casementWindow(height: 800));
      final tall = builder.build(casementWindow(height: 2000));

      expect(tall.hingeCount, greaterThan(short.hingeCount));
    });

    test('a fixed light has no hinges, no handle and no lock', () {
      final scene = builder.build(casementWindow(operation: CellOperation.fixed));

      expect(scene.partsWithRole(PartRole.hinge), isEmpty);
      expect(scene.partsWithRole(PartRole.handle), isEmpty);
      expect(scene.partsWithRole(PartRole.lockCylinder), isEmpty);
      expect(scene.partsWithRole(PartRole.sashStile), isEmpty);
    });

    test('a door leaf with a lock gets a cylinder near the handle', () {
      final door = OpeningModel.blank(OpeningKind.door);
      final scene = builder.build(door);
      final lock = scene.partsWithRole(PartRole.lockCylinder).single;
      final handle = scene.partsWithRole(PartRole.handle).single;

      expect((lock.center.x - handle.center.x).abs(), lessThan(120));
      expect(lock.center.y, lessThan(handle.center.y));
    });

    test('the door handle sits at working height, not in the middle', () {
      final door = OpeningModel.blank(OpeningKind.door);
      final scene = builder.build(door);
      final handle = scene.partsWithRole(PartRole.handle).single;
      final heightAboveFloor = door.heightMm / 2 + handle.center.y;

      expect(heightAboveFloor, closeTo(SceneBuilder.doorHandleHeightMm, 60));
    });

    test('two sliding leaves sit in different tracks so they can pass', () {
      var model = casementWindow(operation: CellOperation.slidingLeft);
      model = ModelEditor.addMullion(model, 0);
      model = ModelEditor.setCellOperation(model, 'r0.c1', CellOperation.slidingRight);
      final scene = builder.build(model);

      final left = scene.partsForCell('r0.c0').firstWhere((p) => p.role == PartRole.glass);
      final right = scene.partsForCell('r0.c1').firstWhere((p) => p.role == PartRole.glass);

      expect(left.center.z, isNot(right.center.z));
    });

    test('an outward leaf sits further out than an inward one', () {
      final outward = builder.build(
        ModelEditor.updateCell(
          casementWindow(),
          'c0',
          (c) => c.copyWith(swing: SwingDirection.outward),
        ),
      );
      final inward = builder.build(
        ModelEditor.updateCell(
          casementWindow(),
          'c0',
          (c) => c.copyWith(swing: SwingDirection.inward),
        ),
      );

      final outGlass = outward.partsWithRole(PartRole.glass).single;
      final inGlass = inward.partsWithRole(PartRole.glass).single;
      expect(outGlass.center.z, greaterThan(inGlass.center.z));
    });
  });

  group('the 3D updates when the model changes', () {
    test('changing the width moves the frame, it does not stretch a picture', () {
      final narrow = builder.build(casementWindow(width: 900));
      final wide = builder.build(casementWindow(width: 1800));

      final narrowJamb =
          narrow.partsWithRole(PartRole.frameJambRight).single.center.x;
      final wideJamb = wide.partsWithRole(PartRole.frameJambRight).single.center.x;

      expect(wideJamb, greaterThan(narrowJamb));
      expect(wide.widthMm, 1800);
      expect(narrow.widthMm, 900);
    });

    test('adding a division adds real parts', () {
      final before = builder.build(casementWindow());
      final after = builder.build(ModelEditor.addMullion(casementWindow(), 0));

      expect(after.parts.length, greaterThan(before.parts.length));
    });

    test('switching to a panel replaces the glass with a solid infill', () {
      final glazed = builder.build(casementWindow());
      final panelled = builder.build(
        ModelEditor.updateCell(
          casementWindow(),
          'c0',
          (c) => c.copyWith(infill: CellInfill.panel),
        ),
      );

      expect(glazed.partsWithRole(PartRole.glass), hasLength(1));
      expect(panelled.partsWithRole(PartRole.glass), isEmpty);
      expect(panelled.partsWithRole(PartRole.panel), hasLength(1));
    });

    test('the finish colour reaches the renderer', () {
      final scene = builder.build(
        casementWindow().copyWith(finish: FrameFinish.blackPowder),
      );

      expect(scene.materials['frame']!.color, FrameFinish.blackPowder.colorValue);
    });

    test('glass is transparent and the frame is not', () {
      final scene = builder.build(casementWindow());

      expect(scene.materials['glass.clearDouble']!.isTransparent, isTrue);
      expect(scene.materials['frame']!.isTransparent, isFalse);
      expect(scene.materials['glass.clearDouble']!.transmission, greaterThan(0.5));
    });
  });

  group('the payload the renderer receives', () {
    test('serialises every part with a position, a size and a material', () {
      final scene = builder.build(casementWindow());
      final json = scene.toJson();
      final parts = json['parts'] as List;

      expect(parts, isNotEmpty);
      for (final part in parts.cast<Map<String, dynamic>>()) {
        expect(part['size'], isA<Map>());
        expect(part['center'], isA<Map>());
        expect(part['material'], isA<String>());
      }
      expect(json['width'], 1200.0);
      expect((json['materials'] as List), isNotEmpty);
    });

    test('carries dimension labels for the 3D dimension overlay', () {
      final scene = builder.build(casementWindow());

      expect(scene.dimensions, hasLength(3));
      expect(scene.dimensions.first.label, contains('1200'));
    });
  });
}
