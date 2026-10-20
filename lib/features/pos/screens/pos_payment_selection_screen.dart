import 'dart:async';
import 'dart:ui' as ui;

import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_payment_service.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_place_order.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart' as kiosk;
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/domain/pos_checkout.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_method_change.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_change_method_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_line_copy.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_menu_actions.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_print.dart';
import 'package:acafe_customer/features/pos/domain/pos_refund_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_builder.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_invoice_model.dart';
import 'package:acafe_customer/features/pos/domain/pos_invoice_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_standalone_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_by_item_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_complete_confirmation_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_fit_column.dart';
import 'package:acafe_customer/features/pos/widgets/pos_invoice_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_success_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_standalone_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_by_item_panel.dart';
import 'package:acafe_customer/features/pos/domain/pos_cash_denomination.dart'
    show PosCashDenomination;
import 'package:acafe_customer/features/pos/widgets/pos_declined_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_cash_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_summary_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_selector.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_context_menu.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_summary_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_tip_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_waiting_card.dart';
import 'package:acafe_customer/features/pos/providers/pos_access_scope.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cash or card fork for the current sale — Figma **1641:2757** (1366x1024).
///
/// Opened by PAY on [PosHomeCartScreen] and deliberately routed outside the
/// shell, so the nav bar is mounted here rather than inherited.
///
/// Nothing on this screen holds its own copy of the sale. The lines, prices and
/// discount come from [CartProvider] / [CouponProvider] exactly as the counter
/// screen reads them, and the customer name and table come from
/// [PosSaleSession], which is why they survive the route change. The receipt
/// card is composed from the very widgets the counter receipt panel is built
/// from, so the operator sees the same ticket either side of PAY.
class PosPaymentSelectionScreen extends StatefulWidget {
  /// Test seam, mirroring [PosSettingsScreen]. Production leaves this null and
  /// resolves prefs from GetIt.
  final SharedPreferences? sharedPreferences;

  const PosPaymentSelectionScreen({super.key, this.sharedPreferences});

  @override
  State<PosPaymentSelectionScreen> createState() =>
      _PosPaymentSelectionScreenState();
}

class _PosPaymentSelectionScreenState extends State<PosPaymentSelectionScreen> {
  /// Stable for the life of this screen: a Retry after a decline is the *same*
  /// checkout attempt and must not be able to charge the card twice.
  final String _idempotencyKey = 'pos-${DateTime.now().millisecondsSinceEpoch}';

  bool _confirming = false;

  /// Non-null only while a confirm attempt is running. `awaitingTerminal` is
  /// what swaps the content area for the waiting card (Figma 1641:4203).
  PosCheckoutPhase? _phase;

  /// The operator has asked the terminal to abandon the payment, and it has not
  /// answered yet.
  bool _cancelling = false;

  bool get _isWaitingForTerminal => _phase == PosCheckoutPhase.awaitingTerminal;

  /// True once the terminal has turned a card payment down and the operator has
  /// not yet chosen Cancel or Try Again.
  ///
  /// Deliberately separate from [_phase]: a phase describes an attempt that is
  /// running, and this is the state after one has finished badly. Only
  /// `paymentFailed` sets it — `orderFailed` means the card *was* charged, so
  /// it keeps its own "do not re-charge" message rather than offering a retry.
  bool _declined = false;

  /// The amount the declined attempt was for, held so the card cannot quote a
  /// different figure than the one the customer was asked to present for.
  double _declinedAmount = 0;

  /// Cash tender, held here rather than in [PosSaleSession]: it belongs to this
  /// payment attempt, not to the ticket, and must not survive a trip back to
  /// the counter screen the way the customer name does.
  PosCashEntry _cash = const PosCashEntry();

  /// Split-by-payment mode (Family 2): non-null while the operator is taking
  /// a sale in several payments. Nothing is placed by entering it — the order
  /// is placed with the first payment (see [_ensureSplitOrder]) — so switching
  /// away before then leaves nothing behind. Held in a ValueNotifier so the
  /// split UI rebuilds surgically.
  late final PosSplitSession _split = PosSplitSession();

  /// Card or Cash for the payment being keyed in.
  PosPaymentMethod _splitMethod = PosPaymentMethod.card;

  /// Amount keyed in for the payment (on Cash: the tender).
  PosCashEntry _splitEntry = const PosCashEntry();

  /// The denomination chip behind [_splitEntry] on a cash split (frame 10);
  /// cleared by any keypad entry, like [_denomination] on a plain cash sale.
  PosCashDenomination? _splitDenomination;

  // ── Split-by-item (Family 3) ─────────────────────────────────────────────
  /// Non-null while guests are paying for their own items. As with
  /// [_split], the order is placed with the first payment.
  late final PosSplitByItemSession _splitByItem = PosSplitByItemSession();

  /// Which items are ticked for the payment being assembled.
  late final PosSplitByItemGroupsBuilder _splitByItemGroups =
      PosSplitByItemGroupsBuilder(groupSeq: 1);

  /// Card or Cash for the guest paying now.
  PosPaymentMethod _splitByItemMethod = PosPaymentMethod.card;

  /// Frame 13: "Split by item" opens a chooser — By item or Custom amount.
  /// True while it is on screen.
  bool _splitChooser = false;

  /// The chooser's pick; By item is the frame's default.
  PosSplitChoice _splitChoice = PosSplitChoice.byItem;

  /// The split-by-payment session was started from the chooser's "Custom
  /// amount" (frame 19): same saving path, guest wording, and the OTHER
  /// group shows "Split by item" as the active row.
  bool _splitCustom = false;

  /// Frame 15: the cash step of a split-by-item payment. Non-null while the
  /// operator keys the tender for the picked items; the payment itself is
  /// recorded at the guest's share.
  PosCashEntry? _sbiTender;
  PosCashDenomination? _sbiDenomination;

  // ── Shared by both split modes ───────────────────────────────────────────
  /// True while a split payment is being charged or saved.
  bool _splitBusy = false;

  /// The sale's order once a split payment, an invoice or a stand-alone
  /// payment has placed it — always at that step's confirm, never on tapping
  /// the option, so switching options leaves nothing in the kitchen. From
  /// then on the sale is committed: the method can't be switched and the
  /// ticket can't be edited until it is finished.
  int? _saleOrderId;

  /// The grand total [_saleOrderId] was placed at.
  double _saleTotal = 0;

  /// A payment whose money is in but which is not saved yet. Kept until it
  /// is, so a retry only re-sends it and never charges the card again.
  _TakenPayment? _taken;

  /// What the waiting card quotes while the terminal has a split payment —
  /// that payment's amount, not the order total. Null otherwise.
  double? _waitingAmount;

  /// Try Again on the declined card for a split payment; null for the plain
  /// sale, which retries through [_tryAgain].
  VoidCallback? _declinedRetry;
  // ─────────────────────────────────────────────────────────────────────────

  // ── Invoice (Family 4) ───────────────────────────────────────────────────
  /// True while the Invoice form is open in the right pane.
  bool _invoiceActive = false;

  /// Mutable form state (company, VAT, email, sendByEmail). Disposed with the
  /// screen so ValueNotifiers are cleaned up when the screen exits.
  final PosInvoiceFormState _invoiceForm = PosInvoiceFormState();

  /// True while Confirm Payment is placing the order / creating the invoice.
  bool _invoiceLoading = false;
  // ─────────────────────────────────────────────────────────────────────────

  // ── Stand-alone terminal (Family 5) ──────────────────────────────────────
  /// True while the stand-alone instructions pane is open.
  bool _standaloneActive = false;

  /// Optional approval code from the terminal slip. Held in a ValueNotifier
  /// so only the text field rebuilds on typing — no root setState.
  final ValueNotifier<String> _standaloneApprovalCode =
      ValueNotifier<String>('');

  /// True while Confirm Payment is placing the order / recording the payment.
  bool _standaloneLoading = false;
  // ─────────────────────────────────────────────────────────────────────────

  /// Null after any keypad entry — a chip stays lit only while it is what the
  /// operator actually chose. See [_onCashKey].
  PosCashDenomination? _denomination;

  /// Guards the exact-tender default below so it seeds [_cash] once per
  /// screen, not on every rebuild — otherwise it would fight the Clear button,
  /// which sets the amount back to empty on purpose.
  bool _cashDefaulted = false;

  /// Set when this screen was opened to confirm a receipt's payment-method
  /// change. Nothing is charged or placed in this mode; the only write is the
  /// change itself, made by [_confirmMethodChange] when the operator confirms.
  PosMethodChange? _change;

  /// The OTHER method (`invoice` / `standalone`) chosen while changing a
  /// receipt's method. Shown as selected; the change is still only committed
  /// by [_confirmMethodChange].
  String? _changeOther;

  /// Method that was just committed in change mode (`card`, `cash`, `invoice`,
  /// `standalone`). Non-null swaps the body for the success card + BACK bar.
  String? _changedTo;
  double _changedTotal = 0;

  /// The tip applied to this sale, in currency (Family 1). Held in a
  /// ValueNotifier so changing it rebuilds only the total-dependent subtree,
  /// never the whole screen. 0 = no tip (the screen then behaves exactly as it
  /// did before tips existed).
  final ValueNotifier<double> _tip = ValueNotifier<double>(0);

  /// Around everything the screen paints, so [_holdLastFrame] can capture it.
  final GlobalKey _frameKey = GlobalKey();

  /// Set once the sale is over and the screen is on its way home: the last
  /// frame it painted, shown in place of the live screen while home slides
  /// in over it.
  ui.Image? _exitFrame;

  /// Which tenders Settings → Payments leaves available on this terminal.
  ///
  /// Read once as the screen opens rather than watched: an operator cannot
  /// reach Settings without abandoning the sale, so the value cannot change
  /// underneath a payment in progress.
  late final PosPaymentSettings _payments = _loadPaymentSettings();

  /// Falls back to the both-tenders default when prefs are not resolvable —
  /// which is the behaviour this screen had before Settings → Payments
  /// existed. A terminal must never lose the ability to take a payment because
  /// a settings read failed.
  PosPaymentSettings _loadPaymentSettings() {
    final SharedPreferences? prefs = widget.sharedPreferences ??
        (di.sl.isRegistered<SharedPreferences>()
            ? di.sl<SharedPreferences>()
            : null);
    if (prefs == null) return PosPaymentSettings.initial();
    return PosPaymentSettingsRepo(sharedPreferences: prefs).load();
  }

  @override
  void initState() {
    super.initState();
    // A sale carried over from before Card was switched off must not open on
    // a method this terminal can no longer offer.
    PosSaleSession.instance.applyEnabledTenders(
      cash: _payments.cashEnabled,
      card: _payments.cardEnabled,
    );

    // Taken once and cleared, so a later normal sale is unaffected.
    final PosMethodChange? change = PosSaleSession.instance.methodChange;
    PosSaleSession.instance.methodChange = null;
    _change = change;
    if (change != null) {
      switch (change.toMethod) {
        case 'card':
          _sale.paymentMethod = PosPaymentMethod.card;
        case 'cash':
          _sale.paymentMethod = PosPaymentMethod.cash;
        default:
          _changeOther = change.toMethod;
      }
    }
  }

  @override
  void dispose() {
    _exitFrame?.dispose();
    _tip.dispose();
    _split.dispose();
    _splitByItem.dispose();
    _splitByItemGroups.dispose();
    _invoiceForm.dispose();
    _standaloneApprovalCode.dispose();
    super.dispose();
  }

