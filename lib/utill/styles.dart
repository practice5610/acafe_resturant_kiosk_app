import 'package:flutter/material.dart';
import 'package:acafe_customer/utill/dimensions.dart';

const rubikRegular = TextStyle(
  fontFamily: 'Rubik',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w400,
);

const rubikMedium = TextStyle(
  fontFamily: 'Rubik',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w500,
);

const rubikSemiBold = TextStyle(
  fontFamily: 'Rubik',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w600,
);

const rubikBold = TextStyle(
  fontFamily: 'Rubik',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w700,
);

const poppinsRegular = TextStyle(
  fontFamily: 'Poppins',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w400,
);

const robotoRegular = TextStyle(
  fontFamily: 'Roboto',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w400,
);

// Figma kiosk fonts, registered in pubspec.yaml: Loew 400/500/700/800 and
// "Swiss721" 400/500. The Swiss721 family is really Nunito Sans (see the note
// in pubspec.yaml), so `swiss721Light` draws Nunito Sans Regular and
// `swiss721Medium` Nunito Sans Medium.
const loewRegular = TextStyle(
  fontFamily: 'Loew',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w400,
);

const loewRegular700 = TextStyle(
  fontFamily: 'Loew',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w700,
);

const loewRegular800 = TextStyle(
  fontFamily: 'Loew',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w800,
);

const loewMedium = TextStyle(
  fontFamily: 'Loew',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w500,
);

const loewBold = TextStyle(
  fontFamily: 'Loew',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w700,
);

const loewExtraBold = TextStyle(
  fontFamily: 'Loew',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w800,
);

const swiss721Light = TextStyle(
  fontFamily: 'Swiss721',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w300,
);

/// Small detail copy (add-on and variation picks under a line item): one step
/// heavier than [swiss721Light], so 11–12 px strokes stay solid on 1× kiosk
/// and desktop displays instead of anti-aliasing to grey.
const swiss721Medium = TextStyle(
  fontFamily: 'Swiss721',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w500,
);

const scotchDisplayLight = TextStyle(
  fontFamily: 'ScotchDisplay',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w300,
);

const scotchDisplayCondLight = TextStyle(
  fontFamily: 'ScotchDisplayCond',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w300,
);

// Inter — POS Report Overview card text (Figma 1915:18091). Bundled at
// 400/600/700/800 in pubspec.yaml; any other weight would be synthesised.
const interRegular = TextStyle(
  fontFamily: 'Inter',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w400,
);

const interSemiBold = TextStyle(
  fontFamily: 'Inter',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w600,
);

const interBold = TextStyle(
  fontFamily: 'Inter',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w700,
);

const interExtraBold = TextStyle(
  fontFamily: 'Inter',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w800,
);

/// Monospace — receipt/ticket rendering only (POS Settings → Hardware preview).
/// Bundled rather than borrowed from the host: CanvasKit does not resolve a
/// generic `monospace` family on the web.
const robotoMonoRegular = TextStyle(
  fontFamily: 'RobotoMono',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w400,
);

const robotoMonoBold = TextStyle(
  fontFamily: 'RobotoMono',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w700,
);

/// Receipt preview body rows (POS Settings → Hardware, Figma 1915:18000).
const jetBrainsMonoRegular = TextStyle(
  fontFamily: 'JetBrainsMono',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w400,
);

const jetBrainsMonoBold = TextStyle(
  fontFamily: 'JetBrainsMono',
  fontSize: Dimensions.fontSizeDefault,
  fontWeight: FontWeight.w700,
);
