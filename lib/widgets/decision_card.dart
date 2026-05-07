import 'package:flutter/material.dart';

import '../models/suggestion.dart';

/// Visual state of a [DecisionCard] in the card-reveal flow.
enum DecisionCardState {
  /// Pre-deal placeholder. No content yet.
  idle,

  /// Cycling through candidates while the algorithm "considers".
  cycling,

  /// Locked on its final candidate; not yet chosen as the winner.
  /// Used for the two flanking cards in the settled state.
  locked,

  /// Locked AND chosen as the winning recommendation. Visually elevated.
  chosen,
}

/// A single card in the three-card decision reveal.
///
/// Renders the [suggestion]'s icon and title, with state-dependent visual
/// treatment:
///   - idle:    soft outline, no content (waiting for "Decide" tap).
///   - cycling: the [suggestion] swaps every ~280ms; a subtle pulse hints
///              that the algorithm is still considering. Animated via
///              [AnimatedSwitcher] under the hood — caller drives swaps
///              by changing the [suggestion] prop.
///   - locked:  the [suggestion] is final; card sits at base size, dim
///              accent. Used for the "also considered" pair.
///   - chosen:  the winner. Slight scale-up, primary border, soft glow.
///
/// The card is purely presentational — the orchestration page owns timing,
/// haptics, and the candidate pool.
class DecisionCard extends StatelessWidget {
  final DecisionCardState state;
  final Suggestion? suggestion;

  /// Card width — kept constant across states so the row layout doesn't
  /// reflow. Visual emphasis on the chosen card uses scale/border instead.
  final double width;

  /// Card height — same logic as [width].
  final double height;

  const DecisionCard({
    super.key,
    required this.state,
    required this.suggestion,
    this.width = 100,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final isChosen = state == DecisionCardState.chosen;
    final isCycling = state == DecisionCardState.cycling;
    final isIdle = state == DecisionCardState.idle;

    final borderColor = isChosen
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    final borderWidth = isChosen ? 2.5 : 1.0;
    final scale = isChosen ? 1.08 : (isIdle ? 0.96 : 1.0);
    final elevation = isChosen ? 6.0 : (isIdle ? 0.0 : 2.0);

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isIdle
              ? theme.colorScheme.surfaceContainerLow
              : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: [
            if (isChosen)
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.25),
                blurRadius: 18,
                spreadRadius: 1,
              )
            else if (elevation > 0)
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: elevation * 2,
                offset: Offset(0, elevation / 2),
              ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, animation) {
              // During cycling, slide content vertically so it feels like
              // a slot-machine reel. In other states, fade.
              if (isCycling) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.35),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              }
              return FadeTransition(opacity: animation, child: child);
            },
            child: _buildContent(theme, key: ValueKey(suggestion?.id ?? 'idle')),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, {required Key key}) {
    if (suggestion == null) {
      return Center(
        key: key,
        child: Icon(
          Icons.help_outline,
          size: 28,
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
      );
    }

    final s = suggestion!;
    return Column(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          s.iconData,
          size: 30,
          color: state == DecisionCardState.chosen
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 8),
        Flexible(
          child: Text(
            s.title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: state == DecisionCardState.chosen
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: state == DecisionCardState.chosen
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
