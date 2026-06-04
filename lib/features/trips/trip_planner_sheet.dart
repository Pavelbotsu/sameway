import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/token_storage.dart';
import '../../core/validators/validators.dart';

class _Suggestion {
  final String name;
  final double lat;
  final double lng;
  const _Suggestion({required this.name, required this.lat, required this.lng});
}

class TripPlannerSheet extends StatefulWidget {
  final LatLng? currentPos;
  const TripPlannerSheet({super.key, this.currentPos});

  @override
  State<TripPlannerSheet> createState() => _TripPlannerSheetState();
}

class _TripPlannerSheetState extends State<TripPlannerSheet> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();

  _Suggestion? _originSug;
  _Suggestion? _destSug;
  List<_Suggestion> _originSuggestions = [];
  List<_Suggestion> _destSuggestions = [];
  bool _loadingOrigin = false;
  bool _loadingDest = false;
  Timer? _debounceOrigin;
  Timer? _debounceDest;

  double _corridor = 2.0;
  int _seats = 2;
  DateTime _plannedAt = DateTime.now().add(const Duration(hours: 2));
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _debounceOrigin?.cancel();
    _debounceDest?.cancel();
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions(String query, bool isOrigin) async {
    if (query.length < 3) {
      setState(() => isOrigin
          ? _originSuggestions = []
          : _destSuggestions = []);
      return;
    }
    if (isOrigin) {
      setState(() => _loadingOrigin = true);
    } else {
      setState(() => _loadingDest = true);
    }

    try {
      final origin = widget.currentPos;
      final bbox = origin != null
          ? '&viewbox=${origin.longitude - 0.5},${origin.latitude - 0.5}'
            ',${origin.longitude + 0.5},${origin.latitude + 0.5}&bounded=0'
          : '';
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}&format=json&limit=5&addressdetails=0$bbox',
      );
      final resp = await http.get(
          uri, headers: {'Accept-Language': 'en', 'User-Agent': 'sameway-app'});
      if (resp.statusCode == 200 && mounted) {
        final list = jsonDecode(resp.body) as List;
        final sug = list
            .map((e) => _Suggestion(
                  name: e['display_name'] as String,
                  lat: double.parse(e['lat'] as String),
                  lng: double.parse(e['lon'] as String),
                ))
            .toList();
        setState(() => isOrigin
            ? _originSuggestions = sug
            : _destSuggestions = sug);
      }
    } catch (_) {}
    if (mounted) {
      setState(() => isOrigin
          ? _loadingOrigin = false
          : _loadingDest = false);
    }
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    if (_originSug == null) {
      setState(() => _error = l.selectOriginLocation);
      return;
    }
    if (_destSug == null) {
      setState(() => _error = l.selectDestinationLocation);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.post(
        Uri.parse('$kApiBase/driver/trips'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'origin_name':
              TextSanitizer.sanitize(_originSug!.name.split(',').first),
          'origin_lat': _originSug!.lat,
          'origin_lng': _originSug!.lng,
          'dest_name':
              TextSanitizer.sanitize(_destSug!.name.split(',').first),
          'dest_lat': _destSug!.lat,
          'dest_lng': _destSug!.lng,
          'seats': _seats,
          'corridor_km': _corridor,
          'planned_at': _plannedAt.toUtc().toIso8601String(),
        }),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(
          content: Text(l.tripPlannedSuccess),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        final msg = (jsonDecode(resp.body) as Map)['error'] as String? ?? 'Failed';
        setState(() => _error = msg);
      }
    } catch (_) {
      setState(() => _error = l.networkError);
    }
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _plannedAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_plannedAt),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (time == null) return;
    setState(() {
      _plannedAt = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Widget _searchField({
    required TextEditingController ctrl,
    required String hint,
    required bool loading,
    required List<_Suggestion> suggestions,
    required bool isOrigin,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          onChanged: (v) {
            if (isOrigin) {
              _originSug = null;
              _debounceOrigin?.cancel();
              _debounceOrigin = Timer(
                  const Duration(milliseconds: 400),
                  () => _fetchSuggestions(v, true));
            } else {
              _destSug = null;
              _debounceDest?.cancel();
              _debounceDest = Timer(
                  const Duration(milliseconds: 400),
                  () => _fetchSuggestions(v, false));
            }
          },
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
            filled: true,
            fillColor: AppColors.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            prefixIcon: Icon(
              isOrigin
                  ? Icons.trip_origin_rounded
                  : Icons.location_on_rounded,
              color: isOrigin ? AppColors.primary : AppColors.teal,
              size: 18,
            ),
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textSecondary)),
                  )
                : null,
          ),
        ),
        if (suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: suggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: AppColors.border, height: 1),
              itemBuilder: (_, i) {
                final s = suggestions[i];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    isOrigin
                        ? Icons.trip_origin_rounded
                        : Icons.location_on_outlined,
                    color: isOrigin ? AppColors.primary : AppColors.teal,
                    size: 16,
                  ),
                  title: Text(s.name,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  onTap: () {
                    ctrl.text = s.name.split(',').first;
                    setState(() {
                      if (isOrigin) {
                        _originSug = s;
                        _originSuggestions = [];
                      } else {
                        _destSug = s;
                        _destSuggestions = [];
                      }
                    });
                  },
                );
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 12, 24, MediaQuery.of(context).padding.bottom + 24),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Plan a Trip',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Schedule a future ride for others to join.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),

            const Text('From',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _searchField(
              ctrl: _originCtrl,
              hint: 'Departure city or address',
              loading: _loadingOrigin,
              suggestions: _originSuggestions,
              isOrigin: true,
            ),
            const SizedBox(height: 14),

            const Text('To',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            _searchField(
              ctrl: _destCtrl,
              hint: 'Destination city or address',
              loading: _loadingDest,
              suggestions: _destSuggestions,
              isOrigin: false,
            ),
            const SizedBox(height: 14),

            const Text('Date & Time',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickDateTime,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: AppColors.primary, size: 18),
                    const SizedBox(width: 10),
                    Text(
                      '${_plannedAt.day.toString().padLeft(2, '0')}/'
                      '${_plannedAt.month.toString().padLeft(2, '0')}/'
                      '${_plannedAt.year}  '
                      '${_plannedAt.hour.toString().padLeft(2, '0')}:'
                      '${_plannedAt.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Seats',
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _CounterBtn(
                            icon: Icons.remove,
                            onTap: () =>
                                setState(() => _seats = (_seats - 1).clamp(1, 6)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text('$_seats',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                          ),
                          _CounterBtn(
                            icon: Icons.add,
                            onTap: () =>
                                setState(() => _seats = (_seats + 1).clamp(1, 6)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Corridor: ${_corridor.toStringAsFixed(1)} km',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primary,
                          thumbColor: AppColors.primary,
                          inactiveTrackColor: AppColors.border,
                          overlayShape: SliderComponentShape.noOverlay,
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: _corridor,
                          min: 0.5,
                          max: 10,
                          divisions: 19,
                          onChanged: (v) => setState(() => _corridor = v),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 13)),
            ],
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.event_available_rounded, size: 18),
                label: Text(_submitting ? 'Planning…' : 'Plan Trip'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CounterBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.primary, size: 16),
        ),
      );
}
