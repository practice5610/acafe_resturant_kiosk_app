import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Settings select — ink focus ring, checkmark for the active option.
class PosSettingsDropdown extends StatelessWidget {
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

  String get _displayLabel {
    for (final PosSettingsOption o in options) {
      if (o.value == value) return o.label;
    }
    return value;
  }

  Future<void> _open(BuildContext context) async {
    final RenderBox box = context.findRenderObject() as RenderBox;
    final Offset origin = box.localToGlobal(Offset.zero);
    final Size size = box.size;

    final String? picked = await showMenu<String>(
      context: context,
      color: PosSettingsSpec.fieldFill,
      elevation: 12,
      shadowColor: const Color(0x33241F20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosSettingsSpec.fieldRadius),
        side: const BorderSide(color: PosSettingsSpec.fieldBorder),
      ),
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy + size.height + 6,
        origin.dx + size.width,
        origin.dy,
      ),
      constraints: BoxConstraints(
        minWidth: size.width,
        maxWidth: size.width,
      ),
      items: [
        for (final PosSettingsOption option in options)
          PopupMenuItem<String>(
            value: option.value,
            height: 44,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    option.label,
                    style: loewBold.copyWith(
                      fontSize: PosSettingsSpec.fieldTextSize,
                      color: PosSettingsSpec.ink,
                    ),
                  ),
                ),
                if (option.value == value)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: PosSettingsSpec.ink,
                  ),
              ],
            ),
          ),
      ],
    );

    if (picked != null && picked != value) {
      onChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: loewBold.copyWith(
            fontSize: PosSettingsSpec.labelSize,
            letterSpacing: PosSettingsSpec.labelTracking,
            color: PosSettingsSpec.ink,
          ),
        ),
        const SizedBox(height: PosSettingsSpec.labelGap),
        Material(
          color: PosSettingsSpec.fieldFill,
          borderRadius: BorderRadius.circular(PosSettingsSpec.fieldRadius),
          child: InkWell(
            onTap: () => _open(context),
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
      ],
    );
  }
}
