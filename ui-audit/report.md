# POS payment layer — pixel audit report

Figma: `egyp8Y2o5BtoJLo8SrcWrX` node **1915:9314** ("POS payment", 32 frames, all 1366×1024).
Method: Figma `get_design_context` + `get_metadata` (exact node geometry) per frame, compared against
the code numerically. Verification renders the real widgets at 1366×1024 under the production `light`
theme with the frame's own sample data (`test/features/pos/pos_payment_audit_golden_test.dart`) and
measures text/box rects against Figma frame coordinates.

Severity: **High** = wrong structure / visibly wrong at a glance · **Med** = off by several px, wrong size
or colour · **Low** = ≤2px or sub-pixel.

---

## Summary

| | Count |
|---|---|
| Frames audited | 32 / 32 |
| Differences found | **122** (27 High · 51 Med · 40 Low · 4 info) |
| Fixed | **114** |
| Not fixed — need logic / a feature (see D7, D9, D12, render-only errors) | 6 |
| Skipped (reason given) | 1 — customer-name text 1.5px inset; shared with the Receipts panel that has another session's uncommitted edits |
| Already matching | 1 |

**Verification.** `test/features/pos/pos_payment_audit_golden_test.dart` renders 27 frames under the production theme
with each frame's sample data (goldens in `test/features/pos/goldens/payment_audit/`), and every text anchor was measured
against the Figma frame coordinates — they match to the pixel except where a Figma inconsistency is noted.
`pos_payment_audit_responsive_test.dart` runs all of them at 1366×1024, 1024×768, 1280×800, 1920×1080, 768×1024
(portrait) and 900×600, plus stress states (14 long lines, a five-figure total, a 55-character customer name, empty cart):
**165 / 165 pass, no overflow or exception.** Full suite: 114 failures vs 115 on the clean pre-audit tree, all pre-existing
(goldens / environment baseline); no new failures. Analyzer: no new issues.

**Extra bugs found beyond Figma** (all fixed unless marked):
1. Split-by-item: an item already paid in an earlier group could be ticked again and charged twice → now an inert "Paid" row.
2. Refund: the ticked items are never sent to the backend (`items_json`) — **not fixed, money path, D11**.
3. Split-payment decline dialog had no `Material` ancestor → debug-underlined text.
4. Zero-padded amounts ("€ 09.50") on the stand-alone pane, its step text, and the receipt dialog subtitle.
5. Refund amounts formatted "€6.00" by hand, ignoring the currency config.
6. Quick-amount chips formatted inconsistently ("17,283.84" vs "17285.00").
7. The whole layer inherited Material 3 line heights (1.43–1.5×), inflating every untyped label by 3–6px.

**Files changed** (lib): `domain/pos_payment_spec.dart`, `screens/pos_payment_selection_screen.dart`,
`screens/pos_refund_screen.dart`, and in `widgets/`: `pos_pay_shell.dart`, `pos_pay_summary_panel.dart`,
`pos_pay_cash_panel.dart`, `pos_payment_method_selector.dart`, `pos_payment_method_card.dart`,
`pos_split_summary_panel.dart`, `pos_split_by_item_panel.dart`, `pos_invoice_panel.dart`, `pos_standalone_panel.dart`,
`pos_waiting_card.dart`, `pos_declined_card.dart`, `pos_payment_error_card.dart`, `pos_payment_success_card.dart`,
`pos_receipt_dialog.dart`, `pos_receipt_line.dart`, `pos_receipt_panel.dart`, `pos_keypad.dart`.
Tests: `pos_payment_screen_test.dart`, `pos_payment_layout_test.dart`, `pos_navigation_test.dart`,
`pos_refund_regression_test.dart` (assertions moved to the Figma values); new `pos_payment_audit_golden_test.dart`,
`pos_payment_audit_responsive_test.dart`.

**Shared-component safety.** Changes to widgets used outside this layer are opt-in parameters with unchanged defaults:
`PosReceiptLine.inset/trailing/background`, `PosReceiptCustomerInfo.paddingTop`, `PosPaymentCardButton.insideStroke`
(the order-complete dialog keeps its original button). The Receipts change-method dialog shares the method selector
and picks up the Figma radios / icons; its tests pass.

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
| 8b | Quick-amount figures (extra bug, found in the stress pass) | one format for all chips | selected chip grouped ("17,283.84"), presets not ("17285.00") | same | Low | Fixed — all chips use the app formatter |
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

