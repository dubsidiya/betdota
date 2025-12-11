import '../models/live_match_data.dart';
import '../models/odds.dart';
import '../models/match.dart';

/// Тип ставки
enum BetType {
  radiantWin,      // Победа Radiant
  direWin,         // Победа Dire
  radiantKills,    // Больше убийств у Radiant
  direKills,       // Больше убийств у Dire
  totalKills,      // Общее количество убийств
  matchDuration,   // Длительность матча
}

/// Решение о ставке
class BettingDecision {
  final BetType betType;
  final double confidence; // Уверенность от 0.0 до 1.0
  final double recommendedAmount; // Рекомендуемая сумма ставки
  final String reasoning; // Обоснование решения
  final Map<String, dynamic> analysisData; // Данные анализа
  
  BettingDecision({
    required this.betType,
    required this.confidence,
    required this.recommendedAmount,
    required this.reasoning,
    required this.analysisData,
  });
}

/// Сервис для принятия решений о ставках на основе анализа паттернов
class BettingDecisionService {
  double _currentBankroll = 10000.0;
  
  /// Установить текущий банкролл
  void setBankroll(double amount) {
    _currentBankroll = amount;
  }
  
  /// Получить текущий банкролл
  double get bankroll => _currentBankroll;
  
  /// Анализ матча и принятие решения о ставке
  /// Возвращает решение с рекомендацией типа ставки, суммы и уверенности
  BettingDecision analyzeAndDecide(
    LiveMatchData liveData,
    Odds? odds,
    Match match,
  ) {
    final analysis = _analyzeMatchState(liveData, odds, match);
    final decision = _makeDecision(analysis, liveData, odds);
    
    return decision;
  }
  
  /// Анализ текущего состояния матча
  Map<String, dynamic> _analyzeMatchState(
    LiveMatchData liveData,
    Odds? odds,
    Match match,
  ) {
    final analysis = <String, dynamic>{};
    
    // 1. Анализ преимущества по золоту
    final radiantNetWorth = liveData.radiantNetWorth ?? 0;
    final direNetWorth = liveData.direNetWorth ?? 0;
    final totalNetWorth = radiantNetWorth + direNetWorth;
    
    if (totalNetWorth > 0) {
      final radiantGoldAdvantage = (radiantNetWorth / totalNetWorth) - 0.5;
      analysis['radiantGoldAdvantage'] = radiantGoldAdvantage;
      analysis['goldAdvantagePercent'] = (radiantGoldAdvantage * 100).abs();
    }
    
    // 2. Анализ преимущества по убийствам
    final radiantKills = liveData.radiantKills ?? 0;
    final direKills = liveData.direKills ?? 0;
    final totalKills = radiantKills + direKills;
    
    if (totalKills > 0) {
      final radiantKillAdvantage = (radiantKills / totalKills) - 0.5;
      analysis['radiantKillAdvantage'] = radiantKillAdvantage;
      analysis['killAdvantagePercent'] = (radiantKillAdvantage * 100).abs();
    }
    
    // 3. Анализ опыта команд
    double radiantXp = 0.0;
    double direXp = 0.0;
    
    if (liveData.players != null) {
      for (var player in liveData.players!) {
        final xp = (player.xpm ?? 0) * ((liveData.duration ?? 0) / 60.0);
        if (player.teamNumber == 0) {
          radiantXp += xp;
        } else if (player.teamNumber == 1) {
          direXp += xp;
        }
      }
    }
    
    final totalXp = radiantXp + direXp;
    if (totalXp > 0) {
      final radiantXpAdvantage = (radiantXp / totalXp) - 0.5;
      analysis['radiantXpAdvantage'] = radiantXpAdvantage;
    }
    
    // 4. Анализ длительности матча
    final duration = liveData.duration ?? 0;
    analysis['duration'] = duration;
    analysis['isEarlyGame'] = duration < 1200; // Меньше 20 минут
    analysis['isMidGame'] = duration >= 1200 && duration < 2400; // 20-40 минут
    analysis['isLateGame'] = duration >= 2400; // Больше 40 минут
    
    // 5. Анализ паттернов по времени
    // В ранней игре преимущество по золоту менее значимо
    // В поздней игре преимущество по золоту критично
    double timeWeight = 1.0;
    if (duration < 600) {
      timeWeight = 0.5; // Ранняя игра - меньше веса
    } else if (duration > 2400) {
      timeWeight = 1.5; // Поздняя игра - больше веса
    }
    analysis['timeWeight'] = timeWeight;
    
    // 6. Анализ коэффициентов
    if (odds != null) {
      final radiantOddsValue = odds.radiantOdds ?? 2.0;
      final direOddsValue = odds.direOdds ?? 2.0;
      final radiantImpliedProb = 1.0 / radiantOddsValue;
      final direImpliedProb = 1.0 / direOddsValue;
      analysis['radiantImpliedProb'] = radiantImpliedProb;
      analysis['direImpliedProb'] = direImpliedProb;
      analysis['valueBet'] = _calculateValueBet(radiantImpliedProb, direImpliedProb, analysis, odds);
    }
    
    // 7. Комплексный анализ преимущества
    double radiantAdvantage = 0.0;
    
    if (analysis['radiantGoldAdvantage'] != null) {
      radiantAdvantage += analysis['radiantGoldAdvantage'] * timeWeight * 0.4;
    }
    if (analysis['radiantKillAdvantage'] != null) {
      radiantAdvantage += analysis['radiantKillAdvantage'] * 0.3;
    }
    if (analysis['radiantXpAdvantage'] != null) {
      radiantAdvantage += analysis['radiantXpAdvantage'] * 0.3;
    }
    
    analysis['radiantAdvantage'] = radiantAdvantage;
    analysis['direAdvantage'] = -radiantAdvantage;
    
    return analysis;
  }
  
