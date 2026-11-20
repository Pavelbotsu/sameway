import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Round avatar: photo, or initials on a neutral fill picked from the name.
/// [ring] draws the role colour around it (the person's role on maps and
/// cards). Initials don't scale with the text size: the circle is a fixed
/// image and its meaning is in [name] for screen readers.
class SwAvatar extends StatelessWidget {
  const SwAvatar({
    super.key,
    required this.name,
    this.image,
    this.size = 32,
    this.ring = false,
    this.excludeFromSemantics = false,
  });

  /// Display name; the first letter(s) become the initials.
  final String name;
  final ImageProvider? image;
  final double size;
  final bool ring;

  /// Set when the name is already read next to the avatar.
  final bool excludeFromSemantics;

  /// One letter, as on the board ("M", "K").
  static String initialsOf(String name) {
    final t = name.trim();
    return t.isEmpty ? '?' : t.characters.first.toUpperCase();
  }

  static Color fillFor(String name) {
    var h = 0;
    for (final c in name.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return SwColors.avatarFills[h % SwColors.avatarFills.length];
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = (size * 0.4).clamp(SwType.minSize, 40.0);
    Widget circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fillFor(name),
        image: image == null ? null : DecorationImage(image: image!, fit: BoxFit.cover),
      ),
      child: image != null
          ? null
          : Text(
              initialsOf(name),
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                  fontFamily: swFontFamily, fontSize: fontSize, fontWeight: FontWeight.w700,
                  height: 1, color: SwColors.text),
            ),
    );
    if (ring) {
      circle = Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: context.role.fill, width: 2)),
        child: circle,
      );
    }
    if (excludeFromSemantics) return ExcludeSemantics(child: circle);
    return Semantics(image: true, label: name, excludeSemantics: true, child: circle);
  }
}
