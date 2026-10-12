# Phase 35 — audit before the work

Written 2026-10-12, before any code for Phase 35 was changed. It records
what the pricing screens, the price list and its editor, extras,
discounts, permissions and the language and appearance settings are
today, and decides where each change in the brief goes. The aim is to
reuse what is there and not add a second engine, store or screen.

## The price summary (the screenshots)

`DesignPriceSheet` (`lib/app/inspector/price_actions.dart`) is the bottom
sheet that **Calculate price** and a card's **Price** open. Top to bottom
it shows:

1. *Design price* and the design's name, then its category.
2. `ProfileChooser`, the material and colour pickers.
3. `PricingOptions`: the aluminium category, *Set each part*, and the
   *Include glass in price* switch with its note.
4. **MATERIAL MEASUREMENTS** (`MeasurementRows`): border length, internal
   line length, combined length, opening profile, other profile, total
   profile, panel m² and glass m². That is eight rows of figures before
   any price.
5. **COST BREAKDOWN** (`PriceBreakdown`, in `extra_charges.dart`):
   - an *AUTOMATIC DESIGN COSTS* heading;
   - each price group's lines, with label, quantity and rate run together
     on one line (`   System Aluminium — Border · 12.000 m × 8.00`) and
     the amount beside it;
   - *Combined profile cost*, then *Design cost*;
   - *EXTRA CHARGES*, *Extras cost*, *Subtotal* and *Discount*.
6. *Final total*, at the very bottom.

What makes it hard to read:

- **The final total comes last.** On a phone it is three or four screens
  down, below eight measurement rows and the choices.
- **Measurements and prices are two separate lists.** The border's 12 m
  is in one list and its 96.00 in the other.
- **Several totals look alike**: combined profile cost, design cost,
  extras cost, subtotal and final total all share one row style.
- **A line's quantity and rate run into its label**, indented with spaces
  and joined by a dot. A long Sorani label wraps into the figures.
- **The rate has no unit or currency** (`× 8.00`), so a metre rate cannot
  be told from a square-metre one.
- **Colour, hardware, labour and installation have no headings.** They are
  groups inside one undivided list.
- **Choosing things and reading the price share one list**, so the result
  is pushed below the controls.
- **There is no close control**, only the drag handle.
- **There is no way to the factory's rates.**

What stays: the figures come from `PriceResult`, the engine's output, and
the sheet adds nothing up itself. The keys tests read (`totalKey`,
`ExtraKeys.*`) stay on the same values.

## How a price is worked out (kept as is)

- `PricingEngine` (`lib/domain/pricing/pricing_engine.dart`) prices the
  takeoff (`PricingTakeoff`) at the price list's rates.
- **Normal profile** (the border and the internal lines) has one rate per
  material. Aluminium has one rate per profile category, *System* and
  *Bend Shoulder*, in `ProfileRate.categories`. The border and the lines
  are measured apart (`ProfilePart`) and **charged at the same rate**: the
  model has no separate line rate, and none is invented here.
- **Opening profile** has one rate per material
  (`ProfileRate.openingPerMetre`). Aluminium's opening profile is **not**
  split by category, and stays that way.
- **Colour** adds so much a metre plus a percentage per catalog colour and
  material (`FactoryColour`), and the material's *any other colour*
  figure for a colour the catalog does not name.
- **Glass** has a single-sheet rate per look and a sealed-unit rate per
  look, each with a custom-colour figure, per m². It is charged only
  where the design's own switch is on (`PricingChoices.glassPriced`, off
  by default since Phase 33).
- **Panel** has a rate per `PanelColour` and a custom-colour figure, per
  m².
- **Hardware** is priced by the piece, per `HardwareKind`.
- **Sliding** adds the track per metre and rollers by the piece.
- **Labour** is per category, as a fixed figure, a figure per m² and a
  percentage. **Installation** is a fixed figure plus a figure per m².
- Rounding: every line is whole cents, half a cent up (`Money.cents`).
  This is not touched.

## The price list and its editor

- `PriceList` is kept by `PriceListStore` (`proframe.pricelist.v2`,
  schema 5). `save` requires `pricing.edit` and bumps the version.
