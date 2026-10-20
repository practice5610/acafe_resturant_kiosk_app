import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/features/cart/domain/cart_line_matcher.dart';
import 'package:acafe_customer/features/cart/providers/cart_provider.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_allergen.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_scroll.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_customize_sections.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_deal_detail_screen.dart';
import 'package:acafe_customer/features/kiosk/screens/kiosk_product_customize_sheet.dart';
import 'package:acafe_customer/features/kiosk/providers/kiosk_auth_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_customize_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_line_copy.dart';
import 'package:acafe_customer/features/pos/domain/pos_responsive.dart';
import 'package:acafe_customer/features/pos/widgets/pos_add_note_dialog.dart';
import 'package:acafe_customer/features/pos/widgets/pos_allergen_notice.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/helper/price_converter_helper.dart';
import 'package:acafe_customer/helper/product_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Opens the POS product-customize landscape screen (Figma **1641:7080**).
///
/// Reuses [ProductProvider] + [buildKioskCartModel] — the same selection and
/// price math as the kiosk — but presents the POS layout and pops back to the
/// counter after save (no kiosk confirmation beat). Shows [PosAllergenNotice]
/// when the branch admin has turned the allergen tag toggle on.
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
  // THE ALLERGEN GATE — mirrors openKioskCustomize exactly: the first time
  // this order reaches for a product, ask what to avoid before showing
  // anything. Once per order (reset in endKioskCustomerSession, same as
  // kiosk), not once per product. Guarded on `cart == null` so this only
  // fires on a NEW product selection, never on re-opening an existing cart
  // line for editing.
  //
  // The one difference from kiosk: the branch admin's "Show Allergen Tag"
  // toggle gates this entirely for POS. Kiosk has no such toggle.
  // DISABLED (2026-09-23, product decision): the popup was firing on every
  // first product tap. Restore by un-commenting this block.
  // final bool allergenTagEnabled =
  //     Provider.of<KioskAuthProvider>(context, listen: false)
  //         .allergenTagEnabled;
  // if (allergenTagEnabled &&
  //     cart == null &&
  //     !KioskAllergenPreferences.instance.asked) {
  //   _askAllergensThenOpenPosCustomize(
  //     context,
  //     product,
  //     customerNameController: customerNameController,
  //     tableController: tableController,
  //     orderType: orderType,
  //     onOrderTypeChanged: onOrderTypeChanged,
  //   );
  //   return;
  // }
  _openPosCustomizeNow(
    context,
    product,
    cart: cart,
    cartIndex: cartIndex,
    customerNameController: customerNameController,
    tableController: tableController,
    orderType: orderType,
    onOrderTypeChanged: onOrderTypeChanged,
  );
}

/// Shows the allergen popup, then opens the product the staff member
/// tapped — unless what was just declared rules it out. Mirrors
/// `_askAllergensThenOpenKioskCustomize`.
// ignore: unused_element
Future<void> _askAllergensThenOpenPosCustomize(
  BuildContext context,
  Product product, {
  TextEditingController? customerNameController,
  TextEditingController? tableController,
  PosOrderType orderType = PosOrderType.dineIn,
  ValueChanged<PosOrderType>? onOrderTypeChanged,
}) async {
  await showPosAllergenFilter(context);
  if (!context.mounted) return;

  if (kioskProductHasAllergen(
      product, KioskAllergenPreferences.instance.avoided)) {
    return;
  }
  _openPosCustomizeNow(
    context,
    product,
    customerNameController: customerNameController,
    tableController: tableController,
    orderType: orderType,
    onOrderTypeChanged: onOrderTypeChanged,
  );
}

