import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../models/betting_decision.dart';
import '../models/odds.dart';
import 'realtime_tracking_service.dart';
import 'betting_decision_service.dart';
import 'dota_api_service.dart';

/// Сервис для реального времени ставок
/// Отслеживает матчи и принимает решения о ставках на основе анализа
class RealtimeBettingService {
  final RealtimeTrackingService _trackingService = RealtimeTrackingService();
  final BettingDecisionService _decisionService = BettingDecisionService();
  final DotaApiService _apiService = DotaApiService();
  final Map<int, StreamSubscription> _subscriptions = {};
  final Map<int, List<BettingDecision>> _decisionHistory = {};
  final Map<int, BettingDecision?> _lastDecisions = {};
  
  /// Начать отслеживание матча и получение решений о ставках
  Stream<BettingDecision> trackAndDecide(
    Match match, {
    double minConfidence = 0.6,
    double baseAmount = 100.0,
    bool autoPlaceBets = false,
  }) {
    final controller = StreamController<BettingDecision>.broadcast();
    final history = <LiveMatchData>[];
    
    debugPrint('RealtimeBettingService: Начато отслеживание матча ${match.matchId}');
    
    // Подписываемся на обновления live данных
    final subscription = _trackingService.trackMatch(match.matchId).listen(
      (liveData) async {
        try {
          // Сохраняем историю (последние 10 обновлений)
          history.add(liveData);
          if (history.length > 10) {
            history.removeAt(0);
          }
          
          // Получаем актуальные коэффициенты
          final odds = await _apiService.getMatchOdds(match.matchId);
          
          // Анализируем и принимаем решение
          final decision = _decisionService.analyzeWithPatterns(
            liveData,
            odds,
            match,
            history,
          );
          
          // Сохраняем решение
          _lastDecisions[match.matchId] = decision;
          if (!_decisionHistory.containsKey(match.matchId)) {
            _decisionHistory[match.matchId] = [];
          }
          _decisionHistory[match.matchId]!.add(decision);
          
          // Ограничиваем историю решений
          if (_decisionHistory[match.matchId]!.length > 50) {
            _decisionHistory[match.matchId]!.removeAt(0);
          }
          
          // Если уверенность достаточна, отправляем решение
          if (decision.confidence >= minConfidence) {
            controller.add(decision);
            
            debugPrint('RealtimeBettingService: Решение для матча ${match.matchId}: '
                '${decision.recommendedTeam.toUpperCase()}, '
                'уверенность: ${decision.confidencePercent}, '
                'сумма: ${decision.recommendedAmount.toStringAsFixed(0)}');
            
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
      // Здесь должна быть интеграция с API букмекеров
      // Пока что только логируем
      debugPrint('RealtimeBettingService: Автоматическая ставка размещена: '
          'Матч ${match.matchId}, '
          'Команда: ${decision.recommendedTeam}, '
          'Сумма: ${decision.recommendedAmount.toStringAsFixed(0)}, '
          'Коэффициент: ${decision.recommendedTeam == "radiant" ? odds.radiantOdds : odds.direOdds}');
      
      // TODO: Интеграция с реальным API букмекеров
      // await bettingApi.placeBet(...);
    } catch (e) {
      debugPrint('RealtimeBettingService: Ошибка размещения ставки: $e');
    }
  }
  
  /// Остановить отслеживание матча
  void stopTracking(int matchId) {
    _subscriptions[matchId]?.cancel();
    _subscriptions.remove(matchId);
    _trackingService.stopTracking(matchId);
    _decisionHistory.remove(matchId);
    _lastDecisions.remove(matchId);
  }
  
  /// Получить последнее решение для матча
  BettingDecision? getLastDecision(int matchId) {
    return _lastDecisions[matchId];
  }
  
  /// Получить историю решений для матча
  List<BettingDecision> getDecisionHistory(int matchId) {
    return _decisionHistory[matchId] ?? [];
  }
  
  /// Остановить все отслеживания
  void stopAll() {
    for (var matchId in _subscriptions.keys.toList()) {
      stopTracking(matchId);
    }
  }
}
