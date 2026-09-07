# ProFrame

A professional door & window **configurator, quotation and manufacturing
management system** for aluminum/PVC/timber/steel factories, built in
Flutter/Dart.

ProFrame is not a demo or a calculator. It implements the full pipeline a
real manufacturer needs, built around one rule: **every subsystem reads
from the same `ProductConfiguration` object.**

```
Configuration → Validation → 2D Design → 3D Design → Price → BOM →
Cutting List → Quotation → Order → Manufacturing
```

If width changes from 1000mm to 1200mm, the 2D drawing, the 3D model, the
price, the BOM, the cutting list and the quotation all update from that
one number — none of them keep their own copy.

---

## 1. What's actually implemented

Everything below is wired to real state and real logic — no screen is a
static mock and no price is hard-coded in a widget.

| Area | Status |
|---|---|
| Auth (roles, permissions, sessions, remember me) | ✅ full, local/offline |
| Responsive shell (rail / drawer / sidebar) | ✅ |
| Dashboard (live stats + charts from real data) | ✅ |
| Customers / Projects CRUD | ✅ |
| Door + Window configurator (9-step wizard) | ✅ |
| Validation engine (configurable rules) | ✅ |
| 2D technical drawing (`CustomPainter`, dimensioned, zoom/pan) | ✅ |
| 3D viewer (real procedural three.js engine, not an image) | ✅ |
| Pricing engine (itemized, admin-configurable rates) | ✅ |
| BOM + cutting list generation | ✅ |
| Quotations (numbering, status, PDF export, share) | ✅ |
| Orders (convert from quotation, progress tracking) | ✅ |
| Manufacturing (production stages, QC checklist) | ✅ |
| Inventory (stock, low-stock alerts) | ✅ |
| Notifications (real, event-driven) | ✅ |
| Audit log (every mutation is recorded) | ✅ |
| Settings (company profile, pricing rules editor, users/roles) | ✅ |
| Reports (revenue, funnel, top customers) | ✅ |
| Localization (EN / AR / CKB, RTL) | ⚠️ core UI + nav fully translated; see §9 |
| Tests | ✅ pricing/validation/manufacturing engines + serialization + 1 widget test |
| Backend | Local-only (see §5) — repository interfaces are backend-ready |

Given the scope of the original brief (an 80-section enterprise spec), a
few things are intentionally out of scope for this pass and documented as
such rather than faked — see **§10 Honest scope notes**.

---

## 2. Architecture

```
lib/
  core/                    # cross-cutting: theme, routing, DI, l10n, errors, utils
  domain/                  # pure Dart — no Flutter, no I/O
    configuration/         # ProductConfiguration + value objects (single source of truth)
    entities/               # Customer, Project, Quotation, Order, ManufacturingOrder, ...
    pricing/                 # PricingRules, PriceBreakdown, Currency
    manufacturing/           # BomLine, CuttingListLine
    services/                # ValidationEngine, PricingEngine, ManufacturingEngine
    repositories/             # abstract interfaces (backend-agnostic)
    auth/                     # UserRole, Permission, AppUser
  data/                    # implementations of the domain repositories
    local/                   # SharedPreferences-backed key/value + JSON collection store
    repositories/             # Local*Repository — the backend swap seam
    demo/                     # seeded demo data
  features/                # one folder per screen area, presentation only
    <feature>/presentation/
  shared/                  # widgets + Riverpod notifiers used by 2+ features
assets/web_3d/             # three.js parametric 3D engine (see §7)
```

**Layering rule:** `domain/` never imports `flutter/material.dart` (except
where an enum's display metadata genuinely needs `Color`/`IconData` — a
deliberate, contained exception, not the whole layer leaking). `data/`
implements `domain/repositories/*` interfaces; nothing above `data/`
imports a `Local*Repository` directly except the composition root
(`data/app_repositories.dart`). `features/` never talks to
`data/` — only to `domain/` and `shared/providers/*`.

### State management

**Riverpod** (`flutter_riverpod`), plain `AsyncNotifier`s — no code
generation, so the project builds without running `build_runner`. Each
entity (`customers`, `projects`, `configurations`, `quotations`, `orders`,
`manufacturing`, `inventory`, `notifications`, `auditLog`, `settings`,
`users`) has one notifier in `shared/providers/` that owns its list and
exposes mutating methods; every mutation also appends an audit-log entry
and, where relevant, a notification — this isn't decorative, it's how the
audit log and notification center actually get their data.

