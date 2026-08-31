import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_added_to_cart_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_allergen_filter_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_deal_banner.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:provider/provider.dart';

void openKioskDealDetail(
  BuildContext context,
  KioskDeal deal, {
  CartModel? cart,
  int? cartIndex,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => KioskDealDetailScreen(
        deal: deal,
        cartIndex: cartIndex,
        initialComponents: cart?.isDeal == true ? cart!.components : null,
      ),
    ),
  );
}

void openKioskCartLine(BuildContext context, CartModel cart, {int? cartIndex}) {
  if (cart.isDeal && cart.dealId != null) {
    final deal = Provider.of<KioskDealProvider>(context, listen: false)
        .dealById(cart.dealId!);
    if (deal != null) {
      openKioskDealDetail(context, deal, cart: cart, cartIndex: cartIndex);
      return;
    }
  }
  if (cart.product != null) {
    openKioskCustomize(context, cart.product!,
        cart: cart, cartIndex: cartIndex);
  }
}

class KioskDealDetailScreen extends StatefulWidget {
  final KioskDeal deal;
  final int? cartIndex;
  final List<CartModel>? initialComponents;

  const KioskDealDetailScreen({
    super.key,
    required this.deal,
    this.cartIndex,
    this.initialComponents,
  });

  @override
  State<KioskDealDetailScreen> createState() => _KioskDealDetailScreenState();
}

class _KioskDealDetailScreenState extends State<KioskDealDetailScreen> {
  late KioskDeal _deal;
  late List<CartModel?> _slots;
  bool _busy = false;
  KioskDealProvider? _dealProvider;

