import 'package:acafe_customer/features/pos/domain/pos_item_prep_status.dart';

/// One kitchen station's aggregate on an order — "Bar · Ready" in Figma
/// 1915:15995 / 1915:16209.
///
/// Server-derived (`stations` on the POS orders, detail and item-write
/// responses): every line ready → ready, every line pending → pending,
/// anything in between → preparing. The POS only ever learns a station's
/// *name*; ids stay server-side.
class PosStationStatus {
  final String name;
  final PrepStatus status;

  const PosStationStatus({required this.name, required this.status});

  /// Lenient: a missing or malformed `stations` key is an order the API did
  /// not summarise (an older backend), which simply draws no pills.
  static List<PosStationStatus> listFromJson(Object? json) {
    if (json is! List) return const <PosStationStatus>[];

    return json
        .whereType<Map>()
        .map((e) => PosStationStatus(
              name: '${e['name'] ?? ''}'.trim(),
              status: PrepStatus.fromWire(e['status']),
            ))
        .where((s) => s.name.isNotEmpty)
        .toList(growable: false);
  }

  @override
  bool operator ==(Object other) =>
      other is PosStationStatus && other.name == name && other.status == status;

  @override
  int get hashCode => Object.hash(name, status);
}
