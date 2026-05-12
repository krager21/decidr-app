import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:decidr_app/data/place_categories.dart';
import 'package:decidr_app/services/places_service.dart';

/// Helper to build a MockClient that responds with the given Overpass
/// elements payload (the `elements` array — the rest of the envelope
/// is filled in here). Pass an alternate [statusCode] to simulate
/// failures.
MockClient _mockOverpass(
  List<Map<String, dynamic>> elements, {
  int statusCode = 200,
}) {
  return MockClient((request) async {
    return http.Response(
      jsonEncode({'elements': elements}),
      statusCode,
    );
  });
}

void main() {
  group('PlacesService Overpass parsing', () {
    test('parses a typical node result with addr and website', () async {
      final service = PlacesService(
        httpClient: _mockOverpass([
          {
            'type': 'node',
            'id': 12345,
            'lat': 40.7129,
            'lon': -74.0061,
            'tags': {
              'name': 'Test Cafe',
              'amenity': 'cafe',
              'addr:housenumber': '12',
              'addr:street': 'Main St',
              'addr:city': 'Brooklyn',
              'website': 'https://test.example',
            },
          },
        ]),
      );

      final places = await service.fetchNearby(
        category: PlaceCategory.cafe,
        lat: 40.7128,
        lon: -74.0060,
      );

      expect(places, hasLength(1));
      final p = places.first;
      expect(p.name, 'Test Cafe');
      expect(p.category, PlaceCategory.cafe);
      expect(p.address, '12 Main St, Brooklyn');
      expect(p.website, 'https://test.example');
      expect(p.osmId, 'node/12345');
      // Brooklyn is ~10–20 m from the user; Haversine should land
      // somewhere in that ballpark.
      expect(p.distanceMeters, greaterThan(0));
      expect(p.distanceMeters, lessThan(50));
    });

    test('falls back to `center` lat/lon for way/relation elements', () async {
      // OSM polygons (parks tagged as ways) put coords under `center`
      // when the query asks for `out center`.
      final service = PlacesService(
        httpClient: _mockOverpass([
          {
            'type': 'way',
            'id': 67890,
            'center': {'lat': 40.7150, 'lon': -74.0050},
            'tags': {'name': 'Test Park', 'leisure': 'park'},
          },
        ]),
      );

      final places = await service.fetchNearby(
        category: PlaceCategory.park,
        lat: 40.7128,
        lon: -74.0060,
      );

      expect(places, hasLength(1));
      expect(places.first.osmId, 'way/67890');
      expect(places.first.name, 'Test Park');
    });

    test('drops elements with no name', () async {
      final service = PlacesService(
        httpClient: _mockOverpass([
          {
            'type': 'node',
            'id': 1,
            'lat': 40.7129,
            'lon': -74.0061,
            'tags': {'amenity': 'cafe'},
          },
          {
            'type': 'node',
            'id': 2,
            'lat': 40.7130,
            'lon': -74.0062,
            'tags': {'name': 'Real Cafe', 'amenity': 'cafe'},
          },
        ]),
      );

      final places = await service.fetchNearby(
        category: PlaceCategory.cafe,
        lat: 40.7128,
        lon: -74.0060,
      );

      expect(places, hasLength(1));
      expect(places.first.name, 'Real Cafe');
    });

    test('sorts results by distance ascending', () async {
      // Far first, near second — should swap order in output.
      final service = PlacesService(
        httpClient: _mockOverpass([
          {
            'type': 'node',
            'id': 1,
            'lat': 40.7200,
            'lon': -74.0060,
            'tags': {'name': 'Far cafe', 'amenity': 'cafe'},
          },
          {
            'type': 'node',
            'id': 2,
            'lat': 40.7130,
            'lon': -74.0062,
            'tags': {'name': 'Near cafe', 'amenity': 'cafe'},
          },
        ]),
      );

      final places = await service.fetchNearby(
        category: PlaceCategory.cafe,
        lat: 40.7128,
        lon: -74.0060,
      );

      expect(places.map((p) => p.name).toList(),
          ['Near cafe', 'Far cafe']);
    });

    test('non-200 response surfaces the error and returns empty', () async {
      final service = PlacesService(
        httpClient: _mockOverpass(const [], statusCode: 503),
      );

      final places = await service.fetchNearby(
        category: PlaceCategory.cafe,
        lat: 40.7128,
        lon: -74.0060,
      );

      expect(places, isEmpty);
      expect(service.error, contains('503'));
    });
  });

  group('PlacesService caching', () {
    test('second call with same coords reuses the cached response', () async {
      var hits = 0;
      final service = PlacesService(
        httpClient: MockClient((request) async {
          hits++;
          return http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 1,
                  'lat': 40.7129,
                  'lon': -74.0061,
                  'tags': {'name': 'Cached Cafe', 'amenity': 'cafe'},
                },
              ],
            }),
            200,
          );
        }),
      );

      await service.fetchNearby(
        category: PlaceCategory.cafe,
        lat: 40.7128,
        lon: -74.0060,
      );
      await service.fetchNearby(
        category: PlaceCategory.cafe,
        lat: 40.7128,
        lon: -74.0060,
      );

      expect(hits, 1, reason: 'Second call should hit the cache, not HTTP');
    });

    test('different category fetches do not share the cache', () async {
      var hits = 0;
      final service = PlacesService(
        httpClient: MockClient((request) async {
          hits++;
          return http.Response(jsonEncode({'elements': []}), 200);
        }),
      );

      await service.fetchNearby(
        category: PlaceCategory.cafe,
        lat: 40.7128,
        lon: -74.0060,
      );
      await service.fetchNearby(
        category: PlaceCategory.park,
        lat: 40.7128,
        lon: -74.0060,
      );

      expect(hits, 2);
    });
  });

  group('PlacesService fetchForCategories', () {
    test('omits categories with no results from the returned map',
        () async {
      final service = PlacesService(
        httpClient: MockClient((request) async {
          // Park returns a hit; cafe returns nothing.
          final body = request.body;
          if (body.contains('leisure') && body.contains('park')) {
            return http.Response(
              jsonEncode({
                'elements': [
                  {
                    'type': 'node',
                    'id': 1,
                    'lat': 40.7129,
                    'lon': -74.0060,
                    'tags': {'name': 'Park', 'leisure': 'park'},
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'elements': []}), 200);
        }),
      );

      final result = await service.fetchForCategories(
        categories: const [PlaceCategory.cafe, PlaceCategory.park],
        lat: 40.7128,
        lon: -74.0060,
      );

      expect(result.keys, [PlaceCategory.park]);
      expect(result[PlaceCategory.park], hasLength(1));
    });
  });
}
