import 'package:acafe_customer/features/pos/domain/pos_home_spec.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_line_copy.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_cart_totals.dart';
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;

/// Prints one receipt through the browser's own print dialog.
///
/// The POS is Flutter Web on a counter terminal, and there is no printing
/// anywhere else in this app to reuse — the only receipt printing in the
/// product is the admin panel's Blade invoice, which a device token cannot
/// reach. `window.print()` with a print-only stylesheet is therefore the whole
/// mechanism, and needs no backend.
///
/// The canvas Flutter renders into cannot be styled for print, so this does not
/// try to print the on-screen pane. It appends a plain-HTML copy of the receipt
/// to the document, hides everything else with an `@media print` rule, prints,
/// and removes it again. What comes out is a narrow thermal-style ticket rather
/// than a screenshot of the sidebar, which is what a receipt should be.
void posPrintReceipt(PosReceiptDetail receipt, {String? branchName}) {
  const String hostId = 'pos-receipt-print-host';
  const String styleId = 'pos-receipt-print-style';

  html.document.getElementById(hostId)?.remove();
  html.document.getElementById(styleId)?.remove();

  final html.StyleElement style = html.StyleElement()
    ..id = styleId
    ..text = _printCss;

  final html.DivElement host = html.DivElement()
    ..id = hostId
    ..setInnerHtml(
      posReceiptPrintHtml(receipt, branchName: branchName),
      treeSanitizer: html.NodeTreeSanitizer.trusted,
    );

  html.document.head?.append(style);
  html.document.body?.append(host);

  try {
    html.window.print();
  } finally {
    // Chrome blocks in print() until the dialog closes, so the ticket is safe
    // to drop the moment it returns. Safari and Firefox return before the
    // preview has rendered, and tearing the node out underneath them prints a
    // blank page — hence the deferred removal rather than an immediate one.
    // Re-entering posPrintReceipt in the meantime is harmless: it removes any
    // host still in the document by id before appending a new one.
    Future<void>.delayed(const Duration(seconds: 1), () {
      host.remove();
      style.remove();
    });
  }
}

/// Everything except the ticket is hidden while printing, and the Flutter view
/// is hidden explicitly: `flt-glass-pane` is not a child of anything a
/// `body > *` rule reaches in every engine build.
const String _printCss = '''
#pos-receipt-print-host { display: none; }
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
  #pos-receipt-print-host {
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
  #pos-receipt-print-host * { visibility: visible !important; }
  @page { margin: 10mm; }
}
''';

/// The ticket itself, as plain HTML. Kept separate from the DOM plumbing above
/// so it can be read (and diffed) without a browser in the loop.
String posReceiptPrintHtml(PosReceiptDetail receipt, {String? branchName}) {
  final StringBuffer out = StringBuffer();
  final String placedAt = receipt.placedAt == null
      ? ''
      : DateFormat('d MMMM yyyy, HH:mm').format(receipt.placedAt!.toLocal());

  out.write('<div class="pr-ticket">');
  out.write('<div class="pr-brand">${_esc(branchName ?? 'A/CAFÉ')}</div>');
  out.write('<div class="pr-title">Purchase Receipt</div>');
  out.write('<div class="pr-meta">#${receipt.id}</div>');
  if (placedAt.isNotEmpty) {
    out.write('<div class="pr-meta">${_esc(placedAt)}</div>');
  }
  out.write('<div class="pr-rule"></div>');

  out.write('<div class="pr-kv"><span>Customer</span>'
      '<span>${_esc(receipt.customerName)}</span></div>');
  if (receipt.table != null) {
    out.write('<div class="pr-kv"><span>Table</span>'
        '<span>${_esc(receipt.table!)}</span></div>');
  }
  out.write('<div class="pr-kv"><span>Method</span>'
      '<span>${receipt.method == 'card' ? 'Card' : 'Cash'}</span></div>');
  out.write('<div class="pr-rule"></div>');

  for (final line in receipt.lines) {
    final int quantity = line.quantity ?? 1;
    final String unit = PosHomeSpec.formatPrice(kioskLineUnitPrice(line));
    final String size = posReceiptUnit(line) == null
        ? ''
        : ' · ${posReceiptUnit(line)}';

    out.write('<div class="pr-line">');
    out.write('<div class="pr-line-top">'
        '<span class="pr-qty">${quantity}x</span>'
        '<span class="pr-name">${_esc(posReceiptLineName(line))}</span>'
        '<span class="pr-amount">'
        '${PosHomeSpec.formatPrice(kioskLineUnitPrice(line) * quantity)}'
        '</span></div>');
    out.write('<div class="pr-line-sub">${_esc('$unit$size')}</div>');
    for (final note in posReceiptNotes(line)) {
      out.write('<div class="pr-note">'
          '${note.included ? '+' : '−'} ${_esc(note.label)}</div>');
    }
    out.write('</div>');
  }

  out.write('<div class="pr-rule"></div>');
  out.write('<div class="pr-kv"><span>Subtotal</span>'
      '<span>${PosHomeSpec.formatPrice(receipt.subtotal)}</span></div>');
  if (receipt.discount > 0) {
    out.write('<div class="pr-kv"><span>Discount</span>'
        '<span>- ${PosHomeSpec.formatPrice(receipt.discount)}</span></div>');
  }
  out.write('<div class="pr-total"><span>Total</span>'
      '<span>${PosHomeSpec.formatPrice(receipt.total)}</span></div>');
  out.write('<div class="pr-footer">Thank you</div>');
  out.write('</div>');

  out.write('<style>$_ticketCss</style>');
  return out.toString();
}

const String _ticketCss = '''
.pr-ticket { width: 72mm; max-width: 100%; margin: 0 auto; font-size: 11px; line-height: 1.45; }
.pr-brand { font-weight: 700; font-size: 15px; letter-spacing: 0.06em; text-align: center; margin-bottom: 6px; }
.pr-title { font-weight: 700; font-size: 13px; text-align: center; }
.pr-meta { text-align: center; color: #333; font-size: 10px; }
.pr-rule { border-top: 1px dashed #000; margin: 8px 0; }
.pr-kv { display: flex; justify-content: space-between; gap: 8px; }
.pr-line { margin-bottom: 6px; }
.pr-line-top { display: flex; gap: 6px; align-items: baseline; }
.pr-qty { font-weight: 700; min-width: 22px; }
.pr-name { flex: 1 1 auto; font-weight: 700; word-break: break-word; }
.pr-amount { font-weight: 700; white-space: nowrap; }
.pr-line-sub { padding-left: 28px; color: #333; font-size: 10px; }
.pr-note { padding-left: 28px; color: #333; font-size: 10px; }
.pr-total { display: flex; justify-content: space-between; font-weight: 700; font-size: 13px; margin-top: 6px; }
.pr-footer { text-align: center; margin-top: 12px; font-size: 10px; }
''';

String _esc(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
