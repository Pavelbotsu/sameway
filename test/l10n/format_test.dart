import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sameway/l10n/format.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  final en = SwFormat.forLocale(const Locale('en'));
  final uk = SwFormat.forLocale(const Locale('uk'));
  final pl = SwFormat.forLocale(const Locale('pl'));
  const nb = ' ';

  // Thursday 12 Nov 2026, 09:05.
  final thu = DateTime(2026, 11, 12, 9, 5);

  test('distance uses the locale decimal separator and unit', () {
    expect(en.distance(850), '850${nb}m');
    expect(en.distance(3140), '3.1${nb}km');
    expect(uk.distance(3140), '3,1$nbкм');
    expect(pl.distance(3140), '3,1${nb}km');
    expect(uk.distance(165000), '165$nbкм');
  });

  test('duration', () {
    expect(en.duration(const Duration(seconds: 30)), '30${nb}s');
    expect(uk.duration(const Duration(minutes: 4)), '4$nbхв');
    expect(pl.duration(const Duration(hours: 2)), '2${nb}godz.');
    expect(en.duration(const Duration(hours: 2, minutes: 20)),
        '2${nb}h 20${nb}min');
    expect(uk.duration(const Duration(hours: 2, minutes: 20)),
        '2$nbгод 20$nbхв');
  });

  test('time is 24-hour everywhere', () {
    final evening = DateTime(2026, 11, 12, 18, 42);
    expect(en.time(evening), '18:42');
    expect(uk.time(evening), '18:42');
    expect(pl.time(thu), '09:05');
  });

  test('deadlines carry a day name', () {
    expect(en.deadline(thu), 'Thu 09:05');
    expect(uk.deadline(thu), 'чт 09:05');
    expect(pl.deadline(thu), 'czw. 09:05');
  });

  test('dates', () {
    expect(en.date(thu), contains('12 Nov'));
    expect(uk.date(thu), contains('12'));
    expect(uk.date(thu), contains('лист'));
    expect(pl.date(thu), contains('lis'));
  });

  test('weekday chips are two letters from the designs', () {
    expect([for (var d = 1; d <= 7; d++) en.weekdayShort(d)],
        ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']);
    expect([for (var d = 1; d <= 7; d++) uk.weekdayShort(d)],
        ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Нд']);
    expect([for (var d = 1; d <= 7; d++) pl.weekdayShort(d)],
        ['Pn', 'Wt', 'Śr', 'Cz', 'Pt', 'So', 'Nd']);
  });

  test('money is whole złoty in every language', () {
    expect(en.zloty(16), '16${nb}zł');
    expect(uk.zloty(15.6), '16${nb}zł');
    expect(pl.zloty(16), '16${nb}zł');
  });

  test('kilograms and decimals', () {
    expect(en.kilograms(0.4), '0.4${nb}kg');
    expect(uk.kilograms(0.4), '0,4$nbкг');
  });

  test('relative chat time', () {
    final now = DateTime(2026, 11, 21, 12);
    expect(en.relative(now.subtract(const Duration(seconds: 20)), now: now),
        'now');
    expect(uk.relative(now.subtract(const Duration(minutes: 5)), now: now),
        '5$nbхв');
    expect(pl.relative(now.subtract(const Duration(hours: 3)), now: now),
        '3${nb}godz.');
    expect(en.relative(now.subtract(const Duration(days: 2)), now: now),
        '2${nb}d');
    expect(uk.relative(DateTime(2026, 10, 1), now: now), '01.10.2026');
  });

  test('unsupported locales format as English', () {
    expect(SwFormat.forLocale(const Locale('de')).distance(3140),
        '3.1${nb}km');
  });
}
