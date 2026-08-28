import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/common/models/product_model.dart';

/// Variation groups whose name mentions "cup"/"can" count as a drink vessel.
///
/// This is the name the backend's Cup/Can switch generates ("Can or cup?");
/// the pattern stays loose so hand-authored groups from before the switch
/// still match. Word-bounded on purpose — an unbounded `can` also matched
/// "Pecan". Shared with the customize screen so the upsell and the cup/can
/// cards never disagree about what a drink is.
final RegExp kioskCupCanPattern =
    RegExp(r'\b(cups?|cans?)\b', caseSensitive: false);

/// True when [product] has a cup or can option the customer can pick.
bool productHasCupCanOption(Product? product) {
  final variations = product?.variations;
  if (variations == null) return false;
  for (final variation in variations) {
    if (kioskCupCanPattern.hasMatch(variation.name ?? '')) return true;
  }
  return false;
}

/// What a product counts as when deciding whether an order is "complete".
enum KioskCourse {
  /// Anything served in a cup or can — coffee, matcha, soft drinks, teas.
  drink,

  /// Anything without a cup/can option — poffertjes and other food.
  food,

  /// Beanies, mugs, beans. Never triggers an upsell in either direction: a bag
  /// of coffee beans is not a meal and does not make one complete.
  merchandise;

  /// Classify a product.
  ///
  /// Cup/can is the drink signal the admin actually sets. `products.area` is
  /// still read for merchandise (there is no cup/can equivalent), but it is
  /// not used for food vs drink: new products are always saved as `bar` and
  /// the edit form has no area selector, so `area` would treat kitchen items
  /// as drinks and ask the wrong question.
  static KioskCourse of(Product? product) {
    if (product?.area?.trim().toLowerCase() == 'merchandise') {
      return KioskCourse.merchandise;
    }
    if (productHasCupCanOption(product)) return KioskCourse.drink;
    return KioskCourse.food;
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

    void apply(Product? product) {
      switch (KioskCourse.of(product)) {
        case KioskCourse.food:
          food = true;
        case KioskCourse.drink:
          drink = true;
        case KioskCourse.merchandise:
          merch = true;
      }
    }

    for (final line in cartList) {
      if (line == null) continue;
      final components = line.components;
      if (line.isDeal && components != null && components.isNotEmpty) {
        for (final component in components) {
          apply(component.product);
        }
      } else {
        apply(line.product);
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
