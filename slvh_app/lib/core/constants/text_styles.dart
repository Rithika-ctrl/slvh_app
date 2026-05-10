import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralised text styles for the SLVH app.
/// Import this file wherever you need a shared text style instead of
/// duplicating TextStyle(...) literals across the codebase.
class AppTextStyles {
  // ── Display / Hero ────────────────────────────────────────────
  static const TextStyle displayLarge = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w900,
    color: AppColors.orange,
    letterSpacing: 7,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    color: AppColors.textDark,
    letterSpacing: 0.5,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
  );

  // ── Headlines ─────────────────────────────────────────────────
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textDark,
  );

  // ── Body ──────────────────────────────────────────────────────
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textDark,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textMid,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
    height: 1.4,
  );

  // ── Labels / Captions ─────────────────────────────────────────
  static const TextStyle labelLarge = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
    letterSpacing: 0.3,
  );

  static const TextStyle labelMedium = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
    letterSpacing: 0.5,
  );

  static const TextStyle labelSmall = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    color: AppColors.textMuted,
    letterSpacing: 1,
  );

  // ── Buttons ───────────────────────────────────────────────────
  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: Colors.white,
    letterSpacing: 0.3,
  );

  // ── Price ─────────────────────────────────────────────────────
  static const TextStyle priceLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: AppColors.orange,
  );

  static const TextStyle priceMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    color: AppColors.orange,
  );

  static const TextStyle priceStrikethrough = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textHint,
    decoration: TextDecoration.lineThrough,
  );

  // ── Input ─────────────────────────────────────────────────────
  static const TextStyle inputText = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w800,
    color: AppColors.textDark,
    letterSpacing: 2,
  );

  static const TextStyle inputHint = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: AppColors.textHint,
  );

  static const TextStyle inputError = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.error,
  );

  // ── Status / Badge ────────────────────────────────────────────
  static const TextStyle statusBadge = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
  );

  // ── Navigation / Tab ──────────────────────────────────────────
  static const TextStyle navLabel = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.3,
  );

  // ── Section header ────────────────────────────────────────────
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: AppColors.textMuted,
    letterSpacing: 2,
  );
}
