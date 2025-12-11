import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../services/dota_api_service.dart';

class MatchesProvider with ChangeNotifier {
  final DotaApiService _apiService = DotaApiService();
  
  bool _isLoading = false;
  String? _error;
  Match? _selectedMatch;

  // Отдельные списки матчей по статусу
  List<Match> _finishedMatches = [];
  List<Match> _liveMatches = [];
  List<Match> _upcomingMatches = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  Match? get selectedMatch => _selectedMatch;

  List<Match> get finishedMatches => _finishedMatches;
  List<Match> get liveMatches => _liveMatches;
  List<Match> get upcomingMatches => _upcomingMatches;
  
  // Объединенный список для обратной совместимости
  List<Match> get matches => [..._finishedMatches, ..._liveMatches, ..._upcomingMatches];

  Future<void> loadMatches({int limit = 50}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Загружаем завершенные матчи из OpenDota
      _finishedMatches = await _apiService.getProMatches(limit: limit);
      
      // Загружаем лайв матчи
      try {
        _liveMatches = await _apiService.getLiveMatches();
      } catch (e) {
        debugPrint('Error loading live matches: $e');
        _liveMatches = [];
      }
      
      // Загружаем предстоящие матчи
      try {
        _upcomingMatches = await _apiService.getUpcomingMatches();
      } catch (e) {
        debugPrint('Error loading upcoming matches: $e');
        _upcomingMatches = [];
      }
      
      _error = null;
    } catch (e) {
      _error = e.toString();
      _finishedMatches = [];
      _liveMatches = [];
      _upcomingMatches = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Загрузка только завершенных матчей
  Future<void> loadFinishedMatches({int limit = 50}) async {
    try {
      _finishedMatches = await _apiService.getProMatches(limit: limit);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading finished matches: $e');
    }
  }

  // Загрузка только лайв матчей
  Future<void> loadLiveMatches() async {
    try {
      _liveMatches = await _apiService.getLiveMatches();
      
      // Если лайв матчей нет, попробуем показать недавние матчи как потенциально лайв
      if (_liveMatches.isEmpty) {
        try {
          final recentMatches = await _apiService.getProMatches(limit: 50);
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          
          // Показываем матчи, которые начались в последние 2 часа и еще не завершены
          final potentialLive = recentMatches.where((match) {
            if (match.startTime == null || match.radiantWin != null) return false;
            final timeDiff = now - match.startTime!;
            return timeDiff >= 0 && timeDiff < 7200; // В течение 2 часов
          }).take(10).toList();
          
          if (potentialLive.isNotEmpty) {
            debugPrint('MatchesProvider: Найдено ${potentialLive.length} потенциально лайв матчей из недавних');
            _liveMatches = potentialLive;
          }
        } catch (e) {
          debugPrint('Error loading potential live matches: $e');
        }
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading live matches: $e');
      _liveMatches = [];
      notifyListeners();
    }
  }

  // Загрузка только предстоящих матчей
  Future<void> loadUpcomingMatches() async {
    try {
      _upcomingMatches = await _apiService.getUpcomingMatches();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading upcoming matches: $e');
    }
  }

  Future<void> loadMatchDetails(int matchId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _selectedMatch = await _apiService.getMatchDetails(matchId);
      _error = null;
    } catch (e) {
      _error = 'Ошибка загрузки деталей матча: ${e.toString()}';
      _selectedMatch = null;
      debugPrint('Error loading match details: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearSelectedMatch() {
    _selectedMatch = null;
    notifyListeners();
  }
}

