import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_text_field.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// Settings → STAFF (Figma **1641:8484**).
///
/// Pixel-faithful UI shell. Roster / shifts / permissions are local design
/// fixtures so the screen matches Figma; wire real APIs later.
class PosStaffSettingsPanel extends StatefulWidget {
  const PosStaffSettingsPanel({super.key});

  static const String pageTitle = 'STAFF';
  static const String pageSubtitle =
      'Manage team members, roles and permissions';

  @override
  State<PosStaffSettingsPanel> createState() => _PosStaffSettingsPanelState();
}

class _PosStaffSettingsPanelState extends State<PosStaffSettingsPanel> {
  late final TextEditingController _name;
  late String _selectedId;
  late String _role;
  late bool _active;
  late Map<String, bool> _permissions;

  static const List<PosSettingsOption> _roleOptions = [
    PosSettingsOption(value: 'Owner', label: 'Owner'),
    PosSettingsOption(value: 'Manager', label: 'Manager'),
    PosSettingsOption(value: 'Employee', label: 'Employee'),
  ];

  static const List<String> _permissionKeys = [
    'Process refunds',
    'Apply discounts',
    'Void orders',
    'Access reports',
    'Manage inventory',
    'Access cash drawer',
    'Manage staff',
  ];

  @override
  void initState() {
    super.initState();
    _selectedId = _StaffFixtures.defaultSelectedId;
    final member = _StaffFixtures.memberById(_selectedId)!;
    _name = TextEditingController(text: member.name);
    _role = member.role;
    _active = member.active;
    _permissions = Map<String, bool>.from(member.permissions);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _selectMember(String id) {
    if (id == _selectedId) return;
    final member = _StaffFixtures.memberById(id);
    if (member == null) return;
    setState(() {
      _selectedId = id;
      _name.text = member.name;
      _role = member.role;
      _active = member.active;
      _permissions = Map<String, bool>.from(member.permissions);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StaffHeader(onAdd: () {}),
        const SizedBox(height: 32),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool wide =
                  constraints.maxWidth >= PosSettingsSpec.wideBreakpoint;
              final Widget left = _LeftColumn(
                selectedId: _selectedId,
                onSelect: _selectMember,
              );
              final Widget right = _RightColumn(
                nameController: _name,
                role: _role,
                roleOptions: _roleOptions,
                onRoleChanged: (v) => setState(() => _role = v),
                active: _active,
                onActiveChanged: (v) => setState(() => _active = v),
                permissions: _permissions,
                permissionKeys: _permissionKeys,
                onPermissionChanged: (key, value) {
                  setState(() => _permissions[key] = value);
                },
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
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _LeftColumn({
    required this.selectedId,
    required this.onSelect,
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
        const _ShiftsCard(),
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
          selectedId: selectedId,
          onSelect: onSelect,
        ),
      ],
    );
  }
}

class _ShiftsCard extends StatelessWidget {
  const _ShiftsCard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: Column(
        children: [
          const _TableHeader(columns: [
            _HeaderCell('SHIFT', width: 220),
            _HeaderCell('TIME', width: 160),
            _HeaderCell('STAFF', flex: 1),
          ]),
          for (int i = 0; i < _StaffFixtures.shifts.length; i++) ...[
            _ShiftRow(
              shift: _StaffFixtures.shifts[i],
              showDivider: i < _StaffFixtures.shifts.length - 1,
            ),
          ],
        ],
      ),
    );
  }
}

class _ShiftRow extends StatelessWidget {
  final _ShiftFixture shift;
  final bool showDivider;

