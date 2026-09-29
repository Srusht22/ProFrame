import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/model/design.dart';
import 'package:proframe/domain/model/design_geometry.dart';
import 'package:proframe/domain/model/elements.dart';
import 'package:proframe/domain/model/infill.dart';
import 'package:proframe/domain/model/materials.dart';
import 'package:proframe/domain/model/surface.dart';
import 'package:proframe/domain/solid/mesh.dart';
import 'package:proframe/domain/solid/mesh_builder.dart';
import 'package:proframe/domain/solid/shading.dart';

import 'rendering_geometry_baseline_test.dart' as base;

// Phase 3 of the CAD and 3D work: a real material system.
//
// Every part is made of something — glass, panel, PVC, aluminium, rubber,
// metal, a handle's metal, a hinge's — and each is described physically
// ([Surface]): how much light it lets through, how rough it is, whether it
// is a metal, how much it reflects, how its edges read, its texture and how
// the technical drawing indicates it. The solid lights every face from
// that description ([Shading.of]); the colour is the user's and nothing
// else.
//
// Held here: the materials are what they say, they look different from one
// another *for the reasons they are different* — with the colour held the
// same — and appearance never reaches geometry.

/// A face square on to the viewer.
const squareOn = Vec3(0, 0, 1);

/// A face tipped up towards the sky, and one tipped down towards the
/// ground, both still facing the viewer.
final tippedUp = const Vec3(0, -0.64, 0.77).normalised;
final tippedDown = const Vec3(0, 0.64, 0.77).normalised;

/// Glancing: nearly edge on to the viewer.
final glancing = const Vec3(0.97, 0, 0.24).normalised;

Shaded shade(Surface surface, int colour, Vec3 normal, {bool side = false}) =>
    Shading.of(
      surface: surface,
      colour: colour,
      normal: normal,
      environment: Environment.daylight,
      side: side,
    );

double luminance(Shaded s) => Rgb.of(s.colour).luminance;

const white = 0xFFF3F4F2;
const black = 0xFF1C1C1C;

