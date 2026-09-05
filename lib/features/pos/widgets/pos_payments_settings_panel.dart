import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_payment_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_payments_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_section.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/features/pos/providers/pos_payment_settings_provider.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_dropdown.dart';
import 'package:acafe_customer/features/pos/widgets/pos_settings_text_field.dart';
import 'package:acafe_customer/features/pos/widgets/pos_toggle.dart';
import 'package:acafe_customer/utill/images.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// Settings → Payments (Figma **1641:4235**).
///
/// Instant-apply throughout: unlike General and Hardware there is no Save
/// button in the design, and none of these controls has an intermediate state
/// worth batching. Every switch writes through on change.
///
/// Three of the four method rows and one of the two transaction switches are
/// rendered **disabled on purpose**. Mobile Pay, Gift Cards and the tipping
/// screen have no implementation behind them anywhere in the product, so a
/// live toggle would promise rails that do not exist. A greyed control says
/// "not available on this terminal" without needing a line of copy to explain
/// it, which is also how Figma paints the Gift Cards row.
class PosPaymentsSettingsPanel extends StatelessWidget {
  const PosPaymentsSettingsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool wide =
            constraints.maxWidth >= PosPaymentsSpec.twoColumnBreakpoint;

        // The page scrolls as one column below the breakpoint. Above it the
        // two columns keep their own heights — the method card is content-
        // sized, so a short list must not stretch to match the settings card.
        final Widget body = wide
            ? const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _PaymentMethodsColumn()),
                  SizedBox(width: PosPaymentsSpec.columnGap),
                  SizedBox(
                    width: PosPaymentsSpec.rightColumnWidth,
                    child: _TransactionSettingsColumn(),
                  ),
                ],
              )
            : const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PaymentMethodsColumn(),
                  SizedBox(height: PosPaymentsSpec.columnGap),
                  _TransactionSettingsColumn(),
                ],
              );

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _PaymentsHeader(),
              const SizedBox(height: PosPaymentsSpec.headerToGridGap),
              body,
            ],
          ),
        );
      },
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _PaymentsHeader extends StatelessWidget {
  const _PaymentsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          PosSettingsSection.payments.title,
          style: loewExtraBold.copyWith(
            fontSize: PosSettingsSpec.titleSize,
            color: PosSettingsSpec.ink,
            height: 1.1,
          ),
        ),
        const SizedBox(height: PosPaymentsSpec.headerGap),
        Text(
          PosSettingsSection.payments.subtitle,
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

/// Uppercase column heading — "PAYMENT METHODS" / "TRANSACTION SETTINGS".
class _ColumnLabel extends StatelessWidget {
  final String text;

  const _ColumnLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: loewBold.copyWith(
        fontSize: PosPaymentsSpec.sectionLabelSize,
        color: PosSettingsSpec.ink,
        height: 1.2,
      ),
    );
  }
}

/// The white, hairline-bordered card both columns sit in.
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;

  /// Only the method list needs clipping — its rows run edge to edge and draw
  /// dividers that would otherwise square off the rounded corners. The padded
  /// settings card must **not** clip: its content sits flush against the clip
  /// bounds, and a glyph with a negative left bearing (the D of "DEFAULT", the
  /// P of "Prints") loses its first pixel column to the clip.
  final bool clip;

  const _Card({required this.child, this.padding, this.clip = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: PosPaymentsSpec.cardFill,
        borderRadius: BorderRadius.circular(PosPaymentsSpec.cardRadius),
        border: Border.all(color: PosPaymentsSpec.cardBorder),
      ),
      child: clip
          ? ClipRRect(
              borderRadius: BorderRadius.circular(
                PosPaymentsSpec.cardRadius - 1,
              ),
              child: child,
            )
          : child,
    );
  }
}

// ── Left column: payment methods ────────────────────────────────────────────

class _PaymentMethodsColumn extends StatelessWidget {
  const _PaymentMethodsColumn();

