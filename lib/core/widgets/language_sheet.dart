import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_colors.dart';
import '../app_localizations.dart';
import '../language_provider.dart';

// Alphabetical by label (Latin scripts cluster, Cyrillic sorts after them).
const _languages = <_LanguageOption>[
  _LanguageOption(code: 'de', label: 'Deutsch', flag: '🇩🇪'),
  _LanguageOption(code: 'en', label: 'English', flag: '🇬🇧'),
  _LanguageOption(code: 'es', label: 'Español', flag: '🇪🇸'),
  _LanguageOption(code: 'fr', label: 'Français', flag: '🇫🇷'),
  _LanguageOption(code: 'it', label: 'Italiano', flag: '🇮🇹'),
  _LanguageOption(code: 'uk', label: 'Українська', flag: '🇺🇦'),
];

class _LanguageOption {
  final String code;
  final String label;
  final String flag;
  const _LanguageOption({
    required this.code,
    required this.label,
    required this.flag,
  });
}

/// Bottom sheet for picking app language. Always launch via
/// [LanguageSheet.show] so the modal is `isScrollControlled` and survives any
/// future additions to the language list without overflowing.
class LanguageSheet extends StatelessWidget {
  const LanguageSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const LanguageSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final langProvider = context.watch<LanguageProvider>();
    final currentCode = langProvider.locale.languageCode;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final maxH = MediaQuery.of(context).size.height * 0.7;

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              l.language,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final lang in _languages) ...[
                    _LangTile(
                      label: lang.label,
                      flag: lang.flag,
                      selected: currentCode == lang.code,
                      onTap: () {
                        context
                            .read<LanguageProvider>()
                            .setLocale(Locale(lang.code));
                        Navigator.pop(context);
                      },
                    ),
                    if (lang.code != _languages.last.code)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final String label;
  final String flag;
  final bool selected;
  final VoidCallback onTap;

  const _LangTile({
    required this.label,
    required this.flag,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}
