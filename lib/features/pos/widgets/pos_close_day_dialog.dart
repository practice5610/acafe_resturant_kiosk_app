import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/domain/pos_close_day_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_data.dart';
import 'package:acafe_customer/features/pos/widgets/pos_close_day_step2.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_report_date_header.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Final outcome of the Close Day flow (Steps 1 + 2).
@immutable
class PosCloseDayResult {
  final PosCloseDayStep2Action action;
  final int countedCents;
  final double expectedAmount;
  final double openingFloat;
  final String? differenceReason;
  final bool printZReport;
  final bool emailReport;

  /// The denomination rows the operator actually filled in, or null when they
  /// typed a total instead. Null rather than a list of zeros: "counted by
  /// denomination and found nothing" and "did not use the table" are different
  /// claims, and only one of them is true here.
  final List<Map<String, dynamic>>? denominationBreakdown;

  const PosCloseDayResult({
    required this.action,
    required this.countedCents,
    required this.expectedAmount,
    required this.openingFloat,
    this.differenceReason,
    this.printZReport = false,
    this.emailReport = false,
    this.denominationBreakdown,
  });

  double get countedAmount => posCentsToMoney(countedCents);
}

/// Close Day modal — Step 1 Count Cash Drawer (Figma **1641:6042**) then
/// Step 2 Review & Confirm (Figma **1641:6707**), in one overlay.
class PosCloseDayDialog extends StatefulWidget {
  final DateTime date;
  final PosReportData data;
  final Future<String?> Function(String pin) verifyManagerPin;

  const PosCloseDayDialog({
    super.key,
    required this.date,
    required this.data,
    required this.verifyManagerPin,
  });

  /// Runs both steps. Returns null on cancel / dismiss.
  static Future<PosCloseDayResult?> show(
    BuildContext context, {
    required DateTime date,
    required PosReportData data,
    required Future<String?> Function(String pin) verifyManagerPin,
  }) {
    return showDialog<PosCloseDayResult>(
      context: context,
      barrierDismissible: true,
      barrierColor: PosCloseDaySpec.backdrop,
      useRootNavigator: false,
      builder: (_) => PosCloseDayDialog(
        date: date,
        data: data,
        verifyManagerPin: verifyManagerPin,
      ),
    );
  }

  @override
  State<PosCloseDayDialog> createState() => _PosCloseDayDialogState();
}

class _PosCloseDayDialogState extends State<PosCloseDayDialog> {
  int _step = 1;
  PosCashEntry _entry = const PosCashEntry();
  bool _denomExpanded = false;
  late List<int> _qty;

  @override
  void initState() {
    super.initState();
    _qty = List<int>.filled(PosCloseDaySpec.denominationCents.length, 0);
  }

  double get _expected => widget.data.expectedInDrawer;
  double get _openingFloat => widget.data.openingFloat;
  bool get _canContinue => !_entry.isEmpty;

  void _onKey(String token) {
    setState(() {
      _entry = _entry.key(token);
      _qty = List<int>.filled(PosCloseDaySpec.denominationCents.length, 0);
    });
  }

  void _onBackspace() {
    setState(() => _entry = _entry.backspace());
  }

  void _setDenomQty(int index, int value) {
    setState(() {
      _qty[index] = value < 0 ? 0 : value;
      int total = 0;
      for (int i = 0; i < _qty.length; i++) {
        total += _qty[i] * PosCloseDaySpec.denominationCents[i];
      }
      _entry = total == 0 ? const PosCashEntry() : _entry.withCents(total);
    });
  }

  /// The filled-in denomination rows, or null when the table wasn't used.
  ///
  /// Zero-quantity rows are dropped: they are the table's resting state, not
  /// evidence that anybody counted that denomination.
  List<Map<String, dynamic>>? _denominationRows() {
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    for (int i = 0; i < _qty.length; i++) {
      if (_qty[i] <= 0) continue;
      final int cents = PosCloseDaySpec.denominationCents[i];
      rows.add(<String, dynamic>{
        'value': posCentsToMoney(cents),
        'quantity': _qty[i],
        'subtotal': posCentsToMoney(cents * _qty[i]),
      });
    }
    return rows.isEmpty ? null : rows;
  }

  void _goToStep2() {
    if (!_canContinue) return;
    setState(() {
      _step = 2;
      _denomExpanded = false;
    });
  }

