import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'layout.dart';

const _text14 = TextStyle(fontFamily: swFontFamily, fontSize: 14, fontWeight: FontWeight.w500, height: 1.4);

/// Snackbar = the result of MY last action, with Undo when it can be
/// undone ("Route ended · Undo", "Ride saved · Undo"). Light on the dark
/// app so it stands out without a shadow. Use [showSwSnackBar].
class SwSnackBar extends StatelessWidget {
  const SwSnackBar({super.key, required this.message, this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _MessageBar(
      background: SwColors.snackbar,
      message: Text(message, style: _text14.copyWith(color: SwColors.onAccent)),
      action: actionLabel == null
          ? null
          : _TextAction(label: actionLabel!, color: context.role.onLight, onTap: onAction),
    );
  }
}

/// Shows a [SwSnackBar] at the bottom. The action closes the snackbar first.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showSwSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 5),
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    padding: EdgeInsets.zero,
    margin: const EdgeInsets.fromLTRB(SwSpace.s16, 0, SwSpace.s16, SwSpace.s16),
    // A little longer when there is something to undo.
    duration: actionLabel == null ? duration : duration + const Duration(seconds: 3),
    content: SwSnackBar(
      message: message,
      actionLabel: actionLabel,
      onAction: onAction == null
          ? null
          : () {
              messenger.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
              onAction();
            },
    ),
  ));
}

enum SwBannerTone { warning, danger }

/// Banner = a problem in the background that the user can fix
/// ("Location access is off. · Open Settings"). Stays until fixed.
class SwBanner extends StatelessWidget {
  const SwBanner({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.tone = SwBannerTone.warning,
    this.icon,
  });

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final SwBannerTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color line, Color fg) = switch (tone) {
      SwBannerTone.warning => (SwColors.warningTint, SwColors.warningLine, SwColors.warning),
      SwBannerTone.danger => (SwColors.dangerTint, SwColors.dangerLine, SwColors.danger),
    };
    return _MessageBar(
      background: bg,
      border: line,
      icon: Icon(icon ?? Icons.warning_amber_rounded, size: 20, color: fg),
      message: Text(message, style: _text14.copyWith(color: SwColors.text)),
      action: actionLabel == null ? null : _TextAction(label: actionLabel!, color: fg, onTap: onAction),
    );
  }
}

/// Message with an optional icon and action. At large text sizes the
/// action moves under the message so nothing is cut.
class _MessageBar extends StatelessWidget {
  const _MessageBar({required this.background, required this.message, this.border, this.icon, this.action});
  final Color background;
  final Color? border;
  final Widget message;
  final Widget? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final large = swIsLargeText(context);
    final head = Row(
      children: [
        if (icon != null) Padding(padding: const EdgeInsetsDirectional.only(end: 10), child: icon),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: message)),
        if (action != null && !large) action!,
        if (action == null) const SizedBox(width: 10),
      ],
    );
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 4, 2),
        constraints: const BoxConstraints(minHeight: SwSize.touchAndroid),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(SwRadius.field),
          border: border == null ? null : Border.all(color: border!),
        ),
        child: action != null && large
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [head, Align(alignment: AlignmentDirectional.centerEnd, child: action)],
              )
            : head,
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  const _TextAction({required this.label, required this.color, this.onTap});
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SwRadius.inner),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SwSize.touchAndroid, minWidth: SwSize.touchAndroid),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(label, style: _text14.copyWith(fontWeight: FontWeight.w700, color: color)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
