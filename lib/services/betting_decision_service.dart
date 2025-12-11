import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../models/live_match_data.dart';
import '../models/odds.dart';
import '../models/betting_decision.dart';

/// Сервис для принятия решений о ставках на основе анализа матча в реальном времени
class BettingDecisionService {
  
  /// Анализировать текущее состояние матча и принять решение о ставке
  BettingDecision analyzeAndDecide(
    LiveMatchData liveData,
    Odds? odds,
    Match match, {
    double baseAmount = 100.0, // Базовая сумма ставки
  }) {
    final analysis = <String, dynamic>{};
    double radiantAdvantage = 0.0;
    double direAdvantage = 0.0;
    final reasons = <String>[];
    
    // Фактор 1: Разница в золоте (Net Worth)
    if (liveData.radiantNetWorth != null && liveData.direNetWorth != null) {
      final netWorthDiff = liveData.radiantNetWorth! - liveData.direNetWorth!;
      final netWorthPercent = netWorthDiff.abs() / ((liveData.radiantNetWorth! + liveData.direNetWorth!) / 2);
      
      analysis['netWorthDiff'] = netWorthDiff;
      analysis['netWorthPercent'] = netWorthPercent;
      
      if (netWorthDiff > 5000) {
        radiantAdvantage += 0.15;
        reasons.add('Radiant имеет преимущество в золоте: ${netWorthDiff.toStringAsFixed(0)}');
      } else if (netWorthDiff < -5000) {
        direAdvantage += 0.15;
        reasons.add('Dire имеет преимущество в золоте: ${netWorthDiff.abs().toStringAsFixed(0)}');
      }
    }
    
    // Фактор 2: Разница в убийствах
    if (liveData.radiantKills != null && liveData.direKills != null) {
      final killDiff = liveData.radiantKills! - liveData.direKills!;
      analysis['killDiff'] = killDiff;
      
      if (killDiff > 5) {
        radiantAdvantage += 0.12;
        reasons.add('Radiant лидирует по убийствам: +$killDiff');
      } else if (killDiff < -5) {
        direAdvantage += 0.12;
        reasons.add('Dire лидирует по убийствам: +${killDiff.abs()}');
      }
    }
    
    // Фактор 3: Разница в счете (уничтоженные строения)
    if (liveData.radiantScore != null && liveData.direScore != null) {
      final scoreDiff = liveData.radiantScore! - liveData.direScore!;
      analysis['scoreDiff'] = scoreDiff;
      
      if (scoreDiff > 3) {
        radiantAdvantage += 0.10;
        reasons.add('Radiant уничтожил больше строений: +$scoreDiff');
      } else if (scoreDiff < -3) {
        direAdvantage += 0.10;
        reasons.add('Dire уничтожил больше строений: +${scoreDiff.abs()}');
      }
    }
    
    // Фактор 4: Время матча (ранняя/поздняя игра)
    if (liveData.duration != null) {
      analysis['duration'] = liveData.duration;
      
      // В ранней игре (0-20 мин) преимущество менее значимо
      // В поздней игре (30+ мин) преимущество более критично
      if (liveData.duration! < 1200) { // До 20 минут
        radiantAdvantage *= 0.7;
        direAdvantage *= 0.7;
        reasons.add('Ранняя игра - преимущество может измениться');
      } else if (liveData.duration! > 1800) { // После 30 минут
        radiantAdvantage *= 1.2;
        direAdvantage *= 1.2;
        reasons.add('Поздняя игра - преимущество критично');
      }
    }
    
    // Фактор 5: Анализ игроков (если доступны)
    if (liveData.players != null && liveData.players!.isNotEmpty) {
      final radiantPlayers = liveData.players!.where((p) => p.teamNumber == 0).toList();
      final direPlayers = liveData.players!.where((p) => p.teamNumber == 1).toList();
      
      // Средний уровень команды
      final radiantAvgLevel = radiantPlayers
          .where((p) => p.level != null)
          .map((p) => p.level!)
          .fold(0, (a, b) => a + b) / radiantPlayers.length;
      final direAvgLevel = direPlayers
          .where((p) => p.level != null)
          .map((p) => p.level!)
          .fold(0, (a, b) => a + b) / direPlayers.length;
      
      if (radiantAvgLevel > direAvgLevel + 2) {
        radiantAdvantage += 0.08;
        reasons.add('Radiant имеет преимущество в уровнях');
      } else if (direAvgLevel > radiantAvgLevel + 2) {
        direAdvantage += 0.08;
        reasons.add('Dire имеет преимущество в уровнях');
      }
      
      analysis['radiantAvgLevel'] = radiantAvgLevel;
      analysis['direAvgLevel'] = direAvgLevel;
    }
    
    // Фактор 6: Коэффициенты букмекеров
    if (odds != null) {
      analysis['odds'] = {
        'radiant': odds.radiantOdds,
        'dire': odds.direOdds,
      };
      
      // Если коэффициенты сильно отличаются от текущего состояния, это может быть value bet
      final expectedRadiantWin = 1.0 / odds.radiantOdds;
      final expectedDireWin = 1.0 / odds.direOdds;
      
      if (radiantAdvantage > direAdvantage && expectedRadiantWin < 0.5) {
        radiantAdvantage += 0.05;
        reasons.add('Value bet на Radiant (коэффициент выгодный)');
      } else if (direAdvantage > radiantAdvantage && expectedDireWin < 0.5) {
        direAdvantage += 0.05;
        reasons.add('Value bet на Dire (коэффициент выгодный)');
      }
    }
    
    // Определяем победителя и уверенность
    String recommendedTeam;
    double confidence;
    
    if (radiantAdvantage > direAdvantage) {
      recommendedTeam = 'radiant';
      confidence = (0.5 + radiantAdvantage).clamp(0.0, 1.0);
    } else if (direAdvantage > radiantAdvantage) {
      recommendedTeam = 'dire';
      confidence = (0.5 + direAdvantage).clamp(0.0, 1.0);
    } else {
      // Ничья - не рекомендуем ставку
      recommendedTeam = 'none';
      confidence = 0.5;
    }
    
    // Рассчитываем рекомендуемую сумму ставки на основе уверенности
    double recommendedAmount = 0.0;
    if (confidence >= 0.6) {
      // Чем выше уверенность, тем больше сумма (но с ограничением)
      recommendedAmount = baseAmount * (confidence - 0.5) * 2;
      recommendedAmount = recommendedAmount.clamp(baseAmount * 0.1, baseAmount * 2.0);
    }
    
    final reason = reasons.isEmpty 
        ? 'Недостаточно данных для анализа' 
        : reasons.join('. ');
    
    return BettingDecision(
      matchId: match.matchId,
      recommendedTeam: recommendedTeam,
      confidence: confidence,
      recommendedAmount: recommendedAmount,
      reason: reason,
      analysis: analysis,
    );
  }
  