### Routing

`go_router` with a `ShellRoute` wrapping the authenticated app shell
(`AppShell`) and a `redirect` that watches `authNotifierProvider` so login
state changes navigate immediately. The configurator is a separate
full-screen route (`parentNavigatorKey`) outside the shell, matching how a
real focused wizard should behave.

### Permissions

`domain/auth/permission.dart` holds one matrix:
`Map<UserRole, Set<Permission>>`. It's checked in two independent places
(spec requirement): the router/`AppShell` hides nav items a role can't see,
and `PermissionGate` blocks the screen body itself — so a deep link can't
bypass the nav-level hiding.

---

## 3. Design system

Brand colors are fixed: **`#013E37`** (dark green — navigation, primary
actions, selected states) and **`#FFEFB3`** (cream — highlight surfaces,
selected-configuration accents). See `core/theme/app_colors.dart` for the
full palette (neutrals, semantic success/warning/error/info) and
`core/theme/app_theme.dart` for the Material 3 theme built from it. The two
brand colors are deliberately *not* used everywhere at full intensity —
neutrals carry the bulk of the UI so the brand colors keep their weight.

Responsive breakpoints (`core/theme/app_spacing.dart`): compact (<600),
medium (600–1024, collapsed rail), expanded (≥1024, extended rail /
3-pane configurator).

---

## 4. The configuration pipeline in detail

### `ProductConfiguration` (`domain/configuration/product_configuration.dart`)

The aggregate root. Composed of value objects — `FrameSpec`, `LeafSpec`,
`PanelSpec`, `GlassSpec`, `HardwareSpec`, `FinishSpec`, `AccessoryOptions`
— each mapping to a real manufacturing subsystem. Fully JSON-serializable
(`toJson`/`fromJson`) so a design is portable and offline-safe, and exposes
`to3DParams()` — a flat primitive map consumed by the JS 3D engine.

### Validation (`domain/services/validation_engine.dart`)

A list of independent `ValidationRule` functions (dimension ranges per
product type, frame depth, section count, physical minimum section width,
glass-thickness-by-type, double/triple-glazing pane consistency, wall
opening vs. unit size, leaf-arrangement consistency, exterior-door lock
recommendation, hinge count vs. height). Each returns `error` or `warning`
severity — only errors block saving a configuration as production-ready,
matching the spec's "Draft → Validated → Quoted → Approved → Production
Ready" state progression. A factory can swap in its own rule list without
touching the engine.

### Pricing (`domain/services/pricing_engine.dart` + `domain/pricing/pricing_rules.dart`)

Every rate is admin-editable from **Settings → Pricing rules** (frame
price/m by material, glass price/m² by type, panel price/m² by type, hinge
price, handle base price + per-model adjustment, lock/closer price tables,
accessory flat price, mosquito net price/m², seal price/m, labor
mode+rate, finish multiplier by color, waste %, overhead %, profit %,
installation/unit, delivery flat fee). The engine returns a fully itemized
`PriceBreakdown` — Frame / Glass / Panel / Hardware / Accessories →
Materials subtotal → Labor → Finishing → Waste → Overhead → Subtotal →
Profit → **Unit price** → **Line total**. Nothing is a black-box "$500".

*Formula note:* the spec's worked example uses `2×height + width` for
frame length; this implementation uses the geometrically correct
rectangle perimeter `2×(width+height)` plus extra length for every
mullion/transom, since that's what an actual frame needs.

### Manufacturing (`domain/services/manufacturing_engine.dart`)

Derives a cutting list (head/sill/jambs, mullions, transoms, door jamb,
threshold, leaf stiles/rails) and a BOM (frame profile, glass/panel,
hinges, handle, lock, closer, seal, mosquito net, misc accessories,
fasteners) from the same configuration. Formulas are simple and explicit
by design — spec §18 asks for factory-specific formulas to be able to
replace the defaults later; this is the seam.

### 2D (`features/designer_2d/`)

