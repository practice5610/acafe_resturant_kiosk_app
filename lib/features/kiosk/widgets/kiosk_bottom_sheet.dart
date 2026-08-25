import 'package:flutter/material.dart';
import 'package:acafe_customer/common/responsive/responsive.dart';

/// Bottom-anchored modal sheet wrapper for kiosk (coupon, filter, etc.).
///
/// [showModalBottomSheet] with `useSafeArea: true` insets the whole sheet above
/// the system bottom inset, which leaves a visible gap on web/kiosk. This helper
/// turns safe area off and pins content to the viewport bottom instead.
///
/// A full-height transparent layer is used for bottom alignment; without an
/// explicit dismiss [GestureDetector] that layer swallows taps on the dark
/// scrim so `isDismissible` never fires. Tapping the dimmed area above the sheet
/// closes the modal; taps on the sheet itself are unchanged.
class KioskBottomSheet extends StatelessWidget {
  final Widget child;
  final double heightFactor;
  final double? maxWidth;
  final bool expandToHeightFactor;

  const KioskBottomSheet({
    super.key,
    required this.child,
    this.heightFactor = 0.55,
    this.maxWidth,
    this.expandToHeightFactor = false,
  });

  @override
  Widget build(BuildContext context) {
    final double viewportHeight = MediaQuery.sizeOf(context).height;
    final double maxHeight = viewportHeight * heightFactor;
    final bool wide = Responsive.isWide(context);
    final double widthCap = maxWidth ?? (wide ? 640.0 : double.infinity);

    final BoxConstraints childConstraints = expandToHeightFactor
        ? BoxConstraints(
            maxWidth: widthCap, minHeight: maxHeight, maxHeight: maxHeight)
        : BoxConstraints(maxWidth: widthCap, maxHeight: maxHeight);

    final Widget sheet = Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SizedBox(
        width: widthCap < double.infinity ? widthCap : double.infinity,
        child: ConstrainedBox(
          constraints: childConstraints,
          child: child,
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        // Tap the dimmed scrim → close (standard modal behaviour).
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        ),
        // Sheet sits above the scrim; [Align] only hit-tests on the sheet itself.
        Align(
          alignment: Alignment.bottomCenter,
          child: sheet,
        ),
      ],
    );
  }
}

/// Shows a kiosk modal sheet pinned flush to the bottom of the viewport.
Future<T?> showKioskBottomSheet<T>(
  BuildContext context, {
  required Widget child,
  double heightFactor = 0.55,
  double? maxWidth,
  bool expandToHeightFactor = false,
}) {
  return showModalBottomSheet<T>(
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: false,
    useRootNavigator: false,
    context: context,
    builder: (ctx) => KioskBottomSheet(
      heightFactor: heightFactor,
      maxWidth: maxWidth,
      expandToHeightFactor: expandToHeightFactor,
      child: child,
    ),
  );
}
