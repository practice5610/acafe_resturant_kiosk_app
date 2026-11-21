# Landscape Tablet Kiosk (Option B) — Status (after Phase 4)

**Scope so far:** B-01 (menu, empty order), B-02 (menu with items), B-03 (item just
added). File key `egyp8Y2o5BtoJLo8SrcWrX`, nodes `2305:3677` / `2305:3881` /
`2305:4117`. Portrait is untouched throughout — every change lives in
`lib/features/kiosk/landscape/**` and `test/features/kiosk/landscape/**`, plus
the one additive hook in `lib/helper/router_helper.dart` and the 8
`assets/language/*.json` files.

## Done

- **Menu screen** (`screens/landscape_menu_screen.dart`): header (logo, search/
  filter/language — same SVG assets as portrait), category rail, filter pills,
  3-column product grid (pinned, not the shared dynamic column algorithm),
  promo banner, bottom fade, product cards (badges, allergen row, out-of-stock
  dimming).
- **Order panel** (`widgets/landscape_order_panel.dart` +
  `widgets/landscape_order_line_card.dart`): title/count, Cancel order,
  Figma-exact cart line cards (own image crop/radius, EDIT row, trash-at-qty-1
  stepper — deliberately a new widget, not a mode of the shared
  `KioskOrderLineCard`, since that widget is also rendered by POS and
  portrait's customize sheet), scroll-to-newest, CHECK OUT.
- **Toast + highlight (B-03):** single 3 s timer drives both together (an
  earlier version had two different durations, now fixed), toast centered on
  the grid's own content region (not the whole screen), `{product}`
  placeholder localization.
- **Coupon ("Enter code"):** wired to the existing portrait coupon flow
  (`openKioskCouponScreen` from `kiosk_coupon_helper.dart` — guest ensure +
  `RouterHelper.getKioskCouponRoute`). Same validation/discount/total logic
  portrait already has; no new logic written.
- **Resize:** landscape/portrait is a live, per-build decision
  (`classifyKioskLayout`) — not the earlier per-order lock, which used to get
  stuck showing the wrong layout after a resize. The one-time crash (a
  `clamp(220, maxWidth*0.4)` that threw below a 550px window) is fixed.
- **Dividers:** header (y115) and order-panel (y118) now land within 1px of
  Figma, measured against the rendered tree rather than estimated.
- **Translations:** every `landscape_*` key used in this feature now has real
  translations in all 8 language files. A new permanent test
  (`landscape_translation_keys_test.dart`) scans the feature folder and fails
  if a future key is ever added without translations — the existing
  `kiosk_languages_test.dart` scanner cannot catch this on its own, because it
  only tracks a key if it is *already* in `en.json`.

## Not done, and why

- **Combo "+"** (`onCombo` in `landscape_menu_screen.dart`) — **stopped for
  sign-off.** Portrait's only combo logic (`findKioskComboUpgrade` /
  `CartProvider.applyComboUpgrade` / `openKioskComboSheet`) is an *upgrade*: it
  only fires when the cart already contains every product a deal bundles, and
  it swaps those lines for the deal line. It does not support "add this
  specific bundle outright," which is what the Figma card (always shows the
  first available bundle, tap "+" to add it) implies. Building that would mean
  writing new cart-mutation logic with no portrait equivalent to call —
  exactly the condition this phase was told to stop on rather than invent.
- **"- removed ingredient" modifier line** — confirmed not buildable:
  `AddOns.isDefault`'s own doc comment says a default "comes with the
  product... the customer cannot turn it off." There is no cart state meaning
  "a default was removed."
- **Checkout, product customize, payment, name/email, search, coupon,
  cart** screens — all still the portrait designs, shown inside whatever
  window size the kiosk has. No landscape Figma exists for these; this phase
  did not redesign them (out of scope, explicitly).
- **Photo "feather" mask** on product cards — checked against the live Figma
  node: there is no separate feather/mask layer in this design, so none was
  added.

## Tests / baseline

- `flutter analyze` — clean on `lib/features/kiosk/landscape/**` +
  `test/features/kiosk/landscape/**`; 34 pre-existing issues elsewhere,
  unchanged by this work.
