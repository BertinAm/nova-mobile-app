import 'package:flutter/material.dart';

import 'core/sync/sync_service.dart';
import 'features/currency_detection/presentation/pages/currency_page.dart';
import 'features/face_recognition/presentation/pages/face_enrolment_page.dart';
import 'features/face_recognition/presentation/pages/face_recognition_page.dart';
import 'features/home/presentation/pages/home_menu_page.dart';
import 'features/ocr/presentation/pages/ocr_page.dart';
import 'features/onboarding/presentation/pages/onboarding_page.dart';
import 'features/obstacle_detection/presentation/pages/obstacle_page.dart';
import 'features/scene_description/presentation/pages/scene_page.dart';
import 'features/settings/presentation/pages/settings_page.dart';
import 'injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  getIt<SyncService>().startWatching();
  runApp(const NovaApp());
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOVA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1F4E79),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.1),
          ),
          child: child!,
        );
      },
      home: const OnboardingPage(),
      routes: {
        '/home': (_) => const HomeMenuPage(),
        '/obstacle': (_) => const ObstaclePage(),
        '/ocr': (_) => const OcrPage(),
        '/scene': (_) => const ScenePage(),
        '/currency': (_) => const CurrencyPage(),
        '/faces': (_) => const FaceRecognitionPage(),
        '/settings': (_) => const SettingsPage(),
        '/enrolment': (_) => const FaceEnrolmentPage(),
      },
    );
  }
}
