import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_orders_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// `date-row` (Figma 1641:2878): a NOW toggle and From / To date-time fields.
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
            placeholder: 'Start date',
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
            placeholder: now ? 'Now' : 'End date',
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
          label,
          style: loewBold.copyWith(
            fontSize: PosOrdersSpec.dateLabelSize,
            color: PosHomeSpec.inkAlpha(0.6),
          ),
        ),
        const SizedBox(width: PosOrdersSpec.dateGap),
        field,
      ],
    );
  }

  static String formatDate(DateTime value) => _date.format(value);

  static String formatTime(DateTime value) => _time.format(value);
}

class _NowPill extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;

  const _NowPill({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? PosHomeSpec.ink : Colors.transparent,
      borderRadius: BorderRadius.circular(PosOrdersSpec.pillRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosOrdersSpec.pillRadius),
        child: Container(
          height: PosOrdersSpec.dateFieldHeight,
          constraints: const BoxConstraints(
            minWidth: PosOrdersSpec.nowButtonWidth,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosOrdersSpec.pillRadius),
            border: Border.all(color: PosHomeSpec.ink),
          ),
          // A Row that shrink-wraps rather than `alignment: center` on the
          // Container: an aligned Container with no width expands to fill its
          // constraints, which turned this pill into a full-width bar the
          // moment the filter bar stacked at tablet width.
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'NOW',
                style: loewBold.copyWith(
                  fontSize: PosOrdersSpec.dateTextSize,
                  color: active ? Colors.white : PosHomeSpec.ink,
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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(PosOrdersSpec.dateFieldRadius),
      child: InkWell(
        onTap: () => _pick(context),
        borderRadius: BorderRadius.circular(PosOrdersSpec.dateFieldRadius),
        child: Container(
          height: PosOrdersSpec.dateFieldHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: PosOrdersSpec.dateFieldPaddingH,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(PosOrdersSpec.dateFieldRadius),
            border: Border.all(color: PosHomeSpec.tableFieldBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: PosOrdersSpec.dateIconSize,
                color: PosHomeSpec.inkAlpha(0.6),
              ),
              const SizedBox(width: PosOrdersSpec.dateGap),
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
                const SizedBox(width: PosOrdersSpec.dateGap),
                Text(
                  PosOrderDateRangeBar.formatTime(value!),
                  style: loewBold.copyWith(
                    fontSize: PosOrdersSpec.dateTextSize,
                    color: PosHomeSpec.ink,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.schedule_outlined,
                  size: PosOrdersSpec.dateIconSize,
                  color: PosHomeSpec.inkAlpha(0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
