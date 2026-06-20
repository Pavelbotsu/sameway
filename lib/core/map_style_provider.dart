import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MapStyle { osm, satellite, dark }

class MapStyleProvider extends ChangeNotifier {
  MapStyle _style = MapStyle.osm;
  MapStyle get style => _style;

  MapStyleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('map_style') ?? 'osm';
    _style = MapStyle.values.firstWhere(
      (s) => s.name == saved,
      orElse: () => MapStyle.osm,
    );
    notifyListeners();
  }

  Future<void> setStyle(MapStyle style) async {
    _style = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_style', style.name);
    notifyListeners();
  }

  String get urlTemplate {
    switch (_style) {
      case MapStyle.osm:
        return 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
      case MapStyle.satellite:
        return 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case MapStyle.dark:
        return 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png';
    }
  }

  /// Optional per-tile post-processing. The Carto dark basemap renders roads
  /// as a faint grey only a few shades above the near-black background, so they
  /// nearly disappear. For the dark style we push the tiles through a
  /// contrast+brightness lift (`out = 1.55*in + 8`) which keeps the backdrop
  /// dark while pulling the grey road network well clear of it. Other styles
  /// return null (tiles render untouched).
  TileBuilder? get tileBuilder =>
      _style == MapStyle.dark ? _darkRoadBoostTileBuilder : null;

  static Widget _darkRoadBoostTileBuilder(
    BuildContext context,
    Widget tileWidget,
    TileImage tile,
  ) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1.55, 0, 0, 0, 8, // R
        0, 1.55, 0, 0, 8, // G
        0, 0, 1.55, 0, 8, // B
        0, 0, 0, 1, 0, // A
      ]),
      child: tileWidget,
    );
  }
}
