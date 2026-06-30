import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/face_entities.dart';

abstract class FaceRepository {
  Future<Either<Failure, List<EnrolledContact>>> contacts();
  Future<Either<Failure, EnrolledContact>> enroll(String name, List<File?> photos);
  Future<Either<Failure, FaceRecognitionResult>> recognise(File? imageFile);
  Future<Either<Failure, void>> deleteContact(String id);
}
