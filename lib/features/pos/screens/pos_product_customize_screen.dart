import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/common/widgets/custom_image_widget.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_sections.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_deal_detail_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/pos/domain/pos_customize_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_coupon_apply_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_context_menu.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/product_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Opens the POS product-customize landscape screen (Figma **1641:7080**).
///
/// Reuses [ProductProvider] + [buildKioskCartModel] — the same selection and
/// price math as the kiosk — but presents the POS layout and pops back to the
/// counter after save (no allergen gate, no kiosk confirmation beat).
void openPosCustomize(
  BuildContext context,
  Product product, {
  CartModel? cart,
  int? cartIndex,
  TextEditingController? customerNameController,
  TextEditingController? tableController,
  PosOrderType orderType = PosOrderType.dineIn,
  ValueChanged<PosOrderType>? onOrderTypeChanged,
}) {
  final cartProvider = Provider.of<CartProvider>(context, listen: false);
  final productProvider = Provider.of<ProductProvider>(context, listen: false);

  final variations = ProductHelper.effectiveVariations(product) ?? [];
  final addOns = product.addOns ?? [];
  final bool hasModifiers = variations.isNotEmpty ||
      addOns.isNotEmpty ||
      product.effectiveAddOnGroups.isNotEmpty;

  if (!hasModifiers) {
    if (cart != null || cartIndex != null) return;
    productProvider.initData(product, null);
    productProvider.initProductVariationStatus(0);
    cartProvider.addToCart(
      buildKioskCartModel(context, product),
      productProvider.cartIndex,
      showMessage: false,
    );
    return;
  }

  bool replaceOtherProductLines = false;
  if (cart == null) {
    for (int i = cartProvider.cartList.length - 1; i >= 0; i--) {
      final line = cartProvider.cartList[i];
      if (line?.product?.id == product.id && line?.isDeal != true) {
        cart = line;
        cartIndex = i;
        replaceOtherProductLines = true;
        break;
      }
    }
  }

  productProvider.initData(product, cart);
  productProvider.initProductVariationStatus(
      ProductHelper.effectiveVariations(product)?.length ?? 0);

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PosProductCustomizeScreen(
        product: product,
        cartIndex: cartIndex,
        initialInstruction: cart?.instruction,
        replaceOtherProductLines: replaceOtherProductLines,
        customerNameController: customerNameController,
        tableController: tableController,
        orderType: orderType,
        onOrderTypeChanged: onOrderTypeChanged,
      ),
    ),
  );
}

/// Edit an existing cart line from POS (deals still use the kiosk deal flow).
void openPosCartLine(BuildContext context, CartModel cart,
    {int? cartIndex,
    TextEditingController? customerNameController,
    TextEditingController? tableController,
    PosOrderType orderType = PosOrderType.dineIn,
    ValueChanged<PosOrderType>? onOrderTypeChanged}) {
  if (cart.isDeal && cart.dealId != null) {
    openKioskCartLine(context, cart, cartIndex: cartIndex);
    return;
  }
  if (cart.product != null) {
    openPosCustomize(
      context,
      cart.product!,
      cart: cart,
      cartIndex: cartIndex,
      customerNameController: customerNameController,
      tableController: tableController,
      orderType: orderType,
      onOrderTypeChanged: onOrderTypeChanged,
    );
  }
}

/// POS landscape product customization — Figma node **1641:7080**.
class PosProductCustomizeScreen extends StatefulWidget {
  final Product product;
  final int? cartIndex;
  final String? initialInstruction;
  final bool replaceOtherProductLines;
  final TextEditingController? customerNameController;
  final TextEditingController? tableController;
  final PosOrderType orderType;
  final ValueChanged<PosOrderType>? onOrderTypeChanged;

  const PosProductCustomizeScreen({
    super.key,
    required this.product,
    this.cartIndex,
    this.initialInstruction,
    this.replaceOtherProductLines = false,
    this.customerNameController,
    this.tableController,
    this.orderType = PosOrderType.dineIn,
    this.onOrderTypeChanged,
  });

  @override
  State<PosProductCustomizeScreen> createState() =>
      _PosProductCustomizeScreenState();
}

