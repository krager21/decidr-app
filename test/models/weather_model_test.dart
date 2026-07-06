import 'package:flutter_test/flutter_test.dart';

import 'package:decidr_app/models/weather_model.dart';

/// A realistic OpenWeatherMap /data/2.5/weather payload.
Map<String, dynamic> owmFixture({
  String condition = 'Clear',
  double temp = 20.0,
  double wind = 3.5,
}) {
  return {
    'coord': {'lon': -122.08, 'lat': 37.39},
    'weather': [
      {'id': 800, 'main': condition, 'description': 'x', 'icon': '01d'},
    ],
    'main': {
      'temp': temp,
      'feels_like': temp - 1.2,
      'temp_min': temp - 2,
      'temp_max': temp + 2,
      'pressure': 1023,
      'humidity': 55,
    },
    'wind': {'speed': wind, 'deg': 350},
    'name': 'Mountain View',
  };
}

void main() {
  group('fromOpenWeatherMap', () {
    test('parses a realistic payload and lowercases the condition', () {
      final data = WeatherData.fromOpenWeatherMap(owmFixture());

      expect(data.condition, 'clear');
      expect(data.temperature, 20.0);
      expect(data.feelsLike, closeTo(18.8, 1e-9));
      expect(data.humidity, 55);
      expect(data.windSpeed, 3.5);
      expect(data.isGoodForOutdoor, isTrue);
    });

    test('rain, cold, heat, and high wind each veto outdoor', () {
      expect(
        WeatherData.fromOpenWeatherMap(owmFixture(condition: 'Rain'))
            .isGoodForOutdoor,
        isFalse,
      );
      expect(
        WeatherData.fromOpenWeatherMap(owmFixture(temp: 4.0))
            .isGoodForOutdoor,
        isFalse,
      );
      expect(
        WeatherData.fromOpenWeatherMap(owmFixture(temp: 36.0))
            .isGoodForOutdoor,
        isFalse,
      );
      expect(
        WeatherData.fromOpenWeatherMap(owmFixture(wind: 12.0))
            .isGoodForOutdoor,
        isFalse,
      );
    });

    test('throws on schema-shifted payloads (service catch handles it)', () {
      expect(
        () => WeatherData.fromOpenWeatherMap({'cod': 200}),
        throwsA(isA<TypeError>()),
      );
    });
  });

  group('derived flags', () {
    WeatherData make({String condition = 'clear', double temp = 20}) =>
        WeatherData(
          condition: condition,
          temperature: temp,
          feelsLike: temp,
          humidity: 50,
          windSpeed: 2,
          isGoodForOutdoor: true,
          fetchedAt: DateTime.now(),
        );

    test('isRainy covers OWM rain-family conditions', () {
      expect(make(condition: 'rain').isRainy, isTrue);
      expect(make(condition: 'thunderstorm').isRainy, isTrue);
      expect(make(condition: 'drizzle').isRainy, isTrue);
      expect(make(condition: 'Rain').isRainy, isTrue, reason: 'case-folded');
      expect(make(condition: 'clouds').isRainy, isFalse);
    });

    test('isSnowy matches snow substrings', () {
      expect(make(condition: 'snow').isSnowy, isTrue);
      expect(make(condition: 'clear').isSnowy, isFalse);
    });

    test('isCold/isHot boundaries at 10 and 30 degrees', () {
      expect(make(temp: 9.9).isCold, isTrue);
      expect(make(temp: 10.0).isCold, isFalse);
      expect(make(temp: 30.0).isHot, isFalse);
      expect(make(temp: 30.1).isHot, isTrue);
    });
  });

  test('toJson/fromJson round-trips', () {
    final original = WeatherData.fromOpenWeatherMap(owmFixture());
    final decoded = WeatherData.fromJson(original.toJson());
    expect(decoded.condition, original.condition);
    expect(decoded.temperature, original.temperature);
    expect(decoded.isGoodForOutdoor, original.isGoodForOutdoor);
    expect(decoded.fetchedAt, original.fetchedAt);
  });
}
