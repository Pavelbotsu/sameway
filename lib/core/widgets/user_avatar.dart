import 'package:flutter/material.dart';

import '../app_colors.dart';

/// Avatar with photo when available, deterministic initials-in-colored-circle
/// otherwise. Same widget across offer card, accepted card, request tiles —
/// no more ad-hoc colored-circle containers.
class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? name;
  final double size;
  final bool ring;
  // When set, the avatar participates in a Hero transition. Mount the same
  // tag at the offer/accepted/active-ride callsites so the avatar morphs
  // smoothly as the state card swaps under AnimatedSwitcher.
  final Object? heroTag;
  // Phase 3.2: identity-verified flag. We gate the overlay on `true` only —
  // an unverified user never sees a "not verified" mark, so the badge is a
  // pure positive signal that appears when verification turns on later.
  final bool verified;

  const UserAvatar({
    super.key,
    this.photoUrl,
    this.name,
    this.size = 44,
    this.ring = true,
    this.heroTag,
    this.verified = false,
  });

  String get _initials {
    final raw = (name ?? '').trim();
    if (raw.isEmpty) return '?';
    final parts = raw.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Color get _bg {
    // Stable hash → palette index. Same name always lands on the same color.
    final palette = <Color>[
      AppColors.primary,
      AppColors.teal,
      AppColors.success,
      const Color(0xFFFFB938),
      const Color(0xFFEE6C6C),
    ];
    final h = (name ?? '?').codeUnits.fold<int>(0, (a, b) => a + b);
    return palette[h % palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final has = photoUrl != null && photoUrl!.trim().isNotEmpty;
    final inner = SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: has
            ? Image.network(
                photoUrl!,
                fit: BoxFit.cover,
                // On network failure fall back to initials. Image.network
                // errorBuilder is the cheapest hook for this.
                errorBuilder: (_, __, ___) => _initialsCircle(),
              )
            : _initialsCircle(),
      ),
    );
    Widget wrapped = inner;
    if (ring) {
      wrapped = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: ClipOval(child: inner),
      );
    }
    if (verified) {
      // Small teal check overlay anchored bottom-right. Scales with `size`
      // so it stays proportional on both 44 px tiles and 64 px hero avatars.
      final badge = size * 0.34;
      wrapped = SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            wrapped,
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: badge,
                height: badge,
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.background,
                    width: badge * 0.12,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: badge * 0.7,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (heroTag != null) {
      wrapped = Hero(tag: heroTag!, child: wrapped);
    }
    return wrapped;
  }

  Widget _initialsCircle() {
    return Container(
      color: _bg,
      alignment: Alignment.center,
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
