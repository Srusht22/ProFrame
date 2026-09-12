import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/domain/design_document.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/layout/design_builder.dart';
import 'package:proframe/domain/layout/design_validator.dart';
import 'package:proframe/domain/layout/note_resolver.dart';
import 'package:proframe/domain/measurement.dart';
import 'package:proframe/domain/panel.dart';
import 'package:proframe/domain/panel_note.dart';
import 'package:proframe/domain/product/opening.dart';
import 'package:proframe/domain/product/product_basics.dart';
import 'package:proframe/domain/recognition/stroke_intent.dart';

Panel wholePanel({List<PanelNote> notes = const []}) => Panel.fixed(
      id: 'whole',
      boundary: Polygon.rectangle(width: 1200, height: 900),
      notes: notes,
    );

DesignDocument design({
  List<Panel>? panels,
  double width = 1200,
  double height = 900,
  ProductCategory category = ProductCategory.window,
  FrameMaterial material = FrameMaterial.pvc,
}) {
  final outline = Polygon.rectangle(width: width, height: height);
  return DesignDocument.blank(
    id: 'd1',
    category: category,
    material: material,
    now: DateTime.utc(2026, 9, 12),
  ).copyWith(
    outline: outline,
    overallWidth: Measurement.confirmed(width),
    overallHeight: Measurement.confirmed(height),
    panels: panels ?? [Panel.fixed(id: 'p1', boundary: outline)],
  );
}

