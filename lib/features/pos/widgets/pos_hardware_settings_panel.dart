import 'dart:async';

import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/providers/pos_hardware_settings_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_preview_card.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_pill.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_save_button.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_text_field.dart';
import 'package:acafe_customer/features/pos/widgets/pos_toggle.dart';
import 'package:acafe_customer/helper/custom_snackbar_helper.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Settings → Hardware form body (Figma 1641:8685).
///
/// Batch form with a Live Preview, so it follows General's Save Changes
/// pattern — draft/saved/dirty/validate/persist — rather than Products'
/// per-toggle auto-save. Header, footer, prefix and the store name feed the
/// preview live, before Save is pressed.
class PosHardwareSettingsPanel extends StatefulWidget {
  /// Test seam: pins the preview's clock so a golden ticket is stable.
  final DateTime? now;

  const PosHardwareSettingsPanel({super.key, this.now});

  @override
  State<PosHardwareSettingsPanel> createState() =>
      _PosHardwareSettingsPanelState();
}

class _PosHardwareSettingsPanelState extends State<PosHardwareSettingsPanel> {
  late final TextEditingController _prefix;
  late final TextEditingController _header;
  late final TextEditingController _footer;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _prefix = TextEditingController();
    _header = TextEditingController();
    _footer = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    final PosHardwareSettingsProvider provider =
        context.read<PosHardwareSettingsProvider>();
    final PosHardwareSettings draft = provider.draft;
    _prefix.text = draft.orderNumberPrefix;
    _header.text = draft.effectiveHeader(provider.storeName);
    _footer.text = draft.receiptFooter;
    _seeded = true;
  }

  @override
  void dispose() {
    _prefix.dispose();
    _header.dispose();
    _footer.dispose();
    super.dispose();
  }

  /// The header field is disabled while "Use store name" is on and mirrors the
  /// live store name, so the controller has to be pushed back into sync when
  /// the toggle flips — the provider owns the value, not the controller.
  void _onUseStoreName(bool value) {
    final PosHardwareSettingsProvider provider =
        context.read<PosHardwareSettingsProvider>();
    provider.setUseStoreName(value);
    final String next = provider.draft.effectiveHeader(provider.storeName);
    if (_header.text != next) {
      _header.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  Future<void> _onSave() async {
    final PosHardwareSettingsProvider provider =
        context.read<PosHardwareSettingsProvider>();
    final bool ok = await provider.save();
    if (!mounted) return;

    if (ok) {
      showCustomSnackBarHelper('Settings saved', isError: false);
    } else if (provider.errors.isNotEmpty) {
      showCustomSnackBarHelper(provider.errors.values.first, isError: true);
    } else {
      showCustomSnackBarHelper('Could not save settings', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final PosHardwareSettingsProvider provider =
        context.watch<PosHardwareSettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hardware',
                    style: loewExtraBold.copyWith(
                      fontSize: PosSettingsSpec.titleSize,
                      color: PosSettingsSpec.ink,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: PosSettingsSpec.headerGap),
                  Text(
                    'Printer, receipt format, and device preferences',
                    style: loewRegular.copyWith(
                      fontSize: PosSettingsSpec.subtitleSize,
                      color: PosSettingsSpec.inkMuted(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            PosSettingsSaveButton(
              loading: provider.isSaving,
              dirty: provider.isDirty,
              onPressed: _onSave,
            ),
          ],
        ),
        const SizedBox(height: PosSettingsSpec.sectionGap),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool twoColumn = constraints.maxWidth >=
                  PosHardwareSpec.twoColumnBreakpoint;

              final Widget form = _FormColumn(
                prefix: _prefix,
                header: _header,
                footer: _footer,
                onUseStoreName: _onUseStoreName,
              );
              final Widget preview = _DebouncedPreview(now: widget.now);

              if (!twoColumn) {
                // Stacked: one scroll view owns both, so the preview is
                // reachable on a tablet instead of being squeezed off-screen.
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      form,
                      const SizedBox(height: PosHardwareSpec.blockGap),
                      // A thermal ticket is a fixed-width object. Letting it
                      // stretch across the whole form column when stacked
                      // would stop looking like the thing it previews.
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: PosHardwareSpec.previewColumnWidth,
                          ),
                          child: preview,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: form,
                      ),
                    ),
                  ),
                  const SizedBox(width: PosHardwareSpec.columnGap),
                  SizedBox(
                    width: PosHardwareSpec.previewColumnWidth,
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: preview,
                      ),
                    ),
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

/// Left column: Printer + Receipt Format.
class _FormColumn extends StatelessWidget {
  final TextEditingController prefix;
  final TextEditingController header;
  final TextEditingController footer;
  final ValueChanged<bool> onUseStoreName;

  const _FormColumn({
    required this.prefix,
    required this.header,
    required this.footer,
    required this.onUseStoreName,
  });

  @override
  Widget build(BuildContext context) {
    final PosHardwareSettingsProvider provider =
        context.watch<PosHardwareSettingsProvider>();
    final PosHardwareSettings draft = provider.draft;
    final Map<String, String> errors = provider.errors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _GroupHeading('Printer'),
        _ToggleRow(
          title: 'Auto-Print Receipts',
          subtitle:
              'Print raw receipt on thermal deck automatically after payment',
          value: draft.autoPrintReceipts,
          onChanged: provider.setAutoPrintReceipts,
        ),
        const SizedBox(height: PosHardwareSpec.toggleRowGap),
        _ToggleRow(
          title: 'Kitchen Ticket Printing',
          subtitle:
              'Route order items automatically to kitchen ticket printer on send',
          value: draft.kitchenTicketPrinting,
          onChanged: provider.setKitchenTicketPrinting,
          // The kitchen app is a display system with no printing code and no
          // automatic-vs-manual send concept, so this preference is stored but
          // nothing consumes it yet. Saying so beats a control that silently
          // does nothing.
          note: 'No kitchen printer is paired with this terminal yet — '
              'this preference is saved but has no effect until kitchen '
              'ticket printing is built.',
        ),
        const SizedBox(height: PosSettingsSpec.fieldGap),
        PosSettingsTextField(
          label: 'Order Number Prefix',
          controller: prefix,
          textInputAction: TextInputAction.next,
          errorText: errors['orderNumberPrefix'],
          onChanged: provider.setOrderNumberPrefix,
        ),
        const SizedBox(height: PosHardwareSpec.helperGap),
        _Helper('Preview: ${PosOrderNumber.preview(draft.orderNumberPrefix)}'),

        const SizedBox(height: PosHardwareSpec.blockGap),
        const Divider(color: PosSettingsSpec.divider, height: 1),
        const SizedBox(height: PosHardwareSpec.blockGap),

        const _GroupHeading('Receipt Format'),
        PosSettingsTextField(
          label: 'Receipt Header',
          controller: header,
          textInputAction: TextInputAction.next,
          errorText: errors['receiptHeader'],
          readOnly: draft.useStoreName,
          onChanged: provider.setReceiptHeader,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Use store name',
                style: loewMedium.copyWith(
                  fontSize: PosSettingsSpec.labelSize,
                  color: PosSettingsSpec.inkMuted(0.55),
                ),
              ),
              const SizedBox(width: 10),
              PosToggle(
                value: draft.useStoreName,
                onChanged: onUseStoreName,
                semanticLabel: 'Use store name',
              ),
            ],
          ),
        ),
        const SizedBox(height: PosSettingsSpec.fieldGap),
        PosSettingsTextField(
          label: 'Receipt Footer',
          controller: footer,
          textInputAction: TextInputAction.done,
          errorText: errors['receiptFooter'],
          onChanged: provider.setReceiptFooter,
        ),
        const SizedBox(height: PosHardwareSpec.blockGap),
        const _KioskLanguages(),
      ],
    );
  }
}

