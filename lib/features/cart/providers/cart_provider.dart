import 'package:flutter/material.dart';
import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';
import 'package:acafe_customer/common/providers/product_provider.dart';
import 'package:acafe_customer/features/cart/domain/cart_line_matcher.dart';
import 'package:acafe_customer/features/cart/domain/reposotories/cart_repo.dart';
import 'package:acafe_customer/features/coupon/providers/coupon_provider.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/main.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:provider/provider.dart';

class CartProvider extends ChangeNotifier {
  final CartRepo? cartRepo;
  CartProvider({required this.cartRepo});

  List<CartModel?> _cartList = [];
  double _amount = 0.0;
  bool _isCartUpdate = false;

  /// One free-text note for the whole order, written on the cart screen. It
  /// replaces the per-item "Instructions" field the customize screen used to
  /// carry, and rides along on the order as `order_note`.
  String _orderNote = '';

  List<CartModel?> get cartList => _cartList;
  double get amount => _amount;
  bool get isCartUpdate => _isCartUpdate;
  String get orderNote => _orderNote;

  void setOrderNote(String note) {
    _orderNote = note.trim();
    notifyListeners();
  }


  void getCartData(BuildContext context) {
    _cartList = [];
    try {
      _cartList.addAll(cartRepo!.getCartList(context));
    } catch (e) {
      debugPrint('getCartData: clearing corrupt cart ($e)');
      _cartList = [];
      try {
        cartRepo?.addToCartList(_cartList);
      } catch (_) {}
    }
    // A restored line carries no lineId — it is never persisted (see
    // CartModel.lineId). Stamp every line now, before anything can key a
    // widget off it, so ids stay unique within this process.
    for (final cart in _cartList) {
      cart?.stampFreshLineId();
    }
    _amount = 0;
    for (final cart in _cartList) {
      if (cart == null) continue;
      _amount += (cart.discountedPrice ?? 0) * (cart.quantity ?? 1);
    }
  }

  /// Writes [cartModel] into the cart and returns the index it ended up at, or
  /// -1 if the cart was left untouched.
  ///
  /// [index] null or -1 means ADD: the line stacks onto an existing line with
  /// the same configuration signature, or becomes a new line. A real [index]
  /// means EDIT that line in place.
  ///
  /// RETURN THE INDEX, DO NOT REUSE THE ONE YOU PASSED IN. An edit can merge
  /// the line it just wrote into another line that now carries the same
  /// configuration (a customer switching line 2 back to the milk line 1
  /// already has), which shortens the list — so the caller's [index] may point
  /// at a different line, or past the end, the moment this returns.
  int addToCart(CartModel cartModel, int? index, {bool showMessage = true}) {
    final bool isUpdate = index != null && index != -1;
    int resultIndex;

    if (isUpdate) {
      if (index < 0 || index >= _cartList.length) return -1;
      _cartList.replaceRange(index, index + 1, [cartModel]);

      // The edited line may now be configured exactly like another line. Two
      // identical lines side by side is not a cart state the customer can
      // reach any other way, so fold them together — the mirror image of the
      // stacking the ADD path does.
      final int survivor = _matchingLineExcluding(cartModel, index);
      if (survivor >= 0) {
        final CartModel keep = _cartList[survivor]!;
        keep.quantity = (keep.quantity ?? 0) + (cartModel.quantity ?? 1);
        _cartList.removeAt(index);
        resultIndex = survivor > index ? survivor - 1 : survivor;
      } else {
        resultIndex = index;
      }
      // An edit changes a line's price, not just its quantity, so the running
      // delta arithmetic the ADD path uses cannot express it. Rebuild.
      _recomputeAmount();
    } else {
      final int matchIndex = findMatchingCartLineIndex(_cartList, cartModel);
      if (matchIndex >= 0) {
        final int addQty = cartModel.quantity ?? 1;
        final CartModel existing = _cartList[matchIndex]!;
        existing.quantity = (existing.quantity ?? 0) + addQty;
        _amount = _amount + (existing.discountedPrice ?? 0) * addQty;
        resultIndex = matchIndex;
      } else {
        _cartList.add(cartModel);
        _amount = _amount + (cartModel.discountedPrice ?? 0) * (cartModel.quantity ?? 1);
        resultIndex = _cartList.length - 1;
      }
    }
    cartRepo!.addToCartList(_cartList);
    setCartUpdate(false);
    if (showMessage) {
      showCustomSnackBarHelper(getTranslated(isUpdate ?
      'cart_updated' : 'added_in_cart', Get.context!), isToast: true, isError: false);
    }

    notifyListeners();
    return resultIndex;
  }

