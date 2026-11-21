import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/language_provider.dart';
import '../../l10n/l10n.dart';
import '../../theme/theme.dart';

/// PR_Language: "Use device language" first, then each language under its
/// own name (endonym) with the name in the current UI language below it.
/// No flags. en, uk and pl only (decision 16; the design draws seven).
///
/// Reached from the account sheet and the splash/map language buttons until
/// the Profile tab exists (Phase 3).
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  /// Pushes the screen in the v3 theme of [role] (radio colour = role).
  static Future<void> push(BuildContext context,
      {SwRole role = SwRole.passenger}) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => Theme(
        data: SwTheme.build(role),
        child: const LanguageScreen(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = context.watch<LanguageProvider>();
    // Endonyms stay the same in every UI language, so they are not in ARB.
    final options = <_Option>[
      // l10n-ignore: endonym, shown the same in every language
      _Option(const Locale('en'), 'English', null),
      // l10n-ignore: endonym, shown the same in every language
      _Option(const Locale('pl'), 'Polski', l.prLanguage_polish),
      // l10n-ignore: endonym, shown the same in every language
      _Option(const Locale('uk'), 'Українська', l.prLanguage_ukrainian),
    ];
    String exonym(Locale locale) => switch (locale.languageCode) {
          'uk' => l.prLanguage_ukrainian,
          'pl' => l.prLanguage_polish,
          _ => l.prLanguage_english,
        };

    return Scaffold(
      backgroundColor: SwColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: SwSpace.s24),
          children: [
            SizedBox(
              height: 64,
              child: Row(
                children: [
                  const SizedBox(width: SwSpace.s8),
                  IconButton(
                    tooltip: l.common_back_a11y,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.chevron_left, size: 28),
                    color: SwColors.text,
                    constraints: const BoxConstraints(
                        minWidth: SwSize.touchAndroid,
                        minHeight: SwSize.touchAndroid),
                  ),
                  const SizedBox(width: SwSpace.s4),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l.common_language,
                          style: SwType.appBarTitle
                              .copyWith(color: SwColors.text)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SwSpace.s16, SwSpace.s4, SwSpace.s16, 0),
              child: Semantics(
                label: l.prLanguage_appLanguage_a11y,
                container: true,
                explicitChildNodes: true,
                child: _Group(children: [
                  _LanguageRow(
                    title: l.prLanguage_useDevice,
                    subtitle:
                        l.prLanguage_currently(exonym(lang.deviceLanguage)),
                    selected: lang.usesDeviceLanguage,
                    onTap: lang.useDeviceLanguage,
                  ),
                  for (final o in options)
                    _LanguageRow(
                      title: o.endonym,
                      subtitle: o.exonym,
                      selected: lang.chosen?.languageCode ==
                          o.locale.languageCode,
                      onTap: () => lang.setLocale(o.locale),
                    ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  SwSpace.s16, SwSpace.s12, SwSpace.s16, 0),
              child: Text(l.prLanguage_footnote, style: SwType.caption),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option {
  const _Option(this.locale, this.endonym, this.exonym);
  final Locale locale;
  final String endonym;

  /// The language's name in the UI language; null for English (as drawn).
  final String? exonym;
}

/// Rows on surface 2 with lines between them (radius 16, v3).
class _Group extends StatelessWidget {
  const _Group({required this.children});
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                const Divider(height: 1, thickness: 1, color: SwColors.line),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// One radio row: title (16/500), optional subtitle, radio on the right in
/// the role colour. Announced as a selected/unselected radio button.
class _LanguageRow extends StatelessWidget {
  const _LanguageRow({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = context.role.fill;
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: SwSpace.s16, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            style: SwType.input.copyWith(color: SwColors.text)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: SwType.caption),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  ExcludeSemantics(
                    child: Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          width: 2,
                          color: selected ? accent : SwColors.textTertiary,
                        ),
                      ),
                      child: selected
                          ? Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                  color: accent, shape: BoxShape.circle),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
