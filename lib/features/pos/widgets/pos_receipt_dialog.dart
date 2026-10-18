import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
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

// ── Figma vectors, inlined (nodes 1915:13053 / 13063 / 13046) ─────────────
// Drawn white on the ink well of the selected tile and ink on the idle one.
// (The file also draws the idle icon white — on a 10% well that is close to
// invisible, so the idle tile uses ink like the payment OTHER rows.)
String _svgEmail(String stroke) =>
    '<svg width="14" height="14" viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M3.1 3H10.9C11.7837 3 12.5 3.71634 12.5 4.6V9.4C12.5 10.2837 11.7837 11 10.9 11H3.1C2.21634 11 1.5 10.2837 1.5 9.4V4.6C1.5 3.71634 2.21634 3 3.1 3Z" stroke="$stroke" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M2.3 4.4L7 8L11.7 4.4" stroke="$stroke" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

String _svgPrint(String stroke) =>
    '<svg width="14" height="14" viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M3.5 5V1.8H10.5V5" stroke="$stroke" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M2.7 5H11.3C11.9627 5 12.5 5.53726 12.5 6.2V8.8C12.5 9.46274 11.9627 10 11.3 10H2.7C2.03726 10 1.5 9.46274 1.5 8.8V6.2C1.5 5.53726 2.03726 5 2.7 5Z" stroke="$stroke" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M3.5 8H10.5V12.2H3.5V8Z" stroke="$stroke" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

const _svgX =
    '<svg width="26" height="26" viewBox="0 0 26 26" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M16.2504 9.74987L13.0001 13.0001M13.0001 13.0001L9.74987 16.2504M13.0001 13.0001L9.74987 9.74987M13.0001 13.0001L16.2504 16.2504M23.8343 13.0001C23.8343 18.9837 18.9837 23.8343 13.0001 23.8343C7.01657 23.8343 2.16593 18.9837 2.16593 13.0001C2.16593 7.01657 7.01657 2.16593 13.0001 2.16593C18.9837 2.16593 23.8343 7.01657 23.8343 13.0001Z" stroke="#241F20" stroke-width="2" stroke-linecap="round"/>'
    '</svg>';

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
        child: PosPayTextScope(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            width: 560,
            padding: const EdgeInsets.all(20),
            // Inside stroke, as in the file.
            foregroundDecoration: BoxDecoration(
              border: Border.all(color: _modalBorder, width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            decoration: BoxDecoration(
              color: _modalBg,
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
                // gap-16 · a 0-tall `Line` (1915:13048) with its 1px stroke
                // just above it · gap-16.
                const SizedBox(height: 16),
                const SizedBox(
                  height: 0,
                  child: OverflowBox(
                    minHeight: 1,
                    maxHeight: 1,
                    alignment: Alignment.bottomCenter,
                    child: ColoredBox(
                      color: _divider,
                      child: SizedBox(height: 1, width: double.infinity),
                    ),
                  ),
                ),
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
                'Order #$orderId · ${PosHomeSpec.formatPrice(total, padZero: false)} · How would you like it?',
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
              child: SvgPicture.string(_svgX, width: 26, height: 26),
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
            iconSvg:   _svgEmail('#241F20'),
            iconSvgWh: _svgEmail('#FFFFFF'),
            selected:  selected == 'email',
            onTap:     () => onSelect('email'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MethodTile(
            label:     'Print',
            iconSvg:   _svgPrint('#241F20'),
            iconSvgWh: _svgPrint('#FFFFFF'),
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
          borderRadius: BorderRadius.circular(10),
        ),
        // Inside stroke: the tile is 64 tall (10 + 24 + 6 + 14 + 10).
        foregroundDecoration: BoxDecoration(
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
                  PosPayRadio(selected: selected),
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
          // `Input Field` (1915:13071): 56 tall, text centred, px-14.
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 19.5),
          // No floating label → no notch gap (it would inset the text 4px).
          enabledBorder: OutlineInputBorder(
            gapPadding: 0,
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _tileActive, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            gapPadding: 0,
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
