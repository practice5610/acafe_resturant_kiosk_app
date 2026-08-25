import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';

/// What a product counts as when deciding whether an order is "complete".
enum KioskCourse {
  /// Anything from the bar — coffee, matcha, soft drinks, teas.
  drink,

  /// Anything made in the kitchen — poffertjes and other food.
  food,

  /// Beanies, mugs, beans. Never triggers an upsell in either direction: a bag
  /// of coffee beans is not a meal and does not make one complete.
  merchandise;

  /// Classify a product.
  ///
  /// `products.area` is the backend's own kitchen-routing field and is the
  /// authority. It is complete as of the 2026_08_25 backfill, but a product
  /// created by an older code path could still arrive with it empty — so an
  /// unknown area falls back to [drink], which is the safe answer in a cafe:
  /// mis-labelling a drink as food would make the kiosk offer a customer a
  /// drink they are already holding.
  static KioskCourse of(Product? product) {
    switch (product?.area?.trim().toLowerCase()) {
      case 'kitchen':
        return KioskCourse.food;
      case 'merchandise':
        return KioskCourse.merchandise;
      case 'bar':
      default:
        return KioskCourse.drink;
    }
  }
}

/// What the kiosk should offer when the customer heads for the cart.
enum KioskUpsell {
  /// Order is food only -> "Would you like something to drink?"
  suggestDrink,

  /// Order is drinks only -> "Would you like something to eat?"
  suggestFood,

  /// Order already has both -> offer to combine them into a combo deal.
  suggestCombo,

  /// Nothing useful to offer: empty cart, or merchandise only.
  none,
}

/// Reads a cart and decides which upsell (if any) belongs on screen.
///
/// Kept out of the widget so the rule is unit-testable and so both the cart
/// button and the checkout button ask the same question and get the same
/// answer — the two entry points named in the brief.
class KioskOrderComposition {
  final bool hasFood;
  final bool hasDrink;
  final bool hasMerchandise;

  const KioskOrderComposition({
    required this.hasFood,
    required this.hasDrink,
    required this.hasMerchandise,
  });

  factory KioskOrderComposition.of(List<CartModel?> cartList) {
    bool food = false;
    bool drink = false;
    bool merch = false;

    for (final line in cartList) {
      if (line == null) continue;
      switch (KioskCourse.of(line.product)) {
        case KioskCourse.food:
          food = true;
        case KioskCourse.drink:
          drink = true;
        case KioskCourse.merchandise:
          merch = true;
      }
    }

    return KioskOrderComposition(
      hasFood: food,
      hasDrink: drink,
      hasMerchandise: merch,
    );
  }

  bool get isEmpty => !hasFood && !hasDrink && !hasMerchandise;

  /// The rule from the brief, in order:
  ///
  ///  * only food  -> ask about a drink
  ///  * only drink -> ask about food
  ///  * both       -> offer the combo
  ///  * anything else (empty, merchandise only) -> say nothing
  KioskUpsell get upsell {
    if (hasFood && hasDrink) return KioskUpsell.suggestCombo;
    if (hasFood) return KioskUpsell.suggestDrink;
    if (hasDrink) return KioskUpsell.suggestFood;
    return KioskUpsell.none;
  }

  /// Which course the upsell sheet should list. Null when nothing is offered.
  KioskCourse? get courseToOffer => switch (upsell) {
        KioskUpsell.suggestDrink => KioskCourse.drink,
        KioskUpsell.suggestFood => KioskCourse.food,
        KioskUpsell.suggestCombo => null,
        KioskUpsell.none => null,
      };
}
