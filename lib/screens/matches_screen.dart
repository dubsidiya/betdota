import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/match.dart';
import '../providers/matches_provider.dart';
import 'match_detail_screen.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchesProvider>().loadMatches();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dota 2 Матчи'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<MatchesProvider>().loadMatches();
            },
          ),
        ],
      ),
      body: Consumer<MatchesProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.matches.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.matches.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Ошибка загрузки',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(provider.error!),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadMatches(),
                    child: const Text('Попробовать снова'),
                  ),
                ],
              ),
            );
          }

          if (provider.matches.isEmpty) {
            return const Center(
              child: Text('Матчи не найдены'),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadMatches(),
            child: ListView.builder(
              itemCount: provider.matches.length,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) {
                final match = provider.matches[index];
                return _MatchCard(match: match);
              },
            ),
          );
        },
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Match match;

  const _MatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final startTime = match.startTime != null
        ? DateTime.fromMillisecondsSinceEpoch(match.startTime! * 1000)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MatchDetailScreen(matchId: match.matchId),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (match.leagueName != null)
                Text(
                  match.leagueName!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          match.radiantTeamName ?? 'Radiant',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (match.radiantScore != null)
                          Text(
                            'Score: ${match.radiantScore}',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ),
                  const Text(
                    'VS',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.deepPurple,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          match.direTeamName ?? 'Dire',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.end,
                        ),
                        if (match.direScore != null)
                          Text(
                            'Score: ${match.direScore}',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.end,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (match.duration != null)
                    Text(
                      'Duration: ${match.formattedDuration}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  if (startTime != null)
                    Text(
                      dateFormat.format(startTime),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
              if (match.radiantWin != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        match.radiantWin! ? Icons.check_circle : Icons.cancel,
                        color: match.radiantWin! ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Winner: ${match.winnerTeamName ?? "Unknown"}',
                        style: TextStyle(
                          color: match.radiantWin! ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

