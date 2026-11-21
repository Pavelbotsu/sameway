import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'avatar.dart';
import 'layout.dart';

/// A driver going the same way in town (P_Offers): "Kasia · 9 min",
/// "Walk 450 m · drops you at the door", and a "Request" action.
/// Carpool wording: the passenger requests, the driver decides.
class SwDriverOfferCard extends StatelessWidget {
  const SwDriverOfferCard({
    super.key,
    required this.driverName,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onAction,
    this.driverPhoto,
    this.onTap,
  });

  final String driverName;

  /// "Kasia · 9 min"
  final String title;

  /// "Walk 450 m · drops you at the door"
  final String subtitle;

  /// "Request"
  final String actionLabel;
  final VoidCallback? onAction;
  final ImageProvider? driverPhoto;

  /// Opens the driver's details.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final large = swIsLargeText(context);
    // The card itself reads "title. subtitle" (and opens details on tap);
    // the action is a separate button.
    final texts = ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: const TextStyle(fontFamily: swFontFamily, fontSize: 15, fontWeight: FontWeight.w700, height: 1.35, color: SwColors.text)),
          const SizedBox(height: 1),
          Text(subtitle, style: SwType.caption),
        ],
      ),
    );
    final action = _ActionPill(label: actionLabel, onTap: onAction);
    final avatar = SwAvatar(name: driverName, image: driverPhoto, size: 36, excludeFromSemantics: true);

    final body = large
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [avatar, const SizedBox(width: SwSpace.s12), Expanded(child: texts)]),
              const SizedBox(height: SwSpace.s8),
              Align(alignment: AlignmentDirectional.centerEnd, child: action),
            ],
          )
        : Row(children: [
            avatar,
            const SizedBox(width: SwSpace.s12),
            Expanded(child: texts),
            const SizedBox(width: SwSpace.s8),
            action,
          ]);

    return Material(
      color: SwColors.surface2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SwRadius.card),
        side: const BorderSide(color: SwColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        container: true,
        label: '$title. $subtitle',
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 12, 6),
            child: body,
          ),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwRadius.pill));
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SwSpace.s4),
        child: Material(
          color: SwColors.surface3,
          shape: shape,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: SwSize.chip, minWidth: SwSize.touchAndroid),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Center(
                  widthFactor: 1,
                  child: Text(label,
                      style: const TextStyle(fontFamily: swFontFamily, fontSize: 14, fontWeight: FontWeight.w600, color: SwColors.text)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