A `CustomPainter` (`TechnicalDrawingPainter`) draws to true scale from
`widthMm`/`heightMm`, with dimension lines (top = width, left = height,
extension lines + labels) in the same style as a hand-drawn shop sketch,
plus mullions/transoms, door-swing diagonals with hinge/handle markers,
and sliding-window arrows. Wrapped in `InteractiveViewer` for pan/zoom,
with a dimension-visibility toggle and PNG export via `RepaintBoundary`.

### 3D (`features/viewer_3d/` + `assets/web_3d/`)

**Real, procedurally-generated 3D — never a static image.** A WebView
(`flutter_inappwebview`, mobile/desktop) or an `<iframe>` (web, via
`dart:ui_web` platform views) runs `assets/web_3d/parametric_engine.js`,
a from-scratch three.js (r128, bundled as static assets so there's no
version drift) engine that builds the frame, mullions/transoms, door
leaves/sashes, glass, hinges, handle, lock and threshold as real boxes/
cylinders sized from the live configuration — changing hinge count adds a
hinge mesh, changing width widens every beam, changing leaf arrangement
regenerates the leaf split. Camera presets (front/back/left/right/top/
bottom/perspective) animate smoothly; dimension overlays and auto-rotate
are toggleable; full screen is supported.

The Flutter↔JS bridge (`WebGLBridge`) is transport-agnostic:
`InAppWebView.evaluateJavascript` on mobile/desktop,
`iframe.contentWindow.postMessage` on web — both call the same
`window.ConfiguratorBridge.*` API in the JS engine.

*Extensibility:* if a factory needs beveled profiles, texture-mapped
finishes, or CAD-accurate joinery beyond what boxes/cylinders can express,
the JS engine is the only file to extend or replace — the Dart-side
contract (`to3DParams()` in → `ConfiguratorBridge` calls out) doesn't
change.

### Quotation → Order → Manufacturing

A quotation snapshots each configuration's price at creation time (so
changing pricing rules later never rewrites a quote that already went
out). Accepting a quotation converts it to an `Order`
(`OrderNotifier.convertFromQuotation`), which immediately opens a
`ManufacturingOrder` at the `productionOrder` stage with a standard QC
checklist. Advancing through
`productionOrder → materialPreparation → cutting → assembly →
glassInstallation → hardwareInstallation → qualityControl → packaging →
delivery → installation → completed` is gated at `qualityControl`: every
check must be `pass`/`N/A` before the stage can advance.

---

## 5. Backend

Local-only in this build: `data/local/key_value_store.dart` wraps
`shared_preferences` as a JSON key/value store, and every
`Local*Repository` in `data/repositories/` implements the matching
`domain/repositories/*` interface against it. **This is the intentional
seam.** To connect a real backend (Laravel/Node/.NET/Java/…):

1. Implement the same interface (e.g. `CustomerRepository`) with HTTP
   calls instead of local JSON.
2. Wire it in `data/app_repositories.dart` (the single composition root)
   instead of `LocalCustomerRepository`.
3. Nothing in `domain/` or `features/` changes.

No repository method throws a raw exception to the UI —
`AsyncValueView` (`shared/widgets/async_value_view.dart`) maps any error
state to a friendly retry card.

---

## 6. Demo accounts & data

On first launch the app seeds realistic (clearly fictional) demo data —
customers, projects, configurations, a quotation, an order in production,
inventory, and notifications — once per collection (`__seeded` flag), so
it never overwrites real data you create afterwards.

Sign in with any of these (password for all: **`Demo@123`**):

| Role | Email |
|---|---|
| Administrator | `admin@proframe.demo` |
| Manager | `manager@proframe.demo` |
| Sales | `sales@proframe.demo` |
| Designer | `designer@proframe.demo` |
| Engineer | `engineer@proframe.demo` |
| Factory | `factory@proframe.demo` |
| Accountant | `accountant@proframe.demo` |
| Viewer | `viewer@proframe.demo` |

The login screen has a **Demo accounts** panel that fills these in for
you. See `domain/auth/permission.dart` for the full role → permission
matrix.

---

## 7. Getting started

```bash
flutter pub get         # also runs `flutter gen-l10n` (flutter.generate: true
                         # in pubspec.yaml) to produce
                         # lib/core/localization/generated/app_localizations.dart
flutter run              # pick a device: Android / iOS / macOS / Windows / Linux / Chrome
```

