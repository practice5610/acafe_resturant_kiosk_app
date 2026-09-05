import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/domain/pos_checkout.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_settings_repo.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_menu_actions.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_print.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_cash_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_declined_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_context_menu.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
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

  /// Null after any keypad entry — a chip stays lit only while it is what the
  /// operator actually chose. See [_onCashKey].
  PosCashDenomination? _denomination;

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

  void _back() {
    // The cart lives in CartProvider and the ticket in PosSaleSession, so
    // leaving loses neither.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(PosRoutes.home);
    }
  }

  void _selectMethod(PosPaymentMethod method) {
    if (_sale.paymentMethod == method) return;
    setState(() {
      _sale.paymentMethod = method;
      // Switching away from cash abandons the tender. Leaving a stale amount
      // behind would let an operator key €50, switch to card, switch back and
      // confirm against a figure they had already moved on from.
      _cash = _cash.clear();
      _denomination = null;
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
  void _tryAgain(double total) {
    if (_confirming) return;
    _confirm(total);
  }

  Future<void> _confirm(double total) async {
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

    final PosHardwareSettings? hardware = PosHardwareSettingsRepo(
      sharedPreferences: di.sl<SharedPreferences>(),
    ).loadSaved(storeName: '');
    if (hardware == null || !hardware.autoPrintReceipts) return;

    final KioskManagerProvider manager = context.read<KioskManagerProvider>();
    try {
      await manager.loadReceiptDetail(orderId);
      if (!mounted) return;
      final Map<String, dynamic>? json = manager.receiptDetail;
      if (json == null || manager.receiptDetailId != orderId) return;
      posPrintReceipt(PosReceiptDetail.fromJson(json));
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
            // Back is withheld while the terminal has the payment: leaving
            // mid-transaction is how a card gets charged against an order
            // nobody placed. Cancel Transaction is the way out.
            _BackRow(
                onBack: _isWaitingForTerminal || _declined ? null : _back),
            if (_declined)
              Expanded(
                child: PosDeclinedCard(
                  // The figure the declined attempt was for, not a fresh read
                  // of the cart — the two cannot differ, but quoting the
                  // attempt is what makes that guaranteed rather than likely.
                  amountDue: _declinedAmount,
                  retrying: _confirming,
                  onCancel: _confirming ? null : _dismissDeclined,
                  onTryAgain: _confirming ? null : () => _tryAgain(total),
                ),
              )
            else if (_isWaitingForTerminal)
              Expanded(
                child: PosWaitingCard(
                  // The same figure the summary and Confirm were quoting a
                  // moment ago — read, not recomputed.
                  amountDue: total,
                  cancelling: _cancelling,
                  onCancel: _cancelling ? null : _cancelTransaction,
                ),
              )
            else ...[
              Expanded(
                child: _Content(
                  lines: lines,
                  hasItems: hasItems,
                  imageBaseUrl: splash.baseUrls?.productImageUrl,
                  dealImageBaseUrl: splash.baseUrls?.dealImageUrl,
                  orderNumber: _sale.orderNumber,
                  customerNameController: _sale.customerName,
                  tableController: _sale.table,
                  method: _sale.paymentMethod,
                  cashEnabled: _payments.cashEnabled,
                  cardEnabled: _payments.cardEnabled,
                  subtotal: subtotal,
                  discount: discount,
                  total: total,
                  onSelectMethod: _selectMethod,
                  cash: _cash,
                  denomination: _denomination,
                  totalCents: _totalCents(total),
                  onCashKey: _onCashKey,
                  onCashBackspace: _onCashBackspace,
                  onCashClear: _onCashClear,
                  onDenomination: (d) => _onDenomination(d, total),
                  onIncrement: _incrementLine,
                  onDecrement: _decrementLine,
                  onOptions: _openReceiptOptions,
                ),
              ),
              // `sticky-bottom-bar` is a flex sibling in 1641:3751, not an
              // overlay: with the tender keypad on screen there is no spare
              // height to float it over. Figma 1641:4203 drops it entirely —
              // the waiting card owns the only action available.
              _ConfirmBar(
                busy: _confirming,
                // Cash adds one more gate on top of "there is a sale": the
                // tendered amount has to cover the total. The button component
                // is untouched — a null callback is the state it already renders
                // as disabled.
                onConfirm:
                    hasItems && !_confirming && (!_isCash || _cashCovers(total))
                        ? () => _confirm(total)
                        : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// `back-btn-row` (1641:2759).
class _BackRow extends StatelessWidget {
  /// Null renders the row and the button, greyed and inert — the chrome has to
  /// hold its 67px or the content below jumps when the waiting card appears.
  final VoidCallback? onBack;

  const _BackRow({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: PosPaymentSpec.backRowHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(
          horizontal: PosPaymentSpec.backRowPaddingH),
      color: PosHomeSpec.pageBg,
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
                borderRadius:
                    BorderRadius.circular(PosPaymentSpec.backButtonRadius),
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
  final double total;
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

  Widget _receiptCard({required bool fill}) {
    final Widget list = hasItems
        ? _orderList(shrinkWrap: !fill)
        : const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: PosReceiptEmptyState(),
          );

    return _Card(
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

  Widget _paymentCard() {
    return _Card(
      padding: const EdgeInsets.symmetric(
        horizontal: PosPaymentSpec.paymentCardPaddingH,
        vertical: PosPaymentSpec.paymentCardPaddingV,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SELECT PAYMENT METHOD',
            style: loewBold.copyWith(
              fontSize: PosPaymentSpec.sectionLabelSize,
              height: PosPaymentSpec.sectionLabelHeight,
              letterSpacing: PosPaymentSpec.sectionLabelTracking,
              color: PosHomeSpec.inkAlpha(PosPaymentSpec.sectionLabelOpacity),
            ),
          ),
          const SizedBox(height: PosPaymentSpec.paymentCardGap),
          Row(
            // start, not stretch: the card is inside a SingleChildScrollView
            // whose height is unbounded, and both method cards already carry
            // the design's fixed 95px height.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (cashEnabled)
                Expanded(
                  child: PosPaymentMethodCard(
                    method: PosPaymentMethod.cash,
                    selected: method == PosPaymentMethod.cash,
                    onTap: () => onSelectMethod(PosPaymentMethod.cash),
                  ),
                ),
              // Only a separator when there are two cards to separate; a
              // single-tender terminal must not carry a stray 16px gutter.
              if (cashEnabled && cardEnabled)
                const SizedBox(width: PosPaymentSpec.methodGap),
              if (cardEnabled)
                Expanded(
                  child: PosPaymentMethodCard(
                    method: PosPaymentMethod.card,
                    selected: method == PosPaymentMethod.card,
                    onTap: () => onSelectMethod(PosPaymentMethod.card),
                  ),
                ),
            ],
          ),
          // `cash-payment-panel` (1641:3830) only exists in the cash frame;
          // the card frame (1641:2757) goes straight from the method row to
          // the totals.
          if (method == PosPaymentMethod.cash) ...[
            const SizedBox(height: PosPaymentSpec.paymentCardGap),
            PosCashPanel(
              entry: cash,
              totalCents: totalCents,
              selectedDenomination: denomination,
              onDenomination: onDenomination,
              onKey: onCashKey,
              onBackspace: onCashBackspace,
              onClear: onCashClear,
            ),
          ],
          const SizedBox(height: PosPaymentSpec.paymentCardGap),
          PosReceiptSummary(
            subtotal: subtotal,
            discount: discount,
            total: total,
            pinned: false,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool sideBySide =
            constraints.maxWidth >= PosPaymentSpec.stackedBelowWidth &&
                constraints.maxHeight >= PosPaymentSpec.stackedBelowHeight;

        // `content-area` in 1641:3751 is `pb-32 px-32` — no top inset. The
        // back row above it already provides the breathing room, and the 32px
        // this frees is what lets the totals stay on screen under the keypad.
        const EdgeInsets padding = EdgeInsets.fromLTRB(
          PosPaymentSpec.contentPadding,
          0,
          PosPaymentSpec.contentPadding,
          PosPaymentSpec.contentPadding,
        );

        if (!sideBySide) {
          return SingleChildScrollView(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _receiptCard(fill: false),
                const SizedBox(height: PosPaymentSpec.contentGap),
                _paymentCard(),
              ],
            ),
          );
        }

        return Padding(
          padding: padding,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                  maxWidth: PosPaymentSpec.contentMaxWidth),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: PosPaymentSpec.receiptFlex,
                    child: _receiptCard(fill: true),
                  ),
                  const SizedBox(width: PosPaymentSpec.contentGap),
                  Expanded(
                    flex: PosPaymentSpec.paymentFlex,
                    // Scrolls rather than stretches: the payment card is sized
                    // by its content in the design, and a short window must
                    // reach the total rather than clip it.
                    child: SingleChildScrollView(child: _paymentCard()),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The rounded panel both halves of `content-area` are drawn on.
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _Card({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      clipBehavior: padding == null ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: PosHomeSpec.panelBg,
        borderRadius: BorderRadius.circular(PosPaymentSpec.cardRadius),
        border: Border.all(
          color: PosHomeSpec.hairline,
          width: PosPaymentSpec.cardBorder,
        ),
      ),
      child: child,
    );
  }
}

/// `sticky-bottom-bar` (1641:2871).
class _ConfirmBar extends StatelessWidget {
  final bool busy;
  final VoidCallback? onConfirm;

  const _ConfirmBar({required this.busy, this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final bool enabled = onConfirm != null;

    return Container(
      decoration: const BoxDecoration(
        color: PosHomeSpec.pageBg,
        border: Border(
          top: BorderSide(
            color: PosHomeSpec.ink,
            width: PosPaymentSpec.barBorderTop,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: PosPaymentSpec.barShadow,
            offset: PosPaymentSpec.barShadowOffset,
            blurRadius: PosPaymentSpec.barShadowBlur,
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(
        PosPaymentSpec.barPaddingH,
        PosPaymentSpec.barPaddingTop,
        PosPaymentSpec.barPaddingH,
        PosPaymentSpec.barPaddingBottom,
      ),
      child: Material(
        color:
            enabled ? PosHomeSpec.ink : PosHomeSpec.inkAlpha(busy ? 1 : 0.35),
        borderRadius: BorderRadius.circular(PosPaymentSpec.confirmRadius),
        child: InkWell(
          onTap: onConfirm,
          borderRadius: BorderRadius.circular(PosPaymentSpec.confirmRadius),
          child: SizedBox(
            height: PosPaymentSpec.confirmHeight,
            width: double.infinity,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy) ...[
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Text(
                    busy ? 'Processing…' : 'Confirm Payment',
                    style: loewBold.copyWith(
                      fontSize: PosPaymentSpec.confirmLabelSize,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
