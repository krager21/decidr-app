import 'package:flutter/material.dart';

/// Visual styling for the tarot card back face.
///
/// Each theme contributes a two-stop gradient for the card body and
/// an accent color used for the border, decorative rings, and the
/// sparkle emblem at center. The front (revealed) face stays driven
/// by the app's Material theme — we only style the back so the picker
/// changes the *deck*, not the readability of dealt suggestions.
///
/// The id is what persists in [PreferencesModel.colorTheme]. Themes
/// can be added by appending to [deckThemes] — `themeById` falls back
/// to the first entry when an unknown id is loaded, so the field is
/// safe across schema changes.
///
/// Background motif painted on the card back — what makes a premium
/// deck more than a recolor of the same two rings.
enum DeckMotif { classic, moonAndStars, leaves, sunRays, geometric }

/// Named `DeckTheme` (not `CardTheme`) to avoid clashing with
/// Flutter's `CardTheme` from the Material library.
class DeckTheme {
  final String id;
  final String name;

  /// Gradient stops for the card-back fill, applied top-left to
  /// bottom-right.
  final Color back1;
  final Color back2;

  /// Used for the border, the two decorative rings, and the sparkle
  /// emblem in the middle.
  final Color accent;

  /// Whether this theme is gated to Decidr Premium. The default
  /// theme is always free; everything else is currently premium.
  /// The Phase-4 paywall replaces the placeholder "coming soon"
  /// dialog with a real purchase flow.
  final bool isPremium;

  /// Back-face art painted behind the emblem.
  final DeckMotif motif;

  const DeckTheme({
    required this.id,
    required this.name,
    required this.back1,
    required this.back2,
    required this.accent,
    required this.isPremium,
    this.motif = DeckMotif.classic,
  });
}

/// All card-back themes shipped with the app.
///
/// Order matters: the picker renders them left-to-right in this order,
/// and `themeById` falls back to the first entry on an unknown id.
const List<DeckTheme> deckThemes = [
  // Default — the original indigo + gold deck. Always free.
  DeckTheme(
    id: 'default',
    name: 'Classic',
    back1: Color(0xFF1E1B4B), // indigo-950
    back2: Color(0xFF312E81), // indigo-800
    accent: Color(0xFFD4A574), // warm gold
    isPremium: false,
  ),
  // Tarot — deeper mystic purple with bright gold.
  DeckTheme(
    id: 'tarot',
    name: 'Tarot',
    back1: Color(0xFF3B0764), // violet-950
    back2: Color(0xFF6B21A8), // violet-800
    accent: Color(0xFFF9C846), // saturated gold
    isPremium: true,
    motif: DeckMotif.moonAndStars,
  ),
  // Forest — deep green with antiqued copper accent.
  DeckTheme(
    id: 'forest',
    name: 'Forest',
    back1: Color(0xFF052E16), // green-950
    back2: Color(0xFF14532D), // green-900
    accent: Color(0xFFC8956D), // antique copper
    isPremium: true,
    motif: DeckMotif.leaves,
  ),
  // Sunset — warm pink-to-orange with cream highlight.
  DeckTheme(
    id: 'sunset',
    name: 'Sunset',
    back1: Color(0xFF7C2D12), // orange-900
    back2: Color(0xFFBE185D), // pink-700
    accent: Color(0xFFFEF3C7), // cream
    isPremium: true,
    motif: DeckMotif.sunRays,
  ),
  // Monochrome — slate grays with silver accent.
  DeckTheme(
    id: 'monochrome',
    name: 'Monochrome',
    back1: Color(0xFF0F172A), // slate-950
    back2: Color(0xFF334155), // slate-700
    accent: Color(0xFFCBD5E1), // slate-300 silver
    isPremium: true,
    motif: DeckMotif.geometric,
  ),
];

/// Look up a theme by id. Unknown ids fall back to the first entry
/// (the always-free Classic deck) so the app is safe across schema
/// changes and legacy values.
DeckTheme themeById(String id) {
  for (final t in deckThemes) {
    if (t.id == id) return t;
  }
  return deckThemes.first;
}
