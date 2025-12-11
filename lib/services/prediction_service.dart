import '../models/match.dart';
import '../models/team_stats.dart';
import '../models/prediction.dart';
import '../models/draft.dart';
import '../models/odds.dart';
import '../models/live_match_data.dart';
import 'dota_api_service.dart';
import 'hero_synergy_service.dart';

class PredictionService {
  final DotaApiService _apiService = DotaApiService();
  final HeroSynergyService _synergyService = HeroSynergyService();

  // Анализ матча и создание предикта
  Future<Prediction> analyzeMatch(Match match) async {
    // Не создаем предикты для завершенных матчей
    if (match.isFinished) {
      throw Exception('Нельзя создать предикт для завершенного матча');
    }

    if (match.radiantTeamId == null || match.direTeamId == null) {
      throw Exception('Match teams information is incomplete');
    }

    // Получаем статистику обеих команд
    final radiantStats = await _apiService.getTeamStats(match.radiantTeamId!);
    final direStats = await _apiService.getTeamStats(match.direTeamId!);

    if (radiantStats == null || direStats == null) {
      throw Exception('Could not fetch team statistics');
    }

    // Получаем дополнительные данные
    Draft? draft;
    Odds? odds;
    LiveMatchData? liveData;

    try {
      draft = await _apiService.getMatchDraft(match.matchId);
    } catch (e) {
      // Игнорируем ошибки получения драфта
    }

    try {
      odds = await _apiService.getMatchOdds(match.matchId);
    } catch (e) {
      // Игнорируем ошибки получения коэффициентов
    }

    if (match.isLive) {
      try {
        liveData = await _apiService.getLiveMatchData(match.matchId);
      } catch (e) {
        // Игнорируем ошибки получения лайв-данных
      }
    }

    // Анализируем факторы
    final analysis = await _calculateAdvancedMatchAnalysis(
      radiantStats,
      direStats,
      draft,
      odds,
      liveData,
    );
    
    // Определяем победителя
    String predictedWinner;
    double confidence;
    String reasoning;

    final radiantScore = analysis['radiantScore'] ?? 0.0;
    final direScore = analysis['direScore'] ?? 0.0;

    if (radiantScore > direScore) {
      predictedWinner = 'radiant';
      confidence = _normalizeConfidence(radiantScore - direScore);
      reasoning = await _generateAdvancedReasoning(
        radiantStats,
        direStats,
        analysis,
        draft,
        odds,
        liveData,
        true,
      );
    } else {
      predictedWinner = 'dire';
      confidence = _normalizeConfidence(direScore - radiantScore);
      reasoning = await _generateAdvancedReasoning(
        direStats,
        radiantStats,
        analysis,
        draft,
        odds,
        liveData,
        false,
      );
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
        'hasDraft': draft != null,
        'hasOdds': odds != null,
        'hasLiveData': liveData != null,
      },
    );
  }

  // Расширенный анализ матча с учетом всех факторов
  Future<Map<String, double>> _calculateAdvancedMatchAnalysis(
    TeamStats radiant,
    TeamStats dire,
    Draft? draft,
    Odds? odds,
    LiveMatchData? liveData,
  ) async {
    double radiantScore = 0;
    double direScore = 0;

    // 1. Win Rate команды (вес: 20%)
    radiantScore += radiant.winRate * 0.2;
    direScore += dire.winRate * 0.2;

    // 2. Recent Form (вес: 15%)
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
    
    radiantScore += radiantRecentForm * 0.15;
    direScore += direRecentForm * 0.15;

    // 3. Анализ драфта и синергии героев (вес: 30%)
    if (draft != null) {
      try {
        final draftComparison = await _synergyService.compareDrafts(draft);
        
        // Преимущество Radiant по драфту
        final draftAdvantage = draftComparison.radiantAdvantage;
        radiantScore += (0.5 + draftAdvantage) * 100 * 0.3;
        direScore += (0.5 - draftAdvantage) * 100 * 0.3;
      } catch (e) {
        // Если не удалось проанализировать драфт, используем нейтральные значения
        radiantScore += 50 * 0.3;
        direScore += 50 * 0.3;
      }
    } else {
      // Если драфта нет, используем нейтральные значения
      radiantScore += 50 * 0.3;
      direScore += 50 * 0.3;
    }

    // 4. Коэффициенты букмекеров (вес: 20%)
    if (odds != null && odds.radiantWinProbability != null) {
      final radiantProb = odds.radiantWinProbability!;
      radiantScore += radiantProb * 100 * 0.2;
      direScore += (1 - radiantProb) * 100 * 0.2;
    } else {
      // Если коэффициентов нет, используем нейтральные значения
      radiantScore += 50 * 0.2;
      direScore += 50 * 0.2;
    }

    // 5. Лайв-данные (вес: 15% для лайв матчей)
    if (liveData != null) {
      double liveAdvantage = 0.0;
      
      // Анализ преимущества по золоту
      if (liveData.radiantNetWorth != null && liveData.direNetWorth != null) {
        final netWorthDiff = liveData.radiantNetWorth! - liveData.direNetWorth!;
        // Нормализуем разницу (максимум ~50000 золота = 100%)
        liveAdvantage += (netWorthDiff / 50000).clamp(-1.0, 1.0) * 0.5;
      }
      
      // Анализ преимущества по киллам
      if (liveData.radiantKills != null && liveData.direKills != null) {
        final killDiff = liveData.radiantKills! - liveData.direKills!;
        // Нормализуем разницу (максимум ~30 киллов = 100%)
        liveAdvantage += (killDiff / 30).clamp(-1.0, 1.0) * 0.3;
      }
      
      // Анализ преимущества по счету
      if (liveData.radiantScore != null && liveData.direScore != null) {
        final scoreDiff = liveData.radiantScore! - liveData.direScore!;
        // Нормализуем разницу (максимум ~10 очков = 100%)
        liveAdvantage += (scoreDiff / 10).clamp(-1.0, 1.0) * 0.2;
      }
      
      radiantScore += (0.5 + liveAdvantage) * 100 * 0.15;
      direScore += (0.5 - liveAdvantage) * 100 * 0.15;
    } else {
      // Если лайв-данных нет, используем нейтральные значения
      radiantScore += 50 * 0.15;
      direScore += 50 * 0.15;
    }

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

  // Расширенная генерация объяснения предикта
  Future<String> _generateAdvancedReasoning(
    TeamStats winnerStats,
    TeamStats loserStats,
    Map<String, double> analysis,
    Draft? draft,
    Odds? odds,
    LiveMatchData? liveData,
    bool isRadiant,
  ) async {
    final winnerName = isRadiant ? 'Radiant' : 'Dire';
    
    final winRateDiff = analysis['${isRadiant ? 'radiant' : 'dire'}WinRate']! - 
                       analysis['${isRadiant ? 'dire' : 'radiant'}WinRate']!;
    final formDiff = analysis['${isRadiant ? 'radiant' : 'dire'}RecentForm']! - 
                    analysis['${isRadiant ? 'dire' : 'radiant'}RecentForm']!;

    String reasoning = '$winnerName команда имеет преимущество:\n\n';
    
    // Статистика команды
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

    // Анализ драфта
    if (draft != null) {
      try {
        final draftComparison = await _synergyService.compareDrafts(draft);
        final synergyAdvantage = isRadiant 
            ? draftComparison.radiantSynergy - draftComparison.direSynergy
            : draftComparison.direSynergy - draftComparison.radiantSynergy;
        
        if (synergyAdvantage > 0.1) {
          reasoning += '• Лучшая синергия героев в драфте\n';
        }
        
        if (draftComparison.radiantAdvantage.abs() > 0.15) {
          if ((isRadiant && draftComparison.radiantAdvantage > 0) ||
              (!isRadiant && draftComparison.radiantAdvantage < 0)) {
            reasoning += '• Преимущество в контрпиках\n';
          }
        }
      } catch (e) {
        // Игнорируем ошибки анализа драфта
      }
    }

    // Коэффициенты букмекеров
    if (odds != null && odds.radiantWinProbability != null) {
      final prob = isRadiant ? odds.radiantWinProbability! : odds.direWinProbability!;
      if (prob > 0.6) {
        reasoning += '• Высокая вероятность победы по коэффициентам букмекеров (${(prob * 100).toStringAsFixed(1)}%)\n';
      }
    }

    // Лайв-данные
    if (liveData != null) {
      if (isRadiant) {
        if (liveData.radiantNetWorth != null && liveData.direNetWorth != null &&
            liveData.radiantNetWorth! > liveData.direNetWorth!) {
          final advantage = liveData.radiantNetWorth! - liveData.direNetWorth!;
          reasoning += '• Преимущество по золоту: +${(advantage / 1000).toStringAsFixed(1)}k\n';
        }
        if (liveData.radiantKills != null && liveData.direKills != null &&
            liveData.radiantKills! > liveData.direKills!) {
          final advantage = liveData.radiantKills! - liveData.direKills!;
          reasoning += '• Преимущество по киллам: +$advantage\n';
        }
      } else {
        if (liveData.radiantNetWorth != null && liveData.direNetWorth != null &&
            liveData.direNetWorth! > liveData.radiantNetWorth!) {
          final advantage = liveData.direNetWorth! - liveData.radiantNetWorth!;
          reasoning += '• Преимущество по золоту: +${(advantage / 1000).toStringAsFixed(1)}k\n';
        }
        if (liveData.radiantKills != null && liveData.direKills != null &&
            liveData.direKills! > liveData.radiantKills!) {
          final advantage = liveData.direKills! - liveData.radiantKills!;
          reasoning += '• Преимущество по киллам: +$advantage\n';
        }
      }
    }
    
    reasoning += '\nОбщая оценка: ${(analysis['${isRadiant ? 'radiant' : 'dire'}Score']!).toStringAsFixed(1)} vs ${(analysis['${isRadiant ? 'dire' : 'radiant'}Score']!).toStringAsFixed(1)}';

    return reasoning;
  }
}
