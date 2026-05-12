import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/interest_places_map.dart';
import '../data/place_categories.dart';
import '../models/nearby_place.dart';
import '../models/suggestion.dart';
import '../services/places_service.dart';

/// Bottom-sheet listing places near the user that match the
/// interests of the suggestion they just landed on.
///
/// Designed in *sections* — currently one section per
/// [PlaceCategory], but the structure leaves room for future
/// "Featured" or curated recommendation sections that don't come
/// from OSM. Each section header carries an icon, label, and count;
/// each tile shows name + optional address + distance + a tap to
/// open in Maps.
///
/// Opens via [showNearbySheet]. Don't construct directly.
class _NearbySheet extends StatefulWidget {
  final Suggestion suggestion;

  /// User's tagged interests, unioned with the suggestion's
  /// interests when resolving which place categories to query.
  /// An empty list still works — the suggestion's own interests
  /// drive the query alone.
  final List<String> userInterests;

  const _NearbySheet({
    required this.suggestion,
    required this.userInterests,
  });

  @override
  State<_NearbySheet> createState() => _NearbySheetState();
}

class _NearbySheetState extends State<_NearbySheet> {
  late final Future<Map<PlaceCategory, List<NearbyPlace>>> _future;

  /// How many distinct place categories we fetch per open. Top-N
  /// keeps the sheet skimmable and the Overpass calls bounded.
  static const _maxCategories = 3;

  @override
  void initState() {
    super.initState();
    final categories = _resolve();
    final service = Provider.of<PlacesService>(context, listen: false);
    _future = service.fetchForCategories(categories: categories);
  }

  /// Resolve which [PlaceCategory] values to query based on (a)
  /// the chosen suggestion's interests and (b) the user's interests.
  /// Categories matching the chosen card outrank user-only matches
  /// via the vote-count in `resolveCategories`.
  List<PlaceCategory> _resolve() {
    final all = <String>{
      ...widget.suggestion.interests,
      ...widget.userInterests,
    };
    final ranked = resolveCategories(all);
    return ranked.take(_maxCategories).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.62,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Drag handle.
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Row(
                  children: [
                    Icon(Icons.near_me, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nearby',
                            style: theme.textTheme.titleLarge,
                          ),
                          Text(
                            'Based on \u201c${widget.suggestion.title}\u201d',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<Map<PlaceCategory, List<NearbyPlace>>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _buildError(theme, snapshot.error.toString());
                    }
                    final results = snapshot.data ?? const {};
                    if (results.isEmpty) {
                      return _buildEmpty(theme);
                    }
                    return _buildSections(
                      theme,
                      results,
                      scrollController,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSections(
    ThemeData theme,
    Map<PlaceCategory, List<NearbyPlace>> sections,
    ScrollController scrollController,
  ) {
    final entries = sections.entries.toList();
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: entries.length,
      itemBuilder: (context, sectionIndex) {
        final cat = entries[sectionIndex].key;
        final places = entries[sectionIndex].value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(cat.icon, size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      cat.label,
                      style: theme.textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      '${places.length}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              ...places.take(5).map((p) => _buildPlaceTile(theme, p)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceTile(ThemeData theme, NearbyPlace place) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _openInMaps(place),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              place.category.icon,
              size: 22,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (place.address != null)
                    Text(
                      place.address!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  place.formattedDistance,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.travel_explore,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing nearby for this one',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Try a different card, or pick more interests in Settings.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(ThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'Couldn\u2019t find nearby places right now',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInMaps(NearbyPlace place) async {
    final url = Uri.parse(place.mapsUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

/// Convenience helper to show the Nearby sheet — pass the chosen
/// [Suggestion] and the user's tagged interests. Returns the
/// future from `showModalBottomSheet`.
Future<void> showNearbySheet(
  BuildContext context, {
  required Suggestion suggestion,
  required List<String> userInterests,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _NearbySheet(
      suggestion: suggestion,
      userInterests: userInterests,
    ),
  );
}