## 03 Payment – Invoice (1915:10311)

| # | Element | Figma value | Code value | File:line | Sev | Status |
|---|---|---|---|---|---|---|
| 1 | Confirm action | Sticky-bar pill **"Confirm Payment"** (node 1915:10473) | Bar hidden; in-pane 56px "Create Invoice" button | `screens/pos_payment_selection_screen.dart` (bar builder) · `widgets/pos_invoice_panel.dart` | High | Fixed — bar shown in invoice mode, wired to the existing `_submitInvoice` with the same `isValid && !loading` rule; in-pane button removed |
| 2 | Field labels | Label **above** each input (Loew Regular 12, ink @0.53, gap 4) | Hint text inside the field (Swiss 14 @0.35), no labels | `pos_invoice_panel.dart` `_InvoiceTextField` | High | Fixed |
| 3 | Input text | Loew **Medium** 14 | Loew Bold 14 | same | Med | Fixed |
| 4 | Input height | 37 (px-14 py-10, 1.5px inside stroke) | ~48 (non-dense M3 decorator) | same | Med | Fixed (dense, 37) |
| 5 | Input text x | 14 from the field edge | 18 (outline `gapPadding` 4) | same | Low | Fixed (`gapPadding: 0`) |
| 6 | Toggle | 36×20 r10 ink track, white r8 thumb | Material `Switch` (52×32) | same | Med | Fixed — `PosPayToggle`; "off" not drawn in Figma → POS inactive fill (see D6) |
| 7 | Toggle subtitle copy | "Send automatically after completing" | "Send a copy to the company email" | same | Med | Fixed |
| 8 | "SEND BY EMAIL" tracking | 0.5 | 0 | same | Low | Fixed |
| 9 | Extra divider | Only one divider (under the amount) | Second divider + 12px above the toggle | same | Med | Fixed (removed) |
| 10 | Pane padding / rhythm | p-24, gap-16; header gap 4 + pb 12; total pb 12; form py-12 gap-10 | px/py 20; ad-hoc 2 / 12 / 16 / 10 gaps | same | Med | Fixed |
| 11 | Amount line box | 58 (`leading-normal`) | 48 (`height: 1.0`) | same | Med | Fixed |
| 12 | Swiss captions | 14 / 16 line boxes | 16 / 18 | same | Low | Fixed (`figmaLeading`) |
| 13 | Pane border | `#F0EBD8` 1.5px (this frame) | `#E8E0CC` 1px (summary style) | screen `_summaryPane` | Low | Fixed |
| 14 | Selected OTHER row | `#241F20` **1.5px** border; 24px filled radio flush right | black 1px; radio centred on the 18 slot (3px overhang) | `widgets/pos_payment_method_selector.dart` | Low | Fixed |

Verified on render: every text anchor in the pane (INVOICE 91, amount 154, labels 311/376/441, inputs 339/404/469 at
x 920, toggle row 524/540) equals the Figma coordinate.

## 04 Payment – Stand-alone terminal (1915:9519)

| # | Element | Figma value | Code value | File:line | Sev | Status |
|---|---|---|---|---|---|---|
| 1 | Confirm action | Sticky-bar pill "Confirm Payment" (node 1915:9675) | Bar hidden; in-pane 56px button | `screens/pos_payment_selection_screen.dart` · `widgets/pos_standalone_panel.dart` | High | Fixed — bar wired to the existing `_submitStandalone` / `_standaloneLoading`; in-pane button removed |
| 2 | Pane padding | p-24 | px-24 py-20 | `pos_standalone_panel.dart` | Low | Fixed |
| 3 | Header → subtitle gap | 4 | 2 | same | Low | Fixed |
| 4 | Amount line box | 58 | 48 (`height: 1.0`) | same | Med | Fixed |
| 5 | Section rhythm | gap-16 between header / total / divider / steps; steps & approval py-12 gap-10 | 12 / 16 / 16 / 10 / **16** / 6 | same | Med | Fixed |
| 6 | Approval label → input | 4 | 6 | same | Low | Fixed |
| 7 | Approval input | 37 tall, Loew **Medium** 14, text at x+14 | ~48 tall, Loew Bold 14, x+18 | `_ApprovalCodeField` | Med | Fixed (dense, `gapPadding: 0`) |
| 8 | Swiss captions | 14 / 16 line boxes | 16 / 18 | same | Low | Fixed |
| 9 | Pane border | `#F0EBD8` 1.5px | `#E8E0CC` 1px | screen `_summaryPane` | Low | Fixed |
| 10 | Amount formatting (extra bug) | "€ 19.00" | `formatPrice` with zero-padding → €9.50 would read "€ 09.50" (also step 1 text) | same | Med | Fixed (`padZero: false`, as every other payment pane) |

