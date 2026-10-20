import 'dart:math' as math;

import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// POS "Who is this order for?" modal — Figma `Customer name – Pop-up`
/// (1915:15751). Edits [controller] in place: "Save & continue" writes the
/// typed name back to the same controller the receipt/order already reads, so
/// nothing about how the name reaches the order changes.
Future<void> showPosCustomerNameDialog({
  required BuildContext context,
  required TextEditingController controller,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: const Color(0x66241F20), // rgba(36,31,32,0.4)
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _CustomerNameModal(controller: controller),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _CustomerNameModal extends StatefulWidget {
  final TextEditingController controller;

  const _CustomerNameModal({required this.controller});

  @override
  State<_CustomerNameModal> createState() => _CustomerNameModalState();
}

class _CustomerNameModalState extends State<_CustomerNameModal> {
  late final TextEditingController _draft;

  @override
  void initState() {
    super.initState();
    _draft = TextEditingController(text: widget.controller.text);
  }

  @override
  void dispose() {
    _draft.dispose();
    super.dispose();
  }

  void _save() {
    widget.controller.text = _draft.text.trim();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final double width = math.min(560, MediaQuery.sizeOf(context).width - 48);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: PosHomeSpec.panelBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PosHomeSpec.hairline, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000), // rgba(0,0,0,0.15)
              offset: Offset(0, 12),
              blurRadius: 16,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Who is this order for?',
                        style: loewExtraBold.copyWith(
                          fontSize: 18,
                          color: PosHomeSpec.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add a name so we can call it out when it’s ready',
                        style: loewBold.copyWith(
                          fontSize: 12,
                          color: TextTones.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context).pop(),
                      child: Icon(
                        Icons.cancel,
                        size: 24,
                        color: PosHomeSpec.inkAlpha(0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const ColoredBox(
              color: PosHomeSpec.hairline,
              child: SizedBox(height: 1, width: double.infinity),
            ),
            const SizedBox(height: 16),
            Text(
              'CUSTOMER NAME',
              style: loewBold.copyWith(
                fontSize: 11,
                color: TextTones.secondary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 41,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: PosHomeSpec.hairline, width: 1.5),
              ),
              child: TextField(
                controller: _draft,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                cursorColor: PosHomeSpec.ink,
                style: loewRegular.copyWith(
                  fontSize: 14,
                  color: PosHomeSpec.ink,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'e.g. Dylan',
                  hintStyle: loewRegular.copyWith(
                    fontSize: 14,
                    color: TextTones.hint,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: PosHomeSpec.ink,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _save,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  child: Text(
                    'Save & continue',
                    style: loewExtraBold.copyWith(
                      fontSize: 14,
                      color: PosHomeSpec.pageBg,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