void _openPosCustomizeNow(
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

  // A line already in the receipt always opens, even when the product has no
  // variations or add-ons (merchandise: t-shirts, mugs, bags). Returning here
  // is what made EDIT a dead tap on live, where such products exist; the
  // screen still edits quantity and the kitchen note.
  final bool editingExistingLine = cart != null || cartIndex != null;

  if (!hasModifiers && !editingExistingLine) {
    productProvider.initData(product, null);
    productProvider.initProductVariationStatus(0);
    cartProvider.addToCart(
      buildKioskCartModel(context, product),
      productProvider.cartIndex,
      showMessage: false,
    );
    return;
  }

  // A NEW product tap opens a BLANK configuration, even when the receipt
  // already holds this product. `cart == null` means the caller did not hand us
  // a line to edit, and a tap on the product grid is exactly that.
  //
  // This is where "Americano, Small" used to become an edit of "Americano,
  // Large": the code here searched the receipt by product.id, seeded this
  // screen with that line's picks and set cartIndex, so saving overwrote it —
  // and `removeOtherLinesForProduct` then deleted every other Americano line.
  // One product could only ever occupy one receipt line.
  //
  // Nothing replaces it. Whether the new line stacks onto an existing one or
  // stands on its own is [CartProvider.addToCart]'s decision, made on the full
  // configuration signature (see `cart_line_matcher.dart`) rather than on the
  // product id. Editing still works — it comes in through `openPosCartLine`,
  // which passes the line and its index explicitly.
  productProvider.initData(product, cart);
  productProvider.initProductVariationStatus(
      ProductHelper.effectiveVariations(product)?.length ?? 0);

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PosProductCustomizeScreen(
        product: product,
        cartIndex: cartIndex,
        initialInstruction: cart?.instruction,
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
  final TextEditingController? customerNameController;
  final TextEditingController? tableController;
  final PosOrderType orderType;
  final ValueChanged<PosOrderType>? onOrderTypeChanged;

  const PosProductCustomizeScreen({
    super.key,
    required this.product,
    this.cartIndex,
    this.initialInstruction,
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
  late final TextEditingController _customerName;
  late final TextEditingController _table;
  late final bool _ownsCustomerControllers;
  String? _instruction;

  /// Items already configured on this screen with DUPLICATE, oldest first.
  /// They sit in "Items that you will add:" and reach the cart only together
  /// with the item being edited, when ADD TO CART is tapped. Leaving the
  /// screen any other way discards them.
  final List<CartModel> _staged = [];

  /// One [GlobalKey] per rendered section, so a failed Add to Cart can scroll
  /// the first invalid section into view. Created on demand, keyed by identity.
  final Map<ProductSectionRef, GlobalKey> _sectionKeys = {};

  GlobalKey _sectionKey(ProductSectionRef ref) =>
      _sectionKeys.putIfAbsent(ref, () => GlobalKey());

  @override
  void initState() {
    super.initState();
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

  /// Runs the shared validation; on failure scrolls the first invalid section
  /// (in on-screen order) into view. Validation fires its own snackbar.
  bool _validateOrReveal(ProductProvider productProvider) {
    if (_validate(context, productProvider)) return true;
    final ProductSectionRef? invalid =
        firstInvalidProductSection(_product, productProvider);
    if (invalid != null) {
      final GlobalKey? key = _sectionKeys[invalid];
      if (key != null) scrollProductSectionIntoView(key);
    }
    return false;
  }

  /// The item being edited, as a cart line. Its variation rows are copies, so
  /// later taps on this screen can never reach into a staged line.
  CartModel _currentLine() {
    final CartModel built = buildKioskCartModel(
      context,
      _product,
      instruction: _instruction,
    );
    return built.copyWithQuantity(built.quantity ?? 1);
  }

  /// The ONLY path from this screen to the cart: the staged items first, in
  /// the order they were made, then the item being edited.
  void _addToCart(ProductProvider productProvider) {
    if (!_validateOrReveal(productProvider)) return;
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (widget.cartIndex != null) {
      final CartModel built = buildKioskCartModel(
        context,
        _product,
        instruction: _instruction,
      );
      cartProvider.addToCart(built, widget.cartIndex, showMessage: false);
    } else {
      for (final CartModel line in _staged) {
        _commitAdd(cartProvider, line);
      }
      _commitAdd(cartProvider, _currentLine());
    }
    Navigator.of(context).pop();
  }

  /// Adds [draft] as a new line, or folds it into the line that already has
  /// the same size, variations and add-ons. A folded line keeps one note: the
  /// draft's if it has one, otherwise the line's existing note.
  void _commitAdd(CartProvider cart, CartModel draft) {
    final int sameIndex = findSameConfigLineIndex(cart.cartList, draft);
    if (sameIndex < 0) {
      cart.addToCart(draft, -1, showMessage: false);
      return;
    }
    final CartModel existing = cart.cartList[sameIndex]!;
    final CartModel merged = draft.copyWithQuantity(
      (existing.quantity ?? 1) + (draft.quantity ?? 1),
      instruction: draft.instruction ?? existing.instruction,
    );
    cart.addToCart(merged, sameIndex, showMessage: false);
  }

  /// Opens the "Add Note" modal (Figma 1915:14827) and stores the result on
  /// the item being configured.
  Future<void> _showAddNote() async {
    final String? result = await showPosAddNoteDialog(
      context: context,
      initialNote: _instruction,
      quickAdd: _product.noteSuggestions ?? const [],
    );
    if (result == null || !mounted) return;
    setState(() => _instruction = result.isEmpty ? null : result);
  }

  /// "DUPLICATE" (add mode only) starts another item of this product without
  /// touching the cart. The finished configuration moves into "Items that you
  /// will add:", and only the variation and add-on picks are cleared for the
  /// next item; its note stays. Nothing is written until ADD TO CART.
  void _duplicate(ProductProvider productProvider) {
    if (!_validateOrReveal(productProvider)) return;
    final CartModel finished = _currentLine();
    setState(() => _staged.add(finished));
    productProvider.initProductVariationStatus(
        ProductHelper.effectiveVariations(_product)?.length ?? 0);
    productProvider.resetSelections(_product);

    // Without the side pane nothing on screen shows the parked item.
    final bool sideReceipt =
        PosMetrics.maybeOf(context)?.showsSideReceipt ?? true;
    if (!sideReceipt) {
      showCustomSnackBarHelper(
        'Item ${_staged.length} saved. Choose options for item '
        '${_staged.length + 1}.',
        isError: false,
      );
    }
  }

  /// Trash on a row of "Items that you will add:". [index] counts the staged
  /// items first; the item being edited is last.
  void _removePendingItem(int index, ProductProvider productProvider) {
    if (index < _staged.length) {
      setState(() => _staged.removeAt(index));
      return;
    }
    // The item being edited. Alone, removing it means leaving without adding.
    if (_staged.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    // Otherwise the previous item comes back into the editor, so the screen
    // always has exactly one item open.
    final CartModel previous = _staged.removeLast();
    productProvider.initData(_product, previous);
    productProvider.initProductVariationStatus(
        ProductHelper.effectiveVariations(_product)?.length ?? 0);
    setState(() {
      final String note = previous.instruction?.trim() ?? '';
      _instruction = note.isEmpty ? null : note;
    });
  }

  @override
  Widget build(BuildContext context) {
    final PosMetrics? metrics = PosMetrics.maybeOf(context);
    final bool sideReceipt = metrics?.showsSideReceipt ?? true;

    return Scaffold(
      backgroundColor: PosCustomizeSpec.pageBg,
      body: SafeArea(
        child: Consumer<ProductProvider>(
          builder: (context, productProvider, _) {
            final sections = KioskCustomizeSections.of(_product);
            final CartModel preview = buildKioskCartModel(
              context,
              _product,
              instruction: _instruction,
            );
            // Everything ADD TO CART will write: the staged items, then this one.
            final List<CartModel> pending = [..._staged, preview];
            final double total = pending.fold<double>(
                0, (sum, line) => sum + kioskLineTotal(line));
            final String priceLabel = PriceConverterHelper.convertPrice(total);
            final String addLabel =
                (getTranslated('add_to_cart', context) ?? 'Add to Cart').trim();
            final String baseLabel =
                addLabel.isEmpty ? 'Add to Cart' : addLabel;
            final String ctaLabel = pending.length > 1
                ? '$baseLabel (${pending.length})'
                : baseLabel;
            // Same rules _addToCart validates with, so the dimmed state and
            // the tap-time guidance can never disagree.
            final bool ready =
                firstInvalidProductSection(_product, productProvider) == null;
            // DUPLICATE is offered only when adding a new product; editing an
            // existing cart line stays single-item.
            final bool canDuplicate = widget.cartIndex == null;

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
                          sectionKey: _sectionKey,
                          onBack: () => Navigator.of(context).pop(),
                          onAddNote: _showAddNote,
                          hasNote: _instruction?.isNotEmpty ?? false,
                          onDuplicate: canDuplicate
                              ? () => _duplicate(productProvider)
                              : null,
                          footer: _AddToCartFooter(
                            priceLabel: priceLabel,
                            label: ctaLabel,
                            ready: ready,
                            onTap: () => _addToCart(productProvider),
                          ),
                        ),
                      ),
                      if (sideReceipt)
                        SizedBox(
                          // The same receipt-width policy Home and Payment use
                          // — a continuous proportion of the window at/above the
                          // desktop floor. The pane shows the items being built
                          // ("Items that you will add:") rather than the cart.
                          width: PosResponsive.receiptWidth(
                            MediaQuery.sizeOf(context).width,
                          ),
                          child: _PendingItemsPreview(
                            lines: pending,
                            onDelete: (index) =>
                                _removePendingItem(index, productProvider),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Sticky footer of the customize pane — one full-width ink CTA carrying the
/// total (Figma `footer` 1915:14823): "ADD TO CART  •  €x.xx". Dimmed while the
/// configuration is incomplete.
class _AddToCartFooter extends StatelessWidget {
  final String priceLabel;
  final String label;
  final bool ready;
  final VoidCallback onTap;

  const _AddToCartFooter({
    required this.priceLabel,
    required this.label,
    required this.ready,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosCustomizeSpec.ctaRadius);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PosCustomizeSpec.pageBg,
        border: Border(
          top: BorderSide(
            color: PosCustomizeSpec.mutedBorder,
            width: PosCustomizeSpec.footerBorder,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: PosCustomizeSpec.footerPadH,
          vertical: PosCustomizeSpec.footerPadV,
        ),
        child: Opacity(
          opacity: ready ? 1.0 : 0.4,
          child: Material(
            color: Colors.black,
            borderRadius: radius,
            child: InkWell(
              onTap: ready ? onTap : null,
              borderRadius: radius,
              child: SizedBox(
                height: PosCustomizeSpec.ctaButtonHeight,
                width: double.infinity,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${label.toUpperCase()}  •  $priceLabel',
                      maxLines: 1,
                      style: loewExtraBold.copyWith(
                        fontSize: PosCustomizeSpec.ctaLabelSize,
                        letterSpacing: PosCustomizeSpec.ctaLetterSpacing,
                        color: PosCustomizeSpec.ctaLabelColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Right pane: the items this screen will add, headed "Items that you will
/// add:" (Figma 1915:14803). Replaces the full receipt on this screen.
///
/// [lines] are the items staged with DUPLICATE followed by the item being
/// edited, which is always last. With more than one item the one being edited
/// is tinted so it is clear which row the left pane is changing.
class _PendingItemsPreview extends StatelessWidget {
  final List<CartModel> lines;
  final ValueChanged<int> onDelete;

  const _PendingItemsPreview({
    required this.lines,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final int editing = lines.length - 1;
    return Container(
      decoration: const BoxDecoration(
        color: PosCustomizeSpec.panelBg,
        border: Border(
          left: BorderSide(color: PosCustomizeSpec.mutedBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: PosHomeSpec.hairline),
              ),
            ),
            child: Text(
              'Items that you will add:',
              style: loewExtraBold.copyWith(
                fontSize: 16,
                color: PosHomeSpec.ink,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: lines.length,
              itemBuilder: (context, index) => _PendingItemRow(
                number: index + 1,
                line: lines[index],
                highlighted: lines.length > 1 && index == editing,
                onDelete: () => onDelete(index),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingItemRow extends StatelessWidget {
  final int number;
  final CartModel line;
  final bool highlighted;
  final VoidCallback onDelete;

  const _PendingItemRow({
    required this.number,
    required this.line,
    required this.highlighted,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final String? unit = posReceiptUnit(line);
    final String price = PosHomeSpec.formatPrice(kioskLineTotal(line));
    final String priceLine = unit == null ? price : '$price · $unit';
    final List<PosReceiptNote> notes = posReceiptNotes(line);
    final String note = line.instruction?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: highlighted ? PosHomeSpec.inkAlpha(0.05) : null,
        border: const Border(
          bottom: BorderSide(color: PosCustomizeSpec.mutedBorder),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ITEM $number',
                  style: loewExtraBold.copyWith(
                    fontSize: 14,
                    color: PosHomeSpec.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  priceLine,
                  style: swiss721Medium.copyWith(
                    fontSize: 12,
                    color: TextTones.secondary,
                  ),
                ),
                for (final n in notes) ...[
                  const SizedBox(height: 4),
                  _PreviewNote(mark: n.included ? '+' : '-', text: n.label),
                ],
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _PreviewNote(mark: 'Note:', text: note),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 26,
            height: 26,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onDelete,
                child: const Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: PosHomeSpec.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewNote extends StatelessWidget {
  final String mark;
  final String text;

  const _PreviewNote({required this.mark, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mark,
          style: loewRegular.copyWith(
            fontSize: 12,
            color: TextTones.secondary,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: swiss721Medium.copyWith(
              fontSize: 11,
              color: TextTones.secondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomizePane extends StatelessWidget {
  final Product product;
  final ProductProvider productProvider;
  final KioskCustomizeSections sections;
  final GlobalKey Function(ProductSectionRef) sectionKey;
  final VoidCallback onBack;
  final VoidCallback onAddNote;
  final bool hasNote;

  /// Null hides the DUPLICATE button (edit mode).
  final VoidCallback? onDuplicate;
  final Widget footer;

  const _CustomizePane({
    required this.product,
    required this.productProvider,
    required this.sections,
    required this.sectionKey,
    required this.onBack,
    required this.onAddNote,
    required this.hasNote,
    required this.onDuplicate,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final bool allergenTagEnabled =
        context.read<KioskAuthProvider>().allergenTagEnabled;
    final Widget? allergenNotice = PosAllergenNotice.maybe(
      product: product,
      enabled: allergenTagEnabled,
    );

    return ColoredBox(
      color: PosCustomizeSpec.pageBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _paneBody(allergenNotice),
          ),
          footer,
        ],
      ),
    );
  }

  Widget _paneBody(Widget? allergenNotice) {
    return Padding(
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
            onBack: onBack,
            onAddNote: onAddNote,
            hasNote: hasNote,
            onDuplicate: onDuplicate,
          ),
          if (allergenNotice != null) ...[
            const SizedBox(height: PosCustomizeSpec.sectionTitleGap),
            allergenNotice,
          ],
          const SizedBox(height: PosCustomizeSpec.sectionGap),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              // The footer sits below this scroll view (not over it), so
              // the last row always clears it; this is breathing room only.
              padding:
                  const EdgeInsets.only(bottom: PosCustomizeSpec.sectionGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final entry in sections.size) ...[
                    KeyedSubtree(
                      key: sectionKey(ProductSectionRef.size(entry.key)),
                      child: _VariationSection(
                        title: entry.value.name?.isNotEmpty == true
                            ? entry.value.name!
                            : 'Size',
                        variation: entry.value,
                        variationIndex: entry.key,
                        product: product,
                        productProvider: productProvider,
                      ),
                    ),
                    const SizedBox(height: PosCustomizeSpec.sectionGap),
                  ],
                  for (final entry in sections.dietary) ...[
                    KeyedSubtree(
                      key: sectionKey(ProductSectionRef.dietary(entry.key)),
                      child: _VariationSection(
                        // 'choose_your_dietary' has no entry in any locale
                        // file; getTranslated() throws on a missing key and
                        // echoes the raw key back rather than returning null,
                        // so the `?? fallback` idiom never actually fires —
                        // use the fallback text directly instead.
                        title: entry.value.name?.isNotEmpty == true
                            ? entry.value.name!
                            : 'Choose your dietary',
                        variation: entry.value,
                        variationIndex: entry.key,
                        product: product,
                        productProvider: productProvider,
                      ),
                    ),
                    const SizedBox(height: PosCustomizeSpec.sectionGap),
                  ],
                  if (product.effectiveAddOnGroups.isNotEmpty) ...[
                    for (final group in product.effectiveAddOnGroups) ...[
                      KeyedSubtree(
                        key: group.id != null
                            ? sectionKey(ProductSectionRef.addOn(group.id!))
                            : null,
                        child: _AddOnsSection(
                          group: group,
                          product: product,
                          productProvider: productProvider,
                        ),
                      ),
                      const SizedBox(height: PosCustomizeSpec.sectionGap),
                    ],
                  ],
                  for (final entry in sections.cupCan) ...[
                    KeyedSubtree(
                      key: sectionKey(ProductSectionRef.cupCan(entry.key)),
                      child: _CupCanSection(
                        variation: entry.value,
                        variationIndex: entry.key,
                        product: product,
                        productProvider: productProvider,
                      ),
                    ),
                    const SizedBox(height: PosCustomizeSpec.sectionGap),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String productName;
  final VoidCallback onBack;
  final VoidCallback onAddNote;
  final bool hasNote;

  /// Null hides DUPLICATE (edit mode).
  final VoidCallback? onDuplicate;

  const _Header({
    required this.productName,
    required this.onBack,
    required this.onAddNote,
    required this.hasNote,
    required this.onDuplicate,
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
        // "EDIT NOTE" once a note exists (Figma 1915:15205), else "ADD NOTE".
        _HeaderActionButton(
          label: hasNote ? 'EDIT NOTE' : 'ADD NOTE',
          filled: false,
          onTap: onAddNote,
        ),
        if (onDuplicate != null) ...[
          const SizedBox(width: 12),
          _HeaderActionButton(
            label: 'DUPLICATE',
            filled: true,
            onTap: onDuplicate!,
          ),
        ],
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosCustomizeSpec.headerBtnRadius);
    return Material(
      color: filled ? PosHomeSpec.ink : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PosCustomizeSpec.headerBtnPadH,
            vertical: PosCustomizeSpec.headerBtnPadV,
          ),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: Text(
            label,
            style: loewExtraBold.copyWith(
              fontSize: PosCustomizeSpec.headerBtnLabel,
              color: filled ? PosCustomizeSpec.pageBg : PosHomeSpec.ink,
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

/// Width of one option card in the 3-up wrapping grid (Figma 273.667 at the
/// design width), clamped so narrow panes stay usable.
double _optionCardWidth(double available) {
  const double gap = PosCustomizeSpec.optionGridGap;
  const int cols = 3;
  final double w = (available - gap * (cols - 1)) / cols;
  return w.clamp(140.0, 273.667);
}

class _VariationSection extends StatelessWidget {
  final String title;
  final Variation variation;
  final int variationIndex;
  final Product product;
  final ProductProvider productProvider;

  const _VariationSection({
    required this.title,
    required this.variation,
    required this.variationIndex,
    required this.product,
    required this.productProvider,
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
            final double cardWidth = _optionCardWidth(constraints.maxWidth);
            return Wrap(
              spacing: PosCustomizeSpec.optionGridGap,
              runSpacing: PosCustomizeSpec.optionGridGap,
              children: [
                for (int i = 0; i < values.length; i++)
                  _OptionCard(
                    width: cardWidth,
                    name: values[i].level?.trim() ?? '',
                    price: values[i].optionPrice ?? 0,
                    selected:
                        productProvider.selectedVariations[variationIndex][i] ??
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
                        variations:
                            productProvider.selectedVariations[variationIndex],
                        min: variation.min,
                        max: variation.max,
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Shared text-only option card for dietary and vessel choices
/// (Figma 1915:13826 / 1915:13918). Selection is a 1px ink outline — no radio,
/// no image.
class _OptionCard extends StatelessWidget {
  final double? width;
  final String name;
  final double price;
  final bool selected;
  final VoidCallback onTap;

  const _OptionCard({
    this.width,
    required this.name,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosCustomizeSpec.optionCardRadius);
    return Material(
      color: PosCustomizeSpec.optionCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: selected
            ? const BorderSide(
                color: PosHomeSpec.ink,
                width: PosCustomizeSpec.optionCardBorder,
              )
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: width,
          height: PosCustomizeSpec.optionCardHeight,
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: loewExtraBold.copyWith(
                  fontSize: PosCustomizeSpec.optionNameSize,
                  color: PosHomeSpec.ink,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                PosHomeSpec.formatPrice(price),
                textAlign: TextAlign.center,
                style: swiss721Light.copyWith(
                  fontSize: PosCustomizeSpec.optionPriceSize,
                  color: TextTones.secondary,
                ),
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
            final double cardWidth = _optionCardWidth(constraints.maxWidth);

            return Wrap(
              spacing: PosCustomizeSpec.optionGridGap,
              runSpacing: PosCustomizeSpec.optionGridGap,
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
                        selected: selected,
                        isDefault: isDefault,
                        quantity: quantity,
                        showQuantity: selected && !group.isSingle && !isDefault,
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

/// Add-on option card (Figma 1915:13849). Text-only, 273×90. Selected / default
/// cards gain a 1px outline; when the add-on carries a quantity the count sits
/// top-centre in a disc and − / + glyphs pin to the card's left / right edges.
class _AddOnCard extends StatelessWidget {
  final double width;
  final String name;
  final double priceDelta;
  final bool selected;
  final bool isDefault;
  final int quantity;
  final bool showQuantity;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _AddOnCard({
    required this.width,
    required this.name,
    required this.priceDelta,
    required this.selected,
    this.isDefault = false,
    required this.quantity,
    required this.showQuantity,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final bool outlined = selected || isDefault;
    final Color borderColor =
        isDefault ? PosCustomizeSpec.includedBorder : PosHomeSpec.ink;
    final Color bg =
        isDefault ? PosCustomizeSpec.includedBg : PosCustomizeSpec.optionCardBg;
    final String priceText = priceDelta > 0
        ? kioskAddonPriceLabel(priceDelta)
        : PosHomeSpec.formatPrice(0);
    final BorderRadius radius =
        BorderRadius.circular(PosCustomizeSpec.optionCardRadius);

    final Widget info = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showQuantity) ...[
          _AddonQtyBadge(quantity),
          const SizedBox(height: 4),
        ],
        Text(
          name,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: loewExtraBold.copyWith(
            fontSize: PosCustomizeSpec.optionNameSize,
            color: PosHomeSpec.ink,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          priceText,
          textAlign: TextAlign.center,
          style: swiss721Light.copyWith(
            fontSize: PosCustomizeSpec.optionPriceSize,
            color: TextTones.secondary,
          ),
        ),
      ],
    );

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: outlined
            ? BorderSide(
                color: borderColor, width: PosCustomizeSpec.optionCardBorder)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: isDefault ? null : onTap,
        borderRadius: radius,
        child: SizedBox(
          width: width,
          height: PosCustomizeSpec.optionCardHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Center(child: info),
                ),
              ),
              if (showQuantity) ...[
                Positioned(
                  left: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _StepGlyph(label: '−', onTap: onDecrement),
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _StepGlyph(label: '+', onTap: onIncrement),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 21px count disc sitting top-centre on an active add-on card (Figma
/// 1915:13852).
class _AddonQtyBadge extends StatelessWidget {
  final int quantity;

  const _AddonQtyBadge(this.quantity);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: PosCustomizeSpec.addonBadge,
      height: PosCustomizeSpec.addonBadge,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: PosHomeSpec.ink,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$quantity',
        style: loewBold.copyWith(
          fontSize: PosCustomizeSpec.addonBadgeLabel,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}

/// A − / + glyph pinned to an add-on card's edge (Figma 1915:13856/13857).
class _StepGlyph extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StepGlyph({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Text(
              label,
              style: loewRegular.copyWith(
                fontSize: PosCustomizeSpec.addonStepGlyph,
                color: PosHomeSpec.ink,
                height: 1.0,
              ),
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

  const _CupCanSection({
    required this.variation,
    required this.variationIndex,
    required this.product,
    required this.productProvider,
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
            final double cardWidth = _optionCardWidth(constraints.maxWidth);
            return Wrap(
              spacing: PosCustomizeSpec.optionGridGap,
              runSpacing: PosCustomizeSpec.optionGridGap,
              children: [
                for (int i = 0; i < values.length; i++)
                  _OptionCard(
                    width: cardWidth,
                    name: values[i].level?.trim() ?? '',
                    price: values[i].optionPrice ?? 0,
                    selected:
                        productProvider.selectedVariations[variationIndex][i] ??
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
                        variations:
                            productProvider.selectedVariations[variationIndex],
                        min: variation.min,
                        max: variation.max,
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
