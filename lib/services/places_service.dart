import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../data/place_categories.dart';
import '../models/nearby_place.dart';

/// Fetches nearby places of a given [PlaceCategory] from OpenStreetMap
/// via the Overpass API.
///
/// Modeled on [WeatherService] — keeps an in-memory cache keyed by
/// `(category, roundedLat, roundedLon)` with a 1-hour TTL, uses
/// `geolocator` for the user's position when callers don't pass
/// one explicitly, and exposes loading/error state via
/// [ChangeNotifier] so the UI can react.
///
/// The bottom sheet that consumes this is designed to render results
/// in sections — one section per category here, with room for future
/// "Featured" / curated picks served from a different source.
class PlacesService extends ChangeNotifier {
  final http.Client _httpClient;

  /// Cache: `(category, roundedLatLon)` → most-recent fetch result.
  /// Lat/lon are rounded to 2 decimals (~1 km grid), so repeated taps
  /// of the same Nearby button within ~hour don't refetch.
  final Map<_CacheKey, _CachedResult> _cache = {};

  /// How long a cached result stays valid before a refetch is allowed.
  static const cacheDuration = Duration(hours: 1);

  /// Default search radius. Two kilometers is a comfortable walk-or-
  /// short-drive distance for city use; rural users may want a bigger
  /// number — surface that as a setting later if there's demand.
  static const defaultRadiusMeters = 2000.0;

  /// Hard cap on results returned per category. Keeps the bottom
  /// sheet skimmable; everything beyond falls off after the
  /// distance sort.
  static const maxResultsPerCategory = 20;

  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  PlacesService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Fetch nearby places of [category] within [radiusMeters] of the
  /// supplied position (or the device's position if `lat` / `lon` are
  /// null). Returns cached results when available and still valid.
  ///
  /// Returns an empty list on permission denial, network failure, or
  /// parse error — the human-readable reason lands in [error] for
  /// the UI to surface if it wants. Never throws.
  Future<List<NearbyPlace>> fetchNearby({
    required PlaceCategory category,
    double? lat,
    double? lon,
    double radiusMeters = defaultRadiusMeters,
  }) async {
    if (lat == null || lon == null) {
      final pos = await _getCurrentPosition();
      if (pos == null) {
        // _error is set by _getCurrentPosition.
        return const [];
      }
      lat = pos.latitude;
      lon = pos.longitude;
    }

    final key = _CacheKey(category, _round(lat), _round(lon));
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < cacheDuration) {
      return cached.places;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final query = _buildOverpassQuery(category, lat, lon, radiusMeters);
      final response = await _httpClient.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: {'data': query},
      );

