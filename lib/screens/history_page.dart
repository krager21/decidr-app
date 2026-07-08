import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/activity_history_model.dart';
import '../models/suggestions_repository.dart';

/// History page showing completed activities
class HistoryPage extends StatelessWidget {
  /// Switches the surrounding [MainTabsPage] to the Decide tab.
  /// HistoryPage is a tab body, not a pushed route, so the empty-state
  /// CTA can't reach the deal screen through the Navigator.
  final VoidCallback? onGoDecide;

  const HistoryPage({super.key, this.onGoDecide});

  @override
  Widget build(BuildContext context) {
    final historyModel = Provider.of<ActivityHistoryModel>(context);
    // Events, not latest-per-id: doing the same activity twice shows
    // both completions.
    final recentEvents = historyModel.getRecentEvents(limit: 30);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity History'),
      ),
      body: recentEvents.isEmpty
          ? _buildEmptyHistoryView(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recentEvents.length,
              itemBuilder: (context, index) {
                return _buildHistoryItem(context, recentEvents[index]);
              },
            ),
    );
  }

  // Build a history item.
  //
  // `event.id` is a Suggestion.id (post-Phase-3); resolve to a
  // renderable Suggestion for the displayed title and icon.
  Widget _buildHistoryItem(
    BuildContext context,
    ActivityEvent event,
  ) {
    final theme = Theme.of(context);
    final suggestionsRepo = Provider.of<SuggestionsRepository>(context);
    final suggestion = suggestionsRepo.resolveById(event.id);

    // Format the date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activityDate = DateTime(
      event.at.year,
      event.at.month,
      event.at.day,
    );

    String dateText;
    if (activityDate == today) {
      dateText = 'Today';
    } else if (activityDate == today.subtract(const Duration(days: 1))) {
      dateText = 'Yesterday';
    } else {
      dateText = '${event.at.day}/${event.at.month}/${event.at.year}';
    }

    // Format the time
    final timeText =
        '${event.at.hour.toString().padLeft(2, '0')}:${event.at.minute.toString().padLeft(2, '0')}';

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
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 24),
            Text(
              'No activity history yet',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Your completed activities will appear here. Deal yourself a decision and mark it done to build your history!',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (onGoDecide != null)
              ElevatedButton.icon(
                onPressed: onGoDecide,
                icon: const Icon(Icons.style),
                label: const Text('Deal cards'),
              ),
          ],
        ),
      ),
    );
  }
}