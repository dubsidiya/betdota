import 'package:flutter/foundation.dart';
import '../models/match.dart';
import '../services/dota_api_service.dart';

class MatchesProvider with ChangeNotifier {
  final DotaApiService _apiService = DotaApiService();
  
  List<Match> _matches = [];
  bool _isLoading = false;
  String? _error;
  Match? _selectedMatch;

  List<Match> get matches => _matches;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Match? get selectedMatch => _selectedMatch;

  Future<void> loadMatches({int limit = 50}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _matches = await _apiService.getProMatches(limit: limit);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _matches = [];
    } finally {
      _isLoading = false;
      notifyListeners();
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
      _error = e.toString();
      _selectedMatch = null;
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

