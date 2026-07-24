import 'package:flutter/material.dart';
import 'package:acafe_customer/features/kiosk/widgets/kiosk_ui.dart';

/// Shared colour tokens for the kiosk-themed search surfaces (search, results,
/// filter), matching the A/CAFÉ menu design: warm cream canvas, white rounded
/// cards, near-black primary and warm tan accent.
class KioskSearchTheme {
  KioskSearchTheme._();

  static const Color pageBg = KioskUI.pageBg; // global kiosk background
  static const Color surface = Color(0xFFFFFFFF); // cards / bars
  static const Color primary = Color(0xFF1E1E1E); // near-black
  static const Color creamText = Color(0xFFF3F3DD); // text on dark buttons
  static const Color border = Color(0xFFE8E2D5); // dividers / outlines
  static const Color muted = Color(0xFF8A8275); // secondary text
  static const Color accent = Color(0xFFC8A97E); // warm tan accent
}