  /// Index of a line configured like [candidate], ignoring the line at
  /// [skipIndex]. Used to fold an edited line into its new twin.
  ///
  /// Goes through [cartLinesMatch] so the rule stays in one place; the skip is
  /// here rather than in the matcher because "same configuration" and "a
  /// different slot in this list" are two different questions.
  int _matchingLineExcluding(CartModel candidate, int skipIndex) {
    for (int i = 0; i < _cartList.length; i++) {
      if (i == skipIndex) continue;
      final CartModel? line = _cartList[i];
      if (line != null && cartLinesMatch(line, candidate)) return i;
    }
    return -1;
  }

  void setQuantity(
      {required bool isIncrement,
      CartModel? cart,
      int? productIndex,
      required bool fromProductView}) {
    int? index = fromProductView ? productIndex :  _cartList.indexOf(cart);
    if (isIncrement) {
      _cartList[index!]!.quantity = _cartList[index]!.quantity! + 1;
      _amount = _amount + _cartList[index]!.discountedPrice!;
    } else {
      _cartList[index!]!.quantity = _cartList[index]!.quantity! - 1;
      _amount = _amount - _cartList[index]!.discountedPrice!;
    }
    cartRepo!.addToCartList(_cartList);

    notifyListeners();
  }

  /// Swap already-customized cart units for a combo line at bundle price.
  ///
  /// [consume] is cart-index → units to take. Walked highest index first so
  /// a `removeAt` never shifts a later index we still need to touch. The
  /// deal line is merged the same way [addToCart] would (identical combos
  /// stack) but without the "added to cart" toast — this is a replacement,
  /// not an add. [_amount] is rebuilt from the resulting list: the usual
  /// delta arithmetic drifts across a multi-line swap.
  void applyComboUpgrade({
    required Map<int, int> consume,
    required CartModel dealLine,
  }) {
    final List<int> indices = consume.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    for (final int index in indices) {
      if (index < 0 || index >= _cartList.length) continue;
      final CartModel? line = _cartList[index];
      if (line == null) continue;
      final int take = consume[index] ?? 0;
      if (take <= 0) continue;
      final int remaining = (line.quantity ?? 1) - take;
      if (remaining <= 0) {
        _cartList.removeAt(index);
      } else {
        line.quantity = remaining;
      }
    }

    final int matchIndex = findMatchingCartLineIndex(_cartList, dealLine);
    if (matchIndex >= 0) {
      final int addQty = dealLine.quantity ?? 1;
      final CartModel existing = _cartList[matchIndex]!;
      existing.quantity = (existing.quantity ?? 0) + addQty;
    } else {
      _cartList.add(dealLine);
    }

    _recomputeAmount();
    cartRepo?.addToCartList(_cartList);
    notifyListeners();
  }

  void _recomputeAmount() {
    _amount = 0;
    for (final CartModel? cart in _cartList) {
      if (cart == null) continue;
      _amount += (cart.discountedPrice ?? 0) * (cart.quantity ?? 1);
    }
  }

  /// Seeds the in-memory cart for tests that cannot go through [addToCart]
  /// (that path needs a navigator and shows a snackbar).
  @visibleForTesting
  void replaceCartList(List<CartModel?> items) {
    _cartList = List<CartModel?>.from(items);
    _recomputeAmount();
    notifyListeners();
  }

  void removeFromCart(int index) {
    _amount = _amount - (_cartList[index]!.discountedPrice! * _cartList[index]!.quantity!);
    _cartList.removeAt(index);
    cartRepo!.addToCartList(_cartList);
    if (_cartList.isEmpty) _dropAttachedCoupon();
    notifyListeners();
  }

  void removeByProductId(int productId) {
    final remaining = <CartModel?>[];
    for (final cart in _cartList) {
      if (cart?.product?.id == productId) {
        _amount = _amount - ((cart!.discountedPrice ?? 0) * (cart.quantity ?? 1));
      } else {
        remaining.add(cart);
      }
    }
    if (remaining.length == _cartList.length) {
      return;
    }
    _cartList = remaining;
    cartRepo!.addToCartList(_cartList);
    if (_cartList.isEmpty) _dropAttachedCoupon();
    notifyListeners();
  }

