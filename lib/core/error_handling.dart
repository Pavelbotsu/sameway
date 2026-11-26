import 'dart:async';
import 'dart:io' show SocketException;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/widgets.dart';

import '../l10n/error_codes.dart';
import '../l10n/l10n.dart';
import 'api_client.dart';

/// Maps any thrown error into a localized, user-facing string. The goal is
/// that no `Exception: 401` or `SocketException: ...` ever reaches the user
/// untouched — every error path can call this and get reasonable copy.
///
/// Lookup order:
///   1. ApiException `message == 'timeout'` → timeout copy
///   2. ApiException with a server `code` → lib/l10n/error_codes.dart
///   3. Known English backend messages (errors without a code), also in
///      error_codes.dart. Before the status: a wrong password on sign-in is a
///      401 too, and must not read "session expired".
///   4. ApiException HTTP status → mapped per class
///   5. SocketException / TimeoutException → offline / timeout copy
///   6. Anything else → generic copy, and the raw error goes to Crashlytics
///      ([reportGenericError]). Unknown server text is never shown: the
///      backend speaks English only, and every visible string must follow the
///      app language.
String friendlyError(BuildContext context, Object e) {
  final l = context.l10n;
  if (e is ApiException) {
    if (e.message == 'timeout') return l.legacy_errTimeout;
    final byCode = serverErrorMessage(l, e.code, e.details);
    if (byCode != null) return byCode;
    final byText = serverMessageText(l, e.message);
    if (byText != null) return byText;
    switch (e.statusCode) {
      // Only 401 means the session is gone. A 403 is "not allowed to do THIS"
      // (wrong role, not your ride) and falls through to the generic error.
      case 401:
        return l.legacy_errSessionExpired;
      case 404:
        return l.legacy_errNotFound;
      case 429:
        return l.err_tooManyRequests;
    }
    if (e.statusCode >= 500) return l.legacy_errServer;
    reportGenericError('HTTP ${e.statusCode}'
        '${e.code == null ? '' : ' code=${e.code}'}: ${e.message}');
    return l.legacy_errGeneric;
  }
  if (e is SocketException) return l.legacy_errOffline;
  if (e is TimeoutException) return l.legacy_errTimeout;
  reportGenericError('${e.runtimeType}: $e');
  return l.legacy_errGeneric;
}

/// Where [friendlyError] sends the raw error when it shows the generic
/// message, so unmapped server messages show up in Crashlytics. Tests swap it.
@visibleForTesting
void Function(String raw) genericErrorSink = _recordToCrashlytics;

final _reported = <String>{};

/// Reports [raw] once per app run (friendlyError also runs inside build).
void reportGenericError(String raw) {
  if (_reported.length >= 100 || !_reported.add(raw)) return;
  genericErrorSink(raw);
}

@visibleForTesting
void resetReportedGenericErrors() => _reported.clear();

/// Non-fatal; honours the user's crash-reporting consent (collection is off
/// without it). Never throws: Firebase may not be set up (tests, misconfigured
/// builds).
void _recordToCrashlytics(String raw) {
  debugPrint('friendlyError fallback: $raw');
  try {
    FirebaseCrashlytics.instance
        .recordError(UnmappedError(raw), StackTrace.current,
            reason: 'generic error shown to the user', fatal: false)
        .catchError((Object _) {});
  } catch (_) {/* Firebase not initialised */}
}

/// What Crashlytics groups the generic-error reports under.
class UnmappedError implements Exception {
  UnmappedError(this.raw);
  final String raw;
  @override
  String toString() => 'UnmappedError: $raw';
}
