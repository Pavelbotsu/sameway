import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/api_client.dart';
import 'core/app_theme.dart';
import 'core/token_storage.dart';
import 'core/websocket_client.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_repository.dart';
import 'features/driver/driver_provider.dart';
import 'features/driver/driver_repository.dart';
import 'features/onboarding/splash_screen.dart';
import 'features/passenger/passenger_provider.dart';
import 'features/passenger/passenger_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp(
      title: 'sameway',
      theme: buildAppTheme(),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
