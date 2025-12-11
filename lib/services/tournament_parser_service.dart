import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/match.dart';

/// Сервис для парсинга данных о предстоящих и лайв матчах с сайтов турниров
/// Использует веб-скрапинг публичных источников
class TournamentParserService {
  
  /// Получить предстоящие матчи через парсинг сайтов (оптимизированная версия с параллельной обработкой)
  Future<List<Match>> getUpcomingMatches() async {
    final List<Match> allMatches = [];
    
    // Параллельная обработка всех источников для ускорения
    final results = await Future.wait([
      _parseDota2Su().catchError((e) {
        debugPrint('TournamentParser Dota2.su error: $e');
        return <Match>[];
      }),
      _parseLiquipedia().catchError((e) {
        debugPrint('TournamentParser Liquipedia error: $e');
        return <Match>[];
      }),
      _parseEsportsSites().catchError((e) {
        debugPrint('TournamentParser esports sites error: $e');
        return <Match>[];
      }),
      _parseOtherSources().catchError((e) {
        debugPrint('TournamentParser other sources error: $e');
        return <Match>[];
      }),
    ], eagerError: false);
    
    // Объединяем результаты
    for (var matches in results) {
      allMatches.addAll(matches);
    }
    
    // Удаляем дубликаты
    final uniqueMatches = <int, Match>{};
    for (var match in allMatches) {
      if (!uniqueMatches.containsKey(match.matchId)) {
        uniqueMatches[match.matchId] = match;
      }
    }
    
    debugPrint('TournamentParser: Всего найдено ${uniqueMatches.length} уникальных предстоящих матчей');
    return uniqueMatches.values.toList();
  }
  
  /// Получить лайв матчи через парсинг сайтов (оптимизированная версия)
  Future<List<Match>> getLiveMatches() async {
    // Используем только быстрый метод - проверка недавних матчей из OpenDota
    try {
      final liveMatches = await _parseLiveFromDota2Su();
      debugPrint('TournamentParser: Получено ${liveMatches.length} лайв матчей');
      return liveMatches;
    } catch (e) {
      debugPrint('TournamentParser live matches error: $e');
      return [];
    }
  }
  
  /// Парсинг Dota2.su для получения предстоящих матчей (оптимизированная версия)
  Future<List<Match>> _parseDota2Su() async {
    // Пробуем только главную страницу матчей для скорости
    try {
      final response = await http.get(
        Uri.parse('https://dota2.su/matches/'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 5)); // Уменьшен таймаут
      
      if (response.statusCode == 200) {
        final html = response.body;
        final matches = _parseDota2SuHtml(html);
        debugPrint('TournamentParser: Найдено ${matches.length} матчей на Dota2.su');
        return matches;
      }
    } catch (e) {
      debugPrint('Error parsing Dota2.su: $e');
    }
    
    return [];
  }
  
