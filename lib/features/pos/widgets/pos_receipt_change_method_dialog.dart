import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ── palette ───────────────────────────────────────────────────────────────────
const _bg           = Color(0xFFFBF8EF);
const _border       = Color(0xFFF0EBD8);
const _tileBorderSelected  = Color(0xFF241F20);
const _tileBorderUnselected = Color(0xFFF0EBD8);
const _tileBorderOther = Color(0xFFE8E3D5);
const _iconBgDim    = Color(0x1A241F20); // ink @ 10 %
const _hintText     = Color(0xFFA6A199);
const _helperText   = Color(0xFF78706E);
const _ctaBg        = Color(0xFF241F20);
const _ctaLabel     = Color(0xFFF7F1DE);

// ── layout constants (Figma 1915:20539) ──────────────────────────────────────
const _modalWidth       = 820.0;
const _bodyColumnGap    = 28.0;
const _primaryTileRadius = 12.0;
const _otherTileRadius   = 10.0;
const _primaryIconBox    = 32.0;
const _primaryIconBoxRadius = 8.0;
const _primaryIconSize   = 18.0;
const _otherIconBox      = 22.0;
const _otherIconBoxRadius = 5.0;
const _otherIconSize     = 13.0;
const _radioOnSize       = 24.0;
const _radioOffSize      = 18.0;
const _primaryLabelSize  = 15.0;
const _otherLabelSize    = 12.0;
const _primaryTilePad    = 12.0;
const _otherTileV        = 10.0;
const _otherTileH        = 12.0;
const _reasonHeight      = 150.0;
const _reasonRadius      = 12.0;
const _sectionLabelSize  = 11.0;
const _subSectionLabelSize = 10.0;
const _confirmRadius     = 12.0;

// ── inline SVGs ───────────────────────────────────────────────────────────────
String _svgCreditCard(String stroke) =>
    '<svg viewBox="0 0 18 18" fill="none" stroke="$stroke" stroke-width="1.5" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="16" height="12" x="1" y="3" rx="1.5"/>'
    '<path d="M1 7.5h16"/></svg>';

String _svgBanknote(String stroke) =>
    '<svg viewBox="0 0 18 18" fill="none" stroke="$stroke" stroke-width="1.5" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="16" height="10" x="1" y="4" rx="1.5"/>'
    '<circle cx="9" cy="9" r="2"/>'
    '<path d="M4 9h.01M14 9h.01"/></svg>';

String _svgFileText(String stroke) =>
    '<svg viewBox="0 0 13 13" fill="none" stroke="$stroke" stroke-width="1.3" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M8 1H3a1 1 0 0 0-1 1v9a1 1 0 0 0 1 1h7a1 1 0 0 0 1-1V4L8 1z"/>'
    '<path d="M8 1v3h3M9 7H4M9 9H4M6 5H4"/></svg>';

String _svgSmartphone(String stroke) =>
    '<svg viewBox="0 0 13 13" fill="none" stroke="$stroke" stroke-width="1.3" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="7" height="11" x="3" y="1" rx="1.5"/>'
    '<path d="M6.5 9.5h.01"/></svg>';

const _svgRadioOn =
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="12" cy="12" r="10" fill="#241F20"/>'
    '<circle cx="12" cy="12" r="4" fill="white"/></svg>';

const _svgRadioOff =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#241F20" stroke-width="2" '
    'xmlns="http://www.w3.org/2000/svg"><circle cx="12" cy="12" r="10"/></svg>';

const _svgX =
    '<svg viewBox="0 0 26 26" fill="none" stroke="#241F20" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="13" cy="13" r="11"/>'
    '<path d="m16.5 9.5-7 7"/><path d="m9.5 9.5 7 7"/></svg>';


/// The operator's choice in the change-method dialog. Not yet applied: the
/// payment screen commits it when the operator confirms there.
class PosMethodChangeDraft {
  final String method;
  final String reason;

  const PosMethodChangeDraft({required this.method, required this.reason});
}

