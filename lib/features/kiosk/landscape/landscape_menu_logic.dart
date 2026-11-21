import 'package:acafe_customer/common/models/cart_model.dart';

/// Which cart line was just added, for the B-03 "item added" feedback (a 2 s
/// green border on the row and a 3 s toast).
///
/// A product added from the menu that is a NEW configuration appends a line, so
/// the cart grows and the new line is the last one. A same-configuration re-add
/// merges into an existing line (handled by `CartProvider.addToCart`), and a
/// panel +/- or delete changes a quantity or shortens the list — none of those
/// grow the list, so this returns null for them and the feedback never misfires
/// on a stepper tap.
int? landscapeJustAddedIndex(List<CartModel?> previous, List<CartModel?> next) {
  if (next.length > previous.length) return next.length - 1;
  return null;
}
