enum MatchStatus {
  finished,    // Завершен
  live,        // Идет сейчас
  upcoming,    // Предстоящий
  unknown,     // Неизвестно
}

class Match {
  final int matchId;
  final int? leagueId;
  final String? leagueName;
  final int? radiantTeamId;
  final String? radiantTeamName;
  final String? radiantTeamLogo;
  final int? direTeamId;
  final String? direTeamName;
  final String? direTeamLogo;
  final int? radiantScore;
  final int? direScore;
  final int? duration;
  final int? startTime;
  final bool? radiantWin;
  final int? gameMode;
  final String? gameModeName;
  final int? lobbyType;
  final List<Player>? players;
  final MatchStatus status;

  Match({
    required this.matchId,
    this.leagueId,
    this.leagueName,
    this.radiantTeamId,
    this.radiantTeamName,
    this.radiantTeamLogo,
    this.direTeamId,
    this.direTeamName,
    this.direTeamLogo,
    this.radiantScore,
    this.direScore,
    this.duration,
    this.startTime,
    this.radiantWin,
    this.gameMode,
    this.gameModeName,
    this.lobbyType,
    this.players,
    MatchStatus? status,
  }) : status = status ?? _determineStatus(startTime, duration, radiantWin);

  factory Match.fromJson(Map<String, dynamic> json) {
    // Обработка вложенных объектов из детального матча
    final radiantTeam = json['radiant_team'] as Map<String, dynamic>?;
    final direTeam = json['dire_team'] as Map<String, dynamic>?;
    final league = json['league'] as Map<String, dynamic>?;
    
    // Извлечение данных команды Radiant
    final radiantTeamId = radiantTeam?['team_id'] ?? 
                         json['radiant_team_id'] ?? 
                         json['radiantTeamId'];
    final radiantTeamName = radiantTeam?['name']?.toString() ?? 
                           json['radiant_name']?.toString() ?? 
                           json['radiantTeamName']?.toString();
    final radiantTeamLogo = radiantTeam?['logo_url']?.toString() ?? 
                           json['radiant_logo']?.toString() ?? 
                           json['radiantTeamLogo']?.toString();
    
    // Извлечение данных команды Dire
    final direTeamId = direTeam?['team_id'] ?? 
                      json['dire_team_id'] ?? 
                      json['direTeamId'];
    final direTeamName = direTeam?['name']?.toString() ?? 
                        json['dire_name']?.toString() ?? 
                        json['direTeamName']?.toString();
    final direTeamLogo = direTeam?['logo_url']?.toString() ?? 
                        json['dire_logo']?.toString() ?? 
                        json['direTeamLogo']?.toString();
    
    // Извлечение данных лиги
    final leagueId = league?['leagueid'] ?? 
                    league?['league_id'] ?? 
                    json['leagueid'] ?? 
                    json['league_id'];
    final leagueName = league?['name']?.toString() ?? 
                      json['league_name']?.toString() ?? 
                      json['leagueName']?.toString();
    
    final startTimeValue = json['start_time'] ?? json['startTime'];
    final durationValue = json['duration'];
    final radiantWinValue = json['radiant_win'] ?? json['radiantWin'];
    
    // Нормализация startTime в int (секунды Unix timestamp)
    int? normalizedStartTime;
    if (startTimeValue != null) {
      if (startTimeValue is int) {
        normalizedStartTime = startTimeValue;
      } else if (startTimeValue is String) {
        normalizedStartTime = int.tryParse(startTimeValue);
      } else if (startTimeValue is double) {
        normalizedStartTime = startTimeValue.toInt();
      }
    }
    
    // Нормализация duration в int
    int? normalizedDuration;
    if (durationValue != null) {
      if (durationValue is int) {
        normalizedDuration = durationValue;
      } else if (durationValue is String) {
        normalizedDuration = int.tryParse(durationValue);
      } else if (durationValue is double) {
        normalizedDuration = durationValue.toInt();
      }
    }
    
    return Match(
      matchId: json['match_id'] ?? json['matchId'] ?? 0,
      leagueId: leagueId is int ? leagueId : (leagueId is String ? int.tryParse(leagueId) : null),
      leagueName: leagueName,
      radiantTeamId: radiantTeamId is int ? radiantTeamId : (radiantTeamId is String ? int.tryParse(radiantTeamId) : null),
      radiantTeamName: radiantTeamName,
      radiantTeamLogo: radiantTeamLogo,
      direTeamId: direTeamId is int ? direTeamId : (direTeamId is String ? int.tryParse(direTeamId) : null),
      direTeamName: direTeamName,
      direTeamLogo: direTeamLogo,
      radiantScore: json['radiant_score'] ?? json['radiantScore'],
      direScore: json['dire_score'] ?? json['direScore'],
      duration: normalizedDuration,
      startTime: normalizedStartTime,
      radiantWin: radiantWinValue,
      gameMode: json['game_mode'] ?? json['gameMode'],
      gameModeName: json['game_mode_name']?.toString() ?? json['gameModeName']?.toString(),
      lobbyType: json['lobby_type'] ?? json['lobbyType'],
      players: json['players'] != null
          ? _parsePlayers(json['players'])
          : null,
    );
  }

