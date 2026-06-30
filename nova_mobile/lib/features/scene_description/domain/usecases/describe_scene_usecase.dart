import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/scene_repository.dart';

class DescribeSceneUseCase {
  final SceneRepository repository;

  DescribeSceneUseCase(this.repository);

  Future<Either<Failure, String>> call(File? imageFile) {
    return repository.describeScene(imageFile);
  }
}
