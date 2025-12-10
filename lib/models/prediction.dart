class Prediction {
  final String id;
  final int matchId;
  final String? matchTitle;
  final String predictedWinner; // 'radiant' or 'dire'
  final double confidence; // 0.0 to 1.0
  final String reasoning;
  final DateTime createdAt;
  final bool? wasCorrect;
  final Map<String, dynamic> analysisData;

  Prediction({
    required this.id,
    required this.matchId,
    this.matchTitle,
    required this.predictedWinner,
    required this.confidence,
    required this.reasoning,
    required this.createdAt,
    this.wasCorrect,
    required this.analysisData,
  });

  factory Prediction.fromJson(Map<String, dynamic> json) {
    return Prediction(
      id: json['id'] ?? '',
      matchId: json['matchId'] ?? 0,
      matchTitle: json['matchTitle'],
      predictedWinner: json['predictedWinner'] ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      reasoning: json['reasoning'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      wasCorrect: json['wasCorrect'],
      analysisData: json['analysisData'] ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'matchId': matchId,
      'matchTitle': matchTitle,
      'predictedWinner': predictedWinner,
      'confidence': confidence,
      'reasoning': reasoning,
      'createdAt': createdAt.toIso8601String(),
      'wasCorrect': wasCorrect,
      'analysisData': analysisData,
    };
  }

  String get confidencePercentage => '${(confidence * 100).toStringAsFixed(1)}%';
}

