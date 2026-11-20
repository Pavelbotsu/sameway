import 'package:flutter/painting.dart';

/// Design system v3 colours (design-pack/design/tokens.json, Main board).
/// The only place in the app where v3 hex values live; widgets read these
/// or `context.role`, never hex.
///
/// Neutrals are plain near-black with no purple tint. Purple only means
/// "driver", teal only means "passenger": see [RoleColors].
abstract final class SwColors {
  // Surfaces: layers differ by colour, never by shadow.
  static const background = Color(0xFF0B0B0F); // app canvas, field fill
  static const surface1 = Color(0xFF141418); // sheets, bars
  static const surface2 = Color(0xFF1B1B21); // cards, groups
  static const surface3 = Color(0xFF26262E); // tracks, icon tiles, neutral badges

  /// Decorative divider. Never the only boundary of an input (1.3:1).
  static const line = Color(0xFF2B2B34);

  /// Field and control borders: 3:1 against every surface (WCAG 1.4.11).
  static const fieldBorder = Color(0xFF64647C);

  // Text
  static const text = Color(0xFFF2F2F7); // 17:1 on background
  static const textSecondary = Color(0xFFA6A5BD); // 7:1 on cards
  static const textTertiary = Color(0xFF8E8DA8); // 5:1 on cards

  /// Text and icons on purple / teal / red fills.
  static const onAccent = Color(0xFF0B0B14);

  // Role (prefer `context.role`, which follows the active role)
  static const driver = Color(0xFF7C6EFF);
  static const driverOnDark = Color(0xFFA99FFF); // purple TEXT on dark (7.7:1)
  static const driverTint = Color(0xFF221F48);
  static const passenger = Color(0xFF00D4BD);
  static const passengerOnDark = Color(0xFF5FF0DD);
  static const passengerTint = Color(0xFF06302E);
  // Border of a tint panel, and role text on light surfaces (snackbar).
  static const driverTintLine = Color(0xFF363072); // not drawn; matches the passenger pair
  static const passengerTintLine = Color(0xFF0E4A45); // Main board pickup code
  static const driverOnLight = Color(0xFF4B3FD9); // Main board snackbar "Undo"
  static const passengerOnLight = Color(0xFF00796B); // L_Screens teal on light

  // Status. Never a role colour.
  static const warning = Color(0xFFF5B83D); // deadlines, searching, unverified
  static const warningTint = Color(0xFF2A2210);
  static const danger = Color(0xFFFF7A7A); // cancel, delete, 112
  static const dangerTint = Color(0xFF2E1518);
  static const eco = Color(0xFF7BD88F); // CO2, "Saved on this phone"
  static const ecoTint = Color(0xFF0F2A1A);

  // On the Main board but not in tokens.json (DESIGN_DEBT.md, v3 deviations).
  static const dangerLine = Color(0xFF4A2227); // border of the tinted danger button
  static const warningLine = Color(0xFF5A4614); // border of the warning banner
  static const snackbar = Color(0xFFF2F2F7); // snackbar is light on dark screens

  /// Scrim behind sheets and dialogs (no shadows in v3).
  static const scrim = Color(0xA6000000);

  /// Avatar fills when there is no photo, picked by name. White text on each
  /// is ≥ 8:1. Main board (#3B3566, #4A3B2E) and L_Screens (#4A2E3A, #2E4A3A).
  static const avatarFills = <Color>[
    Color(0xFF3B3566),
    Color(0xFF4A3B2E),
    Color(0xFF4A2E3A),
    Color(0xFF2E4A3A),
  ];
}