/// Opens the "Change payment method" modal (Figma 1915:20539, State 08).
///
/// Returns the new method string (e.g. 'card', 'cash', 'invoice', 'standalone')
/// on a confirmed change, or null if the dialog was dismissed without saving.
Future<PosMethodChangeDraft?> showPosReceiptChangeMethodDialog({
  required BuildContext context,
  required PosReceiptDetail receipt,
}) {
  return showGeneralDialog<PosMethodChangeDraft>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: PosHomeSpec.contextMenuBackdrop,
    pageBuilder: (_, __, ___) => Material(
      type: MaterialType.transparency,
      child: Center(
        child: _ChangeMethodDialog(receipt: receipt),
      ),
    ),
  );
}

// ── Main dialog widget ────────────────────────────────────────────────────────

class _ChangeMethodDialog extends StatefulWidget {
  final PosReceiptDetail receipt;

  const _ChangeMethodDialog({required this.receipt});

  @override
  State<_ChangeMethodDialog> createState() => _ChangeMethodDialogState();
}

class _ChangeMethodDialogState extends State<_ChangeMethodDialog> {
  late String? _selectedMethod;
  final TextEditingController _reasonCtrl = TextEditingController();
  bool _reasonTouched = false;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.receipt.method;
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  String get _currentMethod => _labelFor(widget.receipt.method);

  static String _labelFor(String method) {
    switch (method) {
      case 'card':       return 'Card';
      case 'invoice':    return 'Invoice';
      case 'standalone': return 'Stand-alone';
      default:           return 'Cash';
    }
  }

