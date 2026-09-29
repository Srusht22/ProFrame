import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/geometry/vec2.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/recognition/interpreter.dart';
import 'package:proframe/domain/sketch/stroke.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';

// The geometry the technical drawing and the solid are built from, pinned
// before the visual work on CAD and 3D begins (see docs/cad_and_3d_audit.md).
//
// The visual phases change how things *look* — colour treatment, lighting,
// glass, metal, edges — and must not move a single corner of what is built.
// So this test fingerprints geometry only: the design's own shapes, and every
// facet's corners, part and role, never its colour, transparency or gloss.
// A change that only repaints leaves every fingerprint here as it was.
//
// A fingerprint that changes is not a test to be updated in passing. It
// means the geometry moved. Where that is the point of the change — a seal
// that is now real material along the glass's edge — update the figure here
// on purpose and say so in the commit; where it is not, the change is wrong.

Stroke pen(String id, List<Vec2> through) {
  final samples = <StrokeSample>[];
  for (var leg = 0; leg + 1 < through.length; leg++) {
    for (var i = 0; i < 30; i++) {
      samples.add(StrokeSample(through[leg].lerp(through[leg + 1], i / 30)));
    }
  }
  return Stroke(id: id, samples: [...samples, StrokeSample(through.last)]);
}

List<Vec2> chevron(Vec2 at) => [
  Vec2(at.x - 55, at.y - 110),
  Vec2(at.x + 55, at.y),
  Vec2(at.x - 55, at.y + 110),
];

Design read(Design design, List<Stroke> strokes) => SketchInterpreter.interpret(
  design.copyWith(sketch: Sketch(strokes: strokes)),
).design;

List<Vec2> rectangle(double w, double h) => [
  const Vec2(0, 0),
  Vec2(w, 0),
  Vec2(w, h),
  Vec2(0, h),
  const Vec2(0, 0),
];

final at = DateTime(2026, 3, 1, 9);

/// A door: a mullion, the left light marked, a line drawn inside that
/// opening, glass above it and a panel below — every kind of part the
/// renderers draw: frame, bar, sash, glass, panel, hinges, handle, lock.
Design door() {
  final base = Design.empty(
    id: 'door',
    kind: DesignKind.door,
    name: 'Door',
    now: at,
  );
  final strokes = [
    pen('outline', rectangle(1600, 2100)),
    pen('mullion', const [Vec2(1000, 0), Vec2(1000, 2100)]),
    pen('mark', chevron(const Vec2(450, 1000))),
  ];
  final marked = read(base, strokes);
  final divided = read(marked, [
    ...marked.sketch.strokes,
    pen('inside', const [Vec2(150, 1400), Vec2(850, 1400)]),
  ]);
  final panes = divided.childSectionsOf(divided.openings.single.sectionId)
    ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
  return Infill.fill(divided, {
    panes.first.id: GlassLook.frosted.finish,
    panes.last.id: PanelColour.brown.finish,
  });
}

/// A window: a mullion, a transom across the right light, the left marked.
Design window() => read(
  Design.empty(id: 'window', kind: DesignKind.window, name: 'Window', now: at),
  [
    pen('outline', rectangle(1800, 1200)),
    pen('mullion', const [Vec2(700, 0), Vec2(700, 1200)]),
    pen('transom', const [Vec2(700, 500), Vec2(1800, 500)]),
    pen('mark', chevron(const Vec2(350, 600))),
  ],
);

/// A sliding pair: two panels, the left one marked to slide.
Design sliding() => read(
  Design.empty(
    id: 'sliding',
    kind: DesignKind.sliding,
    name: 'Sliding',
    now: at,
  ),
  [
    pen('outline', rectangle(2400, 2100)),
    pen('meeting', const [Vec2(1200, 0), Vec2(1200, 2100)]),
    pen('mark', chevron(const Vec2(600, 1050))),
  ],
);

