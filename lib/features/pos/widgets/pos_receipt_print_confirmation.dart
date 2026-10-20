import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/theme/text_legibility.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const _bg = Color(0xFFFBF8EF);
const _border = Color(0xFFF0EBD8);
const _divider = Color(0xFFF0EBD8);
const _labelColor = TextTones.secondary; // Figma #78706E (4.3:1)

const _svgPrinterCheck =
    '<svg viewBox="0 0 28 28" fill="none" xmlns="http://www.w3.org/2000/svg">'
    '<path d="M7 17H5a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h18a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"'
    ' stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M7 10V4a1 1 0 0 1 1-1h12a1 1 0 0 1 1 1v6"'
    ' stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
    '<rect x="7" y="16" width="14" height="9" rx="1"'
    ' stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
    '<path d="M10 21l2.5 2.5L18 17"'
    ' stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>'
    '</svg>';

/// Print confirmation overlay — Figma **1915:20793**.
///
/// Shown after [posPrintReceipt] fires, so the operator has visible feedback
/// that the job reached the browser print queue.  Dismisses on backdrop tap.
Future<void> showPosPrintConfirmation({
  required BuildContext context,
  required PosReceiptDetail receipt,
  required String printerName,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: PosHomeSpec.contextMenuBackdrop,
    pageBuilder: (_, __, ___) => Material(
      type: MaterialType.transparency,
      child: Center(
        child: _PrintConfirmCard(
          receipt: receipt,
          printerName: printerName,
        ),
      ),
    ),
  );
}

class _PrintConfirmCard extends StatelessWidget {
  final PosReceiptDetail receipt;
  final String printerName;

  const _PrintConfirmCard({
    required this.receipt,
    required this.printerName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 520,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      decoration: BoxDecoration(
        color: _bg,
        border: Border.all(color: _border, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: PosHomeSpec.ink,
              shape: BoxShape.circle,
            ),
            child: SvgPicture.string(_svgPrinterCheck, width: 28, height: 28),
          ),
          const SizedBox(height: 16),
          // Headline
          Text(
            'Sent to printer',
            textAlign: TextAlign.center,
            style: loewExtraBold.copyWith(
              fontSize: 24,
              color: PosHomeSpec.ink,
              height: 29 / 24,
            ),
          ),
          const SizedBox(height: 24),
          // Divider
          const Divider(color: _divider, thickness: 1, height: 1),
          const SizedBox(height: 20),
          // Summary section
          _SummarySection(receipt: receipt, printerName: printerName),
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final PosReceiptDetail receipt;
  final String printerName;

  const _SummarySection({
    required this.receipt,
    required this.printerName,
  });

  @override
  Widget build(BuildContext context) {
    final String customerLabel =
        receipt.customerName.isEmpty ? '—' : receipt.customerName;
    final String displayPrinter =
        printerName.trim().isEmpty ? 'Default printer' : printerName.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'RECEIPT DETAILS',
          style: loewBold.copyWith(
            fontSize: 11,
            color: TextTones.hint,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        _SummaryRow(label: 'Receipt Number', value: '#${receipt.id}'),
        const SizedBox(height: 10),
        _SummaryRow(label: 'Customer', value: customerLabel),
        const SizedBox(height: 10),
        _SummaryRow(label: 'Printer', value: displayPrinter),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: loewMedium.copyWith(
            fontSize: 13,
            color: _labelColor,
          ),
        ),
        Text(
          value,
          style: loewBold.copyWith(
            fontSize: 13,
            color: PosHomeSpec.ink,
          ),
        ),
      ],
    );
  }
}
