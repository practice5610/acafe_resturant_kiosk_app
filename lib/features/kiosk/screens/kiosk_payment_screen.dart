import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/auth/providers/auth_provider.dart';
import 'package:acafe_customer/common/models/place_order_body.dart';
import 'package:acafe_customer/features/branch/providers/branch_provider.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_payment_service.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/order/providers/order_provider.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/dimensions.dart';
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
  final String _idempotencyKey = 'kiosk-${DateTime.now().millisecondsSinceEpoch}';

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
      _amount = kioskPayableTotal(cartList, couponDiscount);
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
    final result = await _payment.pay(amount: _amount, idempotencyKey: _idempotencyKey);
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
      if (productVariations != null && selected != null && selected.isNotEmpty) {
        for (int i = 0; i < productVariations.length; i++) {
          if (i < selected.length && selected[i].contains(true)) {
            variations.add(OrderVariation(name: productVariations[i].name, values: OrderVariationValue(label: [])));
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
        cart.product!.id.toString(), cart.discountedPrice.toString(), [], variations,
        cart.discountAmount, cart.quantity, cart.taxAmount, addOnIdList, addOnQtyList,
        instruction: cart.instruction,
      ));
    }

    final branches = splashProvider.configModel?.branches;
    final int? branchId = branchProvider.getBranch()?.id ??
        ((branches != null && branches.isNotEmpty) ? branches.first?.id : null);

    final couponProvider = Provider.of<CouponProvider>(context, listen: false);
    final String? couponCode = couponProvider.coupon?.code;
    final name = KioskSession.instance.customerName;
    final placeOrderBody = PlaceOrderBody(
      cart: carts,
      couponDiscountAmount: couponProvider.discount ?? 0,
      couponDiscountTitle: couponCode,
      couponCode: couponCode,
      orderAmount: double.parse(_amount.toStringAsFixed(2)),
      deliveryAddressId: 0,
      deliveryAddress: null,
      orderType: 'take_away',
      paymentMethod: 'cash_on_delivery',
      branchId: branchId,
      deliveryTime: 'now',
      deliveryDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      orderNote: name.isNotEmpty ? 'Kiosk order — $name' : 'Kiosk order',
      distance: 0,
      isPartial: '0',
      isCutleryRequired: '0',
      transactionReference: _paymentRef,
      bringChangeAmount: 0,
    );

    orderProvider.placeOrder(placeOrderBody, (bool success, String? message, String orderId) {
      if (!mounted) return;
      if (success) {
        cartProvider.clearCartList();
        couponProvider.removeCouponData(false);
        KioskSession.instance.reset();
        RouterHelper.getKioskMenuRoute(action: RouteAction.pushReplacement);
      } else {
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
        child: Stack(
          children: [
            Center(child: _phase == _Phase.failed ? const SizedBox() : _processingView()),
            if (_phase == _Phase.failed) _FailureModal(countdown: _stopCountdown, message: _errorMessage, onRetry: _retry, onStop: _stop),
          ],
        ),
      ),
    );
  }

  Widget _processingView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 64, height: 64, child: CircularProgressIndicator(strokeWidth: 5)),
        const SizedBox(height: Dimensions.paddingSizeExtraLarge),
        Text(
          _phase == _Phase.submitting
              ? (getTranslated('placing_your_order', context) ?? 'Placing your order…')
              : (getTranslated('follow_instructions_on_reader', context) ?? 'Follow the instructions on the card reader'),
          textAlign: TextAlign.center,
          style: rubikSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Theme.of(context).textTheme.bodyLarge!.color),
        ),
        const SizedBox(height: Dimensions.paddingSizeDefault),
        Text(PriceConverterHelper.convertPrice(_amount),
            style: rubikBold.copyWith(fontSize: 28, color: Theme.of(context).primaryColor)),
      ],
    );
  }
}

class _FailureModal extends StatelessWidget {
  final int countdown;
  final String? message;
  final VoidCallback onRetry;
  final VoidCallback onStop;
  const _FailureModal({required this.countdown, this.message, required this.onRetry, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black26,
      alignment: Alignment.center,
      child: Container(
        width: 360,
        margin: const EdgeInsets.all(Dimensions.paddingSizeLarge),
        padding: const EdgeInsets.all(Dimensions.paddingSizeExtraLarge),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Icon(Icons.error_outline, size: 40, color: Theme.of(context).primaryColor),
            ),
            const SizedBox(height: Dimensions.paddingSizeDefault),
            Text(getTranslated('payment_failed', context) ?? 'Payment failed…',
                style: rubikSemiBold.copyWith(fontSize: Dimensions.fontSizeLarge, color: Theme.of(context).primaryColor)),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: Dimensions.paddingSizeSmall),
              Text(message!, textAlign: TextAlign.center,
                  style: rubikRegular.copyWith(fontSize: Dimensions.fontSizeSmall, color: Theme.of(context).hintColor)),
            ],
            const SizedBox(height: Dimensions.paddingSizeExtraLarge),
            Row(
              children: [
                Expanded(child: _Btn(label: getTranslated('retry', context) ?? 'Retry', onTap: onRetry)),
                const SizedBox(width: Dimensions.paddingSizeDefault),
                Expanded(child: _Btn(label: '${getTranslated('stop', context) ?? 'Stop'} ($countdown)', onTap: onStop)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Btn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).primaryColor,
      borderRadius: BorderRadius.circular(Dimensions.radiusDefault),
      clipBehavior: Clip.hardEdge,
      child: KioskTap(
        onTap: onTap,
        child: Container(height: 50, alignment: Alignment.center, child: Text(label, style: rubikSemiBold.copyWith(color: Colors.white))),
      ),
    );
  }
}
