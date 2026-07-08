import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/suggestion.dart';
import '../models/suggestions_repository.dart';
import '../utils/challenge_codec.dart';
import 'main_tabs_page.dart';
import 'welcome_page.dart';

/// Landing page for a shared "same hand" challenge link.
///
/// Recomputes the deterministic hand from the payload's deal inputs
/// and seed against the canonical pipeline (no personal state, no
/// customs, no feedback), so every recipient of the same link draws
/// the same three cards — and sees what the sender drew.
class ChallengePage extends StatelessWidget {
  final ChallengePayload payload;

  const ChallengePage({super.key, required this.payload});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = Provider.of<SuggestionsRepository>(context, listen: false);

    final hand = repo.getStructuredSuggestions(
      activityType: payload.activityType,
      mood: payload.mood,
      timeOfDay: payload.timeOfDay,
      energyLevel: payload.energyLevel,
      weirdnessTolerance: payload.weirdnessTolerance,
      includeCustom: false,
      includeFavorites: false,
      count: 3,
      shuffleSeed: payload.seed,
    );
    final theirs = repo.resolveById(payload.chosenId);
    final yours = hand.length > 1 ? hand[1] : hand.firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('A challenge for you')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your friend drew:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _cardTile(theme, theirs, highlight: false),
            const SizedBox(height: 24),
            Text(
              'The same hand dealt you:',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (hand.isEmpty)
              Text(
                'This hand couldn’t be re-dealt — the deck may have '
                'changed since the link was made.',
                style: theme.textTheme.bodyMedium,
              )
            else ...[
              for (final s in hand) ...[
                _cardTile(theme, s, highlight: s.id == yours?.id),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 4),
              Text(
                'The middle card is yours. Do it, or come get a hand '
                'of your own.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const WelcomePage(),
                  ),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.style),
              label: const Text('Deal me my own hand'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardTile(ThemeData theme, Suggestion s, {required bool highlight}) {
    return Card(
      elevation: highlight ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: highlight
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        leading: Icon(s.iconData, color: theme.colorScheme.primary),
        title: Text(s.title),
        subtitle: s.description.isEmpty
            ? null
            : Text(
                s.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
        trailing: highlight
            ? Icon(Icons.star, color: theme.colorScheme.primary)
            : null,
      ),
    );
  }
}

/// Resolve a `/deal` route: with a valid challenge parameter, the
/// challenge page; otherwise straight into the app (tabs when the
/// questionnaire is complete, welcome otherwise) — skipping the
/// splash-then-welcome gauntlet that PWA shortcuts shouldn't pay.
Widget dealRouteTarget(BuildContext context, Uri uri) {
  final encoded = uri.queryParameters['c'];
  if (encoded != null) {
    final payload = ChallengePayload.decode(encoded);
    if (payload != null) return ChallengePage(payload: payload);
  }
  return const MainTabsPage();
}
