import 'package:flutter/painting.dart';

import 'sw_colors.dart';

/// Radius v3: inner 8 · field/segmented 12 · button/card 16 · sheet/dialog 20 · chips/avatars full.
abstract final class SwRadius {
  static const inner = 8.0;
  static const field = 12.0;
  static const segmented = 12.0;
  static const button = 16.0;
  static const card = 16.0;
  static const sheet = 20.0;
  static const dialog = 20.0;
  static const pill = 999.0;
}

/// Spacing 4 · 8 · 12 · 16 · 20 · 24. Screen padding 20, lists 16.
abstract final class SwSpace {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const screen = 20.0;
  static const list = 16.0;
}

abstract final class SwSize {
  /// Primary button height (full width, bottom, one per screen).
  static const button = 52.0;
  static const buttonSecondary = 48.0;

  /// Design minimum (iOS). Android tap targets are 48 dp.
  static const touch = 44.0;
  static const touchAndroid = 48.0;
  static const field = 56.0;
  static const chip = 40.0;
  static const badge = 26.0;
  static const tabBar = 84.0;
}

const swFontFamily = 'Inter';

/// Type scale v3, named as on the Main board. 13 px is the minimum anywhere.
/// Sentence case, no letter-spacing. Colour comes from the surrounding
/// DefaultTextStyle unless stated.
abstract final class SwType {
  static const minSize = 13.0;

  static const price = TextStyle(fontFamily: swFontFamily, fontSize: 44, fontWeight: FontWeight.w800, height: 1.1);
  static const screenTitle = TextStyle(fontFamily: swFontFamily, fontSize: 28, fontWeight: FontWeight.w800, height: 1.2);
  static const sheetTitle = TextStyle(fontFamily: swFontFamily, fontSize: 22, fontWeight: FontWeight.w700, height: 1.25);
  static const appBarTitle = TextStyle(fontFamily: swFontFamily, fontSize: 20, fontWeight: FontWeight.w700, height: 1.25);
  static const emphasis = TextStyle(fontFamily: swFontFamily, fontSize: 16, fontWeight: FontWeight.w600, height: 1.3);
  static const body = TextStyle(fontFamily: swFontFamily, fontSize: 15, fontWeight: FontWeight.w500, height: 1.45);
  static const groupLabel = TextStyle(fontFamily: swFontFamily, fontSize: 14, fontWeight: FontWeight.w600, height: 1.35);
  static const caption = TextStyle(fontFamily: swFontFamily, fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, color: SwColors.textSecondary);

  /// Text typed into a field (Main board: 500/16).
  static const input = TextStyle(fontFamily: swFontFamily, fontSize: 16, fontWeight: FontWeight.w500, height: 1.3);
}
