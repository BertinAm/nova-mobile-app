import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/currency_result.dart';

abstract class CurrencyRepository {
  Future<Either<Failure, CurrencyResult>> classify(File? imageFile);
}
