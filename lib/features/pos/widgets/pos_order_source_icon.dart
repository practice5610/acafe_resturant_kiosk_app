import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:flutter/material.dart';

/// The `source-badge` in a card's top-right corner (Figma 1641:2944).
///
/// Figma draws two glyphs for three real `channel_key` values. Collapsing two
/// channels onto one icon would make a kiosk order and a counter order
/// indistinguishable at a glance, which is exactly the distinction an operator
/// scanning the board needs, so each channel gets its own:
///
///   counter_pos → storefront   (matches Figma's `store`, and the
///                               "Point of sale" label already used on cards)
///   kiosk       → monitor      (the self-service terminal itself)
///   web_app     → smartphone   (Figma's `smartphone`)
///
/// The kiosk glyph is a monitor rather than the more literal tablet: at the
/// 14px Figma draws these at, a tablet outline and a phone outline are the same
/// rounded rectangle, which would have put the two channels an operator is
/// least able to guess between back onto indistinguishable icons.
class PosOrderSourceIcon extends StatelessWidget {
  final String channelKey;

  const PosOrderSourceIcon({super.key, required this.channelKey});

  static IconData iconFor(String channelKey) {
    switch (channelKey) {
      case 'counter_pos':
        return Icons.storefront_outlined;
      case 'kiosk':
        return Icons.desktop_windows_outlined;
      case 'web_app':
        return Icons.smartphone_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }

  static String labelFor(String channelKey) {
    switch (channelKey) {
      case 'counter_pos':
        return 'Counter POS';
      case 'kiosk':
        return 'Kiosk';
      case 'web_app':
        return 'Web app';
      default:
        return 'Order';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: labelFor(channelKey),
      child: Container(
        width: PosOrdersSpec.sourceBadgeSize,
        height: PosOrdersSpec.sourceBadgeSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: PosHomeSpec.pageBg,
          shape: BoxShape.circle,
          border: Border.all(color: PosHomeSpec.hairline),
        ),
        child: Icon(
          iconFor(channelKey),
          size: PosOrdersSpec.sourceIconSize,
          color: PosHomeSpec.ink,
        ),
      ),
    );
  }
}
