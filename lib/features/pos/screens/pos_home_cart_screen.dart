import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/category/domain/category_model.dart';
import 'package:acafe_customer/features/category/providers/category_provider.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_menu_filter.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_deal_detail_screen.dart';
import 'package:acafe_customer/features/language/providers/localization_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/domain/pos_routes.dart';
import 'package:acafe_customer/features/pos/widgets/pos_category_sidebar.dart';
import 'package:acafe_customer/features/pos/widgets/pos_filter_pill.dart';
import 'package:acafe_customer/features/pos/widgets/pos_product_grid.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:acafe_customer/features/pos/widgets/pos_search_field.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/product_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// POS home — category sidebar, product grid, purchase receipt.
///
/// Figma: empty cart **1642:1087**, cart-active **1641:1968**. Same three-pane
/// screen; the receipt pane swaps empty-state chrome for order lines + PAY
/// when [CartProvider] has items.
class PosHomeCartScreen extends StatefulWidget {
  const PosHomeCartScreen({super.key});

  @override
  State<PosHomeCartScreen> createState() => _PosHomeCartScreenState();
}

class _PosHomeCartScreenState extends State<PosHomeCartScreen> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _customerName = TextEditingController();
  final TextEditingController _table = TextEditingController();

  PosOrderType _orderType = PosOrderType.dineIn;
  String _query = '';

  /// Figma paints POPULAR as the active pill on the empty-cart frame.
  String? _selectedTag = PosHomeSpec.filterPillLabels.first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMenu());
  }

  @override
  void dispose() {
    _search.dispose();
    _customerName.dispose();
    _table.dispose();
    super.dispose();
  }

  Future<void> _loadMenu() async {
    if (!mounted) return;
    final category = context.read<CategoryProvider>();
    final locale = context.read<LocalizationProvider>().locale.languageCode;
    await category.ensureKioskMenuReady(localeCode: locale);
  }

  void _selectCategory(CategoryModel category) {
    context.read<CategoryProvider>().selectKioskCategory('${category.id}');
  }

  void _addToCart(Product product) {
    final branch = ProductHelper.getBranchProductVariationWithPrice(product);
    final double price = branch.price ?? product.price ?? 0;
    final double discounted = PriceConverterHelper.convertWithDiscount(
          price,
          product.discount,
          product.discountType,
        ) ??
        price;
    context.read<CartProvider>().addToCart(
          CartModel(
            price,
            discounted,
            const [],
            price - discounted,
            1,
            0,
            const [],
            product,
            const [],
          ),
          null,
          showMessage: false,
        );
  }

  /// Products for the selected category, narrowed by the active tag pill and
  /// the search box.
  List<Product> _visibleProducts(CategoryProvider category) {
    final String? selectedId = category.selectedSubCategoryId;
    if (selectedId == null) return const [];

    List<Product> products = category
        .kioskProductsForCategoryIds([int.tryParse(selectedId) ?? -1]);

    if (_selectedTag != null) {
      final filtered = filterKioskProductsByTag(
        products: products,
        pillLabels: {_selectedTag!},
      );
      if (filtered.isNotEmpty) products = filtered;
    }

    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      products = products
          .where((p) => (p.name ?? '').toLowerCase().contains(q))
          .toList();
    }

    return products;
  }

  List<CartModel?> get _cartLines =>
      context.read<CartProvider>().cartList;

  bool get _cartHasItems =>
      _cartLines.any((line) => line != null);

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

  void _editLine(int index) {
    final CartModel? line = context.read<CartProvider>().cartList[index];
    if (line == null) return;
    openKioskCartLine(context, line, cartIndex: index);
  }

  void _pay() {
    if (!_cartHasItems) return;
    context.go(PosRoutes.payment);
  }

  PosReceiptPanel _receiptPanel({
    required List<CartModel?> cartList,
    required String? imageBaseUrl,
    String? dealImageBaseUrl,
    required double subtotal,
    required double discount,
    required double total,
    double? width = PosHomeSpec.receiptWidth,
    VoidCallback? onOrderTypeTick,
  }) {
    final bool hasItems = cartList.any((line) => line != null);

    return PosReceiptPanel(
      width: width,
      orderType: _orderType,
      onOrderTypeChanged: (t) {
        setState(() => _orderType = t);
        onOrderTypeTick?.call();
      },
      customerNameController: _customerName,
      tableController: _table,
      subtotal: subtotal,
      discount: discount,
      total: total,
      orderList: hasItems
          ? PosReceiptOrderList(
              lines: cartList,
              imageBaseUrl: imageBaseUrl,
              dealImageBaseUrl: dealImageBaseUrl,
              onIncrement: _incrementLine,
              onDecrement: _decrementLine,
              onEdit: _editLine,
            )
          : null,
      onPay: hasItems ? _pay : null,
    );
  }

  void _openReceiptSheet({
    required double subtotal,
    required double discount,
    required double total,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PosHomeSpec.panelBg,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final CartProvider cart = context.watch<CartProvider>();
            final CouponProvider coupon = context.watch<CouponProvider>();
            final double sheetDiscount = coupon.discount ?? 0;
            final double sheetSubtotal = kioskCartTotal(cart.cartList);
            final double sheetTotal =
                kioskPayableTotal(cart.cartList, sheetDiscount);
            return SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.92,
              child: _receiptPanel(
                width: null,
                cartList: cart.cartList,
                imageBaseUrl:
                    context.read<SplashProvider>().baseUrls?.productImageUrl,
                dealImageBaseUrl:
                    context.read<SplashProvider>().baseUrls?.dealImageUrl,
                subtotal: sheetSubtotal,
                discount: sheetDiscount,
                total: sheetTotal,
                onOrderTypeTick: () => setSheetState(() {}),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = context.watch<CategoryProvider>();
    final cart = context.watch<CartProvider>();
    final coupon = context.watch<CouponProvider>();
    final splash = context.read<SplashProvider>();
    final PosMetrics? metrics = PosMetrics.maybeOf(context);
    final bool sideReceipt = metrics?.showsSideReceipt ?? true;

    final categories = category.categoryList ?? const <CategoryModel>[];
    final selectedId = category.selectedSubCategoryId;

    final products = _visibleProducts(category);
    final double discount = coupon.discount ?? 0;
    final double subtotal = kioskCartTotal(cart.cartList);
    final double total = kioskPayableTotal(cart.cartList, discount);

    final PosReceiptPanel receipt = _receiptPanel(
      cartList: cart.cartList,
      imageBaseUrl: splash.baseUrls?.productImageUrl,
      dealImageBaseUrl: splash.baseUrls?.dealImageUrl,
      subtotal: subtotal,
      discount: discount,
      total: total,
    );

    return ColoredBox(
      color: PosHomeSpec.pageBg,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PosCategorySidebar(
                  categories: categories,
                  selectedId: selectedId,
                  onSelect: _selectCategory,
                ),
                Expanded(
                  child: _ContentArea(
                    searchController: _search,
                    onSearchChanged: (value) =>
                        setState(() => _query = value),
                    selectedTag: _selectedTag,
                    onTagSelected: (label) => setState(() =>
                        _selectedTag = _selectedTag == label ? null : label),
                    products: products,
                    isLoading: category.isKioskMenuPrefetching &&
                        categories.isEmpty,
                    imageBaseUrl: splash.baseUrls?.productImageUrl,
                    cartQuantityOf: cart.getCartProductQuantityCount,
                    onProductTap: _addToCart,
                  ),
                ),
                if (sideReceipt)
                  ClipRect(child: receipt),
              ],
            ),
          ),
          if (!sideReceipt)
            _CompactReceiptBar(
              total: total,
              onTap: () => _openReceiptSheet(
                subtotal: subtotal,
                discount: discount,
                total: total,
              ),
            ),
        ],
      ),
    );
  }
}

