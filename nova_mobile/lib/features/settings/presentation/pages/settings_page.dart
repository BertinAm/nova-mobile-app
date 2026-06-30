import 'package:flutter/material.dart';

import '../../../../core/tts/tts_service.dart';
import '../../../../injection_container.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _rate = 1.0;
  String _language = 'en-CM';

  @override
  Widget build(BuildContext context) {
    final tts = getIt<TtsService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('TTS speech rate', style: Theme.of(context).textTheme.titleLarge),
            Slider(
              value: _rate,
              min: 0.5,
              max: 2.0,
              divisions: 6,
              label: '${_rate.toStringAsFixed(1)}x',
              onChanged: (value) async {
                setState(() => _rate = value);
                await tts.setSpeechRate(value);
              },
            ),
            const SizedBox(height: 24),
            Text('Language', style: Theme.of(context).textTheme.titleLarge),
            RadioListTile<String>(
              value: 'en-CM',
              groupValue: _language,
              title: const Text('English'),
              onChanged: (value) async {
                setState(() => _language = value!);
                await tts.setLanguage(value!);
                await tts.speak('English selected.', priority: TtsPriority.high);
              },
            ),
            RadioListTile<String>(
              value: 'fr-CM',
              groupValue: _language,
              title: const Text('French'),
              onChanged: (value) async {
                setState(() => _language = value!);
                await tts.setLanguage(value!);
                await tts.speak('Français sélectionné.', priority: TtsPriority.high);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => tts.speak('Settings saved.', priority: TtsPriority.normal),
              icon: const Icon(Icons.save),
              label: const Text('Confirm settings'),
            ),
          ],
        ),
      ),
    );
  }
}
