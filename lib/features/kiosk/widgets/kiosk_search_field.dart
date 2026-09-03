import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/utill/styles.dart';

/// Manager-screen chrome neutrals. Warm, not grey -- a neutral grey hairline
/// reads as stock Material against the cream page; these are tinted out of the
/// same family as the page background so the controls belong to the kiosk.
const Color kKioskHairline = Color(0xFFE4DCC6);
const Color kKioskMutedFg = Color(0xFF837B69);
const Color kKioskSubtleFill = Color(0xFFF2ECDC);

/// Hairline/outline widths have to be clamped: at kiosk scales `1.5 * s` lands
/// below a physical pixel on small displays and the border disappears.
double kioskStroke(double value, double s) => (value * s).clamp(1.0, 4.0);

/// The manager cards' shadow, shared with the toolbars so a search field sits
/// on the page at the same elevation as the list below it instead of looking
/// like a different design system bolted on top.
List<BoxShadow> kioskCardShadow(double s) => [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 12 * s,
        offset: Offset(0, 4 * s),
      ),
    ];

/// Pill search field used across the PIN-gated manager screens (stock list,
/// transaction history). Shared so every manager search looks and behaves the
/// same -- same focus ring, same clear affordance, same kiosk-scaled type.
class KioskSearchField extends StatelessWidget {
  final double s;
  final double height;
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasQuery;
  final VoidCallback onClear;
  final String hintText;
  final TextInputType? keyboardType;

  const KioskSearchField({
    super.key,
    required this.s,
    required this.height,
    required this.controller,
    required this.focusNode,
    required this.hasQuery,
    required this.onClear,
    required this.hintText,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: focusNode,
      builder: (context, _) {
        final bool focused = focusNode.hasFocus;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: height,
          padding: EdgeInsets.only(
            left: 30 * s,
            right: hasQuery ? 10 * s : 30 * s,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(height / 2),
            // The focus ring is the whole affordance here: at rest the field is
            // a soft warm hairline, on focus it takes the kiosk's black outline.
            border: Border.all(
              color: focused ? KioskUI.dark : kKioskHairline,
              width: kioskStroke(focused ? 3 : 1.5, s),
            ),
            boxShadow: kioskCardShadow(s),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 34 * s,
                color: focused ? KioskUI.dark : kKioskMutedFg,
              ),
              SizedBox(width: 16 * s),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: keyboardType,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => focusNode.unfocus(),
                  cursorColor: KioskUI.dark,
                  cursorWidth: kioskStroke(3, s),
                  cursorRadius: Radius.circular(2 * s),
                  style: loewMedium.copyWith(
                      fontSize: 27 * s, color: KioskUI.dark),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: hintText,
                    hintStyle: loewMedium.copyWith(
                        fontSize: 27 * s, color: kKioskMutedFg),
                  ),
                ),
              ),
              if (hasQuery)
                KioskTap(
                  onTap: onClear,
                  child: Container(
                    width: height - 24 * s,
                    height: height - 24 * s,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: kKioskSubtleFill,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded,
                        size: 28 * s, color: KioskUI.dark),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
