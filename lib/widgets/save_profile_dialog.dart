import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/preferences_model.dart';
import '../services/premium_service.dart';
import '../utils/constants.dart';
import 'paywall_sheet.dart';

/// Prompt for a name and save the current questionnaire answers as a
/// [PreferenceProfile]. Shared by the questionnaire's "save these
/// answers" affordance and the profile page's profiles card.
///
/// Free tier keeps [SuggestionConstants.savedProfilesFreeMaxCount]
/// profiles; hitting the cap routes to the Premium paywall.
Future<void> showSaveProfileDialog(BuildContext context) {
  final textController = TextEditingController();

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Save as profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Name this set of answers so you can re-apply it in one '
            'tap — "Solo weeknight", "Date night", "Rainy Sunday"…',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: textController,
            autofocus: true,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: 'Profile name',
              hintText: 'e.g. Date night',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final prefs = Provider.of<PreferencesModel>(
              context,
              listen: false,
            );
            final premiumService = Provider.of<PremiumService>(
              context,
              listen: false,
            );
            final name = textController.text;
            var result = await prefs.saveCurrentAsProfile(
              name,
              maxCount: premiumService.isPremium
                  ? SuggestionConstants.savedProfilesMaxCount
                  : SuggestionConstants.savedProfilesFreeMaxCount,
            );
            if (!dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            if (!context.mounted) return;
            if (result == SaveProfileResult.capReached &&
                !premiumService.isPremium) {
              // Show the paywall — and if they upgrade right here,
              // save the profile they typed instead of losing it.
              await showPaywall(context, featureName: 'More saved profiles');
              if (!premiumService.isPremium) return;
              result = await prefs.saveCurrentAsProfile(
                name,
                maxCount: SuggestionConstants.savedProfilesMaxCount,
              );
              if (!context.mounted) return;
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(switch (result) {
                  SaveProfileResult.saved =>
                    'Saved "${name.trim()}" — reapply it any time.',
                  SaveProfileResult.invalid => 'Give the profile a name.',
                  SaveProfileResult.duplicate =>
                    'You already have a profile with that name.',
                  SaveProfileResult.capReached =>
                    'Profile limit reached '
                        '(${SuggestionConstants.savedProfilesMaxCount}).',
                }),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
}
