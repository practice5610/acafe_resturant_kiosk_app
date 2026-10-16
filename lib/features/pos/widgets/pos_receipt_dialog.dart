import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_send_repo.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ── palette (Figma 1915:13024 / 1915:13077) ──────────────────────────────────
const _modalBg     = Color(0xFFFBF8EF);
const _modalBorder = Color(0xFFF0EBD8);
const _divider     = Color(0xFFF0EBD8);
const _tileActive  = Color(0xFF241F20);
const _tileIdle    = Color(0xFFE8E3D5);
const _iconBgIdle  = Color(0x1A241F20); // ink @ 10 %
const _hintColor   = Color(0xFF78706E);
const _ctaBg       = Color(0xFF241F20);
const _ctaLabel    = Color(0xFFF7F1DE);
const _subtitleOp  = 0.60;

// ── inline SVG icon strings ───────────────────────────────────────────────────
const _inkHex = '#241F20';

const _svgEmail =
    '<svg viewBox="0 0 24 24" fill="none" stroke="$_inkHex" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="20" height="16" x="2" y="4" rx="2"/>'
    '<path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></svg>';

const _svgEmailWhite =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<rect width="20" height="16" x="2" y="4" rx="2"/>'
    '<path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"/></svg>';

const _svgPrint =
    '<svg viewBox="0 0 24 24" fill="none" stroke="$_inkHex" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/>'
    '<path d="M6 9V3a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v6"/>'
    '<rect width="12" height="8" x="6" y="14" rx="1"/></svg>';

const _svgPrintWhite =
    '<svg viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/>'
    '<path d="M6 9V3a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v6"/>'
    '<rect width="12" height="8" x="6" y="14" rx="1"/></svg>';

const _svgX =
    '<svg viewBox="0 0 24 24" fill="none" stroke="$_inkHex" stroke-width="2" '
    'stroke-linecap="round" stroke-linejoin="round" xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="12" cy="12" r="10"/>'
    '<path d="m15 9-6 6"/><path d="m9 9 6 6"/></svg>';

const _svgRadioOn =
    '<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
    '<circle cx="12" cy="12" r="10" fill="$_inkHex"/>'
    '<circle cx="12" cy="12" r="4" fill="white"/></svg>';

const _svgRadioOff =
    '<svg viewBox="0 0 24 24" fill="none" stroke="$_inkHex" stroke-width="2" '
    'xmlns="http://www.w3.org/2000/svg"><circle cx="12" cy="12" r="10"/></svg>';

/// Receipt options overlay (Figma 1915:13024 / 1915:13077).
///
/// Two method tiles — Email / Print. Email adds an address input.
/// Sending calls [PosReceiptSendRepo.send] then invokes [onComplete].
/// The X button calls [onSkip] (close without receipt).
class PosReceiptDialog extends StatefulWidget {
  final int orderId;
  final double total;
  final int deviceId;
  final VoidCallback onComplete;
  final VoidCallback onSkip;

  const PosReceiptDialog({
    super.key,
    required this.orderId,
    required this.total,
    required this.deviceId,
    required this.onComplete,
    required this.onSkip,
  });

  @override
  State<PosReceiptDialog> createState() => _PosReceiptDialogState();
}

class _PosReceiptDialogState extends State<PosReceiptDialog> {
  String? _method = 'email';
  bool _loading = false;
  final ValueNotifier<String> _email = ValueNotifier<String>('');

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final String? method = _method;
    if (method == null) return;

    if (method == 'email' && _email.value.trim().isEmpty) {
      showCustomSnackBarHelper('Enter an email address', isError: true);
      return;
    }

    setState(() => _loading = true);

    final String reference =
        'pos-receipt-${widget.orderId}-${DateTime.now().millisecondsSinceEpoch}';