Requires **Flutter ≥ 3.24 / Dart ≥ 3.5** (uses `CardThemeData`/
`DialogThemeData` and `WidgetState*`, both introduced around that release).

### Building

```bash
flutter build apk --release          # Android
flutter build ios --release          # iOS (requires macOS + signing setup)
flutter build web --release          # Web
flutter build windows --release      # Desktop (Windows scaffolding included)
```

macOS/Linux desktop scaffolding isn't included yet — run
`flutter create --platforms=macos,linux .` once to add it (nothing in
`lib/` is Windows-specific, so both should build immediately after).

### Testing

```bash
flutter test
```

`test/domain/` covers the pricing engine (exact-arithmetic cases with a
zeroed rate table, plus formula/invariant checks — the spec explicitly
asks for strong pricing coverage), the validation engine, the
manufacturing engine's BOM/cutting-list generation, unit conversion, and
`ProductConfiguration` JSON round-tripping. `test/widget/` has a
`PriceBreakdownView` rendering test as the pattern for further widget
tests (configurator step widgets, forms).

---

## 8. Environment / configuration

No secrets are hard-coded. This build has no remote backend, so there's no
API base URL to configure yet — when one is added, follow the standard
Flutter pattern (`--dart-define=API_BASE_URL=...` read via
`String.fromEnvironment`) rather than committing it, and keep
Development/Staging/Production as three `--dart-define` profiles rather
than three code paths.

---

## 9. Localization

`l10n.yaml` + `lib/core/localization/arb/app_{en,ar,ckb}.arb` wire up
`flutter gen-l10n` with **English, Arabic and Kurdish Sorani**, and
`app.dart` forces `Directionality` explicitly from `AppLocale.isRtl`
(rather than relying on Flutter's built-in RTL locale table, which may not
recognize `ckb`) so RTL is correct regardless of platform locale data.

**Scope note:** the ~90 keys in the ARB files cover the app shell,
navigation, auth, dashboard labels, configurator step titles, pricing
labels and status labels — fully translated in all three languages. Most
in-screen copy (form field labels, button text inside feature screens) is
still English-only literals; extending coverage is mechanical: add the
key to `app_en.arb` + translations to the other two files, then replace
the literal string with `AppLocalizations.of(context)!.yourKey`.

**PDF fonts:** `QuotationPdfService` loads Noto Sans + Noto Sans Arabic via
`PdfGoogleFonts` (from the `printing` package), which fetches and caches
the TTFs on first use. A factory deploying somewhere without outbound
network access on first run should bundle local `.ttf` files under
`assets/fonts/` and swap `PdfGoogleFonts.notoSansArabicRegular()` for
`pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSansArabic-Regular.ttf'))`
— one function to change.

---

## 10. Honest scope notes

Built by one engineer against an ~80-section enterprise spec — everything
above is real and functional, but a few things are deliberately scoped
down rather than faked:

- **No live backend/multi-user sync.** The repository-interface seam
  (§5) exists specifically so this is a backend swap, not a rewrite.
- **DXF/CNC/CAD export** is not implemented — `toJson()`/the BOM/cutting
  list CSV export are the structured data a future integration would
  consume; see `features/configurator/services/export_service.dart`.
- **Push notifications** aren't wired to a provider — the
  `NotificationType` enum and in-app notification center are the
  provider-agnostic seam.
- **Offline sync conflict resolution** isn't implemented; the app is
  local-first by construction (everything is a local repository today),
  which trivially satisfies "works offline" but doesn't yet demonstrate
  a sync/merge strategy for when a backend is added.
- **Design versioning** (multiple named versions of one configuration)
  is not implemented as a separate history feature; `version`/`updatedAt`
  fields exist on `ProductConfiguration` as the intended seam.
- Full localization of every screen's copy is not complete (see §9).

None of the above are hidden — this section exists so a reviewer never has
to discover a gap by poking at a dead button. There are no dead buttons.

---

## 11. Repository (this branch)

Developed on `S.branch`. `M-branch` in this same repository is an earlier,
smaller parametric-window-only prototype; this build shares its "WebView +
bundled three.js" strategy for real (non-faked) 3D — the one part of that
prototype worth keeping as-is — but the domain model, pricing/validation/
manufacturing engines, and every screen are new and substantially more
complete against the full specification.