Steps keep their bordered `Container`: this frame *includes* the stroke in layout (badge at x13 / y11, rows 44 tall),
unlike the OTHER rows — verified on render (step texts at 324.5 / 378.5 / 432.5, x 953; approval 473 / 501).

## 05 / 09 / 10 / 11 / 12 Split by payment – entry pane (1915:9902 · 11566 · 9677 · 10493 · 10714)

One pane (`Column/Right`, node 1915:10034) drawn in five states, so it is audited once.

| # | Element | Figma value | Code value | File:line | Sev | Status |
|---|---|---|---|---|---|---|
| 1 | Confirm action | Sticky-bar pill "Start Payment N" | Pill drawn *inside* the pane (with its own bar chrome) between keypad and tip row; screen bar hidden | `widgets/pos_split_summary_panel.dart` · screen bar builder | High | Fixed — screen bar, same `_recordSplit` / `_splittingPayment` |
| 2 | Pane stroke & padding | `#E8E3D5` 1.5px; pt-24 px-20 pb-14, gap-8 | `#E8E0CC` 1px; ad-hoc 12/8/6/4 gaps, sections individually padded | same · `PosPayCard` | Med | Fixed (`PosPayCard.borderColor/Width`) |
| 3 | Subtitle copy | "One amount at a time, the remainder follows automatically" | "Overview for split payment" | `_Header` | Med | Fixed |
| 4 | Total | ExtraBold **36**, `leading-none`, gap-1 to "Total to pay" | 30, natural line, gap 2 | `v2SplitTotalSize` | Med | Fixed |
| 5 | Divider under header | none | 1px summary rule | same | Low | Fixed (removed) |
| 6 | Remaining bar padding | px-10 py-6 | px-14 py-8 | `_RemainingBar` | Low | Fixed |
| 7 | Paid payments | 48px rows: dial-pad well, "Payment N" Bold 12 / "Card payment successful" Swiss 10, amount Bold 14 | 10px Swiss one-liners "Payment N  (Card)" + Bold 11 amount | `_PastPaymentsList` → `PosSplitPaidRow` | High | Fixed |
| 8 | Paid row "Refund" pill | Black 85×24 pill per paid payment | Not present | — | — | **Not fixed — needs logic** (refunding one split mid-sale is a money path, not UI). See D7 |
| 9 | Entry card | 62 tall, p-12, `PAYMENT N` over the raw typed amount `€  20` (caret `€  \|` when empty), segmented control right, vertically centred | min 54, p 14/10, formatted `€ 20.00` / grey `0.00`, a ✕ clear icon | `_EntryCard` | Med | Fixed — ✕ removed (backspace on the keypad clears) |
| 10 | Card / Cash control | 12px icons + Bold **10** labels; idle `#A7A19A`, idle cash glyph @45%; active white, no shadow | text-only, 12px labels, idle ink @0.5, drop shadow | `PosSplitMethodToggle` | Med | Fixed (Figma vectors inlined) |
| 11 | Cash split | Change Due banner + €5…Exact row under the entry card (frame 10) | Missing | pane + screen | High | Fixed — reuses the cash pane's banner/denominations; Exact = remaining; new `_onSplitDenomination` only sets the keyed amount (same as typing it) |
| 12 | Keypad decimal key | "," | "." | pane | Low | Fixed (`PosCashEntry` accepts both) |
| 13 | Tip row | 61 / py-16 with no payments (05); 48 / py-8 once rows are listed (09–12); 20px inset inside the pane | always 61 full-bleed | `PosPayTipRow(height:)` | Low | Fixed |
| 14 | Swiss captions | 12 line box at 10px | 14 | pane | Low | Fixed |