void main() {
  group('the materials', () {
    test('every kind the work asks for is there, each once', () {
      final kinds = Surfaces.all.map((s) => s.kind).toSet();
      for (final kind in [
        MaterialClass.glass,
        MaterialClass.panel,
        MaterialClass.pvc,
        MaterialClass.aluminium,
        MaterialClass.rubber,
        MaterialClass.metal,
        MaterialClass.handleMetal,
        MaterialClass.hingeMetal,
      ]) {
        expect(kinds, contains(kind));
      }
      final ids = Surfaces.all.map((s) => s.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final s in Surfaces.all) {
        for (final figure in [
          s.transmission,
          s.scatter,
          s.roughness,
          s.metallic,
          s.reflectivity,
          s.edge.darkness,
        ]) {
          expect(figure, inInclusiveRange(0, 1), reason: s.id);
        }
      }
    });

    test('every material a part can be saved as is a surface', () {
      for (final kind in MaterialKind.values) {
        expect(Surfaces.all, contains(kind.surface), reason: kind.name);
      }
      expect(MaterialKind.rubber.surface, Surfaces.rubber);
    });

    test('each is described by what it physically is', () {
      // Only glass — and a mesh screen — lets light through.
      for (final s in Surfaces.all) {
        final seeThrough =
            s.kind == MaterialClass.glass || s.kind == MaterialClass.mesh;
        expect(s.isTransparent, seeThrough, reason: s.id);
      }
      expect(
        Surfaces.clearGlass.transmission,
        greaterThan(Surfaces.tintedGlass.transmission),
      );
      expect(
        Surfaces.tintedGlass.transmission,
        greaterThan(Surfaces.frostedGlass.transmission),
      );
      expect(Surfaces.frostedGlass.scatter, greaterThan(0.5));
      expect(Surfaces.frostedGlass.texture, SurfaceTexture.frosted);
      expect(Surfaces.clearGlass.scatter, 0);

      // Metals are metals; nothing else is wholly one.
      for (final s in [
        Surfaces.metal,
        Surfaces.handleMetal,
        Surfaces.hingeMetal,
      ]) {
        expect(s.metallic, 1, reason: s.id);
      }
      for (final s in [Surfaces.pvc, Surfaces.panel, Surfaces.rubber]) {
        expect(s.metallic, 0, reason: s.id);
      }
      expect(Surfaces.aluminium.metallic, greaterThan(Surfaces.pvc.metallic));

      // A handle is finished to be held; a hinge is satin.
      expect(
        Surfaces.handleMetal.roughness,
        lessThan(Surfaces.hingeMetal.roughness),
      );

      // Rubber is the roughest and reflects least of all.
      for (final s in Surfaces.all.where((s) => s != Surfaces.rubber)) {
        expect(Surfaces.rubber.roughness, greaterThan(s.roughness));
        expect(Surfaces.rubber.reflectivity, lessThanOrEqualTo(s.reflectivity));
      }

      // A painted panel is matte beside a PVC profile's satin.
      expect(Surfaces.panel.roughness, greaterThan(Surfaces.pvc.roughness));
      // Float glass is green edge on.
      final edge = Rgb.of(Surfaces.clearGlass.edge.sideTint!);
      expect(edge.g, greaterThan(edge.r));
    });

    test('the renderers ask a material what it is like, never which it is', () {
      // So a new material is a new [Surface] and nothing else: neither view
      // has a list of materials of its own to fall out of step.
      for (final path in [
        'lib/domain/solid/shading.dart',
        'lib/app/viewer/model_painter.dart',
        'lib/app/canvas/cad_painter.dart',
      ]) {
        final source = File(path).readAsStringSync();
        for (final named in [
          'Surfaces.',
          'MaterialClass.',
          'isGlazing',
          'MaterialKind.',
        ]) {
          expect(source.contains(named), isFalse, reason: '$path: $named');
        }
      }
    });

    test('the drawing indicates each as a drawing does', () {
      expect(Surfaces.clearGlass.cad.hatch, CadHatch.glazing);
      expect(Surfaces.clearGlass.cad.ownColour, isFalse);
      expect(Surfaces.panel.cad.hatch, CadHatch.diagonal);
      expect(Surfaces.panel.cad.ownColour, isTrue);
      expect(Surfaces.rubber.cad.hatch, CadHatch.solid);
    });
  });

  group('they look different for the reasons they are different', () {
    test('in the same colour, glass is seen through and the rest are not', () {
      final glass = shade(Surfaces.clearGlass, white, squareOn);
      expect(glass.filter, isNotNull, reason: 'what is behind shows');
      expect(glass.opacity, 0, reason: 'clear glass shows nothing of itself');
      for (final s in [
        Surfaces.panel,
        Surfaces.pvc,
        Surfaces.aluminium,
        Surfaces.metal,
        Surfaces.rubber,
      ]) {
        final solid = shade(s, white, squareOn);
        expect(solid.opacity, 1, reason: s.id);
        expect(solid.filter, isNull, reason: s.id);
      }
    });

    test('the two faces of a pane let through what the glass lets through', () {
      for (final glass in [
        Surfaces.clearGlass,
        Surfaces.tintedGlass,
        Surfaces.frostedGlass,
      ]) {
        // In white, so the filter is the glass's transmission alone.
        final face = Rgb.of(shade(glass, 0xFFFFFFFF, squareOn).filter!)
            .luminance;
        final f = glass.reflectivity;
        expect(
          face * face,
          closeTo(glass.transmission * (1 - f) * (1 - f), 0.01),
          reason: glass.id,
        );
      }
    });

    test('tinted glass darkens the view through it more than clear', () {
      double through(Surface s, int colour) =>
          Rgb.of(shade(s, colour, squareOn).filter!).luminance;
      expect(
        through(Surfaces.tintedGlass, GlassLook.tinted.colour),
        lessThan(through(Surfaces.clearGlass, GlassLook.clear.colour) - 0.15),
      );
    });

    test('frosted glass hides more and glows lighter than clear', () {
      final clear = shade(Surfaces.clearGlass, 0xFFD8E6EA, squareOn);
      final frosted = shade(Surfaces.frostedGlass, 0xFFD8E6EA, squareOn);
      expect(frosted.opacity, greaterThan(clear.opacity + 0.3));
      expect(luminance(frosted), greaterThan(0.8));
    });

    test('glass reflects more at a glancing angle than square on', () {
      double reflects(Vec3 n) =>
          Rgb.of(shade(Surfaces.clearGlass, 0xFFD8E6EA, n).reflection!)
              .luminance;
      expect(reflects(glancing), greaterThan(reflects(squareOn) + 0.15));
    });

    test('glass edge on is its green body, not a view through it', () {
      final side = shade(
        Surfaces.clearGlass,
        0xFFD8E6EA,
        const Vec3(1, 0, 0.2),
        side: true,
      );
      expect(side.opacity, greaterThan(0.8));
      final c = Rgb.of(side.colour);
      expect(c.g, greaterThan(c.r));
    });

    test('a metal mirrors the sky and the ground; a matte panel hardly '
        'does', () {
      // Lit from the eye, so both faces take the same light and what
      // differs between them is only what they reflect.
      final fromTheEye = Environment(
        light: const Vec3(0, 0, 1),
        sky: Environment.daylight.sky,
        horizon: Environment.daylight.horizon,
        ground: Environment.daylight.ground,
      );
      double look(Surface s, Vec3 n) => Rgb.of(
        Shading.of(
          surface: s,
          colour: white,
          normal: n,
          environment: fromTheEye,
        ).colour,
      ).luminance;
      double swing(Surface s) =>
          (look(s, tippedUp) - look(s, tippedDown)).abs();
      expect(
        swing(Surfaces.handleMetal),
        greaterThan(swing(Surfaces.panel) * 2),
      );
      expect(swing(Surfaces.handleMetal), greaterThan(0.08));
    });

    test('a metal reflects in its own colour; plastic reflects white', () {
      // Black: whatever lightens it is reflection. Glancing, a black
      // plastic shows the white sky; black metal stays black metal.
      final plastic = luminance(shade(Surfaces.pvc, black, glancing));
      final metal = luminance(shade(Surfaces.handleMetal, black, glancing));
      expect(plastic, greaterThan(metal * 2));

      // And a bronze handle's reflection is bronze.
      const bronze = 0xFF8C6A3F;
      final c = Rgb.of(shade(Surfaces.handleMetal, bronze, tippedUp).colour);
      expect(c.r, greaterThan(c.b + 0.1));
    });

    test('a polished handle catches the light that a satin hinge spreads', () {
      // Square to the half-way between the light and the eye: the highlight.
      final atHighlight =
          (Environment.daylight.light + const Vec3(0, 0, 1)).normalised;
      final handle = luminance(
        shade(Surfaces.handleMetal, 0xFF7C8285, atHighlight),
      );
      final hinge = luminance(
        shade(Surfaces.hingeMetal, 0xFF7C8285, atHighlight),
      );
      expect(handle, greaterThan(hinge));
    });

    test('rubber is dark and rough: it barely changes whichever way it '
        'faces', () {
      const gasket = 0xFF161616;
      final looks = [
        for (final n in [squareOn, tippedUp, tippedDown, glancing])
          luminance(shade(Surfaces.rubber, gasket, n)),
      ];
      for (final l in looks) {
        expect(l, lessThan(0.15));
      }
      final pvc = [
        for (final n in [squareOn, tippedUp, tippedDown, glancing])
          luminance(shade(Surfaces.pvc, gasket, n)),
      ];
      double spread(List<double> v) =>
          v.reduce((a, b) => a > b ? a : b) - v.reduce((a, b) => a < b ? a : b);
      expect(spread(looks), lessThan(spread(pvc)));
    });

    test('a face turned from the light is darker, whatever it is made of', () {
      final towards = Environment.daylight.light;
      final away = const Vec3(0.6, 0.6, 0.53).normalised;
      for (final s in [Surfaces.pvc, Surfaces.panel, Surfaces.aluminium]) {
        expect(
          luminance(shade(s, 0xFF8C9094, towards)),
          greaterThan(luminance(shade(s, 0xFF8C9094, away))),
          reason: s.id,
        );
      }
    });

    test('the user\'s colour is what is lit: a darker panel is darker', () {
      expect(
        luminance(shade(Surfaces.panel, PanelColour.white.colour, squareOn)),
        greaterThan(
          luminance(shade(Surfaces.panel, PanelColour.brown.colour, squareOn)),
        ),
      );
    });
  });

  group('the solid says what each part is made of', () {
    final door = base.door();
    final mesh = MeshBuilder.build(door);

    Iterable<Facet> of(String id) =>
        mesh.facets.where((f) => f.elementId == id);

    test('frame, glass, panel, handle and hinge each their own', () {
      expect(of(door.frame!.id).map((f) => f.surface).toSet(), {Surfaces.pvc});
      final panes = door.childSectionsOf(door.openings.single.sectionId)
        ..sort((a, b) => a.outline.top.compareTo(b.outline.top));
      expect(of(panes.first.id).map((f) => f.surface).toSet(), {
        Surfaces.frostedGlass,
      });
      expect(of(panes.last.id).map((f) => f.surface).toSet(), {Surfaces.panel});
      for (final piece in door.hardware) {
        final expected = switch (piece.kind) {
          HardwareKind.hinge => Surfaces.hingeMetal,
          _ => Surfaces.handleMetal,
        };
        expect(of(piece.id).map((f) => f.surface).toSet(), {
          expected,
        }, reason: piece.kind.name);
      }
    });

    test('a piece the user makes plastic is plastic', () {
      final lever = door.hardware.firstWhere(
        (p) => p.kind == HardwareKind.lever,
      );
      final plastic = door.copyWith(
        hardware: [
          for (final p in door.hardware)
            p.id == lever.id
                ? p.copyWith(
                    finish: const Finish(
                      colour: 0xFFF2F2F0,
                      material: MaterialKind.upvc,
                    ),
                  )
                : p,
        ],
      );
      expect(
        MeshBuilder.build(plastic).facets
            .where((f) => f.elementId == lever.id)
            .map((f) => f.surface)
            .toSet(),
        {Surfaces.pvc},
      );
    });

    test('the thin sides of the glass are known to be sides', () {
      final glass = mesh.facets.where((f) => f.role == FacetRole.glazing);
      expect(glass.where((f) => f.isSide), isNotEmpty);
      // Each pane has two faces, front and back; the rest are its sides.
      for (final id in glass.map((f) => f.elementId).toSet()) {
        expect(
          glass.where((f) => f.elementId == id && !f.isSide),
          hasLength(2),
          reason: id,
        );
      }
    });

    test('no colour has light baked into it: every face is its part\'s own '
        'colour', () {
      int colourOf(String id) {
        if (door.frame!.id == id) return door.frame!.finish.colour;
        final section = door.sectionById(id);
        if (section != null) return section.finish.colour;
        return door.dividerById(id)!.finish.colour;
      }

      for (final facet in mesh.facets) {
        if (facet.role == FacetRole.hardware) continue;
        // A sash is the frame's profile, in the frame's finish.
        final expected = facet.role == FacetRole.sash
            ? door.frame!.finish.colour
            : colourOf(facet.elementId);
        expect(facet.colour, expected, reason: facet.role.name);
      }
    });
  });

  group('appearance never reaches geometry', () {
    final door = base.door();
    final shape = base.designGeometry(door);
    final shut = base.meshGeometry(MeshBuilder.build(door));
    final open = base.meshGeometry(MeshBuilder.build(door, openFraction: 1));

    final panes = door.childSectionsOf(door.openings.single.sectionId)
      ..sort((a, b) => a.outline.top.compareTo(b.outline.top));

    final changes = <String, Design>{
      'the panel recoloured': Infill.fill(door, {
        panes.last.id: PanelColour.white.finish,
      }),
      'the glass made clear': Infill.fill(door, {
        panes.first.id: GlassLook.clear.finish,
      }),
      'the glass made tinted': Infill.fill(door, {
        panes.first.id: GlassLook.dark.finish,
      }),
      'the frame made black': door.copyWith(
        frame: door.frame!.copyWith(
          finish: const Finish(
            colour: 0xFF1E1F1F,
            material: MaterialKind.upvc,
          ),
        ),
      ),
      'the ironmongery in bronze': door.copyWith(
        hardware: [
          for (final p in door.hardware)
            p.copyWith(
              finish: Finish(
                colour: HardwareColour.bronze.colour,
                material: MaterialKind.aluminium,
              ),
            ),
        ],
      ),
    };

    for (final MapEntry(key: what, value: changed) in changes.entries) {
      test('$what: every size, line and corner is where it was', () {
        expect(base.designGeometry(changed), shape);
        expect(base.meshGeometry(MeshBuilder.build(changed)), shut);
        expect(
          base.meshGeometry(MeshBuilder.build(changed, openFraction: 1)),
          open,
        );
        final before = DesignGeometry.of(door);
        final after = DesignGeometry.of(changed);
        for (final bar in door.dividers) {
          expect(
            after.barBody(changed.dividerById(bar.id)!).corners,
            before.barBody(bar).corners,
          );
        }
        for (final section in door.sections) {
          expect(
            after.fillOf(changed.sectionById(section.id)!).corners,
            before.fillOf(section).corners,
          );
        }
      });
    }

    test('the panel made glass: every size and line where it was, and only '
        'the infill\'s own thickness built as glass is', () {
      final glazed = Infill.fill(door, {
        panes.last.id: GlassLook.frosted.finish,
      });
      expect(base.designGeometry(glazed), shape);
      // Everything but that pane is built exactly as before…
      String without(Design d) => base.meshGeometry(
        Mesh([
          for (final f in MeshBuilder.build(d).facets)
            if (f.elementId != panes.last.id) f,
        ]),
      );
      expect(without(glazed), without(door));
      // …and the pane covers the same ground: a sealed unit and a panel are
      // built to their own thicknesses, which is construction, not
      // appearance.
      Set<String> across(Design d) => {
        for (final f in MeshBuilder.build(d).facets)
          if (f.elementId == panes.last.id)
            for (final c in f.corners)
              '${c.x.toStringAsFixed(3)},${c.y.toStringAsFixed(3)}',
      };
      expect(across(glazed), across(door));
    });

    test('the frame made aluminium: every size and line where it was, and '
        'only the frame\'s own section an extrusion\'s', () {
      final aluminium = door.copyWith(
        frame: door.frame!.copyWith(
          finish: const Finish(
            colour: 0xFF1E1F1F,
            material: MaterialKind.aluminium,
          ),
        ),
      );
      expect(base.designGeometry(aluminium), shape);
      // Everything but the frame and the sash — which is made of the
      // frame's material — is built exactly as before…
      String without(Design d) => base.meshGeometry(
        Mesh([
          for (final f in MeshBuilder.build(d).facets)
            if (f.role != FacetRole.frame && f.role != FacetRole.sash) f,
        ]),
      );
      expect(without(aluminium), without(door));
      // …and the frame stands on the same outline to the millimetre.
      List<double> extent(Design d) {
        final xs = <double>[], ys = <double>[], zs = <double>[];
        for (final f in MeshBuilder.build(d).facets) {
          if (f.role != FacetRole.frame) continue;
          for (final c in f.corners) {
            xs.add(c.x);
            ys.add(c.y);
            zs.add(c.z);
          }
        }
        double lo(List<double> v) => v.reduce((a, b) => a < b ? a : b);
        double hi(List<double> v) => v.reduce((a, b) => a > b ? a : b);
        return [lo(xs), hi(xs), lo(ys), hi(ys), lo(zs), hi(zs)];
      }

      expect(extent(aluminium), extent(door));
    });

    test('and the look does change: it is appearance that moved', () {
      final recoloured = MeshBuilder.build(changes['the panel recoloured']!);
      final panel = recoloured.facets.firstWhere(
        (f) => f.elementId == panes.last.id,
      );
      expect(panel.colour, PanelColour.white.colour);
      final aluminium = MeshBuilder.build(
        door.copyWith(
          frame: door.frame!.copyWith(
            finish: const Finish(
              colour: 0xFF1E1F1F,
              material: MaterialKind.aluminium,
            ),
          ),
        ),
      );
      expect(
        aluminium.facets
            .firstWhere((f) => f.elementId == door.frame!.id)
            .surface,
        Surfaces.aluminium,
      );
    });
  });
}
