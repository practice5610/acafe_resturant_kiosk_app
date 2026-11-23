import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_deal_provider.dart';
import 'package:acafe_customer/features/kiosk/landscape/widgets/landscape_order_line_card.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

/// Phase 5 Part C: "+" is NOT wired to anything — the only combo logic that
/// exists in this app (`findKioskComboUpgrade` / `CartProvider.applyComboUpgrade`
/// / `openKioskComboSheet`) is an UPGRADE that only fires when the cart
/// already contains every product of a bundle; it cannot do "add this bundle
/// outright," which is what the Figma card and this constant's name mean. Set
/// to `false` before shipping to production unless that behaviour has been
/// built and reviewed — see docs/landscape/02-status.md ("Combo "+" — pending
/// decision") for the two proposed designs. `true` for now only so the card
/// still matches Figma during development. A plain mutable top-level (not
/// `const`) so a test can flip it and restore it — the value is still only
/// ever meant to be set once, at build/deploy time, not toggled at runtime.
bool kLandscapeComboEnabled = true;

const Color _kPanelBg = Color(0xFFFBF8EF);
const Color _kPanelBorder = Color(0xFFDED8C6);
const Color _kMutedText = Color(0xFF73736E);

/// B2 order panel (B-01 empty … B-03 item added). Always visible on the right
/// of the landscape menu; it replaces the portrait cart screen.
///
/// Rows reuse the existing [KioskOrderLineCard] (compact) so the thumbnail,
/// choices, EDIT and quantity stepper behave exactly as in portrait. Totals and
/// the item count come from the shared cart/coupon helpers. The combo card and
/// the coupon link are shown per the design; their actions are wired in Phase 4
/// (see the TODOs). CHECK OUT uses the existing checkout flow (Phase 5).
class LandscapeOrderPanel extends StatelessWidget {
  final double s;
  final VoidCallback onCheckout;
  final VoidCallback onCancelOrder;
  final VoidCallback onCoupon;
  final VoidCallback onCombo;

  /// Row index to outline green for ~2 s after it was just added (B-03).
  final int? highlightIndex;