void main() {
  group('notes follow their panel when it is split', () {
    test('a note on the left stays on the left half', () {
      // Spec section 8B: never silently discard or misassign a note.
      final source = wholePanel(
        notes: const [
          PanelNote(id: 'n1', text: 'left remark', position: Point2(0.2, 0.5)),
          PanelNote(id: 'n2', text: 'right remark', position: Point2(0.8, 0.5)),
        ],
      );
      final halves = [
        Panel.fixed(
          id: 'a',
          boundary: Polygon.rectangle(width: 600, height: 900),
        ),
        Panel.fixed(
          id: 'b',
          boundary: Polygon.rectangle(
            width: 600,
            height: 900,
            topLeft: const Point2(600, 0),
          ),
        ),
      ];

      final resolved = NoteResolver.afterSplit(source, halves);

      expect(resolved.panels[0].notes.single.text, 'left remark');
      expect(resolved.panels[1].notes.single.text, 'right remark');
      expect(resolved.lost, isEmpty);
    });

    test('a note keeps its place under the finger after the split', () {
      // 0.2 across a 1200 panel is 240 mm, which is 0.4 across a 600 half.
      final source = wholePanel(
        notes: const [
          PanelNote(id: 'n1', text: 'x', position: Point2(0.2, 0.5)),
        ],
      );
      final halves = [
        Panel.fixed(
          id: 'a',
          boundary: Polygon.rectangle(width: 600, height: 900),
        ),
        Panel.fixed(
          id: 'b',
          boundary: Polygon.rectangle(
            width: 600,
            height: 900,
            topLeft: const Point2(600, 0),
          ),
        ),
      ];

      final moved = NoteResolver.afterSplit(source, halves).panels[0];

      expect(moved.notes.single.position.x, closeTo(0.4, 0.001));
      expect(moved.notes.single.position.y, closeTo(0.5, 0.001));
    });

    test('every move is recorded so the user can be told', () {
      final source = wholePanel(
        notes: const [PanelNote(id: 'n1', text: 'x')],
      );
      final halves = [
        Panel.fixed(
          id: 'a',
          boundary: Polygon.rectangle(width: 600, height: 900),
        ),
        Panel.fixed(
          id: 'b',
          boundary: Polygon.rectangle(
            width: 600,
            height: 900,
            topLeft: const Point2(600, 0),
          ),
        ),
      ];

      final resolved = NoteResolver.afterSplit(source, halves);

      expect(resolved.transfers, hasLength(1));
      expect(resolved.transfers.single.wasKept, isTrue);
      expect(NoteResolver.describe(resolved.transfers), contains('1 note'));
    });

    test('merging keeps both panels\' notes', () {
      final left = Panel.fixed(
        id: 'a',
        boundary: Polygon.rectangle(width: 600, height: 900),
        notes: const [PanelNote(id: 'n1', text: 'from the left')],
      );
      final right = Panel.fixed(
        id: 'b',
        boundary: Polygon.rectangle(
          width: 600,
          height: 900,
          topLeft: const Point2(600, 0),
        ),
        notes: const [PanelNote(id: 'n2', text: 'from the right')],
      );

      final merged = NoteResolver.afterMerge([left, right], wholePanel());

      expect(merged.panels.single.notes, hasLength(2));
      expect(
        merged.panels.single.notes.map((n) => n.text),
        containsAll(<String>['from the left', 'from the right']),
      );
    });

    test('drawing a divider moves the notes with the geometry', () {
      var document = design(
        panels: [
          Panel.fixed(
            id: 'p1',
            boundary: Polygon.rectangle(width: 1200, height: 900),
            notes: const [
              PanelNote(id: 'n1', text: 'over here', position: Point2(0.1, 0.5)),
            ],
          ),
        ],
      );

      var counter = 0;
      document = DesignBuilder.apply(
        document,
        const VerticalDividerIntent('k', 600, 'p1'),
        (prefix) => '$prefix${++counter}',
      );

      expect(document.panels, hasLength(2));
      expect(document.panels.first.notes.single.text, 'over here');
      expect(document.panels.last.notes, isEmpty);
    });
  });

  group('a note is an annotation, never a command', () {
    test('adding one changes nothing else about the panel', () {
      // Spec section 8B: a note must not change dimensions, infill or
      // hardware, however it is worded.
      final before = wholePanel();
      final after = before.withNote(
        const PanelNote(id: 'n1', text: 'make this 2000 wide and sliding'),
      );

      expect(after.widthMm, before.widthMm);
      expect(after.infill, before.infill);
      expect(after.behaviour, before.behaviour);
      expect(after.opening, before.opening);
    });

    test('hiding one keeps it', () {
      final panel = wholePanel(
        notes: const [PanelNote(id: 'n1', text: 'keep me')],
      );

      final hidden = panel.withUpdatedNote(
        panel.notes.single.copyWith(isVisible: false),
      );

      expect(hidden.notes, hasLength(1));
      expect(hidden.visibleNotes, isEmpty);
      expect(hidden.hasNote, isTrue);
    });
  });

  group('dimensions are checked, never corrected', () {
    test('a complete design has nothing to report', () {
      expect(DesignValidator.check(design()), isEmpty);
      expect(DesignValidator.isBuildable(design()), isTrue);
    });

    test('missing sizes are incomplete, not wrong', () {
      final blank = DesignDocument.blank(
        id: 'd',
        category: ProductCategory.window,
        material: FrameMaterial.pvc,
      );

      final findings = DesignValidator.check(blank);

      expect(findings, isNotEmpty);
      expect(findings.every((f) => !f.isConflict), isTrue);
      expect(DesignValidator.isBuildable(blank), isTrue);
    });

    test('a gap between two panels is a conflict', () {
      final withGap = design(
        panels: [
          Panel.fixed(
            id: 'a',
            boundary: Polygon.rectangle(width: 500, height: 900),
          ),
          Panel.fixed(
            id: 'b',
            boundary: Polygon.rectangle(
              width: 600,
              height: 900,
              topLeft: const Point2(600, 0),
            ),
          ),
        ],
      );

      final conflicts =
          DesignValidator.check(withGap).where((f) => f.isConflict).toList();

      expect(conflicts, isNotEmpty);
      expect(conflicts.first.message, contains('gap'));
      expect(conflicts.first.remedy, isNotEmpty);
    });

    test('an overlap is a conflict', () {
      final overlapping = design(
        panels: [
          Panel.fixed(
            id: 'a',
            boundary: Polygon.rectangle(width: 700, height: 900),
          ),
          Panel.fixed(
            id: 'b',
            boundary: Polygon.rectangle(
              width: 600,
              height: 900,
              topLeft: const Point2(600, 0),
            ),
          ),
        ],
      );

      expect(
        DesignValidator.check(overlapping)
            .any((f) => f.isConflict && f.message.contains('overlap')),
        isTrue,
      );
    });

    test('a panel outside the frame is a conflict', () {
      final outside = design(
        panels: [
          Panel.fixed(
            id: 'a',
            boundary: Polygon.rectangle(
              width: 400,
              height: 400,
              topLeft: const Point2(2000, 0),
            ),
          ),
        ],
      );

      expect(
        DesignValidator.check(outside)
            .any((f) => f.isConflict && f.message.contains('outside')),
        isTrue,
      );
    });

    test('a fitting gap that eats the whole frame is a conflict', () {
      final impossible = design().copyWith(
        dimensionReference: DimensionReference.wallOpening,
        fittingGapMm: 900,
      );

      expect(
        DesignValidator.check(impossible).any((f) => f.isConflict),
        isTrue,
      );
    });

    test('a sash wider than its system allows is reported with the limit', () {
      // Spec section 9: PVC and aluminium are not the same specification.
      final tooWide = design(width: 1200).copyWith(
        panels: [
          Panel.opening(
            id: 'big',
            boundary: Polygon.rectangle(width: 1200, height: 900),
            opening: const OpeningSpec(
              hingeSide: HingeSide.left,
              direction: OpeningDirection.inward,
              isConfirmed: true,
            ),
          ),
        ],
      );

      final conflict = DesignValidator.check(tooWide)
          .firstWhere((f) => f.isConflict && f.message.contains('wide'));

      // The PVC limit is 900; aluminium's is 1000, so the message must name
      // the system rather than a universal number.
      expect(conflict.message, contains('900 mm limit'));
      expect(conflict.message, contains('Generic PVC casement'));
    });

    test('the same sash is allowed in a system rated for it', () {
      final aluminium = design(width: 950, material: FrameMaterial.aluminium)
          .copyWith(
        panels: [
          Panel.opening(
            id: 'ok',
            boundary: Polygon.rectangle(width: 950, height: 900),
            opening: const OpeningSpec(
              hingeSide: HingeSide.left,
              direction: OpeningDirection.inward,
              isConfirmed: true,
            ),
          ),
        ],
      );

      expect(
        DesignValidator.check(aluminium)
            .any((f) => f.isConflict && f.message.contains('wide')),
        isFalse,
      );
    });

    test('nothing the validator does changes the design', () {
      // Spec section 6: confirmed dimensions are never silently overridden.
      final original = design(
        panels: [
          Panel.fixed(
            id: 'a',
            boundary: Polygon.rectangle(width: 500, height: 900),
          ),
          Panel.fixed(
            id: 'b',
            boundary: Polygon.rectangle(
              width: 600,
              height: 900,
              topLeft: const Point2(600, 0),
            ),
          ),
        ],
      );
      final before = original.panels.map((p) => p.boundary).toList();

      DesignValidator.check(original);

      expect(original.panels.map((p) => p.boundary).toList(), before);
    });

    test('every finding says what to do about it', () {
      final broken = design(
        panels: [
          Panel.fixed(
            id: 'tiny',
            boundary: Polygon.rectangle(width: 20, height: 900),
          ),
        ],
      );

      for (final finding in DesignValidator.check(broken)) {
        expect(finding.remedy, isNotEmpty, reason: finding.message);
        expect(finding.message, isNot(contains('Exception')));
      }
    });
  });
}
