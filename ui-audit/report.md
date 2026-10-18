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
- **D5 — Amount header is 12px shorter on Cash than on Card** (47 vs 58 line box). Implemented per frame,
  so switching Card ↔ Cash moves "Amount due" by 11px. Say if one of the two should win.
