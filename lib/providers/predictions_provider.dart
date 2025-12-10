import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/prediction.dart';
import '../models/match.dart';
import '../services/prediction_service.dart';

class PredictionsProvider with ChangeNotifier {
  final PredictionService _predictionService = PredictionService();
  final String _storageKey = 'saved_predictions';
  
  List<Prediction> _predictions = [];
  bool _isLoading = false;
  String? _error;

  List<Prediction> get predictions => _predictions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  PredictionsProvider() {
    _loadPredictions();
  }

  Future<void> _loadPredictions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? predictionsJson = prefs.getString(_storageKey);
      
      if (predictionsJson != null) {
        final List<dynamic> decoded = json.decode(predictionsJson);
        _predictions = decoded.map((json) => Prediction.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<void> _savePredictions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = json.encode(
        _predictions.map((p) => p.toJson()).toList(),
      );
      await prefs.setString(_storageKey, encoded);
    } catch (e) {
      _error = e.toString();
    }
  }

  Future<Prediction> createPrediction(Match match) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final prediction = await _predictionService.analyzeMatch(match);
      _predictions.insert(0, prediction);
      await _savePredictions();
      _error = null;
      return prediction;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deletePrediction(String id) async {
    _predictions.removeWhere((p) => p.id == id);
    await _savePredictions();
    notifyListeners();
  }

  Future<void> updatePredictionResult(String id, bool wasCorrect) async {
    final index = _predictions.indexWhere((p) => p.id == id);
    if (index != -1) {
      final prediction = _predictions[index];
      _predictions[index] = Prediction(
        id: prediction.id,
        matchId: prediction.matchId,
        matchTitle: prediction.matchTitle,
        predictedWinner: prediction.predictedWinner,
        confidence: prediction.confidence,
        reasoning: prediction.reasoning,
        createdAt: prediction.createdAt,
        wasCorrect: wasCorrect,
        analysisData: prediction.analysisData,
      );
      await _savePredictions();
      notifyListeners();
    }
  }
}