  /// Парсинг HTML Dota2.su (агрессивный метод)
  List<Match> _parseDota2SuHtml(String html) {
    final List<Match> matches = [];
    
    try {
      // Метод 1: Ищем JSON данные встроенные в HTML (многие сайты используют это)
      final jsonPattern = RegExp(r'<script[^>]*type="application/json"[^>]*>(.*?)</script>', dotAll: true);
      final jsonMatches = jsonPattern.allMatches(html);
      
      for (var jsonMatch in jsonMatches) {
        try {
          final jsonStr = jsonMatch.group(1)?.trim();
          if (jsonStr != null && jsonStr.isNotEmpty) {
            final data = jsonDecode(jsonStr);
            final parsed = _extractMatchesFromJson(data);
            matches.addAll(parsed);
          }
        } catch (e) {
          // Не JSON, продолжаем
        }
      }
      
      // Метод 2: Ищем данные в data-атрибутах
      final dataAttrPattern = RegExp(r'data-match[^=]*="([^"]+)"', caseSensitive: false);
      final dataMatches = dataAttrPattern.allMatches(html);
      
      for (var dataMatch in dataMatches) {
        try {
          final dataStr = dataMatch.group(1);
          if (dataStr != null) {
            final data = jsonDecode(dataStr);
            final parsed = _extractMatchesFromJson(data);
            matches.addAll(parsed);
          }
        } catch (e) {
          // Не JSON, продолжаем
        }
      }
      
      // Метод 3: Классический парсинг HTML через регулярные выражения
      // Ищем различные паттерны блоков с матчами
      final matchPatterns = [
        RegExp(r'<div[^>]*class="[^"]*match[^"]*"[^>]*>.*?</div>', dotAll: true),
        RegExp(r'<tr[^>]*class="[^"]*match[^"]*"[^>]*>.*?</tr>', dotAll: true),
        RegExp(r'<li[^>]*class="[^"]*match[^"]*"[^>]*>.*?</li>', dotAll: true),
      ];
      
      for (var pattern in matchPatterns) {
        final matchesHtml = pattern.allMatches(html);
        
        for (var matchHtml in matchesHtml) {
          final matchHtmlStr = matchHtml.group(0) ?? '';
          
          // Извлекаем названия команд (различные паттерны)
          final teamPatterns = [
            RegExp(r'<[^>]*class="[^"]*team[^"]*"[^>]*>([^<]+)</', caseSensitive: false),
            RegExp(r'<a[^>]*title="([^"]+)"[^>]*>', caseSensitive: false),
            RegExp(r'data-team="([^"]+)"', caseSensitive: false),
            RegExp(r'>([A-Z][A-Za-z0-9\s]{2,20})<', caseSensitive: false),
          ];
          
          List<String> teams = [];
          for (var teamPattern in teamPatterns) {
            final teamMatches = teamPattern.allMatches(matchHtmlStr);
            for (var teamMatch in teamMatches) {
              final team = teamMatch.group(1)?.trim() ?? '';
              if (team.isNotEmpty && 
                  team.length > 2 && 
                  team.length < 30 &&
                  !team.contains('<') &&
                  !team.contains('>') &&
                  !team.toLowerCase().contains('vs') &&
                  !team.toLowerCase().contains('match')) {
                teams.add(team);
              }
            }
            if (teams.length >= 2) break;
          }
          
          if (teams.length >= 2) {
            final team1 = teams[0];
            final team2 = teams[1];
            
            // Извлекаем время начала (различные форматы)
            int? startTime;
            final timePatterns = [
              RegExp(r'(\d{1,2})[.:](\d{2})\s*(\d{1,2})[./](\d{1,2})[./](\d{4})'),
              RegExp(r'(\d{4})-(\d{2})-(\d{2})[T\s](\d{2}):(\d{2})'),
              RegExp(r'data-time="(\d+)"', caseSensitive: false),
              RegExp(r'timestamp[=:](\d+)', caseSensitive: false),
            ];
            
            for (var timePattern in timePatterns) {
              final timeMatch = timePattern.firstMatch(matchHtmlStr);
              if (timeMatch != null) {
                try {
                  if (timeMatch.groupCount == 1) {
                    // Это timestamp
                    final parsedTime = int.parse(timeMatch.group(1) ?? '0');
                    if (parsedTime > 1000000000 && parsedTime < 2000000000) {
                      startTime = parsedTime;
                      break; // Валидный timestamp
                    }
                  } else {
                    // Это дата/время
                    final parts = List.generate(timeMatch.groupCount, (i) => timeMatch.group(i + 1) ?? '0');
                    if (parts.length >= 5) {
                      DateTime dateTime;
                      if (parts[0].length == 4) {
                        // Формат YYYY-MM-DD HH:MM
                        dateTime = DateTime(
                          int.parse(parts[0]),
                          int.parse(parts[1]),
                          int.parse(parts[2]),
                          int.parse(parts[3]),
                          int.parse(parts[4]),
                        );
                      } else {
                        // Формат DD.MM.YYYY HH:MM
                        dateTime = DateTime(
                          int.parse(parts[4]),
                          int.parse(parts[3]),
                          int.parse(parts[2]),
                          int.parse(parts[0]),
                          int.parse(parts[1]),
                        );
                      }
                      startTime = dateTime.millisecondsSinceEpoch ~/ 1000;
                      break;
                    }
                  }
                } catch (e) {
                  // Пробуем следующий паттерн
                }
              }
            }
            
            // Если время не найдено, но матч в будущем (по контексту страницы)
            if (startTime == null) {
              // Устанавливаем время на ближайшие часы как fallback
              final now = DateTime.now();
              startTime = now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
            }
            
            if (team1.isNotEmpty && team2.isNotEmpty && 
                team1 != team2 &&
                team1.length > 1 && team2.length > 1) {
              final matchId = (team1 + team2 + startTime.toString()).hashCode.abs();
              
              matches.add(Match(
                matchId: matchId,
                radiantTeamName: team1,
                direTeamName: team2,
                startTime: startTime,
                leagueName: 'Dota 2 Tournament',
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing Dota2.su HTML: $e');
    }
    
    return matches;
  }
  
  /// Извлечение матчей из JSON структуры
  List<Match> _extractMatchesFromJson(dynamic data) {
    final List<Match> matches = [];
    
    try {
      if (data is Map) {
        // Ищем массивы матчей
        for (var key in data.keys) {
          if (key.toString().toLowerCase().contains('match')) {
            final matchData = data[key];
            if (matchData is List) {
              for (var match in matchData) {
                final parsed = _parseMatchFromJson(match);
                if (parsed != null) matches.add(parsed);
              }
            } else if (matchData is Map) {
              final parsed = _parseMatchFromJson(matchData);
              if (parsed != null) matches.add(parsed);
            }
          }
        }
        
        // Рекурсивно ищем вложенные структуры
        for (var value in data.values) {
          if (value is Map || value is List) {
            matches.addAll(_extractMatchesFromJson(value));
          }
        }
      } else if (data is List) {
        for (var item in data) {
          if (item is Map || item is List) {
            matches.addAll(_extractMatchesFromJson(item));
          }
        }
      }
    } catch (e) {
      debugPrint('Error extracting matches from JSON: $e');
    }
    
    return matches;
  }
  
  /// Парсинг одного матча из JSON
  Match? _parseMatchFromJson(dynamic data) {
    try {
      if (data is! Map) return null;
      
      final team1 = data['team1'] ?? 
                   data['radiant'] ?? 
                   data['radiant_team'] ?? 
                   data['home_team'] ?? 
                   data['team_a'] ?? '';
      final team2 = data['team2'] ?? 
                   data['dire'] ?? 
                   data['dire_team'] ?? 
                   data['away_team'] ?? 
                   data['team_b'] ?? '';
      
      String team1Name = '';
      String team2Name = '';
      
      if (team1 is String) {
        team1Name = team1;
      } else if (team1 is Map) {
        team1Name = team1['name'] ?? team1['title'] ?? '';
      }
      
      if (team2 is String) {
        team2Name = team2;
      } else if (team2 is Map) {
        team2Name = team2['name'] ?? team2['title'] ?? '';
      }
      
      int? startTime;
      if (data['start_time'] != null) {
        startTime = data['start_time'] is int 
            ? data['start_time'] 
            : int.tryParse(data['start_time'].toString());
      } else if (data['timestamp'] != null) {
        startTime = data['timestamp'] is int 
            ? data['timestamp'] 
            : int.tryParse(data['timestamp'].toString());
      } else if (data['date'] != null) {
        // Парсим дату
        try {
          final dateStr = data['date'].toString();
          final dateTime = DateTime.parse(dateStr);
          startTime = dateTime.millisecondsSinceEpoch ~/ 1000;
        } catch (e) {
          // Игнорируем ошибки парсинга даты
        }
      }
      
      if (team1Name.isNotEmpty && team2Name.isNotEmpty && team1Name != team2Name) {
        final matchId = data['match_id'] ?? 
                       data['id'] ?? 
                       (team1Name + team2Name + (startTime?.toString() ?? '')).hashCode.abs();
        
        return Match(
          matchId: matchId is int ? matchId : matchId.toString().hashCode.abs(),
          radiantTeamName: team1Name,
          direTeamName: team2Name,
          startTime: startTime,
          leagueName: data['league'] ?? data['tournament'] ?? 'Tournament',
        );
      }
    } catch (e) {
      debugPrint('Error parsing match from JSON: $e');
    }
    
    return null;
  }
  
  /// Парсинг Liquipedia
  Future<List<Match>> _parseLiquipedia() async {
    // Liquipedia имеет API, но он ограничен
    // Используем парсинг HTML как альтернативу
    try {
      final response = await http.get(
        Uri.parse('https://liquipedia.net/dota2/Liquipedia:Upcoming_and_ongoing_matches'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        return _parseLiquipediaHtml(response.body);
      }
    } catch (e) {
      debugPrint('Error parsing Liquipedia: $e');
    }
    
    return [];
  }
  
  /// Парсинг HTML Liquipedia
  List<Match> _parseLiquipediaHtml(String html) {
    final List<Match> matches = [];
    
    try {
      // Парсим таблицы матчей из Liquipedia
      final tablePattern = RegExp(
        r'<table[^>]*class="[^"]*wikitable[^"]*"[^>]*>.*?</table>',
        dotAll: true,
      );
      
      final tables = tablePattern.allMatches(html);
      
      for (var table in tables) {
        final tableHtml = table.group(0) ?? '';
        
        // Ищем строки с матчами
        final rowPattern = RegExp(r'<tr[^>]*>.*?</tr>', dotAll: true);
        final rows = rowPattern.allMatches(tableHtml);
        
        for (var row in rows) {
          final rowHtml = row.group(0) ?? '';
          
          // Извлекаем команды
          final teamPattern = RegExp(r'<a[^>]*title="([^"]+)"[^>]*>');
          final teams = teamPattern.allMatches(rowHtml);
          
          if (teams.length >= 2) {
            final team1 = teams.elementAt(0).group(1)?.trim() ?? '';
            final team2 = teams.elementAt(1).group(1)?.trim() ?? '';
            
            // Извлекаем время
            final timePattern = RegExp(r'(\d{4})-(\d{2})-(\d{2})[T\s](\d{2}):(\d{2})');
            final timeMatch = timePattern.firstMatch(rowHtml);
            
            int? startTime;
            if (timeMatch != null) {
              try {
                final year = int.parse(timeMatch.group(1) ?? '2024');
                final month = int.parse(timeMatch.group(2) ?? '1');
                final day = int.parse(timeMatch.group(3) ?? '1');
                final hour = int.parse(timeMatch.group(4) ?? '0');
                final minute = int.parse(timeMatch.group(5) ?? '0');
                
                final dateTime = DateTime(year, month, day, hour, minute);
                startTime = dateTime.millisecondsSinceEpoch ~/ 1000;
              } catch (e) {
                debugPrint('Error parsing Liquipedia time: $e');
              }
            }
            
            if (team1.isNotEmpty && team2.isNotEmpty) {
              final matchId = (team1 + team2 + (startTime?.toString() ?? '')).hashCode.abs();
              
              matches.add(Match(
                matchId: matchId,
                radiantTeamName: team1,
                direTeamName: team2,
                startTime: startTime,
                leagueName: 'Liquipedia',
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing Liquipedia HTML: $e');
    }
    
    return matches;
  }
  
  /// Парсинг специализированных esports сайтов (оптимизированная версия с параллельной обработкой)
  Future<List<Match>> _parseEsportsSites() async {
    // Параллельная обработка только самых надежных источников
    final results = await Future.wait([
      _parseBo3().catchError((e) {
        debugPrint('TournamentParser bo3 error: $e');
        return <Match>[];
      }),
      _parseDotabuff().catchError((e) {
        debugPrint('TournamentParser dotabuff error: $e');
        return <Match>[];
      }),
      _parseEscharts().catchError((e) {
        debugPrint('TournamentParser escharts error: $e');
        return <Match>[];
      }),
    ], eagerError: false);
    
    final List<Match> matches = [];
    for (var result in results) {
      matches.addAll(result);
    }
    
    return matches;
  }
  
  /// Парсинг huwk.bet (если доступен)
  Future<List<Match>> _parseHuwk() async {
    // Сайт недоступен, возвращаем пустой список
    return [];
  }
  
  /// Парсинг cyberscore.me (если доступен)
  Future<List<Match>> _parseCyberscore() async {
    // Сайт недоступен, возвращаем пустой список
    return [];
  }
  
  /// Парсинг bo3.gg (оптимизированная версия)
  Future<List<Match>> _parseBo3() async {
    try {
      final response = await http.get(
        Uri.parse('https://bo3.gg/ru/dota2'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 5)); // Уменьшен таймаут
      
      if (response.statusCode == 200) {
        final html = response.body;
        final parsed = _parseDota2SuHtml(html);
        return parsed.map((match) => Match(
          matchId: match.matchId,
          radiantTeamName: match.radiantTeamName,
          direTeamName: match.direTeamName,
          startTime: match.startTime,
          leagueName: 'Bo3.gg',
        )).toList();
      }
    } catch (e) {
      debugPrint('Error parsing bo3: $e');
    }
    
    return [];
  }
  
  /// Парсинг dotabuff.com (оптимизированная версия)
  Future<List<Match>> _parseDotabuff() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.dotabuff.com/esports/matches'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 5)); // Уменьшен таймаут
      
      if (response.statusCode == 200) {
        final html = response.body;
        final parsed = _parseDota2SuHtml(html);
        return parsed.map((match) => Match(
          matchId: match.matchId,
          radiantTeamName: match.radiantTeamName,
          direTeamName: match.direTeamName,
          startTime: match.startTime,
          leagueName: 'Dotabuff',
        )).toList();
      }
    } catch (e) {
      debugPrint('Error parsing dotabuff: $e');
    }
    
    return [];
  }
  
  /// Парсинг hawk.live
  Future<List<Match>> _parseHawkLive() async {
    final List<Match> matches = [];
    
    try {
      final urls = [
        'https://hawk.live/dota2',
        'https://www.hawk.live/dota2',
        'https://hawk.live/esports/dota2',
      ];
      
      for (var url in urls) {
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          ).timeout(const Duration(seconds: 15));
          
          if (response.statusCode == 200) {
            final html = response.body;
            final parsed = _parseDota2SuHtml(html);
            for (var match in parsed) {
              matches.add(Match(
                matchId: match.matchId,
                radiantTeamName: match.radiantTeamName,
                direTeamName: match.direTeamName,
                startTime: match.startTime,
                leagueName: 'Hawk.live',
              ));
            }
            if (parsed.isNotEmpty) break;
          }
        } catch (e) {
          debugPrint('Error parsing hawk.live URL $url: $e');
        }
      }
    } catch (e) {
      debugPrint('Error parsing hawk.live: $e');
    }
    
    return matches;
  }
  
  /// Парсинг escharts.com (оптимизированная версия)
  Future<List<Match>> _parseEscharts() async {
    try {
      final response = await http.get(
        Uri.parse('https://escharts.com/ru/upcoming-tournaments/dota2'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 5)); // Уменьшен таймаут
      
      if (response.statusCode == 200) {
        final html = response.body;
        final parsed = _parseDota2SuHtml(html);
        return parsed.map((match) => Match(
          matchId: match.matchId,
          radiantTeamName: match.radiantTeamName,
          direTeamName: match.direTeamName,
          startTime: match.startTime,
          leagueName: 'Esports Charts',
        )).toList();
      }
    } catch (e) {
      debugPrint('Error parsing escharts: $e');
    }
    
    return [];
  }
  
  /// Парсинг других esports сайтов (отключен для скорости)
  Future<List<Match>> _parseOtherEsportsSites() async {
    // Отключено для ускорения загрузки
    return [];
  }
  
  /// Парсинг trackdota.com
  Future<List<Match>> _parseTrackdota() async {
    final List<Match> matches = [];
    
    try {
      final urls = [
        'https://trackdota.com',
        'https://www.trackdota.com',
        'https://trackdota.com/matches',
      ];
      
      for (var url in urls) {
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          ).timeout(const Duration(seconds: 15));
          
          if (response.statusCode == 200) {
            final html = response.body;
            final parsed = _parseDota2SuHtml(html);
            for (var match in parsed) {
              matches.add(Match(
                matchId: match.matchId,
                radiantTeamName: match.radiantTeamName,
                direTeamName: match.direTeamName,
                startTime: match.startTime,
                leagueName: 'TrackDota',
              ));
            }
            if (parsed.isNotEmpty) break;
          }
        } catch (e) {
          debugPrint('Error parsing trackdota URL $url: $e');
        }
      }
    } catch (e) {
      debugPrint('Error parsing trackdota: $e');
    }
    
    return matches;
  }
  
  /// Парсинг vpgame.com
  Future<List<Match>> _parseVpgame() async {
    final List<Match> matches = [];
    
    try {
      final urls = [
        'https://vpgame.com/dota2',
        'https://www.vpgame.com/dota2',
        'https://vpgame.com/esports/dota2',
      ];
      
      for (var url in urls) {
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            },
          ).timeout(const Duration(seconds: 15));
          
          if (response.statusCode == 200) {
            final html = response.body;
            final parsed = _parseDota2SuHtml(html);
            for (var match in parsed) {
              matches.add(Match(
                matchId: match.matchId,
                radiantTeamName: match.radiantTeamName,
                direTeamName: match.direTeamName,
                startTime: match.startTime,
                leagueName: 'VPGame',
              ));
            }
            if (parsed.isNotEmpty) break;
          }
        } catch (e) {
          debugPrint('Error parsing vpgame URL $url: $e');
        }
      }
    } catch (e) {
      debugPrint('Error parsing vpgame: $e');
    }
    
    return matches;
  }
  
  /// Парсинг dotapredict.com
  Future<List<Match>> _parseDotapredict() async {
    final List<Match> matches = [];
    
    try {
      final urls = [
        'https://dotapredict.com/ru',
        'https://dotapredict.com',
        'https://www.dotapredict.com/ru',
      ];
      
      for (var url in urls) {
        try {
          final response = await http.get(
            Uri.parse(url),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
              'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8',
            },
          ).timeout(const Duration(seconds: 15));
          
          if (response.statusCode == 200) {
            final html = response.body;
            final parsed = _parseDota2SuHtml(html);
            for (var match in parsed) {
              matches.add(Match(
                matchId: match.matchId,
                radiantTeamName: match.radiantTeamName,
                direTeamName: match.direTeamName,
                startTime: match.startTime,
                leagueName: 'DotaPredict',
              ));
            }
            if (parsed.isNotEmpty) break;
          }
        } catch (e) {
          debugPrint('Error parsing dotapredict URL $url: $e');
        }
      }
    } catch (e) {
      debugPrint('Error parsing dotapredict: $e');
    }
    
    return matches;
  }
  
  /// Парсинг других источников
  Future<List<Match>> _parseOtherSources() async {
    final List<Match> matches = [];
    
    // Метод 1: Парсинг через OpenDota API (проверяем активные лиги)
    try {
      final openDotaMatches = await _parseOpenDotaUpcoming();
      matches.addAll(openDotaMatches);
      debugPrint('TournamentParser: Получено ${openDotaMatches.length} матчей через OpenDota');
    } catch (e) {
      debugPrint('TournamentParser OpenDota error: $e');
    }
    
    // Метод 2: Парсинг через API турниров (если доступны)
    try {
      final apiMatches = await _parseTournamentApis();
      matches.addAll(apiMatches);
      debugPrint('TournamentParser: Получено ${apiMatches.length} матчей через Tournament APIs');
    } catch (e) {
      debugPrint('TournamentParser Tournament APIs error: $e');
    }
    
    return matches;
  }
  
  /// Парсинг предстоящих матчей через OpenDota (агрессивный поиск)
  Future<List<Match>> _parseOpenDotaUpcoming() async {
    final List<Match> matches = [];
    
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final futureTime = now + (60 * 24 * 60 * 60); // 60 дней вперед
      
      // Метод 1: Прямой запрос к proMatches с фильтрацией (оптимизированная версия)
      try {
        await Future.delayed(const Duration(milliseconds: 500)); // Уменьшена задержка
        final proMatchesResponse = await http.get(
          Uri.parse('https://api.opendota.com/api/proMatches?limit=50'),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ).timeout(const Duration(seconds: 10)); // Уменьшен таймаут
        
        if (proMatchesResponse.statusCode == 429) {
          debugPrint('TournamentParser: Rate limit (429), ждем 5 секунд перед повтором');
          await Future.delayed(const Duration(seconds: 5));
          // Повторная попытка
          final retryResponse = await http.get(
            Uri.parse('https://api.opendota.com/api/proMatches?limit=50'),
            headers: {
              'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            },
          ).timeout(const Duration(seconds: 30));
          if (retryResponse.statusCode == 200) {
            final List<dynamic> proMatches = jsonDecode(retryResponse.body) as List<dynamic>;
            debugPrint('TournamentParser: Проверяем ${proMatches.length} pro матчей на предстоящие (после повтора)');
            
            for (var matchData in proMatches) {
              try {
                final startTime = matchData['start_time'] as int?;
                if (startTime != null && startTime > now && startTime <= futureTime) {
                  final radiantTeam = matchData['radiant_name'] ?? 'Radiant';
                  final direTeam = matchData['dire_name'] ?? 'Dire';
                  
                  if (radiantTeam != 'Radiant' && direTeam != 'Dire' && radiantTeam.isNotEmpty && direTeam.isNotEmpty) {
                    matches.add(Match(
                      matchId: matchData['match_id'] ?? 
                              (radiantTeam + direTeam + startTime.toString()).hashCode.abs(),
                      radiantTeamName: radiantTeam,
                      direTeamName: direTeam,
                      startTime: startTime,
                      leagueName: matchData['league_name'] ?? 'Tournament',
                    ));
                  }
                }
              } catch (e) {
                // Пропускаем
              }
            }
          }
        } else if (proMatchesResponse.statusCode == 200) {
          final List<dynamic> proMatches = jsonDecode(proMatchesResponse.body) as List<dynamic>;
          debugPrint('TournamentParser: Проверяем ${proMatches.length} pro матчей на предстоящие');
          
          for (var matchData in proMatches) {
            try {
              final startTime = matchData['start_time'] as int?;
              if (startTime != null && startTime > now && startTime <= futureTime) {
                final radiantTeam = matchData['radiant_name'] ?? 'Radiant';
                final direTeam = matchData['dire_name'] ?? 'Dire';
                
                if (radiantTeam != 'Radiant' && direTeam != 'Dire' && radiantTeam.isNotEmpty && direTeam.isNotEmpty) {
                  matches.add(Match(
                    matchId: matchData['match_id'] ?? 
                            (radiantTeam + direTeam + startTime.toString()).hashCode.abs(),
                    radiantTeamName: radiantTeam,
                    direTeamName: direTeam,
                    startTime: startTime,
                    leagueName: matchData['league_name'] ?? 'Tournament',
                  ));
                }
              }
            } catch (e) {
              // Пропускаем
            }
          }
        }
      } catch (e) {
        debugPrint('Error parsing proMatches: $e');
      }
      
      // Метод 2: Получаем список активных лиг и проверяем их матчи (оптимизированная версия - пропускаем для скорости)
      // Пропускаем проверку лиг, так как это занимает много времени
      // Можно включить позже если нужно больше матчей
      /*
      try {
        await Future.delayed(const Duration(milliseconds: 500));
        final leaguesResponse = await http.get(
          Uri.parse('https://api.opendota.com/api/leagues?tier=premium'),
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        ).timeout(const Duration(seconds: 10));
        
        if (leaguesResponse.statusCode == 429) {
          debugPrint('TournamentParser: Rate limit (429) при получении лиг, пропускаем');
          return matches;
        }
        
        if (leaguesResponse.statusCode == 200) {
          final List<dynamic> leagues = jsonDecode(leaguesResponse.body) as List<dynamic>;
          
          // Проверяем только топ-10 активных лиг для скорости
          final activeLeagues = leagues.take(10);
          
          debugPrint('TournamentParser: Проверяем ${activeLeagues.length} активных лиг');
          
          for (var league in activeLeagues) {
          try {
            final leagueId = league['leagueid'] ?? league['id'];
            if (leagueId == null) continue;
            
            final matchesResponse = await http.get(
              Uri.parse('https://api.opendota.com/api/leagues/$leagueId/matches?limit=200'),
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
              },
            ).timeout(const Duration(seconds: 10));
            
            if (matchesResponse.statusCode == 200) {
              final List<dynamic> leagueMatches = 
                  jsonDecode(matchesResponse.body) as List<dynamic>;
              
              for (var matchData in leagueMatches) {
                try {
                  final startTime = matchData['start_time'] as int?;
                  if (startTime != null && startTime > now && startTime <= futureTime) {
                    final radiantTeam = matchData['radiant_name'] ?? 
                                     matchData['radiant_team']?['name'] ?? 
                                     'Radiant';
                    final direTeam = matchData['dire_name'] ?? 
                                    matchData['dire_team']?['name'] ?? 
                                    'Dire';
                    
                    if (radiantTeam != 'Radiant' && direTeam != 'Dire' && 
                        radiantTeam.isNotEmpty && direTeam.isNotEmpty) {
                      final matchId = matchData['match_id'] ?? 
                                    (radiantTeam + direTeam + startTime.toString()).hashCode.abs();
                      
                      // Проверяем, нет ли уже такого матча
                      if (!matches.any((m) => m.matchId == matchId)) {
                        matches.add(Match(
                          matchId: matchId,
                          radiantTeamName: radiantTeam,
                          direTeamName: direTeam,
                          startTime: startTime,
                          leagueName: league['name'] ?? 'Tournament',
                        ));
                      }
                    }
                  }
                } catch (e) {
                  // Пропускаем некорректные матчи
                }
              }
            }
            
            // Уменьшена задержка для скорости
            await Future.delayed(const Duration(milliseconds: 200));
          } catch (e) {
            debugPrint('Error parsing league $league: $e');
          }
          }
        }
      } catch (e) {
        debugPrint('Error parsing leagues: $e');
      }
      */
      
      debugPrint('TournamentParser: Найдено ${matches.length} предстоящих матчей через OpenDota');
    } catch (e) {
      debugPrint('Error parsing OpenDota upcoming: $e');
    }
    
    return matches;
  }
  
  /// Парсинг через публичные API турниров
  Future<List<Match>> _parseTournamentApis() async {
    final List<Match> matches = [];
    
    // Попытка использовать различные публичные API
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final futureTime = now + (60 * 24 * 60 * 60); // 60 дней
    
    // Метод 1: Прямой запрос к publicMatches (иногда там есть будущие матчи)
    try {
      final response = await http.get(
        Uri.parse('https://api.opendota.com/api/publicMatches?mmr_ascending=5000&limit=1000'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 20));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        
        for (var matchData in data) {
          try {
            final startTime = matchData['start_time'] as int?;
            if (startTime != null && startTime > now && startTime <= futureTime) {
              // Для publicMatches команды могут быть не указаны, пропускаем
              final radiantTeam = matchData['radiant_name'];
              final direTeam = matchData['dire_name'];
              
              if (radiantTeam != null && direTeam != null && 
                  radiantTeam.isNotEmpty && direTeam.isNotEmpty) {
                matches.add(Match(
                  matchId: matchData['match_id'] ?? 
                          (radiantTeam + direTeam + startTime.toString()).hashCode.abs(),
                  radiantTeamName: radiantTeam,
                  direTeamName: direTeam,
                  startTime: startTime,
                  leagueName: 'Public Match',
                ));
              }
            }
          } catch (e) {
            // Пропускаем
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing publicMatches: $e');
    }
    
    // Метод 2: Попытка использовать другие источники через API
    // Можно добавить больше источников здесь
    
    return matches;
  }
  
  /// Парсинг лайв матчей с Dota2.su
  Future<List<Match>> _parseLiveFromDota2Su() async {
    final List<Match> liveMatches = [];
    
    try {
      // Метод 1: Парсинг HTML сайтов
      final response = await http.get(
        Uri.parse('https://dota2.su/matches/'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final html = response.body;
        
        // Ищем блоки с лайв матчами (обычно помечены как "live" или "ongoing")
        if (html.contains('live') || html.contains('ongoing') || html.contains('идет')) {
          final parsed = _parseDota2SuHtml(html);
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          
          for (var match in parsed) {
            // Если матч начался недавно (в последние 2 часа), считаем его лайв
            if (match.startTime != null) {
              final timeDiff = now - match.startTime!;
              if (timeDiff >= 0 && timeDiff < 7200) { // В течение 2 часов
                liveMatches.add(match);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing live matches from Dota2.su: $e');
    }
    
    // Метод 2: Проверяем недавние матчи из OpenDota, которые могут быть лайв (оптимизированная версия)
    try {
      await Future.delayed(const Duration(milliseconds: 500)); // Уменьшена задержка
      final response = await http.get(
        Uri.parse('https://api.opendota.com/api/proMatches?limit=50'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 10)); // Уменьшен таймаут
      
      if (response.statusCode == 429) {
        debugPrint('TournamentParser: Rate limit (429) при получении лайв матчей, пропускаем');
        return liveMatches;
      }
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        
        for (var matchData in data) {
          try {
            final startTime = matchData['start_time'] as int?;
            final duration = matchData['duration'] as int?;
            final radiantWin = matchData['radiant_win'];
            
            // Матч считается лайв, если:
            // 1. Нет результата (radiant_win == null)
            // 2. Начался недавно (в последние 2 часа)
            // 3. Длится меньше 2 часов
            if (startTime != null && radiantWin == null) {
              final timeDiff = now - startTime;
              if (timeDiff >= 0 && timeDiff < 7200) { // В течение 2 часов
                if (duration == null || duration < 7200) { // Длится меньше 2 часов
                  final radiantTeam = matchData['radiant_name'] ?? 'Radiant';
                  final direTeam = matchData['dire_name'] ?? 'Dire';
                  
                  if (radiantTeam != 'Radiant' && direTeam != 'Dire' && 
                      radiantTeam.isNotEmpty && direTeam.isNotEmpty) {
                    final matchId = matchData['match_id'] ?? 
                                  (radiantTeam + direTeam + startTime.toString()).hashCode.abs();
                    
                    if (!liveMatches.any((m) => m.matchId == matchId)) {
                      liveMatches.add(Match(
                        matchId: matchId,
                        radiantTeamName: radiantTeam,
                        direTeamName: direTeam,
                        startTime: startTime,
                        duration: duration,
                        leagueName: matchData['league_name'] ?? 'Live Match',
                      ));
                    }
                  }
                }
              }
            }
          } catch (e) {
            // Пропускаем
          }
        }
      }
    } catch (e) {
      debugPrint('Error parsing live matches from OpenDota: $e');
    }
    
    return liveMatches;
  }
}

