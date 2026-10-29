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
    final msg = e.message.trim();
    // Known backend messages get proper translations — the Go backend only
    // speaks English, and raw English error copy is unusable for most of the
    // tester base. Keep this map in sync with the backend's `error` strings.
    final known = _knownBackendMessage(l, msg);
    if (known != null) return known;
    // Unknown 4xx — surface it verbatim only if it looks human-readable
    // (no "json:" / Go-style errors), else fall back to generic copy.
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

/// Exact-match translations for the backend's known English `error` strings.
/// Returns null when the message isn't recognized.
String? _knownBackendMessage(AppLocalizations l, String msg) {
  switch (msg) {
    case 'driver is not available':
      return l.errDriverUnavailable;
    case "you're too far from the driver's route":
      return l.errTooFarFromRoute;
    case 'the driver has already passed you':
      return l.errDriverPassedYou;
    case "driver's position is not up to date — try again shortly":
      return l.errDriverPositionStale;
    case 'update your location first':
      return l.errUpdateLocationFirst;
    case 'offer no longer available':
      return l.errOfferGone;
    case 'ride is full':
      return l.errRideFull;
    case 'wrong code':
      return l.errWrongCode;
    case 'ride is not in the accepted state':
      return l.errRideNotAccepted;
    case 'invalid credentials':
      return l.errInvalidCredentials;
    case 'email already registered':
      return l.errEmailTaken;
    case 'invalid or expired code':
      return l.errCodeInvalidOrExpired;
    case 'current password is incorrect':
      return l.errCurrentPasswordWrong;
  }
  return null;
}
