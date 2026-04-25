import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0A1929);
  static const Color primaryLight = Color(0xFF132F4C);
  static const Color primaryMedium = Color(0xFF1A3A5C);

  static const Color accent = Color(0xFF3399FF);
  static const Color accentLight = Color(0xFF66B2FF);
  static const Color accentSoft = Color(0xFF1A3A5C);

  static const Color surface = Color(0xFFF8FAFD);
  static const Color surfaceCard = Colors.white;
  static const Color surfaceDark = Color(0xFF0D2137);

  static const Color textPrimary = Color(0xFF0A1929);
  static const Color textSecondary = Color(0xFF5A6A7A);
  static const Color textHint = Color(0xFF9AA5B4);
  static const Color textOnDark = Color(0xFFF0F4F8);

  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);

  static const List<Color> micGradient = [
    Color(0xFF3399FF),
    Color(0xFF1A73E8),
  ];

  static const List<Color> micListeningGradient = [
    Color(0xFFE74C3C),
    Color(0xFFC0392B),
  ];

  static const List<Color> confirmGradient = [
    Color(0xFF1A73E8),
    Color(0xFF0A47A1),
  ];

  static const Color shadowLight = Color(0x1A0A1929);
  static const Color shadowMedium = Color(0x330A1929);

  // Dark theme palette
  static const Color darkBackground = Color(0xFF0A0E1A);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkCard = Color(0xFF1A2235);
  static const Color darkAppBar = Color(0xFF0D1421);
  static const Color darkTextPrimary = Color(0xFFF0F4FF);
  static const Color darkTextSecondary = Color(0xFF8899AA);
  static const Color darkBorder = Color(0xFF2A3A4A);
  static const Color darkShadow = Color(0x66000000);
}