  void _confirm() {
    final String? method = _selectedMethod;
    final String reason = _reasonCtrl.text.trim();
    if (method == null) return;
    if (reason.isEmpty) {
      setState(() => _reasonTouched = true);
      return;
    }
    Navigator.of(context).pop(PosMethodChangeDraft(method: method, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    final bool reasonEmpty =
        _reasonTouched && _reasonCtrl.text.trim().isEmpty;

    return _SelectionModal(
      receipt: widget.receipt,
      currentMethod: _currentMethod,
      selectedMethod: _selectedMethod,
      reasonCtrl: _reasonCtrl,
      reasonError: reasonEmpty ? 'Please enter a reason for this change.' : null,
      loading: false,
      onSelect: (m) => setState(() => _selectedMethod = m),
      onReasonChanged: (_) {
        if (_reasonTouched) setState(() {});
      },
      onConfirm: _selectedMethod != null ? _confirm : null,
      onClose: () => Navigator.of(context).pop(),
    );
  }
}

// ── State 08: Selection modal ─────────────────────────────────────────────────

class _SelectionModal extends StatelessWidget {
  final PosReceiptDetail receipt;
  final String currentMethod;
  final String? selectedMethod;
  final TextEditingController reasonCtrl;
  final String? reasonError;
  final bool loading;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onReasonChanged;
  final VoidCallback? onConfirm;
  final VoidCallback onClose;

  const _SelectionModal({
    required this.receipt,
    required this.currentMethod,
    required this.selectedMethod,
    required this.reasonCtrl,
    required this.loading,
    required this.onSelect,
    required this.onReasonChanged,
    required this.onConfirm,
    required this.onClose,
    this.reasonError,
  });

  @override
  Widget build(BuildContext context) {
    final double maxH = MediaQuery.of(context).size.height * 0.90;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: _modalWidth, maxHeight: maxH),
      child: Container(
        decoration: BoxDecoration(
          color: _bg,
          border: Border.all(color: _border, width: 1.5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 16,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ModalHeader(
                receipt: receipt,
                currentMethod: currentMethod,
                onClose: onClose,
              ),
              const SizedBox(height: 16),
              const Divider(color: _border, thickness: 1, height: 1),
              const SizedBox(height: 16),
              _ModalBody(
                selectedMethod: selectedMethod,
                reasonCtrl: reasonCtrl,
                reasonError: reasonError,
                onSelect: onSelect,
                onReasonChanged: onReasonChanged,
              ),
              const SizedBox(height: 16),
              _ConfirmButton(loading: loading, onTap: onConfirm),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModalHeader extends StatelessWidget {
  final PosReceiptDetail receipt;
  final String currentMethod;
  final VoidCallback onClose;

  const _ModalHeader({
    required this.receipt,
    required this.currentMethod,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 34),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change payment method',
                style: loewExtraBold.copyWith(
                  fontSize: 18,
                  color: PosHomeSpec.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Receipt #${receipt.id} · ${PosHomeSpec.formatPrice(receipt.total)} · now paid by $currentMethod',
                style: loewBold.copyWith(
                  fontSize: 12,
                  color: PosHomeSpec.inkAlpha(0.60),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onClose,
            child: SvgPicture.string(_svgX, width: 26, height: 26),
          ),
        ),
      ],
    );
  }
}

class _ModalBody extends StatelessWidget {
  final String? selectedMethod;
  final TextEditingController reasonCtrl;
  final String? reasonError;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onReasonChanged;

  const _ModalBody({
    required this.selectedMethod,
    required this.reasonCtrl,
    required this.onSelect,
    required this.onReasonChanged,
    this.reasonError,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _MethodGroup(
            selectedMethod: selectedMethod,
            onSelect: onSelect,
          ),
        ),
        const SizedBox(width: _bodyColumnGap),
        Expanded(
          child: _ReasonGroup(
            ctrl: reasonCtrl,
            error: reasonError,
            onChanged: onReasonChanged,
          ),
        ),
      ],
    );
  }
}

// ── Method picker column ──────────────────────────────────────────────────────

class _MethodGroup extends StatelessWidget {
  final String? selectedMethod;
  final ValueChanged<String> onSelect;

  const _MethodGroup({required this.selectedMethod, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'NEW PAYMENT METHOD',
          style: loewBold.copyWith(
            fontSize: _sectionLabelSize,
            color: PosHomeSpec.inkAlpha(0.60),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'PRIMARY',
          style: loewBold.copyWith(
            fontSize: _subSectionLabelSize,
            color: PosHomeSpec.inkAlpha(0.33),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        _PrimaryMethodTile(
          label: 'Card',
          value: 'card',
          icon: _svgCreditCard,
          selected: selectedMethod == 'card',
          onTap: () => onSelect('card'),
        ),
        const SizedBox(height: 8),
        _PrimaryMethodTile(
          label: 'Cash',
          value: 'cash',
          icon: _svgBanknote,
          selected: selectedMethod == 'cash',
          onTap: () => onSelect('cash'),
        ),
        const SizedBox(height: 8),
        Text(
          'OTHER',
          style: loewBold.copyWith(
            fontSize: _subSectionLabelSize,
            color: PosHomeSpec.inkAlpha(0.33),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        _OtherMethodTile(
          label: 'Invoice',
          value: 'invoice',
          iconBuilder: _svgFileText,
          selected: selectedMethod == 'invoice',
          onTap: () => onSelect('invoice'),
        ),
        const SizedBox(height: 8),
        _OtherMethodTile(
          label: 'Stand-alone',
          value: 'standalone',
          iconBuilder: _svgSmartphone,
          selected: selectedMethod == 'standalone',
          onTap: () => onSelect('standalone'),
        ),
      ],
    );
  }
}

typedef _IconBuilder = String Function(String stroke);

class _PrimaryMethodTile extends StatelessWidget {
  final String label;
  final String value;
  final _IconBuilder icon;
  final bool selected;
  final VoidCallback onTap;

  const _PrimaryMethodTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor =
        selected ? _tileBorderSelected : _tileBorderUnselected;
    final Color iconBoxBg = selected ? PosHomeSpec.ink : _iconBgDim;
    final String iconStroke = selected ? 'white' : '#241F20';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(_primaryTilePad),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: borderColor,
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(_primaryTileRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: _primaryIconBox,
                  height: _primaryIconBox,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBoxBg,
                    borderRadius:
                        BorderRadius.circular(_primaryIconBoxRadius),
                  ),
                  child: SvgPicture.string(
                    icon(iconStroke),
                    width: _primaryIconSize,
                    height: _primaryIconSize,
                  ),
                ),
                SvgPicture.string(
                  selected ? _svgRadioOn : _svgRadioOff,
                  width: selected ? _radioOnSize : _radioOffSize,
                  height: selected ? _radioOnSize : _radioOffSize,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: loewBold.copyWith(
                fontSize: _primaryLabelSize,
                color: PosHomeSpec.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OtherMethodTile extends StatelessWidget {
  final String label;
  final String value;
  final _IconBuilder iconBuilder;
  final bool selected;
  final VoidCallback onTap;

  const _OtherMethodTile({
    required this.label,
    required this.value,
    required this.iconBuilder,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color borderColor =
        selected ? _tileBorderSelected : _tileBorderOther;
    final Color iconBoxBg = selected ? PosHomeSpec.ink : _iconBgDim;
    final String iconStroke = selected ? 'white' : '#241F20';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: _otherTileH,
          vertical: _otherTileV,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: borderColor,
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(_otherTileRadius),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: _otherIconBox,
                  height: _otherIconBox,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconBoxBg,
                    borderRadius:
                        BorderRadius.circular(_otherIconBoxRadius),
                  ),
                  child: SvgPicture.string(
                    iconBuilder(iconStroke),
                    width: _otherIconSize,
                    height: _otherIconSize,
                  ),
                ),
                SvgPicture.string(
                  selected ? _svgRadioOn : _svgRadioOff,
                  width: selected ? _radioOnSize : _radioOffSize,
                  height: selected ? _radioOnSize : _radioOffSize,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: loewMedium.copyWith(
                  fontSize: _otherLabelSize,
                  color: selected
                      ? PosHomeSpec.ink
                      : PosHomeSpec.inkAlpha(0.47),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reason textarea column ────────────────────────────────────────────────────

class _ReasonGroup extends StatelessWidget {
  final TextEditingController ctrl;
  final String? error;
  final ValueChanged<String>? onChanged;

  const _ReasonGroup({
    required this.ctrl,
    this.error,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasError = error != null;
    final Color borderColor = hasError ? const Color(0xFFD32F2F) : PosHomeSpec.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'REASON',
              style: loewBold.copyWith(
                fontSize: _sectionLabelSize,
                color: PosHomeSpec.inkAlpha(0.60),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              ' *',
              style: loewBold.copyWith(
                fontSize: _sectionLabelSize,
                color: const Color(0xFFD32F2F),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: _reasonHeight,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(_reasonRadius),
          ),
          child: TextField(
            controller: ctrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            onChanged: onChanged,
            style: loewRegular.copyWith(
              fontSize: 14,
              color: PosHomeSpec.ink,
            ),
            decoration: InputDecoration(
              hintText: 'e.g. Customer paid cash after card failed',
              hintStyle: loewRegular.copyWith(
                fontSize: 14,
                color: _hintText,
              ),
              contentPadding: const EdgeInsets.only(
                left: 14,
                right: 14,
                top: 16,
                bottom: 10,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (hasError)
          Text(
            error!,
            style: loewBold.copyWith(
              fontSize: 12,
              color: const Color(0xFFD32F2F),
            ),
          )
        else
          Text(
            'The amount stays the same. The change is logged with your name and time.',
            style: loewBold.copyWith(
              fontSize: 12,
              color: _helperText,
            ),
          ),
      ],
    );
  }
}

// ── Confirm button ────────────────────────────────────────────────────────────

class _ConfirmButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;

  const _ConfirmButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null && !loading;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: onTap == null ? 0.40 : 1.0,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _ctaBg,
            borderRadius: BorderRadius.circular(_confirmRadius),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  'Confirm change',
                  style: loewExtraBold.copyWith(
                    fontSize: 14,
                    color: _ctaLabel,
                  ),
                ),
        ),
      ),
    );
  }
}

