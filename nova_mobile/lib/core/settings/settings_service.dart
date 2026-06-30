import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global settings service backed by SharedPreferences.
/// Uses ValueNotifiers so widgets can reactively rebuild on change.
class SettingsService {
  final SharedPreferences _prefs;

  SettingsService(this._prefs) {
    // Initialise notifiers from persisted values.
    _speechRate = ValueNotifier(_prefs.getDouble(_kSpeechRate) ?? 0.75);
    _language = ValueNotifier(_prefs.getString(_kLanguage) ?? 'en-CM');
    _debugCameraPreview = ValueNotifier(_prefs.getBool(_kDebugCamera) ?? false);
    _highContrastMode = ValueNotifier(_prefs.getBool(_kHighContrast) ?? false);
  }

  // Preference keys
  static const _kSpeechRate = 'speech_rate';
  static const _kLanguage = 'language';
  static const _kDebugCamera = 'debug_camera_preview';
  static const _kHighContrast = 'high_contrast_mode';

  // ─── Notifiers ──────────────────────────────────────────────────────────────
  late final ValueNotifier<double> _speechRate;
  late final ValueNotifier<String> _language;
  late final ValueNotifier<bool> _debugCameraPreview;
  late final ValueNotifier<bool> _highContrastMode;

  ValueNotifier<double> get speechRate => _speechRate;
  ValueNotifier<String> get language => _language;
  ValueNotifier<bool> get debugCameraPreview => _debugCameraPreview;
  ValueNotifier<bool> get highContrastMode => _highContrastMode;

  // ─── Setters (also persist) ───────────────────────────────────────────────
  Future<void> setSpeechRate(double value) async {
    _speechRate.value = value.clamp(0.5, 2.0);
    await _prefs.setDouble(_kSpeechRate, _speechRate.value);
  }

  Future<void> setLanguage(String code) async {
    _language.value = code;
    await _prefs.setString(_kLanguage, code);
  }

  Future<void> setDebugCameraPreview(bool enabled) async {
    _debugCameraPreview.value = enabled;
    await _prefs.setBool(_kDebugCamera, enabled);
  }

  Future<void> setHighContrastMode(bool enabled) async {
    _highContrastMode.value = enabled;
    await _prefs.setBool(_kHighContrast, enabled);
  }

  void dispose() {
    _speechRate.dispose();
    _language.dispose();
    _debugCameraPreview.dispose();
    _highContrastMode.dispose();
  }
}
