import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/preferences_model.dart';
import '../models/suggestions_repository.dart';
import '../models/activity_history_model.dart';

/// Result card showing selected suggestion details
class ResultCard extends StatelessWidget {
  final String suggestion;
  
  const ResultCard({
    super.key,
    required this.suggestion,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestionsRepo = Provider.of<SuggestionsRepository>(context);
    final preferencesModel = Provider.of<PreferencesModel>(context);
    
    // Get suggestion details
    final details = suggestionsRepo.getSuggestionDetails(suggestion);
    final icon = suggestionsRepo.getIconForSuggestion(suggestion);
    final isFavorite = preferencesModel.isFavorite(suggestion);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your suggestion:',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          suggestion,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: () {
                      preferencesModel.toggleFavorite(suggestion);
                    },
                    tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                'About this suggestion:',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                details['description'] ?? '',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Benefits:',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                details['benefits'] ?? '',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Tips:',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                details['tips'] ?? '',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Provider.of<ActivityHistoryModel>(context, listen: false)
                      .recordActivity(suggestion);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Marked "$suggestion" as completed!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.check),
                label: const Text('Mark as Completed'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}