import 'package:flutter/material.dart';

import 'sw_colors.dart';

/// Who the user is right now. Purple = driver, teal = passenger.
enum SwRole { driver, passenger }

/// Role colours as a ThemeExtension, so every widget reads the active role
/// via `context.role` instead of hard-coding purple or teal.
/// Never use role colour alone: always pair it with an icon and a word.
@immutable
class RoleColors extends ThemeExtension<RoleColors> {
  const RoleColors({
    required this.role,
    required this.fill,
    required this.onDark,
    required this.tint,
    required this.tintLine,
    required this.onLight,
  });

  final SwRole role;

  /// Primary buttons, routes, markers. Text on it is [SwColors.onAccent].
  final Color fill;

  /// Role-coloured text and icons on dark surfaces.
  final Color onDark;

  /// Selected chips, pinned cards, the pickup-code panel.
  final Color tint;

  /// Border of a [tint] panel.
  final Color tintLine;

  /// Role-coloured text on light surfaces (snackbar action).
  final Color onLight;

  static const driver = RoleColors(
    role: SwRole.driver,
    fill: SwColors.driver,
    onDark: SwColors.driverOnDark,
    tint: SwColors.driverTint,
    tintLine: SwColors.driverTintLine,
    onLight: SwColors.driverOnLight,
  );

  static const passenger = RoleColors(
    role: SwRole.passenger,
    fill: SwColors.passenger,
    onDark: SwColors.passengerOnDark,
    tint: SwColors.passengerTint,
    tintLine: SwColors.passengerTintLine,
    onLight: SwColors.passengerOnLight,
  );

  static RoleColors of(SwRole role) =>
      role == SwRole.driver ? driver : passenger;

  bool get isDriver => role == SwRole.driver;

  /// The icon that goes with the role colour (never colour alone).
  IconData get icon =>
      isDriver ? Icons.directions_car_outlined : Icons.person_outline;

  @override
  RoleColors copyWith({
    SwRole? role,
    Color? fill,
    Color? onDark,
    Color? tint,
    Color? tintLine,
    Color? onLight,
  }) =>
      RoleColors(
        role: role ?? this.role,
        fill: fill ?? this.fill,
        onDark: onDark ?? this.onDark,
        tint: tint ?? this.tint,
        tintLine: tintLine ?? this.tintLine,
        onLight: onLight ?? this.onLight,
      );

  @override
  RoleColors lerp(RoleColors? other, double t) => other == null
      ? this
      : RoleColors(
          role: t < .5 ? role : other.role,
          fill: Color.lerp(fill, other.fill, t)!,
          onDark: Color.lerp(onDark, other.onDark, t)!,
          tint: Color.lerp(tint, other.tint, t)!,
          tintLine: Color.lerp(tintLine, other.tintLine, t)!,
          onLight: Color.lerp(onLight, other.onLight, t)!,
        );
}

extension RoleX on BuildContext {
  /// The active role's colours. Falls back to passenger outside a
  /// `SwTheme` (e.g. old screens), so a component never crashes.
  RoleColors get role =>
      Theme.of(this).extension<RoleColors>() ?? RoleColors.passenger;
}
