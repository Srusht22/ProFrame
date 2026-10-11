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

  // The fingerprints of the geometry. Keyed by design, then by what was
  // fingerprinted.
  //
  // The designs' own fingerprints are as they were when the CAD and 3D
  // audit was written, and have never moved. The solid's moved twice, on
  // purpose. First when the frame and the sash became their profile swept round
  // the ring and the bars' long front edges were eased (the frame is a real
  // profile, see the_frame_is_a_real_profile_test.dart) — every one of
  // those new corners inside the outline, the daylight and the depth the
  // plain ring had. Before that the solid was: door f0c6fb11c2c3f44a /
  // d5ef2ef09699c719, window 98fce4023f819c2b / d7da8fe47c3965a5, sliding
  // 8253ab439ee87dbf / cee840fe27ca12f7.
  //
  // Then when a panel's faces were given the small eased arris a finished
  // panel has (panels are solid, see panels_look_like_panels_test.dart):
  // every new corner inside the pane's fill and its thickness, and only the
  // door — the one design here with a panel — moved. Before that the door
  // was 1eaebb46c455cad2 / 28e1f7f336edbf2f.
  //
  // Then when the ironmongery was built as the pieces it is (Phase 7: the
  // lever one bent piece closed in a dome, the rose, boss and knuckle
  // turned, plates pressed with a rounded edge, a hinge's leaf lying on the
  // face it is screwed to rather than off it): every design's solid moved,
  // and only its ironmongery — every facet that is not ironmongery was
  // checked unchanged, shut and open, and each piece still covers exactly
  // the shapes the drawings draw. Before that the solids were: door
  // 926fa8e9b336512a / 870c6b3cd760cbcf, window 4e543030cc8b4b5f /
  // 8818175eaf4a47fd, sliding 27a71776216ea173 / 6741b95707a4e4d3.
  //
  // Then when depth was given one layout (Phase 8, depth_is_consistent_test
  // .dart): glass built as the sealed unit it is — two sheets, a cavity, an
  // edge seal — held by a glazing bead on the room side; the bars and panes
  // inside a sash standing in the sash's depth rather than against the
  // frame's; one rule for how thick glass and a panel are. Every point the
  // solids had on the face is still there, and the only new ones are the
  // beads' lines on the glass; the designs' own fingerprints did not move. Before that the solids were: door
  // 8d14e9dad135c003 / 4d07d3ee035bbfbf, window 6522b314a64d229f /
  // 2aa8882908f50747, sliding 69ec0b3f0d12b02d / 97efb4a8b4f5b30f.
  const pinned = <String, Map<String, String>>{
    'door': {
      'design': 'ae3cfe6089559a06',
      'shut': '71a9140f78d40c09',
      'open': 'c6e142a513e43739',
    },
    'window': {
      'design': '4f27d2f58f42a604',
      'shut': 'e21c512d074e62cb',
      'open': '45dee86148b7ac59',
    },
    'sliding': {
      'design': '9253e5c841c1026c',
      'shut': '65e6a07d082ef5ab',
      'open': 'c51a25dc85c614b3',
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
    // The frame recoloured, and the ironmongery made of another metal. (A
    // frame made of another material is another profile — an extrusion is
    // not shaped like a PVC chamber — which the frame tests hold.)
    final repainted = design.copyWith(
      frame: design.frame!.copyWith(
        finish: design.frame!.finish.copyWith(colour: 0xFF222222),
      ),
      hardware: [
        for (final p in design.hardware)
          p.copyWith(
            finish: p.finish.copyWith(material: MaterialKind.aluminium),
          ),
      ],
    );
    expect(
      meshGeometry(MeshBuilder.build(repainted)),
      meshGeometry(MeshBuilder.build(design)),
      reason: 'a colour and a finish are not geometry',
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
