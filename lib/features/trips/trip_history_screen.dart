import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:skeletonizer/skeletonizer.dart';
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';
import '../../core/token_storage.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<_TripItem> _trips = [];
  bool _loading = true;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jwt = await TokenStorage().getToken();
      final uid = await TokenStorage().getUserId();
      if (jwt == null) return;
      final resp = await http.get(
        Uri.parse('$kApiBase/auth/trips'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = data['trips'] as List? ?? [];
        setState(() {
          _userId = uid ?? data['user_id'] as String?;
          _trips = list
              .map((e) => _TripItem.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l.tripHistory,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          tooltip: l.back,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Skeletonizer(
        enabled: _loading,
        child: _loading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 6,
                itemBuilder: (_, __) =>
                    _TripCard(trip: _TripItem.skeleton(), userId: ''),
              )
            : _trips.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trips.length,
                    itemBuilder: (_, i) =>
                        _TripCard(trip: _trips[i], userId: _userId ?? ''),
                  ),
      ),
    );
  }


  Widget _buildEmpty() {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.history_rounded,
                  color: AppColors.textSecondary, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              l.noTripsYet,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.firstRidePrompt,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripItem {
  final String id;
  final String driverId;
  final String passengerId;
  final double distanceKm;
  final double co2SavedKg;
  final DateTime completedAt;

  const _TripItem({
    required this.id,
    required this.driverId,
    required this.passengerId,
    required this.distanceKm,
    required this.co2SavedKg,
    required this.completedAt,
  });

  factory _TripItem.fromJson(Map<String, dynamic> j) => _TripItem(
        id: j['id'] as String? ?? '',
        driverId: j['driver_id'] as String? ?? '',
        passengerId: j['passenger_id'] as String? ?? '',
        distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
        co2SavedKg: (j['co2_saved_kg'] as num?)?.toDouble() ?? 0,
        completedAt: j['completed_at'] != null
            ? DateTime.tryParse(j['completed_at'] as String) ?? DateTime.now()
            : DateTime.now(),
      );

  /// Sentinel placeholder used by Skeletonizer so the loaded layout
  /// and the loading layout share the exact same widget tree dimensions.
  factory _TripItem.skeleton() => _TripItem(
        id: '',
        driverId: '',
        passengerId: '',
        distanceKm: 12.0,
        co2SavedKg: 1.8,
        completedAt: DateTime.now(),
      );
}

class _TripCard extends StatelessWidget {
  final _TripItem trip;
  final String userId;

  const _TripCard({required this.trip, required this.userId});

  @override
  Widget build(BuildContext context) {
    final isDriving = trip.driverId == userId;
    final icon =
        isDriving ? Icons.drive_eta_rounded : Icons.person_rounded;
    final roleLabel = isDriving ? 'Driver' : 'Passenger';
    final roleColor = isDriving ? AppColors.primary : AppColors.teal;

    final date = trip.completedAt;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: roleColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        roleLabel,
                        style: TextStyle(
                          color: roleColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.route_rounded,
                        color: AppColors.textSecondary, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${trip.distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.eco_rounded,
                        color: AppColors.success, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '${trip.co2SavedKg.toStringAsFixed(2)} kg CO₂',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
