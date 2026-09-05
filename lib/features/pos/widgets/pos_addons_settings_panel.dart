import 'package:acafe_customer/features/kiosk/providers/kiosk_manager_provider.dart';
import 'package:acafe_customer/features/pos/domain/pos_addons_settings_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_search_field.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_availability_list.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Settings → ADD-ONS (Figma **1641:4088**).
///
/// Drives `add_ons.status`, which the customer payload now filters on
/// (`Helpers::product_data_formatting` / `build_addon_groups`), so hiding an
/// add-on here removes it from live products on the kiosk and the customer web
/// app immediately rather than at the next product save.
///
/// Shares its card and rows with Settings → Products via
/// [PosSettingsAvailabilityCard]; only the copy and the data source differ.
///
/// This screen never touches the Default Add-on feature. It reads two computed
/// fields the endpoint returns — `default_product_count` and
/// `blocks_required_group` — purely to warn or refuse at the point of the tap.
class PosAddonsSettingsPanel extends StatefulWidget {
  const PosAddonsSettingsPanel({super.key});

  static const String pageTitle = 'ADD-ONS';
  static const String pageSubtitle =
      'Configure which add-ons are available on customer kiosks';
  static const String searchHint = 'Search by add-on name...';

  @override
  State<PosAddonsSettingsPanel> createState() => _PosAddonsSettingsPanelState();
}

