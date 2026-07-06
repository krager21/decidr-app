import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:decidr_app/services/weather_service.dart';

const _fixture = {
  'weather': [
    {'main': 'Clouds'},
  ],
  'main': {'temp': 18.0, 'feels_like': 17.0, 'humidity': 60},
  'wind': {'speed': 4.0},
};

void main() {
  test('fetch parses the payload and caches for subsequent calls', () async {
    var calls = 0;
    final service = WeatherService(
      apiKey: 'test-key',
      client: MockClient((request) async {
        calls++;
        expect(request.url.queryParameters['appid'], 'test-key');
        return http.Response(jsonEncode(_fixture), 200);
      }),
    );

    final first = await service.fetchWeather(lat: 1, lon: 2);
    expect(first, isNotNull);
    expect(first!.condition, 'clouds');
    expect(service.freshWeather, isNotNull);
    expect(service.error, isNull);

    // Second call inside the TTL is served from cache.
    await service.fetchWeather(lat: 1, lon: 2);
    expect(calls, 1);
  });

  test('non-200 yields a generic error and null data', () async {
    final service = WeatherService(
      apiKey: 'test-key',
      client: MockClient((_) async => http.Response('nope', 503)),
    );

    final result = await service.fetchWeather(lat: 1, lon: 2);

    expect(result, isNull);
    expect(service.error, contains('503'));
    expect(service.isLoading, isFalse);
  });

  test('network exception yields a generic error without the API key',
      () async {
    final service = WeatherService(
      apiKey: 'super-secret-key',
      client: MockClient((request) async {
        throw http.ClientException('boom', request.url);
      }),
    );

    final result = await service.fetchWeather(lat: 1, lon: 2);

    expect(result, isNull);
    expect(service.error, isNotNull);
    expect(service.error, isNot(contains('super-secret-key')),
        reason: 'exception text embeds the request URL — must not surface');
  });

  test('malformed 200 payload is absorbed, not thrown', () async {
    final service = WeatherService(
      apiKey: 'test-key',
      client: MockClient((_) async => http.Response('{"cod":200}', 200)),
    );

    final result = await service.fetchWeather(lat: 1, lon: 2);

    expect(result, isNull);
    expect(service.error, isNotNull);
  });

  test('without an API key the fetch is refused before any request',
      () async {
    final service = WeatherService(
      client: MockClient((_) async {
        fail('must not hit the network without a key');
      }),
    );

    final result = await service.fetchWeather(lat: 1, lon: 2);

    expect(result, isNull);
    expect(service.error, 'Weather service not configured');
  });

  test('clearCache drops data and error state', () async {
    final service = WeatherService(
      apiKey: 'test-key',
      client: MockClient((_) async => http.Response(jsonEncode(_fixture), 200)),
    );
    await service.fetchWeather(lat: 1, lon: 2);
    expect(service.currentWeather, isNotNull);

    service.clearCache();

    expect(service.currentWeather, isNull);
    expect(service.freshWeather, isNull);
    expect(service.error, isNull);
  });
}
