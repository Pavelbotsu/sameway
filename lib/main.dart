import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/api_client.dart';
import 'core/app_localizations.dart';
import 'core/app_theme.dart';
import 'core/fcm_service.dart';
import 'core/language_provider.dart';
import 'core/map_style_provider.dart';
import 'core/token_storage.dart';
import 'core/websocket_client.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_repository.dart';
import 'features/driver/driver_provider.dart';
import 'features/driver/driver_repository.dart';
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

class SamewayApp extends StatelessWidget {
  const SamewayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LanguageProvider>().locale;
    return MaterialApp(
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
      ],
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
