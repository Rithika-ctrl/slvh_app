import 'package:flutter/material.dart';

class AppColors {
  // Background gradients (matches your current main.dart)
  static const Color bgDark1 = Color(0xFF0F2027);
  static const Color bgDark2 = Color(0xFF203A43);
  static const Color bgDark3 = Color(0xFF2C5364);

  // Glass card
  static const Color glassWhite = Color(0x1AFFFFFF); // white 10% opacity
  static const Color glassBorder = Color(0x33FFFFFF); // white 20% opacity

  // Accent
  static const Color cyan = Colors.cyanAccent;
  static const Color cyanButton = Color(0xB2FFFFFF); // cyanAccent 70% opacity

  // Text
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textHint      = Color(0xFF607D8B);

  // Status
  static const Color success = Color(0xFF26A69A);
  static const Color error   = Color(0xFFEF5350);
  static const Color warning = Color(0xFFFFA726);

  // Gradient list (reuse anywhere)
  static const List<Color> bgGradient = [bgDark1, bgDark2, bgDark3];
}