  /// Расчет value bet (ставка с положительным математическим ожиданием)
  Map<String, dynamic>? _calculateValueBet(
    double radiantImpliedProb,
    double direImpliedProb,
    Map<String, dynamic> analysis,
    Odds odds,
  ) {
    final radiantRealProb = 0.5 + (analysis['radiantAdvantage'] ?? 0.0);
    final direRealProb = 1.0 - radiantRealProb;
    
    final radiantValue = radiantRealProb * radiantImpliedProb - 1.0;
    final direValue = direRealProb * direImpliedProb - 1.0;
    
    if (radiantValue > 0.1 || direValue > 0.1) {
      return {
        'type': radiantValue > direValue ? BetType.radiantWin : BetType.direWin,
        'value': radiantValue > direValue ? radiantValue : direValue,
        'realProb': radiantValue > direValue ? radiantRealProb : direRealProb,
        'impliedProb': radiantValue > direValue ? radiantImpliedProb : direImpliedProb,
      };
    }
    
    return null;
  }
  
  /// Принятие решения на основе анализа
  BettingDecision _makeDecision(
    Map<String, dynamic> analysis,
    LiveMatchData liveData,
    Odds? odds,
  ) {
    final radiantAdvantage = analysis['radiantAdvantage'] ?? 0.0;
    final confidence = (radiantAdvantage.abs() * 2).clamp(0.0, 1.0);
    
    BetType betType;
    String reasoning;
    
    // Определяем тип ставки на основе анализа
    final goldAdvantagePercent = (analysis['goldAdvantagePercent'] as num?)?.toDouble() ?? 0.0;
    final killAdvantagePercent = (analysis['killAdvantagePercent'] as num?)?.toDouble() ?? 0.0;
    
    if (radiantAdvantage > 0.15) {
      betType = BetType.radiantWin;
      reasoning = 'Radiant имеет значительное преимущество по золоту (${goldAdvantagePercent.toStringAsFixed(1)}%) '
          'и убийствам (${killAdvantagePercent.toStringAsFixed(1)}%). '
          'Вероятность победы Radiant: ${((0.5 + radiantAdvantage) * 100).toStringAsFixed(1)}%';
    } else if (radiantAdvantage < -0.15) {
      betType = BetType.direWin;
      reasoning = 'Dire имеет значительное преимущество по золоту (${goldAdvantagePercent.toStringAsFixed(1)}%) '
          'и убийствам (${killAdvantagePercent.toStringAsFixed(1)}%). '
          'Вероятность победы Dire: ${((0.5 - radiantAdvantage) * 100).toStringAsFixed(1)}%';
    } else {
      // Если преимущество небольшое, анализируем другие факторы
      final duration = liveData.duration ?? 0;
      if (duration < 600 && (analysis['radiantKillAdvantage'] ?? 0).abs() > 0.2) {
        // Ранняя игра, большое преимущество по убийствам
        betType = analysis['radiantKillAdvantage'] > 0 ? BetType.radiantKills : BetType.direKills;
        reasoning = 'Ранняя игра (${(duration / 60).toStringAsFixed(0)} мин). '
            'Преимущество по убийствам может быть временным, но значимым.';
      } else {
        // Неопределенная ситуация - не рекомендуем ставку
        betType = BetType.radiantWin; // По умолчанию
        reasoning = 'Текущее состояние матча не дает четкого преимущества ни одной команде. '
            'Рекомендуется подождать более явных сигналов.';
      }
    }
    
    // Рассчитываем рекомендуемую сумму ставки на основе уверенности и банкролла
    // Используем Kelly Criterion для оптимального размера ставки
    double recommendedAmount = 0.0;
    
    if (odds != null && confidence > 0.5) {
      final winProb = betType == BetType.radiantWin 
          ? (0.5 + radiantAdvantage).clamp(0.0, 1.0)
          : (0.5 - radiantAdvantage).clamp(0.0, 1.0);
      
      final oddsValue = betType == BetType.radiantWin 
          ? (odds.radiantOdds ?? 2.0)
          : (odds.direOdds ?? 2.0);
      
      // Kelly Criterion: f = (p * b - q) / b
      // где p = вероятность выигрыша, q = вероятность проигрыша, b = коэффициенты - 1
      final kellyFraction = (winProb * (oddsValue - 1) - (1 - winProb)) / (oddsValue - 1);
      
      // Используем половину Kelly для консервативности
      final conservativeFraction = (kellyFraction * 0.5).clamp(0.0, 0.1); // Максимум 10% банкролла
      
      recommendedAmount = _currentBankroll * conservativeFraction * confidence;
      
      // Минимальная ставка 100, максимальная 10% от банкролла
      recommendedAmount = recommendedAmount.clamp(100.0, _currentBankroll * 0.1);
    } else {
      reasoning = 'Недостаточно данных или низкая уверенность для рекомендации ставки.';
    }
    
    return BettingDecision(
      betType: betType,
      confidence: confidence,
      recommendedAmount: recommendedAmount,
      reasoning: reasoning,
      analysisData: analysis,
    );
  }
  
  /// Обновить банкролл после ставки
  void updateBankrollAfterBet(double betAmount, bool won, double odds) {
    if (won) {
      _currentBankroll += betAmount * (odds - 1);
    } else {
      _currentBankroll -= betAmount;
    }
  }
}

