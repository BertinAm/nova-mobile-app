import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';

abstract class SceneRepository {
  Future<Either<Failure, String>> describeScene(File? imageFile);
}
