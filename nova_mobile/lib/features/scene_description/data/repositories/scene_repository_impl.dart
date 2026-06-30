import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/repositories/scene_repository.dart';
import '../datasources/scene_remote_datasource.dart';

class SceneRepositoryImpl implements SceneRepository {
  final SceneRemoteDatasource datasource;

  SceneRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, String>> describeScene(File? imageFile) async {
    try {
      return right(await datasource.describeScene(imageFile));
    } catch (e) {
      return left(ServerFailure('Scene description failed: $e'));
    }
  }
}
