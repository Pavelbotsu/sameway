import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MapStyle { osm, satellite, dark }

/// Stadia Maps API key, injected at build time so it is not committed:
///   flutter run --dart-define=STADIA_API_KEY=YOUR_KEY
/// When empty, the dark style falls back to filtered OSM tiles.
const kStadiaApiKey = String.fromEnvironment('STADIA_API_KEY');

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
        return kStadiaApiKey.isEmpty
            ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
            : 'https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}.png?api_key=$kStadiaApiKey';
    }
  }

  /// Fallback dark style when no Stadia key is set = greyscale OSM tiles with white roads (CARTO's dark basemap
  /// needs an API key). Two chained filters, because "bright roads AND bright
  /// labels on a dark ground" is not monotonic in any single value:
  ///  1. split into R = road mask (red channel >= ~244, which is white and
  ///     pale-yellow road fills but not OSM's #f2efe9 ground), G = label mask
  ///     (dark pixels, luminance < 170), B = 12% luminance as the dark ground.
  ///  2. sum the three into grey.
  /// Roads come out white, labels light grey (dark-on-white where they sit on a
  /// road), everything else near-black. Orange/red motorways and pink retail
  /// areas are the known imperfections. Other styles return null.
  TileBuilder? get tileBuilder =>
      _style == MapStyle.dark && kStadiaApiKey.isEmpty
          ? _darkGreyRoadsTileBuilder
          : null;

  static Widget _darkGreyRoadsTileBuilder(
    BuildContext context,
    Widget tileWidget,
    TileImage tile,
  ) {
    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        1, 1, 1, 0, 0, // R = R + G + B of stage 1
        1, 1, 1, 0, 0, // G
        1, 1, 1, 0, 0, // B
        0, 0, 0, 1, 0, // A
      ]),
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          60, 0, 0, 0, -14610, // road mask
          -0.6378, -2.1456, -0.2166, 0, 510, // label mask
          0.02551, 0.08582, 0.00866, 0, 0, // dark ground
          0, 0, 0, 1, 0, // A
        ]),
        child: tileWidget,
      ),
    );
  }
}
