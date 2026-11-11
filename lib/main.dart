import 'dart:async';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart' show BuiltInMapCachingProvider;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/api_client.dart';
import 'core/app_localizations.dart';
import 'core/app_theme.dart';
import 'core/connectivity_provider.dart';
import 'core/consent_service.dart';
import 'core/fcm_service.dart';
import 'core/language_provider.dart';
import 'core/location_service.dart';
import 'core/map_style_provider.dart';
import 'core/matching_preference_provider.dart';
import 'core/remote_config_service.dart';
import 'core/session.dart';
import 'core/token_storage.dart';
import 'core/websocket_client.dart';
import 'core/widgets/misconfigured_build_app.dart';
import 'core/widgets/branded_snack_bar.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_repository.dart';
import 'features/driver/driver_provider.dart';
import 'features/driver/driver_repository.dart';
import 'features/legal/terms_gate_screen.dart';
import 'features/onboarding/role_selection_screen.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/passenger/passenger_provider.dart';
import 'features/passenger/passenger_repository.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // A store build aimed at a test backend must not run at all — before
  // Firebase or anything else touches the network.
  final buildProblem = storeBuildProblem();
  if (buildProblem != null) {
    runApp(MisconfiguredBuildApp(problem: buildProblem));
    return;
  }
  await Firebase.initializeApp();
  // Analytics / Crashlytics / Performance only with the user's consent. The
  // manifest keeps them off until this runs; undecided counts as "no", and
  // SplashScreen asks on first launch.
  await ConsentService.apply();
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
  // Remote Config: settings + defaults + best-effort fetch. Never throws —
  // offline startup proceeds on the in-code defaults.
  await RemoteConfigService().init();
  await FcmService.init();
  // Must run before the first TileLayer: flutter_map's cache is a singleton and
  // ignores config passed after it exists. 200 MB (~10k tiles) is plenty for a
  // commuter's area; the 14-day freshness stops re-validating tiles on every
  // launch (OSM's own minimum is 7 days), so repeat trips cost no mobile data.
  BuiltInMapCachingProvider.getOrCreateInstance(
    maxCacheSize: 200 * 1000 * 1000,
    overrideFreshAge: const Duration(days: 14),
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF10101C),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final storage = TokenStorage();
  final api = ApiClient(storage);

  // ONE WebSocketClient, shared by both role providers.
  //
  // They used to get an instance each. The server allows exactly one live
  // connection per user and evicts the previous one on connect, so after a role
  // switch the two clients fought over that single slot forever: passenger
  // connects → server closes driver's socket → driver's client sees onDone and
  // reconnects → server closes passenger's socket → … Neither provider is ever
  // disposed (they are root-scoped), so nothing broke the loop, and the user
  // sat on "Reconnecting…" with every WS event lost.
  final ws = WebSocketClient();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => MapStyleProvider()),
        ChangeNotifierProvider(create: (_) => MatchingPreferenceProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthRepository(api), storage, ws: ws),
        ),
        ChangeNotifierProvider(
          create: (_) => DriverProvider(DriverRepository(api), ws),
        ),
        ChangeNotifierProvider(
          create: (_) => PassengerProvider(PassengerRepository(api), ws),
        ),
      ],
      child: const SamewayApp(),
    ),
  );
}

class SamewayApp extends StatefulWidget {
  const SamewayApp({super.key});

  @override
  State<SamewayApp> createState() => _SamewayAppState();
}

class _SamewayAppState extends State<SamewayApp> {
  /// Root navigator key so the session-expiry handler (which doesn't have a
  /// BuildContext) can pop everything and route to RoleSelectionScreen.
  final _navKey = GlobalKey<NavigatorState>();
  StreamSubscription<void>? _expirySub;
  StreamSubscription<void>? _consentSub;
  StreamSubscription<void>? _suspendedSub;

  @override
  void initState() {
    super.initState();
    final events = SessionEvents.instance;
    _expirySub = events.onExpired.listen(
        (_) => _signOut((l) => l.errSessionExpired));
    _suspendedSub = events.onSuspended.listen(
        (_) => _signOut((l) => l.accountSuspended));
    _consentSub = events.onConsentRequired.listen(_handleConsentRequired);
  }

  /// Clear stored credentials, route back to RoleSelectionScreen and tell the
  /// user why. Decoupled from any one widget so ApiClient can fire it from
  /// anywhere.
  Future<void> _signOut(String Function(AppLocalizations) message) async {
    await LocationService.stop();
    await TokenStorage().clear();
    if (!mounted) return;
    final nav = _navKey.currentState;
    if (nav == null) return;
    nav.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
      (_) => false,
    );
    final ctx = _navKey.currentContext;
    if (ctx != null && ctx.mounted) {
      BrandedSnack.showError(ctx, message(AppLocalizations.of(ctx)));
    }
  }

  /// The server now refuses ride/chat calls until the current Terms are
  /// accepted (a terms version bump, or an account the local check thought
  /// had already accepted). Show the gate in place of whatever is open.
  Future<void> _handleConsentRequired(void _) async {
    final role = await TokenStorage().getRole();
    if (!mounted || role == null) return;
    _navKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => TermsGateScreen(role: role)),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _expirySub?.cancel();
    _consentSub?.cancel();
    _suspendedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LanguageProvider>().locale;
    return MaterialApp(
      navigatorKey: _navKey,
      scaffoldMessengerKey: FcmService.scaffoldMessengerKey,
      title: 'sameway',
      theme: buildAppTheme(),
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        for (final code in AppLocalizations.supportedLanguageCodes) Locale(code),
      ],
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
