import 'dart:convert';

import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:universal_html/html.dart' as html;

/// CSV for the rows currently on screen, downloaded from the browser.
///
/// Client-side on purpose: the only export in the product is the admin panel's
/// FastExcel route, which runs under the session guard and — in `exportExcel` —
/// explicitly calls `notPos()`, excluding the very orders this screen lists. A
/// Blob download over rows already fetched needs no endpoint and no package.
///
/// The caller is responsible for having pulled every page of the active filter
/// first (`loadAllTransactionsForExport`), so this covers the whole filtered
/// result set rather than the pages scrolled into view.
void posExportReceiptsCsv(
  List<PosReceiptRow> rows, {
  required String fileLabel,
}) {
  final String csv = posReceiptsCsv(rows);

  // The BOM is what makes Excel open a UTF-8 CSV as UTF-8; without it the €
  // sign and any accented customer name arrive mojibaked.
  final html.Blob blob = html.Blob(
    <dynamic>['﻿', csv],
    'text/csv;charset=utf-8',
  );
  final String url = html.Url.createObjectUrlFromBlob(blob);

  html.AnchorElement(href: url)
    ..setAttribute('download', 'receipts-$fileLabel.csv')
    ..click();

  html.Url.revokeObjectUrl(url);
}

/// The CSV body. Separated from the download so it can be asserted on directly.
String posReceiptsCsv(List<PosReceiptRow> rows) {
  final StringBuffer out = StringBuffer();
  out.writeln(_row([
    'Receipt',
    'Date & Time',
    'Customer',
    'Products',
    'Method',
    'Amount',
    'Status',
    'Channel',
  ]));

  for (final PosReceiptRow row in rows) {
    out.writeln(_row([
      row.receiptNumber,
      row.placedAt == null ? '' : row.placedAt!.toLocal().toIso8601String(),
      row.customerName,
      row.productsSummary,
      row.methodLabel,
      row.amount.toStringAsFixed(2),
      row.orderStatus,
      row.channelKey,
    ]));
  }

  return out.toString();
}

String _row(List<String> cells) => cells.map(_cell).join(',');

/// RFC 4180 quoting. Product summaries carry commas routinely ("2x A, B"), and
/// a customer name can contain anything the operator typed.
String _cell(String value) {
  final String normalised = value.replaceAll('\r\n', ' ').replaceAll('\n', ' ');
  if (normalised.contains(',') ||
      normalised.contains('"') ||
      normalised.contains(' ')) {
    return '"${normalised.replaceAll('"', '""')}"';
  }
  return normalised;
}

/// Kept for callers that want the bytes without touching the DOM.
List<int> posReceiptsCsvBytes(List<PosReceiptRow> rows) =>
    utf8.encode(posReceiptsCsv(rows));
