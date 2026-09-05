import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipts_spec.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:flutter/material.dart';

/// `receipts-table` (1641:3257) — sticky header over a scrolling body.
///
/// The header sits outside the scrollable rather than as row zero, because a
/// counter's history is hundreds of rows deep and column labels that scroll
/// away are useless. Rows are built lazily for the same reason: Figma draws
/// five, a real shift is not five.
class PosReceiptsTable extends StatelessWidget {
  final List<PosReceiptRow> rows;
  final int? selectedId;
  final ValueChanged<PosReceiptRow> onSelect;
  final ScrollController controller;

  /// True while another page is on its way — appends a footer spinner rather
  /// than covering the rows already on screen.
  final bool loadingMore;

  /// True on a first load with nothing yet to show.
  final bool loading;

  const PosReceiptsTable({
    super.key,
    required this.rows,
    required this.selectedId,
    required this.onSelect,
    required this.controller,
    this.loadingMore = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: PosReceiptsSpec.surface,
        borderRadius: BorderRadius.circular(PosReceiptsSpec.tableRadius),
        border: Border.all(
          color: PosReceiptsSpec.fieldBorder,
          width: PosReceiptsSpec.tableBorder,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Below the threshold the five fixed columns leave no readable width
          // for Products, so Date and Customer fold into the Receipt cell
          // instead of every column being squeezed to illegibility.
          final bool compact = constraints.maxWidth <
              PosReceiptsSpec.compactTableBelowWidth;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _HeaderRow(compact: compact),
              Flexible(
                child: _Body(
                  rows: rows,
                  selectedId: selectedId,
                  onSelect: onSelect,
                  controller: controller,
                  compact: compact,
                  loading: loading,
                  loadingMore: loadingMore,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Beyond this many rows the body stops sizing to its content. Comfortably
/// more than fills the tallest supported pane, so the switch never happens
/// while the table is still short enough to hug.
const int _shrinkWrapRowLimit = 40;

class _Body extends StatelessWidget {
  final List<PosReceiptRow> rows;
  final int? selectedId;
  final ValueChanged<PosReceiptRow> onSelect;
  final ScrollController controller;
  final bool compact;
  final bool loading;
  final bool loadingMore;

  const _Body({
    required this.rows,
    required this.selectedId,
    required this.onSelect,
    required this.controller,
    required this.compact,
    required this.loading,
    required this.loadingMore,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return _EmptyBody(loading: loading);
    }

    // Figma sizes the table to its rows, and a white box stretched to the
    // bottom of a quiet shift looks broken. shrinkWrap gives that, at the cost
    // of building every row — fine for a screenful, wrong for a busy day. Past
    // the threshold the list goes lazy and fills the pane, which is what it
    // would be doing at that length anyway.
    final bool hugContent = rows.length <= _shrinkWrapRowLimit;

    return ListView.builder(
      controller: controller,
      padding: EdgeInsets.zero,
      shrinkWrap: hugContent,
      itemCount: rows.length + (loadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= rows.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PosHomeSpec.ink,
                ),
              ),
            ),
          );
        }

        final PosReceiptRow row = rows[index];
        return _DataRow(
          row: row,
          selected: row.id == selectedId,
          compact: compact,
          onTap: () => onSelect(row),
        );
      },
    );
  }
}

class _EmptyBody extends StatelessWidget {
  final bool loading;

