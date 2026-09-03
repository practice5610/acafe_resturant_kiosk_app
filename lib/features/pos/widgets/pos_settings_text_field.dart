import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Labeled text field matching Figma Settings inputs (1641:3933).
class PosSettingsTextField extends StatelessWidget {
  final String label;
  final String? optionalLabel;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final int maxLines;

  const PosSettingsTextField({
    super.key,
    required this.label,
    required this.controller,
    this.optionalLabel,
    this.onChanged,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: loewBold.copyWith(
                fontSize: PosSettingsSpec.labelSize,
                color: PosSettingsSpec.ink,
              ),
            ),
            if (optionalLabel != null) ...[
              const SizedBox(width: 6),
              Text(
                optionalLabel!,
                style: loewBold.copyWith(
                  fontSize: PosSettingsSpec.labelSize,
                  color: PosSettingsSpec.inkMuted(),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: PosSettingsSpec.labelGap),
        DecoratedBox(
          decoration: BoxDecoration(
            color: PosSettingsSpec.fieldFill,
            borderRadius:
                BorderRadius.circular(PosSettingsSpec.fieldRadius),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFB4544A)
                  : PosSettingsSpec.fieldBorder,
              width: PosSettingsSpec.fieldBorderWidth,
            ),
          ),
          child: Padding(
            padding: PosSettingsSpec.fieldPadding,
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              keyboardType: keyboardType,
              inputFormatters: inputFormatters,
              textInputAction: textInputAction,
              maxLines: maxLines,
              cursorColor: PosSettingsSpec.ink,
              style: loewBold.copyWith(
                fontSize: PosSettingsSpec.fieldTextSize,
                color: PosSettingsSpec.ink,
                height: 1.2,
              ),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: loewRegular.copyWith(
              fontSize: 12,
              color: const Color(0xFFB4544A),
            ),
          ),
        ],
      ],
    );
  }
}
