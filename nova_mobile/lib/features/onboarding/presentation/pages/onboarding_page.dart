import 'package:flutter/material.dart';

import '../../../../injection_container.dart';
import '../../../../core/tts/tts_service.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      getIt<TtsService>().speak(
        'Welcome to NOVA. Use the menu or voice commands to start obstacle detection, read text, describe a scene, identify money, or recognize faces.',
        priority: TtsPriority.high,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'NOVA',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayLarge,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Navigational Object and Voice Assistant',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 48),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                icon: const Icon(Icons.home),
                label: const Text('Go to main menu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
