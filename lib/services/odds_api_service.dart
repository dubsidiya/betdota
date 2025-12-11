import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/match.dart';

/// Сервис для получения данных о предстоящих и лайв матчах через Odds API
/// The Odds API предоставляет бесплатный план: https://the-odds-api.com/
class OddsApiService {
  // ВАЖНО: Получите бесплатный API ключ на https://the-odds-api.com/
  // Бесплатный план: 500 запросов/месяц
  static const String apiKey = 'd06946767fa71537937af90c68b7d32e'; // Замените на ваш ключ
  static const String baseUrl = 'https://api.the-odds-api.com/v4';

  /// Получить предстоящие матчи Dota 2
  /// Использует Odds API для получения расписания матчей от букмекеров
  Future<List<Match>> getUpcomingMatches() async {
    final List<Match> matches = [];

    // Метод 1: Попытка использовать Odds API (если есть ключ)
    if (apiKey != 'YOUR_API_KEY_HERE') {
      try {
        final oddsMatches = await _getMatchesFromOddsApi();
        matches.addAll(oddsMatches);
        if (oddsMatches.isNotEmpty) {
          debugPrint('Odds API: Загружено ${oddsMatches.length} предстоящих матчей');
        }
      } catch (e) {
        debugPrint('Odds API error: $e');
      }
    } else {
      debugPrint('Odds API: Ключ не установлен. Получите бесплатный ключ на https://the-odds-api.com/');
      debugPrint('См. инструкции в файле ODDS_API_SETUP.md');
    }

    // Метод 2: Парсинг публичных источников (резервный метод)
    try {
      final publicMatches = await _getMatchesFromPublicSources();
      matches.addAll(publicMatches);
    } catch (e) {
      debugPrint('Public sources error: $e');
    }

    // Удаляем дубликаты по matchId
    final uniqueMatches = <int, Match>{};
    for (var match in matches) {
      if (!uniqueMatches.containsKey(match.matchId)) {
        uniqueMatches[match.matchId] = match;
      }
    }

    return uniqueMatches.values.toList();
  }

