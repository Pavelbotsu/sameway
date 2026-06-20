import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_colors.dart';
import '../app_localizations.dart';
import '../token_storage.dart';
import '../../features/auth/auth_repository.dart';

/// Account-sheet row that fires a synthetic ranking request against the
/// configured AI provider and shows the result in a SnackBar — quick way to
/// check Groq (or whatever provider is set) is reachable before relying on
/// it for real matches.
///
/// Three outcomes:
///   1. configured + ok + !fallback → "AI ranker working — model · 123 ms"
///   2. !configured                 → "AI not configured — using geometric"
///   3. error or fallback           → "AI ranker failed: ..."
class TestAITile extends StatefulWidget {
  const TestAITile({super.key});

  @override
  State<TestAITile> createState() => _TestAITileState();
}

class _TestAITileState extends State<TestAITile> {
  bool _running = false;

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = AuthRepository(ApiClient(TokenStorage()));
      final res = await repo.testAIRanker();
      if (!mounted) return;
      final configured = res['ai_configured'] == true;
      final ok = res['ok'] == true;
      final usedFallback = res['used_fallback'] == true;
      final model = (res['model_name'] as String?) ?? '';
      final latency = (res['latency_ms'] as num?)?.toInt() ?? 0;
      final err = (res['error'] as String?) ?? '';

      String msg;
      Color color;
      if (!configured) {
        msg = l.testAIDisabled;
        color = AppColors.textSecondary;
      } else if (ok && !usedFallback) {
        msg = '${l.testAIOK} · $model · ${latency}ms';
        color = AppColors.success;
      } else {
        msg = '${l.testAIFailed}${err.isEmpty ? '' : ': $err'}';
        color = AppColors.error;
      }

      messenger.showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text('${l.testAIFailed}: $e'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return InkWell(
      onTap: _running ? null : _run,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.bolt_rounded,
                color: AppColors.textPrimary, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                l.testAILabel,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
            ),
            const SizedBox(width: 8),
            if (_running)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textSecondary,
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
