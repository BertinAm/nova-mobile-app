import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // Force portrait — chest-mounted camera is always portrait for navigation.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await configureDependencies();
  getIt<SyncService>().startWatching();
  runApp(const NovaApp());
}

class NovaApp extends StatelessWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NOVA – Assistive Vision',
      debugShowCheckedModeBanner: false,

      // ─── Audio-first, high-contrast dark theme (SRS §5.1, NFR-32/37) ───────
      theme: _buildTheme(),

      // ─── System UI — dark status bar for maximum contrast ────────────────
      builder: (context, child) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
          ),
        );
        return MediaQuery(
          // Respect user-set system font scaling (NFR-37)
          data: MediaQuery.of(context),
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

/// NOVA design system:
/// • Deep navy blue seed — strong, trustworthy, visible in bright daylight.
/// • Dark mode everywhere — reduces eye strain; higher contrast.
/// • Typography scaled up — readable by low-vision users.
/// • No animation bloat — zero extra motion that could disorient a BVI user.
ThemeData _buildTheme() {
  const seedColour = Color(0xFF1A5276); // Deep navy

  final cs = ColorScheme.fromSeed(
    seedColor: seedColour,
    brightness: Brightness.dark,
    // Manually bump primary container & on-primary for high contrast
    primary: const Color(0xFF4FC3F7),         // Bright sky blue for active elements
    onPrimary: Colors.black,
    secondary: const Color(0xFFFFCC02),       // High-contrast amber for warnings
    onSecondary: Colors.black,
    error: const Color(0xFFFF5252),
    surface: const Color(0xFF0D1117),         // Near-black surface
    onSurface: const Color(0xFFF0F4F8),       // Very light text
    surfaceContainerHighest: const Color(0xFF1C2333),
  );

  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    scaffoldBackgroundColor: cs.surface,

    // ─── Text — large, high-weight, legible for low-vision ───────────────
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: -0.5),
      displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(fontSize: 18, height: 1.5),
      bodyMedium: TextStyle(fontSize: 16, height: 1.5),
      labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ).apply(
      bodyColor: cs.onSurface,
      displayColor: cs.onSurface,
    ),

    // ─── Buttons — tall, wide, impossible to miss ─────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(60),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    // ─── AppBar ───────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surfaceContainerHighest,
      foregroundColor: cs.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: cs.onSurface,
      ),
    ),

    // ─── Cards ───────────────────────────────────────────────────────────
    cardTheme: CardTheme(
      elevation: 1,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),

    // ─── Sliders — fat thumb, easy for trembling fingers ─────────────────
    sliderTheme: const SliderThemeData(
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 14),
      trackHeight: 6,
    ),

    // ─── Switch ──────────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? cs.primary : cs.outline,
      ),
    ),

    // ─── Divider ─────────────────────────────────────────────────────────
    dividerTheme: DividerThemeData(color: cs.outline.withOpacity(0.3), thickness: 1),
  );
}
