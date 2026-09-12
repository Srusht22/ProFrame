import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/errors/app_exception.dart';
import 'package:proframe/core/units/length_unit.dart';
import 'package:proframe/domain/design_document.dart';
import 'package:proframe/domain/design_question.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/measurement.dart';
import 'package:proframe/domain/panel.dart';
import 'package:proframe/domain/panel_divider.dart';
import 'package:proframe/domain/product/finish.dart';
import 'package:proframe/domain/product/infill.dart';
import 'package:proframe/domain/product/opening.dart';
import 'package:proframe/domain/product/product_basics.dart';
import 'package:proframe/domain/sketch.dart';


/// A two-bay window: a fixed left pane and a right sash hinged on the right,
/// divided by a full-height mullion.
DesignDocument twoBayWindow() {
  final outline = Polygon.rectangle(width: 1200, height: 900);
  return DesignDocument.blank(
    id: 'p1',
    category: ProductCategory.window,
    material: FrameMaterial.pvc,
    now: DateTime.utc(2026, 1, 2, 3, 4, 5),
  ).copyWith(
    name: 'Kitchen window',
    outline: outline,
    overallWidth: const Measurement.confirmed(1200),
    overallHeight: const Measurement.confirmed(900),
    dividers: [
      const PanelDivider(
        id: 'd1',
        start: Point2(600, 0),
        end: Point2(600, 900),
        spansFullFrame: true,
      ),
    ],
    panels: [
      Panel.fixed(
        id: 's1',
        boundary: Polygon.rectangle(width: 600, height: 900),
        label: 'left',
      ),
      Panel.opening(
        id: 's2',
        boundary: Polygon.rectangle(
          width: 600,
          height: 900,
          topLeft: const Point2(600, 0),
        ),
        opening: const OpeningSpec(
          hingeSide: HingeSide.right,
          direction: OpeningDirection.outward,
          isConfirmed: true,
        ),
        label: 'right',
      ),
    ],
    sketch: Sketch(strokes: [
      const Stroke(
        id: 'k1',
        points: [Point2(0, 0), Point2(1200, 4), Point2(1200, 900)],
        timestampMs: 120,
      ),
    ]),
  );
}

