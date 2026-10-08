import 'package:acafe_customer/features/pos/domain/pos_attendance.dart';
import 'package:acafe_customer/features/pos/providers/pos_attendance_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_ui.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

/// POS Attendance tab: a day's punch-clock attendance for the branch, read from
/// Planday. A manager sees every linked staff member and may filter to one; any
/// other signed-in staff member sees only their own punches. The scope, the
/// filter list and the rows are all decided server-side — this screen only
/// renders what comes back and never converts a time through any timezone.
class PosAttendanceScreen extends StatefulWidget {
  const PosAttendanceScreen({super.key});

  @override
  State<PosAttendanceScreen> createState() => _PosAttendanceScreenState();
}

class _PosAttendanceScreenState extends State<PosAttendanceScreen> {
  @override
  void initState() {
    super.initState();
    // Load on first mount only. A pre-loaded provider (tests, a kept-alive tab)
    // keeps its data rather than refetching on every rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<PosAttendanceProvider>();
      if (provider.model == null && !provider.isLoading) {
        provider.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PosAttendanceProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(provider: provider),
        const SizedBox(height: PosUI.gutter),
        Expanded(child: _Body(provider: provider)),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final PosAttendanceProvider provider;

  const _Header({required this.provider});

  Future<void> _pickDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: provider.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) await provider.setDate(picked);
  }

  @override
  Widget build(BuildContext context) {
    final PosAttendance? model = provider.model;
    final bool showFilter =
        model != null && model.isManager && model.employees.isNotEmpty;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: PosUI.gutter,
      runSpacing: PosUI.gutterTight,
      children: [
        Text(
          'Attendance',
          style: loewExtraBold.copyWith(
              fontSize: PosUI.headingSize, color: PosUI.ink),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoundIcon(
              key: const Key('pos-attendance-prev'),
              icon: Icons.chevron_left_rounded,
              onTap: provider.prevDay,
            ),
            const SizedBox(width: PosUI.gutterTight),
            InkWell(
              key: const Key('pos-attendance-date'),
              onTap: () => _pickDate(context),
              borderRadius: BorderRadius.circular(PosUI.radius),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: PosUI.surface,
                  borderRadius: BorderRadius.circular(PosUI.radius),
                  border: Border.all(color: PosUI.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: PosUI.ink),
                    const SizedBox(width: 8),
                    Text(
                      intl.DateFormat('EEE, d MMM yyyy').format(provider.date),
                      style: loewMedium.copyWith(
                          fontSize: PosUI.captionSize, color: PosUI.ink),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: PosUI.gutterTight),
            _RoundIcon(
              key: const Key('pos-attendance-next'),
              icon: Icons.chevron_right_rounded,
              onTap: provider.nextDay,
            ),
            const SizedBox(width: PosUI.gutterTight),
            TextButton(
              key: const Key('pos-attendance-today'),
              onPressed: provider.isToday ? null : provider.today,
              child: Text('Today',
                  style: loewBold.copyWith(
                      fontSize: PosUI.captionSize,
                      color: provider.isToday ? PosUI.inkMuted : PosUI.ink)),
            ),
          ],
        ),
        if (showFilter) _EmployeeFilter(provider: provider, model: model),
      ],
    );
  }
}

class _EmployeeFilter extends StatelessWidget {
  final PosAttendanceProvider provider;
  final PosAttendance model;

  const _EmployeeFilter({required this.provider, required this.model});

