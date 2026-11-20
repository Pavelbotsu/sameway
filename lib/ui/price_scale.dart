import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// Price per seat on the price step (I_DriverPrice): the value at 44 px and
/// a scale from [min] to [max] with the suggested band and a thumb.
/// Steps of [step] (1 zł). Drag or tap the scale; screen readers get a
/// slider with increase/decrease actions.
///
/// The limits (half the suggestion … fuel ÷ seats) are computed by the
/// server (`/v1/intercity/price-suggestion`), never here.
class SwPriceScale extends StatelessWidget {
  const SwPriceScale({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.format,
    required this.semanticLabel,
    this.suggestedMin,
    this.suggestedMax,
    this.step = 1,
  }) : assert(max > min);

  final int value, min, max, step;
  final int? suggestedMin, suggestedMax;
  final ValueChanged<int>? onChanged;

  /// Money formatting ("16 zł"), localised by the caller.
  final String Function(int value) format;

  /// "Price per seat"
  final String semanticLabel;

  double _frac(int v) => ((v - min) / (max - min)).clamp(0.0, 1.0);

  int _snap(double frac) {
    final raw = min + frac.clamp(0.0, 1.0) * (max - min);
    final snapped = min + ((raw - min) / step).round() * step;
    return snapped.clamp(min, max);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.role;
    final v = value.clamp(min, max);
    final f = _frac(v);
    final canDown = onChanged != null && v - step >= min;
    final canUp = onChanged != null && v + step <= max;
    const label13 = TextStyle(fontFamily: swFontFamily, fontSize: 13, fontWeight: FontWeight.w500, height: 1.3, color: SwColors.textSecondary);

    return Semantics(
      slider: true,
      label: semanticLabel,
      value: format(v),
      increasedValue: canUp ? format(v + step) : null,
      decreasedValue: canDown ? format(v - step) : null,
      onIncrease: canUp ? () => onChanged!(v + step) : null,
      onDecrease: canDown ? () => onChanged!(v - step) : null,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(format(v), textAlign: TextAlign.center, style: SwType.price.copyWith(color: SwColors.text)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SwSpace.s8),
            child: LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth;
              void set(double dx) {
                if (onChanged == null) return;
                final n = _snap(dx / w);
                if (n != v) onChanged!(n);
              }

              final sMin = suggestedMin, sMax = suggestedMax;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => set(d.localPosition.dx),
                onHorizontalDragUpdate: (d) => set(d.localPosition.dx),
                child: SizedBox(
                  height: 28,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0, right: 0, top: 11, height: 6,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: SwColors.surface3, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                      if (sMin != null && sMax != null)
                        Positioned(
                          left: w * _frac(sMin),
                          width: w * (_frac(sMax) - _frac(sMin)),
                          top: 11, height: 6,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: role.tint,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: role.fill),
                            ),
                          ),
                        ),
                      Positioned(
                        left: w * f - 9, top: 5, width: 18, height: 18,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: role.fill,
                            shape: BoxShape.circle,
                            border: Border.all(color: SwColors.background, width: 3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 2),
          // Labels: min · current · max. Min/max hide when the current label
          // would sit on top of them.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SwSpace.s8),
            child: Stack(
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  heightFactor: 1,
                  child: Opacity(opacity: f < .18 ? 0 : 1, child: Text(format(min), style: label13)),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  heightFactor: 1,
                  child: Opacity(opacity: f > .82 ? 0 : 1, child: Text(format(max), style: label13)),
                ),
                Align(
                  alignment: Alignment(f * 2 - 1, 0),
                  heightFactor: 1,
                  child: Text(format(v), style: label13.copyWith(fontWeight: FontWeight.w600, color: role.onDark)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
