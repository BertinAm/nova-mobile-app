import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/face_entities.dart';
import '../../domain/repositories/face_repository.dart';
import '../datasources/face_recognition_datasource.dart';

class FaceRepositoryImpl implements FaceRepository {
  final FaceRecognitionDatasource datasource;

  FaceRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, List<EnrolledContact>>> contacts() async {
    try {
      return right(await datasource.contacts());
    } catch (e) {
      return left(CacheFailure('Could not load contacts: $e'));
    }
  }

  @override
  Future<Either<Failure, EnrolledContact>> enroll(String name, List<File?> photos) async {
    if (name.trim().isEmpty) {
      return left(const CacheFailure('Contact name is required.'));
    }
    try {
      return right(await datasource.enroll(name, photos));
    } catch (e) {
      return left(ModelFailure('Face enrolment failed: $e'));
    }
  }

  @override
  Future<Either<Failure, FaceRecognitionResult>> recognise(File? imageFile) async {
    try {
      return right(await datasource.recognise(imageFile));
    } catch (e) {
      return left(ModelFailure('Face recognition failed: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteContact(String id) async {
    try {
      await datasource.deleteContact(id);
      return right<Failure, void>(null);
    } catch (e) {
      return left(CacheFailure('Could not delete contact: $e'));
    }
  }
}