  /// Opens the tip modal and records the chosen tip. [payable] is the total
  /// before any tip (the modal bases its percentages on it). A dismissed modal
  /// leaves the current tip untouched.
  ///
  /// When the operator is on Cash with an Exact tender, the tender is re-seeded
  /// to the new grand total so a just-added tip does not silently leave the
  /// sale under-tendered.
  Future<void> _openTip(double payable) async {
    if (!_payments.tippingEnabled) {
      // Switched off for this terminal: say so rather than a row that does
      // nothing.
      showCustomSnackBarHelper(
        'Tipping is turned off in Settings → Payments.',
        isError: true,
      );
      return;
    }
    final double? chosen = await showPosTipDialog(
      context: context,
      payable: payable,
      currentTip: _tip.value,
      decimals: _decimals(context),
    );
    if (chosen == null || !mounted) return;
    _tip.value = chosen < 0 ? 0 : chosen;
    if (_isCash && (_denomination?.exact ?? false)) {
      setState(() {
        _cash = _cash.withCents(_totalCents(payable + _tip.value));
      });
    }
  }

  PosSaleSession get _sale => PosSaleSession.instance;

  bool get _isCash => _sale.paymentMethod == PosPaymentMethod.cash;

  /// Currency precision from the same config the price formatter reads, so the
  /// keypad accepts exactly as many decimals as the display can show.
  int _decimals(BuildContext context) =>
      context.read<SplashProvider>().configModel?.decimalPointSettings ?? 2;

  int _totalCents(double total) =>
      posMoneyToCents(total, decimals: _cash.decimals);

  /// Cash cannot be confirmed until the drawer has the money.
  bool _cashCovers(double total) => _cash.cents >= _totalCents(total);

  /// `Dylan / € 19.00` — customer name (when present) and the live total.
  String _backRowLabel(double total) {
    final String amount = PosHomeSpec.formatPrice(total, padZero: false);
    final String name = _sale.customerName.text.trim();
    return name.isEmpty ? amount : '$name / $amount';
  }

