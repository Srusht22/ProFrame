import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/utilities/geometry_math.dart';
import 'package:proframe/features/geometry/region_solver.dart';
import 'package:proframe/shared/models/design_region.dart';
import 'package:proframe/shared/models/materials.dart';
import 'package:proframe/shared/models/opening_model.dart';

DesignRegion region(
  String id,
  double x,
  double y,
  double w,
  double h, {
  CellOperation operation = CellOperation.fixed,
  CellInfill infill = CellInfill.glass,
}) =>
    DesignRegion(
      id: id,
      rect: Box2.fromLTWH(x, y, w, h),
      operation: operation,
      infill: infill,
    );

OpeningModel model(List<DesignRegion> regions, {double w = 2000, double h = 1600}) =>
    OpeningModel(
      id: 'm',
      kind: OpeningKind.window,
      widthMm: w,
      heightMm: h,
      regions: regions,
    );

void main() {
  group('the worked example from the brief, exactly', () {
    // 200 cm x 160 cm window. Left opening 40 cm wide, full height. A 40 x 40
    // opening at the top-right. Glass and panel filling the rest.
    late OpeningModel window;

    setUp(() {
      window = model([
        region('left', 0, 0, 400, 1600, operation: CellOperation.casementLeft),
        region('topRight', 1600, 0, 400, 400, operation: CellOperation.awning),
        region('upperGlass', 400, 0, 1200, 400),
        region('midGlass', 400, 400, 1600, 600),
        region('lowerPanel', 400, 1000, 1600, 600, infill: CellInfill.panel),
      ]);
    });

    test('the sections keep the exact sizes they were given', () {
      final solved = RegionSolver.solve(window);

      expect(solved.byId('left')!.rect.width, 400);
      expect(solved.byId('left')!.rect.height, 1600);
      expect(solved.byId('topRight')!.rect.width, 400);
      expect(solved.byId('topRight')!.rect.height, 400);
    });

    test('the 40 x 40 opening stays in the top-right corner', () {
      final solved = RegionSolver.solve(window);
      final rect = solved.byId('topRight')!.rect;

      expect(rect.right, window.widthMm, reason: 'must stay against the right edge');
      expect(rect.top, 0, reason: 'must stay against the top edge');
      expect(rect.width, rect.height, reason: '400 x 400 as asked');
    });

    test('a corner opening does not divide the rest of the product', () {
      final solved = RegionSolver.solve(window);

      // The section below the corner opening still spans from the left
      // opening all the way to the right edge — the corner did not push a
      // mullion through it.
      final mid = solved.byId('midGlass')!.rect;
      expect(mid.left, 400);
      expect(mid.right, 2000);
      expect(mid.width, 1600);
    });

    test('the sections add up to the overall dimensions', () {
      final area = window.regions
          .fold<double>(0, (sum, r) => sum + r.rect.width * r.rect.height);
      expect(area, window.widthMm * window.heightMm);
    });

    test('profile is generated around the corner opening automatically', () {
      final solved = RegionSolver.solve(window);

      // An L of profile: something vertical beside it and something
      // horizontal beneath it.
      final bars = solved.bars;
      expect(bars, isNotEmpty);
      expect(bars.any((b) => b.vertical), isTrue);
      expect(bars.any((b) => !b.vertical), isTrue);
    });

    test('no aperture overlaps another', () {
      final solved = RegionSolver.solve(window);
      final apertures = solved.topRegions.map((r) => r.aperture).toList();

      for (var i = 0; i < apertures.length; i++) {
        for (var j = i + 1; j < apertures.length; j++) {
          expect(
            apertures[i].overlaps(apertures[j]),
            isFalse,
            reason: 'apertures $i and $j overlap',
          );
        }
      }
    });

    test('every aperture sits inside the frame', () {
      final solved = RegionSolver.solve(window);

      for (final region in solved.topRegions) {
        expect(region.aperture.left, greaterThanOrEqualTo(solved.innerRect.left - 0.001));
        expect(region.aperture.top, greaterThanOrEqualTo(solved.innerRect.top - 0.001));
        expect(region.aperture.right, lessThanOrEqualTo(solved.innerRect.right + 0.001));
        expect(
          region.aperture.bottom,
          lessThanOrEqualTo(solved.innerRect.bottom + 0.001),
        );
      }
    });
  });

  group('sections are bounded by frame outside and half a bar inside', () {
    test('a 400 + 1600 split still totals the overall width', () {
      final window = model([
        region('a', 0, 0, 400, 1600),
        region('b', 400, 0, 1600, 1600),
      ]);
      final solved = RegionSolver.solve(window);
      final frameFace = window.material.frameFaceMm;
      final barFace = window.material.mullionFaceMm;

      final a = solved.byId('a')!.aperture;
      final b = solved.byId('b')!.aperture;

      expect(a.left, frameFace);
      expect(a.right, 400 - barFace / 2);
      expect(b.left, 400 + barFace / 2);
      expect(b.right, 2000 - frameFace);

      // Apertures plus the frame and the single mullion account for the whole
      // width, with nothing lost or invented.
      expect(a.width + b.width + barFace + 2 * frameFace, closeTo(2000, 0.001));
    });

    test('one section filling the product gets frame on all four sides', () {
      final window = model([region('only', 0, 0, 2000, 1600)]);
      final solved = RegionSolver.solve(window);
      final aperture = solved.byId('only')!.aperture;

      expect(aperture, isNotNull);
      expect(aperture.left, window.material.frameFaceMm);
      expect(aperture.right, 2000 - window.material.frameFaceMm);
      expect(solved.bars, isEmpty, reason: 'nothing left over, so no bars');
    });
  });

  group('asymmetry survives', () {
    test('a deliberately lopsided design is not equalised', () {
      final window = model([
        region('narrow', 0, 0, 300, 1600),
        region('wide', 300, 0, 1700, 1600),
      ]);
      final solved = RegionSolver.solve(window);

      expect(solved.byId('narrow')!.rect.width, 300);
      expect(solved.byId('wide')!.rect.width, 1700);
      expect(
        solved.byId('wide')!.aperture.width,
        greaterThan(solved.byId('narrow')!.aperture.width * 4),
      );
    });

    test('an off-centre opening is not moved to the middle', () {
      final window = model([
        region('opening', 120, 90, 400, 400, operation: CellOperation.awning),
        region('rest', 0, 490, 2000, 1110),
      ]);
      final solved = RegionSolver.solve(window);

      expect(solved.byId('opening')!.rect.left, 120);
      expect(solved.byId('opening')!.rect.top, 90);
    });
  });

  group('tapping picks the section under the finger', () {
    test('the deepest section wins, so a pane inside a leaf is selectable', () {
      final window = model([
        DesignRegion(
          id: 'leaf',
          rect: Box2.fromLTWH(0, 0, 2000, 1600),
          operation: CellOperation.casementRight,
          children: [
            region('upper', 0, 0, 2000, 900),
            region('lower', 0, 900, 2000, 700, infill: CellInfill.panel),
          ],
        ),
      ]);
      final solved = RegionSolver.solve(window);

      expect(solved.regionAt(const Vec2(1000, 400))!.id, 'upper');
      expect(solved.regionAt(const Vec2(1000, 1200))!.id, 'lower');
    });
  });

  group('derived quantities follow the geometry', () {
    test('glass area counts only the glazed sections', () {
      final window = model([
        region('glass', 0, 0, 2000, 800),
        region('panel', 0, 800, 2000, 800, infill: CellInfill.panel),
      ]);
      final solved = RegionSolver.solve(window);

      expect(solved.totalGlassAreaM2, greaterThan(0));
      expect(solved.totalPanelAreaM2, greaterThan(0));
      expect(
        solved.totalGlassAreaM2,
        closeTo(solved.totalPanelAreaM2, 0.01),
        reason: 'the halves were specified equal',
      );
    });

    test('moving a boundary changes the areas in step', () {
      final half = model([
        region('glass', 0, 0, 2000, 800),
        region('panel', 0, 800, 2000, 800, infill: CellInfill.panel),
      ]);
      final seventy = model([
        region('glass', 0, 0, 2000, 1120),
        region('panel', 0, 1120, 2000, 480, infill: CellInfill.panel),
      ]);

      final a = RegionSolver.solve(half);
      final b = RegionSolver.solve(seventy);

      expect(b.totalGlassAreaM2, greaterThan(a.totalGlassAreaM2));
      expect(b.totalPanelAreaM2, lessThan(a.totalPanelAreaM2));
    });
  });
}
