import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_order_filters.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';

/// `date-row` (Figma 1915:15772): a NOW toggle and From / To date-time fields.
///
/// Built new rather than reused — there is no calendar picker anywhere else in
/// the app. Receipts filters by preset range dropdowns (Today / Yesterday /
/// Last 7 days / This month), which cannot express the arbitrary window Figma
/// draws here.
///
/// NOW is not merely a shortcut for "today": it makes the window's end follow
/// the clock, so a terminal left open through service keeps showing orders
/// placed after the operator last touched the filter. Picking an explicit To
/// time is what turns it off.
class PosOrderDateRangeBar extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final bool now;
  final ValueChanged<bool> onNow;
  final ValueChanged<DateTime> onFrom;
  final ValueChanged<DateTime> onTo;

  const PosOrderDateRangeBar({
    super.key,
    required this.from,
    required this.to,
    required this.now,
    required this.onNow,
    required this.onFrom,
    required this.onTo,
  });

  static final DateFormat _date = DateFormat('MMM d, yyyy');
  static final DateFormat _time = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: PosOrdersSpec.dateGap,
      runSpacing: PosOrdersSpec.dateGap,
      children: [
        _NowPill(active: now, onTap: () => onNow(!now)),
        _labelled(
          'From',
          _DateTimeField(
            value: from,
            showTime: false,
            placeholder: 'START DATE',
            onChanged: onFrom,
          ),
        ),
        _labelled(
          'To',
          _DateTimeField(
            value: now ? null : to,
            showTime: true,
            // In NOW mode there is no fixed end, and printing a frozen
            // timestamp would misrepresent a window that is still moving.
            placeholder: now ? 'NOW' : 'END DATE',
            onChanged: onTo,
          ),
        ),
      ],
    );
  }

  Widget _labelled(String label, Widget field) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: loewBold.copyWith(
            fontSize: PosOrdersSpec.dateLabelSize,
            color: PosHomeSpec.inkAlpha(0.6),
          ),
        ),
        const SizedBox(width: PosOrdersSpec.dateLabelGap),
        field,
      ],
    );
  }

  static String formatDate(DateTime value) => _date.format(value);

  static String formatTime(DateTime value) => _time.format(value);
}

/// Quick date-range presets in the same row as the From/To fields.
///
/// Not drawn in Figma 1915:15772, kept on purpose (they carry the
/// cross-clock date_to fix), and drawn in that row's own pill so the row reads
/// as one control: the same outlined r20 pill as NOW.
class PosOrderDatePresetBar extends StatelessWidget {
  final PosOrderDateRangePreset value;
  final ValueChanged<PosOrderDateRangePreset> onChanged;

  const PosOrderDatePresetBar({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: PosOrdersSpec.dateGap,
      runSpacing: PosOrdersSpec.dateGap,
      children: [
        for (final option in PosOrderFilters.dateRangePresets)
          _FilterPill(
            label: option.label,
            active: option.value == value,
            onTap: () => onChanged(option.value),
          ),
      ],
    );
  }
}

/// `today-btn` — NOW. The same pill as the presets beside it.
class _NowPill extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _NowPill({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _FilterPill(
      label: 'NOW',
      active: active,
      onTap: onTap,
      minWidth: PosOrdersSpec.nowButtonWidth,
    );
  }
}

/// Outlined r20 pill, ink-filled when active. Bold 12, uppercase.
class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final double minWidth;

  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
    this.minWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius =
        BorderRadius.circular(PosOrdersSpec.filterPillRadius);

    return Material(
      color: active ? PosHomeSpec.ink : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          constraints: BoxConstraints(minWidth: minWidth),
          padding: const EdgeInsets.symmetric(
            horizontal: PosOrdersSpec.nowPaddingH,
            vertical: PosOrdersSpec.filterPillPaddingV,
          ),
          // Figma strokes sit inside the pill and move nothing.
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: PosHomeSpec.ink,
              width: PosOrdersSpec.filterPillBorder,
            ),
          ),
          // A Row that shrink-wraps rather than `alignment: center` on the
          // Container: an aligned Container with no width expands to fill its
          // constraints, which turned this pill into a full-width bar the
          // moment the filter bar stacked at tablet width.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label.toUpperCase(),
                style: loewBold.copyWith(
                  fontSize: PosOrdersSpec.dateTextSize,
                  color: active ? PosHomeSpec.pageBg : PosHomeSpec.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final DateTime? value;
  final bool showTime;
  final String placeholder;
  final ValueChanged<DateTime> onChanged;

  const _DateTimeField({
    required this.value,
    required this.showTime,
    required this.placeholder,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final DateTime seed = value ?? DateTime.now();

    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: seed,
      firstDate: DateTime(2020),
      // A terminal clock can sit ahead of the server's, and an operator may
      // legitimately want the window to run to the end of today.
      lastDate: DateTime.now().add(const Duration(days: 366)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: PosHomeSpec.ink,
                onPrimary: Colors.white,
                surface: PosHomeSpec.panelBg,
                onSurface: PosHomeSpec.ink,
              ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );

    if (date == null || !context.mounted) return;

    if (!showTime) {
      onChanged(DateTime(date.year, date.month, date.day));
      return;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(seed),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: PosHomeSpec.ink,
                onPrimary: Colors.white,
                surface: PosHomeSpec.panelBg,
                onSurface: PosHomeSpec.ink,
              ),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    );

    // Cancelling the time step still commits the date, ending at 23:59 — the
    // default Figma shows on the To field.
    onChanged(DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 23,
      time?.minute ?? 59,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bool empty = value == null;
    final BorderRadius radius =
        BorderRadius.circular(PosOrdersSpec.filterPillRadius);

    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: PosOrdersSpec.dateFieldPaddingH,
            vertical: PosOrdersSpec.filterPillPaddingV,
          ),
          // Figma strokes sit inside the pill and move nothing.
          foregroundDecoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: PosHomeSpec.ink,
              width: PosOrdersSpec.filterPillBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                Images.posOrdersCalendarSvg,
                width: PosOrdersSpec.filterIconSize,
                height: PosOrdersSpec.filterIconSize,
              ),
              const SizedBox(width: PosOrdersSpec.filterIconGap),
              Text(
                empty
                    ? placeholder
                    : PosOrderDateRangeBar.formatDate(value!).toUpperCase(),
                style: loewBold.copyWith(
                  fontSize: PosOrdersSpec.dateTextSize,
                  color: empty
                      ? PosHomeSpec.inkAlpha(0.45)
                      : PosHomeSpec.ink,
                ),
              ),
              if (showTime && !empty) ...[
                const SizedBox(width: PosOrdersSpec.filterIconGap),
                Text(
                  PosOrderDateRangeBar.formatTime(value!),
                  style: loewBold.copyWith(
                    fontSize: PosOrdersSpec.dateTextSize,
                    color: PosHomeSpec.inkAlpha(0.6),
                  ),
                ),
                const SizedBox(width: PosOrdersSpec.filterIconGap),
                SvgPicture.asset(
                  Images.posOrdersClockSvg,
                  width: PosOrdersSpec.filterIconSize,
                  height: PosOrdersSpec.filterIconSize,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
