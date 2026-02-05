
/// Represents weather data for a location
///
/// Provides weather conditions, temperature, and derived properties
/// to help filter activity suggestions appropriately.
class WeatherData {
  /// Weather condition (e.g., 'clear', 'cloudy', 'rain', 'snow', 'storm')
  final String condition;

  /// Temperature in Celsius
  final double temperature;

  /// Feels-like temperature in Celsius
  final double feelsLike;

  /// Humidity percentage (0-100)
  final int humidity;

  /// Wind speed in meters per second
  final double windSpeed;

  /// Whether current weather is suitable for outdoor activities
  final bool isGoodForOutdoor;

  /// Timestamp when weather data was fetched
  final DateTime fetchedAt;

  WeatherData({
    required this.condition,
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.isGoodForOutdoor,
    required this.fetchedAt,
  });

  /// Check if temperature is cold (below 10°C)
  bool get isCold => temperature < 10;

  /// Check if temperature is hot (above 30°C)
  bool get isHot => temperature > 30;

  /// Check if weather is rainy or stormy
  bool get isRainy => ['rain', 'storm', 'drizzle', 'thunderstorm'].contains(condition.toLowerCase());

  /// Check if weather is snowy
  bool get isSnowy => condition.toLowerCase().contains('snow');

  /// Convert WeatherData to JSON
  Map<String, dynamic> toJson() {
    return {
      'condition': condition,
      'temperature': temperature,
      'feelsLike': feelsLike,
      'humidity': humidity,
      'windSpeed': windSpeed,
      'isGoodForOutdoor': isGoodForOutdoor,
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }

  /// Create WeatherData from JSON
  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      condition: json['condition'] as String,
      temperature: (json['temperature'] as num).toDouble(),
      feelsLike: (json['feelsLike'] as num).toDouble(),
      humidity: json['humidity'] as int,
      windSpeed: (json['windSpeed'] as num).toDouble(),
      isGoodForOutdoor: json['isGoodForOutdoor'] as bool,
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }

  /// Create WeatherData from OpenWeatherMap API response
  factory WeatherData.fromOpenWeatherMap(Map<String, dynamic> json) {
    final main = json['main'] as Map<String, dynamic>;
    final weather = (json['weather'] as List<dynamic>)[0] as Map<String, dynamic>;
    final wind = json['wind'] as Map<String, dynamic>;

    final condition = weather['main'] as String;
    final temp = (main['temp'] as num).toDouble();
    final feelsLike = (main['feels_like'] as num).toDouble();

    // Determine if weather is good for outdoor activities
    final isGood = !['Rain', 'Drizzle', 'Thunderstorm', 'Snow'].contains(condition) &&
        temp > 5 &&
        temp < 35 &&
        (wind['speed'] as num).toDouble() < 10;

    return WeatherData(
      condition: condition.toLowerCase(),
      temperature: temp,
      feelsLike: feelsLike,
      humidity: main['humidity'] as int,
      windSpeed: (wind['speed'] as num).toDouble(),
      isGoodForOutdoor: isGood,
      fetchedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'WeatherData(condition: $condition, temp: ${temperature.toStringAsFixed(1)}°C, outdoor: $isGoodForOutdoor)';
  }
}