  /// Анализ паттернов для принятия решения
  /// Учитывает исторические данные и текущее состояние
  BettingDecision analyzeWithPatterns(
    LiveMatchData liveData,
    Odds? odds,
    Match match,
    List<LiveMatchData> history, // История изменений
  ) {
    // Базовый анализ
    var decision = analyzeAndDecide(liveData, odds, match);
    
    // Анализ трендов (если есть история)
    if (history.isNotEmpty && history.length >= 2) {
      final trend = _analyzeTrend(history);
      decision.analysis['trend'] = trend;
      
      // Если команда набирает преимущество, увеличиваем уверенность
      if (trend['radiantMomentum'] == true && decision.recommendedTeam == 'radiant') {
        decision = BettingDecision(
          matchId: decision.matchId,
          recommendedTeam: decision.recommendedTeam,
          confidence: (decision.confidence * 1.1).clamp(0.0, 1.0),
          recommendedAmount: decision.recommendedAmount * 1.1,
          reason: '${decision.reason}. Radiant набирает преимущество.',
          analysis: decision.analysis,
        );
      } else if (trend['direMomentum'] == true && decision.recommendedTeam == 'dire') {
        decision = BettingDecision(
          matchId: decision.matchId,
          recommendedTeam: decision.recommendedTeam,
          confidence: (decision.confidence * 1.1).clamp(0.0, 1.0),
          recommendedAmount: decision.recommendedAmount * 1.1,
          reason: '${decision.reason}. Dire набирает преимущество.',
          analysis: decision.analysis,
        );
      }
    }
    
    return decision;
  }
  
  /// Анализ тренда на основе истории изменений
  Map<String, dynamic> _analyzeTrend(List<LiveMatchData> history) {
    if (history.length < 2) {
      return {};
    }
    
    final first = history.first;
    final last = history.last;
    
    bool radiantMomentum = false;
    bool direMomentum = false;
    
    // Анализ изменения золота
    if (first.radiantNetWorth != null && last.radiantNetWorth != null &&
        first.direNetWorth != null && last.direNetWorth != null) {
      final radiantChange = last.radiantNetWorth! - first.radiantNetWorth!;
      final direChange = last.direNetWorth! - first.direNetWorth!;
      
      if (radiantChange > direChange + 2000) {
        radiantMomentum = true;
      } else if (direChange > radiantChange + 2000) {
        direMomentum = true;
      }
    }
    
    // Анализ изменения убийств
    if (first.radiantKills != null && last.radiantKills != null &&
        first.direKills != null && last.direKills != null) {
      final radiantKillChange = last.radiantKills! - first.radiantKills!;
      final direKillChange = last.direKills! - first.direKills!;
      
      if (radiantKillChange > direKillChange + 2) {
        radiantMomentum = true;
      } else if (direKillChange > radiantKillChange + 2) {
        direMomentum = true;
      }
    }
    
    return {
      'radiantMomentum': radiantMomentum,
      'direMomentum': direMomentum,
    };
  }
}