      if (response.statusCode != 200) {
        _error = 'Overpass returned ${response.statusCode}';
        debugPrint(_error);
        _isLoading = false;
        notifyListeners();
        return const [];
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final places = _parseOverpassResponse(json, category, lat, lon);
      _cache[key] = _CachedResult(places, DateTime.now());
      _isLoading = false;
      _error = null;
      notifyListeners();
      return places;
    } catch (e) {
      _error = 'Error fetching places: $e';
      debugPrint(_error);
      _isLoading = false;
      notifyListeners();
      return const [];
    }
  }

  /// Fetch nearby places across [categories], sharing one location
  /// lookup. Categories with zero results are dropped from the
  /// returned map so the UI only renders non-empty sections.
  Future<Map<PlaceCategory, List<NearbyPlace>>> fetchForCategories({
    required List<PlaceCategory> categories,
    double? lat,
    double? lon,
    double radiusMeters = defaultRadiusMeters,
  }) async {
    if ((lat == null || lon == null) && categories.isNotEmpty) {
      final pos = await _getCurrentPosition();
      if (pos == null) return const {};
      lat = pos.latitude;
      lon = pos.longitude;
    }

    final result = <PlaceCategory, List<NearbyPlace>>{};
    for (final cat in categories) {
      final places = await fetchNearby(
        category: cat,
        lat: lat,
        lon: lon,
        radiusMeters: radiusMeters,
      );
      if (places.isNotEmpty) {
        result[cat] = places;
      }
    }
    return result;
  }

  void clearCache() {
    _cache.clear();
    notifyListeners();
  }

  // ─── internals ───────────────────────────────────────────────

  String _buildOverpassQuery(
    PlaceCategory category,
    double lat,
    double lon,
    double radius,
  ) {
    // Querying node + way + relation surfaces both pinned points
    // (most cafes, museums) and larger areas (parks tagged as
    // polygons). nwr = node + way + relation.
    return '[out:json][timeout:25];'
        'nwr["${category.osmKey}"="${category.osmValue}"]'
        '(around:$radius,$lat,$lon);'
        'out center $maxResultsPerCategory;';
  }

  List<NearbyPlace> _parseOverpassResponse(
    Map<String, dynamic> json,
    PlaceCategory category,
    double userLat,
    double userLon,
  ) {
    final elements = (json['elements'] as List?) ?? [];
    final places = <NearbyPlace>[];

    for (final raw in elements) {
      final el = raw as Map<String, dynamic>;
      final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};

      final name = tags['name'] as String?;
      if (name == null || name.isEmpty) continue;

      // Nodes have lat/lon directly; ways/relations carry it under
      // the `center` sub-object (because we asked for `out center`).
      double? lat = (el['lat'] as num?)?.toDouble();
      double? lon = (el['lon'] as num?)?.toDouble();
      if (lat == null || lon == null) {
        final center = el['center'] as Map?;
        lat = (center?['lat'] as num?)?.toDouble();
        lon = (center?['lon'] as num?)?.toDouble();
      }
      if (lat == null || lon == null) continue;

      final distance = haversineMeters(userLat, userLon, lat, lon);

      places.add(NearbyPlace(
        osmId: '${el['type']}/${el['id']}',
        name: name,
        category: category,
        lat: lat,
        lon: lon,
        distanceMeters: distance,
        address: _parseAddress(tags),
        website: (tags['website'] as String?) ??
            (tags['contact:website'] as String?),
      ));
    }

    places.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
    return places.take(maxResultsPerCategory).toList();
  }

  /// Compose `addr:street`, `addr:housenumber`, `addr:city` into a
  /// readable string. Returns null when none are present.
  String? _parseAddress(Map<String, dynamic> tags) {
    final parts = <String>[];
    final housenumber = tags['addr:housenumber'] as String?;
    final street = tags['addr:street'] as String?;
    if (street != null && street.isNotEmpty) {
      parts.add(housenumber != null && housenumber.isNotEmpty
          ? '$housenumber $street'
          : street);
    }
    final city = tags['addr:city'] as String?;
    if (city != null && city.isNotEmpty) parts.add(city);
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Round lat/lon to two decimals for the cache key. ≈ 1 km grid —
  /// large enough that successive taps at the same address share a
  /// cache hit, small enough that moving meaningfully invalidates.
  double _round(double v) => (v * 100).round() / 100.0;

  /// Geolocator wrapper, identical to the one in [WeatherService] —
  /// kept private here so the two services can evolve independently
  /// (different permission UX, etc).
  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _error = 'Location services are disabled';
        debugPrint(_error);
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _error = 'Location permission denied';
          debugPrint(_error);
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _error = 'Location permission permanently denied';
        debugPrint(_error);
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
    } catch (e) {
      _error = 'Error getting location: $e';
      debugPrint(_error);
      return null;
    }
  }
}

class _CacheKey {
  final PlaceCategory category;
  final double roundedLat;
  final double roundedLon;
  const _CacheKey(this.category, this.roundedLat, this.roundedLon);

  @override
  bool operator ==(Object other) =>
      other is _CacheKey &&
      other.category == category &&
      other.roundedLat == roundedLat &&
      other.roundedLon == roundedLon;

  @override
  int get hashCode => Object.hash(category, roundedLat, roundedLon);
}

class _CachedResult {
  final List<NearbyPlace> places;
  final DateTime fetchedAt;
  const _CachedResult(this.places, this.fetchedAt);
}
