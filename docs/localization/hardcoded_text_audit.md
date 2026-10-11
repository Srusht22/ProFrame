# Phase 34 — what text is left in the code, and why

Written after the English and Central Kurdish work was finished, 2026-10-11.
It is the follow-up to the audit before it (`phase_34_audit.md`). That
audit counted about 1,800 string literals in `lib/` that could have been
user-visible text. This one goes through what is left after the work and
puts each kind in one class. Every class but the first is text the
application does not translate, and each says why.

The scan behind it lists every quoted literal in `lib/` that reads like
words: a capital letter followed by lower case, or two words with a space.
Generated files are skipped. Comments and keys are left out.

## 1. Translated: everything the user reads

All of it comes from `lib/app/l10n/app_en.arb` and `app_ckb.arb`
(1,219 messages each).

- **Screens** read `context.l10n`. These are the customers, a customer's
  page, the new customer, design and design-information forms and *Choose
  your design*. So are Settings, the workspace and its bars and tools, the
  Draw, CAD and 3D views, the inspector panel, the parts list, the sizes
  and material forms, and the alerts and questions. The price panel, the
  price sheet and its breakdown, the extra-charge form, the financial
  summary, the payment, refund and discount dialogs, quotations and
  receipts are too, along with factory prices and the colour catalogue,
  staff and permissions, sign-in and the PIN dialogs.
- **Messages the domain makes** are said through `Words`
  (`lib/domain/text/words.dart`). That interface is generated from the
  `[domain]` ARB entries, so the domain stays pure Dart. They cover:
  - the price's requirements and readiness, and the engine's issues;
  - the payment, refund, discount, quotation, extra-charge, colour-catalogue
    and factory-price checks;
  - the size form's checks;
  - the geometry check;
  - the questions a reading raises and the names of openings, parts and
    sides;
  - the enum labels, through the `labelIn(Words)` extensions in
    `lib/domain/text/names.dart`;
  - and the price list's upgrade notes.
- **Painted words** follow the language too: GLASS, PANEL, IN and OUT, and
  the names of the rows of figures on the technical drawing (`CadPainter`
  and `DimensionLayout` are handed `Words`). So does Flutter's own wording
  (back, close, OK, the date picker, copy and paste): Central Kurdish has no
  Flutter localisation, so `lib/app/l10n/kurdish_framework.dart` supplies it
  from the same ARB (`fw…`).

## 2. English kept in code on purpose: the default the tests read

Some English stays in the code as the English the domain's own tests
check: each enum's `label`, and each message's English through
`EnglishWords`. Screens never read these directly; they call `labelIn`,
`messageIn` and the like. `test/app/the_words_are_one_set_test.dart`
requires each one to be exactly what the ARB's English says.

A few widget constants keep their English for the same reason, and the
widget shows the ARB message in their place:

- `StartScreen.choices` (the blurbs), `straighteningNote` and `startLabel`;
- `CompleteBar.label` and `CompletedDialog.success`;
- `UnsupportedCategoryNote.title` and `message`;
- `ViewOnlyNote.message`;
- `DesignPreview.nothingDrawnLabel` and `unavailableLabel`;
- `PricingOptions.notSelected`, `PriceButton.notAllowed`.

## 3. Not words: identifiers, keys and formats

None of these is ever shown as text:

- widget keys;
- storage keys (`proframe.*`);
- ids made from a prefix (`kind-…`, `grip-…`, `opening-…`, `EXT-…`, `DSC-…`,
  `Q-000001`, `RCP-000001`, `PAY-…`);
- route names (`/customer/…`);
- serialised enum names and JSON field names;
- font family names (`Noto Sans`, `Noto Sans Arabic`);
- `toString()` output for debugging;
- the facet-identity string `ModelPainter` uses for comparison.

None of these depends on the language. Every stored record reads the same
whichever language wrote it.

## 4. Figures, units and marks: the same in both languages

These stay as they are in both languages:

- figures, written with Latin digits in both;
- the units `cm`, `m`, `m²`, `mm` and `°`;
- currency codes (`USD`, `EUR`, …);
- the signs `×`, `−`, `+` and `%`;
- the opening marks `<`, `>`, `^`, `v` and the sliding arrows;
- `?` for a size not given yet.

