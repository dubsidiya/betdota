import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/match.dart';

/// Сервис для получения данных о матчах через Steam Web API
/// Steam Web API - официальный API от Valve для Dota 2
class SteamApiService {
  // Steam Web API ключ (можно получить бесплатно на https://steamcommunity.com/dev/apikey)
  // ВАЖНО: Для некоторых методов Steam API ключ обязателен!
  // Получите ключ на https://steamcommunity.com/dev/apikey
  static const String apiKey = '409912BBEDE2D2C71C5BD59854FFE5D5';
  static const String baseUrl = 'https://api.steampowered.com';
  
  /// Получить лайв матчи из профессиональных лиг
  /// Использует GetLiveLeagueGames - возвращает матчи, которые идут прямо сейчас
  /// ВАЖНО: Требует Steam Web API ключ!
  Future<List<Match>> getLiveLeagueGames() async {
    // Проверяем наличие API ключа
    if (apiKey.isEmpty) {
      debugPrint('Steam API: API ключ не установлен. Получите ключ на https://steamcommunity.com/dev/apikey');
      debugPrint('Steam API: Без ключа метод GetLiveLeagueGames недоступен (403 Forbidden)');
      return [];
    }

    try {
      // Правильный формат Steam Web API для Dota 2
      // Метод требует API ключ для работы
      final url = '$baseUrl/IDOTA2Match_570/GetLiveLeagueGames/v0001/?key=$apiKey';
      
      final response = await http.get(
        Uri.parse(url),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // Steam API возвращает данные в protobuf формате
        try {
          final bytes = response.bodyBytes;
          debugPrint('Steam API GetLiveLeagueGames: Получен protobuf ответ, размер: ${bytes.length} байт');
          
          // Попытка базового декодирования protobuf без полной схемы
          // Используем простой парсинг для извлечения базовой информации
          final matches = _parseProtobufResponse(bytes);
          
          if (matches.isNotEmpty) {
            debugPrint('Steam API: Успешно декодировано ${matches.length} лайв матчей из protobuf');
            return matches;
          } else {
            debugPrint('Steam API: Не удалось извлечь матчи из protobuf ответа');
            debugPrint('Steam API: Для полного декодирования нужна схема (.proto файл)');
            debugPrint('Steam API: Используем альтернативные методы для получения лайв матчей');
            return [];
          }
        } catch (e) {
          debugPrint('Steam API GetLiveLeagueGames: Ошибка при обработке protobuf: $e');
          return [];
        }
      } else if (response.statusCode == 403) {
        debugPrint('Steam API GetLiveLeagueGames: 403 Forbidden');
        debugPrint('Возможные причины:');
        debugPrint('1. Неверный или отсутствующий API ключ');
        debugPrint('2. API ключ не имеет необходимых прав доступа');
        debugPrint('3. Превышен лимит запросов');
        debugPrint('Получите ключ на https://steamcommunity.com/dev/apikey');
        debugPrint('Response: ${response.body}');
      } else {
        debugPrint('Steam API GetLiveLeagueGames: Ошибка ${response.statusCode}');
        debugPrint('Response: ${response.body}');
      }
    } catch (e) {
      debugPrint('Steam API GetLiveLeagueGames error: $e');
    }

    return [];
  }

