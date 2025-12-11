import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../providers/matches_provider.dart';
import '../providers/predictions_provider.dart';
import 'prediction_result_screen.dart';

class MatchDetailScreen extends StatefulWidget {
  final int matchId;

  const MatchDetailScreen({super.key, required this.matchId});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchesProvider>().loadMatchDetails(widget.matchId);
    });
  }

  @override
  void dispose() {
    // Очищаем выбранный матч при закрытии экрана
    context.read<MatchesProvider>().clearSelectedMatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали матча'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Consumer<MatchesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.selectedMatch == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.selectedMatch == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Ошибка загрузки',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => provider.loadMatchDetails(widget.matchId),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Попробовать снова'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final match = provider.selectedMatch;
          if (match == null) {
            return const Center(child: Text('Матч не найден'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMatchHeader(match),
                const SizedBox(height: 24),
                _buildMatchInfo(match),
                const SizedBox(height: 24),
                if (match.players != null && match.players!.isNotEmpty)
                  _buildPlayersList(match.players!),
                const SizedBox(height: 24),
                if (!match.isFinished) _buildPredictionButton(context, match),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMatchHeader(Match match) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (match.leagueName != null)
              Text(
                match.leagueName!,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        match.radiantTeamName ?? 'Radiant',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (match.radiantScore != null)
                        Text(
                          '${match.radiantScore}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                    ],
                  ),
                ),
                const Text(
                  'VS',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        match.direTeamName ?? 'Dire',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (match.direScore != null)
                        Text(
                          '${match.direScore}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (match.radiantWin != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: match.radiantWin! ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Победитель: ${match.winnerTeamName ?? "Unknown"}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchInfo(Match match) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final startTime = match.startTime != null
        ? DateTime.fromMillisecondsSinceEpoch(match.startTime! * 1000)
        : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Информация о матче',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(),
            _buildInfoRow('Match ID', match.matchId.toString()),
            if (match.duration != null)
              _buildInfoRow('Длительность', match.formattedDuration),
            if (startTime != null)
              _buildInfoRow('Время начала', dateFormat.format(startTime)),
            if (match.gameModeName != null)
              _buildInfoRow('Режим игры', match.gameModeName!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayersList(List<Player> players) {
    final radiantPlayers = players.where((p) => p.teamNumber == 0).toList();
    final direPlayers = players.where((p) => p.teamNumber == 1).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Игроки',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Divider(),
            const Text(
              'Radiant',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            ...radiantPlayers.map((p) => _buildPlayerRow(p)),
            const SizedBox(height: 16),
            const Text(
              'Dire',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            ...direPlayers.map((p) => _buildPlayerRow(p)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerRow(Player player) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              player.playerName ?? player.heroName ?? 'Unknown',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            'K: ${player.kills ?? 0} D: ${player.deaths ?? 0} A: ${player.assists ?? 0}',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(width: 8),
          Text(
            'KDA: ${player.kda.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionButton(BuildContext context, Match match) {
    return Consumer<PredictionsProvider>(
      builder: (context, predictionsProvider, child) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: predictionsProvider.isLoading
                ? null
                : () async {
                    try {
                      final prediction = await predictionsProvider.createPrediction(match);
                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PredictionResultScreen(
                              prediction: prediction,
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ошибка создания предикта: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: predictionsProvider.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Создать предикт',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        );
      },
    );
  }
}

