import 'package:flutter/material.dart';

/// Small badge that surfaces when a match was produced by the AI re-ranker
/// (server-stamped via `match_method` on the WS payload).
///
/// Intentionally minimal so deleting the AI subsystem is a one-step cleanup:
/// delete this file, remove its imports, and the call sites become noop
/// fallthroughs in the `if (offer.matchedByAI)` branch.
class AIMatchChip extends StatelessWidget {
  const AIMatchChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF7C3AED).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF7C3AED).withValues(alpha: 0.55),
          width: 0.6,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, color: Color(0xFFC4B5FD), size: 10),
          SizedBox(width: 3),
          Text(
            'AI',
            style: TextStyle(
              color: Color(0xFFE9D5FF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
