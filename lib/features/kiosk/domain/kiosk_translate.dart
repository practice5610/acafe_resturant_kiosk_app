import 'package:flutter/widgets.dart';
import 'package:acafe_customer/localization/language_constrants.dart';

/// Translation lookup that actually falls back.
///
/// `getTranslated` echoes the KEY back when the lookup fails — its `translate`
/// throws on a missing key and the catch leaves the key in place — so the
/// common `getTranslated(k, context) ?? 'Fallback'` idiom never fires its
/// fallback and the kiosk renders raw keys like `CUP_OR_CAN` at the customer.
/// This is the same guard `kiosk_language_sheet` already applies locally, kept
/// here so the customization flow can share it.
String kioskTranslate(BuildContext context, String key, String fallback) {
  final String? value = getTranslated(key, context);
  if (value == null || value.isEmpty || value == key) return fallback;
  return value;
}
