import 'package:equatable/equatable.dart';

class OcrResult extends Equatable {
  final String text;
  final String language;
  final bool success;
  final int blockCount;

  const OcrResult({
    required this.text,
    required this.language,
    required this.success,
    this.blockCount = 0,
  });

  @override
  List<Object?> get props => [text, language, success, blockCount];
}
