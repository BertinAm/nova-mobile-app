import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final Connectivity _connectivity;

  ConnectivityService({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  Stream<bool> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged.map(_hasConnection);

  Future<bool> get isConnected async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _hasConnection(results);
    } catch (e) {
      debugPrint('Connectivity check failed, assuming offline: $e');
      return false;
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
