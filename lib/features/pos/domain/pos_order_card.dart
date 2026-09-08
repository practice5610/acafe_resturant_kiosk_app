import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';

/// One row of `GET /api/v1/kiosk/manager/orders` — a single card on the board.
///
/// Everything here is server-derived. `customerName` comes from the same
/// `displayCustomerName()` the Receipts feed uses (the name typed at the kiosk
/// or on the POS payment screen, parsed back out of `order_note`), and
/// `addressLines` is whatever the stored address actually contains — which is
/// usually one line, because `customer_addresses.address` is a single column
/// with no separate street / postcode / city. Nothing is padded out to fill
/// Figma's three-line block; the card shrinks instead.
class PosOrderCard {
  final int id;
  final DateTime? createdAt;
  final String orderStatus;
  final String orderType;
  final String channelKey;
  final double orderAmount;
  final String customerName;
  final List<String> addressLines;
  final String displayMethod;
  final String? branchName;

  const PosOrderCard({
    required this.id,
    required this.createdAt,
    required this.orderStatus,
    required this.orderType,
    required this.channelKey,
    required this.orderAmount,
    required this.customerName,
    required this.addressLines,
    required this.displayMethod,
    this.branchName,
  });

  PosOrderSection get section => PosOrderGrouping.sectionOf(orderStatus);

  /// The lines drawn under the customer name.
  ///
  /// A delivery order has an address; a counter or kiosk order does not, and
  /// there is no table number to fall back on — `orders.table_id` is never
  /// written by any of the ordering apps — so it falls back to what is actually
  /// known: where the order came from and which branch took it.
  List<String> get subtitleLines {
    if (addressLines.isNotEmpty) {
      return addressLines;
    }

    final List<String> lines = <String>[];
    final String channel = channelLabel;
    if (channel.isNotEmpty) lines.add(channel);
    final String branch = (branchName ?? '').trim();
    if (branch.isNotEmpty) lines.add(branch);

    return lines;
  }

  String get channelLabel {
    switch (channelKey) {
      case 'counter_pos':
        return 'Point of sale';
      case 'kiosk':
        return 'Kiosk';
      case 'web_app':
        return 'Web app';
      default:
        return '';
    }
  }

  /// Copy with a different status — the optimistic move, before the server has
  /// confirmed it. Kept as a copy rather than a mutation so a rollback is just
  /// putting the original back.
  PosOrderCard withStatus(String status) => PosOrderCard(
        id: id,
        createdAt: createdAt,
        orderStatus: status,
        orderType: orderType,
        channelKey: channelKey,
        orderAmount: orderAmount,
        customerName: customerName,
        addressLines: addressLines,
        displayMethod: displayMethod,
        branchName: branchName,
      );

  factory PosOrderCard.fromJson(Map<String, dynamic> json) {
    return PosOrderCard(
      id: int.tryParse('${json['id']}') ?? 0,
      createdAt: DateTime.tryParse('${json['created_at']}')?.toLocal(),
      orderStatus: json['order_status']?.toString() ?? '',
      orderType: json['order_type']?.toString() ?? '',
      channelKey: json['channel_key']?.toString() ?? '',
      orderAmount: double.tryParse('${json['order_amount']}') ?? 0,
      customerName: json['customer_name']?.toString() ?? '',
      addressLines: (json['address_lines'] is List)
          ? (json['address_lines'] as List)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList(growable: false)
          : const <String>[],
      displayMethod: json['display_method']?.toString() ?? '',
      branchName: json['branch_name']?.toString(),
    );
  }
}