- `FactoryPricesScreen` already exists, and every figure is a `RateField`
  (`price_list_fields.dart`). It already works field by field: one numeric
  field per rate, unit suffix, validation, and a single **Keep prices**.
  Its gaps:
  - no explanation of what each rate applies to;
  - the unit has no currency;
  - nothing says which rates are shared;
  - no way to discard unsaved edits, and leaving with them loses them
    silently;
  - a storage failure is not caught;
  - no confirmation before a broad change;
  - glass rates always shown, with no factory-level glass setting;
  - the numeric filter refuses Eastern Arabic digits.

  **Decision: improve this screen; do not add a second one.**
- A kept price is current only for the design and the price list as they
  were (`PriceInputs.of` hashes `list.toJson()`). So any change to the
  price list's JSON makes every kept price *needs recalculation*.
  Quotations keep a full `PriceResult` and are never repriced.

## Extras

- `ExtraCharge` (`extra_charge.dart`) holds quantity × unit price, a
  category, a unit and a currency. Its scope is a design
  (`PricingChoices.extras`) or the customer's whole job
  (`Customer.extras`). Each is counted once: a design's extras in the
  design's price, and a customer's extras once in `CustomerFinance`.
- `ExtraDialog` is the only form. Every extra is a one-time item typed in
  full. **There is no factory catalog of extras.**
- **Decision:** add a catalog of the factory's usual items
  (`ExtraItem`), kept by its own store (`ExtraCatalogStore`,
  `proframe.extra-items.v1`) and written only with `pricing.edit`.
  - The extra added to a design stays an `ExtraCharge`, a copy of the
    item's name, category, unit, price and currency at that moment, with
    the item's id beside it. So a catalog change never reprices anything
    already added.
  - The catalog is kept apart from the price list on purpose: adding
    silicone to the catalog changes no rate, so it must not make every
    kept price *needs recalculation*.
  - One-time custom extras stay as they are.

## Discounts

- A design discount (`PricingChoices.discount`, `DesignPricing.setDiscount`)
  and a customer discount (`Customer.discounts`) both exist, each with its
  dialog and each requiring `discounts.apply`. Nothing changes in either.
  The summary shows the design discount as a line of its own.

## Permissions

- Capabilities come from `Authority` and `actorProvider`. The stores call
  `require` (`PriceListStore.save` → `pricing.edit`; extras →
  `extras.create`, `.edit`, `.delete`; discounts → `discounts.apply`).
- Holding `extras.create` does **not** give `pricing.edit`.
- `Offering.offers` and `permissionsKnown` keep a control hidden until
  the permissions are known.
- The PIN is a lock on a device, not authentication.

## Language and appearance

- Language is chosen only in **Settings** (the gear on the customers'
  header), kept in `proframe.language`. **There is no language icon.**
- Appearance is `AppearanceButton` on the customers' header: a popup of
  Match device, Light and Dark, its icon showing the current mode, kept in
  `proframe.appearance`. Settings offers it too.
- **Decision:** add a dedicated `LanguageButton` (the translate icon) next
  to the appearance button, on the customers' header and on a customer's
  page. Keep the appearance button, which is already separate, and give it
  a clear label.

## The four Phase 34 leftovers

1. **Digits.** Every figure is written in Latin digits by design, and
   every numeric field filters to `[0-9.]`. So **a Kurdish keyboard's
   Eastern Arabic digits (٠–٩) cannot be typed into any price, size or
   quantity.** That is a real fault.
   - **Decision:** keep Latin digits for display. Technical drawings,
     units and currency codes are Latin, and a mixed display would be
     worse than one convention.
   - Make every numeric field and every reader accept Eastern Arabic and
     Persian digits and the Arabic decimal separator, turning them into
     Latin as they are typed.
2. **Errors in English.**
   - `StaffStore`, `CustomerStore.saveExtra` and `issueReceipt` throw
     English `ArgumentError` or `StateError`.
   - `StaffScreen` shows `e.message` raw.
   - Completing a design shows the raw exception (`completeSaveFailed('$e')`).
3. **Flutter's own words.** Missing in Kurdish:
   - `parseCompactDate`, which uses month/day order while the Kurdish
     `formatCompactDate` writes day/month — a real fault in the date
     picker's typing mode;
   - the *look up*, *search web* and *share* buttons on a phone's
     text-selection menu;
   - the drawer's and the scrim's labels;
   - every Cupertino word, which an iPhone's text-selection menu shows.
4. **Mixed titles.** An English design name in a right-to-left title is
   laid out right to left. It is cut with the ellipsis on its left, which
   reads as its start.
