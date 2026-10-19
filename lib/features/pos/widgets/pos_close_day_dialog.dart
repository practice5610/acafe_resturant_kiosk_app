import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/domain/pos_close_day_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_data.dart';
import 'package:acafe_customer/features/pos/widgets/pos_close_day_step2.dart';
import 'package:acafe_customer/features/pos/widgets/pos_keypad.dart';
import 'package:acafe_customer/features/pos/widgets/pos_pay_shell.dart';
import 'package:acafe_customer/features/pos/widgets/pos_report_widgets.dart';
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

/// Close Day modal — Step 1 Count Cash Drawer (Figma **1915:18618**, table
/// open **1915:18940**) then Step 2 Review & Confirm (Figma **1915:19286** /
/// **1915:19604**), in one overlay.
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
    final double maxHeight = window.height - PosCloseDaySpec.screenInset * 2;

    // Figma draws the open denomination table on a 580 card; the width eases
    // there and back instead of jumping when the table is toggled.
    final double designWidth = _step == 1 && _denomExpanded
        ? PosCloseDaySpec.cardWidthDenomination
        : PosCloseDaySpec.cardWidth;

    // Width-constrained and centred so the area around the card stays
    // transparent and a tap out there falls through to the dismiss barrier.
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(PosCloseDaySpec.screenInset),
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(end: designWidth),
          duration: PosCloseDaySpec.cardResizeDuration,
          curve: Curves.easeOut,
          builder: (BuildContext context, double width, Widget? card) =>
              ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth < width ? maxWidth : width,
              maxHeight: maxHeight,
            ),
            child: card,
          ),
          child: Material(
            color: Colors.transparent,
            // Inside the Material, which re-applies the theme's 1.43 body line
            // height: the scope hands every Loew style Figma's
            // `leading-normal` instead.
            child: PosPayTextScope(
              child: SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(PosCloseDaySpec.cardPadding),
                  decoration: BoxDecoration(
                    color: PosCloseDaySpec.surface,
                    borderRadius:
                        BorderRadius.circular(PosCloseDaySpec.cardRadius),
                    boxShadow: PosCloseDaySpec.cardShadow,
                  ),
                  // Inside stroke: the 32 padding is measured from the card
                  // edge, so content keeps its 496 width.
                  foregroundDecoration: BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(PosCloseDaySpec.cardRadius),
                    border: Border.all(
                      color: PosCloseDaySpec.cardBorderColor,
                      width: PosCloseDaySpec.cardBorder,
                    ),
                  ),
                  child: _step == 1 ? _buildStep1() : _buildStep2(),
                ),
              ),
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
    // Figma draws the open-table state on a tighter 20px rhythm.
    final SizedBox gap = SizedBox(
      height: _denomExpanded
          ? PosCloseDaySpec.denomSectionGap
          : PosCloseDaySpec.sectionGap,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Header(
          date: widget.date,
          onClose: () => Navigator.of(context).pop(),
        ),
        gap,
        const PosReportDivider(color: PosCloseDaySpec.dividerColor),
        gap,
        Text(
          'Count Cash Drawer',
          style: PosCloseDaySpec.text(
              loewExtraBold, PosCloseDaySpec.sectionTitleSize,
              color: PosCloseDaySpec.ink),
        ),
        gap,
        _ExpectedBox(amount: _expected, compact: _denomExpanded),
        gap,
        _ActualAmountBlock(
          entry: _entry,
          showKeypad: !_denomExpanded,
          onKey: _onKey,
          onBackspace: _onBackspace,
        ),
        gap,
        _DenominationToggle(
          expanded: _denomExpanded,
          onTap: () => setState(() => _denomExpanded = !_denomExpanded),
        ),
        if (_denomExpanded) ...<Widget>[
          gap,
          _DenominationTable(qty: _qty, onDenomQty: _setDenomQty),
        ],
        gap,
        const PosReportDivider(color: PosCloseDaySpec.dividerColor),
        gap,
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
              child: Text(
                'Close Day  $dateLabel',
                style: PosCloseDaySpec.text(
                    loewExtraBold, PosCloseDaySpec.titleSize,
                    color: PosCloseDaySpec.ink),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: PosCloseDaySpec.closeIconGap),
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
          style: PosCloseDaySpec.text(loewBold, PosCloseDaySpec.stepSize,
              color: PosCloseDaySpec.stepColor),
        ),
      ],
    );
  }
}