- Landscape suite: **60/60 pass.**
- Full repo suite: **81 failures / 2724 run, 0 in `test/features/kiosk/landscape/`**
  — same failure count as the pre-existing baseline (golden/font/env + a
  handful of already-broken test files unrelated to this feature); confirmed
  via `git stash` that these fail identically with or without this work.

## The portrait/landscape switch rule (exact)

`classifyKioskLayout(window)` in `kiosk_orientation.dart`:

> **Landscape when `window.width >= window.height`. A square window counts as
> landscape. There is no minimum width floor on the decision itself** — a
> 300×200 window is still classified landscape; it just renders small
> (`LandscapeMetrics.scaleFor` has its own floor, `minScale = 0.1`, for the
> render *scale*, not for which layout is chosen).

Evaluated fresh on every build via `KioskLandscapeSwitch.resolve` (no lock,
no memory across calls — see "Done" above). Everything that is `width <
height` renders the untouched portrait screen.

## Combo "+" — pending decision

`kLandscapeComboEnabled` (`landscape_order_panel.dart`) gates the whole
"MAKE IT A COMBO" block — `true` by default so it still matches Figma during
development; set to `false` before shipping unless one of the designs below
is built and reviewed. "+" is not wired to anything either way.

**What supplies the data today:** `KioskDealProvider.deals` (fetched/cached
per branch+device by the backend already, no new fetch needed) — each
`KioskDeal` carries `title`/`bundlePrice`/`originalPrice`/`image`/`available`
and its `items` (the bundle's products). The card currently shows the first
`available && dealType == typeProductBundle` deal — same simple pick as
before; "best match for the current cart" would need new ranking logic with
no portrait precedent to copy.

**How a deal line is priced/sent (read only, unchanged):** `CartModel.deal(
dealId, title, image, bundlePrice, originalPrice, components)` builds the
cart line; `components` are per-product sub-lines. The *only* place that
builds one today (`kiosk_combo_match.dart`) populates `components` by
**copying configuration off cart lines that already exist** (it slices
existing lines down to qty-1 copies) — it has never had to decide a bundled
product's variation/add-on choices from scratch, because the upgrade path
only ever fires when the customer already configured and added those
products themselves.

**Proposal 1 — instant add (closest to what Figma's "+" implies):**
tapping "+" builds a fresh `CartModel.deal(...)` directly from `deal.items`
(no existing cart lines involved) and calls `cart.addToCart(dealLine, null)`
— the same method a normal product add already uses, so toast/highlight/
count/total all update for free via the existing cart-change listener.
*Risk:* building `components` from scratch means deciding each bundled
product's variation/add-on configuration with no customer input and no
portrait precedent for that decision — a product with a required paid
variation could price the bundle wrong. *Files:* `landscape_order_panel.dart`
only.

**Proposal 2 — confirm-then-add:** same construction as Proposal 1, but
"+" opens a confirmation step first (visually modeled on portrait's existing
`_KioskComboSheet` chrome) showing the bundle before adding it. *Risk:* same
component-construction risk as Proposal 1, plus reusing or forking
`kiosk_combo_sheet.dart`'s private sheet widget means either editing a
shared file (stop condition) or duplicating its chrome into a new landscape
file. *Files:* `landscape_order_panel.dart` + a new
`landscape_combo_confirm_sheet.dart` (if not editing the shared one).

Both proposals reuse `cart.addToCart` and existing pricing helpers only —
neither touches order-writing, payment, the API or any model. Whichever is
chosen (or neither, if `false` ships), the component-construction risk above
needs an explicit answer first.

## Known limitations

- Local widget state (selected filter pills, grid scroll position) is not
  preserved across a landscape↔portrait resize — portrait and landscape are
  different `StatefulWidget` trees, so this is inherent, not a bug. Cart,
  category selection and deals (all Provider-held) *are* preserved.
- Coupon navigation (`openKioskCouponScreen`) is wired but not covered by an
  automated test — it depends on `AuthProvider.addGuest()` (a real network
  call) and GoRouter's static route table, both awkward to stub cleanly in a
  widget test. Covered by the manual Chrome checklist instead.