  /// Получить предстоящие матчи из лиг
  /// К сожалению, Steam API не предоставляет прямой метод для расписания
  /// Используем альтернативный подход через OpenDota API
  Future<List<Match>> getScheduledLeagueGames({int? leagueId, int? dateMin, int? dateMax}) async {
    // Steam API не имеет метода GetScheduledLeagueGames
    // Используем OpenDota API напрямую для получения предстоящих матчей
    debugPrint('Steam API: GetScheduledLeagueGames не доступен, используем OpenDota API');
    
    final List<Match> allMatches = [];
    
    try {
      // Метод 1: Попробуем получить лиги через Steam API
      final steamLeagues = await getLeagues();
      List<int> leagueIds = [];
      
      if (steamLeagues.isNotEmpty) {
        // Берем активные лиги (tier может быть числом или строкой)
        final activeLeagues = steamLeagues.where((league) {
          final tier = league['tier'];
          if (tier == null) return false;
          
          // Проверяем tier
          bool isProfessional = false;
          if (tier is int) {
            isProfessional = tier <= 2; // Только профессиональные лиги (tier 1-2)
          } else if (tier is String) {
            final tierLower = tier.toLowerCase();
            isProfessional = tierLower == 'professional' || 
                            tierLower == 'premium' || 
                            tierLower == '1' || 
                            tierLower == '2';
          }
          
          if (!isProfessional) return false;
          
          // Проверяем, что лига имеет недавние матчи (значит она активна)
          // Это косвенный признак того, что лига может иметь предстоящие матчи
          return true; // Пока берем все профессиональные лиги
        }).take(50).toList(); // Увеличиваем до 50 лиг для большего охвата
        
        leagueIds = activeLeagues
            .map((league) => league['leagueid'])
            .whereType<int>()
            .toList();
        
        debugPrint('Steam API: Найдено ${leagueIds.length} активных лиг через OpenDota API');
      }
      
      // Метод 2: Если лиги не получены, используем известные активные лиги
      // Берем самые актуальные лиги из недавних сезонов
      if (leagueIds.isEmpty) {
        debugPrint('Steam API: Используем известные активные лиги');
        // Актуальные лиги Dota 2 (2024-2025)
        // Используем более широкий диапазон ID лиг для поиска
        leagueIds = [];
        
        // Генерируем список потенциальных ID лиг для проверки
        // DPC лиги обычно имеют ID в диапазоне 16000-17000 для 2024-2025
        for (int i = 16000; i <= 16500; i += 10) {
          leagueIds.add(i);
        }
        
        debugPrint('Steam API: Сгенерировано ${leagueIds.length} потенциальных ID лиг для проверки');
      }
      
      debugPrint('Steam API: Проверяем ${leagueIds.length} лиг на наличие предстоящих матчей');
      debugPrint('Steam API: Список проверяемых лиг: ${leagueIds.take(10).join(", ")}');
      
      // Получаем матчи из каждой лиги через OpenDota
      // Пробуем получить самые свежие матчи (включая те, что могут быть в будущем)
      // Увеличиваем количество проверяемых лиг
      for (var leagueIdValue in leagueIds.take(20)) {
        try {
          // Используем сортировку по start_time DESC чтобы получить самые свежие матчи
          final response = await http.get(
            Uri.parse('https://api.opendota.com/api/leagues/$leagueIdValue/matches?limit=100&sort=start_time'),
          ).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final List<dynamic> leagueMatches = json.decode(response.body);
            final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            int foundInLeague = 0;
            int totalMatches = leagueMatches.length;
            int futureMatches = 0;
            int pastMatches = 0;

            debugPrint('Steam API: Лига $leagueIdValue - всего матчей: $totalMatches');

            for (var matchData in leagueMatches) {
              final startTime = matchData['start_time'];
              final radiantWin = matchData['radiant_win'];
              
              if (startTime != null && startTime is int) {
                if (startTime > now) {
                  futureMatches++;
                  // Расширяем диапазон до месяца для поиска предстоящих матчей
                  if ((startTime - now) < 2592000) { // 30 дней
                    // Проверяем, что матч еще не завершен
                    if (radiantWin == null) {
                      final match = Match.fromJson(matchData);
                      if (!match.isFinished) {
                        allMatches.add(match);
                        foundInLeague++;
                        debugPrint('Steam API: Найден предстоящий матч в лиге $leagueIdValue: ${match.radiantTeamName} vs ${match.direTeamName}, через ${((startTime - now) / 3600).toStringAsFixed(1)} часов');
                      }
                    }
                  }
                } else {
                  pastMatches++;
                }
              }
            }
            
            if (foundInLeague > 0) {
              debugPrint('Steam API: Найдено $foundInLeague предстоящих матчей в лиге $leagueIdValue');
            } else if (futureMatches > 0) {
              debugPrint('Steam API: В лиге $leagueIdValue найдено $futureMatches будущих матчей, но они вне диапазона 30 дней или уже завершены');
            } else {
              debugPrint('Steam API: В лиге $leagueIdValue все матчи в прошлом ($pastMatches матчей)');
            }
          } else {
            debugPrint('Steam API: Ошибка получения матчей лиги $leagueIdValue - ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('Error fetching league $leagueIdValue matches: $e');
        }
      }

      if (allMatches.isNotEmpty) {
        debugPrint('Steam API: Получено ${allMatches.length} предстоящих матчей через альтернативный метод');
      } else {
        debugPrint('Steam API: Предстоящие матчи не найдены');
      }
      
      return allMatches;
    } catch (e) {
      debugPrint('Steam API getScheduledLeagueGames error: $e');
      return [];
    }
  }

  /// Получить список лиг через OpenDota API
  /// ПРИМЕЧАНИЕ: Steam API не имеет метода GetLeagueListing
  Future<List<Map<String, dynamic>>> getLeagues() async {
    // Steam API не имеет метода GetLeagueListing
    // Используем OpenDota API для получения списка лиг
    try {
      final response = await http.get(
        Uri.parse('https://api.opendota.com/api/leagues?tier=premium'),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> leaguesData = json.decode(response.body);
        final List<Map<String, dynamic>> leagues = [];
        
        for (var league in leaguesData) {
          if (league is Map<String, dynamic>) {
            leagues.add(league);
          }
        }
        
        debugPrint('OpenDota API: Получено ${leagues.length} лиг');
        return leagues;
      } else {
        debugPrint('OpenDota API GetLeagues: Ошибка ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('OpenDota API GetLeagues error: $e');
    }

    return [];
  }
  
  /// Парсинг protobuf ответа на основе схемы CMsgDOTALeagueLiveGames
  /// Схема: https://github.com/SteamDatabase/Protobufs/blob/master/dota2/dota_gcmessages_common_league.proto
  /// Структура: CMsgDOTALeagueLiveGames { repeated LiveGame games }
  /// LiveGame содержит: radiant_name (field 3), dire_name (field 5), match_id (field 13), time (field 7), league_id (field 1)
  List<Match> _parseProtobufResponse(List<int> bytes) {
    final List<Match> matches = [];
    
    try {
      int offset = 0;
      
      // Ищем поле с номером 1 (games) - это repeated LiveGame
      // Tag для field 1, wire type 2 (length-delimited) = (1 << 3) | 2 = 10 (0x0A)
      while (offset < bytes.length - 1) {
        final tag = bytes[offset];
        offset++;
        
        final fieldNumber = tag >> 3;
        final wireType = tag & 0x07;
        
        if (wireType == 2) {
          // Length-delimited поле
          int length = 0;
          int shift = 0;
          while (offset < bytes.length) {
            final byte = bytes[offset];
            offset++;
            length |= (byte & 0x7F) << shift;
            if ((byte & 0x80) == 0) break;
            shift += 7;
            if (shift >= 32) break;
          }
          
          if (fieldNumber == 1 && offset + length <= bytes.length) {
            // Это поле games - парсим LiveGame
            final gameBytes = bytes.sublist(offset, offset + length);
            final match = _parseLiveGame(gameBytes);
            if (match != null) {
              matches.add(match);
            }
            offset += length;
          } else if (offset + length <= bytes.length) {
            // Другое length-delimited поле, пропускаем
            offset += length;
          } else {
            break;
          }
        } else if (wireType == 0) {
          // Varint поле, пропускаем
          while (offset < bytes.length) {
            final byte = bytes[offset];
            offset++;
            if ((byte & 0x80) == 0) break;
          }
        } else {
          // Неизвестный тип, прекращаем парсинг
          break;
        }
      }
      
      debugPrint('Steam API: Извлечено ${matches.length} матчей из protobuf');
      
    } catch (e) {
      debugPrint('Steam API: Ошибка при парсинге protobuf: $e');
    }
    
    return matches;
  }
  
  /// Парсинг одного LiveGame сообщения
  /// Поля: league_id (1), server_steam_id (2), radiant_name (3), dire_name (5), time (7), match_id (13)
  Match? _parseLiveGame(List<int> bytes) {
    try {
      String? radiantName;
      String? direName;
      int? matchId;
      int? leagueId;
      int? time;
      
      int offset = 0;
      
      while (offset < bytes.length) {
        if (offset >= bytes.length) break;
        
        final tag = bytes[offset];
        offset++;
        
        final fieldNumber = tag >> 3;
        final wireType = tag & 0x07;
        
        if (wireType == 2) {
          // Length-delimited (string)
          int length = 0;
          int shift = 0;
          while (offset < bytes.length) {
            final byte = bytes[offset];
            offset++;
            length |= (byte & 0x7F) << shift;
            if ((byte & 0x80) == 0) break;
            shift += 7;
            if (shift >= 32) break;
          }
          
          if (offset + length <= bytes.length) {
            if (fieldNumber == 3) {
              // radiant_name
              radiantName = String.fromCharCodes(bytes.sublist(offset, offset + length));
            } else if (fieldNumber == 5) {
              // dire_name
              direName = String.fromCharCodes(bytes.sublist(offset, offset + length));
            }
            offset += length;
          } else {
            break;
          }
        } else if (wireType == 0) {
          // Varint (uint32, uint64)
          int value = 0;
          int shift = 0;
          while (offset < bytes.length) {
            final byte = bytes[offset];
            offset++;
            value |= (byte & 0x7F) << shift;
            if ((byte & 0x80) == 0) break;
            shift += 7;
            if (shift >= 64) break;
          }
          
          if (fieldNumber == 1) {
            // league_id (uint32)
            leagueId = value;
          } else if (fieldNumber == 7) {
            // time (uint32) - длительность матча в секундах
            time = value;
          } else if (fieldNumber == 13) {
            // match_id (uint64)
            matchId = value;
          }
        } else {
          // Пропускаем другие типы
          break;
        }
      }
      
      if (radiantName != null && direName != null && 
          radiantName.isNotEmpty && direName.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        // time - это длительность матча, вычисляем примерное время начала
        final startTime = time != null ? now - time : now;
        
        return Match(
          matchId: matchId ?? (radiantName + direName + startTime.toString()).hashCode.abs(),
          radiantTeamName: radiantName,
          direTeamName: direName,
          startTime: startTime,
          duration: time,
          leagueName: leagueId != null ? 'League $leagueId' : 'Steam Live Game',
        );
      }
    } catch (e) {
      debugPrint('Steam API: Ошибка при парсинге LiveGame: $e');
    }
    
    return null;
  }
}

