import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/preferences_model.dart';
import '../models/suggestions_repository.dart';
import '../models/activity_history_model.dart';
import '../models/preference_profile.dart';
import '../services/premium_service.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/save_profile_dialog.dart';
import 'questionnaire_page.dart';
import 'settings_page.dart';
import '../utils/constants.dart';

/// Profile page with settings and favorites
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User profile card
          _buildProfileCard(context),
          
          const SizedBox(height: 24),
          
          // Preferences section
          Text(
            'Your Preferences',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildPreferencesCard(context),

          const SizedBox(height: 24),

          // Saved preference profiles
          Text(
            'Saved Profiles',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildProfilesCard(context),

          const SizedBox(height: 24),

          // Favorites section
          Text(
            'Your Favorites',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildFavoritesCard(context),
          
          const SizedBox(height: 24),
          
          // Custom suggestions section
          Text(
            'Your Custom Suggestions',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildCustomSuggestionsCard(context),
          
          const SizedBox(height: 24),
          
          // App settings
          Text(
            'App Settings',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          _buildSettingsCard(context),
        ],
      ),
    );
  }
  
  // Build profile card
  Widget _buildProfileCard(BuildContext context) {
    final theme = Theme.of(context);
    final historyModel = Provider.of<ActivityHistoryModel>(context);
    final recentActivities = historyModel.getRecentActivities();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar and activity info
            Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: 48,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity Tracker',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Track your completed activities',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Stats
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context, 
                  'Activities', 
                  '${recentActivities.length}',
                  Icons.check_circle_outline,
                ),
                _buildStatItem(
                  context, 
                  'Favorites', 
                  '${Provider.of<PreferencesModel>(context).favoriteActivities.length}',
                  Icons.favorite_outline,
                ),
                _buildStatItem(
                  context, 
                  'Custom', 
                  '${Provider.of<SuggestionsRepository>(context).customSuggestions.length}',
                  Icons.add_circle_outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // Build a stat item
  Widget _buildStatItem(BuildContext context, String title, String value, IconData icon) {
    final theme = Theme.of(context);
    
    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
  
  // Build preferences card
  Widget _buildPreferencesCard(BuildContext context) {
    final preferencesModel = Provider.of<PreferencesModel>(context);
    
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.home_work),
            title: const Text('Activity Type'),
            subtitle: Text(preferencesModel.activityPreference ?? 'Not set'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QuestionnairePage(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.mood),
            title: const Text('Mood'),
            subtitle: Text(preferencesModel.mood ?? 'Not set'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QuestionnairePage(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Time of Day'),
            // With auto-detect on (the default), timeOfDay stays null
            // and the app uses the detected value — show that instead
            // of a misleading 'Not set'.
            subtitle: Text(
              preferencesModel.autoDetectTime
                  ? '${preferencesModel.effectiveTimeOfDay} (auto)'
                  : preferencesModel.timeOfDay ?? 'Not set',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const QuestionnairePage(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  // Build favorites card
  Widget _buildFavoritesCard(BuildContext context) {
    final theme = Theme.of(context);
    final preferencesModel = Provider.of<PreferencesModel>(context);
    final suggestionsRepo = Provider.of<SuggestionsRepository>(context);
    final favorites = preferencesModel.favoriteActivities;
    
    if (favorites.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No favorites yet',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the heart on a dealt card to keep it here.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Card(
      child: Column(
        children: [
          for (int i = 0; i < favorites.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Builder(builder: (context) {
              // favorites[i] is a Suggestion id (Phase 3); resolve to a
              // renderable Suggestion. resolveById falls back to a
              // synthesized stub for unknown ids so display never crashes.
              final fav = suggestionsRepo.resolveById(favorites[i]);
              return ListTile(
                leading: Icon(
                  fav.iconData,
                  color: theme.colorScheme.primary,
                ),
                title: Text(fav.title),
                subtitle: fav.description.isEmpty
                    ? null
                    : Text(
                        fav.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: IconButton(
                  icon: const Icon(Icons.favorite, color: Colors.red),
                  onPressed: () {
                    preferencesModel.toggleFavorite(fav.id);
                  },
                  tooltip: 'Remove from favorites',
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
  
  /// Saved questionnaire profiles: apply with a tap, delete with the
  /// trash icon, save the current answers from the top tile.
  Widget _buildProfilesCard(BuildContext context) {
    final theme = Theme.of(context);
    final preferencesModel = Provider.of<PreferencesModel>(context);
    final profiles = preferencesModel.savedProfiles;

    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              Icons.bookmark_add_outlined,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Save current answers as profile'),
            onTap: () => showSaveProfileDialog(context),
          ),
          if (profiles.isEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No profiles yet. Save one to reapply a whole set of '
                'answers — like "Solo weeknight" or "Date night" — in '
                'one tap.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ] else ...[
            const Divider(height: 1),
            for (int i = 0; i < profiles.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.bolt,
                  color: theme.colorScheme.primary,
                ),
                title: Text(profiles[i].name),
                subtitle: Text(profiles[i].summary),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete profile',
                  onPressed: () =>
                      preferencesModel.deleteProfile(profiles[i].id),
                ),
                onTap: () => _applyProfile(context, profiles[i]),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _applyProfile(
    BuildContext context,
    PreferenceProfile profile,
  ) async {
    final preferencesModel =
        Provider.of<PreferencesModel>(context, listen: false);
    await preferencesModel.applyProfile(profile);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          preferencesModel.arePreferencesComplete
              ? 'Applied "${profile.name}" — deal away!'
              : 'Applied "${profile.name}" — pick your mood in the '
                  'questionnaire to deal.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Build custom suggestions card
  Widget _buildCustomSuggestionsCard(BuildContext context) {
    final theme = Theme.of(context);
    final suggestionsRepo = Provider.of<SuggestionsRepository>(context);
    final customs = suggestionsRepo.customSuggestions;
    
    return Card(
      child: Column(
        children: [
          // Add new custom suggestion
          ListTile(
            leading: Icon(Icons.add_circle, color: theme.colorScheme.primary),
            title: const Text('Add Custom Suggestion'),
            onTap: () {
              _showAddCustomSuggestionDialog(context);
            },
          ),
          
          if (customs.isEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No custom suggestions yet',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your own activities to mix into the deal.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const Divider(height: 1),
            for (int i = 0; i < customs.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                leading: Icon(
                  customs[i].iconData,
                  color: theme.colorScheme.primary,
                ),
                title: Text(customs[i].title),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    _showRemoveCustomSuggestionDialog(
                      context,
                      customs[i].title,
                    );
                  },
                  tooltip: 'Remove custom suggestion',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
  
  // Show dialog to add custom suggestion
  void _showAddCustomSuggestionDialog(BuildContext context) {
    final suggestionsRepo = Provider.of<SuggestionsRepository>(context, listen: false);
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Custom Suggestion'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Activity',
            hintText: 'Enter your custom activity',
            border: OutlineInputBorder(),
          ),
          maxLength: SuggestionConstants.customSuggestionMaxLength,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final premium =
                  Provider.of<PremiumService>(context, listen: false)
                      .isPremium;
              final result = suggestionsRepo.addCustomSuggestionChecked(
                textController.text,
                maxCount: premium
                    ? SuggestionConstants.customSuggestionMaxCount
                    : SuggestionConstants.customSuggestionFreeMaxCount,
              );
              if (result == AddSuggestionResult.added) {
                Navigator.pop(dialogContext);
                return;
              }
              if (result == AddSuggestionResult.capReached && !premium) {
                // Free deck is full — the paywall explains the upgrade.
                Navigator.pop(dialogContext);
                showPaywall(context, featureName: 'Unlimited custom cards');
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(switch (result) {
                    AddSuggestionResult.invalid => 'Type an activity first.',
                    AddSuggestionResult.duplicate =>
                      'That one is already in the deck.',
                    _ => 'Your custom deck is full '
                        '(${SuggestionConstants.customSuggestionMaxCount} cards).',
                  }),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
  
  // Show dialog to remove custom suggestion
  void _showRemoveCustomSuggestionDialog(BuildContext context, String suggestion) {
    final suggestionsRepo = Provider.of<SuggestionsRepository>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Custom Suggestion'),
        content: Text('Are you sure you want to remove "$suggestion" from your custom suggestions?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              suggestionsRepo.removeCustomSuggestion(suggestion);
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
  
  // Build settings card
  Widget _buildSettingsCard(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          // Single entry point to the full Settings page (theme,
          // personalization, haptics, about, help). Lives here as a
          // convenience — the same page is reachable via the gear
          // icon on the Decide AppBar.
          ListTile(
            title: const Text('Settings'),
            subtitle: const Text(
              'Theme, weather, interests, haptics, and more',
            ),
            leading: const Icon(Icons.settings),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const SettingsPage(),
              ),
            ),
          ),
          const Divider(height: 1),
          // Destructive action kept one tap away — users reach for
          // it more often than buried-in-Settings would deserve.
          ListTile(
            title: const Text('Start over'),
            subtitle: const Text(
              'Reset your preferences and walk through the questionnaire again',
            ),
            leading: Icon(
              Icons.restart_alt,
              color: theme.colorScheme.primary,
            ),
            onTap: () => _showStartOverDialog(context),
          ),
        ],
      ),
    );
  }

  // Show start-over confirmation dialog. On confirm, reset preferences
  // and route the user through the questionnaire fresh.
  void _showStartOverDialog(BuildContext context) {
    final preferencesModel =
        Provider.of<PreferencesModel>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Start over?'),
        content: const Text(
          'This will clear your activity preference, mood, energy, '
          'time of day, and weirdness setting. Your favourites, '
          'history, and rejections are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              preferencesModel.resetPreferences();
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const QuestionnairePage(),
                ),
              );
            },
            child: const Text('Start over'),
          ),
        ],
      ),
    );
  }
  
}