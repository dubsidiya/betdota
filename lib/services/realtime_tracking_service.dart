import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/match.dart';
import '../models/live_match_data.dart';

/// Сервис для реалтайм отслеживания матчей и анализа ситуации на карте
/// Использует различные источники для получения данных в реальном времени
class RealtimeTrackingService {
  final Map<int, StreamController<LiveMatchData>> _matchStreams = {};
  final Map<int, Timer> _matchTimers = {};
  
  /// Подключиться к реалтайм отслеживанию матча
  Stream<LiveMatchData> trackMatch(int matchId) {
    if (_matchStreams.containsKey(matchId)) {
      return _matchStreams[matchId]!.stream;
    }
    
    final controller = StreamController<LiveMatchData>.broadcast();
    _matchStreams[matchId] = controller;
    
    // Запускаем периодическое обновление данных
    _startTracking(matchId, controller);
    
    return controller.stream;
  }
  
  /// Остановить отслеживание матча
  void stopTracking(int matchId) {
    _matchTimers[matchId]?.cancel();
    _matchTimers.remove(matchId);
    _matchStreams[matchId]?.close();
    _matchStreams.remove(matchId);
  }
  
  /// Запуск отслеживания матча
  void _startTracking(int matchId, StreamController<LiveMatchData> controller) {
    // Обновляем данные каждые 2-3 секунды
    _matchTimers[matchId] = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final liveData = await _fetchLiveData(matchId);
        if (liveData != null) {
          controller.add(liveData);
        }
      } catch (e) {
        debugPrint('RealtimeTracking: Ошибка получения данных для матча $matchId: $e');
      }
    });
    
    // Первоначальная загрузка
    _fetchLiveData(matchId).then((data) {
      if (data != null) {
        controller.add(data);
      }
    });
  }
  
  /// Получение реалтайм данных матча
  Future<LiveMatchData?> _fetchLiveData(int matchId) async {
    // Метод 1: Пробуем получить через OpenDota (если матч еще идет)
    try {
      final response = await http.get(
        Uri.parse('https://api.opendota.com/api/matches/$matchId'),
      ).timeout(const Duration(seconds: 3));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Проверяем, что матч еще идет
        if (data['radiant_win'] == null) {
          return LiveMatchData.fromJson(data);
        }
      }
    } catch (e) {
      debugPrint('RealtimeTracking: OpenDota error для матча $matchId: $e');
    }
    
    // Метод 2: Пробуем получить через другие источники
    // Можно добавить парсинг сайтов с live данными
    
    return null;
  }
  
  /// Очистка всех подписок
  void dispose() {
    for (var timer in _matchTimers.values) {
      timer.cancel();
    }
    _matchTimers.clear();
    
    for (var controller in _matchStreams.values) {
      controller.close();
    }
    _matchStreams.clear();
  }
}
