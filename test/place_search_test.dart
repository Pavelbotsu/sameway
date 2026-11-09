import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:sameway/core/place_search.dart';

String _photon(List<Map<String, dynamic>> props) => jsonEncode({
      'features': [
        for (final p in props)
          {
            'geometry': {'coordinates': [19.94, 50.06]},
            'properties': p,
          }
      ]
    });

void main() {
  test('parses Photon results into readable names', () {
    final r = PlaceSearch.parsePhoton(_photon([
      {'name': 'AGH', 'street': 'al. Mickiewicza', 'housenumber': '30', 'city': 'Kraków', 'country': 'Polska'},
      {'name': 'Kraków', 'city': 'Kraków', 'country': 'Polska'},
    ]));
    expect(r.first.name, 'AGH, al. Mickiewicza 30, Kraków, Polska');
    expect(r.first.lat, 50.06);
    expect(r.first.lng, 19.94);
    expect(r.last.name, 'Kraków, Polska', reason: 'duplicates dropped');
  });

  test('a slower, older search is dropped when a newer one started', () async {
    final slow = Completer<void>();
    final search = PlaceSearch();
    await http.runWithClient(() async {
      final first = search.search('Kra'); // held until we release it
      final second = search.search('Kraków');
      slow.complete();
      expect(await second, isNotNull);
      expect(await first, isNull, reason: 'superseded');
    }, () => MockClient((req) async {
          if (req.url.queryParameters['q'] == 'Kra') await slow.future;
          return http.Response(_photon([{'name': req.url.queryParameters['q']}]), 200);
        }));
  });

  test('sends language, location bias and an app User-Agent', () async {
    late http.Request seen;
    await http.runWithClient(() async {
      await PlaceSearch().search('Rynek', near: const LatLng(50.06, 19.94), languageCode: 'de');
    }, () => MockClient((req) async {
          seen = req;
          return http.Response(_photon([]), 200);
        }));
    expect(seen.url.queryParameters['lang'], 'de');
    expect(seen.url.queryParameters['lat'], '50.0600');
    expect(seen.url.queryParameters['bbox'], isNotNull);
    expect(seen.headers['User-Agent'], contains('com.sameway.app'));
  });

  test('network failure gives no suggestions, not an exception', () async {
    await http.runWithClient(() async {
      expect(await PlaceSearch().search('x y z'), isEmpty);
    }, () => MockClient((_) async => throw const SocketExceptionLike()));
  });
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
