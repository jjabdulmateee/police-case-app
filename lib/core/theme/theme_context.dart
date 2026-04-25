import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Theme-aware colors for screens that still use explicit [AppColors] patterns.
extension PoliceThemeColors on BuildContext {
  bool get isPoliceDark => Theme.of(this).brightness == Brightness.dark;

  Color get policeScaffold =>
      isPoliceDark ? AppColors.darkBackground : AppColors.surface;

  Color get policeCard =>
      isPoliceDark ? AppColors.darkCard : AppColors.surfaceCard;

  Color get policeTextPrimary =>
      isPoliceDark ? AppColors.darkTextPrimary : AppColors.textPrimary;

  Color get policeTextSecondary =>
      isPoliceDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

  Color get policeTextHint =>
      isPoliceDark ? AppColors.darkTextSecondary.withValues(alpha: 0.85) : AppColors.textHint;

  Color get policeBorder =>
      isPoliceDark ? AppColors.darkBorder : const Color(0xFFF0F0F0);

  Color get policeDivider =>
      isPoliceDark ? AppColors.darkBorder.withValues(alpha: 0.6) : Colors.grey.shade100;

  Color get policeNavBar =>
      isPoliceDark ? AppColors.darkSurface : AppColors.surfaceCard;

  Color get policeDialogShadow =>
      isPoliceDark ? AppColors.darkShadow : AppColors.shadowMedium;

  Color get policeIconButtonBg =>
      isPoliceDark ? AppColors.darkCard : Colors.white;

  Color get policeDocumentPaper =>
      isPoliceDark ? AppColors.darkCard : Colors.white;

  Color get policeBottomBarBg =>
      isPoliceDark ? AppColors.darkSurface : Colors.white;
}
