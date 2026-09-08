import 'package:acafe_customer/features/pos/domain/pos_cash_entry.dart';
import 'package:acafe_customer/features/pos/domain/pos_close_day_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_data.dart';
import 'package:acafe_customer/features/pos/widgets/pos_report_date_header.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Outcome of Close Day Step 2 (Figma **1641:6707**).
enum PosCloseDayStep2Action {
  /// Confirm & Close Day — proceed with the counted cash.
  confirm,

  /// Recount — return to Step 1 with the same day.
  recount,

  /// Leave Close Day and open the Orders board.
  backToOrders,

  /// Dismiss without closing.
  cancel,
}

@immutable
class PosCloseDayStep2Result {
  final PosCloseDayStep2Action action;
  final bool printZReport;
  final bool emailReport;
  final String? differenceReason;

  const PosCloseDayStep2Result({
    required this.action,
    this.printZReport = false,
    this.emailReport = false,
    this.differenceReason,
  });
}

/// Step 2 body — Review & Confirm. Figma **1641:6707**.
class PosCloseDayStep2Panel extends StatefulWidget {
  final DateTime date;
  final PosReportData data;
  final int countedCents;
  final double expectedAmount;
  final ValueChanged<PosCloseDayStep2Result> onResult;

  /// Checks the manager PIN server-side. Returns null when it is accepted,
  /// otherwise the message to show under the field.
  ///
  /// Injected rather than reached for through a provider so this panel stays
  /// testable without a live device token — same split the POS PIN card uses.
  final Future<String?> Function(String pin) verifyManagerPin;

  const PosCloseDayStep2Panel({
    super.key,
    required this.date,
    required this.data,
    required this.countedCents,
    required this.expectedAmount,
    required this.onResult,
    required this.verifyManagerPin,
  });

  @override
  State<PosCloseDayStep2Panel> createState() => _PosCloseDayStep2PanelState();
}

class _PosCloseDayStep2PanelState extends State<PosCloseDayStep2Panel> {
  bool _acceptedDifference = false;
  bool _closeAnyway = false;
  bool _printZReport = false;
  bool _emailReport = false;
  bool _verifyingPin = false;
  String? _pinError;
  final TextEditingController _reason = TextEditingController();
  final TextEditingController _pin = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The reason is part of the confirm gate below, so the footer has to
    // re-evaluate as it is typed rather than only when some other control
    // moves.
    _reason.addListener(_onReasonChanged);
  }

  void _onReasonChanged() => setState(() {});

  @override
  void dispose() {
    _reason.removeListener(_onReasonChanged);
    _reason.dispose();
    _pin.dispose();
    super.dispose();
  }

  double get _variance =>
      posCentsToMoney(widget.countedCents) - widget.expectedAmount;

  bool get _hasDiscrepancy => _variance.abs() >= 0.005;

  bool get _hasPending => widget.data.pendingPrepCount > 0;

  /// Accepting a difference has to say why. The note is the only record of
  /// what happened to the missing (or surplus) cash, and it is what
  /// `cash_drawer.discrepancy_note` persists — accepting silently would close
  /// the day with a variance and no explanation attached to it.
  bool get _reasonGiven => _reason.text.trim().isNotEmpty;

  bool get _cashResolved =>
      !_hasDiscrepancy || (_acceptedDifference && _reasonGiven);

  bool get _ordersResolved => !_hasPending || _closeAnyway;

  bool get _canConfirm => _cashResolved && _ordersResolved && !_verifyingPin;

  String get _footerHint {
    if (_canConfirm) return '';
    if (_verifyingPin) return '';
    if (!_cashResolved && !_ordersResolved) {
      return 'Resolve the cash difference and open orders first';
    }
    if (!_cashResolved) {
      return _acceptedDifference
          ? 'Add a reason for the cash difference first'
          : 'Resolve the cash difference first';
    }
    return 'Resolve open orders first';
  }

  /// Verifies the manager PIN before emitting a confirm, when one was typed.
  ///
  /// The field is optional because nothing in this system makes it mandatory —
  /// there is no "require a PIN to close" setting anywhere. But an entered PIN
  /// is really checked against the device's configuration_code server-side: a
  /// field that accepted anything would be worse than no field at all.
  Future<void> _confirm() async {
    final String pin = _pin.text.trim();

    if (pin.isNotEmpty) {
      setState(() {
        _verifyingPin = true;
        _pinError = null;
      });

      final String? error = await widget.verifyManagerPin(pin);
      if (!mounted) return;

      setState(() {
        _verifyingPin = false;
        _pinError = error;
      });

      if (error != null) return;
    }

    _emit(PosCloseDayStep2Action.confirm);
  }

  void _emit(PosCloseDayStep2Action action) {
    widget.onResult(
      PosCloseDayStep2Result(
        action: action,
        printZReport: _printZReport,
        emailReport: _emailReport,
        differenceReason:
            _acceptedDifference && _reason.text.trim().isNotEmpty
                ? _reason.text.trim()
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String dateLabel = PosReportDateHeader.formatLong(widget.date);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _Step2Header(
          dateLabel: dateLabel,
          onClose: () => _emit(PosCloseDayStep2Action.cancel),
        ),
        const SizedBox(height: PosCloseDaySpec.step2Gap),
        _DaySummary(data: widget.data),
        if (_hasDiscrepancy) ...<Widget>[
          const SizedBox(height: PosCloseDaySpec.step2Gap),
          _DiscrepancySection(
            variance: _variance,
            accepted: _acceptedDifference,
            reasonController: _reason,
            onRecount: () => _emit(PosCloseDayStep2Action.recount),
            onAccept: () => setState(() => _acceptedDifference = true),
          ),
        ],
        if (_hasPending) ...<Widget>[
          const SizedBox(height: PosCloseDaySpec.step2Gap),
          _PendingOrdersSection(
            count: widget.data.pendingPrepCount,
            closeAnyway: _closeAnyway,
            onBackToOrders: () => _emit(PosCloseDayStep2Action.backToOrders),
            onCloseAnyway: () => setState(() => _closeAnyway = true),
          ),
        ],
        const SizedBox(height: PosCloseDaySpec.step2Gap),
        _ActionsList(
          printZReport: _printZReport,
          emailReport: _emailReport,
          pinController: _pin,
          pinError: _pinError,
          onPrintChanged: (bool v) => setState(() => _printZReport = v),
          onEmailChanged: (bool v) => setState(() => _emailReport = v),
        ),
        const SizedBox(height: PosCloseDaySpec.step2Gap),
        Container(
          height: 1,
          color: PosCloseDaySpec.cardBorderColor,
        ),
        const SizedBox(height: PosCloseDaySpec.step2Gap),
        _Step2Footer(
          canConfirm: _canConfirm,
          hint: _footerHint,
          onCancel: () => _emit(PosCloseDayStep2Action.cancel),
          onConfirm: _confirm,
        ),
      ],
    );
  }
}