Interpolated strings that only join these (`'${w} × ${h} cm'`,
`'−${money}'`) are not translatable text. In a right-to-left paragraph a
run like `120.0 × 80.0 cm` or `189.98 USD` stays one left-to-right run,
and reads correctly.

## 5. The user's own data: never translated

Changing the language changes none of these:

- customer names, phones, addresses and notes;
- design names;
- notes on the drawing;
- an extra charge's name, its typed unit and its note;
- a payment's note and description;
- the names of the factory's colour catalogue;
- staff names.

`test/app/the_app_in_central_kurdish_test.dart` checks that switching
language leaves the device's storage byte for byte as it was, apart from
the language setting itself.

## 6. English written into records, and shown in the language of the day

Some records were written in English, by this version or an earlier one,
and are kept as written. They are shown in the chosen language without
being rewritten:

- **A price line's label** (`PriceLine.label`) is still written in English,
  and is now written next to a language-free `LineName`. `labelIn(w)` reads
  the `LineName`, so a kept price or quotation shows in either language. A
  line kept before this phase has no `LineName` and shows its English
  label.
- **A quotation line's category, material and colour** were written as
  English labels. `keptCategoryIn`, `keptMaterialIn` and `keptColourIn`
  read them in the chosen language; a catalogue colour's name is the
  factory's own.
- **The legacy payment's note** (*Migrated from the previous customer
  payment balance.*) is the application's own wording. It is shown through
  `PaymentTransaction.noteIn`. Any other note is the user's.
- **Who recorded something** (`by` on a payment, discount, extra or
  quotation) is kept as written. It is a record of who it was, not a
  message.

## 7. English left on purpose, and why

| Where | What | Why it stays English |
| --- | --- | --- |
| `StaffMember.problemGiving`, `StaffStore` | Refusals thrown as `ArgumentError` | A guard behind the screens. The dialogs check first and say the same thing in the chosen language, so a user never sees these. |
| `CustomerStore.saveExtra` | The double-charge refusal thrown as `StateError` | The same: the extra-charge form checks first, in the chosen language. |
| `NewDesignSetup.begin` | `StateError` for a setup not complete | A programming guard; the screens never call it with an incomplete setup. |
| `DimensionConflict.message` | *This reads … but you typed …* | Not shown anywhere: the geometry check says it through `Words`. |
| The interpreter's gap side (`'the bottom'`, …) | Internal names | Compared inside the reading only; shown through `_Gap.sideIn(w)`. |
| `DefaultFactoryPricing` category labels | `'Door'`, `'Window'`, … in the example price list | Data in the price list. The factory prices screen shows each category through `DesignKind.labelIn`. |
| `Surface`, `FrameProfile` names | Material descriptions in the renderer | Never shown as text. |
| `brandName` on the launch screen | کارگەی وەستا سۆران شارباژێڕی | The workshop's own name, already in Kurdish, and never altered. |
| `AppLanguage.endonym` | `English`, `کوردی (سۆرانی)` | Each language is named in itself, as a language list should be. |
| Flutter's own words that `KurdishMaterialLocalizations` does not override | Rarely shown labels: some screen-reader hints, time-picker words the app never opens | English is the promised fallback. Everything the application's screens show is overridden. |

## How it is kept this way

| Test | Holds |
| --- | --- |
| `test/app/the_words_are_one_set_test.dart` | The two ARB files have the same keys and placeholders. No Kurdish message is empty or equal to its key. The generated `Words`, adapter and localisations are current. The domain's English equals the screen's. Every Kurdish letter has a glyph. |
| `test/app/the_app_in_central_kurdish_test.dart` | English by default and left to right. The switch in Settings works at once, is kept, and the app reopens in it. Kurdish is right to left. A language the app does not know opens in English. Storage is unchanged by switching, the same price figure shows in both, and no key is ever shown. Nothing overflows in Kurdish at a phone's, a tablet's or a laptop's width. The technical drawing is not mirrored, and design names are never translated. |
| `test/app/the_translation_review_test.dart` | The review file lists every message with the wording the application shows, and the apply tool reads an approved row exactly. |
