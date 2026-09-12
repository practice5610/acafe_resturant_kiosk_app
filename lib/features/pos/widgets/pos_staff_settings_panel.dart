import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_staff.dart';
import 'package:acafe_customer/features/pos/providers/pos_staff_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_text_field.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Settings → STAFF (Figma **1641:8484**).
///
/// Chrome is pixel-faithful to Figma; the data behind it is live. The roster,
/// the shift board and the permission grid all come from [PosStaffProvider],
/// which persists every change through [PosStaffRepo] to the branch DB.
class PosStaffSettingsPanel extends StatefulWidget {
  const PosStaffSettingsPanel({super.key});

  static const String pageTitle = 'STAFF';
  static const String pageSubtitle =
      'Manage team members, roles and permissions';

  @override
  State<PosStaffSettingsPanel> createState() => _PosStaffSettingsPanelState();
}

class _PosStaffSettingsPanelState extends State<PosStaffSettingsPanel> {
  final TextEditingController _name = TextEditingController();

  PosStaffProvider? _provider;

  /// The member the name field is currently showing. Tracked so selection
  /// changes rewrite the field while the operator's own keystrokes do not —
  /// echoing provider state back into the controller mid-edit would fight the
  /// cursor.
  String? _boundId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final PosStaffProvider next = context.read<PosStaffProvider>();
    if (identical(next, _provider)) return;
    _provider?.removeListener(_syncName);
    _provider = next..addListener(_syncName);
    _syncName();
  }

  @override
  void dispose() {
    _provider?.removeListener(_syncName);
    _name.dispose();
    super.dispose();
  }

  void _syncName() {
    final PosStaffProvider? provider = _provider;
    if (provider == null) return;
    final PosStaffMember? member = provider.selected;
    if (member == null) {
      _boundId = null;
      _name.clear();
      return;
    }
    if (_boundId == member.id) return;
    _boundId = member.id;
    _name.value = TextEditingValue(
      text: member.name,
      selection: TextSelection.collapsed(offset: member.name.length),
    );
  }

  Future<void> _openAddStaff({String? shiftId}) async {
    final PosStaffProvider provider = context.read<PosStaffProvider>();
    final _NewStaff? result = await showDialog<_NewStaff>(
      context: context,
      builder: (_) => _AddStaffDialog(
        shifts: provider.shifts,
        // Header → Morning; shift-row "+ Add" → that shift.
        initialShiftIds: {shiftId ?? PosStaffShift.morning},
      ),
    );
    if (result == null || !mounted) return;
    provider.addMember(
      name: result.name,
      role: result.role,
      shiftIds: result.shiftIds,
    );
  }

  Future<void> _openShift(String shiftId) async {
    final PosStaffProvider provider = context.read<PosStaffProvider>();
    await showDialog<void>(
      context: context,
      builder: (_) => ChangeNotifierProvider<PosStaffProvider>.value(
        value: provider,
        child: _ShiftRosterDialog(shiftId: shiftId),
      ),
    );
  }

  /// "+ Add" on a shift row — opens hire dialog with that shift pre-selected.
  Future<void> _addToShift(String shiftId) => _openAddStaff(shiftId: shiftId);

  @override
  Widget build(BuildContext context) {
    final PosStaffProvider provider = context.watch<PosStaffProvider>();
    final PosStaffMember? member = provider.selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StaffHeader(onAdd: _openAddStaff),
        const SizedBox(height: 32),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool wide =
                  constraints.maxWidth >= PosSettingsSpec.wideBreakpoint;
              final Widget left = _LeftColumn(
                provider: provider,
                onSelect: provider.select,
                onOpenShift: _openShift,
                onAddToShift: _addToShift,
              );
              final Widget right = _RightColumn(
                member: member,
                nameController: _name,
                nameError: provider.errors['name'],
                onNameChanged: provider.setName,
                onRoleChanged: provider.setRole,
                onActiveChanged: provider.setActive,
                onPermissionChanged: provider.setPermission,
                onRemove: member == null
                    ? null
                    : () => provider.removeMember(member.id),
              );

              if (!wide) {
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      left,
                      const SizedBox(height: 32),
                      right,
                    ],
                  ),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: SingleChildScrollView(child: left)),
                  const SizedBox(width: 32),
                  SizedBox(
                    width: 440,
                    child: SingleChildScrollView(child: right),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _StaffHeader extends StatefulWidget {
  final VoidCallback onAdd;

  const _StaffHeader({required this.onAdd});

  @override
  State<_StaffHeader> createState() => _StaffHeaderState();
}

class _StaffHeaderState extends State<_StaffHeader> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: PosSettingsSpec.divider),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    PosStaffSettingsPanel.pageTitle,
                    style: loewExtraBold.copyWith(
                      fontSize: 28,
                      color: PosSettingsSpec.ink,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    PosStaffSettingsPanel.pageSubtitle,
                    style: loewRegular.copyWith(
                      fontSize: 15,
                      color: PosSettingsSpec.inkMuted(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTapDown: (_) => setState(() => _pressed = true),
                onTapUp: (_) => setState(() => _pressed = false),
                onTapCancel: () => setState(() => _pressed = false),
                onTap: widget.onAdd,
                child: AnimatedScale(
                  scale: _pressed ? 0.97 : 1,
                  duration: const Duration(milliseconds: 90),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: PosSettingsSpec.ink,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14241F20),
                          offset: Offset(0, 6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Text(
                        'Add Staff Member',
                        style: loewBold.copyWith(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Left column ─────────────────────────────────────────────────────────────

class _LeftColumn extends StatelessWidget {
  final PosStaffProvider provider;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onOpenShift;
  final ValueChanged<String> onAddToShift;

  const _LeftColumn({
    required this.provider,
    required this.onSelect,
    required this.onOpenShift,
    required this.onAddToShift,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SHIFTS',
          style: loewExtraBold.copyWith(
            fontSize: 18,
            color: PosSettingsSpec.ink,
          ),
        ),
        const SizedBox(height: 16),
        _ShiftsCard(
          provider: provider,
          onOpenShift: onOpenShift,
          onAddToShift: onAddToShift,
        ),
        const SizedBox(height: 24),
        Text(
          'TEAM OF THE DAY',
          style: loewExtraBold.copyWith(
            fontSize: 18,
            color: PosSettingsSpec.ink,
          ),
        ),
        const SizedBox(height: 16),
        _TeamCard(
          members: provider.members,
          selectedId: provider.selectedId,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

class _ShiftsCard extends StatelessWidget {
  final PosStaffProvider provider;
  final ValueChanged<String> onOpenShift;
  final ValueChanged<String> onAddToShift;

  const _ShiftsCard({
    required this.provider,
    required this.onOpenShift,
    required this.onAddToShift,
  });

  @override
  Widget build(BuildContext context) {
    final List<PosStaffShift> shifts = provider.shifts;
    return _Card(
      child: Column(
        children: [
          const _TableHeader(columns: [
            _HeaderCell('SHIFT', width: 220),
            _HeaderCell('TIME', width: 160),
            _HeaderCell('STAFF', flex: 1),
          ]),
          for (int i = 0; i < shifts.length; i++)
            _ShiftRow(
              shift: shifts[i],
              members: provider.membersOf(shifts[i].id),
              showDivider: i < shifts.length - 1,
              onOpen: () => onOpenShift(shifts[i].id),
              onAdd: () => onAddToShift(shifts[i].id),
            ),
        ],
      ),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  final PosStaffShift shift;
  final List<PosStaffMember> members;
  final bool showDivider;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  const _ShiftRow({
    required this.shift,
    required this.members,
    required this.showDivider,
    required this.onOpen,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: Color(0xFFF0EBD8)),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 220,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InkPill(label: shift.name),
                  const SizedBox(height: 8),
                  Text(
                    shift.time,
                    style: loewRegular.copyWith(
                      fontSize: 13,
                      color: PosSettingsSpec.inkMuted(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: _StaffChipRow(
                members: members,
                visibleCount: 3,
                onOverflowTap: onOpen,
                onAdd: onAdd,
                addLabel: 'Add to ${shift.name}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffChipRow extends StatelessWidget {
  final List<PosStaffMember> members;
  final int visibleCount;
  final VoidCallback onOverflowTap;
  final VoidCallback onAdd;
  final String addLabel;

  const _StaffChipRow({
    required this.members,
    required this.visibleCount,
    required this.onOverflowTap,
    required this.onAdd,
    required this.addLabel,
  });

  @override
  Widget build(BuildContext context) {
    final int shown =
        members.length < visibleCount ? members.length : visibleCount;
    final int overflow = members.length - shown;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < shown; i++)
          _CreamChip(label: members[i].shortName),
        if (overflow > 0)
          _CreamChip(
            label: '+$overflow more',
            onTap: onOverflowTap,
          ),
        if (members.isEmpty)
          Text(
            'No one rostered',
            style: loewRegular.copyWith(
              fontSize: 13,
              color: PosSettingsSpec.inkMuted(),
            ),
          ),
        _AddChip(label: addLabel, onTap: onAdd),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  final List<PosStaffMember> members;
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _TeamCard({
    required this.members,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          const _TableHeader(columns: [
            _HeaderCell('NAME', width: 220),
            _HeaderCell('ROLE', width: 120),
            _HeaderCell('STATUS', width: 100),
          ]),
          if (members.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Text(
                'No staff yet. Use Add Staff Member to hire someone.',
                style: loewRegular.copyWith(
                  fontSize: 13,
                  color: PosSettingsSpec.inkMuted(),
                ),
              ),
            )
          else
            for (int i = 0; i < members.length; i++)
              _TeamRow(
                member: members[i],
                selected: members[i].id == selectedId,
                showDivider: i < members.length - 1,
                onTap: () => onSelect(members[i].id),
              ),
        ],
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final PosStaffMember member;
  final bool selected;
  final bool showDivider;
  final VoidCallback onTap;

  const _TeamRow({
    required this.member,
    required this.selected,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? PosSettingsSpec.pageBg.withValues(alpha: 0.65)
          : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(color: Color(0xFFF0EBD8)),
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 220,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: PosSettingsSpec.pageBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: PosSettingsSpec.fieldBorder),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          member.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: loewBold.copyWith(
                            fontSize: 14,
                            color: PosSettingsSpec.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _CreamChip(label: member.role, fontSize: 12),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: _StatusDot(active: member.active),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Right column ────────────────────────────────────────────────────────────

class _RightColumn extends StatelessWidget {
  final PosStaffMember? member;
  final TextEditingController nameController;
  final String? nameError;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onRoleChanged;
  final ValueChanged<bool> onActiveChanged;
  final void Function(String key, bool value) onPermissionChanged;
  final VoidCallback? onRemove;

  const _RightColumn({
    required this.member,
    required this.nameController,
    required this.nameError,
    required this.onNameChanged,
    required this.onRoleChanged,
    required this.onActiveChanged,
    required this.onPermissionChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final PosStaffMember? m = member;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MEMBER DETAILS',
            style: loewExtraBold.copyWith(
              fontSize: 18,
              color: PosSettingsSpec.ink,
            ),
          ),
          const SizedBox(height: 16),
          if (m == null)
            _Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Select a team member to edit their details.',
                  style: loewRegular.copyWith(
                    fontSize: 13,
                    color: PosSettingsSpec.inkMuted(),
                  ),
                ),
              ),
            )
          else ...[
            _MemberDetailsCard(
              nameController: nameController,
              nameError: nameError,
              onNameChanged: onNameChanged,
              role: m.role,
              onRoleChanged: onRoleChanged,
              active: m.active,
              onActiveChanged: onActiveChanged,
              onRemove: onRemove,
            ),
            const SizedBox(height: 24),
            _PermissionsCard(
              permissions: m.permissions,
              onPermissionChanged: onPermissionChanged,
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Restricted actions on POS prompt the manager PIN set for this '
            'device in Kiosk settings.',
            style: loewRegular.copyWith(
              fontSize: 13,
              height: 1.5,
              color: PosSettingsSpec.inkMuted(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberDetailsCard extends StatelessWidget {
  final TextEditingController nameController;
  final String? nameError;
  final ValueChanged<String> onNameChanged;
  final String role;
  final ValueChanged<String> onRoleChanged;
  final bool active;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback? onRemove;

  const _MemberDetailsCard({
    required this.nameController,
    required this.nameError,
    required this.onNameChanged,
    required this.role,
    required this.onRoleChanged,
    required this.active,
    required this.onActiveChanged,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      radius: 16,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PosSettingsTextField(
              label: 'Name',
              controller: nameController,
              onChanged: onNameChanged,
              errorText: nameError,
            ),
            const SizedBox(height: 12),
            PosSettingsDropdown(
              label: 'Role',
              value: role,
              options: PosStaffRoles.options,
              onChanged: onRoleChanged,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'STAFF STATUS',
                  style: loewExtraBold.copyWith(
                    fontSize: PosSettingsSpec.labelSize,
                    letterSpacing: PosSettingsSpec.labelTracking,
                    color: PosSettingsSpec.ink,
                  ),
                ),
                const Spacer(),
                _PosToggle(value: active, onChanged: onActiveChanged),
              ],
            ),
            if (onRemove != null) ...[
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onRemove,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB42318),
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Remove staff member',
                    style: loewBold.copyWith(fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  final Map<String, bool> permissions;
  final void Function(String key, bool value) onPermissionChanged;

  const _PermissionsCard({
    required this.permissions,
    required this.onPermissionChanged,
  });

  @override
  Widget build(BuildContext context) {
    const List<String> keys = PosStaffPermissions.keys;
    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PERMISSIONS',
              style: loewExtraBold.copyWith(
                fontSize: 12,
                color: PosSettingsSpec.ink,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < keys.length; i++)
              _PermissionRow(
                label: keys[i],
                value: permissions[keys[i]] ?? false,
                showDivider: i < keys.length - 1,
                onChanged: (v) => onPermissionChanged(keys[i], v),
              ),
          ],
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final String label;
  final bool value;
  final bool showDivider;
  final ValueChanged<bool> onChanged;

  const _PermissionRow({
    required this.label,
    required this.value,
    required this.showDivider,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(
                bottom: BorderSide(color: Color(0xFFF0EBD8)),
              )
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          top: 12,
          bottom: showDivider ? 12 : 0,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: loewMedium.copyWith(
                  fontSize: 13,
                  color: PosSettingsSpec.ink,
                ),
              ),
            ),
            _PosToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

// ── Dialogs ─────────────────────────────────────────────────────────────────

/// What [_AddStaffDialog] hands back — nothing is written until the panel
/// applies it, so a cancelled dialog leaves the roster untouched.
class _NewStaff {
  final String name;
  final String role;
  final List<String> shiftIds;

  const _NewStaff({
    required this.name,
    required this.role,
    required this.shiftIds,
  });
}

class _AddStaffDialog extends StatefulWidget {
  final List<PosStaffShift> shifts;

  /// Shifts pre-selected when the dialog opens. Header hire defaults to
  /// Morning; a shift-row "+ Add" passes that shift alone.
  final Set<String> initialShiftIds;

  const _AddStaffDialog({
    required this.shifts,
    this.initialShiftIds = const {PosStaffShift.morning},
  });

  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final TextEditingController _name = TextEditingController();
  late final Set<String> _shiftIds = Set<String>.from(
    widget.initialShiftIds.isEmpty
        ? const {PosStaffShift.morning}
        : widget.initialShiftIds,
  );
  String _role = PosStaffRoles.employee;
  String? _error;
  String? _shiftError;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _toggleShift(String id) {
    setState(() {
      if (_shiftIds.contains(id)) {
        // Keep at least one shift selected — shifts are compulsory.
        if (_shiftIds.length == 1) {
          _shiftError = 'Select at least one shift';
          return;
        }
        _shiftIds.remove(id);
      } else {
        _shiftIds.add(id);
      }
      _shiftError = null;
    });
  }

  void _submit() {
    final String? error = PosStaffValidation.name(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    if (_shiftIds.isEmpty) {
      setState(() => _shiftError = 'Select at least one shift');
      return;
    }
    Navigator.of(context).pop(
      _NewStaff(
        name: _name.text.trim(),
        role: _role,
        shiftIds: _shiftIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _DialogFrame(
      title: 'ADD STAFF MEMBER',
      subtitle: 'They can be rostered onto a shift right away.',
      onConfirm: _submit,
      confirmLabel: 'Add Member',
      children: [
        PosSettingsTextField(
          label: 'Name',
          controller: _name,
          errorText: _error,
          textInputAction: TextInputAction.done,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: 12),
        PosSettingsDropdown(
          label: 'Role',
          value: _role,
          options: PosStaffRoles.options,
          onChanged: (v) => setState(() => _role = v),
        ),
        const SizedBox(height: 16),
        Text(
          'SHIFTS',
          style: loewExtraBold.copyWith(
            fontSize: PosSettingsSpec.labelSize,
            letterSpacing: PosSettingsSpec.labelTracking,
            color: PosSettingsSpec.ink,
          ),
        ),
        const SizedBox(height: PosSettingsSpec.labelGap),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final PosStaffShift shift in widget.shifts)
              _SelectableChip(
                label: shift.name,
                selected: _shiftIds.contains(shift.id),
                onTap: () => _toggleShift(shift.id),
              ),
          ],
        ),
        if (_shiftError != null) ...[
          const SizedBox(height: 8),
          Text(
            _shiftError!,
            style: loewRegular.copyWith(
              fontSize: 12,
              color: const Color(0xFFB42318),
            ),
          ),
        ],
      ],
    );
  }
}

/// Multi-select picker used by "+ Add" on a shift row. Returns the chosen ids.
class _PickStaffDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<PosStaffMember> candidates;

  const _PickStaffDialog({
    required this.title,
    required this.subtitle,
    required this.candidates,
  });

  @override
  State<_PickStaffDialog> createState() => _PickStaffDialogState();
}

class _PickStaffDialogState extends State<_PickStaffDialog> {
  final Set<String> _picked = <String>{};

  @override
  Widget build(BuildContext context) {
    final bool empty = widget.candidates.isEmpty;
    return _DialogFrame(
      title: widget.title.toUpperCase(),
      subtitle: empty
          ? 'Everyone on the team is already on this shift.'
          : widget.subtitle,
      confirmLabel: 'Add ${_picked.length}',
      onConfirm: _picked.isEmpty
          ? null
          : () => Navigator.of(context).pop(_picked.toList()),
      children: [
        if (empty)
          Text(
            'Add a new team member first, then roster them here.',
            style: loewRegular.copyWith(
              fontSize: 13,
              color: PosSettingsSpec.inkMuted(),
            ),
          )
        else
          for (final PosStaffMember m in widget.candidates)
            _PickRow(
              member: m,
              selected: _picked.contains(m.id),
              onTap: () => setState(() {
                if (!_picked.remove(m.id)) _picked.add(m.id);
              }),
            ),
      ],
    );
  }
}

class _PickRow extends StatelessWidget {
  final PosStaffMember member;
  final bool selected;
  final VoidCallback onTap;

  const _PickRow({
    required this.member,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              _CheckBox(value: selected),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: loewBold.copyWith(
                    fontSize: 14,
                    color: PosSettingsSpec.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _CreamChip(label: member.role, fontSize: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// The full roster of one shift — what the "+N more" chip opens. Rostering is
/// live here, so removals apply as they are tapped rather than on a confirm.
class _ShiftRosterDialog extends StatelessWidget {
  final String shiftId;

  const _ShiftRosterDialog({required this.shiftId});

  @override
  Widget build(BuildContext context) {
    final PosStaffProvider provider = context.watch<PosStaffProvider>();
    final PosStaffShift? shift = provider.roster.shiftById(shiftId);
    if (shift == null) return const SizedBox.shrink();
    final List<PosStaffMember> members = provider.membersOf(shiftId);

    return _DialogFrame(
      title: '${shift.name.toUpperCase()} SHIFT',
      subtitle: '${shift.time} · ${members.length} on shift',
      confirmLabel: 'Done',
      onConfirm: () => Navigator.of(context).pop(),
      children: [
        if (members.isEmpty)
          Text(
            'No one is rostered onto this shift yet.',
            style: loewRegular.copyWith(
              fontSize: 13,
              color: PosSettingsSpec.inkMuted(),
            ),
          )
        else
          for (final PosStaffMember m in members)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: loewBold.copyWith(
                        fontSize: 14,
                        color: PosSettingsSpec.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _CreamChip(label: m.role, fontSize: 12),
                  const SizedBox(width: 8),
                  _RemoveButton(
                    tooltip: 'Remove ${m.shortName} from ${shift.name}',
                    onTap: () => provider.removeFromShift(shiftId, m.id),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

/// Shared dialog chrome — cream card, ink title, cancel + confirm.
class _DialogFrame extends StatelessWidget {
  final String title;
  final String subtitle;
  final String confirmLabel;
  final VoidCallback? onConfirm;
  final List<Widget> children;

  const _DialogFrame({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.onConfirm,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: PosSettingsSpec.panelBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: PosSettingsSpec.fieldBorder),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: loewExtraBold.copyWith(
                  fontSize: 18,
                  color: PosSettingsSpec.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: loewRegular.copyWith(
                  fontSize: 13,
                  color: PosSettingsSpec.inkMuted(),
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogButton(
                    label: 'Cancel',
                    filled: false,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 8),
                  _DialogButton(
                    label: confirmLabel,
                    filled: true,
                    onPressed: onConfirm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  const _DialogButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: enabled ? 1 : 0.45,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: filled ? PosSettingsSpec.ink : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PosSettingsSpec.fieldBorder),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Text(
                label,
                style: loewBold.copyWith(
                  fontSize: 13,
                  color: filled ? Colors.white : PosSettingsSpec.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared chrome ───────────────────────────────────────────────────────────

/// The white, hairline-bordered card every block on this screen sits in.
class _Card extends StatelessWidget {
  final Widget child;
  final double radius;

  const _Card({required this.child, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: PosSettingsSpec.fieldBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            offset: Offset(0, 2),
            blurRadius: 10,
            spreadRadius: -4,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _HeaderCell {
  final String label;
  final double? width;
  final int? flex;

  const _HeaderCell(this.label, {this.width, this.flex});
}

class _TableHeader extends StatelessWidget {
  final List<_HeaderCell> columns;

  const _TableHeader({required this.columns});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: PosSettingsSpec.pageBg,
        border: Border(
          bottom: BorderSide(color: Color(0xFFF0EBD8)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          children: [
            for (final col in columns)
              if (col.flex != null)
                Expanded(
                  flex: col.flex!,
                  child: Text(
                    col.label,
                    style: loewExtraBold.copyWith(
                      fontSize: 12,
                      color: PosSettingsSpec.inkMuted(),
                      letterSpacing: 0.3,
                    ),
                  ),
                )
              else
                SizedBox(
                  width: col.width,
                  child: Text(
                    col.label,
                    style: loewExtraBold.copyWith(
                      fontSize: 12,
                      color: PosSettingsSpec.inkMuted(),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _InkPill extends StatelessWidget {
  final String label;

  const _InkPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosSettingsSpec.ink,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PosSettingsSpec.fieldBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: loewBold.copyWith(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _CreamChip extends StatelessWidget {
  final String label;
  final double fontSize;
  final VoidCallback? onTap;

  const _CreamChip({
    required this.label,
    this.fontSize = 13,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget chip = DecoratedBox(
      decoration: BoxDecoration(
        color: PosSettingsSpec.pageBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PosSettingsSpec.fieldBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          label,
          style: loewBold.copyWith(
            fontSize: fontSize,
            color: PosSettingsSpec.ink,
          ),
        ),
      ),
    );
    if (onTap == null) return chip;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: chip),
    );
  }
}

/// Outline "+ Add" pill that opens the hire dialog for that shift.
class _AddChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: PosSettingsSpec.ink),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add, size: 14, color: PosSettingsSpec.ink),
                  const SizedBox(width: 4),
                  Text(
                    'Add',
                    style: loewBold.copyWith(
                      fontSize: 13,
                      color: PosSettingsSpec.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectableChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? PosSettingsSpec.ink : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? PosSettingsSpec.ink
                  : PosSettingsSpec.fieldBorder,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(
              label,
              style: loewBold.copyWith(
                fontSize: 13,
                color: selected ? Colors.white : PosSettingsSpec.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  final bool value;

  const _CheckBox({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: value ? PosSettingsSpec.ink : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: value ? PosSettingsSpec.ink : PosSettingsSpec.fieldBorder,
        ),
      ),
      child: value
          ? const Icon(Icons.check, size: 14, color: Colors.white)
          : null,
    );
  }
}

class _RemoveButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;

  const _RemoveButton({required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: PosSettingsSpec.fieldBorder),
            ),
            child: Icon(
              Icons.close,
              size: 15,
              color: PosSettingsSpec.inkMuted(0.8),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;

  const _StatusDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF3D9A5F) : const Color(0xFFB7B2A3),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          active ? 'Active' : 'Inactive',
          style: loewRegular.copyWith(
            fontSize: 13,
            color:
                active ? PosSettingsSpec.ink : PosSettingsSpec.inkMuted(),
          ),
        ),
      ],
    );
  }
}

/// Figma toggle — 44×24 track, ink when on.
class _PosToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PosToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const double width = 44;
    const double height = 24;
    const double thumb = 18;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onChanged(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: width,
          height: height,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: value ? PosSettingsSpec.ink : const Color(0xFFE3DFD3),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: thumb,
              height: thumb,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
