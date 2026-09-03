import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The A/CAFÉ wordmark.
///
/// Extracted because the artwork was previously inlined as a raw
/// `SvgPicture.asset` at every call site, each repeating the same recolour and
/// the same pair of magic dimensions. Two details make that worth centralising:
///
///  * The shipped asset carries `preserveAspectRatio="none"`, so it **must** be
///    given both a width and a height or it distorts. Deriving width from
///    height here means no call site can get the ratio wrong.
///  * It ships as pure white (`#FFFFFF`) for use on dark kiosk screens, so
///    every light-background use needs a `srcIn` recolour.
///
/// Sizes in the POS design are just two points on the same ratio — the nav bar
/// uses 68.652 x 18, the PIN card 137.305 x 36 — so callers pass [height] only.
class PosWordmark extends StatelessWidget {
  /// Width / height of the artwork, from the asset's own viewBox
  /// (680.783 / 178.475). The Figma frames agree: 137.305 / 36 and
  /// 68.652 / 18 both land on this.
  static const double aspectRatio = 680.783 / 178.475;

  final double height;
  final Color color;

  const PosWordmark({
    super.key,
    required this.height,
    this.color = PosUI.ink,
  });

  double get width => height * aspectRatio;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      Images.kioskLogoWhiteSvg,
      width: width,
      height: height,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }
}
