import 'dart:async';
import 'package:flutter/material.dart';
import 'package:acafe_customer/di_container.dart' as di;
import 'package:acafe_customer/common/models/api_response_model.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_order_repo.dart';
import 'package:acafe_customer/features/kiosk/domain/kiosk_session.dart';
import 'package:acafe_customer/helper/router_helper.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:acafe_customer/utill/dimensions.dart';
import 'package:acafe_customer/utill/styles.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Order placed — shows the order number plus a QR + loyalty offer ("install the
/// app, get points, your order will be waiting"), then auto-resets to the
/// attract screen for the next customer.
class KioskSuccessScreen extends StatefulWidget {
  const KioskSuccessScreen({super.key});

  @override
  State<KioskSuccessScreen> createState() => _KioskSuccessScreenState();
}

class _KioskSuccessScreenState extends State<KioskSuccessScreen> {
  // Longer than the plain confirmation so a customer has time to scan the QR;
  // a "Done" button lets them dismiss sooner.
  static const int _idleTimeoutSeconds = 40;

  Timer? _resetTimer;
  bool _loadingOffer = true;
  String? _smartLink;
  String? _claimCode;
  int _pointsOffer = 0;

  @override
  void initState() {
    super.initState();
    _resetTimer = Timer(const Duration(seconds: _idleTimeoutSeconds), _reset);
    _loadClaimOffer();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadClaimOffer() async {
    final orderId = KioskSession.instance.lastOrderId;
    if (orderId == null || orderId.isEmpty) {
      if (mounted) setState(() => _loadingOffer = false);
      return;
    }
    final ApiResponseModel res =
        await di.sl<KioskOrderRepo>().getClaimToken(orderId);
    if (!mounted) return;
    if (res.response != null && res.response!.statusCode == 200) {
      final data = res.response!.data;
      setState(() {
        _smartLink = data['smart_link']?.toString();
        _claimCode = data['claim_code']?.toString();
        _pointsOffer = data['points_offer'] is int
            ? data['points_offer']
            : int.tryParse('${data['points_offer']}') ?? 0;
        _loadingOffer = false;
      });
    } else {
      // Don't block the customer if the offer can't be minted — show the plain
      // confirmation.
      setState(() => _loadingOffer = false);
    }
  }

  void _reset() {
    KioskSession.instance.reset();
    // Return straight to the menu (home) screen for the next customer.
    if (mounted) context.go(RouterHelper.kioskMenuScreen);
  }

  @override
  Widget build(BuildContext context) {
    final orderNumber = KioskSession.instance.lastOrderNumber;
    final name = KioskSession.instance.customerName;
    final bool hasOffer = _smartLink != null && _smartLink!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor:
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.check_rounded,
                      size: 52, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(height: Dimensions.paddingSizeLarge),
                Text(
                  getTranslated('thanks_for_your_order', context) ??
                      'Thanks for your order',
                  textAlign: TextAlign.center,
                  style: rubikSemiBold.copyWith(
                      fontSize: Dimensions.fontSizeExtraLarge,
                      color: Theme.of(context).textTheme.bodyLarge!.color),
                ),
                if (name.isNotEmpty) ...[
                  const SizedBox(height: Dimensions.paddingSizeSmall),
                  Text(name,
                      style: rubikRegular.copyWith(
                          color: Theme.of(context).hintColor)),
                ],
                if (orderNumber != null) ...[
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  Text(getTranslated('order_number', context) ?? 'Order number',
                      style: rubikRegular.copyWith(
                          color: Theme.of(context).hintColor)),
                  const SizedBox(height: 4),
                  Text(orderNumber,
                      style: rubikBold.copyWith(
                          fontSize: 38,
                          color: Theme.of(context).primaryColor)),
                ],

                if (_loadingOffer) ...[
                  const SizedBox(height: Dimensions.paddingSizeExtraLarge),
                  const SizedBox(
                      height: 26,
                      width: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.5)),
                ] else if (hasOffer) ...[
                  const SizedBox(height: Dimensions.paddingSizeLarge),
                  _buildOfferCard(context),
                ],

                const SizedBox(height: Dimensions.paddingSizeLarge),
                TextButton(
                    onPressed: _reset,
                    child: Text(getTranslated('done', context) ?? 'Done')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOfferCard(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.all(Dimensions.paddingSizeLarge),
      decoration: BoxDecoration(
        color: BrandColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: BrandColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            decoration: BoxDecoration(
              color: BrandColors.primary,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              '+$_pointsOffer ${getTranslated('loyalty_points', context) ?? 'loyalty points'}',
              style: rubikBold.copyWith(color: Colors.white, fontSize: 15),
            ),
          ),
          const SizedBox(height: Dimensions.paddingSizeDefault),
          Text(
            getTranslated('scan_to_install_offer', context) ??
                'Scan to install the A/CAFÉ app & get your points',
            textAlign: TextAlign.center,
            style: rubikSemiBold.copyWith(fontSize: 17),
          ),
          const SizedBox(height: 4),
          Text(
            getTranslated('your_order_will_be_waiting', context) ??
                'Your order will be waiting in the app — usable at any branch.',
            textAlign: TextAlign.center,
            style: rubikRegular.copyWith(
                color: Theme.of(context).hintColor, fontSize: 13),
          ),
          const SizedBox(height: Dimensions.paddingSizeLarge),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: _smartLink!,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: BrandColors.primaryDark,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: BrandColors.primaryDark,
              ),
            ),
          ),
          if (_claimCode != null) ...[
            const SizedBox(height: Dimensions.paddingSizeDefault),
            Text(
              getTranslated('or_enter_code_in_app', context) ??
                  'Or enter this code in the app',
              style: rubikRegular.copyWith(
                  color: Theme.of(context).hintColor, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              _claimCode!,
              style: rubikBold.copyWith(
                  fontSize: 22,
                  letterSpacing: 2,
                  color: BrandColors.primary),
            ),
          ],
        ],
      ),
    );
  }
}
