import 'package:flutter/material.dart';
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
}
