import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/camera/camera_service.dart';
import 'core/constants/app_constants.dart';
import 'core/settings/settings_service.dart';
import 'core/sync/sync_service.dart';
import 'core/tts/tts_service.dart';
import 'core/voice/voice_command_service.dart';
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

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await configureDependencies();

  // Pre-warm camera so the overlay is ready immediately
  if (!AppConstants.simulated) {
    try {
      await getIt<CameraService>().initialize();
    } catch (_) {}
  }

  getIt<SyncService>().startWatching();
  runApp(const NovaApp());
}

/// Global navigator key — used to route voice commands from anywhere.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Current-page stop callback — each feature page registers its own.
VoidCallback? globalStopCurrentOption;

class NovaApp extends StatefulWidget {
  const NovaApp({super.key});

  @override
  State<NovaApp> createState() => _NovaAppState();
}

class _NovaAppState extends State<NovaApp> {
  late final StreamSubscription<VoiceCommand> _voiceSub;

  @override
  void initState() {
    super.initState();
    _voiceSub = getIt<VoiceCommandRouter>().commands.listen(_handleVoiceCommand);

    // Keep the voice service listening continuously
    _startContinuousListening();
  }

  void _startContinuousListening() {
    final svc = getIt<VoiceCommandService>();
    final lang = getIt<SettingsService>().language.value;
    svc.startListening(localeId: lang.replaceAll('-', '_'));
  }

  @override
  void dispose() {
    _voiceSub.cancel();
    super.dispose();
  }

  void _handleVoiceCommand(VoiceCommand command) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    const routes = [
      '/obstacle', '/ocr', '/scene', '/currency', '/faces', '/settings'
    ];

    void jumpTo(String route, {bool autoStart = true}) {
      Navigator.pushNamedAndRemoveUntil(
        ctx, route, ModalRoute.withName('/home'),
        arguments: autoStart,
      );
      // Re-arm listener after navigation
      Future.delayed(const Duration(milliseconds: 800), _startContinuousListening);
    }

