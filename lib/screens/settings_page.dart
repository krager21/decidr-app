import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/deck_themes.dart';
import '../models/preferences_model.dart';
import '../services/context_service.dart';
import '../services/weather_service.dart';
import 'interests_picker_page.dart';

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
        _buildDeckPicker(context, theme, preferencesModel),
      ],
    );
  }

  /// Horizontal scroller of card-back theme previews. Tap to select.
  /// Premium decks route through [_showPremiumComingSoonDialog] today;
  /// Phase 4 swaps that for the real paywall.
  Widget _buildDeckPicker(
    BuildContext context,
    ThemeData theme,
    PreferencesModel prefs,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.style,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Card deck',
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: deckThemes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final deck = deckThemes[i];
                final isSelected = prefs.colorTheme == deck.id;
                return _buildDeckPreview(
                  context,
                  theme,
                  deck,
                  isSelected,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// One deck preview tile — a mini card-back replica with the deck
  /// name and a "Premium" lock chip when applicable.
  Widget _buildDeckPreview(
    BuildContext context,
    ThemeData theme,
    DeckTheme deck,
    bool isSelected,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _selectDeck(context, deck),
      child: SizedBox(
        width: 84,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 110,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [deck.back1, deck.back2],
                ),
                border: Border.all(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : deck.accent.withValues(alpha: 0.5),
                  width: isSelected ? 2.5 : 1,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: deck.accent.withValues(alpha: 0.45),
                        width: 1,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.auto_awesome,
                    size: 16,
                    color: deck.accent,
                  ),
                  if (deck.isPremium)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.55),
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              deck.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Apply [deck] if it's free; otherwise route through the (stub for
  /// now) premium gate. Phase 4 replaces the dialog with the real
  /// paywall once entitlements are wired.
  void _selectDeck(BuildContext context, DeckTheme deck) {
    final prefs = Provider.of<PreferencesModel>(context, listen: false);
    if (!deck.isPremium) {
      prefs.setPreference(PreferenceKey.colorTheme, deck.id);
      return;
    }
    _showPremiumComingSoonDialog(context, deck);
  }

  void _showPremiumComingSoonDialog(BuildContext context, DeckTheme deck) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decidr Premium'),
        content: Text(
          'The "${deck.name}" deck is part of Decidr Premium — coming '
          'soon. We\u2019ll let you know when it lands.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
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
        ListTile(
          title: const Text('Your interests'),
          subtitle: Text(
            prefs.userInterests.isEmpty
                ? 'Tag what you\u2019re into — biases the deal'
                : '${prefs.userInterests.length} selected',
          ),
          leading: const Icon(Icons.interests),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const InterestsPickerPage(),
              ),
            );
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