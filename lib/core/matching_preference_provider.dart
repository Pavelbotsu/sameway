import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's preference for AI-assisted match ranking. Default off.
///
/// The backend supports the same flag whether or not an AI provider is
/// actually configured — if the server has no LLM endpoint, every match still
/// comes back tagged "geometric". So this toggle is safe to flip on without
/// breaking matching.
///
/// To remove the AI subsystem from the app: delete this file, remove the
/// `MatchingPreferenceProvider` from `main.dart`, drop the `SwitchListTile`
/// from the side menu, and remove the `preferAI` param defaults from the
/// repositories.
class MatchingPreferenceProvider extends ChangeNotifier {
  static const _key = 'prefer_ai_matching';

  bool _useAI = false;
  bool get useAI => _useAI;

  MatchingPreferenceProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _useAI = prefs.getBool(_key) ?? false;
    notifyListeners();
  }

  Future<void> set(bool value) async {
    if (_useAI == value) return;
    _useAI = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}