/// Multi-select language pills.
///
/// The Figma frame shows five pills plus a "Show more" link. Only four locales
/// are installed — `assets/language/{nl,en,fr,de}.json`, enforced by
/// `kiosk_languages_test` — and Japanese/Chinese/Korean have no translation
/// files anywhere in the product. So every installed language fits on screen
/// and there is nothing left for "Show more" to reveal; adding the link would
/// be an affordance that expands to nothing. It comes back the moment a fifth
/// locale ships.
class _KioskLanguages extends StatelessWidget {
  const _KioskLanguages();

  @override
  Widget build(BuildContext context) {
    final PosHardwareSettingsProvider provider =
        context.watch<PosHardwareSettingsProvider>();
    final String? error = provider.errors['kioskLanguages'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KIOSK LANGUAGES',
          style: loewBold.copyWith(
            fontSize: PosSettingsSpec.labelSize,
            letterSpacing: PosSettingsSpec.labelTracking,
            color: PosSettingsSpec.ink,
          ),
        ),
        const SizedBox(height: PosSettingsSpec.labelGap),
        Wrap(
          spacing: PosHardwareSpec.pillGap,
          runSpacing: PosHardwareSpec.pillGap,
          children: [
            for (final PosSettingsOption option
                in PosHardwareSettings.kioskLanguageOptions)
              PosSettingsPill(
                label: option.label,
                selected: provider.isKioskLanguageSelected(option.value),
                onTap: () => provider.toggleKioskLanguage(option.value),
              ),
          ],
        ),
        const SizedBox(height: PosHardwareSpec.helperGap),
        _Helper(
          error ??
              'Languages offered to customers at the kiosk. '
                  'Staff terminal language is set under Profile.',
          isError: error != null,
        ),
      ],
    );
  }
}

