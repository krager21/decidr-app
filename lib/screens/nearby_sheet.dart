import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/place_categories.dart';
import '../models/nearby_place.dart';
import '../models/suggestion.dart';
import '../services/places_service.dart';

/// Bottom-sheet listing places of a specific [PlaceCategory] near
/// the user — fired from a "go out" card's Nearby button on the
/// settled state.
///
/// The single category comes from [Suggestion.goOutCategory], so a
/// "Try a new café" card surfaces cafés, "Find a park you haven't
/// visited" surfaces parks, etc. No interest-resolution surprises:
/// the card declares the intent, the sheet honors it.
///
/// Open via [showNearbySheet]. Don't construct directly.
class _NearbySheet extends StatefulWidget {
  final Suggestion suggestion;
  final PlaceCategory category;

  const _NearbySheet({
    required this.suggestion,
    required this.category,
  });

  @override
  State<_NearbySheet> createState() => _NearbySheetState();
}

class _NearbySheetState extends State<_NearbySheet> {
  late final Future<List<NearbyPlace>> _future;

  @override
  void initState() {
    super.initState();
    final service = Provider.of<PlacesService>(context, listen: false);
    _future = service.fetchNearby(category: widget.category);
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
                    Icon(
                      widget.category.icon,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nearby ${widget.category.label.toLowerCase()}',
                            style: theme.textTheme.titleLarge,
                          ),
                          Text(
                            'For \u201c${widget.suggestion.title}\u201d',
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
                child: FutureBuilder<List<NearbyPlace>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _buildError(theme, snapshot.error.toString());
                    }
                    final places = snapshot.data ?? const <NearbyPlace>[];
                    if (places.isEmpty) {
                      return _buildEmpty(theme);
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: places.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                      itemBuilder: (context, i) =>
                          _buildPlaceTile(theme, places[i]),
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

  Widget _buildPlaceTile(ThemeData theme, NearbyPlace place) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openInMaps(place),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
              'No ${widget.category.label.toLowerCase()} found within '
              'two kilometres. Try a wider trip another day.',
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

/// Convenience helper to show the Nearby sheet for a single
/// [PlaceCategory] derived from the chosen card. Returns the
/// future from `showModalBottomSheet`.
Future<void> showNearbySheet(
  BuildContext context, {
  required Suggestion suggestion,
  required PlaceCategory category,
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
      category: category,
    ),
  );
}
