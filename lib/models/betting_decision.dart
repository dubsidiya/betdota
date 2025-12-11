/// Решение о ставке на основе анализа матча в реальном времени
class BettingDecision {
  final int? matchId;
  final String recommendedTeam; // 'radiant' или 'dire'
  final double winProbability; // Вероятность победы рекомендуемой команды
  final double confidence; // Уверенность в решении (0.0 - 1.0)
  final double recommendedBetAmount; // Рекомендуемая сумма ставки (% от банкролла)
  final String reasoning; // Обоснование решения
  final double odds; // Коэффициент на рекомендуемую команду
  final Map<String, dynamic> analysis; // Детальный анализ
  final DateTime timestamp;

  BettingDecision({
    this.matchId,
    required this.recommendedTeam,
    required this.winProbability,
    required this.confidence,
    required this.recommendedBetAmount,
    required this.reasoning,
    required this.odds,
    required this.analysis,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get shouldPlaceBet => confidence >= 0.6;
  
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';
  
  // Для обратной совместимости
  String get reason => reasoning;
  double get recommendedAmount => recommendedBetAmount;
}

