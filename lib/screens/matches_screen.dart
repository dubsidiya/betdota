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

class _MatchesScreenState extends State<MatchesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MatchesProvider>().loadMatches();
    });
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final provider = context.read<MatchesProvider>();
      // Загружаем данные для активной вкладки при необходимости
      switch (_tabController.index) {
        case 0: // Завершенные
          if (provider.finishedMatches.isEmpty && !provider.isLoading) {
            provider.loadFinishedMatches();
          }
          break;
        case 1: // Лайв
          if (provider.liveMatches.isEmpty && !provider.isLoading) {
            provider.loadLiveMatches();
          }
          break;
        case 2: // Предстоящие
          if (provider.upcomingMatches.isEmpty && !provider.isLoading) {
            provider.loadUpcomingMatches();
          }
          break;
      }
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.check_circle),
              text: 'Завершенные',
            ),
            Tab(
              icon: Icon(Icons.play_circle),
              text: 'Идут сейчас',
            ),
            Tab(
              icon: Icon(Icons.schedule),
              text: 'Предстоящие',
            ),
          ],
        ),
      ),
      body: Consumer<MatchesProvider>(
        builder: (context, provider, child) {
          // Показываем ошибку только если нет данных вообще
          if (provider.error != null && 
              provider.finishedMatches.isEmpty && 
              provider.liveMatches.isEmpty && 
              provider.upcomingMatches.isEmpty) {
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
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => provider.loadMatches(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Попробовать снова'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _MatchesList(
                matches: provider.finishedMatches,
                emptyMessage: 'Завершенные матчи не найдены',
                isLoading: provider.isLoading && provider.finishedMatches.isEmpty,
                onRefresh: () => provider.loadFinishedMatches(),
              ),
              _MatchesList(
                matches: provider.liveMatches,
                emptyMessage: 'Идущих матчей не найдено.\n\nЛайв матчи могут быть недоступны из-за ограничений публичных API.\nПопробуйте обновить данные или проверьте завершенные матчинные матчи.',
                isLoading: provider.isLoading && provider.liveMatches.isEmpty,
                onRefresh: () => provider.loadLiveMatches(),
                showInfo: true,
              ),
              _MatchesList(
                matches: provider.upcomingMatches,
                emptyMessage: 'Предстоящих матчей нет',
                isLoading: provider.isLoading && provider.upcomingMatches.isEmpty,
                onRefresh: () => provider.loadUpcomingMatches(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MatchesList extends StatelessWidget {
  final List<Match> matches;
  final String emptyMessage;
  final bool isLoading;
  final VoidCallback onRefresh;
  final bool showInfo;

  const _MatchesList({
    required this.matches,
    required this.emptyMessage,
    this.isLoading = false,
    required this.onRefresh,
    this.showInfo = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (matches.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    showInfo ? Icons.info_outline : Icons.inbox,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (showInfo) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.lightbulb_outline, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Почему нет лайв матчей?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Публичные API (OpenDota, Steam) не всегда предоставляют актуальные данные о лайв матчах. '
                            'Для получения реальных лайв данных требуются платные API или прямой доступ к игровым серверам.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[900],
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Потяните вниз для обновления',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        itemCount: matches.length,
        padding: const EdgeInsets.all(8),
        itemBuilder: (context, index) {
          final match = matches[index];
          return _MatchCard(match: match);
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
              // Статус матча
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    if (match.isLive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (match.isUpcoming)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Предстоящий',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      )
                    else if (match.radiantWin != null)
                      Row(
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
