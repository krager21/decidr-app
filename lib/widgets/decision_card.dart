import 'dart:math';

import 'package:flutter/material.dart';

import '../models/suggestion.dart';

/// Visual state of a [DecisionCard] in the tarot-reveal flow.
enum DecisionCardState {
  /// Showing the back face — pre-reveal placeholder.
  faceDown,

  /// Flipped face-up; the suggestion's title and icon are visible.
  /// Used for the two flanking cards in the settled state.
  revealed,

  /// Flipped face-up AND chosen as the winning recommendation.
  /// Visually emphasized with a primary border, soft glow, and slight scale-up.
  chosen,
}

/// A single tarot-style card in the three-card decision reveal.
///
/// Renders an animated flip: the [DecisionCardState.faceDown] state
/// shows a decorative gradient back; once the parent flips the state
/// to [DecisionCardState.revealed] (or directly [DecisionCardState.chosen]),
/// a 3D Y-axis rotation reveals the front face — icon in a circular
/// badge, then the suggestion's title.
///
/// Stateful so it can own its [AnimationController] for the flip.
/// The parent drives timing by changing the [state] prop; this widget
/// runs the flip animation forward when leaving `faceDown` and reverses
/// it on the way back (e.g. when the user taps "Deal again").
class DecisionCard extends StatefulWidget {
  final DecisionCardState state;
  final Suggestion? suggestion;

  /// Card width — kept constant across states so the row layout doesn't
  /// reflow. Visual emphasis on the chosen card uses scale and glow.
  final double width;

  /// Card height — taller than wide for the tarot proportion.
  final double height;

  const DecisionCard({
    super.key,
    required this.state,
    required this.suggestion,
    this.width = 105,
    this.height = 165,
  });

  @override
  State<DecisionCard> createState() => _DecisionCardState();
}

class _DecisionCardState extends State<DecisionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    // Initial state: if we start revealed/chosen, jump to fully flipped.
    if (widget.state != DecisionCardState.faceDown) {
      _flipController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant DecisionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final wasFaceDown = oldWidget.state == DecisionCardState.faceDown;
    final isFaceDown = widget.state == DecisionCardState.faceDown;
    if (wasFaceDown && !isFaceDown) {
      _flipController.forward();
    } else if (!wasFaceDown && isFaceDown) {
      _flipController.reverse();
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isChosen = widget.state == DecisionCardState.chosen;

    return AnimatedScale(
      scale: isChosen ? 1.08 : 1.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
      child: AnimatedBuilder(
        animation: _flipController,
        builder: (context, _) {
          final t = _flipController.value;
          final angle = t * pi; // 0 (back) → pi (front)
          final showFront = t >= 0.5;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // perspective
              ..rotateY(angle),
            child: showFront
                ? Transform(
                    // Counter-rotate so the front isn't mirrored.
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(pi),
                    child: _buildFrontFace(theme, isChosen),
                  )
                : _buildBackFace(theme),
          );
        },
      ),
    );
  }

  // ─── back face ─────────────────────────────────────────────────

  Widget _buildBackFace(ThemeData theme) {
    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1B4B), // indigo-950
            Color(0xFF312E81), // indigo-800
          ],
        ),
        border: Border.all(
          color: const Color(0xFFD4A574).withValues(alpha: 0.55), // gold
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer decorative ring.
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD4A574).withValues(alpha: 0.32),
                  width: 1.2,
                ),
              ),
            ),
            // Inner ring.
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFD4A574).withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
            ),
            // Sparkle emblem.
            const Icon(
              Icons.auto_awesome,
              size: 22,
              color: Color(0xFFD4A574),
            ),
          ],
        ),
      ),
    );
  }

  // ─── front face ────────────────────────────────────────────────

  Widget _buildFrontFace(ThemeData theme, bool isChosen) {
    final s = widget.suggestion;
    final accent =
        isChosen ? theme.colorScheme.primary : theme.colorScheme.outlineVariant;
    final iconBgColor = isChosen
        ? theme.colorScheme.primary
        : theme.colorScheme.primaryContainer;
    final iconFgColor = isChosen
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onPrimaryContainer;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accent,
          width: isChosen ? 2.5 : 1,
        ),
        boxShadow: [
          if (isChosen)
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.32),
              blurRadius: 22,
              spreadRadius: 1,
            )
          else
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon in a circular badge.
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBgColor,
                boxShadow: isChosen
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary
                              .withValues(alpha: 0.25),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                s?.iconData ?? Icons.help_outline,
                size: 28,
                color: iconFgColor,
              ),
            ),
            const SizedBox(height: 14),
            // Title.
            Flexible(
              child: Text(
                s?.title ?? '',
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: isChosen ? FontWeight.w700 : FontWeight.w500,
                  color: isChosen
                      ? theme.colorScheme.onSurface
                      : theme.colorScheme.onSurfaceVariant,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
