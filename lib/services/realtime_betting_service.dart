import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../models/live_match_data.dart';
import '../models/odds.dart';
import 'live_tracking_service.dart';
import 'betting_decision_service.dart';
import 'betting_api_service.dart';
import 'dota_api_service.dart';

/// Основной сервис для автоматического анализа и ставок в реальном времени
class RealtimeBettingService {
  final LiveTrackingService _trackingService = LiveTrackingService();
  final BettingDecisionService _decisionService = BettingDecisionService();
  final BettingApiService _bettingApi = BettingApiService();
  final DotaApiService _apiService = DotaApiService();
  
  final Map<int, StreamSubscription> _subscriptions = {};
  final Map<int, BettingDecision?> _lastDecisions = {};
  
  /// Начать автоматическое отслеживание и анализ матча
  /// Принимает решения о ставках на основе анализа паттернов
  Stream<BettingDecision> startAutoBetting(
    Match match, {
    double minConfidence = 0.6,
    bool autoPlaceBets = false,
  }) {
    final controller = StreamController<BettingDecision>.broadcast();
    
    debugPrint('RealtimeBettingService: Начато отслеживание матча ${match.matchId}');
    
    // Подписываемся на обновления live данных
    final subscription = _trackingService.trackMatch(match.matchId).listen(
      (liveData) async {
        try {
          // Получаем актуальные коэффициенты
          final odds = await _apiService.getMatchOdds(match.matchId);
          
          // Анализируем и принимаем решение
          final decision = _decisionService.analyzeAndDecide(
            liveData,
            odds,
            match,
          );
          
          // Сохраняем последнее решение
          _lastDecisions[match.matchId] = decision;
          
          // Если уверенность достаточна, отправляем решение
          if (decision.confidence >= minConfidence) {
            controller.add(decision);
            
            // Если включена автоматическая ставка и уверенность высокая
            if (autoPlaceBets && decision.confidence >= 0.75 && odds != null) {
              await _placeBetIfNeeded(match, decision, odds);
            }
          }
        } catch (e) {
          debugPrint('RealtimeBettingService: Ошибка анализа: $e');
        }
      },
      onError: (error) {
        debugPrint('RealtimeBettingService: Ошибка отслеживания: $error');
      },
    );
    
    _subscriptions[match.matchId] = subscription;
    
    return controller.stream;
  }
  
  /// Разместить ставку если условия выполнены
  Future<void> _placeBetIfNeeded(
    Match match,
    BettingDecision decision,
    Odds odds,
  ) async {
    try {
      final success = await _bettingApi.placeBet(
        matchId: match.matchId,
        betType: decision.betType,
        amount: decision.recommendedAmount,
        odds: odds,
      );
      
      if (success) {
        debugPrint('RealtimeBettingService: Ставка успешно размещена');
        debugPrint('  Тип: ${decision.betType}');
        debugPrint('  Сумма: ${decision.recommendedAmount.toStringAsFixed(2)}');
        debugPrint('  Уверенность: ${(decision.confidence * 100).toStringAsFixed(1)}%');
      } else {
        debugPrint('RealtimeBettingService: Не удалось разместить ставку');
      }
    } catch (e) {
      debugPrint('RealtimeBettingService: Ошибка размещения ставки: $e');
    }
  }
  
  /// Остановить отслеживание матча
  void stopTracking(int matchId) {
    _subscriptions[matchId]?.cancel();
    _subscriptions.remove(matchId);
    _trackingService.stopTracking(matchId);
    _lastDecisions.remove(matchId);
  }
  
  /// Получить последнее решение для матча
  BettingDecision? getLastDecision(int matchId) {
    return _lastDecisions[matchId];
  }
  
  /// Установить банкролл
  void setBankroll(double amount) {
    _decisionService.setBankroll(amount);
  }
  
  /// Получить текущий банкролл
  double get bankroll => _decisionService.bankroll;
  
  void dispose() {
    for (var matchId in _subscriptions.keys.toList()) {
      stopTracking(matchId);
    }
    _trackingService.dispose();
  }
}

