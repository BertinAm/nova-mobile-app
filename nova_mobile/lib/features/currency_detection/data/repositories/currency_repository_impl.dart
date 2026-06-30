import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/currency_result.dart';
import '../../domain/repositories/currency_repository.dart';
import '../datasources/tflite_currency_datasource.dart';

class CurrencyRepositoryImpl implements CurrencyRepository {
  final TfliteCurrencyDatasource datasource;

  CurrencyRepositoryImpl(this.datasource);

  @override
  Future<Either<Failure, CurrencyResult>> classify(File? imageFile) async {
    try {
      return right(await datasource.classify(imageFile));
    } catch (e) {
      return left(ModelFailure('Currency detection failed: $e'));
    }
  }
}