class _ExpectedBox extends StatelessWidget {
  final double amount;

  /// The one-row variant drawn while the denomination table is open.
  final bool compact;

  const _ExpectedBox({required this.amount, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosCloseDaySpec.expectedRadius);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        compact
            ? PosCloseDaySpec.expectedCompactPadding
            : PosCloseDaySpec.expectedPadding,
      ),
      decoration: BoxDecoration(
        color: PosCloseDaySpec.pageBg,
        borderRadius: radius,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: PosCloseDaySpec.expectedBorder,
          width: PosCloseDaySpec.hairlineWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Expected in drawer',
                  style: PosCloseDaySpec.text(
                      loewBold,
                      compact
                          ? PosCloseDaySpec.expectedCompactLabelSize
                          : PosCloseDaySpec.expectedLabelSize,
                      color: PosCloseDaySpec.inkMuted),
                ),
              ),
              Text(
                PosHomeSpec.formatPrice(amount, padZero: false),
                style: PosCloseDaySpec.text(
                    loewRegular,
                    compact
                        ? PosCloseDaySpec.expectedCompactAmountSize
                        : PosCloseDaySpec.expectedAmountSize,
                    color: PosCloseDaySpec.ink),
              ),
            ],
          ),
          if (!compact) ...<Widget>[
            const SizedBox(height: PosCloseDaySpec.expectedGap),
            Text(
              'Opening float + cash sales − cash refunds',
              style: PosCloseDaySpec.text(
                  loewRegular, PosCloseDaySpec.expectedHintSize,
                  color: PosCloseDaySpec.expectedHintColor),
            ),
          ],
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
          style: PosCloseDaySpec.text(loewBold, PosCloseDaySpec.inputLabelSize,
              color: PosCloseDaySpec.inkMuted),
        ),
        const SizedBox(height: PosCloseDaySpec.inputGroupGap),
        // With the keypad folded away the table drives the figure, and the
        // field turns into a filled read-out (Figma 1915:18955).
        _AmountField(entry: entry, filled: !showKeypad),
        if (showKeypad) ...<Widget>[
          const SizedBox(height: PosCloseDaySpec.inputGroupGap),
          PosKeypad(
            rows: PosKeypad.digitRows(decimal: ','),
            style: posCompactKeypadStyle(
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
  final bool filled;

  const _AmountField({required this.entry, this.filled = false});

  /// Formatted like every other price, except that once the decimal key has
  /// been pressed the fraction shows exactly what was typed: `62.`, `62.5`,
  /// `62.50`. Always rendering the rounded `62.00` made the `,` key look dead.
  static String _display(PosCashEntry entry) {
    final String formatted = PosHomeSpec.formatPrice(
      posCentsToMoney(entry.cents, decimals: entry.decimals),
      padZero: false,
    );
    final int mark = entry.raw.indexOf(PosCashEntry.decimalMark);
    if (mark < 0) return formatted;
    final String typedFraction = entry.raw.substring(mark + 1);
    return formatted.replaceFirstMapped(
      RegExp(r'\.\d+'),
      (_) => '.$typedFraction',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool empty = entry.isEmpty;
    final BorderRadius radius =
        BorderRadius.circular(PosCloseDaySpec.inputRadius);

    return Container(
      width: double.infinity,
      padding: filled
          ? PosCloseDaySpec.inputFilledPadding
          : PosCloseDaySpec.inputPadding,
      decoration: BoxDecoration(
        color: filled ? PosCloseDaySpec.pageBg : PosCloseDaySpec.surface,
        borderRadius: radius,
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: PosCloseDaySpec.inputBorderColor,
          width: PosCloseDaySpec.inputBorder,
        ),
      ),
      child: Text(
        empty ? 'Enter counted amount' : _display(entry),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: PosCloseDaySpec.text(
            (filled && !empty ? loewExtraBold : loewRegular),
            PosCloseDaySpec.inputTextSize,
            color:
                empty ? PosCloseDaySpec.inputPlaceholder : PosCloseDaySpec.ink),
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
            style: PosCloseDaySpec.text(
                loewBold, PosCloseDaySpec.denomLabelSize,
                color: PosCloseDaySpec.ink),
          ),
        ],
      ),
    );
  }
}

