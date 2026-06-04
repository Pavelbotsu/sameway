import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/token_storage.dart';

class _PlannedTrip {
  final String id;
  final String driverName;
  final String carSummary;
  final String originName;
  final String destName;
  final double distanceKm;
  final DateTime plannedAt;
  final int seats;
  final String status;

  const _PlannedTrip({
    required this.id,
    required this.driverName,
    required this.carSummary,
    required this.originName,
    required this.destName,
    required this.distanceKm,
    required this.plannedAt,
    required this.seats,
    required this.status,
  });

  factory _PlannedTrip.fromJson(Map<String, dynamic> j) => _PlannedTrip(
        id: j['id'] as String,
        driverName: j['driver_name'] as String? ?? 'Driver',
        carSummary: j['car_summary'] as String? ?? '',
        originName: j['origin_name'] as String,
        destName: j['destination_name'] as String,
        distanceKm: (j['distance_km'] as num).toDouble(),
        plannedAt: DateTime.parse(j['planned_at'] as String),
        seats: j['seats'] as int,
        status: j['status'] as String,
      );

  /// Sentinel placeholder for Skeletonizer.
  factory _PlannedTrip.skeleton() => _PlannedTrip(
        id: '',
        driverName: 'Loading driver',
        carSummary: 'Toyota Corolla · White',
        originName: 'Origin location',
        destName: 'Destination location',
        distanceKm: 12.0,
        plannedAt: DateTime.now(),
        seats: 2,
        status: 'open',
      );
}

enum _SortBy { distance, time, destination }

class TripSearchSheet extends StatefulWidget {
  final LatLng? currentPos;
  const TripSearchSheet({super.key, this.currentPos});

  @override
  State<TripSearchSheet> createState() => _TripSearchSheetState();
}

class _TripSearchSheetState extends State<TripSearchSheet> {
  final _originCtrl = TextEditingController();
  final _destCtrl = TextEditingController();

  List<_PlannedTrip> _results = [];
  bool _loading = false;
  bool _searched = false;
  _SortBy _sortBy = _SortBy.time;
  String? _error;

  @override
  void dispose() {
    _originCtrl.dispose();
    _destCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final l = AppLocalizations.of(context);
    final origin = widget.currentPos;
    if (origin == null) {
      setState(() => _error = l.locationNotAvailable);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final sortMap = {
      _SortBy.distance: 'distance',
      _SortBy.time: 'time',
      _SortBy.destination: 'destination',
    };

    try {
      final resp = await http.post(
        Uri.parse('$kApiBase/trips/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'origin_lat': origin.latitude,
          'origin_lng': origin.longitude,
          'radius_km': 50.0,
          'sort_by': sortMap[_sortBy],
        }),
      );
      if (resp.statusCode == 200 && mounted) {
        final list = jsonDecode(resp.body) as List;
        setState(() {
          _results = list
              .map((e) => _PlannedTrip.fromJson(e as Map<String, dynamic>))
              .toList();
          _searched = true;
        });
      }
    } catch (_) {
      setState(() => _error = l.networkError);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _requestTrip(_PlannedTrip trip) async {
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.post(
        Uri.parse('$kApiBase/passenger/request-driver'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'driver_id': trip.id}),
      );
      if (!mounted) return;
      final ok = resp.statusCode == 200;
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? l.requestSent : l.requestFailed),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
      if (ok) Navigator.pop(context);
    } catch (_) {}
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
          24, 12, 24, MediaQuery.of(context).padding.bottom + 16),
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
          const Text('Find Planned Trips',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Search for upcoming trips near you.',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),

          // Sort chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Sort: ',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
                ..._SortBy.values.map((s) {
                  final label = switch (s) {
                    _SortBy.distance => 'Distance',
                    _SortBy.time => 'Departure',
                    _SortBy.destination => 'Destination',
                  };
                  final selected = _sortBy == s;
                  return GestureDetector(
                    onTap: () => setState(() => _sortBy = s),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : AppColors.border,
                          width: 1.2,
                        ),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.normal)),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _search,
              icon: _loading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.search_rounded, size: 18),
              label: Text(_loading ? 'Searching…' : 'Search Trips'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: const TextStyle(
                    color: AppColors.error, fontSize: 13)),
          ],

          if (_loading) ...[
            const SizedBox(height: 16),
            Skeletonizer(
              enabled: true,
              child: Column(
                children: List.generate(
                  3,
                  (_) => _TripCard(
                    trip: _PlannedTrip.skeleton(),
                    onRequest: () {},
                  ),
                ),
              ),
            ),
          ],
          if (_searched && !_loading) ...[
            const SizedBox(height: 16),
            if (_results.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.directions_car_outlined,
                            color: AppColors.textSecondary, size: 24),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No planned trips found',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Try adjusting your search area.',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.4),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (_, i) => _TripCard(
                    trip: _results[i],
                    onRequest: () => _requestTrip(_results[i]),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final _PlannedTrip trip;
  final VoidCallback onRequest;
  const _TripCard({required this.trip, required this.onRequest});

  @override
  Widget build(BuildContext context) {
    final dt = trip.plannedAt.toLocal();
    final dateStr =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
        '  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.drive_eta_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(trip.driverName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    if (trip.carSummary.trim().isNotEmpty)
                      Text(trip.carSummary.trim(),
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${trip.seats} seats',
                      style: const TextStyle(
                          color: AppColors.teal,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  if (trip.distanceKm > 0)
                    Text('${trip.distanceKm.toStringAsFixed(0)} km',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.trip_origin_rounded,
                  color: AppColors.primary, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text(trip.originName,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(Icons.location_on_rounded,
                  color: AppColors.teal, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text(trip.destName,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  color: AppColors.textSecondary, size: 13),
              const SizedBox(width: 4),
              Text(dateStr,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11)),
              const Spacer(),
              TextButton(
                onPressed: onRequest,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: AppColors.teal)),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Request',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