  /// Получить лайв матчи через Odds API
  Future<List<Match>> getLiveMatches() async {
    final List<Match> matches = [];

    if (apiKey != 'YOUR_API_KEY_HERE') {
      // Пробуем разные варианты ключей
      final sportKeys = ['esports_dota2', 'dota2', 'dota_2'];
      
      for (final sportKey in sportKeys) {
        try {
          final response = await http.get(
            Uri.parse('$baseUrl/sports/$sportKey/odds?apiKey=$apiKey&live=true&regions=us,uk,au&markets=h2h'),
          ).timeout(const Duration(seconds: 15));

          if (response.statusCode == 200) {
            final List<dynamic> data = json.decode(response.body);
            for (var item in data) {
              final match = _parseOddsApiMatch(item);
              if (match != null) {
                matches.add(match);
              }
            }
            debugPrint('Odds API: Получено ${matches.length} лайв матчей (ключ: $sportKey)');
            return matches; // Успешно получили данные
          } else if (response.statusCode == 404) {
            // Спорт не найден, пробуем следующий
            continue;
          } else if (response.statusCode == 401) {
            debugPrint('Odds API: Неверный API ключ для лайв матчей');
            break;
          } else if (response.statusCode == 429) {
            debugPrint('Odds API: Превышен лимит запросов для лайв матчей');
            break;
          } else {
            debugPrint('Odds API live matches: Ошибка ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Odds API live matches error ($sportKey): $e');
        }
      }
      
      if (matches.isEmpty) {
        debugPrint('Odds API: Dota 2 лайв матчи не поддерживаются. Используем альтернативные методы.');
      }
    }

    return matches;
  }

  /// Получить список доступных спортов (для отладки)
  Future<void> _checkAvailableSports() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/sports?apiKey=$apiKey'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> sports = json.decode(response.body);
        debugPrint('Доступные спорты в Odds API:');
        for (var sport in sports) {
          final key = sport['key'];
          final title = sport['title'];
          debugPrint('  - $key: $title');
        }
      }
    } catch (e) {
      debugPrint('Error checking sports: $e');
    }
  }

  // Флаг для проверки спортов (один раз)
  static bool _sportsChecked = false;

  /// Получить матчи из Odds API
  Future<List<Match>> _getMatchesFromOddsApi() async {
    // Сначала проверим доступные спорты (только один раз)
    if (!_sportsChecked) {
      await _checkAvailableSports();
      _sportsChecked = true;
    }

    // К сожалению, Odds API не поддерживает Dota 2 напрямую
    // Попробуем использовать общий ключ esports или другие варианты
    final sportKeys = ['esports_dota2', 'dota2', 'dota_2'];
    
    for (final sportKey in sportKeys) {
      try {
        // Используем несколько регионов для получения большего количества матчей
        final response = await http.get(
          Uri.parse('$baseUrl/sports/$sportKey/odds?apiKey=$apiKey&regions=us,uk,au&markets=h2h'),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          final List<Match> matches = [];

          for (var item in data) {
            final match = _parseOddsApiMatch(item);
            if (match != null) {
              matches.add(match);
            }
          }

          debugPrint('Odds API: Получено ${matches.length} матчей из ${data.length} записей (ключ: $sportKey)');
          return matches;
        } else if (response.statusCode == 404) {
          // Спорт не найден, пробуем следующий ключ
          debugPrint('Odds API: Спорт "$sportKey" не найден, пробуем следующий...');
          continue;
        } else if (response.statusCode == 401) {
          debugPrint('Odds API: Неверный API ключ. Проверьте ключ на https://the-odds-api.com/');
          debugPrint('Response: ${response.body}');
          break;
        } else if (response.statusCode == 429) {
          debugPrint('Odds API: Превышен лимит запросов. Бесплатный план: 500 запросов/месяц');
          break;
        } else {
          debugPrint('Odds API: Ошибка ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('Error fetching from Odds API ($sportKey): $e');
      }
    }

    debugPrint('Odds API: Dota 2 не поддерживается напрямую. Используем альтернативные методы.');
    return [];
  }

  /// Парсинг матча из Odds API формата
  Match? _parseOddsApiMatch(Map<String, dynamic> json) {
    try {
      final homeTeam = json['home_team']?.toString() ?? '';
      final awayTeam = json['away_team']?.toString() ?? '';
      final commenceTime = json['commence_time']?.toString();
      final sportTitle = json['sport_title']?.toString() ?? 'Dota 2';

      if (homeTeam.isEmpty || awayTeam.isEmpty) return null;

      // Парсим время начала
      int? startTime;
      if (commenceTime != null) {
        try {
          final dateTime = DateTime.parse(commenceTime);
          startTime = dateTime.millisecondsSinceEpoch ~/ 1000;
        } catch (e) {
          debugPrint('Error parsing commence_time: $e');
        }
      }

      // Генерируем уникальный ID на основе команд и времени
      final matchId = (homeTeam + awayTeam + (startTime?.toString() ?? '')).hashCode.abs();

      return Match(
        matchId: matchId,
        radiantTeamName: homeTeam,
        direTeamName: awayTeam,
        startTime: startTime,
        leagueName: sportTitle,
      );
    } catch (e) {
      debugPrint('Error parsing Odds API match: $e');
      return null;
    }
  }

  /// Получить матчи из публичных источников (резервный метод)
  /// Использует парсинг публичных данных
  Future<List<Match>> _getMatchesFromPublicSources() async {
    final List<Match> matches = [];

    // Метод 1: Парсинг данных из Liquipedia через их API (если доступен)
    try {
      final liquipediaMatches = await _getMatchesFromLiquipedia();
      matches.addAll(liquipediaMatches);
    } catch (e) {
      debugPrint('Liquipedia error: $e');
    }

    // Метод 2: Использование данных из OpenDota о будущих матчах в лигах
    try {
      final leagueMatches = await getUpcomingFromLeagues();
      matches.addAll(leagueMatches);
    } catch (e) {
      debugPrint('League matches error: $e');
    }

    return matches;
  }

  /// Получить предстоящие матчи из лиг OpenDota
  Future<List<Match>> getUpcomingFromLeagues() async {
    final List<Match> matches = [];
    
    try {
      // Получаем список активных лиг
      final response = await http.get(
        Uri.parse('https://api.opendota.com/api/leagues?tier=premium'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> leagues = json.decode(response.body);
        
        // Берем первые 5 активных лиг
        for (var league in leagues.take(5)) {
          final leagueId = league['leagueid'];
          if (leagueId != null) {
            try {
              // Получаем матчи лиги
              final matchesResponse = await http.get(
                Uri.parse('https://api.opendota.com/api/leagues/$leagueId/matches?limit=10'),
              ).timeout(const Duration(seconds: 10));

              if (matchesResponse.statusCode == 200) {
                final List<dynamic> leagueMatches = json.decode(matchesResponse.body);
                final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

                for (var matchData in leagueMatches) {
                  final startTime = matchData['start_time'];
                  if (startTime != null && startTime is int) {
                    // Если матч в будущем (в течение недели)
                    if (startTime > now && (startTime - now) < 604800) {
                      final match = Match.fromJson(matchData);
                      if (!match.isFinished) {
                        matches.add(match);
                      }
                    }
                  }
                }
              }
            } catch (e) {
              debugPrint('Error fetching league $leagueId matches: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching leagues: $e');
    }

    return matches;
  }

  /// Получить матчи из Liquipedia (если доступен API)
  Future<List<Match>> _getMatchesFromLiquipedia() async {
    // Liquipedia не предоставляет публичный API
    // Можно было бы парсить HTML, но это нарушает их ToS
    // Поэтому возвращаем пустой список
    return [];
  }
}

