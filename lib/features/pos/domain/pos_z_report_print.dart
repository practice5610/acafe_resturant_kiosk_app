import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_report_data.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

/// Prints the day's Z-report through the browser's own print dialog.
///
/// This is the receipt printer's mechanism, not its content: same hidden
/// plain-HTML host + `@media print` stylesheet + `window.print()` as
/// [posPrintReceipt], because that is still the only printing this product
/// has. There is no named-printer registry and no silent print-to-device
/// anywhere in the app, so "Print Z-report" opens the browser dialog and is
/// honest about it — it does not claim to reach a specific terminal.
void posPrintZReport(
  PosReportData data,
  DateTime date, {
  String? branchName,
}) {
  const String hostId = 'pos-zreport-print-host';
  const String styleId = 'pos-zreport-print-style';

  html.document.getElementById(hostId)?.remove();
  html.document.getElementById(styleId)?.remove();

  final html.StyleElement style = html.StyleElement()
    ..id = styleId
    ..text = _printCss;

  final html.DivElement host = html.DivElement()
    ..id = hostId
    ..setInnerHtml(
      posZReportPrintHtml(data, date, branchName: branchName),
      treeSanitizer: html.NodeTreeSanitizer.trusted,
    );

  html.document.head?.append(style);
  html.document.body?.append(host);

  try {
    html.window.print();
  } finally {
    // Same deferred teardown as the receipt path: Chrome blocks inside
    // print() until the dialog closes, Safari and Firefox return before the
    // preview has rendered and would print a blank page if the node vanished
    // underneath them.
    Future<void>.delayed(const Duration(seconds: 1), () {
      host.remove();
      style.remove();
    });
  }
}

const String _printCss = '''
#pos-zreport-print-host { display: none; }
@media print {
  html, body {
    background: #ffffff !important;
    margin: 0 !important;
    padding: 0 !important;
    height: auto !important;
    overflow: visible !important;
  }
  body > *, flt-glass-pane, flutter-view, #loading, canvas {
    display: none !important;
    visibility: hidden !important;
  }
  #pos-zreport-print-host {
    display: block !important;
    visibility: visible !important;
    position: static !important;
    width: 100%;
    margin: 0;
    padding: 0;
    color: #000000;
    font-family: "Helvetica Neue", Arial, sans-serif;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }
  #pos-zreport-print-host * { visibility: visible !important; }
  @page { margin: 10mm; }
}
''';

/// The Z-report ticket as plain HTML. Kept separate from the DOM plumbing
/// above so it can be read and diffed without a browser in the loop.
///
/// Every figure comes from the payload the screen is already showing — which
/// for a just-closed day is the frozen snapshot the server returned from the
/// close itself, so the printout and the stored record cannot disagree.
String posZReportPrintHtml(
  PosReportData data,
  DateTime date, {
  String? branchName,
}) {
  final StringBuffer out = StringBuffer();
  String money(double value) => PosHomeSpec.formatPrice(value, padZero: false);

  out.write('<div class="zr-ticket">');
  out.write('<div class="zr-brand">${_esc(branchName ?? 'A/CAFÉ')}</div>');
  out.write('<div class="zr-title">Z-Report</div>');
  out.write(
      '<div class="zr-meta">${_esc(DateFormat('d MMMM yyyy').format(date))}</div>');
  if (data.zNumber != null) {
    out.write('<div class="zr-meta">Z ${data.zNumber}</div>');
  }
  out.write('<div class="zr-rule"></div>');

  out.write(_kv('Total revenue', money(data.totalRevenue)));
  out.write(_kv('Net sales', money(data.netSales)));
  for (final PosReportTaxRow row in data.taxRows) {
    out.write(_kv(row.label, money(row.amount)));
  }
  out.write(_kv('Total tax', money(data.totalTax)));
  out.write(_kv('Tips', money(data.totalTips)));
  out.write(_kv('Orders', '${data.orderCount}'));
  out.write('<div class="zr-rule"></div>');

  out.write('<div class="zr-section">Payment methods</div>');
  for (final PosReportPaymentRow row in data.paymentMethods) {
    out.write(_kv('${row.label} (${row.orderCount})', money(row.amount)));
  }

  out.write('<div class="zr-rule"></div>');
  out.write('<div class="zr-section">Cash drawer</div>');
  out.write(_kv('Opening float', money(data.openingFloat)));
  out.write(_kv('Cash sales', money(data.cashSales)));
  out.write(_kv('Cash refunds', '- ${money(data.cashRefunds)}'));
  out.write(_kv('Expected in drawer', money(data.expectedInDrawer)));

  // Only on a day that was actually counted — never zero-filled, since a
  // zeroed difference reads as a balanced drawer.
  final double? counted = data.countedAmount;
  if (counted != null) {
    out.write(_kv('Counted', money(counted)));
    final double? difference = data.discrepancyAmount;
    if (difference != null) {
      out.write(_kv('Difference', money(difference)));
    }
    final String? note = data.discrepancyNote;
    if (note != null && note.isNotEmpty) {
      out.write('<div class="zr-note">${_esc(note)}</div>');
    }
  }

  out.write('<div class="zr-rule"></div>');
  out.write('<div class="zr-footer">'
      '${_esc(DateFormat('d MMMM yyyy, HH:mm').format(DateTime.now()))}</div>');
  out.write('</div>');

  out.write('<style>$_ticketCss</style>');
  return out.toString();
}

String _kv(String label, String value) =>
    '<div class="zr-kv"><span>${_esc(label)}</span>'
    '<span>${_esc(value)}</span></div>';

const String _ticketCss = '''
.zr-ticket { width: 72mm; max-width: 100%; margin: 0 auto; font-size: 11px; line-height: 1.45; }
.zr-brand { font-weight: 700; font-size: 15px; letter-spacing: 0.06em; text-align: center; margin-bottom: 6px; }
.zr-title { font-weight: 700; font-size: 13px; text-align: center; }
.zr-meta { text-align: center; color: #333; font-size: 10px; }
.zr-rule { border-top: 1px dashed #000; margin: 8px 0; }
.zr-section { font-weight: 700; margin-bottom: 4px; }
.zr-kv { display: flex; justify-content: space-between; gap: 8px; }
.zr-note { color: #333; font-size: 10px; margin-top: 4px; }
.zr-footer { text-align: center; margin-top: 12px; font-size: 10px; color: #333; }
''';

String _esc(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
