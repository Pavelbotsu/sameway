import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// The app's original string API, kept so existing screens compile
/// unchanged. Every string now comes from the ARB files (lib/l10n, the
/// `legacy_*` keys); this class only forwards to the generated [L10n].
///
/// New code uses `context.l10n` (lib/l10n/l10n.dart). Screens move over as
/// later phases touch them; when nothing calls a getter any more, delete it
/// here and its `legacy_*` key from the three ARB files. Delete the class when
/// the last caller is gone.
class AppLocalizations {
  AppLocalizations(this.locale) : _g = l10nFor(locale);

  final Locale locale;
  final L10n _g;

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  static const delegate = _AppLocalizationsDelegate();

  /// Languages the app ships: en, uk, pl (decision 16). Single source for the
  /// delegate, MaterialApp.supportedLocales and the device-locale default.
  static const supportedLanguageCodes = l10nLanguageCodes;

  // ─── Role selection ──────────────────────────────────────────────────────────
  String get iAm => _g.legacy_iAm;
  String get chooseRole => _g.legacy_chooseRole;
  String get driver => _g.legacy_driver;
  String get driverSubtitle => _g.legacy_driverSubtitle;
  String get passenger => _g.legacy_passenger;
  String get passengerSubtitle => _g.legacy_passengerSubtitle;
  String get continueAsGuest => _g.legacy_continueAsGuest;
  String get canSwitchRoles => _g.legacy_canSwitchRoles;
  String get exploreAsGuest => _g.legacy_exploreAsGuest;
  String get guestSubtitle => _g.legacy_guestSubtitle;
  String get guestDriver => _g.legacy_guestDriver;
  String get guestPassenger => _g.legacy_guestPassenger;

  // ─── Auth screen ─────────────────────────────────────────────────────────────
  String get welcomeBack => _g.legacy_welcomeBack;
  String get createAccount => _g.legacy_createAccount;
  String get signInContinue => _g.legacy_signInContinue;
  String get joinSameway => _g.legacy_joinSameway;
  String get signIn => _g.legacy_signIn;
  String get signUp => _g.legacy_signUp;

  // ─── Home top bar & account sheet ────────────────────────────────────────────
  String get account => _g.legacy_account;
  String get switchRole => _g.legacy_switchRole;
  String get language => _g.legacy_language;
  String get signOut => _g.legacy_signOut;
  String get guest => _g.legacy_guest;

  // ─── Forms / validators ──────────────────────────────────────────────────────
  String get fieldRequired => _g.legacy_fieldRequired;

  // ─── Quick role-switch sheet ─────────────────────────────────────────────────
  String get switchRoleTo => _g.legacy_switchRoleTo;
  String get switchToDriver => _g.legacy_switchToDriver;
  String get switchToPassenger => _g.legacy_switchToPassenger;
  String get currentRole => _g.legacy_currentRole;

  // ─── Account & Security ──────────────────────────────────────────────────────
  String get accountSecurity => _g.legacy_accountSecurity;

  // ─── Driver home ─────────────────────────────────────────────────────────────
  String get readyToShare => _g.legacy_readyToShare;
  String get setRouteDesc => _g.legacy_setRouteDesc;
  String get setRoute => _g.legacy_setRoute;
  String get settingRoute => _g.legacy_settingRoute;
  String get findPassengers => _g.legacy_findPassengers;
  String get setYourRoute => _g.legacy_setYourRoute;
  String get destination => _g.legacy_destination;
  String get yourDestination => _g.legacy_yourDestination;
  String get yourRequests => _g.legacy_yourRequests;
  String get yourRequestsHint => _g.legacy_yourRequestsHint;
  String driversHeadingYourWay(int n) => _g.legacy_driversHeadingYourWay(n);
  String get likelyMatchChip => _g.legacy_likelyMatchChip;

