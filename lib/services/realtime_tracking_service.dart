import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../models/live_match_data.dart';
import '../services/dota_api_service.dart';

/// Сервис для отслеживания матчей в реальном времени
/// Обновляет данные каждые 2-3 секунды и отслеживает изменения
class RealtimeTrackingService {
  final DotaApiService _apiService = DotaApiService();
  final Map<int, Timer> _trackingTimers = {};
  final Map<int, StreamController<LiveMatchData>> _matchStreams = {};
  final Map<int, LiveMatchData?> _lastData = {};
  
  /// Начать отслеживание матча в реальном времени
  /// Обновляет данные каждые 2 секунды
  Stream<LiveMatchData> trackMatch(int matchId) {
    if (_matchStreams.containsKey(matchId)) {
      return _matchStreams[matchId]!.stream;
    }
    
    final controller = StreamController<LiveMatchData>.broadcast();
    _matchStreams[matchId] = controller;
    
    // Немедленно получаем первые данные
    _updateMatchData(matchId, controller);
    
    // Затем обновляем каждые 2 секунды для реального времени
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
    _lastData.remove(matchId);
  }
  
  /// Остановить все отслеживания
  void stopAll() {
    for (var matchId in _trackingTimers.keys.toList()) {
      stopTracking(matchId);
    }
  }
  
  /// Обновить данные матча
  Future<void> _updateMatchData(int matchId, StreamController<LiveMatchData> controller) async {
    try {
      final liveData = await _apiService.getLiveMatchData(matchId);
      
      if (liveData != null) {
        // Проверяем, изменились ли данные
        final lastData = _lastData[matchId];
        if (lastData == null || _hasDataChanged(lastData, liveData)) {
          _lastData[matchId] = liveData;
          controller.add(liveData);
          debugPrint('RealtimeTracking: Обновлены данные матча $matchId');
        }
      }
    } catch (e) {
      debugPrint('RealtimeTracking: Ошибка обновления матча $matchId: $e');
    }
  }
  
  /// Проверить, изменились ли данные
  bool _hasDataChanged(LiveMatchData oldData, LiveMatchData newData) {
    return oldData.radiantScore != newData.radiantScore ||
           oldData.direScore != newData.direScore ||
           oldData.radiantNetWorth != newData.radiantNetWorth ||
           oldData.direNetWorth != newData.direNetWorth ||
           oldData.radiantKills != newData.radiantKills ||
           oldData.direKills != newData.direKills ||
           oldData.duration != newData.duration;
  }
  
  /// Получить последние данные матча
  LiveMatchData? getLastData(int matchId) {
    return _lastData[matchId];
  }
}

