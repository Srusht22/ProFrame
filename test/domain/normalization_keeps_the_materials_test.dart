import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/dimensions/measurements.dart';
import 'package:proframe/domain/editing/design_edits.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/hardware/opening_hardware.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

import '../app/pause_and_take_it_back_test.dart' show chevron;
import 'geometry_normalizer_test.dart' show pen;

// Geometry is not material. When the reading corrects a hand-drawn design —
// again, after a figure the user states, after the sizes are given, after
// the outline is drawn again more crooked — every part keeps what it is made
// of: the frame its aluminium, the bars theirs, each glass its look, each
// panel its colour, the handle and the hinges their metal, the design its
// own infill, and every sealed unit its rubber seal. Only the geometry is
// corrected.

/// The outline as drawn: the head sloping, every side a little out.
const outline = [
  Vec2(2, 6),
  Vec2(1612, 150),
  Vec2(1592, 2000),
  Vec2(5, 1990),
  Vec2(2, 6),
];

/// The same outline drawn again, more crooked.
const crookeder = [
  Vec2(-10, 20),
  Vec2(1625, 120),
  Vec2(1600, 2010),
  Vec2(-5, 1985),
  Vec2(-10, 20),
];

/// A design of [kind] drawn by hand: a mullion, a transom across the right
/// light, and a `>` in the left one.
Design drawn(DesignKind kind, {List<Vec2> frame = outline}) =>
    Design.empty(id: 'materials', kind: kind).copyWith(
      customerId: 'customer',
      sketch: Sketch(
        strokes: [
          pen('outline', frame),
          pen('mullion', const [Vec2(700, 60), Vec2(706, 1994)]),
          pen('transom', const [Vec2(712, 900), Vec2(1590, 915)]),
          pen('mark', chevron(const Vec2(350, 1000))),
        ],
      ),
    );

/// The sheet read, as the workspace reads it.
Design readSheet(Design d) =>
    Measurements.keepAfterReading(d, SketchInterpreter.interpret(d).design);

const anthracite = Finish(colour: 0xFF383E42, material: MaterialKind.aluminium);
const whitePvc = Finish(colour: 0xFFF2F2F0, material: MaterialKind.upvc);
const greyAluminium = Finish(
  colour: 0xFF7C8285,
  material: MaterialKind.aluminium,
);
const oak = Finish(colour: 0xFF8A6A45, material: MaterialKind.wood);

Finish metal(HardwareColour c) =>
    Finish(colour: c.colour, material: MaterialKind.steel);

/// [read] given a material for every part: an anthracite aluminium frame, a
/// white uPVC mullion, a grey aluminium transom, an oak line inside the
/// opening; tinted glass and frosted glass in the two fixed lights,
/// blue-grey glass over a white panel in the opening; a silver handle,
/// black hinges and bronze for anything else; and a brown panel as the
/// design's own infill.
Design dressed(Design read) {
  var d = read;
  if (d.kind == DesignKind.both || d.kind == DesignKind.angled) {
    d = OpeningHardware.settle(
      d.copyWith(
        openings: [
          for (final o in d.openings) o.copyWith(kind: DesignKind.door),
        ],
      ),
    );
  }
  final opening = d.openings.single;
  final box = d.sectionById(opening.sectionId)!.outline;
  d = DesignEdits.addLineInside(
    d,
    opening.sectionId,
    id: 'inside',
    at: Vec2(box.centroid.x, box.top + 600),
    horizontal: true,
  );

  d = d.withElement(d.frame!.copyWith(finish: anthracite));
  for (final bar in d.dividers) {
    final finish = switch (bar.fromStrokeId) {
      'mullion' => whitePvc,
      'transom' => greyAluminium,
      _ => oak,
    };
    d = d.withElement(bar.copyWith(finish: finish));
  }

  final lights = d.topLevelSections;
  final fixed = [
    for (final s in lights)
      if (s.id != opening.sectionId) s,
  ];
  d = d.withElement(fixed[0].copyWith(finish: GlassLook.tinted.finish));
  d = d.withElement(fixed[1].copyWith(finish: GlassLook.frosted.finish));
  final panes = panesOf(d);
  d = d.withElement(panes.first.copyWith(finish: GlassLook.blueGrey.finish));
  d = d.withElement(panes.last.copyWith(finish: PanelColour.white.finish));

  for (final h in d.hardware) {
    final finish = h.kind.isHandle
        ? metal(HardwareColour.silver)
        : h.kind == HardwareKind.hinge
        ? metal(HardwareColour.black)
        : metal(HardwareColour.bronze);
    d = d.withElement(h.copyWith(finish: finish));
  }
  return d.copyWith(infill: PanelColour.brown.finish);
}

/// The opening's panes, top to bottom.
List<SectionElement> panesOf(Design d) =>
    d.childSectionsOf(d.openings.single.sectionId)
      ..sort((a, b) => a.outline.top.compareTo(b.outline.top));

/// What every part is made of, by what the part is — never by where it is,
/// which is what the correction is allowed to change.
Map<String, Object?> materialsOf(Design d) {
  final opening = d.openings.single;
  final fixed = [
    for (final s in d.topLevelSections)
      if (s.id != opening.sectionId) s,
  ];
  return {
    'frame': d.frame!.finish.toJson(),
    'infill': d.infill?.toJson(),
    for (final bar in d.dividers) 'bar ${bar.id}': bar.finish.toJson(),
    'opening light': d.sectionById(opening.sectionId)!.finish.toJson(),
    for (var i = 0; i < fixed.length; i++)
      'fixed light $i': [
        fixed[i].finish.toJson(),
        GlassLook.of(fixed[i].finish)?.name,
      ],
    for (final (i, pane) in panesOf(d).indexed)
      'pane $i': [
        pane.finish.toJson(),
        GlassLook.of(pane.finish)?.name,
        PanelColour.of(pane.finish)?.name,
      ],
    for (final h in d.hardware)
      'hardware ${h.id}': [h.kind.name, h.finish.toJson()],
  };
}