  // ─── Persistent chat (Round 2 §3) ────────────────────────────────────────────
  String get chatConversation => _g.legacy_chatConversation;
  String get chatUnavailable => _g.legacy_chatUnavailable;
  String get chatSlowDown => _g.legacy_chatSlowDown;
  String get messagesTitle => _g.legacy_messagesTitle;
  String get noConversations => _g.legacy_noConversations;
  String get noConversationsDesc => _g.legacy_noConversationsDesc;
  String blockUserQ(String name) => _g.legacy_blockUserQ(name);
  String get blockUserBody => _g.legacy_blockUserBody;
  String get blockAction => _g.legacy_blockAction;
  String get userBlocked => _g.legacy_userBlocked;
  String reportUserQ(String name) => _g.legacy_reportUserQ(name);
  String get reportReasonHint => _g.legacy_reportReasonHint;
  String get reportAction => _g.legacy_reportAction;
  String get userReported => _g.legacy_userReported;

  // ─── Partial relay + micro-detour (Round 2 §1–2) ─────────────────────────────
  String get partialRideTitle => _g.legacy_partialRideTitle;
  String relayStopInfo(String stop, int meters) => _g.legacy_relayStopInfo(stop, meters);
  String get relayFallbackInfo => _g.legacy_relayFallbackInfo;
  String get acceptPartialRide => _g.legacy_acceptPartialRide;
  String get relayLeg2Searching => _g.legacy_relayLeg2Searching;
  String get microDetourPassengerNote => _g.legacy_microDetourPassengerNote;
  String detourAddsLabel(int meters, int seconds) => _g.legacy_detourAddsLabel(meters, seconds);
  String get allowMicroDetourTitle => _g.legacy_allowMicroDetourTitle;
  String get allowMicroDetourSubtitle => _g.legacy_allowMicroDetourSubtitle;

  // ─── Match-state banner (Round 2 §6) ─────────────────────────────────────────
  String get matchStateSearching => _g.legacy_matchStateSearching;
  String get matchStateSearchingDesc => _g.legacy_matchStateSearchingDesc;
  String get matchStateCandidatesDesc => _g.legacy_matchStateCandidatesDesc;
  String get matchStateOffer => _g.legacy_matchStateOffer;
  String get matchStateOfferDesc => _g.legacy_matchStateOfferDesc;
  String get matchStateRequested => _g.legacy_matchStateRequested;
  String get matchStateRequestedDesc => _g.legacy_matchStateRequestedDesc;
  String get matchStateMatched => _g.legacy_matchStateMatched;
  String matchStateMatchedWith(String name) => _g.legacy_matchStateMatchedWith(name);
  String get matchStateMatchedDesc => _g.legacy_matchStateMatchedDesc;
  String get matchStateInProgress => _g.legacy_matchStateInProgress;
  String get matchStateInProgressDesc => _g.legacy_matchStateInProgressDesc;
  String get pickOnMap => _g.legacy_pickOnMap;
  String get moveMapToDestination => _g.legacy_moveMapToDestination;
  String get setDestinationHere => _g.legacy_setDestinationHere;
  String get adviceTitle => _g.legacy_adviceTitle;
  String adviceTripTooShort(String km) => _g.legacy_adviceTripTooShort(km);
  String adviceWalkCloser(int meters) => _g.legacy_adviceWalkCloser(meters);
  String get adviceEnableLongWalk => _g.legacy_adviceEnableLongWalk;
  String get adviceNoSameWayDrivers => _g.legacy_adviceNoSameWayDrivers;
  String get adviceNoDrivers => _g.legacy_adviceNoDrivers;
  String get adviceSetDestination => _g.legacy_adviceSetDestination;
  String get corridorRadius => _g.legacy_corridorRadius;
  String get availableSeats => _g.legacy_availableSeats;
  String get routeActive => _g.legacy_routeActive;
  String get exploringAsGuest => _g.legacy_exploringAsGuest;
  String get signInToShareRoute => _g.legacy_signInToShareRoute;
  String get signInShareDesc => _g.legacy_signInShareDesc;

  // ─── Passenger home ──────────────────────────────────────────────────────────
  String get lookingForRides => _g.legacy_lookingForRides;
  String get lookingDesc => _g.legacy_lookingDesc;
  String get signInToFindRides => _g.legacy_signInToFindRides;
  String get signInFindDesc => _g.legacy_signInFindDesc;

