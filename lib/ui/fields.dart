import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';

/// v3 text field: 56 high, label above (13/500), optional leading icon.
/// States: default 1 px `fieldBorder` · focus 2 px role colour ·
/// error 2 px red with the message under the field (13 px).
class SwTextField extends StatelessWidget {
  const SwTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hint,
    this.icon,
    this.iconColor,
    this.errorText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;

  /// Visible label above the field. Without it, [hint] must say what to type.
  final String? label;
  final String? hint;
  final IconData? icon;

  /// Defaults to secondary text colour. [SwSearchField] uses the role colour.
  final Color? iconColor;
  final String? errorText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final bool readOnly;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final role = context.role;
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(SwRadius.field),
          borderSide: BorderSide(color: c, width: w),
        );
    final field = TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      autofocus: autofocus,
      readOnly: readOnly,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      cursorColor: role.fill,
      style: SwType.input.copyWith(color: SwColors.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: SwType.input.copyWith(color: SwColors.textTertiary),
        // Error state only; the message is drawn below, aligned with the
        // field's edge as on the board.
        error: errorText == null ? null : const SizedBox.shrink(),
        filled: true,
        fillColor: SwColors.background,
        isDense: false,
        constraints: const BoxConstraints(minHeight: SwSize.field),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
        prefixIcon: icon == null
            ? null
            : Padding(
                padding: const EdgeInsetsDirectional.only(start: 14, end: 12),
                child: Icon(icon, size: 20, color: iconColor ?? SwColors.textSecondary),
              ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: border(SwColors.fieldBorder),
        enabledBorder: border(SwColors.fieldBorder),
        disabledBorder: border(SwColors.line),
        focusedBorder: border(role.fill, 2),
        errorBorder: border(SwColors.danger, 2),
        focusedErrorBorder: border(SwColors.danger, 2),
      ),
    );
    final l = label;
    final e = errorText;
    if (l == null && e == null) return field;
    return Semantics(
      label: l,
      container: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (l != null) ...[
            ExcludeSemantics(
              child: Text(l,
                  style: const TextStyle(
                      fontFamily: swFontFamily, fontSize: 13, fontWeight: FontWeight.w500,
                      height: 1.4, color: SwColors.textSecondary)),
            ),
            const SizedBox(height: 6),
          ],
          field,
          if (e != null)
            Semantics(
              liveRegion: true,
              child: Text(e,
                  style: const TextStyle(
                      fontFamily: swFontFamily, fontSize: 13, height: 1.45, color: SwColors.danger)),
            ),
        ],
      ),
    );
  }
}

/// "Where to?" search field: search icon in the role colour.
class SwSearchField extends StatelessWidget {
  const SwSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.focusNode,
    this.icon = Icons.search,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
    this.autofocus = false,
  });

  final String hint;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final IconData icon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => SwTextField(
        controller: controller,
        focusNode: focusNode,
        hint: hint,
        icon: icon,
        iconColor: context.role.fill,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        onTap: onTap,
        readOnly: readOnly,
        autofocus: autofocus,
      );
}
