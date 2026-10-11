# Phase 34 — localization audit (before implementation)

Written 2026-10-10, before any screen was converted.

## What was there

- **No localization at all.** `pubspec.yaml` declared no
  `flutter_localizations`, `MaterialApp` had no delegates or locale, and
  every word on every screen was an English literal in a Dart file.
  `test/the_source_tree_is_the_architecture_test.dart` went further and
  refused any `.arb` or `app_localizations*` file under `lib/`, because an
  earlier, untracked generated layer (`lib/core/localization/`) had been
  left on disk and broke the editor.
- **No settings screen.** The customers' header carried an appearance
  button (Match device / Light / Dark, kept as `proframe.appearance` in
  shared preferences), the account button and the factory prices button.
- **Fonts.** `Noto Sans` is the application's face. `Noto Sans Arabic` was
  bundled in `pubspec.yaml` but nothing used it; `Vazirmatn` and
  `Aref Ruqaa` set the workshop's name on the launch only.
- **Text in painters.** The technical drawing (`CadPainter`), the drawing
  (`DesignPainter`) and the model's technical mode write words on the
  canvas — GLASS, PANEL, OVERALL, DAYLIGHT, IN / OUT — with `TextPainter`,
  outside any widget's text style.
- **Text in the domain.** The domain is pure Dart, and it composes many
  of the sentences the user reads: what a design still needs before it can
  be priced, every refusal of a payment, discount, extra charge or colour,
  the names in the sizes form (*Opening 1 — Clear glass 1*), the questions
  a reading puts, the angled-design checks, the labels of every enum
  (categories, materials, glass looks, colours, methods, permissions).

## How much text

A scripted sweep of every string literal under `lib/` (imports, keys and
identifiers left out) found about 1,800 candidates:

| Where | Candidates | Biggest |
| --- | --- | --- |
| `lib/app` | ≈ 1,200 | inspector panel 152, customer finance 96, finance documents 73, customer page 62, extra charges 53, workspace state 43, factory colours 41, CAD view 39 |
| `lib/domain` | ≈ 580 | permissions 57, element labels 55, geometry feedback 51, price list fields 42, materials 40, price state 38, interpreter questions 37 |
| `lib/infrastructure` | ≈ 25 | customer store refusals |

Some of those are not user-visible (ids such as `PAY-…`, `toString`s,
debug strings); each is classified in the checklist kept with the
implementation (`docs/localization/hardcoded_text_audit.md`).

## Risks found

- **Kurdish is not a Flutter locale.** `flutter_localizations` has no
  `ckb` Material, Cupertino or Widgets localizations, so without our own
  every dialog fails in Kurdish and the layout stays left to right. intl
  has no `ckb` plural rules (it falls back to *other*).
- **Generated code is the old trap.** Generated files must be tracked, and
  the architecture test must change with the new layer rather than be
  deleted.
- **Persisted text.** A price line's label and a quotation's snapshot are
  kept with the record. Translating them where they are made would put the
  language into stored data, so they stay English in storage and are
  translated where they are shown.
- **User data.** Customer names, design names, notes, a colour's name in
  the factory's catalog and an extra charge's own name are the user's and
  are never translated.
- **Geometry.** The drawing, the technical drawing and the model are laid
  out in physical coordinates; right to left must not mirror them.
- **Tests.** About 2,600 tests read English on the screen; English must
  stay exactly what it was.

## Approach chosen

- `flutter gen-l10n` with `lib/app/l10n/app_en.arb` (template, fallback)
  and `app_ckb.arb`, generated into `lib/app/l10n/` and kept in git.
- `KurdishFramework` delegates for Material, Widgets (right to left) and
  Cupertino, their words also in the ARB files (`fw…`).
- A **Settings** screen (gear on the customers' header) with the language
  and the appearance; the language kept as `proframe.language`, read
  before the first frame.
- The domain says its sentences through `Words`
  (`lib/domain/text/words.dart`), generated from the ARB entries marked
  `[domain]`: `EnglishWords` for the domain's own English, `ArbWords` for
  the application's language. Nothing about the domain's logic changes,
  and every domain test still reads English.