Verified on frame 10's render: SPLIT PAYMENT 91, total 128, Remaining 192, paid row text 229.5 (x 956), PAYMENT 2 288,
amount 302, Change Due 355.5, denoms 403, key "1" 464.5, Add tip 805.5 — equal to Figma. The segmented control lands
between frame 05's and frame 10's positions (they differ by 3px).

Figma inconsistencies noted (not "fixed"): frame 12 compresses the paid rows to 44px with 4px gaps (09–11 use 48 / 8 and
the pane fits either way) → code follows 09–11. Paid amounts are written "€9.00" (no space) while every other amount
in the layer is "€ 9.00" → code keeps the app-wide format.

## 06 / 17 Waiting for card · 07 Card declined (1915:9328 · 12207 · 10475)

| # | Element | Figma value | Code value | File:line | Sev | Status |
|---|---|---|---|---|---|---|
| 1 | Placement | Card alone, centred on the full page — no back row | Back row kept on screen (dimmed, inert) above the card | `screens/pos_payment_selection_screen.dart` | High | Fixed — back row hidden while waiting / declined |
| 2 | Split-flow decline | Same full-screen card (frame 07 is the *split* decline) | `showGeneralDialog` over the screen with a black 54% scrim | `_showSplitDeclineCard`, `_showSplitByItemDeclineCard` | High | Fixed — barrier = page background |
| 3 | Split decline text (extra bug) | — | Dialog had no `Material` ancestor → Text drawn with debug yellow underlines | `_showSplitDeclineCard` | High | Fixed (`Material` + `PosPayTextScope`) |
| 4 | Card / amount box / button strokes | Inside (card 430 / 500.84 tall, box 103, button 51) | Outside (+3 / +2 / +3px each) | `widgets/pos_waiting_card.dart` | Med | Fixed (`foregroundDecoration`; `PosPaymentCardButton.insideStroke` opt-in so the order-complete dialog outside this layer is unchanged) |
| 5 | Divider | `Line` is 0 tall, 1px stroke drawn just above it | 1px box (+1px) | same | Low | Fixed |
| 6 | Error mark | 83.84 vector overhanging its 80.84 slot (`inset -1.86%`) | Vector scaled down into the slot (thinner stroke) | `PosPaymentErrorMark` | Low | Fixed |