  void removeByDealId(int dealId) {
    final remaining = <CartModel?>[];
    for (final cart in _cartList) {
      if (cart?.dealId == dealId) {
        _amount = _amount - ((cart!.discountedPrice ?? 0) * (cart.quantity ?? 1));
      } else {
        remaining.add(cart);
      }
    }
    if (remaining.length == _cartList.length) {
      return;
    }
    _cartList = remaining;
    cartRepo!.addToCartList(_cartList);
    if (_cartList.isEmpty) _dropAttachedCoupon();
    notifyListeners();
  }

  void removeAddOn(int index, int addOnIndex) {
    _cartList[index]!.addOnIds!.removeAt(addOnIndex);
    cartRepo!.addToCartList(_cartList);
    notifyListeners();
  }

  void clearCartList() {
    _cartList = [];
    _amount = 0;
    _orderNote = '';
    cartRepo?.addToCartList(_cartList);
    _dropAttachedCoupon();
    notifyListeners();
  }

  /// A coupon lives on [CouponProvider], not on the cart — but it is only
  /// meaningful for the current basket. An empty cart (order placed, last
  /// item removed, kiosk reset) must drop it, or the next customer inherits
  /// the previous code.
  void _dropAttachedCoupon() {
    final BuildContext? ctx = Get.context;
    if (ctx == null) return;
    try {
      Provider.of<CouponProvider>(ctx, listen: false).removeCouponData(false);
    } on ProviderNotFoundException {
      // Widget tests (and a kiosk that has not mounted the tree yet) have no
      // CouponProvider. The explicit session-end path still clears it.
    }
  }

  int isExistInCart(int? productID, int? cartIndex) {
    for(int index=0; index<_cartList.length; index++) {
      if(_cartList[index]!.product!.id == productID) {
        if((index == cartIndex)) {
          return -1;
        }else {
          return index;
        }
      }
    }
    return -1;
  }


  int getCartIndex (Product product) {
    for(int index = 0; index < _cartList.length; index ++) {
      if(_cartList[index]?.isDeal == true) continue;
      if(_cartList[index]!.product!.id == product.id ) {

        return index;
      }
    }
    return -1;
  }
  int getCartProductQuantityCount (Product product) {
    int quantity = 0;
    for(int index = 0; index < _cartList.length; index ++) {
      if(_cartList[index]?.isDeal == true) continue;
      if(_cartList[index]!.product!.id == product.id ) {
        quantity = quantity + (_cartList[index]!.quantity ?? 0);
      }
    }
    return quantity;
  }


  setCartUpdate(bool isUpdate) {
    _isCartUpdate = isUpdate;
    if(_isCartUpdate) {
      notifyListeners();
    }

  }

  void onUpdateCartQuantity({required int index, required Product product,  required bool isRemove}) {
    if (index >= 0 && index < _cartList.length && _cartList[index]?.isDeal == true) {
      final int qty = _cartList[index]!.quantity ?? 1;
      if (isRemove && qty <= 1) {
        removeFromCart(index);
        showCustomSnackBarHelper(getTranslated('this_item_removed_form_cart', Get.context!));
        return;
      }
      setQuantity(
        isIncrement: !isRemove,
        cart: _cartList[index],
        fromProductView: false,
      );
      return;
    }

    // ONE LINE, NOT ONE PRODUCT. This used to refuse outright when the cart
    // held more than one line of the product ("update quantity from cart
    // list"), and on the path that did run it wrote the total across every
    // line of the product onto the single line being tapped — so "+" on one of
    // two Americanos made that line qty 3. Both were product-id thinking.
    final CartModel? line =
        (index >= 0 && index < _cartList.length) ? _cartList[index] : null;
    if (line == null) return;

    // Stock is held against the PRODUCT, not the configuration, so the check
    // has to ask what the whole cart would hold: every line of this product
    // plus the unit being added. Keeping this per-line instead would let a
    // customer walk past a stock limit by splitting one product across three
    // different milks.
    if (!isRemove) {
      final ProductProvider productProvider =
          Provider.of<ProductProvider>(Get.context!, listen: false);
      final int productTotal = getCartProductQuantityCount(product) + 1;
      if (!productProvider.checkStock(product, quantity: productTotal)) {
        showCustomSnackBarHelper(getTranslated('out_of_stock', Get.context!));
        return;
      }
    }

    // Only the tapped line's own quantity is written back.
    if (isRemove && (line.quantity ?? 1) <= 1) {
      removeFromCart(index);
      showCustomSnackBarHelper(
          getTranslated('this_item_removed_form_cart', Get.context!));
      return;
    }
    setQuantity(
      isIncrement: !isRemove,
      cart: line,
      fromProductView: false,
    );
  }

}
