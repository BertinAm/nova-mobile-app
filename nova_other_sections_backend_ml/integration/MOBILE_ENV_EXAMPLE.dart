// Example use in Flutter:
// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1

class NovaEnv {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.nova-assistive.cm/api/v1',
  );
}