  @override
  void initState() {
    super.initState();
    _deal = widget.deal;
    _slots = List<CartModel?>.filled(_deal.slots.length, null);
    final initial = widget.initialComponents;
    if (initial != null && initial.length == _slots.length) {
      _slots = List<CartModel?>.from(initial);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dealProvider = Provider.of<KioskDealProvider>(context, listen: false);
      _dealProvider!.addListener(_onDealsLive);
      _maybeAskAllergens();
      _refreshDeal();
      _autoConfigurePlainSlots();
    });
  }

  @override
  void dispose() {
    _dealProvider?.removeListener(_onDealsLive);
    super.dispose();
  }

  void _onDealsLive() {
    if (!mounted) return;
    final fresh = _dealProvider?.dealById(_deal.id);
    if (fresh == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _deal = fresh;
      if (_slots.length != fresh.slots.length) {
        _slots = List<CartModel?>.filled(fresh.slots.length, null);
      }
    });
  }

  Future<void> _maybeAskAllergens() async {
    if (KioskAllergenPreferences.instance.asked) return;
    await showKioskAllergenFilter(context);
  }

  Future<void> _refreshDeal() async {
    final fresh = await Provider.of<KioskDealProvider>(context, listen: false)
        .fetchDeal(_deal.id);
    if (!mounted || fresh == null) return;
    setState(() {
      _deal = fresh;
      if (_slots.length != fresh.slots.length) {
        _slots = List<CartModel?>.filled(fresh.slots.length, null);
      }
    });
    _autoConfigurePlainSlots();
  }

  void _autoConfigurePlainSlots() {
    if (!mounted) return;
    final slots = _deal.slots;
    bool changed = false;
    for (int i = 0; i < slots.length; i++) {
      if (_slots[i] != null) continue;
      if (kioskProductHasModifiers(slots[i])) continue;
      final productProvider =
          Provider.of<ProductProvider>(context, listen: false);
      productProvider.initData(slots[i], null);
      productProvider.initProductVariationStatus(0);
      _slots[i] = buildKioskCartModel(context, slots[i]);
      changed = true;
    }
    if (changed) setState(() {});
  }

  bool get _allConfigured =>
      _slots.isNotEmpty && _slots.every((s) => s != null);

  Future<void> _configureSlot(int index) async {
    final Product product = _deal.slots[index];
    openKioskCustomize(
      context,
      product,
      cart: _slots[index],
      onConfigured: (CartModel configured) {
        if (!mounted) return;
        setState(() => _slots[index] = configured);
      },
    );
  }

  void _addDealToCart() {
    if (!_allConfigured || _busy) return;
    if (!_deal.available) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(kioskTranslate(
            context, 'deal_not_available', 'This deal is no longer available')),
      ));
      return;
    }
    setState(() => _busy = true);
    final line = CartModel.deal(
      dealId: _deal.id,
      title: _deal.title,
      image: _deal.image,
      bundlePrice: _deal.bundlePrice,
      originalPrice: _deal.originalPrice,
      components: _slots.cast<CartModel>(),
    );
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.addToCart(line, widget.cartIndex);
    final splash = Provider.of<SplashProvider>(context, listen: false);
    Navigator.of(context).pushReplacement(
      KioskAddedToCartScreen.route(
        heroImage: KioskProductImageHelper.resolveUrl(
          productImageBaseUrl: splash.baseUrls?.dealImageUrl ??
              splash.baseUrls?.productImageUrl,
          filename: _deal.image,
        ),
        // Same payable the cart bar and cart screen show, coupon included —
        // "your total has been updated" has to name the total they will see.
        totalLabel: PriceConverterHelper.convertPrice(kioskPayableTotal(
            cartProvider.cartList,
            Provider.of<CouponProvider>(context, listen: false).discount ?? 0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final String bannerUrl = KioskProductImageHelper.resolveUrl(
      productImageBaseUrl:
          splash.baseUrls?.dealImageUrl ?? splash.baseUrls?.productImageUrl,
      filename: _deal.image,
    );
    final List<Product> products = _deal.slots;

    return Scaffold(
      backgroundColor: KioskUI.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 28),
                  ),
                  Expanded(
                    child: Text(
                      _deal.title,
                      textAlign: TextAlign.center,
                      style: loewMedium.copyWith(
                          fontSize: 22, color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
                children: [
                  // Same rules as the menu banner (one implementation, see
                  // KioskDealBannerImage): the box takes the artwork's own
                  // ratio so nothing is cropped, it stops at half the window
                  // on a large panel, and it starts at the leading edge. The
                  // old fixed `height: 220` at full width was an 8:1 box for a
                  // 2.4:1 image — almost all of the artwork was cropped away.
                  KioskDealBannerImage(
                    imageUrl: bannerUrl,
                    fallback: _DealFallbackBanner(deal: _deal),
                  ),
                  if ((_deal.description ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      _deal.description!,
                      style: swiss721Light.copyWith(
                          fontSize: 14, color: Colors.black87),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    kioskTranslate(context, 'included_items', 'Included')
                        .toUpperCase(),
                    style: loewMedium.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  for (int i = 0; i < products.length; i++)
                    _DealSlotCard(
                      product: products[i],
                      configured: _slots[i],
                      onCustomize: () => _configureSlot(i),
                    ),
                  const SizedBox(height: 24),
                  _DealPriceBreakdown(deal: _deal),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 24),
              child: SizedBox(
                width: double.infinity,
                height: 72,
                child: ElevatedButton(
                  onPressed: _allConfigured ? _addDealToCart : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: KioskUI.dark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFB9B5A6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    kioskTranslate(context, 'add_to_cart', 'Add to Cart')
                        .toUpperCase(),
                    style: loewMedium.copyWith(fontSize: 18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DealFallbackBanner extends StatelessWidget {
  final KioskDeal deal;
  const _DealFallbackBanner({required this.deal});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF6B4A2F), Color(0xFFB98E5E)],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: Text(
              deal.title.toUpperCase(),
              style: loewMedium.copyWith(color: Colors.white, fontSize: 26),
            ),
          ),
          if ((deal.badgeText ?? '').isNotEmpty ||
              (deal.subtitle ?? '').isNotEmpty)
            Container(
              width: 160,
              height: 160,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                  color: Color(0xFFF3F1DD), shape: BoxShape.circle),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((deal.badgeText ?? '').isNotEmpty)
                    Text(
                      deal.badgeText!,
                      textAlign: TextAlign.center,
                      style: loewMedium.copyWith(fontSize: 14),
                    ),
                  if ((deal.subtitle ?? '').isNotEmpty)
                    Text(
                      deal.subtitle!,
                      textAlign: TextAlign.center,
                      style: scotchDisplayLight.copyWith(fontSize: 14),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DealSlotCard extends StatelessWidget {
  final Product product;
  final CartModel? configured;
  final VoidCallback onCustomize;

  const _DealSlotCard({
    required this.product,
    required this.configured,
    required this.onCustomize,
  });

  @override
  Widget build(BuildContext context) {
    final splash = Provider.of<SplashProvider>(context, listen: false);
    final bool needsCustomize = kioskProductHasModifiers(product);
    final bool done = configured != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: KioskTap(
          onTap: needsCustomize || !done ? onCustomize : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: CustomImageWidget(
                      placeholder: Images.placeholderImage,
                      image: KioskProductImageHelper.heroImageUrl(
                        product: product,
                        productImageBaseUrl: splash.baseUrls?.productImageUrl,
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.name ?? '',
                          style: loewMedium.copyWith(fontSize: 14)),
                      Text(
                        PriceConverterHelper.convertPrice(product.price),
                        style: swiss721Light.copyWith(fontSize: 13),
                      ),
                      if (done && needsCustomize)
                        Text(
                          kioskTranslate(context, 'configured', 'Configured'),
                          style: loewRegular.copyWith(
                              fontSize: 11, color: KioskUI.popularGreen),
                        ),
                    ],
                  ),
                ),
                if (needsCustomize)
                  Text(
                    done
                        ? kioskTranslate(context, 'edit', 'Edit').toUpperCase()
                        : kioskTranslate(context, 'customize', 'Customize')
                            .toUpperCase(),
                    style: loewMedium.copyWith(fontSize: 11),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DealPriceBreakdown extends StatelessWidget {
  final KioskDeal deal;
  const _DealPriceBreakdown({required this.deal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                PriceConverterHelper.convertPrice(deal.originalPrice),
                style: swiss721Light.copyWith(
                  fontSize: 18,
                  color: const Color(0xFF888480),
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                PriceConverterHelper.convertPrice(deal.bundlePrice),
                style: loewMedium.copyWith(fontSize: 22),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${kioskTranslate(context, 'you_save', 'You save')} ${PriceConverterHelper.convertPrice(deal.savings)}'
            '${deal.savingsPercent > 0 ? ' (${deal.savingsPercent}%)' : ''}',
            style: loewRegular.copyWith(
                fontSize: 13, color: KioskUI.popularGreen),
          ),
        ],
      ),
    );
  }
}