  // ─── Sign-in prompt sheet ────────────────────────────────────────────────────
  String get signInToContinue => _g.legacy_signInToContinue;
  String get signInRegister => _g.legacy_signInRegister;

  // ─── Auth — fields and toggles ───────────────────────────────────────────────
  String get fullName => _g.legacy_fullName;
  String get emailAddress => _g.legacy_emailAddress;
  String get password => _g.legacy_password;
  String get invalidEmail => _g.legacy_invalidEmail;
  String get minSixChars => _g.legacy_minSixChars;
  String get noAccountYet => _g.legacy_noAccountYet;
  String get alreadyHaveAccount => _g.legacy_alreadyHaveAccount;

  // ─── Onboarding pages ────────────────────────────────────────────────────────
  String get onboardTitle1 => _g.legacy_onboardTitle1;
  String get onboardSubtitle1 => _g.legacy_onboardSubtitle1;
  String get onboardTitle2 => _g.legacy_onboardTitle2;
  String get onboardSubtitle2 => _g.legacy_onboardSubtitle2;
  String get onboardTitle3 => _g.legacy_onboardTitle3;
  String get onboardSubtitle3 => _g.legacy_onboardSubtitle3;
  String get skip => _g.legacy_skip;
  String get getStarted => _g.legacy_getStarted;
  String get continueLabel => _g.legacy_continueLabel;

  // ─── First-run safety disclaimers (onboarding carousel) ──────────────────────
  String get safetyPassengerTitle => _g.legacy_safetyPassengerTitle;
  String get safetyPassengerBody => _g.legacy_safetyPassengerBody;
  String get safetyDriverTitle => _g.legacy_safetyDriverTitle;
  String get safetyDriverBody => _g.legacy_safetyDriverBody;

  // ─── Common buttons / dialogs ────────────────────────────────────────────────
  String get save => _g.legacy_save;
  String get cancel => _g.legacy_cancel;
  String get later => _g.legacy_later;
  String get openSettings => _g.legacy_openSettings;
  String get gpsOff => _g.legacy_gpsOff;
  String get gpsOffMessage => _g.legacy_gpsOffMessage;
  String get keepRide => _g.legacy_keepRide;
  String get cancelRideQ => _g.legacy_cancelRideQ;
  String get cancelRideMessageDriver => _g.legacy_cancelRideMessageDriver;
  String get cancelRideMessagePassenger => _g.legacy_cancelRideMessagePassenger;

  // ─── Offer / Accepted / Looking cards ────────────────────────────────────────
  String get rideOffer => _g.legacy_rideOffer;
  String get accept => _g.legacy_accept;
  String get decline => _g.legacy_decline;
  String get rideAccepted => _g.legacy_rideAccepted;
  String get youAreInTheRide => _g.legacy_youAreInTheRide;
  String get driverNotified => _g.legacy_driverNotified;
  String get messageDriver => _g.legacy_messageDriver;
  String get driverLabel => _g.legacy_driverLabel;
  String get corridorLabel => _g.legacy_corridorLabel;
  String get seatLabel => _g.legacy_seatLabel;
  String get seatsLabel => _g.legacy_seatsLabel;

  // ─── Driver home — requests list ─────────────────────────────────────────────
  String get noRideRequests => _g.legacy_noRideRequests;
  String get noRideRequestsDesc => _g.legacy_noRideRequestsDesc;

  // ─── Account & Security ──────────────────────────────────────────────────────
  String get displayName => _g.legacy_displayName;
  String get changePassword => _g.legacy_changePassword;
  String get currentPassword => _g.legacy_currentPassword;
  String get newPassword => _g.legacy_newPassword;
  String get confirmNewPassword => _g.legacy_confirmNewPassword;
  String get updatePassword => _g.legacy_updatePassword;
  String get passwordSameAsCurrent => _g.legacy_passwordSameAsCurrent;
  String get passwordsNotMatch => _g.legacy_passwordsNotMatch;
  String get passwordTooShort => _g.legacy_passwordTooShort;
  String get passwordUpdated => _g.legacy_passwordUpdated;
  String get networkError => _g.legacy_networkError;
  String get nameUpdated => _g.legacy_nameUpdated;
  String get emailCopied => _g.legacy_emailCopied;

