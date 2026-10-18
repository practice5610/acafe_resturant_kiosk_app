# POS payment layer — pixel audit report

Figma: `egyp8Y2o5BtoJLo8SrcWrX` node **1915:9314** ("POS payment", 32 frames, all 1366×1024).
Method: Figma `get_design_context` + `get_metadata` (exact node geometry) per frame, compared against
the code numerically. Verification renders the real widgets at 1366×1024 under the production `light`
theme with the frame's own sample data (`test/features/pos/pos_payment_audit_golden_test.dart`) and
measures text/box rects against Figma frame coordinates.

Severity: **High** = wrong structure / visibly wrong at a glance · **Med** = off by several px, wrong size
or colour · **Low** = ≤2px or sub-pixel.

---

## Layer-wide (shared) findings

These were root causes behind many per-screen deltas, so they were fixed once at the source.

| # | Element | Figma value | Code value | File:line | Sev | Status |
|---|---|---|---|---|---|---|
| G1 | Top nav bar | Not drawn on any of the 32 frames — every in-flow frame opens on `back-btn-row` (h67) | `PosTopNavBar` mounted above the back row (+77px), pushing every pane down and squeezing the cash pane into its compressed mode | `screens/pos_payment_selection_screen.dart` (build, both Scaffold branches) | High | Fixed — removed; tests updated (`pos_payment_screen_test`, `pos_navigation_test`). **See Decisions D1.** |
| G2 | Line height of every un-styled `Text` | `leading-normal` — Loew 14→17, 12→14, 48→58 | Inherited M3 theme height (`bodyMedium` 1.43, `bodyLarge` 1.5): 14→20, 12→17, 18→26. Re-applied by every `Material`/`InkWell` inside the panes | theme (`lib/theme/light_theme.dart`) via `Material` | High | Fixed — new `PosPayTextScope` (`widgets/pos_pay_shell.dart`) strips `height` from the theme text styles for the layer; Loew's own metrics equal Figma's at every size (probed 10–48px) |
| G3 | Swiss 721 Light line boxes | 12→14, 13→16, 10→12, 11→13 | Font metrics give 12→16, 13→18 (+2px per line) | all Swiss captions in the layer | Med | Fixed per widget with `PosPaymentSpec.figmaLeading(size)` = round(1.2·size)/size |
| G4 | Stroke alignment | Figma strokes are **inside** (box heights include the border; content not inset) | `Container` borders inset content (+1/1.5px) and grow padding-sized boxes by 2×border (OTHER rows 66 vs 64 → 17px drift by the 4th row) | `PosPayCard`, `PosPaymentMethodCard`, `_OtherMethodRow` | Med | Fixed — borders painted as `foregroundDecoration` |
| G5 | Pane height / gap to CTA bar | Panes 834 tall (y67→901), bar at y920 → 19px | bottom padding 20 → panes 833 | `domain/pos_payment_spec.dart` `v2ContentPaddingBottom` | Low | Fixed (19) |

---

## 01 Payment – Card (1915:9346)

| # | Element | Figma value | Code value | File:line | Sev | Status |
|---|---|---|---|---|---|---|
| 1 | Receipt rows — thumbnail | No product image in the row | 52×62 thumbnail slot (blank while loading) indents every row by 64px | `widgets/pos_receipt_line.dart` (`PosReceiptLine.build`) | High | Fixed — `PosReceiptOrderList(inset: true)` drops it on this layer only |
| 2 | Receipt rows — inset & hairlines | `order-items` px-24; row hairline 392 wide, inset 24 each side | Rows full-bleed (px-16 inside a 0-inset list), hairline edge-to-edge | `pos_receipt_line.dart` | High | Fixed (`inset`) |
| 3 | Qty cluster width | Hug: trash 26 · 8 · digit · 8 · plus 31 | Fixed slots: 31 · 8 · 22 · 8 · 31 → trash ~14px further left | `pos_receipt_line.dart` `_QtyControls` | Med | Fixed for inset rows (`hug`); counter screen unchanged |
| 4 | Customer-info top padding | `py-16` (block 89 tall) | 0 top (73) — label sat on the header hairline | `widgets/pos_receipt_panel.dart` `PosReceiptCustomerInfo` | Med | Fixed (`paddingTop: 16`) |
| 5 | Customer-name text x | 14 from field edge (inside stroke) | 15.5 (1.5px border insets text) | `pos_receipt_panel.dart` `_NameTrigger` | Low | Skipped — shared with Home and the Receipts detail panel (the latter has uncommitted work from another session); 1.5px |
| 6 | Summary header — gap before amount | `gap-10` (header 151) | 20 | `widgets/pos_pay_summary_panel.dart` `PosPaySummaryHeader` | Med | Fixed |
| 7 | Quick-amount chips | Custom · **19.00** · 20.00 / 25.00 · 30.00 · 50.00 | Custom · 19.00 · 20.00 / 50.00 · 55.00 · 60.00 | `pos_pay_summary_panel.dart` `_QuickAmountGrid._presets` | Med | Fixed — next €5, +€5, next €10, next €50 (inert chips; display only) |
| 8 | Quick-amount row gap | 10 (`ontvangen-section` gap-10) | 8 | same | Low | Fixed (`v2ReceivedGap`) |
| 9 | "Amount received" icon | `bi:cash` filled glyph, 16×10 | lucide banknote, stroked, 14×14 | `pos_pay_summary_panel.dart` | Med | Fixed — Figma vector inlined |
| 10 | Tip row — "Add tip" | Loew Bold **12** | 14 | `PosPayTipRow` | Med | Fixed |
| 11 | Tip row — subtitle | Swiss 10 | 12 | `PosPayTipRow` | Med | Fixed |
| 12 | Tip row — "0.00" | Loew Bold **14**, `#1A1A2E` (→ ink) | 17, ink @0.4 when no tip | `PosPayTipRow` | Med | Fixed |
| 13 | Tip row — plus-circle | 12×12 Figma glyph | 14×14 lucide | `PosPaySectionIcon` | Low | Fixed (`glyphWidth/Height`) |
| 14 | Tip row — chevron | Figma glyph, `#8A94A6` | lucide, ink | `pos_pay_summary_panel.dart` | Low | Fixed — glyph inlined, ink @0.4 per sign-off (see D3) |
| 15 | OTHER-row icons | `banknote` (both split rows), `file-text`, `smartphone` — 13px vectors, 2px stroke | lucide grid / split / file / phone in a 24 viewBox (≈1.1px stroke at 13px) | `widgets/pos_payment_method_selector.dart` | Med | Fixed — Figma vectors inlined (see D4) |
| 16 | OTHER-row radio | 18 slot drawing a 24px ring (`inset -16.67%`) | 18px ring | `_OtherMethodRow` | Low | Fixed (`OverflowBox`, `v2OtherRadioDrawn`) |
| 17 | Card tile top row | 46 on the Card tile, 40 on Cash (both frames) → "Card" label 6px lower | 40 on both | `widgets/pos_payment_method_card.dart` | Low | Fixed (`methodTopRowHeightCard`); tile fixed 95 |
| 18 | All pane content offsets | content at border-box edge | +1 / +1.5px | `PosPayCard` | Low | Fixed (G4) |

