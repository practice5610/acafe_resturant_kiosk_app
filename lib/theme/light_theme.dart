import 'package:flutter/material.dart';
import 'package:acafe_customer/theme/brand_colors.dart';
import 'package:acafe_customer/theme/custom_theme_colors.dart';
import 'package:acafe_customer/utill/dimensions.dart';

ThemeData light = ThemeData(
  fontFamily: 'Rubik',
  primaryColor: BrandColors.primary,
  scaffoldBackgroundColor: BrandColors.background,
  canvasColor: BrandColors.background,
  secondaryHeaderColor: BrandColors.secondary,
  brightness: Brightness.light,
  cardColor: Colors.white,
  hintColor: const Color(0xFF9F9F9F),
  disabledColor: const Color(0xFFBABFC4),
  shadowColor: Colors.grey[300],
  splashFactory: NoSplash.splashFactory,
  splashColor: Colors.transparent,
  highlightColor: Colors.transparent,
  hoverColor: Colors.transparent,
  focusColor: Colors.transparent,
  pageTransitionsTheme: const PageTransitionsTheme(builders: {
    TargetPlatform.android: ZoomPageTransitionsBuilder(),
    TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
    TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
  }),

  popupMenuTheme: const PopupMenuThemeData(color: Colors.white, surfaceTintColor: Colors.white),
  dialogTheme: const DialogThemeData(surfaceTintColor: Colors.white),

  extensions: <ThemeExtension<CustomThemeColors>>[
    CustomThemeColors.light(),
  ],

  colorScheme: const ColorScheme(
    brightness: Brightness.light,
    primary: BrandColors.primary,
    onPrimary: BrandColors.onPrimary,
    secondary: BrandColors.secondary,
    onSecondary: BrandColors.onBackground,
    error: Colors.redAccent,
    onError: Colors.redAccent,
    surface: BrandColors.background,
    onSurface: BrandColors.onBackground,
    shadow: Color(0xFFDCDCDC),
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: BrandColors.primary,
    foregroundColor: BrandColors.onPrimary,
    elevation: 0,
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: BrandColors.primary,
      foregroundColor: BrandColors.onPrimary,
      elevation: 0,
      shadowColor: Colors.transparent,
    ).copyWith(
      overlayColor: WidgetStateProperty.all(Colors.transparent),
    ),
  ),

  textButtonTheme: TextButtonThemeData(
    style: ButtonStyle(
      overlayColor: WidgetStateProperty.all(Colors.transparent),
    ),
  ),

  iconButtonTheme: IconButtonThemeData(
    style: ButtonStyle(
      overlayColor: WidgetStateProperty.all(Colors.transparent),
    ),
  ),

  cardTheme: const CardThemeData(
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
  ),

  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: BrandColors.primary,
    foregroundColor: BrandColors.onPrimary,
  ),

  progressIndicatorTheme: const ProgressIndicatorThemeData(
    color: BrandColors.primary,
  ),

  textTheme: const TextTheme(
    displayLarge: TextStyle(fontWeight: FontWeight.w300, fontSize: Dimensions.fontSizeDefault),
    displayMedium: TextStyle(fontWeight: FontWeight.w400,fontSize: Dimensions.fontSizeDefault),
    displaySmall: TextStyle(fontWeight: FontWeight.w500, fontSize: Dimensions.fontSizeDefault),
    headlineMedium: TextStyle(fontWeight: FontWeight.w600, fontSize: Dimensions.fontSizeDefault),
    headlineSmall: TextStyle(fontWeight: FontWeight.w700,  fontSize: Dimensions.fontSizeDefault),
    titleLarge: TextStyle(fontWeight: FontWeight.w800,  fontSize: Dimensions.fontSizeDefault),
    bodySmall: TextStyle(fontWeight: FontWeight.w900,  fontSize: Dimensions.fontSizeDefault),
    titleMedium: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500),
    bodyMedium: TextStyle(fontSize: 12.0),
    bodyLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
  ), tabBarTheme: TabBarThemeData(indicatorColor: BrandColors.primary),
);