  // ─── Chat ────────────────────────────────────────────────────────────────────
  String get activeTrip => _g.legacy_activeTrip;
  String get noMessages => _g.legacy_noMessages;
  String get messageHint => _g.legacy_messageHint;
  String typing(String name) => _g.legacy_typing(name);

  // ─── Trip history ────────────────────────────────────────────────────────────
  String get tripHistory => _g.legacy_tripHistory;
  String get noTripsYet => _g.legacy_noTripsYet;
  String get firstRidePrompt => _g.legacy_firstRidePrompt;

  // ─── Trip planner / search sheets ────────────────────────────────────────────
  String get selectOriginLocation => _g.legacy_selectOriginLocation;
  String get selectDestinationLocation => _g.legacy_selectDestinationLocation;
  String get tripPlannedSuccess => _g.legacy_tripPlannedSuccess;
  String get locationNotAvailable => _g.legacy_locationNotAvailable;
  String get requestSent => _g.legacy_requestSent;
  String get requestFailed => _g.legacy_requestFailed;

  // ─── Promotions ──────────────────────────────────────────────────────────────
  String get promotionsAndRewards => _g.legacy_promotionsAndRewards;
  String get activeOffers => _g.legacy_activeOffers;
  String get expired => _g.legacy_expired;
  String get noPromotions => _g.legacy_noPromotions;

  // ─── Rating sheet ────────────────────────────────────────────────────────────
  String get rateYourDriver => _g.legacy_rateYourDriver;
  String get rateYourPassenger => _g.legacy_rateYourPassenger;
  String get howWasExperience => _g.legacy_howWasExperience;
  String get addCommentOptional => _g.legacy_addCommentOptional;
  String get submit => _g.legacy_submit;
  String get skipRating => _g.legacy_skipRating;

  // ─── Car edit sheet ──────────────────────────────────────────────────────────
  String get myCar => _g.legacy_myCar;
  String get carMake => _g.legacy_carMake;
  String get carModel => _g.legacy_carModel;
  String get carColor => _g.legacy_carColor;
  String get carPlate => _g.legacy_carPlate;
  String get carMakeHint => _g.legacy_carMakeHint;
  String get carModelHint => _g.legacy_carModelHint;
  String get carColorHint => _g.legacy_carColorHint;
  String get carPlateHint => _g.legacy_carPlateHint;
  String get carInfoSaved => _g.legacy_carInfoSaved;

  // ─── Misc tiles / sheets ─────────────────────────────────────────────────────
  String get testNotificationSent => _g.legacy_testNotificationSent;
  String get mapStyle => _g.legacy_mapStyle;
  String get planATrip => _g.legacy_planATrip;
  String get findPlannedTrips => _g.legacy_findPlannedTrips;
  String get testNotification => _g.legacy_testNotification;
  String get aiMatchingLabel => _g.legacy_aiMatchingLabel;
  String get aiMatchingSubtitle => _g.legacy_aiMatchingSubtitle;

  // ─── AI ranker self-test ─────────────────────────────────────────────────────
  String get testAILabel => _g.legacy_testAILabel;
  String get testAIOK => _g.legacy_testAIOK;
  String get testAIFailed => _g.legacy_testAIFailed;
  String get testAIDisabled => _g.legacy_testAIDisabled;

  // ─── Walk-to-pickup banner ───────────────────────────────────────────────────
  String walkToPickup(String dist) => _g.legacy_walkToPickup(dist);

  // ─── Candidate driver list (pre-match) ───────────────────────────────────────
  String get candidateDriversTitle => _g.legacy_candidateDriversTitle;
  String get candidateDriversEmpty => _g.legacy_candidateDriversEmpty;
  String get sameWayBadge => _g.legacy_sameWayBadge;
  String get newDriverBadge => _g.legacy_newDriverBadge;
  String etaApprox(int min) => _g.legacy_etaApprox(min);
  String get driverDetails => _g.legacy_driverDetails;
  String walkShort(String dist) => _g.legacy_walkShort(dist);

