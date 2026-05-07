import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Model for tracking user feedback on activity suggestions.
///
/// Tracks rejections and dislikes — both keyed by [Suggestion.id]
/// after Phase 3 (catalog slugs or `custom-<hash>`).
/// `MigrationService` converts pre-Phase-3 title keys to ids on
/// first launch.
///
/// - Reduces frequency of recently rejected activities (time-decay)
/// - Completely excludes disliked activities
class FeedbackModel extends ChangeNotifier {
  final SharedPreferences _prefs;

  /// Map of suggestion id → list of rejection timestamps.
  Map<String, List<DateTime>> _rejections = {};

  /// Set of suggestion ids the user has explicitly disliked.
  Set<String> _dislikes = {};

  FeedbackModel(this._prefs) {
    _loadFeedback();
  }

  /// All rejected suggestion ids → rejection timestamps.
  Map<String, List<DateTime>> get rejections => _rejections;

  /// All disliked suggestion ids.
  Set<String> get dislikes => _dislikes;

  /// Record a "not right now" rejection for a suggestion by id.
  ///
  /// Keeps only the last 5 rejections per id for memory efficiency.
  void rejectActivity(String id) {
    _rejections[id] ??= [];
    _rejections[id]!.add(DateTime.now());

    if (_rejections[id]!.length > 5) {
      _rejections[id]!.removeAt(0);
    }

    _saveFeedback();
    notifyListeners();
    debugPrint('Rejected activity: $id');
  }

  /// Mark a suggestion as disliked (permanently excluded) by id.
  void dislikeActivity(String id) {
    _dislikes.add(id);
    _saveFeedback();
    notifyListeners();
    debugPrint('Disliked activity: $id');
  }

  /// Clear all feedback for a specific suggestion id.
  void clearFeedback(String id) {
    _rejections.remove(id);
    _dislikes.remove(id);
    _saveFeedback();
    notifyListeners();
    debugPrint('Cleared feedback for: $id');
  }

  /// Clear all feedback data
  void clearAllFeedback() {
    _rejections.clear();
    _dislikes.clear();
    _saveFeedback();
    notifyListeners();
    debugPrint('Cleared all feedback');
  }

  /// Get the weight multiplier for a suggestion by id (0.0 to 1.0).
  ///
  /// Returns:
  /// - 0.0 for disliked ids (completely excluded)
  /// - 0.1-1.0 for rejected ids based on recency and frequency
  /// - 1.0 for ids with no negative feedback
  double getActivityWeight(String id) {
    if (_dislikes.contains(id)) {
      return 0.0;
    }

    final rejectionList = _rejections[id] ?? [];
    if (rejectionList.isEmpty) {
      return 1.0;
    }

    double penalty = 0.0;
    final now = DateTime.now();

    for (final rejection in rejectionList) {
      final daysSince = now.difference(rejection).inDays;

      // Rejections decay over 30 days
      if (daysSince < 1) {
        penalty += 0.3; // Same day: heavy penalty
      } else if (daysSince < 7) {
        penalty += 0.2; // This week: medium penalty
      } else if (daysSince < 30) {
        penalty += 0.1; // This month: light penalty
      }
      // Older than 30 days: ignored
    }

    // Ensure weight stays in valid range (0.1 minimum to still appear occasionally)
    return (1.0 - penalty).clamp(0.1, 1.0);
  }

  /// Whether a suggestion id is disliked.
  bool isDisliked(String id) {
    return _dislikes.contains(id);
  }

  /// Count of rejections for a suggestion id in the last 30 days.
  int getRecentRejectionsCount(String id) {
    final rejectionList = _rejections[id] ?? [];
    final now = DateTime.now();
    return rejectionList
        .where((rejection) => now.difference(rejection).inDays < 30)
        .length;
  }

  /// Load feedback data from SharedPreferences
  Future<void> _loadFeedback() async {
    try {
      // Load rejections
      final rejectionsJson = _prefs.getString('activity_rejections');
      if (rejectionsJson != null) {
        final Map<String, dynamic> decoded = json.decode(rejectionsJson);
        _rejections = decoded.map((key, value) {
          final timestamps = (value as List<dynamic>)
              .map((ts) => DateTime.parse(ts as String))
              .toList();
          return MapEntry(key, timestamps);
        });
      }

      // Load dislikes
      final dislikesList = _prefs.getStringList('activity_dislikes');
      if (dislikesList != null) {
        _dislikes = Set<String>.from(dislikesList);
      }

      debugPrint('Loaded feedback: ${_rejections.length} rejected, ${_dislikes.length} disliked');
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading feedback: $e');
    }
  }

  /// Save feedback data to SharedPreferences
  Future<void> _saveFeedback() async {
    try {
      // Save rejections
      final rejectionsMap = _rejections.map((key, value) {
        final timestamps = value.map((dt) => dt.toIso8601String()).toList();
        return MapEntry(key, timestamps);
      });
      await _prefs.setString('activity_rejections', json.encode(rejectionsMap));

      // Save dislikes
      await _prefs.setStringList('activity_dislikes', _dislikes.toList());

      debugPrint('Saved feedback data');
    } catch (e) {
      debugPrint('Error saving feedback: $e');
    }
  }
}
