import 'dart:async';
import 'dart:io' show SocketException;

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
///   3. ApiException with HTTP status → mapped per-class
///   4. Known English backend messages (errors that come without a code)
///   5. SocketException / TimeoutException → offline / timeout copy
///   6. Anything else → generic copy. Unknown server text is never shown: the
///      backend speaks English only, and every visible string must follow the
///      app language.
String friendlyError(BuildContext context, Object e) {
  final l = context.l10n;
  if (e is ApiException) {
    if (e.message == 'timeout') return l.legacy_errTimeout;
    final byCode = serverErrorMessage(l, e.code);
    if (byCode != null) return byCode;
    switch (e.statusCode) {
      // Only 401 means the session is gone. A 403 is "not allowed to do THIS"
      // (wrong role, not your ride) and falls through to the message below —
      // it used to read "session expired", which was simply wrong.
      case 401:
        return l.legacy_errSessionExpired;
      case 404:
        return l.legacy_errNotFound;
    }
    if (e.statusCode >= 500) return l.legacy_errServer;
    return _knownBackendMessage(l, e.message.trim()) ?? l.legacy_errGeneric;
  }
  if (e is SocketException) return l.legacy_errOffline;
  if (e is TimeoutException) return l.legacy_errTimeout;
  return l.legacy_errGeneric;
}

/// Exact-match translations for the backend's English `error` strings on
/// responses that carry no `code`. Prefer adding a code on the server and a
/// line in error_codes.dart over growing this list.
String? _knownBackendMessage(L10n l, String msg) {
  switch (msg) {
    case 'driver is not available':
      return l.legacy_errDriverUnavailable;
    case "you're too far from the driver's route":
      return l.legacy_errTooFarFromRoute;
    case 'the driver has already passed you':
      return l.legacy_errDriverPassedYou;
    case "driver's position is not up to date — try again shortly":
      return l.legacy_errDriverPositionStale;
    case 'update your location first':
      return l.legacy_errUpdateLocationFirst;
    case 'offer no longer available':
      return l.legacy_errOfferGone;
    case 'ride is full':
      return l.legacy_errRideFull;
    case 'wrong code':
      return l.legacy_errWrongCode;
    case 'ride is not in the accepted state':
      return l.legacy_errRideNotAccepted;
    case 'invalid credentials':
      return l.legacy_errInvalidCredentials;
    case 'email already registered':
      return l.legacy_errEmailTaken;
    case 'invalid or expired code':
      return l.legacy_errCodeInvalidOrExpired;
    case 'current password is incorrect':
      return l.legacy_errCurrentPasswordWrong;
  }
  return null;
}
