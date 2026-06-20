import 'package:flutter/widgets.dart';

/// Six spacing tokens covering the design system's rhythm. New code should
/// reach for these instead of ad-hoc `EdgeInsets.all(14)` / `8` / `24` etc.
/// The names are intentionally short so a builder full of `Spacing.m` reads
/// cleanly. The numeric values match the 4-multiple grid the rest of the
/// theme already lives on.
abstract class Spacing {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 24;
  static const double xxl = 32;

  // Pre-built EdgeInsets for the common all/symmetric uses. These are the
  // ones that pile up in build methods, so having them as constants saves a
  // construction per rebuild and reads as `Spacing.allM` / `Spacing.hL`.
  static const EdgeInsets allXs = EdgeInsets.all(xs);
  static const EdgeInsets allS = EdgeInsets.all(s);
  static const EdgeInsets allM = EdgeInsets.all(m);
  static const EdgeInsets allL = EdgeInsets.all(l);
  static const EdgeInsets allXl = EdgeInsets.all(xl);

  static const EdgeInsets hS = EdgeInsets.symmetric(horizontal: s);
  static const EdgeInsets hM = EdgeInsets.symmetric(horizontal: m);
  static const EdgeInsets hL = EdgeInsets.symmetric(horizontal: l);

  static const EdgeInsets vS = EdgeInsets.symmetric(vertical: s);
  static const EdgeInsets vM = EdgeInsets.symmetric(vertical: m);
  static const EdgeInsets vL = EdgeInsets.symmetric(vertical: l);

  // SizedBox spacers for in-Column/Row gaps.
  static const SizedBox gapXs = SizedBox(width: xs, height: xs);
  static const SizedBox gapS = SizedBox(width: s, height: s);
  static const SizedBox gapM = SizedBox(width: m, height: m);
  static const SizedBox gapL = SizedBox(width: l, height: l);
  static const SizedBox gapXl = SizedBox(width: xl, height: xl);
}
