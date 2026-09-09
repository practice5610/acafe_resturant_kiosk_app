import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Settings select — ink focus ring, checkmark for the active option.
///
/// The menu is inserted into the **root** [Overlay] (not [showMenu]). On the
/// HTML renderer, route-based menus share a DOM stacking context with later
/// form fields (e.g. Default Tax Rate under Default Currency) and end up
/// painted underneath them. A root [OverlayEntry] sits above that context.
class PosSettingsDropdown extends StatefulWidget {
  final String label;
  final String value;
  final List<PosSettingsOption> options;
  final ValueChanged<String> onChanged;

  const PosSettingsDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<PosSettingsDropdown> createState() => _PosSettingsDropdownState();
}

class _PosSettingsDropdownState extends State<PosSettingsDropdown> {
  final LayerLink _link = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _entry;

  String get _displayLabel {
    for (final PosSettingsOption o in widget.options) {
      if (o.value == widget.value) return o.label;
    }
    return widget.value;
  }

  void _close() {
    _entry?.remove();
    _entry = null;
  }

  void _select(String value) {
    _close();
    if (value != widget.value) {
      widget.onChanged(value);
    }
  }

  void _open() {
    if (_entry != null) {
      _close();
      return;
    }

    final BuildContext? fieldContext = _fieldKey.currentContext;
    if (fieldContext == null) return;
    final RenderBox? box = fieldContext.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final Size fieldSize = box.size;
    // Dismiss any focused TextField so its HTML <input> does not sit above
    // the menu on the web HTML renderer.
    FocusManager.instance.primaryFocus?.unfocus();

    _entry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  // Defer removal so we do not mutate the overlay mid hit-test.
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _close();
                  });
                },
                child: const ColoredBox(color: Color(0x00000000)),
              ),
            ),
            CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              offset: Offset(0, fieldSize.height + 6),
              child: Material(
                color: PosSettingsSpec.fieldFill,
                elevation: 24,
                shadowColor: const Color(0x33241F20),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(PosSettingsSpec.fieldRadius),
                  side: const BorderSide(color: PosSettingsSpec.fieldBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: fieldSize.width,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final PosSettingsOption option in widget.options)
                        InkWell(
                          onTap: () => _select(option.value),
                          child: SizedBox(
                            height: 44,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      option.label,
                                      style: loewBold.copyWith(
                                        fontSize:
                                            PosSettingsSpec.fieldTextSize,
                                        color: PosSettingsSpec.ink,
                                      ),
                                    ),
                                  ),
                                  if (option.value == widget.value)
                                    const Icon(
                                      Icons.check_rounded,
                                      size: 18,
                                      color: PosSettingsSpec.ink,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
  }

  @override
  void didUpdateWidget(covariant PosSettingsDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Rebuild the open menu if the selection/options change underneath it.
    if (_entry != null &&
        (oldWidget.value != widget.value ||
            oldWidget.options != widget.options)) {
      _entry!.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: loewBold.copyWith(
            fontSize: PosSettingsSpec.labelSize,
            letterSpacing: PosSettingsSpec.labelTracking,
            color: PosSettingsSpec.ink,
          ),
        ),
        const SizedBox(height: PosSettingsSpec.labelGap),
        CompositedTransformTarget(
          link: _link,
          child: Material(
            key: _fieldKey,
            color: PosSettingsSpec.fieldFill,
            borderRadius: BorderRadius.circular(PosSettingsSpec.fieldRadius),
            child: InkWell(
              onTap: _open,
              borderRadius:
                  BorderRadius.circular(PosSettingsSpec.fieldRadius),
              child: Container(
                width: double.infinity,
                padding: PosSettingsSpec.fieldPadding,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(PosSettingsSpec.fieldRadius),
                  border: Border.all(
                    color: PosSettingsSpec.fieldBorder,
                    width: PosSettingsSpec.fieldBorderWidth,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _displayLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: loewBold.copyWith(
                          fontSize: PosSettingsSpec.fieldTextSize,
                          color: PosSettingsSpec.ink,
                          height: 1.2,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: PosSettingsSpec.chevronSize,
                      height: PosSettingsSpec.chevronSize,
                      child: SvgPicture.asset(
                        Images.posChevronDownSvg,
                        width: PosSettingsSpec.chevronSize,
                        height: PosSettingsSpec.chevronSize,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
