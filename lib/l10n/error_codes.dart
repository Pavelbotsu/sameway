import 'l10n.dart';

/// Server error `code` → user-facing ARB string, in one place (decision 5:
/// the server sends `{error, code}`, the client owns the wording). Add a line
/// here whenever the backend starts sending a new code; unknown codes fall
/// back to the generic error in `friendlyError`.
///
/// [details] is the whole error body: some codes carry the numbers the user
/// needs (`attempts_left`, `wait_s`).
final Map<String, String Function(L10n l, Map<String, dynamic> details)>
    serverErrorMessages = {
  'account_suspended': (l, _) => l.legacy_accountSuspended,
  'active_ride': (l, _) => l.legacy_deleteAccountActiveRide,
  'bad_image': (l, _) => l.err_badImage,
  'birth_date_invalid': (l, _) => l.legacy_birthDateRequired,
  'car_details_required': (l, _) => l.legacy_carDetailsRequired,
  'consent_required': (l, _) => l.legacy_consentRequiredError,
  'driver_declaration_required': (l, _) => l.legacy_driverDeclAllRequired,
  'location_required': (l, _) => l.legacy_errUpdateLocationFirst,
  'no_show_too_early': (l, d) {
    final wait = _int(d['wait_s']);
    return wait != null && wait > 0
        ? l.legacy_noShowTooEarly((wait / 60).ceil())
        : l.err_noShowTooEarly;
  },
  'not_picked_up': (l, _) => l.err_notPickedUp,
  'outside_service_area': (l, _) => l.legacy_outsideServiceArea,
  'pickup_locked': (l, _) => l.legacy_pickupLocked,
  'ride_not_active': (l, _) => l.err_rideNotActive,
  'role_locked_active_ride': (l, _) => l.err_roleLockedActiveRide,
  'underage': (l, _) => l.legacy_errUnderage,
  'wrong_code': (l, d) {
    final left = _int(d['attempts_left']);
    return left != null && left > 0
        ? l.legacy_wrongCodeAttemptsLeft(left)
        : l.legacy_errWrongCode;
  },
  'wrong_password': (l, _) => l.err_passwordIncorrect,
};

/// The localized message for a server error [code], or null when the code is
/// missing or unknown.
String? serverErrorMessage(L10n l, String? code,
        [Map<String, dynamic> details = const {}]) =>
    code == null ? null : serverErrorMessages[code]?.call(l, details);

/// The backend's English `error` texts on responses that carry NO `code`,
/// matched exactly. Only messages the user can act on (or that explain what
/// happened better than "Something went wrong") are here; the rest are client
/// bugs or server faults and get the generic error, which is logged.
/// Prefer a server `code` + a line in [serverErrorMessages] over growing this.
final Map<String, String Function(L10n l)> serverMessageTexts = {
  // Sign-up, sign-in, password
  'invalid credentials': (l) => l.legacy_errInvalidCredentials,
  'email already registered': (l) => l.legacy_errEmailTaken,
  'name is required': (l) => l.err_nameRequired,
  'name cannot be empty': (l) => l.err_nameRequired,
  'name is too long': (l) => l.err_nameTooLong,
  'password must be at least 6 characters': (l) => l.legacy_passwordTooShort,
  'password is too long (max 72 bytes)': (l) => l.err_passwordTooLong,
  'new password must differ from current': (l) => l.err_passwordSameAsCurrent,
  'current password is incorrect': (l) => l.legacy_errCurrentPasswordWrong,
  'invalid or expired code': (l) => l.legacy_errCodeInvalidOrExpired,
  'too many attempts — request a new code': (l) => l.err_tooManyAttempts,
  // Email verification
  'incorrect code': (l) => l.legacy_errCodeInvalidOrExpired,
  'invalid code': (l) => l.legacy_errCodeInvalidOrExpired,
  'code expired': (l) => l.err_codeExpired,
  'no code requested': (l) => l.err_noCodeRequested,
  'please wait before requesting another code': (l) => l.err_waitBeforeNewCode,
  // Profile
  'car details are too long': (l) => l.err_carDetailsTooLong,
  'phone number is invalid': (l) => l.err_phoneInvalid,
  'cannot read photo': (l) => l.err_badImage,
  'account already deleted': (l) => l.err_accountAlreadyDeleted,
  // Chat, reports
  'empty message': (l) => l.err_emptyMessage,
  'messaging unavailable for this user': (l) => l.err_cantMessageUser,
  'you can only message your current match candidates': (l) =>
      l.err_messageMatchesOnly,
  'sending too fast — wait a moment': (l) => l.err_tooManyRequests,
  'too many requests — slow down': (l) => l.err_tooManyRequests,
  'title and body are required': (l) => l.err_bugReportIncomplete,
  // Matching and the ride
  'driver is not available': (l) => l.legacy_errDriverUnavailable,
  "you're too far from the driver's route": (l) => l.legacy_errTooFarFromRoute,
  'the driver has already passed you': (l) => l.legacy_errDriverPassedYou,
  'driver already passed the pickup': (l) => l.legacy_errDriverPassedYou,
  "driver's position is not up to date — try again shortly": (l) =>
      l.legacy_errDriverPositionStale,
  'update your location first': (l) => l.legacy_errUpdateLocationFirst,
  'offer no longer available': (l) => l.legacy_errOfferGone,
  'ride is full': (l) => l.legacy_errRideFull,
  'wrong code': (l) => l.legacy_errWrongCode,
  'ride is not in the accepted state': (l) => l.legacy_errRideNotAccepted,
  'you have already passed this pickup': (l) => l.err_pickupBehindYou,
  'no active route': (l) => l.err_routeNotLive,
  'ride not found or already cancelled': (l) => l.err_rideChanged,
  'request not found or no longer pending': (l) => l.err_rideChanged,
  'request not pending': (l) => l.err_rideChanged,
  'request is no longer declinable — use cancel instead': (l) =>
      l.err_rideChanged,
  'ride is no longer accepted': (l) => l.err_rideChanged,
  'ride is not active': (l) => l.err_rideChanged,
  'ride not in pickup phase': (l) => l.err_rideChanged,
};

final _tooLong = RegExp(r'too long \(max (\d+) characters\)$');
final _photoTooLarge = RegExp(r'^photo is too large \(max (\d+) MB\)$');
// gin's binding errors: "Key: 'X.Email' Error:Field validation for 'Email'
// failed on the 'email' tag" (one line per failed field).
final _binding = RegExp(r"Field validation for '(\w+)' failed on the '(\w+)' tag");

/// The localized message for an English server [message] that came without a
/// code, or null when it isn't one the user can act on.
String? serverMessageText(L10n l, String message) {
  final msg = message.trim();
  final exact = serverMessageTexts[msg];
  if (exact != null) return exact(l);
  final long = _tooLong.firstMatch(msg);
  if (long != null) return l.err_textTooLong(int.parse(long.group(1)!));
  final photo = _photoTooLarge.firstMatch(msg);
  if (photo != null) return l.err_photoTooLarge(photo.group(1)!);
  final b = _binding.firstMatch(msg);
  if (b != null) {
    final field = b.group(1)!;
    final tag = b.group(2)!;
    if (field == 'Email') return l.err_emailInvalid;
    if (field == 'Name' && tag == 'required') return l.err_nameRequired;
    if ((field == 'Password' || field == 'NewPassword') &&
        (tag == 'min' || tag == 'required')) {
      return l.legacy_passwordTooShort;
    }
  }
  return null;
}

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v');
