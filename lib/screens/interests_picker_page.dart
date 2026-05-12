import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/preferences_model.dart';
import '../models/suggestion.dart';

/// Lets the user tag the interests they're into.
///
/// Their picks soft-bias the deal via a Jaccard overlap multiplier
/// inside `SuggestionsRepository.getStructuredSuggestions`. Picking
/// nothing is fine — the multiplier collapses to 1.0 and behavior is
/// unchanged.
///
/// Reachable from Settings → Personalization → "Your interests" and
/// from the post-first-deal soft prompt banner. Persists on close.
class InterestsPickerPage extends StatefulWidget {
  const InterestsPickerPage({super.key});

  @override
  State<InterestsPickerPage> createState() => _InterestsPickerPageState();
}

class _InterestsPickerPageState extends State<InterestsPickerPage> {
  /// Local working set so toggles feel instant — we only persist on
  /// "Done" (or back nav, treated as save).
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    final prefs = Provider.of<PreferencesModel>(context, listen: false);
    _selected = prefs.userInterests.toSet();
  }

  /// Hand-curated groupings of the canonical [Interests] values into
  /// 6 sections. Adding a new interest in `suggestion.dart` requires
  /// extending the appropriate group here too — otherwise it won't
  /// surface in the picker.
  static const List<_InterestGroup> _groups = [
    _InterestGroup('Active & outdoors', Icons.terrain, [
      Interests.nature,
      Interests.fitness,
      Interests.sports,
      Interests.walking,
      Interests.adventure,
      Interests.exploration,
    ]),
    _InterestGroup('Creative & making', Icons.palette, [
      Interests.art,
      Interests.music,
      Interests.writing,
      Interests.photography,
      Interests.crafts,
      Interests.creativity,
    ]),
    _InterestGroup('Mind & body', Icons.self_improvement, [
      Interests.reading,
      Interests.learning,
      Interests.mindfulness,
      Interests.wellness,
    ]),
    _InterestGroup('Food & home', Icons.local_dining, [
      Interests.food,
      Interests.cooking,
      Interests.home,
      Interests.gardening,
    ]),
    _InterestGroup('People & community', Icons.people, [
      Interests.social,
      Interests.connection,
      Interests.community,
      Interests.family,
    ]),
    _InterestGroup('More', Icons.more_horiz, [
      Interests.productivity,
      Interests.games,
      Interests.tech,
      Interests.culture,
    ]),
  ];

  void _toggle(String interest) {
    setState(() {
      if (_selected.contains(interest)) {
        _selected.remove(interest);
      } else {
        _selected.add(interest);
      }
    });
  }

  Future<void> _saveAndPop() async {
    final prefs = Provider.of<PreferencesModel>(context, listen: false);
    prefs.setPreference(
      PreferenceKey.userInterests,
      _selected.toList(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope<Object?>(
      canPop: true,
      // Treat back-nav as save — picks are persisted even if the user
      // doesn't tap "Done". Fires after the pop is committed; context
      // is still valid for reading the provider synchronously.
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) return;
        final prefs = Provider.of<PreferencesModel>(context, listen: false);
        prefs.setPreference(
          PreferenceKey.userInterests,
          _selected.toList(),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Your interests'),
          actions: [
            TextButton(
              onPressed: _saveAndPop,
              child: const Text('Done'),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
              child: Text(
                _selected.isEmpty
                    ? 'Tap what you\u2019re into — we\u2019ll deal you '
                        'more cards that match.'
                    : '${_selected.length} selected — these gently bias '
                        'the deal toward cards that fit.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            for (final group in _groups) _buildGroup(theme, group),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(ThemeData theme, _InterestGroup group) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(group.icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                group.title,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.interests.map((interest) {
              final selected = _selected.contains(interest);
              return FilterChip(
                label: Text(_label(interest)),
                selected: selected,
                onSelected: (_) => _toggle(interest),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Display-cased label for an interest constant.
  /// `'nature'` → `'Nature'`. Two-word fallbacks for the few
  /// non-obvious ones.
  String _label(String interest) {
    if (interest.isEmpty) return interest;
    return interest[0].toUpperCase() + interest.substring(1);
  }
}

class _InterestGroup {
  final String title;
  final IconData icon;
  final List<String> interests;
  const _InterestGroup(this.title, this.icon, this.interests);
}
