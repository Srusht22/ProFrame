import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/errors/app_exception.dart';
import 'package:proframe/domain/design_document.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/measurement.dart';
import 'package:proframe/domain/panel.dart';
import 'package:proframe/domain/panel_divider.dart';
import 'package:proframe/domain/panel_note.dart';
import 'package:proframe/domain/product/opening.dart';
import 'package:proframe/domain/product/product_basics.dart';
import 'package:proframe/infrastructure/export/project_file.dart';
import 'package:proframe/infrastructure/key_value_store.dart';
import 'package:proframe/infrastructure/project_repository.dart';

/// A fully specified window, so a round trip has something to lose.
DesignDocument fullDesign({String id = 'p1', String name = 'Kitchen window'}) {
  final outline = Polygon.rectangle(width: 1200, height: 1500);
  return DesignDocument.blank(
    id: id,
    category: ProductCategory.window,
    material: FrameMaterial.pvc,
    name: name,
    now: DateTime.utc(2026, 9, 12, 10),
  ).copyWith(
    outline: outline,
    overallWidth: const Measurement.confirmed(1200),
    overallHeight: const Measurement.confirmed(1500),
    designNote: 'Customer wants obscure glass',
    dimensionReference: DimensionReference.wallOpening,
    fittingGapMm: 10,
    dividers: const [
      PanelDivider(
        id: 'v1',
        start: Point2(500, 0),
        end: Point2(500, 1500),
        spansFullFrame: true,
      ),
    ],
    panels: [
      Panel.fixed(
        id: 'left',
        boundary: Polygon.rectangle(width: 500, height: 1500),
        notes: const [
          PanelNote(id: 'n1', text: 'توري', position: Point2(0.3, 0.2)),
          PanelNote(id: 'n2', text: 'Hidden remark', isVisible: false),
        ],
      ).copyWith(hasMesh: true),
      Panel.opening(
        id: 'right',
        boundary: Polygon.rectangle(
          width: 700,
          height: 1500,
          topLeft: const Point2(500, 0),
        ),
        opening: const OpeningSpec(
          mechanism: OpeningMechanism.tilt,
          hingeSide: HingeSide.bottom,
          direction: OpeningDirection.inward,
          isConfirmed: true,
        ),
        notes: const [PanelNote(id: 'n3', text: 'Frosted')],
      ),
    ],
  );
}

