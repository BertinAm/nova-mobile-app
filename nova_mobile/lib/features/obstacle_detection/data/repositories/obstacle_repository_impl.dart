import 'package:dartz/dartz.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/obstacle_detection_result.dart';
import '../../domain/repositories/obstacle_repository.dart';
import '../datasources/tflite_obstacle_datasource.dart';

class ObstacleRepositoryImpl implements ObstacleRepository {
  final TfliteObstacleDatasource datasource;

  ObstacleRepositoryImpl(this.datasource);

  @override
  Stream<Either<Failure, List<DetectedObstacle>>> detectObstacles(
    Stream<CameraFrame> cameraStream,
  ) {
    // asyncMap serializes inference calls to avoid overlapping TFLite executions.
    return cameraStream.asyncMap((frame) async {
      try {
        final obstacles = await datasource.detect(frame);
        return right<Failure, List<DetectedObstacle>>(obstacles);
      } catch (e) {
        return left<Failure, List<DetectedObstacle>>(
          ModelFailure('Obstacle detection failed: $e'),
        );
      }
    });
  }
}
