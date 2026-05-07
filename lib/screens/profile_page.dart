import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/preferences_model.dart';
import '../models/suggestions_repository.dart';
import '../models/activity_history_model.dart';
import 'questionnaire_page.dart';
import '../utils/constants.dart';
import '../utils/decidr_theme.dart';

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
    final theme = Theme.of(context);
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
            subtitle: Text(preferencesModel.timeOfDay ?? 'Not set'),
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
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No favorites yet',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add activities to your favorites by tapping the heart icon on the suggestions.',
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
            ListTile(
              leading: Icon(
                suggestionsRepo.getIconForSuggestion(favorites[i]),
                color: theme.colorScheme.primary,
              ),
              title: Text(favorites[i]),
              trailing: IconButton(
                icon: const Icon(Icons.favorite, color: Colors.red),
                onPressed: () {
                  preferencesModel.toggleFavorite(favorites[i]);
                },
                tooltip: 'Remove from favorites',
              ),
            ),
          ],
        ],
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
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No custom suggestions yet',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your own activity suggestions to include in the wheel.',
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
                  suggestionsRepo.getIconForSuggestion(customs[i]),
                  color: theme.colorScheme.primary,
                ),
                title: Text(customs[i]),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    _showRemoveCustomSuggestionDialog(context, customs[i]);
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
    final theme = Theme.of(context);
    final suggestionsRepo = Provider.of<SuggestionsRepository>(context, listen: false);
    final textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final added = suggestionsRepo.addCustomSuggestion(
                textController.text,
              );
              if (added) {
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not add suggestion (empty, duplicate, or list full).',
                    ),
                  ),
                );
              }
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
    final preferencesModel = Provider.of<PreferencesModel>(context);
    
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            title: const Text('Dark Mode'),
            subtitle: const Text('Enable dark theme'),
            secondary: const Icon(Icons.dark_mode),
            value: preferencesModel.useDarkMode,
            onChanged: (value) {
              preferencesModel.updatePreference('useDarkMode', value);
              preferencesModel.updatePreference('useSystemTheme', false);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Use System Theme'),
            subtitle: const Text('Follow system dark/light setting'),
            secondary: const Icon(Icons.settings_system_daydream),
            value: preferencesModel.useSystemTheme,
            onChanged: (value) {
              preferencesModel.updatePreference('useSystemTheme', value);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            subtitle: const Text('Enable vibration when wheel stops'),
            secondary: const Icon(Icons.vibration),
            value: preferencesModel.enableHaptics,
            onChanged: (value) {
              preferencesModel.updatePreference('enableHaptics', value);
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('Wheel Color Theme'),
            subtitle: Text(preferencesModel.colorTheme),
            leading: const Icon(Icons.color_lens),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showColorThemeDialog(context);
            },
          ),
          const Divider(height: 1),
          ListTile(
            title: const Text('About Decidr'),
            subtitle: const Text('Version 2.0.0'),
            leading: const Icon(Icons.info_outline),
            onTap: () {
              _showAboutDialog(context);
            },
          ),
        ],
      ),
    );
  }
  
  // Show color theme dialog
  void _showColorThemeDialog(BuildContext context) {
    final theme = Theme.of(context);
    final preferencesModel = Provider.of<PreferencesModel>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Wheel Color Theme'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: preferencesModel.themeOptions.length,
            itemBuilder: (context, index) {
              final option = preferencesModel.themeOptions[index];
              final isSelected = preferencesModel.colorTheme.toLowerCase() == option.toLowerCase();
              final colors = DecidrTheme.getWheelColors(option.toLowerCase());
              
              return ListTile(
                title: Text(option),
                selected: isSelected,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: colors.take(4).toList(),
                    ),
                  ),
                ),
                trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
                onTap: () {
                  preferencesModel.updatePreference('colorTheme', option.toLowerCase());
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  // Show about dialog
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Decidr',
      applicationVersion: '2.0.0',
      applicationIcon: Icon(
        Icons.shuffle_rounded,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
      applicationLegalese: '© 2025 Decidr App',
      children: [
        const SizedBox(height: 16),
        const Text(
          'Decidr helps you make decisions with a fun spin of the wheel! '
          'Get personalized suggestions based on your preferences and mood.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Enhanced with Material 3 design, dynamic themes, and personalized suggestions.',
        ),
      ],
    );
  }
}