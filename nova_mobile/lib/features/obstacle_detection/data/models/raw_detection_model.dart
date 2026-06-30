class RawDetectionModel {
  final String label;
  final double confidence;
  final double top;
  final double left;
  final double bottom;
  final double right;

  const RawDetectionModel({
    required this.label,
    required this.confidence,
    required this.top,
    required this.left,
    required this.bottom,
    required this.right,
  });

  double get widthNorm => (right - left).abs().clamp(0.0, 1.0);
  double get centerX => ((left + right) / 2).clamp(0.0, 1.0);
}