class _ContentArea extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String? selectedTag;
  final ValueChanged<String> onTagSelected;
  final List<Product> products;
  final bool isLoading;
  final String? imageBaseUrl;
  final int Function(Product) cartQuantityOf;
  final ValueChanged<Product> onProductTap;

  const _ContentArea({
    required this.searchController,
    required this.onSearchChanged,
    required this.selectedTag,
    required this.onTagSelected,
    required this.products,
    required this.isLoading,
    required this.imageBaseUrl,
    required this.cartQuantityOf,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            PosHomeSpec.contentPaddingLeft,
            PosHomeSpec.contentPaddingTop,
            PosHomeSpec.scrollbarInset,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                    right: PosHomeSpec.searchPaddingRight -
                        PosHomeSpec.scrollbarInset),
                child: PosSearchField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(height: PosHomeSpec.sectionGap),
              Padding(
                padding: const EdgeInsets.only(
                    right: PosHomeSpec.searchPaddingRight -
                        PosHomeSpec.scrollbarInset),
                child: SizedBox(
                  height: PosHomeSpec.pillHeight,
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(context)
                        .copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (int i = 0;
                              i < PosHomeSpec.filterPillLabels.length;
                              i++) ...[
                            if (i > 0)
                              const SizedBox(width: PosHomeSpec.pillGap),
                            PosFilterPill(
                              label: PosHomeSpec.filterPillLabels[i],
                              active: selectedTag ==
                                  PosHomeSpec.filterPillLabels[i],
                              onTap: () => onTagSelected(
                                  PosHomeSpec.filterPillLabels[i]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: PosHomeSpec.sectionGap),
              Expanded(
                child: isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: PosHomeSpec.ink),
                      )
                    : PosProductGrid(
                        products: products,
                        imageBaseUrl: imageBaseUrl,
                        cartQuantityOf: cartQuantityOf,
                        onProductTap: onProductTap,
                      ),
              ),
            ],
          ),
        ),
        const Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: PosHomeSpec.contentFadeHeight,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x00F7F1DE),
                    PosHomeSpec.pageBg,
                  ],
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

/// Compact-band stand-in for the pinned receipt. Not in the 1366 Figma frame;
/// `PosMetrics.showsSideReceipt` drops the side panel below 900px / portrait.
class _CompactReceiptBar extends StatelessWidget {
  final double total;
  final VoidCallback onTap;

  const _CompactReceiptBar({required this.total, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosHomeSpec.panelBg,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(
              horizontal: PosHomeSpec.panelPaddingH),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                  color: PosHomeSpec.ink, width: PosHomeSpec.paneBorder),
            ),
          ),
          child: Row(
            children: [
              Text(
                'Purchase Receipt',
                style: loewExtraBold.copyWith(
                  fontSize: PosHomeSpec.headerTitleSize,
                  color: PosHomeSpec.ink,
                ),
              ),
              const Spacer(),
              Text(
                PosHomeSpec.formatPrice(total),
                style: loewExtraBold.copyWith(
                  fontSize: PosHomeSpec.headerTitleSize,
                  color: PosHomeSpec.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
