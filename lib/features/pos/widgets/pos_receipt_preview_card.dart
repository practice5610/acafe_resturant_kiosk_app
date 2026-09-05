import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_settings_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One illustrative order line in the preview ticket.
class PosReceiptSampleLine {
  final int quantity;
  final String name;
  final double amount;
  final List<({String label, double amount})> addons;

  const PosReceiptSampleLine({
    required this.quantity,
    required this.name,
    required this.amount,
    this.addons = const [],
  });
}

/// The sample basket behind the preview.
///
/// **This is illustrative data, not a transaction.** It exists so an operator
/// can judge a header/footer/prefix change against a realistically dense
/// ticket. The card-terminal block below it is illustrative for a harder
/// reason: the Mollie A35 integration is still an abstract interface
/// (`KioskPaymentService`) with only a simulator behind it, so no terminal id,
/// masked PAN, auth code or contactless flag exists anywhere in the product to
/// read. Nothing here is sourced from, or presented as, a real payment.
class PosReceiptSample {
  PosReceiptSample._();

  static const List<PosReceiptSampleLine> lines = [
    PosReceiptSampleLine(
      quantity: 2,
      name: 'Matcha Latte',
      amount: 9.00,
      addons: [(label: 'Oat Milk', amount: 0.60), (label: 'Extra Shot', amount: 0.50)],
    ),
    PosReceiptSampleLine(
      quantity: 3,
      name: 'Mini Poffertjes',
      amount: 16.50,
      addons: [
        (label: 'Whipped Cream', amount: 0.00),
        (label: 'Strawberry Topping', amount: 1.50),
      ],
    ),
    PosReceiptSampleLine(quantity: 2, name: 'Fresh Smoothie', amount: 7.00),
  ];

  static const double subtotal = 47.35;
  static const double total = 47.35;
  static const double taxAmount = 8.22;
  static const int taxPercent = 9;

  /// Register / operator shown on the ticket. Illustrative, like the basket.
  static const String register = '1';
  static const String operatorName = 'Sophie';

  /// Terminal block — see the class comment. Every value is invented.
  static const String terminalId = 'CT878913';
  static const String merchantId = '251149';
  static const String periodNumber = '6242';
  static const String transactionNumber = '00236054';
  static const String token = '1052938610235B604';
  static const String cardScheme = 'Visa DEBIT';
  static const String cardAid = 'A0000000031010';
  static const String cardPan = '4547 93xx xxxx 7448';
  static const String authCode = 'FW7VS3';

  /// Statutory footer identifiers. Placeholders, like the rest of the block.
  static const String kvk = '82451639';
  static const String btw = 'NL862451639B01';
}

/// Thermal-receipt preview for Settings → Hardware (Figma 1641:8685).
///
/// Header, footer, store address/phone, order number and date/time are **live**
/// — they read straight off the unsaved form draft and General → Store
/// Information, so the operator reviews the real thing before pressing Save.
/// The basket and the card-terminal block are illustrative sample data, marked
/// as such on the card.
class PosReceiptPreviewCard extends StatelessWidget {
  final PosHardwareSettings settings;
  final PosGeneralSettings general;

  /// Injectable so widget tests get a stable ticket instead of wall-clock time.
  final DateTime? now;

  const PosReceiptPreviewCard({
    super.key,
    required this.settings,
    required this.general,
    this.now,
  });

  static const Map<String, String> _symbols = {
    'EUR': '€',
    'GBP': '£',
    'USD': r'$',
  };

  String get _symbol => _symbols[general.currency] ?? '€';

  String _money(double amount) =>
      '$_symbol${amount.toStringAsFixed(2)}';

