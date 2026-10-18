import 'dart:math' as math;

import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_tip_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// POS "Add tip" modal — opened from the payment screen's tip row
/// (`tip-section`, nodes 1915:9506 / 10298).
///
/// Built on the layer's own modal, "Apply discount" (Figma 1915:14411; tokens
/// in [PosTipSpec]): presets that show what they come to, a custom amount in
/// € or % keyed on the payment keypad, a tip summary and a live preview, and
/// the sticky ink bar.
///
/// Returns the chosen tip in currency, or `null` when dismissed. `0` is a
/// valid result ("No tip" / "Remove tip"). Money is held in minor units
/// throughout ([PosCashEntry]); [decimals] is the currency's precision.
Future<double?> showPosTipDialog({
  required BuildContext context,
  required double payable,
  required double currentTip,
  int decimals = 2,
}) {
  return showGeneralDialog<double>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: PosTipSpec.scrim,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, _, __) => PosPayTextScope(
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(PosTipSpec.screenMargin),
            child: Center(
              child: PosTipModal(
                payable: payable,
                currentTip: currentTip,
                decimals: decimals,
                onDone: (tip) => Navigator.of(dialogContext).pop(tip),
                onClose: () => Navigator.of(dialogContext).pop(),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, animation, _, child) {
      final Animation<double> curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.97, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// How the tip is being chosen.
enum PosTipMode { preset, amount, percent }

/// The modal's content. Public so it can be rendered and driven in tests
/// without a route; production opens it through [showPosTipDialog].
class PosTipModal extends StatefulWidget {
  /// The amount due before any tip.
  final double payable;

  /// The tip already on the sale (0 = none) — the modal opens on it.
  final double currentTip;

  final int decimals;
  final ValueChanged<double> onDone;
  final VoidCallback onClose;

  const PosTipModal({
    super.key,
    required this.payable,
    required this.currentTip,
    required this.onDone,
    required this.onClose,
    this.decimals = 2,
  });

  @override
  State<PosTipModal> createState() => _PosTipModalState();
}

class _PosTipModalState extends State<PosTipModal> {
  late PosTipMode _mode;
  int _preset = 0;

  /// The unit the custom card is set to; kept while a preset is picked so the
  /// switch does not jump.
  PosTipMode _customUnit = PosTipMode.amount;
  late PosCashEntry _entry;
  final FocusNode _focus = FocusNode(debugLabel: 'pos-tip');

  int get _payableCents =>
      math.max(0, posMoneyToCents(widget.payable, decimals: widget.decimals));

  /// [percent] of the amount due in minor units, rounded half up.
  int _percentOf(int percent) =>
      percent <= 0 ? 0 : (_payableCents * percent + 50) ~/ 100;

  PosCashEntry _freshEntry(PosTipMode unit) => PosCashEntry(
      decimals: unit == PosTipMode.percent ? 0 : widget.decimals);

  @override
  void initState() {
    super.initState();
    final int current =
        posMoneyToCents(widget.currentTip, decimals: widget.decimals);
    _entry = _freshEntry(PosTipMode.amount);
    _mode = PosTipMode.preset;
    if (current > 0) {
      final int? preset = PosTipSpec.presets
          .where((p) => p > 0 && _percentOf(p) == current)
          .firstOrNull;
      if (preset != null) {
        _preset = preset;
      } else {
        _mode = PosTipMode.amount;
        _entry = _entry.withCents(current);
      }
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  // ── Derived ─────────────────────────────────────────────────────────────

  int get _tipCents => switch (_mode) {
        PosTipMode.preset => _percentOf(_preset),
        PosTipMode.amount => _entry.cents,
        PosTipMode.percent => _percentOf(_entry.cents),
      };

  String _money(int cents) => PosHomeSpec.formatPrice(
      posCentsToMoney(cents, decimals: widget.decimals),
      padZero: false);

  /// Why the current choice cannot be applied, or null.
  String? get _error {
    if (_mode == PosTipMode.percent && _entry.cents > PosTipSpec.maxPercent) {
      return 'A tip can be at most ${PosTipSpec.maxPercent}% of the amount due.';
    }
    if (_mode == PosTipMode.amount && _entry.cents > _payableCents) {
      return "A tip can't be more than the amount due "
          '(${_money(_payableCents)}).';
    }
    return null;
  }

  String get _caption {
    final int tip = _tipCents;
    switch (_mode) {
      case PosTipMode.preset:
        return _preset == 0
            ? 'No tip on this order'
            : '$_preset% of ${_money(_payableCents)}';
      case PosTipMode.percent:
        return _entry.isEmpty
            ? 'Enter a percentage'
            : '${_entry.cents}% of ${_money(_payableCents)}';
      case PosTipMode.amount:
        if (_entry.isEmpty) return 'Enter an amount';
        if (_payableCents <= 0 || tip <= 0) return 'Custom amount';
        final double share = tip * 100 / _payableCents;
        final String pct = share == share.roundToDouble()
            ? share.toStringAsFixed(0)
            : share.toStringAsFixed(1);
        return 'Custom amount · $pct% of ${_money(_payableCents)}';
    }
  }

  String get _barLabel {
    if (_error != null) return 'Add tip';
    final int tip = _tipCents;
    if (tip > 0) return 'Add ${_money(tip)} tip';
    return widget.currentTip > 0 ? 'Remove tip' : 'Continue without tip';
  }

  // ── Input ───────────────────────────────────────────────────────────────

  void _pickPreset(int percent) => setState(() {
        _mode = PosTipMode.preset;
        _preset = percent;
        _entry = _freshEntry(_customUnit);
      });

  void _setUnit(PosTipMode unit) => setState(() {
        _customUnit = unit;
        _mode = unit;
        _entry = _freshEntry(unit);
      });

  void _key(String token) => setState(() {
        if (_mode == PosTipMode.preset) {
          _mode = _customUnit;
          _entry = _freshEntry(_customUnit);
        }
        // A percentage is whole and short: three digits shows "over 100%"
        // without letting the field run on.
        if (_mode == PosTipMode.percent && _entry.raw.length >= 3) return;
        _entry = _entry.key(token);
      });

  void _backspace() => setState(() {
        if (_mode != PosTipMode.preset) _entry = _entry.backspace();
      });

  void _apply() {
    if (_error != null) return;
    widget.onDone(posCentsToMoney(_tipCents, decimals: widget.decimals));
  }

  /// A hardware keyboard works too: digits, `,` / `.`, Backspace, Enter, Esc.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.backspace) {
      _backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _apply();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    final String? ch = event.character;
    if (ch != null && RegExp(r'^[0-9.,]$').hasMatch(ch)) {
      _key(ch == '.' ? ',' : ch);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Layout ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosTipSpec.modalRadius);
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double width =
              math.min(PosTipSpec.modalMaxWidth, constraints.maxWidth);
          final bool twoColumns = width >= PosTipSpec.twoColumnMinWidth;
          final Widget left = _valueColumn();
          final Widget right = _summaryColumn();
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: width,
              maxHeight: constraints.maxHeight,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: PosTipSpec.modalBg,
                borderRadius: radius,
                boxShadow: const [PosTipSpec.modalShadow],
              ),
              // Figma strokes inside the box.
              foregroundDecoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: PosTipSpec.hairline,
                  width: PosTipSpec.modalBorderWidth,
                ),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(
                      payable: _money(_payableCents),
                      onClose: widget.onClose,
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(PosTipSpec.bodyPadding),
                        child: twoColumns
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: left),
                                  const SizedBox(width: PosTipSpec.columnGap),
                                  SizedBox(
                                    width: PosTipSpec.rightColumnWidth,
                                    child: right,
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  left,
                                  const SizedBox(
                                      height: PosTipSpec.leftSectionGap),
                                  right,
                                ],
                              ),
                      ),
                    ),
                    _ApplyBar(
                      label: _barLabel,
                      onTap: _error == null ? _apply : null,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _valueColumn() {
    final bool custom = _mode != PosTipMode.preset;
    final bool percentUnit = _customUnit == PosTipMode.percent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SectionLabel('PRESET TIP'),
        const SizedBox(height: PosTipSpec.labelToContentGap),
        Row(
          children: [
            for (int i = 0; i < PosTipSpec.presets.length; i++) ...[
              if (i > 0) const SizedBox(width: PosTipSpec.presetGap),
              Expanded(
                child: _PresetTile(
                  label: PosTipSpec.presets[i] == 0
                      ? 'No tip'
                      : '${PosTipSpec.presets[i]}%',
                  amount: _money(_percentOf(PosTipSpec.presets[i])),
                  active: !custom && _preset == PosTipSpec.presets[i],
                  onTap: () => _pickPreset(PosTipSpec.presets[i]),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: PosTipSpec.leftSectionGap),
        Container(
          padding: const EdgeInsets.all(PosTipSpec.customPadding),
          decoration: BoxDecoration(
            color: PosTipSpec.customFill,
            borderRadius: BorderRadius.circular(PosTipSpec.customRadius),
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosTipSpec.customRadius),
            border: Border.all(color: PosTipSpec.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Custom',
                          style: loewExtraBold.copyWith(
                            fontSize: PosTipSpec.customLabelSize,
                            color: PosHomeSpec.ink,
                          ),
                        ),
                        const SizedBox(height: PosTipSpec.customCopyGap),
                        Text(
                          percentUnit
                              ? 'Enter another percentage'
                              : 'Enter another tip amount',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: swiss721Light.copyWith(
                            fontSize: PosTipSpec.customHintSize,
                            color: PosTipSpec.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _UnitSwitch(
                    percent: percentUnit,
                    onChanged: (percent) => _setUnit(
                        percent ? PosTipMode.percent : PosTipMode.amount),
                  ),
                ],
              ),
              const SizedBox(height: PosTipSpec.customGap),
              _InputBox(
                text: custom ? _entry.raw : '',
                placeholder: percentUnit ? '0' : '0.00',
                suffix: percentUnit ? '%' : '€',
                active: custom,
                invalid: _error != null,
              ),
              const SizedBox(height: PosTipSpec.customGap),
              PosKeypad(
                rows: PosKeypad.digitRows(
                  decimal: percentUnit ? PosKeypadKeys.spacer : ',',
                ),
                style: posPaymentKeypadStyle(
                    backspaceAsset: Images.posKeyBackspaceSvg),
                scale: PosTipSpec.keypadScale,
                onKey: _key,
                onBackspace: _backspace,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryColumn() {
    final int tip = _tipCents;
    final String? error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Card(
          children: [
            const _SectionLabel('TIP'),
            FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                error == null ? _money(tip) : '—',
                key: const Key('pos-tip-amount'),
                maxLines: 1,
                style: loewExtraBold.copyWith(
                  fontSize: PosTipSpec.summaryAmountSize,
                  height: 1,
                  color: tip > 0 && error == null
                      ? PosTipSpec.tipGreen
                      : PosHomeSpec.ink,
                ),
              ),
            ),
            Text(
              _caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: swiss721Light.copyWith(
                fontSize: PosTipSpec.summaryCaptionSize,
                color: PosTipSpec.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: PosTipSpec.rightSectionGap),
        _Card(
          children: [
            const _SectionLabel('PREVIEW'),
            // Preview content (discount node 1915:14466): rows gap-10.
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _PreviewRow(label: 'Amount due', value: _money(_payableCents)),
                const SizedBox(height: PosTipSpec.previewRowGap),
                _PreviewRow(
                  label: 'Tip',
                  value: error == null ? '+ ${_money(tip)}' : '—',
                  color: PosTipSpec.tipGreen,
                ),
                const SizedBox(height: PosTipSpec.previewRowGap),
                const ColoredBox(
                  color: PosTipSpec.hairline,
                  child: SizedBox(height: 1, width: double.infinity),
                ),
                const SizedBox(height: PosTipSpec.previewRowGap),
                _PreviewRow(
                  label: 'Total',
                  value: error == null ? _money(_payableCents + tip) : '—',
                  total: true,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: PosTipSpec.cardGap),
        Text(
          error ?? 'Charged together with the order.',
          key: const Key('pos-tip-note'),
          style: (error == null ? swiss721Light : loewRegular).copyWith(
            fontSize: PosTipSpec.noteSize,
            color: error == null ? PosTipSpec.muted : PosTipSpec.errorInk,
          ),
        ),
      ],
    );
  }
}

// ── Pieces ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String payable;
  final VoidCallback onClose;

  const _Header({required this.payable, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: PosTipSpec.headerPadding,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PosTipSpec.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add tip',
                  style: loewExtraBold.copyWith(
                    fontSize: PosTipSpec.titleSize,
                    color: PosHomeSpec.ink,
                  ),
                ),
                const SizedBox(height: PosTipSpec.headingGap),
                Text(
                  'Added on top of the amount due · $payable',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: swiss721Light.copyWith(
                    fontSize: PosTipSpec.descriptionSize,
                    height: PosTipSpec.descriptionLine /
                        PosTipSpec.descriptionSize,
                    color: PosTipSpec.muted,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Close',
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onClose,
                // The discount modal's close (node 1915:14417): an 18px X
                // drawn, not an icon font glyph.
                child: const SizedBox(
                  width: PosTipSpec.closeSize,
                  height: PosTipSpec.closeSize,
                  child: Center(
                    child: CustomPaint(
                      size: Size.square(PosTipSpec.closeIconSize),
                      painter: _CloseGlyph(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseGlyph extends CustomPainter {
  const _CloseGlyph();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = PosHomeSpec.ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const double inset = 2;
    canvas.drawLine(const Offset(inset, inset),
        Offset(size.width - inset, size.height - inset), p);
    canvas.drawLine(Offset(size.width - inset, inset),
        Offset(inset, size.height - inset), p);
  }

  @override
  bool shouldRepaint(_CloseGlyph oldDelegate) => false;
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: loewBold.copyWith(
        fontSize: PosTipSpec.sectionLabelSize,
        letterSpacing: PosTipSpec.sectionLabelTracking,
        color: PosTipSpec.muted,
      ),
    );
  }
}

/// A preset: the percentage over what it comes to. Ink when chosen; white
/// with an inside hairline otherwise.
class _PresetTile extends StatelessWidget {
  final String label;
  final String amount;
  final bool active;
  final VoidCallback onTap;

  const _PresetTile({
    required this.label,
    required this.amount,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(PosTipSpec.presetRadius);
    return Semantics(
      button: true,
      selected: active,
      label: '$label, $amount',
      excludeSemantics: true,
      child: Material(
        color: active ? PosTipSpec.presetActiveFill : PosHomeSpec.tileBg,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            height: PosTipSpec.presetHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            foregroundDecoration: active
                ? null
                : BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: PosTipSpec.presetIdleBorder,
                      width: PosTipSpec.presetIdleBorderWidth,
                    ),
                  ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: loewBold.copyWith(
                    fontSize: PosTipSpec.presetLabelSize,
                    color: active ? Colors.white : PosHomeSpec.ink,
                  ),
                ),
                const SizedBox(height: PosTipSpec.presetLineGap),
                Text(
                  amount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: swiss721Light.copyWith(
                    fontSize: PosTipSpec.presetAmountSize,
                    color: active
                        ? PosTipSpec.presetActiveAmount
                        : PosTipSpec.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The % / € switch (discount node 1915:14431).
class _UnitSwitch extends StatelessWidget {
  final bool percent;
  final ValueChanged<bool> onChanged;

  const _UnitSwitch({required this.percent, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget segment(String text, bool on, bool value) => Semantics(
          button: true,
          selected: on,
          label: value ? 'Percentage' : 'Amount',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: PosTipSpec.unitSegmentPadding,
              decoration: BoxDecoration(
                color: on ? PosHomeSpec.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                text,
                style: loewBold.copyWith(
                  fontSize: PosTipSpec.unitLabelSize,
                  color: on ? Colors.white : PosTipSpec.muted,
                ),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(PosTipSpec.unitSwitchPadding),
      decoration: BoxDecoration(
        color: PosHomeSpec.tileBg,
        borderRadius: BorderRadius.circular(999),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PosTipSpec.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          segment('€', !percent, false),
          segment('%', percent, true),
        ],
      ),
    );
  }
}

/// The custom value (discount node 1915:14436): ink stroke while it drives
/// the tip, a hairline while a preset does, the error colour when invalid.
class _InputBox extends StatelessWidget {
  final String text;
  final String placeholder;
  final String suffix;
  final bool active;
  final bool invalid;

  const _InputBox({
    required this.text,
    required this.placeholder,
    required this.suffix,
    required this.active,
    required this.invalid,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(PosTipSpec.inputRadius);
    final bool empty = text.isEmpty;
    return Container(
      key: const Key('pos-tip-input'),
      height: PosTipSpec.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: PosTipSpec.inputPaddingH),
      decoration: BoxDecoration(color: PosHomeSpec.tileBg, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: invalid
              ? PosTipSpec.errorInk
              : active
                  ? PosHomeSpec.ink
                  : PosTipSpec.hairline,
          width: PosTipSpec.inputBorderWidth,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                empty ? placeholder : text,
                maxLines: 1,
                style: loewBold.copyWith(
                  fontSize: PosTipSpec.inputValueSize,
                  color: empty ? PosTipSpec.inputPlaceholder : PosHomeSpec.ink,
                ),
              ),
            ),
          ),
          Text(
            suffix,
            style: loewBold.copyWith(
              fontSize: PosTipSpec.inputSuffixSize,
              color: PosTipSpec.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(PosTipSpec.cardRadius);
    return Container(
      padding: const EdgeInsets.all(PosTipSpec.cardPadding),
      decoration: BoxDecoration(color: PosHomeSpec.tileBg, borderRadius: radius),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: PosTipSpec.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: PosTipSpec.cardGap),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool total;

  const _PreviewRow({
    required this.label,
    required this.value,
    this.color = PosHomeSpec.ink,
    this.total = false,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle style = (total ? loewExtraBold : loewBold).copyWith(
      fontSize: PosTipSpec.previewRowSize,
      color: color,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

/// The sticky bar (discount node 1915:14477).
class _ApplyBar extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ApplyBar({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(PosTipSpec.buttonRadius);
    return Container(
      padding: PosTipSpec.barPadding,
      decoration: const BoxDecoration(
        color: PosTipSpec.barFill,
        border: Border(
          top: BorderSide(color: PosHomeSpec.ink, width: PosTipSpec.barTopBorder),
        ),
        boxShadow: [PosTipSpec.barShadow],
      ),
      child: Opacity(
        opacity: onTap == null ? PosTipSpec.buttonDisabledOpacity : 1,
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: PosHomeSpec.ink,
            borderRadius: radius,
            child: InkWell(
              key: const Key('pos-tip-apply'),
              onTap: onTap,
              borderRadius: radius,
              child: SizedBox(
                height: PosTipSpec.buttonHeight,
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                      fontSize: PosTipSpec.buttonLabelSize,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