    final response = await di.sl<PosReceiptSendRepo>().send(
      orderId:   widget.orderId,
      method:    method,
      email:     method == 'email' ? _email.value.trim() : null,
      deviceId:  widget.deviceId,
      reference: reference,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!response.isSuccess) {
      showCustomSnackBarHelper(
        'Could not send receipt: ${response.error}',
        isError: true,
      );
      return;
    }

    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            width: 560,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _modalBg,
              border: Border.all(color: _modalBorder, width: 1.5),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 16,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ModalHeader(
                  orderId: widget.orderId,
                  total:   widget.total,
                  onClose: widget.onSkip,
                ),
                const SizedBox(height: 12),
                const Divider(color: _divider, thickness: 1, height: 1),
                const SizedBox(height: 16),
                _MethodTiles(
                  selected: _method,
                  onSelect: (m) => setState(() => _method = m),
                ),
                if (_method == 'email') ...[
                  const SizedBox(height: 16),
                  _EmailInputGroup(notifier: _email),
                ],
                const SizedBox(height: 16),
                _CtaButton(
                  method:  _method,
                  loading: _loading,
                  onTap:   _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Modal header ─────────────────────────────────────────────────────────────

class _ModalHeader extends StatelessWidget {
  final int orderId;
  final double total;
  final VoidCallback onClose;

  const _ModalHeader({
    required this.orderId,
    required this.total,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Receipt',
                style: loewExtraBold.copyWith(
                  fontSize: 18,
                  color: PosHomeSpec.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Order #$orderId · ${PosHomeSpec.formatPrice(total)} · How would you like it?',
                style: loewBold.copyWith(
                  fontSize: 12,
                  color: PosHomeSpec.inkAlpha(_subtitleOp),
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onClose,
              child: SvgPicture.string(
                _svgX,
                width: 26,
                height: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Method tiles ─────────────────────────────────────────────────────────────

class _MethodTiles extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;

  const _MethodTiles({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MethodTile(
            label:     'Email',
            iconSvg:   _svgEmail,
            iconSvgWh: _svgEmailWhite,
            selected:  selected == 'email',
            onTap:     () => onSelect('email'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MethodTile(
            label:     'Print',
            iconSvg:   _svgPrint,
            iconSvgWh: _svgPrintWhite,
            selected:  selected == 'print',
            onTap:     () => onSelect('print'),
          ),
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  final String label;
  final String iconSvg;
  final String iconSvgWh;
  final bool selected;
  final VoidCallback onTap;

  const _MethodTile({
    required this.label,
    required this.iconSvg,
    required this.iconSvgWh,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: selected ? _tileActive : _tileIdle,
            width: selected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? _tileActive : _iconBgIdle,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: SvgPicture.string(
                      selected ? iconSvgWh : iconSvg,
                      width: 14,
                      height: 14,
                    ),
                  ),
                  SvgPicture.string(
                    selected ? _svgRadioOn : _svgRadioOff,
                    width: selected ? 24 : 18,
                    height: selected ? 24 : 18,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: loewMedium.copyWith(
                fontSize: 12,
                color: selected
                    ? PosHomeSpec.ink
                    : PosHomeSpec.inkAlpha(0.47),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Email input group ─────────────────────────────────────────────────────────

class _EmailInputGroup extends StatelessWidget {
  final ValueNotifier<String> notifier;

  const _EmailInputGroup({required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'EMAIL ADDRESS',
          style: loewBold.copyWith(
            fontSize: 11,
            letterSpacing: 0.5,
            color: PosHomeSpec.inkAlpha(_subtitleOp),
          ),
        ),
        const SizedBox(height: 4),
        _EmailField(notifier: notifier),
        const SizedBox(height: 4),
        Text(
          "We'll send a digital copy of this receipt to this address.",
          style: loewBold.copyWith(fontSize: 12, color: _hintColor),
        ),
      ],
    );
  }
}

class _EmailField extends StatefulWidget {
  final ValueNotifier<String> notifier;

  const _EmailField({required this.notifier});

  @override
  State<_EmailField> createState() => _EmailFieldState();
}

class _EmailFieldState extends State<_EmailField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.notifier.value);
    _ctrl.addListener(() => widget.notifier.value = _ctrl.text);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.emailAddress,
        style: loewRegular.copyWith(fontSize: 14, color: PosHomeSpec.ink),
        decoration: InputDecoration(
          hintText: 'customer@example.com',
          hintStyle: loewRegular.copyWith(
            fontSize: 14,
            color: PosHomeSpec.inkAlpha(0.33),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _tileActive, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _tileActive, width: 1.5),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}

// ── CTA button ────────────────────────────────────────────────────────────────

class _CtaButton extends StatelessWidget {
  final String? method;
  final bool loading;
  final VoidCallback onTap;

  const _CtaButton({
    required this.method,
    required this.loading,
    required this.onTap,
  });

  String get _label => method == 'print' ? 'Print receipt' : 'Send email receipt';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: loading ? const Color(0xFFD4CDBA) : _ctaBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
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
                  _label,
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
