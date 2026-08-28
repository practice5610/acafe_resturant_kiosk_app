import 'package:flutter/material.dart';
import 'package:acafe_customer/localization/language_constrants.dart';
import 'package:acafe_customer/main.dart';
import 'package:acafe_customer/features/splash/providers/splash_provider.dart';
import 'package:provider/provider.dart';

class PriceConverterHelper {
  static String convertPrice(double? price, {double? discount, String? discountType}) {
    // Never force-unwrap config / context here — the menu cart bar calls this
    // on every build, and a single null used to blank the entire /menu-kiosk.
    final BuildContext? ctx = Get.context;
    final configModel = ctx == null
        ? null
        : Provider.of<SplashProvider>(ctx, listen: false).configModel;
    final int decimals = configModel?.decimalPointSettings ?? 2;
    final String symbol = configModel?.currencySymbol ?? '€';
    final String position = configModel?.currencySymbolPosition ?? 'left';

    double value = price ?? 0;
    if (discount != null && discountType != null) {
      if (discountType == 'amount') {
        value = value - discount;
      } else if (discountType == 'percent') {
        value = value - ((discount / 100) * value);
      }
    }

    final String formatted = value.toStringAsFixed(decimals).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return position == 'left'
        ? '$symbol$formatted'
        : '$formatted $symbol';
  }

  static double? convertWithDiscount(double? price, double? discount, String? discountType) {
    if(discountType == 'amount' && (discount ?? 0) > 0) {
      price = price! - discount!;
    }else if(discountType == 'percent' && (discount ?? 0) > 0) {
      price = price! - ((discount! / 100) * price);
    }
    return price;
  }

  static double addonTaxCalculation({double? taxPercentage,  double? addonItemPrice, int? quantity, String? discountType}){
    double taxAmount = 0;
    if(discountType == 'percent' && taxPercentage != null && addonItemPrice != null){
      taxAmount = (addonItemPrice * (quantity ?? 1)) * ((taxPercentage / 100));
    }else if (discountType == 'amount'){
      taxAmount = (quantity ?? 1) * (taxPercentage ?? 1);
    }
    return taxAmount;
  }



  /// Discount amount in currency, 0 when there is no discount.
  /// Anything that is not a type the app can compute ('off', null, unknown)
  /// means "no discount" — returning the untouched price here made the widgets
  /// draw a struck-through old price identical to the new one.
  static double? convertDiscount(BuildContext context, double? price, double? discount, String? discountType) {
    if(discountType == 'amount') {
      return discount ?? 0;
    }else if(discountType == 'percent') {
      return ((discount ?? 0) / 100) * (price ?? 0);
    }
    return 0;
  }

  static double calculation(double amount, double discount, String type, int quantity) {
    double calculatedAmount = 0;
    if(type == 'amount') {
      calculatedAmount = discount * quantity;
    }else if(type == 'percent') {
      calculatedAmount = (discount / 100) * (amount * quantity);
    }
    return calculatedAmount;
  }

  static String getDiscountType({required double? discount, required String? discountType}) {
   return '${discountType == 'percent' ? '${discount?.toInt()} %' : PriceConverterHelper.convertPrice(discount)} ${getTranslated('off', Get.context!)}';
  }


  static String longToShortPrice(double amount){
    int decimalPoint = 2 ;

    if (amount.abs() >= 1e12) {
      return '${(amount / 1e12).toStringAsFixed(decimalPoint)}T';
    } else if (amount.abs() >= 1e9) {
      return '${(amount / 1e9).toStringAsFixed(decimalPoint)}B';
    } else if (amount.abs() >= 1e6) {
      return '${(amount / 1e6).toStringAsFixed(decimalPoint)}M';
    } else {
      return amount.toStringAsFixed(decimalPoint);
    }
  }

}
