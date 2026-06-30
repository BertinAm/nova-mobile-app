import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../core/tts/tts_service.dart';
import '../../../../core/voice/voice_command_service.dart';
import '../../../../injection_container.dart';
import '../../../../main.dart' show globalStopCurrentOption;

class HomeMenuPage extends StatefulWidget {
  const HomeMenuPage({super.key});

  @override
  State<HomeMenuPage> createState() => _HomeMenuPageState();
}

class _HomeMenuPageState extends State<HomeMenuPage> with WidgetsBindingObserver {
  bool _listening = false;

  // Menu items with 1-indexed number labels
  static const _items = [
    _MenuItem(number: 1, title: 'Obstacle Detection',
      icon: Icons.warning_amber_rounded, route: '/obstacle',
      hint: 'Option 1. Detects objects in your path and speaks directional alerts.'),
    _MenuItem(number: 2, title: 'Read Text',
      icon: Icons.document_scanner_rounded, route: '/ocr',
      hint: 'Option 2. Points camera at printed text and reads it aloud.'),
    _MenuItem(number: 3, title: 'Describe Scene',
      icon: Icons.image_search_rounded, route: '/scene',
      hint: 'Option 3. Describes what the camera sees. Requires internet.'),
    _MenuItem(number: 4, title: 'Identify Money',
      icon: Icons.payments_rounded, route: '/currency',
      hint: 'Option 4. Identifies CFA franc banknotes.'),
    _MenuItem(number: 5, title: 'Recognize Faces',
      icon: Icons.face_rounded, route: '/faces',
      hint: 'Option 5. Recognizes and names enrolled contacts.'),
    _MenuItem(number: 6, title: 'Settings',
      icon: Icons.settings_rounded, route: '/settings',
      hint: 'Option 6. Adjust speech rate, language, and accessibility options.'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    globalStopCurrentOption = null;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Ensure permissions are granted even if onboarding was skipped
      await [
        Permission.camera,
        Permission.microphone,
        Permission.location,
      ].request();

      if (!AppConstants.simulated) {
        try {
          await getIt<CameraService>().initialize();
        } catch (_) {}
      }

      getIt<TtsService>().speak(
        'Main menu. Six options: '
        'Option 1, Obstacle Detection. '
        'Option 2, Read Text. '
        'Option 3, Describe Scene. '
        'Option 4, Identify Money. '
        'Option 5, Recognize Faces. '
        'Option 6, Settings. '
        'Press the microphone and say "Option" followed by a number, '
        'or say "stop option" to stop any running feature.',
        priority: TtsPriority.normal,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      getIt<SyncService>().syncNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _repeatMenu() {
    getIt<TtsService>().speak(
      'Option 1, Obstacle Detection. '
      'Option 2, Read Text. '
      'Option 3, Describe Scene. '
      'Option 4, Identify Money. '
      'Option 5, Recognize Faces. '
      'Option 6, Settings.',
      priority: TtsPriority.high,
      interrupt: true,
    );
  }

  Future<void> _startVoice() async {
    setState(() => _listening = true);
    getIt<VoiceCommandService>().startListening();
    await getIt<TtsService>().speak(
      'Listening. Say Option 1 through 6, or "stop option".',
      priority: TtsPriority.high,
    );
    // Auto-stop indicator after 30 s
    Future.delayed(const Duration(seconds: 31), () {
      if (mounted) setState(() => _listening = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NOVA'),
        actions: [
          Semantics(
            button: true,
            label: 'Repeat menu',
            child: IconButton(
              icon: const Icon(Icons.volume_up_rounded),
              tooltip: 'Repeat menu',
              onPressed: _repeatMenu,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Live camera strip ────────────────────────────────────────────
            // _CameraStrip(),

            // ── Numbered menu grid ────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.05,
                  children: _items.map((item) {
                    return Semantics(
                      button: true,
                      label: 'Option ${item.number}: ${item.title}',
                      hint: item.hint,
                      child: _MenuCard(
                        item: item,
                        cs: cs,
                        tt: tt,
                        onTap: () =>
                            Navigator.pushNamed(context, item.route, arguments: true),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Big mic FAB ──────────────────────────────────────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Semantics(
        button: true,
        label: _listening ? 'Listening for voice command' : 'Start voice command',
        hint: 'Say Option 1 through 6, or stop option',
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: _listening
                ? [BoxShadow(color: cs.primary.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 4)]
                : [],
          ),
          child: FloatingActionButton.large(
            backgroundColor: _listening ? cs.primary : cs.primaryContainer,
            foregroundColor: _listening ? cs.onPrimary : cs.onPrimaryContainer,
            onPressed: _listening
                ? () {
                    getIt<VoiceCommandService>().stopListening();
                    setState(() => _listening = false);
                  }
                : _startVoice,
            child: Icon(_listening ? Icons.mic_off_rounded : Icons.mic_rounded, size: 36),
          ),
        ),
      ),
    );
  }
}

// ─── Animated menu card ────────────────────────────────────────────────────────
class _MenuCard extends StatefulWidget {
  const _MenuCard({required this.item, required this.cs, required this.tt, required this.onTap});
  final _MenuItem item;
  final ColorScheme cs;
  final TextTheme tt;
  final VoidCallback onTap;

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _ac, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = widget.cs;
    return GestureDetector(
      onTapDown: (_) => _ac.forward(),
      onTapUp: (_) {
        _ac.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ac.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.primary.withValues(alpha: 0.25), width: 1.5),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Number badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.item.number}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Icon(widget.item.icon, size: 38, color: cs.primary),
              const SizedBox(height: 8),
              Text(
                widget.item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: widget.tt.labelLarge?.copyWith(color: cs.onSurface),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Live camera strip ─────────────────────────────────────────────────────────
class _CameraStrip extends StatefulWidget {
  @override
  State<_CameraStrip> createState() => _CameraStripState();
}

class _CameraStripState extends State<_CameraStrip> {
  CameraController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final svc = getIt<CameraService>();
      await svc.initialize();
      if (mounted) {
        setState(() {
          _ctrl = svc.controller;
          _ready = _ctrl?.value.isInitialized ?? false;
        });
      }
    } catch (_) {
      // camera not available in tests / emulators — hide strip silently
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _ctrl == null) return const SizedBox.shrink();
    return Semantics(
      label: 'Live camera view',
      excludeSemantics: true, // Don't let TalkBack read pixels
      child: Container(
        height: 160,
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CameraPreview(_ctrl!),
              // Subtle label so sighted helpers know what they see
              Positioned(
                bottom: 6, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Live Camera',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Data class ────────────────────────────────────────────────────────────────
class _MenuItem {
  final int number;
  final String title;
  final IconData icon;
  final String route;
  final String hint;

  const _MenuItem({
    required this.number,
    required this.title,
    required this.icon,
    required this.route,
    required this.hint,
  });
}