/// Expanded denomination rows — Figma **1915:18961**.
///
/// Columns are spaced, not packed: like Figma's `justify-between`, the
/// quantity box sits mid-row between the value and the right-aligned subtotal.
class _DenominationTable extends StatelessWidget {
  final List<int> qty;
  final void Function(int index, int value) onDenomQty;

  const _DenominationTable({required this.qty, required this.onDenomQty});

  @override
  Widget build(BuildContext context) {
    final TextStyle header = PosCloseDaySpec.text(
        loewBold, PosCloseDaySpec.denomHeaderSize,
        color: PosCloseDaySpec.denomHeaderColor);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(bottom: PosCloseDaySpec.denomHeaderGap),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('VALUE', style: header),
              SizedBox(
                width: PosCloseDaySpec.denomQtyWidth,
                child: Text(
                  'QUANTITY',
                  textAlign: TextAlign.center,
                  style: header,
                ),
              ),
              SizedBox(
                width: PosCloseDaySpec.denomSubtotalWidth,
                child: Text(
                  'SUBTOTAL',
                  textAlign: TextAlign.right,
                  style: header,
                ),
              ),
            ],
          ),
        ),
        for (int i = 0; i < PosCloseDaySpec.denominationCents.length; i++) ...<Widget>[
          const SizedBox(height: PosCloseDaySpec.denomRowGap),
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
    final Color countColor = widget.quantity == 0
        ? PosCloseDaySpec.denomZeroColor
        : PosCloseDaySpec.ink;

    return Container(
      height: PosCloseDaySpec.denomRowHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: PosCloseDaySpec.denomRowPadding,
      ),
      decoration: BoxDecoration(
        color: PosCloseDaySpec.pageBg,
        borderRadius: BorderRadius.circular(PosCloseDaySpec.denomRowRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            PosHomeSpec.formatPrice(
              posCentsToMoney(widget.cents),
              padZero: false,
            ),
            style: PosCloseDaySpec.text(
                loewBold, PosCloseDaySpec.denomValueSize,
                color: PosCloseDaySpec.ink),
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
              style: PosCloseDaySpec.text(
                  loewBold, PosCloseDaySpec.denomQtySize,
                  color: countColor),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: PosCloseDaySpec.surface,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: PosCloseDaySpec.denomQtyPaddingV,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(PosCloseDaySpec.denomQtyRadius),
                  gapPadding: PosCloseDaySpec.fieldGapPadding,
                  borderSide: const BorderSide(
                    color: PosCloseDaySpec.inputBorderColor,
                    width: PosCloseDaySpec.hairlineWidth,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(PosCloseDaySpec.denomQtyRadius),
                  gapPadding: PosCloseDaySpec.fieldGapPadding,
                  borderSide: const BorderSide(
                    color: PosCloseDaySpec.inputBorderColor,
                    width: PosCloseDaySpec.hairlineWidth,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(PosCloseDaySpec.denomQtyRadius),
                  gapPadding: PosCloseDaySpec.fieldGapPadding,
                  borderSide: const BorderSide(
                    color: PosCloseDaySpec.ink,
                    width: PosCloseDaySpec.hairlineWidth,
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
              style: PosCloseDaySpec.text(
                  loewExtraBold, PosCloseDaySpec.denomValueSize,
                  color: countColor),
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
          // Inside stroke: Cancel stays the 45 Continue is.
          foregroundDecoration: filled
              ? null
              : BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: PosCloseDaySpec.cardBorderColor,
                    width: PosCloseDaySpec.buttonBorder,
                  ),
                ),
          child: Text(
            label,
            style: PosCloseDaySpec.text(
                loewExtraBold, PosCloseDaySpec.buttonTextSize,
                color: filled ? PosCloseDaySpec.pageBg : PosCloseDaySpec.ink),
          ),
        ),
      ),
    );
  }
}
