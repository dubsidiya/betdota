import 'package:flutter/foundation.dart';
import '../models/live_match_data.dart';
import '../models/odds.dart';
import '../models/match.dart';
import '../models/betting_decision.dart';

/// Сервис для принятия решений о ставках на основе анализа ситуации на карте
class BettingDecisionService {
  
  /// Анализ текущей ситуации и принятие решения о ставке
  BettingDecision analyzeAndDecide({
    required LiveMatchData liveData,
    required Odds odds,
    required Match match,
  }) {
    // Анализируем различные факторы
    final analysis = _analyzeGameState(liveData);
    
    // Определяем рекомендуемую ставку
    final recommendation = _calculateBettingRecommendation(
      analysis: analysis,
      odds: odds,
      liveData: liveData,
    );
    
    return recommendation;
  }
  
  /// Анализ текущего состояния игры
  Map<String, dynamic> _analyzeGameState(LiveMatchData liveData) {
    final analysis = <String, dynamic>{};
    
    // 1. Анализ золота (Net Worth)
    final radiantNW = liveData.radiantNetWorth ?? 0;
    final direNW = liveData.direNetWorth ?? 0;
    final totalNW = radiantNW + direNW;
    
    if (totalNW > 0) {
      analysis['radiantGoldAdvantage'] = (radiantNW - direNW) / totalNW;
      analysis['radiantGoldPercent'] = radiantNW / totalNW;
    } else {
      analysis['radiantGoldAdvantage'] = 0.0;
      analysis['radiantGoldPercent'] = 0.5;
    }
    
    // 2. Анализ убийств
    final radiantKills = liveData.radiantKills ?? 0;
    final direKills = liveData.direKills ?? 0;
    final totalKills = radiantKills + direKills;
    
    if (totalKills > 0) {
      analysis['radiantKillAdvantage'] = (radiantKills - direKills) / totalKills;
      analysis['radiantKillPercent'] = radiantKills / totalKills;
    } else {
      analysis['radiantKillAdvantage'] = 0.0;
      analysis['radiantKillPercent'] = 0.5;
    }
    
    // 3. Анализ времени матча
    final duration = liveData.duration ?? 0;
    analysis['duration'] = duration;
    analysis['isEarlyGame'] = duration < 1200; // До 20 минут
    analysis['isMidGame'] = duration >= 1200 && duration < 2400; // 20-40 минут
    analysis['isLateGame'] = duration >= 2400; // После 40 минут
    
    // 4. Анализ игроков
    if (liveData.players != null && liveData.players!.isNotEmpty) {
      final radiantPlayers = liveData.players!.where((p) => p.teamNumber == 0).toList();
      final direPlayers = liveData.players!.where((p) => p.teamNumber == 1).toList();
      
      // Средний уровень команд
      final radiantAvgLevel = radiantPlayers.isNotEmpty
          ? radiantPlayers.map((p) => p.level ?? 0).reduce((a, b) => a + b) / radiantPlayers.length
          : 0.0;
      final direAvgLevel = direPlayers.isNotEmpty
          ? direPlayers.map((p) => p.level ?? 0).reduce((a, b) => a + b) / direPlayers.length
          : 0.0;
      
      analysis['radiantAvgLevel'] = radiantAvgLevel;
      analysis['direAvgLevel'] = direAvgLevel;
      analysis['levelAdvantage'] = radiantAvgLevel - direAvgLevel;
      
      // Средний GPM команд
      final radiantAvgGPM = radiantPlayers.isNotEmpty
          ? radiantPlayers.map((p) => p.gpm ?? 0).reduce((a, b) => a + b) / radiantPlayers.length
          : 0.0;
      final direAvgGPM = direPlayers.isNotEmpty
          ? direPlayers.map((p) => p.gpm ?? 0).reduce((a, b) => a + b) / direPlayers.length
          : 0.0;
      
      analysis['radiantAvgGPM'] = radiantAvgGPM;
      analysis['direAvgGPM'] = direAvgGPM;
      analysis['gpmAdvantage'] = radiantAvgGPM - direAvgGPM;
    }
    
    // 5. Общий счет (если доступен)
    final radiantScore = liveData.radiantScore ?? 0;
    final direScore = liveData.direScore ?? 0;
    analysis['radiantScore'] = radiantScore;
    analysis['direScore'] = direScore;
    analysis['scoreAdvantage'] = radiantScore - direScore;
    
    return analysis;
  }
  
