import 'l10n.dart';

/// Server error `code` → user-facing ARB string, in one place (decision 5:
/// the server sends `{error, code}`, the client owns the wording). Add a line
/// here whenever the backend starts sending a new code; unknown codes fall
/// back to the generic error in `friendlyError`.
final Map<String, String Function(L10n)> serverErrorMessages = {
  'account_suspended': (l) => l.legacy_accountSuspended,
  'active_ride': (l) => l.legacy_deleteAccountActiveRide,
  'bad_image': (l) => l.err_badImage,
  'birth_date_invalid': (l) => l.legacy_birthDateRequired,
  'car_details_required': (l) => l.legacy_carDetailsRequired,
  'consent_required': (l) => l.legacy_consentRequiredError,
  'driver_declaration_required': (l) => l.legacy_driverDeclAllRequired,
  'location_required': (l) => l.legacy_errUpdateLocationFirst,
  'no_show_too_early': (l) => l.err_noShowTooEarly,
  'not_picked_up': (l) => l.err_notPickedUp,
  'outside_service_area': (l) => l.legacy_outsideServiceArea,
  'pickup_locked': (l) => l.legacy_pickupLocked,
  'ride_not_active': (l) => l.err_rideNotActive,
  'role_locked_active_ride': (l) => l.err_roleLockedActiveRide,
  'underage': (l) => l.legacy_errUnderage,
  'wrong_code': (l) => l.legacy_errWrongCode,
  'wrong_password': (l) => l.err_passwordIncorrect,
};

/// The localized message for a server error [code], or null when the code is
/// missing or unknown.
String? serverErrorMessage(L10n l, String? code) =>
    code == null ? null : serverErrorMessages[code]?.call(l);
