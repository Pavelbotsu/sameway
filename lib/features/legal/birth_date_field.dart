import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';

/// Minimum age to use Sameway; the backend enforces the same (handlers.minAge).
const kMinAge = 18;

/// The latest date of birth that is old enough on [today].
DateTime latestAllowedBirthDate(DateTime today) =>
    DateTime(today.year - kMinAge, today.month, today.day);

/// YYYY-MM-DD, the format the backend expects for `birth_date`.
String formatBirthDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Date-of-birth picker used at signup and on the terms gate. The picker
/// can't select a date younger than [kMinAge]; the server re-checks it.
class BirthDateField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool showError;
  final Color accent;

  const BirthDateField({
    super.key,
    required this.value,
    required this.onChanged,
    this.showError = false,
    this.accent = AppColors.primary,
  });

  Future<void> _pick(BuildContext context) async {
    final today = DateTime.now();
    final last = latestAllowedBirthDate(today);
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime(last.year - 7, last.month, last.day),
      firstDate: DateTime(today.year - 100),
      lastDate: last,
      initialEntryMode: DatePickerEntryMode.input,
      helpText: AppLocalizations.of(context).birthDateLabel,
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasValue = value != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: l.birthDateLabel,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _pick(context),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: showError && !hasValue ? AppColors.error : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.cake_outlined,
                      color: hasValue ? accent : AppColors.textSecondary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    hasValue ? formatBirthDate(value!) : l.birthDateLabel,
                    style: TextStyle(
                      color: hasValue ? Colors.white : AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showError && !hasValue)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 0, 0),
            child: Text(
              l.birthDateRequired,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
