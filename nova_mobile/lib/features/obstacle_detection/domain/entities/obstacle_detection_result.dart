import 'package:equatable/equatable.dart';

enum ObstacleZone { near, warning, clear }

enum ObstacleDirection { left, center, right }

class DetectedObstacle extends Equatable {
  final String label;
  final double confidence;
  final ObstacleZone zone;
  final ObstacleDirection direction;
  final double estimatedDistanceMeters;
  final String trackingId;

  const DetectedObstacle({
    required this.label,
    required this.confidence,
    required this.zone,
    required this.direction,
    required this.estimatedDistanceMeters,
    required this.trackingId,
  });

  String get spokenDirection => switch (direction) {
        ObstacleDirection.left => 'left',
        ObstacleDirection.center => 'center',
        ObstacleDirection.right => 'right',
      };

  String get zoneName => switch (zone) {
        ObstacleZone.near => 'near',
        ObstacleZone.warning => 'warning',
        ObstacleZone.clear => 'clear',
      };

  String get alertText {
    if (zone == ObstacleZone.near) return '$label $spokenDirection';
    if (zone == ObstacleZone.warning) return 'Warning, $label $spokenDirection';
    return '$label clear';
  }

  @override
  List<Object?> get props => [trackingId, label, confidence, zone, direction];
}
