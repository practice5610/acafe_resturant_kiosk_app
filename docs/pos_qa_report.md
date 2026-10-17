# POS Payment Flow — Design-QA & Flow-Bug Report

**Figma file:** `egyp8Y2o5BtoJLo8SrcWrX` (POS) · **Canvas:** 1366×1024 · **Date:** 2026-10-17

This report is **honest about verification scope.** A screen is only marked "Matches
Figma" where it was compared against the actual node via `get_design_context`. Items
not yet pixel-compared are listed as **Pending audit**, not claimed as matching.

---

## 1. Preflight (verified)

| Item | Result |
|---|---|
| Figma MCP connectivity | ✅ Connected — 8 nodes fetched this pass |
| Keypad source of truth | `1915:10266` fetched via `get_design_context` (full fills/type/border) |
| Refund frame IDs | `1915:11344` fetched = **"25 Refund – Select items and reason"** ✅ |
| Note A (`1915:9346`) | "01 Payment – Card", single frame, **no keyboard** (resolved earlier) |
| `1915:10494` | `back-btn-row` **component**, not a screen (resolved earlier) |

### Refund frame mapping
Code header (`pos_refund_screen.dart`) documents: `11344`=25, `11448`=26, `11777`=27,
`11551`=28, `12443`=29, `12462`=30. **Spot-verified `11344` = "25 Refund – Select items
and reason"**, which matches the documented Screen 25 — corroborating the mapping. The
other five are documented-but-not-individually-fetched this pass (flagged for honesty).

---

## 2. KEYPAD — VERIFIED, matches Figma exactly (no change)

Source of truth **`1915:10266`** compared field-by-field against `posCashKeypadStyleV2`
(`pos_keypad.dart` + `pos_payment_spec.dart`):

| Property | Figma `1915:10266` | Code `posCashKeypadStyleV2` | Match |
|---|---|---|---|
| Key fill | `#ffffff` (white) | `tileBg = Colors.white` | ✅ |
| Key border | `#d8d1be`, 1.5px | `#D8D1BE`, 1.5px | ✅ |
| Key height | 78 | `v2KeypadKeyHeight = 78` | ✅ |
| Corner radius | 12 | `v2KeypadKeyRadius = 12` | ✅ |
| Column / row gap | 12 / 12 | `v2KeypadGap = 12` | ✅ |
| Label font | Loew **Bold** | `loewBold` | ✅ |
| Label size / color | 24 / `#241f20` | 24 / `ink = #241F20` | ✅ |
| Backspace key fill | `#f0ebd8` | `v2KeypadBackspaceFill = #F0EBD8` | ✅ |
| Delete icon | 23×23 | `v2KeypadBackspaceIconSize = 23` | ✅ |
| Decimal key | `,` (comma), bottom-left | `digitRows(decimal: ',')` in cash | ✅ |

**Conclusion:** the V2 keypad is already pixel-accurate. **No rebuild performed** — a
rebuild would be pure churn and would risk the 4 other `PosKeypad` consumers
(cash entry, split, close-day, PIN lock). The earlier "keyboard looks wrong" impression
is most likely the **fill-mode proportional down-scale**: inside `PosPayCashSummaryPanel`
/ `PosSplitSummaryPanel`, the keypad sits in an `Expanded` + `LayoutBuilder` that scales
it by `availableHeight / 348` when the pane is vertically tight, so keys render shorter
than 78 px on short viewports. That is correct responsive behaviour (no overflow), not a
spec defect. **Open question for you:** do you want the keypad pinned at natural 78 px
height (and the pane to scroll if short), or kept proportionally scaled? Figma shows the
natural size only; it doesn't specify the short-viewport behaviour.

**Note on press state:** keys use an `AnimatedScale` 0.94 press feedback. Figma's static
export can't show a pressed state, so this is a pre-existing, standard touch affordance —
left as-is (not "invented decoration").

---

## 3. FLOW-BUG REVIEW — payment flow traced in code

Scenarios from the brief (a–j). **Verdict: the primary payment flow is well-guarded; no
duplicate-charge or hung-spinner defect found.** Evidence per scenario:

| # | Scenario | Finding | Status |
|---|---|---|---|
| a | Card → waiting → success | `_confirm` → `posConfirmPayment(onPhase:…)` → success card; `mounted` checked after await | ✅ OK |
| b | Declined → retry | `_declined` state → `_tryAgain` → same `_confirm`, **stable `_idempotencyKey`** across retries → no double-auth (real-PSP caveat documented in code) | ✅ OK |
| c | Cash + change due | `_cashCovers(total)` gates confirm; change derived from tender vs total | ✅ OK |
| d | Split P1→P4 | **Remaining balance comes from the backend response** (`PosSplitState.fromJson`), not client math → no rounding drift; cents-based; fresh idempotency key per split; `_splittingPayment` guards re-entry | ✅ OK |
| e | Invoice / Standalone | `_startInvoice` / `_startStandalone` guarded by `if (_xActive \|\| _confirming) return;` | ✅ OK |
| f | Refund | Double-header + hang fixed earlier (`context.go`, `resetFlow`); 5 regression tests green | ✅ Fixed |
| g | Back button | Withheld while waiting/declined: `onBack: _isWaitingForTerminal \|\| _declined ? null : _back` | ✅ OK |
| h | Double-tap / tap-while-loading | Every confirm/record/start handler opens with a busy-flag guard (`_confirming`, `_splittingPayment`, `_cancelling`, `_xActive`) and re-checks `mounted` after each await | ✅ OK |
| i | Keypad edge cases | Tokens routed through `PosCashEntry` (cents model); backspace routed to `onBackspace`, spacer inert. Deep edge-case unit tests (leading zeros, max length, delete-on-empty) **not yet added** | ⚠️ Pending tests |
| j | Root-cause patterns | `initState`-reset bug (refund) fixed; async handlers surface errors via snackbar (not swallowed); loading flags always reset in `finally`/post-await; `push`→`go` fixed for refund & receipt→payment | ✅ OK |

