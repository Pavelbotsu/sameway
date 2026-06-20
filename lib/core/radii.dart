import 'package:flutter/widgets.dart';

/// Three corner-radius tokens — 12 / 16 / 24. The existing theme already
/// settled on those three for chips, cards, and sheets respectively, but
/// individual call sites mix 14/18/20/28 ad-hoc. New code should reach
/// for these so a future visual-rhythm sweep has a single source of truth.
abstract class Radii {
  static const double s = 12; // chips, plate, snack bar
  static const double m = 16; // cards, inputs, tiles
  static const double l = 24; // bottom sheets, hero containers

  static const BorderRadius rsS = BorderRadius.all(Radius.circular(s));
  static const BorderRadius rsM = BorderRadius.all(Radius.circular(m));
  static const BorderRadius rsL = BorderRadius.all(Radius.circular(l));

  // Sheet variant — only top corners rounded.
  static const BorderRadius sheetL = BorderRadius.vertical(
    top: Radius.circular(l),
  );
}
