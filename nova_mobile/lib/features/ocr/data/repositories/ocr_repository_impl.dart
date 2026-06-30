import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/ocr_result.dart';
import '../../domain/repositories/ocr_repository.dart';
import '../datasources/mlkit_ocr_datasource.dart';

class OcrRepositoryImpl implements OcrRepository {
  final MlKitOcrDatasource datasource;

  OcrRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, OcrResult>> recognizeText(File? imageFile) async {
    try {
      return right(await datasource.recognizeFromImage(imageFile));
    } catch (e) {
      return left(ServerFailure('Text recognition failed: $e'));
    }
  }
}
