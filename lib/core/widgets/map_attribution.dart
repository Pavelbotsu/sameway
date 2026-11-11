import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import '../map_style_provider.dart';

/// Always-visible tile licence credit, placed as the last FlutterMap child.
/// Required by the tile providers (OpenStreetMap's policy explicitly forbids
/// hiding it behind a toggle, which rules out RichAttributionWidget's
/// collapsed "i" button). Tapping opens the OSM copyright page.
class MapAttribution extends StatelessWidget {
  final String text;
  const MapAttribution({super.key, this.text = kOsmAttribution});

  @override
  Widget build(BuildContext context) {
    return SimpleAttributionWidget(
      source: Text(text, style: const TextStyle(fontSize: 10)),
      backgroundColor: Colors.white.withValues(alpha: 0.75),
      onTap: () => launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
        mode: LaunchMode.externalApplication,
      ),
    );
  }
}
