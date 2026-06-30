import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/camera/camera_service.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/tts/tts_service.dart';
import '../../domain/entities/currency_result.dart';
import '../../domain/usecases/classify_currency_usecase.dart';

abstract class CurrencyEvent extends Equatable {
  const CurrencyEvent();
  @override
  List<Object?> get props => [];
}

class IdentifyCurrency extends CurrencyEvent {
  const IdentifyCurrency();
}

abstract class CurrencyState extends Equatable {
  const CurrencyState();
  @override
  List<Object?> get props => [];
}

class CurrencyIdle extends CurrencyState {
  const CurrencyIdle();
}

class CurrencyProcessing extends CurrencyState {
  const CurrencyProcessing();
}

class CurrencyDetected extends CurrencyState {
  final CurrencyResult result;
  const CurrencyDetected(this.result);
  @override
  List<Object?> get props => [result];
}

class CurrencyNotClear extends CurrencyState {
  final double confidence;
  final bool underExposed;
  const CurrencyNotClear(this.confidence, {this.underExposed = false});
  @override
  List<Object?> get props => [confidence, underExposed];
}

class CurrencyError extends CurrencyState {
  final String message;
  const CurrencyError(this.message);
  @override
  List<Object?> get props => [message];
}

class CurrencyBloc extends Bloc<CurrencyEvent, CurrencyState> {
  final ClassifyCurrencyUseCase _classifyCurrency;
  final CameraService _camera;
  final TtsService _tts;
  final AppDatabase _db;

  CurrencyBloc(this._classifyCurrency, this._camera, this._tts, this._db)
      : super(const CurrencyIdle()) {
    on<IdentifyCurrency>(_onIdentify);
  }

  Future<void> _onIdentify(
    IdentifyCurrency event,
    Emitter<CurrencyState> emit,
  ) async {
    emit(const CurrencyProcessing());
    await _tts.speak('Identifying money.', priority: TtsPriority.high);

    final image = await _camera.captureStill();
    final result = await _classifyCurrency(image);
    await result.fold(
      (failure) async {
        emit(CurrencyError(failure.message));
        await _tts.speak(
          'Currency detection failed. Please try again.',
          priority: TtsPriority.high,
        );
        await _db.insertUsageEvent(moduleId: ModuleIds.currency, outcome: 'error');
      },
      (currency) async {
        if (!currency.success) {
          emit(CurrencyNotClear(currency.confidence, underExposed: currency.underExposed));
          final lightingHint = currency.underExposed
              ? ' The frame appears dark. Turn on the torch if possible.'
              : '';
          await _tts.speak(
            'Could not identify the note clearly. Please try again with better lighting or closer to the camera.$lightingHint',
            priority: TtsPriority.high,
          );
          await _db.insertUsageEvent(
            moduleId: ModuleIds.currency,
            outcome: 'low_confidence',
            confidenceScore: currency.confidence,
          );
          return;
        }

        emit(CurrencyDetected(currency));
        await _tts.speak(currency.spokenLabel!, priority: TtsPriority.high);
        await _db.insertUsageEvent(
          moduleId: ModuleIds.currency,
          outcome: currency.label!,
          confidenceScore: currency.confidence,
        );
      },
    );
  }
}
