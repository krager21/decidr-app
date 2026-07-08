import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/constants.dart';

/// One completed activity: a [Suggestion.id] and when it was done.
class ActivityEvent {
  final String id;
  final DateTime at;

  const ActivityEvent(this.id, this.at);

  Map<String, dynamic> toJson() => {'id': id, 'at': at.toIso8601String()};

  /// Tolerant decode — returns null for malformed entries so one bad
  /// record never discards the rest of the history.
  static ActivityEvent? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final at = json['at'];
    if (id is! String || at is! String) return null;
    final parsed = DateTime.tryParse(at);
    if (parsed == null) return null;
    return ActivityEvent(id, parsed);
  }
}

/// Model for tracking user activity history with debounced saves.
///
/// Since schema v3 the history is an **append-only event list** —
/// completing "Cook a new recipe" twice keeps both events, which is
/// what streaks, per-day stats, and polite reminders all need. (The
/// old shape was a `{id: latest timestamp}` map, where repeats
/// silently overwrote each other.)
///
/// Ids are [Suggestion.id]s; `MigrationService` converts both the
/// pre-Phase-3 title keys and the v2 map shape on first launch. Use
/// `SuggestionsRepository.resolveById(id)` to render an event's id
/// back to a display [Suggestion].
class ActivityHistoryModel extends ChangeNotifier {
  final SharedPreferences _prefs;

  /// All completion events in append order (oldest first).
  List<ActivityEvent> events = [];
  Timer? _saveTimer;

  ActivityHistoryModel(this._prefs) {
    _loadHistory();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  /// Compatibility view: most recent completion per id. Existing
  /// consumers (deal stats, tests) keep working unchanged.
  Map<String, DateTime> get activityHistory {
    final latest = <String, DateTime>{};
    for (final e in events) {
      final existing = latest[e.id];
      if (existing == null || e.at.isAfter(existing)) {
        latest[e.id] = e.at;
      }
    }
    return latest;
  }

  /// Total number of completions ever recorded.
  int get totalCompletions => events.length;

  /// Whether anything was completed today.
  bool get completedToday {
    final now = DateTime.now();
    return events.any((e) =>
        e.at.year == now.year &&
        e.at.month == now.month &&
        e.at.day == now.day);
  }

  /// Consecutive days with at least one completion, counting back from
  /// today (or from yesterday, so an unfinished today doesn't zero an
  /// ongoing streak).
  int get currentStreak {
    if (events.isEmpty) return 0;
    final days = events
        .map((e) => DateTime(e.at.year, e.at.month, e.at.day))
        .toSet();
    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    // Calendar arithmetic, not Duration: subtracting fixed 24h lands
    // on 23:00 across DST transitions and breaks the day-set lookups.
    DateTime prevDay(DateTime d) => DateTime(d.year, d.month, d.day - 1);
    if (!days.contains(cursor)) {
      cursor = prevDay(cursor);
      if (!days.contains(cursor)) return 0;
    }
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = prevDay(cursor);
    }
    return streak;
  }

  // Load activity history. Accepts the v3 list shape and, defensively,
  // the v2 map shape (in case the migration hasn't run) — anything
  // else resets to empty rather than crashing.
  void _loadHistory() {
    final historyJson = _prefs.getString('activityHistory');
    if (historyJson == null) return;
    try {
      final decoded = jsonDecode(historyJson);
      if (decoded is List) {
        events = decoded
            .map(ActivityEvent.fromJson)
            .whereType<ActivityEvent>()
            .toList();
      } else if (decoded is Map<String, dynamic>) {
        // v2 payload: one latest-timestamp per id.
        events = [
          for (final entry in decoded.entries)
            if (DateTime.tryParse(entry.value.toString()) != null)
              ActivityEvent(
                entry.key,
                DateTime.parse(entry.value.toString()),
              ),
        ]..sort((a, b) => a.at.compareTo(b.at));
      }
    } catch (e) {
      debugPrint('Unexpected error loading activity history: $e');
      events = [];
    }
  }

  /// Save activity history to SharedPreferences (v3 list shape).
  Future<void> _saveHistory() async {
    try {
      await _prefs.setString(
        StorageConstants.keyActivityHistory,
        jsonEncode(events.map((e) => e.toJson()).toList()),
      );
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
  /// Appends an event (repeats accumulate) and schedules a debounced
  /// save.
  void recordActivity(String id) {
    events.add(ActivityEvent(id, DateTime.now()));
    _scheduleSave();
    notifyListeners();
  }

  /// Most recent completion events, newest first, limited by [limit].
  /// Repeat completions of the same activity each appear.
  List<ActivityEvent> getRecentEvents({int limit = 20}) {
    final sorted = [...events]..sort((a, b) => b.at.compareTo(a.at));
    return sorted.take(limit).toList();
  }

  /// Get recently completed activities sorted by date (newest first)
  ///
  /// Compatibility API over the latest-per-id view; prefer
  /// [getRecentEvents] for surfaces that should show repeats.
  List<MapEntry<String, DateTime>> getRecentActivities({int limit = 5}) {
    final entries = activityHistory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(limit).toList();
  }
}
