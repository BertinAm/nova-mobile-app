import 'package:dartz/dartz.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/error/failures.dart';
import '../entities/obstacle_detection_result.dart';

abstract class ObstacleRepository {
  Stream<Either<Failure, List<DetectedObstacle>>> detectObstacles(
    Stream<CameraFrame> cameraStream,
  );
}
