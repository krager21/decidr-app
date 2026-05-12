import '../models/suggestion.dart';
import 'place_categories.dart';

/// Map from a canonical [Interests] string to the [PlaceCategory] list
/// it should surface in the Nearby bottom sheet.
///
/// Used by the resolver to translate "the chosen card is tagged
/// `reading`" into "show libraries, bookstores, cafes." Multiple
/// interests union their categories. Interests with no good OSM
/// counterpart (`crafts`, `home`, `games`, `tech`) intentionally
/// map to an empty list — the resolver drops them.
///
/// Order within each list signals priority: the first category is the
/// strongest match and surfaces first in the bottom sheet groups.
///
/// **Extension point:** the Nearby sheet is designed to render an
/// arbitrary number of *sections*. Today there's one section type
/// (places-by-category, fed by this map and the OSM-backed
/// PlacesService). Future work could add a "Featured" or "Try this"
/// section (curated picks, partner events) without touching this
/// file — each new section gets its own resolver and data source.
const Map<String, List<PlaceCategory>> interestPlaces = {
  // Active / outdoors
  Interests.nature: [
    PlaceCategory.park,
    PlaceCategory.garden,
    PlaceCategory.viewpoint,
  ],
  Interests.fitness: [
    PlaceCategory.gym,
    PlaceCategory.sportsCentre,
    PlaceCategory.swimmingPool,
  ],
  Interests.sports: [
    PlaceCategory.sportsCentre,
    PlaceCategory.swimmingPool,
    PlaceCategory.gym,
  ],
  Interests.walking: [
    PlaceCategory.park,
    PlaceCategory.viewpoint,
    PlaceCategory.garden,
  ],
  Interests.adventure: [
    PlaceCategory.viewpoint,
    PlaceCategory.park,
  ],
  Interests.exploration: [
    PlaceCategory.museum,
    PlaceCategory.gallery,
    PlaceCategory.viewpoint,
  ],

  // Creative / making
  Interests.art: [
    PlaceCategory.gallery,
    PlaceCategory.museum,
  ],
  Interests.music: [
    PlaceCategory.musicVenue,
    PlaceCategory.theatre,
    PlaceCategory.bar,
  ],
  Interests.writing: [
    PlaceCategory.library,
    PlaceCategory.cafe,
    PlaceCategory.bookstore,
  ],
  Interests.photography: [
    PlaceCategory.viewpoint,
    PlaceCategory.park,
    PlaceCategory.museum,
  ],
  Interests.crafts: <PlaceCategory>[], // no clean OSM equivalent
  Interests.creativity: [
    PlaceCategory.gallery,
    PlaceCategory.museum,
  ],

  // Mind / learning
  Interests.reading: [
    PlaceCategory.library,
    PlaceCategory.bookstore,
    PlaceCategory.cafe,
  ],
  Interests.learning: [
    PlaceCategory.library,
    PlaceCategory.museum,
    PlaceCategory.gallery,
  ],
  Interests.mindfulness: [
    PlaceCategory.park,
    PlaceCategory.garden,
  ],

  // Food & home
  Interests.food: [
    PlaceCategory.restaurant,
    PlaceCategory.cafe,
  ],
  Interests.cooking: [
    PlaceCategory.restaurant,
    PlaceCategory.cafe,
  ],
  Interests.home: <PlaceCategory>[], // no clean OSM equivalent
  Interests.gardening: [
    PlaceCategory.garden,
    PlaceCategory.park,
  ],

  // People / community
  Interests.social: [
    PlaceCategory.bar,
    PlaceCategory.pub,
    PlaceCategory.cafe,
    PlaceCategory.restaurant,
  ],
  Interests.connection: [
    PlaceCategory.cafe,
    PlaceCategory.restaurant,
    PlaceCategory.bar,
  ],
  Interests.community: [
    PlaceCategory.library,
    PlaceCategory.park,
    PlaceCategory.playground,
  ],
  Interests.family: [
    PlaceCategory.playground,
    PlaceCategory.park,
    PlaceCategory.museum,
  ],

  // Self & lifestyle
  Interests.wellness: [
    PlaceCategory.park,
    PlaceCategory.swimmingPool,
    PlaceCategory.garden,
  ],
  Interests.productivity: [
    PlaceCategory.library,
    PlaceCategory.cafe,
  ],
  Interests.games: <PlaceCategory>[], // arcade/board-game cafes too rare in OSM
  Interests.tech: <PlaceCategory>[], // no good OSM tag
  Interests.culture: [
    PlaceCategory.museum,
    PlaceCategory.gallery,
    PlaceCategory.theatre,
    PlaceCategory.cinema,
  ],
};

/// Given an iterable of interest strings (from a chosen suggestion
/// and/or the user's tagged interests), return the ranked list of
/// [PlaceCategory] values to surface — most relevant first, deduped.
///
/// A category's rank is the number of times it appears across the
/// input interests' mappings: a category shared by two of the user's
/// interests beats one mentioned by just one.
List<PlaceCategory> resolveCategories(Iterable<String> interests) {
  final votes = <PlaceCategory, int>{};
  for (final interest in interests) {
    final mapped = interestPlaces[interest];
    if (mapped == null) continue;
    for (final cat in mapped) {
      votes[cat] = (votes[cat] ?? 0) + 1;
    }
  }
  final ranked = votes.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return ranked.map((e) => e.key).toList();
}
