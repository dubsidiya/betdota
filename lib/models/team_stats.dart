class TeamStats {
  final int teamId;
  final String teamName;
  final String? teamLogo;
  final int wins;
  final int losses;
  final double winRate;
  final double avgKills;
  final double avgDeaths;
  final double avgGpm;
  final List<RecentMatch> recentMatches;

  TeamStats({
    required this.teamId,
    required this.teamName,
    this.teamLogo,
    required this.wins,
    required this.losses,
    required this.winRate,
    required this.avgKills,
    required this.avgDeaths,
    required this.avgGpm,
    required this.recentMatches,
  });

  factory TeamStats.fromJson(Map<String, dynamic> json) {
    return TeamStats(
      teamId: json['team_id'] ?? json['teamId'] ?? 0,
      teamName: json['name'] ?? json['teamName'] ?? 'Unknown',
      teamLogo: json['logo_url'] ?? json['teamLogo'],
      wins: json['wins'] ?? 0,
      losses: json['losses'] ?? 0,
      winRate: (json['wins'] ?? 0) / ((json['wins'] ?? 0) + (json['losses'] ?? 0) + 1) * 100,
      avgKills: (json['avg_kills'] ?? json['avgKills'] ?? 0).toDouble(),
      avgDeaths: (json['avg_deaths'] ?? json['avgDeaths'] ?? 0).toDouble(),
      avgGpm: (json['avg_gpm'] ?? json['avgGpm'] ?? 0).toDouble(),
      recentMatches: json['recent_matches'] != null
          ? (json['recent_matches'] as List)
              .map((m) => RecentMatch.fromJson(m))
              .toList()
          : [],
    );
  }
}

class RecentMatch {
  final int matchId;
  final bool won;
  final int duration;
  final int kills;
  final int deaths;

  RecentMatch({
    required this.matchId,
    required this.won,
    required this.duration,
    required this.kills,
    required this.deaths,
  });

  factory RecentMatch.fromJson(Map<String, dynamic> json) {
    return RecentMatch(
      matchId: json['match_id'] ?? json['matchId'] ?? 0,
      won: json['radiant_win'] == (json['radiant'] ?? true),
      duration: json['duration'] ?? 0,
      kills: json['kills'] ?? 0,
      deaths: json['deaths'] ?? 0,
    );
  }
}

