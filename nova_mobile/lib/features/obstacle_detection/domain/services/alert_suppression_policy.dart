import '../entities/obstacle_detection_result.dart';

/// Keeps the alert suppression rule testable outside the BLoC.
class AlertSuppressionPolicy {
  final Duration suppressionPeriod;
  final Map<String, DateTime> _lastAlertTime = {};

  AlertSuppressionPolicy({required this.suppressionPeriod});

  bool shouldAlert(DetectedObstacle obstacle, DateTime now) {
    if (obstacle.zone == ObstacleZone.clear) return false;
    final lastAlert = _lastAlertTime[obstacle.trackingId];
    if (lastAlert != null && now.difference(lastAlert) < suppressionPeriod) {
      return false;
    }
    _lastAlertTime[obstacle.trackingId] = now;
    return true;
  }

  void clear() => _lastAlertTime.clear();
}
