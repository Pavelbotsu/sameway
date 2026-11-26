import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'l10n.dart';

/// Locale-aware formatting for distances, durations, times, dates and money
/// (docs/04_I18N.md › Formatting). Units come from ARB (`fmt_*`) and are joined
/// to the number with a no-break space.
///
///   final f = SwFormat.of(context);
///   f.distance(3140)                 // 3.1 km · 3,1 км · 3,1 km
///   f.deadline(t)                    // Thu 09:30 · чт 09:30 · czw. 09:30
///   f.zloty(16)                      // 16 zł
class SwFormat {
  SwFormat(Locale locale, this.l10n) : _tag = _intlTag(locale);

  factory SwFormat.of(BuildContext context) =>
      SwFormat(Localizations.localeOf(context), context.l10n);

  /// For code without a context; unsupported locales format as English.
  factory SwFormat.forLocale(Locale locale) {
    final resolved = l10nResolve(locale);
    return SwFormat(resolved, lookupL10n(resolved));
  }

  final L10n l10n;
  final String _tag;

  /// English uses British date order ("Sat 21 Nov", as in the designs).
  static String _intlTag(Locale locale) => switch (locale.languageCode) {
        'uk' => 'uk',
        'pl' => 'pl',
        _ => 'en_GB',
      };

  /// "850 m", "3.1 km" (one decimal under 100 km), "165 km".
  String distance(num metres) {
    if (metres < 1000) return l10n.fmt_metres(_int(metres));
    final km = metres / 1000;
    return l10n.fmt_kilometres(km < 100 ? decimal(km) : _int(km));
  }

  /// "45 s", "4 min", "2 h", "2 h 20 min" — rounded to whole minutes from one
  /// minute up.
  String duration(Duration d) {
    if (d.inSeconds < 60) return l10n.fmt_seconds(d.inSeconds);
    final minutes = (d.inSeconds / 60).round();
    if (minutes < 60) return l10n.fmt_minutes(minutes);
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? l10n.fmt_hours(h) : l10n.fmt_hoursMinutes(h, m);
  }

  /// 24-hour clock everywhere: "09:30".
  String time(DateTime t) => DateFormat('HH:mm', _tag).format(t);

  /// Deadlines always carry a day name: "Thu 09:30", «чт 09:30», „czw. 09:30”.
  String deadline(DateTime t) =>
      '${DateFormat.E(_tag).format(t)} ${time(t)}';

  /// "Sat 21 Nov", «сб, 21 лист.», „sob., 21 lis”.
  String date(DateTime d) => DateFormat.MMMEd(_tag).format(d);

  /// Two-letter weekday for chips, Monday = 1 … Sunday = 7 (DateTime.weekday):
  /// Mo/Пн/Pn. The letters are the designs' own (copy deck).
  String weekdayShort(int weekday) => switch (weekday) {
        DateTime.monday => l10n.common_mo,
        DateTime.tuesday => l10n.common_tu,
        DateTime.wednesday => l10n.common_we,
        DateTime.thursday => l10n.common_th,
        DateTime.friday => l10n.common_fr,
        DateTime.saturday => l10n.common_sa,
        DateTime.sunday => l10n.common_su,
        _ => throw ArgumentError.value(weekday, 'weekday'),
      };

  /// Whole złoty in every language: "16 zł", "1 250 zł".
  String zloty(num amount) =>
      l10n.fmt_zloty(NumberFormat('#,##0', _tag).format(amount.round()));

  /// CO₂ and similar small weights: "0.4 kg" / «0,4 кг».
  String kilograms(num kg) => l10n.fmt_kilograms(decimal(kg));

  /// Locale decimal separator, [digits] after it: 3.1 / 3,1.
  String decimal(num value, {int digits = 1}) {
    final f = NumberFormat.decimalPattern(_tag)
      ..minimumFractionDigits = digits
      ..maximumFractionDigits = digits;
    return f.format(value);
  }

  /// Chat-list time: now · 5 min · 3 h · 2 d · then a numeric date.
  String relative(DateTime t, {DateTime? now}) {
    final diff = (now ?? DateTime.now()).difference(t);
    if (diff.inMinutes < 1) return l10n.fmt_justNow;
    if (diff.inHours < 1) return l10n.fmt_minutesAgoShort(diff.inMinutes);
    if (diff.inDays < 1) return l10n.fmt_hoursAgoShort(diff.inHours);
    if (diff.inDays < 7) return l10n.fmt_daysAgoShort(diff.inDays);
    return DateFormat.yMd(_tag).format(t);
  }

  /// Numeric date (birth date, trip history): 21/11/2026 · 21.11.2026.
  String numericDate(DateTime d) => DateFormat.yMd(_tag).format(d);

  String _int(num v) => NumberFormat('#,##0', _tag).format(v.round());
}
