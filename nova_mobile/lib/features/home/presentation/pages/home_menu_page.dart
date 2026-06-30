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
    getIt<TtsService>().speak('Main menu.', priority: TtsPriority.normal);
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
    final items = [
      _MenuItem('Obstacle Detection', Icons.warning_amber, '/obstacle'),
      _MenuItem('Read Text', Icons.document_scanner, '/ocr'),
      _MenuItem('Describe Scene', Icons.image_search, '/scene'),
      _MenuItem('Identify Money', Icons.payments, '/currency'),
      _MenuItem('Recognize Faces', Icons.face, '/faces'),
      _MenuItem('Settings', Icons.settings, '/settings'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('NOVA Main Menu')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: items.map((item) {
              return Semantics(
                button: true,
                label: item.title,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamed(context, item.route),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(18),
                    textStyle: Theme.of(context).textTheme.titleMedium,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, size: 42),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          getIt<VoiceCommandService>().startListening();
          getIt<TtsService>().speak('Listening for voice command.', priority: TtsPriority.high);
        },
        icon: const Icon(Icons.mic),
        label: const Text('Voice'),
      ),
    );
  }
}

class _MenuItem {
  final String title;
  final IconData icon;
  final String route;
  const _MenuItem(this.title, this.icon, this.route);
}