### Minor (non-blocking) findings
- **M1** `_showSplitDeclineCard` (line ~592) and one other `showGeneralDialog` callsite
  (~1454) don't wrap content in `Material(type: MaterialType.transparency)` like the
  other 5 callsites do. **Not a crash** — `PosPaymentCardButton` self-provides a
  `Material`, and the card is `Container`→`Column`→`Text`. Consistency nit only.

---

## 4. VISUAL AUDIT — defect found + pending list

### Critical / Major
- **V1 (Major) — Refund layout diverges from Figma.** Figma `25–30 Refund …` use the
  **3-pane payment layout** (purchase-receipt sidebar · reason card · summary pane) with
  a top `back-btn-row` ("Refund / Order #27362") and a sticky "Continue to refund method"
  bar. The current implementation uses a **centered single-column card**
  (`_RefundStepShell`). The centered version fixed an earlier "huge empty space" problem
  but is **not** the Figma design. **Recommended fix:** rebuild refund steps on the shared
  `PosPayThreePane` so they match `25–30`. This is a sizeable rework (own commit).

### Pending audit (NOT compared to Figma yet — not claimed as matching)
These payment states were **not** pixel-compared this pass. Each needs its own
`get_design_context` + diff before any "matches Figma" claim:

| Screen | Node | File |
|---|---|---|
| 01 Payment – Card | `1915:9346` | `pos_pay_summary_panel.dart` |
| Invoice panel | `1915:10311` | `pos_invoice_panel.dart` |
| Standalone panel | `1915:9519` | `pos_standalone_panel.dart` |
| 05 enter amount (split) | `1915:9902` | `pos_split_summary_panel.dart` |
| 06 Waiting for card | `1915:9328` | `pos_waiting_card.dart` |
| 07 Card declined | `1915:10475` | `pos_declined_card.dart` |
| 08 Payment 1 paid (success) | `1915:9315` | `pos_payment_success_card.dart` |
| 09 / 10 / 12 split states | `11566 / 9677 / 10714` | split + cash panels |
| back-btn-row | `1915:10494` | top bar of `pos_payment_selection_screen.dart` |

**Sibling frames not in the brief** (flow states between the listed ones, e.g. "02–04",
"11") were not enumerated this pass — a full sibling sweep is part of completing the
pixel audit.

---

## 5. Changes made this pass
- `test/features/pos/pos_refund_regression_test.dart` — **new**, 5 tests (single header,
  order survives `initState`, flow renders). All green.
- `pos_refund_screen.dart` — removed 3 dead methods (`_navTitle`/`_canGoBack`/
  `_handleBack`, never wired) to clear `unused_element` warnings; `const` hygiene.
- `docs/pos_qa_report.md` — this report.

(The refund functional fixes themselves — `context.go`, `resetFlow` — and the
split/cash panel compaction landed in earlier passes and are already in the tree.)

---

## 6. Test & analyze results
- `flutter test test/features/pos/pos_refund_regression_test.dart` → **5/5 pass**
- `flutter test test/features/pos/pos_payment_screen_test.dart` → **55/55 pass**
- `dart analyze` on refund files → **No issues found**
- Golden tests per screen at 1366×1024 / 1024×768 — **not produced this pass** (depends
  on completing the pixel audit first).

---

## 7. Honest status summary

| Area | Status |
|---|---|
| Keypad vs Figma | ✅ **Matches** (verified field-by-field) |
| Payment flow robustness (a–h, j) | ✅ **Verified in code** — no duplicate-charge/hang defects |
| Refund functional bugs | ✅ **Fixed + regression-tested** |
| Refund visual layout | ⚠️ **Major defect** — centered, Figma is 3-pane (rework pending) |
| 13-screen pixel audit | ⏳ **Pending** — only keypad fully compared; others listed above |
| Golden / responsive / flow-integration tests | ⏳ **Pending** |

**Bottom line:** the keypad is correct, the payment flow is safe to demo on the
golden path, and the Refund functional bugs are gone. The remaining work is the
per-screen **visual** pixel audit (incl. the Refund 3-pane rebuild) plus golden tests —
not yet done, and not claimed as done.

---

## 8. Manual check list (before showing the client)
1. Add 3 items, open Payment. Confirm total matches the cart.
2. Card → confirm → "Waiting for payment" → success card → receipt prints (if auto-print on).
3. Force a decline → "Payment Declined" → **Try Again** re-attempts, **Cancel** returns to selector.
4. Cash → tender below total (confirm disabled) → tender exact/over → **Change Due** correct.
5. Split by payment: pay P1, P2, P3, P4 → "Remaining" decrements correctly each step; final completes once.
6. Split by item: select items → correct selected total + "remaining after this payment".
7. Invoice → fill form → submit → success. Standalone → approval code → success.
8. Refund from a receipt: **one header**, pick a reason, Continue → method → confirm → complete; Back never hangs.
9. Rapid double-tap "Confirm Payment" → only one charge/order.
10. Tap "Confirm" then immediately Back → no stuck spinner, no orphan charge.
11. Keypad: leading zeros, a decimal, delete on empty, amount over remaining — behaves sanely.
12. Resize window to 1280×800 and 1024×768 → 3-pane stays intact, no overflow stripes.
13. **Hardware:** real card-terminal round-trip (approve + decline), real receipt print.
14. **Hardware:** keypad feel on the actual touch screen (tap targets, press feedback).
15. Visual spot-check each payment state on a real POS screen against Figma side-by-side.
