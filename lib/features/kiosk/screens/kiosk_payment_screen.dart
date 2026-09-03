import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:acafe_customer/common/responsive/kiosk_layout.dart';
import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_place_order.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/common/models/place_order_body.dart';
import 'package:acafe_customer/features/branch/providers/branch_provider.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_payment_service.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_coupon_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_tip.dart';
import 'package:acafe_customer/features/order/providers/order_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

enum _Phase { processing, submitting, failed }

/// Drives the terminal payment state machine:
/// processing → paid → submit order → success
/// processing → failed → Retry / Stop(30)
class KioskPaymentScreen extends StatefulWidget {
  const KioskPaymentScreen({super.key});

  @override
  State<KioskPaymentScreen> createState() => _KioskPaymentScreenState();
}

class _KioskPaymentScreenState extends State<KioskPaymentScreen> {
  // Swap the payment service for the real Mollie terminal when ready. Order
  // submission already uses the real backend (OrderProvider.placeOrder).
  final KioskPaymentService _payment = SimulatedKioskPaymentService();

  // Stable across retries of this checkout attempt (idempotency).
  final String _idempotencyKey =
      'kiosk-${DateTime.now().millisecondsSinceEpoch}';

  _Phase _phase = _Phase.processing;
  double _amount = 0;
  Timer? _stopTimer;
  int _stopCountdown = 30;
  String? _paymentRef;
  bool _failedAtSubmit = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cartList =
          Provider.of<CartProvider>(context, listen: false).cartList;
      final couponDiscount =
          Provider.of<CouponProvider>(context, listen: false).discount ?? 0;
      _amount = kioskTotalWithTip(
        kioskPayableTotal(cartList, couponDiscount),
        KioskSession.instance.tipPercentOrZero,
      );
      _startPayment();
    });
  }

  @override
  void dispose() {
    _stopTimer?.cancel();
    super.dispose();
  }

  Future<void> _startPayment() async {
    setState(() => _phase = _Phase.processing);
    final result =
        await _payment.pay(amount: _amount, idempotencyKey: _idempotencyKey);
    if (!mounted) return;

    switch (result.status) {
      case KioskPaymentStatus.paid:
        _paymentRef = result.paymentRef;
        await _submitOrder();
        break;
      case KioskPaymentStatus.failed:
        _showFailure();
        break;
      case KioskPaymentStatus.canceled:
        _exitToCart();
        break;
    }
  }

  /// Places the order on the backend via the SAME path as the user web app
  /// (OrderProvider.placeOrder -> /api/v1/customer/order/place), so it lands in
  /// the orders table and the kitchen app identically. The guest_id created at
  /// startup is attached automatically by the order repository.
  Future<void> _submitOrder() async {
    setState(() => _phase = _Phase.submitting);
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final branchProvider = Provider.of<BranchProvider>(context, listen: false);
    final splashProvider = Provider.of<SplashProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Kiosk orders are placed as a guest. Make sure a guest account exists so the
    // backend's required guest_id is attached by the order repository.
    if (authProvider.getGuestId() == null) {
      await authProvider.addGuest();
    }

    // Build the order cart items — mirrors the web app's confirm_button_widget.
    final List<Cart> carts = [];
    for (final cart in cartProvider.cartList) {
      if (cart == null) continue;

      final List<int?> addOnIdList = [];
      final List<int?> addOnQtyList = [];
      for (final addOn in cart.addOnIds ?? []) {
        addOnIdList.add(addOn.id);
        addOnQtyList.add(addOn.quantity);
      }

      final List<OrderVariation> variations = [];
      final productVariations = cart.product?.variations;
      final selected = cart.variations;
      if (productVariations != null &&
          selected != null &&
          selected.isNotEmpty) {
        for (int i = 0; i < productVariations.length; i++) {
          if (i < selected.length && selected[i].contains(true)) {
            variations.add(OrderVariation(
                name: productVariations[i].name,
                values: OrderVariationValue(label: [])));
            final values = productVariations[i].variationValues ?? [];
            for (int j = 0; j < values.length; j++) {
              if (j < selected[i].length && (selected[i][j] ?? false)) {
                variations.last.values!.label!.add(values[j].level);
              }
            }
          }
        }
      }

      carts.add(Cart(
        cart.product!.id.toString(),
        cart.discountedPrice.toString(),
        [],
        variations,
        cart.discountAmount,
        cart.quantity,
        cart.taxAmount,
        addOnIdList,
        addOnQtyList,
        instruction: cart.instruction,
      ));
    }

    final branches = splashProvider.configModel?.branches;
    final int? branchId = branchProvider.getBranch()?.id ??
        ((branches != null && branches.isNotEmpty) ? branches.first?.id : null);

    final couponProvider = Provider.of<CouponProvider>(context, listen: false);
    final kioskAuthProvider =
        Provider.of<KioskAuthProvider>(context, listen: false);
    final String? couponCode = kioskOrderCouponCode(couponProvider);
    final name = KioskSession.instance.customerName;
    final double tipAmount = kioskTipAmount(
      kioskPayableTotal(
        cartProvider.cartList,
        couponProvider.discount ?? 0,
      ),
      KioskSession.instance.tipPercentOrZero,
    );
    final placeOrderBody = PlaceOrderBody(
      cart: carts,
      couponDiscountAmount: couponProvider.discount ?? 0,
      couponDiscountTitle: couponCode,
      couponCode: couponCode,
      orderAmount: double.parse(_amount.toStringAsFixed(2)),
      tipAmount: tipAmount > 0 ? tipAmount : null,
      deliveryAddressId: 0,
      deliveryAddress: null,
      orderType: kioskOrderType(kioskAuthProvider),
      paymentMethod: 'cash_on_delivery',
      branchId: branchId,
      deviceId: kioskAuthProvider.deviceId,
      deliveryTime: 'now',
      deliveryDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      orderNote: kioskOrderNote(
        name: name,
        note: cartProvider.orderNote,
        tipPercent: KioskSession.instance.tipPercentOrZero,
        tipAmount: tipAmount,
      ),
      distance: 0,
      isPartial: '0',
      isCutleryRequired: '0',
      transactionReference: _paymentRef,
      bringChangeAmount: 0,
    );

    orderProvider.placeOrder(placeOrderBody,
        (bool success, String? message, String orderId) {
      if (success) {
        endKioskCustomerSession(
          mounted ? context : null,
          cart: cartProvider,
          coupon: couponProvider,
        );
        if (!mounted) return;
        RouterHelper.getKioskMenuRoute(action: RouteAction.pushReplacement);
      } else if (mounted) {
        // Payment succeeded but the order didn't post — let Retry re-submit the
        // order (not re-charge), since the customer has already paid.
        _failedAtSubmit = true;
        _errorMessage = message;
        _showFailure();
      }
    }, asGuest: true);
  }

  void _showFailure() {
    setState(() => _phase = _Phase.failed);
    _stopCountdown = 30;
    _stopTimer?.cancel();
    _stopTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _stopCountdown--);
      if (_stopCountdown <= 0) {
        t.cancel();
        _stop();
      }
    });
  }

  void _retry() {
    _stopTimer?.cancel();
    if (_failedAtSubmit) {
      // Already paid — only the order post failed; re-submit, don't re-charge.
      _failedAtSubmit = false;
      _submitOrder();
    } else {
      _startPayment();
    }
  }

  Future<void> _stop() async {
    _stopTimer?.cancel();
    await _payment.cancel();
    _exitToCart();
  }

  void _exitToCart() {
    // Preserve the cart and return to the menu so the customer can retry/adjust.
    if (mounted) context.go(RouterHelper.kioskMenuScreen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double s = KioskLayout.scaleOf(context, constraints);
            return Stack(
              children: [
                Center(
                  child: _phase == _Phase.failed
                      ? const SizedBox()
                      : _processingView(s),
                ),
                if (_phase == _Phase.failed)
                  _FailureModal(
                    s: s,
                    maxWidth: constraints.maxWidth,
                    countdown: _stopCountdown,
                    message: _errorMessage,
                    onRetry: _retry,
                    onStop: _stop,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _processingView(double s) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 86 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 140 * s,
            height: 140 * s,
            child: CircularProgressIndicator(
              strokeWidth: (8 * s).clamp(4.0, 8.0),
              color: KioskUI.dark,
            ),
          ),
          SizedBox(height: 48 * s),
          Text(
            _phase == _Phase.submitting
                ? (getTranslated('placing_your_order', context) ??
                    'Placing your order…')
                : (getTranslated('follow_instructions_on_reader', context) ??
                    'Follow the instructions on the card reader'),
            textAlign: TextAlign.center,
            style: loewExtraBold.copyWith(
              fontSize: 64 * s,
              height: 1.15,
              color: KioskUI.dark,
            ),
          ),
          SizedBox(height: 28 * s),
          Text(
            PriceConverterHelper.convertPrice(_amount),
            style: loewExtraBold.copyWith(
              fontSize: 96 * s,
              color: KioskUI.dark,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailureModal extends StatelessWidget {
  final double s;
  final double maxWidth;
  final int countdown;
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onStop;
  const _FailureModal({
    required this.s,
    required this.maxWidth,
    required this.countdown,
    this.message,
    required this.onRetry,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final double cardWidth = kioskBounded(
      1640 * s,
      min: math.min(320.0, maxWidth * 0.86),
      max: maxWidth * 0.86,
    );
    return Container(
      color: const Color(0xFF1E1E1E).withValues(alpha: 0.45),
      alignment: Alignment.center,
      child: Container(
        width: cardWidth,
        margin: EdgeInsets.all(48 * s),
        padding: EdgeInsets.all(88 * s),
        decoration: BoxDecoration(
          color: KioskUI.pageBg,
          borderRadius: BorderRadius.circular(48 * s),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 96 * s, color: KioskUI.dark),
            SizedBox(height: 32 * s),
            Text(
              getTranslated('payment_failed', context) ?? 'Payment failed…',
              textAlign: TextAlign.center,
              style: loewExtraBold.copyWith(
                fontSize: 56 * s,
                color: KioskUI.dark,
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              SizedBox(height: 16 * s),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: loewMedium.copyWith(
                  fontSize: 32 * s,
                  color: KioskUI.text,
                ),
              ),
            ],
            SizedBox(height: 48 * s),
            Row(
              children: [
                Expanded(
                  child: _Btn(
                    s: s,
                    label: getTranslated('retry', context) ?? 'Retry',
                    filled: true,
                    onTap: onRetry,
                  ),
                ),
                SizedBox(width: 24 * s),
                Expanded(
                  child: _Btn(
                    s: s,
                    label:
                        '${getTranslated('stop', context) ?? 'Stop'} ($countdown)',
                    filled: false,
                    onTap: onStop,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final double s;
  final String label;
  final bool filled;
  final VoidCallback onTap;
  const _Btn({
    required this.s,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? KioskUI.dark : Colors.transparent,
      borderRadius: BorderRadius.circular(30 * s),
      clipBehavior: Clip.antiAlias,
      child: KioskTap(
        onTap: onTap,
        child: Container(
          height: 140 * s,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30 * s),
            border: filled
                ? null
                : Border.all(color: KioskUI.dark, width: (4 * s).clamp(1.5, 4.0)),
          ),
          child: Text(
            label,
            style: loewExtraBold.copyWith(
              fontSize: 40 * s,
              color: filled ? const Color(0xFFF3F3DD) : KioskUI.dark,
            ),
          ),
        ),
      ),
    );
  }
}
