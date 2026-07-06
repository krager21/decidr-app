import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/weather_model.dart';

/// Service for fetching and caching weather data
///
/// Provides weather information based on user location to help
/// filter activity suggestions appropriately.
class WeatherService extends ChangeNotifier {
  final http.Client _client;

  /// The key used for requests — the build-time key in production,
  /// overridable in tests so the fetch/parse/cache paths are reachable
  /// without a --dart-define at test time.
  final String _requestApiKey;

  WeatherService({http.Client? client, @visibleForTesting String? apiKey})
      : _client = client ?? http.Client(),
        _requestApiKey = apiKey ?? _apiKey;

  WeatherData? _currentWeather;
  bool _isLoading = false;
  String? _error;

  /// Cache duration for weather data (30 minutes)
  static const cacheDuration = Duration(minutes: 30);

  /// OpenWeatherMap API key, supplied at build time via `--dart-define`.
  ///
  /// To enable the weather feature, build with:
  ///
  ///   flutter run --dart-define=OPENWEATHER_API_KEY=your_key_here
  ///
  /// Get a free API key at: https://openweathermap.org/api
  ///
  /// When unset, the weather service is disabled and `fetchWeather` returns null.
  static const String _apiKey =
      String.fromEnvironment('OPENWEATHER_API_KEY', defaultValue: '');

  /// Whether the weather service has been configured with an API key.
  static bool get isConfigured => _apiKey.isNotEmpty;

  /// The most recently fetched weather, however old. Prefer
  /// [freshWeather] for anything that *acts* on the data.
  WeatherData? get currentWeather => _currentWeather;

  /// The current weather only while it's within [cacheDuration];
  /// null once stale. The deal pipeline uses this so a long-lived
  /// session doesn't keep filtering against hours-old conditions.
  WeatherData? get freshWeather {
    final data = _currentWeather;
    if (data == null) return null;
    if (DateTime.now().difference(data.fetchedAt) >= cacheDuration) {
      return null;
    }
    return data;
  }

  /// Check if service is currently fetching weather
  bool get isLoading => _isLoading;

  /// Get any error message from the last fetch attempt
  String? get error => _error;

  /// Fetch weather data for a specific location
  ///
  /// Uses cache if available and still valid (within cacheDuration).
  /// Returns null if fetch fails or location permission is denied.
  Future<WeatherData?> fetchWeather({double? lat, double? lon}) async {
    // Check cache first
    if (_currentWeather != null &&
        DateTime.now().difference(_currentWeather!.fetchedAt) < cacheDuration) {
      debugPrint('Using cached weather data');
      return _currentWeather;
    }

    // Check the API key before anything else — in particular before
    // touching the GPS. An unconfigured build must never trigger a
    // location-permission prompt.
    if (_requestApiKey.isEmpty) {
      debugPrint(
        'Weather API key not configured. '
        'Pass --dart-define=OPENWEATHER_API_KEY=... at build time.',
      );
      _error = 'Weather service not configured';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Get location if not provided
      if (lat == null || lon == null) {
        final position = await _getCurrentPosition();
        if (position == null) {
          _error = 'Location permission denied';
          _isLoading = false;
          notifyListeners();
          return null;
        }
        lat = position.latitude;
        lon = position.longitude;
      }

      // Fetch from OpenWeatherMap API
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_requestApiKey&units=metric',
      );

      final response = await _client.get(url);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        _currentWeather = WeatherData.fromOpenWeatherMap(jsonData);
        _error = null;
        debugPrint('Fetched weather: $_currentWeather');
      } else {
        _error = 'Couldn’t fetch weather (HTTP ${response.statusCode})';
        debugPrint(_error);
      }
    } catch (e) {
      // Keep the user-visible message generic: exception text can
      // embed the request URL — API key and coordinates included —
      // and this string is rendered verbatim in Settings.
      _error = 'Couldn’t fetch weather — check your connection';
      debugPrint('Weather fetch failed: ${_sanitize(e)}');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _currentWeather;
  }

  /// Strip the API key out of exception text before it reaches logs.
  String _sanitize(Object e) =>
      e.toString().replaceAll(_requestApiKey, '<redacted>');

  /// Get current device position using Geolocator
  ///
  /// Returns null if location permission is denied or service is disabled.
  Future<Position?> _getCurrentPosition() async {
    try {
      // Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return null;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied');
        return null;
      }

      // Get current position
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
        ),
      );
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  /// Clear cached weather data and error state
  void clearCache() {
    _currentWeather = null;
    _error = null;
    notifyListeners();
  }

  /// Refresh weather data (forces a new fetch even if cache is valid)
  Future<WeatherData?> refreshWeather() async {
    _currentWeather = null;
    return await fetchWeather();
  }
}