  @override
  Widget build(BuildContext context) {
    final PosPaymentSettingsProvider provider =
        context.watch<PosPaymentSettingsProvider>();
    final PosPaymentSettings s = provider.settings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ColumnLabel('PAYMENT METHODS'),
        const SizedBox(height: PosPaymentsSpec.sectionLabelToCardGap),
        _Card(
          clip: true,
          child: Column(
            children: [
              _MethodRow(
                icon: Images.posPayCashSvg,
                iconSize: 16,
                name: 'Cash',
                description:
                    'Accept physical currency cash drawer kicks on print',
                value: s.cashEnabled,
                // Locked when it is the only tender left — see
                // [PosPaymentSettings.isLastTender].
                onChanged: s.cashLocked ? null : provider.setCashEnabled,
              ),
              _MethodRow(
                icon: Images.posPayCardSvg,
                name: 'Credit / Debit Card',
                description:
                    'Charge Visa, Mastercard, AMEX through terminals',
                value: s.cardEnabled,
                onChanged: s.cardLocked ? null : provider.setCardEnabled,
              ),
              // Inert: no Apple Pay / Google Wallet / QR integration exists in
              // this app or its backend.
              _MethodRow(
                icon: Images.posPayMobileSvg,
                name: 'Mobile Pay',
                description: 'Apple Pay, Google Wallet, and localized QR codes',
                value: s.mobilePayEnabled,
                onChanged: null,
              ),
              // Inert: the only gift card code in the product is a no-op entry
              // in the receipt context menu.
              _MethodRow(
                icon: Images.posPayGiftSvg,
                name: 'Gift Cards',
                description:
                    'Scan and redeem branded digital or physical gift cards',
                value: s.giftCardsEnabled,
                onChanged: null,
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MethodRow extends StatelessWidget {
  final String icon;
  final double iconSize;
  final String name;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isLast;

  const _MethodRow({
    required this.icon,
    required this.name,
    required this.description,
    required this.value,
    required this.onChanged,
    this.iconSize = 18,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: PosPaymentsSpec.rowDivider),
              ),
      ),
      child: Padding(
        padding: PosPaymentsSpec.rowPadding,
        child: Row(
          children: [
            Container(
              width: PosPaymentsSpec.iconBoxSize,
              height: PosPaymentsSpec.iconBoxSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: PosPaymentsSpec.iconBoxFill,
                borderRadius:
                    BorderRadius.circular(PosPaymentsSpec.iconBoxRadius),
                border: Border.all(color: PosPaymentsSpec.cardBorder),
              ),
              child: SvgPicture.asset(
                icon,
                width: iconSize,
                colorFilter: const ColorFilter.mode(
                  PosSettingsSpec.ink,
                  BlendMode.srcIn,
                ),
              ),
            ),
            const SizedBox(width: PosPaymentsSpec.rowMetaGap),
            // The description is the longest string on the row and the first
            // thing that should give way — without this the row overflows on a
            // narrow terminal instead of ellipsing.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: loewBold.copyWith(
                      fontSize: PosPaymentsSpec.rowNameSize,
                      color: PosSettingsSpec.ink,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: PosPaymentsSpec.rowTextGap),
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: loewRegular.copyWith(
                      fontSize: PosPaymentsSpec.rowDescriptionSize,
                      color: PosSettingsSpec.inkMuted(),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: PosPaymentsSpec.rowMetaGap),
            PosToggle(
              value: value,
              semanticLabel: '$name enabled',
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Right column: transaction settings ──────────────────────────────────────

class _TransactionSettingsColumn extends StatelessWidget {
  const _TransactionSettingsColumn();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ColumnLabel('TRANSACTION SETTINGS'),
        SizedBox(height: PosPaymentsSpec.rightSectionLabelToCardGap),
        _Card(
          padding: PosPaymentsSpec.settingsCardPadding,
          child: _TransactionSettingsCard(),
        ),
      ],
    );
  }
}

class _TransactionSettingsCard extends StatelessWidget {
  const _TransactionSettingsCard();

  @override
  Widget build(BuildContext context) {
    final PosPaymentSettingsProvider provider =
        context.watch<PosPaymentSettingsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Same record General's Regional Settings edits — changing it here
        // changes it there, and vice versa.
        PosSettingsDropdown(
          label: 'Default Currency',
          value: provider.currency,
          options: PosGeneralSettings.currencyOptions,
          onChanged: provider.setCurrency,
        ),
        const SizedBox(height: PosPaymentsSpec.settingsCardGap),
        const _TaxRateField(),
        const SizedBox(height: PosPaymentsSpec.settingsCardGap),
        const _CardDivider(),
        const SizedBox(height: PosPaymentsSpec.settingsCardGap),
        // Inert on POS: the kiosk has a real tip flow backed by
        // `orders.tip_amount`, but POS checkout has no tip step to switch on.
        _SettingToggleRow(
          label: 'ENABLE TIPPING SCREEN',
          value: provider.settings.tippingEnabled,
          onChanged: null,
        ),
        const SizedBox(height: PosPaymentsSpec.settingsCardGap),
        const _CardDivider(),
        const SizedBox(height: PosPaymentsSpec.settingsCardGap),
        // Real, and shared with Hardware → Printer: this is the same
        // `autoPrintReceipts` flag the payment flow already checks after a
        // completed sale.
        _SettingToggleRow(
          label: 'RECEIPT AUTO-PRINT',
          subtitle: 'Prints automatically after payment',
          value: provider.autoPrintReceipts,
          onChanged: provider.setAutoPrintReceipts,
        ),
      ],
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      color: PosPaymentsSpec.cardBorder,
    );
  }
}

class _SettingToggleRow extends StatelessWidget {
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SettingToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: loewBold.copyWith(
                  fontSize: PosPaymentsSpec.toggleLabelSize,
                  color: PosSettingsSpec.ink,
                  height: 1.2,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: PosPaymentsSpec.toggleTextGap),
                Text(
                  subtitle!,
                  style: loewRegular.copyWith(
                    fontSize: PosPaymentsSpec.toggleSubtitleSize,
                    color: PosSettingsSpec.inkMuted(),
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        PosToggle(
          value: value,
          semanticLabel: label,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

/// Default Tax Rate.
///
/// Owns its own controller so the card can stay stateless and the field is not
/// rebuilt out from under a half-typed value by an unrelated toggle.
///
/// **Persisted, and read by nothing.** Tax in this product is per-product
/// (`products.tax`, summed per cart line by `kiosk_cart_totals.dart`); there is
/// no store-level rate for this to override, so it cannot and does not move any
/// order total. See [PosPaymentSettings].
class _TaxRateField extends StatefulWidget {
  const _TaxRateField();

  @override
  State<_TaxRateField> createState() => _TaxRateFieldState();
}

class _TaxRateFieldState extends State<_TaxRateField> {
  late final TextEditingController _controller;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _controller.text =
        context.read<PosPaymentSettingsProvider>().settings.defaultTaxRate;
    _seeded = true;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PosSettingsTextField(
      label: 'Default Tax Rate',
      controller: _controller,
      suffixText: 'VAT Standard',
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged:
          context.read<PosPaymentSettingsProvider>().setDefaultTaxRate,
    );
  }
}
