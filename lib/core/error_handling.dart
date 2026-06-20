import 'dart:async';
import 'dart:io' show SocketException;

import 'package:flutter/widgets.dart';

import 'api_client.dart';
import 'app_localizations.dart';

/// Maps any thrown error into a localized, user-facing string. The goal is
/// that no `Exception: 401` or `SocketException: ...` ever reaches the user
/// untouched — every error path can call this and get reasonable copy.
///
/// Lookup order:
///   1. ApiException with HTTP status → mapped per-class
///   2. ApiException with `message == 'timeout'` → timeout copy
///   3. SocketException / TimeoutException → offline / timeout copy
///   4. Anything else → generic copy
String friendlyError(BuildContext context, Object e) {
  final l = AppLocalizations.of(context);
  if (e is ApiException) {
    if (e.message == 'timeout') return l.errTimeout;
    switch (e.statusCode) {
      case 401:
      case 403:
        return l.errSessionExpired;
      case 404:
        return l.errNotFound;
    }
    if (e.statusCode >= 500) return l.errServer;
    // Server returned a specific 4xx message — surface it verbatim if it
    // looks human-readable (no "json:" / Go-style errors), else fall back.
    final msg = e.message.trim();
    final looksHuman = msg.isNotEmpty &&
        !msg.startsWith('json:') &&
        !msg.contains('pq:') &&
        !msg.startsWith('SQL');
    return looksHuman ? msg : l.errGeneric;
  }
  if (e is SocketException) return l.errOffline;
  if (e is TimeoutException) return l.errTimeout;
  return l.errGeneric;
}
