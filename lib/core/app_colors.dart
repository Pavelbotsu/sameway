import 'package:flutter/material.dart';

abstract class AppColors {
  static const background = Color(0xFF08080F);
  static const surface = Color(0xFF10101C);
  static const card = Color(0xFF181828);
  static const primary = Color(0xFF7C6FFF);
  static const primaryDark = Color(0xFF5A4FD6);
  static const teal = Color(0xFF00D4BC);
  static const tealDark = Color(0xFF00A896);
  static const textPrimary = Colors.white;
  static const textSecondary = Color(0xFF8794B0);
  // Dark slate gray for labels rendered over the light map (e.g. the role
  // pill), where white text washes out. Intentionally gray, not pure black.
  static const mapLabelText = Color(0xFF3A3F52);
  static const border = Color(0xFF1E2038);
  static const error = Color(0xFFFF5E5E);
  static const success = Color(0xFF4DC987);

  // Text and icons ON the bright accent fills (teal, success, error):
  // white on them is only 1.9–3:1, this dark ink is 6.7–10.6:1 (WCAG AA).
  static const onAccent = Color(0xFF08080F);

  // Fills behind WHITE text. No single purple reaches 4.5:1 both under
  // white text and as text on the dark background, so buttons get their
  // own: white on primaryFill is 5.3:1 (primary is 3.8:1).
  static const primaryFill = Color(0xFF6355E8);
  // SOS and other red buttons with white text: 5.0:1 (error is 3.0:1).
  static const danger = Color(0xFFD32F2F);
}