  /// Расчет рекомендации по ставке
  BettingDecision _calculateBettingRecommendation({
    required Map<String, dynamic> analysis,
    required Odds odds,
    required LiveMatchData liveData,
  }) {
    double radiantWinProbability = 0.5;
    double confidence = 0.0;
    String reasoning = '';
    double recommendedBetAmount = 0.0;
    
    // Базовую вероятность берем из коэффициентов
    final impliedRadiantProb = 1.0 / (odds.radiantOdds ?? 2.0);
    final impliedDireProb = 1.0 / (odds.direOdds ?? 2.0);
    final totalImplied = impliedRadiantProb + impliedDireProb;
    
    // Нормализуем (коэффициенты могут быть не идеальными)
    radiantWinProbability = impliedRadiantProb / totalImplied;
    
    // Корректируем на основе анализа игры
    final goldAdvantage = analysis['radiantGoldAdvantage'] as double;
    final killAdvantage = analysis['radiantKillAdvantage'] as double;
    final levelAdvantage = analysis['levelAdvantage'] as double ?? 0.0;
    final gpmAdvantage = analysis['gpmAdvantage'] as double ?? 0.0;
    final scoreAdvantage = analysis['scoreAdvantage'] as int ?? 0;
    
    // Веса факторов в зависимости от времени игры
    final duration = analysis['duration'] as int;
    double goldWeight, killWeight, levelWeight, gpmWeight;
    
    if (duration < 1200) {
      // Ранняя игра: уровень и GPM важнее
      goldWeight = 0.2;
      killWeight = 0.3;
      levelWeight = 0.3;
      gpmWeight = 0.2;
    } else if (duration < 2400) {
      // Средняя игра: все факторы важны
      goldWeight = 0.3;
      killWeight = 0.25;
      levelWeight = 0.2;
      gpmWeight = 0.25;
    } else {
      // Поздняя игра: золото критично
      goldWeight = 0.4;
      killWeight = 0.2;
      levelWeight = 0.15;
      gpmWeight = 0.25;
    }
    
    // Корректируем вероятность
    final adjustment = (goldAdvantage * goldWeight) +
                      (killAdvantage * killWeight) +
                      (levelAdvantage / 25.0 * levelWeight) + // Нормализуем уровень
                      (gpmAdvantage / 1000.0 * gpmWeight); // Нормализуем GPM
    
    radiantWinProbability = (radiantWinProbability + adjustment).clamp(0.0, 1.0);
    
    // Уверенность зависит от размера преимущества
    final advantageSize = (goldAdvantage.abs() + killAdvantage.abs() + 
                          (levelAdvantage.abs() / 25.0) + 
                          (gpmAdvantage.abs() / 1000.0)) / 4.0;
    confidence = advantageSize.clamp(0.0, 1.0);
    
    // Генерируем обоснование
    final reasons = <String>[];
    
    if (goldAdvantage > 0.1) {
      reasons.add('Radiant имеет значительное преимущество по золоту (${(goldAdvantage * 100).toStringAsFixed(1)}%)');
    } else if (goldAdvantage < -0.1) {
      reasons.add('Dire имеет значительное преимущество по золоту (${(-goldAdvantage * 100).toStringAsFixed(1)}%)');
    }
    
    if (killAdvantage > 0.15) {
      reasons.add('Radiant лидирует по убийствам');
    } else if (killAdvantage < -0.15) {
      reasons.add('Dire лидирует по убийствам');
    }
    
    if (levelAdvantage > 2) {
      reasons.add('Radiant имеет преимущество по уровням');
    } else if (levelAdvantage < -2) {
      reasons.add('Dire имеет преимущество по уровням');
    }
    
    if (scoreAdvantage > 5) {
      reasons.add('Radiant ведет по счету');
    } else if (scoreAdvantage < -5) {
      reasons.add('Dire ведет по счету');
    }
    
    reasoning = reasons.isEmpty 
        ? 'Ситуация на карте примерно равная'
        : reasons.join('. ');
    
    // Рекомендуемая сумма ставки (процент от банкролла)
    // Используем Kelly Criterion для расчета оптимальной ставки
    final isRadiantWin = radiantWinProbability > 0.5;
    final selectedOdds = isRadiantWin ? (odds.radiantOdds ?? 2.0) : (odds.direOdds ?? 2.0);
    
    final kellyFraction = _calculateKellyFraction(
      winProbability: isRadiantWin ? radiantWinProbability : (1.0 - radiantWinProbability),
      odds: selectedOdds,
    );
    
    // Ограничиваем максимальную ставку 10% от банкролла
    recommendedBetAmount = (kellyFraction * 100).clamp(0.0, 10.0);
    
    return BettingDecision(
      matchId: liveData.matchId,
      recommendedTeam: isRadiantWin ? 'radiant' : 'dire',
      winProbability: isRadiantWin ? radiantWinProbability : (1.0 - radiantWinProbability),
      confidence: confidence,
      recommendedBetAmount: recommendedBetAmount,
      reasoning: reasoning,
      odds: selectedOdds,
      analysis: analysis,
    );
  }
  
  /// Расчет доли Kelly Criterion для оптимальной ставки
  double _calculateKellyFraction({
    required double winProbability,
    required double odds,
  }) {
    // Kelly Criterion: f = (bp - q) / b
    // где b = odds - 1, p = вероятность выигрыша, q = 1 - p
    final b = odds - 1.0;
    final p = winProbability;
    final q = 1.0 - p;
    
    if (b <= 0) return 0.0;
    
    final kelly = (b * p - q) / b;
    
    // Возвращаем только положительные значения (не ставим на проигрыш)
    return kelly.clamp(0.0, 1.0);
  }
}
