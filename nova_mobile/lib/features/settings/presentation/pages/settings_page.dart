import 'package:flutter/material.dart';

import '../../../../core/settings/settings_service.dart';
import '../../../../core/tts/tts_service.dart';
import '../../../../injection_container.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SettingsService _settings;
  late final TtsService _tts;

  // Local mirrors of notifier values for the setState pattern
  late double _rate;
  late String _language;
  late bool _debugCamera;
  late bool _highContrast;

  @override
  void initState() {
    super.initState();
    _settings = getIt<SettingsService>();
    _tts = getIt<TtsService>();
    _rate = _settings.speechRate.value;
    _language = _settings.language.value;
    _debugCamera = _settings.debugCameraPreview.value;
    _highContrast = _settings.highContrastMode.value;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tts.speak('Settings page. Swipe to explore options.', priority: TtsPriority.normal);
    });
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  String get _rateLabel {
    if (_rate <= 0.6) return 'Very slow';
    if (_rate <= 0.85) return 'Slow';
    if (_rate <= 1.15) return 'Normal';
    if (_rate <= 1.4) return 'Fast';
    return 'Very fast';
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          Semantics(
            button: true,
            label: 'Read settings aloud',
            child: IconButton(
              icon: const Icon(Icons.record_voice_over),
              tooltip: 'Read settings aloud',
              onPressed: _readSettingsAloud,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ─── TTS Speed ──────────────────────────────────────────────────
            const _SectionHeader('Voice Speed'),
            Semantics(
              label: 'Speech rate slider',
              value: _rateLabel,
              hint: 'Swipe left or right to adjust',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ExcludeSemantics(child: Text('Slower', style: Theme.of(context).textTheme.bodySmall)),
                        Text(
                          _rateLabel,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        ExcludeSemantics(child: Text('Faster', style: Theme.of(context).textTheme.bodySmall)),
                      ],
                    ),
                  ),
                  Slider(
                    value: _rate,
                    min: 0.5,
                    max: 2.0,
                    divisions: 6,
                    label: _rateLabel,
                    semanticFormatterCallback: (_) => _rateLabel,
                    onChanged: (value) => setState(() => _rate = value),
                    onChangeEnd: (value) async {
                      await _settings.setSpeechRate(value);
                      await _tts.setSpeechRate(value);
                      await _tts.speak('Speed set to $_rateLabel.', priority: TtsPriority.high);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ─── TTS Quick Preset Buttons ────────────────────────────────────
            Semantics(
              label: 'Speech rate presets',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RatePresetButton(label: 'Slow', rate: 0.7, currentRate: _rate, onTap: _setRate),
                    _RatePresetButton(label: 'Normal', rate: 1.0, currentRate: _rate, onTap: _setRate),
                    _RatePresetButton(label: 'Fast', rate: 1.4, currentRate: _rate, onTap: _setRate),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
            const Divider(),

            // ─── Language ───────────────────────────────────────────────────
            const _SectionHeader('Language'),
            _LanguageOption(
              code: 'en-CM',
              displayName: 'English',
              selectedCode: _language,
              onSelect: (code) => _setLanguage(code, 'English selected.'),
            ),
            _LanguageOption(
              code: 'fr-CM',
              displayName: 'Français',
              selectedCode: _language,
              onSelect: (code) => _setLanguage(code, 'Français sélectionné.'),
            ),

            const SizedBox(height: 8),
            const Divider(),

            // ─── Accessibility ──────────────────────────────────────────────
            const _SectionHeader('Accessibility'),
            Semantics(
              label: 'High contrast mode',
              value: _highContrast ? 'enabled' : 'disabled',
              hint: 'Double tap to toggle',
              toggled: _highContrast,
              child: SwitchListTile(
                title: const Text('High Contrast Mode'),
                subtitle: const Text('Increases colour contrast for low-vision users'),
                secondary: const Icon(Icons.contrast),
                value: _highContrast,
                onChanged: (val) async {
                  setState(() => _highContrast = val);
                  await _settings.setHighContrastMode(val);
                  await _tts.speak(
                    'High contrast mode ${val ? 'enabled' : 'disabled'}.',
                    priority: TtsPriority.normal,
                  );
                },
              ),
            ),

            const SizedBox(height: 8),
            const Divider(),

            // ─── Developer / Debug ──────────────────────────────────────────
            const _SectionHeader('Developer'),
            Semantics(
              label: 'Debug camera preview',
              value: _debugCamera ? 'enabled' : 'disabled',
              hint: 'Double tap to toggle. When enabled, live camera feed is shown in Obstacle Detection.',
              toggled: _debugCamera,
              child: SwitchListTile(
                title: const Text('Camera Preview (Debug)'),
                subtitle: const Text('Shows live camera feed in Obstacle Detection for verification'),
                secondary: const Icon(Icons.videocam_outlined),
                value: _debugCamera,
                onChanged: (val) async {
                  setState(() => _debugCamera = val);
                  await _settings.setDebugCameraPreview(val);
                  await _tts.speak(
                    'Camera preview ${val ? 'enabled' : 'disabled'}.',
                    priority: TtsPriority.normal,
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // ─── Confirm ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                button: true,
                label: 'Confirm and save settings',
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => _tts.speak('Settings saved.', priority: TtsPriority.normal),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Confirm Settings'),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────────────────────
  Future<void> _setRate(double rate) async {
    setState(() => _rate = rate);
    await _settings.setSpeechRate(rate);
    await _tts.setSpeechRate(rate);
    await _tts.speak('Speed set to $_rateLabel.', priority: TtsPriority.high);
  }

  Future<void> _setLanguage(String code, String announcement) async {
    setState(() => _language = code);
    await _settings.setLanguage(code);
    await _tts.setLanguage(code);
    await _tts.speak(announcement, priority: TtsPriority.high);
  }

  void _readSettingsAloud() {
    final langName = _language == 'fr-CM' ? 'Français' : 'English';
    _tts.speak(
      'Current settings: Speed $_rateLabel. Language $langName. '
      'High contrast ${_highContrast ? "on" : "off"}. '
      'Camera preview ${_debugCamera ? "on" : "off"}.',
      priority: TtsPriority.high,
      interrupt: true,
    );
  }
}

// ─── Reusable sub-widgets ────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 0.8,
              ),
        ),
      ),
    );
  }
}

class _RatePresetButton extends StatelessWidget {
  const _RatePresetButton({
    required this.label,
    required this.rate,
    required this.currentRate,
    required this.onTap,
  });

  final String label;
  final double rate;
  final double currentRate;
  final Future<void> Function(double) onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = (currentRate - rate).abs() < 0.05;
    return Semantics(
      button: true,
      label: 'Set speech rate to $label',
      selected: isSelected,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
        ),
        onPressed: () => onTap(rate),
        child: Text(label),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.code,
    required this.displayName,
    required this.selectedCode,
    required this.onSelect,
  });

  final String code;
  final String displayName;
  final String selectedCode;
  final Future<void> Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedCode == code;
    return Semantics(
      label: 'Language option $displayName',
      selected: isSelected,
      hint: isSelected ? 'Currently selected' : 'Double tap to select',
      child: RadioListTile<String>(
        value: code,
        groupValue: selectedCode,
        title: Text(displayName),
        secondary: isSelected ? const Icon(Icons.check_circle) : null,
        onChanged: (value) => onSelect(value!),
      ),
    );
  }
}
