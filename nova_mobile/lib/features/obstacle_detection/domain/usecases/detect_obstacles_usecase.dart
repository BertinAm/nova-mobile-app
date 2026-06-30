import 'package:dartz/dartz.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/error/failures.dart';
import '../entities/obstacle_detection_result.dart';
import '../repositories/obstacle_repository.dart';

class DetectObstaclesUseCase {
  final ObstacleRepository repository;

  DetectObstaclesUseCase(this.repository);

  Stream<Either<Failure, List<DetectedObstacle>>> call(
    Stream<CameraFrame> cameraStream,
  ) {
    return repository.detectObstacles(cameraStream);
  }
}