Verified: 06 heading 391 / box 481 / amount 501 / button 652; 07 heading 426.4 — equal to Figma once the card is
centred on 1024 (Figma's 06 sits 9px higher only because of a stray 18px `calendar` node under the content area).

## 08 Split payment success · 18 Order paid (1915:9315 · 12225)

| # | Element | Figma value | Code value | File:line | Sev | Status |
|---|---|---|---|---|---|---|
| 1 | Component | Shared `success-card` (640, p-32, r20) | Five hand-built inline cards in the screen (PNG check, `PosPayPillBar` with its bar border + shadow as the button) | screen `_show*SuccessCard` | High | Fixed — all five use `PosPaymentSuccessCard` via one `_showSuccessCard` helper; callbacks unchanged |
| 2 | Backdrop | Card on the plain page background | Black 54% scrim over the payment screen | same | High | Fixed (barrier = `#F7F1DE`) |
| 3 | 08 copy | "Split Payment 1 Successful" · AMOUNT PAID € 9.00 · "Start next payment" | "Payment 1 received" · Remaining box · "Next payment" | `_showSplitSuccessCard` | High | Fixed |
| 4 | 18 button order | **Receipt** (outline) above **Next order** (filled), gap-16 | Next order above Receipt, gap 24 / 10 | `_showSinglePaymentSuccessCard` etc. | Med | Fixed (`secondaryLabel`; gap 16 with two buttons) |
| 5 | Check icon | `mingcute:check-fill` (filled vector) | lucide check (stroked) / `check_circle.png` | `pos_payment_success_card.dart` | Med | Fixed — Figma vector inlined |
| 6 | Strokes | Inside (card, amount box 95, pills 47) | Outside | same | Low | Fixed |

Verified: 08 heading 433 / AMOUNT PAID 502 / pill 619; 18 heading 409.5 / TOTAL PAID 470.5 / Receipt 579.5 / Next
order 642.5 — equal to Figma. Invoice / Stand-alone / split-by-item intermediate outcomes have no frame; they now use
the same card (noted, D8).

## 22 / 23 / 24 Errors – Terminal offline · Timed out · Cash too low (1915:11287 · 11306 · 11325)

| # | Element | Figma value | Code value | File:line | Sev | Status |
|---|---|---|---|---|---|---|
| 1 | Subtitle line box | Swiss 13 → 16 | 18 | `widgets/pos_waiting_card.dart` (`PosPaymentStatusCard.subheading`) | Low | Fixed |
| 2 | Strokes / divider / mark | as 07 | as 07 | shared card | Med | Fixed with 07 |
| 3 | Copy | "Terminal Offline / Check the terminal connection and try again / Retry connection"; "Payment Timed Out / No card was presented within 60 seconds"; "Amount Too Low / Received € 5.70 of € 9.00 / STILL DUE € 3.30 / Back / Add cash" | identical | `widgets/pos_payment_error_card.dart` | — | Matches |
| 4 | Wiring | — | Render-only: no offline / timeout / short-cash path exists to show them | — | — | Not changed (logic, out of scope) |

Verified on render: heading 415.4, subtitle 455.4, amount box text 527.4, buttons 698.4 — equal to Figma (card 522.84
centred on 1024).

## 14 / 16 / 20 / 21 Split by item – select items (1915:11101 · 12010 · 12475 · 12705)

| # | Element | Figma value | Code value | File:line | Sev | Status |
|---|---|---|---|---|---|---|
| 1 | Confirm action | Sticky bar "Start Payment N · € X" | 52px button inside the pane | `widgets/pos_split_by_item_panel.dart` · screen bar | High | Fixed — bar listens to the selection; same `_startSplitByItemPayment`, disabled with nothing selected (as before) |
| 2 | Pane | `#E8E3D5` 1.5px; pt-24 px-20 pb-14, gap-12 | summary stroke; mixed 14/16/20 paddings, 6–10 gaps, a divider above PAY WITH | same | Med | Fixed |
| 3 | Summary | SPLIT PAYMENT Bold 13 tr 1 · "Select items for this payment" · total ExtraBold **36** (`leading-none`) | Bold 11 tr 0.8 · "Select items for payment" · 30 | `_SplitHeader` → shared `PosSplitSummaryHeader(showRemaining: false)` | Med | Fixed |
| 4 | Section labels | Loew Bold 11 `#78706E`, no tracking; "· n OF m" **only on the long list** (20 / 21) | Bold 10 tr 0.4, count always | `_SectionLabel` | Low | Fixed |
| 5 | Item rows | px-16 py-14 (py-10 in the 276px scroller), r12, gap-12; 26px checkbox; name Bold **14**, variant Swiss **11**, price ExtraBold **14** | px-14 py-10, r10; 22px checkbox with a Material check; 13 / 10 / 13 | `_ItemRow` | Med | Fixed — Figma checkbox vector inlined; strokes stay in layout (this frame includes them: rows 64 / 63) |
| 6 | Long orders | 276px scroller, gap-8, 4px `#B9B5A6` thumb in the pane padding | `Flexible` list growing to the free space, no visible thumb | same | Med | Fixed (`_ItemScroller`) |
| 7 | Paid items (frame 16) | 60% rows with a green "Paid" pill, not selectable | Shown as normal selectable rows | same | High | Fixed — paid ids derived from the state's recorded groups. **Extra bug:** an already-paid item could be ticked into a later group and charged twice |
| 8 | Payments taken (frame 16) | 48px "Payment 1 · Cash payment successful · €12.00" row | Not shown | same | Med | Fixed (shared `PosSplitPaidRow`); its Refund pill — see D7 |
| 9 | PAY WITH buttons | 48, r10, gap-8; active ink 1.5px, idle white `#E8E3D6` 1px; 18px Figma card / banknote glyphs, Bold 15 | Material `credit_card` / `account_balance_wallet` icons, idle stroke 1.5px, gap 6 | `PosPayWithRow` | Med | Fixed (repo SVGs = Figma geometry) |
| 10 | Selected total | `#F0EBD9` r8 px-12 py-8; label Bold **11**, amount ExtraBold **14** | label 13, amount 17 | `_SelectedTotal` | Med | Fixed |
| 11 | Remaining note | Swiss **11**; "Nothing remaining after this payment" at zero | Swiss 10; "€ 0.00 remaining after this payment" | same | Med | Fixed |
| 12 | Tip row | shared 61px row (px-20 py-16) | bespoke row with Material icons, 13px amount | same | Med | Fixed (`PosPayTipRow`) |

Verified on render (frames 14 & 16): labels 189 / 249, row text 229.5 / 289 / 381 / 439.5, Paid pill 299.5, PAY WITH
441 / 500, buttons 481 / 540, selected total 536 / 595, note 571 / 630, tip 612 / 671 — all equal to Figma.

## 13 Choose how to split · 15 Payment 1 cash entry · 19 Custom amount (1915:10945 · 11795 · 12240)

| # | Element | Figma value | Code value | Sev | Status |
|---|---|---|---|---|---|
| 1 | Frame 13 | After "Split by item", a chooser: **By item** / **Custom amount** | Tapping "Split by item" goes straight to item selection | High | **Not implemented — new flow, needs decision (D9)** |
| 2 | Frame 19 | "Custom amount" per guest with keypad | No such mode (closest is "Split by payment") | High | **Not implemented (D9)** |
| 3 | Frame 15 | Cash entry for a split-by-item payment (tender field, change, denominations, keypad) | Cash split-by-item records the group amount directly, no tender step | High | **Not implemented (D9)** — needs a tender step in the split-by-item money path |

## 18a / 18b Order paid – Receipt options (1915:13024 · 13077)

| # | Element | Figma value | Code value | File:line | Sev | Status |
|---|---|---|---|---|---|---|
| 1 | Scrim | `rgba(36,31,32,0.4)` | `Colors.black54` | screen `_showReceiptDialog` | Med | Fixed (`v2DialogScrim`) |
| 2 | Text metrics | `leading-normal` | Dialog sits outside the screen's text scope → M3 1.43 line heights | `widgets/pos_receipt_dialog.dart` | Med | Fixed (`PosPayTextScope`) |
| 3 | Header → tiles | gap-16, 0-tall line, gap-16 | 12 + 1px divider + 16 | same | Low | Fixed |
| 4 | Modal & tile strokes | Inside (tiles 64 tall) | Outside (67 / 66) | same | Low | Fixed |
| 5 | Radios | Figma radio: idle `#B9B5A6` 3px ring (24 drawn in an 18 slot), selected 24px filled with cream centre | Self-drawn: idle ink 2px ring at 18, selected white centre | same | Med | Fixed — shared `PosPayRadio` (also used by the OTHER rows now) |
| 6 | Tile icons | Figma 14px mail / printer vectors (1.3 stroke) | lucide icons in a 24 viewBox | same | Low | Fixed — vectors inlined. Idle icon kept ink (Figma draws it white on a 10% well → near-invisible), see D10 |
| 7 | Close icon | Figma 26px x-circle | lucide x-circle | same | Low | Fixed |
| 8 | "EMAIL ADDRESS" tracking | 0 | 0.5 | same | Low | Fixed |
| 9 | Email text position | centred in the 56px field, x+14 | 4px high, x+18 (outline notch gap) | `_EmailField` | Low | Fixed |
| 10 | Subtitle amount | "€ 19.00" | `formatPrice` zero-padded → "€ 09.00" under €10 (extra bug) | `_ModalHeader` | Med | Fixed |

Verified: 18a title 361, subtitle 389, tiles 475, EMAIL ADDRESS 515, field text 551.5 (x 437), helper 592, CTA 634;
18b title 414.5, CTA 580.5 — equal to Figma relative to the dialog (Figma's 18a dialog sits 7px above centre while
18b is centred; code centres both).

## 25–30 Refunds (1915:11344 · 11448 · 11777 · 11551 · 12443 · 12462)

The refund screen did not use the layer's chrome at all: nav bar + a single centred white card per step with
Material radios / checkboxes. It now uses the payment layer's components; `_createRefund` / `_confirmRefund` and every
session read/write are carried over byte-for-byte.

| # | Element | Figma value | Code value | File:line | Sev | Status |
|---|---|---|---|---|---|---|
| 1 | Chrome | Back row "Refund / Order #27362", no nav bar, page bg `#F7F1DE`, sticky pill | Nav bar, `panelBg`, in-card buttons | `screens/pos_refund_screen.dart` | High | Fixed (`PosPayBackRow` → Receipts, `PosPayPillBar`) |
| 2 | 25 / 26 layout | 3 panes: receipt (lines with checkboxes, picked line tinted) · REFUND REASON / REFUND METHOD options · REFUND summary | One 560px card: radio list + "Name × qty" checkbox rows | same | High | Fixed (`PosPayThreePane`, `PosPayReceiptCard`-style sidebar with `PosReceiptLine(trailing:, background:)`) |
| 3 | Option rows | px-16 py-14 r12, Bold 15 (+ Swiss 11 subtitle), 24px disc radio with `#F0EBD9` dot / `#B9B5A6` ring | Material radio icons, Loew Regular 15, `ink@6%` selected fill | same | Med | Fixed |
| 4 | Reasons | Customer changed mind · Wrong item · Quality issue · Other | Wrong item · Customer changed mind · Quality issue · **Overcharged** · Other | same | Med | Fixed to the frame (Overcharged no longer offered — D12) |
| 5 | Summary pane | REFUND / subtitle / 36px amount "Refund amount" / Order total bar / ITEMS TO REFUND rows / "Items selected n of m" or "Refund to" / note | none | same | High | Fixed (shared `PosSplitSummaryHeader` with refund labels) |
| 6 | 27 card wait | Waiting card: dots · "Waiting for card on terminal..." · REFUND AMOUNT · "Cancel Refund" | Success-card shell, "Refunding…", Material labelled TextField | same | High | Fixed to the status card; keeps the approval-code field and a Confirm button the manual terminal flow needs (not in the frame — D13) |
| 7 | 29 cash confirm | "Refund Payment 1?" · tender line · REFUND AMOUNT · Cancel / "Refund € 12.00" | "Cash Refund" card, € without space, 28px Bold amount | same | Med | Fixed (subtitle cannot list the split's items — not in the data) |
| 8 | 28 / 30 done | "Refund Successful" / "Payment 1 Refunded" · AMOUNT REFUNDED | "Refund Complete" / "Split Payment N Refunded" | same | Med | Fixed copy; 28's Receipt + Next order not built (no refund-receipt action); button keeps "Back to Receipts" / Figma 30's "Back to order" (D13) |
| 9 | Amount format (extra bug) | "€ 6.00" | `'€${v.toStringAsFixed(2)}'` → "€6.00", ignores currency config | same | Med | Fixed (`formatPrice`) |
| 10 | 26 options | Original payment (Card •••• 4242) · Cash · **Store credit** | Card / Cash | same | — | Store credit and card last-4 not available → **not built (D12)** |

Verified on render: 25 REFUND REASON 91, first option 146.5 (x 533.5), REFUND 91, amount 128, Order total 192, ITEMS
TO REFUND 224, item 264, summary row 317.5, note 352; 29 heading 357, subtitle 397 — equal to Figma.

**Extra bug (money path, not changed):** the operator ticks items to refund, but `_createRefund` never sends them —
`PosRefundRepo.create` accepts `itemsJson`, the screen passes nothing, so the backend refunds by order / split, not by
the picked lines. The new summary shows the picked lines' total exactly as Figma does, which makes the gap visible:
**this needs your decision before release (D11).**

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
- **D6 — Unspecified states.** Figma draws only the "on" toggle and only a focused (ink) company field.
  Off toggle = POS inactive fill `#DED9C8`, thumb left; unfocused fields = `#E0D9C8` (as drawn for VAT/email).
- **D7 — Per-split "Refund" pill** (frames 09–12). Not built: it needs a refund-one-split path inside the
  sale. Say if you want it wired (the refund flow for receipts already exists, frames 25–30).
- **D8 — States without a frame**: invoice created, stand-alone confirmed, and a split-by-item intermediate
  payment now use the frame 08 / 18 success card (copy: "Invoice created" · AMOUNT INVOICED, "Payment
  confirmed" · TOTAL PAID, "Split Payment N Successful"). Frames 18a / 18b list Next order *above* Receipt,
  frames 18 and 28 list Receipt above — code follows 18 / 28.
- **D9 — Split-by-item frames with no implementation**: 13 (By item / Custom amount chooser), 15 (cash tender
  step for a split-by-item payment) and 19 (custom amount per guest). Each is a new flow or a money-path
  change rather than a UI fix, so they are left for your go-ahead.
- **D10 — Idle receipt-option icon** is white on a 10% well in Figma (unreadable). Kept ink; confirm.
- **D11 — Refund items are not sent (HIGH).** `_createRefund` ignores `selectedItemIndices`; one-line fix is to pass
  them as `itemsJson`, but it changes what the backend refunds, so it is yours to approve.
- **D12 — Refund options.** "Store credit" and "Card •••• 4242" need data / a feature that does not exist;
  "Overcharged" was dropped from the reason list to match the frame.
- **D13 — Refund terminal flow.** Frame 27 assumes an integrated terminal (Cancel only); the code confirms a manual
  terminal refund with an approval code, so the card keeps those controls. Frame 28's Receipt / Next order pair is not
  built (no refund receipt action).
- **D5 — Amount header is 12px shorter on Cash than on Card** (47 vs 58 line box). Implemented per frame,
  so switching Card ↔ Cash moves "Amount due" by 11px. Say if one of the two should win.


---

# Round 2 — finishing the flow (2026-10-18)

Other sessions' uncommitted files, left untouched throughout: `lib/features/pos/screens/pos_receipts_screen.dart`,
`lib/features/pos/widgets/pos_receipt_detail_panel.dart` (app) and `app/Http/Controllers/Api/V1/ReceiptController.php`
(backend, on branch `feature/planday-checkin-backend`). Backend gaps are written up in `ui-audit/backend-needs.md`
(B1–B5); no backend file was changed.

## R1 — Refund items not sent to the backend

**Trace.** Receipt line checkboxes → `PosRefundSession.selectedItemIndices` → `_createRefund()` → `PosRefundRepo.create`.
The indices were dropped at `_createRefund` (it never passed `itemsJson`).

**Backend support: not supported** (B1). `RefundController::create` accepts `items_json` (order-detail ids, no
quantities) but always refunds the whole remaining balance of the source. Per instructions no payload was invented and
the item-level refund work stops here; `items_json` is still not sent.

**What was fixed in the app instead:**

| # | Problem | Fix | Verified |
|---|---|---|---|
| 1 | The summary quoted the ticked lines' total (round 1), but the backend refunds the whole remaining balance → UI ≠ amount refunded | The screen reads `GET refund/list` on entry and quotes exactly what `create` will refund (`posRefundableAmount`, mirrors `RefundController`: split amount − reserved refunds, or `refundable_remaining` − pending order-level refunds). "—" until loaded; never a guess | `pos_refund_amount_test.dart`: quote = bar label = `create` amount (€ 19.00 with one €6 line ticked; split € 12 − € 2 refunded = € 10.00) |
| 2 | **Bug:** any failed refund call (`withError`, null response) threw `NoSuchMethodError` in `_createRefund` / `_confirmRefund`; the button stayed busy forever, no message | Status read null-safely; the backend message is shown and the flow stays on its step | test "an API failure shows the error and changes nothing" |
| 3 | Payload | `create` sends order, reason, `partial_payment_id` for a split; `items_json` deliberately null | payload assertions in the same test |

Edge cases from the brief that depend on item-level support (block with no items, partial quantities, already-refunded
item) cannot be honoured truthfully until B1 lands: the backend would refund the full balance whatever is ticked.
Already-refunded *sources* are handled: the quote reads € 0.00 and `create` returns the backend's "already fully
refunded" message (tested).