  const _EmptyBody({required this.loading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PosHomeSpec.ink,
                ),
              )
            : Text(
                'No receipts for this filter',
                textAlign: TextAlign.center,
                style: swiss721Light.copyWith(
                  fontSize: PosReceiptsSpec.emptySublineSize,
                  color: PosHomeSpec.inkAlpha(0.53),
                ),
              ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final bool compact;

  const _HeaderRow({required this.compact});

  @override
  Widget build(BuildContext context) {
    final TextStyle style = loewExtraBold.copyWith(
      fontSize: PosReceiptsSpec.headerTextSize,
      color: PosHomeSpec.ink,
      height: 1.3,
    );

    return Container(
      color: PosReceiptsSpec.surface,
      padding: const EdgeInsets.all(PosReceiptsSpec.cellPadding),
      child: _CellRow(
        compact: compact,
        receipt: Text('Receipt', style: style),
        date: Text('Date & Time', style: style),
        customer: Text('Customer', style: style),
        products: Text('Products', style: style),
        method: Text('Method', style: style),
        amount: Text('Amount', style: style),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final PosReceiptRow row;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _DataRow({
    required this.row,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // On the ink-filled selected row every column goes white: the 0.6-alpha ink
    // the muted columns use on white would be unreadable on ink.
    final Color primary =
        selected ? PosReceiptsSpec.selectedInk : PosHomeSpec.ink;
    final Color muted = selected
        ? PosReceiptsSpec.selectedInk
        : PosHomeSpec.inkAlpha(0.6);

    TextStyle base(TextStyle family, Color color) => family.copyWith(
          fontSize: PosReceiptsSpec.rowTextSize,
          color: color,
          height: 1.3,
        );

    return Material(
      color: selected ? PosHomeSpec.ink : PosReceiptsSpec.surface,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: PosReceiptsSpec.rowDivider),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(PosReceiptsSpec.cellPadding),
            child: _CellRow(
              compact: compact,
              receipt: compact
                  // Compact keeps the same facts, stacked: the receipt number
                  // with its time and customer beneath, rather than dropping
                  // them.
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          row.receiptNumber,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: base(loewBold, primary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          row.placedAtLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: base(loewRegular, muted)
                              .copyWith(fontSize: 11),
                        ),
                        Text(
                          row.customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              base(loewMedium, primary).copyWith(fontSize: 11),
                        ),
                      ],
                    )
                  : Text(
                      row.receiptNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: base(loewBold, primary),
                    ),
              date: Text(
                row.placedAtLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: base(loewRegular, muted),
              ),
              customer: Text(
                row.customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: base(loewMedium, primary),
              ),
              products: Text(
                row.productsSummary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: base(loewRegular, primary),
              ),
              method: Text(
                row.methodLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: base(loewRegular, muted),
              ),
              amount: Text(
                PosHomeSpec.formatPrice(row.amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: base(loewExtraBold, primary),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The column geometry, in one place so the header and every row cannot drift
/// apart. Products is the only flexible column — Figma pins the other five.
class _CellRow extends StatelessWidget {
  final bool compact;
  final Widget receipt;
  final Widget date;
  final Widget customer;
  final Widget products;
  final Widget method;
  final Widget amount;

  const _CellRow({
    required this.compact,
    required this.receipt,
    required this.date,
    required this.customer,
    required this.products,
    required this.method,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: PosReceiptsSpec.receiptColumn * 1.4, child: receipt),
          const SizedBox(width: PosReceiptsSpec.columnGap),
          Expanded(child: products),
          const SizedBox(width: PosReceiptsSpec.columnGap),
          SizedBox(width: PosReceiptsSpec.amountColumn, child: amount),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: PosReceiptsSpec.receiptColumn, child: receipt),
        const SizedBox(width: PosReceiptsSpec.columnGap),
        SizedBox(width: PosReceiptsSpec.dateColumn, child: date),
        const SizedBox(width: PosReceiptsSpec.columnGap),
        SizedBox(width: PosReceiptsSpec.customerColumn, child: customer),
        const SizedBox(width: PosReceiptsSpec.columnGap),
        Expanded(child: products),
        const SizedBox(width: PosReceiptsSpec.columnGap),
        SizedBox(width: PosReceiptsSpec.methodColumn, child: method),
        const SizedBox(width: PosReceiptsSpec.columnGap),
        SizedBox(width: PosReceiptsSpec.amountColumn, child: amount),
      ],
    );
  }
}
