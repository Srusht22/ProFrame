import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/units.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_tree.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/sections/section_builder.dart';

// The phase's example:
//
//   Opening 40 × 160 cm, a horizontal divider 40 cm down it
//
//   ┌──────────┐        Opening
//   │  GLASS   │        ├── Glass Section
//   ├──────────┤        ├── Internal Divider
//   │  PANEL   │        └── Panel Section
//   └──────────┘
//
// The glass and the panel are the opening's. They are not top-level
// sections, and every figure the user sees of them is in centimetres.

const _panel = Finish(colour: 0xFF7B4A2B, material: MaterialKind.panel);

/// A window whose marked light is exactly 40 × 160 cm of daylight.
Design marked() {
  final at = DateTime(2026);
  final design = SectionBuilder.rebuild(Design(
    id: 'd',
    name: 'test',
    kind: DesignKind.window,
    createdAt: at,
    updatedAt: at,
    frame: FrameElement(
      id: 'f',
      outline: Polygon.rect(0, 0, 2000, 1700),
      profileMm: 50,
    ),
    dividers: const [
      DividerElement(id: 'mull', a: Vec2(470, 0), b: Vec2(470, 1700),
          widthMm: 40),
    ],
  ));
  final sash = design.topLevelSections
      .reduce((a, b) => a.outline.left < b.outline.left ? a : b);
  return DesignEdits.setOpening(
    design,
    sash.id,
    openingId: 'o',
    mechanism: OpeningMechanism.hingedRight,
    markGlyph: '<',
    markAt: sash.outline.centroid,
  );
}

/// The divider 40 cm down it, and the lower pane made a panel.
Design example() {
  final design = marked();
  final on = design.openings.single.sectionId;
  final box = design.sectionById(on)!.outline;
  final out = DesignEdits.addLineInside(
    design,
    on,
    id: 'divider',
    at: Vec2(box.centroid.x, box.top + 400),
    horizontal: true,
  );
  final lower = out
      .childSectionsOf(on)
      .reduce((a, b) => a.outline.top > b.outline.top ? a : b);
  return out.withElement(lower.copyWith(finish: _panel));
}

List<SectionElement> panesOf(Design d) =>
    d.childSectionsOf(d.openings.single.sectionId)
      ..sort((a, b) => a.outline.top.compareTo(b.outline.top));