Verified: every text anchor measured on the render (summary, method column, OTHER rows at a 72px pitch, receipt
rows, CTA, back-row caption) lands on the Figma frame coordinate (±0), except #5.

## 02 Payment – Cash (1915:10105)

| # | Element | Figma value | Code value | File:line | Sev | Status |
|---|---|---|---|---|---|---|
| 1 | Pane mode | Natural stack (771px in an 829–834 pane) | "fill" mode shrank the amount to **32px** and squeezed the field (needed only because of G1) | `widgets/pos_pay_cash_panel.dart` | High | Fixed — natural layout; a short pane scrolls instead of shrinking |
| 2 | Header amount line | 48px text in a **47px** box (header 139) | 58 (header 151, as on Card) | `PosPaySummaryHeader` | Med | Fixed (`amountLineHeight: 47`, pb 11). See D5 |
| 3 | Rule under header | Two stacked 1px rules (10242 + 10243) | One | `pos_pay_cash_panel.dart` | Low | Fixed |
| 4 | Tender section padding | px-16 py-8, gap-12 | px-20 py-6, gap-10 | same | Med | Fixed (`v2CashTender*`) — split panes keep px-20 |
| 5 | Label → field gap | 8 | 4 | `_TenderedField` | Low | Fixed |
| 6 | Amount field | 58 tall, p-16, 2px ink, r12 | squeezed into a fixed 62 *including* label (box ≈42) | `_TenderedField` | High | Fixed (`v2CashFieldHeight`) |
| 7 | Change-due padding | p-16 | px-12 | `_ChangeDueBanner` | Low | Fixed |
| 8 | Keypad digit line box | 29 (`leading-normal` 24px) | 24 (`height: 1.0`) → digits ~2.5px high | `widgets/pos_keypad.dart` `posPaymentKeypadStyle` | Low | Fixed |
| 9 | Content width | 420 (field / denoms; denom 77.6 wide) | 412 / 76 | — | Low | Fixed; `pos_payment_layout_test` updated to the Figma numbers |

Verified on render: Amount due 179, Amount Tendered 216, field text 256, Change Due 319.5, denoms 371, key
"1" 436.5, Add tip 785 — all equal to the Figma frame coordinates.

---

## Decisions for you

- **D1 — Nav bar on the payment screen.** The old frames (1641:*) drew it; the new layer draws it on none
  of 32 frames, so it is removed (Figma is the source of truth). If you want it back for navigation reasons,
  it is a one-line revert in `pos_payment_selection_screen.dart` — but the cash pane then no longer fits
  at 1024 tall.
- **D2 — Method-card borders disagree between frames.** Frame 01: idle `#F0EBD8` 1px, selected black 1px.
  Frame 02: idle `#E8E3D5` 1px, selected `#241F20` 1.5px. Code keeps frame 01's values for both; tell me
  which one is canonical.
- **D3 — Off-palette slates.** The file uses `#1A1A2E`, `#8A94A6` (and `#5A6A8A` on the tip plus-circle).
  The earlier sign-off maps `#1A1A2E` → ink and `#8A94A6` → ink @0.4; I kept that, and mapped `#5A6A8A`
  → ink by the same rule. Say if you now want the literal hexes.
- **D4 — Same banknote icon on "Split by item" and "Split by payment".** That is what Figma draws, so the
  code now matches; it looks like a placeholder — confirm or send distinct icons.
- **D5 — Amount header is 12px shorter on Cash than on Card** (47 vs 58 line box). Implemented per frame,
  so switching Card ↔ Cash moves "Amount due" by 11px. Say if one of the two should win.
