import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/pos/domain/pos_checkout.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_menu_actions.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/domain/pos_sale_session.dart';
import 'package:acafe_customer/features/pos/widgets/pos_payment_method_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_context_menu.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_top_nav_bar.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
  const PosPaymentSelectionScreen({super.key});

  @override
  State<PosPaymentSelectionScreen> createState() =>
      _PosPaymentSelectionScreenState();
}

class _PosPaymentSelectionScreenState extends State<PosPaymentSelectionScreen> {
  /// Stable for the life of this screen: a Retry after a decline is the *same*
  /// checkout attempt and must not be able to charge the card twice.
  final String _idempotencyKey =
      'pos-${DateTime.now().millisecondsSinceEpoch}';

  bool _confirming = false;

  PosSaleSession get _sale => PosSaleSession.instance;

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
    setState(() => _sale.paymentMethod = method);
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

  Future<void> _confirm() async {
    if (_confirming) return;
    final CartProvider cart = context.read<CartProvider>();
    if (!cart.cartList.any((line) => line != null)) return;

    setState(() => _confirming = true);
    final PosCheckoutResult result = await posConfirmPayment(
      context,
      method: _sale.paymentMethod,
      idempotencyKey: _idempotencyKey,
    );
    if (!mounted) return;
    setState(() => _confirming = false);

    switch (result.status) {
      case PosCheckoutStatus.placed:
        showCustomSnackBarHelper(
          result.orderId == null
              ? 'Order placed'
              : 'Order #${result.orderId} placed',
          isError: false,
        );
        context.go(PosRoutes.home);
      case PosCheckoutStatus.paymentFailed:
        showCustomSnackBarHelper(result.message ?? 'Card payment failed');
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

  @override
  Widget build(BuildContext context) {
    final CartProvider cart = context.watch<CartProvider>();
    final CouponProvider coupon = context.watch<CouponProvider>();
    final SplashProvider splash = context.read<SplashProvider>();

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
            _BackRow(onBack: _back),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _Content(
                      lines: lines,
                      hasItems: hasItems,
                      imageBaseUrl: splash.baseUrls?.productImageUrl,
                      dealImageBaseUrl: splash.baseUrls?.dealImageUrl,
                      orderNumber: _sale.orderNumber,
                      customerNameController: _sale.customerName,
                      tableController: _sale.table,
                      method: _sale.paymentMethod,
                      subtotal: subtotal,
                      discount: discount,
                      total: total,
                      onSelectMethod: _selectMethod,
                      onIncrement: _incrementLine,
                      onDecrement: _decrementLine,
                      onOptions: _openReceiptOptions,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: _ConfirmBar(
                      busy: _confirming,
                      onConfirm: hasItems && !_confirming ? _confirm : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `back-btn-row` (1641:2759).
class _BackRow extends StatelessWidget {
  final VoidCallback onBack;

  const _BackRow({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: PosPaymentSpec.backRowHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(
          horizontal: PosPaymentSpec.backRowPaddingH),
      color: PosHomeSpec.pageBg,
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
  final double subtotal;
  final double discount;
  final double total;
  final ValueChanged<PosPaymentMethod> onSelectMethod;
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
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.onSelectMethod,
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
      padding: const EdgeInsets.all(PosPaymentSpec.paymentCardPadding),
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
              color:
                  PosHomeSpec.inkAlpha(PosPaymentSpec.sectionLabelOpacity),
            ),
          ),
          const SizedBox(height: PosPaymentSpec.paymentCardGap),
          Row(
            // start, not stretch: the card is inside a SingleChildScrollView
            // whose height is unbounded, and both method cards already carry
            // the design's fixed 95px height.
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PosPaymentMethodCard(
                  method: PosPaymentMethod.cash,
                  selected: method == PosPaymentMethod.cash,
                  onTap: () => onSelectMethod(PosPaymentMethod.cash),
                ),
              ),
              const SizedBox(width: PosPaymentSpec.methodGap),
              Expanded(
                child: PosPaymentMethodCard(
                  method: PosPaymentMethod.card,
                  selected: method == PosPaymentMethod.card,
                  onTap: () => onSelectMethod(PosPaymentMethod.card),
                ),
              ),
            ],
          ),
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

        // Reserve the sticky bar so nothing ends up underneath it.
        final EdgeInsets padding = const EdgeInsets.all(
          PosPaymentSpec.contentPadding,
        ).copyWith(
          bottom: PosPaymentSpec.contentPadding + PosPaymentSpec.barHeight,
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
        color: enabled
            ? PosHomeSpec.ink
            : PosHomeSpec.inkAlpha(busy ? 1 : 0.35),
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
