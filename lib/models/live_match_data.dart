class LiveMatchData {
  final int matchId;
  final int? radiantScore;
  final int? direScore;
  final int? duration; // в секундах
  final int? radiantNetWorth;
  final int? direNetWorth;
  final int? radiantKills;
  final int? direKills;
  final List<LivePlayer>? players;

  LiveMatchData({
    required this.matchId,
    this.radiantScore,
    this.direScore,
    this.duration,
    this.radiantNetWorth,
    this.direNetWorth,
    this.radiantKills,
    this.direKills,
    this.players,
  });

  factory LiveMatchData.fromJson(Map<String, dynamic> json) {
    return LiveMatchData(
      matchId: json['match_id'] ?? json['matchId'] ?? 0,
      radiantScore: json['radiant_score'] ?? json['radiantScore'],
      direScore: json['dire_score'] ?? json['direScore'],
      duration: json['duration'],
      radiantNetWorth: json['radiant_net_worth'] ?? json['radiantNetWorth'],
      direNetWorth: json['dire_net_worth'] ?? json['direNetWorth'],
      radiantKills: json['radiant_kills'] ?? json['radiantKills'],
      direKills: json['dire_kills'] ?? json['direKills'],
      players: json['players'] != null
          ? (json['players'] as List).map((p) => LivePlayer.fromJson(p)).toList()
          : null,
    );
  }
}

class LivePlayer {
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
  final int? level;

  LivePlayer({
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
    this.level,
  });

  factory LivePlayer.fromJson(Map<String, dynamic> json) {
    int? teamNumber;
    if (json['player_slot'] != null) {
      final slot = json['player_slot'] is int 
          ? json['player_slot'] 
          : (json['player_slot'] is String ? int.tryParse(json['player_slot']) : null);
      teamNumber = slot != null ? (slot < 128 ? 0 : 1) : null;
    } else {
      teamNumber = json['team_number'] ?? json['teamNumber'];
    }

    return LivePlayer(
      accountId: json['account_id'] ?? json['accountId'],
      playerName: json['name']?.toString() ?? json['personaname']?.toString() ?? json['playerName']?.toString(),
      heroId: json['hero_id'] ?? json['heroId'],
      heroName: json['hero_name']?.toString() ?? json['heroName']?.toString(),
      kills: json['kills'] is int ? json['kills'] : (json['kills'] is String ? int.tryParse(json['kills']) : null),
      deaths: json['deaths'] is int ? json['deaths'] : (json['deaths'] is String ? int.tryParse(json['deaths']) : null),
      assists: json['assists'] is int ? json['assists'] : (json['assists'] is String ? int.tryParse(json['assists']) : null),
      netWorth: json['net_worth'] ?? json['netWorth'],
      gpm: json['gold_per_min'] ?? json['gpm'],
      xpm: json['xp_per_min'] ?? json['xpm'],
      teamNumber: teamNumber,
      level: json['level'] is int ? json['level'] : (json['level'] is String ? int.tryParse(json['level']) : null),
    );
  }
}

