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
  WeatherData? _currentWeather;
  bool _isLoading = false;
  String? _error;

  /// Cache duration for weather data (30 minutes)
  static const cacheDuration = Duration(minutes: 30);

  /// OpenWeatherMap API key, injected at build time.
  /// Provide via: `flutter run --dart-define=OPENWEATHER_API_KEY=...`
  /// Get a free key at: https://openweathermap.org/api
  static const String _apiKey =
      String.fromEnvironment('OPENWEATHER_API_KEY');

  /// Get current weather data (returns cached data if still valid)
  WeatherData? get currentWeather => _currentWeather;

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

      // Check if API key is set
      if (_apiKey.isEmpty) {
        debugPrint('Weather API key not configured');
        _error = 'Weather service not configured';
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Fetch from OpenWeatherMap API
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body) as Map<String, dynamic>;
        _currentWeather = WeatherData.fromOpenWeatherMap(jsonData);
        _error = null;
        debugPrint('Fetched weather: $_currentWeather');
      } else {
        _error = 'Failed to fetch weather: ${response.statusCode}';
        debugPrint(_error);
      }
    } catch (e) {
      _error = 'Error fetching weather: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _currentWeather;
  }

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
        desiredAccuracy: LocationAccuracy.low,
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
