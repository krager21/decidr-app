import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/feedback_model.dart';
import '../models/preferences_model.dart';
import '../models/suggestion.dart';
import '../models/suggestions_repository.dart';

/// Browse the full shipped deck — the ~550 cards that are otherwise
/// visible only three at a time.
///
/// Grouped by interest (a card appears in every section it's tagged
/// with; untagged cards land in "Everything else"), searchable, with
/// pre-emptive hearts (favorite before it's ever dealt) and bans
/// (dislike = never deal this).
class CatalogBrowserPage extends StatefulWidget {
  const CatalogBrowserPage({super.key});

  @override
  State<CatalogBrowserPage> createState() => _CatalogBrowserPageState();
}

class _CatalogBrowserPageState extends State<CatalogBrowserPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final repo = Provider.of<SuggestionsRepository>(context);
    final cards = repo.catalog;

    return Scaffold(
      appBar: AppBar(title: const Text('Browse the Deck')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search ${cards.length} cards…',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                isDense: true,
              ),
              onChanged: (q) => setState(() => _query = q.trim()),
            ),
          ),
          Expanded(
            child: _query.isEmpty
                ? _buildSections(cards)
                : _buildSearchResults(cards),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<Suggestion> cards) {
    final q = _query.toLowerCase();
    final hits = cards
        .where((s) =>
            s.title.toLowerCase().contains(q) ||
            s.description.toLowerCase().contains(q) ||
            s.tags.any((t) => t.contains(q)))
        .toList();
    if (hits.isEmpty) {
      return const Center(child: Text('Nothing in the deck matches.'));
    }
    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (context, i) => _CardTile(suggestion: hits[i]),
    );
  }

  Widget _buildSections(List<Suggestion> cards) {
    final bySection = <String, List<Suggestion>>{};
    for (final s in cards) {
      if (s.interests.isEmpty) {
        bySection.putIfAbsent('Everything else', () => []).add(s);
      } else {
        for (final i in s.interests) {
          bySection.putIfAbsent(i, () => []).add(s);
        }
      }
    }
    // Interests in taxonomy order, "Everything else" last.
    final sections = [
      for (final i in Interests.all)
        if (bySection.containsKey(i)) i,
      if (bySection.containsKey('Everything else')) 'Everything else',
    ];
    return ListView.builder(
      itemCount: sections.length,
      itemBuilder: (context, i) {
        final section = sections[i];
        final items = bySection[section]!;
        return ExpansionTile(
          title: Text(
            section == 'Everything else'
                ? section
                : section[0].toUpperCase() + section.substring(1),
          ),
          subtitle: Text('${items.length} cards'),
          children: [
            for (final s in items) _CardTile(suggestion: s),
          ],
        );
      },
    );
  }
}

class _CardTile extends StatelessWidget {
  final Suggestion suggestion;

  const _CardTile({required this.suggestion});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prefs = Provider.of<PreferencesModel>(context);
    final feedback = Provider.of<FeedbackModel>(context);
    final isFav = prefs.isFavorite(suggestion.id);
    final isBanned = feedback.isDisliked(suggestion.id);

    return ListTile(
      leading: Icon(
        suggestion.iconData,
        color: isBanned
            ? theme.colorScheme.outline
            : theme.colorScheme.primary,
      ),
      title: Text(
        suggestion.title,
        style: isBanned
            ? TextStyle(
                decoration: TextDecoration.lineThrough,
                color: theme.colorScheme.outline,
              )
            : null,
      ),
      subtitle: suggestion.description.isEmpty
          ? null
          : Text(
              suggestion.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.red : theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
            onPressed: () => prefs.toggleFavorite(suggestion.id),
          ),
          IconButton(
            icon: Icon(
              isBanned ? Icons.block : Icons.block_outlined,
              color: isBanned
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
            tooltip: isBanned ? 'Allow again' : 'Never deal this',
            onPressed: () {
              if (isBanned) {
                feedback.clearFeedback(suggestion.id);
              } else {
                feedback.dislikeActivity(suggestion.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
