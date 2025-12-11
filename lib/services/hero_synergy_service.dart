import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/draft.dart';

class HeroSynergyService {
  static const String baseUrl = 'https://api.opendota.com/api';

  // Кэш для статистики синергии героев
  final Map<String, HeroPairStats> _synergyCache = {};

  // Получить статистику пары героев
  Future<HeroPairStats> getHeroPairStats(int heroId1, int heroId2) async {
    final key = '${heroId1}_$heroId2';
    if (_synergyCache.containsKey(key)) {
      return _synergyCache[key]!;
    }

    try {
      // Получаем статистику для первого героя
      final response1 = await http.get(
        Uri.parse('$baseUrl/heroes/$heroId1/matchups'),
      );

      if (response1.statusCode == 200) {
        final List<dynamic> matchups = json.decode(response1.body);
        
        // Ищем статистику против второго героя
        for (var matchup in matchups) {
          if (matchup['hero_id'] == heroId2) {
            final games = matchup['games_played'] ?? 0;
            final wins = matchup['wins'] ?? 0;
            final winRate = games > 0 ? wins / games : 0.5;
            
            final stats = HeroPairStats(
              heroId1: heroId1,
              heroId2: heroId2,
              gamesPlayed: games,
              wins: wins,
              winRate: winRate,
            );
            
            _synergyCache[key] = stats;
            return stats;
          }
        }
      }
    } catch (e) {
      // В случае ошибки возвращаем нейтральную статистику
    }

    // Возвращаем нейтральную статистику если данных нет
    final neutralStats = HeroPairStats(
      heroId1: heroId1,
      heroId2: heroId2,
      gamesPlayed: 0,
      wins: 0,
      winRate: 0.5,
    );
    
    _synergyCache[key] = neutralStats;
    return neutralStats;
  }

  // Анализ синергии команды героев
  Future<TeamSynergyAnalysis> analyzeTeamSynergy(List<int> heroIds) async {
    if (heroIds.length < 2) {
      return TeamSynergyAnalysis(
        averageWinRate: 0.5,
        synergyScore: 0.5,
        strongPairs: [],
        weakPairs: [],
      );
    }

    List<HeroPairStats> pairStats = [];
    
    // Анализируем все пары героев в команде
    for (int i = 0; i < heroIds.length; i++) {
      for (int j = i + 1; j < heroIds.length; j++) {
        final stats = await getHeroPairStats(heroIds[i], heroIds[j]);
        pairStats.add(stats);
      }
    }

    if (pairStats.isEmpty) {
      return TeamSynergyAnalysis(
        averageWinRate: 0.5,
        synergyScore: 0.5,
        strongPairs: [],
        weakPairs: [],
      );
    }

    // Вычисляем средний винрейт
    double totalWinRate = 0;
    int validPairs = 0;
    
    for (var stats in pairStats) {
      if (stats.gamesPlayed > 0) {
        totalWinRate += stats.winRate;
        validPairs++;
      }
    }

    final averageWinRate = validPairs > 0 ? totalWinRate / validPairs : 0.5;

    // Определяем сильные и слабые пары
    final strongPairs = pairStats
        .where((s) => s.gamesPlayed > 10 && s.winRate > 0.55)
        .toList();
    final weakPairs = pairStats
        .where((s) => s.gamesPlayed > 10 && s.winRate < 0.45)
        .toList();

    // Вычисляем общий синергетический скор (0-1)
    double synergyScore = averageWinRate;
    
    // Бонус за сильные пары
    if (strongPairs.length > weakPairs.length) {
      synergyScore += 0.1;
    }
    
    // Штраф за слабые пары
    if (weakPairs.length > strongPairs.length) {
      synergyScore -= 0.1;
    }

    synergyScore = synergyScore.clamp(0.0, 1.0);

    return TeamSynergyAnalysis(
      averageWinRate: averageWinRate,
      synergyScore: synergyScore,
      strongPairs: strongPairs,
      weakPairs: weakPairs,
    );
  }

  // Сравнение драфтов двух команд
  Future<DraftComparison> compareDrafts(Draft draft) async {
    final radiantHeroes = draft.allRadiantHeroes;
    final direHeroes = draft.allDireHeroes;

    if (radiantHeroes.isEmpty || direHeroes.isEmpty) {
      return DraftComparison(
        radiantSynergy: 0.5,
        direSynergy: 0.5,
        radiantAdvantage: 0.0,
      );
    }

    final radiantSynergy = await analyzeTeamSynergy(radiantHeroes);
    final direSynergy = await analyzeTeamSynergy(direHeroes);

    // Анализ контрпиков
    double counterScore = 0.0;
    int counterChecks = 0;

    for (var radiantHero in radiantHeroes) {
      for (var direHero in direHeroes) {
        final stats = await getHeroPairStats(radiantHero, direHero);
        if (stats.gamesPlayed > 0) {
          // Если винрейт > 0.55, это хороший контрпик
          if (stats.winRate > 0.55) {
            counterScore += 0.1;
          } else if (stats.winRate < 0.45) {
            counterScore -= 0.1;
          }
          counterChecks++;
        }
      }
    }

    final counterAdvantage = counterChecks > 0 ? counterScore / counterChecks : 0.0;

    // Общее преимущество Radiant
    final radiantAdvantage = (radiantSynergy.synergyScore - direSynergy.synergyScore) + counterAdvantage;

    return DraftComparison(
      radiantSynergy: radiantSynergy.synergyScore,
      direSynergy: direSynergy.synergyScore,
      radiantAdvantage: radiantAdvantage,
      radiantAnalysis: radiantSynergy,
      direAnalysis: direSynergy,
    );
  }
}

class HeroPairStats {
  final int heroId1;
  final int heroId2;
  final int gamesPlayed;
  final int wins;
  final double winRate;

  HeroPairStats({
    required this.heroId1,
    required this.heroId2,
    required this.gamesPlayed,
    required this.wins,
    required this.winRate,
  });
}

class TeamSynergyAnalysis {
  final double averageWinRate;
  final double synergyScore; // 0-1
  final List<HeroPairStats> strongPairs;
  final List<HeroPairStats> weakPairs;

  TeamSynergyAnalysis({
    required this.averageWinRate,
    required this.synergyScore,
    required this.strongPairs,
    required this.weakPairs,
  });
}

class DraftComparison {
  final double radiantSynergy;
  final double direSynergy;
  final double radiantAdvantage; // Положительное значение = преимущество Radiant
  final TeamSynergyAnalysis? radiantAnalysis;
  final TeamSynergyAnalysis? direAnalysis;

  DraftComparison({
    required this.radiantSynergy,
    required this.direSynergy,
    required this.radiantAdvantage,
    this.radiantAnalysis,
    this.direAnalysis,
  });
}