void main() {
  group('a new design starts from the factory defaults', () {
    test('the profile follows the material without being asked for', () {
      final pvc = DesignDocument.blank(
        id: 'a',
        category: ProductCategory.window,
        material: FrameMaterial.pvc,
      );
      final aluminium = DesignDocument.blank(
        id: 'b',
        category: ProductCategory.door,
        material: FrameMaterial.aluminium,
      );

      expect(pvc.profile.id, 'generic.pvc.casement');
      expect(aluminium.profile.id, 'generic.aluminium.casement');
    });

    test('a blank design states everything it is still missing', () {
      final blank = DesignDocument.blank(
        id: 'a',
        category: ProductCategory.window,
        material: FrameMaterial.pvc,
      );

      expect(blank.hasLayout, isFalse);
      expect(blank.hasConfirmedSize, isFalse);
      expect(blank.isFullyConfirmed, isFalse);
      expect(blank.outstandingQuestions, isNotEmpty);
      expect(
        blank.outstandingQuestions.first.kind,
        DesignQuestionKind.notInterpreted,
      );
    });

    test('the default viewing side and dimension reference are explicit', () {
      final blank = DesignDocument.blank(
        id: 'a',
        category: ProductCategory.window,
        material: FrameMaterial.pvc,
      );

      // Neither is ever inferred, so both have a stated starting value
      // (spec sections 3C and 3D).
      expect(blank.viewedFrom, ViewingSide.outside);
      expect(blank.dimensionReference, DimensionReference.outerFrame);
    });
  });

  group('CH and Z cannot contradict each other', () {
    test('a Z panel without opening settings is refused', () {
      expect(
        () => Panel(
          id: 's',
          boundary: Polygon.rectangle(width: 100, height: 100),
          behaviour: PanelBehaviour.opening,
          infill: Glazing.doubleGlazed,
        ),
        throwsArgumentError,
      );
    });

    test('a CH panel carrying opening settings is refused', () {
      expect(
        () => Panel(
          id: 's',
          boundary: Polygon.rectangle(width: 100, height: 100),
          behaviour: PanelBehaviour.fixed,
          infill: Glazing.doubleGlazed,
          opening: const OpeningSpec(
            hingeSide: HingeSide.left,
            direction: OpeningDirection.inward,
          ),
        ),
        throwsArgumentError,
      );
    });

    test('turning a sash into a fixed pane drops its hinge settings', () {
      final design = twoBayWindow();
      final sash = design.panelById('s2')!;

      final fixed = sash.asFixed();

      expect(fixed.behaviour, PanelBehaviour.fixed);
      expect(fixed.opening, isNull);
      // The id survives, so the user's other choices about this panel are
      // not orphaned (spec section 10).
      expect(fixed.id, 's2');
    });

    test('an unconfirmed hinge side is surfaced as a question', () {
      final design = twoBayWindow();
      final unconfirmed = design.panelById('s2')!.asOpening(
            const OpeningSpec(
              hingeSide: HingeSide.left,
              direction: OpeningDirection.inward,
            ),
          );
      final updated = design.withPanel(unconfirmed);

      expect(updated.panelsNeedingOpeningConfirmation, hasLength(1));
      expect(
        updated.outstandingQuestions.any(
          (q) => q.kind == DesignQuestionKind.hingeSideUnconfirmed,
        ),
        isTrue,
      );
      expect(updated.isFullyConfirmed, isFalse);
    });

    test('a fully answered design has nothing outstanding', () {
      final design = twoBayWindow();

      expect(design.hasLayout, isTrue);
      expect(design.hasConfirmedSize, isTrue);
      expect(design.outstandingQuestions, isEmpty);
      expect(design.isFullyConfirmed, isTrue);
      expect(design.fixedPanelCount, 1);
      expect(design.openingPanelCount, 1);
    });
  });

  group('wall opening is not frame size', () {
    test('an outer-frame dimension is used as given', () {
      final design = twoBayWindow();

      expect(design.dimensionReference, DimensionReference.outerFrame);
      expect(design.frameWidthMm, 1200);
      expect(design.frameHeightMm, 900);
    });

    test('a wall opening has the gap the user set taken off, and only that', () {
      final design = twoBayWindow().copyWith(
        dimensionReference: DimensionReference.wallOpening,
        fittingGapMm: 10,
      );

      // 1200 wall opening, 10 mm each side, so a 1180 frame.
      expect(design.frameWidthMm, 1180);
      expect(design.frameHeightMm, 880);
      // The entered dimension is untouched: the allowance is applied where it
      // can be seen, not folded into the stored number (spec section 3D).
      expect(design.overallWidth!.millimetres, 1200);
    });

    test('no allowance is applied unless the user set one', () {
      final design = twoBayWindow()
          .copyWith(dimensionReference: DimensionReference.wallOpening);

      expect(design.fittingGapMm, 0);
      expect(design.frameWidthMm, 1200);
    });
  });

  group('saving and reopening', () {
    test('a design round-trips through JSON unchanged', () {
      final original = twoBayWindow();
      final restored =
          DesignDocument.fromJson(jsonDecode(jsonEncode(original.toJson())));

      expect(restored.id, original.id);
      expect(restored.name, 'Kitchen window');
      expect(restored.category, ProductCategory.window);
      expect(restored.material, FrameMaterial.pvc);
      expect(restored.outline, original.outline);
      expect(restored.dividers, original.dividers);
      expect(restored.panels, original.panels);
      expect(restored.overallWidth, original.overallWidth);
      expect(restored.overallHeight, original.overallHeight);
      expect(restored.viewedFrom, original.viewedFrom);
      expect(restored.dimensionReference, original.dimensionReference);
      expect(restored.finish, original.finish);
      expect(restored.profile, original.profile);
    });

    test('the original ink is still there after reopening', () {
      final restored = DesignDocument.fromJson(
        jsonDecode(jsonEncode(twoBayWindow().toJson())),
      );

      expect(restored.sketch.strokes, hasLength(1));
      expect(restored.sketch.strokes.single.points, hasLength(3));
      expect(restored.sketch.strokes.single.timestampMs, 120);
    });

    test('CH and Z assignments survive the round trip', () {
      final restored = DesignDocument.fromJson(
        jsonDecode(jsonEncode(twoBayWindow().toJson())),
      );

      expect(restored.panelById('s1')!.behaviour, PanelBehaviour.fixed);
      final sash = restored.panelById('s2')!;
      expect(sash.behaviour, PanelBehaviour.opening);
      expect(sash.opening!.hingeSide, HingeSide.right);
      expect(sash.opening!.direction, OpeningDirection.outward);
      expect(sash.opening!.isConfirmed, isTrue);
    });

    test('a display unit is a preference and changes no dimension', () {
      final metric = twoBayWindow();
      final imperial = metric.copyWith(displayUnit: LengthUnit.inch);
      final restored =
          DesignDocument.fromJson(jsonDecode(jsonEncode(imperial.toJson())));

      expect(restored.displayUnit, LengthUnit.inch);
      // Storage is millimetres regardless (spec section 3D).
      expect(restored.overallWidth!.millimetres, 1200);
      expect(restored.outline, metric.outline);
    });
  });

  group('a file that cannot be trusted is refused', () {
    test('a project from a newer version is refused, not guessed at', () {
      final json = twoBayWindow().toJson()
        ..['schema'] = DesignDocument.currentSchemaVersion + 1;

      expect(
        () => DesignDocument.fromJson(json),
        throwsA(
          isA<DesignDataException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('a file with no version number is refused', () {
      final json = twoBayWindow().toJson()..remove('schema');

      expect(() => DesignDocument.fromJson(json), throwsA(isA<DesignDataException>()));
    });

    test('a Z panel whose opening settings were lost is refused', () {
      // Loading this as a fixed pane would silently discard the user's
      // decision, which is worse than refusing (spec section 10).
      final json = twoBayWindow().toJson();
      (json['panels'] as List)[1] = {
        ...((json['panels'] as List)[1] as Map<String, dynamic>),
      }..remove('opening');

      expect(() => DesignDocument.fromJson(json), throwsA(isA<DesignDataException>()));
    });

    test('an opening mechanism this build cannot render is refused', () {
      // A future build that adds sliding must not have its projects silently
      // reinterpreted as hinged here (spec section 3C).
      final json = twoBayWindow().toJson();
      final panels = json['panels'] as List;
      ((panels[1] as Map<String, dynamic>)['opening']
          as Map<String, dynamic>)['mechanism'] = 'sliding';

      expect(() => DesignDocument.fromJson(json), throwsA(isA<DesignDataException>()));
    });

    test('nonsense is refused with a sentence a user can read', () {
      expect(
        () => DesignDocument.fromJson('hello'),
        throwsA(
          isA<DesignDataException>().having(
            (e) => e.message,
            'message',
            contains('not a ProFrame project'),
          ),
        ),
      );
    });
  });

  test('editing one panel leaves every other panel alone', () {
    final design = twoBayWindow();
    final edited = design.withPanel(
      design.panelById('s1')!.copyWith(infill: const SolidPanel()),
    );

    expect(edited.panelById('s1')!.infill, isA<SolidPanel>());
    expect(edited.panelById('s2'), design.panelById('s2'));
    expect(edited.panels, hasLength(2));
  });

  test('the finish is a product colour, never the brand colour', () {
    final design = twoBayWindow().copyWith(finish: StockFinishes.anthracite);

    expect(design.finish.name, 'Anthracite');
    // Brand cream and deep green are not offered as product finishes.
    expect(
      StockFinishes.all.map((f) => f.argb),
      isNot(contains(0xFF013E37)),
    );
  });
}
