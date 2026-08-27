import 'package:acafe_customer/common/responsive/kiosk_responsive.dart';

export 'package:acafe_customer/common/responsive/kiosk_responsive.dart'
    show kKioskContentMaxWidth, kioskProductGridColumns;

/// Historical alias. Prefer [kioskProductGridColumns] keyed to the *measured*
/// product-area width; this wrapper exists so any leftover call site that
/// keyed off window width still compiles.
int menuGridColumns(double width) =>
    kioskProductGridColumns(areaWidth: width, gap: 24);