class _GroupHeading extends StatelessWidget {
  final String title;

  const _GroupHeading(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: PosHardwareSpec.groupGap),
      child: Text(
        title,
        style: loewBold.copyWith(
          fontSize: PosHardwareSpec.groupTitleSize,
          color: PosSettingsSpec.ink,
        ),
      ),
    );
  }
}

class _Helper extends StatelessWidget {
  final String text;
  final bool isError;

  const _Helper(this.text, {this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: loewRegular.copyWith(
        fontSize: PosHardwareSpec.helperSize,
        height: 1.35,
        color: isError
            ? const Color(0xFFB4544A)
            : PosSettingsSpec.inkMuted(0.5),
      ),
    );
  }
}

/// Bordered row: title + description on the left, [PosToggle] on the right.
class _ToggleRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  /// Rendered under the description when the preference has nothing behind it.
  final String? note;

  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: PosSettingsSpec.fieldFill,
        borderRadius: BorderRadius.circular(PosHardwareSpec.toggleRowRadius),
        border: Border.all(color: PosSettingsSpec.fieldBorder),
      ),
      child: Padding(
        padding: PosHardwareSpec.toggleRowPadding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: loewBold.copyWith(
                      fontSize: PosHardwareSpec.toggleTitleSize,
                      color: PosSettingsSpec.ink,
                    ),
                  ),
                  const SizedBox(height: PosHardwareSpec.toggleTextGap),
                  Text(
                    subtitle,
                    style: loewRegular.copyWith(
                      fontSize: PosHardwareSpec.toggleSubtitleSize,
                      height: 1.35,
                      color: PosSettingsSpec.inkMuted(0.55),
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      note!,
                      style: loewMedium.copyWith(
                        fontSize: PosHardwareSpec.helperSize,
                        height: 1.35,
                        color: const Color(0xFF8A6A2F),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            PosToggle(
              value: value,
              onChanged: onChanged,
              semanticLabel: title,
            ),
          ],
        ),
      ),
    );
  }
}

/// Repaints the preview a beat after typing stops.
///
/// The form itself stays instant — the controller and provider update on every
/// keystroke. Only the ticket, which is ~30 text runs deep, waits, so holding a
/// key down cannot make the field feel laggy.
class _DebouncedPreview extends StatefulWidget {
  final DateTime? now;

  const _DebouncedPreview({this.now});

  @override
  State<_DebouncedPreview> createState() => _DebouncedPreviewState();
}

class _DebouncedPreviewState extends State<_DebouncedPreview> {
  static const Duration _delay = Duration(milliseconds: 120);

  Timer? _timer;
  PosHardwareSettings? _shown;
  PosGeneralSettings? _general;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PosHardwareSettingsProvider provider =
        context.watch<PosHardwareSettingsProvider>();
    final PosHardwareSettings draft = provider.draft;
    _general = provider.general;

    // First build paints immediately; later changes coalesce.
    if (_shown == null) {
      _shown = draft;
    } else if (!draft.sameAs(_shown!)) {
      _timer?.cancel();
      _timer = Timer(_delay, () {
        if (!mounted) return;
        setState(() => _shown = provider.draft);
      });
    }

    return PosReceiptPreviewCard(
      settings: _shown!,
      general: _general!,
      now: widget.now,
    );
  }
}
