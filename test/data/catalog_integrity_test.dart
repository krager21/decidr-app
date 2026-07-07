import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:decidr_app/data/suggestions_catalog.dart';
import 'package:decidr_app/models/suggestion.dart';

/// Catalog lint: the content lives in two hand-written Dart files
/// (~480 entries), and every recent data bug — duplicate concepts,
/// outdoor+indoorOnly contradictions, icon names missing from the
/// lookup map — was invisible until someone happened to deal the card.
/// These invariants make the next slip a failing test instead.
void main() {
  test('every suggestion id is unique', () {
    final seen = <String>{};
    final dupes = <String>[];
    for (final s in defaultSuggestions) {
      if (!seen.add(s.id)) dupes.add(s.id);
    }
    expect(dupes, isEmpty, reason: 'duplicate ids: $dupes');
  });

  test('numeric fields are within their documented ranges', () {
    for (final s in defaultSuggestions) {
      expect(s.energyLevel, inInclusiveRange(1.0, 5.0),
          reason: '${s.id} energyLevel');
      expect(s.weirdness, inInclusiveRange(0.0, 1.0),
          reason: '${s.id} weirdness');
      expect(s.durationMinutes, greaterThan(0),
          reason: '${s.id} durationMinutes');
    }
  });

  test('no entry filters itself out: moods and social are non-empty', () {
    for (final s in defaultSuggestions) {
      expect(s.moods, isNotEmpty, reason: '${s.id} has no moods');
      expect(s.social, isNotEmpty, reason: '${s.id} has no social contexts');
    }
  });

  test('no outdoor activity is indoorOnly (weather filter would starve it)',
      () {
    final contradictions = defaultSuggestions
        .where((s) =>
            s.activityType == ActivityType.outdoor &&
            s.weather == WeatherTolerance.indoorOnly)
        .map((s) => s.id)
        .toList();
    expect(contradictions, isEmpty,
        reason: 'outdoor + indoorOnly can never deal under weather '
            'filtering: $contradictions');
  });

  test('every iconName resolves to a real icon, not the fallback', () {
    final broken = defaultSuggestions
        .where((s) =>
            s.iconName != 'local_activity_outlined' &&
            s.iconData == Icons.local_activity_outlined)
        .map((s) => '${s.id} (${s.iconName})')
        .toList();
    expect(broken, isEmpty,
        reason: 'icon names missing from the _materialIcons map: $broken');
  });

  test('interest tags use the canonical Interests taxonomy', () {
    final canonical = Interests.all.toSet();
    final unknown = <String>[];
    for (final s in defaultSuggestions) {
      for (final i in s.interests) {
        if (!canonical.contains(i)) unknown.add('${s.id}: $i');
      }
    }
    expect(unknown, isEmpty, reason: 'unknown interest values: $unknown');
  });

  test('near-duplicate titles do not share a deal pool', () {
    // Two entries whose normalized title key collides AND whose
    // (activityType, mood) coverage overlaps can appear side by side
    // in one 3-card hand — this caught visit-museum/wander-a-museum.
    String keyFor(String title) {
      final words = title
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z ]'), '')
          .split(' ')
          .where((w) => w.length > 3 && !_stopWords.contains(w))
          .toList()
        ..sort();
      return words.join('-');
    }

    final byKey = <String, List<Suggestion>>{};
    for (final s in defaultSuggestions) {
      final k = keyFor(s.title);
      if (k.isEmpty) continue;
      byKey.putIfAbsent(k, () => []).add(s);
    }

    final collisions = <String>[];
    byKey.forEach((k, entries) {
      if (entries.length < 2) return;
      for (var i = 0; i < entries.length; i++) {
        for (var j = i + 1; j < entries.length; j++) {
          final a = entries[i], b = entries[j];
          final samePool = a.activityType == b.activityType &&
              a.moods.toSet().intersection(b.moods.toSet()).isNotEmpty;
          if (samePool) collisions.add('${a.id} <-> ${b.id}');
        }
      }
    });
    expect(collisions, isEmpty,
        reason: 'same-pool near-duplicates: $collisions');
  });
}

const _stopWords = {'with', 'your', 'that', 'this', 'from', 'have'};
