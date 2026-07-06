import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/deck_themes.dart';
import '../models/preferences_model.dart';
import '../services/context_service.dart';
import '../services/premium_service.dart';
import '../services/weather_service.dart';
import '../utils/constants.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/premium_gate.dart';
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
          _buildPremiumSettings(context),
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
  /// Premium decks route through the paywall via [ensurePremium].
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

  /// Apply [deck] if it's free or the user is premium; otherwise
  /// route through the paywall — and apply the deck anyway if the
  /// user upgrades mid-flow, completing their original intent.
  Future<void> _selectDeck(BuildContext context, DeckTheme deck) async {
    final prefs = Provider.of<PreferencesModel>(context, listen: false);
    if (deck.isPremium &&
        !await ensurePremium(
          context,
          featureName: 'The "${deck.name}" deck',
        )) {
      return;
    }
    prefs.setPreference(PreferenceKey.colorTheme, deck.id);
  }

  /// Premium status + purchase entry points. The paywall itself
  /// handles the "store not configured in this build" state, so this
  /// section can always offer the upgrade row.
  Widget _buildPremiumSettings(BuildContext context) {
    final theme = Theme.of(context);
    final premium = Provider.of<PremiumService>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Decidr Premium',
            style: theme.textTheme.titleLarge,
          ),
        ),
        if (premium.isPremium) ...[
          ListTile(
            leading: Icon(
              Icons.auto_awesome,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Premium active'),
            subtitle: const Text(
              'Themed decks, Nearby places, unlimited custom cards',
            ),
            trailing: Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
            ),
          ),
          if (premium.storeAvailable)
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: const Text('Manage subscription'),
              onTap: () => _openSubscriptionManagement(context, premium),
            ),
        ] else ...[
          ListTile(
            leading: Icon(
              Icons.auto_awesome,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Upgrade to Premium'),
            subtitle: const Text(
              'Themed decks, Nearby places, unlimited custom cards',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showPaywall(context),
          ),
          if (premium.storeAvailable)
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restore purchases'),
              subtitle: const Text('Bought Premium on another device?'),
              onTap: () => _restorePurchases(context, premium),
            ),
        ],
      ],
    );
  }

  Future<void> _openSubscriptionManagement(
    BuildContext context,
    PremiumService premium,
  ) async {
    final url = await premium.managementUrl();
    if (url == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Manage your subscription in your app store.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Nothing useful to do — the store settings remain reachable
      // through the OS.
    }
  }

  Future<void> _restorePurchases(
    BuildContext context,
    PremiumService premium,
  ) async {
    final restored = await premium.restore();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          restored
              ? 'Premium restored — welcome back!'
              : 'No previous purchases found.',
        ),
        behavior: SnackBarBehavior.floating,
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
            // next app launch. Weather reads the device GPS, so it
            // also requires the location consent toggle.
            if (value && prefs.useLocation && WeatherService.isConfigured) {
              weather.fetchWeather();
            }
          },
        ),
        SwitchListTile(
          title: const Text('Use my location'),
          subtitle: const Text(
            'Required for weather and nearby places',
          ),
          secondary: const Icon(Icons.my_location),
          value: prefs.useLocation,
          onChanged: (value) {
            prefs.setPreference(PreferenceKey.useLocation, value);
            // Granting location consent while weather is already on
            // unblocks the pending fetch.
            if (value && prefs.useWeather && WeatherService.isConfigured) {
              weather.fetchWeather();
            }
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
    if (!prefs.useLocation) {
      return 'Turn on “Use my location” below to fetch weather';
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
          subtitle: const Text('Version ${AppConstants.appVersion}'),
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
      applicationName: AppConstants.appName,
      applicationVersion: AppConstants.appVersion,
      applicationIcon: Icon(
        Icons.shuffle_rounded,
        size: 48,
        color: Theme.of(context).colorScheme.primary,
      ),
      applicationLegalese: AppConstants.appLegalese,
      children: [
        const SizedBox(height: 16),
        const Text(AppConstants.appDescription),
        const SizedBox(height: 16),
        const Text(AppConstants.appEnhancedFeatures),
      ],
    );
  }
  
  /// Feedback goes out as a real email — Send opens the user's mail
  /// app with their text pre-filled. (The old dialog claimed to send
  /// and silently discarded the text.)
  void _showFeedbackDialog(BuildContext context) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final body = textController.text.trim();
              Navigator.pop(dialogContext);
              final uri = Uri(
                scheme: 'mailto',
                path: AppConstants.supportEmail,
                query: 'subject=${Uri.encodeComponent('Decidr feedback')}'
                    '&body=${Uri.encodeComponent(body)}',
              );
              try {
                await launchUrl(uri);
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'No mail app found — reach us at '
                      '${AppConstants.supportEmail}.',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}