import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sections/section_builder.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// A handle is bought in a finish, and the one the user picks is the one the
// solid builds it in.
//
//   Door handle
//   Material:  [ Steel ]
//   Colour:    [ Black · White · Silver · Grey · Bronze · Brown · Custom ]
//
// The colour is put on the handle's own facets. Nothing is tinted over a
// picture, because there is no picture: the handle is geometry and the
// colour is what that geometry is built in.
//
// **And it has to last.** The ironmongery is worked out again from the
// opening on every rebuild, so a finish that is not carried across is
// thrown away by the next edit — which is what happened: a handle set to
// silver went back to stock grey the moment anything else changed. The
// panel appeared to work and quietly undid itself, which is worse than not
// offering the control at all.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

Design leaf(DesignKind kind) {
  final read = SketchInterpreter.interpret(Design(
    id: 'd',
    name: kind.label,
    kind: kind,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    sketch: Sketch(strokes: [
      pen('outline', const [
        Vec2(0, 0),
        Vec2(1900, 0),
        Vec2(1900, 2100),
        Vec2(0, 2100),
        Vec2(0, 0),
      ]),
      pen('mullion', const [Vec2(950, 0), Vec2(950, 2100)]),
      pen('mark', const [Vec2(560, 950), Vec2(700, 1050), Vec2(560, 1150)]),
    ]),
  )).design;
  return OpeningHardware.settle(read.copyWith(openings: [
    for (final opening in read.openings) opening.copyWith(kind: kind),
  ]));
}

HardwareElement handleOf(Design design) => design.hardware
    .firstWhere((piece) => piece.isOpeningHardware && piece.kind.isHandle);

/// The colours the solid actually builds [elementId] in.
Set<int> builtColours(Design design, String elementId) => {
      for (final facet in MeshBuilder.build(design).facets)
        if (facet.elementId == elementId) facet.colour,
    };

Design painted(Design design, String id, Finish finish) =>
    OpeningHardware.settle(design.withElement(
        design.hardware.firstWhere((p) => p.id == id).copyWith(
              finish: finish,
            )));

