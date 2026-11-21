import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'layout.dart';

/// Grouped rows on surface 2 with divider lines between them (settings,
/// key–value lists, seats by part of the route).
class SwListGroup extends StatelessWidget {
  const SwListGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: SwColors.surface2,
        borderRadius: BorderRadius.circular(SwRadius.card),
        border: Border.all(color: SwColors.line),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, thickness: 1, color: SwColors.line),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Plain list row: optional leading widget, title, optional subtitle,
/// optional trailing widget; tappable when [onTap] is set (then a chevron
/// is shown unless [trailing] is given).
class SwListRow extends StatelessWidget {
  const SwListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final trail = trailing ??
        (onTap == null ? null : const Icon(Icons.chevron_right, size: 20, color: SwColors.textSecondary));
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SwSpace.s16, vertical: 6),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: SwSpace.s12)],
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
                if (trail != null) ...[const SizedBox(width: SwSpace.s12), trail],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Label left (secondary), value right. [total] makes the value 18/800
/// ("Suggested per seat · 16 zł").
class SwKeyValueRow extends StatelessWidget {
  const SwKeyValueRow({super.key, required this.label, required this.value, this.total = false});
  final String label;
  final String value;
  final bool total;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(label, style: SwType.body.copyWith(color: SwColors.textSecondary));
    final valueStyle = total
        ? const TextStyle(fontFamily: swFontFamily, fontSize: 18, fontWeight: FontWeight.w800, height: 1.3, color: SwColors.text)
        : SwType.body.copyWith(color: SwColors.text, fontWeight: FontWeight.w600);
    // At 200 % the value goes under the label so words aren't broken.
    final child = swIsLargeText(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [labelText, Text(value, style: valueStyle)],
          )
        : LayoutBuilder(
            builder: (context, c) => Row(
              children: [
                Expanded(child: labelText),
                const SizedBox(width: SwSpace.s12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: c.maxWidth * .5),
                  child: Text(value, textAlign: TextAlign.end, style: valueStyle),
                ),
              ],
            ),
          );
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SwSpace.s16, vertical: 6),
          child: Align(alignment: AlignmentDirectional.centerStart, child: child),
        ),
      ),
    );
  }
}
