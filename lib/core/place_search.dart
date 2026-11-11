import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'map_style_provider.dart' show kMapUserAgentPackage;

class PlaceSuggestion {
  final String name;
  final double lat;
  final double lng;
  const PlaceSuggestion({required this.name, required this.lat, required this.lng});
}

/// Search-as-you-type for places, used by the destination / route boxes.
///
/// Uses Photon (photon.komoot.io, OpenStreetMap data), which is built for
/// autocomplete. Nominatim, used before, explicitly forbids client-side
/// autocomplete in its usage policy and caps clients at 1 request/s. The
/// public Photon instance is fair-use only — self-host it (or move to a paid
/// geocoder) before real traffic.
///
/// One instance per search box: every call bumps a sequence number and a
/// response that arrives after a newer query started is dropped, so a slow
/// "Kra" result can't overwrite the "Kraków" list.
class PlaceSearch {
  static const _base = 'https://photon.komoot.io/api/';
  // Photon's public instance only localizes these; others get local names.
  static const _photonLangs = {'en', 'de', 'fr', 'it'};

  int _seq = 0;

  /// Up to [limit] places for [query], biased to [near] (and limited to
  /// ±0.5° around it when [bounded]). Returns null when a newer search has
  /// started since — the caller should ignore it. Network errors and
  /// timeouts return an empty list.
  Future<List<PlaceSuggestion>?> search(
    String query, {
    LatLng? near,
    String languageCode = 'en',
    bool bounded = true,
    int limit = 5,
  }) async {
    final seq = ++_seq;
    final params = <String, String>{
      'q': query,
      'limit': '$limit',
      if (_photonLangs.contains(languageCode)) 'lang': languageCode,
      if (near != null) 'lat': near.latitude.toStringAsFixed(4),
      if (near != null) 'lon': near.longitude.toStringAsFixed(4),
      if (near != null && bounded)
        'bbox': [
          near.longitude - 0.5,
          near.latitude - 0.5,
          near.longitude + 0.5,
          near.latitude + 0.5,
        ].map((v) => v.toStringAsFixed(4)).join(','),
    };
    List<PlaceSuggestion> results = const [];
    try {
      final res = await http.get(
        Uri.parse(_base).replace(queryParameters: params),
        headers: {'User-Agent': 'Sameway/1.0 ($kMapUserAgentPackage)'},
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) results = parsePhoton(res.body);
    } catch (_) {/* offline / timeout → no suggestions */}
    return seq == _seq ? results : null;
  }

  /// Parses a Photon GeoJSON response. Exposed for tests.
  static List<PlaceSuggestion> parsePhoton(String body) {
    final features = (jsonDecode(body) as Map)['features'] as List? ?? const [];
    final out = <PlaceSuggestion>[];
    for (final f in features) {
      final coords = (f['geometry']?['coordinates'] as List?)?.cast<num>();
      final p = (f['properties'] as Map?) ?? const {};
      if (coords == null || coords.length < 2) continue;
      final street = [p['street'], p['housenumber']]
          .whereType<String>()
          .join(' ')
          .trim();
      final parts = <String>[
        if (p['name'] is String) p['name'] as String,
        if (street.isNotEmpty) street,
        if (p['city'] is String) p['city'] as String,
        if (p['country'] is String) p['country'] as String,
      ];
      // Drop repeats ("Kraków, Kraków, Poland").
      final seen = <String>{};
      final name = parts.where(seen.add).join(', ');
      if (name.isEmpty) continue;
      out.add(PlaceSuggestion(
          name: name, lat: coords[1].toDouble(), lng: coords[0].toDouble()));
    }
    return out;
  }
}