void main() {
  group('saving and reopening', () {
    test('a project comes back exactly as it went in', () async {
      final store = InMemoryStore();
      final repository = ProjectRepository(store);
      final original = fullDesign();

      await repository.save(original);
      final restored = await repository.load('p1');

      expect(restored, isNotNull);
      expect(restored!.name, original.name);
      expect(restored.outline, original.outline);
      expect(restored.panels, original.panels);
      expect(restored.dividers, original.dividers);
      expect(restored.overallWidth, original.overallWidth);
      expect(restored.designNote, original.designNote);
      expect(restored.dimensionReference, DimensionReference.wallOpening);
      expect(restored.fittingGapMm, 10);
    });

    test('the reopened design is editable, not a picture', () async {
      // Spec section 10: reopening restores an editable design.
      final repository = ProjectRepository(InMemoryStore());
      await repository.save(fullDesign());

      final restored = (await repository.load('p1'))!;
      final edited = restored.withPanel(
        restored.panelById('left')!.copyWith(hasMesh: false),
      );

      expect(edited.panelById('left')!.hasMesh, isFalse);
      expect(edited.panels, hasLength(2));
    });

    test('notes survive with their positions and visibility', () async {
      final repository = ProjectRepository(InMemoryStore());
      await repository.save(fullDesign());

      final left = (await repository.load('p1'))!.panelById('left')!;

      expect(left.notes, hasLength(2));
      expect(left.notes.first.text, 'توري');
      expect(left.notes.first.position, const Point2(0.3, 0.2));
      expect(left.notes.last.isVisible, isFalse);
      // A hidden note is still there, which is the whole point of hiding.
      expect(left.hasNote, isTrue);
      expect(left.visibleNotes, hasLength(1));
    });

    test('a tilt sash keeps its mechanism', () async {
      final repository = ProjectRepository(InMemoryStore());
      await repository.save(fullDesign());

      final right = (await repository.load('p1'))!.panelById('right')!;

      expect(right.opening!.mechanism, OpeningMechanism.tilt);
      expect(right.opening!.isConfirmed, isTrue);
    });

    test('loading something that was never saved gives null', () async {
      final repository = ProjectRepository(InMemoryStore());

      expect(await repository.load('nothing'), isNull);
    });
  });

  group('the project list', () {
    test('it shows every saved project, newest first', () async {
      final repository = ProjectRepository(InMemoryStore());
      await repository.save(fullDesign(id: 'a', name: 'Older'));
      await repository.save(
        fullDesign(id: 'b', name: 'Newer')
            .copyWith(updatedAt: DateTime.utc(2026, 10)),
      );

      final list = await repository.list();

      expect(list.map((p) => p.name), ['Newer', 'Older']);
      expect(list.first.description, contains('Window'));
      expect(list.first.description, contains('1200 × 1500 mm'));
    });

    test('a damaged project is listed as damaged, not hidden', () async {
      // Spec section 10: the user needs to know it is there and broken.
      final store = InMemoryStore({'proframe.project.bad': 'not json at all'});
      final repository = ProjectRepository(store);

      final list = await repository.list();

      expect(list, hasLength(1));
      expect(list.single.isDamaged, isTrue);
      expect(list.single.name, 'Damaged project');
    });

    test('a damaged project reports rather than returning a blank design',
        () async {
      final store = InMemoryStore({'proframe.project.bad': '{"schema": 1}'});

      expect(
        () => ProjectRepository(store).load('bad'),
        throwsA(isA<DesignDataException>()),
      );
    });
  });

  group('duplicating', () {
    test('a copy is a separate project', () async {
      final repository = ProjectRepository(InMemoryStore());
      final original = fullDesign();
      await repository.save(original);

      final copy = await repository.duplicate(original, newId: 'p2');

      expect(copy.id, 'p2');
      expect(copy.name, 'Kitchen window (copy)');
      expect(copy.panels, original.panels);
      // Editing the copy cannot touch the original.
      await repository.save(copy.copyWith(name: 'Renamed'));
      expect((await repository.load('p1'))!.name, 'Kitchen window');
    });
  });

  group('drafts and recovery', () {
    test('a draft is written and can be recovered', () async {
      final repository = ProjectRepository(InMemoryStore());

      await repository.saveDraft(fullDesign());
      final draft = await repository.loadDraft();

      expect(draft, isNotNull);
      expect(draft!.panels, hasLength(2));
    });

    test('a damaged draft never blocks start-up', () async {
      // A broken recovery is offered to nobody; it must not throw on launch.
      final store = InMemoryStore({'proframe.draft': 'rubbish'});

      expect(await ProjectRepository(store).loadDraft(), isNull);
    });

    test('a draft failing to write does not throw into the drawing', () async {
      final store = InMemoryStore()..failNextWrite = true;

      // No exception: a draft is a safety net, not the save.
      await ProjectRepository(store).saveDraft(fullDesign());
    });

    test('saving clears the draft', () async {
      final store = InMemoryStore();
      final repository = ProjectRepository(store);
      await repository.saveDraft(fullDesign());

      await repository.clearDraft();

      expect(await repository.loadDraft(), isNull);
    });
  });

  group('an interrupted save', () {
    test('is reported rather than swallowed', () async {
      // Spec section 10: a user who thinks their work is saved when it is not
      // will lose it.
      final store = InMemoryStore()..failNextWrite = true;

      expect(
        () => ProjectRepository(store).save(fullDesign()),
        throwsA(isA<DesignDataException>()),
      );
    });

    test('leaves the previous version intact', () async {
      final store = InMemoryStore();
      final repository = ProjectRepository(store);
      await repository.save(fullDesign(name: 'Good version'));

      store.failNextWrite = true;
      try {
        await repository.save(fullDesign(name: 'Interrupted'));
      } on DesignDataException {
        // Expected.
      }

      // The scratch key took the failed write; the real one still holds the
      // last good save.
      expect((await repository.load('p1'))!.name, 'Good version');
    });
  });

  group('the native project file', () {
    test('it round-trips through export and import', () {
      final original = fullDesign();

      final restored = ProjectFile.decode(ProjectFile.encode(original));

      expect(restored.panels, original.panels);
      expect(restored.designNote, original.designNote);
      expect(restored.dividers, original.dividers);
    });

    test('a file that is not ours is refused in plain language', () {
      expect(
        () => ProjectFile.decode('{"hello": "world"}'),
        throwsA(
          isA<DesignDataException>().having(
            (e) => e.message,
            'message',
            contains('not a ProFrame project'),
          ),
        ),
      );
    });

    test('nonsense is refused', () {
      expect(
        () => ProjectFile.decode('this is not json'),
        throwsA(isA<DesignDataException>()),
      );
    });

    test('a file from a newer build is refused, not half-read', () {
      final encoded = ProjectFile.encode(fullDesign())
          .replaceFirst('"formatVersion": 1', '"formatVersion": 99');

      expect(
        () => ProjectFile.decode(encoded),
        throwsA(
          isA<DesignDataException>().having(
            (e) => e.message,
            'message',
            contains('newer version'),
          ),
        ),
      );
    });

    test('the file name is derived from the project name', () {
      expect(
        ProjectFile.fileNameFor(fullDesign(name: 'Front door / rev 2')),
        'Front-door-rev-2.proframe',
      );
    });
  });

  group('old files are migrated, not rejected', () {
    test('a schema 1 project with a single note string still opens', () {
      // Spec section 10: do not silently destroy old projects during an
      // update.
      final legacy = {
        'schema': 1,
        'id': 'old',
        'name': 'Made by an earlier build',
        'createdAt': '2026-01-01T00:00:00.000Z',
        'updatedAt': '2026-01-01T00:00:00.000Z',
        'category': 'window',
        'material': 'pvc',
        'profile': {'id': 'generic.pvc.casement', 'version': 1},
        'finish': {'id': 'white', 'name': 'White', 'argb': 0xFFF4F4F1},
        'viewedFrom': 'outside',
        'dimensionReference': 'outerFrame',
        'fittingGapMm': 0,
        'displayUnit': 'millimetre',
        'dividers': <Object?>[],
        'sections': <Object?>[],
        'panels': [
          {
            'id': 'p1',
            'boundary': [
              [0, 0],
              [1000, 0],
              [1000, 800],
              [0, 800],
            ],
            'behaviour': 'fixed',
            'infill': {'kind': 'glazing', 'panes': 2, 'thickness': 24},
            'note': 'an old remark',
          },
        ],
        'sketch': {'strokes': <Object?>[]},
      };

      final design = DesignDocument.fromJson(legacy);

      expect(design.panels.single.notes, hasLength(1));
      expect(design.panels.single.notes.single.text, 'an old remark');
      // Saved forward at the current version.
      expect(
        design.toJson()['schema'],
        DesignDocument.currentSchemaVersion,
      );
    });
  });
}