  String _stamp() {
    final DateTime at = now ?? DateTime.now();
    // The operator's chosen date format from General, so the preview matches
    // what the terminal actually prints rather than a second hardcoded format.
    return '${DateFormat(general.dateFormat).format(at)} '
        '${DateFormat('HH:mm').format(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final String header = settings.effectiveHeader(general.storeName).trim();
    final String footer = settings.receiptFooter.trim();
    final String address = general.address.trim();
    final String phone = general.contactPhone.trim();
    final String stamp = _stamp();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          PosHardwareSpec.previewCaption,
          style: loewBold.copyWith(
            fontSize: PosHardwareSpec.captionSize,
            letterSpacing: PosHardwareSpec.captionTracking,
            color: PosSettingsSpec.inkMuted(0.55),
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: PosHardwareSpec.previewCardBg,
            borderRadius:
                BorderRadius.circular(PosHardwareSpec.previewCardRadius),
            border: Border.all(color: PosSettingsSpec.fieldBorder),
            boxShadow: PosHardwareSpec.previewShadow,
          ),
          child: Padding(
            padding: PosHardwareSpec.previewCardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Store identity (live) ───────────────────────────────
                _Centered(
                  header.isEmpty ? '—' : header.toUpperCase(),
                  bold: true,
                  size: PosHardwareSpec.receiptBrandSize,
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  _Centered(address, size: PosHardwareSpec.receiptSmallSize),
                ],
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  _Centered('Tel: $phone',
                      size: PosHardwareSpec.receiptSmallSize),
                ],

                const _DashedRule(),

                // ── Ticket meta (order number + timestamp are live) ──────
                _Row(
                  'Bon: ${PosOrderNumber.preview(settings.orderNumberPrefix)}',
                  '',
                ),
                _Row('Datum: $stamp', ''),
                const _Row(
                  'Kassa: ${PosReceiptSample.register} / '
                  'Medewerker: ${PosReceiptSample.operatorName}',
                  '',
                ),

                const _DashedRule(),

                // ── Sample basket ───────────────────────────────────────
                for (final PosReceiptSampleLine line
                    in PosReceiptSample.lines) ...[
                  _Row(
                    '${line.quantity}x ${line.name}',
                    _money(line.amount),
                    bold: true,
                  ),
                  for (final addon in line.addons)
                    _Row(
                      '  + ${addon.label}',
                      _money(addon.amount),
                      muted: true,
                      size: PosHardwareSpec.receiptSmallSize,
                    ),
                ],

                const _DashedRule(),

                _Row('Subtotaal', _money(PosReceiptSample.subtotal)),
                const SizedBox(height: 4),
                _Row(
                  'TOTAAL',
                  _money(PosReceiptSample.total),
                  bold: true,
                  size: PosHardwareSpec.receiptTotalSize,
                ),
                const SizedBox(height: 4),
                _Row(
                  'Waarvan BTW ${PosReceiptSample.taxPercent}%',
                  _money(PosReceiptSample.taxAmount),
                ),

                const SizedBox(height: PosHardwareSpec.receiptBlockGap),

                // ── Card terminal block (illustrative — see class doc) ───
                const _Row('BETAALD MET:', '', bold: true,
                    size: PosHardwareSpec.receiptSmallSize),
                _Row('PINNEN', _money(PosReceiptSample.total)),

                const SizedBox(height: PosHardwareSpec.receiptBlockGap),

                const _Row('Kopie', 'Kaarthouder',
                    muted: true, size: PosHardwareSpec.receiptSmallSize),
                const _Row('Terminal   ${PosReceiptSample.terminalId}',
                    'Merchant   ${PosReceiptSample.merchantId}',
                    muted: true, size: PosHardwareSpec.receiptSmallSize),
                const _Row('Periode   ${PosReceiptSample.periodNumber}',
                    'Transactie   ${PosReceiptSample.transactionNumber}',
                    muted: true, size: PosHardwareSpec.receiptSmallSize),
                const _Row('Token', PosReceiptSample.token,
                    muted: true, size: PosHardwareSpec.receiptSmallSize),
                const _Row('Contactloze betaling', PosReceiptSample.cardScheme,
                    muted: true, size: PosHardwareSpec.receiptSmallSize),
                const _Row('[${PosReceiptSample.cardAid}]',
                    'Kaart   ${PosReceiptSample.cardPan}',
                    muted: true, size: PosHardwareSpec.receiptSmallSize),
                const _Row('Kaartnr', '00 BETALING',
                    muted: true, size: PosHardwareSpec.receiptSmallSize),
                _Row('Datum   $stamp',
                    'Auth. code   ${PosReceiptSample.authCode}',
                    muted: true, size: PosHardwareSpec.receiptSmallSize),
                _Row('Totaal',
                    '${_money(PosReceiptSample.total)} ${general.currency}',
                    muted: true, size: PosHardwareSpec.receiptSmallSize),
                const _Row('Met consumentenapparaat', 'gevalideerd',
                    muted: true, size: PosHardwareSpec.receiptSmallSize),
                const _Row('AKKOORD', '', bold: true,
                    size: PosHardwareSpec.receiptSmallSize),

                const _DashedRule(),

                const _Centered(
                  'KVK: ${PosReceiptSample.kvk} | BTW: ${PosReceiptSample.btw}',
                  size: PosHardwareSpec.receiptSmallSize,
                  muted: true,
                ),
                if (footer.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  // ── Footer (live) ─────────────────────────────────────
                  _Centered(footer, size: PosHardwareSpec.receiptBodySize),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Never let this card read as a record of a payment that happened.
        Text(
          'Sample transaction — items and card details are illustrative. '
          'Store name, address, order number and footer are live.',
          style: loewRegular.copyWith(
            fontSize: PosHardwareSpec.helperSize,
            color: PosSettingsSpec.inkMuted(0.5),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

/// A left/right ticket row. The left label flexes and ellipsises so a long
/// store-supplied string can never overflow the fixed-width card.
class _Row extends StatelessWidget {
  final String left;
  final String right;
  final bool bold;
  final bool muted;
  final double size;

  const _Row(
    this.left,
    this.right, {
    this.bold = false,
    this.muted = false,
    this.size = PosHardwareSpec.receiptBodySize,
  });

  @override
  Widget build(BuildContext context) {
    final TextStyle style = (bold ? robotoMonoBold : robotoMonoRegular)
        .copyWith(
      fontSize: size,
      height: 1.45,
      color: muted
          ? PosHardwareSpec.previewInk.withValues(alpha: 0.62)
          : PosHardwareSpec.previewInk,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: PosHardwareSpec.receiptLineGap),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(left, style: style, maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          if (right.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(right, style: style, maxLines: 1, softWrap: false),
          ],
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final String text;
  final bool bold;
  final bool muted;
  final double size;

  const _Centered(
    this.text, {
    this.bold = false,
    this.muted = false,
    this.size = PosHardwareSpec.receiptBodySize,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: (bold ? robotoMonoBold : robotoMonoRegular).copyWith(
        fontSize: size,
        height: 1.4,
        letterSpacing: bold ? 0.4 : 0,
        color: muted
            ? PosHardwareSpec.previewInk.withValues(alpha: 0.62)
            : PosHardwareSpec.previewInk,
      ),
    );
  }
}

/// The tear-line between ticket blocks.
class _DashedRule extends StatelessWidget {
  const _DashedRule();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: PosHardwareSpec.receiptBlockGap,
      ),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: _DashedRulePainter(),
      ),
    );
  }
}

class _DashedRulePainter extends CustomPainter {
  static const double _dash = 3;
  static const double _gap = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = PosHardwareSpec.previewRule
      ..strokeWidth = 1;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + _dash, 0), paint);
      x += _dash + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRulePainter oldDelegate) => false;
}
