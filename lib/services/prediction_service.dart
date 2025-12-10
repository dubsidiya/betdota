import '../models/match.dart';
import '../models/team_stats.dart';
import '../models/prediction.dart';
import 'dota_api_service.dart';

class PredictionService {
  final DotaApiService _apiService = DotaApiService();

  // Анализ матча и создание предикта
  Future<Prediction> analyzeMatch(Match match) async {
    if (match.radiantTeamId == null || match.direTeamId == null) {
      throw Exception('Match teams information is incomplete');
    }

    // Получаем статистику обеих команд
    final radiantStats = await _apiService.getTeamStats(match.radiantTeamId!);
    final direStats = await _apiService.getTeamStats(match.direTeamId!);

    if (radiantStats == null || direStats == null) {
      throw Exception('Could not fetch team statistics');
    }

    // Анализируем факторы
    final analysis = _calculateMatchAnalysis(radiantStats, direStats);
    
    // Определяем победителя
    String predictedWinner;
    double confidence;
    String reasoning;

    final radiantScore = analysis['radiantScore'] ?? 0.0;
    final direScore = analysis['direScore'] ?? 0.0;

    if (radiantScore > direScore) {
      predictedWinner = 'radiant';
      confidence = _normalizeConfidence(radiantScore - direScore);
      reasoning = _generateReasoning(radiantStats, direStats, analysis, true);
    } else {
      predictedWinner = 'dire';
      confidence = _normalizeConfidence(direScore - radiantScore);
      reasoning = _generateReasoning(direStats, radiantStats, analysis, false);
    }

    return Prediction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      matchId: match.matchId,
      matchTitle: '${match.radiantTeamName ?? "Radiant"} vs ${match.direTeamName ?? "Dire"}',
      predictedWinner: predictedWinner,
      confidence: confidence,
      reasoning: reasoning,
      createdAt: DateTime.now(),
      analysisData: {
        'radiantStats': {
          'winRate': radiantStats.winRate,
          'wins': radiantStats.wins,
          'losses': radiantStats.losses,
        },
        'direStats': {
          'winRate': direStats.winRate,
          'wins': direStats.wins,
          'losses': direStats.losses,
        },
        'scores': analysis,
      },
    );
  }

  // Вычисление анализа матча
  Map<String, double> _calculateMatchAnalysis(TeamStats radiant, TeamStats dire) {
    // Факторы для анализа:
    // 1. Win Rate (вес: 40%)
    // 2. Recent Form (вес: 30%)
    // 3. Head-to-head (если есть, вес: 20%)
    // 4. Average Performance (вес: 10%)

    double radiantScore = 0;
    double direScore = 0;

    // Win Rate (0-100)
    radiantScore += radiant.winRate * 0.4;
    direScore += dire.winRate * 0.4;

    // Recent Form (последние 5 матчей)
    final radiantRecentWins = radiant.recentMatches
        .take(5)
        .where((m) => m.won)
        .length;
    final direRecentWins = dire.recentMatches
        .take(5)
        .where((m) => m.won)
        .length;
    
    final radiantRecentForm = (radiantRecentWins / 5) * 100;
    final direRecentForm = (direRecentWins / 5) * 100;
    
    radiantScore += radiantRecentForm * 0.3;
    direScore += direRecentForm * 0.3;

    // Average Performance (GPM, KDA и т.д.)
    radiantScore += (radiant.avgGpm / 1000) * 0.1 * 100; // Нормализуем
    direScore += (dire.avgGpm / 1000) * 0.1 * 100;

    return {
      'radiantScore': radiantScore,
      'direScore': direScore,
      'radiantWinRate': radiant.winRate,
      'direWinRate': dire.winRate,
      'radiantRecentForm': radiantRecentForm,
      'direRecentForm': direRecentForm,
    };
  }

  // Нормализация уверенности (0.5 - 0.95)
  double _normalizeConfidence(double scoreDifference) {
    // Максимальная разница ~100, нормализуем до 0.45 диапазона
    final normalized = (scoreDifference / 100).clamp(0.0, 0.45);
    return 0.5 + normalized; // От 0.5 до 0.95
  }

  // Генерация объяснения предикта
  String _generateReasoning(
    TeamStats winnerStats,
    TeamStats loserStats,
    Map<String, double> analysis,
    bool isRadiant,
  ) {
    final winnerName = isRadiant ? 'Radiant' : 'Dire';
    
    final winRateDiff = analysis['${isRadiant ? 'radiant' : 'dire'}WinRate']! - 
                       analysis['${isRadiant ? 'dire' : 'radiant'}WinRate']!;
    final formDiff = analysis['${isRadiant ? 'radiant' : 'dire'}RecentForm']! - 
                    analysis['${isRadiant ? 'dire' : 'radiant'}RecentForm']!;

    String reasoning = '$winnerName команда имеет преимущество:\n\n';
    
    if (winRateDiff > 10) {
      reasoning += '• Значительно лучший винрейт (${winnerStats.winRate.toStringAsFixed(1)}% vs ${loserStats.winRate.toStringAsFixed(1)}%)\n';
    } else if (winRateDiff > 0) {
      reasoning += '• Лучший винрейт (${winnerStats.winRate.toStringAsFixed(1)}% vs ${loserStats.winRate.toStringAsFixed(1)}%)\n';
    }
    
    if (formDiff > 20) {
      reasoning += '• Отличная форма в последних матчах\n';
    } else if (formDiff > 0) {
      reasoning += '• Лучшая форма в последних матчах\n';
    }
    
    reasoning += '\nОбщая оценка: ${(analysis['${isRadiant ? 'radiant' : 'dire'}Score']!).toStringAsFixed(1)} vs ${(analysis['${isRadiant ? 'dire' : 'radiant'}Score']!).toStringAsFixed(1)}';

    return reasoning;
  }
}

