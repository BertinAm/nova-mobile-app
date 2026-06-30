import 'package:flutter_test/flutter_test.dart';
import 'package:nova_assistive/features/obstacle_detection/domain/entities/obstacle_detection_result.dart';
import 'package:nova_assistive/features/obstacle_detection/domain/services/alert_suppression_policy.dart';

void main() {
  test('suppresses repeat alert for same obstacle within 2 seconds', () {
    final policy = AlertSuppressionPolicy(suppressionPeriod: const Duration(seconds: 2));
    final now = DateTime(2026, 1, 1, 12);
    const obstacle = DetectedObstacle(
      label: 'person',
      confidence: 0.9,
      zone: ObstacleZone.near,
      direction: ObstacleDirection.center,
      estimatedDistanceMeters: 1.2,
      trackingId: 'person-center',
    );

    expect(policy.shouldAlert(obstacle, now), isTrue);
    expect(policy.shouldAlert(obstacle, now.add(const Duration(milliseconds: 800))), isFalse);
    expect(policy.shouldAlert(obstacle, now.add(const Duration(seconds: 3))), isTrue);
  });
}
