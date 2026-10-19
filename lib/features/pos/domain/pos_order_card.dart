import 'package:acafe_customer/features/pos/domain/pos_item_prep_status.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_grouping.dart';
import 'package:acafe_customer/features/pos/domain/pos_station_status.dart';

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

  /// Each line's prep status, in line order, from the board feed's
  /// `item_states`. Empty for an order the feed did not expand, in which case
  /// the card simply draws no progress line rather than a hollow one.
  final List<PrepStatus> itemStates;

  /// One aggregate per kitchen station, from the feed's `stations` — the
  /// card's footer pills. Empty when no line has a station.
  final List<PosStationStatus> stations;

  /// The order's notes, from the feed's `notes`: its own note first, then
  /// each line's instruction. Empty when it has none — or when the backend
  /// predates the field, in which case the card simply flags nothing.
  final List<PosOrderCardNote> notes;

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
    this.itemStates = const <PrepStatus>[],
    this.stations = const <PosStationStatus>[],
    this.notes = const <PosOrderCardNote>[],
  });

  PosOrderSection get section => PosOrderGrouping.sectionOf(orderStatus);

  /// `#1000189` — the order's public number.
  ///
  /// Formatted in one place so the board card and the detail modal's title can
  /// never spell the same order two different ways; the modal simply prefixes
  /// it with "Order ".
  static String numberLabelFor(int id) => '#$id';

  String get numberLabel => numberLabelFor(id);

  bool get hasNotes => notes.isNotEmpty;

  /// "2 of 3 ready" for the card's progress line.
  PrepProgress get progress => PrepProgress.fromStatuses(itemStates);

  /// The bulk move this card's CTA performs, or null when nothing is left to
  /// move -- at which point the order-level action (Mark as collected) takes
  /// over. See [PosBulkItemAction].
  PosBulkItemAction? get bulkAction => PosBulkItemAction.forStatuses(itemStates);

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
        itemStates: itemStates,
        stations: stations,
        notes: notes,
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
      itemStates: (json['item_states'] is List)
          ? (json['item_states'] as List)
              .whereType<Map>()
              .map((e) => PrepStatus.fromWire(e['prep_status']))
              .toList(growable: false)
          : const <PrepStatus>[],
      stations: PosStationStatus.listFromJson(json['stations']),
      notes: PosOrderCardNote.listFromJson(json['notes']),
    );
  }
}

/// One note a board card previews: the order's own ([item] null) or one
/// line's instruction. The server cuts long ones short; the detail overlay
/// shows them in full.
class PosOrderCardNote {
  /// The line's product name; null for a note on the whole order.
  final String? item;
  final int quantity;
  final String text;

  const PosOrderCardNote({
    required this.item,
    required this.text,
    this.quantity = 1,
  });

  /// `2× Latte` — the line this note belongs to; null for the order's own.
  String? get itemLabel {
    final String? name = item;
    if (name == null) return null;
    return quantity > 1 ? '$quantity× $name' : name;
  }

  static List<PosOrderCardNote> listFromJson(dynamic raw) {
    if (raw is! List) return const <PosOrderCardNote>[];

    final List<PosOrderCardNote> notes = <PosOrderCardNote>[];
    for (final dynamic entry in raw) {
      if (entry is! Map) continue;
      final String text = '${entry['text'] ?? ''}'.trim();
      if (text.isEmpty) continue;
      final String item = '${entry['item'] ?? ''}'.trim();
      notes.add(PosOrderCardNote(
        item: item.isEmpty ? null : item,
        quantity: int.tryParse('${entry['quantity']}') ?? 1,
        text: text,
      ));
    }
    return List<PosOrderCardNote>.unmodifiable(notes);
  }
}
