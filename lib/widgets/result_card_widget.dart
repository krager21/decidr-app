import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/preferences_model.dart';
import '../models/suggestions_repository.dart';
import '../models/activity_history_model.dart';
import '../utils/constants.dart';

/// A card widget that displays the selected suggestion with details
///
/// Shows:
/// - Activity name with icon
/// - Favorite toggle button
/// - Description, benefits, and tips
/// - Mark as completed button
class ResultCard extends StatelessWidget {
  final String suggestion;

  const ResultCard({
    required this.suggestion,
    super.key,
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
      padding: UIConstants.cardPadding,
      child: Card(
        elevation: UIConstants.elevatedCardElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UIConstants.cardBorderRadius),
        ),
        child: Padding(
          padding: UIConstants.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with icon and suggestion name
              Row(
                children: [
                  Container(
                    width: UIConstants.avatarIconSize,
                    height: UIConstants.avatarIconSize,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: UIConstants.largeSpacing),
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
              const Divider(height: UIConstants.extraLargeSpacing),

              // Description section
              Text(
                'About this suggestion:',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: UIConstants.defaultSpacing),
              Text(
                details['description'] ?? '',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: UIConstants.largeSpacing),

              // Benefits section
              Text(
                'Benefits:',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: UIConstants.defaultSpacing),
              Text(
                details['benefits'] ?? '',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: UIConstants.largeSpacing),

              // Tips section
              Text(
                'Tips:',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: UIConstants.defaultSpacing),
              Text(
                details['tips'] ?? '',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: UIConstants.largeSpacing),

              // Mark as completed button
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
