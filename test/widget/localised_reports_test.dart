import 'package:flutter_test/flutter_test.dart';
import 'package:proframe/core/i18n/app_language.dart';
import 'package:proframe/core/i18n/numerals.dart';
import 'package:proframe/core/i18n/product_labels.dart';
import 'package:proframe/core/i18n/strings.dart';
import 'package:proframe/domain/design_document.dart';
import 'package:proframe/domain/design_question.dart';
import 'package:proframe/domain/geometry/point2.dart';
import 'package:proframe/domain/geometry/polygon.dart';
import 'package:proframe/domain/layout/design_validator.dart';
import 'package:proframe/domain/layout/width_solver.dart';
import 'package:proframe/domain/measurement.dart';
import 'package:proframe/domain/panel.dart';
import 'package:proframe/domain/product/product_basics.dart';

const english = AppStrings();
const arabic = AppStrings(
  language: AppLanguage.arabic,
  numerals: NumeralSystem.arabicIndic,
);

DesignDocument windowOf({
  double width = 1200,
  double height = 900,
  List<Panel>? panels,
}) {
  final outline = Polygon.rectangle(width: width, height: height);
  return DesignDocument.blank(
    id: 'd1',
    category: ProductCategory.window,
    material: FrameMaterial.pvc,
    now: DateTime.utc(2026, 9, 12),
  ).copyWith(
    outline: outline,
    panels: panels ?? [Panel.fixed(id: 'p1', boundary: outline)],
  );
}

void main() {
  group('what the app found is said in the user language', () {
    test('a finding is a sentence in each language, never a code', () {
      final tiny = Polygon.rectangle(width: 20, height: 900);
      final design = windowOf(panels: [Panel.fixed(id: 'p1', boundary: tiny)]);
      final finding = DesignValidator.check(design)
          .firstWhere((f) => f.code == FindingCode.panelUnderMinimum);

      expect(english.findingMessage(finding), contains('under the'));
      expect(english.findingMessage(finding), contains('Panel 1'));

      final translated = arabic.findingMessage(finding);
      expect(translated, isNot(contains('under')));
      expect(translated, contains('الخانة ١'));
      // The numbers are written in the user's digits too.
      expect(translated, contains('٢٠'));
      expect(arabic.findingRemedy(finding), isNot(english.findingRemedy(finding)));
    });

    test('every finding the validator can produce has words in it', () {
      // One design that is wrong in as many ways as possible, plus the codes
      // it cannot produce, checked directly.
      for (final code in FindingCode.values) {
        final finding = Finding(
          level: FindingLevel.conflict,
          code: code,
          message: 'english',
          remedy: 'english',
          subjectNumber: 2,
          values: const {
            'gap': 10,
            'opening': 100,
            'width': 20,
            'height': 30,
            'minimum': 50,
            'total': 1000,
            'frame': 1200,
            'limit': 900,
          },
          profileName: 'Generic PVC casement',
        );
        for (final strings in [english, arabic]) {
          final message = strings.findingMessage(finding);
          expect(message.trim(), isNotEmpty, reason: '${code.name} says nothing');
          expect(message, isNot(contains('{')), reason: '${code.name} has a '
              'placeholder nobody filled in');
          expect(strings.findingRemedy(finding).trim(), isNotEmpty);
        }
      }
    });

    test('every outstanding question has words in it', () {
      for (final kind in DesignQuestionKind.values) {
        final question = DesignQuestion(
          kind,
          panelLabel: 'Left',
          source: MeasurementSource.estimated,
        );
        for (final strings in [english, arabic]) {
          final text = strings.question(question);
          expect(text.trim(), isNotEmpty, reason: '${kind.name} says nothing');
          expect(text, isNot(contains('{')), reason: '${kind.name} has a '
              'placeholder nobody filled in');
        }
      }
    });

    test('a width refusal explains itself, and offers the widest that works',
        () {
      final row = [
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
      final outcome = WidthSolver.setWidth(row, 'a', 1180);
      final refusal = outcome as WidthRefused;

      expect(english.widthRefusal(refusal), contains('not enough room'));
      expect(english.widthRefusal(refusal), contains('widest'));

      final translated = arabic.widthRefusal(refusal);
      expect(translated, contains('أقصى عرض'));
      expect(translated, isNot(contains('{')));
    });

    test('every refusal the solver can produce has words in it', () {
      for (final code in WidthRefusal.values) {
        final refusal = WidthRefused(
          'english',
          code: code,
          values: const {'minimum': 50, 'requested': 1180, 'neighbour': 20},
        );
        for (final strings in [english, arabic]) {
          expect(strings.widthRefusal(refusal).trim(), isNotEmpty);
          expect(strings.widthRefusal(refusal), isNot(contains('{')));
        }
      }
    });
  });
}
