# Backend work needed for the POS payment layer

Found while finishing the POS payment flow (2026-10-18). None of this was changed in the backend: the
`acafe_resturant` checkout is on another session's branch (`feature/planday-checkin-backend`) with that
session's uncommitted `ReceiptController.php`, and every item touches money logic. File / line references are
against that checkout.

## B1 — Item-level refunds are not supported (blocks "partial refund by item")

`app/Http/Controllers/Api/V1/RefundController.php`

- `create()` validates `items_json` as an array of integers (`order_details` ids) and stores it, but the amount is
  always the **whole remaining balance** of the source (lines 124–128: *"the monetary amount is always the full
  remaining balance for now"*).
- `items_json` carries ids only — no quantity, so "refund 1 of 2" cannot be expressed.
- Nothing records which items (or quantities) were already refunded, so an item could be refunded twice.

What the app needs to send ticked items and have the refund equal them:

1. Request: `items: [{ order_detail_id: int, quantity: int }]` (keep `items_json` for old clients or replace it).
2. Amount = Σ over items of the line's charged unit price (variation + add-ons, net of the line discount and the
   order-level discount share, incl. tax as charged) × quantity, in integer cents, capped by the existing ceiling.
3. Track refunded quantity per `order_details` row (new column or a child table of `order_refunds`) and reject a
   quantity above what is still refundable (422 with a message).
4. `create` response: `amount` = the computed amount; optionally `items` echoed with per-line amounts.
5. `GET refund/list` (or `transactions/{id}`): per detail row `refundable_quantity` and `refunded_quantity`, so the
   app can grey out already-refunded items.
6. `transactions/{id}` `details[]` already come from `order_details_formatter`; the app must also be given each
   row's `id` (it is present on `items[]` today, not parsed for refunds). Once B1 lands, the app change is: parse the
   detail ids, send `items`, quote the server amount.

Until then the app quotes and refunds the full remaining balance and does **not** send `items_json`
(see `posRefundableAmount` in `lib/features/pos/domain/pos_refund_session.dart`).

## B2 — Refunds double-count the tip (money bug)

`RefundController::resolveCeiling()` (single-payment ceiling), `derivePaymentStatus()` and `listSnapshot()` use
`order_amount + tip_amount`. For POS and kiosk orders `order_amount` is already tip-inclusive: the app sends
`order_amount = payable + tip` (`pos_checkout.dart:105`, `kiosk_place_order.dart:130`) and `tip_amount` only as a
breakout (`OrderController.php:180–208`). A tipped order can therefore be refunded **its tip twice**, and
`refundable_remaining` / `grand_total` in `refund/list` are overstated by the tip.

Fix: use `order_amount` alone as the paid total (or subtract the tip if any client sends a tip-exclusive
`order_amount`), in all three places.

## B3 — Split payments carry no id, so one split cannot be refunded from the payment screen

`refund/create` targets a split by `partial_payment_id` (split by payment) or `split_group_id` (split by item), but
neither split API returns those ids:

- `SplitPaymentController::snapshot()` → `payments[]` has `seq, paid_with, paid_amount, due_amount, status,
  reference` — add `'id' => (int) $p->id`.
- `SplitByItemController::snapshot()` → `groups[]` has `seq, amount, item_ids, paid_with, status, reference` — add
  `'id' => (int) $g->id`.

The app already reads `id` when present: the per-payment **Refund** pill (frames 09–12, 16) appears only for a
payment that has an id and has not been refunded. Today it stays hidden.

## B4 — A refunded split does not reopen the balance

Both split snapshots compute `paid` from the split rows only; a succeeded refund against a split does not reduce it.
After refunding "Payment 1" mid-sale the screen would still show that money as paid, and the order could be closed
short. Needed: subtract succeeded refunds (by `partial_payment_id` / `split_group_id`) when computing `paid` /
`remaining` / `fully_paid`, and mark the payment row `status: refunded` in `payments[]` / `groups[]`.

## B5 — Refund options the frames show but no data exists for

- **Store credit** (frame 26): `RefundController::METHODS = ['card', 'cash']` and there is no customer-balance credit
  path for POS guest orders. Needs a `store_credit` method, a customer to credit (guest orders have none), and a
  wallet/loyalty write. The app shows the option only when the receipt reports `store_credit_available: true`.
- **Card last four** (frames 26: "Card •••• 4242"): no card data is stored anywhere (`order_partial_payments`,
  `orders`). Needs the terminal's masked PAN / last four persisted with the payment and returned on
  `transactions/{id}` (e.g. `card_last4`). The app shows "Card •••• nnnn" only when that field is present.
