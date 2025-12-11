class Draft {
  final List<int>? radiantPicks; // Hero IDs
  final List<int>? direPicks; // Hero IDs
  final List<int>? radiantBans; // Hero IDs
  final List<int>? direBans; // Hero IDs
  final Map<int, String>? heroNames; // Hero ID -> Hero Name mapping

  Draft({
    this.radiantPicks,
    this.direPicks,
    this.radiantBans,
    this.direBans,
    this.heroNames,
  });

  factory Draft.fromJson(Map<String, dynamic> json) {
    final picks = json['picks_bans'] as List<dynamic>?;
    
    List<int>? radiantPicks;
    List<int>? direPicks;
    List<int>? radiantBans;
    List<int>? direBans;
    Map<int, String>? heroNames = {};

    if (picks != null) {
      radiantPicks = [];
      direPicks = [];
      radiantBans = [];
      direBans = [];

      for (var pickBan in picks) {
        final heroId = pickBan['hero_id'] as int?;
        final isPick = pickBan['is_pick'] == true;
        final team = pickBan['team'] as int?; // 0 = Radiant, 1 = Dire
        
        if (heroId != null) {
          final heroName = pickBan['hero_name']?.toString();
          if (heroName != null) {
            heroNames[heroId] = heroName;
          }

          if (isPick) {
            if (team == 0) {
              radiantPicks.add(heroId);
            } else if (team == 1) {
              direPicks.add(heroId);
            }
          } else {
            if (team == 0) {
              radiantBans.add(heroId);
            } else if (team == 1) {
              direBans.add(heroId);
            }
          }
        }
      }
    }

    return Draft(
      radiantPicks: radiantPicks,
      direPicks: direPicks,
      radiantBans: radiantBans,
      direBans: direBans,
      heroNames: heroNames.isEmpty ? null : heroNames,
    );
  }

  List<int> get allRadiantHeroes => [
    ...?radiantPicks,
  ];

  List<int> get allDireHeroes => [
    ...?direPicks,
  ];
}

