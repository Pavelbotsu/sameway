import 'package:flutter/material.dart';

/// Material 3 Expressive **Split Button**.
///
/// A primary `FilledButton` cell with a trailing dropdown cell that opens
/// a menu of secondary actions. The two cells share a single rounded
/// container with a 1 dp hairline divider between them — matching the
/// M3 Expressive split-button anatomy.
///
/// Pass the leading [label] (and optional [icon]) for the primary action,
/// [onPressed] for the primary tap, and [menuItems] for the secondary
/// actions revealed by the trailing chevron.
class SplitButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<SplitMenuItem> menuItems;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double height;

  const SplitButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.menuItems,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.height = 48,
  }) : assert(menuItems.length > 0, 'SplitButton requires at least one menu item');

  @override
  State<SplitButton> createState() => _SplitButtonState();
}

class _SplitButtonState extends State<SplitButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _chevron;

  @override
  void initState() {
    super.initState();
    _chevron = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
  }

  @override
  void dispose() {
    _chevron.dispose();
    super.dispose();
  }

  Future<void> _openMenu() async {
    _chevron.forward();
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      _chevron.reverse();
      return;
    }
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      _chevron.reverse();
      return;
    }
    final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
    final rect = RelativeRect.fromLTRB(
      origin.dx,
      origin.dy + box.size.height + 6,
      overlay.size.width - origin.dx - box.size.width,
      0,
    );
    final selected = await showMenu<int>(
      context: context,
      position: rect,
      items: [
        for (var i = 0; i < widget.menuItems.length; i++)
          PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                if (widget.menuItems[i].icon != null) ...[
                  Icon(widget.menuItems[i].icon, size: 18),
                  const SizedBox(width: 10),
                ],
                Text(widget.menuItems[i].label),
              ],
            ),
          ),
      ],
    );
    if (!mounted) return;
    _chevron.reverse();
    if (selected != null) {
      widget.menuItems[selected].onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = widget.backgroundColor ?? cs.primary;
    final fg = widget.foregroundColor ?? cs.onPrimary;

    return SizedBox(
      height: widget.height,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(widget.height / 2),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primary cell
            InkWell(
              onTap: widget.onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: fg, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Hairline divider
            Container(
              width: 1,
              height: widget.height * 0.55,
              color: fg.withValues(alpha: 0.25),
            ),
            // Dropdown cell
            InkWell(
              onTap: widget.onPressed == null ? null : _openMenu,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: RotationTransition(
                  turns: Tween<double>(begin: 0.0, end: 0.5).animate(
                    CurvedAnimation(
                        parent: _chevron, curve: Curves.easeOutCubic),
                  ),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: fg,
                    size: 22,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One secondary action inside a [SplitButton] dropdown.
class SplitMenuItem {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  const SplitMenuItem({
    required this.label,
    required this.onPressed,
    this.icon,
  });
}