/// What the solid builds each part of: for every part, by what the part
/// is, the colours and surfaces its faces are made of — the rubber seal
/// round each sealed unit included.
Map<String, List<String>> solidMaterialsOf(Design d) {
  final opening = d.openings.single;
  final fixed = [
    for (final s in d.topLevelSections)
      if (s.id != opening.sectionId) s,
  ];
  final panes = panesOf(d);
  final roles = <String, String>{
    d.frame!.id: 'frame',
    for (final bar in d.dividers) bar.id: 'bar ${bar.id}',
    opening.sectionId: 'opening light',
    for (var i = 0; i < fixed.length; i++) fixed[i].id: 'fixed light $i',
    for (var i = 0; i < panes.length; i++) panes[i].id: 'pane $i',
    for (final h in d.hardware) h.id: 'hardware ${h.id}',
  };
  final found = <String, Set<String>>{};
  for (final facet in MeshBuilder.build(d).facets) {
    final role = roles[facet.elementId] ?? 'other ${facet.elementId}';
    found
        .putIfAbsent(role, () => {})
        .add(
          '${facet.colour.toRadixString(16)} ${facet.surface.id} '
          '${facet.role.name}',
        );
  }
  return {
    for (final MapEntry(:key, :value) in found.entries)
      key: value.toList()..sort(),
  };
}

const statedLeft = DimensionElement(
  id: 'left',
  a: Vec2(2, 6),
  b: Vec2(2, 1990),
  offsetMm: 0,
  statedMm: 1984,
);

void main() {
  for (final kind in [
    DesignKind.door,
    DesignKind.window,
    DesignKind.sliding,
    DesignKind.both,
    DesignKind.angled,
  ]) {
    group(kind.label, () {
      late Design before;
      setUp(() => before = dressed(readSheet(drawn(kind))));

      test('the materials are all assigned, and are what was said', () {
        final m = materialsOf(before);
        expect(m['frame'], anthracite.toJson());
        expect(m['infill'], PanelColour.brown.finish.toJson());
        expect(
          [
            for (final b in before.dividers)
              if (b.fromStrokeId == 'mullion') b.finish,
          ].single,
          whitePvc,
        );
        expect((m['fixed light 0']! as List)[1], GlassLook.tinted.name);
        expect((m['fixed light 1']! as List)[1], GlassLook.frosted.name);
        expect((m['pane 0']! as List)[1], GlassLook.blueGrey.name);
        expect((m['pane 1']! as List)[2], PanelColour.white.name);
        expect(before.hardware, isNotEmpty);
        // The solid builds the rubber seal round every sealed unit.
        final solid = solidMaterialsOf(before).values.expand((s) => s);
        expect(solid.where((s) => s.contains(' rubber')), isNotEmpty);
      });

      final corrections = <String, Design Function(Design)>{
        'read again': readSheet,
        'corrected again by a stated figure': (d) =>
            readSheet(d.copyWith(dimensions: const [statedLeft])),
        'given its sizes': (d) => Measurements.apply(d, {
          for (final m in Measurements.of(d))
            if (m.asked)
              m.key: switch (m.key) {
                Measurements.widthKey => 1800,
                Measurements.heightKey => 2150,
                _ => m.currentMm(d),
              },
        }).design,
        'drawn again more crooked': (d) => readSheet(
          d.copyWith(
            sketch: Sketch(
              strokes: [
                for (final s in d.sketch.strokes)
                  if (s.id == 'outline') pen('outline', crookeder) else s,
              ],
            ),
          ),
        ),
      };

      for (final MapEntry(key: how, value: correct) in corrections.entries) {
        test('$how: every material exactly as it was, in the design and in '
            'the solid', () {
          final after = correct(before);
          final why = '${kind.name}, $how';
          if (how != 'read again') {
            expect(
              after.frame!.outline,
              isNot(before.frame!.outline),
              reason: '$why: the geometry was corrected',
            );
          }
          final was = materialsOf(before);
          final now = materialsOf(after);
          // A taller leaf may hang on one hinge more: it is made of what
          // the leaf's other hinges are made of.
          final added = now.keys.toSet().difference(was.keys.toSet());
          for (final key in added) {
            expect(key, contains('-hinge-'), reason: '$why: $key');
            expect(
              jsonEncode(now[key]),
              jsonEncode(['hinge', metal(HardwareColour.black).toJson()]),
              reason: '$why: $key',
            );
          }
          expect(
            now..removeWhere((k, _) => added.contains(k)),
            was,
            reason: why,
          );
          final solidWas = solidMaterialsOf(before);
          final solidNow = solidMaterialsOf(after);
          for (final key in solidNow.keys.toSet().difference(
            solidWas.keys.toSet(),
          )) {
            // The added hinge: built of the same as the leaf's others.
            expect(key, contains('-hinge-'), reason: '$why: $key');
            expect(
              solidNow[key],
              solidWas['hardware ${before.openings.single.id}-hinge-0'],
              reason: '$why: $key',
            );
            solidNow.remove(key);
          }
          expect(solidNow, solidWas, reason: '$why: the solid');
        });
      }
    });
  }
}