  @override
  Widget build(BuildContext context) {
    final TextStyle style =
        loewMedium.copyWith(fontSize: PosUI.captionSize, color: PosUI.ink);

    // Shared POS select: the menu opens *below* this field in the root
    // overlay instead of Material's DropdownButton painting over it.
    return PosDropdown<int?>(
      value: provider.employeeFilter,
      onChanged: provider.setEmployeeFilter,
      options: [
        const PosDropdownOption<int?>(value: null, label: 'All staff'),
        for (final e in model.employees)
          PosDropdownOption<int?>(value: e.plandayEmployeeId, label: e.name),
      ],
      triggerBuilder: (context, selected, isOpen, toggle) {
        return Material(
          key: const Key('pos-attendance-employee-filter'),
          color: PosUI.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(PosUI.radius),
            side: BorderSide(color: isOpen ? PosUI.ink : PosUI.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: toggle,
            child: SizedBox(
              width: 240,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected?.label ?? 'All staff',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 140),
                      child: const Icon(Icons.expand_more_rounded,
                          color: PosUI.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  final PosAttendanceProvider provider;

  const _Body({required this.provider});

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.model == null) {
      return const Center(child: CircularProgressIndicator(color: PosUI.ink));
    }

    // A null payload is a transport failure: nothing is known, so offer a retry.
    if (provider.loadFailed || provider.model == null) {
      return _EmptyState(
        icon: Icons.wifi_off_rounded,
        message: "Couldn't load attendance.",
        onRetry: provider.load,
      );
    }

    final PosAttendance model = provider.model!;

    // Server-driven empty states each carry their own message.
    if (!model.plandayEnabled || !model.linked || !model.reachable) {
      return _EmptyState(
        icon: !model.reachable
            ? Icons.cloud_off_rounded
            : Icons.info_outline_rounded,
        message: model.message ?? 'No attendance to show.',
        onRetry: !model.reachable ? provider.load : null,
      );
    }

    if (model.rows.isEmpty) {
      return _EmptyState(
        icon: Icons.schedule_rounded,
        message: model.message ?? 'No attendance for this day.',
      );
    }

    final groups = model.groups;

    // No overscroll glow/stretch and no desktop scrollbar: dragging the list
    // past its edge should not paint a grey indicator over the page.
    return ScrollConfiguration(
      behavior: const _NoGlowScrollBehavior(),
      child: ListView.separated(
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: PosUI.gutter),
        itemBuilder: (context, i) => _EmployeeCard(group: groups[i]),
      ),
    );
  }
}

/// Removes the overscroll glow/stretch (and the desktop scrollbar) so dragging
/// the attendance list past its edge paints nothing over the page -- same clean
/// treatment the kiosk menu uses.
class _NoGlowScrollBehavior extends ScrollBehavior {
  const _NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  Widget buildScrollbar(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

/// One employee's punches for the day, grouped under a single heading -- the
/// Planday Timesheets shape: the name once, the shifts listed beneath it.
class _EmployeeCard extends StatelessWidget {
  final PosAttendanceGroup group;

  const _EmployeeCard({required this.group});

  String _totalLabel() {
    final int m = group.totalMinutes;
    final String worked = m < 60 ? '${m}m' : '${m ~/ 60}h ${m % 60}m';
    final String shifts =
        '${group.shiftCount} ${group.shiftCount == 1 ? 'shift' : 'shifts'}';
    return group.hasOpenShift
        ? '$shifts · $worked so far'
        : '$shifts · $worked';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('attendance-group-${group.plandayEmployeeId}'),
      decoration: BoxDecoration(
        color: PosUI.surface,
        borderRadius: BorderRadius.circular(PosUI.radius),
        border: Border.all(color: PosUI.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Heading: avatar + name + role on the left, the day's total on the
          // right. Sits on a sunken band so it reads as the group's header.
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: PosUI.gutterTight, vertical: 12),
            color: PosUI.surfaceSunken,
            child: Row(
              children: [
                _InitialsAvatar(name: group.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.name,
                          style: loewBold.copyWith(
                              fontSize: PosUI.bodySize, color: PosUI.ink)),
                      if ((group.role ?? '').isNotEmpty)
                        Text(group.role!,
                            style: loewRegular.copyWith(
                                fontSize: PosUI.captionSize,
                                color: PosUI.inkMuted)),
                    ],
                  ),
                ),
                Text(_totalLabel(),
                    style: loewMedium.copyWith(
                        fontSize: PosUI.captionSize, color: PosUI.inkMuted)),
              ],
            ),
          ),
          // The punches, one row each, divided like Planday's timesheet rows.
          for (int i = 0; i < group.rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: PosUI.border),
            _PunchRow(row: group.rows[i]),
          ],
        ],
      ),
    );
  }
}

/// A single punch line inside an employee card: clock in → out, the worked
/// time, and the status chip.
class _PunchRow extends StatelessWidget {
  final PosAttendanceRow row;

  const _PunchRow({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: PosUI.gutterTight, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 4, child: _TimeBlock(row: row)),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: _StatusChip(row: row),
            ),
          ),
        ],
      ),
    );
  }
}

/// A small circular initials badge, matching the nav avatar's look.
class _InitialsAvatar extends StatelessWidget {
  final String name;

  const _InitialsAvatar({required this.name});

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration:
          const BoxDecoration(color: PosUI.accent, shape: BoxShape.circle),
      child: Text(_initials,
          style:
              loewBold.copyWith(fontSize: 13, color: PosUI.ink, height: 1.0)),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  final PosAttendanceRow row;

  const _TimeBlock({required this.row});

  @override
  Widget build(BuildContext context) {
    final String inOut =
        '${row.clockIn ?? '—'}  →  ${row.isOpen ? 'Still in' : (row.clockOut ?? '—')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(inOut,
            style: loewMedium.copyWith(
                fontSize: PosUI.bodySize, color: PosUI.ink)),
        const SizedBox(height: 2),
        Text(
          row.isOpen
              ? 'In progress'
              : (row.workedLabel != null ? 'Worked ${row.workedLabel}' : ''),
          style: loewRegular.copyWith(
              fontSize: PosUI.captionSize, color: PosUI.inkMuted),
        ),
        if (row.hasSchedule)
          Text(
            'Scheduled ${row.scheduledStart ?? '—'}–${row.scheduledEnd ?? '—'}',
            style: loewRegular.copyWith(
                fontSize: PosUI.captionSize, color: PosUI.inkMuted),
          ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final PosAttendanceRow row;

  const _StatusChip({required this.row});

  @override
  Widget build(BuildContext context) {
    final (String label, Color bg, Color fg) = switch (row.status) {
      'active' => ('Active', PosUI.accent, PosUI.ink),
      'approved' => ('Approved', PosUI.success, Colors.white),
      _ => ('Done', PosUI.surfaceSunken, PosUI.ink),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: loewBold.copyWith(fontSize: 12, color: fg)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Future<void> Function()? onRetry;

  const _EmptyState({required this.icon, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: PosUI.inkMuted),
          const SizedBox(height: PosUI.gutterTight),
          Text(message,
              textAlign: TextAlign.center,
              style: loewMedium.copyWith(
                  fontSize: PosUI.bodySize, color: PosUI.inkMuted)),
          if (onRetry != null) ...[
            const SizedBox(height: PosUI.gutter),
            TextButton(
              key: const Key('pos-attendance-retry'),
              onPressed: onRetry,
              child: Text('Retry',
                  style: loewBold.copyWith(
                      fontSize: PosUI.bodySize, color: PosUI.ink)),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;
  final Future<void> Function() onTap;

  const _RoundIcon({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PosUI.surface,
      shape: const CircleBorder(side: BorderSide(color: PosUI.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: PosUI.ink, size: 22),
        ),
      ),
    );
  }
}
