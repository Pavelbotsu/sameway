import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../api_client.dart';
import '../app_colors.dart';
import '../app_localizations.dart';
import '../token_storage.dart';

/// Driver account-sheet row for the micro-detour opt-in (Round 2 §2).
///
/// Unlike the AI-matching preference (device-local SharedPreferences), this
/// flag lives SERVER-SIDE on the user row because it drives matching: the
/// backend only runs the detour pass for drivers with allow_micro_detour.
/// State loads from GET /auth/profile and persists via PUT /auth/profile.
class MicroDetourToggleTile extends StatefulWidget {
  const MicroDetourToggleTile({super.key});

  @override
  State<MicroDetourToggleTile> createState() => _MicroDetourToggleTileState();
}

class _MicroDetourToggleTileState extends State<MicroDetourToggleTile> {
  bool _value = false;
  bool _busy = true; // disabled until the profile fetch resolves

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.get(
        Uri.parse('$kApiBase/auth/profile'),
        headers: {'Authorization': 'Bearer $jwt'},
      );
      if (resp.statusCode == 200 && mounted) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        setState(() {
          _value = body['allow_micro_detour'] == true;
          _busy = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _set(bool v) async {
    final prev = _value;
    setState(() {
      _value = v;
      _busy = true;
    });
    try {
      final jwt = await TokenStorage().getToken();
      if (jwt == null) return;
      final resp = await http.put(
        Uri.parse('$kApiBase/auth/profile'),
        headers: {
          'Authorization': 'Bearer $jwt',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'allow_micro_detour': v}),
      );
      if (!mounted) return;
      if (resp.statusCode != 200) {
        setState(() => _value = prev); // roll back on failure
      }
    } catch (_) {
      if (mounted) setState(() => _value = prev);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: _busy ? null : () => _set(!_value),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.alt_route_rounded,
                color: AppColors.textPrimary, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.allowMicroDetourTitle,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l.allowMicroDetourSubtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            CupertinoSwitch(
              value: _value,
              onChanged: _busy ? null : _set,
              activeTrackColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }
}
