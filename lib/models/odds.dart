class Odds {
  final double? radiantOdds;
  final double? direOdds;
  final String? bookmaker;

  Odds({
    this.radiantOdds,
    this.direOdds,
    this.bookmaker,
  });

  factory Odds.fromJson(Map<String, dynamic> json) {
    return Odds(
      radiantOdds: json['radiant_odds']?.toDouble() ?? json['radiantOdds']?.toDouble(),
      direOdds: json['dire_odds']?.toDouble() ?? json['direOdds']?.toDouble(),
      bookmaker: json['bookmaker']?.toString(),
    );
  }

  // Вычисление вероятности победы на основе коэффициентов
  double? get radiantWinProbability {
    if (radiantOdds == null || direOdds == null) return null;
    // Формула: prob = 1 / odds, нормализованная
    final radiantProb = 1 / radiantOdds!;
    final direProb = 1 / direOdds!;
    final total = radiantProb + direProb;
    return radiantProb / total;
  }

  double? get direWinProbability {
    final radiantProb = radiantWinProbability;
    if (radiantProb == null) return null;
    return 1 - radiantProb;
  }
}

