import '../models/suggestion.dart';
import 'context_cards.dart';
import 'seasonal_packs.dart';

/// Composition of the add-on card packs into the dealable catalog.
///
/// Context packs (weather-positive + late-night) are always in the
/// pool — their time-of-day tags and the weather-affinity scoring
/// decide when they actually surface. Seasonal packs only join the
/// pool inside their date windows, so the catalog stops being frozen
/// in eternal spring.
///
/// Everything here is also exposed via [allPackCards] regardless of
/// window, so ids stay resolvable year-round (history and favorites
/// must render a Halloween card in March).

/// Always-available context packs.
final List<Suggestion> contextPackCards = List.unmodifiable([
  ...rainyDayCards,
  ...snowDayCards,
  ...heatwaveCards,
  ...lateNightCards,
]);

/// Every pack card regardless of season — for id resolution.
final List<Suggestion> allPackCards = List.unmodifiable([
  ...contextPackCards,
  ...summerEveningCards,
  ...autumnCards,
  ...halloweenCards,
  ...decemberHolidayCards,
  ...newYearCards,
]);

/// A month/day window, inclusive on both ends. Handles windows that
/// wrap the year boundary (e.g. Dec 28 → Jan 15).
class SeasonalWindow {
  final int startMonth, startDay, endMonth, endDay;

  const SeasonalWindow(
      this.startMonth, this.startDay, this.endMonth, this.endDay);

  bool contains(DateTime date) {
    final d = date.month * 100 + date.day;
    final start = startMonth * 100 + startDay;
    final end = endMonth * 100 + endDay;
    if (start <= end) return d >= start && d <= end;
    return d >= start || d <= end; // wraps the year boundary
  }
}

/// Pack → window. Windows overlap deliberately (Halloween sits inside
/// autumn) — both packs are live during the overlap.
final Map<SeasonalWindow, List<Suggestion>> seasonalPacks = {
  const SeasonalWindow(6, 1, 8, 31): summerEveningCards,
  const SeasonalWindow(9, 1, 11, 15): autumnCards,
  const SeasonalWindow(10, 24, 11, 1): halloweenCards,
  const SeasonalWindow(12, 1, 12, 27): decemberHolidayCards,
  const SeasonalWindow(12, 28, 1, 15): newYearCards,
};

/// The seasonal cards live on [date].
List<Suggestion> seasonalCardsFor(DateTime date) {
  return [
    for (final entry in seasonalPacks.entries)
      if (entry.key.contains(date)) ...entry.value,
  ];
}