class _PosAddonsSettingsPanelState extends State<PosAddonsSettingsPanel> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<KioskManagerProvider>().loadAllAddonsWithCache();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    final String next = value.trim().toLowerCase();
    if (next == _query) return;
    setState(() => _query = next);
  }

  /// Figma's hint says name, but the SKU is on screen right under it, so a
  /// manager reading one off a shelf label expects it to match. Every term
  /// must hit, so a second word narrows rather than widens.
  bool _matches(Map<String, dynamic> addon) {
    if (_query.isEmpty) return true;

    final String haystack = [
      addon['name'],
      addon['sku'],
    ].whereType<Object>().join(' ').toLowerCase();

    return _query
        .split(RegExp(r'\s+'))
        .every((String term) => haystack.contains(term));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AddonsHeader(),
        const SizedBox(height: PosAddonsSettingsSpec.sectionGap),
        PosSearchField(
          controller: _search,
          onChanged: _onQueryChanged,
          hintText: PosAddonsSettingsPanel.searchHint,
          style: PosSearchFieldStyle.settings,
        ),
        const SizedBox(height: PosAddonsSettingsSpec.sectionGap),
        Expanded(
          child: Selector<KioskManagerProvider, _AddonListShape>(
            // Visible-row identity only, never toggle state -- flipping one
            // add-on cannot rebuild the whole list.
            selector: (_, provider) => _AddonListShape(
              ids: provider.addons
                  .where(_matches)
                  .map<int>((a) => (a['id'] as num).toInt())
                  .toList(growable: false),
              loading: provider.addonsLoading && provider.addons.isEmpty,
            ),
            builder: (context, shape, __) {
              return PosSettingsAvailabilityCard(
                ids: shape.ids,
                loading: shape.loading,
                query: _search.text.trim(),
                emptyMessage: 'No add-ons in this branch catalogue yet.',
                noMatchMessage: (String query) => 'Nothing matches “$query”.',
                rowBuilder: (context, id, showDivider) => _AddonRow(
                  key: ValueKey<int>(id),
                  addonId: id,
                  showDivider: showDivider,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Visible-row identity for the list-level selector.
@immutable
class _AddonListShape {
  final List<int> ids;
  final bool loading;

  const _AddonListShape({required this.ids, required this.loading});

  @override
  bool operator ==(Object other) =>
      other is _AddonListShape &&
      other.loading == loading &&
      listEquals(other.ids, ids);

  @override
  int get hashCode => Object.hash(loading, Object.hashAll(ids));
}

// ── Header ──────────────────────────────────────────────────────────────────

class _AddonsHeader extends StatelessWidget {
  const _AddonsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          PosAddonsSettingsPanel.pageTitle,
          style: loewExtraBold.copyWith(
            fontSize: PosSettingsSpec.titleSize,
            color: PosSettingsSpec.ink,
            height: 1.1,
          ),
        ),
        const SizedBox(height: PosSettingsSpec.headerGap),
        Text(
          PosAddonsSettingsPanel.pageSubtitle,
          style: loewRegular.copyWith(
            fontSize: PosSettingsSpec.subtitleSize,
            color: PosSettingsSpec.inkMuted(),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ── Row ─────────────────────────────────────────────────────────────────────

/// Reads its own add-on out of the provider, so a toggle repaints one row.
class _AddonRow extends StatelessWidget {
  final int addonId;
  final bool showDivider;

  const _AddonRow({
    super.key,
    required this.addonId,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Selector<KioskManagerProvider, _AddonRowState>(
      selector: (_, provider) {
        final Map<String, dynamic> addon = provider.addons.firstWhere(
          (a) => (a['id'] as num?)?.toInt() == addonId,
          orElse: () => const <String, dynamic>{},
        );
        return _AddonRowState(
          name: addon['name']?.toString() ?? '',
          sku: addon['sku']?.toString() ?? '',
          image: addon['image_full_path']?.toString() ?? '',
          price: (addon['price'] as num?)?.toDouble() ?? 0,
          available: addon['is_available'] == true,
          busy: provider.isTogglingAddon(addonId),
          defaultProductCount:
              (addon['default_product_count'] as num?)?.toInt() ?? 0,
          blocksRequiredGroup: addon['blocks_required_group'] == true,
          groupName: addon['group_name']?.toString() ?? '',
        );
      },
      builder: (context, state, __) {
        return PosSettingsAvailabilityRow(
          name: state.name,
          subLabel: state.sku,
          image: state.image,
          price: state.price,
          available: state.available,
          busy: state.busy,
          showDivider: showDivider,
          // A default add-on is free, and "€ 0.00" reads as a price where
          // "€ 00.00" reads as a glitch.
          padZeroPrice: false,
          onChanged: (bool next) => _onToggle(context, state, next),
        );
      },
    );
  }

  /// Turning an add-on ON is always immediate. Turning one OFF is gated:
  /// refused outright when it would leave a required group unsatisfiable,
  /// confirmed when it is a default that live products currently include.
  Future<void> _onToggle(
    BuildContext context,
    _AddonRowState state,
    bool next,
  ) async {
    final provider = context.read<KioskManagerProvider>();

    if (!next) {
      if (state.blocksRequiredGroup) {
        await _showRefusal(context, state);
        return;
      }

      if (state.defaultProductCount > 0) {
        final bool confirmed = await _confirmHideDefault(context, state);
        // Cancel reverts with no request sent -- the toggle never moved,
        // because the optimistic write lives in the provider, not here.
        if (!confirmed) return;
      }
    }

    if (!context.mounted) return;
    final String? refusal =
        await provider.toggleAddonAvailability(addonId, next);

    // The server re-checks the required-group rule, so a stale client that
    // got past the local gate is still stopped here.
    if (refusal != null) {
      showCustomSnackBarHelper(refusal);
    }
  }

  Future<void> _showRefusal(BuildContext context, _AddonRowState state) {
    final String group =
        state.groupName.isEmpty ? 'its group' : '“${state.groupName}”';

    return _showDialog(
      context: context,
      title: 'Cannot hide this add-on',
      body: '$group requires a selection, and hiding “${state.name}” would '
          'leave it with none. Add another option to that group first.',
      confirmLabel: null,
    );
  }

  Future<bool> _confirmHideDefault(
    BuildContext context,
    _AddonRowState state,
  ) async {
    final int count = state.defaultProductCount;
    final String products = count == 1 ? '1 product' : '$count products';

    final bool? result = await _showDialog(
      context: context,
      title: 'Hide a default add-on?',
      body: 'This add-on is included by default on $products. Hiding it '
          'removes it from those products on customer kiosks.',
      confirmLabel: 'Hide add-on',
    );

    return result == true;
  }
}

/// One dialog for both the warning and the refusal — a null [confirmLabel]
/// makes it an acknowledgement with no destructive action.
Future<bool?> _showDialog({
  required BuildContext context,
  required String title,
  required String body,
  required String? confirmLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: PosSettingsSpec.panelBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PosSettingsSpec.fieldRadius),
      ),
      title: Text(
        title,
        style: loewExtraBold.copyWith(
          fontSize: PosAddonsSettingsSpec.dialogTitleSize,
          color: PosSettingsSpec.ink,
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: PosAddonsSettingsSpec.dialogMaxWidth,
        ),
        child: Text(
          body,
          style: loewRegular.copyWith(
            fontSize: PosAddonsSettingsSpec.dialogBodySize,
            color: PosSettingsSpec.inkMuted(),
            height: 1.4,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(
            confirmLabel == null ? 'OK' : 'Cancel',
            style: loewBold.copyWith(color: PosSettingsSpec.inkMuted()),
          ),
        ),
        if (confirmLabel != null)
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              confirmLabel,
              style: loewBold.copyWith(color: PosSettingsSpec.ink),
            ),
          ),
      ],
    ),
  );
}

/// Per-row slice of provider state.
@immutable
class _AddonRowState {
  final String name;
  final String sku;
  final String image;
  final double price;
  final bool available;
  final bool busy;
  final int defaultProductCount;
  final bool blocksRequiredGroup;
  final String groupName;

  const _AddonRowState({
    required this.name,
    required this.sku,
    required this.image,
    required this.price,
    required this.available,
    required this.busy,
    required this.defaultProductCount,
    required this.blocksRequiredGroup,
    required this.groupName,
  });

  @override
  bool operator ==(Object other) =>
      other is _AddonRowState &&
      other.name == name &&
      other.sku == sku &&
      other.image == image &&
      other.price == price &&
      other.available == available &&
      other.busy == busy &&
      other.defaultProductCount == defaultProductCount &&
      other.blocksRequiredGroup == blocksRequiredGroup &&
      other.groupName == groupName;

  @override
  int get hashCode => Object.hash(name, sku, image, price, available, busy,
      defaultProductCount, blocksRequiredGroup, groupName);
}