  // ─── Driver pre-accept disclosure ────────────────────────────────────────────
  String get pickupPointLabel => _g.legacy_pickupPointLabel;
  String get dropoffPointLabel => _g.legacy_dropoffPointLabel;
  String ridesWithYou(String dist) => _g.legacy_ridesWithYou(dist);
  String get zeroDetourLabel => _g.legacy_zeroDetourLabel;
  String get noDestinationDeclared => _g.legacy_noDestinationDeclared;
  String walkToPickupShort(String dist) => _g.legacy_walkToPickupShort(dist);
  String walkApproxMinutes(int min) => _g.legacy_walkApproxMinutes(min);
  String get openWalkingDirections => _g.legacy_openWalkingDirections;
  String get tellCodeToPassenger => _g.legacy_tellCodeToPassenger;
  String get askDriverForCode => _g.legacy_askDriverForCode;
  String get copyCode => _g.legacy_copyCode;
  String get codeCopied => _g.legacy_codeCopied;

  // ─── Friendly error messages (Phase 1.4) ─────────────────────────────────────
  String get errSessionExpired => _g.legacy_errSessionExpired;
  String get errNotFound => _g.legacy_errNotFound;
  String get errServer => _g.legacy_errServer;
  String get errOffline => _g.legacy_errOffline;
  String get errGeneric => _g.legacy_errGeneric;
  String get errTimeout => _g.legacy_errTimeout;
  String get noInternet => _g.legacy_noInternet;
  String get locationNotSyncing => _g.legacy_locationNotSyncing;
  String get reconnecting => _g.legacy_reconnecting;
  String get myLocation => _g.legacy_myLocation;
  String get walkToDestination => _g.legacy_walkToDestination;
  String get walkToDestinationHint => _g.legacy_walkToDestinationHint;
  String walkEstimate(int minutes, int metres) => _g.legacy_walkEstimate(minutes, metres);

  // ─── Pre-permission rationale (Phase 1.7) ────────────────────────────────────
  String get permLocationTitle => _g.legacy_permLocationTitle;
  String get permLocationBody => _g.legacy_permLocationBody;
  String get permNotifTitle => _g.legacy_permNotifTitle;
  String get permNotifBody => _g.legacy_permNotifBody;
  String get permContinue => _g.legacy_permContinue;
  String get permNotNow => _g.legacy_permNotNow;

  // ─── Mid-ride safety check-in ────────────────────────────────────────────────
  String get checkInTitle => _g.legacy_checkInTitle;
  String checkInBody(String otherParty) => _g.legacy_checkInBody(otherParty);
  String get checkInAllGood => _g.legacy_checkInAllGood;
  String get checkInNeedHelp => _g.legacy_checkInNeedHelp;

  // ─── SOS (Phase 1.2) ─────────────────────────────────────────────────────────
  String get sos => _g.legacy_sos;
  String get sosTitle => _g.legacy_sosTitle;
  String get sosBody => _g.legacy_sosBody;
  String get sosCall => _g.legacy_sosCall;
  String get sosShare => _g.legacy_sosShare;
  String sosShareBody(String mapsUrl, String? driverName, String? plate) =>
      _g.legacy_sosShareBody(mapsUrl, driverName ?? '—', plate ?? '—');
  String shareTripLiveBody(String url) => _g.legacy_shareTripLiveBody(url);

  // ─── Profile photo (Phase 1.3) ───────────────────────────────────────────────
  String get profilePhoto => _g.legacy_profilePhoto;
  String get takePhoto => _g.legacy_takePhoto;
  String get fromGallery => _g.legacy_fromGallery;
  String get removePhoto => _g.legacy_removePhoto;
  String get photoUpdated => _g.legacy_photoUpdated;

