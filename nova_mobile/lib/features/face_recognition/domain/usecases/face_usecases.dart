import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/face_entities.dart';
import '../repositories/face_repository.dart';

class GetContactsUseCase {
  final FaceRepository repository;
  GetContactsUseCase(this.repository);
  Future<Either<Failure, List<EnrolledContact>>> call() => repository.contacts();
}

class EnrollFaceUseCase {
  final FaceRepository repository;
  EnrollFaceUseCase(this.repository);
  Future<Either<Failure, EnrolledContact>> call(String name, List<File?> photos) =>
      repository.enroll(name, photos);
}

class RecogniseFaceUseCase {
  final FaceRepository repository;
  RecogniseFaceUseCase(this.repository);
  Future<Either<Failure, FaceRecognitionResult>> call(File? imageFile) =>
      repository.recognise(imageFile);
}

class DeleteContactUseCase {
  final FaceRepository repository;
  DeleteContactUseCase(this.repository);
  Future<Either<Failure, void>> call(String id) => repository.deleteContact(id);
}
