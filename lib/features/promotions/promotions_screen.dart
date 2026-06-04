import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/api_client.dart';
import '../../core/app_colors.dart';
import '../../core/app_localizations.dart';

class _Promotion {
  final String id;
  final String title;
  final String subtitle;
  final int discountPct;
  final String partner;
  final String category;
  final String iconName;
  final DateTime expiresAt;

  const _Promotion({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.discountPct,
    required this.partner,
    required this.category,
    required this.iconName,
    required this.expiresAt,
  });

  bool get isExpired => expiresAt.isBefore(DateTime.now());

  factory _Promotion.fromJson(Map<String, dynamic> j) => _Promotion(
        id: j['id'] as String,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        discountPct: j['discount_pct'] as int,
        partner: j['partner'] as String,
        category: j['category'] as String,
        iconName: j['icon_name'] as String,
        expiresAt: DateTime.parse(j['expires_at'] as String),
      );
}

IconData _iconFromName(String name) {
  switch (name) {
    case 'local_car_wash':
      return Icons.local_car_wash_rounded;
    case 'local_gas_station':
      return Icons.local_gas_station_rounded;
    case 'local_cafe':
      return Icons.local_cafe_rounded;
    case 'local_parking':
      return Icons.local_parking_rounded;
    case 'card_giftcard':
      return Icons.card_giftcard_rounded;
    default:
      return Icons.local_offer_rounded;
  }
}

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  List<_Promotion> _promos = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final resp = await http.get(Uri.parse('$kApiBase/promotions'));
      if (resp.statusCode == 200 && mounted) {
        final list = jsonDecode(resp.body) as List;
        setState(() {
          _promos = list
              .map((e) => _Promotion.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final active = _promos.where((p) => !p.isExpired).toList();
    final expired = _promos.where((p) => p.isExpired).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l.promotionsAndRewards,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader(
                      label: l.activeOffers,
                      icon: Icons.bolt_rounded,
                      color: AppColors.teal),
                  const SizedBox(height: 10),
                  ...active.map((p) => _PromoCard(promo: p)),
                  const SizedBox(height: 20),
                ],
                if (expired.isNotEmpty) ...[
                  _SectionHeader(
                      label: l.expired,
                      icon: Icons.history_rounded,
                      color: AppColors.textSecondary),
                  const SizedBox(height: 10),
                  ...expired.map((p) => _PromoCard(promo: p)),
                ],
                if (_promos.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Column(
                        children: [
                          const Icon(Icons.local_offer_outlined,
                              color: AppColors.border, size: 52),
                          const SizedBox(height: 16),
                          Text(l.noPromotions,
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _SectionHeader(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ],
      );
}

class _PromoCard extends StatelessWidget {
  final _Promotion promo;
  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    final expired = promo.isExpired;
    final accentColor = expired ? AppColors.textSecondary : AppColors.teal;
    final daysLeft = promo.expiresAt.difference(DateTime.now()).inDays;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expired
              ? AppColors.border
              : AppColors.teal.withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Opacity(
        opacity: expired ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFromName(promo.iconName),
                    color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(promo.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${promo.discountPct}% OFF',
                            style: TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(promo.subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            promo.partner,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          expired
                              ? AppLocalizations.of(context).expired
                              : daysLeft == 0
                                  ? 'Expires today'
                                  : 'Expires in $daysLeft days',
                          style: TextStyle(
                              color: expired
                                  ? AppColors.error
                                  : daysLeft <= 3
                                      ? AppColors.error
                                      : AppColors.textSecondary,
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
