import 'package:acafe_customer/features/pos/domain/pos_attendance.dart';
import 'package:acafe_customer/features/pos/providers/pos_attendance_provider.dart';
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: PosUI.surface,
        borderRadius: BorderRadius.circular(PosUI.radius),
        border: Border.all(color: PosUI.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          key: const Key('pos-attendance-employee-filter'),
          value: provider.employeeFilter,
          hint: Text('All staff',
              style:
                  loewMedium.copyWith(fontSize: PosUI.captionSize, color: PosUI.ink)),
          icon: const Icon(Icons.expand_more_rounded, color: PosUI.ink),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text('All staff',
                  style: loewMedium.copyWith(
                      fontSize: PosUI.captionSize, color: PosUI.ink)),
            ),
            for (final e in model.employees)
              DropdownMenuItem<int?>(
                value: e.plandayEmployeeId,
                child: Text(e.name,
                    style: loewMedium.copyWith(
                        fontSize: PosUI.captionSize, color: PosUI.ink)),
              ),
          ],
          onChanged: provider.setEmployeeFilter,
        ),
      ),
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
        icon: !model.reachable ? Icons.cloud_off_rounded : Icons.info_outline_rounded,
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

    return ListView.separated(
      itemCount: model.rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: PosUI.gutterTight),
      itemBuilder: (context, i) => _AttendanceRowCard(row: model.rows[i]),
    );
  }
}

class _AttendanceRowCard extends StatelessWidget {
  final PosAttendanceRow row;

  const _AttendanceRowCard({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('attendance-row-${row.plandayEmployeeId}-${row.clockIn}'),
      padding: const EdgeInsets.all(PosUI.gutterTight),
      decoration: BoxDecoration(
        color: PosUI.surface,
        borderRadius: BorderRadius.circular(PosUI.radius),
        border: Border.all(color: PosUI.border),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.name,
                    style: loewBold.copyWith(
                        fontSize: PosUI.bodySize, color: PosUI.ink)),
                if ((row.role ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(row.role!,
                        style: loewRegular.copyWith(
                            fontSize: PosUI.captionSize, color: PosUI.inkMuted)),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: _TimeBlock(row: row),
          ),
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
            style:
                loewMedium.copyWith(fontSize: PosUI.bodySize, color: PosUI.ink)),
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
      child: Text(label,
          style: loewBold.copyWith(fontSize: 12, color: fg)),
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
                  style:
                      loewBold.copyWith(fontSize: PosUI.bodySize, color: PosUI.ink)),
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
