import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/design_document.dart';
import 'package:proframe/domain/design_question.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/layout/design_builder.dart';
import 'package:proframe/domain/measurement.dart';
import 'package:proframe/domain/product/opening.dart';
import 'package:proframe/domain/product/product_basics.dart';
import 'package:proframe/domain/recognition/stroke_intent.dart';

/// Deterministic ids, so a test can name the panel it expects.
IdFactory countingIds() {
  var n = 0;
  return (prefix) => '$prefix${++n}';
}

DesignDocument blank() => DesignDocument.blank(
      id: 'd1',
      category: ProductCategory.window,
      material: FrameMaterial.pvc,
      now: DateTime.utc(2026, 9, 12),
    );

DesignDocument withFrame({double width = 1200, double height = 900}) =>
    DesignBuilder.apply(
      blank(),
      FrameIntent('k1', Polygon.rectangle(width: width, height: height)),
      countingIds(),
    );

void main() {
  group('drawing a frame', () {
    test('the frame becomes the outline and one whole panel', () {
      final design = withFrame();

      expect(design.outline, isNotNull);
      expect(design.outline!.width, 1200);
      expect(design.panels, hasLength(1));
      expect(design.panels.single.widthMm, 1200);
      // Unmarked, so fixed (spec Phase 2, item 2).
      expect(design.panels.single.behaviour, PanelBehaviour.fixed);
    });

    test('the size taken from the drawing is an estimate, not a dimension', () {
      final design = withFrame();

      // Spec section 2: proportions from a sketch are never dimensions.
      expect(design.overallWidth!.isEstimated, isTrue);
      expect(design.overallWidth!.isConfirmed, isFalse);
      expect(design.hasConfirmedSize, isFalse);
      expect(
        design.outstandingQuestions.any(
          (q) => q.kind == DesignQuestionKind.overallWidthMissing ||
              q.kind == DesignQuestionKind.overallWidthUnconfirmed,
        ),
        isTrue,
      );
    });
  });

  group('drawing a divider', () {
    test('it splits the panel where it was drawn', () {
      final ids = countingIds();
      var design = DesignBuilder.apply(
        blank(),
        FrameIntent('k1', Polygon.rectangle(width: 1200, height: 900)),
        ids,
      );
      final wholeId = design.panels.single.id;

      design = DesignBuilder.apply(
        design,
        VerticalDividerIntent('k2', 400, wholeId),
        ids,
      );

      expect(design.panels, hasLength(2));
      expect(design.panels[0].widthMm, 400);
      expect(design.panels[1].widthMm, 800);
      expect(design.dividers, hasLength(1));
      expect(design.dividers.single.isVertical, isTrue);
    });

    test('a divider across the whole frame is recorded as full', () {
      final ids = countingIds();
      var design = DesignBuilder.apply(
        blank(),
        FrameIntent('k1', Polygon.rectangle(width: 1200, height: 900)),
        ids,
      );
      design = DesignBuilder.apply(
        design,
        VerticalDividerIntent('k2', 600, design.panels.single.id),
        ids,
      );

      expect(design.dividers.single.spansFullFrame, isTrue);
    });

    test('a divider inside one panel of several is partial, and stays partial',
        () {
      // Spec section 4: partial dividers and T-junctions are supported, not
      // completed into a full cross.
      final ids = countingIds();
      var design = DesignBuilder.apply(
        blank(),
        FrameIntent('k1', Polygon.rectangle(width: 1200, height: 900)),
        ids,
      );
      design = DesignBuilder.apply(
        design,
        VerticalDividerIntent('k2', 600, design.panels.single.id),
        ids,
      );
      // Now a transom inside the right-hand panel only.
      design = DesignBuilder.apply(
        design,
        HorizontalDividerIntent('k3', 400, design.panels[1].id),
        ids,
      );

      expect(design.panels, hasLength(3));
      expect(design.dividers, hasLength(2));
      expect(design.dividers.last.spansFullFrame, isFalse);
      expect(design.dividers.last.lengthMm, 600);
    });

    test('a divider naming a panel that is gone changes nothing', () {
      final design = withFrame();

      final after = DesignBuilder.apply(
        design,
        const VerticalDividerIntent('k2', 600, 'no-such-panel'),
        countingIds(),
      );

      expect(after.panels, design.panels);
      expect(after.dividers, isEmpty);
    });
  });

  group('a chevron marks a panel as opening', () {
    test('it becomes Z, hinged where the chevron pointed', () {
      final design = withFrame();
      final panelId = design.panels.single.id;

      final after = DesignBuilder.apply(
        design,
        ChevronIntent(
          'k2',
          panelId: panelId,
          hingeSide: HingeSide.right,
          apex: const Point2(900, 450),
        ),
        countingIds(),
      );

      final panel = after.panelById(panelId)!;
      expect(panel.behaviour, PanelBehaviour.opening);
      expect(panel.opening!.hingeSide, HingeSide.right);
    });

    test('the swing direction is left as a question, not answered', () {
      // The mark says which edge the hinges are on. It does not say whether
      // the leaf swings in or out (spec section 3C).
      final design = withFrame();
      final panelId = design.panels.single.id;

      final after = DesignBuilder.apply(
        design,
        ChevronIntent(
          'k2',
          panelId: panelId,
          hingeSide: HingeSide.left,
          apex: const Point2(300, 450),
        ),
        countingIds(),
      );

      expect(after.panelById(panelId)!.opening!.isConfirmed, isFalse);
      expect(after.panelsNeedingOpeningConfirmation, hasLength(1));
      expect(
        after.outstandingQuestions.any(
          (q) => q.kind == DesignQuestionKind.hingeSideUnconfirmed,
        ),
        isTrue,
      );
    });
  });

  group('confirming a dimension rescales the drawing', () {
    test('the frame becomes the entered width', () {
      final design = DesignBuilder.setOverallWidth(withFrame(), 2000);

      expect(design.outline!.width, closeTo(2000, 0.001));
      expect(design.overallWidth!.isConfirmed, isTrue);
      expect(design.overallWidth!.millimetres, 2000);
    });

    test('the proportions the user drew are kept exactly', () {
      // A divider drawn a third of the way across stays a third of the way
      // across when the real width arrives (spec Phase 2, item 3).
      final ids = countingIds();
      var design = DesignBuilder.apply(
        blank(),
        FrameIntent('k1', Polygon.rectangle(width: 1200, height: 900)),
        ids,
      );
      design = DesignBuilder.apply(
        design,
        VerticalDividerIntent('k2', 400, design.panels.single.id),
        ids,
      );

      design = DesignBuilder.setOverallWidth(design, 2400);

      // 400:800 was one third; 800:1600 still is.
      expect(design.panels[0].widthMm, closeTo(800, 0.001));
      expect(design.panels[1].widthMm, closeTo(1600, 0.001));
      expect(design.dividers.single.start.x, closeTo(800, 0.001));
    });

    test('panel widths still sum to the frame width after rescaling', () {
      final ids = countingIds();
      var design = DesignBuilder.apply(
        blank(),
        FrameIntent('k1', Polygon.rectangle(width: 1187, height: 903)),
        ids,
      );
      design = DesignBuilder.apply(
        design,
        VerticalDividerIntent('k2', 431, design.panels.single.id),
        ids,
      );

      design = DesignBuilder.setOverallWidth(design, 1500);

      final total = design.panels.fold<double>(0, (sum, p) => sum + p.widthMm);
      expect(total, closeTo(1500, 0.01));
    });

    test('width and height scale independently', () {
      var design = withFrame(width: 1200, height: 900);

      design = DesignBuilder.setOverallWidth(design, 2400);
      design = DesignBuilder.setOverallHeight(design, 1800);

      expect(design.outline!.width, closeTo(2400, 0.001));
      expect(design.outline!.height, closeTo(1800, 0.001));
      expect(design.hasConfirmedSize, isTrue);
    });

    test('setting a width before any frame is drawn just records it', () {
      final design = DesignBuilder.setOverallWidth(blank(), 1500);

      expect(design.outline, isNull);
      expect(design.overallWidth, const Measurement.confirmed(1500));
    });
  });

  test('a discarded stroke leaves the design untouched', () {
    final design = withFrame();

    final after = DesignBuilder.apply(
      design,
      const DiscardedIntent('k9', 'scribble'),
      countingIds(),
    );

    expect(after, same(design));
  });

  test('the summary shrinks as the user answers questions', () {
    // Spec Phase 2, item 9: the summary tracks the drawing live.
    final ids = countingIds();
    var design = blank();
    expect(design.outstandingQuestions.length, 3);

    design = DesignBuilder.apply(
      design,
      FrameIntent('k1', Polygon.rectangle(width: 1200, height: 900)),
      ids,
    );
    // Frame drawn: no longer "not interpreted", but both sizes are estimates.
    expect(
      design.outstandingQuestions.any(
        (q) => q.kind == DesignQuestionKind.notInterpreted,
      ),
      isFalse,
    );
    expect(design.outstandingQuestions, hasLength(2));

    design = DesignBuilder.setOverallWidth(design, 1200);
    expect(design.outstandingQuestions, hasLength(1));

    design = DesignBuilder.setOverallHeight(design, 900);
    expect(design.outstandingQuestions, isEmpty);
    expect(design.isFullyConfirmed, isTrue);
  });
}
