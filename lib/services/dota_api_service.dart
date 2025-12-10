import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/match.dart';
import '../models/team_stats.dart';

class DotaApiService {
  static const String baseUrl = 'https://api.opendota.com/api';
  
  // Получить список профессиональных матчей
  Future<List<Match>> getProMatches({int? limit = 50}) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/proMatches?limit=$limit'),
      );

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

  // Получить детали матча
  Future<Match> getMatchDetails(int matchId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/matches/$matchId'),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return Match.fromJson(data);
      } else {
        throw Exception('Failed to load match details: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching match details: $e');
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
}

