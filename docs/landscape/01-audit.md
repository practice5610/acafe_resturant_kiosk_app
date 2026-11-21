# Landscape Tablet Kiosk — Audit & Build Plan (01)

**Status:** Read-only audit. No source files were changed. Awaiting review before any code.
**Scope:** Add "PART B: TABLET KIOSK, OPTION B" (landscape, Figma base 1366×1024) to the existing
Flutter kiosk app **without touching the finished portrait kiosk**. Portrait must stay pixel-identical
on every portrait size — zero regressions.
**Figma:** file `egyp8Y2o5BtoJLo8SrcWrX`, section `2305:3347` (read with `get_metadata` + `get_screenshot` only).
**App audited:** `acafe_resturant_kiosk_app/` (the customer/kiosk Flutter app).

---

## 0. Headline findings

1. **There are no orientation locks to remove.** No `SystemChrome.setPreferredOrientations` anywhere in
   `lib/`; `AndroidManifest.xml` has **no** `android:screenOrientation` (only `configChanges` that *handles*
   rotation without restart); iOS `Info.plist` already allows portrait **and** landscape on iPhone and iPad;
   the primary target is **web**, which simply follows the browser window. The app is already free to render
   landscape — it just renders the *wrong thing* there today (see #2).

2. **The responsive layer is already orientation-aware, but Option B is a different *composition*, not a
   different scale.** `KioskMetrics.resolve()` ([kiosk_responsive.dart:186](../../lib/common/responsive/kiosk_responsive.dart#L186))
   computes `orientation` from `window.width >= window.height` and the existing screens *do* branch on
   `isLandscape`. In landscape today, the **portrait** composition reflows: product grid + a **bottom cart
   bar** ([kiosk_menu_screen.dart:1041](../../lib/features/kiosk/screens/kiosk_menu_screen.dart#L1041)).
   Option B instead wants a **persistent right-hand order panel and no cart screen at all**. So the landscape
   work is a new *layout*, assembled from the existing scaling primitives and widgets.

3. **One clean switch point already exists.** Every kiosk route is built through a single wrapper,
   `_routeHandler(...)`, in [router_helper.dart:201-221](../../lib/helper/router_helper.dart#L201). That is the
   natural single place to pick landscape-vs-portrait per route, with zero edits to portrait screen bodies.

4. **Theme reuse is near-total.** The Figma palette, radii, fonts, pills, buttons and the NAME/EMAIL/PAYMENT
   step bar all already exist as `BrandColors` + `KioskUI` tokens. Almost nothing in the design system is new;
   what's new is arrangement.

5. **Almost every B-screen already has a Flutter implementation** (customize step flow, allergen filter,
   combo sheet, upsell sheet, coupon + applied, name/email + on-screen keyboard, order note, tip sheet,
   payment, success). The order **line card** widget (image, modifiers, EDIT, qty stepper, delete) is already
   built and is exactly the Option B panel/summary row. Most B-work is *re-housing* these into landscape frames.

6. **Task premise correction — B-12e / B-13 / B-14 are present in this Figma page.** The brief said they
   refer to "option A tablet screens not in this page." They *are* drawn as frames here
   (`2305:9386` Order summary, `2305:9485` Tip, `2305:9608` Pay at terminal), and a Figma note says they
   **"match the option A tablet screens TABLET 10a, 11 and 12."** The app already has equivalents
   (`kiosk_confirm_screen`, `kiosk_tip_sheet`, `kiosk_payment_screen`). Treat them as *in scope, restyle-only*.

7. **B-30 accessibility** is explicitly out (later release) and the Figma note agrees. Excluded below.

---

## 1. Kiosk app map

### Entry & boot
- **`lib/main.dart`** — `main()` → DI (`di_container.dart`), localization preload, image-cache sizing,
  CJK font preload, then `runApp(MultiProvider(... MyApp))`.
- **`MyApp`** builds **`MaterialApp.router`** with `RouterHelper.goRoutes`, theme from `ThemeProvider`
  (light/dark), localization delegates, and **`builder: (c, child) => AppChrome(child: child)`**
  ([main.dart:297](../../lib/main.dart#L297)).

### Shell chain (the layout backbone — one fixed tree)
`MaterialApp.router` → **`AppChrome`** → **`AppFrame`** → `PosStaffGate` → route child.
- **`AppChrome`** ([app_chrome.dart](../../lib/common/responsive/app_chrome.dart)) decides POS-vs-kiosk and the
  welcome full-bleed exemption, then renders `AppFrame`.
- **`AppFrame`** ([app_frame.dart](../../lib/common/responsive/app_frame.dart)) establishes **one**
  `KioskMetrics` (via `KioskMetricsScope`) and one `PosMetricsScope`, a background color, size cap and a
  rewritten `MediaQuery.size`. **The router deliberately never moves in the tree** (a moved Router re-parses
  the URL and crashed the POS⇄Kiosk switch). Any landscape switch must respect this: **do not** branch the
  shape of this chain on orientation; branch *inside* the route child.
- **`KioskShell`** ([kiosk_shell.dart](../../lib/common/responsive/kiosk_shell.dart)) is the standalone
  equivalent used where `AppFrame` isn't the wrapper (tests/modals).

### Routing
- **`lib/helper/router_helper.dart`** — GoRouter. Kiosk route constants at
  [L45-59](../../lib/helper/router_helper.dart#L45); route table at
  [L197-227](../../lib/helper/router_helper.dart#L197). Every kiosk screen is built via
  **`_routeHandler(context, path:…, <Screen>())`** — the single wrapper. Note: `kioskSuccessScreen`
  currently **redirects to the menu** ([L212](../../lib/helper/router_helper.dart#L212)); the Thank-You
  screen exists but is bypassed.

### State management (Provider / ChangeNotifier, DI via get_it)
All registered in `main.dart` MultiProvider. Relevant to Option B, **shareable as-is**:
- `CartProvider` — the order itself (lines, qty, add/remove). The Option B panel is a *view* of this.
- `CouponProvider` — coupon code/discount (B6).
- `CategoryProvider`, `ProductProvider` — menu data + categories (B2 rail/grid).
- `OrderProvider` — order placement.
- `KioskAuthProvider`, `KioskManagerProvider`, `DeviceModeProvider`, `KioskDealProvider` — device/session,
  manager screens, POS⇄kiosk, promo banner.
- Kiosk domain helpers (`lib/features/kiosk/domain/*`) — `kiosk_cart_totals`, `kiosk_place_order`,
  `kiosk_customize_spec/sections/scroll`, `kiosk_combo_match`, `kiosk_coupon_*`, `kiosk_tip`,
  `kiosk_allergen`, `kiosk_menu_filter`, `kiosk_navigation_helper`, `kiosk_translate`. **All pure/logic —
  reusable unchanged.**

### API layer
- `lib/data/datasource/remote/dio/dio_client.dart` + feature repos (`kiosk_order_repo`, `kiosk_auth_repo`,
  `kiosk_deal_repo`, `kiosk_manager_repo`, cart/coupon/product repos). **No UI coupling — fully shared.**

### Theme & design tokens
- **`lib/theme/brand_colors.dart`** — `primary #2B2B2B`, `background #E8E6DF`, `secondary #C8A97E` (tan),
  `cardBorder #DED9C7`, dark bg `#1E1D1B`.
- **`lib/features/kiosk/widgets/kiosk_ui.dart`** — kiosk tokens: `pageBg #F7F1DE`, `card #FFFFFF`,
  `dark #1E1E1E`, `popularGreen #357937`, `radius 18`, type scale (pageTitle 32 / heading 28 / section 20 /
  body 16 / caption 14), `primaryButtonHeight 60`, `qtyButtonSize 48`, `checkoutStepCircle 48`,
  **`steps = ['NAME','EMAIL','PAYMENT']`** (the exact B-12e step bar).
- `lib/theme/text_legibility.dart` (TextTones), `custom_theme_colors.dart`, `light_theme.dart`,
  `dark_theme.dart`, `app_page_transitions.dart` (global 250 ms slide).
- Font: **Loew** (Regular/Medium/Bold/ExtraBold) is the kiosk brand face.

### Responsive helpers (already present)
`lib/common/responsive/` — `kiosk_responsive.dart` (the `KioskMetrics` + `KioskResponsive` single source of
truth: `scale(w,h)`, bands, product-grid columns, category-rail layout, reading-column insets, deal-banner
geometry), `kiosk_layout.dart` (`KioskLayout.isLandscape/scaleOf`), `kiosk_shell.dart`, `app_frame.dart`,
`app_chrome.dart`, `breakpoints.dart`, `responsive.dart`. **This is the toolkit the landscape screens build on.**

### i18n
- `lib/localization/app_localization.dart` + `language_constrants.dart`; `getTranslated(key, context)` with the
  **`kioskTranslate(context, key, fallback)`** wrapper ([kiosk_translate.dart](../../lib/features/kiosk/domain/kiosk_translate.dart))
  that actually falls back instead of echoing the raw key. 6 languages incl. CJK (preloaded in `main`).
  **Landscape reuses the same keys**; Figma copy is English, translations follow the existing language list.

### Assets
- Product/add-on images via CDN (`CustomImageWidget` shimmer contract, base_urls); fonts + brand art in
  `assets/`. Nothing orientation-specific.

---

## 2. Portrait assumptions & where landscape would differ

| Area | Current portrait assumption | Landscape implication |
|---|---|---|
| **Orientation locks** | None (no SystemChrome; no manifest lock; iOS allows both; web follows window). | ✅ Nothing to remove. The switch is purely a layout decision. |
| **Menu composition** | Grid + **fixed bottom cart bar** (`_CartBar`, `kiosk_menu_screen.dart:1041`); in landscape today it keeps this bottom bar. | Replace with **persistent right order panel**; no bottom bar, no cart screen. |
| **Cart screen** | `kiosk_cart_screen.dart` / route `/cart-kiosk` is a full screen reached from the bar. | **Not used** in Option B (panel replaces it). Route stays for portrait; landscape never navigates to it. |
| **Scaling model** | One 2572-px-wide artboard scaled by width (`scale = width/2572`, height also bounds landscape). | Option B is authored at **1366×1024**. Landscape screens should scale against *their own* base and **fit by `min(w/1366, h/1024)`**, responsive across tablet sizes — not the 2572 portrait artboard. |
| **PDP** | Customize step flow already full-screen & `isLandscape`-aware. | Option B PDP = photo/desc/choices **left**, step bar + options + CANCEL/NEXT **right** (`2305:4605`). A layout re-house of the same step flow. |
| **Checkout** | Name/email full-screen; confirm/tip/payment are stacked single-column (reading-column centered in landscape). | Name/email stay full-screen (keyboard room). **Order summary (B-12e)** becomes items-left + Summary-card-right; the panel returns here. |
| **Success route** | `kioskSuccessScreen` redirects to menu; Thank-You bypassed. | B-15 Thank-You (name + receipt QR + PLACE NEW ORDER 45 s countdown) must be wired for the landscape flow (decision needed: enable for portrait too or landscape-only). |

**No portrait regression risk from the switch itself**, because the gate is `isLandscape` — the portrait
(`width < height`) code path is never entered by the new layout.

---

## 3. Proposed architecture

**Principle:** portrait code is frozen. Landscape is a parallel, additive layer selected by one switch,
sharing all logic/state/services and most widgets.

### 3.1 The single switch point
Add one resolver used by `_routeHandler` (or a thin wrapper it calls). Pseudocode:

```
Widget kioskScreenFor(BuildContext c, String path, Widget portrait) {
  final landscape = KioskMetrics.of(c).isLandscape;      // width >= height, already resolved
  if (!landscape) return portrait;                        // UNCHANGED portrait path
  final builder = _landscapeRoutes[path];                 // null = no landscape variant yet
  return builder?.call(c) ?? portrait;                    // graceful fallback to portrait
}
```

- **Exactly one decision site.** `_landscapeRoutes` is a lookup keyed by the existing route constants.
- **No config flag** — driven only by `isLandscape` (available width vs height), per the brief.
- **Graceful**: any route without a landscape variant falls back to portrait, so the layer can land screen by
  screen without half-built states.
- Lives at the router wrapper so the **shell/Router tree never changes shape** (respects the AppFrame rule
  that broke POS⇄Kiosk before).
- `fullBleed` welcome stays as-is (B-00 is full-bleed in both orientations).

> Alternative considered: branch inside each screen's `build`. Rejected — it's N switch points scattered
> across frozen portrait files, i.e. edits to portrait code and more regression surface. The router resolver
> keeps portrait files untouched.

### 3.2 Folder layout (new, isolated)
```
lib/features/kiosk/landscape/
  landscape_routes.dart            # the _landscapeRoutes map (the only wiring into router_helper)
  landscape_metrics.dart           # 1366×1024 base + fit = min(w/1366, h/1024), tablet-responsive
  screens/
    landscape_menu_screen.dart     # B-01..B-04 (menu + persistent order panel)
    landscape_pdp_screen.dart      # B-17..B-23 (re-house of step flow)
    landscape_summary_screen.dart  # B-12e (items + Summary card)
    landscape_thank_you_screen.dart# B-15
    ...
  widgets/
    landscape_order_panel.dart     # right-hand panel (wraps existing order line cards)
    landscape_scaffold.dart        # shared 1366×1024 frame + header
```
Only **one** existing file is edited: `router_helper.dart`, to call `kioskScreenFor(...)` inside the already-
existing `_routeHandler`. Everything else is new files.

### 3.3 Shared without change
- **Logic/models/services:** all `lib/features/kiosk/domain/*`, all providers, all repos, `kiosk_responsive`
  primitives, `kiosk_translate`, totals/coupon/combo/allergen/tip helpers.
- **Widgets (reused as-is or lightly parameterized):** `kiosk_order_line_card` (panel + summary rows),
  `kiosk_keyboard`, `kiosk_product_card`, `kiosk_combo_sheet`, `kiosk_upsell_sheet`, `kiosk_tip_sheet`,
  `kiosk_coupon_*`, `kiosk_order_note_sheet`, `kiosk_allergen_filter_row/notice`, `KioskUI` controls.
- **Dialogs/pop-ups** (combo, upsell, coupon-applied, cancel-order, inactivity) are centered overlays that
  already work in any orientation.

### 3.4 Built new (landscape-only)
- The **order panel** container (persistent right column, empty/filled states, MAKE IT A COMBO card, coupon
  link/line, CHECK OUT with total) — composed from existing line cards + buttons.
- The **menu landscape scaffold**: header (logo left, search/filter/flag right), vertical **photo** category
  rail (Figma uses image tiles), 3-col grid, inline promo banner, right panel.
- **PDP landscape frame** (left info / right options split).
- **Order summary split** (items list + Summary card).
- **Thank-You (B-15)** with QR + countdown ring (countdown ring component is shared with coupon-applied/inactivity).

---

## 4. Figma vs current theme

| Token | Figma (Option B) | App today | New for landscape? |
|---|---|---|---|
| Page background | warm beige | `kiosk_ui.pageBg #F7F1DE` / `BrandColors.background #E8E6DF` | No |
| Primary text / near-black | near-black | `#2B2B2B` / `dark #1E1E1E` | No |
| Buttons & selected pills | solid black, white label | `KioskUI.dark`, pill chips exist | No |
| "POPULAR" badge | green | `popularGreen #357937` | No |
| "OUT OF STOCK" badge | grey overlay | product card has sold-out state | No |
| Tan accent | warm tan | `BrandColors.secondary #C8A97E` | No |
| Card radius / border | rounded, soft border | `radius 18` (+12 small), `cardBorder #DED9C7` | No |
| Font | geometric sans | **Loew** family | No |
| Step bar NAME/EMAIL/PAYMENT | checked circles + connectors | `KioskUI.steps` + step-circle 48 | No (restyle only) |
| Qty stepper (− n +) | black squares | `_QtyStepper`/`_StepBox` in line card | No |
| Countdown ring | ring + seconds (B-11, B-15, B-24) | present in coupon-applied/success idle logic | Minor — unify into one widget |

**Genuinely new visual pieces:** persistent **order panel** chrome, the **photo category rail** (tiles with
product images + label, vs portrait's text rail), the **Summary card** on B-12e, and the **B-15** QR+countdown
composition. All use existing tokens — no new colors/fonts/radii are required.

---

## 5. Reuse table per Figma section

Legend: **Reuse** = existing widget/screen usable largely as-is · **Re-house** = existing logic/widget placed in a
new landscape frame · **New** = net-new landscape UI (logic still shared).

| Section | Figma frames | Existing app asset | Verdict |
|---|---|---|---|
| **B1 Start & language** | B-00 `2305:3370`, B-00a `2305:3423` | `kiosk_welcome_screen` (full-bleed), `kiosk_language_sheet`/`kiosk_language_screen` | **Reuse** — already full-bleed + 6 langs; confirm landscape chip row. |
| **B2 Menu & order panel** | B-01..B-04 `2305:3677 / 3881 / 4117 / 4356` | `kiosk_menu_screen` (grid, rail, filter pills, deal banner), `kiosk_order_line_card`, `CartProvider`, `kiosk_combo_sheet` | **New layout, reused parts** — build `landscape_menu_screen` + `landscape_order_panel`; drop bottom cart bar & cart screen; cancel-order pop-up reuse. Photo rail = new. |
| **B3 Product detail (PDP)** | B-17..B-23 `2305:4605…5571`, choices pop-up B-20 `2305:5105` | `kiosk_product_customize_step_flow` / `_sheet` (already full-screen, step bar, "Your choices", +N overflow) | **Re-house** into left-info/right-options split; logic unchanged. |
| **B4 Allergens & ingredients** | B-26..B-28 `2305:5679 / 5979 / 6291` | `kiosk_allergen_filter_screen`, `kiosk_allergen_filter_row`, `kiosk_allergen_notice`, `kiosk_allergen` domain | **Reuse / re-house** — allergens already update with choices on PDP. |
| **B5 Upsell** | B-05 combo `2305:6584`, B-06 `2305:6843`, B-07 "You may also like" `2305:7097` | `kiosk_combo_sheet`, `kiosk_upsell_sheet`, `kiosk_combo_match` | **Reuse** — centered overlays; enforce "one upsell at a time" (already the rule). |
| **B6 Coupon** | B-08..B-11c `2305:7366…9129` | `kiosk_coupon_screen`, `kiosk_coupon_applied_screen` (3 s auto-close + ring), `CouponProvider`, on-screen keyboard | **Reuse** — panel "Enter code" opens existing pop-up; applied → panel coupon line (new panel chrome). |
| **B7 Checkout** | B-12a/b name, B-12c/d email, B-12e summary, B-12f/g note | `kiosk_checkout_name_screen`, `kiosk_checkout_email_screen`, `kiosk_keyboard`, `kiosk_confirm_screen`, `kiosk_order_note_sheet` | **Reuse name/email**; **Re-house B-12e** into items + Summary card (panel returns here). Note pop-up reuse. |
| **B-12e / B-13 / B-14** | `2305:9386 / 9485 / 9608` | `kiosk_confirm_screen` (summary), `kiosk_tip_sheet` (tip), `kiosk_payment_screen` (pay-at-terminal) | **In scope, restyle-only.** Figma says these match option-A TABLET 10a/11/12; equivalents exist. |
| **B8 System states** | B-29 sold-out `2305:10413`, B-24 inactivity `2305:10658`, B-25 out-of-service `2305:11178` | product card OUT-OF-STOCK state; idle timers in welcome/customize/success; `maintenance_screen` (B-25) | **Reuse + 1 New** — B-29/B-25 covered; **B-24 "Still there?"** dialog (10 s ring) to build on existing idle machinery. |
| **B-15 Thank you** | `2305:10220` | `kiosk_order_success_screen` (exists but route **redirects to menu**) | **New wiring** — name + receipt QR + PLACE NEW ORDER 45 s. Decide portrait impact (recommend landscape-only route, leave portrait redirect untouched). |
| **B-30 Accessibility** | `2305:10905` | — | **Out of scope** (later release; Figma agrees). |

---

## 6. Risks

1. **Shared widgets drifting portrait.** Reusing `kiosk_order_line_card` etc. means a landscape tweak could
   change portrait. **Mitigation:** parameterize via new optional args defaulting to current behavior; never
   change a default; cover with portrait goldens (see §8).
2. **Scaling base confusion.** Portrait = 2572 artboard; Option B = 1366×1024. Mixing them inflates/clips.
   **Mitigation:** a separate `landscape_metrics` with its own base and `min(w/1366, h/1024)` fit; landscape
   screens never read the 2572 constants.
3. **Router tree shape.** Branching the shell on orientation re-parses the URL (the POS⇄Kiosk crash class).
   **Mitigation:** switch **inside** the route child via the resolver; shell chain stays fixed.
4. **Orientation flips at runtime** (tablet rotated / browser resized). `KioskMetrics` recomputes, so the UI
   would swap compositions mid-order. **Decision needed:** for a fixed-mount tablet this is fine; if flips are
   possible, consider latching the mode per session. Cart state is provider-held, so the *order survives* a
   flip regardless.
5. **Success route currently bypassed.** Enabling B-15 could change portrait behavior if done globally.
   **Mitigation:** wire Thank-You only on the landscape path first.
6. **`clamp` footguns.** The codebase documents `clamp(min,max)` throwing when `min>max` on odd sizes (hence
   `kioskBounded`). New landscape math must use the same guarded helpers.
7. **Fonts/goldens environment.** Golden diffs are sensitive to font/Flutter version (documented in the
   existing golden tests). Baseline must be captured on the same toolchain before/after.

---

## 7. Phased build order

Foundation first, then by section, each phase shippable (portrait untouched throughout):

- **Phase 0 — Foundation & safety net.** Capture portrait goldens baseline (§8). Add
  `lib/features/kiosk/landscape/` skeleton: `landscape_metrics`, `landscape_scaffold`, and the
  `kioskScreenFor` resolver + empty `_landscapeRoutes`, wired into `_routeHandler`. With an empty map, behavior
  is **identical** — prove portrait + landscape both still render the existing screens. No visual change yet.
- **Phase 1 — B2 Menu & order panel.** `landscape_menu_screen` + `landscape_order_panel` (empty/filled,
  combo card, coupon link, CHECK OUT), photo category rail, filter pills, deal banner, item-added toast +
  green-border, cancel-order pop-up. This unlocks the core flow.
- **Phase 2 — B3 PDP + B4 Allergens.** Re-house customize step flow into the split frame; "Your choices" +
  +N pop-up; allergen filter (B-26..28) and live allergen chips.
- **Phase 3 — B5 Upsell + B6 Coupon.** Combo (B-05/06), "You may also like" (B-07), coupon enter/typed/
  invalid/applied + panel coupon line. Enforce "one upsell in a row."
- **Phase 4 — B7 Checkout + B8 System states.** Name/email (reuse), **B-12e** summary split + Summary card,
  tip (B-13), pay-at-terminal (B-14), **B-15** Thank-You (QR + countdown), B-24 inactivity, B-29 sold-out,
  B-25 out-of-service.
- **Phase 5 — Responsive hardening.** Verify across tablet sizes/aspect ratios (not just 1366×1024):
  10" 4:3, 11" iPad, 12.9", 16:10 Android, short 1366×768 laptop. Confirm no portrait golden moved.

---

## 8. Regression-protection plan for portrait

**Goal:** prove the portrait kiosk is byte-for-byte unchanged after every phase.

**Before any change (Phase 0):**
1. **Golden baseline.** The repo already has a golden harness
   ([test/features/kiosk/customize_golden_test.dart](../../test/features/kiosk/customize_golden_test.dart),
   `coupon_applied_golden_test.dart`, `test/features/kiosk/goldens/`, `test/common/responsive/`). Extend it to
   render **each portrait route** at the production portrait sizes (1080×1920 primary, plus 2–3 portrait tablet
   sizes) and commit the PNGs as the baseline. Capture on a pinned Flutter/font toolchain and record the
   version in the test (goldens are font-sensitive).
2. **Responsive unit tests.** Add/confirm tests on `KioskMetrics.resolve` and the geometry helpers asserting
   that **portrait inputs (`width < height`) return identical values** to today (scale, bands, columns, rail,
   reading insets). These are fast and catch logic drift without rendering.
3. **Switch-invariance test.** With `_landscapeRoutes` empty, assert `kioskScreenFor` returns the *same* widget
   type as the current `_routeHandler` for every route in both orientations.

**After each phase:**
4. Run the full portrait golden suite — **no portrait image may change.** Any diff is a regression to fix
   before merge (use `flutter test` without `--update-goldens`; only update deliberately with sign-off).
5. Re-run responsive unit tests (portrait values frozen).
6. Diff shared widgets: if a reused widget (`kiosk_order_line_card`, keyboard, sheets) was touched, its
   portrait golden must be unchanged — confirms new params defaulted correctly.

**Proof of "portrait unchanged":** green portrait golden suite + green portrait responsive tests + the
switch-invariance test, on the same toolchain as the baseline. Landscape goldens are added **separately** and
never gate portrait.

---

## 9. Open decisions for review

1. **File location** — this report is at `acafe_resturant_kiosk_app/docs/landscape/01-audit.md` (beside the
   code). Move to monorepo-root `docs/` if you prefer the `*_PHASE1.md` convention.
2. **Runtime orientation flips** — latch mode per session, or allow live swap (§6.4)?
3. **B-15 Thank-You** — landscape-only (recommended, zero portrait risk) or enable for portrait too?
4. **Scope confirm** — B-12e/B-13/B-14 treated as in-scope restyle (per §0.6); B-30 excluded.
5. Confirm the switch signal is purely `isLandscape` (width ≥ height), with no "is-tablet" size gate.

*Stopping here for your review before writing any code, per the brief.*
