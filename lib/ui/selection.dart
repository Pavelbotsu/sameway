import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'layout.dart';

const _label14 = TextStyle(
    fontFamily: swFontFamily, fontSize: 14, fontWeight: FontWeight.w600, height: 1.3);

/// One option of a [SwSegmented].
class SwSegment<T> {
  const SwSegment(this.value, this.label);
  final T value;
  final String label;
}

/// Two or three mutually exclusive options ("Instant booking" / "Ask me").
/// Selected = role fill with dark text.
class SwSegmented<T> extends StatelessWidget {
  const SwSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<SwSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) {
    final role = context.role;
    final items = [
      for (final s in segments)
        _Segment(
          label: s.label,
          selected: s.value == selected,
          fill: role.fill,
          onTap: onChanged == null ? null : () => onChanged!(s.value),
        ),
    ];
    return Container(
      // The 4 px inset is part of each segment's tap area (48 dp targets).
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: SwColors.background,
        borderRadius: BorderRadius.circular(SwRadius.segmented),
        border: Border.all(color: SwColors.line),
      ),
      child: swIsLargeText(context)
          // At 200 % the options stack, so words are never broken.
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: items)
          // Equal-height segments when one label wraps.
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final i in items) Expanded(child: i)],
              ),
            ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.fill, this.onTap});
  final String label;
  final bool selected;
  final Color fill;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: GestureDetector(
        // Taps on the inset around the visible segment count too.
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: SwSpace.s4),
          child: Material(
            color: selected ? fill : Colors.transparent,
            borderRadius: BorderRadius.circular(SwRadius.inner),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(SwRadius.inner),
              child: ConstrainedBox(
                // 40 visible + 4 px inset above and below = a 48 dp target.
                constraints: const BoxConstraints(minHeight: SwSize.chip),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: SwSpace.s8, vertical: 6),
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: _label14.copyWith(
                          color: selected ? SwColors.onAccent : SwColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill choice ("2 min" / "4 min" / "6 min"). Selected = role tint,
/// role border and role text. The visible chip is 40 high inside a 48 dp
/// tap target.
class SwChip extends StatelessWidget {
  const SwChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final role = context.role;
    final fg = selected ? role.onDark : SwColors.text;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SwRadius.pill),
      side: BorderSide(color: selected ? role.fill : SwColors.line),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: SwSpace.s4),
        child: Material(
          color: selected ? role.tint : SwColors.surface2,
          shape: shape,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: SwSize.chip, minWidth: SwSize.touchAndroid),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18, color: fg),
                      const SizedBox(width: 6),
                    ],
                    Flexible(child: Text(label, style: _label14.copyWith(color: fg))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// On/off switch, 52×32 (Main board). Needs a [semanticLabel] when it is not
/// inside a [SwToggleRow].
class SwToggle extends StatelessWidget {
  const SwToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final role = context.role;
    final enabled = onChanged != null;
    return Semantics(
      label: semanticLabel,
      toggled: value,
      enabled: enabled,
      onTap: enabled ? () => onChanged!(!value) : null,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: SizedBox(
          width: 56,
          height: SwSize.touchAndroid,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              height: 32,
              padding: const EdgeInsets.all(SwSpace.s4),
              decoration: BoxDecoration(
                color: value ? role.fill : SwColors.surface3,
                borderRadius: BorderRadius.circular(16),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 150),
                alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: value ? SwColors.onAccent : SwColors.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Settings row: title (+ optional caption) and a [SwToggle]. The whole row
/// is the tap target and reads as one switch to screen readers.
class SwToggleRow extends StatelessWidget {
  const SwToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    return MergeSemantics(
      child: InkWell(
        onTap: enabled ? () => onChanged!(!value) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SwSpace.s16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: SwType.body.copyWith(color: SwColors.text, fontWeight: FontWeight.w600)),
                      if (subtitle != null) Text(subtitle!, style: SwType.caption),
                    ],
                  ),
                ),
                const SizedBox(width: SwSpace.s12),
                SwToggle(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// −  1  + stepper (±1 seat, ±1 zł). Buttons are 44 visible inside 48 dp
/// targets; the value is a live region so changes are announced.
class SwStepper extends StatelessWidget {
  const SwStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.decreaseLabel,
    required this.increaseLabel,
    this.min = 0,
    this.max = 99,
    this.step = 1,
    this.format,
    this.semanticValue,
  });

  final int value;
  final ValueChanged<int>? onChanged;
  final int min, max, step;

  /// "Fewer seats" / "More seats".
  final String decreaseLabel, increaseLabel;

  /// Visible value text ("16 zł"); defaults to the number.
  final String Function(int value)? format;

  /// What a screen reader says for the value ("1 seat"); defaults to [format].
  final String Function(int value)? semanticValue;

  @override
  Widget build(BuildContext context) {
    final shown = format?.call(value) ?? '$value';
    final canDown = onChanged != null && value - step >= min;
    final canUp = onChanged != null && value + step <= max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          label: decreaseLabel,
          onTap: canDown ? () => onChanged!(value - step) : null,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40),
          child: Semantics(
            liveRegion: true,
            label: semanticValue?.call(value) ?? shown,
            excludeSemantics: true,
            child: Text(
              shown,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: swFontFamily, fontSize: 18, fontWeight: FontWeight.w700,
                  color: SwColors.text),
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          label: increaseLabel,
          onTap: canUp ? () => onChanged!(value + step) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: SwSize.touchAndroid,
          child: Center(
            child: Container(
              width: SwSize.touch,
              height: SwSize.touch,
              decoration: BoxDecoration(
                color: SwColors.surface3,
                borderRadius: BorderRadius.circular(SwRadius.field),
              ),
              child: Icon(icon, size: 20, color: enabled ? SwColors.text : SwColors.textTertiary),
            ),
          ),
        ),
      ),
    );
  }
}