  void _onStep2(PosCloseDayStep2Result result) {
    switch (result.action) {
      case PosCloseDayStep2Action.recount:
        setState(() => _step = 1);
        return;
      case PosCloseDayStep2Action.cancel:
        Navigator.of(context).pop();
        return;
      case PosCloseDayStep2Action.backToOrders:
      case PosCloseDayStep2Action.confirm:
        Navigator.of(context).pop(
          PosCloseDayResult(
            action: result.action,
            countedCents: _entry.cents,
            expectedAmount: _expected,
            openingFloat: _openingFloat,
            differenceReason: result.differenceReason,
            printZReport: result.printZReport,
            emailReport: result.emailReport,
            denominationBreakdown: _denominationRows(),
          ),
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size window = MediaQuery.sizeOf(context);
    final double maxWidth = window.width - PosCloseDaySpec.screenInset * 2;

    return Material(
      color: Colors.transparent,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(PosCloseDaySpec.screenInset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth < PosCloseDaySpec.cardWidth
                  ? maxWidth
                  : PosCloseDaySpec.cardWidth,
            ),
            child: Container(
              padding: const EdgeInsets.all(PosCloseDaySpec.cardPadding),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(PosCloseDaySpec.cardRadius),
                border: Border.all(
                  color: PosCloseDaySpec.cardBorderColor,
                  width: PosCloseDaySpec.cardBorder,
                ),
                boxShadow: PosCloseDaySpec.cardShadow,
              ),
              child: _step == 1 ? _buildStep1() : _buildStep2(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return PosCloseDayStep2Panel(
      date: widget.date,
      data: widget.data,
      countedCents: _entry.cents,
      expectedAmount: _expected,
      onResult: _onStep2,
      verifyManagerPin: widget.verifyManagerPin,
    );
  }

  Widget _buildStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(
          date: widget.date,
          onClose: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: PosCloseDaySpec.sectionGap),
        const _Hairline(),
        const SizedBox(height: PosCloseDaySpec.sectionGap),
        Text(
          'Count Cash Drawer',
          style: loewExtraBold.copyWith(
            fontSize: PosCloseDaySpec.sectionTitleSize,
            color: PosCloseDaySpec.ink,
          ),
        ),
        const SizedBox(height: PosCloseDaySpec.sectionGap),
        _ExpectedBox(amount: _expected),
        const SizedBox(height: PosCloseDaySpec.sectionGap),
        _ActualAmountBlock(
          entry: _entry,
          showKeypad: !_denomExpanded,
          onKey: _onKey,
          onBackspace: _onBackspace,
        ),
        const SizedBox(height: PosCloseDaySpec.sectionGap),
        _DenominationToggle(
          expanded: _denomExpanded,
          onTap: () => setState(() => _denomExpanded = !_denomExpanded),
        ),
        if (_denomExpanded) ...<Widget>[
          const SizedBox(height: PosCloseDaySpec.sectionGap),
          _DenominationTable(qty: _qty, onDenomQty: _setDenomQty),
        ],
        const SizedBox(height: PosCloseDaySpec.sectionGap),
        const _Hairline(),
        const SizedBox(height: PosCloseDaySpec.sectionGap),
        _Footer(
          canContinue: _canContinue,
          onCancel: () => Navigator.of(context).pop(),
          onContinue: _goToStep2,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final DateTime date;
  final VoidCallback onClose;

  const _Header({required this.date, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final String dateLabel = PosReportDateHeader.formatLong(date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: <InlineSpan>[
                    TextSpan(
                      text: 'Close Day  ',
                      style: loewExtraBold.copyWith(
                        fontSize: PosCloseDaySpec.titleSize,
                        color: PosCloseDaySpec.ink,
                      ),
                    ),
                    TextSpan(
                      text: dateLabel,
                      style: loewRegular.copyWith(
                        fontSize: PosCloseDaySpec.titleSize,
                        color: PosCloseDaySpec.ink,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Close',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: SizedBox(
                  width: PosCloseDaySpec.closeIconSize,
                  height: PosCloseDaySpec.closeIconSize,
                  child: SvgPicture.asset(
                    Images.posXCircleSvg,
                    width: PosCloseDaySpec.closeIconSize,
                    height: PosCloseDaySpec.closeIconSize,
                    fit: BoxFit.contain,
                    placeholderBuilder: (_) => const Icon(
                      Icons.cancel_outlined,
                      size: PosCloseDaySpec.closeIconSize,
                      color: PosCloseDaySpec.ink,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: PosCloseDaySpec.headerGap),
        Text(
          'Step 1 of 2  Count Cash Drawer',
          style: loewBold.copyWith(
            fontSize: PosCloseDaySpec.stepSize,
            color: PosCloseDaySpec.stepColor,
          ),
        ),
      ],
    );
  }
}

class _ExpectedBox extends StatelessWidget {
  final double amount;

  const _ExpectedBox({required this.amount});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(PosCloseDaySpec.expectedPadding),
      decoration: BoxDecoration(
        color: PosCloseDaySpec.pageBg,
        borderRadius: BorderRadius.circular(PosCloseDaySpec.expectedRadius),
        border: Border.all(color: PosCloseDaySpec.expectedBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Expected in drawer',
                  style: loewBold.copyWith(
                    fontSize: PosCloseDaySpec.expectedLabelSize,
                    color: PosHomeSpec.inkAlpha(0.6),
                  ),
                ),
              ),
              Text(
                PosHomeSpec.formatPrice(amount, padZero: false),
                style: loewRegular.copyWith(
                  fontSize: PosCloseDaySpec.expectedAmountSize,
                  color: PosCloseDaySpec.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: PosCloseDaySpec.expectedGap),
          Text(
            'Opening float + cash sales − cash refunds',
            style: loewRegular.copyWith(
              fontSize: PosCloseDaySpec.expectedHintSize,
              color: PosCloseDaySpec.expectedHintColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActualAmountBlock extends StatelessWidget {
  final PosCashEntry entry;
  final bool showKeypad;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;

  const _ActualAmountBlock({
    required this.entry,
    required this.showKeypad,
    required this.onKey,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'ACTUAL COUNTED AMOUNT',
          style: loewBold.copyWith(
            fontSize: PosCloseDaySpec.inputLabelSize,
            color: PosHomeSpec.inkAlpha(0.6),
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: PosCloseDaySpec.inputGroupGap),
        _AmountField(entry: entry),
        if (showKeypad) ...<Widget>[
          const SizedBox(height: PosCloseDaySpec.inputGroupGap),
          PosKeypad(
            rows: PosKeypad.digitRows(decimal: ','),
            style: posCashKeypadStyle(
              backspaceAsset: Images.posKeyBackspaceSvg,
            ),
            onKey: onKey,
            onBackspace: onBackspace,
          ),
        ],
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  final PosCashEntry entry;

  const _AmountField({required this.entry});

  @override
  Widget build(BuildContext context) {
    final bool empty = entry.isEmpty;
    return Container(
      width: double.infinity,
      padding: PosCloseDaySpec.inputPadding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(PosCloseDaySpec.inputRadius),
        border: Border.all(
          color: PosCloseDaySpec.inputBorderColor,
          width: PosCloseDaySpec.inputBorder,
        ),
      ),
      child: Text(
        empty
            ? 'Enter counted amount'
            : PosHomeSpec.formatPrice(
                posCentsToMoney(entry.cents, decimals: entry.decimals),
                padZero: false,
              ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: loewRegular.copyWith(
          fontSize: PosCloseDaySpec.inputTextSize,
          color:
              empty ? PosCloseDaySpec.inputPlaceholder : PosCloseDaySpec.ink,
        ),
      ),
    );
  }
}

class _DenominationToggle extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;

  const _DenominationToggle({required this.expanded, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Transform.rotate(
            angle: expanded ? 3.1415926535 : 0,
            child: SizedBox(
              width: PosCloseDaySpec.denomChevronW,
              height: PosCloseDaySpec.denomChevronH,
              child: SvgPicture.asset(
                Images.posCloseDayChevronSvg,
                width: PosCloseDaySpec.denomChevronW,
                height: PosCloseDaySpec.denomChevronH,
                fit: BoxFit.contain,
                placeholderBuilder: (_) => const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: PosCloseDaySpec.denomChevronW,
                  color: PosCloseDaySpec.ink,
                ),
              ),
            ),
          ),
          const SizedBox(width: PosCloseDaySpec.denomGap),
          Text(
            'Count by denomination',
            style: loewBold.copyWith(
              fontSize: PosCloseDaySpec.denomLabelSize,
              color: PosCloseDaySpec.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Expanded denomination rows from sibling Figma **1641:6101**.
class _DenominationTable extends StatelessWidget {
  final List<int> qty;
  final void Function(int index, int value) onDenomQty;

  const _DenominationTable({required this.qty, required this.onDenomQty});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'VALUE',
                style: loewBold.copyWith(
                  fontSize: PosCloseDaySpec.denomHeaderSize,
                  color: PosHomeSpec.inkAlpha(0.6),
                ),
              ),
            ),
            SizedBox(
              width: PosCloseDaySpec.denomQtyWidth,
              child: Text(
                'QUANTITY',
                textAlign: TextAlign.center,
                style: loewBold.copyWith(
                  fontSize: PosCloseDaySpec.denomHeaderSize,
                  color: PosHomeSpec.inkAlpha(0.6),
                ),
              ),
            ),
            SizedBox(
              width: PosCloseDaySpec.denomSubtotalWidth,
              child: Text(
                'SUBTOTAL',
                textAlign: TextAlign.right,
                style: loewBold.copyWith(
                  fontSize: PosCloseDaySpec.denomHeaderSize,
                  color: PosHomeSpec.inkAlpha(0.6),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (int i = 0; i < PosCloseDaySpec.denominationCents.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(height: PosCloseDaySpec.denomRowGap),
          _DenomRow(
            cents: PosCloseDaySpec.denominationCents[i],
            quantity: qty[i],
            onChanged: (int v) => onDenomQty(i, v),
          ),
        ],
      ],
    );
  }
}

class _DenomRow extends StatefulWidget {
  final int cents;
  final int quantity;
  final ValueChanged<int> onChanged;

  const _DenomRow({
    required this.cents,
    required this.quantity,
    required this.onChanged,
  });

  @override
  State<_DenomRow> createState() => _DenomRowState();
}

class _DenomRowState extends State<_DenomRow> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.quantity}');
    _focus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _DenomRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.quantity != widget.quantity && !_focus.hasFocus) {
      _controller.text = '${widget.quantity}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int subtotal = widget.cents * widget.quantity;
    return SizedBox(
      height: PosCloseDaySpec.denomRowHeight,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              PosHomeSpec.formatPrice(
                posCentsToMoney(widget.cents),
                padZero: false,
              ),
              style: loewBold.copyWith(
                fontSize: PosCloseDaySpec.denomValueSize,
                color: PosCloseDaySpec.ink,
              ),
            ),
          ),
          SizedBox(
            width: PosCloseDaySpec.denomQtyWidth,
            height: PosCloseDaySpec.denomQtyHeight,
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              textAlign: TextAlign.center,
              style: loewBold.copyWith(
                fontSize: PosCloseDaySpec.denomQtySize,
                color: PosCloseDaySpec.ink,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(PosCloseDaySpec.denomQtyRadius),
                  borderSide: const BorderSide(
                    color: PosCloseDaySpec.inputBorderColor,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(PosCloseDaySpec.denomQtyRadius),
                  borderSide: const BorderSide(
                    color: PosCloseDaySpec.inputBorderColor,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(PosCloseDaySpec.denomQtyRadius),
                  borderSide: const BorderSide(
                    color: PosCloseDaySpec.ink,
                    width: 1,
                  ),
                ),
              ),
              onChanged: (String raw) {
                if (raw.isEmpty) {
                  widget.onChanged(0);
                  return;
                }
                final int? parsed = int.tryParse(raw);
                if (parsed != null) widget.onChanged(parsed);
              },
            ),
          ),
          SizedBox(
            width: PosCloseDaySpec.denomSubtotalWidth,
            child: Text(
              PosHomeSpec.formatPrice(
                posCentsToMoney(subtotal),
                padZero: false,
              ),
              textAlign: TextAlign.right,
              style: loewExtraBold.copyWith(
                fontSize: PosCloseDaySpec.denomValueSize,
                color: PosCloseDaySpec.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool canContinue;
  final VoidCallback onCancel;
  final VoidCallback onContinue;

  const _Footer({
    required this.canContinue,
    required this.onCancel,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _ActionButton(
            label: 'Cancel',
            filled: false,
            onTap: onCancel,
          ),
        ),
        const SizedBox(width: PosCloseDaySpec.footerGap),
        Expanded(
          child: Opacity(
            opacity: canContinue ? 1 : PosCloseDaySpec.continueDisabledOpacity,
            child: _ActionButton(
              label: 'Continue',
              filled: true,
              onTap: canContinue ? onContinue : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosCloseDaySpec.buttonRadius);

    return Material(
      color: filled ? PosCloseDaySpec.ink : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          padding: PosCloseDaySpec.buttonPadding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: filled
                ? null
                : Border.all(
                    color: PosCloseDaySpec.cardBorderColor,
                    width: PosCloseDaySpec.buttonBorder,
                  ),
          ),
          child: Text(
            label,
            style: loewExtraBold.copyWith(
              fontSize: PosCloseDaySpec.buttonTextSize,
              color: filled ? PosCloseDaySpec.pageBg : PosCloseDaySpec.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      width: double.infinity,
      color: PosCloseDaySpec.cardBorderColor,
    );
  }
}
