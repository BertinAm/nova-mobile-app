import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/ocr_result.dart';

abstract class OcrRepository {
  Future<Either<Failure, OcrResult>> recognizeText(File? imageFile);
}