void main() {
  group('the palette is the one a joiner orders from', () {
    test('it has the finishes ironmongery is sold in', () {
      expect([for (final c in HardwareColour.values) c.label],
          ['Black', 'White', 'Silver', 'Grey', 'Bronze', 'Brown']);
      // Six different colours, not six names for the same one.
      expect({for (final c in HardwareColour.values) c.colour}, hasLength(6));
    });

    test('a colour is recognised as the one it is, or as the user’s own', () {
      for (final option in HardwareColour.values) {
        expect(HardwareColour.of(option.colour), option);
      }
      expect(HardwareColour.of(0xFF123456), isNull,
          reason: 'anything else is Custom, and still buildable');
    });

    test('a handle is never offered glass to be made of', () {
      for (final material in hardwareMaterials) {
        expect(material.isGlazing, isFalse);
      }
      expect(hardwareMaterials, contains(MaterialKind.steel));
      expect(hardwareMaterials, contains(MaterialKind.aluminium));
    });
  });

  group('the colour is what the solid builds the handle in', () {
    for (final option in HardwareColour.values) {
      test('${option.label} reaches the handle’s own facets', () {
        final design = leaf(DesignKind.door);
        final handle = handleOf(design);
        final after = painted(design, handle.id,
            handle.finish.copyWith(colour: option.colour));

        final built = builtColours(after, handle.id);
        expect(built, isNotEmpty);
        // Every facet of it is that colour, or a shade of it — a solid is
        // lit, so the faces away from the light are darker, and that is the
        // renderer shading the piece rather than painting it something else.
        for (final colour in built) {
          expect(_isShadeOf(colour, option.colour), isTrue,
              reason: '${option.label}: 0x${colour.toRadixString(16)}');
        }
      });
    }

    test('two colours give two different handles', () {
      final design = leaf(DesignKind.door);
      final handle = handleOf(design);

      final black = builtColours(
          painted(design, handle.id,
              handle.finish.copyWith(colour: HardwareColour.black.colour)),
          handle.id);
      final bronze = builtColours(
          painted(design, handle.id,
              handle.finish.copyWith(colour: HardwareColour.bronze.colour)),
          handle.id);

      expect(black, isNot(bronze));
    });

    test('a window’s handle takes a colour the same way', () {
      final design = leaf(DesignKind.window);
      final handle = handleOf(design);
      final after = painted(design, handle.id,
          handle.finish.copyWith(colour: HardwareColour.white.colour));

      for (final colour in builtColours(after, handle.id)) {
        expect(_isShadeOf(colour, HardwareColour.white.colour), isTrue);
      }
    });

    test('a custom colour is built as readily as a named one', () {
      final design = leaf(DesignKind.door);
      final handle = handleOf(design);
      const mine = 0xFF3C6E71;
      final after =
          painted(design, handle.id, handle.finish.copyWith(colour: mine));

      expect(after.hardware.firstWhere((p) => p.id == handle.id).finish.colour,
          mine);
      for (final colour in builtColours(after, handle.id)) {
        expect(_isShadeOf(colour, mine), isTrue);
      }
    });
  });

  group('and the geometry is untouched by it', () {
    test('painting the handle moves no part of the design', () {
      final before = leaf(DesignKind.door);
      final handle = handleOf(before);
      final after = painted(before, handle.id,
          handle.finish.copyWith(colour: HardwareColour.bronze.colour));

      String shape(Design design) => [
            for (final facet in MeshBuilder.build(design).facets)
              '${facet.elementId}:${facet.corners.join(',')}',
          ].join('|');

      expect(shape(after), shape(before),
          reason: 'a colour is not a shape');
    });

    test('and changes no other piece’s colour', () {
      final before = leaf(DesignKind.door);
      final handle = handleOf(before);
      final others = {
        for (final piece in before.hardware)
          if (piece.id != handle.id) piece.id: piece.finish.colour,
      };
      expect(others, isNotEmpty);

      final after = painted(before, handle.id,
          handle.finish.copyWith(colour: HardwareColour.black.colour));

      for (final entry in others.entries) {
        expect(after.hardware.firstWhere((p) => p.id == entry.key).finish
            .colour, entry.value);
      }
    });

    test('each piece takes its own finish, so hinges need not match', () {
      var design = leaf(DesignKind.door);
      final handle = handleOf(design);
      final hinge = design.hardware
          .firstWhere((piece) => piece.kind == HardwareKind.hinge);

      design = painted(design, handle.id,
          handle.finish.copyWith(colour: HardwareColour.silver.colour));
      design = painted(design, hinge.id,
          hinge.finish.copyWith(colour: HardwareColour.black.colour));

      expect(design.hardware.firstWhere((p) => p.id == handle.id).finish
          .colour, HardwareColour.silver.colour);
      expect(design.hardware.firstWhere((p) => p.id == hinge.id).finish
          .colour, HardwareColour.black.colour);
    });
  });

  group('what the user chose lasts', () {
    Design silver(Design design) {
      final handle = handleOf(design);
      return painted(design, handle.id,
          handle.finish.copyWith(
            colour: HardwareColour.silver.colour,
            material: MaterialKind.aluminium,
          ));
    }

    test('a rebuild does not put the stock finish back', () {
      final design = silver(leaf(DesignKind.door));
      final after = SectionBuilder.rebuild(design);

      final handle = handleOf(after);
      expect(handle.finish.colour, HardwareColour.silver.colour);
      expect(handle.finish.material, MaterialKind.aluminium);
    });

    test('nor does moving a bar, or any other edit near it', () {
      var design = silver(leaf(DesignKind.door));
      final mullion = design.topLevelDividers.single;
      design = DesignEdits.moveDivider(design, mullion.id, const Vec2(80, 0));

      expect(handleOf(design).finish.colour, HardwareColour.silver.colour);
    });

    test('nor resizing the leaf it hangs on', () {
      var design = silver(leaf(DesignKind.door));
      final opening = design.openings.single;
      design =
          DesignEdits.setSectionWidth(design, opening.sectionId, 1100);

      expect(handleOf(design).finish.colour, HardwareColour.silver.colour);
    });

    test('nor changing what the leaf is', () {
      var design = silver(leaf(DesignKind.window));
      design = OpeningHardware.settle(design.copyWith(openings: [
        design.openings.single.copyWith(kind: DesignKind.door),
      ]));

      // The form changed — a window's espagnolette for a door's lever — and
      // the finish the user chose came with it.
      expect(handleOf(design).kind, HardwareKind.lever);
      expect(handleOf(design).finish.colour, HardwareColour.silver.colour);
    });

    test('a save and a reload keeps it', () {
      final design = silver(leaf(DesignKind.door));
      final back = Design.fromJson(design.toJson());

      expect(handleOf(back).finish.colour, HardwareColour.silver.colour);
      expect(handleOf(back).finish.material, MaterialKind.aluminium);
    });

    test('and so does reading the sheet again', () {
      final design = silver(leaf(DesignKind.door));
      final again = SketchInterpreter.interpret(design).design;

      expect(again.openings, hasLength(1));
      expect(handleOf(again).finish.colour, HardwareColour.silver.colour);
    });
  });
}

/// True when [colour] is [of] under the renderer's own shading.
///
/// A solid is lit, so a face turned away from the light is a darker version
/// of the same finish. What is forbidden is a different hue altogether —
/// the piece being painted something the user did not choose.
bool _isShadeOf(int colour, int of) {
  int red(int c) => (c >> 16) & 0xFF;
  int green(int c) => (c >> 8) & 0xFF;
  int blue(int c) => c & 0xFF;

  if (red(of) + green(of) + blue(of) == 0) return true;
  final scale = (red(colour) + green(colour) + blue(colour)) /
      (red(of) + green(of) + blue(of)).clamp(1, 765);
  if (scale > 1.02) return false;
  for (final channel in [red, green, blue]) {
    if ((channel(colour) - channel(of) * scale).abs() > 6) return false;
  }
  return true;
}
