import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../data/deck_themes.dart';
import '../models/suggestion.dart';
import '../utils/challenge_codec.dart';

/// Share the chosen card as a rendered image (deck-themed postcard),
/// falling back to plain text wherever image capture or file sharing
/// isn't available. When a [challenge] is provided, the share text
/// carries the "same hand" link so the recipient can draw against the
/// sender.
Future<void> shareSuggestionCard(
  BuildContext context, {
  required Suggestion suggestion,
  required DeckTheme deck,
  ChallengePayload? challenge,
}) async {
  final text = challenge == null
      ? 'Decidr dealt me: ${suggestion.title}'
          '${suggestion.description.isEmpty ? '' : ' — ${suggestion.description}'}'
      : 'Decidr dealt me "${suggestion.title}" — draw the same hand and '
          'see what you get: ${challenge.shareUrl}';

  final bytes = await _capturePostcard(context, suggestion, deck);
  try {
    if (bytes != null) {
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'image/png', name: 'decidr-card.png')
        ],
        text: text,
      ));
      return;
    }
  } catch (_) {
    // fall through to text-only
  }
  await SharePlus.instance.share(ShareParams(text: text));
}

/// Render a 600×800 deck-themed postcard offscreen and capture it as
/// PNG bytes. Returns null when capture fails (e.g. headless tests).
Future<ui.Image?> _renderPostcard(
  BuildContext context,
  Suggestion suggestion,
  DeckTheme deck,
) async {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return null;
  final key = GlobalKey();
  final entry = OverlayEntry(
    builder: (_) => Positioned(
      left: -10000, // offscreen — rendered but never visible
      top: 0,
      child: RepaintBoundary(
        key: key,
        child: _Postcard(suggestion: suggestion, deck: deck),
      ),
    ),
  );
  overlay.insert(entry);
  try {
    // Two frames: one to lay out, one to paint.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    return await boundary.toImage(pixelRatio: 2.0);
  } catch (_) {
    return null;
  } finally {
    entry.remove();
  }
}

Future<dynamic> _capturePostcard(
  BuildContext context,
  Suggestion suggestion,
  DeckTheme deck,
) async {
  final image = await _renderPostcard(context, suggestion, deck);
  if (image == null) return null;
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

/// The shareable postcard: deck-gradient background, big icon, title,
/// description, Decidr wordmark.
class _Postcard extends StatelessWidget {
  final Suggestion suggestion;
  final DeckTheme deck;

  const _Postcard({required this.suggestion, required this.deck});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 600,
        height: 800,
        padding: const EdgeInsets.all(48),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [deck.back1, deck.back2],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome, color: deck.accent, size: 40),
            const Spacer(),
            Icon(suggestion.iconData, color: Colors.white, size: 96),
            const SizedBox(height: 32),
            Text(
              suggestion.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 44,
                fontWeight: FontWeight.bold,
                height: 1.15,
              ),
            ),
            if (suggestion.description.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                suggestion.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 24,
                  height: 1.4,
                ),
              ),
            ],
            const Spacer(),
            Row(
              children: [
                Icon(Icons.shuffle_rounded, color: deck.accent, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Dealt by Decidr',
                  style: TextStyle(
                    color: deck.accent,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