  const _ShiftRow({
    required this.shift,
    required this.showDivider,
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
                names: shift.staffNames,
                visibleCount: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffChipRow extends StatelessWidget {
  final List<String> names;
  final int visibleCount;

  const _StaffChipRow({
    required this.names,
    required this.visibleCount,
  });

  @override
  Widget build(BuildContext context) {
    final int shown = names.length < visibleCount ? names.length : visibleCount;
    final int overflow = names.length - shown;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < shown; i++) _CreamChip(label: names[i]),
        if (overflow > 0) _CreamChip(label: '+$overflow more'),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  final String selectedId;
  final ValueChanged<String> onSelect;

  const _TeamCard({
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
      child: Column(
        children: [
          const _TableHeader(columns: [
            _HeaderCell('NAME', width: 220),
            _HeaderCell('ROLE', width: 120),
            _HeaderCell('STATUS', width: 100),
          ]),
          for (int i = 0; i < _StaffFixtures.team.length; i++) ...[
            _TeamRow(
              member: _StaffFixtures.team[i],
              selected: _StaffFixtures.team[i].id == selectedId,
              showDivider: i < _StaffFixtures.team.length - 1,
              onTap: () => onSelect(_StaffFixtures.team[i].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeamRow extends StatelessWidget {
  final _MemberFixture member;
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
                  child: _StatusDot(
                    active: member.active,
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

// ── Right column ────────────────────────────────────────────────────────────

class _RightColumn extends StatelessWidget {
  final TextEditingController nameController;
  final String role;
  final List<PosSettingsOption> roleOptions;
  final ValueChanged<String> onRoleChanged;
  final bool active;
  final ValueChanged<bool> onActiveChanged;
  final Map<String, bool> permissions;
  final List<String> permissionKeys;
  final void Function(String key, bool value) onPermissionChanged;

  const _RightColumn({
    required this.nameController,
    required this.role,
    required this.roleOptions,
    required this.onRoleChanged,
    required this.active,
    required this.onActiveChanged,
    required this.permissions,
    required this.permissionKeys,
    required this.onPermissionChanged,
  });

  @override
  Widget build(BuildContext context) {
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
          _MemberDetailsCard(
            nameController: nameController,
            role: role,
            roleOptions: roleOptions,
            onRoleChanged: onRoleChanged,
            active: active,
            onActiveChanged: onActiveChanged,
          ),
          const SizedBox(height: 24),
          _PermissionsCard(
            permissions: permissions,
            permissionKeys: permissionKeys,
            onPermissionChanged: onPermissionChanged,
          ),
          const SizedBox(height: 16),
          Text(
            'Restricted actions on POS will prompt a manager override passcode.',
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
  final String role;
  final List<PosSettingsOption> roleOptions;
  final ValueChanged<String> onRoleChanged;
  final bool active;
  final ValueChanged<bool> onActiveChanged;

  const _MemberDetailsCard({
    required this.nameController,
    required this.role,
    required this.roleOptions,
    required this.onRoleChanged,
    required this.active,
    required this.onActiveChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosSettingsSpec.fieldBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PosSettingsTextField(
              label: 'Name',
              controller: nameController,
            ),
            const SizedBox(height: 12),
            PosSettingsDropdown(
              label: 'Role',
              value: role,
              options: roleOptions,
              onChanged: onRoleChanged,
            ),
            const SizedBox(height: 12),
            Text(
              'POS ACCESS PASSCODE',
              style: loewExtraBold.copyWith(
                fontSize: PosSettingsSpec.labelSize,
                letterSpacing: PosSettingsSpec.labelTracking,
                color: PosSettingsSpec.ink,
              ),
            ),
            const SizedBox(height: PosSettingsSpec.labelGap),
            Row(
              children: [
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        PosSettingsSpec.fieldRadius,
                      ),
                      border: Border.all(color: PosSettingsSpec.fieldBorder),
                    ),
                    child: Padding(
                      padding: PosSettingsSpec.fieldPadding,
                      child: Text(
                        '****',
                        style: loewBold.copyWith(
                          fontSize: PosSettingsSpec.fieldTextSize,
                          color: PosSettingsSpec.ink,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _GenerateButton(onPressed: () {}),
              ],
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
                _PosToggle(
                  value: active,
                  onChanged: onActiveChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GenerateButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _GenerateButton({required this.onPressed});

  @override
  State<_GenerateButton> createState() => _GenerateButtonState();
}

class _GenerateButtonState extends State<_GenerateButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: PosSettingsSpec.fieldBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                'Generate',
                style: loewBold.copyWith(
                  fontSize: 13,
                  color: PosSettingsSpec.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  final Map<String, bool> permissions;
  final List<String> permissionKeys;
  final void Function(String key, bool value) onPermissionChanged;

  const _PermissionsCard({
    required this.permissions,
    required this.permissionKeys,
    required this.onPermissionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PosSettingsSpec.fieldBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            offset: Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
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
            for (int i = 0; i < permissionKeys.length; i++) ...[
              _PermissionRow(
                label: permissionKeys[i],
                value: permissions[permissionKeys[i]] ?? false,
                showDivider: i < permissionKeys.length - 1,
                onChanged: (v) => onPermissionChanged(permissionKeys[i], v),
              ),
            ],
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

// ── Shared chrome ───────────────────────────────────────────────────────────

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

  const _CreamChip({
    required this.label,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
            color: active
                ? PosSettingsSpec.ink
                : PosSettingsSpec.inkMuted(),
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

// ── Design fixtures (UI only — replace with real APIs later) ────────────────

class _ShiftFixture {
  final String name;
  final String time;
  final List<String> staffNames;

  const _ShiftFixture({
    required this.name,
    required this.time,
    required this.staffNames,
  });
}

class _MemberFixture {
  final String id;
  final String name;
  final String role;
  final bool active;
  final Map<String, bool> permissions;

  const _MemberFixture({
    required this.id,
    required this.name,
    required this.role,
    required this.active,
    required this.permissions,
  });
}

class _StaffFixtures {
  static const String defaultSelectedId = 'thomas';

  static const List<_ShiftFixture> shifts = [
    _ShiftFixture(
      name: 'Morning',
      time: '08:00-14:00',
      staffNames: [
        'Maria',
        'Sophie',
        'Liam',
        'Eva',
        'Noah',
        'Olivia',
        'Lucas',
        'Mila',
        'Finn',
        'Sara',
        'Jesse',
        'Nina',
      ],
    ),
    _ShiftFixture(
      name: 'Afternoon',
      time: '14:00-20:00',
      staffNames: [
        'Thomas',
        'Liam',
        'Ava',
        'Emma',
        'Noah',
        'Sophie',
        'Lucas',
        'Mila',
        'Finn',
        'Sara',
        'Jesse',
      ],
    ),
    _ShiftFixture(
      name: 'Evening',
      time: '20:00-22:00',
      staffNames: [
        'Maria',
        'Thomas',
        'Noah',
        'Liam',
        'Sophie',
        'Ava',
        'Emma',
        'Olivia',
        'Lucas',
        'Mila',
        'Finn',
        'Sara',
        'Jesse',
      ],
    ),
  ];

  static const Map<String, bool> _managerPerms = {
    'Process refunds': true,
    'Apply discounts': true,
    'Void orders': false,
    'Access reports': true,
    'Manage inventory': true,
    'Access cash drawer': true,
    'Manage staff': false,
  };

  static const Map<String, bool> _ownerPerms = {
    'Process refunds': true,
    'Apply discounts': true,
    'Void orders': true,
    'Access reports': true,
    'Manage inventory': true,
    'Access cash drawer': true,
    'Manage staff': true,
  };

  static const Map<String, bool> _employeePerms = {
    'Process refunds': false,
    'Apply discounts': true,
    'Void orders': false,
    'Access reports': false,
    'Manage inventory': false,
    'Access cash drawer': true,
    'Manage staff': false,
  };

  static const List<_MemberFixture> team = [
    _MemberFixture(
      id: 'maria',
      name: 'Maria van den Berg',
      role: 'Owner',
      active: true,
      permissions: _ownerPerms,
    ),
    _MemberFixture(
      id: 'thomas',
      name: 'Thomas de Vries',
      role: 'Manager',
      active: true,
      permissions: _managerPerms,
    ),
    _MemberFixture(
      id: 'sophie',
      name: 'Sophie Jansen',
      role: 'Employee',
      active: true,
      permissions: _employeePerms,
    ),
    _MemberFixture(
      id: 'liam',
      name: 'Liam Bakker',
      role: 'Employee',
      active: true,
      permissions: _employeePerms,
    ),
    _MemberFixture(
      id: 'emma',
      name: 'Emma Visser',
      role: 'Employee',
      active: false,
      permissions: _employeePerms,
    ),
  ];

  static _MemberFixture? memberById(String id) {
    for (final m in team) {
      if (m.id == id) return m;
    }
    return null;
  }
}
