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
  });

  factory Match.fromJson(Map<String, dynamic> json) {
    return Match(
      matchId: json['match_id'] ?? json['matchId'] ?? 0,
      leagueId: json['leagueid'] ?? json['league_id'],
      leagueName: json['league_name'] ?? json['leagueName'],
      radiantTeamId: json['radiant_team_id'] ?? json['radiantTeamId'],
      radiantTeamName: json['radiant_name'] ?? json['radiantTeamName'],
      radiantTeamLogo: json['radiant_logo'] ?? json['radiantTeamLogo'],
      direTeamId: json['dire_team_id'] ?? json['direTeamId'],
      direTeamName: json['dire_name'] ?? json['direTeamName'],
      direTeamLogo: json['dire_logo'] ?? json['direTeamLogo'],
      radiantScore: json['radiant_score'] ?? json['radiantScore'],
      direScore: json['dire_score'] ?? json['direScore'],
      duration: json['duration'],
      startTime: json['start_time'] ?? json['startTime'],
      radiantWin: json['radiant_win'] ?? json['radiantWin'],
      gameMode: json['game_mode'] ?? json['gameMode'],
      gameModeName: json['game_mode_name'] ?? json['gameModeName'],
      lobbyType: json['lobby_type'] ?? json['lobbyType'],
      players: json['players'] != null
          ? (json['players'] as List).map((p) => Player.fromJson(p)).toList()
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
    return Player(
      accountId: json['account_id'] ?? json['accountId'],
      playerName: json['name'] ?? json['playerName'],
      heroId: json['hero_id'] ?? json['heroId'],
      heroName: json['hero_name'] ?? json['heroName'],
      kills: json['kills'],
      deaths: json['deaths'],
      assists: json['assists'],
      netWorth: json['net_worth'] ?? json['netWorth'],
      gpm: json['gold_per_min'] ?? json['gpm'],
      xpm: json['xp_per_min'] ?? json['xpm'],
      teamNumber: json['player_slot'] != null 
          ? (json['player_slot'] < 128 ? 0 : 1)
          : (json['team_number'] ?? json['teamNumber']),
    );
  }

  double get kda {
    if (deaths == null || deaths == 0) {
      return (kills ?? 0) + (assists ?? 0).toDouble();
    }
    return ((kills ?? 0) + (assists ?? 0)) / deaths!;
  }
}

