import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/api_client.dart';
import 'core/app_localizations.dart';
import 'core/app_theme.dart';
import 'core/connectivity_provider.dart';
import 'core/fcm_service.dart';
import 'core/language_provider.dart';
import 'core/map_style_provider.dart';
import 'core/matching_preference_provider.dart';
import 'core/session.dart';
import 'core/token_storage.dart';
import 'core/websocket_client.dart';
import 'core/widgets/branded_snack_bar.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_repository.dart';
import 'features/driver/driver_provider.dart';
import 'features/driver/driver_repository.dart';
import 'features/onboarding/role_selection_screen.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/passenger/passenger_provider.dart';
import 'features/passenger/passenger_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FcmService.init();
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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => MapStyleProvider()),
        ChangeNotifierProvider(create: (_) => MatchingPreferenceProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(AuthRepository(api), storage),
        ),
        ChangeNotifierProvider(
          create: (_) => DriverProvider(
            DriverRepository(api),
            WebSocketClient(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) => PassengerProvider(
            PassengerRepository(api),
            WebSocketClient(),
          ),
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

  @override
  void initState() {
    super.initState();
    _expirySub = SessionEvents.instance.onExpired.listen(_handleExpired);
  }

  /// Clear stored credentials, route back to RoleSelectionScreen, show a
  /// branded SnackBar telling the user their session ended. Decoupled from
  /// any one widget so ApiClient can fire this from anywhere.
  Future<void> _handleExpired(void _) async {
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
      BrandedSnack.showError(
          ctx, AppLocalizations.of(ctx).errSessionExpired);
    }
  }

  @override
  void dispose() {
    _expirySub?.cancel();
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
      supportedLocales: const [
        Locale('en'),
        Locale('uk'),
        Locale('es'),
        Locale('de'),
        Locale('fr'),
        Locale('it'),
      ],
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
