import 'package:flutter/material.dart';

import '../theme/theme.dart';

const _badgeText = TextStyle(
    fontFamily: swFontFamily, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3);

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg, this.icon, this.liveRegion = false});
  final String label;
  final Color bg, fg;
  final IconData? icon;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: liveRegion,
      child: Container(
        constraints: const BoxConstraints(minHeight: SwSize.badge),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(SwRadius.pill)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              // Scales with the label so the icon still reads at 200 %.
              Icon(icon, size: MediaQuery.textScalerOf(context).scale(14), color: fg),
              const SizedBox(width: SwSpace.s4),
            ],
            Flexible(child: Text(label, style: _badgeText.copyWith(color: fg))),
          ],
        ),
      ),
    );
  }
}

/// Ride state badge. Ride states (Confirmed, Requested, Searching) are
/// always neutral. Amber ([SwStatusBadge.deadline]) only for deadlines and
/// warnings ("Answer by Thu 10:00"): deadlines always carry a day name.
class SwStatusBadge extends StatelessWidget {
  const SwStatusBadge(this.label, {super.key, this.liveRegion = false}) : _deadline = false;

  const SwStatusBadge.deadline(this.label, {super.key, this.liveRegion = false}) : _deadline = true;

  final String label;

  /// Set when the badge changes in place, so the change is announced.
  final bool liveRegion;
  final bool _deadline;

  @override
  Widget build(BuildContext context) => _Pill(
        label: label,
        bg: _deadline ? SwColors.warningTint : SwColors.surface3,
        fg: _deadline ? SwColors.warning : SwColors.text,
        liveRegion: liveRegion,
      );
}

/// Role-tinted tag with an icon ("Your people"). Never colour alone.
class SwTagBadge extends StatelessWidget {
  const SwTagBadge(this.label, {super.key, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final role = context.role;
    return _Pill(label: label, bg: role.tint, fg: role.onDark, icon: icon);
  }
}
