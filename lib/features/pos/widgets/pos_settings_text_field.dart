import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Labeled text field for Settings forms — focus ink ring + soft lift.
class PosSettingsTextField extends StatefulWidget {
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
  State<PosSettingsTextField> createState() => _PosSettingsTextFieldState();
}

class _PosSettingsTextFieldState extends State<PosSettingsTextField> {
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _focus = FocusNode()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError =
        widget.errorText != null && widget.errorText!.isNotEmpty;
    final bool focused = _focus.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label.toUpperCase(),
              style: loewBold.copyWith(
                fontSize: PosSettingsSpec.labelSize,
                letterSpacing: PosSettingsSpec.labelTracking,
                color: PosSettingsSpec.ink,
              ),
            ),
            if (widget.optionalLabel != null) ...[
              const SizedBox(width: 6),
              Text(
                widget.optionalLabel!,
                style: loewMedium.copyWith(
                  fontSize: PosSettingsSpec.labelSize,
                  color: PosSettingsSpec.inkMuted(0.45),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: PosSettingsSpec.labelGap),
        AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: PosSettingsSpec.fieldFill,
            borderRadius:
                BorderRadius.circular(PosSettingsSpec.fieldRadius),
            border: Border.all(
              color: hasError
                  ? const Color(0xFFB4544A)
                  : focused
                      ? PosSettingsSpec.fieldBorderFocus
                      : PosSettingsSpec.fieldBorder,
              width: focused || hasError
                  ? PosSettingsSpec.fieldBorderFocusWidth
                  : PosSettingsSpec.fieldBorderWidth,
            ),
            boxShadow: focused ? PosSettingsSpec.fieldFocusShadow : null,
          ),
          child: Padding(
            padding: PosSettingsSpec.fieldPadding,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              onChanged: widget.onChanged,
              keyboardType: widget.keyboardType,
              inputFormatters: widget.inputFormatters,
              textInputAction: widget.textInputAction,
              maxLines: widget.maxLines,
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
            widget.errorText!,
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