    switch (command) {
      case VoiceCommand.option1:  jumpTo(routes[0]); break;
      case VoiceCommand.option2:  jumpTo(routes[1]); break;
      case VoiceCommand.option3:  jumpTo(routes[2]); break;
      case VoiceCommand.option4:  jumpTo(routes[3]); break;
      case VoiceCommand.option5:  jumpTo(routes[4]); break;
      case VoiceCommand.option6:  jumpTo(routes[5], autoStart: false); break;

      case VoiceCommand.stopCurrentOption:
        if (globalStopCurrentOption != null) {
          globalStopCurrentOption!();
        } else {
          getIt<TtsService>().stop();
        }
        _startContinuousListening();
        break;

      case VoiceCommand.slowTts:
        getIt<TtsService>().setSpeechRate(0.7);
        getIt<TtsService>().speak('Speed slowed.', priority: TtsPriority.normal);
        _startContinuousListening();
        break;
      case VoiceCommand.speedUpTts:
        getIt<TtsService>().setSpeechRate(1.4);
        getIt<TtsService>().speak('Speed increased.', priority: TtsPriority.normal);
        _startContinuousListening();
        break;
      case VoiceCommand.stopTts:
        getIt<TtsService>().stop();
        _startContinuousListening();
        break;
      case VoiceCommand.emergency:
        getIt<TtsService>().speak(
          'Emergency! Calling for help. Please wait.',
          priority: TtsPriority.critical,
          interrupt: true,
        );
        _startContinuousListening();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'NOVA – Assistive Vision',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      builder: (context, child) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
          ),
        );
        return MediaQuery(
          data: MediaQuery.of(context),
          // ─── Wrap everything in a Stack so the floating camera overlay
          //     appears above ALL pages without being per-page ───────────
          child: Stack(
            children: [
              child!,
              const _FloatingCameraOverlay(),
            ],
          ),
        );
      },
      home: const OnboardingPage(),
      routes: {
        '/home':      (_) => const HomeMenuPage(),
        '/obstacle':  (_) => const ObstaclePage(),
        '/ocr':       (_) => const OcrPage(),
        '/scene':     (_) => const ScenePage(),
        '/currency':  (_) => const CurrencyPage(),
        '/faces':     (_) => const FaceRecognitionPage(),
        '/settings':  (_) => const SettingsPage(),
        '/enrolment': (_) => const FaceEnrolmentPage(),
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Floating draggable camera overlay — visible on every screen when enabled
// ════════════════════════════════════════════════════════════════════════════
class _FloatingCameraOverlay extends StatefulWidget {
  const _FloatingCameraOverlay();

  @override
  State<_FloatingCameraOverlay> createState() => _FloatingCameraOverlayState();
}

class _FloatingCameraOverlayState extends State<_FloatingCameraOverlay>
    with SingleTickerProviderStateMixin {
  // Position (bottom-right corner by default)
  double _right = 12;
  double _bottom = 100;
  bool _minimised = false;

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: getIt<SettingsService>().debugCameraPreview,
      builder: (_, showPreview, __) {
        if (!showPreview) return const SizedBox.shrink();

        final ctrl = getIt<CameraService>().controller;
        final hasRealCamera = ctrl != null && ctrl.value.isInitialized;

        return Positioned(
          right: _right,
          bottom: _bottom,
          child: GestureDetector(
            // Drag to reposition
            onPanUpdate: (details) => setState(() {
              _right  = (_right  - details.delta.dx).clamp(0.0, MediaQuery.of(context).size.width  - 130);
              _bottom = (_bottom - details.delta.dy).clamp(0.0, MediaQuery.of(context).size.height - 180);
            }),
            // Tap to minimise / maximise
            onTap: () => setState(() => _minimised = !_minimised),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              width: _minimised ? 48 : 130,
              height: _minimised ? 48 : 175,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(_minimised ? 24 : 14),
                border: Border.all(
                  color: const Color(0xFF4FC3F7).withValues(alpha: 0.7),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_minimised ? 22 : 12),
                child: _minimised
                    ? Center(
                        child: ScaleTransition(
                          scale: _pulseAnim,
                          child: const Icon(Icons.videocam_rounded,
                              color: Color(0xFF4FC3F7), size: 24),
                        ),
                      )
                    : hasRealCamera
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              // Actual live feed
                              _CameraPreviewWidget(ctrl: ctrl),
                              // Corner label
                              Positioned(
                                bottom: 4, left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Color(0xFF4FC3F7),
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                              // Drag hint icon
                              Positioned(
                                top: 4, right: 4,
                                child: Icon(Icons.open_with_rounded,
                                    size: 14, color: Colors.white38),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_off_rounded,
                                  color: Colors.white54, size: 28),
                              const SizedBox(height: 4),
                              const Text(
                                'No cam',
                                style: TextStyle(color: Colors.white54, fontSize: 10),
                              ),
                            ],
                          ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Camera preview widget that handles aspect ratio ─────────────────────────
class _CameraPreviewWidget extends StatelessWidget {
  const _CameraPreviewWidget({required this.ctrl});
  final dynamic ctrl; // CameraController

  @override
  Widget build(BuildContext context) {
    try {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: ctrl.value.previewSize?.height ?? 130,
          height: ctrl.value.previewSize?.width ?? 175,
          child: Builder(builder: (_) {
            // CameraPreview import is in obstacle_page.dart;
            // we import it here too via package:camera
            return _buildPreview(ctrl);
          }),
        ),
      );
    } catch (_) {
      return const Center(child: Icon(Icons.camera_alt, color: Colors.white38));
    }
  }

  Widget _buildPreview(dynamic ctrl) {
    // ignore: avoid_dynamic_calls
    return ctrl.buildPreview();
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  Theme
// ════════════════════════════════════════════════════════════════════════════
ThemeData _buildTheme() {
  const seedColour = Color(0xFF1A5276);

  final cs = ColorScheme.fromSeed(
    seedColor: seedColour,
    brightness: Brightness.dark,
    primary: const Color(0xFF4FC3F7),
    onPrimary: Colors.black,
    secondary: const Color(0xFFFFCC02),
    onSecondary: Colors.black,
    error: const Color(0xFFFF5252),
    surface: const Color(0xFF0D1117),
    onSurface: const Color(0xFFF0F4F8),
    surfaceContainerHighest: const Color(0xFF1C2333),
  );

  return ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    scaffoldBackgroundColor: cs.surface,
    textTheme: const TextTheme(
      displayLarge:  TextStyle(fontSize: 48, fontWeight: FontWeight.bold, letterSpacing: -0.5),
      displayMedium: TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
      headlineMedium:TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      titleLarge:    TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      titleMedium:   TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
      bodyLarge:     TextStyle(fontSize: 18, height: 1.5),
      bodyMedium:    TextStyle(fontSize: 16, height: 1.5),
      labelLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ).apply(bodyColor: cs.onSurface, displayColor: cs.onSurface),
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
    appBarTheme: AppBarTheme(
      backgroundColor: cs.surfaceContainerHighest,
      foregroundColor: cs.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface),
    ),
    cardTheme: CardTheme(
      elevation: 1,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    sliderTheme: const SliderThemeData(
      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 14),
      trackHeight: 6,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? cs.primary : cs.outline,
      ),
    ),
    dividerTheme: DividerThemeData(
      color: cs.outline.withValues(alpha: 0.3),
      thickness: 1,
    ),
  );
}
