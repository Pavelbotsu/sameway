// The app doesn't know anyone's gender: copy about the driver, the passenger
// or the user is neutral ("Label: {name}", the role noun, or a rephrase).
//
// English: no he/she pronouns at all. Ukrainian and Polish: no personal
// pronouns, past-tense verb forms (they agree with the subject's gender),
// "сам/sam" ("alone, by oneself") or gendered role nouns. These also match
// words about things ("код … його", "sesja wygasła"); such hits are listed in
// [_aboutThings] with the key, so each one was looked at. Plural past forms
// (-ли, -li) and impersonal forms (скасовано, anulowano, było) are neutral.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _en = RegExp(r"\b(he|him|his|himself|she|her|hers|herself)\b",
    caseSensitive: false);

const _l = r"\p{L}’'";

final _patterns = {
  'uk': [
    // Personal pronouns (3rd person singular).
    RegExp('(?<![$_l])(він|вона|його|її|йому|їй|нього|неї|ньому|ній|ним|нею)(?![$_l])',
        unicode: true, caseSensitive: false),
    // Past tense, masculine and feminine (also reflexive, and the -ів verbs
    // that read like genitive plurals).
    RegExp('(?<![$_l])[$_l]+(ав|ив|ув|яв|ов|ла|лася|вся|ився|лась)(?![$_l])',
        unicode: true, caseSensitive: false),
    RegExp('(?<![$_l])(хотів|зумів|сидів|летів|вмів|сів|зустрів|привів|відповів|вів|ввів|завів|підвів|встиг|приніс|забув|міг|змогла|зміг|пішла|прийшла)(?![$_l])',
        unicode: true, caseSensitive: false),
    // "Alone / by oneself" and gendered role nouns.
    RegExp('(?<![$_l])(сам|сама)(?![$_l])', unicode: true, caseSensitive: false),
    RegExp('(?<![$_l])(водійк\\p{L}*|пасажирк\\p{L}*)(?![$_l])',
        unicode: true, caseSensitive: false),
  ],
  'pl': [
    RegExp(r'(?<![\p{L}])(on|ona|jego|jej|niego|niej|mu|go|jemu|nim|nią|niemu)(?![\p{L}])',
        unicode: true, caseSensitive: false),
    RegExp(r'(?<![\p{L}])\p{L}+(ł|ła|łem|łam|łeś|łaś|łby|łaby|łbyś|łabyś)(?![\p{L}])',
        unicode: true, caseSensitive: false),
    RegExp(r'(?<![\p{L}])(sam|sama)(?![\p{L}])', unicode: true, caseSensitive: false),
    RegExp(r'(?<![\p{L}])(pasażerk\p{L}*|kierowczyni\p{L}*)(?![\p{L}])',
        unicode: true, caseSensitive: false),
  ],
};

/// "the same" (та сама, ten sam), not "alone".
final _same = {
  'uk': RegExp(r'(той|та|те|ту|тієї|того|тим|тією|тому)\s+$', caseSensitive: false),
  'pl': RegExp(r'(ten|ta|to|taki|taka|takie|tego|tej|tym|tą|tę|tak)\s+$',
      caseSensitive: false),
};

/// Words that match a pattern but aren't verbs or pronouns.
const _notVerbs = {
  'uk': {'постав', 'правила', 'розмов'},
  'pl': {'zł', 'pomysł', 'pomysłem', 'zespół', 'hasła', 'hasłem', 'udziałem',
      'działa', 'zła', 'tytuł'},
};