/// A stable 64-bit FNV-1a hash of [text], written in hex — enough to tell
/// one geometry from another without keeping the whole of it in the test.
String fnv(String text) {
  var hash = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;
  for (final unit in utf8.encode(text)) {
    hash = ((hash ^ BigInt.from(unit)) * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

/// The design's own geometry — what both views are drawn from — without
/// anything about how it looks or when it was edited.
String designGeometry(Design design) {
  final json = jsonDecode(jsonEncode(design.toJson())) as Map<String, Object?>
    ..remove('createdAt')
    ..remove('updatedAt');
  void strip(Object? node) {
    if (node is Map<String, Object?>) {
      node.remove('finish');
      node.remove('colour');
      node.values.forEach(strip);
    } else if (node is List) {
      node.forEach(strip);
    }
  }

  strip(json);
  json.remove('infill');
  return jsonEncode(json);
}

/// Every facet's corners, part and role — never its colour, transparency
/// or gloss, which are appearance.
String meshGeometry(Mesh mesh) => [
  for (final facet in mesh.facets)
    [
      facet.elementId,
      facet.role.name,
      facet.part ?? '',
      for (final c in facet.corners)
        '${c.x.toStringAsFixed(2)},'
            '${c.y.toStringAsFixed(2)},'
            '${c.z.toStringAsFixed(2)}',
    ].join('|'),
].join('\n');

void main() {
  final designs = {'door': door(), 'window': window(), 'sliding': sliding()};

  test('the three designs are what they say they are', () {
    final d = designs['door']!;
    expect(d.frame, isNotNull);
    expect(d.openings, hasLength(1));
    expect(d.dividers.where((b) => b.parentId != null), hasLength(1));
    expect(
      d.sections.map((s) => s.finish.material).toSet(),
      containsAll([MaterialKind.frostedGlass, MaterialKind.panel]),
    );
    expect(d.hardware, isNotEmpty);
    expect(designs['window']!.openings, hasLength(1));
    expect(designs['sliding']!.openings, hasLength(1));
  });

  // The fingerprints as the geometry stood when the CAD and 3D audit was
  // written. Keyed by design, then by what was fingerprinted.
  const pinned = <String, Map<String, String>>{
    'door': {
      'design': 'ae3cfe6089559a06',
      'shut': 'f0c6fb11c2c3f44a',
      'open': 'd5ef2ef09699c719',
    },
    'window': {
      'design': '4f27d2f58f42a604',
      'shut': '98fce4023f819c2b',
      'open': 'd7da8fe47c3965a5',
    },
    'sliding': {
      'design': '9253e5c841c1026c',
      'shut': '8253ab439ee87dbf',
      'open': 'cee840fe27ca12f7',
    },
  };

  for (final MapEntry(key: name, value: design) in designs.entries) {
    test('$name: the geometry both views are built from is as pinned', () {
      final found = {
        'design': fnv(designGeometry(design)),
        'shut': fnv(meshGeometry(MeshBuilder.build(design))),
        'open': fnv(meshGeometry(MeshBuilder.build(design, openFraction: 1))),
      };
      expect(found, pinned[name], reason: '$name: $found');
    });
  }

  test('the fingerprints see geometry and nothing else', () {
    final design = designs['door']!;
    final repainted = design.copyWith(
      frame: design.frame!.copyWith(
        finish: const Finish(
          colour: 0xFF222222,
          material: MaterialKind.aluminium,
        ),
      ),
    );
    expect(
      meshGeometry(MeshBuilder.build(repainted)),
      meshGeometry(MeshBuilder.build(design)),
      reason: 'a colour and a material are not geometry',
    );
    expect(designGeometry(repainted), designGeometry(design));
    final moved = design.copyWith(depthMm: design.depthMm + 10);
    expect(
      meshGeometry(MeshBuilder.build(moved)),
      isNot(meshGeometry(MeshBuilder.build(design))),
      reason: 'a depth is',
    );
  });
}