  // ─── Profile completion (Phase 3.3) ──────────────────────────────────────────
  String get bio => _g.legacy_bio;
  String get bioHint => _g.legacy_bioHint;
  String get phone => _g.legacy_phone;
  String get phoneHint => _g.legacy_phoneHint;
  String get profileCompletion => _g.legacy_profileCompletion;
  String get verifyEmail => _g.legacy_verifyEmail;
  String get emailVerified => _g.legacy_emailVerified;
  String get verificationCodeSent => _g.legacy_verificationCodeSent;
  String get enterVerificationCode => _g.legacy_enterVerificationCode;
  String get verifyAction => _g.legacy_verifyAction;
  String get resendCode => _g.legacy_resendCode;
  String get profileUpdated => _g.legacy_profileUpdated;

  // ─── Accessibility tooltips (Phase 3.5) ──────────────────────────────────────
  String get back => _g.legacy_back;
  String get dismiss => _g.legacy_dismiss;
  String get clear => _g.legacy_clear;
  String get togglePasswordVisibility => _g.legacy_togglePasswordVisibility;
  String semOffer(String driverName) => _g.legacy_semOffer(driverName);
  String semAccepted(String driverName) => _g.legacy_semAccepted(driverName);
  String semInRide(String driverName) => _g.legacy_semInRide(driverName);

  // ─── Bug reporting (Section C) ───────────────────────────────────────────────
  String get reportABug => _g.legacy_reportABug;
  String get bugReportTitle => _g.legacy_bugReportTitle;
  String get bugReportDescription => _g.legacy_bugReportDescription;
  String get bugReportSubmit => _g.legacy_bugReportSubmit;
  String get bugReportThanks => _g.legacy_bugReportThanks;

  // ─── Onboarding gate (Section D) ─────────────────────────────────────────────
  String get showTutorialAgain => _g.legacy_showTutorialAgain;
  String get onboardTitle4 => _g.legacy_onboardTitle4;
  String get onboardSubtitle4 => _g.legacy_onboardSubtitle4;

  // ─── Forgot password (Section E) ─────────────────────────────────────────────
  String get forgotPassword => _g.legacy_forgotPassword;
  String get forgotPasswordHint => _g.legacy_forgotPasswordHint;
  String get resetCodeHint => _g.legacy_resetCodeHint;
  String get newPasswordHint => _g.legacy_newPasswordHint;
  String get resetSubmit => _g.legacy_resetSubmit;
  String get resetSuccess => _g.legacy_resetSuccess;
  String get resetCodeSent => _g.legacy_resetCodeSent;
  String get invalidCode => _g.legacy_invalidCode;

  // ─── Localized toasts (Section B3 hardcoded-English conversion) ──────────────
  String get rideRequestSent => _g.legacy_rideRequestSent;
  String get noCarInfo => _g.legacy_noCarInfo;
  String get passengerAcceptedRide => _g.legacy_passengerAcceptedRide;
  String passengerSentRequest(String name) => _g.legacy_passengerSentRequest(name);
  String savedCO2(String kg) => _g.legacy_savedCO2(kg);

  // ─── Role switch dialog (Section B3) ─────────────────────────────────────────
  String get endRouteAndSwitch => _g.legacy_endRouteAndSwitch;
  String get cancelRequestsAndSwitch => _g.legacy_cancelRequestsAndSwitch;
  String get endDriverRouteQ => _g.legacy_endDriverRouteQ;
  String get cancelPassengerSearchQ => _g.legacy_cancelPassengerSearchQ;
  String get stayAsDriver => _g.legacy_stayAsDriver;
  String get stayAsPassenger => _g.legacy_stayAsPassenger;

  // ─── Bottom navigation bars ──────────────────────────────────────────────────
  String get navRoute => _g.legacy_navRoute;
  String get navPlan => _g.legacy_navPlan;
  String get navFind => _g.legacy_navFind;
  String get navChat => _g.legacy_navChat;
  String get navFindTrips => _g.legacy_navFindTrips;
  String get navOffers => _g.legacy_navOffers;
  String get navReportBug => _g.legacy_navReportBug;
  String get navAccount => _g.legacy_navAccount;

  // ─── Driver: set-route validation ────────────────────────────────────────────
  String get errEnterDestination => _g.legacy_errEnterDestination;
  String get errAddressNotFound => _g.legacy_errAddressNotFound;