  const LandscapeOrderPanel({
    super.key,
    required this.s,
    required this.onCheckout,
    required this.onCancelOrder,
    required this.onCoupon,
    required this.onCombo,
    this.highlightIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kPanelBg,
        border: Border(left: BorderSide(color: _kPanelBorder, width: 2)),
      ),
      child: Consumer2<CartProvider, CouponProvider>(
        builder: (context, cart, coupon, _) {
          final List cartList = cart.cartList;
          final int count = kioskCartItemCount(cart.cartList);
          final bool hasItems = count > 0;
          final double total =
              kioskPayableTotal(cart.cartList, coupon.discount ?? 0);

          return Padding(
            padding: EdgeInsets.only(left: 26 * s, right: 30 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 36 * s),
                _Header(
                    s: s,
                    count: count,
                    hasItems: hasItems,
                    onCancelOrder: onCancelOrder),
                // Gap measured against the rendered tree so the divider's
                // top lands at exactly 118 (Figma `Rectangle`, 2305:3860).
                SizedBox(height: 16 * s),
                Container(height: 1.5 * s, color: _kPanelBorder),
                Expanded(
                  child: hasItems
                      ? _ItemList(
                          s: s, count: cartList.length, highlight: highlightIndex)
                      : _EmptyState(s: s),
                ),
                _ComboCard(s: s, onTap: onCombo),
                SizedBox(height: 18 * s),
                _CouponLink(s: s, enabled: hasItems, onTap: onCoupon),
                SizedBox(height: 12 * s),
                _CheckoutButton(
                    s: s, enabled: hasItems, total: total, onTap: onCheckout),
                SizedBox(height: 28 * s),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final double s;
  final int count;
  final bool hasItems;
  final VoidCallback onCancelOrder;
  const _Header({
    required this.s,
    required this.count,
    required this.hasItems,
    required this.onCancelOrder,
  });

  @override
  Widget build(BuildContext context) {
    final String itemsLabel = count == 1 ? '1 item' : '$count items';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kioskTranslate(context, 'landscape_your_order', 'Your order'),
          style: loewBold.copyWith(
              fontSize: 24 * s, height: 1.0, color: const Color(0xFF0D0D0D)),
        ),
        // Title top is 36 (matches Figma); "items" label top must land at
        // 78 — gap measured against the rendered tree to hit that exactly.
        SizedBox(height: 18 * s),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                itemsLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: swiss721Light.copyWith(
                    fontSize: 17 * s, color: const Color(0xFF0D0D0D)),
              ),
            ),
            SizedBox(width: 12 * s),
            if (hasItems)
              KioskTap(
                onTap: onCancelOrder,
                child: Text(
                  kioskTranslate(
                      context, 'landscape_cancel_order', 'Cancel order'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: loewBold.copyWith(
                    fontSize: 15 * s,
                    color: Colors.black,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final double s;
  const _EmptyState({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 180 * s),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kioskTranslate(
                context, 'landscape_order_empty_title', 'Your order is empty'),
            textAlign: TextAlign.center,
            style: loewBold.copyWith(fontSize: 17 * s, color: Colors.black),
          ),
          SizedBox(height: 8 * s),
          Text(
            kioskTranslate(context, 'landscape_order_empty_body',
                'Tap a product to add it here.'),
            textAlign: TextAlign.center,
            style:
                swiss721Light.copyWith(fontSize: 16 * s, color: _kMutedText),
          ),
        ],
      ),
    );
  }
}

/// Scrolling item list. Newest item is at the bottom (B-02); the combo card,
/// coupon link and CHECK OUT stay fixed below it. Scrolls the newest line
/// into view when [highlight] starts pointing at it (B-03) — never on a
/// plain +/- tap, since the caller only ever sets [highlight] when the list
/// actually grew (see `landscape_menu_screen.dart`'s `landscapeJustAddedIndex`).
class _ItemList extends StatefulWidget {
  final double s;
  final int count;
  final int? highlight;
  const _ItemList({required this.s, required this.count, this.highlight});

  @override
  State<_ItemList> createState() => _ItemListState();
}

class _ItemListState extends State<_ItemList> {
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(covariant _ItemList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight != null && widget.highlight != oldWidget.highlight) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_controller.hasClients) return;
        _controller.animateTo(
          _controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    return ListView.separated(
      controller: _controller,
      padding: EdgeInsets.symmetric(vertical: 16 * widget.s),
      itemCount: widget.count,
      separatorBuilder: (_, __) => SizedBox(height: 12 * widget.s),
      itemBuilder: (context, index) {
        final line = cart.cartList[index];
        if (line == null) return const SizedBox.shrink();
        return LandscapeOrderLineCard(
          cart: line,
          index: index,
          s: widget.s,
          highlighted: widget.highlight == index,
        );
      },
    );
  }
}

/// MAKE IT A COMBO card. Figma shows a bundle's name, photo and price; that
/// data only exists for an actual `product_bundle` deal, so there is nothing
/// honest to show when the branch has none — the whole block (label + card)
/// collapses rather than rendering an empty/fake card. The tap still opens
/// the combo product steps in Phase 4; picking which deal to suggest here
/// (today: the first available bundle) is a UX call for that phase too.
class _ComboCard extends StatelessWidget {
  final double s;
  final VoidCallback onTap;
  const _ComboCard({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (!kLandscapeComboEnabled) return const SizedBox.shrink();
    return Consumer<KioskDealProvider>(
      builder: (context, dealsProvider, _) {
        List<KioskDeal> deals = const <KioskDeal>[];
        try {
          deals = dealsProvider.deals;
        } catch (_) {}
        KioskDeal? bundle;
        for (final KioskDeal deal in deals) {
          if (deal.available && deal.dealType == KioskDeal.typeProductBundle) {
            bundle = deal;
            break;
          }
        }
        if (bundle == null) return const SizedBox.shrink();

        final splash = Provider.of<SplashProvider>(context, listen: false);
        final String image = KioskProductImageHelper.resolveUrl(
          productImageBaseUrl:
              splash.baseUrls?.dealImageUrl ?? splash.baseUrls?.productImageUrl,
          filename: bundle.image,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              kioskTranslate(
                  context, 'landscape_make_it_a_combo', 'MAKE IT A COMBO'),
              style: loewBold.copyWith(
                  fontSize: 13 * s, color: _kMutedText, letterSpacing: 0.3),
            ),
            SizedBox(height: 10 * s),
            KioskTap(
              onTap: onTap,
              child: Container(
                height: 85 * s,
                padding: EdgeInsets.symmetric(horizontal: 14 * s),
                decoration: BoxDecoration(
                  color: _kPanelBg,
                  borderRadius: BorderRadius.circular(8 * s),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        kioskTranslate(
                            context, 'landscape_combo_meal', 'Combo meal'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: loewBold.copyWith(
                            fontSize: 15 * s, color: Colors.black, height: 1.1),
                      ),
                    ),
                    SizedBox(width: 8 * s),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6 * s),
                      child: CustomImageWidget(
                        emptyWhenMissing: true,
                        placeholder: Images.placeholderImage,
                        image: image,
                        width: 56 * s,
                        height: 68 * s,
                        fit: BoxFit.cover,
                      ),
                    ),
                    SizedBox(width: 10 * s),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bundle.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: loewBold.copyWith(
                                fontSize: 13 * s, color: Colors.black, height: 1.2),
                          ),
                          SizedBox(height: 4 * s),
                          Text(
                            PriceConverterHelper.convertPrice(bundle.bundlePrice),
                            style: swiss721Light.copyWith(
                                fontSize: 12 * s, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6 * s),
                    Container(
                      width: 26 * s,
                      height: 26 * s,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                          color: Colors.black, shape: BoxShape.circle),
                      child: Text('+',
                          style: loewMedium.copyWith(
                              fontSize: 18 * s, color: _kPanelBg, height: 1.0)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CouponLink extends StatelessWidget {
  final double s;
  final bool enabled;
  final VoidCallback onTap;
  const _CouponLink({required this.s, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // TODO(phase4): open the coupon pop-up (kiosk_coupon_screen).
    return Opacity(
      opacity: enabled ? 1.0 : 0.3,
      child: IgnorePointer(
        ignoring: !enabled,
        child: KioskTap(
          onTap: onTap,
          child: Row(
            children: [
              Text(
                kioskTranslate(
                    context, 'landscape_have_a_coupon', 'Have a coupon?'),
                style:
                    swiss721Light.copyWith(fontSize: 15 * s, color: _kMutedText),
              ),
              SizedBox(width: 6 * s),
              Text(
                kioskTranslate(context, 'landscape_enter_code', 'Enter code'),
                style: loewBold.copyWith(
                    fontSize: 15 * s,
                    color: Colors.black,
                    decoration: TextDecoration.underline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckoutButton extends StatelessWidget {
  final double s;
  final bool enabled;
  final double total;
  final VoidCallback onTap;
  const _CheckoutButton({
    required this.s,
    required this.enabled,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // TODO(phase5): swap to the dedicated landscape checkout path.
    return Opacity(
      opacity: enabled ? 1.0 : 0.3,
      child: Material(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(10 * s),
        clipBehavior: Clip.antiAlias,
        child: KioskTap(
          onTap: enabled ? onTap : null,
          child: Container(
            height: 64 * s,
            padding: EdgeInsets.symmetric(horizontal: 22 * s),
            alignment: Alignment.center,
            child: Row(
              children: [
                Text(
                  kioskTranslate(context, 'landscape_check_out', 'CHECK OUT'),
                  style: loewBold.copyWith(fontSize: 17 * s, color: Colors.white),
                ),
                const Spacer(),
                Text(
                  PriceConverterHelper.convertPrice(total),
                  style: swiss721Light.copyWith(
                      fontSize: 17 * s, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
