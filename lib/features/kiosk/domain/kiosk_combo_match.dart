import 'package:acafe_customer/common/models/cart_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_deal.dart';

/// One cart line that will lose [quantity] units if the customer accepts.
class KioskComboConsume {
  final int cartIndex;
  final int quantity;

  const KioskComboConsume({required this.cartIndex, required this.quantity});
}

/// A one-tap upgrade: the cart already covers [deal], so swapping those units
/// for [dealLine] always lowers the total.
class KioskComboMatch {
  final KioskDeal deal;
  final List<KioskComboConsume> consume;
  final CartModel dealLine;
  final double currentTotal;

  const KioskComboMatch({
    required this.deal,
    required this.consume,
    required this.dealLine,
    required this.currentTotal,
  });

  double get saving => currentTotal - kioskLineTotal(dealLine);

  Map<int, int> get consumeByIndex {
    final Map<int, int> out = {};
    for (final KioskComboConsume item in consume) {
      out[item.cartIndex] = (out[item.cartIndex] ?? 0) + item.quantity;
    }
    return out;
  }
}

/// Highest-saving upgrade where the cart already holds every product of an
/// active deal. Null when nothing qualifies (missing items, deal already in
/// the cart, or the swap would not save money).
KioskComboMatch? findKioskComboUpgrade(
  List<CartModel?> cartList,
  List<KioskDeal> deals,
) {
  KioskComboMatch? best;
  for (final KioskDeal deal in deals) {
    if (!deal.available) continue;
    final KioskComboMatch? match = _matchDeal(cartList, deal);
    if (match == null) continue;
    if (best == null || match.saving > best.saving) {
      best = match;
    }
  }
  return best;
}

KioskComboMatch? _matchDeal(List<CartModel?> cartList, KioskDeal deal) {
  final Map<int, int> required = _productQuantityMap(deal);
  if (required.isEmpty) return null;

  final Map<int, int> available = {};
  for (int i = 0; i < cartList.length; i++) {
    final CartModel? line = cartList[i];
    if (line == null || line.isDeal) continue;
    final int? id = line.product?.id;
    if (id == null) continue;
    available[id] = (available[id] ?? 0) + (line.quantity ?? 1);
  }
  for (final MapEntry<int, int> need in required.entries) {
    if ((available[need.key] ?? 0) < need.value) return null;
  }

  final Map<int, int> remaining = Map<int, int>.from(required);
  final List<KioskComboConsume> consume = [];
  final Map<int, List<CartModel>> unitsByProduct = {};
  double currentTotal = 0;

  for (int i = 0; i < cartList.length; i++) {
    final CartModel? line = cartList[i];
    if (line == null || line.isDeal) continue;
    final int? id = line.product?.id;
    if (id == null) continue;
    final int need = remaining[id] ?? 0;
    if (need <= 0) continue;

    final int lineQty = line.quantity ?? 1;
    final int take = lineQty < need ? lineQty : need;
    consume.add(KioskComboConsume(cartIndex: i, quantity: take));
    remaining[id] = need - take;

    final double perUnit =
        kioskLineTotal(line) / (lineQty == 0 ? 1 : lineQty);
    currentTotal += perUnit * take;

    final List<CartModel> queue =
        unitsByProduct.putIfAbsent(id, () => <CartModel>[]);
    for (int u = 0; u < take; u++) {
      queue.add(line.copyWithQuantity(1));
    }
  }

  final List<CartModel> components = [];
  for (final slot in deal.slots) {
    final int? id = slot.id;
    if (id == null) return null;
    final List<CartModel>? queue = unitsByProduct[id];
    if (queue == null || queue.isEmpty) return null;
    components.add(queue.removeAt(0));
  }

  final CartModel dealLine = CartModel.deal(
    dealId: deal.id,
    title: deal.title,
    image: deal.image,
    bundlePrice: deal.bundlePrice,
    originalPrice: deal.originalPrice,
    components: components,
  );

  final KioskComboMatch match = KioskComboMatch(
    deal: deal,
    consume: consume,
    dealLine: dealLine,
    currentTotal: currentTotal,
  );
  if (match.saving <= 0) return null;
  return match;
}

/// Dart mirror of `Deal::productQuantityMap()`.
Map<int, int> _productQuantityMap(KioskDeal deal) {
  final Map<int, int> map = {};
  for (final KioskDealItem item in deal.items) {
    final int? id = item.product.id;
    if (id == null) continue;
    final int qty = item.quantity < 1 ? 1 : item.quantity;
    map[id] = (map[id] ?? 0) + qty;
  }
  return map;
}