class _PosProductCustomizeScreenState extends State<PosProductCustomizeScreen> {
  late PosOrderType _orderType;
  late final TextEditingController _customerName;
  late final TextEditingController _table;
  late final bool _ownsCustomerControllers;
  String? _instruction;

  @override
  void initState() {
    super.initState();
    _orderType = widget.orderType;
    _ownsCustomerControllers = widget.customerNameController == null;
    _customerName = widget.customerNameController ?? TextEditingController();
    _table = widget.tableController ?? TextEditingController();
    final String initial = widget.initialInstruction?.trim() ?? '';
    _instruction = initial.isEmpty ? null : initial;
  }

  @override
  void dispose() {
    if (_ownsCustomerControllers) {
      _customerName.dispose();
      _table.dispose();
    }
    super.dispose();
  }

  Product get _product => widget.product;

  bool _validateVariations(
    BuildContext context,
    ProductProvider productProvider,
    Iterable<int> indexes,
  ) {
    final variations = ProductHelper.effectiveVariations(_product) ?? [];
    for (final int index in indexes) {
      if (index < 0 || index >= variations.length) continue;
      final v = variations[index];
      if (!v.isMultiSelect! &&
          v.isRequired! &&
          !productProvider.selectedVariations[index].contains(true)) {
        showCustomSnackBarHelper(
          '${getTranslated('choose_a_variation_from', context)} ${v.name}',
          isError: true,
        );
        return false;
      }
      if (v.isMultiSelect! &&
          (v.isRequired! ||
              productProvider.selectedVariations[index].contains(true)) &&
          v.min! >
              productProvider.selectedVariationLength(
                  productProvider.selectedVariations, index)) {
        showCustomSnackBarHelper(
          '${getTranslated('you_need_to_select_minimum', context)} ${v.min}',
          isError: true,
        );
        return false;
      }
    }
    return true;
  }

  bool _validateAddOnGroups(
    BuildContext context,
    ProductProvider productProvider,
  ) {
    for (final group in _product.effectiveAddOnGroups) {
      final List<int> indexes = [];
      for (final addon in group.addons) {
        final int? i = _product.indexOfAddOn(addon.id);
        if (i != null) indexes.add(i);
      }
      int selected = 0;
      for (final int i in indexes) {
        if (i < productProvider.addOnActiveList.length &&
            productProvider.addOnActiveList[i]) {
          selected++;
        }
      }
      final bool required = group.isRequired || group.min > 0;
      final int min = group.isSingle ? (required ? 1 : 0) : group.min;
      if (required && selected < min) {
        showCustomSnackBarHelper(
          '${getTranslated('choose_a_variation_from', context)} ${group.name ?? ''}',
          isError: true,
        );
        return false;
      }
    }
    return true;
  }

  bool _validate(BuildContext context, ProductProvider productProvider) {
    final variations = ProductHelper.effectiveVariations(_product) ?? [];
    return _validateVariations(
          context,
          productProvider,
          List.generate(variations.length, (i) => i),
        ) &&
        _validateAddOnGroups(context, productProvider);
  }

  void _addToCart(ProductProvider productProvider) {
    if (!_validate(context, productProvider)) return;
    final CartModel built = buildKioskCartModel(
      context,
      _product,
      instruction: _instruction,
    );
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final int? index = widget.cartIndex ?? productProvider.cartIndex;
    cartProvider.addToCart(built, index, showMessage: false);
    if (widget.replaceOtherProductLines &&
        _product.id != null &&
        index != null &&
        index >= 0) {
      cartProvider.removeOtherLinesForProduct(_product.id!, index);
    }
    Navigator.of(context).pop();
  }

  void _incrementLine(int index) {
    final CartProvider cart = context.read<CartProvider>();
    final CartModel? line = cart.cartList[index];
    if (line == null) return;
    cart.setQuantity(
      isIncrement: true,
      cart: line,
      fromProductView: false,
    );
  }

  void _decrementLine(int index) {
    final CartProvider cart = context.read<CartProvider>();
    final CartModel? line = cart.cartList[index];
    if (line == null) return;
    if ((line.quantity ?? 1) <= 1) {
      cart.removeFromCart(index);
    } else {
      cart.setQuantity(
        isIncrement: false,
        cart: line,
        fromProductView: false,
      );
    }
  }

