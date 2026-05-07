import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/constants.dart';

/// Model for tracking user activity history with debounced saves.
///
/// Keys are [Suggestion.id]s after Phase 3 (catalog slugs or
/// `custom-<hash>`). `MigrationService` converts pre-Phase-3 title
/// keys to ids on first launch. Use
/// `SuggestionsRepository.resolveById(id)` to render an entry's id
/// back to a display [Suggestion].
class ActivityHistoryModel extends ChangeNotifier {
  final SharedPreferences _prefs;

  /// Map of suggestion id → most-recent completion timestamp.
  Map<String, DateTime> activityHistory = {};
  Timer? _saveTimer;

  ActivityHistoryModel(this._prefs) {
    _loadHistory();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
  
  // Load activity history
  void _loadHistory() {
    final historyJson = _prefs.getString('activityHistory');
    
    if (historyJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(historyJson);
        
        // Convert string dates to DateTime
        decoded.forEach((key, value) {
          activityHistory[key] = DateTime.parse(value.toString());
        });
      } on FormatException catch (e) {
        debugPrint('Invalid JSON in activity history: $e');
        activityHistory = {};
      } catch (e) {
        debugPrint('Unexpected error loading activity history: $e');
        activityHistory = {};
      }
    }
  }
  
  /// Save activity history to SharedPreferences
  Future<void> _saveHistory() async {
    final Map<String, String> historyStrings = {};

    activityHistory.forEach((key, value) {
      historyStrings[key] = value.toIso8601String();
    });

    try {
      await _prefs.setString(StorageConstants.keyActivityHistory, jsonEncode(historyStrings));
    } catch (e) {
      debugPrint('Error saving activity history: $e');
    }
  }

  /// Schedule a debounced save operation to batch multiple writes
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(StorageConstants.saveDebounceDuration, _saveHistory);
  }

  /// Record a completed activity by [Suggestion.id].
  ///
  /// Stores the current timestamp and schedules a debounced save.
  void recordActivity(String id) {
    activityHistory[id] = DateTime.now();
    _scheduleSave();
    notifyListeners();
  }
  
  /// Get recently completed activities sorted by date (newest first)
  ///
  /// Returns a list of activity-timestamp entries limited by [limit] (default 5).
  List<MapEntry<String, DateTime>> getRecentActivities({int limit = 5}) {
    final entries = activityHistory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return entries.take(limit).toList();
  }
}