void main() {
  group('the opening holds glass, a divider and a panel', () {
    test('the opening is 40 × 160 cm and the divider is 40 cm down it', () {
      final design = example();
      final box = design.sectionById(design.openings.single.sectionId)!.outline;

      expect(Units.format(box.width), '40');
      expect(Units.format(box.height), '160');
      expect(
        Units.format(
            DesignEdits.alongWithin(design, design.dividerById('divider'))!),
        '40',
      );
    });

    test('the structure is glass, divider, panel — all the opening’s', () {
      final design = example();
      final opening = design.openings.single;
      final branch = DesignTree.of(design).openings.single;

      expect(branch.barIds, ['divider']);
      expect(branch.panes, hasLength(2));

      final panes = panesOf(design);
      expect(panes.first.finish.material.isGlazing, isTrue);
      expect(panes.last.finish.material, MaterialKind.panel);
      for (final pane in panes) {
        expect(pane.parentId, opening.id);
        expect(design.openingHolding(pane.parentId)!.id, opening.id);
      }
      expect(design.dividerById('divider')!.parentId, opening.id);
    });

    test('they are not top-level sections', () {
      final before = marked();
      final design = example();

      // The window still has its two main divisions and its one bar. The
      // glass and the panel are not among them.
      expect(design.topLevelSections, hasLength(before.topLevelSections.length));
      expect(design.topLevelSections, hasLength(2));
      expect(design.topLevelDividers.map((b) => b.id), ['mull']);

      final top = {for (final s in design.topLevelSections) s.id};
      for (final pane in panesOf(design)) {
        expect(top, isNot(contains(pane.id)));
        expect(pane.parentId, isNotNull);
      }
      expect(DesignTree.of(design).sections, hasLength(2));
    });

    test('each pane is a section of its own, with its own material', () {
      var design = example();
      final panes = panesOf(design);

      // Changing one does not touch the other, and neither touches the
      // opening's own size.
      final box = design.sectionById(design.openings.single.sectionId)!.outline;
      design = design.withElement(panes.first.copyWith(finish: _panel));

      final after = panesOf(design);
      expect(after.first.finish.material, MaterialKind.panel);
      expect(after.last.finish.material, MaterialKind.panel);
      expect(design.sectionById(design.openings.single.sectionId)!.outline, box);
    });
  });

  group('the figures are the material the workshop cuts', () {
    test('the glass and the panel stop at the divider’s faces', () {
      final design = example();
      final panes = panesOf(design);
      final bar = design.dividerById('divider')!;

      // The phase writes 40 × 40 and 40 × 120, which is the arithmetic with
      // a divider of no thickness. The divider is real material 2.8 cm wide
      // and the glass stops at its faces, so the panes are that much
      // shorter — and the three together are the opening exactly.
      expect(Units.format(panes.first.widthMm), '40');
      expect(Units.format(panes.last.widthMm), '40');
      expect(Units.format(bar.widthMm), '2.8');
      expect(Units.format(panes.first.heightMm), '38.6');
      expect(Units.format(panes.last.heightMm), '118.6');

      final box = design.sectionById(design.openings.single.sectionId)!.outline;
      expect(
        panes.first.heightMm + bar.widthMm + panes.last.heightMm,
        closeTo(box.height, 0.01),
      );
    });

    test('they survive a save and a reload as the opening’s', () {
      final design = example();
      final back = Design.fromJson(design.toJson());
      final panes = panesOf(back);

      expect(panes, hasLength(2));
      for (final pane in panes) {
        expect(pane.parentId, back.openings.single.id);
      }
      expect(Units.format(panes.first.heightMm), '38.6');
      expect(panes.last.finish.material, MaterialKind.panel);
      expect(back.topLevelSections, hasLength(2));
    });

    test('they go with the opening when it moves to another light', () {
      final before = example();
      final wide = before.topLevelSections
          .reduce((a, b) => a.areaMmSq > b.areaMmSq ? a : b);
      final after = DesignEdits.moveOpeningToSection(before, 'o', wide.id);
      final panes = panesOf(after);

      expect(panes, hasLength(2));
      for (final pane in panes) {
        expect(pane.parentId, after.openings.single.id);
      }
      expect(panes.last.finish.material, MaterialKind.panel,
          reason: 'the panel came back as glass');
      expect(after.topLevelSections, hasLength(2));
    });
  });

  group('every figure the user sees is centimetres', () {
    test('the unit is cm and the figures read as centimetres', () {
      final design = example();
      final panes = panesOf(design);

      expect(Units.symbol, 'cm');
      expect(Units.label(panes.first.heightMm), '38.6 cm');
      expect(Units.label(panes.last.heightMm), '118.6 cm');
      expect(Units.label(1600), '160 cm');
      // Typed in centimetres, exact in millimetres.
      expect(Units.parse('72.25'), 722.5);
    });

    test('nothing under lib/app prints a raw millimetre figure', () {
      // The geometry is millimetres and the user never sees one: every
      // figure on screen goes through Units. A number put straight into a
      // string is how millimetres leak out — a dimension the user drew on
      // the sheet was painted as `1600` with no unit at all.
      final offenders = <String>[];
      final raw = RegExp(r'\$\{?[A-Za-z_.]*\.?[a-zA-Z]+Mm[^}]*\}?');
      for (final file in Directory('lib/app')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final lines = file.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.trimLeft().startsWith('//')) continue;
          if (!line.contains("'") && !line.contains('"')) continue;
          if (!raw.hasMatch(line)) continue;
          if (line.contains('Units.')) continue;
          offenders.add('${file.path}:${i + 1}: ${line.trim()}');
        }
      }
      expect(offenders, isEmpty,
          reason: 'a millimetre figure reaches the user:\n'
              '${offenders.join('\n')}');
    });
  });
}
