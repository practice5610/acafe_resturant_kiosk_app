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

  /// True while any OTHER-mode order placement (split, invoice, stand-alone) is
  /// in flight. Prevents the PRIMARY radio from blinking selected between the
  /// cancel of the old OTHER and the activation of the new one.
  bool _startingOther = false;

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

  /// Split-by-payment mode (Family 2): when non-null, the order has been
  /// placed upfront and is collecting splits. null = normal single-tender sale.
  /// Held in a ValueNotifier so the split UI rebuilds surgically (not root
  /// setState) and the split state stays in sync across retry/success.
  late final PosSplitSession _split = PosSplitSession();

  /// Current split method choice (Card/Cash) — isolated from the main
  /// [PosPaymentMethod] which is for normal single-tender sales.
  PosPaymentMethod _splitMethod = PosPaymentMethod.card;

  /// Amount keyed in for the current split.
  PosCashEntry _splitEntry = const PosCashEntry();

  /// The denomination chip behind [_splitEntry] on a cash split (frame 10);
  /// cleared by any keypad entry, like [_denomination] on a plain cash sale.
  PosCashDenomination? _splitDenomination;

  /// True while a split payment (charge + record) is in flight.
  bool _splittingPayment = false;

  /// The idempotency key for the current split's card charge. Stable across
  /// retries of the same split attempt to prevent double-charge.
  String? _splitCardIdempotencyKey;

  // ── Split-by-item (Family 3) ─────────────────────────────────────────────
  /// Non-null while the operator is collecting item groups for this order.
  late final PosSplitByItemSession _splitByItem = PosSplitByItemSession();

  /// Tracks which items are selected for the current payment group.
  late final PosSplitByItemGroupsBuilder _splitByItemGroups =
      PosSplitByItemGroupsBuilder(groupSeq: 1);

  /// Card or Cash for the current split-by-item group payment.
  PosPaymentMethod _splitByItemMethod = PosPaymentMethod.card;

  /// True while a split-by-item group payment is in flight.
  bool _splitByItemLoading = false;

  /// Card idempotency key for the current group. Stable across retries.
  String? _splitByItemCardKey;

  /// Frame 13: "Split by item" opens a chooser — By item or Custom amount —
  /// before any order is placed. True while it is on screen.
  bool _splitChooser = false;

  /// The chooser's pick; By item is the frame's default.
  PosSplitChoice _splitChoice = PosSplitChoice.byItem;

  /// The split-by-payment session was started from the chooser's "Custom
  /// amount" (frame 19): same saving path, guest wording, and the OTHER
  /// group shows "Split by item" as the active row.
  bool _splitCustom = false;

  /// Frame 15: the cash step of a split-by-item payment. Non-null while the
  /// operator keys the tender for the picked items; the payment itself is
  /// still recorded at the group's amount.
  PosCashEntry? _sbiTender;
  PosCashDenomination? _sbiDenomination;
  // ─────────────────────────────────────────────────────────────────────────

  // ── Invoice (Family 4) ───────────────────────────────────────────────────
  /// True while the Invoice form is open in the right pane.
  bool _invoiceActive = false;

  /// Mutable form state (company, VAT, email, sendByEmail). Disposed with the
  /// screen so ValueNotifiers are cleaned up when the screen exits.
  final PosInvoiceFormState _invoiceForm = PosInvoiceFormState();

  /// True while the POST invoice/create call is in flight.
  bool _invoiceLoading = false;

  /// The order_id placed upfront (same flow as split families), stored so the
  /// invoice POST can reference it.
  int _invoiceOrderId = 0;
  // ─────────────────────────────────────────────────────────────────────────

  // ── Stand-alone terminal (Family 5) ──────────────────────────────────────
  /// True while the stand-alone instructions pane is open.
  bool _standaloneActive = false;

  /// Optional approval code from the terminal slip. Held in a ValueNotifier
  /// so only the text field rebuilds on typing — no root setState.
  final ValueNotifier<String> _standaloneApprovalCode =
      ValueNotifier<String>('');

  /// True while the POST standalone-payment/record call is in flight.
  bool _standaloneLoading = false;

  /// The order_id placed upfront before showing the instructions pane.
  int _standaloneOrderId = 0;

  /// Grand total captured at order placement for the receipt dialog subtitle.
  double _standaloneGrandTotal = 0;
  // ─────────────────────────────────────────────────────────────────────────

  /// Grand total captured at invoice order placement for receipt dialog.
  double _invoiceGrandTotal = 0;

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

  void _back() {
    // A method change came from Receipts; leaving goes back there.
    if (_change != null || _changedTo != null) {
      context.go(PosRoutes.receipts);
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

  /// Enters split-by-payment mode: places the order upfront at [grandTotal],
  /// then initializes split session and enters split entry UI. Async because
  /// order placement is async.
  ///
  /// [custom] = started from the split chooser's "Custom amount" (frame 19):
  /// the same split-payment saving path, worded per guest.
  Future<void> _startSplit(double grandTotal, {bool custom = false}) async {
    if (_split.active) return;

    // Place the order upfront via the normal flow (grand total, cash_on_delivery,
    // is_partial=0). Kitchen starts immediately. Then we collect splits.
    final CartProvider cart = context.read<CartProvider>();
    final CouponProvider coupon = context.read<CouponProvider>();
    final kioskSession = kiosk.KioskSession.instance;

    final double payable = kioskPayableTotal(cart.cartList, coupon.discount ?? 0);
    final double tip = _tip.value;
    final double amount = double.parse((payable + tip).toStringAsFixed(2));

    kioskSession.customerName = _sale.customerName.text.trim();

    if (!context.mounted) return;

    setState(() {
      _confirming = true;
      _startingOther = true;
      _phase = null;
      _cancelling = false;
      _declined = false;
    });

    try {
      final KioskPlaceResult placed = await posPlaceOrder(
        context,
        amount: amount,
        tipAmountOverride: tip > 0 ? tip : null,
      );

      if (!mounted) return;

      setState(() { _confirming = false; _startingOther = false; });

      if (!placed.success) {
        showCustomSnackBarHelper(
          placed.message ?? 'Order placement failed',
          isError: true,
        );
        return;
      }

      // Order placed. Initialize split session with the order_id.
      setState(() {
        _splitMethod = PosPaymentMethod.card;
        _splitEntry = _splitEntry.withCents(0);
        _splitDenomination = null;
        _splitCustom = custom;
        _splitChooser = false;
      });
      _split.start(
        orderId: int.tryParse((placed.orderId ?? '').trim()) ?? 0,
        deviceId: context.read<KioskAuthProvider>().deviceId ?? 0,
        grandTotal: amount,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _confirming = false; _startingOther = false; });
      showCustomSnackBarHelper(
        'Order placement error: $e',
        isError: true,
      );
    }
  }

  void _selectMethod(PosPaymentMethod method, double total) {
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

  /// Split keypad entry callback.
  void _onSplitKey(String token) {
    setState(() {
      _splitEntry = _splitEntry.key(token);
      _splitDenomination = null;
    });
  }

  /// Cash split denomination chip: a note value, or Exact = what is still
  /// owed on the order.
  void _onSplitDenomination(PosCashDenomination denomination) {
    final PosSplitState? state = _split.value;
    if (state == null) return;
    setState(() {
      _splitEntry = _splitEntry.withCents(denomination.exact
          ? posMoneyToCents(state.remaining, decimals: _splitEntry.decimals)
          : denomination.cents!);
      _splitDenomination = denomination;
    });
  }

  /// Split keypad backspace callback.
  void _onSplitBackspace() {
    setState(() {
      _splitEntry = _splitEntry.backspace();
      _splitDenomination = null;
    });
  }

  /// Split keypad clear callback.
  void _onSplitClear() {
    setState(() {
      _splitEntry = _splitEntry.clear();
      _splitDenomination = null;
    });
  }

  /// Split method toggle (Card ↔ Cash).
  void _onSplitMethod(PosPaymentMethod method) {
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
    final PosSplitState? state = _split.value;
    if (state == null || _splitEntry.cents <= 0) return null;
    final int remaining =
        posMoneyToCents(state.remaining, decimals: _splitEntry.decimals);
    if (remaining <= 0) return null;
    if (_splitMethod == PosPaymentMethod.cash) {
      return _splitEntry.cents < remaining ? _splitEntry.cents : remaining;
    }
    return _splitEntry.cents > remaining ? null : _splitEntry.cents;
  }

  /// Process a split: charge the amount (card or cash), then POST record.
  /// If success: update PosSplitSession, loop back to entry with decremented
  /// remaining. If decline: show retry option. If fully_paid: show final success.
  Future<void> _recordSplit() async {
    if (_splittingPayment) return;
    if (_split.value == null) return;

    final PosSplitState state = _split.value!;
    final int? amountCents = _splitAppliedCents();
    if (amountCents == null) return;

    final double amountEur = posCentsToMoney(amountCents, decimals: _splitEntry.decimals);
    final String reference = 'pos-split-${state.orderId}-${state.nextSequence}';

    setState(() {
      _splittingPayment = true;
      _phase = null;
    });

    try {
      String? transactionReference;

      // Card payment: use KioskPaymentService.pay with idempotency key.
      if (_splitMethod == PosPaymentMethod.card) {
        _splitCardIdempotencyKey ??= 'pos-split-card-${DateTime.now().millisecondsSinceEpoch}';
        if (!context.mounted) return;
        setState(() => _phase = PosCheckoutPhase.awaitingTerminal);

        final KioskPaymentResult payment = await di.sl<KioskPaymentService>().pay(
          amount: amountEur,
          idempotencyKey: _splitCardIdempotencyKey!,
        );

        if (!mounted) return;
        setState(() => _phase = null);

        switch (payment.status) {
          case KioskPaymentStatus.paid:
            transactionReference = payment.paymentRef;
          case KioskPaymentStatus.failed:
            // Show decline card with retry.
            _showSplitDeclineCard(amountEur, state.nextSequence);
            setState(() => _splittingPayment = false);
            return;
          case KioskPaymentStatus.canceled:
            setState(() => _splittingPayment = false);
            return;
        }
      }
      // Cash: no charge, just record the tendered amount.

      // POST record to backend.
      if (!context.mounted) return;
      setState(() => _phase = PosCheckoutPhase.placingOrder);

      final PosSplitRepo repo = di.sl<PosSplitRepo>();
      final ApiResponseModel response = await repo.record(
        orderId: state.orderId,
        paidWith: _splitMethod == PosPaymentMethod.card ? 'card' : 'cash',
        paidAmount: amountEur,
        deviceId: state.deviceId,
        reference: reference,
        transactionReference: transactionReference,
      );

      if (!mounted) return;
      setState(() => _phase = null);

      if (!response.isSuccess) {
        showCustomSnackBarHelper(
          'Split payment failed: ${response.error}',
          isError: true,
        );
        setState(() => _splittingPayment = false);
        return;
      }

      // Update split state from response.
      final Map<String, dynamic> json =
          Map<String, dynamic>.from(response.response.data as Map);
      final PosSplitState updatedState = PosSplitState.fromJson(
        json,
        deviceId: state.deviceId,
      );
      _split.update(updatedState);

      // Reset entry for next split.
      setState(() {
        _splitEntry = _splitEntry.withCents(0);
        _splittingPayment = false;
        _splitCardIdempotencyKey = null; // Fresh key per split.
      });

      // Show success card.
      _showSplitSuccessCard(updatedState);
    } catch (e) {
      if (!mounted) return;
      setState(() => _splittingPayment = false);
      showCustomSnackBarHelper('Split error: $e', isError: true);
    }
  }

  /// Show decline card for a failed split; user can retry with same reference.
  void _showSplitDeclineCard(double amount, int splitNum) {
    showGeneralDialog(
      context: context,
      // Frame 07: the card on the page background, nothing behind it.
      barrierColor: PosHomeSpec.pageBg,
      pageBuilder: (context, anim, secAnim) => PosPayTextScope(
        child: Material(
          type: MaterialType.transparency,
          child: PosDeclinedCard(
          amountDue: amount,
          retrying: _splittingPayment,
          onCancel:
              _splittingPayment ? null : () => Navigator.pop(context),
          onTryAgain: _splittingPayment ? null : () {
            Navigator.pop(context);
            _recordSplit();
          },
          ),
        ),
      ),
    );
  }

  /// Shows a success state — Figma `success-card` (1915:9317 / 12227) on the
  /// page background, as the frames draw it (nothing behind the card).
  void _showSuccessCard(Widget Function(BuildContext dialogContext) card) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: PosHomeSpec.pageBg,
      pageBuilder: (dialogContext, anim, secAnim) => PosPayTextScope(
        child: Material(
          type: MaterialType.transparency,
          child: card(dialogContext),
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
      return PosPaymentSuccessCard(
        title: 'Order Paid',
        amount: state.grandTotal,
        amountLabel: 'TOTAL PAID',
        secondaryLabel: 'Receipt',
        onSecondary: () => _showReceiptDialog(
          orderId: state.orderId,
          total: state.grandTotal,
          onAfterSend: () {
            Navigator.pop(dialogContext);
            _completeSplit();
          },
        ),
        buttonLabel: 'Next order',
        onContinue: () {
          Navigator.pop(dialogContext);
          _completeSplit();
        },
      );
    });
  }

  /// Final split complete: clear cart + session, navigate home.
  void _completeSplit() {
    final CartProvider cart = context.read<CartProvider>();
    final CouponProvider coupon = context.read<CouponProvider>();

    endKioskCustomerSession(
      context.mounted ? context : null,
      cart: cart,
      coupon: coupon,
    );
    _sale.reset();
    _split.clear();

    if (context.mounted) {
      context.go(PosRoutes.home);
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

  /// "Split by item" in the OTHER group: show the chooser. Nothing is placed
  /// until Continue.
  void _openSplitChooser() {
    _cancelActiveOther();
    setState(() {
      _splitChooser = true;
      _splitChoice = PosSplitChoice.byItem;
    });
  }

  /// Continue on the chooser: By item → the item picker (frame 14), Custom
  /// amount → the per-guest amount entry (frame 19). Both place the order
  /// first, exactly as before; the chooser stays up if that fails.
  Future<void> _continueSplitChooser(double grandTotal) async {
    if (_confirming) return;
    if (_splitChoice == PosSplitChoice.byItem) {
      await _startSplitByItem(grandTotal);
    } else {
      await _startSplit(grandTotal, custom: true);
    }
  }

  // ── Split by item → cash (frame 15) ──────────────────────────────────────

  /// "Start Payment N" on Cash: open the tender step for the picked items.
  /// Nothing is sent until the tender covers the amount due.
  void _startSbiCash(List<PosSplitByItemLineItem> items) {
    final double? charge = _sbiCharge(items);
    if (charge == null) return;
    final int due = posMoneyToCents(charge, decimals: _cash.decimals);
    setState(() {
      // Exact, like a plain cash sale (see _selectMethod).
      _sbiTender = PosCashEntry(decimals: _cash.decimals).withCents(due);
      _sbiDenomination = const PosCashDenomination.exact();
    });
  }

  void _onSbiKey(String token) {
    final PosCashEntry? tender = _sbiTender;
    if (tender == null) return;
    setState(() {
      _sbiTender = tender.key(token);
      _sbiDenomination = null;
    });
  }

  void _onSbiBackspace() {
    final PosCashEntry? tender = _sbiTender;
    if (tender == null) return;
    setState(() {
      _sbiTender = tender.backspace();
      _sbiDenomination = null;
    });
  }

  void _onSbiDenomination(PosCashDenomination d, int dueCents) {
    final PosCashEntry? tender = _sbiTender;
    if (tender == null) return;
    setState(() {
      _sbiTender = tender.withCents(d.exact ? dueCents : d.cents!);
      _sbiDenomination = d;
    });
  }

  /// The segmented control on frame 15: Card leaves the tender step for the
  /// item picker, on Card.
  void _onSbiMethod(PosPaymentMethod method) {
    if (method == PosPaymentMethod.cash) return;
    setState(() {
      _sbiTender = null;
      _sbiDenomination = null;
      _splitByItemMethod = PosPaymentMethod.card;
    });
  }

  // ── Split-by-item (Family 3) ─────────────────────────────────────────────

  /// Entry point: operator taps "Split by item" in the OTHER row.
  /// Places the order upfront then switches UI to item-selection mode.
  Future<void> _startSplitByItem(double amount) async {
    if (_splitByItem.active || _confirming) return;

    final kioskSession = kiosk.KioskSession.instance;
    kioskSession.customerName = _sale.customerName.text.trim();
    if (!context.mounted) return;

    setState(() {
      _confirming = true;
      _startingOther = true;
      _phase = null;
      _cancelling = false;
      _declined = false;
    });

    try {
      final KioskPlaceResult placed = await posPlaceOrder(
        context,
        amount: amount,
        tipAmountOverride: _tip.value > 0 ? _tip.value : null,
      );
      if (!mounted) return;
      setState(() { _confirming = false; _startingOther = false; });

      if (!placed.success) {
        showCustomSnackBarHelper(
          placed.message ?? 'Order placement failed',
          isError: true,
        );
        return;
      }

      setState(() {
        _splitChooser = false;
        _splitByItemMethod = PosPaymentMethod.card;
        _sbiTender = null;
        _sbiDenomination = null;
      });
      _splitByItemGroups.nextGroup(1);
      _splitByItem.start(
        orderId: int.tryParse((placed.orderId ?? '').trim()) ?? 0,
        deviceId: context.read<KioskAuthProvider>().deviceId ?? 0,
        grandTotal: amount,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _confirming = false; _startingOther = false; });
      showCustomSnackBarHelper('Order placement error: $e', isError: true);
    }
  }

  /// Extract cart items as line items for the split-by-item panel.
  List<PosSplitByItemLineItem> _buildLineItemsFromCart(List<CartModel?> lines) {
    final List<PosSplitByItemLineItem> result = [];
    for (int i = 0; i < lines.length; i++) {
      final CartModel? line = lines[i];
      if (line == null) continue;
      final int qty = line.quantity ?? 1;
      result.add(PosSplitByItemLineItem(
        id: i,
        name: line.product?.name ?? 'Item ${i + 1}',
        // The chosen Cup / Can, as frame 14 writes it ("Cup").
        variant: posReceiptUnit(line) ?? '',
        // What the receipt charges for the line: unit price incl. paid
        // add-ons, times quantity.
        price: double.parse((kioskLineUnitPrice(line) * qty).toStringAsFixed(2)),
      ));
    }
    return result;
  }

  /// What a split-by-item payment charges for the current pick, or null when
  /// the pick cannot be paid.
  ///
  /// The backend (`SplitByItemController::createGroups`) takes the whole split
  /// in one call — groups that sum to the order total — and a second call
  /// would delete the groups already paid. So the first payment defines two
  /// groups, the picked items and the rest; the next payment settles the rest
  /// as a whole. A pick of every remaining item charges what is still owed
  /// (which also carries any tip or discount on the order).
  double? _sbiCharge(List<PosSplitByItemLineItem> items) {
    final PosSplitByItemState? state = _splitByItem.value;
    if (state == null) return null;
    final Set<int> picked = _splitByItemGroups.value.selectedItemIds;
    if (picked.isEmpty) return null;
    final PosSplitByItemGroup? pending = state.pendingGroup;
    if (pending != null) {
      return picked.length == pending.itemIds.length &&
              pending.itemIds.every(picked.contains)
          ? pending.amount
          : null;
    }
    final Set<int> paidIds = {for (final g in state.paidGroups) ...g.itemIds};
    final bool everything = items
        .where((i) => !paidIds.contains(i.id))
        .every((i) => picked.contains(i.id));
    if (everything) return state.remaining;
    final double amount = _splitByItemGroups.value.calculateAmount(items);
    return amount > 0 && amount < state.remaining ? amount : null;
  }

  /// Called by the sticky bar's "Start Payment N" (card) or, on cash, by
  /// "Confirm Payment" after the tender step (frame 15).
  Future<void> _startSplitByItemPayment(
      List<PosSplitByItemLineItem> items) async {
    if (_splitByItemLoading) return;
    final PosSplitByItemState? state = _splitByItem.value;
    if (state == null) return;

    final double? charge = _sbiCharge(items);
    if (charge == null) {
      showCustomSnackBarHelper(
        state.pendingGroup == null
            ? 'Select at least one item'
            : 'Pay the remaining items together',
        isError: true,
      );
      return;
    }
    final Set<int> picked = _splitByItemGroups.value.selectedItemIds;

    setState(() {
      _splitByItemLoading = true;
      _phase = PosCheckoutPhase.placingOrder;
    });

    try {
      final PosSplitByItemRepo repo = di.sl<PosSplitByItemRepo>();
      PosSplitByItemGroup? group = state.pendingGroup;

      // 1. First payment: define the split on the backend (the pick, and the
      //    rest as one group) — once per order.
      if (group == null) {
        final List<int> rest = [
          for (final i in items)
            if (!picked.contains(i.id)) i.id,
        ];
        final double restAmount =
            double.parse((state.grandTotal - charge).toStringAsFixed(2));
        final ApiResponseModel createResp = await repo.createGroups(
          orderId: state.orderId,
          deviceId: state.deviceId,
          groups: [
            {'item_ids': picked.toList()..sort(), 'amount': charge},
            if (rest.isNotEmpty && restAmount > 0)
              {'item_ids': rest, 'amount': restAmount},
          ],
        );
        if (!mounted) return;

        if (!createResp.isSuccess) {
          showCustomSnackBarHelper(
            'Group creation failed: ${createResp.error}',
            isError: true,
          );
          setState(() {
            _splitByItemLoading = false;
            _phase = null;
          });
          return;
        }

        final PosSplitByItemState createdState = PosSplitByItemState.fromJson(
          Map<String, dynamic>.from(createResp.response!.data as Map),
          deviceId: state.deviceId,
        );
        _splitByItem.update(createdState);
        group = createdState.pendingGroup;
        if (group == null) {
          setState(() {
            _splitByItemLoading = false;
            _phase = null;
          });
          showCustomSnackBarHelper('Group creation failed', isError: true);
          return;
        }
      }
      if (!mounted) return;
      setState(() => _phase = null);
      final int groupSeq = group.seq;
      final double amount = group.amount;
      final String reference = 'pos-sbi-${state.orderId}-$groupSeq';

      // 2. Card charge (skipped for cash).
      String? transactionRef;
      if (_splitByItemMethod == PosPaymentMethod.card) {
        _splitByItemCardKey ??=
            'pos-sbi-card-${DateTime.now().millisecondsSinceEpoch}';
        setState(() => _phase = PosCheckoutPhase.awaitingTerminal);

        final KioskPaymentResult payment =
            await di.sl<KioskPaymentService>().pay(
          amount: amount,
          idempotencyKey: _splitByItemCardKey!,
        );
        if (!mounted) return;
        setState(() => _phase = null);

        switch (payment.status) {
          case KioskPaymentStatus.paid:
            transactionRef = payment.paymentRef;
          case KioskPaymentStatus.failed:
            _showSplitByItemDeclineCard(amount, groupSeq);
            setState(() => _splitByItemLoading = false);
            return;
          case KioskPaymentStatus.canceled:
            setState(() => _splitByItemLoading = false);
            return;
        }
      }

      // 3. Record payment.
      setState(() => _phase = PosCheckoutPhase.placingOrder);
      final ApiResponseModel recordResp = await repo.recordPayment(
        orderId: state.orderId,
        groupSeq: groupSeq,
        paidWith: _splitByItemMethod == PosPaymentMethod.card ? 'card' : 'cash',
        paidAmount: amount,
        deviceId: state.deviceId,
        reference: reference,
        transactionReference: transactionRef,
      );
      if (!mounted) return;
      setState(() => _phase = null);

      if (!recordResp.isSuccess) {
        showCustomSnackBarHelper(
          'Payment recording failed: ${recordResp.error}',
          isError: true,
        );
        setState(() => _splitByItemLoading = false);
        return;
      }

      final PosSplitByItemState updatedState = PosSplitByItemState.fromJson(
        Map<String, dynamic>.from(recordResp.response!.data as Map),
        deviceId: state.deviceId,
      );
      _splitByItem.update(updatedState);

      setState(() {
        _splitByItemLoading = false;
        _splitByItemCardKey = null;
        _sbiTender = null;
        _sbiDenomination = null;
      });

      _showSplitByItemSuccessCard(updatedState);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _splitByItemLoading = false;
        _phase = null;
      });
      showCustomSnackBarHelper('Split error: $e', isError: true);
    }
  }

  /// Decline card overlay for a failed split-by-item group charge.
  void _showSplitByItemDeclineCard(double amount, int groupSeq) {
    showGeneralDialog(
      context: context,
      // Frame 07's treatment: the card on the page background.
      barrierColor: PosHomeSpec.pageBg,
      pageBuilder: (context, anim, secAnim) => PosPayTextScope(
        child: Material(
          type: MaterialType.transparency,
          child: PosDeclinedCard(
            amountDue: amount,
            retrying: _splitByItemLoading,
            onCancel:
                _splitByItemLoading ? null : () => Navigator.pop(context),
            onTryAgain: _splitByItemLoading
                ? null
                : () {
                    Navigator.pop(context);
                    // Retry: _splitByItemCardKey is stable across retries.
                    final List<PosSplitByItemLineItem> items =
                        _buildLineItemsFromCart(
                            context.read<CartProvider>().cartList);
                    _startSplitByItemPayment(items);
                  },
          ),
        ),
      ),
    );
  }

  /// Success overlay after each group payment: "Start next payment", or the
  /// settled-order card (frame 18).
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
            setState(() {
              _splitByItemGroups.nextGroup(state.nextPaymentNumber);
              // The next payment settles the remaining group: its items
              // come ticked (frame 16).
              for (final int id in state.pendingGroup?.itemIds ?? const []) {
                _splitByItemGroups.toggleItem(id);
              }
              _splitByItemMethod = PosPaymentMethod.card;
            });
          },
        );
      }
      return PosPaymentSuccessCard(
        title: 'Order Paid',
        amount: state.grandTotal,
        amountLabel: 'TOTAL PAID',
        secondaryLabel: 'Receipt',
        onSecondary: () => _showReceiptDialog(
          orderId: state.orderId,
          total: state.grandTotal,
          onAfterSend: () {
            Navigator.pop(dialogContext);
            _completeSplitByItem();
          },
        ),
        buttonLabel: 'Next order',
        onContinue: () {
          Navigator.pop(dialogContext);
          _completeSplitByItem();
        },
      );
    });
  }

  /// Final cleanup: clear cart + session, navigate home.
  void _completeSplitByItem() {
    final CartProvider cart = context.read<CartProvider>();
    final CouponProvider coupon = context.read<CouponProvider>();
    endKioskCustomerSession(
      context.mounted ? context : null,
      cart: cart,
      coupon: coupon,
    );
    _sale.reset();
    _splitByItem.clear();
    if (context.mounted) context.go(PosRoutes.home);
  }

  // ─────────────────────────────────────────────────────────────────────────

  // ── Invoice (Family 4) ───────────────────────────────────────────────────

  /// Operator taps "Invoice" in the OTHER row.
  ///
  /// Places the order upfront (same as split families), then switches the
  /// right pane to the invoice form.
  Future<void> _startInvoice(double grandTotal) async {
    if (_invoiceActive || _confirming) return;

    final kioskSession = kiosk.KioskSession.instance;
    kioskSession.customerName = _sale.customerName.text.trim();
    if (!context.mounted) return;

    setState(() {
      _confirming = true;
      _startingOther = true;
      _phase = null;
      _cancelling = false;
      _declined = false;
    });

    try {
      final KioskPlaceResult placed = await posPlaceOrder(
        context,
        amount: grandTotal,
        tipAmountOverride: _tip.value > 0 ? _tip.value : null,
      );
      if (!mounted) return;
      setState(() { _confirming = false; _startingOther = false; });

      if (!placed.success) {
        showCustomSnackBarHelper(
          placed.message ?? 'Order placement failed',
          isError: true,
        );
        return;
      }

      setState(() {
        _invoiceOrderId     = int.tryParse((placed.orderId ?? '').trim()) ?? 0;
        _invoiceGrandTotal  = grandTotal;
        _invoiceActive      = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _confirming = false; _startingOther = false; });
      showCustomSnackBarHelper('Order placement error: $e', isError: true);
    }
  }

  /// Called by the "Create Invoice" button in [PosInvoicePanel].
  Future<void> _submitInvoice() async {
    if (_invoiceLoading || !_invoiceForm.isValid) return;

    final int deviceId = context.read<KioskAuthProvider>().deviceId ?? 0;
    final String reference =
        'pos-inv-$_invoiceOrderId-${DateTime.now().millisecondsSinceEpoch}';

    final Map<String, dynamic> payload = _invoiceForm.toPayload(
      orderId: _invoiceOrderId,
      deviceId: deviceId,
      reference: reference,
    );

    setState(() {
      _invoiceLoading = true;
      _phase = PosCheckoutPhase.placingOrder;
    });

    try {
      final PosInvoiceRepo repo = di.sl<PosInvoiceRepo>();
      final ApiResponseModel response = await repo.create(payload);

      if (!mounted) return;
      setState(() {
        _invoiceLoading = false;
        _phase = null;
      });

      if (!response.isSuccess) {
        showCustomSnackBarHelper(
          'Invoice failed: ${response.error}',
          isError: true,
        );
        return;
      }

      // Show success overlay then go home.
      _showInvoiceSuccessCard();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _invoiceLoading = false;
        _phase = null;
      });
      showCustomSnackBarHelper('Invoice error: $e', isError: true);
    }
  }

  /// No frame draws the invoice outcome; it uses frame 18's card.
  void _showInvoiceSuccessCard() {
    _showSuccessCard((dialogContext) => PosPaymentSuccessCard(
          title: 'Invoice created',
          amount: _invoiceGrandTotal,
          amountLabel: 'AMOUNT INVOICED',
          secondaryLabel: 'Receipt',
          onSecondary: () => _showReceiptDialog(
            orderId: _invoiceOrderId,
            total: _invoiceGrandTotal,
            onAfterSend: () {
              Navigator.pop(dialogContext);
              _completeInvoice();
            },
          ),
          buttonLabel: 'Next order',
          onContinue: () {
            Navigator.pop(dialogContext);
            _completeInvoice();
          },
        ));
  }

  void _completeInvoice() {
    final CartProvider cart = context.read<CartProvider>();
    final CouponProvider coupon = context.read<CouponProvider>();
    endKioskCustomerSession(
      context.mounted ? context : null,
      cart: cart,
      coupon: coupon,
    );
    _sale.reset();
    setState(() {
      _invoiceActive = false;
      _invoiceOrderId = 0;
    });
    if (context.mounted) context.go(PosRoutes.home);
  }

  // ─────────────────────────────────────────────────────────────────────────

  // ── Stand-alone terminal (Family 5) ──────────────────────────────────────

  /// Operator taps "Stand-alone" in the OTHER row.
  ///
  /// Places the order upfront then shows the instruction pane.
  Future<void> _startStandalone(double grandTotal) async {
    if (_standaloneActive || _confirming) return;

    final kioskSession = kiosk.KioskSession.instance;
    kioskSession.customerName = _sale.customerName.text.trim();
    if (!context.mounted) return;

    setState(() {
      _confirming = true;
      _startingOther = true;
      _phase = null;
      _cancelling = false;
      _declined = false;
    });

    try {
      final KioskPlaceResult placed = await posPlaceOrder(
        context,
        amount: grandTotal,
        tipAmountOverride: _tip.value > 0 ? _tip.value : null,
      );
      if (!mounted) return;
      setState(() { _confirming = false; _startingOther = false; });

      if (!placed.success) {
        showCustomSnackBarHelper(
          placed.message ?? 'Order placement failed',
          isError: true,
        );
        return;
      }

      setState(() {
        _standaloneOrderId    = int.tryParse((placed.orderId ?? '').trim()) ?? 0;
        _standaloneGrandTotal = grandTotal;
        _standaloneActive     = true;
        _standaloneApprovalCode.value = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _confirming = false; _startingOther = false; });
      showCustomSnackBarHelper('Order placement error: $e', isError: true);
    }
  }

  /// Called by "Confirm Payment" in [PosStandalonePanel].
  Future<void> _submitStandalone() async {
    if (_standaloneLoading) return;

    final int deviceId = context.read<KioskAuthProvider>().deviceId ?? 0;
    final String reference =
        'pos-sa-$_standaloneOrderId-${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _standaloneLoading = true;
      _phase = PosCheckoutPhase.placingOrder;
    });

    try {
      final PosStandaloneRepo repo = di.sl<PosStandaloneRepo>();
      final ApiResponseModel response = await repo.record(
        orderId: _standaloneOrderId,
        deviceId: deviceId,
        reference: reference,
        approvalCode: _standaloneApprovalCode.value.trim().isEmpty
            ? null
            : _standaloneApprovalCode.value.trim(),
      );

      if (!mounted) return;
      setState(() {
        _standaloneLoading = false;
        _phase = null;
      });

      if (!response.isSuccess) {
        showCustomSnackBarHelper(
          'Standalone payment failed: ${response.error}',
          isError: true,
        );
        return;
      }

      _showStandaloneSuccessCard();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _standaloneLoading = false;
        _phase = null;
      });
      showCustomSnackBarHelper('Standalone payment error: $e', isError: true);
    }
  }

  /// No frame draws the stand-alone outcome; it uses frame 18's card.
  void _showStandaloneSuccessCard() {
    _showSuccessCard((dialogContext) => PosPaymentSuccessCard(
          title: 'Payment confirmed',
          amount: _standaloneGrandTotal,
          amountLabel: 'TOTAL PAID',
          secondaryLabel: 'Receipt',
          onSecondary: () => _showReceiptDialog(
            orderId: _standaloneOrderId,
            total: _standaloneGrandTotal,
            onAfterSend: () {
              Navigator.pop(dialogContext);
              _completeStandalone();
            },
          ),
          buttonLabel: 'Next order',
          onContinue: () {
            Navigator.pop(dialogContext);
            _completeStandalone();
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
      pageBuilder: (dialogContext, anim, secAnim) => PosReceiptDialog(
        orderId:    orderId,
        total:      total,
        deviceId:   deviceId,
        onComplete: () {
          Navigator.pop(dialogContext);
          onAfterSend();
        },
        onSkip: () => Navigator.pop(dialogContext),
      ),
    );
  }

  /// Shows the success card for a single card / cash payment — frame 18
  /// ("Order Paid", 1915:12227): "Receipt" (outline → receipt dialog → home)
  /// above "Next order" (ink → home).
  void _showSinglePaymentSuccessCard(double total, int orderId) {
    _showSuccessCard((dialogContext) => PosPaymentSuccessCard(
          title: 'Order Paid',
          amount: total,
          amountLabel: 'TOTAL PAID',
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
  /// For split flows the placed order stays in the system (it would need a
  /// void/refund flow to cancel properly — that is out of scope here). The UI
  /// returns to the normal Card/Cash selector.
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
      setState(() => _splitCustom = false);
      return;
    }
    if (_splitByItem.value != null) {
      _splitByItem.clear();
      setState(() {
        _sbiTender = null;
        _sbiDenomination = null;
      });
      return;
    }
    if (_invoiceActive) {
      setState(() {
        _invoiceActive = false;
        _invoiceOrderId = 0;
      });
      return;
    }
    if (_standaloneActive) {
      setState(() {
        _standaloneActive = false;
        _standaloneOrderId = 0;
      });
    }
  }

  void _completeStandalone() {
    final CartProvider cart = context.read<CartProvider>();
    final CouponProvider coupon = context.read<CouponProvider>();
    endKioskCustomerSession(
      context.mounted ? context : null,
      cart: cart,
      coupon: coupon,
    );
    _sale.reset();
    setState(() {
      _standaloneActive = false;
      _standaloneOrderId = 0;
    });
    if (context.mounted) context.go(PosRoutes.home);
  }

  // ─────────────────────────────────────────────────────────────────────────

  void _incrementLine(int index) {
    final CartProvider cart = context.read<CartProvider>();
    final CartModel? line = cart.cartList[index];
    if (line == null) return;
    cart.setQuantity(isIncrement: true, cart: line, fromProductView: false);
  }

  void _decrementLine(int index) {
    final CartProvider cart = context.read<CartProvider>();
    final CartModel? line = cart.cartList[index];
    if (line == null) return;
    if ((line.quantity ?? 1) <= 1) {
      cart.removeFromCart(index);
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
    setState(() => _declined = false);
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
      _startingOther = true;
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
        _cash = _cash.clear();
        _denomination = null;
        await _autoPrintIfEnabled(result.orderId);
        if (!mounted) return;
        _showSinglePaymentSuccessCard(
          total,
          int.tryParse((result.orderId ?? '').trim()) ?? 0,
        );
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
    try {
      await manager.loadReceiptDetail(orderId);
      if (!mounted) return;
      final Map<String, dynamic>? json = manager.receiptDetail;
      if (json == null || manager.receiptDetailId != orderId) return;
      posPrintReceipt(
        PosReceiptDetail.fromJson(json),
        hardware: settings.hardware,
        general: settings.general,
      );
    } catch (_) {
      if (!mounted) return;
      showCustomSnackBarHelper(
        'Order placed, but the receipt could not be printed automatically.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      );
    }

    return Scaffold(
      backgroundColor: PosHomeSpec.pageBg,
      body: PosPayTextScope(
        child: SafeArea(
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
                            // grand total that was charged, not a fresh read.
                            amountDue: _declinedAmount,
                            retrying: _confirming,
                            onCancel: _confirming ? null : _dismissDeclined,
                            onTryAgain: _confirming
                                ? null
                                : () => _tryAgain(grandTotal, tip),
                          ),
                        )
                      else if (_isWaitingForTerminal)
                        Expanded(
                          child: PosWaitingCard(
                            amountDue: grandTotal,
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
                                    splitState: splitState,
                                    splitMethod: _splitMethod,
                                    splitEntry: _splitEntry,
                                    onSplitMethod: _onSplitMethod,
                                    onSplitKey: _onSplitKey,
                                    onSplitBackspace: _onSplitBackspace,
                                    onSplitClear: _onSplitClear,
                                    onSplitDenomination: _onSplitDenomination,
                                    splitDenomination: _splitDenomination,
                                    onSplitByPayment: _change != null
                                        ? null
                                        : () {
                                            _cancelActiveOther();
                                            _startSplit(grandTotal);
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
                                    onSplitConfirm: _splittingPayment
                                        ? null
                                        : _recordSplit,
                                    splitLoading: _splittingPayment,
                                    inSplitByItem: inSplitByItem,
                                    splitByItemState: sbiState,
                                    splitByItemGroups: _splitByItemGroups,
                                    splitByItemMethod: _splitByItemMethod,
                                    splitByItemLineItems: sbiItems,
                                    onSplitByItem: _change != null || inSplitByItem
                                        ? null
                                        : _openSplitChooser,
                                    onSplitByItemMethod: (m) =>
                                        setState(() => _splitByItemMethod = m),
                                    sbiAmountOf: (_) =>
                                        _sbiCharge(sbiItems) ??
                                        _splitByItemGroups.value
                                            .calculateAmount(sbiItems),
                                    sbiTender: _sbiTender,
                                    sbiDenomination: _sbiDenomination,
                                    sbiCharge: _sbiCharge(sbiItems),
                                    sbiPickedNames: [
                                      for (final i in sbiItems)
                                        if (_splitByItemGroups.value
                                            .isSelected(i.id))
                                          i.name,
                                    ],
                                    onSbiKey: _onSbiKey,
                                    onSbiBackspace: _onSbiBackspace,
                                    onSbiDenomination: _onSbiDenomination,
                                    onSbiMethod: _onSbiMethod,
                                    onSplitByItemStartPayment:
                                        _splitByItemLoading
                                            ? null
                                            : () => _startSplitByItemPayment(
                                                sbiItems),
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
                                                _cancelActiveOther();
                                                _startInvoice(grandTotal);
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
                                                _cancelActiveOther();
                                                _startStandalone(grandTotal);
                                              },
                                    onSubmitStandalone: _submitStandalone,
                                    onCancelActiveOther: _cancelActiveOther,
                                    pendingOther: _startingOther,
                                    showSplitOptions: _change == null,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        // Pill CTA hidden while in split-by-item, split-by-payment,
                        // invoice, or stand-alone mode (those panes own their CTAs).
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
                                    loading: _confirming,
                                    onConfirm: _confirming
                                        ? null
                                        : () =>
                                            _continueSplitChooser(grandTotal),
                                  );
                                }
                                // Frames 05 / 09–12 ("Start Payment N") and
                                // 19 ("Start Payment N · € X"): the split
                                // pane is confirmed from this bar, live only
                                // for an amount the backend will take.
                                if (splitState != null) {
                                  final int? applied = _splitAppliedCents();
                                  final String amount = applied == null
                                      ? ''
                                      : ' · ${PosHomeSpec.formatPrice(posCentsToMoney(applied, decimals: _splitEntry.decimals), padZero: false)}';
                                  return PosPayPillBar(
                                    label:
                                        'Start Payment ${splitState.nextSequence}'
                                        '${_splitCustom ? amount : ''}',
                                    loading: _splittingPayment,
                                    onConfirm: _splittingPayment ||
                                            applied == null
                                        ? null
                                        : _recordSplit,
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
                                      final double? charge = _sbiCharge(items);
                                      final String due = PosHomeSpec.formatPrice(
                                          charge ??
                                              builder.calculateAmount(items),
                                          padZero: false);
                                      final PosCashEntry? tender = _sbiTender;
                                      if (tender != null) {
                                        final bool covers = charge != null &&
                                            tender.cents >=
                                                posMoneyToCents(charge,
                                                    decimals: tender.decimals);
                                        return PosPayPillBar(
                                          label: 'Confirm Payment · $due',
                                          loading: _splitByItemLoading,
                                          onConfirm: covers &&
                                                  !_splitByItemLoading
                                              ? () =>
                                                  _startSplitByItemPayment(
                                                      items)
                                              : null,
                                        );
                                      }
                                      final bool cash = _splitByItemMethod ==
                                          PosPaymentMethod.cash;
                                      return PosPayPillBar(
                                        label:
                                            'Start Payment ${sbiState.nextPaymentNumber}'
                                            ' · $due',
                                        loading: _splitByItemLoading,
                                        onConfirm: charge != null &&
                                                !_splitByItemLoading
                                            ? () => cash
                                                ? _startSbiCash(items)
                                                : _startSplitByItemPayment(
                                                    items)
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
  final VoidCallback onSplitClear;
  final ValueChanged<PosCashDenomination> onSplitDenomination;
  final PosCashDenomination? splitDenomination;
  final VoidCallback? onSplitByPayment;
  final VoidCallback? onSplitConfirm;
  final bool splitLoading;

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
  final ValueChanged<PosPaymentMethod> onSplitByItemMethod;
  final VoidCallback? onSplitByItemStartPayment;
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

  /// True while an OTHER-mode order is being placed (API in flight). Prevents
  /// the PRIMARY radio from blinking selected between cancel and activation.
  final bool pendingOther;

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
    required this.onSplitClear,
    required this.onSplitDenomination,
    required this.splitDenomination,
    required this.onSplitByPayment,
    required this.onSplitConfirm,
    required this.splitLoading,
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
    required this.onSplitByItemMethod,
    required this.onSplitByItemStartPayment,
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
    this.pendingOther = false,
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

  /// Payment-method column — node 1915:9420. Scrolls internally when it owns a
  /// bounded height (a pane-internal scroll, never a full-screen one).
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
      pendingOther: pendingOther,
      showSplitOptions: showSplitOptions,
    );
    return PosPayCard(
      padding: const EdgeInsets.all(PosPaymentSpec.v2MethodCardPadding),
      child: fill ? SingleChildScrollView(child: selector) : selector,
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
          onToggleItem: (id) => splitByItemGroups.toggleItem(id),
          onPaymentMethodChanged: onSplitByItemMethod,
          onStartPayment: onSplitByItemStartPayment ?? () {},
          // The order (tip included) is already placed: informational.
          tip: tip,
          amountOf: sbiAmountOf,
          onRefund: onRefundGroup,
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
