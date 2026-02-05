import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/preferences_model.dart';
import '../utils/decidr_theme.dart';
import '../services/context_service.dart';

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
          _buildWheelSettings(context),
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
        ListTile(
          title: const Text('Wheel Color Theme'),
          subtitle: Text(preferencesModel.colorTheme),
          leading: const Icon(Icons.color_lens),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            _showColorThemeDialog(context);
          },
        ),
      ],
    );
  }
  
  // Build wheel settings section
  Widget _buildWheelSettings(BuildContext context) {
    final theme = Theme.of(context);
    final preferencesModel = Provider.of<PreferencesModel>(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Wheel Experience',
            style: theme.textTheme.titleLarge,
          ),
        ),
        SwitchListTile(
          title: const Text('Haptic Feedback'),
          subtitle: const Text('Enable vibration when wheel stops'),
          secondary: const Icon(Icons.vibration),
          value: preferencesModel.enableHaptics,
          onChanged: (value) {
            preferencesModel.updatePreference('enableHaptics', value);
          },
        ),
        SwitchListTile(
          title: const Text('Auto-detect Time of Day'),
          subtitle: Text('Currently: ${ContextService.getCurrentTimeOfDay()}'),
          secondary: Icon(ContextService.getTimeIcon()),
          value: preferencesModel.autoDetectTime,
          onChanged: (value) {
            preferencesModel.updatePreference('autoDetectTime', value);
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