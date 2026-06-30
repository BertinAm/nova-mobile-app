import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/sync/sync_service.dart';
import '../../../../core/tts/tts_service.dart';
import '../../../../core/voice/voice_command_service.dart';
import '../../../../injection_container.dart';

class HomeMenuPage extends StatefulWidget {
  const HomeMenuPage({super.key});

  @override
  State<HomeMenuPage> createState() => _HomeMenuPageState();
}

class _HomeMenuPageState extends State<HomeMenuPage> with WidgetsBindingObserver {
  StreamSubscription<VoiceCommand>? _voiceSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getIt<TtsService>().speak(
        'Main menu. Six options available: Obstacle Detection, Read Text, '
        'Describe Scene, Identify Money, Recognize Faces, and Settings. '
        'Tap any button or press the microphone and say a command.',
        priority: TtsPriority.normal,
      );
    });
    _voiceSubscription = getIt<VoiceCommandRouter>().commands.listen(_handleVoiceCommand);
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
    _voiceSubscription?.cancel();
    super.dispose();
  }

  void _handleVoiceCommand(VoiceCommand command) {
    switch (command) {
      case VoiceCommand.startObstacle:
      case VoiceCommand.stopObstacle:
        Navigator.pushNamed(context, '/obstacle');
        break;
      case VoiceCommand.readText:
        Navigator.pushNamed(context, '/ocr');
        break;
      case VoiceCommand.describeScene:
        Navigator.pushNamed(context, '/scene');
        break;
      case VoiceCommand.identifyMoney:
        Navigator.pushNamed(context, '/currency');
        break;
      case VoiceCommand.recogniseFace:
        Navigator.pushNamed(context, '/faces');
        break;
      case VoiceCommand.slowTts:
        getIt<TtsService>().setSpeechRate(0.7);
        break;
      case VoiceCommand.speedUpTts:
        getIt<TtsService>().setSpeechRate(1.4);
        break;
      case VoiceCommand.stopTts:
        getIt<TtsService>().stop();
        break;
      case VoiceCommand.emergency:
        getIt<TtsService>().speak(
          'Emergency feature placeholder. Connect geolocator and SMS manager here.',
          priority: TtsPriority.critical,
          interrupt: true,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    const items = [
      _MenuItem(
        title: 'Obstacle Detection',
        icon: Icons.warning_amber,
        route: '/obstacle',
        hint: 'Detects objects in your path and gives directional alerts',
      ),
      _MenuItem(
        title: 'Read Text',
        icon: Icons.document_scanner,
        route: '/ocr',
        hint: 'Reads printed or handwritten text aloud from the camera',
      ),
      _MenuItem(
        title: 'Describe Scene',
        icon: Icons.image_search,
        route: '/scene',
        hint: 'Describes what the camera sees in natural language. Requires internet.',
      ),
      _MenuItem(
        title: 'Identify Money',
        icon: Icons.payments,
        route: '/currency',
        hint: 'Identifies CFA franc banknotes',
      ),
      _MenuItem(
        title: 'Recognize Faces',
        icon: Icons.face,
        route: '/faces',
        hint: 'Recognizes and names enrolled contacts',
      ),
      _MenuItem(
        title: 'Settings',
        icon: Icons.settings,
        route: '/settings',
        hint: 'Adjust speech rate, language, and accessibility options',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('NOVA'),
        actions: [
          Semantics(
            button: true,
            label: 'Repeat menu description',
            child: IconButton(
              icon: const Icon(Icons.volume_up),
              tooltip: 'Repeat menu description',
              onPressed: () {
                getIt<TtsService>().speak(
                  'Main menu. Six options: Obstacle Detection, Read Text, '
                  'Describe Scene, Identify Money, Recognize Faces, and Settings.',
                  priority: TtsPriority.high,
                  interrupt: true,
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
            children: items.map((item) {
              return Semantics(
                button: true,
                label: item.title,
                hint: item.hint,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, item.route),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(18),
                    textStyle: Theme.of(context).textTheme.titleMedium,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, size: 46),
                      const SizedBox(height: 12),
                      Text(item.title, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
      floatingActionButton: Semantics(
        button: true,
        label: 'Start voice command',
        hint: 'Say a command like start obstacle detection or read text',
        child: FloatingActionButton.extended(
          onPressed: () {
            getIt<VoiceCommandService>().startListening();
            getIt<TtsService>().speak(
              'Listening. Say a command.',
              priority: TtsPriority.high,
            );
          },
          icon: const Icon(Icons.mic),
          label: const Text('Voice Command'),
        ),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final String route;
  final String hint;

  const _MenuItem({
    required this.title,
    required this.icon,
    required this.route,
    required this.hint,
  });
}
