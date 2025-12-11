import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../models/live_match_data.dart';
import 'dota_api_service.dart';

/// Сервис для отслеживания лайв матчей в реальном времени
/// Обновляет данные каждые несколько секунд и анализирует состояние игры
class LiveTrackingService {
  final DotaApiService _apiService = DotaApiService();
  final Map<int, Timer> _trackingTimers = {};
  final Map<int, StreamController<LiveMatchData>> _matchStreams = {};
  
  /// Начать отслеживание матча в реальном времени
  /// Обновляет данные каждые 2-3 секунды
  Stream<LiveMatchData> trackMatch(int matchId) {
    if (_matchStreams.containsKey(matchId)) {
      return _matchStreams[matchId]!.stream;
    }
    
    final controller = StreamController<LiveMatchData>.broadcast();
    _matchStreams[matchId] = controller;
    
    // Немедленно получаем первые данные
    _updateMatchData(matchId, controller);
    
    // Затем обновляем каждые 2 секунды
    final timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updateMatchData(matchId, controller);
    });
    
    _trackingTimers[matchId] = timer;
    
    return controller.stream;
  }
  
  /// Остановить отслеживание матча
  void stopTracking(int matchId) {
    _trackingTimers[matchId]?.cancel();
    _trackingTimers.remove(matchId);
    _matchStreams[matchId]?.close();
    _matchStreams.remove(matchId);
  }
  
  /// Обновить данные матча
  Future<void> _updateMatchData(int matchId, StreamController<LiveMatchData> controller) async {
    try {
      final liveData = await _apiService.getLiveMatchData(matchId);
      if (liveData != null) {
        controller.add(liveData);
      }
    } catch (e) {
      debugPrint('LiveTrackingService: Ошибка обновления данных матча $matchId: $e');
    }
  }
  
  /// Остановить все отслеживания
  void stopAll() {
    for (var matchId in _trackingTimers.keys.toList()) {
      stopTracking(matchId);
    }
  }
  
  void dispose() {
    stopAll();
  }
}

