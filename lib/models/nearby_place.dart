import 'dart:math' as math;

import '../data/place_categories.dart';

/// One place returned by [PlacesService.fetchNearby].
///
/// Built from an OpenStreetMap node or way. The id + name + lat/lon
/// are always present; address and website may be null when the OSM
/// entry hasn't been tagged with them.
class NearbyPlace {
  /// Unique OSM id (e.g. `node/123456`). Used as a stable key in lists
  /// and for cache deduplication.
  final String osmId;

  /// Display name from the OSM `name` tag. Entries without a name
  /// are dropped by the service before this constructor runs.
  final String name;

  /// The category that surfaced this place. Useful for grouping
  /// results in the bottom sheet and for showing the right icon.
  final PlaceCategory category;

  final double lat;
  final double lon;

  /// Pre-computed distance from the user's position in meters.
  /// Set by the service after fetch so the sheet can sort/format
  /// without keeping the user's position around.
  final double distanceMeters;

  /// Free-form address string assembled from OSM address tags
  /// (`addr:street`, `addr:housenumber`, etc.). Null when the entry
  /// has no address tags.
  final String? address;

  /// Venue website, when tagged. Falls back to null — the bottom
  /// sheet hides the "website" affordance in that case.
  final String? website;

  const NearbyPlace({
    required this.osmId,
    required this.name,
    required this.category,
    required this.lat,
    required this.lon,
    required this.distanceMeters,
    this.address,
    this.website,
  });

  /// Cross-platform Maps URL — OpenStreetMap.org. iOS / macOS will
  /// route this to Safari which is fine. If we want Apple Maps
  /// specifically on iOS later we can branch on Platform.
  String get mapsUrl =>
      'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon';

  /// Distance formatted for display ("0.4 km" / "850 m" / "1.2 km").
  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    final km = distanceMeters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }
}

/// Great-circle distance (Haversine) between two coordinates in
/// meters. Accurate enough for our 2 km Nearby radius — no need for
/// vincenty / WGS84 niceties.
double haversineMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const earthRadiusMeters = 6371000.0;
  final dLat = _toRadians(lat2 - lat1);
  final dLon = _toRadians(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_toRadians(lat1)) *
          math.cos(_toRadians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusMeters * c;
}

double _toRadians(double degrees) => degrees * (math.pi / 180.0);
