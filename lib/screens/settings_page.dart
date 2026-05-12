import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/preferences_model.dart';
import '../services/context_service.dart';
import '../services/weather_service.dart';

/// Settings page with app configuration
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildThemeSettings(context),
          const Divider(),
          _buildPersonalizationSettings(context),
          const Divider(),
          _buildExperienceSettings(context),
          const Divider(),
          _buildAboutSettings(context),
        ],
      ),
    );
  }
  
  // Build theme settings section
  Widget _buildThemeSettings(BuildContext context) {
    final theme = Theme.of(context);
    final preferencesModel = Provider.of<PreferencesModel>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Appearance',
            style: theme.textTheme.titleLarge,
          ),
        ),
        SwitchListTile(
          title: const Text('Use System Theme'),
          subtitle: const Text('Follow system dark/light setting'),
          secondary: const Icon(Icons.settings_system_daydream),
          value: preferencesModel.useSystemTheme,
          onChanged: (value) {
            preferencesModel.updatePreference('useSystemTheme', value);
          },
        ),
        SwitchListTile(
          title: const Text('Dark Mode'),
          subtitle: const Text('Enable dark theme'),
          secondary: const Icon(Icons.dark_mode),
          value: preferencesModel.useDarkMode,
          onChanged: preferencesModel.useSystemTheme 
              ? null 
              : (value) {
                  preferencesModel.updatePreference('useDarkMode', value);
                },
        ),
      ],
    );
  }

  // Build decision-flow settings section
  Widget _buildExperienceSettings(BuildContext context) {
    final theme = Theme.of(context);
    final preferencesModel = Provider.of<PreferencesModel>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Experience',
            style: theme.textTheme.titleLarge,
          ),
        ),
        SwitchListTile(
          title: const Text('Haptic Feedback'),
          subtitle: const Text('Vibrate as cards land and flip'),
          secondary: const Icon(Icons.vibration),
          value: preferencesModel.enableHaptics,
          onChanged: (value) {
            preferencesModel.updatePreference('enableHaptics', value);
          },
        ),
        ListTile(
          title: const Text('Reset Preferences'),
          subtitle: const Text('Clear your activity preferences'),
          leading: const Icon(Icons.restore),
          onTap: () {
            _showResetPreferencesDialog(context);
          },
        ),
      ],
    );
  }

  // Build personalization section — toggles for context signals
  // (weather, location, time) that bias the deal. All are opt-in.
  Widget _buildPersonalizationSettings(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = Provider.of<PreferencesModel>(context);
    final weather = Provider.of<WeatherService>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Personalization',
            style: theme.textTheme.titleLarge,
          ),
        ),
        SwitchListTile(
          title: const Text('Weather-aware suggestions'),
          subtitle: Text(_weatherSubtitle(prefs, weather)),
          secondary: Icon(_weatherIcon(weather)),
          value: prefs.useWeather,
          onChanged: (value) {
            prefs.setPreference(PreferenceKey.useWeather, value);
            // When turning on, kick off a fetch immediately so the
            // user sees the subtitle update without waiting for the
            // next app launch.
            if (value && WeatherService.isConfigured) {
              weather.fetchWeather();
            }
          },
        ),
        SwitchListTile(
          title: const Text('Use my location'),
          subtitle: const Text(
            'Required for weather and (soon) nearby places',
          ),
          secondary: const Icon(Icons.my_location),
          value: prefs.useLocation,
          onChanged: (value) {
            prefs.setPreference(PreferenceKey.useLocation, value);
          },
        ),
        SwitchListTile(
          title: const Text('Auto-detect Time of Day'),
          subtitle: Text('Currently: ${ContextService.getCurrentTimeOfDay()}'),
          secondary: Icon(ContextService.getTimeIcon()),
          value: prefs.autoDetectTime,
          onChanged: (value) {
            prefs.updatePreference('autoDetectTime', value);
          },
        ),
      ],
    );
  }

  /// Build the subtitle for the weather toggle, reflecting service
  /// state so the user can see why their toggle isn't doing anything.
  String _weatherSubtitle(
    PreferencesModel prefs,
    WeatherService weather,
  ) {
    if (!WeatherService.isConfigured) {
      return 'Not configured — set OPENWEATHER_API_KEY at build time';
    }
    if (!prefs.useWeather) {
      return 'Let conditions outside bias the deal';
    }
    if (weather.isLoading) {
      return 'Fetching local weather…';
    }
    if (weather.error != null) {
      return weather.error!;
    }
    final data = weather.currentWeather;
    if (data == null) {
      return 'On — fetching on next deal';
    }
    final temp = data.temperature.round();
    final condition = _humanizeCondition(data.condition);
    return 'Currently: $condition, $temp°C';
  }

  IconData _weatherIcon(WeatherService weather) {
    final data = weather.currentWeather;
    if (data == null) return Icons.cloud_outlined;
    if (data.isRainy) return Icons.umbrella;
    if (data.isSnowy) return Icons.ac_unit;
    final c = data.condition.toLowerCase();
    if (c == 'clear') return Icons.wb_sunny;
    if (c.contains('cloud')) return Icons.cloud;
    return Icons.thermostat;
  }

  String _humanizeCondition(String condition) {
    if (condition.isEmpty) return 'Unknown';
    return condition[0].toUpperCase() + condition.substring(1).toLowerCase();
  }

  // Build about section
  Widget _buildAboutSettings(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'About',
            style: theme.textTheme.titleLarge,
          ),
        ),
        ListTile(
          title: const Text('About Decidr'),
          subtitle: const Text('Version 2.0.0'),
          leading: const Icon(Icons.info_outline),
          onTap: () {
            _showAboutDialog(context);
          },
        ),
        ListTile(
          title: const Text('Help & Feedback'),
          subtitle: const Text('Send us your thoughts'),
          leading: const Icon(Icons.help_outline),
          onTap: () {
            _showFeedbackDialog(context);
          },
        ),
      ],
    );
  }
  
  
  // Show reset preferences dialog
  void _showResetPreferencesDialog(BuildContext context) {
    final preferencesModel = Provider.of<PreferencesModel>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Preferences'),
        content: const Text('This will clear your activity preferences. Your favorites and history will not be affected. Continue?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              preferencesModel.resetPreferences();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Preferences have been reset'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Reset'),
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
          'Decidr helps you make decisions by dealing you three options. '
          'Get personalised activity suggestions based on your mood, '
          'energy, and time.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Enhanced with Material 3 design, dynamic themes, and personalized suggestions.',
        ),
      ],
    );
  }
  
  // Show feedback dialog
  void _showFeedbackDialog(BuildContext context) {
    final theme = Theme.of(context);
    final textController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('We\'d love to hear your thoughts on how to improve Decidr!'),
            const SizedBox(height: 16),
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'Your feedback',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
          ],
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Thanks for your feedback!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}