  String get formattedDuration {
    if (duration == null) return 'N/A';
    final minutes = duration! ~/ 60;
    final seconds = duration! % 60;
    return '${minutes}m ${seconds}s';
  }

  String? get winnerTeamName => radiantWin == true 
      ? radiantTeamName 
      : (radiantWin == false ? direTeamName : null);

  // Определение статуса матча
  static MatchStatus _determineStatus(int? startTime, int? duration, bool? radiantWin) {
    try {
      // Если есть результат - матч завершен
      if (radiantWin != null) {
        return MatchStatus.finished;
      }
      
      if (startTime == null) {
        return MatchStatus.unknown;
      }
      
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final matchStart = startTime;
      
      // Проверка на валидность времени (не должно быть слишком старым или будущим)
      // Если время старше 10 лет назад или больше чем через год - считаем неизвестным
      if (matchStart < (now - 315360000) || matchStart > (now + 31536000)) {
        return MatchStatus.unknown;
      }
      
      final matchEnd = duration != null ? matchStart + duration : null;
      
      // Если матч уже начался и еще не закончился (или нет данных о длительности)
      if (now >= matchStart) {
        if (matchEnd != null && now >= matchEnd) {
          return MatchStatus.finished;
        }
        // Если матч идет более 2 часов, считаем завершенным
        if (duration != null && duration > 7200) {
          return MatchStatus.finished;
        }
        return MatchStatus.live;
      }
      
      // Если матч еще не начался
      return MatchStatus.upcoming;
    } catch (e) {
      // В случае любой ошибки возвращаем unknown
      return MatchStatus.unknown;
    }
  }

  bool get isFinished => status == MatchStatus.finished;
  bool get isLive => status == MatchStatus.live;
  bool get isUpcoming => status == MatchStatus.upcoming;

  // Безопасный парсинг игроков
  static List<Player>? _parsePlayers(dynamic playersData) {
    try {
      if (playersData == null) return null;
      if (playersData is! List) return null;
      
      final List<Player> players = [];
      for (var playerData in playersData) {
        try {
          if (playerData is Map<String, dynamic>) {
            players.add(Player.fromJson(playerData));
          }
        } catch (e) {
          // Пропускаем игроков с ошибками парсинга
          continue;
        }
      }
      return players.isEmpty ? null : players;
    } catch (e) {
      return null;
    }
  }
}

class Player {
  final int? accountId;
  final String? playerName;
  final int? heroId;
  final String? heroName;
  final int? kills;
  final int? deaths;
  final int? assists;
  final int? netWorth;
  final int? gpm;
  final int? xpm;
  final int? teamNumber; // 0 = Radiant, 1 = Dire

  Player({
    this.accountId,
    this.playerName,
    this.heroId,
    this.heroName,
    this.kills,
    this.deaths,
    this.assists,
    this.netWorth,
    this.gpm,
    this.xpm,
    this.teamNumber,
  });

  factory Player.fromJson(Map<String, dynamic> json) {
    // Определение команды по player_slot (0-4 = Radiant, 128-132 = Dire)
    int? teamNumber;
    if (json['player_slot'] != null) {
      final slot = json['player_slot'] is int 
          ? json['player_slot'] 
          : (json['player_slot'] is String ? int.tryParse(json['player_slot']) : null);
      teamNumber = slot != null ? (slot < 128 ? 0 : 1) : null;
    } else {
      teamNumber = json['team_number'] ?? json['teamNumber'];
    }
    
    // Обработка hero_id - может быть int или null
    final heroIdValue = json['hero_id'] ?? json['heroId'];
    final heroId = heroIdValue is int 
        ? heroIdValue 
        : (heroIdValue is String ? int.tryParse(heroIdValue) : null);
    
    return Player(
      accountId: json['account_id'] ?? json['accountId'],
      playerName: json['name']?.toString() ?? json['personaname']?.toString() ?? json['playerName']?.toString(),
      heroId: heroId,
      heroName: json['hero_name']?.toString() ?? json['heroName']?.toString(),
      kills: json['kills'] is int ? json['kills'] : (json['kills'] is String ? int.tryParse(json['kills']) : null),
      deaths: json['deaths'] is int ? json['deaths'] : (json['deaths'] is String ? int.tryParse(json['deaths']) : null),
      assists: json['assists'] is int ? json['assists'] : (json['assists'] is String ? int.tryParse(json['assists']) : null),
      netWorth: json['net_worth'] ?? json['netWorth'],
      gpm: json['gold_per_min'] ?? json['gpm'],
      xpm: json['xp_per_min'] ?? json['xpm'],
      teamNumber: teamNumber,
    );
  }

  double get kda {
    if (deaths == null || deaths == 0) {
      return (kills ?? 0) + (assists ?? 0).toDouble();
    }
    return ((kills ?? 0) + (assists ?? 0)) / deaths!;
  }
}

