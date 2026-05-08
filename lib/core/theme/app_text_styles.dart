import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get displayLarge => GoogleFonts.spaceGrotesk(
    fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5,
  );

  static TextStyle get displayMedium => GoogleFonts.spaceGrotesk(
    fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.3,
  );

  static TextStyle get titleLarge => GoogleFonts.spaceGrotesk(
    fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );

  static TextStyle get titleMedium => GoogleFonts.spaceGrotesk(
    fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.spaceGrotesk(
    fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
  );

  static TextStyle get bodyMedium => GoogleFonts.spaceGrotesk(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
  );

  static TextStyle get bodySmall => GoogleFonts.spaceGrotesk(
    fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecond,
  );

  static TextStyle get labelLarge => GoogleFonts.spaceGrotesk(
    fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary, letterSpacing: 0.5,
  );

  static TextStyle get labelSmall => GoogleFonts.spaceGrotesk(
    fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecond, letterSpacing: 0.8,
  );

  static TextStyle get orangeLabel => GoogleFonts.spaceGrotesk(
    fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orange, letterSpacing: 1.0,
  );
}
