import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/tts/tts_service.dart';
import '../../../../injection_container.dart';
import '../../../../core/camera/camera_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getIt<TtsService>().speak(
        'Welcome to NOVA, the Navigational Object and Voice Assistant. '
        'NOVA helps you navigate your environment, read text, identify money, '
        'recognise faces, and describe scenes. '
        'Press the button at the bottom of the screen to enter the main menu.',
        priority: TtsPriority.high,
      );
    });
  }

  Future<void> _requestPermissionsAndGo() async {
    setState(() => _requesting = true);
    
    // Request Camera, Microphone, and Location permissions
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
    ].request();
    
    // Re-initialize camera now that we have permissions
    if (!AppConstants.simulated) {
      try {
        await getIt<CameraService>().initialize();
      } catch (_) {}
    }
    
    if (mounted) {
      setState(() => _requesting = false);
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Logo / Title area ───────────────────────────────────────────
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Semantics(
                      header: true,
                      label: 'NOVA – Navigational Object and Voice Assistant',
                      child: Column(
                        children: [
                          Icon(
                            Icons.accessibility_new,
                            size: 80,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'NOVA',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .displayLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ExcludeSemantics(
                      child: Text(
                        'Navigational Object and Voice Assistant',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Feature chips ─────────────────────────────────────────
                    const ExcludeSemantics(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _FeatureChip(Icons.warning_amber_outlined, 'Obstacle Detection'),
                          _FeatureChip(Icons.document_scanner_outlined, 'Read Text'),
                          _FeatureChip(Icons.image_search_outlined, 'Scene Description'),
                          _FeatureChip(Icons.payments_outlined, 'Currency'),
                          _FeatureChip(Icons.face_outlined, 'Faces'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ─── Replay welcome button ───────────────────────────────────────
              Semantics(
                button: true,
                label: 'Replay welcome message',
                child: OutlinedButton.icon(
                  onPressed: () => getIt<TtsService>().speak(
                    'Welcome to NOVA. Press the button below to enter the main menu.',
                    priority: TtsPriority.high,
                    interrupt: true,
                  ),
                  icon: const Icon(Icons.volume_up),
                  label: const Text('Replay welcome'),
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                ),
              ),

              const SizedBox(height: 12),

              // ─── CTA ─────────────────────────────────────────────────────────
              Semantics(
                button: true,
                label: 'Enter main menu',
                hint: 'Requests permissions and opens the main menu with all features',
                child: ElevatedButton.icon(
                  onPressed: _requesting ? null : _requestPermissionsAndGo,
                  icon: _requesting 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.home),
                  label: Text(_requesting ? 'Requesting Permissions…' : 'Go to main menu'),
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
