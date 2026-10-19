import 'package:acafe_customer/features/pos/domain/pos_report_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Day selector + Close Day, the `top-controls` row of Figma **1915:18094**.
///
/// A single-day control, deliberately not the Receipts filter: that one is a
/// preset *range* (Today / Last 7 days / …) and answers a different question.
/// Here the whole screen is scoped to exactly one business day, because a
/// Z Report is.
///
/// Next-day is disabled on today. The endpoint rejects a future date with a
/// 422, so letting the arrow step past today would only ever produce an error
/// toast — better that the control says so first.
class PosReportDateHeader extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  /// The branch's business "today", as the server resolved it -- not
  /// `DateTime.now()`. A POS terminal's own OS clock can be set to any
  /// timezone; the server validates and reports against the one configured
  /// in Settings → General (Business Setting `time_zone`), and this control
  /// must agree with whichever day the server will actually accept, or the
  /// arrow lets the operator step into a date the endpoint then 422s on.
  final DateTime today;

  /// Null while the day is already closed or a close is in flight — the button
  /// renders in its disabled state rather than disappearing, so the day's state
  /// stays legible.
  final VoidCallback? onCloseDay;
  final bool closed;
  final bool closing;

  const PosReportDateHeader({
    super.key,
    required this.date,
    required this.onDateChanged,
    required this.today,
    required this.onCloseDay,
    required this.closed,
    required this.closing,
  });

  static const List<String> _weekdays = <String>[
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const List<String> _months = <String>[
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// `Thursday, 23 June` — the Figma format.
  static String formatLong(DateTime date) =>
      '${_weekdays[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isToday => isSameDay(date, today);

  Future<void> _pick(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: date,
      // The system has no orders before it existed, and the endpoint refuses
      // anything after today.
      firstDate: DateTime(2020),
      lastDate: DateTime(today.year, today.month, today.day),
      builder: (BuildContext context, Widget? child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: PosReportSpec.ink,
                onPrimary: PosUI.pageBg,
                surface: PosUI.surface,
                onSurface: PosReportSpec.ink,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null && !isSameDay(picked, date)) {
      onDateChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  void _step(int days) {
    final DateTime next = DateTime(date.year, date.month, date.day + days);
    if (days > 0 && next.isAfter(today)) return;
    onDateChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    // Date controls left, Close Day hard right — one row, as drawn.
    //
    // The left group is a Wrap so that on a genuinely narrow terminal the two
    // step buttons drop under the date field instead of squeezing it; the outer
    // Row keeps Close Day pinned right in every case. An outer Wrap was wrong
    // here: with spaceBetween it hands the first child the full line and pushes
    // the CTA onto its own row even at 1366.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: posPx(context, PosReportSpec.controlGap),
            runSpacing: posPx(context, PosReportSpec.controlGap),
            children: <Widget>[
              _DatePickerButton(
                label: formatLong(date),
                onTap: () => _pick(context),
              ),
              _StepButton(
                asset: Images.posReportChevronLeftSvg,
                fallback: Icons.chevron_left_rounded,
                tooltip: 'Previous day',
                onTap: () => _step(-1),
              ),
              _StepButton(
                asset: Images.posReportChevronRightSvg,
                fallback: Icons.chevron_right_rounded,
                tooltip: 'Next day',
                onTap: _isToday ? null : () => _step(1),
              ),
            ],
          ),
        ),
        SizedBox(width: posPx(context, PosReportSpec.controlGap)),
        _CloseDayButton(
          onTap: onCloseDay,
          closed: closed,
          closing: closing,
        ),
      ],
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DatePickerButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _Control(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: posPx(context, PosReportSpec.datePickerPaddingH),
        vertical: posPx(context, PosReportSpec.datePickerPaddingV),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SvgPicture.asset(
            Images.posReportCalendarSvg,
            width: posPx(context, PosReportSpec.dateIconSize),
            height: posPx(context, PosReportSpec.dateIconSize),
            placeholderBuilder: (_) => Icon(
              Icons.calendar_today_outlined,
              size: posPx(context, PosReportSpec.dateIconSize),
              color: PosReportSpec.ink,
            ),
          ),
          SizedBox(width: posPx(context, PosReportSpec.datePickerGap)),
          Text(
            label,
            style: loewBold.copyWith(
              fontSize: posPx(context, PosReportSpec.dateTextSize),
              color: PosReportSpec.ink,
              letterSpacing: PosReportSpec.tracking,
            ),
            maxLines: 1,
          ),
          SizedBox(width: posPx(context, PosReportSpec.datePickerGap)),
          SvgPicture.asset(
            Images.posReportChevronDownSvg,
            width: posPx(context, PosReportSpec.chevronSize),
            height: posPx(context, PosReportSpec.chevronSize),
            colorFilter:
                const ColorFilter.mode(PosReportSpec.ink, BlendMode.srcIn),
            // A stale web AssetManifest must not leave the control looking
            // like plain text — same guard as pos_payment_method_card.
            placeholderBuilder: (_) => Icon(
              Icons.keyboard_arrow_down_rounded,
              size: posPx(context, PosReportSpec.chevronSize),
              color: PosReportSpec.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final String asset;
  final IconData fallback;
  final String tooltip;
  final VoidCallback? onTap;

  const _StepButton({
    required this.asset,
    required this.fallback,
    required this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = onTap != null
        ? PosReportSpec.ink
        : PosReportSpec.ink.withValues(alpha: PosReportSpec.stepDisabledAlpha);
    final double size = posPx(context, PosReportSpec.navIconSize);

    return Tooltip(
      message: tooltip,
      child: _Control(
        onTap: onTap,
        width: posPx(context, PosReportSpec.controlHeight),
        height: posPx(context, PosReportSpec.controlHeight),
        child: SvgPicture.asset(
          asset,
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          placeholderBuilder: (_) => Icon(fallback, size: size, color: color),
        ),
      ),
    );
  }
}

/// White, `#E1DBC4` hairline, 12px radius — the shared shape of all three date
/// controls.
class _Control extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const _Control({
    required this.child,
    this.onTap,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(posPx(context, PosReportSpec.controlRadius));

    return Material(
      color: PosUI.surface,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: width,
          height: height,
          padding: padding,
          // Only centre when the control has an explicit size. A Container with
          // an alignment and no width expands to fill its constraints, which
          // stretched the date field across the whole row and pushed the step
          // buttons onto a second line.
          alignment:
              (width != null || height != null) ? Alignment.center : null,
          // Inside stroke, as Figma draws it: a decoration border would inset
          // the content and grow the date field from 37 to 39.
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: PosReportSpec.cardBorder,
              width: PosReportSpec.hairlineWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CloseDayButton extends StatelessWidget {
  final VoidCallback? onTap;
  final bool closed;
  final bool closing;

  const _CloseDayButton({
    required this.onTap,
    required this.closed,
    required this.closing,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(posPx(context, PosReportSpec.ctaRadius));
    final bool enabled = onTap != null && !closing && !closed;
    final Color fill = enabled
        ? PosReportSpec.ink
        : PosReportSpec.ink.withValues(alpha: PosReportSpec.ctaDisabledAlpha);
    final double icon = posPx(context, PosReportSpec.ctaIconSize);

    return Material(
      color: fill,
      borderRadius: radius,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: posPx(context, PosReportSpec.ctaPaddingH),
            vertical: posPx(context, PosReportSpec.ctaPaddingV),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (closing)
                SizedBox(
                  width: icon,
                  height: icon,
                  child: CircularProgressIndicator(
                    strokeWidth: posPx(context, PosReportSpec.ctaSpinnerStroke),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(PosUI.pageBg),
                  ),
                )
              else
                SvgPicture.asset(
                  Images.posReportLockSvg,
                  width: icon,
                  height: icon,
                  colorFilter:
                      const ColorFilter.mode(PosUI.pageBg, BlendMode.srcIn),
                  placeholderBuilder: (_) => Icon(
                    closed ? Icons.lock_rounded : Icons.lock_outline_rounded,
                    size: icon,
                    color: PosUI.pageBg,
                  ),
                ),
              SizedBox(width: posPx(context, PosReportSpec.ctaGap)),
              Text(
                closed ? 'Day Closed' : 'Close Day',
                style: loewExtraBold.copyWith(
                  fontSize: posPx(context, PosReportSpec.ctaTextSize),
                  color: PosUI.pageBg,
                  letterSpacing: PosReportSpec.tracking,
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
