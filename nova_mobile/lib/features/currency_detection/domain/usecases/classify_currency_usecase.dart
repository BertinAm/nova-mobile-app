import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/currency_result.dart';
import '../repositories/currency_repository.dart';

class ClassifyCurrencyUseCase {
  final CurrencyRepository repository;

  ClassifyCurrencyUseCase(this.repository);

  Future<Either<Failure, CurrencyResult>> call(File? imageFile) {
    return repository.classify(imageFile);
  }
}
