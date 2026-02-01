import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/theme.dart';
import 'models/game_state.dart';
import 'screens/main_menu_screen.dart';
import 'services/storage_service.dart';
import 'services/audio_service.dart';
import 'services/vibration_service.dart';
import 'services/ad_service.dart';
import 'services/iap_service.dart';
import 'services/offline_queue_service.dart';
import 'services/auth_service.dart';
import 'services/settings_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize services
  await StorageService.instance.init();
  await SettingsService.instance.init();
  await AudioService.instance.init();
  await VibrationService.instance.init();
  await AdService.instance.init();
  await IAPService.instance.init();
  await OfflineQueueService.instance.init();
  await AuthService.instance.init(); // Anonymous sign-in

  // Lock to portrait mode
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const NumberDropApp());
}

class NumberDropApp extends StatelessWidget {
  const NumberDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameState(),
      child: MaterialApp(
        title: 'Number Drop',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainMenuScreen(),
      ),
    );
  }
}
