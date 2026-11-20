import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// What a button does. One [primary] per screen, full width, at the bottom.
enum SwButtonKind {
  /// Role fill, dark text, 52 high.
  primary,

  /// Surface 2 with a divider line, 48 high.
  secondary,

  /// Red text on a red tint, 48 high (cancel, leave, delete).
  danger,

  /// Red fill with dark text, 52 high: only for the final, confirming step.
  dangerFilled,
}

const _buttonText = TextStyle(
    fontFamily: swFontFamily, fontSize: 16, fontWeight: FontWeight.w600, height: 1.25);

ButtonStyle _style(BuildContext context, SwButtonKind kind) {
  final role = context.role;
  final (Color bg, Color fg, BorderSide side, double h) = switch (kind) {
    SwButtonKind.primary => (role.fill, SwColors.onAccent, BorderSide.none, SwSize.button),
    SwButtonKind.secondary => (SwColors.surface2, SwColors.text, const BorderSide(color: SwColors.line), SwSize.buttonSecondary),
    SwButtonKind.danger => (SwColors.dangerTint, SwColors.danger, const BorderSide(color: SwColors.dangerLine), SwSize.buttonSecondary),
    SwButtonKind.dangerFilled => (SwColors.danger, SwColors.onAccent, BorderSide.none, SwSize.button),
  };
  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size.fromHeight(h)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
    elevation: const WidgetStatePropertyAll(0),
    textStyle: const WidgetStatePropertyAll(_buttonText),
    shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(SwRadius.button))),
    tapTargetSize: MaterialTapTargetSize.padded,
    // Disabled = transparent with a 3:1 outline and readable text. A disabled
    // button always says when or why (see [SwLaterButton], `disabledReason`).
    backgroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? Colors.transparent : bg),
    foregroundColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.disabled) ? SwColors.textSecondary : fg),
    overlayColor: WidgetStateProperty.resolveWith((s) =>
        s.contains(WidgetState.pressed) ? fg.withValues(alpha: .12) : fg.withValues(alpha: .06)),
    side: WidgetStateProperty.resolveWith((s) {
      if (s.contains(WidgetState.focused)) return BorderSide(color: role.onDark, width: 2);
      if (s.contains(WidgetState.disabled)) return const BorderSide(color: SwColors.fieldBorder);
      return side;
    }),
  );
}

/// Base for all v3 buttons. Use the named classes below in screens.
class SwButton extends StatelessWidget {
  const SwButton({
    super.key,
    required this.kind,
    required this.label,
    required this.onPressed,
    this.icon,
    this.disabledReason,
  });

  final SwButtonKind kind;
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Shown under a disabled button ("Available at 09:10 · in 6 min",
  /// "Add a destination first"). Ignored while the button is enabled.
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, textAlign: TextAlign.center);
    final child = icon == null
        ? text
        : Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20),
            const SizedBox(width: SwSpace.s8),
            Flexible(child: text),
          ]);
    final button = FilledButton(
      style: _style(context, kind),
      onPressed: onPressed,
      child: child,
    );
    final reason = disabledReason;
    if (onPressed != null || reason == null) return button;
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          button,
          const SizedBox(height: 6),
          Text(
            reason,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: swFontFamily, fontSize: 13, fontWeight: FontWeight.w500,
                height: 1.4, color: SwColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Role-filled main action ("Book seat · 16 zł", "Start sharing route").
class SwPrimaryButton extends SwButton {
  const SwPrimaryButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.icon,
    super.disabledReason,
  }) : super(kind: SwButtonKind.primary);
}

/// Quiet action next to or instead of the primary ("Keep browsing").
class SwSecondaryButton extends SwButton {
  const SwSecondaryButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.icon,
    super.disabledReason,
  }) : super(kind: SwButtonKind.secondary);
}

/// Red action ("Cancel seat"). [filled] only for the final confirmation.
class SwDangerButton extends SwButton {
  const SwDangerButton({
    super.key,
    required super.label,
    required super.onPressed,
    super.icon,
    super.disabledReason,
    bool filled = false,
  }) : super(kind: filled ? SwButtonKind.dangerFilled : SwButtonKind.danger);
}

/// A button that is disabled until [availableAt] and always says when
/// (I_NoShowDriver, I_NoShowPassenger, D_NoShow):
/// "Leave without Olena" + "Available at 09:10 · in 6 min".
/// Re-checks the clock every 15 s and turns into a normal [kind] button
/// once [availableAt] passes.
class SwLaterButton extends StatefulWidget {
  const SwLaterButton({
    super.key,
    required this.label,
    required this.availableAt,
    required this.onPressed,
    required this.availableText,
    this.kind = SwButtonKind.secondary,
    this.now = DateTime.now,
  });

  final String label;
  final DateTime availableAt;
  final VoidCallback onPressed;

  /// Localised "Available at {time} · in {minutes} min". Deadlines and
  /// times are 24 h; [minutesLeft] is rounded up and at least 1.
  final String Function(DateTime at, int minutesLeft) availableText;
  final SwButtonKind kind;

  /// Clock, injectable for tests.
  final DateTime Function() now;

  @override
  State<SwLaterButton> createState() => _SwLaterButtonState();
}

class _SwLaterButtonState extends State<SwLaterButton> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      setState(() {});
      if (!widget.now().isBefore(widget.availableAt)) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.availableAt.difference(widget.now());
    final ready = left <= Duration.zero;
    final minutes = ready ? 0 : (left.inSeconds / 60).ceil().clamp(1, 1 << 30);
    return SwButton(
      kind: widget.kind,
      label: widget.label,
      onPressed: ready ? widget.onPressed : null,
      disabledReason: ready ? null : widget.availableText(widget.availableAt, minutes),
    );
  }
}
