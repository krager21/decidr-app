import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/activity_history_model.dart';
import '../models/suggestions_repository.dart';

/// History page showing completed activities
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historyModel = Provider.of<ActivityHistoryModel>(context);
    final recentActivities = historyModel.getRecentActivities(limit: 20);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History'),
      ),
      body: recentActivities.isEmpty
          ? _buildEmptyHistoryView(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recentActivities.length,
              itemBuilder: (context, index) {
                // Activity item
                final activity = recentActivities[index];
                return _buildHistoryItem(context, activity);
              },
            ),
    );
  }
  
  // Build a history item.
  //
  // `activity.key` is a Suggestion.id (post-Phase-3); resolve to a
  // renderable Suggestion for the displayed title and icon.
  Widget _buildHistoryItem(
    BuildContext context,
    MapEntry<String, DateTime> activity,
  ) {
    final theme = Theme.of(context);
    final suggestionsRepo = Provider.of<SuggestionsRepository>(context);
    final suggestion = suggestionsRepo.resolveById(activity.key);

    // Format the date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activityDate = DateTime(
      activity.value.year,
      activity.value.month,
      activity.value.day,
    );

    String dateText;
    if (activityDate == today) {
      dateText = 'Today';
    } else if (activityDate == today.subtract(const Duration(days: 1))) {
      dateText = 'Yesterday';
    } else {
      dateText =
          '${activity.value.day}/${activity.value.month}/${activity.value.year}';
    }

    // Format the time
    final timeText =
        '${activity.value.hour.toString().padLeft(2, '0')}:${activity.value.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
          ),
          child: Icon(
            suggestion.iconData,
            color: theme.colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
        title: Text(suggestion.title),
        subtitle: Text('$dateText at $timeText'),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }
  
  // Build empty history view
  Widget _buildEmptyHistoryView(BuildContext context) {
    final theme = Theme.of(context);
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No activity history yet',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your completed activities will appear here. Spin the wheel and mark activities as completed to build your history!',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              icon: const Icon(Icons.shuffle),
              label: const Text('Go to Wheel'),
            ),
          ],
        ),
      ),
    );
  }
}