import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/prediction.dart';
import '../providers/predictions_provider.dart';
import 'prediction_result_screen.dart';

class PredictionsListScreen extends StatelessWidget {
  const PredictionsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои предикты'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Consumer<PredictionsProvider>(
        builder: (context, provider, child) {
          if (provider.predictions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Предикты отсутствуют',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Создайте предикт из деталей матча',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.predictions.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final prediction = provider.predictions[index];
              return _PredictionCard(prediction: prediction);
            },
          );
        },
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final Prediction prediction;

  const _PredictionCard({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final confidenceColor = _getConfidenceColor(prediction.confidence);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PredictionResultScreen(
                prediction: prediction,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      prediction.matchTitle ?? 'Матч #${prediction.matchId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: confidenceColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      prediction.confidencePercentage,
                      style: TextStyle(
                        color: confidenceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: prediction.predictedWinner == 'radiant'
                          ? Colors.green.withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      prediction.predictedWinner == 'radiant' ? 'Radiant' : 'Dire',
                      style: TextStyle(
                        color: prediction.predictedWinner == 'radiant'
                            ? Colors.green[700]
                            : Colors.red[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (prediction.wasCorrect != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      prediction.wasCorrect! ? Icons.check_circle : Icons.cancel,
                      color: prediction.wasCorrect! ? Colors.green : Colors.red,
                      size: 20,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dateFormat.format(prediction.createdAt),
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Удалить предикт?'),
                          content: const Text(
                            'Вы уверены, что хотите удалить этот предикт?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Отмена'),
                            ),
                            TextButton(
                              onPressed: () {
                                context
                                    .read<PredictionsProvider>()
                                    .deletePrediction(prediction.id);
                                Navigator.pop(context);
                              },
                              child: const Text(
                                'Удалить',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.7) return Colors.green;
    if (confidence >= 0.55) return Colors.orange;
    return Colors.red;
  }
}

