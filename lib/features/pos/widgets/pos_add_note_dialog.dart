import 'dart:math' as math;

import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// `order_details.instruction` is a varchar(255): a longer note would be
/// refused by checkout and by receipt save-changes alike.
const int kPosNoteMaxLength = 255;

/// POS "Add Note" modal — Figma `Note – Add note to item` (1915:14827).
///
/// Opened from the customize header's ADD NOTE button. [quickAdd] is the
/// product's own quick-add suggestions (configured on the product create
/// screen); an empty list hides the Quick Add section entirely. Returns the
/// edited note string (empty string clears it), or null if dismissed.
Future<String?> showPosAddNoteDialog({
  required BuildContext context,
  String? initialNote,
  List<String> quickAdd = const [],
}) {
  return showGeneralDialog<String?>(
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
              child: _AddNoteModal(
                initialNote: initialNote,
                quickAdd: quickAdd,
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _AddNoteModal extends StatefulWidget {
  final String? initialNote;
  final List<String> quickAdd;

  const _AddNoteModal({this.initialNote, required this.quickAdd});

  @override
  State<_AddNoteModal> createState() => _AddNoteModalState();
}

class _AddNoteModalState extends State<_AddNoteModal> {
  static const Color _hairline = PosHomeSpec.hairline; // #F0EBD8

  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: widget.initialNote ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _appendQuick(String phrase) {
    final String current = _note.text.trim();
    final String next = current.isEmpty ? phrase : '$current, $phrase';
    _note.text = next;
    _note.selection = TextSelection.collapsed(offset: next.length);
  }

  void _save() {
    final String note = _note.text.trim();
    // Quick Add writes the controller directly, past the input formatter.
    Navigator.of(context).pop(note.length > kPosNoteMaxLength
        ? note.substring(0, kPosNoteMaxLength).trim()
        : note);
  }

  /// Lays the product's quick-add suggestions out two per row (Figma shows a
  /// 2-column grid), handling any count including an odd last item.
  List<Widget> _quickAddRows() {
    final List<String> items = widget.quickAdd;
    final List<Widget> rows = [];
    for (int i = 0; i < items.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(Row(
        children: [
          Expanded(child: _QuickChip(items[i], _appendQuick)),
          const SizedBox(width: 8),
          Expanded(
            child: i + 1 < items.length
                ? _QuickChip(items[i + 1], _appendQuick)
                : const SizedBox.shrink(),
          ),
        ],
      ));
    }
    return rows;
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
          border: Border.all(color: _hairline, width: 1.5),
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
                        'Add Note',
                        style: loewExtraBold.copyWith(
                          fontSize: 18,
                          color: PosHomeSpec.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add a note for this item',
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
              color: _hairline,
              child: SizedBox(height: 1, width: double.infinity),
            ),
            const SizedBox(height: 16),
            Text(
              'NOTE',
              style: loewBold.copyWith(
                fontSize: 11,
                color: TextTones.secondary,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _hairline, width: 1.5),
              ),
              child: TextField(
                controller: _note,
                autofocus: true,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(kPosNoteMaxLength),
                ],
                cursorColor: PosHomeSpec.ink,
                style: loewRegular.copyWith(
                  fontSize: 14,
                  color: PosHomeSpec.ink,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Less ice, no nuts',
                  hintStyle: loewRegular.copyWith(
                    fontSize: 14,
                    color: TextTones.hint,
                  ),
                ),
              ),
            ),
            // Quick Add is per-product (configured on the product create
            // screen). Hidden entirely when the product defines no suggestions.
            if (widget.quickAdd.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Quick Add',
                style: loewExtraBold.copyWith(
                  fontSize: 14,
                  color: PosHomeSpec.ink,
                ),
              ),
              const SizedBox(height: 8),
              ..._quickAddRows(),
            ],
            const SizedBox(height: 16),
            const ColoredBox(
              color: _hairline,
              child: SizedBox(height: 1, width: double.infinity),
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
                    'Add Note',
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

class _QuickChip extends StatelessWidget {
  final String label;
  final ValueChanged<String> onTap;

  const _QuickChip(this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => onTap(label),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 67,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PosHomeSpec.hairline, width: 1.5),
          ),
          child: Text(
            label,
            style: loewExtraBold.copyWith(
              fontSize: 13,
              color: PosHomeSpec.ink,
            ),
          ),
        ),
      ),
    );
  }
}
