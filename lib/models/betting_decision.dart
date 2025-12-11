/// Решение о ставке на основе анализа матча в реальном времени
class BettingDecision {
  final int matchId;
  final String recommendedTeam; // 'radiant' или 'dire'
  final double confidence; // 0.0 - 1.0
  final double recommendedAmount; // Рекомендуемая сумма ставки
  final String reason; // Объяснение решения
  final Map<String, dynamic> analysis; // Детальный анализ
  final DateTime timestamp;

  BettingDecision({
    required this.matchId,
    required this.recommendedTeam,
    required this.confidence,
    required this.recommendedAmount,
    required this.reason,
    required this.analysis,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get shouldPlaceBet => confidence >= 0.6;
  
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
}