/// Hits about things, not people (key → words). Reviewed by hand; the
/// comment names the noun the word agrees with.
const _aboutThings = <String, Map<String, Set<String>>>{
  'uk': {
    'bHowToReport_worksOnAnyScreenWe': {'сам'}, // скріншот
    'bSent_thanksItsWithTheTeam': {'отримала'}, // команда
    'iDone_thereWasAProblem': {'була'}, // проблема
    'iMyBooking_sayCode': {'його'}, // код
    'mEmpty_whenYouBookARide': {'він', 'сам'}, // чат
    'nP2_liveActivityUpdatesEveryFew': {'його'}, // код
    'nP5_routeChanged': {'змінився'}, // маршрут
    'oCreate_shownToDriversAndPassengers': {'його'}, // ім’я
    'prEdit_shownOnlyToYourDriver': {'його'}, // номер телефону
    'prMapStyle_switchesBetweenStandardAndDark': {'сама'}, // мапа
    'prVerifyLicence_passengersCanBookYouOnly': {'сам'}, // документ
    'pSearch_usedYesterday': {'була'}, // адреса
    'rwBox_yourRouteLineOnThe': {'його'}, // маршрут
    'tP2_tapNowToPickA': {'його'}, // місто
    'xLocationOff_turnItOnSoWe': {'її'}, // геолокація
    'xMapFailed_mapDidntLoadYourDriver': {'завантажилася'}, // мапа
    'xSignOut_upcomingRides': {'вона'}, // попутка
    'legacy_carDetailsRequired': {'його'}, // авто
    'legacy_errSessionExpired': {'завершився'}, // сеанс
    'legacy_firstRidePrompt': {'її'}, // попутка
    'legacy_newCodeIssued': {'його'}, // код
    'legacy_onboardSubtitle4': {'відбулася'}, // зустріч
    'legacy_rideCancelledTimeout': {'минув', 'її'}, // час, поїздка
    'legacy_shareTripLiveBody': {'нею'}, // поїздка
  },
  'pl': {
    'common_howWasRide': {'minął'}, // przejazd
    'common_sayItWhenYouMeet': {'go'}, // kod
    'diPArrived_howWasIt': {'minęła'}, // podróż
    'dRequest_secondsLeft': {'została'}, // sekunda
    'iDone_thereWasAProblem': {'był'}, // problem
    'iMyBooking_sayCode': {'go'}, // kod
    'iRequestExpired_requestExpired': {'wygasła'}, // prośba
    'nP2_liveActivityUpdatesEveryFew': {'go'}, // kod
    'nP5_routeChanged': {'zmieniła'}, // trasa
    'nP8_aDriverCancellingTheDay': {'wygasła'}, // prośba
    'oPasswordError_triesLeft': {'została'}, // próba
    'oVerify_wrongEmailChangeIt': {'go'}, // e-mail
    'prBug_egTheDestinationPinJumped_hint': {'wróciła'}, // pinezka
    'prVerifyRejected_theTextOnTheBack': {'był'}, // tekst
    'tD4_askThePassengerForTheir': {'go'}, // kod
    'xMapFailed_mapDidntLoadYourDriver': {'wczytała'}, // mapa
    'legacy_errSessionExpired': {'wygasła'}, // sesja
    'legacy_newCodeIssued': {'go'}, // kod
    'legacy_rideCancelledTimeout': {'wygasł', 'został'}, // przejazd
    'legacy_shareTripLiveBody': {'go'}, // przejazd
  },
};

void main() {
  final dir = Directory('lib/l10n');
  Map<String, dynamic> arb(String code) =>
      jsonDecode(File('${dir.path}/app_$code.arb').readAsStringSync())
          as Map<String, dynamic>;

  test('English copy has no he/she pronouns', () {
    final hits = <String>[];
    arb('en').forEach((k, v) {
      if (k.startsWith('@') || v is! String) return;
      if (_en.hasMatch(v)) hits.add('$k: $v');
    });
    expect(hits, isEmpty,
        reason: 'Use the name ("Label: {name}"), the role ("the driver") or '
            '"they":\n${hits.join('\n')}');
  });

  for (final code in ['uk', 'pl']) {
    test('$code copy has no gendered forms about people', () {
      final hits = <String>[];
      final used = <String>{};
      arb(code).forEach((k, v) {
        if (k.startsWith('@') || v is! String) return;
        for (final p in _patterns[code]!) {
          for (final m in p.allMatches(v)) {
            final w = m.group(0)!.toLowerCase();
            if (_notVerbs[code]!.contains(w)) continue;
            if ((w == 'сам' || w == 'сама' || w == 'sam' || w == 'sama') &&
                _same[code]!.hasMatch(v.substring(0, m.start))) {
              continue;
            }
            if (_aboutThings[code]![k]?.contains(w) ?? false) {
              used.add('$k/$w');
              continue;
            }
            hits.add('$k [$w]: $v');
          }
        }
      });
      expect(hits, isEmpty,
          reason: 'Gendered form about a person? Rephrase ("Label: {name}", '
              'impersonal or plural forms). If it is about a thing, add the '
              'key to _aboutThings:\n${hits.join('\n')}');
      final stale = [
        for (final e in _aboutThings[code]!.entries)
          for (final w in e.value)
            if (!used.contains('${e.key}/$w')) '${e.key}/$w',
      ];
      expect(stale, isEmpty, reason: 'Allowlist entries no longer needed');
    });
  }
}
