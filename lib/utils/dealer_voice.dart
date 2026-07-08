import 'dart:math';

/// The dealer's voice — rotating copy so the app's tarot-dealer
/// identity shows up in its words, not just its cards. Every getter
/// returns a random variant; callers use them at moments of feedback.
class DealerVoice {
  DealerVoice._();

  static final Random _rng = Random();

  static String _pick(List<String> options) =>
      options[_rng.nextInt(options.length)];

  /// After "Did it!" — [title] is the completed activity.
  static String completed(String title) => _pick([
        'The cards knew. "$title" — done.',
        '"$title" — dealt and done.',
        'Another one for the books: "$title".',
        'The deck approves. "$title" complete.',
      ]);

  /// Empty pool after filtering.
  static String get emptyPool => _pick([
        'The deck is feeling stubborn — loosen a filter and we’ll reshuffle.',
        'No cards want to come out for this ask. Ease up on a filter?',
        'Even a good dealer needs a wider pool. Adjust and redeal.',
      ]);

  /// Idle nudge under the deal button.
  static String get idleHint => _pick([
        'We’ll deal three cards. The middle one is yours.',
        'Three cards. Fate picks the middle one.',
        'Cut the deck — the middle card decides.',
      ]);
}