  Future<void> _back() async {
    // A method change came from Receipts; leaving goes back there.
    if (_change != null || _changedTo != null) {
      context.go(PosRoutes.receipts);
      return;
    }
    if (_saleLocked) {
      await _leaveCommittedSale();
      return;
    }
    // The cart lives in CartProvider and the ticket in PosSaleSession, so
    // leaving loses neither.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(PosRoutes.home);
    }
  }

  /// The sale's total right now: the cart's payable plus the tip.
  double _liveGrandTotal() {
    final CartProvider cart = context.read<CartProvider>();
    final CouponProvider coupon = context.read<CouponProvider>();
    final double payable =
        kioskPayableTotal(cart.cartList, coupon.discount ?? 0);
    return double.parse((payable + _tip.value).toStringAsFixed(2));
  }

  /// The split-by-payment state as the screen quotes it: the live total
  /// until the order is placed, the backend's figures after.
  PosSplitState? get _splitView => _split.value?.withLiveTotal(_liveGrandTotal());

  PosSplitByItemState? get _sbiView =>
      _splitByItem.value?.withLiveTotal(_liveGrandTotal());

  /// The order is placed (or a split payment is taken): the sale is
  /// committed to its method until it is finished.
  bool get _saleLocked => _saleOrderId != null || _taken != null;

  /// What is still open on the split in progress.
  double get _splitRemaining =>
      _splitView?.remaining ?? _sbiView?.remaining ?? 0;

  /// Stops anything that would abandon a committed sale — switching method,
  /// editing the ticket — and says why. Returns true when it stopped it.
  bool _saleGuard() {
    if (!_saleLocked) return false;
    showCustomSnackBarHelper(
      _invoiceActive
          ? 'This order is already sent — finish the invoice first.'
          : _standaloneActive
              ? 'This order is already sent — confirm the stand-alone '
                  'payment first.'
              : 'Finish this split payment first — '
                  '${PosHomeSpec.formatPrice(_splitRemaining, padZero: false)} '
                  'is still to pay.',
      isError: true,
    );
    return true;
  }

  int get _deviceId => context.read<KioskAuthProvider>().deviceId ?? 0;

  /// Enters split by payment. Instant and local: nothing is placed until the
  /// first payment is taken.
  ///
  /// [custom] = started from the split chooser's "Custom amount" (frame 19):
  /// the same split-payment saving path, worded per guest.
  void _startSplit({bool custom = false}) {
    if (_split.active) return;
    setState(() {
      _splitMethod = PosPaymentMethod.card;
      _splitEntry = _splitEntry.clear();
      _splitDenomination = null;
      _splitCustom = custom;
      _splitChooser = false;
    });
    _split.start(
      orderId: 0,
      deviceId: _deviceId,
      grandTotal: _liveGrandTotal(),
    );
  }

  /// Places the sale's order at the first confirm that needs it (a split
  /// payment saved, an invoice or a stand-alone payment confirmed) and hands
  /// back the same order every time after. Null (with [onError] told why)
  /// when it could not be placed — nothing is ever placed twice.
  /// [split]: a split places the order with its first payment, before the
  /// rest is in -- the backend starts it part-paid so admin waits for the
  /// last payment before listing it.
  Future<int?> _ensureSaleOrder(ValueChanged<String> onError,
      {bool split = false}) async {
    final int? existing = _saleOrderId;
    if (existing != null) return existing;

    final double grandTotal = _liveGrandTotal();
    final double tip = _tip.value;
    kiosk.KioskSession.instance.customerName = _sale.customerName.text.trim();
    final KioskPlaceResult placed = await posPlaceOrder(
      context,
      amount: grandTotal,
      tipAmountOverride: tip > 0 ? tip : null,
      splitPayment: split,
    );
    if (!mounted) return null;
    final int orderId = int.tryParse((placed.orderId ?? '').trim()) ?? 0;
    if (!placed.success || orderId <= 0) {
      onError(placed.message ?? 'The order could not be placed.');
      return null;
    }
    _saleOrderId = orderId;
    _saleTotal = grandTotal;
    _split.attachOrder(orderId, grandTotal);
    _splitByItem.attachOrder(orderId, grandTotal);
    return orderId;
  }

  /// Charges one split payment on the terminal. True once the card has paid;
  /// a decline shows the declined card, whose Try Again runs [retry].
  Future<({bool paid, String? reference})> _chargeSplitCard({
    required int seq,
    required int cents,
    required VoidCallback retry,
  }) async {
    final double amount = posCentsToMoney(cents, decimals: _cash.decimals);
    setState(() {
      _declined = false;
      _declinedRetry = null;
      _cancelling = false;
      _waitingAmount = amount;
      _phase = PosCheckoutPhase.awaitingTerminal;
    });
    final KioskPaymentResult payment = await di.sl<KioskPaymentService>().pay(
      amount: amount,
      // Same payment, same amount → same key: a retry after a decline cannot
      // charge twice. A different amount is a different payment.
      idempotencyKey: '$_idempotencyKey-split-$seq-$cents',
    );
    if (!mounted) return (paid: false, reference: null);
    setState(() {
      _phase = null;
      _cancelling = false;
      _waitingAmount = null;
    });
    switch (payment.status) {
      case KioskPaymentStatus.paid:
        return (paid: true, reference: payment.paymentRef);
      case KioskPaymentStatus.failed:
        setState(() {
          _declined = true;
          _declinedAmount = amount;
          _declinedRetry = retry;
        });
      case KioskPaymentStatus.canceled:
        showCustomSnackBarHelper('Payment canceled', isError: false);
    }
    return (paid: false, reference: null);
  }

  /// Saves [_taken]: places the order if this is the first payment, then
  /// records the payment against it — by amount (split by payment) or for
  /// the guest's items (split by item). On failure the payment stays taken
  /// and the sticky bar offers to save it again.
  Future<void> _saveTaken() async {
    final _TakenPayment? taken = _taken;
    if (taken == null || _splitBusy) return;
    setState(() {
      _splitBusy = true;
      _phase = PosCheckoutPhase.placingOrder;
    });

    String? error;
    try {
      final int? orderId =
          await _ensureSaleOrder((m) => error = m, split: true);
      if (!mounted) return;
      if (orderId != null) {
        if (_split.value != null) {
          final ApiResponseModel r = await di.sl<PosSplitRepo>().record(
            orderId: orderId,
            paidWith: taken.method,
            paidAmount: taken.amount,
            deviceId: _deviceId,
            reference: 'pos-split-$orderId-${taken.seq}',
            transactionReference: taken.transactionReference,
          );
          if (!mounted) return;
          final dynamic data = r.response?.data;
          if (r.isSuccess && data is Map) {
            final PosSplitState next = PosSplitState.fromJson(
                Map<String, dynamic>.from(data),
                deviceId: _deviceId);
            _split.update(next);
            setState(() {
              _taken = null;
              _splitBusy = false;
              _phase = null;
              _splitEntry = _splitEntry.clear();
              _splitDenomination = null;
            });
            // "Order Paid" card disabled for now: a settled order goes
            // straight home (printing finishes in the background). Restore by
            // awaiting the print, then always calling _showSplitSuccessCard.
            // if (next.fullyPaid) await _autoPrintIfEnabled('$orderId');
            // if (mounted) _showSplitSuccessCard(next);
            if (next.fullyPaid) {
              unawaited(_autoPrintIfEnabled('$orderId'));
              _endSale();
            } else {
              _showSplitSuccessCard(next);
            }
            return;
          }
          error = r.error;
        } else if (_splitByItem.value != null) {
          final ApiResponseModel r = await di.sl<PosSplitByItemRepo>().payItems(
            orderId: orderId,
            deviceId: _deviceId,
            itemIds: taken.itemIds,
            amount: taken.amount,
            paidWith: taken.method,
            reference: 'pos-sbi-$orderId-${taken.seq}',
            transactionReference: taken.transactionReference,
          );
          if (!mounted) return;
          final dynamic data = r.response?.data;
          if (r.isSuccess && data is Map) {
            final PosSplitByItemState next = PosSplitByItemState.fromJson(
                Map<String, dynamic>.from(data),
                deviceId: _deviceId);
            _splitByItem.update(next);
            setState(() {
              _taken = null;
              _splitBusy = false;
              _phase = null;
              _sbiTender = null;
              _sbiDenomination = null;
            });
            // "Order Paid" card disabled for now: a settled order goes
            // straight home (printing finishes in the background). Restore by
            // awaiting the print, then always calling
            // _showSplitByItemSuccessCard.
            // if (next.fullyPaid) await _autoPrintIfEnabled('$orderId');
            // if (mounted) _showSplitByItemSuccessCard(next);
            if (next.fullyPaid) {
              unawaited(_autoPrintIfEnabled('$orderId'));
              _endSale();
            } else {
              _showSplitByItemSuccessCard(next);
            }
            return;
          }
          error = r.error;
        }
      }
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() {
      _splitBusy = false;
      _phase = null;
    });
    final String reason =
        (error == null || error!.isEmpty) ? '' : ': ${error!}';
    showCustomSnackBarHelper(
      taken.method == 'card'
          ? 'The card payment was approved but Payment ${taken.seq} could '
              'not be saved$reason. Tap "Save Payment ${taken.seq}" to try '
              'again — the card will not be charged again.'
          : 'Payment ${taken.seq} could not be saved$reason. Tap "Save '
              'Payment ${taken.seq}" to try again.',
      isError: true,
    );
  }

  /// Back during a committed sale. A split payment that is taken but not
  /// saved must be saved first — leaving would lose the record of money
  /// already taken. Otherwise the operator confirms: the order stays saved
  /// (partially paid / unpaid, as Orders and Receipts show it) and the till
  /// moves on.
  Future<void> _leaveCommittedSale() async {
    final _TakenPayment? taken = _taken;
    if (taken != null) {
      showCustomSnackBarHelper(
        'Save Payment ${taken.seq} before leaving — its money was already '
        'taken.',
        isError: true,
      );
      return;
    }
    final bool split = _split.value != null || _splitByItem.value != null;
    final double paid = _splitView?.paid ?? _sbiView?.paid ?? 0;
    final bool? leave = await PosCompleteConfirmationDialog.show(
      context,
      heading: split ? 'Leave this split payment?' : 'Leave this order?',
      subtext: split
          ? '${PosHomeSpec.formatPrice(paid, padZero: false)} is paid and '
              '${PosHomeSpec.formatPrice(_splitRemaining, padZero: false)} is '
              'still open. The order stays saved as partially paid.'
          : 'It was already sent and stays saved as unpaid.',
      cancelLabel: 'Stay',
      confirmLabel: 'Leave',
      compact: true,
    );
    if (leave == true && mounted) _endSale();
  }

  void _selectMethod(PosPaymentMethod method, double total) {
    if (_saleGuard()) return;
    // Cancel any active OTHER mode (split, invoice, stand-alone) so the full
    // group stays single-select: PRIMARY tap always wins.
    _cancelActiveOther();
    if (_changeOther != null) setState(() => _changeOther = null);
    if (_sale.paymentMethod == method) return;
    setState(() {
      _sale.paymentMethod = method;
      if (method == PosPaymentMethod.cash) {
        // Exact is the common case at a till — most cash sales are paid to
        // the cent — so landing on it saves the typical operator a keypad
        // entry. It is a default, not a lock-in: any digit or Clear moves the
        // tender away from it exactly as before.
        _cash = _cash.withCents(_totalCents(total));
        _denomination = const PosCashDenomination.exact();
      } else {
        // Switching away from cash abandons the tender. Leaving a stale
        // amount behind would let an operator key €50, switch to card,
        // switch back and confirm against a figure they had already moved on
        // from.
        _cash = _cash.clear();
        _denomination = null;
      }
    });
  }

  /// Commits the receipt's method change. The only write in change mode.
  Future<void> _confirmMethodChange() async {
    final PosMethodChange? change = _change;
    if (change == null || _confirming) return;
    final String method = _changeOther ??
        (_sale.paymentMethod == PosPaymentMethod.cash ? 'cash' : 'card');

    setState(() => _confirming = true);
    final ApiResponseModel response =
        await di.sl<PosReceiptChangeMethodRepo>().update(
      orderId: change.orderId,
      method: method,
      reason: change.reason,
    );
    if (!mounted) return;
    setState(() => _confirming = false);

    if (!response.isSuccess) {
      final String? error = response.error;
      showCustomSnackBarHelper(
        (error != null && error.isNotEmpty)
            ? error
            : 'Could not update payment method. Please try again.',
        isError: true,
      );
      return;
    }
    setState(() {
      _changedTotal = change.total;
      _change = null;
      _changedTo = method;
    });
  }

  static String _methodLabel(String method) {
    switch (method) {
      case 'card':       return 'Card';
      case 'invoice':    return 'Invoice';
      case 'standalone': return 'Stand-alone';
      default:           return 'Cash';
    }
  }

  void _onCashKey(String token) {
    setState(() {
      _cash = _cash.key(token);
      // Manual entry drops the chip highlight, even if the value still happens
      // to match — the chip reflects a choice, not a coincidence.
      _denomination = null;
    });
  }

  void _onCashBackspace() {
    setState(() {
      _cash = _cash.backspace();
      _denomination = null;
    });
  }

  void _onCashTyped(String text) {
    setState(() {
      _cash = _cash.typed(text);
      _denomination = null;
    });
  }

  void _onCashClear() {
    setState(() {
      _cash = _cash.clear();
      _denomination = null;
    });
  }

  void _onDenomination(PosCashDenomination denomination, double total) {
    setState(() {
      _cash = _cash.withCents(
        denomination.exact ? _totalCents(total) : denomination.cents!,
      );
      _denomination = denomination;
    });
  }

  /// Split keypad entry. Inert while a taken payment waits to be saved: its
  /// amount is what was charged.
  void _onSplitKey(String token) {
    if (_taken != null) return;
    setState(() {
      _splitEntry = _splitEntry.key(token);
      _splitDenomination = null;
    });
  }

  /// Cash split denomination chip: a note value, or Exact = what is still
  /// owed on the order.
  void _onSplitDenomination(PosCashDenomination denomination) {
    final PosSplitState? state = _splitView;
    if (state == null || _taken != null) return;
    setState(() {
      _splitEntry = _splitEntry.withCents(denomination.exact
          ? posMoneyToCents(state.remaining, decimals: _splitEntry.decimals)
          : denomination.cents!);
      _splitDenomination = denomination;
    });
  }

  void _onSplitBackspace() {
    if (_taken != null) return;
    setState(() {
      _splitEntry = _splitEntry.backspace();
      _splitDenomination = null;
    });
  }

  /// Split method toggle (Card ↔ Cash).
  void _onSplitMethod(PosPaymentMethod method) {
    if (_taken != null) return;
    setState(() {
      _splitMethod = method;
      _splitDenomination = null;
    });
  }

  /// What the current split will pay, in cents, or null when it cannot be
  /// taken. Card: the keyed amount, which must not exceed what is still owed
  /// (the backend rejects an over-payment). Cash: the tender, capped at what
  /// is still owed — the excess is the change the banner shows, not part of
  /// the payment. Zero / nothing keyed is never valid.
  int? _splitAppliedCents() {
    final PosSplitState? state = _splitView;
    if (state == null || _splitEntry.cents <= 0) return null;
    final int remaining =
        posMoneyToCents(state.remaining, decimals: _splitEntry.decimals);
    if (remaining <= 0) return null;
    if (_splitMethod == PosPaymentMethod.cash) {
      return _splitEntry.cents < remaining ? _splitEntry.cents : remaining;
    }
    return _splitEntry.cents > remaining ? null : _splitEntry.cents;
  }

  /// A card amount above what is still owed — the bar says so instead of
  /// just going dark.
  bool _splitCardOver(PosSplitState state) =>
      _splitMethod == PosPaymentMethod.card &&
      _splitEntry.cents >
          posMoneyToCents(state.remaining, decimals: _splitEntry.decimals);

  /// "Start Payment N": takes the keyed amount — on the terminal for Card,
  /// from the drawer for Cash — then saves it ([_saveTaken]). With a payment
  /// already taken this only saves it again.
  Future<void> _takeSplitPayment() async {
    if (_splitBusy) return;
    if (_taken != null) return _saveTaken();
    final PosSplitState? state = _splitView;
    final int? cents = _splitAppliedCents();
    if (state == null || cents == null) return;

    final int seq = state.nextSequence;
    final bool card = _splitMethod == PosPaymentMethod.card;
    String? reference;
    if (card) {
      setState(() => _splitBusy = true);
      final charge = await _chargeSplitCard(
          seq: seq, cents: cents, retry: _takeSplitPayment);
      if (!mounted) return;
      setState(() => _splitBusy = false);
      if (!charge.paid) return;
      reference = charge.reference;
    }
    _taken = _TakenPayment(
      seq: seq,
      method: card ? 'card' : 'cash',
      amount: posCentsToMoney(cents, decimals: _splitEntry.decimals),
      transactionReference: reference,
    );
    await _saveTaken();
  }

  /// Shows a success state — Figma `success-card` (1915:9317 / 12227) on the
  /// page background, as the frames draw it (nothing behind the card).
  void _showSuccessCard(Widget Function(BuildContext dialogContext) card) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: PosHomeSpec.pageBg,
      pageBuilder: (dialogContext, anim, secAnim) => PosPayCanvas(
        child: PosPayTextScope(
          child: Material(
            type: MaterialType.transparency,
            child: card(dialogContext),
          ),
        ),
      ),
    );
  }

  /// Show success card after a split is recorded: frame 08 for an
  /// intermediate payment, frame 18's "Order Paid" once the order is settled.
  void _showSplitSuccessCard(PosSplitState state) {
    _showSuccessCard((dialogContext) {
      if (!state.fullyPaid) {
        return PosPaymentSuccessCard(
          title: 'Split Payment ${state.payments.length} Successful',
          amount: state.payments.isEmpty ? 0 : state.payments.last.paidAmount,
          buttonLabel: 'Start next payment',
          // Back to the entry pane for the next split.
          onContinue: () => Navigator.pop(dialogContext),
        );
      }
      return _orderPaidCard(dialogContext, state.orderId, state.grandTotal);
    });
  }

  /// Frame 18 once a split order is fully paid: Receipt above Next order.
  Widget _orderPaidCard(BuildContext dialogContext, int orderId, double total) =>
      PosPaymentSuccessCard(
        title: 'Order Paid',
        amount: total,
        amountLabel: 'TOTAL PAID',
        // The tip went onto the order with its first payment and is locked
        // from then on, so this is the tip inside [total].
        tip: _tip.value,
        secondaryLabel: 'Receipt',
        onSecondary: () => _showReceiptDialog(
          orderId: orderId,
          total: total,
          onAfterSend: () {
            Navigator.pop(dialogContext);
            _endSale();
          },
        ),
        buttonLabel: 'Next order',
        onContinue: () {
          Navigator.pop(dialogContext);
          _endSale();
        },
      );

  /// Ends a sale whose order is placed — finished, or left by the operator —
  /// clearing the cart and the ticket (the order already holds them) and
  /// going home.
  void _endSale() {
    _holdLastFrame();
    final CartProvider cart = context.read<CartProvider>();
    final CouponProvider coupon = context.read<CouponProvider>();
    endKioskCustomerSession(
      context.mounted ? context : null,
      cart: cart,
      coupon: coupon,
    );
    _sale.reset();
    _split.clear();
    _splitByItem.clear();
    _saleOrderId = null;
    _taken = null;
    _invoiceActive = false;
    _standaloneActive = false;
    if (context.mounted) context.go(PosRoutes.home);
  }

  /// Keeps the screen on the frame it last painted while it leaves for home.
  ///
  /// Ending a sale clears the cart, the coupon and the ticket's name / table
  /// fields at once — fields home shows too, so they must be clear when it
  /// slides in. Without this the screen would visibly empty to € 0.00 as it
  /// goes. Call it before the teardown, while that frame is still current;
  /// if it can't be captured the screen just leaves unfrozen.
  void _holdLastFrame() {
    if (_exitFrame != null) return;
    final RenderObject? boundary =
        _frameKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return;
    try {
      final ui.Image frame = boundary.toImageSync(
          pixelRatio: MediaQuery.devicePixelRatioOf(context));
      setState(() => _exitFrame = frame);
    } catch (_) {
      // Not painted yet, or the renderer can't capture: leave unfrozen.
    }
  }

  // ── Refund one payment (pill on frames 09–12 / 16 → 29 → 27 → 30) ───────

  /// A paid split-by-payment row, as the refund flow takes it.
  PosRefundSplit _refundSplitOfPayment(PosSplitPayment p) => PosRefundSplit(
        id: p.id!,
        seq: p.seq,
        method: p.paidWith,
        amount: p.paidAmount,
        reference: p.reference,
      );

  /// A paid split-by-item group, with its items named for frame 29.
  PosRefundSplit _refundSplitOfGroup(PosSplitByItemGroup g) {
    final List<PosSplitByItemLineItem> items =
        _buildLineItemsFromCart(context.read<CartProvider>().cartList);
    return PosRefundSplit(
      id: g.id!,
      seq: g.seq,
      method: g.paidWith,
      amount: g.paidAmount,
      reference: g.reference,
      itemGroup: true,
      items: [
        for (final i in items)
          if (g.itemIds.contains(i.id)) i.name,
      ].join(', '),
    );
  }

  /// A paid row's Refund pill: the existing refund flow for that one payment
  /// (manager-gated like the Receipts entry), pushed over the sale so the
  /// split session stays as it is underneath; the balance is read again on
  /// the way back.
  Future<void> _refundPayment(PosRefundSplit split) async {
    if (!PosAccessScope.guard(context, PosPermission.processRefunds)) return;
    final PosSplitState? byPayment = _split.value;
    final PosSplitByItemState? byItem = _splitByItem.value;
    final int orderId = byPayment?.orderId ?? byItem?.orderId ?? 0;
    final int deviceId = byPayment?.deviceId ?? byItem?.deviceId ?? 0;
    final List<CartModel> lines = [
      for (final CartModel? l in context.read<CartProvider>().cartList)
        if (l != null) l,
    ];
    final PosRefundSession refund = PosRefundSession.instance
      ..reset()
      ..order = PosReceiptDetail(
        id: orderId,
        placedAt: null,
        customerName: _sale.customerName.text.trim(),
        table: null,
        method: split.method,
        subtotal: kioskCartTotal(lines),
        discount: context.read<CouponProvider>().discount ?? 0,
        total: byPayment?.grandTotal ?? byItem?.grandTotal ?? 0,
        orderStatus: 'pending',
        paymentStatus: 'partial_paid',
        lines: lines,
      )
      ..splits = [split]
      ..fromPayment = true;
    await context.push(PosRoutes.refund);
    refund.reset();
    if (!mounted) return;
    await _refreshSplitBalance(orderId, deviceId);
  }

  /// Re-reads the split's balance after a refund. A failed read leaves the
  /// pane as it was.
  Future<void> _refreshSplitBalance(int orderId, int deviceId) async {
    try {
      if (_split.value != null) {
        final ApiResponseModel r = await di
            .sl<PosSplitRepo>()
            .balance(orderId: orderId, deviceId: deviceId);
        final dynamic data = r.response?.data;
        if (!mounted || !r.isSuccess || data is! Map) return;
        _split.update(PosSplitState.fromJson(Map<String, dynamic>.from(data),
            deviceId: deviceId));
      } else if (_splitByItem.value != null) {
        final ApiResponseModel r = await di
            .sl<PosSplitByItemRepo>()
            .balance(orderId: orderId, deviceId: deviceId);
        final dynamic data = r.response?.data;
        if (!mounted || !r.isSuccess || data is! Map) return;
        _splitByItem.update(PosSplitByItemState.fromJson(
            Map<String, dynamic>.from(data),
            deviceId: deviceId));
      }
    } catch (_) {
      // Leave the pane as it was; the next recorded payment refreshes it.
    }
  }

  // ── Split chooser (frame 13) ─────────────────────────────────────────────

  /// "Split by item" in the OTHER group: show the chooser. Nothing is placed.
  void _openSplitChooser() {
    if (_saleGuard()) return;
    _cancelActiveOther();
    setState(() {
      _splitChooser = true;
      _splitChoice = PosSplitChoice.byItem;
    });
  }

  /// Continue on the chooser: By item → the item picker (frame 14), Custom
  /// amount → the per-guest amount entry (frame 19). Both are instant; the
  /// order is placed with the first payment.
  void _continueSplitChooser() {
    if (_splitChoice == PosSplitChoice.byItem) {
      _startSplitByItem();
    } else {
      _startSplit(custom: true);
    }
  }

  // ── Split by item → cash (frame 15) ──────────────────────────────────────

  /// "Start Payment N" on Cash: open the tender step for the picked items.
  /// Nothing is taken until the tender covers the guest's share.
  void _startSbiCash(List<PosSplitByItemLineItem> items) {
    final PosSplitByItemQuote quote = _sbiQuote(items);
    if (!quote.payable) return;
    setState(() {
      // Exact, like a plain cash sale (see _selectMethod).
      _sbiTender = PosCashEntry(decimals: _cash.decimals).withCents(quote.cents);
      _sbiDenomination = const PosCashDenomination.exact();
    });
  }

  void _onSbiKey(String token) {
    final PosCashEntry? tender = _sbiTender;
    if (tender == null || _taken != null) return;
    setState(() {
      _sbiTender = tender.key(token);
      _sbiDenomination = null;
    });
  }

  void _onSbiBackspace() {
    final PosCashEntry? tender = _sbiTender;
    if (tender == null || _taken != null) return;
    setState(() {
      _sbiTender = tender.backspace();
      _sbiDenomination = null;
    });
  }

  void _onSbiDenomination(PosCashDenomination d, int dueCents) {
    final PosCashEntry? tender = _sbiTender;
    if (tender == null || _taken != null) return;
    setState(() {
      _sbiTender = tender.withCents(d.exact ? dueCents : d.cents!);
      _sbiDenomination = d;
    });
  }

  /// The segmented control on frame 15: Card leaves the tender step for the
  /// item picker, on Card.
  void _onSbiMethod(PosPaymentMethod method) {
    if (method == PosPaymentMethod.cash || _taken != null) return;
    setState(() {
      _sbiTender = null;
      _sbiDenomination = null;
      _splitByItemMethod = PosPaymentMethod.card;
    });
  }

  // ── Split-by-item (Family 3) ─────────────────────────────────────────────

  /// Enters split by item. Instant and local: the order is placed with the
  /// first guest's payment.
  void _startSplitByItem() {
    if (_splitByItem.active) return;
    setState(() {
      _splitChooser = false;
      _splitByItemMethod = PosPaymentMethod.card;
      _sbiTender = null;
      _sbiDenomination = null;
    });
    _splitByItemGroups.nextGroup(1);
    _splitByItem.start(
      orderId: 0,
      deviceId: _deviceId,
      grandTotal: _liveGrandTotal(),
    );
  }

  /// The ticket as split-by-item rows: one per line (frame 21 — "Cappuccino ×
  /// 2" is one row), its add-ons under the name, else its unit.
  List<PosSplitByItemLineItem> _buildLineItemsFromCart(List<CartModel?> lines) {
    final List<PosSplitByItemLineItem> result = [];
    for (int i = 0; i < lines.length; i++) {
      final CartModel? line = lines[i];
      if (line == null) continue;
      final int qty = line.quantity ?? 1;
      final List<String> notes = [
        for (final PosReceiptNote n in posReceiptNotes(line))
          n.included
              ? n.label
              : 'No ${n.label.isEmpty ? '' : n.label[0].toLowerCase()}'
                  '${n.label.length > 1 ? n.label.substring(1) : ''}',
      ];
      final String name = posReceiptLineName(line);
      result.add(PosSplitByItemLineItem(
        id: i,
        name: name.isEmpty ? 'Item ${i + 1}' : name,
        detail: notes.isNotEmpty
            ? notes.join(' · ')
            : (posReceiptUnit(line) ?? ''),
        quantity: qty,
        // What the receipt charges for the line: unit price incl. paid
        // add-ons, times quantity.
        price: double.parse((kioskLineUnitPrice(line) * qty).toStringAsFixed(2)),
      ));
    }
    return result;
  }

  /// What the guest paying now is charged for the ticked items: their own
  /// items plus their share of any order discount / tip; the guest who takes
  /// the last items pays exactly what is left.
  PosSplitByItemQuote _sbiQuote(List<PosSplitByItemLineItem> items) {
    final PosSplitByItemState? state = _sbiView;
    if (state == null) return PosSplitByItemQuote.none;
    return posQuoteSplitByItem(
      items: items,
      picked: _splitByItemGroups.value.selectedItemIds,
      paid: state.paidItemIds,
      orderTotal: state.grandTotal,
      remaining: state.remaining,
      decimals: _cash.decimals,
    );
  }

  double _sbiQuoteAmount(List<PosSplitByItemLineItem> items) =>
      posCentsToMoney(_sbiQuote(items).cents, decimals: _cash.decimals);

  /// "Start Payment N" (card) or, on cash, "Confirm Payment" after the tender
  /// step (frame 15): takes the guest's share, then saves it for their items
  /// ([_saveTaken]). With a payment already taken this only saves it again.
  Future<void> _takeSbiPayment() async {
    if (_splitBusy) return;
    if (_taken != null) return _saveTaken();
    final PosSplitByItemState? state = _sbiView;
    if (state == null) return;
    final List<PosSplitByItemLineItem> items =
        _buildLineItemsFromCart(context.read<CartProvider>().cartList);
    final PosSplitByItemQuote quote = _sbiQuote(items);
    if (!quote.payable) {
      showCustomSnackBarHelper('Select at least one item', isError: true);
      return;
    }
    final Set<int> picked = _splitByItemGroups.value.selectedItemIds;
    final List<int> itemIds = [
      for (final PosSplitByItemLineItem i in items)
        if (picked.contains(i.id) && !state.paidItemIds.contains(i.id)) i.id,
    ];

    final int seq = state.nextPaymentNumber;
    final bool card = _splitByItemMethod == PosPaymentMethod.card;
    String? reference;
    if (card) {
      setState(() => _splitBusy = true);
      final charge = await _chargeSplitCard(
          seq: seq, cents: quote.cents, retry: _takeSbiPayment);
      if (!mounted) return;
      setState(() => _splitBusy = false);
      if (!charge.paid) return;
      reference = charge.reference;
    }
    _taken = _TakenPayment(
      seq: seq,
      method: card ? 'card' : 'cash',
      amount: posCentsToMoney(quote.cents, decimals: _cash.decimals),
      transactionReference: reference,
      itemIds: itemIds,
    );
    await _saveTaken();
  }

  /// Success overlay after each guest's payment: "Start next payment" with
  /// the items still unpaid already ticked (frame 16), or the settled-order
  /// card (frame 18).
  void _showSplitByItemSuccessCard(PosSplitByItemState state) {
    _showSuccessCard((dialogContext) {
      if (!state.fullyPaid) {
        // No frame draws this intermediate state; it uses frame 08's card.
        final List<PosSplitByItemGroup> paid = state.paidGroups;
        return PosPaymentSuccessCard(
          title: 'Split Payment ${paid.length} Successful',
          amount: paid.isEmpty ? 0 : paid.last.paidAmount,
          buttonLabel: 'Start next payment',
          onContinue: () {
            Navigator.pop(dialogContext);
            final List<PosSplitByItemLineItem> items =
                _buildLineItemsFromCart(context.read<CartProvider>().cartList);
            _splitByItemGroups.nextGroup(
              state.nextPaymentNumber,
              preselected: {
                for (final PosSplitByItemLineItem i in items)
                  if (!state.paidItemIds.contains(i.id)) i.id,
              },
            );
            setState(() => _splitByItemMethod = PosPaymentMethod.card);
          },
        );
      }
      return _orderPaidCard(dialogContext, state.orderId, state.grandTotal);
    });
  }

  // ── Invoice (Family 4) ───────────────────────────────────────────────────

  /// Operator taps "Invoice" in the OTHER row: the form opens at once.
  /// Nothing is placed until Confirm Payment ([_submitInvoice]).
  void _startInvoice() {
    if (_invoiceActive) return;
    setState(() => _invoiceActive = true);
  }

  /// Confirm Payment on the invoice form (frame 03): places the order — once
  /// — then creates its invoice. A failure leaves the form up; confirming
  /// again reuses the placed order and the same reference, so nothing is
  /// created twice.
  Future<void> _submitInvoice() async {
    if (_invoiceLoading || !_invoiceForm.isValid) return;
    setState(() {
      _invoiceLoading = true;
      _phase = PosCheckoutPhase.placingOrder;
    });

    String? error;
    try {
      final int? orderId = await _ensureSaleOrder((m) => error = m);
      if (!mounted) return;
      if (orderId != null) {
        final ApiResponseModel response =
            await di.sl<PosInvoiceRepo>().create(_invoiceForm.toPayload(
                  orderId: orderId,
                  deviceId: _deviceId,
                  // One invoice per order: a retry replays it.
                  reference: 'pos-inv-$orderId',
                ));
        if (!mounted) return;
        if (response.isSuccess) {
          setState(() {
            _invoiceLoading = false;
            _phase = null;
          });
          _showInvoiceSuccessCard(orderId);
          return;
        }
        error = response.error;
      }
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() {
      _invoiceLoading = false;
      _phase = null;
    });
    showCustomSnackBarHelper(
      'The invoice could not be created'
      '${(error == null || error!.isEmpty) ? '' : ': ${error!}'}. '
      'Tap Confirm Payment to try again.',
      isError: true,
    );
  }

  /// No frame draws the invoice outcome; it uses frame 18's card.
  void _showInvoiceSuccessCard(int orderId) {
    _showSuccessCard((dialogContext) => PosPaymentSuccessCard(
          title: 'Invoice created',
          amount: _saleTotal,
          amountLabel: 'AMOUNT INVOICED',
          tip: _tip.value,
          secondaryLabel: 'Receipt',
          onSecondary: () => _showReceiptDialog(
            orderId: orderId,
            total: _saleTotal,
            onAfterSend: () {
              Navigator.pop(dialogContext);
              _endSale();
            },
          ),
          buttonLabel: 'Next order',
          onContinue: () {
            Navigator.pop(dialogContext);
            _endSale();
          },
        ));
  }

  // ─────────────────────────────────────────────────────────────────────────

  // ── Stand-alone terminal (Family 5) ──────────────────────────────────────

  /// Operator taps "Stand-alone" in the OTHER row: the instructions open at
  /// once. Nothing is placed until Confirm Payment ([_submitStandalone]).
  void _startStandalone() {
    if (_standaloneActive) return;
    _standaloneApprovalCode.value = '';
    setState(() => _standaloneActive = true);
  }

  /// Confirm Payment on the stand-alone pane (frame 04): places the order —
  /// once — then records the terminal payment against it. A failure leaves
  /// the pane up; confirming again reuses the order and the reference.
  Future<void> _submitStandalone() async {
    if (_standaloneLoading) return;
    setState(() {
      _standaloneLoading = true;
      _phase = PosCheckoutPhase.placingOrder;
    });

    String? error;
    try {
      final int? orderId = await _ensureSaleOrder((m) => error = m);
      if (!mounted) return;
      if (orderId != null) {
        final String code = _standaloneApprovalCode.value.trim();
        final ApiResponseModel response =
            await di.sl<PosStandaloneRepo>().record(
          orderId: orderId,
          deviceId: _deviceId,
          // One stand-alone payment per order: a retry replays it.
          reference: 'pos-sa-$orderId',
          approvalCode: code.isEmpty ? null : code,
        );
        if (!mounted) return;
        if (response.isSuccess) {
          setState(() {
            _standaloneLoading = false;
            _phase = null;
          });
          _showStandaloneSuccessCard(orderId);
          return;
        }
        error = response.error;
      }
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return;
    setState(() {
      _standaloneLoading = false;
      _phase = null;
    });
    showCustomSnackBarHelper(
      'The stand-alone payment could not be saved'
      '${(error == null || error!.isEmpty) ? '' : ': ${error!}'}. '
      'Tap Confirm Payment to try again.',
      isError: true,
    );
  }

  /// No frame draws the stand-alone outcome; it uses frame 18's card.
  void _showStandaloneSuccessCard(int orderId) {
    _showSuccessCard((dialogContext) => PosPaymentSuccessCard(
          title: 'Payment confirmed',
          amount: _saleTotal,
          amountLabel: 'TOTAL PAID',
          tip: _tip.value,
          secondaryLabel: 'Receipt',
          onSecondary: () => _showReceiptDialog(
            orderId: orderId,
            total: _saleTotal,
            onAfterSend: () {
              Navigator.pop(dialogContext);
              _endSale();
            },
          ),
          buttonLabel: 'Next order',
          onContinue: () {
            Navigator.pop(dialogContext);
            _endSale();
          },
        ));
  }

  // ── Family 6 — Receipt Email / Print ─────────────────────────────────────

  /// Shows the receipt options dialog on top of the current success card.
  ///
  /// [orderId] and [total] populate the subtitle.
  /// [onAfterSend] is called on successful send OR when the user skips.
  void _showReceiptDialog({
    required int orderId,
    required double total,
    required VoidCallback onAfterSend,
  }) {
    final int deviceId =
        context.read<KioskAuthProvider>().deviceId ?? 0;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'receipt',
      // `dim-overlay` (1915:13039): ink at 40%.
      barrierColor: PosPaymentSpec.v2DialogScrim,
      pageBuilder: (dialogContext, anim, secAnim) => PosPayCanvas(
        child: PosReceiptDialog(
          orderId:    orderId,
          total:      total,
          deviceId:   deviceId,
          onComplete: () {
            Navigator.pop(dialogContext);
            onAfterSend();
          },
          onSkip: () => Navigator.pop(dialogContext),
        ),
      ),
    );
  }

  /// Shows the success card for a single card / cash payment — frame 18
  /// ("Order Paid", 1915:12227): "Receipt" (outline → receipt dialog → home)
  /// above "Next order" (ink → home).
  ///
  /// Not shown for now — see the commented call in [_confirm].
  // ignore: unused_element
  void _showSinglePaymentSuccessCard(double total, int orderId, double tip) {
    _showSuccessCard((dialogContext) => PosPaymentSuccessCard(
          title: 'Order Paid',
          amount: total,
          amountLabel: 'TOTAL PAID',
          tip: tip,
          secondaryLabel: 'Receipt',
          onSecondary: () => _showReceiptDialog(
            orderId: orderId,
            total: total,
            onAfterSend: () {
              Navigator.pop(dialogContext);
              if (context.mounted) context.go(PosRoutes.home);
            },
          ),
          buttonLabel: 'Next order',
          onContinue: () {
            Navigator.pop(dialogContext);
            if (context.mounted) context.go(PosRoutes.home);
          },
        ));
  }

  // ─────────────────────────────────────────────────────────────────────────

  /// Deselects / cancels whichever OTHER mode is currently active.
  ///
  /// A split leaves nothing behind: its order is placed only with the first
  /// payment, and once that has happened the split can't be cancelled from
  /// here at all ([_saleGuard]). The UI returns to the Card/Cash selector.
  ///
  /// In receipt change-method mode this also clears [_changeOther] so re-tapping
  /// Invoice / Stand-alone actually deselects back to PRIMARY.
  void _cancelActiveOther() {
    if (_changeOther != null) {
      setState(() => _changeOther = null);
      return;
    }
    if (_splitChooser) {
      setState(() => _splitChooser = false);
      return;
    }
    if (_split.value != null) {
      _split.clear();
      setState(() {
        _splitCustom = false;
        _splitEntry = _splitEntry.clear();
        _splitDenomination = null;
      });
      return;
    }
    if (_splitByItem.value != null) {
      _splitByItem.clear();
      _splitByItemGroups.clearSelection();
      setState(() {
        _sbiTender = null;
        _sbiDenomination = null;
      });
      return;
    }
    if (_invoiceActive) {
      setState(() => _invoiceActive = false);
      return;
    }
    if (_standaloneActive) {
      setState(() => _standaloneActive = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  /// The OTHER row tapped again: deselect it — unless a split is committed.
  void _onCancelActiveOther() {
    if (_saleGuard()) return;
    _cancelActiveOther();
  }

  /// The ticket's steppers. Once a split has placed the order the ticket is
  /// what was ordered, so it can't change underneath the remaining payments.
  void _incrementLine(int index) {
    if (_saleGuard()) return;
    final CartProvider cart = context.read<CartProvider>();
    final CartModel? line = cart.cartList[index];
    if (line == null) return;
    cart.setQuantity(isIncrement: true, cart: line, fromProductView: false);
  }

  void _decrementLine(int index) {
    if (_saleGuard()) return;
    final CartProvider cart = context.read<CartProvider>();
    final CartModel? line = cart.cartList[index];
    if (line == null) return;
    if ((line.quantity ?? 1) <= 1) {
      cart.removeFromCart(index);
      // Split-by-item ticks are line positions; removing a line moves them.
      _splitByItemGroups.clearSelection();
    } else {
      cart.setQuantity(isIncrement: false, cart: line, fromProductView: false);
    }
  }

  Future<void> _openReceiptOptions(BuildContext anchorContext) async {
    final PosReceiptMenuAction? action = await showPosReceiptContextMenu(
      context: context,
      anchorContext: anchorContext,
    );
    if (action == null || !mounted) return;
    await handlePosReceiptMenuAction(context, action);
  }

  /// Asks the terminal to abandon the payment in flight.
  ///
  /// Does not navigate: the pending `pay()` future is what owns the outcome, so
  /// cancelling resolves it as `canceled` and the existing switch in [_confirm]
  /// puts the operator back on the method selector with the ticket untouched.
  /// Nothing here clears the cart.
  ///
  /// The button goes to `Cancelling...` immediately, because the terminal is
  /// not obliged to answer at once — today's simulator does not even shorten
  /// its wait. Leaving the screen before the answer arrives would risk a
  /// `paid` result landing with no order behind it.
  Future<void> _cancelTransaction() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);
    try {
      await posCancelTerminalPayment();
    } catch (_) {
      // A terminal that refuses the cancel still owns the payment; the pending
      // future remains the source of truth, so there is nothing to undo here.
    }
  }

  /// Dismisses the declined card and returns the operator to the method
  /// selector. The sale is untouched — nothing here clears the cart, the
  /// coupon or the ticket.
  ///
  /// Still tells the terminal to drop the transaction, for parity with Cancel
  /// on the waiting card. That is belt and braces today: the attempt already
  /// terminated, which is why this card is on screen at all. A real terminal
  /// should treat a cancel on a finished transaction as a no-op, so the call is
  /// guarded rather than trusted.
  Future<void> _dismissDeclined() async {
    setState(() {
      _declined = false;
      _declinedRetry = null;
    });
    try {
      await posCancelTerminalPayment();
    } catch (_) {
      // Nothing to undo: there is no payment in flight to lose.
    }
  }

  /// Starts a fresh attempt at the same amount.
  ///
  /// Goes through [_confirm], the same call the first attempt used, so there is
  /// exactly one payment path and no second order-placement branch to keep in
  /// step. `_idempotencyKey` is stable for the life of this screen, so every
  /// retry is the same checkout attempt as far as the terminal is concerned and
  /// cannot double-charge.
  ///
  /// Note for a real terminal: a PSP that caches by idempotency key may replay
  /// the original decline rather than starting a new authorisation. If that
  /// turns out to be the behaviour, this is the line that needs a fresh key —
  /// and the double-charge question has to be answered first.
  void _tryAgain(double total, double tip) {
    if (_confirming) return;
    _confirm(total, tip);
  }

  Future<void> _confirm(double total, double tip) async {
    if (_confirming) return;
    final CartProvider cart = context.read<CartProvider>();
    if (!cart.cartList.any((line) => line != null)) return;
    // Belt and braces: the button is already disabled in this state, but a
    // short tender must never reach order placement.
    if (_isCash && !_cashCovers(total)) return;

    setState(() {
      _confirming = true;
      _phase = null;
      _cancelling = false;
      _declined = false;
    });
    final PosCheckoutResult result = await posConfirmPayment(
      context,
      method: _sale.paymentMethod,
      idempotencyKey: _idempotencyKey,
      // The tip chosen on this screen; added to the charge and the stored
      // total and sent as tip_amount. 0 = no tip, unchanged behaviour.
      tipAmount: tip,
      onPhase: (phase) {
        if (!mounted) return;
        setState(() => _phase = phase);
      },
      // Recorded on the order as `bring_change_amount`, which the backend
      // persists only for cash_on_delivery — exactly what POS sends. Change is
      // derivable from it and the total, so the tender is the figure to keep.
      tenderedAmount: _isCash
          ? posCentsToMoney(_cash.cents, decimals: _cash.decimals)
          : null,
    );
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _phase = null;
      _cancelling = false;
    });

    switch (result.status) {
      case PosCheckoutStatus.placed:
        // posConfirmPayment has already cleared the sale, but nothing has
        // repainted since: hold that frame before anything does.
        _holdLastFrame();
        _cash = _cash.clear();
        _denomination = null;
        // "Order Paid" card disabled for now: straight home, as its
        // "Next order" did, with printing finishing in the background.
        // Restore by awaiting the print, then:
        // _showSinglePaymentSuccessCard(
        //   total,
        //   int.tryParse((result.orderId ?? '').trim()) ?? 0,
        //   tip,
        // );
        unawaited(_autoPrintIfEnabled(result.orderId));
        context.go(PosRoutes.home);
      case PosCheckoutStatus.paymentFailed:
        // Figma 1641:4218 takes over the content area, rather than a snackbar
        // the operator can miss while looking at the customer.
        setState(() {
          _declined = true;
          _declinedAmount = total;
        });
      case PosCheckoutStatus.paymentCanceled:
        showCustomSnackBarHelper('Payment canceled', isError: false);
      case PosCheckoutStatus.orderFailed:
        // Money may already have moved, so this cannot read as a plain retry.
        showCustomSnackBarHelper(
          result.message ??
              'Payment taken but the order did not post — do not re-charge.',
        );
    }
  }

  /// Settings → Hardware → "Auto-Print Receipts".
  ///
  /// Reuses the existing [posPrintReceipt] path verbatim rather than adding a
  /// second printing mechanism: the POS ships as Flutter Web, so printing is
  /// `window.print()` against a hidden HTML ticket and the browser dialog
  /// chooses the device. There is no printer pairing anywhere in the product,
  /// so this cannot target a named printer — it only removes the manual step.
  ///
  /// Best-effort by design. A print that fails must never turn a placed order
  /// into an error the operator has to reason about, so every failure path just
  /// leaves the receipt unprinted and reachable from Receipts.
  Future<void> _autoPrintIfEnabled(String? rawOrderId) async {
    // Checkout hands back the id as a string; receipt lookup is keyed on the
    // integer primary key. A non-numeric id means there is nothing to fetch.
    final int? orderId = int.tryParse((rawOrderId ?? '').trim());
    if (orderId == null) return;

    final settings = posLoadReceiptSettings(
      context,
      sharedPreferences: widget.sharedPreferences,
    );
    if (!settings.hardware.autoPrintReceipts) return;

    final KioskManagerProvider manager = context.read<KioskManagerProvider>();
    // The screen goes home without waiting for this, so past here nothing
    // may depend on it still being mounted.
    try {
      await manager.loadReceiptDetail(orderId);
      final Map<String, dynamic>? json = manager.receiptDetail;
      if (json == null || manager.receiptDetailId != orderId) return;
      posPrintReceipt(
        PosReceiptDetail.fromJson(json),
        hardware: settings.hardware,
        general: settings.general,
      );
    } catch (_) {
      showCustomSnackBarHelper(
        'Order placed, but the receipt could not be printed automatically.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ui.Image? exitFrame = _exitFrame;
    if (exitFrame != null) {
      return ColoredBox(
        color: PosHomeSpec.pageBg,
        child: RawImage(
          image: exitFrame,
          scale: MediaQuery.devicePixelRatioOf(context),
          fit: BoxFit.fill,
        ),
      );
    }
    return RepaintBoundary(key: _frameKey, child: _buildLive(context));
  }

  Widget _buildLive(BuildContext context) {
    final CartProvider cart = context.watch<CartProvider>();
    final CouponProvider coupon = context.watch<CouponProvider>();
    final SplashProvider splash = context.read<SplashProvider>();

    // Precision can only change when config loads; adopting it here keeps the
    // buffer and the formatter agreeing without a second source of truth.
    final int decimals = _decimals(context);
    if (decimals != _cash.decimals) {
      _cash = PosCashEntry(raw: _cash.raw, decimals: decimals);
    }

    final List<CartModel?> lines = cart.cartList;
    final bool hasItems = lines.any((line) => line != null);
    final double discount = coupon.discount ?? 0;
    final double subtotal = kioskCartTotal(lines);
    // Opened from Receipts "Change payment method"? Show that receipt's total
    // instead of the (zero) cart total. The field is captured in initState so
    // repeated build calls don't lose it.
    final double total = _change?.total ?? kioskPayableTotal(lines, discount);

    // Same exact-tender default as switching onto Cash by hand (see
    // _selectMethod) — but for the sale that already opens on Cash, so an
    // operator never has to touch Exact themselves just to match what
    // switching methods would have given them for free.
    if (!_cashDefaulted) {
      _cashDefaulted = true;
      if (_isCash && _cash.isEmpty) {
        _cash = _cash.withCents(_totalCents(total));
        _denomination = const PosCashDenomination.exact();
      }
    }

    final String? changedTo = _changedTo;
    if (changedTo != null) {
      return Scaffold(
        backgroundColor: PosHomeSpec.pageBg,
        body: PosPayTextScope(
        child: SafeArea(
          child: PosPayCanvas(
          child: Column(
            children: [
              PosPayBackRow(
                onBack: _back,
                label: _backRowLabel(_changedTotal),
              ),
              Expanded(
                child: PosPaymentSuccessCard(
                  title: 'Payment method changed',
                  amount: _changedTotal,
                  amountLabel: 'NOW PAID BY ${_methodLabel(changedTo).toUpperCase()}',
                  buttonLabel: 'Back to receipts',
                  onContinue: _back,
                ),
              ),
            ],
          ),
          ),
        ),
      ),
      );
    }

    final Widget screen = Scaffold(
      backgroundColor: PosHomeSpec.pageBg,
      body: PosPayTextScope(
        child: SafeArea(
        // Laid out at Figma's 1366×1024 and scaled to the window.
        child: PosPayCanvas(
        child: Column(
          children: [
            // No top nav bar: no frame in the "POS payment" layer (1915:9314)
            // draws one — the screen opens on `back-btn-row`, and the back
            // button is the way out, which also keeps an operator from tabbing
            // away mid-charge.
            //
            // Everything below reacts to the tip: the displayed
            // total (back row + summary), the cash coverage and the charged
            // amount all become payable + tip. A ValueNotifier rebuilds just
            // this subtree when the tip changes — no root setState.
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: _tip,
                builder: (context, tip, _) {
                  // `total` is the payable (no tip); `grandTotal` is what the
                  // customer pays and what we charge and store.
                  final double grandTotal = double.parse(
                      (total + tip).toStringAsFixed(2));
                  // Settings → Payments "Enable tipping screen" (on by
                  // default); off, the row explains instead of opening.
                  final VoidCallback? onTip =
                      hasItems ? () => _openTip(total) : null;
                  // On a split the tip is part of the order placed with the
                  // first payment, so it can change only until then.
                  final VoidCallback? onSplitTip = _saleLocked ? null : onTip;

                  return Column(
                    children: [
                      // Back is withheld while the terminal has the payment:
                      // leaving mid-transaction charges a card against an
                      // order nobody placed. Cancel Transaction is the way out.
                      // Frames 06 / 07 draw the waiting and declined cards
                      // full-screen: no back row (the card's own buttons are
                      // the only way on).
                      if (!_isWaitingForTerminal && !_declined)
                      PosPayBackRow(
                        onBack: _back,
                        // `Dylan / € 19.00` (node 1915:9351): customer name and
                        // the live grand total, centred.
                        label: _backRowLabel(grandTotal),
                      ),
                      if (_declined)
                        Expanded(
                          child: PosDeclinedCard(
                            // The figure the declined attempt was for — the
                            // split payment's amount, or the grand total that
                            // was charged; not a fresh read.
                            amountDue: _declinedAmount,
                            retrying: _confirming || _splitBusy,
                            onCancel: _confirming || _splitBusy
                                ? null
                                : _dismissDeclined,
                            onTryAgain: _confirming || _splitBusy
                                ? null
                                : _declinedRetry ??
                                    () => _tryAgain(grandTotal, tip),
                          ),
                        )
                      else if (_isWaitingForTerminal)
                        Expanded(
                          child: PosWaitingCard(
                            // A split payment quotes its own amount.
                            amountDue: _waitingAmount ?? grandTotal,
                            cancelling: _cancelling,
                            onCancel:
                                _cancelling ? null : _cancelTransaction,
                          ),
                        )
                      else ...[
                        Expanded(
                          child: ValueListenableBuilder<PosSplitByItemState?>(
                            valueListenable: _splitByItem,
                            builder: (context, sbiState, _) {
                              final bool inSplitByItem = sbiState != null;
                              final List<PosSplitByItemLineItem> sbiItems =
                                  _buildLineItemsFromCart(lines);
                              return ValueListenableBuilder<PosSplitState?>(
                                valueListenable: _split,
                                builder: (context, splitState, _) {
                                  final bool inSplit = splitState != null;
                                  return _Content(
                                    lines: lines,
                                    hasItems: hasItems,
                                    imageBaseUrl:
                                        splash.baseUrls?.productImageUrl,
                                    dealImageBaseUrl:
                                        splash.baseUrls?.dealImageUrl,
                                    orderNumber: _sale.orderNumber,
                                    customerNameController: _sale.customerName,
                                    tableController: _sale.table,
                                    method: _sale.paymentMethod,
                                    cashEnabled: _payments.cashEnabled,
                                    cardEnabled: _payments.cardEnabled,
                                    subtotal: subtotal,
                                    discount: discount,
                                    total: grandTotal,
                                    tip: tip,
                                    onTip: onTip,
                                    onSplitTip: onSplitTip,
                                    onSelectMethod: (method) =>
                                        _selectMethod(method, grandTotal),
                                    cash: _cash,
                                    denomination: _denomination,
                                    totalCents: _totalCents(grandTotal),
                                    onCashKey: _onCashKey,
                                    onCashTyped: _onCashTyped,
                                    onCashBackspace: _onCashBackspace,
                                    onCashClear: _onCashClear,
                                    onDenomination: (d) =>
                                        _onDenomination(d, grandTotal),
                                    onIncrement: _incrementLine,
                                    onDecrement: _decrementLine,
                                    onOptions: _openReceiptOptions,
                                    inSplit: inSplit,
                                    splitState:
                                        splitState?.withLiveTotal(grandTotal),
                                    splitMethod: _splitMethod,
                                    splitEntry: _splitEntry,
                                    onSplitMethod: _onSplitMethod,
                                    onSplitKey: _onSplitKey,
                                    onSplitBackspace: _onSplitBackspace,
                                    onSplitDenomination: _onSplitDenomination,
                                    splitDenomination: _splitDenomination,
                                    splitInputLocked: _taken != null,
                                    onSplitByPayment: _change != null
                                        ? null
                                        : () {
                                            if (_saleGuard()) return;
                                            _cancelActiveOther();
                                            _startSplit();
                                          },
                                    splitCustom: _splitCustom,
                                    onRefundPayment: _change != null
                                        ? null
                                        : (p) => _refundPayment(
                                            _refundSplitOfPayment(p)),
                                    onRefundGroup: _change != null
                                        ? null
                                        : (g) => _refundPayment(
                                            _refundSplitOfGroup(g)),
                                    splitChooser: _splitChooser,
                                    splitChoice: _splitChoice,
                                    onSplitChoice: (c) =>
                                        setState(() => _splitChoice = c),
                                    inSplitByItem: inSplitByItem,
                                    splitByItemState:
                                        sbiState?.withLiveTotal(grandTotal),
                                    splitByItemGroups: _splitByItemGroups,
                                    splitByItemMethod: _splitByItemMethod,
                                    splitByItemLineItems: sbiItems,
                                    onSplitByItem: _change != null || inSplitByItem
                                        ? null
                                        : _openSplitChooser,
                                    onToggleSplitItem: (id) {
                                      if (_taken != null) return;
                                      _splitByItemGroups.toggleItem(id);
                                    },
                                    onSplitByItemMethod: (m) {
                                      if (_taken != null) return;
                                      setState(() => _splitByItemMethod = m);
                                    },
                                    sbiAmountOf: (_) =>
                                        _sbiQuoteAmount(sbiItems),
                                    sbiTender: _sbiTender,
                                    sbiDenomination: _sbiDenomination,
                                    sbiCharge: _sbiQuote(sbiItems).payable
                                        ? _sbiQuoteAmount(sbiItems)
                                        : null,
                                    sbiPickedNames: [
                                      for (final i in sbiItems)
                                        if (_splitByItemGroups.value
                                                .isSelected(i.id) &&
                                            !(sbiState?.paidItemIds
                                                    .contains(i.id) ??
                                                false))
                                          i.title,
                                    ],
                                    onSbiKey: _onSbiKey,
                                    onSbiBackspace: _onSbiBackspace,
                                    onSbiDenomination: _onSbiDenomination,
                                    onSbiMethod: _onSbiMethod,
                                    invoiceActive: _invoiceActive,
                                    invoiceForm: _invoiceForm,
                                    invoiceLoading: _invoiceLoading,
                                    changeOther: _changeOther,
                                    // Change mode: draft only. Normal sale:
                                    // tear down any prior OTHER then place.
                                    onInvoice: _change != null
                                        ? () => setState(
                                            () => _changeOther = 'invoice')
                                        : _invoiceActive
                                            ? null
                                            : () {
                                                if (_saleGuard()) return;
                                                _cancelActiveOther();
                                                _startInvoice();
                                              },
                                    onSubmitInvoice: _submitInvoice,
                                    standaloneActive: _standaloneActive,
                                    standaloneTotal: grandTotal,
                                    standaloneApprovalCode:
                                        _standaloneApprovalCode,
                                    standaloneLoading: _standaloneLoading,
                                    onStandalone: _change != null
                                        ? () => setState(
                                            () => _changeOther = 'standalone')
                                        : _standaloneActive
                                            ? null
                                            : () {
                                                if (_saleGuard()) return;
                                                _cancelActiveOther();
                                                _startStandalone();
                                              },
                                    onSubmitStandalone: _submitStandalone,
                                    onCancelActiveOther: _onCancelActiveOther,
                                    showSplitOptions: _change == null,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        // The sticky bar: one CTA for whichever pane is up.
                        ValueListenableBuilder<PosSplitByItemState?>(
                          valueListenable: _splitByItem,
                          builder: (context, sbiState, _) {
                            return ValueListenableBuilder<PosSplitState?>(
                              valueListenable: _split,
                              builder: (context, splitState, _) {
                                // Frame 03 confirms an invoice through this
                                // bar, not a button inside the pane.
                                if (_invoiceActive) {
                                  return ValueListenableBuilder<String>(
                                    valueListenable: _invoiceForm.companyName,
                                    builder: (context, _, __) => PosPayPillBar(
                                      label: 'Confirm Payment',
                                      loading: _invoiceLoading,
                                      onConfirm: _invoiceForm.isValid &&
                                              !_invoiceLoading
                                          ? _submitInvoice
                                          : null,
                                    ),
                                  );
                                }
                                // Frame 04: same bar for stand-alone.
                                if (_standaloneActive) {
                                  return PosPayPillBar(
                                    label: 'Confirm Payment',
                                    loading: _standaloneLoading,
                                    onConfirm: _standaloneLoading
                                        ? null
                                        : _submitStandalone,
                                  );
                                }
                                // Frame 13: the chooser commits from this bar.
                                if (_splitChooser) {
                                  return PosPayPillBar(
                                    label: 'Continue',
                                    onConfirm: _continueSplitChooser,
                                  );
                                }
                                // A split payment that is taken but not saved:
                                // the bar saves it again, never re-charges.
                                final _TakenPayment? taken = _taken;
                                if (taken != null &&
                                    (splitState != null || sbiState != null)) {
                                  return PosPayPillBar(
                                    label: 'Save Payment ${taken.seq} · '
                                        '${PosHomeSpec.formatPrice(taken.amount, padZero: false)}',
                                    loading: _splitBusy,
                                    onConfirm: _splitBusy ? null : _saveTaken,
                                  );
                                }
                                // Frames 05 / 09–12 ("Start Payment N") and
                                // 19 ("Start Payment N · € X"): the split
                                // pane is confirmed from this bar, live only
                                // for an amount the backend will take.
                                if (splitState != null) {
                                  final PosSplitState view =
                                      splitState.withLiveTotal(grandTotal);
                                  final int? applied = _splitAppliedCents();
                                  final String amount = applied == null
                                      ? ''
                                      : ' · ${PosHomeSpec.formatPrice(posCentsToMoney(applied, decimals: _splitEntry.decimals), padZero: false)}';
                                  return PosPayPillBar(
                                    label: applied == null &&
                                            _splitCardOver(view)
                                        ? 'Enter at most '
                                            '${PosHomeSpec.formatPrice(view.remaining, padZero: false)}'
                                        : 'Start Payment ${view.nextSequence}'
                                            '${_splitCustom ? amount : ''}',
                                    loading: _splitBusy,
                                    onConfirm: _splitBusy || applied == null
                                        ? null
                                        : _takeSplitPayment,
                                  );
                                }
                                // Frames 14 / 16 / 20 / 21: "Start Payment N
                                // · € X" from this bar, live with the
                                // selection; frame 15: "Confirm Payment · €
                                // X" once the cash tender covers it.
                                if (sbiState != null) {
                                  final List<PosSplitByItemLineItem> items =
                                      _buildLineItemsFromCart(lines);
                                  return ValueListenableBuilder<
                                      PosSplitByItemGroupBuilder>(
                                    valueListenable: _splitByItemGroups,
                                    builder: (context, builder, _) {
                                      final PosSplitByItemQuote quote =
                                          _sbiQuote(items);
                                      final String due =
                                          PosHomeSpec.formatPrice(
                                              _sbiQuoteAmount(items),
                                              padZero: false);
                                      final PosCashEntry? tender = _sbiTender;
                                      if (tender != null) {
                                        final bool covers = quote.payable &&
                                            tender.cents >= quote.cents;
                                        return PosPayPillBar(
                                          label: 'Confirm Payment · $due',
                                          loading: _splitBusy,
                                          onConfirm: covers && !_splitBusy
                                              ? _takeSbiPayment
                                              : null,
                                        );
                                      }
                                      final bool cash = _splitByItemMethod ==
                                          PosPaymentMethod.cash;
                                      return PosPayPillBar(
                                        label:
                                            'Start Payment ${sbiState.nextPaymentNumber}'
                                            ' · $due',
                                        loading: _splitBusy,
                                        onConfirm: quote.payable && !_splitBusy
                                            ? () => cash
                                                ? _startSbiCash(items)
                                                : _takeSbiPayment()
                                            : null,
                                      );
                                    },
                                  );
                                }
                                if (_change != null) {
                                  return PosPayPillBar(
                                    label: 'Confirm change',
                                    loading: _confirming,
                                    onConfirm: _confirming
                                        ? null
                                        : _confirmMethodChange,
                                  );
                                }
                                return PosPayPillBar(
                                  label: 'Confirm Payment',
                                  loading: _confirming,
                                  onConfirm: hasItems &&
                                          !_confirming &&
                                          (!_isCash || _cashCovers(grandTotal))
                                      ? () => _confirm(grandTotal, tip)
                                      : null,
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        ),
      ),
      ),
    );

    // A system / browser back can't leave while a payment is in flight (the
    // terminal could charge a card for an order nobody placed), and during a
    // committed split it goes through the same check as the back button.
    final bool inFlight = _isWaitingForTerminal ||
        _splitBusy ||
        _confirming ||
        _invoiceLoading ||
        _standaloneLoading;
    return PopScope(
      canPop: !_saleLocked && !inFlight,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || inFlight) return;
        _back();
      },
      child: screen,
    );
  }
}

/// `content-area` (1641:2763) — the receipt beside the payment card.
///
/// Two structures rather than one shrinking layout: side by side while there
/// is room for both panes, and stacked in a single scroll below that. A
/// counter terminal is landscape, but the same build has to stay usable on a
/// staff tablet and in a half-width browser window.
class _Content extends StatelessWidget {
  final List<CartModel?> lines;
  final bool hasItems;
  final String? imageBaseUrl;
  final String? dealImageBaseUrl;
  final String? orderNumber;
  final TextEditingController customerNameController;
  final TextEditingController tableController;
  final PosPaymentMethod method;

  /// Settings → Payments gates which tender cards are offered. A method that
  /// is switched off is not rendered at all, rather than shown disabled — the
  /// operator has no use for a tender the venue does not take.
  final bool cashEnabled;
  final bool cardEnabled;
  final double subtotal;
  final double discount;
  /// Grand total (payable + tip).
  final double total;

  /// Tip applied; shown on the summary tip row.
  final double tip;

  /// Opens the tip modal. Null when tipping is disabled → row inert.
  final VoidCallback? onTip;

  /// The split panes' tip row: [onTip] until the first split payment places
  /// the order, null after.
  final VoidCallback? onSplitTip;
  final ValueChanged<PosPaymentMethod> onSelectMethod;

  /// The OTHER method picked while changing a receipt's method. Lights its
  /// tile only; it does not start that method's order flow.
  final String? changeOther;
  final PosCashEntry cash;
  final PosCashDenomination? denomination;
  final int totalCents;
  final ValueChanged<String> onCashKey;
  final ValueChanged<String> onCashTyped;
  final VoidCallback onCashBackspace;
  final VoidCallback onCashClear;
  final ValueChanged<PosCashDenomination> onDenomination;
  final ValueChanged<int> onIncrement;
  final ValueChanged<int> onDecrement;
  final ValueChanged<BuildContext> onOptions;

  // Split-by-payment (Family 2) parameters.
  final bool inSplit;
  final PosSplitState? splitState;
  final PosPaymentMethod splitMethod;
  final PosCashEntry splitEntry;
  final ValueChanged<PosPaymentMethod> onSplitMethod;
  final ValueChanged<String> onSplitKey;
  final VoidCallback onSplitBackspace;
  final ValueChanged<PosCashDenomination> onSplitDenomination;
  final PosCashDenomination? splitDenomination;
  final VoidCallback? onSplitByPayment;

  /// A split payment is taken but not saved: the split panes' input is inert.
  final bool splitInputLocked;

  /// The split was started from the chooser's Custom amount (frame 19).
  final bool splitCustom;

  /// A paid row's Refund pill (shown only for a refundable payment).
  final ValueChanged<PosSplitPayment>? onRefundPayment;
  final ValueChanged<PosSplitByItemGroup>? onRefundGroup;

  /// Frame 13's chooser is on screen, with [splitChoice] picked.
  final bool splitChooser;
  final PosSplitChoice splitChoice;
  final ValueChanged<PosSplitChoice> onSplitChoice;

  // Split-by-item (Family 3) parameters.
  final bool inSplitByItem;
  final PosSplitByItemState? splitByItemState;
  final PosSplitByItemGroupsBuilder splitByItemGroups;
  final PosPaymentMethod splitByItemMethod;
  final List<PosSplitByItemLineItem> splitByItemLineItems;
  final VoidCallback? onSplitByItem;
  final ValueChanged<int> onToggleSplitItem;
  final ValueChanged<PosPaymentMethod> onSplitByItemMethod;
  final double Function(PosSplitByItemGroupBuilder pick) sbiAmountOf;

  /// Frame 15: the cash tender for the picked items; null = item picker.
  final PosCashEntry? sbiTender;
  final PosCashDenomination? sbiDenomination;

  /// What the current pick charges; null when it cannot be paid.
  final double? sbiCharge;
  final List<String> sbiPickedNames;
  final ValueChanged<String> onSbiKey;
  final VoidCallback onSbiBackspace;
  final void Function(PosCashDenomination d, int dueCents) onSbiDenomination;
  final ValueChanged<PosPaymentMethod> onSbiMethod;

  // Invoice (Family 4) parameters.
  final bool invoiceActive;
  final PosInvoiceFormState invoiceForm;
  final bool invoiceLoading;
  final VoidCallback? onInvoice;
  final VoidCallback onSubmitInvoice;

  // Stand-alone terminal (Family 5) parameters.
  final bool standaloneActive;
  final double standaloneTotal;
  final ValueNotifier<String> standaloneApprovalCode;
  final bool standaloneLoading;
  final VoidCallback? onStandalone;
  final VoidCallback onSubmitStandalone;

  /// Cancels whichever OTHER mode is currently active (deselects on re-tap).
  final VoidCallback? onCancelActiveOther;

  /// False in receipt change-method mode (splits are not a display override).
  final bool showSplitOptions;

  const _Content({
    required this.lines,
    required this.hasItems,
    required this.imageBaseUrl,
    required this.dealImageBaseUrl,
    required this.orderNumber,
    required this.customerNameController,
    required this.tableController,
    required this.method,
    required this.cashEnabled,
    required this.cardEnabled,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.tip,
    required this.onTip,
    this.onSplitTip,
    required this.onSelectMethod,
    required this.cash,
    required this.denomination,
    required this.totalCents,
    required this.onCashKey,
    required this.onCashTyped,
    required this.onCashBackspace,
    required this.onCashClear,
    required this.onDenomination,
    required this.onIncrement,
    required this.onDecrement,
    required this.onOptions,
    required this.inSplit,
    required this.splitState,
    required this.splitMethod,
    required this.splitEntry,
    required this.onSplitMethod,
    required this.onSplitKey,
    required this.onSplitBackspace,
    required this.onSplitDenomination,
    required this.splitDenomination,
    required this.onSplitByPayment,
    this.splitInputLocked = false,
    required this.splitCustom,
    this.onRefundPayment,
    this.onRefundGroup,
    required this.splitChooser,
    required this.splitChoice,
    required this.onSplitChoice,
    required this.inSplitByItem,
    required this.splitByItemState,
    required this.splitByItemGroups,
    required this.splitByItemMethod,
    required this.splitByItemLineItems,
    required this.onSplitByItem,
    required this.onToggleSplitItem,
    required this.onSplitByItemMethod,
    required this.sbiAmountOf,
    required this.sbiTender,
    required this.sbiDenomination,
    required this.sbiCharge,
    required this.sbiPickedNames,
    required this.onSbiKey,
    required this.onSbiBackspace,
    required this.onSbiDenomination,
    required this.onSbiMethod,
    required this.invoiceActive,
    this.changeOther,
    required this.invoiceForm,
    required this.invoiceLoading,
    required this.onInvoice,
    required this.onSubmitInvoice,
    required this.standaloneActive,
    required this.standaloneTotal,
    required this.standaloneApprovalCode,
    required this.standaloneLoading,
    required this.onStandalone,
    required this.onSubmitStandalone,
    this.onCancelActiveOther,
    this.showSplitOptions = true,
  });

  /// Receipt sidebar pane — node 1915:9353.
  Widget _receiptCard({required bool fill}) => PosPayReceiptCard(
        fill: fill,
        lines: lines,
        hasItems: hasItems,
        imageBaseUrl: imageBaseUrl,
        dealImageBaseUrl: dealImageBaseUrl,
        orderNumber: orderNumber,
        customerNameController: customerNameController,
        tableController: tableController,
        onIncrement: onIncrement,
        onDecrement: onDecrement,
        onOptions: onOptions,
      );

  /// Payment-method column — node 1915:9420. In a window shorter than the
  /// frame it scales down to fit its pane rather than scrolling — every
  /// method stays in view.
  Widget _methodPane({required bool fill}) {
    final Widget selector = PosPaymentMethodSelector(
      method: method,
      cashEnabled: cashEnabled,
      cardEnabled: cardEnabled,
      onSelectMethod: onSelectMethod,
      onSplitByPayment: onSplitByPayment,
      // A custom-amount split is saved as split by payment, but the operator
      // reached it through "Split by item" (frames 13 / 19).
      splitActive: inSplit && !splitCustom,
      onSplitByItem: onSplitByItem,
      splitByItemActive:
          inSplitByItem || splitChooser || (inSplit && splitCustom),
      onInvoice: onInvoice,
      invoiceActive: invoiceActive || changeOther == 'invoice',
      onStandalone: onStandalone,
      standaloneActive: standaloneActive || changeOther == 'standalone',
      onCancelActiveOther: onCancelActiveOther,
      showSplitOptions: showSplitOptions,
    );
    return PosPayCard(
      padding: const EdgeInsets.all(PosPaymentSpec.v2MethodCardPadding),
      child: fill ? PosFitColumn(children: [selector]) : selector,
    );
  }

  /// Payment-summary column. Shows stand-alone panel, invoice form,
  /// split-by-item panel, split-by-payment panel, or the normal Card/Cash
  /// panel depending on the active mode.
  Widget _summaryPane({required bool fill}) {
    // Receipt change-method mode: the drafted OTHER method shows the SAME
    // shared panel the order flow uses, in changeMode (no placement CTA/form).
    if (changeOther == 'standalone') {
      // Frame 04 draws the stand-alone pane on the #F0EBD8 1.5px card.
      return PosPayCard(
        child: PosStandalonePanel(
          grandTotal: standaloneTotal,
          approvalCode: standaloneApprovalCode,
          loading: false,
          onConfirm: () {},
          changeMode: true,
        ),
      );
    }
    if (changeOther == 'invoice') {
      // Frame 03 draws the invoice pane on the #F0EBD8 1.5px card.
      return PosPayCard(
        child: PosInvoicePanel(
          grandTotal: total,
          form: invoiceForm,
          loading: false,
          onSubmit: () {},
          changeMode: true,
        ),
      );
    }
    // Stand-alone mode (Family 5): numbered instructions + approval code.
    if (standaloneActive) {
      return PosPayCard(
        child: PosStandalonePanel(
          grandTotal: standaloneTotal,
          approvalCode: standaloneApprovalCode,
          loading: standaloneLoading,
          onConfirm: onSubmitStandalone,
        ),
      );
    }

    // Invoice mode (Family 4): company name / VAT / email form.
    if (invoiceActive) {
      return PosPayCard(
        child: PosInvoicePanel(
          grandTotal: total,
          form: invoiceForm,
          loading: invoiceLoading,
          onSubmit: onSubmitInvoice,
        ),
      );
    }

    // Frame 13: By item or Custom amount, before anything is placed.
    if (splitChooser) {
      return PosPayCard(
        borderColor: PosSplitSummaryPanel.borderColor,
        borderWidth: PosSplitSummaryPanel.borderWidth,
        child: PosSplitChooserPanel(
          grandTotal: total,
          choice: splitChoice,
          onChoice: onSplitChoice,
          fill: fill,
        ),
      );
    }

    // Split-by-item mode (Family 3): item checklist + Card/Cash + Start Payment.
    if (inSplitByItem && splitByItemState != null) {
      final PosSplitByItemState sbi = splitByItemState!;
      final PosCashEntry? tender = sbiTender;
      final double? charge = sbiCharge;
      // Frame 15: the cash tender for the picked items.
      if (tender != null && charge != null) {
        final int due = posMoneyToCents(charge, decimals: tender.decimals);
        return PosPayCard(
          borderColor: PosSplitSummaryPanel.borderColor,
          borderWidth: PosSplitSummaryPanel.borderWidth,
          child: PosSplitSummaryPanel(
            grandTotal: sbi.grandTotal,
            remaining: sbi.fullyPaid ? 0 : sbi.remaining,
            paid: [
              for (final PosSplitByItemGroup g in sbi.paidGroups)
                PosSplitPaidRowData(
                  label: 'Payment ${g.seq}',
                  subtitle: g.paidWith == 'card'
                      ? 'Card payment successful'
                      : 'Cash payment successful',
                  amount: g.paidAmount,
                  onRefund: onRefundGroup != null && g.refundable
                      ? () => onRefundGroup!(g)
                      : null,
                ),
            ],
            subtitle: 'By item · ${sbiPickedNames.join(', ')}',
            entryLabel: 'PAYMENT ${sbi.nextPaymentNumber} · AMOUNT DUE '
                '${PosHomeSpec.formatPrice(charge, padZero: false)}',
            changeBaseCents: due,
            tipRowHeight: PosPaymentSpec.v2SplitTipRowHeight,
            entry: tender,
            splitMethod: PosPaymentMethod.cash,
            onSplitMethod: onSbiMethod,
            onKey: onSbiKey,
            onBackspace: onSbiBackspace,
            onDenomination: (d) => onSbiDenomination(d, due),
            selectedDenomination: sbiDenomination,
            tip: tip,
            onTipTap: onSplitTip,
            locked: splitInputLocked,
            fill: fill,
          ),
        );
      }
      return PosPayCard(
        borderColor: PosSplitSummaryPanel.borderColor,
        borderWidth: PosSplitSummaryPanel.borderWidth,
        child: PosSplitByItemPanel(
          groups: sbi.groups,
          groupSeq: sbi.nextPaymentNumber,
          grandTotal: sbi.grandTotal,
          remaining: sbi.remaining,
          lineItems: splitByItemLineItems,
          groupBuilder: splitByItemGroups,
          paymentMethod: splitByItemMethod,
          onToggleItem: onToggleSplitItem,
          onPaymentMethodChanged: onSplitByItemMethod,
          tip: tip,
          onAddTip: onSplitTip,
          amountOf: sbiAmountOf,
          onRefund: onRefundGroup,
          locked: splitInputLocked,
          fill: fill,
        ),
      );
    }

    // In split mode: show the split entry panel (node 1915:10034).
    if (inSplit && splitState != null) {
      return PosPayCard(
        borderColor: PosSplitSummaryPanel.borderColor,
        borderWidth: PosSplitSummaryPanel.borderWidth,
        child: PosSplitSummaryPanel.forPayments(
          state: splitState!,
          entry: splitEntry,
          splitMethod: splitMethod,
          onSplitMethod: onSplitMethod,
          onKey: onSplitKey,
          onBackspace: onSplitBackspace,
          onDenomination: onSplitDenomination,
          selectedDenomination: splitDenomination,
          tip: tip,
          onTipTap: onSplitTip,
          locked: splitInputLocked,
          fill: fill,
          customAmount: splitCustom,
          onRefund: onRefundPayment,
        ),
      );
    }

    final Widget content = method == PosPaymentMethod.cash
        ? PosPayCashSummaryPanel(
            total: total,
            entry: cash,
            totalCents: totalCents,
            selectedDenomination: denomination,
            onDenomination: onDenomination,
            onKey: onCashKey,
            onTyped: onCashTyped,
            onBackspace: onCashBackspace,
            onClear: onCashClear,
            tip: tip,
            onTipTap: onTip,
            fill: fill,
          )
        : PosPaySummaryPanel(total: total, tip: tip, onTipTap: onTip);
    // fill=true: cash panel scales itself via LayoutBuilder; card panel is
    // short enough to fit — no SingleChildScrollView needed in either case.
    return PosPayCard(
      summaryBorder: true,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PosPayThreePane(
      receipt: (fill) => _receiptCard(fill: fill),
      method: (fill) => _methodPane(fill: fill),
      summary: (fill) => _summaryPane(fill: fill),
    );
  }
}

/// A split payment whose money is in — the card approved, or the cash in the
/// drawer — but which the backend has not recorded yet. The screen holds it
/// until it is saved, so a retry only re-sends it.
@immutable
class _TakenPayment {
  /// The payment number it is saved as ("Payment 2").
  final int seq;

  /// `card` | `cash`.
  final String method;
  final double amount;

  /// The terminal's reference for a card payment.
  final String? transactionReference;

  /// Split by item: the lines this guest paid for.
  final List<int> itemIds;

  const _TakenPayment({
    required this.seq,
    required this.method,
    required this.amount,
    this.transactionReference,
    this.itemIds = const [],
  });
}
