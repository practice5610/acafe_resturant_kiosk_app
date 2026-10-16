import 'package:flutter/foundation.dart';

/// Immutable snapshot of an invoice returned by the backend.
class PosInvoiceResult {
  final int invoiceId;
  final int orderId;
  final String companyName;
  final String? vatNumber;
  final String? email;
  final bool sendByEmail;
  final String status;
  final String? reference;
  final double grandTotal;
  final String? createdAt;

  const PosInvoiceResult({
    required this.invoiceId,
    required this.orderId,
    required this.companyName,
    this.vatNumber,
    this.email,
    required this.sendByEmail,
    required this.status,
    this.reference,
    required this.grandTotal,
    this.createdAt,
  });

  factory PosInvoiceResult.fromJson(Map<String, dynamic> j) =>
      PosInvoiceResult(
        invoiceId: (j['invoice_id'] as num).toInt(),
        orderId: (j['order_id'] as num).toInt(),
        companyName: j['company_name'] as String,
        vatNumber: j['vat_number'] as String?,
        email: j['email'] as String?,
        sendByEmail: (j['send_by_email'] as bool?) ?? false,
        status: (j['status'] as String?) ?? 'pending',
        reference: j['reference'] as String?,
        grandTotal: (j['grand_total'] as num).toDouble(),
        createdAt: j['created_at'] as String?,
      );
}

/// Mutable form state held in ValueNotifiers — one notifier per field so only
/// the relevant widget rebuilds on change.
class PosInvoiceFormState {
  final companyName = ValueNotifier<String>('');
  final vatNumber = ValueNotifier<String>('');
  final email = ValueNotifier<String>('');
  final sendByEmail = ValueNotifier<bool>(false);

  void dispose() {
    companyName.dispose();
    vatNumber.dispose();
    email.dispose();
    sendByEmail.dispose();
  }

  bool get isValid => companyName.value.trim().isNotEmpty;

  Map<String, dynamic> toPayload({
    required int orderId,
    required int deviceId,
    String? reference,
  }) =>
      {
        'order_id': orderId,
        'company_name': companyName.value.trim(),
        if (vatNumber.value.trim().isNotEmpty) 'vat_number': vatNumber.value.trim(),
        if (email.value.trim().isNotEmpty) 'email': email.value.trim(),
        'send_by_email': sendByEmail.value,
        'device_id': deviceId,
        if (reference != null) 'reference': reference,
      };
}
