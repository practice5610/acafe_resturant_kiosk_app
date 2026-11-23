import 'package:flutter/material.dart';
import 'package:acafe_customer/common/widgets/custom_asset_image_widget.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_translate.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_search_field.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_tap.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';

/// Inline menu search for the kiosk top bar.
///
/// Collapsed it is the same 124-design-px circle as its filter / language
/// neighbours. Tapping it grows a pill in place (no route push), reveals the
/// input left-to-right and focuses it, which raises the on-screen keyboard.
/// The query itself lives in the menu screen so the grid can filter on it.
class KioskMenuSearch extends StatefulWidget {
  final double s;
  final double diameter;
  final double expandedWidth;
  final bool open;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  /// Redesigned menu header look: a white circle with a soft shadow when
  /// collapsed and a borderless white pill when open. Visual only.
  final bool flat;

  const KioskMenuSearch({
    super.key,
    required this.s,
    required this.diameter,
    required this.expandedWidth,
    required this.open,
    required this.controller,
    required this.focusNode,
    required this.onOpen,
    required this.onClose,
    this.flat = false,
  });

  @override
  State<KioskMenuSearch> createState() => _KioskMenuSearchState();
}

class _KioskMenuSearchState extends State<KioskMenuSearch>
    with SingleTickerProviderStateMixin {
  static const Duration _duration = Duration(milliseconds: 320);

  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: _duration,
    value: widget.open ? 1 : 0,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _anim,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(covariant KioskMenuSearch old) {
    super.didUpdateWidget(old);
    if (widget.open == old.open) return;
    if (widget.open) {
      _anim.forward();
      // Focus on the next frame so the TextField is mounted; on a touch kiosk
      // this is what brings the keyboard up.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.open) widget.focusNode.requestFocus();
      });
    } else {
      widget.focusNode.unfocus();
      _anim.reverse();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double s = widget.s;
    final double d = widget.diameter;
    final double stroke = kioskStroke(5, s);

    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) {
        final double t = _curve.value;
        final double width = d + (widget.expandedWidth - d) * t;

        // Fully collapsed: the original circular SVG button, pixel-identical
        // to the filter button beside it.
        if (t == 0 && widget.flat) {
          return Container(
            width: d,
            height: d,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.10),
                  blurRadius: d * 0.2,
                  offset: Offset(0, d * 0.04),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: KioskTap(
                onTap: widget.onOpen,
                child: Center(
                  child:
                      Icon(Icons.search, size: d * 0.48, color: KioskUI.dark),
                ),
              ),
            ),
          );
        }
        if (t == 0) {
          return SizedBox(
            width: d,
            height: d,
            child: KioskTap(
              onTap: widget.onOpen,
              child: CustomAssetImageWidget(Images.searchSvg,
                  width: d, height: d, fit: BoxFit.contain),
            ),
          );
        }

        return Container(
          width: width,
          height: d,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(d / 2),
            border: widget.flat
                ? null
                : Border.all(color: Colors.black, width: stroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black
                    .withValues(alpha: widget.flat ? 0.10 : 0.08 * t),
                blurRadius: 24 * s,
                offset: Offset(0, 8 * s),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              SizedBox(
                width: widget.flat ? d : d - stroke * 2,
                child: Icon(Icons.search_rounded,
                    size: widget.flat ? d * 0.48 : 56 * s, color: KioskUI.dark),
              ),
              Expanded(
                // Left-to-right wipe: the field is laid out at full width and
                // revealed by a growing clip, so text never reflows mid-anim.
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    widthFactor: 1,
                    child: Opacity(
                      opacity: Curves.easeIn.transform(t),
                      child: _field(context),
                    ),
                  ),
                ),
              ),
              _clearButton(t),
            ],
          ),
        );
      },
    );
  }

  Widget _field(BuildContext context) {
    final double s = widget.s;
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      autofocus: false,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => widget.focusNode.unfocus(),
      onTapOutside: (_) => widget.focusNode.unfocus(),
      cursorColor: KioskUI.dark,
      cursorWidth: kioskStroke(3, s),
      maxLines: 1,
      style: loewMedium.copyWith(fontSize: 44 * s, color: KioskUI.dark),
      decoration: InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        hintText:
            kioskTranslate(context, 'search_products', 'Search products…'),
        hintStyle: loewMedium.copyWith(fontSize: 44 * s, color: kKioskMutedFg),
      ),
    );
  }

  Widget _clearButton(double t) {
    final double s = widget.s;
    final double size = widget.diameter - 36 * s;
    return Opacity(
      opacity: t,
      child: Padding(
        padding: EdgeInsets.only(right: 14 * s, left: 8 * s),
        child: KioskTap(
          // Always collapses: clears the query and drops the keyboard.
          onTap: widget.onClose,
          child: Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: kKioskSubtleFill,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close_rounded, size: 44 * s, color: KioskUI.dark),
          ),
        ),
      ),
    );
  }
}