class _Step2Header extends StatelessWidget {
  final String dateLabel;
  final VoidCallback onClose;

  const _Step2Header({required this.dateLabel, required this.onClose});

  @override
  Widget build(BuildContext context) {
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
            GestureDetector(
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
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: PosCloseDaySpec.headerGap),
        Text(
          'Step 2 of 2  Review & Confirm',
          style: loewBold.copyWith(
            fontSize: PosCloseDaySpec.stepSize,
            color: PosCloseDaySpec.stepColor,
          ),
        ),
      ],
    );
  }
}

class _DaySummary extends StatelessWidget {
  final PosReportData data;

  const _DaySummary({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PosCloseDaySpec.summaryPadding),
      decoration: BoxDecoration(
        color: PosCloseDaySpec.pageBg,
        borderRadius: BorderRadius.circular(PosCloseDaySpec.summaryRadius),
        border: Border.all(color: PosCloseDaySpec.cardBorderColor),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatCol(
              label: "TODAY'S REVENUE",
              value: PosHomeSpec.formatPrice(data.totalRevenue, padZero: false),
            ),
          ),
          const SizedBox(width: PosCloseDaySpec.summaryColGap),
          Expanded(
            child: _StatCol(
              label: 'ORDERS',
              value:
                  '${data.orderCount} order${data.orderCount == 1 ? '' : 's'}',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String label;
  final String value;

  const _StatCol({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: loewBold.copyWith(
            fontSize: PosCloseDaySpec.summaryLabelSize,
            color: PosHomeSpec.inkAlpha(0.6),
          ),
        ),
        const SizedBox(height: PosCloseDaySpec.summaryInnerGap),
        Text(
          value,
          style: loewExtraBold.copyWith(
            fontSize: PosCloseDaySpec.summaryValueSize,
            color: PosCloseDaySpec.ink,
          ),
        ),
      ],
    );
  }
}

class _DiscrepancySection extends StatelessWidget {
  final double variance;
  final bool accepted;
  final TextEditingController reasonController;
  final VoidCallback onRecount;
  final VoidCallback onAccept;

