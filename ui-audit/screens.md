# POS payment layer — screen inventory

Figma file `egyp8Y2o5BtoJLo8SrcWrX` ("POS"), layer **1915:9314 "POS payment"**.
All frames are **1366 × 1024**. Paths are relative to `acafe_resturant_kiosk_app/`.

Shared chrome on every in-flow frame: `back-btn-row` (h67) · `content-area`
(3 panes 440 / 370 / flex, gap 20, px 32, panes h834) · `sticky-bottom-bar`
(h104, pill h64). **No frame in the layer draws the top nav bar.**

| # | Frame | Node | Implemented by | Status |
|---|---|---|---|---|
| 01 | Payment – Card | 1915:9346 | `screens/pos_payment_selection_screen.dart` (`_BackRow`, `_Content`) · `widgets/pos_pay_shell.dart` · `widgets/pos_payment_method_selector.dart` · `widgets/pos_payment_method_card.dart` · `widgets/pos_pay_summary_panel.dart` · `widgets/pos_receipt_panel.dart` + `widgets/pos_receipt_line.dart` (receipt sidebar) | Implemented |
| 02 | Payment – Cash | 1915:10105 | same + `widgets/pos_pay_cash_panel.dart` · `widgets/pos_keypad.dart` | Implemented |
| 03 | Payment – Invoice | 1915:10311 | `widgets/pos_invoice_panel.dart` | Implemented |
| 04 | Payment – Stand-alone terminal | 1915:9519 | `widgets/pos_standalone_panel.dart` | Implemented |
| 05 | Split by payment – Enter amount | 1915:9902 | `widgets/pos_split_summary_panel.dart` | Implemented |
| 06 | Split by payment – Waiting for card | 1915:9328 | `widgets/pos_waiting_card.dart` (`PosWaitingCard`) | Implemented |
| 07 | Split by payment – Card declined | 1915:10475 | `widgets/pos_declined_card.dart` | Implemented |
| 08 | Split by payment – Payment 1 paid, continue | 1915:9315 | `widgets/pos_payment_success_card.dart` via `_showSplitSuccessCard` | Implemented |
| 09 | Split by payment – Payment 1 paid, enter Payment 2 | 1915:11566 | `pos_split_summary_panel.dart` | Implemented |
| 10 | Split by payment – Payment 2 cash, change due | 1915:9677 | `pos_split_summary_panel.dart` (+ `PosPayChangeDueBanner` / `PosPayDenominationRow`) | Implemented (change due + denominations added) |
| 11 | Split by payment – Payment 3 card | 1915:10493 | `pos_split_summary_panel.dart` | Implemented |
| 12 | Split by payment – Payment 4 card (final) | 1915:10714 | `pos_split_summary_panel.dart` | Implemented |
| 13 | Split by item – Choose how to split | 1915:10945 | `widgets/pos_split_summary_panel.dart` (`PosSplitChooserPanel`) | Implemented (round 2) |
| 14 | Split by item – Select items | 1915:11101 | `widgets/pos_split_by_item_panel.dart` | Implemented |
| 15 | Split by item – Payment 1 cash entry | 1915:11795 | `pos_split_summary_panel.dart` (data-driven `PosSplitSummaryPanel`) | Implemented (round 2) |
| 16 | Split by item – Payment 1 paid, Payment 2 card | 1915:12010 | `pos_split_by_item_panel.dart` | Implemented |
| 17 | Split by item – Payment 2 waiting for card | 1915:12207 | `PosWaitingCard` | Implemented |
| 18 | Split by item – Order paid | 1915:12225 | `pos_payment_success_card.dart` via `_showSplitByItemSuccessCard` / `_showSinglePaymentSuccessCard` | Implemented |
| 18a | Order paid, Receipt options (Email) | 1915:13024 | `widgets/pos_receipt_dialog.dart` | Implemented |
| 18b | Order paid, Receipt options (Print) | 1915:13077 | `widgets/pos_receipt_dialog.dart` | Implemented |
| 19 | Split by item – Custom amount | 1915:12240 | `pos_split_summary_panel.dart` (`.forPayments(customAmount: true)`) | Implemented (round 2) |
| 20 | Split by item – 6 items (scrolling list) | 1915:12475 | `pos_split_by_item_panel.dart` | Implemented |
| 21 | Split by item – 10 items with variants | 1915:12705 | `pos_split_by_item_panel.dart` | Implemented |
| 22 | Error – Card terminal offline | 1915:11287 | `widgets/pos_payment_error_card.dart` | Render-only (not wired) |
| 23 | Error – Payment timed out | 1915:11306 | `widgets/pos_payment_error_card.dart` | Render-only (not wired) |
| 24 | Error – Cash amount too low | 1915:11325 | `widgets/pos_payment_error_card.dart` | Render-only (not wired) |
| 25 | Refund – Select items and reason | 1915:11344 | `screens/pos_refund_screen.dart` (`_SelectionFrame`, `_ReasonPane`, `_RefundSummaryPane`) | Implemented |
| 26 | Refund – Choose refund method | 1915:11448 | `screens/pos_refund_screen.dart` | Implemented |
| 27 | Refund – Waiting for card on terminal | 1915:11777 | `screens/pos_refund_screen.dart` (`_WaitingStep` → `PosPaymentStatusCard`) | Implemented (keeps approval code, D13) |
| 28 | Refund – Complete | 1915:11551 | `screens/pos_refund_screen.dart` (`_CompleteStep` → `PosPaymentSuccessCard`) | Implemented (no Receipt button, D13) |
| 29 | Refund – Confirm refund of split payment 1 | 1915:12443 | `screens/pos_refund_screen.dart` | Implemented |
| 30 | Refund – Split payment 1 refunded | 1915:12462 | `screens/pos_refund_screen.dart` | Implemented |

Figma reference renders: `ui-audit/figma/<nn>_*.png` (+ exported vectors in `ui-audit/figma/assets/`). Code
renders: golden test `test/features/pos/pos_payment_audit_golden_test.dart` →
`test/features/pos/goldens/payment_audit/*.png`; size sweep in `pos_payment_audit_responsive_test.dart`.
