import 'package:flutter/material.dart';

/// Authoritative design system tokens inspired by Apple Human Interface Guidelines,
/// refined for dark cinema and OLED fidelity.
abstract final class AetherTokens {
  // ── Colors ──
  static const canvasBase = Color(0xFF000000); // Pure OLED pitch black
  static const surfaceElevated = Color(0xFF0B0F19);
  static const surfaceBorder = Color(0x14FFFFFF); // 8% white specular stroke
  static const surfaceHighlight = Color(0x28FFFFFF); // 16% white focus stroke

  static const accentPrimary = Color(0xFF6366F1); // Electric Indigo
  static const accentGold = Color(0xFFF59E0B);    // Primary Star Amber
  static const accentTeal = Color(0xFF06B6D4);    // Specular Horizon Cyan

  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xA6FFFFFF); // 65% white
  static const textMuted = Color(0x61FFFFFF);     // 38% white

  // ── Spacing ──
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;
  static const double space64 = 64.0;

  // ── Radii ──
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 14.0;
  static const double radiusLarge = 22.0;
  static const double radiusRound = 999.0;

  // ── Typography ──
  static const displayTitle = TextStyle(
    color: textPrimary,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
  );

  static const sectionHeader = TextStyle(
    color: textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const cardLabel = TextStyle(
    color: textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
  );

  static const badgeLabel = TextStyle(
    color: textPrimary,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );

  // ── Spring Motion Curves ──
  static const Duration animDurationFast = Duration(milliseconds: 180);
  static const Duration animDurationStandard = Duration(milliseconds: 320);
  static const Curve animCurveSpring = Curves.easeOutCubic;
}