  const _DiscrepancySection({
    required this.variance,
    required this.accepted,
    required this.reasonController,
    required this.onRecount,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final String badge = variance >= 0
        ? '+${PosHomeSpec.formatPrice(variance, padZero: false)}'
        : '−${PosHomeSpec.formatPrice(variance.abs(), padZero: false)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Cash difference detected',
                style: loewExtraBold.copyWith(
                  fontSize: PosCloseDaySpec.discrepancyTitleSize,
                  color: PosCloseDaySpec.ink,
                ),
              ),
            ),
            Container(
              padding: PosCloseDaySpec.discrepancyBadgePadding,
              decoration: BoxDecoration(
                color: PosCloseDaySpec.discrepancyBadgeBg,
                borderRadius: BorderRadius.circular(
                  PosCloseDaySpec.discrepancyBadgeRadius,
                ),
              ),
              child: Text(
                badge,
                style: loewExtraBold.copyWith(
                  fontSize: PosCloseDaySpec.discrepancyBadgeSize,
                  color: PosCloseDaySpec.discrepancyRed,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: PosCloseDaySpec.discrepancySectionGap),
        Row(
          children: <Widget>[
            Expanded(
              child: _SecondaryButton(
                label: 'Recount',
                filled: false,
                onTap: onRecount,
              ),
            ),
            const SizedBox(width: PosCloseDaySpec.discrepancyActionGap),
            Expanded(
              child: _SecondaryButton(
                label: 'Accept difference',
                filled: true,
                onTap: accepted ? null : onAccept,
              ),
            ),
          ],
        ),
        if (accepted) ...<Widget>[
          const SizedBox(height: PosCloseDaySpec.discrepancySectionGap),
          TextField(
            controller: reasonController,
            style: loewRegular.copyWith(
              fontSize: PosCloseDaySpec.inputTextSize,
              color: PosCloseDaySpec.ink,
            ),
            decoration: InputDecoration(
              hintText: 'Reason for difference',
              hintStyle: loewRegular.copyWith(
                fontSize: PosCloseDaySpec.inputTextSize,
                color: PosCloseDaySpec.inputPlaceholder,
              ),
              contentPadding: PosCloseDaySpec.pinFieldPadding,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(PosCloseDaySpec.reasonFieldRadius),
                borderSide: const BorderSide(
                  color: PosCloseDaySpec.inputBorderColor,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(PosCloseDaySpec.reasonFieldRadius),
                borderSide: const BorderSide(
                  color: PosCloseDaySpec.inputBorderColor,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(PosCloseDaySpec.reasonFieldRadius),
                borderSide: const BorderSide(
                  color: PosCloseDaySpec.ink,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ] else ...<Widget>[
          const SizedBox(height: PosCloseDaySpec.discrepancySectionGap),
          Text(
            'Choose one of both options to continue',
            style: loewRegular.copyWith(
              fontSize: PosCloseDaySpec.discrepancyHintSize,
              color: PosHomeSpec.inkAlpha(0.6),
            ),
          ),
        ],
      ],
    );
  }
}

class _PendingOrdersSection extends StatelessWidget {
  final int count;
  final bool closeAnyway;
  final VoidCallback onBackToOrders;
  final VoidCallback onCloseAnyway;

  const _PendingOrdersSection({
    required this.count,
    required this.closeAnyway,
    required this.onBackToOrders,
    required this.onCloseAnyway,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: PosCloseDaySpec.warningBannerPadding,
          decoration: BoxDecoration(
            color: PosCloseDaySpec.warningBannerBg,
            borderRadius:
                BorderRadius.circular(PosCloseDaySpec.warningBannerRadius),
            border: Border.all(color: PosCloseDaySpec.cardBorderColor),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: PosCloseDaySpec.warningIconSize,
                height: PosCloseDaySpec.warningIconSize,
                child: SvgPicture.asset(
                  Images.posAlertTriangleSvg,
                  width: PosCloseDaySpec.warningIconSize,
                  height: PosCloseDaySpec.warningIconSize,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$count order${count == 1 ? '' : 's'} are still in progress',
                  style: loewBold.copyWith(
                    fontSize: PosCloseDaySpec.warningTextSize,
                    color: PosCloseDaySpec.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PosCloseDaySpec.discrepancySectionGap),
        Row(
          children: <Widget>[
            Expanded(
              child: _SecondaryButton(
                label: 'Back to Orders',
                filled: false,
                onTap: onBackToOrders,
              ),
            ),
            const SizedBox(width: PosCloseDaySpec.discrepancyActionGap),
            Expanded(
              child: _SecondaryButton(
                label: 'Close anyway',
                filled: true,
                onTap: closeAnyway ? null : onCloseAnyway,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionsList extends StatelessWidget {
  final bool printZReport;
  final bool emailReport;
  final TextEditingController pinController;
  final String? pinError;
  final ValueChanged<bool> onPrintChanged;
  final ValueChanged<bool> onEmailChanged;

  const _ActionsList({
    required this.printZReport,
    required this.emailReport,
    required this.pinController,
    required this.pinError,
    required this.onPrintChanged,
    required this.onEmailChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _CheckboxRow(
          label: 'Print Z-report',
          value: printZReport,
          onChanged: onPrintChanged,
        ),
        const SizedBox(height: PosCloseDaySpec.actionsListGap),
        _CheckboxRow(
          label: 'Email report to accountant',
          value: emailReport,
          onChanged: onEmailChanged,
        ),
        const SizedBox(height: PosCloseDaySpec.actionsListGap),
        Text(
          'MANAGER PIN (IF REQUIRED)',
          style: loewBold.copyWith(
            fontSize: PosCloseDaySpec.pinLabelSize,
            color: PosHomeSpec.inkAlpha(0.6),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: pinController,
          obscureText: true,
          obscuringCharacter: '•',
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(8),
          ],
          style: loewRegular.copyWith(
            fontSize: PosCloseDaySpec.inputTextSize,
            color: PosCloseDaySpec.ink,
          ),
          decoration: InputDecoration(
            hintText: 'Enter PIN',
            hintStyle: loewRegular.copyWith(
              fontSize: PosCloseDaySpec.inputTextSize,
              color: PosCloseDaySpec.inputPlaceholder,
            ),
            contentPadding: PosCloseDaySpec.pinFieldPadding,
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(PosCloseDaySpec.pinFieldRadius),
              borderSide: const BorderSide(
                color: PosCloseDaySpec.inputBorderColor,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(PosCloseDaySpec.pinFieldRadius),
              borderSide: const BorderSide(
                color: PosCloseDaySpec.inputBorderColor,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(PosCloseDaySpec.pinFieldRadius),
              borderSide: const BorderSide(
                color: PosCloseDaySpec.ink,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (pinError != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            pinError!,
            style: loewBold.copyWith(
              fontSize: PosCloseDaySpec.footerHintSize,
              color: PosCloseDaySpec.discrepancyRed,
            ),
          ),
        ],
      ],
    );
  }
}

class _CheckboxRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckboxRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Row(
        children: <Widget>[
          Container(
            width: PosCloseDaySpec.checkboxSize,
            height: PosCloseDaySpec.checkboxSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: value ? PosCloseDaySpec.ink : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(PosCloseDaySpec.checkboxRadius),
              border: Border.all(
                color: PosCloseDaySpec.ink,
                width: PosCloseDaySpec.checkboxBorder,
              ),
            ),
            child: value
                ? const Icon(
                    Icons.check,
                    size: 14,
                    color: PosCloseDaySpec.pageBg,
                  )
                : null,
          ),
          const SizedBox(width: PosCloseDaySpec.checkboxGap),
          Text(
            label,
            style: loewMedium.copyWith(
              fontSize: PosCloseDaySpec.checkboxLabelSize,
              color: PosCloseDaySpec.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _Step2Footer extends StatelessWidget {
  final bool canConfirm;
  final String hint;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _Step2Footer({
    required this.canConfirm,
    required this.hint,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _FooterButton(
                label: 'CANCEL',
                filled: false,
                onTap: onCancel,
              ),
            ),
            const SizedBox(width: PosCloseDaySpec.footerGap),
            Expanded(
              child: Opacity(
                opacity:
                    canConfirm ? 1 : PosCloseDaySpec.continueDisabledOpacity,
                child: _FooterButton(
                  label: 'Confirm & Close Day',
                  filled: true,
                  onTap: canConfirm ? onConfirm : null,
                ),
              ),
            ),
          ],
        ),
        if (hint.isNotEmpty) ...<Widget>[
          const SizedBox(height: PosCloseDaySpec.footerHintGap),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: loewBold.copyWith(
              fontSize: PosCloseDaySpec.footerHintSize,
              color: PosCloseDaySpec.discrepancyRed,
            ),
          ),
        ],
      ],
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _SecondaryButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosCloseDaySpec.secondaryButtonRadius);
    final bool enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: filled ? PosCloseDaySpec.ink : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: PosCloseDaySpec.secondaryButtonPadding,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: filled
                  ? null
                  : Border.all(
                      color: PosCloseDaySpec.cardBorderColor,
                      width: 1.5,
                    ),
            ),
            child: Text(
              label,
              style: loewBold.copyWith(
                fontSize: PosCloseDaySpec.secondaryButtonTextSize,
                color: filled ? Colors.white : PosCloseDaySpec.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _FooterButton({
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
            textAlign: TextAlign.center,
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
