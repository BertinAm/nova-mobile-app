import 'package:equatable/equatable.dart';

class EnrolledContact extends Equatable {
  final String id;
  final String name;
  final DateTime createdAt;

  const EnrolledContact({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, name, createdAt];
}

class FaceRecognitionResult extends Equatable {
  final bool faceDetected;
  final bool matched;
  final String? contactName;
  final double? similarity;

  const FaceRecognitionResult({
    required this.faceDetected,
    required this.matched,
    this.contactName,
    this.similarity,
  });

  @override
  List<Object?> get props => [faceDetected, matched, contactName, similarity];
}
