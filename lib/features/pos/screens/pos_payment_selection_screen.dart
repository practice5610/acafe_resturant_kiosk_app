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
import 'package:acafe_customer/features/pos/domain/pos_payment_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_menu_actions.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_print.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_split_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_cash_panel.dart'
    show PosCashDenomination;
import 'package:acafe_customer/features/pos/widgets/pos_declined_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_cash_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_summary_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_selector.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_context_menu.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_split_summary_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_tip_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:acafe_customer/features/pos/widgets/pos_waiting_card.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  /// True while a split payment (charge + record) is in flight.
  bool _splittingPayment = false;

  /// The idempotency key for the current split's card charge. Stable across
  /// retries of the same split attempt to prevent double-charge.
  String? _splitCardIdempotencyKey;

  /// Null after any keypad entry — a chip stays lit only while it is what the
  /// operator actually chose. See [_onCashKey].
  PosCashDenomination? _denomination;

  /// Guards the exact-tender default below so it seeds [_cash] once per
  /// screen, not on every rebuild — otherwise it would fight the Clear button,
  /// which sets the amount back to empty on purpose.
  bool _cashDefaulted = false;

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
  }

  @override
  void dispose() {
    _tip.dispose();
    _split.dispose();
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
    final double? chosen = await showPosTipDialog(
      context: context,
      payable: payable,
      currentTip: _tip.value,
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
  Future<void> _startSplit(double grandTotal) async {
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
      _phase = null;
      _cancelling = false;
      _declined = false;
    });

    try {
      final KioskPlaceResult placed = await placeKioskOrder(
        context,
        amount: amount,
        tipAmountOverride: tip > 0 ? tip : null,
      );

      if (!mounted) return;

      setState(() => _confirming = false);

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
      });
      _split.start(
        orderId: int.tryParse((placed.orderId ?? '').trim()) ?? 0,
        deviceId: context.read<KioskAuthProvider>().deviceId ?? 0,
        grandTotal: amount,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _confirming = false);
      showCustomSnackBarHelper(
        'Order placement error: $e',
        isError: true,
      );
    }
  }

  void _selectMethod(PosPaymentMethod method, double total) {
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
    });
  }

  /// Split keypad backspace callback.
  void _onSplitBackspace() {
    setState(() {
      _splitEntry = _splitEntry.backspace();
    });
  }

  /// Split keypad clear callback.
  void _onSplitClear() {
    setState(() {
      _splitEntry = _splitEntry.clear();
    });
  }

  /// Split method toggle (Card ↔ Cash).
  void _onSplitMethod(PosPaymentMethod method) {
    setState(() {
      _splitMethod = method;
    });
  }

  /// Process a split: charge the amount (card or cash), then POST record.
  /// If success: update PosSplitSession, loop back to entry with decremented
  /// remaining. If decline: show retry option. If fully_paid: show final success.
  Future<void> _recordSplit() async {
    if (_splittingPayment) return;
    if (_split.value == null) return;

    final PosSplitState state = _split.value!;
    final int amountCents = _splitEntry.cents;
    if (amountCents <= 0) return;

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
      barrierColor: Colors.black54,
      pageBuilder: (context, anim, secAnim) => Center(
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
    );
  }

  /// Show success card after a split is recorded.
  void _showSplitSuccessCard(PosSplitState state) {
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black54,
      pageBuilder: (context, anim, secAnim) {
        final bool isFinal = state.fullyPaid;
        return Center(
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                width: PosPaymentSpec.v2SuccessCardWidth,
                padding: const EdgeInsets.all(PosPaymentSpec.v2SuccessCardPadding),
                decoration: BoxDecoration(
                  color: PosHomeSpec.tileBg,
                  borderRadius: BorderRadius.circular(
                      PosPaymentSpec.v2SuccessCardRadius),
                  border: Border.all(
                    color: PosHomeSpec.hairline,
                    width: PosPaymentSpec.v2SuccessCardBorder,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon
                    Image.asset(
                      Images.checkCircle,
                      width: PosPaymentSpec.v2SuccessIconSize,
                      height: PosPaymentSpec.v2SuccessIconSize,
                    ),
                    const SizedBox(height: PosPaymentSpec.v2SuccessHeaderGap),
                    Text(
                      isFinal ? 'All payments received' : 'Payment ${state.payments.length} received',
                      style: loewExtraBold.copyWith(
                        fontSize: PosPaymentSpec.v2SuccessHeadingSize,
                        color: PosHomeSpec.ink,
                      ),
                    ),
                    const SizedBox(height: PosPaymentSpec.v2SuccessCardGap),
                    // Remaining info.
                    if (!isFinal) ...[
                      Container(
                        padding: const EdgeInsets.all(
                            PosPaymentSpec.v2SuccessAmountBoxPadding),
                        decoration: BoxDecoration(
                          color: PosHomeSpec.tileBg,
                          borderRadius: BorderRadius.circular(
                              PosPaymentSpec.v2SuccessAmountBoxRadius),
                          border: Border.all(
                            color: PosHomeSpec.tableFieldBorder,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Remaining',
                              style: swiss721Light.copyWith(
                                fontSize: 11,
                                color: PosHomeSpec.inkAlpha(0.4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              PosHomeSpec.formatPrice(state.remaining,
                                  padZero: false),
                              style: loewExtraBold.copyWith(
                                fontSize: 20,
                                color: PosHomeSpec.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: PosPaymentSpec.v2SuccessCardGap),
                    ],
                    // Button.
                    PosPayPillBar(
                      label: isFinal ? 'Finish' : 'Next payment',
                      onConfirm: () {
                        Navigator.pop(context);
                        if (isFinal) {
                          _completeSplit();
                        }
                        // Else: loop back to entry screen (UI will show it)
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
        showCustomSnackBarHelper(
          result.orderId == null
              ? 'Order placed'
              : 'Order #${result.orderId} placed',
          isError: false,
        );
        await _autoPrintIfEnabled(result.orderId);
        if (!mounted) return;
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
    final double total = kioskPayableTotal(lines, discount);

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

    return Scaffold(
      backgroundColor: PosHomeSpec.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // Figma 1641:2757 draws the full nav bar on this frame. It is
            // frozen, not hidden, while a charge is in flight — see
            // PosTopNavBar.interactive.
            PosTopNavBar(
              currentPath: PosRoutes.home,
              interactive: !_confirming,
            ),
            // Everything below the nav bar reacts to the tip: the displayed
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
                  // Tipping is gated behind the existing Settings → Payments
                  // flag; off = the row stays inert, as before this family.
                  final VoidCallback? onTip = _payments.tippingEnabled
                      ? () => _openTip(total)
                      : null;

                  return Column(
                    children: [
                      // Back is withheld while the terminal has the payment:
                      // leaving mid-transaction charges a card against an
                      // order nobody placed. Cancel Transaction is the way out.
                      _BackRow(
                        onBack:
                            _isWaitingForTerminal || _declined ? null : _back,
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
                          child: ValueListenableBuilder<PosSplitState?>(
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
                                onSplitByPayment: () =>
                                    _startSplit(grandTotal),
                                onSplitConfirm:
                                    _splittingPayment ? null : _recordSplit,
                                splitLoading: _splittingPayment,
                              );
                            },
                          ),
                        ),
                        // Full-width pill CTA — `sticky-bottom-bar` (1915:9516).
                        PosPayPillBar(
                          label: 'Confirm Payment',
                          loading: _confirming,
                          // Cash must also cover the grand total (incl. tip).
                          onConfirm: hasItems &&
                                  !_confirming &&
                                  (!_isCash || _cashCovers(grandTotal))
                              ? () => _confirm(grandTotal, tip)
                              : null,
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
    );
  }
}

/// `back-btn-row` (node 1915:9347): the back button at the left, with the
/// ticket's `customer / total` caption centred across the row.
class _BackRow extends StatelessWidget {
  /// Null renders the row and the button, greyed and inert — the chrome has to
  /// hold its 67px or the content below jumps when the waiting card appears.
  final VoidCallback? onBack;

  /// `Dylan / € 19.00` (node 1915:9351) — centred, Loew ExtraBold 14.
  final String label;

  const _BackRow({required this.onBack, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: PosPaymentSpec.backRowHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: Padding(
                // Keep the caption clear of the back button at either edge.
                padding: const EdgeInsets.symmetric(horizontal: 88),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: loewExtraBold.copyWith(
                    fontSize: 14,
                    color: PosHomeSpec.ink,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: PosPaymentSpec.backRowPaddingH),
              child: Opacity(
                opacity: onBack == null ? 0.4 : 1,
                child: Material(
                  color: PosHomeSpec.tileBg,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onBack,
                    child: Container(
                      width: PosPaymentSpec.backButtonSize,
                      height: PosPaymentSpec.backButtonSize,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                            PosPaymentSpec.backButtonRadius),
                        border: Border.all(
                          color: PosHomeSpec.ink,
                          width: PosPaymentSpec.backButtonBorder,
                        ),
                      ),
                      child: SvgPicture.asset(
                        Images.posArrowLeftSvg,
                        width: PosPaymentSpec.backIconSize,
                        height: PosPaymentSpec.backIconSize,
                        colorFilter: const ColorFilter.mode(
                          PosHomeSpec.ink,
                          BlendMode.srcIn,
                        ),
                        placeholderBuilder: (_) => const Icon(
                          Icons.arrow_back,
                          size: PosPaymentSpec.backIconSize,
                          color: PosHomeSpec.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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
  final PosCashEntry cash;
  final PosCashDenomination? denomination;
  final int totalCents;
  final ValueChanged<String> onCashKey;
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
  final VoidCallback? onSplitByPayment;
  final VoidCallback? onSplitConfirm;
  final bool splitLoading;

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
    required this.onSplitByPayment,
    required this.onSplitConfirm,
    required this.splitLoading,
  });

  Widget _orderList({required bool shrinkWrap}) => PosReceiptOrderList(
        lines: lines,
        imageBaseUrl: imageBaseUrl,
        dealImageBaseUrl: dealImageBaseUrl,
        onIncrement: onIncrement,
        onDecrement: onDecrement,
        shrinkWrap: shrinkWrap,
        // No EDIT here: customising a line belongs to the counter screen.
        // Quantity and delete stay, so an operator can still fix a mistake
        // without walking the sale back.
      );

  /// Receipt sidebar pane — node 1915:9353. The header, customer field and
  /// order rows are the Browse-POS redesign widgets, already matching this
  /// frame; only the surrounding card changes to the v2 shell.
  Widget _receiptCard({required bool fill}) {
    final Widget list = hasItems
        ? _orderList(shrinkWrap: !fill)
        : const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: PosReceiptEmptyState(),
          );

    return PosPayCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        children: [
          PosReceiptHeader(orderNumber: orderNumber, onOptions: onOptions),
          PosReceiptCustomerInfo(
            nameController: customerNameController,
            tableController: tableController,
            showBottomHairline: false,
          ),
          const PosReceiptOrderListLabel(),
          if (fill) Expanded(child: list) else list,
        ],
      ),
    );
  }

  /// Payment-method column — node 1915:9420. Scrolls internally when it owns a
  /// bounded height (a pane-internal scroll, never a full-screen one).
  Widget _methodPane({required bool fill}) {
    final Widget selector = PosPaymentMethodSelector(
      method: method,
      cashEnabled: cashEnabled,
      cardEnabled: cardEnabled,
      onSelectMethod: onSelectMethod,
      onSplitByPayment: onSplitByPayment,
      splitActive: inSplit,
    );
    return PosPayCard(
      padding: const EdgeInsets.all(PosPaymentSpec.v2MethodCardPadding),
      child: fill ? SingleChildScrollView(child: selector) : selector,
    );
  }

  /// Payment-summary column. When in split mode, shows the split entry panel.
  /// Otherwise shows the Card or Cash panel as before.
  Widget _summaryPane({required bool fill}) {
    // In split mode: show the split entry panel (node 1915:10034).
    if (inSplit && splitState != null) {
      return PosPayCard(
        summaryBorder: true,
        child: fill
            ? SingleChildScrollView(
                child: PosSplitSummaryPanel(
                  state: splitState!,
                  entry: splitEntry,
                  splitMethod: splitMethod,
                  onSplitMethod: onSplitMethod,
                  onKey: onSplitKey,
                  onBackspace: onSplitBackspace,
                  onClear: onSplitClear,
                  tip: tip,
                  onConfirm: onSplitConfirm,
                  loading: splitLoading,
                ),
              )
            : PosSplitSummaryPanel(
                state: splitState!,
                entry: splitEntry,
                splitMethod: splitMethod,
                onSplitMethod: onSplitMethod,
                onKey: onSplitKey,
                onBackspace: onSplitBackspace,
                onClear: onSplitClear,
                tip: tip,
                onConfirm: onSplitConfirm,
                loading: splitLoading,
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
            onBackspace: onCashBackspace,
            onClear: onCashClear,
            tip: tip,
            onTipTap: onTip,
          )
        : PosPaySummaryPanel(total: total, tip: tip, onTipTap: onTip);
    return PosPayCard(
      summaryBorder: true,
      child: fill ? SingleChildScrollView(child: content) : content,
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