  void _editCartLine(int index) {
    final CartModel? line = context.read<CartProvider>().cartList[index];
    if (line == null || line.product == null) return;
    if (line.isDeal) {
      openKioskCartLine(context, line, cartIndex: index);
      return;
    }
    final Product product = line.product!;
    final productProvider = context.read<ProductProvider>();
    productProvider.initData(product, line);
    productProvider.initProductVariationStatus(
        ProductHelper.effectiveVariations(product)?.length ?? 0);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PosProductCustomizeScreen(
          product: product,
          cartIndex: index,
          initialInstruction: line.instruction,
          replaceOtherProductLines: false,
          customerNameController: widget.customerNameController,
          tableController: widget.tableController,
          orderType: _orderType,
          onOrderTypeChanged: widget.onOrderTypeChanged,
        ),
      ),
    );
  }

  Future<void> _openReceiptOptions(BuildContext anchorContext) async {
    final PosReceiptMenuAction? action = await showPosReceiptContextMenu(
      context: context,
      anchorContext: anchorContext,
    );
    if (action == null || !mounted) return;
    final CouponProvider coupon = context.read<CouponProvider>();
    final CartProvider cart = context.read<CartProvider>();
    final double orderAmount = kioskOrderAmountBeforeCoupon(cart.cartList);
    switch (action) {
      case PosReceiptMenuAction.applyDiscount:
        await showPosCouponApplyDialog(
          context: context,
          orderAmount: orderAmount,
          title: 'Apply discount',
        );
      case PosReceiptMenuAction.applyCustomDiscount:
        await showPosCouponApplyDialog(
          context: context,
          orderAmount: orderAmount,
          title: 'Apply custom discount',
        );
      case PosReceiptMenuAction.removeDiscount:
        if ((coupon.discount ?? 0) <= 0 && coupon.coupon == null) {
          showCustomSnackBarHelper('No discount to remove', isError: false);
          return;
        }
        coupon.removeCouponData(true);
        showCustomSnackBarHelper('Discount removed', isError: false);
      case PosReceiptMenuAction.priceOverride:
      case PosReceiptMenuAction.taxExempt:
      case PosReceiptMenuAction.compItem:
      case PosReceiptMenuAction.moveTable:
      case PosReceiptMenuAction.holdFire:
      case PosReceiptMenuAction.sendKitchen:
      case PosReceiptMenuAction.repeatItem:
      case PosReceiptMenuAction.partialPayment:
      case PosReceiptMenuAction.giftCard:
      case PosReceiptMenuAction.loyaltyPoints:
        break;
    }
  }

  void _pay() {
    if (!context.read<CartProvider>().cartList.any((l) => l != null)) return;
    Navigator.of(context).pop();
    context.go(PosRoutes.payment);
  }

  @override
  Widget build(BuildContext context) {
    final splash = context.watch<SplashProvider>();
    final cart = context.watch<CartProvider>();
    final coupon = context.watch<CouponProvider>();
    final PosMetrics? metrics = PosMetrics.maybeOf(context);
    final bool sideReceipt = metrics?.showsSideReceipt ?? true;

    final double discount = coupon.discount ?? 0;
    final double subtotal = kioskCartTotal(cart.cartList);
    final double total = kioskPayableTotal(cart.cartList, discount);
    final bool hasItems = cart.cartList.any((line) => line != null);

    final PosReceiptPanel receipt = PosReceiptPanel(
      width: null,
      orderType: _orderType,
      onOrderTypeChanged: (t) {
        setState(() => _orderType = t);
        widget.onOrderTypeChanged?.call(t);
      },
      customerNameController: _customerName,
      tableController: _table,
      subtotal: subtotal,
      discount: discount,
      total: total,
      orderList: hasItems
          ? PosReceiptOrderList(
              lines: cart.cartList,
              imageBaseUrl: splash.baseUrls?.productImageUrl,
              dealImageBaseUrl: splash.baseUrls?.dealImageUrl,
              onIncrement: _incrementLine,
              onDecrement: _decrementLine,
              onEdit: _editCartLine,
            )
          : null,
      onOptions: _openReceiptOptions,
      onPay: hasItems ? _pay : null,
    );

    return Scaffold(
      backgroundColor: PosCustomizeSpec.pageBg,
      body: SafeArea(
        child: Consumer<ProductProvider>(
          builder: (context, productProvider, _) {
            final sections = KioskCustomizeSections.of(_product);
            final double lineTotal = kioskLineTotal(
              buildKioskCartModel(
                context,
                _product,
                instruction: _instruction,
              ),
            );
            final String priceLabel =
                PriceConverterHelper.convertPrice(lineTotal);
            final String addLabel =
                (getTranslated('add_to_cart', context) ?? 'Add to Cart')
                    .trim();
            final String ctaLabel =
                '${addLabel.isEmpty ? 'ADD TO CART' : addLabel.toUpperCase()}  •  $priceLabel';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _CustomizePane(
                          product: _product,
                          productProvider: productProvider,
                          sections: sections,
                          onBack: () => Navigator.of(context).pop(),
                        ),
                      ),
                      if (sideReceipt)
                        SizedBox(
                          width: PosResponsive.receiptPanelWidth(
                            MediaQuery.sizeOf(context).width,
                          ),
                          child: receipt,
                        ),
                    ],
                  ),
                ),
                _AddToCartFooter(
                  label: ctaLabel,
                  onTap: () => _addToCart(productProvider),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AddToCartFooter extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddToCartFooter({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: PosCustomizeSpec.footerHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: PosCustomizeSpec.footerPadH,
        vertical: PosCustomizeSpec.footerPadV,
      ),
      decoration: const BoxDecoration(
        color: PosCustomizeSpec.pageBg,
        border: Border(
          top: BorderSide(
            color: PosCustomizeSpec.mutedBorder,
            width: PosCustomizeSpec.footerBorder,
          ),
        ),
      ),
      child: Material(
        color: PosCustomizeSpec.ink,
        borderRadius: BorderRadius.circular(PosCustomizeSpec.ctaRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(PosCustomizeSpec.ctaRadius),
          child: Center(
            child: Text(
              label,
              style: loewExtraBold.copyWith(
                fontSize: PosCustomizeSpec.ctaLabelSize,
                letterSpacing: PosCustomizeSpec.ctaLetterSpacing,
                color: PosCustomizeSpec.plusLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomizePane extends StatelessWidget {
  final Product product;
  final ProductProvider productProvider;
  final KioskCustomizeSections sections;
  final VoidCallback onBack;

  const _CustomizePane({
    required this.product,
    required this.productProvider,
    required this.sections,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final splash = context.read<SplashProvider>();
    final String? imageBase = splash.baseUrls?.productImageUrl;

    return ColoredBox(
      color: PosCustomizeSpec.pageBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PosCustomizeSpec.panePadding,
          PosCustomizeSpec.panePadding,
          PosCustomizeSpec.panePadding,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              productName: product.name ?? '',
              quantity: productProvider.quantity ?? 1,
              onBack: onBack,
              onMinus: () {
                if ((productProvider.quantity ?? 1) > 1) {
                  productProvider.setQuantity(false);
                }
              },
              onPlus: () => productProvider.setQuantity(true),
            ),
            const SizedBox(height: PosCustomizeSpec.sectionGap),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in sections.size) ...[
                      _VariationSection(
                        title: entry.value.name?.isNotEmpty == true
                            ? entry.value.name!
                            : 'Size',
                        variation: entry.value,
                        variationIndex: entry.key,
                        product: product,
                        productProvider: productProvider,
                        imageBaseUrl: imageBase,
                      ),
                      const SizedBox(height: PosCustomizeSpec.sectionGap),
                    ],
                    for (final entry in sections.dietary) ...[
                      _VariationSection(
                        title: entry.value.name?.isNotEmpty == true
                            ? entry.value.name!
                            : (getTranslated('choose_your_dietary', context) ??
                                'Choose your dietary'),
                        variation: entry.value,
                        variationIndex: entry.key,
                        product: product,
                        productProvider: productProvider,
                        imageBaseUrl: imageBase,
                      ),
                      const SizedBox(height: PosCustomizeSpec.sectionGap),
                    ],
                    if (product.effectiveAddOnGroups.isNotEmpty) ...[
                      for (final group in product.effectiveAddOnGroups) ...[
                        _AddOnsSection(
                          group: group,
                          product: product,
                          productProvider: productProvider,
                        ),
                        const SizedBox(height: PosCustomizeSpec.sectionGap),
                      ],
                    ],
                    for (final entry in sections.cupCan) ...[
                      _CupCanSection(
                        variation: entry.value,
                        variationIndex: entry.key,
                        product: product,
                        productProvider: productProvider,
                        imageBaseUrl: imageBase,
                      ),
                      const SizedBox(height: PosCustomizeSpec.sectionGap),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String productName;
  final int quantity;
  final VoidCallback onBack;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _Header({
    required this.productName,
    required this.quantity,
    required this.onBack,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: PosCustomizeSpec.panelBg,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(PosCustomizeSpec.backButtonRadius),
            side: const BorderSide(
              color: PosCustomizeSpec.ink,
              width: PosCustomizeSpec.backButtonBorder,
            ),
          ),
          child: InkWell(
            onTap: onBack,
            borderRadius:
                BorderRadius.circular(PosCustomizeSpec.backButtonRadius),
            child: const SizedBox(
              width: PosCustomizeSpec.backButton,
              height: PosCustomizeSpec.backButton,
              child: Icon(
                Icons.chevron_left,
                size: PosCustomizeSpec.backIcon,
                color: PosCustomizeSpec.ink,
              ),
            ),
          ),
        ),
        const SizedBox(width: PosCustomizeSpec.headerGap),
        Expanded(
          child: Text(
            productName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: loewExtraBold.copyWith(
              fontSize: PosCustomizeSpec.titleSize,
              height: 1.1,
              color: PosCustomizeSpec.ink,
            ),
          ),
        ),
        const SizedBox(width: PosCustomizeSpec.headerGap),
        _QtyStepper(
          quantity: quantity,
          onMinus: onMinus,
          onPlus: onPlus,
        ),
      ],
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int quantity;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  const _QtyStepper({
    required this.quantity,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QtyButton(
          label: '−',
          filled: false,
          onTap: onMinus,
        ),
        const SizedBox(width: PosCustomizeSpec.qtyGap),
        SizedBox(
          width: PosCustomizeSpec.qtyButton,
          height: PosCustomizeSpec.qtyButton,
          child: Center(
            child: Text(
              '$quantity',
              style: loewExtraBold.copyWith(
                fontSize: PosCustomizeSpec.qtyValueSize,
                color: PosCustomizeSpec.ink,
              ),
            ),
          ),
        ),
        const SizedBox(width: PosCustomizeSpec.qtyGap),
        _QtyButton(
          label: '+',
          filled: true,
          onTap: onPlus,
        ),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _QtyButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.black : PosCustomizeSpec.panelBg,
      borderRadius: BorderRadius.circular(PosCustomizeSpec.qtyRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosCustomizeSpec.qtyRadius),
        child: Container(
          width: PosCustomizeSpec.qtyButton,
          height: PosCustomizeSpec.qtyButton,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosCustomizeSpec.qtyRadius),
            border: filled
                ? null
                : Border.all(
                    color: PosCustomizeSpec.mutedBorder,
                    width: PosCustomizeSpec.qtyBorder,
                  ),
          ),
          child: Text(
            label,
            style: loewExtraBold.copyWith(
              fontSize: PosCustomizeSpec.qtyGlyph,
              color: filled ? PosCustomizeSpec.plusLabel : PosCustomizeSpec.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PosCustomizeSpec.sectionTitleGap),
      child: Text(
        title,
        style: loewExtraBold.copyWith(
          fontSize: PosCustomizeSpec.sectionTitleSize,
          color: PosCustomizeSpec.ink,
        ),
      ),
    );
  }
}

class _VariationSection extends StatelessWidget {
  final String title;
  final Variation variation;
  final int variationIndex;
  final Product product;
  final ProductProvider productProvider;
  final String? imageBaseUrl;

  const _VariationSection({
    required this.title,
    required this.variation,
    required this.variationIndex,
    required this.product,
    required this.productProvider,
    required this.imageBaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final values = variation.variationValues ?? [];
    if (values.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        LayoutBuilder(
          builder: (context, constraints) {
            final double gap = PosCustomizeSpec.dietaryCardGap;
            final double available = constraints.maxWidth;
            final int count = values.length;
            final double ideal = PosCustomizeSpec.dietaryCardWidth;
            final double totalIdeal = count * ideal + (count - 1) * gap;
            final double cardWidth = totalIdeal <= available
                ? ideal
                : ((available - gap * (count - 1)) / count).clamp(96.0, ideal);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (int i = 0; i < values.length; i++) ...[
                    if (i > 0) SizedBox(width: gap),
                    _DietaryCard(
                      width: cardWidth,
                      name: values[i].level?.trim() ?? '',
                      imageUrl: KioskProductImageHelper.optionCardImageUrl(
                        value: values[i],
                        productImageBaseUrl: imageBaseUrl,
                      ),
                      selected: productProvider
                              .selectedVariations[variationIndex][i] ??
                          false,
                      onTap: () {
                        productProvider.setCartVariationIndex(
                          variationIndex,
                          i,
                          product,
                          variation.isMultiSelect!,
                        );
                        productProvider.checkIsRequiredSelected(
                          index: variationIndex,
                          isMultiSelect: variation.isMultiSelect!,
                          variations: productProvider
                              .selectedVariations[variationIndex],
                          min: variation.min,
                          max: variation.max,
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DietaryCard extends StatelessWidget {
  final double width;
  final String name;
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  const _DietaryCard({
    required this.width,
    required this.name,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosCustomizeSpec.panelBg,
      borderRadius:
          BorderRadius.circular(PosCustomizeSpec.dietaryCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(PosCustomizeSpec.dietaryCardRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: width,
          height: PosCustomizeSpec.dietaryCardHeight,
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(PosCustomizeSpec.dietaryCardRadius),
            border: Border.all(
              color: selected ? Colors.black : PosCustomizeSpec.mutedBorder,
              width: selected
                  ? PosCustomizeSpec.dietaryBorderSelected
                  : PosCustomizeSpec.dietaryBorder,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: selected
                    ? Container(
                        width: PosCustomizeSpec.dietaryRadio,
                        height: PosCustomizeSpec.dietaryRadio,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 8,
                          color: Colors.white,
                        ),
                      )
                    : Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PosCustomizeSpec.mutedBorder,
                            width: 0.75,
                          ),
                        ),
                      ),
              ),
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SizedBox(
                        width: PosCustomizeSpec.dietaryImage,
                        height: PosCustomizeSpec.dietaryImage,
                        child: imageUrl.isEmpty
                            ? const SizedBox.shrink()
                            : CustomImageWidget(
                                image: imageUrl,
                                fit: BoxFit.contain,
                                cacheWidth: 200,
                              ),
                      ),
                    ),
                  ),
                  Text(
                    name.toUpperCase(),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: loewMedium.copyWith(
                      fontSize: PosCustomizeSpec.dietaryLabelSize,
                      height: 1.0,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddOnsSection extends StatelessWidget {
  final AddOnGroup group;
  final Product product;
  final ProductProvider productProvider;

  const _AddOnsSection({
    required this.group,
    required this.product,
    required this.productProvider,
  });

  String _title(BuildContext context) {
    final String name = (group.name != null && group.name!.isNotEmpty)
        ? group.name!
        : (getTranslated('add_add_ons', context) ?? 'Add add-ons');
    return group.isRequired ? '$name *' : name;
  }

  String _addonImageUrl(BuildContext context, AddOns addon) {
    if (!addon.hasImage) return '';
    final splash = Provider.of<SplashProvider>(context, listen: false);
    return '${splash.baseUrls?.addonImageUrl}/${addon.image}';
  }

  @override
  Widget build(BuildContext context) {
    final List<int> groupIndexes = [
      for (final addon in group.addons)
        if (product.indexOfAddOn(addon.id) != null)
          product.indexOfAddOn(addon.id)!,
    ];
    final List<int> defaultIndexes = [
      for (final addon in group.addons)
        if (addon.isDefault && product.indexOfAddOn(addon.id) != null)
          product.indexOfAddOn(addon.id)!,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(_title(context)),
        LayoutBuilder(
          builder: (context, constraints) {
            final double gapH = PosCustomizeSpec.addonCardGapH;
            final double gapV = PosCustomizeSpec.addonCardGapV;
            final int columns = PosCustomizeSpec.addonColumns;
            final double cardWidth = ((constraints.maxWidth -
                        gapH * (columns - 1)) /
                    columns)
                .clamp(120.0, PosCustomizeSpec.addonCardWidth);

            return Wrap(
              spacing: gapH,
              runSpacing: gapV,
              children: [
                for (final addon in group.addons)
                  if (product.indexOfAddOn(addon.id) != null)
                    Builder(builder: (context) {
                      final int index = product.indexOfAddOn(addon.id)!;
                      final bool selected =
                          index < productProvider.addOnActiveList.length &&
                              productProvider.addOnActiveList[index];
                      final int quantity =
                          index < productProvider.addOnQtyList.length
                              ? (productProvider.addOnQtyList[index] ?? 1)
                              : 1;
                      final bool isDefault = addon.isDefault;
                      return _AddOnCard(
                        width: cardWidth,
                        name: addon.name ?? '',
                        priceDelta: addon.effectivePrice,
                        imageUrl: _addonImageUrl(context, addon),
                        selected: selected,
                        quantity: quantity,
                        showQuantity:
                            selected && !group.isSingle && !isDefault,
                        onTap: () {
                          if (isDefault) return;
                          productProvider.toggleAddOnInGroup(
                            index: index,
                            isSingle: group.isSingle,
                            groupIndexes: groupIndexes,
                            isRequired: group.isRequired,
                            maxSelect: group.max,
                            defaultIndexes: defaultIndexes,
                          );
                        },
                        onIncrement: () =>
                            productProvider.setAddOnQuantity(true, index),
                        onDecrement: () {
                          if (quantity > 1) {
                            productProvider.setAddOnQuantity(false, index);
                          } else {
                            productProvider.toggleAddOnInGroup(
                              index: index,
                              isSingle: group.isSingle,
                              groupIndexes: groupIndexes,
                              isRequired: group.isRequired,
                              maxSelect: group.max,
                              defaultIndexes: defaultIndexes,
                            );
                          }
                        },
                      );
                    }),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AddOnCard extends StatelessWidget {
  final double width;
  final String name;
  final double priceDelta;
  final String imageUrl;
  final bool selected;
  final int quantity;
  final bool showQuantity;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _AddOnCard({
    required this.width,
    required this.name,
    required this.priceDelta,
    required this.imageUrl,
    required this.selected,
    required this.quantity,
    required this.showQuantity,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosCustomizeSpec.panelBg,
      borderRadius: BorderRadius.circular(PosCustomizeSpec.addonCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosCustomizeSpec.addonCardRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: width,
          height: PosCustomizeSpec.addonCardHeight,
          padding: const EdgeInsets.fromLTRB(
            PosCustomizeSpec.addonPadH,
            PosCustomizeSpec.addonPadTop,
            PosCustomizeSpec.addonPadH,
            PosCustomizeSpec.addonPadBottom,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(PosCustomizeSpec.addonCardRadius),
            border: Border.all(
              color: selected ? Colors.black : PosCustomizeSpec.mutedBorder,
              width: selected ? 1.0 : 0.788,
            ),
          ),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  priceDelta > 0 ? kioskAddonPriceLabel(priceDelta) : '',
                  style: swiss721Light.copyWith(
                    fontSize: PosCustomizeSpec.addonPriceSize,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: imageUrl.isEmpty
                    ? const SizedBox.shrink()
                    : CustomImageWidget(
                        image: imageUrl,
                        fit: BoxFit.contain,
                        cacheWidth: 240,
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                name.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: loewMedium.copyWith(
                  fontSize: PosCustomizeSpec.addonLabelSize,
                  height: 1.2,
                  color: Colors.black,
                ),
              ),
              if (showQuantity) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MiniQtyButton(
                      label: '−',
                      filled: false,
                      onTap: onDecrement,
                    ),
                    const SizedBox(width: PosCustomizeSpec.addonMiniQtyGap),
                    SizedBox(
                      width: PosCustomizeSpec.addonMiniQty,
                      height: PosCustomizeSpec.addonMiniQty,
                      child: Center(
                        child: Text(
                          '$quantity',
                          style: loewExtraBold.copyWith(
                            fontSize: PosCustomizeSpec.addonMiniQtyGlyph,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: PosCustomizeSpec.addonMiniQtyGap),
                    _MiniQtyButton(
                      label: '+',
                      filled: true,
                      onTap: onIncrement,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniQtyButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _MiniQtyButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? Colors.black : PosCustomizeSpec.panelBg,
      borderRadius:
          BorderRadius.circular(PosCustomizeSpec.addonMiniQtyRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(PosCustomizeSpec.addonMiniQtyRadius),
        child: Container(
          width: PosCustomizeSpec.addonMiniQty,
          height: PosCustomizeSpec.addonMiniQty,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(PosCustomizeSpec.addonMiniQtyRadius),
            border: Border.all(
              color: filled ? Colors.black : PosCustomizeSpec.mutedBorder,
              width: PosCustomizeSpec.addonMiniQtyBorder,
            ),
          ),
          child: Text(
            label,
            style: loewExtraBold.copyWith(
              fontSize: PosCustomizeSpec.addonMiniQtyGlyph,
              height: 1,
              color: filled ? const Color(0xFFF3F3DD) : Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _CupCanSection extends StatelessWidget {
  final Variation variation;
  final int variationIndex;
  final Product product;
  final ProductProvider productProvider;
  final String? imageBaseUrl;

  const _CupCanSection({
    required this.variation,
    required this.variationIndex,
    required this.product,
    required this.productProvider,
    required this.imageBaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    final values = variation.variationValues ?? [];
    if (values.isEmpty) return const SizedBox.shrink();
    final title = variation.name?.isNotEmpty == true
        ? variation.name!
        : (getTranslated('can_or_cup', context) ?? 'Can or cup?');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title),
        LayoutBuilder(
          builder: (context, constraints) {
            final double gap = PosCustomizeSpec.vesselCardGap;
            return Row(
              children: [
                for (int i = 0; i < values.length; i++) ...[
                  if (i > 0) SizedBox(width: gap),
                  Expanded(
                    child: _VesselCard(
                      height: PosCustomizeSpec.vesselCardHeight,
                      name: values[i].level?.trim() ?? '',
                      assetImage:
                          kioskLocalVesselAsset(values[i].level?.trim() ?? ''),
                      imageUrl: KioskProductImageHelper.optionCardImageUrl(
                        value: values[i],
                        productImageBaseUrl: imageBaseUrl,
                      ),
                      selected: productProvider
                              .selectedVariations[variationIndex][i] ??
                          false,
                      onTap: () {
                        productProvider.setCartVariationIndex(
                          variationIndex,
                          i,
                          product,
                          variation.isMultiSelect!,
                        );
                        productProvider.checkIsRequiredSelected(
                          index: variationIndex,
                          isMultiSelect: variation.isMultiSelect!,
                          variations: productProvider
                              .selectedVariations[variationIndex],
                          min: variation.min,
                          max: variation.max,
                        );
                      },
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _VesselCard extends StatelessWidget {
  final double height;
  final String name;
  final String? assetImage;
  final String imageUrl;
  final bool selected;
  final VoidCallback onTap;

  const _VesselCard({
    required this.height,
    required this.name,
    required this.assetImage,
    required this.imageUrl,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosCustomizeSpec.panelBg,
      borderRadius: BorderRadius.circular(PosCustomizeSpec.vesselCardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosCustomizeSpec.vesselCardRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: height,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(PosCustomizeSpec.vesselCardRadius),
            border: Border.all(
              color: selected ? Colors.black : PosCustomizeSpec.mutedBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: assetImage != null
                    ? Image.asset(assetImage!, fit: BoxFit.contain)
                    : imageUrl.isEmpty
                        ? const SizedBox.shrink()
                        : CustomImageWidget(
                            image: imageUrl,
                            fit: BoxFit.contain,
                            cacheWidth: 320,
                          ),
              ),
              const SizedBox(height: 8),
              Text(
                name.toUpperCase(),
                style: loewExtraBold.copyWith(
                  fontSize: PosCustomizeSpec.vesselLabelSize,
                  color: PosCustomizeSpec.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