  // ─── Driver: bottom panel ────────────────────────────────────────────────────
  String get endRouteQ => _g.legacy_endRouteQ;
  String get endRouteBody => _g.legacy_endRouteBody;
  String get endRouteAction => _g.legacy_endRouteAction;
  String rideRequestsCount(String n) => _g.legacy_rideRequestsCount(n);
  String dropOffName(String name) => _g.legacy_dropOffName(name);
  String get cancelRide => _g.legacy_cancelRide;
  String get waitingForYourLocation => _g.legacy_waitingForYourLocation;
  String get waitingForPassengerLocation => _g.legacy_waitingForPassengerLocation;
  String kmBetweenYou(String km) => _g.legacy_kmBetweenYou(km);
  String routeSummary(String km, int count) => _g.legacy_routeSummary(km, count);
  String pendingOffersCount(int count) => _g.legacy_pendingOffersCount(count);
  /// Localized label for a ride_request status code from the backend.
  String rideStatusLabel(String status) => switch (status) {
        'pending' => _g.legacy_rideStatus_pending,
        'accepted' => _g.legacy_rideStatus_accepted,
        'in_progress' => _g.legacy_rideStatus_in_progress,
        'declined' => _g.legacy_rideStatus_declined,
        'done' => _g.legacy_rideStatus_done,
        'cancelled' => _g.legacy_rideStatus_cancelled,
        'offered' => _g.legacy_rideStatus_offered,
        _ => status,
      };

  // ─── Passenger: home screen ──────────────────────────────────────────────────
  String get whereDoYouWantToGo => _g.legacy_whereDoYouWantToGo;
  String get waitingForDriver => _g.legacy_waitingForDriver;
  String get driverAccepted => _g.legacy_driverAccepted;
  String walkPill(String m, String min) => _g.legacy_walkPill(m, min);
  String driverInMin(String min) => _g.legacy_driverInMin(min);
  String get mapStyleStandard => _g.legacy_mapStyleStandard;
  String get mapStyleSatellite => _g.legacy_mapStyleSatellite;
  String get mapStyleDark => _g.legacy_mapStyleDark;
  String seatsCorridorSummary(String seats, String km) => _g.legacy_seatsCorridorSummary(seats, km);
  String get carLabel => _g.legacy_carLabel;
  String get requestThisRide => _g.legacy_requestThisRide;

  // ─── Role switch: live-state reasons ─────────────────────────────────────────
  String get reasonActiveDriverRoute => _g.legacy_reasonActiveDriverRoute;
  String get reasonAcceptedPassengerRide => _g.legacy_reasonAcceptedPassengerRide;
  String get reasonAcceptedDriverRide => _g.legacy_reasonAcceptedDriverRide;
  String get reasonPendingRideRequests => _g.legacy_reasonPendingRideRequests;
  String get reasonActiveDestinationSearch => _g.legacy_reasonActiveDestinationSearch;
  String switchWillEnd(String reason) => _g.legacy_switchWillEnd(reason);

  // ─── Account: email verification ─────────────────────────────────────────────
  String get enterSixDigitCode => _g.legacy_enterSixDigitCode;
  String get errDriverUnavailable => _g.legacy_errDriverUnavailable;
  String get errTooFarFromRoute => _g.legacy_errTooFarFromRoute;
  String get errDriverPassedYou => _g.legacy_errDriverPassedYou;
  String get errDriverPositionStale => _g.legacy_errDriverPositionStale;
  String get errUpdateLocationFirst => _g.legacy_errUpdateLocationFirst;
  String get errOfferGone => _g.legacy_errOfferGone;
  String get errRideFull => _g.legacy_errRideFull;
  String get errWrongCode => _g.legacy_errWrongCode;
  String get errRideNotAccepted => _g.legacy_errRideNotAccepted;
  String get errInvalidCredentials => _g.legacy_errInvalidCredentials;
  String get errEmailTaken => _g.legacy_errEmailTaken;
  String get errCodeInvalidOrExpired => _g.legacy_errCodeInvalidOrExpired;
  String get errCurrentPasswordWrong => _g.legacy_errCurrentPasswordWrong;

