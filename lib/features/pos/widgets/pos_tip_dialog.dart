import 'dart:math' as math;

import 'package:acafe_customer/features/kiosk/domain/kiosk_tip.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// POS "Add tip" modal for Family 1 — opened from the payment screen's tip row
/// (`tip-section`, nodes 1915:9506 / 10298).
///
/// There is no dedicated tip-modal frame in the payment layer, so this follows
/// the established POS modal pattern (the Apply-discount modal, Figma
/// 1915:14411): a centred `showGeneralDialog` card on the same tokens, with
/// percent presets + a custom € amount and a live total preview.
///
/// Returns the chosen tip in currency, or `null` if dismissed without applying.
/// `0` is a valid result (the operator chose "No tip").
Future<double?> showPosTipDialog({
  required BuildContext context,
  required double payable,
  required double currentTip,
}) {
  return showGeneralDialog<double>(
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
              child: _TipModal(payable: payable, currentTip: currentTip),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// Draft of the tip being composed. Exactly one of [percent] / [custom] drives
/// the amount; the other is null.
@immutable
class _TipDraft {
  /// A chosen preset percentage (0 = "No tip"). Null when a custom € amount is
  /// being entered instead.
  final int? percent;

  /// A custom € amount. Null when a preset is selected.
  final double? custom;

  const _TipDraft({this.percent, this.custom});
}

class _TipModal extends StatefulWidget {
  final double payable;
  final double currentTip;

  const _TipModal({required this.payable, required this.currentTip});

  @override
  State<_TipModal> createState() => _TipModalState();
}

class _TipModalState extends State<_TipModal> {
  static const Color _muted = PosUI.inkMuted;
  static const Color _hairline = PosHomeSpec.contextMenuBorder; // #EAE5D5

  /// Presets, skipping the kiosk's `0` tile (handled by the "No tip" chip).
  static const List<int> _presets = [5, 10, 15];

  late final ValueNotifier<_TipDraft> _draft;
  final TextEditingController _customController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.currentTip > 0) {
      _draft = ValueNotifier(_TipDraft(custom: widget.currentTip));
      _customController.text = _format(widget.currentTip);
    } else {
      _draft = ValueNotifier(const _TipDraft(percent: 0));
    }
  }

  @override
  void dispose() {
    _draft.dispose();
    _customController.dispose();
    super.dispose();
  }

  String _format(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(2) : v.toStringAsFixed(2);

  /// The tip amount a draft resolves to, clamped at >= 0.
  double _tipOf(_TipDraft d) {
    final double raw = d.percent != null
        ? kioskTipAmount(widget.payable, d.percent!)
        : (d.custom ?? 0);
    return math.max(0, raw);
  }

  void _selectPercent(int percent) {
    _customController.clear();
    _draft.value = _TipDraft(percent: percent);
  }

  void _onCustomTyped(String text) {
    final double parsed = double.tryParse(text.replaceAll(',', '.')) ?? 0;
    _draft.value = _TipDraft(custom: parsed);
  }

  void _apply() => Navigator.of(context).pop(_tipOf(_draft.value));

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final double width = math.min(460, screen.width - 48);
    final double maxHeight = screen.height - 48;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: PosHomeSpec.panelBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _hairline, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000), // rgba(0,0,0,0.2)
              offset: Offset(0, 18),
              blurRadius: 48,
              spreadRadius: -12,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            Flexible(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sectionLabel('PRESET TIP'),
                      const SizedBox(height: 10),
                      _presetRow(),
                      const SizedBox(height: 24),
                      _customCard(),
                      const SizedBox(height: 20),
                      _previewCard(),
                    ],
                  ),
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add tip',
                  style: loewExtraBold.copyWith(
                    fontSize: 22,
                    color: PosHomeSpec.ink,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Added on top of the amount due.',
                  style: swiss721Light.copyWith(
                    fontSize: 13,
                    color: _muted,
                    height: 18 / 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 30,
            height: 30,
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.of(context).pop(),
                child: const Icon(Icons.close, size: 20, color: PosHomeSpec.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: loewBold.copyWith(
          fontSize: 11,
          color: _muted,
          letterSpacing: 1,
          height: 1.0,
        ),
      );

  Widget _presetRow() {
    return ValueListenableBuilder<_TipDraft>(
      valueListenable: _draft,
      builder: (context, d, _) {
        Widget chip(String label, bool active, VoidCallback onTap) => Expanded(
              child: _PresetButton(label: label, active: active, onTap: onTap),
            );
        return Row(
          children: [
            chip('No tip', d.percent == 0, () => _selectPercent(0)),
            for (final int p in _presets) ...[
              const SizedBox(width: 12),
              chip('$p%', d.percent == p, () => _selectPercent(p)),
            ],
          ],
        );
      },
    );
  }

  Widget _customCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PosHomeSpec.pageBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Custom',
            style: loewExtraBold.copyWith(fontSize: 14, color: PosHomeSpec.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter a tip amount',
            style: swiss721Light.copyWith(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 12),
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: PosHomeSpec.ink, width: 1.5),
            ),
            child: Row(
              children: [
                Text('€', style: loewBold.copyWith(fontSize: 14, color: _muted)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _customController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    cursorColor: PosHomeSpec.ink,
                    onChanged: _onCustomTyped,
                    onTap: () {
                      // Typing a custom amount supersedes any preset selection.
                      if (_draft.value.percent != null) {
                        _draft.value = const _TipDraft(custom: 0);
                      }
                    },
                    style: loewBold.copyWith(fontSize: 24, color: PosHomeSpec.ink),
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '0.00',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _hairline),
      ),
      child: ValueListenableBuilder<_TipDraft>(
        valueListenable: _draft,
        builder: (context, d, _) {
          final double tip = _tipOf(d);
          final double total = widget.payable + tip;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _sectionLabel('PREVIEW'),
              const SizedBox(height: 12),
              _previewRow('Amount due', PosHomeSpec.formatPrice(widget.payable),
                  bold: false),
              const SizedBox(height: 10),
              _previewRow('Tip', PosHomeSpec.formatPrice(tip),
                  bold: false, color: PosHomeSpec.discountGreen),
              const SizedBox(height: 10),
              const ColoredBox(
                color: _hairline,
                child: SizedBox(height: 1, width: double.infinity),
              ),
              const SizedBox(height: 10),
              _previewRow('Total', PosHomeSpec.formatPrice(total), bold: true),
            ],
          );
        },
      ),
    );
  }

  Widget _previewRow(String label, String value,
      {required bool bold, Color color = PosHomeSpec.ink}) {
    final TextStyle style =
        (bold ? loewExtraBold : loewBold).copyWith(fontSize: 13, color: color);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }

  Widget _bottomBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: PosHomeSpec.pageBg,
        border: Border(top: BorderSide(color: PosHomeSpec.ink, width: 2)),
        boxShadow: [
          BoxShadow(
            color: Color(0x14241F20), // rgba(36,31,32,0.08)
            offset: Offset(0, -6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Material(
        color: PosHomeSpec.ink,
        borderRadius: BorderRadius.circular(32),
        child: InkWell(
          onTap: _apply,
          borderRadius: BorderRadius.circular(32),
          child: SizedBox(
            height: 64,
            width: double.infinity,
            child: Center(
              child: ValueListenableBuilder<_TipDraft>(
                valueListenable: _draft,
                builder: (context, d, _) {
                  final double tip = _tipOf(d);
                  return Text(
                    tip > 0 ? 'Add ${PosHomeSpec.formatPrice(tip)} tip' : 'Done',
                    style: loewBold.copyWith(fontSize: 18, color: Colors.white),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded preset pill — matches the Apply-discount modal's preset buttons.
class _PresetButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? Colors.black : Colors.transparent,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            border: active ? null : Border.all(color: Colors.black, width: 2),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: loewMedium.copyWith(
              fontSize: 13,
              color: active ? Colors.white : Colors.black,
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
