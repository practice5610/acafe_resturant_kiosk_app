import 'package:flutter/material.dart';
import 'package:acafe_customer/common/providers/theme_provider.dart';
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:provider/provider.dart';

class ColorResources {
  static Color getSearchBg(BuildContext context) {
    return Provider.of<ThemeProvider>(context).darkTheme
        ? const Color(0xFF585a5c)
        : BrandColors.background;
  }

  static Color getBackgroundColor(BuildContext context) {
    return Provider.of<ThemeProvider>(context).darkTheme
        ? BrandColors.backgroundDark
        : BrandColors.background;
  }

  static Color getHintColor(BuildContext context) {
    return Provider.of<ThemeProvider>(context).darkTheme
        ? const Color(0xFF98a1ab)
        : const Color(0xFF52575C);
  }

  static Color getGreyBunkerColor(BuildContext context) {
    return Provider.of<ThemeProvider>(context).darkTheme
        ? const Color(0xFFE4E8EC)
        : const Color(0xFF25282B);
  }

  static Color getCartTitleColor(BuildContext context) {
    return Provider.of<ThemeProvider>(context).darkTheme
        ? const Color(0xFF61699b)
        : BrandColors.primaryDark;
  }

  static Color getProfileMenuHeaderColor(BuildContext context) {
    return Provider.of<ThemeProvider>(context).darkTheme
        ? footerColor.withValues(alpha: 0.5)
        : footerColor.withValues(alpha: 0.2);
  }

  static Color getFooterColor(BuildContext context) {
    return Provider.of<ThemeProvider>(context).darkTheme
        ? const Color(0xFF494949)
        : BrandColors.primaryLight;
  }

  static Color getSecondaryColor(BuildContext context) {
    return BrandColors.secondary;
  }

  static Color getTertiaryColor(BuildContext context) {
    return Provider.of<ThemeProvider>(context).darkTheme
        ? const Color(0xFF2B2727)
        : BrandColors.background;
  }

  static const Color colorNero = Color(0xFF1F1F1F);
  static const Color searchBg = BrandColors.background;
  static const Color borderColor = Color(0xFFDCDCDC);
  static const Color cardBorderGrey = BrandColors.cardBorder;
  static const Color footerColor = BrandColors.primaryLight;
  static const Color cardShadowColor = Color(0xFFA7A7A7);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color onBoardingBgColor = BrandColors.primaryLight;
  static const Color homePageSectionTitleColor = BrandColors.onBackground;
  static const Color splashBackgroundColor = BrandColors.primary;

  static const Map<String, Color> buttonBackgroundColorMap = {
    'new': Color(0xffe9f3ff),
    'preparing': Color(0xfffff5da),
    'item_to_collect': Color(0xffe5f2ee),
    'completed': Color(0xffe5f2ee),
    'on_hold': Color(0xfff0ebff),
    'canceled': Color(0xffffeeee),
  };

  static const Map<String, Color> buttonTextColorMap = {
    'new': Color(0xff5686c6),
    'preparing': Color(0xffebb936),
    'item_to_collect': Color(0xff72b89f),
    'completed': Color(0xff2E7D32),
    'on_hold': Color(0xff6f42c1),
    'canceled': Color(0xffff6060),
  };
}
