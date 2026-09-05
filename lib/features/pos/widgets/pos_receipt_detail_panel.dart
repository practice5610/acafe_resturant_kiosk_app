import 'package:acafe_customer/features/kiosk/domain/kiosk_product_image_helper.dart';
import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipts_spec.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_line.dart';
import 'package:acafe_customer/features/pos/widgets/pos_receipt_panel.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// `receipt-details-sidebar` (1641:3300) — one settled receipt.
///
/// Composed from the very widgets the POS Payment screen composes
/// ([PosReceiptHeader], [PosReceiptCustomerInfo], [PosReceiptOrderListLabel],
/// [PosReceiptLine], [PosReceiptSummary]), so the ticket reads identically
/// either side of the sale. What differs is read-only-ness, and that is carried
/// by their own optional flags rather than by a second copy of the panel.
class PosReceiptDetailPanel extends StatefulWidget {
  final PosReceiptDetail? receipt;
  final bool loading;

  /// Null while nothing is selected or a load is in flight — the button is
  /// drawn disabled rather than removed, so the panel keeps its height.
  final VoidCallback? onPrint;

  final String? imageBaseUrl;

  /// Null lets the panel fill its parent (the stacked sheet); the side-by-side
  /// layout pins Figma's 400px.
  final double? width;

  const PosReceiptDetailPanel({
    super.key,
    required this.receipt,
    required this.loading,
    required this.onPrint,
    required this.imageBaseUrl,
    this.width = PosReceiptsSpec.sidebarWidth,
  });

  @override
  State<PosReceiptDetailPanel> createState() => _PosReceiptDetailPanelState();
}

class _PosReceiptDetailPanelState extends State<PosReceiptDetailPanel> {
  /// The shared customer/table fields are controller-driven, so the panel owns
  /// two controllers and rewrites them whenever the selection changes. Holding
  /// them here (rather than rebuilding a controller per frame) is what keeps
  /// the fields from flickering as the list scrolls behind them.
  final TextEditingController _name = TextEditingController();
  final TextEditingController _table = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(PosReceiptDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.receipt?.id != widget.receipt?.id ||
        oldWidget.receipt?.customerName != widget.receipt?.customerName ||
        oldWidget.receipt?.table != widget.receipt?.table) {
      _syncControllers();
    }
  }

  void _syncControllers() {
    // Empty, not a placeholder: POS never persists a table number, and writing
    // a plausible-looking one into the field would be inventing a record.
    _name.text = widget.receipt?.customerName ?? '';
    _table.text = widget.receipt?.table ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _table.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PosReceiptDetail? receipt = widget.receipt;

    return Container(
      width: widget.width,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: PosHomeSpec.panelBg,
        border: Border(
          left: BorderSide(color: Colors.black, width: PosHomeSpec.paneBorder),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PosReceiptHeader(
            orderNumber: receipt?.receiptNumber,
            // No ⋯ on a settled receipt: everything behind that menu edits a
            // sale in progress.
            showOptions: false,
          ),
          PosReceiptCustomerInfo(
            nameController: _name,
            tableController: _table,
            readOnly: true,
            showBottomHairline: false,
          ),
          const PosReceiptOrderListLabel(),
          Expanded(
            child: ClipRect(
              child: _Body(
                receipt: receipt,
                loading: widget.loading,
                imageBaseUrl: widget.imageBaseUrl,
              ),
            ),
          ),
          PosReceiptSummary(
            subtotal: receipt?.subtotal ?? 0,
            discount: receipt?.discount ?? 0,
            total: receipt?.total ?? 0,
          ),
          PosPrintReceiptButton(onPrint: widget.onPrint),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final PosReceiptDetail? receipt;
  final bool loading;
  final String? imageBaseUrl;

  const _Body({
    required this.receipt,
    required this.loading,
    required this.imageBaseUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: PosHomeSpec.ink,
          ),
        ),
      );
    }

    if (receipt == null) {
      return const _Placeholder(
        heading: 'No receipt selected',
        subline: 'Pick a row to see its full breakdown',
      );
    }

    if (receipt!.lines.isEmpty) {
      return const _Placeholder(
        heading: 'No items',
        subline: 'This receipt has no line items',
      );
    }

    // Receipts' own list, deliberately not PosReceiptOrderList: that one is
    // typed to the live cart (List<CartModel?> with index-based +/- callbacks)
    // and widening it would drag cart semantics into a settled receipt. The
    // row widget is shared; only the list around it is local.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        clipBehavior: Clip.hardEdge,
        itemCount: receipt!.lines.length,
        itemBuilder: (context, index) {
          final line = receipt!.lines[index];
          return PosReceiptLine(
            line: line,
            imageUrl: KioskProductImageHelper.cartLineImageUrl(
              cart: line,
              productImageBaseUrl: imageBaseUrl,
            ),
            // A record, not a control: no stepper, no EDIT.
            quantityOnly: true,
          );
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String heading;
  final String subline;

  const _Placeholder({required this.heading, required this.subline});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(PosHomeSpec.panelPaddingH),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            heading,
            textAlign: TextAlign.center,
            style: loewExtraBold.copyWith(
              fontSize: PosReceiptsSpec.emptyHeadingSize,
              color: PosHomeSpec.ink,
            ),
          ),
          const SizedBox(height: PosReceiptsSpec.emptyGap),
          Text(
            subline,
            textAlign: TextAlign.center,
            style: swiss721Light.copyWith(
              fontSize: PosReceiptsSpec.emptySublineSize,
              color: PosHomeSpec.inkAlpha(0.53),
            ),
          ),
        ],
      ),
    );
  }
}

/// `print-receipt-btn` (1641:3374) — outlined, where the live panel puts its
/// ink-filled PAY bar. Deliberately a different control: PAY commits money,
/// this reprints a record, and they must not look like the same button.
class PosPrintReceiptButton extends StatelessWidget {
  final VoidCallback? onPrint;

  const PosPrintReceiptButton({super.key, this.onPrint});

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPrint != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PosReceiptsSpec.printPaddingH,
        PosReceiptsSpec.printPaddingH,
        PosReceiptsSpec.printPaddingH,
        PosReceiptsSpec.printPaddingBottom,
      ),
      child: Opacity(
        opacity: enabled ? 1 : 0.35,
        child: Material(
          color: PosReceiptsSpec.surface,
          borderRadius:
              BorderRadius.circular(PosReceiptsSpec.printButtonRadius),
          child: InkWell(
            onTap: onPrint,
            borderRadius:
                BorderRadius.circular(PosReceiptsSpec.printButtonRadius),
            child: Container(
              height: PosReceiptsSpec.printButtonHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(PosReceiptsSpec.printButtonRadius),
                border: Border.all(
                  color: PosHomeSpec.ink,
                  width: PosReceiptsSpec.printButtonBorder,
                ),
              ),
              child: Text(
                'Print Receipt',
                style: loewBold.copyWith(
                  fontSize: PosReceiptsSpec.printLabelSize,
                  color: PosHomeSpec.ink,
                  height: 19 / 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
