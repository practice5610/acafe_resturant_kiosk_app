import 'package:acafe_customer/features/pos/domain/pos_general_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_hardware_settings.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_history.dart';
import 'package:acafe_customer/features/pos/domain/pos_receipt_print.dart';
import 'package:flutter_test/flutter_test.dart';

/// Receipts shows the tender the backend derives (PosTenders), including the
/// multi-tender sales. A split paid entirely by card used to read "Cash".
void main() {
  // posReceiptPrintHtml formats prices through Get.context.
  TestWidgetsFlutterBinding.ensureInitialized();

  const Map<String, String> labels = {
    'cash': 'Cash',
    'card': 'Card',
    'split': 'Split',
    'invoice': 'Invoice',
    'standalone': 'Stand-alone',
  };

  labels.forEach((String wire, String label) {
    test('display_method "$wire" reads "$label" in the list and the detail', () {
      expect(
        PosReceiptRow.fromJson({'id': 1, 'display_method': wire}).methodLabel,
        label,
      );
      expect(
        PosReceiptDetail.fromJson(
                {'id': 1, 'details': const [], 'display_method': wire})
            .methodLabel,
        label,
      );
    });
  });

  test('the printed receipt names a split, not "Cash"', () {
    final String html = posReceiptPrintHtml(
      PosReceiptDetail.fromJson(
          {'id': 100020, 'details': const [], 'display_method': 'split'}),
      hardware: PosHardwareSettings.initial(storeName: 'A/CAFÉ'),
      general: PosGeneralSettings.fromJson(const {}),
    );
    expect(html, contains('<span>Method</span><span>Split</span>'));
  });
}
