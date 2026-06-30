import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/ocr_result.dart';
import '../repositories/ocr_repository.dart';

class RecognizeTextUseCase {
  final OcrRepository repository;

  RecognizeTextUseCase(this.repository);

  Future<Either<Failure, OcrResult>> call(File? imageFile) {
    return repository.recognizeText(imageFile);
  }
}
