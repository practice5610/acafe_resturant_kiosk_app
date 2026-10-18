import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
/// The kiosk glyph is a monitor rather than the more literal tablet. Figma
/// 1915:16354 does draw a tablet, but it is its own phone outline 1.17px wider
/// (9.33 vs 8.17 at 14px) with the same dot — the two channels an operator is
/// least able to guess between would be back on indistinguishable icons.
///
/// App and counter orders use Figma's own `smartphone` / `store` exports.
class PosOrderSourceIcon extends StatelessWidget {
  final String channelKey;

  /// FINISHED cards draw the badge without its ring, with the thinner glyphs
  /// Figma gives that section.
  final bool finished;

  const PosOrderSourceIcon({
    super.key,
    required this.channelKey,
    this.finished = false,
  });

  /// The 14px glyph inside the card's badge.
  static Widget cardGlyph(String channelKey, {bool finished = false}) {
    final String? asset = switch (channelKey) {
      'web_app' => finished
          ? Images.posOrdersSmartphoneFinishedSvg
          : Images.posOrdersSmartphoneSvg,
      'counter_pos' =>
        finished ? Images.posOrdersStoreFinishedSvg : Images.posOrdersStoreSvg,
      _ => null,
    };

    if (asset != null) {
      return SvgPicture.asset(
        asset,
        width: PosOrdersSpec.sourceIconSize,
        height: PosOrdersSpec.sourceIconSize,
      );
    }

    return Icon(
      iconFor(channelKey),
      size: PosOrdersSpec.sourceIconSize,
      color: PosHomeSpec.ink,
    );
  }

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
          border: finished
              ? null
              : Border.all(
                  color: PosHomeSpec.ink,
                  width: PosOrdersSpec.sourceBadgeBorder,
                ),
        ),
        child: cardGlyph(channelKey, finished: finished),
      ),
    );
  }
}
