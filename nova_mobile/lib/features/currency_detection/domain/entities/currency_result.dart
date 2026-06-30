import 'package:equatable/equatable.dart';

class CurrencyResult extends Equatable {
  final bool success;
  final String? label;
  final String? spokenLabel;
  final double confidence;
  final bool underExposed;

  const CurrencyResult({
    required this.success,
    required this.confidence,
    this.label,
    this.spokenLabel,
    this.underExposed = false,
  });

  @override
  List<Object?> get props => [success, label, spokenLabel, confidence, underExposed];
}
