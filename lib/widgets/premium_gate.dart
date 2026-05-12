import 'package:flutter/material.dart';

/// Placeholder "coming soon" dialog used until Phase 4 (RevenueCat
/// paywall) lands. Every premium feature trigger today routes
/// through this — themed decks, nearby places, and anything that
/// follows. Phase 5 will swap the body for an actual paywall route.
///
/// [featureName] appears inline in the message so the dialog says
/// what's gated, e.g. *"Nearby places is part of Decidr Premium…"*.
///
/// Returns the showDialog future so callers can await dismissal.
Future<void> showPremiumComingSoonDialog(
  BuildContext context, {
  required String featureName,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Decidr Premium'),
      content: Text(
        '$featureName is part of Decidr Premium — coming soon. '
        'We\u2019ll let you know when it lands.',
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

/// Whether the user has unlocked premium features.
///
/// Stub for Phase 3/6 — always returns false. Phase 4 replaces this
/// with a real check against the entitlements service so the same
/// call sites continue to work.
bool hasPremium() => false;