  // ─── Background location (driver) ────────────────────────────────────────────
  String get backgroundLocationUnavailable => _g.legacy_backgroundLocationUnavailable;

  // ─── Legal: age + terms consent ──────────────────────────────────────────────
  String get ageConfirmLabel => _g.legacy_ageConfirmLabel;
  String get acceptTermsLabel => _g.legacy_acceptTermsLabel;
  String get termsOfService => _g.legacy_termsOfService;
  String get privacyPolicy => _g.legacy_privacyPolicy;
  String get consentRequiredError => _g.legacy_consentRequiredError;
  String get birthDateLabel => _g.legacy_birthDateLabel;
  String get birthDateRequired => _g.legacy_birthDateRequired;
  String get errUnderage => _g.legacy_errUnderage;
  String ageYears(int n) => _g.legacy_ageYears(n);
  String get driverDeclTitle => _g.legacy_driverDeclTitle;
  String get driverDeclBody => _g.legacy_driverDeclBody;
  String get driverDeclLicence => _g.legacy_driverDeclLicence;
  String get driverDeclInsurance => _g.legacy_driverDeclInsurance;
  String get driverDeclRoadworthy => _g.legacy_driverDeclRoadworthy;
  String get driverDeclCostSharing => _g.legacy_driverDeclCostSharing;
  String get driverDeclAllRequired => _g.legacy_driverDeclAllRequired;
  String get carDetailsRequired => _g.legacy_carDetailsRequired;
  String get outsideServiceArea => _g.legacy_outsideServiceArea;
  String get termsGateTitle => _g.legacy_termsGateTitle;
  String get termsGateBody => _g.legacy_termsGateBody;

  // ─── Legal: analytics consent ────────────────────────────────────────────────
  String get analyticsConsentTitle => _g.legacy_analyticsConsentTitle;
  String get analyticsConsentBody => _g.legacy_analyticsConsentBody;
  String get analyticsAllow => _g.legacy_analyticsAllow;
  String get analyticsDeny => _g.legacy_analyticsDeny;
  String get analyticsSettingTitle => _g.legacy_analyticsSettingTitle;
  String get analyticsSettingSubtitle => _g.legacy_analyticsSettingSubtitle;
  String get downloadMyData => _g.legacy_downloadMyData;
  String get legalAndPrivacy => _g.legacy_legalAndPrivacy;

  // ─── Pickup code recovery / no-show ──────────────────────────────────────────
  String wrongCodeAttemptsLeft(int n) => _g.legacy_wrongCodeAttemptsLeft(n);
  String get pickupLocked => _g.legacy_pickupLocked;
  String get pickupCodeResetNotice => _g.legacy_pickupCodeResetNotice;
  String get rideCancelledNoShow => _g.legacy_rideCancelledNoShow;
  String get rideCancelledTimeout => _g.legacy_rideCancelledTimeout;
  String get rideCancelledDriverEnded => _g.legacy_rideCancelledDriverEnded;
  String get newPickupCode => _g.legacy_newPickupCode;
  String get pickupLockedDriver => _g.legacy_pickupLockedDriver;
  String get passengerNoShow => _g.legacy_passengerNoShow;
  String get noShowConfirmBody => _g.legacy_noShowConfirmBody;
  String noShowTooEarly(int minutes) => _g.legacy_noShowTooEarly(minutes);
  String get noShowReported => _g.legacy_noShowReported;
  String get newCodeIssued => _g.legacy_newCodeIssued;
  String get accountSuspended => _g.legacy_accountSuspended;

  // ─── Account deletion ────────────────────────────────────────────────────────
  String get deleteAccount => _g.legacy_deleteAccount;
  String get deleteAccountTitle => _g.legacy_deleteAccountTitle;
  String get deleteAccountBody => _g.legacy_deleteAccountBody;
  String get deleteAccountPasswordLabel => _g.legacy_deleteAccountPasswordLabel;
  String get deleteAccountConfirm => _g.legacy_deleteAccountConfirm;
  String get accountDeleted => _g.legacy_accountDeleted;
  String get deleteAccountActiveRide => _g.legacy_deleteAccountActiveRide;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLanguageCodes.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
