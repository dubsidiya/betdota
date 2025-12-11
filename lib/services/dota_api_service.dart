import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/match.dart';
import '../models/team_stats.dart';
import '../models/draft.dart';
import '../models/odds.dart';
import '../models/live_match_data.dart';
import 'odds_api_service.dart';
import 'steam_api_service.dart';
import 'tournament_parser_service.dart';

class DotaApiService {
  static const String baseUrl = 'https://api.opendota.com/api';
  
  // Получить список профессиональных матчей (только завершенные)
  Future<List<Match>> getProMatches({int? limit = 50}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/proMatches?limit=$limit'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Match.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load pro matches: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching pro matches: $e');
    }
  }

  // Получить лайв матчи
  Future<List<Match>> getLiveMatches() async {
    final List<Match> allMatches = [];

    // Метод 1: Парсинг сайтов турниров (самый надежный способ)
    try {
      final parserService = TournamentParserService();
      final parsedMatches = await parserService.getLiveMatches();
      if (parsedMatches.isNotEmpty) {
        allMatches.addAll(parsedMatches);
        debugPrint('TournamentParser: Получено ${parsedMatches.length} лайв матчей через парсинг');
      }
    } catch (e) {
      debugPrint('TournamentParser live matches error: $e');
    }

    // Метод 2: Используем Steam API (официальный источник)
    if (allMatches.isEmpty) {
      try {
        final steamService = SteamApiService();
        final steamMatches = await steamService.getLiveLeagueGames();
        if (steamMatches.isNotEmpty) {
          allMatches.addAll(steamMatches);
          debugPrint('Steam API: Получено ${steamMatches.length} лайв матчей');
        }
      } catch (e) {
        debugPrint('Steam API live matches error: $e');
      }
    }

    // Метод 3: Используем OddsApiService (если поддерживает)
    if (allMatches.isEmpty) {
      try {
        final oddsService = OddsApiService();
        final oddsMatches = await oddsService.getLiveMatches();
        if (oddsMatches.isNotEmpty) {
          allMatches.addAll(oddsMatches);
        }
      } catch (e) {
        debugPrint('Odds API live matches error: $e');
      }
    }

    // Метод 3: Альтернативный метод - проверяем недавние матчи, которые могут быть лайв
    if (allMatches.isEmpty) {
      try {
        final recentMatches = await getProMatches(limit: 100);
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        
        final potentialLiveMatches = recentMatches.where((match) {
          if (match.startTime == null || match.radiantWin != null) return false;
          final matchStart = match.startTime!;
          final matchEnd = match.duration != null ? matchStart + match.duration! : null;
          
          // Матч считается лайв, если начался и еще не закончился
          if (now >= matchStart) {
            if (matchEnd != null && now < matchEnd) return true;
            // Если нет данных о длительности, но матч начался недавно (в последние 2 часа)
            if (matchEnd == null && (now - matchStart) < 7200) return true;
          }
          return false;
        }).toList();
        
        allMatches.addAll(potentialLiveMatches);
      } catch (e) {
        debugPrint('Error getting live matches: $e');
      }
    }

    // Удаляем дубликаты по matchId
    final uniqueMatches = <int, Match>{};
    for (var match in allMatches) {
      if (!uniqueMatches.containsKey(match.matchId)) {
        uniqueMatches[match.matchId] = match;
      }
    }

    return uniqueMatches.values.toList();
  }

  // Получить предстоящие матчи
  Future<List<Match>> getUpcomingMatches() async {
    final List<Match> allMatches = [];

    // Метод 1: Парсинг сайтов турниров (самый надежный способ для предстоящих матчей)
    try {
      final parserService = TournamentParserService();
      final parsedMatches = await parserService.getUpcomingMatches();
      if (parsedMatches.isNotEmpty) {
        allMatches.addAll(parsedMatches);
        debugPrint('TournamentParser: Получено ${parsedMatches.length} предстоящих матчей через парсинг');
      }
    } catch (e) {
      debugPrint('TournamentParser upcoming matches error: $e');
    }

    // Метод 2: Используем Steam API (официальный источник)
    if (allMatches.isEmpty) {
      try {
        final steamService = SteamApiService();
        final steamMatches = await steamService.getScheduledLeagueGames();
        if (steamMatches.isNotEmpty) {
          allMatches.addAll(steamMatches);
          debugPrint('Steam API: Получено ${steamMatches.length} предстоящих матчей');
        }
      } catch (e) {
        debugPrint('Steam API upcoming matches error: $e');
      }
    }

    // Метод 3: Используем OddsApiService (если поддерживает)
    if (allMatches.isEmpty) {
      try {
        final oddsService = OddsApiService();
        final oddsMatches = await oddsService.getUpcomingMatches();
        if (oddsMatches.isNotEmpty) {
          allMatches.addAll(oddsMatches);
        }
      } catch (e) {
        debugPrint('Odds API upcoming matches error: $e');
      }
    }

    // Метод 3: Проверяем матчи из активных лиг OpenDota
    if (allMatches.isEmpty) {
      try {
        final oddsService = OddsApiService();
        final leagueMatches = await oddsService.getUpcomingFromLeagues();
        if (leagueMatches.isNotEmpty) {
          allMatches.addAll(leagueMatches);
        }
      } catch (e) {
        debugPrint('League matches error: $e');
      }
    }

    // Метод 4: Последний резерв - проверяем матчи с будущим временем начала
    // OpenDota API возвращает только завершенные матчи, но иногда есть матчи с будущим временем
    if (allMatches.isEmpty) {
      try {
        final recentMatches = await getProMatches(limit: 200);
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        
        debugPrint('DotaApiService: Проверяем ${recentMatches.length} недавних матчей на предстоящие');
        
        final upcomingFromRecent = recentMatches.where((match) {
          if (match.startTime == null || match.radiantWin != null) return false;
          final matchStart = match.startTime!;
          // Матч считается предстоящим, если время начала в будущем (расширяем до месяца)
          final isUpcoming = now < matchStart && (matchStart - now) < 2592000; // 30 дней
          if (isUpcoming) {
            debugPrint('DotaApiService: Найден предстоящий матч: ${match.radiantTeamName} vs ${match.direTeamName}, start_time: $matchStart, now: $now');
          }
          return isUpcoming;
        }).toList();
        
        if (upcomingFromRecent.isNotEmpty) {
          debugPrint('DotaApiService: Найдено ${upcomingFromRecent.length} предстоящих матчей из недавних');
        }
        
        allMatches.addAll(upcomingFromRecent);
      } catch (e) {
        debugPrint('Error getting upcoming matches: $e');
      }
    }

    // Удаляем дубликаты по matchId
    final uniqueMatches = <int, Match>{};
    for (var match in allMatches) {
      if (!uniqueMatches.containsKey(match.matchId)) {
        uniqueMatches[match.matchId] = match;
      }
    }

    return uniqueMatches.values.toList();
  }


  // Получить детали матча
  Future<Match> getMatchDetails(int matchId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/matches/$matchId'),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout: Превышено время ожидания ответа от сервера');
        },
      );

      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> data = json.decode(response.body);
          return Match.fromJson(data);
        } catch (e) {
          throw Exception('Ошибка парсинга данных матча: $e');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Матч не найден');
      } else {
        throw Exception('Ошибка загрузки матча: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('timeout')) {
        rethrow;
      }
      throw Exception('Ошибка получения деталей матча: $e');
    }
  }

  // Получить статистику команды
  Future<TeamStats?> getTeamStats(int teamId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teams/$teamId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Получаем последние матчи команды
        final matchesResponse = await http.get(
          Uri.parse('$baseUrl/teams/$teamId/matches?limit=10'),
        );
        
        List<RecentMatch> recentMatches = [];
        if (matchesResponse.statusCode == 200) {
          final List<dynamic> matchesData = json.decode(matchesResponse.body);
          recentMatches = matchesData
              .map((m) => RecentMatch.fromJson(m))
              .toList();
        }

        // Вычисляем средние значения из последних матчей
        double avgKills = 0;
        double avgDeaths = 0;
        double avgGpm = 0;
        
        if (recentMatches.isNotEmpty) {
          // Для упрощения используем данные из API или вычисляем из матчей
          // В реальном приложении нужно парсить детали каждого матча
        }

        return TeamStats(
          teamId: data['team_id'] ?? teamId,
          teamName: data['name'] ?? 'Unknown Team',
          teamLogo: data['logo_url'],
          wins: data['wins'] ?? 0,
          losses: data['losses'] ?? 0,
          winRate: 0, // Вычисляется в модели
          avgKills: avgKills,
          avgDeaths: avgDeaths,
          avgGpm: avgGpm,
          recentMatches: recentMatches,
        );
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Получить матчи команды
  Future<List<Match>> getTeamMatches(int teamId, {int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/teams/$teamId/matches?limit=$limit'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Match.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load team matches: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching team matches: $e');
    }
  }

  // Поиск матчей по лиге
  Future<List<Match>> getLeagueMatches(int leagueId, {int limit = 50}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/leagues/$leagueId/matches?limit=$limit'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Match.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load league matches: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching league matches: $e');
    }
  }

  // Получить драфт матча
  Future<Draft?> getMatchDraft(int matchId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/matches/$matchId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Проверяем наличие данных о драфте
        if (data['picks_bans'] != null || data['picksBans'] != null) {
          return Draft.fromJson(data);
        }
        
        return null;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Получить лайв-данные матча (для матчей в процессе)
  Future<LiveMatchData?> getLiveMatchData(int matchId) async {
    try {
      // Метод 1: Пробуем получить через OpenDota API
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/matches/$matchId'),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          
          // Проверяем, что матч еще идет (нет результата)
          if (data['radiant_win'] == null && data['radiantWin'] == null) {
            return LiveMatchData.fromJson(data);
          }
        }
      } catch (e) {
        debugPrint('DotaApiService: Ошибка получения live данных через OpenDota: $e');
      }
      
      // Метод 2: Пробуем получить через другие источники
      // Можно добавить парсинг сайтов с live данными
      
      return null;
    } catch (e) {
      debugPrint('DotaApiService: Ошибка получения live данных: $e');
      return null;
    }
  }

  // Получить коэффициенты (мок-данные, так как OpenDota не предоставляет коэффициенты)
  // В реальном приложении это должно приходить из другого API
  Future<Odds?> getMatchOdds(int matchId) async {
    try {
      // Мок-данные: в реальном приложении здесь должен быть запрос к API букмекеров
      // Для демонстрации возвращаем случайные коэффициенты
      final mockOdds = Odds(
        radiantOdds: 1.5 + (matchId % 10) * 0.1,
        direOdds: 2.5 - (matchId % 10) * 0.1,
        bookmaker: 'Mock Bookmaker',
      );
      
      return mockOdds;
    } catch (e) {
      return null;
    }
  }
}

